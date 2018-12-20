/* mmu800Lib.c - mmu library for PowerPC 800 serie */

/* Copyright 1984-1999 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01n,21may02,dtr  Changing mmu segment cache properties copyback<->writhrough
                 must rely on user to have the 4MB aligned SEGMENT in a known
		 safe cache state. mmu800StateSet cannot make any other 
                 assumption.
01m,16may02,dtr  Fix mmu800TransTblDelete. Ignores global descriptors. SPR 77463
01l,03may02,dtr  Fixes to cache flush and tlbie for l1descriptor updates.
01k,25apr02,pch  SPR 74926: don't connect to unused vector
		 SPR 67973: add exception message for MMU config failure
01j,24apr02,dtr  Fixing function mmu800StateGet/Set and tidying up 
                 TransTblDelete. Also getting mmu800Show routine to work in
		 a useful manner. Some additions for cache.
01i,22mar02,dtr  Adding in write set/unset to mmu800StateSet.
01h,06nov01,dtr  Putting in full 32-bit branch support for exception handler.
01g,09apr99,tpr  Surrounded L1/L2 tables update with intLock/Unlock(SPR #26522)
01f,05feb97,tpr  replaced reserved by field.reserved (SPR #7783).
01e,10nov96,tpr  removed debug function from the normal compilation.
01d,29oct96,tam	 added missing modification history entries; added a few
		 extra comments.
01c,24jun96,tpr	 remove MI_CTR and MD_CTR init; move init to sysALib.s.
01b,18jun96,tpr	 changed mmu860XXX() name by mmu800XXX()
		 correct mmu800lib.h file name.
01a,27apr96,tpr	 written.
*/

/*
DESCRIPTION:
mmu800Lib.c provides the architecture dependent routines that directly
control the memory management unit for the PowerPC 800 serie.  It provides 
routines that are called by the higher level architecture independent 
routines in vmLib.c or vmBaseLib.c

Note :
The 8xx CPU has two levels of descriptors for the MMU TLB's:
L1Desc covers 4MB SEGMENTS (1024 L2Descriptors * PAGE_SIZE )
L2Desc covers PAGES (4096 Bytes fixed)
The L1 has writethrough/copyback cache,guarded.
The L2 has cache inhibit,access(R/W,R/O),valid.
These are the only attributes which you can manipulate.
eg Setting a page as guarded means you actually are setting the segment 
which contains that page to be guarded.

*/

/* includes */

#include "vxWorks.h"
#include "cacheLib.h"
#include "errno.h"
#include "intLib.h"
#include "stdlib.h"
#include "stdio.h"
#include "string.h"
#include "vmLib.h"
#include "sysLib.h"
#include "private/memPartLibP.h"
#include "private/vmLibP.h"
#include "arch/ppc/excPpcLib.h"
#include "arch/ppc/mmu800Lib.h"

/* defines */

#define PAGE_SIZE	4096		/* page size of 4K */

/* locals */

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

    {VM_STATE_MASK_GUARDED, MMU_STATE_MASK_GUARDED,
     VM_STATE_GUARDED, MMU_STATE_GUARDED},

    {VM_STATE_MASK_GUARDED, MMU_STATE_MASK_GUARDED,
     VM_STATE_GUARDED_NOT, MMU_STATE_GUARDED_NOT},
    };

LOCAL MMU_TRANS_TBL *	mmu800TransTblCreate ();
LOCAL STATUS		mmu800TransTblDelete (MMU_TRANS_TBL *transTbl);
LOCAL STATUS		mmu800Enable (BOOL enable);
LOCAL STATUS		mmu800StateSet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				     UINT stateMask, UINT state);
LOCAL STATUS		mmu800StateGet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				     UINT *state);
LOCAL STATUS		mmu800PageMap (MMU_TRANS_TBL *transTbl,
				     void * virtualAddress, void *physPage);
LOCAL STATUS		mmu800GlobalPageMap (void * virtualAddress,
				    void * physPage);
LOCAL STATUS		mmu800Translate (MMU_TRANS_TBL * transTbl,
				      void * virtAddress, void ** physAddress);
LOCAL void		mmu800CurrentSet (MMU_TRANS_TBL * transTbl);
LOCAL STATUS		mmu800TransTblInit (MMU_TRANS_TBL * pNewTransTbl);
LOCAL LEVEL_1_DESC *	mmu800Lvl1DescAddrGet (MMU_TRANS_TBL *	pTransTbl,
				    void * effectiveAddr);
LOCAL STATUS		mmu800Lvl2DescAddrGet (MMU_TRANS_TBL * pTransTbl,
				void * effectiveAddr,
				LEVEL_2_DESC ** ppLvl2Desc);
LOCAL void		mmu800Lvl1DescUpdate (LEVEL_1_DESC * pLvl1Desc,
				LEVEL_1_DESC lvl1Desc);
LOCAL void		mmu800Lvl2DescUpdate (LEVEL_2_DESC * pLvl2Desc,
				LEVEL_2_DESC lvl2Desc);
LOCAL BOOL		mmu800IsOn (int mmuType);

IMPORT void	mmuPpcTlbie ();
IMPORT void	mmuPpcAEnable ();
IMPORT void	mmuPpcADisable ();
IMPORT void     mmuPpcMiApSet(UINT32);
IMPORT void     mmuPpcMdApSet(UINT32);
IMPORT void     mmuPpcMCasidSet(UINT32);
IMPORT void     mmuPpcMTwbSet(LEVEL_1_DESC*);
IMPORT void	mmuPpcInstTlbMissHandler();
IMPORT void	mmuPpcDataTlbMissHandler();
IMPORT void	mmuPpcDataTlbErrorHandler();
IMPORT void	mmuPpcInstTlbMissHandlerLongJump();
IMPORT void	mmuPpcDataTlbMissHandlerLongJump();
IMPORT void	mmuPpcDataTlbErrorHandlerLongJump();
IMPORT void     mmuPpcTlbInvalidateAll();
IMPORT UINT32   vxMsrGet();
STATUS cacheArchFlush      (CACHE_TYPE, void *, size_t);
IMPORT STATE_TRANS_TUPLE *	mmuStateTransArray;
IMPORT int			mmuStateTransArraySize;
IMPORT MMU_LIB_FUNCS		mmuLibFuncs;
IMPORT int			mmuPageBlockSize;
IMPORT BOOL	                excExtendedVectors;

/*
 * a translation table to hold the descriptors for the global transparent
 * translation of physical to virtual memory
 */

MMU_TRANS_TBL	mmuGlobalTransTbl;	/* global translation table */	
LOCAL u_int	mmu800Selected;		/* mmu type selected */
LOCAL MMU_LIB_FUNCS mmuLibFuncsLocal =
    {
    mmu800LibInit,
    mmu800TransTblCreate,
    mmu800TransTblDelete,
    mmu800Enable,
    mmu800StateSet,
    mmu800StateGet,
    mmu800PageMap,
    mmu800GlobalPageMap,
    mmu800Translate,
    mmu800CurrentSet
    };

/******************************************************************************
*
* mmu800LibInit - MMU library initialization
*
* RETURNS: OK, or ERROR if <mmuType> is incorrect or memory allocation failed. 
*/

STATUS mmu800LibInit 
    (
    int 	mmuType		/* data and/or instruction MMU to initialize */
    )
    { 
      /* The excVectorHandler for each mmu exception can be long branch or short 
	 branch. The short branch can address 24 bit range. The long branch 
	 32 bit range */  
      /* This long branch stub does the following :	
 	mtspr M_TW,r18          * save r18 
	mfcr  r18          
	stw   r18,-0x4(r1)	* save condition register on stack 0x4
	mfctr r18
	stw   r18,-0x8(r1)      * save counter register on stack 0x8 
	lis   r18, HI(mmuXXXHandler)
	ori   r18, r18, LO(mmuXXXHandler)
	mtctr r18		* jump to mmu handler *
	bctr
	Note: r18 and cr are restored at the end of this routine 
	*/
    UINT32 excHandMmu[] = {0x7e5fc3a6,   /* mtspr M_TW,r18 -  save r18*/ 
       			   0x7e400026,   /* mfcr r18 -  move cr to r18 */
       			   0x9241fffc,   /* save condition register onto stack */
       			   0x7e4902a6,   /*  mfctr r18 -  move ctr to r18 */
       			   0x9241fff8,   /*  save ctr onto stack */
       			   0x3e400000,   /* lis p0,HI(xxHandler) */
       			   0x62520000,   /* ori p0,p0,LO(xxHandler)*/
       			   0x7e4903a6,   /* load ctr with Handler address*/
       			   0x4e800420};  /* branch handler */

    /* check if the MMU type to initialize is coherent */

    if (!(mmuType & MMU_INST) && !(mmuType & MMU_DATA))
	{
	/*
	 * too soon in boot process to print a string, so store one in the
	 * exception message area.
	 */
	strcpy(sysExcMsg, "8xx MMU config failed: either enable I or D MMU, "
			  "or remove MMU support\n");
	return (ERROR);
	}

    /* save the Data and/or Instruction MMU selected */

    mmu800Selected =  mmuType;
    
    /* initialize the exception table */
    if (!excExtendedVectors) 
	{
	if (mmuType & MMU_INST)
	    {
	    * (int *) _EXC_OFF_INST_MISS = 0x48000002 |
			(((int) mmuPpcInstTlbMissHandler) & 0x03ffffff);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_INST_MISS, sizeof(int));
	    }

	if (mmuType & MMU_DATA)
	    {
	    * (int *) _EXC_OFF_DATA_MISS = 0x48000002 |
			(((int) mmuPpcDataTlbMissHandler) & 0x03ffffff);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_DATA_MISS, sizeof(int));

	    * (int *) _EXC_OFF_DATA_ERROR = 0x48000002 |
			(((int) mmuPpcDataTlbErrorHandler) & 0x03ffffff);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_DATA_ERROR, sizeof(int));
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
	    *(int*)(_EXC_OFF_INST_MISS + 0x14)
		|= MSW((int) mmuPpcInstTlbMissHandlerLongJump);
	    *(int*)(_EXC_OFF_INST_MISS + 0x18)
		|= LSW((int) mmuPpcInstTlbMissHandlerLongJump);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_INST_MISS, sizeof(excHandMmu));
	    }

	if (mmuType & MMU_DATA)
	    {
	    memcpy ((void*)_EXC_OFF_DATA_MISS, &excHandMmu[0],
			sizeof(excHandMmu));
	    *(int*)(_EXC_OFF_DATA_MISS + 0x14)
		|= MSW((int) mmuPpcDataTlbMissHandlerLongJump);
	    *(int*)(_EXC_OFF_DATA_MISS + 0x18)
		|= LSW((int) mmuPpcDataTlbMissHandlerLongJump);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_DATA_MISS, sizeof(excHandMmu));

	    memcpy ((void*)_EXC_OFF_DATA_ERROR, &excHandMmu[0],
			sizeof(excHandMmu));
	    *(int*)(_EXC_OFF_DATA_ERROR + 0x14)
		|= MSW((int) mmuPpcDataTlbErrorHandlerLongJump);
	    *(int*)(_EXC_OFF_DATA_ERROR + 0x18)
		|= LSW((int) mmuPpcDataTlbErrorHandlerLongJump);
	    CACHE_TEXT_UPDATE((void *)_EXC_OFF_DATA_ERROR, sizeof(excHandMmu));
	    }
	}

   /* allocate a piece of memory to handle the level 1 Table */

    mmuGlobalTransTbl.l1TblPtr.pL1Desc =
			(LEVEL_1_DESC *) memalign (PAGE_SIZE, PAGE_SIZE);

    /* check the memory allocation */

    if (mmuGlobalTransTbl.l1TblPtr.pL1Desc == NULL)
	return (ERROR);

    /* invalided all enties in the table */

    memset ((void *) mmuGlobalTransTbl.l1TblPtr.pL1Desc, 0x00, PAGE_SIZE);

    /* initialize the Instruction MMU Access Protection Register */

    mmuPpcMiApSet (0xffffffff);

    /* initialize the Data MMU Access Protection Register */

    mmuPpcMdApSet (0xffffffff);

    /* initialize the Instruction MMU Control register */

    mmuPpcMCasidSet (0);
    mmuPpcTlbInvalidateAll();

    /* initialize the data objects that are shared with vmLib.c */

    mmuStateTransArray = &mmuStateTransArrayLocal [0];

    mmuStateTransArraySize =
		sizeof (mmuStateTransArrayLocal) / sizeof (STATE_TRANS_TUPLE);

    mmuLibFuncs = mmuLibFuncsLocal;

    mmuPageBlockSize = PAGE_SIZE;

    return (OK);

    }

/******************************************************************************
*
* mmu800MemPagesWriteEnable - write enable the memory holding PTEs
*
* Each translation table has a linked list of physical pages that contain its
* table and page descriptors.  Before you can write into any descriptor, you
* must write enable the page it is contained in.  This routine enables all
* the pages used by a given translation table.
*
*/

LOCAL STATUS mmu800MemPagesWriteEnable
    (
    MMU_TRANS_TBL * pTransTbl
    )
    {
    return (OK);
    }

/******************************************************************************
*
* mmu800MemPagesWriteDisable - write disable memory holding PTEs
*
* Memory containing translation table descriptors is marked as read only
* to protect the descriptors from being corrupted.  This routine write protects
* all the memory used to contain a given translation table's descriptors.
*
* RETURNS: N/A
*/

LOCAL void mmu800MemPagesWriteDisable
    (
    MMU_TRANS_TBL * pTransTbl
    )
    {
    }

/******************************************************************************
*
* mmu800TransTblCreate - create a new translation table.
*
* RETURNS: address of new object or NULL if allocation failed.
*/

LOCAL MMU_TRANS_TBL * mmu800TransTblCreate 
    (
    )
    {
    MMU_TRANS_TBL *	pNewTransTbl;

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

    if (mmu800TransTblInit (pNewTransTbl) == ERROR)
	{
	free ((char *) pNewTransTbl);
	return (NULL);
	}

    /* return the new translation table created */

    return (pNewTransTbl);
    }

/******************************************************************************
*
* mmu800TransTblInit - initialize a new translation table 
*
* Initialize a new translation table.  The level 1 table is copyed from the
* global translation mmuPpcGlobalTransTbl, so that we
* will share the global virtual memory with all
* other translation tables.
* 
* RETURNS: OK or ERROR if unable to allocate memory. 
*/

LOCAL STATUS mmu800TransTblInit 
    (
    MMU_TRANS_TBL * pNewTransTbl	/* translation table to initialize */
    )
    {
    /* allocat memory space for a new Level 1 descriptor table */

    pNewTransTbl->l1TblPtr.pL1Desc =
			(LEVEL_1_DESC *) memalign (PAGE_SIZE, PAGE_SIZE);
    /* if the memory cannot be allocated then return ERROR */

    if (pNewTransTbl->l1TblPtr.pL1Desc == NULL)
	return (ERROR);
    
    /* copy the global level 1 descriptor table to the new table */

    memcpy ((void *) pNewTransTbl->l1TblPtr.pL1Desc,
			(void *) mmuGlobalTransTbl.l1TblPtr.pL1Desc, PAGE_SIZE);

    /* lock the new level 1 descriptor table modification */
    mmu800MemPagesWriteDisable (pNewTransTbl);

    return (OK);
    }

/******************************************************************************
*
* mmu800TransTblDelete - delete a translation table.
* 
* This routine deletes a translation table.
*
* RETURNS: OK always.
*/

LOCAL STATUS mmu800TransTblDelete 
    (
    MMU_TRANS_TBL * pTransTbl		/* translation table to be deleted */
    )
    {
    LEVEL_1_DESC 	lvl1Desc;	/* level 1 descriptor */
    LEVEL_1_DESC 	globalLvl1Desc;	/* level 1 descriptor */
    u_int		ix;
    int                 key;

    for (ix = 0 ; ix < MMU_LVL_2_DESC_NB; ix++)
	{
	/* Move through L1 descriptor table */
	pTransTbl->l1TblPtr.l1index = ix;
	/* Grab global version of same L1 descriptor. Careful not to allow other 
         * tasks access to the global descriptor table. 
         */
	key=intLock();
	mmuGlobalTransTbl.l1TblPtr.l1index=ix;
	globalLvl1Desc=*mmuGlobalTransTbl.l1TblPtr.pL1Desc;
        mmuGlobalTransTbl.l1TblPtr.l1index=0;
	intUnlock(key);
	
	lvl1Desc = *pTransTbl->l1TblPtr.pL1Desc;
	if (lvl1Desc.v)
	    {
	      /*  Check to see if L2 descriptor actually created 
               *  in global translation table. If so do not free memory, in use.
               */   
	      if ((lvl1Desc.l1desc & MMU_LVL_1_L2BA_MSK) !=
		  (globalLvl1Desc.l1desc & MMU_LVL_1_L2BA_MSK))
	         free ((void *) (lvl1Desc.l1desc & MMU_LVL_1_L2BA_MSK));
	    }
	}
    /* Reset index so free is done a base of L1 descriptor table */
    pTransTbl->l1TblPtr.l1index = 0;

    /* free the PTEG table */
    free ((void *) pTransTbl->l1TblPtr.pL1Desc);
    free ((void *) pTransTbl);

    return (OK);
    }

/******************************************************************************
*
* mmu800Enable - turn mmu on or off
*
* RETURNS: OK
*/

LOCAL STATUS mmu800Enable 
    (
    BOOL enable			/* TRUE to enable, FALSE to disable MMU */
    )
    {
    int lockKey;		/* lock key for intUnlock() */

    /* lock the interrupt */

    lockKey = intLock ();

    if (enable)
	{
	if (mmu800Selected & MMU_INST)
	    mmuPpcAEnable (MMU_I_ADDR_TRANS);	/* enable instruction MMU */

	if (mmu800Selected & MMU_DATA)
	    mmuPpcAEnable (MMU_D_ADDR_TRANS);	/* enable data MMU */

	}
    else
	{
	if (mmu800Selected & MMU_INST)
	    mmuPpcADisable (MMU_I_ADDR_TRANS);	/* disable instruction MMU */

	if (mmu800Selected & MMU_DATA)
	    mmuPpcADisable (MMU_D_ADDR_TRANS);	/* disable data MMU */
	}

    intUnlock (lockKey);			/* unlock the interrupt */

    return (OK);
    }

/******************************************************************************
*
* mmu800StateSet - set state of virtual memory page
*
* Note : Exercise extreme caution when changing a page from copyback to
* writethrough. The 860 architecture handles the writethrough/copyback
* attribute at the 4MB Level 1 segment level, not the 4KB Level 2 page
* level.  This function does not attempt to automatically flush cache
* lines belonging to the entire 4MB segment. It does, however, invalidate
* all TLB entries mapping any part of the 4MB segment.
*
* The application must handle the flush implications explicitly.  In order
* to change a 4MB segment from copyback to writethrough, first use
* cacheFlush on the entire 4MB segment to flush any dirty cache lines,
* then use mmuStateSet on the first page of the segment to change the
* caching attributes from copyback to writethrough.
* 
* MMU_STATE_VALID	MMU_STATE_VALID_NOT	valid/invalid
* MMU_STATE_WRITABLE	MMU_STATE_WRITABLE_NOT	writable/writeprotected
* MMU_STATE_CACHEABLE	MMU_STATE_CACHEABLE_NOT	cachable/notcachable
* MMU_STATE_CACHEABLE_WRITETHROUGH
* MMU_STATE_CACHEABLE_COPYBACK
* MMU_STATE_GUARDED		MMU_STATE_GUARDED_NOT
*
* RETURNS: OK, or ERROR if descriptor address does not exist.
*/

LOCAL STATUS mmu800StateSet 
    (
    MMU_TRANS_TBL *	pTransTbl, 	/* translation table */
    void *		effectiveAddr,	/* page whose state to modify */ 
    UINT 		stateMask,	/* mask of which state bits to modify */
    UINT		state		/* new state bit values */
    )
    {
    LEVEL_1_DESC *	pLvl1Desc;	/* level 1 descriptor address */
    LEVEL_1_DESC 	lvl1Desc,oldLvl1Desc;	/* level 1 descriptor */
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc,oldLvl2Desc;	/* level 2 descriptor */

    /* get the level 1 descriptor address */

    pLvl1Desc = mmu800Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    /* 
     * get the level 2 descriptor address. If this descriptor address doesn't
     * exist then set errno and return ERROR.
     */

    if (mmu800Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* get the Level 1 Descriptor */

    lvl1Desc.l1desc = pLvl1Desc->l1desc;
    oldLvl1Desc.l1desc = pLvl1Desc->l1desc;

    /* get the Level 2 Descriptor */

    lvl2Desc.l2desc = pLvl2Desc->l2desc;
    oldLvl2Desc.l2desc = pLvl2Desc->l2desc;

    /* Any change of state in the cache requires the page in question to 
       be flushed but not done until just before the tlb invalidate entry */

    /* set the VALID bit if requested */
    if (stateMask & MMU_STATE_MASK_VALID)
        {
        if ((state & MMU_STATE_MASK_VALID) == MMU_STATE_VALID) 
	    lvl2Desc.v = 1;			/* set the Valid bit */
	else
	    lvl2Desc.v = 0;			/* clear the Valid bit */
        }

    /* set the CACHE state if requested */
    if (stateMask & MMU_STATE_MASK_CACHEABLE)
        {
        if ((state & MMU_STATE_MASK_CACHEABLE) == MMU_STATE_CACHEABLE_NOT) 
	    lvl2Desc.ci = 1;			/* set the Cache Inhibit bit */
	else
	    {
	    lvl2Desc.ci = 0;			/* clear the Cache Inhibit bit*/

	    if ((state & MMU_STATE_MASK_CACHEABLE) ==
					MMU_STATE_CACHEABLE_WRITETHROUGH) 
		lvl1Desc.wt = 1;		/* set the writethrough cache */
	    else
		lvl1Desc.wt = 0;		/* set the copyback cache */
	    }
        }
    /* set the GUARDED bit if requested */
    
    if (stateMask & MMU_STATE_MASK_GUARDED)
        {
	if ((state & MMU_STATE_MASK_GUARDED) == MMU_STATE_GUARDED) 
	    lvl1Desc.g = 1;			/* set the Guarded bit */
	else
	    lvl1Desc.g = 0;			/* clear the Guarded bit */
        }

    /* set/unset the WRITABLE BIT if requested */
    if (stateMask & MMU_STATE_MASK_WRITABLE)
        {
       	if ((state & MMU_STATE_MASK_WRITABLE) == MMU_STATE_WRITABLE) 
	    lvl2Desc.pp = 2;			/* set to R/W */
	else
	    lvl2Desc.pp = 3;			/* set to R/O */
        }

    /* Flush page if cache inhibit is going to be set */
    if ( (lvl2Desc.ci!=oldLvl2Desc.ci) && /* Have cache inhibit changed */
	 (lvl2Desc.ci==1) && /* Is it about to be marked cache inhibit */
	 (oldLvl1Desc.wt==0) && /* Only need to do this if in copyback mode */
	 (oldLvl2Desc.v==1) ) /* Make sure old page is valid */
        cacheArchFlush(DATA_CACHE,effectiveAddr,PAGE_SIZE);

    mmu800Lvl1DescUpdate (pLvl1Desc, lvl1Desc);
    mmu800Lvl2DescUpdate (pLvl2Desc, lvl2Desc);

    /* Check to see if L1 descriptor has changed */
    if ((lvl1Desc.g!=oldLvl1Desc.g) || (lvl1Desc.wt != oldLvl1Desc.wt)) 
         /* L1 attribute so invalidate SEGMENT 
          * Quicker than invalidating each page for 4MB
	  * The number of TLB misses resulting in this command is assumed 
          * to be inconsequential for system initialisation.
          */
         mmuPpcTlbInvalidateAll(); 
     else 
         mmuPpcTlbie (effectiveAddr);  /* invalidate page so new descriptor is loaded */
    
    return (OK);
    }

/******************************************************************************
*
* mmu800StateGet - get state of virtual memory page
*
*/

LOCAL STATUS mmu800StateGet 
    (
    MMU_TRANS_TBL *	pTransTbl,	/* tranlation table */
    void *		effectiveAddr, 	/* page whose state we're querying */
    UINT *		state		/* place to return state value */
    )
    {
    LEVEL_1_DESC *	pLvl1Desc;	/* level 1 descriptor address */
    LEVEL_1_DESC 	lvl1Desc;	/* level 1 descriptor */
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc;	/* level 2 descriptor */

    /* get the level 1 descriptor address */

    pLvl1Desc = mmu800Lvl1DescAddrGet (pTransTbl, effectiveAddr);


    /* 
     * get the level 2 descriptor address. If this descriptor address doesn't
     * exist then set errno and return ERROR.
     */

    if (mmu800Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* get the Level 1 Descriptor */

    lvl1Desc.l1desc = pLvl1Desc->l1desc;

    /* get the Level 2 Descriptor */

    lvl2Desc.l2desc = pLvl2Desc->l2desc;

    *state=0;

    /* Get the various supported MMU states */
    if (lvl1Desc.wt==1) *state |= MMU_STATE_CACHEABLE_WRITETHROUGH;
    if (lvl1Desc.g==1) *state |= MMU_STATE_GUARDED;
    if (lvl2Desc.v==1) *state |= MMU_STATE_VALID;
    if (lvl2Desc.ci==0) *state |= MMU_STATE_CACHEABLE;
    if (lvl2Desc.pp==2) *state |= MMU_STATE_WRITABLE;
    
    return (OK);
    }

/******************************************************************************
*
* mmu800PageMap - map physical memory page to virtual memory page
*
* The physical page address is entered into the level 2 descriptor
* corresponding to the given virtual page.  The state of a newly mapped page
* is undefined. 
*
* RETURNS: OK or ERROR if translation table creation failed. 
*/

LOCAL STATUS mmu800PageMap 
    (
    MMU_TRANS_TBL *	pTransTbl, 	/* translation table */
    void *		effectiveAddr, 	/* effective address */
    void *		physicalAddr	/* physical address */
    )
    {
    LEVEL_1_DESC *	pLvl1Desc;	/* level 1 descriptor address */
    LEVEL_1_DESC 	lvl1Desc;	/* level 1 descriptor */
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */
    LEVEL_2_DESC 	lvl2Desc;	/* level 2 descriptor */
    u_int		ix;		/* counter */

    /* get the level 1 descriptor address */

    pLvl1Desc = mmu800Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    /* get the level 1 descriptor */

    lvl1Desc.l1desc = pLvl1Desc->l1desc;

    if (!lvl1Desc.v)
	{

	/* 
	 * the level 2 desciptor is not valid (doesn't exit) then 
	 * allocate a piece of memory to save the level 2 desciptor table
	 */

	pLvl2Desc = (LEVEL_2_DESC *) memalign (PAGE_SIZE, PAGE_SIZE);

	/* 
	 * check if the level 2 desciptor table was created properly. If
	 * not then return ERROR.
	 */

	if (pLvl2Desc == NULL)
	    return (ERROR);
		
	/* 
	 * invalid all level 2 descriptors by clearing the new level
	 * 2 descriptor table created.
	 */

	lvl2Desc.rpn = 0;		/* Real page Number */
	lvl2Desc.pp  = 2;		/* Executable Read/Write page */
	lvl2Desc.ppe = 0;		/* PowerPC encoding */
	lvl2Desc.c   = 0;		/* Not changed page */
	lvl2Desc.spv = 0xf;		/* All sub-page valid */ 
	lvl2Desc.sps = 0;		/* 4 K Bytes page */
	lvl2Desc.sh  = 1;		/* ASID comparaison disabled */
	lvl2Desc.v   = 0;		/* Page Not Valid */

	for (ix = 0; ix < MMU_LVL_2_DESC_NB; ix ++)
	    pLvl2Desc[ix] = lvl2Desc;

	/* 
	 * set the Level 1 Descriptor with default option for the
	 * new level 2 descriptor table created.
	 */

	lvl1Desc.l1desc = ((u_int) pLvl2Desc) & MMU_LVL_1_L2BA_MSK;
	lvl1Desc.apg = 0;	/* use the Access Protection Group Number 0 */
	lvl1Desc.g   = 0;	/* not guarded */
	lvl1Desc.ps  = 0;	/* small page size (4k or 16k) */
	lvl1Desc.wt  = 0;	/* cache copyback mode */
	lvl1Desc.v   = 1;	/* segment valid */

	/* update the Level 1 descriptor in table */

	mmu800Lvl1DescUpdate (pLvl1Desc, lvl1Desc);

	}

    /* 
     * Get the level 2 descriptor address. If the level 2 descriptor doesn't
     * exist then return ERROR. 
     */

    if (mmu800Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	return (ERROR);

    /* get the level 1 descriptor */

    lvl2Desc.l2desc = pLvl2Desc->l2desc;

    /* save the real address in the level 2 descriptors */

    lvl2Desc.rpn = (u_int) physicalAddr >> MMU_RPN_SHIFT;

    /* update the Level 2 descriptor in table */

    mmu800Lvl2DescUpdate (pLvl2Desc, lvl2Desc);
    mmuPpcTlbie(effectiveAddr);

    return (OK);
    }

/******************************************************************************
*
* mmu800GlobalPageMap - map physical memory page to global virtual memory page
*
* mmuPpcGlobalPageMap is used to map physical pages into global virtual memory
* that is shared by all virtual memory contexts.  The translation tables
* for this section of the virtual space are shared by all virtual memory
* contexts.
*
* RETURNS: OK or ERROR if no pte for given virtual page.
*/

LOCAL STATUS mmu800GlobalPageMap 
    (
    void *  effectiveAddr, 	/* effective address */
    void *  physicalAddr	/* physical address */
    )
    {
    return (mmu800PageMap (&mmuGlobalTransTbl, effectiveAddr, physicalAddr));
    }

/******************************************************************************
*
* mmu800Translate - translate a virtual address to a physical address
*
* Traverse the translation table and extract the physical address for the
* given virtual address from the level 2 descriptor corresponding to the
* virtual address.
*
* RETURNS: OK or ERROR if no level 2 descriptor found for given virtual address.
*/

LOCAL STATUS mmu800Translate 
    (
    MMU_TRANS_TBL *	pTransTbl,	/* translation table */
    void *		effectiveAddr,	/* effective address */
    void **		physicalAddr	/* where to place the result */
    )
    {
    LEVEL_2_DESC *	pLvl2Desc;	/* Level 2 descriptor address */
    EFFECTIVE_ADDR	effAddr;	/* effective address */
    REAL_ADDRESS	realAddr;	/* real address */

    /* 
     * find the level 2 descriptor corresponding to the <effectiveAddr>
     * in the translation table pointed to by the <pTransTbl> structure.
     * If this level 2 descriptor cannot be found then return ERROR.
     */

    if (mmu800Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) != OK)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* check if the level 2 descriptor found is valid. If not return ERROR */

    if (!pLvl2Desc->v)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    effAddr = * ((EFFECTIVE_ADDR *) &effectiveAddr);

    /* build the real address */

    realAddr.rpn = pLvl2Desc->rpn;
    realAddr.po  = effAddr.po;

    * physicalAddr = realAddr.realAddr;

    return (OK);
    }

/******************************************************************************
*
* mmu800CurrentSet - change active translation table
*
* This function changes the virtual memory context by loading the M_TWB
* register with the level 1 table pointer saved in the translation
* table structure pointed to by <pTransTbl>.
*
* RETURNS: N/A
*
*/

void mmu800CurrentSet 
    (
    MMU_TRANS_TBL * pTransTbl		/* new active tranlation table */
    ) 
    {
    FAST int	lockKey;		/* intLock lock key */
    static BOOL	firstTime = TRUE;	/* first time call flag */

    if (firstTime)
	{
	/*
	 * write protect all the pages containing the descriptors allocated for
	 * the global translation table.  Need to do this because when this
	 * memory is allocated, the global translation table doesn't exist yet.
	 */

	 mmu800MemPagesWriteDisable (&mmuGlobalTransTbl);
	 mmu800MemPagesWriteDisable (pTransTbl);

	 firstTime = FALSE;
	 }

    lockKey = intLock ();

    /* 
     * save the level 1 table pointer in the M_TWB register via
     * mmu800MTwbSet(). If one or both MMUs are turned on then disable
     * the MMU, set the M_TWB register and re-enable the MMU.
     */

    if (mmu800IsOn (MMU_INST)  || mmu800IsOn (MMU_DATA))
	{
	mmu800Enable (FALSE);			/* disable the MMU */
    	mmuPpcMTwbSet (pTransTbl->l1TblPtr.pL1Desc);
	mmu800Enable (TRUE);			/* re-enable  the MMU */
	}
    else
      {
    	mmuPpcMTwbSet (pTransTbl->l1TblPtr.pL1Desc);
      }
    

    mmuPpcTlbInvalidateAll();

    intUnlock (lockKey);
    }

/*******************************************************************************
*
* mmu800Lvl2DescAddrGet - get the address of a level 2 Desciptor
* 
* This routine finds the address of a level 2 desciptor corresponding to the
* <effectiveAddr> in the translation table pointed to by <pTransTbl> structure.
* If a matching level 2 Descriptor existe, the routine save the level 2
* desciptor address at the address pointed to by <ppLvl2Desc>.
* If any level 2 Descriptor matching the <effectiveAddr> is not found then
* the function return ERROR.
*
* RETURNS: OK or ERROR.
*/

LOCAL STATUS mmu800Lvl2DescAddrGet
    (
    MMU_TRANS_TBL *	pTransTbl,	/* translation table */
    void *		effectiveAddr,	/* effective address */
    LEVEL_2_DESC **	ppLvl2Desc	/* where to save the lvl 2 desc addr */
    )
    {
    LEVEL_1_DESC * 	pLvl1Desc;	/* level 1 descriptor address */
    LEVEL_2_TBL_PTR	lvl2TblPtr;	/* level 2 table pointer */
    EFFECTIVE_ADDR	effAddr;	/* effective address */

    /* get address of the level 1 descriptor */

    pLvl1Desc = mmu800Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    /* 
     * check the valid bit. If the level 1 descriptor is not valid than
     * the level 2 descriptor doesn't exit. In this case return ERROR.
     */

    if (!pLvl1Desc->v)
	return (ERROR);

    effAddr.effAddr = effectiveAddr;

    /* 
     * build the Level 2 descriptor address corresponding to the effective
     * address pointed to by <effectiveAddr>.
     */

    lvl2TblPtr.l2tb     = pLvl1Desc->l2ba;
    lvl2TblPtr.l2index  = effAddr.l2index;
    lvl2TblPtr.field.reserved = 0;

    /* 
     * save the level 2 descriptor address at the address
     * pointed to by <ppLvl2Desc>.
     */

    * ppLvl2Desc = lvl2TblPtr.pL2Desc;

    return (OK);
    }
 
/*******************************************************************************
*
* mmu800Lvl1DescAddrGet - get the address of a level 1 descriptor 
*
* This function returns the address of the level 1 descriptor corresponding
* to the effective address pointed to by <effectiveAddr>. 
*
* RETRUNS: always the address of the level 1 descriptor
*
*/

LOCAL LEVEL_1_DESC * mmu800Lvl1DescAddrGet
    (
    MMU_TRANS_TBL *	pTransTbl,	/* translation table */
    void *		effectiveAddr	/* effective address */
    )
    {
    LEVEL_1_TBL_PTR	lvl1TblPtr;
    EFFECTIVE_ADDR	effAddr;

    effAddr = * ((EFFECTIVE_ADDR *) &effectiveAddr);

    /* 
     * build the Level 1 descriptor address corresponding to the effective
     * address pointed to by <effectiveAddr>.
     */

    lvl1TblPtr.l1tb     = pTransTbl->l1TblPtr.l1tb;
    lvl1TblPtr.l1index  = effAddr.l1index;
    lvl1TblPtr.field.reserved = 0;

    return (lvl1TblPtr.pL1Desc);
    }

/*******************************************************************************
*
* mmu800Lvl1DescUpdate - update a level 1 descriptor 
*
* This function updates a level 1 desciptor. The addess of the level 1
* descriptor is handled by <pLvl1Desc> and the new value of the level 1
* descriptor by <lvl1Desc>.
*
* RETURNS: N/A
*/

LOCAL void mmu800Lvl1DescUpdate
    (
    LEVEL_1_DESC *	pLvl1Desc,	/* Level 1 descriptor address */
    LEVEL_1_DESC	lvl1Desc	/* Level 1 descriptor */
    )
    {
    UINT32	key;

    if (mmu800IsOn (MMU_INST)  || mmu800IsOn (MMU_DATA))
	{
	key = intLock();			/* lock interrupt */
	mmu800Enable (FALSE);                   /* disable the mmu */
	pLvl1Desc->l1desc = lvl1Desc.l1desc;	/* update the descriptor */
	mmu800Enable (TRUE);			/* enable the MMU */
	intUnlock(key);				/* re-enable interrupt */
	}
    else
      {
	pLvl1Desc->l1desc = lvl1Desc.l1desc;	/* update the descriptor */
      }
    }

/*******************************************************************************
*
* mmu800Lvl2DescUpdate - update a level 2 descriptor 
*
* This function updates a level 2 desciptor. The addess of the level 2
* descriptor is handled by <pLvl2Desc> and the new value of the level 2
* descriptor by <lvl2Desc>.
*
* RETURNS: N/A
*/

LOCAL void mmu800Lvl2DescUpdate
    (
    LEVEL_2_DESC *	pLvl2Desc,	/* Level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc	/* Level 2 descriptor */
    )
    {
    UINT32	key;

    if (mmu800IsOn (MMU_INST)  || mmu800IsOn (MMU_DATA))
	{
	key = intLock();			/* lock interrupt */
	mmu800Enable (FALSE);                   /* disable the mmu */
	pLvl2Desc->l2desc = lvl2Desc.l2desc;	/* update the descriptor */
	mmu800Enable (TRUE);			/* enable the MMU */
	intUnlock(key);				/* re-enable interrupt */
	}
    else
      {
	pLvl2Desc->l2desc = lvl2Desc.l2desc;	/* update the descriptor */
      }

    }

/*******************************************************************************
*
* mmu800IsOn - return the state of the MMU
*
* This function returns TRUE if the MMU selected by <mmuType> is on.
*
* RETURNS: TRUE or FALSE
*
*/

LOCAL BOOL mmu800IsOn
    (
    int	mmuType			/* MMU type to return the state of */
    )
    {

    switch (mmuType)
	{
	case MMU_INST:		/* Instruction MMU to test */
	    return (vxMsrGet () & _PPC_MSR_DR);
	    break;

	case MMU_DATA:		/* Data MUU to test */
	    return (vxMsrGet () & _PPC_MSR_IR);
	    break;

	default:		/* default value */
	    return (FALSE);
	}
    }

/*******************************************************************************
*
* mmu800Show - show the level 1 and 2 desciptor for and effective address
*
* NOTE: For MMU library debug only 
*/

void mmu800Show 
    (
    MMU_TRANS_TBL *	pTransTbl,		/* translation table */
    void *		effectiveAddr		/* effective address */
    )
    {
    LEVEL_1_DESC *	pLvl1Desc;	/* level 1 descriptor address */
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */
    LEVEL_1_DESC 	lvl1Desc;	/* level 1 descriptor address */
    LEVEL_2_DESC 	lvl2Desc;	/* level 2 descriptor address */

    if (pTransTbl==NULL)
      pTransTbl=&mmuGlobalTransTbl;

    /* get the level 1 descriptor address */
    
    pLvl1Desc = mmu800Lvl1DescAddrGet (pTransTbl, effectiveAddr);
    lvl1Desc.l1desc = pLvl1Desc->l1desc;

    printf ("Level 1:");
    printf ("l2ba	= 0x%x\n", lvl1Desc.l2ba);
    printf ("apg	= 0x%x\n", lvl1Desc.apg);
    printf ("g		= %d\n", lvl1Desc.g);
    printf ("ps		= 0x%x\n", lvl1Desc.ps);
    printf ("wt		= %d\n", lvl1Desc.wt);
    printf ("v		= %d\n", lvl1Desc.v);

    if (mmu800Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) != OK)
	return ;
    lvl2Desc.l2desc=pLvl2Desc->l2desc;

    printf ("Level 2:");
    printf ("rpn	= 0x%x\n", lvl2Desc.rpn);
    printf ("pp1	= 0x%x\n", lvl2Desc.pp);
    printf ("ppe	= 0x%x\n", lvl2Desc.ppe);
    printf ("c	= 0x%x\n", lvl2Desc.c);
    printf ("spv	= 0x%x\n", lvl2Desc.spv);
    printf ("sps	= %d\n", lvl2Desc.sps);
    printf ("sh		= %d\n", lvl2Desc.sh);
    printf ("ci		= %d\n", lvl2Desc.ci);
    printf ("v		= %d\n", lvl2Desc.v);
    }

#if FALSE
void mmu800TlbShow ()
    {
    int	ix;
    int dbcam;
    int	dbram0;
    int dbram1;
    int ddbcam;
    int	ddbram0;
    int ddbram1;

    for (ix=0; ix<32; ix++)
	{
	mmuPpcMiCtrSet (ix << 8);
	dbcam = mmuPpcMiDbcamGet();
	dbram0 = mmuPpcMiDbram0Get();
	dbram1 = mmuPpcMiDbram1Get();
	ddbcam = mmuPpcMdDbcamGet();
	ddbram0 = mmuPpcMdDbram0Get();
	ddbram1 = mmuPpcMdDbram1Get();

	printf ("ix = %d	dbcam = 0x%x	dbram0 = 0x%x	dbram1 = 0x%x\n",
		ix, dbcam, dbram0, dbram1);
	printf ("ix = %d	ddbcam = 0x%x	ddbram0 = 0x%x	ddbram1 = 0x%x\n",
		ix, ddbcam, ddbram0, ddbram1);
	}
    }
#endif

