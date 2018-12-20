/* cache920tALib.s - ARM920T cache management assembly-language routines */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01b,13nov01,to   remove prepending underscore
01a,04feb99,jpd  written.
*/

#define ARMCACHE	ARMCACHE_920T
#define ARMMMU		ARMMMU_920T

#define FN(a,b)	a##Arm920t##b
#include "redef.s"

#include "cacheALib.s"
