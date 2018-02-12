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

	if(texel.a <= 0.666)
		discard;

	// apply gamma correction and intensity
	outColor.rgb = texel.rgb;
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
