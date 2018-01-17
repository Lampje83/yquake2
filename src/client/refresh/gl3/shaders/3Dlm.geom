#ifdef __INTELLISENSE__
#include "common3d.geom"
#define VS_OUT struct VS_OUT
#endif

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
	flat uint	LightFlags;
	flat uint	SurfFlags;
	flat int	refIndex;
} gs_out;

void writeVertexData (int index) {
	gs_out.LMcoord = gs_in[index].LMcoord;
	gs_out.TexCoord = gs_in[index].TexCoord;
	gs_out.WorldCoord = gs_in[index].WorldCoord;
	gs_out.Normal = gs_in[index].Normal;
	gs_out.LightFlags = gs_in[index].LightFlags;
	gs_out.SurfFlags = gs_in[index].SurfFlags;
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

		if (!clip) 
		{
			gl_ClipDistance[0] = 0.0;
			gl_Position = gl_in[i].gl_Position;
		}
		else
		{
			if ((gs_in[i].refIndex >= 0) && reverse)
			{
				gl_ClipDistance[0] = gs_in[i].refPlaneDist;
				gl_Position = transProj * transView * refData[gs_in[i].refIndex].refMatrix * vec4(gs_in[i].WorldCoord, 1.0);
			}
			else
			{
				gl_ClipDistance[0] = -gs_in[i].refPlaneDist;
				gl_Position = gl_in[i].gl_Position;
			}
		}
		EmitVertex();
	}
	EndPrimitive();
}

void main() {
	int i, j, k;
	bool reflectionActive = gs_in[0].refIndex >= 0;

	count = gl_in.length ();

	if (reflectionActive) {
		// perform frustum culling
		for (j = 0; j < 5; j++) {
			k = 0;
			for (i = 0; i < gl_in.length(); i++) {
			vec4 pos = gl_in[i].gl_Position;
				if (gs_in[i].refPlaneDist > 0)
					pos = transProj * transView * refData[gs_in[i].refIndex].refMatrix * vec4 (gs_in[i].WorldCoord, 1.0);

				if (j < 4) {
					// test for view culling
					if ((pos[j & 1] * (1.0 - (j & 2))) > (refData[gs_in[i].refIndex].cullDistances[j] * pos.w)) k++;
				} else {
					//if ((dot ( pos.xyz, refData[gs_in[i].refIndex].plane.xyz ) - refData[gs_in[i].refIndex].plane.w) < 0) k++;
					if (refPlaneDist[i] < 0) k++;
				}
			}
			if (j < 4) {
				if (k == count)
					// discard
					return;
			}
		}

		if (k <= count) {
			// output reflected triangle
			gl_Layer = 1 + gs_in[0].refIndex * 2;
			outputPrimitive (true, true);
		}
		if (k >= 0) {
			// output refracted triangle
			gl_Layer = 2 + gs_in[0].refIndex * 2;
			outputPrimitive (true, false);
		}
	} else {
		gl_Layer = 0;
		outputPrimitive (false, false);
	}
}