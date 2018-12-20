/* mmu603ALib.s - functions common to all 603-derived MMUs */

/* Copyright 1984-2001 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01a,17apr02,jtp  written based on mmuPpcALib.s
*/

/*
 * This file contains assembly-language functions common to all 603-derived
 * MMUs. This includes 603 and EC603 -- primarily it is the existence
 * of a software tlb miss handler. In concert with mmu600ALib.s,
 * mmuPpcALib.s and mmuPpcLib.c, a complete MMU implementation is
 * present.
 */

/* globals */

	FUNC_EXPORT(mmuPpcInstMissHandler)	/* instrustion miss handler */
	FUNC_EXPORT(mmuPpcDataLoadMissHandler)	/* data load miss handler */
	FUNC_EXPORT(mmuPpcDataStoreMissHandler)  /* data store miss handler */
	FUNC_EXPORT(mmuPpcInstMissHandlerLongJump)	/* instrustion miss handler r 32-bit branch*/
	FUNC_EXPORT(mmuPpcDataLoadMissHandlerLongJump)	/* data load miss handler r 32-bit branch*/
	FUNC_EXPORT(mmuPpcDataStoreMissHandlerLongJump)  /* data store miss handler 32-bit branch*/

	_WRS_TEXT_SEG_START
	

/*******************************************************************************
*
* mmuPpcInstMissHandler - Instruction translation miss exception handler
*
* This routine is the handler for the instruction translation miss exception.
* It is connected to the exception vector 0x1000 by the mmuPpcLibInit()
* function. 
*
* NOTE: During the execution of this handler, the TGPR bit of the MSR is set.
* In this case the GPR0 to GPR3 register are remapped to TGPR0 to TGPR3. The
* contents of GPR0 to GPR3 is unchanged. In this special state the GPR4 to
* GPR31 are unvailable. Attempts to use then will yield undefined results.
* For more information see: " PowerPC 603 RISC Microprocessor User's Manual 
* page 6-12".
*
*/
mmuPpcInstMissHandlerLongJump:
	mtlr    r0

FUNC_BEGIN(mmuPpcInstMissHandler)
	mfspr	r2, HASH1		/* load the first pointer to R2 */

	mfctr	r0			/* save the CTR register value to R0 */

	mfspr	r3, ICMP		/* load the first compare value to R3 */
im0:
	addi	r2, r2, -8		/* adjust the pointer value */
	li	r1, 8			/* load R1 with the nb of PTE by PTEG */

	mtctr	r1			/* move the nb of PTE by PTEG to CTR */
im1:
	lwzu	r1, 8(r2)		/* load to R1 the first word of PTE */
					/* pointed to by R2, with R2 update */
	cmpw	r1,r3			/* see if found the PTE */
	bc	0,2,im1			/* if not processed the next PTE */
	bne	mmuPpcSecHash		/* if not found in the PTEG */
					/* set up the next PTEG or exit */

	lwz	r1, 4(r2)		/* load second part of PTE */

	mtctr	r0			/* restore the CTR value */

	andi.	r3, r1, 8		/* check if guarded page */
	bne	doIAEp			/* if yes, jump */
		
	mfspr	r0, IMISS		/* move the miss address to R0 */

	mfspr	r3, SRR1		/* move the saved cr0 bit to R3 */
	mtcrf	0x80, r3		/* restore CR0 value */

	ori	r1, r1, 0x0100		/* set the reference bit in the PTE */
	mtspr	RPA, r1			/* set the PTE */
        .long   0x7c0007e4		/* tlbli r0	/@ load the itlb */

	stw	r1,4(r2)		/* update page table */

	rfi				/* return from the exception handler */

mmuPpcSecHash:
	andi.	r1, r3, 0x0040
	bne	doIAE
	mfspr	r2,HASH2
	ori	r3,r3,0x0040
	b	im0

doIAEp:
	mfspr	r3,SRR1
	andi.	r2,r3,0xffff
	addis	r2,r2,0x0800
	b	iae1

doIAE:
	mfspr	r3,SRR1
	andi.	r2,r3,0xffff
	addis	r2,r2,0x4000
	mtctr	r0
iae1:
	mtspr	SRR1,r2

	mtcrf	0x80,r3

	mfmsr	r0
	xoris	r0,r0,0x0002
	mtmsr	r0

	ba	0x400			/*  ba	vector400 */
FUNC_END(mmuPpcInstMissHandler)
	

/********************************************************************************
* mmuPpcDataLoadMissHandler - Data load translation miss execption handler
*
* This routine is the handler for the data load translation miss exception.
* It is connected to the exception vector 0x1100 by the mmuPpcLibInit()
* function. 
*
* NOTE: During the execution of this handler, the TGPR bit of the MSR is set.
* In this case the GPR0 to GPR3 register are remapped to TGPR0 to TGPR3. The
* contents of GPR0 to GPR3 is unchanged. In this specail state the GPR4 to
* GPR31 are unvailable. Attempts to use then will yield undefined results.
* For more information see: " PowerPC 603 RISC Microprocessor User's Manual 
* page 6-12".
*
*/

mmuPpcDataLoadMissHandlerLongJump:
	mtlr    r0
FUNC_BEGIN(mmuPpcDataLoadMissHandler)
	mfspr	r2,HASH1

	mfctr	r0
	mfspr	r3,DCMP
dm0:
	addi	r2,r2,-8
	li	r1,8

	mtctr	r1
dm1:
	lwzu	r1,8(r2)
	cmpw	r1,r3
	bc	0,2,dm1				/* bdnzf	eq,dm1 */
	bne	mmuPpcDataSecHash

	lwz	r1,4(r2)

	mtctr	r0

	mfspr	r0,DMISS
	mfspr	r3,SRR1
	mtcrf	0x80,r3

	ori	r1,r1,0x0100
	mtspr	RPA,r1
	stw	r1,4(r2)

	.long   0x7c0007a4			/* tlbld	r0 */

	rfi

mmuPpcDataSecHash:
	andi.	r1,r3,0x0040
	bne	doDAE
	mfspr	r2,HASH2
	ori	r3,r3,0x0040
	b	dm0
FUNC_END(mmuPpcDataLoadMissHandler)

/*******************************************************************************
*
* mmuPpcDataLoadMissHandler - Data store translation miss execption handler
*
* This routine is the handler for the data store translation miss exception.
* It is connected to the exception vector 0x1200 by the mmuPpcLibInit()
* function. 
*
* NOTE: During the execution of this handler, the TGPR bit of the MSR is set.
* In this case the GPR0 to GPR3 register are remapped to TGPR0 to TGPR3. The
* contents of GPR0 to GPR3 is unchanged. In this specail state the GPR4 to
* GPR31 are unvailable. Attempts to use then will yield undefined results.
* For more information see: " PowerPC 603 RISC Microprocessor User's Manual 
* page 6-12".
*
*/
mmuPpcDataStoreMissHandlerLongJump:
	mtlr    r0
	
FUNC_BEGIN(mmuPpcDataStoreMissHandler)
	mfspr	r2,HASH1

	mfctr	r0
	mfspr	r3,DCMP

ceq0:
	addi	r2,r2,-8
	li	r1,8

	mtctr	r1
ceq1:
	lwzu	r1,8(r2)
	cmpw	r1,r3
	bc	0,2,ceq1			/* bdnzf	eq,ceq1 */
	bne	mmuPpcCEq0SecHash

	lwz	r1,4(r2)

	mtctr	r0

	andi.	r3,r1,0x80
	beq	cEq0ChkProt
ceq2:
	mfspr	r0,DMISS
	mfspr	r3,SRR1
	mtcrf	0x80,r3
	mtspr	RPA,r1
	.long   0x7c0007a4			/* tlbld	r0 */

	rfi

mmuPpcCEq0SecHash:
	andi.	r1,r3,0x0040
	bne	doDAE
	mfspr	r2,HASH2
	ori	r3,r3,0x0040
	b	ceq0

cEq0ChkProt:
	rlwinm.	r3,r1,30,0,1
	bge	chk0
	andi.	r3,r1,1
	bc	13,2,chk2
	b	doDAEp
chk0:
	mfspr	r3,SRR1
	andi.	r3,r3,0x4000
	bc	13,2,chk1
	mfspr	r3,DMISS
	mfsrin	r3,r3
	andi.	r3,r3,4
	bc	13,2,chk2
	b	doDAEp

chk1:	mfspr	r3,DMISS
	mfsrin	r3,r3
	andi.	r3,r3,2
	bc	13,2,chk2
	b	doDAEp

chk2:	ori	r1,r1,0x180
	stw	r1,4(r2)
	b	ceq2
	


doDAE:
	mfspr	r3,SRR1
	rlwinm	r1,r3,9,6,6
	addis	r1,r1,0x4000
	b	dae1

doDAEp:
	mfspr	r3,SRR1
	rlwinm	r1,r3,9,6,6
	addis	r1,r1,0x0800

dae1:
	mtctr	r0
	andi.	r2,r3,0xffff
	mtspr	SRR1,r2
	mtspr	DSISR,r2
	mfspr	r1,DMISS
	rlwinm	r2,r2,0,31,31
	bne	dae2
	xoris	r1,r1,0x07
dae2:
	mtspr	DAR,r1

	mfmsr	r0
	xoris	r0,r0,0x2
	mtcrf	0x80,r3
	mtmsr	r0

	.long	0x48000302		/* ba vector300 */
FUNC_END(mmuPpcDataStoreMissHandler)
