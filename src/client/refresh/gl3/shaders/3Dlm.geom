#ifdef __INTELLISENSE__
#include "common3d.geom"
#define VS_OUT struct VS_OUT
#endif

layout (triangles) in;
layout (triangle_strip, max_vertices = 6) out;

in VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	float		refPlaneDist;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} gs_in[];

out VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
	float		refPlaneDist;
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} gs_out;

void writeVertexData (int index) {
	gs_out.LMcoord = gs_in[index].LMcoord;
	gs_out.TexCoord = gs_in[index].TexCoord;
	gs_out.WorldCoord = gs_in[index].WorldCoord;
	gs_out.Normal = gs_in[index].Normal;
	gs_out.refPlaneDist = gs_in[index].refPlaneDist;
	gs_out.LightFlags = gs_in[index].LightFlags;
	gs_out.SurfFlags = gs_in[index].SurfFlags;
	gs_out.refIndex = gs_in[index].refIndex;
}

void mixVertexData (int index1, int index2, float x) {
	gs_out.LMcoord = mix(gs_in[index1].LMcoord, gs_in[index2].LMcoord, x);
	gs_out.TexCoord = mix(gs_in[index1].TexCoord, gs_in[index2].TexCoord, x);
	gs_out.WorldCoord = mix(gs_in[index1].WorldCoord, gs_in[index2].WorldCoord, x);
	gs_out.Normal = mix(gs_in[index1].Normal, gs_in[index2].Normal, x);
	gs_out.LightFlags = gs_in[index1].LightFlags;
	gs_out.SurfFlags = gs_in[index1].SurfFlags;
	gs_out.refIndex = gs_in[index1].refIndex;
}
/*
4 primitives:
A - AB - AC
AB - B - BC
AB - BC - C
AB - BC - AC
*/
void outputRefractedPrimitive (bool reverse) {
	int i, i2;
	for (int j = 0; j < gl_in.length (); j++) {

		if (reverse) {
			// reverse winding. Needed when drawing reflected triangles, for proper culling
			i = gl_in.length () - 1 - j;
		} else {
			i = j;
		}

		if (gl_InvocationID < 3) {
			i2 = gl_InvocationID;
		} else {
			i2 = i + 1;
			if (i2 >= gl_in.length ()) i2 -= gl_in.length ();
		}

		if (gl_InvocationID == i) {
			writeVertexData (i);
		} else {
			mixVertexData (i, i2, 0.5);
		}

		if (gl_InvocationID == i) {
			gl_ClipDistance[0] = -gs_in[i].refPlaneDist;
			gl_Position = transProj * transView * vec4 (findRefractedPos (viewPos, gs_in[i].WorldCoord, refData[gs_in[i].refIndex]), 1.0);
		} else {
			gl_ClipDistance[0] = mix (-gs_in[i].refPlaneDist, -gs_in[i2].refPlaneDist, 0.5);
			gl_Position = transProj * transView * vec4 (findRefractedPos (viewPos, mix (gs_in[i].WorldCoord, gs_in[i2].WorldCoord, 0.5), refData[gs_in[i].refIndex]), 1.0);
		}
		EmitVertex ();
	}
	EndPrimitive ();
}

void outputPrimitive (bool clip, bool reverse) {
	if (gl_InvocationID > 0) {
		return;
	}

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
			gl_Position = transProj * transView * vec4 (gs_in[i].WorldCoord, 1.0);
		} else {
			if (reverse) {
				gl_ClipDistance[0] = gs_in[i].refPlaneDist;
				gl_Position = transProj * transView * refData[gs_in[i].refIndex].refMatrix * vec4 (gs_in[i].WorldCoord, 1.0);
			} else {
				gl_ClipDistance[0] = -gs_in[i].refPlaneDist;
				gl_Position = transProj * transView * vec4(findRefractedPos (viewPos, gs_in[i].WorldCoord, refData[gs_in[i].refIndex]), 1.0); // gl_in[i].gl_Position;
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
			for (i = 0; i < gl_in.length(); i++) {
				vec4 pos = gl_in[i].gl_Position;
				if (gs_in[i].refPlaneDist > 0) {
					// reflect position
					pos = transProj * transView * refData[gs_in[i].refIndex].refMatrix * vec4 (gs_in[i].WorldCoord, 1.0);
				}
/*				if (gs_in[i].refPlaneDist < 0) {
					pos = transProj * transView * vec4 (findRefractedPos (viewPos, gs_in[i].WorldCoord, refData[gs_in[i].refIndex]), 1.0);
				}
*/				if (j < 4) {
					// test for view culling
					if ((pos[j & 1] * (1.0 - (j & 2))) > (refData[gs_in[i].refIndex].cullDistances[j] * pos.w) && (gs_in[i].refPlaneDist > 0)) k++;
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
			//outputRefractedPrimitive (false);
			outputPrimitive (true, false);
		}
	} else {
		gl_Layer = 0;
		outputPrimitive (false, false);
	}
}
