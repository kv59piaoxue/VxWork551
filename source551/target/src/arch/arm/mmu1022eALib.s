/* mmu1022eALib.s - ARM1022E MMU management assembly-language routines */

/* Copyright 1998-2002 Wind River Systems, Inc. */
/* Copyright 2002 ARM Limited */

/*
modification history
--------------------
01a,09dec02,jpd  written.
*/

#define ARMCACHE	ARMCACHE_1022E
#define ARMMMU		ARMMMU_1022E

#define FN(a,b)	a##Arm1022e##b
#include "redef.s"

#include "mmuALib.s"
