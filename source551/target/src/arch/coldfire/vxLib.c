/* vxLib.c - ColdFire miscellaneous support routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,26nov01,dee  removed check for MCF5200
01b,19jun00,ur   Removed all non-Coldfire stuff.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines for Motorola
ColdFire.

SEE ALSO: vxALib
*/

#include "vxWorks.h"
#include "taskLib.h"
#include "intLib.h"
#include "iv.h"
#include "esf.h"

/* externals */

IMPORT vxMemProbeTrap ();
IMPORT vxMemProbeSup (int length, char *adrs, char *pVal);

FUNCPTR	_func_vxMemProbeHook = NULL;	/* hook for BSP vxMemProbe */

/*******************************************************************************
*
* vxMemArchProbe - architecture specific probe routine (ColdFire)
*
* This is the routine implementing the architecture specific part of the
* vxMemProbe routine.  It traps the relevant
* exceptions while accessing the specified address.
*
* RETURNS: OK or ERROR if an exception occurred during access.
*
* INTERNAL
* This routine functions by setting the machine check, data access and
* alignment exception vector to vxMemProbeTrap and then trying to read/write 
* the specified byte. If the address doesn't exist, or access error occurs,
* vxMemProbeTrap will return ERROR.  Note that this routine saves and restores 
* the exception vectors that were there prior to this call.  The entire 
* procedure is done with interrupts locked out.
*/

STATUS vxMemArchProbe 
    (
    FAST void *adrs,    /* address to be probed          */
    int mode,           /* VX_READ or VX_WRITE                 */
    int length,         /* 1, 2, or 4                    */
    FAST void *pVal     /* where to return value,        */
                        /* or ptr to value to be written */
    )
    {
    STATUS status;
    int oldLevel;
    FUNCPTR oldVec1;

    switch (length)
        {
        case (1):
	    break;

        case (2):
            if (((int) adrs & 0x1) || ((int) pVal & 0x1))
                return (ERROR);
            break;

        case (4):
            if (((int) adrs & 0x1) || ((int) pVal & 0x1))
                return (ERROR);
            break;

        default:
            return (ERROR);
        }

    oldLevel = intLock ();			/* lock out CPU */

    oldVec1 = intVecGet ((FUNCPTR *)IV_BUS_ERROR);	/* save bus error vec */
    intVecSet ((FUNCPTR *)IV_BUS_ERROR, vxMemProbeTrap);/* replace berr vec */

    /* do probe */

    if (mode == VX_READ)
	status = vxMemProbeSup (length, adrs, pVal);
    else
	status = vxMemProbeSup (length, pVal, adrs);

    /* restore original vector(s) and unlock */

    intVecSet ((FUNCPTR *)IV_BUS_ERROR, oldVec1);

    intUnlock (oldLevel);

    return (status);

    }

/*******************************************************************************
*
* vxMemProbe - probe an address for a bus error
*
* This routine probes a specified address to see if it is readable or
* writable, as specified by <mode>.  The address will be read or written as
* 1, 2, or 4 bytes as specified by <length> (values other than 1, 2, or 4
* yield unpredictable results).  If the probe is a O_RDONLY, the value read will
* be copied to the location pointed to by <pVal>.  If the probe is a O_WRONLY,
* the value written will be taken from the location pointed to by <pVal>.
* In either case, <pVal> should point to a value of 1, 2, or 4 bytes, as
* specified by <length>.
*
* Note that only data bus errors (machine check exception,  data access 
* exception) are trapped during the probe, and that the access must be 
* otherwise valid (i.e., not generate an address error).
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
* ERROR if the probe caused a bus error.
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

	status = (* _func_vxMemProbeHook) (adrs, mode, length, pVal);
    else

	/* architecture specific probe routine */

	status = vxMemArchProbe (adrs, mode, length, pVal);
    
    return status;
    }

/*******************************************************************************
*
* vxMacSupport - enable/disable MAC support for 52xx and 53xx CPUs
*
* This routine enables or disables (depending on the parameter) the
* support for the multiply/accumulate unit which is present on some of
* the Coldfire CPUs supported by the MCF5200 VxWorks architecture.
* The MAC support should normally be enabled in the BSP at startup.
* MAC support can only be enabled for CPUs that have a MAC. These
* include the 5307 and the 5206e. Do not enable MAC support for
* CPUs without the MAC (including 5204 and 5206), as this will
* crash the system.
* 
* This routine called from sysHwInit() in the bsp file sysLib.c
*
*
* RETURNS:
*  N/A
*
*/

void vxMacSupport
    (
    BOOL en	/* Enable (1) or disable (0) MAC support */
    )
    {
    _coldfireHasMac  = en;
    }
