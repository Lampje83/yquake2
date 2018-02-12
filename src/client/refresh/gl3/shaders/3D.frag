// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;
uniform	sampler2DArray refl;
uniform sampler2DArray reflDepth;

in VS_OUT {
	vec2 TexCoord;
	vec3 WorldCoord;
	vec3 Normal;
} fs_in;

void main()
{
	vec4 texel = texture(tex, fs_in.TexCoord);

	texel.rgb /= intensity;

	float newalpha = alpha;
	if (alpha < 1)
	{
		vec3 viewang = normalize(viewPos - fs_in.WorldCoord.xyz);
		float dp = dot(fs_in.Normal, viewang);

		newalpha += (1.0 - alpha) * pow (1 - dp, 3);

		vec3 bufSize = 1.0 / textureSize(refl, 0);

		vec4 projCoord = gl_FragCoord;
		projCoord.xy *= bufSize.xy;
		projCoord.z = 1 + 2 * refTexture;

		vec4 refltex = texture(refl, projCoord.xyz) * newalpha;
		texel.rgb *= vec3(1 - newalpha);
		// debug
		//texel += vec3(((refTexture + 1) & 1) / 1, ((refTexture + 1) & 6) / 6.0, ((refTexture + 1) & 8) / 8.0) * 0.25;

		texel.rgb += refltex.rgb; // * (1.0 - (texel.a * newalpha));
		texel.rgb += texture(refl, vec3(projCoord.xy, projCoord.z + 1)).rgb * (1 - newalpha);
	}

	outColor.rgb = texel.rgb;
	outColor.a = 1; //texel.a*newalpha; // I think alpha shouldn't be modified by gamma and intensity
}
