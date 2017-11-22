// it gets attributes and uniforms from Common3D.frag

uniform sampler2D tex;

void main()
{
	vec4 texel = texture(tex, passTexCoord);

	// apply intensity and gamma
	texel.rgb *= intensity*0.5;
	outColor.rgb = pow(texel.rgb, vec3(gamma));
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
