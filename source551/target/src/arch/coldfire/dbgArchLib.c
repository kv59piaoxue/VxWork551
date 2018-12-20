/* dbgArchLib.c - ColdFire-dependent debugger library */
  
/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,19jun00,ur   Removed all non-Coldfire stuff.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This module provides the Motorola Coldfire specific support functions
for dbgLib.

NOMANUAL
*/

#include "vxWorks.h"
#include "private/dbgLibP.h"
#include "taskLib.h"
#include "taskArchLib.h"
#include "intLib.h"
#include "regs.h"
#include "iv.h"
#include "cacheLib.h"
#include "ioLib.h"
#include "dsmLib.h"
#include "vxLib.h"
#include "usrLib.h"

/* externals */

IMPORT int dsmNbytes ();
IMPORT int dsmInst ();

/* globals */

char * _archHelp_msg = "";

/*******************************************************************************
*
* _dbgArchInit - architecture dependent initialization routine
*
* This routine initialize global function pointers that are architecture 
* specific.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void _dbgArchInit (void)
    {
    _dbgDsmInstRtn = (FUNCPTR) dsmInst;
    }

/*******************************************************************************
*
* _dbgInstSizeGet - set up breakpoint instruction
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
    return (dsmNbytes (pBrkInst) / sizeof (INSTR));
    }

/*******************************************************************************
*
* _dbgRetAdrsGet - get return address for current routine
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
    /* if next instruction is a LINK or RTS, return address is on top of stack;
     * otherwise it follows saved frame pointer */

    if (INST_CMP(pRegSet->pc,LINK,LINK_MASK) || 
	INST_CMP(pRegSet->pc,RTS,RTS_MASK))
        return (*(INSTR **)pRegSet->spReg);
    else
	return (*((INSTR **)pRegSet->fpReg + 1));
    }

/*******************************************************************************
*
* _dbgFuncCallCheck - check next instruction
*
* This routine checks to see if the next instruction is a JSR or BSR.
* If it is, it returns TRUE, otherwise, returns FALSE.
*
* RETURNS: TRUE if next instruction is JSR or BSR, or FALSE otherwise.
*
* NOMANUAL
*/

BOOL _dbgFuncCallCheck
    (
    INSTR * addr		/* pointer to instruction */
    )
    {
    return (INST_CMP (addr, JSR, JSR_MASK) || INST_CMP (addr, BSR, BSR_MASK));
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
    int tid	/* task id */
    )
    {
    REG_SET regSet;		/* task's register set */

    taskRegsGet (tid, &regSet);

    return (regSet.pc);
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
    int		tid,	/* task id */
    INSTR *	pc,	/* task's pc */
    INSTR *	npc	/* not supoorted on Coldfire */
    )
    {
    REG_SET regSet;	/* task's register set */

    taskRegsGet (tid, &regSet);

    regSet.pc = pc;

    taskRegsSet (tid, &regSet);
    }

/*******************************************************************************
*
* getOneReg - return the contents of one register
*
* Given a task's ID, this routine returns the contents of the register
* specified by the register code.  This routine is used by `a0', `d0', `sr',
* etc.  The register codes are defined in dbgColdfireLib.h.
*
* RETURNS: register contents, or ERROR.
*/

LOCAL int getOneReg
    (
    int		taskId,		/* task's id, 0 means default task */
    int		regCode		/* code for specifying register */
    )
    {
    REG_SET	regSet;		/* get task's regs into here */

    taskId = taskIdFigure (taskId);	/* translate super name to id */

    if (taskId == ERROR)		/* couldn't figure out super name */
	return (ERROR);
    taskId = taskIdDefault (taskId);	/* set the default id */

    if (taskRegsGet (taskId, &regSet) != OK)
	return (ERROR);

    switch (regCode)
	{
	case D0: return (regSet.dataReg [0]);	/* data registers */
	case D1: return (regSet.dataReg [1]);
	case D2: return (regSet.dataReg [2]);
	case D3: return (regSet.dataReg [3]);
	case D4: return (regSet.dataReg [4]);
	case D5: return (regSet.dataReg [5]);
	case D6: return (regSet.dataReg [6]);
	case D7: return (regSet.dataReg [7]);

	case A0: return (regSet.addrReg [0]);	/* address registers */
	case A1: return (regSet.addrReg [1]);
	case A2: return (regSet.addrReg [2]);
	case A3: return (regSet.addrReg [3]);
	case A4: return (regSet.addrReg [4]);
	case A5: return (regSet.addrReg [5]);
	case A6: return (regSet.addrReg [6]);
	case A7: return (regSet.addrReg [7]);	/* a7 is the stack pointer */

	case SR: return (regSet.sr);
	}

    return (ERROR);		/* unknown regCode */
    }

/*******************************************************************************
*
* a0 - return the contents of register `a0' (also `a1' - `a7') (Coldfire)
*
* This command extracts the contents of register `a0' from the TCB of
* a specified task.  If <taskId> is omitted or zero, the last task
* referenced is assumed.
*
* Similar routines are provided for all address registers (`a0' - `a7'):
* a0() - a7().
*
* The stack pointer is accessed via a7().
*
* RETURNS: The contents of register `a0' (or the requested register).
*
* SEE ALSO:
* .pG "Debugging"
*/

int a0
    (
    int taskId		/* task ID, 0 means default task */
    )

    {
    return (getOneReg (taskId, A0));
    }

int a1 (taskId) int taskId; { return (getOneReg (taskId, A1)); }
int a2 (taskId) int taskId; { return (getOneReg (taskId, A2)); }
int a3 (taskId) int taskId; { return (getOneReg (taskId, A3)); }
int a4 (taskId) int taskId; { return (getOneReg (taskId, A4)); }
int a5 (taskId) int taskId; { return (getOneReg (taskId, A5)); }
int a6 (taskId) int taskId; { return (getOneReg (taskId, A6)); }
int a7 (taskId) int taskId; { return (getOneReg (taskId, A7)); }

/*******************************************************************************
*
* d0 - return the contents of register `d0' (also `d1' - `d7') (Coldfire)
*
* This command extracts the contents of register `d0' from the TCB of
* a specified task.  If <taskId> is omitted or zero, the last task
* referenced is assumed.
*
* Similar routines are provided for all data registers (`d0' - `d7'):
* d0() - d7().
*
* RETURNS: The contents of register `d0' (or the requested register).
*
* SEE ALSO:
* .pG "Debugging"
*/

int d0
    (
    int taskId		/* task ID, 0 means default task */
    )
    {
    return (getOneReg (taskId, D0));
    }

int d1 (taskId) int taskId; { return (getOneReg (taskId, D1)); }
int d2 (taskId) int taskId; { return (getOneReg (taskId, D2)); }
int d3 (taskId) int taskId; { return (getOneReg (taskId, D3)); }
int d4 (taskId) int taskId; { return (getOneReg (taskId, D4)); }
int d5 (taskId) int taskId; { return (getOneReg (taskId, D5)); }
int d6 (taskId) int taskId; { return (getOneReg (taskId, D6)); }
int d7 (taskId) int taskId; { return (getOneReg (taskId, D7)); }

/*******************************************************************************
*
* sr - return the contents of the status register (Coldfire)
*
* This command extracts the contents of the status register from the TCB of a
* specified task.  If <taskId> is omitted or zero, the last task referenced is
* assumed.
*
* RETURNS: The contents of the status register.
*
* SEE ALSO:
* .pG "Debugging"
*/

int sr
    (
    int taskId		/* task ID, 0 means default task */
    )
    {
    return (getOneReg (taskId, SR));
    }
