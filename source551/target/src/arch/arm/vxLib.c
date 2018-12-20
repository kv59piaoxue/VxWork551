/* vxLib.c - miscellaneous support routines */

/* Copyright 1996-1999 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01m,25sep01,rec  archv5 support
01l,23jul01,scm  change XScale name to conform to coding standards...
01k,04may01,scm  add STRONGARM support...
01j,11dec00,scm  replace references to ARMSA2 with XScale
01i,13nov00,scm  add SA2 support...
01h,20jan99,cdp  removed support for old ARM libraries.
01g,04sep98,cdp  make Thumb support dependent on ARM_THUMB.
01f,27oct97,kkk  took out "***EOF***" line from end of file.
01e,24oct97,dat  added _func_vxMemProbeHook, SPR 8658
01d,23sep97,cdp  fix comment in header of thumbSymTblAdd.
01c,26mar97,cdp  added Thumb (ARM7TDMI_T) support;
		 added 2 byte support for ARM710A to vxMemProbe.
01b,20feb97,cdp  fixed comments.
01a,11jul96,cdp  written.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines.

SEE ALSO: vxALib
*/

#include "vxWorks.h"
#include "vxLib.h"
#include "intLib.h"
#include "ioLib.h"
#include "iv.h"
#include "esf.h"
#include "private/taskLibP.h"
#include "stdarg.h"
#include "excLib.h"
#if (ARM_THUMB)
#include "symLib.h"
#include "symbol.h"
#endif

IMPORT STATUS  vxMemProbeSup (int length, char * src, char * dest);
STATUS (* _func_vxMemProbeHook)
	    (void *,int,int, void *) = NULL;    /* hook for BSP vxMemProbe */


/******************************************************************************
*
* vxMemProbeTrap - trap handler for vxMemProbe exception
*
* This routine is called from the exception veneer if vxMemProbeSup
* generates an exception. By default, vxMemProbeSup returns OK.
* This code changes the R3 value to ERROR (within the vxMemProbeSup
* routine).
*/

static int vxMemProbeTrap
    (
    ESF *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to registers */
    )
    {
    pRegs->r[3] = ERROR;	/* indicate access failed */

#if (ARM_THUMB)
    /*
     * step over faulting instruction - must not simply increment the
     * PC because the CPU could be in ARM or THUMB state.
     */
    if (pRegs->cpsr & T_BIT)
	pRegs->pc = (INSTR *)((UINT32)pRegs->pc + 2);
    else
	pRegs->pc = (INSTR *)((UINT32)pRegs->pc + 4);
#else
    ++(pRegs->pc);		/* step over failing instruction */
#endif
    return 0;
    }

/******************************************************************************
*
* vxMemArchProbe - architecture specific probe routine (PPC)
*
* This is the routine implementing the architecture specific part of the
* vxMemProbe routine.  It traps the relevant
* exceptions while accessing the specified address.
*
* INTERNAL
* This routine functions by setting the data abort exception vector
* to vxMemProbeTrap and then trying to read/write the specified byte(s).
* If an exception occurs, vxMemProbe will return ERROR.  Note that this
* routine saves and restores the exception vectors that were there prior
* to this call. The entire procedure is done with interrupts locked out.
*
* RETURNS: OK or ERROR if an exception occurred during access.
*/
 
STATUS vxMemArchProbe
    (
    void* adrs,         /* address to be probed */
    int mode,           /* VX_READ or VX_WRITE */
    int length,         /* 1, 2, 4, 8, or 16 */
    void* pVal          /* where to return value, */
			/* or ptr to value to be written */
    )
    {
    STATUS status;
    int oldLevel;
    FUNCPTR oldVec1, oldVec2;

    switch (length)
        {
        case (1):
	    break;

        case (2):
#if ((CPU==ARMARCH4) || (CPU==ARMARCH4_T) || (CPU == STRONGARM) || \
  (CPU == XSCALE) || (CPU==ARMARCH5) || (CPU==ARMARCH5_T))
            if (((int) adrs & 0x1) || ((int) pVal & 0x1))
                return ERROR;
	    /*
	     * ARM710A can do unaligned accesses because it uses
	     * byte instructions. We used to prevent 2 byte accesses on
	     * ARM710A but it turns out that windsh uses them.
	     */
#endif
            break;

        case (4):
            if (((int) adrs & 0x3) || ((int) pVal & 0x3))
                return ERROR;
            break;

        default:
            return ERROR;
        }

    oldLevel = intLock ();			/* disable interrupts */


    /* install an exception handler */

    oldVec1 = excVecGet ((FUNCPTR *) EXC_OFF_DATA);
    oldVec2 = excVecGet ((FUNCPTR *) EXC_OFF_UNDEF);
    excVecSet ((FUNCPTR *) EXC_OFF_DATA, vxMemProbeTrap); 
    excVecSet ((FUNCPTR *) EXC_OFF_UNDEF, vxMemProbeTrap); 


    /* do probe */

    if (mode == VX_READ)
	status = vxMemProbeSup (length, adrs, pVal);
    else
	status = vxMemProbeSup (length, pVal, adrs);


    /* restore original exception handler */

    excVecSet ((FUNCPTR *) EXC_OFF_UNDEF, oldVec2);
    excVecSet ((FUNCPTR *) EXC_OFF_DATA, oldVec1);

    intUnlock (oldLevel);		/* restore interrupts */

    return status;
    }

/*******************************************************************************
*
* vxMemProbe - probe an address for a bus error
*
* This routine probes a specified address to see if it is readable or
* writable, as specified by <mode>.  The address will be read or written as
* 1, 2, or 4 bytes as specified by <length> (values other than 1, 2, or 4
* yield unpredictable results).  If the probe is a VX_READ, the value read will
* be copied to the location pointed to by <pVal>.  If the probe is a VX_WRITE,
* the value written will be taken from the location pointed to by <pVal>.
* In either case, <pVal> should point to a value of 1, 2, or 4 bytes, as
* specified by <length>.
*
* Note that only data abort errors are trapped during the probe.
*
* EXAMPLE
* .CS
* testMem (adrs)
*    char *adrs;
*    {
*    char testW = 1;
*    char testR;
*
*    if (vxMemProbe (adrs, VX_WRITE, 1, &testW) == OK)
*        printf ("value %d written to adrs %x\en", testW, adrs);
*
*    if (vxMemProbe (adrs, VX_READ, 1, &testR) == OK)
*        printf ("value %d read from adrs %x\en", testR, adrs);
*    }
* .CE
*
* MODIFICATION
* The BSP can modify the behaviour of this routine by supplying an alternate
* routine and placing the address of the routine in the global variable
* _func_vxMemProbeHook.  The BSP routine will be called instead of the
* architecture specific routine vxMemArchProbe().
*
* RETURNS:
* OK if the probe is successful, or
* ERROR if the probe caused an exception
*
* SEE ALSO: vxMemArchProbe()
*/

STATUS vxMemProbe
    (
    FAST char *adrs,	/* address to be probed */
    int mode,		/* VX_READ or VX_WRITE */
    int length,		/* 1, 2, or 4 */
    char *pVal 		/* where to return value, */
			/* or ptr to value to be written */
    )
    {
    STATUS status;
 
    if (_func_vxMemProbeHook != NULL)
 
        /* BSP specific probe routine */
 
        status = (* _func_vxMemProbeHook) ((void *)adrs, mode, length,
                                            (void *)pVal);
    else
 
        /* architecture specific probe routine */
 
        status = vxMemArchProbe ((void *)adrs, mode, length, (void *)pVal);
 
    return status;
    }



#if (ARM_THUMB)
/******************************************************************************
*
* thumbSymTblAdd - add a symbol table to Thumb symbol table
*
* This routine is called by the startup code in usrConfig.c to add a symbol
* to a Thumb symbol table. Note that it modifies the symbol passed to it.
*
* NOMANUAL
*/

STATUS thumbSymTblAdd
    (
    SYMTAB_ID symTblId,		/* symbol table to add symbol to */
    SYMBOL    *pSymbol		/* pointer to symbol to add */
    )
    {
    if (pSymbol->type == (SYM_GLOBAL | SYM_TEXT))
	{
	/* flag this as a Thumb code symbol and clear the LSb of its value */

	pSymbol->value = (char *)((UINT32)pSymbol->value & ~1);
	pSymbol->type |= SYM_THUMB;
	}
    return symTblAdd (symTblId, pSymbol);
    }
#endif
