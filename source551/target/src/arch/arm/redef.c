/* redef.c - Symbol redefinitions for C files */

/* Copyright 1998-2001 Wind River Systems, Inc. */

/*
modification history
--------------------
01f,05feb03,jb  Add TtbrGet to redefine to fix broken build
01e,13nov01,to   cosmetic change
01d,02oct01,jpd  added cacheIdentify.
01c,25jul01,scm  add support for btbInvalidate...
01b,09feb01,scm  add support for cache & TLB locking (XScale)
01a,24nov98,cdp  written.
*/

/*
DESCRIPTION
This file redefines symbols in the cache and MMU C libraries so that each
cache/MMU library has unique symbols and cross references are correct.
*/

#define cacheArchLibInstall	FN(cache,LibInstall)
#define cacheDClearDisable	FN(cache,DClearDisable)
#define cacheDFlush		FN(cache,DFlush)
#define cacheDFlushAll		FN(cache,DFlushAll)
#define cacheDInvalidateAll	FN(cache,DInvalidateAll)
#define cacheDInvalidate	FN(cache,DInvalidate)
#define cacheIInvalidateAll	FN(cache,IInvalidateAll)
#define cacheIInvalidate	FN(cache,IInvalidate)
#define cacheDClearAll		FN(cache,DClearAll)
#define cacheDClear		FN(cache,DClear)
#define cacheIClearDisable	FN(cache,IClearDisable)
#define cacheArchPipeFlush	FN(cache,ArchPipeFlush)
#define cacheIMB		FN(cache,IMB)
#define cacheIMBRange		FN(cache,IMBRange)
#define cacheIdentify		FN(cache,Identify)

#if (ARMCACHE == ARMCACHE_XSCALE)
#define btbInvalidate		FN(btb,Invalidate)
#endif

#define cacheIFetchNLock	FN(cache,IFetchNLock)
#define cacheIUnLock		FN(cache,IUnLock)
#define cacheDSetLockMode	FN(cache,DSetLockMode)
#define cacheDLockRead		FN(cache,DLockRead)
#define cacheDUnLock		FN(cache,DUnLock)

#define tlbILock		FN(tlb,ILock)
#define tlbIUnLock		FN(tlb,IUnLock)
#define tlbDLock		FN(tlb,DLock)
#define tlbDUnLock		FN(tlb,DUnLock)

#define mmuLibInstall		FN(mmu,LibInstall)
#define mmuTtbrSet		FN(mmu,TtbrSet)
#define mmuTtbrGet		FN(mmu,TtbrGet)
#define mmuDacrSet		FN(mmu,DacrSet)
#define mmuAEnable		FN(mmu,AEnable)
#define mmuADisable		FN(mmu,ADisable)
#define mmuPrrSet		FN(mmu,PrrSet)
#define mmuPrrGet		FN(mmu,PrrGet)
#define mmuCcrSet		FN(mmu,CcrSet)
#define mmuCcrGet		FN(mmu,CcrGet)
#define mmuWbcrSet		FN(mmu,WbcrSet)
#define mmuWbcrGet		FN(mmu,WbcrGet)
#define mmuPrSet		FN(mmu,PrSet)
#define mmuPrGet		FN(mmu,PrGet)
#define mmuTLBIDFlushEntry	FN(mmu,TLBIDFlushEntry)
#define mmuTLBIDFlushAll	FN(mmu,TLBIDFlushAll)
