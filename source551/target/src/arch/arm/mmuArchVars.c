/* mmuArchVars.c - data for the MMU-type-dependent files */

/* Copyright 1999-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,12nov01,to   copied from AE.
01a,06dec99,jpd  created.
*/

/*
This file declares the data used by the MMU-type-dependent variants of
the MMU-type-dependent support code (made from mmuLib.c and
mmuALib.s).  This separate file is required so that the data is not
declared in those files, as that would lead to multiple instances of
them in the object file variants of those files, causing build
problems.

SEE ALSO: cacheArchLib mmuLib
*/

#include "vxWorks.h"
#include "memLib.h"

/* globals */

/*
 * Function pointer that is called by usrMmuInit() in the
 * architecture-independent code to initialize the correct architecture-
 * and MMU-type-dependent cache support library.  This function pointer
 * is set to the appropriate variant of mmuLibInit() by the
 * appropriate mmuLibInstall() variant, which must itself be called
 * before usrMmuInit() is called.
 */

FUNCPTR sysMmuLibInit = NULL;

/*
 * Pointer to a function that can be filled in by the BSP to point to a
 * function that returns a memory partition id for an area of memory to store
 * the Level 1 and Level 2 page tables. This area must be big enough for all
 * use. No provision is made to use that memory and then continue using
 * system memory once that has been filled.
 * N.B. at the time of writing, this feature has NEVER been tested at all.
 */

PART_ID (* _func_armPageSource) (void) = NULL;

