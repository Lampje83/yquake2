// it gets attributes and uniforms from Common3D.frag

in Vx3Dal gs_out;

void main()
{
	vec4 texel = gs_out.Color;

	// apply gamma correction and intensity
	// texel.rgb *= intensity; // TODO: color-only rendering probably shouldn't use intensity?
	texel.a *= alpha; // is alpha even used here?
	outColor.rgb = pow(texel.rgb, vec3(gamma));
	outColor.a = texel.a; // I think alpha shouldn't be modified by gamma and intensity
}
