/* intArchLib.c - ColdFire interrupt subroutine library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,19jun00,ur   Removed all non-Coldfire stuff.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This library provides architecture-dependent routines to manipulate
and connect to hardware interrupts.  Any C language routine can be
connected to any interrupt by calling intConnect().  Vectors can be
accessed directly by intVecSet() and intVecGet().  
The vector base register can be accessed by the routines
intVecBaseSet() and intVecBaseGet().

Tasks can lock and unlock interrupts by calling the routines intLock() and
intUnlock().  The lock level can be set and reported by intLockLevelSet()
and intLockLevelGet(); the default interrupt mask level is set to 7 by
kernelInit() when VxWorks is initialized.

WARNING
Do not call VxWorks system routines with interrupts locked.
Violating this rule may re-enable interrupts unpredictably.

INTERRUPT VECTORS AND NUMBERS
Most of the routines in this library take an interrupt vector as a
parameter, which is the byte offset into the vector table.  Macros are
provided to convert between interrupt vectors and interrupt numbers:
.iP IVEC_TO_INUM(intVector) 10
changes a vector to a number.
.iP INUM_TO_IVEC(intNumber)
turns a number into a vector.
.iP TRAPNUM_TO_IVEC(trapNumber)
converts a trap number to a vector.

EXAMPLE
To switch between one of several routines for a particular interrupt,
the following code fragment is one alternative:
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
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "cacheLib.h"
#include "errno.h"
#include "intLib.h"
#include "memLib.h"
#include "sysLib.h"
#include "taskLib.h"
#include "string.h"
#include "stdlib.h"
#include "private/vxmIfLibP.h"

IMPORT void intVBRSet (FUNCPTR *baseAddr);

IMPORT void intEnt ();		/* interrupt entrance stub */
IMPORT void intExit ();		/* interrupt exit stub */

#define	HI_WORD(w)		(short)(((int)(w) & 0xffff0000) >> 16)
#define	LO_WORD(w)		(short)((int)(w) & 0x0000ffff)


/* globals */

/* The routine intLock(), found in intALib.s uses intLockMask to construct a
 * new SR with the correct interrupt lock-out level.  The difficulty is
 * intLock() may be called from either interrupt level, or task level, so
 * simply reserving a SR suchas 0x3700 does not work because such a SR would
 * assume task-level code.
 */

USHORT intLockMask = 0x0700;	/* interrupt lock mask - default level 7 */

/* The kernel also locks interrupts but unlike intLock() it knows which stack
 * is being used so intLockIntSR is a status register to lock interrupts from
 * the interrupt stack, and intLockTaskSR is a status register to lock
 * interrupts from the task stack.  These SRs are updated by
 * intLockLevelSet().  It is faster to move these SRs into the
 * SR, then to 'or' in the intLockMask, because there is no: or.w <ea>,SR.
 */

USHORT intLockIntSR  = 0x2700;	/* SR for locking interrupts from int. level */
USHORT intLockTaskSR = 0x3700;	/* SR for locking interrupts from task level */


/* locals */

LOCAL FUNCPTR *intVecBase = 0;		/* vector base address */

LOCAL USHORT intConnectCode []	=	/* intConnect stub */
    {
/*
*0x00  4E41		trap	#1		  * switch to int stack
*0x02  4EB9 kkkk kkkk	jsr	_intEnt  	  * tell kernel
*0x04  9FFC 0000 0014	suba.l	#20,a7  	  * make room for regs
*0x0C  48D7 0307	movem.l	d0-d2/a0-a1,(a7)  * save regs
*0x0E  2F3C pppp pppp	move.l	#parameter,-(a7)  * push param
*0x14  4EB9 rrrr rrrr	jsr	routine		  * call C routine
*0x1A  588F		addq.l  #4,a7             * pop param
*0x1C  4CD7 0307	movem.l (a7),d0-d2/a0-a1  * restore regs
*0x20  DFFC 0000 0014	adda.l	#20,a7  	  * adjust a7
*0x26  4EF9 kkkk kkkk	jmp     _intExit          * exit via kernel
*/
     0x4e41,
     0x4eb9, 0x0000, 0x0000,	/* _intEnt filled in at runtime */
     0x9ffc, 0x0000, 0x0014,
     0x48d7, 0x0307,
     0x2f3c, 0x0000, 0x0000,	/* parameter filled in at runtime */
     0x4eb9, 0x0000, 0x0000,	/* routine to be called filled in at runtime */
     0x588f,
     0x4cd7, 0x0307,
     0xdffc, 0x0000, 0x0014,
     0x4ef9, 0x0000, 0x0000,	/* _intExit filled in at runtime */
    };

/* forward declarations */

FUNCPTR	intHandlerCreate ();
FUNCPTR	*intVecBaseGet ();
FUNCPTR	intVecGet ();


/*******************************************************************************
*
* intConnect - connect a C routine to a hardware interrupt
*
* This routine connects a specified C routine to a specified interrupt
* vector.  The address of <routine> is stored at <vector> so that <routine>
* is called with <parameters> when the interrupt occurs.  The routine is
* invoked in supervisor mode at interrupt level.  A proper C environment
* is established, the necessary registers saved, and the stack set up.
*
* The routine can be any normal C code, except that it must not invoke
* certain operating system functions that may block or perform I/O
* operations.
*
* This routine simply calls intHandlerCreate() and intVecSet().  The address
* of the handler returned by intHandlerCreate() is what actually goes in
* the interrupt vector.
*
* RETURNS:
* OK, or
* ERROR if the interrupt handler cannot be built.
*
* SEE ALSO: intHandlerCreate(), intVecSet()
*/

STATUS intConnect
    (
    VOIDFUNCPTR *vector,            /* interrupt vector to attach to */
    VOIDFUNCPTR routine,            /* routine to be called */
    int parameter               /* parameter to be passed to routine */
    )
    {
    FUNCPTR intDrvRtn = intHandlerCreate ((FUNCPTR) routine, parameter);

    if (intDrvRtn == NULL)
	return (ERROR);

    /* make vector point to synthesized code */

    intVecSet ((FUNCPTR *) vector, (FUNCPTR) intDrvRtn);

    return (OK);
    }
/*******************************************************************************
*
* intHandlerCreate - construct an interrupt handler for a C routine
*
* This routine builds an interrupt handler around the specified C routine.
* This interrupt handler is then suitable for connecting to a specific
* vector address with intVecSet().  The routine will be invoked in
* supervisor mode at interrupt level.  A proper C environment is
* established, the necessary registers saved, and the stack set up.
*
* The routine can be any normal C code, except that it must not invoke
* certain operating system functions that may block or perform I/O
* operations.
*
* IMPLEMENTATION:
* This routine builds an interrupt handler of the following form in
* allocated memory.
*
* .CS
*     0x00  4E41           trap    #1               * switch to int stack
*     0x02  4EB9 kkkk kkkk jsr     _intEnt          * tell kernel
*     0x04  9FFC 0000 0014 suba.l  #20,a7           * make room for regs
*     0x0A  48D7 0307	   movem.l d0-d2/a0-a1,(a7) * save regs
*     0x0E  2F3C pppp pppp move.l  #parameter,-(a7) * push param
*     0x14  4EB9 rrrr rrrr jsr     routine          * call C routine
*     0x1A  588F           addq.l  #4,a7            * pop param
*     0x1C  4CD7 0307      movem.l (a7),d0-d2/a0-a1 * restore regs
*     0x20  DFFC 0000 0014 adda.l  #20,a7           * adjust a7
*     0x26  4EF9 kkkk kkkk jmp     _intExit         * exit via kernel
* .CE
*
* RETURNS: A pointer to the new interrupt handler,
* or NULL if the routine runs out of memory.
*/

FUNCPTR intHandlerCreate
    (
    FUNCPTR routine,            /* routine to be called */
    int parameter               /* parameter to be passed to routine */
    )
    {
    FAST USHORT *pCode;		/* pointer to newly synthesized code */

    pCode = (USHORT *)malloc (sizeof (intConnectCode));

    if (pCode != NULL)
	{
	/* copy intConnectCode into new code area */

	bcopy ((char *)intConnectCode, (char *)pCode, sizeof (intConnectCode));

	/* set the addresses & instructions */

	pCode [2]  = HI_WORD (intEnt);
	pCode [3]  = LO_WORD (intEnt);
	pCode [7+3]  = HI_WORD (parameter);
	pCode [8+3]  = LO_WORD (parameter);
	pCode [10+3]  = HI_WORD (routine);
	pCode [11+3] = LO_WORD (routine);
	pCode [19+3] = HI_WORD (intExit);
	pCode [20+3] = LO_WORD (intExit);
	}

    CACHE_TEXT_UPDATE ((void *) pCode, sizeof (intConnectCode));

    return ((FUNCPTR) (int) pCode);
    }
/*******************************************************************************
*
* intLockLevelSet - set the current interrupt lock-out level
*
* This routine sets the current interrupt lock-out level and stores it in
* the globally accessible variable `intLockMask'.  The specified
* interrupt level will be masked when interrupts are locked by intLock().
* The default lock-out level is 7 for MC680x0 processors, and is initially
* set by kernelInit() when VxWorks is initialized.
*
* RETURNS: N/A
*
* SEE ALSO: intLockLevelGet()
*/

void intLockLevelSet
    (
    int newLevel                /* new interrupt level */
    )
    {
    int oldSR = intLock ();			/* LOCK INTERRUPTS */

    intLockMask    = (USHORT) (newLevel << 8);
    intLockIntSR  &= 0xf8ff;
    intLockTaskSR &= 0xf8ff;
    intLockIntSR  |= intLockMask;
    intLockTaskSR |= intLockMask;

    intUnlock (oldSR);				/* UNLOCK INTERRUPTS */
    }
/*******************************************************************************
*
* intLockLevelGet - get the current interrupt lock-out level
*
* This routine returns the current interrupt lock-out level, which is
* set by intLockLevelSet() and stored in the globally accessible
* variable `intLockMask'.  This is the interrupt level currently
* masked when interrupts are locked out by intLock().  The default
* lock-out level is 7 for 68K processors, and is initially set by
* kernelInit() when VxWorks is initialized.
*
* RETURNS:
* The interrupt level currently stored in the interrupt lock-out mask.
*
* SEE ALSO: intLockLevelSet() 
*/

int intLockLevelGet (void)
    {
    return ((int)(intLockMask >> 8));
    }
/*******************************************************************************
*
* intVecBaseSet - set the vector base address
*
* This routine sets the vector base address.  The CPU's vector base register
* is set to the specified value, and subsequent calls to intVecGet() or
* intVecSet() will use this base address.  The vector base address is
* initially 0, until modified by calls to this routine.
*
* RETURNS: N/A
*
* SEE ALSO: intVecBaseGet(), intVecGet(), intVecSet()
*/

void intVecBaseSet
    (
    FUNCPTR *baseAddr       /* new vector base address */
    )
    {
    intVecBase = baseAddr;	/* keep the base address in a static variable */

    intVBRSet (baseAddr);	/* set the actual vector base register */

    CACHE_TEXT_UPDATE ((void *) baseAddr, 256  * sizeof (FUNCPTR));
    }
/*******************************************************************************
*
* intVecBaseGet - get the vector base address
*
* This routine returns the current vector base address, which is set
* with intVecBaseSet().
*
* RETURNS: The current vector base address.
*
* SEE ALSO: intVecBaseSet()
*/

FUNCPTR *intVecBaseGet (void)
    {
    return (intVecBase);
    }
/******************************************************************************
*
* intVecSet - set a CPU vector
*
* This routine attaches an exception/interrupt handler to a specified vector.
* The vector is specified as an offset into the CPU's vector table.  This
* vector table starts, by default, at address 0. On Coldfire
* CPUs, the vector table may be set to start at any address with the
* intVecBaseSet() routine.  The vector table is set up in usrInit() and
* starts at the lowest available memory address.
*
* RETURNS: N/A
*
* SEE ALSO: intVecBaseSet(), intVecGet()
*/

void intVecSet
    (
    FUNCPTR *	vector,		/* vector offset */
    FUNCPTR	function	/* address to place in vector */
    )
    {
    FUNCPTR *	newVector;
    UINT	state;
    BOOL	writeProtected = FALSE;
    int		pageSize = 0;
    char *	pageAddr = 0;

    /* vector is offset by the vector base address */

    newVector = (FUNCPTR *) ((int) vector + (int) intVecBaseGet ());

    /* see if we need to write enable the memory */

    *newVector = function;

    CACHE_TEXT_UPDATE ((void *) newVector, sizeof (FUNCPTR));
    }

/*******************************************************************************
*
* intVecGet - get a vector
* 
* This routine returns a pointer to the exception/interrupt handler
* attached to a specified vector.  The vector is specified as an
* offset into the CPU's vector table.  This vector table starts, by
* default, at address 0.  However, on 68010 and 68020 CPUs, the vector
* table may be set to start at any address with intVecBaseSet().
*
* RETURNS
* A pointer to the exception/interrupt handler attached to the specified vector.
*
* SEE ALSO: intVecSet(), intVecBaseSet()
*/

FUNCPTR intVecGet
    (
    FUNCPTR *vector     /* vector offset */
    )
    {
    FUNCPTR vec;

    /* vector is offset by vector base address */

    return (* (FUNCPTR *) ((int) vector + (int) intVecBaseGet ()));
    }

/******************************************************************************
*
* intRegsLock - modify a REG_SET to have interrupts locked.
*/ 

int intRegsLock
    (
    REG_SET *pRegs			/* register set to modify */
    )
    {
    int oldSr = pRegs->sr;
    pRegs->sr |= intLockMask;
    return (oldSr);
    }

/******************************************************************************
*
* intRegsUnlock - restore an REG_SET's interrupt lockout level.
*/ 

void intRegsUnlock
    (
    REG_SET *	pRegs,			/* register set to modify */
    int		oldSr			/* sr with int lock level to restore */
    )
    {
    pRegs->sr &= (~0x0700);
    pRegs->sr |= (oldSr & 0x0700);
    }

