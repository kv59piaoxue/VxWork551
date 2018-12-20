/* excALib.s - assembly language exception handling stubs */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
03f,18sep03,mil  Fixed concurrent machine check over critical reg corruption.
03e,13aug03,mil  Added saving of DEAR, ESR, MCSR, MCAR and DBSR.
03d,09jun03,mil  Merged from CP1 to e500.
03c,30jan03,jtp  SPR 78738 exc*Ent needs flush of critical save data before
                 reenabling MMU
03b,13nov02,mil  Updated support for PPC85XX.
03a,03oct02,dtr  Adding save/restore of spefscr spr for 85XX floating point.
02z,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
02y,13jun02,jtp  disable MMU during context restore for 4XX (SPR #78396)
02x,17apr02,jtp  Add PPC440 MMU support
02w,12mar02,mil  Reverted FPSCR sticky status bits clear fix (SPR #24693)
                 for SPR #72980/#73109.
02v,07feb02,mil  Fixed double exception caused by FP unavailability.
                 (SPR #73109/72980)
02u,15jan02,yvp  Fixed PPC604 patch to excEnt (done in 02q for SPR #71240)
02t,19nov01,pch  Rework excVecNum handling for extended vectors.
02s,24oct01,dcb  Clear the sticky bits in the FPCSR when there is a floating
                 point exception.
02q,25oct01,kab  Fix SPR #71240: sync propagates to bus, kills performance
		 cleanup T2.2 macros
02r,05oct01,dtr  Changing _PPC_MSR_EP to _PPC_MSR_IP and also excMsrSet to 
	         use mtmsr not mfmsr. SPR 34977
02q,10sep01,yvp  Fix SPR62760:	Add alignment directive for text section. 
02p,15aug01,pch  Add support for PPC440.  Change test for CPU==PPC4xx
		 to ifdef _PPC_MSR_CE where appropriate.
		 Also reworked SPR 69328 fix to take care of side effects.
02o,27jul01,kab  Fix SPR 69328, excVecNum mask
02n,26jun01,pch  Fix SPR 64511: the DEAR is an SPR, not a DCR
02m,26jun01,kab  Removed ALTIVEC conditional compilation.
02l,14jun01,kab  Fixed Altivec Unavailable exc handler, SPR 68206
02k,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
02j,04dec00,s_m  used bsp functions to read/write BEAR/BESR for 405
02i,30nov00,s_m  fixed bus error handling for 405
02h,25oct00,s_m  renamed PPC405 cpu types
02g,13oct00,sm   removed save/restore of BEAR and BESR for PPC405
02f,13oct00,sm   fixed inclusion of symbol fpfix
02e,31aug00,sm   PPC405 & PPC405F support
02d,26mar99,zl   added PowerPC 509 support, no MSR[IR,DR] bits
02c,13nov98,elg  changed GPR3 restoration register in critical exceptions
02b,18aug98,tpr  added PowerPC EC 603 support.
02a,24dec97,dat  SPR 20104, fixed incorrect use of HIADJ macro
01z,22jul97,tpr  added sync instruction arround HID0 modification (SPR #8976)
01y,18mar97,tam  mask/unmask PPC403 Critical Intr. Enable bit (SPR #8192).
01x,10feb97,tam  restore previous value of MSR[FP] bit in excEnt().
01w,20dec96,tpr  added sync inst. before HID0 modification in excEnt().
01v,24jun96,tpr  added PowerPC 860 support.
01u,19mar96,tpr  fixed the bug with _PPC_MSR_RI bit.
01t,17mar96,tam  cleared BESR with 0.
01s,07mar96,tpr  replaced SPGR1 by SPGR0.
01r,06mar96,tpr  removed SDA.
01q,04mar96,tam  fixed excCrtEnt & excCrtExit for PPC403.
		 added code to save DEAR, BEAR & BESR reg. for PPC403.
01p,01mar96,ms   fixed excExit (typos restoring r4 and r13). Removed excStub.
01o,28feb96,tam  added excCrtExit() for critical exceptions for the PPC403 cpu.
01n,27feb96,ms   removed ".globl excClkStub", fixed sp saving in excEnt.
01m,28jan96,tpr  reworked interrupt and exception handling.
01l,16jan95,tpr  reworked interrupt and exception stub (SPR #5657).
01k,08oct95,tpr  reworked code to include the MMU support.
01j,17jul95,caf  removed dbgBreakpoint reference (PPC403).
01i,16jun95,caf  init r2 and r13 according to EABI standard.
01h,22may95,yao  fixed bug in excEPSet().  moved excTraceStub() to dbgALib.s.
01g,22mar95,caf  put #ifdefs around sdata references, fixed internal comments.
01f,09feb95,yao  added excCrtStub, excCrtEnt, excCrtExit for PPC403.  cleanup.
		 changed to disable interrupt before restore interrupt context.
01e,07feb95,yao  removed excProgStub, excDbgStub, excExit1 for PPC403.
01d,02feb95,yao  added excProgStub for PPC403.  removed unnecessary
		 function declarations.
	   +caf  cleanup.
01c,05dec94,caf  added _GREEN_TOOL support, changed 'bcr' to 'bclr',
		 changed 'mtcr' to 'mtcrf'.
01b,11oct94,yao  fixed bug when demultipex interrupts.
		 changed to check for null pointer before jumping to isr.
01a,09sep94,yao  written.
*/

/*
DESCRIPTION
This module contains the assembly language exception handling stubs
along with the interrupt handling stubs.

There are no user-callable routines in this module.
*/

#define _ASMLANGUAGE

#include "vxWorks.h"
#include "asm.h"
#include "esf.h"
#include "regs.h"
#include "private/taskLibP.h"
#include "arch/ppc/excPpcLib.h"

#define	INT_STACK_SWITCH	/* we switch interrupt stack by default */

#if	(CPU == PPC405F)
/* Certain versions of PPC405F need a fix for Errata # 18 (lfd) instruction 
 * Note: This errata is numbered 18 for the 405GF and numbered 20 for the
 * D8405
 */
#define PPC405F_ERRATA_18		/* define this to include fix */
#endif	/* CPU == PPC405F */

	/* globals */

	FUNC_EXPORT(excEnt)		/* exception stub */
	FUNC_EXPORT(excExit)		/* exception stub */

#ifdef	_PPC_MSR_IP
	FUNC_EXPORT(excEPSet)		/* set MSR[IP] bit */
#endif	/* _PPC_MSR_IP */

#ifdef	_PPC_MSR_CE
	FUNC_EXPORT(excCrtEnt)		/* exception stub for critical intr. */
	FUNC_EXPORT(excCrtExit)		/* exception stub for critical intr. */
#endif	/* _PPC_MSR_CE */

#ifdef  _PPC_MSR_MCE
        FUNC_EXPORT(excMchkEnt)         /* exception stub for mach chk intr. */
        FUNC_EXPORT(excMchkExit)        /* exception stub for mach chk intr. */
#endif  /* _PPC_MSR_MCE */

	/* externals */
#if	(CPU == PPC405F)
	FUNC_IMPORT(fpfix)		/* 405 GF errata #18 fix */
	FUNC_IMPORT(fpCrtfix)		/* PPC405F errata fix for crt.intrp */
#endif	/* CPU == PPC405F */

#if	((CPU == PPC405) || (CPU == PPC405F))
	FUNC_IMPORT(sysDcrPlbbesrClear)
	FUNC_IMPORT(sysDcrPlbbearGet)
	FUNC_IMPORT(sysDcrPlbbesrGet)
#endif	/* (CPU == PPC405) || (CPU == PPC405F) */

	FUNC_IMPORT(excExcHandle)	/* default exception handler */
	FUNC_IMPORT(excIntHandle)	/* default interrupt handler */
	FUNC_IMPORT(reschedule)		/* exception handler */
	FUNC_IMPORT(sysIntHandler)	/* bsp level int handler */

#if	((CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F))
	FUNC_IMPORT(vxPitInt)		/* pit interrupt handler */
	FUNC_IMPORT(vxFitInt)		/* fit interrupt handler */
#else	/* CPU == PPC403 || CPU == PPC405 || CPU == PPC405F */
	FUNC_IMPORT(vxDecInt)		/* decrementer interrupt handler */
#endif	/* CPU == PPC403 || CPU == PPC405 || CPU == PPC405F */

	DATA_IMPORT(readyQHead)		/* ready queue head */
	DATA_IMPORT(kernelState)	/* kernel state */
	DATA_IMPORT(taskIdCurrent)	/* current task identifier */
	DATA_IMPORT(intCnt)		/* interrupt counter */
	DATA_IMPORT(errno)		/* error number */
	DATA_IMPORT(excRtnTbl)		/* table of exception routine to call */
	DATA_IMPORT(excExtendedVectors)	/* non-zero => "long" vectors */

	_WRS_TEXT_SEG_START
	
/******************************************************************************
*
* excEnt - default context saving routine upon exception entrance
*
* NOTE: The stack pointer is already set to the exception stack frame pointer.
*       The exception vector on the stack is saved as  vector offset + 
*       _EXC_CODE_SIZE.
*
* NOMANUAL

* void excEnt()

*/

FUNC_BEGIN(excEnt)
	/* At the entry of this function, the following is done */
	/* mtspr	SPRG3, p0	/@ save P0 to SPRG3 */
	/* mfspr	p0, LR		/@ load LR to P0 */
	/* bla		excEnt		/@ call excEnt */

#if	(CPU == PPC604)
	/*
	 * The PPC604 has HW support for TLB miss, so we can turn on
	 * address xlate now and avoid the cache locking altogether.
	 * Better performance, especially for the 74xx that always
	 * propogates sync insn to bus.
	 */
	mtspr	SPRG0, p1			/* SPRG0 = p1 */
	mtspr	SPRG2, p0			/* SPRG2 = LR */

	mfspr	p0, SRR1			/* p0 = MSRval b4 exception */
	li	p1, _PPC_MSR_IR | _PPC_MSR_DR   /* p1 = mask IR,DR bits */
	and	p0, p0, p1			/* p0 = IR, DR value b4 exc */
						
	mfmsr	p1				/* p1 = MSRval current */
	or	p1, p1, p0			/* p1 = MSRval cur with old */
						/*      IR, DR bits         */
	mtmsr	p1				/* set MSR with old IR, DR */
	isync					/* synchronize */
	mfspr	p0, SPRG2			/* restore LR to p0 */
	mfspr	p1, SPRG0 			/* restore p1 to p1 */
#endif	/* (CPU == PPC604) */

#if	((CPU == PPC603) || (CPU == PPCEC603))
	/* 
	 * When an exception is generated by the processor, it turn off the
	 * MMU. At this moment the cache is not longer controlled by the 
	 * WIMG bits of the MMU. If the DCE bit in the HID0 is set, the cache
	 * is turn on. In this case the register values are written in the cache
	 * and not in the memory. Because VxWorks executes exception handler
	 * with the MMU turned on we don't know if the memory which handles
	 * the register values are cacheable or not. To avoid memory 
	 * coherency problem, the cache lines handling the register values
	 * saved previously should be flush.
	 *
	 * The approach taken here for 603 is to lock the DCACHE controlled by
	 * HID0[DLOCK] and restore HID0 after critical part of ESF is saved.
	 * SPRG0 is used until the restoration is done.
	 *
	 * XXX TPR : ESF should be reworked to reduce the size this cache
	 * flushing.
	 */
	mtspr	SPRG2, p0			/* SPRG2 = LR */

	mfspr	p0, HID0			/* p0 = HID0val */
	mtspr	SPRG0, p0			/* SPRG0 = HID0val */
	ori	p0, p0, _PPC_HID0_DLOCK		/* set the DLOCK bit */
	sync
	mtspr	HID0, p0			/* set HID0 with DLOCK */
	sync

	mfspr	p0, SPRG2			/* restore LR to p0 */
#endif	/* ((CPU == PPC603) || (CPU == PPCEC603)) */

	/*
	 * reserve a room equal to the size of the ESF. This memory space is
	 * taken from the stack of the task which has produce the exception.
	 * This memory space is used to save the processor critical register
	 * values.
	 */

	stwu	sp, - _PPC_ESF_STK_SIZE(sp)	/* allocate ESF */

	stw	p0, _PPC_ESF_LR(sp)		/* save LR */

	mfspr	p0, SPRG3			/* load saved P0 from SPR3 */
	stw	p0, _PPC_ESF_P0(sp)		/* save P0 */

	mfspr	p0, SRR0			/* load saved PC to P0 */
	stw	p0, _PPC_ESF_PC(sp)		/* save PC */

	mfspr	p0, SRR1			/* load saved MSR to P0 */
	stw	p0, _PPC_ESF_MSR(sp)		/* save MSR */

	stw	p1, _PPC_ESF_P1(sp)		/* save general register P1 */

	mfcr	p1				/* load CR to P1 */
	stw	p1, _PPC_ESF_CR(sp)		/* save CR */

#if	(CPU == PPC405F)
	/*
	 * we need the following fix for certain versions of PPC405F
	 */
# ifdef PPC405F_ERRATA_18
	mtspr	SPRG2, p0			/* save P0 (SRR1) */
	mfspr	p1, LR				/* save current LR */
	mtspr	SPRG0, p1
	bl	fpfix				/* handle fix */
	mfspr	p1, SPRG0			/* load LR */
	mtspr	LR, p1
	mfspr	p0, SPRG2			/* restore P0 (SRR1) */
# endif	/* PPC405F_ERRATA_18 */
#endif	/* CPU == PPC405F */


#if	((CPU == PPC603) || (CPU == PPCEC603))
	mfspr	p1, SPRG0			/* p1 = previous saved HID0 */
	sync
	mtspr	HID0, p1			/* restore HID0 w/o DLOCK */
	sync
#endif	/* ((CPU == PPC603) || (CPU == PPCEC603)) */

#if	((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
         (CPU == PPC85XX))
	/*
 	 * Before we reenable the MMU, we need to ensure that the values
	 * we pushed on the stack above are flushed out of cache.
	 */
    	dcbf    0, sp               /* push SP value to memory */

	li  p1, _PPC_ESF_LR
	dcbf    p1, sp              /* push LR value to memory */

	li  p1, _PPC_ESF_P0
	dcbf    p1, sp              /* push P0 value to memory */

	li  p1, _PPC_ESF_PC
	dcbf    p1, sp              /* push PC value to memory */

	li  p1, _PPC_ESF_MSR
	dcbf    p1, sp              /* push MSR value to memory */

	li  p1, _PPC_ESF_P1
	dcbf    p1, sp              /* push P1 value to memory */

	li  p1, _PPC_ESF_CR
	dcbf    p1, sp              /* push CR value to memory */

	sync
#endif	/* CPU == PPC405, PPC405F, PPC440, PPC85XX */

	/* 
	 * Now turn the data or/and instruction MMU on if they were 
	 * previously turned off.
	 * The critical registers are saved. Now the interrupt and machine
	 * check can be re-enabled. If an interrupt or exception is detected
	 * the previous state can be reconstructed.
	 *
	 * Change to the PPC604: MMU has been re-enabled above.
	 * The code below re-enables PPC604 MMU again while re-enabling
	 * interrupts/exceptions, FP -- the MMU is a nop, but cleaner to
	 * leave here, than to make even more complex conditional compile.
	 */

	mfmsr	p1				/* p1 = MSRval current */
						/* p0 should have MSRval app */

/* This is so we can "or" together defined bits, without a tangle of #ifdef */
#ifdef	_PPC_MSR_RI
#define	_MSR_RI	_PPC_MSR_RI
#else  /* _PPC_MSR_RI */
#define	_MSR_RI	0
#endif  /* _PPC_MSR_RI */

#ifdef	_PPC_MSR_FP
#define	_MSR_FP	_PPC_MSR_FP
#else  /* _PPC_MSR_FP */
#define	_MSR_FP	0
#endif  /* _PPC_MSR_FP */

#ifdef	_PPC_MSR_IR
#define	_MSR_IR	_PPC_MSR_IR
#else  /* _PPC_MSR_IR */
#define	_MSR_IR	0
#endif  /* _PPC_MSR_IR */

#ifdef	_PPC_MSR_DR
#define	_MSR_DR	_PPC_MSR_DR
#else  /* _PPC_MSR_DR */
#define	_MSR_DR	0
#endif  /* _PPC_MSR_DR */

#ifdef	_PPC_MSR_IS
#define	_MSR_IS	_PPC_MSR_IS
#else  /* _PPC_MSR_IS */
#define	_MSR_IS	0
#endif  /* _PPC_MSR_IS */

#ifdef	_PPC_MSR_DS
#define	_MSR_DS	_PPC_MSR_DS
#else  /* _PPC_MSR_DS */
#define	_MSR_DS	0
#endif  /* _PPC_MSR_DS */

#ifdef	_PPC_MSR_CE
#define	_MSR_CE	_PPC_MSR_CE
#else	/* _PPC_MSR_CE */
#define	_MSR_CE	0
#endif	/* _PPC_MSR_CE */

#ifdef	_PPC_MSR_MCE
#define	_MSR_MCE	_PPC_MSR_MCE
#else	/* _PPC_MSR_CE */
#define	_MSR_MCE	0
#endif	/* _PPC_MSR_CE */

#if	((CPU != PPC403) && (CPU != PPC405) && (CPU != PPC405F) && \
	 (CPU != PPC440) && (CPU != PPC85XX))

# if	(CPU != PPC509)
	andi.	p0, p0, _MSR_RI | _MSR_FP | _MSR_IR | _MSR_DR | _MSR_IS | _MSR_DS | _PPC_MSR_EE
# else	/* CPU == PPC509 */
	andi.	p0, p0, _PPC_MSR_RI | _PPC_MSR_EE | _PPC_MSR_FP
# endif	/* CPU == PPC509 */

#else	/* CPU == PPC4xx, PPC85XX */

	mtspr	SPRG2, p1			/* SPRG2 = MSRval current */
	lis	p1,  HI(_MSR_CE | _MSR_FP | _MSR_IR | _MSR_DR | _MSR_IS | _MSR_DS | _PPC_MSR_EE)
	ori	p1, p1, LO(_MSR_CE | _MSR_FP | _MSR_IR | _MSR_DR | _MSR_IS | _MSR_DS | _PPC_MSR_EE)
	and.	p0, p1, p0			/* extract runtime values */
	mfspr	p1, SPRG2			/* p1 = MSRval current */

#endif	/* CPU != PPC4xx && PPC85XX */
						/* get value of IR,DR,IS,DS,EE,RI */
						/* & FP bits before exception */
	or	p1, p1, p0			/* restore the previous value */
						/* of IR,DR,IS,DS,EE,RI & FP bits */

	mtmsr	p1				/* ENABLE INTERRUPT */
	isync					/* synchronize */

	mfspr   p0, LR                          /* p0 = exception number */
						/* may be wrong if relocated */
/*
 * The LR value is offset from the vector address by the size of the
 * bla and other instructions preceding it in excConnectCode (or in
 * excExtConnectCode if excExtendedVectors is in effect).  For the
 * "normal" exceptions handled here, the difference varies depending
 * on whether the processor also implements "critical" exceptions.
 *
 * In either case, the offset amounts to 4 * (ENT_OFF + 1) for "short"
 * vectors or 4 * EXT_ISR_OFF for extended vectors; however these symbols
 * are defined in excArchLib.c and the definitions are not accessible here.
 */
	lis     p1, HIADJ(excExtendedVectors)
	lwz     p1, LO(excExtendedVectors)(p1)	/* get excExtendedVectors */
	cmpwi	p1, 0				/* if 0, short vectors */
	beq	shortVec

	li	p1, 20			/* 4 * (EXT_ISR_OFF - (ENT_OFF + 1)) */
shortVec:

#ifdef	_EXC_OFF_CRTL
	addi	p1, p1, 28			/* 4 * (ENT_OFF + 1) */
#else	/* _EXC_OFF_CRTL */
	addi	p1, p1, 12			/* 4 * (ENT_OFF + 1) */
#endif	/* _EXC_OFF_CRTL */
	sub	p0, p0, p1
	stw	p0, _PPC_ESF_VEC_OFF(sp)	/* store to ESF */

	mfspr	p0, CTR				/* load CTR to P0 */
	stw	p0, _PPC_ESF_CTR(sp)		/* save CTR */

	mfspr	p1, XER				/* load XER to P1 */
	stw	p1, _PPC_ESF_XER(sp)		/* save XER */

#if	(CPU == PPC601)
	mfspr	p1, MQ				/* load MQ to P1 */
	stw	p1, _PPC_ESF_MQ(sp)		/* save MQ */
#endif	/* (CPU == PPC601) */
#if	(CPU == PPC85XX)
	mfspr	p1, SPEFSCR			/* load SPEFSCR to P1 */
	stw	p1, _PPC_ESF_SPEFSCR(sp)	/* save SPEFSCR */
#endif	/* (CPU == PPC85XX) */

	/* DEAR/DAR/ESR/DSISR not saved earlier for 5.5. compatibility
	   see SPR 90228 */
#if	((CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F) || \
	 (CPU == PPC440) || (CPU == PPC85XX))
	mfspr	p0, DEAR			/* load DEAR to P0 */
	stw	p0, _PPC_ESF_DEAR(sp)		/* save DEAR */
# if	(CPU == PPC85XX)
	mfspr   p0, ESR				/* load ESR to P0 */
	stw     p0, _PPC_ESF_ESR(sp)		/* save ESR */
# endif  /* CPU == PPC85XX */
#else	/* CPU == PPC4xx, PPC85XX */
	mfspr	p1, DAR
	stw	p1, _PPC_ESF_DAR(sp)		/* save DAR */

	mfspr	p1, DSISR
	stw	p1, _PPC_ESF_DSISR(sp)		/* save DSISR */
#endif	/* CPU == PPC4xx, PPC85XX */

	stw	r0, _PPC_ESF_R0(sp)		/* save general register 0 */

	addi	r0, r1, _PPC_ESF_STK_SIZE
	stw	r0, _PPC_ESF_R1(sp)		/* save exception sp */

	stw	r2, _PPC_ESF_R2(sp)		/* save general register 2 */

#if	TRUE					/* optimization to test */
	/* save the volatile register values on the ESF */

	stw	p2, _PPC_ESF_P2(sp)		/* save general register 5 */
	stw	p3, _PPC_ESF_P3(sp)		/* save general register 6 */
	stw	p4, _PPC_ESF_P4(sp)		/* save general register 7 */
	stw	p5, _PPC_ESF_P5(sp)		/* save general register 8 */
	stw	p6, _PPC_ESF_P6(sp)		/* save general register 9 */
	stw	p7, _PPC_ESF_P7(sp)		/* save general register 10 */

	stw	r11, _PPC_ESF_R11(sp)		/* save general register 11 */
	stw	r12, _PPC_ESF_R12(sp)		/* save general register 12 */
	stw	r13, _PPC_ESF_R13(sp)		/* save general register 13 */

	/* save the non volatile register values on the ESF */

	stw	t0, _PPC_ESF_T0(sp)		/* save general register 14 */
	stw	t1, _PPC_ESF_T1(sp)		/* save general register 15 */
	stw	t2, _PPC_ESF_T2(sp)		/* save general register 16 */
	stw	t3, _PPC_ESF_T3(sp)		/* save general register 17 */
	stw	t4, _PPC_ESF_T4(sp)		/* save general register 18 */
	stw	t5, _PPC_ESF_T5(sp)		/* save general register 19 */
	stw	t6, _PPC_ESF_T6(sp)		/* save general register 20 */
	stw	t7, _PPC_ESF_T7(sp)		/* save general register 21 */
	stw	t8, _PPC_ESF_T8(sp)		/* save general register 22 */
	stw	t9, _PPC_ESF_T9(sp)		/* save general register 23 */
	stw	t10, _PPC_ESF_T10(sp)		/* save general register 24 */
	stw	t11, _PPC_ESF_T11(sp)		/* save general register 25 */
	stw	t12, _PPC_ESF_T12(sp)		/* save general register 26 */
	stw	t13, _PPC_ESF_T13(sp)		/* save general register 27 */
	stw	t14, _PPC_ESF_T14(sp)		/* save general register 28 */
	stw	t15, _PPC_ESF_T15(sp)		/* save general register 29 */
	stw	t16, _PPC_ESF_T16(sp)		/* save general register 30 */
	stw	t17, _PPC_ESF_T17(sp)		/* save general register 31 */
#else
	stmw	p2, _PPC_ESF_P2(sp)		/* save general register 5 */
						/* through 31 */
#endif	/* TRUE */

	blr					/* return to caller */
FUNC_END(excEnt)

/*******************************************************************************
*
* excExit - default context restore routine upon exception exit
*
* NOMANUAL

* void excExit()

*/

FUNC_BEGIN(excExit)
	/* restore dedicated and scratch registers */

	lwz	r0, _PPC_ESF_R0(sp)		/* restore general register 0 */
	lwz	r2, _PPC_ESF_R2(sp)		/* restore general register 2 */

#if	TRUE					/* optimization to test */
	/* restore volatile registers */

	lwz	p1, _PPC_ESF_P1(sp)		/* restore general register 4 */
	lwz	p2, _PPC_ESF_P2(sp)		/* restore general register 5 */
	lwz	p3, _PPC_ESF_P3(sp)		/* restore general register 6 */
	lwz	p4, _PPC_ESF_P4(sp)		/* restore general register 7 */
	lwz	p5, _PPC_ESF_P5(sp)		/* restore general register 8 */
	lwz	p6, _PPC_ESF_P6(sp)		/* restore general register 9 */
	lwz	p7, _PPC_ESF_P7(sp)		/* restore general reg 10 */

	lwz	r11, _PPC_ESF_R11(sp)		/* restore general reg 11 */
	lwz	r12, _PPC_ESF_R12(sp)		/* restore general reg 12 */
	lwz	r13, _PPC_ESF_R13(sp)		/* restore general reg 13 */

	/* restore non-volatile registers */
	/* 
	 * XXX TPR the non-volatile should not be resoted because they are
	 * not destroyed. To test or verify 
	 */

	lwz	t0, _PPC_ESF_T0(sp)		/* restore general reg 14 */
	lwz	t1, _PPC_ESF_T1(sp)		/* restore general reg 15 */
	lwz	t2, _PPC_ESF_T2(sp)		/* restore general reg 16 */
	lwz	t3, _PPC_ESF_T3(sp)		/* restore general reg 17 */
	lwz	t4, _PPC_ESF_T4(sp)		/* restore general reg 18 */
	lwz	t5, _PPC_ESF_T5(sp)		/* restore general reg 19 */
	lwz	t6, _PPC_ESF_T6(sp)		/* restore general reg 20 */
	lwz	t7, _PPC_ESF_T7(sp)		/* restore general reg 21 */
	lwz	t8, _PPC_ESF_T8(sp)		/* restore general reg 22 */
	lwz	t9, _PPC_ESF_T9(sp)		/* restore general reg 23 */
	lwz	t10, _PPC_ESF_T10(sp)		/* restore general reg 24 */
	lwz	t11, _PPC_ESF_T11(sp)		/* restore general reg 25 */
	lwz	t12, _PPC_ESF_T12(sp)		/* restore general reg 26 */
	lwz	t13, _PPC_ESF_T13(sp)		/* restore general reg 27 */
	lwz	t14, _PPC_ESF_T14(sp)		/* restore general reg 28 */
	lwz	t15, _PPC_ESF_T15(sp)		/* restore general reg 29 */
	lwz	t16, _PPC_ESF_T16(sp)		/* restore general reg 30 */
	lwz	t17, _PPC_ESF_T17(sp)		/* restore general reg 31 */
#else
	lmw	p1, _PPC_ESF_P1(sp)		/* restore general register 5 */
						/* through 31 */
#endif	/* TRUE	*/

	/* restore user level special purpose registers */

	lwz	p0, _PPC_ESF_CTR(sp)		/* load saved CTR  to P0*/
	mtspr	CTR, p0				/* restore CTR */

	lwz	p0, _PPC_ESF_XER(sp)		/* load saved XER to P0 */
	mtspr	XER, p0				/* restore XER */

	lwz	p0, _PPC_ESF_LR(sp)		/* load saved LR to P0 */
	mtspr	LR, p0				/* restore LR */

	lwz	p0, _PPC_ESF_CR(sp)		/* load the saved CR to P0 */
	mtcrf	255,p0				/* restore CR */

#if	(CPU==PPC601)
	lwz	p0, _PPC_ESF_MQ(sp)		/* load saved MQ to P0 */
	mtspr	MQ, p0				/* restore MQ */
#endif	/* (CPU==PPC601) */

#if	(CPU==PPC85XX)
	lwz	p0, _PPC_ESF_SPEFSCR(sp)	/* load saved SPEFSCR to P0 */
	mtspr	SPEFSCR, p0			/* restore SPEFSCR */
#endif	/* (CPU==PPC85XX) */

	/* XXX TPR this code can be optimized */

	mfmsr	p0				/* read msr */

#ifdef	_PPC_MSR_RI
	RI_MASK(p0, p0 )			/* mask RI bit */
#endif	/* _PPC_MSR_RI */

	INT_MASK(p0,p0)				/* clear EE bit in msr */
	mtmsr	p0				/* DISABLE INTERRUPT */
	isync					/* synchronize */

#ifdef 	_WRS_TLB_MISS_CLASS_SW
	/*
	 * Turn off MMU to keep SW TLB Miss handler from corrupting
	 * SRR0, SRR1.
	 */

	lwz	p0, _PPC_ESF_PC(sp)		/* load PC to P0 and save */
	mtspr	SPRG0,p0			/* it temporarily in SPRG0 */

	lwz	p0, _PPC_ESF_MSR(sp)		/* load MSR to P0 and save */
	mtspr	SPRG3, p0			/* it temporarily in SPRG3 */

	lwz	p0, _PPC_ESF_P0(sp)		/* restore P0 and save */
	mtspr	SPRG2,p0			/* it temporarily in SPRG2 */

	lwz	sp, _PPC_ESF_SP(sp)		/* restore the SP(R1) */

						/* turn off the MMU before */
						/* to restore the SRR0/SRR1 */
	mfmsr	p0				/* read msr */
	rlwinm	p0,p0,0,28,25			/* disable Instr/Data trans */
	mtmsr	p0				/* set msr */
	isync					/* synchronization */

	mfspr	p0, SPRG0			/* load SPRG0 to p0 */
	mtspr	SRR0, p0			/* restore SRR0 (PC) */

	mfspr	p0, SPRG3			/* load SPRG3 to p0 */
	mtspr	SRR1, p0			/* restore SRR1 (MSR) */

	mfspr	p0, SPRG2			/* restore P0 from SPRG2 */
#else	/* !_WRS_TLB_MISS_CLASS_SW */
	/*
	 * both MMU-less and MMU with miss handler in HW use this code
	 */

	lwz	p0, _PPC_ESF_PC(sp)		/* load the saved PC to P0 */
	mtspr	SRR0, p0			/* and restore SRR0 (PC) */

	lwz	p0, _PPC_ESF_MSR(sp)		/* load the saved MSR to P0 */
	mtspr	SRR1, p0			/* and restore SRR1 (MSR) */

	lwz	p0, _PPC_ESF_P0(sp)		/* restore p0 */

	lwz	sp, _PPC_ESF_SP(sp)		/* restore the stack pointer */
#endif	/* _WRS_TLB_MISS_CLASS_SW */

	rfi					/* return to context of the */
						/* task that got exception */
FUNC_END(excExit)

#ifdef	_PPC_MSR_CE
/******************************************************************************
*
* excCrtEnt - default context saving routine upon critical exception entrance
* NOTE: The stack pointer is already set to the exception stack frame pointer.
*       The exception vector on the stack is saved as  vector offset +
*       _EXC_CODE_SIZE.
*
* NOMANUAL

* void excCrtEnt()

*/

FUNC_BEGIN(excCrtEnt)
	/* At the entry of this function, the following is done */
	/* mtspr        SPRG2, p0       /@ save P0 to SPRG2 */
	/* mfspr        p0, LR          /@ load LR to P0 */
	/* bla          excCrtEnt       /@ call excCrtEnt */

	/*
	 * reserve a room equal to the size of the ESF. This memory space is
	 * taken from the stack of the task which has produce the exception.
	 * This memory space is used to save the processor critical register
	 * values.
	 */

	stwu    sp, - _PPC_ESF_STK_SIZE(sp)     /* update SP */

	stw     p0, _PPC_ESF_LR(sp)             /* save LR */

	mfspr   p0, SPRG2                       /* load saved P0 */
	stw     p0, _PPC_ESF_P0(sp)             /* save general register P0 */

	mfspr   p0, CRIT_SAVE_PC		/* load saved PC to P0 */
	stw     p0, _PPC_ESF_PC(sp)		/* save PC in ESF */

	mfspr   p0, CRIT_SAVE_MSR		/* load saved MSR to P0 */
	stw     p0, _PPC_ESF_MSR(sp)		/* save MSR in ESF */

	stw     p1, _PPC_ESF_P1(sp)             /* save general register P1 */

	mfcr    p1                              /* load CR to P1 */
	stw     p1, _PPC_ESF_CR(sp)             /* save CR */

# if	(CPU == PPC405F)
	/*
	 * we need the following fix for certain versions of PPC405F
	 */
#  ifdef PPC405F_ERRATA_18
	mtspr	SPRG2, p0			/* save P0 (SRR1) */
	mfspr	p1, LR				/* save current LR */
	mtspr	SPRG0, p1
	bl	fpCrtfix			/* handle fix */
	mfspr	p1, SPRG0			/* load LR */
	mtspr	LR, p1
	mfspr	p0, SPRG2			/* restore P0 (SRR1) */
#  endif  /* PPC405F_ERRATA_18 */
# endif	/* CPU == PPC405F */

#if	((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
         (CPU == PPC85XX))
	/*
 	 * Before we reenable the MMU, we need to ensure that the values
	 * we pushed on the stack above are flushed out of cache.
	 */
    	dcbf    0, sp               /* push SP value to memory */

	li  p1, _PPC_ESF_LR
	dcbf    p1, sp              /* push LR value to memory */

	li  p1, _PPC_ESF_P0
	dcbf    p1, sp              /* push P0 value to memory */

	li  p1, _PPC_ESF_PC
	dcbf    p1, sp              /* push PC value to memory */

	li  p1, _PPC_ESF_MSR
	dcbf    p1, sp              /* push MSR value to memory */

	li  p1, _PPC_ESF_P1
	dcbf    p1, sp              /* push P1 value to memory */

	li  p1, _PPC_ESF_CR
	dcbf    p1, sp              /* push CR value to memory */

	sync
#endif	/* CPU == PPC405, PPC405F, PPC440, PPC85XX */

	/*
	 * Now turn the data or/and instruction MMU on if they were
	 * previously turned on.
	 * the critical registers are save. Now the interrupt and machine
	 * check can be re-enabled. If an interrupt or exception is detected
	 * the previous state can be reconstructed.
	 */

	mfmsr   p1                              /* p1 = MSRval current */
						/* p0 should have MSRval app */

	mtspr   SPRG2, p1                       /* SPRG2 = MSRval current */
	lis	p1,  HI( _MSR_CE | _MSR_IR | _MSR_DR | _MSR_IS | _MSR_DS | _PPC_MSR_EE )
	ori	p1, p1, LO( _MSR_CE | _MSR_IR | _MSR_DR | _MSR_IS | _MSR_DS | _PPC_MSR_EE )
	and.    p0, p1, p0			/* extract app IR,DR,CE,EE */
	mfspr   p1, SPRG2                       /* p1 = MSRval before */

	or      p1, p1, p0                      /* p1 = MSRval current with */
						/*      app IR,DR,CE,EE */

	mtmsr   p1                              /* ENABLE INTERRUPT & MMU */
	isync                                   /* synchronize */

	mfspr   p0, LR                          /* p0 = exception number */
						/* may be wrong if relocated */
/*
 * The LR value is offset from the vector address by the size of the
 * bla and other instructions preceding it in excCrtConnectCode (or
 * in excExtCrtConnectCode if excExtendedVectors is in effect).
 *
 * The offset amounts to 4 * (ENT_CRT_OFF + 1) or 4 * EXT_ISR_CRT_OFF
 * respectively, however these symbols are defined in excArchLib.c
 * and the definitions are not accessible here.
 */
	lis     p1, HIADJ(excExtendedVectors)
	lwz     p1, LO(excExtendedVectors)(p1)	/* get excExtendedVectors */
	cmpwi	p1, 0				/* if 0, short vectors */
	beq	crtShortVec

	li	p1, 20		/* 4 * (EXT_ISR_CRT_OFF - (ENT_CRT_OFF + 1)) */
crtShortVec:
	addi	p1, p1, 12			/* 4 * (ENT_CRT_OFF + 1) */
	sub	p0, p0, p1
	stw     p0, _PPC_ESF_VEC_OFF(sp)        /* store to ESF */

	mfspr   p0, CTR                         /* load CTR to P0 */
	stw     p0, _PPC_ESF_CTR(sp)            /* save CTR */

	mfspr   p1, XER                         /* load XER to P0 */
	stw     p1, _PPC_ESF_XER(sp)            /* save XER */

# if	(CPU == PPC403)
	mfdcr   p0, BEAR                        /* load BEAR to P0 */
	stw     p0, _PPC_ESF_BEAR(sp)           /* save BEAR */

	mfdcr   p0, BESR                        /* load  to P0 */
	stw     p0, _PPC_ESF_BESR(sp)           /* save BESR */

	li      p0,0                         	/* clear BESR */
	mtdcr	BESR,p0	
# elif	((CPU == PPC405) || (CPU == PPC405F))
	/*
 	 * For PPC405, since the BEAR/BESR DCR numbers (strictly speaking
	 * the PLB PEAR/PESR) are implementation dependant, we use
	 * BSP provided functions to access these registers.
	 */
	mfspr	p1, LR				/* save current LR */
	bl	sysDcrPlbbearGet		/* read BEAR into p0 */
	stw     p0, _PPC_ESF_BEAR(sp)           /* save BEAR */

	bl	sysDcrPlbbesrGet		/* read BESR into p0 */
	stw     p0, _PPC_ESF_BESR(sp)           /* save BESR */

	li      p0,-1                         	/* clear BESR - write all 1s */
	bl	sysDcrPlbbesrClear		/* write BESR from p0 */
	mtspr	LR, p1				/* restore current LR */
# endif	/* PPC40x */

	/*
	 * SPEFP code in handler not supported.  No need to save for now.
	 */
#if	FALSE
#if     (CPU == PPC85XX)
        mfspr   p1, SPEFSCR                     /* load SPEFSCR to P1 */
        stw     p1, _PPC_ESF_SPEFSCR(sp)        /* save SPEFSCR */
#endif  /* (CPU == PPC85XX) */
#endif	/* FALSE */

# if	(CPU == PPC85XX)
	mfspr   p0, DBSR			/* load DBSR to P0 */
	stw     p0, _PPC_ESF_ESR(sp)		/* save DBSR */
# endif  /* CPU == PPC85XX */

	stw     r0, _PPC_ESF_R0(sp)             /* save general register 0 */

	addi    r0, r1, _PPC_ESF_STK_SIZE
	stw     r0, _PPC_ESF_R1(sp)             /* save exception sp */

	stw     r2, _PPC_ESF_R2(sp)             /* save general register 2 */

# if	TRUE					/* optimization to test */

	/* save the volatile register values on the ESF */

	stw     p2, _PPC_ESF_P2(sp)             /* save general register 5 */
	stw     p3, _PPC_ESF_P3(sp)             /* save general register 6 */
	stw     p4, _PPC_ESF_P4(sp)             /* save general register 7 */
	stw     p5, _PPC_ESF_P5(sp)             /* save general register 8 */
	stw     p6, _PPC_ESF_P6(sp)             /* save general register 9 */
	stw     p7, _PPC_ESF_P7(sp)             /* save general register 10 */

	stw     r11, _PPC_ESF_R11(sp)           /* save general register 11 */
	stw     r12, _PPC_ESF_R12(sp)           /* save general register 12 */
	stw     r13, _PPC_ESF_R13(sp)           /* save general register 13 */

	/* save the non volatile register values on the ESF */

	stw     t0, _PPC_ESF_T0(sp)             /* save general register 14 */
	stw     t1, _PPC_ESF_T1(sp)             /* save general register 15 */
	stw     t2, _PPC_ESF_T2(sp)             /* save general register 16 */
	stw     t3, _PPC_ESF_T3(sp)             /* save general register 17 */
	stw     t4, _PPC_ESF_T4(sp)             /* save general register 18 */
	stw     t5, _PPC_ESF_T5(sp)             /* save general register 19 */
	stw     t6, _PPC_ESF_T6(sp)             /* save general register 20 */
	stw     t7, _PPC_ESF_T7(sp)             /* save general register 21 */
	stw     t8, _PPC_ESF_T8(sp)             /* save general register 22 */
	stw     t9, _PPC_ESF_T9(sp)             /* save general register 23 */
	stw     t10, _PPC_ESF_T10(sp)           /* save general register 24 */
	stw     t11, _PPC_ESF_T11(sp)           /* save general register 25 */
	stw     t12, _PPC_ESF_T12(sp)           /* save general register 26 */
	stw     t13, _PPC_ESF_T13(sp)           /* save general register 27 */
	stw     t14, _PPC_ESF_T14(sp)           /* save general register 28 */
	stw     t15, _PPC_ESF_T15(sp)           /* save general register 29 */
	stw     t16, _PPC_ESF_T16(sp)           /* save general register 30 */
	stw     t17, _PPC_ESF_T17(sp)           /* save general register 31 */
# else	/* TRUE */
	stmw    p2, _PPC_ESF_P2(sp)             /* save general register 5 */
						/* through 31 */
# endif	/* TRUE */

	blr                                     /* return to caller */
FUNC_END(excCrtEnt)


/*******************************************************************************
*
* excCrtExit - default context restore routine upon critical exception exit
*
* NOMANUAL

* void excExit()

*/

FUNC_BEGIN(excCrtExit)
	/* restore dedicated and scratch registers */

	lwz     r0, _PPC_ESF_R0(sp)             /* restore general register 0 */
	lwz     r2, _PPC_ESF_R2(sp)             /* restore general register 2 */

# if	TRUE					/* optimization to test */
	/* restore volatile registers */

	lwz     p1, _PPC_ESF_P1(sp)             /* restore general register 4 */
	lwz     p2, _PPC_ESF_P2(sp)             /* restore general register 5 */
	lwz     p3, _PPC_ESF_P3(sp)             /* restore general register 6 */
	lwz     p4, _PPC_ESF_P4(sp)             /* restore general register 7 */
	lwz     p5, _PPC_ESF_P5(sp)             /* restore general register 8 */
	lwz     p6, _PPC_ESF_P6(sp)             /* restore general register 9 */
	lwz     p7, _PPC_ESF_P7(sp)             /* restore general reg 10 */

	lwz     r11, _PPC_ESF_R11(sp)           /* restore general reg 11 */
	lwz     r12, _PPC_ESF_R12(sp)           /* restore general reg 12 */
	lwz     r13, _PPC_ESF_R13(sp)           /* restore general reg 13 */

	/* restore non-volatile registers */
	/*
	 * XXX TPR the non-volatile should not be restored because they are
	 * not destroyed. To test or verify
	 */

	lwz     t0, _PPC_ESF_T0(sp)             /* restore general reg 14 */
	lwz     t1, _PPC_ESF_T1(sp)             /* restore general reg 15 */
	lwz     t2, _PPC_ESF_T2(sp)             /* restore general reg 16 */
	lwz     t3, _PPC_ESF_T3(sp)             /* restore general reg 17 */
	lwz     t4, _PPC_ESF_T4(sp)             /* restore general reg 18 */
	lwz     t5, _PPC_ESF_T5(sp)             /* restore general reg 19 */
	lwz     t6, _PPC_ESF_T6(sp)             /* restore general reg 20 */
	lwz     t7, _PPC_ESF_T7(sp)             /* restore general reg 21 */
	lwz     t8, _PPC_ESF_T8(sp)             /* restore general reg 22 */
	lwz     t9, _PPC_ESF_T9(sp)             /* restore general reg 23 */
	lwz     t10, _PPC_ESF_T10(sp)           /* restore general reg 24 */
	lwz     t11, _PPC_ESF_T11(sp)           /* restore general reg 25 */
	lwz     t12, _PPC_ESF_T12(sp)           /* restore general reg 26 */
	lwz     t13, _PPC_ESF_T13(sp)           /* restore general reg 27 */
	lwz     t14, _PPC_ESF_T14(sp)           /* restore general reg 28 */
	lwz     t15, _PPC_ESF_T15(sp)           /* restore general reg 29 */
	lwz     t16, _PPC_ESF_T16(sp)           /* restore general reg 30 */
	lwz     t17, _PPC_ESF_T17(sp)           /* restore general reg 31 */
# else	/* TRUE */
	lmw     p1, _PPC_ESF_P1(sp)             /* restore general register 5 */
						/* through 31 */
# endif	/* TRUE */

	/* restore user level special purpose registers */

	lwz     p0, _PPC_ESF_CTR(sp)            /* load saved CTR  to P0*/
	mtspr   CTR, p0                         /* restore CTR */

	lwz     p0, _PPC_ESF_XER(sp)            /* load saved XER to P0 */
	mtspr   XER, p0                         /* restore XER */

	lwz     p0, _PPC_ESF_LR(sp)             /* load saved LR to P0 */
	mtspr   LR, p0                          /* restore LR */

	lwz     p0, _PPC_ESF_CR(sp)             /* load the saved CR to P0 */
	mtcrf   255,p0                          /* restore CR */

	/*
	 * SPEFP code in handler not supported.  No need to save for now.
	 */
#if	FALSE
#if     (CPU==PPC85XX)
        lwz     p0, _PPC_ESF_SPEFSCR(sp)        /* load saved SPEFSCR to P0 */
        mtspr   SPEFSCR, p0                     /* restore SPEFSCR */
#endif  /* (CPU==PPC85XX) */
#endif	/* FALSE */

	/* XXX TPR this code can be optimized */

	mfmsr   p0                              /* read msr */

# ifdef  _PPC_MSR_RI
	RI_MASK(p0, p0 )                        /* mask RI bit */
# endif  /* _PPC_MSR_RI */

	INT_MASK(p0,p0)                         /* clear EE bit in msr */
	mtmsr   p0                              /* DISABLE INTERRUPT */
	isync                                   /* synchronize */

	lwz     p0, _PPC_ESF_PC(sp)             /* load the saved PC to P0 */
	mtspr   CRIT_SAVE_PC, p0		/* and restore CRIT_SAVE_PC */

	lwz     p0, _PPC_ESF_MSR(sp)            /* load the saved MSR to P0 */
	mtspr   CRIT_SAVE_MSR, p0		/* and restore CRIT_SAVE_MSR */

	lwz     p0, _PPC_ESF_P0(sp)             /* restore p0 */

	lwz     sp, _PPC_ESF_SP(sp)             /* restore the stack pointer */

	rfci					/* return to context of the */
						/* task that got exception */
FUNC_END(excCrtExit)

#ifdef	_PPC_MSR_MCE
/******************************************************************************
*
* excMchkEnt - default context save routine on machine check exception entrance
* NOTE: The stack pointer is already set to the exception stack frame pointer.
*       The exception vector on the stack is saved as  vector offset +
*       _EXC_CODE_SIZE.
*
* NOMANUAL

* void excMchkEnt()

*/

FUNC_BEGIN(excMchkEnt)
	/* At the entry of this function, the following is done */
	/* mtspr        SPRG4, p0       /@ save P0 to SPRG4 */
	/* mfspr        p0, LR          /@ load LR to P0 */
	/* bla          excMchkEnt      /@ call excMchkEnt */

	/*
	 * reserve a room equal to the size of the ESF. This memory space is
	 * taken from the stack of the task which has produce the exception.
	 * This memory space is used to save the processor critical register
	 * values.
	 */

	stwu    sp, - _PPC_ESF_STK_SIZE(sp)     /* update SP */

	stw     p0, _PPC_ESF_LR(sp)             /* save LR */

	mfspr   p0, SPRG4_W                     /* load saved P0 */
	stw     p0, _PPC_ESF_P0(sp)             /* save general register P0 */

	mfspr   p0, MCSRR0			/* load saved PC to P0 */
	stw     p0, _PPC_ESF_PC(sp)		/* save PC in ESF */

	mfspr   p0, MCSRR1			/* load saved MSR to P0 */
	stw     p0, _PPC_ESF_MSR(sp)		/* save MSR in ESF */

	stw     p1, _PPC_ESF_P1(sp)             /* save general register P1 */

	mfcr    p1                              /* load CR to P1 */
	stw     p1, _PPC_ESF_CR(sp)             /* save CR */

        /*
         * Before we reenable the MMU, we need to ensure that the values
         * we pushed on the stack above are flushed out of cache.
         */
        dcbf    0, sp               /* push SP value to memory */

        li  p1, _PPC_ESF_LR
        dcbf    p1, sp              /* push LR value to memory */

        li  p1, _PPC_ESF_P0
        dcbf    p1, sp              /* push P0 value to memory */

        li  p1, _PPC_ESF_PC
        dcbf    p1, sp              /* push PC value to memory */

        li  p1, _PPC_ESF_MSR
        dcbf    p1, sp              /* push MSR value to memory */

        li  p1, _PPC_ESF_P1
        dcbf    p1, sp              /* push P1 value to memory */

        li  p1, _PPC_ESF_CR
        dcbf    p1, sp              /* push CR value to memory */

        sync

	/*
	 * Now turn the data or/and instruction MMU on if they were
	 * previously turned on.
	 * the critical registers are save. Now the interrupt and machine
	 * check can be re-enabled. If an interrupt or exception is detected
	 * the previous state can be reconstructed.
	 */

	mfmsr   p1                              /* p1 = MSRval current */
						/* p0 should have MSRval app */

	mtspr   SPRG4_W, p1                     /* SPRG4 = MSRval current */
	lis	p1,  HI( _MSR_MCE | _MSR_CE | _MSR_IS | _MSR_DS | _PPC_MSR_EE )
	ori	p1, p1, LO( _MSR_MCE | _MSR_CE | _MSR_IS | _MSR_DS | _PPC_MSR_EE )
	and.    p0, p1, p0			/* extract app IS,DS,ME,CE,EE */
	mfspr   p1, SPRG4_W                     /* p1 = MSRval before */

	or      p1, p1, p0                      /* p1 = MSRval current with */
						/*      app IS,DS,ME,CE,EE */

	mtmsr   p1                              /* ENABLE INTERRUPT & MMU */
	isync                                   /* synchronize */

	mfspr   p0, LR                          /* p0 = exception number */
						/* may be wrong if relocated */
/*
 * The LR value is offset from the vector address by the size of the
 * bla and other instructions preceding it in excCrtConnectCode (or
 * in excExtCrtConnectCode if excExtendedVectors is in effect).
 *
 * The offset amounts to 4 * (ENT_CRT_OFF + 1) or 4 * EXT_ISR_CRT_OFF
 * respectively, however these symbols are defined in excArchLib.c
 * and the definitions are not accessible here.
 */
	lis     p1, HIADJ(excExtendedVectors)
	lwz     p1, LO(excExtendedVectors)(p1)	/* get excExtendedVectors */
	cmpwi	p1, 0				/* if 0, short vectors */
	beq	mchkShortVec

	li	p1, 20		/* 4 * (EXT_ISR_CRT_OFF - (ENT_CRT_OFF + 1)) */
mchkShortVec:
	addi	p1, p1, 12			/* 4 * (ENT_CRT_OFF + 1) */
	sub	p0, p0, p1
	stw     p0, _PPC_ESF_VEC_OFF(sp)        /* store to ESF */

	mfspr   p0, CTR                         /* load CTR to P0 */
	stw     p0, _PPC_ESF_CTR(sp)            /* save CTR */

	mfspr   p1, XER                         /* load XER to P0 */
	stw     p1, _PPC_ESF_XER(sp)            /* save XER */

	/*
	 * SPEFP code in handler not supported.  No need to save for now.
	 */
#if	FALSE
#if     (CPU == PPC85XX)
        mfspr   p1, SPEFSCR                     /* load SPEFSCR to P1 */
        stw     p1, _PPC_ESF_SPEFSCR(sp)        /* save SPEFSCR */
#endif  /* (CPU == PPC85XX) */
#endif	/* FALSE */

#ifdef _PPC_MSR_MCE
	mfspr	p0, MCAR			/* load MCAR to P0 */
	stw	p0, _PPC_ESF_DEAR(sp)		/* save MCAR */
	mfspr   p0, MCSR			/* load MCSR to P0 */
	stw     p0, _PPC_ESF_ESR(sp)		/* save MCSR */
#endif  /* _PPC_MSR_MCE */

	stw     r0, _PPC_ESF_R0(sp)             /* save general register 0 */

	addi    r0, r1, _PPC_ESF_STK_SIZE
	stw     r0, _PPC_ESF_R1(sp)             /* save exception sp */

	stw     r2, _PPC_ESF_R2(sp)             /* save general register 2 */

# if	TRUE					/* optimization to test */

	/* save the volatile register values on the ESF */

	stw     p2, _PPC_ESF_P2(sp)             /* save general register 5 */
	stw     p3, _PPC_ESF_P3(sp)             /* save general register 6 */
	stw     p4, _PPC_ESF_P4(sp)             /* save general register 7 */
	stw     p5, _PPC_ESF_P5(sp)             /* save general register 8 */
	stw     p6, _PPC_ESF_P6(sp)             /* save general register 9 */
	stw     p7, _PPC_ESF_P7(sp)             /* save general register 10 */

	stw     r11, _PPC_ESF_R11(sp)           /* save general register 11 */
	stw     r12, _PPC_ESF_R12(sp)           /* save general register 12 */
	stw     r13, _PPC_ESF_R13(sp)           /* save general register 13 */

	/* save the non volatile register values on the ESF */

	stw     t0, _PPC_ESF_T0(sp)             /* save general register 14 */
	stw     t1, _PPC_ESF_T1(sp)             /* save general register 15 */
	stw     t2, _PPC_ESF_T2(sp)             /* save general register 16 */
	stw     t3, _PPC_ESF_T3(sp)             /* save general register 17 */
	stw     t4, _PPC_ESF_T4(sp)             /* save general register 18 */
	stw     t5, _PPC_ESF_T5(sp)             /* save general register 19 */
	stw     t6, _PPC_ESF_T6(sp)             /* save general register 20 */
	stw     t7, _PPC_ESF_T7(sp)             /* save general register 21 */
	stw     t8, _PPC_ESF_T8(sp)             /* save general register 22 */
	stw     t9, _PPC_ESF_T9(sp)             /* save general register 23 */
	stw     t10, _PPC_ESF_T10(sp)           /* save general register 24 */
	stw     t11, _PPC_ESF_T11(sp)           /* save general register 25 */
	stw     t12, _PPC_ESF_T12(sp)           /* save general register 26 */
	stw     t13, _PPC_ESF_T13(sp)           /* save general register 27 */
	stw     t14, _PPC_ESF_T14(sp)           /* save general register 28 */
	stw     t15, _PPC_ESF_T15(sp)           /* save general register 29 */
	stw     t16, _PPC_ESF_T16(sp)           /* save general register 30 */
	stw     t17, _PPC_ESF_T17(sp)           /* save general register 31 */
# else	/* TRUE */
	stmw    p2, _PPC_ESF_P2(sp)             /* save general register 5 */
						/* through 31 */
# endif	/* TRUE */

	blr                                     /* return to caller */
FUNC_END(excMchkEnt)


/*******************************************************************************
*
* excMchkExit - default context restore routine on machine check exception exit
*
* NOMANUAL

* void excMchkExit()

*/

FUNC_BEGIN(excMchkExit)
	/* restore dedicated and scratch registers */

	lwz     r0, _PPC_ESF_R0(sp)             /* restore general register 0 */
	lwz     r2, _PPC_ESF_R2(sp)             /* restore general register 2 */

# if	TRUE					/* optimization to test */
	/* restore volatile registers */

	lwz     p1, _PPC_ESF_P1(sp)             /* restore general register 4 */
	lwz     p2, _PPC_ESF_P2(sp)             /* restore general register 5 */
	lwz     p3, _PPC_ESF_P3(sp)             /* restore general register 6 */
	lwz     p4, _PPC_ESF_P4(sp)             /* restore general register 7 */
	lwz     p5, _PPC_ESF_P5(sp)             /* restore general register 8 */
	lwz     p6, _PPC_ESF_P6(sp)             /* restore general register 9 */
	lwz     p7, _PPC_ESF_P7(sp)             /* restore general reg 10 */

	lwz     r11, _PPC_ESF_R11(sp)           /* restore general reg 11 */
	lwz     r12, _PPC_ESF_R12(sp)           /* restore general reg 12 */
	lwz     r13, _PPC_ESF_R13(sp)           /* restore general reg 13 */

	/* restore non-volatile registers */
	/*
	 * XXX TPR the non-volatile should not be restored because they are
	 * not destroyed. To test or verify
	 */

	lwz     t0, _PPC_ESF_T0(sp)             /* restore general reg 14 */
	lwz     t1, _PPC_ESF_T1(sp)             /* restore general reg 15 */
	lwz     t2, _PPC_ESF_T2(sp)             /* restore general reg 16 */
	lwz     t3, _PPC_ESF_T3(sp)             /* restore general reg 17 */
	lwz     t4, _PPC_ESF_T4(sp)             /* restore general reg 18 */
	lwz     t5, _PPC_ESF_T5(sp)             /* restore general reg 19 */
	lwz     t6, _PPC_ESF_T6(sp)             /* restore general reg 20 */
	lwz     t7, _PPC_ESF_T7(sp)             /* restore general reg 21 */
	lwz     t8, _PPC_ESF_T8(sp)             /* restore general reg 22 */
	lwz     t9, _PPC_ESF_T9(sp)             /* restore general reg 23 */
	lwz     t10, _PPC_ESF_T10(sp)           /* restore general reg 24 */
	lwz     t11, _PPC_ESF_T11(sp)           /* restore general reg 25 */
	lwz     t12, _PPC_ESF_T12(sp)           /* restore general reg 26 */
	lwz     t13, _PPC_ESF_T13(sp)           /* restore general reg 27 */
	lwz     t14, _PPC_ESF_T14(sp)           /* restore general reg 28 */
	lwz     t15, _PPC_ESF_T15(sp)           /* restore general reg 29 */
	lwz     t16, _PPC_ESF_T16(sp)           /* restore general reg 30 */
	lwz     t17, _PPC_ESF_T17(sp)           /* restore general reg 31 */
# else	/* TRUE */
	lmw     p1, _PPC_ESF_P1(sp)             /* restore general register 5 */
						/* through 31 */
# endif	/* TRUE */

	/* restore user level special purpose registers */

	lwz     p0, _PPC_ESF_CTR(sp)            /* load saved CTR  to P0*/
	mtspr   CTR, p0                         /* restore CTR */

	lwz     p0, _PPC_ESF_XER(sp)            /* load saved XER to P0 */
	mtspr   XER, p0                         /* restore XER */

	lwz     p0, _PPC_ESF_LR(sp)             /* load saved LR to P0 */
	mtspr   LR, p0                          /* restore LR */

	lwz     p0, _PPC_ESF_CR(sp)             /* load the saved CR to P0 */
	mtcrf   255,p0                          /* restore CR */

	/*
	 * SPEFP code in handler not supported.  No need to save for now.
	 */
#if	FALSE
#if     (CPU==PPC85XX)
        lwz     p0, _PPC_ESF_SPEFSCR(sp)        /* load saved SPEFSCR to P0 */
        mtspr   SPEFSCR, p0                     /* restore SPEFSCR */
#endif  /* (CPU==PPC85XX) */
#endif	/* FALSE */

	/* XXX TPR this code can be optimized */

	mfmsr   p0                              /* read msr */

# ifdef  _PPC_MSR_RI
	RI_MASK(p0, p0 )                        /* mask RI bit */
# endif  /* _PPC_MSR_RI */

	INT_MASK(p0,p0)                         /* clear EE/CE bit in msr */
	mtmsr   p0                              /* DISABLE INTERRUPT */
	isync                                   /* synchronize */

	lwz     p0, _PPC_ESF_PC(sp)             /* load the saved PC to P0 */
	mtspr   MCSRR0, p0			/* and restore MCSRR0 */

	lwz     p0, _PPC_ESF_MSR(sp)            /* load the saved MSR to P0 */
	mtspr   MCSRR1, p0			/* and restore MCSRR1 */

	lwz     p0, _PPC_ESF_P0(sp)             /* restore p0 */

	lwz     sp, _PPC_ESF_SP(sp)             /* restore the stack pointer */

	rfmci					/* return to context of the */
						/* task that got exception */
FUNC_END(excMchkExit)
#endif 	/* _PPC_MSR_MCE */

#endif 	/* _PPC_MSR_CE */

/*******************************************************************************
*
* excEPSet - set exception vector prefix
*
* NOMANUAL
*/

FUNC_BEGIN(excEPSet)
#ifdef	_PPC_MSR_IP
	mfmsr	p7			/* load msr to p7 */
	li	p6, _PPC_MSR_IP		/* load IP mask bit to p6 */
	cmpwi	p0, 0			/* is base address zero */
	beq	excEPClear		/* goto clear IP bit */
	or	p7, p6, p7		/* set IP bit */
	b	excMsrSet		/* go to set msr */
excEPClear:
	rlwinm 	p7, p7, 0, 26, 24	/* clear _PPC_MSR_IP bit */
excMsrSet:
	mtmsr	p7			/* set msr */
#endif	/* _PPC_MSR_EP */
	blr				/* return to the caller */
FUNC_END(excEPSet)

#ifdef	IVOR0
/*******************************************************************************
*
* excIvorInit - set IVOR's as defined in excPpcLib.h
*
* NOMANUAL
*
* void excIvorInit(void)
*
*/
FUNC_EXPORT(excIvorInit)
FUNC_BEGIN(excIvorInit)
	li	p0,IVOR0_VAL
	mtspr	IVOR0,p0
	li	p0,IVOR1_VAL
	mtspr	IVOR1,p0
	li	p0,IVOR2_VAL
	mtspr	IVOR2,p0
	li	p0,IVOR3_VAL
	mtspr	IVOR3,p0
	li	p0,IVOR4_VAL
	mtspr	IVOR4,p0
	li	p0,IVOR5_VAL
	mtspr	IVOR5,p0
	li	p0,IVOR6_VAL
	mtspr	IVOR6,p0
	li	p0,IVOR7_VAL
	mtspr	IVOR7,p0
	li	p0,IVOR8_VAL
	mtspr	IVOR8,p0
	li	p0,IVOR9_VAL
	mtspr	IVOR9,p0
	li	p0,IVOR10_VAL
	mtspr	IVOR10,p0
	li	p0,IVOR11_VAL
	mtspr	IVOR11,p0
	li	p0,IVOR12_VAL
	mtspr	IVOR12,p0
	li	p0,IVOR13_VAL
	mtspr	IVOR13,p0
	li	p0,IVOR14_VAL
	mtspr	IVOR14,p0
	li	p0,IVOR15_VAL
	mtspr	IVOR15,p0
#if     (CPU==PPC85XX)
	li	p0,IVOR32_VAL
	mtspr	IVOR32,p0
	li	p0,IVOR33_VAL
	mtspr	IVOR33,p0
	li	p0,IVOR34_VAL
	mtspr	IVOR34,p0
	li	p0,IVOR35_VAL
	mtspr	IVOR35,p0
#endif  /* (CPU==PPC85XX) */
	blr
FUNC_END(excIvorInit)
#endif	/* IVOR0 */
