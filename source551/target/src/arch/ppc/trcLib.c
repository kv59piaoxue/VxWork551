/* trcLib.c - PowerPC stack trace library */

/* Copyright 1984-1994 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02b,27feb96,ms   reworked findFuncStart.
02a,01feb96,ms   rewritten.
01c,16jan95,caf  disabled stack trace support for now.
01b,05dec94,caf  added cast to trcStack().
01a,07nov94,yao  written.
*/

/*
This module provides the routine trcStack(), which traces a stack
given the current frame pointer, stack pointer, and program counter.
The resulting stack trace lists the nested routine calls and their arguments.

This module provides the low-level stack trace facility.
A higher-level symbolic stack trace, implemented on top of this facility,
is provided by the routine tt() in dbgLib.

SEE ALSO:
dbgLib, tt(),
.pG "Debugging"
*/

#include "vxWorks.h"
#include "symLib.h"
#include "taskLib.h"
#include "regs.h"
#include "string.h"
#include "private/funcBindP.h"
#include "dbgLib.h"
#include "sysSymTbl.h"
#include "vxLib.h"

/* definitions */

#define MAX_TRACE_DEPTH	80	/* maximum stack frames to trace */
#define MAX_SCAN_DEPTH	250	/* maximum distance to scan text */
#define MAX_PROLOGUE_SIZE 20	/* maximum size of function prologue */
#define FP_FROM_STACK(sp)	 (*(char **)(sp))
#define RETURN_PC_FROM_STACK(sp) (*(INSTR **)((sp) + 4))
#define BOGUS_SP(sp,low,high)	 (((int)(sp) % 8) || ((sp) < (low)) || \
				  ((sp) > (high)) || (sp == 0))
#define BOGUS_PC(pc, junk)	 (vxMemProbe((char *)(pc), VX_READ, 4, \
				  (char *)&(junk)) == ERROR)

/* some dissassembly macros */

#define INST_LWZX_SP		_OP(31, 55) | (1 << 21)
#define INST_LWZUX_SP		_OP(31, 23) | (1 << 21)
#define INST_LWZX_SP_MASK	0xffe007fe
#define INST_LWZ_SP_MASK	0xffe00000
#define STW(reg)	((36 << 26) | ((reg) << 21))
#define STW_REG_MASK	0xffe00000

/* globals */

int trcDefaultArgs = 0;			/* default # of args to print */
int trcScanDepth = MAX_SCAN_DEPTH;

/* forward declarations */

static int	trcGetArgs (INSTR *procAddr, char *sp, int *args);
static INSTR *	trcFindFuncStart (INSTR *pc, INSTR *returnPc);
static void	trcDefaultPrint (INSTR *callAdrs, INSTR *funcAdrs, 
			int nargs, int *args);
static void	trcStackLvl (INSTR *pc, INSTR *returnPc, char *sp, char *fp,
			char *stackBottom, int depth, FUNCPTR printRtn);
static STATUS	trcInfoGet (int tid, REG_SET * pRegs, INSTR ** pPc,
			INSTR ** pReturnPc, char ** pSp, char ** pFp);

/*******************************************************************************
*
* trcStack - print a trace of function calls from the stack
*
* This routine provides the low-level stack trace function.
* A higher-level symbolic stack trace, built on top of this, is provided
* by tt() in dbgLib.
* 
* The routine prints a list of the nested routine calls that are on the stack,
* showing each routine call with its parameters.
*
* The stack being traced should be quiescent.  The caller should avoid tracing
* its own stack.
*
* PRINT ROUTINE
* To allow symbolic or alternative printout formats, the call to this
* routine includes the <printRtn> parameter, which specifies a user-supplied
* routine to be called at each nesting level to print out the routine name
* and its arguments.  This routine should be declared as follows:
* .ne 5
* .CS
*     void printRtn (callAdrs, rtnAdrs, nargs, args)
*         INSTR *callAdrs;  /@ address from which routine was called @/
*         int   rtnAdrs;    /@ address of routine called             @/
*         int   nargs;      /@ number of arguments in call           @/
*         int   *args;      /@ pointer to arguments                  @/
* .CE
*
* If <printRtn> is NULL, a default routine is used that prints out just
* the call address, function address, and arguments as hexadecimal values.
*
* CAVEAT
* There is no way to determine the function arguments unless the
* code is compiled with debugging (e.g., "-gdwarf).
*
* EXAMPLE
* The following sequence can be used
* to trace a VxWorks task given a pointer to the task's TCB:
* .CS
*
*     REG_SET regSet;	/@ task's data registers @/
*
*     taskRegsGet (taskId, &regSet);
*     trcStack (&regSet, (FUNCPTR) NULL, tid);
*
* .CE
*
* RETURNS: N/A
*
* SEE ALSO: tt()
* 
* NOMANUAL
*/

void trcStack
    (
    REG_SET * pRegs,	/* general purpose registers */
    FUNCPTR printRtn,	/* routine to print single function call */
    int     tid         /* task's id */
    )
    {
    char *stackBottom = taskTcb (tid)->pStackBase;
    char *sp;			/* current stack pointer */
    char *fp;			/* frame pointer (previous sp) */
    INSTR *pc;			/* current program counter */
    INSTR *returnPc;		/* return address */

    /* get info on the top level stack frame */

    if (trcInfoGet (tid, pRegs, &pc, &returnPc, &sp, &fp) == ERROR)
	{
	if (_func_printErr != NULL)
	    _func_printErr ("trcStack aborted: error in top frame\n");
	return;
	}

    /* use default print routine if none specified */

    if (printRtn == NULL)
	printRtn = (FUNCPTR) trcDefaultPrint;

    /* do the recursive stack trace. */

    trcStackLvl (pc, returnPc, sp, fp, stackBottom, 0, printRtn);
    }

/************************************************************************
*
* trcStackLvl - recursive stack trace routine
*
* This routine is recursive, being called once for each level of routine
* nesting.  The maximum recursion depth is limited to 40 to prevent
* garbage stacks from causing this routine to continue unbounded.
* The "depth" parameter on the original call should be 0.
*/

static void trcStackLvl
    (
    INSTR *pc,		/* current program counter location */
    INSTR *returnPc,	/* return address */
    char *sp,		/* stack pointer */
    char *fp,		/* frame pointer (previous stack pointer) */
    char *stackBottom,	/* effective base of task's stack */
    int depth,		/* recursion depth */
    FUNCPTR printRtn 	/* routine to print single function call */
    )
    {
    char *	prevFp = NULL;
    INSTR *	prevReturnPc;
    int		args[MAX_TASK_ARGS];
    INSTR *	procAddr;
    int		nArgs;

    /* recursive trace if depth not maxed and framepointer is valid */

    if (depth < MAX_TRACE_DEPTH)
	{
	prevFp = FP_FROM_STACK(fp);
	if (BOGUS_SP (prevFp, fp, stackBottom))
	    return;

	prevReturnPc = RETURN_PC_FROM_STACK(prevFp);
	if (!BOGUS_PC (prevReturnPc, procAddr))
	    trcStackLvl (returnPc, prevReturnPc, fp, prevFp, stackBottom,
			 depth+1, printRtn);
	}

    /* get the current routine's starting address */

    procAddr = trcFindFuncStart (pc, returnPc);

    /* get the function arguments */

    nArgs = trcGetArgs (procAddr, sp, args);

    (* printRtn) (returnPc, procAddr, nArgs, args);
    }

/*******************************************************************************
*
* trcDefaultPrint - print a function call
*
* This routine is called by trcStack to print each level in turn.
*
* If nargs is specified as 0, then a default number of args (trcDefaultArgs)
* is printed in brackets ("[..]"), since this often indicates that the
* number of args is unknown.
*/

static void trcDefaultPrint
    (
    INSTR *callAdrs,		/* address from which function was called */
    INSTR *funcAdrs,		/* address of function called */
    int nargs,			/* number of arguments in function call */
    int *args 			/* pointer to function args */
    )
    {
    int ix;
    BOOL doingDefault = FALSE;

    if (!_func_printErr)
	return;

    /* print call address and function address */

    _func_printErr ("%6x: %x (", callAdrs, funcAdrs);

    /* if no args are specified, print out default number (see doc at top) */

    if ((nargs == 0) && (trcDefaultArgs != 0))
	{
	doingDefault = TRUE;
	nargs = trcDefaultArgs;
	_func_printErr ("[");
	}

    /* print args */

    for (ix = 0; ix < nargs; ++ix)
	{
	if (ix != 0)
	    _func_printErr (", ");
	_func_printErr ("%x", args[ix]);
	}

    if (doingDefault)
	_func_printErr ("]");

    _func_printErr (")\n");
    }

/******************************************************************************
*
* trcFindFuncStart - get starting address of a procedure.
*
* Given a "pc" value, determine the address of the procedure
* containing that pc.
* We try several methods until one succeeds.
* 1) First check the returnPc to see if we got to the current proc
* via a branch instruction. If so we can determine the procedure
* address accuratly.
* 2) If there is no branch instruction found, scan backwards up to
* trcScanDepth bytes looking for a "stwu sp, xxx(sp)" instruction,
* and assume that instruction is the proc entry.
*
* RETURNS: The starting address of the procedure, or NULL if it couldn't
* be found.
*/ 

static INSTR * trcFindFuncStart
    (
    INSTR * pc,		/* program counter within current proc */
    INSTR * returnPc	/* return address */
    )
    {
    INSTR * 	pInstr;
    int		branchAddr;

    /* first check if there is a branch instruction before the returnPc */

    pInstr = returnPc - 1;
    if ((INST_CMP (pInstr, INST_B, INST_B_MASK)) ||
	(INST_CMP (pInstr, INST_BC, INST_B_MASK)))
	{
	/* extract address from instruction and sign extend */

	if (INST_CMP (pInstr, INST_B, INST_B_MASK))
	    {
	    branchAddr = *pInstr & 0x03fffffc;
	    if (branchAddr & 0x02000000)
		branchAddr |= 0xfc000000;
	    }
	else
	    {
	    branchAddr = *pInstr & 0xfffc;
	    if (branchAddr & 0x8000)
		branchAddr |= 0xffff0000;
	    }

	/* if branch is not absolute, add in relative address */

	if (!_IFIELD_AA (*pInstr))
	    branchAddr += (int)pInstr;

	return ((INSTR *)branchAddr);
	}

    /* if that fails, try to scan backwards for "stwu sp, xxx(sp)" */

    if (!BOGUS_PC(pc - trcScanDepth, pInstr))
	{
	for (pInstr = pc; pInstr > pc - trcScanDepth; pInstr--)
	    {
	    if (INST_CMP (pInstr, INST_STWU_SP, INST_HIGH_MASK))
		return (pInstr);
	    }
	}

    /* if all else fails, return "pc" as a guess */

    return (pc);
    }

/******************************************************************************
*
* trcPrologueFrameAllocated - check if stack frame is allocated
*
* Start at "procAddr" and scan forwards up to MAX_PROLOGUE_SIZE instructions.
* If we get to our PC before we see an "allocate stack frame" instruction,
* then the current procedure does not have an allocated stack frame.
*
* RETURNS: TRUE if frame is allocated, else false
*/

static BOOL trcPrologueFrameAllocated
    (
    INSTR *procAddr,		/* address of procedure */
    INSTR *pc			/* current PC value */
    )
    {
    INSTR *pInstr;

    for (pInstr = procAddr; pInstr < procAddr + MAX_PROLOGUE_SIZE; pInstr++)
	{
	if (INST_CMP (pInstr, INST_STWU_SP, INST_HIGH_MASK))
	    return (TRUE);
	if (pInstr == pc)
	    return (FALSE);
	}

    return (TRUE);
    }

/******************************************************************************
*
* trcInfoGet - get info on top stack frame.
*
* This routine grabs the stack pointer and pc from the register set.
* It then computes the frame pointer and return PC.
* The later two require care:
*	Usually both are on the stack.
*	Sometimes the return PC is in the link register. This is true in
*	  a leaf procedure, or during a procedure prologue.
*	Sometimes the frame pointer is the stack pointer. This happens
*	  when a frame has not been allocated for the current proc.
*	  Leaf procedures often do not allocate stack frames. Non-leaf
*	  procedures have no frames during the prologue and epilogue).
* This procedure scans forward up to MAX_SCAN_DEPTH instructions from
* the current PC looking for instructions that might give us a clue
* as to which case we are in.
* If the scan doesn't find any of the instructions is is looking for,
* then it assumes we are in the normal case (frame allocated and
* return PC saved to stack).
* 
* XXX - If we are in a function epilogue and have just popped the
* procedure frame, this routine will mistakenly skip the next
* frame down.
*
* A little sanity checking is done. If the stack pointer, frame pointer
* PC or return PC are bogus, we return ERROR.
*
* RETURNS: OK or ERROR if there was trouble parsing the frame.
*/ 

static STATUS trcInfoGet
    (
    int		tid,			/* task ID */
    REG_SET *	pRegs,			/* task's registers */
    INSTR **	pPc,			/* return PC here */
    INSTR **	pReturnPc,		/* return calling PC here */
    char **	pSp,			/* return stack pointer here */
    char **	pFp			/* return frame pointer here */
    )
    {
    BOOL	frameAllocated = TRUE;
    BOOL	returnPcOnStack = TRUE;
    INSTR *	pInstr;
    INSTR *	pc;
    INSTR *	procAddr;
    char *	fp;
    char *	sp;

    pc = (INSTR *)pRegs->pc;
    sp = (char *)pRegs->spReg;

    if (BOGUS_SP(sp, taskTcb(tid)->pStackEnd, taskTcb(tid)->pStackBase))
	return (ERROR);

    if (BOGUS_PC(pc, pInstr))
	goto skipscan;

    if (BOGUS_PC(pc + trcScanDepth, pInstr))
	goto skipscan;

    /* Scan forward from current PC to see how the link register is used */

    for (pInstr = pc; pInstr < pc + trcScanDepth; pInstr++)
	{
	/* mfspr lr,rx => in proc prologue with return PC in link register */

        if (INST_CMP(pInstr, INST_MFLR, INST_MTSPR_MASK))
	    {
	    procAddr = trcFindFuncStart (pc, (INSTR *)pRegs->lr);
	    returnPcOnStack = FALSE;
	    if (trcPrologueFrameAllocated(procAddr, pc))
		frameAllocated = TRUE;
	    else
		frameAllocated = FALSE;
	    break;
	    }

	/* bclr => in proc epilogue with return PC in link register */

        if (INST_CMP(pInstr, INST_BCLR, INST_BCLR_MASK))
	    {
	    returnPcOnStack = FALSE;
	    frameAllocated = TRUE;	/* XXX - not always true in epilogue */
	    break;
	    }

	/* mtspr lr, rx => return PC in link register */

        if (INST_CMP(pInstr, INST_MTLR, INST_MTSPR_MASK))
	    {
	    returnPcOnStack = TRUE;
	    frameAllocated = TRUE;	/* XXX - not always true in epilogue */
	    break;
	    }

	/* "stwu r1, rx" (but no mtspr lr, rx) */

	if (INST_CMP (pInstr, INST_STWU_SP, INST_HIGH_MASK))
	    {
	    returnPcOnStack = FALSE;
	    frameAllocated = FALSE;
	    break;
	    }
	}

skipscan:

    if (frameAllocated)
	{
	fp = FP_FROM_STACK (sp);
	if (BOGUS_SP (fp, sp, taskTcb(tid)->pStackBase))
	    return (ERROR);
	}
    else
	{
	fp = sp;			/* no frame => sp=fp */
	sp -= _STACK_ALIGN_SIZE;	/* fake a stack pointer */
	}

    /* store away the info */

    *pPc = pc;
    *pSp = sp;
    *pFp = fp;

    if (returnPcOnStack)
	*pReturnPc = RETURN_PC_FROM_STACK (*pFp);
    else
	*pReturnPc = (INSTR *)pRegs->lr;

    if (BOGUS_PC(*pReturnPc, pInstr))
	return (ERROR);

    return (OK);
    }

/******************************************************************************
*
* trcGetArgs - get function arguments from the stack.
*
* XXX - No way to do this if the code is not compiled with "-g"
* because the power PC calling conventions do not require
* argumenst to be pushed on the stack.
* This routine is based on disassembled GNU code, which contains
* the following sequence near the proc prologue:
*
*     mfspr        r0, LR		# standard prologue
*     stw          r31, 0xfffc(r1)	# standard prologue
*     stw          r0, 0x4(r1)		# standard prologue
*     stwu         r1, 0xffc0(r1)	# standard prologue
*     or           r31, r1, r1		# r31 = stack pointer
*     stw          r3, 0x18(r31)	# save arg0 0x18 bytes from sp
*     stw          r4, 0x1c(r31)	# save arg1 0x1c bytes from sp
*     stw          r5, 0x20(r31)	# save arg2 0x1c bytes from sp
*	...
*
* So we scan the function prologue looking for this pattern,
* and if we find them we copy the args from the stack.
* The ABI says nothing about this, so GNU or anouther compiler vendor
* can change this at any time and break this stack tracer.
*
* RETURNS: the number of arguments retrieved.
*/ 

static int trcGetArgs
    (
    INSTR *procAddr,
    char *sp,
    int *args
    )
    {
    int nArgs = 0;
    INSTR *pInstr;

    for (pInstr = procAddr; pInstr < procAddr + MAX_PROLOGUE_SIZE; pInstr++)
	{
	if (INST_CMP (pInstr, STW(nArgs + 3), STW_REG_MASK))
	    {
	    args[nArgs] = *(int *)(sp + (*pInstr & 0xffff));
	    nArgs++;
	    if (nArgs >= MAX_TASK_ARGS)
		break;
	    }

	/* a branch instuction means function prologue is over */

        if (INST_CMP (pInstr, INST_BCLR, INST_BCLR_MASK) ||
	    INST_CMP (pInstr, INST_B, INST_B_MASK))
	    break;
	}

    return (nArgs);
    }

