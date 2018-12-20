/* sqrtf.s - single precision square root for the Hitachi SH-4 */

/* Copyright 2000-2001 Wind River Systems, Inc. */
	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01a,16sep00,zl   derived from mathSh7750ALib.s (01b).
*/

/*
DESCRIPTION
This library provides a C interface to the high-level math functions
on the SH7750 (SH4) on-chip floating-point coprocessor. Functions
capable errors, will set errno upon an error. All functions
included in this library whos names correspond to the ANSI C specification
are, indeed, ANSI-compatable. In the spirit of ANSI, HUGE_VAL is now
supported.

WARNING
This library works only if an SH-4 on-chip coprocessor is in the
system! Attempts to use these routines with no coprocessor present
will result in illegal instruction traps.

SEE ALSO:
fppLib (1), floatLib (1), The C Programming Language - Second Edition

INCLUDE FILE: math.h

INTERNAL
Each routine has the following format:
    o save FPSCR register
    o calculate floating-point function using double parameter
    o transfer result to parameter storage
    o store result to d0 and d1 registers
    o restore FPSCR register
*/

#define _ASMLANGUAGE

#include "vxWorks.h"
#include "asm.h"
#include "errno.h"

#if (EDOM > 0x7f)
#error EDOM > 0x7f, check errno.h
#endif
#if (ERANGE > 0x7f)
#error ERANGE > 0x7f, check errno.h
#endif

/* local definitions */


#if (_BYTE_ORDER == _LITTLE_ENDIAN)
#define FARG1	fr5
#else
#define FARG1	fr4
#endif

        .text

/******************************************************************************
*
* sqrtf - compute a non-negative square root (single precision)
*
* RETURNS: The single-precision square root of <x>.

* float sqrtf		/@                                     (to fr0)   @/
*     (
*     float x		/@ value to compute the square root of (in FARG1) @/
*     )

*/
        .global	_sqrtf
        .type	_sqrtf,@function
	.align	_ALIGN_TEXT
_sqrtf:
	xor	r0,r0
	sts	fpscr,r7		/* save FPSCR */
	lds	r0,fpscr		/* set single precision mode */

	fmov	FARG1,fr0
	fsqrt	fr0			/* 9 pitches */

	fldi0	fr1			/* fr1: 0.0 */
	fcmp/gt	FARG1,fr1
	bt	SQF_Edom
SQF_Done:
	rts;
	lds	r7,fpscr		/* restore FPSCR */
SQF_Edom:
	mov.l	SQF_Errno,r1;
	mov	#EDOM,r0
	bra	SQF_Done;
	mov.l	r0,@r1			/* errno: EDOM */

		.align	2
SQF_Errno:	.long	_errno

