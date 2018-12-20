/* cacheSh7700ALib.s - HITACHI SH7700 cache management assembly functions */

/* Copyright 2000-2000 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01b,21nov00,hk   changed to flush whole cache in cacheSh7700OnOp. changed to
		 read P2 to flush writebuf. made cacheSh7700MFlushOp NMI-safe.
01a,15aug00,hk   created.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"


#define CCR			0xec		/* 0xffffffec */

#define CCR_CACHE_FLUSH		0x08
#define CCR_CACHE_ENABLE	0x01

#define CAC_LINE_SIZE		16


	.text

	.global	_cacheSh7700CCRSetOp
	.global	_cacheSh7700CCRGet
	.global	_cacheSh7700OnOp
	.global	_cacheSh7700CFlushOp
	.global	_cacheSh7700AFlushOp
	.global	_cacheSh7700MFlushOp

/******************************************************************************
*
* cacheSh7700CCRSetOp - set cache control register to a specified value
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* void cacheSh7700CCRSetOp (UINT32 ccr)
*	{
*	*CCR = ccr;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7700CCRSetOp,@function
	.align	_ALIGN_TEXT

_cacheSh7700CCRSetOp:
	mov	#CCR,r1
	rts;
	mov.l	r4,@r1

/******************************************************************************
*
* cacheSh7700CCRGet - get cache control register value
*
* This routine may be executed on any region.
*
* UINT32 cacheSh7700CCRGet (void)
*	{
*	return *CCR;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7700CCRGet,@function
	.align	_ALIGN_TEXT

_cacheSh7700CCRGet:
	mov	#CCR,r1
	rts;
	mov.l	@r1,r0

/******************************************************************************
*
* cacheSh7700OnOp - turn on/off cache controller
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* STATUS cacheSh7700OnOp (BOOL on)
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
*	    /@ flush entire cache (16 byte) x (128 entry) x (4 way) @/
*
*	    if      (ccr & 0x10) imax = 0x07f0;	/@ 1-way mode (SH7702 only) @/
*	    else if (ccr & 0x20) imax = 0x0ff0;	/@ 2-way mode @/
*	    else                 imax = 0x1ff0;	/@ 4-way mode @/
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
	.type	_cacheSh7700OnOp,@function
	.align	_ALIGN_TEXT

_cacheSh7700OnOp:
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
	mov	r5,r0
	tst	#0x10,r0		/* 1-way mode ?  (SH7702 only) */
	bf.s	ON_FlushLoop
	mov	#32,r1			/* r1: 32 */
	tst	#0x20,r0		/* 2-way mode ? */
	bf.s	ON_FlushLoop
	shal	r1			/* r1: 64 */
	shal	r1			/* r1: 128 */
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

/******************************************************************************
*
* cacheSh7700CFlushOp - invalidate entire cache tags by setting CCR.CF bit
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* void cacheSh7700CFlushOp (void)
*	{
*	*CCR |= CCR_CACHE_FLUSH;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7700CFlushOp,@function
	.align	_ALIGN_TEXT

_cacheSh7700CFlushOp:
	mov	#CCR,r1
	mov.l	@r1,r0
	or	#CCR_CACHE_FLUSH,r0
	rts;
	mov.l	r0,@r1			/* invalidate entire cache tags */

/******************************************************************************
*
* cacheSh7700AFlushOp - flush cache entries by associative purge loop
*
* This routine may be executed on any region.
*
* void cacheSh7700AFlushOp (UINT32 from, UINT32 to)
*     {
*     UINT32 ca;
*
*     for (ca = from; ca <= to; ca += CAC_LINE_SIZE)
*          *(UINT32 *)(0xf0000008 | (ca & 0x7f0)) = ca & 0x1ffffc00;
*     }
*
* NOMANUAL
*/
	.type	_cacheSh7700AFlushOp,@function
	.align	_ALIGN_TEXT

_cacheSh7700AFlushOp:
	mov.l	AF_XF0000008,r2
	mov.l	AF_X1FFFFC00,r3
	mov.w	AF_X07F0,r6
AF_Loop:
	mov	r3,r0			/* r0: 0x1ffffc00 */
	mov	r6,r1			/* r1: 0x000007f0 */
	and	r4,r0			/* r0: ca & 0x1ffffc00 */
	and	r4,r1			/* r1: ca & 0x000007f0 */
	or	r2,r1			/* r1: 0xf0000008 | (ca & 0x7f0) */
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
AF_X07F0:	.word	0x07f0

/******************************************************************************
*
* cacheSh7700MFlushOp - flush a cache entry by read-modify-writing cache tag
*
* This routine blocks interrupts to assure an atomic read-modify-write
* of cache tag, thus it must be executed on P2 region.
*
* void cacheSh7700MFlushOp (UINT32 *pt, int ix, UINT32 from, UINT32 to)
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
	.type	_cacheSh7700MFlushOp,@function
	.align	_ALIGN_TEXT

_cacheSh7700MFlushOp:
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
