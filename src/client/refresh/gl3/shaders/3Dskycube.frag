// it gets attributes and uniforms from Common3D.frag

#ifndef __INTELLISENSE__
layout (std140) uniform refDat {
#endif
	refData_s refData[16];
#ifndef __INTELLISENSE__
};
#endif

in VS_OUT {
	vec2 TexCoord;
	vec3 WorldCoord;
	vec3 Normal;
	flat uint	SurfFlags;
	flat int	refIndex;
} fs_in;

uniform samplerCube tex;

mat4 rotationMatrix (vec3 axis, float angle)
{
	axis = normalize (axis);
	float s = sin (angle);
	float c = cos (angle);
	float oc = 1.0 - c;

	return mat4 (oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s, 0,
		oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s, 0,
		oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c, 0,
		0, 0, 0, 1);
}

void main()
{
	vec3 vp = viewPos;
	if (fs_in.refIndex >= 0 && (gl_Layer & 1) != 0) {
		float dist = distToPlane (vp, refData[fs_in.refIndex].plane);
		vp -= refData[fs_in.refIndex].plane.xyz * dist * 2;
	}
	vec3 ray = fs_in.WorldCoord.yzx - vp.yzx;
	ray.x = -ray.x;
	if (skyRotate.w != 0) {
		vec3 axis = vec3 (-skyRotate.y, skyRotate.z, skyRotate.x);
		ray = (rotationMatrix (axis, radians(time * -skyRotate.w)) * vec4 (ray, 0.0)).xyz;
	}
	vec4 texel = texture(tex, ray);

	// TODO: something about GL_BLEND vs GL_ALPHATEST etc
	outColor.rgb = texel.rgb / intensity;
	outColor.a = texel.a*alpha; // I think alpha shouldn't be modified by gamma and intensity
}
