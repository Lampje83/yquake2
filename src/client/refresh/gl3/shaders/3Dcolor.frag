#ifdef __INTELLISENSE__
#include "Common3D.frag"
#endif

// it gets attributes and uniforms from Common3D.frag

void main()
{
	vec4 texel = color;

	outColor.rgb = texel.rgb;
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
