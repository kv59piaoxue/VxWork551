/* windALib.s - internal VxWorks kernel assembly library */

/* Copyright 1984-1998 Wind River Systems, Inc. */

/*
modification history
--------------------
01r,03oct02,dtr  Adding save/restore of spefscr for 85XX.
01q,13jun02,jtp  disable MMU during context restore for 4XX (SPR #78396)
01p,25sep01,yvp  fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align.
01o,24jul01,r_s  fixed rlwinm instruction that was GNU specific
01o,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01n,apr1599,tpr  fix bug intorduce by (SPR #24759)
01m,25feb99,jgn  fix scheduler bug (SPR #24759)
01l,18aug98,tpr  added PowerPC EC 603 support.
01o,10aug98,pr   replaced evtsched with function pointer _func_evtLogTSched
01n,16apr98,pr   modified evtAction into int32
01m,23jan98,pr   modified WV code accordingly to the changes made in eventP.h.
                 cleanup
01l,13dec97,pr   started changes of WindView code for WV2.0. STILL IN PROGRESS
01k,11jul96,pr   cleanup windview instrumentation 
01j,08jul96,pr   added windview instrumentation - conditionally compiled
01i,17jun96,tpr  added PowerPC 860 support.
01h,14feb96,tpr  split PPC603 and PPC604.
01g,16jan96,tpr  reworked windLoadContext() to remove kernel bug (SPR #5657).
01f,06jan96,tpr  replace %hiadj and %lo by HIADJ and LO.
01e,03feb95,caf  cleanup.
01d,30nov94,caf  added _GREEN_TOOL support, changed to use r5 when saving
		 errno in windLoadContext().
01c,04nov94,yao added to save ctoc register r13.  fixed miss type of mfmsr
		to mtmsr.
01b,29sep94,yao fixed to branch to link register and link in vxTaskEntry.
		changed to restore original msr before saving context
		in windExit.  changed to use constants defined in regsPpc.h
		so that the code is more portable.  changed to use ave 
		registers used above the frame base that the code would be
		independent of tools.
01a,xxxxxx,yao  written
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they are either
specific to this processor, or they have been optimized for performance.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "private/taskLibP.h"
#include "private/workQLibP.h"
#include "private/eventP.h"
#include "esf.h"

	/* globals */

	FUNC_EXPORT(windExit)		/* routine to exit mutual exclusion */
	FUNC_EXPORT(windIntStackSet)	/* interrupt stack set routine */


	/* externals */

	DATA_IMPORT(taskIdCurrent)	/* current task idnetifier */
	DATA_IMPORT(errno)		/* error number */
	DATA_IMPORT(intCnt)		/* interrupt counter */
	DATA_IMPORT(readyQHead)		/* ready queue head */
	DATA_IMPORT(kernelState)	
	DATA_IMPORT(workQIsEmpty)	
	DATA_IMPORT(vxIntStackBase)	

	FUNC_IMPORT(exit)
	FUNC_IMPORT(workQDoWork)

#define PORTABLE

#ifdef PORTABLE

	FUNC_IMPORT(reschedule)	/* optimized reschedule () routine */
	FUNC_EXPORT(windLoadContext)	/* needed by portable reschedule () */

#endif 	/* PORTABLE */

	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* emptyWorkQueue - empty work queue
*
* This routine is called by windExit.  Interrupts must be locked
* when checking work queue.  p0 contains old msr.
*/

emptyWorkQueue:

	/* carve frame base - equavalent to
	 * STACK_ROUND_UP (FRAMEBASESZ+2*_PPC_REG_SIZE)) */ 
	stwu	sp, -(FRAMEBASESZ+_STACK_ALIGN_SIZE)(sp)
	mfspr	p2, LR		    	    	/* read lr to p2 */ 
	stw	p2, FRAMEBASESZ(sp)	    	/* save lr */ 
	stw	p0, FRAMEBASESZ + _PPC_REG_SIZE(sp)	/* save old msr */

checkWorkQToDo:

	/* p2 = workQIsEmpty */

        lis     p2, HIADJ(workQIsEmpty)
        lwz     p2, LO(workQIsEmpty)(p2)

	cmpwi	p2, 0				/* test for work to do */
	bne	noWorkToDo			/* work queue is empty */
	lwz	p0, FRAMEBASESZ + _PPC_REG_SIZE(sp)      /* load old msr */
	mtmsr	p0				/* UNLOCK INTERRUPTS if neccessary */
	isync					/* SYNC */
	bl	FUNC(workQDoWork)		/* empty the work */

	mfmsr	p0				/* load msr */
	INT_MASK(p0, p1)			/* mask ee bit */
	mtmsr	p1				/* LOCK INTERRUPT */
	isync					/* SYNC */
	b	checkWorkQToDo

noWorkToDo:

#ifdef  WV_INSTRUMENTATION
        /* windview instrumentation - BEGIN */
/* FIXME-PR This might be painful. in simsolaris I have solved it with a macro.
	    here it probably makes more sense to do the check and then call 
	    the functions.
	    I think I need to modify also the macro EVT_CTX_DSP in simsolaris
	    For the moment I sort of patched it. It can be improved by 
	    collecting the parameters only once, for instance.
*/

        lis	p6, HIADJ(evtAction)		/* is any action on? */
        lwz	p0, LO(evtAction)(p6) 
	rlwinm  p1, p0, 0, 16, 31
        cmpwi	p1, 0
        beq	noActionInst			/* if not, exit */

        lis	p6, HIADJ(wvEvtClass)		/* is windview on? */
        lwz	p4, LO(wvEvtClass)(p6)
        lis     p1, (WV_ON >> 16)
        ori     p1, p1, WV_CLASS_1
	and	p6, p4, p1
        lis     p1, (WV_ON >> 16)
        ori     p1, p1, WV_CLASS_1
        cmpw	p1, p6
        bne	trgCheckInst			/* if not, check triggers */

        lis	p4, HIADJ(taskIdCurrent)
        lwz	p1, LO(taskIdCurrent)(p4)
        lwz	p2, WIND_TCB_PRIORITY(p1)	/* get task priority */
        lwz	p3, WIND_TCB_PRI_NORMAL(p1)	/* get task normal priority */

        cmplw	p2, p3				/* check for inheritance */
        bge	noInst1Inheritance		/* if not, then save NODISPATCH */

        li	p0, EVENT_WIND_EXIT_NODISPATCH_PI  /* else, save NODISPATCH_PI */
	b 	Inst1Inheritance

noInst1Inheritance:
        li	p0, EVENT_WIND_EXIT_NODISPATCH	/* get event id */

Inst1Inheritance:
        stwu    sp, -(FRAMEBASESZ+_STACK_ALIGN_SIZE)(sp) /* stack frame * /
        mfspr   p6, LR                          /* read lr to p6 */
        stw     p6, FRAMEBASESZ (sp)            /* save lr */

        lis     p6, HIADJ(_func_evtLogTSched)
        lwz     p1, LO(_func_evtLogTSched)(p6)
        mtlr    p1
        blrl

        lwz     p6,  FRAMEBASESZ (sp)
        mtspr   LR, p6                          /* restore lr */
        addi    sp, sp, FRAMEBASESZ + _STACK_ALIGN_SIZE /* release stack */

trgCheckInst:

        lis	p6, HIADJ(trgEvtClass)		/* are there any triggers? */
        lwz	p4, LO(trgEvtClass)(p6)
        lis     p1, (TRG_ON >> 16)
        ori     p1, p1, TRG_CLASS_1
	and	p4, p4, p1
        lis     p1, (TRG_ON >> 16)
        ori     p1, p1, TRG_CLASS_1
        cmpw	p1, p4
        bne	noActionInst			/* if none, exit */

        lis	p4, HIADJ(taskIdCurrent)
        lwz	p1, LO(taskIdCurrent)(p4)
        lwz	p4, WIND_TCB_PRIORITY(p1)	/* get task priority */
        lwz	p5, WIND_TCB_PRI_NORMAL(p1)	/* get task normal priority */

        cmplw	p4, p5				/* check for inheritance */
        bge	trgNoInst1Inheritance		/* if not, then save NODISPATCH */

        li	p0, EVENT_WIND_EXIT_NODISPATCH_PI  /* else, save NODISPATCH_PI */
	b 	trgInst1Inheritance

trgNoInst1Inheritance:
        li	p0, EVENT_WIND_EXIT_NODISPATCH	/* get event id */

trgInst1Inheritance:

        lis     p6, HIADJ(_func_trgCheck)       /* check if trgCheck func */
        lwz     p1, LO(_func_trgCheck)(p6)      /* exists */
        cmpwi   p1, 0
        beq     noActionInst                  /* if none, exit */

        stwu    sp, -(FRAMEBASESZ+ _STACK_ALIGN_SIZE)(sp) /* carve stack frame */
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
noActionInst:
        /* windview instrumentation - END */
#endif

	lwz	p2, FRAMEBASESZ(sp)		/* load saved lr */ 
	/* recover stack - should be 
	 * STACK_ROUND_UP (FRAMEBASESZ+2*_PPC_REG_SIZE)) */ 
	addi	sp, sp, FRAMEBASESZ+_STACK_ALIGN_SIZE	/* recover frame stack */
	mtspr	LR, p2				/* restore lr */ 
	mfmsr	p0				/* return msr */
	blr

/******************************************************************************
*
* windExit - PORTABLE VERSION of task level exit from kernel
*
* This is the way out of kernel mutual exclusion.  If a higher priority task
* than the current task is ready, then we invoke the rescheduler.  We
* also invoke the rescheduler if any interrupts have occured which have added
* work to the windWorkList.  If rescheduling is necessary,
* the context of the calling task is saved with the PC pointing at the
* next instruction after the jsr to this routine.  The sp in the tcb is
* modified to ignore the return address on the stack.  Thus the context saved
* is as if this routine was never called.
*
* NOMANUAL

* void windExit ()

*/ 

FUNC_LABEL(windExit)
	mfspr	p0, SPRG1			/* load areWeNested */
	/* since the cr bits changed here are volatile, we don't need to save */
	cmpwi	p0, 0				/* exiting interrupt code? */
	beq	taskCode			/* exiting task code */

	/* exiting interrupt code */

	mfmsr	p0				/* pass msr in p0 */
	/* carve frame stack - should be 
	 * STACK_ROUND_UP (FRAMEBASESZ+2*_PPC_REG_SIZE)) */ 
	stwu	sp, -(FRAMEBASESZ + _STACK_ALIGN_SIZE)(sp)
	stw	p0, FRAMEBASESZ(sp)		/* save msr on the stack */
	INT_MASK(p0, p1)			/* mask EE bit */
	mtmsr	p1				/* LOCK INTERRUPTS */
	isync					/* SYNC */
	mfspr	p2, LR		    	    	/* read lr to p2 */
	stw	p2, FRAMEBASESZ+_PPC_REG_SIZE(sp)	    	/* save lr */
	bl	emptyWorkQueue			/* empty work queue */
	xor	p0, p0, p0			/* clear return state */

	/* p2 = &kernelState */

        lis     p2, HIADJ(kernelState)
        addi    p2, p2, LO(kernelState)

	stw	p0, 0(p2)			/* release exclusion */
	lwz	p1, FRAMEBASESZ(sp)		/* restore saved msr */
	mtmsr	p1				/* UNLOCK INTERRUPTS */
	isync					/* SYNC */
	lwz	p2, FRAMEBASESZ+_PPC_REG_SIZE(sp)    	/* load saved lr */

	/* recover frame stack - should be
	 * STACK_ROUND_UP (FRAMEBASESZ+2*_PPC_REG_SIZE)) */ 

	addi	sp, sp, FRAMEBASESZ + _STACK_ALIGN_SIZE
	mtspr	LR, p2				/* restore lr */

	blr

	/* exiting task code */
taskCode:
	mfmsr	p0				/* read msr */
	/* carve stack - equavalent to STACK_ROUND_UP (2*_PPC_REG_SIZE) */ 
	stwu	sp, -_STACK_ALIGN_SIZE(sp)	/* carve space */
	stw	p0, 0(sp)			/* save msr on stack */
	INT_MASK(p0, p1)			/* mask ee bit */
	mtmsr	p1				/* LOCK INTERRUPT */
	isync					/* SYNC */

checkTaskSwitch:

	/*
	 * p7 = taskIdCurrent
	 * p1 = readyQHead
	 */

        lis     p7, HIADJ(taskIdCurrent)
        lwz     p7, LO(taskIdCurrent)(p7)
        lis     p1, HIADJ(readyQHead)
        lwz     p1, LO(readyQHead)(p1)

	cmpw	p7, p1				/* if same */
	beq	checkWorkQ

	lwz	p1, WIND_TCB_LOCK_CNT(p7)	/* load task lock counter */
	cmpwi	p1, 0				/* task preemption allowed */
	beq	saveTaskContext			/* yes, save task context */
	lwz	p2, WIND_TCB_STATUS(p7)		/* load task status */
	cmpwi	p2, 0				/* is task ready to run */
	bne	saveTaskContext

checkWorkQ:

	/* p3 = workQIsEmpty */

        lis     p3, HIADJ(workQIsEmpty)
        lwz     p3, LO(workQIsEmpty)(p3)

	cmpwi	p3, 0				/* check work queue */
	bne	workQueueEmpty			/* no work to do */
	 
	lwz	p0, 0(sp)			/* pass original MSR in p0 */

	stwu	sp, -FRAMEBASESZ(sp)	     	/* carve frame base */
	mfspr	p4, LR		    	     	/* read lr to p4 */
	stw	p4, FRAMEBASESZ+_PPC_REG_SIZE(sp) /* save lr */

	bl	emptyWorkQueue			/* empty workQueue */
	addi	sp, sp, FRAMEBASESZ		/* recover frame stack */
	lwz	p4, _PPC_REG_SIZE(sp)		/* load saved lr */
	mtspr	LR, p4				/* restore lr */
	b	checkTaskSwitch			/* go to checkTaskSwitch */

workQueueEmpty:

	/* kernelState = FALSE */

        xor     p0, p0, p0
        lis     p1, HIADJ(kernelState)
        stw     p0, LO(kernelState)(p1)

	lwz	p3, 0(sp)			/* restore msr from stack */
	mtmsr	p3				/* UNLOCK INTERRUPT if neccessary */
	isync					/* SYNC */
	/* recover stack - equavalent to STACK_ROUND_UP (2*_PPC_REG_SIZE) */ 
	addi	sp, sp, _STACK_ALIGN_SIZE	/* recover stack */

	blr

saveTaskContext:

	/* p7 points to taskIdCurrent */
	/* p1 = errno */

        lis     p1, HIADJ(errno)
        lwz     p1, LO(errno)(p1)

	mfspr	p2, LR				/* load LR */
	stw	p1, WIND_TCB_ERRNO(p7)		/* save errno */
	lwz	p3, 0(sp)			/* read saved msr */
	stw	p2, WIND_TCB_PC(p7)		/* save lr to be new pc */
	li	p1, 0				/* move zero p1 */
	/* recover stack - equavalent to 
	 * STACK_ROUND_UP (2*_PPC_REG_SIZE)) */ 
	addi	sp, sp, _STACK_ALIGN_SIZE	/* recover stack */
	stw	p3, WIND_TCB_MSR(p7) 		/* save msr */
	stw	sp, WIND_TCB_SP(p7)		/* save stack pointer */
	stw	p1, WIND_TCB_P0(p7)		/* return zero for windExit */
#if	(CPU==PPC601)
	mfspr	p2, MQ				/* load mq to p2 */
	stw	p2, WIND_TCB_MQ(p7)		/* save mq to p2 */
#endif	/* (CPU==PPC601) */
#if	(CPU==PPC85XX)
	mfspr	p2, SPEFSCR			/* load SPEFSCR to p2 */
	stw	p2, WIND_TCB_SPEFSCR(p7)	/* save SPEFSCR from p2 */
#endif	/* (CPU==PPC85XX) */
	mfcr	p1				/* save cr */  
	stw	p1, WIND_TCB_CR(p7)		/* save cr */
	stw	r2, WIND_TCB_R2(p7)		/* save r2 */
	stw	r13, WIND_TCB_R13(p7)		/* save r13 */
	stw	t0, WIND_TCB_T0(p7)		/* save non-volatile reg */
	stw	t1, WIND_TCB_T1(p7)		/* save non-volatile reg */
	stw	t2, WIND_TCB_T2(p7)		/* save non-volatile reg */
	stw	t3, WIND_TCB_T3(p7)		/* save non-volatile reg */
	stw	t4, WIND_TCB_T4(p7)		/* save non-volatile reg */
	stw	t5, WIND_TCB_T5(p7)		/* save non-volatile reg */
	stw	t6, WIND_TCB_T6(p7)		/* save non-volatile reg */
	stw	t7, WIND_TCB_T7(p7)		/* save non-volatile reg */
	stw	t8, WIND_TCB_T8(p7)		/* save non-volatile reg */
	stw	t9, WIND_TCB_T9(p7)		/* save non-volatile reg */
	stw	t10, WIND_TCB_T10(p7) 		/* save non-volatile reg */
	stw	t11, WIND_TCB_T11(p7) 		/* save non-volatile reg */
	stw	t12, WIND_TCB_T12(p7) 		/* save non-volatile reg */
	stw	t13, WIND_TCB_T13(p7) 		/* save non-volatile reg */
	stw	t14, WIND_TCB_T14(p7) 		/* save non-volatile reg */
	stw	t15, WIND_TCB_T15(p7) 		/* save non-volatile reg */
	stw	t16, WIND_TCB_T16(p7) 		/* save non-volatile reg */
	stw	t17, WIND_TCB_T17(p7) 		/* save non-volatile reg */
	mtmsr	p3				/* restore msr when it's called */
	isync					/* SYNC */

	b	FUNC(reschedule)
/******************************************************************************
*
* windLoadContext - load the register context from the control block
*
* The registers of the current executing task, (the one reschedule chose),
* are restored from the control block.  This means that all registers
* are available for usage since the prior task context was saved
* before reschedule was called. There is no exception stack frame in the
* PowerPC architecture so none is simulated in doing the context switch.
* Previous interrupt state and new context is restored and a jump to PC
* places us in the new context.  Interrupts are locked on entry to this
* routine so moving the old status register to the processor with a mtmsr
* will re-enable interrupts if previously enabled.
*
*
* NOMANUAL

* void windLoadContext ()

*/


FUNC_LABEL(windLoadContext)

	/* r3 = taskIdCurrent */

        lis     r3, HIADJ(taskIdCurrent)
        lwz     r3, LO(taskIdCurrent)(r3)

	lwz	r4, WIND_TCB_ERRNO(r3)		/* read errno */

	/* save errno */

        lis     r5, HIADJ(errno)
        stw     r4, LO(errno)(r5)

	lwz	r0, WIND_TCB_R0(r3)		/* restore r0 */
	lwz	r5, WIND_TCB_R5(r3)		/* restore r5 */
	lwz	r6, WIND_TCB_R6(r3)		/* restore r6 */
	lwz	r4, WIND_TCB_LR(r3)		/* get lr */
	lwz	r7, WIND_TCB_R7(r3)		/* restore r7 */
	mtspr	LR, r4				/* restore lr */
	lwz	r8, WIND_TCB_R8(r3)		/* restore r8 */
	lwz	r4, WIND_TCB_CTR(r3)		/* get counter register */
	lwz	r9, WIND_TCB_R9(r3)		/* restore r9 */
	mtspr	CTR, r4				/* restore counter register */
	lwz	r10, WIND_TCB_R10(r3)		/* restore r10 */
	lwz	r4, WIND_TCB_XER(r3)		/* get xer */
	lwz	r11, WIND_TCB_R11(r3)		/* restore r11 */
	mtspr	XER, r4				/* restore xer */
	lwz	r12, WIND_TCB_R12(r3)		/* restore r12 */
	lwz	r13, WIND_TCB_R13(r3)		/* restore r13 */
	lwz	r14, WIND_TCB_R14(r3)		/* restore r14 */
	lwz	r15, WIND_TCB_R15(r3)		/* restore r15 */
	lwz	r16, WIND_TCB_R16(r3)		/* restore r16 */
	lwz	r17, WIND_TCB_R17(r3)		/* restore r17 */
	lwz	r18, WIND_TCB_R18(r3)		/* restore r18 */
	lwz	r19, WIND_TCB_R19(r3)		/* restore r19 */
	lwz	r20, WIND_TCB_R20(r3)		/* restore r20 */
	lwz	r21, WIND_TCB_R21(r3)		/* restore r21 */
	lwz	r22, WIND_TCB_R22(r3)		/* restore r22 */
	lwz	r23, WIND_TCB_R23(r3)		/* restore r23 */
	lwz	r24, WIND_TCB_R24(r3)		/* restore r24 */
	lwz	r25, WIND_TCB_R25(r3)		/* restore r25 */
	lwz	r26, WIND_TCB_R26(r3)		/* restore r26 */
	lwz	r27, WIND_TCB_R27(r3)		/* restore r27 */
	lwz	r28, WIND_TCB_R28(r3)		/* restore r28 */
	lwz	r29, WIND_TCB_R29(r3)		/* restore r29 */
	lwz	r30, WIND_TCB_R30(r3)		/* restore r30 */
	lwz	r31, WIND_TCB_R31(r3)		/* restore r31 */
#if	(CPU==PPC601)
	lwz	r4, WIND_TCB_MQ(r3)		/* load mq */
	mtspr	MQ, r4				/* restore mq */
#endif	/* (CPU==PPC601) */
#if	(CPU==PPC85XX)
	lwz	r4, WIND_TCB_SPEFSCR(r3)	/* load SPEFSCR */
	mtspr	SPEFSCR, r4			/* restore SPEFSCR */
#endif	/* (CPU==PPC85XX) */

	lwz	r2, WIND_TCB_R2(r3)		/* restore r2 */

	lwz	sp, WIND_TCB_SP(r3)		/* restore sp */

	lwz	r4, WIND_TCB_CR(r3)		/* get cr */
	mtcrf	255, r4				/* restore cr */

	mfmsr	r4				/* read msr */
	INT_MASK(r4,r4)				/* clear EE bit in msr */
	mtmsr	r4 				/* DISABLE INTERRUPT */
	isync

#ifdef	_WRS_TLB_MISS_CLASS_SW
	/*
	 * Turn off MMU to keep SW TLB Miss handler from corrupting
	 * SRR0, SRR1.
	 */

	lwz	r4, WIND_TCB_PC(r3)		/* restore pc */
	mtspr	SPRG0, r4			/* restore pc */

	lwz	r4, WIND_TCB_MSR(r3)		/* restore msr */
	mtspr	SPRG3, r4			/* restore msr */

	lwz	r4, WIND_TCB_R4(r3)		/* restore r4 */

	lwz	r3, WIND_TCB_R3(r3)		/* restore r3 */
	mtspr	SPRG2,r3

						/* turn off the MMU before */
						/* to restore the SRR0/SRR1 */
	mfmsr	r3				/* read msr */
	rlwinm	r3,r3,0,28,25			/* disable Instr/Data trans */
	mtmsr	r3				/* set msr */
	isync					/* synchronization */

	mfspr	r3, SPRG0
	mtspr	SRR0, r3

	mfspr	r3, SPRG3
	mtspr	SRR1, r3

	mfspr	r3, SPRG2

#else  /* !_WRS_TLB_MISS_CLASS_SW */
	/*
	 * both MMU-less and MMU with miss handler in HW use this code
	 */

	lwz	r4, WIND_TCB_PC(r3)
	mtspr	SRR0, r4			/* restore pc */

	lwz	r4, WIND_TCB_MSR(r3)
	mtspr	SRR1, r4			/* restore msr */

	lwz	r4, WIND_TCB_R4(r3)		/* restore r4 */

	lwz	r3, WIND_TCB_R3(r3)		/* restore r3 */

#endif  /* _WRS_TLB_MISS_CLASS_SW */

	rfi					/* restore context */

/*******************************************************************************
*
* windIntStackSet - set the interrput stack pointer
*
* This routine sets the inerrupt stack pointer to the sepecified address.
* Software register 0 is used to point to the stack pointer.  Software
* register 1 is set to the interrupt nesting count.
*
* NOMANUAL

* void windIntStackSet
*     (
*     char * pBotStack	/@ pointer to bottom of interrupt stack @/
*     )

*/

FUNC_LABEL(windIntStackSet)
	mfmsr	p1				/* load msr to p1 */
	INT_MASK(p1, p2)			/* mask EE bit */
	mtmsr	p2				/* LOCK INTERRUPT */
	isync					/* SYNC */
	mtspr	SPRG0, p0			/* set stack */
	li	p2, 0				/* set p2 to 0 */
	mtspr	SPRG1, p2			/* set intCnt to 0 */

        lis     p3, HIADJ(vxIntStackBase)
        stw     p0, LO(vxIntStackBase)(p3)     /* save vxIntStackBase */

	mtmsr	p1				/* UNLOCK INTERRUPT */
	isync					/* SYNC */
	blr
