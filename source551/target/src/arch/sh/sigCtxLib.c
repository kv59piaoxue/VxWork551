/* sigCtxLib.c - software signal architecture support library */

/* Copyright 1994-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01t,24oct01,zl   fixes for doc builds.
01s,30aug00,hk   change _sigCtxSetup() to import intUnlockSR (ex-brandNewTaskSR)
01r,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
01q,16jul98,st   added SH7750 support.
01q,08may98,jmc  added support for SH-DSP and SH3-DSP.
01q,26nov97,hms  added fpp support definition.
01p,18may97,hk   changed last _sigfaulttable[] member to {0,0} from {0,SIGILL}.
01o,25apr97,hk   changed SH704X to SH7040.
01n,03mar97,hk   fixed _sigCtxStackEnd for SH7700 to just return sp.
01m,09aug96,hk   added FPE_INTDIV_TRAP for SH7700.
01l,08aug96,hk   added more signals for SH7700.
01k,04aug96,hk   enabled ILL_xxx for SH7700.
01j,21may96,hk   workarounded _sigfaulttable for SH7700 build.
01i,15nov95,hk   changed _sigfaulttable[] to use definitions in sigCodes.h.
01h,23may95,hk   saved stack space by fixing _sigCtxStackEnd.
01g,01apr95,hk   changed _sigfaulttable member to use INUM_ directly.
01f,31mar95,hk   added INT_NMI entry to _sigfaulttable.
01e,16mar95,hk   added picture, some refinements.
01d,15mar95,hk   initial functional version.
01c,07mar95,hk   wrote body.
01b,28feb95,hk   adding arch port kit docs. copyright 1995.
01a,08oct94,hk   written based on sparc 01f.
*/

/*
This library provides the architecture specific support needed by
software signals.

[APK]
The architecture-dependent signal library contains routines that support the
architecture-independent sigLib.c.  The complex portions of the signal support
has been abstracted.  The signal support should be modeled after the context
switch code in windExit() and windLoadContext(), and various tasking routines.
*/

/* includes */

#include "vxWorks.h"
#include "private/sigLibP.h"
#include "string.h"
#include "sigCodes.h"

/* defines */

#define	SIG_STACK_ARGS		((pArgs[0] > 4) ? pArgs[0] - 4 : 0)


/* [APK]
 * The table of signal handlers is a subset of the vector table.  The exceptions
 * defined by the hardware should be matched with a handler if possible.  The
 * example below is not for any particular architecture, but is merely and
 * example of common signals.
 *
 * struct sigfaulttable _sigfaulttable [] =
 *     {
 *     {ILLEGAL_INSTRUCTION,SIGILL},		{sigf_fault,     sigf_signo},
 *     {DATA_ACCESS_ERROR,  SIGBUS},
 *     {MMU_VIOLATION,      SIGSEGV},
 *     {FPU_DISABLED,       SIGFPE},
 *     {FPU_EXCEPTION,      SIGFPE},
 *     {COPROCESSOR_ERROR,  SIGILL},
 *     <additional offsets and handlers>
 *     };
 *
 * NOTE:  This table is referenced only from `sigExcKill()' in sigLib.c.
 *        Here the last member {0, 0} is mandatory as the table terminator.
 *        The bus timeout error is not registered in `_sigfaulttable[]', and
 *        it is directly handled in `sigExcKill()'.  In the shell context,
 *        all signals are caught by the `shellSigHandler()', and it restarts
 *        the shell regardless of signal number.  On the dve7604 board, the
 *        VME bus error is reported to SH7604 CPU as an interrupt request.
 *        Typically the NMI is used for this purpose, and it leads to send
 *        SIGBUS to shell task, then the shell is automatically restarted
 *        by shellSigHandler.
 */
struct sigfaulttable _sigfaulttable [] =
    {
#if (CPU==SH7750 || CPU==SH7700)
    {TLB_LOAD_MISS,		SIGSEGV},
    {TLB_STORE_MISS,		SIGSEGV},
    {TLB_INITITIAL_PAGE_WRITE,	SIGSEGV},
    {TLB_LOAD_PROTEC_VIOLATION,	SIGSEGV},
    {TLB_STORE_PROTEC_VIOLATION,SIGSEGV},
    {BUS_LOAD_ADDRESS_ERROR,	SIGBUS},
    {BUS_STORE_ADDRESS_ERROR,	SIGBUS},
    {FPU_EXCEPTION,		SIGFPE},
    {ILLEGAL_INSTR_GENERAL,	SIGILL},
    {ILLEGAL_SLOT_INSTR,	SIGILL},
    {FPE_INTDIV_TRAP,		SIGFPE},
#elif (CPU==SH7600 || CPU==SH7000)
    {ILL_ILLINSTR_GENERAL,	SIGILL},
    {ILL_ILLINSTR_SLOT,		SIGILL},
    {BUS_ADDERR_CPU,		SIGBUS},
    {BUS_ADDERR_DMA,		SIGBUS},
    {FPE_INTDIV_TRAP,		SIGFPE},
#endif
    {0,				0},
    };

/******************************************************************************
*
* _sigCtxRtnValSet - set the return value of a context
*
* Set the return value of a context.
* This routine should be almost the same as taskRtnValueSet in taskArchLib.c
*
* [APK]
* This one-line function sets the register for return values to the second input
* argument.  The first argument is a pointer to the REG_SET in the task's TCB.
*/

void _sigCtxRtnValSet
    (
    REG_SET *pRegs,
    int      val
    )
    {
    pRegs->voreg[0] = val;
    }

/******************************************************************************
*
* _sigCtxStackEnd - get the end of the stack for a context
*
* Get the end of the stack for a context, the context will not be running.
* If during a context switch, stuff is pushed onto the stack, room must
* be left for that (on the 68k the fmt, pc, and sr are pushed just before
* a ctx switch)
*
* [APK]
* This function returns the stack pointer for the task, whose type is a void.
* The input argument is a pointer to the REG_SET in the task's TCB.
*
* NOTE:  This routine is only called from sigWindPendKill in sigLib.c.
*	 The sigWindPendKill builds a sigcontext structure on this return
*	 address (pCtx), then passes it to _sigCtxSetup as pStackBase.
*/

void *_sigCtxStackEnd
    (
    const REG_SET * pRegs
    )
    {
#if (CPU==SH7750 || CPU==SH7700)
    return (void *)(pRegs->nvreg[7]);
#elif (CPU==SH7600 || CPU==SH7000)
    /*
     * The 8 is pad for the pc and sr which are pushed onto the stack.
     */
    return (void *)(pRegs->nvreg[7] - 8);
#endif /* CPU==SH7600 || CPU==SH7000 */

#if FALSE
    /*
     * The 8 is pad for the pc and sr which are pushed onto the stack.
     * The (sizeof(REG_SET) + 32) is size of sigcontext, see sigLibP.h.
     */
    return (void *)(pRegs->nvreg[7] - (sizeof(REG_SET) + 32) - 8);
    /*           = (pRegs->nvreg[7] - (92 + 32) - 8)
     *           = (pRegs->nvreg[7] - 132)
     */
#endif /* FALSE */
    }

/******************************************************************************
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
*
* [APK]
* The signal context set up function is a combination of the taskRegsInit()
* and taskArgsSet() routines.  The program counter is set to the task entry
* input argument, and all other control registers should be set to their
* taskRegsInit() values.  The general-purpose registers should be initialized
* to match the input argument list.  A pointer to the REG_SET for the signal
* context is the first argument to this funcition.
*
* The stack pointer argument is used to create the signal stack frame, which
* contains the REG_SET initialized by this routine.  The stack frame created
* is beyond the end of the task stack.  The stack/frame pointers must be set
* to accommodate the registers and other stack-based structures for the
* architecture.
*
* NOTE:
* This routine is only called from sigWindPendKill, in case of delivering a
* signal to other task.
*
* INTERNAL
*
*          <target task's TCB>              <target task's stack>
* 
*          |                 |         |                                |
*          |                 |         |             used               |
*          |_________________|         |________________________________| <---+
*          | sr = 0x00000000 |         |        (slot for sr)           |     |
*          | pc = sigWrapper |         |_______ (slot_for_pc) __________|____ |
*          | sp -------------------+   |.sc_pregs.......................|  ^  |
*          | r14             |     |   |         : sr                   |  :  |
*          | r13             |     |   |         : pc                   |  :  |
*          | r12   REG_SET   |     |   |         : sp ------------------------+
*          | r11   structure |     |   |         : r14                  |  :
*          | r10   in target |     |   |         : r13                  |  :
*          | r9    task's TCB|     |   |         : r12                  |  :
*          | r8              |     |   |         : r11                  |  :
*          | macl            |     |   |         : r10                  |  :
*          | mach            |     |   |         : r9                   |  :
*          | r7 = pArgs[4]   |     |   |         : r8     These REG_SET |  :
*          | r6 = pArgs[3]   |     |   |         : macl      values are |  S
*          | r5 = pArgs[2]   |     |   |         : mach      saved from |  I
*          | r4 = pArgs[1] -----+  |   |         : r7        the target |  G
*          | r3              |  |  |   |         : r6     task's TCB by |  C
*          | r2              |  |  |   |         : r5   sigWindPendKill.|  O
*          | r1              |  |  |   |         : r4    (these will be |  N
*          | r0              |  |  |   |         : r3      re-loaded by |  T
*          | pr = vxTaskEntry|  |  |   |         : r2       _sigCtxLoad)|  E
*          | gbr             |  |  |   |         : r1                   |  X
* pRegs -> |_vbr_____________|  |  |   |         : r0                   |  T
*          |                 |  |  |   |         : pr                   |  :
*          |                 |  |  |   |         : gbr                  |  :
*          0                    |  |   |.sc_regs.:.vbr..................|  :
*                               |  |   |         :          :.sival_ptr.|  :
*                               |  |   |         :.si_value.:.sival_int.|  :
*           +-------------------+  |   |         :.si_code..............|  :
*           |                      |   |.sc_info.:.si_signo.............|  :
*           |                      |   |.sc_mask........................|  :
*           |                      |   |.sc_restart.....................|  :
*           +- pCtx = pStackBase ----> |_sc_onstack_____________________|__v_
*                                  |   |                       |        |
*                                  |   | pArgs[pArgs[0]]       V        |
*                                  |   |    :              stack for    |
*                                  |   | pArgs[7]         sigWrapper()  |
*                                  |   | pArgs[6]                       |
*                                  +-> | pArgs[5]                       |
*                                      |                                |
*                                      0                            
*/

void _sigCtxSetup
    (
    REG_SET	 *pRegs,			/* in target task's TCB  */
    void	 *pStackBase,			/* stack for sigWrapper  */
    void	(*taskEntry)(),			/* address of sigWrapper */
    int		 *pArgs				/* pArgs[0] = 1          */
    )						/* pArgs[1] = pCtx       */
    {
#if (CPU==SH7750 || CPU==SH7700)
    IMPORT UINT32 intUnlockSR;
#endif
    extern void  vxTaskEntry();
    FAST   int   ix;
    FAST   int * sp;

    bzero ((void *) pRegs, sizeof(REG_SET));	/* clear everything first */

#if (CPU==SH7750 || CPU==SH7700)
    pRegs->sr = intUnlockSR;			/* set status register    */
#elif (CPU==SH7600 || CPU==SH7000)
    pRegs->sr = 0x00000000;			/* set status register    */
#endif
    pRegs->pc = (INSTR *) taskEntry;		/* set entry point        */
    pRegs->pr = (INSTR *) vxTaskEntry;		/* for stack trace ???    */

    for (ix = 0; ix < pArgs[0]; ++ix)
	pRegs->voreg [ix+4] = pArgs [ix+1];	/* 1st 4 args into registers */

    sp = (int *)((int)pStackBase - SIG_STACK_ARGS * (sizeof(int)));

    pRegs->nvreg [7] = (ULONG) sp;		/* set stack pointer      */

    for (ix = 0; ix < SIG_STACK_ARGS; ++ix)
	*sp++ = pArgs [ix+5];			/* Args beyond 4th into stack */
    }
