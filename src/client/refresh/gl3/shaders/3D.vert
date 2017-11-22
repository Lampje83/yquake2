// it gets attributes and uniforms from Common3D.vert

void main()
{
	passTexCoord = texCoord;
	gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
