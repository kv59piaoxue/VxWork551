/* qPriBMapALib.s - optimized bit mapped priority queue internals */

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
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they have been optimized
for performance.

INTERNAL
The C code versions of these routines can be found in qPriBMapLib.c.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "qPriNode.h"

#if defined(PORTABLE)
#define qPriBMapALib_PORTABLE
#endif

#ifndef qPriBMapALib_PORTABLE

	/* globals */

	.globl	_qPriBMapPut
	.globl	_qPriBMapGet
	.globl	_qPriBMapRemove

	.text
	.even

/*******************************************************************************
*
* qPriBMapPut - insert the specified TCB into the ready queue
*

*void qPriBMapPut (pQPriBMapHead, pQPriNode, key)
*    Q_PRI_BMAP_HEAD	*pQPriBMapHead;
*    Q_PRI_NODE		*pQPriNode;
*    int		key;


*/

_qPriBMapPut:
	movel	d2,a7@-			/* push d2 so we can clobber it */
	movel	a4,a7@-			/* push a4 so we can clobber it */
	movel	a5,a7@-			/* push a5 so we can clobber it */

	movel	a7@(0x10),a4		/* ARG1 (pMHead) goes into a4 */
	movel	a7@(0x14),a5		/* ARG2 (pPriNode) goes into a5 */
	movel	a7@(0x18),d0		/* ARG3 (key) goes into d0 */

	movel	a4@,a0			/* a0 gets highest node ready */
	cmpl	#0,a0			/* check for highNode == NULL */
	jeq 	qPriBMap0
	cmpl	a0@(Q_PRI_NODE_KEY),d0	/* is d0 higher priority? */
	jge 	qPriBMap1
qPriBMap0:
	movel	a5,a4@			/* pPriNode is highest priority task */
qPriBMap1:

	movel	d0,a5@(Q_PRI_NODE_KEY)	/* move key into pPriNode */
	notl	d0			/* invert key */
	andl	#0x00ff,d0		/* clear upper bits */

/* qPriBMapMapSet - set the bits in the bit map for the specified priority
 * d0 = priority
 * returns void
 */
	movel	a4@(0x4),a1		/* pMList (metaMap) goes into a1 */
	movel	d0,d1			/* copy priority to d1 */
	lsrl	#3,d1			/* top five bits of d1 to d1 */
	clrl	d2			/* clear out d2 */
	bset	d1,d2			/* set d1 bit # of d2 */
	orl		d2,a1@		/* or d2 into the meta map */
	lea	a1@(4,d1:l),a4
	bset	d0,a4@			/* bit set d0[0:2] into the bit map */

	lsll	#3,d0			/* scale d0 by sizeof (DL_HEAD) 8 */
	lea	a1@(0x24),a4		/* get base of listArray in a4 */
	lea	a4@(0,d0:l),a0		/* a0 = pList */
	movel	a0@(0x4),a1		/* a1 = pList->tail = pPrev */


/* dllAdd - add node to end of list
 * a0 = pList
 * a1 = pLastNode
 * a5 = pNode
 * returns void
 */
	    cmpl	#0,a1		/* (pPrev == NULL)? */
	    jne 	qPriBMap2
	    movel	a5,a0@		/* pList->head = pNode */
	    jra 	qPriBMap3	/* goto next conditional */
qPriBMap2:
	    movel	a5,a1@		/* pPrev->next	   = pNode */
qPriBMap3:
	    movel	a5,a0@(0x4)	/* pList->tail 	   = pNode */
	    clrl	a5@		/* pNode->next	   = NULL */
	    movel	a1,a5@(0x4)	/* pNode->previous = pPrev */

	movel	a7@+,a5			/* pop a5 */
	movel	a7@+,a4			/* pop a4 */
	movel	a7@+,d2			/* pop d2 */
	rts

/*******************************************************************************
*
* qPriBMapGet -
*

*Q_PRI_NODE *qPriBMapGet (pQPriBMapHead)
*    Q_PRI_BMAP_HEAD *pQPriBMapHead;

*/

_qPriBMapGet:
	movel	a7@(0x4),a0		/* pMHead into a0 */
	movel	a0@,a7@-		/* push highNode to delete */
	jeq 	qPriBMapG1		/* if highNode is NULL we're done */
	movel	a0,a7@-			/* push pMHead */
	jsr	_qPriBMapRemove		/* delete the node */
	addl	#0x4,a7			/* clean up second argument */
qPriBMapG1:
	movel	a7@+,d0			/* return node */
	rts

/*******************************************************************************
*
* qPriBMapRemove
*

*STATUS qPriBMapRemove (pQPriBMapHead, pQPriNode)
*    Q_PRI_BMAP_HEAD *pQPriBMapHead;
*    Q_PRI_NODE *pQPriNode;

*/

_qPriBMapRemove:
	movel	d2,a7@-			/* push d2 so we can clobber it */
	movel	a2,a7@-			/* push a2 so we can clobber it */

	movel	a7@(0xc),a2		/* ARG1 (pMHead) goes into a2 */
	movel	a7@(0x10),a1		/* ARG2 (pPriNode) goes into a1 */

	movel	a1@(Q_PRI_NODE_KEY),d0	/* key into d0 */
	notl	d0			/* invert key */
	andl	#0x00ff,d0		/* clear upper bits */
	movel	d0,d1			/* copy priority to d1 */
	lsll	#3,d1			/* scale d1 by sizeof (DL_HEAD) 8 */
	movel	a2@(0x4),a0		/* pMList (metaMap) goes into a0 */
	lea	a0@(0x24,d1:l),a0	/* pList into a0 */

/* dllRemove - delete a node from a doubly linked list
 * a0 = pList
 * a1 = pNode
 * returns void
 */
	    tstl	a1@(0x4)	/* (pNode->previous == NULL)? */
	    jeq 	qPriBMapR1
	    movel	a1@(0x4),a0	/* pNode->previous into a0 */
qPriBMapR1:
	    movel	a1@,a0@		/* pNode->next into a0@ */

	    tstl	a1@		/* (pNode->next == NULL)? */
	    jne 	qPriBMapR2
	    movel	a2@(0x4),a0	/* pMList (metaMap) goes into a0 */
	    lea		a0@(0x24,d1:l),a0 /* pList into a0 */
	    jra 	qPriBMapR3
qPriBMapR2:
	    movel	a1@,a0		/* pNode->next into a0 */
qPriBMapR3:
	    movel	a1@(4),a0@(4)	/* pNode->previous into a0@(4) */

	movel	a2@(0x4),a0		/* pMList (metaMap) goes into a0    */
	movel	a0@(0x24,d1:l),d2	/* if (pList->head == NULL)         */
	jeq 	clearMaps		/*     then we clear maps           */
	cmpl	a2@,a1			/* if not deleting highest priority */
	jne 	qPriBMapDExit		/*     then we are done             */
	movel	d2,a2@			/* update the highest priority task */
	jra 	qPriBMapDExit


clearMaps:

/* qPriBMapMapClear - clear the bits in the bit maps for the specified priority
 * d0 = priority,
 * a0 = &qPriBMapMetaMap,
 * returns void
 */
	movel	d0,d1			/* copy priority to d1 */
	lsrl	#3,d1			/* top five bits of d1 to d1 */
	movel	a2,a7@-
	lea	a0@(4,d1:l),a2
	bclr	d0,a2@			/* clear bit d0[0:2] in map */
	movel	a7@+,a2
	tstb	a0@(4,d1:l)		/* did we clear the last bit in field */
	jne 	qPriBMapNoMeta		/* if not zero, we're done */
	moveq	#-1,d2			/* fill d2 with ones */
	bclr	d1,d2			/* clear d1 bit # of d2 */
	andl	d2,a0@			/* clear bit in meta map */
qPriBMapNoMeta:

	cmpl	a2@,a1			/* have we deleted highest priority */
	jne 	qPriBMapDExit

/* qPriBMapHigh - return highest priority task
 * a0 = &qPriBMapMetaMap,
 * returns highest priority in Q in d0, or random (0,255) if Q empty
 */
	lea	_ffsMsbTbl,a1	/* lookup table address in a1 */
	clrl	d1		/* clear out d1 */
	movew	a0@,d1		/* put msw into d1 */
	jeq 	qPriBMapLsw	/* if zero, try the lsw */
	cmpl	#0x100,d1	/* compare msw to 0x100 */
	jcs 	qPriBMapMswLsb	/* if unsigned less than, then MswLsb */
	lsrl	#8,d1		/* shift Msb to Lsb of d1 */
	moveb	a1@(0,d1:l),d1	/* find first bit set of d1[0:1] */
	addl	#24,d1		/* add bit offset to MswMsb (24) */
	jra 	qPriBMapGetHigh	/* go do the second tier bfffo */

qPriBMapMswLsb:
	moveb	a1@(0,d1:l),d1	/* find first bit set of d1[0:7] */
	addl	#16,d1		/* add bit offset to MswLsb (16) */
	jra 	qPriBMapGetHigh	/* go do the second tier bfffo */

qPriBMapLsw:
	moveb	a0@(2),d1	/* put LswMsb in d1 */
	jeq 	qPriBMapLswLsb	/* if zero, try LswLsb */
	moveb	a1@(0,d1:l),d1	/* find first bit set of d1[0:7] */
	addql	#8,d1		/* add bit offset to LswMsb (8) */
	jra 	qPriBMapGetHigh	/* go do the second tier bfffo */

qPriBMapLswLsb:
	movel	a0@,d1		/* put LswLsb in d1 */
	moveb	a1@(0,d1:l),d1	/* find first bit set of d1[0:7] */

qPriBMapGetHigh:
	movel	d1,d0		/* put copy of d1 in d0 */
	lsll	#3,d0		/* multiply meta priority by 8 */
	moveb	a0@(4,d1:l),d1	/* move tier two bit field into d1 */
	/*
	 * The following sequence is equiv. to:
	 *   addb	a1@(0,d1:l),d0
	 */
	moveb	a1@(0,d1:l),d1	/* get tier two */
	addl	d0,d1		/* add other way around */
	moveb	d1,d0		/* final result */
	
qPriBMapNewHigh:
	lsll	#3,d0			/* scale d0 by sizeof (DL_HEAD) 8 */
	movel	a0@(0x24,d0:l),a2@	/* get highest task into highNode */

qPriBMapDExit:
	movel	a7@+,a2			/* pop a2 */
	movel	a7@+,d2			/* pop d2 */
	clrl	d0			/* return OK */
	rts

#endif	/* !qPriBMapALib_PORTABLE */
