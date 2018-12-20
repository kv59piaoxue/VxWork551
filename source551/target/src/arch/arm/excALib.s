/* excALib.s - exception handling ARM assembly language routines */

/* Copyright 1996-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01m,17oct01,t_m  "test FUNC_LABEL"
01l,11oct01,jb   Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01l,25sep01,rec  archv5 support
01k,23jul01,scm  change XScale name to conform to coding standards...
01j,04may01,scm  add STRONGARM support...
01i,11dec00,scm  replace references to ARMSA2 with XScale
01h,13nov00,scm  modify for SA2
01g,06jul99,cdp  insert NOP after LDM to user bank (SPR #28011).
01f,20jan99,cdp  removed support for old ARM libraries.
01e,06jul98,cdp  added support for generic ARCH3/4/4_T.
01d,27oct97,kkk  took out "***EOF***" line from end of file.
01c,23sep97,cdp  removed kludges for old Thumb tool-chains.
01b,26mar97,cdp  added (Thumb) ARM7TDMI_T support, new BTZ code, IMB handling.
01a,09may96,cdp  written.
*/

/*
DESCRIPTION
This module contains the assembly-language exception-handling stubs
which are connected directly to the ARM exception vectors. Each stub
sets up an appropriate environment and then calls a routine in
excArchLib(1).


SEE ALSO: excArchLib(1)
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "arch/arm/excArmLib.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

/*
 * ARM_BUG_ABORT_ENTERS_SWI controls assembly of code to counter
 * incorrect prefetch abort response in ARM7 core.
 */

#if 	(CPU == ARMARCH3)
#define	ARM_BUG_ABORT_ENTERS_SWI 1
#else
#define	ARM_BUG_ABORT_ENTERS_SWI 0
#endif	/* CPU == ARMARCH3 */


	/* globals */

	.globl	FUNC(armInitExceptionModes)	/* initialise ARM modes */
	.globl	FUNC(excEnterUndef)		/* undefined instruction handler */
	.globl	FUNC(excEnterSwi)		/* software interrupt handler */
	.globl	FUNC(excEnterPrefetchAbort)	/* prefetch abort handler */
	.globl	FUNC(excEnterDataAbort)	/* data abort handler */


	/* externs */

	.extern	FUNC(excExcContinue)
#if (ARM_THUMB)
	.extern	FUNC(arm_call_via_r12)
#endif


	.data
	.balign	4

/*
 * Save areas for ARM exception modes.
 * Note: the r13 of the relevant exception mode points to the start
 * of the save area - this is not a stack.
 */

FUNC_LABEL(undefSaveArea) .fill	6,4	/* 6 registers: SPSR,r0-r3,lr */
FUNC_LABEL(abortSaveArea) .fill	6,4	/* 6 registers: SPSR,r0-r3,lr */
FUNC_LABEL(swiSaveArea)	.fill	6,4	/* 6 registers: SPSR,r0-r3,lr */

/*
 * ARM IRQ stack
 * Note: this very small stack is only used between the call to excVecInit
 * and the call to windIntStackSet during kernel startup. windIntStackSet
 * replaces it completely. FIQ is not handled by VxWorks so no FIQ-mode stack
 * is allocated.
 */

		.fill	6*2,4	/* 6 registers: SPSR,r0-r3,lr */
FUNC_LABEL(irqStack)


	.text
	.balign	4

#if	ARM_BUG_ABORT_ENTERS_SWI
/*
 * The following is a packed table of 16 entries used to determine
 * whether a particular instruction should be executed, depending on its
 * condition field and the PSR flags. To see how it's used, see the SWI
 * handling code.
 */

L$ccTable:
        .long     0x0F0FF0F0,0x3333CCCC,0x00FFFF00,0x5555AAAA
        .long     0x3030CFCF,0xAA5555AA,0xA0505FAF,0xFFFF0000

#endif	/* ARM_BUG_ABORT_ENTERS_SWI */


/* PC-relative-addressable symbols - LDR Rn,=sym is broken */

L$_undefSaveArea:	.long	FUNC(undefSaveArea)
L$_abortSaveArea:	.long	FUNC(abortSaveArea)
L$_swiSaveArea:		.long	FUNC(swiSaveArea)
L$_irqStack:		.long	FUNC(irqStack)
#if (ARM_THUMB)
L$_excExcContinue:	.long	FUNC(excExcContinue)
#endif

/*******************************************************************************
*
* armInitExceptionModes - initialise ARM exception modes
*
* This routine initialises the registers for the ARM exception modes.
*

* void armInitExceptionModes (void)

* INTERNAL
* The SP used by exception modes does not point to a (full-descending)
* stack but to an area just big enough to hold critical registers before
* the processor is switched to SVC mode for exception processing. The SP
* of the exception mode must be left pointing to the base of this area and
* the values in that area must be copied out so that the next exception can
* use it.
*
* Entered in SVC32 mode.
*/

_ARM_FUNCTION_CALLED_FROM_C(armInitExceptionModes)

	MRS	r0,cpsr
	BIC	r1,r0,#MASK_MODE
	ORR	r1,r1,#I_BIT

/*
 * switch to each mode in turn with interrupts disabled and set SP
 * r0 = original CPSR
 * r1 = CPSR with IRQ/FIQ disabled and mode bits clear
 */

	ORR	r2,r1,#MODE_UNDEF32	/* do UNDEF mode */
	MSR	cpsr,r2
	LDR	sp,L$_undefSaveArea

	ORR	r2,r1,#MODE_ABORT32	/* do ABORT mode */
	MSR	cpsr,r2
	LDR	sp,L$_abortSaveArea

	ORR	r2,r1,#MODE_IRQ32	/* do IRQ mode */
	MSR	cpsr,r2
	LDR	sp,L$_irqStack

/* back to SVC mode */

	MSR	cpsr,r0

/*
 **** INTERRUPTS RESTORED
 *
 * zero usr_sp - it should never be used
 */

	MOV	r1,#0
	STMFD	sp!,{r1}
	LDMFD	sp,{sp}^		/* Writeback prohibited */
	NOP				/* required */
	ADD	sp,sp,#4		/* correct SP */
#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc,lr
#endif

/**************************************************************************
*
* excEnterSwi - enter a Software Interrupt exception
*
* This routine is installed on the Software Interrupt vector by excVecInit.
*
* This routine can NEVER be called from C.
*
* SEE ALSO: excVecInit(2)

* void excEnterSwi ()

* INTERNAL
* MODE = SVC32
* IRQs disabled
*
* This entry stub could put registers directly onto the SVC stack but
* it's done this way (using an intermediate save area) so that it can
* share code with other exceptions.
*/

_ARM_FUNCTION(excEnterSwi)

	STMFD	sp!,{r2}		/* save r2 - there must be SVC stack */

#if (ARM_THUMB)

/* adjust return address so it points to instruction that faulted */

	MRS	r2,spsr			/* get PSR of faulting code */
	TSTS	r2,#T_BIT		/* Thumb state? */
	SUBNE	lr,lr,#2		/* ..yes */
	SUBEQ	lr,lr,#4		/* ..no, ARM state */
#else
	SUB	lr,lr,#4		/* make lr -> faulting instruction */
#endif

/*
 * save some registers in the same order as other exception handlers
 * (see excEnterCommon)
 */

	LDR	r2,L$_swiSaveArea	/* r2 -> save area */
	STMIB	r2,{r0-r3,lr}		/* incorrect r2 stored */

/*
 * r2 -> register save area containing <dummy>,r0,r1,<dummy>,r3,lr
 * original r2 on stack
 *
 * now save real r2 value
 */

	LDMFD	sp!,{r1}		/* get original r2 */
	STR	r1,[r2,#4*3]		/* put in save area */

#if	ARM_BUG_ABORT_ENTERS_SWI

        LDR	r0,[lr]			/* get what should be the SWI */
        AND	r1,r0,#0x0F000000	/* isolate the main opcode */
        TEQS	r1,#0x0F000000		/* if not a SWI.. */
	LDMNEIB	r2,{r0-r3,pc}^		/* ..retry the instruction */

/* it was a SWI so examine it and determine whether it should be excuted */

	MRS	r3,spsr			/* r3 = svc_spsr */
        AND	r1,r0,#0xF0000000	/* isolate the condition field */
        TEQS	r1,#0xE0000000		/* provide fast path for AL condition */
        BNE	L$excEnterSwiCheckCond	/* otherwise check condition */

L$excEnterSwiCondOK:

/* instruction was a SWI and was meant to be executed */

#endif	/* ARM_BUF_ABORT_ENTERS_SWI */

#if ((CPU == ARMARCH4)  || (CPU == ARMARCH5) || \
     (CPU == STRONGARM) || (CPU == XSCALE))

/*
 * IMB handler - this is now assembled for all Architecture 4 CPUs
 * lr-> faulting instruction
 */

#if !ARM_BUG_ABORT_ENTERS_SWI
	LDR	r0,[lr]			/* get instruction */
#endif

/* r0 = instruction, known to be a SWI */

	BIC	r0,r0,#0xF0000001	/* remove condition and bit 0 */
	TEQS	r0,#0x0FF00000		/* IMB? */
	LDMEQIB	r2,{r0-r3,lr} 		/* if yes, return to next.. */
	ADDEQS	pc,lr,#4		/* ..instruction */

#endif /* CPU == ARMARCH4, ARMARCH5, STRONGARM or XSCALE */

#if !ARM_BUG_ABORT_ENTERS_SWI
	MRS	r3,spsr			/* r3 = svc_spsr */
#endif
	STR	r3,[r2]			/* save spsr in save area */
	MOV	r0,#EXC_OFF_SWI		/* r0-> exception vector */

/*
 * now join main thread with
 * r0-> exception vector
 * r1 = [scratch]
 * r2-> save area (containing spsr,r0-r3,lr)
 * r3 = original CPSR of exception mode
 * MODE=SVC32
 */

	B	L$excEnterCommon2

#if	ARM_BUG_ABORT_ENTERS_SWI

/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

L$excEnterSwiCheckCond:
/*
 * Instruction that entered SWI vector WAS a SWI but its condition was
 * not AL so need to determine whether it should have been executed.
 *
 * The following is ARM's code, modified so as to avoid generating
 * unaligned accesses. It uses a table of 16 16-bit entries, one for each
 * possible value of the condition part of an instruction, packed into 8
 * words. Each entry has one bit for each possible value of the flags of
 * the PSR. The table entry is extracted using the condition part of the
 * instruction and the bits are indexed using the value obtained by
 * extracting the flags from the PSR. If the bit so obtained is 1, the
 * instruction will be executed. Note that the bits are reversed in the
 * table so that they can be tested by moving them to bit 31.
 *
 * r1 = condition part of instruction
 * r2-> save area
 * r3 = SPSR
 * lr = [scratch]
 */
	ADR	lr,L$ccTable
	MOVS	r1,r1,LSR #29		/* r1 = 0..7, C flag saves V flag */
	LDR	lr,[lr,r1,LSL #2]	/* force word-aligned access */
	MOVCS	lr,lr,LSL #16		/* shift if necessary */
	MOV	r1,r3,LSR #28		/* extract flags */
	MOVS	lr,lr,LSL r1		/* and shift correct bit to bit 31 */
	BMI	L$excEnterSwiCondOK	/* bit set => will execute */

/* flags say SWI should not execute so return to instruction after */

	LDMIB	r2,{r0-r3,lr}		/* SPSR is unchanged */
	ADDS	pc,lr,#4

#endif	/* ARM_BUG_ABORT_ENTERS_SWI */

/**************************************************************************
*
* excEnterDataAbort - enter a data abort exception
*
* This routine is installed on the Data Abort exception vector by
* excVecInit.
*
* This routine can NEVER be called from C.
*
* SEE ALSO: excVecInit(2)

* void excEnterDataAbort ()

* INTERNAL
* MODE = ABORT32
* IRQs disabled
* sp -> register save area (see excEnterCommon)
*/

_ARM_FUNCTION(excEnterDataAbort)

/* adjust return address so it points to instruction that faulted */
	SUB	lr,lr,#8

/* save regs in save area */

	STMIB	sp,{r0-r3,lr}

/* set r0 -> exception vector and join main thread */

	MOV	r0,#EXC_OFF_DATA
	B	L$excEnterCommon

/**************************************************************************
*
* excEnterPrefetchAbort - enter a prefetch abort exception
*
* This routine is installed on the Prefetch Abort exception vector
* by excVecInit.
*
* This routine can NEVER be called from C.
*
* SEE ALSO: excVecInit(2)

* void excEnterPrefetchAbort ()

* INTERNAL
* MODE = ABORT32
* IRQs disabled
* sp -> register save area (see excEnterCommon)
*/

_ARM_FUNCTION(excEnterPrefetchAbort)

/* adjust return address so it points to instruction that faulted */

	SUB	lr,lr,#4

/* save regs in save area */

	STMIB	sp,{r0-r3,lr}

/* set r0 -> exception vector and join main thread */

	MOV	r0,#EXC_OFF_PREFETCH
	B	L$excEnterCommon

/**************************************************************************
*
* excEnterUndef - enter an undefined instruction exception
*
* This routine is installed on the Undefined Instruction vector
* by excVecInit.
*
* This routine can NEVER be called from C.
*
* SEE ALSO: excVecInit(2)

* void excEnterUndef ()

* INTERNAL
* MODE = UNDEF32
* IRQs disabled
* sp -> register save area (see excEnterCommon)
*/

_ARM_FUNCTION(excEnterUndef)

#if (ARM_THUMB)

/* save regs in save area */

	STMIB	sp,{r0-r3}

/* adjust return address so it points to instruction that faulted */

	MRS	r0,spsr			/* get PSR of faulting code */
	TSTS	r0,#T_BIT		/* Thumb state? */
	SUBNE	lr,lr,#2		/* ..yes */
	SUBEQ	lr,lr,#4		/* ..no, ARM */
	STR	lr,[sp,#5*4]		/* store in save area */
#else
 
/* adjust return address so it points to instruction that faulted */
  
	SUB	lr,lr,#4

/* save regs in save area */

	STMIB	sp,{r0-r3,lr}
#endif

/* set r0 -> exception vector and join main thread */

	MOV	r0,#EXC_OFF_UNDEF

	/* FALL THROUGH to excEnterCommon */

/*******************************************************************************
*
* excEnterCommon - enter an exception handler
*
* Control passes to this routine from the exception vectors, after the address
* in lr has been adjusted to point to the faulting instruction.
*
* This routine can NEVER be called from C.
*

* void excEnterCommon ()

* INTERNAL
*
* The exception modes of the ARM have their own stack pointers. However,
* VxWorks exception handlers expect to be called in the context of the faulting
* task so this veneer switches to SVC mode, saving necessary context in an
* exception stack frame.
* The exception stack pointers are only used to point to a few words
* for register saving. THIS IS NOT A STACK and should not be used as one.
* It is laid out as follows
*
*  -------------------------------
* | SPSR | r0 | r1 | r2 | r3 | lr |
*  -------------------------------
* ^
* | sp points here
*
*
* Entry:
*    r0 -> exception vector
*    lr -> faulting instruction
*
*/

L$excEnterCommon:

/* save SPSR in save area */

	MRS	r3,spsr
	STR	r3,[sp]

/*
 * save sp in non-banked reg so can access saved registers after
 * switching to SVC mode
 */

	MOV	r2,sp

/* switch to SVC mode with interrupts (IRQs) disabled */

	MRS	r3,cpsr
	BIC	r1,r3,#MASK_MODE
	ORR	r1,r1,#MODE_SVC32 | I_BIT
	MSR	cpsr,r1

L$excEnterCommon2:

/*
 **** INTERRUPTS DISABLED
 *
 * MODE = SVC32
 * r0 -> exception vector
 * r1 = [scratch]
 * r2 -> where exception mode SPSR,r0-r3,lr are saved
 * r3 = CPSR of exception mode
 * lr = svc_lr at time of exception
 *
 * save the following
 *    exception vector address
 *    svc_sp
 *    sp of exception mode (save area pointer)
 *    CPSR of exception mode
 * NOTE: if anything else gets added to this, the stack
 * addressing later will need adjusting
 */

	MOV	r1,sp
	STMFD	sp!,{r0-r3}

/*
 * put registers of faulting task on stack in order defined
 * in REG_SET so can pass pointer to C handler
 */

	LDR	r1,[r2,#4*5]		/* get LR of exception mode */
	LDR	r3,[r2]			/* get SPSR of exception mode */
	STMFD	sp!,{r1,r3}
	SUB	sp,sp,#4*(14-4+1)	/* make room for r4..r14 */

/*
 * check for USR mode exception - SYSTEM is handled as other modes
 * r3 = SPSR of exception mode
 */

	TSTS	r3,#MASK_SUBMODE
	STMEQIA	sp,{r4-r14}^		/* EQ => USR mode */
	BEQ	L$regsSaved

/*
 * not USR mode so must change to mode to get sp,lr
 * SYSTEM mode is also handled this way (but needn't be)
 * r3 = PSR of faulting mode
 */

	MOV	r1,sp			/* r1 -> where to put regs */
	MRS	r0,cpsr			/* save current mode */
	ORR	r3,r3,#I_BIT
	BIC	r3,r3,#T_BIT
	MSR	cpsr,r3

/* in faulting mode - interrupts still disabled */

	STMIA	r1,{r4-r14}		/* save regs */

/*
 * check if it's SVC mode and, if so, overwrite stored sp
 * stack pointed to by r3 contains
 *    r4..r14, PC, PSR of faulting mode
 *    address of exception vector
 *    svc_sp at time of exception
 *    sp of exception mode
 *    CPSR of exception mode
 */

	AND	r3,r3,#MASK_SUBMODE		/* examine mode bits */
	TEQS	r3,#MODE_SVC32 & MASK_SUBMODE	/* SVC? */
	LDREQ	r3,[r1,#4*(11+3)]		/* yes, get org svc_sp */
	STREQ	r3,[r1,#4*(13-4)]		/* and overwrite */

/* switch back to SVC mode with interrupts still disabled (r0) */

	MSR	cpsr,r0

/* back in SVC mode - interrupts still disabled */

L$regsSaved:

/* transfer r0-r3 to stack */

	LDMIB	r2,{r0-r3}		/* get other regs */
	STMFD	sp!,{r0-r3}

/*
 * exception save area can now be reused
 * stack contains
 *    r0..r14, PC, PSR of faulting mode
 *    address of exception vector
 *    svc_sp at time of exception
 *    sp of exception mode
 *    CPSR of exception mode
 * interrupts still disabled
 *
 * restore interrupt state of faulting code
 */

	LDR	r0,[sp,#4*16]		/* get PSR */
	BIC	r0,r0,#MASK_MODE	/* clear mode bits */
	ORR	r0,r0,#MODE_SVC32	/* select svc32 */
	MSR	cpsr,r0			/* and write it to CPSR */

/*
 **** INTERRUPTS RESTORED to how they were when exception occurred
 *
 * call generic exception handler
 */

	MOV	r1,sp			/* r1 -> REG_SET */
	ADD	r0,r1,#4*15		/* r0 -> ESF (PC, PSR, vector) */
	LDR	fp,[r1,#4*11]
#if (ARM_THUMB)
	LDR	r12,L$_excExcContinue	/* call C routine to continue */
	BL	FUNC(arm_call_via_r12)	/* returns in ARM state */
#else
	BL	FUNC(excExcContinue)		/* call C routine to continue */
#endif

/* exception handler returned (in SVC32) - disable interrupts (IRQs) again */

	MRS	r0,cpsr
	ORR	r0,r0,#I_BIT
	MSR	cpsr,r0

/*
 **** INTERRUPTS DISABLED
 *
 * restore regs from stack, putting some into the exception save area
 */

	LDR	r2,[sp,#4*19]		/* r2 -> exception save area */
	LDMFD	sp!,{r3-r6}		/* get r0-r3 */
	STMIB	r2,{r3-r6}

/* determine mode in which exception occurred so can restore regs */

	LDR	r3,[sp,#4*(16-4)]	/* get PSR of faulting mode */
	TSTS	r3,#MASK_SUBMODE
	LDMEQIA	sp,{r4-r14}^		/* EQ => USR mode */
	BEQ	L$regsRestored

/*
 * exception was not in USR mode so switch to mode to restore regs
 * r0 = PSR we can use to return to this mode
 * r3 = PSR of faulting mode
 */

	MOV	r1,sp			/* r1 -> from where to load regs */
	ORR	r3,r3,#I_BIT
	BIC	r3,r3,#T_BIT
	MSR	cpsr,r3

/*
 * in faulting mode - interrupts still disabled
 * r1 -> svc stack where r4-r14 are stored
 */

	LDMIA	r1,{r4-r14}		/* load regs */

/*
 * If it's SVC mode, reset sp as we've just overwritten it
 * The correct value is in r1
 */

	AND	r3,r3,#MASK_SUBMODE		/* examine mode bits */
	TEQS	r3,#MODE_SVC32 & MASK_SUBMODE	/* SVC? */
	MOVEQ	sp,r1

/* switch back to SVC mode with interrupts still disabled (r0) */

	MSR	cpsr,r0

/* back in SVC mode - interrupts still disabled */

L$regsRestored:

/* r4..r14 of faulting mode now restored */

	ADD	sp,sp,#4*(14-4+1)	/* strip r4..r14 from stack */

	LDMFD	sp!,{r1,r3}		/* get LR and SPSR of exception mode */
	STR	r1,[r2,#4*5]		/* save LR in exception save area */
	STR	r3,[r2]			/* ..with SPSR */

/* get the remaining stuff off the stack */

	LDMFD	sp!,{r0-r3}

/*
 * r0 = address of exception vector - discarded
 * r1 = svc_sp at time of exception - discarded
 * r2 = sp of exception mode
 * r3 = CPSR of exception mode
 *
 * switch back to exception mode
 */

	MSR	cpsr,r3

/*
 * back in exception mode
 * restore remaining registers and return to task that faulted
 */

	LDR	r0,[r2]
	MSR	spsr,r0
	LDMIB	r2,{r0-r3,pc}^
