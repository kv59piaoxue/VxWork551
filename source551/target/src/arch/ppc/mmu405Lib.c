/* mmu405Lib.c - mmu library for PowerPC 405 series */

/* Copyright 1984-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01e,25apr02,pch  SPR 74926: don't connect to unused vector
01d,17apr02,jtp  use common identifier names with PPC440
01c,07dec01,jtp  SPR #67973 add exception message for MMU config failure
01b,22nov00,s_m  changes due to changed prototype of mmuPpcTlbSearch
01a,17jul00,sm 	 written.
*/

/*
DESCRIPTION:
mmu405Lib.c provides the architecture dependent routines that directly
control the memory management unit for the PowerPC 405 series.  It provides 
routines that are called by the higher level architecture independent 
routines in vmLib.c or vmBaseLib.c.
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
#include "arch/ppc/vxPpcLib.h"
#include "arch/ppc/mmu405Lib.h"

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
     VM_STATE_GUARDED_NOT, MMU_STATE_GUARDED_NOT}
    };

LOCAL MMU_TRANS_TBL *	mmu405TransTblCreate ();
LOCAL STATUS		mmu405TransTblDelete (MMU_TRANS_TBL *transTbl);
LOCAL STATUS		mmu405Enable (BOOL enable);
LOCAL STATUS		mmu405StateSet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				     UINT stateMask, UINT state);
LOCAL STATUS		mmu405StateGet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				     UINT *state);
LOCAL STATUS		mmu405PageMap (MMU_TRANS_TBL *transTbl,
				     void * virtualAddress, void *physPage);
LOCAL STATUS		mmu405GlobalPageMap (void * virtualAddress,
				    void * physPage);
LOCAL STATUS		mmu405Translate (MMU_TRANS_TBL * transTbl,
				      void * virtAddress, void ** physAddress);
LOCAL void		mmu405CurrentSet (MMU_TRANS_TBL * transTbl);
LOCAL STATUS		mmu405TransTblInit (MMU_TRANS_TBL * pNewTransTbl);
LOCAL LEVEL_1_DESC *	mmu405Lvl1DescAddrGet (MMU_TRANS_TBL *	pTransTbl,
				    void * effectiveAddr);
LOCAL STATUS		mmu405Lvl2DescAddrGet (MMU_TRANS_TBL * pTransTbl,
				void * effectiveAddr,
				LEVEL_2_DESC ** ppLvl2Desc);
LOCAL void		mmu405Lvl1DescUpdate (LEVEL_1_DESC * pLvl1Desc,
				LEVEL_1_DESC lvl1Desc);
LOCAL void		mmu405Lvl2DescUpdate (LEVEL_2_DESC * pLvl2Desc,
				LEVEL_2_DESC lvl2Desc);
LOCAL BOOL		mmu405IsOn (int mmuType);
LOCAL UINT8 		mmu405GetNewPid (MMU_TRANS_TBL *transTbl);
LOCAL void 		mmu405FreePid (UINT8 pid);
LOCAL void 		mmu405Tlbie (MMU_TRANS_TBL *pTransTbl, void * effAddr);

IMPORT void		mmuPpcPidSet (UINT8 pid);
IMPORT UINT32		mmuPpcPidGet (void);
IMPORT void		mmuPpcTlbInvalidateAll (void);
IMPORT void 		mmuPpcZprSet (UINT32 zprVal);
IMPORT UINT32 		mmuPpcTlbReadEntryHi (UINT32 index);
IMPORT UINT32		mmuPpcTlbReadEntryLo (UINT32 index);
IMPORT int	 		mmuPpcTlbSearch (void * effAddr);
IMPORT void 		mmuPpcTlbWriteEntryHi (UINT32 index, UINT32 tlbhi);
IMPORT void 		mmuPpcTlbWriteEntryLo (UINT32 index, UINT32 tlblo);

IMPORT void	mmuPpcAEnable ();
IMPORT void	mmuPpcADisable ();

IMPORT void	mmuPpcInstTlbMissHandler();
IMPORT void	mmuPpcDataTlbMissHandler();

IMPORT STATE_TRANS_TUPLE *	mmuStateTransArray;
IMPORT int			mmuStateTransArraySize;
IMPORT MMU_LIB_FUNCS		mmuLibFuncs;
IMPORT int			mmuPageBlockSize;


/*
 * a translation table to hold the descriptors for the global transparent
 * translation of physical to virtual memory
 */

MMU_TRANS_TBL	mmuGlobalTransTbl;	/* global translation table */	

/*
 * An array 256 translation table pointers is allocated to store upto
 * 255 (entry 0 unused) unique address maps
 * This array is indexed by the PID value. A value of -1 denotes an
 * unused entry.
 */
MMU_TRANS_TBL	 * mmuAddrMapArray [MMU_ADDR_MAP_ARRAY_SIZE];

/* the global map's PID index into above array (should be equal to 1) */
UINT8	mmuGlobalMapPid;

/* tlb replacement counter: we use a round-robin strategy to determine
 * which tlb entry to replace. The following variable is used by the
 * TLB miss handlers to determine which TLB (0..63) to replace in the
 * event of a TLB miss.
 */
UINT32	mmuPpcTlbNext;

#ifdef DEBUG_MISS_HANDLER
UINT32	mmuPpcITlbMisses;
UINT32	mmuPpcITlbMissArray[256];
UINT32	mmuPpcDTlbMisses;
UINT32	mmuPpcDTlbMissArray[256];
UINT32	mmuPpcITlbErrors;
UINT32	mmuPpcDTlbErrors;
#endif /* DEBUG_MISS_HANDLER */

LOCAL UINT32	mmu405Selected;		/* mmu type selected */

LOCAL MMU_LIB_FUNCS mmuLibFuncsLocal =
    {
    mmu405LibInit,
    mmu405TransTblCreate,
    mmu405TransTblDelete,
    mmu405Enable,
    mmu405StateSet,
    mmu405StateGet,
    mmu405PageMap,
    mmu405GlobalPageMap,
    mmu405Translate,
    mmu405CurrentSet
    };

/******************************************************************************
*
* mmu405LibInit - MMU library initialization
*
* RETURNS: OK, or ERROR if <mmuType> is incorrect or memory allocation failed. 
*/

STATUS mmu405LibInit 
    (
    int 	mmuType		/* data and/or instruction MMU to initialize */
    )
    {

    /* check if the MMU type to initialize is coherent */

    if (!(mmuType & MMU_INST) && !(mmuType & MMU_DATA))
	{
	/*
	 * too soon in boot process to print a string, so store one in the
	 * exception message area.
	 */
	strcpy(sysExcMsg, "405 MMU config failed: either enable I or D MMU, "
			  "or remove MMU support\n");
	return (ERROR);
	}

    /* save the Data and/or Instruction MMU selected */

    mmu405Selected =  mmuType;

    /* initialize the exception table:
     * 	At the exception offset, we put a branch instruction (0x48000002)
     *  OR'ed with the address of the TLB miss handler.
     */ 

    if (mmuType & MMU_INST)
	{
	if ((UINT32)mmuPpcInstTlbMissHandler > 0x03fffffc)
	    {
	    strcpy(sysExcMsg, "405 MMU config failed: TLB miss handler "
				"is too far from the vector table\n");
	    return (ERROR);
	    }
	* (int *) _EXC_OFF_INST_MISS = 0x48000002 |
			(((int) mmuPpcInstTlbMissHandler) & 0x03fffffc);
	CACHE_TEXT_UPDATE((void *)_EXC_OFF_INST_MISS, sizeof(int));
	}

    if (mmuType & MMU_DATA)
	{
	if ((UINT32)mmuPpcDataTlbMissHandler > 0x03fffffc)
	    {
	    strcpy(sysExcMsg, "405 MMU config failed: TLB miss handler "
				"is too far from the vector table\n");
	    return (ERROR);
	    }
	* (int *) _EXC_OFF_DATA_MISS = 0x48000002 |
			(((int) mmuPpcDataTlbMissHandler) & 0x03fffffc);
	CACHE_TEXT_UPDATE((void *)_EXC_OFF_DATA_MISS, sizeof(int));
	}

    /* initialize the address map array: a value of -1 denotes an
       unused element. */

    memset ((void *) mmuAddrMapArray, (int)MMU_ADDR_MAP_ARRAY_INV, 
				    sizeof (mmuAddrMapArray));


    /* get a PID element for the global map */

    mmuGlobalMapPid = mmu405GetNewPid (&mmuGlobalTransTbl);
    if (mmuGlobalMapPid == 0) /* no free PIDs ! */
	    return (ERROR);

    mmuGlobalTransTbl.pid = mmuGlobalMapPid;


   /* allocate a piece of memory to handle the level 1 Table. This memory
    * needs to be page aligned because, we write protect all the page 
    * tables later, and we don't want other variables sharing a page with
    * the page table itself.
    */

    mmuGlobalTransTbl.l1TblPtr.pL1Desc =
			(LEVEL_1_DESC *) memalign (PAGE_SIZE, PAGE_SIZE);

    /* check the memory allocation */

    if (mmuGlobalTransTbl.l1TblPtr.pL1Desc == NULL)
    {
    	mmu405FreePid (mmuGlobalMapPid);
	return (ERROR);
    }

    /* invalidate all entries in the table */

    memset ((void *) mmuGlobalTransTbl.l1TblPtr.pL1Desc, 0x00, PAGE_SIZE);

    /* initialize the PID register , and invalidate all TLB entries */

    mmuPpcPidSet (mmuGlobalMapPid);

    mmuPpcTlbInvalidateAll();

    /* initialize the Zone protection register so that for all zones
     * access is controlled by EX and WR for both user and supervisor
     * states.
     */
    mmuPpcZprSet (MMU_ZPR_INIT_VAL);

    /* initialize the data objects that are shared with vmLib.c */

    mmuStateTransArray = &mmuStateTransArrayLocal [0];

    mmuStateTransArraySize =
		sizeof (mmuStateTransArrayLocal) / sizeof (STATE_TRANS_TUPLE);

    mmuLibFuncs = mmuLibFuncsLocal;

    /* initialize the TLB replacement counter to zero. */
    mmuPpcTlbNext = 0;

    mmuPageBlockSize = PAGE_SIZE;

    return (OK);

    }

#if FALSE
/******************************************************************************
*
* mmu405MemPagesWriteEnable - write enable the memory holding PTEs
*
* Each translation table has a linked list of physical pages that contain its
* table and page descriptors.  Before you can write into any descriptor, you
* must write enable the page it is contained in.  This routine enables all
* the pages used by a given translation table.
*
*/

LOCAL STATUS mmu405MemPagesWriteEnable
    (
    MMU_TRANS_TBL * pTransTbl
    )
    {
    int ix;
    LEVEL_1_DESC lvl1Desc;

    /* we need to enable writes on the level 1 page table and each level 2
     * page table. The level 1 page table is PAGE_SIZE in size, whereas
     * the level 2 page table is 2 * PAGE_SIZE in size.
     */

    /* write enable the level 1 page table */
    mmu405StateSet (pTransTbl, (void *)pTransTbl->l1TblPtr.pL1Desc, 
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE);

    /* go thru the L 1 table and write enable each L 2 table */
    for (ix = 0 ; ix < MMU_LVL_2_DESC_NB; ix++)
	{
	lvl1Desc = * (pTransTbl->l1TblPtr.pL1Desc + ix);

	if (lvl1Desc.field.v)
	    {
	    mmu405StateSet (pTransTbl, (void *)(lvl1Desc.field.l2ba << 2),
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE);
	    mmu405StateSet (pTransTbl, (void *)((lvl1Desc.field.l2ba << 2) + 
						PAGE_SIZE),
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE);
	    }
	}

    return (OK);
    }
#endif

/******************************************************************************
*
* mmu405MemPagesWriteDisable - write disable memory holding PTEs
*
* Memory containing translation table descriptors is marked as read only
* to protect the descriptors from being corrupted.  This routine write protects
* all the memory used to contain a given translation table's descriptors.
*
* RETURNS: N/A
*/

LOCAL void mmu405MemPagesWriteDisable
    (
    MMU_TRANS_TBL * pTransTbl
    )
    {
    int ix;
    LEVEL_1_DESC lvl1Desc;

    /* we need to disable writes on the level 1 page table and each level 2
     * page table. The level 1 page table is PAGE_SIZE in size, whereas
     * the level 2 page table is 2 * PAGE_SIZE in size.
     */

    /* write protect the level 1 page table */
    mmu405StateSet (pTransTbl, (void *)pTransTbl->l1TblPtr.pL1Desc, 
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT);

    /* go thru the L 1 table and write protect each L 2 table */
    for (ix = 0 ; ix < MMU_LVL_2_DESC_NB; ix++)
	{
	lvl1Desc = * (pTransTbl->l1TblPtr.pL1Desc + ix);

	if (lvl1Desc.field.v)
	    {
	    mmu405StateSet (pTransTbl, (void *)(lvl1Desc.field.l2ba << 2),
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT);
	    }
	}

    }

/******************************************************************************
*
* mmu405TransTblCreate - create a new translation table.
*
* RETURNS: address of new object or NULL if allocation failed.
*/

LOCAL MMU_TRANS_TBL * mmu405TransTblCreate 
    (
    )
    {
    MMU_TRANS_TBL *	pNewTransTbl;

    /* allocate a piece of memory to save the new translation table */

    pNewTransTbl = (MMU_TRANS_TBL *) malloc (sizeof (MMU_TRANS_TBL));

    /* if the memory can not allocated then return the NULL pointer */

    if (pNewTransTbl == NULL)
	return (NULL);

    /* get a free PID for the new translation table */

    pNewTransTbl->pid = mmu405GetNewPid (pNewTransTbl);

    if (pNewTransTbl->pid == 0) /* no free PIDs ! */
    {
    free ((char *) pNewTransTbl);
    return (NULL);
    }

    /* 
     * initialize the new translation table. 
     * If the initialization fails then free the memory and return the NULL
     * pointer.
     */

    if (mmu405TransTblInit (pNewTransTbl) == ERROR)
	{
	free ((char *) pNewTransTbl);
	return (NULL);
	}

    /* return the new translation table created */

    return (pNewTransTbl);
    }

/******************************************************************************
*
* mmu405TransTblInit - initialize a new translation table 
*
* Initialize a new translation table.  The level 1 table is copyed from the
* global translation mmuGlobalTransTbl, so that we
* will share the global virtual memory with all
* other translation tables.
* 
* RETURNS: OK or ERROR if unable to allocate memory. 
*/

LOCAL STATUS mmu405TransTblInit 
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

    mmu405MemPagesWriteDisable (pNewTransTbl);

    return (OK);
    }

/******************************************************************************
*
* mmu405TransTblDelete - delete a translation table.
* 
* This routine deletes a translation table.
*
* RETURNS: OK always.
*/

LOCAL STATUS mmu405TransTblDelete 
    (
    MMU_TRANS_TBL * pTransTbl		/* translation table to be deleted */
    )
    {
    LEVEL_1_DESC 	lvl1Desc;	/* level 1 descriptor */
    UINT32		ix;

    /* free the PID element for this translation table */

    mmu405FreePid (pTransTbl->pid);

    /* free level 2 page tables */

    for (ix = 0 ; ix < MMU_LVL_2_DESC_NB; ix++)
	{
	lvl1Desc = * (pTransTbl->l1TblPtr.pL1Desc + ix);

	if (lvl1Desc.field.v)
	    free ((void *) (lvl1Desc.l1desc & MMU_LVL_1_L2BA_MSK));
	}
     
    /* free the level 1 table */

    free ((void *) pTransTbl->l1TblPtr.pL1Desc);

    return (OK);
    }

/******************************************************************************
*
* mmu405Enable - turn mmu on or off
*
* RETURNS: OK
*/

LOCAL STATUS mmu405Enable 
    (
    BOOL enable			/* TRUE to enable, FALSE to disable MMU */
    )
    {
    int lockKey;		/* lock key for intUnlock() */

    /* lock the interrupt */

    lockKey = intLock ();

    if (enable)
	{
	if (mmu405Selected & MMU_INST)
	    mmuPpcAEnable (MMU_I_ADDR_TRANS);	/* enable instruction MMU */

	if (mmu405Selected & MMU_DATA)
	    mmuPpcAEnable (MMU_D_ADDR_TRANS);	/* enable data MMU */
	}
    else
	{
	if (mmu405Selected & MMU_INST)
	    mmuPpcADisable (MMU_I_ADDR_TRANS);	/* disable instruction MMU */

	if (mmu405Selected & MMU_DATA)
	    mmuPpcADisable (MMU_D_ADDR_TRANS);	/* disable data MMU */
	}

    intUnlock (lockKey);			/* unlock the interrupt */

    return (OK);
    }

/******************************************************************************
*
* mmu405StateSet - set state of virtual memory page
*
*
* MMU_STATE_VALID	MMU_STATE_VALID_NOT	valid/invalid
* MMU_STATE_WRITABLE	MMU_STATE_WRITABLE_NOT	writable/writeprotected
* MMU_STATE_CACHEABLE	MMU_STATE_CACHEABLE_NOT	cachable/notcachable
* MMU_STATE_CACHEABLE_WRITETHROUGH
* MMU_STATE_CACHEABLE_COPYBACK
* MMU_STATE_GUARDED	MMU_STATE_GUARDED_NOT	guarded/un-guarded
*
* RETURNS: OK, or ERROR if descriptor address does not exist.
*/

LOCAL STATUS mmu405StateSet 
    (
    MMU_TRANS_TBL *	pTransTbl, 	/* translation table */
    void *		effectiveAddr,	/* page whose state to modify */ 
    UINT 		stateMask,	/* mask of which state bits to modify */
    UINT		state		/* new state bit values */
    )
    {
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc;	/* level 2 descriptor */

    /* 
     * get the level 2 descriptor address. If this descriptor address doesn't
     * exist then set errno and return ERROR.
     */

    if (mmu405Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* get the Level 2 Descriptor */

    lvl2Desc = *pLvl2Desc;

    /* 
     * Check if the state to set page corresponding to <effectiveAddr> will
     * not set the cache inhibited and writethrough mode. This mode is not
     * supported by the cache.
     */

    if ((stateMask & MMU_STATE_MASK_CACHEABLE) &&
	(state & MMU_STATE_CACHEABLE_NOT) &&
	(state & MMU_STATE_CACHEABLE_WRITETHROUGH))
	{
	return (ERROR);
	}

    /* set or reset the VALID bit if requested */

    lvl2Desc.words.word0 = (lvl2Desc.words.word0 & 
				~(stateMask & MMU_STATE_MASK_VALID)) |
				(state & stateMask & MMU_STATE_MASK_VALID); 

    /* set or reset the WIMG bit if requested */

    lvl2Desc.words.word1 = (lvl2Desc.words.word1 &
			~(stateMask & MMU_STATE_MASK_WIMG_WRITABLE_EXECUTE)) |
		 (state & stateMask & MMU_STATE_MASK_WIMG_WRITABLE_EXECUTE);


    /* update the Level 2 Descriptor */

    mmu405Lvl2DescUpdate (pLvl2Desc, lvl2Desc);

    /* invalidate the tlb entry for this effective address */
    mmu405Tlbie (pTransTbl, effectiveAddr);

    return (OK);
    }

/******************************************************************************
*
* mmu405StateGet - get state of virtual memory page
*
*/

LOCAL STATUS mmu405StateGet 
    (
    MMU_TRANS_TBL *	pTransTbl,	/* tranlation table */
    void *		effectiveAddr, 	/* page whose state we're querying */
    UINT *		state		/* place to return state value */
    )
    {
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc;	/* level 2 descriptor */

    /* 
     * get the level 2 descriptor address. If this descriptor address doesn't
     * exist then set errno and return ERROR.
     */

    if (mmu405Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* get the Level 2 Descriptor */

    lvl2Desc = *pLvl2Desc;

    /* extract the state of the VALID  and WIMG bit */

    * state  = lvl2Desc.words.word0 & MMU_STATE_MASK_VALID;
    * state |= lvl2Desc.words.word1 & MMU_STATE_MASK_WIMG_WRITABLE_EXECUTE;


    return (OK);
    }

/******************************************************************************
*
* mmu405PageMap - map physical memory page to virtual memory page
*
* The physical page address is entered into the level 2 descriptor
* corresponding to the given virtual page.  The state of a newly mapped page
* is undefined. 
*
* RETURNS: OK or ERROR if translation table creation failed. 
*/

LOCAL STATUS mmu405PageMap 
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
    UINT32		ix;		/* counter */

    /* get the level 1 descriptor address */

    pLvl1Desc = mmu405Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    /* get the level 1 descriptor */

    lvl1Desc.l1desc = pLvl1Desc->l1desc;

    if (!lvl1Desc.field.v)
	{

	/* 
	 * the level 2 desciptor table is not valid (doesn't exist) then 
	 * allocate a piece of memory to save the level 2 desciptor table
	 * The level 2 table needs to be aligned on a 4byte boundary
	 * and has a size of 1024 entries * 8 bytes/entry = 8K.
	 */

	pLvl2Desc = (LEVEL_2_DESC *) memalign (PAGE_SIZE, 
				MMU_LVL_2_DESC_NB * sizeof(LEVEL_2_DESC));

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

	lvl2Desc.field.epn = 0;		/* effective page number */
	lvl2Desc.field.rsvd1 = 0;
	lvl2Desc.field.size = 1;	/* default 4KB page */
	lvl2Desc.field.v = 0;		/* initially invalid */
	lvl2Desc.field.e = 0;		/* big endian */
	lvl2Desc.field.u0 = 0;		/* no user defined attribute */
	lvl2Desc.field.rsvd2 = 0;

	lvl2Desc.field.rpn = 0;		/* real page number */
	lvl2Desc.field.rsvd3 = 0;	
	lvl2Desc.field.ex = 1;		/* no execute protection */
	lvl2Desc.field.wr = 0;		/* no write protection */
	lvl2Desc.field.zsel = 0;	/* select zone 0 */
	lvl2Desc.field.w = 0;	/* no write thru */
	lvl2Desc.field.i = 0;	/* no cache inhibit */
	lvl2Desc.field.m = 0;	/* memory coherent: no effect */
	lvl2Desc.field.g = 0;	/* memory unguarded */


	for (ix = 0; ix < MMU_LVL_2_DESC_NB; ix ++)
	    pLvl2Desc[ix] = lvl2Desc;

	/* 
	 * set the Level 1 Descriptor with the
	 * new level 2 descriptor table created.
	 */

	lvl1Desc.l1desc = ((UINT32) pLvl2Desc) & MMU_LVL_1_L2BA_MSK;
	lvl1Desc.field.v   = 1;	/* segment valid */

	/* update the Level 1 descriptor in table */

	mmu405Lvl1DescUpdate (pLvl1Desc, lvl1Desc);
	}

    /* 
     * Get the level 2 descriptor address. If the level 2 descriptor doesn't
     * exist then return ERROR. 
     */

    if (mmu405Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	return (ERROR);

    /* get the level 2 descriptor */

    lvl2Desc = *pLvl2Desc;

    /* save the real address & effective addr in the level 2 descriptors */

    lvl2Desc.field.rpn = (UINT32) physicalAddr >> MMU_RPN_SHIFT;
    lvl2Desc.field.epn = (UINT32) effectiveAddr >> MMU_RPN_SHIFT;

    /* set the valid bit in the level 2 descriptor */
    lvl2Desc.field.v = 1;

    /* update the Level 2 descriptor in table */

    mmu405Lvl2DescUpdate (pLvl2Desc, lvl2Desc);

    /* invalidate the tlb entry for this effective addr */
    mmu405Tlbie (pTransTbl, effectiveAddr);

    return (OK);
    }

/******************************************************************************
*
* mmu405GlobalPageMap - map physical memory page to global virtual memory page
*
* mmuPpcGlobalPageMap is used to map physical pages into global virtual memory
* that is shared by all virtual memory contexts.  The translation tables
* for this section of the virtual space are shared by all virtual memory
* contexts.
*
* RETURNS: OK or ERROR if no pte for given virtual page.
*/

LOCAL STATUS mmu405GlobalPageMap 
    (
    void *  effectiveAddr, 	/* effective address */
    void *  physicalAddr	/* physical address */
    )
    {
    return (mmu405PageMap (&mmuGlobalTransTbl, effectiveAddr, physicalAddr));
    }

/******************************************************************************
*
* mmu405Translate - translate a virtual address to a physical address
*
* Traverse the translation table and extract the physical address for the
* given virtual address from the level 2 descriptor corresponding to the
* virtual address.
*
* RETURNS: OK or ERROR if no level 2 descriptor found for given virtual address.
*/

LOCAL STATUS mmu405Translate 
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

    if (mmu405Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) != OK)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* check if the level 2 descriptor found is valid. If not return ERROR */

    if (!pLvl2Desc->field.v)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    effAddr = * ((EFFECTIVE_ADDR *) &effectiveAddr);

    /* build the real address */

    realAddr.field.rpn = pLvl2Desc->field.rpn;
    realAddr.field.po  = effAddr.field.po;

    * physicalAddr = realAddr.realAddr;

    return (OK);
    }

/******************************************************************************
*
* mmu405CurrentSet - change active translation table
*
* This function changes the virtual memory context by loading the PID
* register with the PID value saved in the translation
* table structure pointed to by <pTransTbl>.
*
* RETURNS: N/A
*
*/

void mmu405CurrentSet 
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
	 mmu405MemPagesWriteDisable (&mmuGlobalTransTbl);
	 mmu405MemPagesWriteDisable (pTransTbl);

	 firstTime = FALSE;
	 }

    lockKey = intLock ();

    /* 
     * save the PID value in the PID register via
     * mmuPpcPidSet(). If one or both MMUs are turned on then disable
     * the MMU, set the PID register and re-enable the MMU.
     */

    if (mmu405IsOn (MMU_INST)  || mmu405IsOn (MMU_DATA))
	{
	mmu405Enable (FALSE);			/* disable the MMU */
    	mmuPpcPidSet (pTransTbl->pid);
	mmu405Enable (TRUE);			/* re-enable  the MMU */
	}
    else
    	mmuPpcPidSet (pTransTbl->pid);

    intUnlock (lockKey);
    }

/*******************************************************************************
*
* mmu405Lvl2DescAddrGet - get the address of a level 2 Desciptor
* 
* This routine finds the address of a level 2 desciptor corresponding to the
* <effectiveAddr> in the translation table pointed to by <pTransTbl> structure.
* If a matching level 2 Descriptor exists, the routine save the level 2
* desciptor address at the address pointed to by <ppLvl2Desc>.
* If any level 2 Descriptor matching the <effectiveAddr> is not found then
* the function return ERROR.
*
* RETURNS: OK or ERROR.
*/

LOCAL STATUS mmu405Lvl2DescAddrGet
    (
    MMU_TRANS_TBL *	pTransTbl,	/* translation table */
    void *		effectiveAddr,	/* effective address */
    LEVEL_2_DESC **	ppLvl2Desc	/* where to save the lvl 2 desc addr */
    )
    {
    LEVEL_1_DESC * 	pLvl1Desc;	/* level 1 descriptor address */
    LEVEL_2_DESC *  	pLvl2Desc;  /* level 2 descriptor address */
    EFFECTIVE_ADDR	effAddr;	/* effective address */

    /* get address of the level 1 descriptor */

    pLvl1Desc = mmu405Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    /* 
     * check the valid bit. If the level 1 descriptor is not valid than
     * the level 2 descriptor doesn't exist. In this case return ERROR.
     */

    if (!pLvl1Desc->field.v)
	return (ERROR);

    effAddr.effAddr = effectiveAddr;

    /* 
     * save the level 2 descriptor address at the address
     * pointed to by <ppLvl2Desc>.
     */

    pLvl2Desc = (LEVEL_2_DESC *) (pLvl1Desc->field.l2ba << 2);
    * ppLvl2Desc = pLvl2Desc + effAddr.field.l2index;

    return (OK);
    }
 
/*******************************************************************************
*
* mmu405Lvl1DescAddrGet - get the address of a level 1 descriptor 
*
* This function returns the address of the level 1 descriptor corresponding
* to the effective address pointed to by <effectiveAddr>. 
*
* RETRUNS: always the address of the level 1 descriptor
*
*/

LOCAL LEVEL_1_DESC * mmu405Lvl1DescAddrGet
    (
    MMU_TRANS_TBL *	pTransTbl,	/* translation table */
    void *		effectiveAddr	/* effective address */
    )
    {
    EFFECTIVE_ADDR	effAddr;

    effAddr = * ((EFFECTIVE_ADDR *) &effectiveAddr);

    /* 
     * build the Level 1 descriptor address corresponding to the effective
     * address pointed to by <effectiveAddr>.
     */
    return ( pTransTbl->l1TblPtr.pL1Desc + effAddr.field.l1index );
    }

/*******************************************************************************
*
* mmu405Lvl1DescUpdate - update a level 1 descriptor 
*
* This function updates a level 1 desciptor. The addess of the level 1
* descriptor is handled by <pLvl1Desc> and the new value of the level 1
* descriptor by <lvl1Desc>.
*
* RETURNS: N/A
*/

LOCAL void mmu405Lvl1DescUpdate
    (
    LEVEL_1_DESC *	pLvl1Desc,	/* Level 1 descriptor address */
    LEVEL_1_DESC	lvl1Desc	/* Level 1 descriptor */
    )
    {
    UINT32	key;

    if (mmu405IsOn (MMU_INST)  || mmu405IsOn (MMU_DATA))
	{
	key = intLock();			/* lock interrupt */
	mmu405Enable (FALSE);                   /* disable the mmu */
	pLvl1Desc->l1desc = lvl1Desc.l1desc;	/* update the descriptor */
	mmu405Enable (TRUE);			/* enable the MMU */
	intUnlock(key);				/* re-enable interrupt */
	}
    else
	pLvl1Desc->l1desc = lvl1Desc.l1desc;	/* update the descriptor */
    }

/*******************************************************************************
*
* mmu405Lvl2DescUpdate - update a level 2 descriptor 
*
* This function updates a level 2 desciptor. The addess of the level 2
* descriptor is handled by <pLvl2Desc> and the new value of the level 2
* descriptor by <lvl2Desc>.
*
* RETURNS: N/A
*/

LOCAL void mmu405Lvl2DescUpdate
    (
    LEVEL_2_DESC *	pLvl2Desc,	/* Level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc	/* Level 2 descriptor */
    )
    {
    UINT32	key;

    if (mmu405IsOn (MMU_INST)  || mmu405IsOn (MMU_DATA))
	{
	key = intLock();			/* lock interrupt */
	mmu405Enable (FALSE);                   /* disable the mmu */
	*pLvl2Desc = lvl2Desc;			/* update the descriptor */
	mmu405Enable (TRUE);			/* enable the MMU */
	intUnlock(key);				/* re-enable interrupt */
	}
    else
	*pLvl2Desc = lvl2Desc;			/* update the descriptor */
    }

/*******************************************************************************
*
* mmu405IsOn - return the state of the MMU
*
* This function returns TRUE if the MMU selected by <mmuType> is on.
*
* RETURNS: TRUE or FALSE
*
*/

LOCAL BOOL mmu405IsOn
    (
    int	mmuType			/* MMU type to return the state of */
    )
    {

    switch (mmuType)
	{
	case MMU_INST:		/* Instruction MMU to test */
	    return (vxMsrGet () & _PPC_MSR_IR);
	    break;

	case MMU_DATA:		/* Data MMU to test */
	    return (vxMsrGet () & _PPC_MSR_DR);
	    break;

	default:		/* default value */
	    return (FALSE);
	}
    }


/*******************************************************************************
*
* mmu405GetNewPid - get a free PID for use with a new address map from 
*		mmuAddrMapArray, and set the address map element
*		to point to MMU_TRANS_TBL pointer.
*
* NOTE: For MMU library internal use only
*
* RETURNS: index of free array element or 0.
*/
UINT8 mmu405GetNewPid (MMU_TRANS_TBL *transTbl)
    {
    int i;

    for (i = 1; i < MMU_ADDR_MAP_ARRAY_SIZE; i++)
        if (mmuAddrMapArray [i] == MMU_ADDR_MAP_ARRAY_INV)
	{
	mmuAddrMapArray [i] = transTbl;
	return i;
	}

    return 0;
    }

/*******************************************************************************
*
* mmu405FreePid - Free (mark as invalid) the pid entry
*
* NOTE: For MMU library internal use only
*
*/
void mmu405FreePid (UINT8 pid)
    {
    mmuAddrMapArray [pid] = MMU_ADDR_MAP_ARRAY_INV;
    }

/*******************************************************************************
*
* mmu405Tlbie - Invalidate tlb entry for the specified effective addr
*
* NOTE: For MMU library internal use only. This function switches the current
* address map to the one pointed to by pTransTbl and then restores it back.
*
*/
void mmu405Tlbie (
    MMU_TRANS_TBL *	pTransTbl,	/* tranlation table */
    void * effAddr			/* EA to invalidate in tlb */
    )
    {
    UINT32 index;
    UINT32 tlbhi;
    UINT32 oldPid;

    /* save old PID */
    oldPid = mmuPpcPidGet ();

    /* set PID to the one for pTransTbl */
    if (oldPid != pTransTbl->pid)
	mmuPpcPidSet (pTransTbl->pid);

    if ((index = mmuPpcTlbSearch (effAddr)) != -1)
	{
	/* read current entry (hi part) */
	tlbhi = mmuPpcTlbReadEntryHi (index);

	/* clear valid bit */
	tlbhi &= ~MMU_STATE_VALID;

	/* write back entry */
	mmuPpcTlbWriteEntryHi (index, tlbhi);
	}	

    /* restore old PID */
    if (oldPid != pTransTbl->pid)
	mmuPpcPidSet (oldPid);
    }


/*******************************************************************************
*
* mmu405Show - show the level 1 and 2 desciptor for and effective address
*
* NOTE: For MMU library debug only 
*/

void mmu405Show 
    (
    MMU_TRANS_TBL *	pTransTbl,		/* translation table */
    void *		effectiveAddr		/* effective address */
    )
    {
    LEVEL_1_DESC *	pLvl1Desc;	/* level 1 descriptor address */
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */

    /* get the level 1 descriptor address */

    pLvl1Desc = mmu405Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    printf ("Level 1:\n");
    printf ("l2ba	= 0x%x\n", pLvl1Desc->field.l2ba);
    printf ("v		= %d\n", pLvl1Desc->field.v);

    if (mmu405Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) != OK)
	return ;

    printf ("\n\n");
    printf ("Level 2:\n");
    printf ("epn	= 0x%x\n", pLvl2Desc->field.epn);
    printf ("size	= 0x%x\n", pLvl2Desc->field.size);
    printf ("v		= %d\n", pLvl2Desc->field.v);
    printf ("e		= %d\n", pLvl2Desc->field.e);
    printf ("u0		= %d\n", pLvl2Desc->field.u0);
    printf ("\n");
    printf ("rpn	= 0x%x\n", pLvl2Desc->field.rpn);
    printf ("ex		= %d\n", pLvl2Desc->field.ex);
    printf ("wr		= %d\n", pLvl2Desc->field.wr);
    printf ("zsel	= 0x%x\n", pLvl2Desc->field.zsel);
    printf ("w 		= %d\n", pLvl2Desc->field.w);
    printf ("i 		= %d\n", pLvl2Desc->field.i);
    printf ("m 		= %d\n", pLvl2Desc->field.m);
    printf ("g 		= %d\n", pLvl2Desc->field.g);
    }

/******************************************************************************
*
* mmu405TlbShow - List the contents of the TLB Entry registers
*
* RETURNS: nothing
*/
void mmu405TlbShow ()
    {
    int	ix;
    UINT32 tlbhi, tlblo;

    for (ix=0; ix<64; ix++)
	{
	tlbhi = mmuPpcTlbReadEntryHi (ix);
	tlblo = mmuPpcTlbReadEntryLo (ix);
	printf ("TLB at index %d : %x %x\n", ix, tlbhi, tlblo);
	}
    }

#ifdef DEBUG_MISS_HANDLER

/******************************************************************************
*
* mmu405MetricsShow - Show Miss Handler metrics for debugging
*
* OPTIONS:
*	0 or 3 for I-MMU and D-MMU (long)
*	1      for I-MMU only (long)
*	2      for D-MMU only (long)
*	4 or 7 for all metrics (short)
*	5      for I-MMU only (short)
*	6      for D-MMU only (short)
*
* RETURNS: nothing
*/
void mmu405MetricsShow
    (
    UINT32 option
    )
    {
    int		i;		/* index into miss array */
    int		firsttime;
    UINT32	effAdrs;	/* effective address from miss array */

    if (option == 0)
	option = 3;

    if (option == 4)
	option = 7;

    if (option & 1)
	{
	printf ("I-MMU: %d misses, %d errors.",
	    mmuPpcITlbMisses, mmuPpcITlbErrors);

	if ((option & 4) == 0)
	    {
	    if (mmuPpcITlbMisses > 0)
		printf(" recent misses:");

	    i = (int)mmuPpcITlbMisses - 256;
	    i = max(0, i);
	    for (firsttime=1; i < mmuPpcITlbMisses; i++)
		{
		if (i % 8 == 0 || firsttime)
		    {
		    printf("\n %3d ", i);
		    firsttime = 0;
		    }

		effAdrs = mmuPpcITlbMissArray[i % 256] & 0xfffffc00;

		printf(" %8x", effAdrs);
		} 
	    }

	printf("\n");
	}

    if (option & 2)
	{
	printf ("D-MMU: %d misses, %d errors.",
	    mmuPpcDTlbMisses, mmuPpcDTlbErrors);

	if ((option & 4) == 0)
	    {
	    if (mmuPpcDTlbMisses > 0)
		printf(" recent misses:");

	    i = (int)mmuPpcDTlbMisses - 256;
	    i = max(0, i);
	    for (firsttime=1; i < mmuPpcDTlbMisses; i++)
		{
		if (i % 8 == 0 || firsttime)
		    {
		    printf("\n %3d ", i);
		    firsttime=0;
		    }

		effAdrs = mmuPpcDTlbMissArray[i % 256] & 0xfffffc00;

		printf(" %8x", effAdrs);
		} 
	    }

	printf("\n");
	}
    }
#endif /* DEBUG_MISS_HANDLER */
