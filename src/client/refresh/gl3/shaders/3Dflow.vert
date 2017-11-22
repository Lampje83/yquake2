// it gets attributes and uniforms from Common3D.vert

void main()
{
	passTexCoord = texCoord + vec2(scroll, 0);
	gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
