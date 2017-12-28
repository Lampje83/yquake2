// it gets attributes and uniforms from Common3D.vert

void main()
{
	passTexCoord = texCoord + vec2(scroll, 0);
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
