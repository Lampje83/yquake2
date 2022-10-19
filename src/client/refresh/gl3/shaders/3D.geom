#ifdef __INTELLISENSE__
#include "common3d.geom"
#endif

layout (triangles) in;
layout (triangle_strip, max_vertices = 3) out;

in Vx3D vs[];
out Vx3D gs_out;

void writeVertexData (int index) {
	gs_out.TexCoord = vs[index].TexCoord;
	gs_out.WorldCoord = vs[index].WorldCoord;
	gs_out.Normal = vs[index].Normal;
	gs_out.refIndex = vs[index].refIndex;
	gs_out.SurfFlags = vs[index].SurfFlags;
	gl_ClipDistance[0] = gl_in[index].gl_ClipDistance[0];
	gl_Position = gl_in[index].gl_Position;
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
	bool reflectionActive = vs[i].refIndex >= 0;

	// perform backface culling, improves speed
	// if (cross(gl_in[2].gl_Position.xyz - gl_in[0].gl_Position.xyz, gl_in[1].gl_Position.xyz - gl_in[0].gl_Position.xyz).z < 0)
	//	return;
	
	count = gl_in.length();

	// transform the reflection plane to view space

	if (reflectionActive)
	{
		k = 0;
		for (i = 0; i < gl_in.length (); i++) {
/*
			refPlaneDist[i] = dot (vs[i].WorldCoord.xyz, refData[vs[i].refIndex].plane.xyz) - refData[vs[i].refIndex].plane.w;
			if (dot (viewPos, refData[vs[i].refIndex].plane.xyz) - refData[vs[i].refIndex].plane.w < 0)
			//if ((refData[vs[i].refIndex].flags & REFSURF_PLANEBACK) != 0)
				refPlaneDist[i] = -refPlaneDist[i];
*/
			// is point on plane?
			if (abs(gl_in[i].gl_ClipDistance[0]) < 0.1) k++;
//			if (abs(newplane.w) < 0.1) k++;
		}

		if (k == gl_in.length ())
			// discard
			return;

		gl_Layer = 1 + vs[0].refIndex;
	}
	else
	{
		gl_Layer = 0;
	}
	outputPrimitive ((reflectionActive) && ((refData[vs[0].refIndex].flags & REFSURF_REFRACT) == 0), gl_in.length ());
}