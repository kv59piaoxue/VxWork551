/* sllALib.s - assembly language singly linked list manipulation */

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
01j,02aug01,mem  Diab integration
01i,16jul01,ros  add CofE comment
01h,19oct93,cd   made R4000 use portable version, like R3000.
01g,08aug92,kdl  changed cpu symbol from MIPS_R3000 to R3000.
01f,26may92,rrr  the tree shuffle
01e,15oct91,ajm  not optimized yet, tell the world
01d,04oct91,rrr  passed through the ansification filter
                  -fixed #else and #endif
                  -changed VOID to void
                  -changed ASMLANGUAGE to _ASMLANGUAGE
                  -changed copyright notice
01c,05may90,ajm  ported to MIPS
01b,12sep90,dab  changed linkw to link.
           +lpf
01a,03jun89,jcf  written.
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

   ---------             --------          --------
   | head--------------->| next----------->| next---------
   |       |             |      |          |      |      |
   |       |             |      |          |      |      |
   | tail------          | ...  |    ----->| ...  |      |
   |-------|  |                      |                   v
              |                      |                 -----
              |                      |                  ---
              |                      |                   -
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

INCLUDE FILE: sllLib.h
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

/* optimized version unavailable for MIPS targets */

/* do not use optimized versions for MIPS targets yet */
#if (defined(PORTABLE) || (CPU_FAMILY==MIPS))
#define sllALib_PORTABLE
#endif

#ifndef sllALib_PORTABLE

	/* internal */

	.globl	sllPutAtHead		/* put node at head of list */
	.globl	sllPutAtTail		/* put node at tail of list */
	.globl	sllGet			/* get and delete node from head */

	/* external */


	.text
	.set	reorder

/*******************************************************************************
*
* sllPutAtHead - add node to beginning of list
*
* This routine adds the specified node to the end of the specified list.
*
* RETURNS: void
*
* SEE ALSO: sllPutAtTail (2)

* void sllPutAtHead (pList, pNode)
*     SL_LIST *pList;	/* pointer to list descriptor *
*     SL_NODE *pNode;	/* pointer to node to be added *

* INTERNAL

    {
    if ((pNode->next = pList->head) == NULL)
	pList->head = pList->tail = pNode;
    else
	pList->head = pNode;
    }
*/

	.ent	sllPutAtHead
sllPutAtHead:

	lw	t0, 0(a0)	/* ((pNode->next = pList->head) == NULL) */
	sw	t0, 0(a1)
	bne	zero, t0 , sllHead1

	sw	a1, 4(a0)	/* pList->tail = pNode */

sllHead1:
	sw	a1, 0(a0)	/* pList->head = pNode */

	j	ra
	.end	sllPutAtHead

/*******************************************************************************
*
* sllPutAtTail - add node to end of list
*
* This routine adds the specified node to the end of the specified singly
* linked list.
*
* RETURNS: void
*
* SEE ALSO: sllPutAtHead (2)

* void sllPutAtTail (pList, pNode)
*     SL_LIST *pList;	/* pointer to list descriptor *
*     SL_NODE *pNode;	/* pointer to node to be added *

* INTERNAL

    {
    pNode->next = NULL;

    if (pList->head == NULL)
	pList->tail = pList->head = pNode;
    else
	pList->tail->next = pNode;
	pList->tail = pNode;
    }
*/

	.ent	sllPutAtTail
sllPutAtTail:

	sw	zero, 0(a1)	/* pNode->next = NULL */

	lw	t0, 0(a0)	/* if (pList->head == NULL) */
	bne	zero, t0, sllTail1

	sw	a1,4(a0)	/* pList->tail = NODE */
	sw	a1,0(a0)	/* pList->head = NODE */
	j	ra

sllTail1:
	lw	t0, 4(a0)	/* get pList->tail into t0 */
	sw	a1, 0(t0)	/* pList->tail->next = pNode */
	sw	a1, 4(a0)	/* pList->tail = NODE */

sllTail2:
	j	ra
	.end	sllPutAtTail

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

* SL_NODE *sllGet (pList)
*    FAST SL_LIST *pList;	/* pointer to list from which to get node *

* INTERNAL

    {
    FAST SL_NODE *pNode;

    if ((pNode = pList->head) != NULL)
	pList->head = pNode->next;

    return (pNode);
    }
*/

	.ent	sllGet
sllGet:

	lw	v0, 0(a0)	/* get head into v0 */
	beq	zero,v0,sllGet1	/* if pList->head == NULL then done */

	lw	t0, 0(v0)
	sw	t0, 0(a0)	/* (pNode)->next to pList->head */

sllGet1:
	j	ra
	.end	sllGet

#endif /* sllALib_PORTABLE */
