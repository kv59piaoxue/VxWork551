/* mmuSA1100ALib.s - SA-1100 MMU management assembly-language routines */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01b,13nov01,to  remove prepending underscore
01a,24aug98,jpd  written.
*/

#define ARMCACHE	ARMCACHE_SA1100
#define ARMMMU		ARMMMU_SA1100

#define FN(a,b)	a##ArmSA1100##b
#include "redef.s"

#include "mmuALib.s"
