/* taskArchLib.c - MIPS specific task management routines for kernel */

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
02g,17oct01,mem  Fix argument placement for MIPS64 (SPR #71058)
02f,16jul01,ros  add CofE comment
02e,25apr01,mem  Force FR to be set in SR if _WRS_FP_REGISTER_SIZE==8
		 (SPR #66821).
02d,22dec00,tlc  Remove TLBHI reference.
02c,18dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
02b,10sep99,myz  added CW4000_16 support
02a,19jan99,dra	 added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01?,13jul96,cah  Added CPU=R4650 support
01z,27jun96,kkk  undo 01y.
01y,01may96,mem  task arguements are now of type _RType.
01x,04feb94,cd   changed taskArchRegsShow to handle all MIPS processors
01v,19oct93,cd   added R4000 support.
01u,23aug92,jcf  cleanup.
01t,09aug92,ajm  ansified
01s,09jul92,ajm  changed at0 to at
01r,04jul92,jcf  scalable/ANSI/cleanup effort.
01q,30jun92,yao  removed alternative g* register names.
01p,05jun92,ajm  5.0.5 merge, note mod history changes
01o,26may92,rrr  the tree shuffle
02n,28apr92,ajm  now use global taskSrDefault instead of macro
01m,18mar92,yao  removed routine taskStackAllot(), macro MEM_ROUND_UP.
01l,12mar92,yao  removed taskRegsShow().  added regIndex[].  changed copyright
                 notice.
01k,15jan92,jdi  doc tweak.
01j,14jan92,jdi  documentation cleanup.
01i,04oct91,rrr  passed through the ansification filter
                  -changed VOID to void
                  -changed copyright notice
01h,26sep91,ajm   made t7 and t8, t8 and t9 in taskRegsShow
01g,27may91,ajm   MIPS-ized.
01f,28sep90,jcf   documentation.
01e,02aug90,jcf   documentation.
01d,10jul90,jcf   moved taskStackAllot () from taskLib.c.
01c,26jun90,jcf   added taskRtnValueSet ().
01b,23apr90,jcf   changed name and moved to src/68k.
01a,18dec89,jcf   written by extracting from taskLib (2).
*/

/*
DESCRIPTION
This library provides an interface to MIPS architecture-specific
task management routines.

SEE ALSO: taskLib
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "stdio.h"
#include "taskLib.h"
#include "private/windLibP.h"
#include "private/kernelLibP.h"
#include "private/taskLibP.h"
#include "regs.h"

/* globals */

REG_INDEX taskRegName[] =
    {
#if	  (_WRS_FP_REGISTER_SIZE == 4)
    {"$0", ZEROREG, sizeof(_RType)},
    {"t0", T0REG, sizeof(_RType)},
    {"s0", S0REG, sizeof(_RType)},
    {"t8", T8REG, sizeof(_RType)},
    {"at", ATREG, sizeof(_RType)},
    {"t1", T1REG, sizeof(_RType)},
    {"s1", S1REG, sizeof(_RType)},
    {"t9", T9REG, sizeof(_RType)},
    {"v0", V0REG, sizeof(_RType)},
    {"t2", T2REG, sizeof(_RType)},
    {"s2", S2REG, sizeof(_RType)},
    {"k0", K0REG, sizeof(_RType)},
    {"v1", V1REG, sizeof(_RType)},
    {"t3", T3REG, sizeof(_RType)},
    {"s3", S3REG, sizeof(_RType)},
    {"k1", K1REG, sizeof(_RType)},
    {"a0", A0REG, sizeof(_RType)},
    {"t4", T4REG, sizeof(_RType)},
    {"s4", S4REG, sizeof(_RType)},
    {"gp", GPREG, sizeof(_RType)},
    {"a1", A1REG, sizeof(_RType)},
    {"t5", T5REG, sizeof(_RType)},
    {"s5", S5REG, sizeof(_RType)},
    {"sp", SPREG, sizeof(_RType)},
    {"a2", A2REG, sizeof(_RType)},
    {"t6", T6REG, sizeof(_RType)},
    {"s6", S6REG, sizeof(_RType)},
    {"s8", S8REG, sizeof(_RType)},
    {"a3", A3REG, sizeof(_RType)},
    {"t7", T7REG, sizeof(_RType)},    
    {"s7", S7REG, sizeof(_RType)},
    {"ra", RAREG, sizeof(_RType)},
    {"divlo", LOREG, sizeof(_RType)},
    {"divhi", HIREG, sizeof(_RType)},
    {"sr", SR_OFFSET, sizeof(ULONG)},
    {"pc", PC_OFFSET, sizeof(INSTR *)},
#elif  (_WRS_FP_REGISTER_SIZE == 8)
    {"$0", ZEROREG, sizeof(_RType)},
    {"t0", T0REG, sizeof(_RType)},
    {"s0", S0REG, sizeof(_RType)},
    {"at", ATREG, sizeof(_RType)},
    {"t1", T1REG, sizeof(_RType)},
    {"s1", S1REG, sizeof(_RType)},
    {"v0", V0REG, sizeof(_RType)},
    {"t2", T2REG, sizeof(_RType)},
    {"s2", S2REG, sizeof(_RType)},
    {"v1", V1REG, sizeof(_RType)},
    {"t3", T3REG, sizeof(_RType)},
    {"s3", S3REG, sizeof(_RType)},
    {"a0", A0REG, sizeof(_RType)},
    {"t4", T4REG, sizeof(_RType)},
    {"s4", S4REG, sizeof(_RType)},
    {"a1", A1REG, sizeof(_RType)},
    {"t5", T5REG, sizeof(_RType)},
    {"s5", S5REG, sizeof(_RType)},
    {"a2", A2REG, sizeof(_RType)},
    {"t6", T6REG, sizeof(_RType)},
    {"s6", S6REG, sizeof(_RType)},
    {"a3", A3REG, sizeof(_RType)},
    {"t7", T7REG, sizeof(_RType)},
    {"s7", S7REG, sizeof(_RType)},
    {"s8", S8REG, sizeof(_RType)},    
    {"k0", K0REG, sizeof(_RType)},
    {"", 0, 0},
    {"gp", GPREG, sizeof(_RType)},
    {"k1", K1REG, sizeof(_RType)},
    {"t8", T8REG, sizeof(_RType)},
    {"ra", RAREG, sizeof(_RType)},
    {"sp", SPREG, sizeof(_RType)},
    {"t9", T9REG, sizeof(_RType)},
    {"divlo", LOREG, sizeof(_RType)},
    {"divhi", HIREG, sizeof(_RType)},
    {"sr", SR_OFFSET, sizeof(ULONG)},
    {"pc", PC_OFFSET, sizeof(INSTR *)},
#endif
    {NULL, 0},
    };

/*
*  Default status register has FPA coprocessor on, and all interrupt lines
*  enabled.
*/
 
#ifdef _WRS_R3K_EXC_SUPPORT

ULONG taskSrDefault	= (SR_CU0 | SR_CU1 | SR_IMASK0 | SR_IEC);

#else	/* _WRS_R3K_EXC_SUPPORT */

/*
 * Default status register has FPA coprocessor on, and all interrupt lines
 * enabled.
 *
 * The status register turns on the CP0 control instructions
 * (SR(CU0)==1).
 *
 * For MIPS64, the SR(FR) mode switch is set to expose all 32
 * double-sized floating-point registers to software. We also
 * set SR(CU3)==1 to globally enable MIPS IV instructions in that case.
 *
 */

#if (CPU==MIPS64)
#define SR_ARCH			SR_CU3
#define	SR_FLOAT_MODE		(SR_FR)
#elif (CPU==MIPS32)
#define SR_ARCH			(0)
#define	SR_FLOAT_MODE		(0)
#else
#error "invalid CPU value"
#endif

#define SR_KERNEL_MODE		(SR_IMASK0 | SR_KSU_K | SR_IE)
#define	SR_KERNEL_INT_MODE	(SR_ARCH | SR_CU1 | SR_CU0)

ULONG taskSrDefault	= (SR_FLOAT_MODE | SR_KERNEL_INT_MODE | SR_KERNEL_MODE);
#endif	/* _WRS_R3K_EXC_SUPPORT */

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
    FAST int ix;
    IMPORT ULONG _gp;		/* compiler generated global pointer value */ 

    pTcb->regs.sr = taskSrDefault;		/* set status register */
    pTcb->regs.pc = (INSTR *)vxTaskEntry;	/* set entry point */

    pTcb->regs.lo = 0;
    pTcb->regs.hi = 0;
    pTcb->regs.cause = 0;
    pTcb->regs.fpcsr = 0;
    for (ix = 0; ix < 32; ++ix)
	pTcb->regs.gpreg[ix] = 0;		/* initialize general regs */

    pTcb->regs.gpReg = (_RType) &_gp;	/* load current global pointer */

    /* initial stack pointer is just after MAX_TASK_ARGS task arguments */

    pTcb->regs.spReg = (_RType) ((int)(pStackBase
				       - (MAX_TASK_ARGS * sizeof (_RType))));
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
    FAST _RType *sp;

    /* push args on the stack */

    sp = (_RType *) pStackBase;		/* start at bottom of stack */

#if	  (_WRS_INT_REGISTER_SIZE == 4)
    for (ix = MAX_TASK_ARGS - 1; ix >= 0; --ix)
	*--sp = pArgs[ix];		/* put arguments onto stack */
#elif  (_WRS_INT_REGISTER_SIZE == 8)
    /* Make sure the argument is sign-extended */
    for (ix = MAX_TASK_ARGS - 1; ix >= 0; --ix)
	*--sp = (long long) pArgs[ix];		/* put arguments onto stack */
#endif	/* _WRS_INT_REGISTER_SIZE */

    pTcb->regs.a0Reg = pArgs[0];	/* load register parameter 1 */
    pTcb->regs.a1Reg = pArgs[1];	/* load register parameter 2 */
    pTcb->regs.a2Reg = pArgs[2];	/* load register parameter 3 */
    pTcb->regs.a3Reg = pArgs[3];	/* load register parameter 4 */
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
    pTcb->regs.v0Reg = returnValue;
    }

/*******************************************************************************
*
* taskArgsGet - get a task's arguments
*
* This routine is utilized during task restart to recover the original task
* arguments.
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
    FAST _RType *sp;

    /* push args on the stack */

    sp = (_RType *) pStackBase;			/* start at bottom of stack */

    for (ix = MAX_TASK_ARGS - 1; ix >= 0; --ix)
	pArgs[ix] = (int) *--sp;		/* fill arguments from stack */
    }
/*******************************************************************************
*
* taskSRSet - set task status register
*
* This routine sets the status register of a specified non-executing task
* (i.e., the TCB must not be that of the calling task).  
*
* RETURNS: OK, or ERROR if the task ID is invalid.
*/

STATUS taskSRSet
    (
    int    tid,	 	/* task ID */
    UINT32 sr 		/* new SR  */
    )
    {
    FAST WIND_TCB *pTcb = taskTcb (tid);

    if (pTcb == NULL)		/* task non-existent */
	return (ERROR);

    pTcb->regs.sr = sr;

    return (OK);
    }
/*******************************************************************************
*
* taskSRInit - initialize the default task status register
*
* This routine sets the default status register for system wide tasks.
* This will be the value of the status register that all tasks are 
* spawned with therefore it must be called before kernelInit.
*
* RETURNS: Previous value of default status register.
*/

ULONG taskSRInit
    (
    ULONG newValue 		/* new default task status register  */
    )
    {
    ULONG oldValue;

    oldValue = taskSrDefault;
#if (_WRS_FP_REGISTER_SIZE == 8)
    /* If CU1 is enabled, also enable extended FP regs */
    if (newValue & SR_CU1)
	newValue |= SR_FR;
#endif	/* _WRS_FP_REGISTER_SIZE */
    taskSrDefault = newValue;
    return (oldValue);
    }

/******************************************************************************
*
* taskArchRegsShow - display the contents of a task's registers
*
* This routine displays the register contents of a specified task
* on standard output.
*
* NOTE
* This function doesn't really belong here.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void
taskArchRegsShow
    (
     REG_SET	*pRegSet		/* register set */
    )
    {
    int		ix;
    int *	pReg;		/* points to register value */

    /* print out registers */
#if (_WRS_INT_REGISTER_SIZE == 8)
    _RType	reg;	        /* CPU register value */
    unsigned int hi;		/* high half of reg */
    unsigned int lo;		/* low half of reg */

    /* 64-bit registers */

    for (ix = 0; taskRegName[ix].regName != NULL; ix++)
	{
	if ((ix % 3) == 0)
	    printf ("\n");
	else
	    printf ("%3s","");

	if (taskRegName[ix].regName[0] != EOS)
	    {
	    if (taskRegName[ix].regWidth == sizeof(_RType))
		{
		reg = *(_RType *)((int)pRegSet + taskRegName[ix].regOff);
		hi = reg >> 32;
		lo = reg;
		if (hi)
		    printf ("%-5s = %8x%08x", taskRegName[ix].regName, hi, lo);
		else
		    printf ("%-5s = %8s%8x", taskRegName[ix].regName, "", lo);
		}
	    else
		{
		pReg = (int *) ((int)pRegSet + taskRegName[ix].regOff);
		printf ("%-5s = %8x%8s", taskRegName[ix].regName, *pReg, "");
		}
	    }
	else
	    printf ("%24s", "");
	}
    printf ("\n");

#elif (_WRS_INT_REGISTER_SIZE == 4)

    /* 32-bit registers */

    for (ix = 0; taskRegName[ix].regName != NULL; ix++)
	{
	if ((ix % 4) == 0)
	    printf ("\n");
	else
	    printf ("%3s","");

	if (taskRegName[ix].regName[0] != EOS)
	    {
	    pReg = (int *) ((int)pRegSet + taskRegName[ix].regOff);
            printf ("%-5s = %8x", taskRegName[ix].regName, *pReg);

	    }
	else
	    printf ("%16s", "");
	}

#else	/* _WRS_INT_REGISTER_SIZE */
#error "invalid _WRS_INT_REGISTER_SIZE value"
#endif	/* _WRS_INT_REGISTER_SIZE */

    printf ("\n");
    }
