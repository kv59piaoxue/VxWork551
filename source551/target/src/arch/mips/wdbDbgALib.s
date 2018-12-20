/* wdbDbgALib.s - MIPS R4000 debug support routines */

/* Copyright 1984-2001 Wind River Systems, Inc. */
	.data
	.globl  copyright_wind_river

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
01l,02aug01,mem  Diab integration
01k,16jul01,ros  add CofE comment
01j,12jun01,mem  Fix single-stepping.
01i,08feb01,agf  Adding HAZARD macros
01h,03jan01,mem  Added include of dbgMipsLib.h to resolve the DBG_HARDWARE_BP
                 issue.
01g,02jan01,pes  Finish converting for MIPS32/MIPS64 architecture.
01f,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01e,10sep99,myz  added CW4000_16 support.
01d,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01c,09jan98,dbt	 modified for new breakpoint scheme. Added hardware 
		 breakpoints support
01b,10dec96,kkk  added R4650 routines.
01a,11oct93,cd   created.
*/

/*
DESCRIPTION
This library contains MIPS debug support routines written in 
assembly language.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "regs.h"
#include "arch/mips/dbgMipsLib.h"

	.text
	.set	reorder

	/* externals */

	.globl	_wdbDbgCtxLoad
	.globl	_wdbDbgCtxSave

#if	(DBG_HARDWARE_BP)
	.globl	wdbDbgRegsSet
	.globl	wdbDbgRegsGet
#endif	/* (DBG_HARDWARE_BP) */

/******************************************************************************
*
* _wdbWdbCtxSave - Save the current context of the current task 
*
* Similar to _sigCtxSave but we need to save a little more... This routine
* is used by WDB and by the debugger.
*
* RETURNS: 0

* int _wdbDbgCtxSave
*     (
*     REG_SET *pRegs		/@ Location to save current context @/
*     )

*/

	.ent	_wdbDbgCtxSave
_wdbDbgCtxSave:
	sw	ra, PCREG(a0)		/* save ra to be new PC */
					/* after call to here */
	SW	zero, ZEROREG(a0)
	.set	noat
	SW	AT, ATREG(a0)
	.set	at
	SW	v0, V0REG(a0)
	SW	v1, V1REG(a0)
	SW	a0, A0REG(a0)
	SW	a1, A1REG(a0)
	SW	a2, A2REG(a0)
	SW	a3, A3REG(a0)
	SW	t0, T0REG(a0)
	SW	t1, T1REG(a0)
	SW	t2, T2REG(a0)
	SW	t3, T3REG(a0)
	SW	t4, T4REG(a0)
	SW	t5, T5REG(a0)
	SW	t6, T6REG(a0)
	SW	t7, T7REG(a0)
	SW	s0, S0REG(a0)
	SW	s1, S1REG(a0)
	SW	s2, S2REG(a0)
	SW	s3, S3REG(a0)
	SW	s4, S4REG(a0)
	SW	s5, S5REG(a0)
	SW	s6, S6REG(a0)
	SW	s7, S7REG(a0)
	SW	t8, T8REG(a0)
	SW	t9, T9REG(a0)
	SW	k0, K0REG(a0)
	SW	k1, K1REG(a0)
	SW	gp, GPREG(a0)
	.set	noreorder
	mfc0	t1, C0_SR			/* read SR */
	.set	reorder
	/* sp saved below */
	SW	s8, S8REG(a0)
	SW	ra, RAREG(a0)
	
	SW	sp, SPREG(a0)			/* save stack pointer */
	sw	t1, SRREG(a0)			/* save SR in entirety */
	mflo	t2
	SW	t2, LOREG(a0)
	mfhi	t2
	SW	t2, HIREG(a0)
0:
	move	v0, zero			/* return 0 always */
	j	ra
	.end	_wdbDbgCtxSave

/******************************************************************************
*
* _wdbDbgCtxLoad - Load a new context in the current task
*
* debugger uses this function to restore the state of a task after it's
* hit a breakpoint, so many more things need to be restored than in
* the usual longjmp() case.
*
* Be careful not to reset the stack pointer until you have read
* all the data. Destroying stuff at the end of the stack seems to
* be fair game, this is very true of the debugger.
*
* RETURNS: Never returns

* void _wdbDbgCtxLoad
*     (
*     REG_SET *pRegs		/@ Context to load @/
*     )

*/

	.ent	_wdbDbgCtxLoad
_wdbDbgCtxLoad:
	LW	t2, LOREG(a0)		/* restore lo reg */
	mtlo	t2
	LW	t3, HIREG(a0)		/* restore hi reg */
	mthi	t3
0:	
	LW	v0, V0REG(a0)		/* restore return regs */
	LW	v1, V1REG(a0)
	
	LW	a1, A1REG(a0)		/* restore argument regs (except a0) */
	LW	a2, A2REG(a0)
	LW	a3, A3REG(a0)
	
	LW	t0, T0REG(a0)		/* restore temp regs (except t9) */
	LW	t1, T1REG(a0)
	LW	t2, T2REG(a0)
	LW	t3, T3REG(a0)
	LW	t4, T4REG(a0)
	LW	t5, T5REG(a0)
	LW	t6, T6REG(a0)
	LW	t7, T7REG(a0)
	
	LW	s0, S0REG(a0)		/* restore saved registers */
	LW	s1, S1REG(a0)
	LW	s2, S2REG(a0)
	LW	s3, S3REG(a0)
	LW	s4, S4REG(a0)
	LW	s5, S5REG(a0)
	LW	s6, S6REG(a0)
	LW	s7, S7REG(a0)
	LW	s8, S8REG(a0)
	
	/* restore misc regs */
	LW	ra, RAREG(a0)

	/*
	 * Don't restore gp, it's not saved by _sigCtxSave() and no-one
	 * is supposed to change it anyway.
	 */
	
#ifndef _WRS_R3K_EXC_SUPPORT
	/* ensure that IMASK is clear before enabling EXL */
	li	t9, SR_CU0
	.set	noreorder
	mtc0	t9, C0_SR
	HAZARD_CP_WRITE
	.set	reorder
#endif	/* _WRS_R3K_EXC_SUPPORT */

	lw	t9, SRREG(a0)		/* read old SR */

#ifndef _WRS_R3K_EXC_SUPPORT
	ori	t9, SR_EXL		/* setup EXL for later eret */
#else	/* _WRS_R3K_EXC_SUPPORT */
	/* Shift IEc and KUc bits in the SR left by 2 prior to executing 
	 * the rfe instruction and resuming in the requested context.
	 * wdbDbgArchBreakpoint (wdbDbgArchLib.c) shifted the SR down 
	 * by 2 when we first entered the breakpoint exception. 
	 */
	and	t8, t9,0x00000003
	sll	t8, 2
	and	t9, 0xFFFFFFF0
	or	t9, t8	
#endif
	
	mtc0	t9, C0_SR		/* restore SR (EXL set) */
	HAZARD_CP_WRITE

	/* Interrupts are now disabled. */
	
	/* It's now safe to use k0 and k1 and change the sp. */
	.set	noat
	LW	AT, ATREG(a0)		/* restore AT reg */
	LW	t8, T8REG(a0)		/* restore t8 */
	LW	t9, T9REG(a0)		/* restore t9 */
	lw	k1, PCREG(a0)		/* get pc */
	LW	sp, SPREG(a0)		/* restore stack pointer */
	LW	a0, A0REG(a0)		/* restore a0 */

	.set	noreorder
#ifdef _WRS_R3K_EXC_SUPPORT
	j	k1			/* restart with old state */
	rfe				/* reenable ints if enable
					   previous is set	*/
	nop
#else
	mtc0	k1,C0_EPC		/* set epc */
	HAZARD_ERET
	eret
#endif
	.set	at
	.set	reorder
	.end	_wdbDbgCtxLoad

#if	(DBG_HARDWARE_BP)
/*******************************************************************************
*
* wdbDbgRegsSet - set the R4000/R4650 debug registers
*
* This routine sets the debug registers. 
*
* Note:	for R4650 processors, the C0_IWATCH/C0_DWATCH registers are
* the same register numbers to the C0_WATCHLO/C0_WATCHHI registers on
* R4000. This allows this function to be used without modification or
* recompilation on either processor.
*
* RETURNS : NA

* void wdbDbgRegsSet
*     (
*     REG_SET * pDbgRegs	/@ from where to set debug registers @/
*     )
*
* NOMANUAL
*/

	.ent	wdbDbgRegsSet
wdbDbgRegsSet:
	lw	v0,0(a0)
	mtc0	v0,C0_WATCHLO	/* also: C0_IWATCH */
	lw	v0,4(a0)
	mtc0	v0,C0_WATCHHI	/* also: C0_DWATCH */
	HAZARD_CP_WRITE
	j	ra
	.end	wdbDbgRegsSet

/*******************************************************************************
*
* wdbDbgRegsGet - get the R4000/R4650 debug registers
*
* This routine gets the debug registers.
*
* Note:	for R4650 processors, the C0_IWATCH/C0_DWATCH registers are
* the same register numbers to the C0_WATCHLO/C0_WATCHHI registers on
* R4000. This allows this function to be used without modification or
* recompilation on either processor.
*
* RETURNS : NA

* void wdbDbgRegsGet
*     (
*     REG_SET * pDbgRegs	/@ where to save debug registers @/
*     )
*
* NOMANUAL
*/

	.ent	wdbDbgRegsGet
wdbDbgRegsGet:
	mfc0	v0,C0_WATCHLO	/* also: C0_IWATCH */
	HAZARD_CP_READ
	sw	v0,0(a0)
	mfc0	v0,C0_WATCHHI	/* also: C0_DWATCH */
	HAZARD_CP_READ
	sw	v0,4(a0)
	j	ra
	.end	wdbDbgRegsGet

#endif	/* (DBG_HARDWARE_BP) */
