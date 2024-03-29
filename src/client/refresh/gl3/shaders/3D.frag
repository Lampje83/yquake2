#ifdef __INTELLISENSE__
#include "Common3D.frag"
#endif

// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;
uniform	sampler2DArray refl;
uniform sampler2DArray reflDepth;

in Vx3D gs_out;

void main()
{
	vec4 texel = texture(tex, gs_out.TexCoord);

	texel.rgb /= intensity;

	float newalpha = alpha;
	if (alpha < 1)
	{
		vec3 viewang = normalize(viewPos - gs_out.WorldCoord.xyz);
		float dp = dot(gs_out.Normal, viewang);

		newalpha += (1.0 - alpha) * pow (1 - dp, 3);

		vec3 bufSize = 1.0 / textureSize(refl, 0);

		vec4 projCoord = gl_FragCoord;
		projCoord.xy *= bufSize.xy;
		projCoord.z = 1 + refTexture;

		//vec4 refltex = texture(refl, projCoord.xyz) * newalpha;
		//texel.rgb *= vec3(1 - newalpha);
		texel.rgb = mix (texel.rgb, texture (refl, projCoord.xyz).rgb, newalpha);
		// debug
		//texel += vec3(((refTexture + 1) & 1) / 1, ((refTexture + 1) & 6) / 6.0, ((refTexture + 1) & 8) / 8.0) * 0.25;

		//texel.rgb += refltex.rgb; // * (1.0 - (texel.a * newalpha));
		//texel.rgb += texture(refl, vec3(projCoord.xy, projCoord.z + 1)).rgb * (1 - newalpha);
	}
	texel.a *= newalpha;
	outColor = texel;
}
