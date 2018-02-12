// it gets attributes and uniforms from Common3D.frag

in vec4 passColor;

void main()
{
	vec2 offsetFromCenter = 2.0*(gl_PointCoord - vec2(0.5, 0.5)); // normalize so offset is between 0 and 1 instead 0 and 0.5
	float distSquared = dot(offsetFromCenter, offsetFromCenter);
	if(distSquared > 1.0) // this makes sure the particle is round
		discard;

	outColor.rgb = passColor.rgb / intensity;
	outColor.a = passColor.a * min (1.0, particleFadeFactor*(1.0 - distSquared));
}
