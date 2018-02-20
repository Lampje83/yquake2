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

in VS_OUT {
	vec2		TexCoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat uint	SurfFlags;
	flat int	refIndex;
} tesc_in[];

out TCS_OUT {
	vec2		TexCoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat uint	SurfFlags;
	flat int	refIndex;
} tesc_out[];

void main () {
	vec2 scrpos[3];

	tesc_out[gl_InvocationID].TexCoord = tesc_in[gl_InvocationID].TexCoord;
	tesc_out[gl_InvocationID].WorldCoord = tesc_in[gl_InvocationID].WorldCoord;
	tesc_out[gl_InvocationID].Normal = tesc_in[gl_InvocationID].Normal;
	tesc_out[gl_InvocationID].SurfFlags = tesc_in[gl_InvocationID].SurfFlags;
	tesc_out[gl_InvocationID].refIndex = tesc_in[gl_InvocationID].refIndex;
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
			if (tesc_in[0].refIndex >= 0 && ((refData[tesc_in[0].refIndex].flags & REFSURF_REFRACT) != 0) && refData[tesc_in[0].refIndex].refrindex != 1.0) {
				vec3 lengths;

#if 0
				scrpos[0] = tesc_in[0].WorldCoord.xyz;
				scrpos[1] = tesc_in[1].WorldCoord.xyz;
				scrpos[2] = tesc_in[2].WorldCoord.xyz;
#else
				scrpos[0] = clamp(gl_in[0].gl_Position.xy / gl_in[0].gl_Position.w, -1, 1);
				scrpos[1] = clamp(gl_in[1].gl_Position.xy / gl_in[1].gl_Position.w, -1, 1);
				scrpos[2] = clamp(gl_in[2].gl_Position.xy / gl_in[2].gl_Position.w, -1, 1);
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
}