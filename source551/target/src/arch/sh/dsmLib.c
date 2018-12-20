/* dsmLib.c - SH disassembler */

/* Copyright 1994-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02f,21feb02,h_k  fixed disassembler for "movx.w Da,@Ax*", "movy.w Da,@Ay*" and
                 "movy.w @Ay*,Dy" (SPR #73521).
02e,30oct01,jn   use symFindSymbol for symbol lookup (SPR #7453)
02d,29oct01,h_k  changed .word to .short for showing data length correctly in
                 Diab environment (SPR #69837).
02c,23nov00,hk   added ocbi, ocbp, ocbwb, and movca.l for SH7750.
02b,14nov00,zl   renamed some routines. Corrected dsmNBytes(), removed 
                 obsolete dsmCheck().
02a,24oct00,hk   added termination entry to instFpp[]. changed NULL to 0 for
		 non-pointer elements. added itComplete case to prtArgsFpp.
01z,17oct00,csi  Fixing the movs.l for disassembler
01y,13oct00,csi  Modification for DSP/FP disassemble
01x,15sep00,csi  Modification for DSP/FP disassemble
01w,26jun00,hk   changed to use disassembler in exception context.
		 fixed machine code for fschg/frchg.
01v,08jun99,zl   added SH4 (SH7750) graphics support instructions
01u,08mar99,hk   merged support for DSP & FPU.
01t,30oct98,kab  fix DSP psha insn.
01s,08aug98,kab  fix DSP movx insn.
01r,08jun98,knr  added support for SH7410.
01q,08may98,jmc  added support for SH-DSP and SH3-DSP.
01q,16jul98,st   added SH7750 support (only for SH7700 instructions).
01r,15jun98,hk   tweaked FPU instruction types.
01q,21nov97,st   added FPU instructions in inst table & prtArgs().
01p,07mar97,hk   changed PC/GBR relative offset display to hex. changed to use
                 lower-case letter. changed DC.W to .word. left shifted mnemonic
                 position. fixed PC relative operand display to 32bits.
01o,29jul96,hk   fixed 'mova' address display.
01n,21jun96,hk   added CPU==SH7700 control, fixed binary code typo in inst[]
		 and prtArgs(), changed itBraDispRn to itBraDispRm.
01m,20may96,ja   added new instructions in inst table & prtArgs().
01l,28jun95,hk   unified unknown operand printing to prtUnknownOperand().
01k,08mar95,hk   improved expression for a sign extended immediate value.
01j,30jan95,hk   changed itImmToRn display to hex style. copyright year 1995.
		 sign extend for "mov.w @(disp,pc),rn".
01i,13jan95,hk   fixed a word operand display bug in prtArgs().
01h,25dec94,hk   added dsmCheck() for dbgArchLib.
01g,25dec94,hk   added slot instruction indicator. improved address printing.
01f,08dec94,hk   modifying for better branch displacement display.
01e,06dec94,hk   modified itImmToRn case in prtArgs. #244 should be #-12.
01d,03dec94,hk   modified prtArgs() for itGetRnAtDispPc.
01c,01dec94,hk   added archPortKit docs. added dsmNbytes().
01b,26nov94,hk   fixed compilation error and warnings.
01a,25nov94,hk   written based on mc68k 03l.
*/

/*
This library contains everything necessary to print SH object code in
assembly language format.  The disassembly is done in Hitachi format.

The programming interface is via dsmInst(), which prints a single disassembled
instruction, and dsmNbytes(), which reports the size of an instruction.

To disassemble from the shell, use l(), which calls this
library to do the actual work.  See dbgLib() for details.

INCLUDE FILE: dsmLib.h

SEE ALSO: dbgLib

INTERNAL
The disassembler allows symbolic debugging at the assembly-language level on the
target. Header file definitions and structures supplemented with a few functions
are used to map hexadecimal values into user-readable mnemonics. The complexity
of the disassembler will vary with the size and bit field mapping of the inst-
ruction set. The few global routines are described below. Any other routines are
optional and may remain local. [Arch Port Kit]

INTERNAL
The _dbgArchInit routine (dbgArchLib) initializes a function pointer
_dbgDsmInstRtn (dbgLib) to point the dsmInst routine (dsmLib).

	l (addr, count)						--- dbgLib
	 \
	  dbgList (addr, count)					--- dbgLib
	   \
	    (*_dbgDsmInstRtn) (addr, (int)addr, dbgPrintAdrs)	--- dbgLib
	     \
	      dsmInst (binInst, address, prtAddress)		--- dsmLib

Namely, dsmInst() is the entry point of this library.  Also, a pointer to
dbgPrintAdrs (dbgLib) is passed to dsmInst(), as the default address printing
routine.
*/

#include "vxWorks.h"
#include "dsmLib.h"
#include "symLib.h"
#include "sysSymTbl.h"
#include "string.h"
#include "stdio.h"
#include "errnoLib.h"
#include "cplusLib.h"

/* forward LOCAL functions */

LOCAL INST *dsmFind (USHORT binInst []);
LOCAL void prtArgs (USHORT binInst [], INST *iPtr, int address, char *s);
LOCAL void dsmFormatAdrs (int address, char *s);
LOCAL void nPrtAddress (int address);

#if (CPU==SH7700 || CPU==SH7750)
/* Added for DSP/FP disassembler */
LOCAL INST *dsmFindFpp (USHORT fppInst []);
LOCAL void dsmPrintFpp (USHORT fppInst [], INST *fppPtr, int address,
			int nwords); 
LOCAL void prtArgsFpp (USHORT fppInst [], INST *fppPtr, int address,
		       char *s); 
#endif /* (CPU==SH7700 || CPU==SH7750) */

extern STATUS dspProbe (void);
extern STATUS fppProbe (void);

/*
This table is ordered by the number of bits in an instruction's
one word mask, beginning with the greatest number of bits in mask.
This scheme is used for avoiding conflicts between instructions
when matching bit patterns.  The instruction ops are arranged
sequentially within each group of instructions for a particular
mask so that uniqueness can be easily spotted.

INTERNAL
The primary structure of the disassembler is this array of instruction
mnemonics, instruction types, opcodes, and opcode masks. The type definition
of the INST structure may vary with each architecture, but should be similar
to the example shown in h/arch/<arch>/dsm<Arch>Lib.h. Additional opcodes and
masks are often useful in the disassembly process. This array of structures
is usually quite big, especially for CISC processors. [Arch Port Kit]

INTERNAL
Use additional structures for the register names and encoding, sub-opcode
tables, and other bit-field encoding that are useful in disassembly. The
content and number of structures should be derived naturally from the
instruction encoding tables. The software design should mimic the hardware
that decodes instructions. [Arch Port Kit]
*/

LOCAL INST inst [] =
    {
    /* inst,	instType,		opcode,	mask	*/
    {"clrt",	itComplete,		0x0008,	0xffff},
    {"nop",	itComplete,		0x0009,	0xffff},
    {"rts",	itComplete | itDelay,	0x000b,	0xffff},
    {"sett",	itComplete,		0x0018,	0xffff},
    {"div0u",	itComplete,		0x0019,	0xffff},
    {"sleep",	itComplete,		0x001b,	0xffff},
    {"clrmac",	itComplete,		0x0028,	0xffff},
    {"rte",	itComplete | itDelay,	0x002b,	0xffff},
#if (CPU==SH7750 || CPU==SH7700)
    {"ldtlb",	itComplete,		0x0038,	0xffff},
    {"clrs",	itComplete,		0x0048,	0xffff},
    {"sets",	itComplete,		0x0058,	0xffff},
#endif /* CPU==SH7750 || CPU==SH7700 */
    {"stc",	itStoreCsr,		0x0002,	0xf0ff}, /* STC   SR,  Rn */
    {"bsrf",	itBraDispRm | itDelay,	0x0003,	0xf0ff},
    {"sts",	itStoreCsr,		0x000a,	0xf0ff}, /* STS   MACH,Rn */
    {"stc",	itStoreCsr,		0x0012,	0xf0ff}, /* STC   GBR, Rn */
    {"sts",	itStoreCsr,		0x001a,	0xf0ff}, /* STS   MACL,Rn */
    {"stc",	itStoreCsr,		0x0022,	0xf0ff}, /* STC   VBR, Rn */
    {"braf",	itBraDispRm | itDelay,	0x0023,	0xf0ff},
    {"movt",	itOneReg,		0x0029,	0xf0ff},
    {"sts",	itStoreCsr,		0x002a,	0xf0ff}, /* STS   PR,  Rn */
#if (CPU==SH7700 || CPU==SH7600)
    {"stc",	itStoreCsr,	       	0x0052, 0xf0ff},
    {"stc",	itStoreCsr,	       	0x0062, 0xf0ff},
    {"stc",	itStoreCsr,	       	0x0072, 0xf0ff},
    {"sts",	itStoreCsr,	       	0x006a, 0xf0ff},    
    {"sts",	itStoreCsr,	       	0x007a, 0xf0ff},
    {"sts",	itStoreCsr,	       	0x008a, 0xf0ff},
    {"sts",	itStoreCsr,	       	0x009a, 0xf0ff},
    {"sts",	itStoreCsr,	       	0x00aa, 0xf0ff},
    {"sts",	itStoreCsr,	       	0x00ba, 0xf0ff},
#endif /* CPU==SH7700 || CPU==SH7600 */
#if (CPU==SH7750 || CPU==SH7700)
    {"stc",	itStoreCsr,		0x0032,	0xf0ff}, /* STC   SSR, Rn    */
    {"stc",	itStoreCsr,		0x0042,	0xf0ff}, /* STC   SPC, Rn    */
    {"stc",	itStoreCsr,		0x0082,	0xf0ff}, /* STC   R0_BANK,Rn */
    {"pref",	itAtOneReg,		0x0083,	0xf0ff}, /* PREF  @Rm        */
    {"stc",	itStoreCsr,		0x0092,	0xf0ff}, /* STC   R1_BANK,Rn */
    {"stc",	itStoreCsr,		0x00a2,	0xf0ff}, /* STC   R2_BANK,Rn */
    {"stc",	itStoreCsr,		0x00b2,	0xf0ff}, /* STC   R3_BANK,Rn */
    {"stc",	itStoreCsr,		0x00c2,	0xf0ff}, /* STC   R4_BANK,Rn */
    {"stc",	itStoreCsr,		0x00d2,	0xf0ff}, /* STC   R5_BANK,Rn */
    {"stc",	itStoreCsr,		0x00e2,	0xf0ff}, /* STC   R6_BANK,Rn */
    {"stc",	itStoreCsr,		0x00f2,	0xf0ff}, /* STC   R7_BANK,Rn */
#endif /* CPU==SH7750 || CPU==SH7700 */
#if (CPU==SH7750)
    {"ocbi",	itAtOneReg,		0x0093,	0xf0ff}, /* OCBI    @Rn */
    {"ocbp",	itAtOneReg,		0x00a3,	0xf0ff}, /* OCBP    @Rn */
    {"ocbwb",	itAtOneReg,		0x00b3,	0xf0ff}, /* OCBWB   @Rn */
    {"movca.l",	itAtOneReg,		0x00c3,	0xf0ff}, /* MOVCA.L R0,@Rn */
#endif /* CPU==SH7750 */
    {"mov.b",	itPutRmAtR0Rn,		0x0004,	0xf00f},
    {"mov.w",	itPutRmAtR0Rn,		0x0005,	0xf00f},
    {"mov.l",	itPutRmAtR0Rn,		0x0006,	0xf00f},
    {"mul.l",	itTwoReg,		0x0007,	0xf00f},
    {"mov.b",	itGetRnAtR0Rm,		0x000c,	0xf00f},
    {"mov.w",	itGetRnAtR0Rm,		0x000d,	0xf00f},
    {"mov.l",	itGetRnAtR0Rm,		0x000e,	0xf00f},
    {"mac.l",	itMac,			0x000f,	0xf00f},
    {"mov.l",	itPutRmAtDispRn,	0x1000,	0xf000},
    {"mov.b",	itPutRmAtRn,		0x2000,	0xf00f},
    {"mov.w",	itPutRmAtRn,		0x2001,	0xf00f},
    {"mov.l",	itPutRmAtRn,		0x2002,	0xf00f},
    {"mov.b",	itPushReg,		0x2004,	0xf00f},
    {"mov.w",	itPushReg,		0x2005,	0xf00f},
    {"mov.l",	itPushReg,		0x2006,	0xf00f},
    {"div0s",	itTwoReg,		0x2007,	0xf00f},
    {"tst",	itTwoReg,		0x2008,	0xf00f},
    {"and",	itTwoReg,		0x2009,	0xf00f},
    {"xor",	itTwoReg,		0x200a,	0xf00f},
    {"or",	itTwoReg,		0x200b,	0xf00f},
    {"cmp/str",	itTwoReg,		0x200c,	0xf00f},
    {"xtrct",	itTwoReg,		0x200d,	0xf00f},
    {"mulu.w",	itTwoReg,		0x200e,	0xf00f},
    {"muls.w",	itTwoReg,		0x200f,	0xf00f},
    {"cmp/eq",	itTwoReg,		0x3000,	0xf00f},
    {"cmp/hs",	itTwoReg,		0x3002,	0xf00f},
    {"cmp/ge",	itTwoReg,		0x3003,	0xf00f},
    {"div1",	itTwoReg,		0x3004,	0xf00f},
    {"dmulu.l",	itTwoReg,		0x3005,	0xf00f},
    {"cmp/hi",	itTwoReg,		0x3006,	0xf00f},
    {"cmp/gt",	itTwoReg,		0x3007,	0xf00f},
    {"sub",	itTwoReg,		0x3008,	0xf00f},
    {"subc",	itTwoReg,		0x300a,	0xf00f},
    {"subv",	itTwoReg,		0x300b,	0xf00f},
    {"add",	itTwoReg,		0x300c,	0xf00f},
    {"dmuls.l",	itTwoReg,		0x300d,	0xf00f},
    {"addc",	itTwoReg,		0x300e,	0xf00f},
    {"addv",	itTwoReg,		0x300f,	0xf00f},
    {"shll",	itOneReg,		0x4000,	0xf0ff},
    {"shlr",	itOneReg,		0x4001,	0xf0ff},
    {"sts.l",	itPushCsr,		0x4002,	0xf0ff},
    {"stc.l",	itPushCsr,		0x4003,	0xf0ff},
    {"rotl",	itOneReg,		0x4004,	0xf0ff},
    {"rotr",	itOneReg,		0x4005,	0xf0ff},
    {"lds.l",	itPopCsr,		0x4006,	0xf0ff},
    {"ldc.l",	itPopCsr,		0x4007,	0xf0ff},
    {"shll2",	itOneReg,		0x4008,	0xf0ff},
    {"shlr2",	itOneReg,		0x4009,	0xf0ff},
    {"lds",	itLoadCsr,		0x400a,	0xf0ff},
    {"jsr",	itAtOneReg | itDelay,	0x400b,	0xf0ff},
    {"ldc",	itLoadCsr,		0x400e,	0xf0ff},
    {"dt",	itOneReg,		0x4010,	0xf0ff},
    {"cmp/pz",	itOneReg,		0x4011,	0xf0ff},
    {"sts.l",	itPushCsr,		0x4012,	0xf0ff},
    {"stc.l",	itPushCsr,		0x4013,	0xf0ff},
#if (CPU==SH7700 || CPU==SH7600)
    {"setrc",	itOneReg,		0x4014,	0xf0ff},
#endif /* CPU==SH7700 || CPU==SH7600 */
    {"cmp/pl",	itOneReg,		0x4015,	0xf0ff},
    {"lds.l",	itPopCsr,		0x4016,	0xf0ff},
    {"ldc.l",	itPopCsr,		0x4017,	0xf0ff},
    {"shll8",	itOneReg,		0x4018,	0xf0ff},
    {"shlr8",	itOneReg,		0x4019,	0xf0ff},
    {"lds",	itLoadCsr,		0x401a,	0xf0ff},
    {"tas.b",	itAtOneReg,		0x401b,	0xf0ff},
    {"ldc",	itLoadCsr,		0x401e,	0xf0ff},
    {"shal",	itOneReg,		0x4020,	0xf0ff},
    {"shar",	itOneReg,		0x4021,	0xf0ff},
    {"sts.l",	itPushCsr,		0x4022,	0xf0ff},
    {"stc.l",	itPushCsr,		0x4023,	0xf0ff},
    {"rotcl",	itOneReg,		0x4024,	0xf0ff},
    {"rotcr",	itOneReg,		0x4025,	0xf0ff},
    {"lds.l",	itPopCsr,		0x4026,	0xf0ff},
    {"ldc.l",	itPopCsr,		0x4027,	0xf0ff},
    {"shll16",	itOneReg,		0x4028,	0xf0ff},
    {"shlr16",	itOneReg,		0x4029,	0xf0ff},
    {"lds",	itLoadCsr,		0x402a,	0xf0ff},
    {"jmp",	itAtOneReg | itDelay,	0x402b,	0xf0ff},
    {"ldc",	itLoadCsr,		0x402e,	0xf0ff},
#if (CPU==SH7700 || CPU==SH7600)
    {"stc.l",	itPushCsr,	       	0x4053, 0xf0ff},
    {"ldc.l",	itPopCsr,	       	0x4057, 0xf0ff},
    {"sts.l",	itPushCsr,	       	0x4062, 0xf0ff},
    {"stc.l",	itPushCsr,	       	0x4063, 0xf0ff},
    {"lds.l",	itPopCsr,	       	0x4066, 0xf0ff},
    {"ldc.l",	itPopCsr,	       	0x4067, 0xf0ff},
    {"stc.l",	itPushCsr,	       	0x4073, 0xf0ff},
    {"sts.l",	itPushCsr,	       	0x4072, 0xf0ff},
    {"lds.l",	itPopCsr,	       	0x4076, 0xf0ff},
    {"ldc.l",	itPopCsr,	       	0x4077, 0xf0ff},
    {"sts.l",	itPushCsr,	       	0x4082, 0xf0ff}, 
    {"lds.l",	itPopCsr,	       	0x4086, 0xf0ff},
    {"sts.l",	itPushCsr,	       	0x4092, 0xf0ff},
    {"lds.l",	itPopCsr,	       	0x4096, 0xf0ff},
    {"lds",	itLoadCsr,	       	0x406a, 0xf0ff},
    {"lds",	itLoadCsr,	       	0x407a, 0xf0ff},
    {"lds",	itLoadCsr,	       	0x408a, 0xf0ff},
    {"lds",	itLoadCsr,	       	0x409a, 0xf0ff},
    {"ldc",	itLoadCsr,	       	0x405e, 0xf0ff},
    {"ldc",	itLoadCsr,	       	0x407e, 0xf0ff},
    {"ldc",	itLoadCsr,	       	0x406e, 0xf0ff},
    {"sts.l",	itPushCsr,	       	0x40a2, 0xf0ff},
    {"lds.l",	itPopCsr,	       	0x40a6, 0xf0ff},
    {"lds",	itLoadCsr,	       	0x40aa, 0xf0ff},
    {"sts.l",	itPushCsr,	       	0x40b2, 0xf0ff},
    {"lds.l",	itPopCsr,	       	0x40b6, 0xf0ff}, 
    {"lds",	itLoadCsr,	       	0x40ba, 0xf0ff},  
#endif /* CPU==SH7700 || CPU==SH7600 */
#if (CPU==SH7750 || CPU==SH7700)
    {"stc.l",	itPushCsr,	0x4033,	0xf0ff}, /* STC.L  SSR,@-Rn */
    {"ldc.l",	itPopCsr,	0x4037,	0xf0ff}, /* LDC.L  @Rm+,SSR */
    {"ldc",	itLoadCsr,	0x403e,	0xf0ff}, /* LDC    Rm,SSR */
    {"stc.l",	itPushCsr,	0x4043,	0xf0ff}, /* STC.L  SPC,@-Rn */
    {"ldc.l",	itPopCsr,	0x4047,	0xf0ff}, /* LDC.L  @Rm+,SPC */
    {"ldc",	itLoadCsr,	0x404e,	0xf0ff}, /* LDC    Rm,SPC */
    {"stc.l",	itPushCsr,	0x4083,	0xf0ff}, /* STC.L  R0_BANK,@-Rn */
    {"ldc.l",	itPopCsr,	0x4087,	0xf0ff}, /* LDC.L  @Rm+,R0_BANK */
    {"ldc",	itLoadCsr,	0x408e,	0xf0ff}, /* LDC    Rm,R0_BANK */
    {"stc.l",	itPushCsr,	0x4093,	0xf0ff}, /* STC.L  R1_BANK,@-Rn */
    {"ldc.l",	itPopCsr,	0x4097,	0xf0ff}, /* LDC.L  @Rm+,R1_BANK */
    {"ldc",	itLoadCsr,	0x409e,	0xf0ff}, /* LDC    Rm,R1_BANK */
    {"stc.l",	itPushCsr,	0x40a3,	0xf0ff}, /* STC.L  R2_BANK,@-Rn */
    {"ldc.l",	itPopCsr,	0x40a7,	0xf0ff}, /* LDC.L  @Rm+,R2_BANK */
    {"ldc",	itLoadCsr,	0x40ae,	0xf0ff}, /* LDC    Rm,R2_BANK */
    {"stc.l",	itPushCsr,	0x40b3,	0xf0ff}, /* STC.L  R3_BANK,@-Rn */
    {"ldc.l",	itPopCsr,	0x40b7,	0xf0ff}, /* LDC.L  @Rm+,R3_BANK */
    {"ldc",	itLoadCsr,	0x40be,	0xf0ff}, /* LDC    Rm,R3_BANK */
    {"stc.l",	itPushCsr,	0x40c3,	0xf0ff}, /* STC.L  R4_BANK,@-Rn */
    {"ldc.l",	itPopCsr,	0x40c7,	0xf0ff}, /* LDC.L  @Rm+,R4_BANK */
    {"ldc",	itLoadCsr,	0x40ce,	0xf0ff}, /* LDC    Rm,R4_BANK */
    {"stc.l",	itPushCsr,	0x40d3,	0xf0ff}, /* STC.L  R5_BANK,@-Rn */
    {"ldc.l",	itPopCsr,	0x40d7,	0xf0ff}, /* LDC.L  @Rm+,R5_BANK */
    {"ldc",	itLoadCsr,	0x40de,	0xf0ff}, /* LDC    Rm,R5_BANK */
    {"stc.l",	itPushCsr,	0x40e3,	0xf0ff}, /* STC.L  R6_BANK,@-Rn */
    {"ldc.l",	itPopCsr,	0x40e7,	0xf0ff}, /* LDC.L  @Rm+,R6_BANK */
    {"ldc",	itLoadCsr,	0x40ee,	0xf0ff}, /* LDC    Rm,R6_BANK */
    {"stc.l",	itPushCsr,	0x40f3,	0xf0ff}, /* STC.L  R7_BANK,@-Rn */
    {"ldc.l",	itPopCsr,	0x40f7,	0xf0ff}, /* LDC.L  @Rm+,R7_BANK */
    {"ldc",	itLoadCsr,	0x40fe,	0xf0ff}, /* LDC    Rm,R7_BANK */
    {"shad",	itTwoReg,	0x400c,	0xf00f}, /* SHAD   Rm,Rn */
    {"shld",	itTwoReg,	0x400d,	0xf00f}, /* SHLD   Rm,Rn */
#endif /* CPU==SH7750 || CPU==SH7700 */
    {"mac.w",	itMac,			0x400f,	0xf00f},
    {"mov.l",	itGetRnAtDispRm,	0x5000,	0xf000},
    {"mov.b",	itGetRnAtRm,		0x6000,	0xf00f},
    {"mov.w",	itGetRnAtRm,		0x6001,	0xf00f},
    {"mov.l",	itGetRnAtRm,		0x6002,	0xf00f},
    {"mov",	itTwoReg,		0x6003,	0xf00f},
    {"mov.b",	itPopReg,		0x6004,	0xf00f},
    {"mov.w",	itPopReg,		0x6005,	0xf00f},
    {"mov.l",	itPopReg,		0x6006,	0xf00f},
    {"not",	itTwoReg,		0x6007,	0xf00f},
    {"swap.b",	itTwoReg,		0x6008,	0xf00f},
    {"swap.w",	itTwoReg,		0x6009,	0xf00f},
    {"negc",	itTwoReg,		0x600a,	0xf00f},
    {"neg",	itTwoReg,		0x600b,	0xf00f},
    {"extu.b",	itTwoReg,		0x600c,	0xf00f},
    {"extu.w",	itTwoReg,		0x600d,	0xf00f},
    {"exts.b",	itTwoReg,		0x600e,	0xf00f},
    {"exts.w",	itTwoReg,		0x600f,	0xf00f},
    {"add",	itImmToRn,		0x7000,	0xf000},
    {"mov.b",	itPutR0AtDispRn,	0x8000,	0xff00},
    {"mov.w",	itPutR0AtDispRn,	0x8100,	0xff00},
    {"mov.b",	itGetR0AtDispRm,	0x8400,	0xff00},
    {"mov.w",	itGetR0AtDispRm,	0x8500,	0xff00},
    {"cmp/eq",	itImmToR0,		0x8800,	0xff00},
    {"bt",	itBraDisp8,		0x8900,	0xff00},
    {"bf",	itBraDisp8,		0x8b00,	0xff00},
    {"bt/s",	itBraDisp8 | itDelay,	0x8d00,	0xff00},
    {"bf/s",	itBraDisp8 | itDelay,	0x8f00,	0xff00},
#if (CPU==SH7700 || CPU==SH7600)
    {"setrc",	itOneReg,		0x8200,	0xff00},
    {"ldrs",	itGetDispPc,		0x8c00,	0xff00},
    {"ldre",	itGetDispPc,		0x8e00,	0xff00},
#endif /* CPU==SH7700 || CPU==SH7600 */
    {"mov.w",	itGetRnAtDispPc,	0x9000,	0xf000},
    {"bra",	itBraDisp12 | itDelay,	0xa000,	0xf000},
    {"bsr",	itBraDisp12 | itDelay,	0xb000,	0xf000},
    {"mov.b",	itPutR0AtDispGbr,	0xc000,	0xff00},
    {"mov.w",	itPutR0AtDispGbr,	0xc100,	0xff00},
    {"mov.l",	itPutR0AtDispGbr,	0xc200,	0xff00},
    {"trapa",	itImm,			0xc300,	0xff00},
    {"mov.b",	itGetR0AtDispGbr,	0xc400,	0xff00},
    {"mov.w",	itGetR0AtDispGbr,	0xc500,	0xff00},
    {"mov.l",	itGetR0AtDispGbr,	0xc600,	0xff00},
    {"mova",	itMova,			0xc700,	0xff00},
    {"tst",	itImmToR0,		0xc800,	0xff00},
    {"and",	itImmToR0,		0xc900,	0xff00},
    {"xor",	itImmToR0,		0xca00,	0xff00},
    {"or",	itImmToR0,		0xcb00,	0xff00},
    {"tst.b",	itImmAtR0Gbr,		0xcc00,	0xff00},
    {"and.b",	itImmAtR0Gbr,		0xcd00,	0xff00},
    {"xor.b",	itImmAtR0Gbr,		0xce00,	0xff00},
    {"or.b",	itImmAtR0Gbr,		0xcf00,	0xff00},
    {"mov.l",	itGetRnAtDispPc,	0xd000,	0xf000},
    {"mov",	itImmToRn,		0xe000,	0xf000},
    {"",	0,			0,	0}
    };

#if (CPU==SH7750 || CPU==SH7700)
LOCAL INST instFpp [] = 
    {
    /* inst,    instType,               opcode, mask    */
    {"fabs",    itOneFpReg,         0xf05d, 0xf0ff}, /* FABS    FRn          */
    {"fadd",    itTwoFpReg,         0xf000, 0xf00f}, /* FADD    FRm,FRn      */
    {"fcmp/eq", itTwoFpReg,         0xf004, 0xf00f}, /* FCMP/EQ FRm,FRn      */
    {"fcmp/gt", itTwoFpReg,         0xf005, 0xf00f}, /* FCMP/GT FRm,FRn      */
    {"fdiv",    itTwoFpReg,         0xf003, 0xf00f}, /* FDIV    FRm,FRn      */
    {"fldi0",   itOneFpReg,         0xf08d, 0xf0ff}, /* FLDI0   FRn          */
    {"fldi1",   itOneFpReg,         0xf09d, 0xf0ff}, /* FLDI1   FRn          */
    {"flds",    itFloadFpul,        0xf01d, 0xf0ff}, /* FLDS    FRm,FPUL     */
    {"float",   itFstoreFpul,       0xf02d, 0xf0ff}, /* FLOAT   FPUL,FRn     */
    {"fmac",    itThreeFpReg,       0xf00e, 0xf00f}, /* FMAC    FR0,FRm,FRn  */
    {"fmov",    itTwoFpReg,         0xf00c, 0xf00f}, /* FMOV    FRm,FRn      */
    {"fmov.s",  itGetFRnAtR0Rm,     0xf006, 0xf00f}, /* FMOV.S  @(R0,Rm),FRn */
    {"fmov.s",  itPopFRn,           0xf009, 0xf00f}, /* FMOV.S  @Rm+,FRn     */
    {"fmov.s",  itGetFRnAtRm,       0xf008, 0xf00f}, /* FMOV.S  @Rm,FRn      */
    {"fmov.s",  itPutFRmAtR0Rn,     0xf007, 0xf00f}, /* FMOV.S  FRm,@(R0,Rn) */
    {"fmov.s",  itPushFRm,          0xf00b, 0xf00f}, /* FMOV.S  FRm,@-Rn     */
    {"fmov.s",  itPutFRmAtRn,       0xf00a, 0xf00f}, /* FMOV.S  FRm,@Rn      */
    {"fmul",    itTwoFpReg,         0xf002, 0xf00f}, /* FMUL    FRm,FRn      */
    {"fneg",    itOneFpReg,         0xf04d, 0xf0ff}, /* FNEG    FRn          */
    {"fsqrt",   itOneFpReg,         0xf06d, 0xf0ff}, /* FSQRT   FRn          */
    {"fsts",    itFstoreFpul,       0xf00d, 0xf0ff}, /* FSTS    FPUL,FRn     */
    {"fsub",    itTwoFpReg,         0xf001, 0xf00f}, /* FSUB    FRm,FRn      */
    {"ftrc",    itFloadFpul,        0xf03d, 0xf0ff}, /* FTRC    FRm,FPUL     */
    {"lds",     itLoadFpscr,        0x406a, 0xf0ff}, /* LDS     Rm,FPSCR     */
    {"lds",     itLoadFpul,         0x405a, 0xf0ff}, /* LDS     Rm,FPUL      */
    {"lds.l",   itPopFpscr,         0x4066, 0xf0ff}, /* LDS.L   @Rm+,FPSCR   */
    {"lds.l",   itPopFpul,          0x4056, 0xf0ff}, /* LDS.L   @Rm+,FPUL    */
    {"sts",     itStoreFpscr,       0x006a, 0xf0ff}, /* STS     FPSCR,Rn     */
    {"sts",     itStoreFpul,        0x005a, 0xf0ff}, /* STS     FPUL,Rn      */
    {"sts.l",   itPushFpscr,        0x4062, 0xf0ff}, /* STS.L   FPSCR,@-Rn   */
    {"sts.l",   itPushFpul,         0x4052, 0xf0ff}, /* STS.L   FPUL,@-Rn    */
#if (CPU==SH7750)
    /* SH7750 specific floating point and graphics support instructions */
    {"fschg",   itComplete,         0xf3fd, 0xffff}, /* FSCHG                */
    {"frchg",   itComplete,         0xfbfd, 0xffff}, /* FRCHG                */
    {"ftrv",    itFtrv,             0xf1fd, 0xf3ff}, /* FTRV    XMTRX, FVn   */
    {"fipr",    itFipr,             0xf0ed, 0xf0ff}, /* FIPR    FVm, FVn     */
    {"fcnvsd",  itConvToDp,         0xf0ad, 0xf1ff}, /* FCNVSD  FPUL, DRn    */
    {"fcnvds",  itConvToSp,         0xf0bd, 0xf1ff}, /* FCNVDS  DRm, FPUL    */
#endif /* (CPU==SH7750) */
    {"",	0,		    0,      0}
    };
#endif /* (CPU==SH7750 || CPU==SH7700) */

#if (CPU==SH7700 || CPU==SH7600)
/*
 * The list of SH DSP specific instructions.  The first few are
 * 16 bit instructions (size is detected independently from this table),
 * all the rest are 32 bit.
 * All of these insns can be combined with parallel X & Y moves.
 * DSP instructions may have as many as 7 arguments encoded in
 * the lower three nibbles, and these are represented in the table by
 * the arglist.  
 * The flags field handles "dct" and "dcf" prefixes and any infix
 * parallel mnemonics such as "pmuls", eg, "psub x, y, u pmuls e, f, g"
 */
LOCAL SH_DSP_OPCODE_INFO instDsp[] = 
    {
    /* inst,	arglist,     		opcode,		 mask,   flags*/
    {"movs.l",	{D_AS, D_DS},		0xf402,		0xfc03, SH_MOVS},
    {"movs.l",	{D_DS, D_AS},		0xf403,		0xfc03, SH_MOVS},
    {"movs.w",	{D_AS, D_DS},		0xf400,		0xfc03, SH_MOVS},
    {"movs.w",	{D_DS, D_AS},		0xf401,		0xfc03, SH_MOVS},
    {"movx.w",	{D_AX, D_DX},		0xf000,		0xfc20, SH_MOVX},
    {"movx.w",	{D_DAX, D_AX},		0xf020,		0xfc20, SH_MOVX},
    {"movy.w",	{D_AY, D_DY},		0xf000,		0xfc10, SH_MOVY},
    {"movy.w",	{D_DAY, D_AY},		0xf010,		0xfc10, SH_MOVY},
    {"nopx",	{0},			0xf000,		0xfe5c, SH_MOVX},
    {"nopy",	{0},			0xf000,		0xfda3, SH_MOVY},
    {"pabs",	{D_SX, D_DZ},		0xf8008800,	0xfc00ff30},
    {"pabs",	{D_SY, D_DZ},		0xf800a800,	0xfc00ffc0},
    {"padd",	{D_SX, D_SY, D_DU, D_SE, D_SF, D_DG},	
					0xf8007000,    	0xfc00f000, SH_PMULS},
    {"padd",	{D_SX, D_SY, D_DZ},	0xf800b100,	0xfc00ff00},
    {"padd",	{D_SX, D_SY, D_DZ},	0xf800b200,	0xfc00ff00, SH_DCT},
    {"padd",	{D_SX, D_SY, D_DZ},	0xf800b300,	0xfc00ff00, SH_DCF},
    {"paddc",	{D_SX, D_SY, D_DZ},	0xf800b000,	0xfc00ff00},
    {"pand",	{D_SX, D_SY, D_DZ},	0xf8009500,	0xfc00ff00},
    {"pand",	{D_SX, D_SY, D_DZ},	0xf8009600,	0xfc00ff00, SH_DCT},
    {"pand",	{D_SX, D_SY, D_DZ},	0xf8009700,	0xfc00ff00, SH_DCF},
    {"pclr",	{D_DZ},			0xf8008d00,	0xfc00fff0},
    {"pclr",	{D_DZ},			0xf8008e00,	0xfc00fff0, SH_DCT},
    {"pclr",	{D_DZ},			0xf8008f00,	0xfc00fff0, SH_DCF},
    {"pcmp",	{D_SX, D_SY},		0xf8008400,	0xfc00ff0f},
    {"pcopy",	{D_SX, D_DZ},		0xf800d900,	0xfc00ff30},
    {"pcopy",	{D_SY, D_DZ},		0xf800f900,	0xfc00ffc0},
    {"pcopy",	{D_SX, D_DZ},		0xf800da00,	0xfc00ff30, SH_DCT},
    {"pcopy",	{D_SY, D_DZ},		0xf800fa00,	0xfc00ffc0, SH_DCT},
    {"pcopy",	{D_SX, D_DZ},		0xf800db00,	0xfc00ff30, SH_DCF},
    {"pcopy",	{D_SY, D_DZ},		0xf800fb00,	0xfc00ffc0, SH_DCF},
    {"pdec",	{D_SX, D_DZ},		0xf8008900,	0xfc00ff30},
    {"pdec",	{D_SY, D_DZ},		0xf800a900,	0xfc00ffc0},
    {"pdec",	{D_SX, D_DZ},		0xf8008a00,	0xfc00ff30, SH_DCT},
    {"pdec",	{D_SY, D_DZ},		0xf800aa00,	0xfc00ffc0, SH_DCT},
    {"pdec",	{D_SX, D_DZ},		0xf8008b00,	0xfc00ff30, SH_DCF},
    {"pdec",	{D_SY, D_DZ},		0xf800ab00,	0xfc00ffc0, SH_DCF},
    {"pdmsb",	{D_SX, D_DZ},		0xf8009d00,	0xfc00ff30},
    {"pdmsb",	{D_SY, D_DZ},		0xf800bd00,	0xfc00ffc0},
    {"pdmsb",	{D_SX, D_DZ},		0xf8009e00,	0xfc00ff30, SH_DCT},
    {"pdmsb",	{D_SY, D_DZ},		0xf800be00,	0xfc00ffc0, SH_DCT},
    {"pdmsb",	{D_SX, D_DZ},		0xf8009f00,	0xfc00ff30, SH_DCF},
    {"pdmsb",	{D_SY, D_DZ},		0xf800bf00,	0xfc00ffc0, SH_DCF},
    {"pinc",	{D_SX, D_DZ},		0xf8009900,	0xfc00ff30},
    {"pinc",	{D_SY, D_DZ},		0xf800b900,	0xfc00ffc0},
    {"pinc",	{D_SX, D_DZ},		0xf8009a00,	0xfc00ff30, SH_DCT},
    {"pinc",	{D_SY, D_DZ},		0xf800ba00,	0xfc00ffc0, SH_DCT},
    {"pinc",	{D_SX, D_DZ},		0xf8009b00,	0xfc00ff30, SH_DCF},
    {"pinc",	{D_SY, D_DZ},		0xf800bb00,	0xfc00ffc0, SH_DCF},
    {"plds",	{D_DZ, D_MACH},		0xf800ed00,	0xfc00fff0},
    {"plds",	{D_DZ, D_MACL},		0xf800fd00,	0xfc00fff0},
    {"plds",	{D_DZ, D_MACH},		0xf800ee00,	0xfc00fff0, SH_DCT},
    {"plds",	{D_DZ, D_MACL},		0xf800fe00,	0xfc00fff0, SH_DCT},
    {"plds",	{D_DZ, D_MACH},		0xf800ef00,	0xfc00fff0, SH_DCF},
    {"plds",	{D_DZ, D_MACL},		0xf800ff00,	0xfc00fff0, SH_DCF},
    {"pmuls",	{D_SE, D_SF, D_DG},	0xf8004000,	0xfc00f0f3},
    {"pneg",	{D_SX, D_DZ},		0xf800c900,	0xfc00ff30},
    {"pneg",	{D_SY, D_DZ},		0xf800e900,	0xfc00ffc0},
    {"pneg",	{D_SX, D_DZ},		0xf800ca00,	0xfc00ff30, SH_DCT},
    {"pneg",	{D_SY, D_DZ},		0xf800ea00,	0xfc00ffc0, SH_DCT},
    {"pneg",	{D_SX, D_DZ},		0xf800cb00,	0xfc00ff30, SH_DCF},
    {"pneg",	{D_SY, D_DZ},		0xf800eb00,	0xfc00ffc0, SH_DCF},
    {"por",	{D_SX, D_SY, D_DZ},	0xf800b500,	0xfc00ff00},
    {"por",	{D_SX, D_SY, D_DZ},	0xf800b600,	0xfc00ff00, SH_DCT},
    {"por",	{D_SX, D_SY, D_DZ},	0xf800b700,	0xfc00ff00, SH_DCF},
    {"prnd",	{D_SX, D_DZ},		0xf8009800,	0xfc00ff30},
    {"prnd",	{D_SY, D_DZ},		0xf800b800,	0xfc00ffc0},
    {"psha",	{D_SX, D_SY, D_DZ},	0xf8009100,	0xfc00ff00},
    {"psha",	{D_SX, D_SY, D_DZ},	0xf8009200,	0xfc00ff00, SH_DCT},
    {"psha",	{D_SX, D_SY, D_DZ},	0xf8009300,	0xfc00ff00, SH_DCF},
    {"psha",	{D_IMM, D_DZ},		0xf8001000,	0xfc00f800},
    {"pshl",	{D_SX, D_SY, D_DZ},	0xf8008100,	0xfc00ff00},
    {"pshl",	{D_SX, D_SY, D_DZ},	0xf8008200,	0xfc00ff00, SH_DCT},
    {"pshl",	{D_SX, D_SY, D_DZ},	0xf8008300,	0xfc00ff00, SH_DCF},
    {"pshl",	{D_IMM, D_DZ},		0xf8000000,	0xfc00f800},
    {"psts",	{D_MACH, D_DZ},		0xf800cd00,	0xfc00fff0},
    {"psts",	{D_MACL, D_DZ},		0xf800dd00,	0xfc00fff0},
    {"psts",	{D_MACH, D_DZ},		0xf800ce00,	0xfc00fff0, SH_DCT},
    {"psts",	{D_MACL, D_DZ},		0xf800de00,	0xfc00fff0, SH_DCT},
    {"psts",	{D_MACH, D_DZ},		0xf800cf00,	0xfc00fff0, SH_DCF},
    {"psts",	{D_MACL, D_DZ},		0xf800df00,	0xfc00fff0, SH_DCF},
    {"psub",	{D_SX, D_SY, D_DU, D_SE, D_SF, D_DG},	
					0xf8006000,	0xfc00f000, SH_PMULS},
    {"psub",	{D_SX, D_SY, D_DZ},	0xf800a100,	0xfc00ff00},
    {"psub",	{D_SX, D_SY, D_DZ},	0xf800a200,	0xfc00ff00, SH_DCT},
    {"psub",	{D_SX, D_SY, D_DZ},	0xf800a300,	0xfc00ff00, SH_DCF},
    {"psubc",	{D_SX, D_SY, D_DZ},	0xf800a000,	0xfc00ff00},
    {"pxor",	{D_SX, D_SY, D_DZ},	0xf800a500,	0xfc00ff00},
    {"pxor",	{D_SX, D_SY, D_DZ},	0xf800a600,	0xfc00ff00, SH_DCT},
    {"pxor",	{D_SX, D_SY, D_DZ},	0xf800a700,	0xfc00ff00, SH_DCF},
    {0}
    };
#endif /* CPU==SH7700 || CPU==SH7600 */ 

LOCAL BOOL delaySlot   = FALSE;	/* remember if next inst is in delayed slot */
LOCAL int  lastAddress = 0;	/* remember the last address disassembled   */

/*******************************************************************************
*
* dsmFind - disassemble one instruction
*
* This routine figures out which instruction is pointed to by binInst,
* and returns a pointer to the INST which describes it.
*
* RETURNS: pointer to instruction or NULL if unknown instruction.
*
* INTERNAL
* This routine, called by l(), disassembles the instruction that starts at the
* address passed as an argument. It can be one machine-defined word for RISCs,
* or the beginning of an array of words for CISCs. The return value is a pointer
* to the instruction defined in the INST array. If no disassembly is possible,
* the error number is set to S_dsmLib_UNKNOWN_INSTRUCTION and the return value
* should be NULL. [Arch Port Kit]
*/

LOCAL INST *dsmFind
    (
    USHORT binInst []
    )
    {
    FAST INST *iPtr;

    /* Find out which instruction it is */

    for (iPtr = &inst [0]; iPtr->mask != 0; iPtr++)
	{
	if ((binInst [0] & iPtr->mask) == iPtr->op) return (iPtr);
	}

    /* If we're here, we couldn't find it */

    errnoSet (S_dsmLib_UNKNOWN_INSTRUCTION);
    return (NULL);
    }

/*******************************************************************************
*
* dsmPrint - print a disassembled instruction
*
* This routine prints an instruction in disassembled form.  It takes
* as input a pointer to the instruction, a pointer to the INST
* that describes it (as found by dsmFind()), and an address with which to
* prepend the instruction.
*
* INTERNAL
* The actual printing of the instruction mnemonic and operands are done by this
* function. The list of input arguments includes with the encoded instruction,
* the return value of dsmFind(), the starting address of the instruction, the
* number of instruction words, and pointer(s) to the function(s) that print
* the parts of the instruction. [Arch Port Kit]
*
* INTERNAL
* The format of the disassembled output starts with the address and hexadecimal
* representation of the instruction. The mnemonic and any instruction modifiers
* typically follow, then the operands. The output should reflect the syntax of
* the assembler input. Use spacing to align and enhance the readability of the
* disassembly. [Arch Port Kit]
*/

LOCAL void dsmPrint
    (
    USHORT binInst [],		/* Pointer to instructin */
    FAST INST *iPtr,		/* Pointer to INST returned by dsmFind */
    int address,		/* Address with which to prepend instructin */
    int nwords			/* Instruction length, in words */
    )
    {
    FAST int ix;                /* index into binInst */
    FAST int wordsToPrint;      /* # of 5-char areas to reserve for printing
                                   of hex version of instruction */
    BOOL slotInst;		/* TRUE if instruction is in delayed slot */

    slotInst = (delaySlot == TRUE) && ((address - lastAddress) == 2);

    wordsToPrint = (((nwords - 1) / 2) + 1) * 2;

    /* Print the address and the instruction, in hex */

    printf ("%06x  ", address);

    for (ix = 0; ix < wordsToPrint; ++ix)
        /* print lines in multiples of 5 words */
        {
        if ((ix > 0) && (ix % 3) == 0)          /* print words on next line */
            printf ("\n        ");
        printf ((ix < nwords) ? "%04x " : "     ", binInst [ix]);
        }

    if (slotInst) printf (" (");
    else          printf ("  ");

    if (iPtr == NULL)
        {
        printf (".short  0x%04x", binInst[0]);

	delaySlot = FALSE;
        }
    else
	{
	char s[64 + MAX_SYS_SYM_LEN + 1];

	/* Print the instruction mnemonic, the size code (.w, or whatever),
	   and the arguments */

	prtArgs (binInst, iPtr, address, s);
	printf ("%-10s %s", iPtr->name, s);

	if (iPtr->type & itDelay) delaySlot = TRUE;
	else                      delaySlot = FALSE;
	}

    if (slotInst) printf (")\n");
    else	  printf ("\n");

    lastAddress = address;
    }

/*******************************************************************************
*
* prtArgs - format arguments
*
* NOMANUAL
*/

LOCAL void prtArgs
    (
    USHORT binInst [],	/* Pointer to the binary instruction */
    FAST INST *iPtr,	/* Pointer to the INST describing binInst */
    int address,	/* Address at which the instruction resides */
    char *s
    )
    {
    UINT32 *dPtr;
    UINT32  addr;
    UINT16  disp;
    USHORT  insn = binInst [0];
    char    ss[16];

    switch (iPtr->type & itTypeMask)
	{
	case itComplete:
	    s[0] = '\0';/* No arguments */				break;

	case itOneReg:
	    sprintf (s, "r%u", (insn & 0x0f00) >> 8);			break;

	case itStoreCsr:
	    switch (iPtr->op)
		{
		case 0x0002:	strcpy (ss, "sr");	break;
		case 0x0012:	strcpy (ss, "gbr");	break;
		case 0x0022:	strcpy (ss, "vbr");	break;
#if (CPU==SH7750 || CPU==SH7700)
		case 0x0032:	strcpy (ss, "ssr");	break;
		case 0x0042:	strcpy (ss, "spc");	break;
		case 0x0082:	strcpy (ss, "r0_bank");	break;
		case 0x0092:	strcpy (ss, "r1_bank");	break;
		case 0x00a2:	strcpy (ss, "r2_bank");	break;
		case 0x00b2:	strcpy (ss, "r3_bank");	break;
		case 0x00c2:	strcpy (ss, "r4_bank");	break;
		case 0x00d2:	strcpy (ss, "r5_bank");	break;
		case 0x00e2:	strcpy (ss, "r6_bank");	break;
		case 0x00f2:	strcpy (ss, "r7_bank");	break;
#endif /* CPU==SH7750 || CPU==SH7700 */
		case 0x000a:	strcpy (ss, "mach");	break;
		case 0x001a:	strcpy (ss, "macl");	break;
		case 0x002a:	strcpy (ss, "pr");	break;
#if (CPU==SH7700 || CPU==SH7600)
		case 0x0052:	strcpy (ss, "mod");	break;
		case 0x0062:	strcpy (ss, "rs");	break;
		case 0x006a:	strcpy (ss, "dsr");	break;
		case 0x0072:	strcpy (ss, "re");	break;
		case 0x007a:    strcpy (ss, "a0");	break;
		case 0x008a:    strcpy (ss, "x0");	break;
                case 0x009a:    strcpy (ss, "x1");	break;
		case 0x00aa:    strcpy (ss, "y0");	break;
		case 0x00ba:    strcpy (ss, "y1");	break;
#endif /* CPU==SH7700 || CPU==SH7600 */
		default:	strcpy (ss, "????");
		}
	    sprintf (s, "%s,r%u", ss, (insn & 0x0f00) >> 8);		break;

	case itAtOneReg:
#if (CPU==SH7750)
	    if (iPtr->op == 0x00c3)	/* MOVCA.L R0,@Rn */
		sprintf (s, "r0,@r%u", (insn & 0x0f00) >> 8);
	    else
#endif /* CPU==SH7750 */
		sprintf (s, "@r%u", (insn & 0x0f00) >> 8);
	    break;

	case itPushCsr:
	    switch (iPtr->op)
		{
		case 0x4003:	strcpy (ss, "sr");	break;
		case 0x4013:	strcpy (ss, "gbr");	break;
		case 0x4023:	strcpy (ss, "vbr");	break;
#if (CPU==SH7750 || CPU==SH7700)
		case 0x4033:	strcpy (ss, "ssr");	break;
		case 0x4043:	strcpy (ss, "spc");	break;
		case 0x4083:	strcpy (ss, "r0_bank");	break;
		case 0x4093:	strcpy (ss, "r1_bank");	break;
		case 0x40a3:	strcpy (ss, "r2_bank");	break;
		case 0x40b3:	strcpy (ss, "r3_bank");	break;
		case 0x40c3:	strcpy (ss, "r4_bank");	break;
		case 0x40d3:	strcpy (ss, "r5_bank");	break;
		case 0x40e3:	strcpy (ss, "r6_bank");	break;
		case 0x40f3:	strcpy (ss, "r7_bank");	break;
#endif /* CPU==SH7750 || CPU==SH7700 */
		case 0x4002:	strcpy (ss, "mach");	break;
		case 0x4012:	strcpy (ss, "macl");	break;
		case 0x4022:	strcpy (ss, "pr");	break;
#if (CPU==SH7700 || CPU==SH7600)
		case 0x4053:	strcpy (ss, "mod");	break;
		case 0x4062:	strcpy (ss, "dsr");	break;
		case 0x4063:	strcpy (ss, "rs");	break;
		case 0x4072:	strcpy (ss, "a0");	break;
		case 0x4073:	strcpy (ss, "re");	break;
		case 0x4082:	strcpy (ss, "x0");	break;
		case 0x4092:	strcpy (ss, "x1");	break;
		case 0x40a2:	strcpy (ss, "y0");	break;
		case 0x40b2:	strcpy (ss, "y1");	break;
#endif /* CPU==SH7700 || CPU==SH7600 */
		default:	strcpy (ss, "????");
		}
	    sprintf (s, "%s,@-r%u", ss, (insn & 0x0f00) >> 8);		break;

	case itBraDispRm:
	    sprintf (s, "r%u", (insn & 0x0f00) >> 8);			break;

	case itLoadCsr:
	    switch (iPtr->op)
		{
		case 0x400e:	strcpy (ss, "sr");	break;
		case 0x401e:	strcpy (ss, "gbr");	break;
		case 0x402e:	strcpy (ss, "vbr");	break;
#if (CPU==SH7750 || CPU==SH7700)
		case 0x403e:	strcpy (ss, "ssr");	break;
		case 0x404e:	strcpy (ss, "spc");	break;
		case 0x408e:	strcpy (ss, "r0_bank");	break;
		case 0x409e:	strcpy (ss, "r1_bank");	break;
		case 0x40ae:	strcpy (ss, "r2_bank");	break;
		case 0x40be:	strcpy (ss, "r3_bank");	break;
		case 0x40ce:	strcpy (ss, "r4_bank");	break;
		case 0x40de:	strcpy (ss, "r5_bank");	break;
		case 0x40ee:	strcpy (ss, "r6_bank");	break;
		case 0x40fe:	strcpy (ss, "r7_bank");	break;
#endif /* CPU==SH7750 || CPU==SH7700 */
		case 0x400a:	strcpy (ss, "mach");	break;
		case 0x401a:	strcpy (ss, "macl");	break;
		case 0x402a:	strcpy (ss, "pr");	break;
#if (CPU==SH7700 || CPU==SH7600)
		case 0x405e:	strcpy (ss, "mod");	break;
		case 0x406a:	strcpy (ss, "dsr");	break;
		case 0x406e:	strcpy (ss, "rs");	break;
		case 0x407a:	strcpy (ss, "a0");	break;
		case 0x407e:	strcpy (ss, "re");	break;
		case 0x408a:	strcpy (ss, "x0");	break;
		case 0x409a:	strcpy (ss, "x1");	break;
		case 0x40aa:	strcpy (ss, "y0");	break;
		case 0x40ba:	strcpy (ss, "y1");	break;
#endif /* CPU==SH7700 || CPU==SH7600 */
		default:	strcpy (ss, "????");
		}
	    sprintf (s, "r%u,%s", (insn & 0x0f00) >> 8, ss);		break;

	case itPopCsr:
	    switch (iPtr->op)
		{
		case 0x4007:	strcpy (ss, "sr");	break;
		case 0x4017:	strcpy (ss, "gbr");	break;
		case 0x4027:	strcpy (ss, "vbr");	break;
#if (CPU==SH7750 || CPU==SH7700)
		case 0x4037:	strcpy (ss, "ssr");	break;
		case 0x4047:	strcpy (ss, "spc");	break;
		case 0x4087:	strcpy (ss, "r0_bank");	break;
		case 0x4097:	strcpy (ss, "r1_bank");	break;
		case 0x40a7:	strcpy (ss, "r2_bank");	break;
		case 0x40b7:	strcpy (ss, "r3_bank");	break;
		case 0x40c7:	strcpy (ss, "r4_bank");	break;
		case 0x40d7:	strcpy (ss, "r5_bank");	break;
		case 0x40e7:	strcpy (ss, "r6_bank");	break;
		case 0x40f7:	strcpy (ss, "r7_bank");	break;
#endif /* CPU==SH7750 || CPU==SH7700 */
		case 0x4006:	strcpy (ss, "mach");	break;
		case 0x4016:	strcpy (ss, "macl");	break;
		case 0x4026:	strcpy (ss, "pr");	break;
#if (CPU==SH7700 || CPU==SH7600)
		case 0x4057:	strcpy (ss, "mod");	break;
		case 0x4066:	strcpy (ss, "dsr");	break;
		case 0x4067:	strcpy (ss, "rs");	break;
		case 0x4076:	strcpy (ss, "a0");	break;
		case 0x4077:	strcpy (ss, "re");	break;
		case 0x4086:	strcpy (ss, "x0");	break;
		case 0x4096:	strcpy (ss, "x1");	break;
		case 0x40a6:	strcpy (ss, "y0");	break;
		case 0x40b6:	strcpy (ss, "y1");	break;
#endif /* CPU==SH7700 || CPU==SH7600 */
		default:	strcpy (ss, "????");
		}
	    sprintf (s, "@r%u+,%s", (insn & 0x0f00) >> 8, ss);		break;

	case itTwoReg:
	    sprintf (s, "r%u,r%u",	(insn & 0x00f0) >> 4,
					(insn & 0x0f00) >> 8);		break;
	case itPutRmAtRn:
	    sprintf (s, "r%u,@r%u",	(insn & 0x00f0) >> 4,
					(insn & 0x0f00) >> 8);		break;
	case itGetRnAtRm:
	    sprintf (s, "@r%u,r%u",	(insn & 0x00f0) >> 4,
					(insn & 0x0f00) >> 8);		break;
	case itMac:
	    sprintf (s, "@r%u+,@r%u+",	(insn & 0x00f0) >> 4,
					(insn & 0x0f00) >> 8);		break;
	case itPopReg:
	    sprintf (s, "@r%u+,r%u",	(insn & 0x00f0) >> 4,
					(insn & 0x0f00) >> 8);		break;
	case itPushReg:
	    sprintf (s, "r%u,@-r%u",	(insn & 0x00f0) >> 4,
					(insn & 0x0f00) >> 8);		break;
	case itPutRmAtR0Rn:
	    sprintf (s, "r%u,@(r0,r%u)",(insn & 0x00f0) >> 4,
					(insn & 0x0f00) >> 8);		break;
	case itGetRnAtR0Rm:
	    sprintf (s, "@(r0,r%u),r%u",(insn & 0x00f0) >> 4,
					(insn & 0x0f00) >> 8);		break;
	case itGetR0AtDispRm:
	    switch (iPtr->op)
		{
		case 0x8400:
		    sprintf (s, "@(%d,r%u),r0",  insn & 0x000f,
						(insn & 0x00f0) >> 4);	break;
		case 0x8500:
		    sprintf (s, "@(%d,r%u),r0", (insn & 0x000f) << 1,
						(insn & 0x00f0) >> 4);	break;
		default:
		    strcpy (s, "????");
		}
									break;

	case itPutR0AtDispRn:       /* nd4 format: "opcode R0,@(disp,Rn)"   */
	    switch (iPtr->op)
		{
		case 0x8000:
		    sprintf (s, "r0,@(%d,r%u)",  insn & 0x000f,
						(insn & 0x00f0) >> 4);	break;
		case 0x8100:
		    sprintf (s, "r0,@(%d,r%u)", (insn & 0x000f) << 1,
						(insn & 0x00f0) >> 4);	break;
		default:
		    strcpy (s, "????");
		}
									break;

	case itPutRmAtDispRn:       /* nmd format: "opcode Rm,@(disp,Rn)"   */
	    sprintf (s, "r%u,@(%d,r%u)",	(insn & 0x00f0) >> 4,
						(insn & 0x000f) << 2,
						(insn & 0x0f00) >> 8);	break;

	case itGetRnAtDispRm:       /* nmd format: "opcode @(disp,Rm),Rn"   */
	    sprintf (s, "@(%d,r%u),r%u",	(insn & 0x000f) << 2,
						(insn & 0x00f0) >> 4,
						(insn & 0x0f00) >> 8);	break;

	case itPutR0AtDispGbr:      /* d   format: "opcode R0,@(disp,GBR)"  */
	    switch (iPtr->op)
		{
		case 0xc000:
		    sprintf (s, "r0,@(%#x,gbr)", insn & 0x00ff);	break;
		case 0xc100:
		    sprintf (s, "r0,@(%#x,gbr)", (insn & 0x00ff) << 1);	break;
		case 0xc200:
		    sprintf (s, "r0,@(%#x,gbr)", (insn & 0x00ff) << 2);	break;
		default:
		    strcpy (s, "????");
		}
									break;

	case itGetR0AtDispGbr:      /* d   format: "opcode @(disp,GBR),R0"  */
	    switch (iPtr->op)
		{
		case 0xc400:
		    sprintf (s, "@(%#x,gbr),r0", insn & 0x00ff);	break;
		case 0xc500:
		    sprintf (s, "@(%#x,gbr),r0", (insn & 0x00ff) << 1);	break;
		case 0xc600:
		    sprintf (s, "@(%#x,gbr),r0", (insn & 0x00ff) << 2);	break;
		default:
		    strcpy (s, "????");
		}
									break;

	case itMova:                /* d   format: "opcode @(disp,PC),R0"   */
	    {
	    char sym [MAX_SYS_SYM_LEN + 1];

	    disp = (insn & 0x00ff) << 2;
	    addr = (UINT32)((address + 4 + disp) & 0xfffffffc);
	    dsmFormatAdrs (addr, sym);

	    sprintf (s, "@(%#x,pc),r0 (= %s)", (INT16)disp, sym);
	    }
									break;

	case itBraDisp8:            /* d   format: "opcode disp"            */
	    {
	    char sym [MAX_SYS_SYM_LEN + 1];

	    if (insn & 0x0080) disp = (insn | 0xff00) << 1;
	    else               disp = (insn & 0x00ff) << 1;

	    addr = (UINT32)(address + 4 + (INT16)disp);
	    dsmFormatAdrs (addr, sym);

	    sprintf (s, "%+d       (==> %s)", (INT16)disp, sym);
	    }
									break;

	case itBraDisp12:           /* d12 format: "opcode disp"            */
	    {
	    char sym [MAX_SYS_SYM_LEN + 1];

	    if (insn & 0x0800) disp = (insn | 0xf000) << 1;
	    else               disp = (insn & 0x0fff) << 1;

	    addr = (UINT32)(address + 4 + (INT16)disp);
	    dsmFormatAdrs (addr, sym);

	    sprintf (s, "%+d       (==> %s)", (INT16)disp, sym);
	    }
									break;

	case itGetRnAtDispPc:       /* nd8 format: "opcode @(disp,PC),Rn"   */
	    switch (iPtr->op)
		{
		case 0x9000:
		    disp = (insn & 0x00ff) << 1;
		    dPtr = (UINT32 *)((address + 4 + disp) & 0xfffffffe);

		    sprintf (s, "@(%#x,pc),r%u (= 0x%08x)",
			     disp, (insn & 0x0f00) >> 8, *(INT16 *)dPtr);
		    break;

		case 0xd000:
		    {
		    char     *label;  /* pointer to sym tbl copy of name */
		    void     *actVal;
		    SYMBOL_ID symId;
		    char      demangled [MAX_SYS_SYM_LEN + 1];
		    char     *labelToPrint;

		    disp = (insn & 0x00ff) << 2;
		    dPtr = (UINT32 *)((address + 4 + disp) & 0xfffffffc);
		    addr = *dPtr;
		    
		    if ((symFindSymbol (sysSymTbl, NULL, 
					(void *)addr, SYM_MASK_NONE, 
					SYM_MASK_NONE, &symId) == OK) &&
			(symNameGet (symId, &label) == OK) &&
			(symValueGet (symId, &actVal) == OK) && 
			(actVal == (void *)addr))
			{
			labelToPrint = cplusDemangle (label, demangled,
						      sizeof (demangled));
			sprintf (s, "@(%#x,pc),r%u (= 0x%08x = %s)",
				 disp, (insn & 0x0f00) >> 8,
				 *dPtr, labelToPrint);
			}
		    else
			{
			sprintf (s, "@(%#x,pc),r%u (= 0x%08x)",
				 disp, (insn & 0x0f00) >> 8, *dPtr);
			}
		    }
		    break;

		default:
		    strcpy (s, "????");
		}

									break;

#if (CPU==SH7700 || CPU==SH7600)
        case itGetDispPc:
	    {
	    char sym [MAX_SYS_SYM_LEN + 1];

	    switch (iPtr->op)
		{
		case 0x8e00:
		case 0x8c00: /* allows negative ofsets */
		    if (insn & 0x0080)
		        disp = (insn | 0xff00) << 1; 
		    else
		        disp = (insn & 0x00ff) << 1; 
		    break;
		default:     
		    disp = 0;
		    break;
		}
	    addr = (UINT32)(address + 4 + (INT16)disp);
	    dsmFormatAdrs (addr, sym);

	    sprintf (s, "@(%#x,pc)       (==> %s)", disp, sym);
	    }
									break;
#endif /* CPU==SH7700 || CPU==SH7600 */
	case itImmAtR0Gbr:
	    sprintf (s, "#0x%x,@(r0,gbr)",   insn & 0x00ff);		break;
	case itImmToR0:
	    switch (iPtr->op)
		{
		case 0x8800:
		    sprintf (s, "#0x%x,r0", (INT8)(insn & 0x00ff));	break;
		default:
		    sprintf (s, "#0x%x,r0",        insn & 0x00ff );
		}
									break;
	case itImm:
	    sprintf (s, "#%d",		insn & 0x00ff);			break;
	case itImmToRn:
	    sprintf (s, "#%d,r%u",(INT8)(insn & 0x00ff),
				        (insn & 0x0f00) >> 8);		break;
	default:
	    strcpy (s, "unknown instruction type.");
	}
    }

/*******************************************************************************
*
* dsmFormatAdrs - prints addresses as symbols, if an exact match can be found
*
* NOMANUAL
*/
 
LOCAL void dsmFormatAdrs
    (
    int address,		/* address to print */
    char *s
    )
    {
    char *label; /* pointer to symbol table copy of name */
    void *actVal;
    SYMBOL_ID symId;
    char demangled[MAX_SYS_SYM_LEN + 1];
    char *labelToPrint;
 
    if ((symFindSymbol (sysSymTbl, NULL, (void *)address, 
			SYM_MASK_NONE, SYM_MASK_NONE, &symId) == OK) &&
	(symNameGet (symId, &label) == OK) &&
	(symValueGet (symId, &actVal) == OK) &&
	(actVal == (void *)address))
	{
	labelToPrint = cplusDemangle(label, demangled, sizeof (demangled));
	sprintf (s, "%s", labelToPrint);
	}
    else
	sprintf (s, "0x%08x", address);
    }


#if (CPU==SH7750 || CPU==SH7700)
/*******************************************************************************
*
* dsmFindFpp - lookup FPP insn
*
* FPP instrctions may be either 16 or 32 bit; 
*
* NOMANUAL
*/

LOCAL INST *dsmFindFpp
    (
    USHORT fppInst []
    )
    {
    INST *fppPtr;

    /* Find out which instruction it is */

    for (fppPtr = &instFpp [0]; fppPtr->mask != 0; fppPtr++)
         {
         if ((fppInst [0] & fppPtr->mask) == fppPtr->op) return (fppPtr);
	 }

    /* If we're here, we couldn't find it */

    errnoSet (S_dsmLib_UNKNOWN_INSTRUCTION);
    return (NULL);
    }


/*******************************************************************************
*
* dsmPrintFpp - print SH FPP insn
*
*/
LOCAL void dsmPrintFpp
    (
    USHORT fppInst [],		/* Pointer to instructin */
    INST *fppPtr,		/* Pointer to INST returned by dsmFindFpp */
    int address,		/* Address with which to prepend instructin */
    int nwords			/* Instruction length, in words */
    )
    {
    int ix;                /* index into binInst */
    int wordsToPrint;      /* # of 5-char areas to reserve for printing
				   of hex version of instruction */
    BOOL slotInst;              /* TRUE if instruction is in delayed slot */

    slotInst = (delaySlot == TRUE) && ((address - lastAddress) == 2);

    wordsToPrint = (((nwords - 1) / 2) + 1) * 2;

    /* Print the address and the instruction, in hex */

    printf ("%06x  ", address);

    for (ix = 0; ix < wordsToPrint; ++ix)
        /* print lines in multiples of 5 words */
        {
	if ((ix > 0) && (ix % 3) == 0)          /* print words on next line */
	    printf ("\n        ");
	printf ((ix < nwords) ? "%04x " : "     ", fppInst [ix]);
	}

    if (slotInst) printf (" (");
    else          printf ("  ");

    if (fppPtr == NULL)
        {
        printf (".short  0x%04x", fppInst[0]);
        delaySlot = FALSE;
        }
	
    else
    {
    char s[64 + MAX_SYS_SYM_LEN + 1];

    /* Print the instruction mnemonic, the size code (.w, or whatever),
       and the arguments */

    prtArgsFpp (fppInst, fppPtr, address, s);
    printf ("%-10s %s", fppPtr->name, s);

    if (fppPtr->type & itDelay) delaySlot = TRUE;
    else                      delaySlot = FALSE;
    }

    if (slotInst) printf (")\n");
    else          printf ("\n");

    lastAddress = address;
    }


/******************************************************************************
*
* prtArgsFpp - format FP arguments
*
* NOMANUAL
*/

LOCAL void prtArgsFpp
    (
    USHORT fppInst [],  /* Pointer to the binary instruction */
    INST *fppPtr,    /* Pointer to the INST describing binInst */
    int address,        /* Address at which the instruction resides */
    char *s
    )
    {
    USHORT  finsn = fppInst [0];

    switch (fppPtr->type & itTypeMask)
        {
        case itOneFpReg:
            sprintf (s, "fr%u",         (finsn & 0x0f00) >> 8);          break;

	case itTwoFpReg:
            sprintf (s, "fr%u,fr%u",    (finsn & 0x00f0) >> 4,
                                        (finsn & 0x0f00) >> 8);          break;

	case itFloadFpul:
            sprintf (s, "fr%u,fpul",    (finsn & 0x0f00) >> 8);          break;

        case itFstoreFpul:
            sprintf (s, "fpul,fr%u",    (finsn & 0x0f00) >> 8);          break;

        case itThreeFpReg:
            sprintf (s, "fr0,fr%u,fr%u",(finsn & 0x00f0) >> 4,
                                        (finsn & 0x0f00) >> 8);          break;
        case itGetFRnAtR0Rm:
            sprintf (s, "@(r0,r%u),fr%u",(finsn & 0x00f0) >> 4,
                                        (finsn & 0x0f00) >> 8);          break;
        case itPopFRn:
            sprintf (s, "@r%u+,fr%u",   (finsn & 0x00f0) >> 4,
                                        (finsn & 0x0f00) >> 8);          break;
        case itGetFRnAtRm:
            sprintf (s, "@r%u,fr%u",    (finsn & 0x00f0) >> 4,
                                        (finsn & 0x0f00) >> 8);          break;
        case itPutFRmAtR0Rn:
            sprintf (s, "fr%u,@(r0,r%u)",(finsn & 0x00f0) >> 4,
                                        (finsn & 0x0f00) >> 8);          break;
        case itPushFRm:
            sprintf (s, "fr%u,@-r%u",   (finsn & 0x00f0) >> 4,
                                        (finsn & 0x0f00) >> 8);          break;

	case itPutFRmAtRn:
            sprintf (s, "fr%u,@r%u",    (finsn & 0x00f0) >> 4,
                                        (finsn & 0x0f00) >> 8);          break;

        case itLoadFpscr:
            sprintf (s, "r%u,fpscr",    (finsn & 0x0f00) >> 8);          break;

        case itLoadFpul:
            sprintf (s, "r%u,fpul",     (finsn & 0x0f00) >> 8);          break;

        case itPopFpscr:
            sprintf (s, "@r%u+,fpscr",  (finsn & 0x0f00) >> 8);          break;

        case itPopFpul:
            sprintf (s, "@r%u+,fpul",   (finsn & 0x0f00) >> 8);          break;

        case itStoreFpscr:
            sprintf (s, "fpscr,r%u",    (finsn & 0x0f00) >> 8);          break;

        case itStoreFpul:
            sprintf (s, "fpul,r%u",     (finsn & 0x0f00) >> 8);          break;

        case itPushFpscr:
            sprintf (s, "fpscr,@-r%u",  (finsn & 0x0f00) >> 8);          break;

        case itPushFpul:
            sprintf (s, "fpul,@-r%u",   (finsn & 0x0f00) >> 8);          break;

#if (CPU==SH7750)
	case itComplete:
	    s[0] = '\0';/* No arguments */				 break;

        case itFipr:
            sprintf (s, "fv%u,fv%u",    (finsn & 0x0300) >> 8,
                                        (finsn & 0x0c00) >> 10);         break;

        case itFtrv:
            sprintf (s, "xmtrx,fv%u",   (finsn & 0x0c00) >> 10);         break;

        case itConvToDp:
            sprintf (s, "fpul,dr%u",    (finsn & 0x0e00) >> 8);          break;

        case itConvToSp:
            sprintf (s, "dr%u,fpul",    (finsn & 0x0e00) >> 8);          break;

#endif /* CPU==SH7750 */
        default:
            strcpy (s, "unknown instruction type.");			 break;
        }
    }
#endif /* (CPU==SH7750 || CPU==SH7700) */

#if (CPU==SH7700 || CPU==SH7600)
/*******************************************************************************
*
* dsmFindDsp - lookup SH-DSP insn
*
* SH-DSP instrctions may be either 16 or 32 bit; if 16 bit, then the 
* instruction is in low half of the longword.
*
* NOMANUAL
*/
LOCAL SH_DSP_OPCODE_INFO *dsmFindDsp
    (
    ULONG long insn,
    ULONG long flags
    )
    {
    SH_DSP_OPCODE_INFO *op;

    for (op = instDsp; op->name; op++) 
	{
	if (((insn & op->mask) == op->insn)
	    && (!flags || (op->flags & flags)))
	    return op;
	}

    /* If we're here, we couldn't find it */
    errnoSet (S_dsmLib_UNKNOWN_INSTRUCTION);
    return NULL;
    }

/*******************************************************************************
*
* printDspArgs - print SH DSP insn args
*
*/
LOCAL void printDspArgs
    (
    ULONG insn,
    SH_DSP_OPCODE_INFO *op,
    VOIDFUNCPTR prtAddress
    )
    {     
    int n;
    long imm;
    LOCAL char *se[] = { "x0", "x1", "y0", "a1" };
    LOCAL char *sf[] = { "y0", "y1", "x0", "a1" };
    LOCAL char *sx[] = { "x0", "x1", "a0", "a1" };
    LOCAL char *sy[] = { "y0", "y1", "m0", "m1" };
    LOCAL char *dg[] = { "m0", "m1", "a0", "a1" };
    LOCAL char *ds[] = { "<illegal>", "<illegal>", "<illegal>", "<illegal>",
			  "<illegal>", "a1",        "<illegal>", "a0",
			  "x0",        "x1",        "y0",        "y1",
			  "m0",        "a1g",       "m1",        "a0g" };

    LOCAL char *du[] = { "x0", "y0", "a0", "a1" };
    LOCAL char *dx[] = { "x0", "x1" };
    LOCAL char *dy[] = { "y0", "y1" };
    LOCAL char *dz[] = { "<illegal>", "<illegal>", "<illegal>", "<illegal>",
			  "<illegal>", "a1",        "<illegal>", "a0",
			  "x0",        "x1",        "y0",        "y1",
			  "m0",        "<illegal>", "m1",        "<illegal>" };

    for (n = 0; (n < 8) && (op->arg[n] != D_END); ++n)
	{
	if ((n == 3) && (op->flags & SH_PMULS))
	    printf (" pmuls ");
	else if (n && (n < 7) && (op->arg[n] != D_END))
	    printf (",");

	switch (op->arg[n])
	    {
	    case D_AS:
		switch ((insn >> 2) & 0x03)
		    {
		    case 0:
			printf ("@-as%ld", (insn >> 8) & 0x03);
			break;
		    case 1:
			printf ("@as%ld", (insn >> 8) & 0x03);
			break;
		    case 2:
			printf ("@as%ld+", (insn >> 8) & 0x03);
			break;
		    case 3:
			printf ("@as%ld+is", (insn >> 8) & 0x03);
			break;
		    }
		break;
	    case D_AX:
		if (insn & 0x0200)
		    printf ("@ax1");
		else
		    printf ("@ax0");
		switch ((insn & 0x0c) >> 2)
		    {
		    case 1:
			break;
		    case 2:
			printf ("+");
			break;
		    case 3:
			printf ("+ix");
			break;
		    default:
			printf ("<illegal>");
			break;
		    }
		break;
	    case D_AY:
		if (insn & 0x0100)
		    printf ("@ay1");
		else
		    printf ("@ay0");
		switch (insn & 0x03)
		    {
		    case 1:
			break;
		    case 2:
			printf ("+");
			break;
		    case 3:
			printf ("+iy");
			break;
		    }
		break;
	    case D_DAX:
	        if (insn & 0x0080)
 	            printf ("a1");
 	        else
 	            printf ("a0");
	        break;
	    case D_DAY:
 	        if (insn & 0x0040)
 	            printf ("a1");
 	        else
 	            printf ("a0");
 	        break;
	    case D_DG:
		printf ("%s", dg [(insn & GG_3) >> GG_SHIFT]);
		break;
	    case D_DU:
		printf ("%s", du [(insn & UU_3) >> UU_SHIFT]);
		break;
	    case D_DS:
		printf ("%s", ds [(insn & 0x00f0) >> 4]);
		break;
	    case D_DX:
		printf ("%s", dx [(insn & 0x0080) >> 7]);
		break;
	    case D_DY:
		printf ("%s", dy [(insn & 0x0040) >> 6]);
		break;
	    case D_DZ:
		printf ("%s", dz [(insn & ZZ_F) >> ZZ_SHIFT]);
		break;
	    case D_IMM:
		imm = (insn >> 4) & 0x7f;
		if (imm & 0x40)
	            printf ("#%ld", ((imm << 25) >> 25));
		else
		    printf ("#%ld", imm);
		break;
	    case D_MACH:
		printf ("mach");
		break;
	    case D_MACL:
		printf ("macl");
		break;
	    case D_SE:
		printf ("%s", se [(insn & EE_3) >> EE_SHIFT]);
		break;
	    case D_SF:
		printf ("%s", sf [(insn & FF_3) >> FF_SHIFT]);
		break;
	    case D_SX:
		printf ("%s", sx [(insn & XX_3) >> XX_SHIFT]);
		break;
	    case D_SY:
		printf ("%s", sy [(insn & YY_3) >> YY_SHIFT]);
		break;
	    default:
		printf ("<illegal>");
		break;
	    }
        }
    }

/*******************************************************************************
*
* dsmPrintDsp - print a disassembled SH3 DSP instruction
*
* This routine prints an instruction in disassembled form.  It takes
* as input a pointer to the instruction, an address with which to
* prepend the instruction, a pointer to a function for printing the
* address.
*
* INTERNAL
* The format of the disassembled output starts with the address and hexadecimal
* representation of the instruction. The mnemonic and any instruction modifiers
* typically follow, then the operands. The output should reflect the syntax of
* the assembler input. Use spacing to align and enhance the readability of the
* disassembly. [Arch Port Kit]
*
*/

LOCAL int dsmPrintDsp
    (
    USHORT *memaddr,		/* pointer to instruction */
    int address,                /* Address prepended to instruction */
    VOIDFUNCPTR prtAddress	/* Address printing function */
    )    
    {
    ULONG insn;
    int size = 2;
    SH_DSP_OPCODE_INFO *op;
    BOOL slotInst;		/* TRUE if instruction is in delayed slot */

    slotInst = (delaySlot == TRUE) && ((address - lastAddress) == 2);
    delaySlot = FALSE;		/* No branches in DSP insn's */
    lastAddress = address;

    /* Print the address, in hex */
    printf ("%06x  ", address);

    insn = *memaddr & 0xfc00;
    if (insn == 0xf800)
	{
	size = 2;
	insn = (*memaddr << 16) | (*(memaddr + 1));
	printf ("%04x %04x ", *memaddr, *(memaddr + 1));
	}
    else
	{
	size = 1;
	insn = *memaddr;
	printf ("%04x      ", *memaddr);
	}

    if (slotInst) 
	printf (" (");
    else          
	printf ("  ");

    op = dsmFindDsp (insn, 0);
    if (!op) 
	/* if not found, then print 16 bit word and advance by 2 bytes */
	{
	printf ("   .short 0x%04x", *memaddr);
    	if (slotInst) printf (")\n");
	else          printf ("\n");
	return 2;
	}

    /* found match */
    if (op->flags & SH_DCT)
	printf ("dct ");
    else if (op->flags & SH_DCF)
        printf ("dcf ");

    if (op->flags & (SH_MOVX | SH_MOVY))
	insn &= 0x03ff;
    else
	{
	if (op->flags & (SH_DCF | SH_DCT))
	    printf ("%-6s ", op->name);
	else
	    printf ("%-10s ", op->name);

	printDspArgs (insn, op, prtAddress);
	if (!(op->flags & SH_MOVS))
	    insn = (insn >> 16) & 0x03ff;
	}
	
    /* extract and print parallel moves if needed */
    if (!(op->flags & SH_MOVS))
	{
	int nopy;
	int nopx;
	int first;
	SH_DSP_OPCODE_INFO *mov_op;
	
	nopx = !(insn & MOVX_MASK);
	nopy = !(insn & MOVY_MASK);

	first = (op->flags & (SH_MOVX | SH_MOVY));
	/* MOVX */
	if (!nopx)
	    {
	    mov_op = dsmFindDsp ((insn & MOVX_MASK) | 0xf000, SH_MOVX);
	    if (!first)
		printf (" %s ", mov_op->name);
	    else
		printf ("%-10s ", mov_op->name);
	    printDspArgs (insn, mov_op, prtAddress);
	    first = 0;
	    }
	if (!nopy)
	    {
	    mov_op = dsmFindDsp ((insn & MOVY_MASK) | 0xf000, SH_MOVY);
	    if (!first)
		printf (" %s ", mov_op->name);
	    else
		printf ("%-10s ", mov_op->name);
	    printDspArgs (insn, mov_op, prtAddress);
	    first = 0;
	    }
	if (nopx && nopy && (op->flags & (SH_MOVX | SH_MOVY)))
	    {
	    if (!first)
	        printf (" ");
	    printf ("nopx");
	    }
	}
    if (slotInst) printf (")\n");
    else          printf ("\n");

    return size;
    }	
#endif /* CPU==SH7700 || CPU==SH7600 */

/*******************************************************************************
*
* nPrtAddress - print addresses as numbers
*/

LOCAL void nPrtAddress
    (
    int address
    )
    {
    printf ("%#x", address);
    }

/*******************************************************************************
*
* dsmNwords - return the length (in words) of an instruction
*/

LOCAL int dsmNwords
    (
    USHORT binInst [],
    FAST INST *iPtr
    )
    {
    return (1);
    }

#if (CPU==SH7700 || CPU==SH7750)
/*******************************************************************************
*
* dsmFppNwords - return the length (in words) of an instruction
*/

LOCAL int dsmFppNwords
    (
    USHORT binInst [],
    FAST INST *fppPtr
    )
    {
    return (1);
    }
#endif /* (CPU==SH7700 || CPU==SH7750) */

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
* If <prtAddress> is zero, dsmInst() will use a default routine that prints
* addresses as hex numbers.
*
* ADDRESS-PRINTING ROUTINE
* Many assembly language operands are addresses.  In order to print these
* addresses symbolically, dsmInst() calls a user-supplied routine, passed as a
* parameter, to do the actual printing.  The routine should be declared as:
* .CS
*    void prtAddress (address)
*        int address;   /@ address to print @/
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
* The directive .short (declare short) is printed for unrecognized instructions.
*
* RETURNS : The number of 16-bit words occupied by the instruction.
*/

int dsmInst
    (
    FAST USHORT *binInst,       /* Pointer to the instruction */
    int address,                /* Address prepended to instruction */
    VOIDFUNCPTR prtAddress      /* Address printing function */
    )
    {
    FAST INST *iPtr;
    FAST int size;

    if (prtAddress == NULL)
        prtAddress = nPrtAddress;

#if (CPU==SH7700 || CPU==SH7600)
    if (dspProbe () == OK)
	{
	if ((*binInst & 0xf000) == 0xf000)
	    return (dsmPrintDsp (binInst, address, prtAddress));
	}
#endif /* CPU==SH7700 || CPU==SH7600 */

#if (CPU==SH7700 || CPU==SH7750)
    if (fppProbe () == OK)
	{
        if ((iPtr = dsmFindFpp (binInst)) != NULL)
	    {
	    size = dsmFppNwords (binInst, iPtr);
	    dsmPrintFpp (binInst, iPtr, address, size);
    	    return (size);
	    }
	}
#endif /* CPU==SH7700 || CPU==SH7750 */

    iPtr = dsmFind (binInst);
    size = dsmNwords (binInst, iPtr);
    dsmPrint (binInst, iPtr, address, size); 

    return (size);
    }

/*******************************************************************************
*
* dsmNbytes - determine the size of an instruction
*
* This routine determines the size, in bytes, of an instruction.
* It returns a constant, 4, if the instruction is found, and is preserved for
* compatibility with the 680x0 version.
*
* RETURNS:
* A constant, or 0 if the instruction is unrecognized.
*
* INTERNAL
* The number os bytes in an instruction is returned by this function. For RISCs
* this is often a constant. For CISCs, this function may be a simplified version
* of the dsmFind() routine. The type should be a key to the number of bytes, or
* an explicit entry in the INST structure may be necessary. Make a design trade-
* off between complexity and the amount of space needed to use the LOCAL array
* INST. [Arch Port Kit]
*
* This function appears to be obsolete; it is no longer
* used in dbgLib.c.
*/

int dsmNbytes 
    (
    USHORT *binInst		/* pointer to the instruction */
    )
    {
    FAST INST *iPtr;

    if (binInst == NULL)
	return (0);

#if (CPU==SH7700 || CPU==SH7600)
    if (dspProbe () == OK)
	{
	/* DSP instructions start with 0xf000 */

	if ((*binInst & 0xf000) == 0xf000)
	    {
	    ULONG insn;
	    if ((*binInst & 0xfc00) == 0xf800)
		insn = (ULONG) (*binInst << 16) | (*(binInst + 1));
	    else
		insn = (ULONG) *binInst;
	    if (dsmFindDsp (insn, 0) != NULL)
	        return ((*binInst & 0xfc00) ? 4 : 2);
	    }
	}
#endif /* CPU==SH7700 || CPU==SH7600 */

#if (CPU==SH7700 || CPU==SH7750)
    if (fppProbe () == OK)
	{
	/* FP instructions start with 0xf000 */

	if ((*binInst & 0xf000) == 0xf000)
            if (dsmFindFpp (binInst) != NULL)
    		return (2);
	}
#endif /* CPU==SH7700 || CPU==SH7750 */

    /* Not DSP, nor FP */
    
    if ((iPtr = dsmFind (binInst)) != NULL)
	{
	/* Make sure to skip delay slot instructions */

	if (iPtr->type & itDelay)
	    return (4);
	else
	    return (2);
	}

    /* Nothing found  */

    return 0;
    }
