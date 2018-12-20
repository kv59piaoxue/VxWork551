/* mmuALib.s - ARM MMU management assembly routines */

/* Copyright 1996-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01q,17dec02,jb  Adding ARM 926e and ARM 102xE support
01p,17oct01,t_m  convert to FUNC_LABEL:
01o,11oct01,jb   Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01o,03oct01,jpd  clarified some conditional code.
01n,23jul01,scm  change XScale name to conform to coding standards...
01m,11dec00,scm  replace references to SA2 with XScale
01l,06sep00,scm  add sa2 support ...
01k,08jun99,jpd  added support for ARM 740T, ARM720T, ARM920T.
01j,24nov98,jpd  added support for ARM 940T, SA-1500; removed mmuIntLock/Unlock;
		 moved mmuModifyCr and mmuCrGet to mmuALib2.s;
            cdp  added support for generic ARM ARCH3/ARCH4.
01i,04mar98,jpd  tidied comments/doc'n.
01h,31oct97,jpd  removed redundant, conditionaled-out code.
01g,27oct97,kkk  took out "***EOF***" line from end of file.
01f,10oct97,jpd  tidied.
01e,26sep97,jpd  modified branch prediction code for 810.
01d,18sep97,jpd  disabled FIQs in mmuModifyCr(), added mmuIntLock() and 810
		 errata support.
01c,27may97,jpd  added soft copy of MMU CR on 710A. Changed .aligns to .baligns.
01b,18feb97,jpd  comments/documentation reviewed.
01a,25oct96,jpd  written.
*/

/*
DESCRIPTION
This library contains routines to control ARM Ltd.'s MMUs.

N.B.
Although this library contains code written for the ARM810 CPU, at the time
of writing, this code has NOT been tested fully on that CPU.
YOU HAVE BEEN WARNED.

INTERNAL
Some of these routines will be called with FIQs disabled and attempting
to run them through a debugger is unlikely to be required. To keep
these as efficient as possible, they no longer generate stack frames.

SEE ALSO: vmLib
.I "ARM Architecture Reference Manual,"
.I "ARM 710A Data Sheet,"
.I "ARM 810 Data Sheet,"
.I "ARM 740T Data Sheet,"
.I "ARM 926EJ-S Technical Reference Manual,"
.I "ARM 940T Technical Reference Manual,"
.I "ARM 720T Data Sheet,"
.I "ARM 920T Technical Reference Manual,"
.I "ARM 1020E Technical Reference Manual,"
.I "ARM 1022E Technical Reference Manual,"
.I "Digital Semiconductor SA-110 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1100 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1500 Mediaprocessor Data Sheet."
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "arch/arm/mmuArmLib.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

/*!!!!!!!!!!!!!!!!!!!!!!!!!!!!*/

/*
 * Branch Prediction support:
 * There is currently a fault preventing this from being used on the 810.
 */

#undef BPRED_SUPPORT


#ifndef ARMMMU
#error ARMMMU not defined
#endif

#if (ARMMMU == ARMMMU_1020E)
#define ARMMMU_1020E_REV0_MCR_CP15 TRUE
#else
#define ARMMMU_1020E_REV0_MCR_CP15 FALSE
#endif

/*
 * Only the following processors are supported by this library. Others
 * should not be assembling this file, but ensure they get none of this code
 * if they do.
 */

#if ((ARMMMU == ARMMMU_710A)   || (ARMMMU == ARMMMU_720T)   || \
     (ARMMMU == ARMMMU_740T)   || (ARMMMU == ARMMMU_810)    || \
     (ARMMMU == ARMMMU_SA110)  || (ARMMMU == ARMMMU_SA1100) || \
     (ARMMMU == ARMMMU_SA1500) || (ARMMMU == ARMMMU_920T)   || \
     (ARMMMU == ARMMMU_926E)   || (ARMMMU == ARMMMU_940T)   || \
     (ARMMMU == ARMMMU_946E)   || (ARMMMU == ARMMMU_XSCALE) || \
     (ARMMMU == ARMMMU_1020E)  || (ARMMMU == ARMMMU_1022E))

	/* exports */

#if (!ARM_HAS_MPU)
	/* routines present for non-MPU, i.e. full MMU types */

	.globl	FUNC(mmuTtbrGet)		/* Read MMU TTBR */
	.globl	FUNC(mmuTtbrSet)		/* Write MMU TTBR */
	.globl	FUNC(mmuDacrSet)		/* Write MMU DACR */
	.globl	FUNC(mmuTLBIDFlushEntry)	/* Flush I+D TLB entry */
	.globl	FUNC(mmuTLBIDFlushAll)		/* Flush I+D TLBs */
#else
	/* routines present for MPU types */

	.globl	FUNC(mmuPrrSet)		/* set protection region registers */
	.globl	FUNC(mmuPrrGet)		/* get protection region registers */
	.globl	FUNC(mmuCcrSet)		/* set cache control registers */
	.globl	FUNC(mmuCcrGet)		/* get cache control register */
	.globl	FUNC(mmuWbcrSet)	/* set write-buffer control register */
	.globl	FUNC(mmuWbcrGet)	/* get write-buffer control register */
	.globl	FUNC(mmuPrSet)		/* set cache protection registers */
	.globl	FUNC(mmuPrGet)		/* get cache protection register */
#endif /* (!ARM_HAS_MPU) */
	/* routines present for both */

	.globl	FUNC(mmuAEnable)	/* Switch MMU on (only) */
	.globl	FUNC(mmuADisable)	/* Switch MMU off (only) */


	.text
	.balign	4

	/* PC-relative-addressable symbols */

#if (ARMMMU == ARMMMU_710A)

L$_mmuCrValue:
	.long	FUNC(_mmuCrValue)

#endif

#if (!ARM_HAS_MPU)
/* routines for full-MMU types */

/******************************************************************************
*
* mmuTtbrSet - set the Translation Table Base Register (ARM)
*
* This routine sets the Translation Table Base Register of the MMU.
*
* RETURNS: N/A
*
* NOMANUAL
*
*  void mmuTtbrSet
*    (
*    LEVEL_1_DESC *	pTable	/@ pointer to Translation Table @/
*    )
*
* The pointer to the Translation Table must be correctly aligned (to a 16
* kbyte boundary). This is not checked for in this routine as we have no route
* to send back an error code to the ultimate caller.
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuTtbrSet)

	MCR	CP_MMU, 0, r0, c2, c0, 0 /* Write the TTBR in MMU */

#if ARMMMU_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/******************************************************************************
*
* mmuTtbrGet - Get the Translation Table Base Register (ARM)
*
* This routine gets the Translation Table Base Register of the MMU.
*
* RETURNS: N/A
*
* NOMANUAL
*
*  UINT32 mmuTtbrGet
*    (
*    void
*    )
*
* The pointer to the Translation Table must be correctly aligned (to a 16
* kbyte boundary). This is not checked for in this routine as we have no route
* to send back an error code to the ultimate caller.
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuTtbrGet)

	MRC	CP_MMU, 0, r0, c2, c0, 0 /* Write the TTBR in MMU */

#if ARMMMU_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/******************************************************************************
*
* mmuDacrSet - set the Domain Access Control Register (ARM)
*
* This routine sets the Domain Access Control Register of the MMU.
*
* RETURNS: N/A
*
* NOMANUAL
*
*  void mmuDacrSet
*    (
*    UINT32	dacr	/@ value to load into DACR @/
*    )
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuDacrSet)

	MCR	CP_MMU, 0, r0, c3, c0, 0 /* Write DACR in MMU */

#if ARMMMU_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif /* (!ARM_HAS_MPU) */
/*******************************************************************************
*
* mmuAEnable - enable Memory Management Unit (ARM)
*
* This routine turns the MMU on. It assumes that interrupts are locked out.
* It is called internally to enable the MMU after it has been disabled for a
* short period of time to access internal data structs.
*
* NOMANUAL
*
* void mmuAEnable
*		(
*		UINT32 cacheState	/@ desired I, Z, D and W bits @/
*		)
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuAEnable)

	/* Do not use the stack */


#if (ARMMMU == ARMMMU_710A)
	/* On the 710A, the Control Register is write-only, read the soft-copy*/

	LDR	r2, L$_mmuCrValue	/* Get pointer to soft copy */
	LDR	r1, [r2]		/* Load soft-copy */

#else
	MRC	CP_MMU, 0, r1, c1, c0, 0 /* Read control reg into ARM reg 1 */
#endif

	ORR	r1, r1, #MMUCR_M_ENABLE	/* OR in MMU enable bit */
	ORR	r1, r1, r0		/* OR in any I, Z, C and W bits */

#if (ARMMMU == ARMMMU_710A)
	STR	r1, [r2]		/* Store soft-copy */
#endif
	MCR	CP_MMU, 0, r1, c1, c0, 0 /* Write the control register */

#if (ARMMMU == ARMMMU_XSCALE)
	/* assure that CP15 update takes effect */

	MRC	CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
	MOV	r0, r0			 /* wait for it */
	SUB	pc, pc, #4		 /* branch to next instruction */
#endif

	/*
	 * On StrongARM, the next three instructions will be fetched
	 * "flat".  On 710A and 810, the next two instructions will be
	 * fetched "flat".  If this code is called from a piece of code
	 * in an area whose virtual address will not be the same as its
	 * physical address, problems will ensue.  However, it is not
	 * clear what steps we can take to protect against this here.
	 */

#if ARMMMU_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuADisable - disable Memory Management Unit (ARM)
*
* This routine assumes that interrupts are locked out.  It is called internally
* to disable the MMU for a short period of time to access internal data
* structures that may be write-protected.
*
* NOMANUAL
*
* void mmuADisable (void)
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuADisable)

	/* Do not use the stack */


#if (ARMMMU == ARMMMU_710A)
	/* On the 710A, the Control Register is write-only, read the soft-copy*/

	LDR	r2, L$_mmuCrValue	/* Get pointer to soft copy */
	LDR	r0, [r2]		/* Load soft-copy */

#else
	MRC	CP_MMU, 0, r0, c1, c0, 0 /* Read control reg into ARM reg 0 */
#endif

#if ((ARMMMU == ARMMMU_710A)   || (ARMMMU == ARMMMU_720T)   || \
     (ARMMMU == ARMMMU_740T)   || (ARMMMU == ARMMMU_SA110)  || \
     (ARMMMU == ARMMMU_SA1100) || (ARMMMU == ARMMMU_SA1500) || \
     (ARMMMU == ARMMMU_920T)   || (ARMMMU == ARMMMU_926E)   || \
     (ARMMMU == ARMMMU_940T)   || (ARMMMU == ARMMMU_946E)   || \
     (ARMMMU == ARMMMU_XSCALE) || (ARMMMU == ARMMMU_1020E)  || \
     (ARMMMU == ARMMMU_1022E))

	/*
	 * Clear MMU and D-cache (or ID-cache) enable bits. Some MMUs require
	 * the W bit to be left as Should Be One (SBO), some require it to be
	 * cleared.  Some require I-cache to be disabled when MMU is disabled,
	 * some can cope with it left on.
	 */

#if ((ARMMMU == ARMMMU_920T)   || (ARMMMU == ARMMMU_940T)   || \
     (ARMMMU == ARMMMU_926E)   || (ARMMMU == ARMMMU_946E)   || \
     (ARMMMU == ARMMMU_XSCALE) || (ARMMMU == ARMMMU_1020E)  || \
     (ARMMMU == ARMMMU_1022E))
	/* Leave W bit SBO */

	BIC	r0, r0, #(MMUCR_M_ENABLE | MMUCR_C_ENABLE)
#else
	/* Clear W bit */

	BIC	r0, r0, #(MMUCR_M_ENABLE | MMUCR_C_ENABLE | MMUCR_W_ENABLE)
#endif

#if ((ARMMMU == ARMMMU_940T) || (ARMMMU == ARMMMU_946E))
	/* I-cache must also be disabled, as must not be enabled without MMU */

	BIC	r0, r0, #MMUCR_I_ENABLE		/* Clear I-cache enable */
#endif /* (ARMMMU == ARMMMU_940T,946E) */

#if (ARMMMU == ARMMMU_710A)
	STR	r0, [r2]			/* Store soft-copy */
#endif
	MCR	CP_MMU, 0, r0, c1, c0, 0	/* Write the control register */

#if (ARMMMU == ARMMMU_XSCALE)
	/* assure that CP15 update takes effect */

	MRC	CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
	MOV	r0, r0			 /* wait for it */
	SUB	pc, pc, #4		 /* branch to next instruction */
#endif
#endif /* (ARMMMU == ARMMMU_710A,720T,740T,SA*,920T,940T,XSCALE,1020E,1022E) */

#if (ARMMMU == ARMMMU_810)
#ifdef BPRED_SUPPORT
1:
	BIC	r0, r0, #MMUCR_Z_ENABLE	/* Clear branch-prediction enable */
	MCR	CP_MMU, 0, r0, c1, c0, 0 /* Write the control register */

	/*
	 * We must make sure that speculative prefetching has completed (see
	 * errata sheet and chip spec). We do this by causing a branch that is
	 * predicted to be taken, not to be taken.
	 */

	MSR	cpsr_flg, #0x20000000	/* set carry flag */
	BCC	1b			/* branch never taken */

	/*
	 * Branch prediction is now disabled, and speculative prefetching has
	 * completed.
	 *
	 * Clear MMU, cache and W/B enable bits.
	 */

	BIC	r0, r0, #(MMUCR_M_ENABLE | MMUCR_C_ENABLE | MMUCR_W_ENABLE)
	MCR	CP_MMU, 0, r0, c1, c0, 0	/* Write the control register */
#else
	BIC	r0, r0, #(MMUCR_M_ENABLE | MMUCR_C_ENABLE | MMUCR_W_ENABLE)
	MCR	CP_MMU, 0, r0,c1, c0, 0		/* Write the control register */
#endif /* BPRED_SUPPORT */
#endif /* (ARMMMU == ARMMMU_810) */

#if ARMMMU_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif

	/*
	 * On StrongARM, the next three instructions will be fetched
	 * "translated".* On 710A and 810, the next two instructions will
	 * be fetched "translated". On ARM ( CPUs this can be three
	 * instructions.  If this code is called from a piece
	 * of code in an area whose virtual address will not be the same
	 * as its physical address, problems will ensue. However, it is
	 * not clear what steps we can take to protect against this
	 * here.
	 */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#if (ARM_HAS_MPU)
/*******************************************************************************
*
* mmuPrrSet - write the Protection Region Register(s) (ARM)
*
* This routine writes to the Data and Instruction Protection Region Registers
* (just one combined I-D register on 740T).
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuPrrSet
*	(
*	const UINT32 *	pPegs	/@ pointer to array of register values @/
*	)
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuPrrSet)

	/* Set registers(s) with value from R0 */

#if (ARM_THUMB)
	STMFD	sp!, {r4-r7}			/* Save registers */
#else
	STMFD	sp!, {r4-r7, lr}		/* Save registers */
#endif
	MOV	ip, r0				/* get pointer to block */
	LDMIA	ip, {r0-r7}			/* read from block of memory */
#if ((ARMMMU == ARMMMU_940T) || (ARMMMU == ARMMMU_946E))
	MCR	CP_MMU, 0, r0, c6, c0, 0	/* write registers in MMU */
	MCR	CP_MMU, 0, r0, c6, c0, 1	/* for Instruction and Data */
	MCR	CP_MMU, 0, r1, c6, c1, 0	/* for all 8 regions */
	MCR	CP_MMU, 0, r1, c6, c1, 1	/* Make I and D descriptions */
	MCR	CP_MMU, 0, r2, c6, c2, 0	/* identical */
	MCR	CP_MMU, 0, r2, c6, c2, 1
	MCR	CP_MMU, 0, r3, c6, c3, 0
	MCR	CP_MMU, 0, r3, c6, c3, 1
	MCR	CP_MMU, 0, r4, c6, c4, 0
	MCR	CP_MMU, 0, r4, c6, c4, 1
	MCR	CP_MMU, 0, r5, c6, c5, 0
	MCR	CP_MMU, 0, r5, c6, c5, 1
	MCR	CP_MMU, 0, r6, c6, c6, 0
	MCR	CP_MMU, 0, r6, c6, c6, 1
	MCR	CP_MMU, 0, r7, c6, c7, 0
	MCR	CP_MMU, 0, r7, c6, c7, 1
#endif /* (ARMMMU == ARMMMU_940T,946E) */
#if (ARMMMU == ARMMMU_740T)
	MCR	CP_MMU, 0, r0, c6, c0, 0	/* write registers in MMU */
	MCR	CP_MMU, 0, r1, c6, c1, 0	/* for all 8 regions */
	MCR	CP_MMU, 0, r2, c6, c2, 0
	MCR	CP_MMU, 0, r3, c6, c3, 0
	MCR	CP_MMU, 0, r4, c6, c4, 0
	MCR	CP_MMU, 0, r5, c6, c5, 0
	MCR	CP_MMU, 0, r6, c6, c6, 0
	MCR	CP_MMU, 0, r7, c6, c7, 0
#endif /* (ARMMMU == ARMMMU_740T) */
#if (ARM_THUMB)
	LDMFD	sp!, {r4-r7}			/* restore registers and exit */
	BX	lr
#else
	LDMFD	sp!, {r4-r7, pc}		/* restore registers and exit */
#endif

/*******************************************************************************
*
* mmuPrrGet - read the Protection Region Register(s) (ARM)
*
* This routine reads the Data Space Protection Region Registers
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuPrrGet
*	(
*	UINT32 *	pPegs	/@ pointer to array of register values @/
*	)
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuPrrGet)
#if (ARM_THUMB)
	STMFD	sp!, {r4-r7}			/* Save registers */
#else
	STMFD	sp!, {r4-r7, lr}		/* Save registers */
#endif
	MOV	ip, r0				/* get pointer to block */
	MRC	CP_MMU, 0, r0, c6, c0, 0	/* read registers from MMU */
	MRC	CP_MMU, 0, r1, c6, c1, 0	/* for all 8 regions */
	MRC	CP_MMU, 0, r2, c6, c2, 0
	MRC	CP_MMU, 0, r3, c6, c3, 0
	MRC	CP_MMU, 0, r4, c6, c4, 0
	MRC	CP_MMU, 0, r5, c6, c5, 0
	MRC	CP_MMU, 0, r6, c6, c6, 0
	MRC	CP_MMU, 0, r7, c6, c7, 0
	STMIA	ip, {r0-r7}			/* store to block of memory */
#if (ARM_THUMB)
	LDMFD	sp!, {r4-r7}			/* restore registers and exit */
	BX	lr
#else
	LDMFD	sp!, {r4-r7, pc}		/* restore registers and exit */
#endif

/*******************************************************************************
*
* mmuCcrSet - write the Cache Control Registers (ARM)
*
* This routine writes to the Cache Control Registers
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuCcrSet
*	(
*	UINT32	val	/@ value to write to registers @/
*	)
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuCcrSet)

	MCR	CP_MMU, 0, r0, c2, c0, 0	/* Set reg with val from R0 */
#if ((ARMMMU == ARMMMU_940T) || (ARMMMU == ARMMMU_946E))
	MCR	CP_MMU, 0, r0, c2, c0, 1	/* Set reg with val from R0 */
#endif /* (ARMMMU == ARMMMU_940T,946E) */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuCcrGet - read the Cache Control Register (ARM)
*
* This routine reads the Instruction Cache Control Register
*
* RETURNS: the value read
*
* NOMANUAL
*
* UINT32 mmuCcrGet (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuCcrGet)

	MRC	CP_MMU, 0, r0, c2, c0, 0	/* Read val into R0 */
#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuWbcrSet - write the Write Buffer Control Register (ARM)
*
* This routine writes to the Write Buffer Control Register
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuWbcrSet
*	(
*	UINT32	val	/@ value to write to register @/
*	)
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuWbcrSet)

	MCR	CP_MMU, 0, r0, c3, c0, 0	/* Set reg with val from R0 */
#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuWbcrGet - read the Write Buffer Control Register (ARM)
*
* This routine reads the Write Buffer Control Register
*
* RETURNS: the value read
*
* NOMANUAL
*
* UINT32 mmuWbcrGet (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuWbcrGet)

	MRC	CP_MMU, 0, r0, c3, c0, 0	/* Read val into R0 */
#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuPrSet - write the Protection Registers (ARM)
*
* This routine writes to the Protection Registers
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuPrSet
*	(
*	UINT32	val	/@ value to write to register @/
*	)
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuPrSet)

	MCR	CP_MMU, 0, r0, c5, c0, 0	/* Set reg with val from R0 */
#if ((ARMMMU == ARMMMU_940T) || (ARMMMU == ARMMMU_946E))
	MCR	CP_MMU, 0, r0, c5, c0, 1	/* Set reg with val from R0 */
#endif /*(ARMMMU == ARMMMU_940T,946E) */
#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuPrGet - read the Protection Register (ARM)
*
* This routine reads the Instruction space Protection Register
*
* RETURNS: the value read
*
* NOMANUAL
*
* UINT32 mmuPrGet (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuPrGet)

	MRC	CP_MMU, 0, r0, c5, c0, 0	/* Read val into R0 */
#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif /* (ARM_HAS_MPU) */

#if (!ARM_HAS_MPU)
/*******************************************************************************
*
* mmuTLBIDFlushEntry - flush an entry in both I and D TLBs (ARM)
*
* This routine flushes (invalidates) an entry in the instruction and data
* TLBs.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuTLBIDFlushEntry
*	(
*	void *	addr	/@ (virtual) address of entry to flush @/
*	)
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuTLBIDFlushEntry)

#if (ARMMMU == ARMMMU_710A)
	MCR	CP_MMU, 0, r0, c6, c0, 0	/* Flush ID TLB entry */
#endif

#if ((ARMMMU == ARMMMU_810) || (ARMMMU == ARMMMU_720T))
	MCR	CP_MMU, 0, r0, c8, c7, 1	/* Flush ID TLB entry */
#endif

#if ((ARMMMU == ARMMMU_SA110)  || \
     (ARMMMU == ARMMMU_SA1100) || (ARMMMU == ARMMMU_SA1500))
	/* Cannot flush I TLB entry, only all of it */

	MCR	CP_MMU, 0, r0, c8, c5, 0	/* Flush all I TLB */

	MCR	CP_MMU, 0, r0, c8, c6, 1	/* Flush D TLB entry */
#endif

#if ((ARMMMU == ARMMMU_920T)   || (ARMMMU == ARMMMU_XSCALE) || \
     (ARMMMU == ARMMMU_1020E)  || (ARMMMU == ARMMMU_1022E))
	/*
	 * bits [0:9] of VA SBZ, and should be so, as we are called via
	 * vmLib, which will ensure that the address is page-aligned.
	 */

	MCR	CP_MMU, 0, r0, c8, c5, 1	/* Flush I TLB entry */
	MCR	CP_MMU, 0, r0, c8, c6, 1	/* Flush D TLB entry */

#if (ARMMMU == ARMMMU_XSCALE)
	/* assure that CP15 update takes effect */

	MRC	CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
	MOV	r0, r0			 /* wait for it */
	SUB	pc, pc, #4		 /* branch to next instruction */
#endif
#if ARMMMU_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif
#endif /* (ARMMMU == ARMMMU_920T,XSCALE,1020E,1022E) */

#if (ARMMMU == ARMMMU_926E)
        /*
         * On ARM926ES-J, there is a co-proc op to invalidate any TLB entries
         * for a particular address, whichever TLB it is in.
         */
        MCR     CP_MMU, 0, r0, c8, c7, 1        /* Flush I and D TLB entries */
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

/*******************************************************************************
*
* mmuTLBIDFlushAll - flush all entries in both I and D TLBs (ARM)
*
* This routine flushes (invalidates) all entries in the instruction and data
* TLBs.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void mmuTLBIDFlushAll (void)
*
*/

_ARM_FUNCTION_CALLED_FROM_C(mmuTLBIDFlushAll)

#if (ARMMMU == ARMMMU_710A)
	MCR	CP_MMU, 0, r0, c5, c0, 0	/* Flush all of TLB */
#endif

#if ((ARMMMU == ARMMMU_720T)   || (ARMMMU == ARMMMU_810)    || \
     (ARMMMU == ARMMMU_SA110)  || (ARMMMU == ARMMMU_SA1100) || \
     (ARMMMU == ARMMMU_SA1500) || (ARMMMU == ARMMMU_920T)   || \
     (ARMMMU == ARMMMU_926E)   || (ARMMMU == ARMMMU_XSCALE) || \
     (ARMMMU == ARMMMU_1020E)  || (ARMMMU == ARMMMU_1022E))

#if ((ARMMMU == ARMMMU_720T)   || (ARMMMU == ARMMMU_810)    || \
     (ARMMMU == ARMMMU_920T)   || (ARMMMU == ARMMMU_926E)   || \
     (ARMMMU == ARMMMU_XSCALE) || (ARMMMU == ARMMMU_1020E)  || \
     (ARMMMU == ARMMMU_1022E))
	MOV	r0, #0				/* datasheet says data SBZ */
#endif

	MCR	CP_MMU, 0, r0, c8, c7, 0	/* Flush all I+D TLBs */
#endif

#if (ARMMMU == ARMMMU_XSCALE)
	/* assure that CP15 update takes effect */

	MRC	CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
	MOV	r0, r0			 /* wait for it */
	SUB	pc, pc, #4		 /* branch to next instruction */
#endif

#if ARMMMU_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif /* (!ARM_HAS_MPU) */

#endif /* ARMMMU == 710A,720T,740T,810,SA*,920T,926E,940T,946E,XSCALE,1020E,1022E */
