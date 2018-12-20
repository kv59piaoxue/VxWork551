/* mmu860ALib.s - functions common to all 860-derived MMUs */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01d,21may02,dtr  Use tlbia for tlb invalidate all.
01c,30apr02,dtr  SPR68201 - fix branch to wrong label.
01b,24apr02,dtr  Changing bla to ba for exception jumps.
01a,17apr02,jtp  derived from mmuPpcALib.s
*/

/*
 * This file contains assembly-language functions common to all 860-derived
 * MMUs. In concert with mmuPpcALib.s and mmuPpcLib.c, a complete MMU
 * implementation is present.
 */

/* globals */

	FUNC_EXPORT(mmuPpcTlbie)			/* tlb invalidate entry */

	FUNC_EXPORT(mmuPpcMiApSet)		/* set the MI_AP register */
	FUNC_EXPORT(mmuPpcMdApSet)		/* set the MD_AP register */
	FUNC_EXPORT(mmuPpcMiCtrSet)		/* set the MI_CTR register */
	FUNC_EXPORT(mmuPpcMiCtrGet)		/* get the MI_CTR register */
	FUNC_EXPORT(mmuPpcMdCtrSet)		/* set the MD_CTR register */
	FUNC_EXPORT(mmuPpcMdCtrGet)		/* get the MD_CTR register */
	FUNC_EXPORT(mmuPpcMCasidSet)		/* set the M_CASID register */
	FUNC_EXPORT(mmuPpcTlbInvalidateAll)	/* invalidate all TBL entries */
	FUNC_EXPORT(mmuPpcMdDbcamGet)
	FUNC_EXPORT(mmuPpcMdDbram0Get)
	FUNC_EXPORT(mmuPpcMdDbram1Get)
	FUNC_EXPORT(mmuPpcMiDbcamGet)
	FUNC_EXPORT(mmuPpcMiDbram0Get)
	FUNC_EXPORT(mmuPpcMiDbram1Get)
	FUNC_EXPORT(mmuPpcMiEpnSet)
	FUNC_EXPORT(mmuPpcMiRpnSet)
	FUNC_EXPORT(mmuPpcMdEpnSet)
	FUNC_EXPORT(mmuPpcMdRpnSet)
	FUNC_EXPORT(mmuPpcMTwbSet)
	FUNC_EXPORT(mmuPpcDataTlbMissHandler)	/* data TLB miss handler */
	FUNC_EXPORT(mmuPpcInstTlbMissHandler)	/* instr. TLB miss handler */
	FUNC_EXPORT(mmuPpcDataTlbErrorHandler)	/* data TLB error handler */
	FUNC_EXPORT(mmuPpcDataTlbMissHandlerLongJump)	/* D TLB miss handler */
	FUNC_EXPORT(mmuPpcInstTlbMissHandlerLongJump)	/* I TLB miss handler */
	FUNC_EXPORT(mmuPpcDataTlbErrorHandlerLongJump)	/* D TLB error handler */

	_WRS_TEXT_SEG_START


/******************************************************************************
*
* mmuPpcTlbie - Invalidate the PTE in the TLB
*/

FUNC_BEGIN(mmuPpcTlbie)
	sync
	tlbie 	p0
	sync
	blr		
FUNC_END(mmuPpcTlbie)

/*******************************************************************************
*
* mmuPpcMiApSet - set the MI_AP register value 
*
*/

FUNC_BEGIN(mmuPpcMiApSet)
	mtspr	MI_AP, r3
	blr
FUNC_END(mmuPpcMiApSet)

/*******************************************************************************
*
* mmuPpcMdApSet - set the MD_AP register value 
*
*/

FUNC_BEGIN(mmuPpcMdApSet)
	mtspr	MD_AP, r3
	blr
FUNC_END(mmuPpcMdApSet)

/*******************************************************************************
*
* mmuPpcMiCtrSet - set the MI_CTR register value 
*
*/

FUNC_BEGIN(mmuPpcMiCtrSet)
	mtspr	MI_CTR, r3
	blr
FUNC_END(mmuPpcMiCtrSet)

/*******************************************************************************
*
* mmuPpcMiCtrGet - get the MI_CTR register value 
*
*/

FUNC_BEGIN(mmuPpcMiCtrGet)
	mfspr	r3, MI_CTR
	blr
FUNC_END(mmuPpcMiCtrGet)

/*******************************************************************************
*
* mmuPpcMdCtrSet - set the MD_CTR register value 
*
*/

FUNC_BEGIN(mmuPpcMdCtrSet)
	mtspr	MD_CTR, r3
	blr
FUNC_END(mmuPpcMdCtrSet)

/*******************************************************************************
*
* mmuPpcMdCtrGet - get the MD_CTR register value 
*
*/

FUNC_BEGIN(mmuPpcMdCtrGet)
	mfspr	r3, MD_CTR
	blr
FUNC_END(mmuPpcMdCtrGet)

/*******************************************************************************
*
* mmuPpcMCasidSet - set the M_CASID register value 
*
*/

FUNC_BEGIN(mmuPpcMCasidSet)
	mtspr	M_CASID, r3
	blr
FUNC_END(mmuPpcMCasidSet)

/*******************************************************************************
*
* mmuPpcTlbInvalidateAll - invalidate all tlb 
*
*/

FUNC_BEGIN(mmuPpcTlbInvalidateAll)
	sync
	tlbia
	sync
	blr
FUNC_END(mmuPpcTlbInvalidateAll)

FUNC_BEGIN(mmuPpcMdDbcamGet)
	eieio
	mtspr	MD_DBCAM, r3
	mfspr	r3, MD_DBCAM
	blr
FUNC_END(mmuPpcMdDbcamGet)

FUNC_BEGIN(mmuPpcMdDbram0Get)
	mfspr	r3, MD_DBRAM0
	blr
FUNC_END(mmuPpcMdDbram0Get)

FUNC_BEGIN(mmuPpcMdDbram1Get)
	mfspr	r3, MD_DBRAM1
	blr
FUNC_END(mmuPpcMdDbram1Get)

FUNC_BEGIN(mmuPpcMiDbcamGet)
	eieio
	mtspr	MI_DBCAM, r3
	mfspr	r3, MI_DBCAM
	blr
FUNC_END(mmuPpcMiDbcamGet)

FUNC_BEGIN(mmuPpcMiDbram0Get)
	mfspr	r3, MI_DBRAM0
	blr
FUNC_END(mmuPpcMiDbram0Get)

FUNC_BEGIN(mmuPpcMiDbram1Get)
	mfspr	r3, MI_DBRAM1
	blr
FUNC_END(mmuPpcMiDbram1Get)

FUNC_BEGIN(mmuPpcMiEpnSet)
	mtspr	MI_EPN, r3
	blr
FUNC_END(mmuPpcMiEpnSet)

FUNC_BEGIN(mmuPpcMiRpnSet)
	mtspr	MI_RPN, r3
	blr
FUNC_END(mmuPpcMiRpnSet)

FUNC_BEGIN(mmuPpcMTwbSet)
	mtspr	M_TWB, p0	/* move P0 to M_TWB */
	blr
FUNC_END(mmuPpcMTwbSet)

FUNC_BEGIN(mmuPpcMdEpnSet)
	mtspr	MD_EPN, r3
	blr
FUNC_END(mmuPpcMdEpnSet)

FUNC_BEGIN(mmuPpcMdRpnSet)
	mtspr	MD_RPN, r3
	blr
FUNC_END(mmuPpcMdRpnSet)



/*******************************************************************************
*
* mmuPpcDataTlbMissHandler - Data TLB Miss handler  
*
*/

FUNC_LABEL(mmuPpcDataTlbMissHandlerLongJump)
/* Initial stub does the following :	
 	mtspr M_TW,r18          * save r18 
	mfcr  r18          
	stw   r18,-0x4(r1)	* save condition register on stack 0x4
	mfctr r18
	stw   r18,-0x8(r1)      * save counter register on stack 0x8 
	lis   r18, HI(mmuXXXHandler)
	ori   r18, r18, LO(mmuXXXHandler)
	mtctr r18		* jump to mmu handler *
	bctr
   Note: r18 and cr are restored at the end of this routine 
*/
	lwz	r18, -0x08(r1)
	mtctr	r18
        b mmuPpcDataTlbMissHandlerMain

FUNC_BEGIN(mmuPpcDataTlbMissHandler)
/* jumps to here from exc vector vi branch absolute */ 
	mtspr   M_TW,r18
        mfcr    r18
        stw     r18,-0x04(r1)
	
mmuPpcDataTlbMissHandlerMain:
	mfspr	r18, M_TWB	/* load R1 with the Tablewalk Base pointer */
	lwz	r18, 0(r18)	/* load Level 1 page entry */

	mtspr	MD_TWC, r18	/* save Level 2 Base pointer and */
				/* level 1 attributes */

	rlwinm. r18, r18, 0, 31, 31	/* test Valid bit */
	beq	mmuPpcDataTlbError	/* if entry not valid then exit */

	mfspr	r18, MD_TWC	/* load R1 with level 1 pointer while */
				/* taking into account the page size */
	lwz	r18, 0(r18)	/* load level 2 page entry */

	mtspr	MD_RPN, r18	/* write TLB entry */

	rlwinm. r18, r18, 0, 31, 31	/* test Valid bit */
	beq	mmuPpcDataTlbError	/* if entry not valid then exit */

	lwz	r18, -0x04(r1)
	mtcr	r18
	mfspr	r18, M_TW	/* restore R18 */
	rfi

mmuPpcDataTlbError:
	
	lwz	r18, -0x04(r1)
	mtcr	r18
	mfspr	r18, M_TW	/* restore R18 */
	ba	0x300	/* ba vector 300 */
FUNC_END(mmuPpcDataTlbMissHandler)

/*******************************************************************************
*
* mmuPpcInstTlbMissHandler - Instruction TLB Miss handler  
*
*/

FUNC_LABEL(mmuPpcInstTlbMissHandlerLongJump)
/* Initial stub does the following :	
 	mtspr M_TW,r18          * save r18 
	mfcr  r18          
	stw   r18,-0x4(r1)	* save condition register on stack 0x4
	mfctr r18
	stw   r18,-0x8(r1)      * save counter register on stack 0x8 
	lis   r18, HI(mmuXXXHandler)
	ori   r18, r18, LO(mmuXXXHandler)
	mtctr r18		* jump to mmu handler *
	bctr
   Note: r18 and cr are restored at the end of this mmuXXXHandler 
*/
	lwz	r18, -0x08(r1)
	mtctr	r18
        b mmuPpcInstTlbMissHandlerMain

FUNC_BEGIN(mmuPpcInstTlbMissHandler)
/* jumps to here from exc vector via branch absolute */ 
	mtspr   M_TW,r18
        mfcr    r18
        stw     r18,-0x04(r1)
	
mmuPpcInstTlbMissHandlerMain:
	mfspr	r18, MI_EPN	/* load R1 with instr. miss effective address */
	mtspr	MD_EPN, r18	/* save instr. miss effective addr. in MD_EPN */
	mfspr	r18, M_TWB	/* load R1 with the Tablewalk Base pointer */
	lwz	r18, 0(r18)	/* load Level 1 page entry */

	mtspr	MI_TWC, r18	/* save level 1 attributes */
	mtspr	MD_TWC, r18	/* save Level 2 Base pointer */

	rlwinm. r18, r18, 0, 31, 31	/* test Valid bit */
	beq	mmuPpcInstTlbError	/* if entry not valid then exit */

	mfspr	r18, MD_TWC	/* load R1 with level 1 pointer while */
				/* taking into account the page size */

	lwz	r18, 0(r18)	/* load level 2 page entry */

	mtspr	MI_RPN, r18	/* write TLB entry */

	rlwinm. r18, r18, 0, 31, 31	/* test Valid bit */
	beq	mmuPpcInstTlbError	/* if entry not valid then exit */

	lwz	r18, -0x04(r1)
	mtcr	r18
	mfspr	r18, M_TW	/* restore R1 */
	rfi


mmuPpcInstTlbError:
	
	lwz	r18, -0x04(r1)
	mtcr	r18
	mfspr	r18, M_TW	/* restore R18 */
	ba 0x400	/* ba vector 400 */
FUNC_END(mmuPpcInstTlbMissHandler)

/*******************************************************************************
*
* mmuPpcDataTlbErrorHandler -
*
*/
FUNC_LABEL(mmuPpcDataTlbErrorHandlerLongJump)

/* Initial stub does the following :	
 	mtspr M_TW,r18          * save r18 
	mfcr  r18          
	stw   r18,-0x4(r1)	* save condition register on stack 0x4
	mfctr r18
	stw   r18,-0x8(r1)      * save counter register on stack 0x8 
	lis   r18, HI(mmuXXXHandler)
	ori   r18, r18, LO(mmuXXXHandler)
	mtctr r18		* jump to mmu handler *
	bctr
   Note: r18 and cr are restored at the end of this routine 
*/
	lwz	r18, -0x08(r1)  /* restore counter register */
	mtctr	r18
	b mmuPpcDataTlbErrorHandlerMain
	
FUNC_BEGIN(mmuPpcDataTlbErrorHandler)
/* jumps to here from exc vector vi branch absolute */ 
	mtspr   M_TW,r18
        mfcr    r18
        stw     r18,-0x04(r1)
	
mmuPpcDataTlbErrorHandlerMain:

	mfspr	r18, DSISR
	rlwinm. r18, r18, 0, 1, 1
	bne	exit

	mfspr	r18, DSISR
	rlwinm. r18, r18, 0, 4, 4
	bne	exit

	mfspr	r18, DSISR
	rlwinm. r18, r18, 0, 6, 6
	beq	exit

	stw	r19, -0x08(r1)
	stw	r20, -0x0c(r1)
	stw	r21, -0x10(r1)

	mfspr	r18, M_TWB	/* load R18 with the Tablewalk Base pointer */
	lwz	r18, 0(r18)	/* load Level 1 page entry */

	mtspr	MD_TWC, r18	/* save Level 2 Base pointer and */
				/* level 1 attributes */
	mfspr	r19, MD_TWC	/* load R1 with level 1 pointer while */
				/* taking into account the page size */
	lwz	r19, 0(r19)	/* load level 2 page entry */

	rlwinm.	r20, r19, 20, 0, 1	/* test if PP == 00 OR PP == 01 */
	bge	chk0

	andi.	r20, r19, 0x0400	/* test pp[0] */
	beq	chk2
	b	doDAEp

chk0:
	mfspr	r20, SRR1
	andi.	r20, r20, 0x4000
	beq	chk1

	rlwinm	r20, r18, 28, 27, 31
	mfspr	r21, MD_AP
	rlwnm.	r21, r21, r20, 0, 0
	beq	chk2
	b	doDAEp

chk1:
	rlwinm	r20, r18, 28, 27, 31
	mfspr	r21, MD_AP
	rlwnm.	r21, r21, r20, 1, 1
	beq	chk2
	b	doDAEp

chk2:
	ori	r19, r19, 0x0100
	mfspr	r20, MD_TWC	/* load R1 with level 1 pointer while */
				/* taking into account the page size */
	stw	r19, 0(r20)
	mtspr	MD_RPN, r19	/* write TLB entry */

	lwz	r21, -0x10(r1)
	lwz	r20, -0x0c(r1)
	lwz	r19, -0x08(r1)
	lwz	r18, -0x04(r1)
	mtcr	r18

	mfspr	r18, M_TW	/* restore R18 */
	rfi
	

doDAEp:
	lwz	r21, -0x10(r1)
	lwz	r20, -0x0c(r1)
	lwz	r19, -0x08(r1)
exit :	
	lwz	r18, -0x04(r1)
	mtcr	r18	        /* restore condition register */
	mfspr	r18, M_TW	/* restore R18 */
	
	ba 0x300	/* ba vector300 */
FUNC_END(mmuPpcDataTlbErrorHandler)

