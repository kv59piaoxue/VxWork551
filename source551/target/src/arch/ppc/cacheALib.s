/* cacheALib.s - PowerPC cache management assembly routines */

/* Copyright 1995-2003 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
02d,24jul03,dtr  Formal inspection fixes, remove some CPU==PPC85XX defines and		       fix bug introduced with CP1 merge.
02c,09jun03,dtr  CP1 merge
02c,31jan03,jtp  SPR 82770 handle multiple icbi needed for PPC440
                 virtual-tagged I-Cache
02b,13jan03,pch  SPR 79170: check for MMU enabled before en/disabling cache
02b,20dec02,mil  Fixed build error.
02a,04dec02,dtr  Adding support for E500.
02a,03dec02,pch  604 seems to need sync instead of isync after changing
		 HID0[ICE]
01z,12sep02,pch  SPR 80642: fix 40x/60x/7xx/74xx handling in cachePpcDisable
01z,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
01y,21may02,pch  SPR 77727: fix 405 preprocessor expressions
		 SPR 77736: workaround for PPC405GP errata #15
01x,17apr02,jtp  support PPC440 cache
01w,29oct01,dtr  SPR 63012 - use of non-volatile conditional field.
01v,22oct01,gls  changed to flush 64K cache for 604/7xx (SPR #67431/#28800)
01u,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01t,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01s,03nov00,s_m  added check in cachePpcDisable for PPC405 - if MMU is on
                 return error
01r,25oct00,s_m  renamed PPC405 cpu types
01q,16oct00,sm   In cachePpcEnable, used ppc405DccrVall to initialize the
                 cache, since this is configurable by bsp.
01p,11oct00,sm   fixed problems in cachePpcEnable for PPC405
01o,06oct00,sm   added support for PPC405
01n,24feb99,tpr  added cacheArchPipeFlush.
01m,18aug98,tpr  added PowerPC EC 603 support.
01l,22jul97,tpr  added sync instruction arround HID0 modification (SPR #8976)
01k,21feb97,tam  added support for the PPC403GCX processor.
01j,03sep96,tam  added PPC403 support.
01i,29jul96,tpr  changed MPC_IMP_DCACHE_SIZE value.
01h,15apr96,tam  fixed typo error in cachePpcEnable (SPR #6334 ).
01g,23feb96,tpr  clean up the code.
01f,06jan96,tpr  replace %hi and %lo by HI and LO.
01e,27sep95,tpr  removed MMU disable in cacheEnable() and cacheDisable().
01d,01aug95,kvk  Fixed cacheEnable added cacheDisable to support PPC604.
01c,22jun95,caf  added ifdef for PPC403, cleanup.
01b,27mar95,caf  added cacheEnable() support.
01a,30jan95,caf  created.
*/

/*
DESCRIPTION
This library contains routines to manipulate the PowerPC family caches.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "cacheLib.h"

	
/* defines */

#if	((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604))
/* sizes used in cachePpcDisable(), only for the 60x cases */
#define	MPC_IMP_BLOCK_SIZE	_CACHE_ALIGN_SIZE
# if	(CPU == PPC604)
# define MPC_IMP_DCACHE_SIZE 32768
# else	/* CPU == PPC604 */
# define MPC_IMP_DCACHE_SIZE 16384
# endif	/* CPU == PPC604 */
#endif	/* ((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)) */

	DATA_IMPORT(cachePpcReadOrigin)

	FUNC_IMPORT(cacheErrnoSet)
#if (CPU == PPC440)
	FUNC_IMPORT(cache440Enable)
	FUNC_IMPORT(cache440Disable)
#endif	/* PPC440 */

#if	(CPU == PPC403)
	DATA_IMPORT(ppc403IccrVal)	/* ICCR default cachability states */
	DATA_IMPORT(ppc403DccrVal)	/* DCCR default cachability states */
#endif	/* CPU == PPC403 */

#if ( (CPU == PPC405F) || (CPU == PPC405) )
	DATA_IMPORT(ppc405ICACHE_LINE_NUM) /* comes from BSP */
	DATA_IMPORT(ppc405DCACHE_LINE_NUM) /* comes from BSP */
	DATA_IMPORT(ppc405CACHE_ALIGN_SIZE)/* comes from BSP*/
#endif	/* PPC405F || PPC405 */
	

	FUNC_EXPORT(cachePpcEnable)	  /* enable the data or instr. cache */
	FUNC_EXPORT(cachePpcDisable)	  /* disable the data or instr. cache */
	FUNC_EXPORT(cacheArchInvalidate)  /* invalidate data or instr. cache */
	FUNC_EXPORT(cacheArchFlush)	  /* flush the data or instr. cache */
	FUNC_EXPORT(cacheArchTextUpdate)  /* update the instruction cache */
	FUNC_EXPORT(cacheArchPipeFlush)	  /* flush the CPU pipe cache */
#if (CPU == PPC85XX)
	DATA_IMPORT(ppcE500ICACHE_LINE_NUM) /* comes from BSP */
	DATA_IMPORT(ppcE500DCACHE_LINE_NUM) /* comes from BSP */
	DATA_IMPORT(ppcE500CACHE_ALIGN_SIZE)/* comes from BSP*/

	FUNC_EXPORT(cacheE500Enable)	  /* enable the data or instr. cache */
	FUNC_EXPORT(cacheE500Disable)	  /* disable the data or instr. cache */
#include "cacheE500ALib.s"
#endif
#ifdef _WRS_I_CACHE_TAG_VIRTUAL

	/*
	 * PPC440 has virtually tagged cache lines. The tag is the
	 * entire virtual address, comprising the 32-bit Effective
	 * Address (EA) concatenated with 8-bit Process ID (PID) and
	 * 1-bit Translation Space (TS).
	 *
	 * The result is that data cached from the same physical memory
	 * location may appear in multiple cache lines... for example,
	 * lines filled during a fetch when MSR[IS] = 0, MSR[IS] = 1,
	 * PID = 0, or PID = 2, or when different EAs map the same
	 * physical memory location, in any combination.  If not managed
	 * correctly, these cache lines may have different data contents
	 * cached for the same physical memory location.  This is
	 * particularly visible when setting breakpoints
	 * (usrBreakpointSet).
	 *
	 * There are two approaches: one is to clear the entire I-cache
	 * using iccci, or to issue multiple icbi instructions with all
	 * possible combinations of EA, PID, and TS (note: fetches gets
	 * TS from MSR[IS], but icbi gets TS from MSR[DS]).
	 *
	 * Note that the MMU_BASIC library is assumed, it uses PID=0 to
	 * get started, and PID=2 once the MMU library has been
	 * initialized, if the MMU library has been configured. See
	 * mmu440Lib.c and mmu440LibInit().
	 *
	 * With both I and D MMUs unconfigured, and assuming the same
	 * physical line is not being accessed with multiple EA->PA
	 * translations, then a single icbi with PID=0 and TS=0 is
	 * enough. If either MMU is configured, an additional icbi with
	 * PID=2 and TS=0 is needed. If the I-MMU is configured, then
	 * PID=0, TS=1 and PID=2, TS=1 must be set up for icbi.
	 *
	 * While PID or TS is changed, it is important to not incur any
	 * exceptions, interrupts, or TLB Misses. This is aided by the
	 * fact that icbi gets TS from MSR[DS] instead of MSR[IS], and
	 * we can avoid data accesses that would incur a data TLB Miss.
	 *
	 * Pseudocode for clearing one physical address:
	 *
	 *  MMU_TEMP <== mmuPpcSelected
	 *  MSR_SAVE <== MSR
	 *  MSR[CE,DE,DWE,EE,IS] <== 0
	 *  PID_SAVE <== PID
	 *
	 *  PID <== 0; MSR[DS] <== 0; icbi r0, p1
	 *
	 *  if ((MMU_TEMP | (MMU_INST | MMU_DATA)) != 0)
	 *	PID <== 2; MSR[DS] <== 0; icbi r0, p1
	 *	if ((MMU_TEMP | MMU_INST) != 0)
	 *	    PID <== 2; MSR[DS] <== 1; icbi r0, p1
	 *	    PID <== 0; MSR[DS] <== 1; icbi r0, p1
	 *
	 *  MSR <== MSR_SAVE
	 *  PID <== PID_SAVE
	 *
	 * The same code is needed for both cacheTextUpdate and
	 * cacheArchInvalidate.  The code is provided below as a macro,
	 * ICBI.  The macro takes these parameters:
	 *
	 *	EA_REG - register holding effective address to be icbi'ed
	 *	MSR_SAVE - register to save and restore MSR value in
	 *	PID_SAVE - register to save and restore PID value in
	 *	MMU_TMP - register to use for MMU configuration storage
	 *	MSR_TMP - register to use for manipulating MSR contents
	 *	TMP_REG - register for general use
	 */

# if 1
	/*
	 * ICBI for processors with virtual-tagged I-Cache as described
	 * above.
	 */

#include <arch/ppc/mmu440Lib.h>
	DATA_IMPORT(mmuPpcSelected)

# define ICBI(EA_REG,MSR_SAVE,PID_SAVE,MMU_TMP,MSR_TMP,TMP_REG)		       \
									       \
	lis     MMU_TMP, HIADJ(mmuPpcSelected)	/* load mmuPpcSelected    */ ; \
        lwz     MMU_TMP, LO(mmuPpcSelected)(MMU_TMP)	/* MMU_TMP <==    */ ; \
									       \
	mfmsr	MSR_SAVE			/* MSR_SAVE <== orig MSR  */ ; \
	lis	TMP_REG, HI( ~(_PPC_MSR_CE|_PPC_MSR_EE|_PPC_MSR_DE|            \
			       _PPC_MSR_DWE|_PPC_MSR_IS|_PPC_MSR_DS))	     ; \
	ori	TMP_REG, TMP_REG, LO( ~(_PPC_MSR_CE|_PPC_MSR_EE|_PPC_MSR_DE|   \
			       _PPC_MSR_DWE|_PPC_MSR_IS|_PPC_MSR_DS))	     ; \
	and	MSR_TMP, MSR_SAVE, TMP_REG				     ; \
	mtmsr	MSR_TMP				/* INTS & MMU off 	  */ ; \
	isync					/* synchronize		  */ ; \
									       \
	xor	TMP_REG,TMP_REG,TMP_REG					     ; \
	mfpid	PID_SAVE			/* PID_SAVE <== PID       */ ; \
	mtpid	TMP_REG				/* PID <== 0		  */ ; \
	isync					/* synchronize		  */ ; \
	icbi	r0,EA_REG			/* inval for TS 0, PID 0  */ ; \
									       \
	andi.	MMU_TMP, MMU_TMP, (MMU_INST | MMU_DATA)   /* MMUs off?    */ ; \
	beq	99f				/* if so, skip ahead      */ ; \
									       \
	li	TMP_REG, 2						     ; \
	mtpid	TMP_REG				/* PID <== 2		  */ ; \
	isync					/* synchronize		  */ ; \
	icbi	r0,EA_REG			/* inval for TS 0 PID 2   */ ; \
									       \
	andi.	MMU_TMP, MMU_TMP, (MMU_INST)	/* instruction MMU off?   */ ; \
	beq	99f				/* if so, skip ahead	  */ ; \
									       \
	ori	MSR_TMP, MSR_TMP, _PPC_MSR_DS				     ; \
	mtmsr	MSR_TMP				/* MSR[DS] <== 1	  */ ; \
	isync					/* synchronize		  */ ; \
	icbi	r0,EA_REG			/* inval for TS 1 PID, 2  */ ; \
									       \
	xor	TMP_REG, TMP_REG, TMP_REG				     ; \
	mtpid	TMP_REG				/* PID <== 0		  */ ; \
	isync					/* synchronize		  */ ; \
	icbi	r0,EA_REG			/* inval for TS 1, PID 0  */ ; \
									       \
99:									       \
	mtpid	PID_SAVE			/* restore orig PID	  */ ; \
	isync								     ; \
	mtmsr	MSR_SAVE			/* restore orig MSR	  */ ; \
	isync

# else /* not used */

	/*
	 * Alternate ICBI for processors with Virtual-tagged I-cache,
	 * with lowest performance but greatest portability. Will work
	 * on all Book E Processors. All parameters are ignored.
	 */

# define ICBI(EA_REG,MSR_SAVE,PID_SAVE,MMU_TMP,MSR_TMP,TMP_REG)		       \
	iccci	r0,r0

# endif

#else  /* _WRS_I_CACHE_TAG_VIRTUAL */

	/*
	 * Normal ICBI for processors with physically-tagged I-Cache.
	 * All but the first parameter are ignored.
	 */

# define ICBI(EA_REG,MSR_SAVE,PID_SAVE,MMU_TMP,MSR_TMP,TMP_REG)		       \
	icbi	r0,EA_REG

#endif /* _WRS_I_CACHE_TAG_VIRTUAL */


	_WRS_TEXT_SEG_START

/******************************************************************************
*
* cachePpcEnable - Enable the PowerPC Instruction or Data cache
*
* This routine enables the instruction or data cache as selected by the
* <cache> argument.
*
* NOTE:
* This routine should never be called by the user application. Only
* the cacheArchEnable() can call this routine. If the user application calls
* this routine directly the result is unpredictable and can crash the VxWorks
* kernel.
*
* RETURNS: OK or ERROR if the cache can not be enabled.
*
* SEE ALSO:
*.I "PPC403GA Embedded Controller User's Manual"
*.I "PowerPC 601 RISC Microprocessor User's Manual"
*.I "PowerPC 603 RISC Microprocessor User's Manual"
*.I "PowerPC 604 RISC Microprocessor User's Manual"

* STATUS cachePpcEnable
*     (
*     CACHE_TYPE  cache,          /@ cache to enable @/
*     )

*/

FUNC_BEGIN(cachePpcEnable)

#if     (CPU == PPC85XX)
	b cacheE500Enable
/*
 * This #elif block covers the entire cachePpcEnable function.
 * All alternatives are marked as just below.
 */
#elif	(CPU == PPC601)


/* **** cachePpcEnable **** */

	/*
	 * PPC601 caches are always on. The only way to disable the caches is
	 * via the MMU.
	 */

	b	cacheArchOK			/* return OK */

/* **** cachePpcEnable **** */
#elif	( (CPU == PPC403) || (CPU == PPC405F) || (CPU == PPC405) )

# if (CPU == PPC403)
	li	p3, 0				/* p3 = multiplication factor */
        mfspr   p1, PVR				/* for _CACHE_LINE_NUM */
        rlwinm  p1, p1, 24, 24, 31      	/* extract CPU ID PVR[16:23] */
        cmpwi   p1, _PVR_CONF_403GCX
        bne     enableNo403gcx 			/* 8 for 403GCX which has */
        li	p3, 3               		/* cache 8 times larger */

enableNo403gcx:
# endif	/* PPC403 */
	cmpwi	p0, _DATA_CACHE			/* if _DATA_CACHE then */
	beq	cachePpc403DataEnable		/* enable Data Cache */
# if (CPU == PPC403)
        lis     p2, HIADJ(ppc403IccrVal)
	lwz     p2, LO(ppc403IccrVal)(p2)	/* load ppc403IccrVal value */
# else	/* PPC403 */
	/*
 	 * if the MMU is enabled, the only way to enable the cache is
	 * via the MMU.
	 */
	mfmsr	p2
	rlwinm.	p2, p2, 0, _PPC_MSR_BIT_IR, _PPC_MSR_BIT_IR
	bne	cacheArchError		/* return ERROR if IR set */

        lis     p2, HIADJ(ppc405IccrVal)
	lwz     p2, LO(ppc405IccrVal)(p2)	/* load ppc405IccrVal value */
# endif	/* PPC403 */

	mfspr	p1, ICCR			/* move ICCR to p1 */
	cmpw	p1, p2				/* if instr. cache is already */
	beq	cacheArchOK			/* enabled just return OK */

        /* reset the instruction cache */
# if ((CPU == PPC405) || (CPU == PPC405F))
/* For PPC405 RevE and earlier, disable data MMU to work around errata #15 */
	mfmsr	p3				/* read msr */
	rlwinm	p4,p3,0,28,26			/* Turn off DR bit */
	mtmsr	p4				/* disable data MMU */
	iccci	r0, r0	/* On the 405, iccci invalidates the entire I CACHE */
	mtmsr	p3				/* restore data MMU */
# else /* CPU == PPC403 */
        li      p0, 0                           /* clear p0 */

        li      p1, _ICACHE_LINE_NUM            /* load number of cache lines */
	slw	p1, p1, p3			/* adjust with mult. factor */
        mtctr   p1

cachePpc403IInvalidate:
        iccci   r0, p0
        addi    p0, p0, _CACHE_ALIGN_SIZE       /* bump to next line */
        bdnz    cachePpc403IInvalidate          /* go to invalidate */
# endif /* ((CPU == PPC405) || (CPU == PPC405F)) */

	/* enable instruction cache */
	mtspr   ICCR, p2			/* load ICCR with p2 */
	isync

	b	cacheArchOK			/* return OK */

cachePpc403DataEnable:
# if (CPU == PPC403)
        lis     p2, HIADJ(ppc403DccrVal)
	lwz     p2, LO(ppc403DccrVal)(p2)	/* load ppc403DccrVal value */
# else	/* PPC403 */
	/*
 	 * if the MMU is enabled, the only way to enable the cache is
	 * via the MMU.
	 */
	mfmsr	p2
	rlwinm.	p2, p2, 0, _PPC_MSR_BIT_DR, _PPC_MSR_BIT_DR
	bne	cacheArchError		/* return ERROR if DR set */

        lis     p2, HIADJ(ppc405DccrVal)
	lwz     p2, LO(ppc405DccrVal)(p2)	/* load ppc405DccrVal value */
# endif	/* PPC403 */
	mfspr	p1, DCCR			/* move DCCR to P1 */
	cmpw	p1, p2				/* if data cache is already */
	beq	cacheArchOK			/* enabled just return OK */

        /* reset the data cache */

        li      p0, 0                           /* clear p0 */
# if ( (CPU != PPC405F) && (CPU != PPC405) )
        li      p1, _DCACHE_LINE_NUM          /* load number of cache lines */
	slw	p1, p1, p3			/* adjust with mult. factor */
# else	/* !405F && !405 */
        lis     p1, HIADJ(ppc405DCACHE_LINE_NUM)
	lwz     p1, LO(ppc405DCACHE_LINE_NUM)(p1)
# endif	/* !405F && !405 */
        mtctr   p1

# if ( (CPU == PPC405F) || (CPU == PPC405) )
	/* On the PPC405 the cache line size may be variable, so read
	 * in the variable which specifies the cache line size.
	 */
        lis     p1, HIADJ(ppc405CACHE_ALIGN_SIZE)
        lwz     p1, LO(ppc405CACHE_ALIGN_SIZE)(p1)
# endif	/* PPC405F || PPC405 */

cachePpc403DInvalidate:
        dccci   r0, p0
# if ( (CPU == PPC405F) || (CPU == PPC405) )
        add     p0, p0, p1                      /* bump to next line */
# else	/* PPC405F || PPC405 */
        addi    p0, p0, _CACHE_ALIGN_SIZE       /* bump to next line */
# endif	/* PPC405F || PPC405 */
        bdnz    cachePpc403DInvalidate          /* go to invalidate */

	/* enable data cache */

	mtspr   DCCR, p2			/* load DCCR with p2 */
# if (CPU != PPC403)
/* XXX - Should set _PPC405_DCWR the same as _PPC405_DCCR if
 * XXX - cacheDataMode is CACHE_WRITETHROUGH -- see SPR 77774.
 * XXX - Not done yet because WT should also affect the TLB.
 */
#endif	/* PPC403 */

	isync

	b	cacheArchOK			/* return OK */

/* **** cachePpcEnable **** */
#elif (CPU == PPC440)
	b	cache440Enable

/* **** cachePpcEnable **** */
#else	/* the following code is for 6xx other than 601 */

	mfspr	p1, HID0			/* move HID0 to P1 */

	/* Select if the cache to enable is the Data or the Instruction cache */

       	cmpwi	p0, _DATA_CACHE			/* if _DATA_CACHE then*/
	beq	cachePpcDataEnable		/* enable Data Cache */

	/* enable an flush the Instruction cache */

	andi.	p2, p1, _PPC_HID0_ICE		/* if instr. cache is already */
	bne	cacheArchOK			/* enabled just return OK */

	ori	p1, p1, _PPC_HID0_ICE | _PPC_HID0_ICFI	/* set ICE & ICFI bit */

# if	((CPU == PPC603) || (CPU == PPCEC603))
	rlwinm  p2, p1, 0, 21, 19		/* clear the ICFI bit */
# endif	/* ((CPU  == PPC603) || (CPU == PPCEC603)) */

	/*
	 * The setting of the instruction cache enable (ICE) bit must be
	 * preceded by an isync instruction to prevent the cache from being
	 * enabled or disabled while an instruction access is in progress.
	 * XXX TPR to verify.
         */

	isync				/* Synchronize for ICE enable */
	mtspr	HID0, p1		/* Enable Instr Cache & Inval cache */
# if	((CPU == PPC603) || (CPU == PPCEC603))
	mtspr	HID0, p2		/* using 2 consec instructions */
	isync				/* PPC603 recommendation */
# else	/* ((CPU  == PPC603) || (CPU == PPCEC603)) */
	sync				/* sync here makes no sense, but isync
					 * does not seem to work properly on
					 * any of 604e, 750CX, 750FX, 7400 */
# endif	/* ((CPU  == PPC603) || (CPU == PPCEC603)) */

	b	cacheArchOK		/* return OK */

cachePpcDataEnable:			/* enable data cache code */

	andi.	p2, p1, _PPC_HID0_DCE	/* if data cache already enabled */
	bne	cacheArchOK		/* then exit with OK */

	ori	p1, p1, _PPC_HID0_DCE | _PPC_HID0_DCFI	/* set DCE & DCFI bit */

# if	((CPU == PPC603) || (CPU == PPCEC603))
	rlwinm	p2, p1, 0, 22, 20	/* clear the DCFI bit */
# endif	/* ((CPU  == PPC603) || (CPU == PPCEC603)) */

	/*
	 * The setting of the data cache enable (DCE) bit must be
	 * preceded by a sync instruction to prevent the cache from
	 * being enabled or disabled during a data access.
         */

	sync				/* Synchronize for DCE enable */
	mtspr	HID0, p1		/* Enable Data Cache & Inval cache */
# if	((CPU == PPC603) || (CPU == PPCEC603))
	mtspr	HID0, p2		/* using 2 consecutive instructions */
					/* PPC603 recommendation */
# endif	/* ((CPU  == PPC603) || (CPU == PPCEC603)) */
	sync

	b	cacheArchOK		/* return OK */

/* **** cachePpcEnable **** */
#endif	/* (CPU == PPC85XX) */
FUNC_END(cachePpcEnable)

/******************************************************************************
*
* cachePpcDisable - Disable the PowerPC Instruction or Data cache.
*
* This routine disables the instruction or data cache as selected by the
* <cache> argument.
*
* NOTE:
* This routine should not be called by the user application. Only
* the cacheArchDisable() can call this routine.
*
* RETURNS: OK, or ERROR if the cache can not be disabled.
*
* SEE ALSO:
*.I "PPC403GA Embedded Controller User's Manual"
*.I "PowerPC 601 RISC Microprocessor User's Manual"
*.I "PowerPC 603 RISC Microprocessor User's Manual"
*.I "PowerPC 604 RISC Microprocessor User's Manual"

* STATUS cachePpcDisable
*     (
*     CACHE_TYPE  cache,          /@ cache to disable @/
*     )

*/
FUNC_BEGIN(cachePpcDisable)
#if     (CPU == PPC85XX)
	b cacheE500Disable
#elif	(CPU == PPC601)
/*
 * This #if block covers the entire cachePpcDisable function.
 * All alternatives are marked as just below.
 */

/* **** cachePpcDisable **** */

	/*
	 * PPC601 caches are always on. The only way to disable the caches is
	 * via the MMU.
	 */

	b	cacheArchError		/* return ERROR */

/* **** cachePpcDisable **** */
#elif	( (CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F) )

# if (CPU == PPC403)
	li	p1, 0			/* p1 = shift-left count for */
        mfspr   p2, PVR			/* _CACHE_LINE_NUM per 403 CPU type */
        rlwinm  p2, p2, 24, 24, 31      /* extract CPU ID PVR[16:23] bits */
        cmpwi   p2, _PVR_CONF_403GCX
        bne     disableNo403gcx
        li	p1, 3               	/* 403GCX has cache 8 times larger */
disableNo403gcx:
# endif	/* PPC403 */

	cmpwi	p0, _DATA_CACHE		/* if _DATA_CACHE then*/
	beq	cachePpc403DataDisable	/* disable Data Cache */

	/* disable instruction cache */
# if ( CPU == PPC405 || CPU == PPC405F )
	/*
 	 * if the MMU is enabled, the only way to disable the cache is
	 * via the MMU.
	 */
	mfmsr	p0
	rlwinm.	p0, p0, 0, _PPC_MSR_BIT_IR, _PPC_MSR_BIT_IR
	bne	cacheArchError		/* return ERROR if IR set */
# endif	/* 405 || 405F */
	li	p0, 0x0          	/* 0x0-0xffffffff non cacheable */
        mtspr   ICCR, p0
	isync

	b	cacheArchOK		/* return OK */

	/* disable data cache */

cachePpc403DataDisable:
# if ( (CPU != PPC405F) && (CPU != PPC405) )
	li	p3, _DCACHE_LINE_NUM	/* # of cache lines in most 403 */
	slw	p3, p3, p1		/* 403GCX has 8x as many */
# else	/* !405F && !405 */
	/*
 	 * if the MMU is enabled, the only way to disable the cache is
	 * via the MMU.
	 */
	mfmsr	p3
	rlwinm.	p3, p3, 0, _PPC_MSR_BIT_DR, _PPC_MSR_BIT_DR
	bne	cacheArchError		/* return ERROR if DR set */

        lis     p3, HIADJ(ppc405DCACHE_LINE_NUM)
	lwz     p3, LO(ppc405DCACHE_LINE_NUM)(p3)
# endif	/* !405F && !405 */
        mtspr   CTR, p3			/* CTR = # of cache lines */
	slwi	p5, p3, 5		/* p5 = # of bytes in one cache way */

        /*
         * load up p2 with the buffer address minus
         * one cache block size
         */
# if (CPU == PPC403)
        lis     p2, HI(cachePpcReadOrigin - _CACHE_ALIGN_SIZE)
        ori	p2,p2,LO(cachePpcReadOrigin - _CACHE_ALIGN_SIZE)
# else	/* PPC403 */
	lis     p4, HIADJ(ppc405CACHE_ALIGN_SIZE)
        lwz     p4, LO(ppc405CACHE_ALIGN_SIZE)(p4)
	lis	p3, HIADJ(cachePpcReadOrigin)
	lwz	p3, LO(cachePpcReadOrigin)(p3)
			/* buffer points to 0x10000 - text segment */
	subf	p2, p4, p3
# endif	/* PPC403 */

	/*
	 * Disable interrupts during flush, to ensure everything
	 * is marked invalid when cache is disabled.
	 */

	mfmsr	p1			/* read msr */
	INT_MASK(p1, p0)		/* mask off ce & ee bits */
	mtmsr	p0			/* DISABLE INTERRUPT */

cachePpc403DisableFlush:

	/*
	 * The dcbf instruction seems to mark the flushed line as least-
	 * recently-used, so just cycling through will only flush one
	 * way of each congruence class no matter how many iterations are
	 * performed.  To fix this, we load up both ways from different
	 * addresses before flushing them both.  This code will only work
	 * on a two-way cache (which covers all 403 and 405, including
	 * 403GCX and 405GPr).
	 */

# if ( (CPU == PPC405F) || (CPU == PPC405) )
        add	p2, p4, p2
	lwz	p3, 0(p2)		    /* cast out old line if modified */
	lwzx	p3, p2, p5		    /* repeat p5 higher for other way */
# else	/* PPC405F || PPC405 */
        lbzu    p4, _CACHE_ALIGN_SIZE(p2)   /* cast out old line if modified */
	lbzx	p4, p2, p5		    /* repeat p5 higher for other way */
# endif	/* PPC405F || PPC405 */
	dcbf	0, p2			    /* flush 1st newly-loaded line */
	dcbf	p2, p5			    /* flush 2nd newly-loaded line */
        bdnz    cachePpc403DisableFlush
	sync

	/* disable the data cache */

        li	p0, 0x0			/* 0x0-0xffffffff non cacheable */
        mtspr   DCWR, p0		/* must also turn off WT bits */
        mtspr   DCCR, p0
	sync

	mtmsr	p1			/* restore MSR -- ENABLE INTERRUPT */
	b	cacheArchOK		/* return OK */

/* **** cachePpcDisable **** */
#elif	(CPU == PPC440)
	b	cache440Disable

/* **** cachePpcDisable **** */
#else	/* ((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)) */
	mfspr 	p1, HID0		/* save HID0 to p1 */

       	cmpwi	p0, _DATA_CACHE		/* <cache> == _DATA_CACHE ? */
	beq	cachePpcDataDisable

	/* disable instruction cache */

	rlwinm.	p2, p1, 0, _PPC_HID0_BIT_ICE, _PPC_HID0_BIT_ICE
	beq	cacheArchOK		/* return OK if cache already off */

	ori	p2,p1,_PPC_HID0_ICFI	/* set the ICFI bit */
	rlwinm	p1,p1,0,21,19		/* Turn off the ICFI bit */
	rlwinm	p1,p1,0,17,15		/* Turn off Cache enable bit */

	isync				/* Synchronize for ICE disable */
	mtspr	HID0,p2			/* Invalidate Instr Cache */
# if	((CPU == PPC603) || (CPU == PPCEC603))
	mtspr	HID0,p1			/* using 2 consec instructions */
	isync				/* PPC603 recommendation */
# else	/* ((CPU  == PPC603) || (CPU == PPCEC603)) */
	sync				/* sync here makes no sense, but isync
					 * does not seem to work properly on
					 * any of 604e, 750CX, 750FX, 7400 */
# endif	/* ((CPU  == PPC603) || (CPU == PPCEC603)) */

	b	cacheArchOK		/* return OK */

	/* disable data cache */

cachePpcDataDisable:

	/* if cache already disabled, just return OK */
	rlwinm.	p2, p1, 0, _PPC_HID0_BIT_DCE, _PPC_HID0_BIT_DCE
	beq	cacheArchOK

	/*
	 * All 7xx and 74xx require interrupts disabled during flush.
	 * Do it for 603/604 also, to ensure everything is marked invalid
	 * when cache is disabled.
	 * Also disable the MMU so that TLB reloads (hardware or software)
	 * do not cause page table entries to be brought into the cache.
	 */
#define	_PPC604_USE_DCFA

	mfmsr	p0			/* read msr */
	INT_MASK(p0, p4)		/* mask off ee bit */
	rlwinm	p4, p4, 0, 28, 25	/* mask off DR and IR */
	mtmsr	p4			/* DISABLE INTERRUPT & MMU */
# if (CPU == PPC604)
	mfspr	p2,PVR
	rlwinm	p2,p2,16,16,31		/* extract MS half of PVR */
	cmplwi	p2,0x0009		/* check for PPC604e */
	beq	cachePpcDataDisable604
	cmplwi	p2,0x0004		/* check for PPC604 */
	beq	cachePpcDataDisable604
	cmplwi	p2,0x8000		/* check for MPC7450 */
	beq	cachePpcDataDisable604	/* Like 604, 7450 has no DCFA */

	/* 7400 and 7410 (but not 744x or 745x) have a hardware L1 flush */

	rlwinm	p2,p2,0,17,31		/* mask off bit 0x8000 */
	cmplwi	p2,0x000C		/* check for MPC7400 or MPC7410 */
	bne	noHWflush

	/*
	 * Code sequence described in sec. 3.5.2 "Data Cache Hardware Flush
	 * Parameter in MSSCR0" of the MPC7400 and MPC7410 User's Manuals
	 */
	.long	0x7e00066c	/* dssall */
	sync
	mfspr	p2,MSSCR0
	oris	p2,p2,_PPC_MSSCR0_DL1HWF_U
	mtspr	MSSCR0,p2
wait4l1hw:
	mfspr	p2,MSSCR0
	rlwinm.	p2,p2,0,8,8	/* _PPC_MSSCR0_DL1HWF */
	bne	wait4l1hw
	sync
	b	cachePpcDisableFlushDone

noHWflush:
#  ifdef _PPC604_USE_DCFA
	/*
	 * Set HID0[DCFA] for 7xx.  p1 already contains HID0, and interrupts
	 * are already disabled.  This is the officially recommended method
	 * for all 7xx, however malfunctions have been observed on 750CX and
	 * 750FX if the MMU is enabled.  The alternative below may work better
	 * in such cases.  (Another possible approach, not yet tested, is to
	 * preload the TLB with the addresses to be used in the flush operation
	 * so that TLB misses do not occur during the flush loop.)
	 */
	ori	p3, p1, _PPC_HID0_DCFA
	mtspr	HID0,p3
#  else	/* _PPC604_USE_DCFA */
	/*
	 * To cover optimized PLRU replacement which uses invalid lines
	 * first, 7xx manuals say count must be 1.5 * total # of lines in
	 * cache:  32KB => 1536
	 */
	li	p3, (3 * MPC_IMP_DCACHE_SIZE) / (2 * MPC_IMP_BLOCK_SIZE)
	b	cachePpcDataDisableSetCtr
#  endif /* _PPC604_USE_DCFA */

cachePpcDataDisable604:
	/*
	 * Interrupts have been disabled, and HID0[DCFA] has been set if
	 * required.  Former contents of MSR and HID0 are in p0 and p1
	 * respectively, and will be restored even if unchanged.  This also
	 * works for 7450 since its PLRU always acts as if DCFA were set.
	 */
	li	p3, MPC_IMP_DCACHE_SIZE / MPC_IMP_BLOCK_SIZE  /* 32KB => 1024 */

# else	/* PPC604 */
	/*
	 * All supported PPC603 (incl MPC82xx) have 16KB or smaller dCache,
	 * and no DCFA or hardware flush facility.
	 */
	li	p3, MPC_IMP_DCACHE_SIZE / MPC_IMP_BLOCK_SIZE  /* 16KB => 512 */
# endif	/* PPC604 */

# if	defined (PPC604) && !defined (_PPC604_USE_DCFA)
cachePpcDataDisableSetCtr:
# endif	/* PPC604 & !_PPC604_USE_DCFA */
	mtspr	CTR,p3			/* load CTR with the number of index */

	/* load up p2 with the buffer address minus one cache block size */

	lis 	p2,HI(cachePpcReadOrigin-MPC_IMP_BLOCK_SIZE)
	ori	p2,p2,LO(cachePpcReadOrigin-MPC_IMP_BLOCK_SIZE)

cachePpcDisableLoad:
	lbzu	p4,MPC_IMP_BLOCK_SIZE(p2)   /* cast out old line if modified */
	bdnz	cachePpcDisableLoad	    /* repeat for all sets and ways */

	mtspr	CTR,p3			    /* reload CTR and p2 */
	lis 	p2,HI(cachePpcReadOrigin-MPC_IMP_BLOCK_SIZE)
	ori	p2,p2,LO(cachePpcReadOrigin-MPC_IMP_BLOCK_SIZE)

cachePpcDisableFlush:
	addi	p2, p2, MPC_IMP_BLOCK_SIZE  /* point to next cache line */
	dcbf	0,p2			    /* flush newly-loaded line */
	bdnz	cachePpcDisableFlush	    /* repeat for all sets and ways */

cachePpcDisableFlushDone:
	rlwinm	 p1,p1,0,18,16	    /* Turn off _PPC_HID0_DCE */

	sync			    /* Synchronize for DCE disable */
	mtspr   HID0,p1		    /* Disable dCache and restore DCFA */
	sync

	mtmsr	p0		    /* restore MSR -- ENABLE INTERRUPT & MMU */
	b	cacheArchOK	    /* return OK */

/* **** cachePpcDisable **** */
#endif	/* (CPU == PPC85XX) */

FUNC_END(cachePpcDisable)

/******************************************************************************
*
* cacheArchInvalidate - invalidate entries in a PowerPC cache
*
* This routine invalidates some or all entries in a specified PowerPC cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*

* STATUS cacheArchInvalidate
*     (
*     CACHE_TYPE  cache,          /@ cache to invalidate @/
*     void *      address,        /@ virtual address @/
*     size_t      bytes           /@ number of bytes to invalidate @/
*     )

* INTERNAL
* This code assumes that cache blocks are 16 (403) or 32 (else) bytes in size.
*/

FUNC_BEGIN(cacheArchInvalidate)
	add	p2,p2,p1	/* bytes += address */

#if 	( (CPU == PPC405) || (CPU == PPC405F) )
	lis     p4, HIADJ(ppc405CACHE_ALIGN_SIZE)
        lwz     p4, LO(ppc405CACHE_ALIGN_SIZE)(p4)
#endif	/* PPC405F || PPC405 */
#if 	(CPU == PPC85XX)
	lis     p4, HIADJ(ppcE500CACHE_ALIGN_SIZE)
        lwz     p4, LO(ppcE500CACHE_ALIGN_SIZE)(p4)
#endif

#if 	(CPU == PPC403)
	clrrwi	p1,p1,4		/* round address to 16 byte boundary */
#else	/* CPU == PPC403 */
	clrrwi	p1,p1,5		/* round address to 32 byte boundary */
#endif	/* CPU == PPC403 */
invChk:	cmpwi	cr6,p0,_DATA_CACHE /* test cache type in p0 (reuse cr6 below) */
	beq	cr6,invDat
	cmpwi	p0,_INSTRUCTION_CACHE     /* <cache> == _INSTRUCTION_CACHE ? */
	bne	cacheArchError	/* invalid cache? return ERROR */

	/* partial invalidation of instruction or data cache */

invIns:	ICBI(p1,p3,p5,p6,p7,glr1) /* invalidate copy(ies) in icache */
	b	invBottom

invDat: dcbi	r0,p1           /* dcache block invalidate */

invBottom:
#if ( (CPU == PPC405F) || (CPU == PPC405) || (CPU == PPC85XX) )
	add	p1,p1, p4	/* address += ppc405CACHE_ALIGN_SIZE */
#else	/* PPC405F || PPC405 */
	addi	p1,p1,_CACHE_ALIGN_SIZE	/* address += _CACHE_ALIGN_SIZE */
#endif	/* PPC405F || PPC405 */
	cmplw	p1,p2		/* (address < bytes) ? */
	bge	cacheArchOK	/* if not, return OK */
	beq	cr6,invDat	/* repeat data cache loop */
	b	invIns		/* repeat instruction cache loop */
FUNC_END(cacheArchInvalidate)

/******************************************************************************
*
* cacheArchFlush - flush entries in a PowerPC cache
*
* This routine flushes some or all entries in a specified PowerPC cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*

* STATUS cacheArchFlush
*     (
*     CACHE_TYPE  cache,          /@ cache to flush @/
*     void *      address,        /@ virtual address @/
*     size_t      bytes           /@ number of bytes to flush @/
*     )

* INTERNAL
* This code assumes that cache blocks are 16 (403) or 32 (else) bytes in size.
*/

FUNC_BEGIN(cacheArchFlush)
       	cmpwi	p0,_DATA_CACHE	/* check cache type in p0 */
	bne	cacheArchError	/* invalid cache? return ERROR */

      	add	p2,p2,p1	/* bytes += address */

#if 	( (CPU == PPC405) || (CPU == PPC405F) )
	lis     p5, HIADJ(ppc405CACHE_ALIGN_SIZE)
        lwz     p5, LO(ppc405CACHE_ALIGN_SIZE)(p5)
#endif	/* PPC405F || PPC405 */
#if 	(CPU == PPC85XX)
	lis     p5, HIADJ(ppcE500CACHE_ALIGN_SIZE)
        lwz     p5, LO(ppcE500CACHE_ALIGN_SIZE)(p5)
#endif

#if     ( CPU == PPC403 )
	clrrwi	p1,p1,4		/* round address to 16 byte boundary */
#else	/* CPU == PPC403 */
	clrrwi	p1,p1,5		/* round address to 32 byte boundary */
#endif	/* CPU == PPC403 */

#if	( (CPU == PPC405) || (CPU == PPC405F) )
/*
 * For a PPC405 RevC if MMU is enabled, we need workaround for errata # 37
 * However we do this workaround for all revs.
 */
        mfmsr   p3                      /* read msr */
        INT_MASK(p3, p4)                /* mask ee bit and ce bit */
        mtmsr   p4                      /* DISABLE INTERRUPT */
#endif	/* PPC405F || PPC405 */

fluDat:

#if	( (CPU == PPC405) || (CPU == PPC405F) )
	/* workaround for errata # 37 */
        dcbt    r0,p1
#endif	/* PPC405F || PPC405 */

	dcbst	r0,p1		/* data cache flush (PPC "store") ??dcbf?? */

#if ( (CPU == PPC405F) || (CPU == PPC405) || (CPU == PPC85XX))
	add	p1,p1,p5	/* address += ppc405CACHE_ALIGN_SIZE */
#else	/* PPC405F || PPC405 */
	addi	p1,p1,_CACHE_ALIGN_SIZE	/* address += _CACHE_ALIGN_SIZE */
#endif	/* PPC405F || PPC405 */
	cmplw	p1,p2		/* (address < bytes) ? */
	blt	fluDat		/* if so, repeat */

#if ( (CPU == PPC405) || (CPU == PPC405F) )
	mtmsr	p3		/* restore old msr after errata #37 fixup */
	sync
#endif	/* PPC405F || PPC405 */

	b	cacheArchOK	/* return OK */
FUNC_END(cacheArchFlush)

/******************************************************************************
*
* cacheArchTextUpdate - synchronize the PowerPC instruction and data caches
*
* This routine flushes the PowerPC data cache, and then invalidates the
* instruction cache.  The instruction cache is forced to fetch code that
* may have been created via the data path.
*
* RETURNS: OK, always.

* STATUS cacheArchTextUpdate
*    (
*    void * address,     /@ virtual address @/
*    size_t bytes        /@ number of bytes to update @/
*    )

* INTERNAL
* This code assumes that cache blocks are 16 (403) or 32 (else) bytes in size.
*
* NOMANUAL
*/

FUNC_BEGIN(cacheArchTextUpdate)

      	add	p1,p1,p0	/* bytes += address */

#if 	( (CPU == PPC405) || (CPU == PPC405F) )
	lis     p5, HIADJ(ppc405CACHE_ALIGN_SIZE)
        lwz     p5, LO(ppc405CACHE_ALIGN_SIZE)(p5)
#endif	/* PPC405F || PPC405 */
#if 	(CPU == PPC85XX)
	lis     p5, HIADJ(ppcE500CACHE_ALIGN_SIZE)
        lwz     p5, LO(ppcE500CACHE_ALIGN_SIZE)(p5)
#endif

#if     ( CPU == PPC403 )
	clrrwi	p0,p0,4		/* round address to 16 byte boundary */
#else	/* CPU == PPC403 */
	clrrwi	p0,p0,5		/* round address to 32 byte boundary */
#endif	/* CPU == PPC403 */

#if 	( (CPU == PPC405) || (CPU == PPC405F) )
/*
 * For a PPC405 RevC if MMU is enabled, we need workaround for errata 37
 * But we do it for all revs of PPC405
 */
        mfmsr   p3                      /* read msr */
        INT_MASK(p3, p4)                /* mask ee bit and ce bit */
        mtmsr   p4                      /* DISABLE INTERRUPT */

#endif 	/* PPC405F || PPC405 */

	/* loop */

updTop:

#if 	( (CPU == PPC405) || (CPU == PPC405F) )
        dcbt    r0,p0
#endif	/* PPC405F || PPC405 */

	dcbst	r0,p0		/* update memory */
	sync			/* wait for update */
	ICBI(p0,p2,p4,p6,p7,glr1) /* invalidate copy(ies) in icache */

#if ( (CPU == PPC405F) || (CPU == PPC405) || (CPU == PPC85XX) ) 
	add	p0,p0,p5	/* address += ppc405CACHE_ALIGN_SIZE */
#else	/* PPC405F || PPC405 */
	addi	p0,p0,_CACHE_ALIGN_SIZE	/* address += _CACHE_ALIGN_SIZE */
#endif	/* PPC405F || PPC405 */
	cmplw	p0,p1		/* (address < bytes) ? */
	blt	updTop		/* if so, repeat */

	isync			/* remove copy in own instruction buffer */

#if 	( (CPU == PPC405) || (CPU == PPC405F) )
	mtmsr	p3		/* restore old msr after errata #37 fixup */
#endif	/* PPC405F || PPC405 */

	b	cacheArchOK	/* return OK */

/******************************************************************************
*
* cacheArchError - set errno and return ERROR
*
* To save space, several routines exit through cacheArchError() if
* an invalid cache is specified.
*
* NOMANUAL
*/

cacheArchError:
	mfspr	r0,LR
	stw	r0,4(sp)
	stwu	sp,-16(sp)
	bl	cacheErrnoSet
	lwz	r0,20(sp)
	addi	sp,sp,16
	mtspr	LR,r0
	blr

/******************************************************************************
*
* cacheArchOK - return OK
*
* To save space, several routines exit normally through cacheArchOK().
*
* NOMANUAL
*/

cacheArchOK:
	sync			/* SYNC for good measure (multiprocessor?) */
        li      p0,OK		/* return OK */
	blr
FUNC_END(cacheArchTextUpdate)

/*******************************************************************************
*
* cacheArchPipeFlush - flush the processor pipe
*
* This function forces the processor pipes to be flushed.
*
* RETURNS: always OK
*
* NOMANUAL
*
*/

FUNC_BEGIN(cacheArchPipeFlush)
	eieio
	sync
        li      p0,OK		/* return OK */
	blr
FUNC_END(cacheArchPipeFlush)
