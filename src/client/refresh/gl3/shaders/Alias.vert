// it gets attributes and uniforms from Common3D.vert

out VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	flat mat4	refMatrix;
} vs;

void main()
{
	//vec4 tmp;
	//tmp = transModel * vec4(position, 1.0);
	//vs.WorldCoord = tmp.xyz;
	vs.Color = vertColor*overbrightbits;
	vs.TexCoord = texCoord;
	vs.refMatrix = refMatrix;

	vec4 worldCoord = transModel * vec4 ( position, 1.0 );

	vs.WorldCoord = worldCoord.xyz;

	if ( length ( fluidPlane.xyz ) > 0 ) {
//		worldCoord = refMatrix * worldCoord;
//		passWorldCoord = worldCoord.xyz;
		gl_Position = transProj * transView * worldCoord;
		gl_ClipDistance[ 0 ] = dot ( worldCoord.xyz, fluidPlane.xyz ) + fluidPlane.w;

	} else {
		gl_Position = transProj * transView * worldCoord;
		gl_ClipDistance[ 0 ] = -dot ( worldCoord.xyz, fluidPlane.xyz ) - fluidPlane.w;
	}
}
