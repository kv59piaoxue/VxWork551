/* sigCtxALib.s - software signal architecture support library */

/* Copyright 1984-2001 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river

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
01u,08may02,pes  SPR #75020: fix stack corruption if interrupt received
                 while in sigCtxLoad.
01t,17jan02,agf  SPR 28519: use eret to start a task after context is loaded 
                 so ll/sc internal bit gets cleared
01s,02aug01,mem  Diab integration
01r,07aug01,ros  fix for TSR 251422
01q,16jul01,ros  add CofE comment
01p,13feb01,tlc  Perform HAZARD review.
01o,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01n,19jun00,dra  work around 5432 branch bug
01m,10sep99,myz  added CW4000_16 support.
01l,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01k,17mar99,md3  sigCtxSave - save t1, t2 before modifying (SPR# 25807).
01j,11jul97,kkk  save t8, t9 regs in sigCtxSave also.
01i,16jan97,kkk  sigCtxSave now saves all registers (spr# 5857)
01h,25nov96,kkk  added R4650 support, took out #error line (was causing
		 compilation to fail)
01g,11jul96,kkk  use lw instead of LW for loading of PC and SR regs.
01f,10jul96,ms   fixed sigCtxLoad to restore entire REG_SET (SPR 6787).
01e,31mar94,cd   made generic stack allocation for 32/64 bit processors.
01d,31aug92,rrr  added setjmp
01c,10jul92,ajm  fixed _sigCtxSave to return zero
01b,09jul92,ajm  created from old setjmp longjmp.
01a,08jul92,rrr  written.
*/

/*
This library provides the architecture specific support needed by
software signals.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "regs.h"

	.text
	.set	reorder

	/* internals */

	.globl	_sigCtxLoad
	.globl	_sigCtxSave
	.globl	setjmp
	.globl	sigsetjmp

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

	.ent	setjmp
setjmp:
	SETFRAME(setjmp,0)
	subu	sp, FRAMESZ(setjmp)	/* aquire some stack space */
	SW	ra, FRAMERA(setjmp)(sp)	/* save return address */
	sw	a0, FRAMEA0(setjmp)(sp)	/* save arg */
	li	a1, 1			/* param 2 is a 1 */
	jal	_setjmpSetup		/* make the call */
	lw	a0, FRAMEA0(setjmp)(sp)	/* restore arg */
	LW	ra, FRAMERA(setjmp)(sp)	/* restore return address */
	addu	sp, FRAMESZ(setjmp)	/* restore stack pointer */
	j	_sigCtxSave		/* jump to _sigCtxSave */
	.end	setjmp

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

	.ent	sigsetjmp
sigsetjmp:
	SETFRAME(sigsetjmp,0)
	subu	sp, FRAMESZ(sigsetjmp)	/* aquire some stack space */
	sw	a0, FRAMEA0(sigsetjmp)(sp) /* save arg */
	SW	ra, FRAMERA(sigsetjmp)(sp) /* save return address */
	jal	_setjmpSetup		/* make the call */
	lw	a0, FRAMEA0(sigsetjmp)(sp) /* restore arg */
	LW	ra, FRAMERA(sigsetjmp)(sp) /* restore return address */
	addu	sp, FRAMESZ(sigsetjmp)	/* restore stack pointer */
	j	_sigCtxSave		/* jump to _sigCtxSave */
	.end	sigsetjmp


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

	.ent	_sigCtxSave
_sigCtxSave:
        sw      ra, PCREG(a0)             	/* save ra to be new PC
                                                   after call to here */
        SW      t1, T1REG(a0)                   /* save t1, t2 before */
        SW      t2, T2REG(a0)                   /* modifying them. */
	HAZARD_VR5400
        mfc0    t1, C0_SR                       /* read SR */
	HAZARD_CP_READ
        SW      sp, SPREG(a0)             	/* save stack pointer */
        sw      t1, SRREG(a0)             	/* save SR in entirety */
        mflo    t2
        SW      t2, LOREG(a0)			/* save lo reg */
        mfhi    t2
        SW      t2, HIREG(a0)			/* save hi reg */
0:
        SW      zero, ZEROREG(a0)
        .set    noat
        SW      AT, ATREG(a0)			/* save at register */
        .set    at

	sw	ra, RAREG(a0)			/* save ra */

	/* save return and arg regs */

        SW      v0, V0REG(a0)	
        SW      v1, V1REG(a0)
        SW      a0, A0REG(a0)
        SW      a1, A1REG(a0)
        SW      a2, A2REG(a0)
        SW      a3, A3REG(a0)

	/* save temp registers */

        SW      t0, T0REG(a0)
        SW      t3, T3REG(a0)
        SW      t4, T4REG(a0)
        SW      t5, T5REG(a0)
        SW      t6, T6REG(a0)
        SW      t7, T7REG(a0)
	SW      t8, T8REG(a0)
	SW      t9, T9REG(a0)

	/* save callee-saved registers */

        SW      s0, S0REG(a0)
        SW      s1, S1REG(a0)
        SW      s2, S2REG(a0)
        SW      s3, S3REG(a0)
        SW      s4, S4REG(a0)
        SW      s5, S5REG(a0)
        SW      s6, S6REG(a0)
        SW      s7, S7REG(a0)
        SW      s8, S8REG(a0)
	move	v0, zero			/* return 0 always */
	j	ra
	.end	_sigCtxSave

/*******************************************************************************
*
* _sigCtxLoad - Load a new context in the current task
*
* This is just like longjmp, but every register must be loaded.
* You could also look at this as half a context switch.
*
* Be careful not to reset the stack pointer until you have read
* all the data. Destroying stuff at the end of the stack seems to
* be fair game, this is very true of the debugger.
*
* For non-R3k processors (MIPS 3 ISA & higher) the incoming context is 
* switched to using an 'eret' and the EPC. This is done to ensure the
* internal ll-sc bit is cleared.
*
* RETURNS: Never returns

* void _sigCtxLoad
*     (
*     REG_SET *pRegs		/@ Context to load @/
*     )

*/

	.ent	_sigCtxLoad
_sigCtxLoad:

	/* restore callee-save registers */

        LW      s0, S0REG(a0)
        LW      s1, S1REG(a0)
        LW      s2, S2REG(a0)
        LW      s3, S3REG(a0)
        LW      s4, S4REG(a0)
        LW      s5, S5REG(a0)
        LW      s6, S6REG(a0)
        LW      s7, S7REG(a0)
        LW      s8, S8REG(a0)

	/* restore most caller-save registers */
        LW      t2, LOREG(a0)			/* restore lo reg */
        mtlo    t2
        LW      t3, HIREG(a0)			/* restore hi reg */
        mthi    t3
0:
        LW      v0, V0REG(a0)			/* restore return register */
        LW      v1, V1REG(a0)			/* restore return register */
	LW	a1, A1REG(a0)
	LW	a2, A2REG(a0)
	LW	a3, A3REG(a0)
	LW	ra, RAREG(a0)
        LW      t2, T2REG(a0)
        LW      t3, T3REG(a0)
        LW      t4, T4REG(a0)
        LW      t5, T5REG(a0)
        LW      t6, T6REG(a0)
        LW      t7, T7REG(a0)
        LW      t8, T8REG(a0)
        LW      t9, T9REG(a0)

	/* lock interrupts */

	mfc0	t0, C0_SR
	HAZARD_CP_READ
#ifdef _WRS_R3K_EXC_SUPPORT
	li      t1, ~SR_IEC
#else
	li	t1, ~SR_IE
#endif
	and	t1, t1, t0
	mtc0	t1, C0_SR
	HAZARD_INTERRUPT

	/* restore the rest of the caller-save regs and context switch */

	.set	noat
        LW      t0, T0REG(a0)			/* restore t0 */
        LW      t1, T1REG(a0)			/* restore t1 */
	LW	AT, ATREG(a0)			/* restore at */
        lw      k0, PCREG(a0)             	/* read PC */
        lw      k1, SRREG(a0)             	/* read SR */
        LW      sp, SPREG(a0)             	/* restore stack pointer */
	LW	a0, A0REG(a0)			/* restore a0 */
        .set    noreorder
#ifdef _WRS_R3K_EXC_SUPPORT
        j       k0                              /* restore PC */
        mtc0    k1, C0_SR                       /* restore SR */
#else
        mtc0    k0, C0_EPC              /* set EPC with incoming task's PC */
        ori     k1, SR_EXL              /* set EXL to keep int's disabled */
        mtc0    k1, C0_SR               /* restore status register */
        HAZARD_CP_WRITE
        eret                            /* context switch */
#endif
        .set    reorder
	.set	at
	.end	_sigCtxLoad



