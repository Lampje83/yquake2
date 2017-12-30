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

	// TODO: something about GL_BLEND vs GL_ALPHATEST etc

	// apply gamma correction
	// texel.rgb *= intensity; // TODO: really no intensity for sky?
	outColor.rgb = pow(texel.rgb, vec3(gamma));
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
