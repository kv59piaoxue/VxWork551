/* ffsALib.s - find first set function */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl  _copyright_wind_river
	.long   _copyright_wind_river


/*
modification history
--------------------
01g,28mar00,hk   added .type directive to function name and table.
01f,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01e,25apr97,hk   deleted needless 'mova' caution.
01d,19may95,hk   put caution on 'mova' use.
01c,30apr95,hk   use same ffsMsbTbl to portable version. made _ffsMsbTbl globl.
01b,22apr95,hk   optimized.
01a,21apr95,hk   written based on mc68k-01l.
*/

/*
DESCRIPTION
This library implements ffsMsb() which returns the most significant bit set. By
taking advantage of the BFFFO instruction of 68020 processors and later, the
implementation determines the first bit set in constant time.  For 68000/68010
ffsMsb() utilizes a lookup table to perform the operation.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"


#if (defined(PORTABLE))
#define ffsALib_PORTABLE
#endif

#ifndef ffsALib_PORTABLE

	/* exports */

	.globl	_ffsMsb
	.globl	_ffsMsbTbl

	.text

/*******************************************************************************
*
* ffsMsb - find first set bit (searching from the most significant bit)
*
* This routine finds the first bit set in the argument passed it and
* returns the index of that bit.  Bits are numbered starting
* at 1 from the least signifficant bit.  A return value of zero indicates that
* the value passed is zero.
*

* int ffsMsb (i)
*     int i;       /* argument to find first set bit in *

* INTERNAL:
* (same)	r7:
* (same)	r6:
* (same)	r5:
* (same)	r4:	i
* (same)	r3:
* (clobber)	r2:
* (clobber)	r1:
* (clobber)	r0:	&_ffsMsbTbl
*/
	.align	_ALIGN_TEXT
	.type	_ffsMsb,@function

_ffsMsb:
	tst	r4,r4
	bt	ffsDone

	mova	_ffsMsbTbl,r0		/* lookup table address in r0 */

	mov	r4,r1
	shlr16	r1
	tst	r1,r1
	bt	ffsLsw
					/* 0x????xxxx */
	mov	r1,r2
	shlr8	r1
	tst	r1,r1
	bt	ffsMswLsb
					/* 0x??xxxxxx */
	mov.b	@(r0,r1),r0
	rts;
	add	#25,r0

ffsMswLsb:				/* 0x00??xxxx */
	mov.b	@(r0,r2),r0
	rts;
	add	#17,r0

ffsLsw:					/* 0x0000???? */
	mov	r4,r1
	shlr8	r1
	tst	r1,r1
	bt	ffsLswLsb
					/* 0x0000??xx */
	mov.b	@(r0,r1),r0
	rts;
	add	#9,r0

ffsLswLsb:				/* 0x000000?? */
	mov.b	@(r0,r4),r0
	rts;
	add	#1,r0

ffsDone:				/* 0x00000000 */
	rts;
	mov	#0,r0

	.align	2
	.type	_ffsMsbTbl,@object

_ffsMsbTbl:
	.byte	0, 0, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 3
	.byte	4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4
	.byte	5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5
	.byte	5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5
	.byte	6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte	6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte	6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte	6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6
	.byte	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
	.byte	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
	.byte	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
	.byte	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
	.byte	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
	.byte	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
	.byte	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7
	.byte	7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7

#endif	/* ! ffsALib_PORTABLE */
