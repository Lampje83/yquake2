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
 * Lightmaps and dynamic lighting
 *
 * =======================================================================
 */

#include "header/local.h"

extern gl3lightmapstate_t gl3_lms;

#define DLIGHT_CUTOFF 64

static int r_dlightframecount;
static vec3_t pointcolor;
static cplane_t *lightplane; /* used as shadow plane */
vec3_t lightspot;

qboolean	gl3_shadowmode;		// ERIK: flag for rendering the world in shadow mode

void // bit: 1 << i for light number i, will be or'ed into msurface_t::dlightbits if surface is affected by this light
GL3_MarkLights(dlight_t *light, int bit, mnode_t *node)
{
	cplane_t *splitplane;
	float dist;
	msurface_t *surf;
	int i;
	int sidebit;

	if (node->contents != -1)
	{
		return;
	}

	splitplane = node->plane;
	dist = DotProduct(light->origin, splitplane->normal) - splitplane->dist;

	if (dist > light->intensity - DLIGHT_CUTOFF)
	{
		GL3_MarkLights(light, bit, node->children[0]);
		return;
	}

	if (dist < -light->intensity + DLIGHT_CUTOFF)
	{
		GL3_MarkLights(light, bit, node->children[1]);
		return;
	}

	/* mark the polygons */
	surf = gl3_worldmodel->surfaces + node->firstsurface;

	for (i = 0; i < node->numsurfaces; i++, surf++)
	{
		if (surf->dlightframe != r_dlightframecount)
		{
			surf->dlightbits = 0;
			surf->dlightframe = r_dlightframecount;
		}

		dist = DotProduct(light->origin, surf->plane->normal) - surf->plane->dist;

		if (dist >= 0)
		{
			sidebit = 0;
		}
		else
		{
			sidebit = SURF_PLANEBACK;
		}

		if ((surf->flags & SURF_PLANEBACK) != sidebit)
		{
			continue;
		}

		surf->dlightbits |= bit;
	}

	GL3_MarkLights(light, bit, node->children[0]);
	GL3_MarkLights(light, bit, node->children[1]);
}

// setup projection matrix for cube map

static hmm_mat4
GL3_MYcubePerspective(GLdouble fovy, GLdouble zNear, GLdouble zFar)
{
	// calculation of left, right, bottom, top is from R_MYgluPerspective() of old gl backend
	// which seems to be slightly different from the real gluPerspective()
	// and thus also from HMM_Perspective()
	GLdouble bottom, top;
	float B, C, D;

	top = zNear * tan(fovy * M_PI / 360.0);
	bottom = -top;

	B = (top + bottom) / (top - bottom);
	C = -(zFar + zNear) / (zFar - zNear);
	D = -(2.0*zFar*zNear) / (zFar - zNear);

	hmm_mat4 ret = { {
		{ (2.0*zNear) / (top - bottom), 0, 0, 0 }, // first *column*
		{ 0, (2.0*zNear) / (top - bottom), 0, 0 },
		{ B, B, C, -1.0 },
		{ 0, 0, D, 0 }
		} };

	return ret;
}

GLuint m_fbo = 0;
GLuint m_shadowMap = 0;
GLuint m_depth = 0;
#define SHADOWMAPSIZE 1024

void GL3_RenderShadows(void)
{
	if (!gl3_newrefdef.num_dlights)
		// no dlights, quit
		return;

	// DYNAMIC LIGHTS
	// For each dlight, render the scene into a cubemap using 6 frustum cones,
	// with the dlight as view origin. Each cone can be tested against the player
	// view frustum, and skip rendering accordingly
	// Only brush surfaces marked with the correct dlight bit have to be rendered

	// Setup GL parameters and depth texture buffers

	// Create the FBO
	if (!m_fbo) { glGenFramebuffers(1, &m_fbo); }

	// Create the depth buffer
	if (!m_depth) {
		glGenTextures(1, &m_depth);
		GL3_Bind (GL_TEXTURE_2D, 0, m_depth);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT32, SHADOWMAPSIZE, SHADOWMAPSIZE, 0, GL_DEPTH_COMPONENT, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
	}
	else {
		GL3_Bind (GL_TEXTURE_2D, 0, m_depth);
	}

	// Create the cube map
	if (!m_shadowMap) {
		glGenTextures(1, &m_shadowMap);
		GL3_Bind (GL_TEXTURE_CUBE_MAP, 0, m_shadowMap);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_CUBE_MAP, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);

		// Setup the cube textures
		for (int i = 0; i < 6; i++) {
			glTexImage2D(GL_TEXTURE_CUBE_MAP_POSITIVE_X + i, 0, GL_R32F, SHADOWMAPSIZE, SHADOWMAPSIZE, 0, GL_RED, GL_FLOAT, NULL);
		}
	}
	else {
		GL3_Bind (GL_TEXTURE_CUBE_MAP, 0, m_shadowMap);
	}

	// Setup depth frame buffer

	glBindFramebuffer(GL_FRAMEBUFFER, m_fbo);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, m_depth, 0);

	// Disable writes to the color buffer
	glDrawBuffer(GL_NONE);

	// Disable reads from the color buffer
	glReadBuffer(GL_NONE);

	GLenum Status = glCheckFramebufferStatus(GL_FRAMEBUFFER);

	if (Status != GL_FRAMEBUFFER_COMPLETE) {
		ri.Sys_Error (ERR_DROP, "GL3_RenderShadows: FB error, status: 0x%x\n", Status);
		return;
	}

	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	// Setup projection and view matrix

	gl3state.uni3DData.transProjMat4 = GL3_MYcubePerspective(90, 4, 128);

	// TODO: Setup multiple view matrices for each dlight?
	/* set up view matrix (world coordinates -> light coordinates) */
	{
		hmm_vec3 origin = { gl3_newrefdef.dlights[0].origin[0],
							gl3_newrefdef.dlights[0].origin[1],
							gl3_newrefdef.dlights[0].origin[2] };
		hmm_mat4 viewMat = HMM_LookAt(origin, HMM_Vec3(-1, 0, 0), HMM_Vec3(0, 0, -1));

		gl3state.uni3DData.transViewMat4 = viewMat;
	}

	// TODO: Render model into shadow map textures

	gl3_shadowmode = true;

	// Draw to the cubemap texture
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, m_fbo);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_CUBE_MAP_NEGATIVE_X, m_shadowMap, 0);
	glDrawBuffer(GL_COLOR_ATTACHMENT0);

	GL3_DrawWorld();

	// GL3_DrawEntitiesOnList();

	// STATIC LIGHTS
	// For static lights, render only the alias models in the shadow buffer cubemaps
	// Still have to determine how occlusion is realized for each light,
	// since really static (not color or intensity changing) lights are blended together
	// into the lightmaps

	// END
	// Put GL state back
	glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
	glDrawBuffer(GL_NONE);

	GLenum err = glGetError();
	if (err != GL_NO_ERROR)
	{
		ri.Sys_Error(ERR_DROP, "GL3_RenderShadows: GL error 0x%x raised\n", err);
	}

	gl3_shadowmode = false;

	gl3state.uni3DData.transProjMat4 = gl3_projectionMatrix;
	gl3state.uni3DData.transViewMat4 = gl3_world_matrix;
	gl3state.uni3DData.transModelMat4 = gl3_identityMat4;

}

void GL3_PushDlights(void)
{
	int i;
	dlight_t *l;

	/* because the count hasn't advanced yet for this frame */
	r_dlightframecount = gl3_framecount + 1;

	l = gl3_newrefdef.dlights;

	gl3state.uniLightsData.numDynLights = gl3_newrefdef.num_dlights;

	for (i = 0; i < gl3_newrefdef.num_dlights; i++, l++)
	{
		gl3UniDynLight* udl = &gl3state.uniLightsData.dynLights[i];
		GL3_MarkLights(l, 1 << i, gl3_worldmodel->nodes);

		VectorCopy(l->origin, udl->origin);
		VectorCopy(l->color, udl->color);
		udl->intensity = l->intensity;
	}

	assert(MAX_DLIGHTS == 32 && "If MAX_DLIGHTS changes, remember to adjust the uniform buffer definition in the shader!");

	if(i < MAX_DLIGHTS)
	{
		memset(&gl3state.uniLightsData.dynLights[i], 0, (MAX_DLIGHTS-i)*sizeof(gl3state.uniLightsData.dynLights[0]));
	}
	// GL3_RenderShadows();

	GL3_UpdateUBOLights();
}

static int
RecursiveLightPoint(mnode_t *node, vec3_t start, vec3_t end)
{
	float front, back, frac;
	int side;
	cplane_t *plane;
	vec3_t mid;
	msurface_t *surf;
	int s, t, ds, dt;
	int i;
	mtexinfo_t *tex;
	byte *lightmap;
	int maps;
	int r;

	if (node->contents != -1)
	{
		return -1;     /* didn't hit anything */
	}

	/* calculate mid point */
	plane = node->plane;
	front = DotProduct(start, plane->normal) - plane->dist;
	back = DotProduct(end, plane->normal) - plane->dist;
	side = front < 0;

	if ((back < 0) == side)
	{
		return RecursiveLightPoint(node->children[side], start, end);
	}

	frac = front / (front - back);
	mid[0] = start[0] + (end[0] - start[0]) * frac;
	mid[1] = start[1] + (end[1] - start[1]) * frac;
	mid[2] = start[2] + (end[2] - start[2]) * frac;

	/* go down front side */
	r = RecursiveLightPoint(node->children[side], start, mid);

	if (r >= 0)
	{
		return r;     /* hit something */
	}

	if ((back < 0) == side)
	{
		return -1;     /* didn't hit anuthing */
	}

	/* check for impact on this node */
	VectorCopy(mid, lightspot);
	lightplane = plane;

	surf = gl3_worldmodel->surfaces + node->firstsurface;

	for (i = 0; i < node->numsurfaces; i++, surf++)
	{
		if (surf->flags & (SURF_DRAWTURB | SURF_DRAWSKY))
		{
			continue; /* no lightmaps */
		}

		tex = surf->texinfo;

		s = DotProduct(mid, tex->vecs[0]) + tex->vecs[0][3];
		t = DotProduct(mid, tex->vecs[1]) + tex->vecs[1][3];

		if ((s < surf->texturemins[0]) ||
			(t < surf->texturemins[1]))
		{
			continue;
		}

		ds = s - surf->texturemins[0];
		dt = t - surf->texturemins[1];

		if ((ds > surf->extents[0]) || (dt > surf->extents[1]))
		{
			continue;
		}

		if (!surf->samples)
		{
			return 0;
		}

		ds >>= 4;
		dt >>= 4;

		lightmap = surf->samples;
		VectorCopy(vec3_origin, pointcolor);

		if (lightmap)
		{
			vec3_t scale;

			lightmap += 3 * (dt * ((surf->extents[0] >> 4) + 1) + ds);

			for (maps = 0; maps < MAX_LIGHTMAPS_PER_SURFACE && surf->styles[maps] != 255;
				 maps++)
			{
				for (i = 0; i < 3; i++)
				{
					scale[i] = gl_modulate->value *
							   gl3_newrefdef.lightstyles[surf->styles[maps]].rgb[i];
				}

				pointcolor[0] += lightmap[0] * scale[0] * (1.0 / 255);
				pointcolor[1] += lightmap[1] * scale[1] * (1.0 / 255);
				pointcolor[2] += lightmap[2] * scale[2] * (1.0 / 255);
				lightmap += 3 * ((surf->extents[0] >> 4) + 1) *
							((surf->extents[1] >> 4) + 1);
			}
		}

		return 1;
	}

	/* go down back side */
	return RecursiveLightPoint(node->children[!side], mid, end);
}

void
GL3_LightPoint(vec3_t p, vec3_t color)
{
	vec3_t end;
	float r;
	int lnum;
	dlight_t *dl;
	vec3_t dist;
	float add;

	if (!gl3_worldmodel->lightdata || !currententity)
	{
		color[0] = color[1] = color[2] = 1.0;
		return;
	}

	end[0] = p[0];
	end[1] = p[1];
	end[2] = p[2] - 2048;

	// TODO: don't just aggregate the color, but also save position of brightest+nearest light
	//       for shadow position and maybe lighting on model?

	r = RecursiveLightPoint(gl3_worldmodel->nodes, p, end);

	if (r == -1)
	{
		VectorCopy(vec3_origin, color);
	}
	else
	{
		VectorCopy(pointcolor, color);
	}

	/* add dynamic lights */
	dl = gl3_newrefdef.dlights;

	for (lnum = 0; lnum < gl3_newrefdef.num_dlights; lnum++, dl++)
	{
		VectorSubtract(currententity->origin,
				dl->origin, dist);
		add = dl->intensity - VectorLength(dist);
		add *= (1.0f / 256.0f);

		if (add > 0)
		{
			VectorMA(color, add, dl->color, color);
		}
	}

	VectorScale(color, gl_modulate->value, color);
}


/*
 * Combine and scale multiple lightmaps into the floating format in blocklights
 */
void
GL3_BuildLightMap(msurface_t *surf, int offsetInLMbuf, int stride)
{
	int smax, tmax;
	int r, g, b, a, max;
	int i, j, size, map, numMaps;
	byte *lightmap;

	if (surf->texinfo->flags &
		(SURF_SKY | SURF_TRANS33 | SURF_TRANS66 | SURF_WARP))
	{
		ri.Sys_Error(ERR_DROP, "GL3_BuildLightMap called for non-lit surface");
	}

	smax = (surf->extents[0] >> 4) + 1;
	tmax = (surf->extents[1] >> 4) + 1;
	size = smax * tmax;

	stride -= (smax << 2);

	if (size > 34*34*3)
	{
		ri.Sys_Error(ERR_DROP, "Bad s_blocklights size");
	}

	// count number of lightmaps surf actually has
	for (numMaps = 0; numMaps < MAX_LIGHTMAPS_PER_SURFACE && surf->styles[numMaps] != 255; ++numMaps)
	{}

	if (!surf->samples)
	{
		// no lightmap samples? set at least one lightmap to fullbright, rest to 0 as normal

		if (numMaps == 0)  numMaps = 1; // make sure at least one lightmap is set to fullbright

		for (map = 0; map < MAX_LIGHTMAPS_PER_SURFACE; ++map)
		{
			// we always create 4 (MAX_LIGHTMAPS_PER_SURFACE) lightmaps.
			// if surf has less (numMaps < 4), the remaining ones are zeroed out.
			// this makes sure that all 4 lightmap textures in gl3state.lightmap_textureIDs[i] have the same layout
			// and the shader can use the same texture coordinates for all of them

			int c = (map < numMaps) ? 255 : 0;
			byte* dest = gl3_lms.lightmap_buffers[map] + offsetInLMbuf;

			for (i = 0; i < tmax; i++, dest += stride)
			{
				memset(dest, c, 4*smax);
				dest += 4*smax;
			}
		}

		return;
	}

	/* add all the lightmaps */

	// Note: dynamic lights aren't handled here anymore, they're handled in the shader

	// as we don't apply scale here anymore, nor blend the numMaps lightmaps together,
	// the code has gotten a lot easier and we can copy directly from surf->samples to dest
	// without converting to float first etc

	lightmap = surf->samples;

	for(map=0; map<numMaps; ++map)
	{
		byte* dest = gl3_lms.lightmap_buffers[map] + offsetInLMbuf;
		int idxInLightmap = 0;
		for (i = 0; i < tmax; i++, dest += stride)
		{
			for (j = 0; j < smax; j++)
			{
				r = lightmap[idxInLightmap * 3 + 0];
				g = lightmap[idxInLightmap * 3 + 1];
				b = lightmap[idxInLightmap * 3 + 2];

				/* determine the brightest of the three color components */
				if (r > g)  max = r;
				else  max = g;

				if (b > max)  max = b;

				/* alpha is ONLY used for the mono lightmap case. For this
				   reason we set it to the brightest of the color components
				   so that things don't get too dim. */
				a = max;

				dest[0] = r;
				dest[1] = g;
				dest[2] = b;
				dest[3] = a;

				dest += 4;
				++idxInLightmap;
			}
		}

		lightmap += size * 3; /* skip to next lightmap */
	}

	for ( ; map < MAX_LIGHTMAPS_PER_SURFACE; ++map)
	{
		// like above, fill up remaining lightmaps with 0

		byte* dest = gl3_lms.lightmap_buffers[map] + offsetInLMbuf;

		for (i = 0; i < tmax; i++, dest += stride)
		{
			memset(dest, 0, 4*smax);
			dest += 4*smax;
		}
	}
}

