/* trcLib.c - ARM stack trace library */

/* Copyright 1996-1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01f,07may01,m_h  validate fp before using it.
01e,04sep98,cdp  make Thumb support dependent on ARM_THUMB.
01d,27oct97,kkk  took out "***EOF***" line from end of file.
01c,10oct97,jpd  added further Thumb support.
01b,01may97,cdp  added new function prologues, basic Thumb support, tidied.
01a,22jul96,cdp  created, based on 68K.c
*/

/*
This module provides a routine, trcStack(), which traces a stack
given the current frame pointer, stack pointer, and program counter.
The resulting stack trace lists the nested routine calls and their arguments.

This module provides the low-level stack trace facility.
A higher-level symbolic stack trace, implemented on top of this facility,
is provided by the routine tt() in dbgLib.

SEE ALSO: dbgLib, tt(),
.pG "Debugging,"
.I "ARM Architecture Reference Manual,"
.I "ARM Procedure Call Standard,"
.I "Thumb Procedure Call Standard."
*/

#include "vxWorks.h"
#include "regs.h"
#include "symLib.h"
#include "taskLib.h"
#include "dsmLib.h"
#include "sysSymTbl.h"
#include "vxLib.h"
#include "private/funcBindP.h"


/*
 * Check that this compiler does sign extension when an int is shifted right
 * because code below relies on its doing so.
 */

#if (((INT32)-1L) >> 1) > 0
#	error right shifting an int does not perform sign extension
#endif


#define MAX_TRACE_DEPTH 40 /* maximum number of levels of stack to trace */


/* globals */

int trcDefaultArgs = 0;			/* default # of args to print if */
					/* can't figure out how many */

/* imported functions */

#if (ARM_THUMB)
IMPORT BOOL thumbInstrChangesPc (INSTR *);
#else
IMPORT BOOL armInstrChangesPc (INSTR *);
#endif


/* forward static functions */

LOCAL void trcStackLvl (WIND_TCB *tcb, int *fp, INSTR *pc, int depth, FUNCPTR printRtn);
LOCAL void trcDefaultPrint (INSTR *callAdrs, INSTR *funcAdrs, int nargs, int
		*args);
LOCAL INSTR *trcFindCall (INSTR *returnAdrs);
LOCAL INSTR *trcFindDest (INSTR *callAdrs);
LOCAL int trcCountArgs (INSTR *returnAdrs);
LOCAL INSTR *trcFindFuncStart (int *fp, INSTR *pc);

/*******************************************************************************
*
* trcStack - print a trace of function calls from the stack
*
* This routine provides the low-level stack trace function.  A higher-level
* symbolic stack trace, built on top of trcStack(), is provided by tt() in
* dbgLib.
*
* This routine prints a list of the nested routine calls that are on the
* stack, showing each routine with its parameters.
*
* The stack being traced should be quiescent.  The caller should avoid
* tracing its own stack.
*
* PRINT ROUTINE
* In order to allow symbolic or alternative printout formats, the call to
* this routine includes the <printRtn> parameter, which specifies a
* user-supplied routine to be called at each nesting level to print out the
* routine name and its arguments.  This routine should be declared as
* follows:
* .ne 7
* .CS
*     void printRtn (callAdrs, rtnAdrs, nargs, args)
*         INSTR  *callAdrs;  /@ address from which routine was called *
*         int    rtnAdrs;    /@ address of routine called *
*         int    nargs;	     /@ number of arguments in call *
*         int    *args;	     /@ pointer to arguments *
* .CE
* If <printRtn> is NULL, a default routine will be used that prints out just
* the call address, the function address, and the arguments as hexadecimal
* values.
*
* CAVEAT
* In order to do the trace, a number of assumptions are made.  In general,
* the trace will work for all C language routines and for assembly language
* routines that start with a standard entry sequence which establishes a
* stack frame conforming with the ARM Procedure Call Standard (APCS) or
* the Thumb Procedure Call Standard (TPCS).
*
* Most VxWorks assembly language routines establish a stack frame in this
* fashion for exactly this reason. However, routines written in other
* languages, strange entries into routines, or tasks with corrupted stacks
* can confuse the trace.  Also, all parameters are assumed to be 32-bit
* quantities, therefore structures passed as parameters will be displayed
* as a number of long integers.
*
* .ne 14
* EXAMPLE
* The following sequence can be used to trace a VxWorks task given a pointer
* to the task's TCB:
* .CS
* REG_SET regSet;  /@ task's data registers *
*
* taskRegsGet (taskId, &regSet);
* trcStack (&regSet, (FUNCPTR)NULL, taskId);
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
    REG_SET *pRegSet,		/* pointer to register set */
    FUNCPTR printRtn,           /* routine to print single function call */
    int     tid			/* task's id */
    )
    {
    int		val;			/* address from symbol table */
    char	name[MAX_SYS_SYM_LEN];	/* string associated with val */
    SYM_TYPE	type;			/* type associated with val */
    int		stackSave[4];
    int		i;			/* an index */
    BOOL	in_entry_exit;		/* boolean: whether in entry or exit */
    FAST INSTR *pc = pRegSet->pc;
    FAST int *fp = (int *) pRegSet->fpReg;
    FAST int *sp = (int *) pRegSet->spReg;
#if (ARM_THUMB)
    FAST int *lr = (int *) pRegSet->r[14];
    int	reg;
#endif
    WIND_TCB   *tcb= taskTcb (tid);
    INSTR       insn;


    /* use default print routine if none specified */

    if (printRtn == NULL)
	printRtn = (FUNCPTR) trcDefaultPrint;

    /*
     * if the current routine doesn't have a stack frame, then we fake one
     * by putting the old one on the stack and making fp point to that.
     * We KNOW we don't have a complete stack frame for the current
     * routine in a few particular cases.
     *  1) We are in the entry sequence of a routine which establishes the
     *     stack frame. We try to cope with this;
     *  2) We are in the exit sequence of a routine, which collapses the
     *     stack frame (Thumb only). We try to cope with this;
     *  3) We are in a routine which doesn't create a stack frame. We cannot
     *     do much about this.
     */

#if (!ARM_THUMB)
    /*
     * ARM
     * So far, we have identified 3 types of function prologue (and are still
     * trying to get a useful statement from Cygnus about others):
     *
     *  normal:
     *          mov     ip,sp
     *          stmdb   sp!,{v_regs,fp,ip,lr,pc}
     *          sub     fp,ip,#4
     *
     *  varargs:
     *          mov     ip,sp
     *          stmdb   sp!,{a_regs}
     *          stmdb   sp!,{v_regs,fp,ip,lr,pc}
     *          sub     fp,ip,#4+n*4
     *
     *  structure arg passed by value:
     *          mov     ip,sp
     *          sub     sp,sp,#n
     *          stmdb   sp!,{fp,ip,lr,pc}
     *          sub     fp,ip,#4+n
     *
     * Combining 'varargs' and 'structure arg passed by value' does not
     * seem to generate a different prologue.
     */
#else
    /*
     * Thumb
     * We have identified the following routine prologues. They vary
     * substantially depending on the type of routine and, notably, do
     * not always start with the same instruction. The prologue may be
     * changed later, to be made more efficient.
     *
     *		push	{a_regs}	/@ only present if required @/
     *		sub	sp,#16
     *		push	{v_regs}	/@ only present if required @/
     *					/@ includes lr if non-leaf routine @/
     *		add	rx,sp,#n
     *		str	rx,[sp,#]
     *		mov	rx,pc		/@ 1 @/
     *		str	rx,[sp,#]	/@ 2 @/
     *		mov	rx,fp		/@ 3 @/
     *		str	rx,[sp,#]	/@ 4 @/
     *		mov	rx,lr
     *		str	rx,[sp,#]
     *		add	rx,sp,#n
     *		mov	fp,rx
     *
     * The instructions labelled 1, 2, 3 and 4 can appear in the order 3,4,1,2
     * in some routines.
     *
     * For Thumb we also need to be aware of routine epilogues, as,
     * unlike the ARM epilogue, which is atomic (one instruction), the
     * Thumb epilogue takes several instructions, during which the frame
     * is collapsed. The epilogue is not currently "strictly-conforming"
     * in that fp does not always point to a valid frame: there is a
     * window between the popping of part of the frame and the changing
     * of fp to point to the previous frame.
     *
     * The routine epilogue does not appear to vary much:
     *
     * leaf:
     *		pop	{v_regs}	/@ only present if required @/
     *		pop	{rx, ry}
     *		mov	fp,rx
     *		mov	sp,ry
     *		bx	lr
     * non-leaf:
     *		pop	{v_regs}	/@ only present if required @/
     *		pop	{rx, ry, rz}
     *		mov	fp,ry
     *		mov	sp,rz
     *		bx	rx
     */
#endif


#if (ARM_THUMB)
    /*
     * First look to see if we are in the epilogue.
     *
     * Search backwards from current instruction to find the first
     * instruction of the epilogue.
     */

    for (i = 0; i >= -3 ; --i)
	if (INSTR_IS(pc[i],     T_POP_LO) &&
	    INSTR_IS(pc[i + 1], T_MOV_FP_LO) &&
	    INSTR_IS(pc[i + 2], T_MOV_SP_LO) &&
	    INSTR_IS(pc[i + 3], T_BX_LO))
	    break;

    if (in_entry_exit = (i >= -3), in_entry_exit)
	{
	/* If we have not yet executed the POP instruction, then fp
	 * still points to a valid frame, so pretend we're not in the
	 * epilogue. We have at least proved we're not in the prologue,
	 * which is useful as otherwise we might have a false match on the
	 * MOV FP,
	 */

	if (i == 0)
	    in_entry_exit = FALSE;
	else
	    {
	    /*
	     * If we are in the epilogue, then at the least, the frame
	     * pointer and stack pointer will have been popped from the
	     * stack. i.e. there is no longer a valid stack frame on the
	     * stack (and not possibly overwritten).
	    */

	    if (i == -1)
		{
		/*
		 * Then fp has not yet been restored, old fp value will
		 * be in the register used in the MOV fp, loreg
		 * instruction. Extract the register number from that
		 * instruction, then get that register from the reg set
		 * and make that our dummy fp which we will use to
		 * construct a dummy frame.
		 */

		reg = (pc[i + 1] & 0x38) >> 3;	/* reg num in MOV fp instr */
		fp = (int *)pRegSet->r[reg];
		}
	    /*
	     * We must find the return address from the current routine
	     * to put into our dummy frame later. Extract it from the
	     * register used in the BX instruction used to exit the
	     * routine.
	     */

	    reg = (pc[i + 3] & 0x38) >> 3;	/* reg num in BX instr*/
	    lr = (int *) pRegSet->r[reg];	/* get from reg set */
	    }
	}
    else
	{
	/*
	 * We are not in the epilogue, we may be in the prologue.
	 *
	 * Look for the last instruction of the prologue. This can be up
	 * to twelve instructions after the current one.
	 */

	for (i = 0; i <= 12 ; i++)
	    if (INSTR_IS(pc[i], T_MOV_FP_LO))
		break;

	/*
	 * Check to see if this really is the prologue, by matching
	 * another instruction earlier in the prologue. We have
	 * attempted to choose instructions which should not occur much
	 * elsewhere.
	 */
	in_entry_exit = (i <= 12 &&
		    (INSTR_IS(pc[i - 5], T_MOV_LO_PC) ||
		     INSTR_IS(pc[i - 5], T_MOV_LO_FP)));
	}
#else
    /*
     * Look for the first instruction of the prologue. This can be up
     * to three instructions before the current pc.
     */

    for (i = 0; i >= -3 ; --i)
	if (INSTR_IS(pc[i], MOV_IP_SP))
	    break;

    in_entry_exit = (i >= -2 &&
		INSTR_IS(pc[i + 1], STMDB_SPP_FP_IP_LR_PC) &&
		INSTR_IS(pc[i + 2], SUB_FP_IP_4)) ||
	       (i >= -3 &&
		INSTR_IS(pc[i + 2], STMDB_SPP_FP_IP_LR_PC) &&
		INSTR_IS(pc[i + 3], SUB_FP_IP_4PLUS) &&
		(INSTR_IS(pc[i + 1], STMDB_SPP_AREGS) ||
		 INSTR_IS(pc[i + 1], SUB_SP_SP)));

#endif /* (ARM_THUMB) */

    /*
     * if we're in the entry or exit sequence or, failing that, at a
     * function address that's in the symbol table, fake a stack frame
     * (if at a symbol, then we must be at the first instruction of a
     * routine).
     */

    if (in_entry_exit ||
        ((sysSymTbl != NULL) && (_func_symFindByValue != NULL) &&
	 ((* _func_symFindByValue) (sysSymTbl, (int) pc, name,
				    &val, &type) == OK) &&
	 (val == (int) pc)))
	{
	/* no stack frame - fake one */

	stackSave[0] = *(sp - 1);	/* save values we're going to clobber */
	stackSave[1] = *(sp - 2);
	stackSave[2] = *(sp - 3);
	stackSave[3] = *(sp - 4);

	*(sp - 1) = (int)pc;
#if (ARM_THUMB)
	*(sp - 2) = (int)lr;		/* use the extracted return address */
#else
	*(sp - 2) = (int)pRegSet->r[14];
#endif
	*(sp - 3) = (int)pRegSet->spReg;
	*(sp - 4) = (int)fp;

	fp = sp - 1;				/* points at saved PC */

        if (vxMemProbe ((char *)fp, VX_READ, 2, (char *)&insn) != OK    ||
            tcb->pStackBase < (char *)fp || tcb->pStackEnd > (char *)fp ||
            vxMemProbe ((char *)pc, VX_READ, 2, (char *)&insn) != OK)
            {
            if (_func_printErr != NULL)
                (* _func_printErr) ("trcStack aborted: error in top frame\n");
            return;			/* stack is untraceable */
            }

	trcStackLvl (tcb, fp, pc, 0, printRtn);	/* do stack trace */

	*(sp - 1) = stackSave[0];		/* restore stack */
	*(sp - 2) = stackSave[1];
	*(sp - 3) = stackSave[2];
	*(sp - 4) = stackSave[3];
	}
    else
	{
        if (vxMemProbe ((char *)fp, VX_READ, 2, (char *)&insn) != OK    ||
            tcb->pStackBase < (char *)fp || tcb->pStackEnd > (char *)fp ||
            vxMemProbe ((char *)pc, VX_READ, 2, (char *)&insn) != OK)
            {
            if (_func_printErr != NULL)
                (* _func_printErr) ("trcStack aborted: error in top frame\n");
            return;			/* stack is untraceable */
            }

	trcStackLvl (tcb, fp, pc, 0, printRtn);	/* do stack trace */
	}
    }

/*******************************************************************************
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
    WIND_TCB *tcb,      /* task control block */
    FAST int *fp,       /* stack frame pointer */
    INSTR *pc,          /* program counter */
    int depth,          /* recursion depth */
    FUNCPTR printRtn    /* routine to print single function call */
    )
    {
    FAST INSTR *returnAdrs;
    INSTR       insn;

    if (fp == NULL || vxMemProbe ((char *)fp, VX_READ, 2, (char *)&insn) != OK ||
        vxMemProbe ((char *)(fp - 1), VX_READ, 2, (char *)&insn) != OK ||
        vxMemProbe ((char *)(fp - 3), VX_READ, 2, (char *)&insn) != OK ||
        tcb->pStackBase < (char *)fp || tcb->pStackEnd > (char *)fp ||
        vxMemProbe ((char *)pc, VX_READ, 2, (char *)&insn) != OK)
        {
        if (_func_printErr != NULL)
            (* _func_printErr) ("trcStack aborted: error in frame\n");
	return;			/* stack is untraceable */
        }

    returnAdrs = (INSTR *) *(fp - 1);

    /*
     * Handle oldest calls first, up to MAX_TRACE_DEPTH of them
     * Note: unlike on other architectures, the previous fp is not
     * found at *fp but at *(fp - 3).
     */

    if ((*(fp - 3) != 0) && (depth < MAX_TRACE_DEPTH))
	trcStackLvl (tcb, (int *) *(fp - 3), returnAdrs, depth + 1, printRtn);

    (* printRtn) (trcFindCall (returnAdrs), trcFindFuncStart (fp, pc),
		  trcCountArgs (returnAdrs), fp + 1);
    }

/*******************************************************************************
*
* trcDefaultPrint - print a function call
*
* This routine is called by trcStack() to print each level in turn.
*
* If nargs is specified as 0, then a default number of args (trcDefaultArgs)
* is printed in brackets ("[..]"), since this often indicates that the
* number of args is unknown.
*
* NOTE: no args can be printed as code generator of gccarm provides no
*	way to determine what they are.
*/

LOCAL void trcDefaultPrint
    (
    INSTR *callAdrs,            /* address from which function was called */
    INSTR *funcAdrs,            /* address of function called */
    FAST int nargs,             /* number of arguments in function call */
    int *args                   /* pointer to function args */
    )
    {
    FAST int ix;
    BOOL doingDefault = FALSE;

    /* if there is no printErr routine do nothing */

    if (_func_printErr == NULL)
	return;

    /* print call address and function address */

    (* _func_printErr) ("%6x: %x (", callAdrs, funcAdrs);

    /* if no args are specified, print out default number (see doc at top) */

    if ((nargs == 0) && (trcDefaultArgs != 0))
	{
	doingDefault = TRUE;
	nargs = trcDefaultArgs;
	(* _func_printErr) ("[");
	}

    /* print args */

    for (ix = 0; ix < nargs; ++ix)
	{
	if (ix != 0)
	    (* _func_printErr) (", ");
	(* _func_printErr) ("%x", args[ix]);
	}

    if (doingDefault)
	(* _func_printErr) ("]");

    (* _func_printErr) (")\n");
    }

/*******************************************************************************
*
* trcFindCall - get address from which function was called
*
* RETURNS: address from which current subroutine was called, or NULL.
*/

LOCAL INSTR *trcFindCall
    (
    INSTR *returnAdrs           /* return address */
    )
    {
    FAST INSTR *addr;
    INSTR       insn;


    /* check for bad return address */

    if (returnAdrs == NULL ||
        vxMemProbe ((char *)returnAdrs, VX_READ, 2, (char *)&insn) != OK)
        {
	return NULL;
        }

    /*
     * Starting at the word preceding the return adrs, search for an
     * instruction which changes the PC. The ARM version, just like the 68K
     * one, keeps stepping back until it finds one or hits 0. It could stop
     * after n instructions.
     */

#if (ARM_THUMB)
    /* return address will have bit 0 set; mask it off */

    for (addr = (INSTR *)((UINT32)returnAdrs & ~1) - 1; addr != NULL; --addr)
	if (thumbInstrChangesPc(addr))
	    return addr;		/* found it */
#else
    for (addr = returnAdrs - 1; addr != NULL; --addr)
	if (armInstrChangesPc(addr))
	    return addr;		/* found it */
#endif

    return NULL;			/* not found */
    }

/*******************************************************************************
*
* trcFindDest - find destination of call instruction
*
* RETURNS: address to which call instruction will branch, or NULL if
* unknown
*/

LOCAL INSTR *trcFindDest
    (
    INSTR *callAdrs
    )
    {
	/*
	 * Extract offset, sign extend it and add it to current PC,
	 * adjusting for the pipeline.
	 */

#if (ARM_THUMB)
    /* BL comes in two halves */

    if (INSTR_IS(*callAdrs, T_BL0) && INSTR_IS(*(callAdrs + 1), T_BL1))
	return (INSTR *)((INT32)callAdrs + 4 +
	    (((((INT32)*callAdrs) << 21) >> 9) |
	     ((((INT32)*(callAdrs+1)) & 0x07FF) << 1)));
#else
    if (INSTR_IS(*callAdrs, BL))
	return (INSTR *)((INT32)callAdrs + 8 + ((INT32)(*callAdrs << 8) >> 6));
#endif

    return NULL;				/* don't know destination */
    }

/*******************************************************************************
*
* trcCountArgs - find number of arguments to function
*
* This routine finds the number of arguments passed to the called function
* by examining the stack-pop at the return address.  Many compilers offer
* optimization that defeats this (e.g., by coalescing stack-pops), so a return
* value of 0 may mean "don't know".
*
* RETURNS: number of arguments of function
*
* NOTE: no args can be printed as code generator of gccarm provides no
*	way to determine what they are.
*/

LOCAL int trcCountArgs
    (
    FAST INSTR *returnAdrs              /* return address of function call */
    )
    {
    return 0;				/* no args or unknown */
    }

/*******************************************************************************
*
* trcFindFuncStart - find the starting address of a function
*
* This routine finds the starting address of a function by one of several ways.
*
* If the given frame pointer points to a legitimate frame pointer, then the
* long word preceding the long word pointed to by the frame pointer should
* be the return address of the function call.  Then the instruction preceding
* the return address would be the function call, and the address can be gotten
* from there, provided that the call was to an absolute address. If it was,
* use that address as the function address.  Note that a routine that is
* called by other than a BL (e.g., indirectly) will not meet these
* requirements.
*
* If the above check fails, we search backward from the given pc until a
* routine entry sequence is found (see trcStack() above for description of
* routine prologues).
*
* If the compiler is inserting these sequences at the beginning of ALL
* subroutines, then this will reliably find the start of the routine.
* However, some compilers allow routines, especially "leaf" routines that
* don't call any other routines, NOT to have stack frames, which will cause
* this search to fail.
*
* In either of the above cases, the value is bounded by the nearest routine
* in the system symbol table, if there is one.  If neither method returns a
* legitimate value, then the value from the symbol table is used.  Note that
* the routine may not be in the symbol table if it is LOCAL, etc.
*
* Note that the start of a routine that is not called by BL and
* doesn't start with a frame creation sequence and isn't in the symbol table,
* may not be possible to locate.
*/

LOCAL INSTR *trcFindFuncStart
    (
    int *fp,                    /* frame pointer resulting from function call */
    FAST INSTR *pc              /* address somewhere within the function */
    )
    {
    FAST INSTR *ip;		/* instruction pointer */
    FAST INSTR *minPc;		/* lower bound on program counter */
    int         val;		/* address gotten from symbol table */
    char name[MAX_SYS_SYM_LEN];	/* string associated with val */
    SYM_TYPE    type;		/* type associated with val */
    INSTR       insn;

    /*
     * if there is a symbol table, use value from table that's <= pc as
     * lower bound for function start
     */

    minPc = NULL;

    if ((sysSymTbl != NULL) && (_func_symFindByValue != NULL) &&
	((* _func_symFindByValue) (sysSymTbl, (int) pc, name,
				   &val, &type) == OK))
	{
	minPc = (INSTR *) val;
	}


    /* try to find current function by looking up call */

    if (fp != NULL &&
        vxMemProbe ((char *)(fp - 1), VX_READ, 2, (char *)&insn) == OK) /* frame pointer valid? */
	{
	ip = trcFindCall ((INSTR *) *(fp - 1));
	if (ip != NULL)
	    {
	    ip = trcFindDest (ip);
	    if ((ip != NULL) && (ip >= minPc) && (ip <= pc))
		return (ip);
	    }
	}


    /*
     * Search backward for routine entry sequence (prologue),
     * for possible sequences, refer to trcStack() above.
     */


#if (ARM_THUMB)
    for (; pc >= minPc; --pc)
	{
	if ((INSTR_IS(pc[0], T_PUSH_LO) &&
	     INSTR_IS(pc[1], T_SUB_SP_16) &&
	     INSTR_IS(pc[2], T_PUSH) &&
	     INSTR_IS(pc[3], T_ADD_LO_SP)) ||

	    (INSTR_IS(pc[0], T_SUB_SP_16) &&
	     INSTR_IS(pc[1], T_PUSH) &&
	     INSTR_IS(pc[2], T_ADD_LO_SP)) ||

	    (INSTR_IS(pc[0], T_SUB_SP_16) &&
	     INSTR_IS(pc[1], T_ADD_LO_SP)))
	    return pc;	   /* return address of first instruction of prologue */
	}
#else
    for (; pc >= minPc; --pc)
	{
	if (INSTR_IS(pc[0], MOV_IP_SP) &&
	    ((INSTR_IS(pc[1], STMDB_SPP_FP_IP_LR_PC) &&
	      INSTR_IS(pc[2], SUB_FP_IP_4)) ||
	     (INSTR_IS(pc[2], STMDB_SPP_FP_IP_LR_PC) &&
	      INSTR_IS(pc[3], SUB_FP_IP_4PLUS) &&
	      (INSTR_IS(pc[1], STMDB_SPP_AREGS) ||
	       INSTR_IS(pc[1], SUB_SP_SP)))))
	    return pc;		/* return address of MOV ip,sp */
	}
#endif

    return minPc;		/* return nearest symbol in sym tbl */
    }

