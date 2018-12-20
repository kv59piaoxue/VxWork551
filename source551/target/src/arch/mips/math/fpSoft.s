/* fpSoft.s - MIPS R-Series floating point software emulation library */

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
01q,01aug01,mem  Diab integration
01p,16jul01,ros  add CofE comment
01o,20jun01,ros  fix floating point
01n,02may01,mem  Fix rt_cp_2w calculation.
01m,13mar01,tlc  Perform HAZARD review.
01l,05sep00,dra  Updated FP emulation, added 32 FP support.
01k,13jun00,dra  correct cdf file discrepancies
01j,28feb00,dra  Added macros for assembler label definitions.
01i,05oct99,dra  Added 32 FP reg mode support.
01h,16nov95,mem  Changed (SIGNBIT>>16) to (SIGNBIT>>16) & 0xffff to suppress
		 an assembler warning.
		 Fixed FP instruction decoding.  Fixed several bugs in
		 xxx_fmt_tab offset calculations.
01g,18oct93,cd   added R4000 support.
01f,16aug93,yao  added mathSoftAInit(). added store to fpu register from
		 processor, store to processor register to fpu register,
		 load/store to memory address from fpu registger emulation.
		 redefined stack offset constants. changed entry table in
		 data segment to jump table in text segment.
01e,06jun92,ajm  ifdefd out unused code for now, rid of single quotes for
		 make problems, fixed if/else comments
01d,26may92,rrr  the tree shuffle
		  -changed includes to have absolute path from h/
01c,04oct91,rrr  passed through the ansification filter
		  -changed includes to have absolute path from h/
		  -changed ASMLANGUAGE to _ASMLANGUAGE
		  -changed copyright notice
01b,29aug91,wmd   moved to r3k/math directory, chgd softFp.h->fpSoft.h.
01a,22jul91,ajm   wrs-ized from MIPS code
*/

/*
DESCRIPTION
This library contains the MIPS floating point emulation package.
These routines are used for software emulation of floating point instructions,
unimplemented instruction emulation, and correct processing of
ieee FPA exceptions.  This does not emulate and branch on condition 
instructions.  The software floating-point emulator is called from fpIntr 
with floating-point coprocessor unusable exception or the floating-point 
exception.

The register state on entry to this routine is:

    a0 - exception stack pointer
    a1 - fp instruction to be emulated
    a2 - interrupt or exception
    a3 - pFpContext

The normal calling convention is assumed with the appropriate registers
saved by the caller as if it were a high level language routine.

If register a2 it is non-zero then this routine was called from the
floating-point interrupt handler.  In this case the values of the floating
point registers are still in the coprocessor and the pointer to the tcb
structure for the task that executed the fp instruction is in pFpContext.

If register a2 is zero then this routine was called from the coprocessor
unusable handler.  In this case the values of the floating point registers
are in the tcb for the current task and the pointer to the tcb structure
for the current task is in pFpContext.

This routune returns a non-zero value in v0 if there was a signal posted
to the process as the result of an exception.  Otherwise v0 will be zero.
*/

/* |-----------------------------------------------------------|
 * | Copyright (c) 1991, 1990 MIPS Computer Systems, Inc.      |
 * | All Rights Reserved                                       |
 * |-----------------------------------------------------------|
 * |          Restricted Rights Legend                         |
 * | Use, duplication, or disclosure by the Government is      |
 * | subject to restrictions as set forth in                   |
 * | subparagraph (c)(1)(ii) of the Rights in Technical        |
 * | Data and Computer Software Clause of DFARS 252.227-7013.  |
 * |         MIPS Computer Systems, Inc.                       |
 * |         950 DeGuigne Avenue                               |
 * |         Sunnyvale, California 94088-3650, USA             |
 * |-----------------------------------------------------------|
 */

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "esf.h"
#include "fppLib.h"
#include "iv.h"
#include "asm.h"
#include "arch/mips/fpSoft.h"
#include "signal.h"
#include "private/taskLibP.h"

#define DEBUG	

	.globl	GTEXT(mathSoftAInit)
	.globl	GTEXT(softFp)
	.globl	GTEXT(sqrt_s)
	.globl	GTEXT(sqrt_d)
	.globl	GTEXT(abs_s)
	.globl	GTEXT(abs_d)
	.globl	GTEXT(mov_d)
	.globl	GTEXT(mov_s)
	.globl	GTEXT(neg_d)
	.globl	GTEXT(neg_s)
	.globl	GTEXT(add_d)
	.globl	GTEXT(add_s)
	.globl	GTEXT(mul_d)
	.globl	GTEXT(mul_s)
	.globl	GTEXT(div_d)
	.globl	GTEXT(div_s)
	.globl	GTEXT(norm_s)
	.globl	GTEXT(norm_d)
	.globl	GTEXT(cvts_from_d)
	.globl	GTEXT(cvtd_from_s)
	.globl	GTEXT(cvtd_from_w)
	.globl	GTEXT(cvtd_from_l)	
	.globl	GTEXT(cvtw_from_d)
	.globl	GTEXT(cvtw_from_s)

#ifdef DEBUG
	.comm	_fp_sign,4
	.comm	_fp_exp,4
	.comm	_fp_frA,4
	.comm	_fp_frB,4
	.comm	_fp_insn, 4
	.comm	_fp_trace, 4
	.comm	_fp_trace_data, 64
	.comm	_fp_val, 4
	.comm	_fp_fmt, 4
	.comm	_fp_rs,8
	.comm	_fp_rt,8
	.comm	_fp_overflow_trace,4
	.comm	_fp_overflow, 4
	.comm	_fp_rw,4
	.comm	_fp_rd,8
	.comm	_fp_rs_reg,4
	.comm	_fp_rt_reg,4
	.comm	_fp_rd_reg,4
	.comm	_fp_rd_val,8
#endif

	.text
	.set	reorder

/*******************************************************************************
*
* mathSoftAInit - initialize coprocessor as unusable for software floating
*		  point emulation
*
* NOMANUAL
*/
	.globl	GTEXT(mathSoftAInit)

	.ent	mathSoftAInit

FUNC_LABEL(mathSoftAInit)
	mfc0	t0, C0_SR
	HAZARD_CP_READ
	and	t0, t0, ~SR_CU1
	mtc0	t0, C0_SR
	HAZARD_CP_WRITE
	j	ra
	.end	mathSoftAInit

/*******************************************************************************
*
* softFp - software emulation package
*
*/

	.globl	GTEXT(softFp)
	.ent	softFp, 0
FUNC_LABEL(softFp)
	SETFRAME(softFp,1);
#define RM_OFFSET FRAMER0(softFp)
	.frame	sp, FRAMESZ(softFp), ra
	subu	sp, FRAMESZ(softFp)
	SW	ra, FRAMERA(softFp)(sp)	/* save return address */
	sw	a0, FRAMEA0(softFp)(sp)	/* save exception vector */
	sw	a3, FRAMEA3(softFp)(sp)	/* save pFpContext */

#ifdef DEBUG
	sw	a1, _fp_insn
#endif	
	srl	v0, a1, FPU_TYPE_SHIFT	/* shift fpu instruction */
	and	v1, v0, FPU_TYPE_MASK	/* get instruction type */
	beq	v1, zero, emuLdSt	/* check for load/store instruction */

/*
 * In decoding the instruction it is assumed that the opcode field is COP1
 * and that bit 25 is set  (since only floating-point ops are supposed to
 * be emulated in this routine) and therefore these are not checked.
 * The following fields are fully decoded and reserved encodings will result
 * in an illegal instruction signal (SIGILL) being posted:
 *      FMT -- (bits 24-21)
 *     FUNC -- (bits 5-0)
 */
	/*
	 * Extract the FMT field and exclude illegal values.
	 * On exit from this block of code, v0 will have one of
	 * the following values:
	 *	 0	single floating-point
	 *	 8	double floating-point
	 *	16	reserved
	 *	24	reserved
	 *	32	single fixed-point
	 *	40	double fixed-point
	 * which means each jump table for fmt cases needs 6 entries.
	 */
	srl	v0,a1,C1_FMT_SHIFT-3
	and	v0,C1_FMT_MASK<<3
#ifdef DEBUG
	sw	v0, _fp_fmt
#endif
	bgt	v0,C1_FMT_MAX<<3,illfpinst

	/*
	 * Load the floating point value from the register specified by the
	 * RS field into gp registers.  The gp registers which are used for
	 * the value specified by the RS field are dependent on the FMT (v0)
	 * as follows:
	 * 	single		t2
	 *	double		t2,t3
	 *	extended	t2,t3,s2,s3	(where t3 is really zero)
	 *	quad		t2,t3,s2,s3
	 *
	 * Also load the value of the floating-point control and status
	 * register (C1_SR) into gp register a3.
	 */
load_rs:
	srl	v1,a1,RS_SHIFT		# get the RS field
	and	v1,RS_MASK
#ifdef DEBUG
	sw	v1,_fp_rs_reg
#endif

	/*
	 * If a2 (int or exception) is non-zero then the floating-point values
	 * are loaded from the coprocessor else they are loaded from the tcb.
	 */
	beq	a2,zero,rs_tcb
	
	/*
	 * At this point the floating-point value for the specified FPR register
	 * in the RS field (v1) will be loaded from the coprocessor registers
	 * for the FMT specified (v0).  Also the floating-point control and
	 * status register (C1_SR) is loaded into gp register a3.
	 */
	.set	noreorder
	nop				/* BDSLOT */
	cfc1	a3,C1_SR
	HAZARD_CP_READ
					/* setup to branch to the code to load */
	la	t9, cp_rs_fmt_tab	/* load table address  */
	and	t2,a3,CSR_RM_MASK	/* isolate the current Rounding Mode */
	addu	t9, v0, t9
	j	t9			/*  cp for the specified format. */
	SW	t2,RM_OFFSET(sp)	/* (BDSLOT) save current RM on stack */
	.set	reorder
	.set	noreorder
cp_rs_fmt_tab:
	b	rs_cp_1w; nop		/* 16: single */
	b	rs_cp_2w; nop		/* 17: double */
	b	illfpinst; nop		/* 18: reserved */
	b	illfpinst; nop		/* 19: reserved */
	b	rs_cp_1w; nop		/* 20: single (fixed) */
	b	rs_cp_2w; nop		/* 21: double (fixed) */
	.set	reorder

/*******************************************************************************
*
* emuLdSt - emulate FPU load / store instrunction
*
* on entry: a0 - esf stack pointer
*           a1 - FPU instruction caused exception
*           v0 - shifted FPU instruction
*
* registers used: v1, t2, t3
*
* NOMANUAL
*/

emuLdSt:
	andi 	v1, v0, FPU_I_INST_MASK	/* instruction code to v0 */
	andi 	t1, a1, FPU_I_RS_MASK	/* rs field to t1 */
	andi 	t2, v0, FPU_I_RT_MASK	/* rt field to t2 */
	sll	t1, t1, 2		/* register * 4 */
	sll	t2, t2, 2		/* register * 4 */
	lw	a0, FRAMEA0(softFp)(sp)	/* a0=pEsf */
	lw	a2, FRAMEA3(softFp)(sp)		/* a2=pFpContext */
	li   	t3, FPU_INST_MFC
	beq	t3, v1, emuMCfc1	/* is it mfc1 */
	li   	t3, FPU_INST_MTC
	beq	t3, v1, emuMCtc1	/* is it mtc1 */
	li   	t3, FPU_INST_CFC
	beq	t3, v1, emuMCfc1	/* is it cfc1 */
	li   	t3, FPU_INST_CTC
	beq	t3, v1, emuMCtc1	/* is it ctc1 */
	andi	t1, v0, SLW_BASE_MASK	/* else s/lwc1, base to t1 */
	andi	t0, a1, OFFSET_MASK	/* t0 - offset */
	andi	t2, v0, FPU_I_RT_MASK	/* ft field to t2 */
	li	t4, FPU_SW_INSTR
	andi	t6, v0, FPU_STLD1_MASK	/* t6=func code */
	srl	t1, t1, 3		/* base register times 4 */
	sll	t2, t2, 2		/* ft register times 4 */
	beq	t4, t6, emuSw		/* is swc1 instruction */
	li	t4, FPU_LW_INSTR
	beq	t4, t6, emuLw		/* is lwc1 instruction */
emuExit:
	LW	ra, FRAMERA(softFp)(sp)		/* else unknown instruction */
	addu	sp, FRAMESZ(softFp)
	move	v0, zero		/* clear return value */
	j	ra

/*******************************************************************************
*
* emuMfc1 - emulate mfc instruction
*
* on entry: t1 - rs field, t2 - rt field, a0 - pEsf, 
*	    a1 - FPU instr a2 - taskIdCurrent
*
* NOMANUAL
*/

emuMCfc1:
	lw	t3, taskIdCurrent		/* get tcb */
	addi	t2, WIND_TCB_GREG_BASE		/* get gp register offset */
	addu	t1, a3				/* get fpu register address */
	addu	t2, t3				/* gp register address in tcb */
	lw	t4, (t1)			/* load FPU register */
	SW	t4, (t2)			/* store to general register */
	b	emuExit

/*******************************************************************************
*
* emuMCtc1 - emulate mtc instruction
*
* on entry: t1 - rs field, t2 - rt field
*
* NOMANUAL
*/
emuMCtc1:
	addi	t2, t2, E_STK_ZERO	/* get gp offset to esf stack */
	addu	t1, a3, t1		/* get fpu register address */
	addu	t2, a0, t2		/* get gp register address on stack */
	LW	t4, (t2)		/* load general register */
	sw	t4, (t1) 		/* store to fpu register */
	b	emuExit

/*******************************************************************************
*
* emuSw - emulate swc1 instruction
*
* on entry: t0 - offset, t1 - base field, t2 - ft field, a0 - pEsf, 
*	    a1 - FPU instr a3 - pFpContext
*/
emuSw:
	addi	t1, E_STK_ZERO 		/* base register offset to t1 */
	addu	t2, a3			/* fpu register address to t2 */
	addu	t1, a0			/* base address to t1 */
	lw	t3, (t2)		/* load fpu register to t3 */
	LW	t4, (t1)		/* base register to t4 */
	addu	t4, t0, t4		/* destination address to t1 */
	sw	t3, (t4)		/* store fpu register */
	b emuExit

/*******************************************************************************
*
* emuLw - emulate mfc instruction
*
* on entry: t0 - offset, t1 - base field, t2 - ft field, a0 - pEsf, 
*	    a1 - FPU instr a3 - pFpContext
*/
emuLw:
	lw	t4, taskIdCurrent	/* tcb to t4 */
	addu	t2, a3			/* fpu register address to t2 */
	addi	t4, WIND_TCB_GREG_BASE	/* gp base address to t4 */
	addu	t4, t1			/* get base register address */
	LW	t1, (t4)		/* base register to t1 */
	addu	t1, t0, t1		/* source address to t1 */
	lw	t3, (t1)		/* load from source */
	sw	t3, (t2)		/* store to fpu register */
	b	emuExit

/*******************************************************************************
*
* rs_cp_1w -
*
* Load the one word from the coprocessor for the FPR register specified by
* the RS (v1) field into GPR register t2.
*/
rs_cp_1w:
	sll	v1, v1, 3		/* 8 bytes per entry */
	la	t9, rs_cp_1w_tab	/* load table address */
	addu	v1, t9, v1		/* get entry address */
	j	v1

	.set noreorder
rs_cp_1w_tab:
	b	rs_cp_1w_fpr0; nop
	b	rs_cp_1w_fpr1; nop
	b	rs_cp_1w_fpr2; nop
	b	rs_cp_1w_fpr3; nop
	b	rs_cp_1w_fpr4; nop
	b	rs_cp_1w_fpr5; nop
	b	rs_cp_1w_fpr6; nop
	b	rs_cp_1w_fpr7; nop
	b	rs_cp_1w_fpr8; nop
	b	rs_cp_1w_fpr9; nop
	b	rs_cp_1w_fpr10; nop
	b	rs_cp_1w_fpr11; nop
	b	rs_cp_1w_fpr12; nop
	b	rs_cp_1w_fpr13; nop
	b	rs_cp_1w_fpr14; nop
	b	rs_cp_1w_fpr15; nop
	b	rs_cp_1w_fpr16; nop
	b	rs_cp_1w_fpr17; nop
	b	rs_cp_1w_fpr18; nop
	b	rs_cp_1w_fpr19; nop
	b	rs_cp_1w_fpr20; nop
	b	rs_cp_1w_fpr21; nop
	b	rs_cp_1w_fpr22; nop
	b	rs_cp_1w_fpr23; nop
	b	rs_cp_1w_fpr24; nop
	b	rs_cp_1w_fpr25; nop
	b	rs_cp_1w_fpr26; nop
	b	rs_cp_1w_fpr27; nop
	b	rs_cp_1w_fpr28; nop
	b	rs_cp_1w_fpr29; nop
	b	rs_cp_1w_fpr30; nop
	b	rs_cp_1w_fpr31; nop
	.set	reorder

	.set	noreorder
rs_cp_1w_fpr0:
	mfc1	t2,$f0;		b	load_rs_done; 	nop
rs_cp_1w_fpr1:
	mfc1	t2,$f1;		b	load_rs_done; 	nop
rs_cp_1w_fpr2:
	mfc1	t2,$f2;		b	load_rs_done; 	nop
rs_cp_1w_fpr3:
	mfc1	t2,$f3;		b	load_rs_done; 	nop
rs_cp_1w_fpr4:
	mfc1	t2,$f4;		b	load_rs_done; 	nop
rs_cp_1w_fpr5:
	mfc1	t2,$f5;		b	load_rs_done; 	nop
rs_cp_1w_fpr6:
	mfc1	t2,$f6;		b	load_rs_done; 	nop
rs_cp_1w_fpr7:
	mfc1	t2,$f7;		b	load_rs_done; 	nop
rs_cp_1w_fpr8:
	mfc1	t2,$f8;		b	load_rs_done; 	nop
rs_cp_1w_fpr9:
	mfc1	t2,$f9;		b	load_rs_done; 	nop
rs_cp_1w_fpr10:
	mfc1	t2,$f10;	b	load_rs_done; 	nop
rs_cp_1w_fpr11:
	mfc1	t2,$f11;	b	load_rs_done; 	nop
rs_cp_1w_fpr12:
	mfc1	t2,$f12;	b	load_rs_done; 	nop
rs_cp_1w_fpr13:
	mfc1	t2,$f13;	b	load_rs_done; 	nop
rs_cp_1w_fpr14:
	mfc1	t2,$f14;	b	load_rs_done; 	nop
rs_cp_1w_fpr15:
	mfc1	t2,$f15;	b	load_rs_done; 	nop
rs_cp_1w_fpr16:
	mfc1	t2,$f16;	b	load_rs_done; 	nop
rs_cp_1w_fpr17:
	mfc1	t2,$f17;	b	load_rs_done; 	nop
rs_cp_1w_fpr18:
	mfc1	t2,$f18;	b	load_rs_done; 	nop
rs_cp_1w_fpr19:
	mfc1	t2,$f19;	b	load_rs_done; 	nop
rs_cp_1w_fpr20:
	mfc1	t2,$f20;	b	load_rs_done; 	nop
rs_cp_1w_fpr21:
	mfc1	t2,$f21;	b	load_rs_done; 	nop
rs_cp_1w_fpr22:
	mfc1	t2,$f22;	b	load_rs_done; 	nop
rs_cp_1w_fpr23:
	mfc1	t2,$f23;	b	load_rs_done; 	nop
rs_cp_1w_fpr24:
	mfc1	t2,$f24;	b	load_rs_done; 	nop
rs_cp_1w_fpr25:
	mfc1	t2,$f25;	b	load_rs_done; 	nop
rs_cp_1w_fpr26:
	mfc1	t2,$f26;	b	load_rs_done; 	nop
rs_cp_1w_fpr27:
	mfc1	t2,$f27;	b	load_rs_done; 	nop
rs_cp_1w_fpr28:
	mfc1	t2,$f28;	b	load_rs_done; 	nop
rs_cp_1w_fpr29:
	mfc1	t2,$f29;	b	load_rs_done; 	nop
rs_cp_1w_fpr30:
	mfc1	t2,$f30;	b	load_rs_done; 	nop
rs_cp_1w_fpr31:
	mfc1	t2,$f31;	b	load_rs_done; 	nop
	.set	reorder

/*******************************************************************************
*
* rs_cp_2w -
*
* Load the two words from the coprocessor for the FPR register specified by
* the RS (v1) field into GPR registers t2,t3.
*/
rs_cp_2w:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	srl	v1, v1, 1		/* only allow even numbered registers */
#endif	  /* _WRS_FP_REGISTER_SIZE */
	sll	v1, v1, 3		/* 8 bytes per entry */
	la	t9, rs_cp_2w_tab	/* load table */
	addu	v1, t9, v1		/* get entry address */
	j	v1

	.set	noreorder
rs_cp_2w_tab:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	b	rs_cp_2w_fpr0;	nop
	b	rs_cp_2w_fpr2;	nop
	b	rs_cp_2w_fpr4;	nop
	b	rs_cp_2w_fpr6;	nop
	b	rs_cp_2w_fpr8;	nop
	b	rs_cp_2w_fpr10;	nop
	b	rs_cp_2w_fpr12;	nop
	b	rs_cp_2w_fpr14;	nop
	b	rs_cp_2w_fpr16;	nop
	b	rs_cp_2w_fpr18;	nop
	b	rs_cp_2w_fpr20;	nop
	b	rs_cp_2w_fpr22;	nop
	b	rs_cp_2w_fpr24;	nop
	b	rs_cp_2w_fpr26;	nop
	b	rs_cp_2w_fpr28;	nop
	b	rs_cp_2w_fpr30;	nop
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	b	rs_cp_2w_fpr0; nop
	b	rs_cp_2w_fpr1; nop
	b	rs_cp_2w_fpr2; nop
	b	rs_cp_2w_fpr3; nop
	b	rs_cp_2w_fpr4; nop
	b	rs_cp_2w_fpr5; nop
	b	rs_cp_2w_fpr6; nop
	b	rs_cp_2w_fpr7; nop
	b	rs_cp_2w_fpr8; nop
	b	rs_cp_2w_fpr9; nop
	b	rs_cp_2w_fpr10; nop
	b	rs_cp_2w_fpr11; nop
	b	rs_cp_2w_fpr12; nop
	b	rs_cp_2w_fpr13; nop
	b	rs_cp_2w_fpr14; nop
	b	rs_cp_2w_fpr15; nop
	b	rs_cp_2w_fpr16; nop
	b	rs_cp_2w_fpr17; nop
	b	rs_cp_2w_fpr18; nop
	b	rs_cp_2w_fpr19; nop
	b	rs_cp_2w_fpr20; nop
	b	rs_cp_2w_fpr21; nop
	b	rs_cp_2w_fpr22; nop
	b	rs_cp_2w_fpr23; nop
	b	rs_cp_2w_fpr24; nop
	b	rs_cp_2w_fpr25; nop
	b	rs_cp_2w_fpr26; nop
	b	rs_cp_2w_fpr27; nop
	b	rs_cp_2w_fpr28; nop
	b	rs_cp_2w_fpr29; nop
	b	rs_cp_2w_fpr30; nop
	b	rs_cp_2w_fpr31; nop
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	
#if	  (_WRS_FP_REGISTER_SIZE == 4)
rs_cp_2w_fpr0:
	mfc1	t3,$f0;		mfc1	t2,$f1;		b	load_rs_done
	nop
rs_cp_2w_fpr2:
	mfc1	t3,$f2;		mfc1	t2,$f3;		b	load_rs_done
	nop
rs_cp_2w_fpr4:
	mfc1	t3,$f4;		mfc1	t2,$f5;		b	load_rs_done
	nop
rs_cp_2w_fpr6:
	mfc1	t3,$f6;		mfc1	t2,$f7;		b	load_rs_done
	nop
rs_cp_2w_fpr8:
	mfc1	t3,$f8;		mfc1	t2,$f9;		b	load_rs_done
	nop
rs_cp_2w_fpr10:
	mfc1	t3,$f10;	mfc1	t2,$f11;	b	load_rs_done
	nop
rs_cp_2w_fpr12:
	mfc1	t3,$f12;	mfc1	t2,$f13;	b	load_rs_done
	nop
rs_cp_2w_fpr14:
	mfc1	t3,$f14;	mfc1	t2,$f15;	b	load_rs_done
	nop
rs_cp_2w_fpr16:
	mfc1	t3,$f16;	mfc1	t2,$f17;	b	load_rs_done
	nop
rs_cp_2w_fpr18:
	mfc1	t3,$f18;	mfc1	t2,$f19;	b	load_rs_done
	nop
rs_cp_2w_fpr20:
	mfc1	t3,$f20;	mfc1	t2,$f21;	b	load_rs_done
	nop
rs_cp_2w_fpr22:
	mfc1	t3,$f22;	mfc1	t2,$f23;	b	load_rs_done
	nop
rs_cp_2w_fpr24:
	mfc1	t3,$f24;	mfc1	t2,$f25;	b	load_rs_done
	nop
rs_cp_2w_fpr26:
	mfc1	t3,$f26;	mfc1	t2,$f27;	b	load_rs_done
	nop
rs_cp_2w_fpr28:
	mfc1	t3,$f28;	mfc1	t2,$f29;	b	load_rs_done
	nop
rs_cp_2w_fpr30:
	mfc1	t3,$f30;	mfc1	t2,$f31;	b	load_rs_done
	nop
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
rs_cp_2w_fpr0:
	b	0f; dmfc1	t3,$f0
rs_cp_2w_fpr1:
	b	0f; dmfc1	t3,$f1
rs_cp_2w_fpr2:
	b	0f; dmfc1	t3,$f2
rs_cp_2w_fpr3:
	b	0f; dmfc1	t3,$f3
rs_cp_2w_fpr4:
	b	0f; dmfc1	t3,$f4
rs_cp_2w_fpr5:
	b	0f; dmfc1	t3,$f5
rs_cp_2w_fpr6:
	b	0f; dmfc1	t3,$f6
rs_cp_2w_fpr7:
	b	0f; dmfc1	t3,$f7
rs_cp_2w_fpr8:
	b	0f; dmfc1	t3,$f8
rs_cp_2w_fpr9:
	b	0f; dmfc1	t3,$f9
rs_cp_2w_fpr10:
	b	0f; dmfc1	t3,$f10
rs_cp_2w_fpr11:
	b	0f; dmfc1	t3,$f11
rs_cp_2w_fpr12:
	b	0f; dmfc1	t3,$f12
rs_cp_2w_fpr13:
	b	0f; dmfc1	t3,$f13
rs_cp_2w_fpr14:
	b	0f; dmfc1	t3,$f14
rs_cp_2w_fpr15:
	b	0f; dmfc1	t3,$f15
rs_cp_2w_fpr16:
	b	0f; dmfc1	t3,$f16
rs_cp_2w_fpr17:
	b	0f; dmfc1	t3,$f17
rs_cp_2w_fpr18:
	b	0f; dmfc1	t3,$f18
rs_cp_2w_fpr19:
	b	0f; dmfc1	t3,$f19
rs_cp_2w_fpr20:
	b	0f; dmfc1	t3,$f20
rs_cp_2w_fpr21:
	b	0f; dmfc1	t3,$f21
rs_cp_2w_fpr22:
	b	0f; dmfc1	t3,$f22
rs_cp_2w_fpr23:
	b	0f; dmfc1	t3,$f23
rs_cp_2w_fpr24:
	b	0f; dmfc1	t3,$f24
rs_cp_2w_fpr25:
	b	0f; dmfc1	t3,$f25
rs_cp_2w_fpr26:
	b	0f; dmfc1	t3,$f26
rs_cp_2w_fpr27:
	b	0f; dmfc1	t3,$f27
rs_cp_2w_fpr28:
	b	0f; dmfc1	t3,$f28
rs_cp_2w_fpr29:
	b	0f; dmfc1	t3,$f29
rs_cp_2w_fpr30:
	b	0f; dmfc1	t3,$f30
rs_cp_2w_fpr31:
	b	0f; dmfc1	t3,$f31
	
	.set	reorder
0:
	dsrl32	t2,t3,0
	srlv	t3,t3,zero
	b	load_rs_done	
	.set	noreorder
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */

	.set	reorder

/*
 * At this point the floating-point value for the specified FPR register
 * in the RS field (v1) will be loaded from the task control block (tcb)
 * of the current process for FMT specified (v0).  Also the floating-point
 * contol and status register is loaded into gp register a3.
 */
rs_tcb:
	lw	a3, FRAMEA3(softFp)(sp)		/* restore pFpContext */
	lw	a3, FPCSR(a3)			/* read fpcsr */
	and	t8,a3,CSR_RM_MASK		# isolate current Rounding Mode
	sw	t8,RM_OFFSET(sp)		#  and save on stack
	la	t9,rs_tcb_fmt_tab		# load table address
	addu	t9, v0, t9			# get entry address
	j	t9

	.set	noreorder
rs_tcb_fmt_tab:
	b	rs_tcb_s;	nop
	b	rs_tcb_d;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	b	rs_tcb_w;	nop
	b	rs_tcb_l;	nop
	.set	reorder

rs_tcb_s:
rs_tcb_w:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	sll	v1, v1, 2			/* 4 bytes per register */
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	sll	v1, v1, 3			/* 8 bytes per register */
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	lw	t2, FRAMEA3(softFp)(sp)		/* restore pFpContext */
	addu	v1, t2				/* create register address */
	lw	t2, (v1)			/* read correct register */
	b	load_rs_done
rs_tcb_d:
rs_tcb_l:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	sll	v1, v1, 2			/* 4 bytes per register */
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	sll	v1, v1, 3			/* 8 bytes per register */
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	lw	t2, FRAMEA3(softFp)(sp)		/* restore pFpContext */
	addu	v1, t2				/* create register address */
	lw	t2, (v1)			/* read correct register */
	lw	t3, 4(v1)			/* read next register */

/*
 * At this point the floating-point value for the specified FPR register
 * in the RS field has been loaded into GPR registers and the C1_SR has
 * been loaded into the GPR register (a3).  First the exception field is
 * cleared in the C1_SR.  What is done next is to decode the FUNC field.
 * If this is a dyadic operation then the floating-point value specified
 * by the FPR register in the RT field will be loaded into GPR registers
 * before the instruction is futher decoded.  If this is a monadic
 * instruction is decoded to be emulated.
 */
load_rs_done:
	HAZARD_CP_READ  /* many branches to this point have preceeding mfc0 */

#ifdef DEBUG
	sw	t2,_fp_rs
	sw	t3,_fp_rs+4
#endif	
	and	a3,~CSR_EXCEPT

	and	t8,a1,C1_FUNC_MASK
#ifdef DEBUG
	sw	t8, _fp_val
#endif
	ble	t8,C1_FUNC_DIV,load_rt
	bge	t8,C1_FUNC_1stCMP,load_rt

	bgt	t8,C1_FUNC_CVTL,illfpinst
	bge	t8,C1_FUNC_CVTS,conv
	bgt	t8,C1_FUNC_FLOORW,illfpinst
	bge	t8,C1_FUNC_ROUNDL,conv_round
	bgt	t8,C1_FUNC_NEG,illfpinst

	/* t8 is >= 4 and <= 7 */
	subu	t8,4
	la	t9,mon_func_tab	
	sll	t8,t8,3	
	addu	t9, t8, t9
	j	t9

	.set	noreorder
	nop
mon_func_tab:
	b	func_sqrt;	nop
	b	func_abs;	nop
	b	func_mov;	nop
	b	func_neg;	nop

	.set	reorder
func_sqrt:
	la	v1,sqrt_fmt_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
	nop
sqrt_fmt_tab:
	b	sqrt_s;	nop
	b	sqrt_d;	nop
	b	sqrt_e;	nop
	b	sqrt_q;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	.set	reorder
/*******************************************************************************
*
* sqrt_s - Square root single
*
*/
FUNC_LABEL(sqrt_s)
	/*
	 * Break out the operand into its fields (sign,exp,fraction) and
	 * handle a NaN operand by calling rs_breakout_s() .
	 */
	li	t9,C1_FMT_SINGLE*4
	move	v1,zero
	jal	rs_breakout_s

	/* Check for sqrt of infinity, and produce the correct action if so */
	bne	t1,SEXP_INF,4f	/* is RS an infinity? */
				/* RS is an infinity */
	beq	t0,zero,3f	/* check for -infinity */
	/*
	 * This is -infinity so this is an invalid operation for sqrt so set
	 * the invalid exception in the C1_SR (a3) and setup the result
	 * depending if the enable for the invalid exception is set.
	 */
1:	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,2f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
2:	li	t2,SQUIETNAN_LEAST
	move	v0,zero
	b	rd_1w
	/*
	 * This is +infinity so the result is just +infinity.
	 */
3:	sll	t2,t1,SEXP_SHIFT
	move	v0,zero
	b	rd_1w
4:	/* Check for the sqrt of zero and produce the correct action if so */
	bne	t1,zero,5f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,5f	/* then the high part of the fraction */
	/* Now RS is known to be zero so just return it */
	move	t2,t0		/* get the sign of the zero */
	move	v0,zero
	b	rd_1w
5:	/* Check for sqrt of a negitive number if so it is an invalid */
	bne	t0,zero,1b

	/*
	 * Now that all the NaN, infinity and zero and negitive cases have
	 * been taken care of what is left is a value that the sqrt can be
	 * taken.  So get the value into a format that can be used.  For
	 * normalized numbers set the implied one and remove the exponent
	 * bias.  For denormalized numbers convert to normalized numbers
	 * with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-SEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_s	/* normalize it */
	b	2f
1:	subu	t1,SEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:
	/*
	 * Now take the sqrt of the value.  Written by George Tayor.
	 *  t1		-- twos comp exponent
	 *  t2		-- 24-bit fraction
	 *  t8, t9	-- temps
	 *  v0		-- trial subtraction
	 *  t4		-- remainder
	 *  t6		-- 25-bit result
	 *  t8		-- sticky
	 */

	andi	t9, t1, 1		/*  last bit of unbiased exponent */
	sra	t1, 1			/*  divide exponent by 2 */
	addi	t1, -1			/*  subtract 1, deliver 25-bit result */
	beq	t9, zero, 1f

	sll	t2, t2, 1		/*  shift operand left by 1 */
					/*    if exponent was odd */

1:	li	t6, 1			/*  initialize answer msw */
	move	t4, zero		/*  initialize remainder msw */

	srl	t4, t2, 23		/*  shift operand left by 9 so that */
	sll	t2, t2, 9		/*    2 bits go into remainder */

	li	t8, 25			/*  set cycle counter */

2:	subu	v0, t4, t6		/*  trial subtraction */

	sll	t6, t6, 1		/*  shift answer left by 1 */
	li	t9, -4			/*  put 01 back in low order bits */
	and	t6, t9			/*    using 0xfffffffc mask */
	or	t6, 1

	bltz	v0, 3f			/*  branch on sign of trial subtract */
	ori	t6, 4			/*  set new bit of answer */
	sll	t4, v0, 2		/*  shift trial result left by 2 */
					/*    and put in remainder */
	b	4f

3:	sll	t4, t4, 2		/*  shift remainder left by 2 */

4:	srl	t9, t2, 30		/*  shift operand left by 2 */
	or	t4, t9
	sll	t2, t2, 2

	addi	t8, -1
	bne	t8, zero, 2b

	srl	t6, t6, 2		/*  shift answer right by 2 */
					/*    to eliminate extra bits */

	move	t8, t4			/*  form sticky bit */
	move	t2, t6

	b	norm_s

/*******************************************************************************
*
* sqrt_d - Square root double
*
*/
FUNC_LABEL(sqrt_d)
	/*
	 * Break out the operand into its fields (sign,exp,fraction) and
	 * handle a NaN operand by calling rs_breakout_d() .
	 */
	li	t9,C1_FMT_DOUBLE*4
	move	v1,zero
	jal	rs_breakout_d

	/* Check for sqrt of infinity, and produce the correct action if so */
	bne	t1,DEXP_INF,4f	/* is RS an infinity? */
				/* RS is an infinity */
	beq	t0,zero,3f	/* check for -infinity */
	/*
	 * This is -infinity so this is an invalid operation for sqrt so set
	 * the invalid exception in the C1_SR (a3) and setup the result
	 * depending if the enable for the invalid exception is set.
	 */
1:	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,2f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
2:	li	t2,DQUIETNAN_LESS
	li	t3,DQUIETNAN_LEAST
	move	v0,zero
	b	rd_2w
	/*
	 * This is +infinity so the result is just +infinity.
	 */
3:	sll	t2,t1,DEXP_SHIFT
	move	v0,zero
	b	rd_2w
4:	/* Check for the sqrt of zero and produce the correct action if so */
	bne	t1,zero,5f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,5f	/* then the high part of the fraction */
	bne	t3,zero,5f	/* then the low part of the fraction */
	/* Now RS is known to be zero so just return it */
	move	t2,t0		/* get the sign of the zero */
	move	v0,zero
	b	rd_2w
5:	/* Check for sqrt of a negitive number if so it is an invalid */
	bne	t0,zero,1b

	/*
	 * Now that all the NaN, infinity and zero and negitive cases have
	 * been taken care of what is left is a value that the sqrt can be
	 * taken.  So get the value into a format that can be used.  For
	 * normalized numbers set the implied one and remove the exponent
	 * bias.  For denormalized numbers convert to normalized numbers
	 * with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-DEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_d	/* normalize it */
	b	2f
1:	subu	t1,DEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:
	/*
	 * Now take the sqrt of the value.  Written by George Tayor.
	 *  t1		-- twos comp exponent
	 *  t2, t3	-- 53-bit fraction
	 *  t8, t9	-- temps
	 *  v0, v1	-- trial subtraction
	 *  t4, t5	-- remainder
	 *  t6, t7	-- 54-bit result
	 *  t8		-- sticky
	 */

	andi	t9, t1, 1		/*  last bit of unbiased exponent */
	sra	t1, 1			/*  divide exponent by 2 */
	addi	t1, -1			/*  subtract 1, deliver 54-bit result */
	beq	t9, zero, 1f

	sll	t2, t2, 1		/*  shift operand left by 1 */
	srl	t9, t3, 31 		/*    if exponent was odd */
	or	t2, t9
	sll	t3, t3, 1

1:	move	t6, zero		/*  initialize answer msw */
	li	t7, 1			/*  initialize answer lsw */
	move	t4, zero		/*  initialize remainder msw */
	move	t5, zero		/*  initialize remainder lsw */

	srl	t5, t2, 20		/*  shift operand left by 12 so that */
	sll	t2, t2, 12		/*    2 bits go into remainder */
	srl	t9, t3, 20
	or	t2, t9
	sll	t3, t3, 12

	li	t8, 54			/*  set cycle counter */

2:	sltu	t9, t5, t7		/*  trial subtraction */
	subu	v1, t5, t7
	subu	v0, t4, t6
	subu	v0, t9

	sll	t6, t6, 1		/*  shift answer left by 1 */
	srl	t9, t7, 31
	or	t6, t9
	sll	t7, t7, 1
	li	t9, -4			/*  put 01 back in low order bits */
	and	t7, t9			/*    using 0xfffffffc mask */
	or	t7, 1

	bltz	v0, 3f			/*  branch on sign of trial subtract */
	ori	t7, 4			/*  set new bit of answer */
	sll	t4, v0, 2		/*  shift trial result left by 2 */
	srl	t9, v1, 30		/*    and put in remainder */
	or	t4, t9
	sll	t5, v1, 2
	b	4f
3:
	sll	t4, t4, 2		/*  shift remainder left by 2 */
	srl	t9, t5, 30
	or	t4, t9
	sll	t5, t5, 2

4:	srl	t9, t2, 30		/*  shift operand left by 2 */
	or	t5, t9
	sll	t2, t2, 2
	srl	t9, t3, 30
	or	t2, t9
	sll	t3, t3, 2

	addi	t8, -1
	bne	t8, zero, 2b

	srl	t7, t7, 2		/*  shift answer right by 2 */
	sll	t9, t6, 30		/*    to eliminate extra bits */
	or	t7, t9
	srl	t6, t6, 2

	or	t8, t4, t5		/*  form sticky bit */
 	move	t2, t6
 	move	t3, t7

	b	norm_d

sqrt_e:
sqrt_q:
	b	illfpinst

func_abs:
	la	v1,abs_fmt_tab
	addu	v1, v0, v1
	j	v1

	.set 	noreorder
abs_fmt_tab:
	b	abs_s;	nop
	b	abs_d;	nop
	b	abs_e;	nop
	b	abs_q;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	.set	reorder
/*******************************************************************************
*
* abs_s - Absolute value single
*
*/
FUNC_LABEL(abs_s)
	move	t6,t2		/* save the unmodified word */
	/*
	 * Handle a NaN operand by calling rs_breakout_s().
	 * The broken out results are discarded.
	 */
	li	t9,C1_FMT_SINGLE*4
	jal	rs_breakout_s
	/*
	 * Now just clear the signbit after restoring the unmodified word.
	 */
	move	t2,t6
	and	t2,~SIGNBIT
	move	v0,zero
	b	rd_1w

/*******************************************************************************
*
* abs_d - Absolute value double
*
*/
FUNC_LABEL(abs_d)
	move	t6,t2		/* save the unmodified word */
	/*
	 * Handle a NaN operand by calling rs_breakout_d().
	 * The broken out results are discarded.
	 */
	li	t9,C1_FMT_DOUBLE*4
	jal	rs_breakout_d
	/*
	 * Now just clear the signbit after restoring the unmodified word.
	 */
	move	t2,t6
	and	t2,~SIGNBIT
	move	v0,zero
	b	rd_2w

abs_e:
abs_q:
	b	illfpinst

func_mov:
	la	v1,mov_fmt_tab
	addu	v1, v0, v1
	j	v1
	
	.set	noreorder
mov_fmt_tab:
	b	mov_s;	nop
	b	mov_d;	nop
	b	mov_q;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set reorder

/*******************************************************************************
*
* mov_s - Move single
*
*/
FUNC_LABEL(mov_s)
	move	v0,zero
	b	rd_1w

/*******************************************************************************
*
* mov_d - Move double
*
*/
FUNC_LABEL(mov_d)
	move	v0,zero
	b	rd_2w

mov_e:
mov_q:
	b	illfpinst

func_neg:
	la	v1,neg_fmt_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
neg_fmt_tab:
	b	neg_s;	nop
	b	neg_d;	nop
	b	neg_e;	nop
	b	neg_q;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder

/*******************************************************************************
*
* neg_s - Negation single
*
*/
FUNC_LABEL(neg_s)
	move	t6,t2		/* save the unmodified word */
	/*
	 * Handle a NaN operand by calling rs_breakout_s().
	 * The broken out results are discarded.
	 */
	li	t9,C1_FMT_SINGLE*4
	jal	rs_breakout_s
	/*
	 * Now just negate the operand after restoring the unmodified word.
	 */
	move	t2,t6
	.set	noat
	li	AT,SIGNBIT
	xor	t2,AT
	.set	at
	move	v0,zero
	b	rd_1w

/*******************************************************************************
*
* neg_d - Negation double
*
*/
FUNC_LABEL(neg_d)
	move	t6,t2		/* save the unmodified word */
	/*
	 * Handle a NaN operand by calling rs_breakout_d().
	 * The broken out results are discarded.
	 */
	li	t9,C1_FMT_DOUBLE*4
	jal	rs_breakout_d
	/*
	 * Now just negate the operand after restoring the unmodified word.
	 */
	move	t2,t6
	.set	noat
	li	AT,SIGNBIT
	xor	t2,AT
	.set	at
	move	v0,zero
	b	rd_2w

neg_e:
neg_q:
	b	illfpinst

/*******************************************************************************
*
* load_rt -
*
* Load the floating point value from the register specified by the
* RT field into gp registers.  The gp registers which are used for
* the value specified by the RT feild is dependent on its format
* as follows:
* 	single		t6
*	double		t6,t7
*	extended	t6,t7,s6,s7	(where t7 is really zero)
*	quad		t6,t7,s6,s7
*/
load_rt:
	srl	v1,a1,RT_SHIFT		/* get the RT field */
	and	v1,RT_MASK
#ifdef DEBUG
	sw	v1,_fp_rt_reg
#endif

	/*
	 * If a2 (int or exception) is non-zero then the floating-point values
	 * are loaded from the coprocessor else they are loaded from the tcb.
	 */
	beq	a2,zero,rt_tcb

	/*
	 * At this point the floating-point value for the specified FPR register
	 * in the RT field will loaded from the coprocessor registers for the
	 * FMT specified (v0).
	 */
				/* setup to branch to the code to load */
	la	t9, cp_rt_fmt_tab
	addu	t9, v0, t9
	j	t9			/*  cp for the specified format. */

	.set	noreorder
cp_rt_fmt_tab:
	b	rt_cp_1w;	nop
	b	rt_cp_2w;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	b	rt_cp_1w;	nop
	b	rt_cp_2w;	nop
	.set	reorder
/*******************************************************************************
*
* rt_cp_1w -
*
* Load the one word from the coprocessor for the FPR register specified by
* the RT (v1) field into GPR register t6.
*/
rt_cp_1w:
	sll	v1, v1, 3		/* 8 bytes per entry */
	la	t9,rt_cp_1w_tab
	addu	v1, t9, v1
	j	v1

	.set	noreorder
rt_cp_1w_tab:
	b	rt_cp_1w_fpr0; nop
	b	rt_cp_1w_fpr1; nop
	b	rt_cp_1w_fpr2; nop
	b	rt_cp_1w_fpr3; nop
	b	rt_cp_1w_fpr4; nop
	b	rt_cp_1w_fpr5; nop
	b	rt_cp_1w_fpr6; nop
	b	rt_cp_1w_fpr7; nop
	b	rt_cp_1w_fpr8; nop
	b	rt_cp_1w_fpr9; nop
	b	rt_cp_1w_fpr10; nop
	b	rt_cp_1w_fpr11; nop
	b	rt_cp_1w_fpr12; nop
	b	rt_cp_1w_fpr13; nop
	b	rt_cp_1w_fpr14; nop
	b	rt_cp_1w_fpr15; nop
	b	rt_cp_1w_fpr16; nop
	b	rt_cp_1w_fpr17; nop
	b	rt_cp_1w_fpr18; nop
	b	rt_cp_1w_fpr19; nop
	b	rt_cp_1w_fpr20; nop
	b	rt_cp_1w_fpr21; nop
	b	rt_cp_1w_fpr22; nop
	b	rt_cp_1w_fpr23; nop
	b	rt_cp_1w_fpr24; nop
	b	rt_cp_1w_fpr25; nop
	b	rt_cp_1w_fpr26; nop
	b	rt_cp_1w_fpr27; nop
	b	rt_cp_1w_fpr28; nop
	b	rt_cp_1w_fpr29; nop
	b	rt_cp_1w_fpr30; nop
	b	rt_cp_1w_fpr31; nop
	.set	reorder

	.set 	noreorder
rt_cp_1w_fpr0:
	mfc1	t6,$f0;		b	load_rt_done; 	nop
rt_cp_1w_fpr1:
	mfc1	t6,$f1;		b	load_rt_done; 	nop
rt_cp_1w_fpr2:
	mfc1	t6,$f2;		b	load_rt_done; 	nop
rt_cp_1w_fpr3:
	mfc1	t6,$f3;		b	load_rt_done; 	nop
rt_cp_1w_fpr4:
	mfc1	t6,$f4;		b	load_rt_done; 	nop
rt_cp_1w_fpr5:
	mfc1	t6,$f5;		b	load_rt_done; 	nop
rt_cp_1w_fpr6:
	mfc1	t6,$f6;		b	load_rt_done; 	nop
rt_cp_1w_fpr7:
	mfc1	t6,$f7;		b	load_rt_done; 	nop
rt_cp_1w_fpr8:
	mfc1	t6,$f8;		b	load_rt_done; 	nop
rt_cp_1w_fpr9:
	mfc1	t6,$f9;		b	load_rt_done; 	nop
rt_cp_1w_fpr10:
	mfc1	t6,$f10;	b	load_rt_done; 	nop
rt_cp_1w_fpr11:
	mfc1	t6,$f11;	b	load_rt_done; 	nop
rt_cp_1w_fpr12:
	mfc1	t6,$f12;	b	load_rt_done; 	nop
rt_cp_1w_fpr13:
	mfc1	t6,$f13;	b	load_rt_done; 	nop
rt_cp_1w_fpr14:
	mfc1	t6,$f14;	b	load_rt_done; 	nop
rt_cp_1w_fpr15:
	mfc1	t6,$f15;	b	load_rt_done; 	nop
rt_cp_1w_fpr16:
	mfc1	t6,$f16;	b	load_rt_done; 	nop
rt_cp_1w_fpr17:
	mfc1	t6,$f17;	b	load_rt_done; 	nop
rt_cp_1w_fpr18:
	mfc1	t6,$f18;	b	load_rt_done; 	nop
rt_cp_1w_fpr19:
	mfc1	t6,$f19;	b	load_rt_done; 	nop
rt_cp_1w_fpr20:
	mfc1	t6,$f20;	b	load_rt_done; 	nop
rt_cp_1w_fpr21:
	mfc1	t6,$f21;	b	load_rt_done; 	nop
rt_cp_1w_fpr22:
	mfc1	t6,$f22;	b	load_rt_done; 	nop
rt_cp_1w_fpr23:
	mfc1	t6,$f23;	b	load_rt_done; 	nop
rt_cp_1w_fpr24:
	mfc1	t6,$f24;	b	load_rt_done; 	nop
rt_cp_1w_fpr25:
	mfc1	t6,$f25;	b	load_rt_done; 	nop
rt_cp_1w_fpr26:
	mfc1	t6,$f26;	b	load_rt_done; 	nop
rt_cp_1w_fpr27:
	mfc1	t6,$f27;	b	load_rt_done; 	nop
rt_cp_1w_fpr28:
	mfc1	t6,$f28;	b	load_rt_done; 	nop
rt_cp_1w_fpr29:
	mfc1	t6,$f29;	b	load_rt_done; 	nop
rt_cp_1w_fpr30:
	mfc1	t6,$f30;	b	load_rt_done; 	nop
rt_cp_1w_fpr31:
	mfc1	t6,$f31;	b	load_rt_done; 	nop
	.set	reorder

/*
 * Load the two words from the coprocessor for the FPR register specified by
 * the RT (v1) field into GPR registers t6,t7.
 */
rt_cp_2w:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	srl	v1, v1, 1		/* only allow even numbered registers */
#endif	  /* _WRS_FP_REGISTER_SIZE */
	sll	v1, v1, 3		/* 8 bytes per entry */
	la	t9,rt_cp_2w_tab	
	addu	v1, t9, v1
	j	v1

	.set	noreorder
rt_cp_2w_tab:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	b	rt_cp_2w_fpr0;	nop
	b	rt_cp_2w_fpr2;	nop
	b	rt_cp_2w_fpr4;	nop
	b	rt_cp_2w_fpr6;	nop
	b	rt_cp_2w_fpr8;	nop
	b	rt_cp_2w_fpr10;	nop
	b	rt_cp_2w_fpr12;	nop
	b	rt_cp_2w_fpr14;	nop
	b	rt_cp_2w_fpr16;	nop
	b	rt_cp_2w_fpr18;	nop
	b	rt_cp_2w_fpr20;	nop
	b	rt_cp_2w_fpr22;	nop
	b	rt_cp_2w_fpr24;	nop
	b	rt_cp_2w_fpr26;	nop
	b	rt_cp_2w_fpr28;	nop
	b	rt_cp_2w_fpr30;	nop
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	b	rt_cp_2w_fpr0; nop
	b	rt_cp_2w_fpr1; nop
	b	rt_cp_2w_fpr2; nop
	b	rt_cp_2w_fpr3; nop
	b	rt_cp_2w_fpr4; nop
	b	rt_cp_2w_fpr5; nop
	b	rt_cp_2w_fpr6; nop
	b	rt_cp_2w_fpr7; nop
	b	rt_cp_2w_fpr8; nop
	b	rt_cp_2w_fpr9; nop
	b	rt_cp_2w_fpr10; nop
	b	rt_cp_2w_fpr11; nop
	b	rt_cp_2w_fpr12; nop
	b	rt_cp_2w_fpr13; nop
	b	rt_cp_2w_fpr14; nop
	b	rt_cp_2w_fpr15; nop
	b	rt_cp_2w_fpr16; nop
	b	rt_cp_2w_fpr17; nop
	b	rt_cp_2w_fpr18; nop
	b	rt_cp_2w_fpr19; nop
	b	rt_cp_2w_fpr20; nop
	b	rt_cp_2w_fpr21; nop
	b	rt_cp_2w_fpr22; nop
	b	rt_cp_2w_fpr23; nop
	b	rt_cp_2w_fpr24; nop
	b	rt_cp_2w_fpr25; nop
	b	rt_cp_2w_fpr26; nop
	b	rt_cp_2w_fpr27; nop
	b	rt_cp_2w_fpr28; nop
	b	rt_cp_2w_fpr29; nop
	b	rt_cp_2w_fpr30; nop
	b	rt_cp_2w_fpr31; nop
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	
#if	  (_WRS_FP_REGISTER_SIZE == 4)
rt_cp_2w_fpr0:
	mfc1	t7,$f0;		mfc1	t6,$f1;		b	load_rt_done
	nop
rt_cp_2w_fpr2:
	mfc1	t7,$f2;		mfc1	t6,$f3;		b	load_rt_done
	nop
rt_cp_2w_fpr4:
	mfc1	t7,$f4;		mfc1	t6,$f5;		b	load_rt_done
	nop
rt_cp_2w_fpr6:
	mfc1	t7,$f6;		mfc1	t6,$f7;		b	load_rt_done
	nop
rt_cp_2w_fpr8:
	mfc1	t7,$f8;		mfc1	t6,$f9;		b	load_rt_done
	nop
rt_cp_2w_fpr10:
	mfc1	t7,$f10;	mfc1	t6,$f11;	b	load_rt_done
	nop
rt_cp_2w_fpr12:
	mfc1	t7,$f12;	mfc1	t6,$f13;	b	load_rt_done
	nop
rt_cp_2w_fpr14:
	mfc1	t7,$f14;	mfc1	t6,$f15;	b	load_rt_done
	nop
rt_cp_2w_fpr16:
	mfc1	t7,$f16;	mfc1	t6,$f17;	b	load_rt_done
	nop
rt_cp_2w_fpr18:
	mfc1	t7,$f18;	mfc1	t6,$f19;	b	load_rt_done
	nop
rt_cp_2w_fpr20:
	mfc1	t7,$f20;	mfc1	t6,$f21;	b	load_rt_done
	nop
rt_cp_2w_fpr22:
	mfc1	t7,$f22;	mfc1	t6,$f23;	b	load_rt_done
	nop
rt_cp_2w_fpr24:
	mfc1	t7,$f24;	mfc1	t6,$f25;	b	load_rt_done
	nop
rt_cp_2w_fpr26:
	mfc1	t7,$f26;	mfc1	t6,$f27;	b	load_rt_done
	nop
rt_cp_2w_fpr28:
	mfc1	t7,$f28;	mfc1	t6,$f29;	b	load_rt_done
	nop
rt_cp_2w_fpr30:
	mfc1	t7,$f30;	mfc1	t6,$f31;	b	load_rt_done
	nop
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
rt_cp_2w_fpr0:
	b	0f; dmfc1	t7,$f0
rt_cp_2w_fpr1:
	b	0f; dmfc1	t7,$f1
rt_cp_2w_fpr2:
	b	0f; dmfc1	t7,$f2
rt_cp_2w_fpr3:
	b	0f; dmfc1	t7,$f3
rt_cp_2w_fpr4:
	b	0f; dmfc1	t7,$f4
rt_cp_2w_fpr5:
	b	0f; dmfc1	t7,$f5
rt_cp_2w_fpr6:
	b	0f; dmfc1	t7,$f6
rt_cp_2w_fpr7:
	b	0f; dmfc1	t7,$f7
rt_cp_2w_fpr8:
	b	0f; dmfc1	t7,$f8
rt_cp_2w_fpr9:
	b	0f; dmfc1	t7,$f9
rt_cp_2w_fpr10:
	b	0f; dmfc1	t7,$f10
rt_cp_2w_fpr11:
	b	0f; dmfc1	t7,$f11
rt_cp_2w_fpr12:
	b	0f; dmfc1	t7,$f12
rt_cp_2w_fpr13:
	b	0f; dmfc1	t7,$f13
rt_cp_2w_fpr14:
	b	0f; dmfc1	t7,$f14
rt_cp_2w_fpr15:
	b	0f; dmfc1	t7,$f15
rt_cp_2w_fpr16:
	b	0f; dmfc1	t7,$f16
rt_cp_2w_fpr17:
	b	0f; dmfc1	t7,$f17
rt_cp_2w_fpr18:
	b	0f; dmfc1	t7,$f18
rt_cp_2w_fpr19:
	b	0f; dmfc1	t7,$f19
rt_cp_2w_fpr20:
	b	0f; dmfc1	t7,$f20
rt_cp_2w_fpr21:
	b	0f; dmfc1	t7,$f21
rt_cp_2w_fpr22:
	b	0f; dmfc1	t7,$f22
rt_cp_2w_fpr23:
	b	0f; dmfc1	t7,$f23
rt_cp_2w_fpr24:
	b	0f; dmfc1	t7,$f24
rt_cp_2w_fpr25:
	b	0f; dmfc1	t7,$f25
rt_cp_2w_fpr26:
	b	0f; dmfc1	t7,$f26
rt_cp_2w_fpr27:
	b	0f; dmfc1	t7,$f27
rt_cp_2w_fpr28:
	b	0f; dmfc1	t7,$f28
rt_cp_2w_fpr29:
	b	0f; dmfc1	t7,$f29
rt_cp_2w_fpr30:
	b	0f; dmfc1	t7,$f30
rt_cp_2w_fpr31:
	b	0f; dmfc1	t7,$f31

	.set	reorder
0:
	dsrl32	t6,t7,0
	srlv	t7,t7,zero
	b	load_rt_done	
	.set	noreorder
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	.set	reorder

/*
 * At this point the floating-point value for the specified FPR register
 * in the RT field (v1) will loaded from the task control block (tcb)
 * of the current process for FMT specified (v0).
 */
rt_tcb:
	la	t9,rt_tcb_fmt_tab
	addu	t9, v0, t9
	j	t9

	.set	noreorder
rt_tcb_fmt_tab:
	b	rt_tcb_s;	nop
	b	rt_tcb_d;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	b	rt_tcb_w;	nop
	b	rt_tcb_l;	nop
	.set	reorder
	
rt_tcb_s:
rt_tcb_w:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	sll	v1, v1, 2			/* 4 bytes per register */
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	sll	v1, v1, 3			/* 8 bytes per register */
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	lw	t2, FRAMEA3(softFp)(sp)		/* restore pFpContext */
	addu	v1, t2				/* create register address */
	lw	t6, (v1)			/* read correct register */
	b	load_rt_done
rt_tcb_d:
rt_tcb_l:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	sll	v1, v1, 2			/* 4 bytes per register */
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	sll	v1, v1, 3			/* 8 bytes per register */
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	lw	t2, FRAMEA3(softFp)(sp)		/* restore pFpContext */
	addu	v1, t2				/* create register address */
	lw	t6, (v1)			/* read correct register */
	lw	t7, 4(v1)			/* read next register */

/*
 * At this point the both the floating-point value for the specified FPR
 * registers of the RS and RT fields have been loaded into GPR registers.
 * What is done next is to decode the FUNC field (t8) for the dyadic operations.
 */
load_rt_done:
	HAZARD_CP_READ  /* many branches to this point have preceeding mfc1 */
#ifdef DEBUG
	sw	t8, _fp_val
	sw	t6,_fp_rt
	sw	t7,_fp_rt+4
#endif	
	bge	t8,C1_FUNC_1stCMP,comp

	sll	t8,t8,3
	la	t9,dy_func_tab
	addu	t9, t8, t9
	j	t9

	.set	noreorder
dy_func_tab:
	b	func_add;	nop
	b	func_add;	nop
	b	func_mul;	nop
	b	func_div;	nop

	.set	reorder
/*
 * Both add and subtract functions come here.  The difference is that
 * the FUNC field (t8) is zero for adds.
 */
func_add:
	la	v1,add_fmt_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
add_fmt_tab:
	b	add_s;	nop
	b	add_d;	nop
	b	add_e;	nop
	b	add_q;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder

/*******************************************************************************
*
* add_s -
*
* Add (and subtract) single RD = RS + RT (or RD = RS - RT).  Again the FUNC
* field (t8) is zero for adds.
*/
	.globl	GTEXT(add_s)
FUNC_LABEL(add_s)
	/*
	 * Break out the operands into their fields (sign,exp,fraction) and
	 * handle NaN operands by calling {rs,rt}breakout_s() .
	 */
	li	t9,C1_FMT_SINGLE*4
	li	v1,1
	jal	rs_breakout_s
	jal	rt_breakout_s

	beq	t8,zero,1f	/* - if doing a subtract then negate RT */
	lui	v0,(SIGNBIT>>16)&0xffff
	xor	t4,v0
1:
	/* Check for addition of infinities, and produce the correct action if so */
	bne	t1,SEXP_INF,5f	/* is RS an infinity? */
				/* RS is an infinity */
	bne	t5,SEXP_INF,4f	/* is RT also an infinity? */
				/* RT is an infinity */
	beq	t0,t4,3f	/* do the infinities have the same sign? */

	/*
	 * The infinities do NOT have the same sign thus this is an invalid
	 * operation for addition so set the invalid exception in the C1_SR
	 * (a3) and setup the result depending if the enable for the invalid
	 * exception is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,2f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
2:	li	t2,SQUIETNAN_LEAST
	move	v0,zero
	b	rd_1w

	/*
	 * This is just a normal infinity + infinity so the result is just
	 * an infinity with the sign of the operands.
	 */
3:	move	t2,t0
	sll	t1,t1,SEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_1w

	/*
	 * This is infinity + x , where RS is the infinity so the result is
	 * just RS (the infinity).
	 */
4:	move	t2,t0
	sll	t1,t1,SEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_1w

	/*
	 * Check RT for an infinity value.  At this point it is know that RS
	 * is not an infinity.  If RT is an infinity it will be the result.
	 */
5:	bne	t5,SEXP_INF,6f
	move	t2,t4
	sll	t5,t5,SEXP_SHIFT
	or	t2,t5
	move	v0,zero
	b	rd_1w
6:
	/* Check for the addition of zeros and produce the correct action if so */
	bne	t1,zero,3f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,3f	/* then the fraction */
				/* Now RS is known to be zero */

	bne	t5,zero,2f	/* check RT for a zero value (first the exp) */
	bne	t6,zero,2f	/* then the fraction */
	/*
	 * Now RS and RT are known to be zeroes so set the correct result
	 * according to the rounding mode (in the C1_SR) and exit.
	 */
	and	v0,a3,CSR_RM_MASK	/* get the rounding mode */
	bne	v0,CSR_RM_RMI,1f	/* check for round to - infinity */
	or	t2,t0,t4		/* set the result and exit, for round to */
	move	v0,zero			/*  - infinity the zero result is the */
	b	rd_1w			/*  and of the operands signs */

1:	and	t2,t0,t4		/* set the result and exit, for other */
	move	v0,zero			/*  rounding modes the zero result is the */
	b	rd_1w			/*  or of the operands signs */

	/* RS is a zero and RT is non-zero so the result is RT */
2:	move	t2,t4
	sll	t5,t5,SEXP_SHIFT
	or	t2,t5
	or	t2,t6
	move	v0,zero
	b	rd_1w

	/* RS is now known not to be zero so check RT for a zero value. */
3:	bne	t5,zero,4f	/* check RT for a zero value (first the exp) */
	bne	t6,zero,4f	/* then the fraction */
	or	t2,t0		/* RT is a zero so the result is RS */
	sll	t1,t1,SEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_1w
4:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be added.  So get all values
	 * into a format that can be added.  For normalized numbers set the
	 * implied one and remove the exponent bias.  For denormalized numbers
	 * convert to normalized numbers with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-SEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_s	/* normalize it */
	b	2f
1:	subu	t1,SEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:	bne	t5,zero,3f	/* check for RT being denormalized */
	li	t5,-SEXP_BIAS+1	/* set denorms exponent */
	jal	rt_renorm_s	/* normalize it */
	b	4f
3:	subu	t5,SEXP_BIAS	/* - if RT is not denormalized then remove the */
	or	t6,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
4:
	/*
	 * If the two values are the same except the sign return the correct
	 * zero according to the rounding mode.
	 */
	beq	t0,t4,2f		/* - if the signs are the same continue */
	bne	t1,t5,2f		/* - if the exps are not the same continue */
	bne	t2,t6,2f		/* - if the fractions are not the */
					/*  same continue */

	and	v0,a3,CSR_RM_MASK	/* get the rounding mode */
	bne	v0,CSR_RM_RMI,1f	/* check for round to - infinity */
	or	t2,t0,t4		/* set the result and exit, for round to */
					/*  - infinity the zero result is the */
	move	v0,zero			/*  and of the operands signs */
	b	rd_1w

1:	and	t2,t0,t4		/* set the result and exit, for other */
					/*  rounding modes the zero result is the */
	move	v0,zero			/*  or of the operands signs */
	b	rd_1w
2:
	subu	v1,t1,t5		/* find the difference of the exponents */
	move	v0,v1			/*  in (v1) and the absolute value of */
	bge	v1,zero,1f		/*  the difference in (v0) */
	negu	v0
1:
	ble	v0,SFRAC_BITS+2,2f	/* is the difference is greater than the */
					/*  number of bits of precision? */
	li	t8,STKBIT		/* set the sticky register */
	bge	v1,zero,1f
	/* result is RT added with a sticky bit (for RS) */
	move	t1,t5			/* result exponent will be RTs exponent */
	move	t2,zero
	b	4f
1:	/* the result is RS added with a sticky bit (for RT) */
	move	t6,zero
	b	4f
2:	move	t8,zero			/* clear the sticky register */
	/*
	 * If the exponent difference is greater than zero shift the smaller
	 * value right by the exponent difference to align the binary point
	 * before the addition.  Also select the exponent of the result to
	 * be the largest exponent of the two values.  The result exponent is
	 * left in (t1) so only if RS is to be shifted does RTs exponent
	 * need to be moved into (t1).
	 */
	beq	v0,zero,4f		/* - if the exp diff is zero then no shift */
	bgt	v1,zero,3f		/* - if the exp diff > 0 shift RT */
	move	t1,t5			/* result exponent will be RTs exponent */
	/* Shift the fraction value of RS by < 32 (the right shift amount (v0)) */
	negu	v1,v0			/* the left shift amount which is 32 */
	addu	v1,32			/*  minus right shift amount (v1) */
	srlv	t8,t8,v0		/* shift the sticky register */
	sllv	t9,t2,v1
	or	t8,t9
	srlv	t2,t2,v0		/* shift the fraction */
	b	4f
3:	/* Shift the fraction value of RT by < 32 (the right shift amount (v0)) */
	negu	v1,v0			/* the left shift amount which is 32 */
	addu	v1,32			/*  minus right shift amount (v1) */
	srlv	t8,t8,v0		/* shift the sticky register */
	sllv	t9,t6,v1
	or	t8,t9
	srlv	t6,t6,v0		/* shift the fraction */
4:
	/*
	 * Now if the signs are the same add the two fractions, else if the
	 * signs are different then subtract the smaller fraction from the
	 * larger fraction and the results sign will be the sign of the
	 * larger fraction.
	 */
	bne	t0,t4,1f		/* - if the signs not the same subtract */
	/* Add the fractions */
	addu	t2,t6			/* add fraction words */
	b	norm_s
1:
	/*
	 * Subtract the smaller fraction from the larger fraction and set the
	 * sign of the result to the sign of the larger fraction.
	 */
	blt	t2,t6,3f		/* determine the smaller fraction */
					/*  Note the case where they were equal */
					/*  has already been taken care of */
1:	/*
	 * RT is smaller so subtract RT from RS and use RSs sign as the sign
	 * of the result (the sign is already in the correct place (t0)).
	 */
	sltu	t9,zero,t8		/* set barrow out for sticky register */
	subu	t8,zero,t8
	/* subtract least signifiant fraction words */
	bne	t9,zero,2f		/* see if there is a barrow in */
	/* no barrow in to be subtracted out */
	subu	t2,t2,t6		/* subtract fractions */
	b	norm_s
2:	/* barrow in to be subtracted out */
	subu	t2,t2,t6		/* subtract least fractions */
	subu	t2,1			/* subtract barrow in */
	b	norm_s
3:
	/*
	 * RS is smaller so subtract RS from RT and use RTs sign as the sign
	 * of the result.
	 */
	move	t0,t4			/* use RTs sign as the sign of result */
	sltu	t9,zero,t8		/* set barrow out for sticky register */
	subu	t8,zero,t8
	/* subtract least signifiant fraction words */
	bne	t9,zero,1f		/* see if there is a barrow in */
	/* no barrow in to be subtracted out */
	subu	t2,t6,t2		/* subtract least fractions */
	b	norm_s
1:	/* barrow in to be subtracted out */
	subu	t2,t6,t2		/* subtract least fractions */
	subu	t2,1			/* subtract barrow in */
	b	norm_s

/*******************************************************************************
*
* add_d -
*
* Add (and subtract) double RD = RS + RT (or RD = RS - RT).  Again the FUNC
* field (t8) is zero for adds.
*/
	.globl	GTEXT(add_d)
FUNC_LABEL(add_d)
	/*
	 * Break out the operands into their fields (sign,exp,fraction) and
	 * handle NaN operands by calling {rs,rt}breakout_d() .
	 */
	li	t9,C1_FMT_DOUBLE*4
	li	v1,1
	jal	rs_breakout_d
	jal	rt_breakout_d

	beq	t8,zero,1f	/* - if doing a subtract then negate RT */
	lui	v0,(SIGNBIT>>16)&0xffff
	xor	t4,v0
1:
	/* Check for addition of infinities, and produce the correct action if so */
	bne	t1,DEXP_INF,5f	/* is RS an infinity? */
				/* RS is an infinity */
	bne	t5,DEXP_INF,4f	/* is RT also an infinity? */
				/* RT is an infinity */
	beq	t0,t4,3f	/* do the infinities have the same sign? */

	/*
	 * The infinities do NOT have the same sign thus this is an invalid
	 * operation for addition so set the invalid exception in the C1_SR
	 * (a3) and setup the result depending if the enable for the invalid
	 * exception is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,2f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
2:	li	t2,DQUIETNAN_LESS
	li	t3,DQUIETNAN_LEAST
	move	v0,zero
	b	rd_2w

	/*
	 * This is just a normal infinity + infinity so the result is just
	 * an infinity with the sign of the operands.
	 */
3:	move	t2,t0
	sll	t1,t1,DEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_2w

	/*
	 * This is infinity + x , where RS is the infinity so the result is
	 * just RS (the infinity).
	 */
4:	move	t2,t0
	sll	t1,t1,DEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_2w

	/*
	 * Check RT for an infinity value.  At this point it is know that RS
	 * is not an infinity.  If RT is an infinity it will be the result.
	 */
5:	bne	t5,DEXP_INF,6f
	move	t2,t4
	sll	t5,t5,DEXP_SHIFT
	or	t2,t5
	move	t3,t7
	move	v0,zero
	b	rd_2w
6:
	/* Check for the addition of zeros and produce the correct action if so */
	bne	t1,zero,3f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,3f	/* then the high part of the fraction */
	bne	t3,zero,3f	/* then the low part of the fraction */
				/* Now RS is known to be zero */

	bne	t5,zero,2f	/* check RT for a zero value (first the exp) */
	bne	t6,zero,2f	/* then the high part of the fraction */
	bne	t7,zero,2f	/* then the low part of the fraction */
	/*
	 * Now RS and RT are known to be zeroes so set the correct result
	 * according to the rounding mode (in the C1_SR) and exit.
	 */
	and	v0,a3,CSR_RM_MASK	/* get the rounding mode */
	bne	v0,CSR_RM_RMI,1f	/* check for round to - infinity */
	or	t2,t0,t4		/* set the result and exit, for round to */
	move	v0,zero			/*  - infinity the zero result is the */
	b	rd_2w			/*  and of the operands signs */

1:	and	t2,t0,t4		/* set the result and exit, for other */
	move	v0,zero			/*  rounding modes the zero result is the */
	b	rd_2w			/*  or of the operands signs */

	/* RS is a zero and RT is non-zero so the result is RT */
2:	move	t2,t4
	sll	t5,t5,DEXP_SHIFT
	or	t2,t5
	or	t2,t6
	move	t3,t7
	move	v0,zero
	b	rd_2w

	/* RS is now known not to be zero so check RT for a zero value. */
3:	bne	t5,zero,4f	/* check RT for a zero value (first the exp) */
	bne	t6,zero,4f	/* then the high part of the fraction */
	bne	t7,zero,4f	/* then the low part of the fraction */
	or	t2,t0		/* RT is a zero so the result is RS */
	sll	t1,t1,DEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_2w
4:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be added.  So get all values
	 * into a format that can be added.  For normalized numbers set the
	 * implied one and remove the exponent bias.  For denormalized numbers
	 * convert to normalized numbers with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-DEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_d	/* normalize it */
	b	2f
1:	subu	t1,DEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:	bne	t5,zero,3f	/* check for RT being denormalized */
	li	t5,-DEXP_BIAS+1	/* set denorms exponent */
	jal	rt_renorm_d	/* normalize it */
	b	4f
3:	subu	t5,DEXP_BIAS	/* - if RT is not denormalized then remove the */
	or	t6,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
4:
	/*
	 * If the two values are the same except the sign return the correct
	 * zero according to the rounding mode.
	 */
	beq	t0,t4,2f		/* - if the signs are the same continue */
	bne	t1,t5,2f		/* - if the exps are not the same continue */
	bne	t2,t6,2f		/* - if the fractions are not the */
	bne	t3,t7,2f		/*  same continue */

	and	v0,a3,CSR_RM_MASK	/* get the rounding mode */
	bne	v0,CSR_RM_RMI,1f	/* check for round to - infinity */
	or	t2,t0,t4		/* set the result and exit, for round to */
	move	t3,zero			/*  - infinity the zero result is the */
	move	v0,zero			/*  and of the operands signs */
	b	rd_2w

1:	and	t2,t0,t4		/* set the result and exit, for other */
	move	t3,zero			/*  rounding modes the zero result is the */
	move	v0,zero			/*  or of the operands signs */
	b	rd_2w
2:
	subu	v1,t1,t5		/* find the difference of the exponents */
	move	v0,v1			/*  in (v1) and the absolute value of */
	bge	v1,zero,1f		/*  the difference in (v0) */
	negu	v0
1:
	ble	v0,DFRAC_BITS+2,3f	/* is the difference is greater than the */
					/*  number of bits of precision */
	li	t8,STKBIT		/* set the sticky register */
	bge	v1,zero,2f
	/* result is RT with a STKBIT added (for RS) */
	move	t1,t5			/* result exponent will be RTs exponent */
	move	t2,zero
	move	t3,zero
	b	9f
2:	/* the result is RS with a STKBIT added (for RT) */
	move	t6,zero
	move	t7,zero
	b	9f
3:	move	t8,zero			/* clear the sticky register */
	/*
	 * If the exponent difference is greater than zero shift the smaller
	 * value right by the exponent difference to align the binary point
	 * before the addition.  Also select the exponent of the result to
	 * be the largest exponent of the two values.  The result exponent is
	 * left in (t1) so only if RS is to be shifted does RTs exponent
	 * need to be moved into (t1).
	 */
	beq	v0,zero,9f		/* - if the exp diff is zero then no shift */
	bgt	v1,zero,6f		/* if the exp diff > 0 shift RT */
	move	t1,t5			/* result exponent will be RTs exponent */
	/* Shift the fraction of the RS value */
	blt	v0,32,5f		/* check for shifts >= 32 */
	move	t8,t3			/* shift the fraction over 32 bits by */
	move	t3,t2			/*  moving the words to the right and */
	move	t2,zero			/*  fill the highest word with a zero */
	beq	t8,zero,4f		/* - if any 1s get into the sticky reg */
	or	t8,STKBIT		/*  make sure the sticky bit stays set */
4:	subu	v0,32			/* the right shift amount (v0) */
	negu	v1,v0			/* the left shift amount which is 32 */
	addu	v1,32			/*  minus right shift amount (v1) */
	/* Now shift the fraction (only the low two words in this case) */
	srlv	t8,t8,v0		/* shift the sticky register */
	sllv	t9,t3,v1
	or	t8,t9
	srlv	t3,t3,v0		/* shift the low word of the fraction */
	b	9f
5:	/* Shift the fraction value of RS by < 32 (the right shift amount (v0)) */
	negu	v1,v0			/* the left shift amount which is 32 */
	addu	v1,32			/*  minus right shift amount (v1) */
	srlv	t8,t8,v0		/* shift the sticky register */
	sllv	t9,t3,v1
	or	t8,t9
	srlv	t3,t3,v0		/* shift the low word of the fraction */
	sllv	t9,t2,v1
	or	t3,t9
	srlv	t2,t2,v0		/* shift the high word of the fraction */
	b	9f
6:	/* Shift the fraction of the RT value */
	blt	v0,32,8f		/* check for shifts >= 32 */
	move	t8,t7			/* shift the fraction over 32 bits by */
	move	t7,t6			/*  moving the words to the right and */
	move	t6,zero			/*  fill the highest word with a zero */
	beq	t8,zero,7f		/* - if any 1s get into the sticky reg */
	or	t8,STKBIT		/*  make sure the sticky bit stays set */
7:	subu	v0,32			/* the right shift amount (v0) */
	negu	v1,v0			/* the left shift amount which is 32 */
	addu	v1,32			/*  minus right shift amount (v1) */
	/* Now shift the fraction (only the low two words in this case) */
	srlv	t8,t8,v0		/* shift the sticky register */
	sllv	t9,t7,v1
	or	t8,t9
	srlv	t7,t7,v0		/* shift the low word of the fraction */
	b	9f
8:	/* Shift the fraction value of RT by < 32 (the right shift amount (v0)) */
	negu	v1,v0			/* the left shift amount which is 32 */
	addu	v1,32			/*  minus right shift amount (v1) */
	srlv	t8,t8,v0		/* shift the sticky register */
	sllv	t9,t7,v1
	or	t8,t9
	srlv	t7,t7,v0		/* shift the low word of the fraction */
	sllv	t9,t6,v1
	or	t7,t9
	srlv	t6,t6,v0		/* shift the high word of the fraction */
9:
	/*
	 * Now if the signs are the same add the two fractions, else if the
	 * signs are different then subtract the smaller fraction from the
	 * larger fraction and the results sign will be the sign of the
	 * larger fraction.
	 */
	bne	t0,t4,2f		/* - if the signs not the same subtract */
	/* Add the fractions */
	not	v0,t3			/* set carry out (t9) for the addition */
	sltu	t9,v0,t7		/*  of the least fraction words */
	addu	t3,t7			/* add the least fraction words */
	/* add the less fraction fraction words with the carry in */
	bne	t9,zero,1f		/* see if there is a carry in */
	/* no carry in to be added in (carry out is not possible or needed) */
	addu	t2,t6			/* add the less fraction words */
	b	norm_d
	/* a carry in is to be added in (carry out is not possible or needed) */
1:	addu	t2,t6			/* add the less fraction words */
	addu	t2,1			/* add in the carry in */
	b	norm_d
2:
	/*
	 * Subtract the smaller fraction from the larger fraction and set the
	 * sign of the result to the sign of the larger fraction.
	 */
	blt	t2,t6,5f		/* determine the smaller fraction */
	bgt	t2,t6,1f		/*  Note the case where they were equal */
	bltu	t3,t7,5f		/*  has already been taken care of */
1:	/*
	 * RT is smaller so subtract RT from RS and use RSs sign as the sign
	 * of the result (the sign is already in the correct place (t0)).
	 */
	sltu	t9,zero,t8		/* set barrow out for sticky register */
	subu	t8,zero,t8
	/* subtract least signifiant fraction words */
	bne	t9,zero,2f		/* see if there is a barrow in */
	/* no barrow in to be subtracted out */
	sltu	t9,t3,t7		/* set barrow out for least fraction */
	subu	t3,t3,t7		/* subtract least fractions */
	b	3f
2:	/* barrow in to be subtracted out */
	sltu	t9,t3,t7		/* set barrow out for least fraction */
	subu	t3,t3,t7		/* subtract least fractions */
	seq	v0,t3,zero		/* set barrow out for barrow in */
	or	t9,v0			/* final barrow out */
	subu	t3,1			/* subtract barrow in */
3:	/* subtract less signifiant fraction words */
	bne	t9,zero,4f		/* see if there is a barrow in */
	/* no barrow in to be subtracted out (barrow out not possible or needed) */
	subu	t2,t2,t6		/* subtract less fractions */
	b	norm_d
4:	/* barrow in to be subtracted out (barrow out not possible or needed) */
	subu	t2,t2,t6		/* subtract less fractions */
	subu	t2,1			/* subtract barrow in */
	b	norm_d
5:
	/*
	 * RS is smaller so subtract RS from RT and use RTs sign as the sign
	 * of the result.
	 */
	move	t0,t4			/* use RTs sign as the sign of result */
	sltu	t9,zero,t8		/* set barrow out for sticky register */
	subu	t8,zero,t8
	/* subtract least signifiant fraction words */
	bne	t9,zero,1f		/* see if there is a barrow in */
	/* no barrow in to be subtracted out */
	sltu	t9,t7,t3		/* set barrow out for least fraction */
	subu	t3,t7,t3		/* subtract least fractions */
	b	2f
1:	/* barrow in to be subtracted out */
	sltu	t9,t7,t3		/* set barrow out for least fraction */
	subu	t3,t7,t3		/* subtract least fractions */
	seq	v0,t3,zero		/* set barrow out for barrow in */
	or	t9,v0			/* final barrow out */
	subu	t3,1			/* subtract barrow in */
2:	/* subtract less signifiant fraction words */
	bne	t9,zero,3f		/* see if there is a barrow in */
	/* no barrow in to be subtracted out (barrow out not possible or needed) */
	subu	t2,t6,t2		/* subtract less fractions */
	b	norm_d
3:	/* barrow in to be subtracted out (barrow out not possible or needed) */
	subu	t2,t6,t2		/* subtract least fractions */
	subu	t2,1			/* subtract barrow in */
	b	norm_d

add_e:
add_q:
	b	illfpinst

func_mul:
	la	v1,mul_fmt_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
mul_fmt_tab:
	b	mul_s;	nop
	b	mul_d;	nop
	b	mul_e;	nop
	b	mul_q;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder

/*******************************************************************************
*
* mul_s - Multiplication single RD = RS * RT
*
*/
	.globl GTEXT(mul_s)
FUNC_LABEL(mul_s)
	/*
	 * Break out the operands into their fields (sign,exp,fraction) and
	 * handle NaN operands by calling {rs,rt}breakout_s() .
	 */
	li	t9,C1_FMT_SINGLE*4
	li	v1,1
	jal	rs_breakout_s
	jal	rt_breakout_s

	/*
	 * With the NaN cases taken care of the sign of the result for all
	 * other operands is just the exclusive or of the signs of the
	 * operands.
	 */
	xor	t0,t4

	/*
	 * Check for multiplication of infinities, and produce the correct
	 * action if so.
	 */
	bne	t1,SEXP_INF,4f	/* is RS an infinity? */
	bne	t5,SEXP_INF,1f	/* is RT also an infinity? */
	/*
	 * The operation is just infinity * infinity so the result is just
	 * a properly signed infinity.
	 */
	or	t2,t0
	sll	t1,t1,SEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_1w
1:	/*
	 * RS is an infinity and RT is NOT an infinity, if RT is zero then
	 * this is an invalid operation else the result is just the RS infinity.
	 */
	bne	t5,zero,3f
	bne	t6,zero,3f
	/*
	 * RS is an infinity and RT is zero thus this is an invalid operation
	 * for addition so set the invalid exception in the C1_SR (a3) and
	 * setup the result depending if the enable for the invalid exception
	 * is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,2f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
2:	li	t2,SQUIETNAN_LEAST
	move	v0,zero
	b	rd_1w
	/*
	 * The operation is just infinity (RS) * x (RT) so the result is just
	 * the infinity (RS).
	 */
3:	or	t2,t0
	sll	t1,t1,SEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_1w
	/*
	 * RS is known NOT to be an infinity so now check RT for an infinity
	 */
4:	bne	t5,SEXP_INF,8f	/* is RT an infinity? */
	/*
	 * RT is an infinity, if RS is zero then this is an invalid operation
	 * else the result is just the RT infinity.
	 */
	bne	t1,zero,7f
	bne	t2,zero,7f
	/*
	 * RS is an infinity and RT is zero thus this is an invalid operation
	 * for addition so set the invalid exception in the C1_SR (a3) and
	 * setup the result depending if the enable for the invalid exception
	 * is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,6f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
6:	li	t2,SQUIETNAN_LEAST
	move	v0,zero
	b	rd_1w
	/*
	 * The operation is just x (RS) * infinity (RT) so the result is just
	 * the infinity (RT).
	 */
7:	move	t2,t0
	sll	t5,t5,SEXP_SHIFT
	or	t2,t5
	move	v0,zero
	b	rd_1w
8:
	/*
	 * Check for the multiplication of zeros and produce the correct zero
	 * if so.
	 */
	bne	t1,zero,1f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,1f	/* then the fraction */
	/* Now RS is known to be zero so return the properly signed zero */
	move	t2,t0
	move	v0,zero
	b	rd_1w

1:	bne	t5,zero,2f	/* check RT for a zero value (first the exp) */
	bne	t6,zero,2f	/* then the fraction */
	/* Now RT is known to be zero so return the properly signed zero */
	move	t2,t0
	move	v0,zero
	b	rd_1w
2:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be added.  So get all values
	 * into a format that can be added.  For normalized numbers set the
	 * implied one and remove the exponent bias.  For denormalized numbers
	 * convert to normalized numbers with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-SEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_s	/* normalize it */
	b	2f
1:	subu	t1,SEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:	bne	t5,zero,3f	/* check for RT being denormalized */
	li	t5,-SEXP_BIAS+1	/* set denorms exponent */
	jal	rt_renorm_s	/* normalize it */
	b	4f
3:	subu	t5,SEXP_BIAS	/* - if RT is not denormalized then remove the */
	or	t6,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
4:
	/*
	 * Calculate the exponent of the result to be used by the norm_s:
	 * code to figure the final exponent.
	 */
	addu	t1,t5
	addu	t1,9

	multu	t2,t6		/* multiply RS(fraction) * RT(fraction) */
	mflo	t8		/* the low 32 bits will be the sticky register */
	mfhi	t2		/* the high 32 bits will the result */
	b	norm_s

/*******************************************************************************
*
* mul_d - Multiplication double RD = RS * RT
*
*/
	.globl GTEXT(mul_d)
FUNC_LABEL(mul_d)
	/*
	 * Break out the operands into their fields (sign,exp,fraction) and
	 * handle NaN operands by calling {rs,rt}breakout_d() .
	 */
	li	t9,C1_FMT_DOUBLE*4
	li	v1,1
	jal	rs_breakout_d
	jal	rt_breakout_d

	/*
	 * With the NaN cases taken care of the sign of the result for all
	 * other operands is just the exclusive or of the signs of the
	 * operands.
	 */
	xor	t0,t4

	/*
	 * Check for multiplication of infinities, and produce the correct
	 * action if so.
	 */
	bne	t1,DEXP_INF,4f	/* is RS an infinity? */
	bne	t5,DEXP_INF,1f	/* is RT also an infinity? */
	/*
	 * The operation is just infinity * infinity so the result is just
	 * a properly signed infinity.
	 */
	or	t2,t0
	sll	t1,t1,DEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_2w
1:	/*
	 * RS is an infinity and RT is NOT an infinity, if RT is zero then
	 * this is an invalid operation else the result is just the RS infinity.
	 */
	bne	t5,zero,3f
	bne	t6,zero,3f
	bne	t7,zero,3f
	/*
	 * RS is an infinity and RT is zero thus this is an invalid operation
	 * for addition so set the invalid exception in the C1_SR (a3) and
	 * setup the result depending if the enable for the invalid exception
	 * is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,2f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
2:	li	t2,DQUIETNAN_LESS
	li	t3,DQUIETNAN_LEAST
	move	v0,zero
	b	rd_2w
	/*
	 * The operation is just infinity (RS) * x (RT) so the result is just
	 * the infinity (RS).
	 */
3:	or	t2,t0
	sll	t1,t1,DEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_2w
	/*
	 * RS is known NOT to be an infinity so now check RT for an infinity
	 */
4:	bne	t5,DEXP_INF,8f	/* is RT an infinity? */
	/*
	 * RT is an infinity, if RS is zero then this is an invalid operation
	 * else the result is just the RT infinity.
	 */
	bne	t1,zero,7f
	bne	t2,zero,7f
	bne	t3,zero,7f
	/*
	 * RS is an infinity and RT is zero thus this is an invalid operation
	 * for addition so set the invalid exception in the C1_SR (a3) and
	 * setup the result depending if the enable for the invalid exception
	 * is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,6f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
6:	li	t2,DQUIETNAN_LESS
	li	t3,DQUIETNAN_LEAST
	move	v0,zero
	b	rd_2w
	/*
	 * The operation is just x (RS) * infinity (RT) so the result is just
	 * the infinity (RT).
	 */
7:	move	t2,t0
	sll	t5,t5,DEXP_SHIFT
	or	t2,t5
	move	t3,zero
	move	v0,zero
	b	rd_2w
8:
	/*
	 * Check for the multiplication of zeros and produce the correct zero
	 * if so.
	 */
	bne	t1,zero,1f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,1f	/* then the high part of the fraction */
	bne	t3,zero,1f	/* then the low part of the fraction */
	/* Now RS is known to be zero so return the properly signed zero */
	move	t2,t0
	move	v0,zero
	b	rd_2w

1:	bne	t5,zero,2f	/* check RT for a zero value (first the exp) */
	bne	t6,zero,2f	/* then the high part of the fraction */
	bne	t7,zero,2f	/* then the low part of the fraction */
	/* Now RT is known to be zero so return the properly signed zero */
	move	t2,t0
	move	t3,zero
	move	v0,zero
	b	rd_2w
2:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be added.  So get all values
	 * into a format that can be added.  For normalized numbers set the
	 * implied one and remove the exponent bias.  For denormalized numbers
	 * convert to normalized numbers with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-DEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_d	/* normalize it */
	b	2f
1:	subu	t1,DEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:	bne	t5,zero,3f	/* check for RT being denormalized */
	li	t5,-DEXP_BIAS+1	/* set denorms exponent */
	jal	rt_renorm_d	/* normalize it */
	b	4f
3:	subu	t5,DEXP_BIAS	/* - if RT is not denormalized then remove the */
	or	t6,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
4:
	/*
	 * Calculate the exponent of the result to be used by the norm_d:
	 * code to figure the final exponent.
	 */
	addu	t1,t5
	addu	t1,12

	/*
	 * Since the norm_d: code expects the fraction to be in t2,t3,t8
	 * RSs fraction is moved to t4,t5 so to free up t2,t3 to hold
	 * the accululated result of the partal products.
	 */
	move	t4,t2
	move	t5,t3

	multu	t5,t7		/* multiply RS(low) * RT(low) fractions */
	mflo	ra		/* all the low 32 bits (ra) go into the sticky */
	sne	ra,ra,zero	/*  bit so set it if there are any one bits */
	mfhi	t8		/* get the high 32 bits (t8) */

	multu	t5,t6		/* multiply RS(low) * RT(high) fractions */
	mflo	v1		/* the low 32 bits will be added to t8 */
	mfhi	t3		/* the high 32 bits will go into t3 */
	move	t2,zero		/* the highest accumulator word is zeroed */
	not	v0,v1		/* set the carry out of t8 and low 32 bits */
	sltu	t9,v0,t8	/*  of the mult (v1) */
	addu	t8,v1		/* do the add of t8 and the low 32 bits (v1) */
	beq	t9,zero,1f	/* - if no carry out continue */
	addu	t3,1		/* add the carry in */
	seq	t2,t3,zero	/* set the carry out into t3 */
1:
	multu	t4,t7		/* multiply RS(high) * RT(low) fractions */
	mflo	v1		/* the low 32 bits will be added to t8 */
	mfhi	t5		/* the high 32 bits will be added to t3 */
	not	v0,v1		/* set the carry out of t8 and low 32 bits */
	sltu	t9,v0,t8	/*  of the mult (v1) */
	addu	t8,v1		/* do the add of t8 and the low 32 bits (v1) */
	beq	t9,zero,2f	/* branch if no carry out */
	/* add t3 and the high 32 bits of the mult (t5) and the carry in */
	not	v0,t5		/* set the carry out of t3 and high 32 bits */
	sltu	t9,v0,t3	/*  of the mult (t5) */
	addu	t3,t5		/* do the add of t3 and the high 32 bits (t5) */
	addu	t3,1		/* add the carry in */
	seq	v0,t3,zero	/* set the carry out of the carry in */
	or	t9,v0		/* set the final carry out */
	b	3f
2:	/* add t3 and the high 32 bits of the mult (t5) and no carry in */
	not	v0,t5		/* set the carry out of t3 and high 32 bits */
	sltu	t9,v0,t3	/*  of the mult (t5) */
	addu	t3,t5		/* do the add of t3 and the high 32 bits (t5) */
3:	addu	t2,t9		/* add the carry out to t2 */

	multu	t4,t6		/* multiply RS(high) * RT(high) fractions */
	mflo	v1		/* the low 32 bits will be added to t3 */
	mfhi	t5		/* the high 32 bits will be added to t2 */
	not	v0,v1		/* set the carry out of t3 and low 32 bits */
	sltu	t9,v0,t3	/*  of the mult (v1) */
	addu	t3,v1		/* do the add of t3 and the low 32 bits (v1) */
	beq	t9,zero,4f	/* branch if no carry out */
	/* add t2 and the high 32 bits of the mult (t5) and the carry in */
	addu	t2,1		/* add the carry in */
4:	addu	t2,t5		/* do the add of t2 and the high 32 bits (t5) */
	or	t8,ra

	b	norm_d

mul_e:
mul_q:
	b	illfpinst

func_div:
	la	v1,div_fmt_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
div_fmt_tab:
	b	div_s;	nop
	b	div_d;	nop
	b	div_e;	nop
	b	div_q;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder

/*******************************************************************************
*
* div_s - Division single RD = RS / RT
*
*/
	.globl GTEXT(div_s)
FUNC_LABEL(div_s)
	/*
	 * Break out the operands into their fields (sign,exp,fraction) and
	 * handle NaN operands by calling {rs,rt}breakout_s() .
	 */
	li	t9,C1_FMT_SINGLE*4
	li	v1,1
	jal	rs_breakout_s
	jal	rt_breakout_s

	/*
	 * With the NaN cases taken care of the sign of the result for all
	 * other operands is just the exclusive or of the signs of the
	 * operands.
	 */
	xor	t0,t4

	/*
	 * Check for division of infinities, and produce the correct
	 * action if so.
	 */
	bne	t1,SEXP_INF,3f	/* is RS an infinity? */
	bne	t5,SEXP_INF,2f	/* is RT also an infinity? */
	/*
	 * The operation is infinity / infinity which is an invalid operation.
	 * So set the invalid exception in the C1_SR (a3) and setup the
	 * result depending if the enable for the invalid exception is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,1f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
1:	li	t2,SQUIETNAN_LEAST
	move	v0,zero
	b	rd_1w
	/*
	 * RS is an infinity and RT is NOT an infinity so the result is just a
	 * a properly signed infinity (even if RT is zero).
	 */
2:	or	t2,t0
	sll	t1,t1,SEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_1w
	/*
	 * RS is known NOT to be an infinity so now check RT for an infinity
	 */
3:	bne	t5,SEXP_INF,4f	/* is RT an infinity? */
	/*
	 * RT is an infinity and RS is NOT an infinity so the result is just a
	 * a properly signed zero.
	 */
	move	t2,t0
	move	v0,zero
	b	rd_1w
4:
	/*
	 * Check for the division with zeros and produce the correct action
	 * if so.
	 */
	bne	t5,zero,4f	/* check RT for a zero value (first the exp) */
	bne	t6,zero,4f	/* then the fraction */
	/*
	 * Now RT is known to be zero, if RS is zero it is an invalid operation
	 * if not it is a divide by zero.
	 */
	bne	t1,zero,2f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,2f	/* then the fraction */
	/*
	 * The operation is 0 / 0 which is an invalid operation.
	 * So set the invalid exception in the C1_SR (a3) and setup the
	 * result depending if the enable for the invalid exception is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,1f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
1:	li	t2,SQUIETNAN_LEAST
	move	v0,zero
	b	rd_1w
	/*
	 * The operation is x / 0 which is a divide by zero exception.  So set
	 * the divide by zero exception in the C1_SR (a3) and setup the
	 * result depending if the enable for the divide by zero exception
	 * is set.
	 */
2:	or	a3,DIVIDE0_EXC
	and	v0,a3,DIVIDE0_ENABLE
	beq	v0,zero,3f
	/*
	 * The divide by zero trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_DIV0_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The divide by zero trap was NOT enabled so the result is a properly
	 * signed infinity.
	 */
3:	or	t2,t0,SEXP_INF<<SEXP_SHIFT
	move	v0,zero
	b	rd_1w
	/*
	 * Now RT is known NOT to be zero, if RS is zero the result is just
	 * a properly signed zero.
	 */
4:	bne	t1,zero,5f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,5f	/* then the fraction */
	move	t2,t0
	move	v0,zero
	b	rd_1w
5:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be divded.  So get all values
	 * into a format that can be divded.  For normalized numbers set the
	 * implied one and remove the exponent bias.  For denormalized numbers
	 * convert to normalized numbers with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-SEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_s	/* normalize it */
	b	2f
1:	subu	t1,SEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:	bne	t5,zero,3f	/* check for RT being denormalized */
	li	t5,-SEXP_BIAS+1	/* set denorms exponent */
	jal	rt_renorm_s	/* normalize it */
	b	4f
3:	subu	t5,SEXP_BIAS	/* - if RT is not denormalized then remove the */
	or	t6,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
4:
	/*
	 * Calculate the exponent of the result to be used by the norm_s:
	 * code to figure the final exponent.
	 */
	subu	t1,t5
	subu	t1,8

	/*
	 * Since the norm_s: code expects the fraction to be in t2,t8
	 * RSs fraction is moved to t4 so to free up t2 to hold
	 * the final quotient of the division.
	 */
	move	t4,t2

	move	v0,zero		/* set the number of quotient bits calculated */
				/*  to zero */
	move	t2,zero		/* clear the quotient accumulator */

1:	bltu	t4,t6,3f	/* check if dividend (RS) >= divisor (RT) */

2:	/* subtract divisor (RT) from dividend (RS) */
	subu	t4,t6		/* subtract the fraction words */
	addu	t2,1		/* add one to the quotient accumulator */

	bne	t4,zero,3f	/* see if division is done (remainder of zero) */
	move	t8,zero		/* clear the sticky register (no remainder) */
	negu	v0		/* shift the quotient accumulator into its */
	addu	v0,31		/*  final possition and goto norm_s: */
	sllv	t2,t2,v0
	b	norm_s

3:	sll	t4,t4,1		/* shift the dividend (RS) left one bit */
	addu	v0,1		/* add one to the number of quotient bits */
				/*  calculated */
	sll	t2,t2,1		/* shift the quotient accumulator left one bit */
	/* see if enough quotient bits have been calculated if not continue */
	blt	v0,SFRAC_BITS+3,1b

	negu	v0		/* shift the quoient accumulator into its */
	addu	v0,31		/*  final possition */
	sllv	t2,t2,v0

	move	t8,t4		/* set the sticky register with all the bits of */
				/*  remainder */
	b	norm_s

/*******************************************************************************
*
* div_d - Division double RD = RS / RT
*
*/
	.globl GTEXT(div_d)
FUNC_LABEL(div_d)
	/*
	 * Break out the operands into their fields (sign,exp,fraction) and
	 * handle NaN operands by calling {rs,rt}breakout_d() .
	 */
	li	t9,C1_FMT_DOUBLE*4
	li	v1,1
	jal	rs_breakout_d
	jal	rt_breakout_d

	/*
	 * With the NaN cases taken care of the sign of the result for all
	 * other operands is just the exclusive or of the signs of the
	 * operands.
	 */
	xor	t0,t4

	/*
	 * Check for division of infinities, and produce the correct
	 * action if so.
	 */
	bne	t1,DEXP_INF,3f	/* is RS an infinity? */
	bne	t5,DEXP_INF,2f	/* is RT also an infinity? */
	/*
	 * The operation is infinity / infinity which is an invalid operation.
	 * So set the invalid exception in the C1_SR (a3) and setup the
	 * result depending if the enable for the invalid exception is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,1f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
1:	li	t2,DQUIETNAN_LESS
	li	t3,DQUIETNAN_LEAST
	move	v0,zero
	b	rd_2w
	/*
	 * RS is an infinity and RT is NOT an infinity so the result is just a
	 * a properly signed infinity (even if RT is zero).
	 */
2:	or	t2,t0
	sll	t1,t1,DEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_2w
	/*
	 * RS is known NOT to be an infinity so now check RT for an infinity
	 */
3:	bne	t5,DEXP_INF,4f	/* is RT an infinity? */
	/*
	 * RT is an infinity and RS is NOT an infinity so the result is just a
	 * a properly signed zero.
	 */
	move	t2,t0
	move	t3,zero
	move	v0,zero
	b	rd_2w
4:
	/*
	 * Check for the division with zeros and produce the correct action
	 * if so.
	 */
	bne	t5,zero,4f	/* check RT for a zero value (first the exp) */
	bne	t6,zero,4f	/* then the high part of the fraction */
	bne	t7,zero,4f	/* then the low part of the fraction */
	/*
	 * Now RT is known to be zero, if RS is zero it is an invalid operation
	 * if not it is a divide by zero.
	 */
	bne	t1,zero,2f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,2f	/* then the high part of the fraction */
	bne	t3,zero,2f	/* then the low part of the fraction */
	/*
	 * The operation is 0 / 0 which is an invalid operation.
	 * So set the invalid exception in the C1_SR (a3) and setup the
	 * result depending if the enable for the invalid exception is set.
	 */
	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,1f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result is a quiet NaN.
	 * So use the default quiet NaN and exit softFp().
	 */
1:	li	t2,DQUIETNAN_LESS
	li	t3,DQUIETNAN_LEAST
	move	v0,zero
	b	rd_2w
	/*
	 * The operation is x / 0 which is a divide by zero exception.  So set
	 * the divide by zero exception in the C1_SR (a3) and setup the
	 * result depending if the enable for the divide by zero exception
	 * is set.
	 */
2:	or	a3,DIVIDE0_EXC
	and	v0,a3,DIVIDE0_ENABLE
	beq	v0,zero,3f
	/*
	 * The divide by zero trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_DIV0_VEC
	jal	post_signal
	li	v0,1
	b	store_C1_SR
	/*
	 * The divide by zero trap was NOT enabled so the result is a properly
	 * signed infinity.
	 */
3:	or	t2,t0,DEXP_INF<<DEXP_SHIFT
	move	t3,zero
	move	v0,zero
	b	rd_2w
	/*
	 * Now RT is known NOT to be zero, if RS is zero the result is just
	 * a properly signed zero.
	 */
4:	bne	t1,zero,5f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,5f	/* then the high part of the fraction */
	bne	t3,zero,5f	/* then the low part of the fraction */
	move	t2,t0
	move	v0,zero
	b	rd_2w
5:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be divded.  So get all values
	 * into a format that can be divded.  For normalized numbers set the
	 * implied one and remove the exponent bias.  For denormalized numbers
	 * convert to normalized numbers with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-DEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_d	/* normalize it */
	b	2f
1:	subu	t1,DEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:	bne	t5,zero,3f	/* check for RT being denormalized */
	li	t5,-DEXP_BIAS+1	/* set denorms exponent */
	jal	rt_renorm_d	/* normalize it */
	b	4f
3:	subu	t5,DEXP_BIAS	/* - if RT is not denormalized then remove the */
	or	t6,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
4:
	/*
	 * Calculate the exponent of the result to be used by the norm_d:
	 * code to figure the final exponent.
	 */
	subu	t1,t5
	subu	t1,11

	/*
	 * Since the norm_d: code expects the fraction to be in t2,t3,t8
	 * RSs fraction is moved to t4,t5 so to free up t2,t3 to hold
	 * the final quotient of the division.
	 */
	move	t4,t2
	move	t5,t3

	move	v0,zero		/* set the number of quotient bits calculated */
				/*  to zero */
	move	v1,zero		/* set the number of quotient bits in the */
				/*  quotient accumulator to zero */
	move	t3,zero		/* clear the quotient accumulator */

1:	bltu	t4,t6,3f	/* check if dividend (RS) >= divisor (RT) */
	bne	t4,t6,2f
	bltu	t5,t7,3f

2:	/* subtract divisor (RT) from dividend (RS) */
	sltu	t9,t5,t7	/* set the barrow of the low fraction words */
	subu	t5,t7		/* subtract the low fraction words */
	subu	t4,t6		/* subtract the high fraction words */
	subu	t4,t9		/* subtract the barrow */
	addu	t3,1		/* add one to the quotient accumulator */

	bne	t4,zero,3f	/* see if division is done (remainder of zero) */
	bne	t5,zero,3f
	move	t8,zero		/* clear the sticky register (no remainder) */
	negu	v1		/* shift the quotient accumulator into its */
	addu	v1,31		/*  final possition and place in the proper */
	sllv	t3,t3,v1	/*  word of the final quotient and goto norm_d: */
	bge	v0,32,norm_d
	move	t2,t3
	move	t3,zero
	b	norm_d

3:	sll	t4,t4,1		/* shift the dividend (RS) left one bit */
	srl	t9,t5,31	/* - if the high bit of the low word of the */
	sll	t5,t5,1		/*  fraction is set get it in to the low bit */
	addu	t4,t9		/*  of the high word of the fraction */

	addu	v0,1		/* add one to the number of quotient bits */
				/*  calculated */
	addu	v1,1		/* add one to the number of quotient bits */
				/*  calculated in the quotient accumulator */
	blt	v1,32,4f	/* see if quotient accumulator is full */
	move	t2,t3		/* - if so place it in the high word of the */
	move	t3,zero		/*  of the final quotient, clear it and */
	move	v1,zero		/*  set its count of bits to zero */
	b	1b

4:	sll	t3,t3,1		/* shift the quotient accumulator left one bit */
	/* see if enough quotient bits have been calculated if not continue */
	blt	v0,DFRAC_BITS+3,1b

	negu	v1		/* shift the quoient accumulator into its */
	addu	v1,31		/*  final possition */
	sllv	t3,t3,v1

	move	t8,t4		/* set the sticky register with all the bits of */
	or	t8,t5		/*  remainder */

	b	norm_d

div_e:
div_q:
	b	illfpinst

/*
 * To get to here the FUNC field (t8) was one of the comparison functions.
 * At this point the both the floating-point value for the specified FPR
 * registers of the RS and RT fields have been loaded into GPR registers.
 * What is done next is to decode the FMT field (v0) and branch to the code
 * to compare that format.
 */
comp:
	la	v1,comp_fmt_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
comp_fmt_tab:
	b	comp_s;	nop
	b	comp_d;	nop
	b	comp_e;	nop
	b	comp_q; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder
/*******************************************************************************
*
* comp_s -
*
* Comparison single RS : RT . After the result of the comparison is determined
* the predicate to use to set the condition bit is in the low four bits of the
* FUNC field (t8).
*/
	.globl GTEXT(comp_s)
FUNC_LABEL(comp_s)
	/*
	 * Check either operand for being a NaN.
	 */
	srl	t1,t2,SEXP_SHIFT	/* check RS and RT for a NaN */
	and	t1,SEXP_MASK
	srl	t5,t6,SEXP_SHIFT
	and	t5,SEXP_MASK
	bne	t1,SEXP_NAN,1f
	and	t9,t2,SFRAC_MASK
	bne	t9,zero,2f
1:	bne	t5,SEXP_NAN,7f
	and	t9,t6,SFRAC_MASK
	beq	t9,zero,7f
	/*
	 * At this point one of the operands is an NaN so the result of
	 * the comparision is unordered.  Set the condition bit with
	 * respect to the predicate.
	 */
2:	move	v0,zero			/* a zero exit value (hopefully) */
	and	v1,t8,COND_UN_MASK	/* set or clear the condition bit */
	beq	v1,zero,3f
	or	a3,CSR_CBITSET
	b	4f
3:	and	a3,CSR_CBITCLEAR
	/*
	 * Now see if the invalid exception is to be set.  This can occur
	 * for one of two reasons.  The first if the high bit of the predicate
	 * is set.  Second if either operand is a signaling NaN.
	 */
4:	and	v1,t8,COND_IN_MASK	/* see if this predicate causes an */
	bne	v1,zero,6f		/*  invalid exception is to be set */
					/*  for unordered comparisons */

	bne	t1,SEXP_NAN,5f		/* check RS for a signaling NaN */
	and	t9,t2,SFRAC_MASK
	beq	t9,zero,5f
	and	v1,t2,SSNANBIT_MASK
	bne	v1,zero,6f
5:	bne	t5,SEXP_NAN,store_C1_SR /* check RT for a signaling NaN */
	and	t9,t6,SFRAC_MASK
	beq	t9,zero,store_C1_SR
	and	v1,t6,SSNANBIT_MASK
	beq	v1,zero,store_C1_SR
	/*
	 * The set the invalid trap and if it is enabled signal a SIGFPE.
	 */
6:	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,store_C1_SR
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR
7:
	/*
	 * Set up to do the comparison by negating and setting the sign bits
	 * of negitive operands.
	 */
	li	v0,SIGNBIT
	and	v1,t2,v0	/* check to see if RS is negitive */
	beq	v1,zero,1f
	negu	t2
	xor	t2,v0
1:	and	v1,t6,v0	/* check to see if RT is negitive */
	beq	v1,zero,2f
	negu	t6
	xor	t6,v0
2:
	move	v0,zero		/* zero exit value */
	/*
	 * Now compare the two operands.
	 */
	blt	t2,t6,2f
	bne	t2,t6,4f
	/*
	 * At this point the comparison is known to be equal so set the
	 * condition bit if the equal condition is being compared for in
	 * the predicate.
	 */
	and	v1,t8,COND_EQ_MASK	/* set or clear the condition bit */
	beq	v1,zero,1f
	or	a3,CSR_CBITSET
	b	store_C1_SR
1:	and	a3,CSR_CBITCLEAR
	b	store_C1_SR
	/*
	 * At this point the comparison is known to be less than so set the
	 * condition bit if the less than condition is being compared for in
	 * the predicate.
	 */
2:	and	v1,t8,COND_LT_MASK	/* set or clear the condition bit */
	beq	v1,zero,3f
	or	a3,CSR_CBITSET
	b	store_C1_SR
3:	and	a3,CSR_CBITCLEAR
	b	store_C1_SR
	/*
	 * At this point the comparison is known to be greater than so clear the
	 * condition bit.
	 */
4:	and	a3,CSR_CBITCLEAR
	b	store_C1_SR

/*******************************************************************************
*
* comp_d -
*
* Comparison double RS : RT . After the result of the comparison is determined
* the predicate to use to set the condition bit is in the low four bits of the
* FUNC field (t8).
*/
	.globl GTEXT(comp_d)
FUNC_LABEL(comp_d)
	/*
	 * Check either operand for being a NaN.
	 */
	srl	t1,t2,DEXP_SHIFT	/* check RS for a NaN */
	and	t1,DEXP_MASK
	srl	t5,t6,DEXP_SHIFT	/* check RT for a NaN */
	and	t5,DEXP_MASK
	bne	t1,DEXP_NAN,1f
	and	t9,t2,DFRAC_MASK
	bne	t9,zero,2f
	bne	t3,zero,2f
1:	bne	t5,DEXP_NAN,9f
	and	t9,t6,DFRAC_MASK
	bne	t9,zero,2f
	beq	t7,zero,9f
	/*
	 * At this point one of the operands is an NaN so the result of
	 * the comparision is unordered.  Set the condition bit with
	 * respect to the predicate.
	 */
2:	move	v0,zero			/* a zero exit value (hopefully) */
	and	v1,t8,COND_UN_MASK	/* set or clear the condition bit */
	beq	v1,zero,3f
	or	a3,CSR_CBITSET
	b	4f
3:	and	a3,CSR_CBITCLEAR
	/*
	 * Now see if the invalid exception is to be set.  This can occur
	 * for one of two reasons.  The first if the high bit of the predicate
	 * is set.  Second if either operand is a signaling NaN.
	 */
4:	and	v1,t8,COND_IN_MASK	/* see if this predicate causes an */
	bne	v1,zero,8f		/*  invalid exception is to be set */
					/*  for unordered comparisons */

	bne	t1,DEXP_NAN,6f		/* check RS for a signaling NaN */
	and	t9,t2,DFRAC_MASK
	bne	t9,zero,5f
	beq	t3,zero,6f
5:	and	v1,t2,DSNANBIT_MASK
	bne	v1,zero,8f
6:	bne	t5,DEXP_NAN,store_C1_SR /* check RT for a signaling NaN */
	and	t9,t6,DFRAC_MASK
	bne	t9,zero,7f
	beq	t7,zero,store_C1_SR
7:	and	v1,t6,DSNANBIT_MASK
	beq	v1,zero,store_C1_SR
	/*
	 * The set the invalid trap and if it is enabled signal a SIGFPE.
	 */
8:	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,store_C1_SR
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR
9:
	/*
	 * Set up to do the comparison by negating and setting the sign bits
	 * of negitive operands.
	 */
	li	v0,SIGNBIT
	and	v1,t2,v0	/* check to see if RS is negitive */
	beq	v1,zero,2f
	not	t3
	not	t2
	addu	t3,1
	bne	t3,zero,1f
	addu	t2,1
1:	xor	t2,v0
2:	and	v1,t6,v0	/* check to see if RT is negitive */
	beq	v1,zero,4f
	not	t7
	not	t6
	addu	t7,1
	bne	t7,zero,3f
	addu	t6,1
3:	xor	t6,v0
4:
	move	v0,zero		/* zero exit value */
	/*
	 * Now compare the two operands.
	 */
	blt	t2,t6,2f
	bne	t2,t6,4f
	bltu	t3,t7,2f
	bne	t3,t7,4f
	/*
	 * At this point the comparison is known to be equal so set the
	 * condition bit if the equal condition is being compared for in
	 * the predicate.
	 */
	and	v1,t8,COND_EQ_MASK	/* set or clear the condition bit */
	beq	v1,zero,1f
	or	a3,CSR_CBITSET
	b	store_C1_SR
1:	and	a3,CSR_CBITCLEAR
	b	store_C1_SR
	/*
	 * At this point the comparison is known to be less than so set the
	 * condition bit if the less than condition is being compared for in
	 * the predicate.
	 */
2:	and	v1,t8,COND_LT_MASK	/* set or clear the condition bit */
	beq	v1,zero,3f
	or	a3,CSR_CBITSET
	b	store_C1_SR
3:	and	a3,CSR_CBITCLEAR
	b	store_C1_SR
	/*
	 * At this point the comparison is known to be greater than so clear the
	 * condition bit.
	 */
4:	and	a3,CSR_CBITCLEAR
	b	store_C1_SR

comp_e:
comp_q:
	b	illfpinst

/*
 * To get to here the FUNC field (t8) was one of the explicit rounding
 * conversion functions (round.l, trunc.l, ceil.l, floor.l
 * round.w, trunc.w, ceil.w, floor.w).
 * At this point the floating-point value for the specified FPR register of
 * the RS field has been loaded into GPR registers.
 */
conv_round:
	subu	t8,C1_FUNC_ROUNDL	/* set up to branch on the format the */
	sll	t8,t8,3
	la	v1,round_to_tab
	addu	v1, t8, v1
	j	v1
	
	.set	noreorder
round_to_tab:
	b	roundl;	nop
	b	truncl;  nop
	b	ceill;	nop
	b	floorl;	nop
	b	roundw;	nop
	b	truncw;	nop
	b	ceilw;	nop
	b	floorw;	nop
	.set reorder
	
roundl:
	la	v1,roundl_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
roundl_from_tab:
	b	roundl_from_s; nop
	b	roundl_from_d; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder
roundl_from_s:
	li	t8,CSR_RM_RN		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round nearest" */
	j	cvtl_from_s		/* convert */

roundl_from_d:
	li	t8,CSR_RM_RN		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round nearest" */
	j	cvtl_from_d		/* convert */

truncl:
	la	v1,truncl_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
truncl_from_tab:
	b	truncl_from_s; nop
	b	truncl_from_d; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder
truncl_from_s:
	li	t8,CSR_RM_RZ		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward zero" */
	j	cvtl_from_s		/* convert */

truncl_from_d:
	li	t8,CSR_RM_RZ		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward zero" */
	j	cvtl_from_d		/* convert */

ceill:
	la	v1,ceill_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
ceill_from_tab:
	b	ceill_from_s; nop
	b	ceill_from_d; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder
ceill_from_s:
	li	t8,CSR_RM_RPI		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward plus infinity" */
	j	cvtl_from_s		/* convert */

ceill_from_d:
	li	t8,CSR_RM_RPI		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward plus infinity" */
	j	cvtl_from_d		/* convert */

floorl:
	la	v1,floorl_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
floorl_from_tab:
	b	floorl_from_s; nop
	b	floorl_from_d; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder
floorl_from_s:
	li	t8,CSR_RM_RMI		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward minus infinity" */
	j	cvtl_from_s		/* convert */

floorl_from_d:
	li	t8,CSR_RM_RMI		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward minus infinity" */
	j	cvtl_from_d		/* convert */

roundw:
	la	v1,roundw_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
roundw_from_tab:
	b	roundw_from_s;	nop
	b	roundw_from_d;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder
roundw_from_s:
	li	t8,CSR_RM_RN		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round nearest" */
	j	cvtw_from_s		/* convert */

roundw_from_d:
	li	t8,CSR_RM_RN		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round nearest" */
	j	cvtw_from_d		/* convert */

truncw:
	la	v1,truncw_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
truncw_from_tab:
	b	truncw_from_s;	nop
	b	truncw_from_d;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder
truncw_from_s:
	li	t8,CSR_RM_RZ		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward zero" */
	j	cvtw_from_s		/* convert */

truncw_from_d:
	li	t8,CSR_RM_RZ		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward zero" */
	j	cvtw_from_d		/* convert */

ceilw:
	la	v1,ceilw_from_tab
	add	v1, v0, v1
	j	v1

	.set noreorder
ceilw_from_tab:
	b	ceilw_from_s;	nop
	b	ceilw_from_d;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder
ceilw_from_s:
	li	t8,CSR_RM_RPI		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward plus infinity" */
	j	cvtw_from_s		/* convert */

ceilw_from_d:
	li	t8,CSR_RM_RPI		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward plus infinity" */
	j	cvtw_from_d		/* convert */

floorw:
	la	v1,floorw_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
floorw_from_tab:
	b	floorw_from_s;	nop
	b	floorw_from_d;	nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	b	illfpinst; nop
	.set	reorder

floorw_from_s:
	li	t8,CSR_RM_RMI		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward minus infinity" */
	j	cvtw_from_s		/* convert */

floorw_from_d:
	li	t8,CSR_RM_RMI		/* set operative Rounding Mode */
	sw	t8,RM_OFFSET(sp)	/*  to "round toward minus infinity" */
	j	cvtw_from_d		/* convert */

/*
 * To get to here the FUNC field (t8) was one of the conversion functions.
 * At this point the floating-point value for the specified FPR register of
 * the RS field has been loaded into GPR registers.  What is done next is to
 * futher decode the FUNC field (t8) for the conversion functions.  First
 * the format the conversion is going to is decoded from the FUNC field (t8).
 * Second the format the conversion is coming from is decoded from the FMT
 * field (v0).
 */
conv:
	/* t8 is >= 32 and <= 37, so table has 6 entries */
	subu	t8,C1_FUNC_CVTS		/* set up to branch on the format the */
	sll	t8,t8,3
	la	v1,conv_to_tab
	addu	v1, t8, v1
	j	v1

	.set noreorder
conv_to_tab:
	b	cvts;	nop	/* cvt.s.fmt */
	b	cvtd;	nop	/* cvt.d.fmt */
	b	cvtq;	nop	/* reserved? */
	b	cvtw;	nop	/* reserved? - incorrect? */
	b	cvtw;	nop	/* cvt.w.fmt - from Vr5432 manual */
	b	cvtl;	nop	/* cvt.l.fmt - from Vr5432 manual */
	.set	reorder

cvts:
	la	v1,cvts_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
cvts_from_tab:
	b	illfpinst;	nop
	b	cvts_from_d;	nop
	b	cvts_from_e;	nop
	b	cvts_from_q;	nop
	b	cvts_from_w;	nop
	b	cvts_from_l;	nop
	.set	reorder

/*******************************************************************************
*
* cvts_from_d - Convert to single format from double format.
*
*/
	.globl GTEXT(cvts_from_d)
FUNC_LABEL(cvts_from_d)
	/*
	 * Break out the operand into its fields (sign,exp,fraction) and
	 * handle NaN operands by calling rs_breakout_d() and telling it
	 * to convert NaNs to single if it finds one.
	 */
	li	t9,C1_FMT_SINGLE*4
	move	v1,zero
	jal	rs_breakout_d

	/*
	 * Check for infinities, and produce the correct infinity if so.
	 */
	bne	t1,DEXP_INF,1f	/* is RS an infinity? */
	move	t2,t0		/* use the sign of the infinity */
	or	t2,SEXP_INF<<SEXP_SHIFT
	move	v0,zero
	b	rd_1w
1:
	/*
	 * Check for zeroes, and produce the correct zero if so.
	 */
	bne	t1,zero,1f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,1f	/* then the high part of the fraction */
	bne	t3,zero,1f	/* then the low part of the fraction */
	move	t2,t0		/* use the sign of the zero */
	move	v0,zero
	b	rd_1w
1:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left a value that can be converted by setting it up
	 * for norm_s: . For normalized numbers set the implied one and remove
	 * the exponent bias.  For denormalized numbers convert to a normalized
	 * number with the correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-DEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_d	/* normalize it */
	b	2f
1:	subu	t1,DEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:
	/*
	 * Shift the double fraction over to where a normalized single fraction
	 * is, and branch to norm_s_noshift: to put the value together as a
	 * single and handle the underflow, overflow and inexact exceptions.
	 */
	sll	t2,t2,32-(DFRAC_BITS-SFRAC_BITS)
	srl	v0,t3,DFRAC_BITS-SFRAC_BITS
	or	t2,v0
	sll	t8,t3,32-(DFRAC_BITS-SFRAC_BITS)
	b	norm_s_noshift

cvts_from_e:
cvts_from_q:
	b	illfpinst

/******************************************************************************
*
* cvts_from_w - Convert to single format from a word
*
*/
cvts_from_w:
	bne	t2,zero,1f		/* check for zero */
	move	v0,zero			/* a zero exit value */
	b	rd_1w
1:	move	t0,zero			/* clear sign bit */
	bge	t2,zero,2f		/* - if negitive negate it and set the */
	negu	t2			/*  sign bit */
	li	t0,SIGNBIT
2:
	li	t1,SFRAC_BITS		/* set exponent */

	/*
	 * Determine where the first one bit is in the fraction (t2).  After
	 * this series of tests the shift count to shift the fraction left so
	 * the first 1 bit is in the high bit will be in t9.  This sequence of
	 * code uses registers v0,v1 and t9 (it could be done with two but
	 * with reorginization this is faster).
	 */
	move	v0,t2
	move	t9,zero

	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction (the fraction starts
	 * out only in (t2) but ends up as a single fraction in (t2,t8) ).
	 */
	subu	t9,SFRAC_LEAD0S	/* the calulated shift amount */
	/* Check to see if any shift or adjustment is needed */
	beq	t9,zero,2f
	subu	t1,t9		/* adjust the exponent */
	blt	t9,zero,1f	/* - if the shift amount is negitive shift right */
	/* Shift the fraction left by the shift amount (t9) */
	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sllv	t2,t2,t9
	move	t8,zero
	b	2f
1:	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	sllv	t8,t2,v0
	srlv	t2,t2,t9
2:
	/*
	 * If the result is inexact then it must be rounded else it can just
	 * be put together.
	 */
	bne	t8,zero,norm_s_noshift

	and	t2,~SIMP_1BIT		/* clear the implied 1 */
	or	t2,t0			/* put the sign back in */
	addu	t1,SEXP_BIAS		/* add back in the exponent bias */
	sll	t1,t1,SEXP_SHIFT	/* shift the exponent back in place */
	or	t2,t1			/* put the exponent back in */
	move	v0,zero			/* a zero exit value */
	b	rd_1w

/******************************************************************************
*
* cvts_from_l - Convert to single format from a long
*
*/
cvts_from_l:
	bne	t2,zero,1f		/* check for zero - high bits */
	bne	t3,zero,1f		/* check for zero - low bits */
	move	v0,zero			/* a zero exit value */
	b	rd_1w
1:
	/* Special case: 0x80000000.0000000 -> 0xdf000000 */
	li	t0,0x80000000
	bne	t2,t0,1f		/* check for zero - high bits */
	bne	t3,zero,1f		/* check for zero - low bits */
	li	t2,0xdf000000
	move	v0,zero			/* a zero exit value */
	b	rd_1w
1:
	/* Special case: 0x7fffffff.ffffffff -> 0x5f000000 */
	li	t0,0x7fffffff
	bne	t2,t0,1f		/* check for zero - high bits */
	li	t0,0xffffffff
	bne	t3,t0,1f		/* check for zero - low bits */
	li	t2,0x5f000000
	move	v0,zero			/* a zero exit value */
	b	rd_1w
1:
	move	t0,zero			/* clear sign bit */
	bge	t2,zero,2f		/* - if negitive negate it and set the sign bit */
	negu	t3			/* negate low bits */
	not	t2			/* invert upper bits */
	bne	t3,zero,3f		/* t3==0 -> overflow during negate */
	addu	t2,1			/* increment upper bits */
	and	t2,~SIGNBIT		/* clamp */
3:
	li	t0,SIGNBIT
2:
	li	t1,SFRAC_BITS		/* set exponent */

	/*
	 * The first step in this process is to determine where the first
	 * one bit is in the fraction (t2,t3,t8).  After this series of tests
	 * the shift count to shift the fraction left so the first 1 bit is
	 * in the high bit will be in t9.  This sequence of code uses registers
	 * v0,v1 and t9 (it could be done with two but with reorginization this
	 * is faster).  Note it is not possible for the first one bit to be in
	 * the sticky register (t8) but it does participate in the shift.
	 */
	move	v0,t2
	move	t9,zero
	bne	t2,zero,1f
	move	v0,t3
	addu	t9,32
	bne	t3,zero,1f
	move	v0,t8
	addu	t9,32
	b	5f
1:
	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction.
	 */
	subu	t9,SFRAC_LEAD0S	/* the calulated shift amount */
	/* Check to see if any shift or adjustment is needed */
	beq	t9,zero,4f
	subu	t1,t9		/* adjust the exponent */
	blt	t9,zero,2f	/* - if the shift amount is negitive shift right */
	/* Shift the fraction left by the shift amount (t9) */
	blt	t9,32,1f
	subu	t9,32		/* shift the fraction left for >= 32 bit shifts */
	negu	v0,t9
	addu	v0,32
	sllv	t2,t3,t9
	srlv	v1,t8,v0
	or	t2,v1
	sllv	t3,t8,t9
	move	t8,zero
	b	4f
1:	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sll	t2,t9
	srlv	v1,t3,v0
	or	t2,v1
	sll	t3,t9
	srlv	v1,t8,v0
	or	t3,v1
	sll	t8,t9
	b	4f
2:	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	beq	t8,zero,3f
	or	t8,STKBIT
3:	srl	t8,t9
	sllv	v1,t3,v0
	or	t8,v1
	srl	t3,t9
	sllv	v1,t2,v0
	or	t3,v1
	srl	t2,t9
4:
	/*
	 * If the result is inexact then it must be rounded else it can just
	 * be put together.
	 */
	bne	t8,zero,norm_s_noshift

	and	t2,~SIMP_1BIT		/* clear the implied 1 */
	or	t2,t0			/* put the sign back in */
	addu	t1,SEXP_BIAS		/* add back in the exponent bias */
	sll	t1,SEXP_SHIFT		/* shift the exponent back in place */
	or	t2,t1			/* put the exponent back in */
	move	v0,zero			/* a zero exit value */
	b	rd_1w

cvtd:
	la	v1,cvtd_from_tab
	addu	v1, v0, v1
	j	v1

	.set noreorder
cvtd_from_tab:
	b	cvtd_from_s;	nop
	b	illfpinst;	nop
	b	cvtd_from_e;	nop
	b	cvtd_from_q;	nop
	b	cvtd_from_w;	nop
	b	cvtd_from_l;	nop
	.set	reorder

/*******************************************************************************
*
* cvtd_from_s - Convert to double format from single format.
*
*/
	.globl GTEXT(cvtd_from_s)
FUNC_LABEL(cvtd_from_s)
	/*
	 * Break out the operand into its fields (sign,exp,fraction) and
	 * handle NaN operands by calling rs_breakout_s() and telling it
	 * to convert NaNs to double if it finds one.
	 */
	li	t9,C1_FMT_DOUBLE*4
	move	v1,zero
	jal	rs_breakout_s

	/*
	 * Check for infinities, and produce the correct infinity if so.
	 */
	bne	t1,SEXP_INF,1f	/* is RS an infinity? */
	move	t2,t0		/* use the sign of the infinity */
	or	t2,DEXP_INF<<DEXP_SHIFT
	move	t3,zero
	move	v0,zero
	b	rd_2w
1:
	/*
	 * Check for zeroes, and produce the correct zero if so.
	 */
	bne	t1,zero,1f	/* check RS for a zero value (first the exp) */
	bne	t2,zero,1f	/* then the fraction */
	move	t2,t0		/* use the sign of the zero */
	move	t3,zero
	move	v0,zero
	b	rd_2w
1:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left a value that can be converted.  For normalized
	 * numbers set the implied one and remove the exponent bias.  For
	 * denormalized numbers convert to a normalized number with the
	 * correct exponent.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	li	t1,-SEXP_BIAS+1	/* set denorms exponent */
	jal	rs_renorm_s	/* normalize it */
	b	2f
1:	subu	t1,SEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */
2:
	/*
	 * Shift the single fraction over to where a normalized double fraction
	 * is, and put the result together as a double.  Note underflow,
	 * overflow and inexact exceptions are not possible.
	 */
	sll	t3,t2,DFRAC_BITS-SFRAC_BITS
	srl	t2,t2,32-(DFRAC_BITS-SFRAC_BITS)

	and	t2,~DIMP_1BIT		/* clear the implied 1 */
	or	t2,t0			/* put the sign back in */
	addu	t1,DEXP_BIAS		/* add back in the exponent bias */
	sll	t1,t1,DEXP_SHIFT	/* shift the exponent back in place */
	or	t2,t1			/* put the exponent back in */
	move	v0,zero			/* a zero exit value */
	b	rd_2w

cvtd_from_e:
cvtd_from_q:
	b	illfpinst

/*******************************************************************************
*
* cvtd_from_w - Convert to double formmat from a word
*
*/
FUNC_LABEL(cvtd_from_w)
	bne	t2,zero,1f		/* check for zero */
	move	t3,zero			/* - if so return a +0 */
	move	v0,zero			/* a zero exit value */
	b	rd_2w
1:	move	t0,zero			/* clear sign bit */
	bge	t2,zero,2f		/* - if negitive negate it and set the */
	negu	t2			/*  sign bit */
	li	t0,SIGNBIT
2:
	li	t1,DFRAC_BITS-32	/* set exponent */

	/*
	 * Determine where the first one bit is in the fraction (t2).  After
	 * this series of tests the shift count to shift the fraction left so
	 * the first 1 bit is in the high bit will be in t9.  This sequence of
	 * code uses registers v0,v1 and t9 (it could be done with two but
	 * with reorginization this is faster).
	 */
	move	v0,t2
	move	t9,zero

	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction (the fraction starts
	 * out only in (t2) but ends up as a double fraction in (t2,t3) ).
	 */
	subu	t9,DFRAC_LEAD0S	/* the calulated shift amount */
	/* Check to see if any shift or adjustment is needed */
	move	t3,zero
	beq	t9,zero,2f
	subu	t1,t9		/* adjust the exponent */
	blt	t9,zero,1f	/* - if the shift amount is negitive shift right */
	/* Shift the fraction left by the shift amount (t9) */
	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sllv	t2,t2,t9
	move	t3,zero
	b	2f
1:	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	sllv	t3,t2,v0
	srlv	t2,t2,t9
2:
	/*
	 * Put the result together as a double.  Note underflow,
	 * overflow and inexact exceptions are not possible.
	 */
	and	t2,~DIMP_1BIT		/* clear the implied 1 */
	or	t2,t0			/* put the sign back in */
	addu	t1,DEXP_BIAS		/* add back in the exponent bias */
	sll	t1,t1,DEXP_SHIFT	/* shift the exponent back in place */
	or	t2,t1			/* put the exponent back in */
	move	v0,zero			/* a zero exit value */
	b	rd_2w

/*******************************************************************************
*
* cvtd_from_l - Convert to double format from a 64-bit long
*
*/
FUNC_LABEL(cvtd_from_l)
	bne	t2,zero,1f		/* check for zero - high bits */
	bne	t3,zero,1f		/* check for zero - low bits */
	move	t3,zero			/* - if so return a +0 */
	move	v0,zero			/* a zero exit value */
	b	rd_2w
1:
	/*
	 * Special case:
	 * convert 0x7fffffff.ffffffff to 43e00000.00000000
	 * instaed of 43df ffff.ffffffff
	 * Otherwise:
	 *   d2l(l2d(0x7fffffff.ffffffff) = 0x7fffffff.fffffc00
	 * which upsets Java (amoung other code).
	 */
	li	t0,0x7fffffff
	bne	t2,t0,1f
	li	t0,0xffffffff
	bne	t3,t0,1f
	li	t2,0x43e00000
	move	t3,zero
	move	v0,zero			/* a zero exit value */
	b	rd_2w
1:
	move	t0,zero			/* clear sign bit */
	bge	t2,zero,2f		/* - if negitive negate it and set the sign bit */
	negu	t3			/* negate low bits */
	not	t2			/* invert upper bits */
	bne	t3,zero,3f		/* t3==0 -> overflow during negate */
	addu	t2,1			/* increment upper bits */
3:
	li	t0,SIGNBIT
2:
	li	t1,DFRAC_BITS		/* set exponent */

	/*
	 * The first step in this process is to determine where the first
	 * one bit is in the fraction (t2,t3,t8).  After this series of tests
	 * the shift count to shift the fraction left so the first 1 bit is
	 * in the high bit will be in t9.  This sequence of code uses registers
	 * v0,v1 and t9 (it could be done with two but with reorginization this
	 * is faster).  Note it is not possible for the first one bit to be in
	 * the sticky register (t8) but it does participate in the shift.
	 */
	move	v0,t2
	move	t9,zero
	bne	t2,zero,1f
	move	v0,t3
	addu	t9,32
	bne	t3,zero,1f
	move	v0,t8
	addu	t9,32
1:
	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction.
	 */
	subu	t9,DFRAC_LEAD0S	/* the calulated shift amount */
	/* Check to see if any shift or adjustment is needed */
	beq	t9,zero,4f
	subu	t1,t9		/* adjust the exponent */
	blt	t9,zero,2f	/* - if the shift amount is negitive shift right */
	/* Shift the fraction left by the shift amount (t9) */
	blt	t9,32,1f
	subu	t9,32		/* shift the fraction left for >= 32 bit shifts */
	negu	v0,t9
	addu	v0,32
	sllv	t2,t3,t9
	srlv	v1,t8,v0
	or	t2,v1
	sllv	t3,t8,t9
	move	t8,zero
	b	4f
1:	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sll	t2,t9
	srlv	v1,t3,v0
	or	t2,v1
	sll	t3,t9
	srlv	v1,t8,v0
	or	t3,v1
	sll	t8,t9
	b	4f
2:	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	beq	t8,zero,3f
	or	t8,STKBIT
3:	srl	t8,t9
	sllv	v1,t3,v0
	or	t8,v1
	srl	t3,t9
	sllv	v1,t2,v0
	or	t3,v1
	srl	t2,t9
4:
	/*
	 * Put the result together as a double.  Note underflow,
	 * overflow and inexact exceptions are not possible.
	 */
	and	t2,~DIMP_1BIT		/* clear the implied 1 */
	or	t2,t0			/* put the sign back in */
	addu	t1,DEXP_BIAS		/* add back in the exponent bias */
	sll	t1,DEXP_SHIFT		/* shift the exponent back in place */
	or	t2,t1			/* put the exponent back in */
	move	v0,zero			/* a zero exit value */
	b	rd_2w


cvte:
	la	v1,cvte_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
	nop
cvte_from_tab:
	b	cvte_from_s;	nop
	b	cvte_from_d;	nop
	b	illfpinst;	nop
	b	cvte_from_q;	nop
	b	cvte_from_w;	nop
	b	cvte_from_l;	nop
	.set	reorder

cvte_from_s:
cvte_from_d:
cvte_from_q:
cvte_from_w:
cvte_from_l:
	b	illfpinst

cvtq:
	la	v1,cvtq_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
	nop
cvtq_from_tab:
	b	cvtq_from_s; nop
	b	cvtq_from_d; nop
	b	cvtq_from_e; nop
	b	illfpinst;  nop
	b	cvtq_from_w; nop
	b	cvtq_from_l; nop
	.set	reorder

cvtq_from_s:
cvtq_from_d:
cvtq_from_e:
cvtq_from_w:
cvtq_from_l:
	b	illfpinst

	.globl GTEXT(cvtw)
FUNC_LABEL(cvtw)
	la	v1,cvtw_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
	nop
cvtw_from_tab:
	b	cvtw_from_s;	nop
	b	cvtw_from_d;	nop
	b	cvtw_from_e;	nop
	b	cvtw_from_q;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	.set	reorder

/*******************************************************************************
*
* cvtw_from_s - Convert to a word from single format
*
*/
	.globl GTEXT(cvtw_from_s)
FUNC_LABEL(cvtw_from_s)
	/*
	 * Break out the fields of the RS single value in gp register (t2)
	 * into:
	 *	t0 -- sign bit		     (left justified)
	 *	t1 -- exponent		     (right justified, still biased)
	 *	t2 -- fraction bits [22-0]   (implied one bit NOT set)
	 */
	srl	t1,t2,SEXP_SHIFT
	move	t0,t1
	and	t1,SEXP_MASK
	and	t0,SIGNBIT>>SEXP_SHIFT
	sll	t0,t0,SEXP_SHIFT
	and	t2,SFRAC_MASK

	/*
	 * Check to see if this is a NaN or an infinity and set the invalid
	 * exception in the C1_SR (a3).  Setup the result depending if the
	 * enable for the invalid exception is set and if the value is a NaN
	 * or and infinity.
	 */
	bne	t1,SEXP_NAN,4f

	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,1f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result (implementation
	 * dependent) for infinities is the maximum or minimum value and for
	 * NaNs is the maximum positive value.
	 */
1:	bne	t2,zero,3f	/* is this a NaN? */
	/* it is an infinity, so see what the sign is and return the result */
	bne	t0,zero,2f
	li	t2,WORD_MAX	/* plus infinity returns maximum word value */
	move	v0,zero
	b	rd_1w
2:	li	t2,WORD_MIN	/* minus infinity returns minimum word value */
	move	v0,zero
	b	rd_1w
3:	li	t2,WQUIETNAN_LEAST	/* NaNs return maximum positive value */
	move	v0,zero
	b	rd_1w
4:
	/*
	 * Check the operand for a zero value and return a zero if so.
	 */
	bne	t1,zero,1f
	bne	t2,zero,1f
	/* t2 is already is zero so just use it */
	move	v0,zero
	b	rd_1w
1:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be converted.  For normalized
	 * numbers set the implied one and remove the exponent bias.  For
	 * denormalized numbers the result is an inexact zero.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	move	t2,zero		/* load the zero return value */
	li	t3,STKBIT	/* set the sticky bit */
	b	cvtw_round	/* branch to round */
1:	subu	t1,SEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */

	/*
	 * If the value is too small to have any integer digits then
	 * just set to zero with a sticky bit and round.
	 */
	bge	t1,WEXP_MIN,1f
	move	t2,zero		/* load the zero value */
	li	t3,STKBIT	/* load the sticky bit */
	b	cvtw_round	/* branch to round it */
1:
	/*
	 * If the exponent is too large then branch to set the overflow
	 * exception and to determine the result.  Note it is still possible
	 * to overflow after rounding in one case.
	 */
	bgt	t1,WEXP_MAX+1,cvtw_overflow
	/*
	 * A special check is needed for -1.0*2^31 so that it does not
	 * indicate an overflow and just returns the minimum word value.
	 */
	bne	t1,WEXP_MAX+1,1f
	bne	t2,SIMP_1BIT,cvtw_overflow
	beq	t0,zero,cvtw_overflow
	li	t2,WORD_MIN
	move	v0,zero
	b	rd_1w
1:
	/*
	 * Now shift the fraction so it is a fix point value.
	 */
	subu	t9,t1,SFRAC_BITS	/* calculate the shift amount */
	/* Check to see if any shift is needed */
	move	t3,zero		/* clear the sticky register */
	beq	t9,zero,cvtw_round
	blt	t9,zero,2f	/* - if the shift amount is negative shift right */
	/* Shift the fraction left by the shift amount (t9) */
1:	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sllv	t2,t2,t9
	b	cvtw_round
2:	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	sllv	t3,t2,v0
	srlv	t2,t2,t9
	b	cvtw_round

/*******************************************************************************
*
* cvtw_from_d - Convert to a word from double format
*
*/
	.globl GTEXT(cvtw_from_d)
FUNC_LABEL(cvtw_from_d)
	/*
	 * Break out the fields of the RS double value in gp registers (t2,t3)
	 * into:
	 *	t0 -- sign bit		     (left justified)
	 *	t1 -- exponent		     (right justified, still biased)
	 *	t2 -- fraction bits [51-32]  (implied one bit NOT set)
	 *	t3 -- fraction bits [31-0]
	 */
	srl	t1,t2,DEXP_SHIFT
	move	t0,t1
	and	t1,DEXP_MASK
	and	t0,SIGNBIT>>DEXP_SHIFT
	sll	t0,t0,DEXP_SHIFT
	and	t2,DFRAC_MASK

#ifdef DEBUG
	sw	t0, _fp_sign
	sw	t1, _fp_exp
	sw	t2, _fp_frA
	sw	t3, _fp_frB
#endif
	/*
	 * Check to see if this is a NaN or an infinity and set the invalid
	 * exception in the C1_SR (a3).  Setup the result depending if the
	 * enable for the invalid exception is set and if the value is a NaN
	 * or and infinity.
	 */
	bne	t1,DEXP_NAN,4f

	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,1f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result (implementation
	 * dependent) for infinities is the maximum or minimum value and for
	 * NaNs is the maximum positive value.
	 */
1:	bne	t2,zero,3f	/* is this a NaN? */
	bne	t3,zero,3f
	/* it is an infinity, so see what the sign is and return the result */
	bne	t0,zero,2f
	li	t2,WORD_MAX	/* plus infinity returns maximum word value */
	move	v0,zero
	b	rd_1w
2:	li	t2,WORD_MIN	/* minus infinity returns minimum word value */
	move	v0,zero
	b	rd_1w
3:	li	t2,WQUIETNAN_LEAST	/* NaNs return maximum positive value */
	move	v0,zero
	b	rd_1w
4:
	/*
	 * Check the operand for a zero value and return a zero if so.
	 */
	bne	t1,zero,1f
	bne	t2,zero,1f
	bne	t3,zero,1f
	/* t2 is already is zero so just use it */
	move	v0,zero
	b	rd_1w
1:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be converted.  For normalized
	 * numbers set the implied one and remove the exponent bias.  For
	 * denormalized numbers the result is an inexact zero.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	move	t2,zero		/* load the zero return value */
	li	t3,STKBIT	/* set the sticky bit */
	b	cvtw_round	/* branch to round */
1:	subu	t1,DEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */

	/*
	 * If the value is too small to have any integer digits then
	 * just set to zero with a sticky bit and round.
	 */
	bge	t1,WEXP_MIN,1f
	move	t2,zero		/* load the zero value */
	li	t3,STKBIT	/* load the sticky bit */
	b	cvtw_round	/* branch to round it */
1:
	/*
	 * If the exponent is too large then branch to set the overflow
	 * exception and to determine the result.  Note it is still possible
	 * to overflow after rounding in one case.
	 */
	bgt	t1,WEXP_MAX+1,cvtw_overflow
	/*
	 * A special check is needed for -1.0*2^31 so that it does not
	 * indicate an overflow and just returns the minimum word value.
	 */
	bne	t1,WEXP_MAX+1,1f
	bne	t2,DIMP_1BIT,cvtw_overflow
	bne	t3,zero,cvtw_overflow
	beq	t0,zero,cvtw_overflow
	li	t2,WORD_MIN
	move	v0,zero
	b	rd_1w
1:
	/*
	 * Now shift the fraction so it is a fix point value.
	 */
	subu	t9,t1,DFRAC_BITS-32	/* calculate the shift amount */
	/* Check to see if any shift is needed */
	beq	t9,zero,4f
	blt	t9,zero,2f	/* - if the shift amount is negative shift right */
	/* Shift the fraction left by the shift amount (t9) */
1:	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sllv	t2,t2,t9
	srlv	v1,t3,v0
	or	t2,v1
	sllv	t3,t3,t9
	b	4f
2:	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	sllv	v1,t3,v0
	srlv	t3,t3,t9
	beq	v1,zero,3f
	or	t3,STKBIT
3:	sllv	v1,t2,v0
	or	t3,v1
	srlv	t2,t2,t9
	b	cvtw_round

/*******************************************************************************
*
* cvtw_round -
*
* cvtw_round finishes the conversions to words (fixed point) by rounding
* the fixed point value and coverting it to 2-complement form.  It takes as
* input:
*	t0 -- sign bit		     (left justified)
*	t2 -- fixed point value
*	t3 -- fraction value	     (including the sticky bit)
* It handles the inexact exceptions that may happen and the one case that
* the overflow exception can occur due to rounding.
*/
cvtw_round:
	/*
	 * Now round the fixed point result.
	 */
	lw	v0,RM_OFFSET(sp)	/* operative Rounding Mode */
	beq	v0,CSR_RM_RN,3f		/* round to nearest */
	beq	v0,CSR_RM_RZ,5f		/* round to zero (truncate) */
	beq	v0,CSR_RM_RPI,1f	/* round to plus infinity */
	/* Round to minus infinity */
	beq	t0,zero,5f		/* - if the sign is plus truncate */
	b	2f
1:	/* Round to plus infinity */
	bne	t0,zero,5f		/* - if the sign is minus truncate */
2:	beq	t3,zero,5f		/* - if there are no fraction bits go on */
	addu	t2,1
	beq	t2,SIGNBIT,cvtw_overflow	/* - if overflow then branch */
	b	5f
	/* Round to nearest */
3:	li	v0,GUARDBIT		/* load the guard bit for rounding */
	not	v1,t3			/* set carry out for addition of the */
	sltu	t9,v1,v0		/*  the sticky register and guard bit */
	addu	v0,t3
	beq	t9,zero,4f		/* - if there was no carry out go on */
	addu	t2,1
	beq	t2,SIGNBIT,cvtw_overflow	/* - if overflow then branch */
4:	bne	v0,zero,5f		/* - if sticky register is zero clear the */
	li	v1,~1			/*  last bit in the fraction (round to */
	and	t2,v1			/*  nearest) */
5:
	/*
	 * If the value is negative negate it.
	 */
	beq	t0,zero,1f
	negu	t2
1:
	/*
	 * Check for the inexact exception and exit.
	 */
	move	v0,zero			/* a zero exit value (hopefully) */
	beq	t3,zero,1f		/* check for inexact exception */
cvtw_inexact:
	or	a3,INEXACT_EXC		/* set the inexact exception */
	and	v1,a3,INEXACT_ENABLE	/* see if inexact trap is enabled */
	beq	v1,zero,1f		/* - if it is enabled post a signal */
	li	v0, IV_FPA_PREC_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
1:
	b	rd_1w

/*
 * Overflows (which are invalid not overflow) on conversions to fixed point
 * which are trapped (implementation dependent) will delivered to the trap
 * handler the floating point value in widest supported format rounded to
 * fixed point.  This conversion is done in the signal handler (since theres
 * no place to put the widest supported format) and the result register is left
 * unmodified here.  If the invalid exception is enabled signal a SIGFPE and
 * leave the result register unmodified.  If the invalid exception is not
 * enabled then return the NaN value for a word.
 */
cvtw_overflow:
	or	a3,INVALID_EXC		/* set the invalid exception */
	and	v0,a3,INVALID_ENABLE	/* see if the invalid trap is enabled */
	beq	v0,zero,1f		/* - if it is enabled post a signal */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR		/* dont modify the result register */
1:
	/*
	 * The invalid trap was NOT enabled so the result (implementation
	 * dependent) is the NaN value for a word.
	 */
	li	t2,WQUIETNAN_LEAST
	move	v0,zero
	b	rd_1w

cvtw_from_e:
cvtw_from_q:
	b	illfpinst

	.globl cvtl
cvtl:
	la	v1,cvtl_from_tab
	addu	v1, v0, v1
	j	v1

	.set	noreorder
	nop
cvtl_from_tab:
	b	cvtl_from_s;	nop
	b	cvtl_from_d;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	b	illfpinst;	nop
	.set	reorder
	
/*******************************************************************************
*
* cvtl_from_s - Convert to a 64-bit word from single format
*
*/
	.globl cvtl_from_s
cvtl_from_s:
	/*
	 * Break out the fields of the RS single value in gp register (t2)
	 * into:
	 *	t0 -- sign bit		     (left justified)
	 *	t1 -- exponent		     (right justified, still biased)
	 *	t2 -- fraction bits [22-0]   (implied one bit NOT set)
	 */
	srl	t1,t2,SEXP_SHIFT
	move	t0,t1
	and	t1,SEXP_MASK
	and	t0,SIGNBIT>>SEXP_SHIFT
	sll	t0,t0,SEXP_SHIFT
	and	t2,SFRAC_MASK

	/*
	 * Check to see if this is a NaN or an infinity and set the invalid
	 * exception in the C1_SR (a3).  Setup the result depending if the
	 * enable for the invalid exception is set and if the value is a NaN
	 * or and infinity.
	 */
	bne	t1,SEXP_NAN,4f

	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,1f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result (implementation
	 * dependent) for infinities is the maximum or minimum value and for
	 * NaNs is the maximum positive value.
	 */	
1:	bne	t2,zero,3f	/* is this a NaN? */
	/* it is an infinity, so see what the sign is and return the result */
	bne	t0,zero,2f
	li	t2,LONG_MAX_HIGH	/* plus infinity returns maximum word value */
	li	t3,LONG_MAX_LOW
	move	v0,zero
	b	rd_2w
2:	li	t2,LONG_MIN_HIGH	/* minus infinity returns minimum word value */
	li	t3,LONG_MIN_LOW
	move	v0,zero
	b	rd_2w
3:	li	t2,LQUIETNAN_LEAST_HIGH	/* NaNs return maximum positive value */
	li	t3,LQUIETNAN_LEAST_LOW
	move	v0,zero
	b	rd_2w
4:
	/*
	 * Check the operand for a zero value and return a zero if so.
	 */
	bne	t1,zero,1f
	bne	t2,zero,1f
	/* t2 is already is zero so just use it */
	move	v0,zero
	b	rd_2w
1:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be converted.  For normalized
	 * numbers set the implied one and remove the exponent bias.  For
	 * denormalized numbers the result is an inexact zero.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	move	t2,zero		/* load the zero return value */
	move	t3,zero		/* load the zero return value */
	li	t4,STKBIT	/* set the sticky bit */
	b	cvtl_round	/* branch to round */
1:	subu	t1,SEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,SIMP_1BIT	/*  exponent bias, and set the implied 1 bit */

	/*
	 * If the value is too small to have any integer digits then
	 * just set to zero with a sticky bit and round.
	 */
	bge	t1,LEXP_MIN,1f
	move	t2,zero		/* load the zero value */
	move	t3,zero		/* load the zero value */
	li	t4,STKBIT	/* load the sticky bit */
	b	cvtl_round	/* branch to round it */
1:
	/*
	 * If the exponent is too large then branch to set the overflow
	 * exception and to determine the result.  Note it is still possible
	 * to overflow after rounding in one case.
	 */
	bgt	t1,LEXP_MAX+1,cvtl_overflow
	/*
	 * A special check is needed for -1.0*2^63 so that it does not
	 * indicate an overflow and just returns the minimum word value.
	 */
	bne	t1,LEXP_MAX+1,1f
	bne	t2,SIMP_1BIT,cvtl_overflow
	beq	t0,zero,cvtl_overflow
	li	t2,LONG_MIN_HIGH
	li	t3,LONG_MIN_LOW
	move	v0,zero
	b	rd_2w
1:
	/*
	 * Now shift the fraction so it is a fix point value.
	 */
	subu	t9,t1,SFRAC_BITS	/* calculate the shift amount */
	/* Check to see if any shift is needed */
	move	t4,zero		/* clear fraction */
	beq	t9,zero,cvtl_round
	blt	t9,zero,2f	/* - if the shift amount is negative shift right */
	/* positive shift amount */
1:	/* Shift the fraction left by the shift amount (t9) */
	bge	t9,32-SFRAC_BITS,1f
	/* shift left by 0-8 bits */
	sllv	t3,t2,t9	/* setup low bits */
	move	t2,zero		/* setup high bits */
	b	cvtl_round
1:
	bge	t9,32,1f
	/* shift left by 9-31 bits */
	sllv	t3,t2,t9	/* setup low bits */
	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	srlv	t2,t2,v0	/* setup high bits */
	b	cvtl_round
1:	/* shifting left by 32-63 bits */
	subu	t9,32		/* adjust shift count */
	sllv	t2,t2,t9	/* setup high bits */
	move	t3,zero		/* clear low bits */
	b	cvtl_round
2:	/* shifting right */
	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	sllv	t4,t2,v0	/* setup fraction */
	srlv	t3,t2,t9	/* setup low bits */
	move	t2,zero		/* clear high bits */
	b	cvtl_round

/*******************************************************************************
*
* cvtl_from_d - Convert to a 64-bit word from double format
*
*/
	.globl cvtl_from_d
cvtl_from_d:
	/*
	 * Break out the fields of the RS double value in gp registers (t2,t3)
	 * into:
	 *	t0 -- sign bit		     (left justified)
	 *	t1 -- exponent		     (right justified, still biased)
	 *	t2 -- fraction bits [51-32]  (implied one bit NOT set)
	 *	t3 -- fraction bits [31-0]
	 */
	srl	t1,t2,DEXP_SHIFT
	move	t0,t1
	and	t1,DEXP_MASK
	and	t0,SIGNBIT>>DEXP_SHIFT
	sll	t0,t0,DEXP_SHIFT
	and	t2,DFRAC_MASK

#ifdef DEBUG
	sw	t0, _fp_sign
	sw	t1, _fp_exp
	sw	t2, _fp_frA
	sw	t3, _fp_frB
#endif
	/*
	 * Check to see if this is a NaN or an infinity and set the invalid
	 * exception in the C1_SR (a3).  Setup the result depending if the
	 * enable for the invalid exception is set and if the value is a NaN
	 * or and infinity.
	 */
	bne	t1,DEXP_NAN,4f

	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,1f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR
	/*
	 * The invalid trap was NOT enabled so the result (implementation
	 * dependent) for infinities is the maximum or minimum value and for
	 * NaNs is the maximum positive value.
	 */
1:	bne	t2,zero,3f	/* is this a NaN? */
	bne	t3,zero,3f
	/* it is an infinity, so see what the sign is and return the result */
	bne	t0,zero,2f
	li	t2,LONG_MAX_HIGH	/* plus infinity returns maximum word value */
	li	t3,LONG_MAX_LOW
	move	v0,zero
	b	rd_2w
2:	li	t2,LONG_MIN_HIGH	/* minus infinity returns minimum word value */
	li	t3,LONG_MIN_LOW
	move	v0,zero
	b	rd_2w
3:	li	t2,LQUIETNAN_LEAST_HIGH	/* NaNs return maximum positive value */
	li	t3,LQUIETNAN_LEAST_LOW
	move	v0,zero
	b	rd_2w
4:
	/*
	 * Check the operand for a zero value and return a zero if so.
	 */
	bne	t1,zero,1f
	bne	t2,zero,1f
	bne	t3,zero,1f
	/* t2,t3 is already is zero so just use it */
	move	v0,zero
	b	rd_2w
1:
	/*
	 * Now that all the NaN, infinity and zero cases have been taken care
	 * of what is left are values that can be converted.  For normalized
	 * numbers set the implied one and remove the exponent bias.  For
	 * denormalized numbers the result is an inexact zero.
	 */
	bne	t1,zero,1f	/* check for RS being denormalized */
	move	t2,zero		/* load the zero return value */
	move	t3,zero		/* load the zero return value */
	li	t4,STKBIT	/* set the sticky bit */
	b	cvtl_round	/* branch to round */
1:	subu	t1,DEXP_BIAS	/* - if RS is not denormalized then remove the */
	or	t2,DIMP_1BIT	/*  exponent bias, and set the implied 1 bit */

	/*
	 * If the value is too small to have any integer digits then
	 * just set to zero with a sticky bit and round.
	 */
	bge	t1,LEXP_MIN,1f
	move	t2,zero		/* load the zero value */
	move	t3,zero		/* load the zero value */
	li	t4,STKBIT	/* load the sticky bit */
	b	cvtl_round	/* branch to round it */
1:
	/*
	 * If the exponent is too large then branch to set the overflow
	 * exception and to determine the result.  Note it is still possible
	 * to overflow after rounding in one case.
	 */
	bgt	t1,LEXP_MAX+1,cvtl_overflow
	
	/*
	 * A special check is needed for -1.0*2^63 so that it does not
	 * indicate an overflow and just returns the minimum word value.
	 */
	bne	t1,LEXP_MAX+1,1f
	bne	t2,DIMP_1BIT,cvtl_overflow
	bne	t3,zero,cvtl_overflow
	beq	t0,zero,cvtl_overflow
	li	t2,LONG_MIN_HIGH
	move	t3,zero
	move	v0,zero
	b	rd_2w
1:
	/*
	 * Now shift the fraction so it is a fix point value.
	 */
	subu	t9,t1,DFRAC_BITS-32	/* calculate the shift amount */
	move	t4,zero		/* clear fraction */
	/* Check to see if any shift is needed */
	beq	t9,zero,4f	/* ??? */
	blt	t9,zero,2f	/* - if the shift amount is negative shift right */
1:	/* Shift the fraction left by the shift amount (t9) */
	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sllv	t2,t2,t9	/* setup high bits */
	srlv	v1,t3,v0	/* shift down upper 'low' bits */
	or	t2,v1		/* combine shifted up low bits into high bits */
	sllv	t3,t3,t9	/* setup low bits */
	b	cvtl_round
2:	/* shift right XXX - not sure about this case */
	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	sllv	v1,t3,v0
	srlv	t3,t3,t9	/* position low bits */
	beq	v1,zero,3f
	or	t4,STKBIT	/* set sticky bit in fraction */
3:	sllv	v1,t2,v0
	or	t3,v1		/* merge in shift-down high bits */
	srlv	t2,t2,t9	/* position high bits */
	b	cvtl_round

/*******************************************************************************
*
* cvtl_round -
*
* cvtl_round finishes the conversions to 64-bit words (fixed point) by rounding
* the fixed point value and coverting it to 2-complement form.  It takes as
* input:
*	t0 -- sign bit		     (left justified)
*	t2 -- fixed point value high bits
*	t3 -- fixed point value low bits
*	t4 -- fraction value	     (including the sticky bit)
* It handles the inexact exceptions that may happen and the one case that
* the overflow exception can occur due to rounding.
*/
cvtl_round:
	/*
	 * Now round the fixed point result.
	 */
	lw	v0,RM_OFFSET(sp)	/* operative Rounding Mode */
	beq	v0,CSR_RM_RN,3f		/* round to nearest */
	beq	v0,CSR_RM_RZ,5f		/* round to zero (truncate) */
	beq	v0,CSR_RM_RPI,1f	/* round to plus infinity */
	/* Round to minus infinity */
	beq	t0,zero,5f		/* - if the sign is plus truncate */
	b	2f
1:	/* Round to plus infinity */
	bne	t0,zero,5f		/* - if the sign is minus truncate */
2:	beq	t4,zero,5f		/* - if there are no fraction bits go on */
	move	t5,t3			/* save unmodified t3 */
	addu	t3,1
	xor	t5,t3			/* if bit t3:31 changed, then t5:31 set */
	bge	t5,zero,1f
	addu	t2,1			/* add in carry from t3 */
1:
	beq	t2,SIGNBIT,cvtl_overflow	/* - if overflow then branch */
	b	5f
	/* Round to nearest */
3:	li	v0,GUARDBIT		/* load the guard bit for rounding */
	not	v1,t4			/* set carry out for addition of the */
	sltu	t9,v1,v0		/*  the sticky register and guard bit */
	addu	v0,t4
	beq	t9,zero,4f		/* - if there was no carry out go on */
	move	t5,t3			/* save unmodified t3 */
	addu	t3,1
	xor	t5,t3			/* if bit t3:31 changed, then t5:31 set */
	bge	t5,zero,1f
	addu	t2,1			/* add in carry from t3 */
1:
	beq	t2,SIGNBIT,cvtl_overflow	/* - if overflow then branch */
4:	bne	v0,zero,5f		/* - if sticky register is zero clear the */
	li	v1,~1			/*  last bit in the fraction (round to */
	and	t3,v1			/*  nearest) */
5:
	/*
	 * If the value is negative negate it.
	 */
	beq	t0,zero,1f
	negu	t3			/* negate low bits */
	not	t2			/* invert upper bits */
	bne	t3,zero,1f		/* t3==0 -> overflow during negate */
	addu	t2,1			/* increment upper bits */
1:
	/*
	 * Check for the inexact exception and exit.
	 */
	move	v0,zero			/* a zero exit value (hopefully) */
	beq	t4,zero,1f		/* check for inexact exception */
cvtl_inexact:
	or	a3,INEXACT_EXC		/* set the inexact exception */
	and	v1,a3,INEXACT_ENABLE	/* see if inexact trap is enabled */
	beq	v1,zero,1f		/* - if it is enabled post a signal */
	li	v0,IV_FPA_PREC_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
1:
	b	rd_2w

/*
 * Overflows (which are invalid not overflow) on conversions to fixed point
 * which are trapped (implementation dependent) will delivered to the trap
 * handler the floating point value in widest supported format rounded to
 * fixed point.  This conversion is done in the signal handler (since theres
 * no place to put the widest supported format) and the result register is left
 * unmodified here.  If the invalid exception is enabled signal a SIGFPE and
 * leave the result register unmodified.  If the invalid exception is not
 * enabled then return the NaN value for a 64-bit word.
 */
cvtl_overflow:
	or	a3,INVALID_EXC		/* set the invalid exception */
	and	v0,a3,INVALID_ENABLE	/* see if the invalid trap is enabled */
	beq	v0,zero,1f		/* - if it is enabled post a signal */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR		/* dont modify the result register */
1:
	/*
	 * The invalid trap was NOT enabled so the result (implementation
	 * dependent) is the NaN value for a 64-bit word.
	 */
	li	t2,LQUIETNAN_LEAST_HIGH
	li	t3,LQUIETNAN_LEAST_LOW
	move	v0,zero
	b	rd_2w

/*******************************************************************************
*
* norm_s -
*
* Normalize a single value and handle the overflow, underflow and inexact
* exceptions that may arise.  The input single value is as follows:
*	t0 -- sign bit		     (left justified)
*	t1 -- exponent		     (right justified, not biased)
*	t2 -- fraction bits [22-0]   (implied one bit set)
*	t8 -- fraction sticky bits
*/
	.globl GTEXT(norm_s)
FUNC_LABEL(norm_s)
	/*
	 * Determine the ammount to shift the fraction and adjust the exponent
	 * so the first one bit is in the implied 1 position.
	 */
	/*
	 * The first step in this process is to determine where the first
	 * one bit is in the fraction (t2,t8).  After this series of tests
	 * the shift count to shift the fraction left so the first 1 bit is
	 * in the high bit will be in t9.  This sequence of code uses registers
	 * v0,v1 and t9 (it could be done with two but with reorginization this
	 * is faster).  Note it is not possible for the first one bit to be in
	 * the sticky register (t8) but it does participate in the shift.
	 */
	move	v0,t2
	move	t9,zero
	bne	t2,zero,1f
	move	v0,t8
	addu	t9,32
1:

	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction.
	 */
	subu	t9,SFRAC_LEAD0S	/* the calulated shift amount */
	/* Check to see if any shift or adjustment is needed */
	beq	t9,zero,norm_s_noshift
	subu	t1,t9		/* adjust the exponent */
	blt	t9,zero,2f	/* - if the shift amount is negitive shift right */
	/* Shift the fraction left by the shift amount (t9) */
1:	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sllv	t2,t2,t9
	srlv	v1,t8,v0
	or	t2,v1
	sllv	t8,t8,t9
	b	4f
2:	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	beq	t8,zero,3f
	or	t8,STKBIT
3:	srlv	t8,t8,t9
	sllv	v1,t2,v0
	or	t8,v1
	srlv	t2,t2,t9
4:
	/*
	 * This point can be branched to instead of norm_s if it is known that
	 * the value is normalized.
	 */
norm_s_noshift:

	/*
	 * Now round the result.  The unrounded result (exponent and fraction)
	 * must be saved in the case of untrapped underflow so a correct
	 * denormalized number can be produced with only one rounding.
	 */
	move	t5,t1			/* save unrounded exponent */
	move	t6,t2			/* save unrounded fraction */
	lw	v0,RM_OFFSET(sp)	/* get the rounding mode */
	beq	v0,CSR_RM_RN,3f		/* round to nearest */
	beq	v0,CSR_RM_RZ,5f		/* round to zero (truncate) */
	beq	v0,CSR_RM_RPI,1f	/* round to plus infinity */
	/* Round to minus infinity */
	beq	t0,zero,5f		/* - if the sign is plus truncate */
	b	2f
1:	/* Round to plus infinity */
	bne	t0,zero,5f		/* - if the sign is minus truncate */
2:	beq	t8,zero,5f		/* - if not inexact go on */
	addu	t2,1
	bne	t2,SIMP_1BIT<<1,5f	/* see if the carry requires an exponent */
	addu	t1,1			/*  adjustment and the fraction to be */
	srl	t2,t2,1			/*  shifted */
	b	5f
	/* Round to nearest */
3:	li	v0,GUARDBIT		/* load the guard bit for rounding */
	not	v1,t8			/* set carry out for addition of the */
	sltu	t9,v1,v0		/*  the sticky register and guard bit */
	addu	v0,t8
	beq	t9,zero,4f		/* - if there was no carry out go on */
	addu	t2,1
	bne	t2,SIMP_1BIT<<1,4f	/* see if the carry requires an exponent */
	addu	t1,1			/*  adjustment and the fraction to be */
	srl	t2,t2,1			/*  shifted */
4:	bne	v0,zero,5f		/* - if sticky register is zero clear the */
	li	v1,~1			/*  last bit in the fraction (round to */
	and	t2,v1			/*  nearest) */
5:
	/*
	 * Now check for overflow and produce the correct result for both the
	 * trapped and untrapped cases.
	 */
	ble	t1,SEXP_MAX,9f		/* branch if no overflow */
	or	a3,OVERFLOW_EXC		/* set the overflow flags in C1_SR (a3) */
	and	v0,a3,OVERFLOW_ENABLE	/* see if overflow trap is enabled */
	beq	v0,zero,1f
	/*
	 * The overflow trap was enabled so signal a SIGFPE and put the correct
	 * result in the destination register.
	 */
	li	v0, IV_FPA_OVF_VEC
	jal	post_signal
	subu	t1,SEXP_OU_ADJ-SEXP_BIAS /* adjust the exponent down */
	sll	t1,t1,SEXP_SHIFT
	and	t2,~SIMP_1BIT		/* clear implied 1 */
	or	t2,t0			/* put the sign back in */
	or	t2,t1			/* put the exponent back in */
	beq	t8,zero,L1000		/* check for inexact exception */
	or	a3,INEXACT_EXC		/* set the inexact exception */
L1000:	li	v0,1			/* a non-zero exit value */
	b	rd_1w
	/*
	 * The overflow trap was not enabled so just put the correct
	 * result in the destination register according to the rounding
	 * mode.  Also set the inexact trap and if it is enabled signal a
	 * SIGFPE.
	 */
1:	move	v0,zero			/* zero exit value (hopefully) */
	or	a3,INEXACT_EXC		/* set the inexact exception */
	and	v1,a3,INEXACT_ENABLE	/* see if inexact trap is enabled */
	beq	v1,zero,2f		/* - if it is enabled post a signal */
	li	v0,SIGFPE
	li	v0, IV_FPA_PREC_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
2:	lw	v1,RM_OFFSET(sp)	/* get the rounding mode */
	beq	v1,CSR_RM_RN,8f		/* round to nearest */
	beq	v1,CSR_RM_RZ,7f		/* round to zero (truncate) */
	beq	v1,CSR_RM_RPI,5f	/* round to plus infinity */
	/*
	 * Round to minus infinity caries negative results to minus infinity and
	 * positive results to the formats largest positive finite number.
	 */
3:	beq	t0,zero,4f
	li	t2,SIGNBIT|(SEXP_INF<<SEXP_SHIFT)
	b	rd_1w
4:	li	t2,((SEXP_MAX+SEXP_BIAS)<<SEXP_SHIFT)|SFRAC_LEAST_MAX
	b	rd_1w
	/*
	 * Round to plus infinity caries positive results to plus infinity and
	 * negative results to the formats largest negative finite number.
	 */
5:	bne	t0,zero,6f
	li	t2,SEXP_INF<<SEXP_SHIFT
	b	rd_1w
6:	li	t2,SIGNBIT|((SEXP_MAX+SEXP_BIAS)<<SEXP_SHIFT)|SFRAC_LEAST_MAX
	b	rd_1w
	/*
	 * Round to zero caries the result to the formats largest finite
	 * number with the sign of the result.
	 */
7:	or	t2,t0,((SEXP_MAX+SEXP_BIAS)<<SEXP_SHIFT)|SFRAC_LEAST_MAX
	b	rd_1w
	/*
	 * Round to nearest caries the result to infinity with the sign of the
	 * result.
	 */
8:	or	t2,t0,SEXP_INF<<SEXP_SHIFT
	b	rd_1w
9:
	/*
	 * Now check for underflow and produce the correct result for both the
	 * trapped and untrapped cases.  In the Mips implemention "tininess"
	 * is detected "after rounding" and "loss of accuracy" is detected as
	 * "an inexact result".
	 */
	/*
	 * If underflow is signaled differently if the underflow trap is
	 * enabled or not enabled.  So see if the trap is enabled.
	 */
	and	v0,a3,UNDERFLOW_ENABLE	/* see if underflow trap is enabled */
	beq	v0,zero,2f		/* branch if the trap is not enabled */
	/*
	 * The underflow trap is enabled so the underflow is to be signaled
	 * when "tininess" is detected regardless of "loss of accuracy".
	 */
	bge	t1,SEXP_MIN,L3000	/* check for tininess */
	/*
	 * Underflow has occured and the underflow trap was enabled so signal a
	 * SIGFPE and put the correct result in the destination register.
	 */
	or	a3,UNDERFLOW_EXC
	li	v0, IV_FPA_UFL_VEC
	jal	post_signal
	addu	t1,SEXP_OU_ADJ+SEXP_BIAS /* adjust the exponent up */
	sll	t1,t1,SEXP_SHIFT
	and	t2,~SIMP_1BIT		/* clear implied one bit */
	or	t2,t0			/* put the sign back in */
	or	t2,t1			/* put the exponent back in */
	beq	t8,zero,1f		/* check for inexact exception */
	or	a3,INEXACT_EXC		/* set the inexact exception */
1:	li	v0,1			/* a non-zero exit value */
	b	rd_1w
	/*
	 * The underflow trap is not enabled so the underflow is to be signaled
	 * when both "tininess" and "loss of accuracy" is detected.
	 */
2:	bge	t1,SEXP_MIN,L3000	/* check for tininess */
	/*
	 * Now that tininess has occrued the number will be a denormalized
	 * number or zero.  So produce the denormalized or zero value from
	 * the unrounded result and then check for "loss of accuracy" to
	 * see if underflow is to be detected.
	 */
	move	t1,t5			/* get the unrounded exponent */
	move	t2,t6			/* get the unrounded fraction */
	subu	t1,SEXP_MIN		/* calculate the shift amnount to */
	negu	t1			/*  make the value a denormalized value */
	blt	t1,SFRAC_BITS+2,3f	/* - if the shift amount would shift out */
	move	t2,zero			/*  all the fraction bits then the result */
	li	t8,STKBIT		/*  will be an inexact zero. */
	b 	7f
3:	negu	v0,t1			/* shift the fraction < 32 bits */
	addu	v0,32
	sllv	v1,t8,v0		/* make sure the sticky bit stays set */
	srlv	t8,t8,t1
	beq	v1,zero,6f
	or	t8,STKBIT
6:	sllv	v1,t2,v0
	or	t8,v1
	srlv	t2,t2,t1
7:
	/*
	 * Now round the denormalized result.
	 */
	lw	v0,RM_OFFSET(sp)	/* get the rounding mode */
	beq	v0,CSR_RM_RN,3f		/* round to nearest */
	beq	v0,CSR_RM_RZ,L2000	/* round to zero (truncate) */
	beq	v0,CSR_RM_RPI,1f	/* round to plus infinity */
	/* Round to minus infinity */
	beq	t0,zero,L2000		/* - if the sign is plus truncate */
	b	2f
1:	/* Round to plus infinity */
	bne	t0,zero,L2000		/* - if the sign is minus truncate */
2:	beq	t8,zero,L2000		/* - if not inexact go on */
	addu	t2,1
	b	L2000
	/* Round to nearest */
3:	li	v0,GUARDBIT		/* load the guard bit for rounding */
	not	v1,t8			/* set carry out for addition of the */
	sltu	t9,v1,v0		/*  the sticky register and guard bit */
	addu	v0,t8
	beq	t9,zero,4f		/* - if there was no carry out go on */
	addu	t2,1
4:	bne	v0,zero,L2000		/* - if sticky register is zero clear the */
	li	v1,~1			/*  last bit in the fraction (round to */
	and	t2,v1			/*  nearest) */
	/*
	 * At this point "tininess" has been detected so now if "loss of
	 * accurcy" has also occured then underflow has occured. (the
	 * detection of underflow in untrapped underflow case).
	 */
L2000:	beq	t8,zero,7f		/* test for "loss of accurcy" */
	or	a3,UNDERFLOW_EXC	/* set the underflow exception */
	or	a3,INEXACT_EXC		/* set the inexact exception */
	and	v0,a3,INEXACT_ENABLE	/* see if inexact trap is enabled */
	beq	v0,zero,7f		/* - if it is enabled post a signal */
	li	v0, IV_FPA_PREC_VEC	/* FIX ? */
	jal	post_signal
	/*
	 * Now put together the denormalized or zero result and exit. Note the
	 * exponet field is always zero, and there never is an implied 1 bit.
	 */
	or	t2,t0			/* put back the sign */
	li	v0,1			/* a non-zero exit value */
	b	rd_1w
	/*
	 * Now put together the denormalized or zero result and exit. Note the
	 * exponet field is always zero, and there never is an implied 1 bit.
	 */
7:	or	t2,t0			/* put back the sign */
	move	v0,zero			/* a zero exit value */
	b	rd_1w

	/*
	 * Now check for inexact exception, set the inexact exception if so and
	 * if the trap is enabled signal a SIGFPE.
	 */
L3000:	move	v0,zero			/* a zero exit value (hopefully) */
	beq	t8,zero,1f		/* check for inexact exception */
	or	a3,INEXACT_EXC		/* set the inexact exception */
	and	v0,a3,INEXACT_ENABLE	/* see if inexact trap is enabled */
	beq	v0,zero,1f		/* - if it is enabled post a signal */
	li	v0, IV_FPA_PREC_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
1:
	and	t2,~SIMP_1BIT		/* clear the implied 1 */
	or	t2,t0			/* put the sign back in */
	addu	t1,SEXP_BIAS		/* add back in the exponent bias */
	sll	t1,t1,SEXP_SHIFT	/* shift the exponent back in place */
	or	t2,t1			/* put the exponent back in */
	b	rd_1w

/*******************************************************************************
*
* norm_d -
*
* Normalize a double value and handle the overflow, underflow and inexact
* exceptions that may arise.  The input double value is as follows:
*	t0 -- sign bit		     (left justified)
*	t1 -- exponent		     (right justified, not biased)
*	t2 -- fraction bits [51-32]  (implied one bit set)
*	t3 -- fraction bits [31-0]
*	t8 -- fraction sticky bits
*/
	.globl GTEXT(norm_d)
FUNC_LABEL(norm_d)
	/*
	 * Determine the ammount to shift the fraction and adjust the exponent
	 * so the first one bit is in the implied 1 position.
	 */
	/*
	 * The first step in this process is to determine where the first
	 * one bit is in the fraction (t2,t3,t8).  After this series of tests
	 * the shift count to shift the fraction left so the first 1 bit is
	 * in the high bit will be in t9.  This sequence of code uses registers
	 * v0,v1 and t9 (it could be done with two but with reorginization this
	 * is faster).  Note it is not possible for the first one bit to be in
	 * the sticky register (t8) but it does participate in the shift.
	 */
	move	v0,t2
	move	t9,zero
	bne	t2,zero,1f
	move	v0,t3
	addu	t9,32
	bne	t3,zero,1f
	move	v0,t8
	addu	t9,32
1:
	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction.
	 */
	subu	t9,DFRAC_LEAD0S	/* the calulated shift amount */
	/* Check to see if any shift or adjustment is needed */
	beq	t9,zero,norm_d_noshift
	subu	t1,t9		/* adjust the exponent */
	blt	t9,zero,2f	/* - if the shift amount is negitive shift right */
	/* Shift the fraction left by the shift amount (t9) */
	blt	t9,32,1f
	subu	t9,32		/* shift the fraction left for >= 32 bit shifts */
	negu	v0,t9
	addu	v0,32
	sllv	t2,t3,t9
	srlv	v1,t8,v0
	or	t2,v1
	sllv	t3,t8,t9
	move	t8,zero
	b	4f
1:	negu	v0,t9		/* shift the fraction left for < 32 bit shifts */
	addu	v0,32
	sllv	t2,t2,t9
	srlv	v1,t3,v0
	or	t2,v1
	sllv	t3,t3,t9
	srlv	v1,t8,v0
	or	t3,v1
	sllv	t8,t8,t9
	b	4f
2:	move	v0,t9		/* shift the fraction right for < 32 bit shifts */
	negu	t9		/* Note the shift amount (t9) starts out negative */
	addu	v0,32		/*  for right shifts. */
	beq	t8,zero,3f
	or	t8,STKBIT
3:	srlv	t8,t8,t9
	sllv	v1,t3,v0
	or	t8,v1
	srlv	t3,t3,t9
	sllv	v1,t2,v0
	or	t3,v1
	srlv	t2,t2,t9
4:
	/*
	 * This point can be branched to instead of norm_d if it is known that
	 * the value is normalized.
	 */
norm_d_noshift:

	/*
	 * Now round the result.  The unrounded result (exponent and fraction)
	 * must be saved in the case of untrapped underflow so a correct
	 * denormalized number can be produced with only one rounding.
	 */
	move	t5,t1			/* save unrounded exponent */
	move	t6,t2			/* save unrounded fraction (less) */
	move	t7,t3			/* save unrounded fraction (least) */
	lw	v0,RM_OFFSET(sp)	/* get the rounding mode */
	beq	v0,CSR_RM_RN,3f		/* round to nearest */
	beq	v0,CSR_RM_RZ,5f		/* round to zero (truncate) */
	beq	v0,CSR_RM_RPI,1f	/* round to plus infinity */
	/* Round to minus infinity */
	beq	t0,zero,5f		/* - if the sign is plus truncate */
	b	2f
1:	/* Round to plus infinity */
	bne	t0,zero,5f		/* - if the sign is minus truncate */
2:	beq	t8,zero,5f		/* - if not inexact go on */
	addu	t3,1
	bne	t3,zero,5f		/* - if there was no carry out go on */
	addu	t2,1
	bne	t2,DIMP_1BIT<<1,5f	/* see if the carry requires an exponent */
	addu	t1,1			/*  adjustment and the fraction to be */
	srl	t2,t2,1			/*  shifted */
	b	5f
	/* Round to nearest */
3:	li	v0,GUARDBIT		/* load the guard bit for rounding */
	.globl GTEXT(point4)
FUNC_LABEL(point4)
	not	v1,t8			/* set carry out for addition of the */
	sltu	t9,v1,v0		/*  the sticky register and guard bit */
	addu	v0,t8
	beq	t9,zero,4f		/* - if there was no carry out go on */
	addu	t3,1
	bne	t3,zero,4f		/* - if there was no carry out go on */
	addu	t2,1
	bne	t2,DIMP_1BIT<<1,4f	/* see if the carry requires an exponent */
	addu	t1,1			/*  adjustment and the fraction to be */
	srl	t2,t2,1			/*  shifted */
4:	bne	v0,zero,5f		/* - if sticky register is zero clear the */
	li	v1,~1			/*  last bit in the fraction (round to */
	and	t3,v1			/*  nearest) */
5:
	/*
	 * Now check for overflow and produce the correct result for both the
	 * trapped and untrapped cases.
	 */
	ble	t1,DEXP_MAX,9f		/* branch if no overflow */
	or	a3,OVERFLOW_EXC		/* set the overflow flags in C1_SR (a3) */
	and	v0,a3,OVERFLOW_ENABLE	/* see if overflow trap is enabled */
	beq	v0,zero,1f
	/*
	 * The overflow trap was enabled so signal a SIGFPE and put the correct
	 * result in the destination register.
	 */
	li	v0, IV_FPA_OVF_VEC
	jal	post_signal
	subu	t1,DEXP_OU_ADJ-DEXP_BIAS /* adjust the exponent down */
	sll	t1,t1,DEXP_SHIFT
	and	t2,~DIMP_1BIT		/* clear implied 1 */
	or	t2,t0			/* put the sign back in */
	or	t2,t1			/* put the exponent back in */
	beq	t8,zero,L100		/* check for inexact exception */
	or	a3,INEXACT_EXC		/* set the inexact exception */
L100:	li	v0,1			/* a non-zero exit value */
	b	rd_2w
	/*
	 * The overflow trap was not enabled so just put the correct
	 * result in the destination register according to the rounding
	 * mode.  Also set the inexact trap and if it is enabled signal a
	 * SIGFPE.
	 */
1:	move	v0,zero			/* zero exit value (hopefully) */
	or	a3,INEXACT_EXC		/* set the inexact exception */
	and	v1,a3,INEXACT_ENABLE	/* see if inexact trap is enabled */
	beq	v1,zero,2f		/* - if it is enabled post a signal */
	li	v0, IV_FPA_PREC_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
2:	lw	v1,RM_OFFSET(sp)	/* get the rounding mode */
	beq	v1,CSR_RM_RN,8f		/* round to nearest */
	beq	v1,CSR_RM_RZ,7f		/* round to zero (truncate) */
	beq	v1,CSR_RM_RPI,5f	/* round to plus infinity */
	/*
	 * Round to minus infinity caries negative results to minus infinity and
	 * positive results to the formats largest positive finite number.
	 */
3:	beq	t0,zero,4f
	li	t2,SIGNBIT|(DEXP_INF<<DEXP_SHIFT)
	move	t3,zero
	b	rd_2w
4:	li	t2,((DEXP_MAX+DEXP_BIAS)<<DEXP_SHIFT)|DFRAC_LESS_MAX
	li	t3,DFRAC_LEAST_MAX
	b	rd_2w
	/*
	 * Round to plus infinity caries positive results to plus infinity and
	 * negative results to the formats largest negative finite number.
	 */
5:	bne	t0,zero,6f
	li	t2,DEXP_INF<<DEXP_SHIFT
	move	t3,zero
	b	rd_2w
6:	li	t2,SIGNBIT|((DEXP_MAX+DEXP_BIAS)<<DEXP_SHIFT)|DFRAC_LESS_MAX
	li	t3,DFRAC_LEAST_MAX
	b	rd_2w
	/*
	 * Round to zero caries the result to the formats largest finite
	 * number with the sign of the result.
	 */
7:	or	t2,t0,((DEXP_MAX+DEXP_BIAS)<<DEXP_SHIFT)|DFRAC_LESS_MAX
	li	t3,DFRAC_LEAST_MAX
	b	rd_2w
	/*
	 * Round to nearest caries the result to infinity with the sign of the
	 * result.
	 */
8:	or	t2,t0,DEXP_INF<<DEXP_SHIFT
	move	t3,zero
	b	rd_2w
9:
	/*
	 * Now check for underflow and produce the correct result for both the
	 * trapped and untrapped cases.  In the Mips implemention "tininess"
	 * is detected "after rounding" and "loss of accuracy" is detected as
	 * "an inexact result".
	 */
	/*
	 * If underflow is signaled differently if the underflow trap is
	 * enabled or not enabled.  So see if the trap is enabled.
	 */
	and	v0,a3,UNDERFLOW_ENABLE	/* see if underflow trap is enabled */
	beq	v0,zero,2f		/* branch if the trap is not enabled */
	/*
	 * The underflow trap is enabled so the underflow is to be signaled
	 * when "tininess" is detected regardless of "loss of accuracy".
	 */
	bge	t1,DEXP_MIN,L300	/* check for tininess */
	/*
	 * Underflow has occured and the underflow trap was enabled so signal a
	 * SIGFPE and put the correct result in the destination register.
	 */
	or	a3,UNDERFLOW_EXC
	li	v0, IV_FPA_UFL_VEC
	jal	post_signal
	addu	t1,DEXP_OU_ADJ+DEXP_BIAS /* adjust the exponent up */
	sll	t1,t1,DEXP_SHIFT
	and	t2,~DIMP_1BIT		/* clear implied one bit */
	or	t2,t0			/* put the sign back in */
	or	t2,t1			/* put the exponent back in */
	beq	t8,zero,1f		/* check for inexact exception */
	or	a3,INEXACT_EXC		/* set the inexact exception */
1:	li	v0,1			/* a non-zero exit value */
	b	rd_2w
	/*
	 * The underflow trap is not enabled so the underflow is to be signaled
	 * when both "tininess" and "loss of accuracy" is detected.
	 */
2:	bge	t1,DEXP_MIN,L300	/* check for tininess */
	/*
	 * Now that tininess has occrued the number will be a denormalized
	 * number or zero.  So produce the denormalized or zero value from
	 * the unrounded result and then check for "loss of accuracy" to
	 * see if underflow is to be detected.
	 */
	move	t1,t5			/* get the unrounded exponent */
	move	t2,t6			/* get the unrounded fraction (less) */
	move	t3,t7			/* get the unrounded fraction (least) */
	.globl GTEXT(point7)
FUNC_LABEL(point7)
	subu	t1,DEXP_MIN		/* calculate the shift amnount to */
	negu	t1			/*  make the value a denormalized value */
	blt	t1,DFRAC_BITS+2,3f	/* - if the shift amount would shift out */
	move	t2,zero			/*  all the fraction bits then the result */
	move	t3,zero			/*  will be an inexact zero. */
	li	t8,STKBIT
	b 	7f
3:	blt	t1,32,5f
	subu	t1,32			/* shift the fraction >= 32 bits */
	beq	t8,zero,4f		/* make sure the sticky bit stays set */
	or	t3,STKBIT		/*  if there are any bits in sticky reg. */
4:	move	t8,t3
	move	t3,t2
	move	t2,zero
	negu	v0,t1
	addu	v0,32
	srlv	t8,t8,t1
	sllv	v1,t3,v0
	or	t8,v1
	srlv	t3,t3,t1
	b	7f
5:	negu	v0,t1			/* shift the fraction < 32 bits */
	addu	v0,32
	sllv	v1,t8,v0		/* make sure the sticky bit stays set */
	srlv	t8,t8,t1
	beq	v1,zero,6f
	or	t8,STKBIT
6:	sllv	v1,t3,v0
	or	t8,v1
	srlv	t3,t3,t1
	sllv	v1,t2,v0
	or	t3,v1
	srlv	t2,t2,t1
7:
	/*
	 * Now round the denormalized result.
	 */
	lw	v0,RM_OFFSET(sp)	/* get the rounding mode */
	beq	v0,CSR_RM_RN,3f		/* round to nearest */
	beq	v0,CSR_RM_RZ,L200	/* round to zero (truncate) */
	beq	v0,CSR_RM_RPI,1f	/* round to plus infinity */
	/* Round to minus infinity */
	beq	t0,zero,L200		/* - if the sign is plus truncate */
	b	2f
1:	/* Round to plus infinity */
	bne	t0,zero,L200		/* - if the sign is minus truncate */
2:	beq	t8,zero,L200		/* - if not inexact go on */
	addu	t3,1
	bne	t3,zero,L200		/* - if there was no carry out go on */
	addu	t2,1
	b	L200
	/* Round to nearest */
3:	li	v0,GUARDBIT		/* load the guard bit for rounding */
	.globl GTEXT(point8)
FUNC_LABEL(point8)
	not	v1,t8			/* set carry out for addition of the */
	sltu	t9,v1,v0		/*  the sticky register and guard bit */
	addu	v0,t8
	beq	t9,zero,4f		/* - if there was no carry out go on */
	addu	t3,1
	bne	t3,zero,4f		/* - if there was no carry out go on */
	addu	t2,1
4:	bne	v0,zero,L200		/* - if sticky register is zero clear the */
	li	v1,~1			/*  last bit in the fraction (round to */
	and	t3,v1			/*  nearest) */
	/*
	 * At this point "tininess" has been detected so now if "loss of
	 * accurcy" has also occured then underflow is has occured. (the
	 * detection of underflow in untrapped underflow case).
	 */
L200:	beq	t8,zero,7f		/* test for "loss of accurcy" */
	or	a3,UNDERFLOW_EXC	/* set the underflow exception */
	or	a3,INEXACT_EXC		/* set the inexact exception */
	and	v0,a3,INEXACT_ENABLE	/* see if inexact trap is enabled */
	beq	v0,zero,7f		/* - if it is enabled post a signal */
	li	v0, IV_FPA_PREC_VEC
	jal	post_signal
	/*
	 * Now put together the denormalized or zero result and exit. Note the
	 * exponet field is always zero, and there never is an implied 1 bit.
	 */
	or	t2,t0			/* put back the sign */
	li	v0,1			/* a non-zero exit value */
	b	rd_2w
	/*
	 * Now put together the denormalized or zero result and exit. Note the
	 * exponet field is always zero, and there never is an implied 1 bit.
	 */
7:	or	t2,t0			/* put back the sign */
	move	v0,zero			/* a zero exit value */
	b	rd_2w

	/*
	 * Now check for inexact exception, set the inexact exception if so and
	 * if the trap is enabled signal a SIGFPE.
	 */
L300:	move	v0,zero			/* a zero exit value (hopefully) */
	beq	t8,zero,1f		/* check for inexact exception */
	or	a3,INEXACT_EXC		/* set the inexact exception */
	and	v0,a3,INEXACT_ENABLE	/* see if inexact trap is enabled */
	beq	v0,zero,1f		/* - if it is enabled post a signal */
	li	v0, IV_FPA_PREC_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
1:
	and	t2,~DIMP_1BIT		/* clear the implied 1 */
	or	t2,t0			/* put the sign back in */
	addu	t1,DEXP_BIAS		/* add back in the exponent bias */
	sll	t1,t1,DEXP_SHIFT	/* shift the exponent back in place */
	or	t2,t1			/* put the exponent back in */
	b	rd_2w

norm_e:
norm_q:
	b	illfpinst

/*******************************************************************************
*
* rs_breakout_s -
*
* This leaf routine is called to break out the fields of the RS single value
* in gp register (t2) into:
*	t0 -- sign bit		     (left justified)
*	t1 -- exponent		     (right justified, still biased)
*	t2 -- fraction bits [22-0]   (implied one bit NOT set)
* If the value is a NaN then the action for it is taken and this routine will
* then branch to rd_[124]w: or store_C1_SR: to exit softFp() after converting
* the NaN to the format specified in (t9).  If the value is a quiet NaN then
* if (v1) is non-zero then RT must be checked for a signaling NaN.
*/
rs_breakout_s:
	srl	t1,t2,SEXP_SHIFT
	move	t0,t1
	and	t1,SEXP_MASK
	and	t0,SIGNBIT>>SEXP_SHIFT
	sll	t0,t0,SEXP_SHIFT
	and	t2,SFRAC_MASK

	/* If this is not a NaN then return */
	beq	t1,SEXP_NAN,1f
	j	ra
1:	bne	t2,zero,2f
	j	ra

2:	/* Check to see if this is a signaling NaN */
	and	v0,t2,SSNANBIT_MASK
	bne	v0,zero,4f
	/*
	 * RS is not a signaling NaN so if (v1) is non-zero check RT for a
	 * signaling NaN and if it is return the default quiet nan.
	 */
	beq	v1,zero,3f
	/* Check RT for a signaling NaN */
	srl	t5,t6,SEXP_SHIFT
	move	t4,t5
	and	t5,SEXP_MASK
	and	t4,SIGNBIT>>SEXP_SHIFT
	sll	t4,t4,SEXP_SHIFT
	and	t6,SFRAC_MASK

	bne	t5,SEXP_NAN,3f
	beq	t6,zero,3f
	and	v0,t6,SSNANBIT_MASK
	bne	v0,zero,4f

	/*
	 * RS and RT are not a signaling NaNs so just use RS as the result by
	 * converting it to the format specified in (t9) preserving the
	 * high bits of the fraction.
	 */
3:	sll	t9, t9, 1
	la	v1,rs_snan_fmt
	addu	v1, t9, v1	
	j	v1

	.set	noreorder
rs_snan_fmt:
	b	rs_snan_s;	nop
	b	rs_snan_d;	nop
	.set	reorder

	/*
	 * This is a signaling NaN so set the invalid exception in the C1_SR
	 * (a3) and setup the result depending if the enable for the invalid
	 * exception is set.
	 */
4:	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,5f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR
5:
	/*
	 * The invalid trap was NOT enabled so the result is a quiet version
	 * of the NaN.  So use the default quiet NaN to build a quiet of the
	 * in the format specified in (t9) preserving the high bits of the
	 * fraction.
	 */
	move	t0,zero
	li	t1,SEXP_NAN
	li	t2,SQUIETNAN_LEAST & SFRAC_MASK
	sll	t9, t9, 1
	la	v1,rs_snan_fmt
	addu	v1, t9, v1
	j	v1

rs_snan_s:
	or	t2,t0
	sll	t1,t1,SEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_1w

rs_snan_d:
	sll	t3,t2,DFRAC_BITS-SFRAC_BITS
	srl	t2,t2,32-(DFRAC_BITS-SFRAC_BITS)
	or	t2,t0
	or	t2,DEXP_NAN<<DEXP_SHIFT
	move	v0,zero
	b	rd_2w

/*******************************************************************************
*
* rs_breakout_d -
*
* This leaf routine is called to break out the fields of the RS double value
* in gp registers (t2,t3) into:
*	t0 -- sign bit		     (left justified)
*	t1 -- exponent		     (right justified, still biased)
*	t2 -- fraction bits [51-32]  (implied one bit NOT set)
*	t3 -- fraction bits [31-0]
* If the value is a NaN then the action for it is taken and this routine will
* then branch to rd_[124]w: or store_C1_SR: to exit softFp() after converting
* the NaN to the format specified in (t9).  If the value is a quiet NaN then
* if (v1) is non-zero then RT must be checked for a signaling NaN.
*/
rs_breakout_d:
	srl	t1,t2,DEXP_SHIFT
	move	t0,t1
	and	t1,DEXP_MASK
	and	t0,SIGNBIT>>DEXP_SHIFT
	sll	t0,t0,DEXP_SHIFT
	and	t2,DFRAC_MASK

	/* If this is not a NaN then return */
	beq	t1,DEXP_NAN,1f
	j	ra
1:	bne	t2,zero,2f
	bne	t3,zero,2f
	j	ra

2:	/* Check to see if this is a signaling NaN */
	and	v0,t2,DSNANBIT_MASK
	bne	v0,zero,4f
	/*
	 * RS is not a signaling NaN so if (v1) is non-zero check RT for a
	 * signaling NaN and if it is use the default quiet NaN.
	 */
	beq	v1,zero,3f
	/* Check RT for a signaling NaN */
	srl	t5,t6,DEXP_SHIFT
	move	t4,t5
	and	t5,DEXP_MASK
	and	t4,SIGNBIT>>DEXP_SHIFT
	sll	t4,t4,DEXP_SHIFT
	and	t6,DFRAC_MASK

	bne	t5,DEXP_NAN,3f
	beq	t6,zero,3f
	and	v0,t6,DSNANBIT_MASK
	bne	v0,zero,4f

	/*
	 * RS and RT are not a signaling NaNs so just use RS as the result by
	 * converting it to the format specified in (t9) preserving the
	 * high bits of the fraction.
	 */
3:	sll	t9, t9, 1
	la	v1,rs_dnan_fmt
	addu	v1, t9, v1
	j	v1

	.set	noreorder
rs_dnan_fmt:
	b	rs_dnan_s;	nop
	b	rs_dnan_d;	nop
	.set	reorder
	/*
	 * This is a signaling NaN so set the invalid exception in the C1_SR
	 * (a3) and setup the result depending if the enable for the invalid
	 * exception is set.
	 */
4:	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,5f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR
5:
	/*
	 * The invalid trap was NOT enabled so the result is a quiet version
	 * of the NaN.  So use the default quiet NaN to build a NaN
	 * in the format specified in (t9) preserving the high bits of the
	 * fraction.
	 */
	move	t0,zero
	li	t1,DEXP_NAN
	li	t2,DQUIETNAN_LESS & SFRAC_MASK
	li	t3,DQUIETNAN_LEAST
	sll	t9, t9, 1
	la	v1,rs_dnan_fmt
	addu	v1, t9, v1
	j	v1


rs_dnan_s:
	srl	t3,t3,(DFRAC_BITS-SFRAC_BITS)
	sll	t2,t2,32-(DFRAC_BITS-SFRAC_BITS)
	or	t2,t3
	bne	t2,zero,1f
	li	t2,SQUIETNAN_LEAST & SFRAC_MASK
1:	or	t2,t0
	or	t2,SEXP_NAN<<SEXP_SHIFT
	move	v0,zero
	b	rd_1w

rs_dnan_d:
	or	t2,t0
	sll	t1,t1,DEXP_SHIFT
	or	t2,t1
	move	v0,zero
	b	rd_2w

/*******************************************************************************
*
* rt_breakout_s -
*
* This leaf routine is called to break out the fields of the RT single value
* in gp registers (t6) into:
*	t4 -- sign bit		     (left justified)
*	t5 -- exponent		     (right justified, still biased)
*	t6 -- fraction bits [22-0]   (implied one bit NOT set)
* If the value is a NaN then the action for it is taken and this routine will
* then branch to rd_1w: or store_C1_SR: to exit softFp().
*
*/
rt_breakout_s:
	srl	t5,t6,SEXP_SHIFT
	move	t4,t5
	and	t5,SEXP_MASK
	and	t4,SIGNBIT>>SEXP_SHIFT
	sll	t4,t4,SEXP_SHIFT
	and	t6,SFRAC_MASK

	/* If this is not a NaN then return */
	beq	t5,SEXP_NAN,1f
	j	ra
1:	bne	t6,zero,2f
	j	ra

2:	/* Check to see if this is a signaling NaN */
	and	v0,t6,SSNANBIT_MASK
	bne	v0,zero,3f
	/* This is not a signaling NaN so just use it as the result */
	move	t2,t6
	sll	t5,t5,SEXP_SHIFT
	or	t2,t4
	or	t2,t5
	move	v0,zero
	b	rd_1w

	/*
	 * This is a signaling NaN so set the invalid exception in the C1_SR
	 * (a3) and setup the result depending if the enable for the invalid
	 * exception is set.
	 */
3:	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,4f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR

4:	/*
	 * The invalid trap was NOT enabled so the result is the default quiet
	 * NaN.
	 */
	li	t2,SQUIETNAN_LEAST
	move	v0,zero
	b	rd_1w

/*******************************************************************************
*
* rt_breakout_d -
*
* This leaf routine is called to break out the fields of the RT double value
* in gp registers (t6,t7) into:
*	t4 -- sign bit		     (left justified)
*	t5 -- exponent		     (right justified, still biased)
*	t6 -- fraction bits [51-32]  (implied one bit NOT set)
*	t7 -- fraction bits [31-0]
* If the value is a NaN then the action for it is taken and this routine will
* then branch to rd_2w: or store_C1_SR: to exit softFp().
*/
rt_breakout_d:
	srl	t5,t6,DEXP_SHIFT
	move	t4,t5
	and	t5,DEXP_MASK
	and	t4,SIGNBIT>>DEXP_SHIFT
	sll	t4,t4,DEXP_SHIFT
	and	t6,DFRAC_MASK

	/* If this is not a NaN then return */
	beq	t5,DEXP_NAN,1f
	j	ra
1:	bne	t6,zero,2f
	bne	t7,zero,2f
	j	ra

2:	/* Check to see if this is a signaling NaN */
	and	v0,t6,DSNANBIT_MASK
	bne	v0,zero,3f
	/* This is not a signaling NaN so just use it as the result */
	move	t2,t6
	sll	t5,t5,DEXP_SHIFT
	or	t2,t4
	or	t2,t5
	move	t3,t7
	move	v0,zero
	b	rd_2w

	/*
	 * This is a signaling NaN so set the invalid exception in the C1_SR
	 * (a3) and setup the result depending if the enable for the invalid
	 * exception is set.
	 */
3:	or	a3,INVALID_EXC
	and	v0,a3,INVALID_ENABLE
	beq	v0,zero,4f
	/*
	 * The invalid trap was enabled so signal a SIGFPE and leave the
	 * result register unmodified.
	 */
	li	v0, IV_FPA_INV_VEC
	jal	post_signal
	li	v0,1			/* a non-zero exit value */
	b	store_C1_SR

4:	/*
	 * The invalid trap was NOT enabled so the result is the default quiet
	 * NaN.
	 */
	li	t2,DQUIETNAN_LESS
	li	t3,DQUIETNAN_LEAST
	move	v0,zero
	b	rd_2w

/*******************************************************************************
*
* rs_renorm_s -
*
* This leaf routine is called to renormalize the RS denormalized single value
* in gp registers (t0,t1,t2).  This must be a denormalized value not zero.
*/
rs_renorm_s:
	/*
	 * The first step in this process is to determine where the first
	 * one bit is in the fraction (t2).  After this series of tests
	 * the shift count to shift the fraction left so the first 1 bit is
	 * in the high bit will be in t9.  This sequence of code uses registers
	 * v0,v1 and t9 (it could be done with two but with reorginization this
	 * is faster).
	 */
	move	v0,t2
	move	t9,zero

	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction.
	 */
	subu	t9,SFRAC_LEAD0S	/* the calulated shift amount */
	subu	t1,t9		/* adjust the exponent */
	sllv	t2,t2,t9	/* shift the fraction */
	j	ra

/*******************************************************************************
*
* rs_renorm_d -
*
* This leaf routine is called to renormalize the RS denormalized double value
* in gp registers (t0,t1,t2,t3).  This must be a denormalized value not zero.
*/
	.globl GTEXT(rs_renorm_d)
FUNC_LABEL(rs_renorm_d)
	/*
	 * The first step in this process is to determine where the first
	 * one bit is in the fraction (t2,t3).  After this series of tests
	 * the shift count to shift the fraction left so the first 1 bit is
	 * in the high bit will be in t9.  This sequence of code uses registers
	 * v0,v1 and t9 (it could be done with two but with reorginization this
	 * is faster).
	 */
	move	v0,t2
	move	t9,zero
	bne	t2,zero,1f
	move	v0,t3
	addu	t9,32
1:
	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction.
	 */
	subu	t9,DFRAC_LEAD0S	/* the calulated shift amount */
	subu	t1,t9		/* adjust the exponent */
	blt	t9,32,1f
	subu	t9,32		/* shift the fraction for >= 32 bit shifts */
	sllv	t2,t3,t9
	move	t3,zero
	j	ra
1:
	negu	v0,t9		/* shift the fraction for < 32 bit shifts */
	addu	v0,32
	sllv	t2,t2,t9
	srlv	v1,t3,v0
	or	t2,v1
	sllv	t3,t3,t9
	j	ra

/*******************************************************************************
*
* rt_renorm_s -
*
* This leaf routine is called to renormalize the RT denormalized single value
* in gp registers (t4,t5,t6).  This must be a denormalized value not zero.
*/
rt_renorm_s:
	/*
	 * The first step in this process is to determine where the first
	 * one bit is in the fraction (t6).  After this series of tests
	 * the shift count to shift the fraction left so the first 1 bit is
	 * in the high bit will be in t9.  This sequence of code uses registers
	 * v0,v1 and t9 (it could be done with two but with reorginization this
	 * is faster).
	 */
	move	v0,t6
	move	t9,zero

	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction.
	 */
	subu	t9,SFRAC_LEAD0S	/* the calulated shift amount */
	subu	t5,t9		/* adjust the exponent */
	sllv	t6,t6,t9	/* shift the fraction */
	j	ra

/*******************************************************************************
*
* rt_renorm_d -
*
* This leaf routine is called to renormalize the RT denormalized double value
* in gp registers (t4,t5,t6,t7).  This must be a denormalized value not zero.
*/
rt_renorm_d:
	/*
	 * The first step in this process is to determine where the first
	 * one bit is in the fraction (t6,t7).  After this series of tests
	 * the shift count to shift the fraction left so the first 1 bit is
	 * in the high bit will be in t9.  This sequence of code uses registers
	 * v0,v1 and t9 (it could be done with two but with reorginization this
	 * is faster).
	 */
	move	v0,t6
	move	t9,zero
	bne	t6,zero,1f
	move	v0,t7
	addu	t9,32
1:
	srl	v1,v0,16
	bne	v1,zero,1f
	addu	t9,16
	sll	v0,v0,16
1:	srl	v1,v0,24
	bne	v1,zero,2f
	addu	t9,8
	sll	v0,v0,8
2:	srl	v1,v0,28
	bne	v1,zero,3f
	addu	t9,4
	sll	v0,v0,4
3:	srl	v1,v0,30
	bne	v1,zero,4f
	addu	t9,2
	sll	v0,v0,2
4:	srl	v1,v0,31
	bne	v1,zero,5f
	addu	t9,1
5:
	/*
	 * Now that the it is known where the first one bit is calculate the
	 * amount to shift the fraction to put the first one bit in the
	 * implied 1 position (also the amount to adjust the exponent by).
	 * Then adjust the exponent and shift the fraction.
	 */
	subu	t9,DFRAC_LEAD0S	/* the calulated shift amount */
	subu	t5,t9		/* adjust the exponent */
	blt	t9,32,1f
	subu	t9,32		/* shift the fraction for >= 32 bit shifts */
	sllv	t6,t7,t9
	move	t7,zero
	j	ra
1:
	negu	v0,t9		/* shift the fraction for < 32 bit shifts */
	addu	v0,32
	sllv	t6,t6,t9
	srlv	v1,t7,v0
	or	t6,v1
	sllv	t7,t7,t9
	j	ra

/*******************************************************************************
*
* rd_1w -
*
* This exit point stores a one word floating point value from the gp
* register (t2) into the fpr register specified by the RD field from
* the floating-point instruction (a1).  From here until the return
* to the caller the return value (v0) must not be touched.
*/
rd_1w:
#ifdef DEBUG
	sw	t2, _fp_rw
#endif	
	srl	v1,a1,RD_SHIFT		/* get the RD field */
	and	v1,RD_MASK
#ifdef DEBUG
	sw	v1,_fp_rd_reg
#endif

	/*
	 * If a2 (int or exception) is non-zero then the floating-point values
	 * are loaded from the coprocessor else they are loaded from the tcb.
	 */
	bne	a2,zero,rd_cp_1w

	lw	t8, FRAMEA3(softFp)(sp)		/* read pFpContext */
	addu	t8, v1				/* create register address */
	sw	t2, (v1)			/* write correct register */

	b	store_C1_SR

rd_cp_1w:
	sll	v1,v1, 3			/* 8 bytes per entry */
	la	t9, rd_cp_1w_tab
	addu	v1, t9, v1
	j	v1

	.set	noreorder
rd_cp_1w_tab:
	b	rd_cp_1w_fpr0; nop
	b	rd_cp_1w_fpr1; nop
	b	rd_cp_1w_fpr2; nop
	b	rd_cp_1w_fpr3; nop
	b	rd_cp_1w_fpr4; nop
	b	rd_cp_1w_fpr5; nop
	b	rd_cp_1w_fpr6; nop
	b	rd_cp_1w_fpr7; nop
	b	rd_cp_1w_fpr8; nop
	b	rd_cp_1w_fpr9; nop
	b	rd_cp_1w_fpr10; nop
	b	rd_cp_1w_fpr11; nop
	b	rd_cp_1w_fpr12; nop
	b	rd_cp_1w_fpr13; nop
	b	rd_cp_1w_fpr14; nop
	b	rd_cp_1w_fpr15; nop
	b	rd_cp_1w_fpr16; nop
	b	rd_cp_1w_fpr17; nop
	b	rd_cp_1w_fpr18; nop
	b	rd_cp_1w_fpr19; nop
	b	rd_cp_1w_fpr20; nop
	b	rd_cp_1w_fpr21; nop
	b	rd_cp_1w_fpr22; nop
	b	rd_cp_1w_fpr23; nop
	b	rd_cp_1w_fpr24; nop
	b	rd_cp_1w_fpr25; nop
	b	rd_cp_1w_fpr26; nop
	b	rd_cp_1w_fpr27; nop
	b	rd_cp_1w_fpr28; nop
	b	rd_cp_1w_fpr29; nop
	b	rd_cp_1w_fpr30; nop
	b	rd_cp_1w_fpr31; nop
	.set	reorder

	.set	noreorder
rd_cp_1w_fpr0:
	mtc1	t2,$f0;		b	store_C1_SR; 	nop
rd_cp_1w_fpr1:
	mtc1	t2,$f1;		b	store_C1_SR; 	nop
rd_cp_1w_fpr2:
	mtc1	t2,$f2;		b	store_C1_SR;	nop
rd_cp_1w_fpr3:
	mtc1	t2,$f3;		b	store_C1_SR; 	nop
rd_cp_1w_fpr4:
	mtc1	t2,$f4;		b	store_C1_SR;	nop
rd_cp_1w_fpr5:
	mtc1	t2,$f5;		b	store_C1_SR; 	nop
rd_cp_1w_fpr6:
	mtc1	t2,$f6;		b	store_C1_SR;	nop
rd_cp_1w_fpr7:
	mtc1	t2,$f7;		b	store_C1_SR; 	nop
rd_cp_1w_fpr8:
	mtc1	t2,$f8;		b	store_C1_SR;	nop
rd_cp_1w_fpr9:
	mtc1	t2,$f9;		b	store_C1_SR; 	nop
rd_cp_1w_fpr10:
	mtc1	t2,$f10;	b	store_C1_SR;	nop
rd_cp_1w_fpr11:
	mtc1	t2,$f11;	b	store_C1_SR; 	nop
rd_cp_1w_fpr12:
	mtc1	t2,$f12;	b	store_C1_SR;	nop
rd_cp_1w_fpr13:
	mtc1	t2,$f13;	b	store_C1_SR; 	nop
rd_cp_1w_fpr14:
	mtc1	t2,$f14;	b	store_C1_SR;	nop
rd_cp_1w_fpr15:
	mtc1	t2,$f15;	b	store_C1_SR; 	nop
rd_cp_1w_fpr16:
	mtc1	t2,$f16;	b	store_C1_SR;	nop
rd_cp_1w_fpr17:
	mtc1	t2,$f17;	b	store_C1_SR; 	nop
rd_cp_1w_fpr18:
	mtc1	t2,$f18;	b	store_C1_SR;	nop
rd_cp_1w_fpr19:
	mtc1	t2,$f19;	b	store_C1_SR; 	nop
rd_cp_1w_fpr20:
	mtc1	t2,$f20;	b	store_C1_SR;	nop
rd_cp_1w_fpr21:
	mtc1	t2,$f21;	b	store_C1_SR; 	nop
rd_cp_1w_fpr22:
	mtc1	t2,$f22;	b	store_C1_SR;	nop
rd_cp_1w_fpr23:
	mtc1	t2,$f23;	b	store_C1_SR; 	nop
rd_cp_1w_fpr24:
	mtc1	t2,$f24;	b	store_C1_SR;	nop
rd_cp_1w_fpr25:
	mtc1	t2,$f25;	b	store_C1_SR; 	nop
rd_cp_1w_fpr26:
	mtc1	t2,$f26;	b	store_C1_SR;	nop
rd_cp_1w_fpr27:
	mtc1	t2,$f27;	b	store_C1_SR; 	nop
rd_cp_1w_fpr28:
	mtc1	t2,$f28;	b	store_C1_SR;	nop
rd_cp_1w_fpr29:
	mtc1	t2,$f29;	b	store_C1_SR; 	nop
rd_cp_1w_fpr30:
	mtc1	t2,$f30;	b	store_C1_SR;	nop
rd_cp_1w_fpr31:
	mtc1	t2,$f31;	b	store_C1_SR; 	nop
	.set	reorder

/*
 * This exit point stores a two word floating point value from the gp
 * registers (t2,t3) into the fpr register specified by the RD field from
 * the floating-point instruction (a1).  From here until the return
 * to the caller the return value (v0) must not be touched.
 */
rd_2w:
#ifdef DEBUG
	sw	t2, _fp_rd
	sw	t3, _fp_rd+4
#endif	
	srl	v1,a1,RD_SHIFT		/* get the RD field */
	and	v1,RD_MASK
#ifdef DEBUG
	sw	v1,_fp_rd_reg
#endif
	
	/*
	 * If a2 (int or exception) is non-zero then the floating-point values
	 * are loaded from the coprocessor else they are loaded from the tcb.
	 */
	bne	a2,zero,rd_cp_2w

	lw	t8, FRAMEA3(softFp)(sp)		/* read pFpContext */
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	sll	v1, v1, 2			/* 4 bytes per register */
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	sll	v1, v1, 3			/* 8 bytes per register */
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	addu	t8, v1				/* create register address */
	sw	t2, 4(v1)
	sw	t3, (v1)
	b	store_C1_SR

rd_cp_2w:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	srl	v1, v1, 1		/* only allow even numbered registers */
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	dsll32	t2,t2,0			/* assemble 64-bit value */
	lui	t9, 0xffff
	dsrl32	t9, t9, 0		/* t9 = 0000.0000.ffff.ffff */
	and	t3, t9
	or	t2, t3
#ifdef DEBUG
	sd	t2, _fp_rd_val
#endif
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	sll	v1, v1, 3		/* 8 bytes per entry */
	la	t9, rd_cp_2w_tab
	addu	v1, t9, v1
	j	v1

	.set	noreorder
rd_cp_2w_tab:
#if	  (_WRS_FP_REGISTER_SIZE == 4)
	b	rd_cp_2w_fpr0;	nop
	b	rd_cp_2w_fpr2;	nop
	b	rd_cp_2w_fpr4;	nop
	b	rd_cp_2w_fpr6;	nop
	b	rd_cp_2w_fpr8;	nop
	b	rd_cp_2w_fpr10;	nop
	b	rd_cp_2w_fpr12;	nop
	b	rd_cp_2w_fpr14;	nop
	b	rd_cp_2w_fpr16;	nop
	b	rd_cp_2w_fpr18;	nop
	b	rd_cp_2w_fpr20;	nop
	b	rd_cp_2w_fpr22;	nop
	b	rd_cp_2w_fpr24;	nop
	b	rd_cp_2w_fpr26;	nop
	b	rd_cp_2w_fpr28;	nop
	b	rd_cp_2w_fpr30;	nop
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
	b	rd_cp_2w_fpr0; nop
	b	rd_cp_2w_fpr1; nop
	b	rd_cp_2w_fpr2; nop
	b	rd_cp_2w_fpr3; nop
	b	rd_cp_2w_fpr4; nop
	b	rd_cp_2w_fpr5; nop
	b	rd_cp_2w_fpr6; nop
	b	rd_cp_2w_fpr7; nop
	b	rd_cp_2w_fpr8; nop
	b	rd_cp_2w_fpr9; nop
	b	rd_cp_2w_fpr10; nop
	b	rd_cp_2w_fpr11; nop
	b	rd_cp_2w_fpr12; nop
	b	rd_cp_2w_fpr13; nop
	b	rd_cp_2w_fpr14; nop
	b	rd_cp_2w_fpr15; nop
	b	rd_cp_2w_fpr16; nop
	b	rd_cp_2w_fpr17; nop
	b	rd_cp_2w_fpr18; nop
	b	rd_cp_2w_fpr19; nop
	b	rd_cp_2w_fpr20; nop
	b	rd_cp_2w_fpr21; nop
	b	rd_cp_2w_fpr22; nop
	b	rd_cp_2w_fpr23; nop
	b	rd_cp_2w_fpr24; nop
	b	rd_cp_2w_fpr25; nop
	b	rd_cp_2w_fpr26; nop
	b	rd_cp_2w_fpr27; nop
	b	rd_cp_2w_fpr28; nop
	b	rd_cp_2w_fpr29; nop
	b	rd_cp_2w_fpr30; nop
	b	rd_cp_2w_fpr31; nop
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	
#if	  (_WRS_FP_REGISTER_SIZE == 4)
rd_cp_2w_fpr0:
	mtc1	t3,$f0;		mtc1	t2,$f1;		b	store_C1_SR
	nop
rd_cp_2w_fpr2:
	mtc1	t3,$f2;		mtc1	t2,$f3;		b	store_C1_SR
	nop
rd_cp_2w_fpr4:
	mtc1	t3,$f4;		mtc1	t2,$f5;		b	store_C1_SR
	nop
rd_cp_2w_fpr6:
	mtc1	t3,$f6;		mtc1	t2,$f7;		b	store_C1_SR
	nop
rd_cp_2w_fpr8:
	mtc1	t3,$f8;		mtc1	t2,$f9;		b	store_C1_SR
	nop
rd_cp_2w_fpr10:
	mtc1	t3,$f10;	mtc1	t2,$f11;	b	store_C1_SR
	nop
rd_cp_2w_fpr12:
	mtc1	t3,$f12;	mtc1	t2,$f13;	b	store_C1_SR
	nop
rd_cp_2w_fpr14:
	mtc1	t3,$f14;	mtc1	t2,$f15;	b	store_C1_SR
	nop
rd_cp_2w_fpr16:
	mtc1	t3,$f16;	mtc1	t2,$f17;	b	store_C1_SR
	nop
rd_cp_2w_fpr18:
	mtc1	t3,$f18;	mtc1	t2,$f19;	b	store_C1_SR
	nop
rd_cp_2w_fpr20:
	mtc1	t3,$f20;	mtc1	t2,$f21;	b	store_C1_SR
	nop
rd_cp_2w_fpr22:
	mtc1	t3,$f22;	mtc1	t2,$f23;	b	store_C1_SR
	nop
rd_cp_2w_fpr24:
	mtc1	t3,$f24;	mtc1	t2,$f25;	b	store_C1_SR
	nop
rd_cp_2w_fpr26:
	mtc1	t3,$f26;	mtc1	t2,$f27;	b	store_C1_SR
	nop
rd_cp_2w_fpr28:
	mtc1	t3,$f28;	mtc1	t2,$f29;	b	store_C1_SR
	nop
rd_cp_2w_fpr30:
	mtc1	t3,$f30;	mtc1	t2,$f31;	b	store_C1_SR
	nop
#elif	  (_WRS_FP_REGISTER_SIZE == 8)
rd_cp_2w_fpr0:
	b	store_C1_SR;	dmtc1	t2,$f0
rd_cp_2w_fpr1:
	b	store_C1_SR;	dmtc1	t2,$f1
rd_cp_2w_fpr2:
	b	store_C1_SR;	dmtc1	t2,$f2
rd_cp_2w_fpr3:
	b	store_C1_SR;	dmtc1	t2,$f3
rd_cp_2w_fpr4:
	b	store_C1_SR;	dmtc1	t2,$f4
rd_cp_2w_fpr5:
	b	store_C1_SR;	dmtc1	t2,$f5
rd_cp_2w_fpr6:
	b	store_C1_SR;	dmtc1	t2,$f6
rd_cp_2w_fpr7:
	b	store_C1_SR;	dmtc1	t2,$f7
rd_cp_2w_fpr8:
	b	store_C1_SR;	dmtc1	t2,$f8
rd_cp_2w_fpr9:
	b	store_C1_SR;	dmtc1	t2,$f9
rd_cp_2w_fpr10:
	b	store_C1_SR;	dmtc1	t2,$f10
rd_cp_2w_fpr11:
	b	store_C1_SR;	dmtc1	t2,$f11
rd_cp_2w_fpr12:
	b	store_C1_SR;	dmtc1	t2,$f12
rd_cp_2w_fpr13:
	b	store_C1_SR;	dmtc1	t2,$f13
rd_cp_2w_fpr14:
	b	store_C1_SR;	dmtc1	t2,$f14
rd_cp_2w_fpr15:
	b	store_C1_SR;	dmtc1	t2,$f15
rd_cp_2w_fpr16:
	b	store_C1_SR;	dmtc1	t2,$f16
rd_cp_2w_fpr17:
	b	store_C1_SR;	dmtc1	t2,$f17
rd_cp_2w_fpr18:
	b	store_C1_SR;	dmtc1	t2,$f18
rd_cp_2w_fpr19:
	b	store_C1_SR;	dmtc1	t2,$f19
rd_cp_2w_fpr20:
	b	store_C1_SR;	dmtc1	t2,$f20
rd_cp_2w_fpr21:
	b	store_C1_SR;	dmtc1	t2,$f21
rd_cp_2w_fpr22:
	b	store_C1_SR;	dmtc1	t2,$f22
rd_cp_2w_fpr23:
	b	store_C1_SR;	dmtc1	t2,$f23
rd_cp_2w_fpr24:
	b	store_C1_SR;	dmtc1	t2,$f24
rd_cp_2w_fpr25:
	b	store_C1_SR;	dmtc1	t2,$f25
rd_cp_2w_fpr26:
	b	store_C1_SR;	dmtc1	t2,$f26
rd_cp_2w_fpr27:
	b	store_C1_SR;	dmtc1	t2,$f27
rd_cp_2w_fpr28:
	b	store_C1_SR;	dmtc1	t2,$f28
rd_cp_2w_fpr29:
	b	store_C1_SR;	dmtc1	t2,$f29
rd_cp_2w_fpr30:
	b	store_C1_SR;	dmtc1	t2,$f30
rd_cp_2w_fpr31:
	b	store_C1_SR;	dmtc1	t2,$f31
#else	  /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif	  /* _WRS_FP_REGISTER_SIZE */
	.set	reorder

/*******************************************************************************
*
* store_C1_SR -
*
* This exit point stores the floating-point C1_SR value from the gp
* register (a3) into the C1_SR register.  From here until the return
* to the caller the return value (v0) must not be touched.
*/
store_C1_SR:
	HAZARD_CP_READ  /* many branches to this point have preceeding mtc1 */
	/*
	 * If a2 (int or exception) is non-zero then the floating-point C1_SR
	 * register is stored into the coprocessor else it is stored into
	 * the tcb.
	 */
	bne	a2,zero,1f
	lw	t2, FRAMEA3(softFp)(sp)		/* read pFpContext */
	sw	a3, FPCSR(t2)			/* update fpcsr */
	and	a3,~CSR_EXCEPT
	b	2f
1:
	and	a3,~CSR_EXCEPT
	ctc1	a3,C1_SR
	HAZARD_CP_READ
2:
	LW	ra,FRAMERA(softFp)(sp)
	addu	sp,FRAMESZ(softFp)
	j	ra		/* exit the softFp() emulation routine */

/*******************************************************************************
*
* illfpinst -
*
* This exit point posts an illegal instruction signal.  Set v0 to SIGILL and
* call post_signal().  The return value to be used for softFp() will be
* non-zero to indicate the error.
*/

illfpinst:
	li      v0, IV_CPU_VEC		/* translates to SIGILL */
	jal	post_signal
	/* exit the softFp() emulation routine with an non-zero return value (v0) */
	/* to indicate the error. */
	li	v0,1
	LW	ra,FRAMERA(softFp)(sp)
	addu	sp,FRAMESZ(softFp)
	j	ra
	.end 	softFp

/*******************************************************************************
*
* post_signal -
*
* This routine posts a signal to the task whos instruction is being
* emulated.  The signal type to post is in (v0).
*/
	.globl	GTEXT(post_signal)
	.ent	post_signal
FUNC_LABEL(post_signal)
	SETFRAME(post_signal,0)
	.frame	sp, FRAMESZ(post_signal), ra
	subu	sp, FRAMESZ(post_signal)

	sw	a0, FRAMEA0(post_signal)(sp)	/* exception stack ptr */
	sw	a1, FRAMEA1(post_signal)(sp)	/* fp instruction */
	sw	a2, FRAMEA2(post_signal)(sp)	/* int or exception */
	sw	a3, FRAMEA3(post_signal)(sp)	/* control and status register */
	SW	ra, FRAMERA(post_signal)(sp)
	move	a1, a0			/* move pEsf */
	la	a2, E_STK_SR(a1)	/* load general reg pointer */
	move	a0, v0			/* load fault type */
	jal	excExcHandle		/* signal if task has handler,
					   else suspend task, and display
					   valid exception data */
	LW	ra, FRAMERA(post_signal)(sp)

	addu	sp, FRAMESZ(post_signal)
	j	ra
	.end 	post_signal
