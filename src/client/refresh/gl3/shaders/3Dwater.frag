// it gets attributes and uniforms from Common3D.frag

uniform sampler2D tex;

void main()
{
	vec2 texw;
	texw.s = (passTexCoord.s + sin( passTexCoord.t*0.0625 + time ) * 4.0) / 64.0;
	texw.t = (passTexCoord.t + sin( passTexCoord.s*0.0625 + time ) * 4.0) / 64.0;
	vec4 texel = texture(tex, texw);

	// apply intensity and gamma
	texel.rgb *= intensity*0.5;
	outColor.rgb = pow(texel.rgb, vec3(gamma));
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
