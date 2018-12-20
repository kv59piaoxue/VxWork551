/* qPriBMapALib.s - optimized bit mapped priority queue internals */

/* Copyright 1984-2000 Wind River Systems, Inc. */

	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01f,28mar00,hk   added .type directive to function names.
01e,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01d,29jul96,hk   changed to use 'mova', added DEBUG_LOCAL_SYMBOLS option.
		 changed 'jsr' to _qPriBMapRemove in _qPriBMapGet to 'bsr'.
01c,19may95,hk   worked around 'mova' alignment problem.
01b,01may95,hk   optimized.
01a,23apr95,hk   written based on mc68k-01m.
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

#define	BMAP_LIST_ARRAY		36

	/* globals */

#undef	DEBUG_LOCAL_SYMBOLS

	.globl	_qPriBMapPut
	.globl	_qPriBMapGet
	.globl	_qPriBMapRemove
#ifdef	DEBUG_LOCAL_SYMBOLS
	.globl	qPriBMapPut1
	.globl	qPriBMapPut2
	.globl	qPriBMapPut3
	.globl	qPriBMapGet1
	.globl	dllRemove1
	.globl	dllRemove2
	.globl	clearMaps
	.globl	qPriBMapNoMeta
	.globl	qPriBMapMswLsb
	.globl	qPriBMapLsw
	.globl	qPriBMapLswLsb
	.globl	qPriBMapGetHigh
	.globl	qPriBMapDExit
	.globl	qPriBitTable
	.globl	FfsMsbTbl
#endif	/* DEBUG_LOCAL_SYMBOLS */

	.text

/*******************************************************************************
*
* qPriBMapPut - insert the specified TCB into the ready queue
*
* This routine inserts a node into a priority bit mapped queue.  The insertion
* is based on the specified priority key which is constrained to the range
* 0 to 255.  The highest priority is zero.

* void qPriBMapPut
*     (
*     Q_PRI_BMAP_HEAD	*pQPriBMapHead,
*     Q_PRI_NODE	*pQPriNode,
*     ULONG		key
*     )

* INTERNAL:
*                      +-- Q_PRI_BMAP_HEAD -----+
*    pQPriBMapHead --->| Q_PRI_NODE *highNode   |   +-- BMAP_LIST -------------+
*                      | BMAP_LIST  *pBMapList ---->| UINT32  metaBMap         |
*                      | UINT        nPriority  |   | UINT8   bMap [32]        |
*                      +------------------------+   | DL_LIST listArray [256] -+
*                                                   |  | DL_NODE *head         |
*                  +---- Q_PRI_NODE -----+          |  | DL_NODE *tail         |
*    pQPriNode --->| DL_NODE node -------+          +--+-----------------------+
*               +0 |  | dlnode *next     |
*               +4 |  | dlnode *previous |
*                  |  +------------------+
*               +8 | ULONG   key         |
*                  +---------------------+
*/
	.align	_ALIGN_TEXT
	.type	_qPriBMapPut,@function

					/* r4: pQPriBMapHead           */
					/* r5: pQPriNode               */
_qPriBMapPut:				/* r6: key                     */
	mov.l	@r4,r7			/* r7: pQPriBMapHead->highNode */
	mov.l	r6,@(Q_PRI_NODE_KEY,r5)	/* pQPriNode->key = key        */
	tst	r7,r7
	bt	qPriBMapPut1

	mov.l	@(Q_PRI_NODE_KEY,r7),r0	/* r0: pQPriBMapHead->highNode->key */
	cmp/hi	r6,r0
	bf	qPriBMapPut2

qPriBMapPut1:
	mov.l	r5,@r4			/* pQPriBMapHead->highNode = pQPriNode*/

qPriBMapPut2:
	mov.l	@(4,r4),r4		/* r4: pQPriBMapHead->pBMapList */

/* LOCAL void qPriBMapSet (BMAP_LIST *pBMapList, int priority)
 *
 *		r7:	(priority & 0x7)
 *		r6:	priority ('key' in outer level)
 *		r4:	pBMapList, &pBMapList->metaBMap
 *		r3:	(priority >> 3)
 *		r0:	&qPriBitTable
 */
		not	r6,r3
		extu.b	r3,r3		/* r3: priority = 255 - priority */
		mov	#0x7,r7
		and	r3,r7		/* r7: (priority & 0x7)          */
		shlr	r3
		shlr2	r3		/* r3: (priority >> 3)           */
		mova	qPriBitTable,r0	/* (qPriBitTable must be long aligned)*/
		mov	r3,r1
		shll2	r1
		mov.l	@(r0,r1),r2	/* r2: (1 << (priority >> 3))    */
		mov.l	@r4,r1		/* r1: pBMapList->metaBMap       */
		or	r2,r1
		mov.l	r1,@r4
		shll2	r7
		mov.l	@(r0,r7),r2	/* r2: (1 << (priority & 0x7))   */
		add	r4,r3
		mov.b	@(4,r3),r0;	/* r0: pBMapList->bMap [priority >> 3]*/
	shll r6
		or	r2,r0
		mov.b	r0,@(4,r3)

	shll2	r6
	add	#BMAP_LIST_ARRAY,r6
	add	r6,r4		/*r4:&pQPriBMapHead->pBMapList->listArray[key]*/
/*
 * void dllAdd (pList, pNode)
 */
		mov.l	@(4,r4),r1	/* r1: pPrev = pList->tail */
		mov	#0,r0		/* r0: NULL                */
		mov.l	r5,@(4,r4)	/* pList->tail     = pNode */
		mov.l	r0,@r5		/* pNode->next     = NULL  */
		mov.l	r1,@(4,r5)	/* pNode->previous = pPrev */
		tst	r1,r1		/* (pPrev == NULL) ?       */
		bt	qPriBMapPut3
		mov	r1,r4
qPriBMapPut3:
	rts;	mov.l	r5,@r4		/* pList->head     = pNode */

/*******************************************************************************
*
* qPriBMapGet - remove and return first node in priority bit-mapped queue
*
* This routine removes and returns the first node in a priority bit-mapped
* queue.  If the queue is empty, NULL is returned.

* Q_PRI_NODE *qPriBMapGet
*     (
*     Q_PRI_BMAP_HEAD *pQPriBMapHead
*     )

* RETURN: Pointer to first queue node in queue head, or NULL if queue is empty.

* INTERNAL:
*	r5:	pQPriNode
*	r4:	pQPriBMapHead
*/
#define	QPRIBMAPREMOVE_NOT_CLOBBER_R5

	.align	_ALIGN_TEXT
	.type	_qPriBMapGet,@function

_qPriBMapGet:
	mov.l	@r4,r5;
	tst	r5,r5
	bt	qPriBMapGet1		/* if highNode is NULL we're done */

#ifdef	QPRIBMAPREMOVE_NOT_CLOBBER_R5
	sts.l	pr,@-sp
	bsr	_qPriBMapRemove;	/* r4: pQPriBMapHead, r5: pQPriNode */
	nop
	lds.l	@sp+,pr
#else	/* QPRIBMAPREMOVE_NOT_CLOBBER_R5 */
	mov.l	r8,@-sp
	sts.l	pr,@-sp
	bsr	_qPriBMapRemove;	/* r4: pQPriBMapHead, r5: pQPriNode */
	mov	r5,r8			/* save pQPriNode */
	mov	r8,r0			/* r0: pQPriNode */
	lds.l	@sp+,pr
	rts;
	mov.l	@sp+,r8
#endif	/* QPRIBMAPREMOVE_NOT_CLOBBER_R5 */

qPriBMapGet1:
	rts;
	mov	r5,r0			/* r0: pQPriNode */

/*******************************************************************************
*
* qPriBMapRemove - remove a node from a priority bit mapped queue
*
* This routine removes a node from the specified bit mapped queue.

* STATUS qPriBMapRemove
*     (
*     Q_PRI_BMAP_HEAD *pQPriBMapHead;
*     Q_PRI_NODE      *pQPriNode;
*     )

* RETURN: OK, always.

* INTERNAL:
*                      +-- Q_PRI_BMAP_HEAD -----+
*    pQPriBMapHead --->| Q_PRI_NODE *highNode   |   +-- BMAP_LIST -------------+
*                      | BMAP_LIST  *pBMapList ---->| UINT32  metaBMap         |
*                      | UINT        nPriority  |   | UINT8   bMap [32]        |
*                      +------------------------+   | DL_LIST listArray [256] -+
*                                                   |  | DL_NODE *head         |
*                  +---- Q_PRI_NODE -----+          |  | DL_NODE *tail         |
*    pQPriNode --->| DL_NODE node -------+          +--+-----------------------+
*                  |  | dlnode *next     |
*                  |  | dlnode *previous |
*                  |  +------------------+
*                  | ULONG   key         |
*                  +---------------------+
*/
	.align	_ALIGN_TEXT
	.type	_qPriBMapRemove,@function

					/* r4: pQPriBMapHead            */
_qPriBMapRemove:			/* r5: pQPriNode                */
	mov.l	@(Q_PRI_NODE_KEY,r5),r7	/* r7: pQPriNode->key           */
	mov.l	@(4,r4),r0		/* r0: pQPriBMapHead->pBMapList */
	mov	r7,r6
	shll	r6
	shll2	r6			/*     key*8 indexes listArray[256] */
	add	#BMAP_LIST_ARRAY,r6	/*     add offset to listArray[0]   */
	add	r0,r6			/* r6: &pQPriBMapHead->pBMapList    */
					/*	->listArray[pQPriNode->key] */
/*		    r6     r5
 * void dllRemove (pList, pNode)
 *
 * (same)	r7:			(pQPriNode->key)
 * (same)	r6:	pList		(&listArray[pQPriNode->key])
 * (same)	r5:	pNode		(pQPriNode)
 * (same)	r4:			(pQPriBMapHead)
 * (clobber)	r3:
 * (clobber)	r2:
 * (clobber)	r1:
 * (clobber)	r0:
 */
		mov	r6,r3
		mov.l	@(4,r5),r1	/* r1: pNode->previous        */
		mov.l	@r5,r0		/* r0: pNode->next            */
		mov	r1,r2
		tst	r1,r1		/* (pNode->previous == NULL)? */
		bf	dllRemove1	/* r1: pNode->previous        */
		mov	r3,r1		/* r1: pList                  */
dllRemove1:	mov.l	r0,@r1
		tst	r0,r0		/* (pNode->next == NULL)?     */
		bt	dllRemove2
		mov	r0,r3
dllRemove2:	mov.l	r2,@(4,r3)

	mov.l	@r6,r0;			/* r0: pList->head              */
	mov.l	@(4,r4),r3		/* r3: pQPriBMapHead->pBMapList */
	tst	r0,r0			/* If (pList->head == NULL)         */
	bt	clearMaps		/*     then we clear maps           */

	mov.l	@r4,r1			/* r1: pQPriBMapHead->highNode  */
	cmp/eq	r1,r5			/* If not deleting highest priority */
	bf	qPriBMapDExit		/*     then we are done             */

	bra	qPriBMapDExit;
	mov.l	r0,@r4			/* update the highest priority task */

clearMaps:
/*			 r3          r7
 * void qPriBMapClear (pBMapList, priority)
 *
 * (clobber)	r7:	(priority & 0x7)
 * (clobber)	r6:	(priority >> 3)
 * (same)	r5:
 * (same)	r4:
 * (same)	r3:	pBMapList, &pBMapList->metaBMap
 * (clobber)	r2:
 * (clobber)	r1:
 * (clobber)	r0:	&qPriBitTable
 */
		not	r7,r6
		extu.b	r6,r6		/* r6: priority = 255 - priority */
		mov	#7,r7
		and	r6,r7		/* r7: (priority & 0x7) */
		shlr	r6
		shlr2	r6		/* r6: (priority >> 3) */

		mova	qPriBitTable,r0	/* (qPriBitTable must be long aligned)*/
		shll2	r7
		mov.l	@(r0,r7),r1	/* r1: (1 << (priority & 0x7)) */
		mov	r3,r2
		add	r6,r2
		mov.b	@(4,r2),r0	/* r0: pBMapList->bMap [priority >> 3]*/
		not	r1,r1
		and	r1,r0
		mov.b	r0,@(4,r2)
		tst	#0xff,r0
		bf	qPriBMapNoMeta

		mova	qPriBitTable,r0	/* (qPriBitTable must be long aligned)*/
		shll2	r6
		mov.l	@(r0,r6),r1	/* r1: (1 << (priority >> 3)) */
		mov.l	@r3,r0		/* r0: pBMapList->metaBMap */
		not	r1,r1
		and	r1,r0
		mov.l	r0,@r3

qPriBMapNoMeta:
	mov.l	@r4,r1
	cmp/eq	r1,r5			/* have we deleted highest priority? */
	bf	qPriBMapDExit		/* If not, then we are done          */

/*			r3
 * int qPriBMapHigh (pBMapList)
 *
 * (clobber)	r7:
 * (clobber)	r6:
 * (same)	r5:	(pQPriNode)
 * (same)	r4:	(pQPriBMapHead)
 * (same)	r3:	 pBMapList
 * (clobber)	r2:	
 * (clobber)	r1:
 * (clobber)	r0:
 */
		mov.l	@r3,r6			/* r6: pBMapList->metaBMap */

		mov.l	FfsMsbTbl,r0		/* lookup table address in r0 */
		mov	r6,r1
		shlr16	r1
		tst	r1,r1
		bt	qPriBMapLsw
		mov	r1,r2			/* 0x????xxxx */
		shlr8	r1
		tst	r1,r1
		bt	qPriBMapMswLsb
		mov.b	@(r0,r1),r7		/* 0x??xxxxxx */
		bra	qPriBMapGetHigh;
		add	#24,r7
qPriBMapMswLsb:
		mov.b	@(r0,r2),r7		/* 0x00??xxxx */
		bra	qPriBMapGetHigh;
		add	#16,r7
qPriBMapLsw:
		mov	r6,r1			/* 0x0000???? */
		shlr8	r1
		tst	r1,r1
		bt	qPriBMapLswLsb
		mov.b	@(r0,r1),r7		/* 0x0000??xx */
		bra	qPriBMapGetHigh;
		add	#8,r7
qPriBMapLswLsb:
		mov.b	@(r0,r6),r7		/* 0x000000?? */
qPriBMapGetHigh:
		mov	r0,r2			/* r2: _ffsMsbTbl */
		mov	r3,r1			/* r3: pBMapList */
		add	r7,r1			/* r7: highBits */
		mov.b	@(4,r1),r0
		shll	r7
		extu.b	r0,r0			/* r0: bMap[highBits] */
		mov.b	@(r0,r2),r6		/* r6: lowBits */
		shll2	r7			/* r7: (highBits << 3) */
		or	r6,r7	/* r7: (((highBits << 3) | lowBits) & 0xff) */
		not	r7,r7
		extu.b	r7,r0			/* r0: 255 - r7 */

/* qPriBMapNewHigh: */
	shll	r0
	shll2	r0			/* scale r0 by sizeof (DL_HEAD) 8 */
	add	r3,r0
	mov.l	@(BMAP_LIST_ARRAY,r0),r0
	mov.l	r0,@r4			/* put highest task into highNode */
qPriBMapDExit:
	rts;
	mov	#0,r0			/* return OK */

/* r0 r1 r2 r3 r4 r5 r6 r7 r8 r9 r10 r11 r12 r13 r14 sp pr jsr JSR */

		.align	2
		.type	qPriBitTable,@object

qPriBitTable:	.long	0x00000001, 0x00000002, 0x00000004, 0x00000008
		.long	0x00000010, 0x00000020, 0x00000040, 0x00000080
		.long	0x00000100, 0x00000200, 0x00000400, 0x00000800
		.long	0x00001000, 0x00002000, 0x00004000, 0x00008000
		.long	0x00010000, 0x00020000, 0x00040000, 0x00080000
		.long	0x00100000, 0x00200000, 0x00400000, 0x00800000
		.long	0x01000000, 0x02000000, 0x04000000, 0x08000000
		.long	0x10000000, 0x20000000, 0x40000000, 0x80000000
FfsMsbTbl:	.long	_ffsMsbTbl

#endif	/* !qPriBMapALib_PORTABLE */
