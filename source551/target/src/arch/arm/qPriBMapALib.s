/* qPriBMapALib.s - ARM assembler bit mapped priority queue library */

/* Copyright 1996-1997 Wind River Systems, Inc. */

/*
modification history
--------------------
01f,17oct01,t_m  convert to FUNC_LABEL:
01e,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01d,27oct97,kkk  took out "***EOF***" line from end of file.
01c,10oct97,jpd  Added missing .extern declarations.
01b,23may97,jpd  Amalgamated into VxWorks.
01a,10jul96,apl  Written.
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they have been optimized
for performance.

INTERNAL
The C code versions of these routines can be found in qPriBMapLib.c.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define qPriBMapALib_PORTABLE
#endif

#ifndef qPriBMapALib_PORTABLE

	/* Exports */

	.global	FUNC(qPriBMapPut)
	.global	FUNC(qPriBMapGet)
	.global	FUNC(qPriBMapRemove)


	/* externals */

	.extern FUNC(dllAdd)
	.extern	FUNC(ffsMsb)

	.text
	.balign	4

/*******************************************************************************
*
* qPriBMapPut - insert the specified TCB into the ready queue
*
* RETURNS: N/A
*
* NOMANUAL
*
* void qPriBMapPut
*    (
*    Q_PRI_BMAP_HEAD *	pQPriBMapHead,
*    Q_PRI_NODE *	pQPriNode,
*    ULONG		key
*    )
*/

FUNC_LABEL(qPriBMapPut)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {r4, fp, ip, lr, pc}
	sub	fp, ip, #4
#else
	stmfd	sp!, {r4, lr}
#endif

	mov	r4, r0		/* Preserve ptr to pQPriBMapHead	*/
	mov	r3, r2, asl #3	/* Preserve key				*/
	add	r0, r3, #36	/*					*/

	/* r0, r1 preserved till just before call to dllAdd below */

	str	r2, [r1, #8]	/* pQPriNode->key = key			*/
	ldr	r3, [r4]	/* Get pQPriBMapHead->highNode		*/
	cmp	r3, #NULL	/* Check for NULL			*/
	streq	r1, [r4]	/* pQPriBMapHead->highnode = pQPriNode	*/
	beq	1f
	ldr	r3, [r3, #8]	/* Get highNode->key			*/
	cmp	r2, r3		/* Compare to key			*/
	strcc	r1, [r4]	/* pQPriBMapHead->highnode = pQPriNode	*/

1:
	ldr	r4, [r4, #4]	/* pQPriBMapHead->pBMapList		*/

	/* qPriBMapSet(pBMapList, priority): Inlined. */

	rsb	r2, r2, #255	    /* Compute 255 - priority		*/
	mov	lr, r2, asr #3	    /* Compute priority >> 3		*/
	mov	ip, #1		    /* Load constant for shifting	*/
	ldr	r3, [r4]	    /* Load pBMapList->metaBMap		*/
	orr	r3, r3, ip, asl lr  /* metaBMap |= (1 << (priority >> 3)) */
	str	r3, [r4]	    /* Update pBMapList->metaBMap	*/
	and	r2, r2, #7	    /* priority & 0x07			*/
	add	lr, r4, lr	    /* Compute index address		*/
	ldrb	r3, [lr, #4]	    /* pBMapList->bMap[priority >> 3]	*/
	orr	r3, r3, ip, asl r2  /* bMap |= (1 << (priority & 0x07))	*/
	strb	r3, [lr, #4]	    /* Update bitmap			*/

	/* End qPriBMapSet inlined.  */

	add	r0, r4, r0	/* Compute final argument		*/
	bl	FUNC(dllAdd)		/* Call fn				*/

#ifdef	STACK_FRAMES
	ldmdb	fp, {r4, fp, sp, pc}
#else
	ldmfd	sp!, {r4, pc}
#endif

/*******************************************************************************
*
* qPriBMapGet - remove and return first node in priority bit-mapped queue
*
* This routine removes and returns the first node in a priority bit-mapped
* queue.  If the queue is empty, NULL is returned.
*
* RETURNS Pointer to first queue node in queue head, or NULL if queue is empty.
*
* NOMANUAL
*
* Q_PRI_NODE *qPriBMapGet
*    (
*    Q_PRI_BMAP_HEAD *	pQPriBMapHead
*    )
*/

FUNC_LABEL(qPriBMapGet)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#else /* !STACK_FRAMES */
	stmfd	sp!, {r4, lr}
#endif /* STACK_FRAMES */

	ldr	r4, [r0]	/* Get pQPriBMapHead->highNode */
	movs	r1, r4		/* Check for null AND prepare for call */
	blne	FUNC(qPriBMapRemove)	/* (relies on NULL == 0) call fn */
	mov	r0, r4		/* Load return value */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmfd	sp!, {r4, pc}
#endif /* STACK_FRAMES */

/*******************************************************************************
*
* qPriBMapRemove - remove a node from a priority bit mapped queue
*
* This routine removes a node from the specified bit mapped queue.
*
* NOMANUAL
*
* STATUS qPriBMapRemove
*    (
*    Q_PRI_BMAP_HEAD *	pQPriBMapHead,
*    Q_PRI_NODE *	pQPriNode
*    )
*	
*/

FUNC_LABEL(qPriBMapRemove)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {r4 - r6, fp, ip, lr, pc}
	sub	fp, ip, #4
#else
	stmfd	sp!, {r4 - r6, lr}
#endif

	mov	r4, r0		/* Preserve ptr to pQPriBMapHead	*/
	mov	r5, r1		/* Preserve ptr to pQPriNode		*/
	ldr	ip, [r0, #4]	/* Get pQPriBMapHead->pBMapList		*/
	ldr	lr, [r1, #8]	/* Get pQPriNode->key			*/
	mov	r0, lr, asl #3	/* Compute index into listArray		*/
	add	r0, ip, r0	/* Add base pointer to form address	*/

	/*
	 *	dllRemove (inlined)
	 *	Offsets from r0 are +#36, this saves and add instruction in
	 *	the code above, which would be used if dllRemove was called
	 *	as a function.
	 */

	ldmia	r1, {r2, r3}	/* Load pNode->next, pNode->previous	*/
	cmp	r3, #NULL	/* Check pNode->previous for NULL	*/
	streq	r2, [r0, #36]	/* Set pListHead = pNodeNext		*/
	strne	r2, [r3]	/* Set pNode->previous->next		*/
	cmp	r2, #NULL	/* Check pNode->Next for NULL		*/
	streq	r3, [r0, #40]	/* Set pList->tail			*/
	strne	r3, [r2, #4]	/* Set pNode->next->previous		*/

	/* dllRemove inlined, Ends */


	add	r3, ip, lr, asl #3
	ldr	r2, [r3, #36]	
	cmp	r2, #0		/* if DLL_EMPTY(...) fall though	*/
	bne	dllNotEmpty	/*   otherwise branch...		*/

	/* qPriBMapClear (inlined) */

	rsb	r1, lr, #255	/* Priority = 255 - Priority		*/
	mov	r0, r1, asr #3	/* Priority >> 3			*/
	add	r2, ip, r0	/* Compute array offset pointer		*/
	and	r1, r1, #7	/* (Priority & 0x07)			*/
	mov	lr, #1		/* Load constant for shift		*/
	mvn	r1, lr, asl r1	/* ~(1 << (priority >> 3))		*/
	ldrb	r3, [r2, #4]	/* Load bMap entry			*/
	and	r3, r3, r1	/* Mask it, clearing bits		*/
	strb	r3, [r2, #4]	/* Store bMap entry			*/
	cmp	r3, #0		/* Check priority			*/
	mvneq	r2, lr, asl r0	/* Compute mask				*/
	ldreq	r3, [ip]	/* Load word from meta-map		*/
	andeq	r3, r3, r2	/* Clear bit in the meta-map		*/
	streq	r3, [ip]	/* And update word in meta-map		*/

	/* qPriBMapClear inlined, Ends.  */

	ldr	r3, [r4]
	cmp	r5, r3
	movne	r0, #OK		/* Load return value */

#ifdef STACK_FRAMES
	ldmnedb	fp, {r4 - r6, fp, sp, pc}
#else
	ldmnefd	sp!, {r4 - r6, pc}
#endif

	ldr	r6, [r4, #4]

	/* qPriBMapHigh (Inlined) */

	ldr	r0, [r6]	    /* Pick up metaBMap field	*/
	bl	FUNC(ffsMsb)		    /* Call function		*/
	sub	r1, r0, #1	    /* Decr to form highBits	*/
	and	r1, r1, #255	    /* And ensure byte value	*/
	add	r6, r6, r1	    /* Add array offset		*/
	ldrb	r0, [r6, #4]	    /* And load the argument	*/
	mov	r6, r1		    /* highBits in r4 over call	*/
	bl	FUNC(ffsMsb)		    /* Call function		*/
	sub	r0, r0, #1	    /* Decr to form lowBits	*/
	orr	r0, r0, r6, asl #3  /* incl-or in highBits << 3	*/
	and	r0, r0, #255	    /* Mask to byte value	*/
	rsb	r0, r0, #255	    /* Ret 255 minus that lot	*/

	/* qPriBMapHigh inlined, Ends.	*/

	ldr	r3, [r4, #4]
	add	r3, r3, r0, asl #3
	ldr	r3, [r3, #36]
	str	r3, [r4]
	mov	r0, #OK			/* Load return value	*/
#ifdef STACK_FRAMES
	ldmdb	fp, {r4 - r6, fp, sp, pc}
#else
	ldmfd	sp!, {r4 - r6, pc}
#endif


dllNotEmpty:
	ldr	r3, [r4]	/* Get qPriBMapHead->highnode		*/
	cmp	r5, r3		/* if(pQPriNode == pQP..->highnode)	*/
	streq	r2, [r4]	/* Update pQPriBMapHead->highnode	*/
	mov	r0, #OK		/* Load return value			*/

#ifdef STACK_FRAMES
	ldmdb	fp, {r4 - r6, fp, sp, pc}
#else
	ldmfd	sp!, {r4 - r6, pc}
#endif

#endif /* ! qPriBMapALib_PORTABLE */
