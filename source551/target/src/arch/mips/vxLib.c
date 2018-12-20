/* vxLib.c - miscellaneous support routines */

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
03e,17jan02,tlc  Remove call to sysBusTas from vxLib.c.  Add proper funct-
                 ality as vxTas() is called by sysBusTas.  Add load-linked,
		 store-conditional vxTas_llsc version for those CPU_FAMILIES
		 which support it. (SPR #70336 fix).
03d,16jul01,ros  add CofE comment
03c,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
03b,26mar97,dra  added CW4011 support.
03b,04jun97,dat  added _func_vxMemProbeHook and vxMemArchProbe, SPR 8658.
		 removed sysMemProbe().
02z,19oct93,cd   added R4000 support.
03a,29mar94,caf  improved fix for SPR #3116, updated copyright notice.
02z,09mar94,caf  check for TLB mapped address in vxMemProbe() (SPR #3116).
02y,14sep92,yao  changed to pass void pointer to vxTas(). changed O_RDONLY
		 O_WRONLY to VX_READ and VX_WRITE.
02w,08jul92,ajm  ansified
02v,04jul92,jcf  scalable/ANSI/cleanup effort.
02u,24jun92,ajm  added include of vxLib.c and ioLib.c for O_RDONLY and ansi
02t,05jun92,ajm  5.0.5 merge, note mod history changes
02s,26may92,rrr  the tree shuffle
02r,14jan92,jdi  documentation cleanup.
02q,04oct91,rrr  passed through the ansification filter
                  -changed TINY and UTINY to INT8 and UINT8
                  -changed READ, WRITE and UPDATE to O_RDONLY O_WRONLY and O_RDW
R
                  -changed VOID to void
                  -changed copyright notice
02p,06jun91,ajm  changed vxMemProbe to check if vme error mask is already
		  turned on using sysMaskVmeErr
		  fixed pc increment to be by 1 for pointer
02o,25may91,gae  moved vxLsBitIndexTable & vxMsBitIndexTable here from sysLib.c.
02n,14dec90,ajm  documentation clean up
02m,13dec90,ajm  fixed vxMemProbe to handle vme bus error interrupts correctly
		  got rid of vxMemIntCheck in doing so
02i,23oct90,ajm  fixed register reference to call sysBusEid()
02h,31jul90,ajm  removed previously saved assembler algorithm for memIntCheck
02g,26jun90,rtp  now interpet address as pass by value vice pass by reference.
02f,26jun90,ajm  made vector references for intVecSet, intVecGet use
		  the macro INUM_TO_IVEC
02e,26jun90,ajm  put init of global var status in vxMemProbe so that
		  bus errors are not improperly assumed.
02d,26jun90,ajm  moved vxMemProbeTrap, and vxMemIntCheck from vxALib.s
02c,02may90,rtp  Made status an external so that assignment to it is 
		 explicit by routines in this file AND the assembly bus error 
		 exception and handler and ATE/VME level 5 interrupt status
		 routines  (which affect the outcome of the memory probe).
		 This file is board dependent for STAR and should be located
		 appropriately.
02b,01may90,rtp	 The guts of the Tas routine have been moved to sysLib.s 
		 since it makes use of board specific configuration items 
	 	 such as the availability of a VME read-modify-write register.
		 The vxTas routine is maintained for interface compatibility.
02a,23apr90,rtp  This file is now specific to the R3000. the vxTas routine 
		 is now here vice vxALib.s.
01g,01sep88,gae  documentation.
01f,22jun88,dnw  removed include of ioLib.h.
01e,05jun88,dnw  changed from kLib to vxLib.
		 removed taskRegsShow(), exit(), and breakpoint rtns to taskLib.
01d,30may88,dnw  changed to v4 names.
01c,28may88,dnw  removed reboot to rebootLib.
01b,21apr88,gae  added include of ioLib.h for READ/WRITE/UPDATE.
01a,28jan88,jcf	 written and soon to be redistributed.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines.

SEE ALSO: vxALib

INTERNAL:
The vxMemArchProbe should not be accessing BSP specific functions.  We
have added _func_vxMemProbeHook to do that.  This makes porting mips BSPs
different from porting other BSPs.  This module should not rely on sysBusEid(),
sysMaskVmeErr(), sysUnmaskVmeErr(), or sysBusTas().  (note bad name choices).
D'Anne, Aug 1997.

*/

#include "vxWorks.h"
#include "vxLib.h"
#include "intLib.h"
#include "ioLib.h"
#include "iv.h"
#include "esf.h"
#include "private/taskLibP.h"

/* externals */

IMPORT USHORT sysBusEid ();
IMPORT UINT8  sysMaskVmeErr ();
IMPORT UINT8  sysUnmaskVmeErr ();

#ifdef _WRS_MIPS_LL_SC
IMPORT BOOL   vxTas_llsc();
#endif

FUNCPTR	_func_vxMemProbeHook = NULL;	/* hook for BSP vxMemProbe */

/* locals */

LOCAL STATUS vxBerrStatus;		/* bus error global status */

/* forward declarations */

void vxMemProbeTrap (int vecNum, ESFMIPS *pEsf, int *regs);

/*******************************************************************************
*
* vxMemArchProbe - architecture specific probe routine (MIPS)
*
* This is the routine implementing the architecture specific part of the
* vxMemProbe routine.  It traps the relevant
* exceptions while accessing the specified address.
*
* RETURNS: OK or ERROR if an exception occurred during access.
*/

STATUS vxMemArchProbe
    (
    FAST void *adrs,	/* address to be probed */
    int mode,		/* VX_READ or VX_WRITE */
    int length,		/* 1, 2, or 4 */
    void *pVal 		/* where to return value, */
			/* or ptr to value to be written */
    )
    {
    FUNCPTR oldDBUSVec; 	/* old data bus exception handler */
    UINT8   *byte_operand; 	/* for byte r/w */
    USHORT  *short_operand;	/* for 16 bit r/w */
    ULONG   *word_operand;	/* for 32 bit r/w */
    USHORT  *spVal;		/* short holder for pVal */
    ULONG   *lpVal;		/* long holder for pVal */
    ULONG   oldLevel;		/* previous value of status reg */
    BOOL vmeStatus; 
    UINT8 temp; 

    /* NOTE: comment says that alignment check is not done */

    switch (length)
	{
        case 1:
	    break;
        case 2:
	    if ((UINT)adrs & 1)
		return (ERROR);
	    break;
        case 4:
	    if ((UINT)adrs & 3)
		return (ERROR);
	    break;
	default:
	    return (ERROR);
	    }

    if (!(IS_KSEG0(adrs) || IS_KSEG1(adrs)))
	return (ERROR);		/* TLB mapped addresses not supported */

    oldLevel = intLock ();      /* lock out external ints */

    vmeStatus = sysMaskVmeErr();/* lock out vme error int if not already */

    vxBerrStatus = OK;		/* clear previous settings of bus error */

    /* read and replace data bus error vector */
    oldDBUSVec = intVecGet ((FUNCPTR *) INUM_TO_IVEC(IV_DBUS_VEC));
    intVecSet ((FUNCPTR *) INUM_TO_IVEC(IV_DBUS_VEC), (FUNCPTR) vxMemProbeTrap);

    /* memory probe */
    switch (length)
	{
	case 1:
	    byte_operand = (UINT8 *) adrs; 
	    if (mode == VX_READ) 
		*(UINT8 *)pVal = *byte_operand;
	    else
		*byte_operand = *(UINT8 *)pVal;
	    break;
	case 2:
	    spVal = (USHORT *) pVal;		/* read or write short */
	    short_operand = (USHORT *) adrs;
	    if (mode == O_RDONLY) 
		*spVal = *short_operand;
	    else
		*short_operand = *spVal;
	    break;
	case 4:
	    lpVal = (ULONG *) pVal;		/* read or write long */
	    word_operand = (ULONG *) adrs;
	    if (mode == VX_READ) 
		*lpVal = *word_operand;
	    else
		*word_operand = *lpVal;
	    break;
	default:
	    break;
	}

    temp = (UINT8) sysBusEid();		/* clear pending vme error int if any */
    if (vmeStatus == TRUE)
        sysUnmaskVmeErr();		/* restore vme error interrupt */

    /* replace old bus error vector and unlock */

    intVecSet ((FUNCPTR *) INUM_TO_IVEC(IV_DBUS_VEC), oldDBUSVec);
    intUnlock (oldLevel);		/* restore external interrupts */

    return (vxBerrStatus);
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
* INTERNAL
* This routine functions by setting the machine check, data access and
* alignment exception vector to vxMemProbeTrap and then trying to read/write 
* the specified byte. If the address doesn't exist, or access error occurs,
* vxMemProbeTrap will return ERROR.  Note that this routine saves and restores 
* the excpetion vectors that were there prior to this call.  The entire 
* procedure is done with interrupts locked out.
*
* RETURNS:
*    OK if the probe is successful, or
*    ERROR if the probe caused a bus error.
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


/****************************************************************************
*
* vxTas - C-callable test-and-set primitive for the MIPS architecture
*
* This routine provides a read-modify-write capability through the sysLib
* routine sysBusTas().  If a CPU_FAMILY has load-linked, store-conditional
* support, the vxTas_llsc assembly routine is used to perform the test-and
* set.  
*
* RETURNS: 
*    TRUE if the value had not been set, but is now;
*    FALSE if the value was set already.
*
* SEE ALSO: sysLib: sysBusTas(), vxALib: vxTas_llsc
*/

BOOL vxTas
    (
    void * address 		/* address to test and set */
    )
    {
#ifdef _WRS_MIPS_LL_SC
    return (vxTas_llsc(address));
#else
    int oldLevel;

    oldLevel = intLock ();
    if (*(volatile char *) address == 0)
        {
        *(volatile char *) address = 1;
        intUnlock (oldLevel);
        return (TRUE);
        }
    intUnlock (oldLevel);

    return (FALSE); 
#endif
    }


/*******************************************************************************
*
* vxMemProbeTrap - vxMemProbe support routine
*
* This entry point is momentarily attached to the bus error exception vector.
* It is only activated as a result of the DBERR vector.  It simply sets the 
* global variable "vxBerrStatus" to ERROR to indicate that the bus error 
* did occur, and returns from the exception.
*
* NOMANUAL
*/

void vxMemProbeTrap
    (
    int vecNum,		/* exception vector number */
    ESFMIPS *pEsf,	/* pointer to exception stack frame */
    int *regs 		/* pointer to r3k 32 general regs on esf */
    )
    {
    /* bump epc so we don't re-excecute */
    pEsf->esfRegs.pc += 1;
    vxBerrStatus = ERROR;		/* so we know we got here	    */
    }

