/* vxALib.s - miscellaneous assembly language routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01b,26nov01,dee  remove references to MCF5200
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines.

SEE ALSO: vxLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	.text
	.even

	/* internals */

	.globl _a5RegGet
	.globl _a5RegSet
	.globl _vxMemProbeSup
	.globl _vxMemProbeTrap
	.globl _vxTas

	/* externals */

	.globl _exit

	.text
	.even

/******************************************************************************
*
* a5RegGet - return the value of a5
*
* This routine returns the current value in register a5.
*
* RETURNS: the current value of register a5.
*/

_a5RegGet:
	link	a6,#0
	movel	a5,d0
	unlk	a6
	rts
	
/******************************************************************************
*
* a5RegSet - set a5 with the given value
*
* This routine sets the value of a5 for the given task.
*
*/

_a5RegSet:
	link	a6,#0
	movel	a6@(ARG1),a5
	unlk	a6
	rts

/*******************************************************************************
*
* vxMemProbeSup - vxMemProbe support routine
*
* This routine is called to try to read byte, word, or long, as specified
* by length, from the specified source to the specified destination.
*
* NOMANUAL

STATUS vxMemProbeSup (length, src, dest)
    (
    int 	length,	// length of cell to test (1, 2, 4) *
    char *	src,	// address to read *
    char *	dest	// address to write *
    )

*/

_vxMemProbeSup:
	link	a6,#0

	movel	a6@(ARG2),a0	/* get source address */
	movel	a6@(ARG3),a1	/* get destination address */

	clrl	d0		/* preset status = OK */

	movel	a6@(ARG1),d1	/* get length */
	cmpl	#1,d1
	jne	vmp10
	nop                     /* force write queue flush first */
	moveb	a0@,a1@		/* move byte */
	nop			/* force immediate exception processing */
	jra	vmpRtn

vmp10:
	cmpl	#2,d1
	jne	vmp20
	nop                     /* force write queue flush first */
	movew	a0@,a1@		/* move word */
	nop                     /* force immediate exception processing */
	jra	vmpRtn

vmp20:
	nop                     /* force write queue flush first */
	movel	a0@,a1@		/* move long */
	nop                     /* force immediate exception processing */

	/* 
	 * NOTE: vmpRtn is known by vxMemProbTrap for 68000 because 68000
	 * can't know where to return exactly.
	 */
vmpRtn:
	unlk	a6
	rts

/*******************************************************************************
*
* vxMemProbeTrap - vxMemProbe support routine
*
* This entry point is momentarily attached to the bus error exception
* vector.  It simply sets d0 to ERROR to indicate that the bus error did
* occur, and returns from the interrupt.
*
* 68010 & 68020 NOTE:
* The instruction that caused the bus error must not be run again so we
* have to set some special bits in the exception stack frame.
*
* 68000 & 5200 NOTE:
* On the 68000, the pc in the exception stack frame is NOT necessarily
* the address of the offending instruction, but is merely "in the vicinity".
* Thus the 68000 version of this trap has to patch the exception stack
* frame to return to a known address before doing the RTE.
*
* NOMANUAL
*/

_vxMemProbeTrap:		/* we get here via the bus error trap */

	movel	#vmpRtn,d0
	movel	d0,a7@(4)	/* patch return address (see note above) */

	movel	#-1,d0		/* set status to ERROR */
	rte			/* return to the subroutine */
/*******************************************************************************
*
* vxTas - C-callable atomic test-and-set primitive
*
* This routine provides a C-callable interface to the 680x0 test-and-set
* instruction.  The "tas" instruction is executed on the specified
* address.
*
* RETURNS:
* TRUE if the value had not been set, but now is;
* FALSE if the value was already set.

* BOOL vxTas 
*     (
*     void *	address		/* address to be tested *
*     )

*/
_vxTas:
	moveq	#0,d0
	movel	sp@(4),a0
	
#if (CPU != MCF5400)
	/* no such instruction for ColdFire - forward to BSP. */
	movel	a0,a7@-
	jsr	_sysBusTas
	addql	#4,a7
	rts
#elif (CPU == MCF5400)
	tas	a0@
	bcs	vxTas_exit
	moveq	#1,d0
vxTas_exit:
	rts
#else
#error "Unsupported Coldfire CPU"
#endif
