// bsp_main.c : Defines the exported functions for the DLL application.
//

#include "header\bsp.h"

bspimport_t	bi;
bspexport_t	be;

Q2_DLL_EXPORTED	bspexport_t
GetBspAPI (bspimport_t imp) {
	bspexport_t be = { 0 };

	bi = imp;

	be.apiversion = BSP_API_VERSION;

	return be;
}