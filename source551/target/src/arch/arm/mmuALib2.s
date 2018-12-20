/* mmuALib2.s - ARM MMU management assembly routines */

/* Copyright 1996-1999 Wind River Systems, Inc. */

/*
modification history
--------------------
01f,17oct01,t_m  convert to FUNC_LABEL:
01e,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01d,23jul01,scm  change XScale name to conform to coding standards...
01c,19dec00,scm  add XScale support
01b,20jan99,cdp  removed support for old ARM libraries.
01a,04dec98,jpd  written, using code from mmuALib.s version 01j.
*/

/*
DESCRIPTION
This library contains routines to control ARM family MMUs. This file
will be assembled once only to produce one object file, containing two
different variants of some small MMU handling routines, that are called
by both the cache code and the MMU code, so do not have unique names
like the routines in mmuALib.s.

INTERNAL
To keep these routines as efficient as possible, they do not generate
stack frames.

SEE ALSO: vmLib
.I "ARM Architecture Reference Manual,"
.I "ARM 710A Data Sheet,"
.I "ARM 810 Data Sheet,"
.I "ARM 740T Data Sheet,"
.I "ARM 940T Data Sheet,"
.I "Digital Semiconductor SA-110 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1100 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1500 Mediaprocessor Data Sheet."
*/

#define _ASMLANGUAGE
#include "vxWorks.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

/*
 * When compiling for the new (generic) architectures, ARMMMU will not
 * be defined, but we actually want the 710a version of MMU_INIT_VALUE
 * (it is only required for the soft-copy versions of the routines, which
 * are only used on ARM 710a.
 */

#ifndef ARMMMU
#define ARMMMU ARMMMU_710A
#endif

#include "arch/arm/mmuArmLib.h"

	/* exports */

	.globl	FUNC(mmuCrGet)		/* Fn Ptr to read MMU Control Reg */
	.globl	FUNC(mmuModifyCr)		/* Fn Ptr to modify MMU Control Reg */
	.globl	FUNC(_mmuCrValue)		/* The MMU CR soft copy */
	.globl	FUNC(mmuHardCrGet)		/* get MMU CR from h/w */
	.globl	FUNC(mmuSoftCrGet)		/* get MMU CR from soft copy */
	.globl	FUNC(mmuModifyHardCr)	/* Modify Cr using h/w */
	.globl	FUNC(mmuModifySoftCr)	/* Modify Cr using soft-copy */

	.data
	.balign	4

FUNC_LABEL(_mmuCrValue)		/* The soft-copy */
 
	/*
	 * Initialise the soft copy to the value which should be
	 * written in to the MMU CR during initialisation in
	 * romInit.s/sysALib.s.
	 */

	.long	MMU_INIT_VALUE

	/* pre-initialise function pointers to non-soft-copy versions */

FUNC_LABEL(mmuCrGet)
	.long	FUNC(mmuHardCrGet)

FUNC_LABEL(mmuModifyCr)
	.long	FUNC(mmuModifyHardCr)

	.text
	.balign 4

	/* PC-relative-addressable symbols - LDR Rn,=sym was (is?) broken */
 
L$_mmuCrValue:
	.long	FUNC(_mmuCrValue)

/*******************************************************************************
*
* mmuHardCrGet - read the MMU Control Register (ARM)
*
* This routine reads the MMU Control Register on MMU hardware where this is
* possible.
*
* RETURNS: the value of the MMU Control Register
*
* NOMANUAL
*
* UINT32 mmuHardCrGet (void)
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuHardCrGet)

	/*
	 * Read coprocessor register 1 (the Control Register) from the
	 * MMU Coprocessor into ARM register 0
	 */

	MRC	CP_MMU, 0, r0, c1, c0, 0

	/* return (with value read in r0) */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuSoftCrGet - read the soft copy of the MMU Control Register (ARM)
*
* This routine reads the soft copy of the MMU Control Register on ARM
* 710a MMUs, where the hardware register is not readable.
*
* RETURNS: the value of the MMU Control Register
*
* NOMANUAL
*
* UINT32 mmuSoftCrGet (void)
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuSoftCrGet)

	/* On the 710A, the Control Register is write-only, read the soft-copy*/

	LDR	r0, L$_mmuCrValue	/* Get pointer to soft copy */
	LDR	r0, [r0]		/* Load soft-copy */

	/* return (with value read in r0) */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuModifyHardCr - modify the MMU Control Register (ARM)
*
* This routine modifies the MMU Control Register.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuModifyHardCr
*     (
*     UINT32	value,	/@ value to set @/
*     UINT32	mask	/@ bits in value to pay attention to @/
*     )
*
* If this routine is used to change the MMU Enable bit, on StrongARM, the
* next three instructions will still be fetched "flat" or "translated" as
* the case may be. On 710A and 810, it will be two instructions.
* However, since the virtual mapping should actually be the same as the
* physical address, this should not be a problem and no steps are taken to
* deal with it here.
* Moreover, no check is made in this routine to disallow invalid settings,
* e.g. enabling the D-cache and write-buffer without the MMU.
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuModifyHardCr)

	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, #I_BIT | F_BIT	/* Disable all interrupts */
	MSR	cpsr, r2

	MRC	CP_MMU, 0, r2, c1, c0, 0 /* Read control reg into ARM reg 2 */

	BIC	r2, r2, r1		/* Clear bits of interest using mask */

	AND	r0, r0, r1		/* Mask any incorrectly given bits */

	ORR	r2, r2, r0		/* OR in the bits provided */

	MCR	CP_MMU, 0, r2, c1, c0, 0 /* Write the control register */

#if (ARMMMU == ARMMMU_XSCALE)
        /* assure that CP15 update takes effect */
        MRC     CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r0, r0                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */
#endif

	MSR	cpsr, r3		/* Restore interrupt state */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuModifySoftCr - modify the MMU Control Register including soft-copy (ARM)
*
* This routine modifies the MMU Control Register including and using
* the soft-copy on ARM 710a MMUs, where the MMU Control Register hardware
* is not readable.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuModifySoftCr
*     (
*     UINT32	value,	/@ value to set @/
*     UINT32	mask	/@ bits in value to pay attention to @/
*     )
*
* If this routine is used to change the MMU Enable bit, on StrongARM, the
* next three instructions will still be fetched "flat" or "translated" as
* the case may be. On 710A and 810, it will be two instructions.
* However, since the virtual mapping should actually be the same as the
* physical address, this should not be a problem and no steps are taken to
* deal with it here.
* Moreover, no check is made in this routine to disallow invalid settings,
* e.g. enabling the D-cache and write-buffer without the MMU.
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuModifySoftCr)

	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, #I_BIT | F_BIT	/* Disable all interrupts */
	MSR	cpsr, r2

	/* On the 710A, the Control Register is write-only, read the soft-copy*/

	LDR	ip, L$_mmuCrValue	/* Get pointer to soft copy */
	LDR	r2, [ip]		/* Load soft-copy */

	BIC	r2, r2, r1		/* Clear bits of interest using mask */

	AND	r0, r0, r1		/* Mask any incorrectly given bits */

	ORR	r2, r2, r0		/* OR in the bits provided */

	STR	r2, [ip]		/* Store soft-copy */

	MCR	CP_MMU, 0, r2, c1, c0, 0 /* Write the control register */

#if (ARMMMU == ARMMMU_XSCALE)
        /* assure that CP15 update takes effect */
        MRC     CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r0, r0                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */
#endif

	MSR	cpsr, r3		/* Restore interrupt state */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif
