// it gets attributes and uniforms from Common3D.vert

out vec4 passColor;

void main()
{
	passColor = vertColor;
	gl_Position = transProj * transView * transModel * vec4(position, 1.0);

	// abusing texCoord for pointSize, pointDist for particles
	float pointDist = texCoord.y*0.1; // with factor 0.1 it looks good.

	gl_PointSize = texCoord.x/pointDist;
}
