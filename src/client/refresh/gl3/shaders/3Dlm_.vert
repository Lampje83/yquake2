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
//#version 430 core
#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common.glsl"
#endif

in vec3 position;   // GL3_ATTRIB_POSITION
in vec2 texCoord;   // GL3_ATTRIB_TEXCOORD
in vec2 lmTexCoord; // GL3_ATTRIB_LMTEXCOORD
in vec4 vertColor;  // GL3_ATTRIB_COLOR
in vec3 normal;     // GL3_ATTRIB_NORMAL
in uint lightFlags; // GL3_ATTRIB_LIGHTFLAGS
in uint surfFlags;	// GL3_ATTRIB_SURFFLAGS
in int  refIndex;	// GL3_ATTRIB_REFINDEX

// for UBO shared between all 3D shaders
#ifndef __INTELLISENSE__
layout (binding = 1, std140) uniform uni3D
{
#endif
	mat4 transProj;
	mat4 transView;
	mat4 transModel;

	vec4 skyRotate;
	vec3 viewPos;

	int		refTexture;	// which texture to draw on reflecting surface
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

#define REFSURF_PLANEBACK	2

#ifndef __INTELLISENSE__
layout ( binding = 2, std140 ) uniform refDat {
#endif
	refData_s refData[16];
#ifndef __INTELLISENSE__
};
#endif

#ifndef __INTELLISENSE__
out gl_PerVertex {
#endif
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[1];
#ifndef __INTELLISENSE__
};
#endif
// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "Common.glsl"
#include "Common3D.vert"
#define VS_OUT struct
#endif

out VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	uint	LightFlags;
	uint	SurfFlags;
	int	refIndex;
} vs;

void main()
{
	vs.TexCoord = texCoord;// + vec2(scroll, 0);
	if ((surfFlags & SURF_FLOWING) != 0) {
		vs.TexCoord.s -= time / 48.0 * 32.0;
		// vs.TexCoord += vec2 (time / 128.0, 0);
	}

	vs.LMcoord = lmTexCoord;
	vs.WorldCoord = (transModel * vec4(position, 1.0f)).xyz;
	vs.Normal = normalize((transModel * vec4 (normal, 0.0f)).xyz);
	vs.LightFlags = lightFlags;
	vs.SurfFlags = surfFlags;
	vs.refIndex = refIndex + gl_InstanceID;

	vec3 modifiedCoord;

	if (vs.refIndex >= 0) {
		if ((refData[vs.refIndex].flags & REFSURF_REFRACT) != 0) {
			modifiedCoord = findRefractedPos (viewPos, vs.WorldCoord, refData[vs.refIndex]);
		} else {
			modifiedCoord = (refData[vs.refIndex].refMatrix * vec4 (vs.WorldCoord, 1.0)).xyz;
		}

		vec4 plane = refData[vs.refIndex].plane;
		gl_ClipDistance[0] = -distToPlane (modifiedCoord, plane);
		if (distToPlane (viewPos, plane) < 0) {
			gl_ClipDistance[0] = -gl_ClipDistance[0];
			vs.SurfFlags |= REFSURF_PLANEBACK;
		}
		else {
		}
	} else {
		modifiedCoord = vs.WorldCoord;
		gl_ClipDistance[0] = 0.0;
	}
	gl_Position = transProj * transView * vec4(modifiedCoord, 1.0);
}
