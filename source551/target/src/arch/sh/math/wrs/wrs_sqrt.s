/* sqrt.s - double precision square root for the Hitachi SH-4 */

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
* sqrt - compute a non-negative square root (ANSI)
*
* RETURNS: The double-precision square root of <x>.
*
* double sqrt		/@                                     (to dr0) @/
*     (
*     double x		/@ value to compute the square root of (in dr4) @/
*     )
*
*/
        .global	_sqrt
        .type	_sqrt,@function
	.align	_ALIGN_TEXT
_sqrt:
	mov.l	SQ_FPSCR,r0;
	sts	fpscr,r7		/* save FPSCR */
	lds	r0,fpscr		/* set double precision mode */

	fmov	fr4,fr0
	fmov	fr5,fr1
	fsqrt	dr0			/* 22 pitches */

	fldi0	fr2
	fldi0	fr3			/* dr2: 0.0 */
	fcmp/gt	dr4,dr2
	bt	SQ_Edom
SQ_Done:
	rts;
	lds	r7,fpscr		/* restore FPSCR */
SQ_Edom:
	mov.l	SQ_Errno,r1;
	mov	#EDOM,r0
	bra	SQ_Done;
	mov.l	r0,@r1			/* errno: EDOM */

		.align	2
SQ_FPSCR:	.long	0x00080000	/* FPSCR.PR = 1 (double precision) */
SQ_Errno:	.long	_errno

