/* wdbDbgALib.s - debugging aids assembly language interface */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01c,26nov02,dee  fix SPR# 85105
01b,26nov01,dee  remove tests for MCF5200
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This module contains assembly language routines needed for the debug
package and the 680x0 exception vectors.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "regs.h"
#include "esf.h"

/*
NOTE:
The following define is used to fix a stack frame problem during
an exception.  The stack format portion of the exception frame
needs to be saved in the tcb.  The field in the TCB we will use is

#define WIND_TCB_HASMAC         (WIND_TCB_REGS+OFF_REG_HASMAC)

WIND_TCB_HASMAC is not needed to determine is a MAC is on chip.
Therefore WIND_TCB_HASMAC is going to be used to record the upper
16 bits of the processor status word which contains the stack frame
format information.  This is needed to clean up the stack upon return
from exception.
*/

#define OFF_REG_FORMAT OFF_REG_HASMAC   /* use HASMAC offset in TCB. */

	/* internal */

	.globl	_wdbDbgBpStub		/* breakpoint exceptions handler */
	.globl	_wdbDbgTraceStub	/* trace exceptions handler */

	/* external */

	.globl	_wdbDbgBreakpoint	/* breakpoint processing routine */
	.globl	_wdbDbgTrace		/* trace processing routine */

	.text
	.even

/****************************************************************************
*
* wdbDbgBpStub - breakpoint handling
*
* This routine is attached to the breakpoint trap (default trap #2).  It
* saves the entire task context on the stack and calls wdbDbgBreakpoint () to
* handle the event.
*
* NOMANUAL
*/

_wdbDbgBpStub:		/* breakpoint interrupt driver */

/* Allocate space on the stack for a REG_SET, and save the normal
 * registers in it.
*/
	subl	#SIZEOF_REG_SET,a7
	moveml	d0-d7/a0-a7,a7@

/* Copy the SR and PC from the ESF to the REG_SET.
*/
	movel	a7@(SIZEOF_REG_SET+OFF_ESF_EXCSTAT),a7@(OFF_REG_FORMAT)	/* get complete proc status word */
	movel	a7@(SIZEOF_REG_SET+OFF_ESF_PC),a7@(OFF_REG_PC)	/* fill in program counter */

/* Adjust the saved stack pointer and program counter so that they are exactly
 * as they were before the breakpoint was executed.
*/
	movel	#SIZEOF_REG_SET+8,d0
	addl	d0,a7@(OFF_REG_SP)
	subql	#0x2,a7@(OFF_REG_PC)

	tstl	__coldfireHasMac
	jeq 	bpStubEndSaveMac		/* jump if MAC not present */

bpStubSaveMac:

/* The MAC instructions are coded here using .word directives, because
 * we have to assemble them with the machine flags of a machine that
 * doesn't have a MAC.
*/
	.word	0xa180				/* movel acc,d0 */
	movel	d0,a7@(OFF_REG_MAC)		/* save MAC */
	.word	0xa980				/* movel macsr,d0 */
	movew	d0,a7@(OFF_REG_MACSR)		/* save MACSR */
	.word	0xad80				/* movel mask,d0 */
	movew	d0,a7@(OFF_REG_MASK)		/* save MASK */

bpStubEndSaveMac:
	movel	a7,a5			/* a5 points to saved regs */
	link	a6,#0

	movel   #0,a7@-			/* push FALSE (not a hardware bp) */
	movel   #0,a7@-			/* push NULL (no debug registers) */
	movel	a5,a7@-			/* push pointer to saved regs */
	pea	a5@(76)			/* push pointer to saved info */
	jsr	_wdbDbgBreakpoint	/* do breakpoint handling */

/**************************************************************************
*
* wdbDbgTraceStub - trace exception processing
*
* This routine is attached to the 68k trace exception vector.  It saves the
* entire task context on the stack and calls wdbDbgTrace () to handle the event.
*
* NOMANUAL
*/

_wdbDbgTraceStub:			/* trace interrupt driver */

/* Allocate space on the stack for a REG_SET, and save the normal
 * registers in it.
*/
	subl	#SIZEOF_REG_SET,a7
	moveml	d0-d7/a0-a7,a7@

/* Copy the SR and PC from the ESF to the REG_SET, clearing the trace bit
 * in the SR on the way..
*/
	movel	a7@(SIZEOF_REG_SET+OFF_ESF_EXCSTAT),d0
	andl	#0xffff7fff,d0
	movel	d0,a7@(OFF_REG_FORMAT)
	movel	a7@(SIZEOF_REG_SET+OFF_ESF_PC),a7@(OFF_REG_PC)

/* Adjust the saved stack pointer so that it is exactly as it was before
 * the trace was executed.
*/
	movel	#SIZEOF_REG_SET+8,d0
	addl	d0,a7@(OFF_REG_SP)

	tstl	__coldfireHasMac
	jeq 	traceStubEndSaveMac	/* jump if MAC not present */

traceStubSaveMac:

/* The MAC instructions are coded here using .word directives, because
 * we have to assemble them with the machine flags of a machine that
 * doesn't have a MAC.
*/
	.word	0xa180				/* movel acc,d0 */
	movel	d0,a7@(OFF_REG_MAC)		/* save MAC */
	.word	0xa980				/* movel macsr,d0 */
	movew	d0,a7@(OFF_REG_MACSR)		/* save MACSR */
	.word	0xad80				/* movel mask,d0 */
	movew	d0,a7@(OFF_REG_MASK)		/* save MASK */

traceStubEndSaveMac:
	movel	a7,a5			/* a5 points to saved regs */
	link	a6,#0

	movel	a5,a7@-			/* push pointer to saved regs */
	pea	a5@(76)			/* push pointer to saved info */
	jsr	_wdbDbgTrace		/* do breakpoint handling */
