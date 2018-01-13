// it gets attributes and uniforms from Common3D.frag

uniform sampler2D tex;

uniform	sampler2DArray refl;
// uniform sampler2D refr;

in VS_OUT {
	vec2 TexCoord;
	vec3 WorldCoord;
	vec3 Normal;
} fs_in;

float brightness (vec3 color)
{
	return (color.r + color.g + color.b) / 3;
}

void main()
{
	vec2 texw;

	// Apply water warp
	texw.s = (fs_in.TexCoord.s + sin( fs_in.TexCoord.t * 4 + time ) * 0.0625) ;
	texw.t = (fs_in.TexCoord.t + sin( fs_in.TexCoord.s * 4 + time ) * 0.0625) ;
	vec4 texel = texture(tex, texw);

	texel.rgb *= intensity * 1.0;
	texel.rgb = pow(texel.rgb, vec3(gamma));

	float newalpha = pow(alpha, 3.0);

	if (alpha < 1)
	{
		vec3 viewang = normalize(viewPos - fs_in.WorldCoord.xyz);
		float dp = abs(dot(fs_in.Normal, viewang));

		newalpha += (1.0 - newalpha) * pow (1 - dp, 3.0);

		vec3 bufSize = 1.0 / textureSize(refl, 0);

		vec4 projCoord = gl_FragCoord;
		projCoord.xy *= bufSize.xy;
		projCoord.z = 0;

		vec2 df;
		float intens = brightness (texel.rgb);
		float intensityX1 = brightness (texture(tex, texw - vec2(0.004, 0)).rgb);
		float intensityX2 = brightness (texture(tex, texw + vec2(0.004, 0)).rgb);
		float intensityY1 = brightness (texture(tex, texw - vec2(0, 0.004)).rgb);
		float intensityY2 = brightness (texture(tex, texw + vec2(0, 0.004)).rgb);
		df.x = intensityX2 - intensityX1;
		df.y = intensityY2 - intensityY1;
		//df -= vec2(0.09);
		//df *= 0.1;

		projCoord.xy += df;
		projCoord = clamp(projCoord, 0.0, 1.0);	
		vec4 refltex = texture(refl, vec3(projCoord.xy, 1 + 2 * refTexture)) * newalpha;
		vec4 refrtex = texture(refl, vec3(projCoord.xy, 2 + 2 * refTexture)) * (1 - newalpha);
		texel.rgb *= vec3(1 - newalpha);

		// debug
		// texel += vec3(((refTexture + 1) & 1) / 1, ((refTexture + 1) & 6) / 6.0, ((refTexture + 1) & 8) / 8.0) * 0.25;
		texel.rgb += refltex.rgb; // * (1.0 - (texel.a * newalpha));
		texel.rgb += refrtex.rgb;
	}
	outColor.rgb = texel.rgb;
	// apply intensity and gamma
	outColor.a = 1;//newalpha; // I think alpha shouldn't be modified by gamma and intensity
}
