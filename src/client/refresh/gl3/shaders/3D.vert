// it gets attributes and uniforms from Common3D.vert

out vec2 passTexCoord;
out vec3 passWorldCoord;
out vec3 passNormal;

void main()
{
	passTexCoord = texCoord;
	passWorldCoord = (transModel * vec4(position, 1.0)).xyz;
	vec4 worldNormal = transModel * vec4(normal, 0.0f);
	passNormal = normalize(worldNormal.xyz);

	if (length(fluidPlane.xyz) > 0)
	{
		gl_ClipDistance[0] = dot (passWorldCoord.xyz, fluidPlane.xyz) + fluidPlane.w;
	}
	else
	{
		gl_ClipDistance[0] = 0;
	}

	gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
