#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common.glsl"
#define vs_OUT struct
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

in gl_PerVertex {
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[1];
} gl_in[];

out gl_PerVertex {
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[1];
};

in Vx3Dlm tcs_out[];
out Vx3Dlm vs;

void main (void) {
	bool	refrActive = false;
	//gl_Position = gl_in[0].gl_Position[0] * gl_TessCoord.x + gl_in[1].gl_Position * gl_TessCoord.y + gl_in[2].gl_Position * gl_TessCoord.z;
	vs.TexCoord = tcs_out[0].TexCoord * gl_TessCoord.x + tcs_out[1].TexCoord * gl_TessCoord.y + tcs_out[2].TexCoord * gl_TessCoord.z;
	vs.LMcoord = tcs_out[0].LMcoord * gl_TessCoord.x + tcs_out[1].LMcoord * gl_TessCoord.y + tcs_out[2].LMcoord * gl_TessCoord.z;
	vs.WorldCoord = tcs_out[0].WorldCoord * gl_TessCoord.x + tcs_out[1].WorldCoord * gl_TessCoord.y + tcs_out[2].WorldCoord * gl_TessCoord.z;
	vs.Normal = tcs_out[0].Normal * gl_TessCoord.x + tcs_out[1].Normal * gl_TessCoord.y + tcs_out[2].Normal * gl_TessCoord.z;
	vs.LightFlags = tcs_out[2].LightFlags;
	vs.SurfFlags = tcs_out[2].SurfFlags;
	vs.refIndex = tcs_out[2].refIndex;

	if (tcs_out[2].refIndex >= 0) {
		if ((refData[tcs_out[2].refIndex].flags & REFSURF_REFRACT) != 0) {
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
		vec3 worldCoord = tcs_out[0].WorldCoord * gl_TessCoord.x + tcs_out[1].WorldCoord * gl_TessCoord.y + tcs_out[2].WorldCoord * gl_TessCoord.z;
		gl_Position = transProj * transView * vec4 (findRefractedPos(viewPos, worldCoord, refData[tcs_out[2].refIndex]), 1);
	}
	else {
		gl_Position = gl_in[0].gl_Position[0] * gl_TessCoord.x + gl_in[1].gl_Position * gl_TessCoord.y + gl_in[2].gl_Position * gl_TessCoord.z;
	}
	
	gl_ClipDistance[0] = gl_in[0].gl_ClipDistance[0] * gl_TessCoord.x + gl_in[1].gl_ClipDistance[0] * gl_TessCoord.y + gl_in[2].gl_ClipDistance[0] * gl_TessCoord.z;

}
