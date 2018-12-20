/* vxALib.s - miscellaneous assembly language routines */

/* Copyright 1995-2000 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01s,07sep01,h_k  added power control support (SPR #69838).
01r,31aug00,hk   add .size directive to vxMemProbeIntStubSize. reorder funcs.
01q,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
01p,20apr00,hk   moved in vxMemProbeSup from vxLib. changed vxMemProbeTrap to
                 modify r0 instead of vxBerrStatus. added vxMemProbeIntStub.
01o,10apr00,hk   got rid of .ptext section: modified vxMemProbeTrap as
                 a VBR-relative code in P1/P2.
01n,28mar00,hk   added .type directive to function names.
01m,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01l,08jun99,zl   added .ptext attribute "ax"
01k,12may98,jmc  added support for SH-DSP and SH3-DSP.
01k,09nov98,hk   changed vxMemProbeTrap() for SH7700 to work with new intStub.
01k,16jul98,st   added SH7750 support.
01j,25apr97,hk   changed SH704X to SH7040.
01i,03mar97,hk   changed vxMemProbeTrap() for SH7700 to call intExit. also
                 changed to call sysBErrIntAck() for interrupt acknowledge.
01h,17feb97,hk   fixed vxMemProbeTrap() to skip INTEVT on stack for SH7700.
01g,22dec96,hk   added r7-r4 restoration in _vxMemProbeTrap.
01f,18dec96,hk   moved vxMemProbeTrap to .ptext section.
01e,09dec96,wt+hk changed vxMemProbeTrap for new intStub design.
01d,01oct96,hk   fixed _vxMemProbeTrap for SH7700 to avoid possible r0
		 corruption in non-nested case. also reviewed code/docs.
01c,17sep96,hk   rewrote _vxMemProbeTrap for SH7700.
01b,09jun95,hk   moved in vxTas() from vxLib.
01a,08jun95,hk   written based on mc68k-01q.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines.

SEE ALSO: vxLib
*/

#define _ASMLANGUAGE

#include "vxWorks.h"
#include "asm.h"
#include "iv.h"


	.text

	.global	_vxTas
	.global	_vxMemProbeSup
	.global	_vxMemProbeTrap
#if (CPU==SH7750 || CPU==SH7700)
	.global	_vxMemProbeIntStub
	.global	_vxMemProbeIntStubSize
#endif
	.global	_vxPowerDown

	.extern	_vxPowMgtEnable			/* power management status */

/*******************************************************************************
*
* vxTas - C-callable atomic test-and-set primitive
*
* This routine provides a C-callable interface to the SH test-and-set
* instruction.  The "tas.b" instruction is executed on the specified
* address.
*
* RETURNS:      TRUE (1) if the value had not been set, but now is;
*               FALSE (0) if the value was already set.

* BOOL vxTas
*     (
*     void * address	/@ address to be tested and set @/
*     )

*/
	.align	_ALIGN_TEXT
	.type	_vxTas,@function

_vxTas:
	tas.b	@r4
	rts;
	movt	r0

/******************************************************************************
*
* vxMemProbeSup - vxMemProbe support routine
*
* This routine is called to try to copy byte, word, or long, as specified
* by length, from the specified source to the specified destination.
*
* RETURNS:
* OK if the probe is successful, or ERROR if the probe caused a bus error.

* STATUS vxMemProbeSup
*     (
*     int	length,	/@ length of cell to test (1, 2, 4) @/
*     char *	src,	/@ address to read                  @/
*     char *	dst	/@ address to write                 @/
*     )

*/
	.align	_ALIGN_TEXT
	.type	_vxMemProbeSup,@function

_vxMemProbeSup:
	mov	r4,r0
	cmp/eq	#1,r0			/* if      (length == 1) */
	bt	.vxByte			/*     goto .vxByte      */
	cmp/eq	#2,r0			/* else if (length == 2) */
	bt	.vxWord			/*     goto .vxWord      */
	cmp/eq	#4,r0			/* else if (length == 4) */
	bt	.vxLong			/*     goto .vxLong      */
.vxErr:
	rts;				/* else                  */
	mov	#-1,r0			/*     return ERROR;     */

.vxByte:
	mov	#0,r0			/* r0: OK */
	mov.b	@r5,r1
	mov.b	r1,@r6			/* *(char *)dst = *(char *)src; */
	bra	.vxExit;
	nop

.vxWord:
	mov	r5,r0
	tst	#1,r0			/* if (src & 0x1)      */
	bf	.vxErr			/*     goto .vxErr     */
	mov	r6,r0
	tst	#1,r0			/* else if (dst & 0x1) */
	bf	.vxErr			/*     goto .vxErr     */

	mov	#0,r0			/* r0: OK */
	mov.w	@r5,r1
	mov.w	r1,@r6			/* *(USHORT *)dst = *(USHORT *)src; */
	bra	.vxExit;
	nop

.vxLong:
	mov	r5,r0
	tst	#3,r0			/* if (src & 0x3)      */
	bf	.vxErr			/*     goto .vxErr     */
	mov	r6,r0
	tst	#3,r0			/* else if (dst & 0x3) */
	bf	.vxErr			/*     goto .vxErr     */

	mov	#0,r0			/* r0: OK */
	mov.l	@r5,r1
	mov.l	r1,@r6			/* *(ULONG *)dst = *(ULONG *)src; */

.vxExit:
	nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;
	nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;
	nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;
	nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;
	rts;
	nop				/* safety net to catch interrupt */


#if (CPU==SH7600 || CPU==SH7000)
/******************************************************************************
*
* vxMemProbeTrap - vxMemProbe support routine (SH7600/SH7000)
*
* This entry point is momentarily attached to the bus error interrupt vector.
* It simply sets r0 to ERROR to indicate that the bus error did occur, and
* returns from the interrupt.
*
* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.type	_vxMemProbeTrap,@function

_vxMemProbeTrap:		/* we get here via the bus error trap */
	rte;
	mov	#-1,r0

#elif (CPU==SH7750 || CPU==SH7700)
/******************************************************************************
*
* vxMemProbeTrap - vxMemProbe support routine (SH7750/SH7700)
*
* This routine is called from excStub, with parameters passed by r4, r5, and
* r6.  A stack frame shown below is constructed by excStub, so this routine
* sets r0 on stack to ERROR to indicate that a MMU exception did occur, also
* modifies spc on stack to skip an instruction that got exception, and returns
* to excStub.  Then the modified stack frame will be restored by excStub.
*
* NOMANUAL
*
*               |_____________|     +60       __________
*               |TRA/TEA/FPSCR| 96  +56  +12         ^
*               |   EXPEVT    | 92  +52  +8   _____  | ESFSH
*               |     ssr     | 88  +48  +4     ^    |
*       r5 ---> |     spc     | 84  +44  +0     | ___v__
*               |     r15     | 80  +40         |
*               |     r14     | 76  +36         |
*               |     r13     | 72  +32         |
*               |     r12     | 68  +28         |
*               |     r11     | 64  +24         |
*               |     r10     | 60  +20         |
*               |     r9      | 56  +16         |
*               |     r8      | 52  +12         |
*               |    macl     | 48  +8          |
*               |    mach     | 44  +4     REG_SET
*               |     r7      | 40  +0          |
*               |     r6      | 36              |
*               |     r5      | 32              |
*               |     r4      | 28              |
*               |     r3      | 24              |               +--------+
*               |     r2      | 20              |            r6 |REG_SET*|
*               |     r1      | 16              |               +--------+
*               |     r0      | 12              |            r5 | ESFSH *|
*               |     pr      |  8              |               +--------+
*               |     gbr     |  4              |            r4 |  INUM  |
*       r6 ---> |____ vbr ____|  0    __________v__             +--------+
*               |             |
*/
	.align	_ALIGN_TEXT
	.type	_vxMemProbeTrap,@function

_vxMemProbeTrap:		/* we get here via the bus error trap */
	mov	#-1,r0
	mov.l	r0,@(12,r6)	/* modify _vxMemProbeSup return val to ERROR */

	mov.l	@r5,r0		/* exception address in _vxMemProbeSup */
	add	#2,r0		/* skip 'mov.{b,w,l}' which caused exception */
	rts;			/* return to excStub */
	mov.l	r0,@r5		/* modify spc on stack */

/******************************************************************************
*
* vxMemProbeIntStub - vxMemProbe support routine (SH7750/SH7700)
*
* This routine is copied to (VBR + SH7700_MEMPROBE_INT_STUB_OFFSET), and
* the entry point is momentarily attached to the bus error interrupt vector.
* It simply sets r0 to ERROR to indicate that the bus error did occur, and
* returns from the interrupt.  This routine assumes 0x7000?0?0 in SR, so that
* the corresponding intPrioTable[] entry should be NULL.  Also this routine
* does no interrupt acknowledge, so that the bus error interrupt has to be
* an edge-triggered type.
*
* NOMANUAL
*
*     [ task stack ]                       [ interrupt stack ]
*
*	|  aaa	|     vxIntStackBase ->	+-------+	|	|
*	|__bbb__|<----------------------|task'sp|	|_______|
*	|	|			|INTEVT	|	|INTEVT	|
*					|  ssr	|	|  ssr	|
*				  sp ->	|_ spc _|	|_ spc _|
*					|	|	|	|
*/
	.align	_ALIGN_COPY_TEXT
	.type	_vxMemProbeIntStub,@function

					/* MD=1, RB=1, BL=1, from intStub */
_vxMemProbeIntStub:
	ldc.l	@sp+,spc;		mov	#-1,r0
	ldc.l	@sp+,ssr;		ldc	r0,r0_bank

	stc	vbr,r1;
	mov.l	@(SH7700_ARE_WE_NESTED_OFFSET,r1),r0;
	rotr	r0
	bf.s	vxmIntNested;
	mov.l	r0,@(SH7700_ARE_WE_NESTED_OFFSET,r1)
	rte;
	mov.l	@(4,sp),sp	/* return to task stack */

vxmIntNested:
	rte;
	add	#4,sp		/* skip INTEVT on interrupt stack */
 
vxMemProbeIntStubEnd:
			.align	2
			.type	_vxMemProbeIntStubSize,@object
			.size	_vxMemProbeIntStubSize,4
_vxMemProbeIntStubSize:	.long	vxMemProbeIntStubEnd - _vxMemProbeIntStub

#endif /* CPU==SH7750 || CPU==SH7700 */

/*******************************************************************************
*
* vxPowerDown - turn the processor in reduced power mode
*
* This routine activates the reduced power mode if power management is enabled.
* It is called by the scheduler when the kernel enters the idle loop.
* The power management mode is selected via the routine vxPowerModeSet().
*
* RETURNS: OK, or ERROR if power management is not supported, or external
* interrupts are disabled.
*
* SEE ALSO: vxPowerModeSet(), vxPowerModeGet().
* STATUS vxPowerDown (void)
*/
	.align	_ALIGN_TEXT
	.type	_vxPowerDown,@function

_vxPowerDown:
	/* test if power management is enabled */

	mov.l	VxPowMgtEnable,r0
	mov.l	@r0,r0
	cmp/eq	#1,r0
	bf	.powerExitOk


	/* test if external interrupt are enabled */

	stc	sr,r0			/* read sr */
	and	#0xf0,r0		/* mask 4-7 bits */
	tst	r0,r0
	bt	.powerDownGo
	rts				/* returns ERROR : all interrupts */
	mov	#-1,r0			/* are not enabled. */


.powerDownGo:
	sleep

.powerExitOk:
	rts
	mov	#0,r0			/* returns OK */

	.align	2
VxPowMgtEnable:		.long	_vxPowMgtEnable
