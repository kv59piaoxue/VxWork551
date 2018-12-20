/* windALib.s - internal VxWorks kernel assembly library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01h,09may03,dee  fix SPR 85913
01g,26nov02,dee  fix SPR# 85105
01f,01mar02,tcr  fix interrupt instrumentation (SPR 73858)
01e,26nov01,dee  remove references to _DIAB_TOOL
01d,09nov00,dh   WV support
01c,07jul00,dh   Adding MAC support
01b,14jun00,dh   Mods to compile for Coldfire.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they are either
specific to this processor, or they have been optimized for performance.

WARNING
The assembler instructions to move to and from the MAC registers are
coded as .word values rather than correct mnemonics. This is because the
file must be compiled with the -m5200 switch, and with this switch the
assembler doesn;t recognise these instructions. However, we must have them
in order to support all the 52xx and 53xx families in one library archive.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "private/eventP.h"
#include "private/taskLibP.h"
#include "private/semLibP.h"
#include "private/workQLibP.h"

	.globl	_windExit		/* routine to exit mutual exclusion */
	.globl	_vxTaskEntry		/* task entry wrapper */
	.globl	_intEnt			/* interrupt entrance routine */
	.globl	_intExit		/* interrupt exit routine */
	.globl	_windIntStackSet	/* interrupt stack set routine */
	.globl	_intEntTrap		/* interrupt handler trap */
	.globl	__coldfireHasMac	/* MAC support needed */

#ifdef PORTABLE
	.globl	_windLoadContext	/* needed by portable reschedule () */
#else
	.globl	_reschedule		/* optimized reschedule () routine */
#endif	/* PORTABLE */

	.data
	.even

__coldfireHasMac:
	.long	0			/* defaults to no mac support */

	.text
	.even

/*******************************************************************************
*
* windExitInt - exit kernel routine from interrupt level
*
* windExit branches here if exiting kernel routine from int level
* No rescheduling is necessary because the ISR will exit via intExit, and
* intExit does the necessary rescheduling.  Before leaving kernel state
* the work queue is emptied.
*/

windExitIntWork:
	movew	d0,sr				/* UNLOCK INTERRUPTS */
	jsr	_workQDoWork			/* empty the work queue */

windExitInt:
	movew   sr,d0
	movew	_intLockIntSR,d1		/* LOCK INTERRUPTS */
	movew	d1,sr
	tstl	_workQIsEmpty			/* test for work to do */
	jeq 	windExitIntWork			/* workQueue is not empty */

#ifdef WV_INSTRUMENTATION	/* wv0: windExit (interrupt) */

	/* Is instrumentation on?
	*/
	tstl	_evtAction
        jeq     wv0_skip

	/* Save registers.
	*/
	subl	#24,a7
	moveml  d0-d3/a0-a1,a7@	

        /* Do we need to log this event?
	*/
        movel   _wvEvtClass,d2
        andl    #WV_CLASS_1_ON,d2
        cmpl    #WV_CLASS_1_ON,d2
        jne     wv0_chkTrig
 
        movel   _taskIdCurrent, a0		/* current task */
        movel   a0@(WIND_TCB_PRIORITY),d3	/* ...and priority  */

        /* Is the task running with an inherited priority? If so,
	 * a different event is logged.
	*/
        movel   #EVENT_WIND_EXIT_NODISPATCH,d1
        cmpl    a0@(WIND_TCB_PRI_NORMAL), d3
        jge     wv0_log
        movel   #EVENT_WIND_EXIT_NODISPATCH_PI, d1

wv0_log:
        /* Now log the event.
	*/
        movel   d3,a7@-
        movel   #0,a7@-
        movel   d1,a7@-
        movel   __func_evtLogTSched,a1
        jsr     a1@
        addl    #12,a7

wv0_chkTrig:
        /* Do we need to evaluate triggers for this event?
	*/
        movel   _trgEvtClass,d2
        andl    #TRG_CLASS_1_ON,d2
        cmpl    #TRG_CLASS_1_ON,d2
        jne     wv0_restore

        movel   _taskIdCurrent, a0		/* current task */
        movel   a0@(WIND_TCB_PRIORITY),d3	/* ...and priority  */

        /* Is the task running with an inherited priority? If so,
	 * a different event is logged.
	*/
        movel   #EVENT_WIND_EXIT_NODISPATCH,d1
        cmpl    a0@(WIND_TCB_PRI_NORMAL),d3
        jge     wv0_trigger
        movel   #EVENT_WIND_EXIT_NODISPATCH_PI, d1

wv0_trigger:
        /* Evaluate triggers.
	*/
        clrl    a7@-				/* param 8 - unused */
        clrl    a7@-				/* param 7 - unused */
        clrl    a7@-				/* param 6 - unused */
        movel   d3,a7@-				/* param 5 - priority */
        movel   a0,a7@-				/* param 4 - task id */
        clrl    a7@-				/* param 3 - unused */
        movel   #TRG_CLASS1_INDEX,a7@-		/* param 2 - class index */
        movel   d1,a7@-				/* param 1 - event id */
        movel   __func_trgCheck,a0
        jsr     a0@
        addl    #32,a7				/* Pop params */

wv0_restore:
	moveml  a7@,d0-d3/a0-a1			/* restore regs */
	addl	#24,a7
wv0_skip:

#endif	/* WV_INSTRUMENTATION wv0 */

	clrl	_kernelState			/* else release exclusion */
	movew	d0,sr				/* UNLOCK INTERRUPTS */
	clrl	d0				/* return OK */
	rts					/* back to calling task */

/*******************************************************************************
*
* checkTaskReady - check that taskIdCurrent is ready to run
*
* This code branched to by windExit when it finds preemption is disabled.
* It is possible that even though preemption is disabled, a context switch
* must occur.  This situation arrises when a task block during a preemption
* lock.  So this routine checks if taskIdCurrent is ready to run, if not it
* branches to save the context of taskIdCurrent, otherwise it falls thru to
* check the work queue for any pending work.
*/

checkTaskReady:
	tstl	a0@(WIND_TCB_STATUS)	/* is task ready to run */
	jne 	saveTaskContext		/* if no, we blocked with preempt off */

	/* FALL THRU TO CHECK WORK QUEUE */

/*******************************************************************************
*
* checkWorkQ -	check the work queue for any work to do
*
* This code is branched to by windExit.  Currently taskIdCurrent is highest
* priority ready task, but before we can return to it we must check the work
* queue.  If there is work we empty it via doWorkPreSave, otherwise we unlock
* interrupts, clear d0, and return to taskIdCurrent.
*/

checkWorkQ:
	movew	_intLockTaskSR,d1		/* LOCK INTERRUPTS */
	movew	d1,sr
	tstl	_workQIsEmpty			/* test for work to do */
	jeq 	doWorkPreSave			/* workQueue is not empty */

#ifdef WV_INSTRUMENTATION	/* wv1: windExit (task, no dispatch) */

	/* Is instrumentation on?
	*/
	tstl	_evtAction
        jeq     wv1_skip

	/* Save registers.
	*/
	subl	#24,a7
	moveml  d0-d3/a0-a1,a7@	

        /* Do we need to log this event?
	*/
        movel   _wvEvtClass,d2
        andl    #WV_CLASS_1_ON,d2
        cmpl    #WV_CLASS_1_ON,d2
        jne     wv1_chkTrig
 
        movel   _taskIdCurrent, a0		/* current task */
        movel   a0@(WIND_TCB_PRIORITY),d3	/* ...and priority  */

        /* Is the task running with an inherited priority? If so,
	 * a different event is logged.
	*/
        movel   #EVENT_WIND_EXIT_NODISPATCH,d1
        cmpl    a0@(WIND_TCB_PRI_NORMAL), d3
        jge     wv1_log
        movel   #EVENT_WIND_EXIT_NODISPATCH_PI, d1

wv1_log:
        /* Now log the event.
	*/
        movel   d3,a7@-
        movel   a0,a7@-
        movel   d1,a7@-
        movel   __func_evtLogTSched,a1
        jsr     a1@
        addl    #12,a7

wv1_chkTrig:
        /* Do we need to evaluate triggers for this event?
	*/
        movel   _trgEvtClass,d2
        andl    #TRG_CLASS_1_ON,d2
        cmpl    #TRG_CLASS_1_ON,d2
        jne     wv1_restore

        movel   _taskIdCurrent, a0		/* current task */
        movel   a0@(WIND_TCB_PRIORITY),d3	/* ...and priority  */

        /* Is the task running with an inherited priority? If so,
	 * a different event is logged.
	*/
        movel   #EVENT_WIND_EXIT_NODISPATCH,d1
        cmpl    a0@(WIND_TCB_PRI_NORMAL),d3
        jge     wv1_trigger
        movel   #EVENT_WIND_EXIT_NODISPATCH_PI, d1

wv1_trigger:
        /* Evaluate triggers.
	*/
        clrl    a7@-				/* param 8 - unused */
        clrl    a7@-				/* param 7 - unused */
        clrl    a7@-				/* param 6 - unused */
        movel   d3,a7@-				/* param 5 - priority */
        movel   a0,a7@-				/* param 4 - task id */
        clrl    a7@-				/* param 3 - unused */
        movel   #TRG_CLASS1_INDEX,a7@-		/* param 2 - class index */
        movel   d1,a7@-				/* param 1 - event id */
        movel   __func_trgCheck,a0
        jsr     a0@
        addl    #32,a7				/* Pop params */

wv1_restore:
	moveml  a7@,d0-d3/a0-a1			/* restore regs */
	addl	#24,a7
wv1_skip:

#endif	/* WV_INSTRUMENTATION wv1 */

	clrl	_kernelState			/* else release exclusion */
	movew	#0x3000,sr			/* UNLOCK INTERRUPTS */
	clrl	d0				/* return OK */
	rts					/* back to calling task */

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
	movew	#0x3000,sr			/* UNLOCK INTERRUPTS */
	jsr	_workQDoWork			/* empty the work queue */
	jra 	checkTaskSwitch			/* back up to test if tasks */


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
* this routine.  The SSP in the tcb is modified to ignore the return address
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
	
_windExit:
	tstl	_intCnt			/* if intCnt == 0 we're from task */
	jne 	windExitInt		/* else we're exiting interrupt code */

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
	movel	_taskIdCurrent,a0		/* move taskIdCurrent into a0 */
	cmpl	_readyQHead,a0			/* compare highest ready task */
	jeq 	checkWorkQ			/* if same then time to leave */

	tstl	a0@(WIND_TCB_LOCK_CNT)		/* is task preemption allowed */
	jne 	checkTaskReady			/* if no, check task is ready */

saveTaskContext:
	movel	a7@,a0@(WIND_TCB_PC)		/* save return address as PC */
	movew	sr,d0
	movew	d0,a0@(WIND_TCB_SR)		/* save current SR in TCB */

	moveml	d2-d7,a0@(WIND_TCB_DREGS8)	/* d2-d7; d0,d1 are volatile */
	moveml	a2-a7,a0@(WIND_TCB_AREGS8)	/* a2-a7; a0,a1 are volatile */
	clrl	a0@(WIND_TCB_DREGS)		/* clear saved d0 for return */

	tstl	__coldfireHasMac
	jeq 	saveTaskCtxtMacEnd		/* jump if no MAC */

saveTaskCtxtMac:
	.word	0xa180				/* movel acc,d0 */
	movel	d0,a0@(WIND_TCB_MAC)		/* save MAC */
	.word	0xa980				/* movel macsr,d0 */
	movew	d0,a0@(WIND_TCB_MACSR)		/* save MACSR */
	.word	0xad80				/* movel mask,d0 */
	movew	d0,a0@(WIND_TCB_MASK)		/* save MASK */

saveTaskCtxtMacEnd:

	addql	#4,a0@(WIND_TCB_SSP)		/* fix up SP for no ret adrs */

	movel	_errno,d0			/* save errno */
	movel	d0,a0@(WIND_TCB_ERRNO)		/* save errno */

#ifdef PORTABLE
	jsr	_reschedule			/* goto rescheduler */
#else
	/* FALL THRU TO RESCHEDULE */

/*******************************************************************************
*
* reschedule - rescheduler for VxWorks kernel
*
* This routine is called when either intExit, or windExit, thinks the
* context might change.  All of the contexts of all of the tasks are
* accurately stored in the task control blocks when entering this function.
* The status register is 0x3000. (Supervisor, Master Stack, Interrupts UNLOCKED)
*
* The register a0 must contain the value of _taskIdCurrent at the entrance to
* this routine.
*
* At the conclusion of this routine, taskIdCurrent will equal the highest
* priority task eligible to run, and the kernel work queue will be empty.
* If a context switch to a different task is to occur, then the installed
* switch hooks are called.
*
* NOMANUAL

* void reschedule ()

*/

_reschedule:
	movel	_readyQHead,d0			/* get highest task to d0 */
	jeq 	idle				/* idle if nobody ready */

switchTasks:
	movel	d0,_taskIdCurrent		/* update taskIdCurrent */
	movel	a0,a1				/* a1 gets previous task */
	movel	d0,a0				/* a0 gets highest task*/

	movew	a0@(WIND_TCB_SWAP_IN),d3	/* swap hook mask into d3 */
	movew	a1@(WIND_TCB_SWAP_OUT),d0	/* get swap out hook mask */
	orl	d0,d3				/* or masks together */
	andl	#0xffff,d3			/* clear out upper bits */
	jne 	doSwapHooks			/* any swap hooks to do */
	tstl	_taskSwitchTable		/* any global switch hooks? */
	jne 	doSwitchHooks			/* any switch hooks to do */

dispatch:
	movel	a0@(WIND_TCB_ERRNO),d0		/* restore errno */
	movel	d0,_errno
	movel	a0@(WIND_TCB_SSP),a7		/* push dummy except */

	movew	_intLockIntSR,d1		/* LOCK INTERRUPTS */
	movew	d1,sr

	tstl	__coldfireHasMac
	jeq 	dispatchNoMac			/* jump if no MAC */

	movel	a0@(WIND_TCB_MAC),d0		/* restore MAC */
	.word	0xa100				/* movel d0,acc */
	movew	a0@(WIND_TCB_MACSR),d0		/* restore MACSR */
	.word	0xa900				/* movel d0,macsr */
	movew	a0@(WIND_TCB_MASK),d0		/* restore MASK */
	.word	0xad00				/* movel d0,mask */

dispatchNoMac:

	moveml	a0@(WIND_TCB_REGS),d0-d7/a0-a6	/* load register set */
	
	tstl	_workQIsEmpty			/* if work q is not empty */
	jeq 	doWorkUnlock			/* then unlock and do work */

#ifdef WV_INSTRUMENTATION	/* wv2: reschedule (work queue empty) */

	/* Is instrumentation on?
	*/
	tstl	_evtAction
        jeq     wv2_skip

	/* Save registers.
	*/
	subl	#24,a7
	moveml  d0-d3/a0-a1,a7@	

        /* Do we need to log this event?
	*/
        movel   _wvEvtClass,d2
        andl    #WV_CLASS_1_ON,d2
        cmpl    #WV_CLASS_1_ON,d2
        jne     wv2_chkTrig
 
        movel   _taskIdCurrent, a0		/* current task */
        movel   a0@(WIND_TCB_PRIORITY),d3	/* ...and priority  */

        /* Is the task running with an inherited priority? If so,
	 * a different event is logged.
	*/
        movel   #EVENT_WIND_EXIT_DISPATCH,d1
        cmpl    a0@(WIND_TCB_PRI_NORMAL), d3
        jge     wv2_log
        movel   #EVENT_WIND_EXIT_DISPATCH_PI, d1

wv2_log:
        /* Now log the event.
	*/
        movel   d3,a7@-
        movel   a0,a7@-
        movel   d1,a7@-
        movel   __func_evtLogTSched,a1
        jsr     a1@
        addl    #12,a7

wv2_chkTrig:
        /* Do we need to evaluate triggers for this event?
	*/
        movel   _trgEvtClass,d2
        andl    #TRG_CLASS_1_ON,d2
        cmpl    #TRG_CLASS_1_ON,d2
        jne     wv2_restore

        movel   _taskIdCurrent,a0		/* current task */
        movel   a0@(WIND_TCB_PRIORITY),d3	/* ...and priority  */

        /* Is the task running with an inherited priority? If so,
	 * a different event is logged.
	*/
        movel   #EVENT_WIND_EXIT_DISPATCH,d1	/* event ID is now in d1 */
        cmpl    a0@(WIND_TCB_PRI_NORMAL),d3
        jge     wv2_trigger
        movel   #EVENT_WIND_EXIT_DISPATCH_PI, d1

wv2_trigger:
        /* Evaluate triggers.
	*/
        clrl    a7@-				/* param 8 - unused */
        clrl    a7@-				/* param 7 - unused */
        clrl    a7@-				/* param 6 - unused */
        movel   d3,a7@-				/* param 5 - priority */
        movel   a0,a7@-				/* param 4 - task id */
        clrl    a7@-				/* param 3 - unused */
        movel   #TRG_CLASS1_INDEX,a7@-		/* param 2 - class index */
        movel   d1,a7@-				/* param 1 - event id */
        movel   __func_trgCheck,a0
        jsr     a0@
        addl    #32,a7				/* Pop params */

wv2_restore:
	moveml  a7@,d0-d3/a0-a1			/* restore regs */
	addl	#24,a7
wv2_skip:

#endif	/* WV_INSTRUMENTATION wv2 */

/*
 * At this point we are dispatching to the current
 * task.  The last thing to do is build the exception frame and
 * we need to restore proper format and PC.  Format
 * and PC are stored in the TCB, so we need to get taskIdCurrent again.  All
 * the registers have already been restored so we need to
 * get a working register by saving to stack.
 */
        lea     -16(a7),a7                      /* create stack frame + 8 for reg */
        movel   a0,a7@                          /* save a0 at top of stack */
        movel   d0,a7@(4)                       /* save d0 at top of stack */
        movel   _taskIdCurrent,a0               /* get current task control block */
        movel   a0@(WIND_TCB_HASMAC),a7@(8)     /* onto stack */
        movel   a0@(WIND_TCB_PC),a7@(12)        /* push new pc and proc status */
        movel   #0x40003000,d0                  /* TCB value set back to default */
        movel   d0,a0@(WIND_TCB_HASMAC)         /* TCB value set back to default */
                                                /* if an exception occurs, HASMAC will */
                                                /* have the proper value from instr above */
        movel   a7@+,a0                         /* restore a0 */
        movel   a7@+,d0                         /* restore d0 */
        clrl    _kernelState                    /* release kernel mutex */
        rte                                     /* UNLOCK INTERRUPTS */

/*******************************************************************************
*
* idle - spin here until there is more work to do
*
* When the kernel is idle, we spin here continually checking for work to do.
*/

idle:

#ifdef WV_INSTRUMENTATION	/* wv3: idle loop entry */

	/* Is instrumentation on?
	*/
	tstl	_evtAction
        jeq     wv3_skip

	/* Save registers.
	*/
	subl	#24,a7
	moveml  d0-d3/a0-a1,a7@	

        /* Do we need to log this event?
	*/
        movel   _wvEvtClass,d2
        andl    #WV_CLASS_1_ON,d2
        cmpl    #WV_CLASS_1_ON,d2
        jne     wv3_chkTrig
 
        /* Now log the event. Interrupts need to be disabled.
	*/

      	movew   sr,d2
        movel   d2,a7@-
        movew	_intLockIntSR,d2		/* LOCK INTERRUPTS */
	movew	d2,sr

        movel   #EVENT_WIND_EXIT_IDLE,a7@-
        movel   __func_evtLogT0_noInt,a1
        jsr     a1@
        addl    #4,a7           /* correct stack */
        
        movel   a7@+,d2         /* get SR back */
        move    d2,sr
        
wv3_chkTrig:
        /* Do we need to evaluate triggers for this event?
	*/
        movel   _trgEvtClass,d2
        andl    #TRG_CLASS_1_ON,d2
        cmpl    #TRG_CLASS_1_ON,d2
        jne     wv3_restore

wv3_trigger:
        /* Evaluate triggers.
	*/
        clrl    a7@-				/* param 8 - unused */
        clrl    a7@-				/* param 7 - unused */
        clrl    a7@-				/* param 6 - unused */
        clrl	a7@-				/* param 5 - unused */
        clrl	a7@-				/* param 4 - unused */
        clrl    a7@-				/* param 3 - unused */
        movel   #TRG_CLASS1_INDEX,a7@-		/* param 2 - class index */
        movel   #EVENT_WIND_EXIT_IDLE,a7@-	/* param 1 - event id */
        movel   __func_trgCheck,a0
        jsr     a0@
        addl    #32,a7				/* Pop params */

wv3_restore:
	moveml  a7@,d0-d3/a0-a1			/* restore regs */
	addl	#24,a7
wv3_skip:

#endif	/* WV_INSTRUMENTATION wv3 */

	movew	#0x3000,sr			/* UNLOCK INTERRUPTS (in case)*/

	movel	#1,d0				/* set idle flag for spyLib */
	movel	d0,_kernelIsIdle
idleLoop:
	jsr	idlejsr
	tstl	_workQIsEmpty			/* if work queue is empty */
	jne 	idleLoop			/* keep hanging around */
	clrl	_kernelIsIdle			/* unset idle flag for spyLib */
	jra 	doWork				/* go do the work */
/*
 * this looks funny, but is necessary to allow the visionTrace
 * to work with the ColdFire processor.
 */
idlejsr:
	nop
	nop
	rts

/*******************************************************************************
*
* doSwapHooks - execute the tasks' swap hooks
*/

doSwapHooks:
	pea	a0@			/* push pointer to new tcb */
	pea	a1@			/* push pointer to old tcb */
	lea	_taskSwapTable,a5	/* get adrs of task switch rtn list */
	moveq	#-4,d2			/* start index at -1, heh heh */
	jra 	doSwapShift		/* jump into the loop */

doSwapHook:
	movel	a5@(0,d2:l),a1		/* get task switch rtn into a1 */
	jsr	a1@			/* call routine */

doSwapShift:
	addql	#4,d2			/* bump swap table index */
	lsll	#1,d3			/* shift swapMask bit pattern left */
	btstl	#16,d3			/* check if bit shifted out of lsw */
	jne 	doSwapHook		/* if bit set then do ix hook */
	tstw	d3			/* check if lower 16 bits are zero */
	jne 	doSwapShift		/* any bits still set */
					/* no need to clean stack */
	movel	_taskIdCurrent,a0	/* restore a0 with taskIdCurrent */
	tstl	_taskSwitchTable	/* any global switch hooks? */
	jeq 	dispatch		/* if no then dispatch taskIdCurrent */
	jra 	doSwitchFromSwap	/* do switch routines from swap */

/*******************************************************************************
*
* doSwitchHooks - execute the global switch hooks
*/

doSwitchHooks:
	pea	a0@			/* push pointer to new tcb */
	pea	a1@			/* push pointer to old tcb */

doSwitchFromSwap:
	lea	_taskSwitchTable,a5	/* get adrs of task switch rtn list */
	movel	a5@,a1			/* get task switch rtn into a1 */

doSwitchHook:
	jsr	a1@			/* call routine */
	addql	#4,a5			/* bump to next task switch routine */
	movel	a5@,a1			/* get next task switch rtn */
	cmpl	#0,a1			/* check for end of table (NULL) */
	jne 	doSwitchHook		/* loop */
					/* no need to clean stack */
	movel	_taskIdCurrent,a0	/* restore a0 with taskIdCurrent */
	jra	dispatch		/* dispatch task */

/*******************************************************************************
*
* doWork - empty the work queue
* doWorkUnlock - unlock interrupts and empty the work queue
*/

doWorkUnlock:
	movew	#0x3000,sr		/* UNLOCK INTERRUPTS */
doWork:
	jsr	_workQDoWork		/* empty the work queue */
	movel	_taskIdCurrent,a0	/* put taskIdCurrent into a0 */
	movel	_readyQHead,d0		/* get highest task to d0 */
	jeq	idle			/* nobody is ready so spin */
	cmpl	a0,d0			/* compare to last task */
	jeq	dispatch		/* if the same dispatch */
	jra	switchTasks		/* not same, do switch */

#endif	/* !PORTABLE */

#ifdef PORTABLE

/*******************************************************************************
*
* windLoadContext - load the register context from the control block
*
* The registers of the current executing task, (the one reschedule chose),
* are restored from the control block.  Then the appropriate exception frame
* for the architecture being used is constructed.  To unlock interrupts and
* enter the new context we simply use the instruction rte.
*
* NOMANUAL

* void windLoadContext ()

*/

_windLoadContext:
	movel	_taskIdCurrent,a0		/* current tid */
	movel	a0@(WIND_TCB_ERRNO),d0		/* save errno */
	movel	d0,_errno
	movel	a0@(WIND_TCB_SSP),a7		/* push dummy except. */

	movel	a0@(WIND_TCB_PC),a7@-		/* push new pc and sr */
	movel	a0@(WIND_TCB_HASMAC),a7@-	/* onto stack */
	movel   #0x40003000,d0			/* TCB value set back to default */
	movel   d0,a0@(WIND_TCB_HASMAC)		/* TCB value set back to default */
                                                /* if an exception occurs, HASMAC will */
                                                /* have the proper value from instr above */

	tstl	__coldfireHasMac
	jeq 	windLoadCtxtEnd			/* jump if no MAC */

	movel	a0@(WIND_TCB_MAC),d0		/* restore MAC */
	.word	0xa100				/* movel d0,acc */
	movew	a0@(WIND_TCB_MACSR),d0		/* restore MACSR */
	.word	0xa900				/* movel d0,macsr */
	movew	a0@(WIND_TCB_MASK),d0		/* restore MASK */
	.word	0xad00				/* movel d0,mask */

windLoadCtxtEnd:

	moveml	a0@(WIND_TCB_REGS),d0-d7/a0-a6	/* load register set */
	rte					/* enter task's context. */

#endif	/* PORTABLE */

/*******************************************************************************
*
* intEntTrap - trap entry for interrupts to allow stack switching.
*
* intEntTrap is called by use of a trap #XXX instruction at the start of
* an interrupt service routine (in the intConnect stub).  At the point
* this routine is called, there are two exception stack frames on the
* stack: the exception frame for the interrupt and the exception frame
* for the trap.
* This routine should NEVER be called from C.
*
* SEE ALSO: intConnect(2)

* void intEntTrap ()

*/

_intEntTrap:
	movew	#0x3700,sr	/* disable interrupts, turn on M bit */
	/*
	 * stack (task or interrupt):
	 *	trap frame format,fs,vector,sr
	 *	trap frame PC
	 *	interrupt frame format,fs,vector,sr
	 *	interrupt frame PC
	 */
	movel	d0,a7@-			/* save d0 */
	
	/* check SR from interrupt to see if already on int stack. */
	movew	a7@(4+8+2),d0		/* ISR frame SR */
	andl	#0x0700,d0		/* if the interrupt level > 0 */
	beq	0f			/*   was in ISR */
	movel	a7@+,d0			/* restore d0 */
	rte				/* rte to intConnectStub */
0:
	movel	a0,a7@-			/* save a0 */
	/* switch to ISR stack */
	movel	_vxIntStackBase,a0	/* pointer into ISR stack */
	/*
	 * task stack:
	 *	saved a0
	 *	saved d0
	 *	trap frame format,fs,vector,sr
	 *	trap frame PC
	 *	interrupt frame format,fs,vector,sr
	 *	interrupt frame PC
	 */
	/* push pointer to task stack interrupt frame */
	movel	a7,d0			/* ptr to trap frame */
	addl	#16,d0			/* pop trap frame and saved regs */
	movel	d0,a0@-			/* ptr to int frame on ISR stack */
	
	/* copy over interrupt and trap frames */
	movel	a7@(8+8+4),a0@-		/* int frame PC */
	movel	a7@(8+8+0),a0@-		/* int frame fmt,fs,vector,sr */
	movel	a7@(8+4),a0@-		/* trap frame PC address */
	movel	a7@(8+0),a0@-		/* trap frame fmt,fs,vector,sr */
	
	movel	a0,a7@-			/* push new stack pointer */
	movel	a7@(4),a0		/* restore a0 */
	movel	a7@(8),d0		/* restore d0 */
	movel	a7@,a7			/* new SP, switch stacks */
	/*
	 * task stack:
	 *	interrupt frame format,fs,vector,sr
	 *	interrupt frame PC
	 *	
	 * interrupt stack:
	 *	trap frame format,fs,vector,sr
	 *	trap frame PC
	 *	interrupt frame format,fs,vector,sr
	 *	interrupt frame PC
	 *	pointer to interrupt frame on task stack (for intExit).
	 */
	rte				/* rte to intConnect stub */
	
/*******************************************************************************
*
* intEnt - enter an interrupt service routine
*
* intEnt must be called at the entrance of an interrupt service routine.
* This normally happens automatically, from the stub built by intConnect (2).
* This routine should NEVER be called from C.
*
* SEE ALSO: intConnect(2)

* void intEnt ()

*/

_intEnt:
	movel	a7@,a7@-		/* bump return address up a notch */
	movel	d0,a7@-			/* save d0 */
	movel	_errno,d0
	movel	d0,a7@(0x8)		/* save errno where return adress was */
	movel	a7@+,d0			/* restore d0 */
	addql	#1,_intCnt		/* Bump the counter */

#ifdef WV_INSTRUMENTATION	/* wv4: intEnt */

	/* Is instrumentation on?
	*/
	tstl	_evtAction
        jeq     wv4_skip

	/* Save registers.
	*/
	subl	#44,a7
	moveml  d0-d2/a0-a6,a7@	
	movew	sr,d1
	movew	d1,a7@(40)		/* Previous SR remains in d1 */
	movew	_intLockIntSR,d0
	movew	d0,sr			/* Lock interrupts */

        /* Do we need to log this event?
	*/
        movel   _wvEvtClass,d2
        andl    #WV_CLASS_1_ON,d2
        cmpl    #WV_CLASS_1_ON,d2
        jne     wv4_chkTrig

	/* Calculate event ID from the interrupt number
	*/
	andl	#0x0700,d1
	asrl	#8,d1
	addl	#MIN_INT_ID,d1

        /* Now log the event.
	*/
        movel   d1,a7@-
        movel   __func_evtLogT0_noInt,a1
        jsr     a1@
        addl    #4,a7

wv4_chkTrig:
        /* Do we need to evaluate triggers for this event?
	*/
        movel   _trgEvtClass,d2
        andl    #TRG_CLASS_1_ON,d2
        cmpl    #TRG_CLASS_1_ON,d2
        jne     wv4_restore

	/* Calculate event ID from the interrupt number
	*/
	movew	a7@(40),d1		/* previous SR */
	andl	#0x0700,d1
	asrl	#8,d1
	addl	#MIN_INT_ID,d1

        /* Evaluate triggers.
	*/
        clrl    a7@-				/* param 8 - unused */
        clrl    a7@-				/* param 7 - unused */
        clrl    a7@-				/* param 6 - unused */
        clrl    a7@-				/* param 5 - unused */
        clrl    a7@-				/* param 4 - unused */
        clrl    a7@-				/* param 3 - unused */
        movel   #TRG_CLASS1_INDEX,a7@-		/* param 2 - class index */
        movel   d1,a7@-				/* param 1 - event id */
        movel   __func_trgCheck,a0
        jsr     a0@
        addl    #32,a7				/* Pop params */

wv4_restore:
	movew	a7@(40),d0
	movew	d0,sr				/* Restore SR */
	moveml  a7@,d0-d2/a0-a6			/* restore regs */
	addl	#44,a7
wv4_skip:

#endif	/* WV_INSTRUMENTATION wv4 */

	rts

/*******************************************************************************
*
* intExit - exit an interrupt service routine
*
* Check the kernel ready queue to determine if rescheduling is necessary.  If
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
* SEE ALSO: intConnect(2)

* void intExit ()

* INTERNAL
* This routine must preserve all registers up until the context is saved,
* so any registers that are used to check the queues must first be saved on
* the stack.
*
* At the call to reschedule the value of taskIdCurrent must be in a0.
*/


_intExit:
	movel	a7@+,_errno		/* restore errno */
	movel	d0,a7@-			/* push d0 onto interrupt stack */
	movel	a0,a7@-			/* push a0 onto interrupt stack */

#ifdef WV_INSTRUMENTATION	/* wv5: intExit */

	/* Is instrumentation on?
	*/
	tstl	_evtAction
        jeq     wv5_skip

	/* Save registers.
	*/
	subl	#44,a7
	moveml  d0-d2/a0-a6,a7@	
	movew	sr,d1
	movew	d1,a7@(40)
	movew	_intLockIntSR,d0
	movew	d0,sr

        /* Do we need to log this event?
	*/
        movel   _wvEvtClass,d2
        andl    #WV_CLASS_1_ON,d2
        cmpl    #WV_CLASS_1_ON,d2
        jne     wv5_chkTrig
 
        movel   #EVENT_INT_EXIT, d1		/* event ID is now in d1 */
	tstl	_workQIsEmpty
	jne	wv5_log
        movel   #EVENT_INT_EXIT_K, d1

wv5_log:
        /* Now log the event.
	*/
        movel   d1,a7@-
        movel   __func_evtLogT0_noInt,a1
        jsr     a1@
        addl    #4,a7

wv5_chkTrig:
        /* Do we need to evaluate triggers for this event?
	*/
        movel   _trgEvtClass,d2
        andl    #TRG_CLASS_1_ON,d2
        cmpl    #TRG_CLASS_1_ON,d2
        jne     wv5_restore

        movel   #EVENT_INT_EXIT, d1		/* event ID is now in d1 */
	tstl	_workQIsEmpty
	jne	wv5_trigger
        movel   #EVENT_INT_EXIT_K, d1

wv5_trigger:
        /* Evaluate triggers.
	*/
        clrl    a7@-				/* param 8 - unused */
        clrl    a7@-				/* param 7 - unused */
        clrl    a7@-				/* param 6 - unused */
        clrl    a7@-				/* param 5 - unused */
        clrl    a7@-				/* param 4 - unused */
        clrl    a7@-				/* param 3 - unused */
        movel   #TRG_CLASS1_INDEX,a7@-		/* param 2 - class index */
        movel   d1,a7@-				/* param 1 - event id */
        movel   __func_trgCheck,a0
        jsr     a0@
        addl    #32,a7				/* Pop params */

wv5_restore:
	movew	a7@(40),d0
	movew	d0,sr				/* Restore SR */
	moveml  a7@,d0-d2/a0-a6			/* restore regs */
	addl	#44,a7
wv5_skip:

#endif	/* WV_INSTRUMENTATION wv5 */

	moveql	#1,d0
	subl	d0,_intCnt		/* decrement intCnt */
	tstl	_kernelState		/* if kernelState == TRUE */
	jne	intRte			/*  then just clean up and rte */

	movew	a7@(10),d0		/* get the sr off the stack into d0 */
	andl	#0x0700,d0		/* if the interrupt level > 0 */
	jne	intRte			/*  then came from ISR...clean up/rte */

	movew	_intLockIntSR,d0	/* LOCK INTERRUPTS */
	movew	d0,sr
	movel	_taskIdCurrent,a0	/* put current task into a0 */
	cmpl	_readyQHead,a0		/* compare to highest ready task */
	jeq	intRte			/* if same then don't reschedule */

	tstl	a0@(WIND_TCB_LOCK_CNT)	/* is task preemption allowed */
	jeq	saveIntContext		/* if yes, then save context */
	tstl	a0@(WIND_TCB_STATUS)	/* is task ready to run */
	jne	saveIntContext		/* if no, then save context */

intRte:
	movew	a7@(10),d0		/* get the sr off the stack into d0 */
	andl	#0x0700,d0		/* if the interrupt level > 0 */
	jne	0f			/* jump if nested interrupt */
	movel	a7@+,a0			/* restore a0 */
	movel	a7@+,d0			/* restore d0 */
 	movel	a7@(8),a7		/* switch back to task stack */
	rte
0:
	movel	a7@+,a0		/* restore a0 */
	movel	a7@+,d0		/* restore d0 */
	rte			/* UNLOCKS INTERRUPT and return to interupted */

/* We come here if we have decided that rescheduling is a distinct possibility.
 * The context must be gathered and stored in the current task's tcb.
 * The stored stack pointer must be modified to clean up the SSP.
 */

saveIntContext:
	/* interrupts are still locked out */
	movel	#1,d0				/* kernelState = TRUE; */
	movel	d0,_kernelState
	movel	_taskIdCurrent,a0		/* tcb to be fixed up */
	movel	a7@+,a0@(WIND_TCB_AREGS)	/* store a0 in tcb */
	movel	a7@+,a0@(WIND_TCB_DREGS)	/* store d0 in tcb */
	movel	a7@(8),a7			/* switch back to task stack */
	movew	#0x3000,sr			/* unlock int., switch to msp */

	/* interrupts unlocked and using master stack*/
	movel	a7@,a0@(WIND_TCB_HASMAC)	/* save sr in tcb */
	movel	a7@(4),a0@(WIND_TCB_PC)		/* save pc in tcb */
	moveml	d1-d7,a0@(WIND_TCB_DREGS4)	/* d1-d7 */
	moveml	a1-a7,a0@(WIND_TCB_AREGS4)	/* a1-a7 */

	tstl	__coldfireHasMac
	jeq 	saveIntCtxtMacEnd		/* jump if no MAC */

saveIntCtxtMac:
	.word	0xa180				/* movel acc,d0 */
	movel	d0,a0@(WIND_TCB_MAC)		/* save MAC */
	.word	0xa980				/* movel macsr,d0 */
	movew	d0,a0@(WIND_TCB_MACSR)		/* save MACSR */
	.word	0xad80				/* movel mask,d0 */
	movew	d0,a0@(WIND_TCB_MASK)		/* save MASK */

saveIntCtxtMacEnd:
	addl    #8,a0@(WIND_TCB_SSP)            /* adj master stack ptr */
	
	movel	_errno,d0			/* save errno */
	movel	d0,a0@(WIND_TCB_ERRNO)

	jmp	_reschedule			/* goto rescheduler */


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

_vxTaskEntry:
	movel	#0,a6			/* make sure frame pointer is 0 */
	movel	_taskIdCurrent,a0 	/* get current task id */
	movel	a0@(WIND_TCB_ENTRY),a0	/* entry point for task is in tcb */
	jsr	a0@			/* call main routine */
	addl	#40,a7			/* pop args to main routine */
	movel	d0,a7@-			/* pass result to exit */
	jsr	_exit			/* gone for good */

/*******************************************************************************
*
* windIntStackSet - set the interrupt stack pointer
*
* This routine sets the interrupt stack pointer to the specified address.
* It is only valid on architectures with an interrupt stack pointer.
*
* NOMANUAL

* void windIntStackSet
*     (
*     char *pBotStack	/@ pointer to bottom of interrupt stack @/
*     )

*/

_windIntStackSet:
	link	a6,#0
	unlk	a6
	rts
