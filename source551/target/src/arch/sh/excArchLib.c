/* excArchLib.c - SH exception handling facilities */

/* Copyright 1994-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02n,24oct01,hk   added excPciMapInit() to extend virtual PCI space on SH7751.
02m,10sep01,zl   FP exception info for _WRS_HW_FP_SUPPORT only.
02l,03sep00,hk   change excVecInit() to load VBR-relative stubs to physical
		 memory by way of their virtual address.  delete #include for
		 unreferenced headers.  simplify excBErrVecInit().
02k,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
02j,12jul00,hk   added denormalized FP exception handler for SH7750.
02i,20apr00,hk   changed sysBErrVecNum to excBErrVecNum. changed excTasRetry()
                 to call _func_excBErrIntAck instead of sysBErrIntAck(). moved
                 bus interrupt vector setup to excBErrVecInit(). changed
                 excVecInit() to copy vxMemProbeIntStub. added FUNCPTR casting
                 to intVecSet() argument to suppress compilation warning.
02h,10apr00,hk   added VBR relative loading of intPrioTable, excBErrStub,
                 vxMemProbeTrap. adjusted intVecSet() for sysBErrVecNum.
02g,15sep98,hk   unified SH7750_ macros to SH7700_ macros. simplified SH7750
		 conditional code in excGetInfoFromFSF().
02f,16jul98,st   added SH7750 support.
02f,07may98,jmc  added support for SH-DSP and SH3-DSP.
02f,12may98,hk   supported FPSCR on ESFSH. moved fppSave to excGetInfoFromESF.
02d,26nov97,hms  add fppLib support operation.
02e,04jan98,hk   fixed range check for sysBErrVecNum.
02d,25nov97,hk   changed to use sequential interrupt vector number for SH7700.
02c,01may97,hk   made windview instrumentation conditionally compiled.
02b,28apr97,hk   changed SH704X to SH7040.
02b,07mar97,st   added for windview
02a,17feb97,hk   deleted mmuEnabled reference from excGetInfoFromESF().
01z,17feb97,hk   improved excGetInfoFromESF() for SH7700 to distinguish trap
                 events from other exceptions. restored previous vector range
                 for valid access address.
01y,16feb97,hk   deleted intVecSet() for INUM_SPURIOUS_INTERRUPT. merged zero
                 divide trap init to loop. added null check for sysBErrVecNum.
                 changed vector range for valid aa in excGetInfoFromESF().
01x,09feb97,hk   changed excGetInfoFromESF() to get info from ESFSH for SH7700.
                 changed zero divide trap num to 1 in excVecInit() for SH7700.
01w,28jan97,hk   added casting to suppress compiler warnings (not complete).
01v,28jan97,hk   added notes on excVecInit().
01u,18jan97,hk   validate EXC_ACCESS_ADDR if mmu is on.
01t,15nov96,wt   changed excStub to mmuStub as TLB miss handler.
01s,17sep96,hk   restored intVecSet() for excExcHandle, added excBErrStub setup.
01r,02sep96,hk   deleted intVecSet() for excExcHandle, now it's called directly.
01q,22aug96,hk   changed to use '#if 0' for disabling excRegsShow().
01p,19aug96,hk   added INUM_SPURIOUS_INTERRUPT, changed zero div. to 254.
01o,19aug96,hk   changed excGetInfoFromESF for SH7700 to get sr/pc from pRegs.
01n,13aug96,hk   changed to call excIntStub for uninitialized interrupts.
01m,09aug96,hk   made excVecInit() for SH7700 to looping style.
01l,09aug96,hk   added 'trapa #0' vector set for SH7700 to excVecInit.
01k,08aug96,hk   changed SH7700_OFF_xxx according to new ivSh.h(01t).
01j,04aug96,hk   changed code layout.
01i,29jul96,ja   added exception vector table initialization for SH7700.
01h,29jul96,hk   deleted intStub copy in excVecInit(), made excLib removable.
01g,11jul96,ja   added support for SH7700 in excVecInit.
01f,13jun96,hk   added support for SH7700.
01e,21may96,hk   workarounded excVecInit() for SH7700 build.
01d,01apr95,hk   added INTERNAL comment for excVecInit.
01c,27mar95,hk   added bus error support, copyright 1995.
01b,30oct94,hk   restored 68k code, adjusted for SH. faked excTasRetry().
01a,18jul94,hk   derived from 03f of 68k. Just a stub.
*/

/*
This module contains SH architecture dependent portions of the
exception handling facilities.  See excLib for the portions that are
architecture independent.

SEE ALSO: dbgLib, sigLib, intLib, "Debugging"
*/

#include "vxWorks.h"
#include "cacheLib.h"		/* for CACHE_TEXT_UPDATE() */
#include "esf.h"
#include "iv.h"
#include "sysLib.h"		/* for BOOT_WARM_AUTOBOOT */
#include "intLib.h"		/* for intVecSet() */
#include "qLib.h"		/* for Q_FIRST() */
#include "string.h"		/* for bcopy() */
#include "rebootLib.h"		/* for reboot() */
#include "excLib.h"
#include "private/eventP.h"	/* for EVT_CTX_1() */
#include "private/funcBindP.h"
#include "private/kernelLibP.h"	/* for activeQHead */
#include "private/taskLibP.h"	/* for pTaskLastFpTcb, and taskLib.h */
#include "fppLib.h"		/* for fppSave(), fppExcHandle() */
#include "taskLib.h"		/* for taskIdCurrent, taskIdDefault() */

/* imports */

#if (CPU==SH7750 || CPU==SH7700)
IMPORT void   excIntStub (int vecNum);	/* excALib */
IMPORT void   excBErrStub (int vecNum);	/* excALib */
IMPORT UINT32 excBErrStubSize;		/* excALib */
IMPORT void   vxMemProbeIntStub (void);	/* vxALib  */
IMPORT UINT32 vxMemProbeIntStubSize;	/* vxALib  */
#endif

/* globals */

void (* _func_excBErrIntAck)(void) = NULL;

int excBErrVecNum = NONE;	/* for excALib, excArchShow, and sigLib */
#if (CPU==SH7750)
UINT32 excMmuCrVal = 0;		/* for mmuSh7750Lib.c */
#endif /* CPU==SH7750 */

/* local variables */

LOCAL int excTasErrors;		/* count of TAS bus errors - just curiosity */

/* forward global function prototypes (accessed from external assembly code)*/

void excExcHandle (int vecNum, ESFSH * pEsf, REG_SET * pRegs);

/* forward static function prototypes */

LOCAL BOOL excTasRetry (int vecNum, ESFSH *pEsf, REG_SET *pRegs);
LOCAL void excGetInfoFromESF (int vecNum, ESFSH *pEsf, REG_SET *pRegs,
				   EXC_INFO *pExcInfo);

/******************************************************************************
*
* excVecInit - initialize the exception/interrupt vectors
*
* This routine sets all exception vectors to point to the appropriate
* default exception handlers.  These handlers will safely trap and report
* exceptions caused by program errors or unexpected hardware interrupts.
* All vectors from vector 2 (address 0x0008) to 255 (address 0x03fc) are
* initialized.  Vectors 0 and 1 contain the reset stack pointer and program
* counter.
*
* WHEN TO CALL
* This routine is usually called from the system start-up routine
* usrInit() in usrConfig, before interrupts are enabled.
*
* RETURNS: OK, or ERROR.
*/

STATUS excVecInit (void)
    {
    STATUS status = OK;		/* OK is 0, so we can record ERROR(-1) by OR */
    int vecNum;

#if (CPU==SH7750 || CPU==SH7700)
    UINT virtAddr = (UINT)excVecInit;			/* where am I? */
    UINT virtBase;
    UINT vecAddr;

    virtBase = ((UINT)intVecBaseGet() & 0x1fffffff) | (virtAddr & 0xe0000000);

    /* load bus error stub */

    vecAddr = virtBase + SH7700_EXC_BERR_STUB_OFFSET;
    bcopy ((char *)excBErrStub, (char *)vecAddr, excBErrStubSize);
    status |= CACHE_TEXT_UPDATE ((void *)vecAddr, excBErrStubSize);

    /* load vxMemProbeIntStub */

    vecAddr = virtBase + SH7700_MEMPROBE_INT_STUB_OFFSET;
    bcopy ((char *)vxMemProbeIntStub, (char *)vecAddr, vxMemProbeIntStubSize);
    status |= CACHE_TEXT_UPDATE ((void *)vecAddr, vxMemProbeIntStubSize);

    /* load exception handling stub */

    vecAddr = virtBase + SH7700_EXC_STUB_OFFSET;
    bcopy ((char *)excStub, (char *)vecAddr, excStubSize);
    status |= CACHE_TEXT_UPDATE ((void *)vecAddr, excStubSize);

    /* load TLB mishit handling stub */

    vecAddr = virtBase + SH7700_TLB_STUB_OFFSET;
    bcopy ((char *)mmuStub, (char *)vecAddr, mmuStubSize);
    status |= CACHE_TEXT_UPDATE ((void *)vecAddr, mmuStubSize);

    /* initialize virtual exception vector table */

    for (vecNum = INUM_EXC_LOW; vecNum <= INUM_EXC_HIGH; ++vecNum)
	intVecSet ((FUNCPTR *)INUM_TO_IVEC(vecNum), (FUNCPTR)excExcHandle);

    intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_NMI), (FUNCPTR)excIntStub);

    /* set uninitialized interrupt handler */

    for (vecNum = INUM_INTR_LOW; vecNum <= INUM_INTR_HIGH; ++vecNum)
	intVecSet ((FUNCPTR *)INUM_TO_IVEC(vecNum), (FUNCPTR)excIntStub);

    /* set uninitialized trap handler */

    for (vecNum = INUM_TRAP_128; vecNum <= INUM_TRAP_255; ++vecNum)
	intVecSet ((FUNCPTR *)INUM_TO_IVEC(vecNum), (FUNCPTR)excExcHandle);

#elif (CPU==SH7600 || CPU==SH7000)

    /* make exception vectors point to proper place in bsr table */

    for (vecNum = LOW_VEC; vecNum <= HIGH_VEC; ++vecNum)
	intVecSet ((FUNCPTR *)INUM_TO_IVEC(vecNum),(FUNCPTR)&excBsrTbl[vecNum]);

#endif /* CPU==SH7600 || CPU==SH7000 */

    return status;
    }

#if (CPU==SH7750)
/******************************************************************************
*
* excPciMapInit - initialize the virtual PCI space mapping (SH7751 only)
*
* This routine installs a special TLB mishit exception handler which virtually
* extends the limited PCI window size of SH7751.  The original PCI window size
* is 16MB for memory space and 256KB for IO space, but this new handler allows
* you to extend them to an any multiple of the original window size. The first
* three arguments describe the mapping of PCI memory space, and their every
* lower 24 bits are discarded to force 16MB (0x1000000) alignment.  The last
* three arguments describe the mapping of PCI IO space, and their every lower
* 18 bits are discarded to force 256KB (0x40000) alignment.  These virtual PCI
* space descriptions and sysPhysMemDesc[] entries should not overlap.
* If you set ioSpaceSize to zero, the PCI IO space support is removed from
* the new TLB mishit handler to give a better performance over the non-PCI
* virtual space.  However the removal of PCI memory space support is not
* implemented so that you should not set memSpaceSize to zero.
* The virtual PCI page attribute is fixed to read/writable and non-cacheable,
* and the page size is 1MB on PCI memory space, and 64KB on PCI IO space.
*
* WHEN TO CALL
* This routine overwrites the default TLB mishit handler and it tells
* mmuSh7750LibInit() to reserve some UTLB entries for virtual PCI mapping.
* Therefore it must be called after excVecInit(), and before usrMmuInit().
*
* RETURNS: ERROR if memSpaceSize is zero or virtual spaces overlap,
*          OK otherwise.
*/

STATUS excPciMapInit
    (
    void *memCpuAddr,		/* CPU address of virtual PCI memory space */
    void *memBusAddr,		/* PCI bus address for PCI memory space */
    UINT  memSpaceSize,		/* byte length of PCI memory space */
    void *ioCpuAddr,		/* CPU address of virtual PCI IO space */
    void *ioBusAddr,		/* PCI bus address for PCI IO space */
    UINT  ioSpaceSize		/* byte length of PCI IO space */
    )
    {
    UINT paramAddr;
    UINT vecAddr =(((UINT)intVecBaseGet() & 0x1fffffff) |
		   ((UINT)excPciMapInit & 0xe0000000)) + SH7700_TLB_STUB_OFFSET;

    if (memSpaceSize == 0)
	return ERROR;				/* unsupported */

    if (!(ioCpuAddr >= memCpuAddr + memSpaceSize ||
	  memCpuAddr >= ioCpuAddr + ioSpaceSize))
	return ERROR;				/* overlap in virtual space */

    /* install PCI memory space handler */
	{
	bcopy ((char *)mmuPciStub, (char *)vecAddr, mmuPciStubSize);

	/* setup PCI memory space parameters */

	paramAddr = vecAddr + mmuPciStubParams;

	*(UINT32 *)(paramAddr + 0) = (UINT32)memCpuAddr & 0xff000000;
	*(UINT32 *)(paramAddr + 4) =((UINT32)memCpuAddr & 0xff000000) +
					  (memSpaceSize & 0xff000000);
	*(UINT32 *)(paramAddr + 8) =((UINT32)memBusAddr & 0xff000000) -
				    ((UINT32)memCpuAddr & 0xff000000);

	CACHE_TEXT_UPDATE ((void *)vecAddr, mmuPciStubSize);
	vecAddr += mmuPciStubSize;
	}

    /* concatenate PCI IO space handler if necessary */

    if (ioSpaceSize)
	{
	bcopy ((char *)mmuPciIoStub, (char *)vecAddr, mmuPciIoStubSize);

	/* setup PCI IO space parameters */

	paramAddr = vecAddr + mmuPciIoStubParams;

	*(UINT32 *)(paramAddr + 0) = (UINT32)ioCpuAddr & 0xfffc0000;
	*(UINT32 *)(paramAddr + 4) =((UINT32)ioCpuAddr & 0xfffc0000) +
					  (ioSpaceSize & 0xfffc0000);
	*(UINT32 *)(paramAddr + 8) =((UINT32)ioBusAddr & 0xfffc0000) -
				    ((UINT32)ioCpuAddr & 0xfffc0000);

	CACHE_TEXT_UPDATE ((void *)vecAddr, mmuPciIoStubSize);
	vecAddr += mmuPciIoStubSize;
	}

    /* terminate PCI space handler with proper TLB mishit part */
	{
	bcopy ((char *)mmuStubProper, (char *)vecAddr, mmuStubProperSize);

	CACHE_TEXT_UPDATE ((void *)vecAddr, mmuStubProperSize);
	}

    /* tell mmuSh7750LibInit() to reserve some UTLB entries for PCI space */

    excMmuCrVal = ioSpaceSize ? 0x00fb0104 : 0x00fc0104;
					/* MMUCR: URB=62/63 SV=1 TI=1 AT=0 */
    return OK;
    }
#endif /* CPU==SH7750 */

/******************************************************************************
*
* excBErrVecInit - initialize the bus error interrupt vector
*
* This routine sets the specified bus error interrupt vector to point to
* a special bridge-routine to emulate a bus error exception.  The SH
* architecture does not have a bus error exception, but some boards could
* detect a VME bus timeout error and report it to CPU using interrupt
* mechanism.  To treat this type of interrupt as an exception, BSP should call
* this routine to specify the bus error interrupt vector.  Also the interrupt
* acknowledge function pointer _func_excBErrIntAck must be initialized by BSP.
* Then the interrupt is treated as an exception, and the handler run in the
* context of offending task.
*
* WHEN TO CALL
* This routine may be called from sysHwInit2() in BSP, if necessary.
*
* RETURNS: OK if specified vector is valid, ERROR otherwise.
*/

STATUS excBErrVecInit
    (
    int inum
    )
    {
    STATUS status = ERROR;

    /* set global variable to specify bus error interrupt vector number */

    excBErrVecNum = inum;

    /* set bus error emulation vector */

#if (CPU==SH7750 || CPU==SH7700)

    if ((inum >= INUM_INTR_LOW && inum <= INUM_INTR_HIGH) || inum == INUM_NMI)
	{
	UINT vecAddr = (UINT)intVecBaseGet () + SH7700_EXC_BERR_STUB_OFFSET;

	intVecSet ((FUNCPTR *)INUM_TO_IVEC (inum), (FUNCPTR)vecAddr);
	status = OK;
	}

#elif (CPU==SH7600 || CPU==SH7000)

    if ((inum > INUM_USER_BREAK && inum <= HIGH_VEC) || inum == INUM_NMI)
	{
	intVecSet ((FUNCPTR *)INUM_TO_IVEC (inum), (FUNCPTR)excBsrTblBErr);
	status = OK;
	}

#endif /* CPU==SH7600 || CPU==SH7000 */

    return status;
    }

/******************************************************************************
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
    int		vecNum,	/* exception vector number */
    ESFSH *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    EXC_INFO excInfo;

#if (CPU==SH7750)
    /* see if denormalized number exception */

    if ((vecNum == INUM_FPU_EXCEPTION) && (fppExcHandle (pEsf, pRegs) == OK))
	return;
#endif
    excGetInfoFromESF (vecNum, pEsf, pRegs, &excInfo);  /* fill excInfo/pRegs */

    if ((_func_excBaseHook != NULL) &&			/* user hook around? */
	((* _func_excBaseHook) (vecNum, pEsf, pRegs, &excInfo)))
	return;						/* user hook fixed it */

    if ((excBErrVecNum != NONE) && (vecNum == excBErrVecNum) &&
	excTasRetry (vecNum, pEsf, pRegs))
	return;						/* retry the TAS */

#ifdef WV_INSTRUMENTATION
    /* windview - level 3 event logging */
#if (CPU==SH7750 || CPU==SH7700)
    EVT_CTX_1(EVENT_EXCEPTION, INUM_TO_IEVT (vecNum));
#elif (CPU==SH7600 || CPU==SH7000)
    EVT_CTX_1(EVENT_EXCEPTION, vecNum);
#endif
#endif

    /* if exception occured in an isr or before multi tasking then reboot */

    if ((INT_CONTEXT ()) || (Q_FIRST (&activeQHead) == NULL))
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

    /* CAUTION: pRegs is invalid after calling _func_sigExcKill. */

    if (_func_sigExcKill != NULL)			/* signals installed? */
	(*_func_sigExcKill) (vecNum, INUM_TO_IVEC(vecNum), pRegs);

    if (_func_excInfoShow != NULL)			/* default show rtn? */
	(*_func_excInfoShow) (&excInfo, TRUE);

    if (excExcepHook != NULL)				/* 5.0.2 hook? */
	(* excExcepHook) (taskIdCurrent, vecNum, pEsf);

    taskSuspend (0);					/* whoa partner... */

    taskIdCurrent->pExcRegSet = (REG_SET *) NULL;	/* invalid after rts */
    }

/******************************************************************************
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

void excIntHandle
    (
    int		vecNum,	/* exception vector number */
    ESFSH *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    EXC_INFO excInfo;

    excGetInfoFromESF (vecNum, pEsf, pRegs, &excInfo);	/* fill excInfo/pRegs */

#ifdef WV_INSTRUMENTATION
    /* windview - level 3 event logging */
#if (CPU==SH7750 || CPU==SH7700)
    EVT_CTX_1(EVENT_EXCEPTION, INUM_TO_IEVT (vecNum));
#elif (CPU==SH7600 || CPU==SH7000)
    EVT_CTX_1(EVENT_EXCEPTION, vecNum);
#endif
#endif
    
    if (_func_excIntHook != NULL)
	(*_func_excIntHook) (vecNum, pEsf, pRegs, &excInfo);

    if (Q_FIRST (&activeQHead) == NULL)			/* pre kernel */
	reboot (BOOT_WARM_AUTOBOOT);			/* better reboot */
    }

/******************************************************************************
*
* excGetInfoFromESF - get relevent info from exception stack frame
*
* NOMANUAL
*
* <SH7700 exception case, it differs if interrupt>
*
*           |_____________|        _______
*           |TRA/TEA/FPSCR| 96  +12        ESFSH.info (JUNK if interrupt)
*           |   EXPEVT    | 92  +8 _____   ESFSH.event (not saved, use vecNum)
*           |     ssr     | 88  +4   ^     ESFSH.sr
*  pEsf --> |     spc     | 84  +0   | ___ ESFSH.pc
*           |     r15     | 80       |
*           |     r14     | 76       |
*           |     r13     | 72       |
*           |     r12     | 68       |
*           |     r11     | 64       |
*           |     r10     | 60       |
*           |     r9      | 56       |
*           |     r8      | 52       |
*           |    macl     | 48       |
*           |    mach     | 44    REG_SET
*           |     r7      | 40       |
*           |     r6      | 36       |
*           |     r5      | 32       |
*           |     r4      | 28       |
*           |     r3      | 24       |
*           |     r2      | 20       |			_________________
*           |     r1      | 16       |			|_____pad_______|
*           |     r0      | 12       |			|_____info______|
*           |     pr      |  8       |			|______sr_______|
*           |     gbr     |  4       |			|______pc_______| 
*  pRegs -> |____ vbr ____|  0  _____v__  pExcInfo ---> |_valid_|_vecNum|
*           |             |
*/

LOCAL void excGetInfoFromESF
    (
    FAST int	vecNum,		/* vector number */
    FAST ESFSH *pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs,		/* pointer to register info on stack */
    EXC_INFO *	pExcInfo	/* where to fill in exception info */
    )
    {
#if (CPU==SH7750 || CPU==SH7700)

    pExcInfo->valid	= EXC_VEC_NUM | EXC_PC | EXC_STATUS_REG;
    pExcInfo->vecNum	= vecNum;
    pExcInfo->pc	= ((ESFSH *)pEsf)->pc;
    pExcInfo->sr	= ((ESFSH *)pEsf)->sr;
    pExcInfo->info	= ((ESFSH *)pEsf)->info;

    if (((ESFSH *)pEsf)->event == (INUM_TO_IEVT (INUM_TRAPA_INSTRUCTION)))
	{
	pExcInfo->valid |= EXC_TRAP;
	}
    else if ((vecNum>=INUM_TLB_READ_MISS) && (vecNum<=INUM_WRITE_ADDRESS_ERROR))
	{
	pExcInfo->valid |= EXC_ACCESS_ADDR;
	}
#ifdef _WRS_HW_FP_SUPPORT
    else if (vecNum == INUM_FPU_EXCEPTION)
	{
	pExcInfo->valid |= EXC_FPSCR;

	if (pTaskLastFpTcb != NULL) fppSave (pTaskLastFpTcb->pFpContext);
	}
#endif

#if (CPU==SH7750)
    else if (vecNum==INUM_TLB_MULTIPLE_HIT)
	{
	pExcInfo->valid |= EXC_ACCESS_ADDR;
	}
#endif /* CPU==SH7750 */

#elif (CPU==SH7600 || CPU==SH7000)

    int size = sizeof (ESFSH);

    pExcInfo->valid	= EXC_VEC_NUM | EXC_PC | EXC_STATUS_REG;
    pExcInfo->vecNum	= vecNum;
    pExcInfo->pc	= ((ESFSH *)pEsf)->pc;
    pExcInfo->sr	= ((ESFSH *)pEsf)->sr;

    pRegs->spReg = (ULONG)((char *) pEsf + size);       /* bump up stack ptr */

#endif /* CPU==SH7600 || CPU==SH7000 */
    }

/******************************************************************************
*
* excTasRetry - retry a TAS instruction
*
* If this was a bus error involving a RMW cycle (TAS instruction) we
* return to the handler to retry it.  Such is the case in a vme
* bus deadlock cycle, where the local CPU initiates a TAS instuction
* (or RMW cycle) at the same time it's dual port arbiter grants the local bus
* to an external access.  The cpu backs off by signaling a bus error and
* setting the RM bit in the special status word of the bus error exception
* frame.  The solution is simply to retry the instruction hoping that the
* external access has been resolved.  Even if a card such as a disk controller
* has grabed the bus for DMA accesses for a long time, the worst that will
* happen is we'll end up back here again, and we can keep trying until we get
* through.
*
* RETURNS: TRUE if retry desired, FALSE if not TAS cycle.
* NOMANUAL
*/

LOCAL BOOL excTasRetry
    (
    int		vecNum,		/* exception vector number */
    ESFSH *	pEsf,		/* pointer to exception stack frame */
    REG_SET *	pRegs		/* pointer to register info on stack */
    )
    {
    if (_func_excBErrIntAck != NULL)
	(* _func_excBErrIntAck) ();

    if (0)	/* XXX how to identify the TAS cycle with SH??? */
	{
	++excTasErrors;				/* keep count of TAS errors */
	return (TRUE);				/* retry the instruction */
	}
    
    return (FALSE);
    }
