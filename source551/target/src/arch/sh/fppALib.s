/* fppALib.s - floating-point unit support assembly language routines */

/* Copyright 1984-2001 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01p,11sep01,zl   replaced CPU conditionals with _WRS_HW_FP_SUPPORT.
01o,02oct00,zl   made fppSave safe of non-default FPSCR value.
01n,06sep00,zl   changed fppProbeSup to use fr12.
01m,13jul00,hk   made .global _fppRegGet/_fppRegSet for SH7750 only.
01l,12jul00,hk   added fppRegGet and fppRegSet. renamed fpulGet/fpulSet/fpscr-
		 Get/fpscrSet to fppFpulGet/fppFpulSet/fppFpscrGet/fppFpscrSet,
		 but also kept old names for backward compatibility.
01k,20apr00,zl   fixed fppSave and fppRestore.
01j,10apr00,hk   got rid of .ptext section for fppProbeTrap.
01i,29mar00,hk   added .type directive to function names.
01h,20mar00,zl   added extended floating point registers to the FP context
01g,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01f,08jun99,zl   added .ptext attribute "ax"
01e,08mar99,hk   added #if for FPU-less CPU types.
01d,11may98,hk   paid some efforts for faster operation.
01c,26nov97,hms  added fpp support logic. deleted stubs for fpcrGet/fpcrSet.
01b,27apr97,hk   added stubs for fpcrGet/fpcrSet.
01a,27sep96,hk   taken from mc68k/fppALib.s 01v. just stubs.
*/

/*
DESCRIPTION
This library contains routines to support the SH7718(SH3e) floating-point
unit.  The routines fppSave() and fppRestore() save and restore all the 
task floating-point context information.  Higher-level access mechanisms 
are found in fppLib.

SEE ALSO: fppLib, SH Floating-Point Unit User's Manual
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "fppLib.h"
#include "asm.h"


	.text

	.global	_fppSave
	.global	_fppRestore
#if (CPU==SH7750)
	.global	_fppRegGet		/* for fppExcHandle (SH7750 only) */
	.global	_fppRegSet		/* for fppExcHandle (SH7750 only) */
#endif
#ifdef	_WRS_HW_FP_SUPPORT
	.global	_fppFpulGet
	.global	_fppFpulSet
	.global	_fppFpscrGet
	.global	_fppFpscrSet
	.global	_fppProbeSup
	.global	_fppProbeTrap

	.global	_fpulGet		/* to be obsoleted */
	.global	_fpulSet		/* to be obsoleted */
	.global	_fpscrGet		/* to be obsoleted */
	.global	_fpscrSet		/* to be obsoleted */
#endif

/*******************************************************************************
*
* fppSave - save the floating-pointing context
*
* This routine saves the floating-point context.
* The context saved is:
*
*	- registers fpul, fpscr
*	- registers fr0 - fr15
*	- registers xf0 - xf15 (SH4 only)
*
*	---------
*	|  xf15 |    +132  <-- (r4 + 132)
*	|  ...  |
*	|  xf2  |    + 80
*	|  xf1  |    + 76
*	|  xf0  |    + 72
*	|  fr15 |    + 68  <-- (r4 + 68)
*	|  ...  |
*	|  fr2  |    + 16
*	|  fr1  |    + 12
*	|  fr0  |    + 8
*	| fpscr |    + 4
*	| fpul  | <-- pFpContext ( = r4 )
*	---------
*
* RETURNS: N/A
*
* SEE ALSO: fppRestore(), SH Programing Manual and SH Hardware Manual
*
* void fppSave
*    (
*    FP_CONTEXT * pFpContext	/@ where to save context @/
*    )
*/
	.align	_ALIGN_TEXT
	.type	_fppSave,@function

_fppSave:				/* r4 : *pFpContext    */
#ifdef	_WRS_HW_FP_SUPPORT
	add	#8,   r4		/* r4 : *pFpContext+8  */
	sts.l	fpscr,@-r4		/* save FPSCR register */
	mov.l	FpscrInit,r0		/* r0: FPSCR_INIT      */
	sts.l	fpul, @-r4		/* save FPUL register  */
	lds	r0,   fpscr		/* FPSCR: FPSCR_INIT   */
	add	#72,  r4		/* r4 : *pFpContext+72 */
#if (FP_NUM_DREGS == 32)
	add	#64,  r4		/* extended registers  */
	frchg
	fmov.s	fr15, @-r4		/* save XF15 register  */
	fmov.s	fr14, @-r4		/* save XF14 register  */
	fmov.s	fr13, @-r4		/* save XF13 register  */
	fmov.s	fr12, @-r4		/* save XF12 register  */
	fmov.s	fr11, @-r4		/* save XF11 register  */
	fmov.s	fr10, @-r4		/* save XF10 register  */
	fmov.s	fr9,  @-r4		/* save XF9 register   */
	fmov.s	fr8,  @-r4		/* save XF8 register   */
	fmov.s	fr7,  @-r4		/* save XF7 register   */
	fmov.s	fr6,  @-r4		/* save XF6 register   */
	fmov.s	fr5,  @-r4		/* save XF5 register   */
	fmov.s	fr4,  @-r4		/* save XF4 register   */
	fmov.s	fr3,  @-r4		/* save XF3 register   */
	fmov.s	fr2,  @-r4		/* save XF2 register   */
	fmov.s	fr1,  @-r4		/* save XF1 register   */
	fmov.s	fr0,  @-r4		/* save XF0 register   */
	frchg
#endif
	fmov.s	fr15, @-r4		/* save FR15 register  */
	fmov.s	fr14, @-r4		/* save FR14 register  */
	fmov.s	fr13, @-r4		/* save FR13 register  */
	fmov.s	fr12, @-r4		/* save FR12 register  */
	fmov.s	fr11, @-r4		/* save FR11 register  */
	fmov.s	fr10, @-r4		/* save FR10 register  */
	fmov.s	fr9,  @-r4		/* save FR9 register   */
	fmov.s	fr8,  @-r4		/* save FR8 register   */
	fmov.s	fr7,  @-r4		/* save FR7 register   */
	fmov.s	fr6,  @-r4		/* save FR6 register   */
	fmov.s	fr5,  @-r4		/* save FR5 register   */
	fmov.s	fr4,  @-r4		/* save FR4 register   */
	fmov.s	fr3,  @-r4		/* save FR3 register   */
	fmov.s	fr2,  @-r4		/* save FR2 register   */
	fmov.s	fr1,  @-r4		/* save FR1 register   */
	rts;
	fmov.s	fr0,  @-r4		/* save FR0 register   */
#else
	rts
	nop
#endif

/*******************************************************************************
*
* fppRestore - restore the floating-point coprocessor context
*
* This routine restores the floating-point coprocessor context.
* The context restored is:
*
*	- registers fpul, fpscr
*	- registers fr0 - fr15
*	- registers xf0 - xf15 (SH4 only)
*
* If the internal state frame is null, the other registers are not restored.
*
* RETURNS: N/A
*
* SEE ALSO: fppSave(), SH Programing Manual and SH Hardware Manual
*
* void fppRestore
*    (
*    FP_CONTEXT * pFpContext	/@ from where to restore context @/
*    )
*/
	.align	_ALIGN_TEXT
	.type	_fppRestore,@function

_fppRestore:				/* r4 : *pFpContext    */
#ifdef	_WRS_HW_FP_SUPPORT
	mov.l	FpscrInit,r0		/* r0: FPSCR_INIT      */
	lds.l	@r4+,fpul		/* restore FPUL reg    */
	lds	r0,  fpscr		/* FPSCR: FPSCR_INIT   */
	add	#4,  r4			/* skip FPSCR          */
	fmov.s	@r4+,fr0		/* restore FR0 reg     */
	fmov.s	@r4+,fr1		/* restore FP1 reg     */
	fmov.s	@r4+,fr2		/* restore FP2 reg     */
	fmov.s	@r4+,fr3		/* restore FP3 reg     */
	fmov.s	@r4+,fr4		/* restore FP4 reg     */
	fmov.s	@r4+,fr5		/* restore FP5 reg     */
	fmov.s	@r4+,fr6		/* restore FP6 reg     */
	fmov.s	@r4+,fr7		/* restore FP7 reg     */
	fmov.s	@r4+,fr8		/* restore FP8 reg     */
	fmov.s	@r4+,fr9		/* restore FP9 reg     */
	fmov.s	@r4+,fr10		/* restore FP10 reg    */
	fmov.s	@r4+,fr11		/* restore FP11 reg    */
	fmov.s	@r4+,fr12		/* restore FP12 reg    */
	fmov.s	@r4+,fr13		/* restore FP13 reg    */
	fmov.s	@r4+,fr14		/* restore FP14 reg    */
	fmov.s	@r4+,fr15		/* restore FP15 reg    */
#if (FP_NUM_DREGS == 32)
	frchg
	fmov.s	@r4+,fr0		/* restore XF0 reg     */
	fmov.s	@r4+,fr1		/* restore XF1 reg     */
	fmov.s	@r4+,fr2		/* restore XF2 reg     */
	fmov.s	@r4+,fr3		/* restore XF3 reg     */
	fmov.s	@r4+,fr4		/* restore XF4 reg     */
	fmov.s	@r4+,fr5		/* restore XF5 reg     */
	fmov.s	@r4+,fr6		/* restore XF6 reg     */
	fmov.s	@r4+,fr7		/* restore XF7 reg     */
	fmov.s	@r4+,fr8		/* restore XF8 reg     */
	fmov.s	@r4+,fr9		/* restore XF9 reg     */
	fmov.s	@r4+,fr10		/* restore XF10 reg    */
	fmov.s	@r4+,fr11		/* restore XF11 reg    */
	fmov.s	@r4+,fr12		/* restore XF12 reg    */
	fmov.s	@r4+,fr13		/* restore XF13 reg    */
	fmov.s	@r4+,fr14		/* restore XF14 reg    */
	fmov.s	@r4+,fr15		/* restore XF15 reg    */
	frchg
	add	#-64,r4
#endif  /* (CPU==SH7750) */
	add	#-68,r4			/* r4: pFpContext+4    */
	rts
	lds.l	@r4+,fpscr		/* restore FPSCR reg   */

		.align	2
FpscrInit:	.long	FPSCR_INIT
#else   /* !_WRS_HW_FP_SUPPORT */
	rts
	nop
#endif  /* _WRS_HW_FP_SUPPORT */


#if (CPU==SH7750)
/******************************************************************************
*
* fppRegGet - get the value of fpu register
*
* STATUS fppRegGet (int regnum, UINT32 *p, int sz)
*
* RETURNS: OK if successful, ERROR otherwise.
*
* NOMANUAL
*/ 
	.align	_ALIGN_TEXT
	.type	_fppRegGet,@function

_fppRegGet:
	sts	fpscr,r3	/* save original fpscr */

	tst	r6,r6
	movt	r6		/* 1: args.sz == 0,  0: args.sz == 1 */
	bt.s	fppRegGetChkAlign
	mov	#0x3,r0		/* fmov.s FRm,@r5 requires 4-bytes align */

	mov	#0x7,r0		/* fmov   DRm,@r5 requires 8-bytes align */
fppRegGetChkAlign:
	tst	r5,r0		/* check destination address alignment */
	bf.s	fppRegGetRtn;
	mov	#-1,r0		/* set return value to ERROR */

fppRegGetChkSz:
	mov.l	FPSCR_SZ,r2;	/* check current fpscr.sz */
	tst	r3,r2
	movt	r0		/* 1: fpscr.sz == 0,  0: fpscr.sz == 1 */

	cmp/eq	r0,r6
	bt	fppRegGetOp
	fschg			/* flip fpscr.sz if necessary */
fppRegGetOp:
	shll2	r4
	braf	r4;
	xor	r0,r0		/* set return value to OK */

	bra	fppRegGetRtn;	fmov	fr0,@r5
	bra	fppRegGetRtn;	fmov	fr1,@r5
	bra	fppRegGetRtn;	fmov	fr2,@r5
	bra	fppRegGetRtn;	fmov	fr3,@r5
	bra	fppRegGetRtn;	fmov	fr4,@r5
	bra	fppRegGetRtn;	fmov	fr5,@r5
	bra	fppRegGetRtn;	fmov	fr6,@r5
	bra	fppRegGetRtn;	fmov	fr7,@r5
	bra	fppRegGetRtn;	fmov	fr8,@r5
	bra	fppRegGetRtn;	fmov	fr9,@r5
	bra	fppRegGetRtn;	fmov	fr10,@r5
	bra	fppRegGetRtn;	fmov	fr11,@r5
	bra	fppRegGetRtn;	fmov	fr12,@r5
	bra	fppRegGetRtn;	fmov	fr13,@r5
	bra	fppRegGetRtn;	fmov	fr14,@r5
	bra	fppRegGetRtn;	fmov	fr15,@r5
fppRegGetRtn:
	rts;
	lds	r3,fpscr	/* restore fpscr */

/******************************************************************************
*
* fppRegSet - set the value of fpu register
*
* STATUS fppRegSet (int regnum, UINT32 *p, int sz)
*
* RETURNS: OK if successful, ERROR otherwise.
*
* NOMANUAL
*/ 
	.align	_ALIGN_TEXT
	.type	_fppRegSet,@function

_fppRegSet:
	sts	fpscr,r3	/* save original fpscr */

	tst	r6,r6
	movt	r6		/* 1: args.sz == 0,  0: args.sz == 1 */
	bt.s	fppRegSetChkAlign
	mov	#0x3,r0		/* fmov.s @r5,FRm requires 4-bytes align */

	mov	#0x7,r0		/* fmov   @r5,DRm requires 8-bytes align */
fppRegSetChkAlign:
	tst	r5,r0		/* check destination address alignment */
	bf.s	fppRegSetRtn;
	mov	#-1,r0		/* set return value to ERROR */

fppRegSetChkSz:
	mov.l	FPSCR_SZ,r2;	/* check current fpscr.sz */
	tst	r3,r2
	movt	r0		/* 1: fpscr.sz == 0,  0: fpscr.sz == 1 */

	cmp/eq	r0,r6
	bt	fppRegSetOp
	fschg			/* invert fpscr.sz */
fppRegSetOp:
	shll2	r4
	braf	r4;
	xor	r0,r0		/* set return value to OK */

	bra	fppRegSetRtn;	fmov	@r5,fr0
	bra	fppRegSetRtn;	fmov	@r5,fr1
	bra	fppRegSetRtn;	fmov	@r5,fr2
	bra	fppRegSetRtn;	fmov	@r5,fr3
	bra	fppRegSetRtn;	fmov	@r5,fr4
	bra	fppRegSetRtn;	fmov	@r5,fr5
	bra	fppRegSetRtn;	fmov	@r5,fr6
	bra	fppRegSetRtn;	fmov	@r5,fr7
	bra	fppRegSetRtn;	fmov	@r5,fr8
	bra	fppRegSetRtn;	fmov	@r5,fr9
	bra	fppRegSetRtn;	fmov	@r5,fr10
	bra	fppRegSetRtn;	fmov	@r5,fr11
	bra	fppRegSetRtn;	fmov	@r5,fr12
	bra	fppRegSetRtn;	fmov	@r5,fr13
	bra	fppRegSetRtn;	fmov	@r5,fr14
	bra	fppRegSetRtn;	fmov	@r5,fr15
fppRegSetRtn:
	rts;
	lds	r3,fpscr	/* restore fpscr */

		.align	2
FPSCR_SZ:	.long	FPSCR_FMOV_32BIT_PAIR
#endif /* CPU==SH7750 */

#ifdef	_WRS_HW_FP_SUPPORT
/******************************************************************************
*
* fppFpulGet - get the value of the fpul register
*
* RETURNS: the value of the fpul register
*
* SEE ALSO: fppFpulSet(), SH Programing Manual and SH Hardware Manual
*
* int fppFpulGet (void)
*/ 
	.align	_ALIGN_TEXT
	.type	_fppFpulGet,@function
	.type	_fpulGet,@function

_fppFpulGet:
_fpulGet:
	rts;
	sts	fpul,r0

/******************************************************************************
*
* fppFpulSet - set the value of the fpul register
*
* RETURNS: N/A
*
* SEE ALSO: fppFpulGet(), SH Programing Manual and SH Hardware Manual
*
* void fppFpulSet
*    (
*    int	value
*    )
*
*/ 
	.align	2
	.type	_fppFpulSet,@function
	.type	_fpulSet,@function

_fppFpulSet:
_fpulSet:
	rts;
	lds	r4,fpul

/******************************************************************************
*
* fppFpscrGet - get the value of the fpscr register
*
* The fpscr register controls which exceptions can be generated
* by the coprocessor. By default no exceptions can be generated.
* This routine can be used to check value of fpscr register.
*
* RETURNS: the value of the fpscr register
*
* SEE ALSO: fppFpscrSet(), SH Programing Manual and SH Hardware Manual
*
* int fppFpscrGet (void)
*
*/ 
	.align	2
	.type	_fppFpscrGet,@function
	.type	_fpscrGet,@function

_fppFpscrGet:
_fpscrGet:
	rts;
	sts	fpscr,r0

/******************************************************************************
*
* fppFpscrSet - set the value of the fpscr register
*
* The fpscr register controls which exceptions can be generated
* by the coprocessor. By default no exceptions can be generated.
* This routine can be used to enable some or all floating point
* excpetions.
*
* RETURNS: N/A
*
* SEE ALSO: fppFpulGet(), SH Programing Manual and SH Hardware Manual
*
* void fppFpscrSet
*    (
*    int	value
*    )
*/ 
	.align	2
	.type	_fppFpscrSet,@function
	.type	_fpscrSet,@function

_fppFpscrSet:
_fpscrSet:
	rts;
	lds	r4,fpscr

/*******************************************************************************
*
* fppProbeSup - fppProbe support routine
*
* This routine executes some coprocessor instruction which will cause a
* bus error if a coprocessor is not present.  A handler, viz. fppProbeTrap,
* should be installed at that vector.  If the coprocessor is present this
* routine returns OK.
*
* SEE ALSO: SH User's Manual
*
* NOMANUAL

* STATUS fppProbeSup ()
*/
	.align	2
	.type	_fppProbeSup,@function

_fppProbeSup:
	mov	#0,r0			/* set return value as OK */
	fabs	fr12			/* exception or nothing */
					/* 0xfc5d is illegal for DSP */
	rts;
	nop

/****************************************************************************
*
* fppProbeTrap - fppProbe support routine
*
* This entry point is momentarily attached to the coprocessor illegal opcode
* error exception vector.  Usually it simply sets r0 to ERROR to indicate that
* the illegal opcode error did occur, and returns from the interrupt.
*
* NOTE: The illegal opcode exception will be handled with 0x400000f0 in SR,
*       hence this routine does not have to be in P1/P2.
*
* NOMANUAL
*
*               |_____________|     +60       __________
*               |TRA/TEA/FPSCR| 96  +56  +12         ^
*               |   EXPEVT    | 92  +52  +8   _____  | ESFSH
*               |     ssr     | 88  +48  +4     ^    |
*       r5 ---> |     spc     | 84  +44  +0     | ___v__
*               |     r15     | 80  +40         |
*               |     r14     | 76  +36         |
*               |     r13     | 72  +32         |
*               |     r12     | 68  +28         |
*               |     r11     | 64  +24         |
*               |     r10     | 60  +20         |
*               |     r9      | 56  +16         |
*               |     r8      | 52  +12         |
*               |    macl     | 48  +8          |
*               |    mach     | 44  +4     REG_SET
*               |     r7      | 40  +0          |
*               |     r6      | 36              |
*               |     r5      | 32              |
*               |     r4      | 28              |
*               |     r3      | 24              |               +--------+
*               |     r2      | 20              |            r6 |REG_SET*|
*               |     r1      | 16              |               +--------+
*               |     r0      | 12              |            r5 | ESFSH *|
*               |     pr      |  8              |               +--------+
*               |     gbr     |  4              |            r4 |  INUM  |
*       r6 ---> |____ vbr ____|  0    __________v__             +--------+
*               |             |
*/
	.align	_ALIGN_TEXT
	.type	_fppProbeTrap,@function

_fppProbeTrap:
	mov	#-1,r0
	mov.l	r0,@(12,r6)	/* modify fppProbeSup() return value to ERROR */

	mov.l	@r5,r0		/* exception address in _fppProbeSup */
	add	#2,r0		/* skip 'fabs' */
	rts;			/* return to excStub */
	mov.l	r0,@r5		/* modify spc on stack */

#endif /* _WRS_HW_FP_SUPPORT */
