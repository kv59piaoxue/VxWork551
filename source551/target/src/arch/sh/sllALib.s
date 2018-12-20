/* sllALib.s - assembly language singly linked list manipulation */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01i,28mar00,hk   added .type directive to function names.
01h,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01g,14sep98,hk   simplified CPU conditional in _sllPutAtHead.
01f,16jul98,st   added SH7750 support.
01f,11may98,jmc  added support for SH-DSP and SH3-DSP.
01e,25apr97,hk   changed SH704X to SH7040.
01d,24may96,ja   added support for SH7700.
01c,23jan96,hk   changed bf/s machine code in _sllPutAtHead to use bf.s.
01b,18dec95,hk   added support for SH704X.
01a,15may95,hk   written based on mc68k-01f.
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

/*******************************************************************************
*
* sllPutAtHead - add node to beginning of list
*
* This routine adds the specified node to the end of the specified list.
*
* SEE ALSO: sllPutAtTail (2)

* void sllPutAtHead
*     (
*     SL_LIST *pList,	/@ pointer to list descriptor  @/
*     SL_NODE *pNode	/@ pointer to node to be added @/
*     )

* INTERNAL
*
*    {
*    if ((pNode->next = pList->head) == NULL)
*        pList->head = pList->tail = pNode;
*    else
*        pList->head = pNode;
*    }

* NOTE:	This routine is called from hashLib while booting.
*/
	.align	_ALIGN_TEXT
	.type	_sllPutAtHead,@function

#if	(CPU==SH7000)
				/* r4: pList       */
_sllPutAtHead:			/* r5: pNode       */
	mov.l	@r4,r1;		/* r1: pList->head */
	mov.l	r1,@r5		/*     pNode->next = pList->head */
	tst	r1,r1
	bf	sllHead1
	mov.l	r5,@(4,r4)	/*     pList->tail = pNode       */
sllHead1:
	rts;
	mov.l	r5,@r4		/*     pList->head = pNode       */

#else	/* for any other SH CPU with bf.s instruction */
				/* r4: pList       */
_sllPutAtHead:			/* r5: pNode       */
	mov.l	@r4,r1;		/* r1: pList->head */
	tst	r1,r1
	bf.s	sllHead1	/* .word	0x8f01 */
	mov.l	r1,@r5		/*     pNode->next = pList->head */
	mov.l	r5,@(4,r4)	/*     pList->tail = pNode       */
sllHead1:
	rts;
	mov.l	r5,@r4		/*     pList->head = pNode       */

#endif	/* CPU==SH7000 */

/*******************************************************************************
*
* sllPutAtTail - add node to end of list
*
* This routine adds the specified node to the end of the specified singly
* linked list.
*
* SEE ALSO: sllPutAtHead (2)

* void sllPutAtTail
*     (
*     SL_LIST *pList,	/@ pointer to list descriptor  @/
*     SL_NODE *pNode	/@ pointer to node to be added @/
*     )

* INTERNAL
*
*    {
*    pNode->next = NULL;
*
*    if (pList->head == NULL)
*        pList->tail = pList->head = pNode;
*    else
*        pList->tail->next = pNode;
*        pList->tail = pNode;			/@ XXX redundant bug! @/
*    }

* NOTE:	This routine seems not to be used in VxWorks 5.1.1
*/
	.align	_ALIGN_TEXT
	.type	_sllPutAtTail,@function

				/* r4: pList               */
_sllPutAtTail:			/* r5: pNode               */
	mov	#0,r0		/* r0: NULL                */
	mov.l	@r4,r1;		/* r1: pList->head         */
	mov.l	r0,@r5		/*     pNode->next = NULL  */
	tst	r1,r1
	bt	sllTail1

	mov.l	@(4,r4),r1;	/* r1: pList->tail               */
	mov.l	r5,@r1		/*     pList->tail->next = pNode */
	rts;
	mov.l	r5,@(4,r4)	/*     pList->tail = pNode */

sllTail1:
	mov.l	r5,@r4		/*     pList->head = pNode */
	rts;
	mov.l	r5,@(4,r4)	/*     pList->tail = pNode */

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

* SL_NODE *sllGet
*    (
*    FAST SL_LIST *pList;	/@ pointer to list from which to get node @/
*    )

* INTERNAL
*
*    {
*    FAST SL_NODE *pNode;
*
*    if ((pNode = pList->head) != NULL)
*        pList->head = pNode->next;
*
*    return (pNode);
*    }

* NOTE:	This routine seems not to be used in VxWorks 5.1.1
*/
	.align	_ALIGN_TEXT
	.type	_sllGet,@function

_sllGet:			/* r4: pList               */
	mov.l	@r4,r0;		/* r0: pNode = pList->head */
	tst	r0,r0
	bt	sllGet1
	mov.l	@r0,r1;		/* r1: pNode->next         */
	rts;
	mov.l	r1,@r4
sllGet1:
	rts;
	nop

#endif	/* !PORTABLE */
