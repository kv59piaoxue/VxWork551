/* dsmLib.c - i80x86 disassembler */

/* Copyright 1984-2003 Wind River Systems, Inc. */

#include "copyright_wrs.h"

/*
modification history
--------------------
01m,01mar03,pai  Fixed initialization in dsmInstGet() and printing logic as
                 part of (SPR 86339) work.
01l,16sep02,pai  Updated support for SSE2 & Pentium 4 instructions.
                 Implemented a fix for FP arithmetic insns (SPR 34224).
                 Corrected decode of IN and OUT w/ imm8 operands (SPR 75451).
01k,27mar02,hdn  fixed the CALL/JMP ptr16:16/32 offset size (spr 73624)
01j,30aug01,hdn  added SIMD, sysenter/exit support.
                 always print the disassembled address on 8 digits with 0x.
01i,06may98,fle  added P5 and P6 related instructions and facilities
01h,14nov94,hdn  changed D->DISR, W->WFUL, S->SEXT, P->POP, A->AX, I->IMM.
01g,29may94,hdn  removed I80486.
01f,31aug93,hdn  changed a type of 1st parameter, from char to UCHAR.
01e,02aug93,hdn  fixed a case that has mod=0,rm=5,disp32 operand.
01d,01jun93,hdn  updated to 5.1
                  - changed functions to ansi style
                  - fixed #else and #endif
                  - changed VOID to void
                  - changed copyright notice
01c,18mar93,hdn  supported 486 instructions.
01b,05nov92,hdn  supported "16 bit operand","rep","repne","shift by 1".
                 fixed a bug that is about "empty index".
01a,23jun92,hdn  written. 
*/

/*
This library contains everything necessary to print i80x86 object code in
assembly language format. 

The programming interface is via dsmInst(), which prints a single disassembled
instruction, and dsmNbytes(), which reports the size of an instruction.

To disassemble from the shell, use l(), which calls this
library to do the actual work.  See dbgLib for details.

INCLUDE FILE: dsmLib.h

SEE ALSO: dbgLib
*/


/* includes */

#include "wtxtypes.h"
#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include "errnoLib.h"
#include "dsmLib.h"


/* macros */

#define UNKNOWN_INSN_DESC(pInsn) \
    ( \
    ((const INST *)(pInsn) == NULL) || \
    (((const INST *)(pInsn))->pOpc == NULL) \
    )


/* locals */

/*
 * This table is ordered by the number of bits in an instruction's 
 * mask, beginning with the greatest number of bits in masks.  
 * This scheme is used for avoiding conflicts between instructions 
 * with matching bit patterns.  The instruction ops are arranged 
 * sequentially within each group of instructions for a particular 
 * mask so that uniqueness can be easily spotted.  
 */

LOCAL const INST insnTable [] =
    {
    /* OP3 instructions extended by bits 3, 4, and 5 of ModR/M */

    {"PSLLDQ", itPslldq, OP3|MODRM|I8, XMMRM,
        0x66, 0x0f, 0x73, 0x38,    /* opcode */
        0xff, 0xff, 0xff, 0x38},   /* mask */

    {"PSRLDQ", itPsrldq, OP3|MODRM|I8, XMMRM,
        0x66, 0x0f, 0x73, 0x18,    /* opcode */
        0xff, 0xff, 0xff, 0x38},   /* mask */

    /* OP3 instructions */

    {"PSLL", itPsll, OP3|GG|MODRM|I8, XMMRM,
        0x66, 0x0f, 0x70, 0xf0,    /* opcode */
        0xff, 0xff, 0xfc, 0xf8,},  /* mask */

    {"PSRA", itPsra, OP3|GG|MODRM|I8, XMMRM,
        0x66, 0x0f, 0x70, 0xe0,    /* opcode */
        0xff, 0xff, 0xfc, 0xf8},   /* mask */

    {"PSRL", itPsrl, OP3|GG|MODRM|I8, XMMRM,
        0x66, 0x0f, 0x70, 0xd0,    /* opcode */
        0xff, 0xff, 0xfc, 0xf8},   /* mask */

    {"ADDPD", itAddpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x58, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"ADDSD", itAddsd, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0x58, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"ADDSS", itAddss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x58, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"ANDNPD", itAndnpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x55, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"ANDPD", itAndpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x54, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CMPPD", itCmppd, OP3|MODRM|I8, XMMREG|XMMRM,
        0x66, 0x0f, 0xc2, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CMPSD", itCmpsd, OP3|MODRM|I8, XMMREG|XMMRM,
        0xf2, 0x0f, 0xc2, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CMPSS", itCmpss, OP3|MODRM|I8, XMMREG|XMMRM,
        0xf3, 0x0f, 0xc2, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTDQ2PD", itCvtdq2pd, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0xe6, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTPD2DQ", itCvtpd2dq, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0xe6, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTPD2PS", itCvtpd2ps, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x5a, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTPI2PD", itCvtpi2pd, OP3|MODRM|MMXRM, XMMREG,
        0x66, 0x0f, 0x2a, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTPS2DQ", itCvtps2dq, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x5b, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTSD2SI", itCvtsd2si, OP3|MODRM|REG, XMMRM,
        0xf2, 0x0f, 0x2d, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTSD2SS", itCvtsd2ss, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0x5a, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTSI2SD", itCvtsi2sd, OP3|MODRM|REGRM, XMMREG,
        0xf2, 0x0f, 0x2a, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTSI2SS", itCvtsi2ss, OP3|MODRM|REGRM, XMMREG,
        0xf3, 0x0f, 0x2a, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTSS2SD", itCvtss2sd, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x2d, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTSS2SI", itCvtss2si, OP3|MODRM|REG, XMMRM,
        0xf3, 0x0f, 0x2d, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTTPD2DQ", itCvttpd2dq, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xe6, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTTPD2PI", itCvttpd2pi, OP3|MODRM|MMXREG, XMMRM,
        0x66, 0x0f, 0x2c, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTTPS2DQ", itCvttps2dq, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x5b, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTTSD2SI", itCvttsd2si, OP3|MODRM|REG, XMMRM,
        0xf2, 0x0f, 0x2c, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"CVTTSS2SI", itCvttss2si, OP3|MODRM|REG, XMMRM,
        0xf3, 0x0f, 0x2c, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"DIVPD", itDivpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x5e, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"DIVSD", itDivsd, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0x5e, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"DIVSS", itDivss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x5e, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"FCLEX", itFclex, OP3, 0,
        0x9b, 0xdb, 0xe2, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"FINIT", itFinit, OP3, 0,
        0x9b, 0xdb, 0xe3, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"FSTSW", itFstswA, OP3|AX, 0,
        0x9b, 0xdf, 0xe0, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MASKMOVDQU", itMaskmovdqu, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xf7, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MAXPD", itMaxpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x5f, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MAXSD", itMaxsd, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0x5f, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MAXSS", itMaxss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x5f, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MINPD", itMinpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x5d, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MINSD", itMinsd, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0x5d, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MINSS", itMinss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x5d, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MOVDQ2Q", itMovdq2q, OP3|MODRM|MMXREG, XMMRM,
        0xf2, 0x0f, 0xd6, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MOVMSKPD", itMovmskpd, OP3|MODRM|REG, XMMRM,
        0x66, 0x0f, 0x50, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MOVNTPD", itMovntpd, OP3|MODRM|DISR, XMMREG|XMMRM,
        0x66, 0x0f, 0x2b, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MOVQ", itMovq, OP3|MODRM|DISR, XMMREG|XMMRM,
        0x66, 0x0f, 0xd6, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MOVQ", itMovq, OP3|MODRM|DISR, XMMREG|XMMRM,
        0xf3, 0x0f, 0x7e, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MOVQ2DQ", itMovq2dq, OP3|MODRM|MMXRM, XMMREG,
        0xf3, 0x0f, 0xd6, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MULPD", itMulpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x59, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MULSD", itMulsd, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0x59, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MULSS", itMulss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x59, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"ORPD", itOrpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x56, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PACKSSDW", itPackssdw, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x6b, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PACKSSWB", itPacksswb, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x63, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PACKUSWB", itPackuswb, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x67, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PAND", itPand, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xdb, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PANDN", itPandn, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xdf, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PAVGB", itPavgb, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xe0, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */
                                
    {"PAVGW", itPavgw, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xe3, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PEXTRW", itPextrw, OP3|DISR|MODRM|REGRM|I8, XMMREG,
        0x66, 0x0f, 0xc5, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PINSRW", itPinsrw, OP3|MODRM|REGRM|I8, XMMREG,
        0x66, 0x0f, 0xc4, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMADDWD", itPmadd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xf5, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMAXSW", itPmaxsw, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xee, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMAXUB", itPmaxub, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xde, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMINSW", itPminsw, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xea, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMINUB", itPminub, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xda, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMOVMSKB", itPmovmskb, OP3|MODRM|REGRM|DISR, XMMREG,
        0x66, 0x0f, 0xd7, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMULHUW", itPmulhuw, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xe4, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMULHW", itPmulh, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xe5, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMULLW", itPmull, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xd5, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PMULUDQ", itPmuludq, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xf4, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"POR", itPor, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xeb, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PSADBW", itPsadbw, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xf6, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PSHUFD", itPshufd, OP3|MODRM|I8, XMMREG|XMMRM,
        0x66, 0x0f, 0x70, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PSHUFHW", itPshufhw, OP3|MODRM|I8, XMMREG|XMMRM,
        0xf3, 0x0f, 0x70, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PSHUFLW", itPshuflw, OP3|MODRM|I8, XMMREG|XMMRM,
        0xf2, 0x0f, 0x70, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"PXOR", itPxor, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xef, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"RCPSS", itRcpss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x53, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"RSQRTSS", itRsqrtss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x52, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"SQRTPD", itSqrtpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x51, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"SQRTSD", itSqrtsd, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0x51, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"SQRTSS", itSqrtss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x51, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"SUBPD", itSubpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x5c, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"SUBSD", itSubsd, OP3|MODRM, XMMREG|XMMRM,
        0xf2, 0x0f, 0x5c, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"SUBSS", itSubss, OP3|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x5c, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"UCOMISD", itUcomisd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x2e, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"UNPCKHPD", itUnpckhpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x15, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"UNPCKLPD", itUnpcklpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x14, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"XORPD", itXorpd, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x57, 0x00,    /* opcode */
        0xff, 0xff, 0xff, 0x00},   /* mask */

    {"MOVAPD", itMovapd, OP3|MODRM|DISR, XMMREG|XMMRM,
        0x66, 0x0f, 0x28, 0x00,    /* opcode */
        0xff, 0xff, 0xfe, 0x00},   /* mask */

    {"MOVHPD", itMovhpd, OP3|MODRM|DISR, XMMREG,
        0x66, 0x0f, 0x16, 0x00,    /* opcode */
        0xff, 0xff, 0xfe, 0x00},   /* mask */

    {"MOVLPD", itMovlpd, OP3|MODRM|DISR, XMMREG,
        0x66, 0x0f, 0x12, 0x00,    /* opcode */
        0xff, 0xff, 0xfe, 0x00},   /* mask */

    {"MOVSD", itMovsd, OP3|MODRM|DISR, XMMREG|XMMRM,
        0xf2, 0x0f, 0x10, 0x00,    /* opcode */
        0xff, 0xff, 0xfe, 0x00},   /* mask */

    {"MOVD", itMovd, OP3|MODRM|DISR, XMMREG,
        0x66, 0x0f, 0x6e, 0x00,    /* opcode */
        0xff, 0xff, 0xef, 0x00},   /* mask */

    {"MOVDQA", itMovdqa, OP3|MODRM|DISR, XMMREG|XMMRM,
        0x66, 0x0f, 0x6f, 0x00,    /* opcode */
        0xff, 0xff, 0xef, 0x00},   /* mask */

    {"MOVDQU", itMovdqu, OP3|MODRM|DISR, XMMREG|XMMRM,
        0xf3, 0x0f, 0x6f, 0x00,    /* opcode */
        0xff, 0xff, 0xef, 0x00},   /* mask */

    {"MOVSS", itMovss, OP3|MODRM|DISR, XMMREG|XMMRM,
        0xf3, 0x0f, 0x10, 0x00,    /* opcode */
        0xff, 0xff, 0xfe, 0x00},   /* mask */

    {"MOVUPD", itMovupd, OP3|MODRM|DISR, XMMREG|XMMRM,
        0x66, 0x0f, 0x10, 0x00,    /* opcode */
        0xff, 0xff, 0xfe, 0x00},   /* mask */

    {"PADD", itPadd, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xfc, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PADDS", itPadds, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xec, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PADDUS", itPaddus, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xdc, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PCMPEQ", itPcmpeq, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x74, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PCMPGT", itPcmpgt, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x64, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PSLL", itPsll, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xf0, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PSRA", itPsra, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xe0, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PSRL", itPsrl, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xd0, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PSUB", itPsub, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xf8, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PSUBS", itPsubs, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xe8, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PSUBUS", itPsubus, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0xd8, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PUNPCKH", itPunpckh, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x68, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PUNPCKL", itPunpckl, OP3|GG|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x60, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"PUNPCKLQDQ", itPunpcklqdq, OP3|MODRM, XMMREG|XMMRM,
        0x66, 0x0f, 0x6c, 0x00,    /* opcode */
        0xff, 0xff, 0xfc, 0x00},   /* mask */

    {"LFENCE", itLfence, OP3, 0,
        0x0f, 0xae, 0xe8, 0x00,    /* opcode */
        0xff, 0xff, 0xf8, 0x00},   /* mask */

    {"MFENCE", itMfence, OP3, 0,
        0x0f, 0xae, 0xf0, 0x00,    /* opcode */
        0xff, 0xff, 0xf8, 0x00},   /* mask */

    {"SFENCE", itSfence, OP3, 0,
        0x0f, 0xae, 0xf8, 0x00,    /* opcode */
        0xff, 0xff, 0xf8, 0x00},   /* mask */

    /* OP2 instructions extended by bits 3, 4, and 5 of ModR/M */

    {"BT", itBtI, OP2|MODRM|I8, 0,
        0x0f, 0xba, 0x20, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"BTC", itBtcI, OP2|MODRM|I8, 0,
        0x0f, 0xba, 0x38, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"BTR", itBtrI, OP2|MODRM|I8, 0,
        0x0f, 0xba, 0x30, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"BTS", itBtsI, OP2|MODRM|I8, 0,
        0x0f, 0xba, 0x28, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"CLFLUSH", itClflush, OP2|MODRM, 0,
        0x0f, 0xae, 0x38, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"FSAVE", itFsave, OP2|MODRM, 0,
        0x9b, 0xdd, 0x30, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"FSTCW", itFstcw, OP2|MODRM, 0,
        0x9b, 0xd9, 0x38, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"FSTENV", itFstenv, OP2|MODRM, 0,
        0x9b, 0xd9, 0x30, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"FSTSW", itFstsw, OP2|MODRM, 0,
        0x9b, 0xdd, 0x38, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"FXRSTOR", itFxrstor, OP2|MODRM, 0,
        0x0f, 0xae, 0x08, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"FXSAVE", itFxsave, OP2|MODRM, 0,
        0x0f, 0xae, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"LDMXCSR", itLdmxcsr, OP2|MODRM, 0,
        0x0f, 0xae, 0x10, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"LGDT", itLgdt, OP2|MODRM, 0,
        0x0f, 0x01, 0x10, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"LIDT", itLidt, OP2|MODRM, 0,
        0x0f, 0x01, 0x18, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"LLDT", itLldt, OP2|MODRM, 0,
        0x0f, 0x00, 0x10, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"LMSW", itLmsw, OP2|MODRM, 0,
        0x0f, 0x01, 0x30, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"LTR", itLtr, OP2|MODRM, 0,
        0x0f, 0x00, 0x08, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"PREFETCHNTA", itPrefetchnta, OP2|MODRM, 0,
        0x0f, 0x18, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"PREFETCHT0", itPrefetcht0, OP2|MODRM, 0,
        0x0f, 0x18, 0x08, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"PREFETCHT1", itPrefetcht1, OP2|MODRM, 0,
        0x0f, 0x18, 0x10, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"PREFETCHT2", itPrefetcht2, OP2|MODRM, 0,
        0x0f, 0x18, 0x18, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"SGDT", itSgdt, OP2|MODRM, 0,
        0x0f, 0x01, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"SIDT", itSidt, OP2|MODRM, 0,
        0x0f, 0x01, 0x08, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"SLDT", itSldt, OP2|MODRM, 0,
        0x0f, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */
                                
    {"SMSW", itSmsw, OP2|MODRM, 0,
        0x0f, 0x01, 0x20, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */
    
    {"STMXCSR", itStmxcsr, OP2|MODRM, 0,
        0x0f, 0xae, 0x18, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"STR", itStr, OP2|MODRM, 0,
        0x0f, 0x00, 0x08, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"VERR", itVerr, OP2|MODRM, 0,
        0x0f, 0x00, 0x20, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"VERW", itVerw, OP2|MODRM, 0,
        0x0f, 0x00, 0x28, 0x00,    /* opcode */
        0xff, 0xff, 0x38, 0x00},   /* mask */

    {"PSLL", itPsll, OP2|GG|MODRM|MMXRM|I8, 0,
        0x0f, 0x70, 0xf0, 0x00,    /* opcode */
        0xff, 0xfc, 0xf8, 0x00},   /* mask */

    {"PSRA", itPsra, OP2|GG|MODRM|MMXRM|I8, 0,
        0x0f, 0x70, 0xe0, 0x00,    /* opcode */
        0xff, 0xfc, 0xf8, 0x00},   /* mask */

    {"PSRL", itPsrl, OP2|GG|MODRM|MMXRM|I8, 0,
        0x0f, 0x70, 0xd0, 0x00,    /* opcode */
        0xff, 0xfc, 0xf8, 0x00},   /* mask */

    {"MOVHLPS", itMovhlps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x12, 0xc0, 0x00,    /* opcode */
        0xff, 0xff, 0xc0, 0x00},   /* mask */

    {"MOVLHPS", itMovlhps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x16, 0xc0, 0x00,    /* opcode */
        0xff, 0xff, 0xc0, 0x00},   /* mask */

    /* OP2 instructions */

    {"AAD", itAad, OP2, 0,
       0xd5, 0x0a, 0x00, 0x00,    /* opcode */
       0xff, 0xff, 0x00, 0x00},   /* mask */

    {"AAM", itAam, OP2, 0,
        0xd4, 0x0a, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"ADDPS", itAddps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x58, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"ANDNPS", itAndnps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x55, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"ANDPS", itAndps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x54, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"BSF", itBsf, OP2|MODRM|REG, 0,
        0x0f, 0xbc, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"BSR", itBsr, OP2|MODRM|REG, 0,
        0x0f, 0xbd, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"BT", itBtR, OP2|MODRM|REG, 0,
        0x0f, 0xa3, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"BTC", itBtcR, OP2|MODRM|REG, 0,
        0x0f, 0xbb, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"BTR", itBtrR, OP2|MODRM|REG, 0,
        0x0f, 0xb3, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"BTS", itBtsR, OP2|MODRM|REG, 0,
        0x0f, 0xab, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CLTS", itClts, OP2, 0,
        0x0f, 0x06, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CMPPS", itCmpps, OP2|MODRM|I8, XMMREG|XMMRM,
        0x0f, 0xc2, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CMPXCHG8B", itCmpxchg8b, OP2|MODRM, 0,
        0x0f, 0xc7, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"COMISS", itComiss, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x2f, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CPUID", itCpuid, OP2, 0,
        0x0f, 0xa2, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CVTDQ2PS", itCvtdq2ps, OP2|MODRM, XMMREG|XMMRM,
        0xf3, 0x0f, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CVTPI2PS", itCvtpi2ps, OP2|MODRM|MMXRM, XMMREG,
        0x0f, 0x2a, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CVTPS2PD", itCvtps2pd, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x5a, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CVTPS2PI", itCvtps2pi, OP2|MODRM|MMXREG, XMMRM,
        0x0f, 0x2d, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"CVTTPS2PI", itCvttps2pi, OP2|MODRM|MMXREG, XMMRM,
        0x0f, 0x2c, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"DIVPS", itDivps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x5e, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"EMMS", itEmms, OP2, 0,
        0x0f, 0x77, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"F2XM1", itF2xm1, OP2, 0,
    ESC|0x01, 0xf0, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FABS", itFabs, OP2, 0,
    ESC|0x01, 0xe1, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FCHS", itFchs, OP2, 0,
    ESC|0x01, 0xe0, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FCOMPP", itFcompp, OP2, 0,
    ESC|0x06, 0xd9, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FCOS", itFcos, OP2, 0,
    ESC|0x01, 0xff, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FDECSTP", itFdecstp, OP2, 0,
    ESC|0x01, 0xf6, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FINCSTP", itFincstp, OP2, 0,
    ESC|0x01, 0xf7, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FLD1", itFld1, OP2, 0,
    ESC|0x01, 0xe8, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FLDL2E", itFldL2E, OP2, 0,
    ESC|0x01, 0xea, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FLDL2T", itFldL2T, OP2, 0,
    ESC|0x01, 0xe9, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FLDLG2", itFldLG2, OP2, 0,
    ESC|0x01, 0xec, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FLDLN2", itFldLN2, OP2, 0,
    ESC|0x01, 0xed, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FLDPI", itFldPI, OP2, 0,
    ESC|0x01, 0xeb, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FLDZ", itFldZ, OP2, 0,
    ESC|0x01, 0xee, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FNCLEX", itFclex, OP2, 0,
    ESC|0x03, 0xe2, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FNINIT", itFinit, OP2, 0,
    ESC|0x03, 0xe3, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FNOP", itFnop, OP2, 0,
    ESC|0x01, 0xd0, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FNSTSW", itFstswA, OP2|AX, 0,
    ESC|0x07, 0xe0, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FPATAN", itFpatan, OP2, 0,
    ESC|0x01, 0xf3, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FPREM", itFprem, OP2, 0,
    ESC|0x01, 0xf8, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FPREM1", itFprem1, OP2, 0,
    ESC|0x01, 0xf5, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FPTAN", itFptan, OP2, 0,
    ESC|0x01, 0xf2, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FRNDINT", itFrndint, OP2, 0,
    ESC|0x01, 0xfc, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FSCALE", itFscale, OP2, 0,
    ESC|0x01, 0xfd, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FSIN", itFsin, OP2, 0,
    ESC|0x01, 0xfe, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FSINCOS", itFsincos, OP2, 0,
    ESC|0x01, 0xfb, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FSQRT", itFsqrt, OP2, 0,
    ESC|0x01, 0xfa, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FTST", itFtst, OP2, 0,
    ESC|0x01, 0xe4, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FUCOMPP", itFucompp, OP2, 0,
    ESC|0x02, 0xe9, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FXAM", itFxam, OP2, 0,
    ESC|0x01, 0xe5, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FXTRACT", itFxtract, OP2, 0,
    ESC|0x01, 0xf4, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FYL2X", itFyl2x, OP2, 0,
    ESC|0x01, 0xf1, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"FYL2XP1", itFyl2xp1, OP2, 0,
    ESC|0x01, 0xf9, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"IMUL", itImulRwiRM, OP2|MODRM|REG, 0,
        0x0f, 0xaf, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"INVD", itInvd, OP2, 0,
        0x0f, 0x08, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"INVLPG", itInvlpg, OP2|MODRM, 0,
        0x0f, 0x01, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"LAR", itLar, OP2|MODRM|REG, 0,
        0x0f, 0x02, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"LFS", itLfs, OP2|MODRM|REG, 0,
        0x0f, 0xb4, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"LGS", itLgs, OP2|MODRM|REG, 0,
        0x0f, 0xb5, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"LSL", itLsl, OP2|MODRM|REG, 0,
        0x0f, 0x03, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"LSS", itLss, OP2|MODRM|REG, 0,
        0x0f, 0xb2, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"MASKMOVQ", itMaskmovq, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xf7, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"MAXPS", itMaxps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x5f, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"MINPS", itMinps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x5d, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"MOVMSKPS", itMovmskps, OP2|MODRM|REG, XMMRM,
        0x0f, 0x50, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"MOVNTI", itMovnti, OP2|MODRM|REG, 0,
        0x0f, 0xc3, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"MOVNTPS", itMovntps, OP2|MODRM|DISR, XMMREG|XMMRM,
        0x0f, 0x2b, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"MOVNTQ", itMovntq, OP2|MODRM|DISR, XMMREG|XMMRM,
        0x0f, 0xe7, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"MULPS", itMulps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x59, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"ORPS", itOrps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x56, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PACKSSDW", itPackssdw, OP2|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0x6b, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PACKSSWB", itPacksswb, OP2|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0x63, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PACKUSWB", itPackuswb, OP2|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0x67, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PAND", itPand, OP2|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xdb, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PANDN", itPandn, OP2|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xdf, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PAUSE", itPause, OP2, 0,
        0xf3, 0x90, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMADDWD", itPmadd, OP2|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xf5, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMULHUW", itPmulhuw, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xe4, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMULHW", itPmulh, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xe5, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMULLW", itPmull, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xd5, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMULUDQ", itPmuludq, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xf4, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"POR", itPor, OP2|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xeb, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PXOR", itPxor, OP2|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xef, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"RDTSC", itRdtsc, OP2, 0,
        0x0f, 0x31, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"RDMSR", itRdmsr, OP2, 0,
        0x0f, 0x32, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"RDPMC", itRdpmc, OP2, 0,
        0x0f, 0x33, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"RSM", itRsm, OP2, 0,
        0x0f, 0xaa, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SHLD", itShldRMbyI, OP2|MODRM|REG|I8, 0,
        0x0f, 0xa4, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SHLD", itShldRMbyCL, OP2|MODRM|REG|CL, 0,
        0x0f, 0xa5, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SHRD", itShrdRMbyI, OP2|MODRM|REG|I8, 0,
        0x0f, 0xac, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SHRD", itShrdRMbyCL, OP2|MODRM|REG|CL, 0,
        0x0f, 0xad, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SYSENTER", itSysenter, OP2, 0,
        0x0f, 0x34, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SYSEXIT", itSysexit, OP2, 0,
        0x0f, 0x35, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"UD2", itUd2, OP2, 0,
        0x0f, 0x0b, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"WBINVD", itWbinvd, OP2, 0,
        0x0f, 0x09, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"WRMSR", itWrmsr, OP2, 0,
        0x0f, 0x30, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"RCPPS", itRcpps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x53, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"RSQRTPS", itRsqrtps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x52, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SHUFPS", itShufps, OP2|MODRM|I8, XMMREG|XMMRM,
        0x0f, 0xc6, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SQRTPS", itSqrtps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x51, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"SUBPS", itSubps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x5c, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"UCOMISS", itUcomiss, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x2e, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"UNPCKHPS", itUnpckhps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x15, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"UNPCKLPS", itUnpcklps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x14, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"XORPS", itXorps, OP2|MODRM, XMMREG|XMMRM,
        0x0f, 0x57, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PAVGB", itPavgb, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xe0, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */
                                
    {"PAVGW", itPavgw, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xe3, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PEXTRW", itPextrw, OP2|DISR|MODRM|MMXREG|REGRM|I8, 0,
        0x0f, 0xc5, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PINSRW", itPinsrw, OP2|MODRM|MMXREG|REGRM|I8, 0,
        0x0f, 0xc4, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMAXSW", itPmaxsw, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xee, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMAXUB", itPmaxub, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xde, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMINSW", itPminsw, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xea, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMINUB", itPminub, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xda, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PMOVMSKB", itPmovmskb, OP2|MODRM|MMXREG|REGRM|DISR, 0,
        0x0f, 0xd7, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PSADBW", itPsadbw, OP2|MODRM|MMXREG|MMXRM, 0,
        0x0f, 0xf6, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    {"PSHUFW", itPshufw, OP2|MODRM|MMXREG|MMXRM|I8, 0,
        0x0f, 0x70, 0x00, 0x00,    /* opcode */
        0xff, 0xff, 0x00, 0x00},   /* mask */

    /* 15 bits mask */

    {"CMPXCHG", itCmpxchg, OP2|WFUL|MODRM|REG, 0,
        0x0f, 0xb0, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"MOV", itMovC, OP2|DISR|EEE|MODRM, 0,
        0x0f, 0x20, 0x00, 0x00,    /* opcode */
        0xff, 0xfd, 0x00, 0x00},   /* mask */

    {"MOV", itMovD, OP2|DISR|EEE|MODRM, 0,
        0x0f, 0x21, 0x00, 0x00,    /* opcode */
        0xff, 0xfd, 0x00, 0x00},   /* mask */

    {"MOV", itMovT, OP2|DISR|EEE|MODRM, 0,
        0x0f, 0x24, 0x00, 0x00,    /* opcode */
        0xff, 0xfd, 0x00, 0x00},   /* mask */

    {"MOVD", itMovd, OP2|MMXREG|MODRM|DISR, 0,
        0x0f, 0x6e, 0x00, 0x00,    /* opcode */
        0xff, 0xef, 0x00, 0x00},   /* mask */

    {"MOVQ", itMovq, OP2|MMXREG|MMXRM|MODRM|DISR, 0,
        0x0f, 0x6f, 0x00, 0x00,    /* opcode */
        0xff, 0xef, 0x00, 0x00},   /* mask */

    {"MOVUPS", itMovups, OP2|MODRM|DISR, XMMREG|XMMRM,
        0x0f, 0x10, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"MOVAPS", itMovaps, OP2|MODRM|DISR, XMMREG|XMMRM,
        0x0f, 0x28, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"MOVHPS", itMovhps, OP2|MODRM|DISR, XMMREG,
        0x0f, 0x16, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"MOVLPS", itMovlps, OP2|MODRM|DISR, XMMREG,
        0x0f, 0x12, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"MOVSX", itMovsx, OP2|WFUL|MODRM|REG, 0,
        0x0f, 0xbe, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"MOVZX", itMovzx, OP2|WFUL|MODRM|REG, 0,
        0x0f, 0xb6, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REP INS", itRins, OP2|WFUL, 0,
        0xf3, 0x6c, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REP LODS", itRlods, OP2|WFUL, 0,
        0xf3, 0xac, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REP MOVS", itRmovs, OP2|WFUL, 0,
        0xf3, 0xa4, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REP OUTS", itRouts, OP2|WFUL, 0,
        0xf3, 0x6e, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REP STOS", itRstos, OP2|WFUL, 0,
        0xf3, 0xaa, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REPE CMPS", itRcmps, OP2|WFUL, 0,
        0xf3, 0xa6, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REPE SCAS", itRscas, OP2|WFUL, 0,
        0xf3, 0xae, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REPNE CMPS", itRNcmps, OP2|WFUL, 0,
        0xf2, 0xa6, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"REPNE SCAS", itRNscas, OP2|WFUL, 0,
        0xf2, 0xae, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    {"XADD", itXadd, OP2|WFUL|MODRM|REG, 0,
        0x0f, 0xc0, 0x00, 0x00,    /* opcode */
        0xff, 0xfe, 0x00, 0x00},   /* mask */

    /* 14 bits mask */

    {"PADD", itPadd, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xfc, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PADDS", itPadds, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xec, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PADDUS", itPaddus, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xdc, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PCMPEQ", itPcmpeq, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0x74, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PCMPGT", itPcmpgt, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0x64, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PSLL", itPsll, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xf0, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PSRA", itPsra, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xe0, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PSRL", itPsrl, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xd0, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PSUB", itPsub, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xf8, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PSUBS", itPsubs, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xe8, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PSUBUS", itPsubus, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0xd8, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PUNPCKH", itPunpckh, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0x68, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    {"PUNPCKL", itPunpckl, OP2|GG|MMXREG|MMXRM|MODRM, 0,
        0x0f, 0x60, 0x00, 0x00,    /* opcode */
        0xff, 0xfc, 0x00, 0x00},   /* mask */

    /* 13 bits mask */

    {"BSWAP", itBswap, OP1|MODRM, 0,
        0x0f, 0xc8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FADDP", itFaddST, OP2|FD|ST, 0,
    ESC|0x06, 0xc0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCMOVB", itFcmovb, OP2|ST, 0,
    ESC|0x02, 0xc0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCMOVBE", itFcmovbe, OP2|ST, 0,
    ESC|0x02, 0xd0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCMOVE", itFcmove, OP2|ST, 0,
    ESC|0x02, 0xc8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCMOVNB", itFcmovnb, OP2|ST, 0,
    ESC|0x03, 0xc0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCMOVNBE", itFcmovnbe, OP2|ST, 0,
    ESC|0x03, 0xd0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCMOVNE", itFcmovne, OP2|ST, 0,
    ESC|0x03, 0xc8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCMOVNU", itFcmovnu, OP2|ST, 0,
    ESC|0x03, 0xd8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCMOVU", itFcmovu, OP2|ST, 0,
    ESC|0x02, 0xd8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCOM", itFcomST, OP2|ST, 0,
    ESC|0x00, 0xd0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCOMI", itFcomi, OP2|ST, 0,
    ESC|0x03, 0xf0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FCOMP", itFcompST, OP2|ST, 0,
    ESC|0x00, 0xd8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FFREE", itFfree, OP2|ST, 0,
    ESC|0x05, 0xc0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FLD", itFldST, OP2|ST, 0,
    ESC|0x01, 0xc0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FMULP", itFmulST, OP2|FD|ST, 0,
    ESC|0x06, 0xc8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FST", itFstST, OP2|ST, 0,
    ESC|0x05, 0xd0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FSTP", itFstpST, OP2|ST, 0,
    ESC|0x05, 0xd8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FUCOM", itFucom, OP2|ST, 0,
    ESC|0x05, 0xe0, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FUCOMP", itFucomp, OP2|ST, 0,
    ESC|0x05, 0xe8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"FXCH", itFxch, OP2|ST, 0,
    ESC|0x01, 0xc8, 0x00, 0x00,    /* opcode */
        0xff, 0xf8, 0x00, 0x00},   /* mask */

    {"POP", itPopS, OP2|SREG3, 0,
        0x0f, 0x81, 0x00, 0x00,    /* opcode */
        0xff, 0xc7, 0x00, 0x00},   /* mask */

    {"PUSH", itPushS, OP1|SREG3, 0,
        0x0f, 0x80, 0x00, 0x00,    /* opcode */
        0xff, 0xc7, 0x00, 0x00},   /* mask */

    /* 12 + 3 bits mask */

    {"CMOV", itCmovcc, OP2|TTTN|MODRM|REG, 0,
        0x0f, 0x40, 0x00, 0x00,    /* opcode */
        0xff, 0xf0, 0x00, 0x00},   /* mask */

    {"CSET", itCset, OP2|TTTN|MODRM, 0,
        0x0f, 0x90, 0x00, 0x00,    /* opcode */
        0xff, 0xf0, 0x38, 0x00},   /* mask */

    /* 12 bits mask */

    {"CJMPF", itCjmp, OP2|TTTN|DIS, 0,
        0x0f, 0x80, 0x00, 0x00,    /* opcode */
        0xff, 0xf0, 0x00, 0x00},   /* mask */

    {"FDIVP", itFdivST, OP2|FD|ST, 0,
    ESC|0x06, 0xf0, 0x00, 0x00,    /* opcode */
        0xff, 0xf0, 0x00, 0x00},   /* mask */

    {"FSUBP", itFsubST, OP2|FD|ST, 0,
    ESC|0x06, 0xe0, 0x00, 0x00,    /* opcode */
        0xff, 0xf0, 0x00, 0x00},   /* mask */

    {"FADD", itFaddST, OP2|FD|ST, 0,
    ESC|0x00, 0xc0, 0x00, 0x00,    /* opcode */
        0xfb, 0xf8, 0x00, 0x00},   /* mask */

    {"FMUL", itFmulST, OP2|FD|ST, 0,
    ESC|0x00, 0xc8, 0x00, 0x00,    /* opcode */
        0xfb, 0xf8, 0x00, 0x00},   /* mask */

    {"FDIV", itFdivST, OP2|FD|ST, 0,
    ESC|0x00, 0xf0, 0x00, 0x00,    /* opcode */
        0xfb, 0xf0, 0x00, 0x00},   /* mask */

    {"FSUB", itFsubST, OP2|FD|ST, 0,
    ESC|0x00, 0xe0, 0x00, 0x00,    /* opcode */
        0xfb, 0xf0, 0x00, 0x00},   /* mask */

    /* 11 bits mask */

    {"CALL", itCallRM, OP1|MODRM, 0,
        0xff, 0x10, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"CALL", itCallSegRM, OP1|MODRM, 0,
        0xff, 0x18, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FLDCW", itFldcw, OP1|MODRM, 0,
    ESC|0x01, 0x28, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FLDENV", itFldenv, OP1|MODRM, 0,
    ESC|0x01, 0x20, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FLDbcd", itFldBCDM, OP1|MODRM, 0,
    ESC|0x07, 0x20, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FLDext", itFldERM, OP1|MODRM, 0,
    ESC|0x03, 0x28, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FLDint", itFldLIM, OP1|MODRM, 0,
    ESC|0x07, 0x28, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FNSAVE", itFsave, OP1|MODRM, 0,
    ESC|0x05, 0x30, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FNSTCW", itFstcw, OP1|MODRM, 0,
    ESC|0x01, 0x38, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FNSTENV", itFstenv, OP1|MODRM, 0,
    ESC|0x01, 0x30, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FRSTOR", itFrstor, OP1|MODRM, 0,
    ESC|0x05, 0x20, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FSTPbcd", itFstpBCDM, OP1|MODRM, 0,
    ESC|0x07, 0x30, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FSTPext", itFstpERM, OP1|MODRM, 0,
    ESC|0x03, 0x38, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FSTPint", itFstpLIM, OP1|MODRM, 0,
    ESC|0x07, 0x38, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"FNSTSW", itFstsw, OP1|MODRM, 0,
    ESC|0x05, 0x38, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"IMUL", itImulAwiRM, OP1|WFUL|MODRM|AX, 0,
        0xf6, 0x28, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"JMP", itJmpRM, OP1|MODRM, 0,
        0xff, 0x20, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"JMP", itJmpSegRM, OP1|MODRM, 0,
        0xff, 0x28, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"POP", itPopRM, OP1|MODRM, 0,
        0x8f, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    {"PUSH", itPushRM, OP1|MODRM, 0,
        0xff, 0x30, 0x00, 0x00,    /* opcode */
        0xff, 0x38, 0x00, 0x00},   /* mask */

    /* 10 bits mask */

    {"DEC", itDecRM, OP1|WFUL|MODRM, 0,
        0xfe, 0x08, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    {"DIV", itDiv, OP1|WFUL|MODRM|AX, 0,
        0xf6, 0x30, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    {"IDIV", itIdiv, OP1|WFUL|MODRM|AX, 0,
        0xf6, 0x38, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    {"INC", itIncRM, OP1|WFUL|MODRM, 0,
        0xfe, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    {"MOV", itMovItoRM, OP1|WFUL|MODRM|IMM, 0,
        0xc6, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    {"MUL", itMulAwiRM, OP1|WFUL|MODRM|AX, 0,
        0xf6, 0x20, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    {"NEG", itNeg, OP1|WFUL|MODRM, 0,
        0xf6, 0x18, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    {"NOT", itNot, OP1|WFUL|MODRM, 0,
        0xf6, 0x10, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    {"TEST", itTestIanRM, OP1|WFUL|MODRM|IMM, 0,
        0xf6, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x38, 0x00, 0x00},   /* mask */

    /* 9 bits mask */

    {"ADC", itAdcItoRM, OP1|SEXT|WFUL|MODRM|IMM, 0,
        0x80, 0x10, 0x00, 0x00,    /* opcode */
        0xfc, 0x38, 0x00, 0x00},   /* mask */

    {"ADD", itAddItoRM, OP1|SEXT|WFUL|MODRM|IMM, 0,
        0x80, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x38, 0x00, 0x00},   /* mask */

    {"AND", itAndItoRM, OP1|SEXT|WFUL|MODRM|IMM, 0,
        0x80, 0x20, 0x00, 0x00,    /* opcode */
        0xfc, 0x38, 0x00, 0x00},   /* mask */

    {"CMP", itCmpIwiRM, OP1|SEXT|WFUL|MODRM|IMM, 0,
        0x80, 0x38, 0x00, 0x00,    /* opcode */
        0xfc, 0x38, 0x00, 0x00},   /* mask */

    {"OR", itOrItoRM, OP1|SEXT|WFUL|MODRM|IMM, 0,
        0x80, 0x08, 0x00, 0x00,    /* opcode */
        0xfc, 0x38, 0x00, 0x00},   /* mask */

    {"SBB", itSbbIfrRM, OP1|SEXT|WFUL|MODRM|IMM, 0,
        0x80, 0x18, 0x00, 0x00,    /* opcode */
        0xfc, 0x38, 0x00, 0x00},   /* mask */

    {"SUB", itSubIfrRM, OP1|SEXT|WFUL|MODRM|IMM, 0,
        0x80, 0x28, 0x00, 0x00,    /* opcode */
        0xfc, 0x38, 0x00, 0x00},   /* mask */

    {"FADD", itFaddIRM, OP1|MF|MODRM, 0,
    ESC|0x00, 0x00, 0x00, 0x00,    /* opcode */
        0xf9, 0x38, 0x00, 0x00},   /* mask */

    {"FCOM", itFcomIRM, OP1|MF|MODRM, 0,
    ESC|0x00, 0x10, 0x00, 0x00,    /* opcode */
        0xf9, 0x38, 0x00, 0x00},   /* mask */

    {"FCOMP", itFcompIRM, OP1|MF|MODRM, 0,
    ESC|0x00, 0x18, 0x00, 0x00,    /* opcode */
        0xf9, 0x38, 0x00, 0x00},   /* mask */

    {"FLD", itFldIRM, OP1|MF|MODRM, 0,
    ESC|0x01, 0x00, 0x00, 0x00,    /* opcode */
        0xf9, 0x38, 0x00, 0x00},   /* mask */

    {"FMUL", itFmulIRM, OP1|MF|MODRM, 0,
    ESC|0x00, 0x08, 0x00, 0x00,    /* opcode */
        0xf9, 0x38, 0x00, 0x00},   /* mask */

    {"FST", itFstIRM, OP1|MF|MODRM, 0,
    ESC|0x01, 0x10, 0x00, 0x00,    /* opcode */
        0xf9, 0x38, 0x00, 0x00},   /* mask */

    {"FSTP", itFstpIRM, OP1|MF|MODRM, 0,
    ESC|0x01, 0x18, 0x00, 0x00,    /* opcode */
        0xf9, 0x38, 0x00, 0x00},   /* mask */

    {"XOR", itXorItoRM, OP1|SEXT|WFUL|MODRM|IMM, 0,
        0x80, 0x30, 0x00, 0x00,    /* opcode */
        0xfc, 0x38, 0x00, 0x00},   /* mask */

    /* 8 bits mask */

    {"AAA", itAaa, OP1, 0,
        0x37, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"AAS", itAas, OP1, 0,
        0x3f, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"ARPL", itArpl, OP1|MODRM|REG, 0,
        0x63, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"ASIZE", itAsize, OP1, 0,
        0x67, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"BOUND", itBound, OP1|MODRM|REG, 0,
        0x62, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CALL", itCallSeg, OP1|OFFSEL, 0,
        0x9a, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CALL", itCall, OP1|DIS, 0,
        0xe8, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CBW", itCbw, OP1, 0,
        0x98, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CLC", itClc, OP1, 0,
        0xf8, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CLD", itCld, OP1, 0,
        0xfc, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CLI", itCli, OP1, 0,
        0xfa, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CMC", itCmc, OP1, 0,
        0xf5, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CS", itCs, OP1, 0,
        0x2e, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"CWD", itCwd, OP1, 0,
        0x99, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"DAA", itDaa, OP1, 0,
        0x27, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"DAS", itDas, OP1, 0,
        0x2f, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"DS", itDs, OP1, 0,
        0x3e, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"ENTER", itEnter, OP1|D16L8, 0,
        0xc8, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"ES", itEs, OP1, 0,
        0x26, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"FDIV", itFdivIRM, OP1|MF|MODRM, 0,
    ESC|0x00, 0x30, 0x00, 0x00,    /* opcode */
        0xf9, 0x30, 0x00, 0x00},   /* mask */

    {"FS", itFs, OP1, 0,
        0x64, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"FSUB", itFsubIRM, OP1|MF|MODRM, 0,
    ESC|0x00, 0x20, 0x00, 0x00,    /* opcode */
        0xf9, 0x30, 0x00, 0x00},   /* mask */

    {"GS", itGs, OP1, 0,
        0x65, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"HLT", itHlt, OP1, 0,
        0xf4, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"INT", itInt3, OP1, 0,
        0xcc, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"INT", itInt, OP1|I8, 0,
        0xcd, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"INTO", itInto, OP1, 0,
        0xce, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"IRET", itIret, OP1, 0,
        0xcf, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"JECXZ", itJcxz, OP1|D8, 0,
        0xe3, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"JMP", itJmpD, OP1|DIS, 0,
        0xe9, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"JMP", itJmpSeg, OP1|OFFSEL, 0,
        0xea, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"JMP", itJmpS, OP1|D8, 0,
        0xeb, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LAHF", itLahf, OP1, 0,
        0x9f, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LDS", itLds, OP1|MODRM|REG, 0,
        0xc5, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LEA", itLea, OP1|MODRM|REG, 0,
        0x8d, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LEAVE", itLeave, OP1, 0,
        0xc9, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LES", itLes, OP1|MODRM|REG, 0,
        0xc4, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LOCK", itLock, OP1, 0,
        0xf0, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LOOP", itLoop, OP1|D8, 0,
        0xe2, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LOOPNZ", itLoopnz, OP1|D8, 0,
        0xe0, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"LOOPZ", itLoopz, OP1|D8, 0,
        0xe1, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"NOP", itNop, OP1, 0,
        0x90, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"OSIZE", itOsize, OP1, 0,
        0x66, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"POPA", itPopa, OP1, 0,
        0x61, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"POPF", itPopf, OP1, 0,
        0x9d, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"PUSHA", itPusha, OP1, 0,
        0x60, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"PUSHF", itPushf, OP1, 0,
        0x9c, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"REP", itRep, OP1, 0,
        0xf3, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"REPNE", itRepNe, OP1, 0,
        0xf2, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"RET", itRetI, OP1|D16, 0,
        0xc2, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"RET", itRet, OP1, 0,
        0xc3, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"RET", itRetSeg, OP1, 0,
        0xcb, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"RET", itRetSegI, OP1|D16, 0,
        0xca, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"SAHF", itSahf, OP1, 0,
        0x9e, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"SS", itSs, OP1, 0,
        0x36, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"STC", itStc, OP1, 0,
        0xf9, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"STD", itStd, OP1, 0,
        0xfd, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"STI", itSti, OP1, 0,
        0xfb, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"WAIT", itWait, OP1, 0,
        0x9b, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    {"XLAT", itXlat, OP1|WFUL, 0,
        0xd7, 0x00, 0x00, 0x00,    /* opcode */
        0xff, 0x00, 0x00, 0x00},   /* mask */

    /* 7 bits mask */

    {"ADC", itAdcItoA, SF|WFUL|IMM|AX, 0,
        0x14, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"ADD", itAddItoA, SF|WFUL|IMM|AX, 0,
        0x04, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"AND", itAndItoA, SF|WFUL|IMM|AX, 0,
        0x24, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"CMP", itCmpIwiA, SF|WFUL|IMM|AX, 0,
        0x3c, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"CMPS", itCmps, OP1|WFUL, 0,
        0xa6, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"IMUL", itImulRMwiI, OP1|SEXT|MODRM|REG|IMM, 0,
        0x69, 0x00, 0x00, 0x00,    /* opcode */
        0xfd, 0x00, 0x00, 0x00},   /* mask */

    {"IN", itInF, OP1|WFUL|PORT|I8|AX, 0,
        0xe4, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"IN", itInV, OP1|WFUL|AX, 0,
        0xec, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"INS", itIns, OP1|WFUL, 0,
        0x6c, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"LODS", itLods, OP1|WFUL, 0,
        0xac, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"MOV", itMovRMtoS, OP1|DISR|MODRM|SREG3, 0,
        0x8c, 0x00, 0x00, 0x00,    /* opcode */
        0xfd, 0x00, 0x00, 0x00},   /* mask */

    {"MOVS", itMovs, OP1|WFUL, 0,
        0xa4, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"OR", itOrItoA, SF|WFUL|IMM|AX, 0,
        0x0c, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"OUT", itOutF, OP1|WFUL|PORT|I8|AX, 0,
        0xe6, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"OUT", itOutV, OP1|WFUL|AX, 0,
        0xee, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"OUTS", itOuts, OP1|WFUL, 0,
        0x6e, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"PUSH", itPushI, OP1|SEXT|IMM, 0,
        0x68, 0x00, 0x00, 0x00,    /* opcode */
        0xfd, 0x00, 0x00, 0x00},   /* mask */

    {"SBB", itSbbIfrA, SF|WFUL|IMM|AX, 0,
        0x1c, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"SCAS", itScas, OP1|WFUL, 0,
        0xae, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"SHRO", itRolRMby1, OP1|WFUL|MODRM|TTT, 0,
        0xd0, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"SHRO", itRolRMbyCL, OP1|WFUL|MODRM|TTT|CL, 0,
        0xd2, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"SHRO", itRolRMbyI, OP1|WFUL|MODRM|TTT|I8, 0,
        0xc0, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"STOS", itStos, OP1|WFUL, 0,
        0xaa, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"SUB", itSubIfrA, SF|WFUL|IMM|AX, 0,
        0x2c, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"TEST", itTestRManR, OP1|WFUL|MODRM|REG, 0,
        0x84, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"TEST", itTestIanA, SF|WFUL|IMM|AX, 0,
        0xa8, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"XCHG", itXchgRM, OP1|WFUL|MODRM|REG, 0,
        0x86, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    {"XOR", itXorItoA, SF|WFUL|IMM|AX, 0,
        0x34, 0x00, 0x00, 0x00,    /* opcode */
        0xfe, 0x00, 0x00, 0x00},   /* mask */

    /* 6 bits mask */

    {"ADC", itAdcRMtoRM, OP1|DISR|WFUL|MODRM|REG, 0,
        0x10, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"ADD", itAddRMtoRM, OP1|DISR|WFUL|MODRM|REG, 0,
        0x00, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"AND", itAndRMtoRM, OP1|DISR|WFUL|MODRM|REG, 0,
        0x20, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"CMP", itCmpRMwiRM, OP1|DISR|WFUL|MODRM|REG, 0,
        0x38, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"MOV", itMovRMtoMR, OP1|DISR|WFUL|MODRM|REG, 0,
        0x88, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"MOV", itMovAMtoMA, OP1|DISR|WFUL|DIS|AX, 0,
        0xa0, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"OR", itOrRMtoRM, OP1|DISR|WFUL|MODRM|REG, 0,
        0x08, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"POP", itPopS, OP1|SREG2, 0,
        0x07, 0x00, 0x00, 0x00,    /* opcode */
        0xe7, 0x00, 0x00, 0x00},   /* mask */

    {"PUSH", itPushS, OP1|SREG2, 0,
        0x06, 0x00, 0x00, 0x00,    /* opcode */
        0xe7, 0x00, 0x00, 0x00},   /* mask */

    {"SBB", itSbbRMfrRM, OP1|DISR|WFUL|MODRM|REG, 0,
        0x18, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"SUB", itSubRMfrRM, OP1|DISR|WFUL|MODRM|REG, 0,
        0x28, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    {"XOR", itXorRMtoRM, OP1|DISR|WFUL|MODRM|REG, 0,
        0x30, 0x00, 0x00, 0x00,    /* opcode */
        0xfc, 0x00, 0x00, 0x00},   /* mask */

    /* 5 bits mask */

    {"DEC", itDecR, SF|REG, 0,
        0x48, 0x00, 0x00, 0x00,    /* opcode */
        0xf8, 0x00, 0x00, 0x00},   /* mask */

    {"INC", itIncR, SF|REG, 0,
        0x40, 0x00, 0x00, 0x00,    /* opcode */
        0xf8, 0x00, 0x00, 0x00},   /* mask */

    {"POP", itPopR, SF|REG, 0,
        0x58, 0x00, 0x00, 0x00,    /* opcode */
        0xf8, 0x00, 0x00, 0x00},   /* mask */

    {"PUSH", itPushR, SF|REG, 0,
        0x50, 0x00, 0x00, 0x00,    /* opcode */
        0xf8, 0x00, 0x00, 0x00},   /* mask */

    {"XCHG", itXchgA, SF|REG|AX, 0,
        0x90, 0x00, 0x00, 0x00,    /* opcode */
        0xf8, 0x00, 0x00, 0x00},   /* mask */

    /* 4 bits mask */

    {"CJMPS", itCjmp, OP1|TTTN|D8, 0,
        0x70, 0x00, 0x00, 0x00,    /* opcode */
        0xf0, 0x00, 0x00, 0x00},   /* mask */

    {"MOV", itMovItoR, SF|WFUL|REG|IMM, 0,
        0xb0, 0x00, 0x00, 0x00,    /* opcode */
        0xf0, 0x00, 0x00, 0x00},   /* mask */

    /* last entry */

    {NULL, 0, 0, 0,
        0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00}
    };

/* reg[d32=0,1][reg field=0 - 7] */

LOCAL const char * reg[2][8] = 
    {
    {"AX",  "CX",  "DX",  "BX",  "SP",  "BP",  "SI",  "DI"},
    {"EAX", "ECX", "EDX", "EBX", "ESP", "EBP", "ESI", "EDI"}
    };

/* regw[d32=0,1][w bit=0,1][reg field=0 - 7] */

LOCAL const char * regw[2][2][8] = 
    {
    {{"AL",  "CL",  "DL",  "BL",  "AH",  "CH",  "DH",  "BH"},
     {"AX",  "CX",  "DX",  "BX",  "SP",  "BP",  "SI",  "DI"}},
    {{"AL",  "CL",  "DL",  "BL",  "AH",  "CH",  "DH",  "BH"},
     {"EAX", "ECX", "EDX", "EBX", "ESP", "EBP", "ESI", "EDI"}}
    };

LOCAL const char * regmmx[8] =        /* MMX registers */
    {
    "MM0", "MM1", "MM2", "MM3", "MM4", "MM5", "MM6", "MM7"
    };
    
LOCAL const char * regxmm[8] =        /* XMM registers */
    {
    "XMM0", "XMM1", "XMM2", "XMM3", "XMM4", "XMM5", "XMM6", "XMM7"
    };    

LOCAL const char * gg[4] =      /* MMX instruction packed granularities */
    {
    "B",                        /* packed bytes                         */
    "W",                        /* packed words                         */
    "D",                        /* packed double words                  */
    "Q"                         /* packed quad words                    */
    };

/* immL[d32=0,1][w bit=0,1] */

LOCAL const char immL[2][2] = { {1,2},{1,4} };

/* segment registers, sreg3[sreg3=0-7] */

LOCAL const char * sreg3[8] = { "ES","CS","SS","DS","FS","GS","--","--" };

/* segment registers, sreg2[sreg2=0-3] */

LOCAL const char * sreg2[4] = { "ES","CS","SS","DS" };

/* shift rotate opcodes, ttt[ttt=0-7] */

LOCAL const char * ttt[8] = { "ROL","ROR","RCL","RCR","SHL","SHR","---","SAR" };

/* conditional jump opcodes, tttn[tttn=0-15] */

LOCAL const char * tttn[16] = 
    { 
    "O","NO","B","NB","E","NE","BE","NBE",
    "S","NS","P","NP","L","NL","LE","NLE"
    };

/* control registers, */

LOCAL const char * eeec[8] = { "CR0","---","CR2","CR3","CR4","---","---","---" };

/* debug registers, */

LOCAL const char * eeed[8] = { "DR0","DR1","DR2","DR3","DR4","DR5","DR6","DR7" };

/* test registers, */

LOCAL const char * eeet[8] = { "---","---","---","---","---","---","TR6","TR7" };

/* modrm format */

LOCAL const char * modrm[2][3][8] = 
    {
    {{"[BX+SI]",                "[BX+DI]",
      "[BP+SI]",                "[BP+DI]",
      "[SI]",                   "[DI]",
      "0x%04x",                 "[BX]"},
     {"[BX+SI+%d]",             "[BX+DI+%d]", 
      "[BX+SI+%d]",             "[BX+DI+%d]", 
      "[SI+%d]",                "[DI+%d]", 
      "[BP+%d]",                "[BX+%d]"},
     {"[BX+SI+%d]",             "[BX+DI+%d]", 
      "[BX+SI+%d]",             "[BX+DI+%d]",
      "[SI+%d]",                "[DI+%d]", 
      "[BP+%d]",                "[BX+%d]"}},
    {{"[EAX]",                  "[ECX]", 
      "[EDX]",                  "[EBX]",
      "sib",                    "0x%08x", 
      "[ESI]",                  "[EDI]"},
     {"[EAX+%d]",               "[ECX+%d]", 
      "[EDX+%d]",               "[EBX+%d]",
      "sib",                    "[EBP+%d]", 
      "[ESI+%d]",               "[EDI+%d]"},
     {"[EAX+%d]",               "[ECX+%d]", 
      "[EDX+%d]",               "[EBX+%d]",
      "sib",                    "[EBP+%d]", 
      "[ESI+%d]",               "[EDI+%d]"}}
    };

/* sib format */

LOCAL const char * sib[3][8] = 
    {
    {"[EAX+(%3s%2s)]",          "[ECX+(%3s%2s)]", 
     "[EDX+(%3s%2s)]",          "[EBX+(%3s%2s)]",
     "[ESP+(%3s%2s)]",          "[0x%08x+(%3s%2s)]",
     "[ESI+(%3s%2s)]",          "[EDI+(%3s%2s)]"},
    {"[EAX+(%3s%2s)+%d]",       "[ECX+(%3s%2s)+%d]",
     "[EDX+(%3s%2s)+%d]",       "[EBX+(%3s%2s)+%d]",
     "[ESP+(%3s%2s)+%d]",       "[EBP+(%3s%2s)+%d]",
     "[ESI+(%3s%2s)+%d]",       "[EDI+(%3s%2s)+%d]"},
    {"[EAX+(%3s%2s)+%d]",       "[ECX+(%3s%2s)+%d]",
     "[EDX+(%3s%2s)+%d]",       "[EBX+(%3s%2s)+%d]",
     "[ESP+(%3s%2s)+%d]",       "[EBP+(%3s%2s)+%d]",
     "[ESI+(%3s%2s)+%d]",       "[EDI+(%3s%2s)+%d]"}
    };

/* scale */

LOCAL const char * scale[4] = { "x1","x2","x4","x8" };

/* indexR */

LOCAL const char * indexR[8] = { "EAX","ECX","EDX","EBX","no-","EBP","ESI","EDI" };

/* st */

LOCAL const char * const st = "ST(%d)";

/* mf */

LOCAL const char * mf[4] = { "r32", "---", "r64", "---" };

/* CMPSS variations */

LOCAL const char * cmpss[8] =
    {
    "CMPEQSS",            /* imm = 0 */
    "CMPLTSS",            /* imm = 1 */
    "CMPLESS",            /* imm = 2 */
    "CMPUNORDSS",         /* imm = 3 */
    "CMPNEQSS",           /* imm = 4 */
    "CMPNLTSS",           /* imm = 5 */
    "CMPNLESS",           /* imm = 6 */
    "CMPORDSS"            /* imm = 7 */
    };

/* CMPSD variations */

LOCAL const char * cmpsd[8] =
    {
    "CMPEQSD",            /* imm = 0 */
    "CMPLTSD",            /* imm = 1 */
    "CMPLESD",            /* imm = 2 */
    "CMPUNORDSD",         /* imm = 3 */
    "CMPNEQSD",           /* imm = 4 */
    "CMPNLTSD",           /* imm = 5 */
    "CMPNLESD",           /* imm = 6 */
    "CMPORDSD"            /* imm = 7 */
    };

/* CMPPS variations */

LOCAL const char * cmpps[8] =
    {
    "CMPEQPS",            /* imm = 0 */
    "CMPLTPS",            /* imm = 1 */
    "CMPLEPS",            /* imm = 2 */
    "CMPUNORDPS",         /* imm = 3 */
    "CMPNEQPS",           /* imm = 4 */
    "CMPNLTPS",           /* imm = 5 */
    "CMPNLEPS",           /* imm = 6 */
    "CMPORDPS"            /* imm = 7 */
    };

/* CMPPD variations */

LOCAL const char * cmppd[8] =
    {
    "CMPEQPD",            /* imm = 0 */
    "CMPLTPD",            /* imm = 1 */
    "CMPLEPD",            /* imm = 2 */
    "CMPUNORDPD",         /* imm = 3 */
    "CMPNEQPD",           /* imm = 4 */
    "CMPNLTPD",           /* imm = 5 */
    "CMPNLEPD",           /* imm = 6 */
    "CMPORDPD"            /* imm = 7 */
    };

LOCAL BOOL prefixAsize = FALSE;          /* prefix Address Size, 0x67 */
LOCAL BOOL prefixOsize = FALSE;          /* prefix Operand Size, 0x66 */


/* globals */

int dsmAsize = 1;                        /* 32 bits address size */
int dsmDsize = 1;                        /* 32 bits data size */
int dsmDebug = 0;                        /* debug flag */


/* forward declarations */

LOCAL void dsmPass1 (FORMAT_X * pX, FORMAT_Y * pY);
LOCAL void dsmPass2 (FORMAT_X * pX, FORMAT_Y * pY);



/*******************************************************************************
*
* dsmInstGet - get a descriptor for a specified instruction
*
* Given a binary instruction sequence stored at an address specified by
* <pInsn>, this routine will attempt to locate an specific instruction
* descriptor of type INST for the instruction sequence.  If a matching
* INST descriptor can be associated with the binary sequence, the
* FORMAT_X object specified in the <pX> parameter will be initialized
* such that the <FORMAT_X.pI> field points to the associated INST
* descriptor, the <FORMAT_X.obuf> field holds the null-terminated
* ASCII instruction mnemonic, and the <FORMAT_X.pOpc> field points to
* the unprocessed instruction mnemonic (i.e. <pOpc> initially points
* to the address of <obuf>).
*
* The address of the instruction sequence, <pInsn>, will always be
* saved in the <FORMAT_X.pD> field, even in the case of an ERROR return
* from this routine.  The dsmPrint() routine in this library will use
* the <FORMAT_X.pD> field to print the raw binary values in cases
* where those values do not represent instruction mnemonics handled
* in this disassembler.
*
* RETURNS:  OK if a matching INST descriptor is found, else ERROR.
*
* NOMANUAL
*/
LOCAL STATUS dsmInstGet
    (
    const UINT32 * pInsn,       /* Pointer to the instruction */
    FORMAT_X *     pX           /* Pointer to the FORMAT_X    */
    )
    {
    /* Save the address of the binary opcodes and operands. */

    pX->pD = (const UCHAR *) pInsn;

    /* Try to find a table entry which maps the binary to a mnemonic. */

    for (pX->pI = &insnTable[0]; pX->pI->mask0 != 0; ++(pX->pI))
        {
        const UINT32 * const pOpc = (UINT32 *) &(pX->pI->op0);
        const UINT32 * const pMsk = (UINT32 *) &(pX->pI->mask0);

        if (*pOpc == (*pInsn & *pMsk))
            {
            break;
            }
        }

    if (pX->pI->mask0 == 0)
        {
        errnoSet (S_dsmLib_UNKNOWN_INSTRUCTION);

        if (dsmDebug)
            {
            const unsigned char * const insnByte = (unsigned char *) pInsn;

            printf ("unknown instruction:  %2.2x %2.2x %2.2x %2.2x\n",
                    (UCHAR) insnByte[0], (UCHAR) insnByte[1],
                    (UCHAR) insnByte[2], (UCHAR) insnByte[3]);
            }

        return ERROR;
        }


    /*
     * Initialize the FORMAT_X object w/ a copy of the basic instruction
     * mnemonic found in the INST descriptor table.  Initialize the
     * FORMAT_X instruction name pointer w/ the addr. of this "uncooked"
     * mnemonic.
     */

    pX->pOpc = &pX->obuf[0];
    strcpy (pX->obuf, pX->pI->pOpc);


    return OK;
    }

/*******************************************************************************
*
* dsmPass1 - fill FORMAT_X structure.
*
* INTERNAL
* The FORMAT_X address and data size selector fields <a32> and <d32>
* (16- or 32-bit addresses and / or data) are set according to whether
* or not the instruction has an address size prefix and / or operand
* size prefix.
*
* The FORMAT_X <w> field is initially set, under the assumption that
* instructions specify "full-size" - instead of byte size - data.  The
* <w> field can be modified according to specific instruction formats.
*
* RETURNS: N/A
*
* NOMANUAL
*/
LOCAL void dsmPass1
    (
    FORMAT_X *   pX,
    FORMAT_Y *   pY 
    )
    {
    /* pX->lenO = size of Opcode in bytes = 1, 2, or 3 */

    pX->lenO = ((pX->pI->flag & OP3) ? 3 : ((pX->pI->flag & OP2) ? 2 : 1));

    pX->w    = 1;

    pX->a32  = (prefixAsize ? (~dsmAsize & 0x1) : (dsmAsize));
    pX->d32  = (prefixOsize ? (~dsmDsize & 0x1) : (dsmDsize));


    /* 
     * when TTTN flag is defined, use bits 0,1,2,3 of the least significant
     * byte of the opcode to deconstruct the "Condition Test".
     * see Section B.1.6 of Intel Architecture Software Developer's
     * Manual, Volume 2: Instruction Set Reference 
     */

    if (pX->pI->flag & TTTN)
        {
        const char * pS = tttn[*(pX->pD + pX->lenO - 1) & 0x0f];

        if (pX->pI->type == itCjmp)
            {
            memcpy ((void *) pY->obuf, (void *) "J  ", 3);
            memcpy ((void *) &pY->obuf[1], (void *) pS, strlen (pS));
            }
        if (pX->pI->type == itCset)
            {
            memcpy ((void *) pY->obuf, (void *) "SET", 3);
            memcpy ((void *) &pY->obuf[3], (void *) pS, strlen (pS));
            }
        if (pX->pI->type == itCmovcc)
            {
            memcpy ((void *) pY->obuf, (void *) "CMOV", 4);
            memcpy ((void *) &pY->obuf[4], (void *) pS, strlen (pS));
            }

        pX->pOpc = pY->obuf;
        }

    if (pX->pI->flag & TTT)
        pX->pOpc = ttt[(*(pX->pD + pX->lenO) & 0x38) >> 3];

    /* get MMX data granularity */

    if (pX->pI->flag & GG)
        {
        const char * pS = gg[*(pX->pD + pX->lenO - 1) & 0x03];

        memcpy ((void *) pY->obuf, (void *) pX->pOpc, strlen (pX->pOpc));
        memcpy ((void *) &pY->obuf[strlen(pX->pOpc)], (void *) pS, strlen (pS));

        pX->pOpc = pY->obuf;
        }

    /* get a W */

    if (pX->pI->flag & WFUL)
        {
        pX->w = *(pX->pD + pX->lenO - 1) & 0x01;
        if (pX->pI->type == itMovItoR)
            pX->w = (*pX->pD & 0x08) >> 3;
        }

    /* get a S */

    if (pX->pI->flag & SEXT)
        pX->s = (*(pX->pD + pX->lenO - 1) & 0x02) >> 1;

    /* 
     * get a D 
     *
     * for our representation of data direction:
     *           pX->d = 0 is an r/m -> reg transfer 
     *           pX->d = 1 is a  reg -> r/m transfer
     */

    if (pX->pI->flag & DISR)
        {

        /* 
         * MMX instructions reference least significant opcode byte bit 4 for 
         * data direction information.
         *
         * for Intel's representation:
         *    D bit = 0 is an r/m -> reg transfer 
         *    D bit = 1 is a  reg -> r/m transfer 
         */
                                                               
        if (pX->pI->flag & (MMXREG|MMXRM))
            pX->d = (*(pX->pD + pX->lenO - 1) & 0x10) >> 4;

        /* 
         * XMM instructions reference least significant opcode byte bit 0 for 
         * data direction information.
         *
         * for Intel's representation:
         *    D bit = 0 is an r/m -> reg transfer 
         *    D bit = 1 is a  reg -> r/m transfer 
         */

        else if (pX->pI->flag2 & (XMMREG|XMMRM))
             pX->d = (*(pX->pD + pX->lenO - 1) & 0x01);

        /* 
         * all others use least significant byte bit 1 for 
         * data direction information.
         * 
         * BUT... all other instructions use the opposite representation!
         *
         * for Intel's representation:
         *    D bit = 1 is an r/m -> reg transfer 
         *    D bit = 0 is a  reg -> r/m transfer 
         */

        else
            /* invert the state */
            pX->d = (*(pX->pD + pX->lenO - 1) & 0x02) ? 0 : 1;

        /* evaluate the special case instructions! */

        /*
         * PEXTRW is a SIMD instruction, but it operates on MMX
         * register. Therefore it deviates from the above rules.
         * The DISR flag is included in the definition because
         * the data dir is reg -> r/m regardless.
         */

        if (pX->pI->type == itPextrw)
            pX->d = 1;
        }

    /* get a REG */

    if (pX->pI->flag & SREG2)
        pX->reg = (*pX->pD & 0x18) >> 3;
    if (pX->pI->flag & SREG3)
        pX->reg = (*(pX->pD + pX->lenO) & 0x38) >> 3;
    if ((pX->pI->flag & REG) || 
        (pX->pI->flag & MMXREG) ||
        (pX->pI->flag2 & XMMREG))    
        {
        if (pX->pI->flag & SF)
            pX->reg = *pX->pD & 0x07;
        else if (pX->pI->flag & MODRM)
            pX->reg = (*(pX->pD + pX->lenO) & 0x38) >> 3;
        else
            {
            printf ("dsmLib.c error 0: Invalid opcode flag definition.\n");
            printf ("\top = 0x%02x 0x%02x 0x%02x 0x%02x\n",
                    (UCHAR) pX->pD[0], (UCHAR) pX->pD[1],
                    (UCHAR) pX->pD[2], (UCHAR) pX->pD[3]);
            }
        }
    if (pX->pI->flag & EEE)
        pX->reg = (*(pX->pD + pX->lenO) & 0x38) >> 3;

    /* get a ST for 387*/

    if (pX->pI->flag & ST)
        pX->st = *(pX->pD + pX->lenO - 1) & 0x07;

    /* get a MF for 387*/

    if (pX->pI->flag & MF)
        pX->mf = (*pX->pD & 0x06) >> 1;

    /* get a FD for 387 */

    if (pX->pI->flag & FD)
        pX->fd = *pX->pD & 0x04;

    /* get a size of Immediate, 0, 1, 2, 4 */

    if (pX->pI->flag & I8)
        pX->lenI = 1;

    if (pX->pI->flag & IMM)
        {
        if (pX->s)
            pX->lenI = 1;
        else
            pX->lenI = immL[(int)pX->d32][(int)pX->w];
        }

    if (pX->pI->flag & OFFSEL)
        {

        /* 
         * CALL/JMP ptr16:16/32
         * The operand size attribute determines the size of offset (16/32).
         * The operand size attribute is the D flag in the segment desc.
         * The instruction prefix 0x66 can be used to select an operand
         * size other than the default.
         */

        if (pX->d32)
            pX->lenI = 4;
        else
            pX->lenI = 2;
        }

    if (pX->pI->flag & D16L8)
        pX->lenI = 2;

    /* get a size of Displacement, 0, 1, 2, 4 */

    if (pX->pI->flag & D8)
        pX->lenD = 1;

    if (pX->pI->flag & (DIS|D16))
        {
        if (pX->pI->flag & WFUL)
            {
            if (pX->pI->type == itMovAMtoMA)
                pX->lenD = immL[(int)pX->a32][1];
            else
                pX->lenD = immL[(int)pX->d32][(int)pX->w];
            }
        else
            pX->lenD = immL[(int)pX->d32][(int)pX->w];
        }

    if (pX->pI->flag & OFFSEL)
        pX->lenD = 2;

    if (pX->pI->flag & D16L8)
        pX->lenD = 1;

    if (pX->pI->flag & MODRM)
        {
        pX->modrm = 1;
        pY->pD    = pX->pD + pX->lenO;
        pX->mod   = (*pY->pD & 0xc0) >> 6;
        pX->rm    = *pY->pD & 0x07;

        if ((pX->a32 == 0) && (pX->mod != 3))
            {
            if (pX->mod == 1)
                pX->lenD = 1;
            else if ((pX->mod == 2) || ((pX->mod == 0) && (pX->rm == 6)))
                pX->lenD = 2;
            }
        if ((pX->a32 == 1) && (pX->mod != 3))
            {
            if (pX->rm == 4)
                {
                pX->sib = 1;
                pY->pD = pX->pD + pX->lenO + pX->modrm;
                pX->ss = (*pY->pD & 0xc0) >> 6;
                pX->index = (*pY->pD & 0x38) >> 3;
                pX->base = *pY->pD & 0x07;
                if (pX->mod == 1)
                    pX->lenD = 1;
                else if ((pX->mod == 2) || ((pX->mod == 0) && (pX->base == 5)))
                    pX->lenD = 4;
                }
            else
                {
                if (pX->mod == 1)
                    pX->lenD = 1;
                else if ((pX->mod == 2) || ((pX->mod == 0) && (pX->rm == 5)))
                    pX->lenD = 4;
                }
            }
        }
    }

/*******************************************************************************
*
* dsmPass2 - fill FORMAT_Y structure
*
* RETURNS: N/A
*
* NOMANUAL
*/
LOCAL void dsmPass2
    (
    FORMAT_X * pX,
    FORMAT_Y * pY 
    )
    {
    const char * pS = "";

    /* get an instruction length, pY->len */

    pY->len = pX->lenO + pX->modrm + pX->sib + pX->lenD + pX->lenI;

    /* get an opcode pointer, pY->pOpc */

    pY->pOpc = pX->pOpc;

    if (pX->pI->flag & MF)
        {
        char * const pOpcBuf = pY->obuf;
        if (pX->mf & 1)
            {
            memcpy ((void *) (pOpcBuf+1), (void *) pX->pOpc, strlen (pX->pOpc));
            memcpy ((void *) pOpcBuf, (void *) "FI", 2);
            }
        else
            {
            memcpy ((void *) pOpcBuf, (void *) pX->pOpc, strlen (pX->pOpc));
            strcat (pOpcBuf, mf[(int)pX->mf]);
            }
        pY->pOpc = pY->obuf;
        }

    if (pX->pI->flag & POP)
        {
        memcpy ((void *) pY->obuf, (void *) pX->pOpc, strlen (pX->pOpc));
        strcat (pY->obuf, "P");
        pY->pOpc = pY->obuf;
        }

    /* get a register operand buffer, pY->rbuf */

    if (pX->pI->flag & SREG2)
        memcpy ((void *) pY->rbuf, (void *) sreg2[(int)pX->reg],
                strlen (sreg2[(int)pX->reg]));

    if (pX->pI->flag & SREG3)
        memcpy ((void *) pY->rbuf, (void *) sreg3[(int)pX->reg],
                strlen (sreg3[(int)pX->reg]));

    /* get register number */

    if (pX->pI->flag & REG)
        {
        if (pX->pI->flag & WFUL)
            pS = regw[(int)pX->d32][(int)pX->w][(int)pX->reg];
        else
            pS = reg[(int)pX->d32][(int)pX->reg];
        memcpy ((void *) pY->rbuf, (void *) pS, strlen (pS));
        }

    /* get MMX register number */

    if (pX->pI->flag & MMXREG)
        {
        pS = regmmx[ (int) pX->reg];
        memcpy ((void *) pY->rbuf, (void *) pS, strlen (pS));
        }

    /* XMM register */

    if (pX->pI->flag2 & XMMREG)
        {
        pS = regxmm[ (int) pX->reg];
        memcpy ((void *) pY->rbuf, (void *) pS, strlen (pS));
        }


    if (pX->pI->flag & EEE)
        {
        if (pX->pI->type == itMovC)
            pS = eeec[(int)pX->reg];
        else if (pX->pI->type == itMovD)
            pS = eeed[(int)pX->reg];
        else if (pX->pI->type == itMovT)
            pS = eeet[(int)pX->reg];

        memcpy ((void *) pY->rbuf, (void *) pS, strlen (pS));
        pS = reg[(int)pX->d32][(int)pX->rm];
        memcpy ((void *) pY->mbuf, (void *) pS, strlen (pS));
        }

    if (pX->pI->flag & AX)
        {
        if (pX->pI->flag & WFUL)
            pS = regw[(int)pX->d32][(int)pX->w][0];
        else
            pS = reg[(int)pX->d32][0];

        if (pX->pI->flag & REG)
            memcpy ((void *) pY->ibuf, (void *) pS, strlen (pS));
        else
            memcpy ((void *) pY->rbuf, (void *) pS, strlen (pS));
        }

    if (pX->pI->flag & ST)
        sprintf (pY->rbuf, st, pX->st);
    
    /* get a displacement operand buffer, pY->dbuf */

    if (pX->pI->flag & (D8|D16|DIS))
        {
        pY->pD = pX->pD + pX->lenO + pX->modrm + pX->sib;
        if (pX->lenD == 1)
            pY->addr = *(pY->pD);
        else if (pX->lenD == 2)
            pY->addr = *(short *)pY->pD;
        else if (pX->lenD == 4)
            {
            if (pX->pI->flag & D16)
                pY->addr = *(int *)pY->pD & 0x0000ffff;
            else
                pY->addr = *(int *)pY->pD;
            }
        sprintf (pY->dbuf, "0x%x", pY->addr);
        }

    if (pX->pI->flag & OFFSEL)
        sprintf (pY->dbuf, "0x%x", *(USHORT *)(pX->pD + pX->lenO + pX->lenI));
    
    if (pX->pI->flag & D16L8)
        sprintf (pY->dbuf, "0x%x", *(UCHAR *)(pX->pD + pX->lenO + pX->lenI));

    /* get an immediate operand buffer, pY->ibuf */

    if (pX->pI->flag & (IMM|I8))
        {
        pY->pD = pX->pD + pX->lenO + pX->modrm + pX->sib + pX->lenD;
        if (pX->lenI == 1)
            {
            if (pX->s)
                sprintf (pY->ibuf, "%d", *pY->pD);
            else
                sprintf (pY->ibuf, "0x%x", *(UCHAR *)pY->pD);
            }
        if (pX->lenI == 2)
            sprintf (pY->ibuf, "0x%x", *(USHORT *)pY->pD);
        if (pX->lenI == 4)
            sprintf (pY->ibuf, "0x%x", *(UINT *)pY->pD);
       
        /* 
         * The CMPSS, CMPSD, CMPPS, and CMPPD opcode string is modified
         * based on the imm value.
         */

        if ((pX->pI->type == itCmpps) || (pX->pI->type == itCmpss) ||
            (pX->pI->type == itCmppd) || (pX->pI->type == itCmpsd))
            {
            /* verify that (0 <= imm < 8) */

            if (*(UCHAR *)pY->pD < 8)
                {
                if (pX->pI->type == itCmpps)
                    pY->pOpc = cmpps[*(UCHAR *)pY->pD];
                else if (pX->pI->type == itCmpss)
                    pY->pOpc = cmpss[*(UCHAR *)pY->pD];
                else if (pX->pI->type == itCmppd)
                    pY->pOpc = cmppd[*(UCHAR *)pY->pD];
                else /* (pX->pI->type == itCmpsd) */
                    pY->pOpc = cmpsd[*(UCHAR *)pY->pD];
                }
            }
        }

    if (pX->pI->flag & OFFSEL)
        {
        if (pX->lenI == 2)
            sprintf (pY->ibuf, "0x%x", *(USHORT *)(pX->pD + pX->lenO));
        else
            sprintf (pY->ibuf, "0x%x", *(UINT *)(pX->pD + pX->lenO));
        }

    if (pX->pI->flag & D16L8)
        sprintf (pY->ibuf, "0x%x", *(USHORT *)(pX->pD + pX->lenO));

    if (pX->pI->type == itRolRMby1)                
        sprintf (pY->ibuf, "0x1");

    /* get a memory operand buffer, pY->mbuf */

    if (pX->modrm) 
        {
        if (pX->mod == 3)
            {
            if (pX->pI->flag & WFUL)
                pS = regw[(int)pX->d32][(int)pX->w][(int)pX->rm];
            else if (pX->pI->flag & MMXRM)
                pS = regmmx[(int)pX->rm];
            else if (pX->pI->flag2 & XMMRM)
                pS = regxmm[(int)pX->rm];
            else                                /* REGRM defaults to here */
                pS = reg[(int)pX->d32][(int)pX->rm];
            memcpy ((void *) pY->mbuf, (void *) pS, strlen (pS));
            }
        else
            {
            const char * const format =
                modrm[(int)pX->a32][(int)pX->mod][(int)pX->rm];

            pY->pD = pX->pD + pX->lenO + pX->modrm;

            if (pX->a32 == 0)
                {
                if (pX->mod == 0)
                    {
                    if (pX->rm == 6)
                        sprintf (pY->mbuf, format, *(USHORT *)pY->pD);
                        /* see 01e, pY->addr = *(USHORT *)pY->pD; */
                    else
                        sprintf (pY->mbuf, format);
                    }
                else if (pX->mod == 1)
                    sprintf (pY->mbuf, format, *pY->pD);
                else if (pX->mod == 2)
                    sprintf (pY->mbuf, format, *(USHORT *)pY->pD);
                }
            else
                {
                if ((pX->sib) && (pX->rm == 4))
                    {
                    const char * const format =
                        sib[(int)pX->mod][(int)pX->base];

                    pY->pD += pX->sib;
                    if (pX->mod == 0)
                        {
                        if (pX->base == 5)
                            sprintf (pY->mbuf, format, *(int *)pY->pD, 
                                     indexR[(int)pX->index],
                                     scale[(int)pX->ss]);
                        else
                            sprintf (pY->mbuf, format, indexR[(int)pX->index], 
                                     scale[(int)pX->ss]);
                        }
                    else if (pX->mod == 1)
                        sprintf (pY->mbuf, format, indexR[(int)pX->index],
                                 scale[(int)pX->ss], *pY->pD);
                    else if (pX->mod == 2)
                        sprintf (pY->mbuf, format, indexR[(int)pX->index],
                                 scale[(int)pX->ss], *(int *)pY->pD);
                    }
                else 
                    {
                    if (pX->mod == 0)
                        {
                        if (pX->rm == 5)
                            sprintf (pY->mbuf, format, *(int *)pY->pD);
                            /* see 01e, pY->addr = *(int *)pY->pD; */
                        else
                            sprintf (pY->mbuf, format);
                        }
                    else if (pX->mod == 1)
                        sprintf (pY->mbuf, format, *pY->pD);
                    else if (pX->mod == 2)
                        sprintf (pY->mbuf, format, *(int *)pY->pD);
                    }
                }
            }
        }
    }

/*******************************************************************************
*
* dsmPrint - print FORMAT_Y structure.
*
* RETURNS: N/A
*
* NOMANUAL
*/
LOCAL void dsmPrint
    (
    FORMAT_X *  pX,             /* Pointer to the FORMAT_X   */
    FORMAT_Y *  pY,             /* Pointer to the FORMAT_Y   */
    VOIDFUNCPTR prtAddress      /* Address printing function */
    )
    {
    int    ix;
    int    bytesToPrint;


    if (pY->len == 0)
        pY->len = 1;

    bytesToPrint = (((pY->len - 1) >> 3) + 1) << 3;


    /* print out an address */

    printf ("0x%08x  ", (UINT)(pX->pD));

    /* print out a data */

    for (ix = 0; ix < bytesToPrint; ++ix)
        {
        if ((ix & ~0x07) && ((ix & 0x07) == 0))
            printf ("\n          ");

        if (ix < pY->len)
            printf ("%02x ", (UCHAR) pX->pD[ix]);
        else
            printf ("   ");
        }

    /* print out the unknown instruction */

    if (UNKNOWN_INSN_DESC (pX->pI))
        {
        printf (".BYTE          0x%02x\n", (UCHAR) *(pX->pD));
        return;
        }

    /* set the operand pointers based on first flag */

    switch (pX->pI->flag & 0xfffff)
        {
        case REG:
        case SREG3:
        case SREG2:
        case ST:
            pY->pOpr0 = pY->rbuf;
            break;

        case MODRM:
            pY->pOpr0 = pY->mbuf;
            if (pX->pI->type == itRolRMby1)
                pY->pOpr1 = pY->ibuf;
            break;

        case I8:
        case IMM:
            pY->pOpr0 = pY->ibuf;
            break;

        case D8:
        case DIS:
            pY->pOpr0 = (char *)&pY->addr;
            break;

        case D16:
            pY->pOpr0 = pY->dbuf;
            break;

        case (REG|IMM):
            pY->pOpr0 = pY->rbuf;
            pY->pOpr1 = pY->ibuf;
            break;

        case (MODRM|IMM):
        case (MODRM|I8):
        case (MODRM|MMXRM|I8):
            if ((pX->pI->type == itCmpps) || (pX->pI->type == itCmpss))
                {
                pY->pOpr0 = pY->rbuf;
                pY->pOpr1 = pY->mbuf;
                }
            else if (pX->pI->flag2 & XMMREG)
                {
                pY->pOpr0 = pY->mbuf;
                pY->pOpr1 = pY->rbuf;
                pY->pOpr2 = pY->ibuf;
                }
            else
                {
                pY->pOpr0 = pY->mbuf;
                pY->pOpr1 = pY->ibuf;
                }
            break;

        case (MODRM|REG):
        case (MODRM|REGRM):
        case (MODRM|SREG3):
        case (MODRM|EEE):
        case (MODRM|MMXREG):
        case (MODRM|MMXREG|REGRM):
        case (MODRM|MMXREG|MMXRM):
        case (MODRM|MMXRM):
            if (pX->d)
                {
                pY->pOpr0 = pY->mbuf;        /* data dir = reg to r/m */
                pY->pOpr1 = pY->rbuf;
                }
            else
                {
                pY->pOpr0 = pY->rbuf;        /* data dir = r/m to reg */
                pY->pOpr1 = pY->mbuf;
                }
            break;

        case (MODRM|REG|I8):
        case (MODRM|MMXRM|REG|I8):
        case (MODRM|MMXREG|REGRM|I8):
        case (MODRM|MMXREG|MMXRM|I8):
        case (MODRM|REG|IMM):
            if ((pX->pI->type == itShldRMbyI) || (pX->pI->type == itShrdRMbyI))
                {
                pY->pOpr0 = pY->mbuf;
                pY->pOpr1 = pY->rbuf;
                pY->pOpr2 = pY->ibuf;
                }
            else if (pX->d)
                {
                pY->pOpr0 = pY->mbuf;                /* reg -> r/m */
                pY->pOpr1 = pY->rbuf;
                pY->pOpr2 = pY->ibuf;
                }
            else
                {
                pY->pOpr0 = pY->rbuf;                /* r/m -> reg */
                pY->pOpr1 = pY->mbuf;
                pY->pOpr2 = pY->ibuf;
                }
            break;

        case (MODRM|REG|CL):
            pY->pOpr0 = pY->mbuf;
            pY->pOpr1 = pY->rbuf;
            pY->pOpr2 = "CL";
            break;

        case (IMM|AX):
            pY->pOpr0 = pY->rbuf;
            pY->pOpr1 = pY->ibuf;
            break;

        case (MODRM|AX):
            pY->pOpr0 = pY->rbuf;
            pY->pOpr1 = pY->mbuf;
            break;

        case (MODRM|CL):
            pY->pOpr0 = pY->mbuf;
            pY->pOpr1 = "CL";
            break;

        case (DIS|AX):
            if (pX->d)
                {
                pY->pOpr0 = pY->rbuf;
                pY->pOpr1 = pY->dbuf;
                }
            else
                {
                pY->pOpr0 = pY->dbuf;
                pY->pOpr1 = pY->rbuf;
                }
            break;

        case OFFSEL:
        case D16L8:
            pY->pOpr0 = pY->ibuf;
            pY->pOpr1 = pY->dbuf;
            break;

        case (FD|ST):
            if (pX->fd)
                {
                pY->pOpr0 = pY->rbuf;
                pY->pOpr1 = "ST";
                }
            else
                {
                pY->pOpr0 = "ST";
                pY->pOpr1 = pY->rbuf;
                }
            break;

        case (PORT|I8|AX):
            if (pX->pI->type == itInF)
                {
                pY->pOpr0 = pY->rbuf;
                pY->pOpr1 = pY->ibuf;
                }
            else
                {
                pY->pOpr0 = pY->ibuf;
                pY->pOpr1 = pY->rbuf;
                }
            break;

        case (REG|AX):
            pY->pOpr0 = pY->ibuf;
            pY->pOpr1 = pY->rbuf;
            break;

        case AX:
            if (pX->pI->type == itInV)
                {
                pY->pOpr0 = pY->rbuf;
                pY->pOpr1 = "DX";
                }
            else if (pX->pI->type == itOutV)
                {
                pY->pOpr0 = "DX";
                pY->pOpr1 = pY->rbuf;
                }
            else
                pY->pOpr0 = pY->rbuf;
            break;

        case 0:
            break;

        default:
            printf ("dsmLib.c error 1: Invalid opcode flag definition.\n");
            printf ("\top = 0x%02x 0x%02x 0x%02x 0x%02x\n",
                    (UCHAR) pX->pD[0], (UCHAR) pX->pD[1],
                    (UCHAR) pX->pD[2], (UCHAR) pX->pD[3]);
        }

    /* set the operand pointers based on flag2 */

    if ((pX->pI->flag2 & XMMREG) || (pX->pI->flag2 & XMMRM))
        {
        if (pX->d)
            {
            pY->pOpr0 = pY->mbuf;                /* data dir = reg to r/m */
            pY->pOpr1 = pY->rbuf;
            }
        else
            {
            pY->pOpr0 = pY->rbuf;                /* data dir = r/m to reg */
            pY->pOpr1 = pY->mbuf;
            }
        }
    else if (pX->pI->flag2 != 0)
        {
        printf ("dsmLib.c error 2: Invalid opcode flag definition.\n");
        printf ("\top = 0x%02x 0x%02x 0x%02x 0x%02x\n",
                (UCHAR) pX->pD[0], (UCHAR) pX->pD[1],
                (UCHAR) pX->pD[2], (UCHAR) pX->pD[3]);
        }
        
    /* tune up for the special case */

    if ((pY->pOpr0 == pY->mbuf) && (pY->mbuf[0] == 0))
        pY->pOpr0 = (char *)&pY->addr;

    if ((pY->pOpr1 == pY->mbuf) && (pY->mbuf[0] == 0))
        pY->pOpr1 = (char *)&pY->addr;

    if ((pY->pOpr2 == pY->mbuf) && (pY->mbuf[0] == 0))
        pY->pOpr2 = (char *)&pY->addr;

    /* tune up for "+(no-x1)" */

    if (pY->mbuf[0] != 0)
        {
        char * pS = pY->mbuf;
        char * pD = pY->temp;

        for (ix = 0; ix < (int) (strlen (pY->mbuf)); ++ix)
            {
            if ((*pS == '(') && (*(pS+1) == 'n') && (*(pS+2) == 'o'))
                {
                pS += 7;
                pD -= 1;
                }

            *pD++ = *pS++;

            if (*pS == 0)
                break;
            }

        memcpy ((void *) pY->mbuf, (void *) pY->temp, DSM_BUFSIZE32);
        }

    /* tune up for "+-" */

    memset ((void *)pY->temp, 0, DSM_BUFSIZE32);

    if (pY->mbuf[0] != 0)
        {
        char * pS = pY->mbuf;
        char * pD = pY->temp;

        for (ix = 0; ix < (int) (strlen (pY->mbuf)); ++ix)
            {
            if ((*pS == '+') && (*(pS+1) == '-'))
                pS += 1;

            *pD++ = *pS++;

            if (*pS == 0)
                break;
            }

        memcpy ((void *) pY->mbuf, (void *) pY->temp, DSM_BUFSIZE32);
        }

    /* print out the instruction */

    printf ("%-12s   ", pY->pOpc);

    if (pY->pOpr0 != 0)
        {
        if (pY->pOpr0 == (char *)&pY->addr)
            (*prtAddress) ((int)pX->pD + pY->len + pY->addr);
        else
            printf ("%s", pY->pOpr0);
        }

    if (pY->pOpr1 != 0)
        {
        printf (", ");
        if (pY->pOpr1 == (char *)&pY->addr)
            (*prtAddress) ((int)pX->pD + pY->len + pY->addr);
        else
            printf ("%s", pY->pOpr1);
        }

    if (pY->pOpr2 != 0)
        {
        printf (", ");
        if (pY->pOpr2 == (char *)&pY->addr)
            (*prtAddress) ((int)pX->pD + pY->len + pY->addr);
        else
            printf ("%s", pY->pOpr2);
        }

    printf ("\n");

    return;
    }

/*******************************************************************************
*
* nPrtAddress - print addresses as numbers
*
* RETURNS: N/A
*
* NOMANUAL
*/
LOCAL void nPrtAddress
    (
    int address          /* address to print */
    )
    {
    printf ("%#x", (unsigned int) address); 
    }

/**************************************************************************
*
* dsmData - disassemble and print a byte as data
*
* This routine disassembles and prints a single byte as data (that is,
* as a .BYTE assembler directive) on standard out.  The disassembled data will
* be prepended with the address passed as a parameter.
* 
* RETURNS : The number of words occupied by the data (always 1).
*/
int dsmData
    (
    UCHAR * pD,          /* pointer to the data       */
    int     address      /* address prepended to data */
    )
    {
    FORMAT_X formatx;
    FORMAT_Y formaty;

    memset ((void *) &formatx, 0, sizeof (FORMAT_X));
    memset ((void *) &formaty, 0, sizeof (FORMAT_Y));
    
    formatx.pD  = (const char *) pD;
    formaty.len = 1;

    dsmPrint (&formatx, &formaty, nPrtAddress);

    return (1);
    }

/*******************************************************************************
*
* dsmInst - disassemble and print a single instruction
*
* This routine disassembles and prints a single instruction on standard
* output.  The function passed as parameter <prtAddress> is used to print any
* operands that might be construed as addresses.  The function could be a
* subroutine that prints a number or looks up the address in a
* symbol table.  The disassembled instruction will be prepended with the
* address passed as a parameter.
* 
* If <prtAddress> is zero, dsmInst() will use a default routine that prints 
* addresses as hex numbers.
*
* ADDRESS PRINTING ROUTINE
* Many assembly language operands are addresses.  In order to print these
* addresses symbolically, dsmInst() calls a user-supplied routine, passed as a
* parameter, to do the actual printing.  The routine should be declared as:
* .CS
*     void prtAddress 
*         (
*         int    address   /@ address to print @/
*         )
* .CE
* When called, the routine prints the address on standard out in either
* numeric or symbolic form.  For example, the address-printing routine used
* by l() looks up the address in the system symbol table and prints the
* symbol associated with it, if there is one.  If not, it prints the address
* as a hex number.
* 
* If the <prtAddress> argument to dsmInst is NULL, a default print routine is
* used, which prints the address as a hexadecimal number.
* 
* The directive .DATA.H (DATA SHORT) is printed for unrecognized instructions.
* 
* The effective address mode is not checked since when the instruction with
* invalid address mode executed, an exception would happen.
* 
* INCLUDE FILE: dsmLib.h
* 
* INTERNAL  
* The instruction type is defined by the format of instruction's argument 
* list.  So the order of argument list table should not be changed.  The 
* default value of size field is defined with a special bit set in the size 
* offset field.  To distinguish FPU instructions, a special bit is set in 
* the type field in the instruction table.
*
* RETURNS: The number of bytes occupied by the instruction.
*/
int dsmInst
    (
    UCHAR *     pD,            /* Pointer to the instruction       */
    int         address,       /* Address prepended to instruction */
    VOIDFUNCPTR prtAddress     /* Address printing function        */
    )
    {
    FORMAT_X formatx;
    FORMAT_Y formaty;

    memset ((void *) &formatx, 0, sizeof (FORMAT_X));
    memset ((void *) &formaty, 0, sizeof (FORMAT_Y));

    if (prtAddress == NULL)
        prtAddress = nPrtAddress;


    /* Attempt to find a matching INST descriptor for the binary
     * instruction sequence.
     */

    if (dsmInstGet ((UINT32 *) pD, &formatx) == OK)
        {
        dsmPass1 (&formatx, &formaty);


        /* set prefixAsize & prefixOsize state for next insn. */

        prefixAsize = ((formatx.pI->type == itAsize) ? TRUE : FALSE);
        prefixOsize = ((formatx.pI->type == itOsize) ? TRUE : FALSE);


        if (dsmDebug)
            {
            printf ("\n~~~~~~~~~~~~~~~~~~~\n"
                    "FORMAT_X    pOpc = %s\n", formatx.pI->pOpc);
            printf ("            type = 0x%x\n", formatx.pI->type);
            printf ("            flag = 0x%x\n", formatx.pI->flag);
            printf ("              pD = %2.2x %2.2x %2.2x %2.2x\n",
                    (UCHAR) formatx.pD[0], (UCHAR) formatx.pD[1],
                    (UCHAR) formatx.pD[2], (UCHAR) formatx.pD[3]);
            printf ("lenO, lenD, lenI = %d, %d, %d\n",
                   formatx.lenO, formatx.lenD, formatx.lenI);
            printf ("        d32, a32 = %d, %d\n",
                   formatx.d32, formatx.a32);
            printf ("      modrm, sib = %d, %d\n",
                   formatx.modrm, formatx.sib);
            printf ("           w s d = %d %d %d\n",
                   formatx.w, formatx.s, formatx.d);
            printf ("      mod reg rm = %d %d %d\n",
                   formatx.mod, formatx.reg, formatx.rm);
            printf ("   ss index base = %d %d %d\n",
                   formatx.ss, formatx.index, formatx.base);
            }


        dsmPass2 (&formatx, &formaty);


        if (dsmDebug)
            {
            printf ("\nFORMAT_Y     len = %d\n", formaty.len);
            printf ("            obuf = %s\n", formaty.obuf);
            printf ("            rbuf = %s\n", formaty.rbuf);
            printf ("            mbuf = %s\n", formaty.mbuf);
            printf ("            ibuf = %s\n", formaty.ibuf);
            printf ("            dbuf = %s\n\n", formaty.dbuf);
            }
        }


    dsmPrint (&formatx, &formaty, prtAddress);


    return ((formaty.len == 0) ? 1 : formaty.len);
    }

/*******************************************************************************
*
* dsmNbytes - determine the size of an instruction
*
* This routine reports the size, in bytes, of an instruction.
*
* RETURNS: The size of the instruction, or 0 if the instruction is unrecognized.
*/
int dsmNbytes
    (
    UCHAR * pD       /* Pointer to the instruction */
    )
    {
    FORMAT_X formatx;
    FORMAT_Y formaty;

    memset ((void *) &formatx, 0, sizeof (FORMAT_X));
    memset ((void *) &formaty, 0, sizeof (FORMAT_Y));


    /* Attempt to find a matching INST descriptor for the binary
     * instruction sequence.
     */

    if (dsmInstGet ((UINT32 *) pD, &formatx) == OK)
        {
        dsmPass1 (&formatx, &formaty);

        formaty.len = formatx.lenO + formatx.modrm + formatx.sib +
                      formatx.lenD + formatx.lenI;
        }


    return (formaty.len);
    }
