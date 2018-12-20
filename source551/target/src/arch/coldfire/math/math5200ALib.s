/* math5200ALib.s - integer math support for the MCF5200 */

/* Copyright 1984-2000 Wind River Systems, Inc. */
        .data
        .globl  _copyright_wind_river
        .long   _copyright_wind_river

/*
modification history
--------------------
01a,25mar96,mem created.
*/

/*
DESCRIPTION

INTERNAL
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
	
	/* internals */

	.globl	___udivdisi2		/* 64/32 -> 32r 32q */
	.globl	___umulsi2di		/* 32 x 32 -> 64 */

	/* externals */

	.text
	.even


/*****************************************************************************
*
* ___udivdisi2 - 64/32 divide
*
* RETURNS: N/A

* __udivuldisi2 (high(A), low(A), B)

*/

___udivdisi2:
	movel	a7@(4),d0		/* high(A) */
	movel	a7@(8),d1		/* low(A) */
	movel	a7@(12),a0		/* B */
	subl	#24,a7
	moveml	d2-d7,a7@
	
	/* setup */
	movel	a0,d5		/* B */
	clrl	d4
	
	/*
	 * A = d0:d1
	 * P = d2:d3
	 * B = d4:d5
	 * T = d6,d7
	 * C = a0
	 */
	
	clrl	d2		| clear P
	clrl	d3
	movel	#63,a0		| setup count
udiv_1:
	addl	d1,d1		| shift (P,A) left
	addxl	d0,d0
	addxl	d3,d3
	addxl	d2,d2
	movel	d2,d6		| copy P to T
	movel	d3,d7
	subl	d5,d7		| T = T - B
	subxl	d4,d6
	bmi	udiv_2		| J/ result negative
	addql	#1,d1		| set low bit of A to 1
	movel	d7,d3		| P = T
	movel	d6,d2
udiv_2:
	subql	#1,a0		| decrement count
	tstl	a0
	bpl	udiv_1		| loop

	/*
	 * Return Q in d0 and R in d1
	 */
	movel	d1,d0		| Return Q in d0
	movel	d3,d1		| Return R in d1
	moveml	a7@,d2-d7
	addl	#24,a7
	rts

/*****************************************************************************
*
* ___umulsi2di - 64/32 divide
*
* RETURNS: N/A

* __umulsi2di (A, B)

*/

___umulsi2di:
	movel	a7@(4),d0		/* A */
	movel	a7@(8),d1		/* B */
	subl	#12,a7
	moveml	d2-d4,a7@
	
	/*
	 * A = d0
	 * B = d1
	 * P = d2
	 * T = d3
	 * C = d4
	 */
	
	clrl	d2		| Clear P
	movel	#31,d4		| Setup count
umul_1:
	clrl	d3		| Clear T
	lsrl	#1,d0		| Shift A right
	jcc	1f
	addl	d1,d2		| Add B to P
	addxl	d3,d3		| Save high bit of carry out
1:
	lsrl	#1,d2		| Shift P right
	jcc	1f
	bset	#31,d0		| Set high bit in A
1:
	tstl	d3		| Check carry out of addition.
	jeq	1f
	bset	#31,d2		| Set bit 31 of P to carry out
1:
	subql	#1,d4		| decrement count
	bpl	umul_1		| loop

	/*
	 * Return high product in d1, low product in d0
	 */
	movel	d2,d1		| Return P in d1
	moveml	a7@,d2-d4
	addl	#12,a7
	rts
