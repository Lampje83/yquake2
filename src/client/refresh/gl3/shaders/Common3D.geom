//#version 430 core
#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common.glsl"
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

#define LDBL_EPSILON 1.084202172485504434E-19
// #define M_SQRT3 1.7320508075688772935274463L   // sqrt(3)
#define M_SQRT3_2 0.8660254037844386467637231   // sqrt(3)/2
// #define DBL_EPSILON  2.2204460492503131E-16    // 2^-52  typically defined in the compiler's float.h
#define ZERO_PLUS   8.88178419700125232E-16      // 2^-50 = 4*DBL_EPSILON
#define ZERO_MINUS -8.88178419700125232E-16
#define TINY_VALUE  1.0E-30                      // This is what we use to test for zero. Usually to avoid divide by zero.
#define M_PI 3.1415926535897932384626433832795
#define M_PI_2 M_PI / 2.0

// int QuadCubicRoots (long double *Coeff, int N, long double *RealRoot, long double *ImagRoot);
//void QuadRoots (double P[3], dvec2 RealPart, dvec2 ImagPart);
//void CubicRoots (double P[5], dvec4 RealPart, dvec4 ImagPart);
void BiQuadRoots (double P[5], out dvec4 RealPart, out dvec4 ImagPart);
void ReversePoly (inout double P[5], int N);
void ReversePoly (inout double P[4], int N);
void InvertRoots (int N, inout dvec4 RealRoot, inout dvec4 ImagRoot);

float cosToSin (float value) {
	return sqrt (1 - value * value);
}

vec3 findRefractedPos (vec3 viewpos, vec3 worldpos, refData_s plane) {
#if 1
	vec3 dir		= normalize (worldpos - viewpos);			// original viewing direction
	float dist		= distToPlane (viewpos, plane.plane);		// distance from view to plane
	float worldDist = distToPlane (worldpos, plane.plane);		// distance from point to plane
	float len		= length (worldpos - viewpos);
	float dotPlane	= dot (plane.plane.xyz, dir);
	// point where original view ray intersects with the plane
	vec3 planePos = mix (viewpos, worldpos, abs (dist) / len);
	
	if (plane.refrindex == 1.0) {
		// index of refraction is negliable, don't refract
		return worldpos;
	}

	if (abs (dot (dir, plane.plane.xyz)) > 0.997) {
		// perpendicular to plane, refraction is negliable
		return worldpos;
	}

	if (dist * worldDist > 0) {
		// ray from view to world doesn't cross plane
		return worldpos;
	}

	if (abs (worldDist) < 0.01) {
		// distance to plane negliable
		return worldpos;
	}
	
	// check on which side of the fluid interface we are
	bool outsideFluid = (dist > 0); // TODO: real detection of under/above water
	vec3 startpos, endpos;
	if (outsideFluid) {
		startpos = viewpos; endpos = worldpos;
	} else { // swap positions to get the same result
		float tempdist = dist;
		dist = worldDist;
		worldDist = tempdist;
		startpos = worldpos; endpos = viewpos;
		dir = -dir;
	}

	// copy original intersection point
	vec3	newPlanePos, startPlanePos;
	float	sinview, sinworld;
	int		iteration;
	float	corrFactor = 0.05 + abs (dot (dir, plane.plane.xyz)) * 1.2;	// start with initial correction factor
	float	oldCorrFactor;											// found by trial and error
	startPlanePos = endpos + plane.plane.xyz * abs(worldDist);
	vec3	moveVec = startPlanePos - planePos;

	//dist = abs (dist);
	//worldDist = abs (worldDist);

	for (iteration = 1; iteration < 10; iteration ++) {
		// newPlanePos += (1 - (1 / plane.refrindex));
		newPlanePos = startPlanePos - moveVec / plane.refrindex * corrFactor;
		sinview = cosToSin(abs(dot (normalize (newPlanePos - startpos), normalize (plane.plane.xyz))));
		sinworld = cosToSin(abs(dot (normalize (endpos - newPlanePos), normalize (plane.plane.xyz))));

		if (abs (sinview * plane.refrindex - sinworld) < 0.01) {
			// result is good enough, quit
			break;
		} else {
			// correct result
			oldCorrFactor = corrFactor;
			corrFactor *= pow ((sinview / sinworld) / plane.refrindex, (abs(dist) / len) + cosToSin (abs (dotPlane)) * (1.0 - iteration * 0.1));
		}
		if (abs (corrFactor - oldCorrFactor) < 0.01) {
			// no further correction possible
			break;
		}
	}
#else
	vec3	newPlanePos;
	double	height;			// distance from viewpos to worldpos along plane normal
	double	planedist;		// distance from viewpos to plane
	double	width;			// distance from viewpos to worldpos perpendicular to plane normal
	vec3	startPlanePos; 
	vec3	moveVec;		// vector projected along plane
	double	ior;
	double	P[5];			// the factors for quartic function
	dvec4	real, imag;
	int		i;

	height = dot (worldpos - viewpos, plane.plane.xyz);
	planedist = double (distToPlane (viewpos, plane.plane));
	moveVec = worldpos + (plane.plane.xyz * float(height)) - viewpos;
	width = length(moveVec);
	ior = double(plane.refrindex);
	//if (plane.plane.z < 0) ior = 1.0 / ior;	// assume we are underwater when reflection plane normal has a negative z

	// check if refraction needs to be calculated
	if ((abs (width) < 0.0001) || (abs (height) < 0.0001) || (abs (ior - 1.0) < 0.001)) {
		return worldpos;
	}

	P[0] = 1.0;
	P[1] = -2.0 * width;
	P[2] = (2.0 * height * planedist - (height * height)) / ((ior * ior) - 1.0) + (planedist * planedist + width * width);
	P[3] = -2.0 * ior * ior * planedist * planedist * width / ((ior * ior) - 1.0);
	P[4] = ior * ior * planedist * planedist * width * width / ((ior * ior) - 1.0);

	BiQuadRoots (P, real, imag);

	for (i = 0; i < 4; i++) {
		// search for sane solution
		if (width > 0) {
			if ((real[i] > 0) && (real[i] < width) && (abs (imag[i]) < 0.001)) { break; }
		} else {
			if ((real[i] < 0) && (real[i] > width) && (abs (imag[i]) < 0.001)) { break; }
		}
	}
	if (i == 4) { return worldpos; }	// no sane solution. shouldn't get here

	newPlanePos = viewPos - plane.plane.xyz * float(planedist) + normalize (moveVec) * float(real[i]);
#endif
	return newPlanePos + normalize (newPlanePos - viewpos) * length (worldpos - newPlanePos);
	//vec3 newDir = normalize (newPlanePos - viewPos);
	//return newPlanePos + newDir * abs(worldDist)*abs (dot (newDir, plane.plane.xyz));
	// test case
	//return planePos + normalize (planePos - viewpos) * length (worldpos - planePos);
}


// This function is the quadratic formula with P[0] = 1
// y = P[0]*x^2 + P[1]*x + P[2]
// Normally, we don't allow P[2] = 0, but this can happen in a call from BiQuadRoots.
// If P[2] = 0, the zero is returned in RealRoot[0].
void QuadRoots (double P[4], out dvec2 RealRoot, out dvec2 ImagRoot) {
	double D;
	D = P[1] * P[1] - 4.0*P[2];
	if (D >= 0.0)  // 1 or 2 real roots
	{
		RealRoot[0] = (-P[1] - sqrt (D)) * 0.5;   // = -P[1] if P[2] = 0
		RealRoot[1] = (-P[1] + sqrt (D)) * 0.5;   // = 0 if P[2] = 0
		ImagRoot[0] = ImagRoot[1] = 0.0;
	} else // 2 complex roots
	{
		RealRoot[0] = RealRoot[1] = -P[1] * 0.5;
		ImagRoot[0] = sqrt (-D) * 0.5;
		ImagRoot[1] = -ImagRoot[0];
	}
}

//---------------------------------------------------------------------------
// This finds the roots of y = P0x^3 + P1x^2 + P2x+ P3   P[0] = 1
void CubicRoots (double P[4], out dvec4 RealRoot, out dvec4 ImagRoot) {
	int j;
	double  s, t, b, c, d, Scalar;
	bool CubicPolyReversed = false;

	// Scale the polynomial so that P[N] = +/-1. This moves the roots toward unit circle.
	Scalar = pow (float(abs (P[3])), 1.0 / 3.0);
	for (j = 1; j <= 3; j++) P[j] /= pow (float(Scalar), float(j));

	if (abs (P[3]) < abs (P[2]) && P[2] > 0.0) {
		ReversePoly (P, 3);
		CubicPolyReversed = true;
	}

	s = P[1] / 3.0;
	b = (6.0*P[1] * P[1] * P[1] - 27.0*P[1] * P[2] + 81.0*P[3]) / 162.0;
	t = (P[1] * P[1] - 3.0*P[2]) / 9.0;
	c = t * t * t;
	d = 2.0*P[1] * P[1] * P[1] - 9.0*P[1] * P[2] + 27.0*P[3];
	d = d * d / 2916.0 - c;

	// if(d > 0) 1 complex and 1 real root. We use LDBL_EPSILON to account for round off err.
	if (d > LDBL_EPSILON) {
		d = pow (float(sqrt (d) + abs (b)), 1.0 / 3.0);
		if (d != 0.0) {
			if (b>0) b = -d;
			else b = d;
			c = t / b;
		}
		d = M_SQRT3_2 * (b - c);
		b = b + c;
		c = -b / 2.0 - s;

		RealRoot[0] = (b - s);
		ImagRoot[0] = 0.0;
		RealRoot[1] = RealRoot[2] = c;
		ImagRoot[1] = d;
		ImagRoot[2] = -ImagRoot[1];
	}

	else // d < 0.0  3 real roots
	{
		if (b == 0.0)d = M_PI_2 / 3.0; //  b can be as small as 1.0E-25
		else d = atan (float(sqrt (abs (d)) / abs (b))) / 3.0;

		if (b < 0.0) b = 2.0 * sqrt (abs (t));
		else        b = -2.0 * sqrt (abs (t));

		c = cos (float(d)) * b;
		t = -M_SQRT3_2 * sin (float(d)) * b - 0.5 * c;

		RealRoot[0] = (t - s);
		RealRoot[1] = -(t + c + s);
		RealRoot[2] = (c - s);
		ImagRoot[0] = 0.0;
		ImagRoot[1] = 0.0;
		ImagRoot[2] = 0.0;
	}

	// If we reversed the poly, the roots need to be inverted.
	if (CubicPolyReversed)InvertRoots (3, RealRoot, ImagRoot);

	// Apply the Scalar to the roots.
	for (j = 0; j<3; j++)RealRoot[j] *= Scalar;
	for (j = 0; j<3; j++)ImagRoot[j] *= Scalar;
}

//---------------------------------------------------------------------------

// This finds the roots of  y = P0x^4 + P1x^3 + P2x^2 + P3x + P4    P[0] = 1
// This function calls CubicRoots and QuadRoots
void BiQuadRoots (double P[5], out dvec4 RealRoot, out dvec4 ImagRoot) {
	int j;
	double a, b, c, d, e, Q3Limit, Scalar, Q[4], MinRoot;
	bool QuadPolyReversed = false;

	// Scale the polynomial so that P[N] = +/- 1. This moves the roots toward unit circle.
	Scalar = pow (float(abs (P[4])), 0.25);
	for (j = 1; j <= 4; j++)P[j] /= pow (float(Scalar), float(j));

	// Having P[1] < P[3] helps with the Q[3] calculation and test.
	if (abs (P[1]) > abs (P[3])) {
		ReversePoly (P, 4);
		QuadPolyReversed = true;
	}

	a = P[2] - P[1] * P[1] * 0.375;
	b = P[3] + P[1] * P[1] * P[1] * 0.125 - P[1] * P[2] * 0.5;
	c = P[4] + 0.0625*P[1] * P[1] * P[2] - 0.01171875*P[1] * P[1] * P[1] * P[1] - 0.25*P[1] * P[3];
	e = P[1] * 0.25;

	Q[0] = 1.0;
	Q[1] = P[2] * 0.5 - P[1] * P[1] * 0.1875;
	Q[2] = (P[2] * P[2] - P[1] * P[1] * P[2] + 0.1875*P[1] * P[1] * P[1] * P[1] - 4.0*P[4] + P[1] * P[3]) * 0.0625;
	Q[3] = -b * b*0.015625;


	/* The value of Q[3] can cause problems when it should have calculated to zero (just above) but
	is instead ~ -1.0E-17 because of round off errors. Consequently, we need to determine whether
	a tiny Q[3] is due to roundoff, or if it is legitimately small. It can legitimately have values
	of ~ -1E-28. When this happens, we assume Q[2] should also be small. Q[3] can also be tiny with
	2 sets of equal real roots. Then P[1] and P[3], are approx equal. */

	Q3Limit = ZERO_MINUS;
	if (abs (abs (P[1]) - abs (P[3])) >= ZERO_PLUS &&
		Q[3] > ZERO_MINUS && abs (Q[2]) < 1.0E-5) Q3Limit = 0.0;

	if (Q[3] < Q3Limit && abs (Q[2]) < 1.0E20*abs (Q[3])) {
		CubicRoots (Q, RealRoot, ImagRoot);

		// Find the smallest positive real root. One of the real roots is always positive.
		MinRoot = 1.0E100;
		for (j = 0; j<3; j++) {
			if (ImagRoot[j] == 0.0 && RealRoot[j] > 0 && RealRoot[j] < MinRoot)MinRoot = RealRoot[j];
		}

		d = 4.0*MinRoot;
		a += d;
		if (a*b < 0.0)Q[1] = -sqrt (d);
		else         Q[1] = sqrt (d);
		b = 0.5 * (a + b / Q[1]);
	} else {
		if (Q[2] < 0.0)  // 2 sets of equal imag roots
		{
			b = sqrt (abs (c));
			d = b + b - a;
			if (d > 0.0)Q[1] = sqrt (abs (d));
			else       Q[1] = 0.0;
		} else {
			if (Q[1] > 0.0)b = 2.0*sqrt (abs (Q[2])) + Q[1];
			else          b = -2.0*sqrt (abs (Q[2])) + Q[1];
			Q[1] = 0.0;
		}
	}

	// Calc the roots from two 2nd order polys and subtract e from the real part.
	if (abs (b) > 1.0E-8) {
		Q[2] = c / b;
		QuadRoots (Q, RealRoot.xy, ImagRoot.xy);

		Q[1] = -Q[1];
		Q[2] = b;
		QuadRoots (Q, RealRoot.zw, ImagRoot.zw);

		for (j = 0; j<4; j++)RealRoot[j] -= e;
	} else // b==0 with 4 equal real roots
	{
		for (j = 0; j<4; j++)RealRoot[j] = -e;
		for (j = 0; j<4; j++)ImagRoot[j] = 0.0;
	}

	// If we reversed the poly, the roots need to be inverted.
	if (QuadPolyReversed)InvertRoots (4, RealRoot, ImagRoot);

	// Apply the Scalar to the roots.
	for (j = 0; j<4; j++)RealRoot[j] *= Scalar;
	for (j = 0; j<4; j++)ImagRoot[j] *= Scalar;
}

//---------------------------------------------------------------------------

// A reversed polynomial has its roots at the same angle, but reflected about the unit circle.
void ReversePoly (inout double P[5], int N) {
	int j;
	double Temp;
	for (j = 0; j <= N / 2; j++) {
		Temp = P[j];
		P[j] = P[N - j];
		P[N - j] = Temp;
	}
	if (P[0] != 0.0) {
		for (j = N; j >= 0; j--)P[j] /= P[0];
	}
}

void ReversePoly (inout double P[4], int N) {
	int j;
	double Temp;
	for (j = 0; j <= N / 2; j++) {
		Temp = P[j];
		P[j] = P[N - j];
		P[N - j] = Temp;
	}
	if (P[0] != 0.0) {
		for (j = N; j >= 0; j--)P[j] /= P[0];
	}
}

//---------------------------------------------------------------------------
// This is used in conjunction with ReversePoly
void InvertRoots (int N, inout dvec4 RealRoot, inout dvec4 ImagRoot) {
	int j;
	double Mag;
	for (j = 0; j<N; j++) {
		// complex math for 1/x
		Mag = RealRoot[j] * RealRoot[j] + ImagRoot[j] * ImagRoot[j];
		if (Mag != 0.0) {
			RealRoot[j] /= Mag;
			ImagRoot[j] /= -Mag;
		}
	}
}
//---------------------------------------------------------------------------

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