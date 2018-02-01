#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common3D.geom"
#endif

layout (points) in;
layout (points, max_vertices = 1) out;

in vec4 partColor[];
in vec4 worldPos[];
in int passRefIndex[];

out vec4 passColor;

void main () {
	int j, k;
	bool	reflectionActive = passRefIndex[0] >= 0;
	float	refPlaneDist;
	vec4	pos;

	pos = transProj * transView * worldPos[0]; // gl_in[0].gl_Position;

	if (reflectionActive) {
		refPlaneDist = distToPlane (worldPos[0].xyz, refData[passRefIndex[0]].plane);

		if (distToPlane (viewPos, refData[passRefIndex[0]].plane) < 0) {
			refPlaneDist = -refPlaneDist;
		}
		// perform frustum culling
		for (j = 0; j < 5; j++) {
			k = 0;

			if (refPlaneDist > 0) {
				// reflect position
				pos = transProj * transView * refData[passRefIndex[0]].refMatrix * vec4 (worldPos[0].xyz, 1.0);
			} else if (refPlaneDist < 0) {
				pos = transProj * transView * vec4 (findRefractedPos (viewPos, worldPos[0].xyz, refData[passRefIndex[0]]), 1.0);
			}

			if (j < 4) {
			// test for view culling
				if ((pos[j & 1] * (1.0 - (j & 2))) > (refData[passRefIndex[0]].cullDistances[j] * pos.w) && (refPlaneDist > 0)) k++;
			} else {
				if (refPlaneDist < 0) k++;
			}

			if (j < 4) {
				if (k == 1)
					// discard
					return;
			}
		}

		if (k < 1) {
			// output reflected triangle
			gl_Layer = 1 + passRefIndex[0] * 2;
			//outputPrimitive (true, true);
		}
		if (k > 0) {
			// output refracted triangle
			gl_Layer = 2 + passRefIndex[0] * 2;
			//outputRefractedPrimitive (false);
			//outputPrimitive (true, false);
		}
	} else {
		gl_Layer = 0;
		//outputPrimitive (false, false);
	}
	passColor = partColor[0];
	gl_Position = pos;
	gl_PointSize = gl_in[0].gl_PointSize * 10.0 / pos.z;
	EmitVertex ();
	EndPrimitive ();
}
