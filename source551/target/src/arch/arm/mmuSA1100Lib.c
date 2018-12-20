/* mmuSA1100Lib.c - MMU library for SA-1100 CPU */

/* Copyright 1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,24aug98,jpd  written.
*/

#define ARMCACHE	ARMCACHE_SA1100
#define ARMMMU		ARMMMU_SA1100

#define FN(a,b)	a##ArmSA1100##b
#include "redef.c"

#include "mmuLib.c"
