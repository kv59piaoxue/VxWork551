/* dbgArmLib.c - ARM-specific debug routines for dbg and wdb */

/* Copyright 1996-1998 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01h,24may01,h_k  fixed reloc to INT32 from UINT32 for BL in Thumb
01g,23may01,h_k  fixed sign extention for BL in Thumb
01f,04sep98,cdp  make Thumb support dependent on ARM_THUMB.
01e,27oct97,kkk  took out "***EOF***" line from end of file.
01d,23oct97,cdp  make thumbGetNpc() return bit zero clear for all opcodes.
01c,08oct97,cdp  thumbInstrChangesPc(): clear bit zero of PC before fetching
		 instruction; return false for second half of BL;
		 make thumbGetNpc() return rn when PC is at BL _call_via_rn.
01b,15apr97,cdp  added Thumb (ARM7TDMI_T) support.
01a,08aug96,cdp  created by splitting wdbArchLib.c
*/

/*
DESCRIPTION
This module contains some ARM-specific functions used by dbgArchLib.c,
trcLib.c and wdbArchLib.c. They are in a separate file so that they can be
excluded from the image if neither dbg nor wdb is enabled. Putting them here
also saves having to maintain separate versions in parallel.
*/


#include "vxWorks.h"
#include "regs.h"


/*
 * check that this compiler does sign extension when an int is shifted right
 * because a lot of the code below relies on its doing so.
 */

#if (((INT32)-1L) >> 1) > 0
#	error right shifting an int does not perform sign extension
#endif


#define BIT(n) ((UINT32)1U << (n))
#define BITSET(x,n) (((UINT32)(x) & (1U<<(n))) >> (n))
#define BITS(x,m,n) (((UINT32)((x) & (BIT(n) - BIT(m) + BIT(n)))) >> (m))

/* externals */

#if (ARM_THUMB)
extern int _call_via_r0 (void);
extern int _call_via_r1 (void);
extern int _call_via_r2 (void);
extern int _call_via_r3 (void);
extern int _call_via_r4 (void);
extern int _call_via_r5 (void);
extern int _call_via_r6 (void);
extern int _call_via_r7 (void);
extern int _call_via_r8 (void);
extern int _call_via_r9 (void);
extern int _call_via_sl (void);
extern int _call_via_fp (void);
extern int _call_via_ip (void);
extern int _call_via_lr (void);
#endif


/* locals */

#if (ARM_THUMB)
/*
 * call_via_tbl is used to determine whether a BL is to one of the call_via_rn
 * functions (we can't guarantee we have a symbol table in which we can
 * look up an address.
 */
LOCAL FUNCPTR call_via_tbl[] =
    {
    _call_via_r0,
    _call_via_r1,
    _call_via_r2,
    _call_via_r3,
    _call_via_r4,
    _call_via_r5,
    _call_via_r6,
    _call_via_r7,
    _call_via_r8,
    _call_via_r9,
    _call_via_sl,
    _call_via_fp,
    _call_via_ip,
    _call_via_lr
    };
#endif

/*
 * ccTable is used to determine whether an instruction will be executed,
 * according to the flags in the PSR and the condition field of the
 * instruction. The table has an entry for each possible value of the
 * condition field of the instruction. Each bit indicates whether a particular
 * combination of flags will cause the instruction to be executed. Since
 * ther are four flags, this makes 16 possible TRUE/FALSE values.
 */
LOCAL UINT32 ccTable[] =
    {
    0xF0F0, 0x0F0F, 0xCCCC, 0x3333, 0xFF00, 0x00FF, 0xAAAA, 0x5555,
    0x0C0C, 0xF3F3, 0xAA55, 0x55AA, 0x0A05, 0xF5FA, 0xFFFF, 0x0000
    };

#if (!ARM_THUMB)
/*******************************************************************************
*
* armShiftedRegVal - calculate value of shifted register specified in opcode
*
*/

LOCAL UINT32 armShiftedRegVal
    (
    REG_SET *	pRegs,		/* pointer to task registers */
    UINT32	instr,		/* machine instruction */
    int		cFlag		/* value of carry flag */
    )
    {
    UINT32 res, shift, rm, rs, shiftType;

    rm = BITS(instr, 0, 3);
    shiftType = BITS(instr, 5, 6);

    if (BITSET(instr, 4))
	{
	rs = BITS(instr, 8, 11);
	shift = (rs == 15 ? (UINT32)pRegs->pc + 8 : pRegs->r[rs]) & 0xFF;
	}
    else
	shift = BITS(instr, 7, 11);

    res = rm == 15
		? (UINT32)pRegs->pc + (BITSET(instr, 4) ? 12 : 8)
		: pRegs->r[rm];

    switch (shiftType)
	{
	case 0:		/* LSL */
	    res = shift >= 32 ? 0 : res << shift;
	    break;

	case 1:		/* LSR */
	    res = shift >= 32 ? 0 : res >> shift;
	    break;

	case 2:		/* ASR */
	    if (shift >= 32)
		shift = 31;
	    res = (res & 0x80000000L) ? ~((~res) >> shift) : res >> shift;
	    break;

	case 3:		/* ROR */
	    shift &= 31;
	    if (shift == 0)
		res = (res >> 1) | (cFlag ? 0x80000000L : 0);
	    else
		res = (res >> shift) | (res << (32 - shift));
	    break;
	}
    return res;

    } /* armShiftedRegVal() */

#endif


#if (ARM_THUMB)
/*******************************************************************************
*
* thumbGetNpc - get the address of the next instruction to be executed
*
* RETURNS: address of the next instruction to be executed.
*
* INTERNAL
* This function must be passed the instruction rather than using the one
* pointed to by pRegs->pc as the latter may have been replaced by a breakpoint
* instruction.
*/

INSTR * thumbGetNpc
    (
    INSTR	instr,			/* the current instruction */
    REG_SET *	pRegs			/* pointer to task registers */
    )
    {
    UINT32		pc;		/* current program counter */
    UINT32 		nPc;		/* next program counter */

    pc = (UINT32)pRegs->pc & ~1;	/* current PC as a UINT32 */
    nPc = pc + 2;			/* Thumb default */


    /*
     * Now examine the instruction
     * Following code is derived from the ARM symbolic debugger.
     */

    switch (BITS(instr, 12, 15))
	{
	case 0x0:
	case 0x1:
	case 0x2:
	case 0x3:
	case 0x5:
	case 0x6:
	case 0x7:
	case 0x8:
	case 0x9:
	case 0xA:
	case 0xC:
	    /* no effect on PC - next instruction executes */
	    break;

	case 4:
	    if (BITS(instr, 7, 11) == 0x0E)
		{
		/* BX */
		int rn;

		rn = BITS(instr, 3, 6);
		nPc = rn == 15 ? pc + 4 : pRegs->r[rn];
		break;
		}

	    if (BITSET(instr, 7) && (BITS(instr, 0, 11) & 0xC07) == 0x407)
		{
		/* do something to pc */
		int rn;
		UINT32 operand;

		rn = BITS(instr, 3, 6);
		operand = rn == 15 ? pc + 4 : pRegs->r[rn];
		switch (BITS(instr, 8, 9))
		    {
		    case 0:		/* ADD */
			nPc = pc + 4 + operand;
			break;
		    case 1:		/* CMP */
			break;
		    case 2:		/* MOV */
			nPc = operand;
			break;
		    case 3:		/* BX - already handled */
			break;
		    }
		}
	    break;

	case 0xB:
	    if (BITS(instr, 8, 11) == 0xD)
		{
		/* POP {rlist, pc} */
		INT32 offset = 0;
		UINT32 regList, regBit;

		for (regList = BITS(instr, 0, 7); regList != 0;
						regList &= ~regBit)
		    {
		    regBit = regList & (-regList);
		    offset += 4;
		    }
		nPc = *(UINT32 *)(pRegs->r[13] + offset);

		/* don't check for new pc == pc like ARM debugger does */
		}
	    break;

	case 0xD:
	    {
	    /* SWI or conditional branch */
	    UINT32 cond;
	    
	    cond = (instr >> 8) & 0xF;
	    if (cond == 0xF)
		break;	/* SWI */

	    /* Conditional branch
	     * Use the same mechanism as armGetNpc() to determine whether
	     * the branch will be taken
	     */
	    if (((ccTable[cond] >> (pRegs->cpsr >> 28)) & 1) == 0)
		break;	/* instruction will not be executed */

	    /* branch will be taken */
	    nPc = pc + 4 + (((instr & 0x00FF) << 1) |
		    (BITSET(instr, 7)  ? 0xFFFFFE00 : 0));
	    }
	    break;

	case 0xE:
	    if (BITSET(instr, 11) == 0)
		/* Unconditional branch */
		nPc = pc + 4 + (((instr & 0x07FF) << 1) |
			(BITSET(instr, 10) ? 0xFFFFF000 : 0));
	    break;

	case 0xF:
	    /* BL */
	    if (BITSET(instr, 11))
		{
		/* second half of BL - PC should never be here */

		nPc = pRegs->r[14] + ((instr & 0x07FF) << 1);
		}
	    else
		{
		/* first half of BL */

		UINT32 nextBit;
		UINT i;
		INT32 reloc;

		nextBit = *(UINT16 *)(pc + 2);
		if ((nextBit & 0xF800) != 0xF800)
		    /* Something strange going on */
		    break;

		reloc = (INT32)(((instr & 0x7FF) << 12) |
			((nextBit & 0x7FF) << 1));
		reloc = (reloc ^ 0x00400000) - 0x00400000; /* sign extend */

		nPc = pc + 4 + reloc;

		/*
		 * if it's a call to a call_via_rn function, make the
		 * next PC the contents of the register being used
		 * (otherwise the kernel will halt)
		 */ 

		for (i = 0; i < (sizeof(call_via_tbl) / sizeof(FUNCPTR)); ++i)
		    if (nPc == ((UINT32)(call_via_tbl[i]) & ~1))
			break;

		if (i < (sizeof(call_via_tbl) / sizeof(FUNCPTR)))
		    /* address matches one of the call_via_rn functions */
		    nPc = pRegs->r[i];
		}
	    break;

	} /* switch */

    return (INSTR *)((UINT32)nPc & ~1);

    } /* thumbGetNpc() */

#else	/* (ARM_THUMB) */

/*******************************************************************************
*
* armGetNpc - get the address of the next instruction to be executed
*
* RETURNS: address of the next instruction to be executed.
*
* INTERNAL
* This function must be passed the instruction rather than using the one
* pointed to by pRegs->pc as the latter may have been replaced by a breakpoint
* instruction.
*/

INSTR * armGetNpc
    (
    INSTR	instr,			/* the current instruction */
    REG_SET *	pRegs			/* pointer to task registers */
    )
    {
    UINT32		pc;		/* current program counter */
    UINT32 		nPc;		/* next program counter */

    /*
     * Early versions of this file looked at the PSR to determine whether the
     * CPU was in ARM state or Thumb state and decode the next instruction
     * accordingly. This has been removed since there is to be no support for
     * ARM/Thumb interworking.
     */


    pc = (UINT32)pRegs->pc;	/* current PC as a UINT32 */
    nPc = pc + 4;		/* default */


    /*
     * Now examine the instruction
     * First, check the current condition codes against the condition
     * field of the instruction since, if this instruction is not going
     * to be executed, we can return immediately
     *
     * The following code is a translation of the code supplied by ARM
     * for instruction decoding (EAN-26). Note that this version, unlike
     * the original assembly language version cannot generate unaligned
     * accesses which might be faulted by some systems.
     *
     * Briefly, there are 16 entries in ccTable, one for each possible
     * value of the condition part of an instruction. Each entry has one
     * bit for each possible value of the flags in the PSR. The table
     * entry is extracted using the condition part of the instruction and
     * the bits are indexed using the value obtained by extracting the
     * flags from the PSR. If the bit so obtained is 1, the instruction
     * will be executed.
     */

    if (((ccTable[(instr >> 28) & 0xF] >> (pRegs->cpsr >> 28)) & 1) == 0)
	return (INSTR *)nPc;	/* instruction will not be executed */


    /*
     * This instruction WILL be executed so look at its type
     * We're looking for anything that affects the PC e.g.
     *    B
     *    BL
     *    any data processing op where PC is the destination
     *    any LDR with the PC as the destination
     *	  any LDM with the PC in the list of registers to be loaded
     *
     * Following code is derived from the ARM symbolic debugger.
     */

    switch (BITS(instr, 24, 27))
	{
	case 1:		/* check for halfword or signed byte load to PC */
	    if (BITSET(instr, 4) && BITSET(instr, 7) && BITSET(instr, 20) &&
		    BITS(instr, 5, 6) != 0 && BITS(instr, 12, 15) == 15)
		break;		/* bad instruction */

	    /* FALL THROUGH */
	
	case 0:	/* data processing */
	case 2:
	case 3:
	    {
	    UINT32 rn, op1, op2, cFlag;

	    if (BITS(instr, 12, 15) != 15)	/* Rd */
		/* operation does not affect PC */
		break;

	    if (BITS(instr, 22, 25) == 0 && BITS(instr, 4, 7) == 9)
		/* multiply with PC as destination not allowed */
		break;

	    if (BITS(instr, 4, 23) == 0x2FFF1)
		{
		/* BX */
		rn = BITS(instr, 0, 3);
		nPc = (rn == 15 ? pc + 8 : pRegs->r[rn]) & ~1;
		break;
		}

	    cFlag = BITSET(pRegs->cpsr, 29);
	    rn = BITS(instr, 16, 19);
	    op1 = rn == 15 ? pc + 8 : pRegs->r[rn];

	    if (BITSET(instr, 25))
		{
		UINT32 immVal, rotate;

		immVal = BITS(instr, 0, 7);
		rotate = 2 * BITS(instr, 8, 11);
		op2 = (immVal >> rotate) | (immVal << (32 - rotate));
		}
	    else
		op2 = armShiftedRegVal(pRegs, instr, cFlag);

	    switch (BITS(instr, 21, 24))
		{
		case 0x0:	/* AND */
		    nPc = op1 & op2;
		    break;
		case 0x1:	/* EOR */
		    nPc = op1 ^ op2;
		    break;
		case 0x2:	/* SUB */
		    nPc = op1 - op2;
		    break;
		case 0x3:	/* RSB */
		    nPc = op2 - op1;
		    break;
		case 0x4:	/* ADD */
		    nPc = op1 + op2;
		    break;
		case 0x5:	/* ADC */
		    nPc = op1 + op2 + cFlag;
		    break;
		case 0x6:	/* SBC */
		    nPc = op1 - op2 + cFlag;
		    break;
		case 0x7:	/* RSC */
		    nPc = op2 - op1 + cFlag;
		    break;
		case 0x8:	/* TST */
		case 0x9:	/* TEQ */
		case 0xa:	/* CMP */
		case 0xb:	/* CMN */
		    break;
		case 0xc:	/* ORR */
		    nPc = op1 | op2;
		    break;
		case 0xd:	/* MOV */
		    nPc = op2;
		    break;
		case 0xe:	/* BIC */
		    nPc = op1 & ~op2;
		    break;
		case 0xf:	/* MVN */
		    nPc = ~op2;
		    break;
		}
	    }
	    break;

	case 4:		/* data transfer */
	case 5:
	case 6:
	case 7:
	    if (BITSET(instr, 20) && BITS(instr, 12, 15) == 15 &&
		!BITSET(instr, 22))
		    /* load, PC and not a byte load */
		{
		UINT32 rn, cFlag, base;
		INT32 offset;

		rn = BITS(instr, 16, 19);
		base = rn == 15 ? pc + 8 : pRegs->r[rn];
		cFlag = BITSET(pRegs->cpsr, 29);
		offset = BITSET(instr, 25)
			    ? armShiftedRegVal(pRegs, instr, cFlag)
			    : BITS(instr, 0, 11);

		if (!BITSET(instr, 23))	/* down */
		    offset = -offset;

		if (BITSET(instr, 24))	/* pre-indexed */
		    base += offset;

		nPc = *(INSTR *)base;

		/*
		 * don't check for nPc == pc like the ARM debugger does but
		 * let the higher level (or user) notice.
		 */
		}
	    break;

	case 8:
	case 9:		/* block transfer */
	    if (BITSET(instr, 20) && BITSET(instr, 15))	/* loading PC */
		{
		UINT32 rn;
		INT32 offset = 0;

		rn = BITS(instr, 16, 19);
		if (BITSET(instr, 23))	/* up */
		    {
		    UINT32 regBit, regList;

		    for (regList = BITS(instr, 0, 14); regList != 0;
							regList &= ~regBit)
			{
			regBit = regList & (-regList);
			offset += 4;
			}
		    if (BITSET(instr, 24))	/* preincrement */
			offset += 4;
		    }
		else			/* down */
		    if (BITSET(instr, 24))	/* predecrement */
			offset = -4;

		nPc = *(UINT32 *)(pRegs->r[rn] + offset);

		/*
		 * don't check for nPc == pc like the ARM debugger does but
		 * let the higher level (or user) notice.
		 */
		}
	    break;

	case 0xA:	/* branch */
	case 0xB:	/* branch & link */
	    /*
	     * extract offset, sign extend it and add it to current PC,
	     * adjusting for the pipeline
	     */
	    nPc = pc + 8 + ((INT32)(instr << 8) >> 6);
	    break;

	case 0xC:
	case 0xD:
	case 0xE:           /* coproc ops */
	case 0xF:           /* SWI */
	    break;
	}

    return (INSTR *)nPc;


    } /* armGetNpc() */

#endif	/* (ARM_THUMB) */


#if (ARM_THUMB)
/*******************************************************************************
*
* thumbInstrChangesPc - determine if current instruction changes PC
*
* RETURNS: TRUE if the current instruction changes the PC
*
*/

BOOL thumbInstrChangesPc
    (
    INSTR * pc			/* pointer to instruction */
    )
    {
    INSTR instr;		/* the instruction, itself */
    BOOL res;

    pc = (INSTR *)((UINT32)pc & ~1);	/* align pc */
    instr = *pc;		/* get instruction */
    res = FALSE;		/* assume PC is not affected */


    /*
     * Examine the instruction to determine whether it changes the PC
     * other than in the usual incremental fashion. Note that we don't have
     * the CPSR value so we just assume the instruction will be executed.
     *
     * The following code is a cut-down version of the code used by
     * thumbGetNpc (above).
     */

    switch (BITS(instr, 12, 15))
	{
	case 0x0:
	case 0x1:
	case 0x2:
	case 0x3:
	case 0x5:
	case 0x6:
	case 0x7:
	case 0x8:
	case 0x9:
	case 0xA:
	case 0xC:
	    /* no effect on PC - next instruction executes */
	    break;

	case 4:
	    if (BITS(instr, 7, 11) == 0x0E)
		res = TRUE;	/* BX */
	    else
		if (BITSET(instr, 7) &&
		    (BITS(instr, 0, 11) & 0xC07) == 0x407 &&
		    BITS(instr, 8, 9) != 1)
		    res = TRUE;	/* does something to PC and is not CMP */
	    break;

	case 0xB:
	    if (BITS(instr, 8, 11) == 0xD)
		res = TRUE;	/* POP {rlist, pc} */
	    break;

	case 0xD:
	    if (((instr >> 8) & 0xF) != 0xF)
		res = TRUE;	/* conditional branch, not SWI */
	    break;

	case 0xE:
	    if (BITSET(instr, 11) == 0)
		res = TRUE;	/* unconditional branch */
	    break;

	case 0xF:
	    if (BITSET(instr, 11) == 0)
		res = TRUE;	/* first half of BL */
	    break;

	} /* switch */

    return res;

    } /* thumbInstrChangesPc() */

#else	/* (ARM_THUMB) */

/*******************************************************************************
*
* armInstrChangesPc - determine if current instruction changes PC
*
* RETURNS: TRUE if the current instruction changes the PC
*
*/

BOOL armInstrChangesPc
    (
    INSTR * pc			/* pointer to instruction */
    )
    {
    UINT32 instr;		/* the instruction, itself */
    BOOL res;


    instr = *pc;		/* get instruction */
    res = FALSE;		/* assume PC is not affected */


    /*
     * Examine the instruction to determine whether it changes the PC
     * other than in the usual incremental fashion. Note that we don't have
     * the CPSR value so we just assume the instruction will be executed.
     *
     * The following code is a cut-down version of the code used by
     * armGetNpc (above).
     */


    switch (BITS(instr, 24, 27))
	{
	case 0:	/* data processing */
	case 1:	/* includes signed byte/halfword loads */
	case 2:
	case 3:	/* includes MUL, BX */
	    if (BITS(instr, 12, 15) == 15)	/* Rd */
		res = TRUE;
	    break;

	case 4:		/* data transfer */
	case 5:
	case 6:
	case 7:
	    if (BITSET(instr, 20) && BITS(instr, 12, 15) == 15 &&
		!BITSET(instr, 22))
		    /* load, PC and not a byte load */
		res = TRUE;
	    break;

	case 8:
	case 9:		/* block transfer */
	    if (BITSET(instr, 20) && BITSET(instr, 15))	/* loading PC */
		res = TRUE;
	    break;

	case 0xA:	/* branch */
	case 0xB:	/* branch & link */
	    res = TRUE;
	    break;

	case 0xC:
	case 0xD:
	case 0xE:           /* coproc ops */
	case 0xF:           /* SWI */
	    break;
	}

    return res;

    } /* armInstrChangesPc() */

#endif	/* (ARM_THUMB) */
