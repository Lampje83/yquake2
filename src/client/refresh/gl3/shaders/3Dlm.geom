#ifdef __INTELLISENSE__
#include "common3d.geom"
#define VS_OUT struct VS_OUT
#endif

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

in VS_OUT {
	vec2		TexCoord;
	vec2		LMcoord;
	vec3		WorldCoord;
	vec3		Normal;
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
	gl_ClipDistance[0] = gl_in[index].gl_ClipDistance[0];
	gl_Position = gl_in[index].gl_Position;
}

void main() {
	int i, j, k;
	bool reflectionActive = gs_in[0].refIndex >= 0;

	if (reflectionActive) {
		// perform frustum culling
#if 1
		for (j = 0; j < 5; j++) {
			k = 0;
			for (i = 0; i < gl_in.length(); i++) {
				vec4 pos = gl_in[i].gl_Position;
				if (j < 4) {
					// test for view culling
					//if ((pos[j & 1] * (1.0 - (j & 2))) > (refData[gs_in[i].refIndex].cullDistances[j] * pos.w) && (gl_in[i].gl_ClipDistance[0] > 0)) k++;
					if ((pos[j & 1] * (1.0 - (j & 2))) > (refData[gs_in[i].refIndex].cullDistances[j] * pos.w)) k++;
				} else {
					if (gl_in[i].gl_ClipDistance[0] < 0) k++;
				}
			}
			if (j < 4) {
				if (k == gl_in.length ())
					// discard
					return;
			}
		}
#endif
		gl_Layer = 1 + gs_in[0].refIndex;
	} else {
		gl_Layer = 0;
	}
	outputPrimitive ((reflectionActive) && ((refData[gs_in[0].refIndex].flags & REFSURF_REFRACT) == 0), gl_in.length ());
}
