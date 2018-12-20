/* dbgArchLib.c - PowerPC dependent debuger library */
  
/* Copyright 1984-1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01u,19aug03,dtr  Adding PPC85XX info.
01t,16may02,pch  add cross-ref for maintainability
01s,14mar02,pch  SPR 74270:  make 440 bh types consistent with 5xx/604/860
01r,16aug01,pch  Add PPC440 support
01q,31oct00,s_m  PPC405 hw breakpoint support.
01p,25oct00,s_m  renamed PPC405 cpu types
01o,13jun2k,alp  Added PPC405 support.
01n,19apr99,zl   added support for PPC509 and PPC555
01m,09nov98,elg  added hardware breakpoints for PPC403
01l,13oct98,elg  added hardware breakpoints for PPC603 and PPC604
01k,27jul98,elg  added hardware breakpoints
01j,09jan98,dbt  modified for new breakpoint scheme
		 Removed all refs to TRACE_ESF and all but one to BREAK_ESF.
01i,05feb97,tpr  added PPC860 support (SPR 7881).
		 Removed PPC601.
01h,30jul96,tam  fixed _dbgTaskBPModeClear for PPC403: we do not clear 
		 MSR register DE (Debug Enable) bit anylonger.
01g,04mar96,ms   reworked _dbgRegsAdjust, removed reference to excStub.
01f,14feb96,tpr  added PPC604.
01e,22may95,yao  change reference to excTraceStub() to dbgTraceStub().
01d,07feb95,yao  cleanup.
01c,30jan95,yao  added PPC403 support.
01b,05dec94,caf  fixed cast of _dbgInfoPCGet() return value,
		 added _GREEN_TOOL support.
01a,07nov94,yao  written.
*/

/*
DESCRIPTION
*/

#include "vxWorks.h"
#include "private/dbgLibP.h"
#include "private/taskLibP.h"
#include "fppLib.h"
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
#include "string.h"
#include "logLib.h"

/* externals */

IMPORT int	dsmInst (FAST long * binInst, int address, FUNCPTR prtAddress);
IMPORT STATUS	taskMsrSet (int tid, _RType msr);

/* globals */

/*
 * _archHelp_msg should be coordinated with archHelpMsg
 * in host/resource/tcl/dbgPpcLib.tcl, and with the
 * documentation in host/src/tgtsvr/server/wtx.pcl
 */

char * _archHelp_msg =		/* help message */
#if 	DBG_HARDWARE_BP
    "bh        addr[,access[,task[,count[,quiet]]]] Set hardware breakpoint\n"
    "\t\taccess:\t0 - instruction"
# if (CPU==PPC509)||(CPU==PPC555)||(CPU==PPC604)||(CPU==PPC860)||(CPU==PPC440)||(CPU==PPC85XX)
    "\t\t1 - read/write data\n"
    "\t\t\t2 - read data\t\t3 - write data"
# endif	/* (CPU==PPC5xx) || (CPU==PPC604) || (CPU==PPC860) || CPU==PPC440 */
# if	(CPU == PPC403)
    "\t\t1 - write byte\n"
    "\t\t\t2 - read byte\t\t3 - read/write byte\n"
    "\t\t\t5 - write half-word\t\t6 - read half-word\n"
    "\t\t\t7 - read/write half-word\t\t9 - write word\n"
    "\t\t\t10 - read word\t\t11 - read/write word\n"
    "\t\t\t13 - write quad-word\t\t14 - read quad-word\n"
    "\t\t\t15 - read/write quad-word"
# endif	/* (CPU == PPC403) */
# if ((CPU == PPC405) || (CPU == PPC405F))
    "\t\t1 - write byte\n"
    "\t\t\t2 - read byte\t\t3 - read/write byte\n"
    "\t\t\t4 - write half-word\t\t5 - read half-word\n"
    "\t\t\t6 - read/write half-word\t\t7 - write word\n"
    "\t\t\t8 - read word\t\t9 - read/write word\n"
    "\t\t\t10 - write cache-line\t\t11 - read cache-line\n"
    "\t\t\t12 - read/write cache-line"
# endif  /* (CPU == PPC405) || (CPU == PPC405F) */
#endif	/* DBG_HARDWARE_BP */
    "\n";

/*******************************************************************************
*
* _dbgArchInit - architecture dependent initialization routine
*
* This routine initialize global function pointers that are specific for 
* MIPS architecture.
*
* RETURNS:N/A
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
*/

int _dbgInstSizeGet
    (
    INSTR * brkInst		/* pointer to hold breakpoint instruction */
    )
    {
    return (sizeof(INSTR)/sizeof(INSTR));
    }

/*******************************************************************************
*
* _dbgRetAdrsGet - get return address for current routine
*
* RETURNS: return address for current routine.
*/

INSTR * _dbgRetAdrsGet
    (
    REG_SET * pRegSet		/* pointer to register set */
    )
    {
    FAST INSTR * scanpc;	/* instruction scan pc pointer */
    FAST INSTR * pMtlr = NULL;	/* pointer to instruction mtspr lr, rx */
    _RType sp = pRegSet->spReg;	/* stack pointer */
    INT16 offset;
    int regNum;

    /*
    * scan instructions forward. If we find a "mfspr rx,lr" or a "bclr"
    * then the return address in already in the link register.  If we 
    * find a "mtspr lr, rx" then the return address is saved on the 
    * stack. We need to search back to find the offset.  If the instruction 
    * space is corrupted, could get a bus error eventually or could find a 
    * return address for a neighboring subprogram.
    */

    for (scanpc = (INSTR *) pRegSet->pc; TRUE; scanpc++)	
        {
        /* match "mfspr rx,lr" means return address is in lr */
        if (INST_CMP(scanpc, INST_MFLR, INST_MTSPR_MASK))
            {
	    return ((INSTR *) pRegSet->lr);
            }
        else if (INST_CMP(scanpc, INST_MTLR, INST_MTSPR_MASK))
	    pMtlr = scanpc;
	else if (INST_CMP(scanpc, INST_ADDI_SP, INST_HIGH_MASK) ||
		 INST_CMP(scanpc, INST_STWU_SP,INST_HIGH_MASK))
	    {
	    offset = *scanpc & 0xffff;	/* sign extend */
	    sp += offset;
	    }
	else if (INST_CMP(scanpc, INST_BCLR, INST_BCLR_MASK))
	    if (pMtlr == NULL)
		return ((INSTR *) pRegSet->lr);
	    else
		{
		regNum = _IFIELD_RS((*pMtlr));
		for (; TRUE; pMtlr --)
		    if (INST_CMP(pMtlr, (INST_LWZ_SP | regNum << 21), 
				 INST_HIGH_MASK) ||
			INST_CMP(pMtlr, (INST_LWZU_SP | regNum << 21), 
				 INST_HIGH_MASK))
			{
			offset = (*pMtlr) & 0xffff;
			return ((INSTR *) *(INSTR *)(sp + offset));
			}
		}
        }

    return (NULL);
    }

/*******************************************************************************
*
* _dbgFuncCallCheck - check next instruction
*
* This routine checks to see if the next instruction is a BL or BCL.
* If it is, it returns TRUE, otherwise, returns FALSE.
*
* RETURNS: TRUE if next instruction is JAL or BSR, or FALSE otherwise.
*/

BOOL _dbgFuncCallCheck
    (
    INSTR * addr		/* pointer to instruction */
    )
    {
    return (INST_CMP (addr, INST_BL, INST_BL_MASK) || 
	    INST_CMP (addr, INST_BCL, INST_BL_MASK));
    }

/*******************************************************************************
*
* _dbgInfoPCGet - get pc from exception frame
*
* RETURNS: value of pc saved on stack
*/

INSTR * _dbgInfoPCGet
    (
    BREAK_ESF * pInfo		/* pointer to info saved on stack */
    )
    {
    return ((INSTR *) pInfo->regSet.pc);
    }

/*******************************************************************************
*
* _dbgTaskPCSet - set task's pc
*
* RETURNS:N/A
*/

void _dbgTaskPCSet
    (
    int     tid,	/* task id */
    INSTR * pc,		/* task's pc */
    INSTR * npc		/* task's npc */
    )
    {
    REG_SET regSet;		/* task's register set */

    logMsg ("_dbgTaskPCSet(tid,pc=0x%x,npc)\n", (int)pc,0,0,0,0,0);
    if (taskRegsGet (tid, &regSet) != OK)
	return;

    regSet.pc = (_RType) pc;

    taskRegsSet (tid, &regSet);
    }

/*******************************************************************************
*
* _dbgTaskPCGet - get task's pc
*
* RETURNS:task's program counter
*/

INSTR * _dbgTaskPCGet
    (
    int tid	/* task's id */
    )
    {
    REG_SET	regSet;

    (void) taskRegsGet (tid, &regSet);
    return ((INSTR *) regSet.pc);
    }

#if DBG_HARDWARE_BP
/*******************************************************************************
*
* _dbgBrkDisplayHard - print hardware breakpoint
*
* This routine prints information about hardware breakpoints.
*
* Support here should be coordinated with hwBpTypeList
* in host/resource/tcl/dbgPpcLib.tcl
*
* NOMANUAL
*/

void _dbgBrkDisplayHard
    (
    BRKPT *	pBp	/* breakpoint table entry */
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

# if	(CPU == PPC509) || (CPU == PPC555) || (CPU == PPC604) || (CPU == PPC860)
	case BRK_RW:
	    printf ("r/w data)");
	    break;
	case BRK_READ:
	    printf ("read data)");
	    break;
	case BRK_WRITE:
	    printf ("write data)");
	    break;
# endif	/* CPU == PPC509 || CPU == PPC555 || CPU == PPC604 || CPU == PPC860 */

# if	( (CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F) )
	case BRK_DATAW1:
	    printf ("write byte)");
	    break;
	case BRK_DATAR1:
	    printf ("read byte)");
	    break;
	case BRK_DATARW1:
	    printf ("r/w byte)");
	    break;
	case BRK_DATAW2:
	    printf ("write half)");
	    break;
	case BRK_DATAR2:
	    printf ("read half)");
	    break;
	case BRK_DATARW2:
	    printf ("r/w half)");
	    break;
	case BRK_DATAW4:
	    printf ("write word)");
	    break;
	case BRK_DATAR4:
	    printf ("read word)");
	    break;
	case BRK_DATARW4:
	    printf ("r/w word)");
	    break;
#  if (CPU == PPC403)
	case BRK_DATAW16:
	    printf ("write 4-word)");
	    break;
	case BRK_DATAR16:
	    printf ("read 4-word)");
	    break;
	case BRK_DATARW16:
	    printf ("r/w 4-word)");
	    break;
#  else	/* CPU == PPC403 */
	case BRK_DATAW32:
	    printf ("write 8-word)");
	    break;
	case BRK_DATAR32:
	    printf ("read 8-word)");
	    break;
	case BRK_DATARW32:
	    printf ("r/w 8-word)");
	    break;
#  endif /* CPU == PPC403 */
# endif	/* CPU == PPC40x */

# if	((CPU == PPC440) || (CPU==PPC85XX))
	case BRK_DATAW:
	    printf ("write data)");
	    break;
	case BRK_DATAR:
	    printf ("read data)");
	    break;
	case BRK_DATARW:
	    printf ("r/w data)");
	    break;
# endif	/* CPU == PPC440 */

	default:
	    printf ("unknown)");
	    break;
	}
    }
#endif /* DBG_HARDWARE_BP */
