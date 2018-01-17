#version 430 core
#ifdef __INTELLISENSE__
#include "glsl.h"
#endif

layout (triangles) in;
layout (triangle_strip, max_vertices = 6) out;

// for UBO shared between all 3D shaders
#ifndef __INTELLISENSE__
layout (std140) uniform uni3D {
#endif
	mat4 transProj;
	mat4 transView;
	mat4 transModel;
	//	vec4 fluidPlane;
	//	vec4 cullDistances;
	vec3 viewPos;

	int		refTexture;
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
#define REFSURF_UNDERWATER	128

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
layout (std140) uniform refDat {
#endif
	refData_s refData[16];
#ifndef __INTELLISENSE__
};
#endif

#ifdef __INTELLISENSE__
typedef
#endif
in gl_PerVertex {
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[1];
} gl_in[];

out gl_PerVertex {
	vec4 gl_Position;
	float gl_PointSize;
	float gl_ClipDistance[1];
};

int count;

float refPlaneDist[6];

void writeVertexData (int index);

/*
mat4 rotationMatrix (vec3 axis, float angle) {
	axis = normalize (axis);
	float s = sin (angle);
	float c = cos (angle);
	float oc = 1.0 - c;

	return mat4 (oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0.0,
		oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 0.0,
		oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c, 0.0,
		0.0, 0.0, 0.0, 1.0);
}

void OutputNormalPrimitive () {

}

void OutputReflectedPrimitive () {

}

void OutputRefractedPrimitive () {

}
*/