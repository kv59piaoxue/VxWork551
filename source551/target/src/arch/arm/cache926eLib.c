/* cache926eLib.c - Cache library for ARM926E CPU */

/* Copyright 2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,10jul02,jpd  written.
*/

#define ARMCACHE	ARMCACHE_926E
#define ARMMMU		ARMMMU_926E

#define FN(a,b)	a##Arm926e##b
#include "redef.c"

#include "cacheArchLib.c"
