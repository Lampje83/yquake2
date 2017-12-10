// it gets attributes and uniforms from Common3D.vert

out vec4 passColor;
out vec3 passWorldCoord;

void main()
{
	vec4 tmp;
	tmp = transModel * vec4(position, 1.0);
	passWorldCoord = tmp.xyz;
	passColor = vertColor*overbrightbits;
	passTexCoord = texCoord;
	gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
