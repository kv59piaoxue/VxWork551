/* taskArchLib.c - HITACHI SH-specific task management routines */

/* Copyright 1994-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01n,05apr02,h_k  changed taskArgsSet() to store 1st-4th args into stack (SPR
                 #75153).
01m,30aug00,hk   change taskRegsInit() to import intUnlockSR (ex-brandNewTaskSR)
01l,21aug00,hk   merge SH7729 to SH7700.
01k,14sep98,hk   cleaned up taskRegsInit().
01j,16jul98,st   added SH7750 support.
01j,08may98,jmc  added support for SH-DSP and SH3-DSP.
01i,14dec96,hk   changed magic number 6 in taskArgsGet to MAX_TASK_ARGS-4 (wt).
01h,21sep96,hk   moved sr in taskRegName[] next to pr for nicer register dump.
01g,28jul96,hk   renamed BrandNewTaskSR to brandNewTaskSR.
01f,13jun96,hk   changed taskRegsInit() to refer BrandNewTaskSR.
01e,07jun96,hk   added SH7700 support to taskRegsInit().
01d,02jul95,hk   cleaned vbr,gbr,pr,mac[0],mac[1] in taskRegsInit().
01c,07mar95,hk   used MAX_TASK_ARGS for sp in taskArgsSet(). copyright 1995.
01b,07oct94,hk   changed to match the new regsSh.h definition.
01a,22jul94,hk   derived from 01o of mc68k.
*/

/*
DESCRIPTION
This library provides an interface to SH-specific task management routines.

SEE ALSO: taskLib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "string.h"
#include "taskArchLib.h"
#include "regs.h"
#include "private/taskLibP.h"
#include "private/windLibP.h"


/* globals */

REG_INDEX taskRegName[] =
    {
    {"r0",  REG_SET_R0},
    {"r1",  REG_SET_R1},
    {"r2",  REG_SET_R2},
    {"r3",  REG_SET_R3},
    {"r4",  REG_SET_R4},
    {"r5",  REG_SET_R5},
    {"r6",  REG_SET_R6},
    {"r7",  REG_SET_R7},
    {"r8",  REG_SET_R8},
    {"r9",  REG_SET_R9},
    {"r10", REG_SET_R10},
    {"r11", REG_SET_R11},
    {"r12", REG_SET_R12},
    {"r13", REG_SET_R13},
    {"r14", REG_SET_R14},
    {"r15/sp", REG_SET_R15},
    {"gbr", REG_SET_GBR},
    {"vbr", REG_SET_VBR},
    {"mach",REG_SET_MACH},
    {"macl",REG_SET_MACL},
    {"pr",  REG_SET_PR},
    {"sr",  REG_SET_SR},
    {"pc",  REG_SET_PC},
    {NULL,  0},
    };

/******************************************************************************
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
#if (CPU==SH7750 || CPU==SH7700)
    IMPORT UINT32 intUnlockSR;				/* from intArchLib */
#endif
    bzero ((char *)(&pTcb->regs), sizeof(REG_SET));	/* clear everything */

#if (CPU==SH7750 || CPU==SH7700)
    pTcb->regs.sr = intUnlockSR;		/* set status register */
#endif
    pTcb->regs.pc = (INSTR *)vxTaskEntry;		/* set entry point */

    /* initial stack pointer is after MAX_TASK_ARGS task arguments */

    pTcb->regs.nvreg[7] = (int)(pStackBase - (MAX_TASK_ARGS * sizeof(int)));
    }

/******************************************************************************
*
* taskArgsSet - set a task's arguments
*
* During task initialization this routine is called to push the specified
* arguments onto the task's stack.
*
* NOMANUAL
* ARGSUSED
*
* INTERNAL
*	            <STACK>
*                 |         | <-- pStackBase
*   pArgs [3] --> |         |
*   pArgs [2] --> |         |
*   pArgs [1] --> |         |
*   pArgs [0] --> |         |
*   pArgs [9] --> |         |
*   pArgs [8] --> |         |                   NOTE: MAX_TASK_ARGS is defined
*   pArgs [7] --> |         |                         as '10' in taskLib.h.
*   pArgs [6] --> |         |                            /
*   pArgs [5] --> |         |                           /
*   pArgs [4] --> |         | <-- pStackBase - MAX_TASK_ARGS * (sizeof(int))
*                 0         |
*
*   pArgs [3] -->  voreg [7]  -->  r7
*   pArgs [2] -->  voreg [6]  -->  r6
*   pArgs [1] -->  voreg [5]  -->  r5
*   pArgs [0] -->  voreg [4]  -->  r4
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

    sp = (int *) (pStackBase - MAX_TASK_ARGS * (sizeof(int)));

    for (ix = 4; ix < MAX_TASK_ARGS; ++ix)
	{
	*sp++ = pArgs [ix];			/* Args beyond 4th into stack */
	}

    for (ix = 0; ix < 4; ++ix)
	{
	pTcb->regs.voreg [ix+4] = pArgs [ix];	/* 1st 4 args into registers */
	*sp++ = pArgs [ix];			/* 1st 4 args into stack */
	}
    }

/******************************************************************************
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
    WIND_TCB	*pTcb,		/* pointer TCB to initialize */
    char	*pStackBase,	/* bottom of task's stack */
    int		pArgs[]		/* array of arguments to fill */
    )
    {
    FAST int ix;
    FAST int *sp;

    /* pop args from the stack */

    sp = (int *) (pStackBase - MAX_TASK_ARGS * (sizeof(int)));

    for (ix = 4; ix < MAX_TASK_ARGS; ++ix)
	{
	pArgs [ix] = *sp++;			/* Args beyond 4th from stack */
	}

    for (ix = 0; ix < 4; ++ix)
	{
	pArgs [ix] = *sp++;			/* 1st 4 args from stack */
	}
    }

/******************************************************************************
*
* taskRtnValueSet - set a task's subroutine return value
*
* This routine sets register r0, the return code, to the specified value.  It
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
    pTcb->regs.voreg [0] = returnValue;
    }
