/* mmu600ALib.s - functions common to all 60x-derived MMUs */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01f,02dec02,pch  SPR 83067: unclosed comment prevents isync after mtsrin
01e,27may02,kab  Extra BATs only avaliable to PPC604
01d,24may02,pch  Exclude extra-BAT support from 603 to fix build error
01c,21may02,pcs  Implement code review changes for extra bat support.
01b,28apr02,pcs  Add extra BAT support.
01a,17apr02,jtp  written based on mmuPpcALib.s
*/

/*
 * This file contains assembly-language functions common to all 60x-derived
 * MMUs. This includes 601, 603, EC603, 604, 82XX, and 74XX.  In concert
 * with mmuPpcALib.s and mmuPpcLib.c, a complete MMU implementation is
 * present.
 */

/* globals */

	FUNC_EXPORT(mmuPpcTlbie)			/* tlb invalidate entry */

	FUNC_EXPORT(mmuPpcBatInit)		/* initialize BAT registers */
#if     (CPU == PPC604)
	FUNC_EXPORT(mmuPpcExtraBatInit)		/* initialize BAT registers */
	FUNC_EXPORT(mmuPpcExtraBatEnableMPC7x5)	/* initialize Extra BAT registers */
	FUNC_EXPORT(mmuPpcExtraBatEnableMPC74x5) /* initialize Extra BAT registers */
	FUNC_EXPORT(mmuPpcExtendedBlockEnableMPC74x5) /* initialize Extended Block Size */
#endif /* CPU==PPC604 */
	FUNC_EXPORT(mmuPpcTlbInvalidateAll)         /* invalidate TLB entries */
	FUNC_EXPORT(mmuPpcSrSet)		/* set SR register value */
	FUNC_EXPORT(mmuPpcSrGet)		/* get SR register value */
	FUNC_EXPORT(mmuPpcSdr1Set)		/* Set SDR1 register value */
	FUNC_EXPORT(mmuPpcSdr1Get)		/* Get SDR1 register value */

	_WRS_TEXT_SEG_START
	

/******************************************************************************
*
* mmuPpcTlbie - Invalidate the PTE in the TLB
*/

FUNC_BEGIN(mmuPpcTlbie)
	sync
	tlbie 	p0
	sync
#if	((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604))
#ifdef	_GREEN_TOOL
	.long	0x7c00046c		/* tlbsync */
#else
	tlbsync
#endif
	sync
#endif	/* ((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)) */
	blr		
FUNC_END(mmuPpcTlbie)

/*******************************************************************************
*
* mmuPpcBatInit - initialize the MMU Block Address Translation (BAT) registers 
*
* This routine initialises the Block Address Translation (BAT) registers. The
* BAT registers values are saved in the sysBatDec[] table defined in the 
* sysLib.c file located in the BSP. A pointer to this table is passed has
* input argument. 
* This routine is called by the mmuPpcLibInit() function located in 
* /src/arch/ppc/mmuPpcLib.c file.
* Note: This fn. doesn't invalidate the TLB entries. 
*       Previously it was being done by this fn. Now it doesn't.
*       So mmpPpcLibInit() should explictly call mmuPpcTlbInvalidateAll() to
*       invalidate all the TLB entries.
* RETURNS: N/A

* void mmuPpcBatInit
*     (
*     UINT32 * pBatDesc		/@ &sysBatDesc[0]  @/
*     )

*/

FUNC_BEGIN(mmuPpcBatInit)

	/* on entry, p0 points to head of list of BAT values */
	
        /* initialize the BAT registers (SPRs 528 - 543) */
        lwz     p2,0(p0)
        lwz     p3,4(p0)
        mtspr	IBAT0L,p3			/* SPR 529 (IBAT0L) */
        mtspr	IBAT0U,p2			/* SPR 528 (IBAT0U) */
        isync

        lwz     p2,8(p0)
        lwz     p3,12(p0)
        mtspr	IBAT1L,p3			/* SPR 531 (IBAT1L) */
        mtspr	IBAT1U,p2			/* SPR 530 (IBAT1U) */
        isync

        lwz     p2,16(p0)
        lwz     p3,20(p0)
        mtspr	IBAT2L,p3			/* SPR 533 (IBAT2L) */
        mtspr	IBAT2U,p2			/* SPR 532 (IBAT2U) */
        isync

        lwz     p2,24(p0)
        lwz     p3,28(p0)
        mtspr	IBAT3L,p3			/* SPR 535 (IBAT3L) */
        mtspr	IBAT3U,p2			/* SPR 534 (IBAT3U) */
        isync

#if	((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604))

        lwz     p2,32(p0)
        lwz     p3,36(p0)
        mtspr	DBAT0L,p3			/* SPR 537 (DBAT0L) */
        mtspr	DBAT0U,p2			/* SPR 536 (DBAT0U) */
        isync

        lwz     p2,40(p0)
        lwz     p3,44(p0)
        mtspr	DBAT1L,p3			/* SPR 539 (DBAT1L) */
        mtspr	DBAT1U,p2			/* SPR 538 (DBAT1U) */
        isync

        lwz     p2,48(p0)
        lwz     p3,52(p0)
        mtspr	DBAT2L,p3			/* SPR 541 (DBAT2L) */
        mtspr	DBAT2U,p2			/* SPR 540 (DBAT2U) */
        isync

        lwz     p2,56(p0)
        lwz     p3,60(p0)
        mtspr	DBAT3L,p3			/* SPR 543 (DBAT3L) */
        mtspr	DBAT3U,p2			/* SPR 542 (DBAT3U) */
        isync


#endif	/* (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)) */

	blr				/* return to caller */
FUNC_END(mmuPpcBatInit)

/******************************************************************************
*
* mmuPpcSrSet - Set the value of a Segment Register (SR)
*
* This funstion set the value of the an Segment Register(SR). The segment
* register number is handles by <srNb> and the value by <value>.
* 
* RETURNS: N/A

* void mmuPpcSrSet
*     (
*     UINT srNb,			/@ segment register number to set @/
*     UINT value			/@ value to place in the register @/
*     )

*/
	
FUNC_BEGIN(mmuPpcSrSet)
	/*
	 * The segment register number should be placed in the MSB of
	 * the register
	 */
	rlwinm	p0, p0, 28, 0, 3	/* shift the register number	*/
	isync				/* instruction SYNCHronization	*/
	mtsrin	p1, p0			/* set the register value	*/
	isync				/* instruction SYNCHronisation	*/
	blr
FUNC_END(mmuPpcSrSet)

/******************************************************************************
*
* mmuPpcSrGet - Get the value of a Segment Register (SR)
*
* This routine returns the value handled by a Segment Register. The
* segment register number is handled by <srNb>.
*
* RETURNS: the Segment Register (SR) value.

* UINT mmuPpcSrGet
*     (
*     UINT srNb			/@ Segment Register number to get the value @/
*     )

*/
	
FUNC_BEGIN(mmuPpcSrGet)
	/*
	 * The segment register number should be placed in the MSB of
	 * the register
	 */
	rlwinm	p0, p0, 28, 0, 3	/* shft the register number */
	mfsrin	p0, p0			/* get the register value */
	blr
FUNC_END(mmuPpcSrGet)


/******************************************************************************
*
* mmuPpcSdr1Set - Set the SDR1 register
*
* This routine set the SDR1 register value. The value to set is handled by
* the <sdr1Value> input argument.
*
* Note: This function MUST Not be called if the Data and/or Instruction MMU 
* are enabled. The results are undefined. See: "PowerPc Mircoprocessor Family:
* The Programming Environments page 2-40 * note Nb 5."
*
* RETURNS: N/A

* void mmuPpcSdr1Set
*     (
*     UINT	sdr1Value		/@ value to set in the SDR1 register @/
*/

FUNC_BEGIN(mmuPpcSdr1Set)
	sync				/* SYNChronization */
	mtspr	SDR1, p0		/* set the SDR1 with the P0 value */
	sync				/* SYNChronization */
	blr
FUNC_END(mmuPpcSdr1Set)

/******************************************************************************
*
* mmuPpcSdr1Get - Get the SDR1 register value
* 
* This routine returns the value handled by the SDR1 register.
*
* RETURNS: N/A

* UINT mmuPpcSdr1Get (void)

*/

FUNC_BEGIN(mmuPpcSdr1Get)
	mfspr	p0, SDR1		/* move the SDR1 value to P0 */
	blr
FUNC_END(mmuPpcSdr1Get)

#if	(CPU == PPC604)
/*******************************************************************************
*
* mmuPpcExtraBatInit - initialize the MMU Block Address Translation (BAT) 
*                       registers I/D BAT's 4-7.
*
* This routine initialises the Block Address Translation (BAT) registers. The
* BAT registers values are saved in the sysBatDec[] table defined in the
* sysLib.c file located in the BSP. A pointer to this table is passed is
* input argument. 
*  Note: The pointer corresponds to the start of the additional bat entries.
* This routine is called by the mmuPpcLibInit() function located in
* /src/arch/ppc/mmuPpcLib.c file.
*
* Note: This fn. doesn't invalidate the TLB entries. 
*       So mmpPpcLibInit() should explictly call mmuPpcTlbInvalidateAll() to
*       invalidate all the TLB entries.
* RETURNS: N/A

* void mmuPpcExtraBatInit
*     (
*     UINT32 * pBatDesc              /@ &sysBatDec[16] @/
*     )

*/

FUNC_BEGIN(mmuPpcExtraBatInit)

        /* on entry, p0 points to head of list of BAT values */

        /* initialize the BAT registers (SPRs 560 - 575) */


        lwz     p2,0(p0)
        lwz     p3,4(p0)
        mtspr	IBAT4L,p3			/* SPR 561 (IBAT4L) */
        mtspr	IBAT4U,p2			/* SPR 560 (IBAT4U) */
        isync

        lwz     p2,8(p0)
        lwz     p3,12(p0)
        mtspr	IBAT5L,p3			/* SPR 563 (IBAT5L) */
        mtspr	IBAT5U,p2			/* SPR 562 (IBAT5U) */
        isync

        lwz     p2,16(p0)
        lwz     p3,20(p0)
        mtspr	IBAT6L,p3			/* SPR 565 (IBAT6L) */
        mtspr	IBAT6U,p2			/* SPR 564 (IBAT6U) */
        isync

        lwz     p2,24(p0)
        lwz     p3,28(p0)
        mtspr	IBAT7L,p3                       /* SPR 567 (IBAT7L) */
        mtspr	IBAT7U,p2			/* SPR 566 (IBAT7U) */
        isync

        lwz     p2,32(p0)
        lwz     p3,36(p0)
        mtspr	DBAT4L,p3			/* SPR 569 (DBAT4L) */
        mtspr	DBAT4U,p2			/* SPR 568 (DBAT4U) */
        isync

        lwz     p2,40(p0)
        lwz     p3,44(p0)
        mtspr	DBAT5L,p3			/* SPR 571 (DBAT5L) */
        mtspr	DBAT5U,p2			/* SPR 570 (DBAT5U) */
        isync

        lwz     p2,48(p0)
        lwz     p3,52(p0)
        mtspr	DBAT6L,p3			/* SPR 573 (DBAT6L) */
        mtspr	DBAT6U,p2			/* SPR 572 (DBAT6U) */
        isync

        lwz     p2,56(p0)
        lwz     p3,60(p0)
        mtspr	DBAT7L,p3			/* SPR 575 (DBAT7L) */
        mtspr	DBAT7U,p2			/* SPR 574 (DBAT7U) */
        isync

        blr

FUNC_END(mmuPpcExtraBatInit)
#endif /* PPC604 */

/*******************************************************************************
*
* mmuPpcTlbInvalidateAll - invalidate all the TLB entries.
*
* This routine invalidates all the TLB entries.
*
* RETURNS: N/A
* void mmuPpcTlbInvalidateAll
*     (
*     void
*     )
*/

FUNC_BEGIN(mmuPpcTlbInvalidateAll)

#if     (CPU == PPC604)
        li      p1,64                   /*  604/750/74xx */
#else
        li      p1,32                 
#endif
        xor     p0,p0,p0                /* p0 = 0    */
        mtctr   p1                      /* CTR = 32/64  */

        isync                           /* context sync req'd before tlbie   */

vvxpbi1: tlbie   p0
        sync                            /* sync instr req'd after tlbie      */
        addi    p0,p0,0x1000            /* increment bits 15/16 - 19         */
        bdnz    vvxpbi1                  /* decrement CTR, branch if CTR != 0 */

        blr
FUNC_END(mmuPpcTlbInvalidateAll)

#if	(CPU == PPC604)
/*******************************************************************************
*
* mmuPpcExtraBatEnableMPC7x5 - Enable the EXTRA BAT's on the MPC755
*
* This routine enables the EXTRA BAT's on the MPC755
*
* RETURNS: N/A
* void mmuPpcExtraBatEnableMPC7x5
*     (
*     void
*     )
*/

FUNC_BEGIN(mmuPpcExtraBatEnableMPC7x5)
        mfspr   r3,HID2                          /* Get HID2 */
        oris    r3,r3,_PPC_HID2_HIGH_BAT_EN_U    /* Set HIGH_BAT_EN */
        mtspr   HID2,r3
        sync
        isync
        blr
FUNC_END(mmuPpcExtraBatEnableMPC7x5)

/*******************************************************************************
*
* mmuPpcExtraBatEnableMPC74x5 - Enable the EXTRA BAT's on the MPC7455
*
* This routine enables the EXTRA BAT's on the MPC7455
*
* RETURNS: N/A
* void mmuPpcExtraBatEnableMPC74x5
*     (
*     void
*     )
*/

FUNC_BEGIN(mmuPpcExtraBatEnableMPC74x5)
        mfspr   r3,HID0                          /* Get HID0 */
        oris    r3,r3,_PPC_HID0_HIGH_BAT_EN_U    /* Set HIGH_BAT_EN */
        mtspr   HID0,r3
        sync
        isync
        blr
FUNC_END(mmuPpcExtraBatEnableMPC74x5)

/*******************************************************************************
*
* mmuPpcExtendedBlockEnableMPC74x5 - Enable the Extended Block size on the 
*                                    MPC7455
* This routine enables the extended Block size on the MPC7455
*
* RETURNS: N/A
* void mmuPpcExtendedBlockEnableMPC74x5
*     (
*     void
*     )
*/

FUNC_BEGIN(mmuPpcExtendedBlockEnableMPC74x5)
        mfspr   r3,HID0                  /* Get HID0 */
        ori     r3,r3,_PPC_HID0_XBSEN    /* Set EBSEN */
        mtspr   HID0,r3
        sync
        isync
        blr
FUNC_END(mmuPpcExtendedBlockEnableMPC74x5)
#endif	/* CPU == PPC604 */
