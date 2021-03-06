// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

in VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	// flat int	refIndex;
} fs_in;

void main()
{
	vec4 texel = texture(tex, fs_in.TexCoord);
/*
	float clipPos = dot (passWorldCoord, fluidPlane.xyz) + fluidPlane.w;
	if (clipPos < 0 && (length(fluidPlane.xyz) > 0))
		discard;
*/
	// apply gamma correction and intensity
	texel.a *= alpha; // is alpha even used here?
	texel *= min(vec4(3.0), fs_in.Color);

	outColor = texel;
}
