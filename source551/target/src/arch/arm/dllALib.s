/* dllALib.s - ARM assembly language doubly linked list manipulation */

/* Copyright 1996-1997 Wind River Systems, Inc. */

/*
modification history
--------------------
01e,17oct01,t_m  convert to FUNC_LABEL:
01d,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,23may97,jpd  Amalgamated into VxWorks.
01a,10jul96,apl  Written.
*/

/*
DESCRIPTION
This subroutine library supports the creation and maintenance of a
doubly linked list.  The user supplies a list descriptor (type DL_LIST)
that will contain pointers to the first and last nodes in the list.
The nodes in the list can be any user-defined structure, but they must reserve
space for a pointer as their first element.  The forward chain is terminated
with a NULL pointer.

This library in conjunction with dllLib.c, and the macros defined in dllLib.h,
provide a reduced version of the routines offered in lstLib(1).  For
efficiency, the count field has been eliminated, and enqueueing and dequeueing
functions have been hand optimized.

.ne 16
NON-EMPTY LIST:
.CS

   ---------		 --------	   --------
   | head--------------->| next----------->| next---------
   |	   |		 |	|	   |	  |	 |
   |	   |	    ------ prev |<---------- prev |	 |
   |	   |	   |	 |	|	   |	  |	 |
   | tail------    |	 | ...	|    ----->| ...  |	 |
   |-------|  |    v		     |			 v
	      |  -----		     |		       -----
	      |   ---		     |			---
	      |    -		     |			 -
	      ------------------------

.CE
.ne 12
EMPTY LIST:
.CS

	-----------
	|  head------------------
	|	  |		|
	|  tail----------	|
	|	  |	|	v
	|	  |   -----   -----
	-----------    ---     ---
			-	-

.CE
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define dllALib_PORTABLE
#endif

#ifndef dllALib_PORTABLE


	/* externals */

	.globl	FUNC(dllInsert)
	.globl	FUNC(dllAdd)
	.globl	FUNC(dllRemove)
	.globl	FUNC(dllGet)

	.text
	.balign	4

/*******************************************************************************
*
* dllInsert - insert node in list after specified node
*
* This routine inserts the specified node in the specified list.
* The new node is placed following the specified 'previous' node in the list.
* If the specified previous node is NULL, the node is inserted at the head
* of the list.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void dllInsert
*    (
*    FAST DL_LIST *	pList,	/@ pointer to list descriptor @/
*    FAST DL_NODE *	pPrev,	/@ pointer to node after which to insert @/
*    FAST DL_NODE *	pNode	/@ pointer to node to be inserted @/
*    )
*/

FUNC_LABEL(dllInsert)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	cmp	r1, #NULL	/* Check pPrev for NULL	*/
	ldreq	r3, [r0]	/* pNext = pList->head */
	streq	r2, [r0]	/* pList->head = pNode */
	ldrne	r3, [r1]	/* pNext = pPrev->next */	
	strne	r2, [r1]	/* pPrev->next = pNode */
	cmp	r3, #NULL	/* Check pNext for NULL */
	streq	r2, [r0, #4]	/* pList->tail = pNode */
	strne	r2, [r3, #4]	/* pNext->previous = pNode */
	str	r3, [r2]	/* pNode->next = pNext */
	str	r1, [r2, #4]	/* pNode->previous = pPrev */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr		/* And exit			*/
#endif /* STACK_FRAMES */

/*******************************************************************************
*
* dllAdd - add node to end of list
*
* This routine adds the specified node to the end of the specified list.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void dllAdd
*    (
*    DL_LIST *	pList,	/@ pointer to list descriptor @/
*    DL_NODE *	pNode	/@ pointer to node to be added @/
*    )
*
*/

FUNC_LABEL(dllAdd)
#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	ldr	r2, [r0, #4]	/* Get pPrev */

	/* This is FUNC(dllInsert) inlined. */

	cmp	r2, #NULL	/* Check pPrev for NULL */
	ldreq	r3, [r0]	/* pNext = pList->head */
	streq	r1, [r0]	/* pList->head = pNode */
	ldrne	r3, [r2]	/* pNext = pPrev->next */
	strne	r1, [r2]	/* pPrev->next = pNode */
	cmp	r3, #NULL	/* Check pNext for NULL */
	streq	r1, [r0, #4]	/* pList->tail = pNode */
	strne	r1, [r3, #4]	/* pNext->previous = pNode */
	str	r3, [r1]	/* pNode->next = pNext */
	str	r2, [r1, #4]	/* pNode->previous = pPrev */

	/* End FUNC(dllInsert) inlined. */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr		/* And exit */
#endif /* STACK_FRAMES */

/*******************************************************************************
*
* dllRemove - remove specified node in list
*
* Remove the specified node in the doubly linked list.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void dllRemove
*    (
*    DL_LIST *	pList	/@ pointer to list descriptor @/
*    DL_NODE *	pNode	/@ pointer to node to be deleted @/
*    )
*/

FUNC_LABEL(dllRemove)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	ldmia	r1, {r2, r3}	/* Load pNode->next, pNode->previous */
	cmp	r3, #NULL	/* Check for pNode->previous for NULL */
	streq	r2, [r0]	/* Set pListHead = pNodeNext */
	strne	r2, [r3]	/* Set pNode->previous->next */
	cmp	r2, #NULL	/* Check pNode->next for NULL */
	streq	r3, [r0, #4]	/* Set pList->tail */
	strne	r3, [r2, #4]	/* Set pNode->next->previous */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr		/* And exit */
#endif /* STACK_FRAMES */

/*******************************************************************************
*
* dllGet - get (delete and return) first node from list
*
* This routine gets the first node from the specified list, deletes the node
* from the list, and returns a pointer to the node gotten.
*
* RETURNS
*	Pointer to the node gotten, or
*	NULL if the list is empty.
*
* NOMANUAL
*
*
* DL_NODE * dllGet
*    (
*    FAST DL_LIST *	pList	/@ pointer to list from which to get node @/
*    )
*/

FUNC_LABEL(dllGet)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	ldr	r1, [r0]	/* Get pNode */
	cmp	r1, #NULL	/* Check for null */
	moveq	r0, r1		/* Load return value for quick exit */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr		/* And get out fast */
#endif /* STACK_FRAMES */

	/* Inlined FUNC(dllRemove) */

	ldr	r3, [r1]
	str	r3, [r0]
	ldr	r2, [r1]
	cmp	r2, #0
	streq	r2, [r0, #4]
	movne	r3, #0
	strne	r3, [r2, #4]

	/* End inline FUNC(dllRemove) */

	mov	r0, r1		/* Load return value */
#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr		/* And exit */
#endif /* STACK_FRAMES */

#endif /* (!PORTABLE) */
