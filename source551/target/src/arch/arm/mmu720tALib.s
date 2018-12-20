/* mmu720tALib.s - ARM720T MMU management assembly-language routines */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01b,13nov01,to   remove prepending underscore
01a,04feb99,jpd  written.
*/

#define ARMCACHE	ARMCACHE_720T
#define ARMMMU		ARMMMU_720T

#define FN(a,b)	a##Arm720t##b
#include "redef.s"

#include "mmuALib.s"
