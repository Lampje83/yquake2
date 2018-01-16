#ifdef __INTELLISENSE__
#include "common3d.geom"
#endif

in VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	flat int	refIndex;
} gs_in[];

out VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	flat int	refIndex;
} gs_out;

void outputPrimitive (bool negative, bool reverse) {
	for (int j = 0; j < count; j++) {
		int i;
		if (reverse) {
			// reverse winding. Needed when drawing reflected triangles, for proper culling
			i = count - 1 - j;
		} else {
			i = j;
		}

		gs_out.TexCoord = gs_in[i].TexCoord;
		gs_out.Color = gs_in[i].Color;
		gs_out.WorldCoord = gs_in[i].WorldCoord;
		gs_out.refIndex = gs_in[i].refIndex;

		if (!negative) 
		{
			gl_ClipDistance[0] = 0.0;
			gl_Position = gl_in[i].gl_Position;
		}
		else
		{
			if ((gs_in[i].refIndex >= 0) && reverse)
			{
				gl_ClipDistance[0] = refPlaneDist[i];
				gl_Position = transProj * transView * refData[gs_in[i].refIndex].refMatrix * vec4(gs_in[i].WorldCoord, 1.0);
			}
			else
			{
				gl_ClipDistance[0] = -refPlaneDist[i];
				gl_Position = gl_in[i].gl_Position;
			}
		}
		EmitVertex();
	}
	EndPrimitive();
}


void main() {
	int i, j, k;
	bool reflectionActive = gs_in[i].refIndex >= 0;

	// perform backface culling, improves speed
	// if (cross(gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz, gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz).z < 0)
	//	return;
	
	count = gl_in.length();

	// perform frustum culling
	for (j = 0; j < 5; j++)	{
		k = 0;
		for (i = 0; i < count; i++) {
			vec4 pos = gl_in[i].gl_Position;
			if (reflectionActive)
			{
				if (j == 0)
				{
					refPlaneDist[i] = dot ( gs_in[i].WorldCoord.xyz, refData[ gs_in[i].refIndex ].plane.xyz ) - refData[ gs_in[i].refIndex ].plane.w;

					if (dot (viewPos, refData[gs_in[i].refIndex].plane.xyz) - refData[gs_in[i].refIndex].plane.w < 0)
						// we are looking at the backside of the plane
					//if ((refData[gs_in[i].refIndex].flags & REFSURF_PLANEBACK) != 0)
						refPlaneDist[i] = -refPlaneDist[i];
				}

				if (refPlaneDist[i] > 0)
					pos = transProj * transView * refData[gs_in[i].refIndex].refMatrix * vec4(gs_in[i].WorldCoord, 1.0);

				if (j < 4) {
					// test for view culling
					if ( (pos[j & 1] * (1.0 - (j & 2))) > (refData[gs_in[i].refIndex].cullDistances[j] * pos.w)) k++;
				} else {
					//if ((dot ( pos.xyz, refData[gs_in[i].refIndex].plane.xyz ) - refData[gs_in[i].refIndex].plane.w) < 0) k++;
					if (refPlaneDist[i] < 0) k++;
				}
			}
			else
			{
				refPlaneDist[i] = 0;
			}
		}
		if (j < 4) {
			//if (k == count)
				// discard
				//return;
		}
	}

	if (reflectionActive)
	{
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
	}
	else
	{
		gl_Layer = 0;
		outputPrimitive (false, false);
	}
}