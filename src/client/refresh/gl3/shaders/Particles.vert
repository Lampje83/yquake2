// it gets attributes and uniforms from Common3D.vert
#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common3D.vert"
#endif

out vec4 partColor;
out vec4 worldPos;
out int passRefIndex;

void main()
{
	partColor = vertColor;

	worldPos = transModel * vec4 (position, 1.0);
	passRefIndex = refIndex + gl_InstanceID;
	vec4 viewPos = transView * worldPos;
	gl_Position = transProj * viewPos;

	// abusing texCoord for pointSize, pointDist for particles
	float pointDist = -viewPos.z * 0.1; //texCoord.y*0.1; // with factor 0.1 it looks good.

	gl_PointSize = texCoord.x;
}
