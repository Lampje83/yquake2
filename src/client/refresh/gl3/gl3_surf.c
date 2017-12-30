/*
 * Copyright (C) 1997-2001 Id Software, Inc.
 * Copyright (C) 2016-2017 Daniel Gibson
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or (at
 * your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 *
 * =======================================================================
 *
 * Surface generation and drawing
 *
 * =======================================================================
 */

#include <assert.h>

#include "header/local.h"

int c_visible_lightmaps;
int c_visible_textures;
static vec3_t modelorg; /* relative to viewpoint */
static msurface_t *gl3_alpha_surfaces;

#define MAX_INDICES	2048
GLuint elementlist[ MAX_INDICES ], numelements = 0; // for glDrawElements
GLuint arraystart[ MAX_INDICES ], arraylength[ MAX_INDICES ], numarrays = 0; // for glMultiDrawArrays

gl3lightmapstate_t gl3_lms;

#define BACKFACE_EPSILON 0.01

extern gl3image_t gl3textures[MAX_GL3TEXTURES];
extern int numgl3textures;

void GL3_SurfInit(void)
{
	// init the VAO and VBO for the standard vertexdata: 10 floats and 1 uint
	// (X, Y, Z), (S, T), (LMS, LMT), (normX, normY, normZ) - last two groups for lightmap/dynlights

	glGenVertexArrays(1, &gl3state.vao3D);
	GL3_BindVAO(gl3state.vao3D);

	glGenBuffers(1, &gl3state.vbo3D);
	GL3_BindVBO(gl3state.vbo3D);

	glEnableVertexAttribArray(GL3_ATTRIB_POSITION);
	qglVertexAttribPointer(GL3_ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, sizeof(gl3_3D_vtx_t), 0);

	glEnableVertexAttribArray(GL3_ATTRIB_TEXCOORD);
	qglVertexAttribPointer(GL3_ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof(gl3_3D_vtx_t), offsetof(gl3_3D_vtx_t, texCoord));

	glEnableVertexAttribArray(GL3_ATTRIB_LMTEXCOORD);
	qglVertexAttribPointer(GL3_ATTRIB_LMTEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof(gl3_3D_vtx_t), offsetof(gl3_3D_vtx_t, lmTexCoord));

	glEnableVertexAttribArray(GL3_ATTRIB_NORMAL);
	qglVertexAttribPointer(GL3_ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, sizeof(gl3_3D_vtx_t), offsetof(gl3_3D_vtx_t, normal));

	glEnableVertexAttribArray(GL3_ATTRIB_LIGHTFLAGS);
	qglVertexAttribIPointer(GL3_ATTRIB_LIGHTFLAGS, 1, GL_UNSIGNED_INT, sizeof(gl3_3D_vtx_t), offsetof(gl3_3D_vtx_t, lightFlags));


	glGenVertexArrays ( 1, &gl3state.vao3Dtrans );
	GL3_BindVAO ( gl3state.vao3Dtrans );

	glGenBuffers ( 1, &gl3state.vbo3Dtrans );
	GL3_BindVBO ( gl3state.vbo3Dtrans );

	glEnableVertexAttribArray ( GL3_ATTRIB_POSITION );
	qglVertexAttribPointer ( GL3_ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, sizeof ( gl3_3D_vtx_t ), 0 );

	glEnableVertexAttribArray ( GL3_ATTRIB_TEXCOORD );
	qglVertexAttribPointer ( GL3_ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof ( gl3_3D_vtx_t ), offsetof ( gl3_3D_vtx_t, texCoord ) );

	glEnableVertexAttribArray ( GL3_ATTRIB_LMTEXCOORD );
	qglVertexAttribPointer ( GL3_ATTRIB_LMTEXCOORD, 2, GL_FLOAT, GL_FALSE, sizeof ( gl3_3D_vtx_t ), offsetof ( gl3_3D_vtx_t, lmTexCoord ) );

	glEnableVertexAttribArray ( GL3_ATTRIB_NORMAL );
	qglVertexAttribPointer ( GL3_ATTRIB_NORMAL, 3, GL_FLOAT, GL_FALSE, sizeof ( gl3_3D_vtx_t ), offsetof ( gl3_3D_vtx_t, normal ) );

	glEnableVertexAttribArray ( GL3_ATTRIB_LIGHTFLAGS );
	qglVertexAttribIPointer ( GL3_ATTRIB_LIGHTFLAGS, 1, GL_UNSIGNED_INT, sizeof ( gl3_3D_vtx_t ), offsetof ( gl3_3D_vtx_t, lightFlags ) );


	// init VAO and VBO for model vertexdata: 9 floats
	// (X,Y,Z), (S,T), (R,G,B,A)

	glGenVertexArrays(1, &gl3state.vaoAlias);
	GL3_BindVAO(gl3state.vaoAlias);

	glGenBuffers(1, &gl3state.vboAlias);
	GL3_BindVBO(gl3state.vboAlias);

	glEnableVertexAttribArray(GL3_ATTRIB_POSITION);
	qglVertexAttribPointer(GL3_ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 9*sizeof(GLfloat), 0);

	glEnableVertexAttribArray(GL3_ATTRIB_TEXCOORD);
	qglVertexAttribPointer(GL3_ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 9*sizeof(GLfloat), 3*sizeof(GLfloat));

	glEnableVertexAttribArray(GL3_ATTRIB_COLOR);
	qglVertexAttribPointer(GL3_ATTRIB_COLOR, 4, GL_FLOAT, GL_FALSE, 9*sizeof(GLfloat), 5*sizeof(GLfloat));

	glGenBuffers(1, &gl3state.eboAlias);

	// init VAO and VBO for particle vertexdata: 9 floats
	// (X,Y,Z), (point_size,distace_to_camera), (R,G,B,A)

	glGenVertexArrays(1, &gl3state.vaoParticle);
	GL3_BindVAO(gl3state.vaoParticle);

	glGenBuffers(1, &gl3state.vboParticle);
	GL3_BindVBO(gl3state.vboParticle);

	glEnableVertexAttribArray(GL3_ATTRIB_POSITION);
	qglVertexAttribPointer(GL3_ATTRIB_POSITION, 3, GL_FLOAT, GL_FALSE, 9*sizeof(GLfloat), 0);

	// TODO: maybe move point size and camera origin to UBO and calculate distance in vertex shader
	glEnableVertexAttribArray(GL3_ATTRIB_TEXCOORD); // it's abused for (point_size, distance) here..
	qglVertexAttribPointer(GL3_ATTRIB_TEXCOORD, 2, GL_FLOAT, GL_FALSE, 9*sizeof(GLfloat), 3*sizeof(GLfloat));

	glEnableVertexAttribArray(GL3_ATTRIB_COLOR);
	qglVertexAttribPointer(GL3_ATTRIB_COLOR, 4, GL_FLOAT, GL_FALSE, 9*sizeof(GLfloat), 5*sizeof(GLfloat));

	// init renderbuffers for reflection, refraction and shadow mapping
	GLenum DrawBuffers[ 2 ] = { GL_COLOR_ATTACHMENT0, GL_DEPTH_ATTACHMENT };

	// TODO: Clean these up at shutdown
	glGenFramebuffers ( 1, &gl3state.reflectFB );
	//glGenFramebuffers ( 1, &gl3state.refractFB );
	glGenTextures ( 1, &gl3state.reflectTexture );
	glGenTextures ( 1, &gl3state.reflectTextureDepth );
	//glGenTextures ( 1, &gl3state.refractTexture );
	//glGenTextures ( 1, &gl3state.refractTextureDepth );

	// Setup buffer textures
	glBindTexture ( GL_TEXTURE_2D_ARRAY, gl3state.reflectTexture );
	glTexImage3D ( GL_TEXTURE_2D_ARRAY, 0, GL_RGBA, vid.width, vid.height, 32, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0 );
	glTexParameteri ( GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
	glTexParameteri ( GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST );

	glBindTexture ( GL_TEXTURE_2D_ARRAY, gl3state.reflectTextureDepth );
	glTexImage3D ( GL_TEXTURE_2D_ARRAY, 0, GL_DEPTH_COMPONENT24, vid.width, vid.height, 32, 0, GL_DEPTH_COMPONENT, GL_FLOAT, 0 );
	glTexParameteri ( GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
	glTexParameteri ( GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
/*
	glBindTexture ( GL_TEXTURE_2D, gl3state.refractTexture );
	glTexImage2D ( GL_TEXTURE_2D, 0, GL_RGBA, vid.width, vid.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0 );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );

	glBindTexture ( GL_TEXTURE_2D, gl3state.refractTextureDepth );
	glTexImage2D ( GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT24, vid.width, vid.height, 0, GL_DEPTH_COMPONENT, GL_FLOAT, 0 );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST );
	glTexParameteri ( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST );
*/
	// Setup the frame buffers
	glBindFramebuffer ( GL_FRAMEBUFFER, gl3state.reflectFB );
	glFramebufferTexture ( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, gl3state.reflectTexture, 0 );
	glFramebufferTexture ( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, gl3state.reflectTextureDepth, 0 );
/*
	GLuint depthrenderbuffer;
	glGenRenderbuffers ( 1, &depthrenderbuffer );
	glBindRenderbuffer ( GL_RENDERBUFFER, depthrenderbuffer );
	glRenderbufferStorage ( GL_RENDERBUFFER, GL_DEPTH_COMPONENT, vid.height, vid.width );
	glFramebufferRenderbuffer ( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, depthrenderbuffer );
*/
	glDrawBuffers ( 1, DrawBuffers );

	if ( glCheckFramebufferStatus ( GL_FRAMEBUFFER ) != GL_FRAMEBUFFER_COMPLETE ) {
		R_Printf ( PRINT_ALERT, "Failed to create reflection framebuffers\n" );
	}
/*
	glBindFramebuffer ( GL_FRAMEBUFFER, gl3state.refractFB );
	glFramebufferTexture ( GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, gl3state.refractTexture, 0 );
	glFramebufferTexture ( GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, gl3state.refractTextureDepth, 0 );
	glDrawBuffers ( 1, DrawBuffers );

	if ( glCheckFramebufferStatus ( GL_FRAMEBUFFER ) != GL_FRAMEBUFFER_COMPLETE ) {
		R_Printf ( PRINT_ALERT, "Failed to create refraction framebuffer\n" );
	}
*/
	// Set framebuffer target to default output
	glBindFramebuffer ( GL_FRAMEBUFFER, 0 );
}

void GL3_SurfShutdown(void)
{
	glDeleteBuffers ( 1, &gl3state.vbo3D );
	gl3state.vbo3D = 0;
	glDeleteVertexArrays ( 1, &gl3state.vao3D );
	gl3state.vao3D = 0;

	glDeleteBuffers ( 1, &gl3state.vbo3Dtrans );
	gl3state.vbo3D = 0;
	glDeleteVertexArrays ( 1, &gl3state.vao3Dtrans );
	gl3state.vao3D = 0;

	glDeleteBuffers(1, &gl3state.eboAlias);
	gl3state.eboAlias = 0;
	glDeleteBuffers(1, &gl3state.vboAlias);
	gl3state.vboAlias = 0;
	glDeleteVertexArrays(1, &gl3state.vaoAlias);
	gl3state.vaoAlias = 0;

	glDeleteFramebuffers ( 1, &gl3state.reflectFB );
	//glDeleteFramebuffers ( 1, &gl3state.refractFB );
	glDeleteTextures ( 1, &gl3state.reflectTexture );
	glDeleteTextures ( 1, &gl3state.reflectTextureDepth );

}

void GL_MultiDrawArrays ( void ) {
	if ( numarrays > MAX_INDICES ) {
		ri.Sys_Error ( ERR_DROP, __FUNCTION__": Array list overrun: %d, max %d\n", numarrays, MAX_INDICES );
	} else if ( numarrays ) {
		GL3_BindVAO ( gl3state.vao3D );
		GL3_BindVBO ( gl3state.vbo3D );
		glMultiDrawArrays ( GL_TRIANGLE_FAN, arraystart, arraylength, numarrays );
		numarrays = 0;
	}
}

void GL_DrawElements ( void ) {
	if ( gl_multiarray->value ) {
		GL_MultiDrawArrays ();
		return;
	}

	if ( numelements > MAX_INDICES ) {
		ri.Sys_Error ( ERR_DROP, __FUNCTION__": Element list overrun: %d, max %d\n", numelements, MAX_INDICES );
	} else if ( numelements ) {
		GL3_BindVAO ( gl3state.vao3D );
		GL3_BindVBO ( gl3state.vbo3D );
		//glBufferData ( GL_ARRAY_BUFFER, sizeof ( gl3_3D_vtx_t )*gl3_worldmodel->numglverts, gl3_worldmodel->glverts, GL_STREAM_DRAW );

		glDrawElements ( GL_TRIANGLE_FAN, numelements, GL_UNSIGNED_INT, elementlist );
		numelements = 0;
	}
}
/*
 * Returns true if the box is completely outside the frustom
 */
static qboolean
CullBox(vec3_t mins, vec3_t maxs)
{
	int i;

	if (!gl_cull->value)
	{
		return false;
	}

	hmm_vec4 Vmins, Vmaxs;
	vec3_t	tmins, tmaxs;
	Vmins.X = mins[ 0 ];
	Vmins.Y = mins[ 1 ];
	Vmins.Z = mins[ 2 ];
	Vmins.W = 1;
	if ( memcmp(&gl3state.modMatrix, &gl3_identityMat4, sizeof(hmm_mat4)) ) {
		Vmins = HMM_MultiplyMat4ByVec4 ( gl3state.modMatrix, Vmins );
	}
	tmins[ 0 ] = Vmins.X;
	tmins[ 1 ] = Vmins.Y;
	tmins[ 2 ] = Vmins.Z;

	Vmaxs.X = maxs[ 0 ];
	Vmaxs.Y = maxs[ 1 ];
	Vmaxs.Z = maxs[ 2 ];
	Vmaxs.W = 1;
	if ( memcmp ( &gl3state.modMatrix, &gl3_identityMat4, sizeof ( hmm_mat4 ) ) ) {
		Vmaxs = HMM_MultiplyMat4ByVec4 ( gl3state.modMatrix, Vmaxs );
	}
	tmaxs[ 0 ] = Vmaxs.X;
	tmaxs[ 1 ] = Vmaxs.Y;
	tmaxs[ 2 ] = Vmaxs.Z;

	if ( memcmp ( &gl3state.modMatrix, &gl3_identityMat4, sizeof ( hmm_mat4 ) ) ) {
		if ( Vmins.X > Vmaxs.X ) {
			tmaxs[ 0 ] = Vmins.X;
			tmins[ 0 ] = Vmaxs.X;
		}
		if ( Vmins.Y > Vmaxs.Y ) {
			tmaxs[ 1 ] = Vmins.Y;
			tmins[ 1 ] = Vmaxs.Y;
		}
		if ( Vmins.Z > Vmaxs.Z ) {
			tmaxs[ 2 ] = Vmins.Z;
			tmins[ 2 ] = Vmaxs.Z;
		}
	}
	for (i = 0; i < 4; i++)
	{
		if (BOX_ON_PLANE_SIDE(tmins, tmaxs, &frustum[i]) == 2)
		{
			return true;
		}
	}

	return false;
}

/*
 * Returns the proper texture for a given time and base texture
 */
static gl3image_t *
TextureAnimation(mtexinfo_t *tex)
{
	int c;

	if (!tex->next)
	{
		return tex->image;
	}

	c = currententity->frame % tex->numframes;

	while (c)
	{
		tex = tex->next;
		c--;
	}

	return tex->image;
}


static void
SetLightFlags(msurface_t *surf)
{
	unsigned int lightFlags = 0;
	if (surf->dlightframe == gl3_framecount)
	{
		lightFlags = surf->dlightbits;
	}

	gl3_3D_vtx_t* verts = surf->polys->vertices;

	int numVerts = surf->polys->numverts;
	for(int i=0; i<numVerts; ++i)
	{
		verts[i].lightFlags = lightFlags;
	}
}

static void
SetAllLightFlags(msurface_t *surf)
{
	unsigned int lightFlags = 0xffffffff;

	gl3_3D_vtx_t* verts = surf->polys->vertices;

	int numVerts = surf->polys->numverts;
	for(int i=0; i<numVerts; ++i)
	{
		verts[i].lightFlags = lightFlags;
	}
}

void
GL3_DrawGLPoly ( msurface_t *fa ) {
	glpoly_t *p = fa->polys;
	float scroll;

	if ( fa->flags & SURF_FLOWING ) {
		scroll = -64.0f * ( ( gl3_newrefdef.time / 40.0f ) - (int) ( gl3_newrefdef.time / 40.0f ) );

		if ( scroll == 0.0f ) {
			scroll = -64.0f;
		}
	} else {
		scroll = 0.0f;
	}

	if ( gl3state.uni3DData.scroll != scroll ) {
		gl3state.uni3DData.scroll = scroll;
		GL3_UpdateUBO3D ();
	}

	if ( gl_multiarray->value ) {
		arraystart[ numarrays ] = p->vertices - currentmodel->glverts;
		arraylength[ numarrays++ ] = p->numverts;
	} else {
		if ( numelements > 0 ) {
			elementlist[ numelements++ ] = -1;	// add primitive restart to list
		}
		for ( short i = 0; i < p->numverts; i++, numelements++ ) {
			elementlist[ numelements ] = ( p->vertices - gl3_worldmodel->glverts ) + i;
		}
	}

}
#if 0
void
GL3_DrawGLFlowingPoly(msurface_t *fa)
{
	glpoly_t *p;
	float scroll;

	p = fa->polys;

	scroll = -64.0f * ((gl3_newrefdef.time / 40.0f) - (int)(gl3_newrefdef.time / 40.0f));

	if (scroll == 0.0f)
	{
		scroll = -64.0f;
	}

	if(gl3state.uni3DData.scroll != scroll)
	{
		gl3state.uni3DData.scroll = scroll;
		GL3_UpdateUBO3D();
	}
/*
	GL3_BindVAO(gl3state.vao3D);
	GL3_BindVBO(gl3state.vbo3D);
	glBufferData(GL_ARRAY_BUFFER, sizeof(gl3_3D_vtx_t)*p->numverts, p->vertices, GL_STREAM_DRAW);
	glDrawArrays(GL_TRIANGLE_FAN, 0, p->numverts);
*/
	if ( -3 == gl3_worldmodel ) {	// HACK: somehow transparent bmodels aren't showing up in glDrawElements
		GL3_BindVAO ( gl3state.vao3Dtrans );
		GL3_BindVBO ( gl3state.vbo3Dtrans );
		glBufferData ( GL_ARRAY_BUFFER, sizeof ( gl3_3D_vtx_t )*p->numverts, p->vertices, GL_STREAM_DRAW );
		if ( ( ( p->vertices - gl3_worldmodel->glverts ) > gl3_worldmodel->numglverts ) ||
			( ( p->vertices - gl3_worldmodel->glverts ) < 0 ) ) {
			R_Printf ( PRINT_HIGH, "glvert out of bounds: %d, max = %d\n", p->vertices - gl3_worldmodel->glverts, gl3_worldmodel->numglverts );
		}
		glDrawArrays ( GL_TRIANGLE_FAN, 0, p->numverts );
		//glBufferData ( GL_ARRAY_BUFFER, sizeof ( gl3_3D_vtx_t ) * currentmodel->numglverts, currentmodel->glverts, GL_STATIC_DRAW );
		//glDrawArrays(GL_TRIANGLE_FAN, (p->vertices - currentmodel->glverts), p->numverts);
		GL3_BindVAO ( gl3state.vao3D );
		GL3_BindVBO ( gl3state.vbo3D );
	} else {
		if ( gl_multiarray->value ) {
			arraystart[ numarrays ] = p->vertices - currentmodel->glverts;
			arraylength[ numarrays++ ] = p->numverts;
		} else {
			if ( numelements > 0 ) {
				elementlist[ numelements++ ] = -1;	// add primitive restart to list
			}
			for ( short i = 0; i < p->numverts; i++, numelements++ ) {
				elementlist[ numelements ] = ( p->vertices - gl3_worldmodel->glverts ) + i;
			}
		}
	}
}
#endif

static void
UpdateLMscales(const hmm_vec4 lmScales[MAX_LIGHTMAPS_PER_SURFACE], gl3ShaderInfo_t* si)
{
	int i;
	qboolean hasChanged = false;

	for(i=0; i<MAX_LIGHTMAPS_PER_SURFACE; ++i)
	{
		if(hasChanged)
		{
			si->lmScales[i] = lmScales[i];
		}
		else if(   si->lmScales[i].R != lmScales[i].R
		        || si->lmScales[i].G != lmScales[i].G
		        || si->lmScales[i].B != lmScales[i].B
		        || si->lmScales[i].A != lmScales[i].A )
		{
			si->lmScales[i] = lmScales[i];
			hasChanged = true;
		}
	}

	if(hasChanged)
	{
		GL_DrawElements (); // render display list as state is being changed
		glUniform4fv(si->uniLmScales, MAX_LIGHTMAPS_PER_SURFACE, si->lmScales[0].Elements);
	}
}

static void
RenderBrushPoly(msurface_t *fa)
{
	int map;
	gl3image_t *image;

	c_brush_polys++;

	image = TextureAnimation(fa->texinfo);

	if (fa->flags & SURF_DRAWTURB)
	{
		GL3_Bind(image->texnum);

		GL3_EmitWaterPolys(fa);

		return;
	}
	else
	{
		GL3_Bind(image->texnum);
	}

	hmm_vec4 lmScales[MAX_LIGHTMAPS_PER_SURFACE] = {0};
	lmScales[0] = HMM_Vec4(1.0f, 1.0f, 1.0f, 1.0f);

	GL3_BindLightmap(fa->lightmaptexturenum);

	// Any dynamic lights on this surface?
	for (map = 0; map < MAX_LIGHTMAPS_PER_SURFACE && fa->styles[map] != 255; map++)
	{
		lmScales[map].R = gl3_newrefdef.lightstyles[fa->styles[map]].rgb[0];
		lmScales[map].G = gl3_newrefdef.lightstyles[fa->styles[map]].rgb[1];
		lmScales[map].B = gl3_newrefdef.lightstyles[fa->styles[map]].rgb[2];
		lmScales[map].A = 1.0f;
	}

	if (fa->texinfo->flags & SURF_FLOWING)
	{
		GL3_UseProgram(gl3state.si3DlmFlow.shaderProgram);
		UpdateLMscales(lmScales, &gl3state.si3DlmFlow);
		GL3_DrawGLPoly(fa);
	}
	else
	{
		GL3_UseProgram(gl3state.si3DlmFlow.shaderProgram);
		UpdateLMscales(lmScales, &gl3state.si3DlmFlow);
		GL3_DrawGLPoly(fa);
	}

	// Note: lightmap chains are gone, lightmaps are rendered together with normal texture in one pass
}

/*
 * Draw water surfaces and windows.
 * The BSP tree is waled front to back, so unwinding the chain
 * of alpha_surfaces will draw back to front, giving proper ordering.
 */
extern void GL3_DrawEntitiesOnList ( void );
extern void GL3_DrawParticles ( void );

void
GL3_DrawAlphaSurfaces(void)
{
	msurface_t *s;

	/* go back to the world matrix */
	GL_DrawElements ();
	gl3state.uni3DData.transModelMat4 = gl3_identityMat4;
	GL3_UpdateUBO3D();

	glEnable(GL_BLEND);

	for (s = gl3_alpha_surfaces; s != NULL; s = s->texturechain)
	{
		GL3_SelectTMU ( GL_TEXTURE5 );

		if ( s->plane == gl3state.refPlanes[ 0 ] && ( ( s->flags & SURF_PLANEBACK ) == ( gl3state.planeback[ 0 ] * SURF_PLANEBACK ) ) && (gl_reflection->value)) {
			glBindTexture ( GL_TEXTURE_2D_ARRAY, gl3state.reflectTexture );

			if ( gl3state.numRefPlanes > 0 && gl_reflection->value && gl3state.refVisframe[ 0 ] != gl3_framecount) {
				gl3state.refVisframe[ 0 ] = gl3_framecount;

				hmm_mat4 oldViewMat = gl3state.uni3DData.transModelMat4;
				hmm_vec4 plane = { gl3state.refPlanes[ 0 ]->normal[ 0 ],
					gl3state.refPlanes[ 0 ]->normal[ 1 ],
					gl3state.refPlanes[ 0 ]->normal[ 2 ],
					-gl3state.refPlanes[ 0 ]->dist };
				if ( !gl3state.planeback[ 0 ] ) {
					plane.X = -plane.X;
					plane.Y = -plane.Y;
					plane.Z = -plane.Z;
					plane.W = -plane.W;
				}
				gl3state.modMatrix = HMM_Householder ( plane, -1 );

				gl3state.uni3DData.transModelMat4 = HMM_MultiplyMat4 ( gl3state.modMatrix, gl3state.uni3DData.transModelMat4 );

				// start drawing to reflection buffer
				glBindFramebuffer ( GL_FRAMEBUFFER, gl3state.reflectFB );
				glViewport ( 0, 0, gl3_newrefdef.width, gl3_newrefdef.height );
				glClearColor ( 0, 0, 0, 0 );
				glClear ( GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT );
				//glEnable ( GL_CLIP_DISTANCE0 );

				gl3state.uni3DData.fluidPlane = plane;
				GL3_UpdateUBO3D ();
				//GL3_RenderView (fd);

				// Draw the world
				//GL3_MarkLeafs (); /* done here so we know if we're in water */
				glCullFace ( GL_BACK );

				float oldcull = gl_cullpvs->value;
				//gl_cullpvs->value = 0;
				GL3_DrawWorld ();
				GL3_DrawEntitiesOnList ();
				GL3_DrawParticles ();
				GL3_DrawAlphaSurfaces ();
				
				// Restore normal framebuffer
				gl_cullpvs->value = oldcull;
				glBindFramebuffer ( GL_FRAMEBUFFER, 0 );
				gl3state.uni3DData.transModelMat4 = oldViewMat;
				gl3state.uni3DData.fluidPlane = (hmm_vec4){ 0, 0, 0, 0 };
				glCullFace ( GL_FRONT );
				//glDisable ( GL_CLIP_DISTANCE0 );

				glEnable ( GL_BLEND );
				//		memcpy ( frustum, oldfrustum, sizeof ( cplane_t ) * 4 );
			}

		} else {
			glBindTexture ( GL_TEXTURE_2D_ARRAY, 0);
		}
		GL3_SelectTMU ( GL_TEXTURE0 );
/*
		if ( s->plane->normal[ 0 ] == gl3state.uni3DData.fluidPlane.X &&
			 s->plane->normal[ 1 ] == gl3state.uni3DData.fluidPlane.Y && 
			 s->plane->normal[ 2 ] == gl3state.uni3DData.fluidPlane.Z &&
			 s->plane->dist == gl3state.uni3DData.fluidPlane.W) {
			continue;
		}
*/
		GL3_Bind(s->texinfo->image->texnum);
		c_brush_polys++;
		float alpha = 1.0f;
		if (s->texinfo->flags & SURF_TRANS33)
		{
			alpha = 0.333f;
		}
		else if (s->texinfo->flags & SURF_TRANS66)
		{
			alpha = 0.666f;
		}
		if(alpha != gl3state.uni3DData.alpha)
		{
			gl3state.uni3DData.alpha = alpha;
			GL3_UpdateUBO3D();
		}

		if (s->flags & SURF_DRAWTURB)
		{
			GL3_EmitWaterPolys(s);
		}
		else if (s->texinfo->flags & SURF_FLOWING)
		{
			GL3_UseProgram(gl3state.si3DtransFlow.shaderProgram);
			GL3_DrawGLPoly(s);
		}
		else
		{
			GL3_UseProgram(gl3state.si3Dtrans.shaderProgram);
			GL3_DrawGLPoly(s);
		}
		GL_DrawElements ();
	}

	gl3state.uni3DData.alpha = 1.0f;
	GL3_UpdateUBO3D();

	glDisable(GL_BLEND);

	//gl3_alpha_surfaces = NULL;
}

static void
DrawTextureChains(void)
{
	int i;
	msurface_t *s;
	gl3image_t *image;

	c_visible_textures = 0;

	GL3_BindVAO ( gl3state.vao3D );
	GL3_BindVBO ( gl3state.vbo3D );
	
	for (i = 0, image = gl3textures; i < numgl3textures; i++, image++)
	{
		if (!image->registration_sequence)
		{
			continue;
		}

		s = image->texturechain;

		if (!s)
		{
			continue;
		}

		c_visible_textures++;


		for ( ; s; s = s->texturechain)
		{
			SetLightFlags(s);
			RenderBrushPoly(s);
		}
		GL_DrawElements ();
	}

	// TODO: maybe one loop for normal faces and one for SURF_DRAWTURB ???
}

static void
ClearTextureChains( void ) {
	int i;
	msurface_t *s;
	gl3image_t *image;

	for ( i = 0, image = gl3textures; i < numgl3textures; i++, image++ ) {
		if ( !image->registration_sequence ) {
			continue;
		}

		s = image->texturechain;

		if ( !s ) {
			continue;
		}

		image->texturechain = NULL;
	}

	gl3_alpha_surfaces = NULL;
}

static void
DrawTriangleOutlines( void ) {
	int i;
	msurface_t *s;
	gl3image_t *image;
	glpoly_t *p;

	if ( !gl_showtris->value ) {
		return;
	}

	//glDisable( GL_TEXTURE_2D );
	glDisable( GL_DEPTH_TEST );
	glPolygonMode( GL_FRONT_AND_BACK, GL_LINE );
	gl3state.uniCommonData.color = HMM_Vec4( 1, 1, 1, 1 );
	GL3_UpdateUBOCommon();

	GL3_UseProgram( gl3state.si3DcolorOnly.shaderProgram );

	for ( i = 0, image = gl3textures; i < numgl3textures; i++, image++ ) {
		if ( !image->registration_sequence ) {
			continue;
		}

		s = image->texturechain;

		if ( !s ) {
			continue;
		}

		for ( ; s; s = s->texturechain ) {
			GL3_DrawGLPoly ( s );
		}

	}
	GL_DrawElements ();

	GL3_BindVAO( gl3state.vao3Dtrans );
	GL3_BindVBO( gl3state.vbo3Dtrans );

	for ( s = gl3_alpha_surfaces; s != NULL; s = s->texturechain ) {
		for ( p = s->polys; p != NULL; p = p->next ) {
			glBufferData( GL_ARRAY_BUFFER, sizeof( gl3_3D_vtx_t )*p->numverts, p->vertices, GL_STREAM_DRAW );

			glDrawArrays( GL_TRIANGLE_FAN, 0, p->numverts );
		}
	}

	GL3_BindVAO ( gl3state.vao3D );
	GL3_BindVBO ( gl3state.vbo3D );

	glPolygonMode( GL_FRONT_AND_BACK, GL_FILL );
	//glEnable( GL_TEXTURE_2D );
	glEnable( GL_DEPTH_TEST );
}

static void
RenderLightmappedPoly(msurface_t *surf)
{
	int map;
	gl3image_t *image = TextureAnimation(surf->texinfo);

	hmm_vec4 lmScales[MAX_LIGHTMAPS_PER_SURFACE] = {0};
	lmScales[0] = HMM_Vec4(1.0f, 1.0f, 1.0f, 1.0f);

	assert((surf->texinfo->flags & (SURF_SKY | SURF_TRANS33 | SURF_TRANS66 | SURF_WARP)) == 0
			&& "RenderLightMappedPoly mustn't be called with transparent, sky or warping surfaces!");

	// Any dynamic lights on this surface?
	for (map = 0; map < MAX_LIGHTMAPS_PER_SURFACE && surf->styles[map] != 255; map++)
	{
		lmScales[map].R = gl3_newrefdef.lightstyles[surf->styles[map]].rgb[0];
		lmScales[map].G = gl3_newrefdef.lightstyles[surf->styles[map]].rgb[1];
		lmScales[map].B = gl3_newrefdef.lightstyles[surf->styles[map]].rgb[2];
		lmScales[map].A = 1.0f;
	}

	c_brush_polys++;

	GL3_Bind(image->texnum);
	GL3_BindLightmap(surf->lightmaptexturenum);

	if (surf->texinfo->flags & SURF_FLOWING)
	{
		GL3_UseProgram(gl3state.si3DlmFlow.shaderProgram);
		UpdateLMscales(lmScales, &gl3state.si3DlmFlow);
	}
	else
	{
		GL3_UseProgram(gl3state.si3Dlm.shaderProgram);
		UpdateLMscales(lmScales, &gl3state.si3Dlm);
	}
	GL3_DrawGLPoly ( surf );
}

static void
DrawInlineBModel(void)
{
	int i, k;
	cplane_t *pplane;
	float dot;
	msurface_t *psurf;
	dlight_t *lt;

	/* calculate dynamic lighting for bmodel */
	lt = gl3_newrefdef.dlights;

	for (k = 0; k < gl3_newrefdef.num_dlights; k++, lt++)
	{
		GL3_MarkLights(lt, 1 << k, currentmodel->nodes + currentmodel->firstnode);
	}

	psurf = &currentmodel->surfaces[currentmodel->firstmodelsurface];

	if (currententity->flags & RF_TRANSLUCENT)
	{
		glEnable(GL_BLEND);
		/* TODO: should I care about the 0.25 part? we'll just set alpha to 0.33 or 0.66 depending on surface flag..
		glColor4f(1, 1, 1, 0.25);
		R_TexEnv(GL_MODULATE);
		*/
	}

	/* draw texture */
	for (i = 0; i < currentmodel->nummodelsurfaces; i++, psurf++)
	{
		/* find which side of the node we are on */
		pplane = psurf->plane;

		dot = DotProduct(modelorg, pplane->normal) - pplane->dist;

		/* draw the polygon */
		if (((psurf->flags & SURF_PLANEBACK) && (dot < -BACKFACE_EPSILON)) ||
			(!(psurf->flags & SURF_PLANEBACK) && (dot > BACKFACE_EPSILON)))
		{
			if (psurf->texinfo->flags & (SURF_TRANS33 | SURF_TRANS66))
			{
				/* add to the translucent chain */
				psurf->texturechain = gl3_alpha_surfaces;
				gl3_alpha_surfaces = psurf;

				qboolean addPlane = true;
				for ( int r = 0; r < gl3state.numRefPlanes; r++ ) {
					if ( gl3state.refPlanes[ r ] == psurf->plane ) {
						// plane already in list
						addPlane = false;
						break;
					}
				}
				if ( addPlane ) {
					gl3state.refPlanes[ gl3state.numRefPlanes ] = psurf->plane;
					gl3state.planeback[ gl3state.numRefPlanes ] = ( psurf->flags & SURF_PLANEBACK ) != 0;
					gl3state.numRefPlanes++;
				}
			}
			else if(!(psurf->flags & SURF_DRAWTURB))
			{
				SetAllLightFlags(psurf);
				RenderLightmappedPoly(psurf);
			}
			else
			{
				RenderBrushPoly(psurf);
			}
			GL_DrawElements ();
		}
	}

	if (currententity->flags & RF_TRANSLUCENT)
	{
		glDisable(GL_BLEND);
	}
}

void
GL3_DrawBrushModel(entity_t *e)
{
	vec3_t mins, maxs;
	int i;
	qboolean rotated;

	if (currentmodel->nummodelsurfaces == 0)
	{
		return;
	}

	currententity = e;
	gl3state.currenttexture = -1;

	if (e->angles[0] || e->angles[1] || e->angles[2])
	{
		rotated = true;

		for (i = 0; i < 3; i++)
		{
			mins[i] = e->origin[i] - currentmodel->radius;
			maxs[i] = e->origin[i] + currentmodel->radius;
		}
	}
	else
	{
		rotated = false;
		VectorAdd(e->origin, currentmodel->mins, mins);
		VectorAdd(e->origin, currentmodel->maxs, maxs);
	}

	if (CullBox(mins, maxs))
	{
		return;
	}

	if (gl_zfix->value)
	{
		glEnable(GL_POLYGON_OFFSET_FILL);
	}

	VectorSubtract(gl3_newrefdef.vieworg, e->origin, modelorg);

	if (rotated)
	{
		vec3_t temp;
		vec3_t forward, right, up;

		VectorCopy(modelorg, temp);
		AngleVectors(e->angles, forward, right, up);
		modelorg[0] = DotProduct(temp, forward);
		modelorg[1] = -DotProduct(temp, right);
		modelorg[2] = DotProduct(temp, up);
	}



	//glPushMatrix();
	hmm_mat4 oldMat = gl3state.uni3DData.transModelMat4;

	e->angles[0] = -e->angles[0];
	e->angles[2] = -e->angles[2];
	GL3_RotateForEntity(e);
	e->angles[0] = -e->angles[0];
	e->angles[2] = -e->angles[2];

	GL3_BindVAO ( gl3state.vao3D );
	GL3_BindVBO ( gl3state.vbo3D );
	//glBufferData ( GL_ARRAY_BUFFER, sizeof ( gl3_3D_vtx_t )*gl3_worldmodel->numglverts, gl3_worldmodel->glverts, GL_STREAM_DRAW );

	DrawInlineBModel();

	// glPopMatrix();
	gl3state.uni3DData.transModelMat4 = oldMat;
	GL3_UpdateUBO3D();

	if (gl_zfix->value)
	{
		glDisable(GL_POLYGON_OFFSET_FILL);
	}
}

static void
RecursiveWorldNode(mnode_t *node)
{
	int c, side, sidebit;
	cplane_t *plane;
	msurface_t *surf, **mark;
	mleaf_t *pleaf;
	float dot;
	gl3image_t *image;

	if (node->contents == CONTENTS_SOLID)
	{
		return; /* solid */
	}

	if (node->visframe != gl3_visframecount)
	{
		return;
	}

	if (CullBox(node->minmaxs, node->minmaxs + 3) && gl_cullpvs->value)
	{
		return;
	}

	/* if a leaf node, draw stuff */
	if (node->contents != -1)
	{
		pleaf = (mleaf_t *)node;

		/* check for door connected areas */
		if (gl3_newrefdef.areabits)
		{
			if (!(gl3_newrefdef.areabits[pleaf->area >> 3] & (1 << (pleaf->area & 7))))
			{
				return; /* not visible */
			}
		}

		mark = pleaf->firstmarksurface;
		c = pleaf->nummarksurfaces;

		if (c)
		{
			do
			{
				(*mark)->visframe = gl3_framecount;
				mark++;
			}
			while (--c);
		}

		return;
	}

	/* node is just a decision point, so go down the apropriate
	   sides find which side of the node we are on */
	plane = node->plane;

	switch (plane->type)
	{
		case PLANE_X:
			dot = modelorg[0] - plane->dist;
			break;
		case PLANE_Y:
			dot = modelorg[1] - plane->dist;
			break;
		case PLANE_Z:
			dot = modelorg[2] - plane->dist;
			break;
		default:
			dot = DotProduct(modelorg, plane->normal) - plane->dist;
			break;
	}

	if (dot >= 0)
	{
		side = 0;
		sidebit = 0;
	}
	else
	{
		side = 1;
		sidebit = SURF_PLANEBACK;
	}

	/* recurse down the children, front side first */
	RecursiveWorldNode(node->children[side]);

	/* draw stuff */
	for (c = node->numsurfaces,
		 surf = gl3_worldmodel->surfaces + node->firstsurface;
		 c; c--, surf++)
	{
		if (surf->visframe != gl3_framecount)
		{
			continue;
		}

		if ((surf->flags & SURF_PLANEBACK) != sidebit)
		{
			continue; /* wrong side */
		}

		if ((surf->texinfo->flags & SURF_SKY) && (!gl_skycube->value))
		{
			/* just adds to visible sky bounds */
			GL3_AddSkySurface(surf);
		}
		else if (surf->texinfo->flags & (SURF_TRANS33 | SURF_TRANS66))
		{
			/* add to the translucent chain */
			surf->texturechain = gl3_alpha_surfaces;
			gl3_alpha_surfaces = surf;
			gl3_alpha_surfaces->texinfo->image = TextureAnimation(surf->texinfo);

			qboolean addPlane = true;
			for ( int r = 0; r < gl3state.numRefPlanes; r++ ) {
				if ( gl3state.refPlanes[ r ] == surf->plane ) {
					// plane already in list
					addPlane = false;
					break;
				}
			}
			if ( addPlane ) {
				gl3state.refPlanes[ gl3state.numRefPlanes ] = surf->plane;
				gl3state.planeback[ gl3state.numRefPlanes ] = (surf->flags & SURF_PLANEBACK) != 0;
				gl3state.numRefPlanes++;
			}
		}
		else
		{
			// calling RenderLightmappedPoly() here probably isn't optimal, rendering everything
			// through texturechains should be faster, because far less glBindTexture() is needed
			// (and it might allow batching the drawcalls of surfaces with the same texture)
#if 0
			if(!(surf->flags & SURF_DRAWTURB))
			{
				RenderLightmappedPoly(surf);
			}
			else
#endif // 0
			{
				/* the polygon is visible, so add it to the texture sorted chain */
				image = TextureAnimation(surf->texinfo);
				surf->texturechain = image->texturechain;
				image->texturechain = surf;
			}
		}
	}

	/* recurse down the back side */
	RecursiveWorldNode(node->children[!side]);
}

int chainviewcluster = -2;

void GL3_DrawWorld(void)
{
	entity_t ent;
	
	if (!gl_drawworld->value)
	{
		return;
	}

	if (gl3_newrefdef.rdflags & RDF_NOWORLDMODEL)
	{
		return;
	}
	numelements = 0;
	numarrays = 0;

	currentmodel = gl3_worldmodel;

	VectorCopy(gl3_newrefdef.vieworg, modelorg);

	/* auto cycle the world frame for texture animation */
	memset(&ent, 0, sizeof(ent));
	ent.frame = (int)(gl3_newrefdef.time * 2);
	currententity = &ent;

	gl3state.currenttexture = -1;
	glEnable ( GL_PRIMITIVE_RESTART_FIXED_INDEX );

	GL3_ClearSkyBox();	
	ClearTextureChains ();

	gl3state.numRefPlanes = 0;

	RecursiveWorldNode ( gl3_worldmodel->nodes );
	DrawTextureChains();
	GL3_DrawSkyBox();
	DrawTriangleOutlines();

	currententity = NULL;
}

/*
 * Mark the leafs and nodes that are
 * in the PVS for the current cluster
 */
void
GL3_MarkLeafs(void)
{
	byte *vis;
	byte fatvis[MAX_MAP_LEAFS / 8];
	mnode_t *node;
	int i, c;
	mleaf_t *leaf;
	int cluster;

	if ((gl3_oldviewcluster == gl3_viewcluster) &&
		(gl3_oldviewcluster2 == gl3_viewcluster2) &&
		!gl_novis->value &&
		(gl3_viewcluster != -1))
	{
		return;
	}

	/* development aid to let you run around
	   and see exactly where the pvs ends */
	if (gl_lockpvs->value)
	{
		return;
	}

	gl3_visframecount++;
	gl3_oldviewcluster = gl3_viewcluster;
	gl3_oldviewcluster2 = gl3_viewcluster2;

	if (gl_novis->value || (gl3_viewcluster == -1) || !gl3_worldmodel->vis)
	{
		/* mark everything */
		for (i = 0; i < gl3_worldmodel->numleafs; i++)
		{
			gl3_worldmodel->leafs[i].visframe = gl3_visframecount;
		}

		for (i = 0; i < gl3_worldmodel->numnodes; i++)
		{
			gl3_worldmodel->nodes[i].visframe = gl3_visframecount;
		}

		return;
	}

	vis = GL3_Mod_ClusterPVS(gl3_viewcluster, gl3_worldmodel);

	/* may have to combine two clusters because of solid water boundaries */
	if (gl3_viewcluster2 != gl3_viewcluster)
	{
		memcpy(fatvis, vis, (gl3_worldmodel->numleafs + 7) / 8);
		vis = GL3_Mod_ClusterPVS(gl3_viewcluster2, gl3_worldmodel);
		c = (gl3_worldmodel->numleafs + 31) / 32;

		for (i = 0; i < c; i++)
		{
			((int *)fatvis)[i] |= ((int *)vis)[i];
		}

		vis = fatvis;
	}

	for (i = 0, leaf = gl3_worldmodel->leafs;
		 i < gl3_worldmodel->numleafs;
		 i++, leaf++)
	{
		cluster = leaf->cluster;

		if (cluster == -1)
		{
			continue;
		}

		if (vis[cluster >> 3] & (1 << (cluster & 7)))
		{
			node = (mnode_t *)leaf;

			do
			{
				if (node->visframe == gl3_visframecount)
				{
					break;
				}

				node->visframe = gl3_visframecount;
				node = node->parent;
			}
			while (node);
		}
	}
}

