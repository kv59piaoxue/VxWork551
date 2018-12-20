/* taskArchLib.c - PowerPC specific task management routines for kernel */

/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02c,14aug03,dtr  Setting SPE MSR bit if VX_FP_TASK.
02b,14may03,dtr  Adding initialisation for spefpscr for e500.
02a,03oct02,dtr  Adding speFpscr to standard reg set for 85XX.
01z,04dec01,kab  SPR 69324: unset MSR[VEC] from parent; enabled in
                 altivecCreateHook if VX_ALTIVEC_TASK
01y,21aug01,pch  Add #ifdef missing from previous version
01x,15aug01,pch  Add PPC440 support, and clean up handling of MSR bits.
01w,24may01,kab  fix annoying compiler warning
01v,24may01,kab  Moved enabling ALTIVEC bit in MSR to altivec-specific task
                 create
01u,13apr01,pcs  Relocate the Altivec code.
01t,14mar01,pcs  Added code for ALTIVEC awareness.
01s,25oct00,s_m  renamed PPC405 cpu types
01r,24oct00,s_m  disabled FP exceptions
01q,06oct00,sm   added PPC405 support
01p,18mar99,tam  disabled FP exceptions (work-arround to SPR 25682).
01o,10nov98,elg  added hardware breakpoints for PPC403
01n,20mar98,tam  turn PPC403 MSR[CE] bit on (SPR 8192). 
01m,10feb97,tam  enabled FP unprecise non-recoverable mode if task options
		 includes VX_FP_TASK.
01l,10nov96,tpr  removed FP bit setting in the MSR register for PPC860.
01j,07mar96,ms   added vxTaskEntry so 10 args can be passed to task.
01j,06mar96,tpr  removed SDA.
01i,07oct95,tpr  changed pTcb->regs.msr value in taskRegsInit().
01h,16jun95,caf  initialized r2 and r13 according to EABI standard.
01g,07jun95,caf  undid modification 01d, removed AIX references.
01f,23may95,caf  MMU cleanup, put NULL at base of stack.
01e,19may95,caf  enabled PowerPC 603 data MMU in taskMsrDefault.
01d,28par95,yao  changed to set cr6 bit if task spawned with VX_FP_TASK
		 (TEMPOPRARILY).
01c,16jan95,caf  added FP bit to taskMsrDefault.
01b,21nov94,caf  added support for _GREEN_TOOL (init R2 & R13).
01a,01jun94,yao  written.
*/

/*
DESCRIPTION
This library provides an interface to PowerPC architecture-specific
task management routines.

SEE ALSO: taskLib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "taskLib.h"
#include "private/windLibP.h"
#include "private/kernelLibP.h"
#include "private/taskLibP.h"
#include "regs.h"
#include "string.h"
#include "arch/ppc/vxPpcLib.h"
#include "arch/ppc/toolPpc.h"

/* globals */

REG_INDEX taskRegName[] =
    {
    {"r0", REG_SET_GR(0)},
    {"sp", REG_SET_GR(1)},
    {"r2", REG_SET_GR(2)},
    {"r3", REG_SET_GR(3)},
    {"r4", REG_SET_GR(4)},
    {"r5", REG_SET_GR(5)},
    {"r6", REG_SET_GR(6)},
    {"r7", REG_SET_GR(7)},
    {"r8", REG_SET_GR(8)},
    {"r9", REG_SET_GR(9)},
    {"r10", REG_SET_GR(10)},
    {"r11", REG_SET_GR(11)},
    {"r12", REG_SET_GR(12)},
    {"r13", REG_SET_GR(13)},
    {"r14", REG_SET_GR(14)},
    {"r15", REG_SET_GR(15)},
    {"r16", REG_SET_GR(16)},
    {"r17", REG_SET_GR(17)},
    {"r18", REG_SET_GR(18)},
    {"r19", REG_SET_GR(19)},
    {"r20", REG_SET_GR(20)},
    {"r21", REG_SET_GR(21)},
    {"r22", REG_SET_GR(22)},
    {"r23", REG_SET_GR(23)},
    {"r24", REG_SET_GR(24)},
    {"r25", REG_SET_GR(25)},
    {"r26", REG_SET_GR(26)},
    {"r27", REG_SET_GR(27)},
    {"r28", REG_SET_GR(28)},
    {"r29", REG_SET_GR(29)},
    {"r30", REG_SET_GR(30)},
    {"r31", REG_SET_GR(31)},
    {"msr", REG_SET_MSR},		
    {"lr",  REG_SET_LR},
    {"ctr", REG_SET_CTR},
    {"pc",  REG_SET_PC},
    {"cr",  REG_SET_CR},
    {"xer", REG_SET_XER},
#if	(CPU == PPC601)
    {"mq",  REG_SET_MQ},
#endif	/* (CPU == PPC601) */
#if	(CPU == PPC85XX)
    {"spefscr",  REG_SET_SPEFSCR},
#endif	/* (CPU == PPC85XX) */
    {NULL, 0},
    };

#if     FALSE                  
IMPORT char * _SDA2_BASE_;
IMPORT char * _SDA_BASE_;
#endif

/* interrupts (and FPU) enabled by default */

_RType taskMsrDefault = _PPC_MSR_EE
#ifdef	_PPC_MSR_FP
		      | _PPC_MSR_FP
#endif	/* _PPC_MSR_FP */
#ifdef _PPC_MSR_CE
		      | _PPC_MSR_CE
#endif	/* _PPC_MSR_CE */
#ifdef _PPC_MSR_DE
		      | _PPC_MSR_DE
#endif	/* _PPC_MSR_DE */
		      | _PPC_MSR_ME;


/******************************************************************************
*
* vxTaskEntry - entry point to a task
*/ 

void vxTaskEntry (void)
    {
    int *	args	= ((int *)taskIdCurrent->pStackBase) - MAX_TASK_ARGS;
    FUNCPTR	entry	= taskIdCurrent->entry;
    int		exitCode;

    exitCode = (*entry) (args[0], args[1], args[2], args[3], args[4], args[5],
    		 args[6], args[7], args[8], args[9]);

    while (TRUE)
	{
	exit (exitCode);
	}
    }

/*******************************************************************************
*
* taskRegsInit - initialize a task's registers
*
* During task initialization this routine is called to initialize the specified
* task's registers to the default values.
* 
* NOMANUAL
* ARGSUSED
*/

void taskRegsInit
    (
    WIND_TCB	*pTcb,		/* pointer TCB to initialize */
    char	*pStackBase 	/* bottom of task's stack */
    )
    {
    bzero ((char *) &pTcb->regs, sizeof (REG_SET));

    /* set status register */

    pTcb->regs.msr = vxMsrGet() | _PPC_MSR_EE	/* turn on the External Inter */
#ifdef	_PPC_MSR_CE
				| _PPC_MSR_CE	/* turn on the Critical Intr */
#endif /* _PPC_MSR_CE */
#ifdef	_PPC_MSR_DE
				| _PPC_MSR_DE	/* Debug Exception Enable */
#endif /* _PPC_MSR_DE */
#ifdef	_PPC_MSR_FP
				| _PPC_MSR_FP	/* turn on the floating point */
#endif /* _PPC_MSR_FP */
				| _PPC_MSR_ME;	/* turn on the Machine Check */

#ifdef	_PPC_MSR_FP
    /* disable all FP exceptions by default */

    pTcb->regs.msr &= ~(_PPC_MSR_FE0 | _PPC_MSR_FE1);

# if	0		/* temporary work-around for SPR #25682 */
    /* enable FP imprecise non-recoverable exception mode only for FP tasks */

    if ((pTcb->options & VX_FP_TASK) !=0)
        pTcb->regs.msr |= _PPC_MSR_FE1;		/* enable FP imprecise non-re */
                                                /* coverable exception mode */
# endif	/* 0 */

#endif	/* _PPC_MSR_FP */

#ifdef	_WRS_SPE_SUPPORT
    /*
     * Disable SPE bit in MSR (may be incorrectly inherited from parent); 
     * MSR[SPE] will be turned on by speCreateHook, if required.
     */
    pTcb->regs.msr &= ~_PPC_MSR_SPE;
    pTcb->regs.spefscr = 0;

    if ((pTcb->options & VX_FP_TASK)==VX_FP_TASK)
        pTcb->regs.msr |= _PPC_MSR_SPE;

#endif /* _WRS_SPE_SUPPORT */

    pTcb->regs.pc = (_RType)vxTaskEntry;	/* set entry point */

#ifdef _WRS_ALTIVEC_SUPPORT
    /*
     * Disable ALTIVEC bit in MSR (may be incorrectly inherited from parent); 
     * MSR[VEC] will be turned on by altivecCreateHook, if required.
     */
    pTcb->regs.msr &= ~(_PPC_MSR_VEC << 16);
#endif /* _WRS_ALTIVEC_SUPPORT */

#if FALSE
    /* initialize R2 and R13 (small data area pointer(s)) */

    pTcb->regs.gpr[2] =  (_RType) &_SDA2_BASE_;
    pTcb->regs.gpr[13] = (_RType) &_SDA_BASE_;
#endif	/* FALSE */

    /* initial stack pointer - make room for args + a stack frame */

    pTcb->regs.spReg = (int)pStackBase - ((MAX_TASK_ARGS + 6) * sizeof(int));
    pTcb->regs.spReg = STACK_ROUND_DOWN (pTcb->regs.spReg);

    /* ABI says initial frame pointer should be NULL */

    *(int *)pTcb->regs.spReg = (int *)NULL;
    }

/*******************************************************************************
*
* taskArgsSet - set a task's arguments
*
* During task initialization this routine is called to push the specified
* arguments onto the task's stack.
*
* NOMANUAL
* ARGSUSED
*/

void taskArgsSet
    (
    WIND_TCB	*pTcb,			/* pointer TCB to initialize */
    char	*pStackBase,		/* bottom of task's stack */
    int		pArgs[] 		/* array of startup arguments */
    )
    {
    FAST int ix;
    FAST int *sp;

    /* save args on the stack for taskRestart() */

    sp = (int *) pStackBase;

    for (ix = 1; ix <= MAX_TASK_ARGS; ix++)
	*--sp = pArgs[MAX_TASK_ARGS - ix];
    }

/*******************************************************************************
*
* taskRtnValueSet - set a task's subroutine return value
*
* This routine sets register v0, the return code, to the specified value.  It
* may only be called for tasks other than the executing task.
*
* NOMANUAL
* ARGSUSED
*/

void taskRtnValueSet
    (
    WIND_TCB	*pTcb,		/* pointer TCB for return value */
    int		returnValue 	/* return value to fill into WIND_TCB */
    )
    {
    pTcb->regs.gpr[3] = returnValue;
    }

/*******************************************************************************
*
* taskArgsGet - get a task's arguments
*
* This routine is utilized during task restart to recover the original task
* arguments.
*
* NOTE
* If the task has modified the arguments, the changed values would be 
* returned.
*
* NOMANUAL
* ARGSUSED
*/

void taskArgsGet
    (
    WIND_TCB *pTcb,		/* pointer TCB to initialize */
    char *pStackBase,		/* bottom of task's stack */
    int  pArgs[] 		/* array of arguments to fill */
    )
    {
    FAST int ix;
    FAST int *sp;

    /* get args on the stack */

    sp = (int *) pStackBase;			/* start at bottom of stack */

    for (ix = 1; ix <= MAX_TASK_ARGS; ix++)
	pArgs[MAX_TASK_ARGS - ix] = *--sp;	/* fill arguments from stack */
    }
/*******************************************************************************
*
* taskMsrSet - set task status register
*
* This routine sets the status register of a specified non-executing task
* (i.e., the TCB must not be that of the calling task).  
*
* RETURNS: OK, or ERROR if the task ID is invalid.
*/

STATUS taskMsrSet
    (
    int    tid,	 	/* task ID */
    _RType msr 		/* new SR  */
    )
    {
    FAST WIND_TCB *pTcb = taskTcb (tid);

    if (pTcb == NULL)		/* task non-existent */
	return (ERROR);

    pTcb->regs.msr = msr;

    return (OK);
    }
