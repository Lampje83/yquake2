// it gets attributes and uniforms from Common3D.vert

out VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	flat int	refIndex;
} vs;

void main()
{
	vs.TexCoord = texCoord;
	vs.Color = vertColor*overbrightbits;

	vec4 worldCoord = transModel * vec4 ( position, 1.0 );

	vs.WorldCoord = worldCoord.xyz;
	vs.refIndex = refIndex;

	gl_Position = transProj * transView * worldCoord;
	gl_ClipDistance[0] = 0.0;
}
