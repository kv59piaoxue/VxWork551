/* excALib.s - assembly language exception handling stubs */

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
04k,19jun02,pes  SPR 78857: Prevent interrupt race when clearing EXL bit.
04j,18jan02,agf  add explicit align directive to data section(s)
04i,30nov01,pes  Fix SPR 26903: k0 may be overwritten during interrupt service
                 in restoreVolatile
04h,16jul01,ros  add CofE comment
04g,09jul01,agf  fix logic for spurious extended interrupt
04f,07jun01,agf  Add RM7000 extended interrupt support to WindView
                 instrumentation
04f,12jun01,mem  Fix SR handling in return from exception case.
04e,16feb01,tlc  Perform HAZARD review.
04d,15feb01,pes  Complete change indicated in 04c.
04c,15feb01,pes  Avoid reserved instruction exception in restoreVolatile
                 caused by ctc0 instruction in branch delay slot after
                 checking for extended interrupts.
04b,14feb01,zmm  Change .sdata to .data.
04a,13feb01,pes  Add support for RM7000 extended interrupts.
03z,19dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
03y,19jun00,dra  work around 5432 branch bug
03x,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
03w,30apr99,nps  remove inclusion of evtBufferLib.h
03v,12aug98,kkk  fixed bug in saving FPCSR in excStub. (SPR# 20669)
03u,16apr98,pr   added WindView 20 support.
03t,04apr97,kkk	 fixed excStub to not use k0 and k1 outside of 
		 non-interruptible sections (SPR# 8317)
03s,07mar97,tam  fixed problem when testing SR[CU1] bit (spr #8147)
03r,16dec96,kkk  took out duplicate code.
03q,12dec96,tam  added code to excStub to save FPCSR register (spr #7631).
03p,14oct96,kkk  added R4650 support.
03p,30jul96,kkk  in restoreVolatile, make sure all ints are masked out before
		 reenabling interrupts. (SPR# 4574)
03o,22jul96,pr   added instrumentation
		 moved state save to beginning of excIntStub
03n,08dec94,caf  moved check for spurious interrupt.
03m,12oct94,caf  added support for user prioritized interrupts
		 in excIntStub() (SPR #3714).
03l,19oct93,cd   added R4000 support.
03k,29sep93,caf  undid fix for SPR #2362 due to nested interrupt problem.
03j,07jul93,yao  fixed to read cause register only once (SPR #2362).
                 changed copyright notice.
03i,01oct92,ajm  merge missed changes for spurious interupts, 
		  general cleanup and doc
03h,05jun92,ajm  5.0.5 merge, notice mod history changes
03g,26may92,rrr  the tree shuffle
03f,05nov91,ajm  now use areWeNested to check for interrupt nesting, this
		  allows intCnt to be used for watchDogs.
03e,04oct91,rrr  passed through the ansification filter
                  -changed VOID to void
                  -changed ASMLANGUAGE to _ASMLANGUAGE
                  -changed copyright notice
03d,16jul91,ajm  changed excNormVec to fill more pipeline slots by loading
		  intCnt which was previously done in excIntStub.
03c,08jul91,ajm  changed how excStub reenables interrupts for consistency
		  and debugger.
03b,28may91,ajm  minor changes due to order change in REG_SET
03a,28feb91,ajm  created 5.0 version from 4.02 source
02p,13dec90,ajm  added deterministic hash search to find out which interrupt
		  is bugging us.  This blows away the software prioritization
		  of interrupts in the Prio table (see intR3kLib).  Presently
		  this is ifdefd' with DETERMINISTIC in both this module, and
		  intR3kLib.c so we can go back if we chose.
02o,19nov90,ajm  interleaved instructions to eliminate nop dead cycles
02n,01oct90,ajm  fixed interrupt nesting problem by using SR mask instead
		  of cause mask in excIntStub (PA resolution)
02m,19sep90,ajm  added excIntToExc routine to change thread of floating
		  point interrupts
02l,24aug90,ajm  placed nop before reenabling interrupts with k1 in excStub.
02k,09aug90,ajm  changed j in excUtlbVec, and excGenVec to la and jr
		  so that we can use ram exception vectors while running
		  out of prom.
02j,30jul90,ajm  placed the AT register in the frame of the gp regs 
		  for exceptions so that taskRegsSet and Get make mods
		  correctly in debug.  Thus it is duplicated across
		  the frame.
02i,18jun90,ajm  changed all references to k0 to be in non-interruptible
		  sections.  This is because intExit needs two registers
		  to return with (k0,k1).  Use of k0 in a preempible section
		  would cause havoc.
02h,07jun90,ajm  moved status register manipulation with rfe to soley this
		  module.  This eliminates the need for the previous change.
02g,06jun90,ajm  changed status register manipulation in intExcStub to always
		  enable interrupts by oring SR_IEC in the lsb.  This is done
		  because we no longer use rfe in windLoadContext.
02f,06jun90,ajm  corrected sp save (+ to -) for nested interrupts and exceptions
02e,03jun90,ajm  added restore from exceptions for breakpoints
02d,23may90,ajm  separated excCmnStub into excIntStub and excStub since
		  interrupts and exceptions use different stacks.  Also
		  needed to change excUtlbVec, and excNormVec to make
		  changes work.
02c,08may90,ajm  added stack space for jalr in excCmnStub for up to 4 
		  passed parameters (see esfR3k.h)
02b,01may90,ajm  got rid of gp references, really don't need them if
		  everything is one image
02a,09apr90,ajm  ported to mips r3000
01i,17jan89,jcf  fixed bug in excIntStub; intExit no longer takes d0 on stack.
01i,13feb88,dnw  added .data before .asciz above, for Intermetrics assembler.
01h,01nov87,jcf	 added code in excStub to retry an instruction
01g,24mar87,dnw  added .globl for excExcHandle.
		 documentation.
01f,26feb87,rdc  modifications for VRTX 3.2.
01e,21dec86,dnw  changed to not get include files from default directories.
01d,31oct86,dnw  Eliminated magic f/b numeric labels which mitToMot can't
		   handle.
		 Changed "moveml" instructions to use Motorola style register
		   lists, which are now handled by "aspp".
		 Changed "mov[bwl]" to "move[bwl]" for compatiblity w/Sun as.
01c,26jul86,dnw  changed 68000 version to use BSR table w/ single handler rtn.
01b,03jul86,dnw  documentation.
01a,03apr86,dnw  extracted from dbgALib.s
*/

/*
DESCRIPTION
This module contains the assembly language exception handling stub excStub, 
along with the interrupt handling stub excIntStub.
They are connected directly to the MIPS exception vectors by software.
They simply set up an appropriate environment and then call the appropriate
routine in excLib.

There are no user-callable routines in this module.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "private/eventP.h"
#include "asm.h"
#include "esf.h"
#include "sysLib.h"

#define C0_1_IC	$20			/* Interrupt control (CP0 set 1) */

#define IC_IMASKSHIFT         8         /* offset of ICR intrpt enables  */
#define IC_IMASK              0xff00    /* mask   of ICR intrpt enables  */
#define CAUSE_EXTMASKSHIFT    8         /* offset to align extended pending  */
                                        /*   bits with standard pending bits */

	/* internal */

	.globl	excBsrTbl	/* int/exception handler table	*/
	.globl	excStub		/* exception dispatch stub	*/
	.globl	excIntStub	/* interrupt dispatch stub	*/
	.globl	excNormVec	/* Normal exc/int vector	*/
	.globl	excNormVecSize	/* Normal exc/int vector size */
	.globl	excTlbVec	/* Tlb exception vector */
	.globl	excTlbVecSize	/* Tlb exception vector size */
#ifndef _WRS_R3K_EXC_SUPPORT
	.globl	excXtlbVec	/* Xtlb exception vector */
	.globl	excXtlbVecSize	/* Xtlb exception vector size */
	.globl	excCacheVec	/* Cache exception vector */
	.globl	excCacheVecSize	/* Cache exception vector size */
#endif

	/* external */

	.extern	sysHashOrder		/* address of hash table */
	.extern	intCnt			/* interrupt depth	*/
	.extern	areWeNested		/* Boolean for int nesting */
	.extern	vxIntStackBase		/* interrupt stack base */
	.extern	errno			/* unix like errno */

#ifdef WV_INSTRUMENTATION
	.extern	_func_evtLogT0			/* _func_evtLogT0 func ptr */
	.extern	_func_trgCheck			/* _func_trgCheck func ptr */
	.extern	evtAction    			
	.extern	wvEvtClass		
	.extern	trgEvtClass			
#endif /* WV_INSTRUMENTATION */

	.text
	.set	reorder

/******************************************************************************
*
* mipsIntHookSet - set the MIPS interrupt enter/exit hooks
*
*
*
* NOTE
*
* INTERNAL
*

* void mipsIntHookSet(FUNCPTR enterHook, void exitHook)

*/
	.data
	.align	4
	.globl _func_mipsIntHookEnter
_func_mipsIntHookEnter:
	.word	0
	.globl _func_mipsIntHookExit
_func_mipsIntHookExit:
	.word	0
	.text

	.globl	mipsIntHookSet
	.ent	mipsIntHookSet
mipsIntHookSet:
	sw	a0, _func_mipsIntHookEnter
	sw	a1, _func_mipsIntHookExit
	j	ra
	.end	mipsIntHookSet

/******************************************************************************
*
* mipsExtndIntEnable/mipsExtndIntDisable - enable/disable
*  RM7000 extended interrupt support.
*
*
*
* NOTE
*
* INTERNAL
*
* void mipsExtndIntEnable(void)
* void mipsExtndIntDisable(void)
*
*/
	.data
	.align	4
intStubSelect:	
	.word	0
	
	.text

	.globl	mipsExtndIntEnable
	.ent	mipsExtndIntEnable
mipsExtndIntEnable:	
	li	t0,1
	sw	t0, intStubSelect
	j	ra
	.end	mipsExtndIntEnable
	
	.globl	mipsExtndIntDisable
	.ent	mipsExtndIntDisable
mipsExtndIntDisable:	
	li	t0,0
	sw	t0, intStubSelect
	j	ra
	.end	mipsExtndIntDisable

/*******************************************************************************
*
* excStub - catch and dispatch exceptions
*
* This is the exception handler that is pointed to by the exception
* vector at address 0x80000080, the general exception vector.  
* In this routine we take care of fully saving state, and jumping to the 
* appropriate routines.  On exit from handling we also return 
* here to restore state properly.
*

* NOTE
* For now the utlb vector points here also.
*
* This routine is not callable!!  This routine does not include save and
* restore of floating point state.
*
* INTERNAL
* The goal here is to turn interrupts back on a quickly as possible.
* Some guidelines we have followed are that k0 and k1 can ONLY be used in 
* non-interruptible sections.  Also, before we turn interrupts back on we 
* must save as a minimum the state of the processor that changed upon 
* interrupt generation (volatile registers).  Volatile registers include
* the EPC, CAUSE, STATUS, and BADVA.  Also saved before interrupts are
* enabled, are the sp, and at regs.  These registers are not volatile, but
* used in reading and saving volatile registers.  All registers are saved 
* for proper state display.
*
* NOMANUAL

* void excStub()

*/

	.globl	excStub
	.ent	excStub
excStub:
	.set	noat
	/* we are operating on the task stack at this point */
	SW	sp, E_STK_SP-ESTKSIZE(sp) /* save sp in new intstk frame */
	subu	sp, ESTKSIZE		/* make new exc stk frame	*/
	SW	AT,E_STK_AT(sp)		/* save asmbler resvd reg	*/
	SW	v0,E_STK_V0(sp)		/* save func return 0, used
					   to hold masked cause		*/
	.set	at
	HAZARD_VR5400
	mfc0	k1, C0_BADVADDR		/* read bad VA reg	*/
	mfc0	k0, C0_EPC		/* read exception pc	*/
	HAZARD_CP_READ
	sw	k1, E_STK_BADVADDR(sp)	/* save bad VA on stack	*/
	sw	k0, E_STK_EPC(sp)	/* save EPC on stack	*/
	mfc0	v0, C0_CAUSE		/* read cause register	*/
	mfc0	k1, C0_SR		/* read status register	*/
	HAZARD_CP_READ
	sw	v0, E_STK_CAUSE(sp)	/* save cause on stack	*/
	andi	v0, CAUSE_EXCMASK	/* mask to get the exception cause
					   v0 preserved till jal */
	sw	k1, E_STK_SR(sp)	/* save status on stack	*/

#ifndef SOFT_FLOAT
        /* Now save the FP status register if coprocessor 1 is enabled.
         * We need to do this before enabling exceptions, otherwise,
         * another fpp exception could come in and trash the current
         * state.
         */

        and     k0, k1, SR_CU1          /* coprocessor 1 enabled? */
        beq     k0, zero, excNoFpu
        cfc1    k0, C1_SR               /* read FPCSR register */
	HAZARD_CP_READ
        sw      k0, E_STK_FPCSR(sp)     /* save FPCSR on stack */
        and     k0, k0, ~FP_EXC_MASK    /* clear FPCSR bits    */
        ctc1    k0, C1_SR
	HAZARD_CP_WRITE
#endif	/* !SOFT_FLOAT */

excNoFpu:
#ifdef _WRS_R3K_EXC_SUPPORT
	and	k0, k1, ~SR_KUMSK	/* k0 gets hi order 26 bits */
	and	k1, SR_KUMSK		/* k1 get low order 6 bits */
	srl	k1, 2			/* previous interrupt state */
	or	k1, k0			/* put them together */
#endif
	HAZARD_VR5400
#ifndef _WRS_R3K_EXC_SUPPORT
	mtc0	k1, C0_SR		/* SPR 78857: ensure ints masked */
					/*  before clearing EXL */
	and	k1, ~SR_EXL		/* reenable previous exception state */
#endif
	mtc0	k1, C0_SR
	HAZARD_CP_WRITE
	
	.set	noat
	mflo	AT			/* read entry lo reg	*/
	SW	AT,E_STK_LO(sp)		/* save entry lo reg	*/
	mfhi	AT			/* read entry hi reg	*/
	SW	AT,E_STK_HI(sp)		/* save entry hi reg	*/
0:
	.set	at
	SW	zero, E_STK_ZERO(sp)	/* save zero 		*/
	SW	zero, E_STK_K1(sp)	/* dummy value to k1 	*/
	SW	v1,E_STK_V1(sp)		/* save func return 1	*/
	SW	a0,E_STK_A0(sp)		/* save passed param 0	*/
	SW	a1,E_STK_A1(sp)		/* save passed param 1	*/
	SW	a2,E_STK_A2(sp)		/* save passed param 2	*/
	SW	a3,E_STK_A3(sp)		/* save passed param 3	*/
	SW	t0,E_STK_T0(sp)		/* save temp reg 0	*/
	SW	t1,E_STK_T1(sp)		/* save temp reg 1	*/
	SW	t2,E_STK_T2(sp)		/* save temp reg 2	*/
	SW	t3,E_STK_T3(sp)		/* save temp reg 3	*/
	SW	t4,E_STK_T4(sp)		/* save temp reg 4	*/
	SW	t5,E_STK_T5(sp)		/* save temp reg 5	*/
	SW	t6,E_STK_T6(sp)		/* save temp reg 6	*/
	SW	t7,E_STK_T7(sp)		/* save temp reg 7	*/
	SW	t8,E_STK_T8(sp)		/* save temp reg 8	*/
	SW	t9,E_STK_T9(sp)		/* save temp reg 9	*/
	SW	s0,E_STK_S0(sp)		/* save saved reg 0	*/
	SW	s1,E_STK_S1(sp)		/* save saved reg 1	*/
	SW	s2,E_STK_S2(sp)		/* save saved reg 2	*/
	SW	s3,E_STK_S3(sp)		/* save saved reg 3	*/
	SW	s4,E_STK_S4(sp)		/* save saved reg 4	*/
	SW	s5,E_STK_S5(sp)		/* save saved reg 5	*/
	SW	s6,E_STK_S6(sp)		/* save saved reg 6	*/
	SW	s7,E_STK_S7(sp)		/* save saved reg 7	*/
	SW	s8,E_STK_FP(sp)		/* save saved reg 8	*/
	SW	gp,E_STK_GP(sp)		/* save global pointer?	*/
	SW	ra, E_STK_RA(sp)	/* save return address	*/
	srl	a0, v0, 2		/* pass vector number		*/
	move	a1, sp			/* pass exc stack frame		*/
	la	a2, E_STK_SR(sp)	/* pass general register ptr	*/
	la	t0, excBsrTbl
	addu	v0, t0
	lw	v0, (v0)		/* grab routine addr		*/
	jal	v0			/* jump to routine, only return
					   from remote breakpoints	*/
excReturn:
	LW	v0,E_STK_V0(sp)		/* restore func ret 0	*/
	LW	v1,E_STK_V1(sp)		/* restore func ret 0	*/
	LW	a0,E_STK_A0(sp)		/* restore param 0	*/
	LW	a1,E_STK_A1(sp)		/* restore param 1	*/
	LW	a2,E_STK_A2(sp)		/* restore param 2	*/
	LW	a3,E_STK_A3(sp)		/* restore param 3	*/
	LW	t0,E_STK_T0(sp)		/* restore temp reg 0	*/
	LW	t1,E_STK_T1(sp)		/* restore temp reg 1	*/
	LW	t2,E_STK_T2(sp)		/* restore temp reg 2	*/
	LW	t3,E_STK_T3(sp)		/* restore temp reg 3	*/
	LW	t4,E_STK_T4(sp)		/* restore temp reg 4	*/
	LW	t5,E_STK_T5(sp)		/* restore temp reg 5	*/
	LW	t6,E_STK_T6(sp)		/* restore temp reg 6	*/
	LW	t7,E_STK_T7(sp)		/* restore temp reg 7	*/
	LW	s0,E_STK_S0(sp)		/* restore saved reg 0	*/
	LW	s1,E_STK_S1(sp)		/* restore saved reg 1	*/
	LW	s2,E_STK_S2(sp)		/* restore saved reg 2	*/
	LW	s3,E_STK_S3(sp)		/* restore saved reg 3	*/
	LW	s4,E_STK_S4(sp)		/* restore saved reg 4	*/
	LW	s5,E_STK_S5(sp)		/* restore saved reg 5	*/
	LW	s6,E_STK_S6(sp)		/* restore saved reg 6	*/
	LW	s7,E_STK_S7(sp)		/* restore saved reg 7	*/
	LW	s8,E_STK_FP(sp)		/* restore saved reg 8  */
	LW	gp,E_STK_GP(sp)		/* restore global ptr?  */
	LW	ra,E_STK_RA(sp)		/* restore return addr	*/

	LW	t9,E_STK_LO(sp)		/* grab entry hi reg	*/
	mtlo	t9			/* restore entry hi reg	*/
	LW	t9,E_STK_HI(sp)		/* grab entry lo reg	*/
	mthi	t9			/* restore entry hi reg	*/
0:
#ifndef _WRS_R3K_EXC_SUPPORT
	/* ensure that IMASK is clear before enabling EXL */
	li	t9,SR_IE
	mtc0	t9,C0_SR
	HAZARD_CP_WRITE
#endif
	lw	t9,E_STK_SR(sp)		/* read old SR		*/
#ifndef _WRS_R3K_EXC_SUPPORT
	or	t9, SR_EXL
#else	/* _WRS_R3K_EXC_SUPPORT */
	/* Shift IEc and KUc bits in the SR left by 2 prior to executing 
	 * the rfe instruction and resuming in the requested context.
	 * excExcHandle (excArchLib.c) shifted the SR down 
	 * by 2 when we first entered the exception. 
	 */
	and	t8, t9,0x00000003
	sll	t8, 2
	and	t9, 0xFFFFFFF0
	or	t9, t8	
#endif
	mtc0	t9, C0_SR		/* restore SR (EXL set) */
	HAZARD_CP_WRITE
	.set	noat
	LW	AT,E_STK_AT(sp)		/* restore AT reg	*/
	LW	t8,E_STK_T8(sp)		/* restore temp reg 8	*/
	LW	t9,E_STK_T9(sp)		/* restore temp reg 9	*/
	lw	k1,E_STK_EPC(sp)	/* grab pc		*/
	addu	sp, ESTKSIZE		/* restore stack	*/
	.set	noreorder
#ifdef _WRS_R3K_EXC_SUPPORT
	j	k1			/* restart with old state */
	rfe				/* reenable ints if enable
					   previous is set	*/
#else
	mtc0	k1,C0_EPC
	HAZARD_ERET
	eret
#endif
	.set	reorder
	.set	at
	.end	excStub

/*******************************************************************************
*
* excIntStub - Catch and dispatch interrupts 
*
* This is the interrupt dispatcher that is pointed to by the general 
* exception vector.  In this routine we take care of saving state, and
* jumping to the appropriate routines.  On exit from handling we also
* return here to restore state properly.
*
* This routine is not callable!!  This routine does not include save and
* restore of floating point state.
*
* INTERNAL
* The goal here is to turn interrupts back on a quickly as possible.
* Some guidelines we have followed are that k0 and k1 can ONLY be 
* used in non-interruptible sections. Control is finally passed to intExit
* with interrupts disabled.  Also, before we turn interrupts back on we must 
* save as a minimum the state of the processor that changed upon interrupt 
* generation (volatile registers).  Volatile registers include the EPC, 
* and STATUS registers.  Also saved before interrupts are enabled, are the 
* sp, v0, and at regs.  These registers are not volatile, but used in reading 
* and saving volatile registers, and calculation of the interrupted processor 
* state.  Saved registers (s regs) are not saved upon interrupts because the 
* MIPS compiler philosophy is to save any s-regs they use before any call.
*
*		at	- so assembler can use at	(non-volatile)
*		sp	- we use interrupt stack	(non-volatile)
*		epc	- changed upon excpt generation	(volatile)
*		cause	- changed upon excpt generation	(volatile)
*		status	- must read to bugging int	(volatile)
*		badva	- changed upon excpt generation	(volatile)
*		v0	- holds calculated int cause	(non-volatile)
*
* All interrupts that are not pending are allowed.  This is done by
* using the cause and status registers to determine which external
* interrupts are pending and shutting specifically those off.
*
* Interrupt priority is either 0-7 or 7-0 depending on the value of
* sysHashOrder in sysLib.c.
*
* The pad field of the intPrioTable determines whether to call a
* BSP provided interrupt demultiplex function.  If the pad field
* is zero there no multiplexing necessary, otherwise the pad field
* is passed to the multiplex routine as the base interrupt vector
* for the multiplex group.
*
* The offset field is the interrupt vector to use, or if the pad
* field is non zero, the address of the multiplex routine.
*
* See intPrioTable in sysLib.c , and excBsrTbl in excArchLib.c for a 
* clearer picture.
*
* NOMANUAL

* void excIntStub()

*/

	.globl	excIntStub
	.ent	excIntStub
excIntStub:
	.set	noat
/*
 *	Are we nested interrupt ???
 */
	/* k1 should now contain areWeNested */
	bne	k1, zero, nested	/* if in isr don't reset sp	 */
	lw	k0, vxIntStackBase	/* else {grab addr of int stack	 */
	subu	k0, ESTKSIZE		/* make room for frame		 */
	SW	sp, E_STK_SP(k0)	/* save sp on int stack		 */
	move	sp, k0			/* init new int stack ptr}	 */
	b	save_critical		/* jump over stack manip	 */
nested:
	SW	sp, E_STK_SP-ESTKSIZE(sp) /* save sp in new intstk frame */
	subu	sp, ESTKSIZE		/* make new int stk frame	 */
save_critical:
	SW	AT,E_STK_AT(sp)		/* save as resvd reg	         */
	.set	at
#ifndef WV_INSTRUMENTATION
	SW	v0,E_STK_V0(sp)		/* save return reg 0	         */
#endif /* WV_INSTRUMENTATION */

	/*
         * The following code replaces intEnt so I don't need
	 * to save ra while interrupts are masked
         */

	addu	k1, 1  			/* increment areWeNested         */
	sw	k1, areWeNested		/* update value	                 */
	lw	k1, intCnt		/* load intCnt	                 */
	addu	k1, 1  			/* increment intCnt              */
	sw	k1, intCnt		/* update value	                 */
#ifdef WV_INSTRUMENTATION

/*
 * Begin state save
 */

intStateSave:
	SW	zero,E_STK_ZERO(sp)	/* init zero reg storage	 */
        SW      v0,E_STK_V0(sp)         /* save func return 0            */
        SW      v1,E_STK_V1(sp)         /* save func return 1            */
        SW      a0,E_STK_A0(sp)         /* save passed param 0           */
        SW      a1,E_STK_A1(sp)         /* save passed param 1           */
        SW      a2,E_STK_A2(sp)         /* save passed param 2           */
        SW      a3,E_STK_A3(sp)         /* save passed param 3           */
        SW      t0,E_STK_T0(sp)         /* save temp reg 0               */
        SW      t1,E_STK_T1(sp)         /* save temp reg 1               */
        SW      t2,E_STK_T2(sp)         /* save temp reg 2               */
        SW      t3,E_STK_T3(sp)         /* save temp reg 3               */
        SW      t4,E_STK_T4(sp)         /* save temp reg 4               */
        SW      t5,E_STK_T5(sp)         /* save temp reg 5               */
        SW      t6,E_STK_T6(sp)         /* save temp reg 6               */
        SW      t7,E_STK_T7(sp)         /* save temp reg 7               */
        SW      t8,E_STK_T8(sp)         /* save temp reg 8               */
        SW      t9,E_STK_T9(sp)         /* save temp reg 9               */
        SW      ra,E_STK_RA(sp)         /* save return address           */
        mflo    t2                      /* read entry lo reg             */
        mfhi    t3                      /* read entry hi reg             */
        SW      t2,E_STK_LO(sp)         /* save entry lo reg             */
        SW      t3,E_STK_HI(sp)         /* save entry hi reg             */
0:	

#else /* WV_INSTRUMENTATION */
	lw	k0,errno
	sw	k0,E_ERRNO(sp)		/* save errno                    */
#endif /* WV_INSTRUMENTATION */
	.set	noreorder
	mfc0	k1, C0_SR		/* read status register          */
	mfc0	k0, C0_EPC		/* read exception pc             */
	mfc0	v0, C0_CAUSE		/* read cause register           */
	HAZARD_CP_READ
	sw	k1, E_STK_SR(sp)	/* save status on stack          */
	sw	k0, E_STK_EPC(sp)	/* save EPC on stack             */
	sw	v0, E_STK_CAUSE(sp)	/* save cause on stack           */
	.set	reorder

#ifdef WV_INSTRUMENTATION

        /*
         * windview instrumentation - BEGIN
         * enter an interrupt handler.
         */
        lw      t0, evtAction                   /* is instrumentation on? */
        beqz    t0, noIntEnt

	/* we are checking
	 * if ((wvEvtClass&(WV_CLASS_1_ON)) != (WV_CLASS_1_ON)) 
	 * leave WV instrumentation and check triggering 
	 */
        lw      t0, wvEvtClass                   
        li      t4, WV_CLASS_1_ON               
        and     t0, t0, t4
        bne     t4, t0, trgCheckIntEnt

        /* interrupts are locked
         * all registers are saved
         * k1 has STATUS and v0 has CAUSE from above
         */

        lw      t4, sysHashOrder        /* load address of hash table    */
        and     t1, k1, SR_IMASK        /* t1 = IM[7:0]                  */
        and     t1, v0                  /* t1 = IM[7:0] & IP[7:0]        */
        bnez    t1, 0f                  /* if interrupt, skip down;      */
                                        /*    dont check extended bits   */

	lw	t2, intStubSelect
	beqz	t2, 0f                  /* if not using Rm7K, skip down; */
                                        /*    dont check extended bits   */

        srl     t2, v0, CAUSE_EXTMASKSHIFT 
                                        /* align IP in CAUSE with ICR    */
        cfc0    t1, C0_1_IC             /* get ICR                       */
	HAZARD_CP_READ
        and     t1, IC_IMASK            /* t1 = IM[15:8]                 */
        and     t1, t2                  /* t1 = IM[15:8] & IP[15:8]      */
        beqz    t1, 0f                  /* if still no interrupt, skip   */
                                        /*    use low-order interrupt    */
        srl     t1, IC_IMASKSHIFT       /* right justify                 */
        addu    t1, t4                  /* calculate table index         */
        lbu     t2, 0(t1)               /* read table index              */
        addu    t2, 8                   /* adjust to upper half          */
        b       1f                      /* skip down to function call    */

/* get to here if IP[7:0] -or- not using Rm7k extended interrrupts */
0:
        srl     t1, SR_IMASKSHIFT       /* right justify                 */
        addu    t1, t4                  /* calculate table index         */
        lbu     t2, 0(t1)               /* read table index              */

/* make the function call */
1:
        addu    a0, t2, MIN_INT_ID+1
        lw      t1, _func_evtLogT0
        jal     t1                      /* call evtLogT0 routine          */

        lw      v0, E_STK_CAUSE(sp)     /* restore the value of v0. We    */
					/* might have lost it in evtLogT0 */
trgCheckIntEnt:

        lw      t0, trgEvtClass
        li      t4, TRG_CLASS_1_ON
        and     t0, t0, t4
        bne     t4, t0, noIntEnt

        lw      t4, sysHashOrder        /* load address of hash table    */
        and     t1, k1, SR_IMASK        /* t1 = IM[7:0]                  */
        and     t1, v0                  /* t1 = IM[7:0] & IP[7:0]        */
        bnez    t1, 0f                  /* if interrupt, skip down;      */
                                        /*    dont check extended bits   */

	lw	t2, intStubSelect
	beqz	t2, 0f                  /* if not using Rm7K, skip down; */
                                        /*    dont check extended bits   */

        srl     t2, v0, CAUSE_EXTMASKSHIFT
                                        /* align IP in CAUSE with ICR    */
        cfc0    t1, C0_1_IC             /* get ICR                       */
	HAZARD_CP_READ
        and     t1, IC_IMASK            /* t1 = IM[15:8]                 */
        and     t1, t2                  /* t1 = IM[15:8] & IP[15:8]      */
        beqz    t1, 0f                  /* if still no interrupt, skip   */
                                        /*    use low-order interrupt    */
        srl     t1, IC_IMASKSHIFT       /* right justify                 */
        addu    t1, t4                  /* calculate table index         */
        lbu     t2, 0(t1)               /* read table index              */
        addu    t2, 8                   /* adjust to upper half          */
        b       1f                      /* skip down to function call    */

/* get to here if IP[7:0] -or- not using Rm7k extended interrrupts */
0:
        srl     t1, SR_IMASKSHIFT       /* right justify                 */
        addu    t1, t4                  /* calculate table index         */
        lbu     t2, 0(t1)               /* read table index              */

/* make the function call */
1:
        addu    a0, t2, MIN_INT_ID+1

        li      a1, TRG_CLASS1_INDEX
        li      a2, 0x0

        lw      t1, _func_trgCheck
        jal     t1                              /* call evtLogT0 routine */

        lw      v0, E_STK_CAUSE(sp)     /* restore the value of v0. We    */
noIntEnt:
        /* windview instrumentation - END */

        lw      k0,errno
        sw      k0,E_ERRNO(sp)          /* save errno                    */

#else /* WV_INSTRUMENTATION */
      	SW	t3,E_STK_T3(sp)		/* save temp reg 3 (early)       */
      	SW	t2,E_STK_T2(sp)		/* save temp reg 2 (early)       */
	SW	t1,E_STK_T1(sp)		/* save temp reg 1 (early)       */
#endif /* WV_INSTRUMENTATION */

	lw	t1, intStubSelect
	bnez	t1, excIntStubExtended

excIntStubNormal:	
        /*
         * Note that it is possible to arrive here with
         * (CAUSE & STATUS & SR_IMASK) == 0
         */
	
	/* now k1 has STATUS and v0 has CAUSE */

        andi    t2, v0, SR_IMASK        /* check for spurious interrupt  */
        and     v0, k1, t2              /* v0 = ints enabled and pending */
	lw	t1, sysHashOrder	/* load address of hash table    */
#ifdef WV_INSTRUMENTATION
        beqz    v0, Restore             /* return if no interrupt */
#else /* WV_INSTRUMENTATION */
	beqz	v0, restoreVolatile	/* check for spurious interrupt  */
#endif /* WV_INSTRUMENTATION */
	srl     t2, v0, SR_IMASKSHIFT	/* t2 = v0 right justified       */
	addu	t2, t2, t1		/* calculate table index         */
	lbu	t1, 0(t2)		/* read table index              */
	sll	t1, 4			/* mult by Prio table size       */

        /*
         * The deterministic search implemented is a hash table
         * search, it is necessary that the Prio table be organized
         * in an ordered fashion for this to work.
         *
         * Volatile registers in MIPSville are considered EPC,
         * SR, and CAUSE.  Our kernel implementation also places
         * sp and AT registers in this catagory.  We use t1, t2, and
         * v0 as working registers and call the formentioned set
         * of registers volatile in the context of vxWorks.  It
         * is critical that no other registers are used above
         * this point in excIntStub without restoring them
         * after the label restoreVolatile.  Register t1 now
         * contains the pointer to the prio table which will
         * be used in code that follows.  Be sure not to corrupt
         * this value.
         */

#if 0
	lw	t2, intPrioTable+8(t1)	/* get user mask                 */
#else
	.set	noat
	lui	AT, %hi(intPrioTable+8)
	addu	AT, t1
	lw	t2, %lo(intPrioTable+8)(AT)
	.set	at
#endif
  	or	v0, v0, t2		/* add user mask                 */
	not	v0			/* invert interrupt mask         */
	and	k1, v0, k1		/* apply interrupt mask to k1    */

excIntStubCommonExit:	
#ifdef _WRS_R3K_EXC_SUPPORT
        mtc0    k1, C0_SR               /* update SR       */
	HAZARD_CP_WRITE
        or      k1, SR_IEC              /* now enable ints */
        mtc0    k1, C0_SR               /* update SR       */
#endif
#ifndef _WRS_R3K_EXC_SUPPORT
	mtc0	k1, C0_SR		/* SPR 78857: ensure ints masked */
					/*  before clearing EXL */
	and 	k1, ~SR_EXL
	HAZARD_VR5400
	mtc0	k1, C0_SR		/* enable interrupts w/ new mask */
#endif /* _WRS_R3k_EXC_SUPPORT */
	
#if 0
	lw	v0, intPrioTable+4(t1)	/* get vector ptr;               */
					/* don't touch v0 after this	 */
#else
	.set	noat
	lui	AT, %hi(intPrioTable+4)
	addu	AT, t1
	lw	v0, %lo(intPrioTable+4)(AT)
	.set	at
#endif

#if 0
	lw	t1, intPrioTable+12(t1)	/* get vector base;              */
					/* don't touch t1 after this     */
#else
	.set	noat
	lui	AT, %hi(intPrioTable+12)
	addu	AT, t1
	lw	t1, %lo(intPrioTable+12)(AT)
	.set	at
#endif
#ifndef WV_INSTRUMENTATION

/*
 * Begin state save
 */

intStateSave:
	mflo	t2			/* read entry lo reg	         */
	SW	t2,E_STK_LO(sp)		/* save entry lo reg        	 */
	mfhi	t2			/* read entry hi reg	         */
	SW	t2,E_STK_HI(sp)		/* save entry hi reg	         */
0:					/* save func return 0, see above */
	SW	v1,E_STK_V1(sp)		/* save func return 1	         */
	SW	a0,E_STK_A0(sp)		/* save passed param 0        	 */
	SW	a1,E_STK_A1(sp)		/* save passed param 1	         */
	SW	a2,E_STK_A2(sp)		/* save passed param 2	         */
	SW	a3,E_STK_A3(sp)		/* save passed param 3	         */
	SW	t0,E_STK_T0(sp)		/* save temp reg 0	         */
					/* save temp reg 1, see above	 */
					/* save temp reg 2, see above	 */
					/* save temp reg 3, see above	 */
	SW	t4,E_STK_T4(sp)		/* save temp reg 4	         */
	SW	t5,E_STK_T5(sp)		/* save temp reg 5	         */
	SW	t6,E_STK_T6(sp)		/* save temp reg 6	         */
	SW	t7,E_STK_T7(sp)		/* save temp reg 7	         */
	SW	t8,E_STK_T8(sp)		/* save temp reg 8	         */
	SW	t9,E_STK_T9(sp)		/* save temp reg 9	         */
	SW	ra,E_STK_RA(sp)		/* save return address	         */

#endif /* WV_INSTRUMENTATION */

	beq	t1, zero, call		/* if pad == 0, don't demux	 */
	move	a0, t1			/* pass vector base to demux	 */

	jal	v0			/* call demux routine, v0 now    */
					/* contains vector		 */

call:	move	a0, v0			/* pass vector number		 */
	move	a1, sp			/* pass exc stack frame		 */
	sll	v0, 2			/* mult index by wordsize	 */
	la	t0, excBsrTbl
	addu	v0, t0
	lw	v1, (v0)		/* grab routine addr		 */
	jal	v1			/* jump to routine 		 */

/*
 * Begin state restoration
 */

Restore:
	lw	t2,E_ERRNO(sp)
	sw	t2,errno		/* restore errno                 */
	LW	v1,E_STK_V1(sp)		/* restore func ret 0	         */
	LW	a0,E_STK_A0(sp)		/* restore passed param 0	 */
	LW	a1,E_STK_A1(sp)		/* restore passed param 1	 */
	LW	a2,E_STK_A2(sp)		/* restore passed param 2	 */
	LW	a3,E_STK_A3(sp)		/* restore passed param 3	 */
	LW	t0,E_STK_T0(sp)		/* restore temp reg 0            */
	LW	t4,E_STK_T4(sp)		/* restore temp reg 4            */
	LW	t5,E_STK_T5(sp)		/* restore temp reg 5            */
	LW	t6,E_STK_T6(sp)		/* restore temp reg 6            */
	LW	t7,E_STK_T7(sp)		/* restore temp reg 7            */
	LW	t8,E_STK_T8(sp)		/* restore temp reg 8            */
	LW	ra,E_STK_RA(sp)		/* restore return addr           */
	LW	t9,E_STK_LO(sp)		/* grab entry hi reg             */
	mtlo	t9			/* restore entry hi reg          */
	LW	t9,E_STK_HI(sp)		/* grab entry lo reg             */
	mthi	t9			/* restore entry hi reg          */
0:	
	LW	t9,E_STK_T9(sp)		/* restore temp reg 9            */

	/*
	 * Registers restored after this point must only be registers
	 * which are considered volatile.  This currently 
	 * includes SR, EPC, AT, sp, v0, t1, and t2.  Any additions to
	 * the volatile set of registers (see comments above) should
	 * be mirrored with restores after the label restoreVolatile.
	 */

restoreVolatile:
	lw	t1,E_STK_SR(sp)		/* read old SR		         */
#ifndef _WRS_R3K_EXC_SUPPORT
	/* ensure imask == 0 before setting EXL */
	li	v0,SR_IE	
	HAZARD_VR5400
	mtc0	v0,C0_SR
	HAZARD_CP_WRITE
#endif
#ifdef _WRS_R3K_EXC_SUPPORT
	and	v0,t1,~SR_IMASK&~SR_IEC /* mask/disable all interrupts   */
	mtc0	v0,C0_SR		/* restore SR (without ints)     */
	HAZARD_INTERRUPT
#endif
	.set	noreorder

	/* If extended interrupts are supported, the saved value of the 
	 * Interrupt Control register will have been placed in the ESF 
	 * in place of the zero register. If the saved value is zero, 
	 * it implies that either a) extended interrupts are not 
	 * supported, or b) that the IC register was clear when its 
	 * contents were saved, meaning that it is not necessary to 
	 * restore its contents. 
	 */
	
	LW	t2, E_STK_ZERO(sp)	/* get IntCount from ESF	 */
	beqz	t2, 1f
	nop
	ctc0	t2, C0_1_IC		/* set IntControl		 */
1:	
	mtc0	t1,C0_SR		/* put on processor	         */
	.set	reorder
	LW	v0,E_STK_V0(sp)		/* restore func ret 0	         */
	LW	t3,E_STK_T3(sp)		/* restore temp reg 3            */
      	LW	t2,E_STK_T2(sp)		/* restore temp reg 2	         */
	LW	t1,E_STK_T1(sp)		/* restore temp reg 1	         */

	j	intExit			/* exit kernel, exception frame  */
					/* on interrupt stack            */
	
/* stub for handling extended interrupts on RM7000 */
excIntStubExtended:	
        /*
         * Note that it is possible to arrive here with
         * (CAUSE & STATUS & SR_IMASK) == 0
         */
	
	/* now k1 has STATUS and v0 has CAUSE */
	
	cfc0	t2, C0_1_IC		/* get IntControl */
	srl	t1, k1, 8		/* get IM[7:0] */
	and	t1, 0xff
	and	t2, 0xff00		/* get IM[15:8] */
	or	t1, t2			/* t1 = IM[15:0] */
	srl	t2, v0, 8
	and	t2, 0xffff		/* t2 = IP[15:0] */
	and	t2, t1			/* t2 = IP & IM */
#ifdef WV_INSTRUMENTATION
        beqz    t2, Restore             /* return if no interrupt */
#else /* WV_INSTRUMENTATION */
	beqz	t2, restoreVolatile	/* return if no interrupt */
#endif /* WV_INSTRUMENTATION */
	and	t1, t2, 0xff		/* t1 = (IP&IM)[7:0] */
	beqz	t1, 0f			/* branch if no low int asserted */

	lw	t2, sysHashOrder	/* load address of hash table    */
	addu	t2, t1			/* calculate table index         */
	lbu	t1, 0(t2)		/* read table index              */
	sll	t1, 4			/* mult by Prio table size       */
	b	1f
0:
	srl	t1, t2, 8		/* t1 = (IP&IM)[15:8] */
	lw	t2, sysHashOrder	/* load address of hash table    */
	addu	t2, t1			/* calculate table index         */
	lbu	t1, 0(t2)		/* read table index              */
	add	t1, 8			/* adjust to upper half of table */
	sll	t1, 4			/* mult by Prio table size       */
1:

        /*
         * The deterministic search implemented is a hash table
         * search, it is necessary that the Prio table be organized
         * in an ordered fashion for this to work.
         *
         * Volatile registers in MIPSville are considered EPC,
         * SR, and CAUSE.  Our kernel implementation also places
         * sp and AT registers in this catagory.  We use t1, t2, and
         * v0 as working registers and call the formentioned set
         * of registers volatile in the context of vxWorks.  It
         * is critical that no other registers are used above
         * this point in excIntStub without restoring them
         * after the label restoreVolatile.  Register t1 now
         * contains the pointer to the prio table which will
         * be used in code that follows.  Be sure not to corrupt
         * this value.
         */

#if 0
	lw	t2, intPrioTable+8(t1)	/* get user mask                 */
#else
	.set	noat
	lui	AT, %hi(intPrioTable+8)
	addu	AT, t1
	lw	t2, %lo(intPrioTable+8)(AT)
	.set	at
#endif
  	or	t2, v0			/* add cause bits                */
	and	t3, t2, 0xff00		/* get just SR interrupts	 */
	not	t3			/* invert interrupt mask         */
	and	k1, t3, k1		/* apply interrupt mask to k1    */

	srl	t2, 8			/* get upper int bits		 */
	and	t2, 0xff00		/* get just SR ints		 */
	not	t2
	cfc0	t3, C0_1_IC		/* get IntControl		 */
	HAZARD_CP_READ
	SW	t3, E_STK_ZERO(sp)	/* stash IntCount in ESF	 */
	and	t3, t2
	ctc0	t3, C0_1_IC		/* set IntControl		 */
	j	excIntStubCommonExit

	.end	excIntStub

#ifndef _WRS_R3K_EXC_SUPPORT
/*******************************************************************************
*
* excCache - catch and handle cache exceptions
*
* This is the exception handler that is pointed to by the r4000 
* vector at address 0xa0000100, the cache exception vector.  
* In this routine we attempt to fix the cache error and then continue.
* If too many cache excpetions occur, the cache is disabled.
*

* NOTE
* This routine is not callable!!  This routine does not include save and
* restore of floating point state.
*

* NOMANUAL

* void excCache()

*/
#define STKSIZE	256
	.comm cache_xcp, ESTKSIZE+STKSIZE

	.ent	excCache
excCache:
	/*
	 * Low-level handler only saved $at and $k0, give ourselves
	 * more legroom.
	 */
	la	k0,cache_xcp+STKSIZE
	or	k0,K1BASE
	SW	sp,E_STK_SP(k0)
	move	sp,k0
	SW	v0,E_STK_V0(sp)
	SW	a0,E_STK_A0(sp)
	SW	a1,E_STK_A1(sp)
	SW	a2,E_STK_A2(sp)
	mfc0	v0,C0_CACHEERR
	mfc0	a2,C0_TAGLO		# save taglo
	HAZARD_CP_READ
	and	a0,v0,CACHEERR_BUS	# sysAD bus error?
	bnez	a0,mem_err

	and	a0,v0,CACHEERR_LEVEL	# secondary cache error?
	bnez	a0,scache_err

pcache_err:
	/* error is in one or both primary caches */
	/* generate cache address to use for cacheops */
	and	a0,v0,CACHEERR_SIDX_MASK & ((1<<CACHEERR_PIDX_SHIFT)-1)
	and	a1,v0,CACHEERR_PIDX_MASK
	sll	a1,CACHEERR_PIDX_SHIFT
	or	a0,a1			# $a0 = primary cache index
	addu	a0,K0BASE

	/* determine which cache */
	and	a1,v0,CACHEERR_TYPE
	bnez	a1,pdcache

picache:
	/* zap primary instruction cache line */
	mtc0	zero,C0_TAGLO
	HAZARD_CACHE_TAG
        cache   Index_Store_Tag_I,0(a0)
	b	fixed

pdcache:
	/* give up on a Dirty Exclusive line */
        cache   Index_Load_Tag_D,0(a0)
	HAZARD_CACHE_TAG
	mfc0	a1,C0_TAGLO
	HAZARD_CP_READ
	and	a1,1<<TAG_PSTATE_SHIFT
	bnez	a1,giveup

	/* we can now zap the line */
	mtc0	zero,C0_TAGLO
	HAZARD_CACHE_TAG	
        cache   Index_Store_Tag_D,0(a0)

	/*
	 * cache error appears to be fixed
	 */
fixed:	
	HAZARD_CACHE_TAG
	mtc0	a2,C0_TAGLO	 	# restore taglo
	LW	v0,E_STK_V0(k0)	
	LW	a0,E_STK_A0(k0)	
	LW	a1,E_STK_A1(k0)	
	LW	a2,E_STK_A2(k0)	
	j	ra

mem_err:
	/* not yet implemented */

scache_err:
	/* not yet implemented */

giveup:	
	/* protect ourselves from any more cache errors */
	mfc0	v0,C0_SR
	HAZARD_CP_READ
	or	v0,SR_DE
	mtc0	v0,C0_SR
	HAZARD_CP_WRITE
	
	/* stuff a message in the catastrophic message area */

	lw	a1,sysExcMsg
	beqz	a1,1f
	la	a0,cacheMsg
	jal	strcpy
1:	li	a0,BOOT_NO_AUTOBOOT
	jal	reboot
	b	1b
	j	ra
	.end	excCache

	.rdata
cacheMsg:
	.ascii	"Fatal cache error"
	.byte	0
	.text
#endif

#ifdef _WRS_R3K_EXC_SUPPORT
/*********************************************************************
*
* excNormVec - Instructions to load at the r3000 normal exception vector
*
* These instructions are copied to 0x80000080, the normal exception vector
* by the startup routine excVecInit.  We must use the assembler pseudo op .noat 
* so the la instruction will not use the at register and mess with process 
* state.  The .set noreorder takes instruction reorder control away from the
* assembler, and puts it in our hands.  We are using load address and jump to
* register so that we may run vxWorks out of prom (see j, and jal instruction
* definitions).
*
* NOMANUAL

* void excNormVec()
*/

	.ent	excNormVec
	.set	noreorder
	.set	noat
excNormVec:
	mfc0	k0, C0_CAUSE		/* grab cause register	*/
	HAZARD_CP_READ
	lw	k1, areWeNested		/* grab value in delay slot*/
	andi	k0, CAUSE_EXCMASK	/* look at exception bits */
	bne	k0, zero, 1f		/* zero == interrupt	  */
	nop
	la	k0, excIntStub
	j	k0			/* jump to interrupt handler */
	nop
1:	la	k0, excStub
	j	k0			/* jump to exception handler */
	nop
excNormVecEnd:
	.set	at
	.set	reorder
	.end	excNormVec

	.data
	.align	4
excNormVecSize:
	.word	excNormVecEnd-excNormVec
	.text

#endif

/*********************************************************************
*
* excTlbVec - Instructions to load at the r4000 tlb exception vector
*
* These instructions are copied to 0x80000000, the Tlb exception vector
* by the startup routine excVecInit.  We must use the assembler pseudo op
* .noat so the la instruction will not use the at register and mess with
* process state.  The .set noreorder takes instruction reorder control away
* from the assembler, and puts it in our hands.
*
* To handle tlb exceptions that are funneled to this vector
* we do not have to save state fully.  Since vxworks does not
* use the tlb, we leave it as a common handler, saving full state
* for panics.  If we did use the tlb, this should have its own 
* special vector.  We are using load address and jump to register 
* so that we may run vxWorks out of prom (see j, and jal instruction
* definitions).
*
* NOMANUAL

* void excTlbVec()
*/

	.ent	excTlbVec
	.set	noreorder
	.set	noat
excTlbVec:
	la	k0, excStub
	j	k0				/* jump to exception handler */
	nop
excTlbVecEnd:
	.set	at
	.set	reorder
	.end	excTlbVec

	.data
	.align	4
excTlbVecSize:
	.word	excTlbVecEnd-excTlbVec
	.text

#ifndef _WRS_R3K_EXC_SUPPORT
/*********************************************************************
*
* excXtlbVec - Instructions to load at the r4000 Xtlb exception vector
*
* These instructions are copied to 0x80000080, the Xtlb exception vector
* by the startup routine excVecInit.  We must use the assembler pseudo op
* .noat so the la instruction will not use the at register and mess with
* process state.  The .set noreorder takes instruction reorder control away
* from the assembler, and puts it in our hands.
*
* To handle tlb exceptions that are funneled to this vector
* we do not have to save state fully.  Since vxworks does not
* use the tlb, we leave it as a common handler, saving full state
* for panics.  If we did use the tlb, this should have its own 
* special vector.  We are using load address and jump to register 
* so that we may run vxWorks out of prom (see j, and jal instruction
* definitions).
*
* NOMANUAL

* void excXtlbVec()
*/

	.ent	excXtlbVec
	.set	noreorder
	.set	noat
excXtlbVec:
	la	k0, excStub
	j	k0				/* jump to exception handler */
	nop
excXtlbVecEnd:
	.set	at
	.set	reorder
	.end	excXtlbVec

	.data
	.align	4
excXtlbVecSize:
	.word	excXtlbVecEnd-excXtlbVec
	.text
#endif /* _WRS_R3K_EXC_SUPPORT */

#ifndef _WRS_R3K_EXC_SUPPORT
/*********************************************************************
*
* excCacheVec - Instructions to load at the r4000 cache exception vector
*
* These instructions are copied to 0xa0000100, the cache exception vector
* by the startup routine excVecInit.  We must use the assembler pseudo op
* .noat so the la instruction will not use the at register and mess with
* process state.  The .set noreorder takes instruction reorder control away
* from the assembler, and puts it in our hands.
* When a cache excption takes place, KUSEG is replaced by an unmapped
* uncached area that can be accessed using 0 based addressing.  We 
* save some registers in fixed locations and then attempt to fix the cache
* error.
*
* NOMANUAL

* void excCacheVec()
*/

/* save just below general exception handler */
#define AT_SAVE	+(0x180-8)
#define K0_SAVE	+(0x180-16)
#define RA_SAVE	+(0x180-24)

	.ent	excCacheVec
	.set	noreorder
	.set	noat
excCacheVec:
	SW	AT,AT_SAVE(zero)
	SW	k0,K0_SAVE(zero)
	SW	ra,RA_SAVE(zero)
	.set	at
	la	k0,excCache
	or	k0,K1BASE		# must stay uncached
	jal	k0
	nop
	.set	noat
	LW	AT,AT_SAVE(zero)
	LW	k0,K0_SAVE(zero)
	LW	ra,RA_SAVE(zero)
	eret
	nop
excCacheVecEnd:
	.set	at
	.set	reorder
	.end	excCacheVec

	.data
	.align	4
excCacheVecSize:
	.word	excCacheVecEnd-excCacheVec
	.text

/*********************************************************************
*
* excNormVec - Instructions to load at the r4000 normal exception vector
*
* These instructions are copied to 0x80000180, the normal exception vector
* by the startup routine excVecInit.  We must use the assembler pseudo op .noat 
* so the la instruction will not use the at register and mess with process 
* state.  The .set noreorder takes instruction reorder control away from the
* assembler, and puts it in our hands.  We are using load address and jump to
* register so that we may run vxWorks out of prom (see j, and jal instruction
* definitions).
*
* NOMANUAL

* void excNormVec()
*/

	.ent	excNormVec
	.set	noat
excNormVec:
	mfc0	k0, C0_CAUSE		/* grab cause register	*/
	HAZARD_CP_READ
	lw	k1, areWeNested		/* grab value in delay slot*/
	andi	k0, CAUSE_EXCMASK		/* look at exception bits */
	bne	k0, zero, 1f		/* zero == interrupt	  */
	la	k0, excIntStub
	j	k0			/* jump to interrupt handler */
1:	la	k0, excStub
	j	k0			/* jump to exception handler */
excNormVecEnd:
	.set	at
	.end	excNormVec

	.data
	.align	4
excNormVecSize:
	.word	excNormVecEnd-excNormVec
	.text

#endif /* !_WRS_R3K_EXC_SUPPORT */
