/* cache810ALib.s - ARM810 cache management assembly-language routines */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01b,13nov01,to   remove prepending underscore
01a,14jul98,cdp  written.
*/

#define ARMCACHE	ARMCACHE_810
#define ARMMMU		ARMMMU_810

#define FN(a,b)	a##Arm810##b
#include "redef.s"

#include "cacheALib.s"
