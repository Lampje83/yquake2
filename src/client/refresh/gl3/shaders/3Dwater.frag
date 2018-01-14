// it gets attributes and uniforms from Common3D.frag

uniform sampler2D tex;

uniform	sampler2DArray refl;
uniform sampler2DArray reflDepth;

in VS_OUT {
	vec2 TexCoord;
	vec3 WorldCoord;
	vec3 Normal;
} fs_in;

float brightness (vec3 color)
{
	return (color.r + color.g + color.b);
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
		vec2 delta = 1.0 / textureSize (tex, 0);

		float dp = abs(dot(fs_in.Normal, viewang));

		newalpha += (1.0 - newalpha) * pow (1 - dp, 3.0);

		vec3 bufSize = 1.0 / textureSize(refl, 0);

		vec4 projCoord = gl_FragCoord;
		projCoord.xy *= bufSize.xy;
		projCoord.z = 0;

		vec2 df;
		df.x = -brightness (texture(tex, texw + vec2(-delta.x, 0)).rgb)
			   -brightness (texture(tex, texw + vec2(-delta.x, delta.y)).rgb) / 3
			   -brightness (texture(tex, texw + vec2(-delta.x, -delta.y)).rgb) / 3
			   +brightness (texture(tex, texw + vec2(delta.x, 0)).rgb)
			   +brightness (texture(tex, texw + vec2(delta.x, delta.y)).rgb) / 3
			   +brightness (texture(tex, texw + vec2(delta.x, -delta.y)).rgb) / 3;
		df.y = -brightness (texture(tex, texw + vec2(0, -delta.y)).rgb)
			   -brightness (texture(tex, texw + vec2(delta.x, -delta.y)).rgb) / 3
			   -brightness (texture(tex, texw + vec2(-delta.x, -delta.y)).rgb) / 3
			   +brightness (texture(tex, texw + vec2(0, delta.y)).rgb)
			   +brightness (texture(tex, texw + vec2(delta.x, delta.y)).rgb) / 3
			   +brightness (texture(tex, texw + vec2(-delta.x, delta.y)).rgb) / 3;

		float intensityX2 = brightness (texture(tex, texw + vec2(delta.x, 0)).rgb);
		float intensityY1 = brightness (texture(tex, texw - vec2(0, delta.y)).rgb);
		float intensityY2 = brightness (texture(tex, texw + vec2(0, delta.y)).rgb);
		//df.x = intensityX2 - intensityX1;
		//df.y = intensityY2 - intensityY1;
		//df -= vec2(0.09);
		//df *= 0.1;

		float refldepth = 0.002 / (1.0 - texture(reflDepth, vec3(projCoord.xy, 1 + 2 * refTexture)).r);
		refldepth -= 0.002 / (1.0 - gl_FragCoord.z);
		refldepth = clamp(refldepth, 0.0, 0.125);

		projCoord.zw = projCoord.xy;
		projCoord.xy += df * refldepth;
		//projCoord.xy += df * (texture (reflDepth, vec3(projCoord.xy, 1 + 2 * refTexture)).z - gl_FragCoord.z);
		//projCoord.zw += df * (texture (reflDepth, vec3(projCoord.xy, 2 + 2 * refTexture)).z - gl_FragCoord.z);
		float refrdepth = 0.002 / (1.0 - texture(reflDepth, vec3(projCoord.zw, 2 + 2 * refTexture)).r);
		refrdepth -= 0.002 / (1.0 - gl_FragCoord.z);
		refrdepth = clamp(refrdepth, 0.0, 0.125);

		projCoord.zw += df * refrdepth;
		projCoord = clamp(projCoord, 0.0, 1.0);

		vec4 refltex = texture(refl, vec3(projCoord.xy, 1 + 2 * refTexture)) * newalpha;
		vec4 refrtex = texture(refl, vec3(projCoord.zw, 2 + 2 * refTexture)) * (1 - newalpha);
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
