/* excArchLib.c - MIPS architecture exception handling facilities */

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
02h,16jul01,ros  add CofE comment
02g,13jul01,sru  fix 32-bit extraction of break type
02f,17apr01,dxc  SPR 64275: Fix to handle MIPS16 correctly
02h,13apr01,sru  add BSP-callable functions to set exception vectors
02g,28mar01,sru  use UT_VEC for R3K tlb vector address
02f,19dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
02e,10sep99,myz  added CW4000_16 support
02d,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
02c,14oct96,kkk  added R4650 support.
02c,22jul96,pr   added windview instrumentation.
02b,30may96,kkk  changed FP exceptions from excIntHandle to excExcHandle.
02a,18oct93,cd   added R4000 support.
01z,29sep93,caf  undid fix of SPR #2359.
01y,07jul93,yao  fixed to preserve parity error bit of status 
		 register (SPR #2359).
           +caf  ansification: added cast to cacheInvalidate() parameter,
		 added forward declaration of excGetInfoFromESF().
01x,19oct92,jcf  swapped 5.0/excInfoShow hook order.
01w,01oct92,ajm  changed excIntToExc to excIntHandle for fpa ints
01v,31aug92,rrr  fixed code passed to signal handler
01u,23aug92,jcf  reverted to version 1t.
01t,23aug92,jcf  changed cache* to CACHE_*.  changed filename.
01s,07aug92,ajm  ansified
01r,02aug92,jcf  pass two of exc split. excJobAdd no longer needed.
01p,30jul92,rrr  pass one of the exc split
01o,09jul92,ajm  corrected include list with sigLibP.h
01n,07jul92,ajm  added 5.1 cache support
01m,04jul92,jcf  scalable/ANSI/cleanup effort.
01l,06jun92,ajm  5.0.5 merge, notice mod history changes
01k,26may92,rrr  the tree shuffle
01j,16jan92,yao  removed EXC_MSG.  made excExcFix() local.  added missing
                 args to excJobAdd() and printExc(). added excFaultTab[].
                 moved excDeliverSignal() to src/all/excLib.c.
02i,16jan92,jdi  made excExcFix() NOMANUAL.
02h,14jan92,jdi  documentation cleanup.
01g,18nov91,ajm  turned off rom based vectors in excVecInit
01f,05oct91,ajm  corrected order of VME interrupts in excMsgs
01e,04oct91,rrr  passed through the ansification filter
                  -changed includes to have absolute path from h/
                  -changed VOID to void
                  -changed copyright notice
01d,31jul91,ajm  made co-processor exceptions place fpcsr in sigcontext
		  made excExcFix global for handling of fpa interrupts
		  this should be changed later
01c,17jul91,ajm  added interrupt ack to excIntHandle
01b,01jul91,ajm  fixed badva not to be valid on bus error
01a,01apr91,ajm  MIPS-ized and split from excLib.c.  Derived from 02h of 68k.
*/

/*
This module provides architecture-dependent facilities for handling MIPS
R-Series exceptions.  See excLib for the portions that are architecture
independent.

INITIALIZATION
Initialization of exception handling facilities is in two parts.  First,
excVecInit() is called to set all the MIPS exception, trap, and interrupt
vectors to the default handlers provided by this module.  The rest of this
package is initialized by calling excInit() (in excLib), which spawns the
exception support task, excTask(), and creates the pipe used to communicate
with it.  See the manual entry for excLib for more information.

SEE ALSO: excLib,
.pG "Debugging"
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "esf.h"
#include "iv.h"
#include "sysLib.h"
#include "intLib.h"
#include "msgQLib.h"
#include "signal.h"
#include "cacheLib.h"
#include "errnoLib.h"
#include "dsmLib.h"
#include "private/funcBindP.h"
#include "private/sigLibP.h"
#include "private/taskLibP.h"
#include "string.h"
#include "rebootLib.h"


/* externals  */

IMPORT void excIntToExc ();     /* change interrupt thread */
IMPORT FUNCPTR excExcepHook;    /* add'l rtn to call when exceptions occur */
IMPORT int sysAutoAck(int );
IMPORT ULONG sysBusEar(void );
IMPORT USHORT sysBusEid(void );

/* forward declarations */

LOCAL void excIntHandle (int vecNum, ESFMIPS * pEsf);
void 	   excExcHandle (int vecNum, ESFMIPS * pEsf, REG_SET * pRegs);
LOCAL int  excGetInfoFromESF (FAST int vecNum, FAST ESFMIPS *pEsf,
			      EXC_INFO *pExcInfo);

/*
* excBsrTbl - table of BSRs
*
*	The BSR table is the pointer table for MIPS specific 
*	exceptions, and interrupts.  After an exception, the least 
*	significant bits of the cause register will point us here.  
*	After an interrupt, we use the structure intPrioTbl to point 
*	us to the correct entry.
*/

VOIDFUNCPTR excBsrTbl[] = 
    {
    excIntHandle, 	/* 0 - interrupt exception	*/
    excExcHandle, 	/* 1 - tlb mod exception	*/
    excExcHandle, 	/* 2 - tlb load exception	*/
    excExcHandle,	/* 3 - tlb store exception	*/
    excExcHandle, 	/* 4 - address load exception	*/
    excExcHandle, 	/* 5 - address store exception	*/
    excExcHandle, 	/* 6 - instr. bus error exception*/
    excExcHandle,	/* 7 - data bus error exception	*/
    excExcHandle, 	/* 8 - system call exception	*/
    excExcHandle, 	/* 9 - break point exception	*/
    excExcHandle, 	/* 10 - rsvd instruction exception*/
    excExcHandle,	/* 11 - coprocessor unusable excptn*/
    excExcHandle, 	/* 12 - overflow exception	*/
    excExcHandle,	/* 13 - trap exception 		*/
    excExcHandle, 	/* 14 - VCEI exception 		*/
    excExcHandle,	/* 15 - FPE exception 		*/
    excExcHandle,	/* 16 - reserved entry		*/
    excExcHandle,	/* 17 - reserved entry		*/
    excExcHandle,	/* 18 - reserved entry		*/
    excExcHandle,	/* 19 - reserved entry		*/
    excExcHandle,	/* 20 - reserved entry		*/
    excExcHandle,	/* 21 - reserved entry		*/
    excExcHandle,	/* 22 - reserved entry		*/
    excExcHandle,	/* 23 - watch exception		*/
    excExcHandle,	/* 24 - reserved entry		*/
    excExcHandle,	/* 25 - reserved entry		*/
    excExcHandle,	/* 26 - reserved entry		*/
    excExcHandle,	/* 27 - reserved entry		*/
    excExcHandle,	/* 28 - reserved entry		*/
    excExcHandle,	/* 29 - reserved entry		*/
    excExcHandle,	/* 30 - reserved entry		*/
    excExcHandle,	/* 31 - VCED exception		*/
    excIntHandle,	/* 32 - software trap 0 	*/
    excIntHandle,	/* 33 - software trap 1 	*/
    excIntHandle,	/* 34 - autovec VME irq7 interrupt 	*/
    excIntHandle,	/* 35 - autovec VME irq6 interrupt 	*/
    excIntHandle,	/* 36 - autovec VME irq5 interrupt 	*/
    excIntHandle,	/* 37 - autovec VME irq4 interrupt 	*/
    excIntHandle,	/* 38 - autovec VME irq3 interrupt	*/	
    excIntHandle,	/* 39 - autovec VME irq2 interrupt	*/
    excIntHandle,	/* 40 - autovec VME irq1 interrupt 	*/
    excIntHandle,	/* 41 - spare interrupt	*/
    excIntHandle,	/* 42 - uart 0 interrupt	*/
    excIntHandle,	/* 43 - uart 1 interrupt	*/
    excIntHandle,	/* 44 - msg pending interrupt	*/
    excIntHandle,	/* 45 - spare interrupt		*/
    excIntHandle,	/* 46 - spare interrupt		*/
    excIntHandle,	/* 47 - hw bp interrupt		*/
    excIntHandle,	/* 48 - spare interrupt		*/
    excIntHandle,	/* 49 - spare interrupt		*/
    excIntHandle,	/* 50 - timer 0 interrupt	*/
    excIntHandle,	/* 51 - timer 1 interrupt	*/
    excIntHandle,	/* 52 - spare exception		*/
    excIntHandle,	/* 53 - spare exception		*/
    excExcHandle,	/* 54 - unimplemented FPA oper	*/
    excExcHandle,	/* 55 - invalid FPA operation	*/
    excExcHandle,	/* 56 - FPA div by zero		*/
    excExcHandle,	/* 57 - FPA overflow exception	*/
    excExcHandle,	/* 58 - FPA underflow exception	*/
    excExcHandle,	/* 59 - FPA inexact operation	*/
    excIntHandle,	/* 60 - bus error interrupt	*/
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 70 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 80 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 90 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 100 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 110 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 120 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 130 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 140 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 150 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 160 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 170 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 180 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 190 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 200 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 210 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 220 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 230 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 240 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 250 */
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,
    excIntHandle,	/* 255 */
    };

/*
* sysExcVecInitHook - Initialized to NULL, but can be modified by a BSP 
* prior to the call to excVecInit() to provide an alternate means of 
* initializing the exception vectors.  This variable is placed in the
* data segment rather than the BSS, because the BSP hook that is used
* to set this variable is called before the BSS is cleared.
*/

FUNCPTR sysExcVecInitHook = NULL;


/*******************************************************************************
*
* excNormVecInit - initialize the normal exception vector.
*
* This routine loads the exception handler code for the normal exception 
* vector into the address requested by the BSP.
*
* RETURNS: N/A
*/

void excNormVecInit
    (
    void *vecAdrs
    )
    {
    extern int excNormVec[];	/* instructions for branch to normal handler */
    extern int excNormVecSize;

    /* Load normal exception vector and invalidate instruction cache */
    
    bcopy ((const char *) excNormVec, (char *) vecAdrs, excNormVecSize);
    cacheTextUpdate (vecAdrs, excNormVecSize);
    }


/*******************************************************************************
*
* excTlbVecInit - initialize the TLB exception vector.
*
* This routine loads the exception handler code for the TLB exception 
* vector into the address requested by the BSP.
*
* RETURNS: N/A
*/

void excTlbVecInit
    (
    void *vecAdrs
    )
    {
    extern int excTlbVec[];	/* instructions for branch to TLB handler */
    extern int excTlbVecSize;

    /* Load tlb vector and invalidate instruction cache */

    bcopy ((const char *) excTlbVec, (char *) vecAdrs, excTlbVecSize);
    cacheTextUpdate (vecAdrs, excTlbVecSize);
    }


#ifndef _WRS_R3K_EXC_SUPPORT

/*******************************************************************************
*
* excXtlbVecInit - initialize the XTLB exception vector.
*
* This routine loads the exception handler code for the XTLB exception 
* vector into the address requested by the BSP.
*
* RETURNS: N/A
*/

void excXtlbVecInit
    (
    void *vecAdrs
    )
    {
    extern int excXtlbVec[];	/* instructions for branch to xtlb handler */
    extern int excXtlbVecSize;

    /* Load xtlb vector and invalidate instruction cache */

    bcopy ((const char *) excXtlbVec, (char *) vecAdrs, excXtlbVecSize);
    cacheTextUpdate (vecAdrs, excXtlbVecSize);
    }

/*******************************************************************************
*
* excCacheVecInit - initialize the cache exception vector.
*
* This routine loads the exception handler code for the cache exception 
* vector into the address requested by the BSP.
*
* RETURNS: N/A
*/

void excCacheVecInit
    (
    void *vecAdrs
    )
    {
    extern int excCacheVec[];	/* instructions for branch to cache handler */
    extern int excCacheVecSize;

    /* Load cache exception vector and invalidate instruction cache */

    bcopy ((const char *) excCacheVec, (char *) vecAdrs, excCacheVecSize);
    cacheTextUpdate (vecAdrs, excCacheVecSize);
    }

#endif /* _WRS_R3K_EXC_SUPPORT */

/*******************************************************************************

*
* excVecInit - initialize the exception/interrupt vectors
*
* This routine sets up the MIPS exception vectors to point to the 
* appropriate default exception handlers.
*
* INTERNAL
* The common exception handler excStub() is found in excALib.s.
* 
* WHEN TO CALL
* This routine is usually called from the system start-up routine
* usrInit() in usrConfig.c, before interrupts are enabled.
*
* RETURNS: OK (always).
*
* SEE ALSO: excLib
*/

STATUS excVecInit (void)
    {
    extern int excNormVec[];	/* instructions for branch to normal handler */
    extern int excNormVecSize;
    extern int excTlbVec[];	/* instructions for branch to tlb handler */
    extern int excTlbVecSize;	/* instructions for branch to tlb handler */
#ifndef _WRS_R3K_EXC_SUPPORT
    extern int excXtlbVec[];	/* instructions for branch to xtlb handler */
    extern int excXtlbVecSize;	/* instructions for branch to xtlb handler */
    extern int excCacheVec[];	/* instructions for branch to cache handler */
    extern int excCacheVecSize;	/* instructions for branch to cache handler */
#endif /* _WRS_R3K_EXC_SUPPORT */
    ULONG srValue;		/* status register placeholder */

    /* If available, use BSP-provided initialization function */

    if (sysExcVecInitHook != NULL)
	{
	(*sysExcVecInitHook)();
	}
    else
	{
	/* Load normal vector and invalidate instruction cache */
	bcopy ((const char *)excNormVec, (char *) E_VEC, excNormVecSize);
	cacheTextUpdate ((void *) E_VEC, excNormVecSize);

    /* Load tlb vector and invalidate instruction cache */
#ifdef _WRS_R3K_EXC_SUPPORT
	bcopy ((const char *)excTlbVec, (char *) UT_VEC, excTlbVecSize);
	cacheTextUpdate ((void *) UT_VEC, excTlbVecSize);
#else /* !_WRS_R3K_EXC_SUPPORT */
	bcopy ((const char *)excTlbVec, (char *) T_VEC, excTlbVecSize);
	cacheTextUpdate ((void *) T_VEC, excTlbVecSize);
#endif /* !_WRS_R3K_EXC_SUPPORT */

#ifndef _WRS_R3K_EXC_SUPPORT
	/* Load xtlb vector and invalidate instruction cache */
	bcopy ((const char *)excXtlbVec, (char *) X_VEC, excXtlbVecSize);
	cacheTextUpdate ((void *) X_VEC, excXtlbVecSize);
	/* Load cache exception vector and invalidate instruction cache */
	bcopy ((const char *)excCacheVec, (char *) C_VEC, excCacheVecSize);
	cacheTextUpdate ((void *) C_VEC, excCacheVecSize);
#endif /* _WRS_R3K_EXC_SUPPORT */
	}

    /* Make the vectors usable by turning off rom based vectors */

    srValue = intSRGet();
    srValue &= ~SR_BEV;
    intSRSet(srValue);

    return (OK);
    }
/*******************************************************************************
*
* excExcHandle - interrupt level handling of exceptions
*
* This routine handles exception traps. It is never be called except 
* from the special assembly language interrupt stub routine.
*
* It prints out a bunch of pertinent information about the trap that
* occurred via excTask.
*
* Note that this routine runs in the context of the task that got the exception.
*
* NOMANUAL
*/

void excExcHandle
    (
    int		vecNum,		/* exception vector number */
    ESFMIPS *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs 		/* pointer to general regs on esf */
    )
    {
    EXC_INFO	excInfo;
    int		esfSize;

#ifdef _WRS_R3K_EXC_SUPPORT
    /* restore old sr so it looks like an rfe occured thus allowing interrupts*/ 
    pEsf->esfRegs.sr = (pEsf->esfRegs.sr & ~(SR_KUP|SR_IEP|SR_KUC|SR_IEC)) |
		       ((pEsf->esfRegs.sr & 
			(SR_KUO|SR_IEO|SR_KUP|SR_IEP|SR_KUC|SR_IEC)) >> 2);
#else
    /* restore old sr so it looks like an eret occured */ 
    pEsf->esfRegs.sr &= ~SR_EXL;
#endif

    esfSize = excGetInfoFromESF (vecNum, pEsf, &excInfo);

    /* fix task stack pointer and registers */

    pRegs->sr    = pEsf->esfRegs.sr;

    if ((_func_excBaseHook != NULL) &&			/* user hook around? */
	((* _func_excBaseHook) (vecNum, pEsf, pRegs, &excInfo)))
	return;						/* user hook fixed it */

#ifdef WV_INSTRUMENTATION
    /* windview - level 3 event logging */
    EVT_CTX_1(EVENT_EXCEPTION, vecNum);
#endif /* WV_INSTRUMENTATION */

    if (INT_CONTEXT ())
	{
	if (_func_excPanicHook != NULL)			/* panic hook? */
	    (*_func_excPanicHook) (vecNum, pEsf, pRegs, &excInfo);

	reboot (BOOT_WARM_AUTOBOOT);
	return;						/* reboot returns?! */
	}

    /* task caused exception */

    taskIdCurrent->pExcRegSet = pRegs;			/* for taskRegs[GS]et */

    taskIdDefault ((int)taskIdCurrent);			/* update default tid */

    bcopy ((char *) &excInfo, (char *) &(taskIdCurrent->excInfo),
	   sizeof (EXC_INFO));				/* copy in exc info */

    if (_func_sigExcKill != NULL)
	_func_sigExcKill((int) vecNum, vecNum, pRegs);

    if (_func_excInfoShow != NULL)			/* default show rtn? */
	(*_func_excInfoShow) (&excInfo, TRUE);

    if (excExcepHook != NULL)
	(* excExcepHook) (taskIdCurrent, vecNum, pEsf);

    taskSuspend (0);					/* whoa partner... */

    taskIdCurrent->pExcRegSet = (REG_SET *) NULL;	/* invalid after rts */
    }

/*****************************************************************************
*
* excBreakTypeGet - Get break type number from break instruction.
*
* RETURNS: break instruction type
*/
uint16_t excBreakTypeGet
    (
    ESFMIPS *pEsf	/* pointer to Exception Stack Frame */
    )
    {
    uint32_t epc;       /* Exception Program Counter Register */
    uint32_t *pInst32;  /* epc typed as a pointer to a 32-bit instruction */
#ifdef _WRS_MIPS16
    uint16_t *pInst16;  /* epc typed as a pointer to a 16-bit instruction */
#endif
    uint16_t breakType; /* returned break type */
    
    epc = (uint32_t) pEsf->esfRegs.pc;

    /*
     * Determine type of BREAK exception by examining the BREAK instruction.
     * If the breaked instruction is a branch delay slot, then the pc is the
     * address of the preceding jump or branch instruction. In this case, the
     * instruction at pc + 1 must be examined.
     *
     * For MIPS16 CPU, check the EPC for 16-bit ISA Mode, and retrieve the
     * break exception type from the 16-bit break instruction. In this case,
     * there is no branch delay slot.
     */

#ifdef _WRS_MIPS16

    /* If executing in 16-bit instruction mode then decode 16-bit break
     * instruction. Else decode 32-bit break instruction.
     */
    if (epc & EPC_EIM)
	{
	/* Executing in 16-bit instruction mode on a MIPS16.
	 * There is no branch delay slot in 16-bit ISA mode.
	 */
	pInst16 = (uint16_t *) (epc & EPC_PC);
	breakType = (*pInst16 & BREAK16_CODE_MASK) >> BREAK16_CODE_POS;
	}
    else 
	{ /* Executing in 32-bit instruction mode on a MIPS16*/
	pInst32 = (uint32_t *) epc;
	if (pEsf->cause & CAUSE_BD)		/* Branch Delay Slot */
	    pInst32++;
	
	breakType = (uint16_t) ((*pInst32 & BREAK_CODE_MASK) >> BREAK_CODE_POS);
	}
    
#else /* !_WRS_MIPS16 */
    
    pInst32 = (uint32_t *) epc;
    if (pEsf->cause & CAUSE_BD)		/* Branch Delay Slot */
	pInst32++;
    
    breakType = (uint16_t) ((*pInst32 & BREAK_CODE_MASK) >> BREAK_CODE_POS);
    
#endif /* _WRS_MIPS16 */

    return (breakType);
    }

/*******************************************************************************
*
* excIntHandle - interrupt level handling of interrupts
*
* This routine handles interrupts. It is never be called except 
* from the special assembly language interrupt stub routine.
*
* It prints out a bunch of pertinent information about the trap that
* occurred via excTask.
*/

LOCAL void excIntHandle
    (
    int		vecNum,		/* exception vector number */
    ESFMIPS *	pEsf 		/* pointer to exception stack frame */
    )
    {
    USHORT eid = 0;	/* clear data bus interrupt */
    int result;		/* unacked ints return value */

#ifdef WV_INSTRUMENTATION

    /* windview - level 3 event logging */
    EVT_CTX_1(EVENT_EXCEPTION, vecNum);

#endif /* WV_INSTRUMENTATION */

    if ((vecNum <= HIGH_VEC) && (vecNum >= LOW_VEC))
	{
	result = sysAutoAck(vecNum);	/* clear interrupt condition */

        if (vecNum == IV_BUS_ERROR_VEC)
	    eid = (USHORT) result;	/* result of data bus interrupt */
    
        if ((vecNum <= IV_FPA_PREC_VEC) && (vecNum >= IV_FPA_UNIMP_VEC))
            pEsf->fpcsr = result;	/* result of fpa interrupt */
	}

    if (_func_excIntHook != NULL)
	(*_func_excIntHook) (vecNum, pEsf, eid);
    }
/*****************************************************************************
*
* excGetInfoFromESF - get relevent info from exception stack frame
*
* RETURNS: size of specified ESF
*/

LOCAL int excGetInfoFromESF
    (
    FAST int vecNum,
    FAST ESFMIPS *pEsf,
    EXC_INFO *pExcInfo 
    )
    {
    pExcInfo->vecNum = vecNum;
    pExcInfo->valid  = EXC_VEC_NUM;

    if (( vecNum == IV_TLBMOD_VEC ) || (vecNum == IV_TLBL_VEC ) ||
        (vecNum == IV_TLBS_VEC ) || (vecNum == IV_ADEL_VEC ) ||
        (vecNum == IV_ADES_VEC ))
        {
	/* Its an address error , or tlb miss */

	pExcInfo->valid     |= EXC_EPC | EXC_STATUS_REG | EXC_ACCESS_ADDR |
			       EXC_CAUSE_REG ;
	pExcInfo->epc        = ((ESFMIPS *)pEsf)->esfRegs.pc;
	pExcInfo->statusReg  = ((ESFMIPS *)pEsf)->esfRegs.sr;
	pExcInfo->causeReg   = ((ESFMIPS *)pEsf)->cause;
	pExcInfo->badVa      = ((ESFMIPS *)pEsf)->badva;

	return (sizeof (ESFMIPS));
	}
    else if ( (vecNum == IV_IBUS_VEC ) || (vecNum == IV_DBUS_VEC ))
        {
	/* Its a bus error */

	pExcInfo->valid     |= EXC_EPC | EXC_STATUS_REG | 
			       EXC_CAUSE_REG | EXC_ERROR_ADDR ;

	pExcInfo->epc        = ((ESFMIPS *)pEsf)->esfRegs.pc;
	pExcInfo->statusReg  = ((ESFMIPS *)pEsf)->esfRegs.sr;
	pExcInfo->causeReg   = ((ESFMIPS *)pEsf)->cause;
	pExcInfo->ear        = sysBusEar();
	pExcInfo->eid        = sysBusEid();

	return (sizeof (ESFMIPS));
	}
    else if ((vecNum <= IV_FPA_PREC_VEC) && (vecNum >= IV_FPA_UNIMP_VEC))
        {
	/* Its a floating point error */

	pExcInfo->valid     |= EXC_EPC | EXC_STATUS_REG |
			       EXC_CAUSE_REG | EXC_FP_STATUS_REG ;
	pExcInfo->epc        = ((ESFMIPS *)pEsf)->esfRegs.pc;
	pExcInfo->statusReg  = ((ESFMIPS *)pEsf)->esfRegs.sr;
	pExcInfo->causeReg   = ((ESFMIPS *)pEsf)->cause;
	pExcInfo->fpcsr      = ((ESFMIPS *)pEsf)->fpcsr;

	return (sizeof (ESFMIPS));
	}
#ifdef EXC_BREAK_TYPE    
    else if (vecNum == IV_BP_VEC)
	{
	pExcInfo->valid    |= EXC_EPC | EXC_STATUS_REG | EXC_CAUSE_REG
	                      | EXC_BREAK_TYPE;
	pExcInfo->epc       = ((ESFMIPS *)pEsf)->esfRegs.pc;
	pExcInfo->statusReg = ((ESFMIPS *)pEsf)->esfRegs.sr;
	pExcInfo->causeReg  = ((ESFMIPS *)pEsf)->cause;
	pExcInfo->breakType = excBreakTypeGet(pEsf);

	return (sizeof (ESFMIPS));
	}
#endif
    else
	{
	pExcInfo->valid    |= EXC_EPC | EXC_STATUS_REG | EXC_CAUSE_REG;
	pExcInfo->epc       = ((ESFMIPS *)pEsf)->esfRegs.pc;
	pExcInfo->statusReg = ((ESFMIPS *)pEsf)->esfRegs.sr;
	pExcInfo->causeReg  = ((ESFMIPS *)pEsf)->cause;

	return (sizeof (ESFMIPS));
	}
    }

#if 0
/*******************************************************************************
*
* programError - determine if exception is program error
*
* RETURNS:
*   TRUE if exception indicates program error,
*   FALSE if hardware interrupt or failure.
*/

LOCAL BOOL programError
    (
    int vecNum 		/* exception vector number */
    )
    {
    return (((vecNum < USER_VEC_START) && 
            ((vecNum != IV_SYSCALL_VEC) && (vecNum != IV_BP_VEC))) || 
             (vecNum == IV_BUS_ERROR_VEC) ); 
    }
#endif
