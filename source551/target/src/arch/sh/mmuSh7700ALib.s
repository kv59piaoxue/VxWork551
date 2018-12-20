/* mmuSh7700ALib.s - assembly language MMU functions for SH7700 */

/* Copyright 1996-2000 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01q,03aug00,hk   got rid of .ptext/.pdata. merged mmuCrTLBFlush to mmuTLBFlush.
		 decoupled mmuEnable to mmuCrSetOp/mmuOnOp and mmuSh7700Lib. 
		 created mmuATTRSetOp, mmuPPNSetOp, and mmuTTBSetOp. added
		 support for SH7750.
01p,28jun00,zl   included asm.h for _ALIGN_TEXT
01o,28mar00,hk   added .type directive to function names.
01n,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01m,09oct98,hk   moved SH7750 codes to mmuSh7750Lib.
01l,22sep98.hms  modified comments.
01k,17sep98,hk   merged mmuSh7750ALib.s.
01j,14sep98,hms  (mmuSh7750ALib.s) modified comments. optimized.
01i,17aug98,hms  (mmuSh7750ALib.s) derived from mmuSh7700ALib.s-01h.
01h,19jun97,hk   moved out mmuStub to excALib.s.
01g,03mar97,hk   changed XFFFF000 to XF000, XFFFFFF0F to XFF0F. used mov.w.
01f,17feb97,hk   changed mmuStubErr to jump at excNonTrapa. deleted TEA def.
01e,09feb97,hk   changed EXC_STUB_OFFSET to 0x0100 + 38.
01d,03jan97,hk   enabled TEA. changed TLB error jumping point to excTLBfixed.
01c,25dec96,hk   moved mmuTLBFlush/mmuCrTLBFlush/mmuEnable/mmuOn/mmuOff here
                 to put them in .ptext.  also put localMmuCr in .pdata section.
01b,23dec96,hk   modified comments. optimized.
01a,15nov96,wt   written.
*/

#define	_ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"


	.text

/******************************************************************************
*
* mmuCrSetOp - set MMUCR (MMU control register)
*
* This routine sets MMUCR to the specified value.  It is used to reset mmu
* to a quiescent state.  It has to be executed on P1/P2 (mmu-bypassed) region.

* INT32 mmuCrSetOp (INT32 val)

* RETURNS: current mmucr value
*
* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.global	_mmuCrSetOp
	.type	_mmuCrSetOp,@function

_mmuCrSetOp:
	mov.l	MMUCR,r1
	mov.l	r4,@r1			/* set mmucr */
#if (CPU==SH7750)
	nop; nop; nop; nop
	nop; nop; nop; nop
#endif
	rts;
	mov.l	@r1,r0			/* return current mmucr */

/******************************************************************************
*
* mmuOnOp - turn on/off mmu
*
* This routine turns on/off mmu according to the passed boolean argument.
* This routine assumes that interrupts are locked out.  Also it has to be
* executed on P1/P2 (mmu-bypassed) region, since it modifies the MMUCR.AT bit.

* INT32 mmuOnOp (BOOL enable)

* RETURNS: original mmucr value
*
* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.global	_mmuOnOp
	.type	_mmuOnOp,@function

_mmuOnOp:
	mov.l	MMUCR,r1
	tst	r4,r4
	mov.l	@r1,r0
	bt.s	mmuOff
	mov	r0,r2			/* r2: copy of original mmucr */

	bra	mmuOnSet;
	or	#0x01,r0		/* MMUCR.AT = 1 */

mmuOff:
	shlr	r0
	shll	r0			/* MMUCR.AT = 0 */

mmuOnSet:
	mov.l	r0,@r1			/* set MMUCR.AT */
#if (CPU==SH7750)
	nop; nop; nop; nop
	nop; nop; nop; nop
#endif
	rts;
	mov	r2,r0			/* return original mmucr */

/******************************************************************************
*
* mmuTLBFlushOp - invalidate one TLB entry or entire TLB
*
* This routine invalidates an UTLB entry corresponding to the specified
* virtual address.  The invalidation is done by directly accessing to
* UTLB address array, thus it has to be executed on P2 (mmu-bypassed,
* non-cacheable) region.
*
* If ENTIRE_TLB (-1) is specified as the virtual address, this routine
* invalidates whole UTLB/ITLB entries.  The invalidation is done by
* setting MMUCR.TI bit to 1, thus this operation has to be executed on
* P1/P2 (mmu-bypassed) region.
*
* SH7750: *(UINT32 *)0xf6000080 = (UINT32)v_addr & 0xfffff000;
*
* SH7700: *(UINT32 *)(0xf2000080 | ((UINT32)v_addr & 0x0001f000))
*                                 = (UINT32)v_addr & 0xfffff000;

* void mmuTLBFlush (void *v_addr)

* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.global	_mmuTLBFlushOp
	.type	_mmuTLBFlushOp,@function

_mmuTLBFlushOp:
	mov	r4,r0
	cmp/eq	#-1,r0
	bt	mmuTLBFlushAll

	mov.w	TLB_VPN_MASK,r0;
	mov.l	TLB_ADRS_ARRAY,r1;

#if (CPU==SH7700)
	mov.l	TLB_ENTRY_INDEX,r2;
	and	r4,r2			/* r2: (v_addr & 0x0001f000) */
	or	r2,r1
#endif
	and	r4,r0			/* r0: virtual page number */
	bra	mmuTLBFlushDone;
	mov.l	r0,@r1			/* write to TLB address array */

mmuTLBFlushAll:
	mov.l	MMUCR,r1
	mov.l	@r1,r0
	or	#0x04,r0
	mov.l	r0,@r1			/* invalidate entire TLB */

mmuTLBFlushDone:
#if (CPU==SH7750)
	nop; nop; nop; nop
	nop; nop; nop; nop
#endif
	rts;
	nop

			.align	2
#if (CPU==SH7700)
TLB_ADRS_ARRAY:		.long	0xf2000080
TLB_ENTRY_INDEX:	.long	0x0001f000
#elif (CPU==SH7750)
TLB_ADRS_ARRAY:		.long	0xf6000080
#endif
TLB_VPN_MASK:		.word	0xf000

/******************************************************************************
*
* mmuATTRSetOp - set page attribute to PTE (page table entry)
*
* The PTE is referenced upon TLB mishit exception, thus we have to turn off
* mmu while modifying it.  The PTE is accessed by its physical address, and
* this routine is written carefully to avoid accessing any virtual stack/data
* while modifying MMUCR and PTE.  This routine assumes that interrupts are
* locked out.  Also this routine requires to be executed on P2 (mmu-bypass,
* non-cacheable) space, since it calls mmuTLBFlushOp by relative addressing.

* void mmuATTRSetOp (UINT32 *pPte, UINT32 stateMask, UINT32 state, void *v_addr)

* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.global	_mmuATTRSetOp
	.type	_mmuATTRSetOp,@function

_mmuATTRSetOp:
	mov.l	r8,@-sp
	sts.l	pr,@-sp

	mov.l	MMUCR,r3
	mov.l	@r3,r0
	shlr	r0			/* SR.T is 1 if mmu was turned on */
	bf.s	mmuATTRSet1
	movt	r8			/* remember if mmu was turned on */

	shll	r0
	mov.l	r0,@r3			/* turn off mmu (MMUCR.AT = 0) */

mmuATTRSet1:
	and	r5,r6			/* r6: state to set */
	mov.l	@r4,r2;			/* r2: PTE to modify */
	not	r5,r5
	and	r5,r2			/* r2: state to preserve */
	or	r6,r2
	mov.l	r2,@r4			/* update PTE on memory */

	bsr	_mmuTLBFlushOp;		/* THIS BRANCH MUST BE P2 RELATIVE */
	mov	r7,r4			/* invalidate corresponding TLB entry */

	tst	r8,r8			/* check if we need to turn on mmu */
	bt	mmuATTRSet2

	bsr	_mmuOnOp;		/* THIS BRANCH MUST BE P1/P2 RELATIVE */
	mov	#1,r4			/* turn on mmu */

mmuATTRSet2:
	lds.l	@sp+,pr
	rts;
	mov.l	@sp+,r8

/******************************************************************************
*
* mmuPPNSetOp - set PPN (physical page number) to PTE (page table entry)
*
* The PTE is referenced upon TLB mishit exception, thus we have to turn off
* mmu while modifying it.  The PTE is accessed by its physical address, and
* this routine is written carefully to avoid accessing any virtual stack/data
* while modifying MMUCR and PTE.  This routine assumes that interrupts are
* locked out.  Also this routine requires to be executed on P2 (mmu-bypass,
* non-cacheable) space, since it calls mmuTLBFlushOp by relative addressing.

* void mmuPPNSetOp (UINT32 *pPte, void *p_addr, void *v_addr)

* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.global	_mmuPPNSetOp
	.type	_mmuPPNSetOp,@function

_mmuPPNSetOp:
	mov.l	r8,@-sp
	sts.l	pr,@-sp

	mov.l	MMUCR,r3
	mov.l	@r3,r0
	shlr	r0			/* SR.T is 1 if mmu was turned on */
	bf.s	mmuPPNSet1
	movt	r8			/* remember if mmu was turned on */

	shll	r0
	mov.l	r0,@r3			/* turn off mmu (MMUCR.AT = 0) */

mmuPPNSet1:
	mov.l	@r4,r2			/* r2: PTE to modify */
	mov.w	MmuAttrMask,r1
	and	r1,r2			/* r2: PTE.ATTR to preserve */
	mov.l	MmuPpnMask,r1
	and	r5,r1			/* r1: PTE.PPN to set */
	or	r1,r2
	mov.l	r2,@r4			/* update PTE on memory */

	bsr	_mmuTLBFlushOp;		/* THIS BRANCH MUST BE P2 RELATIVE */
	mov	r6,r4			/* invalidate corresponding TLB entry */

	tst	r8,r8			/* check if we need to turn on mmu */
	bt	mmuPPNSet2

	bsr	_mmuOnOp;		/* THIS BRANCH MUST BE P1/P2 RELATIVE */
	mov	#1,r4			/* turn on mmu */

mmuPPNSet2:
	lds.l	@sp+,pr
	rts;
	mov.l	@sp+,r8

		.align	2
MmuPpnMask:	.long	0x1ffffc00
MmuAttrMask:	.word	0x03ff

/******************************************************************************
*
* mmuTTBSetOp - change TTB (tanslation table base) register
*
* The TTB is referenced upon TLB mishit exception, thus it is safer to disable
* mmu while changing TTB and invalidating TLB.  This routine is written
* carefully to avoid accessing any virtual stack/data while modifying MMUCR and
* TTB.  This routine assumes that interrupts are locked out. Also this routine
* requires to be executed on P2 (mmu-bypass, non-cacheable) space, since it
* calls mmuTLBFlushOp by relative addressing.

* void mmuTTBSetOp (PTE *p_addr)

* NOMANUAL
*/
	.align	_ALIGN_TEXT
	.global	_mmuTTBSetOp
	.type	_mmuTTBSetOp,@function

_mmuTTBSetOp:
	mov.l	r8,@-sp
	sts.l	pr,@-sp

	mov.l	MMUCR,r3
	mov.l	@r3,r0
	shlr	r0			/* SR.T is 1 if mmu was turned on */
	bf.s	mmuTTBSet1
	movt	r8			/* remember if mmu was turned on */

	shll	r0
	mov.l	r0,@r3			/* turn off mmu (MMUCR.AT = 0) */

mmuTTBSet1:
	mov.l	TTB,r1
	mov.l	r4,@r1			/* write to TTB */

	bsr	_mmuTLBFlushOp;		/* THIS BRANCH MUST BE P2 RELATIVE */
	mov	#-1,r4			/* invalidate entire TLB */

	tst	r8,r8			/* check if we need to turn on mmu */
	bt	mmuTTBSet2

	bsr	_mmuOnOp;		/* THIS BRANCH MUST BE P1/P2 RELATIVE */
	mov	#1,r4			/* turn on mmu */

mmuTTBSet2:
	lds.l	@sp+,pr
	rts;
	mov.l	@sp+,r8

			.align	2
#if (CPU==SH7750)
MMUCR:			.long	0xff000010
TTB:			.long	0xff000008
#elif (CPU==SH7700)
MMUCR:			.long	0xffffffe0
TTB:			.long	0xfffffff8
#endif
