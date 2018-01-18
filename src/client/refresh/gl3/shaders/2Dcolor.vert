#ifdef __INTELLISENSE__
#include "glsl.h"
#endif

in vec2 position; // GL3_ATTRIB_POSITION

// for UBO shared between 2D shaders
layout (std140) uniform uni2D
{
	mat4 trans;
};

void main()
{
	gl_Position = trans * vec4(position, 0.0, 1.0);
}