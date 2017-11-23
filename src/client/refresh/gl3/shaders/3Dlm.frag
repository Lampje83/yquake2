// it gets attributes and uniforms from Common3D.frag

struct DynLight { // gl3UniDynLight in C
	vec3 lightOrigin;
	float _pad;
	//vec3 lightColor;
	//float lightIntensity;
	vec4 lightColor; // .a is intensity; this way it also works on OSX...
	// (otherwise lightIntensity always contained 1 there)
};

layout (std140) uniform uniLights
{
	DynLight dynLights[32];
	uint numDynLights;
	uint _pad1; uint _pad2; uint _pad3; // FFS, AMD!
};

uniform sampler2D tex;

uniform sampler2D lightmap0;
uniform sampler2D lightmap1;
uniform sampler2D lightmap2;
uniform sampler2D lightmap3;

uniform vec4 lmScales[4];

in vec2 passLMcoord;
in vec3 passWorldCoord;
in vec3 passNormal;
flat in uint passLightFlags;

void main()
{
	vec4 texel = texture(tex, passTexCoord);
	vec4 lmTex;

	// apply intensity
	texel.rgb *= intensity;

	// apply lightmap
	if (flags != 3u)
	{
		lmTex  = texture(lightmap0, passLMcoord) * lmScales[0];
		lmTex += texture(lightmap1, passLMcoord) * lmScales[1];
		lmTex += texture(lightmap2, passLMcoord) * lmScales[2];
		lmTex += texture(lightmap3, passLMcoord) * lmScales[3];
	}
	else
	{
		// assume all lightmaps are the same size
		ivec2 lmSize = textureSize (lightmap0, 0);
		ivec2 LMcoord = ivec2(passLMcoord * lmSize);
		
		lmTex  = texelFetch(lightmap0, LMcoord, 0) * lmScales[0];
		lmTex += texelFetch(lightmap1, LMcoord, 0) * lmScales[1];
		lmTex += texelFetch(lightmap2, LMcoord, 0) * lmScales[2];
		lmTex += texelFetch(lightmap3, LMcoord, 0) * lmScales[3];
	}

	if(passLightFlags != 0u)
	{
		// TODO: or is hardcoding 32 better?
		for(uint i=0u; i<numDynLights; ++i)
		{
			// I made the following up, it's probably not too cool..
			// it basically checks if the light is on the right side of the surface
			// and, if it is, sets intensity according to distance between light and pixel on surface

			// dyn light number i does not affect this plane, just skip it
			if((passLightFlags & (1u << i)) == 0u)  continue;

			float intens = dynLights[i].lightColor.a;

			vec3 lightToPos = dynLights[i].lightOrigin - passWorldCoord;
			float distLightToPos = length(lightToPos);
			float fact = max(0, intens - distLightToPos - 52);

			// also factor in angle between light and point on surface
			fact *= max(0, dot(passNormal, lightToPos/distLightToPos));


			lmTex.rgb += dynLights[i].lightColor.rgb * fact * (1.0/256.0);
		}
	}
	if (flags == 1u)
	{
		lmTex.rgb = vec3(1.0);
	}
	else if (flags == 2u || flags == 3u)
	{
		texel.rgb = vec3(1.0);
	}
	lmTex.rgb *= overbrightbits;
	outColor = lmTex*texel;
	outColor.rgb = pow(outColor.rgb, vec3(gamma)); // apply gamma correction to result

	outColor.a = 1; // lightmaps aren't used with translucent surfaces
}
