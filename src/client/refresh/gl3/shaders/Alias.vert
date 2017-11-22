// it gets attributes and uniforms from Common3D.vert

out vec4 passColor;

void main()
{
	passColor = vertColor*overbrightbits;
	passTexCoord = texCoord;
	gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
