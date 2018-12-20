/* cacheArchVars.c - data for the cache-type-dependent files */

/* Copyright 1999-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,12nov01,to   copied from AE.
01a,06dec99,jpd  created.
*/

/*
This file declares the data used by the cache-type-dependent variants
of the cache support code (made from cacheArchLib.c and cacheALib.s).
This separate file is required so that the data is not declared in
those files, as that would lead to multiple instances of them in the
object file variants of those files, causing build problems.

SEE ALSO: cacheArchLib mmuLib
*/

#include "vxWorks.h"

/* globals */

/*
 * The way in which _CACHE_ALIGN_SIZE is defined has been changed
 * somewhat and is no longer strictly related to the CPU type defined,
 * but is instead related to the cache type selected.  Therefore, it would
 * be better if drivers that need to know the cache line size, use this
 * variable, rather than the constant.  The variable will be initialized
 * to the appropriate cache-type-dependent value by the variant of the
 * cache library initialization code.
 */

UINT32  cacheArchAlignSize = 0;


/*
 * Variable used to keep desired cache enable state: layout as MMUCR
 * (variously I, Z, W and C bits for different cache/MMUs).  This
 * variable is used to communicate from cacheArchLib to mmuLib, so that
 * when mmuLib enables the MMU, the appropriate cache features are
 * enabled that must not be enabled when the MMU is disabled.  See
 * cacheArchEnable().  For example, we must disable the D-cache,
 * write-buffer and branch-prediction when disabling the MMU on most
 * cache/MMUs and mmuLib will need to know what to turn back on when
 * the MMU is re-enabled.
 */

UINT32  cacheArchState = 0;     /* None of I, Z, W or C bit set */


/*
 * Variable used to hold the interrupt mask used when disabling
 * interrupts for lengthy cache operations such as cache flushing.  This
 * is preinitialized to a mask that disables IRQs and FIQs.  The BSP may
 * change this.  Do not do so unless you are sure that you understand the
 * consequences.  In particular, if interrupts are allowed to occur
 * during these operations, the state of the cache afterwards may be
 * indeterminate.
 */

UINT32  cacheArchIntMask = (F_BIT | I_BIT);


/*
 * Function pointer that is called by cacheLibInit() in the
 * architecture-independent code to initialize the correct architecture-
 * and cache-type-dependent cache support library.  This function pointer
 * is set to the appropriate variant of cacheArchLibInit() by the
 * appropriate cacheArchLibInstall() variant, which must itself be called
 * before cacheLibInit() is called.
 */

FUNCPTR sysCacheLibInit = 0;

