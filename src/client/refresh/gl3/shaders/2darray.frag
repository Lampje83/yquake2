#ifdef __INTELLISENSE__
#include "glsl.h"
#endif

in vec2 passTexCoord;

// for UBO shared between all shaders (incl. 2D)
layout (std140) uniform uniCommon
{
	float gamma;
	float intensity;
	float intensity2D; // for HUD, menu etc

	vec4 color;
};

uniform sampler2DArray tex;
uniform uint texLayer;

out vec4 outColor;

void main()
{
	vec3 coord;
	coord.xy = passTexCoord.xy;
	coord.z = texLayer;

	vec4 texel = texture(tex, coord);

	if(texel.a <= 0.0)
		discard;

	// apply gamma correction and intensity
	texel.rgb *= intensity;
	texel.rgb = pow (texel.rgb, vec3 (gamma));

	outColor = texel;
}