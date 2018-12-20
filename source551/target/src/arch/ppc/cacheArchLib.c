/* cacheArchLib.c - PowerPC cache management library */

/* Copyright 1984-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02c,08aug03,dtr  Fix SPR 90160 for PPC85XX only. Also check for cache on 
                 before calling cachePpcEnable for PPC85XX. Both need to be 
                 added for PPC603,604,603EC.
02b,09jun03,dtr  CP1 merge.
01z,17jan03,mil  Fixed cacheDmaFree() not reenabling caching of page (SPR
                 #85587).
02a,26nov02,dtr  Adding support for PPC85XX.
01z,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
01y,17apr02,jtp  support PPC440 cache, fix SPR#73675 performance concern
01x,22jan02,pcs  Add L3 Cache support &
                 add fix for SPR#70702 & SPR#70703
01w,06nov01,jtp  Add cacheArchDmaMalloc/Free support for PPC440
01v,03oct01,jtp  Add stub support for PPC440
01u,07jun01,dtr  Calculating malloc size with ROUND_UP.
01t,03nov00,s_m  check for return value of cachePpcDisable
01s,25oct00,s_m  renamed PPC405 cpu types
01r,14Jun2k,alp  Added PPC405 support
01q,23jan01,pcs  Merge changes as received from teamF1
01s,12dec00,mno  added snoop support, removed vmLibInstalled check
                 in cacheArchDmaFree (teamf1)
01r,28oct00,ksn  added function pointers for external cache , flushing and
                 disabling (teamF1)
01q,13sep00,ksn  added function pointers for external cache enable and
                 invalidation (teamF1)
01p,25feb99,tpr  added cacheArchPipeFlush pointer (SPR 21165).
01o,18aug98,tpr  added PowerPC EC 603 support.
01n,20dec96,tpr  added cacheArchDisableFromMmu().
01m,10nov96,tpr  remove PPC860 debug code.
01l,03sep96,tam  added PPC403 support.
01k,29jul96,tpr  removed #IF FALSE in cacheArchDmaMalloc().
01j,20jun96,tpr  added ( in cacheIsOn().
01i,29may96,tpr  added PowerPC860 support.
01h,23feb96,tpr  changed hid0Get() by vxHid0Get().
01g,14feb96,tpr  added PPC604.
01f,07oct95,tpr  added PPC601.
01e,24sep95,tpr  added cacheArchDmaMalloc () and cacheArchDmaFree().
01d,01aug95,kvk  added cacheDisable() support.
01c,24may95,caf  initialized PPC603 MMU.
01b,27mar95,caf  added cacheEnable() support.
01a,30jan95,caf  created.
*/

/*
DESCRIPTION
This library contains architecture-specific cache library functions for
the PowerPC family instruction and data caches.
*/

#include "vxWorks.h"
#include "errnoLib.h"
#include "cacheLib.h"
#include "intLib.h"
#include "stdlib.h"
#include "arch/ppc/mmuPpcLib.h"
#include "arch/ppc/vxPpcLib.h"
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "private/funcBindP.h"


/* imports */

/*
 * low-level cache routines use buffer as the start of a memory region
 * from which we can read enough data to flush any dirty cache lines
 * out to RAM.
 */

char *cachePpcReadOrigin = (char *)0x10000;

#if	(CPU == PPC403)
/* 
 * ppc403IccrVal and ppc403DccrVal define respectively the cachability
 * state of the total effective adress space at a 128 MB granularity 
 * for instruction and data.
 * By default memory spaces  0x00000000-0x07ffffff and 0xf8000000-0xfffffffff
 * are set as cached. The rest of the effective adress space is programmed
 * as non-cached (cf _PPC403_ICCR_DEFAULT_VAL and _PPC403_DCCR_DEFAULT_VAL
 * in ppc403.h).
 */

UINT32	ppc403IccrVal	=	_PPC403_ICCR_DEFAULT_VAL;
UINT32	ppc403DccrVal	=	_PPC403_DCCR_DEFAULT_VAL;
#elif ((CPU == PPC405) || (CPU == PPC405F))
/*
 * On the PPC405, ICCR & DCCR control the cacheability state only if the MMU
 * is disabled.  If the MMU is enabled, then the cacheability state is 
 * controlled on a page-by-page basis.
 * If MMU is disabled: By default memory spaces  0x00000000-0x07ffffff 
 * and 0xf8000000-0xfffffffff are set as cached. The rest of the effective 
 * adress space is programmed as non-cached (cf _PPC405_ICCR_DEFAULT_VAL and 
 * _PPC405_DCCR_DEFAULT_VAL in ppc405.h).
 */
UINT32	ppc405IccrVal	=	_PPC405_ICCR_DEFAULT_VAL;
UINT32	ppc405DccrVal	=	_PPC405_DCCR_DEFAULT_VAL;
#endif


/* forward declarations */

STATUS cacheArchEnable     (CACHE_TYPE cache);
STATUS cachePpcEnable      (CACHE_TYPE cache);
STATUS cacheArchDisable    (CACHE_TYPE cache);
STATUS cachePpcDisable     (CACHE_TYPE cache);
STATUS cacheArchTextUpdate (void * address, size_t bytes);
STATUS cacheArchInvalidate (CACHE_TYPE cache, void * address, size_t bytes);
STATUS cacheArchFlush      (CACHE_TYPE cache, void * address, size_t bytes);
STATUS cacheArchPipeFlush  (void);
STATUS cacheArchError      (void);
void * cacheArchDmaMalloc  (size_t bytes);
STATUS cacheArchDmaFree    (void * pBuf);

#if ((CPU == PPC601) || (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC85XX))

IMPORT BOOL mmuPpcIEnabled;
IMPORT BOOL mmuPpcDEnabled;

BOOL cacheIToEnable = FALSE;
BOOL cacheDToEnable = FALSE;

#endif	/* ((CPU==PPC601) || (CPU==PPC603) || (CPU==PPCEC603) || (CPU==PPC604)) */

#if (CPU == PPC440)

/*
 * cache440Enabled serves these purposes:
 *	1) signals the TLB Miss handler whether to set all
 *	   TLB entries to W=0 I=1 (cache inhibited) or as declared
 *	   in the page table.
 *	2) signals the cache440Enable/Disable routines whether to
 *	   do their work or not.
 */

BOOL cache440Enabled = FALSE;

/*
 * cache440ToEnable is used to tell mmu440LibInit() that cacheEnable()
 * had been previously called, did nothing at the time, and the caches
 * are ready to be activated.
 */

BOOL cache440ToEnable = FALSE;

#endif /* CPU==PPC440 */

VOIDFUNCPTR _pSysL2CacheInvFunc = NULL;
VOIDFUNCPTR _pSysL2CacheEnable  = NULL;
VOIDFUNCPTR _pSysL2CacheFlush   = NULL;
VOIDFUNCPTR _pSysL2CacheDisable = NULL;
BOOL snoopEnable = FALSE;

VOIDFUNCPTR _pSysL3CacheInvalEnableFunc   = NULL;
VOIDFUNCPTR _pSysL3CacheFlushDisableFunc = NULL;


/******************************************************************************
*
* cacheArchLibInit - initialize the PowerPC cache library
*
* This routine initializes the cache library for PowerPC processors.
* It initializes the function pointers and configures the
* caches to the specified cache modes.  Modes should be set before caching
* is enabled.  If two complementary flags are set (enable/disable), no
* action is taken for any of the input flags.
*
* RETURNS: OK.
*/

STATUS cacheArchLibInit
    (
    CACHE_MODE  instMode,       			/* I cache mode */
    CACHE_MODE  dataMode        			/* D cache mode */
    )
    {
    cacheLib.enableRtn          = cacheArchEnable;	/* cacheEnable() */
    cacheLib.disableRtn         = cacheArchDisable;	/* cacheDisable() */
    cacheLib.lockRtn            = NULL;			/* XXX cacheLock() */
    cacheLib.unlockRtn          = NULL;			/* XXX cacheUnlock() */
    cacheLib.clearRtn           = NULL;
    cacheLib.dmaMallocRtn       = (FUNCPTR ) cacheArchDmaMalloc;
    cacheLib.dmaFreeRtn         = cacheArchDmaFree;
    cacheLib.dmaVirtToPhysRtn   = NULL;
    cacheLib.dmaPhysToVirtRtn   = NULL;
    cacheLib.textUpdateRtn      = cacheArchTextUpdate;  /* cacheTextUpdate() */
    cacheLib.flushRtn           = cacheArchFlush;       /* cacheFlush() */
    cacheLib.invalidateRtn      = cacheArchInvalidate;  /* cacheInvalidate() */
    cacheLib.pipeFlushRtn       = cacheArchPipeFlush;
    
    cacheDataMode       = dataMode;		/* save dataMode for enable */
    cacheDataEnabled    = FALSE;		/* d-cache is currently off */
    cacheMmuAvailable   = FALSE;		/* no mmu yet */

#if	(CPU == PPC860)
    mmuPpcMiCtrSet (mmuPpcMiCtrGet () & ~ 0x20000000);

    if (dataMode & CACHE_WRITETHROUGH)
	mmuPpcMdCtrSet ((mmuPpcMdCtrGet () | 0x10000000) & ~0x20000000);
    else
	mmuPpcMdCtrSet (mmuPpcMdCtrGet () & ~0x30000000);
#endif	/* (CPU == PPC860 */

    return (OK);
    }

/******************************************************************************
*
* cacheProbe - test for the presence of a type of cache
*
* This routine returns status with regard to the prescence of a particular
* type of cache.
*
* RETURNS: OK, or ERROR if the cache type is invalid or the cache control
* is not supported.
*
*/

LOCAL STATUS cacheProbe
    (
    CACHE_TYPE  cache           			/* cache to test */
    )
    {
    if ((cache == DATA_CACHE) || (cache == INSTRUCTION_CACHE))
	return (OK);

    errno = S_cacheLib_INVALID_CACHE;                   /* set errno */
    return (ERROR);
    }

/******************************************************************************
*
* cacheArchEnable -
*
* RETURNS: OK, or ERROR if the cache type is invalid.
*
* NOMANUAL
*/

STATUS cacheArchEnable
    (
    CACHE_TYPE  cache           			/* cache to enable */
    )
    {

    if (cacheProbe (cache) != OK)
        return (ERROR);                         	/* invalid cache */

#if ((CPU == PPC601) || (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604))
    if ((cache == INSTRUCTION_CACHE) && (!mmuPpcIEnabled))
	{
	cacheIToEnable = TRUE;
	return (OK);
	}

    if ((cache == DATA_CACHE) && (!mmuPpcDEnabled))
	{
	cacheDToEnable = TRUE ;
	return (OK);
	}
#endif

#if (CPU == PPC85XX)
    if ((cache == INSTRUCTION_CACHE))
	cacheIToEnable = TRUE;

    if ((cache == DATA_CACHE))
	cacheDToEnable = TRUE ;

    if ((cache == INSTRUCTION_CACHE) && (!mmuPpcIEnabled))
	return (OK);

    if ((cache == DATA_CACHE) && (!mmuPpcDEnabled))
	return (OK);

    if(!cacheIsOn(cache))
#endif
    cachePpcEnable (cache);				/* enable the cache */

    if (cache == DATA_CACHE)
        {
          if ( cacheDataEnabled == FALSE )
          {
           if (_pSysL2CacheInvFunc != NULL)
              (*_pSysL2CacheInvFunc) ();

           if (_pSysL2CacheEnable != NULL)
              (*_pSysL2CacheEnable) (cache);

           if (_pSysL3CacheInvalEnableFunc != NULL)
              (*_pSysL3CacheInvalEnableFunc) (cache);

           cacheDataEnabled = TRUE;
           cacheFuncsSet ();
          }
        }

    return (OK);
    }

/******************************************************************************
*
* cacheArchDisable -
*
* RETURNS: OK, or ERROR if the cache type is invalid.
*
* NOMANUAL
*/

STATUS cacheArchDisable
    (
    CACHE_TYPE  cache           			/* cache to enable */
    )
    {
    int lockKey;
    int retval;

    if (cacheProbe (cache) != OK)
        return (ERROR);                         	/* invalid cache */

    lockKey = intLock ();

    if (cache == DATA_CACHE)
        {
        if (_pSysL3CacheFlushDisableFunc != NULL)
            (*_pSysL3CacheFlushDisableFunc) ();

        if (_pSysL2CacheFlush != NULL)
            (*_pSysL2CacheFlush) ();

        if (_pSysL2CacheDisable != NULL)
            (*_pSysL2CacheDisable) ();
    }
    retval = cachePpcDisable (cache);
    intUnlock (lockKey);


    if ((cache == DATA_CACHE) && (retval == OK))
        {
        cacheDataEnabled = FALSE;		/* data cache is off */
	cacheFuncsSet ();			/* update data function ptrs */
#if ((CPU == PPC601) || (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC85XX))
	cacheDToEnable = FALSE;
#endif
        }
#if ((CPU == PPC601) || (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC85XX))
    else
	cacheIToEnable = FALSE;
#endif

    return (retval);
    }

/******************************************************************************
*
* cacheArchDisableFromMmu -
*
* RETURNS: OK, or ERROR if the cache type is invalid.
*
* NOMANUAL
*/

STATUS cacheArchDisableFromMmu
    (
    CACHE_TYPE  cache           			/* cache to enable */
    )
    {
    int lockKey;

    if (cacheProbe (cache) != OK)
        return (ERROR);                         	/* invalid cache */

    lockKey = intLock ();

    if (cache == DATA_CACHE)
        {
        if (_pSysL3CacheFlushDisableFunc != NULL)
            (*_pSysL3CacheFlushDisableFunc) ();

        if (_pSysL2CacheFlush != NULL)
            (*_pSysL2CacheFlush) ();

        if (_pSysL2CacheDisable != NULL)
            (*_pSysL2CacheDisable) ();
        }

    cachePpcDisable (cache);
    intUnlock (lockKey);

    if (cache == DATA_CACHE)
        {
        cacheDataEnabled = FALSE;		/* data cache is off */
	cacheFuncsSet ();			/* update data function ptrs */
        }

    return (OK);
    }

/******************************************************************************
*
* cacheErrnoSet -
*
* RETURNS: ERROR, always.
*
* NOMANUAL
*/

STATUS cacheErrnoSet (void)
    {
    errno = S_cacheLib_INVALID_CACHE;
    return (ERROR);
    }

/*******************************************************************************
*
* cacheIsOn - boolean function to return state of cache
*
*/

LOCAL BOOL cacheIsOn
    (
    CACHE_TYPE	cache			/* cache to examine state */
    )
    {
#if ((CPU == PPC601) || (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604))
    if (cache == DATA_CACHE)
	return ((vxHid0Get () & 0x00004000) != 0);

    if (cache == INSTRUCTION_CACHE)
	return ((vxHid0Get () & 0x00008000) != 0);

#elif	(CPU == PPC860)
    if	(cache == INSTRUCTION_CACHE)
	return ((vxIcCstGet() & 0x80000000) != 0);

    if	(cache == DATA_CACHE)
	return ((vxDcCstGet() & 0x80000000) != 0);

#elif	(CPU == PPC403)
    if (cache == DATA_CACHE)
	return ((vxDccrGet() & ppc403DccrVal) != 0);
    if (cache == INSTRUCTION_CACHE)
	return ((vxIccrGet() & ppc403IccrVal) != 0);

#elif	( (CPU == PPC405) || (CPU == PPC405F) )
    if (cache == DATA_CACHE)
	return ((vxDccrGet() & ppc405DccrVal) != 0);
    if (cache == INSTRUCTION_CACHE)
	return ((vxIccrGet() & ppc405IccrVal) != 0);
#elif  (CPU == PPC85XX)
    if (cache == DATA_CACHE)
        return ((vxL1CSR0Get() & 0x1) !=0);
    if (cache == INSTRUCTION_CACHE)
        return ((vxL1CSR1Get() & 0x1) !=0);
#endif	

#if	(CPU == PPC440)
    return (cache440Enabled);
#else /* CPU != PPC440 */
    return (FALSE);
#endif /* CPU */
    }

/*******************************************************************************
*
* cacheArchDmaMalloc - allocate a cache-safe buffer
*
*/

void * cacheArchDmaMalloc
    (
    size_t	bytes			/* size of cache-safe buffer */
    )
    {
    void *	pBuf;
#if	(CPU != PPC403)
    int 	pageSize;

    if (!cacheIsOn (DATA_CACHE))	/* cache is off just allocate buffer */
	{
	return (malloc (bytes));
	}

    if ((pageSize = VM_PAGE_SIZE_GET ()) == ERROR)
	return (NULL);

    /* make sure bytes is a multiple of pageSize */

    bytes = ROUND_UP(bytes,pageSize);

    if ((_func_memalign == NULL) ||
	((pBuf = (void *)(* _func_memalign) (MMU_PPC_PAGE_SIZE, bytes)) ==
									NULL))
	return (NULL);

    if (snoopEnable == TRUE)
        {
        VM_STATE_SET (NULL, pBuf, bytes,
                      VM_STATE_MASK_CACHEABLE | VM_STATE_MASK_MEM_COHERENCY,
                      VM_STATE_CACHEABLE      | VM_STATE_MEM_COHERENCY);
        }
    else
        {
        VM_STATE_SET (NULL, pBuf, bytes,
                      VM_STATE_MASK_CACHEABLE, VM_STATE_CACHEABLE_NOT);
        }


    return (pBuf);

#else	/* CPU == PPC403 */
    pBuf = malloc (bytes);

    if (!cacheIsOn (DATA_CACHE))        /* cache is off just allocate buffer */
        return (pBuf);
    else
        return ((void *)((UINT32) pBuf ^ (UINT32) 0x80000000));
					/* return double-mapped adress */
#endif	/* CPU != PPC403 */
    }

/*******************************************************************************
*
* cacheArchDmaFree - free the buffer acquired by cacheArchDmaMalloc()
*/

STATUS cacheArchDmaFree
    (
    void * pBuf			/* ptr returned by cacheArchDmaMalloc() */
    )
    {
#if	(CPU != PPC403)
    BLOCK_HDR * pHdr;		/* pointer to block header */
    STATUS	status = OK;	/* return value */

    if (cacheIsOn (DATA_CACHE) && 
        ((vmLibInfo.vmBaseLibInstalled) || (vmLibInfo.vmLibInstalled)))
	{
	pHdr = BLOCK_TO_HDR (pBuf);

	status = VM_STATE_SET (NULL,pBuf,(pHdr->nWords * 2) - sizeof(BLOCK_HDR),
                               (VM_STATE_MASK_CACHEABLE |
                                VM_STATE_MASK_MEM_COHERENCY),
                               (VM_STATE_CACHEABLE|VM_STATE_MEM_COHERENCY_NOT));
	}

    free (pBuf);		/* free buffer after modified */

    return (status);

#else	/* CPU == PPC403 */
    if (!cacheIsOn (DATA_CACHE))
        free (pBuf);
    else
        free ((void *) ((UINT32)pBuf ^ (UINT32)0x80000000));
    return (OK);
#endif	/* CPU != PPC403 */
    }

#if	FALSE
#if	(CPU == PPC860)
typedef union 
    {
    struct
	{
	UINT	reserved1:18;
	UINT	tag:1;
	UINT	way:1;
	UINT	reserved2:1;
	UINT	set:7;
	UINT	word:2;
	UINT	reserved3:2;
	} field;
    struct
	{
	UINT	word;
	} bytes;
    } IC_ADR_T;

typedef union 
    {
    struct
	{
	UINT	tag:21;
	UINT	reserved1:1;
	UINT	v:1;
	UINT	l:1;
	UINT	lru:1;
	UINT	reserved3:7;
	} field;
    struct
	{
	UINT	word;
	} bytes;
    } IC_DAT_T;

void iCachePpcShow ()
    {
    UINT	ix;
    IC_ADR_T	icAdr;
    IC_DAT_T	icDat;
    IC_DAT_T	icDat00;
    IC_DAT_T	icDat01;
    IC_DAT_T	icDat02;
    IC_DAT_T	icDat03;

    for (ix = 0; ix <128; ix++)
	{
	icAdr.field.tag = 0;
	icAdr.field.way = 0;
	icAdr.field.set = ix;
	icAdr.field.word = 0;

	vxIcAdrSet (icAdr.bytes.word);
	icDat.bytes.word = vxIcDatGet();

	icAdr.field.tag = 1;
	vxIcAdrSet (icAdr.bytes.word);
	icDat00.bytes.word = vxIcDatGet();

	icAdr.field.word = 1;
	vxIcAdrSet (icAdr.bytes.word);
	icDat01.bytes.word = vxIcDatGet();

	icAdr.field.word = 2;
	vxIcAdrSet (icAdr.bytes.word);
	icDat02.bytes.word = vxIcDatGet();

	icAdr.field.word = 3;
	vxIcAdrSet (icAdr.bytes.word);
	icDat03.bytes.word = vxIcDatGet();


	printf ("Set: %d	tag: 0x%x	v: %d	l: %d	lru: %d	w00: 0x%x	w01: 0x%x	w02: 0x%x	w03: 0x%x\n",
		ix, icDat.bytes.word & 0xfffff800, icDat.field.v, icDat.field.l,
		icDat.field.lru, icDat00.bytes.word, icDat01.bytes.word,
		icDat02.bytes.word, icDat03.bytes.word);

	icAdr.field.way = 1;
	icAdr.field.tag = 0;
	icAdr.field.word = 0;

	vxIcAdrSet (icAdr.bytes.word);
	icDat.bytes.word = vxIcDatGet();

	icAdr.field.tag = 1;
	vxIcAdrSet (icAdr.bytes.word);
	icDat00.bytes.word = vxIcDatGet();

	icAdr.field.word = 1;
	vxIcAdrSet (icAdr.bytes.word);
	icDat01.bytes.word = vxIcDatGet();

	icAdr.field.word = 2;
	vxIcAdrSet (icAdr.bytes.word);
	icDat02.bytes.word = vxIcDatGet();

	icAdr.field.word = 3;
	vxIcAdrSet (icAdr.bytes.word);
	icDat03.bytes.word = vxIcDatGet();


	printf ("       	tag: 0x%x	v: %d	l: %d	lru: %d	w00: 0x%x	w01: 0x%x	w02: 0x%x	w03: 0x%x\n",
		icDat.bytes.word & 0xfffff800, icDat.field.v, icDat.field.l,
		icDat.field.lru, icDat00.bytes.word, icDat01.bytes.word,
		icDat02.bytes.word, icDat03.bytes.word);

	}
    }

void dCachePpcShow ()
    {
    UINT	ix;
    IC_ADR_T	dcAdr;
    IC_DAT_T	dcDat;
    IC_DAT_T	dcDat00;
    IC_DAT_T	dcDat01;
    IC_DAT_T	dcDat02;
    IC_DAT_T	dcDat03;

    for (ix = 0; ix <128; ix++)
	{
	dcAdr.field.tag = 0;
	dcAdr.field.way = 0;
	dcAdr.field.set = ix;
	dcAdr.field.word = 0;

	vxDcAdrSet (dcAdr.bytes.word);
	dcDat.bytes.word = vxDcDatGet();

	dcAdr.field.tag = 1;
	vxDcAdrSet (dcAdr.bytes.word);
	dcDat00.bytes.word = vxDcDatGet();

	dcAdr.field.word = 1;
	vxDcAdrSet (dcAdr.bytes.word);
	dcDat01.bytes.word = vxDcDatGet();

	dcAdr.field.word = 2;
	vxDcAdrSet (dcAdr.bytes.word);
	dcDat02.bytes.word = vxDcDatGet();

	dcAdr.field.word = 3;
	vxDcAdrSet (dcAdr.bytes.word);
	dcDat03.bytes.word = vxDcDatGet();


	printf ("Set:   %d	tag: 0x%x	v: %d	l: %d	lru: %d	w00: 0x%x	w01: 0x%x	w02: 0x%x	w03: 0x%x\n",
		ix, dcDat.bytes.word & 0xfffff800, dcDat.field.v, dcDat.field.l,
		dcDat.field.lru, dcDat00.bytes.word, dcDat01.bytes.word,
		dcDat02.bytes.word, dcDat03.bytes.word);

	dcAdr.field.way = 1;
	dcAdr.field.tag = 0;
	dcAdr.field.word = 0;

	vxDcAdrSet (dcAdr.bytes.word);
	dcDat.bytes.word = vxDcDatGet();

	dcAdr.field.tag = 1;
	vxDcAdrSet (dcAdr.bytes.word);
	dcDat00.bytes.word = vxDcDatGet();

	dcAdr.field.word = 1;
	vxDcAdrSet (dcAdr.bytes.word);
	dcDat01.bytes.word = vxDcDatGet();

	dcAdr.field.word = 2;
	vxDcAdrSet (dcAdr.bytes.word);
	dcDat02.bytes.word = vxDcDatGet();

	dcAdr.field.word = 3;
	vxDcAdrSet (dcAdr.bytes.word);
	dcDat03.bytes.word = vxDcDatGet();


	printf ("		tag: 0x%x	v: %d	l: %d	lru: %d	w00: 0x%x	w01: 0x%x	w02: 0x%x	w03: 0x%x\n",
		dcDat.bytes.word & 0xfffff800, dcDat.field.v, dcDat.field.l,
		dcDat.field.lru, dcDat00.bytes.word, dcDat01.bytes.word,
		dcDat02.bytes.word, dcDat03.bytes.word);

	}
    }
#endif	/* (CPU == PPC860) */
#endif	/* FALSE */
