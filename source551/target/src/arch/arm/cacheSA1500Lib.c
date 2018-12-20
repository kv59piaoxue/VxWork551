/* cacheSA1500Lib.c - Cache library for SA-1500 CPU */

/* Copyright 1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,24aug98,jpd  written.
*/

#define ARMCACHE	ARMCACHE_SA1500
#define ARMMMU		ARMMMU_SA1500

#define FN(a,b)	a##ArmSA1500##b
#include "redef.c"

#include "cacheArchLib.c"
