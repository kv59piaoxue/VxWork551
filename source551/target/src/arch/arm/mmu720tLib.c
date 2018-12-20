/* mmu720tLib.c - MMU library for ARM720T CPU */

/* Copyright 1998-1999 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,04feb99,jpd  written.
*/

#define ARMCACHE	ARMCACHE_720T
#define ARMMMU		ARMMMU_720T

#define FN(a,b)	a##Arm720t##b
#include "redef.c"

#include "mmuLib.c"
