// it gets attributes and uniforms from Common3D.vert

out vec2 passTexCoord;
out vec3 passWorldCoord;
out vec3 passNormal;

void main()
{
	passTexCoord = texCoord + vec2(scroll, 0);
	passWorldCoord = position.xyz;
	vec4 worldNormal = transModel * vec4(normal, 0.0f);
	passNormal = normalize(worldNormal.xyz);

	gl_Position = transProj * transView * transModel * vec4(position, 1.0);

	if (length(fluidPlane.xyz) > 0)
	{
		gl_ClipDistance[0] = dot (position.xyz, fluidPlane.xyz) + fluidPlane.w;
	}
	else
	{
		gl_ClipDistance[0] = 0;
	}

}
