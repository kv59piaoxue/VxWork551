/* dllALib.s - assembly language doubly linked list manipulation */

/* Copyright 1984-2001 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river

/*
 * This file has been developed or significantly modified by the
 * MIPS Center of Excellence Dedicated Engineering Staff.
 * This notice is as per the MIPS Center of Excellence Master Partner
 * Agreement, do not remove this notice without checking first with
 * WR/Platforms MIPS Center of Excellence engineering management.
 */

/*
modification history
--------------------
01h,02aug01,mem  Diab integration
01g,16jul01,ros  add CofE comment
01f,12jun92,ajm  fixed dllGet, included optimized version
01e,15oct91,ajm  not optimized version yet, tell the world
01d,04oct91,rrr  passed through the ansification filter
                  -fixed #else and #endif
                  -changed VOID to void
                  -changed ASMLANGUAGE to _ASMLANGUAGE
                  -changed copyright notice
01c,05may91,ajm  ported to MIPS
01b,12sep90,dab  changed linkw to link, tstl a<n> to cmpl #0,a<n>.
           +lpf  
01a,07aug89,jcf  written.
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

#if defined(PORTABLE)
#define dllALib_PORTABLE
#endif

#ifndef dllALib_PORTABLE

	/* internal */

	.globl	dllInsert
	.globl	dllAdd
	.globl	dllRemove
	.globl	dllGet

	.text
	.set	reorder

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

	.ent	dllInsert
dllInsert:
	bne	zero, a1, dllInsert1	/* (pPrev == NULL)? */
	lw	v0, 0(a0)		/* pNext = pList->head */
	sw	a2, 0(a0)		/* pList->head = pNode */
	b	dllInsert2		/* goto next conditional */
dllInsert1:
	lw	v0, 0(a1)		/* pNext = pPrev->next */
	sw	a2, 0(a1)		/* pPrev->next = pNode */

dllInsert2:
	beq	v0, zero, dllInsert3	/* (pNext == NULL)? */
	sw	a2, 4(v0)		/* pNext->previous = pNode */
	sw	v0, 0(a2)		/* pNode->next     = pNext */
	sw	a1, 4(a2)		/* pNode->previous = pPrev */
	j	ra

dllInsert3:

	sw      a2, 4(a0)		/* */
	sw	v0, 0(a2)		/* pNode->next     = pNext */
	sw	a1, 4(a2)		/* pNode->previous = pPrev */
	j	ra
	.end	dllInsert

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

	.ent	dllAdd
dllAdd:
	move	a2, a1			/* fixup params */
	lw	a1, 4(a0)		/* t0 = pPrev = pList->tail */

	bne	zero, a1, dllAdd1	/* (pPrev == NULL)? */
	lw	v0, 0(a0)		/* pNext = pList->head */
	sw	a2, 0(a0)		/* pList->head = pNode */
	j	dllAdd2			/* goto next conditional */
dllAdd1:
	lw	v0, 0(a1)		/* pNext = pPrev->next */
	sw	a2, 0(a1)		/* pPrev->next = pNode */

dllAdd2:
	beq	v0, zero, dllAdd3	/* (pNext == NULL)? */
	sw	a2, 4(v0)		/* pNext->previous = pNode */
	sw	v0, 0(a2)		/* pNode->next     = pNext */
	sw	a1, 4(a2)		/* pNode->previous = pPrev */
	j	ra

dllAdd3:

	sw      a2, 4(a0)		/* */
	sw	v0, 0(a2)		/* pNode->next     = pNext */
	sw	a1, 4(a2)		/* pNode->previous = pPrev */
	j	ra
	.end	dllAdd

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

	.ent	dllRemove
dllRemove:
	lw	v0, 4(a1)			/* v0 = pNode->previous */
	bne	v0, zero, dllRemove1		/* (v0 == NULL)? */
	lw	t6, 0(a1)
	sw	t6, 0(a0)			/* pList->head = pNode->next */
	b	dllRemove2
dllRemove1:
	lw	t7, 0(a1)
	sw	t7, 0(v0)			/* v0->next = pNode->next */
dllRemove2:
	lw	v0, 0(a1)			/* v0 = pNode->next */
	bne	v0, zero, dllRemove3
	lw	t8, 4(a1)			/* t8 = pNode->previous */
	sw	t8, 4(a0)			/* pList->tail = */
	j	ra
dllRemove3:
	lw	t9, 4(a1)			/* t9 = pNode->previous */
	sw	t9, 4(v0)			/* v0->previous = t8 */
	j	ra
	.end	dllRemove

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

	.ent	dllGet
dllGet:
	lw	v0, 0(a0)		/* pNode = pList->head */
	beq	zero, v0, dllGet2	/* if (v0 == NULL) we're done */
	lw	t1, 0(v0)
	sw	t1, 0(a0)		/* pList->head = pNode->next */
	beq	zero, t1, dllGet1	/* (pNode->next == NULL)? */
	lw	t1, 0(v0)		/* t1 = pNode->next */
	sw	zero, 4(t1)		/* t1@(4) = pNode->previous */
	j	ra

dllGet1:
	sw	zero, 4(a0)		/* t1@(4) = NULL */
dllGet2:
	j	ra
	.end	dllGet

#endif /* dllALib_PORTABLE */
