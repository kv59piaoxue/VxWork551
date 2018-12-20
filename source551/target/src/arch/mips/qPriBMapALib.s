/* qPriBMapALib.s - optimized bit mapped priority queue internals */

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
01o,01aug01,mem  Diab integration.
01n,16jul01,ros  add CofE comment
01m,16jan98,dra  optimized ffsMsb for CW4011, fixed comment.
01k,22feb96,mem  fixed R4000 support.  Was using sw/lw with FRAMERx().
01j,31mar94,cd   made generic stack allocation for 32/64 bit processors.
01i,27jul92,jcf  changed qPriBMapRemove to return OK.
01h,15jul92,ajm  updated for 5.1
01g,08jun92,ajm  now use ffsMsbTbl for hash search
01f,26may92,rrr  the tree shuffle
01e,06oct91,ajm   ported to MIPS
01d,01oct90,dab   changed conditional compilation identifier from
		    HOST_SUN to AS_WORKS_WELL.
01c,12sep90,dab   changed tstl a<n> to cmpl #0,a<n>. changed complex
           +lpf     addressing modes and bfffo instructions to .word's
		    to make non-SUN hosts happy.
01b,10may90,jcf   fixed PORTABLE definition.
		  fixed clobbering of d2 by saving on stack.
01a,15jun89,jcf   written.
*/

/*
DESCRIPTION
This module contains internals to the VxWorks kernel.
These routines have been coded in assembler because they have been optimized
for performance.

INTERNAL
The C code versions of these routines can be found in qPriBMap2Lib.c.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "qPriNode.h"

/* optimized version available for R3000 */

#if defined(PORTABLE)
#define qPriBMapALib_PORTABLE
#endif

#define WORD_TEST 16
#define HALF_TEST 8

#ifndef qPriBMapALib_PORTABLE

	/* globals */
	.globl	qPriBMapPut
	.globl	qPriBMapGet
	.globl	qPriBMapRemove

	.text
	.set	reorder

/*******************************************************************************
*
* qPriBMapPut - insert the specified TCB into the ready queue
*

* void qPriBMapPut (pQPriBMapHead, pQPriNode, key)
*    Q_PRI_BMAP_HEAD	*pQPriBMapHead;
*    Q_PRI_NODE		*pQPriNode;
*    int		key;


*/

	.ent	qPriBMapPut
qPriBMapPut:
	lw	t0, 0(a0)		/* t0 gets highest node ready */
	beq	zero, t0, qPriBMap0	/* check for highNode == NULL */
	lw	t1, Q_PRI_NODE_KEY(t0)	/* read key into t1 */
	sltu	t9, a2, t1		/* is a2 (key) higher priority? */
	beq	zero, t9, qPriBMap1
qPriBMap0:
	sw	a1, 0(a0)		/* pPriNode is highest priority task */
qPriBMap1:
	sw	a2, Q_PRI_NODE_KEY(a1)	/* move key into pPriNode */
	lw	a3, 4(a0)		/* a3 = pQPriBMapHead->pBMapList */

/* qPriBMapMapSet - set the bits in the bit map for the specified priority
 * a3 = pQPriBMapHead->pBMapList
 * a2 = priority
 * returns void
 */

        li      t6, 255         /* load negation constant */
        subu    t5, t6, a2      /* prio = 255 - prio */
        sra     v0, t5, 3       /* create prio >> 3 */
        li      t8, 1           /* load shift value */
        lw      t7, 0(a3)       /* read metaBMap */
        sllv    t9, t8, v0      /* shift 1 left by contents of v0 */
        or      t0, t7, t9      /* or in new metaBmap */
        sw      t0, 0(a3)       /* pBMapList->metaBMap |= (1 << (prio >> 3)) */
        addu    v1, a3, v0      /* create bMap pointer */
        andi    t2, t5, 0x7     /* prio & 0x7 */
        lbu     t1, 4(v1)       /* read indexed bMap field */
        sllv    t4, t8, t2      /* shift 1 left by contents of t2 */
        or      t6, t1, t4      /* or in new bMap */
        sb      t6, 4(v1)       /* pBMapList->bMap [prio >> 3] |=
                                   (1 << (prio & 0x7)) */

	addiu	a0, a3, 36	/* get base of listArray in a0 */
	sll	t0, a2, 3	/* make key double word based */
	move	a2, a1		/* node to add into a2 */
	addu	a0, t0		/* point a0 to key list */
	lw	a1, 4(a0)	/* pPrev = pList->tail */


/* dllAdd - add node to end of list
 * a0 = pList
 * a1 = pPrev
 * a2 = pNode
 * returns void
 */

dllAdd:
        bne     zero, a1, dllAdd1       /* (pPrev == NULL)? */
        lw      t0, 0(a0)               /* pNext = pList->head */
        sw      a2, 0(a0)               /* pList->head = pNode */
        j       dllAdd2                 /* goto next conditional */
dllAdd1:
        lw      t0, 0(a1)               /* pNext = pPrev->next */
        sw      a2, 0(a1)               /* pPrev->next = pNode */

dllAdd2:
        beq     t0, zero, dllAdd3       /* (pNext == NULL)? */
        sw      a2, 4(t0)               /* pNext->previous = pNode */
        sw      t0, 0(a2)               /* pNode->next     = pNext */
        sw      a1, 4(a2)               /* pNode->previous = pPrev */
        j       ra

dllAdd3:
        sw      a2, 4(a0)               /* pList->tail     = pNode */
        sw      t0, 0(a2)               /* pNode->next     = pNext */
        sw      a1, 4(a2)               /* pNode->previous = pPrev */
	j	ra
	.end	qPriBMapPut

/*******************************************************************************
*
* qPriBMapGet -
*

* Q_PRI_NODE *qPriBMapGet (pQPriBMapHead)
*    Q_PRI_BMAP_HEAD *pQPriBMapHead;

*/

	.ent	qPriBMapGet
qPriBMapGet:
	SETFRAME(qPriBMapGet,1)
	subu	sp, FRAMESZ(qPriBMapGet) /* give me some space */
	SW	ra, FRAMERA(qPriBMapGet)(sp) /* save return address */
	lw	a1, 0(a0)		/* get highNode to delete */
	beq	a1, zero, qPriBMapG1	/* if highNode is NULL we're done */
	SW	a1, FRAMER0(qPriBMapGet)(sp) /* save pQPriNode */
	jal	qPriBMapRemove		/* delete the node */
	LW	a1, FRAMER0(qPriBMapGet)(sp) /* restore pQPriNode */
qPriBMapG1:
	LW	ra, FRAMERA(qPriBMapGet)(sp) /* restore ra */
	addiu	sp, sp, FRAMESZ(qPriBMapGet) /* clean stack */
	move	v0, a1			/* return node */
	j	ra			/* back to caller */
	.end	qPriBMapGet

/*******************************************************************************
*
* qPriBMapRemove -
*

*STATUS qPriBMapRemove (pQPriBMapHead, pQPriNode)
*    Q_PRI_BMAP_HEAD *pQPriBMapHead;
*    Q_PRI_NODE *pQPriNode;

*/

	.ent	qPriBMapRemove
qPriBMapRemove:

	move	t8, a0			/* save pQPriBMapHead */
	move	t9, a1			/* save pQPriNode */
	lw	t1, Q_PRI_NODE_KEY(a1) 	/* key into t1 */
	lw	t2, 4(a0)		/* &qPriMapHead->pBMapList */
	addiu	a0, t2, 36		/* get base of listArray in a0 */
	sll	t1, t1, 3		/* make key double word based */
	addu	a0, t1			/* point a0 to key list */
	move	t7, a0			/* save this pointer for later */

/* dllRemove - delete a node from a doubly linked list
 * a0 = pList
 * a1 = pNode
 * returns void
 */

	lw	t0, 4(a1)
	beq	zero, t0, qPriBMapR1	/* (pNode->previous == NULL)? */
	move	a0, t0			/* pList = pNode->previous */
qPriBMapR1:
	lw	t1, 0(a1)		/* pList->head = pNode->next */
	sw	t1, 0(a0)

	bne	zero, t1, qPriBMapR2	/* (pNode->next == NULL)? */
	move	t1, t7			/* t1 = listArray[key] */

qPriBMapR2:
	sw	t0, 4(t1)		/* t1@(4) = pNode->previous */
qPriBMapR3:

	lw	t0, 0(t7)		/* if (pList->head == NULL)         */
	beq	zero, t0, clearMaps	/*     then we clear maps           */
	lw	t1, 0(t8) 		/* if not deleting highest priority */
	bne	t1, t9, qPriBMapDExit	/*     then we are done             */
	sw	t0, 0(t8)		/* update the highest priority task */
	j	qPriBMapDExit


clearMaps:

	lw	a3, 4(t8)		/* a3 = pQPriBMapHead->pBMapList */
	lw	a2, Q_PRI_NODE_KEY(t9)	/* a2 = pQPriNode->key */

/* qPriBMapMapClear - clear the bits in the bit maps for the specified priority
 * a2 = priority,
 * a3 = &qPriBMapMetaMap,
 * returns void
 */

    	li	t6, 255		/* load negation constant */
    	subu	t6, t6, a2	/* prio = 255 - prio */
    	sra	t5, t6, 3	/* create prio >> 3 */
    	li	t3, 1		/* load shift value */
	addu	t4, a3, t5	/* keyed index to bMap */
	lbu	v0, 4(t4)	/* read bMap[priority >> 3] */

	andi	t0, t6, 0x7	/* priority & 0x7 */
	sllv	t0, t3, t0	/* shift 1 left by contents of t0 */
	not	t0, t0		/* complement result */
    	and	v0, v0, t0	/* and in new bMap */
    	sb	v0, 4(t4)	/* pBMapList->bMap[priority >> 3] &=
				   ~(1 << (prio & 0x7)) */
	bne	zero, v0, qPriBMapNoMeta/* if not zero, we're done */

    	lw	t7, 0(a3)	/* read metaBMap */
	sllv	t5, t3, t5	/* shift 1 left by contents of t5 */
	not	t5, t5		/* complement result */
	and	t7, t7, t5	/* and in the bit */
	sw	t7, 0(a3)	/* clear bit in meta map too */

qPriBMapNoMeta:

	lw	t0, 0(t8)	/* have we deleted highest priority */
	bne	t0, t9, qPriBMapDExit

/* qPriBMapMapHigh - return highest priority task
 * a3 = &qPriBMapMetaMap,
 * returns priority in v0
 */

	lw	a0, 0(a3)	/* read metaBMap */

/* ffsMsb - find first set bit (searching from the most significant bit)
 * a0 = 32 bit integer
 * returns ms bit set in v0 (0-31)
 */
	move	v0, zero		/* to pass result */
	beq	zero, a0, ffsNoBitSet	/* zeros means no bit is set */
#if (CPU == CW4011)
	ffs	v0, a0			/* 1->0, 2->1, 4->2, etc. */
#else  /* (CPU == CW4011) */
	srl	t0, a0, WORD_TEST 	/* shift logical half word */
	bne	zero, t0, msHalf	/* != , upper half bit set */
lsHalf:
	srl	t0, a0, HALF_TEST 	/* test ls half word */
	bne	zero, t0, byte1		/* not equal, byte 1
						   has bit set */
byte0:
	move	t1, zero		/* byte 0 has bit set */
	j	calculate
byte1:
	li	t1, 8			/* byte 1 has bit set */
	j	calculate
msHalf:
	srl	t0, t0, HALF_TEST 	/* test ms half word */
	bne	zero, t0, byte3		/* != , byte 3 has bit set */
byte2:
	li	t1, 16			/* byte 2 has bit set */
	j	calculate
byte3:
	li	t1, 24			/* byte 3 has bit set */
calculate:
	srlv	t0, a0, t1		/* put correct byte in byte 0 */
	andi	t0, 0xff		/* make byte oriented */
	la	t2, ffsMsbTbl
	addu	t2, t2, t0
	lbu	v0, (t2)		/* lookup value */
	add	v0, t1			/* fixup for word */
#endif  /* (CPU == CW4011) */
ffsNoBitSet:

	add	a0, a3, v0		/* create index to bMap */
	lbu	a0, 4(a0)		/* pBMapList->bMap[highBits] */
	la	t2, ffsMsbTbl
	addu	t2, t2, a0
	lbu	a0, (t2)		/* create lowBits */
	sll	v0, 3			/* highBits << 3 */
	or	v0, a0			/* result | lowBits */
	li	t0, 255			/* load negation constant */
    	subu	v0, t0, v0		/* return 255 - result */

	sll     v0, 3           	/* make index double word based */
	addiu	a3, a3, 36		/* put listArray base in a3 */
	addu	a3, v0			/* create prio index to listArray */
	lw	v0, 0(a3)		/* read highest prio task */
	sw	v0, 0(t8)		/* put highest task into highNode */
qPriBMapDExit:
	move	v0, zero		/* return OK */
	j	ra
	.end	qPriBMapRemove

#endif /* qPriBMapALib_PORTABLE */
