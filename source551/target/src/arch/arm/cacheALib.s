/* cacheALib.s - ARM cache management assembly routines */

/* Copyright 1996-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01q,11feb03,jb  Fix Merge generated problems
01p,17dec02,jb  Adding ARM 926e and ARM 102xE support, really fixed SPR 71795
01r,31jan03,jb   Backing out SPR 82859 fix as it breaks wrPpmci80310
01q,29jan03,jb   Resolve SPR 71795
01p,29jan03,scm  SPR 82859 modification...
01o,07dec01,rec  Merge in changes from Tor 2.1.1
                 removed early enable of ints in 920T DClearDisable (SPR
                 #71795)
01n,17oct01,t_m  convert to FUNC_LABEL:
01m,11oct01,jb   Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01k,03oct01,jpd  corrected ARM946E code (SPR #68958).
01l,25jul01,scm  add btbInvalidate routine and remove legacy test code from
                 cacheDFlush/cacheDFlushAll for XScale
01k,23jul01,scm  change XScale name to conform to coding standards...
01j,21jul00,jpd  added support for ARM946E.
01i,15feb99,jpd  added support for ARM740T, ARM720T, ARM920T.
01h,24nov98,jpd  added support for ARM 940T, SA-1100/SA-1500; made
		 cacheArchPipeFlush return OK (SPR #22258); made Thumb-aware;
		 moved cacheArchIntLock() to cacheALib2.s;
	    cdp  added support for generic ARM ARCH3/ARCH4.
01g,14nov97,jpd  disabled Ints in SA-110 cacheDClearAll.
01f,31oct97,jpd  fixed faults with invalidation on 810.
01e,27oct97,kkk  took out "***EOF***" line from end of file.
01d,10oct97,jpd  Tidied L$_ usage.
01c,18sep97,jpd  Changed 810 code in line with ARM 810 errata sheet.
		 Added use of sysCacheFlushReadArea on SA-110. Added
		 cacheIMBRange(). Only use cacheArchIntMask in long
		 cache operations.  Added soft-copy of MMU CR on 710A.
		 Changed .aligns to .baligns.  Corrected error in use
		 of cacheArchIntMask and made L$_cacheArchIntMask
		 declaration not specific to ARMSA110.
01b,20feb97,jpd  tidied comments/documentation.
01a,18oct96,jpd  written, based on 68K version 01p.
*/

/*
DESCRIPTION
This library contains routines to control ARM Ltd.'s caches.

N.B.
Although this library contains code written for the ARM810 CPU, at the time
of writing, this code has not been tested fully on that CPU.
YOU HAVE BEEN WARNED.

INTERNAL
TO keep these routines as efficient as possible, they no longer all generate
stack frames.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib,
.I "ARM Architecture Reference Manual,"
.I "ARM 710A Data Sheet,"
.I "ARM 810 Data Sheet,"
.I "ARM 940T Technical Reference Manual,"
.I "ARM 946E-S Technical Reference Manual,"
.I "ARM 740T Data Sheet,"
.I "ARM 720T Data Sheet,"
.I "ARM 920T Technical Reference Manual,"
.I "ARM 926EJ-S Technical Reference Manual,"
.I "ARM 1020E Technical Reference Manual,"
.I "ARM 1022E Technical Reference Manual,"
.I "Digital Semiconductor SA-110 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1100 Microprocessor Technical Reference Manual,"
.I "Digital Semiconductor SA-1500 Mediaprocessor Data Sheet."

*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "cacheLib.h"
#include "arch/arm/mmuArmLib.h"

	.data
	.globl  FUNC(copyright_wind_river)
	.long   FUNC(copyright_wind_river)

	/* globals */

#ifndef ARMCACHE
#error ARMCACHE not defined
#endif

#if (ARMCACHE == ARMCACHE_1020E)
#define ARMCACHE_1020E_REV0_DRAIN_WB TRUE
#define ARMCACHE_1020E_REV0_MCR_CP15 TRUE
#else
#define ARMCACHE_1020E_REV0_DRAIN_WB FALSE
#define ARMCACHE_1020E_REV0_MCR_CP15 FALSE
#endif

/*
 * Only the following processors are supported by this library. Others
 * should not be assembling this file, but, if they do, ensure they get no code.
 */

#if ((ARMCACHE == ARMCACHE_710A)   || (ARMCACHE == ARMCACHE_720T)   || \
     (ARMCACHE == ARMCACHE_740T)   || (ARMCACHE == ARMCACHE_810)    || \
     (ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  |  (ARMCACHE == ARMCACHE_1022E))


#if ((ARMCACHE == ARMCACHE_810)    || (ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))

	/* Not needed on 710A, 740T, 720T, as they are write-through */

	.globl	FUNC(cacheDFlush)		/* Flush D-cache entry */
	.globl	FUNC(cacheDFlushAll)		/* Flush D-cache and drain W/B */
#endif

	.globl	FUNC(cacheDInvalidateAll)	/* Invalidate all D-cache */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))

	/* not supported on 710A, 810, 940T, 740T, 720T */

	.globl	FUNC(cacheDInvalidate)	/* Invalidate D-cache entry */
#endif

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
	.globl	FUNC(cacheIInvalidateAll)	/* Invalidate all I-cache */
#endif

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E) || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E) || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E) || \
     (ARMCACHE == ARMCACHE_1022E))
	.globl	FUNC(cacheIInvalidate)	/* Invalidate I-cache entry */
#if (ARMCACHE == ARMCACHE_XSCALE)
        .globl  FUNC(btbInvalidate)          /* Invalidate BTB */
#endif
#endif

	.globl	FUNC(cacheDClearDisable)	/* Clear, disable D-cache, W/B */

#if ((ARMCACHE == ARMCACHE_810)    || (ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
	/* not supported on 710A, 740T, 720T */

	.globl	FUNC(cacheDClear)		/* Clear D-cache entry */
#endif

	.globl	FUNC(cacheDClearAll)		/* Clear D-cache, drain W/B */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))

	/* not supported on 710A, 810, 740T, 720T */

	.globl	FUNC(cacheIClearDisable)	/* Disable and clear I-cache */
#endif

	.globl	FUNC(cacheArchPipeFlush)	/* Drain Write buffer */

#if ARMCACHE_NEEDS_IMB
	.globl	FUNC(cacheIMB)		/* Execute IMB to flush Prefetch Unit */
	.globl	FUNC(cacheIMBRange)		/* IMBRange to flush some of PU */
#endif

#if ((ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
	.globl	FUNC(cacheIdentify)		/* Get types/sizes of caches fitted */
#endif /* (ARMCACHE == ARMCACHE_926E,946E,1020E,1022E) */

#if (ARMCACHE == ARMCACHE_XSCALE)

	/* currently only supported by XScale platform */

	.globl  FUNC(cacheIFetchNLock)       /* fetch and lock instruction cache line */
	.globl  FUNC(cacheIUnLock)           /* unlock instruction cache */
	.globl  FUNC(cacheDSetLockMode)      /* set data cache lock mode */
	.globl  FUNC(cacheDLockRead)         /* read data cache lock mode */
	.globl  FUNC(cacheDUnLock)           /* ignore mode, unlock data cache */

	.globl  FUNC(tlbILock)               /* translate and lock instruction TLB entry */
	.globl  FUNC(tlbIUnLock)             /* unlock instruction TLB entry */
	.globl  FUNC(tlbDLock)               /* translate and lock data TLB entry */
	.globl  FUNC(tlbDUnLock)             /* unlock data TLB entry */

	.globl FUNC(cacheCreateInternalDataRAM) /* cache as Internal Data RAM */
	.globl FUNC(cacheLockDataIntoDataCache) /* allow the ability to lock data into data cache */

#endif

	/* externals */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))
	/*
	 * Address of (declared in BSP) a readable, cached block of
	 * address space used for nothing else, which we will read to
	 * force the D-cache to be written out to memory.  If the BSP has
	 * an area of the address space which is usable for this purpose,
	 * which does not actually contain memory, it should set the
	 * address to that area. If it does not, it should allocate some
	 * RAM for this. In either case, the area must be marked as
	 * readable and cacheable in the page tables.
	 */

	.extern	FUNC(sysCacheFlushReadArea)

#endif /* ARMCACHE == ARMCACHE_SA110,SA1100,SA1500,XSCALE */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))
	/*
	 * Same for the minicache. The area must be marked as readable
	 * and minicacheable in the page tables.
	 */

	.extern	FUNC(sysMinicacheFlushReadArea)
#endif /* ARMCACHE == SA110,SA1100,SA1500,XSCALE */

#if ((ARMCACHE == ARMCACHE_926E) || (ARMCACHE == ARMCACHE_940T))
        /*
         * All ARM 926E and 940T BSPs, must define the variable
         * sysCacheUncachedAdrs which contains the address of a word that
         * is uncached and is safe to read (i.e. has no side effects).
         *
         * On 940T, this is used by the cacheLib code to perform a read
         * (only) to drain the write-buffer. Clearly this address must be
         * present within one of the valid regions, where it must be marked as
         * non-cacheable.
         *
         * On 926E, this is used to synchronise the data and
         * instruction streams in Level 2 AHB subsystems. The address
         * must be marked as valid and non-cacheable,
         */

        .extern FUNC(sysCacheUncachedAdrs)

#endif /* ARMCACHE == ARMCACHE_926E, 940T */

#if ((ARMCACHE == ARMCACHE_946E) || (ARMCACHE == ARMCACHE_1020E) || \
     (ARMCACHE == ARMCACHE_1022E))
	.extern FUNC(cacheArchIndexMask)	/* mask to get index number from adrs */
#endif /* (ARMCACHE == ARMCACHE_946E,1020E,1022E) */

#if (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
        .extern  FUNC(cacheArchSegMask)       /* mask to get segment num from adrs */
#endif /* (ARMCACHE == ARMCACHE_1020E,1022E) */


#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T) || (ARMCACHE == ARMCACHE_810))

	/* variables */

	.data
	.balign	1

	/* variable used with a SWPB instruction to drain the write-buffer */

FUNC_LABEL(_cacheSwapVar)	.byte	0

#endif /* ARMCACHE == ARMCACHE_710A, 720T, 740T, 810 */


	.text
	.balign	4

/******************************************************************************/

/* PC-relative-addressable symbols - LDR Rn, =sym was (is?) broken */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))

L$_sysCacheFlushReadArea:
	.long	FUNC(sysCacheFlushReadArea)

#endif /* ARMCACHE == ARMCACHE_SA110,SA1100,SA1500,XSCALE */

#if ((ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_XSCALE))
L$_sysMinicacheFlushReadArea:
	.long	FUNC(sysMinicacheFlushReadArea)

#endif /* ARMCACHE == SA1100,SA1500,XSCALE */

#if ((ARMCACHE == ARMCACHE_926E) || (ARMCACHE == ARMCACHE_940T))

L$_sysCacheUncachedAdrs:
	.long	FUNC(sysCacheUncachedAdrs)

#endif /* ARMCACHE == ARMCACHE_926E, 940T */

L$_cacheArchIntMask:
	.long	FUNC(cacheArchIntMask)

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T) || (ARMCACHE == ARMCACHE_810))

L$_cacheSwapVar:
	.long	FUNC(_cacheSwapVar)

#endif

#if (ARMCACHE == ARMCACHE_710A)

L$_mmuCrValue:
	.long	FUNC(_mmuCrValue)

#endif
#if ((ARMCACHE == ARMCACHE_946E) || (ARMCACHE == ARMCACHE_1020E) || \
     (ARMCACHE == ARMCACHE_1022E))
L$_cacheArchIndexMask:
	.long	FUNC(cacheArchIndexMask)	/* mask to get index number from adrs */
#endif /* (ARMCACHE == ARMCACHE_946E,1020E,1022E) */

#if (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
L$_cacheArchSegMask:
        .long   FUNC(cacheArchSegMask)       /* mask to get segment num from adrs */
#endif /* (ARMCACHE == ARMCACHE_1020E,1022E) */

/*******************************************************************************
*
* cacheDClearDisable - clear, flush, disable D-cache and Write buffer (ARM)
*
* This routine clears (flushes and invalidates) and disables the D-cache,
* disables the write-buffer and drains it.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDClearDisable (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDClearDisable)

/*
 * Most CPUs will need their caches cleared, the 710, 740T, 720T just
 * needs the W/B drained. We must close any window between cleaning and
 * invalidating the caches and disabling them (as best we can).
 */

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) ||\
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))
	LDR	r0, L$_sysCacheFlushReadArea
	ADD	r1, r0, #D_CACHE_SIZE

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2

0:
	LDR	r2, [r0], #_CACHE_ALIGN_SIZE /* Displace cache entries */
	TEQS	r1, r0			/* Reached end of buffer? */
	BNE	0b			/* Branch if not */
#endif

#if ((ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_XSCALE))
	LDR	r0, L$_sysMinicacheFlushReadArea
	ADD	r1, r0, #MINI_CACHE_SIZE

1:
	LDR	r2, [r0], #MINI_CACHE_LINE_SIZE /* Displace minicache entries */
	TEQS	r1, r0			/* Reached end of buffer? */
	BNE	1b			/* Branch if not */
#endif

#if (ARMCACHE == ARMCACHE_810)
	MOV	r1, #63			/* 64 indices to clean */

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2
5:
	MOV	r2, #(7<<4)		/* 8 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c11, 1 /* Clean ID-cache entry */
	SUBS	r2, r2, #(1<<4)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned */
#endif

#if (ARMCACHE == ARMCACHE_940T)
	MOV	r1, #63			/* 64 indices to clean */

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2
5:
	MOV	r2, #(3<<4)		/* 4 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c14, 1 /* Clean & invalidate D-cache entry */
	SUBS	r2, r2, #(1<<4)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned and
					 * invalidated */
#endif

#if (ARMCACHE == ARMCACHE_946E)
	LDR	r1, L$_cacheArchIndexMask /* Get ptr to index mask */
	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r1, [r1]		/* num indices to clean - 1 shifted */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2
5:
	MOV	r2, #(3<<30)		/* 4 segments */
6:
	ORR	r0, r2, r1		/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c14, 2 /* Clean & invalidate D-cache entry */
	SUBS	r2, r2, #(1<<30)	/* step on to next segment */
	BHS	6b			/* branch if not done all segs */
	SUBS	r1, r1, #(1<<5)		/* step on to next index */
	BHS	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned and
					 * invalidated */
	MOV	r0, #0			/* Data SBZ */
	MCR	CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */
#endif /* (ARMCACHE == ARMCACHE_946E) */

#if (ARMCACHE == ARMCACHE_920T)
	MOV	r1, #63			/* 64 indices to clean */

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2
5:
	MOV	r2, #(7<<5)		/* 8 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c14, 2 /* Clean & invalidate D-cache entry */
	SUBS	r2, r2, #(1<<5)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned and
					 * invalidated */
	/* Ensure victim pointer does not point to locked entries */

	MRC	CP_MMU, 0, r0, c9, c0, 0  /* Read D-cache lockdown base */
	MCR	CP_MMU, 0, r0, c9, c0, 0  /* Write D-cache lockdown base */

	MOV	r0, #0			/* Data SBZ */
	MCR	CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */


#endif /* (ARMCACHE == ARMCACHE_920T) */

#if (ARMCACHE == ARMCACHE_926E)
        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

5:
        MRC     CP_MMU, 0, pc, c7, c14, 3  /* test, clean & invalidate */
        BNE     5b                      /* branch if dirty */

        MOV     r0, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */
#endif /* (ARMCACHE == ARMCACHE_926E)   */

#if (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
        LDR     r1, L$_cacheArchIndexMask /* Get ptr to index mask */
        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     ip, L$_cacheArchSegMask /* Get pointer to segment mask */
        LDR     r1, [r1]                /* num indices to clean - 1 shifted */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        LDR     ip, [ip]                /* get num segs to clean -1 shifted */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2
#if ARMCACHE_1020E_REV0_DRAIN_WB        /* Rev 0 errata */
        MOV     r0, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */
#endif /* ARMCACHE_1020E_REV0_DRAIN_WB */
5:
        MOV     r2, ip                  /* max num segments */
6:
        ORR     r0, r2, r1              /* Create Index, Seg format */
        MCR     CP_MMU, 0, r0, c7, c14, 2 /* Clean & invalidate D-cache entry */
#if ARMCACHE_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif
        SUBS    r2, r2, #(1<<5)         /* step on to next segment */
        BHS     6b                      /* branch if not done all segs */
        SUBS    r1, r1, #(1<<26)        /* step on to next index */
        BHS     5b                      /* branch if not done all indices */
                                        /* All Index, Seg entries cleaned and
                                         * invalidated */
        MOV     r0, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */
#endif /* (ARMCACHE == ARMCACHE_1020E,1022E) */


/* All D-cache has now been cleaned (written to memory) */

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T))
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, #I_BIT | F_BIT	/* disable all interrupts */
	MSR	cpsr, r2

	LDR	r0, L$_cacheSwapVar	/* R0 -> FUNC(_cacheSwapVar) */
	SWPB	r1, r1, [r0]		/* Drain write-buffer */
#if (ARMCACHE == ARMCACHE_720T)
	MOV	r0, #0
	MCR	CP_MMU, 0, r0, c7, c7, 0 /* Flush (invalidate) all ID-cache */
#else
	MCR	CP_MMU, 0, r0, c7, c0, 0 /* Flush (invalidate) all ID-cache */
#endif
#endif /* (710A, 720T, 740T) */

#if (ARMCACHE == ARMCACHE_810)

	LDR	r0, L$_cacheSwapVar	/* R0 -> FUNC(_cacheSwapVar) */
	SWPB	r1, r1, [r0]		/* Drain write-buffer */

	MOV	r0, #0
	MCR	CP_MMU, 0, r0, c7, c7, 0 /* Flush (invalidate) all ID-cache */

#endif

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))
	MCR	CP_MMU, 0, r0, c7, c10, 4   /* Drain write-buffer */

	MCR	CP_MMU, 0, r0, c7, c6, 0    /* Flush (invalidate) all D-cache */
#endif

#if (ARMCACHE == ARMCACHE_940T)

	LDR	r0, L$_sysCacheUncachedAdrs
	LDR	r0, [r0]		/* R0 -> uncached area */
	LDR	r0, [r0]		/* Drain write-buffer */

	/* no need to invalidate, as we used the clean and invalidate op */
#endif /* ARMCACHE == ARMCACHE_940T */


#if (ARMCACHE == ARMCACHE_710A)
	LDR	ip, L$_mmuCrValue	/* Get pointer to soft-copy */
	LDR	r2, [ip]		/* Load soft copy */
#else
	MRC	CP_MMU, 0, r2, c1, c0, 0 /* Read control register into R2 */
#endif

/* Disable D-cache and write-buffer */

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
        /* on 920T,926E,940T,946E,XSCALE,1020E W bit is Should Be One (SBO) */

	BIC	r2, r2, #MMUCR_C_ENABLE
#else
	BIC	r2, r2, #MMUCR_C_ENABLE | MMUCR_W_ENABLE
#endif

#if (ARMCACHE == ARMCACHE_710A)
	STR	r2, [ip]		/* Store soft-copy */
#endif

	MCR	CP_MMU, 0, r2, c1, c0, 0 /* Write control register */
#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
#endif

	MSR	cpsr, r3		/* Restore interrupt state */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#if ((ARMCACHE == ARMCACHE_810)    || (ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))

/* Not needed on 710A, 720T, 740T as cacheArchLib just drains W/B instead */
/*******************************************************************************
*
* cacheDFlush - flush D-cache entry (ARM)
*
* This routine flushes (writes to memory) an entry in the Data Cache.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDFlush
*     (
*     void *	addr	/@ virtual address to be flushed @/
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDFlush)

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
#if ARMCACHE_1020E_REV0_DRAIN_WB        /* Rev 0 errata */
        MOV     r1, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r1, c7, c10, 4 /* Drain write-buffer */
#endif /* ARMCACHE_1020E_REV0_DRAIN_WB */

	MCR	CP_MMU, 0, r0, c7, c10, 1 /* Clean D-cache entry using VA */

#if ARMCACHE_1020E_REV0_DRAIN_WB        /* Rev 0 errata */
        MCR     CP_MMU, 0, r1, c7, c10, 4 /* Drain write-buffer */
#endif /* ARMCACHE_1020E_REV0_DRAIN_WB */

#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */
#endif

#if (ARMCACHE == ARMCACHE_810)
	AND	r0, r0, #0x70		/* r0 now contains segment number */
					/* in which addr will be cached */
	MOV	r1, #63			/* 64 indices to clean */
1:
	ORR	r2, r0, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r2, c7, c11, 1 /* Clean ID-cache entry */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	1b			/* branch if not done all indices */
#endif

#if (ARMCACHE == ARMCACHE_940T)
	AND	r0, r0, #0x30		/* r0 now contains segment number */
					/* in which addr will be cached */
	MOV	r1, #63			/* 64 indices to clean */
1:
	ORR	r2, r0, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r2, c7, c10, 1 /* Clean D-cache entry */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	1b			/* branch if not done all indices */
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif /* (ARMCACHE == ARMCACHE_810,SA*,920T,926E,940T,946E,XSCALE,1020E,1022E) */

#if ((ARMCACHE == ARMCACHE_810)    || (ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
/*******************************************************************************
*
* cacheDFlushAll - flush all D-cache (ARM)
*
* This routine flushes (writes out to memory) the Data Cache, and drains the
* write-buffer.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDFlushAll (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDFlushAll)

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))
	/*
	 * The following method works by displacing entries as the
	 * StrongArm cache is LRU. 810 is random replacement.
	 */

	LDR	r0, L$_sysCacheFlushReadArea
	ADD	r1, r0, #D_CACHE_SIZE	/* End of buffer to read */
0:
	LDR	r2, [r0], #_CACHE_ALIGN_SIZE /* Displace cache entries */
	TEQS	r1, r0			/* Reached end of buffer? */
	BNE	0b			/* Branch if not */
					/* All D-cache has now been cleaned */
					/* (written to memory) */
#endif

#if ((ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_XSCALE))
	LDR	r0, L$_sysMinicacheFlushReadArea
	ADD	r1, r0, #MINI_CACHE_SIZE
1:
	LDR	r2, [r0], #MINI_CACHE_LINE_SIZE /* Displace minicache entries */
	TEQS	r1, r0			/* Reached end of buffer? */
	BNE	1b			/* Branch if not */
#endif

#if (ARMCACHE == ARMCACHE_810)
	MOV	r1, #63			/* 64 indices to clean */
5:
	MOV	r2, #(7<<4)		/* 8 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c11, 1 /* Clean ID-cache entry */
	SUBS	r2, r2, #(1<<4)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned */
#endif /* (ARMCACHE == ARMCACHE_810) */

#if (ARMCACHE == ARMCACHE_940T)
	MOV	r1, #63			/* 64 indices to clean */
5:
	MOV	r2, #(3<<4)		/* 4 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c10, 1 /* Clean D-cache entry */
	SUBS	r2, r2, #(1<<4)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned */
#endif /* (ARMCACHE == ARMCACHE_940T) */

#if (ARMCACHE == ARMCACHE_946E)
	LDR	r1, L$_cacheArchIndexMask /* Get ptr to num of lines - 1 */
	LDR	r1, [r1]		/* number of indices to clean */
5:
	MOV	r2, #(3<<30)		/* 4 segments */
6:
	ORR	r0, r2, r1		/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c10, 2 /* Clean D-cache entry */
	SUBS	r2, r2, #(1<<30)	/* step on to next segment */
	BHS	6b			/* branch if not done all segs */
	SUBS	r1, r1, #(1<<5)		/* step on to next index */
	BHS	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned */
#endif /* (ARMCACHE == ARMCACHE_946E) */

#if (ARMCACHE == ARMCACHE_920T)
	MOV	r1, #63			/* 64 indices to clean */
5:
	MOV	r2, #(7<<5)		/* 8 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c10, 2 /* Clean D-cache entry */
	SUBS	r2, r2, #(1<<5)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned */
	/* Ensure victim pointer does not point to locked entries */

	MRC	CP_MMU, 0, r0, c9, c0, 0  /* Read D-cache lockdown base */
	MCR	CP_MMU, 0, r0, c9, c0, 0  /* Write D-cache lockdown base */
#endif /* (ARMCACHE == ARMCACHE_920T) */

#if (ARMCACHE == ARMCACHE_926E)
5:
        MRC     CP_MMU, 0, pc, c7, c10, 3  /* test, & clean */
        BNE     5b                      /* branch if dirty */
#endif /* (ARMCACHE == ARMCACHE_926E) */

#if (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
#if ARMCACHE_1020E_REV0_DRAIN_WB        /* Rev 0 errata */
        MOV     r0, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */
#endif /* ARMCACHE_1020E_REV0_DRAIN_WB */
        LDR     r1, L$_cacheArchIndexMask /* Get ptr to index mask */
        LDR     r3, L$_cacheArchSegMask /* Get pointer to segment mask */
        LDR     r1, [r1]                /* num indices to clean - 1 shifted */
        LDR     r3, [r3]                /* get num segs to clean -1 shifted */
5:
        MOV     r2, r3                  /* max num segments */
6:
        ORR     r0, r2, r1              /* Create Index, Seg format */
        MCR     CP_MMU, 0, r0, c7, c10, 2 /* Clean D-cache entry */

#if ARMCACHE_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */

        SUBS    r2, r2, #(1<<5)         /* step on to next segment */
        BHS     6b                      /* branch if not done all segs */
        SUBS    r1, r1, #(1<<26)        /* step on to next index */
        BHS     5b                      /* branch if not done all indices */
                                        /* All Index, Seg entries cleaned */
#endif /* (ARMCACHE == ARMCACHE_1020E,1022E) */

#if (ARMCACHE == ARMCACHE_810)
	LDR	r0, L$_cacheSwapVar	/* R0 -> FUNC(_cacheSwapVar) */
	SWPB	r1, r1, [r0]		/* Drain write-buffer */
#endif

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
     	MOV	r0, #0			    /* data SBZ */
#endif
	MCR	CP_MMU, 0, r0, c7, c10, 4   /* Drain write-buffer */
#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */
#endif

#if (ARMCACHE == ARMCACHE_940T)
	LDR	r0, L$_sysCacheUncachedAdrs
	LDR	r0, [r0]		/* R0 -> uncached area */
	LDR	r0, [r0]		/* Drain write-buffer */
#endif /* ARMCACHE == ARMCACHE_940T */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif /* (ARMCACHE == ARMCACHE_810,SA*,920T,926E,940T,946E,XSCALE,1020E,1022E) */

/*******************************************************************************
*
* cacheDInvalidateAll - invalidate D-cache (ARM)
*
* This routine invalidates all the Data Cache. On 710A/810/740T/720T this is
* the ID-cache.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDInvalidateAll (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDInvalidateAll)

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_740T))
	MCR	CP_MMU, 0, r0, c7, c0, 0 /* Flush (invalidate) all ID-cache */
					/* next two instructions could still */
	NOP				/* come from cache */
#endif/* (710A, 740T) */

#if ((ARMCACHE == ARMCACHE_810) || (ARMCACHE == ARMCACHE_720T))
	MOV	r0, #0			 /* Data SBZ */
	MCR	CP_MMU, 0, r0, c7, c7, 0 /* Flush (invalidate) all ID-cache */
	NOP
#endif

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
	MOV	r0, #0			/* Data SBZ */
#endif
	MCR	CP_MMU, 0, r0, c7, c6, 0 /* Flush (invalidate) all D-cache */
#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif


#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
/*
 * Not needed on 710A, 720T, 740T, as DInvalidateAll() used instead.
 * Not needed on 810, 940T as DClear used instead.
 */
/*******************************************************************************
*
* cacheDInvalidate - invalidate D-cache entry (ARM)
*
* This routine invalidates an entry in the Data Cache
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDInvalidate
*     (
*     void *	addr	/@ virtual address to be invalidated @/
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDInvalidate)

	MCR	CP_MMU, 0, r0, c7, c6, 1 /* Flush (invalidate) D-cache entry */
#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
/*******************************************************************************
*
* cacheIInvalidateAll - invalidate I-cache (ARM)
*
* This routine invalidates the Instruction Cache. On return, the I-cache will
* only still be empty if this routine is called with the I-cache off.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheIInvalidateAll (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheIInvalidateAll)

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
	MOV	r0, #0			/* Data SBZ */
#endif
#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */
	MCR	CP_MMU, 0, r0, c7, c5, 0 /* Flush (invalidate) I-cache */

#if (ARMCACHE == ARMCACHE_XSCALE)
        /* assure that CP15 update takes effect */
        MRC     CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r0, r0                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */
#else
	/*
	 * The next four instructions could still come from the I-cache
	 * (2 on the 940T, 3 on 920T). We also need to flush
	 * the prefetch unit, which will be done by the MOV pc, lr below.
	 */

#if ((ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500))
        NOP                             /* 4 */
        NOP                             /* 3 */
#endif
#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
        NOP                             /* 3 */
#endif
	NOP				/* 2 */
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr			/* 1 */
#endif
#endif /* ARMCACHE == SA110,1100,1500,920T,940T,926E,946E,XSCALE,1020E */

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
/*******************************************************************************
*
* cacheIInvalidate - invalidate I-cache entry (ARM)
*
* This routine invalidates an entry in the Instruction Cache.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheIInvalidate
*	(
*	void *	addr	/@ virtual address to be invalidated @/
*	)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheIInvalidate)

#if (ARMCACHE == ARMCACHE_940T)
	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2

	AND	r0, r0, #0x30		/* r0 now contains segment number */
					/* in which addr will be cached */
	MOV	r1, #63			/* 64 indices to clean */
1:
	ORR	r2, r0, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r2, c7, c5, 1 /* Invalidate I-cache entry */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	1b			/* branch if not done all indices */

	MSR	cpsr, r3		/* Restore interrupt state */
#endif /* (ARMCACHE == ARMCACHE_940T) */


#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE) || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
	/* Bits [0:4] of VA SBZ but will be, (called from cacheArchInvalidate)*/

	MCR	CP_MMU, 0, r0, c7, c5, 1 /* Invalidate I-cache entry */
#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */
#if (ARMCACHE == ARMCACHE_XSCALE)
        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r0, r0                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */
#endif

#endif /* (ARMCACHE == ARMCACHE_920T,926E,946E,XSCALE,1020E,1022E) */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif /* ARMCACHE == ARMCACHE_920T,940T,946E,XSCALE */

#if (ARMCACHE == ARMCACHE_XSCALE)
/*******************************************************************************
*
* btbInvalidate - invalidate Branch Target Buffer (ARM)
*
* This routine invalidates the Branch Target Buffer.
*
* NOTE: If software invalidates a line from the instruction cache and modifies
*       the same location in external memory, it needs to invalidate the BTB.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void btbInvalidate
* (
* void
* )
*/

_ARM_FUNCTION_CALLED_FROM_C(btbInvalidate)

	MCR	CP_MMU, 0, r0, c7, c5, 6 /* Invalidate BTB entry */

	/* assure that CP15 update takes effect */

	MRC	CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
	MOV	r0, r0			/* wait for it */
	SUB	pc, pc, #4		/* branch to next instruction */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif
#endif /* ARMCACHE == XSCALE */

/*******************************************************************************
*
* cacheDClearAll - clear all D-cache and drain Write Buffer (ARM)
*
* This routine clears (flushes and invalidates) all the Data Cache, and
* drains the write-buffer.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDClearAll (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDClearAll)

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))
	LDR	r0, L$_sysCacheFlushReadArea
	ADD	r1, r0, #D_CACHE_SIZE	/* End of buffer to read */

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2

0:
	LDR	r2, [r0], #_CACHE_ALIGN_SIZE /* Displace cache entries */
	TEQS	r1, r0			/* Reached end of buffer? */
	BNE	0b			/* Branch if not */

	/* All D-cache has now been cleaned (written to memory) */

#if ((ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_XSCALE))
	LDR	r0, L$_sysMinicacheFlushReadArea
	ADD	r1, r0, #MINI_CACHE_SIZE
1:
	LDR	r2, [r0], #MINI_CACHE_LINE_SIZE /* Displace minicache entries */
	TEQS	r1, r0			/* Reached end of buffer? */
	BNE	1b			/* Branch if not */
#endif
	MCR	CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */

	MCR	CP_MMU, 0, r0, c7, c6, 0 /* Flush (invalidate) D-cache */

	MSR	cpsr, r3		/* Restore interrupt state */
#endif

#if (ARMCACHE == ARMCACHE_810)
	MOV	r1, #63			/* 64 indices to clean */

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2
5:
	MOV	r2, #(7<<4)		/* 8 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c11, 1 /* Clean ID-cache entry */
	SUBS	r2, r2, #(1<<4)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned */

	LDR	r0, L$_cacheSwapVar	/* R0 -> FUNC(_cacheSwapVar) */
	SWPB	r1, r1, [r0]		/* Drain write-buffer */

	/* All cache is now cleaned */

	MOV	r0, #0
	MCR	CP_MMU, 0, r0, c7, c7, 0 /* Flush (invalidate) all ID-cache */

	MSR	cpsr, r3		/* Restore interrupt state */
#endif

#if (ARMCACHE == ARMCACHE_940T)
	MOV	r1, #63			/* 64 indices to clean */

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2
5:
	MOV	r2, #(3<<4)		/* 4 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c14, 1 /* Clean & invalidate D-cache entry */
	SUBS	r2, r2, #(1<<4)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned and
					 * invalidated */
	LDR	r0, L$_sysCacheUncachedAdrs
	LDR	r0, [r0]		/* R0 -> uncached area */
	LDR	r0, [r0]		/* drain write-buffer */

	MSR	cpsr, r3		/* Restore interrupt state */
#endif

#if (ARMCACHE == ARMCACHE_946E)
	LDR	r1, L$_cacheArchIndexMask /* Get ptr to index mask */
	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r1, [r1]		/* num of indices -1 shifted */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2
5:
	MOV	r2, #(3<<30)		/* 4 segments */
6:
	ORR	r0, r2, r1		/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c14, 2 /* Clean & invalidate D-cache entry */
	SUBS	r2, r2, #(1<<30)	/* step on to next segment */
	BHS	6b			/* branch if not done all segs */
	SUBS	r1, r1, #(1<<5)		/* step on to next index */
	BHS	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned and
					 * invalidated */
	MOV	r0, #0			/* Data SBZ */
	MCR	CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */

	MSR	cpsr, r3		/* Restore interrupt state */
#endif /* ARMCACHE_946E */

#if (ARMCACHE == ARMCACHE_920T)
	MOV	r1, #63			/* 64 indices to clean */

	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2
5:
	MOV	r2, #(7<<5)		/* 8 segments */
6:
	ORR	r0, r2, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r0, c7, c14, 2 /* Clean & invalidate D-cache entry */
	SUBS	r2, r2, #(1<<5)		/* step on to next segment */
	BPL	6b			/* branch if not done all segs */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	5b			/* branch if not done all indices */
					/* All Index, Seg entries cleaned and
					 * invalidated */
	/* Ensure victim pointer does not point to locked entries */

	MRC	CP_MMU, 0, r0, c9, c0, 0  /* Read D-cache lockdown base */
	MCR	CP_MMU, 0, r0, c9, c0, 0  /* Write D-cache lockdown base */

	MOV	r0, #0			/* Data SBZ */
	MCR	CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */

	MSR	cpsr, r3		/* Restore interrupt state */
#endif /* (ARMCACHE == ARMCACHE_920T) */

#if (ARMCACHE == ARMCACHE_926E)
        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2
5:
        MRC     CP_MMU, 0, pc, c7, c14, 3  /* test, clean & invalidate */
        BNE     5b                      /* branch if dirty */

        MOV     r0, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */

        MSR     cpsr, r3                /* Restore interrupt state */
#endif /* (ARMCACHE == ARMCACHE_926E) */

#if (ARMCACHE == ARMCACHE_1020E) || (ARMCACHE == ARMCACHE_1022E)
        LDR     r1, L$_cacheArchIndexMask /* Get ptr to index mask */
        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     ip, L$_cacheArchSegMask /* Get pointer to segment mask */
        LDR     r1, [r1]                /* num indices to clean - 1 shifted */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        LDR     ip, [ip]                /* get num segs to clean -1 shifted */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2
#if ARMCACHE_1020E_REV0_DRAIN_WB        /* Rev 0 errata */
        MOV     r0, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */
#endif /* ARMCACHE_1020E_REV0_DRAIN_WB */
5:
        MOV     r2, ip                  /* max num segments */
6:
        ORR     r0, r2, r1              /* Create Index, Seg format */
        MCR     CP_MMU, 0, r0, c7, c14, 2 /* Clean & invalidate D-cache entry */
#if ARMCACHE_1020E_REV0_MCR_CP15
        NOP
        NOP
#endif /* ARMCACHE_1020E_REV0_MCR_CP15 */
        SUBS    r2, r2, #(1<<5)         /* step on to next segment */
        BHS     6b                      /* branch if not done all segs */
        SUBS    r1, r1, #(1<<26)        /* step on to next index */
        BHS     5b                      /* branch if not done all indices */
                                        /* All Index, Seg entries cleaned and
                                         * invalidated */
        MOV     r0, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r0, c7, c10, 4 /* Drain write-buffer */

        MSR     cpsr, r3                /* Restore interrupt state */
#if ARMCACHE_1020E_REV0_MCR_CP15
        NOP
#endif /* ARMCACHE_1020E_REV0_MCR_CP15 */
#endif /* (ARMCACHE == ARMCACHE_1020E,1022E) */

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_740T))
	LDR	r0, L$_cacheSwapVar	/* R0 -> FUNC(_cacheSwapVar) */
	SWPB	r1, r1, [r0]		/* Drain write-buffer */
	MCR	CP_MMU, 0, r0, c7, c0, 0 /* Flush (invalidate) all ID-cache */
#endif

#if (ARMCACHE == ARMCACHE_720T)
	LDR	r0, L$_cacheSwapVar	/* R0 -> FUNC(_cacheSwapVar) */
	SWPB	r1, r1, [r0]		/* Drain write-buffer */
	MOV	r0, #0
	MCR	CP_MMU, 0, r0, c7, c7, 0 /* Flush (invalidate) all ID-cache */
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#if ((ARMCACHE == ARMCACHE_810)    || (ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500) || \
     (ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_940T)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))

/* Not supported on 710A, 740T, 720T */
/*******************************************************************************
*
* cacheDClear - clear (flush and invalidate) D-cache entry (ARM)
*
* This routine clears (flushes and invalidates) an entry in the Data Cache
*
* INTERNAL
* This routine is called from cacheArchLib, after which it drains the
* write buffer so there is no need to do it here.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDClear
*     (
*     void *	addr	/@ virtual address to be cleared @/
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDClear)

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_XSCALE))
	/*
	 * Other ARM CPUs have ints locked since they have to clean, then
	 * invalidate cache entries for addresses other than for the
	 * address specified. If on SA-110 you call this routine without
	 * ints locked, and other processes can be dirtying the address
	 * specified, then you are asking for trouble.
	 */

	MCR	CP_MMU, 0, r0, c7, c10, 1 /* Clean D-cache entry */
	MCR	CP_MMU, 0, r0, c7, c6, 1 /* Flush (invalidate) D-cache entry */
#endif /* (ARMCACHE == ARMCACHE_SA110,1100,1500) */

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
#if ARMCACHE_1020E_REV0_DRAIN_WB        /* Rev 0 errata */
        MOV     r1, #0                  /* Data SBZ */
        MCR     CP_MMU, 0, r1, c7, c10, 4 /* Drain write-buffer */
#endif /* ARMCACHE_1020E_REV0_DRAIN_WB */
        /*
         * Bits [0:4] SBZ, but will be, as this is called from
         * cacheArchClear(), which will have ANDed off those bits.
         */

        MCR     CP_MMU, 0, r0, c7, c14, 1 /* Clean and Inval D-cache entry */
#if ARMCACHE_1020E_REV0_DRAIN_WB        /* Rev 0 errata */
        MCR     CP_MMU, 0, r1, c7, c10, 4 /* Drain write-buffer */
#endif /* ARMCACHE_1020E_REV0_DRAIN_WB */
#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */
#endif /* (ARMCACHE == ARMCACHE_920T,926E,946E,1020E) */

#if (ARMCACHE == ARMCACHE_810)
	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2

	AND	r0, r0, #0x70		/* r0 now contains segment number */
					/* in which addr will be cached */
	MOV	r1, #63			/* 64 indices to clean */

1:
	ORR	r2, r0, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r2, c7, c11, 1 /* Clean ID-cache entry */
	MCR	CP_MMU, 0, r2, c7, c7, 1 /* Invalidate ID-cache entry */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	1b			/* branch if not done all indices */

	MSR	cpsr, r3		/* Restore interrupt state */
#endif /* ARMCACHE == ARMCACHE_810) */

#if (ARMCACHE == ARMCACHE_940T)
	LDR	r2, L$_cacheArchIntMask	/* Get pointer to cacheArchIntMask */
	LDR	r2, [r2]		/* get cacheArchIntMask */
	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, r2		/* disable interrupts */
	MSR	cpsr, r2

	AND	r0, r0, #0x30		/* r0 now contains segment number */
					/* in which addr will be cached */
	MOV	r1, #63			/* 64 indices to clean */
1:
	ORR	r2, r0, r1, LSL #26	/* Create Index, Seg format */
	MCR	CP_MMU, 0, r2, c7, c14, 1 /* Clean & invalidate D-cache entry */
	SUBS	r1, r1, #1		/* step on to next index */
	BPL	1b			/* branch if not done all indices */

	MSR	cpsr, r3		/* Restore interrupt state */
#endif

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif /* (ARMCACHE == 810,SA110,1100,1500,920T,926E,940T,946E,XSCALE,1020E,1022E) */

#if ((ARMCACHE == ARMCACHE_SA110)   || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500)  || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_940T)    || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_XSCALE)  || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
/*******************************************************************************
*
* cacheIClearDisable - disable and clear I-cache (ARM)
*
* This routine disables and clears (flushes and invalidates) the Instruction
* Cache.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheIClearDisable (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheIClearDisable)

	MRS	r3, cpsr		/* Get CPSR */
	ORR	r2, r3, #I_BIT | F_BIT	/* disable all interrupts */
	MSR	cpsr, r2

	MRC	CP_MMU, 0, r2, c1, c0, 0 /* Read control register */
	BIC	r2, r2, #MMUCR_I_ENABLE	 /* Disable I-cache */
	MCR	CP_MMU, 0, r2, c1, c0, 0 /* Write control register */

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)    || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_1020E)   || \
     (ARMCACHE == ARMCACHE_1022E))
	MOV	r0, #0			/* data SBZ */
#endif
	MCR	CP_MMU, 0, r0, c7, c5, 0 /* Flush (invalidate) all I-cache */

#if (ARMCACHE == ARMCACHE_XSCALE)
        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r0, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r0, r0                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */
#else

	/*
	 * The next four instructions could still come from the I-cache (2 on
	 * the 940T, 3 on 920T). We also need to flush the prefetch unit,
	 * which will be done by the MOV pc, lr below, (or any interrupt).
	 */

#if ((ARMCACHE == ARMCACHE_SA110)  || \
     (ARMCACHE == ARMCACHE_SA1100) || (ARMCACHE == ARMCACHE_SA1500))
	NOP				/* 4 */
	NOP				/* 3 */
#endif

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)    || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
	NOP				/* 3 */
#endif
	NOP				/* 2 */
#endif /* (ARMCACHE == ARMCACHE_XSCALE) */
	MSR	cpsr, r3		/* 1. Restore interrupt state */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#endif /* ARMCACHE == SA110,1100,1500,920T,926E,940T,946E,XSCALE,1020E,1022E */

/*******************************************************************************
*
* cacheArchPipeFlush - drain Write Buffer (ARM)
*
* This routine drains the write-buffer.
*
* NOMANUAL
*
* RETURNS: N/A
*
* SEE ALSO:
* .I "ARM Architecture Reference"
*
* void cacheArchPipeFlush (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheArchPipeFlush)

#if ((ARMCACHE == ARMCACHE_SA110)  || (ARMCACHE == ARMCACHE_SA1100) || \
     (ARMCACHE == ARMCACHE_SA1500) || (ARMCACHE == ARMCACHE_920T)   || \
     (ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_XSCALE) || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
        /* On later cache/MMUs there is an explicit MMU op to do this */

#if ((ARMCACHE == ARMCACHE_920T)   || (ARMCACHE == ARMCACHE_926E)   || \
     (ARMCACHE == ARMCACHE_946E)   || (ARMCACHE == ARMCACHE_1020E)  || \
     (ARMCACHE == ARMCACHE_1022E))
        MOV     r0, #0                          /* Data SBZ */
#endif
        MCR     CP_MMU, 0, r0, c7, c10, 4       /* Drain write-buffer */
#if ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15)
        NOP
        NOP
#endif /* ((ARMCACHE == ARMCACHE_1020E) && ARMCACHE_1020E_REV0_MCR_CP15) */

#endif /* (ARMCACHE == ARMCACHE_SA*,920T,926E,946E,XSCALE,1020E,1022E) */

#if ((ARMCACHE == ARMCACHE_710A) || (ARMCACHE == ARMCACHE_720T) || \
     (ARMCACHE == ARMCACHE_740T) || (ARMCACHE == ARMCACHE_810))
	/*
	 * On 710A/810, there is no explicit MMU op to do this. However
	 * a SWPB (read-lock-write instruction) always acts as an
	 * unbuffered write. Strict ordering of read and write operations
	 * is preserved on 710A/810/740T/720T/710T, so any external read e.g.
	 * uncacheable read or unbuffered write will stall until the
	 * write buffer has drained.
	 */

	LDR	r0, L$_cacheSwapVar		/* R0 -> FUNC(_cacheSwapVar) */
	SWPB	r1, r1, [r0]
#endif

#if (ARMCACHE == ARMCACHE_926E)
        /*
         * On ARM 926E, we have already drained the write-buffer itself above
         * via the MMU co-proc to do this. However, in addition to this, at
         * the sort of times that we drain the write-buffer, we also may need
         * to synchronise the data and instruction streams in Level 2 AHB
         * subsystems after draining the write-buffer.
         */

        LDR     r1, L$_sysCacheUncachedAdrs
        LDR     r1, [r1]                /* R1 -> uncached area */
        LDR     r1, [r1]                /* synchronise I and D streams */
#endif /* (ARMCACHE == ARMCACHE_926E) */

#if (ARMCACHE == ARMCACHE_940T)
	/*
	 * On 940T, there is no explicit MMU op to do this and the
	 * special pleading in the 710A/810 etc. is also absent. However,
	 * any read from an uncached area will stall until the
	 * write-buffer has been drained.
	 */

	LDR	r0, L$_sysCacheUncachedAdrs
	LDR	r0, [r0]		/* R0 -> uncached area */
	LDR	r0, [r0]		/* drain write-buffer */
#endif /* (ARMCACHE == ARMCACHE_940T) */


#if ((ARMCACHE != ARMCACHE_920T)   && (ARMCACHE != ARMCACHE_926E)   && \
     (ARMCACHE != ARMCACHE_946E)   && (ARMCACHE != ARMCACHE_1020E)  && \
     (ARMCACHE != ARMCACHE_1022E))
        /* Already done it above on these caches, before MMU op */

        MOV     r0, #OK                 /* should return STATUS, SPR #22258 */
#endif /* (ARMCACHE != ARMCACHE_920T,926E,946E,1020E,1022E) */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif

#if ARMCACHE_NEEDS_IMB
/*******************************************************************************
*
* cacheIMB - issue Instruction Memory Barrier (IMB) instruction (ARM)
*
* This routine executes an Instruction Memory Barrier instruction to flush the
* Prefetch Unit on the ARM810.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheIMB (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheIMB)


	STMFD	sp!, {lr}	/* The SWI will overwrite LR */

	SWI	0xF00000

#if (ARM_THUMB)
	LDMFD	sp!, {lr}
	BX	lr
#else
	LDMFD	sp!, {pc}
#endif

/*******************************************************************************
*
* cacheIMBRange - issue IMBRange instruction (ARM)
*
* This routine executes an Instruction Memory Barrier Range instruction
* to flush some of the Prefetch Unit on the ARM810.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheIMBRange (INSTR * startAddr, INSTR * endAddr)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheIMBRange)

	STMFD	sp!, {lr}

	SWI	0xF00001

#if (ARM_THUMB)
	LDMFD	sp!, {lr}
	BX	lr
#else
	LDMFD	sp!, {pc}
#endif

#endif /* ARMCACHE_NEEDS_IMB */

#if ((ARMCACHE == ARMCACHE_926E)   || (ARMCACHE == ARMCACHE_946E)   || \
     (ARMCACHE == ARMCACHE_1020E)  || (ARMCACHE == ARMCACHE_1022E))
/*******************************************************************************
*
* cacheIdentify - identify type and size of cache(s) fitted (ARM)
*
* This routine reads the MMU register to determine the type(s) and
* size(s) of cache(s) fitted.
*
* NOMANUAL
*
* RETURNS: coded value indicating information about the cache(s).
*
* UINT32 cacheIdentify (void)
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheIdentify)

	MRC	CP_MMU, 0, r0, c0, c0, 1

	/* Return, with value read in R0 */

#if (ARM_THUMB)
	BX	lr
#else
	MOV	pc, lr
#endif
#endif /* (ARMCACHE == 926E,946E,1020E,1022E) */

#if (ARMCACHE == ARMCACHE_XSCALE)
/*******************************************************************************
*
* cacheIFetchNLock - fetch and lock instruction cache line
*
* This routine will fetch and lock instruction cache line.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheIFetchNLock
*     (
*     void *    addr    /@ virtual address to be locked @/
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheIFetchNLock)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

        /*
	 * The I-cache must be invalidated prior to locking down lines:
         * invalidate the insruction cache and branch target buffer
	 */

	MCR     CP_MMU, 0, r0, c7, c5, 0

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        /* the entry to lock is specified by the virtual address in R0 */

	MCR     CP_MMU, 0, r0, c9, c1, 0 /* fetch and lock i-cache line */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
	BX      lr
#else
	MOV     pc, lr
#endif

/*******************************************************************************
*
* cacheIUnLock - unlock instruction cache
*
* This routine will unlock instruction cache.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheIUnLock
*     (
*     void
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheIUnLock)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

	MCR     CP_MMU, 0, r0, c9, c1, 1 /* unlock i-cache */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
	BX      lr
#else
	MOV     pc, lr
#endif

/*******************************************************************************
*
* cacheDSetLockMode - set data cache lock register mode.
*
* This routine will set data cache lock mode.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDSetLockMode
*     (
*     UINT32 lock_mode
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDSetLockMode)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

        /* drain pending loads and stores */

	MCR     CP_MMU, 0, r0, c7, c10, 4 /* drain */

        /*
         * 0 = no locking occurs
	 * 1 = any fill into the data cache while this bit is set gets locked in
         */

	MCR     CP_MMU, 0, r0, c9, c2, 0 /* lock d-cache */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
	BX      lr
#else
	MOV     pc, lr
#endif

/*******************************************************************************
*
* cacheDLockRead - read data cache lock register mode.
*
*
* NOMANUAL
*
* RETURNS: N/A
*
* UINT32 cacheDLockRead
*     (
*     void
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDLockRead)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r1-r3}             /* save r1-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

	MRC     CP_MMU, 0, r0, c9, c2, 0 /* read d-cache lock register */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

	AND     r0, r0, #0x1             /* wipe reserved bits to zero */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r1-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
	BX      lr
#else
	MOV     pc, lr
#endif

/*******************************************************************************
*
* cacheDUnLock - ignore mode, unlock data cache
*
* This routine will unlock data cache.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheDUnLock
*     (
*     void
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheDUnLock)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

	MCR     CP_MMU, 0, r0, c9, c2, 1 /* unlock d-cache */

        MCR     CP_MMU, 0, r0, c7, c10, 4   /* Drain write-buffer */
        MCR     CP_MMU, 0, r0, c7, c6, 0    /* Flush (invalidate) all D-cache */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
	BX      lr
#else
	MOV     pc, lr
#endif

/*******************************************************************************
*
* tlbILock - translate and lock instruction TLB entry
*
* This routine will lock down entry in instruction TLB.
*
* May need software to disable interrupts - to prevent TLB from caching
* a translation that is about to be locked...
*
* NOMANUAL
*
* RETURNS: N/A
*
* void tlbILock
*     (
*     void *    addr    /@ virtual address to be locked @/
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(tlbILock)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

        /* the entry to lock is specified by the virtual address in R0 */

        MCR     CP_MMU, 0, r0, c8, c5, 0  /* invalidate all I-TLB */
        MCR     CP_MMU, 0, r0, c10, c4, 0 /* translate VA and lock into I-TLB */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
        BX      lr
#else
        MOV     pc, lr
#endif

/*******************************************************************************
*
* tlbIUnLock - unlock instruction TLB
*
* This routine will unlock instruction TLB.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void tlbIUnLock
*     (
*     void *    addr    /@ virtual address to be locked @/
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(tlbIUnLock)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

        /* the entry to lock is specified by the virtual address in R0 */

        MCR     CP_MMU, 0, r0, c10, c4, 1 /* unlock i-TLB */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
        BX      lr
#else
        MOV     pc, lr
#endif

/*******************************************************************************
*
* tlbDLock - translate and lock data TLB entry
*
* This routine will lock down entry in data TLB.
*
* May need software to disable interrupts - to prevent TLB from caching
* a translation that is about to be locked...
*
* NOMANUAL
*
* RETURNS: N/A
*
* void tlbDLock
*     (
*     void *    addr    /@ virtual address to be locked @/
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(tlbDLock)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

        /* the entry to lock is specified by the virtual address in R0 */

        MCR     CP_MMU, 0, r0, c8, c6, 1  /* invalidate D-TLB entry for VA */
        MCR     CP_MMU, 0, r0, c10, c8, 0 /* translare VA and lock into D-TLB */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
        BX      lr
#else
        MOV     pc, lr
#endif

/*******************************************************************************
*
* tlbDUnLock - unlock data TLB entry
*
* This routine will unlock data TLB.
*
* NOMANUAL
*
* RETURNS: N/A
*
* void tlbDUnLock
*     (
*     void *    addr    /@ virtual address to be locked @/
*     )
*/

_ARM_FUNCTION_CALLED_FROM_C(tlbDUnLock)

#if (ARMCACHE == ARMCACHE_XSCALE)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

        /* the entry to lock is specified by the virtual address in R0 */

        MCR     CP_MMU, 0, r0, c10, c8, 1 /* unlock d-TLB */

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r1, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r1, r1                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#endif /* (ARMCACHE == ARMCACHE_XSCALE) */

#if (ARM_THUMB)
        BX      lr
#else
        MOV     pc, lr
#endif

/*******************************************************************************
*
* cacheCreateInternalDataRAM - create internal data RAM using N lines of D-cache
*
* The data cache is a 32-Kbyte, 32-way set associative cache... this
* means there are 32 sets with each set containing 32 ways. Each way of a
* set contains 32 bytes. To access a cache line we use a "Virtual
* Address" composed of :
*
*       Tag [31:10] - 21 bits, represents thw way, unique address
*   Set Index [9:5] - 5 bits, specifies the set within the cache (0-31)
*        Word [4:2] - 3 bits, specifies the 32-bit word within the 8-word cache
*                     line (0-7)
*        Byte [1:0] - 2 bits, represents the byte within the 4-byte word (0-3)
*
* When a line is allocated it uses the Tag & Set Index fields (Bits
* [31:5]) to establish the link to a line in the data cache.
*
* This routine is setup to acquire lines across sets, (i.e. in an empty
* cache, if first line starts at set 0, way 0, the second line is set 1
* way 0, and third is set 2, way 0, etc... when we reach set 31, the next
* line wraps back to set 0, way 1 and so on...).
*
* Input:
*     r0 - Virtual address of a region of memory to configure as data
*          ram, which is aligned on a 32-byte boundary.
*
*     r1 - is the number of 32-byte data cache lines to designate as data ram.
*
* Used:
*     r2 - temp.
*     r3 - hold current CPSR, to restore interrupts on way out
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheCreateInternalDataRAM
*     (
*     void *    addr,    /@ virtual address to be locked @/
*     UINT32    lines    /@ number of cache lines to allocate @/
*     )
*
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheCreateInternalDataRAM)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

        mcr     p15, 0, r0, c7, c10, 4  /* drain pending loads and stores */

        /* lock the cache */

        mov     r2, #0x1                 /* LOCK */
        mcr     p15, 0, r2, c9, c2, 0

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r2, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r2, r2                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        mov     r2, #0x0

dataRAMAllocate:
        /* Allocate and lock a tag at the given address */
        mcr     p15, 0, r0, c7, c2, 5   /* allocate data cache line */

        mcr     p15, 0, r0, c7, c10, 4  /* drain pending loads and stores */

        /* write 32 bytes (8 words) which inits the newly allocated cache line*/
        str     r2, [r0], #4            /* 1st Word */
        str     r2, [r0], #4
        str     r2, [r0], #4
        str     r2, [r0], #4
        str     r2, [r0], #4
        str     r2, [r0], #4
        str     r2, [r0], #4
        str     r2, [r0], #4            /* 8th Word */

        subs    r1, r1, #1
        bne     dataRAMAllocate

        mcr     p15, 0, r0, c7, c10, 4  /* drain pending loads and stores */

        /* unlock the cache */

        mov     r2, #0x0                /* NO LOCK */
        mcr     p15, 0, r2, c9, c2, 0

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r2, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r2, r2                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#if (ARM_THUMB)
        BX      lr
#else
        MOV     pc, lr
#endif

/*******************************************************************************
*
* cacheLockDataIntoDataCache - lock data into the data cache
*
* The data cache is a 32-Kbyte, 32-way set associative cache... this
* means there are 32 sets with each set containing 32 ways. Each way of a
* set contains 32 bytes. To access a cache line we use a "Virtual
* Address" composed of :
*
*       Tag [31:10] - 21 bits, represents thw way, unique address
*   Set Index [9:5] - 5 bits, specifies the set within the cache (0-31)
*        Word [4:2] - 3 bits, specifies the 32-bit word within the
*                     8-word cache line (0-7)
*        Byte [1:0] - 2 bits, represents the byte within the 4-byte word (0-3)
*
* Input:
*     r0 - Virtual address of a region of memory to lock, which s
*          aligned on a 32-byte boundary. (configured with C=1, and B=1)
*
*     r1 - is the number of 32-byte lines to lock into the data cache.
*
* Used:
*     r2 - temp.
*     r3 - hold current CPSR, to restore interrupts on way out
*
* NOMANUAL
*
* RETURNS: N/A
*
* void cacheLockDataIntoDataCache
*     (
*     void *    addr,    /@ virtual address to be locked @/
*     UINT32    lines    /@ number of cache lines to allocate @/
*     )
*
*/

_ARM_FUNCTION_CALLED_FROM_C(cacheLockDataIntoDataCache)

        stmfd   sp!,{r0-r3}             /* save r0-r3 to stack */

        LDR     r2, L$_cacheArchIntMask /* Get pointer to cacheArchIntMask */
        LDR     r2, [r2]                /* get cacheArchIntMask */
        MRS     r3, cpsr                /* Get CPSR */
        ORR     r2, r3, r2              /* disable interrupts */
        MSR     cpsr, r2

        mcr     p15, 0, r0, c7, c10, 4  /* drain pending loads and stores */

        /* lock the cache */

        mov     r2, #0x1                 /* LOCK */
        mcr     p15, 0, r2, c9, c2, 0

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r2, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r2, r2                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        mov     r2, #0x0

lockDataIntoCache:
        mcr     p15, 0, r0, c7, c10, 1  /* write back line if it's dirty */

        mcr     p15, 0, r0, c7, c6, 1   /* Flush/Invalidate line from cache */

	/*
	 * Load and lock 32 bytes of data located at [r0] into the
	 * data cache. Post increment the address in r0 to the next cache
	 * line
	 */

        pld     [r0], #32

        mcr     p15, 0, r0, c7, c10, 4  /* drain pending loads and stores */

        subs    r1, r1, #1
        bne     lockDataIntoCache

        mcr     p15, 0, r0, c7, c10, 4  /* drain pending loads and stores */

        /* unlock the cache */

        mov     r2, #0x0                /* NO LOCK */
        mcr     p15, 0, r2, c9, c2, 0

        /* assure that CP15 update takes effect */

        MRC     CP_MMU, 0, r2, c2, c0, 0 /* arbitrary read of CP15 */
        MOV     r2, r2                   /* wait for it */
        SUB     pc, pc, #4               /* branch to next instruction */

        /*
	 * The MMU is guaranteed to be updated at this point; the next
	 * instruction will see the locked instruction TLB entry
         */

        MSR     cpsr, r3                /* Restore interrupt state */

        /* restore registers and return */

        ldmfd   sp!,{r0-r3}

#if (ARM_THUMB)
        BX      lr
#else
        MOV     pc, lr
#endif

#endif /* ARMCACHE == ARMCACHE_XSCALE */

#endif /* ARMCACHE == 710A,720T,740T,810,SA*,920T,926E,940T,946E,XSCALE,1020E,1022E */
