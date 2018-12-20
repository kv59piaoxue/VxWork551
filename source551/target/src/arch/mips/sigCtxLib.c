/* sigCtxLib.c - software signal architecture support library */

/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
 * This file has been developed or significantly modified by the
 * MIPS Center of Excellence Dedicated Engineering Staff.
 * This notice is as per the MIPS Center of Excellence Master Partner
 * Agreement, do not remove this notice without checking first with
 * WR/Platforms MIPS Center of Excellence engineering management.
 */

/*
modification history
--------------------
01h,16jul01,ros  add CofE comment
01g,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01f,26mar97,dra  Added #ifdef's to handle CW4011 bus error vector differences.
01e,31mar94,cd   added some casts for new _RType register type.
		 ensure correct stack alignment arguments.
01d,31aug92,rrr  cleanup of the code passed to signal handlers
01c,30jul92,rrr  added sigfaulttable
01b,09jul92,ajm  created 
01a,08jul92,rrr  written.
*/

/*
This library provides the architecture specific support needed by
software signals.
*/

#include "vxWorks.h"
#include "private/sigLibP.h"
#include "iv.h"
#include "string.h"

IMPORT ULONG taskSrDefault;

/* global variables */

struct sigfaulttable _sigfaulttable [] = {
    {IV_TLBMOD_VEC,     SIGBUS},
    {IV_TLBL_VEC,       SIGBUS},
    {IV_TLBS_VEC,       SIGBUS},
    {IV_ADEL_VEC,       SIGBUS},
    {IV_ADES_VEC,       SIGBUS},
/* XXX {IV_IBUS_VEC,        SIGBUS}, */
/* XXX {IV_DBUS_VEC,        SIGBUS}, */
    {IV_IBUS_VEC,       SIGSEGV},
    {IV_DBUS_VEC,       SIGSEGV},
    {IV_SYSCALL_VEC,    SIGTRAP},
    {IV_BP_VEC,         SIGTRAP},
    {IV_RESVDINST_VEC,  SIGILL},
    {IV_CPU_VEC,        SIGILL},
    {IV_FPA_UNIMP_VEC,  SIGFPE},
    {IV_FPA_INV_VEC,    SIGFPE},
    {IV_FPA_DIV0_VEC,   SIGFPE},
    {IV_FPA_OVF_VEC,    SIGFPE},
    {IV_FPA_UFL_VEC,    SIGFPE},
    {IV_FPA_PREC_VEC,   SIGFPE},
    {0,                 0},
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
    pRegs->v0Reg = val;
    }


/*******************************************************************************
*
* _sigCtxStackEnd - get the end of the stack for a context
*
* Get the end of the stack for a context, the context will not be running.
* If during a context switch, stuff is pushed onto the stack, room must
* be left for that (on the 68k the fmt, pc, and sr are pushed just before
* a ctx switch)
*/

void *_sigCtxStackEnd
    (
    const REG_SET	*pRegs
    )
    {
    return (void *)((int)pRegs->spReg);	/* XXX */
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
* For the 68k case, we push vxTaskEntry() onto the stack so a stacktrace
* looks good.
*/

void _sigCtxSetup
    (
    REG_SET		*pRegs,
    void		*pStackBase,
    void		(*taskEntry)(),
    int			*pArgs
    )
    {
    FAST int ix;
    FAST int *sp;
    IMPORT ULONG _gp;		/* compiler generated global pointer value */ 

    bzero ((void *) pRegs, sizeof(REG_SET));	/* initialize register set */

    pRegs->sr = taskSrDefault;			/* set status register */
    pRegs->pc = (INSTR *) taskEntry;		/* set entry point */

    pRegs->gpReg = (_RType) (int) &_gp;		/* load curent global pointer */

    /* push args on the stack */

    sp = (int *) pStackBase;            	/* start at bottom of stack */

    /* allocate space on stack for arguments with correct alignment */
    sp = (int *) STACK_ROUND_DOWN(sp - max (4, pArgs[0]));

    for (ix = pArgs[0]; ix > 0; --ix)
        sp[ix] = pArgs[ix];              	/* put arguments onto stack */

    pRegs->spReg = (_RType)((int)sp);		/* load initial stack pointer */

    pRegs->a0Reg = pArgs[1];        		/* load register parameter 1 */
    pRegs->a1Reg = pArgs[2];        		/* load register parameter 2 */
    pRegs->a2Reg = pArgs[3];        		/* load register parameter 3 */
    pRegs->a3Reg = pArgs[4];        		/* load register parameter 4 */
    }

