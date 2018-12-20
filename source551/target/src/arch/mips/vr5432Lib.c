/* vr5432Lib.c - NEC Vr5432 support library */

/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
 * This file has been developed or significantly modified by the
 * MIPS Center of Excellence Dedicated Engineering Staff.
 * This notice is as per the MIPS Center of Excellence Master Partner
 * Agreement, do not remove this notice without checking first with
 * WR/Platforms MIPS Center of Excellence engineering management.
 */

/*
modification history
--------------------
01b,16jul01,ros  add CofE comment
01a,04jun01,mem  written.
*/

/*
DESCRIPTION
This library provides a low-level support for the NEC Vr5432 processor.

INITIALIZATION

SEE ALSO:

*/

#include "vxWorks.h"
#include "objLib.h"
#include "private/windLibP.h"
#include "private/kernelLibP.h"
#include "private/taskLibP.h"
#include "taskArchLib.h"
#include "memLib.h"
#include "iv.h"
#include "esf.h"
#include "fppLib.h"

/* imports */

IMPORT FUNCPTR _func_fppSaveHook;
IMPORT FUNCPTR _func_fppRestoreHook;
IMPORT FUNCPTR _func_fppInitializeHook;

#if !defined(SOFT_FLOAT) && (_WRS_FP_REGISTER_SIZE == 8)

/* Vr5432 multi-media insns only work in 32-FP mode */

IMPORT void vr5432FppSave (FP_CONTEXT *pFpContext);
IMPORT void vr5432FppRestore (FP_CONTEXT *pFpContext);
IMPORT void vr5432FppInitialize (void);
#endif	/* !defined(SOFT_FLOAT) && (_WRS_FP_REGISTER_SIZE == 8) */

/* globals */

/* forward declarations */

/******************************************************************************
*
* vr5432ArchInit - initialize vr5432 support.
*
* This routine must be called before using the floating-point coprocessor.
*
* NOMANUAL
*/

void vr5432ArchInit (void)
    {
#if !defined(SOFT_FLOAT) && (_WRS_FP_REGISTER_SIZE == 8)
    _func_fppSaveHook = (FUNCPTR) vr5432FppSave;
    _func_fppRestoreHook = (FUNCPTR) vr5432FppRestore;
    _func_fppInitializeHook = (FUNCPTR) vr5432FppInitialize;
#endif	/* !defined(SOFT_FLOAT) && (_WRS_FP_REGISTER_SIZE == 8) */
    }
