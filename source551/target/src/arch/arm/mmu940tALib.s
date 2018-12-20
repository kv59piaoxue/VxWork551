/* mmu940tALib.s - ARM940T MMU management assembly-language routines */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01b,13nov01,to   remove prepending underscore
01a,14jul98,cdp  written.
*/

#define ARMCACHE	ARMCACHE_940T
#define ARMMMU		ARMMMU_940T

#define FN(a,b)	a##Arm940t##b
#include "redef.s"

#include "mmuALib.s"
