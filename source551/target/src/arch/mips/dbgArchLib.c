/* dbgArchLib.c - MIPS architecture dependent debugger library */
  
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
01r,16jul01,ros  add CofE comment
01q,20dec00,pes  Update for MIPS32/MIPS64 target combinations.
01p,22sep99,myz  added CW4000_16 support.
01o,29jul99,alp  added CW4000 and CW4010 support.
01n,18jan99,elg  Authorize breakpoints on branch delay slot (SPR 24356).
01m,08jan98,dbt  modified for new breakpoint scheme
01l,14oct96,kkk  added R4650 support.
01k,10feb95,jdi  doc tweaks.
01j,27jan95,rhp  doc cleanup.
01i,19oct93,cd   added R4000 support
01h,29sep93,caf  undid fix of SPR #2359.
01g,07jul93,yao  fixed to preserve parity error bit of status
		 register (SPR #2359).  changed copyright notice.
01f,01oct92,ajm  added dynamically bound handlers, general cleanup
01e,23aug92,jcf  made filename consistant.
01d,22jul92,yao  fixed bug when adding a temporary breakpoint at a branch 
		 instruction in _dbgStepAdd().
01c,06jul92,yao  removed dbgCacheClear().  made user uncallable globals
		 started with '_'.
01b,04jul92,jcf  scalable/ANSI/cleanup effort.
01a,16jun92,yao  written based on mips dbgLib.c ver01k.
*/

/*
DESCRIPTION
NOMANUAL
*/

#include "vxWorks.h"
#include "private/dbgLibP.h"
#include "private/taskLibP.h"
#include "taskArchLib.h"
#include "intLib.h"
#include "excLib.h"
#include "regs.h"
#include "iv.h"
#include "cacheLib.h"
#include "ioLib.h"
#include "dsmLib.h"
#include "vxLib.h"
#include "stdio.h"
#include "wdb/wdbDbgLib.h"
#include "dbgLib.h"

/* externals */

IMPORT int 	dsmInst (FAST long * binInst, int address, FUNCPTR prtAddress);
IMPORT FUNCPTR	wdbDbgArchHandler[8];
IMPORT int      dsmNbytes (ULONG);
IMPORT BOOL mips16Instructions(ULONG);

/* globals */

char * _archHelp_msg = 		/* help message */
#if     (DBG_HARDWARE_BP)
    "bh addr[,access[,task[,count[,quiet]]]] Set hardware breakpoint\n"
    "        access :      1 - write            2 - read\n"
    "                      3 - read/write"
    "        For R4650 processors:\n"
    "        access :      0 - instruction      1 - write\n"
    "                      2 - read             3 - read/write"
#endif	/* (DBG_HARDWARE_BP) */
    "\n";

/*******************************************************************************
*
* _dbgArchInit - architecture dependent initialization routine
*
* This routine initialize global function pointers that are specific for 
* MIPS architecture.
*
* RETURNS:N/A
* 
* NOMANUAL
*/

void _dbgArchInit (void)

    {
    _dbgDsmInstRtn = (FUNCPTR) dsmInst;
    }

/*******************************************************************************
*
* _dbgInstSizeGet - set up breakpoint instruction
*
* RETURNS: size of the instruction at specified location.
* 
* NOMANUAL
*/

int _dbgInstSizeGet
    (
    INSTR * brkInst		/* pointer to hold breakpoint instruction */
    )
    {
    return (2);
    }

/*******************************************************************************
*
* _dbgRetAdrsGet - get return address for current routine
*
* RETURNS: return address for current routine.
* 
* NOMANUAL
*/

INSTR * _dbgRetAdrsGet
    (
    REG_SET * pRegSet		/* pointer to register set */
    )
    {
#if	FALSE
    INSTR * scanpc;		/* instruction scan pc pointer */

    /*
    * scan instructions forward. If we find a "sw ra,x(sp)" or a "jr ra"
    * then the return address in already in register "ra".  If we find
    * a "lw ra,x(sp)" then the return address is saved in offset "x"
    * on the stack. If the instruction space is corrupted, could get
    * a bus error eventually or could find a return address for a
    * neighboring subprogram.
    */

    for (scanpc = pRegSet->pc; TRUE; scanpc++)	
	{
	/* match "sw ra,x(sp)" or "jr ra" means return address in ra */
	if (INST_CMP(scanpc,(SW_INSTR|RA<<RT_POS|SP<<BASE_POS),
		(GENERAL_OPCODE_MASK|RT_MASK|BASE_MASK)) ||
	    INST_CMP(scanpc,(SPECIAL|JR_INSTR|RA<<RS_POS),
		(GENERAL_OPCODE_MASK|SPECIAL_MASK|RS_MASK)))
	    {
	    return ((INSTR *) pRegSet->raReg);
	    }

	/* match "lw ra, x(sp)" means return address is on the stack */
	if (INST_CMP(scanpc,(LW_INSTR|RA<<RT_POS|SP<<BASE_POS),
		(GENERAL_OPCODE_MASK|RT_MASK|BASE_MASK)))
	    {
	    /* Note that the "C" compiler treats "short" as the lower
	     * 16 bits of the word and automatically performs the sign
	     * extend when the "short" is converted to a "long"
	     */

	    return ((INSTR *)(*(INSTR **) (pRegSet->spReg + (short) *scanpc)));
	    }
	}

    return (NULL);
#endif	/* FALSE */
    return ((INSTR *) ERROR);
    }

/*******************************************************************************
*
* _dbgFuncCallCheck - check next instruction
*
* This routine checks to see if the next instruction is a JAL or BAL.
* If it is, it returns TRUE, otherwise, returns FALSE.
*
* RETURNS: TRUE if next instruction is JAL or BAL, or FALSE otherwise.
* 
* NOMANUAL
*/

BOOL _dbgFuncCallCheck
    (
    INSTR * addr		/* pointer to instruction */
    )
    {
    if (mips16Instructions((ULONG)addr))
	{
	/* mips16 jal, jalr instructions */

        if ( (M16_INSTR_OPCODE(*(UINT16 *)addr) == M16_JALNX_INSTR)||
	     (((*(UINT16 *)addr) & 0xf81f) == 0xe800) )  /* j(al)r */
	     return (TRUE);
        else
	     return(FALSE);
        }

    return (INST_CMP (addr, JAL_INSTR, GENERAL_OPCODE_MASK) || 
#ifdef _WRS_MIPS16
#define JALX_INSTR  0x74000000
	    INST_CMP (addr, JALX_INSTR, GENERAL_OPCODE_MASK) ||
#endif
	    INST_CMP (addr, (SPECIAL|JALR_INSTR), 
		(GENERAL_OPCODE_MASK | SPECIAL_MASK)) ||
	    INST_CMP (addr, (BCOND|BLTZAL_INSTR), 
		(GENERAL_OPCODE_MASK | BCOND_MASK)) ||
	    INST_CMP (addr, (BCOND | BGEZAL_INSTR), 
		(GENERAL_OPCODE_MASK | BCOND_MASK)) ||
	    INST_CMP (addr, (BCOND | BLTZALL_INSTR), 
		(GENERAL_OPCODE_MASK | BCOND_MASK)) ||
	    INST_CMP (addr, (BCOND | BGEZALL_INSTR), 
		(GENERAL_OPCODE_MASK | BCOND_MASK))
	    );
    }

/*******************************************************************************
*
* _dbgTaskPCGet - get task's pc
*
* RETURNS:task's program counter
* 
* NOMANUAL
*/

INSTR * _dbgTaskPCGet
    (
    int tid	/* task's id */
    )
    {
    REG_SET	regSet;

    (void) taskRegsGet (tid, &regSet);

#ifdef _WRS_MIPS16

    /* mask off possible mips16 function indicator */

    return((INSTR *)((int)(regSet.pc) & ~0x1));
#else
    return ((INSTR *) regSet.pc);
#endif
    }

/*******************************************************************************
*
* _dbgTaskPCSet - set task's pc
*
* RETURNS:N/A
*
* NOMANUAL
*/

void _dbgTaskPCSet
    (
    int		tid,	/* task id */
    INSTR *	pc,	/* task's pc */
    INSTR *	npc	/* task's npc */
    )
    {
    REG_SET regSet;	/* task's register set */

    if (taskRegsGet (tid, &regSet) != OK)
	return;

    regSet.pc = pc;

    taskRegsSet (tid, &regSet);
    }

/*******************************************************************************
*
* dbgBpTypeBind - bind a breakpoint handler to a breakpoint type (MIPS R3000, R4000, R4650)
* 
* Dynamically bind a breakpoint handler to breakpoints of type 0 - 7.
* By default only breakpoints of type zero are handled with the
* vxWorks breakpoint handler (see dbgLib).  Other types may be used for
* Ada stack overflow or other such functions.  The installed handler
* must take the same parameters as excExcHandle() (see excLib).
*
* RETURNS:
* OK, or
* ERROR if <bpType> is out of bounds.
* 
* SEE ALSO
* dbgLib, excLib
*/

STATUS dbgBpTypeBind
    (
    int		bpType,		/* breakpoint type */
    FUNCPTR	routine		/* function to bind */
    )
    {
    if ((bpType > 7) || (bpType < 0))
	{
	return (ERROR);
	}
    else
	{
	wdbDbgArchHandler[bpType] = routine;
	return (OK);
	}
    }

#if	(DBG_HARDWARE_BP)
/******************************************************************************
*
* _dbgBrkDisplayHard - print hardware breakpoint
*
* This routine print hardware breakpoint.
*
* NOMANUAL
*/

void _dbgBrkDisplayHard
    (
    BRKPT *	pBp		/* breakpoint table entry */
    )
    {
    int type;

    if ((pBp->bp_flags & BRK_HARDWARE) == 0)
	return;

    type = pBp->bp_flags & BRK_HARDMASK;

    printf (" (hard-");

    switch (type)
	{
	case BRK_INST:
	    printf ("inst.)");
	    break;

	case BRK_READ:
	    printf ("data read)");
	    break;

	case BRK_WRITE:
	    printf ("data write)");
	    break;

	case BRK_RW:
	    printf ("data r/w)");
	    break;

	default:
	    printf ("unknown)");
	    break;
	}
    }
#endif  /* DBG_HARDWARE_BP */
