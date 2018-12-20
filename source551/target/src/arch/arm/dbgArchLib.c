/* dbgArchLib.c - ARM-dependent debugger library */

/* Copyright 1996-1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01g,13nov98,cdp  made Thumb support dependent on ARM_THUMB.
01f,20apr98,dbt  modified for new breakpoint scheme.
01e,27oct97,kkk  took out "***EOF***" line from end of file.
01d,10oct97,jpd  added further Thumb support.
01c,01may97,cdp  modified for alternative function prologues;
		 added Thumb (ARM7TDMI_T) support.
01b,20feb97,jpd  Tidied comments/documentation.
01a,18jul96,jpd  written, based on 680x0 version 01h.
*/

/*
DESCRIPTION
This module provides the Advanced Risc Machines Ltd, ARM-specific support
functions for dbgLib. Note that no support is provided here for the
EmbeddedICE hardware debugging facilities.

NOMANUAL
*/

#include "vxWorks.h"
#include "private/dbgLibP.h"
#include "taskLib.h"
#include "regs.h"
#include "dsmLib.h"
#include "usrLib.h"
#include "arch/arm/arm.h"
#include "stdio.h"
#include "string.h"

/* externals */

/* architecture-dependent instruction decoding routines from dbgArmLib.c */

#if (ARM_THUMB)
IMPORT BOOL thumbInstrChangesPc (INSTR *);
#else
IMPORT BOOL armInstrChangesPc (INSTR *);
#endif

/* globals */

extern char * _archHelp_msg;
char * _archHelp_msg =
    "r0-r14    [task]                Display a register of a task\n"
    "cpsr      [task]                Display cpsr of a task\n"
    "psrShow   value                 Display meaning of psr value\n";

/* defines */

/* pseudo-register num to pass to getOneReg() to get CPSR, local to this file */

#define ARM_REG_CPSR	16

/*******************************************************************************
*
* _dbgArchInit - architecture dependent initialization routine
*
* This routine initialises global function pointers that are architecture
* specific.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void _dbgArchInit (void)

    {
    /* Install the ARM disassembler from dsmLib.c */

    _dbgDsmInstRtn = dsmInst;
    }

/*******************************************************************************
*
* _dbgInstSizeGet - get size of breakpoint instruction
*
* NOTE
* In contrast to the Architecture Porting Guidelines, this routine should not
* return the size in units of 16-bit words. It should return the size in units
* of sizeof(INSTR). The only place this routine is called from, is in so(), in
* dbgLib.c which uses this to add a breakpoint at:
* (INSTR *)(pc + _dbgInstSizeGet(pc).
*
* RETURNS: size of the instruction at specified location.
*
* NOMANUAL
*/

int _dbgInstSizeGet
    (
    INSTR * pBrkInst		/* pointer to hold breakpoint instruction */
    )
    {
    return dsmNbytes (pBrkInst) / sizeof(INSTR);
    }

/*******************************************************************************
*
* _dbgRetAdrsGet - get return address for current routine
*
* This routine is used by the cret() routine to set a breakpoint at the return
* address of the current subroutine.
*
* NOTE
* In order to find the return address, a number of assumptions are made.
* In general, it will work for all C language routines and for ARM assembly
* language routines that start and funish with a standard entry sequence.
* For details of these sequences see trcStack() in trcLib.c.
*
* Most VxWorks assembly language routines establish a stack frame in this
* fashion for exactly this reason. However, routines written in other
* languages, strange entries into routines, or tasks with corrupted stacks
* can confuse this routine
*
* RETURNS: return address for current routine.
*
* NOMANUAL
*/

INSTR * _dbgRetAdrsGet
    (
    REG_SET * pRegSet		/* pointer to register set */
    )
    {
    int		i;			/* an index */
    FAST INSTR	*pc = pRegSet->pc;	/* pointer to instruction */

    /*
     * If the current routine doesn't have a stack frame, then we will have
     * to guess that the return address is in the link register, in the
     * absence of any better guesses.
     * We KNOW we don't have a complete stack frame for the current
     * routine in a few particular cases. In some of these cases, we are
     * able to find the return address reliably.
     *
     *  1) We are in the entry sequence of a routine which establishes the
     *     stack frame. We try to cope with this.
     *  2) We are in the exit sequence of a routine (Thumb only), which
     *	   collapses the stack frame. We try to cope with this.
     *  3) We are in a routine which doesn't create a stack frame. We cannot
     *     do much about this.
     *
     * For prologue descriptions, please refer to trcStack() in trcLib.c.
     */

    /*
     * Before we go any further, check to see if frame pointer is zero.
     * If so use lr, it's the best we can do
     */

    if (pRegSet->fpReg == 0)
#if (ARM_THUMB)
	/* return address will have bit 0 set; mask it off */

	return (INSTR *)(pRegSet->r[14] & ~1);
#else
	return (INSTR *)pRegSet->r[14];
#endif


#if (ARM_THUMB)
    /*
     * First look to see if we are in the epilogue. Unlike the ARM which has
     * an atomic epilogue, the Thumb epilogue is several instructions, during
     * which the frame pointer is restored to its previous value.
     *
     * Search backwards from current instruction to find the first instruction
     * of the epilogue.
     */

    for (i = 0; i >= -3 ; --i)
	if (INSTR_IS(pc[i],     T_POP_LO) &&
	    INSTR_IS(pc[i + 1], T_MOV_FP_LO) &&
	    INSTR_IS(pc[i + 2], T_MOV_SP_LO) &&
	    INSTR_IS(pc[i + 3], T_BX_LO))
	    break;

    if (i >= -3)
	{
	/* Then we are in the epilogue */

	if (i == 0)
	    /*
	     * We are in the epilogue, but have not popped part of the
	     * frame yet. The frame pointer points to a valid frame. We must
	     * get the return address from the frame pointed to by fp. Mask
	     * bit 0 off from the return address.
	     */
	    return (INSTR *)(*(((UINT32 *)(pRegSet->fpReg)) - 1) & ~1);
	else
	    {
	    /*
	     * Return address will now be in the register used in the
	     * BX Rn instruction used to exit the routine. Look at the
	     * instruction and extract the register number from that
	     * instruction. Then get that register from the reg set.
	     */

	    i = (pc[i + 3] & 0x38) >> 3;	/* register number in BX instr*/

	    /* return address will have bit 0 set; mask it off */

	    return (INSTR *)(pRegSet->r[i] & ~1);
	    }
	}


    /*
     * We are not in the epilogue, but we may be in the prologue.
     *
     * Look for the last instruction of the prologue. This can be up
     * to twelve instructions after the current one.
     */

    for (i = 0; i <= 12 ; i++)
	if (INSTR_IS(pc[i], T_MOV_FP_LO))
	    break;

    /*
     * Check to see if this really is the prologue, by matching
     * another instruction earlier in the prologue. We have
     * attempted to choose instructions which should not occur much
     * elsewhere.
     *
     * If we are in the entry sequence of the routine, use lr. Bit 0
     * will be set, mask it off. Otherwise extract return address from
     * frame.
     *
     * If we know we are in the entry sequence, then we know that the
     * return address is in lr, otherwise it's just our best guess.
     */

    if (i <= 12 &&
	(INSTR_IS(pc[i - 5], T_MOV_LO_PC) ||
	 INSTR_IS(pc[i - 5], T_MOV_LO_FP)))
	return (INSTR *)(pRegSet->r[14] & ~1);
    else
	return (INSTR *)(*(((UINT32 *)(pRegSet->fpReg)) - 1) & ~1);

#else /* (ARM_THUMB) */

    /*
     * Look for the first instruction of the prologue. This can be up
     * to three instructions before the current one.
     */

    for (i = 0; i >= -3 ; --i)
	if (INSTR_IS(pc[i], MOV_IP_SP))
	    break;

    /* If we are in the entry sequence of the routine, use lr. */

    if ((i >= -2 &&
	INSTR_IS(pc[i + 1], STMDB_SPP_FP_IP_LR_PC) &&
	INSTR_IS(pc[i + 2], SUB_FP_IP_4)) ||
       (i >= -3 &&
	INSTR_IS(pc[i + 2], STMDB_SPP_FP_IP_LR_PC) &&
	INSTR_IS(pc[i + 3], SUB_FP_IP_4PLUS) &&
	(INSTR_IS(pc[i + 1], STMDB_SPP_AREGS) ||
	 INSTR_IS(pc[i + 1], SUB_SP_SP))))
	return (INSTR *)pRegSet->r[14];
    else
	return *(((INSTR **)(pRegSet->fpReg)) - 1);

#endif	/* (ARM_THUMB) */

    }

/*******************************************************************************
*
* _dbgFuncCallCheck - check if instruction calls a function
*
* This routine checks to see if the instruction calls a function.
* On the ARM, many classes of instruction could be used to do this. We check to
* see if the instruction is a BL, or if it changes the PC and the previous
* instruction is a MOV lr, pc instruction. On Thumb we do the equivalent,
* though on Thumb, the BL is two instructions long.
*
* RETURNS: TRUE if next instruction calls a function, FALSE otherwise.
*
* NOMANUAL
*/

BOOL _dbgFuncCallCheck
    (
    INSTR * addr		/* pointer to instruction */
    )
    {
#if (ARM_THUMB)
    /* check for both halves of a BL instruction */

    return (INSTR_IS (*addr, T_BL0) && INSTR_IS (*(addr + 1), T_BL1)) ||
	   (INSTR_IS (*(addr - 1), T_MOV_LR_PC) && thumbInstrChangesPc (addr));
#else
    return (INSTR_IS (*addr, BL) ||
	   (INSTR_IS (*(addr - 1), MOVXX_LR_PC) && armInstrChangesPc (addr)));
#endif
    }

/*******************************************************************************
*
* _dbgTaskPCSet - set task's pc
*
* RETURNS: N/A
*
* NOMANUAL
*/

void _dbgTaskPCSet
    (
    int    tid,		/* task id */
    INSTR* pc,		/* task's pc */
    INSTR* npc		/* next pc, not supported on ARM */
    )
    {
    REG_SET regSet;		/* task's register set */

    if (taskRegsGet (tid, &regSet) != OK)
        return;

    regSet.pc = pc;

    taskRegsSet (tid, &regSet);
    }

/*******************************************************************************
*
* _dbgTaskPCGet - restore register set
*
* RETURNS: N/A
*
* NOMANUAL
*/

INSTR * _dbgTaskPCGet
    (
    int tid		/* task id */
    )
    {
    REG_SET regSet;		/* task's register set */

    taskRegsGet (tid, &regSet);

    return regSet.pc;
    }

/*******************************************************************************
*
* getOneReg - return the contents of one register
*
* Given a task's ID, this routine returns the contents of the register
* specified by the register code.  This routine is used by `a1', `cpsr', etc.
*
* RETURNS: register contents, or ERROR.
*/

LOCAL int getOneReg (taskId, regCode)
    int		taskId;		/* task's id, 0 means default task */
    int		regCode;	/* code for specifying register */
    {
    REG_SET	regSet;		/* get task's regs into here */

    taskId = taskIdFigure (taskId);	/* translate super name to id */

    if (taskId == ERROR)		/* couldn't figure out super name */
	return ERROR;
    taskId = taskIdDefault (taskId);	/* set the default id */

    if (taskRegsGet (taskId, &regSet) != OK)
	return ERROR;

    switch (regCode)
	{
	case 0:  return regSet.r[0];	/* general registers */
	case 1:  return regSet.r[1];
	case 2:  return regSet.r[2];
	case 3:  return regSet.r[3];
	case 4:  return regSet.r[4];
	case 5:  return regSet.r[5];
	case 6:  return regSet.r[6];
	case 7:  return regSet.r[7];
	case 8:  return regSet.r[8];
	case 9:  return regSet.r[9];
	case 10: return regSet.r[10];
	case 11: return regSet.r[11];
	case 12: return regSet.r[12];
	case 13: return regSet.r[13];
	case 14: return regSet.r[14];
	case 15: return (int) regSet.pc;

	case ARM_REG_CPSR: return regSet.cpsr;

	}

    return ERROR;		/* unknown regCode */

    }

/*******************************************************************************
*
* r0 - return the contents of register `r0' (also `r1' - `r14') (ARM)
*
* This command extracts the contents of register `r0' from the TCB of a
* specified task.  If <taskId> is omitted or zero, the last task referenced is
* assumed.
*
* Similar routines are provided for registers (`r1' - `r14'):
* r1() - r14().
*
* RETURNS: The contents of register `r0' (or the requested register).
*
* SEE ALSO:
* .pG "Debugging"
*/

int r0
    (
    int taskId		/* task ID, 0 means default task */
    )

    {
    return getOneReg (taskId, 0);
    }

int r1  (taskId) int taskId; { return getOneReg (taskId, 1); }
int r2  (taskId) int taskId; { return getOneReg (taskId, 2); }
int r3  (taskId) int taskId; { return getOneReg (taskId, 3); }
int r4  (taskId) int taskId; { return getOneReg (taskId, 4); }
int r5  (taskId) int taskId; { return getOneReg (taskId, 5); }
int r6  (taskId) int taskId; { return getOneReg (taskId, 6); }
int r7  (taskId) int taskId; { return getOneReg (taskId, 7); }
int r8  (taskId) int taskId; { return getOneReg (taskId, 8); }
int r9  (taskId) int taskId; { return getOneReg (taskId, 9); }
int r10 (taskId) int taskId; { return getOneReg (taskId, 10); }
int r11 (taskId) int taskId; { return getOneReg (taskId, 11); }
int r12 (taskId) int taskId; { return getOneReg (taskId, 12); }
int r13 (taskId) int taskId; { return getOneReg (taskId, 13); }
int r14 (taskId) int taskId; { return getOneReg (taskId, 14); }

/*******************************************************************************
*
* cpsr - return the contents of the current processor status register (ARM)
*
* This command extracts the contents of the status register from the TCB of a
* specified task.  If <taskId> is omitted or zero, the last task referenced is
* assumed.
*
* RETURNS: The contents of the current processor status register.
*
* SEE ALSO:
* .pG "Debugging"
*/

int cpsr
    (
    int taskId		/* task ID, 0 means default task */
    )
    {
    return getOneReg (taskId, ARM_REG_CPSR);
    }

/*******************************************************************************
*
* psrShow - display the meaning of a specified PSR value, symbolically (ARM)
*
* This routine displays the meaning of all fields in a specified PSR value,
* symbolically.
*
* RETURNS: OK, always.
*
* SEE ALSO:
* .I "ARM Architecture Reference Manual".
*/

STATUS psrShow
    (
    UINT32 psrval		/* psr value to show */
    )
    {
    char str[16];		/* NZVCIFTSYSTEM32 */

    strcpy(str, "nzcvift");

    if (psrval & N_BIT)
	str[0] = 'N';

    if (psrval & Z_BIT)
	str[1] = 'Z';

    if (psrval & C_BIT)
	str[2] = 'C';

    if (psrval & V_BIT)
	str[3] = 'V';

    if (psrval & I_BIT)
	str[4] = 'I';

    if (psrval & F_BIT)
	str[5] = 'F';

    if (psrval & T_BIT)
	str[6] = 'T';

    switch (psrval & 0x1F)
	{
	case MODE_USER32:
	    strcat(str, "USER32");
	    break;

	case MODE_FIQ32:
	    strcat(str, "FIQ32");
	    break;

	case MODE_IRQ32:
	    strcat(str, "IRQ32");
	    break;

	case MODE_SVC32:
	    strcat(str, "SVC32");
	    break;

	case MODE_ABORT32:
	    strcat(str, "ABORT32");
	    break;

	case MODE_UNDEF32:
	    strcat(str, "UNDEF32");
	    break;

	case MODE_SYSTEM32:
	    strcat(str, "SYSTEM32");
	    break;

	default:
	    strcat(str, "------");
	    break;
	    }

    printf("%s\n", str);

    return OK;
    }
