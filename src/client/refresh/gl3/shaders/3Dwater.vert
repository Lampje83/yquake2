// it gets attributes and uniforms from Common3D.vert

out	vec4 mvpVertex;
out vec3 passWorldCoord;
out vec3 passNormal;

void main()
{
	vec2 tc = texCoord;
	//tc.s += sin( texCoord.t*0.125 + time ) * 4;
	tc.s += scroll;
	//tc.t += sin( texCoord.s*0.125 + time ) * 4;
	// tc *= 1.0/64.0; // do this last
	passTexCoord = tc;
	passWorldCoord = position.xyz;
	vec4 worldNormal = transModel * vec4(normal, 0.0f);
	passNormal = normalize(worldNormal.xyz);

	mvpVertex = transProj * transView * transModel * vec4(position, 1.0);
	gl_Position = transProj * transView * transModel * vec4(position, 1.0);
}
