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
