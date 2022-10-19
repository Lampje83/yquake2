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
#endif

layout (vertices = 3) out;

#ifndef __INTELLISENSE__
layout (std140) uniform refDat {
#endif
	refData_s refData[16];
#ifndef __INTELLISENSE__
};
#endif

struct Vertex {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	uint	LightFlags;
	uint	SurfFlags;
	int		refIndex;
};

in Vertex VS_OUT[];
/*
out TCS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} tesc_out[];
*/
out Vertex TCS_OUT[];

void main () {
	vec2 scrpos[3];

	TCS_OUT[gl_InvocationID].TexCoord = VS_OUT[gl_InvocationID].TexCoord;
	TCS_OUT[gl_InvocationID].LMcoord = VS_OUT[gl_InvocationID].LMcoord;
	TCS_OUT[gl_InvocationID].WorldCoord = VS_OUT[gl_InvocationID].WorldCoord;
	TCS_OUT[gl_InvocationID].Normal = VS_OUT[gl_InvocationID].Normal;
	TCS_OUT[gl_InvocationID].LightFlags = VS_OUT[gl_InvocationID].LightFlags;
	TCS_OUT[gl_InvocationID].SurfFlags = VS_OUT[gl_InvocationID].SurfFlags;
	TCS_OUT[gl_InvocationID].refIndex = VS_OUT[gl_InvocationID].refIndex;

	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
	gl_out[gl_InvocationID].gl_ClipDistance[0] = gl_in[gl_InvocationID].gl_ClipDistance[0];

	if (gl_InvocationID == 0) {
		{
#if 0	// this actually makes things slower
			for (int j = 0; j < 5; j++) {
				int k = 0;
				for (int i = 0; i < gl_in.length (); i++) {
					vec4 pos = gl_in[i].gl_Position;
					if (j < 4) {
						// test for view culling
						//if ((pos[j & 1] * (1.0 - (j & 2))) > (refData[gs_in[i].refIndex].cullDistances[j] * pos.w) && (gl_in[i].gl_ClipDistance[0] > 0)) k++;
						if ((pos[j & 1] * (1.0 - (j & 2))) > (refData[tesc_in[i].refIndex].cullDistances[j] * pos.w)) k++;
					}
					else {
						if (gl_in[i].gl_ClipDistance[0] < 0) k++;
					}
				}
				if (j < 4) {
					if (k == gl_in.length ())
					{
						// discard
						gl_TessLevelInner[0] = 0;
						gl_TessLevelOuter[0] = 0;
						gl_TessLevelOuter[1] = 0;
						gl_TessLevelOuter[2] = 0;
						return;
					}
				}
			}
#endif
			if (VS_OUT[0].refIndex >= 0 && ((refData[VS_OUT[0].refIndex].flags & REFSURF_REFRACT) != 0) && refData[VS_OUT[0].refIndex].refrindex != 1.0) {
				vec3 lengths;
#if 0
				scrpos[0] = tesc_in[0].WorldCoord.xyz;
				scrpos[1] = tesc_in[1].WorldCoord.xyz;
				scrpos[2] = tesc_in[2].WorldCoord.xyz;
#else
				scrpos[0] = clamp (gl_in[0].gl_Position.xy / gl_in[0].gl_Position.w, -1, 1);
				scrpos[1] = clamp (gl_in[1].gl_Position.xy / gl_in[1].gl_Position.w, -1, 1);
				scrpos[2] = clamp (gl_in[2].gl_Position.xy / gl_in[2].gl_Position.w, -1, 1);
#endif
				lengths[0] = length (scrpos[0] - scrpos[1]);
				lengths[1] = length (scrpos[1] - scrpos[2]);
				lengths[2] = length (scrpos[2] - scrpos[0]);

				gl_TessLevelInner[0] = 0.25 + min (length (mix (scrpos[0], scrpos[1], 0.5) - scrpos[2]),
					length (mix (scrpos[1], scrpos[2], 0.5) - scrpos[0])) * 1.5;
				gl_TessLevelOuter[0] = 0.5 + lengths[1] * 1.5;
				gl_TessLevelOuter[1] = 0.5 + lengths[2] * 1.5;
				gl_TessLevelOuter[2] = 0.5 + lengths[0] * 1.5;
			}
			else {
				gl_TessLevelInner[0] = 1;
				gl_TessLevelOuter[0] = 1;
				gl_TessLevelOuter[1] = 1;
				gl_TessLevelOuter[2] = 1;
			}
		}
	}
	// TODO: move reflection/refraction window clipping from geometry shader here
}