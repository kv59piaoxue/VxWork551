/* mmu400ALib.s - functions common to all IBM 4xx MMUs */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01b,20may02,pch  SPR 75927: adjust stack pointer in TLB miss handlers
01a,17apr02,jtp  derived from mmuPpcALib.s
*/

/*
 * This file contains assembly-language functions common to all 4xx-derived
 * MMUs. This includes 405, 405F, and 440. Additional implementation
 * will be found in family-specific files (e.g. mmu405ALib.s). Along
 * with mmuPpcALib.s and mmuPpcLib.c, a complete MMU implementation is
 * present.
 *
 * Note: The PPC440 updates the MMUCR[STID] field on reading TLB
 * word 0, and uses it on writing TLB word 0. The 405, on the other
 * hand, uses the PID register to tag the address space id on writing
 * the hi TLB word (word 0). So long as we read then write the TLB word
 * 0 in the miss handlers, similar code will automatically work for
 * both PPC405 and PPC440.
 */

#if (CPU==PPC440)
# include <arch/ppc/mmu440Lib.h>
#endif /* CPU */

/* defines */

/*
 * The miss handler for PPC405/405F and 440 are very similar, so they
 * have been parameterized with preprocessor variables so as to be
 * conditionally assembled for each CPU type.
 *
 * configuration parameters for the common 400 TLB Miss handler code
 */

#if	((CPU == PPC405) || (CPU == PPC405F))

# define TLB_V_BIT	25	/* valid bit is at bit 25 of word 0 */
# define TLB_N_WORDS	2	/* two TLB words, hi (0) and lo (1) */
# define L2_ENTRY_SIZE	3	/* power of 2 => 8 bytes */
# undef TLB_MIN_SUPPORT		/* use TLB indexes from 0 to max */
# undef CACHE_STATE_VAR

#elif	((CPU == PPC440))

# define TLB_V_BIT	22	/* valid bit is at bit 22 of word 0 */
# define TLB_W_BIT	20	/* writethru bit is at bit 19 of word 2 */
# define TLB_I_BIT	21	/* cache inhibit bit is at bit 20 of word 2 */
# define TLB_N_WORDS	3	/* three TLB words, 0, 1, and 2 */
# define L2_ENTRY_SIZE	4	/* power of 2 => 16 bytes */
# define TLB_MIN_SUPPORT	/* use TLB indexes from mmuPpcTlbMin to max */
# define CACHE_STATE_VAR cache440Enabled	/* if TRUE cache is enabled */

#else	/* CPU */

# error "CPU value not supported"

#endif	/* CPU */

/*
 * stack frame used for saving and restoring registers during the miss calls
 */

#define R18_OFFSET	(TLB_FRAME_SIZE - 0x04)
#ifdef DONT_USE_SPRG4_7			/* use stack to save registers */
# define CR_OFFSET	(TLB_FRAME_SIZE - 0x08)
# define R19_OFFSET	(TLB_FRAME_SIZE - 0x0C)
# define R20_OFFSET	(TLB_FRAME_SIZE - 0x10)
# define R21_OFFSET	(TLB_FRAME_SIZE - 0x14)
# if     (TLB_N_WORDS == 3)
#  define R22_OFFSET	(TLB_FRAME_SIZE - 0x18)
#  define TLB_FRAME_SIZE	0x18
# else	/* TLB_N_WORDS == 3 */
#  define TLB_FRAME_SIZE	0x14
# endif	/* TLB_N_WORDS == 3 */
#else
# if     (TLB_N_WORDS == 3)
#  define R22_OFFSET	(TLB_FRAME_SIZE - 0x08)
#  define TLB_FRAME_SIZE	0x08
# else	/* TLB_N_WORDS == 3 */
#  define TLB_FRAME_SIZE	0x04
# endif	/* TLB_N_WORDS == 3 */
#endif /* DONT_USE_SPRG4_7 */

/* externals */

	DATA_IMPORT(mmuPpcTlbNext)
#ifdef TLB_MIN_SUPPORT
	DATA_IMPORT(mmuPpcTlbMin)
#endif /* TLB_MIN_SUPPORT */
#ifdef CACHE_STATE_VAR
	DATA_IMPORT(CACHE_STATE_VAR)
#endif /* TLB_MIN_SUPPORT */
	DATA_IMPORT(mmuAddrMapArray)

#ifdef DEBUG_MISS_HANDLER
	DATA_IMPORT(mmuPpcITlbMisses)
	DATA_IMPORT(mmuPpcDTlbMisses)
	DATA_IMPORT(mmuPpcITlbErrors)
	DATA_IMPORT(mmuPpcDTlbErrors)
	DATA_IMPORT(mmuPpcITlbMissArray)
	DATA_IMPORT(mmuPpcDTlbMissArray)
#endif /* DEBUG_MISS_HANDLER */

/* globals */

	FUNC_EXPORT(mmuPpcPidSet)		/* set the PID register */
	FUNC_EXPORT(mmuPpcPidGet)		/* get the PID register */
	FUNC_EXPORT(mmuPpcTlbSearch)		/* search TLB for EA */

	FUNC_EXPORT(mmuPpcEsrGet)		/* get ESR */
	FUNC_EXPORT(mmuPpcMsrGet)		/* get MSR */
	FUNC_EXPORT(mmuPpcInstTlbMissHandler)	/* instr tlb miss handler */
	FUNC_EXPORT(mmuPpcDataTlbMissHandler)	/* data tlb miss handler */


	_WRS_TEXT_SEG_START


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
* mmuPpcTlbSearch - TLB search indexed
*
*	The TLB is search for a valid entry which translates EA and PID.
*	Note this just does the search; different processors expect
*	other registers -- PID or MMUCR, for example -- to be set up
*	as a precondition to calling this function.
*
* INPUTS: effectiveAddr (EA) in r3
*
* USAGE: int mmuPpcTlbSearch (void * effAddr);
*
* RETURNS: index of  valid TLB entry if found. The lower 6 bits of the index
*	   value specify the index of the TLB entry found.
*	   returns -1 if no valid TID entry matching EA and PID is found.
*
*/
FUNC_BEGIN(mmuPpcTlbSearch)
	tlbsx.	r3, 0, r3 
	bne	tlbe_notfound
	blr		/* index is in r3 */

tlbe_notfound:
	li	r3, -1
	blr
FUNC_END(mmuPpcTlbSearch)


/*******************************************************************************
*
* mmuPpcEsrGet - Get Exception Syndrome register
*
* returns: value of ESR
*
* usage: u_int mmuPpcEsrGet ();
*
*/
FUNC_BEGIN(mmuPpcEsrGet)
	mfspr	r3, ESR
	blr
FUNC_END(mmuPpcEsrGet)

/*******************************************************************************
*
* mmuPpcMsrGet - Get Machine Status Register
*
* returns: value of MSR
*
* usage: u_int mmuPpcMsrGet ();
*
*/
FUNC_BEGIN(mmuPpcMsrGet)
	mfmsr	r3
	blr
FUNC_END(mmuPpcMsrGet)


/*******************************************************************************
*
* mmuPpcInstTlbMissHandler - Instruction TLB Miss handler for PPC4XX
*
* If the define DONT_USE_SPRG4_7 is not defined, then the miss handler uses
* SPRG 4 - 7 to save registers it uses.
*
* Note: mmu4??LibInit() installs this handler by plugging in a 'ba
* mmuPpcInstTlbMissHandler' instruction at the miss vector address. As a
* result, none of the standard excEnt()/excExit() processing has been
* done.  This routine cannot be branched to if >32MB from the vector
* page.  Also note that the stack is used for saving at least registers
* R18 and (for PPC440) R22.
*
* for SPR 75927: adjust the stack pointer at entry & exit instead of using
* negative offsets.
*/
FUNC_BEGIN(mmuPpcInstTlbMissHandler)

	addi	sp, sp, -TLB_FRAME_SIZE
	stw	r18, R18_OFFSET(r1)	/* save R18 */
	mfcr	r18	
#ifdef DONT_USE_SPRG4_7         /* use stack to save registers */
	stw	r18, CR_OFFSET(r1)  /* save CR (because we modify it later) */
	stw	r19, R19_OFFSET(r1)	/* save R19 */
	stw	r20, R20_OFFSET(r1)	/* save R20 */
	stw	r21, R21_OFFSET(r1)	/* save R21 */
#else                           /* use SPRG4-7 to save registers */
# ifdef SPRG7_W
        mtspr   SPRG4_W, r18      /* SPRG4 = CR */
        mtspr   SPRG5_W, r19      /* SPRG5 = R19 */
        mtspr   SPRG6_W, r20      /* SPRG6 = R20 */
        mtspr   SPRG7_W, r21      /* SPRG7 = R21 */
# else
        mtspr   SPRG4, r18      /* SPRG4 = CR */
        mtspr   SPRG5, r19      /* SPRG5 = R19 */
        mtspr   SPRG6, r20      /* SPRG6 = R20 */
        mtspr   SPRG7, r21      /* SPRG7 = R21 */
# endif
#endif
#if     (TLB_N_WORDS == 3)
	stw	r22, R22_OFFSET(r1)	/* save R22 */
#endif	/* TLB_N_WORDS == 3 */

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

#if	(TLB_N_WORDS == 3)
	lwz 	r22, 8(r18)	/* word 2 of tlb entry */
# if	defined(CACHE_STATE_VAR)
	lis 	r20, HI(CACHE_STATE_VAR)
	ori	r20, r20, LO(CACHE_STATE_VAR)
	lwz	r20, 0(r20)	/* read value of cache state variable */
	cmpwi	r20, 0		/* compare with zero (FALSE) */
	bne	0f		/* caching allowed, skip ahead */

	/* caching not allowed, turn off writethru, turn on inhibit */
	rlwinm  r22, r22, 0, TLB_W_BIT+1, TLB_W_BIT-1
	lis	r20, HI(MMU_STATE_CACHEABLE_NOT)
	ori	r20, r20, LO(MMU_STATE_CACHEABLE_NOT)
	or	r22, r22, r20
0:
#endif /* defined(CACHE_STATE_VAR) */
#endif	/* TLB_N_WORDS == 3 */
	lwz	r20, 0(r18)	/* word 0 of tlb entry */
	lwz 	r21, 4(r18)	/* word 1 of tlb entry */

	rlwinm. r19, r20, 0, TLB_V_BIT, TLB_V_BIT	/* test Valid bit */

	beq	mmuPpcInstTlbError	/* if entry not valid then exit */

#ifdef DEBUG_MISS_HANDLER
	lis 	r19, HI(mmuPpcITlbMisses)
	ori	r19, r19, LO(mmuPpcITlbMisses)
	lwz	r18, 0(r19)	/* read value of tlb miss counter */
	addi	r18, r18, 1	/* increment tlb replacement counter */
	stw	r18, 0(r19)	/* write back to memory */

	subi	r18, r18, 1	/* array is zero-based */
	rlwinm	r18, r18, 0, 24, 31 /* miss count modulo 256 */
	li	r19, 2		/* multiply by sizeof pointer */
	slw	r18, r18, r19
	lis 	r19, HI(mmuPpcITlbMissArray)	/* load miss array address */
	ori	r19, r19, LO(mmuPpcITlbMissArray)
	add	r19, r19, r18	/* index into miss array table */
	stw	r20, 0(r19)	/* write word0 to miss array entry */
#endif /* DEBUG_MISS_HANDLER */

	lis 	r19, HI(mmuPpcTlbNext)	/* get index of tlb entry to */
	ori	r19, r19, LO(mmuPpcTlbNext) /* replace */

	lwz	r18, 0(r19)	/* read value of tlb replacement counter */

	tlbwe	r20, r18, 0	/*  write word 0 entry */
	tlbwe	r21, r18, 1	/*  write word 1 entry */
#if	(TLB_N_WORDS == 3)
	tlbwe	r22, r18, 2	/*  write word 2 entry */
#endif	/* TLB_N_WORDS == 3 */

	addi	r18, r18, 1	/* increment tlb replacement counter */
	rlwinm	r18, r18, 0, 26, 31 /* mask off higher 26 bits */

#ifdef	TLB_MIN_SUPPORT
	/* bump up the replacement counter to the lowest dynamic tlb index */

	lis 	r20, HI(mmuPpcTlbMin)
	ori	r20, r20, LO(mmuPpcTlbMin)
	lwz	r20, 0(r20)	/* read value of mmuPpcTlbMin */
	subf.	r21, r20, r18	/* r21 <- next tlb - mmuPpcTlbMin */
	bge	0f		/* if not too low skip the next instruction */
	mr	r18, r20	/* use mmuPpcTlbMin instead */

0:
#endif	/* TLB_MIN_SUPPORT */

	stw	r18, 0(r19)	/* write back to memory */

#if     (TLB_N_WORDS == 3)
	lwz	r22, R22_OFFSET(r1)	/* load R22 */
#endif	/* TLB_N_WORDS == 3 */
#ifdef DONT_USE_SPRG4_7         /* restore registers from stack */
	lwz	r21, R21_OFFSET(r1)	/* load R21 */
	lwz	r20, R20_OFFSET(r1)	/* load R20 */
	lwz	r19, R19_OFFSET(r1)	/* load R19 */
	lwz	r18, CR_OFFSET(r1)  /* load CR  */
#else                           /* restore registers from SPRG4-7 */
# if SPRG7_R
        mfspr   r21, SPRG7_R      /* R21 = SPRG7 */
        mfspr   r20, SPRG6_R      /* R20 = SPRG6 */
        mfspr   r19, SPRG5_R      /* R19 = SPRG5 */
        mfspr   r18, SPRG4_R      /* CR  = SPRG4 */
# else
        mfspr   r21, SPRG7      /* R21 = SPRG7 */
        mfspr   r20, SPRG6      /* R20 = SPRG6 */
        mfspr   r19, SPRG5      /* R19 = SPRG5 */
        mfspr   r18, SPRG4      /* CR  = SPRG4 */
# endif
#endif
	mtcr	r18
	lwz	r18, R18_OFFSET(r1)	/* load R18 */
	addi	sp, sp, TLB_FRAME_SIZE

	rfi

mmuPpcInstTlbError:

#ifdef DEBUG_MISS_HANDLER
	lis 	r19, HI(mmuPpcITlbErrors)
	ori	r19, r19, LO(mmuPpcITlbErrors)
	lwz	r18, 0(r19)	/* read value of tlb error counter */
	addi	r18, r18, 1	/* increment tlb replacement counter */
	stw	r18, 0(r19)	/* write back to memory */
#endif /* DEBUG_MISS_HANDLER */

#if     (TLB_N_WORDS == 3)
	lwz	r22, R22_OFFSET(r1)	/* load R22 */
#endif	/* TLB_N_WORDS == 3 */
#ifdef DONT_USE_SPRG4_7         /* restore registers from stack */
	lwz	r21, R21_OFFSET(r1)	/* load R21 */
	lwz	r20, R20_OFFSET(r1)	/* load R20 */
	lwz	r19, R19_OFFSET(r1)	/* load R19 */
	lwz	r18, CR_OFFSET(r1)  /* load CR  */
#else                           /* restore registers from SPRG4-7 */
# if SPRG7_R
        mfspr   r21, SPRG7_R      /* R21 = SPRG7 */
        mfspr   r20, SPRG6_R      /* R20 = SPRG6 */
        mfspr   r19, SPRG5_R      /* R19 = SPRG5 */
        mfspr   r18, SPRG4_R      /* CR  = SPRG4 */
# else
        mfspr   r21, SPRG7      /* R21 = SPRG7 */
        mfspr   r20, SPRG6      /* R20 = SPRG6 */
        mfspr   r19, SPRG5      /* R19 = SPRG5 */
        mfspr   r18, SPRG4      /* CR  = SPRG4 */
# endif
#endif
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
* If the define DONT_USE_SPRG4_7 is not defined, then the miss handler uses
* SPRG 4 - 7 to save most of the registers it uses.
*
* Note: mmu4??LibInit() installs this handler by plugging in a 'ba
* mmuPpcDataTlbMissHandler' instruction at the miss vector address. As a
* result, none of the standard excEnt()/excExit() processing has been
* done.  This routine cannot be branched to if >32MB from the vector
* page.  Also note that the stack is used for saving at least registers
* R18 and (for PPC440) R22.
*
* for SPR 75927: adjust the stack pointer at entry & exit instead of using
* negative offsets.
*/

FUNC_BEGIN(mmuPpcDataTlbMissHandler)
	addi	sp, sp, -TLB_FRAME_SIZE
	stw	r18, R18_OFFSET(r1)	/* save R18 */
	mfcr	r18	
#ifdef DONT_USE_SPRG4_7		/* use stack to save registers */
	stw	r18, CR_OFFSET(r1)  /* save CR (because we modify it later) */
	stw	r19, R19_OFFSET(r1)	/* save R19 */
	stw	r20, R20_OFFSET(r1)	/* save R20 */
	stw	r21, R21_OFFSET(r1)	/* save R21 */
#else				/* use SPRG4-7 to save registers */
# ifdef SPRG7_W
        mtspr   SPRG4_W, r18      /* SPRG4 = CR */
        mtspr   SPRG5_W, r19      /* SPRG5 = R19 */
        mtspr   SPRG6_W, r20      /* SPRG6 = R20 */
        mtspr   SPRG7_W, r21      /* SPRG7 = R21 */
# else
        mtspr   SPRG4, r18      /* SPRG4 = CR */
        mtspr   SPRG5, r19      /* SPRG5 = R19 */
        mtspr   SPRG6, r20      /* SPRG6 = R20 */
        mtspr   SPRG7, r21      /* SPRG7 = R21 */
# endif
#endif
#if     (TLB_N_WORDS == 3)
	stw	r22, R22_OFFSET(r1)	/* save R22 */
#endif	/* TLB_N_WORDS == 3 */

	mfspr	r18, DEAR  /* load R18 with data miss effective address */
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

#if	(TLB_N_WORDS == 3)
	lwz 	r22, 8(r18)	/* word 2 of tlb entry */
# if	defined(CACHE_STATE_VAR)
	lis 	r20, HI(CACHE_STATE_VAR)
	ori	r20, r20, LO(CACHE_STATE_VAR)
	lwz	r20, 0(r20)	/* read value of cache state variable */
	cmpwi	r20, 0		/* compare with zero (FALSE) */
	bne	0f		/* caching allowed, skip ahead */

	/* caching not allowed, turn off writethru, turn on inhibit */
	rlwinm  r22, r22, 0, TLB_W_BIT+1, TLB_W_BIT-1
	lis	r20, HI(MMU_STATE_CACHEABLE_NOT)
	ori	r20, r20, LO(MMU_STATE_CACHEABLE_NOT)
	or	r22, r22, r20
0:
#endif /* defined(CACHE_STATE_VAR) */
#endif	/* TLB_N_WORDS == 3 */
	lwz	r20, 0(r18)	/* word 0 of tlb entry */
	lwz 	r21, 4(r18)	/* word 1 of tlb entry */

	rlwinm. r19, r20, 0, TLB_V_BIT, TLB_V_BIT	/* test Valid bit */
	beq	mmuPpcDataTlbError	/* if entry not valid then exit */

#ifdef DEBUG_MISS_HANDLER
	lis 	r19, HI(mmuPpcDTlbMisses)
	ori	r19, r19, LO(mmuPpcDTlbMisses)
	lwz	r18, 0(r19)	/* read value of tlb miss counter */
	addi	r18, r18, 1	/* increment tlb replacement counter */
	stw	r18, 0(r19)	/* write back to memory */

	subi	r18, r18, 1	/* array is zero-based */
	rlwinm	r18, r18, 0, 24, 31 /* miss count modulo 256 */
	li	r19, 2		/* multiply by sizeof pointer */
	slw	r18, r18, r19
	lis 	r19, HI(mmuPpcDTlbMissArray)	/* load miss array address */
	ori	r19, r19, LO(mmuPpcDTlbMissArray)
	add	r19, r19, r18	/* index into miss array table */
	stw	r20, 0(r19)	/* write word0 to miss array entry */
#endif /* DEBUG_MISS_HANDLER */

	lis 	r19, HI(mmuPpcTlbNext)	/* get index of tlb entry to */
	ori	r19, r19, LO(mmuPpcTlbNext) /* replace */

	lwz	r18, 0(r19)	/* read tlb replacement counter */

	tlbwe	r20, r18, 0	/* write word 0 entry */
	tlbwe	r21, r18, 1	/* write word 1 entry */
#if	(TLB_N_WORDS == 3)
	tlbwe	r22, r18, 2	/* write word 2 entry */
#endif	/* TLB_N_WORDS == 3 */

	addi	r18, r18, 1	/* increment next replacement tlb counter */
	rlwinm	r18, r18, 0, 26, 31 /* mask off higher 26 bits */

#ifdef	TLB_MIN_SUPPORT
	/* bump up the replacement counter to the lowest dynamic tlb index */

	lis 	r20, HI(mmuPpcTlbMin)
	ori	r20, r20, LO(mmuPpcTlbMin)
	lwz	r20, 0(r20)	/* read value of mmuPpcTlbMin */
	subf.	r21, r20, r18	/* r21 <- next tlb - mmuPpcTlbMin */
	bge	0f		/* if not too low skip the next instruction */
	mr	r18, r20	/* use mmuPpcTlbMin instead */
0:
#endif	/* TLB_MIN_SUPPORT */

	stw	r18, 0(r19)	/* write back to memory */

#if     (TLB_N_WORDS == 3)
	lwz	r22, R22_OFFSET(r1)	/* load R22 */
#endif	/* TLB_N_WORDS == 3 */
#ifdef DONT_USE_SPRG4_7         /* restore registers from stack */
	lwz	r21, R21_OFFSET(r1)	/* load R21 */
	lwz	r20, R20_OFFSET(r1)	/* load R20 */
	lwz	r19, R19_OFFSET(r1)	/* load R19 */
	lwz	r18, CR_OFFSET(r1)  /* load CR  */
#else				/* restore registers from SPRG4-7 */
# if SPRG7_R
        mfspr   r21, SPRG7_R      /* R21 = SPRG7 */
        mfspr   r20, SPRG6_R      /* R20 = SPRG6 */
        mfspr   r19, SPRG5_R      /* R19 = SPRG5 */
        mfspr   r18, SPRG4_R      /* CR  = SPRG4 */
# else
        mfspr   r21, SPRG7      /* R21 = SPRG7 */
        mfspr   r20, SPRG6      /* R20 = SPRG6 */
        mfspr   r19, SPRG5      /* R19 = SPRG5 */
        mfspr   r18, SPRG4      /* CR  = SPRG4 */
# endif
#endif
	mtcr	r18
	lwz	r18, R18_OFFSET(r1)	/* load R18 */
	addi	sp, sp, TLB_FRAME_SIZE

	rfi

mmuPpcDataTlbError:

#ifdef DEBUG_MISS_HANDLER
	lis 	r19, HI(mmuPpcDTlbErrors)
	ori	r19, r19, LO(mmuPpcDTlbErrors)
	lwz	r18, 0(r19)	/* read value of tlb error counter */
	addi	r18, r18, 1	/* increment tlb replacement counter */
	stw	r18, 0(r19)	/* write back to memory */
#endif /* DEBUG_MISS_HANDLER */

#if     (TLB_N_WORDS == 3)
	lwz	r22, R22_OFFSET(r1)	/* load R22 */
#endif	/* TLB_N_WORDS == 3 */
#ifdef DONT_USE_SPRG4_7         /* restore registers from stack */
	lwz	r21, R21_OFFSET(r1)	/* load R21 */
	lwz	r20, R20_OFFSET(r1)	/* load R20 */
	lwz	r19, R19_OFFSET(r1)	/* load R19 */
	lwz	r18, CR_OFFSET(r1)  /* load CR  */
#else				/* restore registers from SPRG4-7 */
# if SPRG7_R
        mfspr   r21, SPRG7_R      /* R21 = SPRG7 */
        mfspr   r20, SPRG6_R      /* R20 = SPRG6 */
        mfspr   r19, SPRG5_R      /* R19 = SPRG5 */
        mfspr   r18, SPRG4_R      /* CR  = SPRG4 */
# else
        mfspr   r21, SPRG7      /* R21 = SPRG7 */
        mfspr   r20, SPRG6      /* R20 = SPRG6 */
        mfspr   r19, SPRG5      /* R19 = SPRG5 */
        mfspr   r18, SPRG4      /* CR  = SPRG4 */
# endif
#endif
	mtcr	r18
	lwz	r18, R18_OFFSET(r1)	/* load R18 */
	addi	sp, sp, TLB_FRAME_SIZE

        .long   0x48000302      /* ba vector 300 (data access
				 * exception)
				 */
FUNC_END(mmuPpcDataTlbMissHandler)
