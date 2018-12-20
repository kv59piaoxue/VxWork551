/* excArchShow.c - SH exception show facilities */

/* Copyright 1994-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02f,10dec01,zl   removed local typedefs of UINT64 and INT64.
02e,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
02d,22jun00,hk   changed fpscr display for SH7750.
02c,20apr00,hk   changed sysBErrVecNum to excBErrVecNum.
02b,19aug99,zl   included floating point info for SH7750.
02a,07oct98,st   deleted debug code in excInfoShow().
01z,22sep98,hms  deleted SH7700 "NULL" message in excMsgs[] (0x120, 0x140)
                 and added comment "SH7750 only".
                 deleted debug code. modified comments.
		 change "SCIF1","SCIF2" message in excMsgs[] to "SCI","SCIF".
01y,16jul98,st   added SH7750 support.
01y,08may98,jmc  added support for SH-DSP and SH3-DSP.
01z,12may98,hk   added FPSCR support in excInfoShow().
01w,26nov97,hms  added fpp support definitions.
01x,04jan98,hk   fixed range check for sysBErrVecNum.
01w,25nov97,hk   changed to use sequential interrupt vector number for SH7700.
01v,25apr97,hk   changed SH704X to SH7040.
01u,23feb97,hk   added validity check for EXPEVT display in excInfoShow().
01t,17feb97,hk   reworked on excMsgs[] to display uniform exception messages.
01s,17feb97,hk   did minor format change in access address display. 
01r,17feb97,hk   improved excInfoShow() to display event specific registers.
01q,16feb97,hk   added uninitialized interrupt messages for SH7708/SH7707 to
                 excMsgs[]. changed excIntInfoFmt and excInfoShow() for SH7700.
		 fixed SH7700 vecName fetch code in excIntInfoShow().
01p,12feb97,hk   changed excIntInfoFmt for SH7700.
01o,09feb97,hk   moved zero divide message in excMsgs[] to 2nd. message review.
01n,18jan97,hk   added access address display in excInfoShow() for SH7700.
01m,19aug96,hk   deleted bank register display from excRegsShow().
01l,19aug96,hk   moved SH7700 "Zero Divide" message in excMsgs[] to 254th.
01k,13aug96,hk   added uninitialized interrupt message for SH7700.
01j,09aug96,hk   changed exception messages for SH7700. deleted unnecessary
		 NULLs for all cpus.
01i,04aug96,hk   changed code layout.
01h,13jun96,hk   added support for SH7700. changed excRegsShow() format.
01g,06jly95,sa   added "Zero Divide" on #62 of excMsgs.
01f,27mar95,hk   added bus err support, disabled excRegsShow(), copyright 1995.
01e,17jan95,hk   added excRegsShow().
01d,15dec94,sa   changed 'Vector number %d (0-255)' -> '(0-127)'.
01c,30oct94,hk   restored 68k code, adjusted for SH.
01b,25oct94,hk   edited excMsgs[] for sh.
01a,18jul94,hk   derived from 01c of 68k. Just a stub.
*/

/*
This module contains SH architecture dependent portions of the
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
#include "fioLib.h"
#include "intLib.h"
#include "qLib.h"
#include "private/kernelLibP.h"
#include "private/funcBindP.h"
#if (CPU==SH7750 || CPU==SH7700)
#include "fppLib.h"			/* FP_CONTEXT */
#include "private/taskLibP.h"		/* pTaskLastFpTcb prototype */
#endif


/* external data */

IMPORT int excBErrVecNum;	/* interrupt vecter number used for bus error */

/* locals */

/* 
 * Exception error messages.  These are used by the exception printing routine.
 * Exception numbers are the same as used by the CPU.
 */

LOCAL char *excMsgs [] =
    {
#if (CPU==SH7750 || CPU==SH7700)
    "(VxWorks Software Breakpoint)",	/*  0 0x000: */
    "Zero Divide",			/*  1 0x020: */
    "TLB Miss/Invalid (Load)",		/*  2 0x040: */
    "TLB Miss/Invalid (Store)",		/*  3 0x060: */
    "Initial Page Write",		/*  4 0x080: */
    "TLB Protection Violation (Load)",	/*  5 0x0a0: */
    "TLB Protection Violation (Store)",	/*  6 0x0c0: */
    "Address Error (Load)",		/*  7 0x0e0: */
    "Address Error (Store)",		/*  8 0x100: */
    "FPU Exception",			/*  9 0x120: (SH7750/SH7700 only) */
    "TLB Multiple Hit",			/* 10 0x140: (SH7750 only) */
    "Unconditional Trap",		/* 11 0x160: */
    "Reserved Instruction Code",	/* 12 0x180: */
    "Illegal Slot Instruction",		/* 13 0x1a0: */
    "(NMI)",				/* 14 0x1c0: */
    "User Breakpoint Trap",		/* 15 0x1e0: */
    "(IRL15)",				/* 16 0x200: */
    "(IRL14)",				/* 17 0x220: */
    "(IRL13)",				/* 18 0x240: */
    "(IRL12)",				/* 19 0x260: */
    "(IRL11)",				/* 20 0x280: */
    "(IRL10)",				/* 21 0x2a0: */
    "(IRL9)",				/* 22 0x2c0: */
    "(IRL8)",				/* 23 0x2e0: */
    "(IRL7)",				/* 24 0x300: */
    "(IRL6)",				/* 25 0x320: */
    "(IRL5)",				/* 26 0x340: */
    "(IRL4)",				/* 27 0x360: */
    "(IRL3)",				/* 28 0x380: */
    "(IRL2)",				/* 29 0x3a0: */
    "(IRL1)",				/* 30 0x3c0: */
    NULL,				/* 31 0x3e0: (reserved) */
    "(TMU0 Underflow)",			/* 32 0x400: */
    "(TMU1 Underflow)",			/* 33 0x420: */
    "(TMU2 Underflow)",			/* 34 0x440: */
    "(TMU2 Input Capture)",		/* 35 0x460: */
    "(RTC Alarm Int)",			/* 36 0x480: */
    "(RTC Periodic Int)",		/* 37 0x4a0: */
    "(RTC Carry Int)",			/* 38 0x4c0: */
    "(SCI Rx Err)",			/* 39 0x4e0: */
    "(SCI Rx Int)",			/* 40 0x500: */
    "(SCI Tx Int)",			/* 41 0x520: */
    "(SCI Tx Err)",			/* 42 0x540: */
    "(WDT)",				/* 43 0x560: */
    "(BSC Refresh Compare Match)",	/* 44 0x580: */
    "(BSC Refresh Overflow)",		/* 45 0x5a0: */
    NULL,				/* 46 0x5c0: */
    NULL,				/* 47 0x5e0: */
#if (CPU==SH7750)
    "JTAG",				/* 48 0x600: */
    NULL,				/* 49 0x620: */
    "(DMAC DMTE0)",			/* 50 0x640: */
    "(DMAC DMTE1)",			/* 51 0x660: */
    "(DMAC DMTE2)",			/* 52 0x680: */
    "(DMAC DMTE3)",			/* 53 0x6a0: */
    "(DMAC DMTER)",			/* 54 0x6c0: */
    NULL,				/* 55 0x6e0: */
    "(SCIF Rx Err)",			/* 56 0x700: */
    "(SCIF Rx Int)",			/* 57 0x720: */
    "(SCIF Tx Int)",			/* 58 0x740: */
    "(SCIF Tx Err)",			/* 59 0x760: */
    NULL,				/* 60 0x780: */
    NULL,				/* 61 0x7a0: */
    NULL,				/* 62 0x7c0: */
    NULL,				/* 63 0x7e0: */
    "FPU Disable",			/* 64 0x800: */
    "Illegal Slot Instruction(FPU)",	/* 65 0x820: */
    NULL,				/* 66 0x840: */
    NULL,				/* 67 0x860: */
    NULL,				/* 68 0x880: */
    NULL,				/* 69 0x8a0: */
    NULL,				/* 70 0x8c0: */
    NULL,				/* 71 0x8e0: */
    NULL,				/* 72 0x900: */
    NULL,				/* 73 0x920: */
    NULL,				/* 74 0x940: */
    NULL,				/* 75 0x960: */
    NULL,				/* 76 0x980: */
    NULL,				/* 77 0x9a0: */
    NULL,				/* 78 0x9c0: */
    NULL,				/* 79 0x9e0: */
#elif (CPU==SH7700)
    "(IRQ0)",				/* 48 0x600: SH7707 */
    "(IRQ1)",				/* 49 0x620: SH7707 */
    "(IRQ2)",				/* 50 0x640: SH7707 */
    "(IRQ3)",				/* 51 0x660: SH7707 */
    "(IRQ4)",				/* 52 0x680: SH7707 */
    "(IRQ5)",				/* 53 0x6a0: SH7707 */
    NULL,				/* 54 0x6c0: */
    NULL,				/* 55 0x6e0: */
    "(PINT0 - PINT7)",			/* 56 0x700: SH7707 */
    "(PINT8 - PINT15)",			/* 57 0x720: SH7707 */
    NULL,				/* 58 0x740: */
    NULL,				/* 59 0x760: */
    NULL,				/* 60 0x780: */
    NULL,				/* 61 0x7a0: */
    NULL,				/* 62 0x7c0: */
    NULL,				/* 63 0x7e0: */
    "(DMAC0)",				/* 64 0x800: SH7707 */
    "(DMAC1)",				/* 65 0x820: SH7707 */
    "(DMAC2)",				/* 66 0x840: SH7707 */
    "(DMAC3)",				/* 67 0x860: SH7707 */
    "(SCIF1 Rx Err)",			/* 68 0x880: SH7707 */
    "(SCIF1 Rx Int)",			/* 69 0x8a0: SH7707 */
    "(SCIF1 Break Int)",		/* 70 0x8c0: SH7707 */
    "(SCIF1 Tx Int)",			/* 71 0x8e0: SH7707 */
    "(SCIF2 Rx Err)",			/* 72 0x900: SH7707 */
    "(SCIF2 Rx Int)",			/* 73 0x920: SH7707 */
    "(SCIF2 Break Int)",		/* 74 0x940: SH7707 */
    "(SCIF2 Tx Int)",			/* 75 0x960: SH7707 */
    "(AD)",				/* 76 0x980: SH7707 */
    "(LCD)",				/* 77 0x9a0: SH7707 */
    "(PC Card 0)",			/* 78 0x9c0: SH7707 */
    "(PC Card 1)",			/* 79 0x9e0: SH7707 */
#endif /* CPU==SH7700 */

#elif (CPU==SH7600 || CPU==SH7000)
    NULL,				/*  0: (power-on reset pc) */
    NULL,				/*  1: (power-on reset sp) */
    NULL,				/*  2: (manual reset pc) */
    NULL,				/*  3: (manual reset sp) */
    "Reserved Instruction Code",	/*  4: */
    NULL,				/*  5: (reserved) */
    "Illegal Slot Instruction",		/*  6: */
    NULL,				/*  7: (reserved) */
    NULL,				/*  8: (reserved) */
    "CPU Address Error",		/*  9: */
    "DMA Address Error",		/* 10: */
    "(NMI)",				/* 11: */
    "User Break Interrupt",		/* 12: */
                                  NULL, NULL, NULL,	/* 13-15: (reserved) */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,	/* 16-23: (reserved) */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,	/* 24-31: (reserved) */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,	/* 32-39: user trap */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,	/* 40-47: user trap */
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,	/* 48-55: user trap */
    NULL, NULL, NULL, NULL, NULL, NULL,			/* 56-61: user trap */
    "Zero Divide",			/* 62: (used by VxWorks) */
    "(VxWorks Software Breakpoint)",	/* 63: (used by VxWorks) */
#endif /* CPU==SH7600 || CPU==SH7000 */
    };

#if (CPU==SH7750 || CPU==SH7700)
LOCAL char *excIntInfoFmt = "\n\
Uninitialized Interrupt!\n\
INTEVT Register: 0x%08x %s\n\
Program Counter: 0x%08x\n\
Status Register: 0x%08x\n";
#elif (CPU==SH7600 || CPU==SH7000)
LOCAL char *excIntInfoFmt = "\n\
Uninitialized Interrupt!\n\
Vector number %d (0-127). %s\n\
Program Counter: 0x%08x\n\
Status Register: 0x%08x\n";
#endif

LOCAL REG_SET excRegsBuf;

/* forward declarations */

LOCAL void excInfoShow (EXC_INFO *pExcInfo, BOOL doBell);
LOCAL void excIntInfoShow (int vecNum, ESFSH *pEsf, REG_SET *pRegs,
			   EXC_INFO *pExcInfo);
LOCAL void excPanicShow (int vecNum, ESFSH *pEsf, REG_SET *pRegs,
			 EXC_INFO *pExcInfo);
LOCAL void excRegsShow (REG_SET * pRegs);
#if (CPU==SH7750 || CPU==SH7700)
LOCAL void excFpregsShow (FP_CONTEXT * pFp);
#endif

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
    EXC_INFO *  pExcInfo,       /* exception information to summarize */
    BOOL        doBell          /* print task id and ring warning bell */
    )
    {
    FAST int valid  = pExcInfo->valid;
    FAST int vecNum = pExcInfo->vecNum;

    /* print each piece of info if valid */

    if (valid & EXC_VEC_NUM)
        {
	if ((excBErrVecNum != NONE) && (vecNum == excBErrVecNum))
	    printExc ("\nBus Error\n", 0,0,0,0,0);
        else if ((vecNum < NELEMENTS (excMsgs)) && (excMsgs [vecNum] != NULL))
            printExc ("\n%s\n", (int) excMsgs [vecNum], 0, 0, 0, 0);
        else
            printExc ("\nTrap to uninitialized vector number %d (0-255).\n",
                      vecNum, 0, 0, 0, 0);
        }

#if (CPU==SH7750 || CPU==SH7700)
    if (valid & EXC_TRAP)
        printExc ("TRA Register   : 0x%08x  (TRAPA #%d)\n",
		(int)pExcInfo->info, (int)(pExcInfo->info >> 2), 0,0,0);
    else if (valid & EXC_VEC_NUM)
        printExc ("EXPEVT Register: 0x%08x\n", INUM_TO_IEVT(vecNum),0,0,0,0);
#endif

    if (valid & EXC_PC)
        printExc ("Program Counter: 0x%08x\n", (int)pExcInfo->pc,0,0,0,0);

    if (valid & EXC_STATUS_REG)
        printExc ("Status Register: 0x%08x\n", (int)pExcInfo->sr,0,0,0,0);

#if (CPU==SH7750 || CPU==SH7700)
    if (valid & EXC_ACCESS_ADDR)
        printExc ("Access  Address: 0x%08x\n", (int)pExcInfo->info,0,0,0,0);

    if (valid & EXC_FPSCR)
	{
        printExc ("FPSCR  Register: 0x%08x  ", (int)pExcInfo->info,0,0,0,0);
	if ((UINT32)pExcInfo->info & FPSCR_CAUSE_INVALID_OP)
	    printExc ("(Invalid Operation)", 0,0,0,0,0);
	else if ((UINT32)pExcInfo->info & FPSCR_CAUSE_ZERO_DIVIDE)
	    printExc ("(Zero Divide)", 0,0,0,0,0);
	printExc ("\n", 0,0,0,0,0);
	}
#endif

    if (doBell)
	printExc ("Task: %#x \"%s\"\007\n", (int)taskIdCurrent, 
		  (int)taskName ((int)taskIdCurrent), 0, 0, 0);

#if (CPU==SH7750 || CPU==SH7700)
    if ((valid & EXC_FPSCR) && (pTaskLastFpTcb != NULL))
	excFpregsShow (pTaskLastFpTcb->pFpContext);
#endif
    }

/*******************************************************************************
*
* excIntInfoShow - print out uninitialized interrupt info
*/

LOCAL void excIntInfoShow
    (
    int		vecNum,		/* exception vector number */
    ESFSH *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* parsed exception information */
    )
    {
    char *vecName = "";

    if ((vecNum < NELEMENTS (excMsgs)) && (excMsgs [vecNum] != NULL))
	vecName = excMsgs [vecNum];

#if (CPU==SH7750 || CPU==SH7700)
    vecNum = INUM_TO_IEVT(vecNum);
#endif
    if (Q_FIRST (&activeQHead) == NULL)			/* pre kernel */
	{
	printExc (excIntInfoFmt, vecNum, (int)vecName, (int)pEsf->pc, 
		  (int)pEsf->sr, 0);
	excRegsShow (pRegs);
	}
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
    ESFSH *	pEsf,		/* pointer to exception stack frame */
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

/*******************************************************************************
*
* excRegsShow - print REG_SET on stack
*
* NOMANUAL
*/

LOCAL void excRegsShow
    (
    REG_SET *  pRegs		/* pointer to register info on stack */
    )
    {
    REG_SET *  pSave = &excRegsBuf;

    bcopy ((char *)pRegs, (char *)pSave, sizeof (REG_SET));

    printExc ("\nr0  = 0x%08x, r1  = 0x%08x, r2   = 0x%08x, r3     = 0x%08x",
	pSave->voreg[0], pSave->voreg[1], pSave->voreg[2], pSave->voreg[3], 0);
    printExc ("\nr4  = 0x%08x, r5  = 0x%08x, r6   = 0x%08x, r7     = 0x%08x",
	pSave->voreg[4], pSave->voreg[5], pSave->voreg[6], pSave->voreg[7], 0);
    printExc ("\nr8  = 0x%08x, r9  = 0x%08x, r10  = 0x%08x, r11    = 0x%08x",
	pSave->nvreg[0], pSave->nvreg[1], pSave->nvreg[2], pSave->nvreg[3], 0);
    printExc ("\nr12 = 0x%08x, r13 = 0x%08x, r14  = 0x%08x, r15/sp = 0x%08x",
	pSave->nvreg[4], pSave->nvreg[5], pSave->nvreg[6], pSave->nvreg[7], 0);
    printExc ("\ngbr = 0x%08x, vbr = 0x%08x, mach = 0x%08x, macl   = 0x%08x",
	pSave->gbr,      pSave->vbr,      pSave->mac[0],   pSave->mac[1], 0);
    printExc ("\npr  = 0x%08x, sr  = 0x%08x, pc   = 0x%08x (inst   = 0x%04x)\n",
	(int) pSave->pr, pSave->sr, (int) pSave->pc, (int) *pSave->pc, 0);
    }

#if (CPU==SH7750 || CPU==SH7700)

/*******************************************************************************
*
* excFpregsShow - print SH7750/SH7718 FPU registers on TCB
*
* NOMANUAL
*/

LOCAL void excFpregsShow
    (
    FP_CONTEXT * pFp		/* pointer to FPU register info on TCB */
    )
    {
    UINT32 fpscr = pFp->fpscr;
    char s[64];

#if (CPU==SH7750)
    if (fpscr & FPSCR_DOUBLE_PRECISION)
    {
    excFormatDbl (pFp->fpx[0], pFp->fpx[1], s);
    printExc("\ndr0  = 0x%08x%08x (%s)\n",pFp->fpx[0], pFp->fpx[1], (int)s,0,0);
    excFormatDbl (pFp->fpx[2], pFp->fpx[3], s);
    printExc ( "dr2  = 0x%08x%08x (%s)\n",pFp->fpx[2], pFp->fpx[3], (int)s,0,0);
    excFormatDbl (pFp->fpx[4], pFp->fpx[5], s);
    printExc ( "dr4  = 0x%08x%08x (%s)\n",pFp->fpx[4], pFp->fpx[5], (int)s,0,0);
    excFormatDbl (pFp->fpx[6], pFp->fpx[7], s);
    printExc ( "dr6  = 0x%08x%08x (%s)\n",pFp->fpx[6], pFp->fpx[7], (int)s,0,0);
    excFormatDbl (pFp->fpx[8], pFp->fpx[9], s);
    printExc ( "dr8  = 0x%08x%08x (%s)\n",pFp->fpx[8], pFp->fpx[9], (int)s,0,0);
    excFormatDbl (pFp->fpx[10], pFp->fpx[11], s);
    printExc ( "dr10 = 0x%08x%08x (%s)\n",pFp->fpx[10],pFp->fpx[11],(int)s,0,0);
    excFormatDbl (pFp->fpx[12], pFp->fpx[13], s);
    printExc ( "dr12 = 0x%08x%08x (%s)\n",pFp->fpx[12],pFp->fpx[13],(int)s,0,0);
    excFormatDbl (pFp->fpx[14], pFp->fpx[15], s);
    printExc ( "dr14 = 0x%08x%08x (%s)\n",pFp->fpx[14],pFp->fpx[15],(int)s,0,0);
    }
    else
#endif
    {
    excFormatFlt (pFp->fpx[0], s);
    excFormatFlt (pFp->fpx[1], &s[32]);
    printExc ("\nfr0  = 0x%08x (%s)\nfr1  = 0x%08x (%s)\n",
	pFp->fpx[0], (int)s ,pFp->fpx[1], (int)&s[32], 0);

    excFormatFlt (pFp->fpx[2], s);
    excFormatFlt (pFp->fpx[3], &s[32]);
    printExc ("fr2  = 0x%08x (%s)\nfr3  = 0x%08x (%s)\n",
	pFp->fpx[2], (int)s, pFp->fpx[3], (int)&s[32], 0);

    excFormatFlt (pFp->fpx[4], s);
    excFormatFlt (pFp->fpx[5], &s[32]);
    printExc ("fr4  = 0x%08x (%s)\nfr5  = 0x%08x (%s)\n",
	pFp->fpx[4], (int)s, pFp->fpx[5], (int)&s[32], 0);

    excFormatFlt (pFp->fpx[6], s);
    excFormatFlt (pFp->fpx[7], &s[32]);
    printExc ("fr6  = 0x%08x (%s)\nfr7  = 0x%08x (%s)\n",
	pFp->fpx[6], (int)s, pFp->fpx[7], (int)&s[32], 0);

    excFormatFlt (pFp->fpx[8], s);
    excFormatFlt (pFp->fpx[9], &s[32]);
    printExc ("fr8  = 0x%08x (%s)\nfr9  = 0x%08x (%s)\n",
	pFp->fpx[8], (int)s, pFp->fpx[9], (int)&s[32], 0);

    excFormatFlt (pFp->fpx[10], s);
    excFormatFlt (pFp->fpx[11], &s[32]);
    printExc ("fr10 = 0x%08x (%s)\nfr11 = 0x%08x (%s)\n",
	pFp->fpx[10], (int)s, pFp->fpx[11], (int)&s[32], 0);

    excFormatFlt (pFp->fpx[12], s);
    excFormatFlt (pFp->fpx[13], &s[32]);
    printExc ("fr12 = 0x%08x (%s)\nfr13 = 0x%08x (%s)\n",
	pFp->fpx[12], (int)s, pFp->fpx[13], (int)&s[32], 0);

    excFormatFlt (pFp->fpx[14], s);
    excFormatFlt (pFp->fpx[15], &s[32]);
    printExc ("fr14 = 0x%08x (%s)\nfr15 = 0x%08x (%s)\n",
	pFp->fpx[14], (int)s, pFp->fpx[15], (int)&s[32], 0);
    }

    printExc ("fpul = 0x%08x\n", pFp->fpul, 0,0,0,0);

    /* dump FPSCR */
	{
	int i,j;
	UINT32 val = fpscr;
	char buf[32+1+3];

	for (i=0, j=0; i<32; ++i, ++j)
	    {
	    if (i==8 || i==16 || i==24) buf[j++] = ' ';

	    if (val & 0x80000000) buf[j] = '1'; else buf[j] = '0';
	    val <<= 1;
	    }
	buf [35] = '\0';
	printExc ("fpscr=(%s)\n", (int)buf,0,0,0,0);
	}
    printExc ("                  |||||      |     |    |     \n",0,0,0,0,0);

    switch (fpscr & FPSCR_ROUND_MODE_MASK)
	{
	case FPSCR_ROUND_TO_ZERO:	strcpy (s, "round to zero");	break;
	case FPSCR_ROUND_TO_NEAREST:	strcpy (s, "round to nearest");	break;
	default:			strcpy (s, "<reserved>");
	}
    printExc ("                  |||||      |     |    RM: %s\n",
		(int)s,0,0,0,0);

    s[0] = '\0';
    if (fpscr & FPSCR_FLAG_INVALID_OP)	strcat (s, " Invalid");
    if (fpscr & FPSCR_FLAG_ZERO_DIVIDE)	strcat (s, " Zero-Divide");
    if (fpscr & FPSCR_FLAG_OVERFLOW)	strcat (s, " Overflow");
    if (fpscr & FPSCR_FLAG_UNDERFLOW)	strcat (s, " Underflow");
    if (fpscr & FPSCR_FLAG_INEXACT)	strcat (s, " Inexact");
    if (s[0] == '\0') strcpy (s, " <none>");
    printExc ("                  |||||      |     Flag:%s\n",(int)s,0,0,0,0);

    s[0] = '\0';
    if (fpscr & FPSCR_ENABLE_INVALID_OP)strcat (s, " Invalid");
    if (fpscr & FPSCR_ENABLE_ZERO_DIVIDE)strcat (s, " Zero-Divide");
    if (fpscr & FPSCR_ENABLE_OVERFLOW)	strcat (s, " Overflow");
    if (fpscr & FPSCR_ENABLE_UNDERFLOW)	strcat (s, " Underflow");
    if (fpscr & FPSCR_ENABLE_INEXACT)	strcat (s, " Inexact");
    if (s[0] == '\0') strcpy (s, " <none>");
    printExc ("                  |||||      Enable:%s\n",(int)s,0,0,0,0);

    s[0] = '\0';
    if (fpscr & FPSCR_CAUSE_FPU_ERROR)	strcat (s, " FPU-Error");
    if (fpscr & FPSCR_CAUSE_INVALID_OP)	strcat (s, " Invalid");
    if (fpscr & FPSCR_CAUSE_ZERO_DIVIDE)strcat (s, " Zero-Divide");
    if (fpscr & FPSCR_CAUSE_OVERFLOW)	strcat (s, " Overflow");
    if (fpscr & FPSCR_CAUSE_UNDERFLOW)	strcat (s, " Underflow");
    if (fpscr & FPSCR_CAUSE_INEXACT)	strcat (s, " Inexact");
    if (s[0] == '\0') strcpy (s, " <none>");
    printExc ("                  ||||Cause:%s\n",(int)s,0,0,0,0);

    strcpy (s, fpscr & FPSCR_DENORM_TRUNCATE ? "zero" : "it is");
    printExc ("                  |||DN: treat denormalized number as %s\n",
		(int)s,0,0,0,0);

#if (CPU==SH7750)
    strcpy (s, fpscr & FPSCR_DOUBLE_PRECISION ? "double" : "single");
    printExc ("                  ||PR: %s precision\n",(int)s,0,0,0,0);

    strcpy (s, fpscr & FPSCR_FMOV_32BIT_PAIR ? "32bit pair" : "one 32bit");
    printExc ("                  |SZ: fmov transfers %s\n",(int)s,0,0,0,0);

    strcpy (s, fpscr & FPSCR_BANK1_SELECT ? "bank 1" : "bank 0");
    printExc ("                  FR: select FP register %s\n",(int)s,0,0,0,0);
#endif /*CPU==SH7750*/
    }

/******************************************************************************
*
* excFormatDbl - format double precision FP number into ASCII string
*
* RETURNS: OK, or ERROR
*
* NOMANUAL
*/

STATUS excFormatDbl
    (
    UINT32 upper32,
    UINT32 lower32,
    char *s
    )
    {
    UINT64 dval, body;
    BOOL sign;

    dval = upper32;
    dval <<= 32;
    dval += lower32;

    body = dval & 0x7fffffffffffffff;
    sign = dval & 0x8000000000000000 ? TRUE : FALSE;

    if      (body >= 0x7ff8000000000000) strcpy (s, "sNaN");
    else if (body >  0x7ff0000000000000) strcpy (s, "qNaN");
    else if (body == 0x7ff0000000000000) strcpy (s,  sign ? "-Inf" : "+Inf");
    else if (body == 0x0000000000000000) strcpy (s,  sign ? "-0.0" : "+0.0");
    else
	{
	int   exp = ((body & 0x7ff0000000000000) >> 52) - 1023;
	INT64 rem =   body & 0x000fffffffffffff;
	INT64 pow2to52 = 0x0010000000000000;
	int i;
	char buf[32];
	
	for (i=0; i<17; i++)
	    {
	    int quot = (rem * 10) / pow2to52;

	    if (quot > 9 || quot < 0)
		{
		strcpy (s, "error\n");
		return ERROR;
		}

	    buf[i] = (UINT8)quot | 0x30;
	    rem = (rem * 10) - (pow2to52 * quot);
	    }
	buf[i] = '\0';

	if (body >= pow2to52)
	    sprintf (s, "%s%s x 2^%+d", sign ? "-1." : "+1.", buf, exp);
	else
	    sprintf (s, "%s%s x 2^%+d", sign ? "-0." : "+0.", buf, exp + 1);
	}
    return OK;
    }

/******************************************************************************
*
* excFormatFlt - format single precision FP number into ASCII string
*
* RETURNS: OK, or ERROR
*
* NOMANUAL
*/

STATUS excFormatFlt
    (
    UINT32 fval,
    char *s
    )
    {
    UINT32 body = fval & 0x7fffffff;
    BOOL   sign = fval & 0x80000000 ? TRUE : FALSE;

    if      (body >= 0x7fc00000) strcpy (s, "sNaN");
    else if (body >  0x7f800000) strcpy (s, "qNan");
    else if (body == 0x7f800000) strcpy (s,  sign ? "-Inf" : "+Inf");
    else if (body == 0x00000000) strcpy (s,  sign ? "-0.0" : "+0.0");
    else
	{
	int exp = ((body & 0x7f800000) >> 23) - 127;
	int rem =   body & 0x007fffff;
	int pow2to23 = 0x00800000;
	int i;
	char buf[16];

	for (i=0; i<8; i++)
	    {
	    int quot = (rem * 10) / pow2to23;

	    if (quot > 9 || quot < 0)
		{
		strcpy (s, "error\n");
		return ERROR;
		}

	    buf[i] = (UINT8)quot | 0x30;
	    rem = (rem * 10) - (pow2to23 * quot);
	    }
	buf[i] = '\0';

	if (body >= pow2to23)
	    sprintf (s, "%s%s x 2^%+d", sign ? "-1." : "+1.", buf, exp);
	else
	    sprintf (s, "%s%s x 2^%+d", sign ? "-0." : "+0.", buf, exp + 1);
	}
    return OK;
    }

#endif /* CPU==SH7750 || CPU==SH7700 */
