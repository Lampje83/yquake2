#version 150

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

out vec4 outColor;

void main()
{
	vec3 coord;
	coord.xy = passTexCoord.xy;
	coord.z = 0;

	vec4 texel = texture(tex, coord);

	//coord.z = 1;
	//vec4 texel2 = texture(tex, coord);

	// the gl1 renderer used glAlphaFunc(GL_GREATER, 0.666);
	// and glEnable(GL_ALPHA_TEST); for 2D rendering
	// this should do the same
	//texel += texel2;

	if(texel.a <= 0.0)
		discard;

	// apply gamma correction and intensity
	//texel.rgb *= intensity2D;
	outColor.rgb = texel.rgb;
	outColor.a = 1; //texel.a; // I think alpha shouldn't be modified by gamma and intensity
}