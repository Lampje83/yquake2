#pragma once

#include "..\..\common\header\common.h"

#define	BSP_API_VERSION		1
#define EXPORT
#define IMPORT

/*
extern int qbsp3 (int argc, char **argv);
extern int qvis3 (int argc, char **argv);
extern int qrad3 (int argc, char **argv);
*/

typedef struct {
	int		apiversion;
	int		bspversion;

	int		(EXPORT *DoBSP) (int argc, char **argv);
	int		(EXPORT *DoVis) (int argc, char **argv);
	int		(EXPORT *DoRad) (int argc, char **argv);

	cmodel_t* (EXPORT* CM_LoadMap) (char* name, qboolean clientload, unsigned* checksum);
	cmodel_t* (EXPORT* CM_InlineModel) (char* name);

} mapexport_t;

typedef struct {
	void	(IMPORT *Sys_Error) (int err_level, char *str, ...) __attribute__ ((format (printf, 2, 3)));

	void	(IMPORT *Cmd_AddCommand) (char *name, void (*cmd)(void));
	void	(IMPORT *Cmd_RemoveCommand) (char *name);
	int		(IMPORT *Cmd_Argc) (void);
	char*	(IMPORT *Cmd_Argv) (int i);
	void	(IMPORT *Cmd_ExecuteText) (int exec_when, char *text);

	void	(IMPORT *Com_VPrintf) (int print_level, const char *fmt, va_list argptr);

	// files will be memory mapped read only
	// the returned buffer may be part of a larger pak file,
	// or a discrete file from anywhere in the quake search path
	// a -1 return means the file does not exist
	// NULL can be passed for buf to just determine existance
	int		(IMPORT *FS_LoadFile) (char *name, void **buf);
	void	(IMPORT *FS_FreeFile) (void *buf);

	// gamedir will be the current directory that generated
	// files should be stored to, ie: "f:\quake\id1"
	char*	(IMPORT *FS_Gamedir) (void);

	cvar_t*	(IMPORT *Cvar_Get) (char *name, char *value, int flags);
	cvar_t*	(IMPORT *Cvar_Set) (char *name, char *value);
	void	(IMPORT *Cvar_SetValue) (char *name, float value);

} mapimport_t;

extern mapimport_t	bi;
void Com_Printf (char *msg, ...);
