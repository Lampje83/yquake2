// it gets attributes and uniforms from Common3D.frag

in VS_OUT {
	vec2 TexCoord;
	vec3 WorldCoord;
	vec3 Normal;
} fs_in;
uniform sampler2D tex;

void main()
{
	vec4 texel = texture(tex, fs_in.TexCoord);

	// apply gamma correction and intensity
	texel.rgb *= intensity;
	outColor.rgb = pow(texel.rgb, vec3(gamma));
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
