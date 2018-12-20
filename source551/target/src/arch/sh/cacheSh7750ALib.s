/* cacheSh7750ALib.s - HITACHI SH7750 cache management assembly function */

/* Copyright 1998-2002 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01l,18nov02,h_k  fixed for IC index mode (SPR #81126).
01k,20nov01,hk   added cacheSh7750ILineInvalOp().
01j,03oct01,frf  modified cacheSh7750TClearOp() function, way information not 
	         necessary. Modified cacheSh7750IInvalOp() function, ass. purge 
                 by comparison in each way (enhanced mode).
01i,06jun01,frf  added 2way enhanced mode for SH7751R support.
01h,04mar01,hk   secure 8 insns before rts after modifying cache tag. fix tag
		 mask to 0xfffffc00 (was 0x1ffffc00) in cacheSh7750IInvalOp.
01g,06dec00,hk   fixed ocbwb machine code (was 0x00d3). also changed ocbi/ocbp
		 to use mnemonics. added misc cache tag control functions.
01f,27mar00,hk   added .type directive to function names.
01e,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01d,24feb99,hk   fixed copyright year.
01c,09oct98,hk   code review: added NULL check. merged conditional branches.
01b,20sep98,hk   code review: deleted cacheSh7750CCRWrite.
01a,24aug98,st   written.
*/

#define	_ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

#define _ALIGN_UNCACHED_TEXT	2

#define CCR_OC_RAM_ENABLE	0x20		/* CCR.ORA */
#define CCR_OC_INVALIDATE	0x08		/* CCR.OCI */
#define CCR_WRITE_BACK_P1	0x04		/* set P1 to copy-back */
#define CCR_WRITE_THRU		0x02		/* set P0/P3 to write-thru */
#define CCR_OC_ENABLE		0x01		/* enable operand cache */

#define DCACHE_LINE_SIZE	32
#define ICACHE_LINE_SIZE	32

#define MMU_REGS_BASE		   0xff000000
#define PTEH		0x00	/* 0xff000000: Page Table Entry High  */
#define PTEL		0x04	/* 0xff000004: Page Table Entry Low   */
#define TTB		0x08	/* 0xff000008: Translation Table Base */
#define MMUCR		0x10	/* 0xff000010: MMU Control Register */

	.text

	.global	_cacheSh7750CCRSetOp
	.global	_cacheSh7750CCRGet
	.global	_cacheSh7750DCacheOnOp
	.global	_cacheSh7750DFlushAllOp
	.global	_cacheSh7750DClearAllOp
	.global	_cacheSh7750IInvalOp
	.global	_cacheSh7750ILineInvalOp
	.global	_cacheSh7750TInvalOp
	.global	_cacheSh7750TFlushOp
	.global	_cacheSh7750TClearOp
	.global	_cacheSh7750DFlush
	.global	_cacheSh7750DInvalidate
	.global	_cacheSh7750DClear
	.global	_cacheSh7750PipeFlush

/******************************************************************************
*
* cacheSh7750CCRSetOp - set cache control register to a specified value
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* UINT32 cacheSh7750CCRSetOp (UINT32 ccr)
*       {
*       *CCR = ccr;
*
*	return *CCR;
*       }
*
* NOMANUAL
*/
	.type	_cacheSh7750CCRSetOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750CCRSetOp:
	mov.l	CS_XFF00001C,r1
	mov.l	r4,@r1			/* set CCR */

	nop; nop; nop; nop		/* secure 8 insns before rts */
	nop; nop; nop; nop

	rts;
	mov.l	@r1,r0			/* return CCR */

		.align	2
CS_XFF00001C:	.long	0xff00001c	/* CCR address in P4 */

/******************************************************************************
*
* cacheSh7750CCRGet - get cache control register value
*
* This routine may be executed on any region.
*
* UINT32 cacheSh7750CCRGet (void)
*       {
*       return *CCR;
*       }
*
* NOMANUAL
*/
	.type	_cacheSh7750CCRGet,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750CCRGet:
	mov.l	CG_XFF00001C,r1
	rts;
	mov.l	@r1,r0

		.align	2
CG_XFF00001C:	.long	0xff00001c		/* CCR address in P4 */

/******************************************************************************
*
* cacheSh7750DCacheOnOp - turn on/off cache controller
*
* This routine modifies CCR, thus it must be executed on P2 region.
*
* STATUS cacheSh7750DCacheOnOp (BOOL on)
*	{
*	UINT32 ccr = *CCR;
*	BOOL enabled = ccr & CCR_OC_ENABLE;
*
*	if (enabled == on)
*	    return ERROR;
*
*	SR |= BL;				/@ BLOCK INTERRUPTS @/
*
*	if ((ccr & CCR_OC_ENABLE) &&
*	    ((ccr & (CCR_WRITE_BACK_P1 | CCR_WRITE_THRU) != CCR_WRITE_THRU) ||
*	     (*MMUCR & AT)))
*	    {
*	    cacheSh7750DClearAll ();
*	    cacheSh7750PipeFlush ();
*	    }
*
*	*CCR = ccr & ~CCR_OC_ENABLE;		/@ disable D-cache @/
*
*	*CCR = ccr | CCR_OC_INVALIDATE;		/@ invalidate entire D-cache @/
*
*	if (on == TRUE)
*	    *CCR = ccr | CCR_OC_ENABLE;		/@ enable D-cache @/
*
*	SR &= ~BL;				/@ UNBLOCK INTERRUPTS @/
*
*	return OK;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7750DCacheOnOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750DCacheOnOp:
	mov.l	r8,@-sp
	mov.l	r9,@-sp
	mov.l	r10,@-sp
	sts.l	pr,@-sp

	bsr	_cacheSh7750CCRGet;
	mov	r4,r8			/* r8: on */
	mov	r0,r9			/* r9: original CCR */
	tst	#CCR_OC_ENABLE,r0
	movt	r0			/* 1: disabled, 0: enabled */
	tst	r8,r8
	movt	r1			/* 1: disable,  0: enable */
	cmp/eq	r0,r1
	bt.s	DO_Exit;		/* keep current CCR.OCE */
	mov	#-1,r3			/* r3: ERROR */

	mov.l	DO_X10000000,r0;
	stc	sr,r10			/* r10: original SR */
	or	r10,r0
	ldc	r0,sr			/* BLOCK INTERRUPTS */

	mov	r9,r0
	tst	#CCR_OC_ENABLE,r0
	bt	DO_FlushDone		/* CE: 0 (D-cache is disabled) */

	and	#(CCR_WRITE_BACK_P1 | CCR_WRITE_THRU),r0
	cmp/eq	#CCR_WRITE_THRU,r0
	bf	DO_Flush
					/* CB: 0,  WT: 1 (no copyback region) */
	mov.l	DO_XFF000010,r1
	mov.l	@r1,r0			/* r0: MMUCR */
	tst	#0x1,r0			/* if (MMUCR.AT == 0) */
	bt	DO_FlushDone		/*    skip flushing */
DO_Flush:
	bsr	_cacheSh7750DClearAllOp;
	nop				/* flush & invalidate entire D-cache */
	bsr	_cacheSh7750PipeFlush;
	nop				/* flush write-back buffer by P2-read */
DO_FlushDone:
	mov	#(~CCR_OC_ENABLE),r4
	bsr	_cacheSh7750CCRSetOp;
	and	r9,r4			/* disable D-cache */

	or	#CCR_OC_INVALIDATE,r0
	bsr	_cacheSh7750CCRSetOp;
	mov	r0,r4			/* invalidate entire D-cache tags */

	tst	r8,r8
	bt.s	DO_Unblock;
	mov	#0,r3			/* r3: OK */

	or	#CCR_OC_ENABLE,r0
	bsr	_cacheSh7750CCRSetOp;
	mov	r0,r4			/* enable D-cache */
DO_Unblock:
	ldc	r10,sr			/* UNBLOCK INTERRUPTS */
DO_Exit:
	lds.l	@sp+,pr
	mov.l	@sp+,r10
	mov.l	@sp+,r9
	mov.l	@sp+,r8
	rts;
	mov	r3,r0			/* return status */

		.align	2
DO_X10000000:	.long	0x10000000	/* SR.BL */
DO_XFF000010:	.long	0xff000010	/* MMUCR */

/******************************************************************************
*
* cacheSh7750DFlushAllOp - flush entire D-cache tags
*
* STATUS cacheSh7750DFlushAllOp ()
*
* NOMANUAL
*/
	.type	_cacheSh7750DFlushAllOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750DFlushAllOp:
	bra	DC_Init;
	mov	#0xfd,r4

/******************************************************************************
*
* cacheSh7750DClearAllOp - clear entire D-cache tags
*
* STATUS cacheSh7750DClearAllOp ()
*	{
*	int ix;
*	insigned int iway = 0; 
*	unsigned int nMaxWay = 0;			/@ only one way @/
*	unsigned int nMaxEntry = 128; 
*
*	SR |= BL;					/@ BLOCK INTERRUPTS @/
*
*	/@ Enhanced mode ? @/	
*	if (ccr & CCR_2WAY_EMODE)
*	    {
*	    nMaxEntry = 256;
*
*	/@ The enhanced mode with half cache enabled reserves the 
*	 @ entire sencond way for RAM space and the first way entries still
*	 @ remain for cache. Therefore with full cache mode, increase
*	 @ the max number of way to 2.
*	 @/
*			
*	    if ((ccr & CCR_OC_RAM_ENABLE) == 0)			
*		nMaxWay = 1;				/@ two ways @/
*	    }	
*
*	for (iway = nMaxWay << 14; iway >= 0; iway -= 0x4000)
*	   {
*		/@   0-127 or 0-255 in enhanced mode @/
*	   for (ix = 0; ix <= nMaxEntry; ix += 0x20)
*		*(UINT32 *)(0xf4000000 | iway | ix) &= 0xfffffffc;	
*
*		/@   255-383 or 255-511 in enhanced mode @/
*	   for (ix = 0; ix <= nMaxEntry; ix += 0x20)
*		*(UINT32 *)(0xf4002000 | iway | ix) &= 0xfffffffc;	
*
*	   /@ if not in RAM mode, only for compatible way @/
*	   if ((ccr & CCR_OC_RAM_ENABLE == 0) 
*		&& (ccr & CCR_2WAY_EMODE) == 0))
*		{
*			/@ 128-255 @/
*		for (ix = 0; ix <= 0xfe0; ix += 0x20)
*			*(UINT32 *)(0xf4001000 | iway | ix) &= 0xfffffffc;
*			/@ 384-511 @/
*		for (ix = 0; ix <= 0xfe0; ix += 0x20)
*			*(UINT32 *)(0xf4003000 | iway | ix) &= 0xfffffffc;	
*		}
*	    }
*
*	SR &= ~BL;					/@ UNBLOCK INTERRUPTS @/
*
*	return OK;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7750DClearAllOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750DClearAllOp:
	mov	#0xfc,r4

DC_Init:
        mov.l   DC_X10000000,r0;
        stc     sr,r7                   /* r7: original SR */
        or      r7,r0
        ldc     r0,sr                   /* BLOCK INTERRUPTS */
 
        mov.w   DC_X2000,r6             /* r6: 0x2000 */
	mov.w   DC_128,r3
	mov     #0,r5			/* nMaxWay = 0 */
        mov.l   DC_XFF00001C,r1
        mov.l   @r1,r0                  /* r0: ccr */
        mov.l   DC_X80000000,r1
        tst     r1,r0                   /* if ( ccr & CCR_2WAY_EMODE ) */
        bt	DC_WayLoop		/* ...no EMode, go to DC_NoEMode */
	shll	r3			/* r3: 256 */
	tst     #CCR_OC_RAM_ENABLE,r0	/* if (ccr & CCR_OC_RAM_ENABLE) */
	bf      DC_WayLoop		/* with RAM mode only one way */
	nop
	mov	#1,r5			/* nMaxWay = 1 */
	 
DC_WayLoop:
	shll16	r5
	shlr2	r5
        mov.l   DC_XF4000000,r0         /* r0: 0xf4000000 */
	or	r5,r0			/* r0: 0xf4000000 | iway */

DC_Loop:
     /* flush 0-127 or 0-255 */   /* flush 256-383 or 256-511  */
        mov.l   @r0,r1;         mov.l   @(r0,r6),r2
        and     r4,r1;          and     r4,r2
        mov.l   r1,@r0;         mov.l   r2,@(r0,r6)
 
        add     #DCACHE_LINE_SIZE,r0
        dt      r3
        bf      DC_Loop
	
	mov.l	DC_XFF00001C,r1
	mov.l	@r1,r0			/* r0: ccr */
	tst	#CCR_OC_RAM_ENABLE,r0
	bf	DC_NextWay

        mov.l   DC_X80000000,r1
	mov.w   DC_128,r3
        tst     r1,r0                   /* if ( ccr & CCR_2WAY_EMODE ) */
	bf/s	DC_NextWay		/* EMode? go to the next way */
	shll	r3			/* r3: 256 */
	
	mov.l	DC_XF4001000,r0		/* r0: 0xf4001000 */
DC_Loop2:
	/* flush 128-255 */	/* flush 384-511 */
	mov.l	@r0,r1;		mov.l	@(r0,r6),r2
	and	r4,r1;		and	r4,r2
	mov.l	r1,@r0;		mov.l	r2,@(r0,r6)

	add	#DCACHE_LINE_SIZE,r0
	dt	r3
	bf	DC_Loop2
	
DC_NextWay:             
	shlr8	r5;	shlr2	r5
	shlr2	r5;	shlr2	r5
	mov	#1,r2
	clrt 
	subc	r2,r5			/* iway -= 0x4000 */ 
        bf	DC_WayLoop

        nop; nop; nop; nop              /* secure 8 insns before rts */
        nop; nop; nop; nop              /* XXX these 4 nops may not necessary */
 
        ldc     r7,sr                   /* UNBLOCK INTERRUPTS */
        rts;
        mov     #0,r0                   /* return OK */

		.align	2
DC_X80000000:	.long	0x80000000	/* CCR.EMODE */
DC_X10000000:	.long	0x10000000	/* SR.BL */
DC_XFF00001C:	.long	0xff00001c	/* CCR address in P4 */
DC_XF4000000:	.long	0xf4000000	/* D-cache address array */
DC_XF4001000:	.long	0xf4001000	/* D-cache address array */
DC_XF4002000:	.long	0xf4002000	/* D-cache address array */
DC_X2000:	.word	0x2000
DC_128:		.word	128
	
	
/******************************************************************************
*
* cacheSh7750IInvalOp - invalidate I-cache entries by associative purge
*
* This routine clears V-bit in I-cache address array associatively. Note that
* this operation does nothing if SH7750 MMU mishits I-TLB, thus this routine
* is not reliable if MMU is enabled.  This routine has to be executed on P2.
*
* STATUS cacheSh7750IInvalOp (void *from, size_t bytes)
*     {
*     UINT32 ca = (UINT32)from & 0xffffffe0;
*
*     if (bytes == 0) return OK;
*
*     if (*CCR & CCR_IC_INDEX_ENABLE)
*         while (ca < (UINT32)from + bytes)
*             {
*             /@ In enhanced mode the A bit force an associative purge
*              @ by a comparison of the tag stored in the entry of each
*              @ way. Therefore the way bit 13 is not used.        ^^^^
*              @/
*             *(UINT32 *)(0xf0000008 | (ca & 0xfe0) | ((ca & 0x2000000) >> 13))
*                                                       = ca & 0xfffffc00;
*
*             ca += ICACHE_LINE_SIZE;
*             }
*     else
*         while (ca < (UINT32)from + bytes)
*             {
*             /@ In enhanced mode the A bit force an associative purge
*              @ by a comparison of the tag stored in the entry of each
*              @ way. Therefore the way bit 13 is not used.        ^^^^
*              @/
*             *(UINT32 *)(0xf0000008 | (ca & 0x1fe0)) = ca & 0xfffffc00;
*
*             ca += ICACHE_LINE_SIZE;
*             }
*
*     return OK;
*     }
*
* RETURNS: OK, always.
*
* NOMANUAL
*/
	.type	_cacheSh7750IInvalOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750IInvalOp:
	tst	r5,r5			/* if (bytes == 0) */
	bt	II_Exit			/*     return OK;  */

	mov.l	II_XF0000008,r2
	add	r4,r5			/* r5: from + bytes */
	mov.w	II_XFC00,r3		/* r3: 0xfffffc00 */
	mov	#0xe0,r0		/* r0: 0xffffffe0 */
	mov.l	II_XFF00001C,r1		/* r1: CCR address */
	mov.l	@r1,r1			/* r1: CCR value */
	mov	#0x80,r7
	extu.b	r7,r7
	shll8	r7			/* r7: CCR_IC_INDEX_ENABLE */
	tst	r7,r1			/* check CCR_IC_INDEX_ENABLE bit */
	bf.s	II_Index_Mode		/* if on, go to II_Index_Mode */
	and	r0,r4			/* r4: ca = from & 0xffffffe0 */

	mov.w	II_X1FE0,r6		/* r6: 0x00001fe0 (each way) */
II_Loop:
	cmp/hs	r5,r4			/* if (from + bytes <= ca) */
	bt	II_Exit			/*     return OK;          */

	mov	r3,r0			/* r0: 0xfffffc00 */
	mov	r6,r1			/* r1: 0x00001fe0 */
	and	r4,r0			/* r0: ca & 0xfffffc00 */
	and	r4,r1			/* r1: ca & 0x00001fe0 */
	or	r2,r1			/* r1: 0xf0000008 | (ca & 0x1fe0) */

	mov.l	r0,@r1			/* purge cache entry associatively */
	bra	II_Loop;
	add	#ICACHE_LINE_SIZE,r4	/* ca += ICACHE_LINE_SIZE */

II_Index_Mode:
	mov.w	II_XFE0,r6		/* r6: 0x00000fe0 */
	mov	#0x2,r7
	shll16	r7
	shll8	r7			/* r7: 0x02000000 */
II_Loop_Index:
	cmp/hs	r5,r4			/* if (from + bytes <= ca) */
	bt	II_Exit			/*     return OK;          */

	mov	r6,r1			/* r1: 0x00000fe0 */
	and	r4,r1			/* r1: ca & 0x00000fe0 */
	or	r2,r1			/* r1: 0xf0000008 | (ca & 0xfe0) */
	tst	r7,r4			/* check A25 bit */
	bt	II_A25_Off		/* if off, keep A12 bit off */

	mov	#0x10,r0		/* if on, enable A12 bit */
	shll8	r0			/* r0: 0x00001000 */
	or	r0,r1			/* r1: 0xf0001008 | (ca & 0xfe0) */
II_A25_Off:
	mov	r3,r0			/* r0: 0xfffffc00 */
	and	r4,r0			/* r0: ca & 0xfffffc00 */
	mov.l	r0,@r1			/* purge cache entry associatively */
	bra	II_Loop_Index;
	add	#ICACHE_LINE_SIZE,r4	/* ca += ICACHE_LINE_SIZE */

II_Exit:
	nop; nop; nop; nop		/* secure 8 insns before rts */
	nop; nop; nop; nop		/* XXX these 4 nops may not necessary */
	rts;
	mov	#0,r0			/* return OK */

		.align	2
II_XF0000008:	.long	0xf0000008	/* associative purge region */
II_XFF00001C:	.long	0xff00001c	/* CCR address in P4 */
II_XFC00:	.word	0xfc00
II_X1FE0:	.word	0x1fe0		/* comparison done in each way */
II_XFE0:	.word	0xfe0

/******************************************************************************
*
* cacheSh7750ILineInvalOp - invalidate a I-cache entry with MMU enabled
*
* This routine invalidates an instruction cache entry for a specified virtual
* address.  Note that an associative I-cache invalidation results in nop if
* the specified address mishits I-TLB.  This routine refills I-TLB before
* invalidating I-cache so that it always success invalidating an instruction
* cache entry even if MMU is enabled.  This routine has to be executed on P2.
*
* STATUS cacheSh7750ILineInval (void *va)   /@ virtual address to invalidate @/
*     {
*     UINT32 ie, ue, lrui;
*     UINT32 key = excBlock ();                     /@ BLOCK EXCEP (SR.BL=1) @/
*     UINT32 asid  = *(UINT32 *)0xff000000 & 0xff;  /@ PTEH.ASID (for AE) @/
*     UINT32 mmucr = *(UINT32 *)0xff000010;         /@ MMUCR @/
*
*     /@ once invalidate U-TLB and I-TLB associatively (set D,~V) @/
*
*     *(UINT32 *)0xf6000080 = ((UINT32)va & 0xfffffc00) | 0x200 | asid;
*
*     /@ reload U-TLB @/
*
*     if (mmuStub (va) != OK)                       /@ mmuStub() without rte @/
*         {
*         excUnblock (key);                         /@ UNBLOCK EXCEPTION @/
*         return ERROR;
*         }
*
*     ue = (mmucr >> 2) & 0x00003f00;               /@ extract MMUCR.URC @/
*
*     /@ figure out the Least Recently Used I-TLB entry @/
*
*     lrui = mmucr >> 26;                           /@ extract MMUCR.LRUI @/
*
*     if      ((lrui & 0x38) == 0x38) ie = 0x000;   /@ simulate LRU algoritm @/
*     else if ((lrui & 0x26) == 0x06) ie = 0x100;
*     else if ((lrui & 0x15) == 0x01) ie = 0x200;
*     else if ((lrui & 0x0b) == 0x00) ie = 0x300;
*     else
*         {
*         excUnblock (key);                         /@ UNBLOCK EXCEPTION @/
*         return ERROR;                             /@ this should not happen @/
*         }
*
*     /@ copy just loaded U-TLB entry (PTEH/PTEL/PTEA) to I-TLB @/
*
*     *(UINT32 *)(0xf2000000 | ie) = *(UINT32 *)(0xf6000000 | ue);  /@ pteh @/
*     *(UINT32 *)(0xf3000000 | ie) = *(UINT32 *)(0xf7000000 | ue);  /@ ptel @/
*     *(UINT32 *)(0xf3800000 | ie) = *(UINT32 *)(0xf7800000 | ue);  /@ ptea @/
*
*     /@ invalidate I-cache associatively (set ~V, I-TLB hit assured) @/
*
*     if (*CCR & CCR_IC_INDEX_ENABLE)
*         *(UINT32 *)(0xf0000008 | ((UINT32)va & 0xfe0) |
*                     ((va & 0x2000000) >> 13)) = (UINT32)va & 0xfffffc00;
*     else
*         *(UINT32 *)(0xf0000008 | ((UINT32)va & 0x1fe0))
*                                               = (UINT32)va & 0xfffffc00;
*
*     excUnblock (key);                             /@ UNBLOCK EXCEPTION @/
*     return OK;
*     }
*
* RETURNS: OK, or ERROR
*
* NOMANUAL
*/
	.type	_cacheSh7750ILineInvalOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750ILineInvalOp:		/* r4: va */
	mov.l	IL_X10000000,r0;	/* r0: SR.BL bit */
	stc	sr,r7			/* r7: old sr */
	or	r7,r0
	ldc	r0,sr			/* BLOCK INTERRUPT/EXCEPTION */

	mov.l	IL_MmuRegsBase,r3;	/* r3: 0xff000000 */
	mov	#0xfc,r1
	mov	r4,r6
	shll8	r1			/* r1: 0xfffffc00 */
	mov.l	@(PTEH,r3),r0;
	and	r1,r6			/* r6: va & 0xfffffc00 */
	and	#0xff,r0		/* r0: PTEH.ASID */
	or	r6,r0			/* r0: (va & 0xfffffc00) | ASID */
	mov.l	r0,@(PTEH,r3)		/* update PTEH */

	mov	#2,r1
	shll8	r1			/* r1: 0x200 (UTLB: D, ~V) */
	mov.l	IL_XF6000080,r2;	/* r2: U-TLB address array with A-bit */
	or	r1,r0			/* r0: (va & 0xfffffc00)|0x200|ASID */
	mov.l	r0,@r2			/* once invalidate U-TLB and I-TLB */

	mov	#-10,r0
	mov	r6,r1			/* r1:ABCDEFGHIJKLMNOPQRSTUV0000000000*/
	shld	r0,r1			/* r1:0000000000ABCDEFGHIJKLMNOPQRSTUV*/
	mov.w	IL_X0FFC,r2;		/* r2:00000000000000000000111111111100*/
	mov	#-12,r0
	and	r1,r2			/* r2:00000000000000000000KLMNOPQRST00*/
	shld	r0,r1			/* r1:0000000000000000000000ABCDEFGHIJ*/
	mov.l	@(TTB,r3),r0;
	shll2	r1			/* r1:00000000000000000000ABCDEFGHIJ00*/
	mov.l	@(r0,r1),r0;		/* r0: --> PTELs table */
	cmp/eq	#-1,r0
	bt	IL_Err
	mov.l	@(r0,r2),r1;		/* r1: PTEL entry to load */
	swap.b	r1,r0
	tst	#0x01,r0		/* invalid if PTEL.V (bit8) is zero */
	bt	IL_Err
	mov.l	r1,@(PTEL,r3)		/* update PTEL */
	ldtlb				/* load PTEH/PTEL/PTEA to U-TLB */

	mov.l	@(MMUCR,r3),r1;		/* extract URC and LRUI from MMUCR */
	shlr2	r1
	swap.b	r1,r0
	and	#0x3f,r0		/* r0: MMUCR.URC */
	swap.b	r0,r2			/* r2: U-TLB entry specifier */
	mov	#-24,r0
	shld	r0,r1			/* r1: MMUCR.LRUI */
	mov	r1,r0			/* simulate I-TLB LRU algorithm */
	and	#0x38,r0
	cmp/eq	#0x38,r0
	bt.s	IL_LoadItlb0		/* if ((LRUI & 0x38)==0x38) ie=0x000; */
	mov	r1,r0
	and	#0x26,r0
	cmp/eq	#0x06,r0
	bt.s	IL_LoadItlb1		/* if ((LRUI & 0x26)==0x06) ie=0x100; */
	mov	r1,r0
	and	#0x15,r0
	cmp/eq	#0x01,r0
	bt.s	IL_LoadItlb2		/* if ((LRUI & 0x15)==0x01) ie=0x200; */
	mov	r1,r0
	tst	#0x0b,r0
	bt.s	IL_LoadItlb		/* if ((LRUI & 0x0b)==0x00) ie=0x300; */
	mov	#3,r3
IL_Err:
	bra	IL_Exit;		/* else             */
	mov	#-1,r0			/*     return ERROR;*/

IL_X0FFC:	.word	0x0ffc
		.align	2
IL_X10000000:	.long	0x10000000
IL_MmuRegsBase:	.long	MMU_REGS_BASE
IL_XF6000080:	.long	0xf6000080

IL_LoadItlb0:
	bra	IL_LoadItlb;
	mov	#0,r3
IL_LoadItlb1:
	bra	IL_LoadItlb;
	mov	#1,r3
IL_LoadItlb2:
	mov	#2,r3
IL_LoadItlb:				/* r2: U-TLB entry specifier */
	shll8	r3			/* r3: I-TLB entry specifier */
					/* r4: va */
					/* r6: va & 0xfffffc00 */
	mov.l	IL_XF6000000,r0;
	mov.l	@(r0,r2),r1;		/* copy UTLB.PTEH */
	mov.l	IL_XF2000000,r0;
	mov.l	r1,@(r0,r3);		/* load ITLB.PTEH */
	mov.l	IL_XF7000000,r0;
	mov.l	@(r0,r2),r1;		/* copy UTLB.PTEL */
	mov.l	IL_XF3000000,r0;
	mov.l	r1,@(r0,r3);		/* load ITLB.PTEL */
	mov.l	IL_XF7800000,r0;
	mov.l	@(r0,r2),r1;		/* copy UTLB.PTEA */
	mov.l	IL_XF3800000,r0;
	mov.l	r1,@(r0,r3);		/* load ITLB.PTEA */

	mov.l	IL_XFF00001C,r1		/* r1: CCR address */
	mov.l	@r1,r1			/* r1: CCR value */
	mov	#0x80,r0
	extu.b	r0,r0
	shll8	r0			/* r0: CCR_IC_INDEX_ENABLE */
	tst	r0,r1			/* check CCR_IC_INDEX_ENABLE bit */
	bt	IL_No_Index_Mode	/* if off, go to IL_No_Index_Mode */

	mov.w	IL_XFE0,r1;
	mov	#0x20,r0
	shll16	r0
	shll8	r0			/* r0: 0x02000000 */
	tst	r0,r4			/* check A25 bit */
	bt.s	IL_A25_Off		/* if off, keep A12 bit off */
	and	r1,r4			/* r4: va & 0xfe0 */

	mov.l	IL_XF0001008,r0;	/* if on, enable A12 bit */
	bra	IL_Inval
	or	r0,r4			/* r4: 0xf0001008 | (va & 0xfe0) */

IL_No_Index_Mode:
	mov.w	IL_X1FE0,r1;
	and	r1,r4			/* r4: va & 0x1fe0 */
IL_A25_Off:
	mov.l	IL_XF0000008,r0;
	or	r0,r4			/* r4: 0xf0000008 | (va & 0xxfe0) */
IL_Inval:
	mov.l	r6,@r4			/* invalidate I-cache associatively */
	nop				/* secure 8 insn before leaving P2 */
	nop
	nop
	nop
	nop
	nop
	mov	#0,r0			/* return OK */
IL_Exit:
	ldc	r7,sr			/* UNBLOCK INTERRUPT/EXCEPTION */
	rts;
	nop

IL_XFE0:	.word	0xfe0
IL_X1FE0:	.word	0x1fe0
		.align	2
IL_XF6000000:	.long	0xf6000000	/* U-TLB address array */
IL_XF7000000:	.long	0xf7000000	/* U-TLB data array 1 */
IL_XF7800000:	.long	0xf7800000	/* U-TLB data array 2 */
IL_XF2000000:	.long	0xf2000000	/* I-TLB address array */
IL_XF3000000:	.long	0xf3000000	/* I-TLB data array 1 */
IL_XF3800000:	.long	0xf3800000	/* I-TLB data array 2 */
IL_XFF00001C:	.long	0xff00001c	/* CCR address in P4 */
IL_XF0000008:	.long	0xf0000008	/* I-cache address array with A-bit */
IL_XF0001008:	.long	0xf0001008	/* I-cache address array with A-bit
					   and A25-bit */

/******************************************************************************
*
* cacheSh7750TInvalOp - clear V bit of cache tag
*
* NOMANUAL
*/
	.type	_cacheSh7750TInvalOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750TInvalOp:
	bra	TC_Init;
	mov	#0xfe,r3		/* r3: 0xfffffffe  ~V */

/******************************************************************************
*
* cacheSh7750TFlushOp - clear U bit of cache tag
*
* NOMANUAL
*/
	.type	_cacheSh7750TFlushOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750TFlushOp:
	bra	TC_Init;
	mov	#0xfd,r3		/* r3: 0xfffffffd  ~U */

/******************************************************************************
*
* cacheSh7750TClearOp - clear U & V bits of cache tag
*
* This routine blocks interrupts to assure an atomic read-modify-write
* of cache tag, thus it must be executed on P2 region.
*
* STATUS cacheSh7750TClearOp (UINT32 *pt, int ix, UINT32 from, UINT32 to)
*	{
*	UINT32 tag;
*
*	SR |= BL;				/@ BLOCK INTERRUPTS @/
*
*	tag = *pt;				/@ read cache tag @/
*
*	if (tag & (TAG_USED | TAG_VALID))
*	    {
*	    if (ix < 0) /@ force invalidating cache tag @/
*		{
*		*pt = tag & ~(TAG_USED | TAG_VALID); /@ modify cache tag @/
*		}
*	    else /@ check cached address @/
*		{
*		UINT32 ca = (tag & 0xfffffc00) | (ix & 0x3ff);
*
*		if (ca >= from && ca <= to)
*		    *pt = tag & ~(TAG_USED | TAG_VALID); /@ modify cache tag @/
*		}
*	    }
*
*	SR &= ~BL;				/@ UNBLOCK INTERRUPTS @/
*
*	return OK;
*	}
*
* NOMANUAL
*/
	.type	_cacheSh7750TClearOp,@function
	.align	_ALIGN_UNCACHED_TEXT

_cacheSh7750TClearOp:
	mov	#0xfc,r3		/* r3: 0xfffffffc  ~(U|V) */

TC_Init:				/* r4: &tag, r5: ix, r6: from, r7: to */
	mov.l	r8,@-sp

	mov.l	TC_X10000000,r0;
	stc	sr,r8			/* r8: original SR */
	or	r8,r0
	ldc	r0,sr			/* BLOCK INTERRUPTS */

	mov.l	@r4,r0			/* r0: cache tag */
	tst	#0x01,r0		/* TAG_VALID? */
	bt	TC_Done

	cmp/pz	r5			/* ix >= 0 ? */
	bf	TC_Purge

	mov.l	TC_XFFFFFC00,r1
	and	r0,r1			/* r1: tag & 0xfffffc00 */
	mov.w	TC_X03FF,r2
	and	r5,r2			/* r2: ix & 0x3ff */
	or	r2,r1			/* r1: ca (cached address) */

	cmp/hs	r6,r1			/* ca_begin <= ca ? */
	bf	TC_Done
	cmp/hs	r1,r7			/* ca <= ca_end ? */
	bf	TC_Done
TC_Purge:
	and	r3,r0			/* clear U & V */
	mov.l	r0,@r4			/* purge cache entry */

	nop; nop; nop; nop		/* secure 8 insns before rts */
	nop; nop; nop; nop
TC_Done:
	ldc	r8,sr			/* UNBLOCK INTERRUPTS */
	mov.l	@sp+,r8
	rts;
	mov	#0,r0			/* return OK */

		.align	2
TC_X10000000:	.long	0x10000000	/* SR.BL */
TC_XFFFFFC00:	.long	0xfffffc00
TC_X03FF:	.word	0x03ff

/******************************************************************************
*
* cacheSh7750DFlush - flush some entries from SH7750 D-cache
*
* STATUS cacheSh7750DFlush (void *from, size_t bytes);
*	{
*	UINT32 ca, ca_nop;
*
*	if (bytes == 0) return OK;
*
*	ca = (UINT32)from & 0xffffffe0;
*	ca_nop = (UINT32)from + bytes;
*
*	while (ca < ca_nop)
*	    {
*	    ocbwb (ca);
*
*	    ca += 32;
*	    }
*	return OK;
*	}
*
* RETURNS: OK, always.
*
* NOMANUAL
*/
	.type	_cacheSh7750DFlush,@function
	.align	_ALIGN_TEXT

_cacheSh7750DFlush:
	tst	r5,r5		/* if (bytes == 0) */
	bt	OCFend		/*     return OK;  */

	mov	#0xe0,r0	/* r0: 0xffffffe0 */
	and	r4,r0		/* r0 -> (current cache line) */

	add	r4,r5		/* r5 -> (last adrs to flush) + 1 */

OCFlp:	cmp/hs	r5,r0		/* if (r5 <= r0)  */
	bt	OCFend		/*     return OK; */

	ocbwb	@r0		/* write back, no invalidation */

	bra	OCFlp;
	add	#32,r0		/* r0 -> (next cache line) */

OCFend:	rts;
	mov	#0,r0		/* return OK */

/******************************************************************************
*
* cacheSh7750DInvalidate - invalidate some entries from SH7750 D-cache
*
* STATUS cacheSh7750DInvalidate (void *from, size_t bytes);
*
* RETURNS: OK, always.
*
* NOMANUAL
*/
	.type	_cacheSh7750DInvalidate,@function
	.align	_ALIGN_TEXT

_cacheSh7750DInvalidate:
	tst	r5,r5		/* if (bytes == 0) */
	bt	OCIend		/*     return;     */

	mov	#0xe0,r0	/* r0: 0xffffffe0 */
	and	r4,r0		/* r0 -> (current cache line) */

	add	r4,r5		/* r5 -> (last adrs to invalidate) + 1 */

OCIlp:	cmp/hs	r5,r0		/* if (r5 <= r0) */
	bt	OCIend		/*     return;   */

	ocbi	@r0		/* invalidate, no write-back */

	bra	OCIlp;
	add	#32,r0		/* r0 -> (next cache line) */

OCIend:	rts;
	mov	#0,r0		/* return OK */


/******************************************************************************
*
* cacheSh7750DClear - clear some entries from SH7750 operand(data) cache
*
* STATUS cacheSh7750DClear (void *from, size_t bytes);
*
* RETURNS: OK, always.
*
* NOMANUAL
*/
	.type	_cacheSh7750DClear,@function
	.align	_ALIGN_TEXT

_cacheSh7750DClear:
	tst	r5,r5		/* if (bytes == 0) */
	bt	OCCend		/*     return;     */

	mov	#0xe0,r0	/* r0: 0xffffffe0 */
	and	r4,r0		/* r0 -> (current cache line) */

	add	r4,r5		/* r5 -> (last adrs to clear) + 1 */

OCClp:	cmp/hs	r5,r0		/* if (r5 <= r0) */
	bt	OCCend		/*     return;   */

	ocbp	@r0		/* write-back, then invalidate */

	bra	OCClp;
	add	#32,r0		/* r0 -> (next cache line) */

OCCend:	rts;
	mov	#0,r0		/* return OK */

/******************************************************************************
*
* cacheSh7750PipeFlush - flush write buffers to memory
*
* This routine forces the processor output buffers to write their contents
* to RAM.  A cache flush may have forced its data into the write buffers,
* then the buffers need to be flushed to RAM to maintain coherency.
*
* RETURNS: OK.
*
* NOMANUAL
*/
	.type	_cacheSh7750PipeFlush,@function
	.align	_ALIGN_TEXT

_cacheSh7750PipeFlush:
	mov.l	PF_XA0000000,r1
	mov	#0,r0			/* return OK */
	rts;
	mov.l	@r1,r1			/* flush write-buffer by P2 read */

		.align	2
PF_XA0000000:	.long	0xa0000000	/* P2 (reset vector) */
