// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "Common3D.vert"
#endif

out VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat uint	LightFlags;
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
	vs.refIndex = refIndex + gl_InstanceID;

	gl_Position = transProj * transView * worldCoord;
	gl_ClipDistance[0] = 0.0;
}
