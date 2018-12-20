/* cacheSA110ALib.s - SA-110 cache management assembly-language routines */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01b,13nov01,to   remove prepending underscore
01a,14jul98,cdp  written.
*/

#define ARMCACHE	ARMCACHE_SA110
#define ARMMMU		ARMMMU_SA110

#define FN(a,b)	a##ArmSA110##b
#include "redef.s"

#include "cacheALib.s"
