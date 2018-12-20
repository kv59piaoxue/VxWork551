/* intArchLib.c - interrupt architecture */

/* Copyright 1984-1998, Wind River Systems, Inc. */

/*
modification history
--------------------
01k,13nov98,cdp  moved intLock(), intUnlock() to intALib.s;
		 maintain count of interrupt demux errors.
01j,03sep98,cjtc conversion for WV20 - single step logging
01i,31jul98,pr   added WindView 2.0 support.
01h,21apr98,jpd  implemented intVecTableWriteProtect().
01g,20mar98,cdp  replaced logMsg call with _func_logMsg call (SPR #20625)
01f,25nov97,cdp  include arch/arm/intArmLib.h.
01e,28oct97,tam  logged <vector> (vector number) instead of <level> for Windview
01d,21oct97,tam  defined evtTimeStamp as a global and change
		 INCLUDE_INSTRUMENTATION to INCLUDE_INSTRUMENTATION.
01c,07aug97,cdp  rewritten for new interrupt structure (based on 01b template);
		 added selection of interrupt model at run time;
01b,03mar97,jpd  tidied comments/documentation. intEnable/Disable return int.
01a,09may96,cdp  written, based on 68K version.
*/

/*
This generic architecture library is intended for architectures similar
to 80X86, PPC, and ARM.  Each has just one or two interrupt input pins.  An
external interrupt control chip must handle the prioritization of interrupt
inputs and then present a single interrupt to the processor.

At this architecture level, the numbering of interrupt levels or vectors
is of no interest.  The interrupt controller chip will deal with level numbers.
Vector numbers are just indices into the vector handler array.  The maximum
number of vectors is set by the macro INT_NUM_VECTORS defined in the
architecture header files, or by the BSP.

This architecture model does not support the following routines:
  intVecSet()
  intVecGet()
  intHandlerCreate()

Two models for actual processing of interrupts are presented here.  The first
is a fully pre-emptable model.  This model calls the hardware device to get
the level and vector for the current interrupt request.  It then re-enables
the interrupt exception so that a higher level interrupt can preempt the
current interrupt.  When the current interrupt is finished, the interrupt
exception is turned off before exitting back to the exception handler level.
(See intIntRtn for more information).

The second model is a non preemptable one, but it may be faster.  In this
model we process one interrupt at a time until the interrupt controller
device says that no more are pending.  We do this one at a time
to minimize priority inversion.  Priority inversion occurs when the CPU
is processing a low priority interrupt and a higher priority interrupt is
made to wait until the low priority interrupt is finished.

The model is selected when the interrupt library is initialised.

This template was designed as the single interrupt handling library for
the complete system.  This may change in the future.  As multiple bus systems
predominate, interrupt systems may become bus related rather than cpu related.
That would require a change to an object model, with one interrupt controller
object per bus system.

At some future time it would be nice to add a model that allows Vectors to be
overloaded.  This would allow multiple service routines to be connected to
the same vector.  It would require the addition of an intDisconnect() routine
for proper interrupt routine management.

Another option to consider is the use of the lockLevel concept.  Lock levels
allow the user to specify what interrupt level is used for VxWorks kernel
protection.  Priority levels higher than the lock level are effectively
non-maskable interrupts (NMI) and are subject to all the restrictions applying
to NMIs.  If the architecture provides no other means for NMI processing, the
this module must implement user controllable lock levels.  If there is
some hardware mechanism for NMI outside the control of this module, then
the engineer can select INT_HDWE_LOCK_LEVEL which will modify this code
to use special architecture routines to turn on/off interrupt enable for
all external devices.  See the description of the macros CPU_INTERRUPT_ENABLE
and CPU_INTERRUPT_DISABLE.  If INT_HDWE_LOCK_LEVEL is not defined, this module
will call the BSP routine, sysIntLvlChgRtn, with the user supplied lockLevel
value to implement intLock() and intUnlock().

It is expected that the architecture engineer will select the models best
suited to the CPU.  When the final product is ready, code for
models not used should be removed.  The models presented here are options
for the architecture designer, not the end-user.  The end-user will receive
only the compiled binary object.  He does not have these choices available.

Because intLibInit needs the number of levels and number of vectors as
input, it must be called from BSP code at some time.  Usually this is part
of sysHwInit2().  The template implementation uses malloc() which is not
available for routines called from sysHwInit.  If the implementation is
changed to not use malloc, then the call to intLibInit() could be moved to
sysHwInit() instead.

If the designer wants the user to have control over options like MODEL_PREEMPT
and HDWE_LOCK_LEVEL then intLibInit should have a 3rd argument 'mode' which
the user will use to specify the desired operating mode.  Note that most
architectures don't give the end-user these types of decisions.  Doing so will
also increase code size over a system that doesn't have such options available.
*/

/* includes */

#include "vxWorks.h"
#include "stdlib.h"
#include "intLib.h"
#include "private/funcBindP.h"		/* for _func_logMsg */
#include "arch/arm/excArmLib.h"
#include "arch/arm/ivArm.h"
#include "arch/arm/intArmLib.h"
#include "private/vmLibP.h"
#ifdef	WV_INSTRUMENTATION
#include "private/eventP.h"
#endif	/* WV_INSTRUMENTATION */

/* defines */

typedef struct {	/* VEC_ENTRY */
    VOIDFUNCPTR	routine;
    ULONG	arg;
    } VEC_ENTRY;

#define INT_HDWE_LOCK_LEVEL


/* Connect the interupt handler to it's exception vector ? */

#define INTR_EXC_ID	(EXC_OFF_IRQ) /* exception id, for external interrupt */

#ifndef EXC_CONNECT_INTR_RTN
#   define EXC_CONNECT_INTR_RTN(rtn) \
	excIntConnect((VOIDFUNCPTR *)INTR_EXC_ID,rtn)
#endif

/* The default action for an uninitialized vector */

#ifndef UNINITIALIZED_VECTOR_RCVD
#   define UNINITIALIZED_VECTOR_RCVD(vector) \
	{ \
	if (_func_logMsg != NULL) \
	    _func_logMsg ("Uninitialized vector %d\n",vector,0,0,0,0,0); \
	}
#endif

/* For VxVMI, protect the vector table, if possible */

#ifndef INT_VEC_TBL_PROTECT
#   define INT_VEC_TBL_PROTECT 						   \
    { 									   \
    int pageSize; 							   \
    UINT vectorPage; 							   \
									   \
    if (!vmLibInfo.vmLibInstalled) 					   \
	{ 								   \
	errno = S_intLib_VEC_TABLE_WP_UNAVAILABLE; 			   \
	return (ERROR); 						   \
	} 								   \
									   \
    pageSize = VM_PAGE_SIZE_GET();					   \
									   \
    vectorPage = (UINT) intVecBaseGet () / pageSize * pageSize;		   \
									   \
    return (VM_STATE_SET (0, (void *) vectorPage, pageSize, 		   \
			  VM_STATE_MASK_WRITABLE, VM_STATE_WRITABLE_NOT)); \
    }
#endif

/* This sets the CPU interrupt enable on */

#ifndef CPU_INTERRUPT_ENABLE
#   define CPU_INTERRUPT_ENABLE intUnlock(0)
#endif

/* This resets the CPU interrupt enable */

#ifndef CPU_INTERRUPT_DISABLE
#   define CPU_INTERRUPT_DISABLE intLock()
#endif

/* This restores a previous interrupt enable state */

#ifndef CPU_INTERRUPT_RESTORE
#   define CPU_INTERRUPT_RESTORE(a) intUnlock(a)
#endif


/* global/local data */

UINT32	intDemuxErrorCount = 0;			/* count of spurious intrs */

LOCAL	VEC_ENTRY* intVecTable = NULL;
LOCAL	int	intLockLevel = 0;		/* lockLevel value */
LOCAL	int	intNumVectors = 0;		/* vectors allocated */
LOCAL	VOIDFUNCPTR intUserUninitRtn = NULL;	/* uninit. vector routine */
LOCAL	STATUS	dummy (void) { return ERROR; }	/* dummy, returns ERROR */
	FUNCPTR sysIntLvlVecChkRtn = dummy;	/* return vector and level */
	FUNCPTR sysIntLvlVecAckRtn = dummy;	/* ack vector and level */
	FUNCPTR sysIntLvlChgRtn = dummy;	/* change priority level */
	FUNCPTR sysIntLvlEnableRtn = dummy;	/* enable a single level */
	FUNCPTR sysIntLvlDisableRtn = dummy;	/* disable a single level */

/* forward declarations */

	void	intIntRtnPreempt (void);
	void	intIntRtnNonPreempt (void);
LOCAL	void	intUninitVec (int vector);

/*******************************************************************************
*
* intLibInit - initialize the generic architecture interrupt library
*
* Initialize the interrupt system.  This allocates the interrupt vector table
* and initializes all vectors to point to the uninitialized vector handler.
*
* RETURNS: OK or ERROR for invalid arguments or malloc failure.
*/

STATUS	intLibInit
    (
    int numLevels,	/* number of levels */
    int numVectors,	/* number of vectors */
    int mode		/* type of interrupt handling */
    )
    {
    int i;

    if (intVecTable == NULL)
	{

	/* Allocate and initialize the vector table */

	intVecTable = malloc (numVectors * sizeof (VEC_ENTRY));

	if (intVecTable != NULL)
	    {
	    intNumVectors = numVectors;

	    /* initialize table with uninitialized vec handler */

	    for (i = 0; i < numVectors; i++)
		{
		intConnect (INUM_TO_IVEC(i), NULL, 0);
		}

	    /* connect architecture interrupt exception */

	    if (mode & INT_PREEMPT_MODEL)
		EXC_CONNECT_INTR_RTN (intIntRtnPreempt);
	    else
		EXC_CONNECT_INTR_RTN (intIntRtnNonPreempt);

	    return OK;
	    }

	return ERROR;	/* malloc failure */
	}

    return OK;	/* already initialized */
    }

/*******************************************************************************
*
* intIntRtnPreempt - pre-emptive interrupt exception handler
*
* This routine is an interrupt exception handler.  It will normally be
* installed through the exception library.
*
* This handler is fully pre-emptive. In this model, high priority
* interrupts are enabled during the processing of low-priority
* interrupts.  Should a high priority interrupt occur, the low-priority
* handler is interrupted and the high priority hanlder takes over.  It
* will return to the low-priority handler when done.  This may not always
* be the most efficient method, but it always provides the least latency
* for high-priority interrupt handling.
*
* RETURNS:
*
* ARGSUSED
*/

void intIntRtnPreempt (void)
    {
    UINT32 level;
    UINT32 vector;
    VOIDFUNCPTR pRoutine;


    /* Get vector number, previous interrupt level */

    if ((*sysIntLvlVecChkRtn) (&level, &vector) == ERROR)
	{
	++intDemuxErrorCount;	/* update error count */
	return;
	}

#ifdef WV_INSTRUMENTATION
    /*
     * In the ARM architechture, exceptions cannot be locked out with intLock()
     * which makes a two-stage logging approach (i.e. timestamp saved in intEnt
     * and then used here) dangerous...it can lead to out-of sequence events
     * in the event log, thus confusing the parser. So we just use a single
     * stage logging here
     */

    WV_EVT_INT_ENT(vector)
#endif	/* WV_INSTRUMENTATION */

    /* enable additional CPU interrupts (only hi pri will get through) */

    CPU_INTERRUPT_ENABLE;

    /*
     * Use the vector number to locate and invoke the appropriate
     * vector routine
     */

    pRoutine = intVecTable[vector].routine;
    (*pRoutine)(intVecTable[vector].arg);

    /*
     * Return to the all interrupts disabled state
     * before exiting back to the exception handler
     */

    CPU_INTERRUPT_DISABLE;

    /* acknowledge interrupt, restore interrupt level */

    (*sysIntLvlVecAckRtn) (level, vector);
    }

/*******************************************************************************
*
* intIntRtnNonPreempt - non-pre-emptive interrupt exception handler
*
* This handler does not provide pre-emptive interrupts.  If a high
* priority interrupt occurs while a low priority interrupt is being
* handled, the high priority interrupt must wait for the low priority
* interrupt handler to finish.  As soon as the low-priority handler is
* done, the high priority handler will be invoked.  This model has less
* exception handling overhead of the fully pre-emptive model, but has a
* greater worst case latency for high priority interrupts.
*
* RETURNS:
*
* ARGSUSED
*/

void intIntRtnNonPreempt (void)
    {
    UINT32 level;
    UINT32 vector;
    VOIDFUNCPTR pRoutine;


    /* Get vector number, previous interrupt level */

    if ((*sysIntLvlVecChkRtn) (&level, &vector) == ERROR)
	{
	++intDemuxErrorCount;	/* update error count */
	return;
	}

    do
	{
	/* Loop until no more interrupts are found */

#ifdef WV_INSTRUMENTATION

	/*
	 * In the ARM architechture, exceptions cannot be locked out
	 * with intLock() which makes a two-stage logging approach (i.e.
	 * timestamp saved in intEnt and then used here) dangerous...it
	 * can lead to out-of sequence events in the event log, thus
	 * confusing the parser. So we just use a single stage logging
	 * here.
	 */

	WV_EVT_INT_ENT(vector)

#endif	/* WV_INSTRUMENTATION */

	/*
	 * Use the vector number to locate and invoke the appropriate
	 * vector routine
	 */

	pRoutine = intVecTable[vector].routine;
	(*pRoutine)(intVecTable[vector].arg);

	/* acknowledge the interrupt and restore interrupt level */

	(*sysIntLvlVecAckRtn) (level, vector);
	}
    while ((*sysIntLvlVecChkRtn) (&level, &vector) != ERROR);

    }

/*******************************************************************************
*
* intLevelSet - change current interrupt level
*
* Set the current interrupt level to the specified level.
*
* RETURNS:
* Previous interrupt level.
*/

int	intLevelSet
    (
    int level	/* new interrupt level value */
    )
    {
    return (*sysIntLvlChgRtn) (level);
    }

/*******************************************************************************
*
* intEnable - enable a specific interrupt level
*
* Enable a specific interrupt level.  For each interrupt level to be used,
* there must be a call to this routine before it will be
* allowed to interrupt.
*
* RETURNS:
* OK or ERROR for invalid arguments.
*/

STATUS	intEnable
    (
    int level	/* level to be enabled */
    )
    {
    return (*sysIntLvlEnableRtn) (level);
    }

/*******************************************************************************
*
* intDisable - disable a particular interrupt level
*
* This call disables a particular interrupt level, regardless of the current
* interrupt mask level.
*
* RETURNS:
* OK or ERROR for invalid arguments.
*/

STATUS	intDisable
    (
    int level	/* level to be disabled */
    )
    {
    return (*sysIntLvlDisableRtn) (level);
    }

/*******************************************************************************
*
* intConnect - connect user routine to an interrupt vector
*
* The user specified interrupt handling routine is connected to the specified
* vector.
*
* RETURNS: OK or ERROR for invalid arguments.
*/

STATUS	intConnect
    (
    VOIDFUNCPTR* vector,	/* vector id */
    VOIDFUNCPTR routine,	/* interrupt service routine */
    int argument		/* argument for isr */
    )
    {
    int vecNum;
    VEC_ENTRY *pVec;

    if (intVecTable == NULL)
	return ERROR;		/* library not initialized */

    vecNum = IVEC_TO_INUM (vector);

    /* check vector specified is in range allocated */

    if (vecNum < 0 || vecNum >= intNumVectors)
	return ERROR;

    pVec = &intVecTable[vecNum];

    if (routine == NULL)
	{
	routine = intUninitVec;
	argument = vecNum;
	}

    pVec->routine = routine;
    pVec->arg = argument;

    return OK;
    }

/*******************************************************************************
*
* intLockLevelSet - set the interrupt lock level
*
* This call establishes the interrupt level to be set when
* intLock() is called.
*
* RETURNS: N/A.
*/

void	intLockLevelSet
    (
    int newLevel	/* new lock level value */
    )
    {
    intLockLevel = newLevel;
    return;
    }

/*******************************************************************************
*
* intLockLevelGet - return current interrupt lock level
*
* The interrupt lock level is the interrupt level that is set by the
* intLock() command.  It is changeable by the intLockLevelSet() command.
*
* RETURNS:
* Returns the current interrupt lock level value. Returns ERROR if
* lockLevel is implemented in hardware and not in software.
*/

int	intLockLevelGet (void)
    {
#ifdef INT_HDWE_LOCK_LEVEL
    return ERROR;
#else
    return intLockLevel;
#endif
    }

/*******************************************************************************
*
* intVecTableWriteProtect - write protect the vector table
*
* This command is only supported with the VxVMI optional product.  Depending
* upon the architecture capabilities, this function may not be supported at
* all.
*
* RETURNS: OK or ERROR if function is not supported.
*/

STATUS	intVecTableWriteProtect (void)
    {
    INT_VEC_TBL_PROTECT;

    return OK;
    }

/*******************************************************************************
*
* intUninitVec - uninitialized vector handler
*
* This routine handles the uninitialized vectors.  It calls the user
* handler for uninitialized vectors, if one has been provided.
*
* RETURNS: N/A.
*/

LOCAL void intUninitVec
    (
    int vector		/* vector number */
    )
    {
    if (intUserUninitRtn != NULL)
	(*intUserUninitRtn) (vector);
    else
	{
	/* default uninitialized vector action */

	UNINITIALIZED_VECTOR_RCVD (vector);
	}
    }

/*******************************************************************************
*
* intUninitVecSet - set the uninitialized vector handler
*
* This routine installs a handler for the uninitialized vectors to be
* called when any uninitialized vector is entered.
*
* RETURNS: N/A.
*/

void intUninitVecSet
    (
    VOIDFUNCPTR routine	/* ptr to user routine */
    )
    {
    if (routine != NULL)
	intUserUninitRtn = routine;
    }

/*******************************************************************************
*
* intVecBaseSet - set the interrupt vector base
*
* RETURNS: N/A.
*/

void intVecBaseSet
    (
    FUNCPTR *base
    )
    {
    return; /* DUMMY ROUTINE */
    }

/*******************************************************************************
*
* intVecBaseGet - return the interrupt vector base
*
* RETURNS: pointer to beginning of vector table.
*/

FUNCPTR * intVecBaseGet (void)
    {
    return NULL; /* DUMMY ROUTINE */
    }

/******************************************************************************
*
* intRegsLock - modify a REG_SET to have interrupts locked.
*
* Note that this leaves the FIQ bit alone as FIQs are not handled by VxWorks.
*/

int intRegsLock
    (
    REG_SET *pRegs			/* register set to modify */
    )
    {
    UINT32 oldSr = pRegs->cpsr;
    pRegs->cpsr |= I_BIT;
    return oldSr;
    }

/******************************************************************************
*
* intRegsUnlock - restore a REG_SET's interrupt lockout level.
*
* Note that this leaves the FIQ bit alone as FIQs are not handled by VxWorks.
*/

void intRegsUnlock
    (
    REG_SET *	pRegs,			/* register set to modify */
    int		oldSr			/* sr with int lock level to restore */
    )
    {
    pRegs->cpsr = (pRegs->cpsr & ~I_BIT) | (oldSr & I_BIT);
    }
