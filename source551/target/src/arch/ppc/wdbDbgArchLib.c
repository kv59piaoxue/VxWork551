/* wdbDbgArchLib.c - PowerPc specific callouts for the debugger */

/* Copyright 1988-1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01w,02dec02,mil  Updated support for PPC85XX.
01v,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
01u,16may02,pch  add cross-ref for maintainability
01t,14mar02,pch  SPR 74270:  make 440 bh types consistent with 5xx/604/860
01s,22aug01,pch  Add PPC440 support; cleanup
01r,03may01,pch  fix 403 breakage introduced in 405 project
01q,30oct00,s_m  merged changes for 403 HW BP support
01p,27oct00,s_m  changes for PPC405 support
01o,25oct00,s_m  renamed PPC405 cpu types
01n,11oct00,sm   fixed problems with 405
01m,10oct00,sm   set _func_excTrapRtn to wdbDbgBreakpoint for 405
01l,06oct00,sm   PPC405 support
01k,19apr99,zl   added PowerPC 509 and 555 support.
01k,09nov98,elg  added hardware breakpoints for PPC403
01j,13oct98,elg  added hardware breakpoints for PPC603 and PPC604
01i,20sep98,tpr  added PowerPC EC603 support.
01h,28jul98,elg  added hardware breakpoints
01g,09jan98,dbt  modified for new breakpoint scheme
01f,12feb97,tam	 modified wdbArchInit to get rid off wdbBpStub() 
01e,09jul96,ms 	 modified 403 support for new WDB breakpoint library
01d,09may96,tpr	 added PowerPC 860 support.
01c,26feb96,tam	 added support for PPC403. Added single step support for the 
		 PPC403.
01b,26feb96,kkk	 use _EXC_OFF_RUN_TRACE for trace on 601
01a,09sep95,xxx	 written.
*/

/*
DESCRIPTION
This module contains the architecture specific calls needed by the debugger

Hardware breakpoint support should be coordinated with
hwBpTypeList in host/resource/tcl/dbgPpcLib.tcl, and
documented in host/src/tgtsvr/server/wtx.pcl

*/

#include "vxWorks.h"
#include "regs.h"
#include "iv.h"
#include "intLib.h"
#include "ioLib.h"
#include "wdb/wdbDbgLib.h"
#include "arch/ppc/excPpcLib.h"
#include "arch/ppc/vxPpcLib.h"
#if	(CPU == PPC604)
#include "arch/ppc/mmuArchVars.h"
#endif	/* (CPU == PPC604) */

/* externals */

IMPORT void	wdbDbgTraceStub();
IMPORT FUNCPTR	_func_excTrapRtn;

#if	DBG_HARDWARE_BP
IMPORT void	wdbDbgHwBpStub ();
# if	(CPU == PPC604)
IMPORT void	wdbDbgDataAccessStub ();
# endif	/* (CPU == PPC604) */
#endif	/* DBG_HARDWARE_BP */

#if	((CPU == PPC405) || (CPU == PPC405F))
/*
 * Table containing mappings of hardware data breakpoint types and
 * the corresponding DBCR1 bit settings.  Each row represents one
 * breakpoint type.  Column 1 in the table is for the first data
 * breakpoint and column 2 is for the second.
 */
static UINT32 wdbDbgDbcr1ValTable [][2] = 
	{
	 {	0, 0 },				/* dummy entry for BRK_INST */
	 { 	_DBCR1_D1W | _DBCR1_D1S_BYTE,	
		_DBCR1_D2W | _DBCR1_D2S_BYTE }, 	/* BRK_DATAW1 */
	 {	_DBCR1_D1R | _DBCR1_D1S_BYTE,
		_DBCR1_D2R | _DBCR1_D2S_BYTE },		/* BRK_DATAR1 */
	 {	_DBCR1_D1R | _DBCR1_D1W | _DBCR1_D1S_BYTE,
		_DBCR1_D2R | _DBCR1_D2W | _DBCR1_D2S_BYTE }, 
							/* BRK_DATARW1 */
	 {	_DBCR1_D1W | _DBCR1_D1S_HWORD,
		_DBCR1_D2W | _DBCR1_D2S_HWORD },	/* BRK_DATAW2 */
	 {	_DBCR1_D1R | _DBCR1_D1S_HWORD,
		_DBCR1_D2R | _DBCR1_D2S_HWORD },	/* BRK_DATAR2 */
	 {	_DBCR1_D1R | _DBCR1_D1W | _DBCR1_D1S_HWORD,
		_DBCR1_D2R | _DBCR1_D2W | _DBCR1_D2S_HWORD}, 
							/* BRK_DATARW2 */
	 {	_DBCR1_D1W | _DBCR1_D1S_WORD,
		_DBCR1_D2W | _DBCR1_D2S_WORD },		/* BRK_DATAW4 */
	 {	_DBCR1_D1R | _DBCR1_D1S_WORD,
		_DBCR1_D2R | _DBCR1_D2S_WORD },		/* BRK_DATAR4 */
	 {	_DBCR1_D1R | _DBCR1_D1W | _DBCR1_D1S_WORD,
		_DBCR1_D2R | _DBCR1_D2W | _DBCR1_D2S_WORD },
							/* BRK_DATARW4 */
	 {	_DBCR1_D1W | _DBCR1_D1S_CACHE_LINE,
		_DBCR1_D2W | _DBCR1_D2S_CACHE_LINE },
							/* BRK_DATAW32 */
	 {	_DBCR1_D1R | _DBCR1_D1S_CACHE_LINE,
		_DBCR1_D2R | _DBCR1_D2S_CACHE_LINE },
							/* BRK_DATAR32 */
	 {	_DBCR1_D1R | _DBCR1_D1W | _DBCR1_D1S_CACHE_LINE,
		_DBCR1_D2R | _DBCR1_D2W | _DBCR1_D2S_CACHE_LINE },
							/* BRK_DATARW32 */
	};

#elif	((CPU == PPC440) || (CPU == PPC85XX))
/*
 * Table containing mappings of hardware data breakpoint types and
 * the corresponding DBCR0 bit settings.  Each row represents one
 * breakpoint type.  Column 1 in the table is for the first data
 * breakpoint and column 2 is for the second.
 */
static UINT32 wdbDbgDbcr0ValTable [][2] = 
	{
	 {	0, 0 },				/* dummy entry for BRK_INST */
	 { _DBCR0_DAC1R | _DBCR0_DAC1W,
	   _DBCR0_DAC2R | _DBCR0_DAC2W },		/* BRK_DATARW */
	 { _DBCR0_DAC1R, _DBCR0_DAC2R },		/* BRK_DATAR */
	 { _DBCR0_DAC1W, _DBCR0_DAC2W }, 		/* BRK_DATAW */

	};

#endif /* CPU == PPC405 || CPU == PPC405F : CPU == PPC440 || CPU == PPC85XX */

/* forward declaration */

#if	DBG_HARDWARE_BP
LOCAL void	wdbDbgRegsGet (DBG_REGS * pDbgReg);
#endif	/* DBG_HARDWARE_BP */

/*******************************************************************************
*
* wdbDbgArchInit - set exception handlers for the break and the trace.
*
* This routine set exception handlers for the break and the trace.
* And also make a break instruction.
*/

void wdbDbgArchInit(void)
    {
#if	DBG_NO_SINGLE_STEP
    _func_excTrapRtn = (FUNCPTR) wdbDbgTrap;
#else	/* DBG_NO_SINGLE_STEP */
    _func_excTrapRtn = (FUNCPTR) wdbDbgBreakpoint;
#endif	/* DBG_NO_SINGLE_STEP */

#if	(CPU == PPC601)
    excVecSet ((FUNCPTR *) _EXC_OFF_RUN_TRACE, (FUNCPTR) wdbDbgTraceStub);
#elif	((CPU == PPC509)   || (CPU == PPC555) || (CPU == PPC603) || \
	 (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC860)) 
    excVecSet ((FUNCPTR *) _EXC_OFF_TRACE, (FUNCPTR) wdbDbgTraceStub);
#endif 	/* 601 : 509 | 555 | 603 | EC603 | 604 | 860 */

#if	DBG_HARDWARE_BP

# if	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))
    excVecSet ((FUNCPTR *) _EXC_OFF_DATA_BKPT, (FUNCPTR) wdbDbgHwBpStub);
# elif	(CPU == PPC604)
    excVecSet ((FUNCPTR *) _EXC_OFF_DATA, (FUNCPTR) wdbDbgDataAccessStub);
# endif	/* PPC509 | PPC555 | PPC860 : PPC604 */

# if	((CPU == PPC509)   || (CPU == PPC555) || (CPU == PPC603) || \
	 (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC860))
    excVecSet ((FUNCPTR *) _EXC_OFF_INST_BKPT, (FUNCPTR) wdbDbgHwBpStub);
# elif	(defined(_PPC_MSR_CE))
    excCrtConnect ((VOIDFUNCPTR *) _EXC_OFF_DBG, (VOIDFUNCPTR) wdbDbgHwBpStub);
# endif	/* 509 | 555 | 603 | EC603 | 604 | 860 : _PPC_MSR_CE */

#endif	/* DBG_HARDWARE_BP */
    }

/******************************************************************************
*
* wdbDbgTraceModeSet - lock interrupts and set the trace bit.
*/ 

int wdbDbgTraceModeSet
    (
    REG_SET *	pRegs		/* pointer to the register set */
    )
    {
    int oldMsr;

    oldMsr = intRegsLock (pRegs);
#ifdef	_PPC_MSR_SE
    pRegs->msr |= _PPC_MSR_SE;
#endif  /* _PPC_MSR_SE */

    return (oldMsr);
    }

/******************************************************************************
*
* wdbDbgTraceModeClear - restore old int lock level and clear the trace bit.
*/ 

void wdbDbgTraceModeClear
    (
    REG_SET *	pRegs,		/* pointer to the register set */
    int 	oldMsr		/* old value of Machine status register */
    )
    {
    intRegsUnlock (pRegs, oldMsr);
#ifdef	_PPC_MSR_SE
    pRegs->msr &= ~_PPC_MSR_SE;
#endif  /* _PPC_MSR_SE */
    }

#if	DBG_NO_SINGLE_STEP
                /* no h/w single stepping */
/*******************************************************************************
*
* wdbDbgGetNpc - returns the adress of the next instruction to be executed.
*
* RETURNS: Adress of the next instruction to be executed.
*/

INSTR * wdbDbgGetNpc
    (
    REG_SET *  pRegs            /* pointer to task registers */
    )
    {
    INSTR               machInstr;              /* Machine instruction */
    INSTR *             npc;                    /* next program counter */
    UINT32              branchType;
    UINT32              li;                     /* LI field */
    UINT32              lr;                     /* LR field */
    UINT32              bd;                     /* BD field */
    UINT32              bo;                     /* BO field */
    UINT32              bi;                     /* BI field */
    _RType              ctr;                    /* CTR register  */
    INSTR *             cr;                     /* CR register   */
    BOOL                cond;
    UINT32              bo2,bo3,bo0,bo1,crbi;   /* bits values   */

    npc = (INSTR *) (pRegs->pc + 4);		/* Default nPC */
    machInstr = *(INSTR *)(pRegs->reg_pc);

    /*
     * tests for branch instructions:
     * bits 0-3 are common for all branch
     */

    if ((machInstr & BRANCH_MASK) == OP_BRANCH)
        {
        /* opcode bits 0 to 5 equal 16,17,18 or 19 */

        branchType = (machInstr & 0xFC000000) >> 26;

        ctr = pRegs->ctr;
        cr = (INSTR *) pRegs->cr;
        lr = pRegs->lr;
        li = _IFIELD_LI (machInstr);
        bo = _IFIELD_BO (machInstr);
        bi = _IFIELD_BI (machInstr);
        bd = _IFIELD_BD (machInstr);

        bo0 = _REG32_BIT (bo, (BO_NB_BIT-1));   /* bit 0 of BO */
        bo1 = _REG32_BIT (bo, (BO_NB_BIT-2));   /* bit 1 of BO */
        bo2 = _REG32_BIT (bo, (BO_NB_BIT-3));   /* bit 2 of BO */
        bo3 = _REG32_BIT (bo, (BO_NB_BIT-4));   /* bit 3 of BO */
        crbi = _REG32_BIT ((UINT32) cr, (CR_NB_BIT-1-((UINT32) bi)));
                                                /* bit bi of CR */

        /* Switch on the type of branch (Bx, BCx, BCCTRx, BCLRx)   */

        switch (branchType)
            {
            case (16):                          /* BC - Branch Conditional */
                {
                if (bo2 == 0)                   /* bit 2 of BO == 0   */
                    ctr--;                      /* decrement CTR register */

                /* test branch condition */

                cond = FALSE;
                if ((bo2 == 1) || ((ctr == 0) && (bo3 == 0)) )
                    if ((bo0 == 1) || (bo1 == crbi))
                        cond = TRUE;
                if (cond)
                    if ((machInstr & AA_MASK) == 1)
                        npc = (INSTR *) bd;	/* AA = 1 : absolute branch */
                    else
			/* AA = 0 : relative branch */
                        npc = (INSTR *) (pRegs->pc + bd);
                }
                break;


            case (18):                          /* B  - Unconditional Branch */
                {
                if ((machInstr & AA_MASK) == 1)
                    npc = (INSTR *) li;		/* AA = 1 : absolute branch */
                else
		    /* AA = 0 : relative branch */
                    npc = (INSTR *)(pRegs->pc + li);
                }
                break;


            case (19): /* Bcctr or Bclr - Branch Conditional to Register */
                {
                if ((machInstr & BCCTR_MASK) == INST_BCCTR)
                    {
                    /* Bcctr - Branch Conditional to Count Register */

                    if (bo2 == 0)               /* bit 2 of BO == 0   */
                        ctr--;                  /* decrement CTR register */

                    /* test branch condition */

                    cond = FALSE;
                    if ((bo2 == 1) || ((ctr == 0) && (bo3 == 0)))
                        if ((bo0 == 1) || (bo1 == crbi))
                            cond = TRUE;
                    if (cond)
			/* branch relative to CTR */
                        npc = (INSTR *) (ctr & 0xFFFFFFFC);
                    }

                if ((machInstr & BCLR_MASK) == INST_BCLR)
                    {
                    /* Bclr - Branch Conditional to Link Register */

                    if (bo2 == 0)               /* bit 2 of BO == 0   */
                        ctr--;                  /* decrement CTR register */

                    /* test branch condition */

                    cond = FALSE;
                    if ((bo2 == 1) || ((ctr == 0) && (bo3 == 0)))
                        if ((bo0 == 1) || (bo1 == crbi))
                            cond = TRUE;
                    if (cond)
			/* branch relative to LR */
			npc = (INSTR *) (lr & 0xFFFFFFFC);
                    }
                }
                break;
            }
        }
    return (npc);
    }
#endif	/* DBG_NO_SINGLE_STEP */

#if	DBG_HARDWARE_BP
/*******************************************************************************
*
* wdbDbgHwAddrCheck - check the address for the hardware breakpoint.
*
* This routine checks the address for the hardware breakpoint.
*
* RETUTNS: OK or ERROR if address not 32-bit boundary or unaccessible.
*
* NOMANUAL
*/

STATUS wdbDbgHwAddrCheck
    (
    UINT32	addr,		/* address to check */
    UINT32	type,		/* access type */
    FUNCPTR	memProbeRtn	/* memProbe routine */
    )
    {
    UINT32	val;		/* dummy for memProbeRtn */

    type = (type & BRK_HARDMASK);

    /*
     * Breakpoint address must be 32bit-aligned except for a data breakpoint
     * on a PPC4xx/5xx/860 where it is possible to break on a byte access.
     */

#if	((CPU == PPC509)   || (CPU == PPC555) || (CPU == PPC860) || \
	 (CPU == PPC405F)  || (CPU == PPC405) || (CPU == PPC440) || \
	 (CPU == PPC85XX))
    if (type == BRK_INST)
#endif	/* CPU == PPC5xx, PPC860, PPC4xx, PPC85XX */
	if (addr & 0x03)
	    return (ERROR);

    switch (type)
    	{
#if	(CPU == PPC509)   || (CPU == PPC555) || (CPU == PPC603)  || \
	(CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC860)
	case BRK_INST:
	case BRK_READ:
	case BRK_WRITE:
	case BRK_RW:
	    if (memProbeRtn ((char *) (addr & ~0x03), O_RDONLY, 4,
	                     (char *) &val) != OK)
	    	return (ERROR);
	    break;

#elif	( (CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F) )
	case BRK_DATAR1:
	case BRK_DATAW1:
	case BRK_DATARW1:
	    if (memProbeRtn ((char *) addr, O_RDONLY, 1, (char *) &val) != OK)
	    	return (ERROR);
	    break;
	case BRK_DATAR2:
	case BRK_DATAW2:
	case BRK_DATARW2:
	    if ((addr & 0x01) ||
	        (memProbeRtn ((char *) addr, O_RDONLY, 2, (char *) &val) != OK))
	    	return (ERROR);
	    break;
	case BRK_INST:
	case BRK_DATAR4:
	case BRK_DATAW4:
	case BRK_DATARW4:
	    if ((addr & 0x03) ||
	        (memProbeRtn ((char *) addr, O_RDONLY, 4, (char *) &val) != OK))
	    	return (ERROR);
	    break;
# if	(CPU == PPC403)
	case BRK_DATAR16:
	case BRK_DATAW16:
	case BRK_DATARW16:
	    if ((addr & 0x0F) ||
	(memProbeRtn ((char *) addr +  0, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr +  4, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr +  8, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr + 12, O_RDONLY, 4, (char *) &val) != OK)
		)
	    	return (ERROR);
	    break;

# elif ((CPU == PPC405) || (CPU == PPC405F))
	case BRK_DATAR32:
	case BRK_DATAW32:
	case BRK_DATARW32:
	    if (
	(memProbeRtn ((char *) addr +  0, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr +  4, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr +  8, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr + 12, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr + 16, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr + 20, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr + 24, O_RDONLY, 4, (char *) &val) != OK) ||
	(memProbeRtn ((char *) addr + 28, O_RDONLY, 4, (char *) &val) != OK)
		)
	    	return (ERROR);
	    break;
# endif	/* 40x */

#elif	((CPU == PPC440) || (CPU == PPC85XX))
	case BRK_DATAR:
	case BRK_DATAW:
	case BRK_DATARW:
	    if (memProbeRtn ((char *) addr, O_RDONLY, 1, (char *) &val) != OK)
	    	return (ERROR);
	    break;
	case BRK_INST:
	    if ((addr & 0x03) ||
	        (memProbeRtn ((char *) addr, O_RDONLY, 4, (char *) &val) != OK))
	    	return (ERROR);
	    break;

#endif	/* PPC5xx | PPC60x | PPC860 : PPC40x */

	default:
	    break;
	}

    return (OK);
    }

/*******************************************************************************
*
* wdbDbgHwBpSet - set the Development Support Registers
*
* Access is the type of access that will generate a breakpoint (depends on the
* architecture).
*
* NOMANUAL
*/

STATUS wdbDbgHwBpSet
    (
    DBG_REGS *  pDbgRegs,       /* debug registers */
    UINT32      access,         /* access type */
    UINT32      addr            /* breakpoint addr */
    )
    {
    int		status = OK;

    switch (access)
        {
	case BRK_INST:

#if	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))

	    /* take the first free instruction breakpoint register and set it */

	    if ((pDbgRegs->ictrl & _PPC_ICTRL_SIW0EN) != _PPC_ICTRL_SIW0EN)
	        {
		pDbgRegs->cmpa = addr;
		pDbgRegs->ictrl |= _PPC_ICTRL_CTA(_PPC_ICTRL_CT_EQ) |
		                   _PPC_ICTRL_IW0_A | _PPC_ICTRL_SIW0EN;
		}
	    else if ((pDbgRegs->ictrl & _PPC_ICTRL_SIW1EN) != _PPC_ICTRL_SIW1EN)
	        {
		pDbgRegs->cmpb = addr;
		pDbgRegs->ictrl |= _PPC_ICTRL_CTB(_PPC_ICTRL_CT_EQ) |
		                   _PPC_ICTRL_IW1_B | _PPC_ICTRL_SIW1EN;
		}
	    else if ((pDbgRegs->ictrl & _PPC_ICTRL_SIW2EN) != _PPC_ICTRL_SIW2EN)
	        {
		pDbgRegs->cmpc = addr;
		pDbgRegs->ictrl |= _PPC_ICTRL_CTC(_PPC_ICTRL_CT_EQ) |
		                   _PPC_ICTRL_IW2_C | _PPC_ICTRL_SIW2EN;
		}
	    else if ((pDbgRegs->ictrl & _PPC_ICTRL_SIW3EN) != _PPC_ICTRL_SIW3EN)
	        {
		pDbgRegs->cmpd = addr;
		pDbgRegs->ictrl |= _PPC_ICTRL_CTD(_PPC_ICTRL_CT_EQ) |
		                   _PPC_ICTRL_IW3_D | _PPC_ICTRL_SIW3EN;
		}
	    else

#elif	(CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)
	    if ((pDbgRegs->iabr & _PPC_IABR_BE) != _PPC_IABR_BE)
	        {
	        pDbgRegs->iabr = _PPC_IABR_ADD(addr) |
# if	(CPU == PPC604)
				 (mmuPpcIEnabled ? _PPC_IABR_TE : 0) |
# endif	/* (CPU == PPC604) */
		                 _PPC_IABR_BE;
		}
	    else

#elif	(CPU == PPC403)
	    if ((pDbgRegs->dbcr & _DBCR_IA1) != _DBCR_IA1)
	        {
		pDbgRegs->iac1 = addr;
		pDbgRegs->dbcr |= _DBCR_IDM | _DBCR_IA1;
		}
	    else if ((pDbgRegs->dbcr & _DBCR_IA2) != _DBCR_IA2)
	        {
		pDbgRegs->iac2 = addr;
		pDbgRegs->dbcr |= _DBCR_IDM | _DBCR_IA2;
		}
	    else

#elif   ((CPU == PPC405) || (CPU == PPC405F))
	    if ((pDbgRegs->dbcr0 & _DBCR0_IA1) != _DBCR0_IA1)
		{
		pDbgRegs->iac1 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM | _DBCR0_IA1;
		}
	    else if ((pDbgRegs->dbcr0 & _DBCR0_IA2) != _DBCR0_IA2)
		{
		pDbgRegs->iac2 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM | _DBCR0_IA2;
		}
	    else if ((pDbgRegs->dbcr0 & _DBCR0_IA3) != _DBCR0_IA3)
		{
		pDbgRegs->iac3 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM | _DBCR0_IA3;
		}
	    else if ((pDbgRegs->dbcr0 & _DBCR0_IA4) != _DBCR0_IA4)
		{
		pDbgRegs->iac4 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM | _DBCR0_IA4;
		}
	    else

#elif   ((CPU == PPC440) || (CPU == PPC85XX))
	    if ((pDbgRegs->dbcr0 & _DBCR0_IAC1) != _DBCR0_IAC1)
		{
		pDbgRegs->iac1 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM | _DBCR0_IAC1;
		}
	    else if ((pDbgRegs->dbcr0 & _DBCR0_IAC2) != _DBCR0_IAC2)
		{
		pDbgRegs->iac2 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM | _DBCR0_IAC2;
		}
#if   (CPU != PPC85XX)
	    else if ((pDbgRegs->dbcr0 & _DBCR0_IAC3) != _DBCR0_IAC3)
		{
		pDbgRegs->iac3 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM | _DBCR0_IAC3;
		}
	    else if ((pDbgRegs->dbcr0 & _DBCR0_IAC4) != _DBCR0_IAC4)
		{
		pDbgRegs->iac4 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM | _DBCR0_IAC4;
		}
#endif  /* CPU != PPC85XX */

	    else

#endif	/* PPC5xx | PPC860 : PPC60x : PPC403 : PPC405x */

	        /* no more free breakpoint register */

	        status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;

#if	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))
	case BRK_READ:
	case BRK_WRITE:
	case BRK_RW:

	    /* take the first free data breakpoint register and set it */

	    if ((pDbgRegs->lctrl2 & _PPC_LCTRL2_LW0EN) != _PPC_LCTRL2_LW0EN)
	        {
		pDbgRegs->cmpe = addr;
		pDbgRegs->lctrl1 |= _PPC_LCTRL1_CTE(_PPC_LCTRL1_CT_EQ) |
		                    _PPC_LCTRL1_CRWE(access);
		pDbgRegs->lctrl2 |= _PPC_LCTRL2_LW0LA_E |
				    _PPC_LCTRL2_LW0LADC |
		                    _PPC_LCTRL2_LW0EN |
				    _PPC_LCTRL2_SLW0EN;
		}
	    else if ((pDbgRegs->lctrl2 & _PPC_LCTRL2_LW1EN) !=
	             _PPC_LCTRL2_LW1EN)
                {
		pDbgRegs->cmpf = addr;
		pDbgRegs->lctrl1 |= _PPC_LCTRL1_CTF(_PPC_LCTRL1_CT_EQ) |
		                    _PPC_LCTRL1_CRWF(access);
		pDbgRegs->lctrl2 |= _PPC_LCTRL2_LW1LA_F |
				    _PPC_LCTRL2_LW1LADC |
		                    _PPC_LCTRL2_LW1EN |
				    _PPC_LCTRL2_SLW1EN;
		}
	    else

	        /* no more free breakpoint register */

	        status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;

#elif (CPU == PPC604)
	case BRK_READ:
	    if (!(pDbgRegs->dabr & (_PPC_DABR_DW | _PPC_DABR_DR)))
	        pDbgRegs->dabr = _PPC_DABR_DAB(addr) |
		                 (mmuPpcDEnabled ? _PPC_DABR_BT : 0) |
				 _PPC_DABR_DR;
	    else
	        status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;
	case BRK_WRITE:
	    if (!(pDbgRegs->dabr & (_PPC_DABR_DW | _PPC_DABR_DR)))
	        pDbgRegs->dabr = _PPC_DABR_DAB(addr) |
		                  (mmuPpcDEnabled ? _PPC_DABR_BT : 0) |
				  _PPC_DABR_DW;
	    else
	        status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;
	case BRK_RW:
	    if (!(pDbgRegs->dabr & (_PPC_DABR_DW | _PPC_DABR_DR)))
	        pDbgRegs->dabr = _PPC_DABR_DAB(addr) |
		                 (mmuPpcDEnabled ? _PPC_DABR_BT : 0) |
				 _PPC_DABR_DR | _PPC_DABR_DW;
	    else
	        status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;

#elif	(CPU == PPC403)
	case BRK_DATAR1:
	case BRK_DATAW1:
	case BRK_DATARW1:
	case BRK_DATAR2:
	case BRK_DATAW2:
	case BRK_DATARW2:
	case BRK_DATAR4:
	case BRK_DATAW4:
	case BRK_DATARW4:
	case BRK_DATAR16:
	case BRK_DATAW16:
	case BRK_DATARW16:
	    if (!(pDbgRegs->dbcr & (_DBCR_D1R | _DBCR_D1W)))
	        {
		pDbgRegs->dac1 = addr;
		pDbgRegs->dbcr |= _DBCR_IDM | _DBCR_D1A(access) |
		                  _DBCR_D1S(access);
		}
	    else if (!(pDbgRegs->dbcr & (_DBCR_D2R | _DBCR_D2W)))
	        {
		pDbgRegs->dac2 = addr;
		pDbgRegs->dbcr |= _DBCR_IDM | _DBCR_D2A(access) |
		                  _DBCR_D2S(access);
	        }
	    else
	        status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;

#elif	((CPU == PPC405) || (CPU == PPC405F))
	case BRK_DATAR1:
	case BRK_DATAW1:
	case BRK_DATARW1:
	case BRK_DATAR2:
	case BRK_DATAW2:
	case BRK_DATARW2:
	case BRK_DATAR4:
	case BRK_DATAW4:
	case BRK_DATARW4:
	case BRK_DATAR32:
	case BRK_DATAW32:
	case BRK_DATARW32:
	if (!(pDbgRegs->dbcr1 & (_DBCR1_D1R | _DBCR1_D1W)))
		{
		pDbgRegs->dac1 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM;
		pDbgRegs->dbcr1 |= wdbDbgDbcr1ValTable [access][0];
		}
	else if (!(pDbgRegs->dbcr1 & (_DBCR1_D2R | _DBCR1_D2W)))
		{
		pDbgRegs->dac2 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM;
		pDbgRegs->dbcr1 |= wdbDbgDbcr1ValTable [access][1];
		}
	else
		status = WDB_ERR_HW_REGS_EXHAUSTED;
	break;

#elif	((CPU == PPC440) || (CPU == PPC85XX))
	case BRK_DATAR:
	case BRK_DATAW:
	case BRK_DATARW:
	if (!(pDbgRegs->dbcr0 & (_DBCR0_DAC1R | _DBCR0_DAC1W)))
		{
		pDbgRegs->dac1 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM;
		pDbgRegs->dbcr0 |= wdbDbgDbcr0ValTable [access][0];
		}
	else if (!(pDbgRegs->dbcr0 & (_DBCR0_DAC2R | _DBCR0_DAC2W)))
		{
		pDbgRegs->dac2 = addr;
		pDbgRegs->dbcr0 |= _DBCR0_IDM;
		pDbgRegs->dbcr0 |= wdbDbgDbcr0ValTable [access][1];
		}
	else
		status = WDB_ERR_HW_REGS_EXHAUSTED;
	break;
#endif	/* PPC5xx | PPC860 : PPC604 : PPC403 : PPC405x : PPC440 | PPC85XX */

	default:
	    status = WDB_ERR_INVALID_HW_BP;
	}
	
#if	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))

    /* set nonmasked mode, breakpoints are always recognized */

    if (status == OK)
        pDbgRegs->lctrl2 |= _PPC_LCTRL2_BRKNOMSK;

#elif	(defined(_PPC_MSR_DE))

    /* set MSR to enable debug exceptions */

    if (status == OK)
    	pDbgRegs->msr |= _PPC_MSR_DE;

#endif	/* PPC5xx | PPC860 : _PPC_MSR_DE */

    return (status) ;
    }

/*******************************************************************************
*
* wdbDbgHwBpFind - Find the hardware breakpoint
*
* This routine finds the type and the address of the address of the
* hardware breakpoint that is set in the DBG_REGS structure.
* Those informations are stored in the breakpoint structure that is passed
* in parameter.
*
* RETURNS : OK or ERROR if unable to find the hardware breakpoint
*
* NOMANUAL
*/

STATUS wdbDbgHwBpFind
    (
    DBG_REGS *  pDbgRegs,
    UINT32 *    pType,          /* return type info via this pointer */
    UINT32 *    pAddr           /* return address info via this pointer */
    )
    {
    int addr = 0;
    int type = 0;
#if	((CPU == PPC405) || (CPU == PPC405F))
	UINT32	dbcr1;
	int i;
#endif	/* CPU == PPC405x */
#if	((CPU == PPC440) || (CPU == PPC85XX))
	UINT32	dbcr0;
	int i;
#endif	/* CPU == PPC440 || CPU == PPC85XX */

#if 	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))

    switch (pDbgRegs->ictrl & _PPC_ICTRL_SIWEN_MSK)
        {
        case _PPC_ICTRL_SIW0EN:
	    addr = pDbgRegs->cmpa;
	    type = BRK_INST | BRK_HARDWARE;
	    break;

	case _PPC_ICTRL_SIW1EN:
	    addr = pDbgRegs->cmpb;
	    type = BRK_INST | BRK_HARDWARE;
	    break;

	case _PPC_ICTRL_SIW2EN:
	    addr = pDbgRegs->cmpc;
	    type = BRK_INST | BRK_HARDWARE;
	    break;

	case _PPC_ICTRL_SIW3EN:
	    addr = pDbgRegs->cmpd;
	    type = BRK_INST | BRK_HARDWARE;
	    break;
	}

    if ((pDbgRegs->lctrl2 & _PPC_LCTRL2_LW0EN) == _PPC_LCTRL2_LW0EN)
        {
	addr = pDbgRegs->cmpe;
	type = _PPC_LCTRL1_TYPE_E(pDbgRegs->lctrl1) | BRK_HARDWARE;
	}

    else if ((pDbgRegs->lctrl2 & _PPC_LCTRL2_LW1EN) == _PPC_LCTRL2_LW1EN)
        {
	addr = pDbgRegs->cmpf;
	type = _PPC_LCTRL1_TYPE_F(pDbgRegs->lctrl1) | BRK_HARDWARE;
	}

#endif	/* (CPU == PPC5xx) || (CPU == PPC860) */

#if	(CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)
    if ((pDbgRegs->iabr & _PPC_IABR_BE) == _PPC_IABR_BE)
        {
	addr = _PPC_IABR_ADD(pDbgRegs->iabr);
	type = BRK_INST | BRK_HARDWARE;
	}
#endif	/* (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) */

#if	(CPU == PPC604)
    switch (pDbgRegs->dabr & _PPC_DABR_D_MSK)
        {
        case _PPC_DABR_DR:
	    addr = pDbgRegs->dar & ~0x03;	/* 32-bit aligned address */
	    type = BRK_READ | BRK_HARDWARE;
	    break;
	case _PPC_DABR_DW:
	    addr = pDbgRegs->dar & ~0x03;
	    type = BRK_WRITE | BRK_HARDWARE;
	    break;
	case (_PPC_DABR_DR | _PPC_DABR_DW):
	    addr = pDbgRegs->dar & ~0x03;
	    type = BRK_RW | BRK_HARDWARE;
	    break;
	}
#endif	/* (CPU == PPC604) */

#if	(CPU == PPC403)
    switch (pDbgRegs->dbsr & _DBSR_HWBP_MSK)
        {
	case _DBSR_IA1:
	    addr = pDbgRegs->iac1;
	    type = BRK_INST | BRK_HARDWARE;
	    break;
	case _DBSR_IA2:
	    addr = pDbgRegs->iac2;
	    type = BRK_INST | BRK_HARDWARE;
	    break;
	case _DBSR_DR1:
	case _DBSR_DW1:
	    addr = pDbgRegs->dac1;
	    type = _DBCR_D1_ACCESS(pDbgRegs->dbcr) |
	           _DBCR_D1_SIZE(pDbgRegs->dbcr) |
		   BRK_HARDWARE;
	    break;
	case _DBSR_DR2:
	case _DBSR_DW2:
	    addr = pDbgRegs->dac2;
	    type = _DBCR_D2_ACCESS(pDbgRegs->dbcr) |
	           _DBCR_D2_SIZE(pDbgRegs->dbcr) |
		   BRK_HARDWARE;
	    break;
	}

#elif ((CPU == PPC405) || (CPU == PPC405F))
    switch (pDbgRegs->dbsr & _DBSR_HWBP_MSK)
        {
        case _DBSR_IA1:
            addr = pDbgRegs->iac1;
            type = BRK_INST | BRK_HARDWARE;
            break;
        case _DBSR_IA2:
            addr = pDbgRegs->iac2;
            type = BRK_INST | BRK_HARDWARE;
            break;
        case _DBSR_IA3:
            addr = pDbgRegs->iac3;
            type = BRK_INST | BRK_HARDWARE;
            break;
        case _DBSR_IA4:
            addr = pDbgRegs->iac4;
            type = BRK_INST | BRK_HARDWARE;
            break;
        case _DBSR_DR1:
        case _DBSR_DW1:
            addr = pDbgRegs->dac1;
	    dbcr1 = pDbgRegs->dbcr1 & (_DBCR1_D1R | _DBCR1_D2R | \
				       _DBCR1_D1W | _DBCR1_D2W | \
				       _DBCR1_D1S | _DBCR1_D2S);
	    for ( i = 0 ;
		  i < (sizeof(wdbDbgDbcr1ValTable) / (2 * sizeof(UINT32))) ;
		  i++ )
		{
		if (wdbDbgDbcr1ValTable[i][0] == dbcr1)
		    break;
		}
	    type = i | BRK_HARDWARE;
            break;
        case _DBSR_DR2:
        case _DBSR_DW2:
            addr = pDbgRegs->dac2;
	    dbcr1 = pDbgRegs->dbcr1 & (_DBCR1_D1R | _DBCR1_D2R | \
				       _DBCR1_D1W | _DBCR1_D2W | \
				       _DBCR1_D1S | _DBCR1_D2S);
	    for ( i = 0 ;
		  i < (sizeof(wdbDbgDbcr1ValTable) / (2 * sizeof(UINT32))) ;
		  i++ )
		{
		if (wdbDbgDbcr1ValTable[i][1] == dbcr1)
		    break;
		}
	    type = i | BRK_HARDWARE;
            break;
        }
#elif ((CPU == PPC440) || (CPU == PPC85XX))
    switch (pDbgRegs->dbsr & _DBSR_HWBP_MSK)
        {
        case _DBSR_IAC1:
            addr = pDbgRegs->iac1;
            type = BRK_INST | BRK_HARDWARE;
            break;
        case _DBSR_IAC2:
            addr = pDbgRegs->iac2;
            type = BRK_INST | BRK_HARDWARE;
            break;
#if   (CPU != PPC85XX)
        case _DBSR_IAC3:
            addr = pDbgRegs->iac3;
            type = BRK_INST | BRK_HARDWARE;
            break;
        case _DBSR_IAC4:
            addr = pDbgRegs->iac4;
            type = BRK_INST | BRK_HARDWARE;
            break;
#endif  /* CPU != PPC85XX */
        case _DBSR_DAC1R:
        case _DBSR_DAC1W:
            addr = pDbgRegs->dac1;
	    dbcr0 = pDbgRegs->dbcr0 & (_DBCR0_DAC1R | _DBCR0_DAC2R | \
				       _DBCR0_DAC1W | _DBCR0_DAC2W );
	    for ( i = 0 ;
		  i < (sizeof(wdbDbgDbcr0ValTable) / (2 * sizeof(UINT32))) ;
		  i++ )
		{
		if (wdbDbgDbcr0ValTable[i][0] == dbcr0)
		    break;
		}
	    type = i | BRK_HARDWARE;
            break;
        case _DBSR_DAC2R:
        case _DBSR_DAC2W:
            addr = pDbgRegs->dac2;
	    dbcr0 = pDbgRegs->dbcr0 & (_DBCR0_DAC1R | _DBCR0_DAC2R | \
				       _DBCR0_DAC1W | _DBCR0_DAC2W );
	    for ( i = 0 ;
		  i < (sizeof(wdbDbgDbcr0ValTable) / (2 * sizeof(UINT32))) ;
		  i++ )
		{
		if (wdbDbgDbcr0ValTable[i][1] == dbcr0)
		    break;
		}
	    type = i | BRK_HARDWARE;
            break;
        }
#endif	/* (CPU == PPC4xx) */
	    
    if ((addr == 0) && (type == 0))
        return (ERROR);

    *pType = type;
    *pAddr = addr;

    return (OK);
    }

/*******************************************************************************
*
* wdbDbgHwBpHandle - interrupt level handling of hardware breakpoints
*
* This handler gets the debug registers and calls the common handler for
* breakpoints.
*
* NOMANUAL
*/

void wdbDbgHwBpHandle
    (
    void *	pInfo,		/* pointer on info */
    REG_SET *	pRegisters	/* pointer to register set */
    )
    {
    DBG_REGS	dbgRegSet;	/* debug registers */

    wdbDbgRegsGet (&dbgRegSet);
    wdbDbgRegsClear ();
#if	DBG_NO_SINGLE_STEP
    wdbDbgTrap ((INSTR *) pRegisters->pc, pRegisters, pInfo, &dbgRegSet, TRUE);
#else	/* DBG_NO_SINGLE_STEP */
    wdbDbgBreakpoint (pInfo, pRegisters, &dbgRegSet, TRUE);
#endif	/* DBG_NO_SINGLE_STEP */
    }

/*******************************************************************************
*
* wdbDbgRegsGet - get hardware breakpoint registers
*
* This routine reads hardware breakpoint registers.
*/

LOCAL void wdbDbgRegsGet
    (
    DBG_REGS *	pDbgReg		/* debug register set */
    )
    {

#if 	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))

    pDbgReg->cmpa = dbgCmpaGet ();		/* get comparator A register */
    pDbgReg->cmpb = dbgCmpbGet ();		/* get comparator B register */
    pDbgReg->cmpc = dbgCmpcGet ();		/* get comparator C register */
    pDbgReg->cmpd = dbgCmpdGet (); 	        /* get comparator D register */
    pDbgReg->cmpe = dbgCmpeGet ();	     	/* get comparator E register */
    pDbgReg->cmpf = dbgCmpfGet ();	     	/* get comparator F register */
    pDbgReg->lctrl1 = dbgLctrl1Get ();     	/* get LCTRL1 register */
    pDbgReg->lctrl2 = dbgLctrl2Get ();     	/* get LCTRL2 register */
    pDbgReg->ictrl = dbgIctrlGet ();     	/* get ICTRL register */

#elif	(CPU == PPC603) || (CPU ==PPCEC603) || (CPU == PPC604)

    pDbgReg->iabr = wdbDbgIabrGet ();		/* get IABR register */
# if	(CPU == PPC604)
    pDbgReg->dabr = wdbDbgDabrGet ();		/* get DABR register */
    pDbgReg->dar = wdbDbgDarGet ();		/* get DAR register */
# endif	/* (CPU == PPC604) */

#elif	 (CPU == PPC403) 

    pDbgReg->dbcr = wdbDbgDbcrGet ();		/* get DBCR register */
    pDbgReg->dbsr = wdbDbgDbsrGet ();		/* get DBSR register */
    pDbgReg->dac1 = wdbDbgDac1Get ();		/* get DAC1 register */
    pDbgReg->dac2 = wdbDbgDac2Get ();		/* get DAC2 register */
    pDbgReg->iac1 = wdbDbgIac1Get ();		/* get IAC1 register */
    pDbgReg->iac2 = wdbDbgIac2Get ();		/* get IAC2 register */
    pDbgReg->msr = vxMsrGet ();			/* get MSR register */

#elif    ((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
	  (CPU == PPC85XX))

    pDbgReg->dbcr0= wdbDbgDbcr0Get ();           /* get DBCR0 register */
    pDbgReg->dbcr1= wdbDbgDbcr1Get ();           /* get DBCR1 register */
# if	((CPU == PPC440) || (CPU == PPC85XX))
    pDbgReg->dbcr2= wdbDbgDbcr2Get ();           /* get DBCR2 register */
# endif	/* CPU == PPC440, PPC85XX */
    pDbgReg->dbsr = wdbDbgDbsrGet ();           /* get DBSR register */
    pDbgReg->dac1 = wdbDbgDac1Get ();           /* get DAC1 register */
    pDbgReg->dac2 = wdbDbgDac2Get ();           /* get DAC2 register */
    pDbgReg->iac1 = wdbDbgIac1Get ();           /* get IAC1 register */
    pDbgReg->iac2 = wdbDbgIac2Get ();           /* get IAC2 register */
#if   (CPU != PPC85XX)
    pDbgReg->iac3 = wdbDbgIac3Get ();           /* get IAC3 register */
    pDbgReg->iac4 = wdbDbgIac4Get ();           /* get IAC4 register */
#endif  /* CPU != PPC85XX */
    pDbgReg->msr = vxMsrGet ();                 /* get MSR register */

#endif	/* PPC5xx | PPC860 : PPC60x : PPC403 : PPC405x */
    }

/*******************************************************************************
*
* wdbDbgRegsSet - set hardware breakpoint registers
*
* This routine sets hardware breakpoint registers.
*
* NOMANUAL
*/

void wdbDbgRegsSet
    (
    DBG_REGS *	pDbgReg		/* debug register set */
    )
    {

#if 	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))

    dbgCmpaSet (pDbgReg->cmpa);			/* set comparator A register */
    dbgCmpbSet (pDbgReg->cmpb);			/* set comparator B register */
    dbgCmpcSet (pDbgReg->cmpc);			/* set comparator C register */
    dbgCmpdSet (pDbgReg->cmpd);			/* set comparator D register */
    dbgCmpeSet (pDbgReg->cmpe);			/* set comparator E register */
    dbgCmpfSet (pDbgReg->cmpf);			/* set comparator F register */
    dbgLctrl1Set (pDbgReg->lctrl1);		/* set LCTRL1 register */
    dbgLctrl2Set (pDbgReg->lctrl2);		/* set LCTRL2 register */

    /* change only used bits of ICTRL register */

    dbgIctrlSet (pDbgReg->ictrl | dbgIctrlGet ());	/* set ICTRL register */

#elif	(CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)

    wdbDbgIabrSet (pDbgReg->iabr);		/* set IABR regsiter */
# if	(CPU == PPC604)
    wdbDbgDabrSet (pDbgReg->dabr);		/* set DABR register */
# endif	/* (CPU == PPC604) */

#elif	(CPU == PPC403)

    wdbDbgDbcrSet (pDbgReg->dbcr);		/* set DBCR register */
    wdbDbgDac1Set (pDbgReg->dac1);		/* set DAC1 register */
    wdbDbgDac2Set (pDbgReg->dac2);		/* set DAC2 register */
    wdbDbgIac1Set (pDbgReg->iac1);		/* set IAC1 register */
    wdbDbgIac2Set (pDbgReg->iac2);		/* set IAC2 register */
    vxMsrSet (pDbgReg->msr | vxMsrGet ());	/* set MSR register */

#elif   ((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
	 (CPU == PPC85XX))

    wdbDbgDbcr0Set (pDbgReg->dbcr0);            /* set DBCR0 register */
    wdbDbgDbcr1Set (pDbgReg->dbcr1);            /* set DBCR1 register */
# if	((CPU == PPC440) || (CPU == PPC85XX))
    wdbDbgDbcr2Set (pDbgReg->dbcr2);            /* set DBCR2 register */
# endif	/* CPU == PPC440, PPC85XX */
    wdbDbgDac1Set (pDbgReg->dac1);              /* set DAC1 register */
    wdbDbgDac2Set (pDbgReg->dac2);              /* set DAC2 register */
    wdbDbgIac1Set (pDbgReg->iac1);              /* set IAC1 register */
    wdbDbgIac2Set (pDbgReg->iac2);              /* set IAC2 register */
#if   (CPU != PPC85XX)
    wdbDbgIac3Set (pDbgReg->iac3);              /* set IAC3 register */
    wdbDbgIac4Set (pDbgReg->iac4);              /* set IAC4 register */
#endif  /* CPU != PPC85XX */
    vxMsrSet (pDbgReg->msr | vxMsrGet ());      /* set MSR register */

#endif	/* PPC5xx | PPC860 : PPC60x : PPC403 : PPC405x */
    }

/*******************************************************************************
*
* wdbDbgRegsClear - clear hardware breakpoint registers
*
* This routine clears hardware breakpoint registers.
*
* NOMANUAL
*/

void wdbDbgRegsClear (void)
    {

#ifdef	_PPC_MSR_DE
    /* clear debug enable bit in MSR before clobbering DBCRx */
    vxMsrSet (vxMsrGet () & ~_PPC_MSR_DE);
#endif	/* _PPC_MSR_DE */

#if 	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))

    dbgCmpaSet (0);			/* clear comparator A register */
    dbgCmpbSet (0);			/* clear comparator B register */
    dbgCmpcSet (0);			/* clear comparator C register */
    dbgCmpdSet (0);			/* clear comparator D register */
    dbgCmpeSet (0);			/* clear comparator E register */
    dbgCmpfSet (0);			/* clear comparator F register */
    dbgLctrl1Set (0);			/* clear LCTRL1 register */
    dbgLctrl2Set (0);			/* clear LCTRL2 register */

    /* clear only used bits of ICTRL register */

    dbgIctrlSet (dbgIctrlGet () & ~_PPC_ICTRL_HWBP_MSK);

#elif	(CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)

    wdbDbgIabrSet (0);			/* clear IABR register */
# if	(CPU == PPC604)
    wdbDbgDabrSet (0);			/* clear DABR register */

    /* clear only the breakpoint bit of the DSISR */

    vxDsisrSet (vxDsisrGet () & ~_PPC_DSISR_BRK);
# endif	/* (CPU == PPC604) */

#elif	(CPU == PPC403)

    wdbDbgDbcrSet (0);				/* clear DBCR register */
    wdbDbgDac1Set (0);				/* clear DAC1 register */
    wdbDbgDac2Set (0);				/* clear DAC2 register */
    wdbDbgIac1Set (0);				/* clear IAC1 register */
    wdbDbgIac2Set (0);				/* clear IAC2 register */
    wdbDbgDbsrSet (_DBSR_HWBP_MSK);		/* clear DBSR register */

#elif   ((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
	 (CPU == PPC85xx))

    wdbDbgDbcr0Set (0);                         /* clear DBCR0 register */
    wdbDbgDbcr1Set (0);                         /* clear DBCR1 register */
# if	((CPU == PPC440) || (CPU == PPC85XX))
    wdbDbgDbcr2Set (0);                         /* clear DBCR2 register */
# endif	/* CPU == PPC440 || CPU == PPC85XX */
    wdbDbgDac1Set (0);                          /* clear DAC1 register */
    wdbDbgDac2Set (0);                          /* clear DAC2 register */
    wdbDbgIac1Set (0);                          /* clear IAC1 register */
    wdbDbgIac2Set (0);                          /* clear IAC2 register */
#if   (CPU != PPC85XX)
    wdbDbgIac3Set (0);                          /* clear IAC3 register */
    wdbDbgIac4Set (0);                          /* clear IAC4 register */
#endif  /* CPU != PPC85XX */
    wdbDbgDbsrSet (_DBSR_HWBP_MSK);             /* clear DBSR register */

#endif	/* PPC5xx | PPC860 : PPC60x : PPC403 : PPC405x | PPC440 : PPC85XX */
    }

#endif	/* DBG_HARDWARE_BP */
