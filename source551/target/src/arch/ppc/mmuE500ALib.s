/* mmuE500ALib.s -  */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01b,07jan03,dtr  Adding functions for static TLB accesses.
01a,13dec02,dtr  Moving defines to ppc85xx.h.
*/

/*
 */
#define _ASMLANGUAGE

#include "vxWorks.h"
#if (CPU==PPC85XX)
# include <arch/ppc/ppc85xx.h>
# include <arch/ppc/mmuE500Lib.h>
#endif /* CPU */

/* defines */


#if	(CPU == PPC85XX)

# define TLB_V_BIT	0	/* valid bit is at bit 22 of word 0 */
# define TLB_N_WORDS	3	/* three TLB words, 0, 1, and 2 */
# define L2_ENTRY_SIZE	4	/* power of 2 => 16 bytes */

#else	/* CPU */

# error "CPU value not supported"

#endif	/* CPU */

/*
 * stack frame used for saving and restoring registers during the miss calls
 */

#define TLB_FRAME_SIZE	   0x18
#define R18_OFFSET	   (TLB_FRAME_SIZE - 0x04)
#define CR_OFFSET	   (TLB_FRAME_SIZE - 0x08)
#define R19_OFFSET	   (TLB_FRAME_SIZE - 0x0C)
#define R20_OFFSET	   (TLB_FRAME_SIZE - 0x10)
#define R21_OFFSET	   (TLB_FRAME_SIZE - 0x14)
#define R22_OFFSET	   (TLB_FRAME_SIZE - 0x18)


/* externals */

	DATA_IMPORT(mmuAddrMapArray)

/* globals */

	FUNC_EXPORT(mmuPpcPidSet)		/* set the PID register */
	FUNC_EXPORT(mmuPpcPidGet)		/* get the PID register */
	FUNC_EXPORT(mmuE500TlbDynamicInvalidate) /* Invalidate L1 dynamic TLB1 entries */
	FUNC_EXPORT(mmuE500TlbStaticInvalidate)  /* Invalidate L2 static (CAM) TLB1 entries */
	FUNC_EXPORT(mmuPpcE500Tlbie)		/* get ESR */
	FUNC_EXPORT(mmuPpcInstTlbMissHandler)	/* instr tlb miss handler */
	FUNC_EXPORT(mmuPpcDataTlbMissHandler)	/* data tlb miss handler */
	FUNC_EXPORT(mmuPpcTlbWriteEntryWord0)	/* write TLB entry word 0 */
	FUNC_EXPORT(mmuPpcTlbWriteEntryWord1)	/* write TLB entry word 1 */
	FUNC_EXPORT(mmuPpcTlbWriteEntryWord2)	/* write TLB entry word 2 */
	FUNC_EXPORT(mmuPpcTlbWriteExecute)	/* execute MAS registers and sync tlb */
	

	_WRS_TEXT_SEG_START

/*******************************************************************************
*
* mmuPpcTlbWriteEntryWord0 - TLB Write Entry Word 0
*
*/
FUNC_BEGIN(mmuPpcTlbWriteEntryWord0)
	mtspr MAS1,r3
	isync
	blr
FUNC_END(mmuPpcTlbWriteEntryWord0)

/*******************************************************************************
*
* mmuPpcTlbWriteEntryWord1 - TLB Write Entry Word 1
*
*/
FUNC_BEGIN(mmuPpcTlbWriteEntryWord1)
	mtspr MAS2,r3
	isync
	blr
FUNC_END(mmuPpcTlbWriteEntryWord1)

/*******************************************************************************
*
* mmuPpcTlbWriteEntryWord0 - TLB Write Entry Word 0
*
*/
FUNC_BEGIN(mmuPpcTlbWriteEntryWord2)
	mtspr MAS3,r3
	isync
	blr
FUNC_END(mmuPpcTlbWriteEntryWord2)

/*******************************************************************************
*
* mmuPpcTlbWriteExecute - Execute TLB Update 
*
*/
FUNC_BEGIN(mmuPpcTlbWriteExecute)
	mtspr MAS0,r3
	isync
	tlbwe
	tlbsync
	blr
FUNC_END(mmuPpcTlbWriteExecute)

/*******************************************************************************
*
* mmuE500TlbDynamicInvalidate - Invalidate TLB1 dynamic entries 
*
*/

FUNC_BEGIN(mmuE500TlbDynamicInvalidate)
	lis p0, HIADJ( _PPC_MMUCSR0_DL1MMU_FI | \
		       _PPC_MMUCSR0_IL1MMU_FI | \
		       _PPC_MMUCSR0_L2TLB0_FI)	
	addi p0, p0, LO ( _PPC_MMUCSR0_DL1MMU_FI | \
		          _PPC_MMUCSR0_IL1MMU_FI | \
			  _PPC_MMUCSR0_L2TLB0_FI)
	mtspr MMUCSR0, p0
	isync
	tlbsync
	blr
FUNC_END(mmuE500TlbDynamicInvalidate)

/*******************************************************************************
*
* mmuE500TlbStaticInvalidate - Invalidate TLB1 static entries 
*
*/

FUNC_BEGIN(mmuE500TlbStaticInvalidate)
	lis p0, HIADJ(_PPC_MMUCSR0_L2TLB1_FI)	
	addi p0, p0, LO (_PPC_MMUCSR0_L2TLB1_FI)
	mtspr MMUCSR0, p0
	isync
	tlbsync
	blr
FUNC_END(mmuE500TlbStaticInvalidate)
/*******************************************************************************
*
* mmuPpcPidSet - set the PID register
*
*/
FUNC_BEGIN(mmuPpcPidSet)
	mtspr	PID, r3
	blr
FUNC_END(mmuPpcPidSet)

/*******************************************************************************
*
* mmuPpcPidGet - get the PID register
*
*/
FUNC_BEGIN(mmuPpcPidGet)
	mfspr	r3, PID
	blr
FUNC_END(mmuPpcPidGet)


/*******************************************************************************
*
* mmuPpcE500Tlbie - Invalidate tlb entry for the specified effective addr
*
* INPUTS: effectiveAddr (EA) in r4
*
* USAGE: int mmuPpcE500Tlbie (MMU_TRANS_TBL *pTransTbl,void * effAddr);
*
* RETURNS: None.
*
*/
FUNC_BEGIN(mmuPpcE500Tlbie)
        sync
        tlbivax r0,r4
        tlbsync
        blr             
FUNC_END(mmuPpcE500Tlbie)


/*******************************************************************************
*
* mmuPpcInstTlbMissHandler - Instruction TLB Miss handler for PPC4XX
*
*/
FUNC_BEGIN(mmuPpcInstTlbMissHandler)

	addi	sp, sp, -TLB_FRAME_SIZE
	stw	r18, R18_OFFSET(r1)	/* save R18 */
	mfcr	r18	

	stw	r18, CR_OFFSET(r1)  /* save CR (because we modify it later) */
	stw	r19, R19_OFFSET(r1)	/* save R19 */
	stw	r20, R20_OFFSET(r1)	/* save R20 */
	stw	r21, R21_OFFSET(r1)	/* save R21 */
	stw	r22, R22_OFFSET(r1)	/* save R22 */

	mfsrr0	r18  	 	/* load R18 with instr. miss eff. address */
	mfspr	r19, PID 	/* read current PID register */
	
	lis	r20, HI(mmuAddrMapArray)	/* read addr of mmu map table */
	ori	r20, r20, LO(mmuAddrMapArray) 

	li	r21, 2		/* size of each addr map entry in power of 2 */

	slw	r19, r19, r21
	add	r20, r20, r19	/* index into mmu map table */
	lwz	r20, 0(r20)	/* read pointer to MMU_TRANS_TBL struct */
	lwz	r20, 0(r20)	/* read pointer to Level 1 table */

	mr	r19, r18	/* get instr miss addr */
	rlwinm	r19, r19, 10, 22, 31	/* get index into level 1 table */
	
	slw	r19, r19, r21	/* multiply index by size of L1 entry */
	add	r20, r20, r19	/* index into L1 table */
	lwz	r20, 0(r20)	/* load Level 1 page entry */

	rlwinm. r19, r20, 0, 31, 31	/* test Valid bit */
	beq	mmuPpcInstTlbError	/* if entry not valid then exit */

	rlwinm	r20, r20, 0, 0, 29	/* mask of lower 2 bits */
					/* r20 now has the base of l2 table */

	mr	r19, r18	/* get instr miss addr */
	rlwinm	r19, r19, 20, 22, 31 /* get index into level 2 table */
	li	r21, L2_ENTRY_SIZE	/* each L2 entry is 2^size words long */
	slw	r19, r19, r21	/* multiply index by size of L2 entry */
	add	r18, r20, r19	/* index into L2 table */

	lwz	r20, 0(r18)	/* word 0 of tlb entry */
	lwz 	r21, 4(r18)	/* word 1 of tlb entry */
	lwz 	r22, 8(r18)	/* word 2 of tlb entry */

	rlwinm. r19, r20, 0, TLB_V_BIT, TLB_V_BIT 	/* test Valid bit */

	beq	mmuPpcInstTlbError	/* if entry not valid then exit */

        sync
        mtspr   MAS1, r20
        mtspr   MAS2, r21
        mtspr   MAS3, r22
        tlbwe
        isync

	lwz	r22, R22_OFFSET(r1)	/* load R22 */
	lwz	r21, R21_OFFSET(r1)	/* load R21 */
	lwz	r20, R20_OFFSET(r1)	/* load R20 */
	lwz	r19, R19_OFFSET(r1)	/* load R19 */
	lwz	r18, CR_OFFSET(r1)  /* load CR  */

	mtcr	r18
	lwz	r18, R18_OFFSET(r1)	/* load R18 */
	addi	sp, sp, TLB_FRAME_SIZE

	rfi

mmuPpcInstTlbError:


	lwz	r22, R22_OFFSET(r1)	/* load R22 */
	lwz	r21, R21_OFFSET(r1)	/* load R21 */
	lwz	r20, R20_OFFSET(r1)	/* load R20 */
	lwz	r19, R19_OFFSET(r1)	/* load R19 */
	lwz	r18, CR_OFFSET(r1)  /* load CR  */

	mtcr	r18
	lwz	r18, R18_OFFSET(r1)	/* load R18 */
	addi	sp, sp, TLB_FRAME_SIZE

        .long   0x48000402      /* ba vector 400 (instruction access
				 * exception)
				 */
FUNC_END(mmuPpcInstTlbMissHandler)

/*******************************************************************************
*
* mmuPpcDataTlbMissHandler - Data TLB Miss handler for PPC4XX
*
*/

FUNC_BEGIN(mmuPpcDataTlbMissHandler)
	addi	sp, sp, -TLB_FRAME_SIZE
	stw	r18, R18_OFFSET(r1)	/* save R18 */
	mfcr	r18	

	stw	r18, CR_OFFSET(r1)  /* save CR (because we modify it later) */
	stw	r19, R19_OFFSET(r1)	/* save R19 */
	stw	r20, R20_OFFSET(r1)	/* save R20 */
	stw	r21, R21_OFFSET(r1)	/* save R21 */
	stw	r22, R22_OFFSET(r1)	/* save R22 */

	mfspr	r18, DEAR       /* load R18 with data miss effective address */
	mfspr	r19, PID 	/* read current PID register */
	
	lis	r20, HI(mmuAddrMapArray)	/* read addr of mmu map table */
	ori	r20, r20, LO(mmuAddrMapArray) 

	li	r21, 2		/* size of each addr map entry in power of 2 */

	slw	r19, r19, r21	
	add	r20, r20, r19	/* index into mmu map table */
	lwz	r20, 0(r20)	/* read pointer to MMU_TRANS_TBL struct */
	lwz	r20, 0(r20)	/* read pointer to Level 1 table */

	mr	r19, r18	/* get data miss addr */
	rlwinm	r19, r19, 10, 22, 31	/* get index into level 1 table */
	slw	r19, r19, r21	/* multiply index by size of L1 entry */
	add	r20, r20, r19	/* index into L1 table */
	lwz	r20, 0(r20)	/* load Level 1 page entry */

	rlwinm. r19, r20, 0, 31, 31	/* test Valid bit */
	beq	mmuPpcDataTlbError	/* if entry not valid then exit */

	rlwinm	r20, r20, 0, 0, 29	/* mask of lower 2 bits */
					/* r20 now has the base of l2 table */

	mr	r19, r18	/* get data miss addr */
	rlwinm	r19, r19, 20, 22, 31 /* get index into level 2 table */
	li	r21, L2_ENTRY_SIZE	/* each L2 entry is 2^size words long */
	slw	r19, r19, r21	/* multiply index by size of L2 entry */
	add	r18, r20, r19	/* index into L2 table */

	lwz	r20, 0(r18)	/* word 0 of tlb entry */
	lwz 	r21, 4(r18)	/* word 1 of tlb entry */
	lwz 	r22, 8(r18)	/* word 2 of tlb entry */

	rlwinm. r19, r20, 0, TLB_V_BIT, TLB_V_BIT	/* test Valid bit */
	beq	mmuPpcDataTlbError	/* if entry not valid then exit */

        sync
        mtspr   MAS1, r20
        mtspr   MAS2, r21
        mtspr   MAS3, r22
        tlbwe
        isync

	lwz	r22, R22_OFFSET(r1)	/* load R22 */
	lwz	r21, R21_OFFSET(r1)	/* load R21 */
	lwz	r20, R20_OFFSET(r1)	/* load R20 */
	lwz	r19, R19_OFFSET(r1)	/* load R19 */
	lwz	r18, CR_OFFSET(r1)  /* load CR  */

	mtcr	r18
	lwz	r18, R18_OFFSET(r1)	/* load R18 */
	addi	sp, sp, TLB_FRAME_SIZE

	rfi

mmuPpcDataTlbError:


	lwz	r22, R22_OFFSET(r1)	/* load R22 */
	lwz	r21, R21_OFFSET(r1)	/* load R21 */
	lwz	r20, R20_OFFSET(r1)	/* load R20 */
	lwz	r19, R19_OFFSET(r1)	/* load R19 */
	lwz	r18, CR_OFFSET(r1)  /* load CR  */

	mtcr	r18
	lwz	r18, R18_OFFSET(r1)	/* load R18 */
	addi	sp, sp, TLB_FRAME_SIZE

        .long   0x48000302      /* ba vector 300 (data access
				 * exception)
				 */
FUNC_END(mmuPpcDataTlbMissHandler)
