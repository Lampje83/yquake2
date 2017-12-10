// it gets attributes and uniforms from Common3D.frag

uniform sampler2D tex;

uniform	sampler2D refl;
uniform sampler2D refr;

in vec4 mvpVertex;
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

	float newalpha = alpha;
	if (alpha < 1)
	{
		newalpha = pow(alpha, 1.0);
		vec3 viewang = normalize(passWorldCoord.xyz - viewPos);
		float dp = dot(passNormal, viewang);

		newalpha += (1.0 - newalpha) * pow (1 + dp, 5) * 1.0;

		vec4 tmp = vec4(1.0 / mvpVertex.w);
		vec4 projCoord = mvpVertex * tmp;
		projCoord += vec4(1.0);
		projCoord *= vec4(0.5);
		projCoord = clamp(projCoord, 0.001, 0.999);	

		vec2 df;
		float intensity = brightness (texel.rgb);
		float intensityX1 = brightness (texture(tex, texw - vec2(0.004, 0)).rgb);
		float intensityX2 = brightness (texture(tex, texw + vec2(0.004, 0)).rgb);
		float intensityY1 = brightness (texture(tex, texw - vec2(0, 0.004)).rgb);
		float intensityY2 = brightness (texture(tex, texw + vec2(0, 0.004)).rgb);
		//df.x = intensity - dFdx(intensity);
		//df.y = intensity - dFdy(intensity);
		df.x = intensityX2 - intensityX1;
		df.y = intensityY2 - intensityY1;
		//df -= vec2(0.09);
		//df *= 0.1;
		texel.rgb += texture(refl, projCoord.xy + df).rgb * newalpha; // * (1.0 - (texel.a * newalpha));
	}
	// apply intensity and gamma
	texel.rgb *= intensity*0.5;
	outColor.rgb = pow(texel.rgb, vec3(gamma));
	outColor.a = texel.a*newalpha; // I think alpha shouldn't be modified by gamma and intensity
}
