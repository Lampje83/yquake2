// it gets attributes and uniforms from Common3D.frag
#ifdef __INTELLISENSE__
#include "Common.glsl"
#include "Common3D.frag"
#endif

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
uniform sampler2DArray lightmap;
uniform vec4 lmScales[4];

in Vx3Dlm gs_out;

void main()
{
	vec4 texel = texture(tex, gs_out.TexCoord);
	vec4 lmTex;

	// apply lightmap
	if (flags != 3u)
	{
		lmTex  = texture(lightmap, vec3(gs_out.LMcoord, 0 + lightmapindex)) * lmScales[0];
		lmTex += texture(lightmap, vec3(gs_out.LMcoord, 1 + lightmapindex)) * lmScales[1];
		lmTex += texture(lightmap, vec3(gs_out.LMcoord, 2 + lightmapindex)) * lmScales[2];
		lmTex += texture(lightmap, vec3(gs_out.LMcoord, 3 + lightmapindex)) * lmScales[3];
	}
	else
	{
		ivec2 lmSize = textureSize (lightmap, 0).xy;
		ivec2 LMcoord = ivec2(gs_out.LMcoord * lmSize);
		
		lmTex  = texelFetch(lightmap, ivec3(LMcoord, 0 + lightmapindex), 0) * lmScales[0];
		lmTex += texelFetch(lightmap, ivec3(LMcoord, 1 + lightmapindex), 0) * lmScales[1];
		lmTex += texelFetch(lightmap, ivec3(LMcoord, 2 + lightmapindex), 0) * lmScales[2];
		lmTex += texelFetch(lightmap, ivec3(LMcoord, 3 + lightmapindex), 0) * lmScales[3];
	}

	if(gs_out.LightFlags != 0u)
	{
		// TODO: or is hardcoding 32 better?
		for(uint i=0u; i<numDynLights; ++i)
		{
			// I made the following up, it's probably not too cool..
			// it basically checks if the light is on the right side of the surface
			// and, if it is, sets intensity according to distance between light and pixel on surface

			// dyn light number i does not affect this plane, just skip it
			if((gs_out.LightFlags & (1u << i)) == 0u)  continue;

			float intens = dynLights[i].lightColor.a;

			vec3 lightToPos = dynLights[i].lightOrigin - gs_out.WorldCoord;
			float distLightToPos = length(lightToPos);
			float fact = max(0, intens - distLightToPos - 52);

			// also factor in angle between light and point on surface
			fact *= max (0, dot (gs_out.Normal, lightToPos / distLightToPos));

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

	outColor.a = 1; // lightmaps aren't used with translucent surfaces
}
