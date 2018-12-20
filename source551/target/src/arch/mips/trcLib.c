/* trcLib.c - MIPS stack trace library */

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
01z,22may02,pgh  Fix SPR 70048.
01y,16jul01,ros  add CofE comment
01x,28jun01,mem  Add missing break.
01w,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01v,12nov99,myz  only trace back to the task main function.
01u,23sep99,myz  added CW4000_16 support.
01t,27jun96,kkk  undo 01r.
01s,31may96,kkk  added additional check for bogus stack frame(from ease).
01r,01may96,mem  changed R4000 argument handling.
01q,13jun94,caf  added checks for untraceable program counter (SPR #2958).
01p,19oct93,cd   added support for branch and link likely instructions.
01o,08oct93,yao  added checks for NULL sysSymTbl in trcStackLvl().
01n,27jul93,yao  fixed the bug that caculated stack frame size only once in
                 trcGetFuncInfo().  removed unused parameter pFrameAllocated
                 to trcGetFuncInto().
01m,07jul93,yao  made stack trace available.  changed copyright notice.
01p,16feb93,caf  added checks for untraceable program counter (SPR #2958).
01l,14sep92,yao  made trcStack() NOMANUAL.
01k,12sep92,ajm  changed OPCODE_MASK to GENERAL_OPCODE_MASK
01j,07aug92,ajm  made stack trace unsupported
01i,04jul92,jcf  scalable/ANSI/cleanup effort.
01h,05jun92,ajm  5.0.5 merge, note mod history changes
01f,26may92,rrr  the tree shuffle
01e,30mar92,yao  changed copyright notice.  made paramters to trcStack()
                 consistent with other architectures.  removed declarations
                 for undefined functions.
01d,14jan92,jdi  documentation cleanup.
01c,16oct91,ajm  documentation
01b,04oct91,rrr  passed through the ansification filter
                  -changed TINY and UTINY to INT8 and UINT8
                  -changed VOID to void
                  -changed copyright notice
01a,01jan91,ajm  created from 68k version 01q 
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
#include "arch/mips/dbgMipsLib.h"

#define MAX_TRACE_DEPTH 80 /* maximum number of levels of stack to trace */
#define MAX_SCAN_DEPTH 1000 /* maximum distance to scan in the code text */
#define DSM(addr,inst,mask) ((*addr & mask) == inst)

/* globals */

int trcDefaultArgs = 4; /* default # of args to print if trc
                         * can't figure out how many */

/* forward declarations */

LOCAL void trcGetFuncInfo (int depth, REG_SET *regs, char *sp, INSTR *pc, 
                           INSTR **pCallAddr, int *pFrameSize);

LOCAL INSTR *trcFindFuncStart (REG_SET *regs, INSTR *callpc);

LOCAL void trcDefaultPrint (INSTR *callAdrs, INSTR *funcAdrs, 
                            FAST int nargs, int *args);

LOCAL void trcStackLvl (char *stackBottom, REG_SET *regs, char *sp, 
                        INSTR *pc, int depth, FUNCPTR printRtn);

IMPORT int printErr(const char *,  ...);

/* externals */

IMPORT int dsmNbytes (ULONG);
IMPORT BOOL mips16Instructions (ULONG);

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
*         INSTR *callAdrs;  /@ address from which routine was called *
*         int   rtnAdrs;    /@ address of routine called             *
*         int   nargs;      /@ number of arguments in call           *
*         int   *args;      /@ pointer to arguments                  *
* .CE
*
* If <printRtn> is NULL, a default routine is used that prints out just
* the call address, function address, and arguments as hexadecimal values.
*
* CAVEAT
* In order to do the trace, some assumptions are made.  In general, the
* trace will work for all C language routines, and for assembly language
* routines that start with a LINK instruction.  Most VxWorks assembly
* language routines include LINK instructions for exactly this reason.
* However, routines written in other languages, strange entries into
* routines, or tasks with corrupted stacks can confuse the trace.  Also, all
* parameters are assumed to be 32-bit quantities; thus structures passed as
* parameters will be displayed as some number of long integers.
*
* EXAMPLE
* The following sequence can be used
* to trace a VxWorks task given a pointer to the task's TCB:
* .CS
*
*     REG_SET regSet;   /@ task's data registers *
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
    REG_SET *   regs,       /* general purpose registers */
    FUNCPTR     printRtn,   /* routine to print single function call */
    int         tid         /* task's id */
    )
    {
    int         taskMainFuncFrameSize = 0;
    char *      stackBottom = taskTcb (tid)->pStackBase;
    EXC_INFO *  trcExcInfo = & (taskTcb (tid)->excInfo);

    if ((trcExcInfo->valid & EXC_ACCESS_ADDR) &&
        (trcExcInfo->valid & EXC_EPC)         &&
        ((ULONG) trcExcInfo->badVa == (ULONG) trcExcInfo->epc))
        {
        return; /* i-fetch caused exception, so cannot trace MIPS stack */
        }

    /* use default print routine if none specified */

    if (printRtn == NULL)
        printRtn = (FUNCPTR) trcDefaultPrint;

    /* must perform the trace by searching through code to determine 
     * stack frames, and unwinding them to determine callers and parameters. 
     * We subtract 40 from stackBottom for the reserved task params that
     * are tagged onto every task's main entry point.
     */

    /* Only trace to the task's main function which is called by vxTaskEntry.
     * The function end code "jr ra or jr a3" is removed after the infinite
     * loop by Compiler optimization. So we won't be able to trace back the
     * function calling the function which has the infinite loop.
     */

    if ((ULONG)(((WIND_TCB *)(tid))->entry) & 0x1)
        {
        /* mips16 function */
        UINT16 * pInstr;

        pInstr = (UINT16 *)((ULONG)(((WIND_TCB *)(tid))->entry) & (~0x1));  

        if ((*pInstr & M16_I8_MASK) ==  M16_ADJSP_INSTR)
            taskMainFuncFrameSize = ((int)(*pInstr & 0xff) << 24) >> 21;

        }
    else
        {
        /* mips 32 bit function */
        UINT32 * pInstr;

        pInstr = (UINT32 *)((ULONG)(((WIND_TCB *)(tid))->entry) & (~0x1));

        if (DSM(pInstr, (ADDIU_INSTR | SP << RT_POS),
                (GENERAL_OPCODE_MASK | RT_MASK)))
            {
            /* Get the lower 16 bits, cast as short to sign extend. */
            taskMainFuncFrameSize = (short)(*pInstr & 0xFFFF);
            }
        }

    trcStackLvl (stackBottom-40+taskMainFuncFrameSize, 
                 regs, (char *) ((int)regs->spReg), 
                 regs->pc, 0, printRtn);

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
    char *      stackBottom,    /* effective base of task's stack */
    REG_SET *   regs,           /* general purpose registers */
    char *      sp,             /* current stack frame pointer */
    INSTR *     pc,             /* current program counter location */
    int         depth,          /* recursion depth */
    FUNCPTR     printRtn        /* routine to print single function call */
    )
    {
    INSTR *         callpc;     /* point where called from */
    INSTR *         startpc;    /* entry point of the current function */
    int             frameSize;  /* size, in bytes, of current stack frame */
    static UINT8    type;       /* unused holder for symbol type */
    static char     label [MAX_SYS_SYM_LEN + 1]; /* unused holder for symbol name */

#ifdef DBG_PRINTF
        (void)printf("trcStackLvl entry. depth=%d\n", depth);
#endif /* DBG_PRINTF */

    /* for each subprogram encountered, determine a bunch of info about it.
     * Includes where it was called from, its stack frame size and whether
     * the frame has already been allocated.
     */

    /* stop the unwind if it's obvious that we can't dereference the pc */

#ifdef _WRS_MIPS16
    if (IS_KUSEG(pc))
#else
    if (IS_KUSEG(pc) || ((UINT) pc & 0x03))
#endif
        return;

    frameSize = 0;
    trcGetFuncInfo (depth, regs, sp, pc, &callpc, &frameSize);

    /* Stop the unwind if we can't determine the caller of this function,
     * and check the callpc we got back.
     */

#ifdef _WRS_MIPS16
     if (IS_KUSEG(callpc))
#else
    if (IS_KUSEG(callpc) || ((UINT) callpc & 0x03))
#endif
        {
#ifdef DBG_PRINTF
        (void)printf("trcStackLvl depth=%d bad callpc\n", depth);
#endif /* DBG_PRINTF */
        return;
        }

    /* At depth 0, the first, we must adjust the sp if the stack frame for 
     * the current function has not yet been allocated.  No need to worry 
     * as we unwind the stack further since previous functions would 
     * necessarily have allocated their stack frames already.
     */

    /* only continue unwinding if this is not the last stack frame.
     * (i.e., the "main" function)
     */ 

    if ((ULONG) (sp + frameSize) <= (ULONG) stackBottom)
        {
        /* find the entry point to the current function */
        startpc = trcFindFuncStart (regs, callpc);

        if (startpc == NULL) 
            {
            /* unable to determine entry point from code...try the symbol table.
             * Note that the symbol table may yield the wrong entry point if
             * the function name is not in it (such as the case for "static"
             * functions in "C". In this case, we may get the starting address
             * for the previous function in the text section and the trace
             * would yield strange results. */

            if ((sysSymTbl == NULL) ||
                (symFindByValue (sysSymTbl, (UINT) pc, (char *) label, 
                                 (int *) &startpc, (SYM_TYPE *)&type) != OK))
                return;
            }

        /* Unwind the stack by adding the determined frame size and
         * place the pc at the point at which this subprogram was called.
         * Keep unwinding until the max number of functions has been reached */

        if (depth < MAX_TRACE_DEPTH)
            {
            trcStackLvl (stackBottom, regs, (char *) (sp + frameSize), 
                         callpc, depth + 1, printRtn);
            }
        }

    /* since this is the last frame, we can only determine the entry point
     * via the symbol table
     */

    else if ((sysSymTbl == NULL) ||
             (symFindByValue (sysSymTbl, (UINT) pc, (char *) label, 
                              (int *) &startpc, (SYM_TYPE *) &type) != OK))
        return;

    /* time to print out info about this function including the
     * called-from pc, the start of this function, the number of
     * actual parameters and their values.  Since there is no simple
     * way of knowing how many parameters there are, the saved values
     * for a0 - a3 are printed every time.  This will print extra 
     * parameters for some functions and too few for others.  However, 
     * an examination of the source code will identify the real number.
     * In any case, the values for the real number of parameters will
     * be correct with the exception of the lowest (or current) function.
     * Depending on where in the function the task is currently suspended,
     * it may not yet have saved all the calling parameters on the stack.
     * In the MIPS calling convention, calling parameters are saved at the
     * top of the previous stack frame.  An optimising compiler may elect
     * to store the argument registers elsewhere and so the arguments listed
     * in the stack trace are unlikely to reflect reality.
     */

    (* printRtn) (callpc, startpc, 4, sp + frameSize);
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
    INSTR *     callAdrs,   /* address from which function was called */
    INSTR *     funcAdrs,   /* address of function called */
    FAST int    nargs,      /* number of arguments in function call */
    int *       args        /* pointer to function args */
    )
    {
    FAST int    ix;
    BOOL        doingDefault = FALSE;

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
#if (CPU == MIPS64)
        printErr ("%x", args[ix * 2]);
#else /* (CPU == MIPS64) */
        printErr ("%x", args[ix]);
#endif /* (CPU == MIPS64) */
        }

    if (doingDefault)
        printErr ("]");

    printErr (")\n");
    }

/****************************************************************************
*
* trcFindFuncStart - find the starting address of a function
*
* This routine finds the starting address of a function.
* For MIPS processors, to find the start of a function, we use the instruction
* where the function was called from to compute it. The call was one of  
* a "jal", "jalr" or "BxAL[L]" instruction. For "jalr", it will be impossible
* to determine the target address since the contents of the target register
* have been lost along the way.
*/

LOCAL INSTR *trcFindFuncStart
    (
    REG_SET *   regs,   /* general purpose registers */
    INSTR *     callpc  /* pc of the calling point */
    )
    {
#ifdef DBG_PRINTF
        (void)printf("trcFindFuncStart entry.\n");
#endif /* DBG_PRINTF */

    /* compute the target of the call instruction which will be the
     * entry point (i.e., starting address) of the current function.
     * If the call was by a "jalr" instruction, then there is no way 
     * to reconstruct the entry point since the register contents have
     * been lost.
     */

    if (mips16Instructions((ULONG)callpc))
        {
        callpc = (INSTR *)((int)callpc & ~0x1);
        if (M16_INSTR_OPCODE(*(UINT16 *)callpc) == M16_JALNX_INSTR)
            {
            ULONG dstAddr;

            dstAddr = ((*(UINT16 *)callpc) << 16) + (*((UINT16 *)callpc + 1));
            dstAddr = M16_JALX_IMM(dstAddr) | (((ULONG)callpc) & 0xf0000000);

            return ( (INSTR *)dstAddr);
            }
        else
            return (NULL);
        }

    if (DSM (callpc, JAL_INSTR, GENERAL_OPCODE_MASK))
        {
        /* Jump And Link -- target address specified by shifting the offset 
         * left 2 bits and then "or"ing it with the upper 4 bits of the pc.
         */
        return ( (INSTR *) (((*callpc & TARGET_MASK) << 2) | 
                            ((int) callpc & 0xf0000000)) );
        }

    if (DSM (callpc,(BCOND | BLTZAL_INSTR),
             (GENERAL_OPCODE_MASK | BCOND_MASK)) ||
        DSM (callpc,(BCOND | BGEZAL_INSTR),
             (GENERAL_OPCODE_MASK | BCOND_MASK)) ||
        DSM (callpc,(BCOND | BLTZALL_INSTR),
             (GENERAL_OPCODE_MASK | BCOND_MASK)) ||
        DSM (callpc,(BCOND | BGEZALL_INSTR),
             (GENERAL_OPCODE_MASK | BCOND_MASK)))
        {

        /* Branch And Link -- target address specified by shifting the 
         * offset left 2 bits with sign extension and then adding it to the
         * address of the instruction in the delay slot.  Note that the "C" 
         * compiler automatically sign extends the "short" part of the 
         * instruction (i.e., the lower 16 bits).
         */

        return (callpc + 1 + (short) (*callpc & 0xFFFF));
        }

    /* either the call was via a "jalr" or there was a bad instruction where
     * we thought we were called from
     */

    return (NULL);
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
    int         depth,      /* recursion depth */
    REG_SET *   regs,       /* general purpose registers */
    char *      sp,         /* stack pointer */
    INSTR *     pc,         /* current pc */
    INSTR **    pCallAddr,  /* receives address from which this function called */
    int *       pFrameSize  /* receives stack frame size */
    )
    {
    FAST int        ix;
    FAST int        scanDepth;
    FAST INSTR *    scanpc;
    INSTR *         retAddr;

    *pFrameSize = (int) 0;
    retAddr = (INSTR *) NULL;

#ifdef DBG_PRINTF
    (void)printf("trcGetFuncInfo depth=%d pc=%08x sp=%08x\n", depth, pc, sp);
#endif /* DBG_PRINTF */

    /* scan instructions forward until the end of function or the max
     * scan count is reached. If we find a "sw ra,x(sp)" or a "jr ra"
     * then the return address in already in register "ra".  If we find
     * a "lw ra,x(sp)" then the return address is saved in offset "x"
     * on the stack. If the instruction space is corrupted, could get
     * a bus error eventually or could find a return address for a 
     * neighboring subprogram. The calling pc is determined by subtracting
     * 2 instructions from the return address. The stack frame size, if
     * found, and whether it is allocated, are passed out.
     */

    /* check if the pc belongs to a mips16 function */

    if (mips16Instructions((ULONG)pc))
        {
        ULONG scanPc = (ULONG)pc & ~0x1;
        ULONG addr = (ULONG)NULL;

        for (ix = 0; ix < MAX_SCAN_DEPTH; ix++)
            {
            if (((*(UINT16 *)scanPc) & M16_I8_MASK) == M16_I8_SWRASP) 
                {
                /* sw ra,x(sp) */

                addr = regs->raReg;
                }
            else if ((*(UINT16 *)scanPc) == M16_JR_RA_INSTR)
                {
                /* jr ra */

                if (addr == (ULONG)NULL)
                    addr = regs->raReg;
                ix = MAX_SCAN_DEPTH - 2;
                }
            else if ((*(UINT16 *)scanPc) == M16_JR_A3_INSTR) 
                {
                /*  jr a3 */

                if (addr == (ULONG)NULL)
                    addr = regs->a3Reg;
                ix = MAX_SCAN_DEPTH - 2;
                }
            else if ((M16_INSTR_OPCODE(*(UINT16 *)scanPc) == M16_LWSP_INSTR) &&
                     (M16_RX(*(UINT16 *)scanPc) == M16_REG_7) )
                {
                /* lw a3,x(sp) */

                addr = *(ULONG *)((int)sp + *pFrameSize + 
                                  M16_RI_OFFSET(*(UINT16 *)scanPc));
                }
            else if (((*(UINT16 *)scanPc) & M16_I8_MASK) == M16_ADJSP_INSTR)  
                {
                /* adjsp */

                *pFrameSize += ((int)((*(UINT16 *)scanPc) & 0xff) << 24) >> 21;
                }
            scanPc += dsmNbytes(scanPc);
            }  /* end for */

        /* make sure address aligned at 2 byte boundary */

        *pCallAddr = (INSTR *)((addr & ~0x1) - 6);

        return;
        } /* end if (mips16Instructions((ULONG)pc)) */

    scanDepth = MAX_SCAN_DEPTH;
    if (depth == 0)
        {

        /* Check insn we're sitting on to see if we're at the first
         * instruction of the function
         */

        if (DSM(pc, (ADDIU_INSTR | SP << RT_POS),
                (GENERAL_OPCODE_MASK | RT_MASK)))
            {

            /* match "[d]addiu sp,sp,-offset"
             * First instruction of function, innermost frame, don't scan.
             */

            scanDepth = -1;
            retAddr = (INSTR*) ((int)regs->raReg);  /* return point */
            }
            else
            {

            /* If in innermost frame, don't disassemble instruction we're
             * sitting on, as we haven't executed it yet.
             */

            scanDepth--;
            }
        }
    for (ix = scanDepth, scanpc = pc; ix >= 0; ix--, scanpc--)
        {

        /* match "jr ra" means ran off the top and missed the
         * beginning of the function.
         */

        if (DSM(scanpc,(SPECIAL | JR_INSTR | RA << RS_POS),
                (GENERAL_OPCODE_MASK | SPECIAL_MASK | RS_MASK)))
            {
#ifdef DBG_PRINTF
            (void)printf("trcGetFuncInfo depth=%d match jr ra\n", depth);
#endif /* DBG_PRINTF */

            /* If in innermost frame, assume return in ra. */

            if (depth == 0)
                retAddr = (INSTR*) ((int)regs->raReg);  /* return point */
            break;
            }

        /* match "addiu sp,sp,+-offset" to determine stack frame size.
         * Note that the "C" compiler takes care of sign extension
         * from "short" to "int" when we extract the immediate part of
         * the instruction. 
         */

        else if (DSM(scanpc, (ADDIU_INSTR | SP << RT_POS),
                     (GENERAL_OPCODE_MASK | RT_MASK)))
            {
#ifdef DBG_PRINTF
            (void)printf("trcGetFuncInfo depth=%d match addiu sp,sp,+-offset\n", depth);
#endif /* DBG_PRINTF */
            if ((short)(*scanpc & 0xFFFF) > 0)
                {

                /* stack frame de-allocation implies we may have
                 * run off the top of the function.  Stop searching.
                 */

                if (retAddr == NULL)
                    {
                    retAddr = (INSTR*) ((int)regs->raReg);
                    break;
                    }
                }
            /* If we hit this before 'sw/sd ra,x(sp)', this means we're
             * stopped between the allocation of the stack frame and the
             * save of RA on the stack.  If this happens anywhere other
             * than the innermost frame, it's illegal code and we're probabaly
             * actually lost.
             */

            *pFrameSize -= (short)(*scanpc & 0xFFFF);   /* get the immediate offset */
            if ((depth == 0) && (retAddr == NULL))
                {
                retAddr = (INSTR*) ((int)regs->raReg);
                break;
                }
            if (retAddr != NULL)
                {
                /* Have frameSize and retAddr, done with this frame. */
                break;
                }
            }

#if (CPU == MIPS64)
        /* match "sd ra,x(sp)" means return address is on the stack */

        else if (DSM(scanpc,(SD_INSTR | RA << RT_POS | SP << BASE_POS),
                     (GENERAL_OPCODE_MASK | RT_MASK | BASE_MASK)))
            {
#ifdef DBG_PRINTF
            (void)printf("trcGetFuncInfo depth=%d sp=%08x scanpc=%08x match sd ra,x(sp)\n", depth,sp,*scanpc);
#endif /* DBG_PRINTF */
#if (_BYTE_ORDER == _BIG_ENDIAN)
            retAddr = (INSTR *) *(int *)((int)sp + (short)(*scanpc & 0xFFFF) + 4);
#else /* (_BYTE_ORDER == _BIG_ENDIAN) */
            retAddr = (INSTR *) *(int *)((int)sp + (short)(*scanpc & 0xFFFF));
#endif /* (_BYTE_ORDER == _BIG_ENDIAN) */
#ifdef DBG_PRINTF
            (void)printf("trcGetFuncInfo depth=%d retAddr=%08x\n", depth,retAddr);
#endif /* DBG_PRINTF */
            }
#endif /* (CPU == MIPS64) */

        /* match "sw ra,x(sp)" means return address is on the stack */

        else if (DSM(scanpc,(SW_INSTR | RA << RT_POS | SP << BASE_POS),
                     (GENERAL_OPCODE_MASK | RT_MASK | BASE_MASK)))
            {
#ifdef DBG_PRINTF
            (void)printf("trcGetFuncInfo depth=%d sp=%08x scanpc=%08x match sw ra,x(sp)\n", depth,sp,*scanpc);
#endif /* DBG_PRINTF */
            retAddr = (INSTR *) *(int *)((int)sp + (short)(*scanpc & 0xFFFF));
#ifdef DBG_PRINTF
            (void)printf("trcGetFuncInfo depth=%d retAddr=%08x\n", depth,retAddr);
#endif /* DBG_PRINTF */
            }
        }

    /* if a return address was found, subtract 2 instructions from it to
     * determine the calling point, or set it to NULL 
     */

    if (mips16Instructions((ULONG)retAddr) )
        {
        /* Need to handle differently if it comes from a 16 bit function. 
         * subtract 2 instructions: one 32 bit, jal(x) and one 16 bit delay slot
         */

        if (retAddr != NULL)
            {
            retAddr = (INSTR *)(((int)retAddr & ~0x1) - 6);
            *pCallAddr = retAddr;
            }
        else
            *pCallAddr = NULL; 
        }
    else
        *pCallAddr =  (retAddr != NULL) ? (retAddr - 2) : NULL;

    }
