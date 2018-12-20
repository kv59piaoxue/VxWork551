/* vxmIfLib.c - interface library to VxM  */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,28jul00,ish  3Soft changes for ColdFire
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
------------
This is the interface library for VxE and VxM.
*/

#include "vxWorks.h"
#include "taskLib.h"
#include "types.h"
#include "private/vxmIfLibP2.h"

/* locals */

VXM_IF_OPS		vxmIfOps;
VXM_IF_OPS *		pVxmIfOps = &vxmIfOps;
VXM_IF_ANCHOR *		pVxmIfAnchor;
BOOL			vxmIfInitialized = FALSE;

/* XXX string. for dbg purposes */
IMPORT int 	intCnt;
IMPORT BOOL 	kernelState; 

BOOL vxmIfBrkIgnore (int tid);

/******************************************************************************
*
* vxmIfInit - initialize the interface
*/  
STATUS vxmIfInit 
    (
    VXM_IF_ANCHOR *	pAnchor
    )

    {
    FUNCPTR	getFunc;

    pVxmIfAnchor = pAnchor;

    if (pVxmIfAnchor->ifMagic != VXM_IF_MAGIC)
	return (ERROR);

    /* the the interface access function from the anchor */
    getFunc = pVxmIfAnchor->ifGetFunc;

    /* initialize the interface operations using the access function */
    vxmIfOps.vxmTblGet	   = getFunc;
    vxmIfOps.vxmIntVecGet  = (FUNCPTR) (*getFunc) (VXM_IF_INT_VEC_GET_FUNC);
    vxmIfOps.vxmIntVecSet  = (FUNCPTR) (*getFunc) (VXM_IF_INT_VEC_SET_FUNC);
    vxmIfOps.vxmBufRead	   = (FUNCPTR) (*getFunc) (VXM_IF_BUF_RD_FUNC);
    vxmIfOps.vxmBufWrite   = (FUNCPTR) (*getFunc) (VXM_IF_BUF_WRT_FUNC);
    vxmIfOps.vxmWrtBufFlush =(FUNCPTR) (*getFunc) (VXM_IF_WRTBUF_FLUSH_FUNC);
    vxmIfOps.vxmHostQuery  = (FUNCPTR) (*getFunc) (VXM_IF_QUERY_FUNC);
    vxmIfOps.vxmClbkAdd    = (FUNCPTR) (*getFunc) (VXM_IF_CALLBACK_ADD_FUNC);
    vxmIfOps.vxmClbkReady  = (FUNCPTR) (*getFunc) (VXM_IF_CALLBACK_STATE_FUNC);
    vxmIfOps.vxmClbkQuery  = (FUNCPTR) (*getFunc) (VXM_IF_CALLBACK_QUERY_FUNC);
    vxmIfOps.vxmEntHookSet = (FUNCPTR) (*getFunc) (VXM_IF_ENTER_HOOK_SET_FUNC);
    vxmIfOps.vxmExitHookSet= (FUNCPTR) (*getFunc) (VXM_IF_EXIT_HOOK_SET_FUNC);
    vxmIfOps.vxmIntLvlSet  = (FUNCPTR) (*getFunc) (VXM_IF_INT_LVL_SET_FUNC);
    vxmIfOps.vxmExitFunc   = (FUNCPTR) (*getFunc) (VXM_IF_EXIT_FUNC);
    vxmIfOps.vxmIntAckSet  = (FUNCPTR) (*getFunc) (VXM_IF_INT_ACK_SET_FUNC);
    vxmIfOps.vxmTtyNum     = (FUNCPTR) (*getFunc) (VXM_IF_TTY_NUM_FUNC);
    vxmIfOps.vxmBreakQuery = (FUNCPTR) (*getFunc) (VXM_IF_BREAK_QUERY_FUNC);

#if CPU_FAMILY==I960
    vxmIfOps.vxmFaultVecSet  = (FUNCPTR) (*getFunc) (VXM_IF_FLT_VEC_SET_FUNC);
#endif /* CPU_FAMILY==I960 */
    /* install internal debugger callback */
    (* pVxmIfOps->vxmClbkAdd) (VXM_IF_CALLBACK_DBG, vxmIfBrkIgnore);

    vxmIfInitialized = TRUE;
    return (OK);
    }

/******************************************************************************
*
* vxmIfInstalled - check for the presence of the ROM monitor.
*/  
BOOL vxmIfInstalled ()
    {
    if (pVxmIfAnchor->ifMagic != VXM_IF_MAGIC)
	return (FALSE);
    return (TRUE);
    }

/******************************************************************************
*
* vxmIfEnterHookSet - set a hook called upon entrance to vxMon.
*/  
FUNCPTR vxmIfEnterHookSet 
    (
    FUNCPTR 	hookFunc,
    UINT32	hookArg
    )

    {
    if (!vxmIfInitialized)
	return ((FUNCPTR)NULL);
    return ((FUNCPTR)(*pVxmIfOps->vxmEntHookSet) (hookFunc, hookArg)); 
    }

/******************************************************************************
*
* vxmIfExitHookSet - set a hook called upon exit from vxMon.
*/  
FUNCPTR vxmIfExitHookSet 
    (
    FUNCPTR 	hookFunc,
    UINT32	hookArg
    )

    {
    if (!vxmIfInitialized)
	return ((FUNCPTR)NULL);
    return ((FUNCPTR)(*pVxmIfOps->vxmExitHookSet) (hookFunc, hookArg)); 
    }

/******************************************************************************
*
* vxmIfExit - Called by uWorks upon exit.
*
* If uWorks is forced to abort, this function can be used to exit 
* gracefully via vxMon.
*/  
FUNCPTR vxmIfExit
    (
    UINT32	code
    )

    {
    if (!vxmIfInitialized)
	return ((FUNCPTR)NULL);
    return ((FUNCPTR)(*pVxmIfOps->vxmExitFunc) (code)); 
    }

/******************************************************************************
*
* vxmIfIntLvlSet - set interrupt level to use when in monitor.
*/  
UINT32 vxmIfIntLvlSet 
    (
    UINT32	level
    )

    {
    if (!vxmIfInitialized)
	return ((UINT32)NULL);
    return ((* pVxmIfOps->vxmIntLvlSet) (level));
    }

/******************************************************************************
*
* vxmIfVecGet - get an interrupt vector via the ROM monitor.
*/  
FUNCPTR vxmIfVecGet 
    (
    FUNCPTR * 	vec
    )

    {
    if (!vxmIfInitialized)
	return ((FUNCPTR)NULL);
    return ((FUNCPTR)(* pVxmIfOps->vxmIntVecGet) (vec)); 
    }

/******************************************************************************
*
* vxmIfVecSet - set an interrupt vector via the ROM monitor.
*/  
STATUS vxmIfVecSet 
    (
    FUNCPTR * 	vec,
    FUNCPTR	func
    )

    {
    if (!vxmIfInitialized)
	return ((STATUS)NULL);
    return ((*pVxmIfOps->vxmIntVecSet) (vec, func)); 
    }
/******************************************************************************
*
* vxmIfIntAckSet - update interrupt acknowledge table
*/  
STATUS vxmIfIntAckSet 
    (
    UINT * 	ackTable
    )
    {
    if (!vxmIfInitialized)
	return (ERROR);
    return ((*pVxmIfOps->vxmIntAckSet) (ackTable)); 
    }
/******************************************************************************
*
* vxmIfTtyNum - return tty channel used by VxMon
*/  
int vxmIfTtyNum ()
    {
    if (!vxmIfInitialized)
	return (ERROR);
    return ((*pVxmIfOps->vxmTtyNum) ()); 
    }

/******************************************************************************
*
* vxmIfHostQuery - query the host via VxM for input data.
*/   
BOOL vxmIfHostQuery ()
    {
    if (!vxmIfInitialized)
	return ((BOOL)NULL);
    return (* pVxmIfOps->vxmHostQuery) ();
    }

/******************************************************************************
*
* vxmIfBreakQuery - query the host via VxM for ctrl-c support
*/   
STATUS vxmIfBreakQuery 
    (
    FUNCPTR breakFunc
    )
    {
    if (!vxmIfInitialized)
	return ((BOOL)NULL);
    return (* pVxmIfOps->vxmBreakQuery) (breakFunc);
    }

/******************************************************************************
*
* vxmIfWrtBufFlush - flush the ROM monitor write buffer.
*/  
void vxmIfWrtBufFlush ()

    {
    if (!vxmIfInitialized)
	return;
    (* pVxmIfOps->vxmWrtBufFlush) ();
    }

/******************************************************************************
*
* vxmIfBufRead - read a buffer of data from the ROM monitor.
*/  
int vxmIfBufRead
    (
    char *	pBuf,
    int		nBytes
    )

    {
    if (!vxmIfInitialized)
	return (0);
    return ((* pVxmIfOps->vxmBufRead) (pBuf, nBytes));
    }

/******************************************************************************
*
* vxmIfBufWrite - write a buffer of data to the ROM monitor.
*/  
int vxmIfBufWrite
    (
    char *	pBuf,
    int		nBytes
    )

    {
    if (!vxmIfInitialized)
	return (0);
    return ((* pVxmIfOps->vxmBufWrite) (pBuf, nBytes));
    }

/******************************************************************************
*
* vxmIfCallbackAdd - add a callback to the interface.
*/  
STATUS vxmIfCallbackAdd
    (
    int		funcNo,		/* callback function number */
    FUNCPTR 	func,		/* callback function */
    UINT32	arg,		/* required argument to pass */ 
    UINT32	maxargs,	/* max. number of optional args */
    UINT32	state		/* initial state of callback */
    )

    {
    if (!vxmIfInitialized)
	return ((STATUS)NULL);
    return ((* pVxmIfOps->vxmClbkAdd) (funcNo, func, arg, maxargs, state));
    }

/******************************************************************************
*
* vxmIfCallbackReady - set the state of the given callback to ready.
*
*/  
STATUS vxmIfCallbackReady 
    (
    int	funcNo			/* number of callback */
    )

    {
    if (!vxmIfInitialized)
	return ((STATUS)NULL);
    return ((* pVxmIfOps->vxmClbkReady) (funcNo));
    }

/******************************************************************************
*
* vxmIfCallbackQuery - query the host for action on the given callback.
* 
*/  
STATUS vxmIfCallbackQuery
    (
    int	funcNo			/* callback to query. */
    )

    {
    if (!vxmIfInitialized)
	return ((STATUS)NULL);
    return ((* pVxmIfOps->vxmClbkQuery) (funcNo));
    }

/******************************************************************************
*
* vxmIfBrkIgnore - callback from vxMon to see if breakpoint should be ignored.
*
* Function installed in callback table but only called by the debugger in 
* vxMon to find out if a breakpoint should be ignored or taken.
*
* Returns: TRUE if the breakpoint is to be ignored.
*/  
BOOL vxmIfBrkIgnore 
    (
    int	tid			/* task id */
    )

    {
    if (((intCnt > 0)) ||
	((kernelState == TRUE)) ||
	(((int)taskIdCurrent != tid)) ||
	(((WIND_TCB *)tid)->options & VX_UNBREAKABLE) /* ||
	((((WIND_TCB *)tid)->lockCnt != 0) && (dbgLockUnbreakable)) ||
	((((WIND_TCB *)tid)->safeCnt != 0) && (dbgSafeUnbreakable))
	XXX string where are dbgLockUn and dbgSafeUn set in vxWorks ? */)
	{
	return (TRUE);
	}
    else
	return (FALSE);
    }

#if CPU_FAMILY==I960
/******************************************************************************
*
* vxmIfFaultVecSet - set a vector in the fault table via ROM monitor.
*
* This routine sets a vector in the fault table.  The <vector> parameter is
* the address of the fault handler to attach to <faultNo>, a number in the
* fault table.  The <type> parameter specifies whether the vector should be
* installed in the fault table as a local-call entry or as a system-call
* entry.  (See Chapter 7, "Fault Handling" in the 80960CA manual).
*
* NOTE
* If the low-order 2 bits of the returned vector are 10b (0x02), the vector
* was taken from 'sysProcTable' and should be reinstalled in 'faultTable'
* with <type> set to SYS_SYSTEM_CALL_FAULT.
*
* RETURNS: The previous vector for the specified <faultNo> as UINT32.
*
* SEE ALSO:
* .I "Intel 80960CA User's Manual"
*/  

UINT32 vxmIfFaultVecSet
    (
    INSTR	*vector,	/* fault handler address  */
    UINT32	faultNo,	/* fault number to attach */
    UINT32	type		/* type of fault call     */
    )

    {
    if (!vxmIfInitialized)
	return ((UINT32)NULL);
    return ((vxmIfOps.vxmFaultVecSet) (vector, faultNo, type)); 
    }

#endif /* CPU_FAMILY==I960 */
