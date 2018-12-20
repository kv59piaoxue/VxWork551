/* sigCtxALib.s - software signal architecture support library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.text
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01c,09may03,dee  fix SPR 85913
01b,14jun00,dh   include asm.h for diab/gnu compatibility macros.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
This library provides the architecture specific support needed by
software signals.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "regs.h"
#include "esf.h"

	/* internals */

	.globl	__sigCtxLoad
	.globl	__sigCtxSave


	.global _sigsetjmp

/*******************************************************************************
*
* sigsetjmp - set non-local goto with option to save signal mask
*
* This routine saves the current task context and program counter in <env>
* for later use by siglongjmp().   It returns 0 when called.  However, when
* program execution returns to the point at which sigsetjmp() was called and the
* task context is restored by siglongjmp(), sigsetjmp() will then return the
* value <val>, as specified in siglongjmp().
*
* If the value of <savemask> argument is not zero, the sigsetjmp() function
* shall save the current signal mask of the task as part of the calling
* environment.
*
* RETURNS: 0 or <val> if return is via siglongjmp().
*
* SEE ALSO: longjmp()

* int setjmp
*    (
*    jmp_buf env,       /@ where to save stack environment @/
*    int     savemask	/@ whether or not to save the current signal mask @/
*    )

*/
_sigsetjmp:
	movel	a7@(8),a7@-
	movel	a7@(8),a7@-
	jsr	__setjmpSetup
	addl	#8,a7
	jmp	__sigCtxSave

	.global _setjmp

/*******************************************************************************
*
* setjmp - set non-local goto
*
* This routine saves the current task context and program counter in <env>
* for later use by longjmp().   It returns 0 when called.  However, when
* program execution returns to the point at which setjmp() was called and the
* task context is restored by longjmp(), setjmp() will then return the value
* <val>, as specified in longjmp().
*
* RETURNS: 0 or <val> if return is via longjmp().
*
* SEE ALSO: longjmp()

* int setjmp
*    (
*    jmp_buf env        /@ where to save stack environment @/
*    )

*/
_setjmp:
	movel	#1,a7@-
	movel	a7@(8),a7@-
	jsr	__setjmpSetup
	addl	#8,a7

	/* FALL THROUGH */

/*******************************************************************************
*
* _sigCtxSave - Save the current context of the current task
*
* This is just like setjmp except it doesn't worry about saving any sigmask.
* It must also always return 0.
*
* RETURNS: 0

* int _sigCtxSave
*     (
*     REG_SET *pRegs		/@ Location to save current context @/
*     )

*/

__sigCtxSave:
	movel	a7@(4),a0
	movew	sr,d0
	movew	d0,a0@(OFF_REG_SR)		/* SR */
	movew	#$4000,d0
	movew	d0,a0@(OFF_REG_HASMAC)		/*  new format word */
	clrl	d0				/* first return value */
	movel	a7@(0),a1
	movel	a1,a0@(OFF_REG_PC)		/* PC */
	movel	a7,a1
	addql	#4,a1
	movel	a1,a0@(OFF_REG_SP)		/* SP */
	moveml	d1-d7/a0-a6,a0@(OFF_REG_D1)
	rts

/*******************************************************************************
*
* _sigCtxLoad - Load a new context in the current task
*
* This is just like longjmp, but every register must be loaded.
* You could also look at this as half a context switch.
*
* Be careful not to reset the stack pointer until you have read
* all the data. Destroying stuff at the end of the stack seems to
* be far game, this is very true of the debugger.
*
* RETURNS: Never returns

* void _sigCtxLoad
*     (
*     REG_SET *pRegs		/@ Context to load @/
*     )

*/

__sigCtxLoad:
	movel	a7@(4),a0		/* a0:	REG_SET pointer */
	movel	a0@(OFF_REG_SP),a1	/* a1:	new stack pointer */
	movel	a0@(OFF_REG_PC),a1@-	/* push new pc */
	movew	a0@(OFF_REG_SR),a1@-	/* push new sr */
	movew	a0@(OFF_REG_HASMAC),a1@-	/* push format word */
	movel	a1,a7@-
	moveml	a0@,d0-d7/a0-a6
	movel	a7@,a7
	rte
