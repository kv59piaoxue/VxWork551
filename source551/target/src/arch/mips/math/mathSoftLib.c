/* mathSoftLib.c - high-level floating-point emulation library */

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
01g,16jul01,ros  add CofE comment
01f,03jan01,pes  Fix compiler warnings.
01e,20dec99,dra  added true soft-float protection.
01d,08apr97,kkk  fixed to correctly pull in sf objs modules for SW_FP.
01d,03aug96,kkk  added dummy routine to pull in sf object modules for SW_FP.
01c,25oct93,yao  changed to turn fpu off when task is created.
01b,07sep93,yao  changed to install support routines only once.
01a,25aug93,yao  written.
*/

/*
DESCRIPTION
This library provides support routines for software emulation of 
floating-point operations.

INCLUDE FILES: math.h

SEE ALSO: mathHardLib, mathSoftALib
*/

#include "vxWorks.h"
#include "math.h"
#include "intLib.h"
#include "taskLib.h"
#include "taskHookLib.h"
#include "excLib.h"
#include "sysLib.h"
#include "fppLib.h"
#include "private/funcBindP.h"
#include "excLib.h"
#include "esf.h"
#include "string.h"

IMPORT VOIDFUNCPTR excBsrTbl[];
IMPORT void fpIntr();
IMPORT void mathSoftAInit ();


/* dummy function pointers to pull in math object modules */

#ifndef SOFT_FLOAT
LOCAL DBLFUNCPTR       mathAcosFunc;   /* double-precision function ptrs */
LOCAL DBLFUNCPTR       mathAsinFunc;
LOCAL DBLFUNCPTR       mathAtanFunc;
LOCAL DBLFUNCPTR       mathAtan2Func;
LOCAL DBLFUNCPTR       mathCeilFunc;
LOCAL DBLFUNCPTR       mathCosFunc;
LOCAL DBLFUNCPTR       mathCoshFunc;
LOCAL DBLFUNCPTR       mathExpFunc;
LOCAL DBLFUNCPTR       mathFabsFunc;
LOCAL DBLFUNCPTR       mathFloorFunc;
LOCAL DBLFUNCPTR       mathFmodFunc;
LOCAL DBLFUNCPTR       mathRintFunc;
LOCAL DBLFUNCPTR       mathLogFunc;
LOCAL DBLFUNCPTR       mathLog10Func;
LOCAL DBLFUNCPTR       mathPowFunc;
LOCAL DBLFUNCPTR       mathSinFunc;
LOCAL DBLFUNCPTR       mathSinhFunc;
LOCAL DBLFUNCPTR       mathSqrtFunc;
LOCAL DBLFUNCPTR       mathTanFunc;
LOCAL DBLFUNCPTR       mathTanhFunc;

LOCAL FLTFUNCPTR       mathAcosfFunc;  /* single-precision function ptrs */
LOCAL FLTFUNCPTR       mathAsinfFunc;
LOCAL FLTFUNCPTR       mathAtanfFunc;
LOCAL FLTFUNCPTR       mathAtan2fFunc;
LOCAL FLTFUNCPTR       mathCeilfFunc;
LOCAL FLTFUNCPTR       mathCosfFunc;
LOCAL FLTFUNCPTR       mathCoshfFunc;
LOCAL FLTFUNCPTR       mathExpfFunc;
LOCAL FLTFUNCPTR       mathFabsfFunc;
LOCAL FLTFUNCPTR       mathFmodfFunc;
LOCAL FLTFUNCPTR       mathFloorfFunc;
LOCAL FLTFUNCPTR       mathLogfFunc;
LOCAL FLTFUNCPTR       mathLog10fFunc;
LOCAL FLTFUNCPTR       mathPowfFunc;
LOCAL FLTFUNCPTR       mathSinfFunc;
LOCAL FLTFUNCPTR       mathSinhfFunc;
LOCAL FLTFUNCPTR       mathSqrtfFunc;
LOCAL FLTFUNCPTR       mathTanfFunc;
LOCAL FLTFUNCPTR       mathTanhfFunc;
#endif	/* SOFT_FLOAT */

/* forward declaration */

LOCAL int mathSoftInstalled = FALSE;

LOCAL void fppSoftHook (WIND_TCB * pTcb);

/******************************************************************************
*
* mathSoftInit - initialize software floating-point math support
*
* This routine installs the exception handler for coprocessor unusable 
* exception for software emulation.  Disables the coprocessor and adds
* task create hook for software emulation.
*
* This routine is called from usrConfig.c if INCLUDE_FP_EMULATION is defined.
* This definition causes the linker to include the floating-point
* emulation library.
*
* RETURNS: N/A
*
* SEE ALSO: mathHardInit()
*
*/

void mathSoftInit ()
    {
    if (!mathSoftInstalled)
	{
#ifndef SOFT_FLOAT
	excBsrTbl [EXC_CODE_FPU] = (VOIDFUNCPTR) fpIntr;
	taskCreateHookAdd ((FUNCPTR)fppSoftHook);
	mathSoftAInit ();
#endif	/* SOFT_FLOAT */
	mathSoftInstalled = TRUE;
	}
#ifndef SOFT_FLOAT
    /* Double-precision routines */

    mathAcosFunc 	= (DBLFUNCPTR) acos;
    mathAsinFunc	= (DBLFUNCPTR) asin;
    mathAtanFunc	= (DBLFUNCPTR) atan;
    mathAtan2Func	= (DBLFUNCPTR) atan2;
    mathCeilFunc	= (DBLFUNCPTR) ceil;
    mathCosFunc		= (DBLFUNCPTR) cos;
    mathCoshFunc	= (DBLFUNCPTR) cosh;
    mathExpFunc		= (DBLFUNCPTR) exp;
    mathFabsFunc	= (DBLFUNCPTR) fabs;
    mathFmodFunc	= (DBLFUNCPTR) fmod;
    mathFloorFunc	= (DBLFUNCPTR) floor;
    mathRintFunc	= (DBLFUNCPTR) rint;
    mathLogFunc		= (DBLFUNCPTR) log;
    mathLog10Func	= (DBLFUNCPTR) log10;
    mathPowFunc		= (DBLFUNCPTR) pow;
    mathSqrtFunc	= (DBLFUNCPTR) sqrt;
    mathTanFunc		= (DBLFUNCPTR) tan;
    mathTanhFunc	= (DBLFUNCPTR) tanh;
    mathSinFunc		= (DBLFUNCPTR) sin;
    mathSinhFunc	= (DBLFUNCPTR) sinh;


    /* Single-precision routines */

    mathAcosfFunc	= (FLTFUNCPTR) acosf;
    mathAsinfFunc	= (FLTFUNCPTR) asinf;
    mathAtanfFunc	= (FLTFUNCPTR) atanf;
    mathAtan2fFunc	= (FLTFUNCPTR) atan2f;
    mathCeilfFunc	= (FLTFUNCPTR) ceilf;
    mathCosfFunc	= (FLTFUNCPTR) cosf;
    mathCoshfFunc	= (FLTFUNCPTR) coshf;
    mathExpfFunc	= (FLTFUNCPTR) expf;
    mathFabsfFunc	= (FLTFUNCPTR) fabsf;
    mathFmodfFunc	= (FLTFUNCPTR) fmodf;
    mathFloorfFunc	= (FLTFUNCPTR) floorf;
    mathLogfFunc	= (FLTFUNCPTR) logf;
    mathLog10fFunc	= (FLTFUNCPTR) log10f;
    mathPowfFunc	= (FLTFUNCPTR) powf;
    mathSinfFunc	= (FLTFUNCPTR) sinf;
    mathSinhfFunc	= (FLTFUNCPTR) sinhf;
    mathSqrtfFunc	= (FLTFUNCPTR) sqrtf;
    mathTanfFunc	= (FLTFUNCPTR) tanf;
    mathTanhfFunc	= (FLTFUNCPTR) tanhf;
#endif	/* SOFT_FLOAT */
    } 

/******************************************************************************
*
* fppSoftHook - task hook routine for software emulation
*
* NOMANUAL
*/

LOCAL void fppSoftHook 
    (
    WIND_TCB * pTcb
    )
    {

    if (pTcb->options & VX_FP_TASK)
	{
	/* allocate space for saving context and registers */

	pTcb->pFpContext = (FP_CONTEXT *)
			  taskStackAllot ((int) pTcb, sizeof (FP_CONTEXT));

	bzero ((char *)pTcb->pFpContext, sizeof(FP_CONTEXT));
	pTcb->pFpContext->fpcsr = FP_ENABLE;	/* enable fpu interrupt */
	pTcb->regs.sr &= ~SR_CU1;		/* turn off fpu */
	}
    }

/******************************************************************************
*
* mathFpInit - fpa interrupt handling installization
*
* NOMANUAL
*/

#define	EXC_FPU_UNIMP	38		/* unimplemented FPA operation */
#define	EXC_FPU_ILL	39		/* invalid FPA operation */
#define	EXC_FPU_DIV_0 	40		/* FPA dived by zero */
#define EXC_FPU_OVFL	41		/* FPA overflow */
#define EXC_FPU_UDFL	42		/* FPA underflow */
#define	EXC_FPU_INEXACT	43		/* FPA inexact operation */

void mathFpInit ()
    {
    excBsrTbl [EXC_FPU_UNIMP] 	= (VOIDFUNCPTR) fpIntr;
    excBsrTbl [EXC_FPU_ILL] 	= (VOIDFUNCPTR) fpIntr;
    excBsrTbl [EXC_FPU_DIV_0] 	= (VOIDFUNCPTR) fpIntr;
    excBsrTbl [EXC_FPU_OVFL] 	= (VOIDFUNCPTR) fpIntr;
    excBsrTbl [EXC_FPU_UDFL] 	= (VOIDFUNCPTR) fpIntr;
    excBsrTbl [EXC_FPU_INEXACT]	= (VOIDFUNCPTR) fpIntr;
    }
