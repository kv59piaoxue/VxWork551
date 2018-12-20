/* cache1022eLib.c - Cache library for ARM1022E CPU */

/* Copyright 1998-2002 Wind River Systems, Inc. */
/* Copyright 2002 ARM Limited */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,09dec02,jpd  written.
*/

#define ARMCACHE	ARMCACHE_1022E
#define ARMMMU		ARMMMU_1022E

#define FN(a,b)	a##Arm1022e##b
#include "redef.c"

#include "cacheArchLib.c"
