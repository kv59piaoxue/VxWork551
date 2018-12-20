/* cacheSh7622ALib.s - HITACHI SH7622 cache management assembly function */

/* Copyright 1998-2001 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01b,11apr01,frf  modified invalidation functions, added clear function.
01a,26mar01,frf  written on base of cacheSh7604ALib.s.
*/

#define	_ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

#define _ALIGN_UNCACHED_TEXT	2

#define CCR		0xec		/* 0xffffffec */

/* SH7622 Cache Control Register bit define */
#define C_ENABLE    	0x00000001	/* enable cache */
#define C_WRITE_THROUGH	0x00000002	/* operating mode for area P0
					   U0 and P3
					   1:write-through
					   0:write-back */
#define C_WRITE_BACK   	0x00000004	/* operating mode for area P1
					   1:write-back
					   0:write-through */
#define C_FLUSH	   	0x00000008	/* flushes all cache entries
					   (clears V,U and LRU bits) */

#define CAC_V		0x1
#define CAC_U		0x2	
#define CAC_A		0x8	
#define CAC_LINE_SIZE	16
	
	.text

	.global	_cacheSh7622CCRSetOp
	.global	_cacheSh7622CCRGet
	.global	_cacheSh7622CacheOnOp
	.global	_cacheSh7622CFlushOp
	.global	_cacheSh7622AFlushOp
	.global	_cacheSh7622MFlushOp


/******************************************************************************
*
* cacheSh7622CCRSetOp - set cache control register to a specified value
*	
* This routine modifies CCR, thus it must be executed on P2 region.
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* UINT32 cacheSh7622CCRSetOp (UINT32 ccr)
*       {
*       *CCR = ccr;
*
*       return *CCR;
*       }
*
* NOMANUAL
*/
        .type   _cacheSh7622CCRSetOp,@function
        .align  _ALIGN_UNCACHED_TEXT
 
_cacheSh7622CCRSetOp:
        mov	#CCR,r1
        mov.l   r4,@r1                  /* set CCR */ 
        rts;
        mov.l   @r1,r0                  /* return CCR */
 
/******************************************************************************
*
* cacheSh7622CCRGet - get cache control register value
*
* This routine may be executed on any region.
*
* UINT32 cacheSh7622CCRGetOp (void)
*       {
*       return *CCR;
*       }
*
* NOMANUAL
*/
	.type	_cacheSh7622CCRGet,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7622CCRGet:
	mov	#CCR,r1
	rts;
	mov.l	@r1,r0


/******************************************************************************
*
* cacheSh7622CacheOnOp - turn on/off cache controller
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* STATUS cacheSh7622CacheOnOp (BOOL on)
*	{
*	UINT32 ccr = *CCR;
*	BOOL enabled = ccr & C_ENABLE;
*
*	if (enabled == on)
*	    return ERROR;
*
*	SR |= IMASK;				/@ BLOCK INTERRUPTS @/
*
*	if (on == FALSE)
*	    {
*	    int ix;
*
*	    for (ix = 0; ix <= 0x07f0; ix += 0x10)
*		{
*		*(UINT32 *)(0xf0000000 | ix) &= 0xfffffffc;	/@ clear U&V @/
*		}
*	    }
*
*	*CCR = ccr & ~C_ENABLE;		/@ disable caching @/
*
*	*CCR = ccr | C_FLUSH;		/@ invalidate entire cache @/
*
*	if (on == TRUE)
*	    *CCR = ccr | C_ENABLE;	/@ enable caching @/
*
*	SR &= ~IMASK;				/@ UNBLOCK INTERRUPTS @/
*
*	return OK;
*	}
*
* NOMANUAL
*/

	.type	_cacheSh7622CacheOnOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7622CacheOnOp:
	mov	#CCR,r6
	mov.l	@r6,r5			/* r5: original CCR */
	mov	r5,r0
	tst	#C_ENABLE,r0
	movt	r0			/* 1: disabled, 0: enabled */
	tst	r4,r4
	movt	r1			/* 1: disable,  0: enable */
	cmp/eq	r0,r1
	bt.s	ON_Exit;		/* keep current CCR.CE */
	mov	#-1,r3			/* r3: ERROR */

	mov.l	ON_X000000F0,r0;
	stc	sr,r7			/* r7: original SR */
	or	r7,r0
	ldc	r0,sr			/* BLOCK INTERRUPTS */

	mov	r5,r0
	tst	#C_ENABLE,r0
	bt	ON_FlushDone		/* CE: 0 (cache is disabled) */
	and	#0x6,r0
	cmp/eq	#C_WRITE_THROUGH,r0
	bt	ON_FlushDone		/* CB: 0,  WT: 1 (no copyback region) */

	mov.l	ON_XF0000000,r3		/* r3: 0xf0000000 */
	mov	#0xfc,r2		/* r2: 0xfffffffc */
	
	mov.w	ON_X07F0,r1		/* r1: 0x07f0 */
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
	mov	#(~C_ENABLE),r0
	and	r5,r0
	mov.l	r0,@r6			/* DISABLE CACHE */

	or	#C_FLUSH,r0
	mov.l	r0,@r6			/* invalidate entire cache tags */

	tst	r4,r4
	bt.s	ON_Unblock;
	mov	#0,r3			/* r3: OK */

	mov	r5,r0
	or	#C_ENABLE,r0
	mov.l	r0,@r6			/* ENABLE CACHE */
ON_Unblock:
	ldc	r7,sr			/* UNBLOCK INTERRUPTS */
ON_Exit:
	rts;
	mov	r3,r0			/* return status */

		.align	2
ON_X000000F0:	.long	0x000000f0	/* SR.IMASK */
ON_XF0000000:	.long	0xf0000000	/* cache address array */
ON_XA0000000:	.long	0xa0000000	/* P2 base address for dummy read */
ON_X07F0:	.word	0x07f0
	
/******************************************************************************
*
* cacheSh7622CFlushOp - invalidate entire cache tags by setting CCR.CF bit
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* void cacheSh7622CFlushOp (void)
*	{
*	*CCR |= C_FLUSH;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7622CFlushOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7622CFlushOp:
	mov	#CCR,r1
	mov.l	@r1,r0
	or	#C_FLUSH,r0
	rts;
	mov.l	r0,@r1			/* invalidate entire cache tags */

/******************************************************************************
*
* cacheSh7622AFlushOp - flush cache entries 
*
* This routine invalidates all the entries in the cache and perform 
* writeback whenever there's incoherence between cacache and external 
* memory.
*
* void cacheSh7622AFlushOp
*     (
*     UINT32 ca_begin,
*     UINT32 ca_end
*     )
*     {
*     UINT32 ca;
*  
*     for (ca = ca_begin; ca <= ca_end; ca += CAC_LINE_SIZE)
*         *(UINT32 *)(0xf0000008 | (ca & 0x7f0)) = ca & 0x1ffffc00;
*     }
*
* NOMANUAL
*/	
	.type	_cacheSh7622AFlushOp,@function
	.align	2			/* run on cache thru region */

_cacheSh7622AFlushOp:
	cmp/hi	r5,r4			/* if (ca_end < ca_begin) */
	bt	AI_Exit;		/*     return;            */

	mov.l	AI_XF0000008,r2
	mov.l	AI_X1FFFFC00,r3
	mov.w	AI_X07F0,r6	
AI_Loop:
	mov	r3,r0			/* r0: 0x1ffffc00 */
	mov	r6,r1			/* r1: 0x000007f0 */
	and	r4,r0			/* r0: ca & 0x1ffffc00 */
	and	r4,r1			/* r1: ca & 0x000007f0 */
	or	r2,r1			/* r1: 0xf0000008 | (ca & 0x7f0) */
	add	#CAC_LINE_SIZE,r4
	cmp/hi	r5,r4
	bf.s	AI_Loop
	mov.l	r0,@r1			/* purge cache entry associatively */

AI_Exit:		
	mov.l	AI_XA0000000,r1
	rts;
	mov.l	@r1,r1			/* flush write-buffer by P2-read */

		.align	2
AI_XF0000008:	.long	0xf0000008	/* associative purge region */
AI_X1FFFFC00:	.long	0x1ffffc00
AI_XA0000000:	.long	0xa0000000	/* P2 base address (reset vector) */
AI_X07F0:	.word	0x07f0

/******************************************************************************
*
* cacheSh7622MFlushOp - flush a cache entry by read-modify-writing tag
*
* void cacheSh7622MFlushOp
*     (
*     UINT32 *pt,
*     int     ix,
*     UINT32  ca_begin,
*     UINT32  ca_end
*     )
*     {
*     int key = intLock ();
*     UINT32 tag = *pt;
*  
*     if (tag & TAG_VALID)
*         {
*	  if (ix < 0) /@ force invalidating cache tag @/
*             {
*	      *pt = tag & ~(TAG_USED | TAG_VALID); /@ modify cache tag @/
*	      }
*	  else /@ check cached address @/
*             {  
*	      UINT32 ca = (tag & 0x1ffffc00) | ix;
*  
*             if ((ca >= ca_begin) && (ca <= ca_end))
*                {
*                *(UINT32 *)(CAC_ADRS_ARRAY | ca) = 0;
*                }
*	      }
*         }
*     intUnlock (key);
*     }
*
* NOMANUAL
*/
	.type	_cacheSh7622MFlushOp,@function
	.align	2			/* run on cache thru region */

_cacheSh7622MFlushOp:
	stc	sr,r3			/* r3: key */
	mov	r3,r0
	or	#0xf0,r0
	ldc	r0,sr			/* LOCK INTERRUPTS */

	mov.l	@r4,r0			/* r0: tag */
	tst	#CAC_V,r0
	bt	MI_Exit

	cmp/pz	r5			/* ix >= 0 ? */
	bf	MI_Purge

	mov.l	MI_X1FFFFC00,r2
	and	r0,r2
	or	r5,r2			/* r2: ca = (tag & 0x1ffffc00) | ix */
	cmp/hs	r6,r2			/* if (ca < ca_begin) */
	bf	MI_Exit			/*     goto MI_Exit;  */

	cmp/hi	r7,r2			/* if (ca > ca_end)   */
	bt	MI_Exit			/*     goto MI_Exit;  */

MI_Purge:
	mov	#0xfc,r1		/* r1: 0xfffffffc */
	and	r1,r0			/* clear U and V */
	mov.l	MI_XF0000008,r1
	or	r1,r4
	mov.l	r0,@r4			/* purge cache entry */
	
MI_Exit:
	rts;
	ldc	r3,sr			/* UNLOCK INTERRUPTS */

		.align 2
MI_X1FFFFC00:	.long	0x1ffffC00
MI_XF0000008:	.long	0xf0000008


































