/* dllALib.s - assembly language doubly linked list manipulation */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
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
	.even

/*******************************************************************************
*
* dllInsert - insert node in list after specified node
*
* This routine inserts the specified node in the specified list.
* The new node is placed following the specified 'previous' node in the list.
* If the specified previous node is NULL, the node is inserted at the head
* of the list.

*void dllInsert (pList, pPrev, pNode)
*    FAST DL_LIST *pList;	/* pointer to list descriptor *
*    FAST DL_NODE *pPrev;	/* pointer to node after which to insert *
*    FAST DL_NODE *pNode;	/* pointer to node to be inserted *

* INTERNAL

    {
    FAST DL_NODE *pNext;

    if (pPrev == NULL)
	{				/* new node is to be first in list *
	pNext = pList->head;
	pList->head = pNode;
	}
    else
	{				/* make prev node point fwd to new *
	pNext = pPrev->next;
	pPrev->next = pNode;
	}

    if (pNext == NULL)
	pList->tail = pNode;		/* new node is to be last in list *
    else
	pNext->previous = pNode;	/* make next node point back to new *

    pNode->next		= pNext;   	/* set pointers in new node *
    pNode->previous	= pPrev;
    }

*/

_dllInsert:
	movel	a4,a7@-			/* push a4/a5 so we can clobber em */
	movel	a5,a7@-

	movel	a7@(0xc),a0		/* pList into a0 */
	movel	a7@(0x10),a1		/* pPrev into a1 */
	movel	a7@(0x14),a5		/* pNode into a5 */

	cmpl	#0,a1			/* (pPrev == NULL)? */
	jne 	dllInsert1
	movel	a0@,a4			/* pNext = pList->head */
	movel	a5,a0@			/* pList->head = pNode */
	jra 	dllInsert2		/* goto next conditional */
dllInsert1:
	movel	a1@,a4			/* pNext = pPrev->next */
	movel	a5,a1@			/* pPrev->next = pNode */

dllInsert2:
	cmpl	#0,a4			/* (pNext == NULL)? */
	jne 	dllInsert3
	movel	a5,a0@(0x4)		/* pList->tail = pNode */
	jra 	dllInsert4		/* goto set pointers */
dllInsert3:
	movel	a5,a4@(0x4)		/* pNext->previous = pNode */
dllInsert4:
	movel	a4,a5@			/* pNode->next     = pNext */
	movel	a1,a5@(0x4)		/* pNode->previous = pPrev */

	movel	a7@+,a5
	movel	a7@+,a4			/* restore a4/a5 */
	rts

/*******************************************************************************
*
* dllAdd - add node to end of list
*
* This routine adds the specified node to the end of the specified list.

*void dllAdd (pList, pNode)
*    DL_LIST *pList;	/* pointer to list descriptor *
*    DL_NODE *pNode;	/* pointer to node to be added *

* INTERNAL

    {
    dllInsert (pList, pList->tail, pNode);
    }

*/

_dllAdd:
	movel	a2,a7@-			/* push a2 so we can clobber em */
	movel	a7@(0xc),a2		/* a2 = pNode */
	movel	a7@(0x8),a0		/* a0 = pList */
	movel	a0@(0x4),a1		/* a1 = pList->tail = pPrev */

	cmpl	#0,a1			/* (pPrev == NULL)? */
	jne 	dllAdd1
	movel	a2,a0@			/* pList->head = pNode */
	jra 	dllAdd2			/* goto next conditional */
dllAdd1:
	movel	a2,a1@			/* pPrev->next = pNode */
dllAdd2:
	movel	a2,a0@(0x4)		/* pList->tail     = pNode */
	clrl	a2@			/* pNode->next     = NULL */
	movel	a1,a2@(0x4)		/* pNode->previous = pPrev */
	movel	a7@+,a2			/* restore a2 */
	rts

/*******************************************************************************
*
* dllRemove - remove specified node in list
*
* Remove the specified node in the doubly linked list.

*void dllRemove (pList, pNode)
*    DL_LIST *pList;		/* pointer to list descriptor *
*    DL_NODE *pNode;		/* pointer to node to be deleted *

* INTERNAL

    {
    if (pNode->previous == NULL)
	pList->head = pNode->next;
    else
	pNode->previous->next = pNode->next;

    if (pNode->next == NULL)
	pList->tail = pNode->previous;
    else
	pNode->next->previous = pNode->previous;
    }

*/

_dllRemove:
	movel	a7@(0x8),a1		/* a1 = pNode */

	tstl	a1@(0x4)		/* (pNode->previous == NULL)? */
	jne 	dllRemove1
	movel	a7@(0x4),a0		/* a0 = pList */
	jra 	dllRemove2
dllRemove1:
	movel	a1@(0x4),a0		/* a0 = pNode->previous */
dllRemove2:
	movel	a1@,a0@			/* a0@ = pNode->next */
	
	tstl	a1@			/* (pNode->next == NULL)? */
	jne 	dllRemove3
	movel	a7@(0x4),a0		/* a0 = pList */
	jra 	dllRemove4
dllRemove3:
	movel	a1@,a0			/* a0 = pNode->next */
dllRemove4:
	movel	a1@(0x4),a0@(0x4)	/* a0@(4) = pNode->previous */
	rts

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

*DL_NODE *dllGet (pList)
*    FAST DL_LIST *pList;	/* pointer to list from which to get node *

* INTERNAL

    {
    FAST DL_NODE *pNode = pList->head;

    if (pNode != NULL)
	dllRemove (pList, pNode);

    return (pNode);
    }

*/

_dllGet:
	movel	a7@(0x4),a0		/* a0 = pList */
	movel	a0@,d0			/* d0 = pList->head */
	jeq 	dllGet2			/* if (d0 == NULL) we're done */
	movel	d0,a1
	movel	a1@,a0@			/* a0@ = pNode->next */
	tstl	a1@			/* (pNode->next == NULL)? */
	jeq 	dllGet1
	movel	a1@,a0			/* a0 = pNode->next */
dllGet1:
	clrl	a0@(0x4)		/* a0@(4) = pNode->previous */
	movel   d0,a0			/* Motorola SVR4 address argument */
dllGet2:
	rts

#endif	/* (!PORTABLE) */
