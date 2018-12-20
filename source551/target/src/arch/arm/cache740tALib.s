/* cache740tALib.s - ARM740T cache management assembly-language routines */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01b,13nov01,to   remove prepending underscore
01a,05jan99,jpd  written.
*/

#define ARMCACHE	ARMCACHE_740T
#define ARMMMU		ARMMMU_740T

#define FN(a,b)	a##Arm740t##b
#include "redef.s"

#include "cacheALib.s"
