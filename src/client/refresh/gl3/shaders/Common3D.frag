#version 430 core

#define SURF_FLOWING	0x40
#define SURF_WARP		0x08

layout (location = 0) out vec4 outColor;

// for UBO shared between all shaders (incl. 2D)
layout (std140) uniform uniCommon
{
	float gamma; // this is 1.0/vid_gamma
	float intensity;
	float intensity2D; // for HUD, menus etc

	vec4 color; // really?

};
// for UBO shared between all 3D shaders
layout (std140) uniform uni3D
{
	mat4 transProj;
	mat4 transView;
	mat4 transModel;
//	vec4 fluidPlane;
//	vec4 cullDistances;
	vec3 viewPos;

	int		refTexture;	// which texture to draw on reflecting surface
	float scroll; // for SURF_FLOWING
	float time;
	float alpha;
	float overbrightbits;
	float particleFadeFactor;
	uint  flags;
	float _pad_1; // AMDs legacy windows driver needs this, otherwise uni3D has wrong size
	float _pad_2;
	//float _pad_3;
};
