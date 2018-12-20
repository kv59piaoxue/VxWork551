/* intArchLib.c - MIPS R-Series interrupt subroutine library */

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
01y,16jul01,ros  add CofE comment
01x,25apr01,mem  Remove VXM code.
01w,02jan01,pes  Replace SR_IEC/SR_IE with SR_INT_ENABLE.
01v,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01u,10sep99,myz  added CW4000_16 support
01t,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01s,19jul96,cah  added R4650 support
01r,04dec95,mem  added intRegsLock, intRegsUnlock
01q,12may95,cd   made intHandlerCreate Endianess independent
01p,26jan95,rhp  doc tweaks.
01o,29mar94,caf  added R4000 to documentation.
01n,01apr93,caf  changed intConnect() to take VOIDFUNCPTR.
01n,17oct94,rhp  removed obs. docn references to intALib
01m,23aug92,jcf  changed cache* to CACHE_*.  changed filename.
01l,08aug92,ajm  ansified
01k,02aug92,jcf  added vxmIfVecxxx callout for monitor support.
01j,07jul92,yao  moved intConnect() and globla variable areWeNested here 
		 from intLib.c.  ANSI cleanwd up.
01i,07jul92,ajm  5.1 cache support added
01h,04jul92,jcf  scalable/ANSI/cleanup effort.
01g,05jun92,ajm  5.0.5 merge, note mod history changes
01f,26may92,rrr  the tree shuffle
01e,16jan92,jdi  doc tweak.
01d,14jan92,jdi  documentation cleanup.
01c,04oct91,rrr  passed through the ansification filter
                  -changed includes to have absolute path from h/
                  -changed VOID to void
                  -changed copyright notice
01b,21aug91,wmd  moved PRIO_TABLE and intPrioTable definition to sysLib.c
01a,01apr91,ajm  MIPS-ized and split.  Derived from 03b 68K version.
*/

/*
DESCRIPTION
This library provides architecture-dependent routines to manipulate
and connect to hardware interrupts.  Any C language routine can be
connected to any interrupt by calling intConnect().  Vectors can be
accessed directly by intVecSet() and intVecGet().  

WARNING
Do not call VxWorks system routines with interrupts locked.
Violating this rule may re-enable interrupts unpredictably.

INTERRUPT VECTORS AND NUMBERS
Some of the routines in this library take an interrupt vector as a
parameter, which is the byte offset into the vector table.
Macros are provided to convert between interrupt vectors and interrupt
numbers:
.iP IVEC_TO_INUM(intVector) 10
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

SEE ALSO: intLib, intALib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "intLib.h"
#include "memLib.h"
#include "sysLib.h"
#include "private/taskLibP.h"
#include "string.h"

/* imports */

IMPORT void intEnt ();		/* interrupt entrance stub */
IMPORT void intExit ();		/* interrupt exit stub */


#define	HI_WORD(w)		(((UINT32)(w) >> 16) & 0xffff)
#define	LO_WORD(w)		(((UINT32)(w)) & 0xffff)

/* globals */

int areWeNested = 0;	/* Counter to tell if we are a nested interrupt */
			/* Bumped and de-bumped by kernel */
/* locals */

#if FALSE
LOCAL FUNCPTR *intVecBase = 0;		/* vector base address */
#endif

LOCAL UINT intConnectCode []	=	/* intConnect stub */
    {
/*
*  0x0:		3c08xxxx	lui	t0,xxxx		* msh routine address
*  0x4:		3c04yyyy	lui	a0,yyyy		* msh parameter load
*  0x8:		3508zzzz	ori	t0,t0,zzzz	* lsh routine address
*  0xc:		01000008	jr	t0		* jump to routine
*  0x10:	3484pppp	ori	a0,a0,pppp	* lsh load in BD slot
*/
     0x3c080000,	/* msh routine address runtime load */
     0x3c040000,	/* msh parameter load runtime load */
     0x35080000,	/* lsh routine address runtime load */
     0x01000008,	/* jump to routine */
     0x34840000,	/* lsh load in BD slot runtime load */
    };

/* forward declarations */

FUNCPTR	  intHandlerCreate (FUNCPTR routine, int parameter);
FUNCPTR	* intVecBaseGet (void);
FUNCPTR	  intVecGet (FUNCPTR * vector);
void intVecSet (FUNCPTR * vector, FUNCPTR function);

/*******************************************************************************
*
* intConnect - connect a C routine to a hardware interrupt
*
* This routine connects a specified C routine to a specified interrupt
* vector.  The address of <routine> is stored at <vector> so that <routine>
* is called with <parameter> when the interrupt occurs.  The routine is
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
    FUNCPTR intDrvRtn = intHandlerCreate ((FUNCPTR) routine, parameter);

    if (intDrvRtn == NULL)
	return (ERROR);

    /* make vector point to synthesized code */

    intVecSet ((FUNCPTR *) vector,(FUNCPTR)  intDrvRtn);

    return (OK);
    }
/*******************************************************************************
*
* intHandlerCreate - construct an interrupt handler for a C routine
*
* This routine builds an interrupt handler around a specified C routine.
* This interrupt handler is then suitable for connecting to a specific
* vector address with intVecSet().  The interrupt handler is invoked in
* supervisor mode at interrupt level.  A proper C environment is
* established, the necessary registers saved, and the stack set up.
*
* The routine can be any normal C code, except that it must not invoke
* certain operating system functions that may block or perform I/O
* operations.
*
* IMPLEMENTATION:
* This routine builds an interrupt handler of the following form in
* allocated memory:
*
* .CS
*     0x0:   3c08xxxx   lui   t0,xxxx      * msh routine address
*     0x4:   3c04yyyy   lui   a0,yyyy      * msh parameter load
*     0x8:   3508zzzz   ori   t0,t0,zzzz   * lsh routine address
*     0xc:   01000008   jr    t0           * jump to routine
*     0x10:  3484pppp   ori   a0,a0,pppp   * lsh load in BD slot
* .CE
*
* RETURNS:
* A pointer to the new interrupt handler, or NULL if memory
* is insufficient.
*/

FUNCPTR intHandlerCreate 
    (
    FUNCPTR routine,		/* routine to be called              */
    int     parameter		/* parameter to be passed to routine */
    )
    {
    FAST UINT * pCode;	/* pointer to newly synthesized code */

    pCode = (UINT *) malloc (sizeof (intConnectCode));

    if (pCode != NULL)
	{
	/* copy intConnectCode into new code area */

	bcopy ((char *)intConnectCode, (char *)pCode, sizeof (intConnectCode));

	/* set the addresses & instructions */

	pCode [0]  |= HI_WORD (routine);
	pCode [1]  |= HI_WORD (parameter);
	pCode [2]  |= LO_WORD (routine);
	pCode [4]  |= LO_WORD (parameter);
	}

    /*
     * Flush the cache so we don't get instruction
     * cache hits to wrong vector
     */

    CACHE_TEXT_UPDATE ((void *) pCode, sizeof (intConnectCode));

    return ((FUNCPTR)pCode);
    }
/*******************************************************************************
*
* intVecBaseSet - set the vector base address
*
* This routine sets the vector base address.  The CPU's vector base
* register is set to the specified value, and subsequent calls to 
* intVecGet() and intVecSet() will use this base address.
* The vector base address is initially 0, until changed by calls to this
* routine.
*
* NOTE:
* The MIPS processor does not have a vector base register;
* thus this routine is a no-op for this architecture.
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
    }
/*******************************************************************************
*
* intVecBaseGet - get the vector base address
*
* This routine returns the current vector base address that has been set
* with intVecBaseSet().
*
* RETURNS: The current vector base address, always 0 on MIPS.
*
* SEE ALSO: intVecBaseSet()
*/

FUNCPTR * intVecBaseGet (void)

    {
    IMPORT int excBsrTbl[];
    return((FUNCPTR *)excBsrTbl);
    }
/******************************************************************************
*
* intVecSet - set a CPU vector
*
* This routine attaches an exception/interrupt handler to a specified vector.
* The vector is specified as an offset into the CPU's vector table.  On the
* MIPS architecture the vector table is set up statically in software.
*
* SEE ALSO: intVecGet()
*/

void intVecSet 
    (
    FUNCPTR * vector,		/* vector offset              */
    FUNCPTR   function		/* address to place in vector */
    )

    {
    FUNCPTR * newVector;

    /* vector is offset by the vector base address */

    newVector = (FUNCPTR *) ((int) vector + (int) intVecBaseGet ());

    *newVector = function;
    }
/*******************************************************************************
*
* intVecGet - get a CPU vector
*
* This routine returns a pointer to the exception/interrupt handler attached
* to a specified vector.  The vector is specified as an offset into the CPU's
* vector table.
* For the MIPS architecture, the vector table is set up statically in software.
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
    /* vector is offset by vector base address */

    return (* (FUNCPTR *) ((int) vector + (int) intVecBaseGet ()));
    }
/*******************************************************************************
*
* intLockLevelSet - set the current interrupt lock-out level
*
* This is a null routine for the MIPS architecture.
*/

void intLockLevelSet
    (
    int newLevel 		/* new interrupt level */
    )
    {
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
    pRegs->sr &= ~SR_INT_ENABLE;
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
    pRegs->sr = (pRegs->sr & ~SR_INT_ENABLE) | (oldSr & SR_INT_ENABLE);
    }
