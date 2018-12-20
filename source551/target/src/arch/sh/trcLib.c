/* trcLib.c - SH stack trace library */

/* Copyright 1995-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01k,05apr02,h_k  adjust reserved task params size (SPR #75153).
01j,30oct01,jn   use symFindSymbol for symbol lookup (SPR #7453)
01i,06dec01,h_k  fixed trcGetFuncInfo for the recursion depth is 0 and added
                 Diab support (SPR #69837).
01h,10may00,hk   revised trcGetFuncInfo() for GCC 2.96.
01g,19apr00,rsh  remove instruction #defines and put them in dsmShLib.h where
                 they go
01f,24aug99,hk   revised tracing algorithm (TSR#138850 related).
01e,14oct96,wt   rewritten.
01d,24oct95,sa   modified trcStackLvl(). disable argnument display.
01c,02jun95,sa   fixed trcGetFuncInfo(), and speed-up.
                 deleted TRC_INDICATE_PROGRESS.
01b,03apr95,hk   added progress indicator (enabled by TRC_INDICATE_PROGRESS).
01a,17mar95,sa   created from mips version 01p.
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
#include "sysSymTbl.h"
#include "dsmLib.h"
#include "taskLib.h"
#include "regs.h"
#include "stdio.h"
#include "vxLib.h"
#include "string.h"

#ifndef SYM_GLOBAL
#define SYM_GLOBAL	0x1
#endif
#ifndef SYM_TEXT
#define SYM_TEXT	0x4
#endif

#define MAX_TRACE_DEPTH 80 /* maximum number of levels of stack to trace */
#define MAX_SCAN_DEPTH		2000		/* search for proc start up to
						 * 2000 instructions */
#define MAX_PROLOG_INSN	20

typedef struct
    {
    INSTR *entry;		/* function entry address */
    INSTR *returnTo;		/* caller's pc to return */
    int szNvRegs;		/* size of non-volatile registers on stack */
    int szFrame;		/* size of stack frame */
    int szSubFrame;		/* size of sub stack frame after prolog code */
    BOOL foundSubFrame;		/* TRUE if sub stack frame exists */
    BOOL foundAddFrame;		/* TRUE if add stack frame exists */
    INT8 frameReg;		/* register used to get a long frame size */
    } TRC_INFO;

/* globals */

int trcDebug = 0;
int trcDefaultArgs = 4;			/* default # of args to print if trc
					 * can't figure out how many */

#define TRC_DEBUG(x)	if (trcDebug) printf x

/* forward declarations */

LOCAL void trcGetFuncInfo (REG_SET *regs, char *sp, INSTR *pc, int depth,
    INSTR **pReturnTo, INSTR **pFuncEntry, int *pFrameSize);

LOCAL void trcDefaultPrint (INSTR *callAdrs, INSTR *funcAdrs, 
    FAST int nargs, int *args);

LOCAL void trcStackLvl (char *stackBottom, REG_SET *regs, char *sp,
    INSTR *pc, int depth, FUNCPTR printRtn);

/*******************************************************************************
*
* trcStack - print a trace of function calls from the stack
*
* This routine provides the low-level stack trace function.  A higher-level
* symbolic stack trace, built on top of trcStack(), is provided by tt() in
* dbgLib.
*/

void trcStack
    (
    REG_SET *regs,	/* general purpose registers */
    FUNCPTR  printRtn,	/* routine to print single function call */
    int      tid	/* task's id */
    )
    {
    char *stackBottom = taskTcb (tid)->pStackBase;

    /* use default print routine if none specified */

    if (printRtn == NULL)
	printRtn = (FUNCPTR) trcDefaultPrint;

    /* must perform the trace by searching through code to determine stack
     * frames, and unwinding them to determine callers and parameters. 
     * We subtract a fixed size from stackBottom for the reserved task params
     * that are tagged onto every task's main entry point.
     */

    trcStackLvl (stackBottom - (MAX_TASK_ARGS * sizeof(int)), regs,
		(char *)regs->spReg, regs->pc, 0, printRtn);
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

LOCAL void trcStackLvl
    (
    char *stackBottom,	/* effective base of task's stack */
    REG_SET *regs,	/* current register set */
    char *sp,		/* current stack pointer */
    INSTR *pc,		/* current program counter */
    int depth,		/* recursion depth */
    FUNCPTR printRtn 	/* routine to print single function call */
    )
    {
    INSTR *callpc;		/* point where called from */
    INSTR *startpc;		/* entry point of the current function */
    int frameSize;		/* size, in bytes, of current stack frame */
    SYMBOL_ID symId;            /* symbol identifier */

    /* stop the unwind if it's obvious that we can't dereference the pc */

    if ((pc == NULL) || ((UINT)pc & 0x01))
	return;

    /* for each subprogram encountered, determine a bunch of info about it.
     * Includes where it was called from, its stack frame size and whether
     * the frame has already been allocated.
     */

    trcGetFuncInfo (regs, sp, pc, depth, &callpc, &startpc, &frameSize);

    /* Stop the unwind if we can't determine the caller of this function,
     * and check the callpc we got back.
     */

    if ((callpc == NULL) || ((UINT)callpc & 0x01))
	return;

    /* only continue unwinding if this is not the last stack frame.
     * (i.e., the "main" function)
     */
    TRC_DEBUG (("sp + %d = %p, bottom %p, margin %d\n",
		frameSize, sp + frameSize, stackBottom,
		stackBottom - (sp + frameSize)));

    if ((ULONG)(sp + frameSize) < (ULONG)stackBottom)
        {
        if (startpc == NULL)
            {
	    /* unable to determine entry point from code...try the symbol table.
	     * Note that the symbol table may yield the wrong entry point if
	     * the function name is not in it (such as the case for "static"
	     * functions in "C". In this case, we may get the starting address
	     * for the previous function in the text section and the trace
	     * would yield strange results. */

	    if ((sysSymTbl == NULL) ||
		(symFindSymbol (sysSymTbl, NULL, (void *)pc, 
				SYM_MASK_NONE, SYM_MASK_NONE, &symId) != OK) ||
		(symValueGet (symId, (void *)&startpc) != OK))
		return;
	    }

	/* Unwind the stack by adding the determined frame size and
	 * place the pc at the point at which this subprogram was called.
	 * Keep unwinding until the max number of functions has been reached */

	if (depth < MAX_TRACE_DEPTH)
            {
            trcStackLvl (stackBottom, regs, (char *)(sp + frameSize),
                                 callpc, depth + 1, printRtn);
            }
        }

    /* since this is the last frame, we can only determine the entry point
     * via the symbol table
     */

    else if ((sysSymTbl == NULL) ||
	     (symFindSymbol (sysSymTbl, NULL, (void *)pc, 
			     SYM_MASK_NONE, SYM_MASK_NONE, &symId) != OK) ||
	     (symValueGet (symId, (void *)&startpc) != OK))
	return;

    /* time to print out info about this function including the
     * called-from pc, the start of this function, the number of
     * actual parameters and their values.
     */

    (* printRtn) (callpc - 2, startpc, -1, sp + frameSize);
    }

/****************************************************************************
*
* trcGetFuncInfo - get address from which function was called
*
* Determines specific info about the current function, such as the
* address where it was called from, the stack frame size (if any) and
* whether the stack frame has already been allocated.
*/

LOCAL void trcGetFuncInfo
    (
    REG_SET *regs,      /* current SH register set */
    char *sp,           /* current sp */
    INSTR *pc,          /* current pc */
    int depth,		/* recursion depth */
    INSTR **pReturnTo,  /* return address from which this function called */
    INSTR **pFuncEntry,	/* return starting address of a function */
    int *pFrameSize     /* return stack frame size */
    )
    {
    INSTR *pscan;
    TRC_INFO trcInfo;
    char *label;	/* pointer to symbol table copy of symbol name */
    INSTR *pSymAhead;
    SYMBOL_ID symId;    /* symbol identifier */
    SYM_TYPE type;	/* symbol type */

    int szSubFrameEpilog = 0;
    int prStoreCheck = 0;
    BOOL inEpilog = FALSE;
    BOOL checkDiab = FALSE;

    /* If the recursion depth is 0, it is likely to be in a prolog code unless
     * it's in a epilog code. Scan forward up to MAX_PROLOG_INSN instructions,
     * or until finding an epilog instruction.
     */
    if (depth == 0)
	{
	TRC_DEBUG (("<forward scan #%d> sp %p, pc %p, upto %p\n",
		    depth, sp, pc, pc + MAX_PROLOG_INSN - 1));

	for (pscan = pc; pscan < pc + MAX_PROLOG_INSN; pscan++)
	    {
	    INSTR insn;

	    if (vxMemProbe ((char *)pscan, VX_READ, 2, (char *)&insn) != OK)
		{
		*pReturnTo = NULL;
		return;
		}
	    else if (insn == INST_PUSH_FP ||		/* mov.l r14,@-r15 */
		     insn == INST_PUSH_PR ||		/* sts.l pr,@-r15  */
		     insn == INST_SET_FP)		/* mov   r15,r14   */
		{
		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		TRC_DEBUG (("<forward scan #%d> pc %p in prolog, pr %p\n",
			    depth, pscan, regs->pr));

		*pReturnTo  = regs->pr;
		*pFuncEntry = NULL;
		*pFrameSize = 0;

		/* get the closest global function address from current pc */

		if ((sysSymTbl == NULL) ||
		    (symFindSymbol (sysSymTbl, NULL, (void *)pc, 
				    (SYM_GLOBAL | SYM_TEXT), SYM_MASK_ALL, 
				    &symId) != OK) ||
		    (symNameGet (symId, &label) != OK) ||
		    (symValueGet (symId, (void *)&pSymAhead) != OK) || 
		    (symTypeGet (symId, &type) != OK))
		    {
		    return;
		    }

		trcInfo.szNvRegs = 0;
		trcInfo.szFrame = 0;
		trcInfo.frameReg = NONE;

		/* Scan back the prolog code until beginning of the function. */

		for (pscan = pc - 1;pscan > (pc - MAX_SCAN_DEPTH) &&
		    (pscan >= pSymAhead); pscan--)
		    {
		    if (vxMemProbe ((char *)pscan, VX_READ, 2,
			(char *)&insn) != OK)
			{
			return;
			}
		    else if ((insn & (MASK_ADD_IMM_SP | 0x80)) ==
			(INST_ADD_IMM_SP | 0x80))	/* add   #-imm,r15 */
			{
			if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

			trcInfo.szFrame -= (INT8)(insn & 0x00ff);
			}
		    else if ((insn & MASK_SUB_REG_SP) == INST_SUB_REG_SP)
							/* sub rm,r15 */
			{
			if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

			trcInfo.frameReg = (insn & 0x00f0) >> 4;
			}
		    else if (trcInfo.frameReg != NONE &&
			(insn & MASK_MOV_IMM16) == INST_MOV_IMM16 &&
			(insn & 0x0f00) == trcInfo.frameReg << 8)
						/* mov.w @(disp,PC),Rn*/
			{
			UINT16 disp = (insn & 0x00ff) << 1;
			INT16 imm16;

			if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

			if (vxMemProbe ((char *)(pscan + 2) + disp,
			    VX_READ, 2, (char *)&imm16) != OK)
			    imm16 = 0;

			TRC_DEBUG (("<backward scan #%d> frame size %d\n",
			    depth, imm16));

			trcInfo.szFrame = imm16;
			}
		    else if (insn == INST_PUSH_PR)	/* sts.l pr,@-r15 */
			{
			if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

			trcInfo.szNvRegs = 4;
			}
		    else if ((insn & MASK_PUSH_REG) == INST_PUSH_REG)
							/* mov.l rm,@-r15 */
			{
			UINT8 rm = (insn & 0x00f0) >> 4;

			if (rm >= 8 && rm <= 14)
			    {
			    if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

			    trcInfo.szNvRegs += 4;
			    }

			if (rm == 8)			/* mov.l r8,@-r15 */
			    {
			    trcInfo.entry = pscan;
			    break;
			    }
			}
		    }

		*pFrameSize = trcInfo.szNvRegs + trcInfo.szFrame;
		return;
		}
	    else if (insn == INST_RESTORE_SP ||		/* mov   r14,r15   */
		     insn == INST_POP_PR ||		/* lds.l @r15+,pr  */
		     insn == INST_POP_FP ||		/* mov.l @r15+,r14 */
		     insn == INST_RTS)			/* rts             */
		{
		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		TRC_DEBUG (("<forward scan #%d> found epilog at %p\n",
			    depth, pscan));
		break;
		}
	    }

	TRC_DEBUG (("<forward scan #%d> pc %p not in prolog\n", depth, pc));
	}

    /* get the closest global function address from current pc */

    if ((sysSymTbl == NULL) ||
	(symFindSymbol (sysSymTbl, NULL, (void *)pc, 
			(SYM_GLOBAL | SYM_TEXT), SYM_MASK_ALL, &symId) != OK) ||
	(symNameGet (symId, &label) != OK) ||
	(symValueGet (symId, (void *)&pSymAhead) != OK) || 
	(symTypeGet (symId, &type) != OK))
	{
	label = "????";
	pSymAhead = NULL;
	type = 0;
	}

    /* We now know that the pc is NOT in a function prolog. Scan backward and
     * determine whether it is a C or an assembly function. If this is GNU C,
     * we should first find 'mov r15,r14' at the end of prolog. If this is
     * Diab C, we should first find 'add -imm,r15', 'sts.l pr,@-r15' or
     * 'mov.l r14,@-r15'. Keep track of stack operations otherwise, to get the
     * called address of this assembly function.
     */

    TRC_DEBUG (("<backward scan #%d> sp %p, pc %p, upto %p(%s:%#x)\n",
		depth, sp, pc, pSymAhead, label, type));

    for (trcInfo.szFrame = 0,
	 pscan = pc - 1;
	 pscan > pc - MAX_SCAN_DEPTH && pscan >= pSymAhead;
	 pscan--)
	{
	INSTR insn;

	if (vxMemProbe ((char *)pscan, VX_READ, 2, (char *)&insn) != OK)
	    {
	    *pReturnTo = NULL;
	    return;
	    }
	else if (insn == INST_SET_FP)			  /* mov   r15,r14  */
	    {
	    break;
	    }
	else if ((insn & MASK_PUSH_REG) == INST_PUSH_REG) /* mov.l rm,@-r15 */
	    {
	    if (insn == (INST_PUSH_REG | 0xe0))		/* mov.l r14,@-r15 */
		{
		INSTR insnNext;

		if ((vxMemProbe ((char *)(pscan - 1), VX_READ, 2,
		    (char *)&insnNext) == OK) &&
		    (insnNext == (INST_PUSH_REG | 0xd0)))
							/* mov.l r13,@-r15 */
		    {
		    checkDiab = TRUE;
		    break;
		    }
		}
	    else
		{
		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		trcInfo.szFrame += 4;
		}
	    }
	else if (insn == INST_PUSH_PR)			  /* sts.l pr,@-r15 */
	    {
	    INSTR insnNext;

	    if ((vxMemProbe ((char *)(pscan - 1), VX_READ, 2,
		(char *)&insnNext) == OK) &&
		(insnNext == (INST_PUSH_REG | 0xe0)))	/* mov.l r14,@-r15 */
		{
		checkDiab = TRUE;
		break;
		}
	    else
		{
		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		if (vxMemProbe ((char *)((int)sp + trcInfo.szFrame),
			    VX_READ, 4, (char *)&trcInfo.returnTo) != OK)
		    trcInfo.returnTo = NULL;

		*pReturnTo  = trcInfo.returnTo;
		*pFuncEntry = NULL;
		*pFrameSize = trcInfo.szFrame + 4;
		return;
		}
	    }
	else if ((insn & MASK_ADD_IMM_SP) == INST_ADD_IMM_SP)
							/* add #imm,r15 */
	    {
	    INSTR insnNext;

	    if ((vxMemProbe ((char *)(pscan - 1), VX_READ, 2,
		(char *)&insnNext) == OK) &&
		((insnNext == (INST_PUSH_REG | 0xe0)) || /* mov.l r14,@-r15 */
		(insnNext == INST_PUSH_PR)))		/* sts.l pr,@-r15 */
		{
		checkDiab = TRUE;
		break;
		}
	    }
	else if ((depth == 0) && (insn == INST_RESTORE_SP)) /* mov r14,r15 */
	    {
	    inEpilog = TRUE;
	    break;
	    }
	else if ((depth == 0) && (insn == INST_POP_PR))	/* lds.l @r15+,pr */
	    {
	    inEpilog = TRUE;
	    }
	else if ((depth == 0) && ((insn & MASK_POP_REG) ==
	    (INST_POP_REG | 0xe00)))			/* mov.l @r15+,r14 */
	    {
	    inEpilog = TRUE;
	    }
	}

    /* Here we know that this is a C function, and the pc is NOT in prolog.
     * Scan backward again until finding the end of prolog (mov r15,r14 or
     * sts.l @r15+,pr) to see if a sub-stack frame is constructed after the
     * prolog code.
     */

    pscan = pc - 1;

    /* If pc is in epilog, scan back until the start of the epilog. */

    if (inEpilog == TRUE)
	{
	TRC_DEBUG (("<backward scan #%d> pc %p in epilog\n", depth, pc));

	for (trcInfo.foundAddFrame = FALSE;
	    pscan > pc - MAX_SCAN_DEPTH && pscan >= pSymAhead;
	    pscan--)
	    {
	    INSTR insn;

	    if (vxMemProbe ((char *)pscan, VX_READ, 2, (char *)&insn) != OK)
		{
		*pReturnTo = NULL;
		return;
		}
	    else if ((insn & MASK_ADD_IMM_SP) == INST_ADD_IMM_SP)
		{
		INT8 imm = insn & 0xff;

		TRC_DEBUG (("%x  %04x        add        #%d,r15",
		    (UINT)pscan, insn, imm));

		if (trcInfo.foundAddFrame == FALSE)
		    {
		    trcInfo.foundAddFrame = TRUE;

		    if (imm > 0)			/* add #+imm,r15 */
			{
			TRC_DEBUG ((" (add)\n"));
			szSubFrameEpilog -= imm;
			}
		    else				/* add #-imm,r15 */
			TRC_DEBUG ((" (skip)\n"));
		    }
		else
		    TRC_DEBUG ((" (skip)\n"));
		}
	    else if (insn == INST_RESTORE_SP)		/* mov r14,r15 */
		{
		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		--pscan;
		break;
		}
	    else if ((insn & MASK_ADD_REG_SP) == INST_ADD_REG_SP)
							/* add rm,r15 */
		{
		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		trcInfo.frameReg = (insn & 0x00f0) >> 4;
		}
	    else if (trcInfo.frameReg != NONE &&
		(insn & MASK_MOV_IMM16) == INST_MOV_IMM16 &&
		(insn & 0x0f00) == trcInfo.frameReg << 8)
						/* mov.w @(disp,PC),Rn*/
		{
		UINT16 disp = (insn & 0x00ff) << 1;
		INT16 imm16;

		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		if (vxMemProbe ((char *)(pscan + 2) + disp, VX_READ, 2,
		    (char *)&imm16) != OK)
		    imm16 = 0;

		TRC_DEBUG (("<backward scan #%d> frame size %d\n", depth,
		    imm16));

		szSubFrameEpilog -= imm16;
		}
	    else if (insn == INST_POP_PR)		/* sts.l @r15+,pr */
		{
		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		szSubFrameEpilog -= 4;
		prStoreCheck -= 1;

		if (checkDiab == TRUE)
		    {
		    --pscan;
		    break;
		    }
		}
	    else if ((insn & MASK_POP_REG) == INST_POP_REG)
							/* mov.l @r15+,rm */
		{
		UINT8 rm = (insn & 0x0f00) >> 8;

		if (rm >= 8 && rm <= 14)
		    {
		    if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		    szSubFrameEpilog -= 4;
		    }

		if ((rm == 14) && (checkDiab == TRUE))	/* mov.l @r15+,r14 */
		    {
		    INSTR insnNext;

		    if ((vxMemProbe ((char *)(pscan - 1), VX_READ, 2,
			(char *)&insnNext) == OK) &&
			(insnNext != INST_POP_PR))	/* not sts.l @r15+,pr */
			{
			--pscan;
			break;
			}
		    }
		}
	    }
	}

    /* Scan back until the end of the prolog. */

    for (trcInfo.foundSubFrame = FALSE,
	 trcInfo.foundAddFrame = FALSE,
	 trcInfo.szSubFrame = 0;
	 pscan > pc - MAX_SCAN_DEPTH && pscan >= pSymAhead;
	 pscan--)
	{
	INSTR insn;

	if (vxMemProbe ((char *)pscan, VX_READ, 2, (char *)&insn) != OK)
	    {
	    *pReturnTo = NULL;
	    return;
	    }
	else if ((insn & MASK_ADD_IMM_SP) == INST_ADD_IMM_SP)
	    {
	    INT8 imm = insn & 0xff;

	    TRC_DEBUG (("%x  %04x        add        #%d,r15",
			(UINT)pscan, insn, imm));

	    if (trcInfo.foundSubFrame == FALSE)
		{
		trcInfo.foundSubFrame = TRUE;

		if (imm < 0)				/* add #-imm,r15 */
		    {
		    TRC_DEBUG ((" (sub)\n"));
		    trcInfo.szSubFrame = - imm;
		    }
		else					/* add #+imm,r15 */
		    TRC_DEBUG ((" (skip)\n"));
		}
	    else
		TRC_DEBUG ((" (skip)\n"));
	    }
	else if (((insn & MASK_ADD_IMM_R14) == INST_ADD_IMM_R14) &&
		(inEpilog == TRUE) && (checkDiab != TRUE))
	    {
	    INT8 imm = insn & 0xff;

	    TRC_DEBUG (("%x  %04x        add        #%d,r14",
		(UINT)pscan, insn, imm));

	    if (trcInfo.foundAddFrame == FALSE)
		{
		trcInfo.foundAddFrame = TRUE;

		if (imm > 0)				/* add #+imm,r14 */
		    {
		    TRC_DEBUG ((" (add)\n"));
		    szSubFrameEpilog -= imm;
		    }
		else					/* add #-imm,r14 */
		    TRC_DEBUG ((" (skip)\n"));
		}
	    }
	else if (((insn & MASK_PUSH_REG) == INST_PUSH_REG) &&
		(checkDiab == TRUE))			/* mov.l rm,@-r15 */
	    {
	    UINT8 rm = (insn & 0x00f0) >> 4;

	    if (rm >= 8 && rm <= 14)
		{
		if (inEpilog == TRUE)
		    {
		    trcInfo.szSubFrame = szSubFrameEpilog;
		    }
		break;
		}
	    }
	else if ((insn == INST_PUSH_PR) && (checkDiab == TRUE))
							/* sts.l pr,@-r15 */
	    {
	    if (inEpilog == TRUE)
		{
		trcInfo.szSubFrame = szSubFrameEpilog;
		}

	    break;
	    }
	else if (insn == INST_SET_FP)			/* mov r15,r14 */
	    {
	    if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

	    if (inEpilog == TRUE)
		{
		trcInfo.szSubFrame = szSubFrameEpilog;
		}

	    --pscan;
	    break;
	    }
	}

    /* Scan backward the rest of prolog code.
     */

    for (trcInfo.entry = NULL,
	 trcInfo.szNvRegs = 0,
	 trcInfo.szFrame = 0,
	 trcInfo.frameReg = NONE;
	 pscan > pc - MAX_SCAN_DEPTH && pscan >= pSymAhead;
	 pscan--)
	{
	INSTR insn;

	if (vxMemProbe ((char *)pscan, VX_READ, 2, (char *)&insn) != OK)
	    {
	    *pReturnTo = NULL;
	    return;
	    }
	else if ((insn & (MASK_ADD_IMM_SP | 0x80)) == (INST_ADD_IMM_SP | 0x80))
							/* add   #-imm,r15 */
	    {
	    if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

	    trcInfo.szFrame -= (INT8)(insn & 0x00ff);
	    }
	else if ((insn & MASK_SUB_REG_SP) == INST_SUB_REG_SP) /* sub rm,r15 */
	    {
	    if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

	    trcInfo.frameReg = (insn & 0x00f0) >> 4;
	    }
	else if (trcInfo.frameReg != NONE &&
		 (insn & MASK_MOV_IMM16) == INST_MOV_IMM16 &&
		 (insn & 0x0f00) == trcInfo.frameReg << 8)
							/* mov.w @(disp,PC),Rn*/
	    {
	    UINT16 disp = (insn & 0x00ff) << 1;
	    INT16 imm16;

	    if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

	    if (vxMemProbe ((char *)(pscan + 2) + disp, VX_READ, 2,
			    (char *)&imm16) != OK)
		imm16 = 0;

	    TRC_DEBUG (("<backward scan #%d> frame size %d\n", depth, imm16));
	    trcInfo.szFrame = imm16;
	    }
	else if (insn == INST_PUSH_PR)			/* sts.l pr,@-r15 */
	    {
	    if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

	    trcInfo.szNvRegs = 4;
	    prStoreCheck += 1;
	    }
	else if ((insn & MASK_PUSH_REG) == INST_PUSH_REG) /* mov.l rm,@-r15 */
	    {
	    UINT8 rm = (insn & 0x00f0) >> 4;

	    if (rm >= 8 && rm <= 14)
		{
		if (trcDebug) dsmInst (&insn, (int)pscan, NULL);

		trcInfo.szNvRegs += 4;
		}

	    if (rm == 8)				/* mov.l r8,@-r15 */
		{
		trcInfo.entry = pscan;
		break;
		}
	    }
	}

    /* get the return address on stack */

    if (vxMemProbe ((char *)((int)sp + trcInfo.szFrame + trcInfo.szSubFrame),
		    VX_READ, 4, (char *)&trcInfo.returnTo) != OK)
	trcInfo.returnTo = NULL;

    if ((depth == 0) && (prStoreCheck == 0))
	*pReturnTo = regs->pr;
    else
	*pReturnTo = trcInfo.returnTo;

    *pFuncEntry = trcInfo.entry;
    *pFrameSize = trcInfo.szNvRegs + trcInfo.szFrame + trcInfo.szSubFrame;
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

LOCAL void trcDefaultPrint
    (
    INSTR *callAdrs,		/* address from which function was called */
    INSTR *funcAdrs,		/* address of function called */
    FAST int nargs,		/* number of arguments in function call */
    int *args 			/* pointer to function args */
    )
    {
    FAST int ix;
    BOOL doingDefault = FALSE;

    /* print call address and function address */

    printErr ("%6x: %x (", callAdrs, funcAdrs);

    /* if no args are specified, print out default number (see doc at top) */

    if ((nargs == 0) && (trcDefaultArgs != 0))
	{
	doingDefault = TRUE;
	nargs = trcDefaultArgs;
	printErr ("[");
	}

    /* print args */

    for (ix = 0; ix < nargs; ++ix)
	{
	if (ix != 0)
	    printErr (", ");
	printErr ("%x", args[ix]);
	}

    if (doingDefault)
	printErr ("]");

    printErr (")\n");
    }
