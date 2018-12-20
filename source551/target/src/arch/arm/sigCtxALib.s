/* sigCtxALib.s - software signal architecture support library */

/* Copyright 1996-1998 Wind River Systems, Inc. */

/*
modification history
--------------------
01h,04nov01,tpw  Add missing .text directives after recent addition of .data.
01g,17oct01,t_m  convert to FUNC_LABEL:
01f,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01e,03sep98,cdp  make Thumb support dependent on ARM_THUMB.
01d,27oct97,kkk  took out "***EOF***" line from end of file.
01c,23sep97,cdp  removed surplus '.code 32'.
01b,16apr97,cdp  added Thumb (ARM7TDMI_T) support.
01a,09jul96,cdp  written.
*/

/*
This library provides the architecture specific support needed by
software signals.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "regs.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

	/* globals */

	.globl	FUNC(sigsetjmp)
	.globl	FUNC(setjmp)
	.globl	FUNC(_sigCtxLoad)
	.globl	FUNC(_sigCtxSave)


	/* externals */

	.extern	FUNC(_setjmpSetup)

	.text
	.balign 4

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

#if (ARM_THUMB)
_THUMB_FUNCTION(sigsetjmp)

	PUSH	{r0,r1}		/* save parms and link */
	PUSH	{lr}
	BL	FUNC(_setjmpSetup)
	POP	{r0}		/* restore lr */
	MOV	lr,r0
	POP	{r0,r1}
	B	FUNC(_sigCtxSave)
#else
_ARM_FUNCTION(sigsetjmp)

	STMFD	sp!,{r0,r1,lr}	/* save parms and link */
	BL	FUNC(_setjmpSetup)
	LDMFD	sp!,{r0,r1,lr}
	B	FUNC(_sigCtxSave)
#endif

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

#if (ARM_THUMB)
_THUMB_FUNCTION(setjmp)

	PUSH	{r0}
	PUSH	{lr}
	MOV	r1,#1
	BL	FUNC(_setjmpSetup)
	POP	{r0}		/* restore lr */
	MOV	lr,r0
	POP	{r0}
	B	FUNC(_sigCtxSave)	/* to avoid alignment problems */
#else
_ARM_FUNCTION(setjmp)

	STMFD	sp!,{r0,lr}
	MOV	r1,#1
	BL	FUNC(_setjmpSetup)
	LDMFD	sp!,{r0,lr}
	/* FALL THROUGH */
#endif

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

_ARM_FUNCTION_CALLED_FROM_C(_sigCtxSave)

	STR	lr,[r0,#REG_SET_PC_OFFSET]	/* save PC */
	MRS	lr,cpsr				/* save PSR */
#if (ARM_THUMB)
	ORR	lr,lr,#T_BIT			/* Thumb state */
#endif
	STR	lr,[r0,#REG_SET_CPSR_OFFSET]
	STMIB	r0,{r1-r13}			/* save R1..SP in REG_SET */
	LDR	lr,[r0,#REG_SET_PC_OFFSET]	/* get return address */
	MOV	r0,#0				/* return 0 */
#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc,lr
#endif

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

_ARM_FUNCTION_CALLED_FROM_C(_sigCtxLoad)

	LDR	lr,[r0,#REG_SET_CPSR_OFFSET]	/* reload PSR */
	MSR	spsr,lr
	LDMIA	r0,{r0-r12,sp,lr,pc}^
