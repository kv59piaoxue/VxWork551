/* cache1020eALib.s - ARM1020E cache management assembly-language routines */

/* Copyright 1998-2002 Wind River Systems, Inc. */
/* Copyright 2002 ARM Limited */

/*
modification history
--------------------
01a,09dec02,jpd  written.
*/

#define ARMCACHE	ARMCACHE_1020E
#define ARMMMU		ARMMMU_1020E

#define FN(a,b)	a##Arm1020e##b
#include "redef.s"

#include "cacheALib.s"
