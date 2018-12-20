/* dbgStrShow.c - Debug Store mechanism specific show routines */

/* Copyright 2001-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,28jun01,hdn  written.
*/

/*
DESCRIPTION
This library provides Debug Store mechanism specific show routines. 

*/

/* includes */

#include "vxWorks.h"
#include "regs.h"
#include "stdio.h"
#include "taskLib.h"
#include "dbgLib.h"
#include "symLib.h"
#include "sysSymTbl.h"
#include "sysLib.h"
#include "arch/i86/pentiumLib.h"
#include "arch/i86/dbgStrLib.h"
#include "drv/intrCtl/loApic.h"


/* defines */

#define	SHOW_BTS	1		/* show BTS records */
#define	SHOW_PEBS	2		/* show PEBS records */


/* externals */

IMPORT CPUID		sysCpuId;
IMPORT UINT32		loApicBase;
IMPORT WIND_TCB *	taskIdCurrent;
IMPORT BOOL		dbgStrSysMode;	/* DS system mode */
IMPORT DS_CONFIG	dbgStrCfg;	/* DS config */
IMPORT UINT32		sysBtsIntCnt;	/* BTS int count */
IMPORT UINT32		sysPebsIntCnt;	/* PEBS int count */


/* globals */


/* locals */

LOCAL UINT32 memTop = 0;		/* memory top address */
LOCAL char * pebsEventTbl [] = {	/* PEBS event names */
	"none",
	"front end",
	"execution",
	"replay",
	};
LOCAL char * pebsMetricTbl [] = {	/* PEBS metric names */
	"none",
	"memory loads",
	"memory stores",
	"packed SP",
	"packed DP",
	"scalar SP",
	"scalar DP",
	"128 bit MMX",
	"64 bit MMX",
	"x87 FP",
	"x87 SIMD moves",
	"1st level cache load miss",
	"2nd level cache load miss",
	"data TLB load miss",
	"data TLB store miss",
	"data TLB all miss",
	"MOB load replay",
	"split load",
	"split store",
	};


/* prototypes */

LOCAL void btsShow	(WIND_TCB * pTcb);
LOCAL void pebsShow	(WIND_TCB * pTcb);
LOCAL void btsRecShow	(BTS_REC *  pBtsRec);
LOCAL void pebsRecShow	(PEBS_REC * pPebsRec);


/*******************************************************************************
*
* dbgStrShowInit - initialize the Debug Store show facility
*
* NOMANUAL
*/

void dbgStrShowInit (void)
    {
    }

/*******************************************************************************
*
* dbgStrShow - Debug Store show routine
*
* This routine is the Debug Store show routine
*
* RETURNS: N/A
*/

void dbgStrShow
    (
    WIND_TCB * pTcb,			/* pointer to TCB */
    int type				/* 0, 1(SHOW_BTS) or 2(SHOW_PEBS) */
    )
    {
    X86_EXT * pExt = NULL;		/* X86 extension */
    DS_CONFIG * pC = NULL;		/* DS config */
    DS_BUF_HEADER * pH = NULL;		/* DS header */
    UINT32 value[2];			/* MSR 64 bits value */
    LL_UNION ll;			/* 64/32*2 union */


    /* check if the Debug Store feature is supported */

    if (((sysCpuId.featuresEdx & CPUID_DTS) == 0) ||
	(!dbgStrCfg.btsAvailable && !dbgStrCfg.pebsAvailable))
	{
	printf ("Debug Store is not supported by this processor\n");
        return;
	}

    /* show the Debug Store related MSRs */

    pentiumMsrGet (IA32_DS_AREA, (LL_INT *)&value);
    printf ("IA32_DS_AREA     : 0x%08x-%08x\n", value[1], value[0]);
    
    pentiumMsrGet (IA32_MISC_ENABLE, (LL_INT *)&value);
    printf ("IA32_MISC_ENABLE : 0x%08x-%08x\n", value[1], value[0]);

    pentiumMsrGet (IA32_DEBUGCTL, (LL_INT *)&value);
    printf ("IA32_DEBUGCTL    : 0x%08x-%08x\n", value[1], value[0]);

    pentiumMsrGet (IA32_PEBS_ENABLE, (LL_INT *)&value);
    printf ("IA32_PEBS_ENABLE : 0x%08x-%08x\n", value[1], value[0]);

    pentiumMsrGet (MSR_IQ_CCCR4, (LL_INT *)&value);
    printf ("MSR_IQ_CCCR4     : 0x%08x-%08x\n", value[1], value[0]);

    /* show the PMC entry in the LVT */

    printf ("PMC in the LVT   : 0x%08x\n", *(int *)(loApicBase + LOAPIC_PMC));

    /* show the BTS/PEBS interrupt count */

    printf ("Interrupts       : BTS=%d  PEBS=%d\n", 
	    sysBtsIntCnt, sysPebsIntCnt);

    /* get the DS config and DS header */

    if (pTcb == (WIND_TCB *)NONE)
	pC = &dbgStrCfg;
    else if (pTcb == NULL)
	pExt = (X86_EXT *)taskIdCurrent->reserved2;
    else
	pExt = (X86_EXT *)pTcb->reserved2;

    if (pExt != NULL)
        pC = (DS_CONFIG *)pExt->reserved0;

    printf ("Debug Store is %s mode\n", 
	    dbgStrSysMode ? "system" : "task");
    if ((pC == NULL) || (pC->pH == NULL))
	{
	printf ("Debug Store is disabled in this task.\n");
	return;
	}
    pH = pC->pH;

    /* show the DS config and DS header */

    printf ("Debug Store Config address = 0x%08x  Header address = 0x%08x\n",
	    (int)pC, (int)pH);
    printf ("BTS  : is %s, is %s\n", 
	    pC->btsAvailable ? "available" : "unavailable",
	    pC->btsEnabled ? "enabled" : "disabled");
    printf ("     : is configured %s mode, %s mode\n",
	    pC->btsIntMode ? "interrupt" : "circular",
	    pC->btsBufMode ? "buffer" : "bus");

    printf ("     : base=0x%08x index=0x%08x max=0x%08x threshold=0x%08x\n", 
	    (int)pH->btsBase, (int)pH->btsIndex, pH->btsMax, 
	    pH->btsThreshold);
    
    printf ("PEBS : is %s, is %s\n", 
	    pC->pebsAvailable ? "available" : "unavailable",
	    pC->pebsEnabled ? "enabled" : "disabled");
    printf ("     : event=%s, metric=%s, mode=%s\n",
	    (pC->pebsEvent < NELEMENTS (pebsEventTbl)) ? 
	     pebsEventTbl[pC->pebsEvent] : "unknown",
	    (pC->pebsMetric < NELEMENTS (pebsMetricTbl)) ? 
	     pebsMetricTbl[pC->pebsMetric] : "unknown",
	    pC->pebsOs ? "supervisor" : "user");
    printf ("     : base=0x%08x index=0x%08x max=0x%08x threshold=0x%08x\n", 
	    (int)pH->pebsBase, (int)pH->pebsIndex, pH->pebsMax, 
	    pH->pebsThreshold);
    ll.i64 = pH->pebsCtr;
    printf ("     : counter[0]=0x%08x counter[1]=0x%08x\n", 
	    ll.i32[0], ll.i32[1]);

    /* get the memory top address */

    memTop = (UINT32)sysMemTop();

    /* show BTS or PEBS, if that is specified */

    if (type == SHOW_BTS)
	btsShow (pTcb);
    else if (type == SHOW_PEBS)
	pebsShow (pTcb);
    }

/*******************************************************************************
*
* btsShow - Debug Store BTS show routine
*
* This routine is the Debug Store BTS show routine
*
* RETURNS: N/A
*/

LOCAL void btsShow 
    (
    WIND_TCB * pTcb			/* pointer to TCB */
    )
    {
    X86_EXT * pExt = NULL;		/* X86 TCB extension */
    DS_CONFIG * pC = NULL;		/* DS config */
    DS_BUF_HEADER * pH;			/* DS header */
    BTS_REC * btsRec;			/* BTS_REC */
    UINT32 predOk = 0;			/* prediction OK */
    UINT32 predNg = 0;			/* prediction NG */
    BOOL oldValue;			/* TRUE if BTS was enabled */


    /* check if the Debug Store feature is supported */

    if (((sysCpuId.featuresEdx & CPUID_DTS) == 0) ||
	(!dbgStrCfg.btsAvailable))
        return;

    /* disable the BTS */

    oldValue = dbgStrBtsEnable (FALSE);

    /* get the DS Config and DS Header */

    if (dbgStrSysMode)
	pC = &dbgStrCfg;
    else
	{
        if (pTcb == NULL)
	    pExt = (X86_EXT *)taskIdCurrent->reserved2;
        else
	    pExt = (X86_EXT *)pTcb->reserved2;
	}
    
    if (pExt != NULL)
        pC = (DS_CONFIG *)pExt->reserved0;

    if (pC == NULL)
	{
	printf ("There is no Debug Store Config\n");
	return;
	}

    pH = pC->pH;
    if (pH == NULL)
	{
	printf ("There is no Debug Store Header\n");
	return;
	}

    /* parse the BTS buffer, and display */

    if (pH->btsIndex->pcFm != 0)
	{
	for (btsRec = pH->btsIndex; btsRec < (BTS_REC *)pH->btsMax; btsRec++)
	    {
	    if (btsRec->misc & BTS_PREDICTED)
		predOk++;
	    else
		predNg++;
	    btsRecShow (btsRec);
	    }
	}

    for (btsRec = pH->btsBase; btsRec < pH->btsIndex; btsRec++)
	{
	if (btsRec->misc & BTS_PREDICTED)
	    predOk++;
	else
	    predNg++;
	btsRecShow (btsRec);
	}
    
    printf ("prediction succeeded = %d  failed = %d\n", predOk, predNg);

    /* enable the BTS if it was */

    if (oldValue)
        dbgStrBtsEnable (TRUE);
    }

/*******************************************************************************
*
* pebsShow - Debug Store PEBS show routine
*
* This routine is the Debug Store PEBS show routine
*
* RETURNS: N/A
*/

LOCAL void pebsShow 
    (
    WIND_TCB * pTcb			/* pointer to TCB */
    )
    {
    X86_EXT * pExt = NULL;		/* X86 TCB extension */
    DS_CONFIG * pC = NULL;		/* DS config */
    DS_BUF_HEADER * pH;			/* DS header */
    PEBS_REC * pebsRec;			/* PEBS_REC */
    BOOL oldValue;			/* TRUE if PEBS was enabled */


    /* check if the Debug Store feature is supported */

    if (((sysCpuId.featuresEdx & CPUID_DTS) == 0) ||
	(!dbgStrCfg.pebsAvailable))
        return;

    /* disable the PEBS */

    oldValue = dbgStrPebsEnable (FALSE);

    /* get the DS Config and DS Header */

    if (dbgStrSysMode)
	pC = &dbgStrCfg;
    else
	{
        if (pTcb == NULL)
	    pExt = (X86_EXT *)taskIdCurrent->reserved2;
        else
	    pExt = (X86_EXT *)pTcb->reserved2;
	}
    
    if (pExt != NULL)
        pC = (DS_CONFIG *)pExt->reserved0;

    if (pC == NULL)
	{
	printf ("There is no Debug Store Config\n");
	return;
	}

    pH = pC->pH;
    if (pH == NULL)
	{
	printf ("There is no Debug Store Header\n");
	return;
	}

    /* parse the PEBS buffer, and display */

    if (pH->pebsIndex->eip != 0)
	{
	for (pebsRec = pH->pebsIndex; pebsRec < (PEBS_REC *)pH->pebsMax; 
	     pebsRec++)
	    {
	    pebsRecShow (pebsRec);
	    }
	}

    for (pebsRec = pH->pebsBase; pebsRec < pH->pebsIndex; pebsRec++)
	{
	pebsRecShow (pebsRec);
	}
    
    /* enable the PEBS if it was */

    if (oldValue)
        dbgStrPebsEnable (TRUE);
    }

/*******************************************************************************
*
* btsRecShow - Debug Store BTS_REC show routine
*
* This routine is the Debug Store BTS_REC show routine
*
* RETURNS: N/A
*/

LOCAL void btsRecShow 
    (
    BTS_REC * pBtsRec			/* pointer to BTS_REC */
    )
    {

    /* this must not happen, but do it to prevent the page fault */

    if ((pBtsRec->pcFm == 0) || (pBtsRec->pcTo == 0))
	return;
	    
    if (pBtsRec->pcFm < memTop)
        l ((INSTR *)pBtsRec->pcFm, 1);
    else
	printf ("0x%08x  branch from\n", pBtsRec->pcFm);

    if (pBtsRec->pcTo < memTop)
        l ((INSTR *)pBtsRec->pcTo, 1);
    else
	printf ("0x%08x  branch to\n", pBtsRec->pcTo);
    }

/*******************************************************************************
*
* pebsRecShow - Debug Store PEBS_REC show routine
*
* This routine is the Debug Store PEBS_REC show routine
*
* RETURNS: N/A
*/

LOCAL void pebsRecShow 
    (
    PEBS_REC * pPebsRec			/* pointer to PEBS_REC */
    )
    {

    /* this must not happen, but do it to prevent the page fault */

    if (pPebsRec->eip == 0)
	return;
	    
    if (pPebsRec->eip < memTop)
        l ((INSTR *)pPebsRec->eip, 1);

    printf ("EIP=0x%08x EFLAGS=0x%08x\n", 
	    pPebsRec->eip, pPebsRec->eflags);
    printf ("EAX=0x%08x EBX=0x%08x ECX=0x%08x EDX=0x%08x\n", 
	    pPebsRec->eax, pPebsRec->ebx, pPebsRec->ecx, pPebsRec->edx);
    printf ("ESI=0x%08x EDI=0x%08x EBP=0x%08x ESP=0x%08x\n", 
	    pPebsRec->esi, pPebsRec->edi, pPebsRec->ebp, pPebsRec->esp);
    }

