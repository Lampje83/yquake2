// it gets attributes and uniforms from fragmentCommon3D

uniform sampler2D tex;

in vec2 passTexCoord;
in vec4 passColor;
in vec3 passWorldCoord;

void main()
{
	vec4 texel = texture(tex, passTexCoord);
/*
	float clipPos = dot (passWorldCoord, fluidPlane.xyz) + fluidPlane.w;
	if (clipPos < 0 && (length(fluidPlane.xyz) > 0))
		discard;
*/
	// apply gamma correction and intensity
	texel.rgb *= intensity;
	texel.a *= alpha; // is alpha even used here?
	texel *= min(vec4(3.0), passColor);

	outColor.rgb = pow(texel.rgb, vec3(gamma));
	outColor.a = texel.a; // I think alpha shouldn't be modified by gamma and intensity
}
