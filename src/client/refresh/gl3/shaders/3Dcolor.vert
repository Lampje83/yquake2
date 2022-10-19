// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common3D.vert"
#endif

out Vx3D vs;

void main()
{
	vs.TexCoord = texCoord;

	if ((surfFlags & SURF_FLOWING) != 0) {
		vs.TexCoord.s -= time / 48.0 * 32.0;
	}

	vs.WorldCoord = (transModel * vec4 (position, 1.0f)).xyz;
	vs.Normal = normalize ((transModel * vec4 (normal, 0.0f)).xyz);
	vs.SurfFlags = surfFlags;
	vs.refIndex = refIndex + gl_InstanceID;

	vec3 modifiedCoord;

	if (vs.refIndex >= 0) {
		if ((refData[vs.refIndex].flags & REFSURF_REFRACT) != 0) {
			modifiedCoord = findRefractedPos (viewPos, vs.WorldCoord, refData[vs.refIndex]);
		}
		else {
			modifiedCoord = (refData[vs.refIndex].refMatrix * vec4 (vs.WorldCoord, 1.0)).xyz;
		}

		vec4 plane = refData[vs.refIndex].plane;
		gl_ClipDistance[0] = -distToPlane (modifiedCoord, plane);
		if (distToPlane (viewPos, plane) < 0) {
			gl_ClipDistance[0] = -gl_ClipDistance[0];
			vs.SurfFlags |= REFSURF_PLANEBACK;
		}
	}
	else {
		modifiedCoord = vs.WorldCoord;
		gl_ClipDistance[0] = 0.0;
	}
	gl_Position = transProj * transView * vec4 (modifiedCoord, 1.0);
}
