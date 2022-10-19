#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common3D.frag"
#endif

// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

in Vx3Dal gs_out;

void main()
{
	vec4 texel = texture(tex, gs_out.TexCoord);
/*
	float clipPos = dot (passWorldCoord, fluidPlane.xyz) + fluidPlane.w;
	if (clipPos < 0 && (length(fluidPlane.xyz) > 0))
		discard;
*/
	// apply gamma correction and intensity
	texel.a *= alpha; // is alpha even used here?
	texel *= min(vec4(3.0), gs_out.Color);

	outColor = texel;
}
