// it gets attributes and uniforms from Common3D.vert

out VS_OUT {
	vec2		TexCoord;
	vec3		WorldCoord;
	vec3		Normal;
	flat mat4	refMatrix;
} vs;

void main()
{
	vs.TexCoord = texCoord;

	if ((surfFlags & SURF_FLOWING) != 0) {
		vs.TexCoord.s -= time / 48.0 * 32.0;
	}

	vec4 worldCoord = transModel * vec4 ( position, 1.0 );

	vs.WorldCoord = worldCoord.xyz;
	vec4 worldNormal = transModel * vec4 ( normal, 0.0f );
	vs.Normal = normalize ( worldNormal.xyz );
	vs.refMatrix = refMatrix;

	if ( length ( fluidPlane.xyz ) > 0 ) {
		//worldCoord = refMatrix * worldCoord;
		//vs.WorldCoord = worldCoord.xyz;
		gl_Position = transProj * transView * worldCoord;
		gl_ClipDistance[ 0 ] = dot ( worldCoord.xyz, fluidPlane.xyz ) + fluidPlane.w;

	} else {
		gl_Position = transProj * transView * worldCoord;
		gl_ClipDistance[ 0 ] = dot ( worldCoord.xyz, fluidPlane.xyz ) + fluidPlane.w;
	}
}
