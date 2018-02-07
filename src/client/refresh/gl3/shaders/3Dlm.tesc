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
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	float		refPlaneDist;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} tesc_in[];

out TCS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	float		refPlaneDist;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} tesc_out[];

void main () {
	vec3 scrpos[3];

	tesc_out[gl_InvocationID].TexCoord = tesc_in[gl_InvocationID].TexCoord;
	tesc_out[gl_InvocationID].LMcoord = tesc_in[gl_InvocationID].LMcoord;
	tesc_out[gl_InvocationID].WorldCoord = tesc_in[gl_InvocationID].WorldCoord;
	tesc_out[gl_InvocationID].Normal = tesc_in[gl_InvocationID].Normal;
	tesc_out[gl_InvocationID].refPlaneDist = tesc_in[gl_InvocationID].refPlaneDist;
	tesc_out[gl_InvocationID].LightFlags = tesc_in[gl_InvocationID].LightFlags;
	tesc_out[gl_InvocationID].SurfFlags = tesc_in[gl_InvocationID].SurfFlags;
	tesc_out[gl_InvocationID].refIndex = tesc_in[gl_InvocationID].refIndex;
	gl_out[gl_InvocationID].gl_Position = gl_in[gl_InvocationID].gl_Position;
	//gl_out[gl_InvocationID].gl_ClipDistance[0] = gl_in[gl_InvocationID].gl_ClipDistance[0];
	if (gl_InvocationID == 0) {
		if (tesc_in[0].refIndex >= 0 && (tesc_in[0].refPlaneDist < 0
			|| tesc_in[1].refPlaneDist < 0
			|| tesc_in[2].refPlaneDist < 0) && refData[tesc_in[0].refIndex].refrindex != 1.0) {
			vec3 lengths;
/*
			scrpos[0] = gl_in[0].gl_Position.xy;// / gl_in[0].gl_Position.w;
			scrpos[1] = gl_in[1].gl_Position.xy;// / gl_in[1].gl_Position.w;
			scrpos[2] = gl_in[2].gl_Position.xy;// / gl_in[2].gl_Position.w;
*/
			scrpos[0] = tesc_in[0].WorldCoord.xyz;
			scrpos[1] = tesc_in[1].WorldCoord.xyz;
			scrpos[2] = tesc_in[2].WorldCoord.xyz;
			lengths[0] = length (scrpos[0] - scrpos[1]);
			lengths[1] = length (scrpos[1] - scrpos[2]);
			lengths[2] = length (scrpos[2] - scrpos[0]);

			gl_TessLevelInner[0] = 1 + min (length (mix (scrpos[0], scrpos[1], 0.5) - scrpos[2]),
											length (mix (scrpos[1], scrpos[2], 0.5) - scrpos[0])) * 0.02;
			gl_TessLevelOuter[0] = 1 + lengths[1] * 0.01;
			gl_TessLevelOuter[1] = 1 + lengths[2] * 0.01;
			gl_TessLevelOuter[2] = 1 + lengths[0] * 0.01;
		} else {
			gl_TessLevelInner[0] = 1;
			gl_TessLevelOuter[0] = 1;
			gl_TessLevelOuter[1] = 1;
			gl_TessLevelOuter[2] = 1;
		}
	}
}