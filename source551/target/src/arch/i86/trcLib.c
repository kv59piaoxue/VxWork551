/* trcLib.c - i80x86 stack trace library */

/* Copyright 1984-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01g,16sep02,pai  Cleaned up data types & formatting.  Added additional
                 instruction patterns.  Moved manifest constants to common
                 header file.  Added notes on IA-32 cross-compiler stack
                 frame structures.
01f,16jan02,pai  replaced obsolete symFindByValue (_func_symFindByValue) with
                 symByValueFind.  Removed FAST variable qualifier.
                 Cleaned up formatting and updated copyright for T2.2.
01e,12may95,p_m  adapted to support host based tt().
01d,26oct94,hdn  added a MAX_LOOPCOUNT to avoid infinite loop.
01c,09dec93,hdn  added a forward declaration of trcCountArgs().
                 commented out trcFollowJmp(pc) in trcFindFuncStart().
01b,01jun93,hdn  added third parameter tid to trcStack().
                 updated to 5.1.
                  - changed functions to ansi style
                  - changed VOID to void
                  - changed copyright notice
01a,16jul92,hdn  written based on TRON version.
*/

/*
This module provides a routine, trcStack(), which traces a stack
given the current frame pointer, stack pointer, and program counter.
The resulting stack trace lists the nested routine calls and their arguments.

This module provides the low-level stack trace facility.
A higher-level symbolic stack trace, implemented on top of this facility,
is provided by the routine tt() in dbgLib.

INTERNAL
The IA-32 architecture supports procedure calls in the following two
different ways:

    o CALL and RET instructions.

    o ENTER and LEAVE instructions, in conjuntion with the CALL and RET
      instructions.

Both of these procedure call mechanisms use the procedure stack ("the
stack") to save the state of the calling procedure, pass parameters to the
called procedure, and store local variables for the currently executing
procedure.

The processor's facilities for handling interrupts and exceptions are
similar to those used by the CALL and RET instructions.

The stack is a contiguous array of memory locations.  Each VxWorks task
has its own stack of a size and location specified when the task was
created.

The next available memory location on the stack is called the top of
stack.  At any given time, the stack pointer (contained in the ESP
register) gives the address (the offset from the base of the stack
segement) to the top of the stack.

Items are placed on the stack using a PUSH instruction and removed from
the stack using the POP instruction.  When an item is pushed onto the
stack, the processor decrements the ESP register, then writes the item at
the new top of stack.  When an item is popped off the stack, the processor
reads the item from the top of stack, then increments the ESP register.
In this manner, the stack grows down in memory (towards lower addresses)
when items are pushd on the stack and shrinks up (towards higher
addresses) when the items are popped from the stack.

The processor provides two pointers for linking of procedures: the
stack-frame base pointer and the return instruction pointer.  These
pointers are intended to permit reliable and coherent linking of
procedures.

The stack is typically divided into frames.  Each frame can contain local
variables, parameters to be passed to another procedure, and procedure
linking information.  The stack-frame base pointer (contained in the EBP
register) identifies a fixed reference point within the stack frame for
the called procedure.  To use the stack-frame base pointer, the called
procedure typically saves the current EBP contents (by pushing the
register), then copies the contents of the ESP register into the EBP
register.  The EBP value is then used as a base address for accessing
procedure parameters and local variables for the life of the procedure.
Before returning, the procedure will restore ESP from EBP and pop the
saved EBP register value from the stack.

Prior to branching to the first instruction of the called procedure, the
CALL instruction pushes the address in the EIP register onto the current
stack.  This address is then called the return-instruction pointer and it
points to the instruction where execution of the calling procedure should
resume following a return from the called procedure.  Upon returning from
a called procedure, the RET instruction pops the return-instruction
pointer from the stack back into the EIP register.

The IA-32 processors have a few variations on CALL and RET operations.
For example, there are procedure call variations that allow calls to
different segments and different privilege levels, as well as variations
related to interrupt and exception handlers.  In addition, arguments can
be passed in registers or on the stack.

The IA-32 calling convention for the VxWorks C/C++ cross-compilers and
runtime are fairly straight-forward (with one major exception) and
consistent with what is used in several major IA-32 development
environments.  Generally C-language source functions are compiled down
to procedures using the near CALL and RET operation.  When executing a
near call, the processor does the following:

    (1) Parameters to a procedure are pushed on the stack in order from
        right to left (as the parameters appear in the source code).

    (2) The CALL instruction pushes the current value of EIP on the stack.

    (3) The offset of the called procedure is loaded into the EIP
        register.

    (4) The called procedure begins executing.

When executing a near return, the processor does the following:

    (1) The return instruction pointer is popped into the EIP register.

    (2) If the RET instruction has an optional <n> argument, the stack
        pointer is incremented by the number of bytes specified with the
        <n> operand to release parameters from the stack.  VxWorks code
        does not do this - the caller cleans the stack, not the callee.

    (3) Execution is resumed at the caller on instructions that clean
        the stack (increment the stack pointer) based on the number of
        parameters passed to the routine being returned from.

A hypothetical stack frame for a routine with (3) 32-bit paramaters and (2)
local variables might appear as follows:

.bS
                                                 High Memory
                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Previous ESP -->|                              |
                |------------------------------|     Stack grows downwards 
                | parameter 3                  |              |
                |------------------------------|              |
                | parameter 2                  |              |
                |------------------------------|              v
                | parameter 1                  | [EBP+8]
                |------------------------------|
                | return address               | [EBP+4]
                |------------------------------|
New EBP ------->| previous EBP                 | [EBP]
                |------------------------------|
                | local variable 1             | [EBP-4]
                |------------------------------|
New ESP ------->| local variable 2             | [EBP-8]
                |------------------------------|
                |                              |
                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
                                                 Low Memory
.bE

In the example above, the EBP register is used as the stack "frame pointer".
The EBP register, once initialized on function entry, can be used to access
any of the procedure parameters and local variables in addition to the
procedure return address.  The usual prologue and epilogue code used to
support this model is as follows (Intel assembly syntax):

.CS
    foo:
        push  ebp
        mov   ebp, esp
        ...
        mov   esp, ebp
        pop   ebp
        ret
.CE

The ENTER and LEAVE instructions support an alternate method for creating
and destroying stack frames.  The ENTER instruction has two operands.  It
is not necessary to understand the use of these operands in this stack
tracing library.  With respect to ENTER and LEAVE instructions, it is
important to note that an EBP-based stack frame is created and destroyed
in a manner that is equivalent to the preceding example.

.CS
    foo:
        enter m,n    ; push EBP, then copy ESP to EBP
        ...
        leave        ; copy EBP to ESP, then pop EBP
        ret
.CE

The Tornado 2.2 IA-32 cross-compiler does not generate subroutine stack
setup code in the manner described above when the -msse compiler flag is
used.  The -msse flag will cause the compiler to generate prologue and
epilogue code which is used to dynamically align stack variables on
16-byte addresses, as required for most SSE/SSE2 memory operands.  The
mechanics behind this alignment and other SSE/SSE2 ABI conventions
introduced in the Intel compiler are discussed in the Intel Application
Note AP-589.  Note that the Tornado 2.2 IA-32 cross-compiler (version
2.9-PentiumIII-010221) is essentially the "Intel C/C++ Compiler".

A 128-bit vendor-specific data type named __m128 may imply the following
extensions to the IA-32 ABI:

    o Functions that use Streaming SIMD Extensions data provide
      a 16-byte-aligned stack frame.

    o __m128 parameters are aligned, possibly creating "holes"
      (padding) in the argument block.

    o __m128 parameters may be passed in registers.

    o The first (3) __m128 parameters are passed in registers xmm0,
      xmm1, and xmm2.  Additional __m128 parameters are passed on
      the stack as usual.

    o __m128 return values are passed in xmm0.

    o Registers xmm0 through xmm7 are caller-save.

Subroutines that use the __m128 data type must have 16-byte-aligned stack
frames (for local variables of type __m128) to meet alignment requirements
for SSE memory operands.

The current Intel compiler resolves the 16-byte-alignment requirement by
inserting function prologue and epilogue code to dynamically align the stack
appropriately.

As an optimization, an alternate entry point will be created that can be
called when proper stack alignment is guaranteed by the caller.  Through
call graph analysis, calls to the unaligned entry point can be optimized
into calls to the aligned entry point when the stack can be proven to be
properly aligned.

SEE ALSO: dbgLib, tt(),
.pG "Debugging"
*/

/* includes */

#include "vxWorks.h"
#include "dbgLib.h"
#include "regs.h"
#include "stdio.h"
#include "stdlib.h"
#include "symLib.h"
#include "sysSymTbl.h"
#include "taskLib.h"
#include "private/funcBindP.h"


/* imports */

IMPORT int vxTaskEntry ();


/* globals */

/* default number of arguments printed from trcDefaultPrint() */

int trcDefaultArgs = 5;


/* forward declarations */

LOCAL const INSTR * trcFindCall (const INSTR *);
LOCAL const INSTR * trcFindFuncStart (const INSTR *);
LOCAL const INSTR * trcFindReturnAddr (const int *, const INSTR *);
LOCAL const INSTR * trcFindDest (const INSTR *);
LOCAL const INSTR * trcFollowJmp (const INSTR *);
LOCAL void  trcDefaultPrint (const INSTR *, const INSTR *, int, const int *);
LOCAL void  trcStackLvl (const int *, const INSTR *, const char *, const char *, FUNCPTR);
LOCAL int   trcCountArgs (const INSTR *);



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
*     void printRtn
*         (
*         INSTR *  callAdrs,  /@ address from which routine was called @/
*         int      rtnAdrs,   /@ address of routine called             @/
*         int      nargs,     /@ number of arguments in call           @/
*         int *    args       /@ pointer to arguments                  @/
*         )
* .CE
* If <printRtn> is NULL, a default routine will be used that prints out just
* the call address, the function address, and the arguments as hexadecimal
* values.
*
* CAVEAT
* In order to do the trace, a number of assumptions are made.  In general,
* the trace will work for all C language routines and for assembly language
* routines that start with an PUSH %EBP MOV %ESP %EBP instruction.  Most 
* VxWorks assembly language routines include PUSH %EBP MOV %ESP %EBP 
* instructions for exactly this reason.
* However, routines written in other languages, strange entries into
* routines, or tasks with corrupted stacks can confuse the trace.  Also,
* all parameters are assumed to be 32-bit quantities, therefore structures
* passed as parameters will be displayed as a number of long integers.
*
* EXAMPLE
* The following sequence can be used
* to trace a VxWorks task given a pointer to the task's TCB:
* .CS
* REG_SET regSet;        /@ task's data registers @/
*
* taskRegsGet (taskId, &regSet);
* trcStack (&regSet, (FUNCPTR) printRtn, tid);
* .CE
*
* SEE ALSO: tt()
*
* NOMANUAL
*/
void trcStack
    (
    REG_SET *  pRegSet,        /* pointer to a task register set */
    FUNCPTR    printRtn,       /* routine to print single function call */
    int        tid             /* task's id */
    )
    {
    STATUS     symStatus = ERROR;
    int        val       = 0;


    /* Extract the program counter (EIP), stack pointer (ESP), and
     * frame pointer (EBP) values from the register structure.
     */

    const INSTR * const  pc  = pRegSet->pc;
    const int * const    sp  = (int *) pRegSet->esp;
    const int *          fp  = (int *) pRegSet->ebp;

    const char * const   pStackBase  = taskTcb(tid)->pStackBase;
    const char * const   pStackLimit = taskTcb(tid)->pStackLimit;



    /* Find the address of the next instruction that is not a JMP. */

    const INSTR * const  addr = trcFollowJmp (pc);



    /* use default print routine if none specified */

    if (printRtn == NULL)
        {
        printRtn = (FUNCPTR) trcDefaultPrint;
        }



    /* If there is a symbol table, use it to test whether (pc) is on
     * the first instruction of a subroutine.
     */

    if (sysSymTbl != NULL)
        {
        char *     pName = NULL;  /* function name from symbol table */
        SYM_TYPE   type;          /* function type from symbol table */

        symStatus = symByValueFind (sysSymTbl, (int) pc, &pName, &val, &type);

        if (pName != NULL)
            {
            free (pName);         /* new API requires this */
            }
        }


    /*
     * if the current routine doesn't have a stack frame, then we fake one
     * by putting the old one on the stack and making fp point to that;
     * we KNOW we don't have a stack frame in a few restricted but useful
     * cases:
     *  1) we are at a PUSH %EBP MOV %ESP %EBP or RET or ENTER instruction,
     *  2) we are the first instruction of a subroutine (this may NOT be
     *     a PUSH %EBP MOV %ESP %EBP instruction with some compilers)
     */

    if ((DSM (addr,     PUSH_EBP, PUSH_EBP_MASK) && 
         DSM (addr + 1, MOV_ESP0, MOV_ESP0_MASK) &&
         DSM (addr + 2, MOV_ESP1, MOV_ESP1_MASK)) ||

        (DSM (addr,   ENTER,    ENTER_MASK)    ||
         DSM (addr,   RET,      RET_MASK)      ||
         DSM (addr,   RETADD,   RETADD_MASK))   ||

        ((symStatus == OK) && (val == (int) pc)))
        {
        /* The stack frame is not created yet, so we'll simulate one by
         * first saving the value (ESP-1), storing the current EBP value
         * at that location, then setting EBP to the location where its
         * old value was saved.  This is approximately equivalent to:
         *
         *     func:
         *         push  ebp
         *         mov   ebp, esp
         *     ...
         */

        int stackSave = *(sp - 1);
        *((int *) sp - 1) = (int) fp;

        fp = (sp - 1);

        trcStackLvl (fp, pc, pStackBase, pStackLimit, printRtn);

        *((int *) sp - 1) = stackSave;    /* restore saved stack variable */
        }
    else if (DSM (addr - 1, PUSH_EBP, PUSH_EBP_MASK) && 
             DSM (addr,     MOV_ESP0, MOV_ESP0_MASK) &&
             DSM (addr + 1, MOV_ESP1, MOV_ESP1_MASK))
        {
        fp = sp;
        trcStackLvl (fp, pc, pStackBase, pStackLimit, printRtn);
        }
    else
        {
        trcStackLvl (fp, pc, pStackBase, pStackLimit, printRtn);
        }
    }

/*******************************************************************************
*
* trcStackLvl - recursive stack trace routine
*
* This routine is recursive, being called once for each level of routine
* nesting.
*
* INTERNAL
* Whether or not the return address is at (frame ptr + 1) really depends
* upon whether the current frame was compiled with -msse and whether the
* current routine has locals passed from the caller.  In the latter case,
* EBX is pushed, in addition to EBP and ESI for the former case.  The
* following fragments illustrate the cases typically encountered when
* -msse is used to build a body of code:
*
*     int foo (int) { int x; ... }
*     -------------------------------------------
*     foo:
*        55                      push   %ebp
*        56                      push   %esi
*        53                      push   %ebx
*        89 e6                   mov    %esp,%esi
*     ...
*     foo.aligned:
*        55                      push   %ebp
*        56                      push   %esi
*        53                      push   %ebx
*        89 e6                   mov    %esp,%esi
*     ...
*
*     int foo (int) { ... }
*     -------------------------------------------
*     foo:
*        55                      push   %ebp
*        56                      push   %esi
*        89 e6                   mov    %esp,%esi
*     ...
*     foo.aligned:
*        55                      push   %ebp
*        56                      push   %esi
*        89 e6                   mov    %esp,%esi
*     ...
*
* RETURNS: N/A
*
* NOMANUAL
*/
LOCAL void trcStackLvl
    (
    const int *    fp,          /* stack frame pointer */
    const INSTR *  pc,          /* program counter */
    const char *   pStackBase,  /* stack bottom (highest memory address) */
    const char *   pStackLimit, /* stack top (lowest memory address) */
    FUNCPTR        printRtn     /* routine to print single function call */
    )
    {
    const INSTR *  returnAdrs;


    /* XXX NOTE XXX
     * (fp+2) is supposed to represent the stack address of the arguments
     * passed to this frame.  This value should be wrapped in a macro in
     * case there is a requirement to change it.
     */

    if ((((char *)(fp + 2) + (MAX_TASK_ARGS * sizeof(int))) > pStackBase) ||
        ((char *)(fp) < pStackLimit))
        {
        return;
        }


    /* XXX NOTE XXX
     * This assumption does not work in the case of stack frames generated
     * with the -msse compiler option.  We have to dynamically determine
     * whether we are in a routine where the return address is at a scaled
     * offset of 1, 2, or 3 from the frame pointer for the current routine.
     *
     *     returnAdrs = (const INSTR *) *(fp + 1);
     */

    returnAdrs = trcFindReturnAddr (fp, pc);

    /* handle oldest calls first */

    trcStackLvl ((const int *)(*fp), returnAdrs, pStackBase,
                 pStackLimit, printRtn);

    (* printRtn) (trcFindCall (returnAdrs), trcFindFuncStart (pc),
                  trcCountArgs (returnAdrs), fp + 2);
    }

/*******************************************************************************
*
* trcFindReturnAddr - find the return address of a function
*
* Given a program counter <pc> and a frame pointer <fp> for a function
* with an "activated" stack frame, this routine will find the address in
* the calling function to which the function will return.
*
* INTERNAL
* The Tornado 2.2 cross-compiler subroutine prologues are typically
* generated as follows:
*
*     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*     ...
*     8b 65 00   mov    0x0(%ebp),%esp
*     5e         pop    %esi
*     5d         pop    %ebp
*     c3         ret
*
*     = 8b65005e 5dc3 ==> [esp+8] has the return address
*
*     OR
*     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*     ...
*     8b 65 00   mov    0x0(%ebp),%esp
*     5b         pop    %ebx
*     5e         pop    %esi
*     5d         pop    %ebp
*     c3         ret
*
*     = 8b65 005b5e5d c3 ==> [esp+12] has the return address
*
* In other words, extract unaligned stack pointer from the location
* specified in EBP, then get the return address at an offset from the
* unaligned stack pointer.
*
* RETURNS: The return address for some active function.
*
* NOMANUAL
*/
LOCAL const INSTR * trcFindReturnAddr
    (
    const int *    fp,          /* stack frame pointer */
    const INSTR *  pc           /* program counter */
    )
    {
    FOREVER
        {
        if (DSM (pc, LEAVE,  LEAVE_MASK))
            {
            return (const INSTR *) *(fp + 1);
            }

        if (DSM (pc, RET, RET_MASK) || DSM (pc, RETADD, RETADD_MASK))
            {
            if ((UINT32) *(pc - 4) == 0x5d5e5b00)
                {
                /* this is not exactly right ... */

                fp += 3;

                return (const INSTR *) (*fp);
                }
            else if ((UINT32) *(pc - 4) == 0x5d5e0065)
                {
                /* this is not exactly right ... */

                fp += 2;

                return (const INSTR *) (*fp);
                }

            ++fp;
            return (const INSTR *) (*fp);
            }

        ++pc;
        }
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
*
* RETURNS: N/A
*
* NOMANUAL
*/
LOCAL void trcDefaultPrint
    (
    const INSTR * callAdrs,   /* address from which function was called */
    const INSTR * funcAdrs,   /* address of function called */
    int           nargs,      /* number of arguments in function call */
    const int *   args        /* pointer to function args */
    )
    {
    int     i;
    BOOL    doingDefault = FALSE;

    /* if there is no printErr routine do nothing */

    if (_func_printErr == NULL)
        return;

    /* print call address and function address */

    (* _func_printErr) ("%8x: %x (", callAdrs, funcAdrs);

    /* if no args are specified, print out default number (see doc at top) */

    if ((nargs == 0) && (trcDefaultArgs != 0))
        {
        doingDefault = TRUE;
        nargs = trcDefaultArgs;
        (* _func_printErr) ("[");
        }

    /* print subroutine arguments */

    for (i = 0; i < nargs; ++i)
        {
        if (i != 0)
            {
            (* _func_printErr) (", ");
            }

        (* _func_printErr) ("%x", args[i]);
        }

    if (doingDefault)
        {
        (* _func_printErr) ("]");
        }

    (* _func_printErr) (")\n");
    }

/*******************************************************************************
*
* trcFindCall - get address from which function was called
*
* INTERNAL
* There is a bit of trouble with this routine.  Given the <returnAdrs>
* for some function, we are trying to go to that text address, and then
* back up the program counter and look for the CALL instruction that
* invoked the function.  The problem is that there are several CALL
* instruction formats that the test/filter is NOT looking for.  Thus,
* this routine could easilly fail to find the address from which a
* function was called.  The test/filter needs to be more sophisticated.
*
* RETURNS: Address from which current subroutine was called, or NULL.
*
* NOMANUAL
*/
LOCAL const INSTR * trcFindCall
    (
    const INSTR * returnAdrs  /* return address */
    )
    {
    const INSTR * addr;       /* points to executable instruction address */

    /* starting at the word preceding the return adrs, search for CALL */

    for (addr = returnAdrs - 1; addr != NULL; --addr)
        {
        if ((DSM (addr,     CALL_INDIR0,        CALL_INDIR0_MASK) &&
            (DSM (addr + 1, CALL_INDIR_REG_EAX, CALL_INDIR_REG_MASK) ||
             DSM (addr + 1, CALL_INDIR_REG_EDX, CALL_INDIR_REG_MASK) ||
             DSM (addr + 1, CALL_INDIR1,        CALL_INDIR1_MASK))) ||
            (DSM (addr,     CALL_DIR,           CALL_DIR_MASK)))
            {
            return (addr);     /* found it */
            }
        }

    return (NULL);             /* not found */
    }

/*******************************************************************************
*
* trcFindDest - find destination of call instruction
*
* RETURNS:
* Address to which call instruction (CALL) will branch or NULL if unknown.
*
* NOMANUAL
*/
LOCAL const INSTR * trcFindDest
    (
    const INSTR * callAdrs
    )
    {
    if (DSM (callAdrs, CALL_DIR, CALL_DIR_MASK))
        {
        /* PC-relative offset */

        const int displacement = *(int *)(callAdrs + 1);

        /* program counter */

        const INSTR * const pc = (INSTR *)((int) callAdrs + 1 + sizeof (int));

        return ((const INSTR *) ((int) pc + displacement));
        }
    
    return (NULL);    /* don't know destination */
    }

/*******************************************************************************
*
* trcCountArgs - find number of arguments to function
*
* This routine finds the number of arguments passed to the called function
* by examining the stack-pop at the return address.  Many compilers offer
* optimization that defeats this (e.g. by coalescing stack-pops), so a return
* value of 0, may mean "don't know".
*
* INTERNAL
* This routine relies on the "caller cleans the stack" convention to
* imply how many 4-byte quantities were pushed on the stack for a function
* call.  On IA-32, since the stack grows from high to low addresses, the
* calling routine cleans the stack by adding some number of bytes to ESP
* at the function return address.
*
* RETURNS: The number of arguments passed to a function.
*
* NOMANUAL
*/
LOCAL int trcCountArgs
    (
    const INSTR * returnAdrs    /* return address of function call */
    )
    {
    int           nbytes;       /* stores the argument count */


    /* if inst is a JMP, use the target of the JMP as the returnAdrs */

    const INSTR * const addr = trcFollowJmp (returnAdrs);


    if (DSM (addr,   ADDI08_0, ADDI08_0_MASK) &&
        DSM (addr+1, ADDI08_1, ADDI08_1_MASK))
        {
        nbytes = *(char *)(addr + 2);
        }
    else if (DSM (addr,   ADDI32_0, ADDI32_0_MASK) &&
             DSM (addr+1, ADDI32_1, ADDI32_1_MASK))
        {
        nbytes = *(int *)(addr + 2);
        }
    else if (DSM (addr,   LEAD08_0, LEAD08_0_MASK) &&
             DSM (addr+1, LEAD08_1, LEAD08_1_MASK) &&
             DSM (addr+2, LEAD08_2, LEAD08_2_MASK))
        {
        nbytes = *(char *)(addr + 3);
        }
    else if (DSM (addr,   LEAD32_0, LEAD32_0_MASK) &&
             DSM (addr+1, LEAD32_1, LEAD32_1_MASK) &&
             DSM (addr+2, LEAD08_2, LEAD08_2_MASK))
        {
        nbytes = *(int *)(addr + 3);
        }
    else
        {
        nbytes = 0;  /* no args, or unknown */
        }

    if (nbytes < 0)
        nbytes = 0 - nbytes;

    return (nbytes >> 2);
    }

/*******************************************************************************
*
* trcFindFuncStart - find the starting address of a function
*
* This routine finds the starting address of a function by one of several ways.
*
* If the given frame pointer points to a legitimate frame pointer, then the
* long word following the frame pointer pointed to by the frame pointer should
* be the return address of the function call. Then the instruction preceding
* the return address would be the function call, and the address can be gotten
* from there, provided that the CALL was to an pc-relative address. If it was,
* use that address as the function address.  Note that a routine that is
* called by other than a call-direct (e.g. indirectly) will not meet these
* requirements.
* 
* If the above check fails, we search backward from the given pc until a
* PUSH %EBP MOV %ESP %EBP instruction is found.  If the compiler is putting 
* PUSH %EBP MOV %ESP %EBP instructions as the first instruction of ALL
* subroutines, then this will reliably find the start of the routine.
* However, some compilers allow routines, especially "leaf" routines that
* don't call any other routines, to NOT have stack frames, which will cause
* this search to fail.
*
* In either of the above cases, the value is bounded by the nearest
* routine in the system symbol table, if there is one.  If neither method
* returns a legitimate value, then the value from the symbol table is use.
* Note that the routine may not be in the symbol table if it is LOCAL, etc.
*
* Note that the start of a routine that is not called by call-direct and
* doesn't start with a PUSH %EBP MOV %ESP %EBP and isn't in the symbol table,
* may not be possible to locate.
*
* RETURNS:
* The closest function entry-point address found at a memory location
* lower than that specified program counter address.
*
* NOMANUAL
*/
LOCAL const INSTR * trcFindFuncStart
    (
    const INSTR *  pc             /* address somewhere within the function */
    )
    {
    const INSTR *  minPc = NULL;  /* lower bound on program counter */
    int            val   = 0;     /* function address from symbol table */


    /* If there is a symbol table, try to find a symbol table value
     * that is <= (pc) as the lower bound for the function entry point.
     * If we can find a symbol table record for a function entry point
     * <= (pc), then that address may, or may not, be the entry point
     * for the function (pc) is in.
     */

    if (sysSymTbl != NULL)
        {
        char *     pName = NULL;  /* function name from symbol table */
        SYM_TYPE   type;          /* function type from symbol table */

        if (symByValueFind (sysSymTbl, (int) pc, &pName, &val, &type) == OK)
            {
            minPc = (const INSTR *)(val);
            }

        if (pName != NULL)
            {
            free (pName);  /* new API requires this */
            }
        }


    /* XXX NOTE (fix this) XXX
     * Search backward for a recognizable function prologue.  If there is
     * no symbol table built into the image, then (minPc) = 0.  In this
     * case, the search for function prologue could possibly decrement down
     * to address 0 in memory.
     */

    for (; pc >= minPc; --pc)
        {
        /* vxTaskEntry is the first code to be executed by every task
         * when it comes into existence. Since nothing can come before
         * vxTaskEntry, the recursion stops there.
         */

        if ((int) pc == (int) vxTaskEntry)
            return pc;


        if ((DSM (pc,     PUSH_EBP, PUSH_EBP_MASK) &&
             DSM (pc + 1, MOV_ESP0, MOV_ESP0_MASK) &&
             DSM (pc + 2, MOV_ESP1, MOV_ESP1_MASK)) ||

            /* this CANNOT distinguish between "func" and "func.aligned" */

            (DSM (pc,     PUSH_EBP,    PUSH_EBP_MASK) && 
             DSM (pc + 1, PUSH_ESI,    PUSH_ESI_MASK) &&
            (DSM (pc + 2, MOV_ESP_ESI, MOV_ESP_ESI_MASK) ||
             DSM (pc + 3, MOV_ESP_ESI, MOV_ESP_ESI_MASK))) ||

             DSM (pc,     ENTER,       ENTER_MASK)
           )
            {
            return (pc);  /* assume we've found the function entry point */
            }
        }

    return (minPc);       /* return the nearest function entry address */
    }

/*******************************************************************************
*
* trcFollowJmp - resolve any JMP instructions to final destination
*
* This routine returns a pointer to the next non-JMP instruction to be
* executed if the pc were at the specified <adrs>.  That is, if the instruction
* at <adrs> is not a JMP, then <adrs> is returned.  Otherwise, if the
* instruction at <adrs> is a JMP, then the destination of the JMP is
* computed, which then becomes the new <adrs> which is tested as before.
* Thus we will eventually return the address of the first non-JMP instruction
* to be executed.
*
* The need for this arises because compilers may put JMPs to instructions
* that we are interested in, instead of the instruction itself.  For example,
* optimizers may replace a stack pop with a JMP to a stack pop.  Or in very
* UNoptimized code, the first instruction of a subroutine may be a JMP to
* a PUSH %EBP MOV %ESP %EBP, instead of a PUSH %EBP MOV %ESP %EBP (compiler
* may omit routine "post-amble" at end of parsing the routine!).  We call
* this routine anytime we are looking for a specific kind of instruction,
* to help handle such cases.
*
* RETURNS: The address that a chain of branches points to.
*
* NOMANUAL
*/
LOCAL const INSTR * trcFollowJmp
    (
    const INSTR * addr
    )
    {
    int     displacement;        /* PC relative offset */
    int     length;              /* instruction length */

    /* while instruction is a JMP, get destination adrs */

    while (DSM (addr, JMPD08, JMPD08_MASK) ||
           DSM (addr, JMPD32, JMPD32_MASK))
        {
        if (DSM (addr, JMPD08, JMPD08_MASK))
            {
            displacement = *(char *)(addr + 1);
            length = 2;
            addr   = (INSTR *) (addr + length + displacement);
            }
        else if (DSM (addr, JMPD32, JMPD32_MASK))
            {
            displacement = *(int *)(addr + 1);
            length = 5;
            addr   = (INSTR *) (addr + length + displacement);
            }
        }

    return (addr);
    }
