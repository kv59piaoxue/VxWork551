/* taskArchLib.c - ColdFire-specific task management routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01e,17dec02,dee  fix for SPR 85105
01c,26nov01,dee  remove references to MCF5200
01b,19jun00,ur   Removed all non-Coldfire stuff.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This library provides an interface to ColdFire-specific task management
routines.

SEE ALSO: taskLib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "taskArchLib.h"
#include "regs.h"
#include "private/taskLibP.h"
#include "private/windLibP.h"


/*******************************************************************************
*
* taskRegsInit - initialize a task's registers
*
* During task initialization this routine is called to initialize the specified
* task's registers to the default values.
*
* NOMANUAL
* ARGSUSED
*/

void taskRegsInit
    (
    WIND_TCB    *pTcb,          /* pointer TCB to initialize */
    char        *pStackBase     /* bottom of task's stack */
    )
    {
    FAST int ix;

    pTcb->regs.sr = 0x3000;			/* set status register */
    pTcb->regs.hasMac = 0x4000;                 /* set default format field */
    pTcb->regs.mac = 0;				/* clear mac */
    pTcb->regs.macsr = 0;			/* clear mac status register */
    pTcb->regs.mask = 0;			/* clear mac mask register */
    pTcb->regs.pc = (INSTR *)vxTaskEntry;	/* set entry point */

    for (ix = 0; ix < 8; ++ix)
	pTcb->regs.dataReg[ix] = 0;		/* initialize d0 - d7 */

    for (ix = 0; ix < 7; ++ix)
	pTcb->regs.addrReg[ix] = 0;		/* initialize a0 - a6 */

    /* initial stack pointer is just after MAX_TASK_ARGS task arguments */

    pTcb->regs.spReg = (int) (pStackBase - (MAX_TASK_ARGS * sizeof (int)));
    }

/*******************************************************************************
*
* taskArgsSet - set a task's arguments
*
* During task initialization this routine is called to push the specified
* arguments onto the task's stack.
*
* NOMANUAL
* ARGSUSED
*/

void taskArgsSet
    (
    WIND_TCB    *pTcb,          /* pointer TCB to initialize */
    char        *pStackBase,    /* bottom of task's stack */
    int         pArgs[]         /* array of startup arguments */
    )
    {
    FAST int ix;
    FAST int *sp;

    /* push args on the stack */

    sp = (int *) pStackBase;			/* start at bottom of stack */

    for (ix = MAX_TASK_ARGS - 1; ix >= 0; --ix)
	*--sp = pArgs[ix];			/* put arguments onto stack */
    }

/*******************************************************************************
*
* taskRtnValueSet - set a task's subroutine return value
*
* This routine sets register d0, the return code, to the specified value.  It
* may only be called for tasks other than the executing task.
*
* NOMANUAL
* ARGSUSED
*/

void taskRtnValueSet
    (
    WIND_TCB    *pTcb,          /* pointer TCB for return value */
    int         returnValue     /* return value to fill into WIND_TCB */
    )
    {
    pTcb->regs.dataReg [0] = returnValue;
    }

/*******************************************************************************
*
* taskArgsGet - get a task's arguments
*
* This routine is utilized during task restart to recover the original task
* arguments.
*
* NOMANUAL
* ARGSUSED
*/

void taskArgsGet
    (
    WIND_TCB *pTcb,             /* pointer TCB to initialize */
    char *pStackBase,           /* bottom of task's stack */
    int  pArgs[]                /* array of arguments to fill */
    )
    {
    FAST int ix;
    FAST int *sp;

    /* push args on the stack */

    sp = (int *) pStackBase;			/* start at bottom of stack */

    for (ix = MAX_TASK_ARGS - 1; ix >= 0; --ix)
	pArgs[ix] = *--sp;			/* fill arguments from stack */
    }
/*******************************************************************************
*
* taskSRSet - set task status register
*
* This routine sets the status register of a specified task that is not
* running (i.e., the TCB must not be that of the calling task).  Debugging
* facilities use this routine to set the trace bit in the status register of
* a task that is being single-stepped.
*
* RETURNS: OK, or ERROR if the task ID is invalid.
*/

STATUS taskSRSet
    (
    int    tid,         /* task ID */
    UINT16 sr           /* new SR */
    )
    {
    FAST WIND_TCB *pTcb = taskTcb (tid);

    if (pTcb == NULL)		/* task non-existent */
	return (ERROR);

    pTcb->regs.sr = sr;

    return (OK);
    }
