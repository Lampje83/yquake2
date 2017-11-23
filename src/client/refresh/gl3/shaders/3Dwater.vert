// it gets attributes and uniforms from Common3D.vert
void main()
{
	vec2 tc = texCoord;
	//tc.s += sin( texCoord.t*0.125 + time ) * 4;
	tc.s += scroll;
	//tc.t += sin( texCoord.s*0.125 + time ) * 4;
	// tc *= 1.0/64.0; // do this last
	passTexCoord = tc;

	gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
