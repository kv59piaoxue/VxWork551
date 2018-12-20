/* qPriHeapALib.s  - ARM assembler heap priority queue management library */

/* Copyright 1996-1997 Wind River Systems, Inc. */


/*
modification history
--------------------
01e,17oct01,t_m  convert to FUNC_LABEL:
01d,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,23may97,jpd  Amalgamated into VxWorks.
01a,16jul96,apl  Written.
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they have been optimized
for performance.

INTERNAL
The C code versions of these routines can be found in qPriHeapLib.c.
*/


#define _ASMLANGUAGE
#include "arch/arm/arm.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define qPriHeapALib_PORTABLE
#endif

#ifndef qPriHeapALib_PORTABLE

	/* globals */

	.globl	FUNC(qPriHeapUp)
	.globl	FUNC(qPriHeapDown)

	.text
	.balign	4

/*******************************************************************************
*
* qPriHeapUp - elevate a node to its proper place in the heap tree
*
* This routine elevates a node to its proper place in the heap tree.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void qPriHeapUp
*    (
*    Q_PRI_BMAP_HEAD	*pQPriHeapHead,
*    int		index
*    )
*
*/

FUNC_LABEL(qPriHeapUp)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {r4, r5, fp, ip, lr, pc}
	sub	fp, ip, #4
#else /* !STACK_FRAMES */
	stmfd	sp!, {r4 - r5, lr}
#endif /* STACK_FRAMES */

	sub	r3, r1, #1		/* ParentIx = workIx - 1	*/
	add	r3, r3, r3, lsr #31
	mov	r5, r0			/* Save pQPriHeapHead pointer	*/
	mov	r0, r3, asr #1		/* ParentIx = (workIx - 1) / 2	*/
	ldr	lr, [r5, #4]		/* pQPriHeapHead->pHeapArray	*/
	ldr	r4, [lr, r1, asl #2]	/* Load heapArray[workIx]	*/
	cmp	r1, #0			/* Check WorkIx > 0		*/
	ble	heapUpDone		/* Quick exit case		*/

heapUpWhile:
	ldr	ip, [lr, r0, asl #2]	/* heapArray[parentIx] ...	*/
	ldr	r2, [ip]		/*	...->key		*/
	ldr	r3, [r4]		/* workNode->key		*/
	cmp	r2, r3			/* Compare keys			*/
	bls	heapUpDone
	str	ip, [lr, r1, asl #2]	/* ...[workIx] = ...[parentIx]	*/
	mov	r1, r0			/* workIx = parentIx		*/
	sub	r3, r1, #1		/* parentIx = (workIx - 1)	*/
	add	r3, r3, r3, lsr #31
	mov	r0, r3, asr #1		/* parentIx = (workIx - 1) / 2	*/
	cmp	r1, #0			/* while(WorkIx > 0 && ...)	*/
	bgt	heapUpWhile		/* Loop				*/

heapUpDone:
	str	r4, [lr, r1, asl #2]	/* heapArray[wo] = heapArray[]	*/
	ldr	r3, [lr]		/* Load heapArray[0]		*/
	str	r3, [r5]		/* pQPriHeapHead->highNode = ..	*/

#ifdef STACK_FRAMES
	ldmdb	fp, {r4, r5, fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmfd	sp!, {r4 - r5, pc}
#endif /* STACK_FRAMES */

/*******************************************************************************
*
*
* qPriHeapDown - move a node down to its proper place in the heap tree
*
* This routine moves a node down to its proper place in the heap tree.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void qPriHeapDown
*    (
*    Q_PRI_BMAP_HEAD *	pQPriHeapHead,
*    int		index
*    )
*/

FUNC_LABEL(qPriHeapDown)

#ifdef STACK_FRAMES
	mov	ip, sp stmdb	sp!, {r4, r5, fp, ip, lr, pc}
	sub	fp, ip, #4
#else /* !STACK_FRAMES */
	stmfd	sp!, {r4 - r5, lr}
#endif /* STACK_FRAMES */

	mov	r3, r1			/* workIx = index passed in r1	*/
	mov	r1, r1, LSL #1		/* leftChildIx = 2 * workIx...	*/
	add	r2, r1, #1		/*	... plus one.		*/
	add	ip, r2, #1		/* rightChildIx = left...Ix + 1	*/
	ldmib	r0, {r1, r4}		/* Load ->HeapArray ->heapIndex	*/
	ldr	lr, [r1, r3, LSL #2]	/* Load heapArray[workIx]	*/
	cmp	r4, r2			/* left...Ix < pQ...->heapIndex	*/
	ble	heapDownDone		/* Done?			*/

heapDownWhile:
	ldr	r4, [r0, #8]		/* pQPriHeapHead->heapIndex	*/
	cmp	r4, ip			/* rightChildIx >= ...heapIndex */
	ble	heapDownSkip
	ldr	r4, [r1, r2, LSL #2]	/* heapArray[...ChildIx]	*/
	ldr	r4, [r4]		/*	...->key		*/
	ldr	r5, [r1, ip, LSL #2]	/* heapArray[...ChildIx]	*/
	ldr	r5, [r5]		/*	...->key		*/
	cmp	r4, r5			/* Compare key fields		*/
	movcs	r2, ip			

heapDownSkip:
	ldr	ip, [r1, r2, LSL #2]	/* heapArray[lesserChildIx]	*/
	ldr	r5, [ip]		/*	...->key		*/
	ldr	r4, [lr]		/* workNode->key		*/
	cmp	r5, r4			/* [les...]->key < workNode-key */
	bcs	heapDownDone		/* break			*/
	str	ip, [r1, r3, LSL #2]	/* heapArray[workIx] = heap...	*/
	mov	r3, r2			
	mov	ip, r2, LSL #1		/* leftChildIx = 2 * workIx...	*/
	add	r2, ip, #1		/*	... plus one.		*/
	add	ip, ip, #2		/* rightChildIx = left...Ix + 1	*/
	ldr	r4, [r0, #8]		/* pQPriHeapHead->heapIndex	*/
	cmp	r4, r2			/* left...Ix < pQ...->heapIndex	*/
	bgt	heapDownWhile

heapDownDone:
	str	lr, [r1, r3, LSL #2]	/* heapArray[workIx] = workNode	*/
	ldr	r1, [r1]		/* Load heapArray[0]...		*/
	str	r1, [r0]		/* Set pQPriHeapHeap->pHighNode	*/

#ifdef STACK_FRAMES
	ldmdb	fp, {r4, r5, fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmfd	sp!, {r4 - r5, pc}	/* And exit...			*/
#endif /* STACK_FRAMES */

#endif /* ! qPriHeapALib_PORTABLE */
