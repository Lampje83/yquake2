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
 * OpenGL3 refresher: Handling shaders
 *
 * =======================================================================
 */

/* TODO: Reorganize shaders

Global pipelines needed:
- 2D
- 3D brush
- 3D alias
  - Sprites could be realized with a (different) geometry shader
- Particles
Effects like:
- Laser beams
- Rail spiral
- etc

Reflected / refracted positions should be calculated in vertex shader,
	in case of refraction, a flag should be set in uniform buffer.
	and tessellation can happen appropiately
If a shockwave effect is to be introduced, this can happen in tessellation stage also
Tesselation stage is also responsible for culling of triangles outside of
	reflection/refraction window

Geometry shader will only be used to generate quads for 2D triangles, or sprites
Its PRIMARY function will be to select the appropiate framebuffer layer for rendering
Consider using extension GL_AMD_VERTEX_SHADER_LAYER extension to skip GS altogether

The geometry shader will also be used to generate depth cubemaps, using a different
geometry shader file.

The fragment shader should be as pluggable as possible, like a universal
appliable material.

Texture coordinate attribute should be one vec4, which can be used as color for
textureless objects
*/

#include "header/local.h"

// TODO: remove eprintf() usage
#define eprintf(...)  R_Printf(PRINT_ALL, __VA_ARGS__)

const char* commonSrc;

static GLuint
CompileShader (GLenum shaderType, const char* shaderSrc, const char* shaderSrc2) {
	GLuint shader = glCreateShader (shaderType);

	if (commonSrc == NULL) {
		int fileSize = ri.FS_LoadFile ("shaders/Common.glsl", (void **) &commonSrc);
		if (!fileSize || commonSrc == NULL) {
			commonSrc = NULL;
			R_Printf (PRINT_ALL, "WARNING: Failed to load common shader library!\n");
		}
	}

	const char* sources[3] = { commonSrc, shaderSrc, shaderSrc2 };
	int numSources = shaderSrc2 != NULL ? 3 : 2;

	if (commonSrc != NULL) {
		glShaderSource (shader, numSources, sources, NULL);
	} else {
		// no common shader file found
		glShaderSource (shader, numSources - 1, sources + 1, NULL);
	}
	glCompileShader (shader);
	GLint status;
	glGetShaderiv (shader, GL_COMPILE_STATUS, &status);

	char buf[2048];
	char* bufPtr = buf;
	int bufLen = sizeof (buf);
	GLint infoLogLength;
	glGetShaderiv (shader, GL_INFO_LOG_LENGTH, &infoLogLength);
	if (infoLogLength >= bufLen) {
		bufPtr = malloc (infoLogLength + 1);
		bufLen = infoLogLength + 1;
		if (bufPtr == NULL) {
			bufPtr = buf;
			bufLen = sizeof (buf);
			R_Printf (PRINT_ALL, "WARN: In CompileShader(), malloc(%d) failed!\n", infoLogLength + 1);
		}
	}

	glGetShaderInfoLog (shader, bufLen, NULL, bufPtr);

	const char* shaderTypeStr = "";
	switch (shaderType) {
		case GL_VERTEX_SHADER:   shaderTypeStr = "Vertex"; break;
		case GL_FRAGMENT_SHADER: shaderTypeStr = "Fragment"; break;
		case GL_GEOMETRY_SHADER: shaderTypeStr = "Geometry"; break;
		case GL_COMPUTE_SHADER:  shaderTypeStr = "Compute"; break;
		case GL_TESS_CONTROL_SHADER:    shaderTypeStr = "TessControl"; break;
		case GL_TESS_EVALUATION_SHADER: shaderTypeStr = "TessEvaluation"; break;
	}
	if (status != GL_TRUE) {
		R_Printf (PRINT_ALL, "ERROR: Compiling %s Shader failed: %s\n", shaderTypeStr, bufPtr);
		glDeleteShader (shader);

		if (bufPtr != buf)  free (bufPtr);

		return 0;
	}
	else if (infoLogLength >= 3) {
		R_Printf (PRINT_ALL, "%s shader: %s\n", shaderTypeStr, bufPtr);
	}
	return shader;
}
static void BindAttribLocations (int shaderProgram) {
	// make sure all shaders use the same attribute locations for common attributes
	// (so the same VAO can easily be used with different shaders)
	glBindAttribLocation (shaderProgram, GL3_ATTRIB_POSITION, "position");
	glBindAttribLocation (shaderProgram, GL3_ATTRIB_TEXCOORD, "texCoord");
	glBindAttribLocation (shaderProgram, GL3_ATTRIB_LMTEXCOORD, "lmTexCoord");
	glBindAttribLocation (shaderProgram, GL3_ATTRIB_COLOR, "vertColor");
	glBindAttribLocation (shaderProgram, GL3_ATTRIB_NORMAL, "normal");
	glBindAttribLocation (shaderProgram, GL3_ATTRIB_LIGHTFLAGS, "lightFlags");
	glBindAttribLocation (shaderProgram, GL3_ATTRIB_SURFFLAGS, "surfFlags");
	glBindAttribLocation (shaderProgram, GL3_ATTRIB_REFINDEX, "refIndex");
}

static GLuint
CreateShaderProgram(int numShaders, const GLuint* shaders)
{
	int i=0;

	GLuint shaderProgram = glCreateProgram();

	if(shaderProgram == 0) {
		R_Printf (PRINT_ALL, "ERROR: Couldn't create a new Shader Program!\n");
		return 0;
	}

	for(i=0; i<numShaders; ++i) {
		glAttachShader(shaderProgram, shaders[i]);
		int err = glGetError ();
		if (err != GL_NO_ERROR) {
			R_Printf (PRINT_ALL, __FUNCTION__": Error %i while attaching shader. Program #%i, shader #%i at index %i\n", err, shaderProgram, shaders[i], i);
		}

		char message[8192];
		int msglen;
		glGetShaderInfoLog (shaders[i], sizeof (message), &msglen, message);

		if (msglen >= 3) {
			R_Printf (PRINT_ALL, "%s\n", message);
		}
		if (glIsShader (shaders[i]) == false)
			R_Printf (PRINT_ALL, "#%i is not a valid shader object\n", shaders[i]);
	}

	// the following line is not necessary/implicit (as there's only one output)
	// glBindFragDataLocation(shaderProgram, 0, "outColor"); XXX would this even be here?
	BindAttribLocations (shaderProgram);

	glProgramParameteri (shaderProgram, GL_PROGRAM_SEPARABLE, GL_TRUE);
	glLinkProgram(shaderProgram);

	GLint status;
	glGetProgramiv(shaderProgram, GL_LINK_STATUS, &status);
	{
		char buf[2048];
		char* bufPtr = buf;
		int bufLen = sizeof(buf);
		GLint infoLogLength;
		glGetProgramiv(shaderProgram, GL_INFO_LOG_LENGTH, &infoLogLength);
		if(infoLogLength >= bufLen)
		{
			bufPtr = malloc(infoLogLength+1);
			bufLen = infoLogLength+1;
			if(bufPtr == NULL)
			{
				bufPtr = buf;
				bufLen = sizeof(buf);
				eprintf("WARN: In CreateShaderProgram(), malloc(%d) failed!\n", infoLogLength+1);
			}
		}

		glGetProgramInfoLog(shaderProgram, bufLen, NULL, bufPtr);

		if (status != GL_TRUE) {
			eprintf ("ERROR: Linking shader program failed: %s\n", bufPtr);

			glDeleteProgram (shaderProgram);

			if (bufPtr != buf)  free (bufPtr);

			return 0;
		}
		else {
			if (infoLogLength > 3) {
				R_Printf (PRINT_ALL, "Linking shader program succeeded: %s\n", bufPtr);
			}			
		}
	}

	for(i=0; i<numShaders; ++i)
	{
		// after linking, they don't need to be attached anymore.
		// no idea  why they even are, if they don't have to..
		glDetachShader(shaderProgram, shaders[i]);
	}

	return shaderProgram;
}

enum UniformBlocks {
	GL3_BINDINGPOINT_UNICOMMON,
	GL3_BINDINGPOINT_UNI2D,
	GL3_BINDINGPOINT_UNI3D,
	GL3_BINDINGPOINT_UNILIGHTS,
	GL3_BINDINGPOINT_REFDATA
};

static qboolean
initShader2D(gl3ShaderInfo_t* shaderInfo, const char* vertFilename, const char* fragFilename, const char *shaderDesc)
{
	GLuint shaders2D[2] = {0};
	GLuint prog = 0;

	char*	vertSrc;
	char*	fragSrc;
	int		fileSize;

	if(shaderInfo->shaderProgram != 0)
	{
		R_Printf(PRINT_ALL, "WARNING: calling initShader2D for gl3ShaderInfo_t that already has a shaderProgram!\n");
		glDeleteProgram(shaderInfo->shaderProgram);
	}

	if ( !( fileSize = ri.FS_LoadFile( fragFilename, (void **) &fragSrc ) ) ) {
		R_Printf( PRINT_ALL, __FUNCTION__": Failed to load 2D fragment shader!\n" );
		return false;
	}
	//fragSrc[fileSize] = 0;

	if ( !( fileSize = ri.FS_LoadFile( vertFilename, (void **) &vertSrc ) ) ) {
		R_Printf( PRINT_ALL, __FUNCTION__": Failed to load 2D vertex shader!\n" );
		ri.FS_FreeFile( (void *) fragSrc );
		return false;
	}
	//vertSrc[fileSize] = 0;

	//shaderInfo->uniColor = shaderInfo->uniProjMatrix = shaderInfo->uniModelViewMatrix = -1;
	shaderInfo->shaderProgram = 0;
	shaderInfo->uniLmScales = -1;

	shaders2D[0] = CompileShader(GL_VERTEX_SHADER, vertSrc, NULL);
	if (shaders2D[0] == 0)  goto err_cleanup;

	shaders2D[1] = CompileShader(GL_FRAGMENT_SHADER, fragSrc, NULL);
	if(shaders2D[1] == 0)
	{
		glDeleteShader(shaders2D[0]);
		goto err_cleanup;
	}

	prog = CreateShaderProgram(2, shaders2D);
	//BindAttribLocations (prog);

	// I think the shaders aren't needed anymore once they're linked into the program
	glDeleteShader(shaders2D[0]);
	glDeleteShader(shaders2D[1]);

	if(prog == 0)
	{
		goto err_cleanup;
	}

	shaderInfo->shaderProgram = prog;

	// Create program pipeline
	glGenProgramPipelines (1, &shaderInfo->shaderProgramPipeline);
	if (shaderInfo->shaderProgramPipeline == 0) {
		R_Printf (PRINT_ALL, "Failed to create program pipeline for %s\n", shaderDesc);
		goto err_cleanup;
	}
	glUseProgramStages (shaderInfo->shaderProgramPipeline, GL_VERTEX_SHADER_BIT | GL_FRAGMENT_SHADER_BIT, prog);

	GL3_UseProgram(prog);

	// Bind the buffer object to the uniform blocks
	GLuint blockIndex = glGetUniformBlockIndex(prog, "uniCommon");
	if(blockIndex != GL_INVALID_INDEX)
	{
		GLint blockSize;
		glGetActiveUniformBlockiv(prog, blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, &blockSize);
		if(blockSize != sizeof(gl3state.uniCommonData))
		{
			R_Printf(PRINT_ALL, "WARNING: OpenGL driver disagrees with us about UBO size of 'uniCommon': %i vs %i\n",
					blockSize, (int)sizeof(gl3state.uniCommonData));

			goto err_cleanup;
		}

		glUniformBlockBinding(prog, blockIndex, GL3_BINDINGPOINT_UNICOMMON);
	}
	else
	{
		R_Printf(PRINT_ALL, "WARNING: Couldn't find uniform block index 'uniCommon' in program %s\n", shaderDesc);
		// TODO: clean up?
		return false;
	}
	blockIndex = glGetUniformBlockIndex(prog, "uni2D");
	if(blockIndex != GL_INVALID_INDEX)
	{
		GLint blockSize;
		glGetActiveUniformBlockiv(prog, blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, &blockSize);
		if(blockSize != sizeof(gl3state.uni2DData))
		{
			R_Printf(PRINT_ALL, "WARNING: OpenGL driver disagrees with us about UBO size of 'uni2D'\n");
			goto err_cleanup;
		}

		glUniformBlockBinding(prog, blockIndex, GL3_BINDINGPOINT_UNI2D);
	}
	else
	{
		R_Printf(PRINT_ALL, "WARNING: Couldn't find uniform block index 'uni2D'\n");
		goto err_cleanup;
	}

	ri.FS_FreeFile( (void *) fragSrc );
	ri.FS_FreeFile( (void *) vertSrc );

	return true;

err_cleanup:

	if (shaderInfo->shaderProgramPipeline != 0) glDeleteProgramPipelines (1, &shaderInfo->shaderProgramPipeline);
	if(shaders2D[0] != 0)  glDeleteShader(shaders2D[0]);
	if(shaders2D[1] != 0)  glDeleteShader(shaders2D[1]);

	if(prog != 0)  glDeleteProgram(prog);

	R_Printf (PRINT_ALL, "WARNING: Failed to create shader program for %s!\n", shaderDesc);

	return false;
}

// geometry shader is optional
static qboolean
initShader3D(gl3ShaderInfo_t* shaderInfo, const char* vertFilename, const char* fragFilename, const char* geomFilename, const char* shaderDesc)
{
	GLuint shaders3D[5] = {0};
	GLuint prog = 0;
	int i=0;

	char*	vertSrc;
	char*	fragSrc;
	char*	geomSrc;
	char*	tescSrc;
	char*	teseSrc;
	char*	vertCommon, *fragCommon, *geomCommon;
	char*	glslCommon;		// for global glsl functions
	int		fileSize = 0;

	// load shader files

	if (!(fileSize = ri.FS_LoadFile ("shaders/Common.glsl", (void **) &glslCommon))) {
		R_Printf (PRINT_ALL, __FUNCTION__": Failed to load common shader include file!\n");
		return false;
	}

	if ( !( fileSize = ri.FS_LoadFile( "shaders/Common3D.frag", (void **) &fragCommon ) ) ) {
		R_Printf( PRINT_ALL, __FUNCTION__": Failed to load 3D common fragment shader!\n" );
		return false;
	}
	if ( !( fileSize = ri.FS_LoadFile( "shaders/Common3D.geom", (void **) &geomCommon ) ) ) {
		R_Printf( PRINT_ALL, __FUNCTION__": Failed to load 3D common geometry shader!\n" );
		ri.FS_FreeFile( fragCommon );
		return false;
	}
	if (!(fileSize = ri.FS_LoadFile ("shaders/Common3D.vert", (void **) &vertCommon))) {
		R_Printf (PRINT_ALL, __FUNCTION__": Failed to load 3D common vertex shader!\n");
		ri.FS_FreeFile (geomCommon);
		ri.FS_FreeFile (fragCommon);
		return false;
	}

	if ( !( fileSize = ri.FS_LoadFile( fragFilename, (void **) &fragSrc ) ) ) {
		R_Printf( PRINT_ALL, __FUNCTION__": Failed to load 3D fragment shader!\n" );
		ri.FS_FreeFile( fragCommon );
		ri.FS_FreeFile (geomCommon);
		ri.FS_FreeFile( vertCommon );
		return false;
	}
	if ( !( fileSize = ri.FS_LoadFile( vertFilename, (void **) &vertSrc ) ) ) {
		R_Printf( PRINT_ALL, __FUNCTION__": Failed to load 3D vertex shader!\n" );
		ri.FS_FreeFile( fragCommon );
		ri.FS_FreeFile (geomCommon);
		ri.FS_FreeFile( vertCommon );
		ri.FS_FreeFile( fragSrc );
		return false;
	}

	if ( shaderInfo->shaderProgram != 0 ) {
		R_Printf( PRINT_ALL, "WARNING: calling initShader3D for gl3ShaderInfo_t that already has a shaderProgram!\n" );
		glDeleteProgram( shaderInfo->shaderProgram );
	}

	shaderInfo->shaderProgram = 0;
	shaderInfo->uniLmScales = -1;

	shaders3D[0] = CompileShader(GL_VERTEX_SHADER, vertCommon, vertSrc);
	ri.FS_FreeFile( vertCommon );
	ri.FS_FreeFile( vertSrc );
	if ( shaders3D[0] == 0 ) {
		ri.FS_FreeFile( fragCommon );
		ri.FS_FreeFile( fragSrc );
		goto err_cleanup;
	}
	glObjectLabel (GL_SHADER, shaders3D[0], strlen (vertFilename), vertFilename);

	shaders3D[1] = CompileShader(GL_FRAGMENT_SHADER, fragCommon, fragSrc);
	ri.FS_FreeFile( fragCommon );
	ri.FS_FreeFile( fragSrc );

	if(shaders3D[1] == 0)
	{
		glDeleteShader(shaders3D[0]);
		goto err_cleanup;
	}
	glObjectLabel (GL_SHADER, shaders3D[1], strlen (fragFilename), fragFilename);

	GLuint numshaders = 2;

	// Geometry shader is optional
	if ( geomFilename != NULL ) {
		if ( strlen ( geomFilename ) > 0 ) {
			if ( !( fileSize = ri.FS_LoadFile ( geomFilename, (void **) &geomSrc ) ) ) {
				R_Printf ( PRINT_ALL, __FUNCTION__": Failed to load 3D geometry shader for %s!\n", shaderDesc );
				ri.FS_FreeFile ( geomSrc );
			} else {
				shaders3D[ 2 ] = shaders3D[ 1 ];
				shaders3D[ 1 ] = CompileShader ( GL_GEOMETRY_SHADER, geomCommon, geomSrc );
				numshaders++;
			} 
		}
	}

	if (shaders3D[1] == 0) {
		// Couldn't create geometry shader, so try without
		R_Printf (PRINT_ALL, __FUNCTION__": Failed to compile 3D geometry shader!\n");
		shaders3D[1] = shaders3D[2];
		shaders3D[2] = 0;
		numshaders = 2;
	}


	// try to locate tessellation shaders
	char tessFilename[64], baseName[64];
	size_t extoffset = strstr (vertFilename, ".") - vertFilename;
	strncpy_s (baseName, sizeof(baseName), vertFilename, extoffset);
	Com_sprintf (tessFilename, 64, "%s.tese", baseName);

	if ((fileSize = ri.FS_LoadFile (tessFilename, (void **) &teseSrc)) <= 0) {
		R_Printf (PRINT_DEVELOPER, __FUNCTION__": Failed to load 3D tessellation evaluation shader!\n");
	}

	GLuint tessshadernum[2];
	if (fileSize > 0) {
		tessshadernum[0] = CompileShader (GL_TESS_EVALUATION_SHADER, teseSrc, NULL);

		Com_sprintf (tessFilename, 64, "%s.tesc", baseName);

		if ((fileSize = ri.FS_LoadFile (tessFilename, (void **) &tescSrc)) <= 0) {
			R_Printf (PRINT_DEVELOPER, __FUNCTION__": Failed to load 3D tessellation control shader!\n");
			tessshadernum[1] = 0;
		} else {
			tessshadernum[1] = CompileShader (GL_TESS_CONTROL_SHADER, tescSrc, NULL);
		}
	} else {
		tessshadernum[0] = tessshadernum[1] = 0;
	}

	if (tessshadernum[0] > 0) {
		// insert tessellation evaluation shader
		shaders3D[3] = shaders3D[2];
		shaders3D[2] = shaders3D[1];
		shaders3D[1] = tessshadernum[0];
		numshaders++;
	}

	if (tessshadernum[1] > 0) {
		// insert tessellation control shader
		shaders3D[4] = shaders3D[3];
		shaders3D[3] = shaders3D[2];
		shaders3D[2] = shaders3D[1];
		shaders3D[1] = tessshadernum[1];
		numshaders++;
	}

	prog = CreateShaderProgram ( numshaders, shaders3D );
	if(prog == 0)
	{
		goto err_cleanup;
	}

	//BindAttribLocations (prog);

	byte *programBinary;
	GLsizei length;
	GLenum binFormat;
	FILE* f;

	glGetProgramiv (prog, GL_PROGRAM_BINARY_LENGTH, &length);
	programBinary = malloc (length);
	glGetProgramBinary (prog, length, &length, &binFormat, programBinary);
	char fname[96];
	Com_sprintf (fname, sizeof (fname), "%s/shaders/%s.o", ri.FS_Gamedir (), shaderDesc);
	if (!fopen_s (&f, fname, "wb")) {
		fwrite (programBinary, 1, length, f);
		fclose (f);
	}
	free (programBinary);

	glObjectLabel (GL_PROGRAM, prog, strlen (shaderDesc), shaderDesc);

	// Create program pipeline
	glGenProgramPipelines (1, &shaderInfo->shaderProgramPipeline);
	if (shaderInfo->shaderProgramPipeline == 0) {
		R_Printf (PRINT_ALL, "Failed to create program pipeline for %s\n", shaderDesc);
		goto err_cleanup;
	}
	glUseProgramStages (shaderInfo->shaderProgramPipeline,
		GL_VERTEX_SHADER_BIT |
		GL_TESS_CONTROL_SHADER_BIT |
		GL_TESS_EVALUATION_SHADER_BIT |
		GL_GEOMETRY_SHADER_BIT |
		GL_FRAGMENT_SHADER_BIT, prog);
	glObjectLabel (GL_PROGRAM_PIPELINE, shaderInfo->shaderProgramPipeline, strlen (shaderDesc), shaderDesc);

	GL3_UseProgram(prog);

	// Bind the buffer object to the uniform blocks
	GLuint blockIndex = glGetUniformBlockIndex(prog, "uniCommon");
	if(blockIndex != GL_INVALID_INDEX)
	{
		GLint blockSize;
		glGetActiveUniformBlockiv(prog, blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, &blockSize);
		if(blockSize != sizeof(gl3state.uniCommonData))
		{
			R_Printf(PRINT_ALL, "WARNING: OpenGL driver disagrees with us about UBO size of 'uniCommon'\n");

			goto err_cleanup;
		}

		glUniformBlockBinding(prog, blockIndex, GL3_BINDINGPOINT_UNICOMMON);
	}
	else
	{
		R_Printf(PRINT_ALL, "WARNING: Couldn't find uniform block index 'uniCommon'\n");

		goto err_cleanup;
	}
	blockIndex = glGetUniformBlockIndex(prog, "uni3D");
	if(blockIndex != GL_INVALID_INDEX)
	{
		GLint blockSize;
		glGetActiveUniformBlockiv(prog, blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, &blockSize);
		if(blockSize != sizeof(gl3state.uni3DData))
		{
			R_Printf(PRINT_ALL, "WARNING: OpenGL driver disagrees with us about UBO size of 'uni3D'\n");
			R_Printf(PRINT_ALL, "         driver says %d, we expect %d\n", blockSize, (int)sizeof(gl3state.uni3DData));

			goto err_cleanup;
		}

		glUniformBlockBinding(prog, blockIndex, GL3_BINDINGPOINT_UNI3D);
	}
	else
	{
		R_Printf(PRINT_ALL, "WARNING: Couldn't find uniform block index 'uni3D'\n");

		goto err_cleanup;
	}
	blockIndex = glGetUniformBlockIndex(prog, "uniLights");
	if(blockIndex != GL_INVALID_INDEX)
	{
		GLint blockSize;
		glGetActiveUniformBlockiv(prog, blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, &blockSize);
		if(blockSize != sizeof(gl3state.uniLightsData))
		{
			R_Printf(PRINT_ALL, "WARNING: OpenGL driver disagrees with us about UBO size of 'uniLights'\n");
			R_Printf(PRINT_ALL, "         OpenGL says %d, we say %d\n", blockSize, (int)sizeof(gl3state.uniLightsData));

			goto err_cleanup;
		}

		glUniformBlockBinding(prog, blockIndex, GL3_BINDINGPOINT_UNILIGHTS);
	}
	// else: as uniLights is only used in the LM shaders, it's ok if it's missing

	blockIndex = glGetUniformBlockIndex ( prog, "refDat" );
	//int blockIndex2 = glGetUniformBlockIndex ( prog, "refData" );
	if ( blockIndex != GL_INVALID_INDEX ) {
		GLint blockSize;
		glGetActiveUniformBlockiv ( prog, blockIndex, GL_UNIFORM_BLOCK_DATA_SIZE, &blockSize );
		if ( blockSize != sizeof ( gl3UniRefData_t ) ) {
			if (blockSize / sizeof (gl3UniRefData_t) != floor (blockSize / sizeof (gl3UniRefData_t))) {
				R_Printf (PRINT_ALL, "WARNING: OpenGL driver disagrees with us about UBO size of 'refDat'\n");
				R_Printf (PRINT_ALL, "         OpenGL says %d, we say %d\n", blockSize, (int)sizeof (gl3UniRefData_t));
				goto err_cleanup;
			}
		}

		if ( blockIndex != GL_INVALID_INDEX ) {
			glUniformBlockBinding ( prog, blockIndex, GL3_BINDINGPOINT_REFDATA );
		}
		else {
			R_Printf ( PRINT_ALL, "WARNING: Block index of 'refData' not found\n" );
		}
	}
	else {
		R_Printf ( PRINT_ALL, "WARNING: Couldn't find uniform block index 'refDat' at program %s\n", shaderDesc );
	}

	// make sure texture is GL_TEXTURE0
	GLint texLoc = glGetUniformLocation(prog, "tex");
	if(texLoc != -1)
	{
		glProgramUniform1i(prog, texLoc, 0);
	}

	// ..  and the lightmap texture uses GL_TEXTURE1
	char lmName[10] = "lightmap";
	GLint lmLoc = glGetUniformLocation(prog, lmName);
	if(lmLoc != -1)
	{
		glProgramUniform1i (prog, lmLoc, 1);
	}

	GLint bumpLoc = glGetUniformLocation (prog, "bump");
	if (bumpLoc != -1) {
		glProgramUniform1i (prog, bumpLoc, 2);
	}

	GLint reflLoc = glGetUniformLocation ( prog, "refl" );
	if ( reflLoc != -1 ) {
		glProgramUniform1i ( prog, reflLoc, 5 );
	}

	GLint reflDLoc = glGetUniformLocation (prog, "reflDepth");
	if (reflDLoc != -1) {
		glProgramUniform1i ( prog, reflDLoc, 6);
	}

	GLint lmScalesLoc = glGetUniformLocation(prog, "lmScales");
	shaderInfo->uniLmScales = lmScalesLoc;
	if(lmScalesLoc != -1)
	{
		shaderInfo->lmScales[0] = HMM_Vec4(1.0f, 1.0f, 1.0f, 1.0f);

		for(i=1; i<4; ++i)  shaderInfo->lmScales[i] = HMM_Vec4(0.0f, 0.0f, 0.0f, 0.0f);

		glProgramUniform4fv(prog, lmScalesLoc, 4, shaderInfo->lmScales[0].Elements);
	}

	shaderInfo->shaderProgram = prog;

	// I think the shaders aren't needed anymore once they're linked into the program
	for (i = 0; i < numshaders; i++) {
		glDeleteShader (shaders3D[i]);
	}

	char buf[8192];
	GLsizei infoLen;
	glGetProgramInfoLog (prog, 8192, &infoLen, buf);

	if (infoLen > 0) {
		R_Printf (PRINT_DEVELOPER, "%s: %s ", shaderDesc, buf);
	}
	return true;

err_cleanup:

	if ( shaders3D[ 0 ] != 0 )  glDeleteShader ( shaders3D[ 0 ] );
	if ( shaders3D[ 1 ] != 0 )  glDeleteShader ( shaders3D[ 1 ] );
	if ( shaders3D[ 2 ] != 0 )	glDeleteShader ( shaders3D[ 2 ] );

	if ( prog != 0 )  glDeleteProgram ( prog );

	R_Printf (PRINT_ALL, "WARNING: Failed to create shader program for %s!\n", shaderDesc);
	return false;
}

static qboolean
initShaderCompute (gl3ShaderInfo_t* shaderInfo, const char *compFilename, const char* shaderDesc) {
	GLuint	prog = 0;
	GLuint	shader = 0;
	int		fileSize;
	char*	compSrc;

	if (shaderInfo->shaderProgram != 0)
	{
		R_Printf (PRINT_ALL, "WARNING: calling initShaderCompute for gl3ShaderInfo_t that already has a shaderProgram!\n");
		glDeleteProgram (shaderInfo->shaderProgram);
		shaderInfo->shaderProgram = 0;
	}

	if (!(fileSize = ri.FS_LoadFile (compFilename, (void **)&compSrc))) {
		R_Printf (PRINT_ALL, __FUNCTION__": Failed to load compute shader %s!\n", compFilename);
		return false;
	}

	shader = CompileShader (GL_COMPUTE_SHADER, compSrc, NULL);
	if (!shader) {
		goto err_cleanup;
	}

	prog = CreateShaderProgram (1, &shader);
	if (!prog) {
		goto err_cleanup;
	}

	glDeleteShader (shader);
	shader = 0;

	// make sure texture is GL_TEXTURE0
	GLint texLoc = glGetUniformLocation (prog, "tex");
	if (texLoc != -1)
	{
		glProgramUniform1i (prog, texLoc, 0);
	}

	// ..  and the lightmap texture uses GL_TEXTURE1
	char lmName[10] = "lightmap";
	GLint lmLoc = glGetUniformLocation (prog, lmName);
	if (lmLoc != -1)
	{
		glProgramUniform1i (prog, lmLoc, 1);
	}

	GLint bumpLoc = glGetUniformLocation (prog, "bump");
	if (bumpLoc != -1) {
		glProgramUniform1i (prog, bumpLoc, 2);
	}

	GLint reflLoc = glGetUniformLocation (prog, "refl");
	if (reflLoc != -1) {
		glProgramUniform1i (prog, reflLoc, 5);
	}

	GLint reflDLoc = glGetUniformLocation (prog, "reflDepth");
	if (reflDLoc != -1) {
		glProgramUniform1i (prog, reflDLoc, 6);
	}

	shaderInfo->shaderProgram = prog;

	return true;

err_cleanup:
	if (prog != 0) {
		glDeleteProgram (prog);
	}
	if (shader != 0) {
		glDeleteShader (shader);
	}
	
	return false;
}

static void initUBOs(void)
{
	gl3state.uniCommonData.gamma = 1.0f/vid_gamma->value;
	gl3state.uniCommonData.intensity = gl3_intensity->value;
	gl3state.uniCommonData.intensity2D = gl3_intensity_2D->value;
	gl3state.uniCommonData.color = HMM_Vec4(1, 1, 1, 1);

	glGenBuffers(1, &gl3state.uniCommonUBO);
	glBindBuffer(GL_UNIFORM_BUFFER, gl3state.uniCommonUBO);
	glBindBufferBase(GL_UNIFORM_BUFFER, GL3_BINDINGPOINT_UNICOMMON, gl3state.uniCommonUBO);
	glBufferData(GL_UNIFORM_BUFFER, sizeof(gl3state.uniCommonData), &gl3state.uniCommonData, GL_DYNAMIC_DRAW);

	// the matrix will be set to something more useful later, before being used
	gl3state.uni2DData.transMat4 = HMM_Mat4();

	glGenBuffers(1, &gl3state.uni2DUBO);
	glBindBuffer(GL_UNIFORM_BUFFER, gl3state.uni2DUBO);
	glBindBufferBase(GL_UNIFORM_BUFFER, GL3_BINDINGPOINT_UNI2D, gl3state.uni2DUBO);
	glBufferData(GL_UNIFORM_BUFFER, sizeof(gl3state.uni2DData), &gl3state.uni2DData, GL_DYNAMIC_DRAW);

	// the matrices will be set to something more useful later, before being used
	gl3state.uni3DData.transProjMat4 = HMM_Mat4();
	gl3state.uni3DData.transViewMat4 = HMM_Mat4();
	gl3state.uni3DData.transModelMat4 = gl3_identityMat4;
	gl3state.uni3DData.lightmapindex = 0;
	gl3state.uni3DData.time = 0.0f;
	gl3state.uni3DData.alpha = 1.0f;
	// gl_overbrightbits 0 means "no scaling" which is equivalent to multiplying with 1
	gl3state.uni3DData.overbrightbits = (gl3_overbrightbits->value <= 0.0f) ? 1.0f : gl3_overbrightbits->value;
	gl3state.uni3DData.particleFadeFactor = gl3_particle_fade_factor->value;

	glGenBuffers(1, &gl3state.uni3DUBO);
	glBindBuffer(GL_UNIFORM_BUFFER, gl3state.uni3DUBO);
	glBindBufferBase(GL_UNIFORM_BUFFER, GL3_BINDINGPOINT_UNI3D, gl3state.uni3DUBO);
	glBufferData(GL_UNIFORM_BUFFER, sizeof(gl3state.uni3DData), &gl3state.uni3DData, GL_DYNAMIC_DRAW);

	glGenBuffers(1, &gl3state.uniLightsUBO);
	glBindBuffer(GL_UNIFORM_BUFFER, gl3state.uniLightsUBO);
	glBindBufferBase(GL_UNIFORM_BUFFER, GL3_BINDINGPOINT_UNILIGHTS, gl3state.uniLightsUBO);
	glBufferData(GL_UNIFORM_BUFFER, sizeof(gl3state.uniLightsData), &gl3state.uniLightsData, GL_DYNAMIC_DRAW);

	glGenBuffers ( 1, &gl3state.uniRefDataUBO );
	glBindBuffer ( GL_UNIFORM_BUFFER, gl3state.uniRefDataUBO );
	glBindBufferBase ( GL_UNIFORM_BUFFER, GL3_BINDINGPOINT_REFDATA, gl3state.uniRefDataUBO );
	glBufferData ( GL_UNIFORM_BUFFER, sizeof ( gl3state.uniRefData ), &gl3state.uniRefData, GL_DYNAMIC_DRAW );

	gl3state.currentUBO = gl3state.uniRefDataUBO;

}

static qboolean createShaders ( void ) {
	if ( !initShader2D ( &gl3state.si2D,			"shaders/2d.vert",		"shaders/2d.frag",										"textured 2D rendering" ) ) { return false; }
	if ( !initShader2D ( &gl3state.si2Darray,		"shaders/2d.vert",		"shaders/2darray.frag",									"array-textured 2D rendering" ) ) { return false; }
	if ( !initShader2D ( &gl3state.si2Dcolor,		"shaders/2Dcolor.vert", "shaders/2Dcolor.frag",									"color-only 2D rendering" ) ) { return false;	}
	if ( !initShader3D ( &gl3state.si3Dlm,			"shaders/3Dlm.vert",	"shaders/3Dlm.frag",			"shaders/3Dlm.geom",	"textured 3D rendering with lightmap" ) ) { return false; }
	if ( !initShader3D ( &gl3state.si3Dtrans,		"shaders/3Dcolor.vert",	"shaders/3D.frag",				"shaders/3D.geom",		"rendering translucent 3D things" ) ) { return false; }
	if ( !initShader3D ( &gl3state.si3DcolorOnly,	"shaders/3D.vert",		"shaders/3Dcolor.frag",			"shaders/3D.geom",		"flat-colored 3D rendering" ) ) { return false;	}
	if ( !initShader3D ( &gl3state.si3Dturb,		"shaders/3Dcolor.vert",	"shaders/3Dwater.frag",			"shaders/3D.geom",		"water rendering" ) ) { return false; }
	if ( !initShader3D ( &gl3state.si3Dsky,			"shaders/3D.vert",		"shaders/3Dsky.frag",			"shaders/3D.geom",		"sky rendering" ) ) { return false;	}
	if ( !initShader3D ( &gl3state.si3Dskycube,		"shaders/3D.vert",		"shaders/3Dskycube.frag",		"shaders/3D.geom",		"sky cubemap rendering" ) ) { return false;	}
	if ( !initShader3D ( &gl3state.si3Dsprite,		"shaders/3D.vert",		"shaders/3Dsprite.frag",		"shaders/3D.geom",		"sprite rendering" ) ) { return false; }
	if ( !initShader3D ( &gl3state.si3DspriteAlpha, "shaders/3D.vert",		"shaders/3DspriteAlpha.frag",	"shaders/3D.geom",		"alpha-tested sprite rendering" ) ) { return false;	}
	if ( !initShader3D ( &gl3state.si3Dalias,		"shaders/Alias.vert",	"shaders/Alias.frag",			"shaders/Alias.geom",	"rendering textured models" ) ) { return false;	}
	if ( !initShader3D ( &gl3state.si3DaliasColor,	"shaders/Alias.vert",	"shaders/AliasColor.frag",		"shaders/Alias.geom",	"flat-colored models" ) ) { return false;	}
	const char* particleFrag = "shaders/Particles.frag";
	if ( gl3_particle_square->value != 0.0f ) {
		particleFrag = "shaders/ParticlesSquare.frag";
	}
	if ( !initShader3D ( &gl3state.siParticle, "shaders/Particles.vert", particleFrag, "shaders/Particles.geom", "rendering particles" ) ) { return false; }

	if (!initShaderCompute (&gl3state.siBumpmap, "shaders/bumpmap.comp", "generating bumpmaps")) { return false; }

	gl3state.currentShaderProgram = 0;

	return true;
}

qboolean GL3_InitShaders(void)
{
	initUBOs();

	return createShaders();
}

static void deleteShaders(void)
{
	const gl3ShaderInfo_t siZero = {0};
	for(gl3ShaderInfo_t* si = &gl3state.si2D; si <= &gl3state.siParticle; ++si)
	{
		if (si->shaderProgramPipeline != 0) glDeleteProgramPipelines (1, &si->shaderProgramPipeline);
		if(si->shaderProgram != 0)  glDeleteProgram(si->shaderProgram);
		*si = siZero;
	}
}

void GL3_ShutdownShaders(void)
{
	deleteShaders();

	// let's (ab)use the fact that all UBO handles are consecutive fields
	// of the gl3state struct
	glDeleteBuffers(5, &gl3state.uniCommonUBO);
	gl3state.uniCommonUBO = gl3state.uni2DUBO = gl3state.uni3DUBO = gl3state.uniLightsUBO = gl3state.uniRefDataUBO = 0;
}

qboolean GL3_RecreateShaders(void)
{
	// delete and recreate the existing shaders (but not the UBOs)
	deleteShaders();
	return createShaders();
}

static inline void
updateUBO(GLuint ubo, GLsizeiptr size, void* data)
{
	if(gl3state.currentUBO != ubo)
	{
		gl3state.currentUBO = ubo;
		glBindBuffer(GL_UNIFORM_BUFFER, ubo);
	}

	// http://docs.gl/gl3/glBufferSubData says  "When replacing the entire data store,
	// consider using glBufferSubData rather than completely recreating the data store
	// with glBufferData. This avoids the cost of reallocating the data store."
	// no idea why glBufferData() doesn't just do that when size doesn't change, but whatever..
	// however, it also says glBufferSubData() might cause a stall so I DON'T KNOW!
	// on Linux/nvidia, by just looking at the fps, glBufferData() and glBufferSubData() make no difference
	// TODO: STREAM instead DYNAMIC?

#if 1
	// this seems to be reasonably fast everywhere.. glMapBuffer() seems to be a bit faster on OSX though..
	glBufferData(GL_UNIFORM_BUFFER, size, data, GL_DYNAMIC_DRAW);
#elif 0
	// on OSX this is super slow (200fps instead of 470-500), BUT it is as fast as glBufferData() when orphaning first
	// nvidia/linux-blob doesn't care about this vs glBufferData()
	// AMD open source linux (R3 370) is also slower here (not as bad as OSX though)
	// intel linux doesn't seem to care either (maybe 3% faster, but that might be imagination)
	// AMD Windows legacy driver (Radeon HD 6950) doesn't care, all 3 alternatives seem to be equally fast
	//glBufferData(GL_UNIFORM_BUFFER, size, NULL, GL_DYNAMIC_DRAW); // orphan
	glBufferSubData(GL_UNIFORM_BUFFER, 0, size, data);
#else
	// with my current nvidia-driver (GTX 770, 375.39), the following *really* makes it slower. (<140fps instead of ~850)
	// on OSX (Intel Haswell Iris Pro, OSX 10.11) this is fastest (~500fps instead of ~470)
	// on Linux/intel (Ivy Bridge HD-4000, Linux 4.4) this might be a tiny bit faster than the alternatives..
	glBufferData(GL_UNIFORM_BUFFER, size, NULL, GL_DYNAMIC_DRAW); // orphan
	GLvoid* ptr = glMapBuffer(GL_UNIFORM_BUFFER, GL_WRITE_ONLY);
	memcpy(ptr, data, size);
	glUnmapBuffer(GL_UNIFORM_BUFFER);
#endif

	// TODO: another alternative: glMapBufferRange() and each time update a different part
	//       of buffer asynchronously (GL_MAP_UNSYNCHRONIZED_BIT) => ringbuffer style
	//       when starting again from the beginning, synchronization must happen I guess..
	//       also, orphaning might be necessary
	//       and somehow make sure the new range is used by the UBO => glBindBufferRange()
	//  see http://git.quintin.ninja/mjones/Dolphin/blob/4a463f4588e2968c499236458c5712a489622633/Source/Plugins/Plugin_VideoOGL/Src/ProgramShaderCache.cpp#L207
	//   or https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/VideoBackends/OGL/ProgramShaderCache.cpp
}

void GL3_UpdateUBOCommon ( void ) {
	updateUBO ( gl3state.uniCommonUBO, sizeof ( gl3state.uniCommonData ), &gl3state.uniCommonData );
}

void GL3_UpdateUBO2D ( void ) {
	updateUBO ( gl3state.uni2DUBO, sizeof ( gl3state.uni2DData ), &gl3state.uni2DData );
}

void GL3_UpdateUBO3D ( void ) {
	updateUBO ( gl3state.uni3DUBO, sizeof ( gl3state.uni3DData ), &gl3state.uni3DData );
}

void GL3_UpdateUBOLights ( void ) {
	updateUBO ( gl3state.uniLightsUBO, sizeof ( gl3state.uniLightsData ), &gl3state.uniLightsData );
}

void GL3_UpdateUBORefData ( void ) {
	updateUBO ( gl3state.uniRefDataUBO, sizeof ( gl3state.uniRefData ), gl3state.uniRefData );
}