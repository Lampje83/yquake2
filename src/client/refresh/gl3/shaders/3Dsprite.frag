#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common.glsl"
#endif

// it gets attributes and uniforms from Common3D.frag
in Vx3D gs_out;

uniform sampler2D tex;

void main()
{
	vec4 texel = texture(tex, gs_out.TexCoord);

	outColor.rgb = texel.rgb;
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
