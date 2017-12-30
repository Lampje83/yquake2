// it gets attributes and uniforms from Common3D.vert

out VS_OUT {
	vec2 TexCoord;
	vec3 WorldCoord;
	vec3 Normal;
} vs;

void main()
{
	vs.TexCoord = texCoord + vec2(scroll, 0);
	vs.WorldCoord = position.xyz;
	vec4 worldNormal = transModel * vec4(normal, 0.0f);
	vs.Normal = normalize(worldNormal.xyz);

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
