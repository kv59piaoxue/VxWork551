/* cacheXSCALEALib.s - XScale cache management assembly-language routines */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01d,13nov01,to   remove prepending underscore
01c,23jul01,scm  change XScale name to conform to coding standards...
01b,11dec00,scm  replaces references to ARMSA2 with XScale
01a,01sep00,scm  written.
*/

#define ARMCACHE	ARMCACHE_XSCALE
#define ARMMMU		ARMMMU_XSCALE

#define FN(a,b)	a##ArmXSCALE##b
#include "redef.s"

#include "cacheALib.s"
