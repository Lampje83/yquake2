// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common3D.vert"
#endif

out VS_OUT {
	vec2		TexCoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat int	refIndex;
} vs;

void main()
{
	vs.TexCoord = texCoord;

	if ((surfFlags & SURF_FLOWING) != 0) {
		vs.TexCoord.s -= time / 48.0 * 32.0;
	}

	vs.WorldCoord = (transModel * vec4 ( position, 1.0 )).xyz;

	vec4 worldNormal = transModel * vec4 ( normal, 0.0f );
	vs.Normal = normalize ( worldNormal.xyz );
	vs.refIndex = refIndex + gl_InstanceID;

/*	if ( vs.refIndex >= 0 ) {
		//worldCoord = refMatrix * worldCoord;
		//vs.WorldCoord = worldCoord.xyz;
		gl_Position = transProj * transView * worldCoord;
		gl_ClipDistance[ 0 ] = dot ( worldCoord.xyz, refData[ refIndex ].plane.xyz ) - refData[ refIndex ].plane.w;
		if ( ( refData[ refIndex ].flags & REFSURF_PLANEBACK ) != 0 ) {
			gl_ClipDistance[ 0 ] = -gl_ClipDistance[ 0 ];
		}

	} else {
*/		gl_Position = transProj * transView * vec4(vs.WorldCoord, 1.0);
	float refPlaneDist;

	refPlaneDist = dot (vs.WorldCoord.xyz, refData[vs.refIndex].plane.xyz)-refData[vs.refIndex].plane.w;
	if (dot (viewPos, refData[vs.refIndex].plane.xyz)-refData[vs.refIndex].plane.w < 0)
		//if ((refData[gs_in[i].refIndex].flags & REFSURF_PLANEBACK) != 0)
		refPlaneDist = -refPlaneDist;
	gl_ClipDistance[ 0 ] = refPlaneDist; // dot ( worldCoord.xyz, refData[ refIndex ].plane.xyz ) + refData[ refIndex ].plane.w;
//	}
}
