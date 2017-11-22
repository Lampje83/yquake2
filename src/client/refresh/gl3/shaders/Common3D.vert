#version 150

in vec3 position;   // GL3_ATTRIB_POSITION
in vec2 texCoord;   // GL3_ATTRIB_TEXCOORD
in vec2 lmTexCoord; // GL3_ATTRIB_LMTEXCOORD
in vec4 vertColor;  // GL3_ATTRIB_COLOR
in vec3 normal;     // GL3_ATTRIB_NORMAL
in uint lightFlags; // GL3_ATTRIB_LIGHTFLAGS

out vec2 passTexCoord;

// for UBO shared between all 3D shaders
layout (std140) uniform uni3D
{
	mat4 transProj;
	mat4 transView;
	mat4 transModel;

	float scroll; // for SURF_FLOWING
	float time;
	float alpha;
	float overbrightbits;
	float particleFadeFactor;
	float _pad_1; // AMDs legacy windows driver needs this, otherwise uni3D has wrong size
	float _pad_2;
	float _pad_3;
};