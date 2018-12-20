/* mmu405ALib.s - functions common to all 405-derived MMUs */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01a,17apr02,jtp  Split from mmuPpcALib.s
*/

/* globals */

	FUNC_EXPORT(mmuPpcTlbInvalidateAll)	/* invalidate all TBL entries */
	FUNC_EXPORT(mmuPpcTlbReadEntryHi)	/* read HI word of TLB entry */
	FUNC_EXPORT(mmuPpcTlbReadEntryLo)	/* read LO word of TLB entry */
	FUNC_EXPORT(mmuPpcTlbWriteEntryHi)	/* write HI word of TLB entry */
	FUNC_EXPORT(mmuPpcTlbWriteEntryLo)	/* write LO word of TLB entry */
	FUNC_EXPORT(mmuPpcZprSet)		/* set ZPR */
	FUNC_EXPORT(mmuPpcZprGet)		/* get ZPR */

	_WRS_TEXT_SEG_START
	

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


/*******************************************************************************
*
* mmuPpcTlbReadEntryHi - TLB Read Entry Hi
*	Read the hi part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: u_int mmuPpcTlbReadEntryHi (u_int index);
*
* RETURNS: the hi part of the tlb entry.
*	   
* NOTE: This function updates the PID register with the TID value of the TLB
* 	entry read. So either ensure that you only read a TLB entry 
*	corresponding to the currently active address space or restore the PID
*	register later.
*
*	If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbReadEntryHi)
	tlbrehi	r3, r3
	blr
FUNC_END(mmuPpcTlbReadEntryHi)

/*******************************************************************************
*
* mmuPpcTlbReadEntryLo - TLB Read Entry Lo
*	Read the Lo part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: u_int mmuPpcTlbReadEntryLo (u_int index);
*
* RETURNS: the Lo part of the tlb entry.
*	   
* NOTES: If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbReadEntryLo)
	tlbrelo	r3, r3
	blr
FUNC_END(mmuPpcTlbReadEntryLo)

/*******************************************************************************
*
* mmuPpcTlbWriteEntryHi - TLB Write Entry Hi
*	Write the hi part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: void mmuPpcTlbWriteEntryHi (u_int index, u_int tlbhi);
*
* NOTE: This function updates the TID field with the value of the PID register.
* 	So either ensure that you only write a TLB entry 
*	corresponding to the currently active address space or set/restore the 
*	PID register later.
*
*	If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbWriteEntryHi)
	tlbwehi	r4, r3
	isync
	blr
FUNC_END(mmuPpcTlbWriteEntryHi)

/*******************************************************************************
*
* mmuPpcTlbWriteEntryLo - tlb write entry lo
*	write the lo part of tlb entry specified by the input index (0..63)
*
* inputs: index (0..63) in the lower 6 bits of r3
*
* usage: void mmuPpcTlbWriteEntryLo (u_int index, u_int tlblo);
*
* notes: if the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbWriteEntryLo)
	tlbwelo	r4, r3
	isync
	blr
FUNC_END(mmuPpcTlbWriteEntryLo)

/*******************************************************************************
*
* mmuPpcZprSet - Set Zone protection register
*
* inputs: value to write to the ZPR register
*
* usage: void mmuPpcZprSet (u_int zprVal);
*
*/
FUNC_BEGIN(mmuPpcZprSet)
	mtspr	ZPR, r3
	blr
FUNC_END(mmuPpcZprSet)

/*******************************************************************************
*
* mmuPpcZprGet - Get Zone protection register
*
* returns: value of ZPR
*
* usage: u_int mmuPpcZprGet ();
*
*/
FUNC_BEGIN(mmuPpcZprGet)
        mfspr   r3, ZPR
	blr
FUNC_END(mmuPpcZprGet)

