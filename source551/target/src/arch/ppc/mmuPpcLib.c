/* mmuPpcLib.c - mmu library for PowerPc */

/* Copyright 1984-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01n,12sep02,pch  SPR 80274: add support for PPC750FX additional BAT registers
01m,27may02,kab  Extra BAT only available on PPC604
01l,30apr02,mil  Fixed mmuPpcTranslate() to contain page offset (SPR #76143).
01k,28apr02,pcs  Add MPC 7x5/74x5 extra bat support
01j,25apr02,pch  SPR 74926: don't connect to unused vector
		 SPR 67973: add exception message for MMU config failure
01i,14nov01,dtr  Addition of full 32bit branch for mmu excection vectors.
01h,29oct98,elg  added some variables declarations in mmuArchVars.c
01g,18aug98,tpr  added PowerPC EC 603 support.
01f,20dec96,tpr  replaced cacheDisable()0 by cacheDisableFromMmu().
01e,25jul96,tpr  removed bug with PTE address get function (SPR #6582).
01d,23feb96,tpr  added documentation + code clean up.
01c,14feb96,tpr  slipt PPC603 and PPC604.
01b,10oct95,kvk	 enclosed 603 specific stuff for itself.
01a,08sep95,tpr	 written.
*/

/*
DESCRIPTION:
*/

/* includes */

#include "vxWorks.h"
#include "errno.h"
#include "cacheLib.h"
#include "vmLib.h"
#include "sysLib.h"
#include "string.h"
#include "stdlib.h"
#include "intLib.h"
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "arch/ppc/excPpcLib.h"
#include "arch/ppc/ivPpc.h"
#include "arch/ppc/mmuPpcLib.h"
#include "arch/ppc/mmuArchVars.h"

/* defines */

#define PAGE_SIZE	4096		/* page size of 4K */

/* typedefs */

typedef struct hashTabInfo
    {
    UINT	hashTabOrgMask;
    UINT	hastTabMask;
    UINT	pteTabMinSize;
    } HASH_TAB_INFO ;

/* externals */

IMPORT u_int	mmuPpcSrGet ();
IMPORT void	mmuPpcSrSet ();
IMPORT void	mmuPpcTlbie ();
IMPORT void	mmuPpcAEnable ();
IMPORT void	mmuPpcADisable ();
IMPORT void	mmuPpcSdr1Set ();
IMPORT u_int 	mmuPpcSdr1Get ();
IMPORT void	mmuPpcBatInit (int * pSysBatDesc);
#if	(CPU == PPC604)
IMPORT void	mmuPpcExtraBatInit (int * pSysBatDesc);
IMPORT void	mmuPpcExtraBatEnableMPC74x5(void);
IMPORT void	mmuPpcExtraBatEnableMPC7x5(void);
#endif	/* PPC604 */
IMPORT void	mmuPpcTlbInvalidateAll(void);
IMPORT STATUS	cacheArchEnable (CACHE_TYPE cache);
IMPORT STATUS	cacheArchDisableFromMmu (CACHE_TYPE  cache);

#if	((CPU == PPC603) || (CPU == PPCEC603))
IMPORT void	mmuPpcInstMissHandler();
IMPORT void	mmuPpcDataLoadMissHandler();
IMPORT void	mmuPpcDataStoreMissHandler();
IMPORT void	mmuPpcInstMissHandlerLongJump();
IMPORT void	mmuPpcDataLoadMissHandlerLongJump();
IMPORT void	mmuPpcDataStoreMissHandlerLongJump();
#endif	/* ((CPU == PPC603) || (CPU == PPCEC603)) */

IMPORT STATE_TRANS_TUPLE *	mmuStateTransArray;
IMPORT int			mmuStateTransArraySize;
IMPORT MMU_LIB_FUNCS		mmuLibFuncs;
IMPORT int			mmuPageBlockSize;

IMPORT BOOL	cacheIToEnable;
IMPORT BOOL	cacheDToEnable;
IMPORT BOOL	                excExtendedVectors;

/* locals */

FUNCPTR _pSysBatInitFunc = NULL;


LOCAL STATE_TRANS_TUPLE mmuStateTransArrayLocal [] =
    {
    {VM_STATE_MASK_VALID, MMU_STATE_MASK_VALID,
     VM_STATE_VALID, MMU_STATE_VALID},

    {VM_STATE_MASK_VALID, MMU_STATE_MASK_VALID,
     VM_STATE_VALID_NOT, MMU_STATE_VALID_NOT},

    {VM_STATE_MASK_WRITABLE, MMU_STATE_MASK_WRITABLE,
     VM_STATE_WRITABLE, MMU_STATE_WRITABLE},

    {VM_STATE_MASK_WRITABLE, MMU_STATE_MASK_WRITABLE,
     VM_STATE_WRITABLE_NOT, MMU_STATE_WRITABLE_NOT},

    {VM_STATE_MASK_CACHEABLE, MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE, MMU_STATE_CACHEABLE},

    {VM_STATE_MASK_CACHEABLE, MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE_NOT, MMU_STATE_CACHEABLE_NOT},

    {VM_STATE_MASK_CACHEABLE, MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE_WRITETHROUGH, MMU_STATE_CACHEABLE_WRITETHROUGH},

    {VM_STATE_MASK_MEM_COHERENCY, MMU_STATE_MASK_MEM_COHERENCY,
     VM_STATE_MEM_COHERENCY, MMU_STATE_MEM_COHERENCY},

    {VM_STATE_MASK_MEM_COHERENCY, MMU_STATE_MASK_MEM_COHERENCY,
     VM_STATE_MEM_COHERENCY_NOT, MMU_STATE_MEM_COHERENCY_NOT},

    {VM_STATE_MASK_GUARDED, MMU_STATE_MASK_GUARDED,
     VM_STATE_GUARDED, MMU_STATE_GUARDED},

    {VM_STATE_MASK_GUARDED, MMU_STATE_MASK_GUARDED,
     VM_STATE_GUARDED_NOT, MMU_STATE_GUARDED_NOT},
    };

LOCAL HASH_TAB_INFO mmuPpcHashTabInfo[] =
    {
    {MMU_SDR1_HTABORG_8M,	MMU_SDR1_HTABMASK_8M,	MMU_PTE_MIN_SIZE_8M},
    {MMU_SDR1_HTABORG_16M,	MMU_SDR1_HTABMASK_16M,	MMU_PTE_MIN_SIZE_16M},
    {MMU_SDR1_HTABORG_32M,	MMU_SDR1_HTABMASK_32M,	MMU_PTE_MIN_SIZE_32M},
    {MMU_SDR1_HTABORG_64M,	MMU_SDR1_HTABMASK_64M,	MMU_PTE_MIN_SIZE_64M},
    {MMU_SDR1_HTABORG_128M,	MMU_SDR1_HTABMASK_128M,	MMU_PTE_MIN_SIZE_128M},
    {MMU_SDR1_HTABORG_256M,	MMU_SDR1_HTABMASK_256M,	MMU_PTE_MIN_SIZE_256M},
    {MMU_SDR1_HTABORG_512M,	MMU_SDR1_HTABMASK_512M,	MMU_PTE_MIN_SIZE_512M},
    {MMU_SDR1_HTABORG_1G,	MMU_SDR1_HTABMASK_1G,	MMU_PTE_MIN_SIZE_1G},
    {MMU_SDR1_HTABORG_2G,	MMU_SDR1_HTABMASK_2G,	MMU_PTE_MIN_SIZE_2G},
    {MMU_SDR1_HTABORG_4G,	MMU_SDR1_HTABMASK_4G,	MMU_PTE_MIN_SIZE_4G},
    };

LOCAL int mmuPpcHashTabInfoNumEnt = NELEMENTS (mmuPpcHashTabInfo);

/*
 * a translation table to hold the descriptors for the global transparent
 * translation of physical to virtual memory
 */

LOCAL MMU_TRANS_TBL	mmuGlobalTransTbl;	/* global translation table */	
LOCAL u_int		mmuPpcSelected;		/* mmu type selected */

/* forward declarations */

LOCAL MMU_TRANS_TBL *	mmuPpcTransTblCreate ();
LOCAL STATUS		mmuPpcTransTblDelete (MMU_TRANS_TBL *transTbl);
LOCAL STATUS		mmuPpcEnable (BOOL enable);
LOCAL STATUS		mmuPpcStateSet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				        UINT stateMask, UINT state);
LOCAL STATUS		mmuPpcStateGet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				        UINT *state);
LOCAL STATUS		mmuPpcPageMap (MMU_TRANS_TBL *transTbl,
				       void * virtualAddress, void *physPage);
LOCAL STATUS		mmuPpcGlobalPageMap (void * virtualAddress,
				             void * physPage);
LOCAL STATUS		mmuPpcTranslate (MMU_TRANS_TBL * transTbl,
				         void * virtAddress,
					 void ** physAddress);
LOCAL void		mmuPpcCurrentSet (MMU_TRANS_TBL * transTbl);
LOCAL void		mmuPpcPtegAddrGet (MMU_TRANS_TBL * pTransTbl,
					   void * effectiveAddr,
					   PTEG ** ppPteg1,
					   PTEG ** ppPteg2,
					   u_int * pVirtualSegId,
					   u_int * abbrevPageIndex);
LOCAL void  		mmuPpcPteUpdate (PTE * pteAddr, PTE * pteVal);
LOCAL STATUS		mmuPpcTransTblInit (MMU_TRANS_TBL * pNewTransTbl);
LOCAL STATUS		mmuPpcPteGet (MMU_TRANS_TBL * pTransTbl,
    				      void * effectiveAddr,
    				      PTE ** ppPte);

#if	(CPU == PPC604)
void mmuPpcBatInitMPC74x5 (UINT32 *pSysBatDesc);
void mmuPpcBatInitMPC7x5 (UINT32 *pSysBatDesc);
#endif	/* PPC604 */

LOCAL MMU_LIB_FUNCS mmuLibFuncsLocal =
    {
    mmuPpcLibInit,
    mmuPpcTransTblCreate,
    mmuPpcTransTblDelete,
    mmuPpcEnable,
    mmuPpcStateSet,
    mmuPpcStateGet,
    mmuPpcPageMap,
    mmuPpcGlobalPageMap,
    mmuPpcTranslate,
    mmuPpcCurrentSet
    };

/******************************************************************************
*
* mmuPpcLibInit - initialize module
*
*/

STATUS mmuPpcLibInit 
    (
    int 	mmuType,		/* data and/or instruction mmu */
    int *	pPhysMemDesc,		/* physical memory desciption */ 
    int		elementNb,		/* element nbr in physical mem desc */
    int *	pSysBatDesc		/* bat register description */
    )
    {
    u_int		entryNb;		/* entry number */
    u_int		memSize = 0;		/* total memorie size */
    SR			srVal;
    u_int		position;
    PHYS_MEM_DESC *	pMemDesc;
#if 	((CPU == PPC603) || (CPU == PPCEC603))
    UINT32 excHandMmu[] = {0x7c0802a6,   /* mflr r0 - save link register */
			   0x3c200000,   /* lis r1,HI(mmuXxxHandler)     */ 
			   0x60210000,   /* ori r1,r1,LO(mmuXxxHandler)  */
			   0x7c2803a6,   /* mtlr r1 - load link register */
			   0x4e800021};  /* blrl */
#endif	/* ((CPU == PP603) || (CPU == PPCEC603)) */

    /* check if the MMU type to initialize is coherent */

    if (!(mmuType & MMU_INST) && !(mmuType & MMU_DATA))
	{
	/*
	 * too soon in boot process to print a string, so store one in the
	 * exception message area.
	 */
	strcpy(sysExcMsg, "6xx MMU config failed: either enable I or D MMU, "
			  "or remove MMU support\n");
	return (ERROR);
	}

    /* save the Data and/or Instruction MMU selected */

    mmuPpcSelected =  mmuType;

    /* initiliaze the BAT register */

    if (pSysBatDesc != NULL)
    {
       if( _pSysBatInitFunc == NULL)
       {
    	  mmuPpcBatInit (pSysBatDesc);
       }
       else
       {
    	  (*_pSysBatInitFunc) (pSysBatDesc);
       }
       mmuPpcTlbInvalidateAll();
    }

#if 	((CPU == PPC603) || (CPU == PPCEC603))
    /* initialize the exception table */
    if (!excExtendedVectors) 
	{
	if (mmuType & MMU_INST)
	    {
	    * (int *) _EXC_OFF_INST_MISS = 0x48000002 |
			    (((int) mmuPpcInstMissHandler) & 0x03ffffff);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_INST_MISS, sizeof(int));
	    }

	if (mmuType & MMU_DATA)
	    {
	    * (int *) _EXC_OFF_LOAD_MISS = 0x48000002 |
			    (((int) mmuPpcDataLoadMissHandler) & 0x03ffffff);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_LOAD_MISS, sizeof(int));

	    * (int *) _EXC_OFF_STORE_MISS = 0x48000002 |
			    (((int) mmuPpcDataStoreMissHandler) & 0x03ffffff);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_STORE_MISS, sizeof(int));
	    }
	}
    else
	{
	/*
	 * Copy to each vector standard long branch stub,
	 * and load exact handler address into each stub.
	 */
	if (mmuType & MMU_INST)
	    {
	    memcpy ((void*)_EXC_OFF_INST_MISS, &excHandMmu[0],
			sizeof(excHandMmu));
	    *(int*)(_EXC_OFF_INST_MISS + 0x4)
		|= MSW((int) mmuPpcInstMissHandlerLongJump);
	    *(int*)(_EXC_OFF_INST_MISS + 0x8)
		|= LSW((int) mmuPpcInstMissHandlerLongJump);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_INST_MISS, sizeof(excHandMmu));
	    }

	if (mmuType & MMU_DATA)
	    {
	    memcpy ((void*)_EXC_OFF_LOAD_MISS, &excHandMmu[0],
			sizeof(excHandMmu));
	    *(int*)(_EXC_OFF_LOAD_MISS + 0x4)
		|= MSW((int) mmuPpcDataLoadMissHandlerLongJump);
	    *(int*)(_EXC_OFF_LOAD_MISS + 0x8)
		|= LSW((int) mmuPpcDataLoadMissHandlerLongJump);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_LOAD_MISS, sizeof(excHandMmu));

	    memcpy ((void*)_EXC_OFF_STORE_MISS, &excHandMmu[0],
			sizeof(excHandMmu));
	    *(int*)(_EXC_OFF_STORE_MISS + 0x4)
		|= MSW((int) mmuPpcDataStoreMissHandlerLongJump);
	    *(int*)(_EXC_OFF_STORE_MISS + 0x8)
		|= LSW((int) mmuPpcDataStoreMissHandlerLongJump);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_STORE_MISS, sizeof(excHandMmu));
	    }
	}

#endif	/* ((CPU == PP603) || (CPU == PPCEC603)) */

    /* initialize the Segment Registers */
     
    srVal.bit.t = 0;
    srVal.bit.ks = 1;
    srVal.bit.kp = 1;
    srVal.bit.n = 0;
    srVal.bit.vsid = 0;
    
    for (entryNb = 0; entryNb < 16; entryNb++)		/* XXX TPR to fix */
	{
	mmuPpcSrSet (entryNb, srVal.value);
	srVal.bit.vsid += 0x100;
	}

    pMemDesc =  (PHYS_MEM_DESC *) pPhysMemDesc;

    /* 
     * compute the total size of memory to map by reading the
     * sysPhysMemDesc[] table.
     */

    for (entryNb = 0; entryNb < sysPhysMemDescNumEnt; entryNb++)
	{
	memSize += sysPhysMemDesc[entryNb].len;
	}

    /* */

    memSize = (memSize - 1) / 0x800000 ;
    
    position = 0;

    do
	memSize = memSize >> 1;
    while ((++position < mmuPpcHashTabInfoNumEnt) & (memSize != 0));
	
    mmuGlobalTransTbl.hTabOrg	   = mmuPpcHashTabInfo[position].hashTabOrgMask;
    mmuGlobalTransTbl.hTabMask	   = mmuPpcHashTabInfo[position].hastTabMask;
    mmuGlobalTransTbl.pteTableSize = mmuPpcHashTabInfo[position].pteTabMinSize;

    /*
     * allocate memory to save PTEs
     * The mimimum size depends of the total memory to map.
     */

    mmuGlobalTransTbl.hTabOrg &=
		(u_int) memalign (mmuGlobalTransTbl.pteTableSize,
					mmuGlobalTransTbl.pteTableSize);

    /* invalided all PTE in the table */

    memset ((void *) mmuGlobalTransTbl.hTabOrg, 0x00,
    						mmuGlobalTransTbl.pteTableSize);

    /* initialize the data objects that are shared with vmLib.c */

    mmuStateTransArray = &mmuStateTransArrayLocal [0];

    mmuStateTransArraySize =
		sizeof (mmuStateTransArrayLocal) / sizeof (STATE_TRANS_TUPLE);

    mmuLibFuncs = mmuLibFuncsLocal;

    mmuPageBlockSize = PAGE_SIZE;

    return (OK);

    }

#if	FALSE
/******************************************************************************
*
* mmuPpcMemPagesWriteEnable - write enable the memory holding PTEs
*
* Each translation table has a linked list of physical pages that contain its
* table and page descriptors.  Before you can write into any descriptor, you
* must write enable the page it is contained in.  This routine enables all
* the pages used by a given translation table.
*
*/

LOCAL STATUS mmuPpcMemPagesWriteEnable
    (
    MMU_TRANS_TBL * pTransTbl
    )
    {
    u_int thisPage; 

    thisPage = pTransTbl->hTabOrg;

    while (thisPage < (pTransTbl->hTabOrg + pTransTbl->pteTableSize))
	{
	if (mmuPpcStateSet (pTransTbl, (void *) thisPage,
			MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE) == ERROR)
	    return (ERROR) ;

	thisPage += PAGE_SIZE;
	}
    return (OK);
    }
#endif	/* FALSE */

/******************************************************************************
*
* mmuPpcMemPagesWriteDisable - write disable memory holding PTEs
*
* Memory containing translation table descriptors is marked as read only
* to protect the descriptors from being corrupted.  This routine write protects
* all the memory used to contain a given translation table's descriptors.
*
*/

LOCAL void mmuPpcMemPagesWriteDisable
    (
    MMU_TRANS_TBL * pTransTbl
    )
    {
    u_int thisPage; 

    thisPage = pTransTbl->hTabOrg;

    while (thisPage < (pTransTbl->hTabOrg + pTransTbl->pteTableSize))
	{
	if (mmuPpcStateSet (pTransTbl,(void *)  thisPage,
			MMU_STATE_MASK_WIMG_AND_WRITABLE, 
			MMU_STATE_WRITABLE_NOT  | MMU_STATE_GUARDED_NOT |
			MMU_STATE_MEM_COHERENCY | MMU_STATE_CACHEABLE_COPYBACK)
			== ERROR)
	    return ;

	thisPage += PAGE_SIZE;
	}
    }

/******************************************************************************
*
* mmuPpcTransTblCreate - create a new translation table.
*
*/

LOCAL MMU_TRANS_TBL * mmuPpcTransTblCreate 
    (
    )
    {
    MMU_TRANS_TBL *	pNewTransTbl;
    static BOOL		firstTime = TRUE;	/* first time call flag */


    if (firstTime)
	{
	firstTime = FALSE;
	pNewTransTbl = &mmuGlobalTransTbl;
	}
    else
	{

	/* allocate a piece of memory to save the new translation table */

	pNewTransTbl = (MMU_TRANS_TBL *) malloc (sizeof (MMU_TRANS_TBL));

	/* if the memory can not allocated then return the NULL pointer */

	if (pNewTransTbl == NULL)
	    return (NULL);

	/* 
	 * initilialize the new translation table. 
	 * If the initialization falls then free the memory and return the NULL
	 * pointer.
	 */

	if (mmuPpcTransTblInit (pNewTransTbl) == ERROR)
	    {
	    free ((char *) pNewTransTbl);
	    return (NULL);
	    }
	}

    /* return the new translation table created */

    return (pNewTransTbl);
    }

/******************************************************************************
*
* mmuPpcTransTblInit - initialize a new translation table 
*
* Initialize a new translation table.  The level 1 table is copyed from the
* global translation mmuPpcGlobalTransTbl, so that we
* will share the global virtual memory with all
* other translation tables.
* 
* RETURNS: OK or ERROR if unable to allocate memory. 
*/

LOCAL STATUS mmuPpcTransTblInit 
    (
    MMU_TRANS_TBL * pNewTransTbl	/* translation table to initialize */
    )
    {
    void *	pPtegTable;

    pNewTransTbl->pteTableSize	= mmuGlobalTransTbl.pteTableSize;
    pNewTransTbl->hTabMask	= mmuGlobalTransTbl.hTabMask;

    pPtegTable = memalign (pNewTransTbl->pteTableSize,
						pNewTransTbl->pteTableSize);

    if (pPtegTable == NULL)
	return (ERROR);

    pNewTransTbl->hTabOrg = (u_int) pPtegTable ;
    
    memcpy ((void *) (pNewTransTbl->hTabOrg),
            (void *) (mmuGlobalTransTbl.hTabOrg),
	    pNewTransTbl->pteTableSize);

    mmuPpcMemPagesWriteDisable (pNewTransTbl);

    return (OK);
    }

/******************************************************************************
*
* mmuPpcTransTblDelete - delete a translation table.
* 
* This routine deletes a translation table.
*
* RETURNS: OK always.
*/

LOCAL STATUS mmuPpcTransTblDelete 
    (
    MMU_TRANS_TBL * pTransTbl		/* translation table to be deleted */
    )
    {

    /* free the PTEG table */

    free ((void *) pTransTbl->hTabOrg);

    /* free the translation table data structure */

    free (pTransTbl);

    return (OK);
    }

/******************************************************************************
*
* mmuPpcEnable - turn mmu on or off
*
* RETURNS: OK
*/

LOCAL STATUS mmuPpcEnable 
    (
    BOOL enable			/* TRUE to enable, FALSE to disable MMU */
    )
    {
    int lockKey;		/* lock key for intUnlock() */

    if (enable)
	{
	/* lock the interrupt */

	lockKey = intLock ();

	if (mmuPpcSelected & MMU_INST)
	    {
	    mmuPpcAEnable (MMU_I_ADDR_TRANS);	/* enable instruction MMU */
	    mmuPpcIEnabled = TRUE;		/* tell I MMU is turned on */

	    /* test if the Instruction cache should be enabled too */

	    if (cacheIToEnable)			
		cacheArchEnable (_INSTRUCTION_CACHE);	/* enable the I cache */
	    }

	if (mmuPpcSelected & MMU_DATA)
	    {
	    mmuPpcAEnable (MMU_D_ADDR_TRANS);	/* enable data MMU */
	    mmuPpcDEnabled = TRUE;		/* tell D MMU is turned on */

	    /* test if the Data cache should be enabled too */

	    if (cacheDToEnable)
		cacheArchEnable (_DATA_CACHE);		/* enable the D cache */
	    }

	intUnlock (lockKey);			/* unlock the interrupt */

	}
    else
	{
	lockKey = intLock ();			/* lock the Interrupt */

	if (mmuPpcSelected & MMU_INST)
	    {
	    /*
	     * if the Instruction cache is enabled, then disable the 
	     * instruction cache before to disable the Instruction MMU.
	     */
	    if (cacheIToEnable)
		cacheArchDisableFromMmu (_INSTRUCTION_CACHE);

	    /* disable the Instruction MMU */

	    mmuPpcADisable (MMU_I_ADDR_TRANS);

	    /* set the flag to tell that the Instruction MMU is disabled */

	    mmuPpcIEnabled = FALSE;
	    }

	if (mmuPpcSelected & MMU_DATA)
	    {
	    /*
	     * if the Data cache is enabled, then disable the Data cache
	     * to disable the Data MMU.
	     */
	    if (cacheDToEnable)
		cacheArchDisableFromMmu (_DATA_CACHE);

	    /* disable the Data MMU */

	    mmuPpcADisable (MMU_D_ADDR_TRANS);

	    /* set the flag to tell that the Data MMU is disabled */
	    mmuPpcDEnabled = FALSE;
	    }

	intUnlock (lockKey);			/* unlock the interrupt */

	}

    return (OK);
    }

/******************************************************************************
*
* mmuPpcStateSet - set state of virtual memory page
*
*
* MMU_STATE_VALID	MMU_STATE_VALID_NOT	valid/invalid
* MMU_STATE_WRITABLE	MMU_STATE_WRITABLE_NOT	writable/writeprotected
* MMU_STATE_CACHEABLE	MMU_STATE_CACHEABLE_NOT	cachable/notcachable
* MMU_STATE_CACHEABLE_WRITETHROUGH
* MMU_STATE_CACHEABLE_COPYBACK
* MMU_STATE_MEM_COHERENCY	MMU_STATE_MEM_COHERENCY_NOT
* MMU_STATE_GUARDED		MMU_STATE_GUARDED_NOT
* MMU_STATE_NO_ACCESS
* MMU_STATE_NO_EXECUTE
*/

LOCAL STATUS mmuPpcStateSet 
    (
    MMU_TRANS_TBL *	pTransTbl, 	/* translation table */
    void *		effectiveAddr,	/* page whose state to modify */ 
    UINT 		stateMask,	/* mask of which state bits to modify */
    UINT		state		/* new state bit values */
    )
    {
    PTE *	pPte;		/* PTE address */
    PTE		pte;		/* PTE value */

    /* 
     * Try to find in the PTEG table pointed to by the pTransTbl structure,
     * the PTE corresponding to the <effectiveAddr>.
     * If this PTE can not be found then return ERROR.
     */

    if (mmuPpcPteGet (pTransTbl, effectiveAddr, &pPte) != OK)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* 
     * Check if the state to set page corresponding to <effectiveAddr> will
     * not set the cache in inhibited and writethrough mode. This mode is not
     * supported by the cache.
     */

    if ((stateMask & MMU_STATE_MASK_CACHEABLE) &&
	(state & MMU_STATE_CACHEABLE_NOT) &&
	(state & MMU_STATE_CACHEABLE_WRITETHROUGH))
	{
	return (ERROR);
	}

    /* load the value of the PTE pointed to by pPte to pte */

    pte = *pPte;

    /* set or reset the VALID bit if requested */

    pte.bytes.word0 = (pte.bytes.word0 & ~(stateMask & MMU_STATE_MASK_VALID)) |
			(state & stateMask & MMU_STATE_MASK_VALID); 

    /* set or reset the WIMG bit if requested */

    pte.bytes.word1 = (pte.bytes.word1 &
			~(stateMask & MMU_STATE_MASK_WIMG_AND_WRITABLE)) |
			 (state & stateMask & MMU_STATE_MASK_WIMG_AND_WRITABLE);


    /* update the PTE in the table */

    mmuPpcPteUpdate (pPte, &pte);

    /* update the Translation Lookside Buffer */

    mmuPpcTlbie (effectiveAddr);

    return (OK);
    }

/******************************************************************************
*
* mmuPpcStateGet - get state of virtual memory page
*
*/

LOCAL STATUS mmuPpcStateGet 
    (
    MMU_TRANS_TBL *	pTransTbl,	/* tranlation table */
    void *		effectiveAddr, 	/* page whose state we're querying */
    UINT *		state		/* place to return state value */
    )
    {
    PTE *	pPte;		/* PTE address */

    /* 
     * Try to find the PTE corresponding to the <effectiveAddr> in the PTEG
     * table pointed to by the pTransTbl structure,
     * If this PTE can not be found then return ERROR.
     */

    if (mmuPpcPteGet (pTransTbl, effectiveAddr, &pPte) != OK)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* extract the state of the VALID  and WIMG bit */

    * state  = pPte->bytes.word0 & MMU_STATE_MASK_VALID;
    * state |= pPte->bytes.word1 & MMU_STATE_MASK_WIMG_AND_WRITABLE;

    return (OK);
    }

/******************************************************************************
*
* mmuPpcPageMap - map physical memory page to virtual memory page
*
* The physical page address is entered into the pte corresponding to the
* given virtual page.  The state of a newly mapped page is undefined. 
*
* RETURNS: OK or ERROR if translation table creation failed. 
*/

LOCAL STATUS mmuPpcPageMap 
    (
    MMU_TRANS_TBL *	pTransTbl, 	/* translation table */
    void *		effectiveAddr, 	/* effective address */
    void *		physicalAddr	/* physical address */
    )
    {
    PTE *	pPte;			/* PTE address */
    PTE		pte;			/* PTE value */
    PTEG *	pPteg1;			/* PTEG 1 address */
    PTEG *	pPteg2;			/* PTEG 2 address */
    UINT	vsid;			/* virtual segment ID */
    UINT	api;			/* abbreviated page index */
    UINT	pteIndex;		/* PTE index in a PTEG */
    UINT	hashLevel;		/* hash table level */

    if (mmuPpcPteGet (pTransTbl, effectiveAddr, &pPte) == OK)
	{
	pte = * pPte;
	}
    else
	{
	/* get the address of both PTEGs, VSID and API value */

	mmuPpcPtegAddrGet (pTransTbl, effectiveAddr, &pPteg1,
							&pPteg2, &vsid, &api);

	pteIndex = 0;
	pPte = NULL;
	hashLevel = 0;

	/*
	 * read the PTEs of the first group. If one of the PTE matchs
	 * the expected PTE then extrats the physical address from the PTE
	 * word 1 and exits the function with OK. If not, chechs the next PTE.
	 * If no PTE matchs the expected PTE then read the second group.
	 */

	do
	    {
	    if (pPteg1->pte[pteIndex].field.v == FALSE)
		{
		pPte = &pPteg1->pte[pteIndex];
		hashLevel = 0;
		break;
		}

            if (pPteg2->pte[pteIndex].field.v == FALSE)
	     	{ 
		pPte = &pPteg2->pte[pteIndex];
		hashLevel = 1;
		}
	    }
	while (++pteIndex < MMU_PTE_BY_PTEG);

	if (pPte == NULL)
	    {
	    errno = S_mmuLib_NO_DESCRIPTOR;
	    return (ERROR);
	    }

	pte.field.v = TRUE;		/* entry valid */
	pte.field.vsid = vsid;
	pte.field.h = hashLevel;
	pte.field.api = api;
	pte.field.r = 0;
	pte.field.c = 0;
	pte.field.wimg = 0;		/* cache writethrough mode */
	pte.field.pp = 2;		/* read/write */
	}

    pte.field.rpn = (u_int) physicalAddr >> MMU_PTE_RPN_SHIFT;

    mmuPpcPteUpdate (pPte, &pte);

    mmuPpcTlbie (effectiveAddr);

    return (OK);
    }

/******************************************************************************
*
* mmuPpcGlobalPageMap - map physical memory page to global virtual memory page
*
* mmuPpcGlobalPageMap is used to map physical pages into global virtual memory
* that is shared by all virtual memory contexts.  The translation tables
* for this section of the virtual space are shared by all virtual memory
* contexts.
*
* RETURNS: OK or ERROR if no pte for given virtual page.
*/

LOCAL STATUS mmuPpcGlobalPageMap 
    (
    void *  effectiveAddr, 	/* effective address */
    void *  physicalAddr	/* physical address */
    )
    {
    return (mmuPpcPageMap (&mmuGlobalTransTbl, effectiveAddr, physicalAddr));
    }

/******************************************************************************
*
* mmuPpcTranslate - translate a virtual address to a physical address
*
* Traverse the translation table and extract the physical address for the
* given virtual address from the pte corresponding to the virtual address.
*
* RETURNS: OK or ERROR if no pte for given virtual address.
*/

LOCAL STATUS mmuPpcTranslate 
    (
    MMU_TRANS_TBL *	pTransTbl,	/* translation table */
    void *		effectiveAddr,	/* effective address */
    void **		physicalAddr	/* where to place the result */
    )
    {
    PTE *	pPte;		/* PTE address */

    /* 
     * Try to find the PTE corresponding to the <effectiveAddr> in the PTEG
     * table pointed to by the pTransTbl structure,
     * If this PTE can not be found then return ERROR.
     */

    if (mmuPpcPteGet (pTransTbl, effectiveAddr, &pPte) != OK)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* extact the physical address save in the PTE */

    * physicalAddr = (void *) (((u_int) pPte->bytes.word1 & MMU_PTE_RPN) |
                               ((u_int) effectiveAddr & ~MMU_PTE_RPN));

    return (OK);
    }

/******************************************************************************
*
* mmuPpcCurrentSet - change active translation table
*
*/

 void mmuPpcCurrentSet 
    (
    MMU_TRANS_TBL * pTransTbl	/* new active tranlation table */
    ) 
    {
    int		lockKey;			/* intLock lock key */
    static BOOL	firstTime = TRUE;	/* first time call flag */

    if (firstTime)
	{
	/*
	 * write protect all the pages containing the PTEs allocated for
	 * the global translation table.  Need to do this because when this
	 * memory is allocated, the global translation table doesn't exist yet.
	 */

	 mmuPpcMemPagesWriteDisable (&mmuGlobalTransTbl);
	 mmuPpcMemPagesWriteDisable (pTransTbl);

	 firstTime = FALSE;
	 }

    lockKey = intLock ();

    /* 
     * the SDR1 register MUST NOT be altered when the MMU is enabled
     * (see "PowerPc Mircoprocessor Family: The Programming Environments
     * page 2-40 note Nb 5."
     * If the MMU is enabled then turn it off, change SDR1 and
     * enabled it again. Otherwise change SDR1 value.
     */

    if ((mmuPpcIEnabled)  || (mmuPpcDEnabled))
	{
	mmuPpcEnable (FALSE);			/* disable the MMU */
    	mmuPpcSdr1Set (pTransTbl->hTabOrg | pTransTbl->hTabMask);
	mmuPpcEnable (TRUE);			/* re-enable  the MMu */
	}
    else
	mmuPpcSdr1Set (pTransTbl->hTabOrg | pTransTbl->hTabMask);

    intUnlock (lockKey);
    }

/*******************************************************************************
*
* mmuPpcPteGet - get the address of a PTE of a given effective address
* 
* This routine finds the PTE address corresponding to the <effectiveAddr> in
* the PTEG table pointed to by <pTransTbl> structure. If a matching PTE
* existe, the routine save the PTE address at the address pointed to by <ppPte>.
* If any PTE matching the <effectiveAddr> is not found then the function
* return ERROR.
*
* RETURNS: OK or ERROR.
*/

LOCAL STATUS mmuPpcPteGet
    (
    MMU_TRANS_TBL *	pTransTbl,	/* translation table */
    void *		effectiveAddr,	/* effective address */
    PTE **		ppPte		/* result */
    )
    {
    PTEG *	pPteg1;			/* PTEG 1 address */
    PTEG *	pPteg2;			/* PTEG 2 address */
    UINT	vsid;			/* virtual segment ID */
    UINT	api;			/* abbreviated page index */
    UINT	pteIndex;		/* PTE index in a PTEG */

    /* get the address of both PTEGs, the VSID and API values */

    mmuPpcPtegAddrGet (pTransTbl, effectiveAddr, &pPteg1, &pPteg2, &vsid, &api);

    pteIndex = 0;

    /*
     * read the PTEs of the first group. If one of the PTE matchs
     * the expected PTE then extrats the physical address from the PTE word 1
     * and exits the function with OK. If not, checks the next PTE. If no PTE
     * matchs the expected PTE in the first PTEG then read the second PTEG.
     */

    do
	{
	if ((pPteg1->pte[pteIndex].field.v    == TRUE) &&
	    (pPteg1->pte[pteIndex].field.vsid == vsid) &&
	    (pPteg1->pte[pteIndex].field.api  == api) &&
	    (pPteg1->pte[pteIndex].field.h    == 0 ))
	    {
	    * ppPte = &pPteg1->pte[pteIndex];
	    return (OK);
	    }
	}
    while (++pteIndex < MMU_PTE_BY_PTEG);

    pteIndex = 0;

    /*
     * read the PTEs of the second PTEG. If one of the PTE matchs
     * the expected PTE then extrats the physical address from the PTE word 1
     * and exit the function with OK. If not check the next PTE. If no PTE
     * match the expected PTE then exit the function with ERROR.
     */

    do
	{
	if ((pPteg2->pte[pteIndex].field.v    == TRUE) &&
	    (pPteg2->pte[pteIndex].field.vsid == vsid) &&
	    (pPteg2->pte[pteIndex].field.api  ==  api) &&
	    (pPteg2->pte[pteIndex].field.h    == 1 ))
	    {
	    * ppPte = &pPteg2->pte[pteIndex];
	    return (OK);
	    }
	}
    while (++pteIndex < MMU_PTE_BY_PTEG);

    return (ERROR);
    }
 
/*******************************************************************************
*
* mmuPpcPtegAddrGet - get the address of the two Page Table Entry Groups (PTEG)
*
*/

LOCAL void mmuPpcPtegAddrGet
    (
    MMU_TRANS_TBL *	pTransTbl,		/* translation table */
    void *		effectiveAddr,		/* effective address */
    PTEG **		ppPteg1,		/* page table entry group 1 */
    PTEG **		ppPteg2,		/* page table entry group 2 */
    u_int *		pVirtualSegId,		/* virtual segment Id value */
    u_int *		pAbbrevPageIndex	/* abbreviated page index */
    )
    {
    SR		srVal;			/* segment register value */
    UINT 	pageIndex;		/* page index value */
    UINT	primHash;		/* primary hash value */
    UINT	hashValue1;		/* hash value 1 */
    UINT	hashValue2;		/* hash value 2 */
    UINT	hashValue1L;
    UINT	hashValue1H;
    UINT	hashValue2L;
    UINT	hashValue2H;
    EA		effAddr;

    effAddr = * ((EA *)  &effectiveAddr);

    srVal.value =  mmuPpcSrGet (effAddr.srSelect);

    * pVirtualSegId = srVal.bit.vsid ;

    pageIndex = effAddr.pageIndex;

    * pAbbrevPageIndex = (pageIndex & MMU_EA_API) >> MMU_EA_API_SHIFT;

    primHash = srVal.bit.vsid & MMU_VSID_PRIM_HASH;

    hashValue1 = primHash ^ pageIndex;

    hashValue2 = ~ hashValue1;

    hashValue1L = (hashValue1 & MMU_HASH_VALUE_LOW) << MMU_PTE_HASH_VALUE_LOW_SHIFT;
    hashValue1H = (hashValue1 & MMU_HASH_VALUE_HIGH) >> MMU_HASH_VALUE_HIGH_SHIFT;

    hashValue2L = (hashValue2 & MMU_HASH_VALUE_LOW) << MMU_PTE_HASH_VALUE_LOW_SHIFT;
    hashValue2H = (hashValue2 & MMU_HASH_VALUE_HIGH) >> MMU_HASH_VALUE_HIGH_SHIFT;

    hashValue1H = (hashValue1H & pTransTbl->hTabMask) << MMU_PTE_HASH_VALUE_HIGH_SHIFT ;
    hashValue2H = (hashValue2H & pTransTbl->hTabMask) << MMU_PTE_HASH_VALUE_HIGH_SHIFT;

    * ppPteg1 = (PTEG *) (pTransTbl->hTabOrg | hashValue1H | hashValue1L);

    * ppPteg2 = (PTEG *) (pTransTbl->hTabOrg | hashValue2H | hashValue2L);

    }

/*******************************************************************************
*
* mmuPpcPteUpdate - update a PTE value 
*
*/
LOCAL void  mmuPpcPteUpdate
    (
    PTE *	pteAddr,	/* address of the PTE to update */
    PTE *	pteVal		/* PTE value */
    )
    {

    if ((mmuPpcIEnabled) | (mmuPpcDEnabled))
	{
	mmuPpcEnable (FALSE);			/* disable the mmu */
	memcpy ((void *) pteAddr, pteVal, sizeof (PTE));
	mmuPpcEnable (TRUE);
	}
    else
	memcpy ((void *) pteAddr, pteVal, sizeof (PTE));
    }

#if	(CPU == PPC604)
/*******************************************************************************
*
* mmuPpcBatInitMPC74x5 - Initialize the BAT's on the MPC7455
*
* This routine initializes the I & D BAT's on the MPC7455
*
* RETURNS: None
*/

void mmuPpcBatInitMPC74x5 
  (
  UINT32 *pSysBatDesc /* Pointer to the Bat Descriptor array. */
  )
  {

  /* initialize first 4 w/ pre-existing routine - no status */
  mmuPpcBatInit (pSysBatDesc);

  /* 
   * initialize other 4 w/ MPC 7[45]x specific asm routine,
   *  since it also works for 74[45]x
   *
   *  2*8*4 = 2 (UBAT,LBAT) , 8 (4 IBAT + 4 DBAT) , 4 (sizeof UINT32)
   */
  mmuPpcExtraBatInit ((UINT32 *)((UINT32)pSysBatDesc + 2*8*4));

  /* Turn on extra BAT's in HID0 */
  mmuPpcExtraBatEnableMPC74x5();
  }
    
/*******************************************************************************
*
* mmuPpcBatInitMPC7x5 - Initialize the BAT's on the MPC755
*
* This routine initializes the I & D BAT's on the MPC755
*
* RETURNS: None
*/

void mmuPpcBatInitMPC7x5 
  (
  UINT32 *pSysBatDesc
  )
  {

  /* initialize first 4 w/ pre-existing routine - no status */
  mmuPpcBatInit (pSysBatDesc);

  /* 
   * initialize other 4 w/ MPC 7[45]x specific asm routine
   *
   *  2*8*4 = 2 (UBAT,LBAT) , 8 (4 IBAT + 4 DBAT) , 4 (sizeof UINT32)
   */
  mmuPpcExtraBatInit ((UINT32 *)((UINT32)pSysBatDesc + 2*8*4));


  /* Turn on extra BAT's in HID2 */
  mmuPpcExtraBatEnableMPC7x5();
  }

/******************************************************************************
*
* mmuPpcBatInit750fx - Initialize the BAT's on the IBM PPC750FX
*
* This routine initializes the I & D BAT's on the IBM PPC750FX
*
* RETURNS: None
*/

void mmuPpcBatInit750fx
    (
    UINT32 *pSysBatDesc
    )
    {

    /* initialize first 4 w/ pre-existing routine - no status */
    mmuPpcBatInit (pSysBatDesc);

    /*
     * initialize other 4 w/ PPC 7[45]x specific asm routine,
     *   since it also works for 750FX
     *
     *  2*8*4 = 2 (UBAT,LBAT) , 8 (4 IBAT + 4 DBAT) , 4 (sizeof UINT32)
     */
    mmuPpcExtraBatInit ((UINT32 *)((UINT32)pSysBatDesc + 2*8*4));

    /* No separate enable function:  750FX extra BAT's are always on */
    }
#endif /* CPU == PPC604 */


#if	FALSE			/* under construction */	
/*******************************************************************************
*
* mmuPpcSrRegInit - initialize the Segment Registers (SR)
*
*
*/

STATUS mmuPpcSrRegInit
    (
    PHYS_MEM_DESC *	pPhysMemDesc,	/* phycical Memory description */
    UINT		elementNb,	/* element number in the desc. */
    PTEG *		pPtegTbl,	/* PTEG table */
    MMU_TRANS_TBL *	pTransTbl	/*  */
    )
    {
    SR_TABLE *	pAddrTbl;
    u_int	index;
    void *	address = 0x00;
    u_int	entryNb;
    SR		srVal = 0;
    u_int	hashValue;
    u_int	hashValueL;
    u_int	hashValueH;

    pAddrTbl = (SR_TABLE *) malloc (16 * sizeof (SR_TABLE));

    if (pAddrTbl == NULL)
	return (ERROR);

    /* init the address table */

    for (index = 0; index < 16; index++)
	{
	pAddrTbl[index].lowAddr  = address + 0x01000000 - 1 ;
	pAddrTbl[index].highAddr = address ;
	}

    for (entryNb = 0; entryNb < elementNb; entryNb++)
	{
	index = ((EA)pPhysMemDesc[entryNb]->virtualAddr).srSelect 

	pAddrTbl[index]->lowAddr = min (pAddrTbl[index].lowAddr,
				pPhysMemDesc[entryNb]->virtualAddr);

	index = ((EA) pPhysMemDesc[entryNb]->virtualAddr + len).srSelect 

	pAddrTbl[index]->highAddr = max (pAddrTbl[index].highAddr,
				pPhysMemDesc[entryNb]->virtualAddr + len - 1);

	}

    srVal.bit.t = 0;
    srVal.bit.ks = 1;
    srVal.bit.kp = 1;
    srVal.bit.n = 0;

    hashValueL = (pPtegTbl & MMU_PTE_HASH_VALUE_LOW_MASK) >> MMU_PTE_HASH_VALUE_LOW_SHIFT;

    hashValueH = (pPtegTbl & MMU_PTE_HASH_VALUE_HIGH_MASK) >> MMU_PTE_HASH_VALUE_HIGH_SHIFT;

    hashValueH = (hashValueH & pTransTbl->hTabMask) << MMU_HASH_VALUE_HIGH_SHIFT;

    hashValue = (hashValueH & MMU_HASH_VALUE_HIGH) | (hashValueL & MMU_HASH_VALUE_LOW);
    srVal.bit.vsid = (hashValue ^ pAddrTbl[0]->lowAddr. ;

    for (index = 0; index < 16; index++)
	{


    free (pAddrTbl);

    return (OK);
    }


 void mmmuPpcPteShow 
    (
    MMU_TRANS_TBL *	pTransTbl,		/* translation table */
    void *		effectiveAddr		/* effective address */
    )
    {
    PTE *	pte;

    if (mmuPpcPteGet (pTransTbl, effectiveAddr, &pte) == ERROR)
	return ;

    printf ("v		= %d\n", pte->field.v);
    printf ("vsid	= 0x%x\n", pte->field.vsid);
    printf ("h		= %d\n", pte->field.h);
    printf ("api	= 0x%x\n", pte->field.api);
    printf ("rpn	= 0x%x\n", pte->field.rpn);
    printf ("r		= %d\n", pte->field.r);
    printf ("c		= %d\n", pte->field.c);
    printf ("wimg	= 0x%x\n", pte->field.wimg);
    printf ("pp		= 0x%x\n", pte->field.pp);
    }

#endif
