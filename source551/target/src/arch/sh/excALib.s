/* excALib.s - exception handling SH assembly language routines */

/* Copyright 1994-2001 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
03e,10dec01,zl   added leading underscore to areWeNested.
03d,08nov01,hk   courtesies of Hans-Erik and Hitachi-Japan, added mmuPciStub.
03c,03nov01,zl   made excNonTrapa local.
03b,10sep01,zl   FPSCR exception info for _WRS_HW_FP_SUPPORT only.
03a,03sep00,hk   change excUnblock to preserve SR.DSP.
		 change small constants to use .word storage.
		 lock interrupts in excDispatch before using bank-1 registers.
		 use intBlockSR (ex-0x70000000) to block exceptions.
		 merge intLockIntSR to intLockTaskSR.
		 put together .text directives.
		 add .size directive to global constants.
02z,21aug00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
02y,20jun00,hk   fixed excStub/excIntStub/excBsrTbl for SH7600.
02x,20apr00,hk   changed sysBErrVecNum to excBErrVecNum. changed text alignment
                 to _ALIGN_COPY_TEXT, for stubs to be copied before use.
02w,10apr00,hk   got rid of .ptext section: modified excBErrStub as a VBR-
                 relative code in P1/P2. also changed intPrioTable and
                 areWeNested to VBR-relative data.  changed inter-stub
                 branches to jumps.
02v,28mar00,hk   added .type directive to function names and tables.
02u,17mar00,zl   made use of alignment macro _ALIGN_TEXT
02t,16jun99,zl   added instrunction to save EXPEVT in _excStub
02s,08jun99,zl   added .ptext attribute "ax"
02r,02mar99,hk   merged mmuStub.
02n,28may98,jmc  added support for SH-DSP and SH3-DSP.
02o,04nov98,hk   changed excBErrStub/excIntStub for new intStub design(SH7700).
02n,12may98,hk   added SH7718(SH3e) on-chip FPU exception support.
02q,08oct98,hk   improved mmuStub for SH7750. unified coding in excStub.
02p,16sep98,hk   code review: simplified CPU conditionals. unified SH7750_VEC_
                 TABLE_OFFSET to SH7700_VEC_TABLE_OFFSET.
02o,16sep98,st   deleted dummy code in mmuStub().
02n,16jul98,st   added SH7750 support.
02m,25nov97,hk   changed to use sequential interrupt number for SH7700.
02l,19jun97,hk   moved in mmuStub from mmuSh7700ALib.s.
02k,27apr97,hk   changed SH704X to SH7040.
02j,03mar97,hk   moved excTlbStub to relax code layout. merged excUnknown
                 to excSetDefault. reviewed comment.
02i,23feb97,hk   added sanity check for EXPEVT value.
02h,17feb97,hk   pushed EXPEVT on stack. deleted unused INTEVT def. fixed
                 TRA/TEA push logic for address error exception w/mmu.
                 minimized bank1 register usage. made excNonTrapa global for
                 branching from mmuStub. simplified SR.BL unblocking code.
02g,12feb97,hk   adjusted excBErrStub/excIntStub for pushed INTEVT on stack.
02f,09feb97,hk   fixed _excStub for SH7700 to handle protection exceptions.
02e,18jan97,hk   saved TRA/TEA on top of stack.
02d,03jan97,hk   added excTLBfixed.
02c,25dec96,hk   fixed comment for excStub.
02b,21dec96,hk   moved SH3 code to .ptext. excluded _excBErrStub from
                 _excStubSize. renamed AAreWeNested as AreWeNested.
02a,16dec96,hk   added wt's TLB invalid exception support code to excStub.
01z,13dec96,hk   fixed excIntStub for SH[127m] to pop errno in r1.
01y,09dec96,wt   changed excStub not to use stack while blocked, and kept
	   +hk   volatiles in bank regs. overhauled excBErrStub/excIntStub.
01x,29sep96,hk   added excBackToTaskContext to handle exception in task context.
		 fixed r0 on stack for non-nested case. changed blocking sr to
		 0x50000000 before rte. special thanks to wt for this to fix.
01w,26sep96,hk   changed cmp/eq in excUnblock to tst, to use r2 instead of r0.
01v,17sep96,hk   fixed r5 in excStub to point ESF before calling excExcHandle.
		 added bypass for BL unblocking. made regular exception to fetch
		 its handler from virtual vector table, but forced bus error to
		 call excExcHandle. noted that rte code in excStub is not used.
		 renamed excBErrExc to _excBErrStub, and made it to be directly
		 called from _intStub. added documentation to _excBErrStub.
01u,02sep96,hk   changed exception stack design and excBErrExc for SH7700.
01t,22aug96,hk   deleted bank registers from REG_SET, trying bus err exception.
01s,19aug96,hk   changed code layout. changed SH7700 excIntStub for new intStub.
01r,14aug96,hk   deleted bank switch in excStub. intPrioTable covers exception.
01q,13aug96,hk   fixed excIntStub for SH7700 to do rts.
01p,13aug96,hk   added excIntStub for SH7700.
01o,09aug96,hk   added 'trapa' handling code for SH7700. currently overlaying
		 the trap vector table to exception/interrupt virtual vectbl.
01n,08aug96,hk   deleted #include "excLib.h". changed EXPEVT to 8bit immediate.
		 also added TRA def. changed SH7700_VEC_OFFSET according to
		 new ivSh.h (01t).
01m,08aug96,hk   added notes on excStub for SH7700.
01l,04aug96,hk   changed code layout. added bank control for SH7700.
01k,29jul96,hk   changed to use 'mova', added DEBUG_LOCAL_SYMBOLS option.
01j,26jul96,ja   call excHandler via ExcVecTbl.
01i,11jul96,ja   added excStubSize: for SH7700.
01h,13jun96,hk   added excStub: for SH7700.
01g,08apr96,hk   moved ExcBsrTblBErr/ExcBsrTbl to restore 256 BSR table.
01e,28mar96,ja   resized BSR table 256 ->166: fix pcrel too far.
01f,18dec95,hk   added support for SH704X.
01e,19may95,hk   worked around 'mova' alignment problem.
01d,06apr95,hk   deleted excBsrTbl entries over 128.
01c,27mar95,hk   added bus error support. copyright 1995.
01b,05dec94,hk   modified for pc/sr swapping in REG_SET.
01a,27oct94,hk   taken from 68k 02c.
*/

/*
DESCRIPTION
This module contains the assembly language exception handling stub.
It is connected directly to the SH exception vectors.
It sets up an appropriate environment and then calls a routine
in excLib(1).

SEE ALSO: excLib(1)
*/

#define _ASMLANGUAGE

#include "vxWorks.h"
#include "iv.h"
#include "asm.h"

#if	(CPU==SH7750 || CPU==SH7700)
#if	(SH7700_TLB_STUB_OFFSET > 0x7fff)
#error	SH7700_TLB_STUB_OFFSET > 0x7fff, check ivSh.h
#endif
#if	(SH7700_VEC_TABLE_OFFSET > 0x7fff)
#error	SH7700_VEC_TABLE_OFFSET > 0x7fff, check ivSh.h
#endif
#if	(SH7700_INT_PRIO_TABLE_OFFSET > 0x7fff)
#error	SH7700_INT_PRIO_TABLE_OFFSET > 0x7fff, check ivSh.h
#endif
#if	(SH7700_EXC_STUB_OFFSET > 0x7fff)
#error	SH7700_EXC_STUB_OFFSET > 0x7fff, check ivSh.h
#endif
#endif	/* CPU==SH7750 || CPU==SH7700 */


	.text

	/* globals */

	.global	_excStub
	.global	_excIntStub
#if	(CPU==SH7750 || CPU==SH7700)
	.global	_excStubSize
	.global	_excBErrStub
	.global	_excBErrStubSize
	.global	_mmuStub
	.global	_mmuStubSize
#elif	(CPU==SH7600 || CPU==SH7000)
	.global	_excBsrTbl
	.global	_excBsrTblBErr
#endif	/*CPU==SH7600 || CPU==SH7000*/

#if	(CPU==SH7750)
	/* globals for SH7751 virtual PCI space extension */
	.global	_mmuPciStub
	.global	_mmuPciStubSize
	.global	_mmuPciStubParams
	.global	_mmuPciIoStub
	.global	_mmuPciIoStubSize
	.global	_mmuPciIoStubParams
	.global	_mmuStubProper
	.global	_mmuStubProperSize
#endif	/* CPU==SH7750 */

	/* imports */

	.extern	_excBErrVecNum		/* excArchLib */
	.extern	_excExcHandle		/* excArchLib */
	.extern	_excIntHandle		/* excArchLib */
	.extern	_intCnt			/* intLib */
	.extern	_errno			/* errnoLib */
	.extern	_intExit		/* windALib */
	.extern	_intLockTaskSR		/* intArchLib */
#if	(CPU==SH7750 || CPU==SH7700)
	.extern	_intBlockSR		/* intArchLib */
#elif	(CPU==SH7600 || CPU==SH7000)
	.extern	_vxIntStackBase		/* kernelLib */
	.extern	_areWeNested		/* windALib */
#endif	/*CPU==SH7600 || CPU==SH7000*/

	/* local definitions */

#if	(CPU==SH7750)
#define TRA	0x20		/* 0xff000020: TRApa exception register */
#define EXPEVT	0x24		/* 0xff000024: Exception Event	      */
#define TEA	0x0c		/* 0xff00000c: TLB Exception Address    */
#elif	(CPU==SH7700)
#define TRA	0xd0		/* 0xffffffd0: TRApa exception register */
#define EXPEVT	0xd4		/* 0xffffffd4: EXception EVenT register */
#define TEA	0xfc		/* 0xfffffffc: TLB Exception Address    */
#endif	/*CPU==SH7700*/


#if (CPU==SH7750 || CPU==SH7700)
/******************************************************************************
*
* excStub - exception handler (SH7750/SH7700)
*
* This is the exception dispatcher that is pointed by the SH77XX exception
* vector.  These instructions are copied to (vbr + 0x100), the SH77XX
* exception vector by the startup routine excVecInit().  In this routine
* we take care of saving state, and jumping to the appropriate routines.
* On exit from handling we also return here to restore state properly.
* 
* This routine is not callable!!  This routine does not include save and
* restore of floating point state.
*
* NOMANUAL
*
*		|_____________|     +60       __________
*		|TRA/TEA/FPSCR| 96  +56  +12         ^
*		|   EXPEVT    | 92  +52  +8   _____  | ESFSH
*		|     ssr     | 88  +48  +4	^    |
*	r5 --->	|     spc     | 84  +44  +0	| ___v__
*		|     r15     | 80  +40		|
*		|     r14     | 76  +36		|
*		|     r13     | 72  +32		|
*		|     r12     | 68  +28		|
*		|     r11     | 64  +24		|
*		|     r10     | 60  +20		|
*		|     r9      | 56  +16		|
*		|     r8      | 52  +12		|
*		|    macl     | 48  +8		|
*		|    mach     | 44  +4     REG_SET
*		|     r7      | 40  +0		|
*		|     r6      | 36		|
*		|     r5      | 32		|
*		|     r4      | 28		|
*		|     r3      | 24		|		+--------+
*		|     r2      | 20		|	     r6 |REG_SET*|
*		|     r1      | 16		|		+--------+
*		|     r0      | 12		|	     r5 | ESFSH *|
*		|     pr      |  8		|		+--------+
*		|     gbr     |  4		|	     r4 |  INUM  |
*       r6 --->	|____ vbr ____|  0    __________v__		+--------+
*               |             |
*/
	.align	_ALIGN_COPY_TEXT
	.type	_excStub,@function

_excStub:			/* MD=1, RB=1, BL=1, IM=? */
#if	(CPU==SH7750)
	mov.l	EFF000000,r1
	mov.l	@(EXPEVT,r1),r0
#else
	mov	#EXPEVT,r1
	mov.l	@r1,r0
#endif
	cmp/eq	#0x40,r0	/* 0x40: TLB invalid (read) */
	bt	excTlbStub
	cmp/eq	#0x60,r0	/* 0x60: TLB invalid (write) */
	bt	excTlbStub

#ifdef	_WRS_HW_FP_SUPPORT
	mov.w	EvtFpu,r1
	cmp/eq	r1,r0		/* 0x120: FPU exception */
	bt.s	excFpuStub;
	mov	r0,r5		/* r5_bank1 = EXPEVT */
#endif
	mov.w	EvtTrapa,r1
	cmp/eq	r1,r0		/* 0x160: Unconditional Trap */
	bf.s	excNonTrapa
	mov	r0,r5		/* r5_bank1 = EXPEVT */

#if	(CPU==SH7750)
	mov.l	EFF000000,r1
	bra	excInfoGet;
	add	#TRA,r1
#else
	bra	excInfoGet;
	mov	#TRA,r1
#endif

excTlbStub:
	mov.w	MMU_STUB_OFFSET,r1;
	stc	vbr,r0
	add	r1,r0
	jmp	@r0;		/* ---> mmuStub: at (vbr + 0x400) */
	nop

#ifdef	_WRS_HW_FP_SUPPORT
excFpuStub:
	bra	excUnblock;
	sts	fpscr,r4
#endif


excNonTrapa:			/* <--- mmuStubErr:  */
#if	(CPU==SH7750)
	mov.l	EFF000000,r1;
	add	#TEA,r1
#else
	mov	#TEA,r1
#endif

excInfoGet:			/* r5_bank1 = EXPEVT */
	mov.l	@r1,r4		/* r4_bank1 = TRA or TEA */
excUnblock:			/* r4_bank1 = TRA or TEA or FPSCR */
	stc	ssr,r6		/* r6_bank1 = ssr    */
	stc	spc,r7		/* r7_bank1 = spc    */

	mov.l	XCFFFFFFF,r1	/* r1: 0xcfffffff */
	stc	sr,r0		/* r0: 0x7___?_?_ */
	or	#0xf0,r0	/* r0: 0x7___?_f_ */
	and	r1,r0		/* r0: 0x4___?_f_ */
	ldc	r0,sr		/* UNBLOCK EXCEPTION (enable mmuStub), RB=0 */

	stc.l	r4_bank,@-sp				/* save TRA/TEA/FPSCR */
	stc.l	r5_bank,@-sp				/* save EXPEVT    */
	stc.l	r6_bank,@-sp;	stc.l	r7_bank,@-sp	/* save ssr/spc   */
	add	#-4,sp;		mov.l	r14, @-sp	/* save     r14   */
	mov.l	r13, @-sp;	mov.l	r12, @-sp	/* save r13/r12   */
	mov.l	r11, @-sp;	mov.l	r10, @-sp	/* save r11/r10   */
	mov.l	r9,  @-sp;	mov.l	r8,  @-sp	/* save r9/r8     */
	sts.l	macl,@-sp;	sts.l	mach,@-sp	/* save macl/mach */
	mov.l	r7,  @-sp				/* save r7        */

	mov	sp,  r7
	add	#60, r7
	mov.l	r7,  @(40,sp)				/* save as r15  */
				mov.l	r6,  @-sp	/* save    r6   */
	mov.l	r5,  @-sp;	mov.l	r4,  @-sp	/* save r5/r4   */
	mov.l	r3,  @-sp;	mov.l	r2,  @-sp	/* save r3/r2   */
	mov.l	r1,  @-sp;	mov.l	r0,  @-sp	/* save r1/r0   */
	sts.l	pr,  @-sp				/* save pr      */
	stc.l	gbr, @-sp;	stc.l	vbr, @-sp	/* save gbr/vbr */

	mov	sp,  r5
	add	#84, r5		/* r5: --> ESF */

	mov.l	@(8,r5),r4	/* r4: EXPEVT 0x080, 0x0a0, ... 0x1d0 */

	mov	r4,r0		/* do sanity check for EXPEVT code */
	tst	#0x1f,r0
	bf	excSetDefault	/*(EXPEVT & 0x1f) != 0, this should not happen*/
	mov	#0x40,r1
	cmp/hs	r1,r0
	bf	excSetDefault	/* EXPEVT < 0x40, this should not happen */
	shll2	r1
	shll2	r1
	cmp/hs	r1,r0
	bt	excSetDefault	/* EXPEVT >= 0x400, this should not happen */

	mov.w	IntPrioTableOffset,r1
	stc	vbr,r0
	add	r1,r0
	mov	r4,r3
	mov	#-3,r1
	shld	r1,r3		/* r3: 0x0, 0x4 */
	mov.l	@(r0,r3),r2	/* fetch sr from intPrioTable[] */

	mov.w	EvtTrapa,r1	/* If this is a trap exception, read */
	cmp/eq	r4,r1		/* TRA value and map it over the sh3 */
	bf	excUnlock	/* virtual interrupt vector table.   */

	mov.l	@(12,r5),r3	/* r3: TRA 0x000, 0x004, ... 0x3fc */
	mov	r3,r4
	mov	#3,r1
	shld	r1,r4		/* r4: 0x000, 0x020, ... 0x1fe0 */

excUnlock:
	tst	r2,r2			/* continue locking if intPrioTable */
	bt	excChkBusErr		/* entry is null, otherwise         */
	ldc	r2,sr			/* UNLOCK INTERRUPTS                */

excChkBusErr:
	mov.l	ExcBErrVecNum,r1;
	mov.l	@r1,r0;			/* r0: 0, 1, 2, ... 255 */
	shll2	r0			/* If this is a bus error interrupt,*/
	cmp/eq	r3,r0			/* force to call excExcHandle since */
	bt	excSetDefault		/* the vector entry is excBErrStub. */

	mov.w	ExcVecTblOffset,r1
	stc	vbr,r0
	add	r1,r0
	bra	excDispatch;
	mov.l	@(r0,r3),r2

excSetDefault:
	mov.l	ExcExcHandle,r2

excDispatch:
	mov	#-5,r1
	shld	r1,r4		/* r4: 0, 1, 2, ... 255 */
	jsr	@r2;		/* excExcHandle (INUM, ESFSH, REG_SET) */
	mov	sp,r6		/*                r4    r5      r6     */

	/* only vxMemProbeTrap/fppProbeTrap come here */

	add	#8,sp			/* skip vbr/gbr */
	lds.l	@sp+,pr
	mov.l	@sp+,r0
	mov.l	@sp+,r1
	mov.l	@sp+,r2
	mov.l	@sp+,r3			/* LOCK INTERRUPTS, RB=0 */
	mov.l	@sp+,r4;		mov.l	IntLockSR,r7
	mov.l	@sp+,r5;		mov.l	@r7,r7
	mov.l	@sp+,r6;		ldc	r7,sr
	mov.l	@sp+,r7
	lds.l	@sp+,mach
	lds.l	@sp+,macl
	add	#32,sp			/* skip r8-r15 */

	ldc.l	@sp+,r7_bank		/* r7_bank1 = spc */
	ldc.l	@sp+,r6_bank		/* r6_bank1 = ssr */
	ldc	r5,  r5_bank		/* r5_bank1 = r5  */

	mov.l	IntBlockSR,r5
	mov.l	@r5,r5
	ldc	r5,sr			/* BLOCK EXCEPTION/INTERRUPTS, RB=1 */

	ldc	r5,r5_bank		/* r5_bank0 = r5  */
	ldc	r6,ssr
	ldc	r7,spc
	rte;				/* UNBLOCK INTERRUPTS/EXCEPTION */
	add	#8,sp			/* skip EXPEVT, TRA/TEA */

			.align	2
#if (CPU==SH7750)
EFF000000:		.long	0xff000000
#endif
XCFFFFFFF:		.long	0xcfffffff
IntBlockSR:		.long	_intBlockSR			/* intArchLib */
IntLockSR:		.long	_intLockTaskSR			/* intArchLib */
ExcExcHandle:		.long	_excExcHandle			/* excArchLib */
ExcBErrVecNum:		.long	_excBErrVecNum			/* excArchLib */
EvtFpu:			.word	0x120
EvtTrapa:		.word	0x160
MMU_STUB_OFFSET:	.word	SH7700_TLB_STUB_OFFSET		/* ivSh.h */
ExcVecTblOffset:	.word	SH7700_VEC_TABLE_OFFSET		/* ivSh.h */
IntPrioTableOffset:	.word	SH7700_INT_PRIO_TABLE_OFFSET	/* ivSh.h */
excStubEnd:
			.align	2
			.type	_excStubSize,@object
			.size	_excStubSize,4
_excStubSize:		.long	excStubEnd - _excStub

/******************************************************************************
*
* excBErrStub - bus timeout error interrupt handling stub (SH7750/SH7700)
*
* This stub code is attached to a virtual interrupt vector table entry
* by excVecInit(), to a slot specified by excBErrVecNum.  Thus this code
* is dispatched from intStub, with INTEVT/ssr/spc on interrupt stack.
* The object here is to fake the bus error interrupt as an exception:
* (1) push the INTEVT code to EXPEVT register, (2) return to task's stack
* if not nested, (3) then branch to excStub, the generic exception handling
* stub.
*
* NOMANUAL
*
*	   [ task's stack ]               [ interrupt stack ]
*				
*	|  aaa	|     vxIntStackBase ->	+-------+	|	|
*	|__bbb__|<----------------------|task'sp|	|_______| +12
*	|	|			|INTEVT	|	|INTEVT	|  +8
*					|  ssr	|	|  ssr	|  +4
*				  sp ->	|__spc__|	|__spc__|  +0
*					|	|	|	|
*/
	.align	_ALIGN_COPY_TEXT
	.type	_excBErrStub,@function

_excBErrStub:				/* MD=1, RB=1, BL=1 */
	mov.l	@(8,sp),r0;
#if	(CPU==SH7750)
	mov.l	BE_FF000000,r1
	mov.l	r0,@(EXPEVT,r1)		/* INTEVT -> EXPEVT */
#else
	mov	#EXPEVT,r1
	mov.l	r0,@r1			/* INTEVT -> EXPEVT */
#endif
	stc	vbr,r1;
	mov.l	@(SH7700_ARE_WE_NESTED_OFFSET,r1),r0
	rotr	r0
	mov.l	r0,@(SH7700_ARE_WE_NESTED_OFFSET,r1) /* update areWeNested */
	bf.s	excBErrNested
	add	#12,sp			/* skip spc/ssr/INTEVT */

	mov.l	@sp,sp			/* return to task's stack */
excBErrNested:
	mov.w	BE_ExcStubOffset,r0
	stc	vbr,r1
	add	r1,r0
	jmp	@r0;			/* jump to _excStub in P1/P2 */
	nop

			.align	2
#if (CPU==SH7750)
BE_FF000000:		.long	0xff000000
#endif
BE_ExcStubOffset:	.word	SH7700_EXC_STUB_OFFSET
excBErrStubEnd:
			.align	2
			.type	_excBErrStubSize,@object
			.size	_excBErrStubSize,4
_excBErrStubSize:	.long	excBErrStubEnd - _excBErrStub

/******************************************************************************
*
* excIntStub - uninitialized interrupt handler (SH7750/SH7700)
*
* This routine is dispatched from intStub, with INTEVT/ssr/spc on interrupt
* stack.  It forms a REG_SET structure on stack, then calls the generic
* uninitialized interrupt handler (excIntHandle()).  Then it reforms the
* stack frame and jumps to intExit.
*
* NOMANUAL
*
*   [task's stack]  [interrupt stack]         <before intExit>
*
*	|  aaa	|     	+-------+		|	|
*	|__bbb__|<------|task'sp| +68		|_______|
*	|	|	|INTEVT	| +64	+104	|INTEVT	|
*			|  ssr	| +60	+100	|  ssr	|
*	r5 ------ sp ->	|_ spc _| +56	+96	|  spc	|
*		-4	|  ssr	| +52	+92	|  pr	|
*		-8	|  spc	| +48	+88	|  r0	|
*		-12	|  r15	| +44	+84	|  r1	|
*			|  r14	| +40	+80	|  r2	|
*			|  r13	| +36	+76	|  r3	|
*			|  r12	| +32	+72	|  r4	|
*			|  r11	| +28	+68	|  r5	|
*			|  r10	| +24	+64	|  r6	|
*			|  r9	| +20	+60	|  r7	|
*			|  r8	| +16	+56	| mach	|
*			| macl	| +12	+52	| macl	|
*		  	| mach	| +8	+48	|	|
*			|  r7	| +4	+44
*			|  r6	| +0	+40
*		 	|  r5	|	+36
*		  sp ->	|  r4	|	+32
*			|  r3	|	+28
*			|  r2	|	+24
*			|  r1	|	+20
*			|  r0	|	+16
*			|  pr	|	+12
*			|  gbr	|	+8
*		REG_SET	|_ vbr _|	+4
*			| errno	|	+0
*			|	|	
*/
	.align	_ALIGN_TEXT
	.type	_excIntStub,@function
					/* MD=1, RB=0, BL=0 */
_excIntStub:
	add	#-12,sp
	mov.l	r14, @-sp;				/* save r14       */
	mov.l	r13, @-sp;	mov.l	r12, @-sp	/* save r13/r12   */
	mov.l	r11, @-sp;	mov.l	r10, @-sp	/* save r11/r10   */
	mov.l	r9,  @-sp;	mov.l	r8,  @-sp	/* save r9/r8     */
	sts.l	macl,@-sp;	sts.l	mach,@-sp	/* save macl/mach */
	mov.l	r7,  @-sp;	mov.l	r6,  @-sp	/* save r7/r6     */

	mov.l	@(60,sp),r7;	mov.l	r7,@(52,sp)	/* save ssr */
	mov.l	@(56,sp),r7;	mov.l	r7,@(48,sp)	/* save spc */

	stc	vbr,r6;
	mov	sp,r7
	mov.l	@(SH7700_ARE_WE_NESTED_OFFSET,r6),r6;
	rotr	r6
	bf.s	excIntNested
	add	#68,r7
	mov.l	@r7,r7	/* task's sp */
excIntNested:			mov.l	r7,@(44,sp)	/* save as r15 */

	mov.l	IS_IntCnt,r7
	mov.l	@r7, r6
	add	#1,  r6
	mov.l	r6,  @r7

	mov.l	r5,  @-sp;	mov.l	r4,  @-sp	/* save r5/r6   */
	mov.l	r3,  @-sp;	mov.l	r2,  @-sp	/* save r3/r2   */
	mov.l	r1,  @-sp;	mov.l	r0,  @-sp	/* save r1/r0   */
	sts.l	pr,  @-sp				/* save pr      */
	stc.l	gbr, @-sp;	stc.l	vbr, @-sp	/* save gbr/vbr */
	mov.l	IS_Errno,r7
	mov.l	@r7,  r6;	mov.l	r6,  @-sp	/* save errno   */

	mov	sp,r4
	add	#104,r4
	mov.l	@r4,r4			/* r4: INTEVT */
	mov	#-5,r1
	shld	r1,r4			/* r4: (INTEVT >> 5) */
	mov	sp,r5
	add	#96,r5			/* r5: pEsf */
	mov.l	IS_ExcIntHandle,r0;
	mov	sp,r6
	jsr	@r0;			/* excIntHandle (INUM, pEsf, pRegs) */
	add	#4,r6			/*                r4     r5    r6   */

	mov	sp,r7
	add	#96,r7					/* r7: pEsf */
	mov.l	@(12,sp),r6;	mov.l	r6,@-r7		/* push pr */
	mov.l	@(16,sp),r6;	mov.l	r6,@-r7		/* push r0 */
	mov.l	@(20,sp),r6;	mov.l	r6,@-r7		/* push r1 */
	mov.l	@(24,sp),r6;	mov.l	r6,@-r7		/* push r2 */
	mov.l	@(28,sp),r6;	mov.l	r6,@-r7		/* push r3 */
	mov.l	@(32,sp),r6;	mov.l	r6,@-r7		/* push r4 */
	mov.l	@(36,sp),r6;	mov.l	r6,@-r7		/* push r5 */
	mov.l	@(40,sp),r6;	mov.l	r6,@-r7		/* push r6 */
	mov.l	@(44,sp),r6;	mov.l	r6,@-r7		/* push r7 */
	mov.l	@(48,sp),r6;	mov.l	r6,@-r7		/* push mach */
	mov.l	@(52,sp),r6;	mov.l	r6,@-r7		/* push macl */

	mov.l	IS_IntExit,r0
	mov.l	@sp,r1			/* r1: errno (for intExit) */
	jmp	@r0;			/* exit the ISR thru the kernel */
	mov	r7,sp			/* sp -> macl */

			.align	2
IS_IntCnt:		.long	_intCnt
IS_Errno:		.long	_errno
IS_ExcIntHandle:	.long	_excIntHandle
IS_IntExit:		.long	_intExit


/******************************************************************************
*
* mmuStub - TLB mishit exception handler (SH7750/SH7700)
*
* This is the TLB (Translation Lookaside Buffer) mishit exception handler that
* is pointed by the SH77XX TLB mishit exception vector.  The object here is to
* find a new page table entry from address translation table and load it to
* TLB.  If a valid entry is not found, put EXPEVT in r0 and jump to excTLBfixed.
*
* These instructions are copied to (vbr + 0x400), the SH77XX TLB mishit excep-
* tion vector by the startup routine excVecInit().  As this handler does not
* unblock exception, another TLB mishit exception is fatal and it leads to
* an immediate CPU reset.  To avoid this, the code text is safely placed on
* physical space by proper VBR setup, and the address translation table is also
* built on plysical space by mmuSh7700Lib.  This handler uses R0..R3 in bank-1
* as work registers, thus these four registers are volatile while SR.BL=0.
*
* NOMANUAL
*/

#define PTEH	0x0		/* Page Table Entry High  */
#define PTEL	0x4		/* Page Table Entry Low   */
#define TTB	0x8		/* Translation Table Base */
#define MMUCR	0x10		/* MMU Control Register */

	.align	_ALIGN_COPY_TEXT
	.type	_mmuStub,@function

_mmuStub:			/* MD=1, RB=1, BL=1, IM=? */
#if	(CPU==SH7750)
	mov.l	MS_XFF000000,r3;/* r3: 0xff000000 */
#else	/*CPU==SH7700*/
	mov	#0xf0,r3	/* r3: 0xfffffff0 */
#endif	/*CPU==SH7700*/
	mov	#-10,r0
	mov.l	@(PTEH,r3),r1;	/* r1: ABCDEFGHIJKLMNOPQRSTUV00???????? */
	shld	r0,r1		/* r1: 0000000000ABCDEFGHIJKLMNOPQRSTUV */
	mov.w	MS_X0FFC,r2;	/* r2: 00000000000000000000111111111100 */
	mov	#-12,r0
	and	r1,r2		/* r2: 00000000000000000000KLMNOPQRST00 */
	shld	r0,r1		/* r1: 0000000000000000000000ABCDEFGHIJ */
	mov.l	@(TTB,r3),r0;
	shll2	r1		/* r1: 00000000000000000000ABCDEFGHIJ00 */
	mov.l	@(r0,r1),r0;	/* r0: --> PTELs table */
	cmp/eq	#-1,r0
	bt	mmuStubErr

	mov.l	@(r0,r2),r1;	/* r1: PTEL entry to load */
	swap.b	r1,r0
	tst	#0x01,r0	/* entry invalid if PTEL.V (bit8) is zero */
	bt	mmuStubErr

	mov.l	r1,@(PTEL,r3)	/* update PTEL */
	ldtlb			/* load PTEH/PTEL to TLB */
	nop
	rte;			/* UNBLOCK EXCEPTION */
	nop
		.align	2
#if (CPU==SH7750)
MS_XFF000000:	.long	0xff000000
#endif
MS_X0FFC:	.word	0x0ffc

mmuStubErr:	/* failed to find a valid PTEL entry */
	mov.l	MS_ExcNonTrapaOffset,r0; 
	stc	vbr,r1
	add	r1,r0
#if	(CPU==SH7750)
	jmp	@r0;
	mov.l	@(EXPEVT,r3),r5
#else	/*CPU==SH7700*/
	mov	#EXPEVT,r1
	jmp	@r0;
	mov.l	@r1,r5
#endif	/*CPU==SH7700*/
			.align	2
MS_ExcNonTrapaOffset:	.long	excNonTrapa - _excStub + SH7700_EXC_STUB_OFFSET
mmuStubEnd:
			.type	_mmuStubSize,@object
			.size	_mmuStubSize,4
_mmuStubSize:		.long	mmuStubEnd - _mmuStub

#if (CPU==SH7750)
/******************************************************************************
*
* mmuPciStub - TLB mishit exception handler with virtual PCI space support
*
* This is an optional TLB mishit exception handler which enables to extend
* the PCI window size of SH7751. The original PCI window size is 16MB for
* memory space and 256KB for IO space, and an effective PCI bus address is
* specified as a sum of a window offset and a window base address in PCIMBR/
* PCIIOBR register.  The idea is to map every 16MB/256KB page in a user
* defined virtual PCI space to the same physical PCI window memory, using
* the TLB mishit exceptions to update the corresponding base register when
* the effective address of the exception lies within the virtual PCI space.
*
* The problem with this scheme is that you can't guarantee that you will always
* get a TLB mishit exception when you switch between the virtual PCI pages,
* because the previous virtual-to-physical mappings are cached in the UTLB.
* To solve this problem, we use the URC field in the MMUCR register to load
* a PCI mapping to an unique UTLB entry: #63 for PCI memory mapping, and #62
* for PCI I/O mapping.  The URB field in the MMUCR register is initialized
* by excPciMapInit() to reserve these UTLB entries.  This means that there will
* ever be only one mapping in the UTLB for PCI memory space and another one
* mapping for PCI I/O space, so that you will always get an exception when
* you go beyond a PCI page boundary.  The used page size differs on each space:
* 1MB for PCI memory space, 64KB for PCI IO space, and 4KB for other regular
* non-PCI space.
*
* This handler is composed of three parts: mmuPciStub, mmuPciIoStub, and
* mmuStubProper.  The initialization is managed by excPciMapInit(), only
* the necessary handler parts are pasted in (VBR+0x400) and some immediate
* constants are modified to describe the virtual PCI space parameters.
* As mentioned above, the excPciMapInit() also tells mmuSh7750LibInit() to
* reserve a few UTLB entries.  The mmuPciStub part takes care of PCI memory
* space mapping, and the mmuPciIoStub part takes care of PCI IO space mapping.
* The regular TLB refill part (mmuStubProper) picks up a new PTEL value from
* a page table, but other two parts (mmuPciStub/mmuPciIoStub) assemble a new
* PTEL value from a requested virtual address information in PTEH.  Therefore
* these virtual PCI spaces do not need a page table which would affect on
* system memory usage.
*
* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.type	_mmuPciStub,@function

_mmuPciStub:				/* MD=1, RB=1, BL=1, IM=? */
	mov.l	MP_XFF000000,r3;
	mov.l	MP_PCI_VMEM_LOW,r0;	/* Lower PCI memory space boundary */
	mov.l	@(TEA,r3),r1;
	mov.l	MP_PCI_VMEM_HIGH,r2;	/* Upper PCI memory space boundary */
	cmp/hi	r1,r0
	bt	mmuPciStubEnd
	cmp/hs	r2,r1
	bt	mmuPciStubEnd

	mov.l	MP_PCI_PMEM_BASE,r0;
	and	r3,r1			/* r1: TEA & 0xff000000 */
	mov.l	MP_PCIMBR,r2;
	add	r0,r1
	mov.l	@r2,r0;
	and	#1,r0			/* r0: PCIMBR.LOCK bit */
	or	r0,r1
	mov.l	r1,@r2			/* Update PCIMBR with 16 MB page */

	mov.l	@(MMUCR,r3),r1;		/* Replace UTLB entry #63 */
	mov.l	MP_X0000FC00,r2;
	mov.l	MP_PCI_16M_PN_MASK,r0;
	or	r2,r1
	mov.l	r1,@(MMUCR,r3)		/* MMUCR.URC = 63 */

	mov.l	@(PTEH,r3),r1;		/* r1: VPN | ASID */
	mov.l	MP_PCI_1M_PTEL_BASE,r2;
	and	r0,r1			/* r1: offset in 16MB PCI window */
	or	r2,r1			/* r1: PPN | page attributes */
	mov.l	r1,@(PTEL,r3)		/* update PTEL */
	ldtlb				/* load PTEH/PTEL to TLB */
	nop
	rte;				/* UNBLOCK EXCEPTION */
	nop
			.align	_ALIGN_TEXT
MP_XFF000000:		.long	0xff000000
MP_PCI_VMEM_LOW:	.long	0x10000000	/*      (to be patched) */
MP_PCI_VMEM_HIGH:	.long	0x14000000	/* 64MB (to be patched) */
MP_PCI_PMEM_BASE:	.long  -0x10000000	/*      (to be patched) */
MP_PCIMBR:		.long	0xfe2001c4
MP_X0000FC00:		.long	0x0000fc00
MP_PCI_16M_PN_MASK:	.long	0x00fffc00	/* mask to extract page number*/
MP_PCI_1M_PTEL_BASE:	.long	0x1d0001f4	/* 0x1d000000 - 0x1dffffff,
						 * V, 1MB, RW, NoCache, Dirty */
			.align	_ALIGN_TEXT
mmuPciStubEnd:
			.type	_mmuPciStubSize,@object
			.size	_mmuPciStubSize,4
_mmuPciStubSize:	.long	mmuPciStubEnd - _mmuPciStub

			.type	_mmuPciStubParams,@object
			.size	_mmuPciStubParams,4
_mmuPciStubParams:	.long	MP_PCI_VMEM_LOW - _mmuPciStub


	.align	_ALIGN_TEXT
	.type	_mmuPciIoStub,@function
_mmuPciIoStub:				/* r1: TEA,  r3: 0xff000000 */
	mov.l	MP_PCI_VIO_LOW,r0;	/* Lower PCI I/O space boundary */
	mov.l	MP_PCI_VIO_HIGH,r2;	/* Upper PCI I/O space boundary */
	cmp/hi	r1,r0
	bt	mmuPciIoStubEnd
	cmp/hs	r2,r1
	bt	mmuPciIoStubEnd

	mov.l	MP_XFFFC0000,r2;
	mov.l	MP_PCI_PIO_BASE,r0;
	and	r2,r1			/* r1: TEA & 0xfffc0000 */
	mov.l	MP_PCIIOBR,r2;
	add	r0,r1
	mov.l	@r2,r0;
	and	#1,r0			/* r0: PCIIOBR.LOCK bit */
	or	r0,r1
	mov.l	r1,@r2			/* Update PCIIOBR with 256KB page */

	mov.l	MP_XFFFF03FF,r0;
	mov.l	@(MMUCR,r3),r1;		/* Replace UTLB entry #62 */
	mov.l	MP_X0000F800,r2;
	and	r0,r1
	mov.l	MP_PCI_256K_PN_MASK,r0;
	or	r2,r1
	mov.l	r1,@(MMUCR,r3)		/* MMUCR.URC = 62 */

	mov.l	@(PTEH,r3),r1;		/* r1: VPN | ASID */
	mov.l	MP_PCI_64K_PTEL_BASE,r2;
	and	r0,r1			/* r1: offset in 256KB PCI window */
	or	r2,r1			/* r1: PPN | page attributes */
	mov.l	r1,@(PTEL,r3)		/* update PTEL */
	ldtlb				/* load PTEH/PTEL to TLB */
	nop
	rte;				/* UNBLOCK EXCEPTION */
	nop
			.align	_ALIGN_TEXT
MP_PCI_VIO_LOW:		.long	0x10000000	/*      (to be patched) */
MP_PCI_VIO_HIGH:	.long	0x14000000	/* 64MB (to be patched) */
MP_PCI_PIO_BASE:	.long  -0x10000000	/*      (to be patched) */
MP_XFFFC0000:		.long	0xfffc0000
MP_PCIIOBR:		.long	0xfe2001c8
MP_XFFFF03FF:		.long	0xffff03ff
MP_X0000F800:		.long	0x0000f800
MP_PCI_256K_PN_MASK:	.long	0x0003fc00	/* mask to extract page number*/
MP_PCI_64K_PTEL_BASE:	.long	0x1e2401e4	/* 0x1e240000 - 0x1e27ffff,
						 * V, 64K, RW, NoCache, Dirty */
			.align	_ALIGN_TEXT
mmuPciIoStubEnd:
			.type	_mmuPciIoStubSize,@object
			.size	_mmuPciIoStubSize,4
_mmuPciIoStubSize:	.long	mmuPciIoStubEnd - _mmuPciIoStub

			.type	_mmuPciIoStubParams,@object
			.size	_mmuPciIoStubParams,4
_mmuPciIoStubParams:	.long	MP_PCI_VIO_LOW - _mmuPciIoStub


	.type	_mmuStubProper,@function
	.align	_ALIGN_TEXT
_mmuStubProper:
	mov	#-10,r0
	mov.l	@(PTEH,r3),r1;	/* r1: ABCDEFGHIJKLMNOPQRSTUV00???????? */
	shld	r0,r1		/* r1: 0000000000ABCDEFGHIJKLMNOPQRSTUV */
	mov.w	MP_X0FFC,r2;	/* r2: 00000000000000000000111111111100 */
	mov	#-12,r0
	and	r1,r2		/* r2: 00000000000000000000KLMNOPQRST00 */
	shld	r0,r1		/* r1: 0000000000000000000000ABCDEFGHIJ */
	mov.l	@(TTB,r3),r0;
	shll2	r1		/* r1: 00000000000000000000ABCDEFGHIJ00 */
	mov.l	@(r0,r1),r0;	/* r0: --> PTELs table */
	cmp/eq	#-1,r0
	bt	mmuStubProperErr

	mov.l	@(r0,r2),r1;	/* r1: PTEL entry to load */
	swap.b	r1,r0
	tst	#0x01,r0	/* entry invalid if PTEL.V (bit8) is zero */
	bt	mmuStubProperErr

	mov.l	r1,@(PTEL,r3)	/* update PTEL */
	ldtlb			/* load PTEH/PTEL to TLB */
	nop
	rte;			/* UNBLOCK EXCEPTION */
	nop

MP_X0FFC:	.word	0x0ffc

mmuStubProperErr:		/* failed to find a valid PTEL entry */
	mov.l	MP_ExcNonTrapaOffset,r0; 
	stc	vbr,r1
	add	r1,r0
	jmp	@r0;
	mov.l	@(EXPEVT,r3),r5

			.align	2
MP_ExcNonTrapaOffset:	.long	excNonTrapa - _excStub + SH7700_EXC_STUB_OFFSET
mmuStubProperEnd:
			.type	_mmuStubProperSize,@object
			.size	_mmuStubProperSize,4
_mmuStubProperSize:	.long	mmuStubProperEnd - _mmuStubProper

#endif /* CPU==SH7750 */

#elif (CPU==SH7600 || CPU==SH7000)

/******************************************************************************
*
* excStub - exception handler (SH7600/SH7000)
*
* NOMANUAL
*
*	   |        |	   |        |		|        |
*	   |________|	   |________|		|________|
*	96 |   sr   |	   |   sr   |		|   sr   |
* 	92 |__ pc __| ESF  |__ pc __| +64  r5->	|__ pc __| +40
*	88 |   pr   |	   |   pr   | +60	|   sr   | +36
*  sp->	84 |   pr'  |	   |   pr'  | +56	|   pc   | +32
*	80 |        | sp-> |        | +52	|  r15   | +28
*	76 |        |	   |  r14   | +48	|  r14   | +24
*	72 |        |	   |  r13   | +44	|  r13   | +20
*	68 |        |	   |  r12   | +40	|  r12   | +16
*	64 |        |	   |  r11   | +36	|  r11   | +12
*	60 |        |	   |  r10   | +32	|  r10   |  +8
*	56 |        |	   |   r9   | +28	|   r9   |  +4
*	52 |        |	   |   r8   | +24	|   r8   |  +0
*	48 |        |	   |  macl  | +20	|  macl  |
*	44 |        |	   |  mach  | +16	|  mach  |
*	40 |        |	   |   r7   | +12	|   r7   |
*	36 |        |	   |   r6   |  +8	|   r6   |
*	32 |        |	   |   r5   |  +4	|   r5   |
*	28 |        |	   |   r4   |  +0  sp->	|   r4   |
*	24 |        |	   |        |		|   r3   |
*	20 |        |	   |        |		|   r2   |
*	16 |        |	   |        |		|   r1   |
*	12 |        |	   |        |		|   r0   |
*	 8 |        |	   |        |		|   pr   |
*	 4 |        |	   |        |		|   gbr  |
*	 0 |        |	   |        |	REG_SET	|__ vbr _| <-r6
*	   |        |	   |        |		|	 |
*/
	.align	_ALIGN_TEXT
	.type	_excStub,@function

_excStub:
	add	#-4,sp;		mov.l	r14, @-sp	/* save      r14  */
	mov.l	r13, @-sp;	mov.l	r12, @-sp	/* save  r13/r12  */
	mov.l	r11, @-sp;	mov.l	r10, @-sp	/* save  r11/r10  */
	mov.l	r9,  @-sp;	mov.l	r8,  @-sp	/* save   r9/r8   */
	sts.l	macl,@-sp;	sts.l	mach,@-sp	/* save macl/mach */
	mov.l	r7,  @-sp;	mov.l	r6,  @-sp	/* save   r7/r6   */
	mov.l	r5,  @-sp;	mov.l	r4,  @-sp	/* save   r5/r4   */

	sts	pr,r4					/* r4: excBsrTbl[] */
	mov.l	@(60,sp),r7;	lds	r7,pr		/* restore pr */

	mov	sp,r5;		add	#64,r5		/* r5->ESF */
				mov.l	r5,@(52,sp)	/* save as r15  */
	mov.l	@r5,r6;		mov.l	r6,@(56,sp)	/* save pc      */
	mov.l	@(4,r5),r6;	mov.l	r6,@(60,sp)	/* save sr      */

	mov.l	r3,@-sp;	mov.l	r2,@-sp		/* save r3/r2   */
	mov.l	r1,@-sp;	mov.l	r0,@-sp		/* save r1/r0   */
	sts.l	pr,@-sp					/* save pr      */
	stc.l	gbr,@-sp;	stc.l	vbr,@-sp	/* save gbr/vbr */
							/* (sp --> REG_SET) */
	add	#-6,r4			/* adjust return adrs to be BSR adrs  */

	mova	_excBsrTblBErr,r0	/*- BUS ERROR INTERRUPT SUPPORT CODE -*/
	cmp/eq	r0,r4                   /* is this a bus error interrupt?     */
	bt	excBErrExc              /* if yes, do special handling        */
					/*------------------------------------*/
	mova	_excBsrTbl,r0
	sub	r0,r4			/* get offset from start of BSR table */
	shlr2	r4			/* turn vector offset into excep num  */

excDoProc:				/* do exception processing            */
	mov.l	ExcExcHandle,r0		/*   r4: excep num                    */
	jsr	@r0			/*   r5: ESF*                         */
	mov	sp,r6			/*   r6: REG_SET* (delay slot)        */

	add	#8,sp					/* skip vbr&gbr */
	lds.l	@sp+,pr					/* restore pr   */
	mov.l	@sp+,r0;	mov.l	@sp+,r1		/* restore r0/r1 */
	mov.l	@sp+,r2;	mov.l	@sp+,r3		/* restore r2/r3 */
	mov.l	@sp+,r4;	mov.l	@sp+,r5		/* restore r4/r5 */
	mov.l	@sp+,r6;	mov.l	@sp+,r7		/* restore r6/r7 */
	lds.l	@sp+,mach;	lds.l	@sp+,macl	/* restore mach/macl */
	add	#40,sp			/* pop REG_SET off stack              */
	rte				/* return to task that got exception  */
	nop				/* (delay slot) */

excBErrExc:                             /*- BUS ERROR INTERRUPT SUPPORT CODE -*/
	ldc	r6,sr			/* succeed task's sr value.           */
        mov.l   ExcBErrVecNum,r1	/* set bus error excep number in r4,  */
        bra     excDoProc		/* then return to normal sequence.    */
        mov.l   @r1,r4			/* (delay slot)                       */
					/*------------------------------------*/
		.align	2
ExcExcHandle:	.long	_excExcHandle
ExcBErrVecNum:	.long	_excBErrVecNum

/******************************************************************************
*
* excIntStub - uninitialized interrupt handler (SH7600/SH7000)
*
* NOMANUAL
*
*	<task'sp>	   <task'sp>	   <int stack>		<int stack>
*
*	|        |	   |        |
*	|________|	   |________|
*	|   sr   |	20 |   sr   |
* ESF	|__ pc __|	16 |__ pc __|
*	|   pr   |	12 |   pr   |
* sp->	|   pr'  |	 8 |   r0   |
*	|        |	 4 |   r1   |	   |________|		|________|
*	|        |  r1-> 0 |   r2   | <--- |task'sp |		|task'sp |
* 	|        |	   |        |	   |   r3   |		|   r3   |
*	|        |	   |        |	   |   r4   |		|   r4   |
*	|        |	   |        |	   |   r5   |		|   r5   |
*	|        |	   |        |	   |   r6   |		|   r6   |
*	|        |	   |        |	   |   r7   |		|   r7   |
*	|        |	   |        |	   |  mach  |		|  mach  |
*	|        |	   |        |	   |  macl  |		|  macl  |
*	|        |	   |        | sp-> |_ errno_|     +92	|_ errno_|
*	|        |	   |        |	   |   sr   |     +88	|        |
*	|        |	   |        |	   |   pc   |     +84
* 	|        |	   |        |	   |  r15   | +52 +80
*	|        |	   |        |	   |  r14   | +48 +76
*	|        |	   |        |	   |  r13   | +44 +72
*	|        |	   |        |	   |  r12   | +40 +68
*	|        |	   |        |	   |  r11   | +36 +64
*	|        |	   |        |	   |  r10   | +32 +60
*	|        |	   |        |	   |   r9   | +28 +56
*	|        |	   |        |	   |   r8   | +24 +52
*	|        |	   |        |	   |  macl  | +20 +48
*	|        |	   |        |	   |  mach  | +16 +44
*	|        |	   |        |	   |   r7   | +12 +40
*	|        |	   |        |	   |   r6   |  +8 +36
*	|        |	   |        |	   |   r5   |  +4 +32
*	|        |	   |        |	   |   r4   |  +0 +28
*	|        |	   |        |	   |   r3   |     +24
*	|        |	   |        |	   |   r2   |     +20
*	|        |	   |        |	   |   r1   |     +16
*	          	             	   |   r0   |     +12
*	          	             	   |   pr   |      +8
*	          	             	   |   gbr  |      +4
*	          	           REG_SET |__ vbr _|      +0
*	          	             	   |        |
*/
	.align	_ALIGN_TEXT
	.type	_excIntStub,@function

_excIntStub:
	mov.l	r0,@sp			/* overwrite pr' on stack */
	mov.l	r1,@-sp
	mov.l	r2,@-sp;		mov.l	IntLockSR,r2
	mov.l	AreWeNested,r1;		mov.l	@r2,r0
					stc	sr,r2	/* save current sr */
	/* update areWeNested */	ldc	r0,sr	/* LOCK INTERRUPTS */
	mov.l	@r1,r0
	rotl	r0
	mov.l	r0,@r1
#if (CPU==SH7000)
	mov	sp,r1
	bf	excIntNested
#else
	bf.s	excIntNested
	mov	sp,r1			/* r1: points at r2 on stack */
#endif
	mov.l	VxIntStackBase,r0;
	mov.l	@r0,r0;
	mov.l	sp,@-r0			/* save task's sp */
	mov	r0,sp			/* switch to interrupt stack */
excIntNested:
					ldc	r2,sr	/* UNLOCK INTERRUPTS */
	mov.l	r3,  @-sp
	mov.l	r4,  @-sp;		mov.l	IntCnt,r2
	mov.l	r5,  @-sp;		mov.l	@r2,r0
	mov.l	r6,  @-sp;		add	#1,r0
	mov.l	r7,  @-sp;		mov.l	Errno,r3
	sts.l	mach,@-sp;		mov.l	@r3,r3
	sts.l	macl,@-sp;		mov.l	r3,@-sp		/* save errno */
					mov.l	r0,@r2		/* bump count */
	/* form REG_SET on stack */

	mov.l	@(20,r1),r0;	mov.l	r0,  @-sp	/* save sr */
	mov.l	@(16,r1),r0;	mov.l	r0,  @-sp	/* save pc */
	add	#-4,sp;		mov.l	r14, @-sp	/* save      r14  */
	mov.l	r13, @-sp;	mov.l	r12, @-sp	/* save  r13/r12  */
	mov.l	r11, @-sp;	mov.l	r10, @-sp	/* save  r11/r10  */
	mov.l	r9,  @-sp;	mov.l	r8,  @-sp	/* save   r9/r8   */
	sts.l	macl,@-sp;	sts.l	mach,@-sp	/* save macl/mach */
	mov.l	r7,  @-sp;	mov.l	r6,  @-sp	/* save   r7/r6   */
	mov.l	r5,  @-sp;	mov.l	r4,  @-sp	/* save   r5/r4   */

	sts	pr,r4					/* r4: excBsrTbl[] */
	mov	r1,r5;		add	#16,r5		/* r5->ESF */
				mov.l	r5,@(52,sp)	/* save as r15  */
				mov.l	r3,@-sp		/* save r3 */
	mov.l	@r1,r0;		mov.l	r0,@-sp		/* save r2 */
	mov.l	@(4,r1),r0;	mov.l	r0,@-sp		/* save r1 */
	mov.l	@(8,r1),r0;	mov.l	r0,@-sp		/* save r0 */
	mov.l	@(12,r1),r0;	mov.l	r0,@-sp		/* save pr */
	stc.l	gbr,@-sp;	stc.l	vbr,@-sp	/* save gbr/vbr */
							/* (sp ==> REG_SET) */
	add	#-6,r4			/* adjust return adrs to be BSR adrs  */
	mova	_excBsrTbl,r0		/* (_excBsrTbl must be long aligned)  */
	sub	r0,r4			/* get offset from start of BSR table */
	mov.l	ExcIntHandle,r0
	shlr2	r4			/* turn vector offset into excep num  */
					/* do exception processing            */
	jsr	@r0;			/*   r4: excep num                    */
	mov	sp,r6			/*   r5: ESF*                         */
					/*   r6: REG_SET* (delay slot)        */
	mov.l	IntExit,r0
	add	#92,sp
	jmp	@r0;			/* exit the ISR thru the kernel */
	mov.l	@sp+,r1			/* r1: _errno */

		.align	2
IntLockSR:	.long	_intLockTaskSR
AreWeNested:	.long	_areWeNested
VxIntStackBase:	.long	_vxIntStackBase
IntCnt:		.long	_intCnt
Errno:		.long	_errno
ExcIntHandle:	.long	_excIntHandle
IntExit:	.long	_intExit

/******************************************************************************
*
* excBsrTbl - table of BSRs
*
* NOMANUAL
*/
	.align	2
	.type	_excBsrTblBErr,@object
	.type	_excBsrTbl,@object

_excBsrTblBErr:
	sts.l	pr,@-sp;    bsr	_excStub;	/* 0: bus error (bsp specific)*/
_excBsrTbl:
	sts.l	pr,@-sp;    bsr	_excIntStub;	/* 0: power-on reset pc */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/* 1: power-on reset sp */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/* 2: manual reset pc */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/* 3: manual reset sp */
	sts.l	pr,@-sp;    bsr	_excStub;	/* 4: general illegal instr */
	sts.l	pr,@-sp;    bsr	_excStub;	/* 5:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/* 6: illegal slot instr */
	sts.l	pr,@-sp;    bsr	_excStub;	/* 7:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/* 8:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/* 9: cpu address error */
	sts.l	pr,@-sp;    bsr	_excStub;	/*10: dma address error */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*11: non-maskable interrupt */
	sts.l	pr,@-sp;    bsr	_excStub;	/*12: user break interrupt */
	sts.l	pr,@-sp;    bsr	_excStub;	/*13:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*14:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*15:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*16:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*17:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*18:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*19:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*20:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*21:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*22:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*23:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*24:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*25:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*26:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*27:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*28:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*29:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*30:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*31:  (reserved) */
	sts.l	pr,@-sp;    bsr	_excStub;	/*32: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*33: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*34: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*35: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*36: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*37: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*38: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*39: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*40: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*41: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*42: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*43: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*44: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*45: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*46: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*47: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*48: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*49: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*50: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*51: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*52: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*53: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*54: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*55: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*56: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*57: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*58: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*59: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*60: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*61: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*62: trap */
	sts.l	pr,@-sp;    bsr	_excStub;	/*63: trap */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*64: IRL 1    */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*65: IRL 2-3  */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*66: IRL 4-5  */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*67: IRL 6-7  */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*68: IRL 8-9  */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*69: IRL10-11 */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*70: IRL12-13 */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*71: IRL14-15 */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*72: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*73: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*74: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*75: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*76: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*77: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*78: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*79: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*80: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*81: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*82: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*83: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*84: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*85: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*86: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*87: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*88: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*89: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*90: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*91: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*92: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*93: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*94: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*95: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*96: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*97: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*98: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*99: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*100: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*101: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*102: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*103: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*104: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*105: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*106: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*107: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*108: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*109: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*110: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*111: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*112: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*113: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*114: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*115: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*116: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*117: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*118: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*119: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*120: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*121: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*122: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*123: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*124: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*125: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*126: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*127: */
#if (CPU==SH7600)
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*128: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*129: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*130: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*131: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*132: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*133: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*134: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*135: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*136: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*137: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*138: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*139: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*140: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*141: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*142: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*143: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*144: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*145: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*146: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*147: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*148: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*149: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*150: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*151: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*152: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*153: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*154: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*155: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*156: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*157: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*158: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*159: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*160: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*161: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*162: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*163: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*164: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*165: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*166: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*167: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*168: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*169: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*170: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*171: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*172: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*173: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*174: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*175: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*176: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*177: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*178: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*179: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*180: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*181: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*182: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*183: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*184: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*185: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*186: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*187: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*188: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*189: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*190: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*191: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*192: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*193: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*194: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*195: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*196: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*197: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*198: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*199: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*200: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*201: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*202: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*203: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*204: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*205: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*206: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*207: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*208: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*209: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*210: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*211: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*212: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*213: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*214: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*215: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*216: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*217: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*218: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*219: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*220: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*221: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*222: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*223: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*224: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*225: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*226: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*227: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*228: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*229: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*230: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*231: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*232: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*233: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*234: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*235: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*236: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*237: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*238: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*239: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*240: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*241: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*242: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*243: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*244: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*245: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*246: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*247: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*248: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*249: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*250: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*251: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*252: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*253: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*254: */
	sts.l	pr,@-sp;    bsr	_excIntStub;	/*255: */
#endif /* CPU==SH7600 */
	sts.l	pr,@-sp
#endif /* CPU==SH7600 || CPU==SH7000 */
