/* mmuArchVars.c - globals for PowerPC MMU */

/* Copyright 1998-2003 Wind River Systems, Inc. */

#include "copyright_wrs.h"

/*
modification history
--------------------
01b,02jan03,jtp  SPR 82770 add PPC440 arch/cache shared variables
01a,06nov98,rew  written
*/

/*
DESCRIPTION
This module contains MMU library global variables that can be used by
other libraries even when MMU is not selected in the BSP.  On CPUs that
do not support MMU or when MMU is not used, the following variables
assume that MMU is disabled.
*/

/* includes */

#include "vxWorks.h"

/* globals */

#ifdef _WRS_I_CACHE_TAG_VIRTUAL
UINT32	mmuPpcSelected = 0;		/* MMU config (MMU_INST|MMU_DATA) */
#else /* _WRS_I_CACHE_TAG_VIRTUAL */
BOOL	mmuPpcIEnabled = FALSE;		/* Instruction MMU State */
BOOL	mmuPpcDEnabled = FALSE;		/* Data MMU State */
#endif /* _WRS_I_CACHE_TAG_VIRTUAL */
