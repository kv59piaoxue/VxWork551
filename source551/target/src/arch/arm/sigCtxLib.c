/* sigCtxLib.c - software signal architecture support library */

/* Copyright 1996-1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01d,04sep98,cdp  make Thumb support dependent on ARM_THUMB.
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,05jun97,cdp  added Thumb (ARM7TDMI_T) support.
01a,09jul96,cdp  written.
*/

/*
This library provides the architecture specific support needed by
software signals.
*/

#include "vxWorks.h"
#include "private/sigLibP.h"
#include "string.h"
#include "taskLib.h"


struct sigfaulttable _sigfaulttable [] =
    {
    {EXC_OFF_RESET,	SIGILL},
    {EXC_OFF_UNDEF,	SIGILL},
    {EXC_OFF_SWI,	SIGILL},
    {EXC_OFF_PREFETCH,	SIGSEGV},
    {EXC_OFF_DATA,	SIGSEGV},
    {0,  0 },
    };

/*******************************************************************************
*
* _sigCtxRtnValSet - set the return value of a context
*
* Set the return value of a context.
* This routine should be almost the same as taskRtnValueSet in taskArchLib.c
*/

void _sigCtxRtnValSet
    (
    REG_SET		*pRegs,
    int			val
    )
    {
    pRegs->r [0] = val;
    }


/*******************************************************************************
*
* _sigCtxStackEnd - get the end of the stack for a context
*
* Get the end of the stack for a context, the context will not be
* running. If during a context switch, stuff is pushed onto the stack,
* room must be left for that. [I assume this copied comment refers to the
* context switch stuff in sigCtxALib.s, not windALib.s in which case the
* ARM does not need any extra space allocated (unlike 68k and i86).]
*/

void *_sigCtxStackEnd
    (
    const REG_SET	*pRegs
    )
    {
    return (void *)(pRegs->spReg);
    }

/*******************************************************************************
*
* _sigCtxSetup - Setup of a context
*
* This routine will set up a context that can be context switched in.
* <pStackBase> points beyond the end of the stack. The first element of
* <pArgs> is the number of args to call <taskEntry> with.
* When the task gets swapped in, it should start as if called like
*
* (*taskEntry) (pArgs[1], pArgs[2], ..., pArgs[pArgs[0]])
*
* This routine is a blend of taskRegsInit and taskArgsSet.
*
* Currently (for signals) pArgs[0] always equals 1, thus the task should
* start as if called like
* (*taskEntry) (pArgs[1]);
*
* Furthermore (for signals), the function taskEntry will never return.
*/

void _sigCtxSetup
    (
    REG_SET		*pRegs,
    void		*pStackBase,
    void		(*taskEntry)(),
    int			*pArgs
    )
    {
    FAST int *sp;
    FAST int i;


    /* zero registers and set up initial CPSR and PC */

    bzero((void *)pRegs, sizeof(REG_SET));
#if (ARM_THUMB)
    pRegs->cpsr = MODE_SVC32 | T_BIT;
#else
    pRegs->cpsr = MODE_SVC32;
#endif
    pRegs->pc = (INSTR *)taskEntry;


    /* put any arguments above the first four onto the stack */

    sp = (int *)((ULONG)pStackBase & ~3);	/* start at bottom of stack */
    for (i = pArgs[0]; i > 4; --i)
	*--sp = pArgs[i];


    /* put first four args in registers */

    for ( ; i > 0; --i)
	pRegs->r[i-1] = pArgs[i];


    /* point SP at any args on the stack */

    pRegs->spReg = (ULONG)sp;
    }
