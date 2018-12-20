/* trcLib.c - ColdFire stack trace library */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,16jan02,rec  fix name length for symFindByValue
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
This module provides a routine, trcStack(), which traces a stack
given the current frame pointer, stack pointer, and program counter.
The resulting stack trace lists the nested routine calls and their arguments.

This module provides the low-level stack trace facility.
A higher-level symbolic stack trace, implemented on top of this facility,
is provided by the routine tt() in dbgLib.

SEE ALSO: dbgLib, tt(),
.pG "Debugging"
*/

#include "vxWorks.h"
#include "regs.h"
#include "stdio.h"
#include "symLib.h"
#include "sysSymTbl.h"
#include "private/funcBindP.h"

#define MAX_TRACE_DEPTH 40 /* maximum number of levels of stack to trace */

/* instruction words */

#define LINK_A6		0x4e56		/* LINK A6,... */
#define RTS		0x4e75		/* RTS */
#define JSR_ABS		0x4eb9		/* JSR abs */
#define ADD_W		0xdefc		/* ADD.W */
#define ADD_L		0xdffc		/* ADD.L */
#define ADDQ_W		0x504f		/* ADDQ.W A7 */
#define ADDQ_L		0x508f		/* ADDQ.L A7 */
#define LEA_A7		0x4fef		/* LEA $x(A7),A7 */
#define MOVE_L_A7	0x2e80		/* MOVE.L xxx,(A7) */
#define MOVE_L_A6_A7	0x2e75		/* MOVE.L (xxx,A6),A7 */

/* globals */

int trcDefaultArgs = 5;			/* default # of args to print if trc
					 * can't figure out how many */

/* forward static functions */

static void trcStackLvl (int *fp, INSTR *pc, int depth, FUNCPTR printRtn);
static void trcDefaultPrint (INSTR *callAdrs, INSTR *funcAdrs, int nargs, int
		*args);
static INSTR *trcFindCall (INSTR *returnAdrs);
static INSTR *trcFindDest (INSTR *callAdrs);
static int trcCountArgs (INSTR *returnAdrs);
static INSTR *trcFindFuncStart (int *fp, INSTR *pc);
static INSTR *trcFollowBra (INSTR *adrs);


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
* routines that start with a LINK instruction.  Most VxWorks assembly
* language routines include LINK instructions for exactly this reason.
* However, routines written in other languages, strange entries into
* routines, or tasks with corrupted stacks can confuse the trace.  Also, all
* parameters are assumed to be 32-bit quantities, therefore structures
* passed as parameters will be displayed as a number of long integers.
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
    int		val;			/* address gotten from symbol table */
    char	name[MAX_SYS_SYM_LEN+1]; /* string associated with val */
    SYM_TYPE	type;			/* type associated with val */
    INSTR	instr;			/* next instruction */
    int		stackSave;
    FAST INSTR *pc = pRegSet->pc;
    FAST int *fp = (int *) pRegSet->fpReg;
    FAST int *sp = (int *) pRegSet->spReg;

    /* use default print routine if none specified */

    if (printRtn == NULL)
	printRtn = (FUNCPTR) trcDefaultPrint;

    /*
     * if the current routine doesn't have a stack frame, then we fake one
     * by putting the old one on the stack and making fp point to that;
     * we KNOW we don't have a stack frame in a few restricted but useful
     * cases:
     *  1) we are at a LINK or RTS instruction,
     *  2) we are the first instruction of a subroutine (this may NOT be
     *     a LINK instruction with some compilers)
     */

    instr = *trcFollowBra (pc);

    if ((instr == LINK_A6) || (instr == RTS) ||
        ((sysSymTbl != NULL) && (_func_symFindByValue != NULL) &&
	 ((* _func_symFindByValue) (sysSymTbl, (int) pc, name, 
				    &val, &type) == OK) &&
	 (val == (int) pc)))
	{
	/* no stack frame - fake one */

	stackSave = *(sp - 1);		/* save value we're going to clobber */
	*(sp - 1) = (int)fp;		/* make new frame pointer by */
					/* sticking old one on stack */
	fp = sp - 1;			/* and pointing to it */

	trcStackLvl (fp, pc, 0, printRtn);	/* do stack trace */

	*(sp - 1) = stackSave;		/* restore stack */
	}
    else
	{
	trcStackLvl (fp, pc, 0, printRtn);	/* do stack trace */
	}
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
    FAST int *fp,       /* stack frame pointer (A6) */
    INSTR *pc,          /* program counter */
    int depth,          /* recursion depth */
    FUNCPTR printRtn    /* routine to print single function call */
    )
    {
    FAST INSTR *returnAdrs;

    if (fp == NULL)
	return;			/* stack is untraceable */

    returnAdrs = (INSTR *) *(fp + 1);

    /* handle oldest calls first, up to MAX_TRACE_DEPTH of them */

    if ((*fp != NULL) && (depth < MAX_TRACE_DEPTH))
	trcStackLvl ((int *) *fp, returnAdrs, depth + 1, printRtn);

    (* printRtn) (trcFindCall (returnAdrs), trcFindFuncStart (fp, pc),
		  trcCountArgs (returnAdrs), fp + 2);
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
/****************************************************************************
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

    /* starting at the word preceding the return adrs, search for jsr or bsr */

    for (addr = returnAdrs - 1; addr != NULL; --addr)
	if (((*addr & 0xffc0) == 0x4e80) || ((*addr & 0xff00) == 0x6100))
	    return (addr);		/* found it */

    return (NULL);			/* not found */
    }
/****************************************************************************
*
* trcFindDest - find destination of call instruction
*
* RETURNS: address to which call instruction (jsr) will branch, or NULL if
* unknown
*/

LOCAL INSTR *trcFindDest
    (
    INSTR *callAdrs
    )
    {
    if (*callAdrs == JSR_ABS)			/* jsr absolute long mode? */
	return ((INSTR *) *(int *)(callAdrs + 1));	/* return next long */

    return (NULL);				/* don't know destination */
    }
/****************************************************************************
*
* trcCountArgs - find number of arguments to function
*
* This routine finds the number of arguments passed to the called function
* by examining the stack-pop at the return address.  Many compilers offer
* optimization that defeats this (e.g., by coalescing stack-pops), so a return
* value of 0 may mean "don't know".
*
* RETURNS: number of arguments of function
*/

LOCAL int trcCountArgs
    (
    FAST INSTR *returnAdrs              /* return address of function call */
    )
    {
    FAST INSTR inst;
    FAST int nargs;
    FAST int tmpNargs;


    nargs = 0;

    /* if inst is a BRA, use the target of the BRA as the returnAdrs */

    returnAdrs = trcFollowBra (returnAdrs);
    inst = *returnAdrs;		/* get the instruction */

    if (inst == ADD_W)
	nargs = *(returnAdrs + 1) >> 2;		/* ADD.W */
    else if (inst == ADD_L)
	nargs = *(int *)(returnAdrs + 1) >> 2;	/* ADD.L */
    else if (((inst & 0xF1FF) == ADDQ_W) || ((inst & 0xF1FF) == ADDQ_L))
	{
	/* there may be multiple addq's at the return addrs */
	do
	    {
	    /* get the number of bytes and div by 4 to get the number of args */

	    tmpNargs = (inst & 0x0E00) >> 11;	/* ADDQ.L or ADDQ.W */
	    if (tmpNargs == 0)
	    	tmpNargs = 2;			/* 0 => 8 in quick mode */

	    nargs += tmpNargs;

	    returnAdrs++;			/* sizeof ADDQ */
	    inst = *returnAdrs;			/* check next instruction */

	    } while (((inst & 0xF1FF) == ADDQ_W) || 
		     ((inst & 0xF1FF) == ADDQ_L));

	}
    else if (inst == LEA_A7)
	nargs = *(returnAdrs + 1) >> 2;		/* LEA $x(A7),A7 */
    else if ((inst & 0xFFC0) == MOVE_L_A7)
	nargs = 1;				/* MOVE.L xxx,(A7) */
    else if (inst == MOVE_L_A6_A7)
	nargs = 8;				/* MOVE.L (xxx,A6),A7
						   # of args unknowable */
    else
	nargs = 0;				/* no args, or unknown */

    return (nargs);
    }
/****************************************************************************
*
* trcFindFuncStart - find the starting address of a function
*
* This routine finds the starting address of a function by one of several ways.
*
* If the given frame pointer points to a legitimate frame pointer, then the
* long word following the frame pointer pointed to by the frame pointer should
* be the return address of the function call.  Then the instruction preceding
* the return address would be the function call, and the address can be gotten
* from there, provided that the jsr was to an absolute address.  If it was,
* use that address as the function address.  Note that a routine that is
* called by other than a jsr-absolute (e.g., indirectly) will not meet these
* requirements.
*
* If the above check fails, we search backward from the given pc until a
* LINK instruction is found.  If the compiler is putting LINK instructions
* as the first instruction of ALL subroutines, then this will reliably find
* the start of the routine.  However, some compilers allow routines, especially
* "leaf" routines that don't call any other routines, to NOT have stack frames,
* which will cause this search to fail.
*
* In either of the above cases, the value is bounded by the nearest routine
* in the system symbol table, if there is one.  If neither method returns a
* legitimate value, then the value from the symbol table is used.  Note that
* the routine may not be in the symbol table if it is LOCAL, etc.
*
* Note that the start of a routine that is not called by jsr-absolute and
* doesn't start with a LINK and isn't in the symbol table, may not be possible
* to locate.
*/

LOCAL INSTR *trcFindFuncStart
    (
    int *fp,                    /* frame pointer resulting from function call */
    FAST INSTR *pc              /* address somewhere within the function */
    )
    {
    FAST INSTR *ip;		/* instruction pointer */
    FAST INSTR *minPc;		/* lower bound on program counter */
    int val;			/* address gotten from symbol table */
    char name[MAX_SYS_SYM_LEN+1]; /* string associated with val */
    SYM_TYPE type;		/* type associated with val */

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

    if (fp != NULL)			/* frame pointer legit? */
	{
	ip = trcFindCall ((INSTR *) *(fp + 1));
	if (ip != NULL)
	    {
	    ip = trcFindDest (ip);
	    if ((ip != NULL) && (ip >= minPc) && (ip <= pc))
		return (ip);
	    }
	}

    /* search backward for LINK A6,#xxxx */

    for (; pc >= minPc; --pc)
	{
	if (*trcFollowBra (pc) == LINK_A6)
	    return (pc);		/* return address of LINK_A6 */
	}

    return (minPc);		/* return nearest symbol in sym tbl */
    }
/*********************************************************************
*
* trcFollowBra - resolve any BRA instructions to final destination
*
* This routine returns a pointer to the next non-BRA instruction to be
* executed if the pc were at the specified <adrs>.  That is, if the instruction
* at <adrs> is not a BRA, then <adrs> is returned.  Otherwise, if the
* instruction at <adrs> is a BRA, then the destination of the BRA is
* computed, which then becomes the new <adrs> which is tested as before.
* Thus we will eventually return the address of the first non-BRA instruction
* to be executed.
*
* The need for this arises because compilers may put BRAs to instructions
* that we are interested in, instead of the instruction itself.  For example,
* optimizers may replace a stack pop with a BRA to a stack pop.  Or in very
* UNoptimized code, the first instruction of a subroutine may be a BRA to
* a LINK, instead of a LINK (compiler may omit routine "post-amble" at end
* of parsing the routine!).  We call this routine anytime we are looking
* for a specific kind of instruction, to help handle such cases.
*
* RETURNS: address that chain of branches points to.
*/

LOCAL INSTR *trcFollowBra
    (
    FAST INSTR *adrs
    )
    {
    FAST INSTR inst = *adrs;	/* 16 bit instruction at adrs */
    FAST int displacement;

    /* while instruction is a BRA, get destination adrs */

    while ((inst & 0xff00) == 0x6000)
	{
	++adrs;			/* point to word following instr */

	switch (inst & 0xff)
	    {
	    case 0:			/* 16 bit displacement */
		displacement = (short) *adrs;
		break;
	    case 0xff:			/* 32 bit displacement */
		displacement = (*adrs << 16) | *(adrs + 1);
		break;
	    default:			/* 8 bit displacement */
		displacement = (char) (inst & 0xff);

		/* check for branch to self, or to odd displacement */

		if ((displacement == 0xfe) || (displacement & 0x01))
		    return (--adrs);	/* don't follow it */

		break;
	    }

	adrs = (INSTR *) ((char *) adrs + displacement);

	inst = *adrs;		/* get the instruction */
	}

    return (adrs);
    }
