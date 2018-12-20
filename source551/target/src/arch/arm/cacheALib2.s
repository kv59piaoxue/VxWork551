/* cacheALib2.s - ARM cache management assembly routines */

/* Copyright 1996-1998 Wind River Systems, Inc. */

/*
modification history
--------------------
01c,17oct01,t_m  convert to FUNC_LABEL:
01b,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01a,24nov98,jpd  written, removing code from cacheALib.s version 01h.
*/

/*
DESCRIPTION
This library contains routines to control the ARM family caches. It
contains routines that do not vary for different cache types.

INTERNAL
To keep these routines as efficient as possible, they do not generate
stack frames.

SEE ALSO:
.I "ARM Architecture Reference Manual,"
*/

#define _ASMLANGUAGE
#include "vxWorks.h"

	.data
	.globl  FUNC(copyright_wind_river)
	.long   FUNC(copyright_wind_river)

	/* globals */

	.globl	FUNC(cacheArchIntLock)	/* Lock interrupts according to mask */

	.text
	.balign	4

/******************************************************************************/

/* PC-relative-addressable symbols - LDR Rn, =sym was (is?) broken */

L$_cacheArchIntMask:
	.long	FUNC(cacheArchIntMask)

/*******************************************************************************
*
* cacheArchIntLock - locks interrupts according to mask (ARM)
*
* This routine locks interrupts according to the mask specified by the
* BSP, cacheArchIntMask.
*
* NOMANUAL
*
* RETURNS
* The I and F bits from the CPSR as the lock-out key for the interrupt level
* prior to the call. Use to unlock interrupts with a call to intIFUnLock().
*
* SEE ALSO: intIFLock(), intIFUnlock()
*
* void cacheArchIntLock(void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheArchIntLock)

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r1, cpsr		/* Get CPSR */
	AND	r0, r1, #I_BIT | F_BIT	/* Save bits to return in r0 */
	ORR	r2, r1, r2		/* OR in disable bits to CPSR value */
	MSR	cpsr, r2		/* disable interrupts */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

