/* cache940tLib.c - Cache library for ARM940T CPU */

/* Copyright 1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,14jul98,cdp  written.
*/

#define ARMCACHE	ARMCACHE_940T
#define ARMMMU		ARMMMU_940T

#define FN(a,b)	a##Arm940t##b
#include "redef.c"

#include "cacheArchLib.c"
