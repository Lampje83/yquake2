// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "Common3D.vert"
#define VS_OUT struct
#endif

out VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} vs;

void main()
{
	vs.TexCoord = texCoord;// + vec2(scroll, 0);
	if ((surfFlags & SURF_FLOWING) != 0) {
		vs.TexCoord += vec2(time / 128.0, 0);
	}
	vs.LMcoord = lmTexCoord;
	vec4 worldCoord = transModel * vec4(position, 1.0);
	vs.WorldCoord = worldCoord.xyz;
	vec4 worldNormal = transModel * vec4(normal, 0.0f);
	vs.Normal = normalize(worldNormal.xyz);
	vs.LightFlags = lightFlags;
	vs.SurfFlags = surfFlags;
	vs.refIndex = refIndex + gl_InstanceID;
	//vs.refPlaneDist = distToRefPlane (vs.WorldCoord.xyz, refData[vs.refIndex].plane);
	vec4 plane = refData[refIndex + gl_InstanceID].plane;
	if (distToPlane (viewPos, plane) < 0) {
		gl_ClipDistance[0] = -distToPlane (vs.WorldCoord.xyz, plane);
		vs.SurfFlags = surfFlags | REFSURF_PLANEBACK;
	} else {
		gl_ClipDistance[0] = distToPlane (vs.WorldCoord.xyz, plane);
		vs.SurfFlags = surfFlags;
	}
	gl_Position = transProj * transView * worldCoord;
	// gl_ClipDistance[0] = 0.0;
}
