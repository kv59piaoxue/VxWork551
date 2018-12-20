/* dsmLib.c - ARM disassembler */

/*
 * Copyright 1991-1998 Advanced RISC Machines Ltd. and Wind River Systems, Inc.
 */
#include "copyright_wrs.h"

/*
modification history
--------------------
01e,04sep98,cdp  make Thumb support dependent on ARM_THUMB.
01d,27oct97,kkk  took out "***EOF***" line from end of file.
01c,10oct97,jpd  tidied.
01b,19jun97,jpd  added Thumb (ARM7TDMI_T) support.
01a,15aug96,jpd  written, based on 680X0 version 03o and also ARM Ltd.'s
		 disassembler sources
*/

/*
This library contains everything necessary to print ARM and Thumb
object code in assembly language format.  The disassembly is done in
native ARM/Thumb format.

The programming interface is via dsmInst(), which prints a single disassembled
instruction, and dsmNbytes(), which reports the size of an instruction.

To disassemble from the shell, use l(), which calls this
library to do the actual work.  See dbgLib() for details.

INTERNAL

This code is very largely based on the ARM Ltd. disassembler code, and so
does not conform to the recommended structure for VxWorks disassemblers.



INCLUDE FILE: dsmLib.h

SEE ALSO: dbgLib
.I "ARM Architecture Reference Manual,"
.I "ARM 7TDMI Data Sheet,"
.I "ARM 710A Data Sheet,"
.I "ARM 810 Data Sheet,"
.I "Digital Semiconductor SA-110 Microprocessor Technical Reference Manual."
*/

#include "vxWorks.h"
#include "dsmLib.h"
#include "string.h"
#include "stdio.h"
#include "errnoLib.h"


/*
 * check that this compiler does sign extension when an int is shifted right
 * because code below relies on its doing so.
 */

#if (((INT32)-1L) >> 1) > 0
#	error right shifting an int does not perform sign extension
#endif

#if (ARM_THUMB)
#define INCLUDE_THUMB_DISASM
#undef  INCLUDE_ARM_DISASM
#else
#undef  INCLUDE_THUMB_DISASM
#define INCLUDE_ARM_DISASM
#endif

/* ---------------- Output Functions --------------------- */

#define outc(h)   (printf("%c",h))
#define outf(f,s) (printf(f,s))
#define outi(n)   outf("#%ld",(unsigned long)n)
#define outx(n)   (printf("0x%lx",(unsigned long)n))
#define outs(s)   (printf("%s", s), (strlen(s)))


/* ---------------- Bit twiddlers ------------------------ */

/*
 * The casts to UINT32 in bit() and bits() are redundant, but required by
 * some buggy compilers.
 */
#define bp(n) (((UINT32)1L<<(n)))
#define bit(n) (((UINT32)(instr & bp(n)))>>(n))
#define bits(m,n) (((UINT32)(instr & (bp(n)-bp(m)+bp(n))))>>(m))
#define ror(n,b) (((n)>>(b))|((n)<<(32-(b)))) /* n right rotated b bits */

/*******************************************************************************
*
* reg - display register name
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void reg
    (
    UINT32	rno,	/* register number */
    int		ch	/* char to display after reg, 0 => do nothing */
    )
    {
    /* Replace "r15" with "pc" */

    if (rno == 15)
	outs("pc");
    else
	outf("r%d", rno);

    if (ch != 0)
	outc(ch);

    return;

    } /* reg() */

/*******************************************************************************
*
* outh - display immediate value in hex
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void outh
    (
    UINT32	n,	/* number to display */
    UINT32	pos	/* whether number is positive */
    )
    {

    /* ARM assembler immediate values are preceded by '#' */

    outc('#');


    if (!pos)
	outc('-');


    /* decimal values by default, precede hex values with '0x' */

    if (n < 10)
	outf("%d", n);
    else
	outx(n);

    return;

    } /* outh() */

/*******************************************************************************
*
* spacetocol9 - tab to column 9
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void spacetocol9
    (
    int	l	/* current column position */
    )
    {
    for (; l < 9 ; l++)
	outc(' ');

    return;

    } /* spacetocol9() */

/*******************************************************************************
*
* outregset - display register set of load/store multiple instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void outregset
    (
    UINT32	instr	/* the value of the instruction */
    )
    {
    BOOL started = FALSE, string = FALSE;
    UINT32 i, first = 0, last = 0;

    /* display the start of list char */

    outc('{');


    /* check for presence of each register in list */

    for (i = 0; i < 16; i++)
	{
	if (bit(i))
	    {
	    /* register is in list */
	    if (!started)
		{
		/* not currently doing a consecutive list of reg numbers */
		reg(i, 0);	/* print starting register */
		started = TRUE;
		first = last = i;
		}
	    else
		/* currently in a list */
		if (i == last+1)
		    {
		    string = TRUE;
		    last = i;
		    }
		else
		    /* not consecutive */
		    {
		    if (i > last+1 && string)
			{
			outc((first == last-1) ? ',' : '-');
			reg(last, 0);
			string = FALSE;
			}
		    outc(',');
		    reg(i, 0);
		    first = last = i;
		    }
	    }
	} /* endfor */

    if (string)
	{
	outc((first == last-1) ? ',' : '-');
	reg(last, 0);
	}

    outc('}');

    return;

    } /* outregset() */

/*******************************************************************************
*
* cond - display condition code of instruction
*
* RETURNS: number of characters written.
*
* NOMANUAL
*
*/

LOCAL int cond
    (
    UINT32	instr
    )
    {
    const char *ccnames = "EQ\0\0NE\0\0CS\0\0CC\0\0MI\0\0PL\0\0VS\0\0VC\0\0"
			  "HI\0\0LS\0\0GE\0\0LT\0\0GT\0\0LE\0\0\0\0\0\0NV";

    return outs(ccnames+4*(int)bits(28,31));

    } /* cond() */

/*******************************************************************************
*
* opcode - display the opcode of an ARM instruction
*
* This routine is also used in the display of a conditional branch ARM
* instruction.
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void opcode
    (
    UINT32	instr,	/* the value of the instruction */
    const char *op,	/* the opcode as a string */
    char	ch	/* any additional suffix char 0 => display nothing */
    )
    {
    int l;

    /* display the opcode */

    l = outs(op);


    /* display any condition code */

    l += cond(instr);


    /* display any suffix character */

    if (ch != 0)
	{
	outc(ch);
	l++;
	}

    /* pad with spaces to column 9 */

    spacetocol9(l);

    return;

    } /* opcode() */


#ifdef INCLUDE_ARM_DISASM

/*******************************************************************************
*
* freg - display FP register name
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void freg
    (
    UINT32	rno,	/* register number */
    int		ch	/* char to display after reg, 0 => do nothing */
    )
    {

    outf("f%d", rno);

    if (ch != 0)
	outc(ch);

    return;

    } /* freg() */

/*******************************************************************************
*
* shiftedreg - display shifted register operand
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void shiftedreg
    (
    UINT32	instr
    )
    {
    char *shiftname = "LSL\0LSR\0ASR\0ROR" + 4*(int)bits(5,6);

    /* display register name */

    reg(bits(0,3), 0); /* offset is a (shifted) reg */


    if (bit(4))
	{
	/* register shift */

	outf(",%s ", shiftname);
	reg(bits(8,11), 0);
	}
    else
	if (bits(5,11) != 0)
	    {
	    /* immediate shift */

	    if (bits(5,11) == 3)
		outs(",RRX");
	    else
		{
		outf(",%s ", shiftname);
		if (bits(5,11) == 1 || bits(5,11) == 2)
		    outi(32L);
		else
		    outi(bits(7,11));
		}
	    }

    return;

    } /* shiftedreg() */

/*******************************************************************************
*
* outAddress - display an address as part of an instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void outAddress
    (
    UINT32	instr,		/* value of instruction */
    UINT32	address,	/* address */
    INT32	offset,		/* any offset part of instruction */
    VOIDFUNCPTR	prtAddress	/* routine to print addresses as symbols */
    )
    {
    if (bits(16,19) == 15 && bit(24) && !bit(25))
	{
	/* pc based, pre, imm */
	if (!bit(23))
	    offset = -offset;
	address = address + offset + 8;
	prtAddress(address);
	}
    else
	{
	outc('[');
	reg(bits(16,19), (bit(24) ? 0 : ']'));
	outc(',');

	if (!bit(25))
	    {
	    /* offset is an immediate */
	    outh(offset, bit(23));
	    }
	else
	    {
	    if (!bit(23))
		outc('-');
	    shiftedreg(instr);
	    }

	if (bit(24))
	    {
	    outc(']');
	    if (bit(21))
		outc('!');
	    }
	}

    return;

    } /* outAddress() */

/*******************************************************************************
*
* generic_cpdo - display generic coprocessor data processing instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void generic_cpdo
    (
    UINT32	instr
    )
    {
    opcode(instr, "CDP", 0);
    outf("p%d,", bits(8,11));
    outx(bits(20,23));
    outc(',');

    outf("c%d,", bits(12,15));	/* CRd */
    outf("c%d,", bits(16,19));	/* CRn */
    outf("c%d,", bits(0,3));	/* CRm */
    outh(bits(5,7),1);

    return;

    } /* generic_cpdo() */

/*******************************************************************************
*
* generic_cprt - display generic coprocessor register transfer instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void generic_cprt
    (
    UINT32	instr
    )
    {
    opcode(instr, (bit(20) ? "MRC" : "MCR"), 0);
    outf("p%d,", bits(8,11));
    outx(bits(21,23));
    outc(',');
    reg(bits(12,15), ',');

    outf("c%d,",bits(16,19));	/* CRn */
    outf("c%d,",bits(0,3));	/* CRm */
    outh(bits(5,7),1);

    return;

    } /* generic_cprt() */

/*******************************************************************************
*
* generic_cpdt - display a generic coprocessor data transfer instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void generic_cpdt
    (
    UINT32	instr,
    UINT32	address,
    VOIDFUNCPTR	prtAddress
    )
    {
    opcode(instr, (bit(20) ? "LDC" : "STC"), (bit(22) ? 'L' : 0));
    outf("p%d,",bits(8,11));
    outf("c%d,",bits(12,15));

    outAddress(instr, address, 4*bits(0,7), prtAddress);

    return;

    } /* generic_cpdt() */

/*******************************************************************************
*
* fp_dt_widthname - display floating-point data transfer width name
*
* RETURNS: the character representing the width specifier
*
* NOMANUAL
*
*/

LOCAL char fp_dt_widthname
    (
    UINT32	instr
    )
    {

    return "SDEP"[bit(15) + 2*bit(22)];

    } /* fp_dt_widthname() */

/*******************************************************************************
*
* fp_widthname - display floating-point width name
*
* RETURNS: the character representing the width name
*
* NOMANUAL
*
*/

LOCAL char fp_widthname
    (
    UINT32	instr
    )
    {

    return "SDEP"[bit(7) + 2*bit(19)];

    } /* fp_widthname() */

/*******************************************************************************
*
* fp_rounding - display floating-point rounding
*
* RETURNS: the character representing the rounding
*
* NOMANUAL
*
*/

LOCAL char *fp_rounding
    (
    UINT32	instr
    )
    {

    return "\0\0P\0M\0Z" + 2*bits(5,6);

    } /* fp_rounding() */

/*******************************************************************************
*
* fp_mfield - display FP field
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void fp_mfield
    (
    UINT32	instr
    )
    {
    UINT32 r = bits(0,2);

    if (bit(3))
	{
	if (r < 6)
	    outi(r);
	else
	    outs((r == 6 ? "#0.5" : "#10"));
	}
    else
	freg(r, 0);

    return;

    } /* fp_mfield() */

/*******************************************************************************
*
* fp_cpdo - display FP op
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void fp_cpdo
    (
    UINT32	instr,
    BOOL *	oddity
    )
    {
    char *opset;
    int l;

    if (bit(15))  /* unary */
	opset = "MVF\0MNF\0ABS\0RND\0SQT\0LOG\0LGN\0EXP\0"
		"SIN\0COS\0TAN\0ASN\0ACS\0ATN\0URD\0NRM";
    else
	opset = "ADF\0MUF\0SUF\0RSF\0DVF\0RDF\0POW\0RPW\0"
		"RMF\0FML\0FDV\0FRD\0POL\0XX1\0XX2\0XX3";

    l = outs(opset + 4*bits(20,23));
    l += cond(instr);
    outc(fp_widthname(instr));
    l++;
    l += outs(fp_rounding(instr));
    spacetocol9(l);
    freg(bits(12,14), ',');  /* Fd */
    if (!bit(15))
	freg(bits(16,18), ',');  /* Fn */
    else
	if (bits(16,18) != 0)
	    /* odd monadic (Fn != 0) ... */
	    *oddity = TRUE;

    fp_mfield(instr);

    return;

    } /* fp_cpdo() */

/*******************************************************************************
*
* fp_cprt - display floating-point register transfer instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void fp_cprt
    (
    UINT32	instr
    )
    {
    int op = (int)bits(20,23);

    if (bits(12,15) == 15)  /* ARM register = pc */
	{
	if ((op & 9) != 9)
	    op = 4;
	else
	    op = (op>>1)-4;
	opcode(instr, "CMF\0\0CNF\0\0CMFE\0CNFE\0???" + 5*op, 0);
	freg(bits(16,18), ',');
	fp_mfield(instr);
	return;
	}
    else
	{
	int l;

	if (op > 7)
	    op = 7;
	l = outs("FLT\0FIX\0WFS\0RFS\0WFC\0RFC\0???\0???" + 4*op);
	l += cond(instr);
	outc(fp_widthname(instr));
	l++;
	l += outs(fp_rounding(instr));
	spacetocol9(l);
	if (bits(20,23) == 0) /* FLT */
	    {
	    freg(bits(16,18), ',');
	    }
	reg(bits(12,15), 0);
	if (bits(20,23) == 1) /* FIX */
	   {
	   outc(',');
	   fp_mfield(instr);
	   }
	}

    return;

    } /* fp_cprt() */

/*******************************************************************************
*
* fp_cpdt - display floating-point data transfer instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void fp_cpdt
    (
    UINT32	instr,
    UINT32	address,
    VOIDFUNCPTR	prtAddress
    )
    {
    if (!bit(24) && !bit(21))
	{
	/* oddity: post and not writeback */
	generic_cpdt(instr, address, prtAddress);
	}
    else
	{
	opcode(instr, (bit(20) ? "LDF" : "STF"), fp_dt_widthname(instr));
	freg(bits(12,14), ',');
	outAddress(instr, address, 4*bits(0,7), prtAddress);

	}

    return;

    } /* fp_cpdt() */

/*******************************************************************************
*
* fm_cpdt - display floating-point load/store multiple instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void fm_cpdt
    (
    UINT32	instr,
    UINT32	address,
    VOIDFUNCPTR	prtAddress
    )
    {
    if (!bit(24) && !bit(21))
	{
	/* oddity: post and not writeback */
	generic_cpdt(instr, address, prtAddress);
	return;
	}
    opcode(instr, (bit(20) ? "LFM" : "SFM"), 0);
    freg(bits(12,14), ',');
    {
	int count = (int)(bit(15) + 2*bit(22));

	outf("%d,", count==0 ? 4: count);
    }
    outAddress(instr, address, 4*bits(0,7), prtAddress);

    return;

    } /* fm_cpdt() */

/*******************************************************************************
*
* disass_32 - disassemble an ARM (32-bit) instruction
*
* RETURNS: size of instruction, in bytes
*
* NOMANUAL
*
*/

LOCAL UINT32 disass_32
    (
    UINT32	instr,		/* the value of the instruction */
    UINT32	address,	/* the address to print before instruction */
    VOIDFUNCPTR	prtAddress	/* routine to print addresses as symbols */
    )
    {
    BOOL oddity = FALSE;

    switch (bits(24,27))
	{

	case 0:
	    if (bit(23) == 1 && bits(4,7) == 9)
		{ /* Long Multiply */
		opcode(instr, bit(21) ? (bit(22) ? "SMLAL" : "UMLAL")
		                      : (bit(22) ? "SMULL" : "UMULL"),
		       bit(20) ? 'S' : 0);
		reg(bits(12,15), ',');
		reg(bits(16,19), ',');
		reg(bits(0,3), ',');
		reg(bits(8,11), 0);
		break;
		}
	/* **** Drop through */
	case 1:
	case 2:
	case 3:
	    if (bit(4) && bit (7))
		{
		if (!bit(5) && !bit(6))
		    {
		    if (bits(22, 27) == 0)
			{
			opcode(instr, (bit(21) ? "MLA" : "MUL"),
			       (bit(20) ? 'S' : 0));
			reg(bits(16,19), ',');
			reg(bits(0,3), ',');
			reg(bits(8,11), 0);
			if (bit(21))
			    {
			    outc(',');
			    reg(bits(12,15), 0);
			    }
			break;
			}
		    if (bits(23,27) == 2 && bits (8, 11) == 0)
			{
			/* Swap */
			opcode(instr, "SWP", (bit(22) ? 'B' : 0));
			reg(bits(12,15), ',');
			reg(bits(0,3), ',');
			outc('[');
			reg(bits(16,19), ']');
			break;
			}
		    }
		else
		    {
		    if (!bit(25) && (bit(20) || !bit(6)))
			{
			int l;
			
			l = outs(bit(20) ? "LDR" : "STR");
			l += cond(instr);
			if (bit(6))
			    {
			    outc('S');
			    outc(bit(5) ? 'H' : 'B');
                	    l += 2;
			    }
			else
			    {
			    outc('H');
			    l++;
			    }
			spacetocol9(l);
			reg(bits(12,15), ',');
			outc('[');
			reg(bits(16,19), 0);
			if (bit(24))
			    outc(',');
			else
			    {
			    outc(']');
			    outc(',');
			    }
			if (bit(22))
			    {
			    outh(bits(0, 3) + (bits(8,11)<<4), bit(23));
			    }
			else
			    {
			    if (!bit(23)) outc('-');
				reg(bits(0,3),0);
			    }
			    if (bit(24))
				{
				outc(']');
				if (bit(21))
				    outc('!');
				}
			break;
			}
		    }
		}

	    if (bits(4, 27) == 0x12fff1)
		{
		opcode(instr, "BX", 0);
		reg(bits(0, 3), 0);
		break;
		}

	    if (instr == 0xe1a00000L)
		{
		opcode(instr, "NOP", 0);
		break;
		}

		{ /* data processing */
		int op = (int)bits(21,24);
		const char *opnames = "AND\0EOR\0SUB\0RSB\0ADD\0ADC\0SBC\0RSC\0"
				      "TST\0TEQ\0CMP\0CMN\0ORR\0MOV\0BIC\0MVN";

		if (op >= 8 && op < 12 && !bit(20))
		    {
		    if ((op & 1) == 0)
			{
			opcode(instr, "MRS", 0);
			reg(bits(12,15), ',');
			if (op == 8)
			    outs("cpsr");
			else
			    outs("spsr");
			oddity = (bits(0, 11) != 0 || bits(16, 19) != 15);
			break;
			}
		    else
			{
			    char *rname = op == 9 ? "cpsr" : "spsr";
			    int rn = (int)bits(16, 19);
			    char *part = rn == 1 ? "ctl" :
			                 rn == 8 ? "flg" :
			                 rn == 9 ? "all" :
			                           "?";

			    opcode(instr, "MSR", 0);
			    outs(rname);
			    outf("_%s,", part);
			    oddity = bits(12,15) != 15;
			}
		    }
		else
		    {
		    int ch = (!bit(20)) ? 0 :
				(op>=8 && op<12) ? (bits(12,15)==15 ? 'P' : 0) :
				'S';
		    opcode(instr, opnames+4*op, ch);

		    if (!(op >= 8 && op < 12))
			{ /* not TST TEQ CMP CMN */
			  /* print the dest reg */
			reg(bits(12,15), ',');
			}

		    if (op != 13 && op != 15)
			{ /* not MOV MVN */
			reg(bits(16,19), ',');
			}
		    }

		if (bit(25))
		    { /* rhs is immediate */
		    int shift = 2 * (int)bits(8,11);
		    INT32 operand = ror(bits(0,7), shift);

		    outh(operand, 1);
		    }
		else
		    { /* rhs is a register */
		    shiftedreg(instr);
		    }
		}
	    break;


	case 0xA:
	case 0xB:
	    opcode(instr, (bit(24) ? "BL" : "B"), 0);
		{
		INT32 offset =
			  (((INT32)bits(0,23))<<8)>>6; /* sign extend and * 4 */

		address += offset + 8;
		prtAddress(address);
		}
	    break;


	case 6:
	case 7:
	/*
	 * Cope with the case where register shift register is specified
	 * as this is an undefined instruction rather than an LDR or STR
	 */
	    if (bit(4))
		{
		outs("Undefined Instruction");
		break;
		}
       /* ***** Drop through to always LDR / STR case */
	case 4:
	case 5:
	    {
	    int l;

	    l = outs(bit(20) ? "LDR" : "STR");
	    l += cond(instr);
	    if (bit(22))
		{
		outc('B');
		l++;
		}
	    if (!bit(24) && bit(21))  /* post, writeback */
		{
		outc('T');
		l++;
		}
	    spacetocol9(l);
	    reg(bits(12,15), ',');
	    outAddress(instr, address, bits(0,11), prtAddress);
	    break;
	    }


	case 8:
	case 9:
	{
	int l;

	l = outs(bit(20) ? "LDM" : "STM");
	l += cond(instr);
	l += outs("DA\0\0IA\0\0DB\0\0IB" + 4*(int)bits(23,24));
	spacetocol9(l);
	reg(bits(16,19), 0);
	if (bit(21))
	    outc('!');
	outc(',');
	outregset(instr);
	if (bit(22)) outc('^');
	    break;
	}


	case 0xF:
	    opcode(instr, "SWI", 0);
		{
		INT32 swino = bits(0,23);
		outx(swino);
		}
	    break;


	case 0xE:
	   if (bit(4)==0)
		{ /* CP data processing */
		switch(bits(8,11))
		    {
		    case 1:
			fp_cpdo(instr, &oddity);
			break;

		    default:
			generic_cpdo(instr);
			break;
		    }
		}
	    else
		{ /* CP reg to/from ARM reg */
		switch (bits(8,11))
		    {
		    case 1:
			fp_cprt(instr);
			break;

		    default:
			generic_cprt(instr);
			break;
		    }
	   }
	   break;


	case 0xC:
	case 0xD:
	    switch (bits(8,11))
		{
		case 1:
		    fp_cpdt(instr, address, prtAddress);
		    break;
		case 2:
		    fm_cpdt(instr, address, prtAddress);
		    break;
		default:
		    generic_cpdt(instr, address, prtAddress);
		    break;
		}
	    break;


	default:
	    outs("EQUD    ");
	    outx(instr);
	    errnoSet (S_dsmLib_UNKNOWN_INSTRUCTION);
	    break;

    } /* endswitch */


    if (oddity)
	outs(" ; (?)");

    outc('\n');

    return 4;

    } /* disass_32() */

#endif /* INCLUDE_ARM_DISASM */

#ifdef INCLUDE_THUMB_DISASM

/*******************************************************************************
*
* t_opcode - display the opcode of a Thumb instruction
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void t_opcode
    (
    const char *	op	/* the opcode as a string */
    )
    {
    int l;

    /* display the opcode */

    l = outs(op);


    /* pad with spaces to column 9 */

    spacetocol9(l);

    return;

    } /* t_opcode() */


/*******************************************************************************
*
* disass_16 - disassemble a Thumb (16-bit) instruction
*
* RETURNS: size of instruction, in bytes
*
* NOMANUAL
*
*/

UINT32 disass_16
    (
    UINT32	instr,		/* the value of the instruction */
    UINT32	instr2,		/* the value of the next instruction */
    UINT32	address,	/* the address to print before instruction */
    VOIDFUNCPTR	prtAddress	/* routine to print addresses as symbols */
    )
    {
    INT32 Rd, Rm, Rn, Ro;
    INT32 imm5, imm8, imm11;
    INT32 L, B;

    Rd = bits(0, 2);
    Rm = bits(3, 5);
    Rn = bits(6, 8);
    Ro = bits(8, 10);
#define imm3 Rn
    imm11 = bits(0, 10);
    imm8 = bits(0, 7);
    imm5 = bits(6, 10);
    L = bit(11);
#define SP L
#define H L
    B = bit(10);
#define S B
#define I B

    switch (bits(11, 15))
	{
	case 3:
	    if (bit(9) == 0 && I && imm3 == 0)
		{
		t_opcode("MOV");
		reg(Rd, ',');
		reg(Rm, 0);
		break;
		}
	    t_opcode(bit(9) ? "SUB" : "ADD");
	    reg(Rd, ',');

	    if (Rd != Rm)
		reg(Rm, ',');
	    I ? outh(imm3, 1) : reg(Rn, 0 );
	    break;


	case 10:
	case 11:
	    t_opcode("STR\0*STRH\0STRB\0LDSB\0LDR\0*LDRH\0LDRB\0LDSH" +
		bits(9, 11) * 5);
	    reg(Rd, ',');
	    outc('[');
	    reg(Rm, ',');
	    reg(Rn, ']');
	    break;


	case 12:
	case 13:
	    imm5 <<= 1;
	case 16:
	case 17:
	    imm5 <<= 1;
	case 14:
	case 15:
	    t_opcode("STR\0*LDR\0*STRB\0LDRB\0STRH\0LDRH\0" +
		(bits(11, 15) - 12) * 5);
	    reg(Rd, ',');
	    outc('[');
	    reg(Rm, ',');
	    outh(imm5, 1);
	    outc(']');
	    break;


	case 0:
	case 1:
	case 2:
	    t_opcode("LSL\0LSR\0ASR" + bits(11, 12) * 4);
	    reg(Rd, ',');
	    if (Rd != Rm)
		reg(Rm, ',');
	    outh(imm5, 1);
	    break;


	case 8:
	    {
	    INT32 op;

	    op = bits(6, 10);
	    if (op < 16)
		{
		t_opcode("AND\0EOR\0LSL\0LSR\0ASR\0ADC\0SBC\0ROR\0"
			 "TST\0NEG\0CMP\0CMN\0ORR\0MUL\0BIC\0MVN" + op * 4);
		}
	    else
		{
		if (op & 2)
		    Rd += 8;
		if (op & 1)
		    Rm += 8;

		switch(op)
		    {
		    case 17:
		    case 18:
		    case 19:
			t_opcode("ADD");
			break;

		    case 21:
		    case 22:
		    case 23:
			t_opcode("CMP");
			break;

		    case 25:
		    case 26:
		    case 27:
			t_opcode("MOV");
			break;

		    case 16:
		    case 20:
		    case 24:
		    case 30:
		    case 31:
			t_opcode("Undefined");
			outc('\n');
			return 2;

		    case 28:
		    case 29:
			t_opcode("BX");
			reg(Rm, 0);
			outc('\n');
			return 2;

		    } /* end switch(op) */

		} /* endelse (op >= 16) */

	    reg(Rd, ',');
	    reg(Rm, 0);
	    break;

	    } /* endcase 8 */


	case 4:
	case 5:
	case 6:
	case 7:
	    /* ADD/SUB/MOV/CMP (large) immediate */

	    t_opcode("MOV\0CMP\0ADD\0SUB" + bits(11, 12) * 4);
	    reg(Ro, ',');
	    outh(imm8, 1);
	    break;


	case 18:
	case 19:
	    /*
	     * LDR/STR SP-relative. ARM disassembler code would try to look
	     * this up, but there seems little point in this. Display as
	     * LDR Ro, [SP, #imm]
	     */

	    t_opcode("STR\0LDR" + L * 4);
	    reg(Ro, ',');
	    imm8 <<= 2;
	    outc('[');
	    reg(13, ',');
	    outh(imm8, 1);
	    outc(']');
	    break;


	case 28:
	    /* unconditional branch */

	    t_opcode("B");
	    imm11 = (imm11 << 21) / (1 << 20);
	    prtAddress(address + imm11 + 4);
	    break;


	case 22:
	case 23:
	    if (!bit(10))
		{
		if (bits(8, 11) != 0)
		    {
		    t_opcode("Undefined");
		    }
		else
		    {
		    imm8 = (imm8 & 0x7f) << 2;
		    t_opcode(bit(7) ? "SUB" : "ADD");
		    reg(13, ',');
		    outh(imm8, 1);
		    }
		}
	    else
		{
		if (bit(9))
		    {
		    t_opcode("Undefined");
		    }
		else
		    {
		    instr &= 0x1ff;
		    if (instr & 0x100)
			{
			instr &= ~0x100;
			if (L)
			    instr |= 0x8000;
			else
			    instr |= 0x4000;
			}
		    t_opcode("PUSH\0POP" + L * 5);
		    outregset(instr);
		    }
		}
	    break;


	case 9:
	    t_opcode("LDR");
	    reg(Ro, ',');
	    imm8 <<= 2;
	    address = (address + 4) & ~3;
	    prtAddress(address + imm8);
	    break;


	case 24:
	case 25:
	    instr &= 0xFF;
	    t_opcode("STMIA\0LDMIA" + L * 6);
	    reg(Ro, '!');
	    outc(',');
	    outregset(instr);
	    break;


	case 20:
	case 21:
	    t_opcode("ADR\0ADD" + SP * 4);
	    reg(Ro, ',');
	    imm8 <<= 2;
	    if (!SP)
		{
		address = (address + 4) & ~3;
		prtAddress(address + imm8);
		}
	    else
		{
		reg(13, ',');
		outh(imm8, 1);
		}
	    break;


	case 26:
	case 27:
	    { /* Either SWI or conditional branch */
	    INT32 op;

	    op = bits(8, 11);
	    if (op == 15)
		{ /* SWI */
		t_opcode("SWI");
		outx(imm8);
		}
	    else
		{
		/* conditional branch: make up ARM instruction to display B?? */

		opcode(op << 28, "B", 0);
		imm8 = (imm8 << 24) / (1 << 23);
		prtAddress(address + imm8 + 4);
		}
	    break;
	    }


	case 30:
	    { /*
	       * BL prefix: the BL Thumb instruction is actually TWO 16-bit
	       * instructions, the BL prefix and the BL itself.
	       */
	    INT32 offset;

	    if ((instr2 & 0xf800) == 0xf800)
		{ /* if next instruction is the BL itself */
		t_opcode("BL");
		offset = instr2 & 0x7ff;
		offset = (((imm11 << 11) | offset) << 10) / (1 << 9);
		prtAddress(address + offset + 4);
		outc('\n');
		return 4; /* Note two 16-bit instructions */
		}
	    else
		{ /* BL prefix, not followed by BL: not defined */
		t_opcode("first half of BL instruction");
		}
	    break;
	    }


	case 31:
	    /*
	     * BL suffix, but we should already have dealt with it, if
	     * preceded by a BL prefix.
	     */
	    t_opcode("second half of BL instruction");
	    break;


	default:
	    t_opcode("Undefined");
	    break;

	} /* endswitch */

    outc('\n');

    return 2;

    } /* disass_16() */

#undef imm3
#undef SP
#undef S
#undef H
#undef H1
#undef H2

#endif

/*******************************************************************************
*
* nPrtAddress - print addresses as numbers
*
* RETURNS: N/A
*
* NOMANUAL
*
*/

LOCAL void nPrtAddress
    (
    int	address
    )
    {
    printf ("0x%x", address);
    }

/*******************************************************************************
*
* dsmInst - disassemble and print a single instruction
*
* This routine disassembles and prints a single instruction on standard
* output.  The function passed as parameter <prtAddress> is used to print any
* operands that might be construed as addresses.  The function could be a
* subroutine that prints a number or looks up the address in a symbol table.
* The disassembled instruction will be prepended with the address passed as
* a parameter.
*
* ADDRESS-PRINTING ROUTINE
* Many assembly language operands are addresses.  In order to print these
* addresses symbolically, dsmInst() calls a user-supplied routine, passed as a
* parameter, to do the actual printing.  The routine should be declared as:
* .CS
*    void prtAddress (address)
*        int address;	/@ address to print @/
* .CE
*
* When called, the routine prints the address on standard output in either
* numeric or symbolic form.  For example, the address-printing routine used
* by l() looks up the address in the system symbol table and prints the
* symbol associated with it, if there is one.  If not, the routine prints the
* address as a hex number.
*
* If the <prtAddress> argument to dsmInst() is NULL, a default print routine is
* used, which prints the address as a hexadecimal number.
*
* The directive EQUD (declare word) is printed for unrecognized instructions.
*
* RETURNS : The size of the instruction in units of sizeof(INSTR).
*/

int dsmInst
    (
    FAST INSTR *	binInst,	/* Pointer to the instruction */
    int			address,	/* Address prepended to instruction */
    VOIDFUNCPTR		prtAddress	/* Address printing function */
    )
    {
#ifdef INCLUDE_THUMB_DISASM
    UINT16 instr2 = 0;
#endif

    /* If no address printing function has been supplied, use default */

    if (prtAddress == NULL)
	prtAddress = nPrtAddress;


    /* Print the address first, then the instruction in hex */

#ifdef INCLUDE_ARM_DISASM
    printf("%08x  %08x  ", address, (UINT32)*binInst);

    return disass_32((UINT32)*binInst, (UINT32)address, prtAddress) /
                                                                 sizeof(INSTR);
#endif

#ifdef INCLUDE_THUMB_DISASM
    if (INSTR_IS((*(UINT16 *)binInst), T_BL0))
	{
	instr2 = *(((UINT16 *)binInst) + 1);
	if (INSTR_IS(instr2, T_BL1))
	    {
	    /*
	     * Instruction is a BL: i.e. this instruction is a BL
	     * prefix and the next instruction is the BL itself. So, this
	     * instruction is effectively 32-bits long. Get the next 16-bit
	     * half of the instruction and display all of it as a 32-bit int.
	    */
	    printf("%08x  %04x%04x  ", address, instr2, *(UINT16 *)binInst);
	    }
	else
	    /* BL prefix not followed by BL suffix */
	    printf("%08x  %04x      ", address,  *(UINT16 *)binInst);
	}
    else
	/* Normal (16-bit) Thumb instruction */
	printf("%08x  %04x      ", address,  *(UINT16 *)binInst);

    return disass_16((UINT32)(*(UINT16 *)binInst), (UINT32)instr2,
    			(UINT32)address, prtAddress) / sizeof(INSTR);
#endif

    } /* dsmInst() */

/*******************************************************************************
*
* dsmNbytes - determine the size of an instruction
*
* This routine reports the size, in bytes, of an instruction.
*
* RETURNS:
* The size of the instruction, or
* 0 if the instruction is unrecognized.
*
*/

int dsmNbytes
    (
    FAST INSTR *	binInst	/* Pointer to the instruction */
    )
    {

#if (ARM_THUMB)
    return INSTR_IS (*binInst, T_BL0) ? 2 * sizeof(INSTR) : sizeof(INSTR);
#else
    return sizeof (INSTR);
#endif

    } /* dsmNbytes() */
