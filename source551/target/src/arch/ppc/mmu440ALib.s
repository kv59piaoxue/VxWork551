/* mmu440ALib.s - functions common to all 440-derived MMUs */

/* Copyright 2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01a,17apr02,jtp  written
*/

/*
 * This file contains assembly-language functions common to all 440-derived
 * MMUs. This may include other 32-bit BookE processors.  More generic
 * common functions are found in mmu400ALib.s and mmuPpcALib.s. In concert
 * with mmuPpcLib.c, a complete MMU implementation is present.
 */

/* globals */

	FUNC_EXPORT(mmuPpcMmucrGet)		/* get mmucr register */
	FUNC_EXPORT(mmuPpcMmucrSet)		/* set mmucr register */
	FUNC_EXPORT(mmuPpcTlbReadEntryWord0)	/* read TLB entry word 0 */
	FUNC_EXPORT(mmuPpcTlbReadEntryWord1)	/* read TLB entry word 1 */
	FUNC_EXPORT(mmuPpcTlbReadEntryWord2)	/* read TLB entry word 2 */
	FUNC_EXPORT(mmuPpcTlbWriteEntryWord0)	/* write TLB entry word 0 */
	FUNC_EXPORT(mmuPpcTlbWriteEntryWord1)	/* write TLB entry word 1 */
	FUNC_EXPORT(mmuPpcTlbWriteEntryWord2)	/* write TLB entry word 2 */

	_WRS_TEXT_SEG_START
	

/*******************************************************************************
*
* mmuPpcMmucrGet - get contents of MMUCR register
*
*/

FUNC_BEGIN(mmuPpcMmucrGet)
	mfspr	p0, MMUCR
	blr
FUNC_END(mmuPpcMmucrGet)

/*******************************************************************************
*
* mmuPpcMmucrSet - set contents of MMUCR register
*
*/

FUNC_BEGIN(mmuPpcMmucrSet)
	mtspr	MMUCR, p0
	blr
FUNC_END(mmuPpcMmucrSet)


/*******************************************************************************
*
* mmuPpcTlbReadEntryWord0 - TLB Read Entry Word 0
*	Read the word 0 part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: u_int mmuPpcTlbReadEntryWord0 (u_int index);
*
* RETURNS: the word 0 part of the tlb entry.
*	   
* NOTE: This function updates the MMUCR register with the TID value of the TLB
* 	entry read.
*
*	If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbReadEntryWord0)
	tlbre	r3, r3, 0
	blr
FUNC_END(mmuPpcTlbReadEntryWord0)

/*******************************************************************************
*
* mmuPpcTlbWriteEntryWord0 - TLB Write Entry Word 0
*	Write the word 0 part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: void mmuPpcTlbWriteEntryWord0 (u_int index, u_int word0);
*
* NOTE: This function updates the TID field with the value of the MMUCR[STID]
*	register.
* 	Ensure that you have set it correctly before calling this function.
*
*	If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbWriteEntryWord0)
	tlbwe	r4, r3, 0
	isync
	blr
FUNC_END(mmuPpcTlbWriteEntryWord0)

/*******************************************************************************
*
* mmuPpcTlbReadEntryWord1 - TLB Read Entry Word 1
*	Read the word 1 part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: u_int mmuPpcTlbReadEntryWord1 (u_int index);
*
* RETURNS: the word 1 part of the tlb entry.
*	   
* NOTE: If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbReadEntryWord1)
	tlbre	r3, r3, 1
	blr
FUNC_END(mmuPpcTlbReadEntryWord1)

/*******************************************************************************
*
* mmuPpcTlbWriteEntryWord1 - TLB Write Entry Word 1
*	Write the word 1 part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: void mmuPpcTlbWriteEntryWord1 (u_int index, u_int word1);
*
* NOTE: If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbWriteEntryWord1)
	tlbwe	r4, r3, 1
	isync
	blr
FUNC_END(mmuPpcTlbWriteEntryWord1)

/*******************************************************************************
*
* mmuPpcTlbReadEntryWord2 - TLB Read Entry Word 2
*	Read the word 2 part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: u_int mmuPpcTlbReadEntryWord2 (u_int index);
*
* RETURNS: the word 2 part of the tlb entry.
*	   
* NOTE: If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbReadEntryWord2)
	tlbre	r3, r3, 2
	blr
FUNC_END(mmuPpcTlbReadEntryWord2)

/*******************************************************************************
*
* mmuPpcTlbWriteEntryWord2 - TLB Write Entry Word 2
*	Write the word 2 part of TLB entry specified by the input index (0..63)
*
* INPUTS: index (0..63) in the lower 6 bits of r3
*
* USAGE: void mmuPpcTlbWriteEntryWord2 (u_int index, u_int word2);
*
* NOTE: If the index is invalid, behaviour is undefined.
*
*/
FUNC_BEGIN(mmuPpcTlbWriteEntryWord2)
	tlbwe	r4, r3, 2
	isync
	blr
FUNC_END(mmuPpcTlbWriteEntryWord2)

