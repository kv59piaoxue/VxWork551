/* sigCtxALib.s - software signal architecture support library */

/* Copyright 1984-1998 Wind River Systems, Inc. */

/*
modification history
--------------------
01m,03oct02,dtr  Adding save/restore of spefscr for 85XX.
01l,13jun02,jtp  disable MMU during context restore for 4XX (SPR #78396)
01k,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01j,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01i,17apr01,dtr  Making setjmp/longjmp a function.
01h,07aug99,cno  ba _sigCtxSave instruction causes a link error (SPR 7153)
01g,18aug98,tpr  added PowerPC EC 603 support.
01f,24jun96,tpr  added PowerPC 860 support.
01e,31may96,tpr  Added second argument of _setjmpSetup() call (SPR #6650).
01d,30jan96,tpr  replaced %hiadj and %lo by HIADJ and LO.
01c,16jun95,tpr	 reworked _sigCtxLoad() to remove the bug with register reload.
01b,12jun95,caf  removed redundant labels.
01a,30may95,bdl  written.
*/

/*
This library provides the architecture specific support needed by
software signals.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "regs.h"

	
	/* internals */

	FUNC_EXPORT(_sigCtxLoad)
	FUNC_EXPORT(_sigCtxSave)
	FUNC_EXPORT(setjmp)
	FUNC_EXPORT(sigsetjmp)

	/* externals */

	.extern	_setjmpSetup

	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* sigsetjmp - set non-local goto with option to save signal mask
*
* This routine saves the current task context and program counter in <env>
* for later use by siglongjmp().   It returns 0 when called.  However, when
* program execution returns to the point at which sigsetjmp() was called and the
* task context is restored by siglongjmp(), sigsetjmp() will then return the
* value <val>, as specified in siglongjmp().
*
* If the value of <savemask> argument is not zero, the sigsetjmp() function
* shall save the current signal mask of the task as part of the calling
* environment.
*
* RETURNS: 0 or <val> if return is via siglongjmp().
*
* SEE ALSO: longjmp()

* int setjmp
*    (
*    jmp_buf env,       /@ where to save stack environment @/
*    int     savemask	/@ whether or not to save the current signal mask @/
*    )

*/

FUNC_BEGIN(sigsetjmp)
	stwu	sp, -80(sp)
	mfspr	r5, LR
	stw	r5, 4(sp)
	stw	r3, 8(sp)
	stwu	sp, -FRAMEBASESZ(sp)
	bl	_setjmpSetup
        addi	sp, sp, FRAMEBASESZ
	lwz	r3, 8(sp)
	lwz	r5, 4(sp)
	addi	sp, sp, 80
	mtspr	LR, r5
	b	_sigCtxSave
FUNC_END(sigsetjmp)


/*******************************************************************************
*
* setjmp - set non-local goto
*
* This routine saves the current task context and program counter in <env>
* for later use by longjmp().   It returns 0 when called.  However, when
* program execution returns to the point at which setjmp() was called and the
* task context is restored by longjmp(), setjmp() will then return the value
* <val>, as specified in longjmp().
*
* RETURNS: 0 or <val> if return is via longjmp().
*
* SEE ALSO: longjmp()

* int setjmp
*    (
*    jmp_buf env        /@ where to save stack environment @/
*    )

*/


FUNC_BEGIN(setjmp)
	stwu	sp, -80(sp)
	mfspr	r5, LR
	stw	r5, 4(sp)
	stw	r3, 8(sp)
	li	r4, 0x0001
	stwu	sp, -FRAMEBASESZ(sp)
	bl	_setjmpSetup
        addi	sp, sp, FRAMEBASESZ
	lwz	r3, 8(sp)
	lwz	r5, 4(sp)
	addi	sp, sp, 80
	mtspr	LR, r5

	/* FALL THROUGH */

/*******************************************************************************
*
* _sigCtxSave - Save the current context of the current task
*
* This is just like setjmp except it doesn't worry about saving any sigmask.
* It must also always return 0.
*
* RETURNS: 0

* int _sigCtxSave
*     (
*     REG_SET *pRegs		/@ Location to save current context @/
*     )

*/

FUNC_LABEL(_sigCtxSave)
	stmw	r0, REG_SET_GR(0)(r3)

	mfmsr	r4
	stw	r4, REG_SET_MSR(r3)

	mfspr	r5, LR
	stw	r5, REG_SET_LR(r3)
	stw	r5, REG_SET_PC(r3)

	mfspr	r4, CTR
	stw	r4, REG_SET_CTR(r3)

	mfcr	r4
	stw	r4, REG_SET_CR(r3)

	mfspr	r5, XER
	stw	r5, REG_SET_XER(r3)

#if	(CPU==PPC601)
	mfspr	r4, MQ
	stw	r4, REG_SET_MQ(r3)
#endif
#if	(CPU==PPC85XX)
	mfspr	r4, SPEFSCR
	stw	r4, REG_SET_SPEFSCR(r3)
#endif  /* CPU==PPC85XX */

	xor	r3, r3, r3
	blr
FUNC_END(setjmp)

/*******************************************************************************
*
* _sigCtxLoad - Load a new context in the current task
*
* This is just like longjmp, but every register must be loaded.
* You could also look at this as half a context switch.
*
* Be careful not to reset the stack pointer until you have read
* all the data. Destroying stuff at the end of the stack seems to
* be far game, this is very true of the debugger.
*
* RETURNS: Never returns

* void _sigCtxLoad
*     (
*     REG_SET *pRegs		/@ Context to load @/
*     )

*/

FUNC_BEGIN(_sigCtxLoad)
	/*
	 * XXX - code is just like excExit. Perhaps this should
	 * be built on top of excExit in a future release.
	 */

	mfmsr	r4
	INT_MASK(r4, r4)
	mtmsr	r4
	isync

	lwz	r0, REG_SET_GR(0)(r3)

	lwz	r1, REG_SET_GR(1)(r3)
	
	lwz	r2, REG_SET_GR(2)(r3)

	lmw	r5, REG_SET_GR(5)(r3)

	lwz	r4, REG_SET_LR(r3)
	mtspr	LR, r4

	lwz	r4, REG_SET_CTR(r3)
	mtspr	CTR, r4

	lwz	r4, REG_SET_XER(r3)
	mtspr	XER, r4

#if	(CPU==PPC601)
	lwz	r4, REG_SET_MQ(r3)
	mtspr	MQ, r4
#endif	/* CPU==PPC601 */
#if	(CPU==PPC85XX)
	lwz	r4, REG_SET_SPEFSCR(r3)
	mtspr	SPEFSCR, r4
#endif	/* CPU==PPC85XX */

#ifdef	_WRS_TLB_MISS_CLASS_SW
	/*
	 * Turn off MMU to keep SW TLB Miss handler from corrupting
	 * SRR0, SRR1.
	 */

        lwz     r4, REG_SET_CR(r3)             /* get cr */
        mtcrf   255, r4                         /* restore cr */

        lwz     r4, REG_SET_PC(r3)             /* restore pc */
        mtspr   SPRG0, r4                       /* restore pc */

        lwz     r4, REG_SET_MSR(r3)            /* restore msr */
        mtspr   SPRG3, r4                       /* restore msr */

        lwz     r4, REG_SET_GR(4)(r3)             /* restore r4 */

        lwz     r3, REG_SET_GR(3)(r3)             /* restore r3 */
        mtspr   SPRG2,r3

                                                /* turn off the MMU before */
                                                /* to restore the SRR0/SRR1 */
        mfmsr   r3                              /* read msr */
        rlwinm  r3,r3,0,28,25                   /* disable Instr/Data trans */
        mtmsr   r3                              /* set msr */
        isync                                   /* synchronization */

        mfspr   r3, SPRG0
        mtspr   SRR0, r3

        mfspr   r3, SPRG3
        mtspr   SRR1, r3

        lis     r3, HIADJ(vxIntStackBase)
        lwz     r3, LO(vxIntStackBase) (r3)
        mtspr   SPRG0, r3

        mfspr   r3, SPRG2
#else  /* !_WRS_TLB_MISS_CLASS_SW */
	/*
	 * both MMU-less and MMU with miss handler in HW use this code
	 */

        lwz     r4, REG_SET_CR(r3)             /* get cr */
        mtcrf   255, r4                         /* restore cr */

        lwz     r4, REG_SET_PC(r3)
        mtspr   SRR0, r4                        /* restore pc */

        lwz     r4, REG_SET_MSR(r3)
        mtspr   SRR1, r4                        /* restore msr */

        lwz     r4, REG_SET_GR(4)(r3)             /* restore r4 */

        lwz     r3, REG_SET_GR(3)(r3)             /* restore r3 */

#endif  /* _WRS_TLB_MISS_CLASS_SW */
	rfi
FUNC_END(_sigCtxLoad)
