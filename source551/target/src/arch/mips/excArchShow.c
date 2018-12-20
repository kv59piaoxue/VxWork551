/* excArchShow.c - mips exception show facilities */

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
01l,17may02,pes  Corrected use of _WRS_R3K_EXC_SUPPORT macro
01k,20dec01,mem  Correct execption error messages for #2-4. (SPR 72283).
01j,16jul01,ros  add CofE comment
01i,20dec00,pes  Update for MIPS32/MIPS64 target combinations.
01h,10sep99,myz  added CW4000_16 support.
01g,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01f,18dec96,tam  modified excInfoShow() to display further information for 
		 break exception (spr #2363).
01e,13jul96,cah  added R4650 CPU type definition checks
01d,18apr96,rml  added R4650 specific exception descriptions
01c,18oct93,cd   added R4000 support.
01b,23aug92,jcf  made filename consistant.
01a,02aug92,jcf  extracted from excR3kLib.c.
*/

/*
This module contains MIPS architecture dependent portions of the
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


/* locals */

/* 
 * Exception error messages.  These are used by the exception printing routine.
 * Exception numbers are the same as used by the CPU
 */

#ifdef _WRS_R3K_EXC_SUPPORT
LOCAL char *excMsgs [] =
    {
    "Non operational vector",
    "Tlb MOD Exception",
    "Tlb Load Exception",
    "Tlb Store Exception",
    "Address load Exception",
    "Address store Exception",
    "Instruction bus error",
    "Data bus error",
    "Syscall Exception",
    "Breakpoint Exception",
    "Reserved Instruction Exception",
    "Co-processor unusable Exception",
    "Overflow Exception",
    "Reserved0 Exception",
    "Reserved1 Exception",
    "Reserved2 Exception",
    "software interrupt 0",
    "software interrupt 1",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "unimplemented FPA operation",
    "invalid FPA operation",
    "FPA div by zero",
    "FPA overflow exception",
    "FPA underflow exception",
    "FPA inexact operation",
    "non-cpu bus error interrupt",
    };

#else
LOCAL char *excMsgs [] =
    {
    "Non operational vector",
    "Tlb MOD Exception",
    "Tlb Load Exception",
    "Tlb Store Exception",
    "Address load Exception",
    "Address store Exception",
    "Instruction bus error",
    "Data bus error",
    "Syscall Exception",
    "Breakpoint Exception",
    "Reserved Instruction Exception",
    "Co-processor unusable Exception",
    "Overflow Exception",
    "Trap Exception",
    "Reserved 14 Exception",
    "FPE Exception",
    "Reserved 16 Exception",
    "Reserved 17 Exception",
    "Reserved 18 Exception",
    "Reserved 19 Exception",
    "Reserved 20 Exception",
    "Reserved 21 Exception",
    "Reserved 22 Exception",
    "Watch Exception",
    "Reserved 24 Exception",
    "Reserved 25 Exception",
    "Reserved 26 Exception",
    "Reserved 27 Exception",
    "Reserved 28 Exception",
    "Reserved 29 Exception",
    "Reserved 30 Exception",
    "Reserved 31 Exception",
    "software interrupt 0",
    "software interrupt 1",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "User defined interrupt",
    "unimplemented FPA operation",
    "invalid FPA operation",
    "FPA div by zero",
    "FPA overflow exception",
    "FPA underflow exception",
    "FPA inexact operation",
    "non-cpu bus error interrupt",
    };
#endif

LOCAL char *excIntInfoFmt = "\n\
Uninitialized Interrupt!\n\
Vector number %d (0-255). %s\n\
Program Counter: 0x%08x\n\
Status Register: 0x%04x\n";

/* forward declarations */

LOCAL void excInfoShow (EXC_INFO *pExcInfo, BOOL doBell);
LOCAL void excIntInfoShow (int vecNum, ESFMIPS *pEsf, USHORT eid);
LOCAL void excPanicShow (int vecNum, ESFMIPS *pEsf, REG_SET *pRegs,
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
    EXC_INFO *	pExcInfo,
    BOOL	doBell
    )
    {
    FAST int valid  = pExcInfo->valid;
    FAST int vecNum = pExcInfo->vecNum;
    FAST UINT32 brkCode;

    /* print each piece of info if valid */

    if (valid & EXC_VEC_NUM)
	{
	if ((vecNum < NELEMENTS (excMsgs)) && (excMsgs [vecNum] != NULL))
	    printExc ("\n%s\n", (int) excMsgs [vecNum], 0, 0, 0, 0);	
	else
	    printExc ("\nTrap to uninitialized vector number %d (16-255).\n",
		      vecNum, 0, 0, 0, 0);
	}

    /* the following code checks the code field of the break instruction in 
     * order to determine the reason for the break instruction: the compiler
     * adds extra code to trap integer div. by zero or interger overflow using 
     * a break instruction since there's no exception specific to these 
     * conditions.
     */

    if (vecNum == IV_BP_VEC)
	{
	/* read break instr. code field */

	brkCode = ((*(UINT32 *) pExcInfo->epc) & EXC_BRK_CODE_MSK) >> 6;

	switch (brkCode)
	    {
	    case (EXC_BRK_DIV_BY_ZERO):
		printExc ("Caused by an Integer Divide by Zero\n",0,0,0,0,0);
		break;
	    case (EXC_BRK_INT_OVF):
		printExc ("Caused by an Integer Overflow\n",0,0,0,0,0);
		break;
	    default:
		break;
	    }
	}

    /* display relevant registers */

    if (valid & EXC_EPC)
	printExc ("Exception Program Counter: 0x%08x\n", 
		  (int) pExcInfo->epc, 0, 0, 0, 0);

    if (valid & EXC_STATUS_REG)
	printExc ("Status Register: 0x%08x\n", 
		  (int) pExcInfo->statusReg, 0, 0, 0, 0);

    if (valid & EXC_CAUSE_REG)
	printExc ("Cause Register: 0x%08x\n", 
		  (int) pExcInfo->causeReg, 0, 0, 0, 0);

    if (valid & EXC_ACCESS_ADDR)
	printExc ("Access Address : 0x%08x\n", 
		  (int) pExcInfo->badVa, 0, 0, 0, 0);

    if (valid & EXC_FP_STATUS_REG)
        printExc ("Fp Status Register: 0x%08x\n", 
		  (int) pExcInfo->fpcsr, 0, 0, 0, 0);

    if (valid & EXC_ERROR_ADDR)
	{
        printExc ("Error address: 0x%08x, Error ID: 0x%04x\n",
		    (int) pExcInfo->ear, (int) pExcInfo->eid, 0, 0, 0);
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
    int		vecNum,		/* vector number */
    ESFMIPS *	pEsf,		/* pointer to exception stack frame */
    USHORT	eid
    )
    {
    ULONG  	ear;
    char *	vecName = "";

    IMPORT ULONG sysBusEar();

    if ((vecNum < NELEMENTS (excMsgs)) && (excMsgs [vecNum] != NULL))
	vecName = excMsgs [vecNum];

    logMsg (excIntInfoFmt, vecNum, (int)vecName, (int)pEsf->esfRegs.pc,
	    (int)pEsf->esfRegs.sr, eid, 0);

    if (vecNum == IV_BUS_ERROR_VEC)
	{
	ear = sysBusEar();	/* read error address reg */
        logMsg ("Error address: 0x%08x, Error ID: 0x%04x\n", (int)ear, (int)eid,
		0, 0, 0, 0);
	}
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
    ESFMIPS *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* parsed exception information */
    )
    {
    printExc (" \nException at interrupt level:\n", 0, 0, 0, 0, 0);
    excInfoShow (pExcInfo, FALSE);	/* print the message into sysExcMsg */
    printExc ("Regs at 0x%x\n", (int) pRegs, 0, 0, 0, 0);
    }
