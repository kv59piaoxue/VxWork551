/* sllALib.s - assembly language singly linked list manipulation */

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

#ifndef PORTABLE

	/* internal */

	.globl	_sllPutAtHead		/* put node at head of list */
	.globl	_sllPutAtTail		/* put node at tail of list */
	.globl	_sllGet			/* get and delete node from head */

	/* external */


	.text
	.even

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

_sllPutAtHead:
	link	a6,#0

	movel	a6@(ARG1),a0	/* get pointer to list */
	movel	a6@(ARG2),a1	/* get pointer to node */

	movel	a0@,a1@		/* ((pNode->next = pList->head) == NULL) */
	jne 	sllHead1

	movel	a1,a0@(0x4)	/* pList->tail = pNode */

sllHead1:
	movel	a1,a0@		/* pList->head = pNode */

	unlk	a6
	rts

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

_sllPutAtTail:
	link	a6,#0
	movel	a6@(ARG1),a0	/* get pointer to list */
	movel	a6@(ARG2),a1	/* get pointer to node */

	clrl	a1@		/* pNode->next = NULL */

	tstl	a0@		/* if (pList->head == NULL) */
	jne 	sllTail1

	movel	a1,a0@(0x4)	/* pList->tail = NODE */
	movel	a1,a0@		/* pList->head = NODE */
	jra 	sllTail2

sllTail1:
	movel	a0@(0x4),a0	/* get pList->tail into a0 */
	movel	a1,a0@		/* pList->tail->next = pNode */
	movel	a6@(ARG1),a0	/* get pointer to list */
	movel	a1,a0@(0x4)	/* pList->tail = NODE */

sllTail2:
	unlk	a6
	rts

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

*SL_NODE *sllGet (pList)
*    FAST SL_LIST *pList;	/* pointer to list from which to get node *

* INTERNAL

    {
    FAST SL_NODE *pNode;

    if ((pNode = pList->head) != NULL)
	pList->head = pNode->next;

    return (pNode);
    }
*/

_sllGet:
	link	a6,#0

	movel	a6@(ARG1),a0	/* get pointer to list */

	movel	a0@,d0		/* get head into d0 */
	jeq 	sllGet1		/* if pList->head == NULL then done */

	movel	d0,a1		/* pList->head to a1 */
	movel	a1@,a0@		/* (pNode)->next to pList->head */

sllGet1:
	unlk	a6
	rts

#endif	/* !PORTABLE */
