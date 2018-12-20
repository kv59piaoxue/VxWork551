/* sigCtxLib.c - software signal architecture support library */

/* Copyright 1984-1996 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01n,22nov02,mil  Added SPE exception for PPC85XX.
01m,15aug01,pch  Change test for CPU==PPC4xx to ifdef _PPC_MSR_CE,
		 & clean up handling of _PPC_MSR_FP
01l,25oct00,s_m  renamed PPC405 cpu types
01k,06oct00,sm   PPC405 FPU & MMU support
01j,20mar97,tam  turn PPC403 MSR[CE] bit on in _sigCtxSetup() (SPR 8192). 
01i,14feb97,tam  changed test when setting MSR[FP] in sigCtxSetup()
01h,16apr96,tpr  decoupled _EXC_OFF_INST_MISS, _EXC_OFF_LOAD_MISS and
		 _EXC_OFF_STORE_MISS excpetion in _sigfaulttable.
01g,06mar96,tpr	 removed SDA.
01f,27feb96,ms   fixed _sigfaulttable to allow exception->signal mapping.
01e,21jan96,tpr  replaced taskMsrDefault by a dynamic value setting.
01d,16jun95,caf  initialized r2 and r13 according to EABI standard,
		 removed AIX references.
01a,30may95,bdl  written.
*/

/*
This library provides the architecture specific support needed by
software signals.
*/

#include "vxWorks.h"
#include "private/sigLibP.h"
#include "string.h"
#include "taskLib.h"
#include "arch/ppc/vxPpcLib.h"

extern	taskMsrDefault;

#if	FALSE				/* XXX TPR SDA not support yet */
IMPORT char * _SDA2_BASE_;
IMPORT char * _SDA_BASE_;
#endif

struct sigfaulttable _sigfaulttable [] =
    {
	{_EXC_OFF_MACH, SIGBUS},

#ifdef  _EXC_OFF_INST
	{_EXC_OFF_INST, SIGBUS},
#endif

	{_EXC_OFF_ALIGN, SIGBUS},
	{_EXC_OFF_PROG, SIGILL},

#ifdef	_EXC_OFF_DATA
	{_EXC_OFF_DATA, SIGBUS},
#else
#ifdef	_EXC_OFF_PROT	/* PPC405 */
        {_EXC_OFF_PROT, SIGBUS},
#endif
#endif

#ifdef	_EXC_OFF_FPU
	{_EXC_OFF_FPU, SIGFPE},
#endif

#ifdef	_EXC_OFF_SPE
	{_EXC_OFF_SPE, SIGFPE},
#endif

#ifdef	_EXC_OFF_DBG
	{_EXC_OFF_DBG, SIGTRAP},
#endif

#ifdef	_EXC_OFF_INST_BRK
	{_EXC_OFF_INST_BRK, SIGTRAP},
#endif

#ifdef	_EXC_OFF_TRACE
	{_EXC_OFF_TRACE, SIGTRAP},
#endif

#ifdef	_EXC_OFF_RUN_TRACE
	{_EXC_OFF_RUN_TRACE, SIGTRAP},
#endif

#ifdef	_EXC_OFF_DATA_MISS
	{_EXC_OFF_DATA_MISS, SIGSEGV},
#endif

#ifdef	_EXC_OFF_INST_MISS
	{_EXC_OFF_INST_MISS, SIGSEGV},
#endif

#ifdef	_EXC_OFF_LOAD_MISS
	{_EXC_OFF_LOAD_MISS, SIGSEGV},
#endif

#ifdef	_EXC_OFF_STORE_MISS
	{_EXC_OFF_STORE_MISS, SIGSEGV},
#endif

#ifdef	_EXC_OFF_CRTL
	{_EXC_OFF_CRTL, SIGBUS},
#endif

#ifdef	_EXC_OFF_SYSCALL
	{_EXC_OFF_SYSCALL, SIGILL},
#endif

	{0,  0 },
    };

/*******************************************************************************
*
* _sigCtxRtnValSet - set the return value of a context
*
* Set the return value of a context.
* This routine should be almost the same as taskRtnValueSet in taskArchLib.c
*/

void _sigCtxRtnValSet
    (
    REG_SET		*pRegs,
    int			val
    )
    {
    pRegs->gpr[3] = val;
    }


/*******************************************************************************
*
* _sigCtxStackEnd - get the end of the stack for a context
*
* Get the end of the stack for a context, the context will not be running.
* If during a context switch, stuff is pushed onto the stack, room must
* be left for that (on the 68k the fmt, pc, and sr are pushed just before
* a ctx switch)
*/

void *_sigCtxStackEnd
    (
    const REG_SET	*pRegs
    )
    {
    return (void *)(pRegs->gpr[1]);
    }

/*******************************************************************************
*
* _sigCtxSetup - Setup of a context
*
* This routine will set up a context that can be context switched in.
* <pStackBase> points beyond the end of the stack. The first element of
* <pArgs> is the number of args to call <taskEntry> with.
* When the task gets swapped in, it should start as if called like
*
* (*taskEntry) (pArgs[1], pArgs[2], ..., pArgs[pArgs[0]])
*
* This routine is a blend of taskRegsInit and taskArgsSet.
*
* Currently (for signals) pArgs[0] always equals 1, thus the task should
* start as if called like
* (*taskEntry) (pArgs[1]);
*
* Furthermore (for signals), the function taskEntry will never return.
* For the 68k case, we push vxTaskEntry() onto the stack so a stacktrace
* looks good.
*/

void _sigCtxSetup
    (
    REG_SET		*pRegs,
    void		*pStackBase,
    void		(*taskEntry)(),
    int			*pArgs
    )
    {
    FAST int *sp;
    FAST int regNum;
    FAST int ix;

    bzero ((char *) pRegs, sizeof (REG_SET));

    pRegs->msr = vxMsrGet() | _PPC_MSR_EE	/* turn on the External Inter */
#ifdef	_PPC_MSR_CE
			    | _PPC_MSR_CE	/* turn on the Critical Intr */
#endif /* _PPC_MSR_CE */
#ifdef	_PPC_MSR_FP
			    | _PPC_MSR_FP	/* turn on the floating point */
#endif /* _PPC_MSR_FP */
			    | _PPC_MSR_ME;	/* turn on the Machine Check */

    pRegs->pc = (_RType)taskEntry;

    pRegs->spReg = (_RType) (STACK_ROUND_DOWN((int)pStackBase -
                                (MAX_TASK_ARGS * sizeof (int))));

#if	FALSE			/* XXX TPR SDA not supported yet */
    /* initialize R2 and R13 (small data area pointer(s)) */

    pRegs->gpr[2] =  (_RType) &_SDA2_BASE_;
    pRegs->gpr[13] = (_RType) &_SDA_BASE_;
#endif	/* FALSE */

    sp = (int *) pStackBase; /* start at bottom of stack */
 
    for (ix = 0; ix < MAX_TASK_ARGS; ix++)
        *--sp = pArgs[ix];              /* put arguments onto stack */
 
    for (ix = 0, regNum = PPC_ARG0_REG; ix < PPC_MAX_ARG_REGS; ix ++)
        pRegs->gpr[regNum ++] = pArgs[ix + 1];
    }
