/* excArchShow.c - PowerPC exception show facilities */

/* Copyright 1984-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01w,13aug03,mil  Added machine check related info.
01v,22nov02,mil  Updated support for PPC85XX.
01u,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
01t,16may02,mil  Added _EXC_OFF_THERMAL for PPC604 (SPR #77552).
01s,19apr02,jtp  Correct display of excMsgTbl[] for PPC440
01r,30oct01,pch  Fix spelling errors in reports
01q,16aug01,pch  Add support for PPC440
01p,14jun01,kab  Fixed Altivec Unavailable Exchandler, SPR 68206
01o,30nov00,s_m  added showing of BEAR for 405
01n,25oct00,s_m  renamed PPC405 cpu types
01m,13oct00,sm   modified machine check handling for PPC405
01l,06oct00,sm   PPC405 support
01k,12aug99,zl   added PowerPC 509 and PowerPC 555 support.
01j,18aug98,tpr  added PowerPC EC 603 support.
01i,24feb97,tam  added support for 403GC/GCX exceptions.
01h,10feb97,tam  added support to handle floating point exceptions (SPR #7840).
01g,24may96,tpr  added PowerPC 860 support.
01f,15mar96,tam  added PPC403 support.
01e,23feb96,tpr  cleaned up.
01d,14feb96,tpr  split PPC603 and PPC604.
01c,03oct95,tpr  changed %d to 0x%x in excInfoShow().
01b,03mar95,yao  added NIA message.  added modification history.
01a,xxxxxxx,yao  created.
*/

/*
This module contains PowerPC architecture dependent portions of the
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
#include "stdio.h"
#include "fioLib.h"
#include "vxLib.h"
#include "private/funcBindP.h"
#ifdef _WRS_ALTIVEC_SUPPORT
#include "altivecLib.h"
#endif /* _WRS_ALTIVEC_SUPPORT */

typedef struct {
    int		excVec;		/* exception vector */
    char * 	excMsg;		/* exception message */
    } EXC_MSG_TBL;

/* locals */

/* 
 * Exception error messages.  These are used by the exception printing routine.
 * Exception numbers are the same as used by the CPU
 */

LOCAL EXC_MSG_TBL excMsgTbl [] = {
#if  ((CPU==PPC403) || (CPU == PPC405) || (CPU == PPC405F) || \
      (CPU == PPC440) || (CPU == PPC85XX))

# ifdef	   _EXC_OFF_CRTL
	  {_EXC_OFF_CRTL, "critical interrupt"},
# endif	/* _EXC_OFF_CRTL */

# ifdef	   _EXC_OFF_MACH
	  {_EXC_OFF_MACH, "machine check"},
# endif	/* _EXC_OFF_MACH */

# ifdef	   _EXC_OFF_DATA
	  {_EXC_OFF_DATA, "data storage"},
# endif	/* _EXC_OFF_DATA */

# ifdef	   _EXC_OFF_PROT
	  {_EXC_OFF_PROT, "protection violation/data access"},
# endif	/* _EXC_OFF_PROT */

# ifdef	   _EXC_OFF_INST
	  {_EXC_OFF_INST, "instruction access"},
# endif	/* _EXC_OFF_INST */

# ifdef	   _EXC_OFF_INTR
	  {_EXC_OFF_INTR, "external interrupt"},
# endif	/* _EXC_OFF_INTR */

# ifdef	   _EXC_OFF_ALIGN
	  {_EXC_OFF_ALIGN, "alignment"},
# endif	/* _EXC_OFF_ALIGN */

# ifdef	   _EXC_OFF_PROG
	  {_EXC_OFF_PROG, "program"},
# endif	/* _EXC_OFF_PROG */

# ifdef	   _EXC_OFF_FPU
	  {_EXC_OFF_FPU, "fp unavailable"},
# endif	/* _EXC_OFF_FPU */

# ifdef	   _EXC_OFF_SYSCALL
	  {_EXC_OFF_SYSCALL, "system call"},
# endif	/* _EXC_OFF_SYSCALL */

# ifdef	   _EXC_OFF_APU
	  {_EXC_OFF_APU, "auxiliary processor unavailable"},
# endif	/* _EXC_OFF_APU */

# ifdef	   _EXC_OFF_DECR
	  {_EXC_OFF_DECR, "decrementer"},
# endif	/* _EXC_OFF_DECR */

# ifdef	   _EXC_OFF_PIT
	  {_EXC_OFF_PIT, "programmable interval timer"},
# endif	/* _EXC_OFF_PIT */

# ifdef	   _EXC_OFF_FIT
	  {_EXC_OFF_FIT, "fixed interval timer"},
# endif	/* _EXC_OFF_FIT */

# ifdef	   _EXC_OFF_WD
	  {_EXC_OFF_WD, "watchdog timer"},
# endif	/* _EXC_OFF_WD */

# ifdef	   _EXC_OFF_DATA_MISS
	  {_EXC_OFF_DATA_MISS, "data translation miss"},
# endif	/* _EXC_OFF_DATA_MISS */

# ifdef	   _EXC_OFF_INST_MISS
	  {_EXC_OFF_INST_MISS, "instruction translation miss"},
# endif	/* _EXC_OFF_INST_MISS */

# ifdef	   _EXC_OFF_DBG
	  {_EXC_OFF_DBG, "debug exception"},
# endif	/* _EXC_OFF_DBG */

# ifdef	   _EXC_OFF_SPE
	  {_EXC_OFF_SPE, "SPE unavailable exception"},
# endif	/* _EXC_OFF_SPE */

# ifdef	   _EXC_OFF_VEC_DATA
	  {_EXC_OFF_VEC_DATA, "SPE vector data exception"},
# endif	/* _EXC_OFF_VEC_DATA */

# ifdef	   _EXC_OFF_VEC_RND
	  {_EXC_OFF_VEC_RND, "SPE vector rounding exception"},
# endif	/* _EXC_OFF_VEC_RND */

# ifdef	   _EXC_OFF_PERF_MON
	  {_EXC_OFF_PERF_MON, "Performance monitor exception"},
# endif	/* _EXC_OFF_PERF_MON */

#endif	/* CPU==PPC4xx, PPC85XX */

#if	(CPU == PPC509) 
    {_EXC_OFF_RESET, "system reset"},
    {_EXC_OFF_MACH, "machine check"},
    {_EXC_OFF_INTR, "external interrupt"},
    {_EXC_OFF_ALIGN, "alignment"},
    {_EXC_OFF_PROG, "program"},
    {_EXC_OFF_FPU, "fp unavailable"},
    {_EXC_OFF_DECR, "decrementer"},
    {_EXC_OFF_SYSCALL, "system call"},
    {_EXC_OFF_TRACE, "trace"},
    {_EXC_OFF_FPA, "floating point assist"},
    {_EXC_OFF_SW_EMUL, "Implementation Dependent Software Emulation"},
    {_EXC_OFF_DATA_BKPT, "Implementation Dependent Data Breakpoint "},
    {_EXC_OFF_INST_BKPT, "Implementation Dependent Instruction Breakpoint"},
    {_EXC_OFF_PERI_BKPT, "Implementation Dependent Peripheral Breakpoint"},
    {_EXC_OFF_NM_DEV_PORT, "Implementation Dependent Non Maskable Development Port"},
#endif	/* (CPU == PPC509) */

#if	(CPU == PPC555) 
    {_EXC_OFF_RESET, "system reset"},
    {_EXC_OFF_MACH, "machine check"},
    {_EXC_OFF_INTR, "external interrupt"},
    {_EXC_OFF_ALIGN, "alignment"},
    {_EXC_OFF_PROG, "program"},
    {_EXC_OFF_FPU, "fp unavailable"},
    {_EXC_OFF_DECR, "decrementer"},
    {_EXC_OFF_SYSCALL, "system call"},
    {_EXC_OFF_TRACE, "trace"},
    {_EXC_OFF_FPA, "floating point assist"},
    {_EXC_OFF_SW_EMUL, "Implementation Dependent Software Emulation"},
    {_EXC_OFF_IPE, "Implementation Dependent Instruction Protection Error"},
    {_EXC_OFF_DPE, "Implementation Dependent Data Protection Error"},
    {_EXC_OFF_DATA_BKPT, "Implementation Dependent Data Breakpoint "},
    {_EXC_OFF_INST_BKPT, "Implementation Dependent Instruction Breakpoint"},
    {_EXC_OFF_PERI_BKPT, "Implementation Dependent Peripheral Breakpoint"},
    {_EXC_OFF_NM_DEV_PORT, "Implementation Dependent Non Maskable Development Port"},
#endif	/* (CPU == PPC555) */

#if	(CPU==PPC601)
    {_EXC_OFF_RESET, "system reset"},
    {_EXC_OFF_MACH, "machine check"},
    {_EXC_OFF_DATA, "data access"},
    {_EXC_OFF_INST, "instruction access"},
    {_EXC_OFF_INTR, "external interrupt"},
    {_EXC_OFF_ALIGN, "alignment"},
    {_EXC_OFF_PROG, "program"},
    {_EXC_OFF_FPU, "fpu unavailable"},
    {_EXC_OFF_DECR, "decrementer"},
    {_EXC_OFF_SYSCALL, "system call"},
    {_EXC_OFF_IOERR, "io controller interface error"},
    {_EXC_OFF_RUN_TRACE, "run mode/trace"},
#endif	/* (CPU==PPC601) */

#if	((CPU == PPC603) || (CPU == PPCEC603))
    {_EXC_OFF_RESET, "system reset"},
    {_EXC_OFF_MACH, "machine check"},
    {_EXC_OFF_DATA, "data access"},
    {_EXC_OFF_INST, "instruction access"},
    {_EXC_OFF_INTR, "external interrupt"},
    {_EXC_OFF_ALIGN, "alignment"},
    {_EXC_OFF_PROG, "program"},
    {_EXC_OFF_FPU, "fp unavailable"},
    {_EXC_OFF_DECR, "decrementer"},
    {_EXC_OFF_SYSCALL, "system call"},
    {_EXC_OFF_TRACE, "trace"},
    {_EXC_OFF_INST_MISS, "instruction translation miss"},
    {_EXC_OFF_LOAD_MISS, "data load translation miss"},
    {_EXC_OFF_STORE_MISS, "data store translation miss"},
    {_EXC_OFF_INST_BRK, "instruction address breakpoint exception"},
    {_EXC_OFF_SYS_MNG, "system management interrupt"},
#endif	/* ((CPU == PPC603) || (CPU == PPCEC6030)) */

#if	(CPU == PPC604) 
    {_EXC_OFF_RESET, "system reset"},
    {_EXC_OFF_MACH, "machine check"},
    {_EXC_OFF_DATA, "data access"},
    {_EXC_OFF_INST, "instruction access"},
    {_EXC_OFF_INTR, "external interrupt"},
    {_EXC_OFF_ALIGN, "alignment"},
    {_EXC_OFF_PROG, "program"},
    {_EXC_OFF_FPU, "fp unavailable"},
    {_EXC_OFF_DECR, "decrementer"},
    {_EXC_OFF_SYSCALL, "system call"},
    {_EXC_OFF_TRACE, "trace"},
    {_EXC_OFF_PERF, "performance monitoring"},
# ifdef _WRS_ALTIVEC_SUPPORT
    {_EXC_ALTIVEC_UNAVAILABLE, "AltiVec unavailable"},
    {_EXC_ALTIVEC_ASSIST, "AltiVec assist"},
# endif /* _WRS_ALTIVEC_SUPPORT */
    {_EXC_OFF_INST_BRK, "instruction address breakpoint exception"},
    {_EXC_OFF_SYS_MNG, "system management interrupt"},
    {_EXC_OFF_THERMAL, "thermal"},
#endif	/* (CPU == PPC604) */

#if	(CPU == PPC860) 
    {_EXC_OFF_RESET, "system reset"},
    {_EXC_OFF_MACH, "machine check"},
    {_EXC_OFF_DATA, "data access"},
    {_EXC_OFF_INST, "instruction access"},
    {_EXC_OFF_INTR, "external interrupt"},
    {_EXC_OFF_ALIGN, "alignment"},
    {_EXC_OFF_PROG, "program"},
    {_EXC_OFF_FPU, "fp unavailable"},
    {_EXC_OFF_DECR, "decrementer"},
    {_EXC_OFF_SYSCALL, "system call"},
    {_EXC_OFF_TRACE, "trace"},
    {_EXC_OFF_SW_EMUL, "Implementation Dependent Software Emulation"},
    {_EXC_OFF_INST_MISS, "Implementation Dependent Instruction TLB Miss"},
    {_EXC_OFF_DATA_MISS, "Implementation Dependent Data TLB Miss"},
    {_EXC_OFF_INST_ERROR, "Implementation Dependent Instruction TLB Error"},
    {_EXC_OFF_DATA_ERROR, "Implementation Dependent Data TLB Error"},
    {_EXC_OFF_DATA_BKPT, "Implementation Dependent Data Breakpoint "},
    {_EXC_OFF_INST_BKPT, "Implementation Dependent Instruction Breakpoint"},
    {_EXC_OFF_PERI_BKPT, "Implementation Dependent Peripheral Breakpoint"},
    {_EXC_OFF_NM_DEV_PORT, "Implementation Dependent Non Maskable Development Port"},
#endif	/* (CPU == PPC860) */

    {0, NULL}
    };

#ifdef	_PPC_MSR_FP
/*
 * Floating Point Exception error messages. 
 * Exception numbers correspond to exception status bits in the FPSCR register. 
 */

EXC_MSG_TBL fpExcMsgTbl [] = {
    {_PPC_FPSCR_OX, "Floating point overflow"},
    {_PPC_FPSCR_UX, "Floating point underflow"},
    {_PPC_FPSCR_ZX, "Floating point divide by zero"},
    {_PPC_FPSCR_XX, "Floating point inexact"},
    {_PPC_FPSCR_VXSNAN, "Floating point invalid operation for SNAN"},
    {_PPC_FPSCR_VXISI, "Floating point invalid operation for INF - INF"},
    {_PPC_FPSCR_VXIDI, "Floating point invalid operation for INF / INF"},
    {_PPC_FPSCR_VXZDZ, "Floating point invalid operation for 0 / 0"},
    {_PPC_FPSCR_VXIMZ, "Floating point invalid operation for INF * 0"},
    {_PPC_FPSCR_VXVC, "Floating point invalid operation for invalide compare"},
    {_PPC_FPSCR_VXSOFT,"Floating point invalid operation for software request"},
    {_PPC_FPSCR_VXSQRT, "Floating point invalid operation for square root"},
    {_PPC_FPSCR_VXCVI, "Floating point invalid operation for interger convert"},
    {0, NULL}
    };
#endif  /* _PPC_MSR_FP */

/* forward declarations */

LOCAL void excInfoShow (EXC_INFO *pExcInfo, BOOL doBell);
/* XXX LOCAL void excIntInfoShow (int vecOff, ESFPPC *pEsf, USHORT eid); */
LOCAL void excPanicShow (int vecOff, ESFPPC *pEsf, REG_SET *pRegs,
			 EXC_INFO *pExcInfo);


/*******************************************************************************
*
* excShowInit - initialize exception show facility
*
* NOMANUAL
*/

STATUS excShowInit (void)
    {
    _func_excInfoShow	= (FUNCPTR) excInfoShow;
/* XXX    _func_excIntHook	= (FUNCPTR) excIntInfoShow; */
    _func_excPanicHook	= (FUNCPTR) excPanicShow;

    return (OK);
    }

#ifdef	_PPC_MSR_FP
/*******************************************************************************
*
* excFpCheck - check if a FP exception occured
*
* This routine verifies if a floating point exception happened and displays
* relevant exception messages according to the FPSCR status bits.
*
* RETURNS: FALSE or TRUE if a floating point exception did occured
*
* NOMANUAL
*/

LOCAL BOOL excFpCheck
    (
    UINT32 fpscrReg     /* Floating Point Status and Control register value */
    )
    {
    int ix = 0;
    UINT32 fpExc;

    fpExc = fpscrReg & _PPC_FPSCR_EXC_MASK;

    if (((fpscrReg & (_PPC_FPSCR_FX | _PPC_FPSCR_FEX | _PPC_FPSCR_VX)) == 0) ||
        (fpExc == 0))
        return (FALSE);

    /*
     * a floating point exception did occur: print messages according to 
     * FP exception types.
     */

    while (fpExcMsgTbl[ix].excMsg != NULL)
        {
        if ((fpExc & fpExcMsgTbl[ix].excVec) != 0)
            printExc ("\n%s", (int) fpExcMsgTbl[ix].excMsg, 0, 0, 0, 0);
        ix++;
        }
    printExc ("\n", 0, 0, 0, 0, 0);

    return (TRUE);
    }
#endif  /* _PPC_MSR_FP */

/*******************************************************************************
*
* excInfoShow - print exception info
*
* NOMANUAL
*/

LOCAL void excInfoShow 
    (
    EXC_INFO *	pExcInfo,
    BOOL	doBell
    )
    {
    FAST int valid  = pExcInfo->valid;
    FAST int vecOff = pExcInfo->vecOff;
    FAST int ix;

#ifdef 	_PPC_MSR_FP
    /* extra processing for hardware floating point exceptions */

    if ((vecOff == _EXC_OFF_PROG) 			/* Program Excep. ? */
# ifdef	_EXC_PROG_SRR1_FPU
	&& ((pExcInfo->msr & _EXC_PROG_SRR1_FPU) == _EXC_PROG_SRR1_FPU)
# endif	/* _EXC_PROG_SRR1_FPU */
	&& excFpCheck (pExcInfo->fpcsr)			/* FP exc. conditions */
	&& ((vxMsrGet() & _PPC_MSR_FP) != 0) 		/* MSR[FP] is set ? */
	&& ((taskIdCurrent->options & VX_FP_TASK) != 0))
        {
        /* a floating point exception did occur: display FPSCR */

        valid |= _EXC_INFO_FPCSR;
        }
    else			/* MMM: should this else be here? */
#endif  /* _PPC_MSR_FP */
    	if (valid & _EXC_INFO_VEC)
	    {
    	    /* print each piece of info if valid */

	    for (ix = 0; excMsgTbl[ix].excVec != vecOff; ix ++)
	    	{
	    	if (excMsgTbl[ix].excMsg == NULL)
	            break;
	    	}
	    if (excMsgTbl[ix].excMsg != NULL)
	    	printExc ("\n%s\n", (int) excMsgTbl[ix].excMsg, 0, 0, 0, 0);	
	    else
	    	printExc ("\nTrap to uninitialized vector number 0x%x.\n",
		          vecOff, 0, 0, 0, 0);
	    }

    if (valid & _EXC_INFO_CIA)
	printExc ("Exception current instruction address: 0x%08x\n", 
		  (int) pExcInfo->cia, 0, 0, 0, 0);

    if (valid & _EXC_INFO_NIA)
	printExc ("Exception next instruction address: 0x%08x\n", 
		  (int) pExcInfo->cia, 0, 0, 0, 0);

    if (valid & _EXC_INFO_MSR)
	printExc ("Machine Status Register: 0x%08x\n", 
		  (int) pExcInfo->msr, 0, 0, 0, 0);

#ifdef	_EXC_INFO_DAR
    if (valid & _EXC_INFO_DAR)
        printExc ("Data Access Register: 0x%08x\n", 
		  (int) pExcInfo->dar, 0, 0, 0, 0);
#endif	/* _EXC_INFO_DAR */

#ifdef	_EXC_INFO_DEAR
    if (valid & _EXC_INFO_DEAR)
        printExc ("Data Exception Address Register: 0x%08x\n", 
		  (int) pExcInfo->dear, 0, 0, 0, 0);
#endif	/* _EXC_INFO_DEAR */

    if (valid & _EXC_INFO_XER)
        printExc ("Fixed Point Register: 0x%08x\n", 
		  (int) pExcInfo->xer, 0, 0, 0, 0);

    if (valid & _EXC_INFO_CR)
        printExc ("Condition Register: 0x%08x\n", 
		  (int) pExcInfo->cr, 0, 0, 0, 0);

#ifdef	_EXC_INFO_FPCSR
    if (valid & _EXC_INFO_FPCSR)
        printExc ("Fp Control and Status Register: 0x%08x\n", 
		  (int) pExcInfo->fpcsr, 0, 0, 0, 0);
#endif	/* _EXC_INFO_FPCSR */

#ifdef	_EXC_INFO_DSISR
    if (valid & _EXC_INFO_DSISR)
        printExc ("Data storage interrupt Register: 0x%08x\n", 
		  (int) pExcInfo->dsisr, 0, 0, 0, 0);
#endif	/* _EXC_INFO_DSISR */

#ifdef	_EXC_INFO_BEAR
    if (valid & _EXC_INFO_BEAR)
        printExc ("Bus Error Address Register: 0x%08x\n", 
		  (int) pExcInfo->bear, 0, 0, 0, 0);
#endif	/* _EXC_INFO_BEAR */

#ifdef	_EXC_INFO_BESR
    if (valid & _EXC_INFO_BESR)
        printExc ("Bus Error Syndrome Register: 0x%08x\n", 
		  (int) pExcInfo->besr, 0, 0, 0, 0);
#endif	/* _EXC_INFO_BESR */

#ifdef	_EXC_INFO_SPEFSCR
    if (valid & _EXC_INFO_SPEFSCR)
        printExc ("SPE Floating-point Status and Control Register: 0x%08x\n", 
		  (int) pExcInfo->spefscr, 0, 0, 0, 0);
#endif	/* _EXC_INFO_SPEFSCR */

#ifdef	_EXC_INFO_ESR
    if (valid & _EXC_INFO_ESR)
        printExc ("Exception Syndrome Register: 0x%08x\n", 
		  (int) pExcInfo->mcesr, 0, 0, 0, 0);
#endif	/* _EXC_INFO_ESR */

#ifdef	_EXC_INFO_MCSR
    if (valid & _EXC_INFO_MCSR)
        {
        printExc ("Machine Check Syndrome Register: 0x%08x\n", 
		  (int) pExcInfo->mcesr, 0, 0, 0, 0);
	/* print MCAR only if not caused by mchk input pin */
        if (((pExcInfo->mcesr) & 0x80000000) == 0)
            printExc ("Machine Check Address Register: 0x%08x\n", 
		      (int) pExcInfo->dear, 0, 0, 0, 0);
        }
#endif	/* _EXC_INFO_MCSR */

    if (doBell)
	printExc ("Task: %#x \"%s\"\007\n", (int)taskIdCurrent, 
		  (int)taskName ((int)taskIdCurrent), 0, 0, 0);
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
    int		vecOff,		/* exception vector number */
    ESFPPC *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* parsed exception information */
    )
    {
    printExc (" \nException at interrupt level:\n", 0, 0, 0, 0, 0);
    excInfoShow (pExcInfo, FALSE);	/* print the message into sysExcMsg */
    printExc ("Regs at 0x%x\n", (int) pRegs, 0, 0, 0, 0);
    }
