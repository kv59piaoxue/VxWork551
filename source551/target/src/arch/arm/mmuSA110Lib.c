/* mmuSA110Lib.c - MMU library for SA-110 CPU */

/* Copyright 1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,14jul98,cdp  written.
*/

#define ARMCACHE	ARMCACHE_SA110
#define ARMMMU		ARMMMU_SA110

#define FN(a,b)	a##ArmSA110##b
#include "redef.c"

#include "mmuLib.c"
