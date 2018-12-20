/* cache740tLib.c - Cache library for ARM740T CPU */

/* Copyright 1998-1999 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,05jan99,jpd  written.
*/

#define ARMCACHE	ARMCACHE_740T
#define ARMMMU		ARMMMU_740T

#define FN(a,b)	a##Arm740t##b
#include "redef.c"

#include "cacheArchLib.c"
