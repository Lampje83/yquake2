// bsp_main.c : Defines the exported functions for the DLL application.
//

#include "header\map.h"

mapimport_t	mi;
mapexport_t	me;

Q2_DLL_EXPORTED	mapexport_t
GetBspAPI (mapimport_t imp) {
	mapexport_t me = { 0 };

	mi = imp;

	me.apiversion = BSP_API_VERSION;
	me.bspversion = BSPVERSION;

	return me;
}

void Com_Printf (char *msg, ...)
{
	va_list argptr;
	va_start (argptr, msg);
	mi.Com_VPrintf (PRINT_ALL, msg, argptr);
	va_end (argptr);
}
