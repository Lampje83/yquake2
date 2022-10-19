#version 430 core

#define REFSURF_PLANEBACK	2
#define REFSURF_REFRACT		4

#define SURF_FLOWING		0x40
#define SURF_WARP			0x08
#define SURF_PLANEBACK		0x02
#define SURF_UNDERWATER		128

#ifndef GLOBALFUNCS
#define GLOBALFUNCS

struct refData_s {
	mat4	refMatrix;
	vec4	color;
	vec4	plane;
	vec4	cullDistances;
	int		flags;
	float	refrindex;
	float	_pad_1;
	float	_pad_2;
};

float distToPlane (vec3 point, vec4 plane) {
	return  dot (point, plane.xyz) - plane.w;
}

float cosToSin (float value) {
	return sqrt (1 - value * value);
}

vec3 findRefractedPos (vec3 viewpos, vec3 worldpos, refData_s plane) {
	vec3	planepos[3];		/*	0 is for the view position projected on the refraction plane
								1 is for the world position projected on the refraction plane
								2 is our test case and will eventually be used
								0 and 1 are also used as buffer for the bisection method */
	float	sinV, sinW;			//	storage for our test case
	float	ior;				//	index of refraction, this gets inverted when inside the fluid
	int		i;
	float	distV, distW;
	float	start, end;

	distV = distToPlane (viewpos, plane.plane);
	distW = distToPlane (worldpos, plane.plane);

	if ((distV * distW) > 0) {
		// line doesn't cross the plane
		return worldpos;
	}

	ior = plane.refrindex;
	if ((ior == 1.0) || ior == 0.0) {
		// no refraction at all, quit
		return worldpos;
	}

	if (distW > 0) {
		// inside fluid
		ior = 1.0 / ior;
	}

	// project viewpos to plane
	planepos[0] = viewpos - distV * plane.plane.xyz;
	// project worldpos to plane
	planepos[1] = worldpos - distW * plane.plane.xyz;

	start = 0; end = 1;

	for (i = 0; i < 20; i++) {
		planepos[2] = mix (planepos[0], planepos[1], (start + end) * 0.5);
		// calculate angles
		sinV = cosToSin (abs (dot (normalize (viewpos - planepos[2]), plane.plane.xyz)));
		sinW = cosToSin (abs (dot (normalize (worldpos - planepos[2]), plane.plane.xyz)));

		if (abs (sinV - sinW * ior) < 0.001) {
			// our result is good enough
			break;
		} else {
			if ((sinV - sinW * ior) > 0) {
				// our point is too far from view position
				end = (start + end) * 0.5;
			} else {
				// our point is too far from world position
				start = (start + end) * 0.5;
			}
		}
	}

	// calculate new distances
	distV = length (viewpos - planepos[2]);
	distW = length (worldpos - planepos[2]);

	if (abs (distToPlane (planepos[2], plane.plane)) > 1)
		return worldpos;

	// now project our point beyond the newly calculated vector
	return viewpos + ((planepos[2] - viewpos) / distV) * (distV + distW);
}
#endif
#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common.glsl"
#define VS_OUT struct
#endif

layout (triangles, equal_spacing) in;

// for UBO shared between all 3D shaders
#ifndef __INTELLISENSE__
layout (std140) uniform uni3D {
#endif
	mat4 transProj;
	mat4 transView;
	mat4 transModel;

	vec4  skyRotate;
	vec3 viewPos;

	int		refTexture;
	int		lightmapindex;
	float time;
	float alpha;
	float overbrightbits;
	float particleFadeFactor;
	uint  flags;
	float _pad_1; // AMDs legacy windows driver needs this, otherwise uni3D has wrong size
	float _pad_2;
	//float _pad_3;
#ifndef __INTELLISENSE__
};
#endif

#ifndef __INTELLISENSE__
layout (std140) uniform refDat {
#endif
	refData_s refData[16];
#ifndef __INTELLISENSE__
};
#endif

in TCS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	uint	LightFlags;
	uint	SurfFlags;
	int	refIndex;
} tese_in[];

out VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	uint	LightFlags;
	uint	SurfFlags;
	int		refIndex;
} tese_out;

void main (void) {
	bool	refrActive = false;
	//gl_Position = gl_in[0].gl_Position[0] * gl_TessCoord.x + gl_in[1].gl_Position * gl_TessCoord.y + gl_in[2].gl_Position * gl_TessCoord.z;
	tese_out.TexCoord = tese_in[0].TexCoord * gl_TessCoord.x + tese_in[1].TexCoord * gl_TessCoord.y + tese_in[2].TexCoord * gl_TessCoord.z;
	tese_out.LMcoord = tese_in[0].LMcoord * gl_TessCoord.x + tese_in[1].LMcoord * gl_TessCoord.y + tese_in[2].LMcoord * gl_TessCoord.z;
	tese_out.WorldCoord = tese_in[0].WorldCoord * gl_TessCoord.x + tese_in[1].WorldCoord * gl_TessCoord.y + tese_in[2].WorldCoord * gl_TessCoord.z;
	tese_out.Normal = tese_in[0].Normal * gl_TessCoord.x + tese_in[1].Normal * gl_TessCoord.y + tese_in[2].Normal * gl_TessCoord.z;
	tese_out.LightFlags = tese_in[2].LightFlags;
	tese_out.SurfFlags = tese_in[2].SurfFlags;
	tese_out.refIndex = tese_in[2].refIndex;

	if (tese_in[2].refIndex >= 0) {
		if ((refData[tese_in[2].refIndex].flags & REFSURF_REFRACT) != 0) {
			refrActive = true;
		}
	}
	if (gl_TessCoord.x == 1.0 && gl_TessCoord.y == 0.0 && gl_TessCoord.z == 0.0) {
		gl_Position = gl_in[0].gl_Position;
	}
	else if (gl_TessCoord.x == 0.0 && gl_TessCoord.y == 1.0 && gl_TessCoord.z == 0.0) {
		gl_Position = gl_in[1].gl_Position;
	}
	else if (gl_TessCoord.x == 0.0 && gl_TessCoord.y == 0.0 && gl_TessCoord.z == 1.0) {
		gl_Position = gl_in[2].gl_Position;
	}
	else if (refrActive) {
		vec3 worldCoord = tese_in[0].WorldCoord * gl_TessCoord.x + tese_in[1].WorldCoord * gl_TessCoord.y + tese_in[2].WorldCoord * gl_TessCoord.z;
		gl_Position = transProj * transView * vec4 (findRefractedPos(viewPos, worldCoord, refData[tese_in[2].refIndex]), 1);
	}
	else {
		gl_Position = gl_in[0].gl_Position[0] * gl_TessCoord.x + gl_in[1].gl_Position * gl_TessCoord.y + gl_in[2].gl_Position * gl_TessCoord.z;
	}
	
	gl_ClipDistance[0] = gl_in[0].gl_ClipDistance[0] * gl_TessCoord.x + gl_in[1].gl_ClipDistance[0] * gl_TessCoord.y + gl_in[2].gl_ClipDistance[0] * gl_TessCoord.z;

}
