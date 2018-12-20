/* wdbDbgArchLib.c - ARM-specific callouts for the debugger */

/* Copyright 1996-1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01e,13nov98,cdp  made Thumb support dependent on ARM_THUMB.
01d,20apr98,dbt  modified for new breakpoint scheme.
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,18aug97,cdp  added Thumb (ARM7TDMI_T) support.
01a,05aug96,cdp  written.
*/

/*
DESCRIPTION
This module contains the architecture-specific calls needed by the
debugger.
*/


#include "vxWorks.h"
#include "regs.h"
#include "intLib.h"
#include "excLib.h"
#include "esf.h"
#include "wdb/wdbDbgLib.h"


/* external functions */

IMPORT void wdbDbgTrap (INSTR *, REG_SET *, void *, void *, BOOL);
#if (ARM_THUMB)
IMPORT INSTR * thumbGetNpc (INSTR, REG_SET *);
#else
IMPORT INSTR * armGetNpc (INSTR, REG_SET *);
#endif


/* forward declarations */

LOCAL void wdbDbgArmBreakpoint (ESF *, REG_SET *);

/*******************************************************************************
*
* wdbDbgArchInit - set exception handlers for the break and the trace.
*
* This routine installs an exception handler for the Breakpoint/Trace
* exception. In reality, this is just a back door to the undefined
* instruction handler.
*/

void wdbDbgArchInit(void)
    {
    /*
     * The ARM undefined instruction exception handler will check that the
     * undefined instruction is the breakpoint instruction and pass control
     * to an installed breakpoint handler via a function pointer. So, install
     * our handler.
     */

    _func_excBreakpoint = wdbDbgArmBreakpoint;
    }

/*******************************************************************************
*
* wdbDbgArmBreakpoint - handler for breakpoint exception
*
* This routine is called by the kernel undefined instruction exception
* handler when it has determined that the undefined instruction was
* a breakpoint. Note that this and dbgArchLib cannot be used at the same
* time because they use the same mechanism.
*/

LOCAL void wdbDbgArmBreakpoint
    (
    ESF *	pEsf,	/* pointer to info saved on stack */
    REG_SET *	pRegs	/* pointer to saved registers */
    )
    {

    /*
     * VxWorks 5.3   (WIND version 2.4) called dbg_trap_handler()
     * VxWorks 5.3.1 (WIND version 2.5) calls wdbTrap() instead.
     * NOTE: the third arg isn't used by any of the called routines
     */

    wdbDbgTrap (pEsf->pc, pRegs, (void *) NULL, NULL, FALSE);
    }

/*******************************************************************************
*
* wdbDbgTraceModeSet - lock interrupts and set the trace bit.
*/

int wdbDbgTraceModeSet
    (
    REG_SET *pRegs
    )
    {
    return intRegsLock (pRegs);
    }

/*******************************************************************************
*
* wdbDbgTraceModeClear - restore old int lock level and clear the trace bit.
*/

void wdbDbgTraceModeClear
    (
    REG_SET *pRegs,
    int oldSr
    )
    {
    intRegsUnlock (pRegs, oldSr);
    }

/*******************************************************************************
*
* wdbDbgGetNpc - returns the address of the next instruction to be executed
*
* RETURNS: address of the next instruction to be executed.
*/

INSTR * wdbDbgGetNpc
    (
    REG_SET * pRegs			/* pointer to task registers */
    )
    {

    /*
     * VxWorks 5.3   (WIND version 2.4) called bpFind() to check for a
     * breakpoint at this address and, if there was one, fetch the
     * original instruction rather than look at the breakpoint
     * instruction
     * VxWorks 5.3.1 (WIND version 2.5) appears not to have to do this.
     */

#if (ARM_THUMB)
    return thumbGetNpc (*pRegs->pc, pRegs);
#else
    return armGetNpc (*pRegs->pc, pRegs);
#endif
    }
