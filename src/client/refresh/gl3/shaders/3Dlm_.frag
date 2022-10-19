#version 430 core

#define REFSURF_PLANEBACK	2
#define REFSURF_REFRACT		4

#define SURF_FLOWING		0x40
#define SURF_WARP			0x08
#define SURF_PLANEBACK		0x02
#define SURF_UNDERWATER		128

#ifndef GLOBALFUNCS
#define GLOBALFUNCS

struct refData_s {
	mat4	refMatrix;
	vec4	color;
	vec4	plane;
	vec4	cullDistances;
	int		flags;
	float	refrindex;
	float	_pad_1;
	float	_pad_2;
};

float distToPlane (vec3 point, vec4 plane) {
	return  dot (point, plane.xyz) - plane.w;
}

float cosToSin (float value) {
	return sqrt (1 - value * value);
}

vec3 findRefractedPos (vec3 viewpos, vec3 worldpos, refData_s plane) {
	vec3	planepos[3];		/*	0 is for the view position projected on the refraction plane
								1 is for the world position projected on the refraction plane
								2 is our test case and will eventually be used
								0 and 1 are also used as buffer for the bisection method */
	float	sinV, sinW;			//	storage for our test case
	float	ior;				//	index of refraction, this gets inverted when inside the fluid
	int		i;
	float	distV, distW;
	float	start, end;

	distV = distToPlane (viewpos, plane.plane);
	distW = distToPlane (worldpos, plane.plane);

	if ((distV * distW) > 0) {
		// line doesn't cross the plane
		return worldpos;
	}

	ior = plane.refrindex;
	if ((ior == 1.0) || ior == 0.0) {
		// no refraction at all, quit
		return worldpos;
	}

	if (distW > 0) {
		// inside fluid
		ior = 1.0 / ior;
	}

	// project viewpos to plane
	planepos[0] = viewpos - distV * plane.plane.xyz;
	// project worldpos to plane
	planepos[1] = worldpos - distW * plane.plane.xyz;

	start = 0; end = 1;

	for (i = 0; i < 20; i++) {
		planepos[2] = mix (planepos[0], planepos[1], (start + end) * 0.5);
		// calculate angles
		sinV = cosToSin (abs (dot (normalize (viewpos - planepos[2]), plane.plane.xyz)));
		sinW = cosToSin (abs (dot (normalize (worldpos - planepos[2]), plane.plane.xyz)));

		if (abs (sinV - sinW * ior) < 0.001) {
			// our result is good enough
			break;
		} else {
			if ((sinV - sinW * ior) > 0) {
				// our point is too far from view position
				end = (start + end) * 0.5;
			} else {
				// our point is too far from world position
				start = (start + end) * 0.5;
			}
		}
	}

	// calculate new distances
	distV = length (viewpos - planepos[2]);
	distW = length (worldpos - planepos[2]);

	if (abs (distToPlane (planepos[2], plane.plane)) > 1)
		return worldpos;

	// now project our point beyond the newly calculated vector
	return viewpos + ((planepos[2] - viewpos) / distV) * (distV + distW);
}
#endif
//#version 430 core
#ifdef __INTELLISENSE__
#include "glsl.h"
#endif

layout (location = 0) out vec4 outColor;

// for UBO shared between all shaders (incl. 2D)
#ifndef __INTELLISENSE__
layout (std140) uniform uniCommon
{
#endif
	float gamma; // this is 1.0/vid_gamma
	float intensity;
	float intensity2D; // for HUD, menus etc

	vec4 color; // really?
#ifndef __INTELLISENSE__
};
// for UBO shared between all 3D shaders
layout (std140) uniform uni3D
{
#endif
	mat4 transProj;
	mat4 transView;
	mat4 transModel;

	vec4 skyRotate;
	vec3 viewPos;

	int		refTexture;	// which texture to draw on reflecting surface
	int		lightmapindex;
	float time;
	float alpha;
	float overbrightbits;
	float particleFadeFactor;
	uint  flags;
	float _pad_1; // AMDs legacy windows driver needs this, otherwise uni3D has wrong size
	float _pad_2;
	//float _pad_3;
#ifndef __INTELLISENSE__
};
#endif
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

in VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} fs_in;

void main()
{
	vec4 texel = texture(tex, fs_in.TexCoord);
	vec4 lmTex;

	// apply lightmap
	if (flags != 3u)
	{
		lmTex  = texture(lightmap, vec3(fs_in.LMcoord, 0 + lightmapindex)) * lmScales[0];
		lmTex += texture(lightmap, vec3(fs_in.LMcoord, 1 + lightmapindex)) * lmScales[1];
		lmTex += texture(lightmap, vec3(fs_in.LMcoord, 2 + lightmapindex)) * lmScales[2];
		lmTex += texture(lightmap, vec3(fs_in.LMcoord, 3 + lightmapindex)) * lmScales[3];
	}
	else
	{
		ivec2 lmSize = textureSize (lightmap, 0).xy;
		ivec2 LMcoord = ivec2(fs_in.LMcoord * lmSize);
		
		lmTex  = texelFetch(lightmap, ivec3(LMcoord, 0 + lightmapindex), 0) * lmScales[0];
		lmTex += texelFetch(lightmap, ivec3(LMcoord, 1 + lightmapindex), 0) * lmScales[1];
		lmTex += texelFetch(lightmap, ivec3(LMcoord, 2 + lightmapindex), 0) * lmScales[2];
		lmTex += texelFetch(lightmap, ivec3(LMcoord, 3 + lightmapindex), 0) * lmScales[3];
	}

	if(fs_in.LightFlags != 0u)
	{
		// TODO: or is hardcoding 32 better?
		for(uint i=0u; i<numDynLights; ++i)
		{
			// I made the following up, it's probably not too cool..
			// it basically checks if the light is on the right side of the surface
			// and, if it is, sets intensity according to distance between light and pixel on surface

			// dyn light number i does not affect this plane, just skip it
			if((fs_in.LightFlags & (1u << i)) == 0u)  continue;

			float intens = dynLights[i].lightColor.a;

			vec3 lightToPos = dynLights[i].lightOrigin - fs_in.WorldCoord;
			float distLightToPos = length(lightToPos);
			float fact = max(0, intens - distLightToPos - 52);

			// also factor in angle between light and point on surface
			fact *= max (0, dot (fs_in.Normal, lightToPos / distLightToPos));

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
