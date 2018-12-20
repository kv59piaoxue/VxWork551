/* dsmips.c - MIPS disassembler */

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
01c,06dec01,agf  add 3 operand support for mtc./mfc.
01b,16jul01,ros  add CofE comment
01a,11jul01,mem  written based on 01n of host/src/tgtsvr/disassembler/dsmMips.c
*/

/*
DESCRIPTION
This library contains everything necessary to print MIPS IV object 
code in assembly language format. 

The programming interface is via dsmMipsInstGet, which prints a single
disassembled instruction, and dsmMipsInstSizeGet, which will tell you
how big an instruction is.

To disassemble from the shell, use l(2), which calls this
library to do the actual work.  See dbgLib(1) for details.

ADDRESS PRINTING ROUTINE
Many assembly language operands are addresses.  In order to print these
addresses symbolically, dsmMipsInstGet calls a user-supplied routine, passed as
a parameter, to do the actual printing.  The routine should be declared as:

.CS
    void prtAddress (int address)
.CE

When called, the routine prints the address on standard out in either
numeric or symbolic form.  For example, the address-printing routine used
by l(2) looks up the address in the system symbol table and prints the
symbol associated with it, if there is one.  If not, it prints the address
as a hex number.

If the <prtAddress> argument to dsmMipsInstGet is NULL, a default print routine
is used, which prints the address as a hexadecimal number.

The directive DC.W (declare word) is printed for unrecognized instructions.

DEFICIENCIES

The address operand printing routine interface has been retained although
it will support only jumps and branches ("lui" and "addiu" pairs are
not coupled here so these cannot be resolved symbolically).  This interface
is provided so that a caller could look up the address operand in the symbol
table and print its symbol name rather than raw address.
*/

/* includes */

#ifdef HOST
#include <string.h>
#include <stdlib.h>

#include "host.h"
#include "dsmMips.h"
#include "cputypes.h"
#include "stdio.h"
#include "symbol.h"
#else
#include "vxWorks.h"
#include "dsmLib.h"
#include "errnoLib.h"
#include "symbol.h"
#include "stdio.h"
#include "sysSymTbl.h"
#include "arch/mips/dbgMipsLib.h"
#endif

/* defines */

#define MAX_LINE_LEN	1000	/* max line length for an instruction        */
#define BUF_MAX_SIZE    30      /* max size of buffer to write in            */

/* 

The CPU bits defined below can be used to identify instructions which
are only valid on a particular set of CPU types.  At some point in the
future it might be valuable to add bits which identify CPU groups such
as ISA, ISA2, etc.  If you add any entry to this list, a corresponding
entry needs to be made to the CPUMASK, defined below.

*/

#define CPU_ANY		(0)
#define CPU_MIPS1	(1 << 0)
#define CPU_MIPS2	(1 << 1)
#define CPU_MIPS3	(1 << 2)
#define CPU_MIPS4	(1 << 3)
#define CPU_MIPS32	(1 << 4)
#define CPU_MIPS64	(1 << 5)

#define CPU_CW4011	(0)		/* dummy */
#define CPU_R4650	(0)		/* dummy */
#define CPU_VR5400	(0)		/* dummy */

#ifndef HOST
#if (CPU==MIPS32)
#define	CPUMASK		(CPU_MIPS1 | CPU_MIPS2 | CPU_MIPS32)
#elif (CPU==MIPS64)
#define CPUMASK		\
    (CPU_MIPS1 | CPU_MIPS2 | CPU_MIPS3 | CPU_MIPS4 | CPU_MIPS32 | CPU_MIPS64)
#else
#error "Illegal CPU value"
#endif
#endif

/*

The following tables represent intruction opcodes and subtypes.
Each table entry consists of four elements:
	-an opcode mnemonic string to be printed if a match occurs,
	-the bit pattern which the relevent part of the opcode is
	 matched with,
	-a mask field to be applied to the instruction to extract,
	-a format string describing the instruction operands.

The inst table is searched linearly to find the first matching instruction.
A match is made when the extracted part of an instruction matches
the 2nd field.  Overloaded instructions such as sll/nop are resolved by
inserting the special case instruction before the general case.

*/

#define ITYPE(op,rs,rt,immed) ((unsigned long) ( ( (op)<<26) | ( ( rs)<<21) | \
						 ( (rt)<<16) | immed))
#define RTYPE(rs,rt,rd,v) ITYPE(0,rs,rt,rd<<11|v)
#define JTYPE(op,val) ( (unsigned long) ( ( (op)<<26) | val))
#define MTYPE(op,rs,rt,rd,v) ITYPE(op,rs,rt,rd<<11|v)

#define RMASK(rs,rt,rd,v) ITYPE(0x3f,rs,rt,rd<<11|v)
#define IMASK(a,b,c)	  ITYPE(0x3f,a,b,c)
#define MMASK(a,b,c)	  ITYPE(0x3f,a,b,((c)<<11)|v)

#define COP1T(fmt,code) ( (unsigned long) ( (17 << 26) | (1 << 25) | \
					   (fmt << 21) | code))
#define COP1B(fmt,code) COP1T(fmt,code)
#define COP1TMSK	( (unsigned long) ( (0x3f << 26) | (1 << 25) | \
					   (0xf << 21) | 0x3f))
#define COP1BMSK	( (unsigned long) (COP1TMSK | (0x1f << 16)))
#define COP1CMPMSK	( (unsigned long) (COP1TMSK | (0x1f << 6)))

#define JTYPE_OP(code)  ((code & 0xfc000000) >> 26)
#define JTYPE_TARGET(code)      (code & 0x03ffffff)
#define ITYPE_OP(code)  ((code & 0xfc000000) >> 26)
#define ITYPE_RS(code)  ((code & 0x03e00000) >> 21)
#define ITYPE_RT(code)  ((code & 0x001f0000) >> 16)
#define ITYPE_I(code)   ((unsigned long) (short)(code & 0x0000ffff))
#define UTYPE_OP(code)  ((code & 0xfc000000) >> 26)
#define UTYPE_RS(code)  ((code & 0x03e00000) >> 21)
#define UTYPE_RT(code)  ((code & 0x001f0000) >> 16)
#define UTYPE_U(code)   (code & 0x0000ffff)
#define RTYPE_OP(code)  ((code & 0xfc000000) >> 26)
#define RTYPE_RS(code)  ((code & 0x03e00000) >> 21)
#define RTYPE_RT(code)  ((code & 0x001f0000) >> 16)
#define RTYPE_RD(code)  ((code & 0x0000f800) >> 11)
#define RTYPE_S(code)   ((code & 0x000007c0) >> 6)
#define RTYPE_FUNC(code)        (code & 0x0000003f)
#define FTYPE_OP(code)  ((code & 0xfc000000) >> 26)
#define FTYPE_FMT(code) ((code & 0x01d00000) >> 21)
#define FTYPE_FR(code)	((code & 0x03e00000) >> 21)
#define FTYPE_FT(code)  ((code & 0x001f0000) >> 16)
#define FTYPE_FS(code)  ((code & 0x0000f800) >> 11)
#define FTYPE_FD(code)  ((code & 0x000007c0) >> 6)
#define FTYPE_FUNC(code)        (code & 0x0000003f)
#define CTYPE_OP(code)  ((code & 0xfc000000) >> 26)
#define CTYPE_CO(code)  ((code & 0x02000000) >> 25)
#define CTYPE_COFUNC(code)      (code & 0x01ffffff)
#define TTYPE_OP(code)  ((code & 0xfc000000) >> 26)
#define TTYPE_CODE(code)        ((code & 0x03ffffc0) >> 6)
#define TTYPE_FUNC(code)        (code & 0x0000003f)

#define COP1B_MIPS4(fmt,tf,code)    ((17 << 26) | (1 << 25) | (fmt << 21) | (tf <<16)|code)
#define COP1BMSK_MIPS4   (COP1TMSK | (0x03 << 6))
#define COP1CMPMSK_MIPS4 (COP1TMSK | (0x03 << 6))

#define COP1B_MIPS4(fmt,tf,code)    ((17 << 26) | (1 << 25) | (fmt << 21) | (tf <<16)|code)
#define COP1BMSK_MIPS4   (COP1TMSK | (0x03 << 6))
#define COP1CMPMSK_MIPS4 (COP1TMSK | (0x03 << 6))

#define MIPS4_RCC(code)	((code & 0x001c0000) >> 18)
#define MIPS4_WCC(code)	((code & 0x00000700) >> 8)

#define MMTYPE(code)		((unsigned long) ((18 << 26) | (code)))
#define MMTYPE_VEC(code)	((unsigned long) ((18 << 26) | \
				 (0xb << 22) | (code)))
#define MMTYPE_IMM(code)	((unsigned long) ((18 << 26) | \
				 (0xf << 22) | (code)))
#define MMTYPE_AC(acc,code)	((unsigned long) ((18 << 26) | \
				 ((acc) << 22) | (code)))

#define MMTYPE_MUL(acc,code)	((unsigned long) ((18 << 26) | \
				 ((acc) << 6) | (code)))
#define MMTYPE_MUL_VEC(acc,code) \
    ((unsigned long) ((18 << 26) | (0xb << 22) | ((acc) << 6) | (code)))
#define MMTYPE_MUL_IMM(acc,code) \
    ((unsigned long) ((18 << 26) | (0xf << 22) | ((acc) << 6) | (code)))

#define MMTYPE_MACM(code)	((unsigned long) (code))
#define MMTYPE_ROR(code)	((unsigned long) (1 << 21) | (code))

#define MMVECMSK		(0xffe0003f)	/* vector-vector */
#define MMIMMMSK		(0xffe0003f)	/* vector-immediate */
#define MMSELMSK		(0xfe20003f)	/* vector-scalar */
#define MMCMSK			(0x1f << 6)	/* used by c.XX.ob */

#define MM1MSK		((unsigned long) ((0x3f << 26) | (0x01 << 21) |(0x3f)))
#define MM2MSK		(MM1MSK | (0x1f << 6))
#define MM3MSK		(MM2MSK | (0xf << 21))
#define MM4MSK		(MM1MSK | (0x7fff << 11))
#define MM5MSK		(MM1MSK | (0x1f << 11))
#define MM6MSK		(MM2MSK | (0x3ff << 16))
#define MMALNIMSK	((unsigned long) ((0xff << 24) | (0x3f)))

#define RORVMSK		((unsigned long) ((0x3f << 26) | (0x1f << 6) | (0x3f)))
#define MACMMSK		((unsigned long) ((0x3f << 26) |(0x7ff)))

#define VTYPE_OP(code)		(((code) & 0xfc000000) >> 26)
#define VTYPE_SEL(code)		(((code) & 0x03c00000) >> 22)
#define VTYPE_ACC(code)		(((code) & 0x03c00000) >> 22)
#define VTYPE_IMM(code)		(((code) & 0x01f00000) >> 21)
#define VTYPE_VT(code)		(((code) & 0x001f0000) >> 16)
#define VTYPE_VS(code)		(((code) & 0x0000f800) >> 11)
#define VTYPE_VD(code)		(((code) & 0x000007c0) >> 6)
#define VTYPE_FUNC(code)	((code) & 0x0000003f)

/* mips16 defines and strings describing operand formats  */

#define I16_OPCODE_MASK     0xf800
#define I16_RTYPE_RX(code)  ((code & 0x0700) >> 8)
#define I16_RTYPE_RY(code)  ((code & 0x00e0) >> 5)
#define I16_RTYPE_RZ(code)  ((code & 0x001c) >> 2)
#define I16_ITYPE_I4(code)  (code & 0xf)
#define I16_ITYPE_I5(code)  (code & 0x1f)
#define I16_ITYPE_I8(code)  (code & 0xff)
#define I16_ITYPE_I11(code) (code & 0x7ff)

#define ITYPE16_1(op,rx,ry,rz,immed) \
	( ((op) << 11) | ((rx) << 8) | ((ry) << 5) | ((rz) << 2) | immed)

#define RMASK16(rx,ry,rz,immed) ITYPE16_1(0x1f,rx,ry,rz,immed)

#define I8TYPE(op,opsub,ry,r32) ( ((op)<<11) | ((opsub)<<8) | ((ry)<<5) | (r32))

#define I8MASK(opsub,ry,r32)    I8TYPE(0xc,opsub,ry,r32)

#define SFTTYPE(op,rx,ry,sm,f) \
	( ((op) << 11) | ((rx) << 8) | ((ry) << 5) | ((sm) << 2) | f)

#define SFTMASK(rx,ry,sm,f) SFTTYPE(0x6,rx,ry,sm,f)

char rx_ry[]      = "rx,ry";
char ra_rx[]      = "ra,rx";
char rr[]         = "rr";
char ry_rx[]      = "ry,rx";
char rx_ry_rz[]   = "rx,ry,rz";
char rz_rx_ry[]   = "rz,rx,ry";
char rx_i8[]      = "rx,i2";
char rx_ry_i5[]   = "rx,ry,i1";
char ry_rx_i4[] = "ry,rx,i0";
char f_i8[]       = "i2";
char rx_ry_sm[] = "rx,ry,im";
char ry_rm[]      = "ry,rm";
char ro_rn[]      = "ro,rn";
char ry_m[]       = "ry,m";

char rx[]       = "rx";
char rx_b[]     = "rx,b";
char i4[]       = "i0";
char i5[]       = "i1";
char i8[]       = "i2";
char ix[]       = "ix";

/* end mips16 */

/* Standard VxWorks tokens */

#define LOCAL static

/* globals */

/* strings describing operand formats */
LOCAL char B[] = "B";		/* break code */
LOCAL char C_m[] = "C,m";	/* Bits20:16,immediate_offset(GPR_base)
				 * Bits 20:16 are "op" for CACHE instruction
				 * and hint for PREF instruction 
   				 */
LOCAL char H[] = "H";           /* Hint field of PREFX instruction */
LOCAL char d[] = "d";		/* "cc" (condition code)field in instructions that read from it */
LOCAL char w[] = "w";		/* "cc" field in instructions that write into it */
LOCAL char m[] = "m";		/* immediate_offset(GPR_base) */
LOCAL char n[] = "n";		/* GPR_index(GPR_base).  rs(rt) */
LOCAL char S[] = "S";		/* syscall */
LOCAL char b[] = "b";		/* 16 bit branch offset */
LOCAL char d_b[]  ="d,b";
LOCAL char w_fs_ft[] = "w,fs,ft";
LOCAL char fd_n[] = "fd,n";
LOCAL char fd_fr_fs_ft[] = "fd,fr,fs,ft";
LOCAL char rd_rs_d[] = "rd,rs,d";
LOCAL char fd_fs_d[] = "fd,fs,d";
LOCAL char fd_fs_rt[] = "fd,fs,rt";
LOCAL char H_n[] = "H,n";
LOCAL char H_m[] = "H,m";
LOCAL char fs_n[] = "fs,n"; 
LOCAL char fd_fs[] = "fd,fs";
LOCAL char fd_fs_ft[] = "fd,fs,ft";
LOCAL char fs_ft[] = "fs,ft";
LOCAL char ft_m[] = "ft,m";
LOCAL char g[] = "g";		
LOCAL char j[] = "j";		/* Absolute Jump */
LOCAL char null[] = "";
LOCAL char rd[] = "rd";
LOCAL char rd_rs[] = "rd,rs";
LOCAL char rd_rs_rt[] = "rd,rs,rt";
LOCAL char rd_rt[] = "rd,rt";
LOCAL char rd_rt_rs[] = "rd,rt,rs";
LOCAL char rd_rt_s[] = "rd,rt,s";
LOCAL char rs[] = "rs";
LOCAL char rs_b[] = "rs,b";
LOCAL char rs_i[] = "rs,i";
LOCAL char rs_rt[] = "rs,rt";
LOCAL char rs_rt_b[] = "rs,rt,b";
LOCAL char rt_P[] = "rt,P";
LOCAL char rt_0[] = "rt,0";
LOCAL char rt_0_sel[] = "rt,0,i0";
LOCAL char rt_1[] = "rt,1";
LOCAL char rt_fs[] = "rt,fs";
LOCAL char rt_fs_sel[] = "rt,fs,i0";
LOCAL char rt_i[] = "rt,i";
LOCAL char rt_m[] = "rt,m";
LOCAL char rt_rs_i[] = "rt,rs,i";
LOCAL char rt_rs_u[] = "rt,rs,u";
LOCAL char rt_u[] = "rt,u";
/* VR5400 Multi-media insn formats */
LOCAL char vd_vs_vt[] = "vd,vs,vt";
LOCAL char vd_vs_vt_sel[] = "vd,vs,vt[ve]";
LOCAL char vd_vs_vt_imm[] = "vd,vs,C";
LOCAL char vd_vs_vt_vi[] = "vd,vs,vt,vi";
LOCAL char vd_C[] = "vd,C";
LOCAL char vs_vt[] = "vs,vt";
LOCAL char vs_vt_sel[] = "vs,vt[ve]";
LOCAL char vs_vt_imm[] = "vs,C";
LOCAL char vd[] = "vd";
LOCAL char vs[] = "vs";
LOCAL char vi[] = "vi";

LOCAL INST itab[] =
    {

    /* R5400 new insns; most have three formats depending on SEL field  */
    {"pickf.ob",	MMTYPE_VEC(2),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"pickt.ob",	MMTYPE_VEC(3),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"min.ob",		MMTYPE_VEC(6),	MMVECMSK, vd_vs_vt, CPU_VR5400}, 
    {"max.ob",		MMTYPE_VEC(7),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"sub.ob",		MMTYPE_VEC(10),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"add.ob",		MMTYPE_VEC(11),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"and.ob",		MMTYPE_VEC(12),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"xor.ob",		MMTYPE_VEC(13),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"or.ob",		MMTYPE_VEC(14),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"nor.ob",		MMTYPE_VEC(15),	MMVECMSK, vd_vs_vt, CPU_VR5400},
    {"mul.ob",		MMTYPE_VEC(48),	MMVECMSK, vd_vs_vt, CPU_VR5400},

    {"pickf.ob",	MMTYPE(2),	MMSELMSK, vd_vs_vt, CPU_VR5400},
    {"pickt.ob",	MMTYPE(3),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"min.ob",		MMTYPE(6),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400}, 
    {"max.ob",		MMTYPE(7),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"sub.ob",		MMTYPE(10),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"add.ob",		MMTYPE(11),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"and.ob",		MMTYPE(12),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"xor.ob",		MMTYPE(13),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"or.ob",		MMTYPE(14),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"nor.ob",		MMTYPE(15),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"sll.ob",		MMTYPE(16),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"srl.ob",		MMTYPE(18),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},
    {"mul.ob",		MMTYPE(48),	MMSELMSK, vd_vs_vt_sel, CPU_VR5400},

    {"pickf.ob",	MMTYPE_IMM(2),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"pickt.ob",	MMTYPE_IMM(3),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"min.ob",		MMTYPE_IMM(6),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400}, 
    {"max.ob",		MMTYPE_IMM(7),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"sub.ob",		MMTYPE_IMM(10),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"add.ob",		MMTYPE_IMM(11),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"and.ob",		MMTYPE_IMM(12),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"xor.ob",		MMTYPE_IMM(13),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"or.ob",		MMTYPE_IMM(14),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"nor.ob",		MMTYPE_IMM(15),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"sll.ob",		MMTYPE_IMM(16),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"srl.ob",		MMTYPE_IMM(18),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},
    {"mul.ob",		MMTYPE_IMM(48),	MMIMMMSK, vd_vs_vt_imm, CPU_VR5400},

    {"c.lt.ob",		MMTYPE_VEC(4),	MMVECMSK|MMCMSK, vs_vt, CPU_VR5400},
    {"c.le.ob",		MMTYPE_VEC(5),	MMVECMSK|MMCMSK, vs_vt, CPU_VR5400},
    {"c.eq.ob",		MMTYPE_VEC(1),	MMVECMSK|MMCMSK, vs_vt, CPU_VR5400},

    {"c.lt.ob",		MMTYPE(4),     MMSELMSK|MMCMSK, vs_vt_sel, CPU_VR5400},
    {"c.le.ob",		MMTYPE(5),     MMSELMSK|MMCMSK, vs_vt_sel, CPU_VR5400},
    {"c.eq.ob",		MMTYPE(1),     MMSELMSK|MMCMSK, vs_vt_sel, CPU_VR5400},

    {"c.lt.ob",		MMTYPE_IMM(4), MMIMMMSK|MMCMSK, vs_vt_imm, CPU_VR5400},
    {"c.le.ob",		MMTYPE_IMM(5), MMIMMMSK|MMCMSK, vs_vt_imm, CPU_VR5400},
    {"c.eq.ob",		MMTYPE_IMM(1), MMIMMMSK|MMCMSK, vs_vt_imm, CPU_VR5400},

    {"muls.ob",		MMTYPE_MUL_VEC(0,50),	MMVECMSK|MMCMSK, vs_vt, 
     CPU_VR5400},
    {"mulsl.ob",	MMTYPE_MUL_VEC(16,50),	MMVECMSK|MMCMSK, vs_vt, 
     CPU_VR5400},
    {"mula.ob",		MMTYPE_MUL_VEC(0,51),	MMVECMSK|MMCMSK, vs_vt, 
     CPU_VR5400},
    {"mull.ob",		MMTYPE_MUL_VEC(16,51),	MMVECMSK|MMCMSK, vs_vt, 
     CPU_VR5400},

    {"muls.ob",		MMTYPE_MUL(0,50),	MMSELMSK|MMCMSK, vs_vt_sel, CPU_VR5400},
    {"mulsl.ob",	MMTYPE_MUL(16,50),	MMSELMSK|MMCMSK, vs_vt_sel, CPU_VR5400},
    {"mula.ob",		MMTYPE_MUL(0,51),	MMSELMSK|MMCMSK, vs_vt_sel, CPU_VR5400},
    {"mull.ob",		MMTYPE_MUL(16,51),	MMSELMSK|MMCMSK, vs_vt_sel, CPU_VR5400},

    {"muls.ob",		MMTYPE_MUL_IMM(0,50),	MMIMMMSK|MMCMSK, vs_vt_imm, CPU_VR5400},
    {"mulsl.ob",	MMTYPE_MUL_IMM(16,50),	MMIMMMSK|MMCMSK, vs_vt_imm, CPU_VR5400},
    {"mula.ob",		MMTYPE_MUL_IMM(0,51),	MMIMMMSK|MMCMSK, vs_vt_imm, CPU_VR5400},
    {"mull.ob",		MMTYPE_MUL_IMM(16,51),	MMIMMMSK|MMCMSK, vs_vt_imm, CPU_VR5400},

    /* remaining multimedia insn's have only one form */
    {"racl.ob",		MMTYPE_AC(0,63),	MM4MSK, vd, CPU_VR5400},
    {"racm.ob",		MMTYPE_AC(4,63),	MM4MSK, vd, CPU_VR5400},
    {"rach.ob",		MMTYPE_AC(8,63),	MM4MSK, vd, CPU_VR5400},

#if 0 /* XXX VR5400 doc - wrong! */
    {"shfl.pach.ob",	MMTYPE_AC(4,31),	MM1MSK, vd_vs_vt, CPU_VR5400},
    {"shfl.pacl.ob",	MMTYPE_AC(5,31),	MM1MSK, vd_vs_vt, CPU_VR5400},
    {"shfl.mixh.ob",	MMTYPE_AC(6,31),	MM1MSK, vd_vs_vt, CPU_VR5400},
    {"shfl.mixl.ob",	MMTYPE_AC(7,31),	MM1MSK, vd_vs_vt, CPU_VR5400},
#else /* cygnus gnu opcode; unique */
    {"shfl.pach.ob",	0x4900001f, 0xffe0003f, vd_vs_vt, CPU_VR5400},
    {"shfl.pacl.ob",	0x4940001f, 0xffe0003f, vd_vs_vt, CPU_VR5400},
    {"shfl.mixh.ob",	0x4980001f, 0xffe0003f, vd_vs_vt, CPU_VR5400},
    {"shfl.mixl.ob",	0x49c0001f, 0xffe0003f, vd_vs_vt, CPU_VR5400},
#endif

    {"rzu.ob",		MMTYPE(32),	MM5MSK, vd_C, CPU_VR5400},

    {"wach.ob",		MMTYPE_AC(8,62),	MM6MSK, vs, CPU_VR5400},
    {"wacl.ob",		MMTYPE_AC(0,62),	MM3MSK, vs_vt, CPU_VR5400},

    {"alni.ob",		MMTYPE(24),	MMALNIMSK, vd_vs_vt_vi, CPU_VR5400},

    {"dbreak",          JTYPE(0x1c,0x3f), IMASK(0,0,0x3f), null,  CPU_VR5400},
    {"dret",            JTYPE(0x1c,0x3e), IMASK(0,0,0x3f), null,  CPU_VR5400},

    /* XXX unique forms...*/
    {"mfpc",            0x4000c801,	0xffe0ffc1, rt_P,  CPU_VR5400},
    {"mfps",            0x4000c800,	0xffe0ffc1, rt_P,  CPU_VR5400},
    {"mtpc",            0x4080c801,	0xffe0ffc1, rt_P,  CPU_VR5400},
    {"mtps",            0x4080c800,	0xffe0ffc1, rt_P,  CPU_VR5400},
    {"mfdr",            0x7000003d,	0xffe007ff, rt_0,  CPU_VR5400},
    {"mtdr",            0x7080003d,	0xffe007ff, rt_0,  CPU_VR5400},

    
    {"macc",		MMTYPE_MACM(344),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"macchi",		MMTYPE_MACM(856),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"macchiu",		MMTYPE_MACM(857),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"maccu",		MMTYPE_MACM(345),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"msac",		MMTYPE_MACM(472),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"msachi",		MMTYPE_MACM(984),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"msachiu",		MMTYPE_MACM(985),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"msacu",		MMTYPE_MACM(473),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"mul",		MMTYPE_MACM(88), 	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"mulhi",		MMTYPE_MACM(600),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"mulhiu",		MMTYPE_MACM(601),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"mulu",		MMTYPE_MACM(89), 	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"muls",		MMTYPE_MACM(216),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"mulshi",		MMTYPE_MACM(728),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"mulshiu",		MMTYPE_MACM(729),	MACMMSK, rd_rs_rt, CPU_VR5400},
    {"mulsu",		MMTYPE_MACM(217),	MACMMSK, rd_rs_rt, CPU_VR5400},

    /* XXX 5400 documents dror & dror32 w/ identical bits; gnu uses: */
    {"dror32",		MMTYPE_ROR(62),		MM1MSK, rd_rt_s, CPU_VR5400},
    {"dror",		MMTYPE_ROR(54),		MM1MSK, rd_rt_s, CPU_VR5400},
    {"dror",		MMTYPE_ROR(62),		MM1MSK, rd_rt_s, CPU_VR5400},
    {"ror",		MMTYPE_ROR(2),	 	MM1MSK, rd_rt_s, CPU_VR5400},

#if 0 /* this is the vr5400 doc version */
    {"drorv",		MMTYPE_ROR(22),		RORVMSK, rd_rt_rs, CPU_VR5400},
    {"rorv",		MMTYPE_ROR(6),	 	RORVMSK, rd_rt_rs, CPU_VR5400},
#else /* the cygnus gnu opcode encoding: JTYPE(0,0x56) */
    {"drorv",		0x00000056, 0xfc0007ff, rd_rt_rs, CPU_VR5400},
    {"rorv",		0x00000046, 0xfc0007ff, rd_rt_rs, CPU_VR5400},
#endif
    /* End R5400 new insns */


    /* Coprocessor 0 operations */
    {"tlbr",	ITYPE(16,0x10,0,0x01), (unsigned long) (~0), null},
    {"tlbwi",	ITYPE(16,0x10,0,0x02), (unsigned long) (~0), null},
    {"tlbwr",	ITYPE(16,0x10,0,0x06), (unsigned long) (~0), null},
    {"tlbp",	ITYPE(16,0x10,0,0x08), (unsigned long) (~0), null},
    {"rfe",	ITYPE(16,0x10,0,0x10), (unsigned long) (~0), null},
    {"eret",	ITYPE(16,0x10,0,0x18), (unsigned long) (~0), null},
    {"dret",	ITYPE(16,0x10,0,0x1f), (unsigned long) (~0), null},
    {"waiti",	ITYPE(16,0x10,0,0x20), (unsigned long) (~0), null, CPU_CW4011},

    /* Coprocessor 1 operations */
    {"add.s",	COP1T(0,0),	COP1TMSK, fd_fs_ft},
    {"add.d",	COP1T(1,0),	COP1TMSK, fd_fs_ft},
    {"add.e",	COP1T(2,0),	COP1TMSK, fd_fs_ft},
    {"add.q",	COP1T(3,0),	COP1TMSK, fd_fs_ft},
    {"add.w",	COP1T(4,0),	COP1TMSK, fd_fs_ft},
    {"add.l",	COP1T(5,0),	COP1TMSK, fd_fs_ft},

    {"sub.s",	COP1T(0,1),	COP1TMSK, fd_fs_ft},
    {"sub.d",	COP1T(1,1),	COP1TMSK, fd_fs_ft},
    {"sub.e",	COP1T(2,1),	COP1TMSK, fd_fs_ft},
    {"sub.q",	COP1T(3,1),	COP1TMSK, fd_fs_ft},
    {"sub.w",	COP1T(4,1),	COP1TMSK, fd_fs_ft},
    {"sub.l",	COP1T(5,1),	COP1TMSK, fd_fs_ft},

    {"mul.s",	COP1T(0,2),	COP1TMSK, fd_fs_ft},
    {"mul.d",	COP1T(1,2),	COP1TMSK, fd_fs_ft},
    {"mul.e",	COP1T(2,2),	COP1TMSK, fd_fs_ft},
    {"mul.q",	COP1T(3,2),	COP1TMSK, fd_fs_ft},
    {"mul.w",	COP1T(4,2),	COP1TMSK, fd_fs_ft},
    {"mul.l",	COP1T(5,2),	COP1TMSK, fd_fs_ft},

    {"div.s",	COP1T(0,3),	COP1TMSK, fd_fs_ft},
    {"div.d",	COP1T(1,3),	COP1TMSK, fd_fs_ft},
    {"div.e",	COP1T(2,3),	COP1TMSK, fd_fs_ft},
    {"div.q",	COP1T(3,3),	COP1TMSK, fd_fs_ft},
    {"div.w",	COP1T(4,3),	COP1TMSK, fd_fs_ft},
    {"div.l",	COP1T(5,3),	COP1TMSK, fd_fs_ft},

    {"sqrt.s",	COP1T(0,4),	COP1BMSK, fd_fs},
    {"sqrt.d",	COP1T(1,4),	COP1BMSK, fd_fs},
    {"sqrt.e",	COP1T(2,4),	COP1BMSK, fd_fs},
    {"sqrt.q",	COP1T(3,4),	COP1BMSK, fd_fs},
    {"sqrt.w",	COP1T(4,4),	COP1BMSK, fd_fs},
    {"sqrt.l",	COP1T(5,4),	COP1BMSK, fd_fs},

    {"abs.s",	COP1B(0,5),	COP1BMSK, fd_fs},
    {"abs.d",	COP1B(1,5),	COP1BMSK, fd_fs},
    {"abs.e",	COP1B(2,5),	COP1BMSK, fd_fs},
    {"abs.q",	COP1B(3,5),	COP1BMSK, fd_fs},
    {"abs.w",	COP1B(4,5),	COP1BMSK, fd_fs},
    {"abs.l",	COP1B(5,5),	COP1BMSK, fd_fs},

    {"mov.s",	COP1B(0,6),	COP1BMSK, fd_fs},
    {"mov.d",	COP1B(1,6),	COP1BMSK, fd_fs},
    {"mov.e",	COP1B(2,6),	COP1BMSK, fd_fs},
    {"mov.q",	COP1B(3,6),	COP1BMSK, fd_fs},

    {"neg.s",	COP1B(0,7),	COP1BMSK, fd_fs},
    {"neg.d",	COP1B(1,7),	COP1BMSK, fd_fs},
    {"neg.e",	COP1B(2,7),	COP1BMSK, fd_fs},
    {"neg.q",	COP1B(3,7),	COP1BMSK, fd_fs},
    {"neg.w",	COP1B(4,7),	COP1BMSK, fd_fs},
    {"neg.l",	COP1B(5,7),	COP1BMSK, fd_fs},

    {"round.l.s",	COP1B(0,8),	COP1BMSK, fd_fs},
    {"round.l.d",	COP1B(1,8),	COP1BMSK, fd_fs},
    {"round.l.e",	COP1B(2,8),	COP1BMSK, fd_fs},
    {"round.l.q",	COP1B(3,8),	COP1BMSK, fd_fs},

    {"trunc.l.s",	COP1B(0,9),	COP1BMSK, fd_fs},
    {"trunc.l.d",	COP1B(1,9),	COP1BMSK, fd_fs},
    {"trunc.l.e",	COP1B(2,9),	COP1BMSK, fd_fs},
    {"trunc.l.q",	COP1B(3,9),	COP1BMSK, fd_fs},

    {"ceil.l.s",	COP1B(0,10),	COP1BMSK, fd_fs},
    {"ceil.l.d",	COP1B(1,10),	COP1BMSK, fd_fs},
    {"ceil.l.e",	COP1B(2,10),	COP1BMSK, fd_fs},
    {"ceil.l.q",	COP1B(3,10),	COP1BMSK, fd_fs},

    {"floor.l.s",	COP1B(0,11),	COP1BMSK, fd_fs},
    {"floor.l.d",	COP1B(1,11),	COP1BMSK, fd_fs},
    {"floor.l.e",	COP1B(2,11),	COP1BMSK, fd_fs},
    {"floor.l.q",	COP1B(3,11),	COP1BMSK, fd_fs},

    {"round.w.s",	COP1B(0,12),	COP1BMSK, fd_fs},
    {"round.w.d",	COP1B(1,12),	COP1BMSK, fd_fs},
    {"round.w.e",	COP1B(2,12),	COP1BMSK, fd_fs},
    {"round.w.q",	COP1B(3,12),	COP1BMSK, fd_fs},

    {"trunc.w.s",	COP1B(0,13),	COP1BMSK, fd_fs},
    {"trunc.w.d",	COP1B(1,13),	COP1BMSK, fd_fs},
    {"trunc.w.e",	COP1B(2,13),	COP1BMSK, fd_fs},
    {"trunc.w.q",	COP1B(3,13),	COP1BMSK, fd_fs},

    {"ceil.w.s",	COP1B(0,14),	COP1BMSK, fd_fs},
    {"ceil.w.d",	COP1B(1,14),	COP1BMSK, fd_fs},
    {"ceil.w.e",	COP1B(2,14),	COP1BMSK, fd_fs},
    {"ceil.w.q",	COP1B(3,14),	COP1BMSK, fd_fs},

    {"floor.w.s",	COP1B(0,15),	COP1BMSK, fd_fs},
    {"floor.w.d",	COP1B(1,15),	COP1BMSK, fd_fs},
    {"floor.w.e",	COP1B(2,15),	COP1BMSK, fd_fs},
    {"floor.w.q",	COP1B(3,15),	COP1BMSK, fd_fs},

    {"movf.s", COP1B_MIPS4(0,0,17), COP1BMSK_MIPS4, fd_fs_d, CPU_MIPS4},
    {"movf.d", COP1B_MIPS4(1,0,17), COP1BMSK_MIPS4, fd_fs_d, CPU_MIPS4},

    {"movt.s", COP1B_MIPS4(0,1,17), COP1BMSK_MIPS4, fd_fs_d, CPU_MIPS4},
    {"movt.d", COP1B_MIPS4(1,1,17), COP1BMSK_MIPS4, fd_fs_d, CPU_MIPS4},

    {"movz.s", COP1B(0,18), COP1BMSK_MIPS4, fd_fs_rt, CPU_MIPS4},
    {"movz.d", COP1B(1,18), COP1BMSK_MIPS4, fd_fs_rt, CPU_MIPS4},


    {"movn.s", COP1B(0,19), COP1TMSK, fd_fs_rt, CPU_MIPS4},
    {"movn.d", COP1B(1,19), COP1TMSK, fd_fs_rt, CPU_MIPS4},

    {"recip.s", COP1B(0,21), COP1BMSK, fd_fs, CPU_MIPS4},
    {"recip.d", COP1B(1,21), COP1BMSK, fd_fs, CPU_MIPS4},

    {"rsqrt.s", COP1B(0,22), COP1BMSK, fd_fs, CPU_MIPS4},
    {"rsqrt.d", COP1B(1,22), COP1BMSK, fd_fs, CPU_MIPS4},

    /*"cvt.s.s",	COP1B(0,32),	COP1BMSK, fd_fs,*/
    {"cvt.s.d",	COP1B(1,32),	COP1BMSK, fd_fs},
    {"cvt.s.e",	COP1B(2,32),	COP1BMSK, fd_fs},
    {"cvt.s.q",	COP1B(3,32),	COP1BMSK, fd_fs},
    {"cvt.s.w",	COP1B(4,32),	COP1BMSK, fd_fs},
    {"cvt.s.l",	COP1B(5,32),	COP1BMSK, fd_fs},

    {"cvt.d.s",	COP1B(0,33),	COP1BMSK, fd_fs},
    /*"cvt.d.d",	COP1B(1,33),	COP1BMSK, fd_fs,*/
    {"cvt.d.e",	COP1B(2,33),	COP1BMSK, fd_fs},
    {"cvt.d.q",	COP1B(3,33),	COP1BMSK, fd_fs},
    {"cvt.d.w",	COP1B(4,33),	COP1BMSK, fd_fs},
    {"cvt.d.l",	COP1B(5,33),	COP1BMSK, fd_fs},

    {"cvt.e.s",	COP1B(0,34),	COP1BMSK, fd_fs},
    {"cvt.e.d",	COP1B(1,34),	COP1BMSK, fd_fs},
    /*"cvt.e.e",	COP1B(2,34),	COP1BMSK, fd_fs,*/
    {"cvt.e.q",	COP1B(3,34),	COP1BMSK, fd_fs},
    {"cvt.e.w",	COP1B(4,34),	COP1BMSK, fd_fs},
    {"cvt.e.l",	COP1B(5,34),	COP1BMSK, fd_fs},

    {"cvt.q.s",	COP1B(0,35),	COP1BMSK, fd_fs},
    {"cvt.q.d",	COP1B(1,35),	COP1BMSK, fd_fs},
    {"cvt.q.e",	COP1B(2,35),	COP1BMSK, fd_fs},
    /*"cvt.q.q",	COP1B(3,35),	COP1BMSK, fd_fs,*/
    {"cvt.q.w",	COP1B(4,35),	COP1BMSK, fd_fs},
    {"cvt.q.l",	COP1B(5,35),	COP1BMSK, fd_fs},

    {"cvt.w.s",	COP1B(0,36),	COP1BMSK, fd_fs},
    {"cvt.w.d",	COP1B(1,36),	COP1BMSK, fd_fs},
    {"cvt.w.e",	COP1B(2,36),	COP1BMSK, fd_fs},
    {"cvt.w.q",	COP1B(3,36),	COP1BMSK, fd_fs},
    /*"cvt.w.w",	COP1B(4,36),	COP1BMSK, fd_fs,*/
    /*"cvt.w.l",	COP1B(5,36),	COP1BMSK, fd_fs,*/

    {"cvt.l.s",	COP1B(0,37),	COP1BMSK, fd_fs},
    {"cvt.l.d",	COP1B(1,37),	COP1BMSK, fd_fs},
    {"cvt.l.e",	COP1B(2,37),	COP1BMSK, fd_fs},
    {"cvt.l.q",	COP1B(3,37),	COP1BMSK, fd_fs},
    /*"cvt.l.w",	COP1B(4,37),	COP1BMSK, fd_fs,*/
    /*"cvt.l.l",	COP1B(5,37),	COP1BMSK, fd_fs,*/


				/* MIPS IV Compare Instructions */

    {"c.f.s",	COP1B(0,48),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.f.s",	COP1B(0,48),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.f.d",	COP1B(1,48),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.f.e",	COP1B(2,48),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.f.q",	COP1B(3,48),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.f.w",	COP1B(4,48),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.f.l",	COP1B(5,48),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.un.s",	COP1B(0,49),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.un.d",	COP1B(1,49),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.un.e",	COP1B(2,49),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.un.q",	COP1B(3,49),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.un.w",	COP1B(4,49),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.un.l",	COP1B(5,49),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.eq.s",	COP1B(0,50),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.eq.d",	COP1B(1,50),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.eq.e",	COP1B(2,50),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.eq.q",	COP1B(3,50),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.eq.w",	COP1B(4,50),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.eq.l",	COP1B(5,50),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.ueq.s", COP1B(0,51),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ueq.d", COP1B(1,51),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ueq.e", COP1B(2,51),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ueq.q", COP1B(3,51),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ueq.w", COP1B(4,51),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ueq.l", COP1B(5,51),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.olt.s",	COP1B(0,52),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.olt.d",	COP1B(1,52),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.olt.e",	COP1B(2,52),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.olt.q",	COP1B(3,52),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.olt.w",	COP1B(4,52),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.olt.l",	COP1B(5,52),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.ult.s",	COP1B(0,53),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ult.d",	COP1B(1,53),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ult.e",	COP1B(2,53),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ult.q",	COP1B(3,53),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ult.w",	COP1B(4,53),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ult.l",	COP1B(5,53),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.ole.s",	COP1B(0,54),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ole.d",	COP1B(1,54),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ole.e",	COP1B(2,54),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ole.q",	COP1B(3,54),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ole.w",	COP1B(4,54),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ole.l",	COP1B(5,54),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.ule.s",	COP1B(0,55),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ule.d",	COP1B(1,55),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ule.e",	COP1B(2,55),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ule.q",	COP1B(3,55),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ule.w",	COP1B(4,55),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ule.l",	COP1B(5,55),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.sf.s",	COP1B(0,56),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.sf.d",	COP1B(1,56),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.sf.e",	COP1B(2,56),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.sf.q",	COP1B(3,56),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.sf.w",	COP1B(4,56),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.sf.l",	COP1B(5,56),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.ngle.s",	COP1B(0,57),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngle.d",	COP1B(1,57),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngle.e",	COP1B(2,57),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngle.q",	COP1B(3,57),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngle.w",	COP1B(4,57),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngle.l",	COP1B(5,57),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.seq.s",	COP1B(0,58),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.seq.d",	COP1B(1,58),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.seq.e",	COP1B(2,58),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.seq.q",	COP1B(3,58),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.seq.w",	COP1B(4,58),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.seq.l",	COP1B(5,58),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.ngl.s",	COP1B(0,59),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngl.d",	COP1B(1,59),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngl.e",	COP1B(2,59),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngl.q",	COP1B(3,59),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngl.w",	COP1B(4,59),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngl.l",	COP1B(5,59),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.lt.s",	COP1B(0,60),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.lt.d",	COP1B(1,60),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.lt.e",	COP1B(2,60),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.lt.q",	COP1B(3,60),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.lt.w",	COP1B(4,60),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.lt.l",	COP1B(5,60),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.nge.s",	COP1B(0,61),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.nge.d",	COP1B(1,61),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.nge.e",	COP1B(2,61),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.nge.q",	COP1B(3,61),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.nge.w",	COP1B(4,61),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.nge.l",	COP1B(5,61),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.le.s",	COP1B(0,62),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.le.d",	COP1B(1,62),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.le.e",	COP1B(2,62),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.le.q",	COP1B(3,62),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.le.w",	COP1B(4,62),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.le.l",	COP1B(5,62),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

    {"c.ngt.s",	COP1B(0,63),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngt.d",	COP1B(1,63),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngt.e",	COP1B(2,63),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngt.q",	COP1B(3,63),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngt.w",	COP1B(4,63),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},
    {"c.ngt.l",	COP1B(5,63),	COP1CMPMSK_MIPS4, w_fs_ft, CPU_MIPS4},

				/* MIPS III Compare Instructions */

    {"c.f.s",	COP1B(0,48),	COP1CMPMSK, fs_ft},
    {"c.f.s",	COP1B(0,48),	COP1CMPMSK, fs_ft},
    {"c.f.d",	COP1B(1,48),	COP1CMPMSK, fs_ft},
    {"c.f.e",	COP1B(2,48),	COP1CMPMSK, fs_ft},
    {"c.f.q",	COP1B(3,48),	COP1CMPMSK, fs_ft},
    {"c.f.w",	COP1B(4,48),	COP1CMPMSK, fs_ft},
    {"c.f.l",	COP1B(5,48),	COP1CMPMSK, fs_ft},

    {"c.un.s",	COP1B(0,49),	COP1CMPMSK, fs_ft},
    {"c.un.d",	COP1B(1,49),	COP1CMPMSK, fs_ft},
    {"c.un.e",	COP1B(2,49),	COP1CMPMSK, fs_ft},
    {"c.un.q",	COP1B(3,49),	COP1CMPMSK, fs_ft},
    {"c.un.w",	COP1B(4,49),	COP1CMPMSK, fs_ft},
    {"c.un.l",	COP1B(5,49),	COP1CMPMSK, fs_ft},

    {"c.eq.s",	COP1B(0,50),	COP1CMPMSK, fs_ft},
    {"c.eq.d",	COP1B(1,50),	COP1CMPMSK, fs_ft},
    {"c.eq.e",	COP1B(2,50),	COP1CMPMSK, fs_ft},
    {"c.eq.q",	COP1B(3,50),	COP1CMPMSK, fs_ft},
    {"c.eq.w",	COP1B(4,50),	COP1CMPMSK, fs_ft},
    {"c.eq.l",	COP1B(5,50),	COP1CMPMSK, fs_ft},

    {"c.ueq.s", COP1B(0,51),	COP1CMPMSK, fs_ft},
    {"c.ueq.d", COP1B(1,51),	COP1CMPMSK, fs_ft},
    {"c.ueq.e", COP1B(2,51),	COP1CMPMSK, fs_ft},
    {"c.ueq.q", COP1B(3,51),	COP1CMPMSK, fs_ft},
    {"c.ueq.w", COP1B(4,51),	COP1CMPMSK, fs_ft},
    {"c.ueq.l", COP1B(5,51),	COP1CMPMSK, fs_ft},

    {"c.olt.s",	COP1B(0,52),	COP1CMPMSK, fs_ft},
    {"c.olt.d",	COP1B(1,52),	COP1CMPMSK, fs_ft},
    {"c.olt.e",	COP1B(2,52),	COP1CMPMSK, fs_ft},
    {"c.olt.q",	COP1B(3,52),	COP1CMPMSK, fs_ft},
    {"c.olt.w",	COP1B(4,52),	COP1CMPMSK, fs_ft},
    {"c.olt.l",	COP1B(5,52),	COP1CMPMSK, fs_ft},

    {"c.ult.s",	COP1B(0,53),	COP1CMPMSK, fs_ft},
    {"c.ult.d",	COP1B(1,53),	COP1CMPMSK, fs_ft},
    {"c.ult.e",	COP1B(2,53),	COP1CMPMSK, fs_ft},
    {"c.ult.q",	COP1B(3,53),	COP1CMPMSK, fs_ft},
    {"c.ult.w",	COP1B(4,53),	COP1CMPMSK, fs_ft},
    {"c.ult.l",	COP1B(5,53),	COP1CMPMSK, fs_ft},

    {"c.ole.s",	COP1B(0,54),	COP1CMPMSK, fs_ft},
    {"c.ole.d",	COP1B(1,54),	COP1CMPMSK, fs_ft},
    {"c.ole.e",	COP1B(2,54),	COP1CMPMSK, fs_ft},
    {"c.ole.q",	COP1B(3,54),	COP1CMPMSK, fs_ft},
    {"c.ole.w",	COP1B(4,54),	COP1CMPMSK, fs_ft},
    {"c.ole.l",	COP1B(5,54),	COP1CMPMSK, fs_ft},

    {"c.ule.s",	COP1B(0,55),	COP1CMPMSK, fs_ft},
    {"c.ule.d",	COP1B(1,55),	COP1CMPMSK, fs_ft},
    {"c.ule.e",	COP1B(2,55),	COP1CMPMSK, fs_ft},
    {"c.ule.q",	COP1B(3,55),	COP1CMPMSK, fs_ft},
    {"c.ule.w",	COP1B(4,55),	COP1CMPMSK, fs_ft},
    {"c.ule.l",	COP1B(5,55),	COP1CMPMSK, fs_ft},

    {"c.sf.s",	COP1B(0,56),	COP1CMPMSK, fs_ft},
    {"c.sf.d",	COP1B(1,56),	COP1CMPMSK, fs_ft},
    {"c.sf.e",	COP1B(2,56),	COP1CMPMSK, fs_ft},
    {"c.sf.q",	COP1B(3,56),	COP1CMPMSK, fs_ft},
    {"c.sf.w",	COP1B(4,56),	COP1CMPMSK, fs_ft},
    {"c.sf.l",	COP1B(5,56),	COP1CMPMSK, fs_ft},

    {"c.ngle.s",	COP1B(0,57),	COP1CMPMSK, fs_ft},
    {"c.ngle.d",	COP1B(1,57),	COP1CMPMSK, fs_ft},
    {"c.ngle.e",	COP1B(2,57),	COP1CMPMSK, fs_ft},
    {"c.ngle.q",	COP1B(3,57),	COP1CMPMSK, fs_ft},
    {"c.ngle.w",	COP1B(4,57),	COP1CMPMSK, fs_ft},
    {"c.ngle.l",	COP1B(5,57),	COP1CMPMSK, fs_ft},

    {"c.seq.s",	COP1B(0,58),	COP1CMPMSK, fs_ft},
    {"c.seq.d",	COP1B(1,58),	COP1CMPMSK, fs_ft},
    {"c.seq.e",	COP1B(2,58),	COP1CMPMSK, fs_ft},
    {"c.seq.q",	COP1B(3,58),	COP1CMPMSK, fs_ft},
    {"c.seq.w",	COP1B(4,58),	COP1CMPMSK, fs_ft},
    {"c.seq.l",	COP1B(5,58),	COP1CMPMSK, fs_ft},

    {"c.ngl.s",	COP1B(0,59),	COP1CMPMSK, fs_ft},
    {"c.ngl.d",	COP1B(1,59),	COP1CMPMSK, fs_ft},
    {"c.ngl.e",	COP1B(2,59),	COP1CMPMSK, fs_ft},
    {"c.ngl.q",	COP1B(3,59),	COP1CMPMSK, fs_ft},
    {"c.ngl.w",	COP1B(4,59),	COP1CMPMSK, fs_ft},
    {"c.ngl.l",	COP1B(5,59),	COP1CMPMSK, fs_ft},

    {"c.lt.s",	COP1B(0,60),	COP1CMPMSK, fs_ft},
    {"c.lt.d",	COP1B(1,60),	COP1CMPMSK, fs_ft},
    {"c.lt.e",	COP1B(2,60),	COP1CMPMSK, fs_ft},
    {"c.lt.q",	COP1B(3,60),	COP1CMPMSK, fs_ft},
    {"c.lt.w",	COP1B(4,60),	COP1CMPMSK, fs_ft},
    {"c.lt.l",	COP1B(5,60),	COP1CMPMSK, fs_ft},

    {"c.nge.s",	COP1B(0,61),	COP1CMPMSK, fs_ft},
    {"c.nge.d",	COP1B(1,61),	COP1CMPMSK, fs_ft},
    {"c.nge.e",	COP1B(2,61),	COP1CMPMSK, fs_ft},
    {"c.nge.q",	COP1B(3,61),	COP1CMPMSK, fs_ft},
    {"c.nge.w",	COP1B(4,61),	COP1CMPMSK, fs_ft},
    {"c.nge.l",	COP1B(5,61),	COP1CMPMSK, fs_ft},

    {"c.le.s",	COP1B(0,62),	COP1CMPMSK, fs_ft},
    {"c.le.d",	COP1B(1,62),	COP1CMPMSK, fs_ft},
    {"c.le.e",	COP1B(2,62),	COP1CMPMSK, fs_ft},
    {"c.le.q",	COP1B(3,62),	COP1CMPMSK, fs_ft},
    {"c.le.w",	COP1B(4,62),	COP1CMPMSK, fs_ft},
    {"c.le.l",	COP1B(5,62),	COP1CMPMSK, fs_ft},

    {"c.ngt.s",	COP1B(0,63),	COP1CMPMSK, fs_ft},
    {"c.ngt.d",	COP1B(1,63),	COP1CMPMSK, fs_ft},
    {"c.ngt.e",	COP1B(2,63),	COP1CMPMSK, fs_ft},
    {"c.ngt.q",	COP1B(3,63),	COP1CMPMSK, fs_ft},
    {"c.ngt.w",	COP1B(4,63),	COP1CMPMSK, fs_ft},
    {"c.ngt.l",	COP1B(5,63),	COP1CMPMSK, fs_ft},

    /* General Purpose RTYPE (Special) */

    {"nop",	RTYPE(0,0,0,0), RMASK(0x1f,0x1f,0x1f,0x7ff), null},
    {"ssnop",	RTYPE(0,0,0,0x40), RMASK(0x1f,0x1f,0x1f,0x7ff), null},
    {"sll",	RTYPE(0,0,0,0), RMASK(0,0,0,0x3f), rd_rt_s},
    {"selsr",	RTYPE(0,0,0,1), RMASK(0,0,0,0x7ff), rd_rs_rt, CPU_CW4011},
    {"movf",    RTYPE(0,0,0,1), RMASK(0,0x3,0,0x7ff), rd_rs_d, CPU_MIPS4},
    {"reserved",RTYPE(0,0,0,1), RMASK(0,0,0,0x3f), null},
    {"srl",	RTYPE(0,0,0,2), RMASK(0x1f,0,0,0x3f), rd_rt_s},
    {"sra",	RTYPE(0,0,0,3), RMASK(0x1f,0,0,0x3f), rd_rt_s},
    {"sllv",	RTYPE(0,0,0,4), RMASK(0,0,0,0x7ff), rd_rt_rs},
    {"selsl",	RTYPE(0,0,0,5), RMASK(0,0,0,0x7ff), rd_rs_rt, CPU_CW4011},
    {"reserved",RTYPE(0,0,0,5), RMASK(0,0,0,0x3f), null},
    {"srlv",	RTYPE(0,0,0,6), RMASK(0,0,0,0x7ff), rd_rt_rs},
    {"srav",	RTYPE(0,0,0,7), RMASK(0,0,0,0x7ff), rd_rt_rs},
    {"jr",	RTYPE(0,0,0,8), RMASK(0,0x1f,0x1f,0x7ff), rs},
    {"jalr",	RTYPE(0,0,0x1f,9), RMASK(0,0x1f,0x1f,0x7ff), rs},
    {"jalr",	RTYPE(0,0,0,9), RMASK(0,0x1f,0,0x7ff), rd_rs},
    {"ffs",	RTYPE(0,0,0,10), RMASK(0,0x1f,0,0x7ff), rd_rs, CPU_CW4011},
    {"movz",    RTYPE(0,0,0,10), RMASK(0,0,0,0x7ff), rd_rs_rt, CPU_MIPS4}, 
    {"reserved",RTYPE(0,0,0,10), RMASK(0,0,0,0x3f), null},
    {"ffc",	RTYPE(0,0,0,11), RMASK(0,0x1f,0,0x7ff), rd_rs, CPU_CW4011},
    {"movn",	RTYPE(0,0,0,11), RMASK(0,0,0,0x7ff), rd_rs_rt, CPU_MIPS4},    
    {"reserved",RTYPE(0,0,0,11), RMASK(0,0,0,0x3f), null},
    {"syscall",	RTYPE(0,0,0,12), RMASK(0,0,0,0x3f), S},
    {"break",	RTYPE(0,0,0,13), RMASK(0,0,0,0x3f), B},
    {"sdbbp",	RTYPE(0,0,0,14), RMASK(0,0,0,0x3f), null},
    {"sync",	RTYPE(0,0,0,15), RMASK(0x1f,0x1f,0x1f,0x7ff), null},
    {"mfhi",	RTYPE(0,0,0,16), RMASK(0x1f,0x1f,0,0x7ff), rd},
    {"mthi",	RTYPE(0,0,0,17), RMASK(0,0x1f,0x1f,0x7ff), rs},
    {"mflo",	RTYPE(0,0,0,18), RMASK(0x1f,0x1f,0,0x7ff), rd},
    {"mtlo",	RTYPE(0,0,0,19), RMASK(0,0x1f,0x1f,0x7ff), rs},
    {"dsllv",	RTYPE(0,0,0,20), RMASK(0,0,0,0x7ff), rd_rt_rs},
    {"reserved",	RTYPE(0,0,0,21), RMASK(0,0,0,0x3f), null},
    {"dsrlv",	RTYPE(0,0,0,22), RMASK(0,0,0,0x7ff), rd_rt_rs},
    {"dsrav",	RTYPE(0,0,0,23), RMASK(0,0,0,0x7ff), rd_rt_rs},
    {"mult",	RTYPE(0,0,0,24), RMASK(0,0,0x1f,0x7ff), rs_rt},
    {"multu",	RTYPE(0,0,0,25), RMASK(0,0,0x1f,0x7ff), rs_rt},
    {"div",	RTYPE(0,0,0,26), RMASK(0,0,0x1f,0x7ff), rs_rt},
    {"divu",	RTYPE(0,0,0,27), RMASK(0,0,0x1f,0x7ff), rs_rt},
    {"madd",	RTYPE(0,0,0,28), RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_CW4011},
    {"dmult",	RTYPE(0,0,0,28), RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_MIPS3},
    {"reserved",RTYPE(0,0,0,28), RMASK(0,0,0,0x3f), null},
    {"maddu",	RTYPE(0,0,0,29), RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_CW4011},
    {"dmultu",	RTYPE(0,0,0,29), RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_MIPS3},
    {"reserved",RTYPE(0,0,0,29), RMASK(0,0,0,0x3f), null},
    {"msub",	RTYPE(0,0,0,30), RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_CW4011},
    {"ddiv",	RTYPE(0,0,0,30), RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_MIPS3},
    {"reserved",RTYPE(0,0,0,30), RMASK(0,0,0,0x3f), null},
    {"msubu",	RTYPE(0,0,0,31), RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_CW4011},
    {"ddivu",	RTYPE(0,0,0,31), RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_MIPS3},
    {"reserved",RTYPE(0,0,0,31), RMASK(0,0,0,0x3f), null},
    {"add",	RTYPE(0,0,0,32), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"move",	RTYPE(0,0,0,33), RMASK(0,0x1f,0,0x7ff), rd_rs},
    {"move",	RTYPE(0,0,0,33), RMASK(0x1f,0,0,0x7ff), rd_rt},
    {"addu",	RTYPE(0,0,0,33), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"neg",	RTYPE(0,0,0,34), RMASK(0x1f,0,0,0x7ff), rd_rt},
    {"sub",	RTYPE(0,0,0,34), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"negu",	RTYPE(0,0,0,35), RMASK(0x1f,0,0,0x7ff), rd_rt},
    {"subu",	RTYPE(0,0,0,35), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"and",	RTYPE(0,0,0,36), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"move",	RTYPE(0,0,0,37), RMASK(0,0x1f,0,0x7ff), rd_rs},
    {"move",	RTYPE(0,0,0,37), RMASK(0x1f,0,0,0x7ff), rd_rt},
    {"or",	RTYPE(0,0,0,37), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"xor",	RTYPE(0,0,0,38), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"not",	RTYPE(0,0,0,39), RMASK(0,0x1f,0,0x7ff), rd_rs},
    {"nor",	RTYPE(0,0,0,39), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"min",	RTYPE(0,0,0,40), RMASK(0,0,0,0x7ff), rd_rs_rt, CPU_CW4011},
    {"max",	RTYPE(0,0,0,41), RMASK(0,0,0,0x7ff), rd_rs_rt, CPU_CW4011},
    {"reserved",RTYPE(0,0,0,40), RMASK(0,0,0,0x3f), null},
    {"reserved",RTYPE(0,0,0,41), RMASK(0,0,0,0x3f), null},
    {"slt",	RTYPE(0,0,0,42), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"sltu",	RTYPE(0,0,0,43), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"dadd",	RTYPE(0,0,0,44), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"dmove",	RTYPE(0,0,0,45), RMASK(0,0x1f,0,0x7ff), rd_rs},
    {"daddu",	RTYPE(0,0,0,45), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"dneg",	RTYPE(0,0,0,46), RMASK(0x1f,0,0,0x7ff), rd_rt},
    {"dsub",	RTYPE(0,0,0,46), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"dnegu",	RTYPE(0,0,0,47), RMASK(0x1f,0,0,0x7ff), rd_rt},
    {"dsubu",	RTYPE(0,0,0,47), RMASK(0,0,0,0x7ff), rd_rs_rt},
    {"tge",	RTYPE(0,0,0,48), RMASK(0,0,0,0x3f), rs_rt},
    {"tgeu",	RTYPE(0,0,0,49), RMASK(0,0,0,0x3f), rs_rt},
    {"tlt",	RTYPE(0,0,0,50), RMASK(0,0,0,0x3f), rs_rt},
    {"tltu",	RTYPE(0,0,0,51), RMASK(0,0,0,0x3f), rs_rt},
    {"teq",	RTYPE(0,0,0,52), RMASK(0,0,0,0x3f), rs_rt},
    {"reserved",	RTYPE(0,0,0,53), RMASK(0,0,0,0x3f), null},
    {"tne",	RTYPE(0,0,0,54), RMASK(0,0,0,0x3f), rs_rt},
    {"reserved",	RTYPE(0,0,0,55), RMASK(0,0,0,0x3f), null},
    {"dsll",	RTYPE(0,0,0,56), RMASK(0x1f,0,0,0x3f), rd_rt_s},
    {"reserved",	RTYPE(0,0,0,57), RMASK(0,0,0,0x3f), null},
    {"dsrl",	RTYPE(0,0,0,58), RMASK(0x1f,0,0,0x3f), rd_rt_s},
    {"dsra",	RTYPE(0,0,0,59), RMASK(0x1f,0,0,0x3f), rd_rt_s},
    {"dsll32",	RTYPE(0,0,0,60), RMASK(0x1f,0,0,0x3f), rd_rt_s},
    {"reserved",	RTYPE(0,0,0,61), RMASK(0,0,0,0x3f), null},
    {"dsrl32",	RTYPE(0,0,0,62), RMASK(0x1f,0,0,0x3f), rd_rt_s},
    {"dsra32",	RTYPE(0,0,0,63), RMASK(0x1f,0,0,0x3f), rd_rt_s},

    {"movt",    RTYPE(0,1,0,1), RMASK(0,0x3,0,0x7ff), rd_rs_d, CPU_MIPS4},

    /* bcond branches  */
    {"bltz",	ITYPE(1,0,0,0),	IMASK(0,0x1f,0), rs_b},
    {"bgez",	ITYPE(1,0,1,0),	IMASK(0,0x1f,0), rs_b},
    {"bltzl",	ITYPE(1,0,2,0),	IMASK(0,0x1f,0), rs_b},
    {"bgezl",	ITYPE(1,0,3,0),	IMASK(0,0x1f,0), rs_b},
    {"reserved", ITYPE(1,0,4,0),	IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,5,0),	IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,6,0),	IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,7,0),	IMASK(0,0x1f,0), null},
    {"tgei",	ITYPE(1,0,8,0),	IMASK(0,0x1f,0), rs_i},
    {"tgeiu",	ITYPE(1,0,9,0),	IMASK(0,0x1f,0), rs_i},
    {"tlti",	ITYPE(1,0,10,0),IMASK(0,0x1f,0), rs_i},
    {"tltiu",	ITYPE(1,0,11,0),IMASK(0,0x1f,0), rs_i},
    {"teqi",	ITYPE(1,0,12,0),IMASK(0,0x1f,0), rs_i},
    {"reserved", ITYPE(1,0,13,0),IMASK(0,0x1f,0), null},
    {"tnei",	ITYPE(1,0,14,0),IMASK(0,0x1f,0), rs_i},
    {"reserved", ITYPE(1,0,15,0),IMASK(0,0x1f,0), null},
    {"bltzal",	ITYPE(1,0,16,0),IMASK(0,0x1f,0), rs_b},
    {"bal",	ITYPE(1,0,17,0),IMASK(0x1f,0x1f,0), b},
    {"bgezal",	ITYPE(1,0,17,0),IMASK(0,0x1f,0), rs_b},
    {"bltzall",	ITYPE(1,0,18,0),IMASK(0,0x1f,0), rs_b},
    {"bgezall",	ITYPE(1,0,19,0),IMASK(0,0x1f,0), rs_b},
    {"reserved", ITYPE(1,0,20,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,21,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,22,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,23,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,24,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,25,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,26,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,27,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,28,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,29,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,30,0),IMASK(0,0x1f,0), null},
    {"reserved", ITYPE(1,0,31,0),IMASK(0,0x1f,0), null},

    /* jumps */
    {"j",	JTYPE(2,0), JTYPE(0x3f,0), j},
    {"jal",	JTYPE(3,0), JTYPE(0x3f,0), j},

    /* branches */
    {"b",	ITYPE(4,0,0,0), IMASK(0x1f,0x1f,0), b},
    {"beqz",	ITYPE(4,0,0,0),	IMASK(0,0x1f,0), rs_b},
    {"beq",	ITYPE(4,0,0,0),	IMASK(0,0,0), rs_rt_b},
    {"bnez",	ITYPE(5,0,0,0),	IMASK(0,0x1f,0), rs_b},
    {"bne",	ITYPE(5,0,0,0),	IMASK(0,0,0), rs_rt_b},
    {"blez",	ITYPE(6,0,0,0),	IMASK(0,0x1f,0), rs_b},
    {"bgtz",	ITYPE(7,0,0,0),	IMASK(0,0x1f,0), rs_b},

    /* computational (immediate) */
    {"addi",	ITYPE(8,0,0,0),	IMASK(0,0,0),  rt_rs_i},
    {"li",	ITYPE(9,0,0,0), IMASK(0x1f,0,0), rt_i},
    {"addiu",	ITYPE(9,0,0,0),	IMASK(0,0,0),  rt_rs_i},
    {"slti",	ITYPE(10,0,0,0), IMASK(0,0,0), rt_rs_i},
    {"sltiu",	ITYPE(11,0,0,0), IMASK(0,0,0), rt_rs_i},
    {"andi",	ITYPE(12,0,0,0), IMASK(0,0,0), rt_rs_u},
    {"liu",	ITYPE(13,0,0,0), IMASK(0x1f,0,0), rt_u},
    {"ori",	ITYPE(13,0,0,0), IMASK(0,0,0), rt_rs_u},
    {"xori",	ITYPE(14,0,0,0), IMASK(0,0,0), rt_rs_u},
    {"lui",	ITYPE(15,0,0,0), IMASK(0,0,0), rt_u},

    /* coprocessor func */
    {"mfc0",	ITYPE(16,0,0,0), IMASK(0x1f,0,0x7ff), rt_0},
    {"mfc0",	ITYPE(16,0,0,0), IMASK(0x1f,0,0x7f8), rt_0_sel},
    {"dmfc0",	ITYPE(16,1,0,0), IMASK(0x1f,0,0x7ff), rt_0},
    {"dmfc0",	ITYPE(16,1,0,0), IMASK(0x1f,0,0x7f8), rt_0_sel},
    {"mtc0",	ITYPE(16,4,0,0), IMASK(0x1f,0,0x7ff), rt_0},
    {"mtc0",	ITYPE(16,4,0,0), IMASK(0x1f,0,0x7f8), rt_0_sel},
    {"dmtc0",	ITYPE(16,5,0,0), IMASK(0x1f,0,0x7ff), rt_0},
    {"dmtc0",	ITYPE(16,5,0,0), IMASK(0x1f,0,0x7f8), rt_0_sel},
    {"bc0f",	ITYPE(16,8,0,0), IMASK(0x1f,0x1f,0), b},
    {"bc0t",	ITYPE(16,8,1,0), IMASK(0x1f,0x1f,0), b},
    {"bc0fl",	ITYPE(16,8,2,0), IMASK(0x1f,0x1f,0), b},
    {"bc0tl",	ITYPE(16,8,3,0), IMASK(0x1f,0x1f,0), b},
    {"reserved",	ITYPE(16,0,0,0), IMASK(0x10,0x0,0), null},
    {"c0",	ITYPE(16,0x10,0,0), IMASK(0x10,0,0), g},

    {"mfc1",	ITYPE(17,0,0,0), IMASK(0x1f,0,0x7ff), rt_fs},
    {"mfc1",	ITYPE(17,0,0,0), IMASK(0x1f,0,0x7f8), rt_fs_sel},
    {"dmfc1",	ITYPE(17,1,0,0), IMASK(0x1f,0,0x7ff), rt_fs},
    {"dmfc1",	ITYPE(17,1,0,0), IMASK(0x1f,0,0x7f8), rt_fs_sel},
    {"cfc1",	ITYPE(17,2,0,0), IMASK(0x1f,0,0x7ff), rt_1},
    {"mtc1",	ITYPE(17,4,0,0), IMASK(0x1f,0,0x7ff), rt_fs},
    {"mtc1",	ITYPE(17,4,0,0), IMASK(0x1f,0,0x7f8), rt_fs_sel},
    {"dmtc1",	ITYPE(17,5,0,0), IMASK(0x1f,0,0x7ff), rt_fs},
    {"dmtc1",	ITYPE(17,5,0,0), IMASK(0x1f,0,0x7f8), rt_fs_sel},
    {"ctc1",	ITYPE(17,6,0,0), IMASK(0x1f,0,0x7ff), rt_1},
    {"bc1f",	ITYPE(17,8,0,0), IMASK(0x1f,0x03,0), d_b, CPU_MIPS4},
    {"bc1f",	ITYPE(17,8,0,0), IMASK(0x1f,0x1f,0),  b},
    {"bc1t",	ITYPE(17,8,1,0), IMASK(0x1f,0x03,0), d_b, CPU_MIPS4},
    {"bc1t",	ITYPE(17,8,1,0), IMASK(0x1f,0x1f,0),  b},
    {"bc1fl",	ITYPE(17,8,2,0), IMASK(0x1f,0x03,0), d_b, CPU_MIPS4},
    {"bc1fl",	ITYPE(17,8,2,0), IMASK(0x1f,0x1f,0),  b},
    {"bc1tl",	ITYPE(17,8,3,0), IMASK(0x1f,0x03,0), d_b, CPU_MIPS4},
    {"bc1tl",	ITYPE(17,8,3,0), IMASK(0x1f,0x1f,0),  b},
    {"reserved",	ITYPE(17,0,0,0), IMASK(0x10,0x0,0), null},
    {"c1",	ITYPE(17,0x10,0,0), IMASK(0x10,0,0), g},

    {"mfc2",	ITYPE(18,0,0,0), IMASK(0x1f,0,0x7ff), rt_fs},
    {"mfc2",	ITYPE(18,0,0,0), IMASK(0x1f,0,0x7f8), rt_fs_sel},
    {"dmfc2",	ITYPE(18,1,0,0), IMASK(0x1f,0,0x7ff), rt_fs},
    {"dmfc2",	ITYPE(18,1,0,0), IMASK(0x1f,0,0x7f8), rt_fs_sel},
    {"cfc2",	ITYPE(18,2,0,0), IMASK(0x1f,0,0x7ff), rt_1},
    {"mtc2",	ITYPE(18,4,0,0), IMASK(0x1f,0,0x7ff), rt_fs},
    {"mtc2",	ITYPE(18,4,0,0), IMASK(0x1f,0,0x7f8), rt_fs_sel},
    {"dmtc2",	ITYPE(18,5,0,0), IMASK(0x1f,0,0x7ff), rt_fs},
    {"dmtc2",	ITYPE(18,5,0,0), IMASK(0x1f,0,0x7f8), rt_fs_sel},
    {"ctc2",	ITYPE(18,6,0,0), IMASK(0x1f,0,0x7ff), rt_1},
    {"bc2f",	ITYPE(18,8,0,0), IMASK(0x1f,0x1f,0),  b},
    {"bc2t",	ITYPE(18,8,1,0), IMASK(0x1f,0x1f,0),  b},
    {"bc2fl",	ITYPE(18,8,2,0), IMASK(0x1f,0x1f,0),  b},
    {"bc2tl",	ITYPE(18,8,3,0), IMASK(0x1f,0x1f,0),  b},
    {"reserved",ITYPE(18,0,0,0), IMASK(0x10,0x0,0), null},
    {"c2",	ITYPE(18,0x10,0,0), IMASK(0x10,0,0), g},
    {"ldxc1",	ITYPE(19,0,0,1), IMASK(0,0,0xf83f), fd_n, CPU_MIPS4 },
    {"lwxc1",	ITYPE(19,0,0,0), IMASK(0,0,0xf83f), fd_n, CPU_MIPS4 },
    {"sdxc1",	ITYPE(19,0,0,9), IMASK(0,0,0x7ff), fs_n, CPU_MIPS4 },
    {"swxc1",	ITYPE(19,0,0,8), IMASK(0,0,0x7ff), fs_n, CPU_MIPS4 },
    {"prefx",	ITYPE(19,0,0,15), IMASK(0,0,0x7ff), H_n, CPU_MIPS4 },
    {"madd.s",	ITYPE(19,0,0,32), IMASK(0,0,0x3f), fd_fr_fs_ft, CPU_MIPS4 },
    {"madd.d",	ITYPE(19,0,0,33), IMASK(0,0,0x3f), fd_fr_fs_ft, CPU_MIPS4 },
    {"msub.s",  ITYPE(19,0,0,40), IMASK(0,0,0x3f), fd_fr_fs_ft, CPU_MIPS4},
    {"msub.d",  ITYPE(19,0,0,41), IMASK(0,0,0x3f), fd_fr_fs_ft, CPU_MIPS4},
    {"nmadd.s", ITYPE(19,0,0,48), IMASK(0,0,0x3f), fd_fr_fs_ft, CPU_MIPS4},
    {"nmadd.d", ITYPE(19,0,0,49), IMASK(0,0,0x3f), fd_fr_fs_ft, CPU_MIPS4},
    {"nmsub.s", ITYPE(19,0,0,56), IMASK(0,0,0x3f), fd_fr_fs_ft, CPU_MIPS4},
    {"nmsub.d", ITYPE(19,0,0,57), IMASK(0,0,0x3f), fd_fr_fs_ft, CPU_MIPS4},
    {"reserved",ITYPE(19,0,0,0), IMASK(0,0,0), null},
    {"beqzl",	ITYPE(20,0,0,0),IMASK(0,0x1f,0), rs_b},
    {"beql",	ITYPE(20,0,0,0),IMASK(0,0,0), rs_rt_b},
    {"bnezl",	ITYPE(21,0,0,0),IMASK(0,0x1f,0), rs_b},
    {"bnel",	ITYPE(21,0,0,0),IMASK(0,0,0), rs_rt_b},
    {"blezl",	ITYPE(22,0,0,0),IMASK(0,0x1f,0), rs_b},
    {"bgtzl",	ITYPE(23,0,0,0),IMASK(0,0x1f,0), rs_b},
    {"daddi",	ITYPE(24,0,0,0),IMASK(0,0,0),  rt_rs_i},
    {"daddiu",	ITYPE(25,0,0,0),IMASK(0,0,0),  rt_rs_i},

    {"ldl",	ITYPE(26,0,0,0),IMASK(0,0,0),  rt_m},
    {"ldr",	ITYPE(27,0,0,0),IMASK(0,0,0),  rt_m},
    {"madd",	MTYPE(28,0,0,0,0),RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_R4650},
    {"madd",	MTYPE(28,0,0,0,0),RMASK(0,0,0,0x7ff), rd_rs_rt, CPU_R4650},
    {"madd",	MTYPE(28,0,0,0,1),RMASK(0,0,0x1f,0x7ff), rs_rt, CPU_R4650},
    {"maddu",	MTYPE(28,0,0,0,1),RMASK(0,0,0,0x7ff), rd_rs_rt, CPU_R4650},
    {"addciu",	ITYPE(28,0,0,0),IMASK(0,0,0),  rt_rs_i, CPU_CW4011},
    {"reserved",	ITYPE(29,0,0,0),IMASK(0,0,0),  null},
    {"reserved",	ITYPE(30,0,0,0),IMASK(0,0,0),  null},
    {"reserved",	ITYPE(31,0,0,0),IMASK(0,0,0),  null},

    /* loads */
    {"lb",	ITYPE(32,0,0,0), IMASK(0,0,0), rt_m},
    {"lh",	ITYPE(33,0,0,0), IMASK(0,0,0), rt_m},
    {"lwl",	ITYPE(34,0,0,0), IMASK(0,0,0), rt_m},
    {"lw",	ITYPE(35,0,0,0), IMASK(0,0,0), rt_m},
    {"lbu",	ITYPE(36,0,0,0), IMASK(0,0,0), rt_m},
    {"lhu",	ITYPE(37,0,0,0), IMASK(0,0,0), rt_m},
    {"lwr",	ITYPE(38,0,0,0), IMASK(0,0,0), rt_m},
    {"lwu",	ITYPE(39,0,0,0), IMASK(0,0,0), rt_m},

    /* stores */
    {"sb",	ITYPE(40,0,0,0), IMASK(0,0,0), rt_m},
    {"sh",	ITYPE(41,0,0,0), IMASK(0,0,0), rt_m},
    {"swl",	ITYPE(42,0,0,0), IMASK(0,0,0), rt_m},
    {"sw",	ITYPE(43,0,0,0), IMASK(0,0,0), rt_m},
    {"sdl",	ITYPE(44,0,0,0), IMASK(0,0,0), rt_m},
    {"sdr",	ITYPE(45,0,0,0), IMASK(0,0,0), rt_m},
    {"swr",	ITYPE(46,0,0,0), IMASK(0,0,0), rt_m},

    /* cache */
    {"flushi",	ITYPE(47,0,1,0), IMASK(0x1f,0x1f,0xffff), null, CPU_CW4011},
    {"flushd",	ITYPE(47,0,2,0), IMASK(0x1f,0x1f,0xffff), null, CPU_CW4011},
    {"flushid",	ITYPE(47,0,3,0), IMASK(0x1f,0x1f,0xffff), null, CPU_CW4011},
    {"wb",	ITYPE(47,0,4,0), IMASK(0,0x1f,0), m, CPU_CW4011},
    {"cache",	ITYPE(47,0,0,0), IMASK(0,0,0), C_m},

    /* coprocessor load */
    {"ll",	ITYPE(48,0,0,0), IMASK(0,0,0), rt_m},
    {"lwc1",	ITYPE(49,0,0,0), IMASK(0,0,0), ft_m},
    {"lwc2",	ITYPE(50,0,0,0), IMASK(0,0,0), rt_m},
    {"pref",	ITYPE(51,0,0,0), IMASK(0,0,0), C_m, CPU_MIPS4},

    {"lld",	ITYPE(52,0,0,0), IMASK(0,0,0), rt_m},
    {"ldc1",	ITYPE(53,0,0,0), IMASK(0,0,0), ft_m},
    {"ldc2",	ITYPE(54,0,0,0), IMASK(0,0,0), rt_m},
    {"ld",	ITYPE(55,0,0,0), IMASK(0,0,0), rt_m},

    /* coproc store */
    {"sc",	ITYPE(56,0,0,0), IMASK(0,0,0), rt_m},
    {"swc1",	ITYPE(57,0,0,0), IMASK(0,0,0), ft_m},
    {"swc2",	ITYPE(58,0,0,0), IMASK(0,0,0), rt_m},
    {"reserved",ITYPE(59,0,0,0), IMASK(0,0,0), null},

    {"scd",	ITYPE(60,0,0,0), IMASK(0,0,0), rt_m},
    {"sdc1",	ITYPE(61,0,0,0), IMASK(0,0,0), ft_m},
    {"sdc2",	ITYPE(62,0,0,0), IMASK(0,0,0), rt_m},
    {"sd",	ITYPE(63,0,0,0), IMASK(0,0,0), rt_m},

    {NULL, 0, 0, NULL}
    };

/* mips16 itab table
 * Some of the array elements are not used by instruction decoding
 * function dsmPrint. They are handled directly in the function.
 */


LOCAL INST itab16[] =
    {
    /* General Purpose RTYPE (Special) */

    {"addiusp", ITYPE16_1(0x0,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"addiupc", ITYPE16_1(0x1,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"b",       ITYPE16_1(0x2,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), b},
    {"beqz",    ITYPE16_1(0x4,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_b},
    {"bnez",    ITYPE16_1(0x5,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_b},
    {"addiu8",  ITYPE16_1(0x9,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"slti",    ITYPE16_1(0xa,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"sltiu",   ITYPE16_1(0xb,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"li",      ITYPE16_1(0xd,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"cmpi",    ITYPE16_1(0xe,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"lb",      ITYPE16_1(0x10,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ry_m},
    {"lh",      ITYPE16_1(0x11,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ry_m},
    {"lwsp",    ITYPE16_1(0x12,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"lw",      ITYPE16_1(0x13,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ry_m},
    {"lbu",     ITYPE16_1(0x14,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ry_m},
    {"lhu",     ITYPE16_1(0x15,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ry_m},
    {"lwpc",    ITYPE16_1(0x16,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"sb",      ITYPE16_1(0x18,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ry_m},
    {"sh",      ITYPE16_1(0x19,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ry_m},
    {"swsp",    ITYPE16_1(0x1a,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), rx_i8},
    {"sw",      ITYPE16_1(0x1b,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ry_m},
    {"extend",  ITYPE16_1(0x1e,0,0,0,0), RMASK16(0x0,0x0,0x0,0x0), ix},

    /* RR type */

    {"jalr", ITYPE16_1(0x1d,0,2,0,0x0), RMASK16(0x0,0x7,0,0x1f), ra_rx},
    {"jr",   ITYPE16_1(0x1d,0,0,0,0x0), RMASK16(0x0,0x0,0,0x1f), rr},
    {"slt",  ITYPE16_1(0x1d,0,0,0,0x2), RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"sltu", ITYPE16_1(0x1d,0,0,0,0x3), RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"sllv", ITYPE16_1(0x1d,0,0,0,0x4), RMASK16(0x0,0x0,0,0x1f), ry_rx},
    {"break",ITYPE16_1(0x1d,0,0,0,0x5), RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"srlv", ITYPE16_1(0x1d,0,0,0,0x6), RMASK16(0x0,0x0,0,0x1f), ry_rx},
    {"srav", ITYPE16_1(0x1d,0,0,0,0x7), RMASK16(0x0,0x0,0,0x1f), ry_rx},
    {"cmp",  ITYPE16_1(0x1d,0,0,0,0xa), RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"neg",  ITYPE16_1(0x1d,0,0,0,0xb), RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"and",  ITYPE16_1(0x1d,0,0,0,0xc), RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"or",   ITYPE16_1(0x1d,0,0,0,0xd), RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"xor",  ITYPE16_1(0x1d,0,0,0,0xe), RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"not",  ITYPE16_1(0x1d,0,0,0,0xf), RMASK16(0x0,0x0,0,0x1f), rx_ry},

    /* RR type for multiply and divide instructions */
    {"mfhi", ITYPE16_1(0x1d,0,0,0,0x10),RMASK16(0x0,0x0,0,0x1f), rx},
    {"mflo", ITYPE16_1(0x1d,0,0,0,0x12),RMASK16(0x0,0x0,0,0x1f), rx},
    {"mult", ITYPE16_1(0x1d,0,0,0,0x18),RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"multu",ITYPE16_1(0x1d,0,0,0,0x19),RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"div",  ITYPE16_1(0x1d,0,0,0,0x1a),RMASK16(0x0,0x0,0,0x1f), rx_ry},
    {"divu", ITYPE16_1(0x1d,0,0,0,0x1b),RMASK16(0x0,0x0,0,0x1f), rx_ry},

    /* RRR type */

    {"addu", ITYPE16_1(0x1c,0,0,0,0x1), RMASK16(0x0,0x0,0,0x3), rz_rx_ry},
    {"subu", ITYPE16_1(0x1c,0,0,0,0x3), RMASK16(0x0,0x0,0,0x3), rz_rx_ry},

    /* RRI-A */

    {"addiu",0x4000,0xf800,ry_rx_i4},

    /*  I8-Type instruction */

    {"bteqz",I8TYPE(0xc,0,0,0), I8MASK(0x7,0,0),b},
    {"btnez",I8TYPE(0xc,1,0,0), I8MASK(0x7,0,0),b},
    {"swrasp",I8TYPE(0xc,2,0,0), I8MASK(0x7,0,0),f_i8},
    {"adjsp",I8TYPE(0xc,3,0,0), I8MASK(0x7,0,0),f_i8},
    {"move",I8TYPE(0xc,5,0,0), I8MASK(0x7,0,0),ro_rn},
    {"move",I8TYPE(0xc,7,0,0), I8MASK(0x7,0,0),ry_rm},

    /* jal and jalx */
    {"jal", 0x1800,0xfc00,j},
    {"jalx",0x1c00,0xfc00,j},


    /* shift instruction */

    {"sll",     SFTTYPE(0x6,0,0,0,0), SFTMASK(0,0,0,0x3),rx_ry_sm},
    {"srl",     SFTTYPE(0x6,0,0,0,2), SFTMASK(0,0,0,0x3),rx_ry_sm},
    {"sra",     SFTTYPE(0x6,0,0,0,3), SFTMASK(0,0,0,0x3),rx_ry_sm},

    /* must follow the 5400 insn's */
    {"reserved",	ITYPE(18,0,0,0), IMASK(0x10,0x0,0), null},
    {"reserved",	ITYPE(28,0,0,0),IMASK(0,0,0),  null},
    {"c2",	ITYPE(18,0x10,0,0), IMASK(0x10,0,0), g},
    {NULL, 0, 0, NULL}
    };

/* forward declarations */

LOCAL char *regName (int regNumber, BOOL);
LOCAL char *regCP0Name (int regNumber);
LOCAL char *regCP1Name (int regNumber);
LOCAL char *regCP2Name (int regNumber);

#ifdef HOST
LOCAL void dsmPrint
    (
    int		endian,		/* endianness of data in buffer              */
    ULONG *	binInst,	/* pointer to instruction                    */
    INST *	iPtr,		/* pointer to inst as returned by dsmFind()  */
    TGT_ADDR_T	address, 	/* address with which to prepend instruction */
    int		nwords,		/* length of instruction, in words           */
    VOIDFUNCPTR	prtAddress,	/* printing function address                 */
    char *	pString,	/* string to write result in                 */
    BOOL32	appendAddr,	/* TRUE appends insts' addresses             */
    BOOL32	appendOpcodes,	/* TRUE appends insts' opcodes               */
    int         symType
    );

LOCAL void nPrtAddress (TGT_ADDR_T address, char * pString);

LOCAL int hostByteOrder (void);

LOCAL ULONG getCpuMask (void);
#endif

/******************************************************************************
*
* regName - Converts register number to register name (pointer to string).
*/

LOCAL char *regName
    (
    int regNumber,     /* numerical register representation */
    BOOL mips16Mode    /* mips16 instruction format, TRUE or FALSE */
    )
    {
    static char *registerName [] =
	{
	"zero", "at", "v0", "v1",
	"a0", "a1", "a2", "a3",
	"t0", "t1", "t2", "t3",
	"t4", "t5", "t6", "t7",
	"s0", "s1", "s2", "s3",
	"s4", "s5", "s6", "s7",
	"t8", "t9", "k0", "k1",
	"gp", "sp", "s8", "ra"
	};

    static char * mode16RegName [] = {"s0","s1","v0","v1","a0","a1","a2","a3"};

    if (mips16Mode == TRUE)
        {
        if (regNumber < (int) NELEMENTS(mode16RegName))
            return (mode16RegName[regNumber]);
        else
            return ("");
        }
    else
        {
        if (regNumber < (int) NELEMENTS(registerName))
            return (registerName[regNumber]);
        else
	    return ("");
        }
    }

/******************************************************************************
*
* regCP0Name - Converts register number to coprocessor 0 register name
* 	(pointer to string).
*/

LOCAL char *regCP0Name
    (
    int regNumber
    )
    {
    static char *registerName [] =
	{
	"tlbindex", "tlbrandom", "tlblo0", "tlblo1",
	"tlbcontext", "tlbpagemask", "wired", "$7",
	"badvaddr", "count", "tlbhigh", "compare",
	"sr", "cause", "epc", "prid",
	"config", "lladdr", "watchlo", "watchhi",
	"$20", "$21", "$22", "$23",
	"$24", "$25", "ecc", "cacheerr",
	"taglo", "taghi", "errpc", "$31"
	};

    if (regNumber < (int) NELEMENTS(registerName))
    	return (registerName[regNumber]);
    else
	return ("unknown");
    }

/******************************************************************************
*
* regCP1Name - Converts register number to coprocessor 1 register name
* 	(pointer to string).
*/

LOCAL char *regCP1Name
    (
    int regNumber
    )
    {
    static char *registerName [] =
	{
	"feir", "$1", "$2", "$3",
	"$4", "$5", "$6", "$7",
	"$8", "$9", "$10", "$11",
	"$12", "$13", "$14", "$15",
	"$16", "$17", "$18", "$19",
	"$20", "$21", "$22", "$23",
	"$24", "$25", "$26", "$27",
	"$28", "$29", "$30", "fsr"
	};

    if (regNumber < (int) NELEMENTS(registerName))
    	return (registerName[regNumber]);
    else
	return ("unknown");
    }

/******************************************************************************
*
* regCP2Name - Converts register number to coprocessor 2 register name 
* 	(pointer to string).
*/

LOCAL char *regCP2Name
    (
    int regNumber 
    )
    {
    static char *registerName [] = 
	{
	"$0", "$1", "$2", "$3", 
	"$4", "$5", "$6", "$7",
	"$8", "$9", "$10", "$11", 
	"$12", "$13", "$14", "$15",
	"$16", "$17", "$18", "$19",
	"$20", "$21", "$22", "$23",
	"$24", "$25", "$26", "$27",
	"$28", "$29", "$30", "$31"
	};

    if (regNumber < (int)(NELEMENTS(registerName)))
    	return (registerName[regNumber]);
    else 
	return ("unknown");
    }

#ifdef HOST
/******************************************************************************
*
* hostByteOrder - compute host byte order
*
* NOMANUAL
*/

LOCAL int hostByteOrder (void)
    {
    static int endian = -1;		/* the result is cached */

    if (endian == -1)			/* haven't figured it out yet? */
	{
	union
	    {
	    unsigned long l;
	    char c [4];
	    } u;

	u.l = 0x12345678;

	endian = u.c [0] == 0x78 ? LITTLE_ENDIAN : BIG_ENDIAN;
	}

    return endian;
    }

/*******************************************************************************
*
* dsmFind - disassemble one instruction
*
* This routine figures out which instruction is pointed to by binInst,
* and returns a pointer to the INST which describes it.  If no INST is
* found, returns NULL.
*
*/

LOCAL INST *dsmFind
    (
    int endian,			/* endianness of data in buffer */
    ULONG *binInst,
    ULONG cpumask,
    BOOL mips16Mode    /* the type of the instruction's preceding symbol */
    )
    {
    unsigned long inst;
    INST *iPtr;
    int swap;

    swap = (hostByteOrder () != endian);
    if (mips16Mode)  /* mips16 */
        {
        inst = *(unsigned short *)binInst;
        SWAB_16_IF (swap,inst);

        iPtr = itab16;
        }
    else
        {
        inst = *binInst;
        SWAB_32_IF (swap, inst);

        iPtr = itab;
        }

    /* Find out which instruction it is */
    for (; iPtr->name; iPtr++)
	{
	if (((iPtr->mask & inst) == iPtr->op) &&  /* inst match? */
	    (!iPtr->cpumask || /* inst not cpu-specific? */
	     (iPtr->cpumask & cpumask)))  /* inst is valid for this cpu? */
            return (iPtr);
	}
    return (NULL);
}

/*******************************************************************************
*
* dsmPrint - print a disassembled instruction
*
* This routine prints an instruction in disassembled form.  It takes
* as input a pointer to the instruction, a pointer to the INST
* that describes it (as found by dsmFind), and an address with which to
* prepend the instruction. If <appendAddr> is set to TRUE, the first member of
* the returned string is the address at which code happends. If <appendOpcodes>
* is set to TRUE, opcodes are also joined (after addresses) in the returned
* string.
*
* This function prints the address, raw instruction, opcode
* mnemonic and operands.
*
*/

LOCAL void dsmPrint
    (
    int		endian,		/* endianness of data in buffer              */
    ULONG *	binInst,	/* Pointer to instruction                    */
    INST *	iPtr,		/* Pointer to INST returned by dsmFind       */
    TGT_ADDR_T	address,	/* Address with which to prepend instructin  */
    int		nwords,		/* Instruction length, in words              */
    VOIDFUNCPTR	prtAddress,	/* Address printing function                 */
    char *	pString,	/* where to write disassembled inst          */
    BOOL32	appendAddr,	/* TRUE appends insts' addresses             */
    BOOL32	appendOpcodes,	/* TRUE appends insts' opcodes               */
    BOOL        mips16Mode      /* mips16 instruction format, TRUE or FALSE */
    )
    {
    mipsInst	inst;
    char *	s;
    char 	c;
    int		regno;				/* register number           */
    int		swap;				/* have to swap data or not  */
    char *	outBuf;				/* output formated string    */
    char        buf[BUF_MAX_SIZE];		/* buffer to format strings  */
    UINT32      xtnd = 0;
    UINT32      offset = 0;

    outBuf = (char *) calloc (sizeof (char), MAX_LINE_LEN);

    outBuf[0] = 0;

    regno = 0;

    swap = (hostByteOrder () != endian);

    if (mips16Mode)
        {
        inst = *(unsigned short *)binInst;
        SWAB_16_IF (swap, inst);

        /* jal(x) is a 2*16bit instruction */

        if (M16_INSTR_OPCODE(inst) == M16_JALNX_INSTR)
            {
            UINT16 temp16;
            temp16 = *(((UINT16 *)binInst) + 1);
            SWAB_16_IF (swap, temp16);
            inst = (inst << 16) | temp16;
            }
        else if (M16_INSTR_OPCODE(inst) == M16_EXTEND_INSTR)
            {
            /* extend instruction is also 2*16bit long*/

            xtnd = inst;
            inst = *(((UINT16 *)binInst) + 1);
            SWAB_16_IF (swap,inst);

            /* find the real instruction being extended */

            iPtr = dsmFind (endian, binInst, getCpuMask(), TRUE);
            }
        }
    else  /* if (mips16Mode), expect to be 4 bytes */
        {
        inst = *binInst;
        SWAB_32_IF (swap, inst);
        }

    /* Print the address and the instruction, in hex */

    strcat (outBuf, "{");
    if (appendAddr)
	{
        sprintf (buf, "%08x", (unsigned int) address);
        strcat (outBuf, buf);   /* 1st element */
	}
    strcat (outBuf, "} {");

    if (appendOpcodes)
	{
        if (mips16Mode &&
            (!(M16_INSTR_OPCODE(*(UINT16 *)binInst) == M16_JALNX_INSTR ||
               M16_INSTR_OPCODE(*(UINT16 *)binInst) == M16_EXTEND_INSTR)) )

            sprintf (buf, "%04x", (unsigned)inst);
        else
            sprintf (buf, "%08x", (unsigned)((xtnd << 16) | inst) );
        strcat (outBuf, buf);
	}
    strcat (outBuf, "} {");

    if (iPtr == NULL)
	{
        strcat (outBuf, "XXX.word   "); /* 3rd element */
	sprintf (buf, "%-8s\t%#08x}", "DC.W", (unsigned)inst);
        strcat (outBuf, buf);        /* 4th element */

	strcpy (pString, outBuf);
	free (outBuf);

	return;
	}

    /* deal with some special instructions in mips16 */

    if (mips16Mode && (M16_INSTR_OPCODE(*(UINT16 *)binInst) != M16_JALNX_INSTR))
	{
        BOOL specialInstr = TRUE;

        /* if previous instruction is EXTEND, extract the 11 bit operand
         * and form the whole offset accordingly
         */

        if (xtnd)
            {
            offset = M16_EXTEND_IMM(xtnd) | (inst & 0x1f);
            SIGN_EXTEND_32BIT(offset);
            }
        else
            offset = (I16_ITYPE_I8(inst)) << 2;

        if ( M16_INSTR_OPCODE(inst) == M16_ADDIUSP_INSTR )
            {
            sprintf (buf,"%-8s\t%s, sp,%d","addiu",
                     regName (I16_RTYPE_RX(inst),TRUE), offset);
            }
        else if ( M16_INSTR_OPCODE(inst) == M16_ADDIUPC_INSTR)
            {
            sprintf (buf,"%-8s\t%s, pc,0x%x","addiu",
                     regName (I16_RTYPE_RX(inst),TRUE), offset);
            }
        else if ( M16_INSTR_OPCODE(inst) == M16_ADDIU8_INSTR)
            {
	    if (!xtnd)
                offset = (I16_ITYPE_I8(inst));

            sprintf (buf,"%-8s\t%s, 0x%x","addiu",
                     regName (I16_RTYPE_RX(inst),TRUE), offset);
            }
        else if ( M16_INSTR_OPCODE(inst) == M16_LWSP_INSTR)
            {
            sprintf (buf,"%-8s\t%s, %d(sp)","lw",
                     regName (I16_RTYPE_RX(inst),TRUE),offset);
            }
        else if ( M16_INSTR_OPCODE(inst) == M16_LWPC_INSTR)
            {
            sprintf (buf,"%-8s\t%s, %d(pc)","lw",
                     regName (I16_RTYPE_RX(inst),TRUE),offset);
            }
        else if ( M16_INSTR_OPCODE(inst) == M16_SWSP_INSTR)
            {
            sprintf (buf,"%-8s\t%s, %d(sp)","sw",
                     regName (I16_RTYPE_RX(inst),TRUE),offset);
            }
        else if ( (inst & 0xff00) == 0x6200)          /* swrasp */
            {
            sprintf (buf,"%-8s\t%s, %d(sp)","sw","ra",offset);
            }
        else if ( (inst & 0xff00) == 0x6300)         /* adjsp */
            {
            /* this is a bit unique, immediate needs to be shifted left 3 and
             * sign extended to 32 bit if previous instruction is not EXTEND.
             */
            if (!xtnd)
                offset = (int)((I16_ITYPE_I8(inst)) << 24) >> 21;

            sprintf (buf,"%-8s\t%s, %d","addiu","sp",offset);
            }
        else
            specialInstr = FALSE;

        if (specialInstr == TRUE)
            {
            strcat (outBuf, buf);
            strcat (outBuf, "}");
            strcpy (pString, outBuf);
            free (outBuf);
            return;
            }
        } /* end if (mips16Mode) */

    /* Print the instruction mnemonic and the arguments */

    sprintf (buf, "%-8s\t", iPtr->name);
    strcat (outBuf, buf);   /* 3rd element */

    for ((s = (iPtr->operands)); (c = (*s)); s++)
	{
	/* couple of cases modify outBuf directly; mark buf as empty */

	buf[0] = '\0';
        switch (c)
	    {
            case ',':
            case '[':
            case ']':
	        sprintf (buf, "%c", c);
		break;
	    case 'r':		/* gp register */
                {
                BOOL regName32bit = TRUE;

                switch (*++s)
                    {
                    case 's': regno = RTYPE_RS(inst); break;
                    case 't': regno = RTYPE_RT(inst); break;
                    case 'd': regno = RTYPE_RD(inst); break;

                    /*  mips16 */
                    case 'a':
			regno = 31;
			break;

                    case 'r':
			if (I16_RTYPE_RY(inst) == 0)
			    {
			    regno = I16_RTYPE_RX(inst);
			    regName32bit = FALSE;
			    }
                        else
			    regno = 31;
                        break;

                    case 'x':
                        regno = I16_RTYPE_RX(inst);
                        regName32bit = FALSE;
                        break;

                    case 'y':
                        regno = I16_RTYPE_RY(inst);
                        regName32bit = FALSE;
                        break;

                    case 'z':
                        regno = I16_RTYPE_RZ(inst);
                        regName32bit = FALSE;
                        break;

                    /* mips16 movr32 and mov32r */

                    case 'm':
                        regno = inst & 0x1f;
                        break;
                    case 'n':
                        regno = ((inst & 0xe0) >> 5) | (inst & 0x18);
                        break;
                    case 'o':
                        regno = inst & 0x7;
                        regName32bit = FALSE;
                        break;
                    }
                sprintf (buf, "%s", regName (regno,(!regName32bit)));
                }
		break;
	    case 'f':		/* fp register */
		switch (*++s)
		    {
		    case 's': regno = FTYPE_FS(inst); break;
		    case 't': regno = FTYPE_FT(inst); break;
		    case 'd': regno = FTYPE_FD(inst); break;
		    case 'r': regno = FTYPE_FR(inst); break; 	
		    }
		sprintf (buf, "$f%d", regno);
		break;
	    case 'i':		/* 16bit int */
                /* modify for mips16 */

                if ( (*(s+1) == ',') || (*(s+1) == 0))
                    sprintf (buf, "%ld", (long int)(ITYPE_I(inst)));
                else
                    {
                    int immed = 0;

                    /* if previous instruction is EXTEND, extract the
                     * operand and form the entire immediate for current
                     * instruction.
                     */

                    switch (*++s)
                        {
                        case '0': 
			    immed = inst & 0xf;   
			    if (xtnd)
				{
				immed |= (M16_EXTEND_IMM(xtnd)) >> 1;

				/* sign extend to 32 bit */

				if (immed & 0x4000)
				    immed |= 0xffff8000;
                                }
			    break;

                        case '1': 
			    immed = inst & 0x1f;   
			    if (xtnd)
				{
				immed &= 0x1f;
				immed |= M16_EXTEND_IMM(xtnd);
				SIGN_EXTEND_32BIT(immed);
				}
			    break;

                        case '2': 
			    immed = inst & 0xff;   
			    if (xtnd)
				{
				immed &= 0x1f;
				immed |= M16_EXTEND_IMM(xtnd);
				}
			    break;


                        /* shamt (16 bit mode shift inst) */
                        case 'm':
                            immed = (inst >> 2) & 0x7;

			    if (xtnd)
				immed = (xtnd >> 6) & 0x1f;
                            break;
                        }
                    sprintf (buf, "0x%x", immed);
                    }
		break;
	    case 'u':		/* 16bit unsigned */
	    	sprintf (buf, "%#x", UTYPE_U(inst));
	    	break;
	    case 'b':		/* 16bit bra offset */
                if (mips16Mode)
                    {
                    /* for mips16, the b, beqz and bnez has different size of
                     * offset. Also to consider whether the previous
                     * instruction is EXTEND.
                     */

                    if (xtnd)
                        {
                        offset = M16_EXTEND_IMM(xtnd) | (inst & 0x1f);
                        SIGN_EXTEND_32BIT(offset);

                        /* shift left 1 and adjust 2 for base address */

                        offset = (offset << 1) + 2;
                        }

                    if (M16_INSTR_OPCODE(inst) == M16_B_INSTR)
                        {
                        if (!xtnd)
                            offset = ((int)(inst << 21)) >> 20;
                        }

                    else /* beqz,bnez,bteqz and btnez */

                    /* next address + offset << 1  and sign-extended 32bit*/
                        {
                        if (!xtnd)
                            offset = ((int)(inst << 24)) >> 23;
                        }

                    (*prtAddress)(address + 2 + offset,outBuf);
                    }
                else /* if (mips16Mode) */

		    (*prtAddress) (address + (ITYPE_I(inst) << 2) + 4, outBuf);
		break;
	    case 'j':		/* absolute jump  */
                if (mips16Mode)
                    inst = ((inst & 0x3e00000) >> 5) |
                            ((inst & 0x1f0000) << 5) |
                            (inst & 0xffff);

		(*prtAddress) ((address & 0xf0000000) |
			        (JTYPE_TARGET(inst) << 2),
			       outBuf);
		break;
	    case 's':		/* shift amount */
		sprintf (buf, "%d", RTYPE_S(inst));
		break;
	    case 'g':
		sprintf (buf, "0x%x", CTYPE_COFUNC(inst));
		break;
	    case 'B':		/* break code */
		sprintf (buf, "%#x(%#x)", TTYPE_CODE(inst)>>10,
			 TTYPE_CODE(inst));
		break;
	    case 'S':		/* syscall code */
		sprintf (buf, "%#x", TTYPE_CODE(inst));
		break;
	    case '0':
		sprintf (buf, "%s", regCP0Name (RTYPE_RD(inst)));
		break;
	    case '1':
		sprintf (buf, "%s", regCP1Name (RTYPE_RD(inst)));
		break;
	    case 'C':
		sprintf (buf, "%d", RTYPE_RT(inst));
		break;
	    case 'm':
	      if (mips16Mode)  /* mips16 */
		{
		  if (xtnd)
		    {
		      offset = M16_EXTEND_IMM(xtnd) | (inst & 0x1f);
		      SIGN_EXTEND_32BIT(offset);
		    }
		  if (M16_INSTR_OPCODE(inst) == M16_LB_INSTR ||
		      M16_INSTR_OPCODE(inst) == M16_SB_INSTR ||
		      M16_INSTR_OPCODE(inst) == M16_LBU_INSTR)
		    {
		      if (!xtnd)
			offset = I16_ITYPE_I5(inst);
		    }
		  else if (M16_INSTR_OPCODE(inst) == M16_LH_INSTR ||
			   M16_INSTR_OPCODE(inst) == M16_SH_INSTR ||
			   M16_INSTR_OPCODE(inst) == M16_LHU_INSTR)
		    {
		      if (!xtnd)
			offset = (I16_ITYPE_I5(inst)) << 1;
		    }
		  else
		    {
		      if (!xtnd)
			offset = (I16_ITYPE_I5(inst)) << 2;
		    }
		  sprintf (buf, "%d(%s)", offset,
			   regName (I16_RTYPE_RX(inst),TRUE));
		}
	      else
		sprintf (buf, "%ld(%s)", ITYPE_I(inst),
			 regName (ITYPE_RS(inst),FALSE));
	      break;
	    case 'd':
		sprintf (buf, "%d", MIPS4_RCC(inst));
		break;
	    case 'w':
		sprintf (buf, "%d", MIPS4_WCC(inst));
		break;
	    case 'n':
		sprintf (buf, "%s(%s)", regName(RTYPE_RT(inst), FALSE),
			 regName(RTYPE_RS(inst), FALSE));
		break;
	    case 'H':
		sprintf (buf, "%d", RTYPE_RD(inst));
		break;
	    case 'P':
		sprintf (buf, "%d", (inst >> 1) & 0x1f);
		break;
	    case 'v':		/* mm register */
		switch (*++s)
		    {
		    case 't': 
			sprintf (buf, "$f%d", VTYPE_VT(inst));
			break;

		    case 's': 
			sprintf (buf, "$f%d", VTYPE_VS(inst));
			break;

		    case 'd': 
			sprintf (buf, "$f%d", VTYPE_VD(inst));
			break;

		    case 'e':
			sprintf (buf, "%d", VTYPE_SEL(inst));
			break;

		    case 'i':
			sprintf (buf, "%d", VTYPE_IMM(inst));
			break;
		    }
		break;
	    default:
		sprintf (buf, "%c", c);
		break;
	    }
	if ( buf[0] != '\0' )
	    strcat (outBuf, buf);
	}

    strcat (outBuf, "}");
    strcpy (pString, outBuf);
    free (outBuf);
    }

/*******************************************************************************
*
* nPrtAddress - A dumb routine to print addresses as numbers.
*/

LOCAL void nPrtAddress
    (
    TGT_ADDR_T	address,
    char *	pString			/* string to write in                */
    )
    {
    char        buf [BUF_MAX_SIZE];	/* buffer to format strings          */

    sprintf (buf, "%#x", (unsigned int) address);
    strcat (pString, buf);
    }

/******************************************************************************
*
* getCpuMask - A routine which maps the target CPU id to a mask which can 
* be used as a disassembly aid.
*/

LOCAL ULONG getCpuMask (void)
    {
    int cpu;

    /* XXX There is no info available to set the cpu var! */
#if 0
    cpu = VR5400;
    switch (cpu)
	{
	case R4000:
	    return (CPU_R4000);
	case R4650:
	    return (CPU_R4650);
	case CW4000:
	    return (CPU_CW4000);
	case CW4011:
	    return (CPU_CW4011);
	case VR4100:
	    return (CPU_VR4100);
	case VR5000:
	    return (CPU_VR5000);
	case VR5400:
	    return (CPU_VR5400);
	}
#endif
    return (~0);
    }

/*******************************************************************************
*
* dsmMipsInstGet - disassemble and print a single instruction
*
* This routine is called to disassemble and print (on standard out) a
* single instruction.  The function passed as parameter prtAddress will
* be used to print any operands which might be construed as addresses.
* This could be either a simple routine that just prints a number,
* or one that looks up the address in a symbol table.
* The disassembled instruction will be prepended with the address
* passed as a parameter. The booleans printAddr and printOpcodes specify if
* the instruction address and the opcodes are to be append to the output string.
*
* If prtAddress == 0, a default routine will be used that prints
* addresses as hex numbers.
*
* RETURNS : The number of 32-bit words occupied by the instruction.
*/

int dsmMipsInstGet
    (
    ULONG *	binInst,	  	/* Pointer to the instruction        */
    int		endian,			/* endian of data in buffer          */
    TGT_ADDR_T	address,		/* Address prepended to instruction  */
    VOIDFUNCPTR	prtAddress, 		/* Address printing function         */
    char *	pString,		/* string to write in                */
    BOOL32	printAddr,		/* if adresses are to be appended    */
    BOOL32	printOpcodes,		/* if opcodes are to be appended     */
    int         symType			/* the instruction's preceding symbol type */
    )
    {
    INST *	iPtr;
    int		size = 1; 		/* words in MIPS, always */
    BOOL        mips16Mode = FALSE;

#if 0
    if (symType & SYM_MIPS16)
	mips16Mode = TRUE;
#endif

    if (prtAddress == NULL)
	prtAddress = nPrtAddress;

    iPtr = dsmFind (endian, binInst, getCpuMask(), mips16Mode);
    dsmPrint (endian, binInst, iPtr, address, size, prtAddress, pString,
	      printAddr, printOpcodes, mips16Mode);
    return (size);
    }

/*******************************************************************************
*
* dsmMipsInstSizeGet - find out how big an instruction is
*
* This routine tells how big an instruction is, in bytes.
*
* RETURNS:
*    size of instruction, or
*    0 if instruction is unrecognized
*/

int dsmMipsInstSizeGet
    (
    ULONG *binInst, 		/* Pointer to the instruction */
    int endian,
    int symType    /* the instruction's preceding symbol type */
    )
    {
    int      instSize = sizeof(INSTR);

#if 0
    /* If mips16 function, the instruction size is 2 bytes except jal(x) and
     * extend. Otherwise it is the sizeof(INSTR).
     */
    if (symType & SYM_MIPS16)
	{
	int swap;
        ULONG inst;

	swap = (hostByteOrder () != endian);
	inst = *(UINT16 *)binInst;
	SWAB_16_IF (swap, inst);

        /* jal(x) or extend instructions are 4 bytes */

        if ( !( (M16_INSTR_OPCODE(*(UINT16 *)binInst) == M16_JALNX_INSTR) ||
                (M16_INSTR_OPCODE(*(UINT16 *)binInst) == M16_EXTEND_INSTR) ) )
            instSize = 2;
        else
            instSize = 4;
        }
#endif
    return (instSize);
    }

#else	/* HOST */

/* forward declarations */

LOCAL void dsmPrint (ULONG binInst, FAST INST *iPtr, int address, 
		     int nwords, FUNCPTR prtAddress, int symType);
LOCAL void nPrtAddress (int address );

/* global functions */

int dsmNbytes (ULONG);

BOOL mips16Instructions (ULONG);

/* externals */

extern FUNCPTR _func_symFindByValue;

/*******************************************************************************
*
* dsmFind - disassemble one instruction
*
* This routine figures out which instruction is pointed to by binInst,
* and returns a pointer to the INST which describes it.  If no INST is
* found, returns NULL.
* 
*/

LOCAL INST *dsmFind
    (
     ULONG binInst,
     int   mips16Mode
    )
    {
    FAST unsigned long inst;
    INST *iPtr;

    /* check instruction size */

    if (mips16Mode)  /* mips16 */
	{
	/* make sure aligned at 2 byte boundary */

	binInst &= ~0x1;

        inst = *(unsigned short *)binInst;
	iPtr = itab16;
	}
    else
	{
	/* make sure aligned at 4 byte boundary */

	binInst &= ~0x3;

        inst = *(ULONG *)binInst;
        iPtr = itab;
	}

    /* Find out which instruction it is */
    for (; iPtr->name; iPtr++)
	{
	if ((iPtr->mask & inst) == iPtr->op &&
	    (!iPtr->cpumask || /* inst not cpu-specific? */
	     (iPtr->cpumask & CPUMASK)))  /* inst is valid for this cpu? */
            return (iPtr);
	}
    errnoSet (S_dsmLib_UNKNOWN_INSTRUCTION);
    return (NULL);
}

/*******************************************************************************
*
* dsmPrint - print a disassembled instruction
*
* This routine prints an instruction in disassembled form.  It takes
* as input a pointer to the instruction, a pointer to the INST
* that describes it (as found by dsmFind), and an address with which to
* prepend the instruction.
*
* This function prints the address, raw instruction, opcode
* mnemonic and operands.
*
*/

LOCAL void dsmPrint
    (
    ULONG binInst,		/* Pointer to instruction */
    FAST INST *iPtr,		/* Pointer to INST returned by dsmFind */
    int address,		/* Address with which to prepend instructin */
    int nwords,			/* Instruction length, in words */
    FUNCPTR prtAddress, 	/* Address printing function */
    int     mips16Mode          /* mips16 instruction format, TRUE or FALSE */
    )
    {
    mipsInst	inst;
    FAST char *	s;
    char 	c;
    int		regno = -1;
    int         xtnd   = 0;
    int         offset = 0;

    /* Print the address and the instruction, in hex */

    printf ("%#06x  ", address);

    if (mips16Mode) 
        {
	/* make sure adress is aligned at 2 byte boundary */

	binInst &= ~0x1;

	inst.code = *(unsigned short *)binInst;

	/* jal(x) is a 2*16bit instruction */

        if (M16_INSTR_OPCODE(inst.code) == M16_JALNX_INSTR)
            {
            inst.code = (inst.code << 16) | (*(((UINT16 *)binInst) + 1));

            printf ("%08x    ", inst.code);
            }
        else if (M16_INSTR_OPCODE(inst.code) == M16_EXTEND_INSTR)
	    {
	    /* extend instruction is also 2*16bit long*/

	    xtnd = inst.code;
	    inst.code = *(((UINT16 *)binInst) + 1);
	    printf("%08x    ", (xtnd << 16) | inst.code);

	    /* find the real instruction being extended */

	    iPtr = dsmFind (binInst+2,TRUE);
	    }
        else
            {
            printf ("%04x        ", inst.code);
            }
        }
    else  /* if (mips16Mode) */
        {
	/* non mips16 mode, expect to be 32 bit */

	/* make sure aligned at 4 bytes */

	binInst &= ~0x3;

        inst.code = *(ULONG *)binInst;
        printf ("%08x    ", inst.code);
        }

    /* check if there is a valid instruction */


    if (iPtr == NULL)
	{
	printf ("%-8s\t%#08x\n", "DC.W", *(int *)binInst);
	return;
	}

    /* deal with some special instructions in mips16 */

    if (mips16Mode && (M16_INSTR_OPCODE(*(UINT16 *)binInst) != M16_JALNX_INSTR))
        {
        BOOL specialInstr = TRUE;

	/* if previous instruction is EXTEND, extract the 11 bit operand
	 * and form the whole offset accordingly
	 */

	if (xtnd)
	    {
            offset = M16_EXTEND_IMM(xtnd) | (inst.code & 0x1f);
            SIGN_EXTEND_32BIT(offset);
            }
        else
	    offset = (I16_ITYPE_I8(inst.code)) << 2;

        if ( M16_INSTR_OPCODE(inst.code) == M16_ADDIUSP_INSTR ) 
            {
            printf ("%-8s\t%s, sp,%d\n","addiu",
                     regName (I16_RTYPE_RX(inst.code),TRUE), offset);
            }
        else if ( M16_INSTR_OPCODE(inst.code) == M16_ADDIUPC_INSTR) 
            {
            printf ("%-8s\t%s, pc,0x%x\n","addiu",
                     regName (I16_RTYPE_RX(inst.code),TRUE), offset);
            }
        else if ( M16_INSTR_OPCODE(inst.code) == M16_ADDIU8_INSTR) 
            {
            printf ("%-8s\t%s, 0x%x\n","addiu",
                     regName (I16_RTYPE_RX(inst.code),TRUE), offset);
            }
        else if ( M16_INSTR_OPCODE(inst.code) == M16_LWSP_INSTR) 
            {
            printf ("%-8s\t%s, %d(sp)\n","lw",
                     regName (I16_RTYPE_RX(inst.code),TRUE),offset);
            }
        else if ( M16_INSTR_OPCODE(inst.code) == M16_LWPC_INSTR)
            {
            printf ("%-8s\t%s, %d(pc)\n","lw",
                     regName (I16_RTYPE_RX(inst.code),TRUE),offset);
            }
        else if ( M16_INSTR_OPCODE(inst.code) == M16_SWSP_INSTR) 
            {
            printf ("%-8s\t%s, %d(sp)\n","sw",
                     regName (I16_RTYPE_RX(inst.code),TRUE),offset);
            }
        else if ( (inst.code & 0xff00) == 0x6200)          /* swrasp */
            {
            printf ("%-8s\t%s, %d(sp)\n","sw","ra",offset);
            }
        else if ( (inst.code & 0xff00) == 0x6300)         /* adjsp */
            {
	    /* this is a bit unique, immediate needs to be shifted left 3 and
	     * sign extended to 32 bit if previous instruction is not EXTEND.
	     */
	    if (!xtnd)
		offset = (int)((I16_ITYPE_I8(inst.code)) << 24) >> 21;

            printf ("%-8s\t%s, %d\n","addiu","sp",offset);
            }
        else
            specialInstr = FALSE;

        if (specialInstr == TRUE)
            return;

        } /* end if (mips16Mode) */

    /* Print the instruction mnemonic and the arguments */

    printf ("%-8s\t", iPtr->name);
    for (s = iPtr->operands; (c = *s); s++)
	{
        switch (c)
	    {
            case ',':
	        printf ("%c", c);
		break;
	    case 'r':		/* gp register */
                {
                BOOL regName32bit = TRUE;

		switch (*++s)
		    {
		    case 's': regno = inst.rtype.rs; break;
		    case 't': regno = inst.rtype.rt; break;
		    case 'd': regno = inst.rtype.rd; break;

                    /*  mips16 */
                    case 'a':
                        regno = 31;
                        break;

                    case 'r':
                        if (I16_RTYPE_RY(inst.code) == 0)
                            {
                            regno = I16_RTYPE_RX(inst.code);
                            regName32bit = FALSE;
                            }
                        else
                            regno = 31;
                        break;

                    case 'x':
                        regno = I16_RTYPE_RX(inst.code); 
                        regName32bit = FALSE; 
                        break;

                    case 'y':
                        regno = I16_RTYPE_RY(inst.code); 
                        regName32bit = FALSE; 
                        break;

                    case 'z':
                        regno = I16_RTYPE_RZ(inst.code); 
                        regName32bit = FALSE; 
                        break;

                    /* mips16 movr32 and mov32r */

                    case 'm':
                        regno = inst.code & 0x1f;
                        break;
                    case 'n':
                        regno = ((inst.code & 0xe0) >> 5) | (inst.code & 0x18);
                        break;
                    case 'o': 
                        regno = inst.code & 0x7; 
                        regName32bit = FALSE;
                        break;
		    }
		printf ("%s", regName (regno,(!regName32bit))); 
                }
		break;
	    case 'f':		/* fp register */
		switch (*++s)
		    {
		    case 's': regno = inst.ftype.fs; break;
		    case 't': regno = inst.ftype.ft; break;
		    case 'd': regno = inst.ftype.fd; break;
		    case 'r': regno = inst.ftype.fmt; break;
		    }
		printf ("$f%d", regno);
		break;
	    case 'i':		/* for mips16  */

                if ( (*(s+1) == ',') || (*(s+1) == 0))
		    printf ("%d", inst.itype.i);
                else
                    {
                    int immed = 0;

                    switch (*++s)
                        {
                        case '0': immed = inst.code & 0xf;    break;
                        case '1': immed = inst.code & 0x1f;   break;
                        case '2': immed = inst.code & 0xff;   break;

                        /* shamt (16 bit mode shift inst) */
                        case 'm':
                            immed = (inst.code >> 2) & 0x7;
                            break;

                        }
                    
		    /* if previous instruction is EXTEND, extract the
		     * operand and form the entire immediate for current 
		     * instruction accordingly.
		     */
                    if (xtnd)
			{
			if (*s == 'm')
			    immed = (xtnd >> 6) & 0x1f;
                        else if (*s == '0')
			    {
                            immed |= (M16_EXTEND_IMM(xtnd)) >> 1;
                      
			    /* sign extend to 32 bit */

			    if (immed & 0x4000)
			        immed |= 0xffff8000;	
                            }
                        else 
			    {
                            immed &= 0x1f;
                            immed |= M16_EXTEND_IMM(xtnd);
                            SIGN_EXTEND_32BIT(immed);
                            }
	                }		    
                    printf ("%d", immed);
                    }
		break;
	    case 'u':		/* 16bit unsigned */
	    	printf ("%#x", inst.utype.u);
	    	break;
	    case 'b':		/* 16bit bra offset */
                if (mips16Mode)
                    {
                    /* for mips16, the b, beqz and bnez has different size of
                     * offset. Also need to consider whether the previous  
		     * instruction is EXTEND.
                     */

                    if (xtnd)
                        {
                        offset = M16_EXTEND_IMM(xtnd) | (inst.code & 0x1f);
                        SIGN_EXTEND_32BIT(offset); 

			/* shift left 1 and adjust 2 for base address */

			offset = (offset << 1) + 2;
                        } 
                       
                    if (M16_INSTR_OPCODE(inst.code) == M16_B_INSTR) 
                        {
                        if (!xtnd)
                            offset = ((int)(inst.code << 21)) >> 20;
                        }
                                      
                    else /* beqz,bnez,bteqz and btnez */
 
                    /* next address + offset << 1  and sign-extended 32bit*/
                        {
                        if (!xtnd)
                            offset = ((int)(inst.code << 24)) >> 23;
                        }
  
                    (*prtAddress)(address + 2 + offset);
                    }
                else  /* if (mips16Mode) */

		    (*prtAddress) (address + (inst.itype.i << 2) + 4);
		break;
	    case 'j':		/* absolute jump  */
                if (mips16Mode)
                    inst.jtype.target = ((inst.code & 0x3e00000) >> 5) |
                            ((inst.code & 0x1f0000) << 5) |
                            (inst.code & 0xffff);

		(*prtAddress) ((address & 0xf0000000) | 
                               (inst.jtype.target << 2));
		break;
	    case 's':		/* shift amount */
		printf ("%d", inst.rtype.s);
		break;
	    case 'g':
		printf ("0x%x", inst.ctype.cofun);
		break;
	    case 'B':		/* break code */
		printf ("%#x(%#x)", inst.ttype.code>>10, inst.ttype.code);
		break;
	    case 'S':		/* syscall code */
		printf ("%#x", inst.ttype.code);
		break;
	    case '0':
		printf ("%s", regCP0Name (inst.rtype.rd));
		break;
	    case '1':
		printf ("%s", regCP1Name (inst.rtype.rd));
		break;
	    case 'C':
		printf ("%d", inst.rtype.rt);
		break;
	    case 'm':
                if (mips16Mode)  /* mips16 */
		    {
                    if (xtnd)
                        {
                        offset = M16_EXTEND_IMM(xtnd) | (inst.code & 0x1f);
                        SIGN_EXTEND_32BIT(offset);
                        }

		    if (M16_INSTR_OPCODE(inst.code) == M16_LB_INSTR ||
			M16_INSTR_OPCODE(inst.code) == M16_SB_INSTR ||
			M16_INSTR_OPCODE(inst.code) == M16_LBU_INSTR)
                        {
                        if (!xtnd)
			    offset = I16_ITYPE_I5(inst.code);
                        }
                    else if (M16_INSTR_OPCODE(inst.code) == M16_LH_INSTR ||
			     M16_INSTR_OPCODE(inst.code) == M16_SH_INSTR ||
			     M16_INSTR_OPCODE(inst.code) == M16_LHU_INSTR)
                        {
                        if (!xtnd)
                            offset = (I16_ITYPE_I5(inst.code)) << 1;
                        }
                    else
                        {
                        if (!xtnd)
			    offset = (I16_ITYPE_I5(inst.code)) << 2;
                        }

                    printf ("%d(%s)", offset,
                                      regName (I16_RTYPE_RX(inst.code),TRUE));
                    }				        
                else
		    printf ("%d(%s)", inst.itype.i,
			    regName (inst.itype.rs, FALSE));
		break;
	    case 'd':
		printf ("%d", inst.readCCtype.cc);
		break;
	    case 'w':
		printf ("%d", inst.writeCCtype.cc);
		break;
	    case 'n':
		printf ("%s(%s)",
			regName(inst.rtype.rt, FALSE),
			regName(inst.rtype.rs, FALSE));
		break;
	    case 'H':
		printf ("%d", inst.rtype.rd);
		break;
            case 'P':
                printf ("%d", (inst.vtype.op >> 1) & 0x1f);
                break;
	    case 'v':		/* mm register */
		switch (*++s)
		    {
		    case 't': 
			printf ("$f%d", inst.vtype.vt);
			break;

		    case 's': 
			printf ("$f%d", inst.vtype.vs);
			break;

		    case 'd': 
			printf ("$f%d", inst.vtype.vd);
			break;

		    case 'e': 
			printf ("%d", inst.vtype.sel);
			break;

		    case 'i':
			/*
			 * Fakery: this is not an ftype insn, but
			 * this avoids another format in dsmMipsLib.h
			 * that would be used for exactly 1 insn: 
			 * VR5400 alni.ob
			 */
			printf ("%d", inst.ftype.fmt & 0x7);
			break;
		    }
		break;
	    default:
		printf ("%c", c);
		break;
	    }	
	}
    printf("\n");
    }

/*******************************************************************************
*
* nPrtAddress - A dumb routine to print addresses as numbers.
*/

LOCAL void nPrtAddress
    (
    int address 
    )
    {
    printf ("%#x", address);
    }

/**************************************************************************
*
* dsmData - disassemble and print a word as data
*
* This routine is called to disassemble and print (on standard out) a
* single 32 bit word as data.  The disassembled data will be prepended 
* with the address passed as a parameter.
*
* RETURNS : The number of words occupied by the data (always 1).
*/

int dsmData
    (
    long *binInst,	/* Pointer to the data */
    int address 	/* Address prepended to data */
    )
    {
    printf ("%#06x  ", address);
    printf ("%08x    ", (UINT) *binInst );
    return (1);
    }
/*******************************************************************************
*
* dsmInst - disassemble and print a single instruction
*
* This routine is called to disassemble and print (on standard out) a
* single instruction.  The function passed as parameter prtAddress will
* be used to print any operands which might be construed as addresses.
* This could be either a simple routine that just prints a number,
* or one that looks up the address in a symbol table.
* The disassembled instruction will be prepended with the address
* passed as a parameter.
*
* If prtAddress == 0, a default routine will be used that prints 
* addresses as hex numbers.
*
* RETURNS : The number of 32-bit words occupied by the instruction.
*/

int dsmInst
    (
    ULONG binInst,	  	/* Pointer to the instruction */
    int address,		/* Address prepended to instruction */
    FUNCPTR prtAddress 		/* Address printing function */
    ) 
    {
    FAST INST *iPtr;
    FAST int size = 1; 		/* words in MIPS, always */
    BOOL mips16Mode;

    mips16Mode = mips16Instructions(address);

#ifdef _WRS_MIPS16
    address &= (~0x1);
#endif

    if (prtAddress == NULL)
	prtAddress = (FUNCPTR) nPrtAddress;

    iPtr = dsmFind (binInst,mips16Mode);
    dsmPrint (binInst, iPtr, address, size, prtAddress,mips16Mode);
    return (size);
    }
/*******************************************************************************
*
* dsmNbytes - find out how big an instruction is
*
* This routine tells how big an instruction is, in bytes. 
*
* RETURNS:
*    size of instruction, or
*    0 if instruction is unrecognized
*/

int dsmNbytes
    (
    ULONG instAddr		/* the instruction's address*/
    ) 

    {
    int      instSize = sizeof(INSTR);

#ifdef _WRS_MIPS16

    instSize = 4;   
   
    /* If mips16 function, the instruction size is 2 bytes except jal(x) inst
     * and extend instructions.
     */
    if (mips16Instructions(instAddr))
        {
	instAddr &= ~0x1;

        /* jal(x) instructions are 4 bytes */

        if ( !( (M16_INSTR_OPCODE(*(UINT16 *)instAddr) == M16_JALNX_INSTR) ||
		(M16_INSTR_OPCODE(*(UINT16 *)instAddr) == M16_EXTEND_INSTR) ) )
            instSize = 2;
        }
#endif

    return (instSize);	/* bytes/instruction always for MIPS */
    }

/*************************************************************************
*
* mips16Instructions - check if it is a mips16 instruction 
*
*/

BOOL mips16Instructions
    (
    ULONG addr
    )
    {
#ifdef _WRS_MIPS16
    char label [MAX_SYS_SYM_LEN + 1];
    int actVal;
    SYM_TYPE symType = 0;

    /* Always return true, if the mips16 mode bit is passed from user */

    if (addr & 0x1)
	return (TRUE);

    /* find out the preceding symbol type. 16 bit symbol address may have
     * bit 0 set to 1. So search addr + 1
     */

    if (_func_symFindByValue == NULL)
	return (FALSE);    /* XXX should return TRUE ? */

    if ((*_func_symFindByValue) (sysSymTbl, addr | 0x1,label,&actVal, 
	 &symType) == OK )
        {
        /* in case the SYM_MIPS16 is not set in symType */

        if (actVal & 0x1)
            symType |= SYM_MIPS16;
        }

    if (symType & SYM_MIPS16)
        return (TRUE);
    else
#endif
        return (FALSE);
    }
#endif	/* HOST */
