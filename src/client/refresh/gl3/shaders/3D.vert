// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common3D.vert"
#endif

out VS_OUT {
	vec2		TexCoord;
	vec3		WorldCoord;
	vec3		Normal;
	float		refPlaneDist;
	flat uint	SurfFlags;
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
	gl_Position = transProj * transView * vec4(vs.WorldCoord, 1.0);
	float refPlaneDist;

	vec4 plane = refData[refIndex + gl_InstanceID].plane;
	if (distToPlane (viewPos, plane) < 0) {
		vs.refPlaneDist = -distToPlane (vs.WorldCoord.xyz, plane);
		vs.SurfFlags = surfFlags | REFSURF_PLANEBACK;
	} else {
		vs.refPlaneDist = distToPlane (vs.WorldCoord.xyz, plane);
		vs.SurfFlags = surfFlags & (~REFSURF_PLANEBACK);
	}
	gl_Position = transProj * transView * vec4(vs.WorldCoord, 1);
	//gl_ClipDistance[0] = 0.0;
}
