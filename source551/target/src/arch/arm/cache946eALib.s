/* cache946eALib.s - ARM946E cache management assembly-language routines */

/* Copyright 2000-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01b,13nov01,to   remove prepending underscore
01a,18jul00,jpd  written.
*/

#define ARMCACHE	ARMCACHE_946E
#define ARMMMU		ARMMMU_946E

#define FN(a,b)	a##Arm946e##b
#include "redef.s"

#include "cacheALib.s"
