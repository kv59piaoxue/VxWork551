/* vxALib.s - miscellaneous assembly language routines */

/* Copyright 1996-1998 Wind River Systems, Inc. */
/*
modification history
--------------------
01h,17oct01,t_m  convert to FUNC_LABEL:
01g,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01f,08sep98,jpd  moved mmuReadId here from mmuALib.s;
	    cdp	 make Thumb support dependent on ARM_THUMB.
01e,27oct97,kkk  took out "***EOF***" line from end of file.
01d,23sep97,cdp  removed kludges for old Thumb tool-chains.
01c,18jun97,cdp  added Thumb (ARM7TDMI_T) support;
		 added 2 byte support for ARM710A to vxMemProbeSup.
01b,03mar97,jpd  tidied comments/documentation.
01a,03jul96,cdp  written.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines.

SEE ALSO: vxLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "private/taskLibP.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

	/* globals */

	.globl	FUNC(vxTas)
	.globl FUNC(vxMemProbeSup)
	.globl FUNC(vxTaskEntry)
#if (ARM_THUMB)
	.globl	FUNC(arm_call_via_r2)
	.globl	FUNC(arm_call_via_r12)
#endif
	.globl	FUNC(mmuReadId)		/* Read MMU ID Register */


	/* externs */

	.extern	FUNC(exit)
	.extern	FUNC(taskIdCurrent)
#if (ARM_THUMB)
	.extern	FUNC(_call_via_ip)
#endif


	.text
	.balign 4

/*******************************************************************************
*
* vxTas - this routine performs the atomic test and set for the ARM arch.
*
* This routine provides a C-callable interface to a test-and-set
* instruction.  The test-and-set instruction is executed on the specified
* address.  The architecture test-and-set instruction is SWPB.
*
* RETURNS:
* TRUE if value had been not set, but is now
* FALSE if value was already set

* BOOL vxTas(address)
*     char *	address		/@ address to be tested @/

*/

_ARM_FUNCTION_CALLED_FROM_C(vxTas)

	MOV	r1, #1
	SWPB	r1, r1, [r0]
	AND	r1, r1, #1	/* LS bit only */
	EOR	r0, r1, #1	/* if was set, return 0 else return 1 */
#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* vxMemProbeSup - vxMemProbe support routine
*
* This routine is called to try to read byte, word, or long, as specified
* by length, from the specified source to the specified destination.
*
* NOMANUAL

STATUS vxMemProbeSup (length, src, dest)
    (
    int 	length,	/@ length of cell to test (1, 2, 4) @/
    char *	src,	/@ address to read @/
    char *	dest	/@ address to write @/
    )

*/

_ARM_FUNCTION_CALLED_FROM_C(vxMemProbeSup)

/* establish stack frame */

	MOV	ip, sp
	STMDB	sp!, {fp,ip,lr,pc}
	SUB	fp, ip, #4

/* preset r3 to an OK result */

	MOV	r3, #0		/* result = 0 */

/* copy 1/2/4 bytes from src to dest, according to length arg */

	TEQS	r0, #1
	LDREQB	r1, [r1]
	STREQB	r1, [r2]

	TEQS	r0, #2
#if ARM_HAS_HALFWORD_INSTRUCTIONS
	.long	0x01D110B0	/* LDREQH r1, [r1] */
	.long	0x01C210B0	/* STREQH r1, [r2] */
#else
	TEQS	r0, #2
	LDREQB	r12, [r1], #1
	STREQB	r12, [r2], #1
	LDREQB	r12, [r1], #1
	STREQB	r12, [r2], #1
#endif
	TEQS	r0, #4
	LDREQ	r1, [r1]
	STREQ	r1, [r2]

/* if an exception occurred, r3 will have been overwritten with ERROR */

	MOV	r0, r3		/* return result */
#if (ARM_THUMB)
	LDMDB	fp, {fp,sp,lr}
	BX	lr
#else
	LDMDB	fp, {fp,sp,pc}
#endif

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
* INTERNAL
* This function is interruptible.
*
* NOMANUAL

* void vxTaskEntry (void)

*/

#if (ARM_THUMB)

_THUMB_FUNCTION(vxTaskEntry)

/*
 * This used to use the ARM code with a veneer to switch from Thumb
 * state to ARM state but, unfortunately, certain tests create a context
 * and step it and that won't work. Consequently, this has been rewritten
 * (with loss of efficiency) in Thumb code.
 *
 * Prepare to call a ten argument function using the args written to the
 * base of the stack during task creation
 * Although r3-r7 probably contain zero at this point and we could
 * use them, it's safest not to rely on that.
 *
 */

	LDR	r3, L$_taskIdCurrent
	LDR	r3, [r3]			/* r3 -> TCB */

/* make space for args on stack */

	SUB	sp, #6*4			/* make space for 6 args */
	MOV	r2, sp				/* r2->where args will go */
	PUSH	{r4-r7}				/* save some regs */

/* put entry point in r12 */

	LDR	r0, [r3, #WIND_TCB_ENTRY]
	MOV	r4, #1				/* force Thumb state */
	ORR	r0, r4
	MOV	r12, r0

/* zero fp so tt won't trace back to here - otherwise we could do this in C */

	MOV	r0, #0
	MOV	fp, r0

/* copy the last six arguments from the base of the stack */

	LDR	r3, [r3, #WIND_TCB_PSTACKBASE]
	SUB	r3, #6*4			/* r3 -> last 6 args */
	LDMIA	r3!, {r0-r1,r4-r7}		/* copy 6 args to stack */
	STMIA	r2!, {r0-r1,r4-r7}
	SUB	r3, #10*4			/* r3 -> first 4 args */
	LDMIA	r3!, {r0-r2}			/* first 4 in regs */
	LDR	r3, [r3]

/* call the task's entry point */

	POP	{r4-r7}
	BL	FUNC(_call_via_ip)

/*
 * returns in Thumb state
 *
 * pass the returned value to exit()
 * should not need to force call to exit() in Thumb state because linker
 * should fix this up, if necessary.
 */

	BL	FUNC(exit)
	B	.				/* loop forever */
#else

_ARM_FUNCTION(vxTaskEntry)

	LDR	r12, L$_taskIdCurrent
	LDR	r12, [r12]			/* r12->TCB */

/*
 * prepare to call a ten argument function using the args written to the
 * base of the stack during task creation
 */

	LDR	r3, [r12, #WIND_TCB_PSTACKBASE]
	LDMDB	r3!, {r0-r2}			/* copy 3 args to stack */
	STMFD	sp!, {r0-r2}
	LDMDB	r3!, {r0-r2}			/* copy 3 more to stack */
	STMFD	sp!, {r0-r2}
	LDMDB	r3, {r0-r3}			/* first 4 in regs */

/* zero fp so tt won't trace back to here - otherwise we could do this in C */

	MOV	fp, #0

/* call the task's entry point */

	MOV	lr, pc
	LDR	pc, [r12, #WIND_TCB_ENTRY]

/* pass the returned value to exit() */

	BL	FUNC(exit)				/* should not return */
	B	.				/* loop forever */

#endif	/* (ARM_THUMB) */

/******************************************************************************/

#if (ARM_THUMB)

_ARM_FUNCTION(arm_call_via_r2)
	BX	r2

_ARM_FUNCTION(arm_call_via_r12)
	BX	r12

#endif	/* (ARM_THUMB) */

/*******************************************************************************
*
* mmuReadId - read the MMU ID register (ARM)
*
* This routine reads the MMU ID register to return the processor ID. If
* the CPU does not, in fact, have an MMU coprocessor, then this will
* cause an undefined instruction exception.  If this routine is to be run
* on a system that might not have an MMU coprocessor, then the undefined
* instruction exception should be trapped.
*
* RETURNS: the ID register of the System Control Coprocessor
*
* UINT32 mmuReadId (void)
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuReadId)

/*
 * Read coprocessor register 0 (the ID register) from the MMU coprocessor
 * into ARM register 0
 */

	MRC	CP_MMU, 0, r0, c0, c0, 0


/* Return (with value read in r0) */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/******************************************************************************/

	.balign	4

/* PC-relative-addressable symbols - LDR Rn, =sym was/is broken */

L$_taskIdCurrent:	.long	FUNC(taskIdCurrent)
