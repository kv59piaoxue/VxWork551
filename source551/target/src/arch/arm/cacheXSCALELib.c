/* cacheXSCALELib.c - Cache library for XScale CPU */

/* Copyright 1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,23jul01,scm  change XScale name to conform to coding standards...
01b,11dec00,scm  replaces references to ARMSA2 with XScale
01a,01sep00,scm  written.
*/

#define ARMCACHE	ARMCACHE_XSCALE
#define ARMMMU		ARMMMU_XSCALE

#define FN(a,b)	a##ArmXSCALE##b
#include "redef.c"

#include "cacheArchLib.c"
