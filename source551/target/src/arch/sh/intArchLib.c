/* intArchLib.c - SH interrupt subroutine library */

/* Copyright 1994-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02n,05mar01,hk   modified intVecTableWriteProtect() to leave table cacheable.
02m,21feb01,zl   Added stub routines for intEnable() and intDisable() 
                 (SPR #63046).
02l,28oct00,hk   added cacheFlush to intVecSet() for SH7700/SH7750.
02k,11sep00,hk   add intGlobalSRSet() to automate SR.DSP bit preservation.
02j,04sep00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
		 merge intLockIntSR to intLockTaskSR, change intLockLevelSet().
		 add intUnlockSR/intBlockSR to support SR.DSP bit preservation.
		 delete inclusion of unreferenced headers.
		 delete unnecessary forward declarations.
		 add _func_intConnectHook to decouple intConnect() from
		 sysIntConnect() and sysInumVirtBase.
		 minor change in intHandlerCreate() regarding cache control.
		 change intVecBaseSet() to load VBR-relative stubs by way of
		 their virtual address.
		 add intPrioTable[] loading to intVecBaseSet().
		 move in windIntStackSet() from windALib.
		 change intVecSet() to set vector by way of virtual address.
		 change intVecTableWriteProtect() to make the virtual address
		 of vector table uncacheable.
		 simplify intRegsLock()/intRegsUnlock().
02i,10apr00,hk   added VBR-relative loading of intExitStub, dispatchStub,
                 and INTEVT register address in intVecBaseSet().
02h,20mar00,zl   forced interrupt handlers aligned to cache line size
02g,22sep99,zl   updated for little endian support.
02e,07may98,jmc  added support for SH-DSP and SH3-DSP.
02e,07nov98,hk   unified intConnectCode[] for SH7700/SH7600/SH7040/SH7000.
		 deleted unreferenced IMPORT for AreWeNested/VxIntStackBase.
02f,15sep98,hk   unified SH7750_ macro to SH7700_ style.
02e,16jul98,st   added SH7750 support.
02d,25nov97,hk   deleted junk in intHandlerCreate(). reviewed comments.
02c,25apr97,hk   changed SH704X to SH7040.
02b,23feb97,hk   fixed intRegsUnlock() to preserve M/Q/S/T bits in new SR.
                 reviewed intRegsLock().
02a,28jan97,hk   added notes on intVecBaseSet() and deleted unnecessary ptr.
                 disabled write enable/disable code intVecSet() and added notes.
                 made intVecTableWriteProtect() for SH7700 only, used etext
                 to identify logical space to be protected. copyright 1997.
01z,13dec96,hk   fixed intLockLevelSet() to clear upper 24 bits in intLockMask.
01y,13dec96,hk   deleted dynamic relocation code for intStub & intConnectCode.
01x,08dec96,hk   changed intLockIntSR to usr bank-1. modified SH7700
		 intConnectCode[] to call intExit(). dynamically relocate
		 intExit(), AreWeNested, and VxIntStackBase to P1 addresses.
01w,27aug96,wt   fixed the bug of intRegsLock () and intRegsUnlock ().
01v,13aug96,hk   changed intEnt for SH7700 to intStub.
01u,08aug96,hk   changed SH7700_OFF_INT according to new ivSh.h (01t).
01t,29jul96,hk   added intEnt loading code for SH7700 in intVecBaseSet().
01s,27jul96,hk   changed intLockTaskSR to 0x400000f0 for SH7700. reviewed
		 #if/#elif/#endif readability.
01r,24jul96,wt   import intRegsLock() and intRegsUnlock() from sparc's code.
01q,23jul96,hk   suppressed intEnt declaration for SH7700.
01p,13jun96,hk   changed intLockTaskSR to 0x600000f0 for SH7700.
01o,07jun96,hk   added support for SH7700.
01n,15aug95,hk   changed INUM_VIRT_BASE to sysInumVirtBase.
01m,02jul95,hk   documentation review.
01l,18jun95,hk   modified intConnect() to call-out sysIntConnect() for over 128.
01k,06apr95,hk   filled two nops in intConnectCode with meaningfull codes. '95.
01j,25oct94,hk   removed 68k code and comment from intVecBaseSet().
01i,20oct94,sa   fixed intHandlerCreate(). pCode [18] = HI_WORD (parameter);
							^^ bug. LO_WORD
01h,17oct94,hk   fixed intLockLevelGet(), seems not used though.
01g,08oct94,hk   modified intConnectCode (alpha-0).
01f,06oct94,hk   modified intConnectCode, intHandlerCreate.
01e,06oct94,hk   courtesy of sa, fixed intConnectCode.
01d,30sep94,sa   fixed intHandlerCreate().
01c,27sep94,hk   fixed intLockLevelSet() again.
01b,26sep94,hk   fixed intLockLevelSet().
01a,07jul94,hk   derived from 68k-03s.
*/

/*
This library provides routines to manipulate and connect to hardware interrupts
and exceptions.  Any C language routine can be connected to any exception,
interrupt, or trap by calling the routine intConnect().  Interrupt vectors
can be accessed directly by the routines intVecSet() and intVecGet().  The
vector base register (VBR) can be accessed by the routines intVecBaseSet()
and intVecBaseGet().

Tasks can lock and unlock interrupts by calling the routines intLock() and
intUnlock().  The lock level can be set and reported by intLockLevelSet()
and intLockLevelGet(); the default interrupt mask level is set to 15 by
kernelInit() when VxWorks is initialized.

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

SEE ALSO: intALib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "cacheLib.h"		/* for CACHE_TEXT_UPDATE() */
#include "errno.h"		/* for errno */
#include "intLib.h"		/* for intLock(), intUnlock() */
#include "iv.h"
#include "memLib.h"		/* for memalign() */
#include "string.h"		/* for bcopy(), bzero() */
#if (CPU==SH7750 || CPU==SH7700)
#include "qLib.h"		/* for Q_FIRST() */
#include "taskLib.h"		/* for taskIdListGet() */
#include "private/kernelLibP.h"	/* for activeQHead */
#endif
#include "private/vxmIfLibP.h"	/* for VXM_IF_VEC_SET, VXM_IF_VEC_GET */
#include "private/vmLibP.h"	/* for vmLibInfo, VM_STATE_GET, VM_STATE_SET */


/* imports */

IMPORT void intEnt ();				/* windALib */
IMPORT void intExit ();				/* windALib */
#if (CPU==SH7750 || CPU==SH7700)
IMPORT void intExitStub ();			/* windALib */
IMPORT int  intExitStubSize;			/* windALib */
IMPORT void dispatchStub ();			/* windALib */
IMPORT int  dispatchStubSize;			/* windALib */
IMPORT void intStub ();				/* windALib */
IMPORT int  intStubSize;			/* windALib */
IMPORT UINT32 intPrioTable[];			/* sysALib */
IMPORT UINT32 intPrioTableSize;			/* sysALib */
IMPORT int  intEvtAdrs;				/* XXX sysLib */
#endif

#define	HI_WORD(w)		(short)(((int)(w) & 0xffff0000) >> 16)
#define	LO_WORD(w)		(short)((int)(w) & 0x0000ffff)


/* globals */

/* The routine intLock(), found in intALib.s uses intLockMask to construct a
 * new SR with the correct interrupt lock-out level.  The difficulty is
 * intLock() may be called from either interrupt level, or task level, so
 * simply reserving a SR suchas 0x400000f0 does not work because such a SR
 * would assume task-level code.
 */

UINT32 intLockMask = 0x000000f0;   /* interrupt lock mask - default level 15 */

/* The kernel also locks interrupts but unlike intLock() it knows which stack
 * is being used so intLockIntSR is a status register to lock interrupts from
 * the interrupt stack, and intLockTaskSR is a status register to lock
 * interrupts from the task stack.  These SRs are updated by
 * intLockLevelSet().  It is faster to move these SRs into the
 * SR, then to 'or' in the intLockMask, because there is no: or.w <ea>,SR.
 */

#if (CPU==SH7750 || CPU==SH7700)
UINT32 intLockTaskSR   = 0x400000f0; /* SR for locking ints */
UINT32 intUnlockSR     = 0x40000000; /* SR for unlocking ints */
UINT32 intBlockSR      = 0x70000000; /* SR for blocking ints */
#elif (CPU==SH7600 || CPU==SH7000)
UINT32 intLockTaskSR   = 0x000000f0; /* SR for locking ints */
#endif


STATUS (* _func_intConnectHook)
    (VOIDFUNCPTR *, VOIDFUNCPTR, int) = NULL;	/* hook for BSP intConnect */
int    (* _func_intEnableRtn) (int) = NULL;     /* routine for intEnable */
int    (* _func_intDisableRtn) (int) = NULL;    /* routine for intDisable */


LOCAL int  dummy (void) { return ERROR; }  /* dummy, returns ERROR   */
FUNCPTR    sysIntLvlEnableRtn  = dummy;    /* enable a single level  */
FUNCPTR    sysIntLvlDisableRtn = dummy;    /* disable a single level */


/* locals */

LOCAL FUNCPTR *intVecBase = 0;		/* vector base address */


LOCAL USHORT intConnectCode []	=	/* intConnect stub */
    {
/*
 * 0x00  4f22                           sts.l	pr,@-sp        * save pr
 * 0x02  2f06                           mov.l	r0,@-sp        * save r0
 * 0x04  d004				mov.l	intEntAdrs,r0  *
 * 0x06  400b				jsr	@r0            * tell kernel
 * 0x08  2f16				mov.l	r1,@-sp        * save r1
 * 0x0a  d005				mov.l	routineAdrs,r0 *
 * 0x0c  d405				mov.l	paramAdrs,r4   * set parameter
 * 0x0e  400b				jsr	@r0            * call C routine
 * 0x10  0009				nop
 * 0x12  d002				mov.l	intExitAdrs,r0 *
 * 0x14  402b				jmp	@r0            * exit via kernel
 * 0x16  61f6				mov.l	@sp+,r1        * pop errno in r1
 * 0x18  kkkk kkkk	intEntAdrs:	.long	_intEnt
 * 0x1c  pppp pppp	intExitAdrs:	.long	_intExit
 * 0x20  rrrr rrrr	routineAdrs:	.long	routine
 * 0x24  qqqq qqqq	paramAdrs:	.long	parameter
 */
    0x4f22, 0x2f06, 0xd004, 0x400b,
    0x2f16, 0xd005, 0xd405, 0x400b,
    0x0009, 0xd002, 0x402b, 0x61f6,
    0x0000, 0x0000,		/* _intEnt filled in at runtime */
    0x0000, 0x0000,		/* _intExit filled in at runtime */
    0x0000, 0x0000,		/* routine to be called filled in at runtime */
    0x0000, 0x0000,		/* parameter filled in at runtime */
    };


/******************************************************************************
*
* intConnect - connect a C routine to a hardware interrupt
*
* This routine connects a specified C routine to a specified interrupt
* vector.  The address of <routine> is stored at <vector> so that <routine>
* is called with <parameters> when the interrupt occurs.  The routine will
* be invoked in supervisor mode at interrupt level.  A proper C environment
* is established, the necessary registers saved, and the stack set up.
*
* The routine can be any normal C code, except that it must not invoke
* certain operating system functions that may block or perform I/O
* operations.
*
* This routine simply calls intHandlerCreate() and intVecSet().  The address
* of the handler returned by intHandlerCreate() is what actually gets put in
* the interrupt vector.
*
* RETURNS: OK, or ERROR if the routine is unable to build the interrupt handler.
*
* SEE ALSO: intHandlerCreate(), intVecSet()
*/

STATUS intConnect
    (
    VOIDFUNCPTR *vector,	/* to attach */
    VOIDFUNCPTR routine,	/* to be called */
    int parameter		/* for the routine */
    )
    {
    STATUS status = ERROR;

    if (_func_intConnectHook != NULL)
	{
	/* BSP specific connect routine */

	status = (* _func_intConnectHook) (vector, routine, parameter);
	}
    else
	{
	FUNCPTR intDrvRtn = intHandlerCreate ((FUNCPTR)routine, parameter);

	if (intDrvRtn != NULL)
	    {
	    /* make vector point to synthesized code */

	    intVecSet ((FUNCPTR *)vector, (FUNCPTR)intDrvRtn);

	    status = OK;
	    }
	}

    return status;
    }

/******************************************************************************
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
*     0x00  4EB9 kkkk kkkk jsr     _intEnt           * tell kernel
*     0x06  48E7 E0C0      movem.l d0-d2/a0-a1,-(a7) * save regs
*     0x0a  2F3C pppp pppp move.l  #parameter,-(a7)  * push param
*     0x10  4EB9 rrrr rrrr jsr     routine           * call C routine
*     0x16  588F           addq.l  #4,a7             * pop param
*     0x18  4CDF 0307      movem.l (a7)+,d0-d2/a0-a1 * restore regs
*     0x1c  4EF9 kkkk kkkk jmp     _intExit          * exit via kernel
* .CE
*
* RETURNS: A pointer to the new interrupt handler,
* or NULL if the routine runs out of memory.
*/

FUNCPTR intHandlerCreate
    (
    FUNCPTR routine,		/* to be called */
    int parameter		/* for the routine */
    )
    {
    USHORT *pCode;		/* pointer to newly synthesized code */

    pCode = (USHORT *)memalign (_CACHE_ALIGN_SIZE, sizeof (intConnectCode));

    if (pCode != NULL)
	{
	/* copy intConnectCode into new code area */

	bcopy ((char *)intConnectCode, (char *)pCode, sizeof (intConnectCode));

	/* set the addresses & instructions */
#if (_BYTE_ORDER == _BIG_ENDIAN)
	pCode [12] = HI_WORD (intEnt);
	pCode [13] = LO_WORD (intEnt);
	pCode [14] = HI_WORD (intExit);
	pCode [15] = LO_WORD (intExit);
	pCode [16] = HI_WORD (routine);
	pCode [17] = LO_WORD (routine);
	pCode [18] = HI_WORD (parameter);
	pCode [19] = LO_WORD (parameter);
#else
	pCode [12] = LO_WORD (intEnt);
	pCode [13] = HI_WORD (intEnt);
	pCode [14] = LO_WORD (intExit);
	pCode [15] = HI_WORD (intExit);
	pCode [16] = LO_WORD (routine);
	pCode [17] = HI_WORD (routine);
	pCode [18] = LO_WORD (parameter);
	pCode [19] = HI_WORD (parameter);
#endif
	CACHE_TEXT_UPDATE ((void *)pCode, sizeof (intConnectCode));
	}

    return (FUNCPTR)pCode;
    }

/*******************************************************************************
*
* intEnable - enable the corresponding interrupt level
* 
* On SuperH processors, individual interrupts can be enabled/disabled by
* programming the on-chip interrupt controller IPRA-IPRx registers. The 
* implementation of these registers is different among the SuperH processors.
* Also, the same interrupt level can be shared by two or more interrupt sources.
* For these reasons, it is not possible to implement a generic intEnable() 
* routine, but it can be implemented at BSP level.
*
* RETURNS:
* OK or ERROR for invalid arguments.
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
* On SuperH processors, individual interrupts can be enabled/disabled by
* programming the on-chip interrupt controller IPRA-IPRx registers. The 
* implementation of these registers is different among the SuperH processors.
* Also, the same interrupt level can be shared by two or more interrupt sources.
* For these reasons it is not possible to implement a generic intDisable()
* routine, but it can be implemented at BSP level.
*
* RETURNS:
* OK or ERROR for invalid arguments.
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

/******************************************************************************
*
* intLockLevelSet - set the current interrupt lock-out level
*
* This routine sets the current interrupt lock-out level and stores it in
* the globally accessible variable <intLockMask>.  The specified
* interrupt level will be masked when interrupts are locked by intLock().
* The default lock-out level is 15 for SH processors, and is initially set by
* the kernelInit() call when VxWorks is initialized.
*
* RETURNS: N/A
*
* SEE ALSO: intLockLevelGet()
*/

void intLockLevelSet
    (
    int newLevel				/* new lock-out level */
    )
    {
    int key = intLock ();			/* LOCK INTERRUPTS */

    intLockMask  = (newLevel << 4) & 0x000000f0;

    intLockTaskSR = (intLockTaskSR & 0xffffff0f) | intLockMask;

    intUnlock (key);				/* UNLOCK INTERRUPTS */
    }

/******************************************************************************
*
* intLockLevelGet - get the current interrupt lock-out level
*
* This routine returns the current interrupt lock-out level, which is set by
* intLockLevelSet().  This is the interrupt level currently masked when
* interrupts are locked out by intLock().  The default lock-out level is 15
* for SH processors, and is initially set by the kernelInit() call when
* VxWorks is initialized.
*
* RETURNS:
* The interrupt level currently stored in the interrupt lock-out mask.
*
* SEE ALSO: intLockLevelSet()
*/

int intLockLevelGet (void)
    {
    return intLockMask >> 4;
    }

/******************************************************************************
*
* intVecBaseSet - set the vector base address
*
* This routine sets the vector base address.  The CPU's vector base register
* is set to the specified value, and subsequent calls to intVecGet() or
* intVecSet() will use this base address.  The vector base address is
* initially 0, until changed by calls to this routine.
*
* RETURNS: N/A
*
* SEE ALSO: intVecBaseGet(), intVecGet(), intVecSet()
*
* INTERNAL:
* This routine is called from usrInit(), with VEC_BASE_ADRS (configAll.h)
* as baseAddr.  At the time of this routine call, cacheLibInit() is done
* but cacheEnable() is not.  Namely whole cache is invalidated and not
* enabled.  Therefore no cache invalidation is necessary before copying
* intStub, even if the specified baseAddr is in a non-cache region.
*/

void intVecBaseSet
    (
    FUNCPTR *baseAddr       /* new vector base address */
    )
    {
#if (CPU==SH7750 || CPU==SH7700)
    UINT virtAddr = (UINT)intVecBaseSet;		/* where am I? */
    UINT virtBase = ((UINT)baseAddr & 0x1fffffff) | (virtAddr & 0xe0000000);
    UINT stubAddr;

    bzero ((char *)virtBase, 0x1000);	/* clean VBR relative stub space */

    /* load INTEVT register address */

    stubAddr = virtBase + SH7700_INT_EVT_ADRS_OFFSET;
    *(UINT32 *)stubAddr = intEvtAdrs;
    CACHE_TEXT_UPDATE ((void *)stubAddr, sizeof (UINT32));

    /* load interrupt handling stub */

    stubAddr = virtBase + SH7700_INT_STUB_OFFSET;
    bcopy ((char *)intStub, (char *)stubAddr, intStubSize);
    CACHE_TEXT_UPDATE ((void *)stubAddr, intStubSize);

    /* load intExit stub */

    stubAddr = virtBase + SH7700_INT_EXIT_STUB_OFFSET;
    bcopy ((char *)intExitStub, (char *)stubAddr, intExitStubSize);
    CACHE_TEXT_UPDATE ((void *)stubAddr, intExitStubSize);

    /* load task dispatch stub */

    stubAddr = virtBase + SH7700_DISPATCH_STUB_OFFSET;
    bcopy ((char *)dispatchStub, (char *)stubAddr, dispatchStubSize);
    CACHE_TEXT_UPDATE ((void *)stubAddr, dispatchStubSize);

    /* load intPrioTable[] */
 
    stubAddr = virtBase + SH7700_INT_PRIO_TABLE_OFFSET;
    bcopy ((char *)intPrioTable, (char *)stubAddr, intPrioTableSize);
    CACHE_TEXT_UPDATE ((void *)stubAddr, intPrioTableSize);

    intVecBase = baseAddr;	/* keep the base address in a static variable */

    intVBRSet (baseAddr);	/* set the actual vector base register */

#else
    intVecBase = baseAddr;	/* keep the base address in a static variable */

    intVBRSet (baseAddr);	/* set the actual vector base register */

    CACHE_TEXT_UPDATE ((void *)baseAddr, 256 * sizeof (FUNCPTR));
#endif
    }

/******************************************************************************
*
* intVecBaseGet - get the vector base address
*
* This routine returns the current vector base address that has been set
* with the intVecBaseSet() routine.
*
* RETURNS: The current vector base address.
*
* SEE ALSO: intVecBaseSet()
*/

FUNCPTR *intVecBaseGet (void)
    {
    return intVecBase;
    }

/******************************************************************************
*
* windIntStackSet - set the interrupt stack pointer
*
* This routine sets the interrupt stack pointer to the specified address.
* It is only valid on architectures with an interrupt stack pointer.
*
* NOMANUAL
*/

void windIntStackSet
    (
    char *pBotStack	/* pointer to bottom of interrupt stack */
    )
    {
#if (CPU==SH7750 || CPU==SH7700)

    UINT virtAddr = (UINT)windIntStackSet;		/* where am I? */
    UINT virtBase = ((UINT)intVecBase & 0x1fffffff) | (virtAddr & 0xe0000000);
    UINT stubAddr;

    stubAddr = virtBase + SH7700_INT_STACK_BASE_OFFSET;
    *(char **)stubAddr = pBotStack;
    CACHE_TEXT_UPDATE ((void *)stubAddr, sizeof (char *));

    stubAddr = virtBase + SH7700_ARE_WE_NESTED_OFFSET;
    *(UINT32 *)stubAddr = 0x80000000;
    CACHE_TEXT_UPDATE ((void *)stubAddr, sizeof (UINT32));

    stubAddr = virtBase + SH7700_NULL_EVT_CNT_OFFSET;
    *(UINT32 *)stubAddr = 0xabcd0000;
    CACHE_TEXT_UPDATE ((void *)stubAddr, sizeof (UINT32));

#endif /* CPU==SH7750 || CPU==SH7700 */
    }

/******************************************************************************
*
* intVecSet - set a CPU vector
*
* This routine sets an exception/interrupt vector to a specified address.
* The vector is specified as an offset into the CPU's vector table.
* On SH CPUs, the vector table may be set to start at any address with the
* intVecBaseSet() routine.  The vector table is set up in usrInit() and
* starts at the lowest available memory address.
*
* RETURNS: N/A
*
* SEE ALSO: intVecBaseSet(), intVecGet()
*/

void intVecSet
    (
    FUNCPTR *vector,	/* vector offset */
    FUNCPTR  function	/* address to place in vector */
    )
    {
    FUNCPTR *newVector;
#if (CPU==SH7750 || CPU==SH7700)
    BOOL     writeProtected = FALSE;
    int      pageSize = 0;
    char    *pageAddr = 0;
    UINT     virtAddr = (UINT)intVecSet;		/* where am I? */
#endif

    if (VXM_IF_VEC_SET (vector, function) == OK)	/* can monitor do it? */
	return;

    /* vector is offset by the vector base address */

    newVector = (FUNCPTR *)((UINT)vector + (UINT)intVecBaseGet ());

#if (CPU==SH7750 || CPU==SH7700)

    /* set the vector from its virtual address */

    newVector =
	(FUNCPTR *)(((UINT)newVector & 0x1fffffff) | (virtAddr & 0xe0000000));

    /* see if we need to write enable the memory */

    if (vmLibInfo.vmLibInstalled)
	{
	UINT state;

	pageSize = VM_PAGE_SIZE_GET();

	pageAddr = (char *)((UINT)newVector / pageSize * pageSize);

	if (VM_STATE_GET (NULL, (void *)pageAddr, &state) != ERROR)
	    {
	    if ((state & VM_STATE_MASK_WRITABLE) == VM_STATE_WRITABLE_NOT)
		{
		writeProtected = TRUE;

		VM_STATE_SET (NULL, pageAddr, pageSize,
			      VM_STATE_MASK_WRITABLE, VM_STATE_WRITABLE);
		}
	    }
	}
#endif

    *newVector = function;

#if (CPU==SH7750 || CPU==SH7700)

    /* push out the new vector on the data cache to physical memory */

    /* XXX The SH7729 gets an exception from fppProbe() unless flushing
     * XXX the cached vector before protecting the virtual page, and it
     * XXX happens regardless of the caching mode (copyback/writethru).
     * XXX The exception handler gets a vector from P1-cacheable region
     * XXX (by default), so that the new vector seems invisible on P1.
     * XXX It is strange because the SH7729 cache holds physical addresses
     * XXX in its address section, so we should not experience a cache
     * XXX incoherency problem between P0 and P1. However the flush code
     * XXX below is absolutely necessary if VBR is set to P2-noncacheable
     * XXX region, so please do not remove this. (02l,28oct00,hk)
     */
    if (cacheLib.flushRtn != NULL)
	cacheLib.flushRtn (DATA_CACHE, (void *)newVector, sizeof (FUNCPTR));

    if (writeProtected)
	{
	VM_STATE_SET (NULL, pageAddr, pageSize, 
		      VM_STATE_MASK_WRITABLE, VM_STATE_WRITABLE_NOT);
	}
#endif

    /* synchronize the instruction and data caches if they are separated */

    CACHE_TEXT_UPDATE ((void *)newVector, sizeof (FUNCPTR));
    }

/******************************************************************************
*
* intVecGet - get a vector
*
* This routine returns the current value of a specified exception/interrupt
* vector.  The vector is specified as an offset into the CPU's vector table.
* On SH CPUs, the vector table may be set to start at any address with the
* intVecBaseSet() routine.
*
* RETURNS: The current value of <vector>.
*
* SEE ALSO: intVecSet(), intVecBaseSet()
*/

FUNCPTR intVecGet
    (
    FUNCPTR *vector     /* vector offset */
    )
    {
    FUNCPTR vec;

    if ((vec = VXM_IF_VEC_GET (vector)) != NULL)	/* can monitor do it? */
	return vec;

    /* vector is offset by vector base address */

    return *(FUNCPTR *)((int)vector + (int)intVecBaseGet ());
    }

#if (CPU==SH7750 || CPU==SH7700)
/******************************************************************************
*
* intVecTableWriteProtect - write protect exception vector table
*
* If the unbundled mmu support package (vmLib) is present, write protect
* the exception vector table to protect it from being accidently corrupted.
* Note that other data structures contained in the page will also be
* write protected.  In the default VxWorks configuration, the exception
* vector table is located at location 0 in memory.  Write protecting this
* affects the backplane anchor, boot configuration information and potentially
* the text segment (assuming the default text location of 0x1000.)  All code
* that manipulates these structures has been modified to write enable the 
* memory for the duration of the operation.  If the user selects a different 
* address for the exception vector table, he should insure that it resides 
* in a page seperate from other writable data structures.
* 
* RETURNS: OK, or ERROR if unable to write protect memory.
*/

STATUS intVecTableWriteProtect (void)
    {
    STATUS status = ERROR;

    if (vmLibInfo.vmLibInstalled)
	{
	int pageSize = VM_PAGE_SIZE_GET ();

	if (pageSize != 0)
	    {
	    UINT virtAddr = (UINT)intVecTableWriteProtect; /* where am I? */
	    UINT vecBase  = (UINT)intVecBaseGet ();
	    UINT vecPage  = ((vecBase & 0x1fffffff) | (virtAddr & 0xe0000000))
			  / pageSize * pageSize;

	    status = VM_STATE_SET (NULL, (void *)vecPage, pageSize, 
				   VM_STATE_MASK_WRITABLE, VM_STATE_WRITABLE_NOT);
	    }
	}
    else
	errno = S_intLib_VEC_TABLE_WP_UNAVAILABLE;

    return status;
    }

/******************************************************************************
*
* intGlobalSRSet - set special bit(s) to status register values used by kernel
*
* This routine sets the specified bit(s) to every SR value used by kernel.
*
* RETURNS: OK, or ERROR
*/

STATUS intGlobalSRSet (UINT32 bits, UINT32 mask, int maxTasks)
    {
    UINT virtAddr = (UINT)intGlobalSRSet;		/* where am I? */
    UINT virtBase = ((UINT)intVecBase & 0x1fffffff) | (virtAddr & 0xe0000000);
    UINT prioTbl  = virtBase + SH7700_INT_PRIO_TABLE_OFFSET;
    UINT32 *p;
    BOOL    writeProtected = FALSE;
    int     pageSize = 0;
    char   *pageAddr = 0;
    STATUS  status = OK;

    /* modify intPrioTable[] entries */

    if (vmLibInfo.vmLibInstalled)
	{
	UINT state;

	pageSize = VM_PAGE_SIZE_GET();

	pageAddr = (char *)(prioTbl / pageSize * pageSize);

	if (VM_STATE_GET (NULL, (void *)pageAddr, &state) != ERROR)
	    {
	    if ((state & VM_STATE_MASK_WRITABLE) == VM_STATE_WRITABLE_NOT)
		{
		writeProtected = TRUE;

		VM_STATE_SET (NULL, pageAddr, pageSize,
			      VM_STATE_MASK_WRITABLE, VM_STATE_WRITABLE);
		}
	    }
	}

    for (p = (UINT32 *)prioTbl; p < (UINT32 *)(prioTbl + intPrioTableSize); p++)
	if (*p != 0) *p = (*p & mask) | (bits & ~mask);

    if (writeProtected)
	{
	VM_STATE_SET (NULL, pageAddr, pageSize, 
		      VM_STATE_MASK_WRITABLE, VM_STATE_WRITABLE_NOT);
	}

    CACHE_TEXT_UPDATE ((void *)prioTbl, intPrioTableSize);

    /* modify global SR values used by kernel */

    intLockTaskSR = (intLockTaskSR & mask) | (bits & ~mask);
    intUnlockSR   = (intUnlockSR   & mask) | (bits & ~mask);
    intBlockSR    = (intBlockSR    & mask) | (bits & ~mask);

    /* if kernel is running, we also need to take care of the existing tasks */

    if (Q_FIRST (&activeQHead) != NULL)		/* kernel is running */
	{
	int i, numTasks;
	int *idList;

	if ((idList = malloc ((maxTasks + 1) * sizeof (int))) == NULL)
	    return ERROR;

	taskLock ();				/* LOCK PREEMPTION */

	numTasks = taskIdListGet (idList, maxTasks + 1);

	if (numTasks <= maxTasks)
	    {
	    /* modify current SR value */

	    int key = intLock ();		/* LOCK INTERRUPTS */

	    intSRSet ((intSRGet () & mask) | (bits & ~mask));

	    intUnlock (key);			/* UNLOCK INTERRUPTS */

	    /* modify every task's SR value in TCB */

	    for (i = 0; i < numTasks; i++)
		{
		WIND_TCB *pTcb = (WIND_TCB *)idList[i];

		pTcb->regs.sr = (pTcb->regs.sr & mask) | (bits & ~mask);
		}
	    }
	else
	    status = ERROR;

	taskUnlock ();				/* UNLOCK PREEMPTION */

	free (idList);
	}

    return status;
    }

#endif /* CPU==SH7750 || CPU==SH7700 */

/******************************************************************************
*
* intRegsLock - modify a REG_SET to have interrupts locked
*
*/ 

int intRegsLock
    (
    REG_SET *pRegs		/* register set to modify */
    )
    {
    ULONG oldSr = pRegs->sr;

    pRegs->sr = (oldSr & 0xffffff0f) | intLockMask;

    return oldSr;
    }

/******************************************************************************
*
* intRegsUnlock - restore an REG_SET's interrupt lockout level
*
* NOTE: M/Q/S/T bits have to be preserved.
*/ 

void intRegsUnlock
    (
    REG_SET * pRegs,		/* register set to modify */
    int       oldSr		/* sr with int lock level to restore */
    )
    {
    pRegs->sr = (pRegs->sr & 0xffffff0f) | ((ULONG)oldSr & 0x000000f0);
    }
