/* cacheSh7604ALib.s - HITACHI SH7604 cache management assembly functions */

/* Copyright 2001-2001 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01a,02feb01,hk   created.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"


#define CCR			0xfe92		/* 0xfffffe92 */

#define MC_ENABLE		0x01	/* enable cache */
#define IC_NOLOAD		0x02	/* disable instruction replace */
#define DC_NOLOAD		0x04	/* disable data replace */
#define MC_2WAY			0x08	/* 2 way cache */
#define MC_PURGE		0x10	/* cache purge */

#define CAC_LINE_SIZE		16

#define TAG_VALID		0x4


	.text

	.global _cacheSh7604CCRGet
	.global	_cacheSh7604CCRSetOp
	.global	_cacheSh7604AInvalOp
	.global	_cacheSh7604MInvalOp

/******************************************************************************
*
* cacheSh7604CCRGet - get cache control register value
*
* This routine may be executed on any region.
*
* UINT8 cacheSh7604CCRGet (void)
*     {
*     return *CCR;
*     }
*
* NOMANUAL
*/
	.type	_cacheSh7604CCRGet,@function
	.align	_ALIGN_TEXT

_cacheSh7604CCRGet:
	mov.w	CG_CCR,r1		/* r1: 0xfffffe92 */
	mov.b	@r1,r0
	rts;
	extu.b	r0,r0

		.align 1
CG_CCR:		.short	0xfe92

/******************************************************************************
*
* cacheSh7604CCRSetOp - set cache control register to a specified value
*
* void cacheSh7604CCRSetOp (UINT8 value)
*   {
*   volatile UINT8 ccr;
* 
*   if (value & MC_ENABLE)
* 	{
* 	int key = intLock ();				/@ LOCK INTERRUPTS @/
* 
* 	if (value & MC_PURGE)
* 	    *CCR = value & ~(MC_PURGE | MC_ENABLE);	/@ disable w/o purge @/
* 
* 	*CCR = value & ~MC_ENABLE;			/@ disable or purge @/
* 
* 	*CCR = value & ~MC_PURGE;			/@ enable @/
* 
* 	ccr = *CCR;					/@ sync pipeline @/
* 
* 	intUnlock (key);				/@ UNLOCK INTERRUPTS @/
* 	}
*   else
* 	{
* 	if (value & MC_PURGE)
* 	    *CCR = value & ~(MC_PURGE | MC_ENABLE);	/@ disable w/o purge @/
* 
* 	*CCR = value & ~MC_ENABLE;			/@ disable or purge @/
* 
* 	ccr = *CCR;					/@ sync pipeline @/
* 	}
*   }
*
* NOMANUAL
*/
	.type	_cacheSh7604CCRSetOp,@function
	.align	2		/* run on cache thru region */

_cacheSh7604CCRSetOp:
	mov.w	CS_CCR,r5	/* r5: 0xfffffe92 */

	extu.b	r4,r4		/* r4: value & 0x000000ff */
	mov	r4,r0
	tst	#MC_ENABLE,r0
	bt	CS_Disable
				/* (value & MC_ENABLE) != 0 */
	stc	sr,r6		/* r6: key */
	mov	r6,r0
	or	#0xf0,r0
	ldc	r0,sr		/* LOCK INTERRUPTS */

	mov	r4,r0
	tst	#MC_PURGE,r0
	bt	CS_NoPurge
				/* (value & MC_PURGE) != 0 */
	and	#0xee,r0
	mov.b	r0,@r5		/* *CCR = value & ~(MC_PURGE | MC_ENABLE); */
CS_NoPurge:
	mov	r4,r0
	and	#0xfe,r0
	mov.b	r0,@r5		/* *CCR = value & ~MC_ENABLE; */

	mov	r4,r0
	and	#0xef,r0
	mov.b	r0,@r5		/* *CCR = value & ~MC_PURGE; */
	mov.b	@r5,r0		/* sync pipeline */
	rts;
	ldc	r6,sr		/* UNLOCK INTERRUPTS */

CS_Disable:			/* (value & MC_ENABLE) == 0 */
	mov	r4,r0
	tst	#MC_PURGE,r0
	bt	CS_NoPurge2
				/* (value & MC_PURGE) != 0 */
	and	#0xee,r0
	mov.b	r0,@r5		/* *CCR = value & ~(MC_PURGE | MC_ENABLE); */
CS_NoPurge2:
	mov	r4,r0
	and	#0xfe,r0
	mov.b	r0,@r5		/* *CCR = value & ~MC_ENABLE; */
	rts;
	mov.b	@r5,r0		/* sync pipeline */

		.align 1
CS_CCR:		.short	0xfe92

/******************************************************************************
*
* cacheSh7604AInvalOp - invalidate cache entries by associative purge loop
*
* This routine may be executed on any region.
*
* void cacheSh7604AInvalOp
*     (
*     UINT32 ca_begin,
*     UINT32 ca_end
*     )
*     {
*     UINT32 ca;
*  
*     for (ca = ca_begin; ca <= ca_end; ca += CAC_LINE_SIZE)
*         *(UINT32 *)(ca | ASSOCIATIVE_PURGE) = 0;
*     }
*
* NOMANUAL
*/
	.type	_cacheSh7604AInvalOp,@function
	.align	2			/* run on cache thru region */

_cacheSh7604AInvalOp:
	cmp/hi	r5,r4			/* if (ca_end < ca_begin) */
	bt	AI_Exit;		/*     return;            */

	mov.l	AI_X40000000,r3		/* r3: ASSOCIATIVE_PURGE */
	mov	#0,r2
AI_Loop:
	mov	r4,r1
	or	r3,r1			/* r1: ca | ASSOCIATIVE_PURGE */
	add	#CAC_LINE_SIZE,r4
	cmp/hi	r5,r4			/* if (ca <= ca_end) */
	bf.s	AI_Loop			/*     goto AI_Loop; */
	mov.l	r2,@r1
AI_Exit:
	rts;
	nop

		.align 2
AI_X40000000:	.long	0x40000000	/* associative purge region */

/******************************************************************************
*
* cacheSh7604MInvalOp - invalidate a cache entry by read-modify-writing tag
*
* void cacheSh7604MInvalOp
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
*         UINT32 ca = (tag & 0x1ffffc00) | ix;
*  
*         if ((ca >= ca_begin) && (ca <= ca_end))
*             {
*             *(UINT32 *)(CAC_ADRS_ARRAY | ca) = 0;
*             }
*         }
*     intUnlock (key);
*     }
*
* NOMANUAL
*/
	.type	_cacheSh7604MInvalOp,@function
	.align	2			/* run on cache thru region */

_cacheSh7604MInvalOp:
	stc	sr,r3			/* r3: key */
	mov	r3,r0
	or	#0xf0,r0
	ldc	r0,sr			/* LOCK INTERRUPTS */

	mov.l	@r4,r0			/* r0: tag */
	tst	#TAG_VALID,r0
	bt	MI_Exit

	mov.l	MI_X1FFFFC00,r2
	and	r0,r2
	or	r5,r2			/* r2: ca = (tag & 0x1ffffc00) | ix */
	cmp/hs	r6,r2			/* if (ca < ca_begin) */
	bf	MI_Exit			/*     goto MI_Exit;  */

	cmp/hi	r7,r2			/* if (ca > ca_end)   */
	bt	MI_Exit			/*     goto MI_Exit;  */

	mov.l	MI_X60000000,r1
	or	r1,r2
	mov	#0,r1
	mov.l	r1,@r2			/* *(CAC_ADRS_ARRAY | ca) = 0 */
MI_Exit:
	rts;
	ldc	r3,sr			/* UNLOCK INTERRUPTS */

		.align 2
MI_X1FFFFC00:	.long	0x1ffffc00
MI_X60000000:	.long	0x60000000

/* r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 r15 jsr */
