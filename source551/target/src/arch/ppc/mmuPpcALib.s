/* mmuPpcALib.s - functions common to all PowerPC MMUs */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01m,05dec02,dtr  Including mmuE500Alib.s for PPC85XX.
01l,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
01k,24apr02,jtp  Add MMU_I_ADDR_TRANS definition
01j,17apr02,jtp  support PPC440 MMU; split code sections out to subfiles
01i,12feb02,dtr  Fix to branching on exit from Inst/Data Miss Handler
                 (PPC860 603).
01h,06nov01,dtr  Putting in full 32-bit branch support for exception handler.
01r,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01q,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01p,14dec00,s_m  fixed bug in comment
01o,14dec00,s_m  added actual 405 tlb instructions
01n,22nov00,s_m  fixed bug in mmuPpcTlbSearch
01m,21nov00,s_m  removed mmuPpcTlbie for PPC405 and removed ref. to PPC403
01l,25oct00,s_m  renamed PPC405 cpu types
01k,17jul00,sm   added PPC405 support functions
01j,18aug98,tpr  added PowerPC EC 603 support.
01i,06nov96,tpr  reworked PPC860 handlers to fix SPR #7381
01h,13may96,tpr  added mmuPpcDataTlbMissHandler() and mmuPpcInstTlbMissHandler()
01g,23feb96,tpr  added documentation + code clean up.
01f,14feb96,tpr  split PPC603 and PPC604.
01e,06jan96,tpr  replace some instructions by them value or normal mnemonic.
01d,10oct95,tpr  enclosed 603 specific stuff for itself.
01c,07oct95,tpr  added MMU exception handlers.
01b,21sep95,kvk  added mmuPpcSrSet and mmuPpcSrGet and tlbie routines
01a,23may95,caf  derived from mmu32ALib.s.
*/

/*
 * This file contains assembly-language functions common to all PowerPC
 * MMUs. These functions are very generic. Any additions to support a
 * particular implementation are present in other, family-specific files
 * (e.g. mmu400ALib.s, mmu440ALib.s).
 */

#define	_ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "esf.h"

#if ((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440))
#  include "mmu400ALib.s"
# if ((CPU == PPC405) || (CPU == PPC405F))
#  include "mmu405ALib.s"
# endif /* 405 family */
# if ((CPU == PPC440))
#  include "mmu440ALib.s"
# endif /* 440 family */
#endif /* 400 family */

#if ((CPU == PPC601) || (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604))
#  include "mmu600ALib.s"
# if ((CPU == PPC603) || (CPU == PPCEC603))
#  include "mmu603ALib.s"
# endif /* 603 family */
#endif /* 600 family */

#if (CPU == PPC85XX)
#include "mmuE500ALib.s"
#endif 
	
#if ((CPU == PPC860))
#  include "mmu860ALib.s"
#endif /* 860 family */


/* defines */

/* Define these if not already defined in mmuXXXLib.h */

#ifndef MMU_I_ADDR_TRANS
# define MMU_I_ADDR_TRANS 0
#endif /* MMU_I_ADDR_TRANS */

#ifndef MMU_D_ADDR_TRANS
#define MMU_D_ADDR_TRANS 1
#endif /* MMU_D_ADDR_TRANS */

/* globals */

	FUNC_EXPORT(mmuPpcAEnable)			/* mmu PPC Enable */
	FUNC_EXPORT(mmuPpcADisable)			/* mmu PPC Disable */

	_WRS_TEXT_SEG_START
	

/******************************************************************************
*
* mmuPpcAEnable - Enable the Instruction or Data MMU
*
* This routine enable the Instruction or the Data MMU according the
* <mmuType> input argument. This input argument can only take two
* values: MMU_I_ADDR_TRANS and MMU_D_ADDR_TRANS. 
*
* RETURNS: N/A

* void mmuPpcAEnable 
*     (
*     UINT	mmuType			/@ type of MMU to enable @/
*     )

*/

FUNC_BEGIN(mmuPpcAEnable)
	mfmsr	p1			/* load the MSR value in P1 */

       	cmpwi	p0, MMU_I_ADDR_TRANS	/* is instruction MMU selected? */
	bne	enaDat			/* if not jump */

#if defined(_PPC_MSR_IR)
	ori	p1, p1, _PPC_MSR_IR 	/* set the IR bit of the MSR */
#elif defined(_PPC_MSR_IS)
	ori	p1, p1, _PPC_MSR_IS 	/* set the IS bit of the MSR */
#else
#  error "bit to enable instruction mmu is not defined"
#endif
	mtmsr	p1			/* ENABLE the INSTRUNCTION MMU */
	isync				/* instruction SYNChronization */
	blr

enaDat:
       	cmpwi	p0, MMU_D_ADDR_TRANS	/* is data MMU selected? */
	bne	enaErr			/* if not go to error */

#if defined(_PPC_MSR_DR)
	ori	p1, p1, _PPC_MSR_DR	/* set the DR bit of the MSR */
#elif defined(_PPC_MSR_DS)
	ori	p1, p1, _PPC_MSR_DS	/* set the DS bit of the MSR */
#else
#  error "bit to enable data mmu is not defined"
#endif
	mtmsr	p1			/* ENABLE the DATA MMU */
	sync				/* SYNChronization */
enaErr:					/* errors do nothing and return */
	blr	

FUNC_END(mmuPpcAEnable)

/******************************************************************************
*
* mmuPpcADisable - Enable the Instruction or Data MMU
*
* This routine disables the Instruction or the Data MMU according the
* <mmuType> input argument. This input argument can only take two
* values: MMU_I_ADDR_TRANS and MMU_D_ADDR_TRANS. 
*
* RETURNS: N/A

* void mmuPpcADisable 
*     (
*     UINT	mmuType			/@ type of MMU to enable @/
*     )

*/

FUNC_BEGIN(mmuPpcADisable)
	mfmsr	p1			/* load the MSR value to P1 */

       	cmpwi	p0, MMU_I_ADDR_TRANS	/* is instruction MMU selected? */
	bne	disDat			/* if not, jump... */

	rlwinm	p1, p1, 0, 27, 25	/* clear _PPC_MSR_IR/_PPC_MSR_IS */
	mtmsr	p1			/* DISABLE the Instruction MMU */
	isync				/* instruction SYNChronization */
	blr

disDat:
       	cmpwi	p0, MMU_D_ADDR_TRANS	/* is data MMU selected? */
	bne	disErr			/* if not, jump... */

	rlwinm	p1, p1, 0, 28, 26	/* clear _PPC_MSR_DR/_PPC_MSR_DS */
	mtmsr	p1			/* DISABLE the Data MMU */
	sync				/* SYNChronization */

disErr:					/* errors do nothing and return */
	blr	
FUNC_END(mmuPpcADisable)
