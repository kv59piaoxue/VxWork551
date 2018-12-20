/* fpIntr.s - floating point interrupt handler */

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
01r,17may02,pes  SPR #72943: Corrected Unimplemented Operation exception
                 behavior.
01q,01aug01,mem  Diab integration
01p,16jul01,ros  add CofE comment
01o,05sep00,dra  Updated FP emulation, added 32 FP support.
01n,13jun00,dra  correct cdf file discrepancies
01m,01nov99,dra  Fixed handling of stray FP exceptions when SR_CU1 bit is
                 clear.
01l,16aug99,dra  updated for vxWorks6.
01k,12aug98,kkk  fixed bug in saving FPCSR in fpIntr, now it's saved
		 in excStub. (SPR# 20669)
01j,08mar97,kkk  took out saving of registers in fpIntr() for R3000.
01i,10dec96,tam  replaced CPU_R3XXX macros.
01h,02feb96,mem  Added decoding of FPU exception cause.  Fixed forwarding
	         of exceptions.
01g,18oct93,cd   added R4000 support.
01f,01sep93,yao  removed ifdef.  changed not to read fpcsr when fpu
		 is not available.  redefined stack offset constants.
01e,05jun92,ajm  ifdef'd out unused code for now
01d,26may92,rrr  the tree shuffle
		  -changed includes to have absolute path from h/
01c,04oct91,rrr  passed through the ansification filter
		  -fixed #else and #endif
		  -changed ASMLANGUAGE to _ASMLANGUAGE
		  -changed copyright notice
01b,29aug91,wmd   moved to r3k/math directory, chg'd softFp.h->fpSoft.h.
01a,22jul91,ajm   wrs-ized from MIPS code
*/

/*
 * |-----------------------------------------------------------|
 * | Copyright (c) 1990 MIPS Computer Systems, Inc.            |
 * | All Rights Reserved                                       |
 * |-----------------------------------------------------------|
 * |          Restricted Rights Legend                         |
 * | Use, duplication, or disclosure by the Government is      |
 * | subject to restrictions as set forth in                   |
 * | subparagraph (c)(1)(ii) of the Rights in Technical        |
 * | Data and Computer Software Clause of DFARS 52.227-7013.   |
 * |         MIPS Computer Systems, Inc.                       |
 * |         950 DeGuigne Drive                                |
 * |         Sunnyvale, CA 94086                               |
 * |-----------------------------------------------------------|
 */

/*
DESCRIPTION
This library contains the MIPS floating point interrupt handler.
To get to into this library there must be some form of floating-point
coprocessor hardware to generate the interrupt/exception.  Because floating
point operations should not be executed at interrupt level, FPA exceptions
should always come from the current executing task, and taskIdCurrent
will contain the TID of the task executing the FPA instruction.  The
handler clears the FPA exception and decides whether to ignore the
exception, signal on the condition, or emulate the FPA instruction.
The current values of the floating-point registers are in the floating
point registers in the coprocessor.

The register state on entry to this routine is:

    a0 - vector number
    a1 - exception stack pointer


Upon exit of this routine any modified value of a floating-point register
is just left in that register and then a return to the caller is done.
The caller is the routine excIntStub which will restore the processor state
and call the kernel.  If the kernel decides it is necessary to reschedule,
the FPA switch hook routines will save and restore the new FPA state for the
current process.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "esf.h"
#include "fppLib.h"
#include "arch/mips/archMips.h"
#include "arch/mips/excMipsLib.h"
#include "private/taskLibP.h"
#include "arch/mips/fpSoft.h"
#include "asm.h"
#include "iv.h"

#ifndef WIND_TCB_OPTIONS
#include "taskLib.h"
#define WIND_TCB_OPTIONS	0x38
#define WIND_TCB_PFPCONTEXT	0xc0
#endif
	
/* defines */

#define DEBUG

#define VX_FP_TASK              0x0008		/* XXX */
#define	FRAMETID(routine)	FRAMER0(routine)
#define	FRAMEEPC(routine)	FRAMER1(routine)

	.globl	GTEXT(excExcHandle)		/* exc handler */

	.text
	.set	reorder

/******************************************************************************
* fpIntr - Interrupt handler for MIPS floating point unit
*
* On entry:
*  a0:	vecNum
*  a1:	ESFMIPS *
*  a2:	REG_SET *
*/

	.globl	GTEXT(fpIntr)
	.ent	fpIntr
FUNC_LABEL(fpIntr)
	SETFRAME(fpIntr,2)
	.frame	sp, FRAMESZ(fpIntr), ra
	subu	sp, FRAMESZ(fpIntr)

	SW	ra, FRAMERA(fpIntr)(sp)
	sw	a0, FRAMEA0(fpIntr)(sp)	/* save vector */
	sw	a1, FRAMEA1(fpIntr)(sp)	/* save pEsf */
/*	.mask	0x80000002, -LOCAL_SIZE */

	lw	t0, taskIdCurrent
	move	t1, a0			/* save vector */
	sw	t0, FRAMETID(fpIntr)(sp) /* save taskIdCurrent */
	move	a0, a1			/* a0 becomes pEsf */

#if FALSE
#if	(CPU == R3000)
    /*
    *  Save regs that excIntStub would not have.  This is necessary
    *  for branch emulation, and signals.
    */
	sw	zero, E_STK_ZERO(a0)		/* save zero  reg */
	sw	s0, E_STK_S0(a0)		/* save saved reg 0 */
	sw	s1, E_STK_S1(a0)		/* save saved reg 1 */
	sw	s2, E_STK_S2(a0)		/* save saved reg 2 */
	sw	s3, E_STK_S3(a0)		/* save saved reg 3 */
	sw	s4, E_STK_S4(a0)		/* save saved reg 4 */
	sw	s5, E_STK_S5(a0)		/* save saved reg 5 */
	sw	s6, E_STK_S6(a0)		/* save saved reg 6 */
	sw	s7, E_STK_S7(a0)		/* save saved reg 7 */
	sw	s8, E_STK_FP(a0)		/* save frame pointer */
	sw	gp, E_STK_GP(a0)		/* save global pointer */
#endif	/* CPU == R3000 */
#endif /* FALSE */

	subu	t1, t1, EXC_CODE_FPU		/* get exception type */
	sw	t1, FRAMEA2(fpIntr)(sp)		/* save exception type */
	beq	t1, zero, noFpu

	lw	t0, E_STK_FPCSR(a0)             /* load FPCSR from stack */

#ifdef DEBUG
	/* At this point, t0 holds the unmodified fpscr reg value. */
	.comm	_fp_fpscr, 4
	sw	t0, _fp_fpscr
#endif	
	/*
	 * The following doesn't seem to handle well the case on the R4000
	 * where the SR_FR bit in the task's status register was clear
	 * and the task referenced an odd floating point register.
	 */
	
	/* check for unimplemented operation */
	li	t1, FP_EXC_E
	and	t1, t0, t1
	bnez	t1, noFpu
	
	/*
	 * If the cause of the FP exception was something other than a
	 * unimplemented operation exception, divert the exception to the
	 * proper exception handler.
	 */
	
	/* check for inexact operation */
	li	a0, EXC_CODE_FPE_INEXACT
	li	t1, FP_EXC_I
	and	t1, t0, t1
	bnez	t1, fpuForwardExc
	
	/* check for underflow */
	li	a0, EXC_CODE_FPE_UNDERFLOW
	li	t1, FP_EXC_U
	and	t1, t0, t1
	bnez	t1, fpuForwardExc
	
	/* check for overflow */
	li	a0, EXC_CODE_FPE_OVERFLOW
	li	t1, FP_EXC_O
	and	t1, t0, t1
	bnez	t1, fpuForwardExc
	
	/* check for divide by zero */
	li	a0, EXC_CODE_FPE_DIV0
	li	t1, FP_EXC_Z
	and	t1, t0, t1
	bnez	t1, fpuForwardExc
	
	/* check for invalid operation */
	li	a0, EXC_CODE_FPE_INVALID
	li	t1, FP_EXC_V
	and	t1, t0, t1
	bnez	t1, fpuForwardExc
	
	/* shouldn't get here */
	li	a0, EXC_CODE_RI
	b	fpuForwardExc
	
noFpu:
	lw	a3, E_STK_SR(a0)	/* SR at time of exception */
	and	a3, SR_CU1		/* FPU usable bit */
	beq	a3, zero, 0f		/* FPU off - no FP allowed */

	lw	a3, FRAMETID(fpIntr)(sp)/* get current excecuting task */
	lw	a2, WIND_TCB_OPTIONS(a3)/* read options field */
	andi	a2, VX_FP_TASK		/* mask all but VX_FP_TASK bit */
	bnez	a2, 1f			/* are we allowed to use fp unit */
0:
	/*
	 * At this point there has been an exception from the floating-point
	 * coprocessor but the current task was not allowed to use it.
	 * This isn't really good enough, the task probably *is* using floating
	 * point but the kernel won't be saving its state...
	 */
	
	la	a0, strayString
	jal	logMsg			/* let us know about strays */
	
	li	a0, IV_CPU_VEC		/* translates to SIGILL */
	b	send_signal

1:
	lw	a0, FRAMEA1(fpIntr)(sp)	/* pEsf to a0 */ 
	lw	a3, E_STK_EPC(a0)	/* load the epc into a3 */
	lw	a1, 0(a3)		/* load the instr at the epc into a1 */
	lw	v0, E_STK_CAUSE(a0)	/* load the cause register into v0 */
	
#ifdef DEBUG
	/* count of number of exceptions seen */
	.comm	_fp_epc, 4
	.comm	_fp_cause, 4
	sw	a3, _fp_epc
	sw	v0, _fp_cause
#endif	
	bltz	v0, 3f			/* in branch delay slot ? */

	/*
	 * This is not in a branch delay slot (branch delay bit not set) so
	 * calculate the resulting pc (epc+4) into v0 and continue to softFp().
	 */
	addu	v0, a3, 4
	sw	v0, FRAMEEPC(fpIntr)(sp)	/* save the resulting pc */
	b	4f
3:
	/*
	 * This is in a branch delay slot so the branch will have to be
	 * emulated to get the resulting pc (done by calling emulateBranch() ).
	 * The arguments to emulateBranch are:
	 *     a0 - pEsf (exception stack)
	 *     a1 - the branch instruction
	 *     a2 - the floating-point control and status register
	 */

	lw	a2, E_STK_FPCSR(a0)	/* get value of C1_SR */
	jal	fppEmulateBranch	/* emulate the branch */
	bne	v0, 1, emulateOk
	
	/* failed to emulate branch correctly */
	li      a0, IV_CPU_VEC		/* translates to SIGILL */
	b	send_signal

emulateOk:
	sw	v0, FRAMEEPC(fpIntr)(sp)	/* save the resulting pc */
	lw	a0, FRAMEA1(fpIntr)(sp)	/* restore exception stack pointer */
	lw	a3, E_STK_EPC(a0)	/* load the epc into a3 */
	lw	a1,4(a3)	/* get instruction to be emulated from BD slot */

4:
	/*
	 * Check to see if the instruction to be emulated is a floating-point
	 * instruction.  If it is not then this interrupt must have been caused
	 * by writing to the C1_SR a value which will cause an interrupt.
	 * It is possible however that when writing to the C1_SR the
	 * instruction that is to be "emulated" when the interrupt is handled
	 * looks like a floating-point instruction and will incorrectly be
	 * emulated and a SIGILL will not be sent.  This is the user's problem
	 * because he shouldn't write a value into the C1_SR which should
	 * cause an interrupt.
	 *
	 * 5/20/2002 pes - We can also get to this point if we are trying to
	 * emulate an opcode other than OPCODE_C1. Given that we don't know
	 * whether the software FP emulator can handle other opcodes,
	 * it is now deemed more likely for the problem to be unimplemented
	 * opcodes than generating an interrupt with a value written to C1_SR.
	 *
	 */
	srl	a3,a1,OPCODE_SHIFT
	beq	a3,OPCODE_C1,10f

	/*
	 * Assume the emulator can't handle any opcode other than OPCODE_C1.
	 * Report as Unimplemented FPA operation.
	 */

	li	a0, IV_FPA_UNIMP_VEC
	b	send_signal

10:
	/*
	 * For now all instructions that cause an interrupt are just handed
	 * off to softFp() to emulate it and come up with correct result.
	 * The arguments to softFp() are:
	 *	a0 - pEsf (exception stack)
	 *	a1 - floating-point instruction
	 *	a2 - fpuIsAlive
	 *	a3 - taskIdCurrent
	 *
	 * What might have be done is for all exceptions for which the trapped
	 * result is the same as the untrapped result is: turn off the enables,
	 * re-excute the instruction, restore the enables and then post a
	 * SIGFPE.
	 */

	lw	a2, FRAMEA2(fpIntr)(sp)	/* load exception type */
	lw	t0, FRAMETID(fpIntr)(sp)/* get current excecuting task */
	lw	a3, WIND_TCB_PFPCONTEXT(t0)	/* read pFpContext - FIX */
	jal	softFp			/* emulate away */
	bne	v0,zero,8f		/* signal posted */

#ifdef ASSERTIONS
	/*
	 * If going back to user code without posting a signal there must
	 * not be any exceptions which could cause an interrupt.
	 */
	lw	a0, E_STK_FPCSR(a0)	/* get fp status reg   */
	and	a1,a0,CSR_EXCEPT	/* isolate the exception bits */
	and	a0,CSR_ENABLE 		/* isolate the enable bits */
	or	a0,(UNIMP_EXC >> 5)	/* fake an enable for unimplemented */
	sll	a0,5			/* align both bit sets */
	and	a0,a1			/* check for corresponding bits */
	beq	a0,zero,7f		/* if not then ok */
	PANIC("fpIntr csr exceptions")
7:
#endif	/* ASSERTIONS */

	/*
	 * The instruction was emulated by softFp() without a signal being
	 * posted so now change the epc to the target pc.
	 */
	lw	a0, FRAMEA1(fpIntr)(sp)	 /* restore the exception stack pointer */
	lw	v0, FRAMEEPC(fpIntr)(sp) /* get the resulting pc */
	sw	v0, E_STK_EPC(a0)	/* store the resulting pc in the epc */

	b	8f
strayFpExc:

	
8:
	LW	ra,FRAMERA(fpIntr)(sp)
	addu	sp,FRAMESZ(fpIntr)
	j	ra
	
send_signal:
fpuForwardExc:
	/* Force coprocessor unusable exceptions to excExcHandle */
	la	v0, IV_CPU_VEC
	beq	a0, v0, fpuForceExc
	
	/*
	 * An FPU exception that we can't handle, forward to the
	 * exception vector entered in excBsrTbl[].
	 *	a0 - vector #
	 * Simply load up the vector from excBsrTbl[] and jump to fpuExc.
	 */
	sll	v0, a0, 2
	la	t0, excBsrTbl
	addu	t0, v0
	lw	v0, (t0)
	b	fpuExc
	
fpuForceExc:
	/*
	 * An FPU exception that we can't handle, force a call
	 * to excExcHandle, do not use the excBsrTbl[] exception table.
	 */
	la	v0, excExcHandle
	
fpuExc:
	/*
	 * Undo our frame and call the specified exception handler
	 * exception vector entered in excBsrTbl[].
	 *	a0 - vector #
	 *	v0 - exception handler to call.
	 */
#ifdef DEBUG
	.comm	_fp_exc, 4
	sw	a0, _fp_exc
	
	.comm	_fp_exc_vec, 4
	sw	v0, _fp_exc_vec
#endif
	
	lw	a1, FRAMEA1(fpIntr)(sp) /* pEsf to a1 */ 
	la	a2, E_STK_SR(a1)	/* pass general register ptr */
	
	/* undo our stack frame */
	LW	ra,FRAMERA(fpIntr)(sp)
	addu	sp,FRAMESZ(fpIntr)
	
	/* tail call to the exception handler, we don't return here. */
	jr	v0
	
	.end	fpIntr

/******************************************************************************
*
* strayString -
*
*/
	.rdata
strayString:
	.ascii	"Stray fp exception\n"
	.byte	0
