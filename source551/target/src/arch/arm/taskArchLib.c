/* taskArchLib.c - ARM-specific task management routines */

/* Copyright 1996-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01e,16jan02,to   initialize fpStatus
01d,04sep98,cdp  make Thumb support dependent on ARM_THUMB.
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,05jun97,cdp  added Thumb (ARM7TDMI_T) support.
01a,09may96,cdp  written, based on 68K version
*/

/*
DESCRIPTION
This library provides an interface to ARM-specific task management routines.

SEE ALSO: taskLib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "taskArchLib.h"
#include "taskLib.h"
#include "regs.h"
#include "private/taskLibP.h"
#include "private/windLibP.h"
#include "string.h"


/* globals */

REG_INDEX taskRegName[] =
    {
    {"r0",	REG_SET_G_REG_OFFSET(0)},
    {"r1",	REG_SET_G_REG_OFFSET(1)},
    {"r2",	REG_SET_G_REG_OFFSET(2)},
    {"r3",	REG_SET_G_REG_OFFSET(3)},
    {"r4",	REG_SET_G_REG_OFFSET(4)},
    {"r5",	REG_SET_G_REG_OFFSET(5)},
    {"r6",	REG_SET_G_REG_OFFSET(6)},
    {"r7",	REG_SET_G_REG_OFFSET(7)},
    {"r8",	REG_SET_G_REG_OFFSET(8)},
    {"r9",	REG_SET_G_REG_OFFSET(9)},
    {"r10",	REG_SET_G_REG_OFFSET(10)},
    {"r11/fp",	REG_SET_G_REG_OFFSET(11)},
    {"r12/ip",	REG_SET_G_REG_OFFSET(12)},
    {"r13/sp",	REG_SET_G_REG_OFFSET(13)},
    {"r14/lr",	REG_SET_G_REG_OFFSET(14)},
    {"pc",	REG_SET_PC_OFFSET},
    {"cpsr",	REG_SET_CPSR_OFFSET},
    {NULL,	NULL},
    };

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
    WIND_TCB    *pTcb,		/* pointer TCB to initialize */
    char        *pStackBase	/* bottom of task's stack */
    )
    {
    /* clear registers to 0 - note: this clears fp */

    bzero((char *) &pTcb->regs, sizeof(REG_SET));


    /* create a CPSR and a PC pointing to vxTaskEntry */

#if (ARM_THUMB)
    pTcb->regs.cpsr = MODE_SVC32 | T_BIT;
#else
    pTcb->regs.cpsr = MODE_SVC32;
#endif
    pTcb->regs.pc = (INSTR *)((UINT32)&vxTaskEntry & ~1);


    /* initial stack pointer is just below MAX_TASK_ARGS task arguments */

    pTcb->regs.spReg = (int) (pStackBase - (MAX_TASK_ARGS * sizeof (int)));

    /* initialize fpStatus for fplib */
    pTcb->fpStatus = 0;
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
    FAST int i;
    FAST int *sp;

    /*
     * Push task args onto the stack so they are availble for taskRestart().
     * Args 0..3 will be loaded into r0..r3 in vxTaskEntry.
     */

    sp = (int *) pStackBase;			/* start at bottom of stack */

    for (i = MAX_TASK_ARGS - 1; i >= 0; --i)
        *--sp = pArgs[i];			/* put arguments onto stack */
    }

/*******************************************************************************
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
    pTcb->regs.r[0] = returnValue;
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
    FAST int i;
    FAST int *sp;

    /* retrieve args from base of stack */

    sp = (int *) pStackBase;			/* start at bottom of stack */

    for (i = MAX_TASK_ARGS - 1; i >= 0; --i)
        pArgs[i] = *--sp;			/* fill arguments from stack */
    }
