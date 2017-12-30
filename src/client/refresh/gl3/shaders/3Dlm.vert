// it gets attributes and uniforms from Common3D.vert

out vec2 passTexCoord;
out vec2 passLMcoord;
out vec3 passWorldCoord;
out vec3 passNormal;
flat out uint passLightFlags;

void main()
{
	passTexCoord = texCoord;
	passLMcoord = lmTexCoord;
	vec4 worldCoord = transModel * vec4(position, 1.0);
	passWorldCoord = worldCoord.xyz;
	vec4 worldNormal = transModel * vec4(normal, 0.0f);
	passNormal = normalize(worldNormal.xyz);
	passLightFlags = lightFlags;

	gl_Position = transProj * transView * worldCoord;

	if (length(fluidPlane.xyz) > 0)
	{
		gl_ClipDistance[0] = dot (worldCoord.xyz, fluidPlane.xyz) + fluidPlane.w;
	}
	else
	{
		gl_ClipDistance[0] = 0;
	}
}
