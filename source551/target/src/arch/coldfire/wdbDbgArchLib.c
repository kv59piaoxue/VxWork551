/* wdbDbgArchLib.c - ColdFire specific callouts for the debugger */

/* Copyright 1988-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This module contains the architecture specific calls needed by the
WDB debug agent and the target shell debugger.
*/


#include "vxWorks.h"
#include "regs.h"
#include "iv.h"
#include "intLib.h"
#include "wdb/wdbDbgLib.h"

#define TRACE_BIT       0x8000  		/* trace bit in 68K SR */

extern void wdbDbgBpStub();
extern void wdbDbgTraceStub();

/*******************************************************************************
*
* wdbDbgArchInit - set exception handlers for the break and the trace.
*
* This routine set exception handlers for the break and the trace.
* And also make a break instruction.
*/

void wdbDbgArchInit(void)
    {
    intVecSet ((FUNCPTR *) TRAPNUM_TO_IVEC (DBG_TRAP_NUM), 
						(FUNCPTR) wdbDbgBpStub);
    intVecSet ((FUNCPTR *) IV_TRACE, (FUNCPTR) wdbDbgTraceStub);
    }

/******************************************************************************
*
* wdbDbgTraceModeSet - lock interrupts and set the trace bit.
*/ 

int wdbDbgTraceModeSet
    (
    REG_SET *pRegs
    )
    {
    int oldSr;

    oldSr = intRegsLock (pRegs);
    pRegs->sr |= TRACE_BIT;

    return (oldSr);
    }

/******************************************************************************
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
    pRegs->sr &= ~TRACE_BIT;
    }
