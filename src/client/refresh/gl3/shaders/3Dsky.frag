// it gets attributes and uniforms from Common3D.frag
#ifdef __INTELLISENSE__
#include "glsl.h"
#include "Common3D.frag"
#endif

in Vx3D gs_out;

uniform sampler2D tex;

void main()
{
	vec4 texel = texture(tex, gs_out.TexCoord);

	// TODO: something about GL_BLEND vs GL_ALPHATEST etc
	outColor.rgb = texel.rgb / intensity;
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
