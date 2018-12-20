/* mmu926eALib.s - ARM926E MMU management assembly-language routines */

/* Copyright 2002 Wind River Systems, Inc. */

/*
modification history
--------------------
01a,10jul02,jpd  written.
*/

#define ARMCACHE	ARMCACHE_926E
#define ARMMMU		ARMMMU_926E

#define FN(a,b)	a##Arm926e##b
#include "redef.s"

#include "mmuALib.s"
