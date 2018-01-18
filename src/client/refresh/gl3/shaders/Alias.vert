// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "Common3D.vert"
#endif

out VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	float		refPlaneDist;
	flat uint	SurfFlags;
	flat int	refIndex;
} vs;

void main()
{
	vs.TexCoord = texCoord;
	vs.Color = vertColor*overbrightbits;

	vec4 worldCoord = transModel * vec4 ( position, 1.0 );

	vs.WorldCoord = worldCoord.xyz;
	vs.refIndex = refIndex + gl_InstanceID;

	vec4 plane = refData[refIndex + gl_InstanceID].plane;
	if (distToPlane (viewPos, plane) < 0) {
		vs.refPlaneDist = -distToPlane (vs.WorldCoord.xyz, plane);
		vs.SurfFlags = surfFlags | REFSURF_PLANEBACK;
	} else {
		vs.refPlaneDist = distToPlane (vs.WorldCoord.xyz, plane);
		vs.SurfFlags = surfFlags;
	}
	gl_Position = transProj * transView * worldCoord;
	gl_ClipDistance[0] = 0.0;
}
