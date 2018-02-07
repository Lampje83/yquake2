#ifdef __INTELLISENSE__
#include "glsl.h"
#define VS_OUT struct
#endif

layout (triangles, fractional_odd_spacing) in;

// for UBO shared between all 3D shaders
#ifndef __INTELLISENSE__
layout (std140) uniform uni3D {
#endif
	mat4 transProj;
	mat4 transView;
	mat4 transModel;
	//	vec4 fluidPlane;
	//	vec4 cullDistances;
	vec3 viewPos;

	int		refTexture;
	float scroll; // for SURF_FLOWING
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

in TCS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	float		refPlaneDist;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} tese_in[];

out VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	float		refPlaneDist;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} tese_out;

void main (void) {
	//gl_Position = gl_in[0].gl_Position[0] * gl_TessCoord.x + gl_in[1].gl_Position * gl_TessCoord.y + gl_in[2].gl_Position * gl_TessCoord.z;
	tese_out.TexCoord = tese_in[0].TexCoord * gl_TessCoord.x + tese_in[1].TexCoord * gl_TessCoord.y + tese_in[2].TexCoord * gl_TessCoord.z;
	tese_out.LMcoord = tese_in[0].LMcoord * gl_TessCoord.x + tese_in[1].LMcoord * gl_TessCoord.y + tese_in[2].LMcoord * gl_TessCoord.z;
	tese_out.WorldCoord = tese_in[0].WorldCoord * gl_TessCoord.x + tese_in[1].WorldCoord * gl_TessCoord.y + tese_in[2].WorldCoord * gl_TessCoord.z;
	tese_out.Normal = tese_in[0].Normal * gl_TessCoord.x + tese_in[1].Normal * gl_TessCoord.y + tese_in[2].Normal * gl_TessCoord.z;
	tese_out.refPlaneDist = tese_in[0].refPlaneDist * gl_TessCoord.x + tese_in[1].refPlaneDist * gl_TessCoord.y + tese_in[2].refPlaneDist * gl_TessCoord.z;
	tese_out.LightFlags = tese_in[2].LightFlags;
	tese_out.SurfFlags = tese_in[2].SurfFlags;
	tese_out.refIndex = tese_in[2].refIndex;
	gl_Position = transProj * transView * vec4 (tese_in[0].WorldCoord * gl_TessCoord.x + tese_in[1].WorldCoord * gl_TessCoord.y + tese_in[2].WorldCoord * gl_TessCoord.z, 1);
	//gl_ClipDistance[0] = 0.0; //gl_in[0].gl_ClipDistance[0] * gl_TessCoord.x + gl_in[1].gl_ClipDistance[0] * gl_TessCoord.y + gl_in[2].gl_ClipDistance[0] * gl_TessCoord.z;

}
