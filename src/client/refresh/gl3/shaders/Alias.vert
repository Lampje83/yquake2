// it gets attributes and uniforms from Common3D.vert

out VS_OUT {
	vec2		TexCoord;
	vec4		Color;
	vec3		WorldCoord;
	flat int	refIndex;
} vs;

void main()
{
	//vec4 tmp;
	//tmp = transModel * vec4(position, 1.0);
	//vs.WorldCoord = tmp.xyz;
	vs.Color = vertColor*overbrightbits;
	vs.TexCoord = texCoord;
	vs.refIndex = refIndex;

	vec4 worldCoord = transModel * vec4 ( position, 1.0 );

	vs.WorldCoord = worldCoord.xyz;

	if ( vs.refIndex >= 0 ) {
		//worldCoord = refMatrix * worldCoord;
		//vs.WorldCoord = worldCoord.xyz;
		gl_Position = transProj * transView * worldCoord;
		gl_ClipDistance[ 0 ] = dot ( worldCoord.xyz, refData[ refIndex ].plane.xyz ) - refData[ refIndex ].plane.w;
		if ( ( refData[ refIndex ].flags & REFSURF_PLANEBACK ) != 0 ) {
			gl_ClipDistance[ 0 ] = -gl_ClipDistance[ 0 ];
		}

	} else {
		gl_Position = transProj * transView * worldCoord;
		gl_ClipDistance[ 0 ] = 1; // dot ( worldCoord.xyz, refData[ refIndex ].plane.xyz ) + refData[ refIndex ].plane.w;
	}
}
