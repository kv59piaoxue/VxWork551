/* vxLib.c - miscellaneous Hitachi SH support routines */

/* Copyright 1994-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01r,02nov01,zl   changed VXPOWERMODEREGS to use pointers
01q,07sep01,h_k  added power control support (SPR #69838).
01p,31aug00,hk   merge vxMemArchProbe() for SH7750/SH7700/SH7600/SH7000.
01o,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
01n,20apr00,hk   conformed D'Anne's design policy on vxMemProbe(). wrote
                 vxMemArchProbe() to catch MMU exceptions. moved vxMemProbeSup
                 to vxALib, deleted vxBerrStatus.
01m,03mar97,hk   added inline nops to catch bus error interrupt,
                 before to restore the original handler.
01l,01oct96,hk   disabled address error stuff and other junk in vxMemProbeSup.
01k,17sep96,hk   enabled func body for SH7700. some parts are commented out.
01j,18aug96,hk   deleted vxIntStackPointer, it's not used anymore.
01i,07jun96,hk   faked vxMemProbe() for SH7700's i() command (only for alpha).
01h,21may96,hk   workarounded vxMemProbeSup() for SH7700 build.
01g,16aug95,hk   moved reserved area check in vxMemProbe() to sysVxAdrsChk().
01f,05jul95,hk   modified vxMemProbe().
01e,28jun95,hk   added comment on vxMemProbe().
01d,27jun95,hk   added checking for reserved space access to vxMemProbe().
01c,09jun95,hk   moved vxTas() out to vxALib.s.
01b,08jun95,hk   fixed vxMemProbe() for dve7604 smNet slave mode.
01a,15dec94,sa   support vxMemProbe(), vxTas() for SH.
                 see also sysmemProbe(), sysBusTas().
01a,16oct94,hk   written.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines for Hitachi SH.

SEE ALSO: vxALib
 
INTERNAL:
The vxMemArchProbe should not be accessing BSP specific functions.  We
have added _func_vxMemProbeHook to do that.  This makes porting mips BSPs
different from porting other BSPs.  This module should not rely on sysBusEid(),
sysMaskVmeErr(), sysUnmaskVmeErr(), or sysBusTas().  (note bad name choices).
D'Anne, Aug 1997.

*/

#include "vxWorks.h"
#include "iv.h"
#include "intLib.h"
#include "vxLib.h"

/* global function pointers */

STATUS (* _func_vxMemProbeHook)
	    (void *,int,int, void *) = NULL;	/* hook for BSP vxMemProbe */
STATUS (* _func_vxIdleLoopHook) (void) = NULL;	/* hook for idle loop */

/* globals */

UINT32 vxPowMgtEnable = FALSE;			/* power management status */

VXPOWERMODEREGS vxPowerModeRegs = {NULL, NULL, NULL};

/* locals */

LOCAL UINT32 vxPowMgtMode = VX_POWER_MODE_DISABLE; /* power management mode */

/******************************************************************************
*
* vxMemArchProbe - architecture specific probe routine
*
* This is the routine implementing the architecture specific part of the
* vxMemProbe routine.  It traps the relevant exceptions while accessing
* the specified address.
*
* INTERNAL
* This routine functions by setting the MMU exception trap vectors to
* vxMemProbeTrap and then trying to read/write the specified address using
* vxMemProbeSup.  If the address is not accessible, vxMemProbeTrap will modify
* the return value of vxMemProbeSup to ERROR.  Note that this routine saves
* and restores the MMU exception vectors that were there prior to this call.
* The entire procedure is done with interrupts locked out.
* This routine captures only mis-aligned access for SH2/SH1.
*
* RETURNS: OK or ERROR if an exception occurred during access.
*/
 
STATUS vxMemArchProbe
    (
    void *adrs,		/* address to be probed */
    int   mode,		/* VX_READ or VX_WRITE */
    int length,		/* 1, 2, or 4 */
    void *pVal		/* where to return value, */
			/* or ptr to value to be written */
    )
    {
    STATUS status;

#if (CPU==SH7750 || CPU==SH7700)
    int key;
    FUNCPTR sv1, sv2, sv3, sv4;

    /* lock interrupts and save original vector(s) */

    key = intLock ();

    sv1 = intVecGet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_READ_MISS));
    sv2 = intVecGet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_WRITE_MISS));
    sv3 = intVecGet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_READ_PROTECTED));
    sv4 = intVecGet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_WRITE_PROTECTED));

    /* momentarily replace MMU exception handler(s) */

    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_READ_MISS),
		(FUNCPTR) vxMemProbeTrap);
    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_WRITE_MISS),
		(FUNCPTR) vxMemProbeTrap);
    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_READ_PROTECTED),
		(FUNCPTR) vxMemProbeTrap);
    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_WRITE_PROTECTED),
		(FUNCPTR) vxMemProbeTrap);
#endif

    /* do probe */

    if (mode == VX_READ)
	status = vxMemProbeSup (length, adrs, pVal);
    else
	status = vxMemProbeSup (length, pVal, adrs);

#if (CPU==SH7750 || CPU==SH7700)
    /* restore original vector(s) and unlock interrupts */

    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_READ_MISS), sv1);
    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_WRITE_MISS), sv2);
    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_READ_PROTECTED), sv3);
    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_TLB_WRITE_PROTECTED), sv4);

    intUnlock (key);
#endif

    return status;
    }

/*******************************************************************************
*
* vxMemProbe - probe an address for bus error
*
* This routine probes a specified address to see if it is readable or
* writable, as specified by <mode>.  The address will be read or written as
* 1, 2, or 4 bytes, as specified by <length>.  (Values other than 1, 2, or 4
* yield unpredictable results).  If the probe is a VX_READ, the value read will
* be copied to the location pointed to by <pVal>.  If the probe is a VX_WRITE,
* the value written will be taken from the location pointed to by <pVal>.
* In either case, <pVal> should point to a value of 1, 2, or 4 bytes, as
* specified by <length>.
*
* EXAMPLE
* .CS
*     testMem (adrs)
*         char *adrs;
*         {
*         char testW = 1;
*         char testR;
*
*         if (vxMemProbe (adrs, VX_WRITE, 1, &testW) == OK)
*             printf ("value %d written to adrs %x\en", testW, adrs);
*
*         if (vxMemProbe (adrs, VX_READ, 1, &testR) == OK)
*             printf ("value %d read from adrs %x\en", testR, adrs);
*         }
* .CE
*
* RETURNS:
* OK if the probe is successful, or ERROR if the probe caused a bus error or
* an address misalignment.
*
* SEE ALSO: sysLib: sysMemProbe()
*/

STATUS vxMemProbe 
    (
    FAST char *adrs,	/* address to be probed          */
    int        mode,	/* VX_READ (0) or VX_WRITE (1)   */
    int        length,	/* 1, 2, or 4                    */
    FAST char *pVal	/* where to return value,        */
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

/*******************************************************************************
*
* vxPowerModeSet - set the power management mode
*
* This routine selects the power management mode which will be activated
* only when the routine vxPowerDown() is called.
* vxPowerModeSet() is normally called in the BSP initialization routine
* (sysHwInit).
* Power management modes include the following:
* .iP "VX_POWER_MODE_DISABLE (0x0)"
* Power management is disable.
* .iP "VX_POWER_MODE_SLEEP (0x1)"
* CPU is inactive while the kernel is idle.
* .iP "VX_POWER_MODE_DEEP_SLEEP (0x2)"
* CPU and DMA are inactive while the kernel is idle (SH4 only).
* .iP "VX_POWER_MODE_USER (0xff)"
* User specific mode.
*
* RETURNS: OK, or ERROR if <mode> is incorrect, not supported by the
* processor or vxPowerModeRegs.pSTBCR1 is not set.
*
* SEE ALSO:
* vxPowerModeGet(), vxPowerDown()
*/

STATUS vxPowerModeSet
    (
    UINT32 mode			/* power management mode to select */
    )
    {
    UINT8 stbcrMode[3] = {0, 0, 0};

    if (vxPowerModeRegs.pSTBCR1 == NULL)
	return (ERROR);		/* vxPowerModeRegs.pSTBCR1 is not set */

    /* set stbcrMode, vxPowMgtEnable and vxPowMgtMode according to <mode> */

    switch (mode & VX_POWER_MODE_MASK)
	{
	case VX_POWER_MODE_DISABLE:
	    vxPowMgtEnable = FALSE;
	    vxPowMgtMode = VX_POWER_MODE_DISABLE;
	    _func_vxIdleLoopHook = NULL;
            break;

	case VX_POWER_MODE_SLEEP:
	    vxPowMgtMode = VX_POWER_MODE_SLEEP;
	    vxPowMgtEnable = TRUE;
	    _func_vxIdleLoopHook = (FUNCPTR) vxPowerDown;
	    break;

#if (CPU == SH7750)

	case VX_POWER_MODE_DEEP_SLEEP:
	    vxPowMgtMode = VX_POWER_MODE_DEEP_SLEEP;
	    vxPowMgtEnable = TRUE;
	    stbcrMode[1] = STBCR2_DSLP;
	    _func_vxIdleLoopHook = (FUNCPTR) vxPowerDown;
	    break;

#endif

	case VX_POWER_MODE_USER:
	    stbcrMode[0] = (mode & ~VX_POWER_MODE_MASK) >> 8;
	    stbcrMode[1] = (mode & ~VX_POWER_MODE_MASK) >> 16;
	    stbcrMode[2] = (mode & ~VX_POWER_MODE_MASK) >> 24;
	    vxPowMgtMode = VX_POWER_MODE_USER;
	    vxPowMgtEnable = TRUE;
	    _func_vxIdleLoopHook = (FUNCPTR) vxPowerDown;
	    break;

	default:
	    return (ERROR);             /* mode not supported */
	}

    /* set new value for STBCR */

    if (vxPowerModeRegs.pSTBCR3 != NULL)
	*vxPowerModeRegs.pSTBCR3 = stbcrMode[2];

    if (vxPowerModeRegs.pSTBCR2 != NULL)
	*vxPowerModeRegs.pSTBCR2 = stbcrMode[1];

    *vxPowerModeRegs.pSTBCR1 = stbcrMode[0];

    return (OK);
    }


/*******************************************************************************
*
* vxPowerModeGet - get the power management mode
*
* This routine returns the power management mode set via vxPowerDown().
*
* RETURNS:
* the power management mode (VX_POWER_MODE_SLEEP, VX_POWER_MODE_DEEP_SLEEP
* VX_POWER_MODE_DISABLE or VX_POWER_MODE_USER), or ERROR if power management
* is not supported.
*
* SEE ALSO:
* vxPowerModeSet(), vxPowerDown()
*/

UINT32 vxPowerModeGet (void)
    {
    return (vxPowMgtMode);		/* return mode set via vxPowerDown() */
    }
