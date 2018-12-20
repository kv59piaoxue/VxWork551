/* dbgALib.s - SH debugging aids assembly interface */

/* Copyright 1994-2000 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01m,21aug00,hk   merge SH7040 and SH7410 to SH7600.
01l,28mar00,hk   added .type directive to function names.
01k,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01j,04jun99,zl   changed copyright data
01i,12may98,jmc  added support for SH-DSP and SH3-DSP.
01h,25apr97,hk   changed SH704X to SH7040.
01g,18jan97,hk   made this file null for SH7700.
01f,15feb95,hk   added but disabled CLEAR_BRCR_CMF section. copyright 1995.
01e,21dec94,hk   added _dbgHwBpStub for UBC support.
01d,08dec94,hk   fixed pc backstep number.
01c,06dec94,hk   writing stub code. (pc/sr has been swapped in REG_SET)
01b,01dec94,hk   included archPortKit docs, updated copyright.
01a,09oct94,hk   written based on sparc 01p.
*/

/*
DESCRIPTION
This module contains assembly language routines needed for the debug
package and the SH exception vectors.  There are no user-callable
routines here.

INTERNAL
The assembly-language stubs connected by _dbgVecInit() are in this library.
Most architectures will have at least a breakpoint trap, possibly a trace
trap, and maybe additional debugger support via a trapping mechanism.

INTERNAL
The SH architecture supports a software breakpoint trap, and a special
hardware breakpoint mechanism called UBC (User Break Controller).
However, trace trap is not supported.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "esf.h"

#if	(CPU==SH7600 || CPU==SH7000)

	/* internal */

	.global	_dbgBpStub		/* breakpoint exceptions handler */
	.global	_dbgHwBpStub		/* hardware breakpoint handler   */

	/* external */

	.global	_dbgBreakpoint		/* breakpoint processing routine */
/*	.global	_excStub		/* exception handling routine */
/*	.global	_excExit		/* trap exit routine */

	.text
	.align	_ALIGN_TEXT

#undef	CLEAR_BRCR_CMF			/* define if clear CMFs in stub. */

/*******************************************************************************
*
* dbgBpStub - breakpoint handling trap
*
* INTERNAL
* On entry, %l1 & %l2 contain the PC & nPC at time of trap, %sp points to area
* in which excEnter saved regs, traps are enabled.
*
* INTERNAL
* The breakpoint stub is called by excEnter(), creates the BREAK_ESF structure,
* and calls dbgBreakpoint(). The arguments to dbgBreakpoint() are pointers to
* the BREAK_ESF structure and to the stacked register set, respectively. Depend-
* ing on the architecture, the state of the processor and the stack frame may
* have to be adjusted for this special type of execution. [Arch Port Kit]
*
* INTERNAL
* dbgBreakpoint() only returns to the stub if the breakpoint was hit at inter-
* rupt level. The stack frame must be cleaned up and a return-from-exception
* executed. This may be done directly, or a call to excExit() may be more
* appropriate. [Arch Port Kit]
*
* NOMANUAL

* dbgBpStub ()

* INTERNAL
*
*  0	|	|
*	|	|
*	|	|
*	| trapa	| --> the original instruction here is not executed.
*  pc->	|	|     To continue the program, do the following:
*	|	|	1) decrement pc to the trapped point (dbgBpStub).
*	|	|	2) restore the original instruction.
*	|	|	3) resume program from the trapped point.
*
*
*                  |        |
*                  |________|
*               88 |   sr   |
*           ESF 84 |__ pc __| +44  +56  +32
*               80 |  r15   | +40  +52  +28
*               76 |  r14   | +36  +48  +24
*               72 |  r13   | +32  +44  +20
*               68 |  r12   | +28  +40  +16
*               64 |  r11   | +24  +36  +12
*               60 |  r10   | +20  +32  +8
*               56 |   r9   | +16  +28  +4
*               52 |   r8   | +12  +24  +0
*               48 |  macl  | +8   +20
*               44 |  mach  | +4   +16
*        sp ->  40 |   r7   | +0   +12
*               36 |   r6   |      +8
*               32 |   r5   |      +4
*               28 |   r4   |      +0
*               24 |   r3   |
*               20 |   r2   |
*               16 |   r1   |      +--------+
*               12 |   r0   |   r5 |REG_SET*|
*                8 |   pr   |      +--------+
*                4 |   gbr  |   r4 |  ESF * |
*       REG_SET  0 |__ vbr _|      +--------+
*                  |        |
*
* The REG_SET overlaps ESF on purpose.  This design is slightly different from
* the case in excLib.  We just follow the mc68k design, this is better anyway.
*/
	.type	_dbgBpStub,@function

_dbgBpStub:
	mov.l	sp,  @-sp		/* save r15  (verified this to work) */
	mov.l	r14, @-sp		/* save r14  */
	mov.l	r13, @-sp		/* save r13  */
	mov.l	r12, @-sp		/* save r12  */
	mov.l	r11, @-sp		/* save r11  */
	mov.l	r10, @-sp		/* save r10  */
	mov.l	r9,  @-sp		/* save r9   */
	mov.l	r8,  @-sp		/* save r8   */
	sts.l	macl,@-sp		/* save macl */
	sts.l	mach,@-sp		/* save mach */
	mov.l	r7,  @-sp		/* save r7   */

	mov.l	@(44,sp),r7		/* fetch pc on ESF                  */
	add	#-2, r7			/* step backwards to the trap front */
	mov.l	r7,@(44,sp)		/* adjust saved program counter     */

	mov.l	r6,  @-sp		/* save r6   */
	mov.l	r5,  @-sp		/* save r5   */
	mov.l	r4,  @-sp		/* save r4   */

	mov	sp,  r4
	add	#56, r4			/* r4 points at ESF */

	mov.l	r3,  @-sp		/* save r3   */
	mov.l	r2,  @-sp		/* save r2   */
	mov.l	r1,  @-sp		/* save r1   */
	mov.l	r0,  @-sp		/* save r0   */
	sts.l	pr,  @-sp		/* save pr   */
	stc.l	gbr, @-sp		/* save gbr  */
	stc.l	vbr, @-sp		/* save vbr  */

	mov.l	DbgBreakpoint,r0	/* do breakpoint handling      */
	jsr	@r0			/*   r4: ESF*                  */
	mov	sp,  r5			/*   r5: REG_SET* (delay slot) */

	/* we only return if the breakpoint was hit at interrupt level */

	add	#8,sp			/* skip vbr&gbr */
	lds.l	@sp+,pr			/* restore pr   */
	mov.l	@sp+,r0			/* restore r0   */
	mov.l	@sp+,r1			/* restore r1   */
	mov.l	@sp+,r2			/* restore r2   */
	mov.l	@sp+,r3			/* restore r3   */
	mov.l	@sp+,r4			/* restore r4   */
	mov.l	@sp+,r5			/* restore r5   */
	mov.l	@sp+,r6			/* restore r6   */
	mov.l	@sp+,r7			/* restore r7   */
	lds.l	@sp+,mach		/* restore mach */
	lds.l	@sp+,macl		/* restore macl */
	add	#32,sp			/* pop REG_SET off stack (except ESF) */
	rte				/* resume from the trapped point      */
	nop				/* (delay slot) */

/*******************************************************************************
*
* dbgHwBpStub - hardware breakpoint handler
*
* NOMANUAL
*
* INTERNAL
*
* This stub code requires the PCBA/PCBB bits in UBC break control register to
* be set zero (break before instruction execution), which is initial default.
*
*  0	|	|    +--- UBC break address register (BARA/BARB)
*	|	|    |
*  pc->	| inst.	| <--+
*	|    \	|          This instruction is not executed at break time.
*             \___________/
*/
	.align	_ALIGN_TEXT
	.type	_dbgHwBpStub,@function

_dbgHwBpStub:
	mov.l	sp,  @-sp		/* save r15  (verified this to work) */
	mov.l	r14, @-sp		/* save r14  */
	mov.l	r13, @-sp		/* save r13  */
	mov.l	r12, @-sp		/* save r12  */
	mov.l	r11, @-sp		/* save r11  */
	mov.l	r10, @-sp		/* save r10  */
	mov.l	r9,  @-sp		/* save r9   */
	mov.l	r8,  @-sp		/* save r8   */
	sts.l	macl,@-sp		/* save macl */
	sts.l	mach,@-sp		/* save mach */
	mov.l	r7,  @-sp		/* save r7   */

/*	mov.l	@(44,sp),r7		/@ fetch pc on ESF                  */
/*	add	#-2, r7			/@ step backwards to the trap front */
/*	mov.l	r7,@(44,sp)		/@ adjust saved program counter     */

	mov.l	r6,  @-sp		/* save r6   */
	mov.l	r5,  @-sp		/* save r5   */
	mov.l	r4,  @-sp		/* save r4   */

	mov	sp,  r4
	add	#56, r4			/* r4 points at ESF */

	mov.l	r3,  @-sp		/* save r3   */
	mov.l	r2,  @-sp		/* save r2   */
	mov.l	r1,  @-sp		/* save r1   */
	mov.l	r0,  @-sp		/* save r0   */
	sts.l	pr,  @-sp		/* save pr   */
	stc.l	gbr, @-sp		/* save gbr  */
	stc.l	vbr, @-sp		/* save vbr  */

#ifdef	CLEAR_BRCR_CMF
	mov.l	BRCR_ADDRESS,r1
	mov.w	@r1,r0
	mov.l	BRCR_MASK,r2
	and	r2,r0
	mov.w	r0,@r1
#endif	/* CLEAR_BRCR_CMF */

	mov.l	DbgBreakpoint,r0	/* do breakpoint handling      */
	jsr	@r0			/*   r4: ESF*                  */
	mov	sp,  r5			/*   r5: REG_SET* (delay slot) */

	/* we only return if the breakpoint was hit at interrupt level */

	add	#8,sp			/* skip vbr&gbr */
	lds.l	@sp+,pr			/* restore pr   */
	mov.l	@sp+,r0			/* restore r0   */
	mov.l	@sp+,r1			/* restore r1   */
	mov.l	@sp+,r2			/* restore r2   */
	mov.l	@sp+,r3			/* restore r3   */
	mov.l	@sp+,r4			/* restore r4   */
	mov.l	@sp+,r5			/* restore r5   */
	mov.l	@sp+,r6			/* restore r6   */
	mov.l	@sp+,r7			/* restore r7   */
	lds.l	@sp+,mach		/* restore mach */
	lds.l	@sp+,macl		/* restore macl */
	add	#32,sp			/* pop REG_SET off stack (except ESF) */
	rte				/* resume from the trapped point      */
	nop				/* (delay slot) */

/*******************************************************************************
*
* dbgTraceStub - trace exception processing
*
* INTERNAL
* The trace stub is called by excEnter(), creates the TRACE_ESF structure, and
* calls dbgTrace(). The arguments to dbgBreakpoint() are pointers to the TRACE_
* ESF structure and to the stacked register set, respectively. Depending on the
* architecture, the state of the processor and the stack frame may have to be
* adjusted for this special type of exception. [Arch Port Kit]
*
* INTERNAL
* dbgTrace() returns to the stub if the trace was hit at interrupt level. The
* stack frame must be cleaned up and a return-from-exception executed. This may
* be done directly, or a call to excExit() may be more appropriate. [Arch Port
* Kit]
*
* NOMANUAL
*/
		.align	2
DbgBreakpoint:	.long	_dbgBreakpoint

#ifdef	CLEAR_BRCR_CMF
BRCR_ADDRESS:	.long	0xffffff78	/* SH7600 */
BRCR_MASK:	.long	0x00003f3f	/* to clear BRCR Compare Match Flags */
#endif	/* CLEAR_BRCR_CMF */

#endif	/* CPU==SH7600 || CPU==SH7000 */
