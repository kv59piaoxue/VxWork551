/* cache810Lib.c - Cache library for ARM810 CPU */

/* Copyright 1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,14jul98,cdp  written.
*/

#define ARMCACHE	ARMCACHE_810
#define ARMMMU		ARMMMU_810

#define FN(a,b)	a##Arm810##b
#include "redef.c"

#include "cacheArchLib.c"
