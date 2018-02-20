
#ifdef __INTELLISENSE__
// it gets attributes and uniforms from Common3D.frag
#define VS_OUT struct
#endif

layout (early_fragment_tests) in;

uniform sampler2D tex;

uniform	sampler2DArray refl;
uniform sampler2DArray reflDepth;

#ifndef __INTELLISENSE__
layout (std140) uniform refDat {
#endif
	refData_s refData[16];
#ifndef __INTELLISENSE__
};
#endif

in VS_OUT {
	vec2 TexCoord;
	vec3 WorldCoord;
	vec3 Normal;
	flat uint	SurfFlags;
	flat int	refIndex;
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

	texel.rgb /= intensity;

	float newalpha = pow(alpha, 2.0);

	if (alpha < 1)
	{
		vec3 viewang = normalize(viewPos - fs_in.WorldCoord.xyz);
		vec2 delta = 1.0 / textureSize (tex, 0);
		vec4 plane = refData[refTexture].plane;

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
			   +brightness (texture(tex, texw + vec2(delta.x, -delta.y)).rgb) / 3
				;
		df.y = -brightness (texture(tex, texw + vec2(0, -delta.y)).rgb)
			   -brightness (texture(tex, texw + vec2(delta.x, -delta.y)).rgb) / 3
			   -brightness (texture(tex, texw + vec2(-delta.x, -delta.y)).rgb) / 3
			   +brightness (texture(tex, texw + vec2(0, delta.y)).rgb)
			   +brightness (texture(tex, texw + vec2(delta.x, delta.y)).rgb) / 3
			   +brightness (texture(tex, texw + vec2(-delta.x, delta.y)).rgb) / 3
				;

		float dp = abs (dot (normalize(fs_in.Normal + vec3(df, 0.0) * 0.15), viewang));

		newalpha += (1.0 - newalpha) * pow (1 - dp, 3.0);
		if (plane.z < 0) { plane = -plane; }
		if ((dot (plane.xyz, viewPos) - plane.w) < 0) {
			// total internal reflection
			if ((cosToSin (dp) * 1.333) > 0.99) {
				newalpha = mix(newalpha, 1.0, clamp((cosToSin(dp) * 1.333 - 0.99) * 100.0, 0, 1));
			}
		}
		if (plane.z > 0) { plane = -plane; }

		float refldepth;
		if (fs_in.refIndex == -1) {
			refldepth = 0.002 / (1.0 - texture (reflDepth, vec3 (projCoord.xy, 1 + refTexture)).r);
			refldepth -= 0.002 / (1.0 - gl_FragCoord.z);
		}
		else {
			refldepth = 0.05;
		}

		projCoord.zw = projCoord.xy;
		projCoord.xy += df * clamp(refldepth, 0.0, 0.125);
		//projCoord.xy += df * (texture (reflDepth, vec3(projCoord.xy, 1 + refTexture)).z - gl_FragCoord.z);
		//projCoord.zw += df * (texture (reflDepth, vec3(projCoord.xy, 2 + refTexture)).z - gl_FragCoord.z);
		float refrdepth;
		if (fs_in.refIndex == -1) {
			refrdepth = 0.002 / (1.0 - texture (reflDepth, vec3 (projCoord.zw, 2 + refTexture)).r);
			refrdepth -= 0.002 / (1.0 - gl_FragCoord.z);
		}
		else {
			refrdepth = 0.1;
		}

		projCoord.zw += df * clamp(refrdepth, 0.0, 0.25);
		projCoord = clamp(projCoord, 0.0, 1.0);

		vec4 refltex = texture(refl, vec3(projCoord.xy, 1 + refTexture)) * newalpha;
		vec4 refrtex = texture(refl, vec3(projCoord.zw, 2 + refTexture)) * (1 - newalpha);
		//texel.rgb *= vec3(1 - newalpha);
		if (plane.z < 0) { plane = -plane; }
		if ((dot(plane.xyz, viewPos) - plane.w) < 0) {
			// we are under water
			refrdepth = length(fs_in.WorldCoord - viewPos) / 1000;
		}
		texel.rgb *= clamp (1.0 - pow (0.95, refrdepth * 80.0), 0.0, 1.0);
		// debug
		// texel += vec3(((refTexture + 1) & 1) / 1, ((refTexture + 1) & 6) / 6.0, ((refTexture + 1) & 8) / 8.0) * 0.25;
		texel.rgb += refltex.rgb; // * (1.0 - (texel.a * newalpha));
		texel.rgb += refrtex.rgb *clamp (pow (0.95, refrdepth * 80.0), 0.0, 1.0);
	}
	outColor.rgb = texel.rgb;
	outColor.a = 1;//newalpha; // I think alpha shouldn't be modified by gamma and intensity
}
