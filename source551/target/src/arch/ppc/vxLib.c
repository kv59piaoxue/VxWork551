/* vxLib.c - miscellaneous support routines */

/* Copyright 1984-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01y,16dec02,mil  Updated support for PPC85XX.
01x,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
01w,09may02,dtr  Using vxPlprcrSet function for SPR34619.
01v,23apr02,pch  Handle _EXC_OFF_PROT as well as _EXC_OFF_DATA - SPR 76137
01u,17apr02,jtp  support PPC440 cache & mmu
01t,25mar02,kab  SPR 74651: PPC604 does not disable power down.
01s,22oct01,dtr  Fix for SPR65678. Code for PPC860 should lock/unlock keyed
                 registers due to board lock up/register corruption. S/W fix
                 for h/w problem.
01r,16aug01,pch  Add PPC440 support
01q,04dec00,s_m  removed vxExierEnable/Disable for 405
01p,25oct00,s_m  renamed PPC405 cpu types
01o,06oct00,sm   PPC405 support
01n,14jun2k,alp  Added PPC405 support.
01m,10nov99,cmc  Use vxImemBaseGet not vxImmrGet to get 555 internal mem map
01l,14sep99,cmc  Added MPC555 power mgt support
01p,12mar99,elg  VX_POWER_MODE_NAP is not supported by PPC860 (doc change)
                 (SPR 22432).
01o,18aug98,tpr  added PowerPC EC 603 support.
01n,07aug97,tam  fixed vxMemProbe for PPC403 on write (SPR #8370)
01m,04jun97,dat  added _func_vxMemProbeHook and vxMemArchProbe, SPR 8658.
01l,23oct96,tam  added vxPowerModeSet() and vxPowerModeGet() functions.
01k,28feb96,tam  removed vxFitXXX() & vxPitXXX functions.
01j,27feb96,ms   reworked vxMemProbeTrap().
01i,23feb96,tpr  moved vxDecXXX() functions to /drc/timer/ppcDecTimer.c.
01h,27jun95,caf  received new __gh_va_arg(), fixed "&" in it courtesy dnw.
01g,15jun95,caf  added EABI __va_arg() courtesy Diab Data, Inc.
01f,24may95,caf  fixed misplaced #endif in version 01e.
01e,22may95,caf  conditionally compiled __gh_va_arg().
01d,27apr95,caf  made vxDecCount global, removed vxDecEnable(),
		 added Green Hills helper routine __gh_va_arg().
01c,09feb95,yao  fixed vxMemProbe to reinstall the right handler.  added
		 alignment checking for short for PPC403.
01b,11oct94,yao  added PIT,FIT handling routines for 403. added code
		 for vxMemProbe.
01a,11oct94,yao  written.
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
#if	(CPU == PPC860)			/* necessary to prevent name clashes */
#include "drv/multi/ppc860Siu.h"	/* with h/arch/ppc/ppc403.h */
#endif	/* CPU == PPC860 */
#if	(CPU == PPC555)			/* necessary to prevent name clashes */
#include "drv/multi/ppc555Siu.h"	/* with h/arch/ppc/ppc403.h */
#endif	/* CPU == PPC555 */
#if	( (CPU == PPC403) || (CPU == PPC405)  || (CPU == PPC405F) || (CPU == PPC440))
#include "cacheLib.h"
#endif	/* CPU == PPC40x */

/* globals */

UINT32	vxPowMgtEnable = FALSE;		/* power management status */
#if (CPU == PPC860)
UINT32  vx860KeyedRegUsed = FALSE;      /* Lock/Unlock Keyed registers on access */
#endif

STATUS (* _func_vxMemProbeHook)
	    (void *,int,int, void *) = NULL;	/* hook for BSP vxMemProbe */

/* locals */

#if	((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	 (CPU == PPC860) || (CPU == PPC555) || (CPU == PPC85XX))
LOCAL  UINT32  vxPowMgtMode = VX_POWER_MODE_DISABLE; /* power management mode */
#endif	/* PPC603, PPCEC603, PPC604, PPC860, PPC555 */

/* forward declarations */

IMPORT STATUS  vxMemProbeSup (int length, char * src, char * dest);
IMPORT STATUS  vxMemArchProbe (void *, int, int, void *);
IMPORT FUNCPTR excVecGet (FUNCPTR * vector);
IMPORT void    excVecSet (FUNCPTR * vector, FUNCPTR proc);
IMPORT int     vmpxx();
#if (CPU==PPC860)
IMPORT void    vxPlprcrSet (UINT32*,UINT32,UINT32);
#endif
/******************************************************************************
*
* vxMemProbeTrap - trap handler for vxMemProbe exception
*
* This routine is called from the excConnectCode stub if vxMemProbeSup
* generates an exception. By default, vxMemProbeSup returns OK.
* This code changes the PC value to "vxpxx" (within the vxMemProbeSup
* routine), and vxpxx sets the return value to ERROR.
*
* INTERNAL
* A Data Machine Check exception (external bus error, non-configured memory
* error, bank protection violation, or time-out during data-side access)
* because of a write/load access to an non-configured memory address which
* was not in the data cache still causes a data cache line fill to occur on
* PowerPC 403 CPU. The data in this cache line is invalid, however the data
* cache has no way of knowing that and so does flag this cache line has valid.
* When this cache line need to be replaced, the data is written back to memory
* if it was a write access, then generating another machine check.
* With load access on an non-configured memory address, the cache line fill
* occurs too, however the cache line is not written back to memory.
* It is therefore necessary for vxMemProbeTrap() to invalidated this cache
* line to prevent it to be written back to memory.
*
* However, we must not do this for MMU protection violations (_EXC_OFF_PROT)
* because the invalidate operation would cause another _EXC_OFF_PROT and
* infinite recursion.
*/

static int vxMemProbeTrap
    (
    ESFPPC *    pEsf            /* pointer to exception stack frame */
    )
    {
    REG_SET *pRegSet = &pEsf->regSet;
#if	( (CPU == PPC403) || (CPU == PPC405)  || (CPU == PPC405F) || (CPU == PPC440))
    UINT32 adrs;
    int vecNum = pEsf->vecOffset;	/* exception vector number */

    if ((cacheLib.invalidateRtn != NULL) && (vecNum == _EXC_OFF_MACH))
	{
	/* get the offending address */

#if	( (CPU == PPC403) || (CPU == PPC405)  || (CPU == PPC405F))
	    adrs = pEsf->bear;
#else	/* CPU == PPC40x */
	    adrs = pEsf->dear;
#endif /* CPU == PPC40x */

	/* invalidate the corresponding cache line */
	cacheLib.invalidateRtn(DATA_CACHE, adrs, 16);
	}
#endif	/* CPU == PPC4xx */

    pRegSet->pc = (_RType)vmpxx;        /* vmpxx will force an ERROR return */
    return (0);
    }

/******************************************************************************
*
* vxMemArchProbe - architecture specific probe routine (PPC)
*
* This is the routine implementing the architecture specific part of the
* vxMemProbe routine.  It traps the relevant
* exceptions while accessing the specified address.
*
* RETURNS: OK or ERROR if an exception occurred during access.
*/

STATUS vxMemArchProbe
    (
    void* adrs,		/* address to be probed */
    int mode,		/* VX_READ or VX_WRITE */
    int length,		/* 1, 2, 4, 8, or 16 */
    void* pVal 		/* where to return value, */
			/* or ptr to value to be written */
    )
    {
    int oldLevel;
    FUNCPTR oldVec1;	/* for saving _EXC_OFF_MACH */
#ifdef	_EXC_OFF_DATA
    FUNCPTR oldVec2;	/* for saving _EXC_OFF_DATA */
#endif	/* _EXC_OFF_DATA */
    FUNCPTR oldVec3;	/* for saving _EXC_OFF_ALIGN */
#ifdef	_EXC_OFF_PROT
    FUNCPTR oldVec4;	/* for saving _EXC_OFF_PROT */
#endif	/* _EXC_OFF_PROT */
    STATUS result;

    /* CPU specific address verification */

    switch (length)
        {
        case (1):
	    break;

        case (2):
#if	(CPU==PPC403)
            if (((int) adrs & 0x1) || ((int) pVal & 0x1))
                return (ERROR);
#endif	/* (CPU==PPC403) */
            break;

        case (4):
            if (((int) adrs & 0x3) || ((int) pVal & 0x3))
                return (ERROR);
            break;

        case (8):
	    if (((int) adrs & 0x7) || ((int) pVal & 0x7))
	    return (ERROR);
	    break;

	case (16):
	    if (((int) adrs & 0xf) || ((int) pVal & 0xf))
	    return (ERROR);
	    break;
        default:
            return (ERROR);
        }
    oldLevel = intLock ();			/* lock out CPU */

    oldVec1 = excVecGet ((FUNCPTR *) _EXC_OFF_MACH);
    excVecSet ((FUNCPTR *) _EXC_OFF_MACH, FUNCREF(vxMemProbeTrap)); 

#ifdef	_EXC_OFF_DATA
    oldVec2 = excVecGet ((FUNCPTR *) _EXC_OFF_DATA);
    excVecSet ((FUNCPTR *) _EXC_OFF_DATA, FUNCREF(vxMemProbeTrap)); 
#endif	/* _EXC_OFF_DATA */
#ifdef	_EXC_OFF_PROT
    /*
     * _EXC_OFF_DATA and _EXC_OFF_PROT are mutually exclusive today,
     * and most likely always will be, but it costs nothing to name
     * the save areas uniquely and prevent any possible problem.
     */
    oldVec4 = excVecGet ((FUNCPTR *) _EXC_OFF_PROT);
    excVecSet ((FUNCPTR *) _EXC_OFF_PROT, FUNCREF(vxMemProbeTrap)); 
#endif	/* _EXC_OFF_PROT */
    oldVec3 = excVecGet ((FUNCPTR *) _EXC_OFF_ALIGN);
    excVecSet ((FUNCPTR *) _EXC_OFF_ALIGN, FUNCREF(vxMemProbeTrap)); 

    /* do probe */

    if (mode == VX_READ)
	result = vxMemProbeSup (length, adrs, pVal);
    else
	result = vxMemProbeSup (length, pVal, adrs);

    /* restore original vector(s) and unlock */

    excVecSet ((FUNCPTR *) _EXC_OFF_MACH, oldVec1);
#ifdef	_EXC_OFF_DATA
    excVecSet ((FUNCPTR *) _EXC_OFF_DATA, oldVec2);
#endif	/* _EXC_OFF_DATA */
#ifdef	_EXC_OFF_PROT
    excVecSet ((FUNCPTR *) _EXC_OFF_PROT, oldVec4);
#endif	/* _EXC_OFF_PROT */
    excVecSet ((FUNCPTR *) _EXC_OFF_ALIGN, oldVec3);

    intUnlock (oldLevel);

    return (result);
    }

/*******************************************************************************
*
* vxMemProbe - probe an address for a bus error
*
* This routine probes a specified address to see if it is readable or
* writable, as specified by <mode>.  The address will be read or written as
* 1, 2, 4, 8, or 16 bytes as specified by <length> (other values
* yield unpredictable results).  If the probe is a O_RDONLY, the value read will
* be copied to the location pointed to by <pVal>.  If the probe is a O_WRONLY,
* the value written will be taken from the location pointed to by <pVal>.
* In either case, <pVal> should point to a location of the size specified by
* <length>.
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
* INTERNAL
* This routine functions by setting the machine check, data access and
* alignment exception vector to vxMemProbeTrap and then trying to read/write 
* the specified byte. If the address doesn't exist, or access error occurs,
* vxMemProbeTrap will return ERROR.  Note that this routine saves and restores 
* the excpetion vectors that were there prior to this call.  The entire 
* procedure is done with interrupts locked out.
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
* .iP "VX_POWER_MODE_DISABLE (0x1)"
* Power management is disable: this prevents MSR(POW) bit to be set (all PPC).
* .iP "VX_POWER_MODE_FULL (0x2)"
* All CPU units are active while the kernel is iddle (PPC555, PPC603, PPCEC603 and
* PPC860 only).
* .iP "VX_POWER_MODE_DOZE (0x4)"
* Only the decrementer, data cache and bus snooping are active (PPC555, PPC603, PPCEC603
* and PPC860).
* .iP "VX_POWER_MODE_NAP (0x8)"
* Only the decrementer is active (PPC603, PPCEC603 and PPC604).
* .iP "VX_POWER_MODE_SLEEP (0x10)"
* All CPU units are inactive while the kernel is idle (PPC555, PPC603, PPCEC603 and
* PPC860) - not recommended for the PPC603 and PPCEC603 architecture.
* .iP "VX_POWER_MODE_DEEP_SLEEP (0x20)"
* All CPU units are inactive while the kernel is idle (PPC555 and PPC860 only) - not
* recommended.
* .iP "VX_POWER_MODE_DPM (0x40)"
* Dynamic Power Management Mode	(PPC603 and PPCEC603 only).
* .iP "VX_POWER_MODE_DOWN (0x80)"
* Only a hard reset causes an exit from power-down low power mode (PPC555 and PPC860 only)
* - not recommended.
*
* RETURNS: OK, or ERROR if <mode> is incorrect or not supported by the
* processor.
*
* SEE ALSO:
* vxPowerModeGet(), vxPowerDown()
*/

STATUS vxPowerModeSet 
    (
    UINT32 mode			/* power management mode to select */
    )
    {
#if	((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC85XX))
    UINT32 hid0Mode;

    /* set hid0Mode, vxPowMgtEnable and vxPowMgtMode according to <mode> */

    switch (mode)
	{
    	case VX_POWER_MODE_DISABLE:
	    hid0Mode = 0;
	    vxPowMgtEnable = FALSE;
	    vxPowMgtMode = VX_POWER_MODE_DISABLE;
	    break;

#if (CPU != PPC85XX)
    	case VX_POWER_MODE_DPM:
	    hid0Mode = _PPC_HID0_DPM;
	    vxPowMgtMode = VX_POWER_MODE_DPM;
    	    vxPowMgtEnable = TRUE;
	    break;
#endif  /* CPU != PPC85XX */

    	case VX_POWER_MODE_FULL:
	    hid0Mode = 0;
	    vxPowMgtMode = VX_POWER_MODE_FULL;
    	    vxPowMgtEnable = TRUE;
	    break;

    	case VX_POWER_MODE_DOZE:
	    hid0Mode = _PPC_HID0_DOZE;
	    vxPowMgtMode = VX_POWER_MODE_DOZE;
    	    vxPowMgtEnable = TRUE;
	    break;

    	case VX_POWER_MODE_NAP:
	    hid0Mode = _PPC_HID0_NAP;
	    vxPowMgtMode = VX_POWER_MODE_NAP;
    	    vxPowMgtEnable = TRUE;
	    break;

    	case VX_POWER_MODE_SLEEP:
	    hid0Mode = _PPC_HID0_SLEEP;
	    vxPowMgtMode = VX_POWER_MODE_SLEEP;
    	    vxPowMgtEnable = TRUE;
	    break;

	default:
	    return (ERROR);		/* mode not supported */
	}

    /* set new value for HID0 */

#if (CPU != PPC85XX)
    vxHid0Set ((vxHid0Get() & ~(_PPC_HID0_DOZE | _PPC_HID0_NAP | 
		_PPC_HID0_SLEEP | _PPC_HID0_DPM)) | hid0Mode);
#else  /* CPU != PPC85XX */
    vxHid0Set ((vxHid0Get() & ~(_PPC_HID0_DOZE | _PPC_HID0_NAP | 
		_PPC_HID0_SLEEP)) | hid0Mode);
#endif  /* CPU != PPC85XX */

    return (OK);

#elif	(CPU == PPC604)

    /* set vxPowMgtEnable and vxPowMgtMode according to <mode> */

    if (mode == VX_POWER_MODE_DISABLE) 
        {
	vxPowMgtEnable = FALSE;
	vxPowMgtMode = VX_POWER_MODE_DISABLE;
	}
    else
        {
    	if (mode == VX_POWER_MODE_NAP)
	    {
	    vxPowMgtMode = VX_POWER_MODE_NAP;
    	    vxPowMgtEnable = TRUE;
	    }
	else
	    return (ERROR);
	}
    
    return (OK);

#elif	((CPU == PPC860) || (CPU == PPC555))
    UINT32 	plprcrVal = 0;
    
# if (CPU == PPC555)
    int 	immrVal = vxImemBaseGet();
# else	/* CPU == PPC555 */
    int 	immrVal = vxImmrGet();
# endif	/* CPU == PPC555 */

    /* set plprcrVal, vxPowMgtEnable and vxPowMgtMode according to <mode> */

    switch (mode)
	{
	case VX_POWER_MODE_DISABLE:
	    plprcrVal = PLPRCR_LPM_NORMAL;
	    vxPowMgtMode = VX_POWER_MODE_DISABLE;
    	    vxPowMgtEnable = FALSE;
	    break;

	case VX_POWER_MODE_FULL:
	    plprcrVal = PLPRCR_LPM_NORMAL;
	    vxPowMgtMode = VX_POWER_MODE_FULL;
    	    vxPowMgtEnable = TRUE;
	    break;

    	case VX_POWER_MODE_DOZE:
	    plprcrVal = PLPRCR_LPM_DOZE;
	    vxPowMgtMode = VX_POWER_MODE_DOZE;
    	    vxPowMgtEnable = TRUE;
	    break;

    	case VX_POWER_MODE_SLEEP:
	    plprcrVal = PLPRCR_LPM_SLEEP;
	    vxPowMgtMode = VX_POWER_MODE_SLEEP;
    	    vxPowMgtEnable = TRUE;
	    break;

    	case VX_POWER_MODE_DEEP_SLEEP:
	    plprcrVal = PLPRCR_LPM_DEEP_SLEEP;
	    vxPowMgtMode = VX_POWER_MODE_DEEP_SLEEP;
    	    vxPowMgtEnable = TRUE;
	    break;

    	case VX_POWER_MODE_DOWN:
	    plprcrVal = PLPRCR_LPM_DOWN | PLPRCR_TEXPS;
	    vxPowMgtMode = VX_POWER_MODE_DOWN;
    	    vxPowMgtEnable = TRUE;
	    break;

	default:
	    return (ERROR);		/* mode not supported */
	}

    /* set new value for PLPRCR */

# if (CPU == PPC860)
    if (vx860KeyedRegUsed==TRUE)
        {
	*PLPRCRK(immrVal) = 0x55ccaa33; /* KEYED_REG_UNLOCK_VALUE */
	WRS_ASM("        isync");
	plprcrVal |= (*PLPRCR(immrVal) & ~PLPRCR_LPM_MSK);
        /* the delay value of 3 is worst case scenario */
	vxPlprcrSet ((UINT32*)immrVal,plprcrVal,3); 
	*PLPRCRK(immrVal) = ~0x55ccaa33; /* ~KEYED_REG_UNLOCK_VALUE */
        }
    else
        {
	plprcrVal |= (*PLPRCR(immrVal) & ~PLPRCR_LPM_MSK);
        /* the delay value of 3 is worst case scenario */ 
	vxPlprcrSet ((UINT32*)immrVal,plprcrVal,3);
        }

# else	/* CPU == PPC860 */
    *PLPRCR(immrVal) = (*PLPRCR(immrVal) & ~PLPRCR_LPM_MSK) | plprcrVal;
# endif	/* CPU == PPC860 */

    return (OK);

#else	/* remaining cases are 403, 405, 405F, 440, 505, 509, 601, 602 */

    return (ERROR);			/* power management not supported */

#endif	/* ((CPU == PPC603) || (CPU == PPCEC603)) */
    }

/*******************************************************************************
*
* vxPowerModeGet - get the power management mode 
*
* This routine returns the power management mode set via vxPowerDown().
*
* RETURNS:
* the power management mode (VX_POWER_MODE_DOZE, VX_POWER_MODE_NAP,
* VX_POWER_MODE_SLEEP, VX_POWER_MODE_DEEP_SLEEP, VX_POWER_MODE_DPM,
* VX_POWER_MODE_FULL, VX_POWER_MODE_DOWN or VX_POWER_MODE_DISABLE),
* or ERROR if no power mode has been selected or power management is
* not supported.
*
* SEE ALSO:
* vxPowerModeSet(), vxPowerDown()
*/

UINT32 vxPowerModeGet (void)
    {
#if	((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	 (CPU == PPC860) || (CPU == PPC555) || (CPU == PPC85XX))

    return (vxPowMgtMode);		/* return mode set via vxPowerDown() */

#else	/* remaining cases are 403, 405, 405F, 440, 505, 509, 601, 602 */

    return (ERROR);			/* power management not supported */

#endif	/* PPC603, PPCEC603, PPC604, PPC860, PPC555 */
    }


#if	(CPU==PPC403)
/*******************************************************************************
*
* vxExierEnable - turn on external interrupt
*
* This routine enables specified external interrupt by setting the exier.
*
* RETURNS: old value of exier.
*
*/

UINT32 vxExierEnable 
    (
    UINT32 exier		/* external interrupts to enable */
    )
    {
    int oldExier = vxExierGet ();

    vxExierSet ((oldExier | exier));

    return (oldExier);
    }
/*******************************************************************************
*
* vxExierDisable - turn off external interrupt
*
* This routine disables specified external interrupt.  
*
* RETURNS: old value of exier.
*
*/
UINT32 vxExierDisable 
    (
    UINT32 exier		/* external interrupts to disable */
    )
    {
    int oldExier = vxExierGet ();

    vxExierSet ((oldExier & ~exier));

    return (oldExier);
    }
#endif	/* CPU==PPC403 */

#if 0 /*PCS Verify with DIAB folks. */
#ifdef	_DIAB_TOOL

/*
 * Copyright 1995 Diab Data, Inc.
 *
 * Description :
 * Implemention of PowerPC ABI function
 * void *__va_arg(va_list argp, int type)
 *
 * History :
 * When     Who     What
 * 950523   teve    initial
 */

#undef __EABI__
#define __EABI__	1

void *__va_arg(va_list argp, int type)
    {
    int index;
    char *rp;

    if (type == 1) 
        {	/* arg_WORD	*/
       	index = argp->__gpr;
       	if (index < 8) 
            {
    	    argp->__gpr = index + 1;
	    return argp->__reg + index*4;
	    } 
        else 
            {
	    rp = argp->__mem;
	    argp->__mem = rp + 4;
	    return rp;
	    }
	} 
    else if (type == 3) 
        {	/* arg_ARGREAL	*/
	index = argp->__fpr;
        if (index < 8) 
            {
            argp->__fpr = index + 1;
            return argp->__reg + index*8 + 32;
  	    } 
        else 
            {
	    rp = argp->__mem;
	    rp = (char *)(((long)rp + 7) & ~7);
            argp->__mem = rp + 8;
            return rp;
            }
        } 
    else if (type == 4) 
        {	/* arg_ARGSINGLE */
        index = argp->__fpr;
        if (index < 8) 
            {
            argp->__fpr = index + 1;
	    return argp->__reg + index*4 + 32;
            } 
        else 
            {
	    rp = argp->__mem;
            argp->__mem = rp + 4;
            return rp;
            }
        } 
    else if (type == 2) 
        {	/* arg_DOUBLEWORD */
        index = argp->__gpr;
      	index = (index + 1) & ~1;
       	if (index < 7) 
            { 
       	    argp->__gpr = index + 2;
       	    return argp->__reg + index*4;
       	    } 
        else 
            {
      	    rp = argp->__mem;
       	    argp->__gpr = index;
       	    rp = (char *)(((long)rp + 7) & ~7);
       	    argp->__mem = rp + 4;
       	    return rp;
       	    }
        } 
    else if (type == 0) 
        {	/* arg_ARGPOINTER */
        index = argp->__gpr;
        if (index < 8) 
            {
            argp->__gpr = index + 1;
	    return *(void **)(argp->__reg + index*4);
	    } 
        else 
            {
            rp = argp->__mem;
	    argp->__mem = rp + 4;
	    return *(void **)rp;
	    }
	}
    }    

#endif	/* _DIAB_TOOL */
#endif

#ifdef	_GREEN_TOOL

# if	( (CPU==PPC403) || (CPU==PPC405) || (CPU==PPC440) )
#define	__ppcsfp	/* soft floating point */
# endif	/* CPU==PPC403 || CPU==PPC405 || CPU==PPC440 */

/* the following code is from indvaarg.c of Green Hills */

/*
		    Low Level Interface Library

    Copyright 1983,1984,1985,1986,1987,1988,1989,1990,1991,1992,1993,1994
		    Green Hills Software,Inc.

 *  This program is the property of Green Hills Software, Inc,
 *  its contents are proprietary information and no part of it
 *  is to be disclosed to anyone except employees of Green Hills
 *  Software, Inc., or as agreed in writing signed by the President
 *  of Green Hills Software, Inc.
 *
*/

#define NINTREGS 8
#define NFLTREGS 13

# if !defined(__ppcsfp)

/* Power PC Varargs helper function */
/* This assumes that all pointers are the same size >= size of ints.
 * Actually for PPC pointers are the size of ints now, but this is
 * designed to be slightly more general.
 */
char * __gh_va_arg(va_list *pap, int isreg, int isfloat, int size)
    {
/* [Hal] Wed May 24 12:03:17 PDT 1995 - Rewrite to be reentrant. */
    char *z;
    if (isreg && !isfloat) 
        {
	/* ints */
	if (pap->int_cnt < NINTREGS) 
            {
	    return (char *)&pap->reg_ptr[pap->int_cnt++];
	    } 
        else 
            {
	    return (char *)&pap->oflo_ptr[pap->mem_cnt++];
	    }
        } 
    else if (isreg && isfloat) 
        {
	/* doubles */
#       define DSIZE (sizeof(double)/sizeof(int))
	if (pap->FP_cnt < NFLTREGS) 
            {
	    return (char *)(pap->reg_ptr+NINTREGS+(DSIZE*pap->FP_cnt++));
	    } 
        else 
            {
	    /* Align doubles */
	    pap->mem_cnt = ((pap->mem_cnt+DSIZE-1)/DSIZE)*DSIZE;
	    z = (char *)(pap->oflo_ptr+pap->mem_cnt);
	    pap->mem_cnt += DSIZE;
	    return z;
	    }
        } 
    else 
        {
	/* structs */
#       define PSIZE (sizeof(char *)/sizeof(int))
	if (pap->int_cnt < NINTREGS) 
            {
	    z = *(char **)(pap->reg_ptr+(PSIZE*pap->int_cnt));
	    pap->int_cnt += PSIZE;
	    } 
        else 
            {
	    z = *(char **)(pap->oflo_ptr+pap->mem_cnt);
	    pap->mem_cnt += PSIZE;
	    }
	return z;		/* structs passed as addresses */
       }
    }

# else /* __ppcsfp */
/* [Hal] Tue Mar 21 14:56:56 PST 1995 - Support for PPC403 software FP. */

char * __gh_va_arg(va_list *pap, int isreg, int isfloat, int size)
    {
/* [Hal] Wed May 24 12:03:17 PDT 1995 - Rewrite to be reentrant. */
    char *z;
    if (isreg && !isfloat) 
        {
	/* ints */
	if (pap->int_cnt < NINTREGS) 
            {
	    return (char *)&pap->reg_ptr[pap->int_cnt++];    /* fixed: & */
	    } 
        else 
            {
	    return (char *)&pap->oflo_ptr[pap->mem_cnt++];   /* fixed: & */
	    }
        } 
    else if (isreg && isfloat) 
        {
	/* doubles */
#       define DSIZE (sizeof(double)/sizeof(int))
	if (pap->int_cnt & 1)	/* Get to even offset */
	    pap->int_cnt += 1;
	if (pap->int_cnt < NINTREGS) 
            {
	    z = (char *)(pap->reg_ptr+pap->int_cnt);
	    pap->int_cnt += 2;
	    } 
        else 
            {
	    /* Align doubles */
	    pap->mem_cnt = ((pap->mem_cnt+DSIZE-1)/DSIZE)*DSIZE;
	    z = (char *)(pap->oflo_ptr+pap->mem_cnt);
	    pap->mem_cnt += DSIZE;
	    }
	return z;
        } 
    else 
        {
	/* structs */
#       define PSIZE (sizeof(char *)/sizeof(int))
	if (pap->int_cnt < NINTREGS) 
            {
	    z = *(char **)(pap->reg_ptr+(PSIZE*pap->int_cnt));
	    pap->int_cnt += PSIZE;
	    } 
        else 
            {
	    z = *(char **)(pap->oflo_ptr+pap->mem_cnt);
	    pap->mem_cnt += PSIZE;
	    }
	return z;		/* structs passed as addresses */
        }
    }

# endif	/* __ppcsfp */

#endif	/* _GREEN_TOOL */
