/* dllALib.s - assembly language doubly linked list manipulation */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01d,28mar00,hk   added .type directive to function names.
01c,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01b,26apr95,hk   optimized.
01a,25apr95,hk   written based on mc68k-01g.
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

   ---------             --------          --------
   | head--------------->| next----------->| next---------
   |       |             |      |          |      |      |
   |       |        ------ prev |<---------- prev |      |
   |       |       |     |      |          |      |      |
   | tail------    |     | ...  |    ----->| ...  |      |
   |-------|  |    v                 |                   v
              |  -----               |                 -----
              |   ---                |                  ---
              |    -                 |                   -
              ------------------------

.CE
.ne 12
EMPTY LIST:
.CS

	-----------
        |  head------------------
        |         |             |
        |  tail----------       |
        |         |     |       v
        |         |   -----   -----
        -----------    ---     ---
                        -	-

.CE
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

#ifndef PORTABLE
	/* internal */

	.globl	_dllInsert
	.globl	_dllAdd
	.globl	_dllRemove
	.globl	_dllGet


	/* external */


	.text

/* r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 r15 sp jsr */

/*******************************************************************************
*
* dllInsert - insert node in list after specified node
*
* This routine inserts the specified node in the specified list.
* The new node is placed following the specified 'previous' node in the list.
* If the specified previous node is NULL, the node is inserted at the head
* of the list.

* void dllInsert
*     (
*     FAST DL_LIST *pList,	/@ pointer to list descriptor @/
*     FAST DL_NODE *pPrev,	/@ pointer to node after which to insert @/
*     FAST DL_NODE *pNode	/@ pointer to node to be inserted @/
*     )

* INTERNAL

*     {
*     FAST DL_NODE *pNext;
*
*     if (pPrev == NULL)
*	  {				/@ new node is to be first in list @/
*	  pNext = pList->head;
*	  pList->head = pNode;
*	  }
*     else
*	  {				/@ make prev node point fwd to new @/
*	  pNext = pPrev->next;
*	  pPrev->next = pNode;
*	  }
*
*     if (pNext == NULL)
*	  pList->tail = pNode;		/@ new node is to be last in list @/
*     else
*	  pNext->previous = pNode;	/@ make next node point back to new @/
*
*     pNode->next	= pNext;   	/@ set pointers in new node @/
*     pNode->previous	= pPrev;
*     }

*		DL_LIST			DL_NODE
*	pList -> head		pNode -> next
*		 tail			previous
*/
	.align	_ALIGN_TEXT
	.type	_dllInsert,@function
					/* r4: (DL_LIST *) pList  */
					/* r5: (DL_NODE *) pPrev  */
_dllInsert:				/* r6: (DL_NODE *) pNode  */

	tst	r5,r5			/* (pPrev == NULL) ? */
	bf	dllInsert1

	mov.l	@r4,r1			/* pNext = pList->head */
	bra	dllInsert2;
	mov.l	r6,@r4			/* pList->head = pNode */

dllInsert1:
	mov.l	@r5,r1			/* pNext = pPrev->next */
	mov.l	r6,@r5			/* pPrev->next = pNode */

dllInsert2:
	mov.l	r1,@r6			/* pNode->next = pNext */
	mov.l	r5,@(4,r6)		/* pNode->previous = pPrev */

	tst	r1,r1			/* (pNext == NULL) ? */
	bt	dllInsert3
	mov	r1,r4
dllInsert3:
	rts;
	mov.l	r6,@(4,r4)

/*******************************************************************************
*
* dllAdd - add node to end of list
*
* This routine adds the specified node to the end of the specified list.

* void dllAdd
*     (
*     DL_LIST *pList,	/@ pointer to list descriptor @/
*     DL_NODE *pNode	/@ pointer to node to be added @/
*     )

* INTERNAL

*     {
*     dllInsert (pList, pList->tail, pNode);
*     }

* void dllAdd
*     (
*     FAST DL_LIST *pList,	/@ pointer to list descriptor @/
*     FAST DL_NODE *pNode	/@ pointer to node to be inserted @/
*     )
*     {
*     FAST DL_NODE *pNext;
*
*     if (pPrev == NULL)
*	  {				/@ new node is to be first in list @/
*	  pNext = pList->head;
*	  pList->head = pNode;
*	  }
*     else
*	  {				/@ make prev node point fwd to new @/
*	  pNext = pPrev->next;
*	  pPrev->next = pNode;
*	  }
*
*     pList->tail	= pNode;	/@ new node is to be last in list @/
*     pNode->next	= pNext;   	/@ set pointers in new node @/
*     pNode->previous	= pPrev;
*     }

*/
	.align	_ALIGN_TEXT
	.type	_dllAdd,@function
					/* r4: pList */
_dllAdd:				/* r5: pNode */
	mov.l	@(4,r4),r6		/* r6: pPrev = pList->tail */
	mov	#0,r0			/* r0: NULL */

	mov.l	r5,@(4,r4)		/* pList->tail     = pNode */
	mov.l	r0,@r5			/* pNode->next     = NULL  */
	mov.l	r6,@(4,r5)		/* pNode->previous = pPrev */

	tst	r6,r6			/* (pPrev == NULL) ? */
	bt	dllAdd1

	mov	r6,r4
dllAdd1:
	rts;
	mov.l	r5,@r4			/* pList->head     = pNode */

/*******************************************************************************
*
* dllRemove - remove specified node in list
*
* Remove the specified node in the doubly linked list.

* void dllRemove
*     (
*     DL_LIST *pList,		/@ pointer to list descriptor @/
*     DL_NODE *pNode		/@ pointer to node to be deleted @/
*     )

* INTERNAL

*     {
*     if (pNode->previous == NULL)
*         pList->head           = pNode->next;
*     else
*         pNode->previous->next = pNode->next;
*
*     if (pNode->next == NULL)
*         pList->tail           = pNode->previous;
*     else
*         pNode->next->previous = pNode->previous;
*     }

*		DL_LIST			DL_NODE
*	pList -> head		pNode -> next
*		 tail			previous
*/
	.align	_ALIGN_TEXT
	.type	_dllRemove,@function
				/* r4: pList */
_dllRemove:			/* r5: pNode */
	mov.l	@(4,r5),r1	/* r1: pNode->previous */
	mov.l	@r5,r0		/* r0: pNode->next */
	mov	r1,r2
	tst	r1,r1		/* (pNode->previous == NULL)? */
	bf	dllRemove1	/* r1: pNode->previous */

	mov	r4,r1		/* r1: pList */
dllRemove1:
	mov.l	r0,@r1

	tst	r0,r0		/* (pNode->next == NULL)? */
	bt	dllRemove2
	mov	r0,r4
dllRemove2:
	rts;
	mov.l	r2,@(4,r4)

/*******************************************************************************
*
* dllGet - get (delete and return) first node from list
*
* This routine gets the first node from the specified list, deletes the node
* from the list, and returns a pointer to the node gotten.
*
* RETURNS: Pointer to the node gotten, or NULL if the list is empty.

* DL_NODE *dllGet (pList)
*     (
*     FAST DL_LIST *pList	/@ pointer to list from which to get node @/
*     )

* INTERNAL

*     {
*     FAST DL_NODE *pNode = pList->head;
*
*     if (pNode != NULL)                      /@ is list empty?           @/
*         {
*         pList->head = pNode->next;          /@ make next node be 1st    @/
*
*         if (pNode->next == NULL)            /@ is there any next node?  @/
*             pList->tail = NULL;             /@   no - list is empty     @/
*         else
*             pNode->next->previous = NULL;   /@   yes - make it 1st node @/
*         }
*     return (pNode);
*     }

*		DL_LIST			DL_NODE
*	pList -> head		pNode -> next
*		 tail			previous
*/
	.align	_ALIGN_TEXT
	.type	_dllGet,@function

_dllGet:				/* r4: pList */
	mov.l	@r4,r0			/* r0: pNode = pList->head */
	tst	r0,r0
	bt	dllGet2			/* if (r0 == NULL) we're done */

	mov.l	@r0,r1			/* r1: pNode->next */
	mov	#0,r2			/* r2: NULL */
	mov.l	r1,@r4			/* pList->head = pNode->next */

	tst	r1,r1			/* (pNode->next == NULL)? */
	bt	dllGet1
	mov	r1,r4
dllGet1:
	rts;
	mov.l	r2,@(4,r4)
dllGet2:
	rts;
	nop

#endif	/* (!PORTABLE) */
