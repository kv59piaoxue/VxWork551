/* dbgArchLib.c - SH-dependent debugger library */
  
/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02t,24oct01,zl   fixes for doc builds.
02s,15nov00,zl   fixed _dbgInstSizeGet().
02r,06sep00,zl   simplified CPU conditionals. Updated _archHelp_msg.
02q,03may00,rsh  fix instruction mask error and add some better documentation
02p,21apr00,rsh  implement cret
02o,19apr00,frf  Modified dbgHelp and dbgBrkDisplayHard functions
02n,13apr00,frf  Removed BRKENTRY and HWBP
02m,27mar00,frf  Add SH support for T2: dbg API updated
02l,11mar99,hk   changed TBH_ to TSH_BH_, simplified CPU conditionals.
                 merged _archHelp_msg for all SH CPUs.
02k,09mar99,hk   changed to include CPU specific header for UBC register defs.
02j,09mar99,hk   changed macro prefix BH_ to TBH_, to recover target shell tool.
02i,02mar99,hk   retrieved _archHelp_msg for non-SENS branch.
02h,09oct98,hk   code review: sorted CPU conditionals. fixed dBRCR for SH7750.
02g,07oct98,st   changed BBRA,BBRB default setting for SH7750 from
                 BBR_BREAK_AT_INST_OR_DATA_ACCESS to BBR_BREAK_AT_INST_FETCH.
02f,16jul98,st   added support for SH7750.
02g,15oct98,kab  removed obsolete archHelp_msg.
02f,08may97,jmc  added support for SH-DSP and SH3-DSP.
02e,23apr98,hk   fixed _dbgStepAdd() against slot instr exception by s().
02d,25apr97,hk   changed SH704X to SH7040.
02c,09feb97,hk   renamed excBpHandle/excBpHwHandle to dbgBpStub/dbgHwBpStub.
02b,08aug96,hk   code layout review. changed some #if (CPU==SH7xxx) controls.
02a,24jul96,ja   added support for SH7700.
01z,21may96,hk   workarounded for SH7700 build.
01y,10may96,hk   added support for SH7700 (first phase).
01x,19dec95,hk   added support for SH704X.
01w,08aug95,sa   fixed _dbgStepAdd().
01v,28jun95,hk   rewrote _dbgBranchDelay().
01u,27jun95,hk   deleted _dbgBranchDelay().
01t,16mar95,hk   added bypass to the delay slot checking in _dbgBranchDelay().
01s,28feb95,hk   changed _dbgVecInit() to conform ivSh.h 01e.
01r,22feb95,hk   added SH7000 support. moved printBbr(), printBrcr() to sysLib.
01q,21feb95,hk   obsoleted bh(,4), more refinements, wrote some docs.
01p,20feb95,hk   limited data break setup only for ch.B.
01o,17feb95,hk   added bh(,4) to allow parameter customization.
01n,15feb95,hk   debugging bh() problem.
01m,07feb95,hk   copyright year 1995. more rewriting.
01l,11jan95,hk   rewriting h/w breakpoint stuff.
01k,25dec94,hk   fixed _archHelp_msg, clean-up. added _dbgBranchDelay().
		 fixed _dbgInstSizeGet(), so() now functional.
01j,23dec94,hk   changing macro names.
01i,21dec94,hk   working on UBC code. adding sequence diagram.
01h,18dec94,hk   writing UBC support code.
01g,15dec94,hk   adding hardware breakpoint function prototypes from i960 01t.
01f,15dec94,hk   use SR_BIT_T.
01e,15dec94,hk   more fixing. Now s() command is functional.
01d,06dec94,hk   fixing.
01c,01dec94,hk   included archPortKit notes. wrote most routines.
01b,26nov94,hk   wrote _dbgArchInit body.
01a,09oct94,hk   written based on sparc 01i.
*/

/*
DESCRIPTION
This module provides the SH specific support functions for dbgLib.

NOMANUAL

INTERNAL
This architecture-dependent debugger library contains some simple routines
that support the architecture-independent dbgLib.c. The complex portions of
the debugger have been abstracted. 

*/

#include "vxWorks.h"
#include "private/dbgLibP.h"
#include "taskLib.h"
#include "fppLib.h"
#include "taskArchLib.h"
#include "intLib.h"
#include "regs.h"
#include "iv.h"
#include "cacheLib.h"
#include "ioLib.h"
#include "dsmLib.h"
#include "vxLib.h"
#include "stdio.h"
#include "usrLib.h"


IMPORT int    dsmNbytes ();
IMPORT int    dsmInst ();
IMPORT INST * dsmCheck ();


/* globals */

/* _archHelp_msg
 *
 * INTERNAL
 * Architecture-specific help routines for the debugger are summarized in this
 * string. The routine syntax is added to the end of the architecture-indepent
 * routines displayed by dbgHelp(). The register display routines comprise the
 * minimal set, and it should include any additional functionality that may be
 * useful for debugging. [Arch port kit]
 */
char * _archHelp_msg =
 "bh        addr[,access[,task[,count[,quiet]]]] Set hardware breakpoint\n"
 "                access values:\n"
 "                 - Break on any access         (              00)\n"
 "                 - Break on instruction fetch  (              01)\n"
 "                 - Break on data access        (              10)\n"
 "                 - Bus cycle any               (            00  )\n"
 "                 - Bus cycle read              (            01  )\n"
 "                 - Bus cycle write             (            10  )\n"
 "                 - Operand size any            (          00    )\n"
 "                 - Operand size byte           (          01    )\n"
 "                 - Operand size word           (          10    )\n"
 "                 - Operand size long           (          11    )\n"
 "                 - CPU access                  (        00      )\n"
 "                 - DMAC access                 (        01      )\n"
 "                 - CPU or DMAC access          (        10      )\n"
 "                 - IBUS                        (      00        )\n"
 "                 - XBUS                        (      01        )\n"
 "                 - YBUS                        (      10        )\n"
 "   *Not all access combinations are supported by all SuperH CPUs.\n"
 "    Use of an invalid combination is not always reported as an error.\n"
 "r0-r15,sr,gbr,vbr,mach,macl,pr,pc [task]       Get a register of a task\n";

/* forward declarations */



/*******************************************************************************
*
* _dbgArchInit - architecture dependent initialization routine
*
* This routine initialize global function pointers that are architecture 
* specific.
*
* NOMANUAL
*
* INTERNAL
* This function is identical for all architectures. It is used to link the
* architecture-specific routines in this file to the architecture-independent
* debugger support. The generic function call attaches the new processor's
* debugger library support. [Arch port kit]
*
* NOTE
* This routine is called from dbgInit() only.
*/

void _dbgArchInit (void)
    {
    _dbgDsmInstRtn   = (FUNCPTR)  dsmInst;
    }

/*******************************************************************************
*
* _dbgInstSizeGet - set up breakpoint instruction
*
* RETURNS: size of the instruction at specified location.
*
* NOMANUAL
*
* INTERNAL
* This routine currently returns the number of 16-bit words needed to implement
* the breakpoint instruction at the specified address. It returns 16-bit words,
* instead of bytes, for compatibility with the original 68K debugger design;
* this does not make much sense for other architectures. In some future release
* the return value will be more architecture-independent, in other words, in
* bytes. [Arch port kit]
*
* NOTE
* This routine is called from so() only.  Any SH instruction is 16-bit length,
* but we treat a delayed branch instruction as 32-bit.  Otherwise we may insert
* the trapa instruction in a delay slot and gets an illegal slot exception.
*/

int _dbgInstSizeGet
    (
    INSTR * pBrkInst		/* pointer to hold breakpoint instruction */
    )
    {
    return (dsmNbytes (pBrkInst) / sizeof (INSTR));
    }

/*******************************************************************************
*
* _dbgRetAdrsGet - get return address for current routine
*
* RETURNS: return address for current routine.
*
* NOMANUAL
*
* INTERNAL
* A pointer to a REG_SET is passed to this routine. It returns the adress of the
* instruction in the calling routine that will be executed when this function
* returns. Depending on the processor's function call mechanism and pipelining,
* the calling routine's program counter may have to be adjusted to create the
* return address. [Arch port kit]
*
* INTERNAL
* While executing a leaf procedure, the pr register always holds the correct
* return address.  In case of a non-leaf procedure, this is not always true.
* After returning from a subroutine, pr keeps holding a return address of the
* subroutine.  The correct return address of non-leaf procedure is on stack.
*
* ex. proc: <<< pr valid >>>
*	     :
* 4f22      sts.l  pr, @-sp
*	     :
*	    mov.l  &subr,r0
*	    jsr    @r0              
*	    nop
*	     :
*	    <<< pr invalid >>>  ---> pr contains the return adrs of "subr".
*	     :
* 4f26      lds.l  @sp+,pr    ---> return adrs of "proc" is popped at here.
*	     :
* 000b      rts
*	    nop
*
* NOTE
* This routine currently only detects #imm adjustment of the stack. Consequently,
* it will not find the correct frame pointer adjustment in functions which have
* greater than 127 (7 #imm bits) bytes of parameters and local data. A search
* through usrConfig.o indicates such a case only occurs once. For Beta, this
* should be sufficient.
*
*/

INSTR * _dbgRetAdrsGet
    (
    REG_SET * pRegSet
    )
    {

    INSTR * scanpc;        /* instruction scan pc pointer for forward scan */
    UINT16 immed;
    INT32 offset;
    void * fp;

    /*
    * scan instructions forward. If we find a "sts.l pr,@-sp" or a "jsr @rm"
    * then the return address in already in the link register.  If we
    * find a "lds.l @sp+,pr" then the return address is saved on the
    * stack. We need to search back to find the offset. 
    * If we find "rts" without encountering the above instructions, it is
    * a leaf function and the return address is in register "pr".
    */
 
 
    for (scanpc = pRegSet->pc; TRUE; scanpc++)
        {
        /* 
         * if inst is "sts.l pr,@-sp" we are in the prolog.
         * if inst is "rts" we are in a leaf proceedure. Note that
         * this assumes you cannot break in the epilog, which would be
         * true for c code, but not necessarily for assembly.
         * Either way, the TCB's pr value is valid. 
         */

        if ((INST_CMP(scanpc, INST_PUSH_PR, 0xffff)) ||
            (INST_CMP(scanpc, INST_RTS, 0xffff)))
            {
            return (pRegSet->pr);
            }

        /*
         * we are somewhere in the function body of a non-leaf
         * routine and the pr may have been modified by a previous
         * function call. The correct pr is on the stack and must
         * be retrieved. Break from here and enter the search backwards
         * loop.
         */

        else if (INST_CMP(scanpc, INST_POP_PR, 0xffff))
            {
            break;
            }
        }

    /* if we arrive here, we are inside the function body and the current
     * tcb's pr value may be invalid (i.e. we may have called a subroutine
     * within the current function body which would have modified pr). 
     * Consequently, we'll need to search backwards to find 1) the current
     * frame pointer (stored in r14) and 2) the offset from the current
     * frame pointer back to the pr location on the stack. The sh compiler
     * sets the frame pointer to the stack location of the last parameter
     * or local allocation so that we have a variable offset back to the
     * pr location.
     */

    scanpc = pRegSet->pc;

    /* search back until we have the SET_FP instruction (mov.l sp,r14) */

    while (!(INST_CMP(scanpc, INST_SET_FP, 0xffff)))
        {
        scanpc--;
        }

    /* search back until the PUSH_PR instruction looking for a frame
     * adjustment instruction that modifies r15 before storing to r14.
     * (add #imm,sp). The #imm argument 
     */

    while (!(INST_CMP(scanpc, INST_PUSH_PR, 0xffff)))
        {
        if (INST_CMP(scanpc, INST_ADD_IMM_SP, MASK_ADD_IMM_SP)) 
            {
            immed = *(scanpc) & 0x00ff;

            /* "add #imm,sp" instruction sign extends #imm. Since this instruction
             * descremented the sp, #imm will be a negative value. sign extend
             * it to get it's proper negative value. And then reverse the sign.
             */

            offset = (0xffffff00 | (long) immed);   /* negative offset */
            offset = 0 - (offset);

            /* add offset to frame pointer */ 

            (ULONG *) fp = pRegSet->fpReg;

            (char *) fp += offset;

            /* retrieve and return pr */

            return ((INSTR *) *((ULONG *) fp));
            }
        scanpc--;
        }

    /* if we get here, then the offset is zero, so just return the value
     * held in r14 (the frame pointer).
     */

    return ((INSTR *) *((ULONG *) pRegSet->fpReg));

#if FALSE
    return ((INSTR *) ERROR);
#endif
    }

/*******************************************************************************
*
* _dbgFuncCallCheck - check next instruction
*
* This routine checks to see if the next instruction is a JSR or BSR.
* If it is, it returns TRUE, otherwise, returns FALSE.
*
* RETURNS: TRUE if next instruction is JSR or BSR, or FALSE otherwise.
*
* NOMANUAL
*
* INTERNAL
* This routine checks the instruction pointed to by the input argument to
* determine if it is an instruction that is used to implement a function call.
* If so, the function returns TRUE, otherwise the return value is FALSE.
* Note the use of the INST_CMP macro defined in dbgLib.h. [Arch port kit]
*
* NOTE
* This routine is called from so() only.
*/

BOOL _dbgFuncCallCheck
    (
    INSTR * addr
    )
    {
    /* SH JSR and BSR instructions:
     * 
     * JSR	@Rn		0100nnnn00001011	itAtOneReg  - 2/3
     * BSRF	Rn		0000nnnn00000011	itBraDispRn - 2/2
     * BSR	disp		1011dddddddddddd	itBraDisp12 - 2/2
     */
    return (INST_CMP (addr, 0x400b, 0xf0ff)	/* JSR  */
	||  INST_CMP (addr, 0x0003, 0xf0ff)	/* BSRF */
	||  INST_CMP (addr, 0xb000, 0xf000)	/* BSR  */ );
    }

/*******************************************************************************
*
* _dbgInfoPCGet - get pc from stack
*
* RETURNS: value of pc saved on stack
*
* NOMANUAL
*
* INTERNAL
* This routine returns a pointer to the instruction addressed by the program
* counter. The input argument is a pointer to the breakpoint stack frame. The
* return value is the program counter element of that structure, whose type
* should be an INSTR*. [Arch port kit]
*
* NOTE
* This routine is called from dbgBreakpoint() only.
*/

INSTR * _dbgInfoPCGet
    (
    BREAK_ESF * pInfo
    )
    {
    return (pInfo->pc);
    }

/*******************************************************************************
*
* _dbgTaskPCSet - set task's pc
*
* NOMANUAL
*
* INTERNAL
* The task identification and the program counter(s) are passed to this
* function which will set new program counter(s) for the specified task.
* A local copy of REG_SET is filled by the call to taskRegsGet(), the program
* counter(s) set, and then copied back to the task's TCB by taskRegsSet().
* This routine is similar for all architectures. [Arch port kit]
*
* NOTE
* This routine is called from c() and s().
*/

void _dbgTaskPCSet
    (
    int     tid,
    INSTR * pc,		/* task's pc                        */
    INSTR * npc		/* task's npc (not supported by SH) */
    )
    {
    REG_SET regSet;

    if (taskRegsGet (tid, &regSet) != OK)
	return;

    regSet.pc = pc;

    taskRegsSet (tid, &regSet);
    }

/*******************************************************************************
*
* _dbgTaskPCGet - get task's pc
*
* RETURNS: specified task's program counter
*
* NOMANUAL
*
* INTERNAL
* This routine returns a pointer to the instruction addressed by the program
* counter. The input argument is the task identifier used with taskRegsGet().
* The return value is the program counter element of that structure, whose
* type should be an INSTR*. [Arch port kit]
*
* NOTE
* This routine is called from c(), so(), dbgTlSnglStep(), and dbgTaskSwitch().
*/

INSTR * _dbgTaskPCGet
    (
    int     tid
    )
    {
    REG_SET regSet;

    (void) taskRegsGet (tid, &regSet);

    return ((INSTR *) regSet.pc);
    }



/*******************************************************************************
*
* getOneReg - return the contents of one register
*
* Given a task's ID, this routine returns the contents of the register
* specified by the register code.  This routine is used by r0, sr, etc.
* The register codes are defined in regsSh.h.
*
* NOMANUAL
*
* RETURNS: register contents, or ERROR.
*
* INTERNAL
* This routine gets the contents of a specific register in the REG_SET based on
* the task identifier and the register index. A call is made to taskIdFigure(),
* and the return value checked for an ERROR. taskIdDefault() and taskRegsGer()
* are called to fill a local copy of REG_SET. The index is used to return the
* contents of the register. [Arch port kit]
*
*/

LOCAL int getOneReg
    (
    int     taskId,			/* task ID, 0 means default task */
    int     regCode			/* code for specifying register */
    )
    {
    REG_SET regSet;			/* get task's regs into here */

    taskId = taskIdFigure (taskId);	/* translate super name to ID */

    if (taskId == ERROR)		/* couldn't figure out super name */
	return (ERROR);
    taskId = taskIdDefault (taskId);	/* set the default ID */

    if (taskRegsGet (taskId, &regSet) != OK)
	return (ERROR);

    return (*(int *)((int)&regSet + regCode));
    }

/*******************************************************************************
*
* r0 - return the contents of general register r0 (also r1-r15) (SH)
*
* This command extracts the contents of register r0 from the TCB of a specified
* task.  If <taskId> is omitted or zero, the last task referenced is assumed.
*
* Similar routines are provided for all general registers (r1 - r15):
* r1() - r15().
*
* RETURNS: The contents of register r0 (or the requested register).
*
* SEE ALSO:
* .pG "Debugging"
*
* INTERNAL
* Although this routine is hereby marked NOMANUAL, it actually gets
* published, but from arch/doc/dbgArchLib.c.
*
* INTERNAL
* Each control and general-purpose register should have a routine to display
* its contents in the REG_SET structure in the TCB. The task identifier and
* a register index is passed to the hidden (local) function getOneReg() which
* returns the contents. [Arch port kit]
*/

int r0
    (
    int taskId		/* task ID, 0 means default task */
    )
    {
    return (getOneReg (taskId, REG_SET_R0  ));
    }

int r1  (int taskId) { return (getOneReg (taskId, REG_SET_R1  )); }
int r2  (int taskId) { return (getOneReg (taskId, REG_SET_R2  )); }
int r3  (int taskId) { return (getOneReg (taskId, REG_SET_R3  )); }
int r4  (int taskId) { return (getOneReg (taskId, REG_SET_R4  )); }
int r5  (int taskId) { return (getOneReg (taskId, REG_SET_R5  )); }
int r6  (int taskId) { return (getOneReg (taskId, REG_SET_R6  )); }
int r7  (int taskId) { return (getOneReg (taskId, REG_SET_R7  )); }
int r8  (int taskId) { return (getOneReg (taskId, REG_SET_R8  )); }
int r9  (int taskId) { return (getOneReg (taskId, REG_SET_R9  )); }
int r10 (int taskId) { return (getOneReg (taskId, REG_SET_R10 )); }
int r11 (int taskId) { return (getOneReg (taskId, REG_SET_R11 )); }
int r12 (int taskId) { return (getOneReg (taskId, REG_SET_R12 )); }
int r13 (int taskId) { return (getOneReg (taskId, REG_SET_R13 )); }
int r14 (int taskId) { return (getOneReg (taskId, REG_SET_R14 )); }
int r15 (int taskId) { return (getOneReg (taskId, REG_SET_R15 )); }

/*******************************************************************************
*
* sr - return the contents of control register sr (also gbr, vbr) (SH)
*
* This command extracts the contents of register sr from the TCB of a specified
* task.  If <taskId> is omitted or zero, the last task referenced is assumed.
*
* Similar routines are provided for all control registers (gbr, vbr):
* gbr(), vbr().
*
* RETURNS: The contents of register sr (or the requested control register).
*
* SEE ALSO:
* .pG "Debugging"
*
* INTERNAL
* Although this routine is hereby marked NOMANUAL, it actually gets
* published, but from arch/doc/dbgArchLib.c.
*
* INTERNAL
* Each control and general-purpose register should have a routine to display
* its contents in the REG_SET structure in the TCB. The task identifier and
* a register index is passed to the hidden (local) function getOneReg() which
* returns the contents. [Arch port kit]
*/

int sr
    (
    int taskId		/* task ID, 0 means default task */
    )
    {
    return (getOneReg (taskId, REG_SET_SR  ));
    }

int gbr (int taskId) { return (getOneReg (taskId, REG_SET_GBR )); }
int vbr (int taskId) { return (getOneReg (taskId, REG_SET_VBR )); }

/*******************************************************************************
*
* mach - return the contents of system register mach (also macl, pr) (SH)
*
* This command extracts the contents of register mach from the TCB of
* a specified task.  If <taskId> is omitted or zero, the last task referenced
* is assumed.
*
* Similar routines are provided for other system registers (macl, pr):
* macl(), pr().  Note that pc() is provided by usrLib.c.
*
* RETURNS: The contents of register mach (or the requested system register).
*
* SEE ALSO:
* .pG "Debugging"
*
* INTERNAL
* Although this routine is hereby marked NOMANUAL, it actually gets
* published, but from arch/doc/dbgArchLib.c.
*
* INTERNAL
* Each control and general-purpose register should have a routine to display
* its contents in the REG_SET structure in the TCB. The task identifier and
* a register index is passed to the hidden (local) function getOneReg() which
* returns the contents. [Arch port kit]
*/

int mach
    (
    int taskId		/* task ID, 0 means default task */
    )
    {
    return (getOneReg (taskId, REG_SET_MACH));
    }

int macl(int taskId) { return (getOneReg (taskId, REG_SET_MACL)); }
int pr  (int taskId) { return (getOneReg (taskId, REG_SET_PR  )); }

#if	FALSE
int pc  (int taskId) { return (getOneReg (taskId, REG_SET_PC  )); }
#endif	/* FALSE, usrLib provides this. */


#if	DBG_HARDWARE_BP  	/* TO THE END OF THIS FILE */
/******************************************************************************
*
* _dbgBrkDisplayHard - display a hardware breakpoint
*
* NOMANUAL
*
* NOTE
* This routine is called from dbgBrkDisplay() only.
*/

void _dbgBrkDisplayHard
    (
    BRKPT *	pBp            /* breakpoint table entry */
    )
    {
    int type;

    if ((pBp->bp_flags & BRK_HARDWARE) == 0) 
        return;

    type = pBp->bp_flags & BRK_HARDMASK;

    printf ("\n            UBC");

    switch (type & BH_BREAK_MASK)
	{
	/* HW breakpoint on bus... */
	case BH_BREAK_INSN:  printf(" INST");	break;	/* istruction access */
	case BH_BREAK_DATA:  printf(" DATA");	break;	/* data access */
	default:             printf(" I/D");	break;	/* any */
	}
    switch (type & BH_CYCLE_MASK)
	{
        /* HW breakpoint on bus cycle... */
	case BH_CYCLE_READ:  printf(" READ");	break;	/* read  */
	case BH_CYCLE_WRITE: printf(" WRITE");	break;	/* write */
	default:             printf(" R/W");	break;  /* any */
	}
    switch (type & BH_SIZE_MASK)
	{
	/* HW breakpoint on operand size */
	case BH_8:           printf(" BYTE");	break;	/*  8 bit */
	case BH_16:          printf(" WORD");	break;	/* 16 bit */
	case BH_32:          printf(" LONG");	break;	/* 32 bit */
	}
    switch (type & BH_CPU_MASK)
	{
        /* HW breakpoint on bus cycle... */
	case BH_CPU:	     printf(" CPU");	break;	/* CPU */
	case BH_DMAC:	     printf(" DMA");	break;	/* DMA ctrl */
	case BH_DMAC_CPU:    printf(" DMA/CPU");break;	/* DMA/CPU */
	}
    switch (type & BH_BUS_MASK)
	{
        /* HW breakpoint on bus cycle... */
	case BH_XBUS:        printf(" XBUS");	break;	/* XBUS, DSP only */
	case BH_YBUS:        printf(" YBUS");	break;	/* YBUS, DSP only */
	}
    }
#endif	/* DBG_HARDWARE_BP */
