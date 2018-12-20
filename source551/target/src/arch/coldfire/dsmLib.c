/* dsmLib.c - ColdFire disassembler */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01f,26nov01,dee  remove references to MCF5200
01e,19nov00,dh  Fix typo.
01d,02oct00,bittner INTOUCH instruction, corrected CPUSHL, removed all #ifdef MCF5200
		    from the code. Only parts of the instruction table are idef'ed.
		    (if the instruction isn't found in the table, the corresponding code
		    will not be executed anyway)
01c,29sep00,bittner Multiply and Accumulate (MAC) and v4 instruction set enhancements
01b,19jun00,ur   Removed all non-Coldfire stuff.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
This library contains everything necessary to print Coldfire object code in
assembly language format.  The disassembly is done in Motorola format.

The programming interface is via dsmInst(), which prints a single disassembled
instruction, and dsmNbytes(), which reports the size of an instruction.

To disassemble from the shell, use l(), which calls this
library to do the actual work.  See dbgLib() for details.

INCLUDE FILE: dsmLib.h

SEE ALSO: dbgLib
*/

#include "vxWorks.h"
#include "dsmLib.h"
#include "symLib.h"
#include "string.h"
#include "stdio.h"
#include "errnoLib.h"

#define LONGINT	 	0
#define SINGLEREAL	1
#define EXTENDEDREAL	2
#define PACKEDDECIMAL	3
#define WORDINT		4
#define DOUBLEREAL	5
#define BYTEINT		6

/* forward static functions */

static INST *dsmFind (USHORT binInst [ ]);
static void dsmPrint (USHORT binInst [ ], INST *iPtr, int address, int
		nwords, FUNCPTR prtAddress);
static int dsmNwords (USHORT binInst [ ], INST *iPtr);
static int fppNwords (USHORT mode, USHORT reg, USHORT rm, USHORT src, USHORT
		extension [ ]);
static int modeNwords (USHORT mode, USHORT reg, int size, USHORT extension [
		]);
static int mode6And7Words (USHORT extension [ ]);
static void prtArgs (USHORT binInst [ ], INST *iPtr, int address, FUNCPTR
		prtAddress);
static void prContReg (USHORT contReg);
static void prEffAddr (USHORT mode, USHORT reg, USHORT extension [ ], int
		size, FUNCPTR prtAddress);
static void prMovemRegs (USHORT extension, USHORT mode);
static void prFmovemr (USHORT mode, USHORT rlist);
static void prFmovemcr (USHORT rlist);
static void prtSizeField (USHORT binInst [ ], INST *iPtr);
static void nPrtAddress (int address);
static void prOffWid (USHORT dO, USHORT offset, USHORT dW, USHORT width);
static void prIndirectIndex (USHORT extension [ ], USHORT mode, USHORT reg);
static void prDisplace (USHORT size, USHORT pDisp [ ]);

/* 
 * include MAC (5206e and 53xx) CPUs
 * and V4 enhancements
 * 
 */
#define MCF52PLUS		/* additions to instruction set for MCF5200 and higher */
#define INCLUDE_MAC		/* multiply and accumulate instructions */
#if (CPU==MCF5400)
#define INCLUDE_V4		/* Coldfire V4 intruction set enhancements */
#endif

/*
This table is ordered by the number of bits in an instruction's
two word mask, beginning with the greatest number of bits in masks.
This scheme is used for avoiding conflicts between instructions
when matching bit patterns.  The instruction ops are arranged
sequentially within each group of instructions for a particular
mask so that uniqueness can be easily spotted.
*/

#if defined (INCLUDE_MAC)
/*    MAC instructions for Coldfire 5206 & 53xx	*/
LOCAL INST inst_add [] =
    {
    /* 16 bit mask */ 
    {"MOVE",	itMoveTCCR,   0xa9c0, 0x0000,	  0xffc0, 0x0000,    0x00, 0x00},
    
    /*    12 bit mask	*/
    {"MOVE",	itMoveFACC,   0xa180, 0x0000, 0xfff0, 0x0000,  0x00, 0x00},
    {"MOVE",	itMoveFMACSR, 0xa980, 0x0000, 0xfff0, 0x0000,  0x00, 0x00},
    {"MOVE",	itMoveFMASK,  0xad80, 0x0000, 0xfff0, 0x0000,  0x00, 0x00},
    
    /*    10 bit mask	*/
    {"MOVE",	itMoveTACC,   0xa100, 0x0000, 0xffc0, 0x0000,  0xfc, 0xef},
    {"MOVE",	itMoveTMACSR, 0xa900, 0x0000, 0xffc0, 0x0000,  0xfc, 0xef},
    {"MOVE",	itMoveTMASK,  0xad00, 0x0000, 0xffc0, 0x0000,  0xfc, 0xef},
    
    /*    9 bit mask	*/
    {"MAC",	itMac,        0xa000, 0x0000, 0xf1b0, 0x0100,  0x00, 0x00},
    {"MSAC",	itMsac,       0xa000, 0x0100, 0xf1b0, 0x0100,  0x00, 0x00},
    
     /*    8 bit mask	*/
    {"MACL",	itMacl,       0xa080, 0x0000, 0xf180, 0x0110,  0xc3, 0x00},
    {"MSACL",	itMsacl,      0xa080, 0x0100, 0xf180, 0x0110,  0xc3, 0x00},
    {""	    ,	0,	      0,      0,      0,      0,       0,    0   }
    };
#endif

LOCAL INST inst [] =
    {
    /*   26 bit mask */
    {"DIVU",	itDivL, 0x4c40, 0x0000,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVS",	itDivL, 0x4c40, 0x0800,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVU",	itDivL, 0x4c40, 0x1001,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVS",	itDivL, 0x4c40, 0x1801,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVU",	itDivL, 0x4c40, 0x2002,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVS",	itDivL, 0x4c40, 0x2802,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVU",	itDivL, 0x4c40, 0x3003,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVS",	itDivL, 0x4c40, 0x3803,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVU",	itDivL, 0x4c40, 0x4004,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVS",	itDivL, 0x4c40, 0x4804,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVU",	itDivL, 0x4c40, 0x5005,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVS",	itDivL, 0x4c40, 0x5805,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVU",	itDivL, 0x4c40, 0x6006,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVS",	itDivL, 0x4c40, 0x6806,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVU",	itDivL, 0x4c40, 0x7007,	  0xffc0, 0xffff,    0x02, 0x00},
    {"DIVS",	itDivL, 0x4c40, 0x7807,	  0xffc0, 0xffff,    0x02, 0x00},

#if defined (MCF52PLUS)
    {"WDEBUG",	itWDebug, 0xfbc0, 0x0003, 0xffc0, 0xffff,    0x00, 0x00},
#endif /* MCF52PLUS */

    /*   24 bit mask */
    {"ORI",	itImmCCR, 0x003c, 0x0000, 0xffff, 0xff00,    0x00, 0x00},
								    /* to CCR */
    {"ANDI",	itImmCCR, 0x023c, 0x0000, 0xffff, 0xff00,    0x00, 0x00},
								    /* to CCR */
    {"EORI",	itImmCCR, 0x0a3c, 0x0000, 0xffff, 0xff00,    0x00, 0x00},
								   /* to CCR */
    {"CAS2",	itCas2,   0x0cfc, 0x0000, 0xffff, 0x0e38,    0x00, 0x00},
    {"CAS2",	itCas2,   0x0efc, 0x0000, 0xffff, 0x0e38,    0x00, 0x00},

    /*     22 bit mask	*/
    {"CHK2",	itChk2, 0x00c0, 0x0800,	  0xffc0, 0x0fff,    0x9b, 0x10},
    {"CMP2",	itChk2, 0x00c0, 0x0000,	  0xffc0, 0x0fff,    0x9b, 0x10},
    {"CHK2",	itChk2, 0x02c0, 0x0800,   0xffc0, 0x0fff,    0x9b, 0x10},
    {"CMP2",	itChk2, 0x02c0, 0x0000,	  0xffc0, 0x0fff,    0x9b, 0x10},
    {"CHK2",	itChk2, 0x04c0, 0x0800,	  0xffc0, 0x0fff,    0x9b, 0x10},
    {"CMP2",	itChk2, 0x04c0, 0x0000,	  0xffc0, 0x0fff,    0x9b, 0x10},
    {"MOVES",	itMoves,0x0e00, 0x0000,   0xffc0, 0x0fff,    0x83, 0x1c},
    {"MOVES",	itMoves,0x0e40, 0x0000,   0xffc0, 0x0fff,    0x83, 0x1c},
    {"MOVES",	itMoves,0x0e80, 0x0000,   0xffc0, 0x0fff,    0x83, 0x1c},

    /*     21 bit mask	*/
    {"CAS",	itCas, 0x0ac0, 0x0000,	  0xffc0, 0xfe38,    0x83, 0x1c},
    {"CAS",	itCas, 0x0cc0, 0x0000,	  0xffc0, 0xfe38,    0x83, 0x1c},
    {"CAS",	itCas, 0x0ec0, 0x0000,	  0xffc0, 0xfe38,    0x83, 0x1c},

    /*   Fpp instructions */
    {"FABS",	itFabs,   0xf200, 0x0018,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FACOS",   itFacos,  0xf200, 0x001c,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FADD",    itFadd,   0xf200, 0x0022,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FASIN",	itFasin,  0xf200, 0x000c,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FATAN",	itFatan,  0xf200, 0x000a,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FATANH",	itFatanh, 0xf200, 0x000b,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FCMP",	itFcmp,   0xf200, 0x0038,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FCOS",	itFcos,   0xf200, 0x001d,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FCOSH",	itFcosh,  0xf200, 0x0019,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FDB",	itFdb,    0xf248, 0x0000,   0xfff8, 0xffc0,    0x00, 0x00},
    {"FDIV",	itFdiv,   0xf200, 0x0020,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FETOX",	itFetox,  0xf200, 0x0010,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FETOXM1",	itFetoxm1,0xf200, 0x0008,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FGETEXP",	itFgetexp,0xf200, 0x001e,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FGETMAN",	itFgetman,0xf200, 0x001f,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FINT",	itFint,   0xf200, 0x0001,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FINTRZ",	itFintrz, 0xf200, 0x0003,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FLOG10",	itFlog10, 0xf200, 0x0015,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FLOG2",	itFlog2,  0xf200, 0x0016,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FLOGN",	itFlogn,  0xf200, 0x0014,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FLOGNP1",	itFlognp1,0xf200, 0x0006,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FMOD",	itFmod,   0xf200, 0x0021,   0xffc0, 0xa07f,    0x02, 0x00},
    {"FMOVE",	itFmove,  0xf200, 0x0000,   0xffc0, 0xffff,    0x00, 0x00},
    {"FMOVE",	itFmove,  0xf200, 0x4000,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FMOVE",	itFmovek, 0xf200, 0x6000,   0xffc0, 0xe000,    0x82, 0x1c},
    {"FMOVE",	itFmovel, 0xf200, 0x8000,   0xffc0, 0xe3ff,    0x00, 0x00},
    {"FMOVE",	itFmovel, 0xf200, 0xa000,   0xffc0, 0xe3ff,    0x80, 0x1c},
    {"FMOVECR",	itFmovecr,0xf200, 0x5c00,   0xffc0, 0xfc00,    0x00, 0x00},
    {"FMOVEM",	itFmovem, 0xf200, 0xc000,   0xffc0, 0xe700,    0x83, 0x10},
    {"FMOVEM",	itFmovem, 0xf200, 0xe000,   0xffc0, 0xe700,    0x83, 0x1c},
    {"FMOVEM",	itFmovemc,0xf200, 0xc000,   0xffc0, 0xe3ff,    0x00, 0x00},
    {"FMOVEM",	itFmovemc,0xf200, 0xe000,   0xffc0, 0xe3ff,    0x80, 0x1c},
    {"FMUL",	itFmul,   0xf200, 0x0023,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FMUL",	itFmul,   0xf200, 0x4023,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FNEG",	itFneg,   0xf200, 0x001a,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FNEG",	itFneg,   0xf200, 0x401a,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FNOP",	itFnop,   0xf200, 0x0000,   0xffc0, 0xffff,    0x00, 0x00},
    {"FREM",	itFrem,   0xf200, 0x0025,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FREM",	itFrem,   0xf200, 0x4025,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FSCALE",	itFscale, 0xf200, 0x0026,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FSCALE",	itFscale, 0xf200, 0x4026,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FS",	itFs,     0xf200, 0x0000,   0xffc0, 0xffc0,    0x82, 0x1c},
    {"FSGLDIV",	itFsgldiv,0xf200, 0x0024,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FSGLDIV",	itFsgldiv,0xf200, 0x4024,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FSGLMUL",	itFsglmul,0xf200, 0x0027,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FSGLMUL",	itFsglmul,0xf200, 0x4027,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FSIN",	itFsin,   0xf200, 0x000e,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FSIN",	itFsin,   0xf200, 0x400e,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FSINCOS",	itFsincos,0xf200, 0x0030,   0xffc0, 0xe078,    0x00, 0x00},
    {"FSINCOS",	itFsincos,0xf200, 0x4030,   0xffc0, 0xe078,    0x00, 0x00},
    {"FSINH",	itFsinh,  0xf200, 0x0002,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FSINH",	itFsinh,  0xf200, 0x4002,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FSQRT",	itFsqrt,  0xf200, 0x0004,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FSQRT",	itFsqrt,  0xf200, 0x4004,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FSUB",	itFsub,   0xf200, 0x0028,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FSUB",	itFsub,   0xf200, 0x4028,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FTAN",	itFtan,   0xf200, 0x000f,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FTAN",	itFtan,   0xf200, 0x400f,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FTANH",	itFtanh,  0xf200, 0x0009,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FTANH",	itFtanh,  0xf200, 0x4009,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FTENTOX",	itFtentox,0xf200, 0x0012,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FTENTOX",	itFtentox,0xf200, 0x4012,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FTRAP",	itFtrap,  0xf200, 0x0000,   0xffc0, 0xffc0,    0x00, 0x00},
    {"FTST",	itFtst,   0xf200, 0x003a,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FTST",	itFtst,   0xf200, 0x403a,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FTWOTOX",	itFtwotox,0xf200, 0x0011,   0xffc0, 0xe07f,    0x00, 0x00},
    {"FTWOTOX",	itFtwotox,0xf200, 0x4011,   0xffc0, 0xe07f,    0x02, 0x00},
    {"FB",	itFb,     0xf280, 0x0000,   0xff80, 0x0000,    0x00, 0x00},
    {"FRESTORE",itFrestore,0xf340,0x0000,   0xffc0, 0x0000,    0x93, 0x10},
    {"FSAVE",	itFsave,  0xf300, 0x0000,   0xffc0, 0x0000,    0x8b, 0x1c},

    /*     20 bit mask	*/
    {"DIVUL",	itDivL,    0x4c40, 0x0000,   0xffc0, 0x8ff8,    0x02, 0x00},
    {"DIVU",	itDivL,    0x4c40, 0x0400,   0xffc0, 0x8ff8,    0x02, 0x00},
    {"DIVSL",	itDivL,    0x4c40, 0x0800,   0xffc0, 0x8ff8,    0x02, 0x00},
    {"DIVS",	itDivL,    0x4c40, 0x0c00,   0xffc0, 0x8ff8,    0x02, 0x00},
    {"cpDBcc",	itCpDbcc,  0xf048, 0x0000,   0xf1f8, 0xffc0,    0x00, 0x00},
    {"cpTRAP",	itCpTrapcc,0xf078, 0x0000,   0xf1f8, 0xffc0,    0x00, 0x00},

    /*    19 bit mask	*/
    {"MULS",	itDivL, 0x4c00, 0x0800,	  0xffc0, 0x8bf8,    0x02, 0x00},
    {"MULU",	itDivL, 0x4c00, 0x0000,	  0xffc0, 0x8bf8,    0x02, 0x00},

    /*    18 bit mask	*/
    {"BTST",	itStatBit, 0x0800,0x0000,   0xffc0, 0xff00,    0x82, 0x10},
    {"BCHG",	itStatBit, 0x0840,0x0000,   0xffc0, 0xff00,    0x82, 0x1c},
    {"BCLR",	itStatBit, 0x0880,0x0000,   0xffc0, 0xff00,    0x82, 0x1c},
    {"CALLM",	itCallm,   0x06c0,0x0000,   0xffc0, 0xff00,    0x9b, 0x10},

    /*    17 bit mask	*/
    {"BSET",	itStatBit,  0x08c0, 0x0000,  0xffc0, 0xfe00,    0x82, 0x1c},

    /*    16 bit mask */
    {"ANDI",	itImmTSR,   0x027c, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
								    /* to SR */
    {"ORI",	itImmTSR,   0x007c, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
								    /* to SR */
    {"EORI",	itImmTSR,   0x0a7c, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
								    /* to SR */
#if defined ( MCF52PLUS )
    {"HALT",	itComplete, 0x4ac8, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"PULSE",	itComplete, 0x4acc, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
#endif /* MCF52PLUS */
    {"ILL",	itComplete, 0x4afc, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"RESET",	itComplete, 0x4e70, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"NOP",	itComplete, 0x4e71, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"STOP",	itStop,     0x4e72, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"RTE",	itComplete, 0x4e73, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"RTD",	itRTD, 	    0x4e74, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"RTS",	itComplete, 0x4e75, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"TRAPV",	itComplete, 0x4e76, 0x0000,  0xffff, 0x0000,    0x00, 0x00},
    {"RTR",	itComplete, 0x4e77, 0x0000,  0xffff, 0x0000,    0x00, 0x00},

    /*     15 bit mask	*/
    {"MOVEC",	itMovec,    0x4e7a, 0x0000,  0xfffe, 0x0000,    0x00, 0x00},

    /*     14 bit mask	*/
    {"BFCHG",	itBfchg,    0xeac0, 0x0000,  0xffc0, 0xf000,    0x9a, 0x1c},
    {"BFCLR",	itBfchg,    0xecc0, 0x0000,  0xffc0, 0xf000,    0x9a, 0x1c},
    {"BFSET",	itBfchg,    0xeec0, 0x0000,  0xffc0, 0xf000,    0x9a, 0x1c},

    /*    13 bit mask	*/
    {"LINK",	itLinkL,    0x4808, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"SWAP",	itSwap,     0x4840, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"BKPT",	itBkpt,     0x4848, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"EXT",	itExt,      0x4880, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"EXT",	itExt,      0x48c0, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"EXTB",	itExt,      0x49c0, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"LINK",	itLink,     0x4e50, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"UNLK",	itUnlk,     0x4e58, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBT",	itDb,       0x50c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPT",	itTrapcc,   0x50f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBF",	itDb,       0x51c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPF",	itTrapcc,   0x51f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBHI",	itDb,       0x52c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPHI",	itTrapcc,   0x52f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBLS",	itDb,       0x53c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPLS",	itTrapcc,   0x53f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBCC",	itDb,       0x54c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPCC",	itTrapcc,   0x54f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBCS",	itDb,       0x55c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPCS",	itTrapcc,   0x55f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBNE",	itDb,       0x56c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPNE",	itTrapcc,   0x56f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBEQ",	itDb,       0x57c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPEQ",	itTrapcc,   0x57f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBVC",	itDb,       0x58c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPVC",	itTrapcc,   0x58f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBVS",	itDb,       0x59c8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPVS",	itTrapcc,   0x59f8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBPL",	itDb,       0x5ac8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPPL",	itTrapcc,   0x5af8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBMI",	itDb,       0x5bc8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPMI",	itTrapcc,   0x5bf8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBGE",	itDb,       0x5cc8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPGE",	itTrapcc,   0x5cf8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBLT",	itDb,       0x5dc8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPLT",	itTrapcc,   0x5df8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBGT",	itDb, 	    0x5ec8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPGT",	itTrapcc,   0x5ef8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"DBLE",	itDb,       0x5fc8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"TRAPLE",	itTrapcc,   0x5ff8, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"BFTST",	itBfchg,    0xe8c0, 0x0000,  0xffc0, 0xe000,    0x9a, 0x10},
#if defined ( MCF52PLUS )
    {"CPUSHL", itCpush,	    0xf4e8, 0x0000, 0xfff8,  0x0000,    0x00, 0x00},
#endif /* defined ( MCF52PLUS ) */
#if defined ( INCLUDE_V4 )
    {"CPUSHL", itCpush,	    0xf468, 0x0000, 0xfff8,  0x0000,    0x00, 0x00},
    {"CPUSHL", itCpush,	    0xf4a8, 0x0000, 0xfff8,  0x0000,    0x00, 0x00},
    {"SATS",	itSats,	    0x4c80, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
    {"INTOUCH",	itIntouch,  0xf428, 0x0000,  0xfff8, 0x0000,    0x00, 0x00},
#endif

    /*     12 bit mask	*/
    {"RTM",	itRtm, 	    0x06c0, 0x0000,  0xfff0, 0x0000,    0x00, 0x00},
    {"TRAP",	itTrap,     0x4e40, 0x0000,  0xfff0, 0x0000,    0x00, 0x00},
    {"MOVE",	itMoveUSP,  0x4e60, 0x0000,  0xfff0, 0x0000,    0x00, 0x00},
								    /* USP */
    /*    11 bit mask	*/
    {"BFEXTU",	itBfext,    0xe9c0, 0x0000,  0xffc0, 0x8000,    0x9a, 0x10},
    {"BFEXTS",	itBfext,    0xebc0, 0x0000,  0xffc0, 0x8000,    0x9a, 0x10},
    {"BFFFO",	itBfext,    0xedc0, 0x0000,  0xffc0, 0x8000,    0x9a, 0x10},
    {"BFINS",	itBfins,    0xefc0, 0x0000,  0xffc0, 0x8000,    0x9a, 0x1c},

    /*     10 bit mask	*/
    {"ORI",	itImm,      0x0000, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ORI",	itImm,      0x0040, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ORI",	itImm,      0x0080, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ANDI",	itImm,      0x0200, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ANDI",	itImm,      0x0240, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ANDI",	itImm,      0x0280, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SUBI",	itImm,      0x0400, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SUBI",	itImm,      0x0440, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SUBI",	itImm,      0x0480, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ADDI",	itImm,      0x0600, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ADDI",	itImm,      0x0640, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ADDI",	itImm,      0x0680, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"EORI",	itImm,      0x0a00, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"EORI",	itImm,      0x0a40, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"EORI",	itImm,      0x0a80, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"CMPI",	itImm,      0x0c00, 0x0000,  0xffc0, 0x0000,    0x82, 0x10},
    {"CMPI",	itImm,      0x0c40, 0x0000,  0xffc0, 0x0000,    0x82, 0x10},
    {"CMPI",	itImm,      0x0c80, 0x0000,  0xffc0, 0x0000,    0x82, 0x10},
    {"MOVE",	itMoveFSR,  0x40c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
					 		    /* from SR*/
    {"MOVE",	itMoveFCCR, 0x42c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    								    /*from CCR*/
    {"MOVE",	itMoveCCR,  0x44c0, 0x0000,  0xffc0, 0x0000,    0x02, 0x00},
								    /* to CCR */
    {"MOVE",	itMoveTSR,  0x46c0, 0x0000,  0xffc0, 0x0000,    0x02, 0x00},
								    /* to SR */
    {"NBCD",	itNbcd,     0x4800, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"PEA",	itNbcd,     0x4840, 0x0000,  0xffc0, 0x0000,    0x9b, 0x10},
    {"TAS",	itNbcd,     0x4ac0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"JSR",	itNbcd,     0x4e80, 0x0000,  0xffc0, 0x0000,    0x9b, 0x10},
    {"JMP",	itNbcd,     0x4ec0, 0x0000,  0xffc0, 0x0000,    0x9b, 0x10},
    {"ST",	itScc,      0x50c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SF",	itScc,      0x51c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SHI",	itScc,      0x52c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SLS",	itScc,      0x53c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SCC",	itScc,      0x54c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SCS",	itScc,      0x55c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SNE",	itScc,      0x56c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SEQ",	itScc,      0x57c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SVC",	itScc,      0x58c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SVS",	itScc,      0x59c0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SPL",	itScc,      0x5ac0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SMI",	itScc,      0x5bc0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SGE",	itScc,      0x5cc0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SLT",	itScc,      0x5dc0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SGT",	itScc,      0x5ec0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"SLE",	itScc,      0x5fc0, 0x0000,  0xffc0, 0x0000,    0x82, 0x1c},
    {"ASR",	itMemShift, 0xe0c0, 0x0000,  0xffc0, 0x0000,    0x83, 0x1c},
    {"ASL",	itMemShift, 0xe1c0, 0x0000,  0xffc0, 0x0000,    0x83, 0x1a},
    {"LSR",	itMemShift, 0xe2c0, 0x0000,  0xffc0, 0x0000,    0x83, 0x1c},
    {"LSL",	itMemShift, 0xe3c0, 0x0000,  0xffc0, 0x0000,    0x83, 0x1c},
    {"ROXR",	itMemShift, 0xe4c0, 0x0000,  0xffc0, 0x0000,    0x83, 0x1c},
    {"ROXL",	itMemShift, 0xe5c0, 0x0000,  0xffc0, 0x0000,    0x83, 0x1c},
    {"ROR",	itMemShift, 0xe6c0, 0x0000,  0xffc0, 0x0000,    0x83, 0x1c},
    {"ROL",	itMemShift, 0xe7c0, 0x0000,  0xffc0, 0x0000,    0x83, 0x1c},

    /*     10 bit mask	*/
    {"CMPM",	itCmpm, 0xb108, 0x0000,	  0xf1f8, 0x0000,    0x00, 0x00},
    {"CMPM",	itCmpm, 0xb148,	0x0000,   0xf1f8, 0x0000,    0x00, 0x00},
    {"CMPM",	itCmpm, 0xb188, 0x0000,	  0xf1f8, 0x0000,    0x00, 0x00},
    {"EXG",	itExg,  0xc140,	0x0000,   0xf1f8, 0x0000,    0x00, 0x00},
    {"EXG",	itExg,  0xc148,	0x0000,   0xf1f8, 0x0000,    0x00, 0x00},
    {"EXG",	itExg,  0xc188,	0x0000,   0xf1f8, 0x0000,    0x00, 0x00},

    /*     9 bit mask	*/
    {"MOVEM",	itMovem, 0x4880, 0x0000, 0xff80, 0x0000,    0x8b, 0x1c},
    {"MOVEM",	itMovem, 0x4c80, 0x0000, 0xff80, 0x0000,    0x93, 0x10},
    {"SBCD",	itBcd,   0x8100, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"PACK",	itPack,  0x8140, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"UNPK",	itPack,  0x8180, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"ABCD",	itBcd,   0xc100, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"SUBX",	itX,     0x9100, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"SUBX",	itX,     0x9140, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"SUBX",	itX,     0x9180, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"ADDX",	itX,     0xd100, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"ADDX",	itX,     0xd140, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},
    {"ADDX",	itX,     0xd180, 0x0000, 0xf1f0, 0x0000,    0x00, 0x00},


    /*     8 bit mask	*/
    {"NEGX",	itNegx, 0x4000,	0x0000,   0xff00, 0x0000,    0x82, 0x1c},
    {"CLR",	itNegx, 0x4200,	0x0000,   0xff00, 0x0000,    0x82, 0x1c},
    {"NEG",	itNegx, 0x4400,	0x0000,   0xff00, 0x0000,    0x82, 0x1c},
    {"NOT",	itNegx, 0x4600,	0x0000,   0xff00, 0x0000,    0x82, 0x1c},
    {"TST",	itNegx, 0x4a00,	0x0000,   0xff00, 0x0000,    0x80, 0x10},
    {"BRA",	itBra,  0x6000,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BSR",	itBra,  0x6100,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BHI",	itBra,  0x6200, 0x0000,	  0xff00, 0x0000,    0x00, 0x00},
    {"BLS",	itBra,  0x6300,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BCC",	itBra,  0x6400,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BCS",	itBra,  0x6500,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BNE",	itBra,  0x6600,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BEQ",	itBra,  0x6700,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BVC",	itBra,  0x6800,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BVS",	itBra,  0x6900,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BPL",	itBra,  0x6a00,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BMI",	itBra,  0x6b00,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BGE",	itBra,  0x6c00,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BLT",	itBra,  0x6d00, 0x0000,	  0xff00, 0x0000,    0x00, 0x00},
    {"BGT",	itBra,  0x6e00,	0x0000,   0xff00, 0x0000,    0x00, 0x00},
    {"BLE",	itBra,  0x6f00,	0x0000,   0xff00, 0x0000,    0x00, 0x00},

#if defined (MCF52PLUS)
    {"WDDATA",  itNegx, 0xfb00, 0x0000,   0xff00, 0x0000,    0x00, 0x00},
#endif defined (MCF52PLUS)

    /*     7 bit mask	*/
    {"BTST",	itDynBit, 0x0100, 0x0000,  0xf1c0, 0x0000,    0x02, 0x00},
    {"BCHG",	itDynBit, 0x0140, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"BCLR",	itDynBit, 0x0180, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"BSET",	itDynBit, 0x01c0, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"CHK",	itChk,    0x4100, 0x0000,  0xf1c0, 0x0000,    0x02, 0x00},
    {"CHK",	itChk,    0x4180, 0x0000,  0xf1c0, 0x0000,    0x02, 0x00},
    {"LEA",	itLea,    0x41c0, 0x0000,  0xf1c0, 0x0000,    0x9b, 0x10},
    {"DIVU",	itDivW,   0x80c0, 0x0000,  0xf1c0, 0x0000,    0x02, 0x00},
    {"DIVS",	itDivW,   0x81c0, 0x0000,  0xf1c0, 0x0000,    0x02, 0x00},
    {"SUB",	itOr,     0x9000, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"SUB",	itOr,     0x9040, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"SUB",	itOr,     0x9080, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"SUBA",	itAdda,   0x90c0, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"SUB",	itOr,     0x9100, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"SUB",	itOr,     0x9140, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"SUB",	itOr,     0x9180, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"SUBA",	itAdda,   0x91c0, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"CMP",	itOr,     0xb000, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"CMP",	itOr,     0xb040, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"CMP",	itOr,     0xb080, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"CMPA",	itAdda,   0xb0c0, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"CMPA",	itAdda,   0xb1c0, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"MULU",	itDivW,   0xc0c0, 0x0000,  0xf1c0, 0x0000,    0x02, 0x00},
    {"MULS",	itDivW,   0xc1c0, 0x0000,  0xf1c0, 0x0000,    0x02, 0x00},
    {"ADD",	itOr,     0xd000, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"ADD",	itOr,     0xd040, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"ADD",	itOr,     0xd080, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"ADDA",	itAdda,   0xd0c0, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},
    {"ADD",	itOr,     0xd100, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"ADD",	itOr,     0xd140, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"ADD",	itOr,     0xd180, 0x0000,  0xf1c0, 0x0000,    0x82, 0x1c},
    {"ADDA",	itAdda,   0xd1c0, 0x0000,  0xf1c0, 0x0000,    0x00, 0x00},

    /*     7 bit mask	*/
    {"ASR",	itRegShift, 0xe000,0x0000,   0xf118, 0x0000,    0x00, 0x00},
    {"LSR",	itRegShift, 0xe008,0x0000,   0xf118, 0x0000,    0x00, 0x00},
    {"ROXR",	itRegShift, 0xe010,0x0000,   0xf118, 0x0000,    0x00, 0x00},
    {"ROR",	itRegShift, 0xe018,0x0000,   0xf118, 0x0000,    0x00, 0x00},
    {"ASL",	itRegShift, 0xe100,0x0000,   0xf118, 0x0000,    0x00, 0x00},
    {"LSL",	itRegShift, 0xe108,0x0000,   0xf118, 0x0000,    0x00, 0x00},
    {"ROXL",	itRegShift, 0xe110,0x0000,   0xf118, 0x0000,    0x00, 0x00},
    {"ROL",	itRegShift, 0xe118,0x0000,   0xf118, 0x0000,    0x00, 0x00},

    /*     7 bit mask	*/
    {"MOVEP",	itMovep, 0x0080, 0x0000,   0xf038, 0x0000,    0x00, 0x00},
#if defined ( INCLUDE_V4 )
    {"MOV3Q",	itMove3q,0xa140, 0x0000,   0xf1c0, 0x0000,    0x80, 0xfc},
#endif

    /*     6 bit mask	*/
    {"cpBcc",	itCpBcc, 0xf080, 0x0000,   0xf180, 0x0000,    0x00, 0x00},
#if defined ( INCLUDE_V4 )
    {"MVS",	itMvs  , 0x7100, 0x0000,   0xf180, 0x0000,    0x80, 0xe0},
    {"MVZ",	itMvz  , 0x7180, 0x0000,   0xf180, 0x0000,    0x80, 0xe0},
#endif

    /*     5 bit mask	*/
    {"MOVEA",	itMoveA, 0x0040, 0x0000,   0xc1c0, 0x0000,    0x00, 0x00},

    /*     5 bit mask	*/
    {"ADDQ",	itQuick, 0x5000, 0x0000,  0xf100, 0x0000,    0x80, 0x1c},
    {"SUBQ",	itQuick, 0x5100, 0x0000,  0xf100, 0x0000,    0x80, 0x1c},
    {"MOVEQ",	itMoveq, 0x7000, 0x0000,  0xf100, 0x0000,    0x00, 0x00},

    /*     4 bit mask	*/
    {"MOVE",	itMoveB, 0x1000, 0x0000,  0xf000, 0x0000,    0x82, 0x1c},
    {"MOVE",	itMoveL, 0x2000, 0x0000,  0xf000, 0x0000,    0x82, 0x1c},
    {"MOVE",	itMoveW, 0x3000, 0x0000,  0xf000, 0x0000,    0x82, 0x1c},
    {"OR",	itOr,    0x8000, 0x0000,  0xf100, 0x0000,    0x02, 0x00},
    {"OR",	itOr,    0x8100, 0x0000,  0xf100, 0x0000,    0x83, 0x1c},
    {"EOR",	itOr,    0xb000, 0x0000,  0xf000, 0x0000,    0x82, 0x1c},
    {"AND",	itOr,    0xc000, 0x0000,  0xf100, 0x0000,    0x02, 0x00},
    {"AND",	itOr,    0xc100, 0x0000,  0xf100, 0x0000,    0x83, 0x1c},
    {"",	0,	 0,	 0,       0,	  0,         0,    0}
    };



/*******************************************************************************
*
* dsmFind - disassemble one instruction
*
* This routine figures out which instruction is pointed to by binInst,
* and returns a pointer to the INST which describes it.
*
* RETURNS: pointer to instruction or NULL if unknown instruction.
*/

LOCAL INST *dsmFind
    (
    USHORT binInst []
    )
    {
    FAST INST *iPtr;
    UINT8 instMode;
    UINT8 instReg;

    /* Look first for MAC instructions */
#if defined (INCLUDE_MAC)
    INST *iPtr_add;
    for (iPtr_add = &inst_add [0] ; iPtr_add->mask1 != 0 ; iPtr_add++)
    {
	if ( ((binInst [0] & iPtr_add->mask1) == iPtr_add->op1)
	     && ((binInst [1] & iPtr_add->mask2) == iPtr_add->op2)
	     )
	{
	    /* get address mode */

	    instMode = (binInst [0] & 0x0038) >> 3;
	    instReg = binInst [0] & 0x0007;

	    /* check effective address mode */

	    if (((1 << instMode ) & iPtr_add->modemask) == 0x00)
	    {
	        return (iPtr_add);
	    }

	    if ((((1 << instMode ) & iPtr_add->modemask) == 0x80) &&
		(((1 << instReg) & iPtr_add->regmask) == 0x00))
	        {
	        return (iPtr_add);
		}

     	}
    }

    /* end of "Look first for MAC instructions"  */
#endif
    
    /* Find out which instruction it is */

    for (iPtr = &inst [0]; iPtr->mask1 != 0; iPtr++)
    {
	if (((binInst [0] & iPtr->mask1) == iPtr->op1)
	     && ((binInst[1] & iPtr->mask2) == iPtr->op2))
	    {
	    /* get address mode */

	    if (strcmp (iPtr->name, "MOVE") == 0)
		{
		instMode = (binInst[0] & 0x01c0) >> 6;
		instReg  = (binInst[0] & 0x0e00) >> 9;
		}
	    else
		{
	        instMode = (binInst[0] & 0x0038) >> 3;
	        instReg = binInst [0] & 0x0007;
		}

	    /* check effective address mode */

	    if (((1 << instMode ) & iPtr->modemask) == 0x00)
		{
	        return (iPtr);
		}
	    if ((((1 << instMode ) & iPtr->modemask) == 0x80) &&
		(((1 << instReg) & iPtr->regmask) == 0x00))
	        {
	        return (iPtr);
		}

	    }
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
*/

LOCAL void dsmPrint
    (
    USHORT binInst [],          /* Pointer to instructin */
    FAST INST *iPtr,            /* Pointer to INST returned by dsmFind */
    int address,                /* Address with which to prepend instructin */
    int nwords,                 /* Instruction length, in words */
    FUNCPTR prtAddress          /* Address printing function */
    )
    {
    FAST int ix;		/* index into binInst */
    FAST int wordsToPrint;	/* # of 5-char areas to reserve for printing
				   of hex version of instruction */
    wordsToPrint = (((nwords - 1) / 5) + 1) * 5;

    /* Print the address and the instruction, in hex */

    printf ("%06x  ", address);
    for (ix = 0; ix < wordsToPrint; ++ix)
	/* print lines in multiples of 5 words */
	{
	if ((ix > 0) && (ix % 5) == 0)		/* print words on next line */
	    printf ("\n        ");
	printf ((ix < nwords) ? "%04x " : "     ", binInst [ix]);
	}

    if (iPtr == NULL)
	{
	printf ("DC.W        0x%04x\n", binInst[0]);
	return;
	}

    /* Print the instruction mnemonic, the size code (.w, or whatever), and
       the arguments */

    printf ("%-6s", iPtr->name);
    prtSizeField (binInst, iPtr);
    printf ("    ");
    prtArgs (binInst, iPtr, address, prtAddress);
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
    int frstArg;	/* length of first argument */

    if (iPtr == NULL)
	return (1);			/* not an instruction */

    switch (iPtr->type)
	{
	case itMoveFACC:
	case itMoveFMACSR:
	case itMoveFMASK:
	case itMoveTCCR:
		return (1);

	case itMoveTMASK:
	case itMoveTACC:
	case itMoveTMACSR:
		return (1 + modeNwords((binInst [0] & 0x0038) >> 3  
					,binInst [0] & 7
					, 2,  &binInst [1]
					)
			);
	case itMac:
	case itMsac:
		return (2);

   	 
	case itMacl:
	case itMsacl:
		return (2 + modeNwords((binInst [0] & 0x0038) >> 3  
					,binInst [0] & 7
					, 0,  &binInst [2]
					)
			);
	case itLea:
	case itBcd:
	case itNbcd:
	case itDynBit:
	case itMemShift:
	case itMoveTSR:
	case itMoveFSR:
	case itMoveCCR:
	case itQuick:
	case itScc:
	case itMoveFCCR:
	case itDivW:
	case itCpSave:
	    return (1 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7, 1, &binInst [1]));

	case itMoves:
	case itStatBit:
	case itMovem:
	case itCallm:
	case itBfchg:
	case itBfext:
	case itBfins:
	case itCpGen:
	case itCpScc:
	    return (2 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7, 0, &binInst [2]));

	case itDivL:
	    return (2 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7, 2, &binInst [2]));

	case itAdda:
	    return (1 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7,
				    ((binInst [0] & 0x0100) == 0) ? 1 : 2,
				    &binInst [1]));
	case itMoveA:
	    return (1 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7,
				    ((binInst [0] & 0x1000) == 0) ? 2 : 1,
				    &binInst [1]));
	case itNegx:
	case itOr:
	    return (1 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7,
				    ((binInst [0] & 0x0080) == 0) ? 1 : 2,
				    &binInst [1]));
	case itChk:
	    return (1 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7,
				    ((binInst [0] & 0x0080) == 0) ? 2 : 1,
				    &binInst [1]));

	case itChk2:
	    return (2 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7,
				    ((binInst [0] & 0x0400) == 0) ? 1 : 2,
				    &binInst [2]));

	case itCas:
	    return (2 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7,
				    ((binInst [0] & 0x0600) == 3) ? 2 : 1,
				    &binInst [2]));

	case itComplete:
	case itMoveq:
	case itExg:
	case itSwap:
	case itTrap:
	case itX:
	case itMoveUSP:
	case itUnlk:
	case itCmpm:
	case itExt:
	case itBkpt:
	case itRtm:
	case itRegShift:
	case itCpush:
	case itIntouch:
	    return (1);

	case itMovep:
	case itStop:
	case itLink:
	case itDb:
	case itRTD:
	case itMovec:
	case itPack:
	case itImmCCR:
	case itImmTSR:
	    return (2);

	case itLinkL:
	case itCas2:
	case itCpDbcc:
	    return (3);

	case itBra:
	    switch (binInst [0] & 0xff)
		{
		case 0: 	return (2);
		case 0xff:	return (3);
		default:	return (1);
		}

	case itTrapcc:
	    return (((binInst [0] & 7) == 4) ? 1 : binInst [0] & 7);

	case itImm:
	    return ((((binInst [0] & 0x0080) == 0) ? 2 : 3) +
		modeNwords ((binInst [0] & 0x0038) >> 3, binInst [0] & 7, 0,
			((binInst [0] & 0x0080) == 0) ? &binInst [2]
			: &binInst [3]));

	case itMoveB:
	case itMoveW:
	    {
	    frstArg = modeNwords ((binInst [0] & 0x0038) >> 3,
				   binInst [0] & 7, 1, &binInst [1]);
	    return (1 + frstArg + modeNwords ((binInst [0] & 0x01c0) >> 6,
			    		      (binInst [0] & 0x0e00) >> 9, 1,
			    		      &binInst [1 + frstArg]));
	    }
	case itMoveL:
	    {
	    frstArg = modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7, 2, &binInst [1]);
	    return (1 + frstArg + modeNwords ((binInst [0] & 0x01c0) >> 6,
				    	      (binInst [0] & 0x0e00) >> 9, 2,
					      &binInst [1 + frstArg]));
	    }
	case itCpBcc:
	    return ((binInst [0] & 0x40) ? 3 : 2);

	case itCpTrapcc:
	    switch (binInst [0] & 7)
		{
		case 2:		return (3);
		case 3:		return (4);
		case 4:		return (2);
		}

	/* fpp instructions */
	case itFb:
	    if (binInst[0] & 0x0040)
		return(3);
	    else
		return(2);

	case itFrestore:
	case itFsave:
	    return(1 + modeNwords((binInst[0] & 0x0038) >> 3,
			    binInst[0] & 0x7, 0, &binInst[1]));

	case itFmovek:
	case itFmovel:
	case itFmovem:
	case itFmovemc:
	    return(2 + fppNwords((binInst[0] & 0x0038) >> 3,
			    binInst[0] & 0x7, 1, 0, &binInst[2]));

	case itFmovecr:
		return(2);

	case itFabs:
	case itFacos:
	case itFadd:
	case itFasin:
	case itFatan:
	case itFatanh:
	case itFcmp:
	case itFcos:
	case itFcosh:
	case itFdb:
	case itFdiv:
	case itFetox:
	case itFetoxm1:
	case itFgetexp:
	case itFgetman:
	case itFint:
	case itFintrz:
	case itFlog10:
	case itFlog2:
	case itFlogn:
	case itFlognp1:
	case itFmod:
	case itFmove:
	case itFmul:
	case itFneg:
	case itFnop:
	case itFrem:
	case itFscale:
	case itFs:
	case itFsgldiv:
	case itFsglmul:
	case itFsin:
	case itFsincos:
	case itFsinh:
	case itFsqrt:
	case itFsub:
	case itFtan:
	case itFtanh:
	case itFtentox:
	case itFtrap:
	case itFtst:
	case itFtwotox:
	    return (2 + fppNwords ((binInst[0] & 0x0038) >> 3,
		    binInst[0] & 0x7, (binInst[1] & 0x4000) >> 14,
		    (binInst[1] & 0x1c00) >> 10,
		    /* (binInst[1] & 0x0380) >> 7, XXX eliminate? */
		    &binInst[2]));

	case itWDebug:
	    return (2 + modeNwords ((binInst [0] & 0x0038) >> 3,
				    binInst [0] & 7,
				    2,
				    &binInst [2]));
	case itSats:
		return 1;
	case itMove3q:
		return (1 + modeNwords((binInst [0] & 0x0038) >> 3  
					,binInst [0] & 7
					, 0,  &binInst [1]
					)
			);
	case itMvs:
	case itMvz:
		return (1 + modeNwords((binInst [0] & 0x0038) >> 3  
					,binInst [0] & 7
					, 1,  &binInst [1]
					)
			);
	}

    /* We never get here, but just for lint ... */
    return (0);
    }
/*******************************************************************************
*
* fppNwords - number of words of extension used by the mode for fpp instrutions
*/

LOCAL int fppNwords
    (
    FAST USHORT mode,
    USHORT reg,
    USHORT rm,
    USHORT src,
    USHORT extension []         /* extension array for effective address */
    )
    {
    if (rm != 0)
	{
	if (mode == 0x7 && reg == 0x4)
	    {
	    switch (src)
		{
		case 0:
		case 1:
		    return (2);
		case 2:
		case 3:
		    return (6);
		case 4:
		    return (1);
		case 5:
		    return (4);
		case 6:
		    return (1);
		}
	    }
	else
	    return (modeNwords (mode, reg, 0, extension));
	}

    return (0);
    }
/*******************************************************************************
*
* modeNwords - Figure out the number of words of extension needed for a mode
*/

LOCAL int modeNwords
    (
    FAST USHORT mode,
    USHORT reg,
    int size,           /* the size of an immediate operand in words */
    USHORT extension [] /* extension array for effective address */
    )
    {
    switch (mode)
	{
	case 0x00:    				/* Dn */
	case 0x01:				/* An */
	case 0x02:				/* (An) */
	case 0x03:				/* (An)+ */
	case 0x04:				/* -(An) */

	    return (0);

	case 0x05:				/* (d16,An) */

	    return (1);

	case 0x06:				/* reg indirect w.index modes */

	    return (mode6And7Words (&extension [0]));

	case 0x07:				/* memory indirect */
	    switch (reg)
		{
		/* With mode 7, sub-modes are determined by the
		   register number */

		case 0x0:			/* abs.short */
		case 0x2:			/* PC + off */

		     return (1);

		case 0x3:			/* PC + ind + off */

		    return (mode6And7Words (&extension [0]));

		case 0x1:				/* abs.long */

		    return (2);

		case 0x4:				/* imm. */
		    return (size);
		}
	}
    /* We never get here, but just for lint ... */
    return (0);
    }
/*******************************************************************************
*
* mode6And7Words - number of words of extension needed for modes 6 and 7
*/

LOCAL int mode6And7Words
    (
    FAST USHORT extension []
    )
    {
    int count = 1;	/* number of words in extension */

    if ((extension [0] & 0x0100) == 0)		/* (An) + (Xn) + d8 */
	return (count);

    switch ((extension [0] & 0x30) >> 4)	/* base displacement size */
	{
	case 0:		/* reserved or NULL displacement */
	case 1:
	    break;

	case 2:		/* word displacement */
	    count += 1;
	    break;

	case 3:		/* long displacement */
	    count += 2;
	    break;
	}

    if ((extension [0] & 0x40) == 0)		/* index operand added */
	{
	switch (extension [0] & 3)
	    {
	    case 0:		/* reserved or NULL displacement */
	    case 1:
		break;

	    case 2:		/* word displacement */
		count += 1;
		break;

	    case 3:		/* long displacement */
		count += 2;
		break;
	    }
	}

    return (count);
    }
/*******************************************************************************
*
* prtArgs - Print the arguments for an instruction
*/

LOCAL void prtArgs
    (
    USHORT binInst [],  /* Pointer to the binary instruction */
    FAST INST *iPtr,    /* Pointer to the INST describing binInst */
    int address,        /* Address at which the instruction resides */
    FUNCPTR prtAddress  /* routine to print addresses. */
    )
    {
    int  frstArg;
    int  displacement;
    int  sizeData;
    char *sourceYword, *sourceXword, *shift, *mam;

    switch (iPtr->type)
	{
	case itBra:
	    switch (binInst [0] & 0xff)
		{
		case 0:
		    displacement = (short) binInst[1];
		    break;
		case 0xff:
		    displacement = (((short) binInst [1] << 16) | binInst [2]);
		    break;
		default:
		    displacement = (char) (binInst [0] & 0xff);
		    break;
		}

	    (*prtAddress) (address + 2 + displacement);
	    printf ("\n");
	    break;

	case itDivW:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 7,
			&binInst [1], 2, prtAddress);
	    printf (",D%x\n", (binInst [0] & 0x0e00) >> 9);
	    break;

	case itChk:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 7,
			&binInst [1], (binInst [0] & 0x80) ? 2 : 4, prtAddress);
	    printf (",D%x\n", (binInst [0] & 0x0e00) >> 9);
	    break;

	case itChk2:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 7,
			&binInst [2], 0, prtAddress);
	    printf ((binInst [1] & 0x8000) ? ",A%x\n" : ",D%x\n",
		    (binInst [1] & 0x7000) >> 12);
	    break;

	case itLea:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 2, prtAddress);
	    printf (",A%x\n", (binInst [0] & 0x0e00) >> 9);
	    break;

	case itComplete:
	    /* No arguments */
	    printf ("\n");
	    break;

	case itStatBit:
	case itCallm:
	    printf ("#%#x,", binInst [1]);
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [2], 0, prtAddress);
	    printf ("\n");
	    break;

	case itDynBit:
	    printf ("D%x,", (binInst [0] & 0x0e00) >> 9);
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 0, prtAddress);
	    printf ("\n");
	    break;

	case itExg:
	    switch ((binInst [0] & 0x00f8) >> 3)
		{
		case 0x08:
		    printf ("D%x,D%x\n", (binInst [0] & 0x0e00) >> 9,
					 binInst [0] & 0x0007);
		    break;
		case 0x09:
		    printf ("A%x,A%x\n", (binInst [0] & 0x0e00) >> 9,
					 binInst [0] & 0x0007);
		    break;
		case 0x11:
		    printf ("D%x,A%x\n", (binInst [0] & 0x0e00) >> 9,
					 binInst [0] & 0x0007);
		    break;
		}
	    break;

	case itImm:
	    switch ((binInst [0] & 0x00c0) >> 6)	/* size */
		{
		case 0:					/* byte */
		    printf ("#%#x,", binInst [1] & 0x00ff);
		    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
				&binInst [2], 0, prtAddress);
		    break;
		case 1:					/* word */
		    printf ("#%#x,", binInst [1]);
		    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
				&binInst [2], 0, prtAddress);
		    break;
		case 2:					/* long */
		    printf ("#%#x%04x,", binInst [1], binInst [2]);
		    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
				&binInst [3], 0, prtAddress);
		    break;
		}
	    printf ("\n");
	    break;

	case itMoveB:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 1, prtAddress);
	    printf (",");
	    frstArg = modeNwords ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
				  1, &binInst [1]);
	    prEffAddr ((binInst [0] & 0x01c0) >> 6, (binInst [0] & 0x0e00) >> 9,
			&binInst [1 + frstArg], 1, prtAddress);
	    printf ("\n");
	    break;

	case itMoveW:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 2, prtAddress);
	    printf (",");
	    frstArg = modeNwords ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
				  1, &binInst [1]);
	    prEffAddr ((binInst [0] & 0x01c0) >> 6, (binInst [0] & 0x0e00) >> 9,
			&binInst [1 + frstArg], 2, prtAddress);
	    printf ("\n");
	    break;

	case itMoveL:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 4, prtAddress);
	    printf (",");
	    frstArg = modeNwords ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
				  2, &binInst [1]);
	    prEffAddr ((binInst [0] & 0x01c0) >> 6, (binInst [0] & 0x0e00) >> 9,
			&binInst [1 + frstArg], 4, prtAddress);
	    printf ("\n");
	    break;

	case itImmCCR:
	    printf ("#%#x,CCR\n", binInst [1] & 0xff);
	    break;

	case itImmTSR:
	    printf ("#%#x,SR\n", binInst [1]);
	    break;

	case itMoveCCR:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 2, prtAddress);
	    printf (",CCR\n");
	    break;

	case itMoveTSR:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 2, prtAddress);
	    printf (",SR\n");
	    break;

	case itMoveFSR:
	    printf ("SR,");
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 0, prtAddress);
	    printf ("\n");
	    break;

	case itMoveUSP:

	    printf (((binInst [0] & 0x8) == 0) ? "A%x,USP\n" : "USP,A%x\n",
		    binInst [0] & 0x07);
	    break;

	case itMovep:
	    if ((binInst [0] & 0x0040) == 0)

		printf ("%x(A%x),D%x\n", binInst [1], binInst [0] & 0x07,
			(binInst [0] & 0x0c00) >> 9);

	    else

		printf ("D%x,%x(A%x)\n", (binInst [0] & 0x0c00) >> 9,
			binInst [1], binInst [0] & 0x07);

	    break;

	case itMovem:
	    if ((binInst [0] & 0x0400) == 0)
		{
		prMovemRegs (binInst [1], (binInst [0] & 0x38) >> 3);
		printf (",");
		prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			    &binInst [2], 0, prtAddress);
		printf ("\n");
		}
	    else
		{
		prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			    &binInst [2], 0, prtAddress);
		printf (",");
		prMovemRegs (binInst [1], (binInst [0] & 0x38) >> 3);
		printf ("\n");
		}
	    break;

	case itMoveq:
	    printf ("#%#x,D%x\n", binInst [0] & 0x00ff,
		    (binInst [0] & 0x0e00) >> 9);
	    break;

	case itNbcd:
	case itNegx:
	case itCpSave:
	case itScc:
	case itMemShift:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 0, prtAddress);
	    printf ("\n");
	    break;

	case itCpGen:
	case itCpScc:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [2], 0, prtAddress);
	    printf ("\n");
	    break;

	case itMoveA:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
		&binInst [1], ((binInst [0] & 0x1000) == 0) ? 4 : 2,
		prtAddress);
	    printf (",A%x\n", (binInst [0] & 0x0e00) >> 9);
	    break;

	case itAdda:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
		&binInst [1], ((binInst [0] & 0x0100) == 0) ? 2 : 4,
		prtAddress);
	    printf (",A%x\n", (binInst [0] & 0x0e00) >> 9);
	    break;

	case itCmpm:
	    printf ("(A%x)+,(A%x)+\n", (binInst [0] & 0x0007),
		(binInst [0] & 0x0e00) >> 9);
	    break;

	case itOr:
	    switch ((binInst [0] & 0x01c0) >> 6)	/* op-mode */
		{
		case 0:				/* byte, to D reg */
		    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 1, prtAddress);
		    printf (",D%x\n", (binInst [0] & 0x0e00) >> 9);
		    break;

		case 1:				/* word to D reg */
		    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 2, prtAddress);
		    printf (",D%x\n", (binInst [0] & 0x0e00) >> 9);
		    break;

		case 2:				/* long, to D reg */
		    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 4, prtAddress);
		    printf (",D%x\n", (binInst [0] & 0x0e00) >> 9);
		    break;

		case 4:				/* byte, to eff address */
		case 5:				/* word, to eff address */
		case 6:				/* long, to eff address */
		    printf ("D%x,", (binInst [0] & 0x0e00) >> 9);
		    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 0, prtAddress);
		    printf ("\n");
		    break;

		}
	    break;

	case itQuick:

	    /* If the data field is 0, it really means 8 */

	    if ((binInst [0] & 0x0e00) == 0)
		printf ("#0x8,");
	    else
		printf ("#%#x,", (binInst [0] & 0x0e00) >> 9);

	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 0, prtAddress);
	    printf ("\n");
	    break;

	case itBcd:
	    if ((binInst [0] & 0x0004) == 0)
		printf ("D%x,D%x\n", (binInst [0] & 0x0e00) >> 9,
				    binInst [0] & 0x0007);
	    else
		printf ("-(A%x),-(A%x)\n", (binInst [0] & 0x0e00) >> 9,
				    binInst [0] & 0x0007);
	    break;

	case itRegShift:
	    if ((binInst [0] & 0x0e20) == 0)
		printf ("#0x8,");
	    else if ((binInst [0] & 0x0020) == 0)
		printf ("#%#x,", (binInst [0] & 0x0e00) >> 9);
	    else
		printf ("D%x,", (binInst [0] & 0x0e00) >> 9);

	    printf ("D%x\n", binInst [0] & 0x07);
	    break;

	case itTrapcc:
	    if ((binInst [0] & 7) == 2)
		printf ("#%#x", binInst [1]);
	    else if ((binInst [0] & 7) == 3)
		printf ("#%#x%04x", binInst [1], binInst [2]);
	    printf ("\n");
	    break;

	case itStop:
	    printf ("%#x\n", binInst [1]);
	    break;

	case itSwap:
	case itExt:
	    printf ("D%x\n", binInst [0] & 0x07);
	    break;

	case itUnlk:
	    printf ("A%x\n", binInst [0] & 0x07);
	    break;

	case itLink:
	    printf ("A%x,#%#x\n", binInst [0] & 0x07, binInst [1]);
	    break;

	case itLinkL:
	    printf ("A%x,#%#x%04x\n", binInst [0] & 7, binInst [1], binInst [2]);
	    break;

	case itRtm:
	    printf ((binInst [0] & 8) ? "A%x\n" : "D%x\n", binInst [0] & 7);
	    break;

	case itTrap:
	    printf ("#%#x\n", binInst [0] & 0x0f);
	    break;

	case itBkpt:
	    printf ("#%#x\n", binInst [0] & 7);
	    break;

	case itX:
	    printf (((binInst [0] & 0x08) == 0) ?
		    "D%x,D%x\n" : "-(A%x),-(A%x)\n",
		    binInst [0] & 0x07, (binInst [0] & 0x0e00) >> 9);
	    break;

	case itPack:
	    printf (((binInst [0] & 0x08) == 0) ?
		    "D%x,D%x," : "-(A%x),-(A%x),",
		    binInst [0] & 0x07, (binInst [0] & 0x0e00) >> 9);
	    printf ("#%#x\n", binInst [1]);
	    break;

	case itDb:
	    printf ("D%x,", binInst [0] & 0x07);
	    (*prtAddress) (address + 2 + (short) binInst [1]);
	    printf ("\n");
	    break;

	case itRTD:
	    printf ("#%#x\n", binInst [1]);
	    break;

	case itBfchg:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 7, &binInst [2],
	              0, prtAddress);
	    prOffWid ((binInst [1] & 0x0800) >> 11, (binInst [1] & 0x07c0) >> 6,
		      (binInst [1] & 0x20) >> 5, binInst [1] & 0x1f);
	    printf ("\n");
	    break;

	case itBfext:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 7, &binInst [2],
	              0, prtAddress);
	    prOffWid ((binInst [1] & 0x0800) >> 11, (binInst [1] & 0x07c0) >> 6,
		      (binInst [1] & 0x20) >> 5, binInst [1] & 0x1f);
	    printf (",D%x\n", (binInst [1] & 0x7000) >> 12);
	    break;

	case itBfins:
	    printf ("D%x,", (binInst [1] & 0x7000) >> 12);
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 7, &binInst [2],
	              0, prtAddress);
	    prOffWid ((binInst [1] & 0x0800) >> 11, (binInst [1] & 0x07c0) >> 6,
		      (binInst [1] & 0x20) >> 5, binInst [1] & 0x1f);
	    printf ("\n");
	    break;

	case itDivL:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 7, &binInst [2],
			4, prtAddress);
	    printf (",");
	    if (binInst [1] & 0x0400
		|| ((binInst [1] & 0x0007) != ((binInst [1] & 0x7000) >> 12)))
		{
		printf ("D%x:", binInst [1] & 7);
		}
	    printf ("D%x\n", (binInst [1] & 0x7000) >> 12);
	    break;

	case itCas:
	    printf ("D%x,D%x,", binInst [1] & 7, (binInst [1] & 0x01c0) >> 6);
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 7, &binInst [2],
			0, prtAddress);
	    printf ("\n");
	    break;

	case itCas2:
	    printf ("D%x:D%x,D%x:D%x,", binInst [1] & 7, binInst [2] & 7,
		     (binInst [1] & 0x01c0) >> 6, (binInst [2] & 0x01c0) >> 6 );
	    printf (binInst [1] & 0x8000 ? "(A%x):" : "(D%x):",
		     (binInst [1] & 0x7000) >> 12);
	    printf (binInst [2] & 0x8000 ? "(A%x)\n" : "(D%x)\n",
		     (binInst [2] & 0x7000) >> 12);
	    break;

	case itMoves:
	    if ((binInst[1] & 0x0800) == 0)
		{
		/* from <ea> to general reg */

		prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			    &binInst [2], 0, prtAddress);
		if ((binInst[1] & 0x8000) == 0)
		    printf (",D%x\n",(binInst[1] & 0x7000) >> 12);
		else
		    printf (",A%x\n",(binInst[1] & 0x7000) >> 12);
		}
	    else
		{
		/* from general reg to <ea> */
		if ( (binInst[1] & 0x8000) == 0)
		    printf ("D%x, ",(binInst[1] & 0x7000) >> 12);
		else
		    printf ("A%x, ",(binInst[1] & 0x7000) >> 12);
		prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			    &binInst [2], 0, prtAddress);
		printf ("\n");
		}
	    break;

	case itMovec:
	    if ((binInst[0] & 1) == 0)
		{
		/* control reg to general reg */
		prContReg (binInst[1] & 0x0fff);
		if ((binInst[1] & 0x8000) == 0)
		    printf (",D%x\n",(binInst[1] & 0x7000) >> 12);
		else
		    printf (",A%x\n",(binInst[1] & 0x7000) >> 12);
		}
	    else
		{
		/* general reg to control reg */
		if ((binInst[1] & 0x8000) == 0)
		    printf ("D%x,",(binInst[1] & 0x7000) >> 12);
		else
		    printf ("A%x,",(binInst[1] & 0x7000) >> 12);
		prContReg (binInst[1] & 0x0fff);
		printf ("\n");
		}
	    break;

	case itMoveFCCR:
	    printf ("CCR, ");
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [1], 0, prtAddress);
	    printf ("\n");
	    break;

	case itCpBcc:
	    if ((binInst [0] & 0x40) == 0)
		printf ("#%#x%04x\n", binInst [1], binInst [2]); /* xxx 0x */
	    else
		printf ("#%#x\n", binInst [1]);
	    break;

	case itCpDbcc:
	    printf("D%x,#%#x\n", binInst [0] & 7, binInst [2]);
	    break;

	case itCpTrapcc:
	    switch (binInst [0] & 7)
		{
		case 2:
		    printf ("#%#x\n", binInst [2]);
		    break;
		case 3:
		    printf ("#%#x%04x\n", binInst [2], binInst [3]);
		    break;
		case 4:
		    printf ("#0\n");
		    break;
		}
	    break;

	/* fpp instructions */
	case itFb:
		if(binInst[0] & 0x40)
			printf ("#%#x\n", binInst[1]);
		else
			printf ("#%#x%04x\n", binInst[1], binInst[2]);
		break;

	case itFrestore:
	case itFsave:
	case itFs:
		prEffAddr((binInst[0] & 0x38)>>3, binInst[0] & 0x7,
			&binInst[1], 0, prtAddress);
		printf ("\n");
		break;

	case itFdb:
		printf ("D%x,#%#x\n",binInst[0] & 0x7, binInst[2]);
		break;

	case itFtrap:
		switch(binInst[0] & 7)
		    {
		    case 2:
			    printf ("#%#x\n",binInst[2]);
			    break;
		    case 3:
			    printf ("#%#x%04x\n", binInst[2], binInst[3]);
			    break;
		    case 4:
			    printf ("#0\n"); break;
		    }
		break;
	case itFtst:
		if (binInst[1] & 0x4000)
			prEffAddr((binInst[0] & 0x38)>>3, binInst[0] & 0x7,
				&binInst[2], 0, prtAddress);
		else
			printf ("F%x", (binInst[1] & 0x0380)>>7);
		printf ("\n");
		break;

	case itFmovek:
		printf ("F%x,", (binInst[1] & 0x0380)>>7);
		prEffAddr((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			&binInst[2], 0, prtAddress);
		printf ("\n");
		break;

	case itFmovel:
		if (binInst[1] & 0x2000)
		    {
		    prFmovemcr ((binInst[1] & 0x1c00) >> 10);
		    printf (",");
		    prEffAddr((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			    &binInst[2], 0, prtAddress);
		    }
		else
		    {
		    prEffAddr((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			    &binInst[2], 0, prtAddress);
		    printf (",");
		    prFmovemcr ((binInst[1] & 0x1c00) >> 10);
		    }
		printf ("\n");
		break;

	case itFmovecr:
		printf ("#%#x,", binInst[1] & 0x7f);
		printf ("F%x\n",(binInst[1] & 0x0380) >> 7);
		break;

	case itFmovem:
		if (binInst[1] & 0x2000)
		    {
		    prFmovemr((binInst[1] & 0x1800) >> 11, binInst[1] & 0xff);
		    printf (",");
		    prEffAddr((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			    &binInst[2], 0, prtAddress);
		    }
		else
		    {
		    prEffAddr((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			    &binInst[2], 0, prtAddress);
		    printf (",");
		    prFmovemr ((binInst[1] & 0x1800) >> 11, binInst[1] & 0xff);
		    }
		printf ("\n");
		break;

	case itFmovemc:
		if (binInst[1] & 0x2000)
		    {
		    prFmovemcr ((binInst[1] & 0x1c00) >> 10);
		    printf (",");
		    prEffAddr((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			    &binInst[2], 0, prtAddress);
		    }
		else
		    {
		    prEffAddr ((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			    &binInst[2], 0, prtAddress);
		    printf (",");
		    prFmovemcr ((binInst[1] & 0x1c00) >> 10);
		    }
		printf ("\n");
		break;

	case itFsincos:
		if (binInst[1] & 0x4000)
		    prEffAddr((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			    &binInst[2], 0, prtAddress);
		else
		    printf ("F%x,", (binInst[1] & 0x1c00) >> 10);
		printf (",F%x:F%x\n", (binInst[1] & 0x7),
				(binInst[1] & 0x380) >> 7);
		break;

	case itFabs:
	case itFacos:
	case itFadd:
	case itFasin:
	case itFatan:
	case itFatanh:
	case itFcmp:
	case itFcos:
	case itFcosh:
	case itFdiv:
	case itFetox:
	case itFetoxm1:
	case itFgetexp:
	case itFgetman:
	case itFint:
	case itFintrz:
	case itFlog10:
	case itFlog2:
	case itFlogn:
	case itFlognp1:
	case itFmod:
	case itFmove:
	case itFmul:
	case itFneg:
	case itFnop:
	case itFrem:
	case itFscale:
	case itFsgldiv:
	case itFsglmul:
	case itFsin:
	case itFsinh:
	case itFsqrt:
	case itFsub:
	case itFtan:
	case itFtanh:
	case itFtentox:
	case itFtwotox:
		if (binInst[1] & 0x4000)
		    {
		    switch ((binInst [1] & 0x1c00) >> 10)
			{
			case LONGINT: 		sizeData = 4; break;
			case SINGLEREAL:	sizeData = 4; break;
			case EXTENDEDREAL:	sizeData = 12; break;
			case PACKEDDECIMAL:	sizeData = 12; break;
			case WORDINT: 		sizeData = 2; break;
			case DOUBLEREAL:	sizeData = 8; break;
			case BYTEINT: 		sizeData = 2; break;
			default: 		sizeData = 4; break;
			}
		    
		    prEffAddr((binInst[0] & 0x38) >> 3, binInst[0] & 0x7,
			    &binInst[2], sizeData, prtAddress);
		    printf (",F%x", (binInst[1] & 0x0380) >> 7);
		    }
		else
		    printf ("F%x,F%x", (binInst[1] & 0x1c00) >> 10,
			    (binInst[1] & 0x0380) >> 7);
		printf ("\n");
		break;

	case itCpush:
#ifdef INCLUDE_V4
	    printf ("%s,(A%x)\n", (binInst[0] & 0x00c0) == 0x0040 ? "DC" :
				  (binInst[0] & 0x00c0) == 0x0080 ? "IC" : "BC",
			binInst [0] & 0x07);
#else
	    printf ("(A%x)\n", binInst [0] & 0x07);
#endif
	    break;

	  case itWDebug:
	    prEffAddr ((binInst [0] & 0x38) >> 3, binInst [0] & 0x7,
			&binInst [2], 0, prtAddress);
	    printf ("\n");

	/*    MAC instructions for Coldfire 5206 & 53xx	*/

	case itMoveFACC:
	    printf ( "ACC, %c%x\n"
		     ,((binInst [0] & 0x8) == 0) ? 'D' : 'A'
		     ,binInst [0] & 0x7
		     );
	    break;
	   
	case itMoveTACC:
	    prEffAddr ( ( binInst [0] & 0x38) >> 3,
	                binInst [0] & 0x7,
			&binInst [1], 4, prtAddress );
	    printf( ", ACC\n");
	    break;

	case itMoveFMACSR:
	    printf ( "MACSR, %c%x\n",
		     ((binInst [0] & 0x8) == 0) ? 'D' : 'A',
		     binInst [0] & 0x7);
	    break;

	case itMoveTMACSR:
	    prEffAddr ( ( binInst [0] & 0x38) >> 3,
	                 binInst [0] & 0x7,
			&binInst [1], 4, prtAddress);
	    printf (", MACSR\n");
	    break;

	case itMoveFMASK:
	    printf ("MASK, %c%x\n",
		     ((binInst [0] & 0x8) == 0) ? 'D' : 'A',
		     binInst [0] & 0x7);
	    break;

	case itMoveTMASK:
	    prEffAddr ( (binInst [0] & 0x38) >> 3,
	                binInst [0] & 0x7,
			&binInst [1], 4, prtAddress);
	    printf( ", MASK\n");
	    break;


	case itMoveTCCR:
	    printf ( "MACSR, CCR\n");
	    break;

	case itMsac:
	case itMac:
	    {
		USHORT binInst0 = binInst [0];
		USHORT binInst1 = binInst [1];

		/* SF Scale Factor */
		switch ((binInst1 & 0x0600) >> 9)
		    {
		    case 1:	shift = ",<<"; 	break;
		    case 3:	shift = ",>>"; 	break;
		    default: 	shift = NULL; 	break;
		    }
		/* print operand upper/lower half only for word operands (SZ flag is 0)*/
		if (0 == (binInst1 & 0x0800) )
		{
		    /* U/LX Source X Word Select field */
		    switch (binInst1 & 0x0080)
		    {
		    case 0:	sourceXword = ".l"; 	break;
		    default: 	sourceXword = ".u"; 	break;
		    }

		    /* U/LY Source Y Word Select field */
		    switch (binInst1 & 0x0040)
		    {
		    case 0:	sourceYword = ".l"; 	break;
		    default: 	sourceYword = ".u"; 	break;
		    }
		}
		else
		{
		    sourceXword = NULL;
		    sourceYword = NULL;
		}

		printf ( "%c%x%s,%c%x%s%s\n" 
			 ,((binInst0 & 0x0008) == 0) ? 'D' : 'A'
			 ,binInst0 & 0x0007
			 ,((sourceYword == NULL) ? "" : sourceYword) 
			 ,((binInst0 & 0x0040) == 0) ? 'D' : 'A'
		         ,((binInst0 & 0x0e00) >> 9)
			 ,((sourceXword == NULL) ? "" : sourceXword)
			 ,((shift == NULL) ? "" : shift)
			 );
	    }
	    break;


	case itMsacl:
	case itMacl:
	    {
	    	USHORT binInst0 = binInst [0];
	    	USHORT binInst1 = binInst [1];
                
		/* SF Scale Factor */
		switch ((binInst1 & 0x0600) >> 9)
		    {
		    case 1:	shift = ",<<"; 	break;
		    case 3:	shift = ",>>"; 	break;
		    default: 	shift = NULL; 	break;
		    }
		/* print operand upper/lower half only for word operands (SF flag is zero) */
		if (0 == (binInst1 & 0x0800))
		{
		/* U/LY Source Y Word Select field */
		switch (binInst1 & 0x0040)
		    {
		    case 0:	sourceYword = ".l"; 	break;
		    default: 	sourceYword = ".u"; 	break;
		    }

		/* U/LX Source X Word Select field */
		switch (binInst1 & 0x0080)
		    {
		    case 0:	sourceXword = ".l"; 	break;
		    default: 	sourceXword = ".u"; 	break;
		    }
		}
		else
		{
			
		    sourceXword = NULL;
		    sourceYword = NULL;
		}
		/* MAM (MASK) field */
		switch (binInst1 & 0x0020)
		    {
		    case 0:	mam = NULL; 	break;
		    default: 	mam = "&"; 	break;
		    }

		/* 
		 * MACL .<size> Ry.<ul>, Rx.<ul>, <ea>, Rw 		no shift
		 * MACL .<size> Ry.<ul>, Rx.<ul>,<shift>, <ea>, Rw      shift
		 * MACL .<size> Ry.<ul>, Rx.<ul>,<shift>, <ea>&, Rw     shift and mask
		 */ 
		
		/* Ry Data or Address */
		printf (((binInst1 & 0x0008)  == 0) ? "D" : "A");
		
		/* Ry register number */
		printf ( "%d",binInst1 & 0x0007 );
		
		/* Ry upper/lower half */
		if ( sourceYword )
			printf(  sourceYword );
		printf (  "," );
		
		/* now for Rx */
		/* Rx Data or Address */
		printf (((binInst1 & 0x8000)  == 0) ? "D" : "A");
		
		/* Rx register number */
		printf ( "%d",(binInst1 & 0x7000) >> 12 );
		
		/* Rx upper/lower half */
		if ( sourceXword )
			printf( sourceXword );
		
		/* shift ? */
		if ( shift )
			printf ( shift );
		
		/* effective address */
		printf ( "," );
	   	prEffAddr ( ( binInst0 & 0x38) >> 3,
	                    binInst0 & 0x7,
			    &binInst [2], 4, prtAddress);
		
		/* Mask Addressing Mode Modifier */
		if ( mam )
			printf ( mam );

		/* Rw destination register */
		printf ( "," );
		/* Rw Data or Address */
		printf (((binInst0 & 0x0040)  == 0) ? "D" : "A");
		
		/* Rw register number */
		printf ( "%d\n",(binInst0 & 0x0e00) >> 9 );
		

	    }
	    break;

	/* End of "MAC instructions for Coldfire 5206 & 53xx" */


	/*    Coldfire version 4  instruction set enhancements */

	case itMove3q:
	    printf ( "#%#x," ,( binInst [0] & 0x0e00) >> 9 );
	    prEffAddr ( ( binInst [0] & 0x38) >> 3,
	                binInst [0] & 0x7,
			&binInst [1], 2, prtAddress );
	    printf("\n");
	    break;

	case itMvs:
	case itMvz:
	    prEffAddr ( (binInst [0] & 0x38) >> 3,
	                binInst [0] & 0x7,
			&binInst [1], 2, prtAddress);
	    printf ( ",D%d\n" ,(binInst [0] & 0x0e00) >> 9 );
	    break;
	
	case itSats:
	    printf ("D%d\n", binInst [0] & 0x07);
	    break;

	case itIntouch:
	    printf ("(A%x)\n", binInst [0] & 0x07);
	    break;
	/* End of Coldfire version 4  instruction set enhancements */

	default:
	    break;
	}
    }
/*******************************************************************************
*
* prContReg - print the name of a control register
*/

LOCAL void prContReg
    (
    USHORT contReg
    )
    {
    char *buf;

    switch (contReg)
	{
	case SFC:	buf = "SFC";		break;
	case DFC:	buf = "DFC";		break;
	case USP:	buf = "USP";		break;
	case VBR:	buf = "VBR";		break;

	case CACR:	buf = "CACR";		break;
	case TC:	buf = "TC";		break;
	case ACR0:	buf = "ACR0";		break;
	case ACR1:	buf = "ACR1";		break;
	case ACR2:	buf = "ACR2";		break;
	case ACR3:	buf = "ACR3";		break;
	case ROMBAR:	buf = "ROMBAR";		break;
	case ROMBAR0:	buf = "ROMBAR0";	break;
	case ROMBAR1:	buf = "ROMBAR1";	break;
	case MBAR:	buf = "MBAR";		break;

	default:
	    buf = "";	/* make sure nothing is printed */
	    break;
	}

    printf (buf);
    }
/*******************************************************************************
*
* prEffAddr - print the argument for an effective address
*/

LOCAL void prEffAddr
    (
    FAST USHORT mode,   /* mode indicator */
    FAST USHORT reg,    /* register number (or special if mode = 7) */
    USHORT extension [],/* extension data, if required */
    int size,           /* size of extension, in bytes, for immediate */
    FUNCPTR prtAddress  /* Function to print addresses */
    )
    {
    switch (mode)	/* Effective mode */
	{
	case 0x00:    				/* Dn */
	    printf ("D%x", reg);
	    break;

	case 0x01:				/* An */
	    printf ("A%x", reg);
	    break;

	case 0x02:				/* (An) */
	    printf ("(A%x)", reg);
	    break;

	case 0x03:				/* (An)+ */
	    printf ("(A%x)+", reg);
	    break;

	case 0x04:				/* -(An) */
	    printf ("-(A%x)", reg);
	    break;

	case 0x05:				/* (d16,An) */
	    printf ("(%#x,A%x)", extension [0], reg);
	    break;

	case 0x06:				/* addr reg + index + offset */
	    prIndirectIndex (&extension [0], mode, reg);
	    break;

	case 0x07:
	    switch (reg)
		{
		/* With mode 7, sub-modes are determined by the
		   register number */

		case 0x0:				/* abs.short */
		    (*prtAddress) (extension [0]);
		    break;

		case 0x1:				/* abs.long */
		    (*prtAddress) (extension [1] + (extension [0] << 16));
		    break;

		case 0x2:				/* PC + displacement */
		    printf ("(%#x,PC)", extension [0]);
		    break;

		case 0x3:				/* rel + ind + off */
		    prIndirectIndex (&extension [0], mode, reg);
		    break;

		case 0x4:				/* imm. */
		    switch (size)
			{
			case 1:			/* 1 byte */
			    printf ("#%#x", extension [0] & 0xff);
			    break;
			case 2:			/* 2 bytes */
			    printf ("#%#x", extension [0]);
			    break;
			case 4:
			    printf ("#%#x%04x", extension [0], extension [1]);
			    break;
		        case 8:
			    printf ("#%#x%04x%04x%04x", extension [0],
				    extension [1], extension [2],
				    extension [3]);
			    break;
			}
		    break;
		}
	}
    }
/*******************************************************************************
*
* prMovemRegs - print the regs for a movem instruction
*/

LOCAL void prMovemRegs
    (
    FAST USHORT extension,
    FAST USHORT mode
    )
    {
    FAST int ix;
    BOOL slash = FALSE;		/* keep track of slash's between registers */
    BOOL forward  = mode == 4;
    int  repeatCount;
    char regChar  = 'D';
    BOOL isRange  = FALSE;	/* printing range of registers*/
    BOOL nextSet  = FALSE;	/* set to TRUE if next bit is set */

    /* If the mode is predecrement, the extension word has the bits in
       the opposite order, which explains all the weird conditionals below. */

    for (repeatCount = 0; repeatCount < 2; repeatCount++)
	{
	for (ix = 0; ix <= 7; ix++)
	    {
	    if ((extension & (forward ? 0x8000 : 1)) != 0)
		{
		/* see if the next bit is set */

		nextSet = (((forward ? extension << 1 : extension >> 1) &
			   (forward ? 0x8000 : 1)) && ix != 7);

		/*
		 * If we're not printing a range of registers, just print ",DX"
		 * If we're at the end of a range, print -DX.  If neither 
		 * applies, don't print anything.
		 */

		if (!isRange)
		    {
		    if (slash)
			printf ("/");
		    printf ("%c%x", regChar, ix);
		    }
		else
		    {
		    if (!nextSet)
			printf ("-%c%x", regChar, ix);
		    }

		/*
		 * If the next bit is set, then we're in a range of registers.
		 * Set isRange and slash appropriately.
		 */

		if (nextSet)
		    {
		    slash = FALSE;
		    isRange = TRUE;
		    }
		else
		    {
		    slash = TRUE;
		    isRange = FALSE;
		    }
		}

	    extension = forward ? extension << 1 : extension >> 1;
	    }

	regChar = 'A';
	}
    }
/*******************************************************************************
*
* prFmovemr - print the registers for a fmovemr instruction
*/

LOCAL void prFmovemr
    (
    FAST USHORT mode,
    FAST USHORT rlist
    )
    {
    FAST int ix;
    BOOL slash = FALSE;		/* keep track of slash's between registers */
    BOOL postincr = mode == 2 || mode == 3;
    BOOL isRange  = FALSE;	/* printing range of registers*/
    BOOL nextSet  = FALSE;	/* set to TRUE if next bit is set */

    for (ix = 0; ix <= 7; ix++)
	{
	if (rlist & (postincr ? 0x80 : 1))
	    {
	    /* see if the next bit is set */

	    nextSet = (((postincr ? rlist << 1 : rlist >> 1) &
		       (postincr ? 0x80 : 1)) && ix != 7);

	    /*
	     * If we're not printing a range of registers, just print ",FX"
	     * If we're at the end of a range, print -FX.  If neither 
	     * applies, don't print anything.
	     */

	    if (!isRange)
		{
		if (slash)
		    printf ("/");
		printf ("F%x", ix);
		}
	    else
		{
		if (!nextSet)
		    printf ("-F%x", ix);
		}

	    /*
	     * If the next bit is set, then we're in a range of registers.
	     * Set isRange and slash appropriately.
	     */

	    if (nextSet)
		{
		slash = FALSE;
		isRange = TRUE;
		}
	    else
		{
		slash = TRUE;
		isRange = FALSE;
		}
	    }
	rlist = postincr ? rlist << 1 : rlist >> 1;
	}
    }

/*******************************************************************************
*
* prFmovemcr - print the regs for a fmovemcr instruction
*/

LOCAL void prFmovemcr
    (
    FAST USHORT rlist
    )
    {
    printf ("#<");
    if (rlist & 1)
	printf ("FPIAR,");
    if (rlist & 2)
	printf ("FPSR,");
    if (rlist & 4)
	printf ("FPCR");
    printf (">");
    }
/*******************************************************************************
*
* prtSizeField - print the size field of an instruction (.S, .W, or .L)
*/

LOCAL void prtSizeField
    (
    USHORT binInst [],
    FAST INST *iPtr
    )
    {
    switch (iPtr->type)
	{
	case itLea:
	case itBcd:
	case itNbcd:
	case itMoveTSR:
	case itMoveFSR:
	case itMoveCCR:
	case itComplete:
	case itMoveq:
	case itExg:
	case itSwap:
	case itUnlk:
	case itTrap:
	case itMoveUSP:
	case itStop:
	case itBra:
	case itBfchg:
	case itBfext:
	case itBfins:
	case itDb:
	case itScc:
	case itRTD:
	case itMovec:
	case itMoveFCCR:
	case itBkpt:
	case itCallm:
	case itPack:
	case itRtm:
	case itImmCCR:
	case itImmTSR:
	case itCpGen:
	case itCpSave:
	case itMemShift:
	case itCpush:
        case itWDebug:
	    printf ("  ");
	    break;
	case itIntouch:
	    printf (" ");
	    break;

	case itDynBit:
	case itStatBit:
	    printf (((binInst [0] & 0x0038) == 0) ? ".L" : ".B");
	    break;

	case itNegx:
	case itQuick:
	case itX:
	case itImm:
	case itMoves:
	    switch ((binInst [0] & 0x00c0) >> 6)
		{
		case 0:
		    printf (".B");
		    break;
		case 1:
		case 3:
		    printf (".W");
		    break;
		case 2:
		    printf (".L");
		    break;
		}
	    break;

	case itOr:
	case itCmpm:
	case itRegShift:
	    switch ((binInst [0] & 0x00c0) >> 6)
		{
		case 0:
		    printf (".B");
		    break;
		case 1:
		    printf (".W");
		    break;
		case 2:
		    printf (".L");
		    break;
		}
	    break;

	case itCas:
	case itCas2:
	    switch ((binInst [0] & 0x0600) >> 9)
		{
		case 1:
		    printf (".B");
		    break;
		case 2:
		    printf (".W");
		    break;
		case 3:
		    printf (".L");
		    break;
		}
	    break;

	case itChk2:
	    switch ((binInst [0] & 0x0600) >> 9)
		{
		case 0:
		    printf (".B");
		    break;
		case 1:
		    printf (".W");
		    break;
		case 2:
		    printf (".L");
		    break;
		}
	    break;

	case itTrapcc:
	    switch (binInst [0] & 7)
		{
		case 2:
		    printf (".W");
		    break;

		case 3:
		    printf (".L");
		    break;

		case 4:
		    printf ("  ");
		    break;
		}
	    break;

	case itChk:
	    printf (((binInst [0] & 0x0080) == 0) ? ".W" : ".L");
	    break;

	case itMoveA:
	    printf (((binInst [0] & 0x1000) == 0) ? ".L" : ".W");
	    break;

	case itAdda:
	    printf (((binInst [0] & 0x0100) == 0) ? ".W" : ".L");
	    break;

	case itMovem:
	case itMovep:
	case itExt:
	case itCpBcc:
	    printf (((binInst [0] & 0x0040) == 0) ?  ".W" : ".L");
	    break;

	case itCpTrapcc:
	    switch (binInst [0] & 7)
		{
		case 2:
		    printf (".W");
		    break;
		case 3:
		    printf (".L");
		    break;
		case 4:
		    printf ("  ");
		    break;
		}
	    break;

	case itMoveB:
	case itCpScc:
	    printf (".B");
	    break;

	case itMoveW:
	case itDivW:
	case itLink:
	case itCpDbcc:
	    printf (".W");
	    break;

	case itMoveL:
	case itDivL:
	case itLinkL:
	    printf (".L");
	    break;

	/* fpp instructions */
	case itFb:
		if (binInst[0] & 0x0040)
			printf (".L");
		else
			printf (".W");
		break;

	case itFrestore:
	case itFsave:
	case itFdb:
	case itFnop:
		printf ("  ");
		break;

	case itFtrap:
		if ((binInst[0] & 0x7) == 0x2)
			printf (".W");
		else if ((binInst[0] & 0x7) == 0x3)
			printf (".L");
		break;

	case itFmovek:
		switch ((binInst[1] & 0x1c00) >> 10)
		    {
		    case 0:		printf (".L"); break;
		    case 1:		printf (".S"); break;
		    case 2:		printf (".X"); break;
		    case 3:		printf (".P"); break;
		    case 4:		printf (".W"); break;
		    case 5:		printf (".D"); break;
		    case 6:		printf (".B"); break;
		    case 7:		printf (".P"); break;
		    }
		break;

	case itFmovel:
	case itFmovemc:
		printf (".L");
		break;

	case itFmovecr:
	case itFmovem:
		printf (".X");
		break;

	case itFabs:
	case itFacos:
	case itFadd:
	case itFasin:
	case itFatan:
	case itFatanh:
	case itFcmp:
	case itFcos:
	case itFcosh:
	case itFdiv:
	case itFetox:
	case itFetoxm1:
	case itFgetexp:
	case itFgetman:
	case itFint:
	case itFintrz:
	case itFlog10:
	case itFlog2:
	case itFlogn:
	case itFlognp1:
	case itFmod:
	case itFmove:
	case itFmul:
	case itFneg:
	case itFrem:
	case itFscale:
	case itFs:
	case itFsgldiv:
	case itFsglmul:
	case itFsin:
	case itFsincos:
	case itFsinh:
	case itFsqrt:
	case itFsub:
	case itFtan:
	case itFtanh:
	case itFtentox:
	case itFtst:
	case itFtwotox:
	    if (binInst[1] & 0x4000)
		{
		switch ((binInst[1] & 0x1c00)>>10)
		    {
		    case 0:
			    printf (".L"); break;
		    case 1:
			    printf (".S"); break;
		    case 2:
			    printf (".X"); break;
		    case 3:
			    printf (".P"); break;
		    case 4:
			    printf (".W"); break;
		    case 5:
			    printf (".D"); break;
		    case 6:
			    printf (".B"); break;
		    }
		}
	    else
	        printf (".X"); break;
	    break;

	/*    MAC instructions for Coldfire 5206 & 53xx	*/

	case itMoveFACC:
	case itMoveFMACSR:
	case itMoveFMASK:
	case itMoveTACC:
	case itMoveTCCR:
	case itMoveTMACSR:
	case itMoveTMASK:
	    printf (".L");
	    break;
	   
	case itMac:
	case itMacl:
	case itMsac:
	case itMsacl:
		switch (binInst [1] & 0x0800)	/* SZ Size field */
		    {
		    case 0:	printf (".W"); 	break;
		    default: 	printf (".L");	break;
		    }
	    break;

	/* End of "MAC instructions for Coldfire 5206 & 53xx" */

	/* Coldfire version 4 instruction set enhancements */
	
	case itMvs:
	case itMvz:
		switch (binInst [0] & 0x0040)	/* SZ Size field */
		    {
		    case 0:	printf (".B"); 	break;
		    default: 	printf (".W");	break;
		    }
	    break;

	case itMove3q:
	case itSats:
    	    printf ("  ");
	    break;
	
	/* End of Coldfire version 4 instruction set enhancements */
	}
    }
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
* prOffWid - print the offset and width fields of an instruction
*/

LOCAL void prOffWid
    (
    FAST USHORT dO,             /* if dO is true, offset in data reg */
    FAST USHORT offset,         /* field offset */
    FAST USHORT dW,             /* if dW is true, width in data reg */
    FAST USHORT width           /* field width */
    )
    {
    printf (dO ? "{D%x:" : "{#%d:", offset);
    printf (dW ? "D%x}" : "#%d}", width);
    }
/*******************************************************************************
*
* prIndirectIndex - print memory indirect with index, address register or
* 	program counter
*
* Assumes only modes 6 and 7 of effective addressing
*/

LOCAL void prIndirectIndex
    (
    USHORT extension [],
    USHORT mode,
    USHORT reg
    )
    {
    USHORT scale;		/* scaling factor */
    USHORT bdSize;		/* base displacement size */
    USHORT iS;			/* index suppress bit */
    USHORT indexReg;		/* index register number */
    USHORT indexIndirect;	/* index/indirect selection */

    scale 	= (extension [0] & 0x0600) >> 9;
    bdSize 	= (extension [0] & 0x0030) >> 4;
    iS		= (extension [0] & 0x0040) >> 6;
    indexReg	= (extension [0] & 0x7000) >> 12;
    indexIndirect = extension [0] & 7;

    if ((extension [0] & 0x0100) == 0)
	{
    	/* address register indirect with index (8-bit displacement) */

	printf ("(%#x,", extension [0] & 0xff); /* print displacement */

	/* print address register */

	if (mode == 7)
	    printf ("PC,");
	else
	    printf ("A%x,", reg);

	/* print the index register.  The high order bit of the
	   extension word determines whether it's a D or A reg */

	printf (extension [0] & 0x8000 ? "A%x" : "D%x", indexReg);

	/* determine whether the index register is a word or a long,
	   also determined by a bit in the extension word */

	printf (extension [0] & 0x0800 ? ".L" : ".W");

	/* print the scaling factor */

	printf ("*%d)", 1 << scale);
	}

    /*else if ((iS == 1) || ((iS == 0) && (indexIndirect == 0))) --ism */
    else if ((iS == 0) && (indexIndirect == 0))
	{
    	/* address register indirect with index (base displacement)
	 * or PC indirect with index (base displacement)
	 */

	printf ("(");

	/* print the base displacement, address register, index register,
	   length, and scaling factor */

	prDisplace (bdSize, &extension [1]);
	if (mode == 7)
	    printf (",PC,");
	else if ((extension[0] & 0x80) == 0)
	    printf (",A%x,", reg);
	else
	    printf (",");
	printf (extension [0] & 0x8000 ? "A%x" : "D%x", indexReg);
	printf (extension [0] & 0x0800 ? ".L" : ".W");
	printf ("*%d)", 1 << scale);
	}

    /*else if ((iS == 0) && ((indexIndirect > 4) && (indexIndirect < 8)))--ism*/
    else if ((iS == 1) || ((iS == 0) && ((indexIndirect > 4) &&
		(indexIndirect < 8))))
    	/* memory indirect post-indexed */
	{
	printf ("([");

	/* print the base displacement, address register, index register,
	   length, and scaling factor */

	prDisplace (bdSize, &extension [1]);
	if (mode == 7)
	    printf (",PC],");
	else
	    printf (",A%x],", reg);

	if (iS==0) /* no suppression of index */
		{
		printf (extension [0] & 0x8000 ? "A%x" : "D%x", indexReg);
		printf (extension [0] & 0x0800 ? ".L" : ".W");
		printf ("*%d,", 1 << scale);
		}

	/* print the outer displacement */

	prDisplace (extension [0] & 7, &extension [0] + bdSize);
	printf (")");
	}

    else if ((iS == 0) && (indexIndirect >= 1) && (indexIndirect <= 3))
    	/* memory indirect pre-indexed */
	{
	printf ("([");

	/* print the base displacement, address register, index register,
	   length, and scaling factor */

	prDisplace (bdSize, &extension [1]);
	if (mode == 7)
	    printf (",PC,");
	else
	    printf (",A%x,", reg);

	printf (extension [0] & 0x8000 ? "A%x" : "D%x", indexReg);
	printf (extension [0] & 0x0800 ? ".L" : ".W");
	printf ("*%d],", 1 << scale);

	/* print the outer displacement */

	prDisplace (extension [0] & 7, &extension [0] + bdSize);
	printf (")");
	}
    }
/*******************************************************************************
*
* prDisplace - print displacement
*
* Used for printing base and outer displacements.  Only looks at two least
* significant bits of the size.
*/

LOCAL void prDisplace
    (
    USHORT size,
    USHORT pDisp []
    )
    {
    switch (size & 3)
	{
	case 1:				/* NULL displacement */
	    printf ("0");
	    break;

	case 2:				/* word displacement */
	    printf ("%#x", pDisp [0]);
	    break;

	case 3:				/* long displacement */
	    printf ("%#x%04x", pDisp [0], pDisp [1]);
	    break;
	}
    }
/**************************************************************************
*
* dsmData - disassemble and print a word as data
*
* This routine disassembles and prints a single 16-bit word as data (that is,
* as a DC.W assembler directive) on standard output.  The disassembled data
* will be prepended with the address passed as a parameter.
*
* RETURNS: The number of words occupied by the data (always 1).
*/

int dsmData
    (
    USHORT *binInst,    /* Pointer to the data */
    int address         /* Address prepended to data */
    )
    {
    dsmPrint (binInst, (INST *)NULL, address, 1, (FUNCPTR) nPrtAddress);
    return (1);
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
* If <prtAddress> is zero, dsmInst() will use a default routine that prints
* addresses as hex numbers.
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
* The directive DC.W (declare word) is printed for unrecognized instructions.
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

    iPtr = dsmFind (binInst);
    size = dsmNwords (binInst, iPtr);
    dsmPrint (binInst, iPtr, address, size, (FUNCPTR) prtAddress);
    return (size);
    }
/*******************************************************************************
*
* dsmNbytes - determine the size of an instruction
*
* This routine reports the size, in bytes, of an instruction.
*
* RETURNS:
* The size of the instruction, or
* 0 if the instruction is unrecognized.
*/

int dsmNbytes
    (
    FAST USHORT *binInst        /* Pointer to the instruction */
    )
    {
    FAST INST *iPtr = dsmFind (binInst);

    return ((iPtr == NULL) ? 0 : 2 * dsmNwords (binInst, iPtr));
    }
