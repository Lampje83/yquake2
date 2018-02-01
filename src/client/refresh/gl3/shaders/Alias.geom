#ifdef __INTELLISENSE__
#include "common3d.geom"
#endif

layout (triangles) in;
layout (triangle_strip, max_vertices = 6) out;

in VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	float		refPlaneDist;
	flat uint	SurfFlags;
	flat int	refIndex;
} gs_in[];

out VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	float		refPlaneDist;
	flat uint	SurfFlags;
	flat int	refIndex;
} gs_out;

void writeVertexData (int index) {
	gs_out.TexCoord = gs_in[index].TexCoord;
	gs_out.Color = gs_in[index].Color;
	gs_out.WorldCoord = gs_in[index].WorldCoord;
	gs_out.refIndex = gs_in[index].refIndex;
}

void outputPrimitive (bool clip, bool reverse) {
	for (int j = 0; j < gl_in.length (); j++) {
		int i;
		if (reverse) {
			// reverse winding. Needed when drawing reflected triangles, for proper culling
			i = gl_in.length () - 1 - j;
		} else {
			i = j;
		}

		writeVertexData (i);

		if (!clip) {
			gl_ClipDistance[0] = 0.0;
			gl_Position = gl_in[i].gl_Position;
		} else {
			if (reverse) {
				gl_ClipDistance[0] = gs_in[i].refPlaneDist;
				gl_Position = transProj * transView * refData[gs_in[i].refIndex].refMatrix * vec4 (gs_in[i].WorldCoord, 1.0);
			} else {
				gl_ClipDistance[0] = -gs_in[i].refPlaneDist;
				gl_Position = transProj * transView * vec4 (findRefractedPos (viewPos, gs_in[i].WorldCoord, refData[gs_in[i].refIndex]), 1.0); // gl_in[i].gl_Position;
				//gl_Position = gl_in[i].gl_Position;
			}
		}
		EmitVertex ();
	}
	EndPrimitive ();
}


void main() {
	int i, j, k;
	bool reflectionActive = gs_in[0].refIndex >= 0;

	if (reflectionActive) {
		// perform frustum culling
		for (j = 0; j < 5; j++) {
			k = 0;
			for (i = 0; i < gl_in.length (); i++) {
				vec4 pos = gl_in[i].gl_Position;
				if (gs_in[i].refPlaneDist > 0)
					pos = transProj * transView * refData[gs_in[i].refIndex].refMatrix * vec4 (gs_in[i].WorldCoord, 1.0);

				if (j < 4) {
					// test for view culling
					if ((pos[j & 1] * (1.0 - (j & 2))) > (refData[gs_in[i].refIndex].cullDistances[j] * pos.w)) k++;
				} else {
					if (gs_in[i].refPlaneDist < 0) k++;
				}
			}
			if (j < 4) {
				if (k == gl_in.length ())
					// discard
					return;
			}
		}

		if (k < gl_in.length ()) {
			// output reflected triangle
			gl_Layer = 1 + gs_in[0].refIndex * 2;
			outputPrimitive (true, true);
		}
		if (k > 0) {
			// output refracted triangle
			gl_Layer = 2 + gs_in[0].refIndex * 2;
			outputPrimitive (true, false);
		}
	} else {
		gl_Layer = 0;
		outputPrimitive (false, false);
	}
}