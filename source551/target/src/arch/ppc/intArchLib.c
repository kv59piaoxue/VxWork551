/* intArchLib.c - PowerPC interrupt subroutine library */

/* Copyright 1984-1996 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01j,15aug01,pch  Change test for CPU==PPC4xx to ifdef _PPC_MSR_CE
01i,25oct00,s_m  renamed PPC405 cpu types
01h,07sep00,sm   modified intRegsLock and intRegsUnlock for PPC405 & PPC405F
01h,14dec00,pai  the intEnable() and intDisable() routines now return a value
                 (SPR #28548).
01g,20mar97,tam  added masking of the PPC403 MSR[CE] bit (SPR 8192). 
01f,09dec96,tpr  changed intEnable() and intDisable return value from void
		 to int to match Mips prototype.
01e,04mar96,tpr  added interrupt function hooks.
01d,21feb96,ms   fixed intRegsLock.
01c,29nov95,tpr  added intRegsLock() and intRegsUnlock().
01b,21nov94,yao  changed to call sysIntConnect() for intConnect().  
		 removed intHandlerCreate ().
01a,09sep94,yao  written.
*/

/*
This library provides various routines to manipulate and connect to
hardware interrupts and exceptions.  Any C language routine can be
connected to any exception, interrupt, or trap by calling intConnect().
Interrupt vectors can be accessed directly by the routines intVecSet() 
and intVecGet().  See also the routines provided in intALib and intLib.

INTERRUPT VECTORS AND NUMBERS
Some of the routines in this library take an interrupt vector as a
parameter, which is the byte offset into the vector table.
Macros are provided to convert between interrupt vectors and interrupt
numbers:
.iP IVEC_TO_INUM(intVector)
converts a vector to a number.
.iP INUM_TO_IVEC(intNumber)
converts a number to a vector.

EXAMPLE
To switch between one of several routines for a particular interrupt,
the following code fragment is one alternative.
.CS
    vector  = INUM_TO_IVEC(some_int_vec_num);
    oldfunc = intVecGet (vector);
    newfunc = intHandlerCreate (routine, parameter);
    intVecSet (vector, newfunc);
    ...
    intVecSet (vector, oldfunc);    /@ use original routine @/
    ...
    intVecSet (vector, newfunc);    /@ reconnect new routine @/
.CE

INCLUDE FILE: iv.h

SEE ALSO: intALib, intLib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "intLib.h"
#include "memLib.h"
#include "sysLib.h"
#include "private/taskLibP.h"


/* globals */

STATUS	  (* _func_intConnectRtn) (VOIDFUNCPTR *, VOIDFUNCPTR, int) = NULL;
void	  (* _func_intVecSetRtn) (FUNCPTR *, FUNCPTR ) = NULL;
FUNCPTR   (* _func_intVecGetRtn) (FUNCPTR *) = NULL;
void	  (* _func_intVecBaseSetRtn) (FUNCPTR *) = NULL;
FUNCPTR * (* _func_intVecBaseGetRtn) (void) = NULL;
int	  (* _func_intLevelSetRtn) (int) = NULL;
int	  (* _func_intEnableRtn) (int) = NULL;
int	  (* _func_intDisableRtn) (int) = NULL;

/*******************************************************************************
*
* intConnect - connect a C routine to a hardware interrupt
*
* This routine connects a specified C routine to a specified
* interrupt vector.  The address of <routine> is stored at <vector>
* so that the routine will be called with <parameter> when the interrupt
* occurs.  The routine will be invoked in supervisor mode at interrupt
* level.  A proper C environment will have been established,
* the necessary registers saved, and the stack set up.
*
* The routine can be any normal C code, except that it must not
* invoke certain operating system functions that may block or perform
* I/O operations.
*
* This routine simply calls intHandlerCreate() and intVecSet().
* The address of the handler returned by intHandlerCreate()
* is what actually gets put in the interrupt vector.
*
* RETURNS:
* OK, or ERROR if the interrupt handler cannot be built.
*
* SEE ALSO: intHandlerCreate(), intVecSet()
*/

STATUS intConnect 
    (
    VOIDFUNCPTR * vector,	/* interrupt vector to attach to     */
    VOIDFUNCPTR   routine,	/* routine to be called              */
    int           parameter	/* parameter to be passed to routine */
    )
    {
    if (_func_intConnectRtn == NULL)
	return (ERROR);

    return (_func_intConnectRtn (vector, routine, parameter));
    }

/******************************************************************************
*
* intVecSet - set a CPU vector
*
* This routine sets an exception/interrupt vector to a specified address.
* The vector is specified as an offset into the CPU's vector table.  On the
* MIPS R3000 CPU the vector table is set up statically in software.
*
* SEE ALSO: intVecGet()
*/

void intVecSet 
    (
    FUNCPTR * vector,		/* vector offset              */
    FUNCPTR   function		/* address to place in vector */
    )

    {
    if (_func_intVecSetRtn != NULL)
        _func_intVecSetRtn (vector, function);
    }

/*******************************************************************************
*
* intVecGet - get a CPU vector
*
* This routine returns the current value of a specified exception/interrupt
* vector.  The vector is specified as an offset into the CPU's vector table.
* For the PowerPC CPU the vector table is set up at the board level.
*
* RETURNS: The current value of the specified vector.
*
* SEE ALSO: intVecSet()
*/

FUNCPTR intVecGet 
    (
    FUNCPTR * vector 	/* vector offset */
    )
    {
    if (_func_intVecGetRtn == NULL)
	return (NULL);

    return (_func_intVecGetRtn (vector));
    }

/*******************************************************************************
*
* intVecBaseSet - set the interrupt vector base address
*
* This routine sets the vector base address.  The CPU's vector base
* register is set to the specified value, and subsequent calls to 
* intVecGet() and intVecSet() will use this base address.
* The vector base address is initially 0, until changed by calls to this
* routine.
*
* NOTE:
* The PowerPC does not have an interrupt vector base register;
* thus this routine is a no-op for these architectures.
*
* RETURNS: N/A
*
* SEE ALSO: intVecBaseGet(), intVecGet(), intVecSet()
*/

void intVecBaseSet 
    (
    FUNCPTR * baseAddr	    /* new vector base address */
    )
    {
    if (_func_intVecBaseSetRtn != NULL)
    	_func_intVecBaseSetRtn (baseAddr);
    }

/*******************************************************************************
*
* intVecBaseGet - get the vector base address
*
* This routine returns the current vector base address that has been set
* with intVecBaseSet().
*
* RETURNS: The current vector base address, always 0.
*
* SEE ALSO: intVecBaseSet()
*/

FUNCPTR * intVecBaseGet (void)
    {
    if (_func_intVecBaseGetRtn == NULL)
	return (NULL);

    return (_func_intVecBaseGetRtn ());
    }

/*******************************************************************************
*
* intLevelSet - set the current interrupt lock-out level
*
* The PowerPC does not define external interrupt interface.  It is at board 
* level that decides the interrupt handler.
*/

int intLevelSet
    (
    int newLevel 		/* new interrupt level */
    )
    {
    if (_func_intLevelSetRtn == NULL)
	return (ERROR);

    return (_func_intLevelSetRtn (newLevel));
    }

/*******************************************************************************
*
* intEnable - enable the corresponding interrupt level
* 
*/

int intEnable
    (
    int intLevel		/* interrupt level to enable */
    )
    {
    if (_func_intEnableRtn != NULL)
	return (_func_intEnableRtn (intLevel));

    return (ERROR);
    }

/*******************************************************************************
*
* intDisable - disable the  corresponding interrupt level
*
*/

int intDisable
    (
    int intLevel		/* interrupt level to disable */
    )
    {
    if (_func_intDisableRtn != NULL)
	return (_func_intDisableRtn (intLevel));

    return (ERROR);
    }

/*******************************************************************************
*
* intLockLevelSet - set the current interrupt lock-out level
*
*/

void intLockLevelSet
    (
    int newLevel                /* new interrupt level */
    )
    {
    }

/*******************************************************************************
*
* intLockLevelGet - get the current interrupt lock-out level
*
*/

int intLockLevelGet (void)
    {
    return (ERROR);
    }

/******************************************************************************
*
* intRegsLock - modify a REG_SET to have interrupts locked.
*/

int intRegsLock
    (
    REG_SET *	pRegs		/* register set to modify */
    )
    {
    int oldMsr = pRegs->msr;
#ifdef	_PPC_MSR_CE
    pRegs->msr &= (~(_PPC_MSR_EE | _PPC_MSR_CE));
#else	/* _PPC_MSR_CE */
    pRegs->msr &= (~_PPC_MSR_EE);
#endif	/* _PPC_MSR_CE */
    return (oldMsr);
    }

/******************************************************************************
*
* intRegsUnlock - restore an REG_SET's interrupt lockout level.
*/

void intRegsUnlock
    (
    REG_SET *	pRegs,			/* register set to modify */
    int		oldMsr			/* msr with int lock to restore */
    )
    {
#ifdef	_PPC_MSR_CE
    pRegs->msr &= (~(_PPC_MSR_EE | _PPC_MSR_CE));
    pRegs->msr |= (oldMsr & (_PPC_MSR_EE | _PPC_MSR_CE));
#else	/* _PPC_MSR_CE */
    pRegs->msr &= (~_PPC_MSR_EE);
    pRegs->msr |= (oldMsr & _PPC_MSR_EE);
#endif	/* _PPC_MSR_CE */
    }


