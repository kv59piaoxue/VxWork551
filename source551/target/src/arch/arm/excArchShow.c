/* excArchShow.c - ARM exception show facilities */

/* Copyright 1996-1997 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,24feb98,jgn  make logMsg call indirect for scalability (SPR #20625)
01b,27oct97,kkk  took out "***EOF***" line from end of file.
01a,25jun96,cdp  created.
*/

/*
This module contains ARM architecture dependent portions of the
exception handling facilities.  See excLib for the portions that are
architecture independent.

SEE ALSO: dbgLib, sigLib, intLib, "Debugging"
*/

#include "vxWorks.h"
#include "esf.h"
#include "iv.h"
#include "taskLib.h"
#include "errno.h"
#include "string.h"
#include "logLib.h"
#include "stdio.h"
#include "stdio.h"
#include "fioLib.h"
#include "private/funcBindP.h"
#include "private/kernelLibP.h"

typedef struct {
    UINT32	vecAddr;	/* exception vector */
    char * 	excMsg;		/* exception message */
    } EXC_MSG_TBL;


/* locals */

/* 
 * Exception error messages.
 * These are used by the exception printing routine.
 */

LOCAL EXC_MSG_TBL excMsgTbl [] = {
    {EXC_OFF_RESET,	"Branch through zero"},
    {EXC_OFF_UNDEF,	"Undefined instruction"},
    {EXC_OFF_SWI,	"Software interrupt"},
    {EXC_OFF_PREFETCH,	"Instruction prefetch abort"},
    {EXC_OFF_DATA,	"Data abort"},
    {EXC_OFF_IRQ,	"Interrupt"},
    {EXC_OFF_FIQ,	"Fast interrupt"},
    {0, NULL}
    };

/* forward declarations */

LOCAL void excInfoShow (EXC_INFO *pExcInfo, BOOL doBell);
LOCAL void excIntInfoShow (void);
LOCAL void excPanicShow (int vecOff, ESF *pEsf, REG_SET *pRegs,
			 EXC_INFO *pExcInfo);


/*******************************************************************************
*
* excShowInit - initialize exception show facility
*
* NOMANUAL
*/

STATUS excShowInit (void)
    {
    _func_excInfoShow	= (FUNCPTR) excInfoShow;
    _func_excIntHook	= (FUNCPTR) excIntInfoShow;
    _func_excPanicHook	= (FUNCPTR) excPanicShow;

    return OK;
    }

/*******************************************************************************
*
* excInfoShow - print exception info
*
* NOMANUAL
*/

LOCAL void excInfoShow 
    (
    EXC_INFO *	pExcInfo,
    BOOL	doBell
    )
    {
    FAST int valid  = pExcInfo->valid;
    FAST UINT32 vecAddr = pExcInfo->vecAddr;
    FAST int i;

    /* print each piece of info if valid */

    if (valid & EXC_INFO_VECADDR)
	{
	for (i = 0; excMsgTbl[i].vecAddr != vecAddr; i++)
	    {
	    if (excMsgTbl[i].excMsg == NULL)
	        break;
	    }
	if (excMsgTbl[i].excMsg != NULL)
	    printExc ("\n%s\n", (int) excMsgTbl[i].excMsg, 0, 0, 0, 0);	
	else
	    printExc ("\nTrap to uninitialized vector address 0x%x.\n",
		      vecAddr, 0, 0, 0, 0);
	}

    if (valid & EXC_INFO_PC)
	printExc ("Exception address: 0x%08x\n", 
		  (int) pExcInfo->pc, 0, 0, 0, 0);

    if (valid & EXC_INFO_CPSR)
	printExc ("Current Processor Status Register: 0x%08x\n", 
		  (int) pExcInfo->cpsr, 0, 0, 0, 0);

    if (doBell)
	printExc ("Task: %#x \"%s\"\007\n", (int)taskIdCurrent, 
		  (int)taskName ((int)taskIdCurrent), 0, 0, 0);
    }

/*******************************************************************************
*
* excIntInfoShow - print out uninitialised interrupt info
*/

LOCAL void excIntInfoShow
    (
    )
    {
    if (Q_FIRST (&activeQHead) == NULL)		/* pre kernel */
	printExc ("uninitialised interrupt vector", 0, 0, 0, 0, 0);
    else
	if (_func_logMsg != NULL)
	    _func_logMsg ("uninitialised interrupt vector", 0, 0, 0, 0, 0, 0);
    }

/*******************************************************************************
*
* excPanicShow - exception at interrupt level
*
* This routine is called if an exception is caused at interrupt
* level.  We can't handle it in the usual way.  Instead, we save info in
* sysExcMsg and trap to rom monitor.
*/

LOCAL void excPanicShow
    (
    int		vecOff,		/* exception vector number */
    ESF *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* parsed exception information */
    )
    {
    printExc (" \nException at interrupt level:\n", 0, 0, 0, 0, 0);
    excInfoShow (pExcInfo, FALSE);	/* print the message into sysExcMsg */
    printExc ("Regs at 0x%x\n", (int) pRegs, 0, 0, 0, 0);
    }
