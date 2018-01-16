#version 430 core
#ifdef __INTELLISENSE__
#include "glsl.h"
#endif

in vec3 position;   // GL3_ATTRIB_POSITION
in vec2 texCoord;   // GL3_ATTRIB_TEXCOORD
in vec2 lmTexCoord; // GL3_ATTRIB_LMTEXCOORD
in vec4 vertColor;  // GL3_ATTRIB_COLOR
in vec3 normal;     // GL3_ATTRIB_NORMAL
in uint lightFlags; // GL3_ATTRIB_LIGHTFLAGS
in uint surfFlags;	// GL3_ATTRIB_SURFFLAGS
in int  refIndex;	// GL3_ATTRIB_REFINDEX

#define SURF_FLOWING	0x40
#define SURF_WARP		0x08

// for UBO shared between all 3D shaders
#ifndef __INTELLISENSE__
layout (std140) uniform uni3D
{
#endif
	mat4 transProj;
	mat4 transView;
	mat4 transModel;
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
#ifndef __INTELLISENSE__
};
#endif

#define REFSURF_PLANEBACK	2

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

#ifndef __INTELLISENSE__
layout ( std140 ) uniform refDat {
#endif
	refData_s refData[16];
#ifndef __INTELLISENSE__
};
#endif

#ifndef __INTELLISENSE__
out gl_PerVertex {
#endif
    vec4 gl_Position;
    float gl_PointSize;
    float gl_ClipDistance[1];
#ifndef __INTELLISENSE__
};
#endif
