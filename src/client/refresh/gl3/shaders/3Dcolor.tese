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
	vec3		WorldCoord;
	vec3		Normal;
	flat uint	SurfFlags;
	flat int	refIndex;
} tese_in[];

out VS_OUT {
	vec2		TexCoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat uint	SurfFlags;
	flat int	refIndex;
} tese_out;

void main (void) {
	bool	refrActive = false;
	//gl_Position = gl_in[0].gl_Position[0] * gl_TessCoord.x + gl_in[1].gl_Position * gl_TessCoord.y + gl_in[2].gl_Position * gl_TessCoord.z;
	tese_out.TexCoord = tese_in[0].TexCoord * gl_TessCoord.x + tese_in[1].TexCoord * gl_TessCoord.y + tese_in[2].TexCoord * gl_TessCoord.z;
	tese_out.WorldCoord = tese_in[0].WorldCoord * gl_TessCoord.x + tese_in[1].WorldCoord * gl_TessCoord.y + tese_in[2].WorldCoord * gl_TessCoord.z;
	tese_out.Normal = tese_in[0].Normal * gl_TessCoord.x + tese_in[1].Normal * gl_TessCoord.y + tese_in[2].Normal * gl_TessCoord.z;
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
	else if (tese_in[2].refIndex >= 0 && (refData[tese_in[2].refIndex].flags & REFSURF_REFRACT) != 0) {
		vec3 worldCoord = tese_in[0].WorldCoord * gl_TessCoord.x + tese_in[1].WorldCoord * gl_TessCoord.y + tese_in[2].WorldCoord * gl_TessCoord.z;
		gl_Position = transProj * transView * vec4 (findRefractedPos(viewPos, worldCoord, refData[tese_in[2].refIndex]), 1);
	}
	else {
		gl_Position = gl_in[0].gl_Position[0] * gl_TessCoord.x + gl_in[1].gl_Position * gl_TessCoord.y + gl_in[2].gl_Position * gl_TessCoord.z;
	}
	
	gl_ClipDistance[0] = gl_in[0].gl_ClipDistance[0] * gl_TessCoord.x + gl_in[1].gl_ClipDistance[0] * gl_TessCoord.y + gl_in[2].gl_ClipDistance[0] * gl_TessCoord.z;

}
