/* cache920tLib.c - Cache library for ARM920T CPU */

/* Copyright 1998-1999 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,04feb99,jpd  written.
*/

#define ARMCACHE	ARMCACHE_920T
#define ARMMMU		ARMMMU_920T

#define FN(a,b)	a##Arm920t##b
#include "redef.c"

#include "cacheArchLib.c"
