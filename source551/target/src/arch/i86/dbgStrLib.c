/* dbgStrLib.c - Debug Store mechanism library */

/* Copyright 2001-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,29oct02,hdn  allocated X86_EXT from stack instead.
01a,28jun01,hdn  written.
*/

/*
DESCRIPTION
This library provides Debug Store (DS) mechanism specific routines. 
The DS mechanism is introduced in the Pentium4 (P7) architecture.
The DS mechanism is used to collect two types of information that are 
branch records and precise event-based sampling records.  The availability 
of the DS mechanism in a processor is indicated with the DS feature flag 
(bit 21) returned by the CPUID instruction.

The DS save area is divided into three parts as follows: buffer
management area, branch trace store (BTS) buffer, and precise 
event-based sampling (PEBS) buffer.  The linear address of the 
first byte of the DS buffer management area is specified with the
IA32_DS_AREA MSR.  Here is the DS save area format:

      DS Buffer Management Area
      -----------------------
  0H  BTS buffer base          -> A
  4H  BTS index                -> B
  8H  BTS absolute maximum     -> C
  CH  BTS interrupt threshold
 10H  PEBS buffer base         -> X
 14H  PEBS index               -> Y
 18H  PEBS absolute maximum    -> Z
 1CH  PEBS interrupt threshold
 20H  PEBS counter reset (0-31)
 24H  PEBS counter reset (31-63)
 28H  reserved
      -----------------------

      BTS Buffer
      -----------------------
 A -> Branch Record 0
      Branch Record 1
      :
 B -> Branch Record current
      :
 C -> Branch Record n
      -----------------------

      PEBS Buffer
      -----------------------
 X -> PEBS Record 0
      PEBS Record 1
      :
 Y -> PEBS Record current
      :
 Z -> PEBS Record n
      -----------------------

The branch record is stored in the BTS buffer in the DS save area 
whenever a taken branch, interrupt, or exception is detected.
Here is the branch record format:
      0                    31
      -----------------------
  0H  Last Branch From EIP
  4H  Last Branch To EIP
  8H  Branch Predicted (bit 4)
      -----------------------

The PEBS record is stored in the PEBS buffer in the DS save area 
whenever a counter overflow occurs.  This record contains the 
architectural state of the processor (state of the 8 general purpose
registers, EIP register, and EFLAGS register) at the time of the event 
that caused the counter to overflow.  When the state information has 
been logged, the counter is automatically reset to a preselected value, 
and event counting begins again.  Here is the PEBS record format:
      0                    31
      -----------------------
  0H  EFLAGS
  4H  EIP (linear address)
  8H  EAX
  CH  EBX
 10H  ECX
 14H  EDX
 18H  ESI
 1CH  EDI
 20H  EBP
 24H  ESP
      -----------------------

When the DS mechanism is used, a 25 or 30 times slowdown can be expected
due to the effects of the trace store occurring on every taken branch.
The DS mechanism can be configured to either system mode or task mode.
In the system mode, only one DS save area is created and holds all the
BTS or PEBS records.  In the task mode, each task has its own dedicated
DS save area and holds the BTS or PEBS records while the task is executed.
The dedicated DS save area is created and deleted with the task.  And
switched as task switches.  This library provides following APIs:
.CS
  - to initialize this library.
    If the first or second parameter is zero, the default buffer size
    BTS_NBYTES_DEF or PEBS_NBYTES_DEF is used.  It is initialized to
    the system mode if the third parameter is TRUE.  Otherwise, task
    mode is used.
    STATUS dbgStrLibInit
    (
    UINT32 btsNbytes,	/@ BTS buffer size @/
    UINT32 pebsNbytes,	/@ PEBS buffer size @/
    BOOL   sysMode	/@ DS system mode @/
    )

  - to initialize the Debug Store (BTS + PEBS) buffer.
    The buffers are allocated if the pointers - that is 1st, 2nd and 5th
    params - are NULL.  
    DS_BUF_HEADER * dbgStrBufInit 
    (
    DS_BUF_HEADER * pH,		/@ Debug Store Buffer Header @/
    BTS_REC * btsBufAddr,	/@ BTS  buffer base @/
    UINT32 btsMaxOffset,	/@ BTS  absolute maximum @/
    UINT32 btsIntOffset,	/@ BTS  interrupt threshold @/
    PEBS_REC * pebsBufAddr,	/@ PEBS buffer base @/
    UINT32 pebsMaxOffset,	/@ PEBS absolute maximum @/
    UINT32 pebsIntOffset	/@ PEBS interrupt threshold @/
    )

  - to allocate the Debug Store buffers of the specified task.
    The first and second parameter of dbgStrLibInit() is used 
    for the BTS and PEBS buffer size respectively.  If the pTcb
    is NONE, the allocated buffer is set to the system DS config.
    STATUS dbgStrBufAlloc
    (
    WIND_TCB * pTcb	/@ pointer to the task's WIND_TCB @/
    )

  - to deallocate the Debug Store buffers of the specified task.
    If the pTcb is NONE, the allocated buffer for the system DS 
    config is deallocated.
    STATUS dbgStrBufFree
    (
    WIND_TCB * pTcb	/@ pointer to the task's WIND_TCB @/
    )

  - to configure the BTS/PEBS.
    This routine stores the configuration parameters in the DS_CONFIG
    structure.  If the first parameter is NONE, the system DS_CONFIG 
    structure is used.  If it is NULL, the current task's one is used.
    If the BTS interrupt mode is FALSE, the BTS buffer is used as a
    circular buffer.  This routine does not access any MSRs.
    STATUS dbgStrConfig 
    (
    WIND_TCB * pTcb,	/@ pointer to the task's WIND_TCB @/
    BOOL  btsEnable,	/@ BTS,  TRUE to enable BTS, FALSE to disable @/
    BOOL  pebsEnable,	/@ PEBS, TRUE to enable PEBS, FALSE to disable @/
    BOOL  btsIntMode,	/@ BTS,  TRUE to interrupt, FALSE to circular mode @/
    BOOL  btsBufMode,	/@ BTS,  TRUE to buffer, FALSE to send it on Bus @/
    INT32 pebsEvent,	/@ PEBS, event @/
    INT32 pebsMetric,	/@ PEBS, metric in the event @/
    BOOL  pebsOs,	/@ PEBS, TRUE if OS mode, otherwise USR mode @/
    LL_INT * pPebsValue	/@ PEBS, (reset) value in the counter @/
    )

  - to start/stop the BTS/PEBS with parameters set by dbgStrConfig().
    This routine calls dbgStrBtsModeSet(), dbgStrBtsEnable(),
    dbgStrPebsModeSet(), dbgStrPebsEnable().
    STATUS dbgStrStart 
    (
    WIND_TCB * pTcb,	/@ pointer to the task's WIND_TCB @/
    )

  - stop the Debug Store (BTS + PEBS) mechanism.
    This routine stops the BTS/PEBS mechanism if the specified task 
    is the current task.  Otherwise, it set the disable flag in the 
    DS configuration parameter of the task.
    This routine calls dbgStrBtsEnable() and dbgStrPebsEnable().
    STATUS dbgStrStop 
    (
    WIND_TCB * pTcb	/@ pointer to the task's WIND_TCB @/
    )

  - to setup the BTS mode.
    This routine set up the BTS MSRs with the specified mode.
    STATUS dbgStrBtsModeSet 
    (
    BOOL intMode,	/@ TRUE to generate int, FALSE to circular mode @/
    BOOL bufMode	/@ TRUE to store BTMs, FALSE to send BTMs on Bus @/
    )

  - to enable the BTS.
    This routine enables or disables the BTS.
    BOOL dbgStrBtsEnable 
    (
    BOOL enable		/@ TRUE to enable, FALSE to disable the BTS @/
    )

  - to setup the PEBS mode.
    This routine set up the PEBS MSRs with the specified mode.
    STATUS dbgStrPebsModeSet 
    (
    INT32 event,	/@ event @/
    INT32 metric,	/@ metric in the event @/
    BOOL os,		/@ TRUE if OS mode, otherwise USR mode @/
    LL_INT * pValue	/@ (reset) value in the counter @/
    )

  - to enable the PEBS.
    This routine enables or disables the PEBS.
    BOOL dbgStrPebsEnable
    (
    BOOL enable		/@ TRUE to enable, FALSE to disable the PEBS @/
    )
.CE

The show routine is provided and linked in if INCLUDE_SHOW_ROUTINES is
defined in the BSP.  The show routine dbgStrShow() has two parameters.
The first parameter is a pointer to the TCB.  If that is NONE, the system
BTS/PEBS information is shown.  If that is NULL, the current task's 
BTS/PEBS information is shown.  The second parameter specifies type of
interest.  It can be 0 for general information, 1 for BTS, 2 for PEBS.

In PEBS, the filtering events and cascading counters are not supported.
Also the logical processor specific PEBS in the Hyper Threading is not
supported.

INTERNAL
The BTS/PEBS interrupt hook routine is not used in this release.
A routine to transfer the BTS/PEBS records to the host tools maybe
connected, so that the BTS records would be shown in the source code
or the PEBS records can be displayed in GUI. 

SEE ALSO:
sysDbgStr.c and dbgStrShow.c
.I "Intel Architecture Software Developer's Manual"
*/

/* includes */

#include "vxWorks.h"
#include "taskLib.h"
#include "taskHookLib.h"
#include "regs.h"
#include "intLib.h"
#include "string.h"
#include "memPartLib.h"
#include "arch/i86/pentiumLib.h"
#include "arch/i86/perMonLib.h"
#include "arch/i86/dbgStrLib.h"
#include "drv/intrCtl/loApic.h"


/* defines */


/* externals */

IMPORT CPUID	sysCpuId;		/* CPUID structure */
IMPORT WIND_TCB * taskIdCurrent;	/* current taskId */


/* globals */

BOOL		dbgStrSysMode = FALSE;	/* TRUE for system mode */
DS_CONFIG	dbgStrCfg     = {0};	/* system DS config */
DS_CONFIG *	dbgStrCurrent = NULL;	/* current DS config */


/* locals */


/* prototypes */

LOCAL void   dbgStrCreateHook	(WIND_TCB * pNewTcb);
LOCAL void   dbgStrSwitchHook	(WIND_TCB * pOldTcb, WIND_TCB * pNewTcb);
LOCAL void   dbgStrDeleteHook	(WIND_TCB * pTcb);
LOCAL STATUS dbgStrPebsFrontEnd	(INT32 metric, BOOL os);
LOCAL STATUS dbgStrPebsExec	(INT32 metric, BOOL os);
LOCAL STATUS dbgStrPebsReplay	(INT32 metric, BOOL os);


/*******************************************************************************
*
* dbgStrLibInit - initialize the Debug Store library dbgStrLib
*
* This routine initializes the Debug Store library dbgStrLib.
* If the first or second parameter is zero, the default buffer size
* BTS_NBYTES_DEF or PEBS_NBYTES_DEF is used.  It is initialized to the 
* system mode if the third parameter is TRUE.  Otherwise, task mode is used.
*
* RETURNS: OK if Debug Store feature is supported, ERROR otherwise.
*/

STATUS dbgStrLibInit
    (
    UINT32 btsNbytes,	/* BTS buffer size */
    UINT32 pebsNbytes,	/* PEBS buffer size */
    BOOL   sysMode	/* DS system mode */
    )
    {
    INT32 value[2];		/* MSR 64 bits value */

    /* check if the Debug Store feature is supported */

    if ((sysCpuId.featuresEdx & CPUID_DTS) == 0)
        return (ERROR);

    /* check if the BTS and PEBS are available */

    pentiumMsrGet (IA32_MISC_ENABLE, (LL_INT *)&value);

    if ((value[0] & MSC_BTS_UNAVAILABLE) == 0)
        dbgStrCfg.btsAvailable = TRUE;

    if ((value[0] & MSC_PEBS_UNAVAILABLE) == 0)
        dbgStrCfg.pebsAvailable = TRUE;

    if (!dbgStrCfg.btsAvailable && !dbgStrCfg.pebsAvailable)
	return (ERROR);

    /* remember the BTS and PEBS buffer size, and the DS mode */

    dbgStrCfg.btsNbytes  = (btsNbytes == 0) ? BTS_NBYTES_DEF : btsNbytes;
    dbgStrCfg.pebsNbytes = (pebsNbytes == 0) ? PEBS_NBYTES_DEF : pebsNbytes;

    if ((dbgStrCfg.btsNbytes < BTS_NBYTES_MIN) || 
	(dbgStrCfg.pebsNbytes < PEBS_NBYTES_MIN))
	return (ERROR);

    dbgStrSysMode = sysMode;

    /* allocate and initialize the DS header, BTS/PEBS buffer */

    if (dbgStrBufAlloc ((WIND_TCB *)NONE) != OK)
	return (ERROR);

    /* set up the task create/switch/delete hook routines */

    if (!sysMode)
	{
        taskCreateHookAdd ((FUNCPTR)dbgStrCreateHook);
        taskSwitchHookAdd ((FUNCPTR)dbgStrSwitchHook);
        taskDeleteHookAdd ((FUNCPTR)dbgStrDeleteHook);
	}

    return (OK);
    }

/*******************************************************************************
*
* dbgStrBufInit - initialize the Debug Store (BTS + PEBS) buffer 
*
* This routine initializes the Debug Store (BTS + PEBS) buffer.  The buffers
* are allocated if the pointers - that is 1st, 2nd and 5th params - are NULL.
*
* RETURNS: address of Debug Store Buffer Header, or NULL if failed.
*/

DS_BUF_HEADER * dbgStrBufInit 
    (
    DS_BUF_HEADER * pH,		/* Debug Store Buffer Header */
    BTS_REC * btsBufAddr,	/* BTS  buffer base */
    UINT32 btsMaxOffset,	/* BTS  absolute maximum */
    UINT32 btsIntOffset,	/* BTS  interrupt threshold */
    PEBS_REC * pebsBufAddr,	/* PEBS buffer base */
    UINT32 pebsMaxOffset,	/* PEBS absolute maximum */
    UINT32 pebsIntOffset	/* PEBS interrupt threshold */
    )
    {
    UINT32 nRec;
    UINT32 nByte;

    /* allocate aligned Debug Store Buffer Header if pHeader is zero */

    if (pH == NULL)
	{
	pH = (DS_BUF_HEADER *)KMEM_ALIGNED_ALLOC (
	     		      sizeof (DS_BUF_HEADER), _CACHE_ALIGN_SIZE);
	if (pH == NULL)
	    return (NULL);
	}

    /* setup the Debug Store buffer management area for BTS */

    pH->btsBase      = btsBufAddr;
    pH->btsMax       = ((UINT32)btsBufAddr + btsMaxOffset) + 1;
    pH->btsThreshold = (UINT32)btsBufAddr + btsIntOffset;

    /* allocate aligned BTS buffer if btsBufAddr is zero */

    if ((dbgStrCfg.btsAvailable) && (btsBufAddr == NULL))
	{
	nRec = btsMaxOffset / sizeof (BTS_REC);
	nByte = nRec * sizeof (BTS_REC);
	
	/* override btsBase */

	pH->btsBase = (BTS_REC *)KMEM_ALIGNED_ALLOC (nByte, 
						     _CACHE_ALIGN_SIZE);
	if (pH->btsBase == NULL)
	    {
	    KMEM_FREE ((char *)pH);
	    return (NULL);
	    }

	/* override btsMax */

	pH->btsMax = ((UINT32)pH->btsBase + nByte) + 1;

	/* override btsThreshold */

	nRec = btsIntOffset / sizeof (BTS_REC);
	pH->btsThreshold = nRec * sizeof (BTS_REC) + (UINT32)pH->btsBase;
	}

    /* setup the Debug Store buffer management area for PEBS */

    pH->pebsBase      = pebsBufAddr;
    pH->pebsMax       = ((UINT32)pebsBufAddr + pebsMaxOffset) + 1;
    pH->pebsThreshold = (UINT32)pebsBufAddr + pebsIntOffset;

    /* allocate aligned PEBS buffer if pebsBufAddr is zero */

    if ((dbgStrCfg.pebsAvailable) && (pebsBufAddr == NULL))
	{
	nRec = pebsMaxOffset / sizeof (PEBS_REC);
	nByte = nRec * sizeof (PEBS_REC);
	
	/* override pebsBase */

	pH->pebsBase = (PEBS_REC *)KMEM_ALIGNED_ALLOC (nByte, 
						       _CACHE_ALIGN_SIZE);
	if (pH->pebsBase == NULL)
	    {
	    KMEM_FREE ((char *)pH->btsBase);
	    KMEM_FREE ((char *)pH);
	    return (NULL);
	    }

	/* override pebsMax */

	pH->pebsMax = ((UINT32)pH->pebsBase + nByte) + 1;

	/* override pebsThreshold */

	nRec = pebsIntOffset / sizeof (PEBS_REC);
	pH->pebsThreshold = nRec * sizeof (PEBS_REC) + (UINT32)pH->pebsBase;
	}

    /* set the BTS and PEBS index */

    pH->btsIndex  = pH->btsBase;
    pH->pebsIndex = pH->pebsBase;

    /* clear the buffer to set access & dirty bit in PTE */

    bfill ((char *)pH->btsBase, pH->btsMax - (UINT32)pH->btsBase - 1, 0);
    bfill ((char *)pH->pebsBase, pH->pebsMax - (UINT32)pH->pebsBase - 1, 0);

    return (pH);
    }

/*******************************************************************************
*
* dbgStrBufAlloc - allocate the Debug Store buffers of the specified task
*
* This routine allocates the Debug Store buffers of the specified task
* The first and second parameter of dbgStrLibInit() is used for the BTS and 
* PEBS buffer size respectively.  If the pTcb is NONE, the allocated buffer 
* is set to the system DS config - dbgStrcfg.
*
* RETURNS: OK, or ERROR if there is no memory to alloc.
*/

STATUS dbgStrBufAlloc
    (
    WIND_TCB * pTcb	/* pointer to the task's WIND_TCB */
    )
    {
    X86_EXT * pExt = NULL;	/* X86 TCB extension */
    DS_CONFIG * pC = NULL;	/* DS config */
    DS_BUF_HEADER * pH;		/* DS header */
    UINT32 btsNbytesMax = 0;	/* BTS max bytes */
    UINT32 btsNbytesInt = 0;	/* BTS threshold bytes */
    UINT32 pebsNbytesMax = 0;	/* PEBS max bytes */
    UINT32 pebsNbytesInt = 0;	/* PEBS threshold bytes */
    UINT32 nRec;

    /* get the DS config */

    if (pTcb == (WIND_TCB *)NONE)
	pC = &dbgStrCfg;
    else if (pTcb == NULL)
	pExt = (X86_EXT *)taskIdCurrent->reserved2;
    else
	pExt = (X86_EXT *)pTcb->reserved2;

    if (pExt != NULL)
	pC = (DS_CONFIG *)pExt->reserved0;

    if (pC == NULL)
	return (ERROR);
    
    /* get (btsMax - btsBase) and (btsThreshold - btsBase) */

    nRec = pC->btsNbytes / sizeof (BTS_REC);
    btsNbytesMax = nRec * sizeof (BTS_REC);
    nRec = (pC->btsNbytes - BTS_NBYTES_OFF) / sizeof (BTS_REC);
    btsNbytesInt = nRec * sizeof (BTS_REC);

    /* get (pebsMax - pebsBase) and (pebsThreshold - pebsBase) */

    nRec = pC->pebsNbytes / sizeof (PEBS_REC);
    pebsNbytesMax = nRec * sizeof (PEBS_REC);
    nRec = (pC->pebsNbytes - PEBS_NBYTES_OFF) / sizeof (PEBS_REC);
    pebsNbytesInt = nRec * sizeof (PEBS_REC);

    /* allocate and initialize the DS header, BTS/PEBS buffer */

    pH = dbgStrBufInit (NULL, NULL, btsNbytesMax, btsNbytesInt, 
			NULL, pebsNbytesMax, pebsNbytesInt);

    if (pH == NULL)
	return (ERROR);

    pC->pH = pH;

    return (OK);
    }

/*******************************************************************************
*
* dbgStrBufFree - deallocate the Debug Store buffers of the specified task
*
* This routine deallocates the Debug Store buffers of the specified task
* If the pTcb is NONE, the allocated buffer for the system DS config 
* - dbgStrCfg is deallocated.
*
* RETURNS: OK, or ERROR if the specified task is NONE or has no buffer.
*/

STATUS dbgStrBufFree
    (
    WIND_TCB * pTcb	/* pointer to the task's WIND_TCB */
    )
    {
    X86_EXT * pExt = NULL;	/* X86 TCB extension */
    DS_CONFIG * pC = NULL;	/* DS config */
    DS_BUF_HEADER * pH;		/* DS header */

    /* get the DS config */

    if (pTcb == (WIND_TCB *)NONE)
	pC = &dbgStrCfg;
    else if (pTcb == NULL)
	pExt = (X86_EXT *)taskIdCurrent->reserved2;
    else
	pExt = (X86_EXT *)pTcb->reserved2;

    if (pExt != NULL)
	pC = (DS_CONFIG *)pExt->reserved0;

    if ((pC == NULL) || (pC->pH == NULL))
	return (ERROR);
    
    /* free the DS header and the DS config */

    pH = pC->pH;

    if (pH->btsBase != NULL)
        KMEM_FREE ((char *)pH->btsBase);

    if (pH->pebsBase != NULL)
        KMEM_FREE ((char *)pH->pebsBase);

    KMEM_FREE ((char *)pH);

    return (OK);
    }

/*******************************************************************************
*
* dbgStrConfig - configure the Debug Store (BTS + PEBS) mechanism
*
* This routine configures the Debug Store (BTS + PEBS) mechanism
* This routine stores the configuration parameters in the DS_CONFIG
* structure.  If the first parameter is NONE, the system DS_CONFIG 
* structure is used.  If it is NULL, the current task's one is used.
* If the BTS interrupt mode is FALSE, the BTS buffer is used as a
* circular buffer.  This routine does not access any MSRs.
*
* RETURNS: OK, or ERROR if there is no DS header
*/

STATUS dbgStrConfig 
    (
    WIND_TCB * pTcb,	/* pointer to deleted task's WIND_TCB */
    BOOL  btsEnable,	/* BTS,  TRUE to enable BTS, FALSE to disable */
    BOOL  pebsEnable,	/* PEBS, TRUE to enable PEBS, FALSE to disable */
    BOOL  btsIntMode,	/* BTS,  TRUE to raise int, FALSE to circular mode */
    BOOL  btsBufMode,	/* BTS,  TRUE to store BTMs, FALSE to send it on Bus */
    INT32 pebsEvent,	/* PEBS, event */
    INT32 pebsMetric,	/* PEBS, metric in the event */
    BOOL  pebsOs,	/* PEBS, TRUE if OS mode, otherwise USR mode */
    LL_INT * pPebsValue	/* PEBS, (reset) value in the counter */
    )
    {
    X86_EXT * pExt = NULL;	/* X86 TCB extension */
    DS_CONFIG * pC = NULL;	/* DS config */

    /* get the DS config */

    if (pTcb == (WIND_TCB *)NONE)
	pC = &dbgStrCfg;
    else if (pTcb == NULL)
	pExt = (X86_EXT *)taskIdCurrent->reserved2;
    else
	pExt = (X86_EXT *)pTcb->reserved2;

    if (pExt != NULL)
	pC = (DS_CONFIG *)pExt->reserved0;

    if (pC == NULL)
	return (ERROR);

    /* set the BTS/PEBS configuration parameters */

    pC->btsEnabled  = btsEnable;
    pC->pebsEnabled = pebsEnable;
    pC->btsIntMode  = btsIntMode;
    pC->btsBufMode  = btsBufMode;
    pC->pebsEvent   = pebsEvent;
    pC->pebsMetric  = pebsMetric;
    pC->pebsOs      = pebsOs;
    pC->pebsCtr     = (pPebsValue != NULL) ? *pPebsValue : PEBS_DEF_RESET;

    return (OK);
    }

/*******************************************************************************
*
* dbgStrStart - start or stop the Debug Store (BTS + PEBS) mechanism
* 
* This routine starts/stops the BTS/PEBS with parameters set by dbgStrConfig().
* The BTS/PEBS can be enabled or disabled depending on the parameters.
* This routine calls dbgStrBtsModeSet(), dbgStrBtsEnable(), 
* dbgStrPebsModeSet(), dbgStrPebsEnable().
*
* RETURNS: OK, or ERROR if there is no DS header
*/

STATUS dbgStrStart 
    (
    WIND_TCB * pTcb	/* pointer to the task's WIND_TCB */
    )
    {
    X86_EXT * pExt = NULL;	/* X86 TCB extension */
    DS_CONFIG * pC = NULL;	/* DS config */
    int value[2];		/* MSR 64 bits value */
    int oldLevel;		/* old int level */

    /* get the DS config */

    if (pTcb == (WIND_TCB *)NONE)
	pC = &dbgStrCfg;
    else if (pTcb == NULL)
	pExt = (X86_EXT *)taskIdCurrent->reserved2;
    else
	pExt = (X86_EXT *)pTcb->reserved2;

    if (pExt != NULL)
	pC = (DS_CONFIG *)pExt->reserved0;

    if ((pC == NULL) || (pC->pH == NULL))
	return (ERROR);
    
    /* stop the BTS/PEBS with interrupt locked */

    oldLevel = intLock ();		/* LOCK INTERRUPTS */
    dbgStrBtsEnable (FALSE);
    dbgStrPebsEnable (FALSE);
    intUnlock (oldLevel);		/* UNLOCK INTERRUPTS */

    /* set the linear address of the Debug Store buffer header */

    value[0] = (int)pC->pH;
    value[1] = 0;
    pentiumMsrSet (IA32_DS_AREA, (LL_INT *)&value);

    dbgStrCurrent = pC;			/* update */

    /* set the parameters to the BTS/PEBS MSRs */

    dbgStrBtsModeSet (pC->btsIntMode, pC->btsBufMode);
    dbgStrPebsModeSet (pC->pebsEvent, pC->pebsMetric, pC->pebsOs, 
    		       &pC->pebsCtr);
    oldLevel = intLock ();		/* LOCK INTERRUPTS */
    dbgStrBtsEnable (pC->btsEnabled);
    dbgStrPebsEnable (pC->pebsEnabled);
    intUnlock (oldLevel);		/* UNLOCK INTERRUPTS */

    return (OK);
    }

/*******************************************************************************
*
* dbgStrStop - stop the Debug Store (BTS + PEBS) mechanism
* 
* This routine stops the BTS/PEBS mechanism if the specified task is the
* current task.  Otherwise, it set the disable flag in the DS configuration
* parameter of the task.
* This routine calls dbgStrBtsEnable() and dbgStrPebsEnable().
*
* RETURNS: OK, or ERROR if there is no DS header
*/

STATUS dbgStrStop 
    (
    WIND_TCB * pTcb	/* pointer to the task's WIND_TCB */
    )
    {
    X86_EXT * pExt = NULL;	/* X86 TCB extension */
    DS_CONFIG * pC = NULL;	/* DS config */
    int oldLevel;		/* old int level */

    /* get the DS config */

    if (pTcb == (WIND_TCB *)NONE)
	pC = &dbgStrCfg;
    else if (pTcb == NULL)
	pExt = (X86_EXT *)taskIdCurrent->reserved2;
    else
	pExt = (X86_EXT *)pTcb->reserved2;

    if (pExt != NULL)
	pC = (DS_CONFIG *)pExt->reserved0;

    if ((pC == NULL) || (pC->pH == NULL))
	return (ERROR);
    
    /* set the configuration parameter FALSE(disable) */

    pC->btsEnabled  = FALSE;
    pC->pebsEnabled = FALSE;

    /* stop the BTS/PEBS with interrupt locked */

    if ((pTcb == (WIND_TCB *)NONE) || (pTcb == NULL))
	{
        oldLevel = intLock ();		/* LOCK INTERRUPTS */
        dbgStrBtsEnable (FALSE);
        dbgStrPebsEnable (FALSE);
        intUnlock (oldLevel);		/* UNLOCK INTERRUPTS */
	}

    return (OK);
    }

/*******************************************************************************
*
* dbgStrBtsModeSet - set the BTS (Branch Trace Store) mode
*
* This routine sets the BTS (Branch Trace Store) mode.
*
* RETURNS: OK, or ERROR if the BTS is not initialized.
*/

STATUS dbgStrBtsModeSet 
    (
    BOOL intMode,	/* TRUE to generate int, FALSE to circular mode */
    BOOL bufMode	/* TRUE to store BTMs, FALSE to send BTMs on Bus */
    )
    {
    int value[2];	/* MSR 64 bits value */

    /* check if the BTS initialization succeeded */

    if (!dbgStrCfg.btsAvailable)
	return (ERROR);

    /* set the BT and BTINT bit in IA32_DEBUGCTL */

    pentiumMsrGet (IA32_DEBUGCTL, (LL_INT *)&value);
    value[0] &= ~(DBG_P7_BTS | DBG_P7_BTINT);
    if (bufMode)
	value[0] |= DBG_P7_BTS;
    if (intMode)
	value[0] |= DBG_P7_BTINT;
    pentiumMsrSet (IA32_DEBUGCTL, (LL_INT *)&value);

    return (OK);
    }

/*******************************************************************************
*
* dbgStrBtsEnable - enables BTS (Branch Trace Store) mechanism
*
* This routine enables BTS (Branch Trace Store) mechanism.
*
* RETURNS: TRUE, or FALSE if the BTS was not enabled
*/

BOOL dbgStrBtsEnable 
    (
    BOOL enable		/* TRUE to enable, FALSE to disable the BTS */
    )
    {
    int value[2];	/* MSR 64 bits value */
    int oldValue;	/* old value */

    /* check if the BTS initialization succeeded */

    if (!dbgStrCfg.btsAvailable)
	return (FALSE);

    /* get the IA32_DEBUGCTL value */

    pentiumMsrGet (IA32_DEBUGCTL, (LL_INT *)&value);
    oldValue = value[0];

    /* enable or disable the BTM */

    if (enable)
        value[0] |= DBG_P7_TR;
    else
        value[0] &= ~DBG_P7_TR;

    /* set the IA32_DEBUGCTL value */

    pentiumMsrSet (IA32_DEBUGCTL, (LL_INT *)&value);

    return ((oldValue & DBG_P7_TR) ? TRUE : FALSE);
    }

/*******************************************************************************
*
* dbgStrPebsModeSet - set the PEBS (Precise Event Based Sampling) mode
*
* This routine sets the PEBS (Precise Event Based Sampling) mode.
*
* RETURNS: OK, or ERROR if the PEBS is not initialized.
*/

STATUS dbgStrPebsModeSet 
    (
    INT32 event,	/* event */
    INT32 metric,	/* metric in the event */
    BOOL os,		/* TRUE if OS mode, otherwise USR mode */
    LL_INT * pValue	/* (reset) value in the counter */
    )
    {
    STATUS status = ERROR;	/* return value */

    /* check if the PEBS initialization succeeded */

    if (!dbgStrCfg.pebsAvailable)
	return (ERROR);

    /* set up the PEBS counter */

    dbgStrCurrent->pH->pebsCtr = *pValue;
    pentiumMsrSet (MSR_IQ_COUNTER4, pValue);

    /* set up ESCR/CCCR/PEBS_ENABLE MSRs for the PEBS event */

    switch (event)
	{
	case PEBS_FRONT_END:
	    status = dbgStrPebsFrontEnd (metric, os);
	    break;

	case PEBS_EXECUTION:
	    status = dbgStrPebsExec (metric, os);
	    break;

	case PEBS_REPLAY:
	    status = dbgStrPebsReplay (metric, os);
	    break;

	default:
	    break;
	}

    return (status);
    }

/*******************************************************************************
*
* dbgStrPebsEnable - enables PEBS (Precise Event Based Sampling) mechanism
*
* This routine enables PEBS (Precise Event Based Sampling) mechanism.
*
* RETURNS: TRUE, or FALSE if the PEBS was not enabled
*/

BOOL dbgStrPebsEnable
    (
    BOOL enable		/* TRUE to enable, FALSE to disable the PEBS */
    )
    {
    int value[2];	/* MSR 64 bits value */
    int oldValue;	/* old value */

    /* check if the PEBS initialization succeeded */

    if (!dbgStrCfg.pebsAvailable)
	return (FALSE);

    /* get the MSR_IQ_CCCR4 value */

    pentiumMsrGet (MSR_IQ_CCCR4, (LL_INT *)&value);
    oldValue = value[0];

    /* enable or disable the PEBS */

    if (enable)
        value[0] |= CCCR_ENABLE;
    else
        value[0] &= ~CCCR_ENABLE;

    /* set the MSR_IQ_CCCR4 value */

    pentiumMsrSet (MSR_IQ_CCCR4, (LL_INT *)&value);

    return ((oldValue & CCCR_ENABLE) ? TRUE : FALSE);
    }

/*******************************************************************************
*
* dbgStrCreateHook - create hook routine for the Debug Store
*
* This routine is the create hook routine for the Debug Store 
*
* RETURNS: N/A
*/

LOCAL void dbgStrCreateHook
    (
    WIND_TCB * pNewTcb		/* pointer to new task's TCB */
    )
    {
    X86_EXT * pExt;		/* X86 TCB extension */
    DS_CONFIG * pC;		/* DS config */

    /* allocate the X86 TCB extension if it is not yet allocated */

    if ((pExt = (X86_EXT *)pNewTcb->reserved2) == 0)
        {
        pExt = (X86_EXT *) taskStackAllot ((int) pNewTcb, sizeof (X86_EXT));
        if (pExt == NULL)
	    return;
    
	bzero ((char *) pExt, sizeof (X86_EXT));
        pNewTcb->reserved2 = (int)pExt;
        }

    /* allocate the DS configuration, and save it in the TCB */

    pC = (DS_CONFIG *) KMEM_ALIGNED_ALLOC (sizeof (DS_CONFIG), 
					   _CACHE_ALIGN_SIZE);
    if (pC == NULL)
	return;
    
    pExt->reserved0 = (UINT32)pC;

    /* inherit the system DS configuration */

    bcopy ((char *)&dbgStrCfg, (char *)pC, sizeof (DS_CONFIG));

    /* allocate and initialize the DS header, BTS/PEBS buffer */

    if (dbgStrBufAlloc (pNewTcb) != OK)
	return;
    }

/*******************************************************************************
*
* dbgStrSwitchHook - switch hook routine for the Debug Store
*
* This routine is the switch hook routine for the Debug Store 
*
* RETURNS: N/A
*/

LOCAL void dbgStrSwitchHook
    (
    WIND_TCB * pOldTcb,	/* pointer to old task's WIND_TCB */
    WIND_TCB * pNewTcb	/* pointer to new task's WIND_TCB */
    )
    {

    /* start/stop the BTS/PEBS with the parameters set by dbgStrConfig() */

    dbgStrStart (pNewTcb);
    }

/*******************************************************************************
*
* dbgStrDeleteHook - delete hook routine for the Debug Store
*
* This routine is the delete hook routine for the Debug Store 
*
* RETURNS: N/A
*/

LOCAL void dbgStrDeleteHook
    (
    WIND_TCB * pTcb	/* pointer to deleted task's WIND_TCB */
    )
    {
    X86_EXT * pExt = NULL;	/* X86 TCB extension */
    DS_CONFIG * pC = NULL;	/* DS config */

    /* if it is current task, stop DS. Otherwise let the switch hook stop */

    if (pTcb == taskIdCurrent)
	{
	dbgStrBtsEnable (FALSE);
	dbgStrPebsEnable (FALSE);
	}

    /* delete the DS header */

    dbgStrBufFree (pTcb);

    /* delete the DS config */

    pExt = (X86_EXT *)pTcb->reserved2;
    if (pExt != NULL)
	pC = (DS_CONFIG *)pExt->reserved0;

    if (pC != NULL)
        KMEM_FREE ((char *)pC);
    }

/*******************************************************************************
*
* dbgStrPebsFrontEnd - set up the PEBS for the Front End event
*
* This routine sets up the PEBS for the Front End event.
*
* RETURNS: OK, or ERROR if the specified metric is not supported.
*/

LOCAL STATUS dbgStrPebsFrontEnd 
    (
    INT32 metric,	/* metric in the event */
    BOOL os		/* TRUE if OS mode, otherwise USR mode */
    )
    {
    int value[2];	/* MSR 64 bits value */

    /* validation check for the metric */

    switch (metric)
	{
	case PEBS_MEMORY_LOADS:

	    value[0] = ESCR_MEMORY_LOADS | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_RAT_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_MEMORY_STORES:

	    value[0] = ESCR_MEMORY_STORES | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_RAT_ESCR0, (LL_INT *)&value);

	    break;

	default:
	    return (ERROR);
	}

    value[0] = ESCR_FRONT_END | (os ? ESCR_OS : ESCR_USR);
    value[1] = 0;
    pentiumMsrSet (MSR_CRU_ESCR2, (LL_INT *)&value);

    value[0] = CCCR_FRONT_END;
    value[1] = 0;
    pentiumMsrSet (MSR_IQ_CCCR4, (LL_INT *)&value);

    value[0] = DS_BIT_25;
    value[1] = 0;
    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

    return (OK);
    }

/*******************************************************************************
*
* dbgStrPebsExec - set up the PEBS for the Execution event
*
* This routine sets up the PEBS for the Execution event.
*
* RETURNS: OK, or ERROR if the specified metric is not supported.
*/

LOCAL STATUS dbgStrPebsExec 
    (
    INT32 metric,	/* metric in the event */
    BOOL os		/* TRUE if OS mode, otherwise USR mode */
    )
    {
    int value[2];	/* MSR 64 bits value */

    /* validation check for the metric */

    switch (metric)
	{
	case PEBS_PACKED_SP:

	    value[0] = ESCR_PACKED_SP | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_FIRM_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_PACKED_DP:

	    value[0] = ESCR_PACKED_DP | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_FIRM_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_SCALAR_SP:

	    value[0] = ESCR_SCALAR_SP | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_FIRM_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_SCALAR_DP:

	    value[0] = ESCR_SCALAR_DP | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_FIRM_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_128BIT_MMX:

	    value[0] = ESCR_128BIT_MMX | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_FIRM_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_64BIT_MMX:

	    value[0] = ESCR_64BIT_MMX | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_FIRM_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_X87_FP:

	    value[0] = ESCR_X87_FP | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_FIRM_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_X87_SIMD_MOVES:

	    value[0] = ESCR_X87_SIMD_MOVES | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_FIRM_ESCR0, (LL_INT *)&value);

	    break;

	default:
	    return (ERROR);
	}

    value[0] = ESCR_EXECUTION | (os ? ESCR_OS : ESCR_USR);
    value[1] = 0;
    pentiumMsrSet (MSR_CRU_ESCR2, (LL_INT *)&value);

    value[0] = CCCR_EXECUTION;
    value[1] = 0;
    pentiumMsrSet (MSR_IQ_CCCR4, (LL_INT *)&value);

    value[0] = DS_BIT_25;
    value[1] = 0;
    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

    return (OK);
    }

/*******************************************************************************
*
* dbgStrPebsReplay - set up the PEBS for the Replay event
*
* This routine sets up the PEBS for the Replay event.
*
* RETURNS: OK, or ERROR if the specified metric is not supported.
*/

LOCAL STATUS dbgStrPebsReplay 
    (
    INT32 metric,	/* metric in the event */
    BOOL os		/* TRUE if OS mode, otherwise USR mode */
    )
    {
    int value[2];	/* MSR 64 bits value */

    /* validation check for the metric */

    switch (metric)
	{
	case PEBS_1STL_CACHE_LOAD_MISS:

	    value[0] = (DS_BIT_0 | DS_BIT_24 | DS_BIT_25);
    	    value[1] = 0;
    	    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

	    value[0] = (DS_BIT_0);
    	    value[1] = 0;
    	    pentiumMsrSet (MSR_PEBS_MATRIX_VERT, (LL_INT *)&value);

	    break;

	case PEBS_2NDL_CACHE_LOAD_MISS:

	    value[0] = (DS_BIT_1 | DS_BIT_24 | DS_BIT_25);
    	    value[1] = 0;
    	    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

	    value[0] = (DS_BIT_0);
    	    value[1] = 0;
    	    pentiumMsrSet (MSR_PEBS_MATRIX_VERT, (LL_INT *)&value);

	    break;

	case PEBS_DTLB_LOAD_MISS:

	    value[0] = (DS_BIT_2 | DS_BIT_24 | DS_BIT_25);
    	    value[1] = 0;
    	    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

	    value[0] = (DS_BIT_0);
    	    value[1] = 0;
    	    pentiumMsrSet (MSR_PEBS_MATRIX_VERT, (LL_INT *)&value);

	    break;

	case PEBS_DTLB_STORE_MISS:

	    value[0] = (DS_BIT_2 | DS_BIT_24 | DS_BIT_25);
    	    value[1] = 0;
    	    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

	    value[0] = (DS_BIT_1);
    	    value[1] = 0;
    	    pentiumMsrSet (MSR_PEBS_MATRIX_VERT, (LL_INT *)&value);

	    break;

	case PEBS_DTLB_ALL_MISS:

	    value[0] = (DS_BIT_2 | DS_BIT_24 | DS_BIT_25);
    	    value[1] = 0;
    	    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

	    value[0] = (DS_BIT_0 | DS_BIT_1);
    	    value[1] = 0;
    	    pentiumMsrSet (MSR_PEBS_MATRIX_VERT, (LL_INT *)&value);

	    break;

	case PEBS_MOB_LOAD_REPLAY:

	    value[0] = (DS_BIT_9 | DS_BIT_24 | DS_BIT_25);
    	    value[1] = 0;
    	    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

	    value[0] = (DS_BIT_0);
    	    value[1] = 0;
    	    pentiumMsrSet (MSR_PEBS_MATRIX_VERT, (LL_INT *)&value);

	    value[0] = ESCR_MOB_LOAD_REPLAY | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_MOB_ESCR0, (LL_INT *)&value);

	    break;

	case PEBS_SPLIT_LOAD:

	    value[0] = (DS_BIT_10 | DS_BIT_24 | DS_BIT_25);
    	    value[1] = 0;
    	    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

	    value[0] = (DS_BIT_0);
    	    value[1] = 0;
    	    pentiumMsrSet (MSR_PEBS_MATRIX_VERT, (LL_INT *)&value);

	    value[0] = ESCR_SPLIT_LOAD | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_SAAT_ESCR1, (LL_INT *)&value);

	    break;

	case PEBS_SPLIT_STORE:

	    value[0] = (DS_BIT_10 | DS_BIT_24 | DS_BIT_25);
    	    value[1] = 0;
    	    pentiumMsrSet (IA32_PEBS_ENABLE, (LL_INT *)&value);

	    value[0] = (DS_BIT_1);
    	    value[1] = 0;
    	    pentiumMsrSet (MSR_PEBS_MATRIX_VERT, (LL_INT *)&value);

	    value[0] = ESCR_SPLIT_STORE | (os ? ESCR_OS : ESCR_USR);
	    value[1] = 0;
	    pentiumMsrSet (MSR_SAAT_ESCR0, (LL_INT *)&value);

	    break;

	default:
	    return (ERROR);
	}

    value[0] = ESCR_REPLAY | (os ? ESCR_OS : ESCR_USR);
    value[1] = 0;
    pentiumMsrSet (MSR_CRU_ESCR2, (LL_INT *)&value);

    value[0] = CCCR_REPLAY;
    value[1] = 0;
    pentiumMsrSet (MSR_IQ_CCCR4, (LL_INT *)&value);

    return (OK);
    }

