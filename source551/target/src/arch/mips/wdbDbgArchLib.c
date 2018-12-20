/* wdbDbgArchLib.c - MIPS architecture-dependent debugger library */

/* Copyright 1988-2001 Wind River Systems, Inc. */
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
01p,18jul01,sru  add wdbTool variable
01o,16jul01,ros  add CofE comment
01n,02may01,dxc  SPR 64101: Add check for jump delay slot in wdbNpc16Get
01m,16apr01,dxc  SPR 64275: Fix break exception handling
01m,21dec00,pes  Adapt to MIPS32/MIPS64 CPU architectures
01l,30mar00,dra  Fix MIPS16 merge errors.
01k,23sep99,myz  reworked last mod.
01j,08sep99,myz  added mips16 support.  
01h,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
		 protected fpscr checks with #ifndef SOFT_FLOAT.
01h,14jan99,elg  made breakpoints on delay slot work (SPR 24356).
01g,12mar98,dbt  return corresponding error if the hardware breakoint
                 registers are full or if the hardware breakpoint is invalid.
01f,08jan98,dbt  modified for new breakpoint scheme. Added hardware
		 breakpoints support
01e,12dec96,tam  set fpcsr field in wdbArchBreakpoint if necessary (spr #7631).
01d,14nov96,mem  corrected mask of pc used in J and JAL calculations.
01c,20nov96,kkk  added R4650 support.
01b,14jun96,kkk  changed dbg_trap_hander to wdbTrap, fixed wdbGetNpc.
01a,04dec95,mem  written.
*/

/*
DESCRIPTION
This module contains the architecture specific calls needed by the WDB
debug agent.
*/

/* includes */

#include "vxWorks.h"
#include "regs.h"
#include "iv.h"
#include "intLib.h"
#include "ioLib.h"
#include "esf.h"
#include "fppLib.h"
#include "wdb/wdbDbgLib.h"

/* external functions */

extern void	wdbDbgTrap();
extern void	excExcHandle(int vecNum, ESFMIPS * pEsf, REG_SET * pRegs);
extern uint16_t excBreakTypeGet(ESFMIPS *pEsf);

#if     (DBG_HARDWARE_BP)
extern void	wdbDbgRegsGet (DBG_REGS * pDbgReg);
#endif  /* (DBG_HARDWARE_BP) */

/* forward declarations */

LOCAL void wdbDbgArchBreakpoint (int vecNum, ESFMIPS * pInfo, REG_SET * pRegs);
LOCAL void wdbDbgBpStub (int vecNum, ESFMIPS * pInfo, REG_SET * pRegs);
#if     (DBG_HARDWARE_BP)
LOCAL void wdbDbgArchHwBreakpoint (int vecNum, ESFMIPS * pInfo, 
						REG_SET * pRegs);
#endif  /* (DBG_HARDWARE_BP) */

/*
*  This function allows the user to dynamically bind a breakpoint
*  handler to  breakpoints of type 0 - 7.  By default only breakpoints
*  of type zero are handled with the function dbgBreakpoint (see dbgLib).
*  Other types may be used for Ada stack overflow or other such functions.
*  Use the function dbgBpTypeBind to bind a handler for the corresponding
*  breakpoint type.  The installed handler must take the same parameters as
*  excExcHandle (see excLib).
*/

FUNCPTR wdbDbgArchHandler [] =
    {
    (FUNCPTR) wdbDbgArchBreakpoint,
    (FUNCPTR) excExcHandle,
    (FUNCPTR) excExcHandle,
    (FUNCPTR) excExcHandle,
    (FUNCPTR) excExcHandle,
    (FUNCPTR) excExcHandle,
    (FUNCPTR) excExcHandle,
    (FUNCPTR) excExcHandle,
    };
#define NUM_WDB_DBG_ARCH_HANDLERS (sizeof(wdbDbgArchHandler)/sizeof(FUNCPTR))

#ifdef _WRS_MIPS16

/* mips16 register index to 32 bit mode register index conversion array */

LOCAL int reg32Inx[8] = {16,17,2,3,4,5,6,7};

LOCAL INSTR * wdbNpc32Get (REG_SET *);
LOCAL void * wdbNpc16Get (REG_SET *);

#endif

/*****************************************************************************
*
* wdbDbgArchInit - set exception handlers for the break and the trace.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void wdbDbgArchInit(void)
    {
    intVecSet ((FUNCPTR *) INUM_TO_IVEC(IV_BP_VEC),
	       (FUNCPTR) wdbDbgBpStub);

#if 	(DBG_HARDWARE_BP)
    intVecSet ((FUNCPTR *) INUM_TO_IVEC (IV_WATCH_VEC), 
		(FUNCPTR) wdbDbgArchHwBreakpoint);
#endif	/* (DBG_HARDWARE_BP) */
    }

/*******************************************************************************
*
* wdbDbgBpStub - breakpoint handling
*
* Called from "excStub" exception vector handler upon decoding a BREAK
* exception in the CAUSE register.  Upon entry, `a0' contains the exception
* code number, `a1' the exception stack frame pointer, and `a2' points to 
* the saved task registers.
*
* The code value in the actual BREAK instruction hit determines whether
* this exception should be processed by the native debugger or the
* remote (i.e., VME backplane) debugger. A code of zero (0) means native.
*
* NOMANUAL
*/

LOCAL void wdbDbgBpStub 
    (
    int		vecNum,	/* exception vector number */
    ESFMIPS *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to buf containing saved regs */
    )
    {
    uint16_t breakType;	/* type of break point */
    
    breakType = excBreakTypeGet(pEsf);

    if (breakType < NUM_WDB_DBG_ARCH_HANDLERS)
	(wdbDbgArchHandler[breakType]) (vecNum, pEsf, pRegs);
    
#ifdef _WRS_MIPS16
#endif /* _WRS_MIPS16 */
    }

/******************************************************************************
*
* wdbDbgArchBreakpoint - setup to call breakpoint handler.
*
* RETURNS: N/A
*
* NOMANUAL
*/

LOCAL void wdbDbgArchBreakpoint
    (
    int		vecNum,		/* exception vector number */
    ESFMIPS *	pInfo,		/* pointer to esf info saved on stack */
    REG_SET *	pRegs		/* pointer to buf containing saved regs */
    )
    {
#if     (DBG_HARDWARE_BP)

    /* clear debug registers */

    wdbDbgRegsClear ();
#endif	/* (DBG_HARDWARE_BP) */

    /* Provide the cause register value for wdbDbgGetNpc() */

    pRegs->cause = pInfo->cause;

    /*
     * If the breaked instruction is a branch delay slot then the PC is the
     * address of the branch instruction immadiately preceding the delay slot.
     * It must be changed to match with the breakpoint address.
     */

    /* mips16 code does not have branch delay slots.
     * It only has delay slots for jump instructions.
     * 
     * BUG: There are both 32-bit and 16 bit jump instructions on mips16.
     * This code is oversimplified.
     * Should place code here to implement table 6.6 P. 6-31 in TR4101 Technical
     * Manual. This logic is also needed in excArchLib.c (excBreakTypeGet)
     * to retrieve the break instruction correctly. 
     */

    if (pRegs->cause & CAUSE_BD)        /* Branch Delay Slot */
	pRegs->pc++;
		
#ifdef SOFT_FLOAT
    pRegs->fpcsr = 0;
#else   /* SOFT_FLOAT */

    /* Provide the FPCSR register value for wdbDbgGetNpc() */
			     
    if (fppProbe() == OK)
	pRegs->fpcsr = pInfo->fpcsr;
    else
	pRegs->fpcsr = 0;
#endif   /* SOFT_FLOAT */
			      
#ifdef _WRS_R3K_EXC_SUPPORT
     /* restore old sr so it looks like an rfe occured
      * thus allowing interrupts.
      */
     pRegs->sr = (pRegs->sr & ~(SR_KUP|SR_IEP|SR_KUC|SR_IEC)) |
       ((pRegs->sr & (SR_KUO|SR_IEO|SR_KUP|SR_IEP|SR_KUC|SR_IEC)) >> 2);
#else
    /* restore old sr so it looks like an eret occured */ 
    pRegs->sr &= ~SR_EXL;
#endif

    wdbDbgTrap (pRegs->pc, pRegs, (void *) NULL, (void *) NULL, FALSE);
    }

#if	(DBG_HARDWARE_BP)
/******************************************************************************
*
* wdbDbgArchHwBreakpoint - setup to call breakpoint handler.
*
* RETURNS: N/A
*
* NOMANUAL
*/

LOCAL void wdbDbgArchHwBreakpoint
    (
    int		vecNum,		/* exception vector number */
    ESFMIPS	*pInfo,		/* pointer to esf info saved on stack */
    REG_SET 	*pRegs		/* pointer to buf containing saved regs */
    )
    {
    DBG_REGS 	dbgRegs;
    void *	pDbgRegs = &dbgRegs;
#ifdef _WRS_R4650
    UINT32	causeReg;
#endif	/* _WRS_R4650 */

    /* read the debug registers */

    wdbDbgRegsGet (pDbgRegs);

    /* Clear debug registers */

    wdbDbgRegsClear ();

    /* Provide the cause register value for hardware breakpoints handling */

    dbgRegs.cause = pInfo->cause;

#ifdef _WRS_R4650

    /* Clean watch bits in the cause register */

    causeReg = intCRGet ();
    causeReg &= ~0x03000000;
    intCRSet (causeReg);
#endif	/* _WRS_R4650 */

    /* Provide the cause register value for wdbDbgGetNpc() */

    pRegs->cause = pInfo->cause;

    /*
     * If the breaked instruction is a branch delay slot then the PC is the
     * address of the branch instruction immadiately preceding the delay slot.
     * It must be changed to match with the breakpoint address.
     */

    if (pRegs->cause & CAUSE_BD)	/* Branch Delay Slot */
	pRegs->pc++;

    /* Provide the FPCSR register value for wdbDbgGetNpc() */

    if (fppProbe() == OK)
	pRegs->fpcsr = pInfo->fpcsr;
    else
	pRegs->fpcsr = 0;

#ifndef _WRS_R3K_EXC_SUPPORT

    /* Restore old sr so it looks like an eret occured */ 

    pRegs->sr &= ~SR_EXL;
#endif

    wdbDbgTrap(pRegs->pc, pRegs, (void *) NULL, (void *) pDbgRegs, TRUE);
    }
#endif	/* DBG_HARDWARE_BP */

/******************************************************************************
*
* wdbDbgTraceModeSet - lock interrupts and set the trace bit.
*
* Because MIPS has no trace mode, all this routine needs to do is
* lock interrupts for the reg set.
*
* RETURNS: the old int level
*
* NOMANUAL
*/ 

int wdbDbgTraceModeSet
    (
    REG_SET *pRegs
    )
    {
    return intRegsLock (pRegs);
    }

/******************************************************************************
*
* wdbDbgTraceModeClear - restore old int lock level and clear the trace bit.
*
* Because MIPS has no trace mode, all this routine needs to do is
* restore the int mask from the last wdbDbgTraceModeSet().
*
* RETURNS: N/A
*
* NOMANUAL
*/ 

void wdbDbgTraceModeClear
    (
    REG_SET *pRegs,
    int oldSr
    )
    {
    intRegsUnlock (pRegs, oldSr);
    }

#ifdef _WRS_MIPS16

/***************************************************************************
*
* wdbNpcSizeGet - Get the next breakpoint instruction size
*
* Usually the size is 2 in 16 bit mode, and 4 in 32 bit mode. But when program
* jumps from 16 bit mode to 32 bit mode,or other way around, the size should
* be either 4 or 2.
*
*/

int wdbNpcSizeGet
    (
    REG_SET *pRegs              /* pointer to task registers */
    )
    {
    ULONG pc;
    int npcSize;

    pc = (ULONG)(pRegs->pc);

    if (pc & 0x1)
        {
	/* in mips16 mode */

        UINT16 instr16;

	/* defalut size is 2 */

        npcSize = 2;

        pc &= ~0x1;
        instr16 = *(UINT16 *)pc;

        if ( (instr16 & 0xfc00) == 0x1c00)  /* jalx */
          
	    /* jumping to a 32 bit function */

            npcSize = 4;

        else if ( (instr16 & 0xf81f) == 0xe800)
            {
            /* J(AL)R */
            if ((instr16 & 0x7e0) == 0x20)
                {
                /* JR ra instr */

                if ( !((ULONG)(pRegs->gpreg[31]) & 0x1) )
		
		    /* jumping to a 32 bit function */

                    npcSize = 4;
                }
            else
                {
                /* JR rx or JALR ra,rx */

                if (!((pRegs->gpreg[reg32Inx[M16_RX(instr16)]]) & 0x1))

		    /* jumping to a 32 bit function */

                    npcSize = 4;
                }
            }
        }  /* if (pc & 0x1)*/
    else
        {
        /* 32 bit mode */
        ULONG machInstr;

        machInstr = *(ULONG *)pc;

        npcSize = 4;
        if (((machInstr & 0xfc1f07ff) == 0x00000009) ||
            ((machInstr & 0xfc1fffff) == 0x00000008))
            {
            if ( (pRegs->gpreg[(machInstr >> 21) & 0x1f]) & 0x1)

		/* jumping to a 16 bit function */

                npcSize = 2;
            }
        }
    return (npcSize);
    }

/******************************************************************************
*
* wdbGetNpc - get the next pc
*
* If not in the delay slot of a jump or branch instruction,
* the next instruction is always pc+4 (all branch and jump instructions
* have 1 delay slot). Otherwise the npc is the target of the jump or branch.
*
* For branch and jump instructions, the instruction in the delay slot is
* never reported.  The expectation is that a breakpoint will be set on
* the instruction that is returned.  When a resuming from a breakpoint
* hit in a delay slot, execution restarts at the branch or jump.
*
* RETURNS: The next instruction
*
* NOMANUAL
*/

INSTR * wdbDbgGetNpc
    (
    REG_SET *pRegs              /* pointer to task registers */
    )
    {
    INSTR * ret;

    if ((ULONG)(pRegs->pc) & 0x1)
        ret = (INSTR *)wdbNpc16Get(pRegs);
    else
        ret = wdbNpc32Get(pRegs);

    return (ret);
    }

/**************************************************************************
*
* wdbNpc16Get - Get next instruction address running in mips16 mode.
*
*/

LOCAL void * wdbNpc16Get
    (
    REG_SET *pRegs
    )

    {
    UINT16      instr16;
    ULONG       npc;
    ULONG       disp;
    ULONG       extImm;
    ULONG       pc;

    /* mips16 code does not have branch delay slots. If a branch is taken,
     * the instruction that immediately follows the branch(the delay slot
     * instruction) is cancelled.
     * However there is a delay slot for jump instructions. Branch,jump
     * or extended instructions must not be placed in the jump delay slot
     */


    pc = (ULONG)(pRegs->pc) & EPC_PC;

    instr16 = *(UINT16 *)pc;
    extImm  = 0;

    /* if it is a extend instruction, extract the immediate field
     * and advance to the next instruction. The M16_EXTEND_IMM macro
     * works for all extended instructions ***EXCEPT*** EXT-RRI-A
     * format (ADDIU) and EXT-SHIFT format (SHIFT). Since neither
     * of these instructions branch or jump, they are a "don't-care".
     */

    if (M16_INSTR_OPCODE(instr16) == M16_EXTEND_INSTR)
        {
        extImm = M16_EXTEND_IMM(instr16);
        pc += 2;
        instr16 = *(UINT16 *)pc;
        }

    /* default next pc */

    npc = pc + 2;

    switch (M16_INSTR_OPCODE(instr16))
        {
        case M16_B_INSTR: /* B instr */

	    /* It is expected that the bit 5 to bit 10 of the B instruction is
	     * zero when the preceding instruction is EXTEND.
	     */
            disp = (instr16 & (~M16_OPCODE_MASK)) | extImm;

            /* sign(msb of the offset) extended to 32 bit */

            if (!extImm)
                disp = ((int)(disp << 21)) >> 20;
            else
                disp = ((int)(disp << 16)) >> 15;

            npc = disp + pc + 2;

            break;

        case M16_BEQZ_INSTR:    /* BEQZ */
        case M16_BNEZ_INSTR:    /* BNEZ */
            {
            int regNo;

            /* offset and signed extended */

            disp = (instr16 & 0xff) | extImm;
            if (!extImm)
                disp = ((int)(disp << 24)) >> 23;
            else
                disp = ((int)(disp << 16)) >> 15;

            /* convert register index for 16 bit instruction to 32 bit's */

            regNo = reg32Inx[M16_RX(instr16)];

            if ( (pRegs->gpreg[regNo] == 0 &&
                  M16_INSTR_OPCODE(instr16) == M16_BEQZ_INSTR) ||
                 (pRegs->gpreg[regNo] != 0 &&
                  M16_INSTR_OPCODE(instr16) == M16_BNEZ_INSTR) )
                npc = pc + disp + 2;
            }
            break;

        case M16_I8_INSTR:
            if ( (instr16 & 0x0700) == 0x0000 ||
                 (instr16 & 0x0700) == 0x0100 )
                {
                /* BTEQZ or BTNEZ */

                disp = (instr16 & 0xff) | extImm;
                if (!extImm)
                    disp = ((int)(disp << 24)) >> 23;
                else
                    disp = ((int)(disp << 16)) >> 15;

                if ( (pRegs->gpreg[24] == 0 &&
                      (instr16 & 0x0700) == 0x0000) ||
                     (pRegs->gpreg[24] != 0 &&
                      (instr16 & 0x0700) == 0x0100) )
                    npc = disp + pc + 2;

                }
            break;

        case M16_JALNX_INSTR: /* JAL or JALX*/

	    disp = ((*(UINT16 *)pc) << 16) + (*((UINT16 *)pc + 1));
	    disp = M16_JALX_IMM(disp);

            npc  = ((pc + 4) & 0xf0000000) | disp;
            break;

        case M16_RR_INSTR:
            if (!(instr16 & 0x1f))
                {
                /* J(AL)R */

                if ( (instr16 & 0x7e0) == 0x20)
                    /* JR ra instr */

                    npc = (pRegs->gpreg[31]) & 0xfffffffe;
                else
                    /* JR rx or JALR ra,rx */

                    npc = (pRegs->gpreg[reg32Inx[M16_RX(instr16)]]) &
                          0xfffffffe;
                }
            break;
        default:
            break;

        }   /* end switch */

    return ((void *)npc);
    }

#endif /* _WRS_MIPS16 */

#ifndef _WRS_MIPS16
/******************************************************************************
*
* wdbDbgGetNpc - get the next pc
*
* If not in the delay slot of a jump or branch instruction,
* the next instruction is always pc+4 (all branch and jump instructions
* have 1 delay slot). Otherwise the npc is the target of the jump or branch.
*
* For branch and jump instructions, the instruction in the delay slot is
* never reported.  The expectation is that a breakpoint will be set on
* the instruction that is returned.  When a resuming from a breakpoint
* hit in a delay slot, execution restarts at the branch or jump.
*
* RETURNS: The next instruction
*
* NOMANUAL
*/

INSTR *wdbDbgGetNpc 

#else 

LOCAL INSTR * wdbNpc32Get

#endif /* _WRS_MIPS16 */

    (
    REG_SET *pRegs		/* pointer to task registers */
    )
    {
    int	rsVal;
    int	rtVal;
    int	disp;
    INSTR	machInstr;
    ULONG	npc;
    ULONG	pc;

#if	FALSE
    /*
     * If we are in a branch delay slot, the pc has been changed in the
     * breakpoint handler to match with the breakpoint address.
     * It is modified to have its normal value.
     */

    if (pRegs->cause & CAUSE_BD)
    	pRegs->pc--;
#endif	/* FALSE */

    pc = (ULONG) pRegs->pc;
    machInstr = *(INSTR *) pRegs->pc;	/* Get the Instruction */

    /* Default instruction is the next one. */

    npc = pc + 4;

    /*
     * Do not report the instruction in a branch delay slot as the
     * next pc.  Doing so will mess up the WDB_STEP_OVER case as
     * the branch instruction is re-executed.
     */

    /*
     * Check if we are on a branch likely instruction, which will nullify
     * the instruction in the slot if the branch is taken.
     * Also, pre-extract some of the instruction fields just to make coding
     * easier.
     */

    rsVal = pRegs->gpreg[(machInstr >> 21) & 0x1f];
    rtVal = pRegs->gpreg[(machInstr >> 16) & 0x1f];
    disp = ((int) ((machInstr & 0x0000ffff) << 16)) >> 14;
    if ((machInstr & 0xf3ff0000) == 0x41020000)	/* BCzFL  */
	{
	int copId = (machInstr >> 26) & 0x03;
	npc = pc + 8;
	switch (copId)
	    {
	  case 1:
#ifndef SOFT_FLOAT
	    if ((pRegs->fpcsr & FP_COND) != FP_COND)
		npc = disp + pc + 4;
#endif	/* !SOFT_FLOAT */
	    break;
	    }
	}
    else if ((machInstr & 0xf3ff0000) == 0x41030000)	/* BCzTL  */
	{
	int copId = (machInstr >> 26) & 0x03;
	npc = pc + 8;
	switch (copId)
	    {
	  case 1:
#ifndef SOFT_FLOAT
	    if ((pRegs->fpcsr & FP_COND) == FP_COND)
		npc = disp + pc + 4;
#endif	/* !SOFT_FLOAT */
	    break;
	    }
	}
    else if (((machInstr & 0xfc1f0000) == 0x04130000)		/* BGEZALL*/
	     || ((machInstr & 0xfc1f0000) == 0x04030000))	/* BGEZL  */
	{
	if (rsVal >= 0)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if ((machInstr & 0xfc1f0000) == 0x5c000000)	/* BGTZL  */
	{
	if (rsVal > 0)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if ((machInstr & 0xfc1f0000) == 0x58000000)	/* BLEZL  */
	{
	if (rsVal <= 0)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if (((machInstr & 0xfc1f0000) == 0x04120000)		/* BLTZALL*/
	     || ((machInstr & 0xfc1f0000) == 0x04020000))	/* BLTZL  */
	{
	if (rsVal < 0)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if ((machInstr & 0xfc000000) == 0x50000000)	/* BEQL   */
	{
	if (rsVal == rtVal)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if ((machInstr & 0xfc000000) == 0x54000000)	/* BNEL   */
	{
	if (rsVal != rtVal)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if (((machInstr & 0xfc000000) == 0x08000000)	 	/* J    */
	|| ((machInstr & 0xfc000000) == 0x0c000000)) 	/* JAL  */
	npc = ((machInstr & 0x03ffffff) << 2) | (pc & 0xf0000000);
    else if (((machInstr & 0xfc1f07ff) == 0x00000009)	/* JALR */
	     || ((machInstr & 0xfc1fffff) == 0x00000008))	/* JR   */
	npc = pRegs->gpreg[(machInstr >> 21) & 0x1f];
    else if ((machInstr & 0xf3ff0000) == 0x41000000)	/* BCzF   */
	{
	int copId = (machInstr >> 26) & 0x03;
	npc = pc + 8;
	switch (copId)
	    {
	  case 1:
#ifndef SOFT_FLOAT
	    if ((pRegs->fpcsr & FP_COND) != FP_COND)
		npc = disp + pc + 4;
#endif	/* !SOFT_FLOAT */
	    break;
	    }
	}
    else if ((machInstr & 0xf3ff0000) == 0x41010000)	/* BCzT   */
	{
	int copId = (machInstr >> 26) & 0x03;
	npc = pc + 8;
	switch (copId)
	    {
	  case 1:
#ifndef SOFT_FLOAT
	    if ((pRegs->fpcsr & FP_COND) == FP_COND)
		npc = disp + pc + 4;
#endif	/* !SOFT_FLOAT */
	    break;
	    }
	}
    else if ((machInstr & 0xfc000000) == 0x10000000)	/* BEQ    */
	{
	if (rsVal == rtVal)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if (((machInstr & 0xfc1f0000) == 0x04010000)	/* BGEZ   */
	     || ((machInstr & 0xfc1f0000) == 0x04110000))	/* BGEZAL */
	{
	if (rsVal >= 0)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if ((machInstr & 0xfc1f0000) == 0x1c000000)	/* BGTZ   */
	{
	if (rsVal > 0)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if ((machInstr & 0xfc1f0000) == 0x18000000)	/* BLEZ   */
	{
	if (rsVal <= 0)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if (((machInstr & 0xfc1f0000) == 0x04000000)	/* BLTZ   */
	     || ((machInstr & 0xfc1f0000) == 0x04100000))	/* BLTZAL */
	{
	if (rsVal < 0)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else if ((machInstr & 0xfc000000) == 0x14000000)	/* BNE    */
	{
	if (rsVal != rtVal)
	    npc = disp + pc + 4;
	else
	    npc = pc + 8;
	}
    else
	{
	/* normal instruction */
	}
    return (INSTR *) npc;
    }

#if	(DBG_HARDWARE_BP)
/******************************************************************************
*
* wdbDbgHwBpSet - set a data breakpoint register
*
* type is the type of access that will generate a breakpoint.
*
* NOMANUAL
*/

STATUS wdbDbgHwBpSet
    (
    DBG_REGS *  pDbgReg,	/* debug registers */
    UINT32	access,		/* access type */
    UINT32      addr		/* breakpoint addr */
    )
    {
    int status = OK;

    switch (access)
	{
	case BRK_WRITE:
	case BRK_READ:
	case BRK_RW:
#ifndef _WRS_R4650
	    if (pDbgReg->watchLo == 0)
		{
		pDbgReg->watchLo = (K0_TO_PHYS(addr) & ~7) | access;
		pDbgReg->watchHi = 0;
		}
	    else
		status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;

#else
	    if (pDbgReg->dWatch == 0)
		pDbgReg->dWatch = (((UINT32) addr & ~7) | 
					((access << 1) & 0x6));
	    else
		status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;

	case BRK_INST:
	    if (pDbgReg->iWatch == 0)
		pDbgReg->iWatch = ((UINT32) addr & ~3) | 0x1;
	    else
		status = WDB_ERR_HW_REGS_EXHAUSTED;
	    break;
#endif	/* _WRS_R4650 */
	default:
	    status = WDB_ERR_INVALID_HW_BP;
	}
    
    return (status);
    }

/******************************************************************************
*
* wdbDbgHwBpFind - Find the hardware breakpoint
*
* This routines find the type and the address of the address of the
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
    DBG_REGS *	pDbgRegs,
    UINT32 *	pType,		/* return type info via this pointer */
    UINT32 *	pAddr		/* return address info via this pointer */
    )
    {
    int eventFlags;
    int addr = 0;
    int type = 0;

#ifndef _WRS_R4650
    eventFlags = pDbgRegs->cause & 0x00800000;

    if (eventFlags)
	{
	type = (pDbgRegs->watchLo & 0x3) | BRK_HARDWARE;
	addr = PHYS_TO_K0 (pDbgRegs->watchLo & ~0x7);
	}
#else
    eventFlags = pDbgRegs->cause & 0x03000000;

    if (eventFlags & 0x02000000)
	{
	type = ((pDbgRegs->dWatch >> 1) & 0x3) | BRK_HARDWARE;
	addr = pDbgRegs->dWatch & ~0x7;
	}
    else if (eventFlags & 0x01000000)
	{
	type = BRK_INST | BRK_HARDWARE;
	addr = pDbgRegs->iWatch & ~0x3;
	}
#endif	/* _WRS_R4650 */

    if ((addr == 0) && (type == 0))
	return (ERROR);

    *pType = type;
    *pAddr = addr;

    return (OK);
    }

/*******************************************************************************
*
* wdbDbgHwAddrCheck - check the address for the hardware breakpoint.
*
* This routine check the address for the hardware breakpoint.
*
* RETURNS: OK or ERROR if the address is not appropriate.
*
* NOMANUAL
*/

STATUS wdbDbgHwAddrCheck
    (
    UINT32 	addr,		/* instuction pointer */
    UINT32	type,		/* access type */
    FUNCPTR	memProbeRtn	/* memProbe routine */
    )
    {
    UINT32	val;		/* dummy for memProbeRtn */

    if (addr & 0x03)
	return (ERROR);

    switch (type)
        {
        case BRK_WRITE:
        case BRK_READ:
        case BRK_RW:
#ifdef _WRS_R4650
	case BRK_INST:
#endif	/* _WRS_R4650) */
	    if (memProbeRtn ((char *)addr, O_RDONLY, 4, (char *) &val) != OK)
		{
		return (ERROR);
		}
	    break;

	default:
	    break;
        }

    return (OK);
    }

/*******************************************************************************
*
* wdbDbgRegsClear - clear hardware break point registers
*
* This routine clears hardware breakpoint registers.
*
* RETURNS : N/A.
*
* NOMANUAL
*/

void wdbDbgRegsClear
    (
    void
    )
    {
    DBG_REGS dbgRegs;

#ifndef _WRS_R4650
    dbgRegs.watchLo = 0;
    dbgRegs.watchHi = 0;
#else
    dbgRegs.iWatch = 0;
    dbgRegs.dWatch = 0;
#endif	/* _WRS_R4650 */
    wdbDbgRegsSet (&dbgRegs);
    }
#endif	/* (DBG_HARDWARE_BP) */
