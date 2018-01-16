// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "Common3D.vert"
#endif

out VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	flat int	refIndex;
} vs;

void main()
{
	vs.TexCoord = texCoord;
	vs.Color = vertColor*overbrightbits;

	vec4 worldCoord = transModel * vec4 ( position, 1.0 );

	vs.WorldCoord = worldCoord.xyz;
	vs.refIndex = refIndex + gl_InstanceID;

	gl_Position = transProj * transView * worldCoord;

	float refPlaneDist;

	refPlaneDist = dot (vs.WorldCoord.xyz, refData[vs.refIndex].plane.xyz) - refData[vs.refIndex].plane.w;
	if (dot (viewPos, refData[vs.refIndex].plane.xyz)-refData[vs.refIndex].plane.w < 0)
		//if ((refData[gs_in[i].refIndex].flags & REFSURF_PLANEBACK) != 0)
		refPlaneDist = -refPlaneDist;
	gl_ClipDistance[0] = -refPlaneDist; // dot ( worldCoord.xyz, refData[ refIndex ].plane.xyz ) + refData[ refIndex ].plane.w;
}
