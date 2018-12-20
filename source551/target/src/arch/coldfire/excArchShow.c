/* excArchShow.c - ColdFire exception show facilities */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,12feb02,rec  report divzero exception
01b,19jun00,ur   Removed all non-Coldfire stuff.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
This module contains ColdFire architecture dependent portions of the
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
#include "intLib.h"
#include "qLib.h"
#include "private/kernelLibP.h"
#include "private/funcBindP.h"


/* locals */

/* 
 * Exception error messages.  These are used by the exception printing routine.
 * Exception numbers are the same as used by the CPU.
 */

LOCAL char *excMsgs [] =
    {
    NULL,				/*  0 reset sp */
    NULL,				/*  1 reset pc */
    "Access Error",			/*  2 */
    "Address Error",			/*  3 */
    "Illegal Instruction",		/*  4 */
    "Divide By Zero",			/*  5 */
    NULL, NULL,				/*  6-7 reserved */
    "Privilege Violation",		/*  8 */
    "Trace Exception",			/*  9 */
    "Unimplemented Line-A Opcode",	/* 10 */
    "Unimplemented Line-F Opcode",	/* 11 */
#if (CPU==MCF5400)
    "Non-PC Breakpoint Debug Interrupt"	/* 12 */
    "PC Breakpoint Debug Interrupt"	/* 13 */
#else
    "Debug Interrupt",			/* 12 */
    NULL,				/* 13 reserved*/
#endif
    "Format Error",			/* 14 */
    "Uninitialized Interrupt",		/* 15 */
    NULL, NULL, NULL, NULL,		/* 16-23 reserved */
    NULL, NULL, NULL, NULL,
    "Spurious Interrupt",		/* 24 */
    NULL, NULL, NULL, NULL,             /* 25-31 autovectored interrupts */
    NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,             /* 32-47 TRAP #0-15 vectors */
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,		/* 48-63 reserved */
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL,
    NULL, NULL, NULL, NULL
    };

LOCAL char *excIntInfoFmt = "\n\
Uninitialized Interrupt!\n\
Vector number %d (0-255). %s\n\
Program Counter: 0x%08x\n\
Status Register: 0x%04x\n";

LOCAL char *excFsMsg [] =
    {
    NULL, NULL,					/*  0-1 reserved */
#if (CPU==MCF5400)
    "Interrupt during a debug service routine",	/*  2 */
#else
    NULL,					/*  2 reserved */
#endif
    NULL,					/*  3 reserved */
    "Error on Instruction Fetch",		/*  4 */
    NULL, NULL, NULL,				/*  5-7 reserved */
    "Error on Operand Write",			/*  8 */
    "Attempted Write to Write-Protected Space",	/*  9 */
    NULL, NULL,					/* 10-11 reserved */
    "Error on Operand Read",			/* 12 */
    NULL, NULL, NULL				/* 13-15 reserved */
    };

/* forward declarations */

LOCAL void excInfoShow (EXC_INFO *pExcInfo, BOOL doBell);
LOCAL void excIntInfoShow (int vecNum, void *pEsf, REG_SET *pRegs,
			   EXC_INFO *pExcInfo);
LOCAL void excPanicShow (int vecNum, void *pEsf, REG_SET *pRegs,
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

    return (OK);
    }

/*******************************************************************************
*
* excInfoShow - print exception info
*
* NOMANUAL
*/

LOCAL void excInfoShow
    (
    EXC_INFO *	pExcInfo,	/* exception information to summarize */
    BOOL	doBell		/* print task id and ring warning bell */
    )
    {
    int valid  = pExcInfo->valid;
    int vecNum = pExcInfo->vecNum;
    int fsNum  = ESFCOLD_FS_UNPACK (pExcInfo->funcCode);
    int format = ESFCOLD_FORMAT_UNPACK (pExcInfo->funcCode);

    /* print each piece of info if valid */

    if (valid & EXC_VEC_NUM)
	{
	if ((vecNum < NELEMENTS (excMsgs)) && (excMsgs [vecNum] != NULL))
	    {
    	    if ((valid & EXC_FUNC_CODE) &&
		fsNum != 0 &&	/* fsNum == 0 : fault status invalid */
		excFsMsg[fsNum] != NULL)
		{
		printExc ("\n%s (%s)\n", (int) excMsgs [vecNum],
					 (int) excFsMsg[fsNum], 0, 0, 0);
	        }
	    else
	        printExc ("\n%s\n", (int) excMsgs [vecNum], 0, 0, 0, 0);
	    }
	else
	    printExc ("\nTrap to uninitialized vector number %d (0-255).\n",
		      vecNum, 0, 0, 0, 0);
	}

    if (valid & EXC_PC)
	printExc ("Program Counter: 0x%08x\n", (int) pExcInfo->pc, 0, 0, 0, 0);

    if (valid & EXC_STATUS_REG)
	printExc ("Status Register: 0x%04x\n", (int) pExcInfo->statusReg, 0, 0,
		  0, 0);

    if (valid & EXC_FUNC_CODE)
	{
	printExc ("Format         : 0x%02x\n", format, 0, 0, 0, 0);
	printExc ("Fault Status   : 0x%x\n", fsNum, 0, 0, 0, 0);
        }

    if (doBell)
	printExc ("Task: %#x \"%s\"\007\n", (int)taskIdCurrent, 
		  (int)taskName ((int)taskIdCurrent), 0, 0, 0);
    }
/*******************************************************************************
*
* excIntInfoShow - print out uninitialized interrupt info
*/

LOCAL void excIntInfoShow
    (
    int		vecNum,		/* exception vector number */
    void *	pEsfInfo,	/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* parsed exception information */
    )
    {
    char *vecName = "";
    ESFCOLD *pEsf = (ESFCOLD *) pEsfInfo;

    if ((vecNum < NELEMENTS (excMsgs)) && (excMsgs [vecNum] != NULL))
	vecName = excMsgs [vecNum];

    if (Q_FIRST (&activeQHead) == NULL)			/* pre kernel */
	printExc (excIntInfoFmt, vecNum, (int)vecName, (int)pEsf->pc, 
		  (int)pEsf->sr, 0);
    else
	logMsg (excIntInfoFmt, vecNum, (int)vecName, (int)pEsf->pc,
		(int)pEsf->sr, 0, 0);
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
    int		vecNum,		/* exception vector number */
    void *	pEsfInfo,	/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* parsed exception information */
    )
    {
    if (INT_CONTEXT ())
	printExc (" \nException at interrupt level:\n", 0, 0, 0, 0, 0);

    if (Q_FIRST (&activeQHead) == NULL)
	printExc ("Exception before kernel initialized:\n", 0, 0, 0, 0, 0);

    excInfoShow (pExcInfo, FALSE);	/* print the message into sysExcMsg */

    printExc ("Regs at 0x%x\n", (int) pRegs, 0, 0, 0, 0);
    }
