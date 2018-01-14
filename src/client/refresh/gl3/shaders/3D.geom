#version 430 core

layout (triangles) in;
layout (triangle_strip, max_vertices = 6) out;

// for UBO shared between all 3D shaders
layout (std140) uniform uni3D
{
	mat4 transProj;
	mat4 transView;
	mat4 transModel;
//	vec4 fluidPlane;
//	vec4 cullDistances;
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
};

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

layout ( std140 ) uniform refDat {
	refData_s	refData[16];
};

in VS_OUT {
	vec2		TexCoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat int	refIndex;
} gs_in[];

out VS_OUT {
	vec2		TexCoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat int	refIndex;
} gs_out;

int count;

float refPlaneDist [6];

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
		gs_out.WorldCoord = gs_in[i].WorldCoord;
		gs_out.Normal = gs_in[i].Normal;
		gs_out.refIndex = gs_in[i].refIndex;

		gl_Position = gl_in[i].gl_Position;

		if (!negative) 
		{
			gl_ClipDistance[0] = 0.0; //gl_in[i].gl_ClipDistance[0];
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

vec4 transformPlane (vec4 plane, mat4 mat)
{
	vec4 point, normal;

	normal = mat * vec4(plane.xyz, 0.0);
	point = mat * vec4(plane.xyz * -plane.w, 1.0);

	return vec4(normal.xyz, dot(point, normal));
}

void main() {
	int i, j, k;
	bool reflectionActive = gs_in[i].refIndex >= 0;

	// perform backface culling, improves speed
	// if (cross(gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz, gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz).z < 0)
	//	return;
	
	count = gl_in.length();

	// transform the reflection plane to view space
//	vec4 newplane = transformPlane (refData[gs_in[i].refIndex].plane, transView);
/*	
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
//					refPlaneDist[i] = dot ( (transView * vec4(gs_in[i].WorldCoord.xyz, 1.0)).xyz, newplane.xyz ) - newplane.w;

					// check on which side of the plane we are
					if (dot (viewPos, refData[gs_in[i].refIndex].plane.xyz) - refData[gs_in[i].refIndex].plane.w < 0)
//					if (newplane.w < 0)
//					if ((refData[gs_in[i].refIndex].flags & REFSURF_PLANEBACK) != 0)
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
			if (k == count)
				// discard
				return;
		}
	}
*/
	if (reflectionActive)
	{
		for (i = 0; i < count; i++) {
			refPlaneDist[i] = dot ( gs_in[i].WorldCoord.xyz, refData[ gs_in[i].refIndex ].plane.xyz ) - refData[ gs_in[i].refIndex ].plane.w;
			if (dot (viewPos, refData[gs_in[i].refIndex].plane.xyz) - refData[gs_in[i].refIndex].plane.w < 0)
			//if ((refData[gs_in[i].refIndex].flags & REFSURF_PLANEBACK) != 0)
				refPlaneDist[i] = -refPlaneDist[i];
			if (abs(-dot ( gs_in[i].WorldCoord.xyz, refData[gs_in[i].refIndex].plane.xyz ) + refData[gs_in[i].refIndex].plane.w) < 0.1) k++;
//			if (abs(newplane.w) < 0.1) k++;
		}
		if (k == count)
			// discard
			return;
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