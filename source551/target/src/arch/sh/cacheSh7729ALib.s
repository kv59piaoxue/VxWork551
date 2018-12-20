/* cacheSh7729ALib.s - HITACHI SH7729 cache management assembly functions */

/* Copyright 2000-2000 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01d,21nov00,hk   changed cacheSh7729OnOp to wait writeback completion before
		 disabling cache, updated C code algorithm commentary also.
01c,18nov00,hk   changed to flush whole cache in cacheSh7729OnOp.
01b,17nov00,hk   disabled cache before modifying CCR2. made cacheSh7729OnOp
		 NMI-safe. changed to flush write-buf by reading P2 (was P4).
		 changed cacheSh7729CCR2SetOp to return CCR2 for SH7729R.
01a,09sep00,hk   derived from cacheSh7700ALib.s (01a).
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"


#define CCR			0xec		/* 0xffffffec */

#define CCR_CACHE_FLUSH		0x08
#define CCR_CACHE_ENABLE	0x01

#define CAC_LINE_SIZE		16


	.text

	.global	_cacheSh7729CCRSetOp
	.global	_cacheSh7729CCRGet
	.global	_cacheSh7729CCR2SetOp
	.global	_cacheSh7729OnOp
	.global	_cacheSh7729LoadOp
	.global	_cacheSh7729CFlushOp
	.global	_cacheSh7729AFlushOp
	.global	_cacheSh7729MFlushOp

/******************************************************************************
*
* cacheSh7729CCRSetOp - set cache control register to a specified value
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* void cacheSh7729CCRSetOp (UINT32 ccr)
*	{
*	*CCR = ccr;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7729CCRSetOp,@function
	.align	_ALIGN_TEXT

_cacheSh7729CCRSetOp:
	mov	#CCR,r1
	rts;
	mov.l	r4,@r1

/******************************************************************************
*
* cacheSh7729CCRGet - get cache control register value
*
* This routine may be executed on any region.
*
* UINT32 cacheSh7729CCRGet (void)
*	{
*	return *CCR;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7729CCRGet,@function
	.align	_ALIGN_TEXT

_cacheSh7729CCRGet:
	mov	#CCR,r1
	rts;
	mov.l	@r1,r0

/******************************************************************************
*
* cacheSh7729CCR2SetOp - set cache control register-2 to a specified value
*
* This routine modifies CCR2, thus it must be executed on P2 region.
*
* UINT32 cacheSh7729CCR2SetOp (UINT32 ccr2)
*	{
*	UINT32 ccr = *CCR;			/@ save CCR @/
*
*	SR |= BL;				/@ BLOCK INTERRUPTS @/
*
*	*CCR = (ccr & ~CCR_CACHE_ENABLE);	/@ disable cache @/
*
*	*CCR2 = ccr2;				/@ set CCR2 @/
*
*	*CCR = ccr;				/@ restore CCR @/
*
*	SR &= ~BL;				/@ UNBLOCK INTERRUPTS @/
*
*	return *CCR2;				/@ valid on SH7729R only @/
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7729CCR2SetOp,@function
	.align	_ALIGN_TEXT

_cacheSh7729CCR2SetOp:
	mov	#CCR,r7
	mov.l	@r7,r6			/* r6: original CCR */

	mov.l	S2_X10000000,r0;
	stc	sr,r5			/* r5: original SR */
	or	r5,r0
	ldc	r0,sr			/* BLOCK INTERRUPTS */

	mov	r6,r0
	mov	#(~CCR_CACHE_ENABLE),r1
	and	r1,r0
	mov.l	r0,@r7			/* DISABLE CACHE */

	mov.l	S2_XA40000B0,r3;
	mov.l	r4,@r3			/* set CCR2 */

	mov.l	r6,@r7			/* restore CCR (ENABLE CACHE) */

	ldc	r5,sr			/* restore SR (UNBLOCK INTERRUPTS) */
	rts;
	mov.l	@r3,r0			/* return CCR2 (for SH7729R) */

		.align	2
S2_X10000000:	.long	0x10000000	/* SR.BL */
S2_XA40000B0:	.long	0xa40000b0	/* CCR2 address in P2 */

/******************************************************************************
*
* cacheSh7729OnOp - turn on/off cache controller
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* STATUS cacheSh7729OnOp (BOOL on)
*	{
*	UINT32 ccr = *CCR;
*	BOOL enabled = ccr & CCR_CACHE_ENABLE;
*
*	if (enabled == on)
*	    return ERROR;
*
*	SR |= BL;				/@ BLOCK INTERRUPTS @/
*
*	if (on == FALSE)
*	    {
*	    int ix, imax;
*
*	    /@ flush entire cache (16 byte) x (256 entry) x (4 way) @/
*
*	    imax = 0x3ff0;
*
*	    for (ix = 0; ix <= imax; ix += 0x10)
*		{
*		*(UINT32 *)(0xf0000000 | ix) &= 0xfffffffc;	/@ clear U&V @/
*		}
*	    }
*
*	*CCR = ccr & ~CCR_CACHE_ENABLE;		/@ disable caching @/
*
*	*CCR = ccr | CCR_CACHE_FLUSH;		/@ invalidate entire cache @/
*
*	if (on == TRUE)
*	    *CCR = ccr | CCR_CACHE_ENABLE;	/@ enable caching @/
*
*	SR &= ~BL;				/@ UNBLOCK INTERRUPTS @/
*
*	return OK;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7729OnOp,@function
	.align	_ALIGN_TEXT

_cacheSh7729OnOp:
	mov	#CCR,r6
	mov.l	@r6,r5			/* r5: original CCR */
	mov	r5,r0
	tst	#CCR_CACHE_ENABLE,r0
	movt	r0			/* 1: disabled, 0: enabled */
	tst	r4,r4
	movt	r1			/* 1: disable,  0: enable */
	cmp/eq	r0,r1
	bt.s	ON_Exit;		/* keep current CCR.CE */
	mov	#-1,r3			/* r3: ERROR */

	mov.l	ON_X10000000,r0;
	stc	sr,r7			/* r7: original SR */
	or	r7,r0
	ldc	r0,sr			/* BLOCK INTERRUPTS */

	mov	r5,r0
	tst	#CCR_CACHE_ENABLE,r0
	bt	ON_FlushDone		/* CE: 0 (cache is disabled) */
	and	#0x6,r0
	cmp/eq	#0x2,r0
	bt	ON_FlushDone		/* CB: 0,  WT: 1 (no copyback region) */

	mov.l	ON_XF0000000,r3		/* r3: 0xf0000000 */
	mov	#0xfc,r2		/* r2: 0xfffffffc */
	mov.w	ON_256,r1		/* r1: 256 */
ON_FlushLoop:
	mov.l	@r3,r0; and r2,r0; mov.l r0,@r3; add #0x10,r3
	mov.l	@r3,r0; and r2,r0; mov.l r0,@r3; add #0x10,r3
	mov.l	@r3,r0; and r2,r0; mov.l r0,@r3; add #0x10,r3
	mov.l	@r3,r0; and r2,r0; mov.l r0,@r3; add #0x10,r3
	dt	r1
	bf	ON_FlushLoop		/* flush whole cache */
	mov.l	ON_XA0000000,r1
	mov.l	@r1,r1			/* flush write-back buffer by P2-read */

ON_FlushDone:
	mov	#(~CCR_CACHE_ENABLE),r0
	and	r5,r0
	mov.l	r0,@r6			/* DISABLE CACHE */

	or	#CCR_CACHE_FLUSH,r0
	mov.l	r0,@r6			/* invalidate entire cache tags */

	tst	r4,r4
	bt.s	ON_Unblock;
	mov	#0,r3			/* r3: OK */

	mov	r5,r0
	or	#CCR_CACHE_ENABLE,r0
	mov.l	r0,@r6			/* ENABLE CACHE */
ON_Unblock:
	ldc	r7,sr			/* UNBLOCK INTERRUPTS */
ON_Exit:
	rts;
	mov	r3,r0			/* return status */

		.align	2
ON_X10000000:	.long	0x10000000	/* SR.BL */
ON_XF0000000:	.long	0xf0000000	/* cache address array */
ON_XA0000000:	.long	0xa0000000	/* P2 base address for dummy read */
ON_256:		.word	256

/******************************************************************************
*
* cacheSh7729LoadOp - load specified memory region to a cache way
*
* This routine has to be executed on P2 region.
*
* STATUS cacheSh7729LoadOp (UINT32 *p_ccr2, UINT32 from, UINT32 to)
*     {
*     UINT32 ccr2 = *p_ccr2;		/@ get CCR2 value to set @/
*     UINT32 ca;
*
*     SR |= BL;				/@ BLOCK INTERRUPTS @/
*
*     if (ccr2 & W2LOAD)
*         cacheSh7729CCR2Set (W2LOAD | W2LOCK);
*     else if (ccr2 & W3LOAD)
*         cacheSh7729CCR2Set (W3LOAD | W3LOCK);
*     else
*         return ERROR;
*
*     for (ca = from; ca <= to; ca += CAC_LINE_SIZE)
*          {
*          *(UINT32 *)(0xf0000008 | (ca & 0xff0)) = ca & 0x1ffffc00;
*          pref (ca);
*          }
*
*     ccr2 &= ~(W2LOAD | W3LOAD);
*     cacheSh7729CCR2Set (ccr2);	/@ disable loading, restore lock bits @/
*
*     SR &= ~BL;			/@ UNBLOCK INTERRUPTS @/
*     *p_ccr2 = ccr2;			/@ update CCR2 value on memory @/
*     return OK;
*     }
*
* NOMANUAL
*/
	.type	_cacheSh7729LoadOp,@function
	.align	_ALIGN_TEXT

_cacheSh7729LoadOp:
	mov.l	r8,@-sp;	mov	r4,r8	/* r8: &ccr2 */
	mov.l	r9,@-sp;	mov	r5,r9	/* r9: from */
	mov.l	r10,@-sp;	mov	r6,r10	/* r10: to */
	mov.l	r11,@-sp;	stc	sr,r11	/* r11: original SR */
	mov.l	r12,@-sp;	mov.l	@r8,r12	/* r12: ccr2 */
	sts.l	pr,@-sp

	mov.l	LD_X10000000,r0
	or	r11,r0
	ldc	r0,sr			/* BLOCK INTERRUPTS */

	mov	#0x2,r0			/* r0:  W2LOAD */
	tst	r0,r12
	bf.s	LD_SetCCR2;
	mov	#0x3,r4			/* r4: (W2LOAD | W2LOCK) */

	shll8	r0			/* r0:  W3LOAD */
	tst	r0,r12
	bf.s	LD_SetCCR2;
	shll8	r4			/* r4: (W3LOAD | W3LOCK) */

	bra	LD_Exit;
	mov	#-1,r0			/* return ERROR */

LD_SetCCR2:
	bsr	_cacheSh7729CCR2SetOp;	/* CCR2: LOAD & LOCK either one way */
	nop
	mov.l	LD_XF0000008,r2		/* r2: 0xf0000008 */
	mov.l	LD_X1FFFFC00,r3		/* r3: 0x1ffffc00 */
	mov.w	LD_X0FF0,r4		/* r4: 0x00000ff0 */
	mov	r9,r5			/* r5: from */
	mov.l	LD_XA0000000,r6		/* r6: 0xa0000000 (P2 non-cacheable) */
LD_LoadLoop:
	mov	r3,r0			/* r0: 0x1ffffc00 */
	mov	r4,r1			/* r1: 0x00000ff0 */
	and	r5,r0			/* r0: ca & 0x1ffffc00 */
	and	r5,r1			/* r1: ca & 0x00000ff0 */
	or	r2,r1			/* r1: 0xf0000008 | (ca & 0xff0) */
	mov.l	r0,@r1			/* purge cache entry associatively */
	mov.l	@r6,r0			/* flush write-back buffer by P2-read */

	pref	@r5			/* load 16-bytes to specified way */

	add	#CAC_LINE_SIZE,r5
	cmp/hi	r10,r5
	bf	LD_LoadLoop

	mov.w	LD_XFDFD,r0		/* r0: 0xfffffdfd */
	and	r0,r12			/* r12: ccr2 & ~(W3LOAD | W2LOAD) */
	bsr	_cacheSh7729CCR2SetOp;
	mov	r12,r4			/* CCR2 &= ~LOAD; */
	mov	#0,r0			/* return OK */
LD_Exit:
	ldc	r11,sr			/* UNBLOCK INTERRUPTS */
	mov.l	r12,@r8			/* update ccr2 */
	lds.l	@sp+,pr
	mov.l	@sp+,r12
	mov.l	@sp+,r11
	mov.l	@sp+,r10
	mov.l	@sp+,r9
	rts;
	mov.l	@sp+,r8

		.align	2
LD_X10000000:	.long	0x10000000	/* SR.BL */
LD_XF0000008:	.long	0xf0000008	/* associative purge region */
LD_X1FFFFC00:	.long	0x1ffffc00
LD_XA0000000:	.long	0xa0000000	/* P2 base address for dummy read */
LD_X0FF0:	.word	0x0ff0
LD_XFDFD:	.word	0xfdfd		/* ~(W3LOAD | W2LOAD) */

/******************************************************************************
*
* cacheSh7729CFlushOp - invalidate entire cache tags by setting CCR.CF bit
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* void cacheSh7729CFlushOp (void)
*	{
*	*CCR |= CCR_CACHE_FLUSH;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7729CFlushOp,@function
	.align	_ALIGN_TEXT

_cacheSh7729CFlushOp:
	mov	#CCR,r1
	mov.l	@r1,r0
	or	#CCR_CACHE_FLUSH,r0
	rts;
	mov.l	r0,@r1			/* invalidate entire cache tags */

/******************************************************************************
*
* cacheSh7729AFlushOp - flush cache entries by associative purge loop
*
* This routine may be executed on any region.
*
* void cacheSh7729AFlushOp (UINT32 from, UINT32 to)
*     {
*     UINT32 ca;
*
*     for (ca = from; ca <= to; ca += CAC_LINE_SIZE)
*          *(UINT32 *)(0xf0000008 | (ca & 0xff0)) = ca & 0x1ffffc00;
*     }
*
* NOMANUAL
*/
	.type	_cacheSh7729AFlushOp,@function
	.align	_ALIGN_TEXT

_cacheSh7729AFlushOp:
	mov.l	AF_XF0000008,r2
	mov.l	AF_X1FFFFC00,r3
	mov.w	AF_X0FF0,r6
AF_Loop:
	mov	r3,r0			/* r0: 0x1ffffc00 */
	mov	r6,r1			/* r1: 0x00000ff0 */
	and	r4,r0			/* r0: ca & 0x1ffffc00 */
	and	r4,r1			/* r1: ca & 0x00000ff0 */
	or	r2,r1			/* r1: 0xf0000008 | (ca & 0xff0) */
	add	#CAC_LINE_SIZE,r4
	cmp/hi	r5,r4
	bf.s	AF_Loop
	mov.l	r0,@r1			/* purge cache entry associatively */

	mov.l	AF_XA0000000,r1
	rts;
	mov.l	@r1,r1			/* flush write-buffer by P2-read */

		.align	2
AF_XF0000008:	.long	0xf0000008	/* associative purge region */
AF_X1FFFFC00:	.long	0x1ffffc00
AF_XA0000000:	.long	0xa0000000	/* P2 base address (reset vector) */
AF_X0FF0:	.word	0x0ff0

/******************************************************************************
*
* cacheSh7729MFlushOp - flush a cache entry by read-modify-writing cache tag
*
* This routine blocks interrupts to assure an atomic read-modify-write
* of cache tag, thus it must be executed on P2 region.
*
* void cacheSh7729MFlushOp (UINT32 *pt, int ix, UINT32 from, UINT32 to)
*	{
*	UINT32 tag;
*
*	SR |= BL;				/@ BLOCK INTERRUPTS @/
*
*	tag = *pt;				/@ read cache tag @/
*
*	if (tag & TAG_VALID)
*	    {
*	    if (ix < 0) /@ force invalidating cache tag @/
*		{
*		*pt = tag & ~(TAG_USED | TAG_VALID); /@ modify cache tag @/
*		}
*	    else /@ check cached address @/
*		{
*		UINT32 ca = (tag & 0x1ffffc00) | (ix & 0x3ff);
*
*		if (ca >= from && ca <= to)
*		    *pt = tag & ~(TAG_USED | TAG_VALID); /@ modify cache tag @/
*		}
*	    }
*
*	SR &= ~BL;				/@ UNBLOCK INTERRUPTS @/
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7729MFlushOp,@function
	.align	_ALIGN_TEXT

_cacheSh7729MFlushOp:
	mov.l	MF_X10000000,r0;
	stc	sr,r3			/* r3: original SR */
	or	r3,r0
	ldc	r0,sr			/* BLOCK INTERRUPTS */

	mov.l	@r4,r0			/* r0: cache tag */
	tst	#0x01,r0		/* TAG_VALID? */
	bt	MF_Done

	cmp/pz	r5			/* ix >= 0 ? */
	bf	MF_Purge

	mov.l	MF_X1FFFFC00,r1
	and	r0,r1			/* r1: tag & 0x1ffffc00 */
	mov.w	MF_X03FF,r2
	and	r5,r2			/* r2: ix & 0x3ff */
	or	r2,r1			/* r1: ca (cached address) */

	cmp/hs	r6,r1			/* ca_begin <= ca ? */
	bf	MF_Done
	cmp/hs	r1,r7			/* ca <= ca_end ? */
	bf	MF_Done
MF_Purge:
	mov	#0xfc,r1		/* r1: 0xfffffffc */
	and	r1,r0			/* clear U and V */
	mov.l	r0,@r4			/* purge cache entry */
MF_Done:
	ldc	r3,sr			/* UNBLOCK INTERRUPTS */
	mov.l	MF_XA0000000,r1
	rts;
	mov.l	@r1,r1			/* flush write-buffer by P2-read */

		.align	2
MF_X10000000:	.long	0x10000000	/* SR.BL */
MF_X1FFFFC00:	.long	0x1ffffc00
MF_XA0000000:	.long	0xa0000000	/* P2 base address (reset vector) */
MF_X03FF:	.word	0x03ff
