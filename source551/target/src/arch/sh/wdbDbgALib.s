/* wdbDbgALib.s - SH debugging aids assembly interface */

/* Copyright 1996-2000 Wind River Systems, Inc. */

        .data
        .global _copyright_wind_river
        .long   _copyright_wind_river

/*
modification history
--------------------
01l,22aug00,hk   merge SH7410 and SH7040 to SH7600.
01k,03jun00,hk   fixed assemble error for SH7600.
01j,03apr00,frf  Add SH support for T2:wdbXxx()->wdbDbgXxx()
01i,28mar00,hk   added .type directive to function names.
01h,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01g,21oct98,kab  added hardware breakpoint support.
01g,11may98,jmc  added support for SH-DSP and SH3-DSP.
01f,25apr97,hk   changed SH704X to SH7040.
01e,23feb97,hk   made this file null for SH7700. changed args for
                 wdbArchBreakpoint().
01d,18jan97,hk   code review. deleted _wdbBpStubEnd. made #if simple.
01c,06oct96,wt   added comment.
01b,29sep96,wt   added support for SH7700.
01a,06sep96,wt   written (for SH7600).
*/

/*
DESCRIPTION
This module contains assembly language routines needed for the debug
package and the SH exception vectors.  There are no user-callable
routines here.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "esf.h"


#if	(CPU==SH7600 || CPU==SH7000)

	/* globals */

	.global	_wdbDbgBpStub		/* breakpoint exceptions handler */
	.global	_wdbDbgHwBpStub		/* h/w breakpoint exceptions handler */

	/* imports */

	.extern	_wdbDbgArchBreakpoint	/* breakpoint processing routine */
	.extern _wdbDbgHwBreakpoint	/* h/w breakpoint processing routine */

	.text

/*******************************************************************************
*
* wdbDbgBpStub - breakpoint handling trap
*
* INTERNAL
* On entry, r4 & r5 contain the PC & nPC at time of trap, sp points to area
* in which excEnter saved regs, traps are enabled.
*
* NOMANUAL

* wdbDbgBpStub ()

*/
	.align	_ALIGN_TEXT
	.type	_wdbDbgBpStub,@function

_wdbDbgBpStub:
	add	#-12,sp			/* save pc and sr later */
	mov.l	r15,@sp			/* save r15 */
	mov.l	r14, @-sp
	mov.l	r13, @-sp;	mov.l	r12, @-sp
	mov.l	r11, @-sp;	mov.l	r10, @-sp
	mov.l	r9,  @-sp;	mov.l	r8,  @-sp
	sts.l	macl,@-sp;	sts.l	mach,@-sp
	mov.l	r7,  @-sp;	mov.l	r6,  @-sp
	mov.l	r5,  @-sp;	mov.l	r4,  @-sp
	mov.l	r3,  @-sp;	mov.l	r2,  @-sp
	mov.l	r1,  @-sp;	mov.l	r0,  @-sp
	sts.l	pr,  @-sp
	stc.l	gbr, @-sp;	stc.l	vbr, @-sp

	mov sp,r4			/* load base address */
	add #80,r4			/* r4: ESF */

	mov.l @(0,r4),r5		/* load saved sp */
	add #20,r5			/* fix saved sp */
	mov.l r5,@(0,r4)		/* store saved sp */
	mov.l @(16,r4),r5		/* copy saved sr on interrupt */
	mov.l r5,@(8,r4)

	mov.l @(12,r4),r5		/* load saved pc */
	add #-2,r5			/* fix saved pc - 16 bit OK*/
	mov.l r5,@(4,r4)		/* store saved pc */
	mov.l r5,@(12,r4)		/* store saved pc for rte */
	add #12,r4			/* readjust base address */

	mov	r4,r5			/* XXX r4 should be vecNum */
	mov.l	WdbDbgArchBreakpoint,r0	/* do breakpoint handling */
	jsr	@r0;			/* r5: ESF */
	mov	sp,r6			/* r6: REG_SET */

	add	#8,sp					/* skip vbr&gbr */
	lds.l	@sp+,pr					/* restore pr   */
	mov.l	@sp+,r0;	mov.l	@sp+,r1		/* restore r0/r1 */
	mov.l	@sp+,r2;	mov.l	@sp+,r3		/* restore r2/r3 */
	mov.l	@sp+,r4;	mov.l	@sp+,r5		/* restore r4/r5 */
	mov.l	@sp+,r6;	mov.l	@sp+,r7		/* restore r6/r7 */
	lds.l	@sp+,mach;	lds.l	@sp+,macl	/* restore mach/macl */
	add	#40,sp			/* pop REG_SET off stack */
	rte;
	nop

/*******************************************************************************
*
* wdbDbgHwBpStub - hardware breakpoint handling trap
*
* INTERNAL
* On entry, r4 & r5 contain the PC & nPC at time of trap, sp points to area
* in which excEnter saved regs, traps are enabled.
* For insn breakpoints, only supports break before execution.
*
* This stub code requires the PCBA/PCBB bits in UBC break control register to
* be set zero (break before instruction execution), which is initial default.
*
*  0	|	|    +--- UBC break address register (BARA/BARB)
*	|	|    |
*  pc->	| inst.	| <--+
*	|    \	|          This instruction is not executed at break time.
*             \___________/
*
* NOMANUAL

* wdbDbgHwBpStub ()

*/
	.align	_ALIGN_TEXT
	.type	_wdbDbgHwBpStub,@function

_wdbDbgHwBpStub:
	mov.l r15, @-sp			/* save r15 */
	mov.l r14, @-sp
	mov.l r13, @-sp
	mov.l r12, @-sp
	mov.l r11, @-sp
	mov.l r10, @-sp
	mov.l r9,  @-sp
	mov.l r8,  @-sp
	sts.l macl,@-sp
	sts.l mach,@-sp
	mov.l r7,  @-sp
	mov.l r6,  @-sp
	mov.l r5,  @-sp
	mov.l r4,  @-sp

	mov sp,r4			/* load base address */
	add #56,r4			/* r4 points at ESF */

	mov.l r3,  @-sp
	mov.l r2,  @-sp
	mov.l r1,  @-sp
	mov.l r0,  @-sp
	sts.l pr,  @-sp
	stc.l gbr, @-sp
	stc.l vbr, @-sp

	mov.l WdbDbgHwBreakpoint,r0	/* do breakpoint handling */
	mov r4,r5			/* r4 should be vecNum (ignored) */
	jsr @r0;			/* r5: ESF */
	mov sp,r6			/* r6: REG_SET */

	add #8,sp					/* skip vbr&gbr */
	lds.l @sp+,pr					/* restore pr   */
	mov.l @sp+,r0
	mov.l @sp+,r1
	mov.l @sp+,r2
	mov.l @sp+,r3
	mov.l @sp+,r4
	mov.l @sp+,r5
	mov.l @sp+,r6
	mov.l @sp+,r7
	lds.l @sp+,mach
	lds.l @sp+,macl
	add #32,sp			/* pop REG_SET off stack */
	rte;
	nop
			.align	2
WdbDbgArchBreakpoint:	.long	_wdbDbgArchBreakpoint
WdbDbgHwBreakpoint:	.long	_wdbDbgHwBreakpoint

#endif	/* CPU==SH7600 || CPU==SH7000 */
