// it gets attributes and uniforms from Common3D.frag

uniform sampler2D tex;

uniform	sampler2DArray refl;
// uniform sampler2D refr;

in vec3 passWorldCoord;
in vec3 passNormal;

float brightness (vec3 color)
{
	return (color.r + color.g + color.b) / 3;
}

void main()
{
	vec2 texw;
	texw.s = (passTexCoord.s + sin( passTexCoord.t * 4 + time ) * 0.0625) ;
	texw.t = (passTexCoord.t + sin( passTexCoord.s * 4 + time ) * 0.0625) ;
	vec4 texel = texture(tex, texw);

	texel.rgb *= intensity * 2.0;
	texel.rgb = pow(texel.rgb, vec3(gamma));

	float newalpha = alpha;
	if (alpha < 1)
	{
		newalpha = pow(alpha, 1.0);
		vec3 viewang = normalize(viewPos - passWorldCoord.xyz);
		float dp = dot(passNormal, viewang);

		newalpha += (1.0 - newalpha) * pow (1 - dp, 5);

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
		vec4 refltex = texture(refl, projCoord.xyz);
		texel.rgb *= vec3(1 - newalpha);

		texel.rgb += refltex.rgb * newalpha; // * (1.0 - (texel.a * newalpha));
	}
	outColor.rgb = texel.rgb;
	// apply intensity and gamma
	outColor.a = newalpha; // I think alpha shouldn't be modified by gamma and intensity
}
