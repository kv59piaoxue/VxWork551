/* sllALib.s - ARM assembly language singly linked list manipulation routines */

/* Copyright 1996-1997 Wind River Systems, Inc. */


/*
modification history
--------------------
01e,17oct01,t_m  convert to FUNC_LABEL:
01d,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,23may97,jpd  Amalgamated into VxWorks.
01a,11jul96,apl  written.
*/

/*
DESCRIPTION
This subroutine library supports the creation and maintenance of a
singly linked list.  The user supplies a list descriptor (type SL_LIST)
that will contain pointers to the first and last nodes in the list.
The nodes in the list can be any user-defined structure, but they must reserve
space for a pointer as their first element.  The forward chain is terminated
with a NULL pointer.

.ne 16
NON-EMPTY LIST:
.CS

   ---------		 --------	   --------
   | head--------------->| next----------->| next---------
   |	   |		 |	|	   |	  |	 |
   |	   |		 |	|	   |	  |	 |
   | tail------ 	 | ...	|    ----->| ...  |	 |
   |-------|  | 		     |			 v
	      | 		     |		       -----
	      | 		     |			---
	      | 		     |			 -
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
#define sllALib_PORTABLE
#endif

#ifndef PORTABLE

	/* externals */

	.globl	FUNC(sllPutAtHead)		/* put node at head of list */
	.globl	FUNC(sllPutAtTail)		/* put node at tail of list */
	.globl	FUNC(sllGet) 		/* get and delete node from head */


	.text
	.balign	4

/*******************************************************************************
*
* sllPutAtHead - add node to beginning of list
*
* This routine adds the specified node to the head of the specified list.
*
* RETURNS: N/A
*
* NOMANUAL
*
* SEE ALSO: sllPutAtTail (2)
*
* void sllPutAtHead
*     (
*     SL_LIST *	pList;	 /@ pointer to list descriptor @/
*     SL_NODE *	pNode;	 /@ pointer to node to be added @/
*     )
*
*     {
*     if ((pNode->next = pList->head) == NULL)
*	  pList->head = pList->tail = pNode;
*     else
*	  pList->head = pNode;
*     }
*/

FUNC_LABEL(sllPutAtHead)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	ldr	r3, [r0]	/* Get pList->head */
	str	r3, [r1]	/* Set pNode->next */
	cmp	r3, #0		/* (pNode->next = pList->head) == NULL */
	streq	r1, [r0, #4]	/* pList->tail = pNode */
	str	r1, [r0]	/* pList->head = pNode */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr		/* And exit... */
#endif /* STACK_FRAMES */

/*******************************************************************************
*
* sllPutAtTail - add node to end of list
*
* This routine adds the specified node to the end of the specified singly
* linked list.
*
* RETURNS: N/A
*
* NOMANUAL
*
* SEE ALSO: sllPutAtHead (2)
*
* void sllPutAtTail
*     (
*     SL_LIST *	pList;	 /@ pointer to list descriptor @/
*     SL_NODE *	pNode;	 /@ pointer to node to be added @/
*     )
*
*     {
*     pNode->next = NULL;
*
*     if (pList->head == NULL)
*	  pList->tail = pList->head = pNode;
*     else
*	  pList->tail->next = pNode;
*	  pList->tail = pNode;
*     }
*/

FUNC_LABEL(sllPutAtTail)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	mov	r3, #NULL		/* Load constant */
	str	r3, [r1]		/* pNode->next = NULL */
	ldr	r3, [r0]		/* Get pList->head */
	cmp	r3, #NULL		/* Check for NULL */
	streq	r1, [r0]		/* pList->head = pNode */
	ldrne	r3, [r0, #4]		/* Get ptr pList->tail->next */
	strne	r1, [r3]		/* pList->tail->next = pNode */
	str	r1, [r0, #4]		/* pList->tail = pNode */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr			/* And exit... */
#endif /* STACK_FRAMES */



/*******************************************************************************
*
* sllGet - get (delete and return) first node from list
*
* This routine gets the first node from the specified singly linked list,
* deletes the node from the list, and returns a pointer to the node gotten.
*
* RETURNS
*	Pointer to the node gotten, or
*	NULL if the list is empty.
*
* NOMANUAL
*
* SL_NODE *sllGet
*     (
*     FAST SL_LIST * pList;	  /@ pointer to list from which to get node @/
*     )
*
*     {
*     FAST SL_NODE *pNode;
*
*     if ((pNode = pList->head) != NULL)
*	  pList->head = pNode->next;
*
*     return (pNode);
*     }
*/

FUNC_LABEL(sllGet)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	mov	r2, r0			/* Preserve pList pointer */
	ldr	r0, [r2]		/* Get pList->head, to return */
	cmp	r0, #NULL		/* pList->head is NULL? */
	ldrne	r3, [r0]		/* Get pNode->next */
	strne	r3, [r2]		/* pNode->next to pList->head */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr			/* And exit... */
#endif /* STACK_FRAMES */

#endif /* !PORTABLE */
