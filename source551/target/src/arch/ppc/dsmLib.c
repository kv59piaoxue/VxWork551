/* dsmPpc.c - PowerPC disassembler */

/* Copyright 1994-2003 Wind River Systems, Inc. */

#include "copyright_wrs.h"

/*
modification history
--------------------
01g,16sep03,mil  Fixed build problem for host mcore target.
01f,16jun03,mil  Added E500 instructions.
01e,10jun03,tpw  Merge T2.2 CP1 to E500
01d,23jan03,pch  Add isel and rfmci for 440x5 core (440GX)
01d,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
01c,29nov01,pch  SPR 71662: improve formatting consistency
01b,29oct01,pch  Add host-side debugging; retrieve target info before
		 calling dsmFind() (which needs it :)
01a,18sep01,pch  created by merging target/src/arch/ppc/dsmLib.c vn 01o
		 and host/src/tgtsvr/disassembler/dsmPpc.c vn 02r
		 Also added selective handling of processor-specific SPR's
		 and instructions in the host disassembler based on the
		 cpuType of the currently-connected target.

Following are the history entries from the merged files

    07sep01,pch  Add PPC440 operations & registers, cleanup; fix for SPR 70249.
    01jun01,dtr  Instructions dst,dstt,dstst,dststt are mixed up.
                 Instruction name change vrsqte -> vrsqrte.
                 New IFORM_VA1B for vmaddfp,vnmsubfp vB,vC swapped vC,vB. 

    30may01,dtr  Removing debug.
    29may01,dtr  Removing duplicated mask.
    30apr01,dtr  Correcting merge errors.
    27mar01,dtr  Replacing #ifdef SP7400 with  PPC604 && WRS_ALTIVEC_SUPPORT.
    15feb01,jrs  Fix masking for mulch insns.
    14feb01,jrs  Add mulc class instructions (MAC).
    14feb01,jrs  Add MMU instructions.
    14feb01,jrs  Clean up SPR registers for IBM 405.
    09dec00,jrs  Fix WS field map
    08dec00,jrs  Fix register map for dcr's.
    07dec00,dtr  Support for Altivec Instruction Set.
    04dec00,jrs  Add 405-specific target register mappings.
    30nov00,jrs  Add IBM 405 MAC and TLB instructions.
    17nov00,jrs  Add PPC405 changes.
    14sep98,fle  changed output string format
    18aug98,tpr  added PowerPC EC 603 support.
    20apr98,fle  removed appending disassembled instruction with <CR> to
                 proceed it in host/src/tgtsvr/server/tsDisassemble.c
    04mar98,fle  warnings eradication
    03sep97,fle  Adding the WTX_MEM_DISASSEMBLE service
		 + put options for returning (or not) instructions address and
		   instructions opcodes.
    26jul96,tam  cleanup. added simplified mnemonics.
    07jun96,kkk  added endian argument to dsmXXXInst and dsmXXXNbytes.
    18jun96,pr   cleanup.
	    tam  added simplified mnemonics li and lis. Fixed decoding of DCRs.
    28mar96,tam  fixed decodeSpecial() to use regList[] instead of spr[].
		 added {} in dcr, added missing declarations for DMACCx.
    27mar96,ms   added in all the #if CPU==XXX stuff.
    24jan96,elp  fixed cross-endian disassembly.
    02jan96,elp  adapted for Tornado.
    18apr95,caf  fixed floating point loads and stores.
    08feb95,caf  added PPC403 support, cleaned up SPR handling.
    29jan95,caf  fixed decoding of absolutes and immediates, changed "nop",
		 added "blr".
    22aug94,caf  created, based on version 03l of src/arch/mc68k/dsmLib.c.
*/

/*
DESCRIPTION

This library contains everything necessary to print PowerPC object code in
assembly language format. The format described below are taken from the
PowerPC manual. Some discrepancies can occur, since the formats are also
used for the printout layout. Some of the formats are the same for commands
that refer to both floating point and non floating point registers.  In
such cases the format has been split so that the respective definitions
could be used in the printout layout.

In the target server (which runs on the host), the programming
interface is via dsmPpcInstGet(). In the target shell, the interface
is via dsmInst().  Each of these entry points prints a single
disassembled instruction.

To disassemble from the shell, use l(), which calls this
library to do the actual work.  See dbgLib() for details.

INCLUDE FILE: dsmPpc.h

SEE ALSO: windSh and dbgLib
*/

/* includes */

#if	defined(HOST)

#include <stdlib.h>
#include <string.h>
#include "host.h"
#include "dsmPpc.h"
#include "wtx.h"
#include "tgtlib.h"

# ifdef CPU
# include "cputypes.h"
# else /* CPU */
# define CPU 0
# include "cputypes.h"
# undef CPU
# endif	/* CPU */

#else	/* HOST */

#include "vxWorks.h"
#include "errnoLib.h"
#include "dsmLib.h"

#endif	/* HOST */

#include "stdio.h"

/* locals */

#if	defined(HOST)
/* Host knows how to disassemble all types, but customizes for current target */
LOCAL UINT32 targetCpuType = 0;		/* CPU type number, from agent */
LOCAL UINT32 targetCoProc = 0;		/* hasCoprocessor field */
LOCAL UINT16 targetInstFlags = 0;	/* flags for supported instructions */
#endif	/* HOST */

/*

This structure contains the masks to be used for recognizing the op code
for the different commands. It is based on the form description given in
the PowerPC manual. Some implementation specific form are also included,
as well as some simplified mnemonics. Some of the form have the same
mask but are addressing different registers. In some cases, the same form
has been doubled (thus introducing an extra form with respect to the ones
described in the manual) to distinguish between operations on floating point
and general registers.

XXX - _IFORM_XO_2 is a misnomer.  These instructions
XXX - are actually form X, not form XO.

*/

LOCAL UINT32 mask [] =
    {

/*  instruction mask       form name       #    example instruction          */
/*  ----------------       ---------       -    -------------------          */

    0xfc000000,         /* _IFORM_I_1      0    b                            */
    0xfc000000,         /* _IFORM_B_1      1    bc                           */
    0xffffffff,         /* _IFORM_SC_1     2    sc                           */
    0xfc000000,         /* _IFORM_D_1      3    lwz                          */
    0xfc000000,         /* _IFORM_D_2      4    addi                         */
    0xfc000000,         /* _IFORM_D_3      5    stw                          */
    0xfc000000,         /* _IFORM_D_4      6    andi.                        */
    0xfc400000,         /* _IFORM_D_5      7    cmpi                         */
    0xfc400000,         /* _IFORM_D_6      8    cmpli                        */
    0xfc000000,         /* _IFORM_D_7      9    twi                          */
    0xfc000000,         /* _IFORM_D_8      10   stfd                         */
    0xfc0007ff,         /* _IFORM_X_1      11   lwzx                         */
    0xffff07ff,         /* _IFORM_X_2      12   tlbie                        */
    0xfc1f07ff,         /* _IFORM_X_3      13   mfsrin                       */
    0xfc1f07fe,         /* _IFORM_X_4      14   fabs                         */
    0xfc1fffff,         /* _IFORM_X_5      15   mfcr                         */
    0xfc1ffffe,         /* _IFORM_X_6      16   mffs                         */
    0xfc10ffff,         /* _IFORM_X_7      17   mfsr                         */
    0xfc0007fe,         /* _IFORM_X_8      18   and                          */
    0xfc0007ff,         /* _IFORM_X_9      19   stwcx.                       */
    0xfc0007ff,         /* _IFORM_X_10     20   stwx                         */
    0xfc00fffe,         /* _IFORM_X_11     21   cntlzw                       */
    0xfc1f07ff,         /* _IFORM_X_12     22   mtsrin                       */
    0xfc1fffff,         /* _IFORM_X_13     23   mtmsr                        */
    0xfc10ffff,         /* _IFORM_X_14     24   mtsr                         */
    0xfc0007fe,         /* _IFORM_X_15     25   srawi                        */
    0xfc4007ff,         /* _IFORM_X_16     26   cmp                          */
    0xfc6007ff,         /* _IFORM_X_17     27   fcmpo                        */
    0xfc63ffff,         /* _IFORM_X_18     28   mcrfs                        */
    0xfc7fffff,         /* _IFORM_X_19     29   mcrxr                        */
    0xfc7f0ffe,         /* _IFORM_X_20     30   mtfsfi                       */
    0xfc0007ff,         /* _IFORM_X_21     31   tw                           */
    0xffe007ff,         /* _IFORM_X_22     32   dcbz                         */
    0xffffffff,         /* _IFORM_X_23     33   sync                         */
    0xfc0007ff,         /* _IFORM_X_24     34   stfdux                       */
    0xfc0007fe,         /* _IFORM_X_25     35   mtfsb0                       */
    0xfc0007ff,         /* _IFORM_X_26     36   lswi                         */
    0xfc0007ff,         /* _IFORM_X_27     37   stswi                        */
    0xfc00fffe,         /* _IFORM_XL_1     38   bcctr                        */
    0xfc0007ff,         /* _IFORM_XL_2     39   crand                        */
    0xfc63ffff,         /* _IFORM_XL_3     40   mcrf                         */
    0xffffffff,         /* _IFORM_XL_4     41   rfi                          */
    0xfc0007ff,         /* _IFORM_XFX_1    42   mfspr                        */
    0xfc100fff,         /* _IFORM_XFX_2    43   mtcrf                        */
    0xfc0007ff,         /* _IFORM_XFX_3    44   mftb                         */
    0xfc0007ff,         /* _IFORM_XFX_4    45   mtspr                        */
    0xfe0107fe,         /* _IFORM_XFL_1    46   mtfsf                        */
    0xfc0003fe,         /* _IFORM_XO_1     47   add                          */
    0xfc0007fe,         /* _IFORM_XO_2     48   mulhw                        */
    0xfc00fbfe,         /* _IFORM_XO_3     49   addme                        */
    0xfc0007fe,         /* _IFORM_A_1      50   fadd                         */
    0xfc00003e,         /* _IFORM_A_2      51   fmadd                        */
    0xfc00f83e,         /* _IFORM_A_3      52   fmul                         */
    0xfc1f07fe,         /* _IFORM_A_4      53   fres                         */
    0xfc000000,         /* _IFORM_M_1      54   rlwimi                       */
    0xfc000000,         /* _IFORM_M_2      55   rlwnm                        */
    0xfc1f0000,         /* _IFORM_D_9      56   li                           */

    /* the following instructions are specific to the PPC400 family */

    0xfc0007ff,         /* _IFORM_400_1    57   mfdcr                        */
    0xfc0007ff,         /* _IFORM_400_2    58   mtdcr                        */
    0xffff7fff,         /* _IFORM_400_3    59   wrteei                       */
    0xfc0007fe,		/* _IFORM_405_TLB  60   tlbre, tlbwe                 */
    0xfc0007fe,		/* _IFORM_405_SX   61   tlbsx                        */

    /* the following are for altivec support */

    0xfc00003f,		/* _IFORM_VA_1	   62	vmhaddshs		     */
    0xfc00043f,		/* _IFORM_VA_2	   63   vsldoi      		     */
    0xfc0007ff,		/* _IFORM_VX_1     64	vaddubm 		     */
    0xfc1fffff,		/* _IFORM_VX_2     65	mfvscr  		     */
    0xffff07ff,		/* _IFORM_VX_3     66	mtvscr  		     */
    0xfc1f07ff,		/* _IFORM_VX_4     67	vrefp   		     */
    0xfc0007ff,		/* _IFORM_VX_5     68	vcfux   		     */
    0xfc00ffff,		/* _IFORM_VX_6     69	vspltisb 		     */
    0xfc0007ff,		/* _IFORM_X_28	   70	lvebx			     */
    0xfc0007ff,		/* _IFORM_X_29	   71	stvebx			     */
    0xfc8007ff,		/* _IFORM_X_30	   72	dstt			     */
    0xfec007ff,		/* _IFORM_X_31	   73	dst			     */
    0xfc9fffff,		/* _IFORM_X_32	   74	dssall			     */
    0xfe9fffff,		/* _IFORM_X_33	   75	dss			     */
    0xfc0003ff,		/* _IFORM_VXR_1	   76	vcmpbfp			     */
    0xfc00003f,		/* _IFORM_VA_1B	   77	vmaddfp			     */
    
    /* 440x5 and 85xx */
    0xfc00003e,		/* _IFORM_M_3	   78   isel			     */

    /* The following are for E500 (85xx), based on prelim manuals.
       The reserved bits are now don't cares instead of mandated zeros. */

    0xfc0007fe,         /* _IFORM_X_34     79   mbar (with MO field)         */
    0xfc0007fe,         /* _IFORM_X_35     80   wrteei                       */
    0xfc0007fc,         /* _IFORM_X_36     81   tlbivax                      */
    0xfc0007fe,         /* _IFORM_X_37     82   tlbsx                        */
    0xfc0007ff,         /* _IFORM_X_38     83   tlbre                        */
    0xfc0007ff,         /* _IFORM_XFX_5    84   mfpmr                        */
    0xfc0007ff,         /* _IFORM_XFX_6    85   mtpmr                        */
    0xfc0007f8,         /* _IFORM_EVS_1    86   evsel                        */
    0xfc0007ff,         /* _IFORM_EFX_1    87   efsadd                       */
    0xfc0007ff,         /* _IFORM_EFX_2    88   efscfsf                      */
    0xfc0007ff,         /* _IFORM_EFX_3    89   efsabs                       */
    0xfc0007ff,         /* _IFORM_EFX_4    90   efscmpeq                     */
    0xfc0007ff,         /* _IFORM_EVX_1    91   brinc                        */
    0xfc0007ff,         /* _IFORM_EVX_2    92   evfscfsf                     */
    0xfc0007ff,         /* _IFORM_EVX_3    93   evabs                        */
    0xfc0007ff,         /* _IFORM_EVX_4    94   evaddiw                      */
    0xfc0007ff,         /* _IFORM_EVX_5    95   evrlwi                       */
    0xfc0007ff,         /* _IFORM_EVX_6    96   evcmpeq                      */
    0xfc0007ff,         /* _IFORM_EVX_7    97   evsplatfi                    */
    0xfc0007ff,         /* _IFORM_EVX_8    98   evstddx                      */
    0xfc0007ff,         /* _IFORM_EVX_9    99   evstdh                       */
    0xfc0007ff,         /* _IFORM_EVX_10  100   evstwhe                      */
    0xfc0007ff,         /* _IFORM_EVX_11  101   evldd                        */
    0xfc0007ff,         /* _IFORM_EVX_12  102   evlhhesplat                  */
    0xfc0007ff,         /* _IFORM_EVX_13  103   evlwhe                       */
    0xfc0007ff          /* _IFORM_EVX_14  104   evsubifw                     */

#if	(!defined(HOST))
    ,(UINT32)NULL	/* mark the end of mask []			     */
#endif	/* HOST */
    };

/*

This structure contains the complete listing of the PowerPC commands.
Some implementation specific commands are also included, as well as
some simplified mnemonics. Simplified mnemonics have to be put in front.
The commands are the ones described in the PowerPC manuals.

Optional commands, present in only some implementations, are supported
on their respective target disassemblers, and on the host when connected
to a target which implements them.

The listing is made following the different forms (D, X, ...), as in
the PowerPC manual.

*/

LOCAL INST inst [] =
    {

/*  ascii       instruction bits    form name       classification flags      */
/*  -----       ----------------    ---------       --------------------      */

    /* the following instructions are simplified mnemonics */

    {"nop",      0x60000000,         _IFORM_SC_1,   0},	    /* ori r0,r0,0 */
    {"blr",      0x4e800020,         _IFORM_SC_1,   0},	    /* bclr   20,0 */
    {"blrl",	 0x4e800021,         _IFORM_SC_1,   0},     /* bclr   20,0 */
    {"bctr",     0x4e800420,         _IFORM_SC_1,   0},     /* bcctr  20,0 */
    {"bctrl",    0x4e800021,         _IFORM_SC_1,   0},     /* bcctrl 20,0 */
    {"bdzlr",    0x4e400020,         _IFORM_SC_1,   0},     /* bclr   18,0 */
    {"bdzlrl",   0x4e400021,         _IFORM_SC_1,   0},     /* bclrl  18,0 */
    {"bdnzlr",   0x4e000020,         _IFORM_SC_1,   0},     /* bclr   16,0 */
    {"bdnzlrl",  0x4e000021,         _IFORM_SC_1,   0},     /* bclrl  16,0 */
    {"li",       _OP(14,    0),      _IFORM_D_9,    0},     /* addi   RT,0,IM */
    {"lis",      _OP(15,    0),      _IFORM_D_9,    0},     /* addi   RT,0,IM */

    /* the following instructions are specific to the PPC400 family */
 
#if	(defined(HOST) || (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) || (CPU==PPC440))

    {"dccci",    _OP(31,  454),      _IFORM_X_22,    _IFLAG_4XX_SPEC},
    {"dcread",   _OP(31,  486),      _IFORM_X_1,     _IFLAG_4XX_SPEC},
    {"icbt",     _OP(31,  262),      _IFORM_X_22,    _IFLAG_4XX_SPEC},
    {"iccci",    _OP(31,  966),      _IFORM_X_22,    _IFLAG_4XX_SPEC},
    {"icread",   _OP(31,  998),      _IFORM_X_22,    _IFLAG_4XX_SPEC},
    {"mfdcr",    _OP(31,  323),      _IFORM_400_1,   _IFLAG_4XX_SPEC},
    {"mtdcr",    _OP(31,  451),      _IFORM_400_2,   _IFLAG_4XX_SPEC},
    {"rfci",     _OP(19,   51),      _IFORM_XL_4,    _IFLAG_4XX_SPEC},
    {"wrtee",    _OP(31,  131),      _IFORM_X_13,    _IFLAG_4XX_SPEC},
    {"wrteei",   _OP(31,  163),      _IFORM_400_3,   _IFLAG_4XX_SPEC},

#endif	/* HOST || PPC4xx */

    /* the following instructions are specific to the IBM 405 & 440 */

#if (defined(HOST) || (CPU == PPC405) || (CPU == PPC405F) || (CPU==PPC440))

    {"mulchw",  _OP( 4,  168), _IFORM_XO_2, _IFLAG_RC | _IFLAG_MAC},
    {"mulchwu", _OP( 4,  136), _IFORM_XO_2, _IFLAG_RC | _IFLAG_MAC},
    {"mulhhw",  _OP( 4,   40), _IFORM_XO_2, _IFLAG_RC | _IFLAG_MAC},
    {"mulhhwu", _OP( 4,    8), _IFORM_XO_2, _IFLAG_RC | _IFLAG_MAC},
    {"mullhw",  _OP( 4,  424), _IFORM_XO_2, _IFLAG_RC | _IFLAG_MAC},
    {"mullhwu", _OP( 4,  392), _IFORM_XO_2, _IFLAG_RC | _IFLAG_MAC},

    {"macchw",  _OP( 4,  172), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"macchws", _OP( 4,  236), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"macchwsu",_OP( 4,  204), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"macchwu", _OP( 4,  140), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"machhw",  _OP( 4,   44), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"machhws", _OP( 4,  108), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"machhwsu",_OP( 4,   76), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"machhwu", _OP( 4,   12), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"maclhw",  _OP( 4,  428), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"maclhws", _OP( 4,  492), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"maclhwsu",_OP( 4,  460), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"maclhwu", _OP( 4,  396), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"nmacchw", _OP( 4,  174), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"nmacchws",_OP( 4,  238), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"nmachhw", _OP( 4,   46), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"nmachhws",_OP( 4,  110), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"nmaclhw", _OP( 4,  430), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},
    {"nmaclhws",_OP( 4,  494), _IFORM_XO_1, _IFLAG_RC | _IFLAG_OE | _IFLAG_MAC},

    {"tlbsx",   _OP(31,  914), _IFORM_405_SX,  _IFLAG_RC | _IFLAG_4XTLB},
    {"tlbre",   _OP(31,  946), _IFORM_405_TLB, _IFLAG_4XTLB},
    {"tlbwe",   _OP(31,  978), _IFORM_405_TLB, _IFLAG_4XTLB},

#endif	/* HOST || (CPU==PPC405) || (CPU==PPC405F) || (CPU==PPC440) */

	/* Specific to the PPC440 */
#if	(defined(HOST) || (CPU == PPC440))
    {"icbt",	_OP(31,   22), _IFORM_X_22, _IFLAG_440_SPEC},
    {"dlmzb",	_OP(31,   78), _IFORM_X_8,  _IFLAG_RC | _IFLAG_440_SPEC},
#endif	/* HOST || CPU == PPC440 */

	/*
	 * Specific to the PPC440x5 core.  No need to explicitly test CPU,
	 * since PPC_440x5 will not be defined unless CPU == PPC440.  Host
	 * will disassemble for all 440 since at present there is no way
	 * for it to know about a CPU_VARIANT.
	 */
#if	(defined(HOST) || defined(PPC_440x5))
    {"isel",	_OP(31,   15), _IFORM_M_3,  _IFLAG_440_SPEC},
    {"rfmci",	_OP(19,   38), _IFORM_XL_4, _IFLAG_440_SPEC},
#endif	/* HOST || PPC_440x5 */

    /* the following instructions are specific to the PPC603 and PPCEC603 */

#if	(defined(HOST) || (CPU == PPC603) || (CPU == PPCEC603))

    {"tlbld",    _OP(31,  978),     _IFORM_X_2,     _IFLAG_603_SPEC},
    {"tlbli",    _OP(31, 1010),     _IFORM_X_2,     _IFLAG_603_SPEC},

#endif	/* PPC603 PPCEC603 */

    /* the following instructions are specific to the PPC85XX (E500) */

#if	(defined(HOST) || (CPU == PPC85XX))
    {"bbelr",    _OP(31,  550),     _IFORM_X_23,    _IFLAG_E500_SPEC},
    {"bblels",   _OP(31,  518),     _IFORM_X_23,    _IFLAG_E500_SPEC},
    {"dcblc",    _OP(31,  390),     _IFORM_X_21,    _IFLAG_E500_SPEC},
    {"dcbtls",   _OP(31,  166),     _IFORM_X_21,    _IFLAG_E500_SPEC},
    {"dcbtstls", _OP(31,  134),     _IFORM_X_21,    _IFLAG_E500_SPEC},
    {"icblc",    _OP(31,  230),     _IFORM_X_21,    _IFLAG_E500_SPEC},
    {"icbt",     _OP(31,   22),     _IFORM_X_21,    _IFLAG_E500_SPEC},
    {"icbtls",   _OP(31,  486),     _IFORM_X_21,    _IFLAG_E500_SPEC},
    {"isel",	 _OP(31,   15),     _IFORM_M_3,     _IFLAG_E500_SPEC},
    {"msync",    _OP(31,  598),     _IFORM_X_23,    _IFLAG_E500_SPEC},
    {"mbar",     _OP(31,  854),     _IFORM_X_34,    _IFLAG_E500_SPEC},
    {"tlbivax",  _OP(31,  786),     _IFORM_X_36,    _IFLAG_E500_SPEC},
    {"tlbre",    _OP(31,  946),     _IFORM_X_38,    _IFLAG_E500_SPEC},
    {"tlbsx",    _OP(31,  914),     _IFORM_X_37,    _IFLAG_E500_SPEC},
    {"tlbwe",    _OP(31,  978),     _IFORM_X_38,    _IFLAG_E500_SPEC},
    {"rfci",     _OP(19,   51),     _IFORM_XL_4,    _IFLAG_E500_SPEC},
    {"rfmci",    _OP(19,   38),     _IFORM_XL_4,    _IFLAG_E500_SPEC},
    {"wrtee",    _OP(31,  131),     _IFORM_X_13,    _IFLAG_E500_SPEC},
    {"wrteei",   _OP(31,  163),     _IFORM_X_35,    _IFLAG_E500_SPEC},
    {"mfpmr",    _OP(31,  334),     _IFORM_XFX_5,   _IFLAG_E500_SPEC},
    {"mtpmr",    _OP(31,  462),     _IFORM_XFX_6,   _IFLAG_E500_SPEC},
#endif	/* PPC85XX */

    /* the following instructions are generic to PowerPC */

    {"b",        _OP(18,    0),     _IFORM_I_1,     _IFLAG_AA | _IFLAG_LK},
    {"bc",       _OP(16,    0),     _IFORM_B_1,     _IFLAG_AA | _IFLAG_LK},
    {"sc",       _OP(17,    1),     _IFORM_SC_1,    0},

    {"addi",     _OP(14,    0),     _IFORM_D_2,     0},
    {"addic",    _OP(12,    0),     _IFORM_D_2,     0},
    {"addic.",   _OP(13,    0),     _IFORM_D_2,     0},
    {"addis",    _OP(15,    0),     _IFORM_D_2,     0},
    {"andi.",    _OP(28,    0),     _IFORM_D_4,     0},
    {"andis.",   _OP(29,    0),     _IFORM_D_4,     0},
    {"cmpi",     _OP(11,    0),     _IFORM_D_5,     0},
    {"cmpli",    _OP(10,    0),     _IFORM_D_6,     0},
    {"lbz",      _OP(34,    0),     _IFORM_D_1,     0},
    {"lbzu",     _OP(35,    0),     _IFORM_D_1,     0},
    {"lfd",      _OP(50,    0),     _IFORM_D_8,     0},
    {"lfdu",     _OP(51,    0),     _IFORM_D_8,     0},
    {"lfs",      _OP(48,    0),     _IFORM_D_8,     0},
    {"lfsu",     _OP(49,    0),     _IFORM_D_8,     0},
    {"lha",      _OP(42,    0),     _IFORM_D_1,     0},
    {"lhau",     _OP(43,    0),     _IFORM_D_1,     0},
    {"lhz",      _OP(40,    0),     _IFORM_D_1,     0},
    {"lhzu",     _OP(41,    0),     _IFORM_D_1,     0},
    {"lmw",      _OP(46,    0),     _IFORM_D_1,     0},
    {"lwz",      _OP(32,    0),     _IFORM_D_1,     0},
    {"lwzu",     _OP(33,    0),     _IFORM_D_1,     0},
    {"mulli",    _OP( 7,    0),     _IFORM_D_2,     0},
    {"ori",      _OP(24,    0),     _IFORM_D_4,     0},
    {"oris",     _OP(25,    0),     _IFORM_D_4,     0},
    {"stb",      _OP(38,    0),     _IFORM_D_3,     0},
    {"stbu",     _OP(39,    0),     _IFORM_D_3,     0},
    {"stfd",     _OP(54,    0),     _IFORM_D_8,     0},
    {"stfdu",    _OP(55,    0),     _IFORM_D_8,     0},
    {"stfs",     _OP(52,    0),     _IFORM_D_8,     0},
    {"stfsu",    _OP(53,    0),     _IFORM_D_8,     0},
    {"sth",      _OP(44,    0),     _IFORM_D_3,     0},
    {"sthu",     _OP(45,    0),     _IFORM_D_3,     0},
    {"stmw",     _OP(47,    0),     _IFORM_D_3,     0},
    {"stw",      _OP(36,    0),     _IFORM_D_3,     0},
    {"stwu",     _OP(37,    0),     _IFORM_D_3,     0},
    {"subfic",   _OP( 8,    0),     _IFORM_D_2,     0},
    {"twi",      _OP( 3,    0),     _IFORM_D_7,     0},
    {"xori",     _OP(26,    0),     _IFORM_D_4,     0},
    {"xoris",    _OP(27,    0),     _IFORM_D_4,     0},

    {"and",      _OP(31,   28),     _IFORM_X_8,     _IFLAG_RC},
    {"andc",     _OP(31,   60),     _IFORM_X_8,     _IFLAG_RC},
    {"cmp",      _OP(31,    0),     _IFORM_X_16,    0},
    {"cmpl",     _OP(31,   32),     _IFORM_X_16,    0},
    {"cntlzw",   _OP(31,   26),     _IFORM_X_11,    _IFLAG_RC},
    {"dcbf",     _OP(31,   86),     _IFORM_X_22,    0},
    {"dcbi",     _OP(31,  470),     _IFORM_X_22,    0},
    {"dcbst",    _OP(31,   54),     _IFORM_X_22,    0},
    {"dcbt",     _OP(31,  278),     _IFORM_X_22,    0},
    {"dcbtst",   _OP(31,  246),     _IFORM_X_22,    0},
    {"dcbz",     _OP(31, 1014),     _IFORM_X_22,    0},
    {"eciwx",    _OP(31,  310),     _IFORM_X_1,     0},
    {"ecowx",    _OP(31,  438),     _IFORM_X_10,    0},
    {"eieio",    _OP(31,  854),     _IFORM_X_23,    0},
    {"eqv",      _OP(31,  284),     _IFORM_X_8,     _IFLAG_RC},
    {"extsb",    _OP(31,  954),     _IFORM_X_11,    _IFLAG_RC},
    {"extsh",    _OP(31,  922),     _IFORM_X_11,    _IFLAG_RC},

#if (defined(HOST) || (CPU == PPC601) || (CPU == PPC603) || (CPU==PPC604) || \
	(CPU == PPC405F))
    {"fabs",     _OP(63,  264),     _IFORM_X_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fctiw",    _OP(63,   14),     _IFORM_X_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fctiwz",   _OP(63,   15),     _IFORM_X_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fcmpo",    _OP(63,   32),     _IFORM_X_17,    _IFLAG_FP_SPEC},
    {"fcmpu",    _OP(63,    0),     _IFORM_X_17,    _IFLAG_FP_SPEC},
    {"fmr",      _OP(63,   72),     _IFORM_X_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fnabs",    _OP(63,  136),     _IFORM_X_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fneg",     _OP(63,   40),     _IFORM_X_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"frsp",     _OP(63,   12),     _IFORM_X_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"lfdux",    _OP(31,  631),     _IFORM_X_24,    _IFLAG_FP_SPEC},
    {"lfdx",     _OP(31,  599),     _IFORM_X_24,    _IFLAG_FP_SPEC},
    {"lfsux",    _OP(31,  567),     _IFORM_X_24,    _IFLAG_FP_SPEC},
    {"lfsx",     _OP(31,  535),     _IFORM_X_24,    _IFLAG_FP_SPEC},
    {"stfdux",   _OP(31,  759),     _IFORM_X_24,    _IFLAG_FP_SPEC},
    {"stfdx",    _OP(31,  727),     _IFORM_X_24,    _IFLAG_FP_SPEC},
    {"stfsux",   _OP(31,  695),     _IFORM_X_24,    _IFLAG_FP_SPEC},
    {"stfiwx",   _OP(31,  983),     _IFORM_X_24,    _IFLAG_FP_SPEC},
    {"stfsx",    _OP(31,  663),     _IFORM_X_24,    _IFLAG_FP_SPEC},
#endif	/* HOST | 60x | 405F */

    {"icbi",     _OP(31,  982),     _IFORM_X_22,    0},
    {"lbzux",    _OP(31,  119),     _IFORM_X_1,     0},
    {"lbzx",     _OP(31,   87),     _IFORM_X_1,     0},
    {"lhaux",    _OP(31,  375),     _IFORM_X_1,     0},
    {"lhax",     _OP(31,  343),     _IFORM_X_1,     0},
    {"lhbrx",    _OP(31,  790),     _IFORM_X_1,     0},
    {"lhzux",    _OP(31,  311),     _IFORM_X_1,     0},
    {"lhzx",     _OP(31,  279),     _IFORM_X_1,     0},
    {"lswi",     _OP(31,  597),     _IFORM_X_26,    0},
    {"lswx",     _OP(31,  533),     _IFORM_X_1,     0},
    {"lwarx",    _OP(31,   20),     _IFORM_X_1,     0},
    {"lwbrx",    _OP(31,  534),     _IFORM_X_1,     0},
    {"lwzux",    _OP(31,   55),     _IFORM_X_1,     0},
    {"lwzx",     _OP(31,   23),     _IFORM_X_1,     0},
    {"mcrfs",    _OP(63,   64),     _IFORM_X_18,    0},
    {"mcrxr",    _OP(31,  512),     _IFORM_X_19,    0},
    {"mfcr",     _OP(31,   19),     _IFORM_X_5,     0},
    {"mffs",     _OP(63,  583),     _IFORM_X_6,     _IFLAG_RC},
    {"mfmsr",    _OP(31,   83),     _IFORM_X_5,     0},
    {"mfsr",     _OP(31,  595),     _IFORM_X_7,     0},
    {"mfsrin",   _OP(31,  659),     _IFORM_X_3,     0},
    {"mtfsb0",   _OP(63,   70),     _IFORM_X_25,    _IFLAG_RC},
    {"mtfsb1",   _OP(63,   38),     _IFORM_X_25,    _IFLAG_RC},
    {"mtfsfi",   _OP(63,  134),     _IFORM_X_20,    _IFLAG_RC},
    {"mtmsr",    _OP(31,  146),     _IFORM_X_13,    0},
    {"mtsr",     _OP(31,  210),     _IFORM_X_14,    0},
    {"mtsrin",   _OP(31,  242),     _IFORM_X_12,    0},
    {"nand",     _OP(31,  476),     _IFORM_X_8,     _IFLAG_RC},
    {"nor",      _OP(31,  124),     _IFORM_X_8,     _IFLAG_RC},
    {"or",       _OP(31,  444),     _IFORM_X_8,     _IFLAG_RC},
    {"orc",      _OP(31,  412),     _IFORM_X_8,     _IFLAG_RC},
    {"slw",      _OP(31,   24),     _IFORM_X_8,     _IFLAG_RC},
    {"sraw",     _OP(31,  792),     _IFORM_X_8,     _IFLAG_RC},
    {"srawi",    _OP(31,  824),     _IFORM_X_15,    _IFLAG_RC},
    {"srw",      _OP(31,  536),     _IFORM_X_8,     _IFLAG_RC},
    {"stbux",    _OP(31,  247),     _IFORM_X_10,    0},
    {"stbx",     _OP(31,  215),     _IFORM_X_10,    0},
    {"sthbrx",   _OP(31,  918),     _IFORM_X_10,    0},
    {"sthux",    _OP(31,  439),     _IFORM_X_10,    0},
    {"sthx",     _OP(31,  407),     _IFORM_X_10,    0},
    {"stswi",    _OP(31,  725),     _IFORM_X_27,    0},
    {"stswx",    _OP(31,  661),     _IFORM_X_10,    0},
    {"stwbrx",   _OP(31,  662),     _IFORM_X_10,    0},
    {"stwcx.", 1+_OP(31,  150),     _IFORM_X_9,     0},
    {"stwx",     _OP(31,  151),     _IFORM_X_10,    0},
    {"stwux",    _OP(31,  183),     _IFORM_X_10,    0},
    {"sync",     _OP(31,  598),     _IFORM_X_23,    0},

#if	(defined(HOST) || !defined(PPC_NO_REAL_MODE))
    {"tlbia",    _OP(31,  370),     _IFORM_X_23,    0},
#endif	/* HOST || !PPC_NO_REAL_MODE */

    {"tlbie",    _OP(31,  306),     _IFORM_X_2,     0},
    {"tlbsync",  _OP(31,  566),     _IFORM_X_23,    0},
    {"tw",       _OP(31,    4),     _IFORM_X_21,    0},
    {"xor",      _OP(31,  316),     _IFORM_X_8,     _IFLAG_RC},

    {"bcctr",    _OP(19,  528),     _IFORM_XL_1,    _IFLAG_LK},
    {"bclr",     _OP(19,   16),     _IFORM_XL_1,    _IFLAG_LK},
    {"crand",    _OP(19,  257),     _IFORM_XL_2,    0},
    {"crandc",   _OP(19,  129),     _IFORM_XL_2,    0},
    {"creqv",    _OP(19,  289),     _IFORM_XL_2,    0},
    {"crnand",   _OP(19,  225),     _IFORM_XL_2,    0},
    {"crnor",    _OP(19,   33),     _IFORM_XL_2,    0},
    {"cror",     _OP(19,  449),     _IFORM_XL_2,    0},
    {"crorc",    _OP(19,  417),     _IFORM_XL_2,    0},
    {"crxor",    _OP(19,  193),     _IFORM_XL_2,    0},
    {"isync",    _OP(19,  150),     _IFORM_XL_4,    0},
    {"mcrf",     _OP(19,    0),     _IFORM_XL_3,    0},
    {"rfi",      _OP(19,   50),     _IFORM_XL_4,    0},

    {"mfspr",    _OP(31,  339),     _IFORM_XFX_1,   0},
    {"mtspr",    _OP(31,  467),     _IFORM_XFX_4,   0},
    {"mtcrf",    _OP(31,  144),     _IFORM_XFX_2,   0},
    {"mftb",     _OP(31,  371),     _IFORM_XFX_3,   0},

    {"mtfsf",	 _OP(63,  711),     _IFORM_XFL_1,   _IFLAG_RC},

    {"add",      _OP(31,  266),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"addc",     _OP(31,   10),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"adde",     _OP(31,  138),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"addme",    _OP(31,  234),     _IFORM_XO_3,    _IFLAG_RC | _IFLAG_OE},
    {"addze",    _OP(31,  202),     _IFORM_XO_3,    _IFLAG_RC | _IFLAG_OE},
    {"divw",     _OP(31,  491),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"divwu",    _OP(31,  459),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"mulhw",    _OP(31,   75),     _IFORM_XO_2,    _IFLAG_RC},
    {"mulhwu",   _OP(31,   11),     _IFORM_XO_2,    _IFLAG_RC},
    {"mullw",    _OP(31,  235),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"neg",      _OP(31,  104),     _IFORM_XO_3,    _IFLAG_RC | _IFLAG_OE},
    {"subf",     _OP(31,   40),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"subfc",    _OP(31,    8),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"subfe",    _OP(31,  136),     _IFORM_XO_1,    _IFLAG_RC | _IFLAG_OE},
    {"subfme",   _OP(31,  232),     _IFORM_XO_3,    _IFLAG_RC | _IFLAG_OE},
    {"subfze",   _OP(31,  200),     _IFORM_XO_3,    _IFLAG_RC | _IFLAG_OE},

#if (defined(HOST) || (CPU == PPC601) || (CPU == PPC603) || (CPU==PPC604) || \
	(CPU == PPC405F))
    {"fadd",     _OP(63,   21),     _IFORM_A_1,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fadds",    _OP(59,   21),     _IFORM_A_1,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fdiv",     _OP(63,   18),     _IFORM_A_1,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fdivs",    _OP(59,   18),     _IFORM_A_1,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fmadd",    _OP(63,   29),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fmadds",   _OP(59,   29),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fmsub",    _OP(63,   28),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fmsubs",   _OP(59,   28),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fmul",     _OP(63,   25),     _IFORM_A_3,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fmuls",    _OP(59,   25),     _IFORM_A_3,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fnmadd",   _OP(63,   31),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fnmadds",  _OP(59,   31),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fnmsub",   _OP(63,   30),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fnmsubs",  _OP(59,   30),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fres",     _OP(59,   24),     _IFORM_A_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"frsqrte",  _OP(63,   26),     _IFORM_A_4,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fsel",     _OP(63,   23),     _IFORM_A_2,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fsub",     _OP(63,   20),     _IFORM_A_1,     _IFLAG_RC | _IFLAG_FP_SPEC},
    {"fsubs",    _OP(59,   20),     _IFORM_A_1,     _IFLAG_RC | _IFLAG_FP_SPEC},
#endif	/* HOST | 60x | 405F */

    /* The following are for the Altivec processor */
#if     (defined(HOST) || ((CPU == PPC604) && (_WRS_ALTIVEC_SUPPORT == TRUE)))

    {"vmaddfp",     _VOP(4,   46),  _IFORM_VA_1B,  _IFLAG_AV_SPEC},
    {"vnmsubfp",    _VOP(4,   47),  _IFORM_VA_1B,  _IFLAG_AV_SPEC},
    {"vmhaddshs",   _VOP(4,   32),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vmhraddshs",  _VOP(4,   33),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vmladduhm",   _VOP(4,   34),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vmsumubm",    _VOP(4,   36),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vmsummbm",    _VOP(4,   37),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vmsumuhm",    _VOP(4,   38),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vmsumuhs",    _VOP(4,   39),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vmsumshm",    _VOP(4,   40),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vmsumshs",    _VOP(4,   41),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vsel",	    _VOP(4,   42),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vperm",       _VOP(4,   43),  _IFORM_VA_1,   _IFLAG_AV_SPEC},
    {"vsldoi",	    _VOP(4,   44),  _IFORM_VA_2,   _IFLAG_AV_SPEC},
    {"vaddubm",	    _VOP(4,    0),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vadduhm",	    _VOP(4,   64),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vadduwm",	    _VOP(4,  128),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vaddcuw",	    _VOP(4,  384),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vaddubs",	    _VOP(4,  512),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vadduhs",	    _VOP(4,  576),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vadduws",	    _VOP(4,  640),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vaddsbs",	    _VOP(4,  768),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vaddshs",	    _VOP(4,  832),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vaddsws",	    _VOP(4,  896),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsububm",	    _VOP(4, 1024),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubuhm",	    _VOP(4, 1088),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubuwm",	    _VOP(4, 1152),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubcuw",	    _VOP(4, 1408),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsububs",	    _VOP(4, 1536),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubuhs",	    _VOP(4, 1600),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubuws",	    _VOP(4, 1664),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubsbs",	    _VOP(4, 1792),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubshs",	    _VOP(4, 1856),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubsws",	    _VOP(4, 1920),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmaxub",	    _VOP(4,    2),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmaxuh",	    _VOP(4,   66),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmaxuw",	    _VOP(4,  130),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmaxsb",	    _VOP(4,  258),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmaxsh",	    _VOP(4,  322),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmaxsw",	    _VOP(4,  386),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vminub",	    _VOP(4,  514),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vminuh",	    _VOP(4,  578),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vminuw",	    _VOP(4,  642),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vminsb",	    _VOP(4,  770),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vminsh",	    _VOP(4,  834),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vminsw",	    _VOP(4,  898),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vavgub",	    _VOP(4, 1026),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vavguh",	    _VOP(4, 1090),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vavguw",	    _VOP(4, 1154),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vavgsb",	    _VOP(4, 1282),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vavgsh",	    _VOP(4, 1346),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vavgsw",	    _VOP(4, 1410),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vrlb",	    _VOP(4,    4),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vrlh",	    _VOP(4,   68),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vrlw",	    _VOP(4,  132),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vslb",	    _VOP(4,  260),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vslh",	    _VOP(4,  324),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vslw",	    _VOP(4,  388),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsl",	    _VOP(4,  452),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsrb",	    _VOP(4,  516),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsrh",	    _VOP(4,  580),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsrw",	    _VOP(4,  644),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsr",	    _VOP(4,  708),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsrab",	    _VOP(4,  772),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsrah",	    _VOP(4,  836),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsraw",	    _VOP(4,  900),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vand",	    _VOP(4, 1028),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vandc",	    _VOP(4, 1092),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vor",	    _VOP(4, 1156),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vnor",	    _VOP(4, 1284),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"mfvscr",	    _OP(4,   770),  _IFORM_VX_2,   _IFLAG_AV_SPEC},
    {"mtvscr",	    _OP(4,   802),  _IFORM_VX_3,   _IFLAG_AV_SPEC},
    {"vmuloub",	    _VOP(4,    8),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmulouh",	    _VOP(4,   72),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmulosb",	    _VOP(4,  264),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmulosh",	    _VOP(4,  328),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmuleub",	    _VOP(4,  520),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmuleuh",	    _VOP(4,  584),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmulesb",	    _VOP(4,  776),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmulesh",	    _VOP(4,  840),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsum4ubs",    _VOP(4, 1544),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsum4sbs",    _VOP(4, 1800),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsum4shs",    _VOP(4, 1608),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsum2sws",    _VOP(4, 1672),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsumsws",	    _VOP(4, 1928),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vaddfp",	    _VOP(4,   10),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsubfp",	    _VOP(4,   74),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vrefp",	    _VOP(4,  266),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vrsqrtefp",   _VOP(4,  330),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vexptefp",    _VOP(4,  394),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vlogefp",	    _VOP(4,  458),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vrfin",	    _VOP(4,  522),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vrfiz",	    _VOP(4,  586),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vrfip",	    _VOP(4,  650),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vrfim",	    _VOP(4,  714),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vcfux",	    _VOP(4,  778),  _IFORM_VX_5,   _IFLAG_AV_SPEC},
    {"vcfsx",	    _VOP(4,  842),  _IFORM_VX_5,   _IFLAG_AV_SPEC},
    {"vctuxs",	    _VOP(4,  906),  _IFORM_VX_5,   _IFLAG_AV_SPEC},
    {"vctsxs",	    _VOP(4,  970),  _IFORM_VX_5,   _IFLAG_AV_SPEC},
    {"vmaxfp",	    _VOP(4, 1034),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vminfp",	    _VOP(4, 1098),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmrghb",	    _VOP(4,   12),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmrghh",	    _VOP(4,   76),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmrghw",	    _VOP(4,  140),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmrglb",	    _VOP(4,  268),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmrglh",	    _VOP(4,  332),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vmrglw",	    _VOP(4,  396),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vspltb",	    _VOP(4,  524),  _IFORM_VX_5,   _IFLAG_AV_SPEC},
    {"vsplth",	    _VOP(4,  588),  _IFORM_VX_5,   _IFLAG_AV_SPEC},
    {"vspltw",	    _VOP(4,  652),  _IFORM_VX_5,   _IFLAG_AV_SPEC},
    {"vspltisb",    _VOP(4,  780),  _IFORM_VX_6,   _IFLAG_AV_SPEC},
    {"vspltish",    _VOP(4,  844),  _IFORM_VX_6,   _IFLAG_AV_SPEC},
    {"vspltisw",    _VOP(4,  908),  _IFORM_VX_6,   _IFLAG_AV_SPEC},
    {"vslo",	    _VOP(4, 1036),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vsro",	    _VOP(4, 1100),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vpkuhum",	    _VOP(4,   14),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vpkuwum",	    _VOP(4,   78),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vpkuhus",	    _VOP(4,  142),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vpkuwus",	    _VOP(4,  206),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vpkshus",	    _VOP(4,  270),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vpkswus",	    _VOP(4,  334),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vpkshss",	    _VOP(4,  398),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vpkswss",	    _VOP(4,  462),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"vupkhsb",	    _VOP(4,  526),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vupkhsh",	    _VOP(4,  590),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vupklsb",	    _VOP(4,  654),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vupklsh",	    _VOP(4,  718),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vpkpx",  _VOP(4, (12<<6) + 14), _IFORM_VX_1, _IFLAG_AV_SPEC},
    {"vupkhpx",	    _VOP(4,  846),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vupklpx",	    _VOP(4,  974),  _IFORM_VX_4,   _IFLAG_AV_SPEC},
    {"vxor",	    _VOP(4, 1220),  _IFORM_VX_1,   _IFLAG_AV_SPEC},
    {"dst",	    _OP(31,  342),  _IFORM_X_31,   _IFLAG_AV_SPEC},
    {"dstt",	    _OP(31,  342),  _IFORM_X_30,   _IFLAG_AV_SPEC},
    {"dstst",	    _OP(31,  374),  _IFORM_X_31,   _IFLAG_AV_SPEC},
    {"dststt",	    _OP(31,  374),  _IFORM_X_30,   _IFLAG_AV_SPEC},
    {"dss",         _OP(31,  822),  _IFORM_X_33,   _IFLAG_AV_SPEC},
    {"dssall",	    _OP(31,  822),  _IFORM_X_32,   _IFLAG_AV_SPEC},
    {"lvebx",	    _OP(31,    7),  _IFORM_X_28,   _IFLAG_AV_SPEC},
    {"lvehx",	    _OP(31,   39),  _IFORM_X_28,   _IFLAG_AV_SPEC},
    {"lvewx",	    _OP(31,   71),  _IFORM_X_28,   _IFLAG_AV_SPEC},
    {"lvsl",	    _OP(31,    6),  _IFORM_X_28,   _IFLAG_AV_SPEC},
    {"lvsr",	    _OP(31,   38),  _IFORM_X_28,   _IFLAG_AV_SPEC},
    {"lvx",	    _OP(31,  103),  _IFORM_X_28,   _IFLAG_AV_SPEC},
    {"lvxl",	    _OP(31,  359),  _IFORM_X_28,   _IFLAG_AV_SPEC},
    {"stvebx",	    _OP(31,  135),  _IFORM_X_29,   _IFLAG_AV_SPEC},
    {"stvehx",	    _OP(31,  167),  _IFORM_X_29,   _IFLAG_AV_SPEC},
    {"stvewx",	    _OP(31,  199),  _IFORM_X_29,   _IFLAG_AV_SPEC},
    {"stvx",	    _OP(31,  231),  _IFORM_X_29,   _IFLAG_AV_SPEC},
    {"stvxl",	    _OP(31,  487),  _IFORM_X_29,   _IFLAG_AV_SPEC},
    {"vcmpbfp",     _VOP(4,  966),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpeqfp",    _VOP(4,  198),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpequb",    _VOP(4,    6),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpequh",    _VOP(4,   70),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpequw",    _VOP(4,  134),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpgefp",    _VOP(4,  454),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpgtfp",    _VOP(4,  710),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpgtsb",    _VOP(4,  774),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpgtsh",    _VOP(4,  838),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpgtsw",    _VOP(4,  902),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpgtub",    _VOP(4,  518),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpgtuh",    _VOP(4,  582),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},
    {"vcmpgtuw",    _VOP(4,  646),  _IFORM_VXR_1,  _IFLAG_VRC | _IFLAG_AV_SPEC},

#endif /* HOST || (CPU==PPC604 && _WRS_ALTIVEC_SUPPORT == TRUE) */

    /* The following are for the SPE on E500 processors */

#if     (defined(HOST) || ((CPU == PPC85XX)))

    {"evsel",       _ESOP(4,  79),  _IFORM_EVS_1,  _IFLAG_E500_SPEC},
    {"efsabs",      _VOP(4,  708),  _IFORM_EFX_3,  _IFLAG_E500_SPEC},
    {"efsadd",      _VOP(4,  704),  _IFORM_EFX_1,  _IFLAG_E500_SPEC},
    {"efscfsf",     _VOP(4,  723),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efscfsi",     _VOP(4,  721),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efscfuf",     _VOP(4,  722),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efscfui",     _VOP(4,  720),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efscmpeq",    _VOP(4,  718),  _IFORM_EFX_4,  _IFLAG_E500_SPEC},
    {"efscmpgt",    _VOP(4,  716),  _IFORM_EFX_4,  _IFLAG_E500_SPEC},
    {"efscmplt",    _VOP(4,  717),  _IFORM_EFX_4,  _IFLAG_E500_SPEC},
    {"efsctsf",     _VOP(4,  727),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efsctsi",     _VOP(4,  725),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efsctsiz",    _VOP(4,  730),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efsctuf",     _VOP(4,  726),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efsctui",     _VOP(4,  724),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efsctuiz",    _VOP(4,  728),  _IFORM_EFX_2,  _IFLAG_E500_SPEC},
    {"efsdiv",      _VOP(4,  713),  _IFORM_EFX_1,  _IFLAG_E500_SPEC},
    {"efsmul",      _VOP(4,  712),  _IFORM_EFX_1,  _IFLAG_E500_SPEC},
    {"efsnabs",     _VOP(4,  709),  _IFORM_EFX_3,  _IFLAG_E500_SPEC},
    {"efsneg",      _VOP(4,  710),  _IFORM_EFX_3,  _IFLAG_E500_SPEC},
    {"efssub",      _VOP(4,  705),  _IFORM_EFX_1,  _IFLAG_E500_SPEC},
    {"efststeq",    _VOP(4,  734),  _IFORM_EFX_4,  _IFLAG_E500_SPEC},
    {"efststgt",    _VOP(4,  732),  _IFORM_EFX_4,  _IFLAG_E500_SPEC},
    {"efststlt",    _VOP(4,  733),  _IFORM_EFX_4,  _IFLAG_E500_SPEC},

    {"brinc",        _VOP(4,  527),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evabs",        _VOP(4,  520),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evaddiw",      _VOP(4,  514),  _IFORM_EVX_4,  _IFLAG_E500_SPEC},
    {"evaddsmiaaw",  _VOP(4, 1225),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evaddssiaaw",  _VOP(4, 1217),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evaddumiaaw",  _VOP(4, 1224),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evaddusiaaw",  _VOP(4, 1216),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evaddw",       _VOP(4,  512),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evand",        _VOP(4,  529),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evandc",       _VOP(4,  530),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evcmpeq",      _VOP(4,  564),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evcmpgts",     _VOP(4,  561),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evcmpgtu",     _VOP(4,  560),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evcmplts",     _VOP(4,  563),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evcmpltu",     _VOP(4,  562),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evcntlsw",     _VOP(4,  526),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evcntlzw",     _VOP(4,  525),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evdivws",      _VOP(4, 1222),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evdivwu",      _VOP(4, 1223),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"eveqv",        _VOP(4,  537),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evextsb",      _VOP(4,  522),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evextsh",      _VOP(4,  523),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evfsabs",      _VOP(4,  644),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evfsadd",      _VOP(4,  640),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evfscfsf",     _VOP(4,  659),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfscfsi",     _VOP(4,  657),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfscfuf",     _VOP(4,  658),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfscfui",     _VOP(4,  656),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfscmpeq",    _VOP(4,  654),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evfscmpgt",    _VOP(4,  652),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evfscmplt",    _VOP(4,  653),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evfsctsf",     _VOP(4,  663),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfsctsi",     _VOP(4,  661),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfsctsiz",    _VOP(4,  666),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfsctuf",     _VOP(4,  662),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfsctui",     _VOP(4,  660),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfsctuiz",    _VOP(4,  664),  _IFORM_EVX_2,  _IFLAG_E500_SPEC},
    {"evfsdiv",      _VOP(4,  649),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evfsmul",      _VOP(4,  648),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evfsnabs",     _VOP(4,  645),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evfsneg",      _VOP(4,  646),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evfssub",      _VOP(4,  641),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evfststeq",    _VOP(4,  670),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evfststgt",    _VOP(4,  668),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evfststlt",    _VOP(4,  669),  _IFORM_EVX_6,  _IFLAG_E500_SPEC},
    {"evldd",        _VOP(4,  769),  _IFORM_EVX_11, _IFLAG_E500_SPEC},
    {"evlddx",       _VOP(4,  768),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evldh",        _VOP(4,  773),  _IFORM_EVX_11, _IFLAG_E500_SPEC},
    {"evldhx",       _VOP(4,  772),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evldw",        _VOP(4,  771),  _IFORM_EVX_11, _IFLAG_E500_SPEC},
    {"evldwx",       _VOP(4,  770),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evlhhesplat",  _VOP(4,  777),  _IFORM_EVX_12, _IFLAG_E500_SPEC},
    {"evlhhesplatx", _VOP(4,  776),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evlhhossplat", _VOP(4,  783),  _IFORM_EVX_12, _IFLAG_E500_SPEC},
    {"evlhhossplatx",_VOP(4,  782),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evlhhousplat", _VOP(4,  781),  _IFORM_EVX_12, _IFLAG_E500_SPEC},
    {"evlhhousplatx",_VOP(4,  780),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evlwhe",       _VOP(4,  785),  _IFORM_EVX_13, _IFLAG_E500_SPEC},
    {"evlwhex",      _VOP(4,  784),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evlwhos",      _VOP(4,  791),  _IFORM_EVX_13, _IFLAG_E500_SPEC},
    {"evlwhosx",     _VOP(4,  790),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evlwhou",      _VOP(4,  789),  _IFORM_EVX_13, _IFLAG_E500_SPEC},
    {"evlwhoux",     _VOP(4,  788),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evlwhsplat",   _VOP(4,  797),  _IFORM_EVX_13, _IFLAG_E500_SPEC},
    {"evlwhsplatx",  _VOP(4,  796),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evlwwsplat",   _VOP(4,  793),  _IFORM_EVX_13, _IFLAG_E500_SPEC},
    {"evlwwsplatx",  _VOP(4,  792),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmergehi",    _VOP(4,  556),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmergehilo",  _VOP(4,  558),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmergelo",    _VOP(4,  557),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmergelohi",  _VOP(4,  559),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhegsmfaa",  _VOP(4, 1323),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhegsmfan",  _VOP(4, 1451),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhegsmiaa",  _VOP(4, 1321),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhegsmian",  _VOP(4, 1449),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhegumiaa",  _VOP(4, 1320),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhegumian",  _VOP(4, 1448),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhesmf",     _VOP(4, 1035),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhesmfa",    _VOP(4, 1067),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhesmfaaw",  _VOP(4, 1291),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhesmfanw",  _VOP(4, 1419),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhesmi",     _VOP(4, 1033),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhesmia",    _VOP(4, 1065),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhesmiaaw",  _VOP(4, 1289),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhesmianw",  _VOP(4, 1417),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhessf",     _VOP(4, 1027),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhessfa",    _VOP(4, 1059),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhessfaaw",  _VOP(4, 1283),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhessfanw",  _VOP(4, 1411),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhessiaaw",  _VOP(4, 1281),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhessianw",  _VOP(4, 1409),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmheumi",     _VOP(4, 1032),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmheumia",    _VOP(4, 1064),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmheumiaaw",  _VOP(4, 1288),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmheumianw",  _VOP(4, 1416),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmheusiaaw",  _VOP(4, 1280),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmheusianw",  _VOP(4, 1408),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhogsmfaa",  _VOP(4, 1327),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhogsmfan",  _VOP(4, 1455),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhogsmiaa",  _VOP(4, 1325),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhogsmian",  _VOP(4, 1453),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhogumiaa",  _VOP(4, 1324),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhogumian",  _VOP(4, 1452),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhosmf",     _VOP(4, 1039),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhosmfa",    _VOP(4, 1071),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhosmfaaw",  _VOP(4, 1295),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhosmfanw",  _VOP(4, 1423),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhosmi",     _VOP(4, 1037),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhosmia",    _VOP(4, 1069),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhosmiaaw",  _VOP(4, 1293),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhosmianw",  _VOP(4, 1421),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhossf",     _VOP(4, 1031),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhossfa",    _VOP(4, 1063),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhossfaaw",  _VOP(4, 1287),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhossfanw",  _VOP(4, 1415),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhossiaaw",  _VOP(4, 1285),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhossianw",  _VOP(4, 1413),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhoumi",     _VOP(4, 1036),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhoumia",    _VOP(4, 1068),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhoumiaaw",  _VOP(4, 1292),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhoumianw",  _VOP(4, 1420),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhousiaaw",  _VOP(4, 1284),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmhousianw",  _VOP(4, 1412),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmra",        _VOP(4, 1220),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evmwhsmf",     _VOP(4, 1103),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhsmfa",    _VOP(4, 1135),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhsmi",     _VOP(4, 1101),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhsmia",    _VOP(4, 1133),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhssf",     _VOP(4, 1095),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhssfa",    _VOP(4, 1127),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhumi",     _VOP(4, 1100),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhumia",    _VOP(4, 1132),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhusiaaw",  _VOP(4, 1348),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwhusianw",  _VOP(4, 1476),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwlumi",     _VOP(4, 1096),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwlumia",    _VOP(4, 1128),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwlumiaaw",  _VOP(4, 1352),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwlumianw",  _VOP(4, 1480),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwlusiaaw",  _VOP(4, 1344),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwlusianw",  _VOP(4, 1472),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwsmf",      _VOP(4, 1115),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwsmfa",     _VOP(4, 1147),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwsmfaa",    _VOP(4, 1371),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwsmfan",    _VOP(4, 1499),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwsmi",      _VOP(4, 1113),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwsmia",     _VOP(4, 1145),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwsmiaa",    _VOP(4, 1369),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwsmian",    _VOP(4, 1497),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwssf",      _VOP(4, 1107),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwssfa",     _VOP(4, 1139),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwssfaa",    _VOP(4, 1363),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwssfan",    _VOP(4, 1491),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwumi",      _VOP(4, 1112),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwumia",     _VOP(4, 1144),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwumiaa",    _VOP(4, 1368),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evmwumian",    _VOP(4, 1496),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evnand",       _VOP(4,  542),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evneg",        _VOP(4,  521),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evnor",        _VOP(4,  536),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evor",         _VOP(4,  535),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evorc",        _VOP(4,  539),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evrlw",        _VOP(4,  552),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evrlwi",       _VOP(4,  554),  _IFORM_EVX_5,  _IFLAG_E500_SPEC},
    {"evrndw",       _VOP(4,  524),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evslw",        _VOP(4,  548),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evslwi",       _VOP(4,  550),  _IFORM_EVX_5,  _IFLAG_E500_SPEC},
    {"evsplatfi",    _VOP(4,  555),  _IFORM_EVX_7,  _IFLAG_E500_SPEC},
    {"evsplati",     _VOP(4,  553),  _IFORM_EVX_7,  _IFLAG_E500_SPEC},
    {"evsrwis",      _VOP(4,  547),  _IFORM_EVX_5,  _IFLAG_E500_SPEC},
    {"evsrwiu",      _VOP(4,  546),  _IFORM_EVX_5,  _IFLAG_E500_SPEC},
    {"evsrws",       _VOP(4,  545),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evsrwu",       _VOP(4,  544),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evstdd",       _VOP(4,  801),  _IFORM_EVX_11, _IFLAG_E500_SPEC},
    {"evstddx",      _VOP(4,  800),  _IFORM_EVX_8,  _IFLAG_E500_SPEC},
    {"evstdh",       _VOP(4,  805),  _IFORM_EVX_9,  _IFLAG_E500_SPEC},
    {"evstdhx",      _VOP(4,  804),  _IFORM_EVX_8,  _IFLAG_E500_SPEC},
    {"evstdw",       _VOP(4,  803),  _IFORM_EVX_9,  _IFLAG_E500_SPEC},
    {"evstdwx",      _VOP(4,  802),  _IFORM_EVX_8,  _IFLAG_E500_SPEC},
    {"evstwhe",      _VOP(4,  817),  _IFORM_EVX_10, _IFLAG_E500_SPEC},
    {"evstwhex",     _VOP(4,  816),  _IFORM_EVX_8,  _IFLAG_E500_SPEC},
    {"evstwho",      _VOP(4,  821),  _IFORM_EVX_10, _IFLAG_E500_SPEC},
    {"evstwhox",     _VOP(4,  820),  _IFORM_EVX_8,  _IFLAG_E500_SPEC},
    {"evstwwe",      _VOP(4,  825),  _IFORM_EVX_10, _IFLAG_E500_SPEC},
    {"evstwwex",     _VOP(4,  824),  _IFORM_EVX_8,  _IFLAG_E500_SPEC},
    {"evstwwo",      _VOP(4,  829),  _IFORM_EVX_10, _IFLAG_E500_SPEC},
    {"evstwwox",     _VOP(4,  828),  _IFORM_EVX_8,  _IFLAG_E500_SPEC},
    {"evsubfsmiaaw", _VOP(4, 1227),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evsubfssiaaw", _VOP(4, 1219),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evsubfumiaaw", _VOP(4, 1226),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evsubfusiaaw", _VOP(4, 1218),  _IFORM_EVX_3,  _IFLAG_E500_SPEC},
    {"evsubfw",      _VOP(4,  516),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
    {"evsubifw",     _VOP(4,  518),  _IFORM_EVX_14, _IFLAG_E500_SPEC},
    {"evxor",        _VOP(4,  534),  _IFORM_EVX_1,  _IFLAG_E500_SPEC},
#endif /* HOST || (CPU==PPC85XX) */

    {"rlwimi",   _OP(20,    0),     _IFORM_M_1,     _IFLAG_RC},
    {"rlwinm",   _OP(21,    0),     _IFORM_M_1,     _IFLAG_RC},
    {"rlwnm",    _OP(23,    0),     _IFORM_M_2,     _IFLAG_RC}

    };    /* end of inst[] */

LOCAL SPR spr [] =
    {
    /* The following SPRs are generic to all PowerPC processors */

    {9,		"CTR"},  	/* count */
    {8,		"LR"},   	/* link */
    {287,	"PVR"},		/* processor version */
    {272,	"SPRG0"},	/* operating system use */
    {273,	"SPRG1"},	/* operating system use */
    {274,	"SPRG2"},	/* operating system use */
    {275,	"SPRG3"},	/* operating system use */
    {26,	"SRR0"},	/* save/restore */
    {27,	"SRR1"},	/* save/restore */
    {1,		"XER"},		/* integer exception */

    /*
     * The following SPRs are processor specific.  On the host,
     * create a separate array for each CPU or group of similar
     * CPU's.  On each target, include only its own definitions.
     */

#if	(defined(HOST) || (CPU == PPC403))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr403 [] =
    {
# endif	/* HOST */
    {0x3d7,	"CDBCR"},
    {0x3f6,	"DAC1"},
    {0x3f7,	"DAC2"},
    {0x3f2,	"DBCR"},
    {0x3f0,	"DBSR"},
    {0x3fa,	"DCCR"},
    {0x3d5,	"DEAR"},
    {0x3d4,	"ESR"},
    {0x3d6,	"EVPR"},
    {0x3f4,	"IAC1"},
    {0x3f5,	"IAC2"},
    {0x3fb,	"ICCR"},
    {0x3d3,	"ICDBDR"},
    {0x3fc,	"PBL1"},
    {0x3fe,	"PBL2"},
    {0x3fd,	"PBU1"},
    {0x3ff,	"PBU2"},
    {0x3db,	"PIT"},
    {0x3de,	"SRR2"},
    {0x3df,	"SRR3"},
    {0x3dc,	"TBHI"},
    {0x3dd,	"TBLO"},
    {0x3da,	"TCR"},
    {0x3d8,	"TSR"},
#endif	/* HOST || PPC403 */

#if	(defined(HOST) || (CPU == PPC405) || (CPU == PPC405F))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr405 [] =
    {
# endif	/* HOST */
    {0x3b3,	"CCR0"},
    {0x3f6,	"DAC1"},
    {0x3f7,	"DAC2"},
    {0x3f2,	"DBCR0"},
    {0x3bd,	"DBCR1"},
    {0x3f0,	"DBSR"},
    {0x3fa,	"DCCR"},
    {0x3ba,	"DCWR"},
    {0x3d5,	"DEAR"},
    {0x3b6,	"DVC1"},
    {0x3b7,	"DVC2"},
    {0x3d4,	"ESR"},
    {0x3d6,	"EVPR"},
    {0x3f4,	"IAC1"},
    {0x3f5,	"IAC2"},
    {0x3b4,	"IAC3"},
    {0x3b5,	"IAC4"},
    {0x3fb,	"ICCR"},
    {0x3d3,	"ICDBDR"},
    {0x008,	"LR"},
    {0x3b1,	"PID"},
    {0x3db,	"PIT"},
    {0x3b9,	"SGR"},
    {0x3bb,	"SLER"},
    {0x114,	"SPRG4"},
    {0x104,	"SPRG4_R"},
    {0x115,	"SPRG5"},
    {0x105,	"SPRG5_R"},
    {0x116,	"SPRG6"},
    {0x106,	"SPRG6_R"},
    {0x117,	"SPRG7"},
    {0x107,	"SPRG7_R"},
    {0x3de,	"SRR2"},
    {0x3df,	"SRR3"},
    {0x3bc,	"SU0R"},
    {0x10c,	"TBL"},
    {0x11c,	"TBL"},
    {0x10d,	"TBU"},
    {0x11d,	"TBU"},
    {0x3da,	"TCR"},
    {0x3d8,	"TSR"},
    {0x100,	"USPRG0"},
    {0x3b0,	"ZPR"},
#endif	/* HOST || PPC405 || PPC405F */

#if	(defined(HOST) || (CPU == PPC440))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr440 [] =
    {
# endif	/* HOST */
    {0x3B3,	"CCR0"},	/* Core Configuration Register 0 */
    {0x03A,	"CSRR0"},	/* Critical Save/Restore Register 0 */
    {0x03B,	"CSRR1"},	/* Critical Save/Restore Register 1 */
    {0x13C,	"DAC1"},	/* Data Address Compare 1 */
    {0x13D,	"DAC2"},	/* Data Address Compare 2 */
    {0x134,	"DBCR0"},	/* Debug Control Register 0 */
    {0x135,	"DBCR1"},	/* Debug Control Register 1 */
    {0x136,	"DBCR2"},	/* Debug Control Register 2 */
    {0x3F3,	"DBDR"},	/* Debug Data Register */
    {0x130,	"DBSR"},	/* Debug Status Register */
    {0x39D,	"DCDBTRH"},	/* Data Cache Debug Tag Register High */
    {0x39C,	"DCDBTRL"},	/* Data Cache Debug Tag Register Low */
    {0x03D,	"DEAR"},	/* Data Exception Address Register */
    {0x016,	"DEC"},		/* Decrementer */
    {0x036,	"DECAR"},	/* Decrementer Auto-Reload */
    {0x390,	"DNV0"},	/* Data Cache Normal Victim 0 */
    {0x391,	"DNV1"},	/* Data Cache Normal Victim 1 */
    {0x392,	"DNV2"},	/* Data Cache Normal Victim 2 */
    {0x393,	"DNV3"},	/* Data Cache Normal Victim 3 */
    {0x394,	"DTV0"},	/* Data Cache Transient Victim 0 */
    {0x395,	"DTV1"},	/* Data Cache Transient Victim 1 */
    {0x396,	"DTV2"},	/* Data Cache Transient Victim 2 */
    {0x397,	"DTV3"},	/* Data Cache Transient Victim 3 */
    {0x13E,	"DVC1"},	/* Data Value Compare 1 */
    {0x13F,	"DVC2"},	/* Data Value Compare 2 */
    {0x398,	"DVLIM"},	/* Data Cache Victim Limit */
    {0x03E,	"ESR"},		/* Exception Syndrome Register */
    {0x138,	"IAC1"},	/* Instruction Address Compare 1 */
    {0x139,	"IAC2"},	/* Instruction Address Compare 2 */
    {0x13A,	"IAC3"},	/* Instruction Address Compare 3 */
    {0x13B,	"IAC4"},	/* Instruction Address Compare 4 */
    {0x3D3,	"ICDBDR"},	/* Instruction Cache Debug Data Register */
    {0x39F,	"ICDBTRH"},	/* Instruction Cache Debug Tag Register High */
    {0x39E,	"ICDBTRL"},	/* Instruction Cache Debug Tag Register Low */
    {0x370,	"INV0"},	/* Instruction Cache Normal Victim 0 */
    {0x371,	"INV1"},	/* Instruction Cache Normal Victim 1 */
    {0x372,	"INV2"},	/* Instruction Cache Normal Victim 2 */
    {0x373,	"INV3"},	/* Instruction Cache Normal Victim 3 */
    {0x374,	"ITV0"},	/* Instruction Cache Transient Victim 0 */
    {0x375,	"ITV1"},	/* Instruction Cache Transient Victim 1 */
    {0x376,	"ITV2"},	/* Instruction Cache Transient Victim 2 */
    {0x377,	"ITV3"},	/* Instruction Cache Transient Victim 3 */
    {0x399,	"IVLIM"},	/* Instruction Cache Victim Limit */
    {0x190,	"IVOR0"},	/* Critical Input */
    {0x191,	"IVOR1"},	/* Machine Check */
    {0x192,	"IVOR2"},	/* Data Storage */
    {0x193,	"IVOR3"},	/* Instruction Storage */
    {0x194,	"IVOR4"},	/* External Input */
    {0x195,	"IVOR5"},	/* Alignment */
    {0x196,	"IVOR6"},	/* Program */
    {0x197,	"IVOR7"},	/* Floating Point Unavailable */
    {0x198,	"IVOR8"},	/* System Call */
    {0x199,	"IVOR9"},	/* Auxiliary Processor Unavailable */
    {0x19A,	"IVOR10"},	/* Decrementer */
    {0x19B,	"IVOR11"},	/* Fixed Interval Timer */
    {0x19C,	"IVOR12"},	/* Watchdog Timer */
    {0x19D,	"IVOR13"},	/* Data TLB Error */
    {0x19E,	"IVOR14"},	/* Instruction TLB Error */
    {0x19F,	"IVOR15"},	/* Debug */
    {0x03F,	"IVPR"},	/* Interrupt Vector Prefix Register */
    {0x3B2,	"MMUCR"},	/* Memory Management Unit Control Register */
    {0x030,	"PID"},		/* Process ID */
    {0x11E,	"PIR"},		/* Processor ID Register */
    {0x39B,	"RSTCFG"},	/* Reset Configuration */
    {0x104,	"SPRG4_R"},	/* Special Purpose Register General 4, read */
    {0x114,	"SPRG4_W"},	/* Special Purpose Register General 4, write */
    {0x105,	"SPRG5_R"},	/* Special Purpose Register General 5, read */
    {0x115,	"SPRG5_W"},	/* Special Purpose Register General 5, write */
    {0x106,	"SPRG6_R"},	/* Special Purpose Register General 6, read */
    {0x116,	"SPRG6_W"},	/* Special Purpose Register General 6, write */
    {0x107,	"SPRG7_R"},	/* Special Purpose Register General 7, read */
    {0x117,	"SPRG7_W"},	/* Special Purpose Register General 7, write */
    {0x10C,	"TBL_R"},	/* Time Base Lower, read */
    {0x11C,	"TBL_W"},	/* Time Base Lower, write */
    {0x10D,	"TBU_R"},	/* Time Base Upper, read */
    {0x11D,	"TBU_W"},	/* Time Base Upper, write */
    {0x154,	"TCR"},		/* Timer Control Register */
    {0x150,	"TSR"},		/* Timer Status Register */
    {0x100,	"USPRG0"},	/* User Special Purpose Register General 0 */
#endif	/* HOST || PPC440 */

#if (defined(HOST) || (CPU == PPC509))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr509 [] =
    {
# endif	/* HOST */
    {19,	"DAR"},		/* exception handling */
    {22,	"DEC"},		/* decrementer */
    {18,	"DSISR"},	/* exception handling */
    {81,	"EID"},		/* External Interrupt Disable */
    {80,	"EIE"},		/* External Interrupt Enable */
    {1022,	"FPECR"},	/* Floating-Point Exception Cause Register */
    {561,	"ICADR"},	/* I-Cache Address Register */
    {560,	"ICCSR"},	/* Control and Status Register */
    {562,	"ICDAT"},	/* I-Cache Data Port */
    {82,	"NRE"},		/* Non-Recoverable Exception */
    {284,	"TBL"},		/* time base -- for writing */
    {268,	"TBL"},  	/* time base -- for reading */
    {285,	"TBU"},		/* time base -- for writing */
    {269,	"TBU"},  	/* time base -- for reading */
#endif /* HOST || PPC509 */

#if (defined(HOST) || (CPU == PPC555))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr555 [] =
    {
# endif	/* HOST */
    {19,	"DAR"},		/* exception handling */
    {22,	"DEC"},		/* decrementer */
    {18,	"DSISR"},	/* exception handling */
    {81,	"EID"},		/* External Interrupt Disable */
    {80,	"EIE"},		/* External Interrupt Enable */
    {1022,	"FPECR"},	/* Floating-Point Exception Cause Register */
    {824,	"L2U_RA0"},	/* L2U Region Attribute Register 0 */
    {825,	"L2U_RA1"},	/* L2U Region Attribute Register 1 */
    {826,	"L2U_RA2"},	/* L2U Region Attribute Register 2 */
    {827,	"L2U_RA3"},	/* L2U Region Attribute Register 3 */
    {792,	"L2U_RBA0"},	/* L2U Region Base Address Register 0 */
    {793,	"L2U_RBA1"},	/* L2U Region Base Address Register 1 */
    {794,	"L2U_RBA2"},	/* L2U Region Base Address Register 2 */
    {795,	"L2U_RBA3"},	/* L2U Region Base Address Register 3 */
    {816,	"MI_RA0"},	/* IMPU Region Attribute Register 0 */
    {817,	"MI_RA1"},	/* IMPU Region Attribute Register 1 */
    {818,	"MI_RA2"},	/* IMPU Region Attribute Register 2 */
    {819,	"MI_RA3"},	/* IMPU Region Attribute Register 3 */
    {784,	"MI_RBA0"},	/* IMPU Region Base Address 0 */
    {785,	"MI_RBA1"},	/* IMPU Region Base Address 1 */
    {787,	"MI_RBA3"},	/* IMPU Region Base Address 3 */
    {82,	"NRE"},		/* Non-Recoverable Exception */
    {284,	"TBL"},		/* time base -- for writing */
    {268,	"TBL"},  	/* time base -- for reading */
    {285,	"TBU"},		/* time base -- for writing */
    {269,	"TBU"},  	/* time base -- for reading */
#endif /* HOST || PPC555 */

#if	(defined(HOST) || (CPU == PPC601))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr601 [] =
    {
# endif	/* HOST */
    {1013,	"DABR"},	/* optional in the PowerPC architecture */
    {19,	"DAR"},		/* exception handling */
    {537,	"DBAT0L"},	/* memory management */
    {536,	"DBAT0U"},	/* memory management */
    {539,	"DBAT1L"},	/* memory management */
    {538,	"DBAT1U"},	/* memory management */
    {541,	"DBAT2L"},	/* memory management */
    {540,	"DBAT2U"},	/* memory management */
    {543,	"DBAT3L"},	/* memory management */
    {542,	"DBAT3U"},	/* memory management */
    {22,	"DEC"},		/* decrementer */
    {18,	"DSISR"},	/* exception handling */
    {282,	"EAR"},		/* optional in the PowerPC architecture */
    {1008,	"HID0"},
    {1009,	"HID1"},
    {1010,	"IABR"},
    {529,	"IBAT0L"},	/* memory management */
    {528,	"IBAT0U"},	/* memory management */
    {531,	"IBAT1L"},	/* memory management */
    {530,	"IBAT1U"},	/* memory management */
    {533,	"IBAT2L"},	/* memory management */
    {532,	"IBAT2U"},	/* memory management */
    {535,	"IBAT3L"},	/* memory management */
    {534,	"IBAT3U"},	/* memory management */
    {0,		"MQ"},
    {1023,	"PIR"},		/* optional in the PowerPC architecture */
    {5,		"RTCL"},	/* for reading */
    {21,	"RTCL"},	/* for writing */
    {4,		"RTCU"},	/* for reading */
    {20,	"RTCU"},	/* for writing */
    {25,	"SDR1"},  	/* memory management */
    {284,	"TBL"},		/* time base -- for writing */
    {268,	"TBL"},  	/* time base -- for reading */
    {285,	"TBU"},		/* time base -- for writing */
    {269,	"TBU"},  	/* time base -- for reading */
#endif	/* HOST || PPC601 */

#if	(defined(HOST) || (CPU == PPC603) || (CPU == PPCEC603))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr603 [] =
    {
# endif	/* HOST */
    {19,	"DAR"},		/* exception handling */
    {537,	"DBAT0L"},	/* memory management */
    {536,	"DBAT0U"},	/* memory management */
    {539,	"DBAT1L"},	/* memory management */
    {538,	"DBAT1U"},	/* memory management */
    {541,	"DBAT2L"},	/* memory management */
    {540,	"DBAT2U"},	/* memory management */
    {543,	"DBAT3L"},	/* memory management */
    {542,	"DBAT3U"},	/* memory management */
    {977,	"DCMP"},
    {22,	"DEC"},		/* decrementer */
    {976,	"DMISS"},
    {18,	"DSISR"},	/* exception handling */
    {282,	"EAR"},		/* optional in the PowerPC architecture */
    {978,	"HASH1"},
    {979,	"HASH2"},
    {1008,	"HID0"},
    {1010,	"IABR"},
    {529,	"IBAT0L"},	/* memory management */
    {528,	"IBAT0U"},	/* memory management */
    {531,	"IBAT1L"},	/* memory management */
    {530,	"IBAT1U"},	/* memory management */
    {533,	"IBAT2L"},	/* memory management */
    {532,	"IBAT2U"},	/* memory management */
    {535,	"IBAT3L"},	/* memory management */
    {534,	"IBAT3U"},	/* memory management */
    {981,	"ICMP"},
    {980,	"IMISS"},
    {982,	"RPA"},
    {25,	"SDR1"},  	/* memory management */
    {284,	"TBL"},		/* time base -- for writing */
    {268,	"TBL"},  	/* time base -- for reading */
    {285,	"TBU"},		/* time base -- for writing */
    {269,	"TBU"},  	/* time base -- for reading */
#endif	/* HOST || PPC603 PPCEC603 */

#if	(defined(HOST) || (CPU == PPC604))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr604 [] =
    {
# endif	/* HOST */
    {1013,	"DABR"},	/* optional in the PowerPC architecture */
    {19,	"DAR"},		/* exception handling */
    {537,	"DBAT0L"},	/* memory management */
    {536,	"DBAT0U"},	/* memory management */
    {539,	"DBAT1L"},	/* memory management */
    {538,	"DBAT1U"},	/* memory management */
    {541,	"DBAT2L"},	/* memory management */
    {540,	"DBAT2U"},	/* memory management */
    {543,	"DBAT3L"},	/* memory management */
    {542,	"DBAT3U"},	/* memory management */
    {22,	"DEC"},		/* decrementer */
    {18,	"DSISR"},	/* exception handling */
    {282,	"EAR"},		/* optional in the PowerPC architecture */
    {1008,	"HID0"},
    {1010,	"IABR"},
    {529,	"IBAT0L"},	/* memory management */
    {528,	"IBAT0U"},	/* memory management */
    {531,	"IBAT1L"},	/* memory management */
    {530,	"IBAT1U"},	/* memory management */
    {533,	"IBAT2L"},	/* memory management */
    {532,	"IBAT2U"},	/* memory management */
    {535,	"IBAT3L"},	/* memory management */
    {534,	"IBAT3U"},	/* memory management */
    {952,	"MMCR0"},
    {1023,	"PIR"},		/* optional in the PowerPC architecture */
    {953,	"PMC1"},
    {954,	"PMC2"},
    {959,	"SDA"},
    {25,	"SDR1"},  	/* memory management */
    {955,	"SIA"},
    {284,	"TBL"},		/* time base -- for writing */
    {268,	"TBL"},  	/* time base -- for reading */
    {285,	"TBU"},		/* time base -- for writing */
    {269,	"TBU"},  	/* time base -- for reading */
    {256,	"VRSAVE"},	/* Altivec specific */
#endif	/* HOST || PPC604 */

#if	(defined(HOST) || (CPU == PPC85XX))
# if	defined(HOST)
    {NONE,	""}		/* END OF LIST */
    };
LOCAL SPR spr85xx [] =
    {
# endif	/* HOST */
    {58,	"CSRR0"},	/* Critical Save/Restore Register 0 */
    {59,	"CSRR1"},	/* Critical Save/Restore Register 1 */
    {316,	"DAC1"},	/* Data Address Compare 1 */
    {317,	"DAC2"},	/* Data Address Compare 2 */
    {308,	"DBCR0"},	/* Debug Control Register 0 */
    {309,	"DBCR1"},	/* Debug Control Register 1 */
    {310,	"DBCR2"},	/* Debug Control Register 2 */
    {304,	"DBSR"},	/* Debug Status Register */
    {61,	"DEAR"},	/* Data Exception Address Register */
    {22,	"DEC"},		/* Decrementer */
    {54,	"DECAR"},	/* Decrementer Auto-Reload */
    {62,	"ESR"},		/* Exception Syndrome Register */
    {312,	"IAC1"},	/* Instruction Address Compare 1 */
    {313,	"IAC2"},	/* Instruction Address Compare 2 */
    {400,	"IVOR0"},	/* Critical Input */
    {401,	"IVOR1"},	/* Machine Check */
    {402,	"IVOR2"},	/* Data Storage */
    {403,	"IVOR3"},	/* Instruction Storage */
    {404,	"IVOR4"},	/* External Input */
    {405,	"IVOR5"},	/* Alignment */
    {406,	"IVOR6"},	/* Program */
    {407,	"IVOR7"},	/* Floating Point Unavailable */
    {408,	"IVOR8"},	/* System Call */
    {409,	"IVOR9"},	/* Auxiliary Processor Unavailable */
    {410,	"IVOR10"},	/* Decrementer */
    {411,	"IVOR11"},	/* Fixed Interval Timer */
    {412,	"IVOR12"},	/* Watchdog Timer */
    {413,	"IVOR13"},	/* Data TLB Error */
    {414,	"IVOR14"},	/* Instruction TLB Error */
    {415,	"IVOR15"},	/* Debug */
    {63,	"IVPR"},	/* Interrupt Vector Prefix Register */
    {48,	"PID"},		/* Process ID */
    {286,	"PIR"},		/* Processor ID Register */
    {260,	"SPRG4_R"},	/* Special Purpose Register General 4, read */
    {276,	"SPRG4_W"},	/* Special Purpose Register General 4, write */
    {261,	"SPRG5_R"},	/* Special Purpose Register General 5, read */
    {277,	"SPRG5_W"},	/* Special Purpose Register General 5, write */
    {262,	"SPRG6_R"},	/* Special Purpose Register General 6, read */
    {278,	"SPRG6_W"},	/* Special Purpose Register General 6, write */
    {263,	"SPRG7_R"},	/* Special Purpose Register General 7, read */
    {279,	"SPRG7_W"},	/* Special Purpose Register General 7, write */
    {268,	"TBL_R"},	/* Time Base Lower, read */
    {284,	"TBL_W"},	/* Time Base Lower, write */
    {269,	"TBU_R"},	/* Time Base Upper, read */
    {285,	"TBU_W"},	/* Time Base Upper, write */
    {340,	"TCR"},		/* Timer Control Register */
    {336,	"TSR"},		/* Timer Status Register */
    {256,	"USPRG0"},	/* User Special Purpose Register General 0 */
    {513,       "BBEAR"},       /* Branch Buffer Entry Address Register */
    {514,       "BBTAR"},       /* Branch Buffer Target Address Register */
    {1013,      "BUCSR"},       /* Branch Unit Control and Status Register */
    {1008,      "HID0"},        /* Hardware Implementation Dependent Reg 0 */
    {1009,      "HID1"},        /* Hardware Implementation Dependent Reg 1 */
    {528,       "IVOR32"},      /* SPE APU Unavailable */
    {529,       "IVOR33"},      /* SPE Floating Point Data */
    {530,       "IVOR34"},      /* SPE Floating Point Round */
    {531,       "IVOR35"},      /* Performance Monitor */
    {515,       "L1CFG0"},      /* L1 Cache Configuration Register 0 */
    {516,       "L1CFG1"},      /* L1 Cache Configuration Register 1 */
    {1010,      "L1CSR0"},      /* L1 Cache Control and Status Reg 0 */
    {1011,      "L1CSR1"},      /* L1 Cache Control and Status Reg 1 */
    {624,       "MAS0"},        /* MMU Assist Reg 0 */
    {625,       "MAS1"},        /* MMU Assist Reg 1 */
    {626,       "MAS2"},        /* MMU Assist Reg 2 */
    {627,       "MAS3"},        /* MMU Assist Reg 3 */
    {628,       "MAS4"},        /* MMU Assist Reg 4 */
    {629,       "MAS5"},        /* MMU Assist Reg 5 */
    {630,       "MAS6"},        /* MMU Assist Reg 6 */
    {573,       "MCAR"},        /* Machine Check Address Register */
    {572,       "MCSR"},        /* Machine Check Syndrome Register */
    {570,       "MCSRR0"},      /* Machine Check Save/Restore Reg 0 */
    {571,       "MCSRR1"},      /* Machine Check Save/Restore Reg 1 */
    {1015,      "MMUCFG"},      /* MMU Configuration Register */
    {1012,      "MMUCSR0"},     /* MMU Control and Status Register 0 */
    {517,       "NPIDR"},       /* Nexus Processor ID Register */
    {48,        "PID0"},        /* Process ID Register 0 */
    {633,       "PID1"},        /* Process ID Register 1 */
    {634,       "PID2"},        /* Process ID Register 2 */
    {512,       "SPEFSCR"},     /* SPE Floating Point Status and Control Reg */
    {688,       "TLB0CFG"},     /* TLB Configuration Register 0 */
    {689,       "TLB1CFG"},     /* TLB Configuration Register 1 */
#endif	/* HOST || PPC85XX */

    {NONE,	""}		/* END OF LIST */
    };

#if	defined(HOST)
LOCAL SPR *altSpr = NULL;	/* CPU-specific SPR table for current CPU */
#endif	/* HOST */

#if	(defined(HOST) || (CPU == PPC403))
LOCAL SPR dcr [] =	/* device control registers (PPC403 only) */
    { 
    {0x90,	"BEAR"},
    {0x91,	"BESR"},
    {0x80,	"BR0"},
    {0x81,	"BR1"},
    {0x82,	"BR2"},
    {0x83,	"BR3"},
    {0x84,	"BR4"},
    {0x85,	"BR5"},
    {0x86,	"BR6"},
    {0x87,	"BR7"},
    {0xc4,	"DMACC0"},
    {0xcc,	"DMACC1"},
    {0xd4,	"DMACC2"},
    {0xdc,	"DMACC3"},
    {0xc0,	"DMACR0"},
    {0xc8,	"DMACR1"},
    {0xd0,	"DMACR2"},
    {0xd8,	"DMACR3"},
    {0xc1,	"DMACT0"},
    {0xc9,	"DMACT1"},
    {0xd1,	"DMACT2"},
    {0xd9,	"DMACT3"},
    {0xc2,	"DMADA0"},
    {0xca,	"DMADA1"},
    {0xd2,	"DMADA2"},
    {0xda,	"DMADA3"},
    {0xc3,	"DMASA0"},
    {0xcb,	"DMASA1"},
    {0xd3,	"DMASA2"},
    {0xdb,	"DMASA3"},
    {0xe0,	"DMASR"},
    {0x40,	"EXISR"},
    {0x42,	"EXIER"},
    {0xa0,	"IOCR"},
    {NONE,	""}		/* END OF LIST */
    };
#endif	/* HOST || PPC403 */

#if	((CPU == PPC405) || (CPU == PPC405F))

/* XXX - Note that the 405 core does not provide *any* DCR's.  These
 * XXX - definitions apply to the 405GP, and perhaps to some other
 * XXX - 405-based ASIC's.  A mechanism should be provided for a BSP
 * XXX - to supply the DCR list.  This array is not built on the host.
 */
LOCAL SPR dcr [] =	/* device control registers (PPC405 only) */
    {
    {0x010,      "SDRAM0_CFGADDR"},
    {0x011,      "SDRAM0_CFGDATA"},
    {0x012,      "EBC0_CFGADDR"},
    {0x013,      "EBC0_CFGDATA"},
    {0x014,      "DCP0_CFGADDR"},
    {0x015,      "DCP0_CFGDATA"},
    {0x018,      "OCM0_ISARC"},
    {0x019,      "OCM0_ISCNTL"},
    {0x01a,      "OCM0_DSARC"},
    {0x01b,      "OCM0_DSCNTL"},
    {0x0a0,      "POB0_BESR0"},
    {0x0a2,      "POB0_BEAR"},
    {0x0a4,      "POB0_BESR1"},
    {0x0b0,      "CPC0_PLLMR"},
    {0x0b1,      "CPC0_CR0"},
    {0x0b2,      "CPC0_CR1"},
    {0x0b4,      "CPC0_PSR"},
    {0x0b5,      "CPC0_JTAGID"},
    {0x0b8,      "CPC0_SR"},
    {0x0b9,      "CPC0_ER"},
    {0x0ba,      "CPC0_FR"},
    {0x0c5,      "UIC0_TR"},
    {0x0c6,      "UIC0_MSR"},
    {0x0c7,      "UIC0_VR"},
    {0x100,      "DMA0_CR0"},
    {0x101,      "DMA0_CT0"},
    {0x102,      "DMA0_DA0"},
    {0x103,      "DMA0_SA0"},
    {0x104,      "DMA0_SG0"},
    {0x108,      "DMA0_CR1"},
    {0x109,      "DMA0_CT0"},
    {0x10a,      "DMA0_DA0"},
    {0x10b,      "DMA0_SA0"},
    {0x10c,      "DMA0_SG0"},
    {0x110,      "DMA0_CR2"},
    {0x111,      "DMA0_CT2"},
    {0x112,      "DMA0_DA2"},
    {0x113,      "DMA0_SA2"},
    {0x114,      "DMA0_SG2"},
    {0x118,      "DMA0_CR3"},
    {0x119,      "DMA0_CT3"},
    {0x11a,      "DMA0_DA3"},
    {0x11b,      "DMA0_SA3"},
    {0x11c,      "DMA0_SG3"},
    {0x120,      "DMA0_SR"},
    {0x123,      "DMA0_SGC"},
    {0x125,      "DMA0_SLP"},
    {0x126,      "DMA0_POL"},
    {0x180,      "MAL0_CFG"},
    {0x181,      "MAL0_ESR"},
    {0x182,      "MAL0_IER"},
    {0x184,      "MAL0_TXCASR"},
    {0x185,      "MAL0_TXCARR"},
    {0x186,      "MAL0_TXEOBISR"},
    {0x187,      "MAL0_TXDEIR"},
    {0x190,      "MAL0_RXCASR"},
    {0x191,      "MAL0_RXCARR"},
    {0x192,      "MAL0_RXEOBISR"},
    {0x193,      "MAL0_RXDEIR"},
    {0x1a0,      "MAL0_TXCTP0R"},
    {0x1a1,      "MAL0_TXCTP1R"},
    {0x1c0,      "MAL0_RXCTP0R"},
    {0x1e0,      "MAL0_RCBS0"},
    {0x084,      "PLB0_BESR"},
    {0x086,      "PLB0_BEAR"},
    {0x087,      "PLB0_ACR"},
    {0x0a0,      "POB0_BESR0"},
    {0x0c0,      "UIC0_SR"},
    {0x0c2,      "UIC0_ER"},
    {0x0c3,      "UIC0_CR"},
    {0x0c4,      "UIC0_PR"},
    {0x0c8,      "UIC0_VCR"},

    {NONE,	""}		/* END OF LIST */
    };
#endif	/* CPU == PPC405 || CPU == PPC405F */

#if	(CPU == PPC440)
/* XXX - As with the 405, the 440 core does not provide any DCR's.  Unlike the
 * XXX - 405, we don't have a prior release out there pretending that it does.
 */
LOCAL SPR dcr [] =	/* device control registers (PPC440 only) */
    {
    {NONE,	""}		/* END OF LIST */
    };
#endif	/* PPC440 */

#if     (defined(HOST) || (CPU == PPC85XX))
LOCAL SPR pmr [] =      /* Performance Monitor Register (PPC85XX only) */
    {
    {16,        "PMC0"},        /* Performance Monitor Counter 0 */
    {17,        "PMC1"},        /* Performance Monitor Counter 1 */
    {18,        "PMC2"},        /* Performance Monitor Counter 2 */
    {19,        "PMC3"},        /* Performance Monitor Counter 3 */
    {400,       "PMGC0"},       /* Performance Monitor Gbl Ctrl Reg 0 */
    {144,       "PMLCa0"},      /* Performance Monitor Local Ctrl a0 */
    {145,       "PMLCa1"},      /* Performance Monitor Local Ctrl a1 */
    {146,       "PMLCa2"},      /* Performance Monitor Local Ctrl a2 */
    {147,       "PMLCa3"},      /* Performance Monitor Local Ctrl a3 */
    {272,       "PMLCb0"},      /* Performance Monitor Local Ctrl b0 */
    {273,       "PMLCb1"},      /* Performance Monitor Local Ctrl b1 */
    {274,       "PMLCb2"},      /* Performance Monitor Local Ctrl b2 */
    {275,       "PMLCb3"},      /* Performance Monitor Local Ctrl b3 */

    {0,         "UPMC0"},        /* User Performance Monitor Counter 0 */
    {1,         "UPMC1"},        /* User Performance Monitor Counter 1 */
    {2,         "UPMC2"},        /* User Performance Monitor Counter 2 */
    {3,         "UPMC3"},        /* User Performance Monitor Counter 3 */
    {128,       "UPMLCa0"},      /* User Performance Monitor Local Ctrl a0 */
    {129,       "UPMLCa1"},      /* User Performance Monitor Local Ctrl a1 */
    {130,       "UPMLCa2"},      /* User Performance Monitor Local Ctrl a2 */
    {131,       "UPMLCa3"},      /* User Performance Monitor Local Ctrl a3 */
    {256,       "UPMLCb0"},      /* User Performance Monitor Local Ctrl b0 */
    {257,       "UPMLCb1"},      /* User Performance Monitor Local Ctrl b1 */
    {258,       "UPMLCb2"},      /* User Performance Monitor Local Ctrl b2 */
    {259,       "UPMLCb3"},      /* User Performance Monitor Local Ctrl b3 */
    {384,       "UPMGC0"},       /* User Performance Monitor Gbl Ctrl Reg 0 */

    {NONE,      ""}             /* END OF LIST */
    };
#endif  /* HOST || PPC85XX */


#if	defined(HOST)
/*****************************************************************************
*
* upbinInst - return an unpacked UINT32 in BIG_ENDIAN format
*
* RETURNS: an UINT32 in BIG_ENDIAN format
*/

LOCAL UINT32 upbinInst
    (
    UINT32	binInst_val
    )
    {
    return UNPACK_B32(&binInst_val);
    }
#else	/* HOST */
#define	upbinInst(binInst_val) (binInst_val)
#endif	/* HOST */

/*******************************************************************************
*
* dsmFind - find descriptor for one instruction
*
* This routine figures out which instruction is pointed to by binInst,
* and returns a pointer to the INST which describes it.
*
* RETURNS: pointer to instruction or NULL if unknown instruction.
*/

LOCAL INST *dsmFind
    (
#if	defined(HOST)
    UINT32 *	binInst      /* pointer to the instruction */
#else	/* HOST */
    INSTR *binInst      /* pointer to the instruction */
#endif	/* HOST */
    )
    {
    int         mule;
    UINT32	tmpMask;

#ifdef DEBUG
printf ("\n disassembling 0x%08x\n", upbinInst (* binInst));
#endif /* DEBUG */

    for (mule = 0; mule < (int) NELEMENTS (inst); mule ++)
	{
	tmpMask = mask[inst[mule].form];

	if ( ( (upbinInst (* binInst)) & tmpMask) == inst [mule].op)
	    {
#ifdef DEBUG
printf (" [ mule==%3d  form==%2d  mask==0x%08x  op==0x%08x ]\n",
        mule, inst[mule].form, mask[inst[mule].form], inst[mule].op);
#endif /* DEBUG */

#if	defined(HOST)
# ifdef DEBUG
printf (" [ flags==0x%04x  _IFLAG_SPEC==0x%04x  targetInstFlags==0x%04x ]\n",
        inst[mule].flags, _IFLAG_SPEC, targetInstFlags);
# endif /* DEBUG */
	    /* See if the INST found applies to the current target */
	    if ((inst[mule].flags & _IFLAG_SPEC)	/* not generic */
	     && !(inst[mule].flags & targetInstFlags))	/* not this one */
		continue;
#endif	/* HOST */

	    break;
	    }
	}

    if (mule >= (int) NELEMENTS(inst))
	{
#if	(!defined(HOST))
	errnoSet (S_dsmLib_UNKNOWN_INSTRUCTION);
#endif	/* HOST */
        return ((INST *) NULL);			/* no instruction found */
	}

    return (inst + mule);
    }

/*
 * The PRINT macro is very peculiar, in that it generates the front end
 * of a function call *including* the open parenthesis (and, on the host,
 * the first parameter) but *excluding* the remaining parameters and the
 * closing parenthesis.  This makes its invocations look strange.  It's
 * done this way because C macros don't allow varargs.
 */
#if	defined(HOST)
#define PRINT sprintf (pString + strlen(pString),
#else	/* HOST */
#define PRINT printf (
#endif	/* HOST */

/*******************************************************************************
*
* nPrtAddress - print addresses as numbers
*/

LOCAL void nPrtAddress
    (
#if	defined(HOST)
    TGT_ADDR_T	address,
    char *	pString	/* string to write in */
#else	/* HOST */
    UINT32 address
#endif	/* HOST */
    )
    {
    PRINT "%#x", (unsigned int) address);
    }

/*******************************************************************************
*
* dsmSuffixPrint - print an instruction suffix
*
* Prints the 'o', '.', 'l', and/or 'a' suffixes for an instruction.
*
* RETURNS: The number of characters transmitted.
*/

LOCAL int dsmSuffixPrint
    (
#if	defined(HOST)
    UINT32 *		binInst,  /* pointer to the instruction */
    INST *		iPtr,     /* pointer to INST returned by dsmFind */
    char *		pString   /* string to write in */
#else	/* HOST */
    INSTR *     binInst,    /* pointer to the instruction                */
    FAST INST * iPtr        /* pointer to INST returned by dsmFind       */
#endif	/* HOST */
    )
    {
    int		sum = 0;

    if ((iPtr->flags & _IFLAG_OE) && _IFIELD_OE(* binInst))
        {
#if	defined(HOST)
	strcat (pString, "o");
	sum++;
#else	/* HOST */
	sum += printf ("o");
#endif	/* HOST */
	}

    if ((iPtr->flags & _IFLAG_RC) && _IFIELD_RC(* binInst))
        {
#if	defined(HOST)
	strcat (pString, ".");
	sum++;
#else	/* HOST */
	sum += printf (".");
#endif	/* HOST */
	}

    if ((iPtr->flags & _IFLAG_VRC) && _IFIELD_VRC(* binInst))
        {
#if	defined(HOST)
	strcat (pString, ".");
	sum++;
#else	/* HOST */
	sum += printf (".");
#endif	/* HOST */
	}

    if ((iPtr->flags & _IFLAG_LK) && _IFIELD_LK(* binInst))
        {
#if	defined(HOST)
	strcat (pString, "l");
	sum++;
#else	/* HOST */
	sum += printf ("l");
#endif	/* HOST */
	}

    if ((iPtr->flags & _IFLAG_AA) && _IFIELD_AA(* binInst))
        {
#if	defined(HOST)
	strcat (pString, "a");
	sum++;
#else	/* HOST */
	sum += printf ("a");
#endif	/* HOST */
	}

    return (sum);
    }

/*******************************************************************************
*
* decodeSpecial -
*/

LOCAL char * decodeSpecial
    (
    int		regNumber,
#if	defined(HOST)
    SPR		*altList,
#endif	/* HOST */
    SPR		*regList
    )
    {
    int         mule;

    if (regList == NULL)
	return NULL;

    for (mule = 0; regList[mule].code != NONE; mule ++)
	if (regList[mule].code == regNumber)
	    {
	    return (regList[mule].name);
	    }

#if	defined(HOST)
    if (altList == NULL)
	return NULL;

    for (mule = 0; altList[mule].code != NONE; mule ++)
	if (altList[mule].code == regNumber)
	    {
	    return (altList[mule].name);
	    }
#endif	/* HOST */

    /* did not find register in either list */

    return NULL;
    }

/*******************************************************************************
*
* prtArgs - print the arguments of an instruction
*/

LOCAL void prtArgs
    (
#if	defined(HOST)
    UINT32 *     pI,		/* pointer to the instruction */
    INST *	iPtr,		/* pointer to INST returned by dsmFind */
    TGT_ADDR_T	address,	/* address to print before instruction */
    VOIDFUNCPTR prtAddress,	/* routine to print addresses */
    char *	pString		/* string to write in */
#else	/* HOST */
    INSTR *     pI,		/* pointer to the instruction */
    FAST INST * iPtr,		/* pointer to INST returned by dsmFind */
    UINT32	address,	/* address to print before instruction */
    VOIDFUNCPTR prtAddress	/* routine to print addresses */
#endif	/* HOST */
    )
    {
    char *sprName;

/*
 * XXX - HACK to handle format warning problem:  on the host, *pI is a
 * XXX - UINT32 which is an (unsigned int), but on the target it is an
 * XXX - INSTR which is an (unsigned long).  INSN is set up to be an
 * XXX - (unsigned int) on either.  Similarly, address is a TGT_ADDR_T
 * XXX - (unsigned long) on the host but a UINT32 (unsigned int) on the
 * XXX - target; INSN_ADDR is always an (unsigned int).  We can get by
 * XXX - with this sort of shenanigans because, in fact, both (int) and
 * XXX - (long) are the same size on all platforms of interest.
 */
#if	defined(HOST)
#define	INSN	(* pI)
#define	INSN_ADDR	((unsigned int)address)
#else	/* HOST */
#define	INSN	((unsigned int)* pI)
#define	INSN_ADDR	address
#endif	/* HOST */

    switch (iPtr->form)
	{
        case _IFORM_I_1:
            if (_IFIELD_AA(INSN))
#if	defined(HOST)
                (* prtAddress) (_IFIELD_LI(INSN), pString); /* abs address */
#else	/* HOST */
		(* prtAddress) (_IFIELD_LI(INSN));      /* absolute address */
#endif	/* HOST */
            else
		{
		/*
		 * Relative branch:  show target address
		 * in hex as well as symbolically.
		 */
		PRINT "0x%x # ", _IFIELD_LI(INSN) + INSN_ADDR);
#if	defined(HOST)
                (* prtAddress) (_IFIELD_LI(INSN) + INSN_ADDR, pString);
#else	/* HOST */
		(* prtAddress) (_IFIELD_LI(INSN) + INSN_ADDR);
#endif	/* HOST */
		}
            break;

        case _IFORM_B_1:
            PRINT "0x%x,%d, ", _IFIELD_BO(INSN), _IFIELD_BI(INSN));

            if (_IFIELD_AA(INSN))
#if	defined(HOST)
                (* prtAddress) (_IFIELD_BD(INSN), pString);  /* abs address */
#else	/* HOST */
		(* prtAddress) (_IFIELD_BD(INSN));      /* absolute address */
#endif	/* HOST */
            else
		{
		/*
		 * Relative branch:  show target address
		 * in hex as well as symbolically.
		 */
		PRINT "0x%x # ", _IFIELD_BD(INSN) + INSN_ADDR);
#if	defined(HOST)
                (* prtAddress) (_IFIELD_BD(INSN) + INSN_ADDR, pString);
#else	/* HOST */
		(* prtAddress) (_IFIELD_BD(INSN) + INSN_ADDR);
#endif	/* HOST */
		}
            break;

	case _IFORM_SC_1:
	case _IFORM_X_23:
	case _IFORM_XL_4:
	case _IFORM_X_38:
	    break;

	case _IFORM_D_1:
	    PRINT "r%d,%d(r%d)", _IFIELD_RD(INSN), _IFIELD_D_S(INSN),
                    _IFIELD_RA(INSN));
	    break;

	case _IFORM_D_2:
	    PRINT "r%d,r%d,0x%x # %d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
		    _IFIELD_SIMM(INSN), _IFIELD_SIMM_S(INSN));
	    break;

	case _IFORM_D_3:
	    PRINT "r%d,%d(r%d)", _IFIELD_RS(INSN), _IFIELD_D_S(INSN),
                    (int ) ((unsigned short) _IFIELD_RA(INSN)));
	    break;

	case _IFORM_D_4:
	    PRINT "r%d,r%d,0x%x", _IFIELD_RA(INSN), _IFIELD_RS(INSN),
                    _IFIELD_UIMM(INSN));
            break;

	case _IFORM_D_5:
	    PRINT "crf%d,%d,r%d,0x%x # %d", _IFIELD_CRFD(INSN),
                    _IFIELD_L(INSN), _IFIELD_RA(INSN), _IFIELD_SIMM(INSN),
		    _IFIELD_SIMM_S(INSN));
            break;

	case _IFORM_D_6:
	    PRINT "crf%d,%d,r%d,0x%x # %d", _IFIELD_CRFD(INSN),
                    _IFIELD_L(INSN), _IFIELD_RA(INSN), _IFIELD_UIMM(INSN),
		    _IFIELD_UIMM(INSN));
            break;

	case _IFORM_D_7:
	    PRINT "0x%x,r%d,0x%x # %d", _IFIELD_TO(INSN),
		    _IFIELD_RA(INSN), _IFIELD_SIMM(INSN), _IFIELD_SIMM_S(INSN));
            break;

	case _IFORM_D_8:
	    PRINT "fr%d,%d(r%d)", _IFIELD_FRS(INSN),
		    _IFIELD_D_S(INSN), _IFIELD_RA(INSN));
            break;

	case _IFORM_D_9:
	    PRINT "r%d,0x%x # %d", _IFIELD_RD(INSN),
		     _IFIELD_SIMM(INSN), _IFIELD_SIMM_S(INSN));
	    break;

	case _IFORM_X_1:
	case _IFORM_XO_1:
	case _IFORM_XO_2:
	    PRINT "r%d,r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
                    _IFIELD_RB(INSN));
            break;

	case _IFORM_X_2:
	    PRINT "r%d", _IFIELD_RB(INSN));
            break;

	case _IFORM_X_3:
	    PRINT "r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RB(INSN));
            break;

	case _IFORM_X_4:
	    PRINT "fr%d,fr%d", _IFIELD_FRD(INSN), _IFIELD_FRB(INSN));
            break;

	case _IFORM_X_5:
	    PRINT "r%d", _IFIELD_RD(INSN));
            break;

	case _IFORM_X_6:
	    PRINT "fr%d", _IFIELD_FRD(INSN));
            break;

	case _IFORM_X_7:
	    PRINT "r%d,%d", _IFIELD_RD(INSN), _IFIELD_SR(INSN));
            break;

	case _IFORM_X_8:
	    PRINT "r%d,r%d,r%d", _IFIELD_RA(INSN), _IFIELD_RS(INSN),
                    _IFIELD_RB(INSN));
            break;

	case _IFORM_X_9:
	case _IFORM_X_10:
	    PRINT "r%d,r%d,r%d", _IFIELD_RS(INSN), _IFIELD_RA(INSN),
                    _IFIELD_RB(INSN));
            break;

	case _IFORM_X_11:
	    PRINT "r%d,r%d", _IFIELD_RA(INSN), _IFIELD_RS(INSN));
            break;

	case _IFORM_X_12:
	    PRINT "r%d,r%d", _IFIELD_RS(INSN), _IFIELD_RB(INSN));
            break;

	case _IFORM_X_13:
	    PRINT "r%d", _IFIELD_RS(INSN));
            break;

	case _IFORM_X_14:
	    PRINT "%d,r%d", _IFIELD_SR(INSN), _IFIELD_RS(INSN));
            break;

	case _IFORM_X_15:
	    PRINT "r%d,r%d,%d", _IFIELD_RA(INSN), _IFIELD_RS(INSN),
                    _IFIELD_SH(INSN));
            break;

	case _IFORM_X_16:
	    PRINT "crf%d,%d,r%d,r%d", _IFIELD_CRFD(INSN), _IFIELD_L(INSN),
		    _IFIELD_RA(INSN), _IFIELD_RB(INSN));
            break;

	case _IFORM_X_17:
	    PRINT "crf%d,fr%d,fr%d", _IFIELD_CRFD(INSN), _IFIELD_FRA(INSN),
		    _IFIELD_FRB(INSN));
            break;

	case _IFORM_X_18:
	    PRINT "crf%d,crf%d", _IFIELD_CRFD(INSN), _IFIELD_CRFS(INSN));
            break;

	case _IFORM_X_19:
	    PRINT "crf%d", _IFIELD_CRFD(INSN));
            break;

	case _IFORM_X_20:
	    PRINT "crf%d,0x%x", _IFIELD_CRFD(INSN), _IFIELD_IMM(INSN));
            break;

	case _IFORM_X_21:
	    PRINT "0x%x,r%d,r%d # %d", _IFIELD_TO(INSN), _IFIELD_RA(INSN),
                    _IFIELD_RB(INSN), _IFIELD_TO(INSN));
            break;

	case _IFORM_X_22:
	    PRINT "r%d,r%d", _IFIELD_RA(INSN), _IFIELD_RB(INSN));
            break;

	case _IFORM_X_24:
	    PRINT "fr%d,r%d,r%d", _IFIELD_FRS(INSN), _IFIELD_RA(INSN),
		    _IFIELD_RB(INSN));
            break;

	case _IFORM_X_25:
	    PRINT "crb%d", _IFIELD_CRBD(INSN));
            break;

	case _IFORM_X_26:
	    PRINT "r%d,r%d,%d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
                    _IFIELD_NB(INSN));
            break;

	case _IFORM_X_27:
	    PRINT "r%d,r%d,%d", _IFIELD_RS(INSN), _IFIELD_RA(INSN),
                    _IFIELD_NB(INSN));
            break;

	case _IFORM_XL_1:
            PRINT "0x%x,%d", _IFIELD_BO(INSN), _IFIELD_BI(INSN));
            break;

	case _IFORM_XL_2:
	    PRINT "crb%d,crb%d,crb%d", _IFIELD_CRBD(INSN),
                    _IFIELD_CRBA(INSN), _IFIELD_CRBB(INSN));
            break;

	case _IFORM_XL_3:
	    PRINT "crf%d,crf%d", _IFIELD_CRFD(INSN), _IFIELD_CRFS(INSN));
            break;

        case _IFORM_XFX_1: /* mfspr */
	case _IFORM_XFX_3: /* mftb */
#if	defined(HOST)
	    sprName = decodeSpecial (_IFIELD_SPR(INSN), altSpr, spr);
#else	/* HOST */
	    sprName = decodeSpecial (_IFIELD_SPR(INSN), spr);
#endif	/* HOST */
	    if (sprName)
		PRINT "r%d,%s", _IFIELD_RD(INSN), sprName);
	    else
		PRINT "r%d,%d", _IFIELD_RD(INSN), _IFIELD_SPR(INSN));
            break;

	case _IFORM_XFX_2:
	    PRINT "0x%x,r%d", _IFIELD_CRM(INSN), _IFIELD_RS(INSN));
            break;

       case _IFORM_XFX_4:
#if	defined(HOST)
	    sprName = decodeSpecial (_IFIELD_SPR(INSN), altSpr, spr);
#else	/* HOST */
	    sprName = decodeSpecial (_IFIELD_SPR(INSN), spr);
#endif	/* HOST */
	    if (sprName)
		PRINT "%s,r%d", sprName, _IFIELD_RS(INSN));
	    else
		PRINT "%d,r%d", _IFIELD_SPR(INSN), _IFIELD_RS(INSN));
            break;

	case _IFORM_XFL_1:
	    PRINT "0x%x,fr%d", _IFIELD_FM(INSN), _IFIELD_FRB(INSN));
            break;

	case _IFORM_XO_3:
	    PRINT "r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RA(INSN));
            break;

	case _IFORM_A_1:
	    PRINT "fr%d,fr%d,fr%d", _IFIELD_FRD(INSN), _IFIELD_FRA(INSN),
		    _IFIELD_FRB(INSN));
            break;

	case _IFORM_A_2:
	    PRINT "fr%d,fr%d,fr%d,fr%d", _IFIELD_FRD(INSN),
                    _IFIELD_FRA(INSN), _IFIELD_FRC(INSN), _IFIELD_FRB(INSN));
            break;

	case _IFORM_A_3:
	    PRINT "fr%d,fr%d,fr%d", _IFIELD_FRD(INSN), _IFIELD_FRA(INSN),
		    _IFIELD_FRC(INSN));
            break;

	case _IFORM_A_4:
	    PRINT "fr%d,fr%d", _IFIELD_FRD(INSN), _IFIELD_FRB(INSN));
            break;

	case _IFORM_M_1:
	    PRINT "r%d,r%d,%d,%d,%d", _IFIELD_RA(INSN), _IFIELD_RS(INSN),
		    _IFIELD_SH(INSN), _IFIELD_MB(INSN), _IFIELD_ME(INSN));
            break;

	case _IFORM_M_2:
	    PRINT "r%d,r%d,r%d,%d,%d", _IFIELD_RA(INSN), _IFIELD_RS(INSN),
		    _IFIELD_RB(INSN), _IFIELD_MB(INSN), _IFIELD_ME(INSN));
            break;

#if	(defined(HOST) || (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) || (CPU==PPC440))

	case _IFORM_400_1:			/* mfdcr */
#if	defined(HOST)
	    /* Only 403 has host-decodable DCR's */
	    if (targetCpuType == PPC403
	     && (sprName = decodeSpecial (_IFIELD_SPR(INSN), NULL, dcr)))
#else	/* HOST */
	    if ((sprName = decodeSpecial (_IFIELD_SPR(INSN), dcr)))
#endif	/* HOST */
		PRINT "r%d,%s", _IFIELD_RD(INSN), sprName);
	    else
		PRINT "r%d,%d", _IFIELD_RD(INSN), _IFIELD_SPR(INSN));
	    break;

	case _IFORM_400_2:			/* mtdcr */
#if	defined(HOST)
	    /* Only 403 has host-decodable DCR's */
	    if (targetCpuType == PPC403
	     && (sprName = decodeSpecial (_IFIELD_SPR(INSN), NULL, dcr)))
#else	/* HOST */
	    if ((sprName = decodeSpecial (_IFIELD_SPR(INSN), dcr)))
#endif	/* HOST */
		PRINT "%s,r%d", sprName, _IFIELD_RS(INSN));
	    else
		PRINT "%d,r%d", _IFIELD_SPR(INSN), _IFIELD_RS(INSN));
	    break;

	case _IFORM_400_3:			/* wrteei */
	    if ((INSN) & (1 << 15))
#if	defined(HOST)
		strcat (pString, "1");
#else	/* HOST */
		printf ("1");
#endif	/* HOST */
	    else
#if	defined(HOST)
		strcat (pString, "0");
#else	/* HOST */
		printf ("0");
#endif	/* HOST */
	    break;

#endif	/* HOST || PPC4xx */

#if	(defined(HOST) || (CPU == PPC405) || (CPU == PPC405F) || \
	 (CPU == PPC440))

        case _IFORM_405_TLB:                    /* tlbre, tlbwe */
	    PRINT "r%d,r%d,%d", _IFIELD_TO(INSN), _IFIELD_RA(INSN),
		   _IFIELD_WS(INSN));
            break;

        case _IFORM_405_SX:                     /* tlbsx */
	    PRINT "r%d,r%d,r%d", _IFIELD_TO(INSN), _IFIELD_RA(INSN),
		   _IFIELD_RB(INSN));
            break;

#endif	/* HOST || PPC405 || PPC405F || PPC440 */

	    /* Altivec support */
#if     (defined(HOST) || ((CPU == PPC604) && (_WRS_ALTIVEC_SUPPORT == TRUE)))
	case _IFORM_VA_1:
	    PRINT "v%d,v%d,v%d,v%d", _IFIELD_VD(INSN), _IFIELD_VA(INSN),
                  _IFIELD_VB(INSN), _IFIELD_VC(INSN));
	  break;
	case _IFORM_VA_1B:
	    PRINT "v%d,v%d,v%d,v%d", _IFIELD_VD(INSN), _IFIELD_VA(INSN),
                  _IFIELD_VC(INSN), _IFIELD_VB(INSN));
	  break;
	case _IFORM_VA_2:
	    PRINT "v%d,v%d,v%d,%d", _IFIELD_VD(INSN), _IFIELD_VA(INSN),
		  _IFIELD_VB(INSN), _IFIELD_VSH(INSN));
	  break;
	case _IFORM_VX_1:
	    PRINT "v%d,v%d,v%d", _IFIELD_VD(INSN), _IFIELD_VA(INSN),
		  _IFIELD_VB(INSN));
	  break;
	case _IFORM_VX_2:
	    PRINT "v%d", _IFIELD_VD(INSN));
	  break;
	case _IFORM_VX_3:
	    PRINT "v%d", _IFIELD_VB(INSN));
	  break;  
	case _IFORM_VX_4:
	    PRINT "v%d,v%d", _IFIELD_VD(INSN), _IFIELD_VB(INSN));
	  break;
	case _IFORM_VX_5:
	    PRINT "v%d,v%d,%d", _IFIELD_VD(INSN), _IFIELD_VB(INSN),
		  _IFIELD_VUIMM(INSN));
	  break;
	case _IFORM_VX_6:
	    PRINT "v%d,%d", _IFIELD_VD(INSN), _IFIELD_VSIMM(INSN));
	  break;

	case _IFORM_X_28:
	    PRINT "v%d,r%d,r%d", _IFIELD_VD(INSN), _IFIELD_VA(INSN),
		  _IFIELD_VB(INSN));
	  break;
	case _IFORM_X_29:
	    PRINT "v%d,r%d,r%d", _IFIELD_VS(INSN), _IFIELD_VA(INSN),
		  _IFIELD_VB(INSN));
	  break;
	case _IFORM_X_30:
	case _IFORM_X_31:
	    PRINT "r%d,r%d,%d", _IFIELD_VA(INSN), _IFIELD_VB(INSN),
		  _IFIELD_STRM(INSN));
	  break;
	case _IFORM_X_32:
	case _IFORM_X_33:
	    PRINT "%d", _IFIELD_STRM(INSN));
	  break;
	case _IFORM_VXR_1:
	    PRINT "v%d,v%d,v%d", _IFIELD_VD(INSN), _IFIELD_VA(INSN),
		  _IFIELD_VB(INSN));
	  break;
#endif /* HOST || (CPU==PPC604 && _WRS_ALTIVEC_SUPPORT == TRUE) */

#if	(defined(HOST) || defined(PPC_440x5) || (CPU == PPC85XX))
	case _IFORM_M_3:
	    PRINT "r%d,r%d,r%d,0x%x # %d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
		    _IFIELD_RB(INSN), _IFIELD_MB(INSN), _IFIELD_MB(INSN));
            break;
#endif	/* HOST || PPC_440x5 || PPC85XX */

#if	(defined(HOST) || (CPU == PPC85XX))
	case _IFORM_EVS_1:
	    PRINT "r%d,r%d,r%d,crf%d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
		    _IFIELD_RB(INSN), _IFIELD_CRFE(INSN));
            break;
	case _IFORM_X_34:
	    PRINT "%d", _IFIELD_MO(INSN));
            break;
	case _IFORM_EFX_1:
	    PRINT "r%d,r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
		   _IFIELD_RB(INSN));
            break;
	case _IFORM_EFX_2:
	    PRINT "r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RB(INSN));
            break;
	case _IFORM_EFX_3:
	    PRINT "r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RA(INSN));
            break;
	case _IFORM_EFX_4:
	    PRINT "crf%d,r%d,r%d", _IFIELD_CRFD(INSN), _IFIELD_RA(INSN),
		   _IFIELD_RB(INSN));
            break;
	case _IFORM_EVX_1:
	    PRINT "r%d,r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
		   _IFIELD_RB(INSN));
            break;
	case _IFORM_EVX_2:
	    PRINT "r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RB(INSN));
            break;
	case _IFORM_EVX_3:
	    PRINT "r%d,r%d", _IFIELD_RD(INSN), _IFIELD_RA(INSN));
            break;
	case _IFORM_EVX_4:
	    PRINT "r%d,r%d,0x%x # %d", _IFIELD_RD(INSN), _IFIELD_RB(INSN),
		   _IFIELD_RA(INSN), _IFIELD_VUIMM(INSN));
            break;
	case _IFORM_EVX_5:
	    PRINT "r%d,r%d,0x%x # %d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
		   _IFIELD_RB(INSN), _IFIELD_RB(INSN));
            break;
	case _IFORM_EVX_6:
	    PRINT "crf%d,r%d,r%d", _IFIELD_CRFD(INSN), _IFIELD_RA(INSN),
		   _IFIELD_RB(INSN));
            break;
	case _IFORM_EVX_7:
	    PRINT "r%d,0x%x # %d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
		   _IFIELD_VSIMM(INSN));
            break;
	case _IFORM_EVX_8:
	    PRINT "r%d,r%d,r%d", _IFIELD_RS(INSN), _IFIELD_RA(INSN),
		   _IFIELD_RB(INSN));
            break;
	case _IFORM_EVX_9:
	    PRINT "r%d,%d(r%d)", _IFIELD_RS(INSN), _IFIELD_RB(INSN)*8,
		   _IFIELD_RA(INSN));
            break;
	case _IFORM_EVX_10:
	    PRINT "r%d,%d(r%d)", _IFIELD_RS(INSN), _IFIELD_RB(INSN)*4,
		   _IFIELD_RA(INSN));
            break;
	case _IFORM_EVX_11:
	    PRINT "r%d,%d(r%d)", _IFIELD_RD(INSN), _IFIELD_RB(INSN)*8,
		   _IFIELD_RA(INSN));
            break;
	case _IFORM_EVX_12:
	    PRINT "r%d,%d(r%d)", _IFIELD_RD(INSN), _IFIELD_RB(INSN)*2,
		   _IFIELD_RA(INSN));
            break;
	case _IFORM_EVX_13:
	    PRINT "r%d,%d(r%d)", _IFIELD_RD(INSN), _IFIELD_RB(INSN)*4,
		   _IFIELD_RA(INSN));
            break;
	case _IFORM_EVX_14:
	    PRINT "r%d,0x%x,r%d # %d", _IFIELD_RD(INSN), _IFIELD_RA(INSN),
		   _IFIELD_RB(INSN), _IFIELD_VUIMM(INSN));
            break;
        case _IFORM_XFX_5:                      /* mfpmr */
#if     defined(HOST)
            if (targetCpuType == PPC85XX
             && (sprName = decodeSpecial (_IFIELD_SPR(INSN), NULL, pmr)))
#else   /* HOST */
            if ((sprName = decodeSpecial (_IFIELD_SPR(INSN), pmr)) != NULL)
#endif  /* HOST */
                PRINT "r%d,%s", _IFIELD_RD(INSN), sprName);
            else
                PRINT "r%d,%d", _IFIELD_RD(INSN), _IFIELD_SPR(INSN));
            break;

        case _IFORM_XFX_6:                      /* mtpmr */
#if     defined(HOST)
            if (targetCpuType == PPC85XX
             && (sprName = decodeSpecial (_IFIELD_SPR(INSN), NULL, pmr)))
#else   /* HOST */
            if ((sprName = decodeSpecial (_IFIELD_SPR(INSN), pmr)) != NULL)
#endif  /* HOST */
                PRINT "%s,r%d", sprName, _IFIELD_RS(INSN));
            else
                PRINT "%d,r%d", _IFIELD_SPR(INSN), _IFIELD_RS(INSN));
            break;
	case _IFORM_X_35:
	    PRINT "%d", _IFIELD_EE(INSN));
            break;
	case _IFORM_X_36:
	    PRINT "r%d,r%d", _IFIELD_RA(INSN), _IFIELD_RB(INSN));
            break;
	case _IFORM_X_37:
	    PRINT "r%d,r%d", _IFIELD_RA(INSN), _IFIELD_RB(INSN));
            break;

#endif	/* HOST || PPC85XX */

        default:	/* should never get here! */
	    PRINT "????");
	    break;
	}
#if	(!defined(HOST))
    printf ("\n");
#endif	/* HOST */
    }

/*******************************************************************************
*
* dsmPrint - print a disassembled instruction
*
* This routine prints an instruction in disassembled form.  It takes
* as input a pointer to the instruction, a pointer to the INST that
* describes it (as found by dsmFind()), an address with which to prepend
* the instruction, and a function to print operands which are addresses.
* On the host, the appendAddr and appendOpcodes parameters control whether
* the address, and the hex content of the instruction, are to be included
* in the returned string.
*/

LOCAL void dsmPrint
    (
#if	defined(HOST)
    UINT32 *	binInst,	/* pointer to the instruction                */
    INST *	iPtr,		/* pointer to INST returned by dsmFind       */
    TGT_ADDR_T	address,	/* address to print before instruction       */
    VOIDFUNCPTR	prtAddress,	/* address printing function                 */
    char *	pString,	/* string to write in                        */
    BOOL32	appendAddr,	/* TRUE to append insts' addresses           */
    BOOL32	appendOpcodes	/* TRUE to append insts' opcodes             */
#else	/* HOST */
    INSTR *     binInst,    /* pointer to the instruction                */
    FAST INST * iPtr,       /* pointer to INST returned by dsmFind       */
    UINT32	address,    /* address to print before instruction       */
    VOIDFUNCPTR prtAddress  /* address printing function                 */
#endif	/* HOST */
    )
    {
    int		outCount = 0;
#if	defined(HOST)
    UINT32      instr = upbinInst (*binInst);
#endif	/* HOST */

    /* print the address and the instruction, in hex */

#if	defined(HOST)
    strcpy (pString, "{");
    if (appendAddr)
	{
        PRINT "%08x", (unsigned int) address);
	}
    strcat (pString, "} {");
    if (appendOpcodes)
	{
        PRINT "%08x", instr);
	}
    strcat (pString, "} {");
#else	/* HOST */
    printf ("%#06x  ", address);
    printf ("%08lx    ", *binInst );
#endif	/* HOST */

    if (iPtr == NULL)
        {
#if	defined(HOST)
        PRINT ".long       0x%08x}", instr);
#else	/* HOST */
	printf (".long       %08lx\n", binInst[0]);
#endif	/* HOST */
        return;
        }

    /* XXX check for simplified mnemonic */

    /* print the instruction mnemonic */

#if	defined(HOST)
    strcat (pString, iPtr->name);
    outCount += strlen (iPtr->name);
    outCount += dsmSuffixPrint (&instr, iPtr, pString);
#else	/* HOST */
    outCount += printf ("%s", iPtr->name);
    outCount += dsmSuffixPrint (binInst, iPtr);
#endif	/* HOST */

    while (outCount ++ < 12)
#if	defined(HOST)
        strcat (pString, " ");		/* space over to arg column  */
#else	/* HOST */
	printf (" ");		/* space over to arg column  */
#endif	/* HOST */

    /* print the arguments */

#if	defined(HOST)
    prtArgs (&instr, iPtr, address, prtAddress, pString);
    strcat (pString, "}");
#else	/* HOST */
    prtArgs (binInst, iPtr, address, prtAddress);
#endif	/* HOST */
    }

/*******************************************************************************
*
* dsmPpcInstGet - disassemble and print a single instruction (target server)
* dsmInst - disassemble and print a single instruction (target shell)
*
* This routine disassembles and prints a single instruction on standard
* output.  The function passed as parameter <prtAddress> is used to print any
* operands that might be construed as addresses.  The function could be a
* subroutine that prints a number or looks up the address in a symbol table.
* The disassembled instruction will be prepended with the address passed as
* a parameter.
*
* If <prtAddress> is zero, this function will use a default routine that 
* prints addresses as hex numbers.
*
* ADDRESS-PRINTING ROUTINE
* Many assembly language operands are addresses.  In order to print these
* addresses symbolically, this function calls a user-supplied routine, passed 
* as a parameter, to do the actual printing.  The routine should be declared as:
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
* If the <prtAddress> argument is NULL, a default print routine is used,
* which prints the address as a hexadecimal number.
*
* The directive DC.W (declare word) is printed for unrecognized instructions.
*
* RETURNS: The number of 32-bit words occupied by the instruction (always 1).
*/

#if	defined(HOST)
int dsmPpcInstGet
#else	/* HOST */
int dsmInst
#endif	/* HOST */
    (
#if	defined(HOST)
    UINT32 *		binInst,	/* pointer to the inst.              */
    int 		endian,        	/* endian of data in buffer          */
    TGT_ADDR_T		address,	/* address prepended to inst.        */
    VOIDFUNCPTR	 	prtAddress,	/* address printing function         */
    char *		pString,	/* string to write in                */
    BOOL32		printAddr,	/* if addresses are appened          */
    BOOL32		printOpcodes	/* if opcodes are appened            */
#else	/* HOST */
    INSTR *	binInst,       /* pointer to the instruction       */
    UINT32	address,       /* address prepended to instruction */
    VOIDFUNCPTR prtAddress     /* address printing function        */
#endif	/* HOST */
    )
    {
#if	defined(HOST)
    INST *	iPtr;
    WTX_TGT_INFO *pWtxTgtInfo;
#else	/* HOST */
    FAST INST *iPtr;
#endif	/* HOST */

    if (prtAddress == NULL)
        prtAddress = nPrtAddress;

#if	defined(HOST)

    /* Set altSpr and targetInstFlags according to the attached target */

    targetInstFlags = 0;
    if ((pWtxTgtInfo = tgtInfoGet()) == NULL)
	{
	targetCpuType = 0;
	targetCoProc = 0;
	}
    else
	{
	targetCpuType = pWtxTgtInfo->rtInfo.cpuType;
	targetCoProc  = pWtxTgtInfo->rtInfo.hasCoprocessor;
	if ( targetCoProc & WTX_FPP_MASK )
	    targetInstFlags |= _IFLAG_FP_SPEC;
	if ( targetCoProc & WTX_ALTIVEC_MASK )
	    targetInstFlags |= _IFLAG_AV_SPEC;
	if ( targetCoProc & WTX_SPE_MASK )
	    targetInstFlags |= _IFLAG_E500_SPEC;
	}

    switch (targetCpuType)
	{
	case PPC403:
	    targetInstFlags |= _IFLAG_403_SPEC;
	    altSpr = spr403;
	    break;

	case PPC405F:
	    targetInstFlags |= _IFLAG_FP_SPEC;
	case PPC405:
	    targetInstFlags |= _IFLAG_405_SPEC;
	    altSpr = spr405;
	    break;

	case PPC440:
	    targetInstFlags |= _IFLAG_440_SPEC;
	    altSpr = spr440;
	    break;

	case PPC509:
	    altSpr = spr509;
	    break;

	case PPC555:
	    altSpr = spr555;
	    break;

	case PPC601:
	    targetInstFlags |= _IFLAG_601_SPEC;
	    altSpr = spr601;
	    break;

	case PPC603:
	    targetInstFlags |= _IFLAG_FP_SPEC;
	case PPCEC603:
	    targetInstFlags |= _IFLAG_603_SPEC;
	    altSpr = spr603;
	    break;

	case PPC604:
	    targetInstFlags |= _IFLAG_604_SPEC;
	    altSpr = spr604;
	    break;

	case PPC85XX:
	    targetInstFlags |= _IFLAG_E500_SPEC;
	    altSpr = spr85xx;
	    break;

	default:
	    altSpr = NULL;
	}

    iPtr = dsmFind (binInst);

    dsmPrint (binInst, iPtr, address, prtAddress, pString, printAddr,
	      printOpcodes);

#else	/* HOST */

    iPtr = dsmFind (binInst);

    dsmPrint (binInst, iPtr, address, prtAddress);

#endif	/* HOST */

    return (1);
    }

#if	defined(HOST)
/*****************************************************************************
*
* dsmPpcInstSizeGet - determine the size of an instruction
*
* This routine determines the size, in bytes, of an instruction.
* It returns a constant, 4, and is preserved for
* compatibility with the 680x0 version.
*
* * RETURNS:
* A constant (4)
*/

int dsmPpcInstSizeGet 
    (
    UINT32 *	binInst,		/* pointer to the instruction */
    int 	endian	         	/* endian of data in buffer */
    )
    {
    return (4);
    }
#endif	/* HOST */
