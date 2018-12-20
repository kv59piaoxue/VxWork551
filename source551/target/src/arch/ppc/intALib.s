/* intALib.s - assembly language interrupt handling routines */

/* Copyright 1984-2003 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
02h,09jun03,mil  Merged from CP1 to e500.
02g,30jan03,jtp  Comment intCrtEnt regarding need to flush critical save
		 data before reenabling MMU
02f,20nov02,mil  Updated support for PPC85XX.
02e,03oct02,dtr  Adding save/restore of spefscr for 85XX.
02d,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
02c,13jun02,jtp  disable MMU during context restore for 4XX (SPR #78396)
02b,17may02,pch  SPR 77035: fix WindView calculation of vector address
02a,17apr02,jtp  support PPC440 cache & mmu
01z,15oct01,kab  Fix SPR #71240: Enable PPC604 MMU IR,DR rather than
		 cache lock.
01z,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01y,18sep01,tcr  fix WindView instrumentation for interrupts
01x,16aug01,pch  Add PPC440 support; change test for CPU==PPC4xx to ifdef
		 _PPC_MSR_CE_U where appropriate
01w,20jun01,pch  Export intCrtEnt & intCrtExit for PPC405
01v,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01u,17apr01,dtr  FUNC doesn't work relpacing with function type.
		 This should enable intLock etc to be seen as function in
		 symbol table.
01y,25oct00,s_m  renamed PPC405 cpu types
01x,18oct00,s_m  restore MMU state in intExit for PPC405
01w,18oct00,s_m  enable MMU in interrupt wrapper
01v,13oct00,sm   fpfix and fpCrtfix are externs only for PPC405F
01u,06oct00,sm   Include fix for PPC405F errata
01t,24aug98,cjtc Windview 2.0 event logging now handled in int controller
		 code. Avoids problem with out-of-sequence timestamps in
		 event log (SPR 21868)
01q,18aug98,tpr  added PowerPC EC 603 support.
01s,16apr98,pr   commenting out triggering code. Modified evtAction into int32
01r,23jan98,pr   modified WV code accordingly to the changes made in eventP.h
01q,13dec97,pr   started changes of WindView code for WV2.0. STILL IN PROGRESS
01p,06aug97,tam  fixed problem with CE interrupt (SPR #8964)
01o,22jul97,tpr  added sync instruction arround HID0 modification (SPR #8976)
01n,27mar97,tam  set FP & RI bits before calling the rescheduler (SPR #8286)
01m,18mar97,tam  modified interrupt masks for PPC403; added intCrtEnt() and
		 intCrtExit() (SPR #8192).
01l,12dec96,tpr  added sync before HID0 changing to lock data cache (SPR #7605)
01k,15jul96,tpr  replace cahce flushing by cache locking in intEnt().
01j,11jul96,pr   cleanup for windview instrumentation
01i,08jul96,pr   added windview instrumentation - conditionally compiled
01h,24jun96,tpr  added  PowerPC 860 support.
01g,23may96,tpr  fixed SPR 6593.
01f,06mar96,tpr  removed bug intExit() for PPC603.
01e,23feb96,tpr  added intEnt() and intExit().
01d,23sep95,tpr  changed intUnlock code to unlock interrupt only.
01c,03feb95,caf  cleanup.
01b,05dec94,caf  changed 'bcr' to 'bclr'.
*/

/*
DESCRIPTION
This library contains various functions associated with interrupt management
for the PowerPC family. The intEnt() entry point is used to save the current
context prior to call the C or assembly interrupt handler. intExit() is used
to leave interrupt processing and restart the current task or interrupt handler,
or call the rescheduler if a higher priority task has been made ready by the
interrupt handler.
The routines intLock() and intUnlock() are used to lock and unlock external
interrupts and the internal decrementer (PPC440, PPC601, PPC603, PPC604) or
timer (PPC403, PPC405) during critical code sections.

Architecture:

            intExit()
               |
     __________|____________
    /                       \
    | in Kernel             | not in Kernel and
    v or Nested             v not Nested
    |         ______________|__________________
 intRet      /                                 \
             | current task =                  | current task not
             v highest ready task              v highest ready task
             |                _________________|______________
          intRet             /                                \
                             | preempt disabled               |
                             v or task not ready         saveIntContext
                             |                                |
                          intRet                          reschedule()
                                                              |
                                                         windLoadContext()


SEE ALSO: intLib, windALib, excALib, sigCtxLib

*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "esf.h"
#include "private/eventP.h"
#include "private/taskLibP.h"
#include "excLib.h"

/* Certain versions of PPC405F need a fix for Errata # 18 (lfd) instruction
 * Note: This errata is numbered 18 for the 405GF and numbered 20 for the
 * D8405
 */
#define PPC405F_ERRATA_18		/* define this to include fix */

	/* globals */

	FUNC_EXPORT(intEnt)		/* Interrupt Entry routine */
	FUNC_EXPORT(intExit)		/* Interrupt Exit routine */
#ifdef	_PPC_MSR_CE_U
	FUNC_EXPORT(intCrtEnt)		/* Critical Interrupt Entry routine */
	FUNC_EXPORT(intCrtExit)		/* Critical Interrupt Exit routine */
#endif 	/* _PPC_MSR_CE_U */
	FUNC_EXPORT(intLock)		/* Interrupt Lock routine */
	FUNC_EXPORT(intUnlock)		/* Interrupt Unlock routine */

	/* externs */

	FUNC_IMPORT(reschedule)		/* rescheduler */

#if (CPU == PPC405F)
	FUNC_EXPORT(fpfix)		/* PPC405F errata fix */
	FUNC_EXPORT(fpCrtfix)		/* PPC405F errata fix for crt.intrp */
#endif	/* CPU == PPC405F */

	DATA_IMPORT(readyQHead)		/* ready queue head */
	DATA_IMPORT(kernelState)	/* kernel state */
	DATA_IMPORT(taskIdCurrent)	/* current task identifier */
	DATA_IMPORT(intCnt)		/* interrupt counter */
	DATA_IMPORT(errno)		/* error number */

	_WRS_TEXT_SEG_START

/*******************************************************************************
*
* intEnt - catch and dispatch external interrupts
*
* This is the interrupt dispatcher that is pointed by the PowerPC exception.
* It saves the context when interrupt happens and return to the stub.
*
* NOMANUAL

* void excIntStub()

*/


FUNC_BEGIN(intEnt)
	/* At the entry of this function, the following is done */
	/* mtspr	SPRG3, p0	/@ save P0 to SPRG3 */
	/* mfspr	p0, LR		/@ load LR to P0 */
	/* bla		intEnt		/@ save vector in LR, jump to handler */

	mtspr	SPRG2, p0		/* save LR to SPRG2 */

	mtspr	SPRG0, p1		/* save P1 to SPRG0 */

	/*
	 * On the PowerPC 60X, when an external interrupt is taken, the
	 * processor turns the MMU off. At this moment the cache is no
	 * longer controlled by the WIMG bits of the MMU. If the data cache
	 * is on, the value of the SP, CR, PC and MSR register are written in
	 * the cache and not in the memory.
	 * The interrupt handler should be executed with the MMU in the
	 * same state as the non-interrupt code. This stub should
	 * re-enable the data or/and instruction MMU if they were enabled
	 * before the interrupt.
	 * By re-enabling the MMU, the cache restarts to be controlled via the
	 * WIMG bits. If the memory pages which handle the interrupt stack are
	 * in not cacheables state, the cache is turn off for all memory acces
	 * in this area.
	 * In intExit() the SP, CR, PC, and MSR register values should be
	 * restored. Because the MMU is on, the processor go to read the memory
	 * to get the register values. But the true value is save in the cache.
	 * In this case the restored value is corrupted and can crash VxWorks.
	 * To avoid memory this coherency problem, the data cache should be
	 * locked.
	 */

	/*
	 * Note that the PPC604 has HW support for TLB-miss.
	 * PPC603 &c cannot enable the TLB until ready to handle nested
	 * interrupts from a TLB-miss.  This is not an issue for the PPC604,
	 * so enable the MMU I/D immediately, get the cache state back, and
	 * don't go through any cache-lock gyrations.
	 * This is a critical performance issue if HID0[ABE] (propagate
	 * sync to bus) is set:	 The PPC7400/7410 cannot turn it off.
	 */
#if	(CPU == PPC604)
	mfspr	p1, SRR1			/* load P1 w/ SRR1(MSR) */
	rlwinm	p1, p1, 0, 26, 27		/* get IR and DR bit values */
						/* before the interrupt */
	mfmsr	p0				/* get the current MSR value */
	or	p0, p0, p1			/* set MMU bits if previously */
	mtmsr	p0				/* set & restore MSR value */
	isync					/* instruction sync. */
#endif	/* (CPU == PPC604) */

	mfcr	p1			/* save CR to P1 before it is changed */

	/*
	 * The special purpose register SPRG1 contains the real interrupt
	 * nesting count.  It is initialzed in wintIntStackSet() in windALib.s.
	 * Because intCnt is faked in windTickAnnounce(), intCnt cannot be
	 * used for checking of nested interrupts to switch stack.
	 */

	mfspr	p0, SPRG1		/* get nested count */
	addi	p0, p0, 1		/* increment nested count */
	mtspr	SPRG1, p0		/* update nested count */

	/*
	 * The PowerPC Familly doesn't support the notion of interrupt
	 * stack. To avoid to add the size of interrupt stack in each task
	 * stack this stub switch from the task stack to the interrupt stack
	 * by changing the value of the SP(R1).
	 * This switch should be performed only if the interrupt is not
	 * a nested interrupt.
	 */

	cmpwi	p0, 1			/* test for nested interrput */
	beq	intStackSwitch		/* no, switch to interrupt stack */

#if	((CPU == PPC603) || (CPU == PPCEC603))
	mfspr	p0, HID0			/* get HID0 value */
	mtcr	p0				/* save temporily HID0 */
	ori	p0, p0, _PPC_HID0_DLOCK		/* set the DLOCK bit */
	sync
	mtspr	HID0, p0			/* LOCK the Data Cache */
#endif	/* ((CPU == PPC603) || (CPU == PPCEC603) */

	stwu	sp, -_PPC_ESF_STK_SIZE(sp)	/* we already use int. stack */
	b	intSaveCritical			/* save old stack pointer */

intStackSwitch:
#if	((CPU == PPC603) || (CPU == PPCEC603))
	mfspr	p0, HID0			/* get HID0 value */
	mtcr	p0				/* save temporily HID0 */
	ori	p0, p0, _PPC_HID0_DLOCK		/* set the DLOCK bit */
	sync
	mtspr	HID0, p0			/* LOCK the Data Cache */
#endif	/* ((CPU == PPC603) || (CPU == PPCEC603)) */

	addi	p0, sp, 0			/* save current SP to P0 */
	lis	sp, HIADJ(vxIntStackBase)	/* load int. stack base addr. */
	lwz	sp, LO(vxIntStackBase)(sp)  	/* in SP */
	stwu	p0,  -_PPC_ESF_STK_SIZE(sp)	/* carve stack */

intSaveCritical:
	stw	p1, _PPC_ESF_CR(sp)		/* save CR */

	mfspr	p0, SRR0			/* load P0 with SRR0(PC) */
	stw	p0, _PPC_ESF_PC(sp)		/* save SRR0(PC) */

	mfspr	p1, SRR1			/* load P1 with SRR1(MSR) */
	stw	p1, _PPC_ESF_MSR(sp)		/* save SRR1(MSR) */

#if 	(CPU == PPC405F)
        /*
         * we need the following fix for certain versions of PPC405F
         */
# ifdef PPC405F_ERRATA_18
        mfspr   p0, LR                          /* save current LR */
	stw	p0, _PPC_ESF_LR(sp)
        bl      fpfix	                        /* handle fix */
        lwz	p0, _PPC_ESF_LR(sp)
        mtspr   LR, p0				/* restore current LR */
# endif	/* PPC405F_ERRATA_18 */

#endif  /* (CPU == PPC405F) */

#if	((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
	 (CPU == PPC85XX))
	/*
 	 * Before we reenable the MMU, we need to ensure that the values
	 * we pushed on the stack above are flushed out of cache.
	 */
    	dcbf    0, sp               /* push SP value in memory */

	li  p0, _PPC_ESF_CR
	dcbf    p0, sp              /* push CR value in memory */

	li  p0, _PPC_ESF_PC
	dcbf    p0, sp              /* push PC value in memory */

	li  p0, _PPC_ESF_MSR
	dcbf    p0, sp              /* push MSR value in memory */

	sync
#endif	/* CPU == PPC405 || CPU == PPC405F || CPU == PPC440 */

#if	((CPU == PPC603) || (CPU == PPCEC603))
	mfcr	p0				/* load temporily saved HID0 */
	mtspr	HID0, p0			/* UNLOCK the Data Cache */
#endif	/* ((CPU == PPC603) || (CPU == PPCEC603)) */

	/* PPC604 enabled MMU IR/DR above */
#ifdef	_WRS_TLB_MISS_CLASS_SW
	/*
	 * 604 MMU (Hardware miss handling) was reenabled above; this case
	 * will reenable all other MMUs (software miss handlers)
	 */

	rlwinm	p1, p1, 0, 26, 27		/* get IR and DR bit values */
						/* before the interrupt */
	mfmsr	p0				/* get the current MSR value */
	or	p0, p0, p1			/* set MMU bits if previously */
	mtmsr	p0				/* set & restore MSR value */
	isync					/* instruction sync. */
#endif	/* _WRS_TLB_MISS_CLASS_SW */

	mfspr	p0, SPRG2			/* load saved LR to P0 */
	stw	p0, _PPC_ESF_LR(sp)		/* save LR */

	mfspr	p0, SPRG3			/* reload saved P0 */
	stw	p0, _PPC_ESF_P0(sp) 		/* save P0 to the stack */

	mfspr	p1, SPRG0			/* reload saved P1 */
	stw	p1, _PPC_ESF_P1(sp) 		/* save P1 to the stack */

        lis     p0, HIADJ(errno)
        lwz     p0, LO(errno)(p0)		/* load ERRNO to P0 and */
	stw	p0, _PPC_ESF_ERRNO(sp)		/* save ERRNO to the stack */

        lis     p1, HIADJ(intCnt)
        lwz     p0, LO(intCnt)(p1)		/* load intCnt value */
        addi    p0, p0, 1			/* increment intCnt value */
        stw     p0, LO(intCnt)(p1)		/* save new intCnt value */

	/*
	 * The critical status are saved at this stage. The interrupt should
	 * be enabled as soon as possible to reduce the interrupt latency.
	 * However, there is only one mask bit on PowerPC. It is at the
	 * interrupt controller level to set mask for each individual
	 * interrupt.
	 * Thus, we save task's register first, then call interrupt controller
	 * routine to decide if the interrupt should be re-enabled or not.
	 */

	mfspr	p0, XER				/* load XER to P0 */
	stw	p0, _PPC_ESF_XER(sp)		/* save XER to the stack */

	mfspr	p0, CTR				/* load CTR to P0 */
	stw	p0, _PPC_ESF_CTR(sp)		/* save CTR to the stack */

#if	(CPU==PPC601)
	mfspr	p0, MQ				/* load MQ to P0 */
	stw	p0, _PPC_ESF_MQ(sp)		/* save MQ to the stack */
#endif	/* (CPU==PPC601) */
#if	(CPU==PPC85XX)
	mfspr	p0, SPEFSCR			/* load SPEFSCR to P0 */
	stw	p0, _PPC_ESF_SPEFSCR(sp)    /* save SPEFSCR to the stack */
#endif	/* (CPU==PPC85XX) */

#if	FALSE
	lwz	p0, 0(sp)
	stw	p0, _PPC_ESF_SP(sp)
#endif

	stw	r0, _PPC_ESF_R0(sp)		/* save general register 0 */
	stw	r2, _PPC_ESF_R2(sp)		/* save general register 2 */

	stw	p2, _PPC_ESF_P2(sp) 		/* save general register 5 */
	stw	p3, _PPC_ESF_P3(sp) 		/* save general register 6 */
	stw	p4, _PPC_ESF_P4(sp) 		/* save general register 7 */
	stw	p5, _PPC_ESF_P5(sp) 		/* save general register 8 */
	stw	p6, _PPC_ESF_P6(sp) 		/* save general register 9 */
	stw	p7, _PPC_ESF_P7(sp) 		/* save general register 10 */

	stw	r11, _PPC_ESF_R11(sp)		/* save general register 11 */
	stw	r12, _PPC_ESF_R12(sp)		/* save general register 12 */
	stw	r13, _PPC_ESF_R13(sp)		/* save general register 13 */

	/*
	 * The callee should save the non volatile registers, thus they are
	 * not saved here. An assembly routine should not use these registers
	 * or follow the calling convention by saving them before using.
	 */


	/*
	 * Instrumentation for external interrupts is done in the interrupt
	 * controller code. The timestamp is no longer taken here. This avoids
	 * the problem with out-of-sequence timestamps appearing in the event
	 * log if a tickAnnounce occurs between here and when the interrupt
	 * controller code is taken (SPR 21358)
	 */

#ifdef  WV_INSTRUMENTATION
        /* windview instrumentation - BEGIN
         * enter an interrupt handler.
         */

        lis     p6, HIADJ(evtAction)            /* WindView or triggering on? */
        lwz     p0, LO(evtAction)(p6)
        cmpwi   p0, 0
        bne     actionIntEnt                    /* if so, more tests */

noActionIntEnt:

#endif  /* WV_INSTRUMENTATION */

        blr					/* return */

#ifdef  WV_INSTRUMENTATION

actionIntEnt:

       /*
        * The external interrupt is instrumented elsewhere, so the only one we
        * do here is decrementer (or PIT for PPC40x).
        */

        mfspr   p0, LR                          /* save exception number to P0*/

/*
 * The LR value is offset from the vector address by the size of the
 * bla and other instructions preceding it in excConnectCode (or in
 * excExtConnectCode if excExtendedVectors is in effect).  For the
 * "normal" interrupts handled here, the difference varies depending
 * on whether the processor also implements "critical" exceptions.
 *
 * In either case, the offset amounts to 4 * (ENT_OFF + 1) for "short"
 * vectors or 4 * EXT_ISR_OFF for extended vectors; however these symbols
 * are defined in excArchLib.c and the definitions are not accessible here.
 */
	lis     p6, HIADJ(excExtendedVectors)
	lwz     p6, LO(excExtendedVectors)(p6)	/* get excExtendedVectors */
	cmpwi	p6, 0				/* if 0, short vectors */
	beq	shortVec

	li	p6, 20			/* 4 * (EXT_ISR_OFF - (ENT_OFF + 1)) */
shortVec:

#ifdef	_EXC_OFF_CRTL
	addi	p6, p6, 28			/* 4 * (ENT_OFF + 1) */
#else	/* _EXC_OFF_CRTL */
	addi	p6, p6, 12			/* 4 * (ENT_OFF + 1) */
#endif	/* _EXC_OFF_CRTL */
	sub	p0, p0, p6

	stw	p0, _PPC_ESF_VEC_OFF(sp)	/* store to ESF */

#if (defined (_EXC_OFF_DECR) || defined (_EXC_OFF_PIT))

#if (defined (_EXC_OFF_DECR))
        cmpwi   p0, _EXC_OFF_DECR
#else   /* _EXC_OFF_DECR */
        cmpwi   p0, _EXC_NEW_OFF_PIT
#endif /*  _EXC_OFF_DECR */

        bne     noActionIntEnt

	/* wvEvtClass&(WV_CLASS_1|WV_ON) == (WV_CLASS1|WV_ON) */

        lis     p6, HIADJ(wvEvtClass)           /* is windview on? */
        lwz     p4, LO(wvEvtClass)(p6)
        lis     p0, HI(WV_CLASS_1_ON)
        ori     p0, p0, LO(WV_CLASS_1_ON)
        and     p6, p4, p0

        cmpw    p6, p0
        bne     trgCheckIntEnt                  /* if not, go to trigger */


        lis     p6, HIADJ(_func_evtLogT0)       /* check if logging func */
        lwz     p0, LO(_func_evtLogT0)(p6)      /* exists */
        cmpwi   p0, 0
        beq     trgCheckIntEnt                  /* if NULL, go to trigger */

        stwu    sp, -(FRAMEBASESZ+ _STACK_ALIGN_SIZE)(sp) /* carve stack frame */
        mfspr   p6, LR                          /* read lr to p6 */
        stw     p6, FRAMEBASESZ (sp)            /* save lr */

        /* Make an event id, and generate event */

        mtlr    p0                              /* call through the funcptr */
        li      p0, PPC_DECR_INT_ID

        blrl

        lwz     p6,  FRAMEBASESZ (sp)
        mtspr   LR, p6                          /* restore lr */
        addi    sp, sp, FRAMEBASESZ + _STACK_ALIGN_SIZE /* release stack */


trgCheckIntEnt:

        lis     p6, HIADJ(trgEvtClass)          /* are there any triggers? */
        lwz     p4, LO(trgEvtClass)(p6)
        lis     p1, HI(TRG_CLASS_1_ON)
        ori     p1, p1, LO(TRG_CLASS_1_ON)
        and     p4, p4, p1
        cmpw    p1, p4
        bne     noActionIntEnt                  /* if none, exit */

        lis     p6, HIADJ(_func_trgCheck)       /* check if trgCheck func */
        lwz     p1, LO(_func_trgCheck)(p6)      /* exists, leave it in p1 */
        cmpwi   p1, 0
        beq     noActionIntEnt                  /* if none, exit */

        stwu    sp, -(FRAMEBASESZ+ _STACK_ALIGN_SIZE)(sp) /* carve stack frame */
        mflr    p6                              /* read lr to p6 */
        stw     p6, FRAMEBASESZ (sp)            /* save lr */

        mtlr    p1

        li      p0, PPC_DECR_INT_ID
        li      p1, 0
        li      p2, 0
        li      p3, 0
        li      p4, 0
        li      p5, 0
        li      p6, 0
        li      p7, 0

        blrl                                    /* check for triggers */

        lwz     p6,  FRAMEBASESZ (sp)
        mtspr   LR, p6                          /* restore lr */
        addi    sp, sp, FRAMEBASESZ + _STACK_ALIGN_SIZE /* release stack */

#endif  /* (defined (_EXC_OFF_DECR) || defined (_EXC_OFF_PIT)) */

        ba      noActionIntEnt

#endif /* WV_INSTRUMENTATION */

FUNC_END(intEnt)


/*******************************************************************************
*
* intExit - exit an interrupt service routine
*
* Check the kernel ready queue to determine if rescheduling is necessary.  If
* no higher priority task has been readied, and no kernel work has been queued,
* then we return to the interrupted task.
*
* If rescheduling is necessary, the context of the interrupted task is saved in
* its associated TCB with the PC, MSR in SRR0, SRR1.
* This routine must be branched to when exiting an interrupt service routine.
* This normally happens automatically, from the stub built by excIntConnect (2).
*
* This routine can NEVER be called from C.
*
* INTERNAL
* This routine must preserve all registers up until the context is saved,
* so any registers that are used to check the queues must first be saved on
* the stack.
*
* At the call to reschedule the value of taskIdCurrent must be in p0.
*
* SEE ALSO: excIntConnect(2)

* void intExit ()

*/


FUNC_BEGIN(intExit)
	mfmsr	p0				/* read msr to p0 */

#ifdef	_PPC_MSR_RI
	RI_MASK (p0, p0)			/* mask RI bit */
#endif	/* _PPC_MSR_RI */

	INT_MASK(p0, p0)			/* clear EE and RI bit */
	mtmsr	p0				/* DISABLE INTERRUPT */
	isync					/* synchronize */

#ifdef  WV_INSTRUMENTATION
        /* windview instrumentation - BEGIN
         * log event if work has been done in the interrupt handler.
         */

/* this is the idea:
              if workQIsEmpty
              EVT_CTX_0(EVENT_INT_EXIT)
              else
              EVT_CTX_0(EVENT_INT_EXIT_K)
*/

        lis     p6, HIADJ(evtAction)            /* is WindView on? */
        lwz     p0, LO(evtAction)(p6)
        cmpwi   p0, 0
        beq     noActionIntExit                 /* if not, exit */

        lis     p6, HIADJ(wvEvtClass)           /* is windview on? */
        lwz     p4, LO(wvEvtClass)(p6)
        lis     p1, HI(WV_CLASS_1_ON)
        ori     p1, p1, LO(WV_CLASS_1_ON)
        and     p6, p4, p1

        cmpw    p1, p6
        bne     trgCheckIntExit                 /* if not, go to trigger */

        lis     p3, HIADJ(workQIsEmpty)         /* is work queue empty? */
        lwz     p2, LO(workQIsEmpty)(p3)
        cmpwi   p2, 0
        beq     intExitNoK
        li      p0, EVENT_INT_EXIT_K
        b       intExitCont
intExitNoK:
        li      p0, EVENT_INT_EXIT              /* get event id */
intExitCont:
        stwu    sp, -(FRAMEBASESZ+_STACK_ALIGN_SIZE)(sp) /* stack frame * /
        mfspr   p6, LR                          /* read lr to p6 */
        stw     p6, FRAMEBASESZ (sp)            /* save lr */

        lis     p6, HIADJ(_func_evtLogT0)
        lwz     p1, LO(_func_evtLogT0)(p6)
        mtlr    p1
        blrl

        lwz     p6,  FRAMEBASESZ (sp)
        mtspr   LR, p6                          /* restore lr */
        addi    sp, sp, FRAMEBASESZ + _STACK_ALIGN_SIZE /* release stack */
trgCheckIntExit:

        lis     p6, HIADJ(trgEvtClass)          /* are there any triggers? */
        lwz     p4, LO(trgEvtClass)(p6)
        lis     p1, HI(TRG_CLASS_1_ON)
        ori     p1, p1, LO(TRG_CLASS_1_ON)
        and     p4, p4, p1

        cmpw    p1, p4
        bne     noActionIntExit                 /* if none, exit */

        lis     p3, HIADJ(workQIsEmpty)         /* is work queue empty? */
        lwz     p2, LO(workQIsEmpty)(p3)
        cmpwi   p2, 0
        beq     trgIntExitNoK
        li      p0, EVENT_INT_EXIT_K
        b       trgIntExitCont
trgIntExitNoK:

        li      p0, EVENT_INT_EXIT              /* get event id */
trgIntExitCont:

        lis     p6, HIADJ(_func_trgCheck)       /* check if trgCheck func */
        lwz     p1, LO(_func_trgCheck)(p6)      /* exists */
        cmpwi   p1, 0
        beq     noActionIntExit                  /* if none, exit */

        stwu    sp, -(FRAMEBASESZ+_STACK_ALIGN_SIZE)(sp) /* stack frame * /
        mfspr   p6, LR                          /* read lr to p6 */
        stw     p6, FRAMEBASESZ (sp)            /* save lr */

        mtlr    p1

        li      p1, 0		/* CLASS1_INDEX */
        li      p2, 0
        li      p3, 0
        li      p4, 0
        li      p5, 0
        li      p6, 0
        li      p7, 0

        blrl                                    /* check for triggers */

        lwz     p6,  FRAMEBASESZ (sp)
        mtspr   LR, p6                          /* restore lr */
        addi    sp, sp, FRAMEBASESZ + _STACK_ALIGN_SIZE /* release stack */

noActionIntExit:
/* windview instrumentation - END */
#endif /* WV_INSTRUMENTATION */

	lwz	r0, _PPC_ESF_R0(sp)		/* restore general register 0 */
	lwz	r2, _PPC_ESF_R2(sp)		/* restore general register 2 */

	lwz	p4, _PPC_ESF_P4(sp)		/* restore general reg 7 */
	lwz	p5, _PPC_ESF_P5(sp)		/* restore general reg 8 */
	lwz	p6, _PPC_ESF_P6(sp)		/* restore general reg 9 */
	lwz	p7, _PPC_ESF_P7(sp)		/* restore general reg 10 */

	lwz	r11, _PPC_ESF_R11(sp)		/* restore general reg 11 */
	lwz	r12, _PPC_ESF_R12(sp)		/* restore general reg 12 */
	lwz	r13, _PPC_ESF_R13(sp)		/* restore general reg 13 */

	lwz	p0, _PPC_ESF_XER(sp)		/* load the saved XER to P0 */
	mtspr	XER, p0				/* restore XER */

	lwz	p0, _PPC_ESF_CTR(sp)		/* load the saved CTR to P0 */
	mtspr	CTR, p0				/* restore CTR */

#if	(CPU==PPC601)
	lwz	p0, _PPC_ESF_MQ(sp)		/* load the saved MQ to P0 */
	mtspr	MQ, p0				/* restore MQ */
#endif	/* (CPU==PPC601) */
#if	(CPU==PPC85XX)
	lwz	p0, _PPC_ESF_SPEFSCR(sp)		/* load the saved MQ to P0 */
	mtspr	SPEFSCR, p0				/* restore MQ */
#endif	/* (CPU==PPC85XX) */

	lis	p0, HIADJ(errno)
	lwz	p3, _PPC_ESF_ERRNO(sp)		/* load errno value */
	stw	p3, LO(errno)(p0)		/* restore errno value */

	lwz	p0, _PPC_ESF_LR(sp)		/* load the saved LR to P0 */
	mtspr	LR, p0				/* restore LR */

        lis     p1, HIADJ(intCnt)
        lwz     p2, LO(intCnt)(p1)		/* load intCnt value to P2 */
        addi    p2, p2, -1			/* decrement intCnt value */
        stw     p2, LO(intCnt)(p1)		/* save new intCnt value */

	mfspr	p0, SPRG1			/* load nesting count to P0 */
	addi	p0, p0, -1			/* decrement nesting count */
	mtspr	SPRG1, p0			/* update nesting count */

	/*
	 * we don't rely on the global variable <intCnt> because
	 * windTickAnnounce() modifies it to fake an ISR context.
	 */

	cmpwi	p0, 0				/* SPRG1 says nested int? */
	bne	intRte				/* yes, just return */

        lis     p2, HIADJ(kernelState)
        lwz     p0, LO(kernelState)(p2)		/* load kernelState to P0 */

	cmpwi	p0, 0				/* if kernelState == TRUE */
	bne	intRte				/* just clean up and return */

        lis     p0, HIADJ(taskIdCurrent)
        lwz     p0, LO(taskIdCurrent)(p0)	/* load taskIdCurrent to P0 */

        lis     p1, HIADJ(readyQHead)
        lwz     p1, LO(readyQHead)(p1)		/* load readyQHead to P1 */

	cmpw	p0, p1				/* comp to highest ready task */
	beq	intRte				/* return from interrput */

	lwz	p1, WIND_TCB_LOCK_CNT(p0)	/* load p1 with task lock cnt */
	cmpwi	p1, 0 				/* if task preemption allowed */
	beq	saveIntContext			/* then save task context */

	lwz	p1, WIND_TCB_STATUS(p0)		/* set p2 to task's status */
	cmpwi	p1, 0				/* if task ready to run */
	bne	saveIntContext			/* if no, save context */

intRte:
	lwz	p1, _PPC_ESF_P1(sp)		/* restore p1 */
	lwz	p2, _PPC_ESF_P2(sp)		/* restore p2 */
	lwz	p3, _PPC_ESF_P3(sp)		/* restore general reg 6 */

	lwz	p0, _PPC_ESF_CR(sp)
	mtcrf	255,p0				/* restore CR */

#ifdef	_WRS_TLB_MISS_CLASS_SW
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

	lwz	sp, 0(sp)			/* restore the SP(R1) */

						/* turn off the MMU before */
						/* to restore the SRR0/SRR1 */
	mfmsr	p0				/* read msr */
	rlwinm	p0,p0,0,28,25			/* disable Instr/Data trans */
	mtmsr	p0				/* set msr */
	isync					/* synchronization */

	mfspr	p0, SPRG0			/* load SRR0 to p0 */
	mtspr	SRR0, p0			/* restore SRR0 (PC) */

	mfspr	p0, SPRG3			/* load SRR1 to p0 */
	mtspr	SRR1, p0			/* restore SRR1 (MSR) */

	mfspr	p0, SPRG2			/* restore P0 from SPRG2 */
#else	/* !_WRS_TLB_MISS_CLASS_SW */
	/*
	 * both MMU-less and MMU with miss handler in HW use this code
	 */

	lwz	p0, _PPC_ESF_PC(sp)		/* load PC to P0 and */
	mtspr	SRR0, p0			/* restore SRR0 (PC) */

	lwz	p0, _PPC_ESF_MSR(sp)		/* load MSR to P0 and */
	mtspr	SRR1, p0			/* restore SRR1 (MSR) */

	lwz	p0, _PPC_ESF_P0(sp)		/* restore p0 */

	lwz	sp, 0(sp)			/* pop up stack */
#endif	/* _WRS_TLB_MISS_CLASS_SW */

	rfi					/* return to previus context */

/* rescheduling is necessary.  p0 contains taskIdCurrent.
 * interrupts are still locked out */

saveIntContext:
	/*
	 * when we arrive to this point
	 * p0 = taskIdCurrent
	 * p2 = kernelState MSB address
	 * p3 = errno
	 */

	li	p1, 1
        stw     p1, LO(kernelState)(p2)		/* kernelState = TRUE */

	stw	p3, WIND_TCB_ERRNO(p0)		/* save errno */

	lwz	p1, _PPC_ESF_PC(sp)		/* load PC to P1 */
	stw	p1, WIND_TCB_PC(p0)		/* store PC in tcb */

	lwz	p1, _PPC_ESF_MSR(sp)		/* read MSR to P1 */
	stw	p1, WIND_TCB_MSR(p0)		/* store msr in tcb */

	lwz	p1, _PPC_ESF_LR(sp)		/* load LR to P1 */
	stw	p1, WIND_TCB_LR(p0)		/* store LR to tcb */

	stw	r0, WIND_TCB_R0(p0) 		/* store R0 to tcb */

	stw	r2, WIND_TCB_R2(p0) 		/* store R2 to tcb */

	lwz	p1, _PPC_ESF_P0(sp)		/* load saved P0 */
	stw	p1, WIND_TCB_P0(p0) 		/* store P0 in tcb */

	lwz	p1, _PPC_ESF_P1(sp)		/* load saved P1 */
	stw	p1, WIND_TCB_P1(p0) 		/* store P1 to tcb */

	lwz	p1, _PPC_ESF_P2(sp)		/* load saved P2 */
	stw	p1, WIND_TCB_P2(p0) 		/* store P2 to tcb */

	lwz	p1, _PPC_ESF_P3(sp)		/* load saved P3 */
	stw	p1, WIND_TCB_P3(p0) 		/* store P3 to tcb */

	lwz	p1, _PPC_ESF_CR(sp)		/* load saved CR */
	stw	p1, WIND_TCB_CR(p0)		/* store CR to tcb */

	lwz	sp, 0(sp)			/* recover stack */
	stw	sp, WIND_TCB_SP(p0)		/* store SP to tcb */

	mfspr	p1, CTR				/* load CTR to p1 */
	stw	p1, WIND_TCB_CTR(p0)		/* store CTR to tcb */

	mfspr	p1, XER				/* load XER to p6 */
	stw	p1, WIND_TCB_XER(p0)		/* store XER to tcb */

#if	(CPU==PPC601)
	mfspr	p1, MQ				/* load MQ to p7 */
	stw	p1, WIND_TCB_MQ(p0)		/* store MQ to tcb */
#endif	/* (CPU==PPC601) */
#if	(CPU==PPC85XX)
	mfspr	p1, SPEFSCR			/* load SPEFSCR to p1 */
	stw	p1, WIND_TCB_SPEFSCR(p0)	/* store SPEFSCR to tcb */
#endif	/* (CPU==PPC85XX) */

#if 	TRUE
	stw	p4, WIND_TCB_P4(p0) 		/* store P4 to tcb */
	stw	p5, WIND_TCB_P5(p0) 		/* store P5 to tcb */
	stw	p6, WIND_TCB_P6(p0) 		/* store P6 to tcb */
	stw	p7, WIND_TCB_P7(p0) 		/* store P7 to tcb */

	stw	r11, WIND_TCB_R11(p0) 		/* store r11 to tcb */
	stw	r12, WIND_TCB_R12(p0) 		/* store r12 to tcb */
	stw	r13, WIND_TCB_R13(p0) 		/* store r13 to tcb */

	stw	t0, WIND_TCB_T0(p0) 		/* store t0 to tcb */
	stw	t1, WIND_TCB_T1(p0) 		/* store t1 to tcb */
	stw	t2, WIND_TCB_T2(p0) 		/* store t2 to tcb */
	stw	t3, WIND_TCB_T3(p0) 		/* store t3 to tcb */
	stw	t4, WIND_TCB_T4(p0) 		/* store t4 to tcb */
	stw	t5, WIND_TCB_T5(p0) 		/* store t5 to tcb */
	stw	t6, WIND_TCB_T6(p0) 		/* store t6 to tcb */
	stw	t7, WIND_TCB_T7(p0) 		/* store t7 to tcb */
	stw	t8, WIND_TCB_T8(p0) 		/* store t8 to tcb */
	stw	t9, WIND_TCB_T9(p0) 		/* store t9 to tcb */
	stw	t10, WIND_TCB_T10(p0) 		/* store t10 to tcb */
	stw	t11, WIND_TCB_T11(p0) 		/* store t11 to tcb */
	stw	t12, WIND_TCB_T12(p0) 		/* store t12 to tcb */
	stw	t13, WIND_TCB_T13(p0) 		/* store t13 to tcb */
	stw	t14, WIND_TCB_T14(p0) 		/* store t14 to tcb */
	stw	t15, WIND_TCB_T15(p0) 		/* store t15 to tcb */
	stw	t16, WIND_TCB_T16(p0) 		/* store t16 to tcb */
	stw	t17, WIND_TCB_T17(p0) 		/* store t17 to tcb */

#else
	stmw    p4, _PPC_ESF_P2(p0)             /* save general register 7 */
						/* through 31 */
#endif

	/* unlock interrupts and set MSR's FP, RI and CE bits if they exist */

	mfmsr	p2				/* load msr */
#ifdef  _PPC_MSR_RI
# ifdef _PPC_MSR_FP
	ori	p2, p2, _PPC_MSR_RI | _PPC_MSR_EE | _PPC_MSR_FP
# else
	ori	p2, p2, _PPC_MSR_RI | _PPC_MSR_EE
# endif /* _PPC_MSR_FP */
#else   /* _PPC_MSR_RI */
# ifdef _PPC_MSR_FP
	ori	p2, p2, _PPC_MSR_EE | _PPC_MSR_FP
# else
	ori	p2, p2, _PPC_MSR_EE
# endif /* _PPC_MSR_FP */
#endif  /* _PPC_MSR_RI */

#ifdef	_PPC_MSR_CE_U
	oris	p2, p2, _PPC_MSR_CE_U		/* set CE bit (critical intr) */
#endif 	/* _PPC_MSR_CE_U */
	mtmsr	p2				/* UNLOCK INTERRUPT */
	isync

	stwu    sp, -FRAMEBASESZ(sp)		/* carve stack frame */
	b	FUNC(reschedule)		/* goto rescheduler */
FUNC_END(intExit)

/*******************************************************************************
*
* intLock - lock out interrupts
*
* This routine disables interrupts.
*
* IMPORTANT CAVEAT
* The routine intLock() can be called from either interrupt or task level.
* When called from a task context, the interrupt lock level is part of the
* task context.  Locking out interrupts does not prevent rescheduling.
* Thus, if a task locks out interrupts and invokes kernel services that
* cause the task to block (e.g., taskSuspend() or taskDelay()) or causes a
* higher priority task to be ready (e.g., semGive() or taskResume()), then
* rescheduling will occur and interrupts will be unlocked while other tasks
* run.  Rescheduling may be explicitly disabled with taskLock().
*
* EXAMPLE
* .CS
*     lockKey = intLock ();
*
*      ...
*
*     intUnlock (lockKey);
* .CE
*
* RETURNS
* An architecture-dependent lock-out key for the interrupt state
* prior to the call.
*
* SEE ALSO: intUnlock(), taskLock()

* int intLock ()

*/

FUNC_BEGIN(intLock)
	mfmsr	 p0			/* load msr to parm0 */
	INT_MASK(p0, p1)		/* mask EE bit */
	mtmsr	 p1			/* LOCK INTERRUPT */
	isync				/* SYNC XXX TPR not requested */
	blr				/* return to the caller */
FUNC_END(intLock)

/*******************************************************************************
*
* intUnlock - cancel interrupt locks
*
* This routine re-enables interrupts that have been disabled by the routine
* intLock().  Use the architecture-dependent lock-out key obtained from the
* preceding intLock() call.
*
* RETURNS: N/A
*
* SEE ALSO: intLock()

* void intUnlock
*	(
*	int lockKey
*	)

*/

FUNC_BEGIN(intUnlock)
#ifdef	_PPC_MSR_CE_U
	rlwinm	p0,p0,0,14,16		/* select EE and CE bit in lockKey */
	rlwinm	p0,p0,0,16,14
#else	/* _PPC_MSR_CE_U */
	rlwinm	p0,p0,0,16,16		/* select EE bit in lockKey */
#endif 	/* _PPC_MSR_CE_U */
	mfmsr	p1			/* move MSR to parm1 */
	or	p0,p1,p0		/* restore EE bit (and CE for 403) */
	mtmsr	p0			/* UNLOCK INTERRUPRS */
	isync				/* Instruction SYNChronization XXX */
	blr				/* return to the caller */
FUNC_END(intUnlock)


#ifdef	_PPC_MSR_CE_U

/*******************************************************************************
*
* intCrtEnt - catch and dispatch  external critical interrupt
*
* This is the interrupt dispatcher that is pointed by the PowerPC exception.
* It saves the context when interrupt happens and return to the stub.
*
* NOMANUAL

* void intCrtEnt()

*/

FUNC_BEGIN(intCrtEnt)
	/* At the entry of this function, the following is done */
	/* mtspr	SPRG2, p0	/@ save P0 to SPRG2 */
	/* mfspr	p0, LR		/@ load LR to P0 */
	/* bla		intCrtEnt	/@ save vector in LR, jump to handler */

	mtspr	SPRG0, p1		/* save P1 to SPRG0: free p1 up */

	/*
	 * we may have a Critical Exception occuring at the very beginning
	 * of the processing of a normal external interrupt, right before
	 * MSR[CE] bit is cleared in the stub excConnectCode. Therefore
	 * it is necessary to save the value of SPRG3 in this Critical
	 * exception handler before using it and restore it after.
	 */

	mfspr	p1, SPRG3		/* push SPRG3 on the current stack */
	stw	p1, -4(sp)		/* either the interrupt one or the */
					/* interrupted task one */
	mfspr	p1, SPRG2		/* move initial p0 from SPRG2 */
	mtspr	SPRG3, p1		/* to SPRG3 */

	mtspr	SPRG2, p0		/* save LR to SPRG2 */

	mfcr	p1 			/* save CR to P1 before it is changed */

	/*
	 * On the PowerPC 60X, when an external interrupt is taken, the
	 * processor turns the MMU off. At this moment the cache is not
	 * longer controlled by the WIMG bits of the MMU. If the data cache
	 * is on, the value of the SP, CR, PC and MSR register are written in
	 * the cache and not in the memory.
	 * The interrupt handler should be executed with the MMU in the
	 * same state as the none interrupt code. This stub should
	 * re-enable the data or/and instruction MMU if they were enabled
	 * before the interrupt.
	 * By re-enabling the MMU, the cache restarts to be controlled via the
	 * WIMG bits. If the memory pages which handle the interrupt stack are
	 * in not cacheables state, the cache is turn off for all memory acces
	 * in this area.
	 * In intCrtExit() the SP, CR, PC, and MSR register values should be
	 * restored. Because the MMU is on the processor go to read the memory
	 * to get the register values. But the true value is save in the cache.
	 * In this case the restored value is corrupted and can crash VxWorks.
	 * To avoid memory this coherency problem, the data cache should be
	 * locked.
	 */

	/*
	 * The special purpose register SPRG1 contains the real interrupt
	 * nesting count.  It is initialized in wintIntStackSet() in windALib.s.
	 * Because intCnt is faked in windTickAnnounce(), intCnt cannot be
	 * used for checking of nested interrupts to switch stack.
	 */

	mfspr	p0, SPRG1		/* get nested count */
	addi	p0, p0, 1		/* increment nested count */
	mtspr	SPRG1, p0		/* update nested count */

	/*
	 * The PowerPC Familly doesn't support the notion of interrupt
	 * stack. To avoid to add the size of interrupt stack in each task
	 * stack this stub switch from the task stack to the interrupt stack
	 * by changing the value of the SP(R1).
	 * This switch should be performed only if the interrupt is not
	 * a nested interrupt.
	 */

	cmpwi	p0, 1			/* test for nested interrput */
	beq	intCrtStackSwitch	/* no, switch to interrupt stack */

	stwu	sp, -_PPC_ESF_STK_SIZE(sp)	/* we already use int. stack */
	b	intCrtSaveCritical		/* save old stack pointer */

intCrtStackSwitch:
	addi	p0, sp, 0			/* save current SP to P0 */
	lis	sp, HIADJ(vxIntStackBase)	/* load int. stack base addr. */
	lwz	sp, LO(vxIntStackBase)(sp)  	/* in SP */
	stwu	p0,  -_PPC_ESF_STK_SIZE(sp)	/* carve stack */

intCrtSaveCritical:
	stw	p1, _PPC_ESF_CR(sp)		/* save CR */

	mfspr	p0, CRIT_SAVE_PC		/* load P0 with CRIT_SAVE_PC */
	stw	p0, _PPC_ESF_PC(sp)		/* save in ESF */

	mfspr	p1, CRIT_SAVE_MSR		/* load P1 with CRIT_SAVE_MSR */
	stw	p1, _PPC_ESF_MSR(sp)		/* save in ESF */

#if	(CPU == PPC405F)
        /*
         * we need the following fix for certain versions of PPC405F
         */
# ifdef PPC405F_ERRATA_18
        mfspr   p0, LR                          /* save current LR */
	stw	p0, _PPC_ESF_LR(sp)
        bl      fpCrtfix	                /* handle fix */
        lwz	p0, _PPC_ESF_LR(sp)
        mtspr   LR, p0				/* restore current LR */
# endif	/* PPC405F_ERRATA_18 */

#endif	/* (CPU == PPC405F) */

	mfspr	p0, SPRG2			/* load saved LR to P0 */
	stw	p0, _PPC_ESF_LR(sp)		/* save LR */

	mfspr	p0, SPRG3			/* reload saved P0 */
	stw	p0, _PPC_ESF_P0(sp) 		/* save P0 to the stack */

	lwz	p1, 0(sp)			/* load stack were was saved */
	lwz	p1, -4(p1)			/* SPRG3 and restore SPRG3 */
	mtspr	SPRG3, p1			/* prior to the CE exception */

	mfspr	p1, SPRG0			/* reload saved P1 */
	stw	p1, _PPC_ESF_P1(sp) 		/* save P1 to the stack */

        lis     p0, HIADJ(errno)
        lwz     p0, LO(errno)(p0)		/* load ERRNO to P0 and */
	stw	p0, _PPC_ESF_ERRNO(sp)		/* save ERRNO to the stack */

        lis     p1, HIADJ(intCnt)
        lwz     p0, LO(intCnt)(p1)		/* load intCnt value */
        addi    p0, p0, 1			/* increment intCnt value */
        stw     p0, LO(intCnt)(p1)		/* save new intCnt value */

	/*
	 * At this point we should restore the preexisting MMU state, so that
	 * the exception handler can run in the correct memory protection and
	 * caching context. This requires fixing SPR 78819 & 78780.
	 *
	 * SPR 78738 also needs to be taken into account, to flush the items
	 * just written to cache, to maintain coherency between MMU 'on' and
	 * 'off' data.
	 */

	/*
	 * The critical status are saved at this stage. The interrupt should
	 * be enabled as soon as possible to reduce the interrupt latency.
	 * However, there is only one mask bit on PowerPC. It is at the
	 * interrupt controller level to set mask for each individual
	 * interrupt.
	 * Thus, we save task's register first, then call interrupt controller
	 * routine to decide if the interrupt should be re-enabled or not.
	 */

	mfspr	p0, XER				/* load XER to P0 */
	stw	p0, _PPC_ESF_XER(sp)		/* save XER to the stack */

	mfspr	p0, CTR				/* load CTR to P0 */
	stw	p0, _PPC_ESF_CTR(sp)		/* save CTR to the stack */

#if	FALSE
	lwz	p0, 0(sp)
	stw	p0, _PPC_ESF_SP(sp)
#endif	/* FALSE */

	stw	r0, _PPC_ESF_R0(sp)		/* save general register 0 */
	stw	r2, _PPC_ESF_R2(sp)		/* save general register 2 */

	stw	p2, _PPC_ESF_P2(sp) 		/* save general register 5 */
	stw	p3, _PPC_ESF_P3(sp) 		/* save general register 6 */
	stw	p4, _PPC_ESF_P4(sp) 		/* save general register 7 */
	stw	p5, _PPC_ESF_P5(sp) 		/* save general register 8 */
	stw	p6, _PPC_ESF_P6(sp) 		/* save general register 9 */
	stw	p7, _PPC_ESF_P7(sp) 		/* save general register 10 */

	stw	r11, _PPC_ESF_R11(sp)		/* save general register 11 */
	stw	r12, _PPC_ESF_R12(sp)		/* save general register 12 */
	stw	r13, _PPC_ESF_R13(sp)		/* save general register 13 */

	/*
	 * The callee should save the non volatile registers, thus they are
	 * not saved here. An assembly routine should not use these registers
	 * or follow the calling convention by saving them before using.
	 */

        blr					/* return */
FUNC_END(intCrtEnt)


/*******************************************************************************
*
* intCrtExit - exit a critical interrupt service routine
*
* Check the kernel ready queue to determine if rescheduling is necessary.  If
* no higher priority task has been readied, and no kernel work has been queued,
* then we return to the interrupted task.
*
* If rescheduling is necessary, the context of the interrupted task is saved in
* its associated TCB with the PC, MSR in CRIT_SAVE_PC, CRIT_SAVE_MSR.
* This routine must be branched to when exiting an interrupt service routine.
* This normally happens automatically, from the stub built by excIntCrtConnect
* (2).
*
* This routine can NEVER be called from C.
*
* INTERNAL
* This routine must preserve all registers up until the context is saved,
* so any registers that are used to check the queues must first be saved on
* the stack.
*
* At the call to reschedule the value of taskIdCurrent must be in p0.
*
* SEE ALSO: excIntCrtConnect(2)

* void intCrtExit ()

*/

FUNC_BEGIN(intCrtExit)
	mfmsr	p0				/* read msr to p0 */

#ifdef	_PPC_MSR_RI
	RI_MASK (p0, p0)			/* mask RI bit */
#endif	/* _PPC_MSR_RI */

	INT_MASK(p0, p0)			/* clear EE and RI bit */
	mtmsr	p0				/* DISABLE INTERRUPT */
	isync					/* synchronize */

#ifdef  WV_INSTRUMENTATION
        /* windview instrumentation - BEGIN
         * log event if work has been done in the interrupt handler.
         */

        lis     p6, HIADJ(evtAction)            /* is WindView on? */
        lwz     p0, LO(evtAction)(p6)
        cmpwi   p0, 0
        beq     noActionIntCrtExit              /* if not, exit */

        lis     p6, HIADJ(wvEvtClass)           /* is windview on? */
        lwz     p4, LO(wvEvtClass)(p6)
        lis     p1, HI(WV_CLASS_1_ON)
        ori     p1, p1, LO(WV_CLASS_1_ON)
        and     p6, p4, p1
        cmpw    p1, p6
        bne     trgCheckIntCrtExit              /* if not, go to trigger */

        lis     p3, HIADJ(workQIsEmpty)         /* is work queue empty? */
        lwz     p2, LO(workQIsEmpty)(p3)
        cmpwi   p2, 0
        beq     intCrtExitNoK
        li      p0, EVENT_INT_EXIT_K
        b       intCrtExitCont
intCrtExitNoK:
        li      p0, EVENT_INT_EXIT              /* get event id */
intCrtExitCont:
        stwu    sp, -(FRAMEBASESZ+_STACK_ALIGN_SIZE)(sp) /* stack frame * /
        mfspr   p6, LR                          /* read lr to p6 */
        stw     p6, FRAMEBASESZ (sp)            /* save lr */

        lis     p6, HIADJ(_func_evtLogT0)
        lwz     p1, LO(_func_evtLogT0)(p6)
        mtlr    p1
        blrl

        lwz     p6,  FRAMEBASESZ (sp)
        mtspr   LR, p6                          /* restore lr */
        addi    sp, sp, FRAMEBASESZ + _STACK_ALIGN_SIZE /* release stack */
trgCheckIntCrtExit:

        lis     p6, HIADJ(trgEvtClass)          /* are there any triggers? */
        lwz     p4, LO(trgEvtClass)(p6)
        lis     p1, HI(TRG_CLASS_1_ON)
        ori     p1, p1, LO(TRG_CLASS_1_ON)
        and     p4, p4, p1
        cmpw    p1, p4
        bne     noActionIntCrtExit                      /* if none, exit */

        lis     p3, HIADJ(workQIsEmpty)         /* is work queue empty? */
        lwz     p2, LO(workQIsEmpty)(p3)
        cmpwi   p2, 0
        beq     trgIntCrtExitNoK
        li      p0, EVENT_INT_EXIT_K
        b       trgIntCrtExitCont
trgIntCrtExitNoK:
        li      p0, EVENT_INT_EXIT              /* get event id */
trgIntCrtExitCont:

        lis     p6, HIADJ(_func_trgCheck)       /* check if trgCheck func */
        lwz     p1, LO(_func_trgCheck)(p6)      /* exists */
        cmpwi   p1, 0
        beq     noActionIntCrtExit                  /* if none, exit */

        stwu    sp, -(FRAMEBASESZ+ _STACK_ALIGN_SIZE)(sp) /* carve stack frame */
        mfspr   p6, LR                          /* read lr to p6 */
        stw     p6, FRAMEBASESZ (sp)            /* save lr */

        mtlr    p1

        li      p1, 0           /* CLASS1_INDEX */
        li      p2, 0
        li      p3, 0
        li      p4, 0
        li      p5, 0
        li      p6, 0
        li      p7, 0

        blrl                                    /* check for triggers */

        lwz     p6,  FRAMEBASESZ (sp)
        mtspr   LR, p6                          /* restore lr */
        addi    sp, sp, FRAMEBASESZ + _STACK_ALIGN_SIZE /* release stack */

noActionIntCrtExit:
        /* windview instrumentation - END */
#endif /* WV_INSTRUMENTATION */

	lwz	r0, _PPC_ESF_R0(sp)		/* restore general register 0 */
	lwz	r2, _PPC_ESF_R2(sp)		/* restore general register 2 */

	lwz	p4, _PPC_ESF_P4(sp)		/* restore general reg 7 */
	lwz	p5, _PPC_ESF_P5(sp)		/* restore general reg 8 */
	lwz	p6, _PPC_ESF_P6(sp)		/* restore general reg 9 */
	lwz	p7, _PPC_ESF_P7(sp)		/* restore general reg 10 */

	lwz	r11, _PPC_ESF_R11(sp)		/* restore general reg 11 */
	lwz	r12, _PPC_ESF_R12(sp)		/* restore general reg 12 */
	lwz	r13, _PPC_ESF_R13(sp)		/* restore general reg 13 */

	lwz	p0, _PPC_ESF_XER(sp)		/* load the saved XER to P0 */
	mtspr	XER, p0				/* restore XER */

	lwz	p0, _PPC_ESF_CTR(sp)		/* load the saved CTR to P0 */
	mtspr	CTR, p0				/* restore CTR */

	lis	p0, HIADJ(errno)
	lwz	p3, _PPC_ESF_ERRNO(sp)		/* load errno value */
	stw	p3, LO(errno)(p0)		/* restore errno value */

	lwz	p0, _PPC_ESF_LR(sp)		/* load the saved LR to P0 */
	mtspr	LR, p0				/* restore LR */

        lis     p1, HIADJ(intCnt)
        lwz     p2, LO(intCnt)(p1)		/* load intCnt value to P2 */
        addi    p2, p2, -1			/* decrement intCnt value */
        stw     p2, LO(intCnt)(p1)		/* save new intCnt value */

	mfspr	p0, SPRG1			/* load nesting count to P0 */
	addi	p0, p0, -1			/* decrement nesting count */
	mtspr	SPRG1, p0			/* update nesting count */

	/*
	 * we don't rely on the global variable <intCnt> because
	 * windTickAnnounce() modifies it to fake an ISR context.
	 */

	cmpwi	p0, 0				/* SPRG1 says nested int? */
	bne	intCrtRte			/* yes, just return */

	/*
	 * we need to determine if the CE interrupt occured while
	 * the CPU was in the excConnectCode stub before that Critical
	 * Exception was turned off. That is if an external interrupt is
	 * nested with this critical interrupt. If that's the case the
	 * nested int. counter was not incremented for the external
	 * interrupt: so even if SPRG1 is equal to 0 now , this is a nested
	 * interrupt situation and therefore we should return immediately
	 * via intCrtRte.
	 */

	lwz	p0, _PPC_ESF_PC(sp)		/* get PC value before CE int.*/
	rlwinm  p0, p0, 0, 0, 26		/* clear bits 27 to 31 of PC */

	cmpwi	p0, _EXC_OFF_INTR		/* was it an external int. */
	beq	intCrtRte

#ifdef	_EXC_OFF_PIT
	cmpwi	p0, _EXC_OFF_PIT		/* was it a PIT interrupt */
	beq	intCrtRte
#endif	/* _EXC_OFF_PIT */

#ifdef	_EXC_OFF_FIT
	cmpwi	p0, _EXC_OFF_FIT		/* was it a FIT interrupt */
	beq	intCrtRte
#endif	/* _EXC_OFF_FIT */

#ifdef	_EXC_NEW_OFF_PIT
	cmpwi	p0, _EXC_NEW_OFF_PIT		/* was it a PIT interrupt */
	beq	intCrtRte
#endif	/* _EXC_NEW_OFF_PIT */

#ifdef	_EXC_NEW_OFF_FIT
	cmpwi	p0, _EXC_NEW_OFF_FIT		/* was it a FIT interrupt */
	beq	intCrtRte
#endif	/* _EXC_NEW_OFF_FIT */

        lis     p2, HIADJ(kernelState)
        lwz     p0, LO(kernelState)(p2)		/* load kernelState to P0 */

	cmpwi	p0, 0				/* if kernelState == TRUE */
	bne	intCrtRte			/* just clean up and return */

        lis     p0, HIADJ(taskIdCurrent)
        lwz     p0, LO(taskIdCurrent)(p0)	/* load taskIdCurrent to P0 */

        lis     p1, HIADJ(readyQHead)
        lwz     p1, LO(readyQHead)(p1)		/* load readyQHead to P1 */

	cmpw	p0, p1				/* comp to highest ready task */
	beq	intCrtRte			/* return from interrput */

	lwz	p1, WIND_TCB_LOCK_CNT(p0)	/* load p1 with task lock cnt */
	cmpwi	p1, 0 				/* if task preemption allowed */
	beq	saveIntCrtContext		/* then save task context */

	lwz	p1, WIND_TCB_STATUS(p0)		/* set p2 to task's status */
	cmpwi	p1, 0				/* if task ready to run */
	bne	saveIntCrtContext		/* if no, save context */

intCrtRte:
	lwz	p1, _PPC_ESF_P1(sp)		/* restore p1 */
	lwz	p2, _PPC_ESF_P2(sp)		/* restore p2 */
	lwz	p3, _PPC_ESF_P3(sp)		/* restore general reg 6 */

	lwz	p0, _PPC_ESF_CR(sp)
	mtcrf	255,p0				/* restore CR */

	lwz	p0, _PPC_ESF_PC(sp)		/* load PC to P0 and */
	mtspr	CRIT_SAVE_PC, p0		/* restore CRIT_SAVE_PC */

	lwz	p0, _PPC_ESF_MSR(sp)		/* load MSR to P0 and */
	mtspr	CRIT_SAVE_MSR, p0		/* restore CRIT_SAVE_MSR */

	lwz	p0, _PPC_ESF_P0(sp)		/* restore p0 */

	lwz	sp, 0(sp)			/* pop up stack */

	rfci					/* return to previous context */

/* rescheduling is necessary.  p0 contains taskIdCurrent.
 * interrupts are still locked out */

saveIntCrtContext:
	/*
	 * when we arrive to this point
	 * p0 = taskIdCurrent
	 * p2 = kernelState MSB address
	 * p3 = errno
	 */

	li	p1, 1
        stw     p1, LO(kernelState)(p2)		/* kernelState = TRUE */

	stw	p3, WIND_TCB_ERRNO(p0)		/* save errno */

	lwz	p1, _PPC_ESF_PC(sp)		/* load PC to P1 */
	stw	p1, WIND_TCB_PC(p0)		/* store PC in tcb */

	lwz	p1, _PPC_ESF_MSR(sp)		/* read MSR to P1 */
	stw	p1, WIND_TCB_MSR(p0)		/* store msr in tcb */

	lwz	p1, _PPC_ESF_LR(sp)		/* load LR to P1 */
	stw	p1, WIND_TCB_LR(p0)		/* store LR to tcb */

	stw	r0, WIND_TCB_R0(p0) 		/* store R0 to tcb */

	stw	r2, WIND_TCB_R2(p0) 		/* store R2 to tcb */

	lwz	p1, _PPC_ESF_P0(sp)		/* load saved P0 */
	stw	p1, WIND_TCB_P0(p0) 		/* store P0 in tcb */

	lwz	p1, _PPC_ESF_P1(sp)		/* load saved P1 */
	stw	p1, WIND_TCB_P1(p0) 		/* store P1 to tcb */

	lwz	p1, _PPC_ESF_P2(sp)		/* load saved P2 */
	stw	p1, WIND_TCB_P2(p0) 		/* store P2 to tcb */

	lwz	p1, _PPC_ESF_P3(sp)		/* load saved P3 */
	stw	p1, WIND_TCB_P3(p0) 		/* store P3 to tcb */

	lwz	p1, _PPC_ESF_CR(sp)		/* load saved CR */
	stw	p1, WIND_TCB_CR(p0)		/* store CR to tcb */

	lwz	sp, 0(sp)			/* recover stack */
	stw	sp, WIND_TCB_SP(p0)		/* store SP to tcb */

	mfspr	p1, CTR				/* load CTR to p1 */
	stw	p1, WIND_TCB_CTR(p0)		/* store CTR to tcb */

	mfspr	p1, XER				/* load XER to p6 */
	stw	p1, WIND_TCB_XER(p0)		/* store XER to tcb */

# if 	TRUE
	stw	p4, WIND_TCB_P4(p0) 		/* store P4 to tcb */
	stw	p5, WIND_TCB_P5(p0) 		/* store P5 to tcb */
	stw	p6, WIND_TCB_P6(p0) 		/* store P6 to tcb */
	stw	p7, WIND_TCB_P7(p0) 		/* store P7 to tcb */

	stw	r11, WIND_TCB_R11(p0) 		/* store r11 to tcb */
	stw	r12, WIND_TCB_R12(p0) 		/* store r12 to tcb */
	stw	r13, WIND_TCB_R13(p0) 		/* store r13 to tcb */

	stw	t0, WIND_TCB_T0(p0) 		/* store t0 to tcb */
	stw	t1, WIND_TCB_T1(p0) 		/* store t1 to tcb */
	stw	t2, WIND_TCB_T2(p0) 		/* store t2 to tcb */
	stw	t3, WIND_TCB_T3(p0) 		/* store t3 to tcb */
	stw	t4, WIND_TCB_T4(p0) 		/* store t4 to tcb */
	stw	t5, WIND_TCB_T5(p0) 		/* store t5 to tcb */
	stw	t6, WIND_TCB_T6(p0) 		/* store t6 to tcb */
	stw	t7, WIND_TCB_T7(p0) 		/* store t7 to tcb */
	stw	t8, WIND_TCB_T8(p0) 		/* store t8 to tcb */
	stw	t9, WIND_TCB_T9(p0) 		/* store t9 to tcb */
	stw	t10, WIND_TCB_T10(p0) 		/* store t10 to tcb */
	stw	t11, WIND_TCB_T11(p0) 		/* store t11 to tcb */
	stw	t12, WIND_TCB_T12(p0) 		/* store t12 to tcb */
	stw	t13, WIND_TCB_T13(p0) 		/* store t13 to tcb */
	stw	t14, WIND_TCB_T14(p0) 		/* store t14 to tcb */
	stw	t15, WIND_TCB_T15(p0) 		/* store t15 to tcb */
	stw	t16, WIND_TCB_T16(p0) 		/* store t16 to tcb */
	stw	t17, WIND_TCB_T17(p0) 		/* store t17 to tcb */

# else	/* TRUE */
	stmw    p4, _PPC_ESF_P2(p0)             /* save general register 7 */
						/* through 31 */
# endif	/* TRUE */

	mfmsr	p2				/* load msr */
	ori	p2, p2, _PPC_MSR_EE		/* set EE bit */
	oris	p2, p2, _PPC_MSR_CE_U		/* set CE bit (critical intr) */
	mtmsr	p2				/* UNLOCK INTERRUPT */
	isync

	stwu    sp, -FRAMEBASESZ(sp)		/* carve stack frame */
	b	FUNC(reschedule)		/* goto rescheduler */

FUNC_END(intCrtExit)

#endif	/* _PPC_MSR_CE_U */

#if 	(CPU == PPC405F)
/* fpfix.s -- Workaround example for 405GF errata #18

   Assumptions:

   1) The routine was invoked using a brach-and-link instruction

   2) SRR0 has not been modified since entering the interrupt handler.

   3) No attempt was made to read or write any FPRs since entering the interrupt handler.
   Note: This code patch can be executed whether or not the instruction pointed to by SRR0 is a lfd,
   lfdx, lfdu, or lfdux.                                             */

/* PVR versions of 405 which need workaround for lfd instructions */
#define PVR_405GF       0x40310484      /* 405GF */
#define PVR_HIAWATHA    0x40310486      /* Hiawatha */

FUNC_BEGIN(fpfix)
	/* we need to check for two PVR versions of the 405 chip:
         * 0x40310484 and 0x40310486. Only these two versions need this
         * workaround.
         */
          mfpvr   r3                      /* get pvr */
          lis     r4, HI(PVR_405GF)
          ori     r4, r4, LO(PVR_405GF)

          cmpw    r3, r4
          beq     fpfixload	          /* 405GF */

          lis     r4, HI(PVR_HIAWATHA)
          ori     r4, r4, LO(PVR_HIAWATHA)

          cmpw    r3, r4
          beq     fpfixload	          /* HIAWATHA */

          blr			/* nothing to fix */

fpfixload:
	  mfmsr r3          /* get MSR */
          ori r3,r3,0x2000  /* set the FP bit in the MSR */
          mtmsr r3          /* update the MSR */
          isync

          /* initialize base register - method varies by assembler */
          addis r4,r0, HI(fprdata)
          ori   r4,r4, LO(fprdata)

          /* retrieve interrupting instruction */
          mfsrr0 r3         /* get SRR0 */
          lwz r3,0x0(r3)    /* retrieve the instruction */
          extrwi. r3,r3,5,6 /* extract target FPR field from instr */
          beq usefpr1       /* target FPR = 0? */

          /* execute hardware fix */
          stfd f0, 0(r4)    /* save fp reg */
          lfs f0, 0(r4)     /* dummy load to clear hardware */
          lfd f0, 0(r4)     /* restore fp reg */

          b	restoreMsr

usefpr1:  stfd f1, 0(r4)    /* save fp reg */
          lfs f1, 0(r4)     /* dummy load to clear hardware */
          lfd f1, 0(r4)     /* restore fp reg */
          b	restoreMsr

restoreMsr:
	  mfmsr	r3	/* get MSR */
	  addi  r4, r0, 0xdfff	/* r4 = 0xffffdfff */
	  and	r3, r3, r4	/* clear FP bit */
	  mtmsr r3	/* restore old MSR */
	  isync

	  blr		/* return */
FUNC_END(fpfix)

/* same work around as above, but called from a critical interrupt or
 * exception.
 */

FUNC_BEGIN(fpCrtfix)
	/* we need to check for two PVR versions of the 405 chip:
         * 0x40310484 and 0x40310486. Only these two versions need this
         * workaround.
         */
          mfpvr   r3                      /* get pvr */
          lis     r4, HI(PVR_405GF)
          ori     r4, r4, LO(PVR_405GF)

          cmpw    r3, r4
          beq     fpCrtfixload	          /* 405GF */

          lis     r4, HI(PVR_HIAWATHA)
          ori     r4, r4, LO(PVR_HIAWATHA)

          cmpw    r3, r4
          beq     fpCrtfixload	          /* HIAWATHA */

          blr			/* nothing to fix */

fpCrtfixload:
	  mfmsr r3          /* get MSR */
          ori r3,r3,0x2000  /* set the FP bit in the MSR */
          mtmsr r3          /* update the MSR */
          isync

          /* initialize base register - method varies by assembler */
          addis r4,r0, HI(fprdata)
          ori   r4,r4, LO(fprdata)

          /* retrieve interrupting instruction */
          mfspr r3, CRIT_SAVE_PC	/* PC where interrupt occurred */
          lwz r3,0x0(r3)    /* retrieve the instruction */
          extrwi. r3,r3,5,6 /* extract target FPR field from instr */
          beq useCrtfpr1       /* target FPR = 0? */

          /* execute hardware fix */
          stfd f0, 0(r4)    /* save fp reg */
          lfs f0, 0(r4)     /* dummy load to clear hardware */
          lfd f0, 0(r4)     /* restore fp reg */

          b	restoreCrtMsr

useCrtfpr1:  stfd f1, 0(r4)    /* save fp reg */
          lfs f1, 0(r4)     /* dummy load to clear hardware */
          lfd f1, 0(r4)     /* restore fp reg */
          b	restoreCrtMsr

restoreCrtMsr:
	  mfmsr	r3	/* get MSR */
	  addi  r4, r0, 0xdfff	/* r4 = 0xffffdfff */
	  and	r3, r3, r4	/* clear FP bit */
	  mtmsr r3	/* restore old MSR */
	  isync

	  blr		/* return */
FUNC_END(fpCrtfix)

.data
.align 3
fprdata: .double 0            /* save/restore location */

#endif 	/* CPU == PPC405F */
