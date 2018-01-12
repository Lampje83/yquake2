// it gets attributes and uniforms from Common3D.frag

in VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	flat int	refIndex;
} fs_in;

void main()
{
	vec4 texel = fs_in.Color;

	// apply gamma correction and intensity
	// texel.rgb *= intensity; // TODO: color-only rendering probably shouldn't use intensity?
	texel.a *= alpha; // is alpha even used here?
	outColor.rgb = pow(texel.rgb, vec3(gamma));
	outColor.a = texel.a; // I think alpha shouldn't be modified by gamma and intensity
}
