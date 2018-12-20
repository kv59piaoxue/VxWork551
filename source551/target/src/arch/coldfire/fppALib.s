/* fppALib.s - floating-point coprocessor support assembly language routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01b,26nov01,dee  remove reference to _DIAB_TOOL
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This library contains routines to support the MC68881/MC68882 floating-point
coprocessor.  The routines fppSave() and fppRestore() save and restore all the
task floating-point context information, which consists of the eight extended
double precision registers and three control registers.  Higher-level access
mechanisms are found in fppLib.

SEE ALSO: fppLib, MC68881/MC68882 Floating-Point Coprocessor User's Manual
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "fppLib.h"
#include "asm.h"

/* The following flag controls the assembly of the fpp instructions.
 *   If TRUE, the fpp instructions are assembled (many assemblers can't handle).
 *   If FALSE, hand-coded machine code equivalents are assembled.
 */

#define FPP_ASSEM	FALSE


	.text
	.even

	/* internals */

	.globl _fppSave
	.globl _fppRestore
	.globl _fppProbeSup
	.globl _fppProbeTrap
	.globl _fppDtoDx
	.globl _fppDxtoD

	.data
fppNullStateFrame:
	.long  0x00000000
fppCPVersion:
	.byte  0xff


	.text
	.even

/*******************************************************************************
*
* fppSave - save the floating-pointing coprocessor context
*
* This routine saves the floating-point coprocessor context.
* The context saved is:
*
*	- registers fpcr, fpsr, and fpiar
*	- registers f0 - f7
*	- internal state frame
*
* If the internal state frame is null, the other registers are not saved.
*
* FIXME: Coldfire FP ???
*
* RETURNS: N/A
*
* SEE ALSO: fppRestore(), MC68881/MC68882 Floating-Point Coprocessor
* User's Manual

* void fppSave
*    (
*    FP_CONTEXT *  pFpContext  /* where to save context *
*    )

*/

_fppSave:
	link	a6,#0
	movel	a6@(ARG1),a0			/* where to save registers */

so_null:
	unlk	a6
	rts

/*******************************************************************************
*
* fppRestore - restore the floating-point coprocessor context
*
* This routine restores the floating-point coprocessor context.
* The context restored is:
*
*	- registers fpcr, fpsr, and fpiar
*	- registers f0 - f7
*	- internal state frame
*
* If the internal state frame is null, the other registers are not restored.
*
* FIXME: Coldfire FP ???
*
* RETURNS: N/A
*
* SEE ALSO: fppSave(), MC68881/MC68882 Floating-Point Coprocessor User's Manual

* void fppRestore
*    (
*    FP_CONTEXT *  pFpContext  /* from where to restore context *
*    )

*/

_fppRestore:
	link	a6,#0

	unlk	a6
	rts

/*******************************************************************************
*
* fppDtoDx - convert double to extended double precision
*
* The MC68881 uses a special extended double precision format
* (12 bytes as opposed to 8 bytes) for internal operations.
* The routines fppSave and fppRestore must preserve this precision.
*
* NOMANUAL

* void fppDtoDx (pDx, pDouble)
*     DOUBLEX *pDx;	 /* where to save result    *
*     double *pDouble;	 /* ptr to value to convert *

*/

_fppDtoDx:
	link	a6,#0

	unlk	a6
	rts
/*******************************************************************************
*
* fppDxtoD - convert extended double precisoion to double
*
* The MC68881 uses a special extended double precision format
* (12 bytes as opposed to 8 bytes) for internal operations.
* The routines fppSave and fppRestore must preserve this precision.
*
* NOMANUAL

* void fppDxtoD (pDouble, pDx)
*     double *pDouble;		/* where to save result    *
*     DOUBLEX *pDx;		/* ptr to value to convert *

*/

_fppDxtoD:
	link	a6,#0

	unlk	a6
	rts

/*******************************************************************************
*
* fppProbeSup - fppProbe support routine
*
* This routine executes some coprocessor instruction which will cause a
* bus error if a coprocessor is not present.  A handler, viz. fppProbeTrap,
* should be installed at that vector.  If the coprocessor is present this
* routine returns OK.
*
* SEE ALSO: MC68881/MC68882 User's Manual, page 5-15
*
* NOMANUAL

* STATUS fppProbeSup ()
*/

_fppProbeSup:
	link	a6,#0
	clrl	d0		/* set status to OK */
	nop
#if FPP_ASSEM
	fmovecr	#0,fp0		/* 040 unimplemented instruction */
#else
	.word	0xf200,0x5c00	/* fmovecr #0,fp0 */
#endif
	nop

fppProbeSupEnd:
	unlk    a6
	rts

/****************************************************************************
*
* fppProbeTrap - fppProbe support routine
*
* This entry point is momentarily attached to the coprocessor illegal opcode
* error exception vector.  Usually it simply sets d0 to ERROR to indicate that
* the illegal opcode error did occur, and returns from the interrupt.  The
* 68040/68060 version, however, stores the coprocessor version number for pseudo
* frame construction in fppSave, and leaves d0 with the value of OK.
*
* NOMANUAL
*/

_fppProbeTrap:			/* coprocessor illegal error trap */

	movel	#fppProbeSupEnd,d0	/* change PC to bail out */
	movel	d0,a7@(4)
	movel	#-1,d0			/* set status to ERROR */
	rte				/* return to fppProbeSupEnd */
