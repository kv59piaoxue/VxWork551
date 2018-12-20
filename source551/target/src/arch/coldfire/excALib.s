/* excALib.s - exception handling Coldfire assembly language routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01f,17dec02,dee  fix for SPR 85105
01d,26nov01,dee  remove references to MCF5200
01c,19jun00,ur   Removed all non-Coldfire stuff.
01b,14jun00,dh   include asm.h for DIAB/gnu compatibility macros.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This module contains the assembly language exception handling stub.
It is connected directly to the Coldfire exception vectors.
It sets up an appropriate environment and then calls a routine
in excLib(1).

SEE ALSO: excLib(1)
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

	/* globals */

	.globl	_excStub	/* generic stub routine */
	.globl	_excIntStub	/* uninitialized interrupt handler */
	.extern	__coldfireHasMac

	.text
	.even

/*********************************************************************
*
* excStub - exception handler
*
* When we get here there's an ESF struct on the stack.
* We save room for a register set and save the registers into it.
*
* NOMANUAL
*/

_excStub:

/* Allocate space on the stack for a REG_SET, and save the normal
 * registers in it.
*/
	subl	#SIZEOF_REG_SET,a7
	moveml	d0-d7/a0-a7,a7@

/* Adjust the saved stack pointer so that it points at the ESF, not at the
 * REG_SET.
*/
	movel	#SIZEOF_REG_SET,d0
	addl	d0,a7@(OFF_REG_SP)

/* Copy the SR and PC from the ESF to the REG_SET.
*/
	movel	a7@(SIZEOF_REG_SET+OFF_ESF_EXCSTAT),a7@(OFF_REG_FORMAT)	/* get complete proc status word */
	movel	a7@(SIZEOF_REG_SET+OFF_ESF_PC),a7@(OFF_REG_PC)	/* fill in program counter */

	tstl	__coldfireHasMac
	jeq	excStubEndSaveMac	/* jump if MAC not present */

excStubSaveMac:

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

excStubEndSaveMac:

/* Extract the exception vector offset from the exception status word and
 * convert it to an exception number. That now lives in D0
*/
	movew	a7@(SIZEOF_REG_SET+OFF_ESF_EXCSTAT),d0
	andl	#0x03fc,d0
	lsrl	#2,d0

/* Now call excExcHandle(int, ESF*, REG_SET*) 
*/
	movel	a7,a7@-			/* push pointer to REG_SET */
	pea	a7@(SIZEOF_REG_SET+4)	/* push pointer to exception frame */
	movel	d0,a7@-			/* push exception number */
	jsr	_excExcHandle		/* do exception processing */
	addl	#0xc,a7			/* clean up pushed arguments */

/* Restore registers, clean up and return.
*/
	tstl	__coldfireHasMac
	jeq 	excStubEndRestoreMac		/* jump if no MAC */

	movel	a7@(OFF_REG_MAC),d0		/* restore MAC */
	.word	0xa100				/* movel d0,acc */
	movew	a7@(OFF_REG_MACSR),d0		/* restore MACSR */
	.word	0xa900				/* movel d0,macsr */
	movew	a7@(OFF_REG_MASK),d0		/* restore MASK */
	.word	0xad00				/* movel d0,mask */

excStubEndRestoreMac:
	moveml	a7@,d0-d7/a0-a6		/* restore registers except adj. a7 */
	addl	#SIZEOF_REG_SET,a7	/* pop REG_SET off stack */
	rte				/* return to task that got exception */

/*********************************************************************
*
* excIntStub - uninitialized interrupt handler
*
* NOMANUAL
*/

_excIntStub:
	trap	#1			/* switch to interrupt stack */

	addql	#1,_intCnt		/* from intEnt(); errno saved below */

/* Allocate space for a REG_SET on the stack, and save the registers into it.
*/
	subl	#SIZEOF_REG_SET,a7
	moveml	d0-d7/a0-a7,a7@

/* Adjust the saved stack pointer so that it points to the ESF.
*/
	movel	#SIZEOF_REG_SET,d0
	addl	d0,a7@(OFF_REG_SP)

/* Copy the SR and PC from the ESF to the REG_SET.
*/
	movel	a7@(SIZEOF_REG_SET+OFF_ESF_EXCSTAT),a7@(OFF_REG_FORMAT)	/* get complete proc status word */
	movel	a7@(SIZEOF_REG_SET+OFF_ESF_PC),a7@(OFF_REG_PC)	/* fill in program counter */

	tstl	__coldfireHasMac
	jeq	excIntStubEndSaveMac	/* jump if MAC not present */

excIntStubSaveMac:

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

excIntStubEndSaveMac:

/* Extract the exception vector offset from the exception status word and
 * convert it to an exception number. That now lives in D0
*/
	movew	a7@(SIZEOF_REG_SET+OFF_ESF_EXCSTAT),d0		/* get the vector offset from the esf */
	andl	#0x03fc,d0		/* clear the format */
	lsrl	#2,d0			/* turn vector offset into excep num */

	movel	_errno,a7@-		/* save errno on the stack (intEnt()) */

/* Now call excIntHandle(int, ESF*, REG_SET*)
*/
	pea	a7@(4)			/* push pointer to REG_SET */
	pea	a7@(SIZEOF_REG_SET+8)	/* push pointer to exception frame */
	movel	d0,a7@-			/* push exception number */
	jsr	_excIntHandle		/* do exception processing */
	addl	#0xc,a7			/* clean up pushed arguments */
	movel	a7@+,_errno		/* restore errno */

/* Restore registers, clean up and exit via intExit.
*/
	tstl	__coldfireHasMac
	jeq 	excIntStubEndRestoreMac		/* jump if no MAC */

	movel	a7@(OFF_REG_MAC),d0		/* restore MAC */
	.word	0xa100				/* movel d0,acc */
	movew	a7@(OFF_REG_MACSR),d0		/* restore MACSR */
	.word	0xa900				/* movel d0,macsr */
	movew	a7@(OFF_REG_MASK),d0		/* restore MASK */
	.word	0xad00				/* movel d0,mask */

excIntStubEndRestoreMac:
	moveml	a7@,d0-d7/a0-a6		/* restore registers from REG_SET */
	addl	#SIZEOF_REG_SET,a7	/* discard the REG_SET */
	movel	_errno,a7@-		/* save errno on the stack (intEnt()) */
	jmp	_intExit		/* exit the ISR thru the kernel */

