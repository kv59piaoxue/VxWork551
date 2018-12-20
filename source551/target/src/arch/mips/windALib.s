/* windALib.s - internal VxWorks kernel assembly library */

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
03i,16jan02,agf  SPR 28519: use eret to start a task after context is loaded
                 so ll/sc internal bit gets cleared
03h,01aug01,mem  Diab integration.
03g,16jul01,ros  add CofE comment
03f,12jun01,mem  Update for new coding standard.
03e,13feb01,tlc  Perform HAZARD review.
03d,03jan01,mem  Fix load of SR register from TCB in portable version.
03c,19dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
03b,19jun00,dra  work around 5432 branch bug
03a,11may00,tpw  Make it work for CW4000 again.
02z,10sep99,myz  added CW4000_16 support.
02x,19jan99,dra  addwd CW4000, CW4011, VR4100, VR5000 and VR5400 support.
02w,01apr99,nps  removed inclusion of obsolete evtBufferLib.h
02v,30jul98,am   registers change in trgCheckInst4
02u,08jul98,cjtc bug fix - priority inheritance stipple never appears in
                 WindView log (SPR 21672)
02t,16may98,pr   replaced lhu with lw for evtAction. 
02s,16apr98,pr   added WindView 20 support.
02r,14oct96,kkk  added R4650 support.
02q,30jul96,kkk  did too much in 02p.
02p,30jul96,kkk  fixed windExitInit to unlock int in branch delay correctly.
02o,23jul96,pr   added windview instrumentation.
02n,12oct94,caf  corrected size of .extern readyQHead (now 16, was 4).
02m,19oct93,cd   added R4000 support
02l,29sep92,ajm  made taskSrDefault accessible through the gp, 
		  expanded stacks past minimum allowed.
02k,04jul92,jcf  scalable/ANSI/cleanup effort.
02j,05jun92,ajm  5.0.5 merge, note mod history changes
02i,26may92,rrr  the tree shuffle
02h,28apr92,ajm   now use taskSrDefault for SR instead of macro
02g,05nov91,ajm   now use areWeNested for interrupt nesting, this allows
		   intCnt to be used for watchDogs
02f,29oct91,ajm   fixed switch/swap hook parameters
02e,15oct91,ajm   pulled in optimizations
02d,14oct91,ajm   reordered .set noreorder section for kernelState bug
02c,09oct91,ajm   put save of errno to tcb in saveIntContext
02b,01aug91,ajm   removed assembler .set noreorder macros. They tend to screw 
		   up assembler
02a,18jun91,jcf	  SPECIAL VERSION FOR 5.0.2 RELEASE.  windExitInt empties work q
01b,28may91,ajm   now use esf.h defines for passed stack
01a,26feb91,ajm   written from 68k v5.0 and mips v4.02 source
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
#include "private/eventP.h"
#include "private/taskLibP.h"
#include "private/workQLibP.h"
#include "esf.h"

	.text
	.set	reorder

	.globl	windExit		/* routine to exit mutual exclusion */
	.globl	vxTaskEntry		/* task entry wrapper */
#if FALSE /* no longer required */
	.globl	intEnt			/* interrupt entrance routine */
#endif
	.globl	intExit			/* interrupt exit routine */
	.globl	windIntStackSet		/* interrupt stack set routine */

#ifdef PORTABLE	
	.globl	windLoadContext		/* needed by portable reschedule () */
#else
	.globl	reschedule		/* optimized reschedule () routine */
#endif /* PORTABLE */

	/* external */

	.extern	intCnt			/* interrupt depth */
	.extern	areWeNested		/* nesting boolean */
	.extern	errno			/* unix like errno */
	.extern	workQIsEmpty		/* work to do ? */
	.extern	kernelState		/* in kernel ? */
	.extern	taskIdCurrent		/* running task */
	.extern	readyQHead		/* head of ready Q */
	.extern	kernelIsIdle		/* are we idle ? */
	.extern	taskSrDefault		/* default task status reg. */

#ifdef WV_INSTRUMENTATION

	.extern _func_evtLogTSched	/* timestamp function pointer */
	.extern _func_trgCheck		/* timestamp function pointer */
	.extern _func_evtLogT0		/* timestamp function pointer */
	.extern evtAction	    
	.extern wvEvtClass	    
	.extern trgEvtClass	    

#endif /* WV_INSTRUMENTATION */

#ifndef PORTABLE    /* This !(PORTABLE) section is the optimized windExit () */

/*******************************************************************************
*
* windExitInt - exit kernel routine from interrupt level
*
* windExit branches here if exiting kernel routine from int level
* No rescheduling is necessary because the ISR will exit via intExit, and
* intExit does the necessary rescheduling.
*/

windExitIntWork:
	SETFRAME(windExitIntWork,0)
	subu	sp, FRAMESZ(windExitIntWork)	/* need some stack */
	SW	ra, FRAMERA(windExitIntWork)(sp) /* save ra */
	HAZARD_VR5400
	mtc0    t2, C0_SR        		/* UNLOCK INTS in BD slot */
	jal	workQDoWork			/* empty the work queue */
	LW	ra, FRAMERA(windExitIntWork)(sp) /* restore ra */
	addu	sp, FRAMESZ(windExitIntWork)	/* restore stack */

	.ent 	windExitInt
windExitInt:
	HAZARD_VR5400
	mfc0	t2, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t2
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	lw	t0, workQIsEmpty		/* test for work to do */
	beq	zero, t0, windExitIntWork	/* workQueue is not empty */

#ifdef WV_INSTRUMENTATION

        /*
         * windview instrumentation - BEGIN
         * exit windExit with no dispatch; point 1 in the windExit diagram.
         */
        lw      t0, evtAction                   /* is instrumentation on? */
        beqz    t0, noInst1

        lw      t0, wvEvtClass                   /* is instrumentation on? */
        li      t4, WV_CLASS_1_ON                   /* is instrumentation on? */
	and     t0, t0, t4
        bne     t4, t0, trgCheckInst1

        SETFRAME(windExitInt,1)
        subu    sp, FRAMESZ(windExitInt)        /* need some stack */
        SW      ra, FRAMERA(windExitInt)(sp)    /* save ra */
        SW      t2, FRAMER0(windExitInt)(sp)    /* save old sr */

        lw      a1, taskIdCurrent
        lw      a2, WIND_TCB_PRIORITY(a1)

        /*
         * Determine if the task is running at an inherited priority
         */
        lw      t4, WIND_TCB_PRI_NORMAL(a1)
        li      a0, EVENT_WIND_EXIT_NODISPATCH
        bge     a2, t4, noInst1Inheritance      /* no inheritance */
        li      a0, EVENT_WIND_EXIT_NODISPATCH_PI
noInst1Inheritance:

        lw      t1, _func_evtLogTSched
        jal     t1                              /* call evtsched routine */

        LW      t2, FRAMER0(windExitInt)(sp)    /* restore sr */
        LW      ra, FRAMERA(windExitInt)(sp)    /* restore ra */
        addu    sp, FRAMESZ(windExitInt)        /* restore stack */
trgCheckInst1:

        lw      t0, trgEvtClass                   
        li      t4, TRG_CLASS_1_ON                
	and     t0, t0, t4
        bne     t4, t0, noInst1

        SETFRAME(windExitInt,1)
        subu    sp, FRAMESZ(windExitInt)        /* need some stack */
        SW      ra, FRAMERA(windExitInt)(sp)    /* save ra */
        SW      t2, FRAMER0(windExitInt)(sp)    /* save old sr */

        lw      a3, taskIdCurrent
        lw      s0, WIND_TCB_PRIORITY(a3)

        /*
         * Determine if the task is running at an inherited priority
         */
        lw      t4, WIND_TCB_PRI_NORMAL(a3)
        li      a0, EVENT_WIND_EXIT_NODISPATCH
        bge     s0, t4, trgNoInst1Inheritance   /* no inheritance */
        li      a0, EVENT_WIND_EXIT_NODISPATCH_PI

trgNoInst1Inheritance:

        li      a1, TRG_CLASS1_INDEX
        li      a2, 0x0

        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

        LW      t2, FRAMER0(windExitInt)(sp)    /* restore sr */
        LW      ra, FRAMERA(windExitInt)(sp)    /* restore ra */
        addu    sp, FRAMESZ(windExitInt)        /* restore stack */
noInst1:
        /* windview instrumentation - END */

#endif /* WV_INSTRUMENTATION */

	HAZARD_VR5400
	sw      zero, kernelState 		/* else release exclusion */
	move	v0, zero			/* return OK */
	mtc0    t2, C0_SR        		/* UNLOCK INTERRUPTS */
	j       ra		 		/* back to calling task */
	.end	windExitInt

/*******************************************************************************
*
* checkTaskReady - check that taskIdCurrent is ready to run
*
* This code branched to by windExit when it finds preemption is disabled.
* It is possible that even though preemption is disabled, a context switch
* must occur.  This situation arrises when a task blocks during a preemption
* lock.  So this routine checks if taskIdCurrent is ready to run, if not it
* branches to save the context of taskIdCurrent, otherwise it falls thru to
* check the work queue for any pending work.
*/

checkTaskReady:
	/* taskIdCurrent in t0  */
	lw	t1, WIND_TCB_STATUS(t0)	/* is task ready to run */
	bne	zero,t1,saveTaskContext /* if no, we blocked with preempt off */

	/* FALL THRU TO CHECK WORK QUEUE */

/*******************************************************************************
*
* checkWorkQ -	check the work queue for any work to do
*
* This code is branched to by windExit.  Currently taskIdCurrent is highest
* priority ready task, but before we can return to it we must check the work
* queue.  If there is work we empty it via doWorkPreSave, otherwise we unlock
* interrupts, clear v0, and return to taskIdCurrent.
*/

checkWorkQ:
	HAZARD_VR5400
	mfc0	t2, C0_SR
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t2
	mtc0	t1, C0_SR		/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	lw	t0, workQIsEmpty	/* test for work to do */
	beq	zero, t0, doWorkPreSave	/* workQueue is not empty */

#ifdef WV_INSTRUMENTATION

        /*
         * windview instrumentation - BEGIN
         * exit windExit with no dispatch; point 4 in the windExit diagram.
         */
        lw      t0, evtAction                   /* is instrumentation on? */
        beqz    t0, noInst4

        lw      t0, wvEvtClass                   /* is instrumentation on? */
        li      t4, WV_CLASS_1_ON                   /* is instrumentation on? */
        and     t0, t0, t4
        bne     t4, t0, trgCheckInst4

        SETFRAME(checkWorkQ,1)
        subu    sp, FRAMESZ(checkWorkQ)         /* need some stack */
        SW      ra, FRAMERA(checkWorkQ)(sp)     /* save ra */
        SW      t2, FRAMER0(checkWorkQ)(sp)     /* save old sr */

        lw      a1, taskIdCurrent
        lw      a2, WIND_TCB_PRIORITY(a1)
        /*
         * Determine if the task is running at an inherited priority
         */
        lw      t4, WIND_TCB_PRI_NORMAL(a1)
        li      a0, EVENT_WIND_EXIT_NODISPATCH
        bge     a2, t4, noInst4Inheritance      /* no inheritance */
        li      a0, EVENT_WIND_EXIT_NODISPATCH_PI
noInst4Inheritance:

        lw      t1, _func_evtLogTSched
        jal     t1                              /* call evtsched routine */

restoreInst4:
        LW      t2, FRAMER0(checkWorkQ)(sp)
        LW      ra, FRAMERA(checkWorkQ)(sp)
        addu    sp, FRAMESZ(checkWorkQ)

trgCheckInst4:

        lw      t0, trgEvtClass
        li      t4, TRG_CLASS_1_ON
        and     t0, t0, t4
        bne     t4, t0, noInst4

        SETFRAME(checkWorkQ,1)
        subu    sp, FRAMESZ(checkWorkQ)         /* need some stack */
        SW      ra, FRAMERA(checkWorkQ)(sp)     /* save ra */
        SW      t2, FRAMER0(checkWorkQ)(sp)     /* save old sr */

        lw      a1, taskIdCurrent
        lw      a2, WIND_TCB_PRIORITY(a1)

        /*
         * Determine if the task is running at an inherited priority
         */

        lw      t4, WIND_TCB_PRI_NORMAL(a1)
        li      a0, EVENT_WIND_EXIT_NODISPATCH
        bge     a2, t4, trgNoInst4Inheritance   /* no inheritance */
        li      a0, EVENT_WIND_EXIT_NODISPATCH_PI

trgNoInst4Inheritance:

        li      a1, TRG_CLASS1_INDEX
        li      a2, 0x0

        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

        LW      t2, FRAMER0(checkWorkQ)(sp)
        LW      ra, FRAMERA(checkWorkQ)(sp)
        addu    sp, FRAMESZ(checkWorkQ)

noInst4:
        /* windview instrumentation - END */

#endif /* WV_INSTRUMENTATION */

	sw      zero, kernelState 	/* else release exclusion */
	HAZARD_VR5400
	mtc0    t2, C0_SR        	/* UNLOCK INTERRUPTS */
	move	v0, zero		/* return OK */
	j       ra		 	/* back to calling task */

/*******************************************************************************
*
* doWorkPreSave - empty the work queue with current context not saved
*
* We try to empty the work queue here, rather than let reschedule
* perform the work because there is a strong chance that the
* work we do will not preempt the calling task.  If this is the case, then
* saving the entire context just to restore it in reschedule is a waste of
* time.  Once the work has been emptied, the ready queue must be checked to
* see if reschedule must be called, the check of the ready queue is done by
* branching back up to checkTaskCode.
*/

doWorkPreSave:
	HAZARD_VR5400
	mtc0    t2, C0_SR        	/* UNLOCK INTERRUPTS */
	SETFRAME(doWorkPreSave,0)
	subu	sp, FRAMESZ(doWorkPreSave) /* temp stack */
	SW	ra, FRAMERA(doWorkPreSave)(sp) /* preserve ra */
	jal     workQDoWork		/* empty the work queue */
	LW	ra, FRAMERA(doWorkPreSave)(sp)	/* restore ra */
	addu	sp, FRAMESZ(doWorkPreSave)	/* restore stack */
	b	checkTaskSwitch		/* back up to test if tasks switched */

/******************************************************************************
*
* windExit - task level exit from kernel
*
* Release kernel mutual exclusion (kernelState) and dispatch any new task if
* necessary.  If a higher priority task than the current task has been made
* ready, then we invoke the rescheduler.  Before releasing mutual exclusion,
* the work queue is checked and emptied if necessary.
*
* If rescheduling is necessary, the context of the calling task is saved in its
* associated TCB with the PC pointing at the next instruction after the jsr to
* this routine.  The SP in the tcb is modified to ignore the return address
* on the stack.  Thus the context saved is as if this routine was never called.
*
* Only the volatile registers d0,d1,a0,a1 are safe to use until the context
* is saved in saveTaskContext.
*
* At the call to reschedule the value of taskIdCurrent must be in a0.
*
* RETURNS: OK or
*	   ERROR if semaphore timeout occurs.
*
* NOMANUAL

* STATUS windExit ()

*/  

windExit:
	lw      t0, intCnt		/* if intCnt == 0 we're from task */
	bne     zero, t0, windExitInt	/* else we're exiting interrupt code */

	/* FALL THRU TO CHECK THAT CURRENT TASK IS STILL HIGHEST */

/*******************************************************************************
*
* checkTaskSwitch - check to see if taskIdCurrent is still highest task
*
* We arrive at this code either as the result of falling thru from windExit,
* or if we have finished emptying the work queue.  We compare taskIdCurrent
* with the highest ready task on the ready queue.  If they are same we
* go to a routine to check the work queue.  If they are different and preemption
* is allowed we branch to a routine to make sure that taskIdCurrent is really
* ready (it may have blocked with preemption disabled).  If they are different
* we save the context of taskIdCurrent and fall thru to reschedule.
*/

checkTaskSwitch:
	lw	t0, taskIdCurrent		/* move taskIdCurrent into t0 */
	lw	t1, readyQHead			/* move readyQHead into t1 */
	beq	t0, t1, checkWorkQ		/* if same then time to leave */

	lw	t1, WIND_TCB_LOCK_CNT(t0)	/* is task preemption allowed */
	bne	zero, t1, checkTaskReady	/* if no, check task is ready */

saveTaskContext:
	lw 	t1, errno
	sw	t1, WIND_TCB_ERRNO(t0)		/* save errno */
	sw	ra, WIND_TCB_PC(t0)	   	/* save ra to be new PC 
						   after call to here */
	HAZARD_VR5400
	mfc0	t1, C0_SR			/* read SR */
	SW	sp, WIND_TCB_SP(t0)	   	/* save stack pointer */
	sw      t1, WIND_TCB_SR(t0)     	/* save SR in entirety */
						/* load saved registers */
						/* less volatile t0-t9,a0-a3 */
	SW	zero, WIND_TCB_V0(t0)	   	/* windExit returns OK */
	mflo	t2
	SW	t2, WIND_TCB_LO(t0)
	mfhi	t2
	SW	t2, WIND_TCB_HI(t0)
	SW	s0, WIND_TCB_S0(t0)
	SW	s1, WIND_TCB_S1(t0)
	SW	s2, WIND_TCB_S2(t0)
	SW	s3, WIND_TCB_S3(t0)
	SW	s4, WIND_TCB_S4(t0)
	SW	s5, WIND_TCB_S5(t0)    
	SW	s6, WIND_TCB_S6(t0)
	SW	s7, WIND_TCB_S7(t0)
	SW	s8, WIND_TCB_S8(t0)

	/* FALL THRU TO RESCHEDULE */

/*******************************************************************************
*
* reschedule - rescheduler for VxWorks kernel
*
* This routine is called when either intExit, or windExit, thinks the
* context might change.  All of the contexts of all of the tasks are
* accurately stored in the task control blocks when entering this function.
* The status register has interrupts UNLOCKED upon entry to this routine.
*
* The register t0 must contain the value of taskIdCurrent at the entrance to
* this routine.
*
* At the conclusion of this routine, taskIdCurrent will equal the highest
* priority task eligible to run, and the kernel work queue will be empty.
* If a context switch to a different task is to occur, then the installed
* switch hooks are called.
*
* For non-R3k processors (MIPS 3 ISA & higher) the incoming context is 
* switched to using an 'eret' and the EPC. This is done to ensure the
* internal ll-sc bit is cleared.
*
* NOMANUAL

* void reschedule ()

*/

	.ent	reschedule
reschedule:
	lw	t1, readyQHead			/* get highest task to t1 */
	beq	zero, t1, idle			/* idle if nobody ready */

switchTasks:
	sw	t1, taskIdCurrent		/* update taskIdCurrent */

	/* t1 has highest task*/
	/* t0 has previous task */

	lhu	t2, WIND_TCB_SWAP_IN(t1)	/* swap in hook mask into t1 */
	lhu	t3, WIND_TCB_SWAP_OUT(t0)	/* swap out hook mask into t2 */
	or	t3, t3, t2			/* or in swap out hook mask */
	bne	zero, t3, doSwapHooks		/* any swap hooks to do */
	lw	t2, taskSwitchTable		/* any global switch hooks? */
	bne	zero, t2, doSwitchHooks		/* any switch hooks to do */

dispatch:

	lw	t1, taskIdCurrent		/* can't be sure with hooks */
	lw	t0, WIND_TCB_ERRNO(t1)		/* restore errno */
	sw	t0, errno

#ifndef WV_INSTRUMENTATION

        LW	sp, WIND_TCB_SP(t1)             /* restore task sp */
        LW	a0, WIND_TCB_A0(t1)             /* restore saved registers */
        LW	a1, WIND_TCB_A1(t1)
        LW      a2, WIND_TCB_A2(t1)
        LW      a3, WIND_TCB_A3(t1)
        LW      v0, WIND_TCB_V0(t1)
        LW      v1, WIND_TCB_V1(t1)
        LW      t2, WIND_TCB_LO(t1)             /* use t2 to restore LO & HI */
        mtlo    t2
        LW      t2, WIND_TCB_HI(t1)
        mthi    t2
        LW      t3, WIND_TCB_T3(t1)
        LW      t4, WIND_TCB_T4(t1)
        LW      t5, WIND_TCB_T5(t1)
        LW      t6, WIND_TCB_T6(t1)
        LW      t7, WIND_TCB_T7(t1)
        LW      s0, WIND_TCB_S0(t1)
        LW      s1, WIND_TCB_S1(t1)
        LW      s2, WIND_TCB_S2(t1)
        LW      s3, WIND_TCB_S3(t1)
        LW      s4, WIND_TCB_S4(t1)
        LW      s5, WIND_TCB_S5(t1)
        LW      s6, WIND_TCB_S6(t1)
        LW      s7, WIND_TCB_S7(t1)
        LW      t8, WIND_TCB_T8(t1)
        LW      t9, WIND_TCB_T9(t1)
        LW      s8, WIND_TCB_S8(t1)
        LW      ra, WIND_TCB_RA(t1)             /* restore return addr */

#endif /* !WV_INSTRUMENTATION */

	HAZARD_VR5400
	mfc0	t0, C0_SR 
	li	t2, ~SR_INT_ENABLE
	and	t2, t2, t0
	mtc0	t2, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	lw	k0, workQIsEmpty		/* if work q is not empty */
	lw	k1, WIND_TCB_SR(t1)		/* k1 = current SR */
	beq	zero, k0, doWorkUnlock		/* then do work while */

#ifdef WV_INSTRUMENTATION
	.set	reorder

        /*
         * windview instrumentation - BEGIN
         * exit windExit with dispatch;
         */
	lw      t2, evtAction                   /* is WV/triggering on? */
        beqz    t2, noInst3

        lw      t0, wvEvtClass                  /* is WV instrumentation on? */
        li      t4, WV_CLASS_1_ON               
        and     t0, t0, t4
        bne     t4, t0, trgCheckInst3
        /*
         * generate a frame to allow called functions
         * to save parameters etc, but don't bother saving state
         * because we are just about to do a context switch
         */
        SETFRAME(dispatch,1)
        subu    sp, FRAMESZ(dispatch)
	SW	t1, FRAMER0(dispatch)(sp)
        lw      a1, taskIdCurrent
        lw      a2, WIND_TCB_PRIORITY(a1)
        /*
         * Determine if the task is running at an inherited priority
         */
        lw      t4, WIND_TCB_PRI_NORMAL(a1)
        li      a0, EVENT_WIND_EXIT_DISPATCH
        bge     a2, t4, noInst3Inheritance      /* no inheritance */
        li      a0, EVENT_WIND_EXIT_DISPATCH_PI
noInst3Inheritance:

        lw      t0, _func_evtLogTSched
        jal     t0                              /* call evtsched routine */

inst3BufOvrFlow:
	LW	t1, FRAMER0(dispatch)(sp)
        addu    sp, FRAMESZ(dispatch)
trgCheckInst3:

        lw      t0, trgEvtClass
        li      t4, TRG_CLASS_1_ON
        and     t0, t0, t4
        bne     t4, t0, noInst3

        SETFRAME(dispatch,1)
        subu    sp, FRAMESZ(dispatch)
        SW      t1, FRAMER0(dispatch)(sp)

        lw      a3, taskIdCurrent
        lw      a2, WIND_TCB_PRIORITY(a3)
        /*
         * Determine if the task is running at an inherited priority
         */
        lw      t4, WIND_TCB_PRI_NORMAL(a3)
        li      a0, EVENT_WIND_EXIT_DISPATCH
        bge     a2, t4, trgNoInst3Inheritance   /* no inheritance */
        li      a0, EVENT_WIND_EXIT_DISPATCH_PI
trgNoInst3Inheritance:

	li      a1, TRG_CLASS1_INDEX
	li      a2, 0x0

        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

        LW      t1, FRAMER0(dispatch)(sp)
        addu    sp, FRAMESZ(dispatch)

noInst3:
        /* windview instrumentation - END */
                                                /* load register set */
        LW      sp, WIND_TCB_SP(t1)             /* restore task sp */
        LW      a0, WIND_TCB_A0(t1)             /* restore saved registers */
        LW      a1, WIND_TCB_A1(t1)
        LW      a2, WIND_TCB_A2(t1)
        LW      a3, WIND_TCB_A3(t1)
        LW      v0, WIND_TCB_V0(t1)
        LW      v1, WIND_TCB_V1(t1)
        LW      t2, WIND_TCB_LO(t1)             /* use t2 to restore LO & HI */
        mtlo    t2
        LW      t2, WIND_TCB_HI(t1)
        mthi    t2
        LW      t3, WIND_TCB_T3(t1)
        LW      t4, WIND_TCB_T4(t1)
        LW      t5, WIND_TCB_T5(t1)
        LW      t6, WIND_TCB_T6(t1)
        LW      t7, WIND_TCB_T7(t1)
        LW      s0, WIND_TCB_S0(t1)
        LW      s1, WIND_TCB_S1(t1)
        LW      s2, WIND_TCB_S2(t1)
        LW      s3, WIND_TCB_S3(t1)
        LW      s4, WIND_TCB_S4(t1)
        LW      s5, WIND_TCB_S5(t1)
        LW      s6, WIND_TCB_S6(t1)
        LW      s7, WIND_TCB_S7(t1)
        LW      t8, WIND_TCB_T8(t1)
        LW      t9, WIND_TCB_T9(t1)
        LW      s8, WIND_TCB_S8(t1)
        LW      ra, WIND_TCB_RA(t1)             /* restore return addr */

#endif /* WV_INSTRUMENTATION */
	.set	noreorder

	sw	zero, kernelState		/* release kernel mutex */
	lw	k0, WIND_TCB_PC(t1)		/* k0 =  return address */
	.set	noat
	LW	AT, WIND_TCB_AT(t1)		/* restore assembler temp */
	LW	t2, WIND_TCB_T2(t1)		/* restore temp 2 */
	LW	t0, WIND_TCB_T0(t1)		/* restore temp 0 */
	LW	t1, WIND_TCB_T1(t1)		/* restore temp 1 */

#ifdef _WRS_R3K_EXC_SUPPORT
	j	k0			/* context switch */
	mtc0	k1, C0_SR		/* restore status register */
#else
        mtc0    k0, C0_EPC		/* set EPC with incoming task's PC */
        ori     k1, SR_EXL		/* set EXL to disable int's */
        mtc0    k1, C0_SR		/* restore status register */
        HAZARD_CP_WRITE
        eret				/* context switch */
#endif

	.set	at
	.set	reorder
	.end	reschedule

/*******************************************************************************
*
* idle - spin here until there is more work to do
*
* When the kernel is idle, we spin here continually checking for work to do.
* For the R3k we load the default task SR instead of oring in SR_IEC so that
* we don't get here with anything masked.  We must use our own stack for the 
* idle state because doWork will make subroutine calls that use the stack.  We
* don't want to be on another tasks stack, we can't be on the interrupt
* stack because intCnt == 0, and any interrupt would muck our stack.
*/

	.ent	idle
idle:

#ifdef WV_INSTRUMENTATION
        /*
         * windview instrumentation - BEGIN
         * enter idle state
         *
         */

        lw      t1, evtAction                   /* is instrumentation on? */
        beqz    t1, noInstIdle

	HAZARD_VR5400
        mfc0    t2, C0_SR
        li      t1, ~SR_INT_ENABLE
        and     t1, t1, t2
        mtc0    t1, C0_SR               /* LOCK INTERRUPTS */
	HAZARD_INTERRUPT

        lw      t0, wvEvtClass                   /* is instrumentation on? */
        li      t1, WV_CLASS_1_ON                   /* is instrumentation on? */
        and     t0, t0, t1
        bne     t1, t0, trgCheckIdle

        SETFRAME(idle,0)
        subu    sp,FRAMESZ(idle)

        li      a0, EVENT_WIND_EXIT_IDLE

        lw      t1, _func_evtLogT0
        jal     t1                              /* call evtLogT0 routine */

noInstIdleRestore:
        addu    sp, FRAMESZ(idle)
trgCheckIdle:

        lw      t0, trgEvtClass
        li      t1, TRG_CLASS_1_ON
        and     t0, t0, t1
        bne     t1, t0, noInstIdle

        SETFRAME(idle,0)
        subu    sp,FRAMESZ(idle)

        li      a0, EVENT_WIND_EXIT_IDLE

        li      a1, TRG_CLASS1_INDEX
        li      a2, 0x0

        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

        addu    sp, FRAMESZ(idle)
noInstIdle:
        /* windview instrumentation - END */

#endif /* WV_INSTRUMENTATION */

	lw	t2, taskSrDefault	/* load default SR value */
	li	t0, 1			/* load idle flag to reg */
	HAZARD_VR5400
	mtc0    t2, C0_SR        	/* UNLOCK INTERRUPTS */
	sw	t0, kernelIsIdle	/* set idle flag for spyLib */
idleLoop:
	lw	t1, workQIsEmpty	/* if work queue is still empty */
	bne	zero, t1, idleLoop	/* keep hanging around */
	sw	zero, kernelIsIdle	/* unset idle flag for spyLib */
	j	doWork			/* go do the work */
	.end	idle

/*******************************************************************************
*
* doSwapHooks - execute the tasks' swap hooks
*
* S-regs are used for variables that must be preserved across
* procedure calls.  We need not restore the S-regs because
* kernelState = TRUE, so we will never overwrite them due
* to an interrupt thread, and all registers are now available
* for use at this point (tcb's acurrately saved).
*/

doSwapHooks:
	SETFRAME(doSwapHooks,0)
	subu	sp, FRAMESZ(doSwapHooks) /* make room for 2 params and ra */
	move	s0, t0			/* load pointer to old tcb */
	move	s1, t1			/* load pointer to new tcb */
	la	s2, taskSwapTable	/* get adrs of task switch rtn list */
	move	s3, t3			/* put mask in saved reg */
	li	s4, 0x10000		/* load ending condition into reg */
	j	doSwapShift		/* jump into the loop */

doSwapHook:
	move	a0, s0			/* pass taskIdPrevious */
	move	a1, s1			/* pass taskIdCurrent */
	lw	t1, -4(s2)		/* get task switch rtn into t1 */
	jal	t1			/* call routine */

doSwapShift:
	andi	t2, s3, 0x8000		/* mask bit set ? */
	sll	s3, 1			/* shift swapMask bit pattern left */
	addi	s2, 4			/* increment taskSwapTable */
	bne	zero, t2, doSwapHook	/* yes, call SwapHook */
	blt	s3, s4, doSwapShift	/* if mask > 0x8000 all done */
	addi	sp, FRAMESZ(doSwapHooks) /* clean up stack */

	move	t1, s1			/* restore t1 with taskIdCurrent */
	lw	t0, taskSwitchTable	/* any global switch hooks? */
	beq	zero, t0, dispatch	/* if no then dispatch taskIdCurrent */
	j	doSwitchFromSwap	/* do switch routines from swap */

/*******************************************************************************
*
* doSwitchHooks - execute the global switch hooks
*/

doSwitchHooks:
	move	s0, t0			/* load pointer to old tcb */
	move	s1, t1			/* load pointer to new tcb */

doSwitchFromSwap:
	SETFRAME(doSwitchHooks,0)
	subu	sp, FRAMESZ(doSwitchHooks) /* make room for 2 params and ra */
	la	s2, taskSwitchTable	/* get adrs of task switch rtn list */
	lw	t1, 0(s2)		/* get task switch rtn into t1 */

doSwitchHook:
	move	a0, s0			/* pass taskIdPrevious */
	move	a1, s1			/* pass taskIdCurrent */
	jal	t1			/* call routine */
	addu	s2, 4			/* bump to next task switch routine */
	lw	t1, 0(s2)		/* get next task switch rtn */
	bne	zero, t1, doSwitchHook	/* loop */
	move	t1, s1			/* restore t1 with taskIdCurrent */
	addu	sp, FRAMESZ(doSwitchHooks) /* clean up stack */
	j	dispatch		/* dispatch task */

/*******************************************************************************
*
* doWork - empty the work queue
* doWorkUnlock - unlock interrupts and empty the work queue
*
* For doWorkUnlock, t0 must contain the value of the R3k SR before
* interrupts were locked.  We do not need to preserve the ra on a
* stack in these cases because state has been fully preserved at 
* this point.
*
*/

doWorkUnlock:
	HAZARD_VR5400
	mtc0	t0, C0_SR		/* UNLOCK interrupts */
doWork:
	jal	workQDoWork		/* empty the work queue */
	lw	t0, taskIdCurrent	/* put taskIdCurrent into t0 */
	lw	t1, readyQHead		/* get highest task to t1 */
	beq	zero, t1, idle		/* nobody is ready so spin */
	beq	t0, t1, dispatch	/* if the same dispatch */
	j	switchTasks		/* not same, do switch */

#else /* PORTABLE	portable version of windExit() and windLoadContext() */

/*******************************************************************************
*
* windExitInt - exit kernel routine from interrupt level
*
* windExit branches here if exiting kernel routine from int level
* No rescheduling is necessary because the ISR will exit via intExit, and
* intExit does the necessary rescheduling.
*/

windExitIntWork:
	SETFRAME(windExitIntWork,0)
	subu	sp, FRAMESZ(windExitIntWork)	 /* need some stack */
	SW	ra, FRAMERA(windExitIntWork)(sp) /* save ra */
	mtc0    t2, C0_SR        		 /* UNLOCK INTS */
	jal	workQDoWork			 /* empty the work queue */

	LW	ra, FRAMERA(windExitIntWork)(sp) /* restore ra */
	addu	sp, FRAMESZ(windExitIntWork)	 /* restore stack */

	.ent 	windExitInt
windExitInt:
	mfc0	t2, C0_SR
	HAZARD_CP_READ
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t2
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT

	lw	t0, workQIsEmpty		/* test for work to do */
	beq	zero, t0, windExitIntWork	/* workQueue is not empty */
	move	v0, zero			/* return OK */
	sw      zero, kernelState 		/* else release exclusion */
	mtc0    t2, C0_SR        		/* UNLOCK INTERRUPTS */
	j       ra		 		/* back to calling task */
	.end	windExitInt

/******************************************************************************
*
* windExit - PORTABLE VERSION of task level exit from kernel
*
* This is the way out of kernel mutual exclusion.  If a higher priority task
* than the current task is ready, then we invoke the rescheduler.  We
* also invoke the rescheduler if any interrupts have occured which have added
* work to the windWorkList.  If rescheduling is necessary,
* the context of the calling task is saved with the PC pointing at the
* next instruction after the jsr to this routine.  The SP in the tcb is
* modified to ignore the return address on the stack.  Thus the context saved
* is as if this routine was never called.
*
* NOMANUAL

* void windExit ()

*/  

	.ent	windExit
windExit:
	lw      t0,intCnt			/* (intCnt == 0) == task code */
	bne     zero, t0, windExitInt		/* exiting interrupt code? */
taskCode:
	lw	t0, taskIdCurrent		/* move taskIdCurrent into t0 */
	lw	t1, readyQHead			/* compare highest ready task */
	beq	t0, t1, checkWorkQ		/* if same then check workQ */
	lw	t2, WIND_TCB_LOCK_CNT(t0)	/* allowed to switch tasks? */
	beq	zero, t2, saveTaskContext	/* if yes, save task context */
	lw	t2, WIND_TCB_STATUS(t0)		/* is task ready to run? */
	bne	zero, t2, saveTaskContext	/* we blocked while taskLocked*/
checkWorkQ:
	mfc0	t2, C0_SR
	HAZARD_CP_READ
	li	t1, ~SR_INT_ENABLE
	and	t1, t1, t2
	mtc0	t1, C0_SR			/* LOCK INTERRUPTS */
	HAZARD_INTERRUPT
	
	lw	k0, workQIsEmpty		/* test for work to do */
	beq	zero, k0, saveTaskContextUL	/* workQueue is not empty */
	sw	zero, kernelState		/* else release exclusion */
	mtc0    t2, C0_SR        		/* UNLOCK INTERRUPTS */
	move	v0, zero			/* return OK */
	j	ra				/* back to calling task */

saveTaskContextUL:
	mtc0    t2, C0_SR        		/* UNLOCK INTERRUPTS */
saveTaskContext:
	lw 	t1, errno
	HAZARD_VR5400

	mfc0	t2, C0_SR			/* make sure we have sr */
	HAZARD_CP_READ
	sw	t1, WIND_TCB_ERRNO(t0)		/* save errno */
	SW	sp, WIND_TCB_SP(t0)	   	/* save stack pointer */
	sw	ra, WIND_TCB_PC(t0)	   	/* save ra to be new PC 
						   after call to here */
	sw      t2, WIND_TCB_SR(t0)     	/* save SR in entirety */
						/* load saved registers */
						/* less volatile t0-t9 */
	SW	zero, WIND_TCB_V0(t0)	   	/* windExit() returns OK */
	mflo	t1
	SW	t1, WIND_TCB_LO(t0)
	mfhi	t2
	SW	t2, WIND_TCB_HI(t0)
0:
	SW	s0, WIND_TCB_S0(t0)
	SW	s1, WIND_TCB_S1(t0)
	SW	s2, WIND_TCB_S2(t0)
	SW	s3, WIND_TCB_S3(t0)
	SW	s4, WIND_TCB_S4(t0)
	SW	s5, WIND_TCB_S5(t0)    
	SW	s6, WIND_TCB_S6(t0)
	SW	s7, WIND_TCB_S7(t0)
	SW	s8, WIND_TCB_S8(t0)
	j	reschedule			/* goto rescheduler */
	.end	windExit

/*******************************************************************************
*
* windLoadContext - load the register context from the control block
*
* The registers of the current executing task, (the one reschedule chose),
* are restored from the control block.  This means that all registers 
* are available for usage since the prior task context was saved
* before reschedule was called. There is no exception stack frame in the 
* MIPS architecture so none is simulated in doing the context switch.
* Previous interrupt state and new context is restored. For R3k processors
* a jump to PC places us in the new context. For all other ISA's, switching to
* the new context is accomplished via an 'eret' and the EPC. 
*
* Interrupts are locked on entry to this routine so moving the old status 
* register to the processor with a mtc0 will re-enable interrupts if previously 
* enabled. This is not an issue for non-R3k processors because the EXL bit is 
* being set in anticipation of the 'eret'. Interrupts are disabled by virtue of
* it being set.
*
* K1 and K0 are available for kernel use but ONLY in non-interruptible sections.
*
* NOMANUAL

* void windLoadContext ()

*/

	.ent	windLoadContext
windLoadContext:
	lw      t0, taskIdCurrent   		/* current tid */
	lw	t1, WIND_TCB_ERRNO(t0)		/* read errno */
	LW	a0, WIND_TCB_A0(t0) 		/* restore saved registers */
	LW	a1, WIND_TCB_A1(t0)
	LW	a2, WIND_TCB_A2(t0)
	LW	a3, WIND_TCB_A3(t0)
	sw	t1, errno			/* save errno */
	LW	v0, WIND_TCB_V0(t0)
	LW	v1, WIND_TCB_V1(t0)
	LW	t1, WIND_TCB_T1(t0)
	LW	t2, WIND_TCB_T2(t0)
	LW	t3, WIND_TCB_LO(t0)
	LW	t4, WIND_TCB_HI(t0)
	mtlo	t3
	mthi	t4
0:
	LW	t3, WIND_TCB_T3(t0)
	LW	t4, WIND_TCB_T4(t0)
	LW	t5, WIND_TCB_T5(t0)
	LW	t6, WIND_TCB_T6(t0)
	LW	t7, WIND_TCB_T7(t0)
	LW	s0, WIND_TCB_S0(t0)
	LW	s1, WIND_TCB_S1(t0)
	LW	s2, WIND_TCB_S2(t0)
	LW	s3, WIND_TCB_S3(t0)
	LW	s4, WIND_TCB_S4(t0)
	LW	s5, WIND_TCB_S5(t0)
	LW	s6, WIND_TCB_S6(t0)
	LW	s7, WIND_TCB_S7(t0)
	LW	t8, WIND_TCB_T8(t0)
	LW	t9, WIND_TCB_T9(t0)
	LW      s8, WIND_TCB_S8(t0)
	LW	ra, WIND_TCB_RA(t0)		/* restore return addr */
	lw	k1, WIND_TCB_SR(t0)		/* load status register */
	lw	k0, WIND_TCB_PC(t0)		/* restore PC */
	LW	sp, WIND_TCB_SP(t0)		/* restore task stack pointer */
	.set	noat
	LW	AT, WIND_TCB_AT(t0)  
	LW	t0, WIND_TCB_T0(t0)
	.set	noreorder

#ifdef _WRS_R3K_EXC_SUPPORT
	j	k0				/* context switch */
	mtc0	k1, C0_SR			/* restore status register */
#else
	mtc0	k0, C0_EPC
	ori	k1, SR_EXL
	mtc0	k1, C0_SR
	HAZARD_CP_WRITE
	eret
#endif
	.set	reorder
	.set	at
	.end 	windLoadContext 

#endif /* PORTABLE */

/*******************************************************************************
*
* intEnt - enter an interrupt service routine
*
* This routine has been inlined in the common interrupt stub for
* performance reasons on the R3k.
*
* INTERNAL
* On the R3K only three instructions are
* needed therefore this routine is never called.
* Also intCnt is used to discover if interrupts are nested.
* .CS
*
*    lw      k1, intCnt   /* grab contents of intCnt
*    ...
*    addu    k1, 1        /* increment intCnt
*    sw      k1, intCnt   /* update value
* .CE
*
* SEE ALSO: excIntStub()
*/

    /* xxx */

/*******************************************************************************
*
* intExit - exit an interrupt service routine
*
* Check the kernel ready queue to determine if resheduling is necessary.  If
* no higher priority task has been readied, and no kernel work has been queued,
* then we return to the interrupted task.
*
* If rescheduling is necessary, the context of the interrupted task is saved
* in its associated TCB with the PC, SR and SP retrieved from the exception
* frame on the master stack.
*
* This routine must be branched to when exiting an interrupt service routine.
* This normally happens automatically, from the stub built by intConnect (2).
*
* This routine can NEVER be called from C.
*
* It can only be jumped to because a jsr will push a return address on the
* stack.
*
* INTERNAL
* This routine must preserve all registers up until the context is saved,
* so any registers that are used to check the queues must first be saved on
* the stack.
*
* At the call to reschedule the value of taskIdCurrent must be in t0.
*
* Restoration of errno has been moved into the common interrupt stub
* for performance reasons on the R3k.
*
* SEE ALSO: intConnect(2)

* void intExit ()

*/

	.ent	intExit
intExit:
					/* we are on the interrupt stack here */
	SETFRAME(intExit,3)
	subu 	sp, FRAMESZ(intExit)	/* get some work space */
	SW	t0, FRAMER0(intExit)(sp) /* store registers which are used */
	SW	t1, FRAMER1(intExit)(sp)
	SW	t2, FRAMER2(intExit)(sp)

#ifdef WV_INSTRUMENTATION

        /*
         * windview instrumentation - BEGIN
         * log event if work has been done in the interrupt handler.
         */
        lw      t0, evtAction                   /* is WV/triggering on? */
        beqz    t0, noIntExit

        lw      t0, wvEvtClass                   /* is WV instrumentation on? */
        li      t4, WV_CLASS_1_ON                   
        and     t0, t0, t4
        bne     t4, t0, trgCheckIntExit

        /*
         * don't bother to save registers - they are all in
         * the exception frame
         */
        lw      t2, workQIsEmpty                /* work in work queue? */
        li      a0, EVENT_INT_EXIT              /* event id */
        bnez    t2, intExitEvent
        li      a0, EVENT_INT_EXIT_K            /* event id */
intExitEvent:

        lw      t1, _func_evtLogT0
        jal     t1                              /* call evtLogT0 routine */

trgCheckIntExit:

        lw      t0, trgEvtClass
        li      t4, TRG_CLASS_1_ON
        and     t0, t0, t4
        bne     t4, t0, intExitBufOverflow

        lw      t2, workQIsEmpty                /* work in work queue? */
        li      a0, EVENT_INT_EXIT              /* event id */
        bnez    t2, trgIntExitEvent
        li      a0, EVENT_INT_EXIT_K            /* event id */

trgIntExitEvent:

	li      a1, TRG_CLASS1_INDEX
	li      a2, 0x0

        lw      t1, _func_trgCheck
        jal     t1                              /* call trgCheck routine */

intExitBufOverflow:
        /* restore all registers */
        LW      t0,FRAMESZ(intExit)+E_STK_HI(sp) /* grab entry lo reg    */
        LW      t1,FRAMESZ(intExit)+E_STK_LO(sp) /* grab entry hi reg    */
        mthi    t0                               /* restore entry hi reg */
        mtlo    t1                               /* restore entry hi reg */
0:
        LW      v0,FRAMESZ(intExit)+E_STK_V0(sp) /* restore func ret 0   */
        LW      v1,FRAMESZ(intExit)+E_STK_V1(sp) /* restore func ret 1   */
        LW      a0,FRAMESZ(intExit)+E_STK_A0(sp) /* restore passed param 0 */
        LW      a1,FRAMESZ(intExit)+E_STK_A1(sp) /* restore passed param 1 */
        LW      a2,FRAMESZ(intExit)+E_STK_A2(sp) /* restore passed param 2 */
        LW      a3,FRAMESZ(intExit)+E_STK_A3(sp) /* restore passed param 3 */
                                                 /* restore temp reg 0 (below) */
                                                 /* restore temp reg 1 (below) */
                                                 /* restore temp reg 2 (below) */
        LW      t3,FRAMESZ(intExit)+E_STK_T3(sp) /* restore temp reg 3            */
        LW      t4,FRAMESZ(intExit)+E_STK_T4(sp) /* restore temp reg 4 */
        LW      t5,FRAMESZ(intExit)+E_STK_T5(sp) /* restore temp reg 5 */
        LW      t6,FRAMESZ(intExit)+E_STK_T6(sp) /* restore temp reg 6 */
        LW      t7,FRAMESZ(intExit)+E_STK_T7(sp) /* restore temp reg 7 */
        LW      t8,FRAMESZ(intExit)+E_STK_T8(sp) /* restore temp reg 8 */
        LW      ra,FRAMESZ(intExit)+E_STK_RA(sp) /* restore return addr */
        LW      t9,FRAMESZ(intExit)+E_STK_T9(sp) /* restore temp reg 9 */

noIntExit:
        /* windview instrumentation - END */

#endif /* WV_INSTRUMENTATION */

	lw	t0, intCnt	
	subu	t0, 1
	sw	t0, intCnt		/* decrement intCnt */
	lw	t1, areWeNested		/* load nested boolean */
	subu	t1, 1			/* decrement */
	sw	t1, areWeNested		/* store nested boolean */
	lw      t2, kernelState 	/* if kernelState == TRUE */
	bne	t2, zero, intRte	/* then just clean up and rte */ 
	bne     t1, zero, intRte	/* if nested int then just rte */

	lw	t0, taskIdCurrent	/* put current task in t0 */
	lw	t2, readyQHead 	 	/* compare to highest ready task */
	beq	t0, t2, intRte       	/* if same then don't reschedule */

	lw	t1, WIND_TCB_LOCK_CNT(t0)	/* is task preemption allowed */
	beq	zero, t1, saveIntContext	/* if yes, then save context */
	lw	t1, WIND_TCB_STATUS(t0)		/* is task ready to run */
	bne	zero, t1, saveIntContext	/* if no, then save context */
intRte:
	LW	t0, FRAMER0(intExit)(sp)	/* restore registers used locally */
	LW	t1, FRAMER1(intExit)(sp)
	LW	t2, FRAMER2(intExit)(sp)
	addu	sp, FRAMESZ(intExit)		/* recover stack work space */
	.set 	noreorder
	.set	noat
	lw	k0, E_STK_EPC(sp)	/* get the exception program counter */
	LW	AT, E_STK_AT(sp)	/* restore AT reg		*/
	LW	sp, E_STK_SP(sp)	/* restore the task stack pointer,
				   	   no need to pop temp stack now */
#ifdef _WRS_R3K_EXC_SUPPORT
	j	k0			/* return to previous context */
	rfe				/* RESTORE INTERRUPTS */
#else
	HAZARD_VR5400
	mtc0	k0,C0_EPC		/* return to previous context */
	HAZARD_ERET
	eret				/* RESTORE INTERRUPTS */
#endif
	.set	at
	.set 	reorder

/* We are here if we have decided that rescheduling is a distinct possibility.
 * The context must be gathered and stored in the current task's tcb.
 * The stored stack pointers must be modified to clean up the stacks (ISP, MSP).
 */  

saveIntContext:
	/* interrupts are still locked out */
	li	t1, 1 				/* kernelState = TRUE; */
	sw	t1, kernelState 		
	lw	k0, taskIdCurrent		/* tcb to be fixed up */
	lw	t0, errno
	sw	t0, WIND_TCB_ERRNO(k0)		/* save errno */
	LW	t0, FRAMER0(intExit)(sp)	/* restore working registers */
	LW	t1, FRAMER1(intExit)(sp)			
	LW	t2, FRAMER2(intExit)(sp)
	SW 	t0, WIND_TCB_T0(k0)		/* and save in TCB */
	SW	t1, WIND_TCB_T1(k0)			
	SW	t2, WIND_TCB_T2(k0)			
	move	t0, k0				/* use t0 as taskIdCurrent */
	addu	sp, FRAMESZ(intExit)		/* recover stack work space */
	lw	t2, E_STK_EPC(sp)		/* get the exception PC */
	LW	t1, E_STK_SP(sp)		/* get the process SP */
	sw	t2, WIND_TCB_PC(t0)		/* store exception PC in TCB */
	SW	t1, WIND_TCB_SP(t0)		/* store regs in tcb */
	.set	noat
	LW	AT, E_STK_AT(sp)
	SW	AT, WIND_TCB_AT(t0) 
	.set	at
	mfc0	k1, C0_SR
	HAZARD_CP_READ
#ifdef _WRS_R3K_EXC_SUPPORT
	/* modify the status register ready to store in the task TCB */
	and 	k0, k1, SR_KUMSK
	and	k1, ~SR_KUMSK
	srl	k0, 2
	or	k1, k0
#else
	and	k1,~SR_EXL
#endif
	sw	k1, WIND_TCB_SR(t0)		/* store sr in TCB */
	move	sp, t1				/* work off task stack */
	mtc0	k1, C0_SR			/* UNLOCK INTERRUPTS */


/*
*	A window of vulnerabilty opens up here on the R3000.  We need to
* 	have epc,sp,and AT restored and have begun working off the task stack 
*	by now.  This is because intCnt == 0, and if we get interrupted
*	excIntStub will reset and muck the stack.
*/
						/* store registers starting */
	SW	t3, WIND_TCB_T3(t0)             /*    with remaining  temp  */
	SW	t4, WIND_TCB_T4(t0)		/*    registers so work     */
	SW	t5, WIND_TCB_T5(t0)		/*    are available         */
	SW	t6, WIND_TCB_T6(t0)
	SW	t7, WIND_TCB_T7(t0)
	SW	a0, WIND_TCB_A0(t0)		/* save remaining registers  */
	SW	a1, WIND_TCB_A1(t0)		/*    in TCB                 */
	SW	a2, WIND_TCB_A2(t0)
	SW	a3, WIND_TCB_A3(t0)
	SW	v0, WIND_TCB_V0(t0)
	SW	v1, WIND_TCB_V1(t0)
	mflo	v0
	mfhi	v1
	SW	v0, WIND_TCB_LO(t0)
	SW	v1, WIND_TCB_HI(t0)
0:
	SW	s0, WIND_TCB_S0(t0)
	SW	s1, WIND_TCB_S1(t0)
	SW	s2, WIND_TCB_S2(t0)
	SW	s3, WIND_TCB_S3(t0)
	SW	s4, WIND_TCB_S4(t0)
	SW	s5, WIND_TCB_S5(t0)
	SW	s6, WIND_TCB_S6(t0)
	SW	s7, WIND_TCB_S7(t0)
	SW	t8, WIND_TCB_T8(t0)
	SW	t9, WIND_TCB_T9(t0)
	SW      s8, WIND_TCB_S8(t0)
	SW	ra, WIND_TCB_RA(t0)		
	j	reschedule			/* goto rescheduler */
	.end 	intExit

/*******************************************************************************
*
* vxTaskEntry - task startup code following spawn
*
* This hunk of code is the initial entry point to every task created via
* the "spawn" routines.  taskCreate(2) has put the true entry point of the
* task into the tcb extension before creating the task,
* and then pushed exactly ten arguments (although the task may use
* fewer) onto the stack.  This code picks up the real entry point and calls it.
* Upon return, the 10 task args are popped, and the result of the main
* routine is passed to "exit" which terminates the task.
* This way of doing things has several purposes.  First a task is easily
* "restartable" via the routine taskRestart(2) since the real
* entry point is available in the tcb extension.  Second, the call to the main
* routine is a normal call including the usual stack clean-up afterwards,
* which means that debugging stack trace facilities will handle the call of
* the main routine properly.  
*
* NOMANUAL

* void vxTaskEntry () 

*/

	.ent	vxTaskEntry
vxTaskEntry:
   	/* stack frame for 10 parameters created in taskLib */
	lw      t0, taskIdCurrent  /* get current task id */
	lw      t1, WIND_TCB_ENTRY(t0)	/* entry point for task is in tcb */
	jal     t1 		   /* call main routine */
	move    a0, v0 		   /* pass result to exit */
	jal     exit		   /* gone for good */
	.end vxTaskEntry

/*******************************************************************************
*
* windIntStackSet - set the interrupt stack pointer
*
* This routine sets the interrupt stack pointer to the specified address.
* It is only valid on architectures with an interrupt stack pointer.
*
* NOMANUAL

* void windIntStackSet (pBotStack)
*     char *pBotStack;	/* pointer to bottom of interrupt stack *

*/  

	.ent windIntStackSet
windIntStackSet:
	j	ra 		/* just return */
	.end windIntStackSet
