/* windALib.s - internal VxWorks kernel assembly library */

/* Copyright 1995-2001 Wind River Systems, Inc. */

	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
04q,10dec01,zl   added leading underscore to areWeNested.
04p,05nov01,zl   added underscore to intRte1W and intRte2W.
04o,07sep01,h_k  added _func_vxIdleLoopHook for power control support (SPR
                 #69838).
04n,24sep00,zl   moved _func_wdbUbcInit from wdbDbgArchLib.c.
04m,08sep00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
		 rename brandNewTaskSR to intUnlockSR, also change it as
		 a global data to support SR.DSP preservation.
		 move windIntStackSet to intArchLib.
04l,21jun00,hk   rearranged code layout to improve WV-off performance.
04k,23may00,hk   fixed instrumentation bugs in windExitInt/checkWorkQ/dispatch.
04j,22may00,hk   reviewed WindView instrumentation code for T2/SH4.
04i,27apr00,frf  WindView support for SH: functions changed:reschedule,
		 idle,windExitInt,checkWorkQ,windExit,intEnt,intExit.
04h,10apr00,hk   got rid of .ptext/.pdata sections. relaxed tight coding.
04g,28mar00,hk   added .type directive to function names and variables.
04f,17mar00,zl   made use of alignment macro _ALIGN_TEXT
04e,05oct99,zl   updated for little endian event logging
04e,08jun99,zl   added .ptext attribute "ax" and .pdata attribute "aw"
04d,02mar99,hk   put back intCnt to intLib, errno to errnoLib.
04c,02mar99,hk   simplified CPU conditionals.
03y,07nov98,hk   changed intStub to facilitate intVecSet() usage by user.
04b,09oct98,hk   code review: sorted CPU conditionals.
04a,07oct98,st   changed to use SGR register at stack change operation in
		 intStub (SH7750 only).
03z,17sep98,hk   unified to use SH7700_VEC_TABLE_OFFSET for SH7750.
03y,16jul98,st   added SH7750 support.
03z,02sep98,jmc  revised initial SR for SH7729 to include DSP = 1.
03y,08may98,jmc  added support for SH-DSP and SH3-DSP.
03x,03mar98,hk   changed to use immediate values instead of longword constants.
03w,03nov97,hk   reviewed intExit instrumentation for SH7600/SH7040/SH7000.
03v,10jul97,hk   reviewed windview instrumentation code.
03u,11jun97,hms  deleted lines related with windview, as there were duplicate
                 instructions in sequence of intStub function.
03t,05may97,hk   deleted pre-03a history, see RCS. made windviewInstr local.
03s,03may97,hk   made windview instrumentation conditionally compiled.
03r,28apr97,hk   changed SH704X to SH7040.
03t,11apr97,hms  added variable reference for SH7600/7000/704X WindView support
03s,16mar97,hms  changed function order. Functions for WindView suppport were
		 move to top of this file.
03r,06mar97,hms  added WindView support.
03q,12feb97,hk   added SH7707 support, intStub selects INTEVT2 by intEvtAdrs.
                 pushed INTEVT on stack to avoid r4_bank1 corruption by NMI.
03p,18jan97,hk   added _nullEvtCnt to monitor null event interrupt.
03o,23dec96,hk   changed code layout to localize pc relative labels. deleted
                 unnecessary .align and 68k specific comments. did pipeline
                 optimization in intRte and saveIntContext for SH7700. moved
                 _vxTaskEntry/_windIntStackSet back to .text.
03n,22dec96,hk   updated windLoadContext for SH7700. did some comment review.
03m,21dec96,hk   moved vxIntStackBase/intCnt/errno to .pdata.
03l,16dec96,wt   deleted DEBUG_LOCAL_LABELS stuff. made VxIntStackBase and
           +hk   AreWeNested local. made windIntStackSet as empty function.
03k,16dec96,wt   changed dispatch for mmu support. removed logical memory
           +hk   access code after blocking TLB exception. 
03j,12dec96,hk   named .ptext/.pdata sections for SH7700 mmu support.
03i,09dec96,hk   made areWeNested global, set INTEVT to r4_bank1 in intStub,
		 added intStayBlocked: to handle NULL entry in intPrioTable[].
03h,08dec96,wt   changed intStub/intExit/saveIntContext for SH7700 to run
	   +hk   interrupt handler on bank-0. adopt areWeNested for SH7700.
03g,26sep96,hk   added interrupt blocking code in dispatch. changed cmp/eq to
		 tst in intUnblock, to use r2 instead of r0. rewrote intExit
		 for SH7700, now its sequence is identical to SH7600/SH7000.
03f,17sep96,hk   overhauled _intStub, added bypass for BL unblocking.
03e,02sep96,hk   deleted unnecessary comment.
03d,23aug96,hk   changed INTEVT notation (-40 => 0xd8).
03c,19aug96,hk   deleted INT_STACK_ENABLE, intSpurious, moved SH7700 intRte.
03b,19aug96,hk   changed code align to save some bytes.
03a,18aug96,hk   improved interrupt stack emulation for SH7600/SH7000/SH7040.
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they are either
specific to this processor, or they have been optimized for performance.

INTERNAL

        +-----> checkTaskReady
        |               |
        |               +--(task is not ready)------------------------->+
        |               |                                               |
        |               v                                               |
        |  +--> checkWorkQ                            windExitInt <--+  |
        |  |            |                               |            |  |
        |  |            +---->(workQueue is empty)<-----+            |  |
        |  |            |               |               |            |  |
        |  |            |               v               |            |  |
        |  |            |             return            |            |  |
        |  |            v                               v            |  |
        |  |    doWorkPreSave <=> _workQDoWork <=> windExitIntWork   |  |
        |  |            |                               |            |  |
        |  |            |   _windExit                   +----------->|  |
        |  |            |       |                                    |  |
        |  |            |       +----(called at interrupt level)---->+  |
        |  |            |       |                                       |
        |  |            v       v                                       v
        |  |          checkTaskSwitch   +-------------------------------+
        |  |                    |       |
        |  +--(task is highest)-+       |    _intExit
        |                       |       |       |
        +-----(task is locked)--+       |       +--> intRte -> rte
                                |       |       |
                                v       v       v
                             saveTaskContext    saveIntContext
                                        |       |
                                        v       v
                                        reschedule
                                            |
        +--------------------+              v
        | windExit & intExit |       _windLoadContext
        | state transition   |              |
        | diagram            |              v
        +--------------------+             rte (to new context)
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "iv.h"
#include "private/taskLibP.h"
#include "private/workQLibP.h"
#include "private/eventP.h"
#include "private/semLibP.h"

#if	(TRG_CLASS1_INDEX > 0x7f)
#error	TRG_CLASS1_INDEX > 0x7f, check eventP.h
#endif
#if	(MIN_INT_ID >= 0x7f)
#error	MIN_INT_ID >= 0x7f, check eventP.h
#endif
#if	(EVENT_DISPATCH_OFFSET >= 0x7f)
#error	EVENT_DISPATCH_OFFSET >= 0x7f, check eventP.h
#endif
#if	(EVENT_INT_EXIT >= 0x7f)
#error	EVENT_INT_EXIT >= 0x7f, check eventP.h
#endif
#if	(EVENT_INT_EXIT_K >= 0x7f)
#error	EVENT_INT_EXIT_K >= 0x7f, check eventP.h
#endif
#if	(EVENT_NODISPATCH_OFFSET >= 0x7f)
#error	EVENT_NODISPATCH_OFFSET >= 0x7f, check eventP.h
#endif
#if	(EVENT_WIND_EXIT_DISPATCH >= 0x7f)
#error	EVENT_WIND_EXIT_DISPATCH >= 0x7f, check eventP.h
#endif
#if	(EVENT_WIND_EXIT_DISPATCH_PI >= 0x7f)
#error	EVENT_WIND_EXIT_DISPATCH_PI >= 0x7f, check eventP.h
#endif
#if	(EVENT_WIND_EXIT_NODISPATCH >= 0x7f)
#error	EVENT_WIND_EXIT_NODISPATCH >= 0x7f, check eventP.h
#endif
#if	(EVENT_WIND_EXIT_NODISPATCH_PI >= 0x7f)
#error	EVENT_WIND_EXIT_NODISPATCH_PI >= 0x7f, check eventP.h
#endif
#if	(EVENT_WIND_EXIT_IDLE >= 0x7f)
#error	EVENT_WIND_EXIT_IDLE >= 0x7f, check eventP.h
#endif
#if	(WIND_TCB_ENTRY >= 0x7f)
#error	WIND_TCB_ENTRY >= 0x7f, check taskLibP.h
#endif
#if	(WIND_TCB_ERRNO >= 0x7f) && FALSE
#error	WIND_TCB_ERRNO >= 0x7f, check taskLibP.h
#endif
#if	(WIND_TCB_LOCK_CNT >= 0x7f)
#error	WIND_TCB_LOCK_CNT >= 0x7f, check taskLibP.h
#endif
#if	(WIND_TCB_PRIORITY >= 0x7f)
#error	WIND_TCB_PRIORITY >= 0x7f, check taskLibP.h
#endif
#if	(WIND_TCB_PRI_NORMAL >= 0x7f)
#error	WIND_TCB_PRI_NORMAL >= 0x7f, check taskLibP.h
#endif
#if	(WIND_TCB_STATUS >= 0x7f)
#error	WIND_TCB_STATUS >= 0x7f, check taskLibP.h
#endif
#if	(WIND_TCB_SWAP_IN >= 0x7f)
#error	WIND_TCB_SWAP_IN >= 0x7f, check taskLibP.h
#endif
#if	(WIND_TCB_SWAP_OUT >= 0x7f)
#error	WIND_TCB_SWAP_OUT >= 0x7f, check taskLibP.h
#endif
#if	(WIND_TCB_MACL > 0x7fff)
#error	WIND_TCB_MACL > 0x7fff, check regsSh.h and taskLibP.h
#endif

#if (CPU==SH7750 || CPU==SH7700)

#if	(SH7700_INT_EVT_ADRS_OFFSET > 60)
#error	SH7700_INT_EVT_ADRS_OFFSET > 60, check ivSh.h
#endif
#if	(SH7700_ARE_WE_NESTED_OFFSET > 60)
#error	SH7700_ARE_WE_NESTED_OFFSET > 60, check ivSh.h
#endif
#if	(SH7700_INT_STACK_BASE_OFFSET > 60)
#error	SH7700_INT_STACK_BASE_OFFSET > 60, check ivSh.h
#endif
#if	(SH7700_NULL_EVT_CNT_OFFSET > 60)
#error	SH7700_NULL_EVT_CNT_OFFSET > 60, check ivSh.h
#endif
#if	(SH7700_DISPATCH_STUB_OFFSET > 0x7f)
#error	SH7700_DISPATCH_STUB_OFFSET > 0x7f, check ivSh.h and adjust dispatch.
#endif
#if	(SH7700_INT_EXIT_STUB_OFFSET > 0x7f)
#error	SH7700_INT_EXIT_STUB_OFFSET > 0x7f, check ivSh.h and adjust intExit.
#endif

#define INT_EVT_ADRS	SH7700_INT_EVT_ADRS_OFFSET		/* ivSh.h */
#define ARE_WE_NESTED	SH7700_ARE_WE_NESTED_OFFSET		/* ivSh.h */
#define INT_STACK_BASE	SH7700_INT_STACK_BASE_OFFSET		/* ivSh.h */
#define NULL_EVT_CNT	SH7700_NULL_EVT_CNT_OFFSET		/* ivSh.h */
#define DISPATCH_STUB	SH7700_DISPATCH_STUB_OFFSET		/* ivSh.h */
#define INT_EXIT_STUB	SH7700_INT_EXIT_STUB_OFFSET		/* ivSh.h */

#elif (CPU!=SH7600 && CPU!=SH7000)
#error The CPU macro is not defined properly
#endif /* CPU!=SH7600 && CPU!=SH7000 */

/* 
 * The _func_wdbUbcInit declaration normally should be in wdbDbgArchLib.c, but
 * then bootrom builds fail because the BSPs setting this function pointer drag
 * in the wdbDbgArchLib.o module.
 */

	.global __func_wdbUbcInit
	.type	__func_wdbUbcInit,@object
	.align 2
__func_wdbUbcInit:	.long	0	/* hook for BSP's UBC init function */

	.text

	.global	_windExit		/* routine to exit mutual exclusion */
	.global	_vxTaskEntry		/* task entry wrapper           */
	.global	_intExit		/* interrupt exit routine       */
	.global	_intEnt			/* interrupt entrance routine   */
#if (CPU==SH7750 || CPU==SH7700)
	.global	_dispatchStub		/* referenced from intArchLib	*/
	.global	_dispatchStubSize	/* referenced from intArchLib	*/
	.global	_intExitStub		/* referenced from intArchLib	*/
	.global	_intExitStubSize	/* referenced from intArchLib	*/
	.global	_intStub		/* referenced from intArchLib   */
	.global	_intStubSize		/* referenced from intArchLib   */
	.global	_intRte1W		/* for intVecSet() usage */
	.global	_intRte2W		/* for intVecSet() usage */
#endif /* CPU==SH7750 || CPU==SH7700 */

#undef	DEBUG
#ifdef	DEBUG
	.global	windExitInt
	.global	checkTaskReady
	.global	checkWorkQ
	.global	doWorkPreSave
	.global	checkTaskSwitch
	.global	saveTaskContext
	.global	saveIntContext
#ifdef	WV_INSTRUMENTATION
	.global	intEntInstr
	.global	intExitInstr
	.global	noDispatchInstr
#endif	/* WV_INSTRUMENTATION */
#endif	/* DEBUG */

#undef	PORTABLE
#ifdef	PORTABLE
	.global	_windLoadContext	/* needed by portable reschedule () */
#else	/* !PORTABLE */
	.global	_reschedule		/* optimized reschedule () routine */
#ifdef	DEBUG
	.global	idle
	.global	switchTasks
	.global	doSwapHooks
	.global	doSwitchHooks
	.global	dispatch
	.global	doWorkUnlock
	.global	doWork
#ifdef	WV_INSTRUMENTATION
	.global	dispatchInstr
	.global	idleInstr
#endif	/* WV_INSTRUMENTATION */
#endif	/* DEBUG */
#endif	/* !PORTABLE */


#if (CPU==SH7750 || CPU==SH7700)
/******************************************************************************
*
* dispatchStub - last part of task dispatch (SH7750/SH7700)
*
* Before loading spc/ssr, intRte must set SR.BL to 1.  While SR.BL=1,
* any virtual space access may cause h/w reboot due to TLB miss hit.
* Hence this routine is copied to a fixed physical address space.
*
* NOTE: This stub is shared by dispatch/windLoadContext/_sigCtxLoad.
*/
	.align	2			/* ??? hangs if no align */
	.type	_dispatchStub,@function

_dispatchStub:				/* SR: intLockTaskSR */
	mov.l	@r14+,r11
	mov.l	@r14+,r12
	mov.l	@r14+,r13
	ldc.l	@r14+,r4_bank
	ldc.l	@r14+,r5_bank
	ldc.l	@r14+,r6_bank
	ldc.l	@r14+,r7_bank

	mov.l	DS_IntBlockSR,r14
	mov.l	@r14,r14
	ldc	r14,sr			/* BLOCK INTERRUPTS/EXCEPTION, RB=1 */

	mov	r4,r14
	mov	r5,sp
	ldc	r6,spc
	ldc	r7,ssr
	rte;				/* UNBLOCK INTERRUPTS/EXCEPTION */
	nop
			.align	2
DS_IntBlockSR:		.long	_intBlockSR
dispatchStubEnd:
			.align	2
			.type	_dispatchStubSize,@object
			.size	_dispatchStubSize,4
_dispatchStubSize:	.long	dispatchStubEnd - _dispatchStub

/******************************************************************************
*
* intExitStub - last part of intExit (SH7750/SH7700)
*
* Before loading spc/ssr, SR.BL must be set to 1.  While SR.BL=1,
* any virtual space access may cause h/w reboot due to TLB miss hit.
* Hence this routine is copied to a fixed physical address space.
*/
	.align	2			/* ??? hangs if no align */
	.type	_intExitStub,@function

_intExitStub:
	/* BLOCK INTS/EXCEPTION */	mov.l	@sp+,r1
	ldc	r0,sr;			ldc.l	@sp+,r0_bank
					lds.l	@sp+,pr
intRte2:
	stc	vbr,r1;			ldc.l	@sp+,spc
	mov.l	@(ARE_WE_NESTED,r1),r0; ldc.l	@sp+,ssr
	rotr	r0
	bf.s	intRteNested;
	mov.l	r0,@(ARE_WE_NESTED,r1)	/* update areWeNested */
	rte;
	mov.l	@(4,sp),sp		/* return to task stack */

intRteNested:
	rte;
	add	#4,sp			/* skip INTEVT */

intRte1:				mov.l	@sp+,r1
	ldc	r0,sr;			bra	intRte2;
					ldc.l	@sp+,r0_bank
intExitStubEnd:
			.align	2
			.type	_intExitStubSize,@object
			.size	_intExitStubSize,4
_intExitStubSize:	.long	intExitStubEnd - _intExitStub


/* 
 * _intRte1W and _intRte2W can be used to implement fast interrupt handlers
 * connected with intVecSet() as described in target/src/arch/doc/intArchLib.c
 */


		.type	_intRte1W,@object
		.size	_intRte1W,2
_intRte1W:	.word	intRte1 - _intExitStub + INT_EXIT_STUB

		.type	_intRte2W,@object
		.size	_intRte2W,2
_intRte2W:	.word	intRte2 - _intExitStub + INT_EXIT_STUB


/******************************************************************************
*
* intStub - Catch and dispatch interrupts (SH7750/SH7700)
*
* This is the interrupt dispatcher that is pointed to by the SH3 interrupt
* vector.  These instructions are copied to (vbr + 0x600), the SH3 interrupt
* vector by the startup routine intVecBaseSet().  In this routine we take care
* of saving state, and jumping to the appropriate routine.  On exit from
* handling we also return here to restore state properly.
*
* NOMANUAL

* void intStub()

* INTERNAL
*
*    [ task's stack ]		   [ interrupt stack ]
*				
*	|  xxx	|
*	|  yyy	|     vxIntStackBase ->	+-------+
*	|__zzz__|<----------------------|task'sp| +8
*	|	|			|INTEVT	| +4
*	|	|			|  ssr	| +0 (at intStubNullEvt)
*				  sp ->	|_ spc _|
*					|	|
*
* CAUTION: DO NOT BREAK R4, R5, R6, AND R7 IN BANK1 !!!
*          THEY ARE USED IN DISPATCH CODE WHILE SR IS 0X400000F0.
*
* NOTE: Omitted _ALIGN_TEXT since this routine will be copied to vbr + 0x600.
*/

#if	(SH7700_VEC_TABLE_OFFSET != 0x800)
#error	SH7700_VEC_TABLE_OFFSET != 0x800, check ivSh.h and adjust intStub.
#endif
#if	(SH7700_INT_PRIO_TABLE_OFFSET != 0xc00)
#error	SH7700_INT_PRIO_TABLE_OFFSET != 0xc00, check ivSh.h and adjust intStub.
#endif

	.align	2
	.type	_intStub,@function

_intStub:
	stc	vbr,r3;			mov.l	@(INT_EVT_ADRS,r3),r1
	mov.l	@(ARE_WE_NESTED,r3),r0;	mov.l	@r1,r2	/* r2: INTEVT */
	rotl	r0
	bf.s	intStubSaveRegs
	mov.l	r0,@(ARE_WE_NESTED,r3)	/* update areWeNested */

#if	(CPU==SH7750)
	mov.l	@(INT_STACK_BASE,r3),sp	/* switch to interrupt stack */
	.word	0x4f32			/* stc.l sgr,@-sp : save task's sp */
#else	/* in default of sgr */
	mov.l	@(INT_STACK_BASE,r3),r0
	mov.l	sp,@-r0			/* save task's stack pointer */
	mov	r0,sp			/* switch to interrupt stack */
#endif

intStubSaveRegs:
	mov.l	r2,@-sp;		tst	r2,r2
	stc.l	ssr,@-sp;		bt	intStubNullEvt
	stc.l	spc,@-sp;		mov	#-3,r1

	/* load new sr to ssr */	/* load dispatch address to spc */
	mov	#0xc,r0;		shld	r1,r2	/* r2: 0, 4, 8, ... */
	shll8	r0;	/* r0: 0xc00 */
	add	r3,r0
	mov.l	@(r0,r2),r1;		mov	#0x8,r0
					shll8	r0	/* r0: 0x800 */
	tst	r1,r1;			add	r3,r0
	bt.s	intStubStayBlocked;	mov.l	@(r0,r2),r0
	ldc	r1,ssr;			ldc	r0,spc
	rte;				nop

intStubStayBlocked:
	jmp	@r0;
	nop

intStubNullEvt:
	mov.l	@(ARE_WE_NESTED,r3),r0;	mov.l	@(NULL_EVT_CNT,r3),r1
	rotr	r0;			add	#1,r1
	mov.l	r0,@(ARE_WE_NESTED,r3);	mov.l	r1,@(NULL_EVT_CNT,r3)
	bf	intStubNullEvtNested
	rte;
	mov.l	@(8,sp),sp
intStubNullEvtNested:
	rte;
	add	#8,sp			/* skip ssr/INTEVT on stack */
intStubEnd:
		.align	2
		.type	_intStubSize,@object
		.size	_intStubSize,4
_intStubSize:	.long	intStubEnd - _intStub

/******************************************************************************
*
* intEnt - enter an interrupt service routine (SH7750/SH7700)
*
* intEnt must be called at the entrance of an interrupt service routine.
* This normally happens automatically, from the stub built by intConnect (2).
* This routine should NEVER be called from C.
*
* SEE ALSO: intConnect(2)

* void intEnt ()

*/
	.align	_ALIGN_TEXT
	.type	_intEnt,@function

_intEnt:
	mov.l	r2,@-sp
	mov.l	r3,@-sp
	mov.l	r4,@-sp;		mov.l	IE_IntCnt,r0;
	mov.l	r5,@-sp;		mov.l	@r0,   r1;
	mov.l	r6,@-sp;		add	#1,    r1
	mov.l	r7,@-sp;		mov.l	IE_Errno, r2;
	sts.l	mach,@-sp;		mov.l	@r2,   r3;
	sts.l	macl,@-sp;		mov.l	r3,  @-sp	/* push errno */
					mov.l	r1,   @r0	/* bump count */
#ifdef	WV_INSTRUMENTATION
	mov.l	IE_EvtAction,r3;
	mov.l	@r3,r2;
	tst	r2,r2
	bf	intEntInstr	/* let him return */
#endif
	rts;
	nop
			.align	2
IE_IntCnt:		.long	_intCnt
IE_Errno:		.long	_errno
#ifdef	WV_INSTRUMENTATION
IE_EvtAction:		.long	_evtAction
#endif

#elif (CPU==SH7600 || CPU==SH7000)
/******************************************************************************
*
* intEnt - enter an interrupt service routine (SH7600/SH7000)
*
* intEnt must be called at the entrance of an interrupt service routine.
* This normally happens automatically, from the stub built by intConnect (2).
* This routine should NEVER be called from C.
*
* SEE ALSO: intConnect(2)

* void intEnt ()

* INTERNAL
*	     [ task's stack ]			   [ interrupt stack ]
*
*		|	|					|	|
*		|_______|					|_______|
*		|  sr	|					|  sr	|
*		|_ pc __|					|_ pc __|
*		|  pr	|					|  pr	|
*		|  r0	|					|  r0	|
*		|  r1	|     vxIntStackBase ->	|_______|	|  r1	|
*		|  r2	| <--------------------	|task'sp|	|  r2	|
*		|	|			|  r3	|	|  r3	|
*		|	|			|  r4	|	|  r4	|
*		|	|			|  r5	|	|  r5	|
*		|	|			|  r6	|	|  r6	|
*		|	|			|  r7	|	|  r7	|
*		|	|			| mach	|	| mach	|
*		|	|			| macl	|	| macl	|
*		|	|		  sp -> | errno	|	| errno	|
*		|	|			|	|	|	|
*
*		  (task) --------------------> (interrupt) --> (interrupt)
*
*  areWeNested: 0x80000000 -------------------> 0x00000001 ---> 0x00000002
*/
	.align	_ALIGN_TEXT
	.type	_intEnt,@function

_intEnt:
	mov.l	r2,  @-sp;		mov.l	IE_IntLockSR,r2
	mov.l	IE_AreWeNested,r1;	mov.l	@r2,r0
					stc	sr,r2	/* save current sr */
	/* update areWeNested */	ldc	r0,sr	/* LOCK INTERRUPTS */
	mov.l	@r1,r0
	rotl	r0
#if (CPU==SH7000)
	mov.l	r0,@r1
	bf	intEntNested
#else
	bf.s	intEntNested
	mov.l	r0,@r1
#endif
	mov.l	IE_VxIntStackBase,r1;
	mov.l	@r1,r0;
	mov.l	sp,@-r0			/* save task's sp           */
	mov	r0,sp			/* switch to interrupt stack*/
intEntNested:
					ldc	r2,sr	/* UNLOCK INTERRUPTS */
	mov.l	r3,  @-sp
	mov.l	r4,  @-sp;		mov.l	IE_IntCnt,r0;
	mov.l	r5,  @-sp;		mov.l	@r0,   r1;
	mov.l	r6,  @-sp;		add	#1,    r1
	mov.l	r7,  @-sp;		mov.l	IE_Errno, r2;
	sts.l	mach,@-sp;		mov.l	@r2,   r3;
	sts.l	macl,@-sp;		mov.l	r3,  @-sp	/* save errno */
					mov.l	r1,   @r0	/* bump count */
#ifdef	WV_INSTRUMENTATION
	mov.l	IE_EvtAction,r3;
	mov.l	@r3,r2;
	tst	r2,r2
	bf	intEntInstr	/* let him return */
#endif
	rts;
	nop
			.align	2
IE_IntLockSR:		.long	_intLockTaskSR
IE_AreWeNested:		.long	_areWeNested
IE_VxIntStackBase:	.long	_vxIntStackBase		/* kernelLib.c */
IE_IntCnt:		.long	_intCnt
IE_Errno:		.long	_errno
#ifdef	WV_INSTRUMENTATION
IE_EvtAction:		.long	_evtAction
#endif

#endif /* CPU==SH7600 || CPU==SH7000 */

#ifdef	WV_INSTRUMENTATION
/******************************************************************************
*
* intEntInstr - windview instrumentation: enter an interrupt handler
*
*/
	.align	_ALIGN_TEXT
	.type	intEntInstr,@function

intEntInstr:
	/* LOCK INTERRUPTS */
	mov.l	IEI_IntLockSR,r1;	mov.l	r8,@-sp
	mov.l	@r1,r0;			stc.l	sr,@-sp
	ldc	r0,sr;			sts.l	pr,@-sp

        /* We're going to need the event ID,
         * so get it now.
         */
	mov.l	@(4,sp),r0;		/* r0: sr */
	mov	#MIN_INT_ID,r8
	shlr2	r0
	shlr2	r0
	and	#0x0f,r0		/* r0: interrupt level */
	add	r0,r8			/* r8: event ID */

	/* check if we need to log this event */

	mov.l	IEI_WvEvtClass,r1;
	mov.l	IEI_WV_CLASS_1_ON,r3;
	mov.l	@r1,r0;
	and	r3,r0
	cmp/eq	r3,r0
	bf	intEntCheckTrg

	mov.l	IEI_EvtLogT0,r1;
	mov.l	@r1,r0;
	jsr	@r0;			/* evtLogT0 (eventID) */
	mov	r8,r4

intEntCheckTrg:
	/* check if we need to evaluate trigger for this event */

	mov.l  IEI_TrgEvtClass,r1;
	mov.l  IEI_TRG_CLASS_1_ON,r3;
	mov.l  @r1,r0;			mov	#0,r7	/* r7: NULL */
	and    r3,r0
	cmp/eq r3,r0
	bf     intEntInstDone

	/*             r4     r5   r6 r7 +0 +4 +8 +12 */
	/* trgCheck (eventID,index, 0, 0, 0, 0, 0, 0) */

	mov.l	r7,@-sp;		mov.l	r7,@-sp
	mov.l	r7,@-sp;		mov.l	r7,@-sp
	mov.l	IEI_TrgCheck,r1;	mov	r7,r6
	mov.l	@r1,r0;			mov	#TRG_CLASS1_INDEX,r5
	jsr	@r0;			mov	r8,r4
					add	#16,sp	/* pop params */
intEntInstDone:
					lds.l	@sp+,pr 
					ldc.l	@sp+,sr	/* UNLOCK INTERRUPT */
	rts;				mov.l	@sp+,r8

			.align	2
IEI_IntLockSR:		.long	_intLockTaskSR
IEI_WvEvtClass:		.long	_wvEvtClass
IEI_WV_CLASS_1_ON:	.long   WV_CLASS_1_ON
IEI_EvtLogT0:		.long	__func_evtLogT0
IEI_TrgEvtClass:	.long	_trgEvtClass
IEI_TRG_CLASS_1_ON:	.long	TRG_CLASS_1_ON	
IEI_TrgCheck:		.long	__func_trgCheck

/******************************************************************************
*
* intExitInstr - windview instrumentation: exit an interrupt handler
*
*/
	.align	_ALIGN_TEXT
	.type	intExitInstr,@function

intExitInstr:
	/* windview instrumentation - BEGIN
	 * log event if work has been done in the interrupt handler.
	 */

	/* LOCK INTERRUPTS */		
	mov.l	IXI_IntLockSR,r1;	mov.l	r8,@-sp
	mov.l	@r1,r0;			stc.l	sr,@-sp
	ldc	r0,sr;
	
	mov.l	IXI_WorkQIsEmpty,r1;	sts.l	pr,@-sp
	mov.l	@r1,r0;
	mov	#EVENT_INT_EXIT,r8
	tst	r0,r0
	bf 	intExitEvent		/* workQ is empty */
	mov	#EVENT_INT_EXIT_K,r8
intExitEvent:				/* r8: event ID */

	/* check if we need to log this event */

	mov.l	IXI_WvEvtClass,r1;
	mov.l	IXI_WV_CLASS_1_ON,r3;
	mov.l	@r1,r0;
	and	r3,r0
	cmp/eq	r3,r0
	bf	intExitCheckTrg
	
	mov.l	IXI_EvtLogT0,r1;
	mov.l	@r1,r0;
	jsr	@r0;			/* evtLogT0 (eventID) */
	mov	r8,r4
	
intExitCheckTrg:
	/* check if we need to evaluate trigger for this event */

	mov.l	IXI_TrgEvtClass,r1;
	mov.l	IXI_TRG_CLASS_1_ON,r3;
	mov.l	@r1,r0;			mov	#0,r7	/* r7: NULL */
	and	r3,r0
	cmp/eq	r3,r0
	bf	intExitInstDone

	/*             r4     r5   r6 r7 +0 +4 +8 +12 */
	/* trgCheck (eventID,index, 0, 0, 0, 0, 0, 0) */

	mov.l	r7,@-sp;		mov.l	r7,@-sp
	mov.l	r7,@-sp;		mov.l	r7,@-sp
	mov.l	IXI_TrgCheck,r1;	mov	r7,r6
	mov.l	@r1,r0;			mov	#TRG_CLASS1_INDEX,r5
	jsr	@r0;			mov	r8,r4
					add	#16,sp	/* pop params */
intExitInstDone:
					lds.l	@sp+,pr 
					ldc.l	@sp+,sr	/* UNLOCK INTERRUPT */
	bra	intExitNoInstr;		mov.l	@sp+,r8

			.align	2
IXI_IntLockSR:		.long	_intLockTaskSR
IXI_WorkQIsEmpty:	.long	_workQIsEmpty
IXI_WvEvtClass:		.long	_wvEvtClass
IXI_WV_CLASS_1_ON:	.long   WV_CLASS_1_ON		/* eventP.h */
IXI_EvtLogT0:		.long	__func_evtLogT0
IXI_TrgEvtClass:	.long	_trgEvtClass
IXI_TRG_CLASS_1_ON:	.long	TRG_CLASS_1_ON		/* eventP.h */
IXI_TrgCheck:		.long	__func_trgCheck
#endif	/* WV_INSTRUMENTATION */

#if (CPU==SH7750 || CPU==SH7700)
/******************************************************************************
*
* intExit - exit an interrupt service routine (SH7750/SH7700)
*
*/
	.align	_ALIGN_TEXT
	.type	_intExit,@function
					/* r1: _errno (poped @intConnectCode) */
_intExit:
	/* restore errno */
	mov.l	IX_Errno,r0;
	mov.l	r1,@r0

#ifdef	WV_INSTRUMENTATION
	mov.l	IX_EvtAction,r3;
	mov.l	@r3,r2;
	tst	r2,r2
	bf	intExitInstr		/* ==> intExitInstr */
intExitNoInstr:				/* <== intExitInstr */
#endif
					/* decrement intCnt */
					mov.l	IX_IntCnt,r2;
					mov.l	@r2,r1;
	/* if in kernel, rte */		add	#-1,r1
	mov.l	IX_KernelState,r0;	mov.l	r1,@r2
	mov.l	@r0,r1;			mov.l	IX_IntLockSR,r0;
	tst	r1,r1;			mov.l	@r0,r2;
	bf	intExitRestoreRegs

	/* if nested, just rte */
	stc	vbr,r1;			mov.l	IX_TaskIdCurrent,r5;
	mov.l	@(ARE_WE_NESTED,r1),r0;	mov.l	IX_ReadyQHead,r4;
	cmp/eq	#1,r0
	bf	intExitRestoreRegs

	/* LOCK INTERRUPTS */		/* if r7 is highest, don't reschedule */
	ldc	r2,sr;			mov.l	@r5,r7;
					mov.l	@r4,r6;
					cmp/eq	r7,r6
					bt	intExitRestoreRegs
	/* preemption locked? */
	mov	#WIND_TCB_LOCK_CNT,r0	/* is current task ready to run? */
	mov.l	@(r0,r7),r1;		mov	#WIND_TCB_STATUS,r0
	tst	r1,r1;			mov.l	@(r0,r7),r1;
	bt	saveIntContext;		tst	r1,r1	/* WIND_READY(0x00)? */
					bf	saveIntContext

intExitRestoreRegs:
	/* MD=1, RB=0, BL=0, IM=? */	lds.l	@sp+,macl
					lds.l	@sp+,mach
	mov.l	IX_IntBlockSR,r0;	mov.l	@sp+,r7
	mov.l	@r0,r0;			mov.l	@sp+,r6
					mov.l	@sp+,r5
	stc	vbr,r1;			mov.l	@sp+,r4
	add	#INT_EXIT_STUB,r1;	mov.l	@sp+,r3
	jmp	@r1;			mov.l	@sp+,r2

			.align	2
IX_IntLockSR:		.long	_intLockTaskSR
IX_TaskIdCurrent:	.long	_taskIdCurrent
IX_ReadyQHead:		.long	_readyQHead
IX_Errno:		.long	_errno
IX_IntCnt:		.long	_intCnt
IX_KernelState:		.long	_kernelState
IX_IntBlockSR:		.long	_intBlockSR
#ifdef	WV_INSTRUMENTATION
IX_EvtAction:		.long	_evtAction
#endif

/******************************************************************************
*
* saveIntContext (SH7750/SH7700)
*
* We are here if we have decided that rescheduling is a distinct possibility.
* The context must be gathered and stored in the current task's tcb.
*/
	.align	_ALIGN_TEXT
	.type	saveIntContext,@function
					/* r3: _intLockTaskSR  */
					/* r4: ReadyQHead     */
					/* r5: TaskIdCurrent  */
					/* r6: _readyQHead    */
					/* r7: _taskIdCurrent */
saveIntContext:
	/* interrupts are still locked out, and not nested */
	mov.l	SI_KernelState,r0;
	mov	#1,r1;			mov.w	SI_WINDTCB_MACL,r6;
	mov.l	r1,@r0;			add	r7,r6

	mov.l	@sp+,r0;
	mov.l	@sp+,r1;		mov.l	r0,@r6		/* save macl */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save mach */
	mov.l	@sp+,r1;		mov.l	r0,@-r6		/* save r7   */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save r6   */
	mov.l	@sp+,r1;		mov.l	r0,@-r6		/* save r5   */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save r4   */
	mov.l	@sp+,r1;		mov.l	r0,@-r6		/* save r3   */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save r2   */
	mov.l	@sp+,r1;		mov.l	r0,@-r6		/* save r1   */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save r0   */
	mov.l	@sp+,r1;/*spc*/		mov.l	r0,@-r6		/* save pr   */
	mov.l	@sp+,r0;/*ssr*/		add	#80,r6

	mov.l	@(4,sp),sp;/*task'sp*/	mov.l	r0,@r6		/* save ssr  */
					mov.l	r1,@-r6		/* save spc  */
	/* update areWeNested */
	stc	vbr,r2;			mov.l	sp,@-r6		/* save sp  */
	mov.l	@(ARE_WE_NESTED,r2),r1;	mov.l	SI_intUnlockSR,r0
	rotr	r1;			mov.l	@r0,r0
	mov.l	r1,@(ARE_WE_NESTED,r2);	ldc	r0,sr	/* UNLOCK INTERRUPTS */

	mov.l	r14,@-r6					/* save r14 */
	mov.l	r13,@-r6					/* save r13 */
	mov.l	r12,@-r6					/* save r12 */
	mov.l	r11,@-r6;		mov.l   SI_Errno,r3;	/* save r11 */
	mov.l	r10,@-r6;		mov.l   @r3,r1;		/* save r10 */
	mov.l	r9, @-r6;		mov  #WIND_TCB_ERRNO,r0	/* save r9  */
	mov.l	r8, @-r6;		extu.b  r0,r0		/* save r8  */

#ifndef	PORTABLE
	bra	_reschedule;		mov.l   r1,@(r0,r7)	/* save errno */
					/* r3: SI_Errno       */
					/* r4: ReadyQHead     */
					/* r5: TaskIdCurrent  */
					/* r6: (invalid)      */
					/* r7: _taskIdCurrent */
#else /* PORTABLE */
	mov.l	SI_Reschedule,r6
	jmp	@r6;			mov.l   r1,@(r0,r7)	/* save errno */

			.align	2
SI_Reschedule:		.long	_reschedule
#endif /* PORTABLE */

			.align	2
SI_KernelState:		.long	_kernelState
SI_Errno:		.long	_errno
SI_intUnlockSR:		.long	_intUnlockSR
SI_WINDTCB_MACL:	.word	WIND_TCB_MACL		/* see regsSh.h */

#elif (CPU==SH7600 || CPU==SH7000)
/******************************************************************************
*
* intExit - exit an interrupt service routine (SH7600/SH7000)
*
* Check the kernel ready queue to determine if resheduling is necessary.  If
* no higher priority task has been readied, and no kernel work has been queued,
* then we return to the interrupted task.
*
* If rescheduling is necessary, the context of the interrupted task is saved
* in its associated TCB with the PC, SR and SP retrieved from the exception
* frame on the interrupt stack.
*
* This routine must be branched to when exiting an interrupt service routine.
* This normally happens automatically, from the stub built by intConnect (2).
*
* This routine can NEVER be called from C.
*
* SEE ALSO: intConnect(2)

* void intExit ()

* INTERNAL
* This routine must preserve all registers up until the context is saved,
* so any registers that are used to check the queues must first be saved on
* the stack.
*/
	.align	_ALIGN_TEXT
	.type	_intExit,@function
					/* r1: _errno (poped @intConnectCode) */
_intExit:
	/* restore errno */
	mov.l	IX_Errno,r0;
	mov.l	r1,@r0

#ifdef	WV_INSTRUMENTATION
	mov.l	IX_EvtAction,r3;
	mov.l	@r3,r2;
	tst	r2,r2
	bf	intExitInstr		/* ==> intExitInstr */
intExitNoInstr:				/* <== intExitInstr */
#endif
					/* decrement intCnt */
					mov.l	IX_IntCnt,r2;
	/* save sr in r3 */		mov.l	@r2,r1;
	stc	sr,r3;			add	#-1,r1

	/* if in kernel, rte */
	mov.l	IX_KernelState,r0;	mov.l	r1,@r2
	mov.l	@r0,r1;			mov.l	IX_IntLockSR,r0;
	tst	r1,r1;			mov.l	@r0,r2;	/* r2: _intLockTaskSR */
	bf	intRte

	/* if nested, just rte */
	mov.l	IX_AreWeNested,r1;	mov.l	IX_TaskIdCurrent,r5;
	mov.l	@r1,r0;			mov.l	IX_ReadyQHead,r4;
	cmp/eq	#1,r0
	bf	intRte;

	/* LOCK INTERRUPTS */		/* if r7 is highest, don't reschedule */
	ldc	r2,sr;			mov.l	@r5,r7;
					mov.l	@r4,r6;
					cmp/eq	r7,r6
					bt	intRte
	/* preemption locked? */
	mov	#WIND_TCB_LOCK_CNT,r0	/* is current task ready to run? */
	mov.l	@(r0,r7),r1;		mov	#WIND_TCB_STATUS,r0
	tst	r1,r1;			mov.l	@(r0,r7),r1;
	bt	saveIntContext;		tst	r1,r1	/* WIND_READY(0x00)? */
					bf	saveIntContext

	/* r2: _intLockTaskSR,   r4: ReadyQHead,      r6: _readyQHead    */
	/* r3: saved sr,         r5: TaskIdCurrent,   r7: _taskIdCurrent */

	.type	intRte,@function

intRte:	ldc	r3,sr			/* UNLOCK INTERRUPTS */
	lds.l	@sp+,macl
	lds.l	@sp+,mach
	mov.l	@sp+,r7
	mov.l	@sp+,r6
	mov.l	@sp+,r5
	mov.l	@sp+,r4
	mov.l	@sp+,r3
	mov.l	IX_AreWeNested,r1;
	ldc	r2,sr			/* LOCK INTERRUPTS */
	mov.l	@r1,r0;
	rotr	r0
#if (CPU==SH7000)
	mov.l	r0,@r1
	bf	intRteNested
#else
	bf.s	intRteNested
	mov.l	r0,@r1			/* update areWeNested */
#endif
	mov.l	@sp,sp			/* return to task's stack */
intRteNested:
	mov.l	@sp+,r2
	mov.l	@sp+,r1
	mov.l	@sp+,r0
	lds.l	@sp+,pr
	rte;				/* UNLOCK INTERRUPTS */
	nop
			.align	2
IX_IntCnt:		.long	_intCnt
IX_IntLockSR:		.long	_intLockTaskSR
IX_ReadyQHead:		.long	_readyQHead
IX_TaskIdCurrent:	.long	_taskIdCurrent
IX_KernelState:		.long	_kernelState
IX_AreWeNested:		.long	_areWeNested
IX_Errno:		.long	_errno
#ifdef	WV_INSTRUMENTATION
IX_EvtAction:		.long	_evtAction
#endif

/******************************************************************************
*
* saveIntContext (SH7600/SH7000 version)
*
* We are here if we have decided that rescheduling is a distinct possibility.
* The context must be gathered and stored in the current task's tcb.
* The stored stack pointers must be modified to clean up the stacks (ISP, MSP).
*
* INTERNAL
*
*	     [ task's stack ]		   [ interrupt stack ]
*
*		|	|
*  +---------->	|_______| +8
*  |		|  sr	| +4
*  |	  sp ->	|_ pc __|  0
*  |	  ^	|  pr	|
*  |	  ^	|  r0	|
*  |	  ^	|  r1	|     vxIntStackBase -> |_______|
*  |	  ^	|  r2	| <--------------------	|task'sp|
*  |		|	|		  ^	|  r3	|
*  |		|	|		  ^	|  r4	|
*  |		|	|		  ^	|  r5	|
*  |		|	|		  ^	|  r6	|
*  |		|	|		  ^	|  r7	|
*  |		|	|		  ^	| mach	|
*  |		|	|		  sp ->	| macl	|
*  |		|	|			|	|
*  |
*  |					_________________
*  |		WIND_TCB_SR	0x17c	|      sr	| +80
*  |		WIND_TCB_PC	0x178	|      pc	| +76
*  +-----------	WIND_TCB_R15	0x174	|    sp + 8	| +72
*		WIND_TCB_R14	0x170	|      r14	| +68
*		WIND_TCB_R13	0x16c	|      r13	| +64
*		WIND_TCB_R12	0x168	|      r12	| +60
*		WIND_TCB_R11	0x164	|      r11	| +56
*		WIND_TCB_R10	0x160	|      r10	| +52
*		WIND_TCB_R9	0x15c	|      r9	| +48
*		WIND_TCB_R8	0x158	|      r8	| +44
*	r2 ->	WIND_TCB_MACL	0x154	|     macl	| +40
*		WIND_TCB_MACH	0x150	|     mach	| +36
*		WIND_TCB_R7	0x14c	|      r7	| +32
*		WIND_TCB_R6	0x148	|      r6	| +28
*		WIND_TCB_R5	0x144	|      r5	| +24
*		WIND_TCB_R4	0x140	|      r4	| +20
*		WIND_TCB_R3	0x13c	|      r3	| +16
*		WIND_TCB_R2	0x138	|      r2	| +12
*		WIND_TCB_R1	0x134	|      r1	| +8
*		WIND_TCB_R0	0x130	|      r0	| +4
*		WIND_TCB_PR	0x12c	|      pr	| +0
*		WIND_TCB_GBR	0x128	|		|
*		WIND_TCB_VBR	0x124	|		|	(regsSh.h)
*					|		|
*		WIND_TCB_REGS	0x124	|_______________|	(taskLibP.h)
*				0x120	|_____ sr ______|
*				0x11c	|_____ pc ______|
*		EXC_INFO	0x118	|_valid_|_vecNum|	(excShLib.h)
*					|		|
*		WIND_TCB_ERRNO		|    _errno	|
*					|		|
*	r7 ->	WIND_TCB	0x0	|_______________|	(taskLib.h)
*/
	.align	_ALIGN_TEXT
	.type	saveIntContext,@function
					/* r2: _intLockTaskSR */
					/* r3: saved sr       */
					/* r4: ReadyQHead     */
					/* r5: TaskIdCurrent  */
					/* r6: _readyQHead    */
					/* r7: _taskIdCurrent */
saveIntContext:
	/* interrupts are still locked out, and not nested */
	mov.l	SI_KernelState,r0;
	mov	#1,r1;			mov.w	SI_WINDTCB_MACL,r6;
	mov.l	r1,@r0;			add	r7,r6

	ldc	r3,sr			/* UNLOCK INTERRUPTS */

	mov.l	@sp+,r0
	mov.l	@sp+,r1;		mov.l	r0,@r6		/* save macl */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save mach */
	mov.l	@sp+,r1;		mov.l	r0,@-r6		/* save r7   */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save r6   */
	mov.l	@sp+,r1;		mov.l	r0,@-r6		/* save r5   */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save r4   */
					mov.l	r0,@-r6		/* save r3   */
	mov.l	SI_AreWeNested,r1;
	ldc	r2,sr			/* LOCK INTERRUPTS */
	mov.l	@r1,r0;
	mov.l	@sp,sp;			/* return to task's stack */
	rotr	r0
	mov.l	r0,@r1			/* update areWeNested */
	ldc	r3,sr			/* UNLOCK INTERRUPTS  */

	mov.l	@sp+,r1;
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save r2 */
	mov.l	@sp+,r1;		mov.l	r0,@-r6		/* save r1 */
	mov.l	@sp+,r0;		mov.l	r1,@-r6		/* save r0 */
					mov.l	r0,@-r6		/* save pr */
	xor	r0,r0
	ldc	r0,sr			/* UNLOCK INTERRUPTS */

	mov.l	@(4,sp),r1;		add	#80,r6
	mov.l	@sp,r0;			mov.l	r1,@r6		/* save sr */
					mov.l	r0,@-r6		/* save pc */

	mov	sp, r0			/* keep sp untouched */
	add	#8, r0			/* adjust sp to be saved in tcb */
	mov.l	r0, @-r6					/* save sp  */
	mov.l	r14,@-r6					/* save r14 */
	mov.l	r13,@-r6					/* save r13 */
	mov.l	r12,@-r6					/* save r12 */
	mov.l	r11,@-r6;		mov.l   SI_Errno,r3;	/* save r11 */
	mov.l	r10,@-r6;		mov.l   @r3,r1;		/* save r10 */
	mov.l	r9, @-r6;		mov  #WIND_TCB_ERRNO,r0	/* save r9  */
	mov.l	r8, @-r6;		extu.b  r0,r0		/* save r8  */

#ifndef	PORTABLE
	bra	_reschedule;		mov.l   r1,@(r0,r7)	/* save errno */
					/* r3: Errno          */
					/* r4: ReadyQHead     */
					/* r5: TaskIdCurrent  */
					/* r6: (invalid)      */
					/* r7: _taskIdCurrent */
#else	/* PORTABLE */
	mov.l	SI_Reschedule,r6
	jmp	@r6;			mov.l   r1,@(r0,r7)	/* save errno */

			.align	2
SI_Reschedule:		.long	_reschedule
#endif	/* PORTABLE */

			.align	2
SI_KernelState:		.long	_kernelState
SI_AreWeNested:		.long	_areWeNested
SI_Errno:		.long	_errno
SI_WINDTCB_MACL:	.word	WIND_TCB_MACL		/* TCB offset */

#endif /* CPU==SH7600 || CPU==SH7000 */

#ifdef	WV_INSTRUMENTATION
/******************************************************************************
*
* noDispatchInstr - windview instrumentation: exit windExit with NO dispatch
*
*/
	.align	_ALIGN_TEXT
	.type	noDispatchInstr,@function

noDispatchInstr:
	mov.l	NDI_TaskIdCurrent,r1;			mov.l	r8,@-sp
	mov	#WIND_TCB_PRIORITY,r0;			mov.l	r9,@-sp
	mov.l	@r1,r8;		/* r8: taskID */	sts.l	pr,@-sp
	mov.l	@(r0,r8),r9;	/* r9: priority */	

	/* check if we need to log this event */
	mov.l	NDI_WvEvtClass,r1;
	mov.l	NDI_WV_CLASS_1_ON,r3;
	mov.l	@r1,r0;
	and	r3,r0
	cmp/eq	r3,r0
	bf	noDispatchCheckTrg
	
	/* Here we try to determine if the task is running at an
	 * inherited priority, if so a different event is generated.
	 */
	mov	#WIND_TCB_PRI_NORMAL,r0
	mov.l	@(r0,r8),r1;
	mov	#EVENT_WIND_EXIT_NODISPATCH,r4
	cmp/ge	r1,r9				/* normalPriority <= priority */
	bt	noDispatchEvtLog		/* no inheritance */
	mov	#EVENT_WIND_EXIT_NODISPATCH_PI,r4
noDispatchEvtLog:				/* r4: event ID */
	mov.l	NDI_EvtLogTSched,r1;
	mov.l	@r1,r0;	mov	r9,r6	/*                 r4      r5   r6   */
	jsr	@r0;	mov	r8,r5	/* evtLogTSched (eventID,taskID,pri) */

noDispatchCheckTrg:
	mov.l	NDI_TrgEvtClass,r1;
	mov.l	NDI_TRG_CLASS_1_ON,r3;
	mov.l	@r1,r0;			mov	#0,r2	/* r2: NULL */
	and	r3,r0
	cmp/eq	r3,r0
	bf	noDispatchInstDone

	mov	#WIND_TCB_PRI_NORMAL,r0
	mov.l	@(r0,r8),r1;
	mov	#EVENT_WIND_EXIT_NODISPATCH,r4
	cmp/ge	r1,r9				/* normalPriority <= priority */
	bt	noDispatchEvalTrg		/* no inheritance */
	mov	#EVENT_WIND_EXIT_NODISPATCH_PI,r4
noDispatchEvalTrg:				/* r4: event ID */

	/*             r4     r5     r6     r7     +0 +4 +8 +12 */
	/* trgCheck (eventID,index,taskID,priority, 0, 0, 0, 0) */

	mov.l	r2,@-sp;		mov.l	r2,@-sp
	mov.l	r2,@-sp;		mov.l	r2,@-sp
	mov.l	NDI_TrgCheck,r1;	mov	r9,r7
	mov.l	@r1,r0;			mov	r8,r6
	jsr	@r0;			mov	#TRG_CLASS1_INDEX,r5
					add	#16,sp	/* pop params */
noDispatchInstDone:
							lds.l	@sp+,pr
							mov.l	@sp+,r9
							rts;
							mov.l	@sp+,r8
			.align	2
NDI_TaskIdCurrent:	.long	_taskIdCurrent
NDI_WvEvtClass:		.long	_wvEvtClass
NDI_WV_CLASS_1_ON:	.long   WV_CLASS_1_ON
NDI_EvtLogTSched:	.long	__func_evtLogTSched
NDI_TrgEvtClass:	.long	_trgEvtClass
NDI_TRG_CLASS_1_ON:	.long	TRG_CLASS_1_ON
NDI_TrgCheck:		.long	__func_trgCheck

#ifndef	PORTABLE
/******************************************************************************
*
* dispatchInstr - windview instrumentation: exit windExit with dispatch
*
*/
	.align	_ALIGN_TEXT
	.type	dispatchInstr,@function

dispatchInstr:
	mov.l	DII_TaskIdCurrent,r12;			mov.l	r0,@-sp
	mov	#WIND_TCB_PRIORITY,r0;			mov.l	r1,@-sp
	mov.l	@r12,r11;	/* r11: task ID */	mov.l	r2,@-sp
	mov.l	@(r0,r11),r12;	/* r12: priority */	mov.l	r3,@-sp
							mov.l	r4,@-sp
	/* check if we need to log this event */
	mov.l	DII_WvEvtClass,r1;			mov.l	r5,@-sp
	mov.l	DII_WV_CLASS_1_ON,r3;			mov.l	r6,@-sp
	mov.l	@r1,r0;					mov.l	r7,@-sp   
	and	r3,r0;					sts.l	pr,@-sp
	cmp/eq	r3,r0
	bf	dispatchCheckTrg
	
	/* Here we try to determine if the task is running at an
	 * inherited priority, if so a different event is generated.
	 */
	mov	#WIND_TCB_PRI_NORMAL,r0
	mov.l	@(r0,r11),r1;
	mov	#EVENT_WIND_EXIT_DISPATCH,r4
	cmp/ge	r1,r12				/* normalPriority <= priority */
	bt	dispatchEvtLog			/* no inheritance	*/
	mov	#EVENT_WIND_EXIT_DISPATCH_PI,r4
dispatchEvtLog:					/* r4: event ID */
	mov.l	DII_EvtLogTSched,r1;
	mov.l	@r1,r0;	mov	r12,r6	/*                 r4      r5   r6   */
	jsr	@r0;	mov	r11,r5	/* evtLogTSched (eventID,taskID,pri) */

dispatchCheckTrg:
	/* check if we need to evaluate trigger for this event */

	mov.l	DII_TrgEvtClass,r1;
	mov.l	DII_TRG_CLASS_1_ON,r3;
	mov.l	@r1,r0;			mov	#0,r2	/* r2: NULL */
	and	r3,r0
	cmp/eq	r3,r0
	bf	dispatchInstDone

	mov	#WIND_TCB_PRI_NORMAL,r0
	mov.l	@(r0,r11),r1;
	mov	#EVENT_WIND_EXIT_DISPATCH,r4
	cmp/ge	r1,r12				/* normalPriority <= priority */
	bt	dispatchEvalTrg			/* no inheritance */
	mov	#EVENT_WIND_EXIT_DISPATCH_PI,r4
dispatchEvalTrg:				/* r4: event ID */

	/*             r4     r5     r6      r7    +0 +4 +8 +12 */
	/* trgCheck (eventID,index,taskID,priority, 0, 0, 0, 0) */

	mov.l	r2,@-sp;		mov.l	r2,@-sp
	mov.l	r2,@-sp;		mov.l	r2,@-sp
	mov.l	DII_TrgCheck,r1;	mov	r12,r7
	mov.l	@r1,r0;			mov	r11,r6
	jsr	@r0;			mov	#TRG_CLASS1_INDEX,r5
					add	#16,sp	/* pop params */
dispatchInstDone:
							lds.l	@sp+,pr
							mov.l	@sp+,r7
							mov.l	@sp+,r6
							mov.l	@sp+,r5	
							mov.l	@sp+,r4
							mov.l	@sp+,r3
							mov.l	@sp+,r2
							mov.l	@sp+,r1
	bra	dispatchNoInstr;			mov.l	@sp+,r0

			.align	2
DII_TaskIdCurrent:	.long	_taskIdCurrent
DII_WvEvtClass:		.long	_wvEvtClass
DII_WV_CLASS_1_ON:	.long   WV_CLASS_1_ON
DII_EvtLogTSched:	.long	__func_evtLogTSched
DII_TrgEvtClass:	.long	_trgEvtClass
DII_TRG_CLASS_1_ON:	.long	TRG_CLASS_1_ON
DII_TrgCheck:		.long	__func_trgCheck

/******************************************************************************
*
* idleInstr - windview instrumentation: enter idle state
*
*/
	.align	_ALIGN_TEXT
	.type	idleInstr,@function

idleInstr:
	mov.l	ILI_IntLockSR,r1;	sts.l	pr,@-sp
	mov.l	@r1,r0;
	ldc	r0,sr;	/* LOCK INTERRUPTS */

	/* check if we need to log this event */

	mov.l	ILI_WvEvtClass,r1;
	mov.l	ILI_WV_CLASS_1_ON,r3;
	mov.l	@r1,r0;
	and	r3,r0
	cmp/eq	r3,r0
	bf	idleCheckTrg

	mov.l	ILI_EvtLogT0,r1;
	mov.l	@r1,r0;
	jsr	@r0;	/* evtLogT0 (eventID) */
	mov	#EVENT_WIND_EXIT_IDLE,r4

idleCheckTrg:
	/* check if we need to evaluate trigger for this event */

	mov.l	ILI_TrgEvtClass,r1;
	mov.l	ILI_TRG_CLASS_1_ON,r3;
	mov.l	@r1,r0;			mov	#0,r7	/* r7: NULL */
	and	r3,r0
	cmp/eq	r3,r0
	bf	idleInstDone
	
	/*             r4     r5   r6 r7 +0 +4 +8 +12 */
	/* trgCheck (eventID,index, 0, 0, 0, 0, 0, 0) */

	mov.l	r7,@-sp;		mov.l	r7,@-sp
	mov.l	r7,@-sp;		mov.l	r7,@-sp
	mov.l	ILI_TrgCheck,r1;	mov	r7,r6
	mov.l	@r1,r0;			mov	#TRG_CLASS1_INDEX,r5
	jsr	@r0;			mov	#EVENT_WIND_EXIT_IDLE,r4
					add	#16,sp	/* pop params */
idleInstDone:
	bra	idleNoInstr;		lds.l	@sp+,pr

			.align	2
ILI_IntLockSR:		.long	_intLockTaskSR
ILI_WvEvtClass:		.long	_wvEvtClass
ILI_WV_CLASS_1_ON:	.long   WV_CLASS_1_ON		/* 0x10000001 */
ILI_EvtLogT0:		.long	__func_evtLogT0
ILI_TrgEvtClass:	.long	_trgEvtClass
ILI_TRG_CLASS_1_ON:	.long	TRG_CLASS_1_ON		/* 0x10000001 */
ILI_TrgCheck:		.long	__func_trgCheck
#endif	/* !PORTABLE */
#endif	/* WV_INSTRUMENTATION */

/******************************************************************************
*
* windExitInt - exit kernel routine from interrupt level
*
* windExit branches here if exiting kernel routine from int level.
* No rescheduling is necessary because the ISR will exit via intExit, and
* intExit does the necessary rescheduling.  Before leaving kernel state
* the work queue is emptied.
*/
	.align	_ALIGN_TEXT
	.type	windExitIntWork,@function
	.type	windExitInt,@function

windExitIntWork:				/*     windExitIntWork (r2) */
	mov.l	WXI_WorkQDoWork,r1;
	sts.l	pr,@-sp
#if	(CPU==SH7600 || CPU==SH7000)
	jsr	@r1;
	ldc	r2,sr
#else
	ldc	r2,sr;				/* UNLOCK INTERRUPTS        */
	jsr	@r1;				/*     empty the work queue */
	nop
#endif
	lds.l	@sp+,pr

windExitInt:					/*     windExitInt (void)   */
	mov.l	WXI_IntLockSR,r4;
	mov.l	WXI_WorkQIsEmpty,r5;
	mov.l	@r4,r1;
	stc	sr,r2				/* r2: old sr      */
	ldc	r1,sr				/* LOCK INTERRUPTS */

	mov.l	@r5,r1;				/* r1: _workQIsEmpty          */
	tst	r1,r1				/*     test for work to do    */
	bt 	windExitIntWork			/*     workQueue is not empty */

#ifdef	WV_INSTRUMENTATION
	mov.l	WXI_EvtAction,r1;		
	mov.l	@r1,r0;
	tst	r0,r0
	bt	windExitIntNoInstr;
	sts.l	pr,@-sp
	bsr	noDispatchInstr;
	mov.l	r2,@-sp
	mov.l	@sp+,r2
	lds.l	@sp+,pr
windExitIntNoInstr:
#endif
	mov.l	WXI_KernelState,r6;
	xor	r0,r0				/* r0: NULL                 */
	mov.l	r0,@r6				/*     release exclusion    */
#if	(CPU==SH7600 || CPU==SH7000)
	rts;
	ldc	r2,sr
#else
	ldc	r2,sr				/* UNLOCK INTERRUPTS        */
	rts;					/*     back to calling task */
	nop					/*     return 0 (r0)        */
#endif
			.align	2
WXI_WorkQDoWork:	.long	_workQDoWork
WXI_IntLockSR:		.long	_intLockTaskSR
WXI_WorkQIsEmpty:	.long	_workQIsEmpty
WXI_KernelState:	.long	_kernelState
#ifdef	WV_INSTRUMENTATION
WXI_EvtAction:		.long	_evtAction
#endif

/******************************************************************************
*
* checkTaskReady - check that taskIdCurrent is ready to run
*
* This code branched to by windExit when it finds preemption is disabled.
* It is possible that even though preemption is disabled, a context switch
* must occur.  This situation arrises when a task block during a preemption
* lock.  So this routine checks if taskIdCurrent is ready to run, if not it
* branches to save the context of taskIdCurrent, otherwise it falls thru to
* check the work queue for any pending work. The h/private/taskLibP.h defines
* WIND_TCB_STATUS as 0x3c, and WIND_READY as 0x00.
*/
	.align	_ALIGN_TEXT
	.type	checkTaskReady,@function
					/* r4: ReadyQHead     */
					/* r5: TaskIdCurrent  */
					/* r6: _readyQHead    */
checkTaskReady:				/* r7: _taskIdCurrent */
	mov	#WIND_TCB_STATUS,r0
	mov.l	@(r0,r7),r1;
	tst	r1,r1			/* is task ready to run? */
	bf	saveTaskContext		/* if no, we blocked with preempt off */

	/* FALL THRU TO CHECK WORK QUEUE */

/******************************************************************************
*
* checkWorkQ -	check the work queue for any work to do
*
* This code is branched to by windExit.  Currently taskIdCurrent is highest
* priority ready task, but before we can return to it we must check the work
* queue.  If there is work we empty it via doWorkPreSave, otherwise we unlock
* interrupts, clear r0, and return to taskIdCurrent.
*/
	.type	checkWorkQ,@function
					/* r4: ReadyQHead     */
					/* r5: TaskIdCurrent  */
					/* r6: _readyQHead    */
checkWorkQ:				/* r7: _taskIdCurrent */
	mov.l	CQ_IntLockSR,r2;	/* r2: IntLockSR  */
	mov.l	CQ_WorkQIsEmpty,r3;	/* r3: WorkQIsEmpty   */
	mov.l	@r2,r1;
	ldc	r1,sr			/* LOCK INTERRUPTS */

	mov.l	@r3,r1;
	tst	r1,r1			/*     test for work to do */
	bt 	doWorkPreSave		/*     workQueue is not empty */

#ifdef	WV_INSTRUMENTATION
	mov.l	CQ_EvtAction,r1; 
	mov.l	@r1,r0;
	tst	r0,r0
	bt	checkWorkQNoInstr
	sts.l	pr,@-sp
	bsr	noDispatchInstr;
	nop
	lds.l	@sp+,pr
checkWorkQNoInstr:
#endif

#if (CPU==SH7600 || CPU==SH7000)
	mov.l	CQ_KernelState,r1;
	xor	r0,r0			/* r0: zero */
	mov.l	r0,@r1			/* release exclusion */
	rts;				/* back to calling task (return 0) */
	ldc	r0,sr			/* UNLOCK INTERRUPTS */

#else /* CPU==SH7750 || CPU==SH7700 */
	mov.l	CQ_KernelState,r1;	mov.l	CQ_intUnlockSR,r3
	xor	r0,r0;			mov.l	@r3,r2
	mov.l	r0,@r1;			ldc	r2,sr
	rts;	/* return 0 */		nop

			.align	2
CQ_intUnlockSR:		.long	_intUnlockSR

#endif /* CPU==SH7750 || CPU==SH7700 */

			.align	2
CQ_IntLockSR:		.long	_intLockTaskSR
CQ_WorkQIsEmpty:	.long	_workQIsEmpty
CQ_KernelState:		.long	_kernelState
#ifdef	WV_INSTRUMENTATION
CQ_EvtAction:		.long	_evtAction
#endif

/******************************************************************************
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
	.align	_ALIGN_TEXT
	.type	doWorkPreSave,@function
					/* r7: _taskIdCurrent */
					/* r6: _readyQHead    */
					/* r5: TaskIdCurrent  */
					/* r4: ReadyQHead     */
					/* r3: WorkQIsEmpty   */
					/* r2: IntLockSR  */
doWorkPreSave:				/* r1: NULL (to unlock interrupts) */
#if (CPU==SH7600 || CPU==SH7000)
	mov.l	PS_WorkQDoWork,r0;
	sts.l	pr,@-sp
	jsr	@r0;			/* empty the work queue */
	ldc	r1,sr			/* UNLOCK INTERRUPTS */
#else
					mov.l	PS_intUnlockSR,r2
	mov.l	PS_WorkQDoWork,r0;	mov.l	@r2,r1
	sts.l	pr,@-sp;		ldc	r1,sr
	jsr	@r0;			nop
#endif
	bra 	checkTaskSwitch;	/* back up to test if tasks switched */
	lds.l	@sp+,pr			/* r0-r7: (invalid) */

			.align	2
PS_WorkQDoWork:		.long	_workQDoWork	/* void workQDoWork (void) */
#if (CPU!=SH7600 && CPU!=SH7000)
PS_intUnlockSR:		.long	_intUnlockSR
#endif

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
* this routine.  This is simply done by saving PR as PC, thus the context saved
* is as if this routine was never called.  The PR itself will be poped from the
* stack, as shown in the diagram below.  Only the volatile registers r0..r7 are
* safe to use until the context is saved in saveTaskContext.
*
* RETURNS: OK or ERROR if semaphore timeout occurs.
*
* NOMANUAL

* STATUS windExit ()

* INTERNAL
*				|
*  ex.  semDelete ()		|	r0 - r7: free to use
*	    {			|	mac[hl]: free to use
*	    push pr		|
*	    jsr  semDestroy	|	r8 - r14: must be saved before use.
*	        {		|
*		push pr		|	sp: points at pr value on the stack.
*		call windExit	|	    this pr value is the semDestroy
*	    $1:	pop  pr		|	    return address, namely $2.
*		rts		|
*	        }		|	pr: holds the windExit return address,
*	$2: pop  pr		|	    namely $1.
*	    rts			|
*	    }			|	vbr,gbr: doesn't matter.
*		+-------+	|
*	  sp->	|  $2	|	|
*				|
*	    pr	[  $1	]	|
*/
	.align	_ALIGN_TEXT
	.type	_windExit,@function

_windExit:				/* STATUS windExit (void); */
	mov.l	WX_IntCnt,r1;
	mov.l	@r1,r0;
	tst	r0,r0			/* if intCnt == 0 we're from task */
	bf 	windExitInt		/* else we're exiting interrupt code */

	/* FALL THRU TO CHECK THAT CURRENT TASK IS STILL HIGHEST */

/******************************************************************************
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
	.type	checkTaskSwitch,@function

checkTaskSwitch:			/* r0-r7: (invalid)   */
	mov.l	WX_TaskIdCurrent,r5;	/* r5: TaskIdCurrent  */
	mov.l	WX_ReadyQHead,r4;	/* r4: ReadyQHead     */
	mov.l	@r5,r7;			/* r7: _taskIdCurrent */
	mov.l	@r4,r6;			/* r6: _readyQHead    */
	cmp/eq	r7,r6			/* compare highest ready task     */
	bt	checkWorkQ		/* if same then time to leave (^) */

	mov	#WIND_TCB_LOCK_CNT,r0
	mov.l	@(r0,r7),r1;
	tst	r1,r1			/* is task preemption allowed     */
	bf	checkTaskReady		/* if no, check task is ready (^) */

	/* FALL THRU TO SAVE THE CURRENT TASK CONTEXT IN TCB */

/******************************************************************************
*
* saveTaskContext - save the current task context
*
* We arrive at this code either as the result of falling thru from checkTask-
* Switch, or if taskIdCurrent is not ready at checkTaskReady.  Save all the
* non-volatile registers and errno in TCB, then call-out the rescheduler.
*
* INTERNAL
*
*	r1 = 0				_________________
*	r2 ->	WIND_TCB_SR	0x17c	|     sr (=0)	|	 0
*	 v	WIND_TCB_PC	0x178	|     pc (=pr)	|	-4
*	 v	WIND_TCB_R15	0x174	|     sp	|	-8
*	 v	WIND_TCB_R14	0x170	|     r14	|	-12
*	 v	WIND_TCB_R13	0x16c	|     r13	|	-16
*	 v	WIND_TCB_R12	0x168	|     r12	|	-20
*	 v	WIND_TCB_R11	0x164	|     r11	|	-24
*	 v	WIND_TCB_R10	0x160	|     r10	|	-28
*	 v	WIND_TCB_R9	0x15c	|     r9	|	-32
*	r2 ->	WIND_TCB_R8	0x158	|     r8	|  0	-36
*		WIND_TCB_MACL	0x154	|		| -4	-40
*		WIND_TCB_MACH	0x150	|		| -8	-44
*		WIND_TCB_R7	0x14c	|		| -12	-48
*		WIND_TCB_R6	0x148	|		| -16	-52
*		WIND_TCB_R5	0x144	|		| -20	-56
*		WIND_TCB_R4	0x140	|		| -24	-60
*		WIND_TCB_R3	0x13c	|		| -28	-64
*		WIND_TCB_R2	0x138	|		| -32	-68
*		WIND_TCB_R1	0x134	|		| -36	-72
*		WIND_TCB_R0	0x130	|     r0 (=0)	|	-76
*		WIND_TCB_PR	0x12c	|		|	-80
*		WIND_TCB_GBR	0x128	|		|
*		WIND_TCB_VBR	0x124	|		|	(regsSh.h)
*					|		|
*		WIND_TCB_REGS	0x124	|_______________|	(taskLibP.h)
*				0x120	|_____ sr ______|
*				0x11c	|_____ pc ______|
*		EXC_INFO	0x118	|_valid_|_vecNum|	(excShLib.h)
*					|		|
*		WIND_TCB_ERRNO		|    _errno	|
*					|		|
*	r7 ->	WIND_TCB	0x0	|_______________|	(taskLib.h)
*/
	.type	saveTaskContext,@function
						/* r4: ReadyQHead     */
						/* r5: TaskIdCurrent  */
						/* r6: _readyQHead    */
						/* r7: _taskIdCurrent */
saveTaskContext:
	mov.l	WX_WINDTCB_SR,r2;		/* get TCB_SR offset in r2    */
	mov.l	WX_Errno,r3;			/* fetch errno address        */
	add	r7,r2				/* add taskIdCurrent          */
	mov.l	@r3,r1;				/* get errno                  */
	mov	#WIND_TCB_ERRNO,r0		/* get TCB offset             */

#if	(CPU==SH7600 || CPU==SH7000)
	extu.b	r0,r0
	mov.l	r1,@(r0,r7)			/* save errno in tcb          */
	xor	r6,r6				/* use this zero twice        */
	mov.l	r6,@r2				/* save a brand new SR (zero) */
#else
	mov.l	WX_intUnlockSR,r6;		/* IL_ unavailable if portable*/
	extu.b	r0,r0
	mov.l	@r6,r6;
	mov.l	r1,@(r0,r7)
	mov.l	r6,@r2				/* save a brand new SR        */
	xor	r6,r6
#endif
	sts.l	pr,  @-r2			/* save return address as PC  */
	mov.l	sp,  @-r2			/* save r15                   */
	mov.l	r14, @-r2			/* save r14                   */
	mov.l	r13, @-r2			/* save r13                   */
	mov.l	r12, @-r2			/* save r12                   */
	mov.l	r11, @-r2			/* save r11                   */
	mov.l	r10, @-r2			/* save r10                   */
	mov.l	r9,  @-r2			/* save r9                    */
	mov.l	r8,  @-r2			/* save r8                    */
	add	#-36,r2				/* mac[lh],r1-r7 are volatile */
	mov.l	r6,  @-r2			/* clear saved r0 for return  */
/*	sts.l	pr,  @-r2			/@ Not necessary              */

						/* r3: Errno          */
						/* r4: ReadyQHead     */
						/* r5: TaskIdCurrent  */
						/* r6: 0              */
						/* r7: _taskIdCurrent */
#ifdef PORTABLE
	mov.l	WX_Reschedule,r0;		/* void reschedule (void)     */
	jsr	@r0;				/* goto rescheduler           */
	nop					/* should never return!       */

		.align	2
WX_Reschedule:	.long	_reschedule
#else	/* !PORTABLE */

	/* FALL THRU TO RESCHEDULE */

/******************************************************************************
*
* reschedule - rescheduler for VxWorks kernel
*
* This routine is called when either intExit, or windExit, thinks the
* context might change.  All of the contexts of all of the tasks are
* accurately stored in the task control blocks when entering this function.
* The STORED status register is 0x40000000 for SH7750/SH7700,
* 0x00000000 for SH7600/SH7000. (Interrupts UNLOCKED)
*
* At the conclusion of this routine, taskIdCurrent will equal the highest
* priority task eligible to run, and the kernel work queue will be empty.
* If a context switch to a different task is to occur, then the installed
* switch hooks are called.
*
* NOMANUAL

* void reschedule ()

* INTERNAL
*
*     _________        ___________________                  _reschedule
*    /         \      /                   \                      |
*   |           v    v                     |                     |
*   |           doWork <==> workQDoWork()  |      taskIdPrevious = taskIdCurrent
*   |              |                       |                     |
*   |              v                       |                     v
*   |  +----------------------+            ^           +----------------------+
*   |  | readyQHead != NULL ? |-(No)---> idle <---(No)-| readyQHead != NULL ? |
*   |  +----------------------+                        +----------------------+
*   |              |(Yes)                                        |(Yes)
*   |              |                                             |
*   |              v                                             |
*   |   +--------------------------------+                       |
*   |   | readyQHead == taskIdPrevious ? |-(No)------------+     |
*   |   +--------------------------------+                 |     |
*   |              |(Yes)                          taskIdCurrent = readyQHead
*   |              |                                       |     |
*   |              |                                       v     v
*   |              |                                     switchTasks
*   |               \                                        /
*   |                \___________           ________________/
*   |                            \         /     /     /
*   |                             \       /     /     /
*   |                              |     |     |   doSwapHooks <==> C(r4,r5)
*   |     r8:  ReadyQHead          |     |     |     |      \____________
*   |     r9:  TaskIdCurrent       |     |     v     v                   \
*   |     r10:                     |     |   doSwitchHooks <==> C(r4,r5)  |
*   |     r11: WorkQIsEmpty        |     |    /  ________________________/
*   |     r12:                      \    |   /  /
*   |     r13: taskIdPrevious        \   |  /  /
*   |     r14: taskIdCurrent          \  | |  /
*   |                                  | | | |
*   |                                  v v v v
*   |                                 dispatch
*   |                                     |
*   |                      taskIdPrevious = taskIdCurrent
*    \                                    |
*     \                                  / \
*      `------ doWorkUnlock <-----------'   `-----------------> rte
*/
	/*   |                          */
	/* (saveTaskContext)            */	/* r3: Errno          */
	/*   |                          */	/* r4: ReadyQHead     */
	/*   |   +---- saveIntContext   */	/* r5: TaskIdCurrent  */
	/*   |   |                      */	/* r6: (invalid)      */
	/*   V   V                      */	/* r7: _taskIdCurrent */

	.type	_reschedule,@function

_reschedule:
	mov	r4,r8
	mov	r5,r9
	mov.l	@r8,r14;
	mov	r7,r13			/* taskIdPrevious = taskIdCurrent */
	mov.l	WX_WorkQIsEmpty,r11;
	tst     r14,r14
	bt	idle;			/* idle if nobody ready */

	mov.l	r14,@r9			/* taskIdCurrent = readyQHead */

	/*   |                          */	/* r14: _readyQHead     */
	/*   |                          */	/* r13: _taskIdPrevious */
	/*   |                          */	/* r12:                 */
	/*   |                          */	/* r11: WorkQIsEmpty    */
	/*   |                          */	/* r10:                 */
	/*   |   +---- doWork           */	/* r9:  TaskIdCurrent   */
	/*   |   |                      */	/* r8:  ReadyQHead      */
	/*   V   V                      */	/* r0-r7: (don't care)  */
	.type	switchTasks,@function

switchTasks:
	mov	#WIND_TCB_SWAP_IN,r0
	mov.w	@(r0,r14),r12;
	mov	#WIND_TCB_SWAP_OUT,r0
	mov.w	@(r0,r13),r0;
	or	r0,r12
	extu.w	r12,r12				/* r12: swap hook mask */
	tst     r12,r12
	bf	doSwapHooks			/* any swap hooks to do */

	mov.l   WX_TaskSwitchTable,r10;
	mov.l	@r10,r6;
	tst	r6,r6				/* r6: _taskSwitchTable */
	bf	doSwitchHooks

	/*   |                          */	/* r14: _taskIdCurrent  */
	/*   |   +-- doSwapHooks        */	/* r13: _taskIdPrevious */
	/*   |   |                      */	/* r12:                 */
	/*   |   |   +-- doSwitchHooks  */	/* r11: WorkQIsEmpty    */
	/*   |   |   |                  */	/* r10:                 */
	/*   |   |   |   +-- doWork     */	/* r9:  TaskIdCurrent   */
	/*   |   |   |   |              */	/* r8:  ReadyQHead      */
	/*   V   V   V   V              */	/* r0-r7: (don't care)  */
	.type	dispatch,@function

#if (CPU==SH7750 || CPU==SH7700)

dispatch:
	/* taskIdPrevious = taskIdCurrent */
	mov	r14,r13
					mov	#WIND_TCB_ERRNO,r0
					extu.b	r0,r0
					mov.l	@(r0,r14),r2
	mov.l	DI_WINDTCB_PR,r1;	mov.l	WX_Errno,r3
	add	r1,r14;			mov.l	r2,@r3	/* restore errno */

	/* load register set */
	lds.l	@r14+,pr
	mov.l	@r14+,r0
	mov.l	@r14+,r1
	mov.l	@r14+,r2
	mov.l	@r14+,r3
	mov.l	@r14+,r4
	mov.l	@r14+,r5
	mov.l	@r14+,r6
	mov.l	@r14+,r7
	lds.l	@r14+,mach		/* LOCK INTERRUPTS */
	lds.l	@r14+,macl;		mov.l	DI_IntLockSR,r12
	mov.l	@r14+,r8;		mov.l	@r12,r12
	mov.l	@r14+,r9;		ldc	r12,sr
					/* is work q empty? */
					mov.l	@r11,r12
	mov.l	@r14+,r10;		tst	r12,r12
					bt	doWorkUnlock /* r8,r9: broken */
#ifdef	WV_INSTRUMENTATION
	mov.l	DI_EvtAction,r11
	mov.l	@r11,r12
	tst	r12,r12
	bt	dispatchNoInstr
	bra	dispatchInstr;		/* ==> dispatchInstr */
	nop
		.align	2
DI_EvtAction:	.long	_evtAction
dispatchNoInstr:			/* <== dispatchInstr */
#endif	/*WV_INSTRUMENTATION*/
					/* release kernel mutex */
	stc	vbr,r11;		mov.l	DI_KernelState,r13
	add	#DISPATCH_STUB,r11;	mov	#0,r12
	jmp	@r11;			mov.l	r12,@r13

			.align	2
DI_WINDTCB_PR:		.long	WIND_TCB_PR

#elif (CPU==SH7600 || CPU==SH7000)

dispatch:
	/* taskIdPrevious = taskIdCurrent */
	mov	r14,r13
					mov	#WIND_TCB_ERRNO,r0
					extu.b	r0,r0
					mov.l	@(r0,r14),r2
	mov.l	DI_WINDTCB_R15,r1;	mov.l	WX_Errno,r3
	add	r1,r14;			mov.l	r2,@r3	/* restore errno */

	mov.l	@r14+,sp		/* set new task's sp */
	mov.l	@r14+,r0		/* get new task's pc */
	mov.l	@r14, r1		/* get new task's sr */
	add	#-80,r14
	mov.l	r1, @-sp		/* push sr as dummy exception frame */
	mov.l	r0, @-sp		/* push pc as dummy exception frame */

	/* load register set */
	lds.l	@r14+,pr
	mov.l	@r14+,r0
	mov.l	@r14+,r1
	mov.l	@r14+,r2
	mov.l	@r14+,r3
	mov.l	@r14+,r4
	mov.l	@r14+,r5
	mov.l	@r14+,r6
	mov.l	@r14+,r7
	lds.l	@r14+,mach		/* LOCK INTERRUPTS */
	lds.l	@r14+,macl;		mov.l	DI_IntLockSR,r12
	mov.l	@r14+,r8;		mov.l   @r12,r12
	mov.l	@r14+,r9;		ldc     r12,sr

					/* is work q empty? */
					mov.l	@r11,r12
	mov.l	@r14+,r10;		tst	r12,r12
					bt	doWorkUnlock /* r8,r9: broken */
#ifdef	WV_INSTRUMENTATION
	mov.l	DI_EvtAction,r11
	mov.l	@r11,r12
	tst	r12,r12
	bt	dispatchNoInstr
	bra	dispatchInstr;		/* ==> dispatchInstr */
	nop
		.align	2
DI_EvtAction:	.long	_evtAction
dispatchNoInstr:			/* <== dispatchInstr */
#endif	/*WV_INSTRUMENTATION*/
					/* release kernel mutex */
					mov.l	DI_KernelState,r13
					mov	#0,r12
	mov.l	@r14+,r11;		mov.l	r12,@r13
	mov.l	@r14+,r12
	mov.l	@r14+,r13;		rte
	mov.l	@r14,r14		/* INTERRUPTS UNLOCKED */

			.align	2
DI_WINDTCB_R15:		.long	WIND_TCB_R15

#endif /* CPU==SH7600 || CPU==SH7000 */

			.align	2
DI_IntLockSR:		.long	_intLockTaskSR
DI_KernelState:		.long	_kernelState
WX_TaskSwitchTable:	.long	_taskSwitchTable
WX_WorkQIsEmpty:	.long	_workQIsEmpty

/******************************************************************************
*
* idle - spin here until there is more work to do
*
* When the kernel is idle, we spin here continually checking for work to do.
*/
	.align	2
	.type	idle,@function
					/* r14: 0              */
	/************************/	/* r13:                */
	/*                      */	/* r12:                */
	/*   +---- _reschedule  */	/* r11: WorkQIsEmpty   */
	/*   |                  */	/* r10:                */
	/*   |   +---- doWork   */	/* r9:                 */
	/*   |   |              */	/* r8:                 */
	/*   V   V              */	/* r0-r7: (don't care) */
idle:

#ifdef	WV_INSTRUMENTATION
	mov.l	IL_EvtAction,r1;
	mov.l	@r1,r0;
	tst	r0,r0
	bt	idleNoInstr
	bra	idleInstr;		/* ==> idleInstr */
	nop
		.align	2
IL_EvtAction:	.long	_evtAction
idleNoInstr:				/* <== idleInstr */
#endif

#if (CPU==SH7600 || CPU==SH7000)
	ldc	r14,sr			/* UNLOCK INTERRUPTS (just in case) */
	mov.l   IL_KernelIsIdle,r1;
	mov	#1,r0
#else
					mov.l	IL_intUnlockSR,r3
	mov.l   IL_KernelIsIdle,r1;	mov.l	@r3,r2
	mov	#1,r0;			ldc	r2,sr
#endif
	mov.l	r0,@r1			/* _kernelIsIdle = 1 */

idleLoop:
	mov.l	@r11,r0;
	tst	r0,r0
	bt	bra_doWork		/* branch if _workQIsEmpty == 0 */
	mov.l	IL_VxIdleLoopHook,r0
	mov.l	@r0,r0
	tst	r0,r0
	bt	idleLoop		/* loop _func_vxIdleLoopHook == NULL */
	jsr	@r0
	nop
	bra	idleLoop
	nop

bra_doWork:
	bra	doWork;
	mov.l	r0,@r1			/* _kernelIsIdle = 0 */

/******************************************************************************
*
* doSwapHooks - execute the tasks' swap hooks
*
*/
	.align	2
	.type	doSwapHooks,@function
					/* r14: _taskIdCurrent  */
					/* r13: _taskIdPrevious */
					/* r12: swap hook mask  */
	/************************/	/* r11:                 */
	/*                      */	/* r10:                 */
	/*   +---- switchTasks  */	/* r9:  TaskIdCurrent   */
	/*   |                  */	/* r8:                  */
	/*   V                  */	/* r0-r7: (don't care)  */

doSwapHooks:
	mov.l   DSW_TaskSwapTable,r10;	/* r10: TaskSwapTable   */
	add     #-4,r10			/* start index at -1, heh heh       */
	bra	doSwapShift;		/* jump into the loop               */
	shll16	r12			/* align 16-bit mask to 32-bit MSB  */

doSwapHook:
	mov.l   @r10,r6;
	mov     r13,r4
	jsr	@r6;			/* f(_taskIdPrevious, _taskIdCurrent) */
	mov	r14,r5			/*        r4               r5         */

doSwapShift:
	add     #4,r10			/* bump swap table index           */
	shll    r12			/* shift swapMask bit pattern left */
	bt	doSwapHook		/* if T bit set then do ix hook    */

	tst	r12,r12
	bf	doSwapShift		/* any bits still set     */

	mov.l   DSW_TaskSwitchTable,r10;
	mov.l	@r10,r6;
	tst	r6,r6			/* r6: _taskSwitchTable */
	bt	dispatch

	/* FALL THRU TO DO_SWITCH_HOOKS */

/******************************************************************************
*
* doSwitchHooks - execute the global switch hooks
*
*/
	.type	doSwitchHooks,@function

	/*   |                    */	/* r14: _taskIdCurrent   */
	/*   |                    */	/* r13: _taskIdPrevious  */
	/*   |                    */	/* r12:                  */
	/*   |                    */	/* r11:                  */
	/*   |                    */	/* r10: TaskSwitchTable  */
	/* (doSwapHooks)          */	/* r9:  TaskIdCurrent    */
	/*   |                    */	/* r8:                   */
	/*   |   +-- switchTasks  */	/* r7:                   */
	/*   |   |                */	/* r6:  _taskSwitchTable */
	/*   V   V                */	/* r0-r5: (don't care)   */

doSwitchHooks:
	mov     #16,r12			/* VX_MAX_TASK_SWITCH_RTNS (taskLib.h)*/
	mov     r13,r4

doSwitchHook:
	jsr     @r6;			/* f(_taskIdPrevious, _taskIdCurrent) */
	mov	r14,r5			/*        r4               r5         */

	add     #4,r10			/* bump to next task switch routine */
	mov.l	@r10,r6;		/* get next task switch rtn         */
	tst	r6,r6			/* check for end of table (NULL)    */
	bt	dispatch
#if (CPU==SH7000)
	add     #-1,r12
	tst	r12,r12
#else
	dt	r12			/* r12: --ix */
#endif
	bt	dispatch

	bra	doSwitchHook;
	mov     r13,r4


/******************************************************************************
*
* doWorkUnlock - unlock interrupts and empty the work queue
*
* doWork       - empty the work queue
*
*/
	.align	2
	.type	doWorkUnlock,@function
	.type	doWork,@function

	/************************/	/* r12: 0 */
	/*                      */
	/*   +---- dispatch     */
	/*   |                  */
	/*   V                  */

doWorkUnlock:
#if (CPU==SH7600 || CPU==SH7000)
	ldc	r12,sr			/* UNLOCK INTERRUPTS */
	mov.l	WX_ReadyQHead,r8
	mov.l	WX_TaskIdCurrent,r9
#else
	mov.l	WX_intUnlockSR,r1;	mov.l	WX_ReadyQHead,r8
	mov.l	@r1,r0;			mov.l	WX_TaskIdCurrent,r9
	ldc	r0,sr
#endif
	/*   |                  */	/* r13: taskIdPrevious */
	/*   |   +---- idle     */	/* r9:  TaskIdCurrent  */
	/*   |   |              */	/* r8:  ReadyQHead     */
	/*   V   V              */	/* r0-r7: (don't care) */
doWork:
	mov.l	WX_WorkQDoWork,r0;
	jsr	@r0;			/* empty the work queue */
	nop
	mov.l	@r8,r14;		/* r14: _readyQHead */
	tst	r14,r14
	bt	idle			/* nobody is ready so spin */

	cmp/eq	r13,r14			/* compare to last task   */
	bt	dispatch		/* if the same dispatch   */

	bra	switchTasks;		/* not same, do switch    */
	mov.l	r14,@r9			/* taskIdCurrent = readyQHead */

			.align	2
DSW_TaskSwapTable:	.long	_taskSwapTable
DSW_TaskSwitchTable:	.long	_taskSwitchTable
IL_KernelIsIdle:	.long	_kernelIsIdle
#if (CPU!=SH7600 && CPU!=SH7000)
IL_intUnlockSR:		.long	_intUnlockSR
#endif
IL_VxIdleLoopHook:	.long	__func_vxIdleLoopHook

#endif	/* !PORTABLE */

			.align	2
WX_IntCnt:		.long	_intCnt
WX_TaskIdCurrent:	.long	_taskIdCurrent
WX_ReadyQHead:		.long	_readyQHead
WX_WINDTCB_SR:		.long	WIND_TCB_SR
WX_Errno:		.long	_errno
WX_WorkQDoWork:		.long	_workQDoWork
#if (CPU!=SH7600 && CPU!=SH7000)
WX_intUnlockSR:		.long	_intUnlockSR
#endif

/******************************************************************************
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
	.align	_ALIGN_TEXT
	.type	_vxTaskEntry,@function

					/* @(20,sp): arg10 */
					/* @(16,sp):  arg9 */
					/* @(12,sp):  arg8 */
					/* @( 8,sp):  arg7 */
					/* @( 4,sp):  arg6 */
					/* @( 0,sp):  arg5 */
					/*      r7 :  arg4 */
					/*      r6 :  arg3 */
					/*      r5 :  arg2 */
					/*      r4 :  arg1 */
_vxTaskEntry:
	mov.l	VX_TaskIdCurrent,r1;
	mov.l	@r1,r0;
	mov	#WIND_TCB_ENTRY,r1
	mov.l	@(r0,r1),r2;
	jsr	@r2;			/* call main routine */
	nop
	mov.l	VX_Exit,r1;
	add	#24,sp			/* pop args to main routine */
	jsr	@r1;			/* gone for good */
	mov	r0,r4			/* pass result to exit */

			.align	2
VX_TaskIdCurrent:	.long	_taskIdCurrent
VX_Exit:		.long	_exit

#if (CPU==SH7600 || CPU==SH7000)

			.data
			.align	2
			.global	_areWeNested
			.type	_areWeNested,@object
			.size	_areWeNested,4
_areWeNested:		.long	0x80000000

#endif /* CPU==SH7600 || CPU==SH7000 */

#ifdef	PORTABLE
/******************************************************************************
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

* INTERNAL
*					|		|
*		Current	task's stack:	|_______________| <-------------+
*					|_____ sr ______| <-------+     |
*					|_____ pc ______| <- sp --|--+  |
*					|		|         |  |  |
*					|		|         |  |  |
*					_________________         |  |  |
*	  0	WIND_TCB_SR	0x17c	|     sr (=0)	| --------+  |  |
*	 -4	WIND_TCB_PC	0x178	|     pc (=pr)	| -----------+  |
*	 -8	WIND_TCB_R15	0x174	|     sp	| --------------+
*	-12	WIND_TCB_R14	0x170	|     r14	| -> r14, then rte.
*	-16	WIND_TCB_R13	0x16c	|     r13	| -> r13
*	-20	WIND_TCB_R12	0x168	|     r12	| -> r12
*	-24	WIND_TCB_R11	0x164	|     r11	| -> r11
*	-28	WIND_TCB_R10	0x160	|     r10	| -> r10
*	-32	WIND_TCB_R9	0x15c	|     r9	| -> r9
*	-36	WIND_TCB_R8	0x158	|     r8	| -> r8
*	-40	WIND_TCB_MACL	0x154	|		| -> macl
*	-44	WIND_TCB_MACH	0x150	|		| -> mach
*	-48	WIND_TCB_R7	0x14c	|		| -> r7
*	-52	WIND_TCB_R6	0x148	|		| -> r6
*	-56	WIND_TCB_R5	0x144	|		| -> r5
*	-60	WIND_TCB_R4	0x140	|		| -> r4
*	-64	WIND_TCB_R3	0x13c	|		| -> r3
*	-68	WIND_TCB_R2	0x138	|		| -> r2
*	-72	WIND_TCB_R1	0x134	|		| -> r1
*	-76	WIND_TCB_R0	0x130	|     r0 (=0)	| -> r0
*	-80	WIND_TCB_PR	0x12c	|		| -> pr
*	 	WIND_TCB_GBR	0x128	|		|
*	 	WIND_TCB_VBR	0x124	|		|	(regsSh.h)
*	 				|		|
*	 	WIND_TCB_REGS	0x124	|_______________|	(taskLibP.h)
*	 			0x120	|_____ sr ______|
*	 			0x11c	|_____ pc ______|
*	 	EXC_INFO	0x118	|_valid_|_vecNum|	(excShLib.h)
*	 				|		|
*	 	WIND_TCB_ERRNO		|    _errno	| -> _errno
*	 				|		|
*	r14 ->	WIND_TCB	0x0	|_______________|	(taskLib.h)
*/
	.text
	.align	_ALIGN_TEXT
	.type	_windLoadContext,@function

#if (CPU==SH7750 || CPU==SH7700)

_windLoadContext:
	mov.l	WL_TaskIdCurrent,r1;	mov	#WIND_TCB_ERRNO,r0
	mov.l	@r1,r14;		extu.b	r0,r0
					mov.l	@(r0,r14),r2
	mov.l	WL_WINDTCB_PR,r1;	mov.l	WL_Errno,r3
	add	r1,r14;			mov.l	r2,@r3	/* restore errno */

	/* load register set */
	lds.l	@r14+,pr
	mov.l	@r14+,r0
	mov.l	@r14+,r1
	mov.l	@r14+,r2
	mov.l	@r14+,r3
	mov.l	@r14+,r4
	mov.l	@r14+,r5
	mov.l	@r14+,r6
	mov.l	@r14+,r7
	lds.l	@r14+,mach
	lds.l	@r14+,macl;		stc	vbr,r11
	mov.l	@r14+,r8;		add	#DISPATCH_STUB,r11
	mov.l	@r14+,r9;		jmp	@r11;
	mov.l	@r14+,r10

			.align	2
WL_WINDTCB_PR:		.long	WIND_TCB_PR

#elif (CPU==SH7600 || CPU==SH7000)

_windLoadContext:
	mov.l	WL_TaskIdCurrent,r1;	mov	#WIND_TCB_ERRNO,r0
	mov.l	@r1,r14;		extu.b	r0,r0
					mov.l	@(r0,r14),r2
	mov.l	WL_WINDTCB_R15,r1;	mov.l	WL_Errno,r3
	add	r1,r14;			mov.l	r2,@r3	/* restore errno */

	mov.l	@r14+,sp		/* set new task's sp */
	mov.l	@r14+,r5		/* get new task's pc */
	mov.l	@r14, r6		/* get new task's sr */
	add	#-80,r14
	mov.l	r6, @-sp		/* push sr as dummy exception frame */
	mov.l	r5, @-sp		/* push pc as dummy exception frame */

	/* load register set */
	lds.l	@r14+,pr;
	mov.l	@r14+,r0
	mov.l	@r14+,r1
	mov.l	@r14+,r2
	mov.l	@r14+,r3
	mov.l	@r14+,r4
	mov.l	@r14+,r5
	mov.l	@r14+,r6
	mov.l	@r14+,r7
	lds.l	@r14+,mach
	lds.l	@r14+,macl
	mov.l	@r14+,r8
	mov.l	@r14+,r9
	mov.l	@r14+,r10
	mov.l	@r14+,r11
	mov.l	@r14+,r12		/* UNLOCK INTERRUPTS */
	mov.l	@r14+,r13;		rte
	mov.l	@r14,r14

			.align	2
WL_WINDTCB_R15:		.long	WIND_TCB_R15

#endif /* CPU==SH7600 || CPU==SH7000 */

WL_TaskIdCurrent:	.long	_taskIdCurrent
WL_Errno:		.long	_errno

#endif	/* PORTABLE */
