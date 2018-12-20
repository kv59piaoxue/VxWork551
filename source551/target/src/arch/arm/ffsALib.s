/* ffsALib.s - ARM find first set assembly routines */

/* Copyright 1996-1997 Wind River Systems, Inc. */


/*
modification history
--------------------
01e,17oct01,t_m  convert to FUNC_LABEL:
01d,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,27may97,jpd  Amalgamated into VxWorks.
01a,04jul96,ams  Written.
*/

/*
DESCRIPTION
This library implements ffsMsb() and ffsLsb() which returns the most and least
significant bit set respectively.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define ffsALib_PORTABLE
#endif

#ifndef ffsALib_PORTABLE

	/* Exports */

	.global	FUNC(ffsMsb)
	.global	FUNC(ffsLsb)


	/* externals */

	.extern	FUNC(ffsMsbTbl)
	.extern	FUNC(ffsLsbTbl)


	.text
	.balign	4

/* PC-relative-addressable pointers - LDR Rn,=sym was (is?) broken */

L$_MsbTblAddr:	.long	FUNC(ffsMsbTbl)
L$_LsbTblAddr:	.long	FUNC(ffsLsbTbl)

/*******************************************************************************
*
* ffsMsb - find first set bit (searching from the most significant bit)
*
* This routine finds the first bit set in the argument passed it and
* returns the index of that bit.  Bits are numbered starting
* at 1 from the least significant bit.  A return value of zero indicates that
* the value passed is zero.
*
* RETURNS: most significant bit set
*
* NOMANUAL
*
* void ffsMsb
*	(
*	int i	/@ argument to find first set bit in @/
*	)
*
*/

FUNC_LABEL(ffsMsb)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	/*  Quick test for 0 */

	cmp	r0, #0
#ifdef STACK_FRAMES
	ldmeqdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr
#endif /* STACK_FRAMES */


	/* Get reference to Msb table */

	ldr	ip, L$_MsbTblAddr


	/* Test which half */

	movs	r1, r0, lsr #16		/* Get upper 16 bits */
	beq	0f			/* If 0 then in lower */


	/* UPPER HALF */

	movs	r0, r1, lsr #8		/* Get upper 8 bits */

	ldrneb	r0, [r0, ip]		/* If non-zero, byte 3 of initial r0 */
	addne	r0, r0, #25

	ldreqb	r0, [r1, ip]		/* If zero, byte 2 of initial r0 */
	addeq	r0, r0, #17

	/* Done */
#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */


	/* LOWER HALF */
0:
	movs	r1, r0, lsr #8		/* Get upper 8 bits */

	ldrneb	r0, [r1, ip]		/* If non-zero, byte 1 of initial r0 */
	addne	r0, r0, #9

	ldreqb	r0, [r0, ip]		/* If zero, byte 0 of initial r0 */
	addeq	r0, r0, #1

	/* Done */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */


/*******************************************************************************
*
* ffsLsb - find first set bit (searching from the least significant bit)
*
* This routine finds the first bit set in the argument passed it and
* returns the index of that bit.  Bits are numbered starting
* at 1 from the least significant bit.  A return value of zero indicates that
* the value passed is zero.
*
* RETURNS: least significant bit set
*
* NOMANUAL
*
* void ffsLsb
*	(
*	int i	/@ argument to find first set bit in @/
*	)
*
*/

FUNC_LABEL(ffsLsb)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */


	/* Quick test for 0 */

	cmp	r0, #0

#ifdef STACK_FRAMES
	ldmeqdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr
#endif /* STACK_FRAMES */

	/* Get reference to Msb table */

	ldr	ip, L$_LsbTblAddr


	/* Test which half */

	movs	r1, r0, lsl #16		/* Get & check lower 16 bits */
	beq	0f			/* If 0, then in upper */


	/* LOWER HALF */

	ands	r0, r0, #255		/* Check lower 8 bits (byte 0 in r0) */

	ldrneb	r0, [r0, ip]		/* If non-zero, byte 0 of original r0 */
	addne	r0, r0, #1
	
	moveq	r0, r1, lsr #24		/* If zero, byte 1 of original r0 */
	ldreqb	r0, [r0, ip]
	addeq	r0, r0, #9

	/* Done */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */


	/* UPPER HALF */

0:
	mov	r0, r0, lsr #16		/* Get upper 16 bits */
	ands	r1, r0, #255		/* Check lower 8 bits (byte 2 in r0) */

	ldrneb	r0, [r1, ip]		/* If non-zero, byte 2 of original r0 */
	addne	r0, r0, #17
	
	moveq	r0, r0, lsr #8		/* If zero, byte 3 of original r0 */
	ldreqb	r0, [r0, ip]
	addeq	r0, r0, #25

	/* Done */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */


#endif /* ! ffsALib_PORTABLE */
