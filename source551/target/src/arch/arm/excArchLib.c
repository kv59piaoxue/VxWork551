/* excArchLib.c - ARM exception handling facilities */

/* Copyright 1996-1997 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01g,01nov01,t_m  change excExcepHook to a IMPORT to remove dup definition
01f,25jul01,scm  modify intialization to flush entire cache- visionProbe
                 requirement...
01e,25feb98,jgn  added declaration of excExcepHook to this file
		 for scalability (SPR #20625)
01d,27oct97,kkk  took out "***EOF***" line from end of file.
01c,16apr97,cdp  changed BTZ handling to make it easier to support Thumb;
		 added WindView support.
01b,03mar97,jpd  tidied comments/documentation.
01a,09may96,cdp  written.
*/

/*
This module contains ARM architecture dependent portions of the
exception handling facilities.  See excLib for the portions that are
architecture independent.

SEE ALSO: dbgLib, sigLib, intLib, "Debugging"
*/

#include "vxWorks.h"
#include "esf.h"
#include "iv.h"
#include "sysLib.h"
#include "intLib.h"
#include "taskLib.h"
#include "qLib.h"
#include "errno.h"
#include "string.h"
#include "fppLib.h"
#include "vxLib.h"
#include "logLib.h"
#include "rebootLib.h"
#include "dbgLib.h"
#include "cacheLib.h"
#include "private/funcBindP.h"
#include "private/kernelLibP.h"
#include "private/taskLibP.h"
#include "private/sigLibP.h"

#define TEST_SWI_HANDLER 0


/* externals */

/*
 * The following imports are assembler routines which are put directly on the
 * hardware vectors (well almost directly - each vector contains a
 * LDR PC,[PC,#thing] to cause the PC to branch to these routines)
 */

IMPORT void excEnterUndef (void);
IMPORT void excEnterSwi (void);
IMPORT void excEnterPrefetchAbort (void);
IMPORT void excEnterDataAbort (void);
IMPORT void intEnt (void);
IMPORT void armInitExceptionModes (void);


/* globals */

/*
 * The following function pointers are used by the interrupt stubs. After
 * the saving of relevant registers and stack switching has been done,
 * the stub eventually calls the function installed on one of these vectors.
 */

VOIDFUNCPTR _func_armIrqHandler;	/* IRQ handler */
VOIDFUNCPTR _func_excBreakpoint = NULL;	/* breakpoint handler */

IMPORT FUNCPTR excExcepHook;

/* local definitions */

typedef struct excTbl
    {
    UINT32	vecAddr;	/* vector address */
    VOIDFUNCPTR fn;		/* exception entry veneer */
    } EXC_TBL;

#define NUM_EXC_VECS 5
#define NUM_CHANGEABLE_EXC_VECS	5


/*
 * EXC_VEC_TABLE_BASE is the address of the table of addresses loaded
 * by LDR PC,<> instructions stored in the hardware exception vectors
 */

#define EXC_VEC_TABLE_BASE 0x100


/* forward functions */

void excIntHandle (void);
void excExcHandle (ESF *, REG_SET *);
#if	TEST_SWI_HANDLER
void excExcHandleSwi (ESF *, REG_SET *);
#endif	/* TEST_SWI_HANDLER */
LOCAL void excGetInfoFromESF (int, FAST ESF *, REG_SET *, EXC_INFO *);


/* local variables */

/*
 * excEnterTbl is a table of vector addresses and routines which should
 * be installed. See excVecInit for more details.
 */

LOCAL EXC_TBL excEnterTbl[NUM_EXC_VECS] =
    {
	/* no entry for branch through zero */
	{ EXC_OFF_UNDEF,	excEnterUndef},		/* undefined instr */
	{ EXC_OFF_SWI,		excEnterSwi},		/* software interrupt */
	{ EXC_OFF_PREFETCH, 	excEnterPrefetchAbort},	/* prefetch abort */
	{ EXC_OFF_DATA, 	excEnterDataAbort},	/* data abort */
	/* no entry for old address exception */
	{ EXC_OFF_IRQ,		intEnt},		/* interrupt request */
	/* no entry for FIQ */
    };

#define FIRST_VECTOR	EXC_OFF_UNDEF


/*
 * excHandlerTbl is a table of handlers to be called from the exception stubs
 * NOTE: this table MUST be initialised such that the index into the
 * table for a particular exception is equal to the address of that
 * exception's vector >> 2.
 */

LOCAL EXC_TBL excHandlerTbl[NUM_CHANGEABLE_EXC_VECS] =
    {
	{ EXC_OFF_RESET,	excExcHandle},	/* reset */
	{ EXC_OFF_UNDEF,	excExcHandle},	/* undefined instruction */
#if	TEST_SWI_HANDLER
	{ EXC_OFF_SWI,		excExcHandleSwi},	/* software interrupt */
#else	/* TEST_SWI_HANDLER */
	{ EXC_OFF_SWI,		excExcHandle},	/* software interrupt */
#endif	/* TEST_SWI_HANDLER */
	{ EXC_OFF_PREFETCH,	excExcHandle},	/* prefetch abort */
	{ EXC_OFF_DATA,		excExcHandle},	/* data abort */
	/* no entry for old address exception */
	/* no entries for IRQ/FIQ */
    };

/*******************************************************************************
*
* excVecInit - initialize the exception/interrupt vectors
*
* This routine sets all exception vectors to point to the appropriate
* default exception handlers. All exception vectors are initialized to
* default handlers except 0x14 (Address) which is now reserved on the ARM
* and 0x1C (FIQ), which is not used by VxWorks.
*
* WHEN TO CALL
* This routine is usually called from the system start-up routine
* usrInit() in usrConfig, before interrupts are enabled.
*
* RETURNS: OK (always).
*/

STATUS excVecInit (void)
    {
    FAST int i;


    /* initialise ARM exception mode registers */

    armInitExceptionModes ();


    /* initialise hardware exception vectors */

    for (i = 0; i < NUM_EXC_VECS; ++i)
	{
	/*
	 * Each vector contains a LDR PC,[PC,#offset] instruction to
	 * load the PC from a table of addresses stored at
	 * EXC_VEC_TABLE_BASE. This allows full 32 bit addressing rather
	 * than 12 bit (MOV #) or 24 bit (B).
	 */
	*(UINT32 *)excEnterTbl[i].vecAddr = 0xE59FF000 |
					(EXC_VEC_TABLE_BASE - 8 - FIRST_VECTOR);
	*(VOIDFUNCPTR *)
	    (excEnterTbl[i].vecAddr + EXC_VEC_TABLE_BASE - FIRST_VECTOR) =
							    excEnterTbl[i].fn;
	}


    /*
     * Branch through zero has to be handled differently if it is
     * possible for address 0 to be be branched to in ARM and Thumb
     * states (no LDR pc,[pc,#n] in Thumb state). The following
     * instruction, installed at address 0, will cause an undefined
     * instruction exception in both ARM and Thumb states.
     */

    *(UINT32 *)EXC_OFF_RESET = 0xE7FDDEFE;


    /* now sort out the instruction cache to reflect the changes */

#if (CPU==XSCALE)
    /*
     * any call to single-line cache-invalidate could corrupt the
     * the visionProbe debug session of the visionTools on XScale...
     */
    CACHE_TEXT_UPDATE(EXC_OFF_RESET, ENTIRE_CACHE);
#else
    CACHE_TEXT_UPDATE(EXC_OFF_RESET, EXC_OFF_IRQ + 4);
#endif


    /* install default IRQ handler */

    _func_armIrqHandler = excIntHandle;


    return OK;
    }

/*******************************************************************************
*
* excIntConnect - connect a C routine to an asynchronous exception vector
*
* This routine connects a specified C routine to a specified asynchronous 
* exception vector (IRQ). The address of <routine> is stored in a
* function pointer to be called by intEnt following an asynchronous
* exception.
*
* When the C routine is invoked the interrupt is still locked. It is the
* C routine responsibility to re-enable the interrupt.
*
* The routine can be any normal C code, except that it must not
* invoke certain operating system functions that may block or perform
* I/O operations
*
* NOTE:
* On the ARM, the address of <routine> is stored in a function pointer
* to be called by the stub installed on the IRQ exception vector
* following an asynchronous exception.  This routine is responsible for
* determining the interrupt source and despatching the correct handler
* for that source.
*
* Before calling the routine, the interrupt stub switches to SVC mode,
* changes to a separate interrupt stack and saves necessary registers. In
* the case of a nested interrupt, no SVC stack switch occurs.
*
* RETURNS: OK always.
* 
* SEE ALSO: excVecSet().
*/

STATUS excIntConnect
    (
    VOIDFUNCPTR * vector,		/* exception vector to attach to */
    VOIDFUNCPTR	  routine		/* routine to be called */
    )
    {
    if ((UINT32)vector != EXC_OFF_IRQ)
	return ERROR;

    _func_armIrqHandler = routine;
    return OK;
    }

#if	TEST_SWI_HANDLER
/*******************************************************************************
*
* excExcHandleSwi - SWI handler for test purposes only
*
* NOMANUAL
*/

void excExcHandleSwi
    (
    ESF *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    ++(pRegs->pc);	/* step over SWI instruction */
    ++(pRegs->r[0]);	/* increment r0 */
    }

#endif	/* TEST_SWI_HANDLER */

/*******************************************************************************
*
* excExcHandle - interrupt level handling of exceptions
*
* This routine handles exception traps.  It is never to be called except
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
    ESF *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    EXC_INFO excInfo;
    int vec = pEsf->vecAddr;		/* exception vector */

    excGetInfoFromESF (vec, pEsf, pRegs, &excInfo);	/* fill excInfo/pRegs */

    if ((_func_excBaseHook != NULL) && 			/* user hook around? */
	((* _func_excBaseHook) (vec, pEsf, pRegs, &excInfo)))
	return;						/* user hook fixed it */


#ifdef WV_INSTRUMENTATION
    /* windview - level 3 event logging */
    EVT_CTX_1(EVENT_EXCEPTION, vec);
#endif /* WV_INSTRUMENTATION */


    /* if exception occured in an isr or before multi tasking then reboot */

    if ((INT_CONTEXT ()) || (Q_FIRST (&activeQHead) == NULL))
	{
	if (_func_excPanicHook != NULL)			/* panic hook? */
	    (*_func_excPanicHook) (vec, pEsf, pRegs, &excInfo);

	reboot (BOOT_WARM_AUTOBOOT);
	return;						/* reboot returns?! */
	}

    /* task caused exception */

    taskIdCurrent->pExcRegSet = pRegs;			/* for taskRegs[GS]et */

    taskIdDefault ((int)taskIdCurrent);			/* update default tid */

    bcopy ((char *) &excInfo, (char *) &(taskIdCurrent->excInfo),
	   sizeof (EXC_INFO));				/* copy in exc info */

    if (_func_sigExcKill != NULL)			/* signals installed? */
	(*_func_sigExcKill) (vec, 0, pRegs);

    if (_func_excInfoShow != NULL)			/* default show rtn? */
	(*_func_excInfoShow) (&excInfo, TRUE);

    if (excExcepHook != NULL)				/* 5.0.2 hook? */
        (* excExcepHook) (taskIdCurrent, vec, pEsf);

    taskSuspend (0);					/* whoa partner... */

    taskIdCurrent->pExcRegSet = (REG_SET *) NULL;	/* invalid after rts */
    }

/*******************************************************************************
*
* excIntHandle - interrupt level handling of interrupts
*
* This routine handles interrupts.  It is never to be called except
* from the special assembly language interrupt stub routine.
*
* It prints out a bunch of pertinent information about the trap that
* occurred via excTask().
*
* NOMANUAL
*/

void excIntHandle ()
    {

#ifdef WV_INSTRUMENTATION
    /* windview - level 3 event logging */
    EVT_CTX_1(EVENT_EXCEPTION, EXC_OFF_IRQ);
#endif /* WV_INSTRUMENTATION */

    if (_func_excIntHook != NULL)
	(*_func_excIntHook) ();

    if (Q_FIRST (&activeQHead) == NULL)			/* pre kernel */
	reboot (BOOT_WARM_AUTOBOOT);			/* better reboot */
    }

/*****************************************************************************
*
* excGetInfoFromESF - get relevent info from exception stack frame
*
*/

LOCAL void excGetInfoFromESF
    (
    int		vec,		/* vector */
    FAST ESF *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* where to fill in exception info */
    )
    {
    pExcInfo->valid = EXC_INFO_VECADDR | EXC_INFO_PC | EXC_INFO_CPSR;
    pExcInfo->vecAddr = pEsf->vecAddr;
    pExcInfo->pc = pRegs->pc;
    pExcInfo->cpsr = pRegs->cpsr;

    switch (pEsf->vecAddr)
	{
	case EXC_OFF_RESET:	/* branch through zero */
	    pExcInfo->valid ^= EXC_INFO_PC;		/* PC not valid */
	    break;


	case EXC_OFF_UNDEF:	/* undefined instruction */
	case EXC_OFF_SWI:	/* software interrupt */
	case EXC_OFF_PREFETCH:	/* prefetch abort */
	    break;


	case EXC_OFF_DATA:	/* data abort */
	    /*
	     * note that registers may need unwinding if reexecution of
	     * the instruction is to be attempted after the cause of
	     * the abort has been fixed
	     */
	    break;


	default:		/* what else can there be? */
	    break;
	}
    }

/*******************************************************************************
*
* excExcContinue - continue low level handling of exception
*
* This routine is called from the excEnter stubs to pass control to
* the required exception handler.
*
* Note that this routine runs in the context of the task that got the exception.
*
* NOMANUAL
*/

void excExcContinue
    (
    ESF *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    EXC_INFO excInfo;
    FAST UINT32 vec = pEsf->vecAddr;	/* exception vector */

    /*
     * call exception handler for this exception
     * if exception occurred at address 0, we don't care what sort of
     * exception it was - it MUST be a branch-through-zero (EXC_OFF_RESET).
     */

    if (pRegs->pc == 0)
	vec = pEsf->vecAddr = EXC_OFF_RESET;


    switch (vec)
	{
	case EXC_OFF_RESET:	/* reset = branch through zero */
	case EXC_OFF_SWI:	/* software interrupt */
	case EXC_OFF_PREFETCH:	/* prefetch abort */
	case EXC_OFF_DATA:	/* data abort */
	    (excHandlerTbl[vec >> 2].fn) (pEsf, pRegs);
	    break;


	case EXC_OFF_UNDEF:	/* undefined instruction */
	    /*
	     * check explicitly for an undefined instruction exception
	     * caused by the undefined instruction we use as a breakpoint
	     * and invoke its handler directly. WDB and DBG both use this
	     * so only one can be installed at a time.
	     */

	    if (*(pRegs->pc) == DBG_BREAK_INST && _func_excBreakpoint != NULL)
		_func_excBreakpoint(pEsf, pRegs);
	    else
		(excHandlerTbl[vec >> 2].fn) (pEsf, pRegs);
	    break;


	default:		/* should not happen - reboot */
	    excGetInfoFromESF (vec, pEsf, pRegs, &excInfo);

	    if (_func_excPanicHook != NULL)		/* panic hook? */
		(*_func_excPanicHook) (vec, pEsf, pRegs, &excInfo);

	    reboot (BOOT_WARM_AUTOBOOT);
	    break;

	}
    }

/*******************************************************************************
*
* excVecSet - set an exception vector
*
* This routine specifies the C routine that will be called when the exception
* corresponding to <vector> occurs.  This routine does not create the
* exception stub; it simply replaces the C routine to be called in the
* exception stub.
*
* NOTE
* On the ARM, there is no excConnect() routine, unlike the PowerPC. The C
* routine is attached to a default stub using excVecSet().
*
*
* SEE ALSO: excVecGet()
*/

void excVecSet
    (
    FUNCPTR * vector,	/* exception vector */
    FUNCPTR function	/* routine to be called */
    )
    {
    FAST int i;


    /*
     * find entry in table for this exception
     * NOTE: -1 because we don't put IRQ through here and FIQ isn't
     * in the table
     */

    for (i = 0; i < NUM_CHANGEABLE_EXC_VECS; ++i)
	if (excHandlerTbl[i].vecAddr == (UINT32)vector)
	    break;

    if (i < NUM_CHANGEABLE_EXC_VECS)
	excHandlerTbl[i].fn = (VOIDFUNCPTR)function;	/* install handler */
    }


/*******************************************************************************
*
* excVecGet - get an exception vector
*
* This routine returns the address of the C routine currently connected to
* <vector>.
*
* SEE ALSO: excVecSet()
*/

FUNCPTR excVecGet
    (
    FUNCPTR * vector	/* exception vector */
    )
    {
    FAST int i;


    /*
     * find entry in table for this exception
     * NOTE: -1 because we don't put IRQ through here and FIQ isn't
     * in the table
     */

    for (i = 0; i < NUM_CHANGEABLE_EXC_VECS; ++i)
	if (excHandlerTbl[i].vecAddr == (UINT32)vector)
	    return (FUNCPTR)excHandlerTbl[i].fn;

    return NULL;
    }
