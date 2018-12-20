/* mmu946eLib.c - MMU library for ARM946E CPU */

/* Copyright 2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,19jul00,jpd  written.
*/

#define ARMCACHE	ARMCACHE_946E
#define ARMMMU		ARMMMU_946E

#define FN(a,b)	a##Arm946e##b
#include "redef.c"

#include "mmuLib.c"
