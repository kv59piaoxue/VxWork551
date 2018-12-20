/* mmuE500Lib.c - mmu library for PowerPC e500Core series */

/* Copyright 2001-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01d,30jul03,dtr  Removing some gloabals no longer required.
01c,07jan03,dtr  Adding static TLB entry support.
01b,02dec02,dtr  Adding cache support.
01a,05nov02,pcs  Remove debug sim_printf

*/

/*
DESCRIPTION:
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
#include "arch/ppc/mmuArchVars.h"
#include "arch/ppc/mmuE500Lib.h"

/* defines */

/* typedefs */

/* externals */

IMPORT void	mmuPpcPidSet (UINT8 pid);
IMPORT UINT32	mmuPpcPidGet (void);
IMPORT void	mmuPpcMmucrSet (UINT32 pid);
IMPORT UINT32	mmuPpcMmucrGet (void);
IMPORT UINT32 	mmuPpcTlbReadEntryWord0 (UINT32 index);
IMPORT UINT32	mmuPpcTlbReadEntryWord1 (UINT32 index);
IMPORT UINT32	mmuPpcTlbReadEntryWord2 (UINT32 index);
IMPORT void 	mmuPpcTlbWriteEntryWord0 (UINT32 word0);
IMPORT void 	mmuPpcTlbWriteEntryWord1 (UINT32 word1);
IMPORT void 	mmuPpcTlbWriteEntryWord2 (UINT32 word2);
IMPORT void 	mmuPpcTlbWriteExecute(UINT32 mas0reg);
IMPORT int      mmuPpcE500Tlbie (MMU_TRANS_TBL *pTransTbl,void * effAddr);
IMPORT void	mmuPpcAEnable ();
IMPORT void	mmuPpcADisable ();

IMPORT void	mmuPpcInstTlbMissHandler();
IMPORT void	mmuPpcDataTlbMissHandler();

IMPORT STATE_TRANS_TUPLE *	mmuStateTransArray;
IMPORT int			mmuStateTransArraySize;
IMPORT MMU_LIB_FUNCS		mmuLibFuncs;
IMPORT int			mmuPageBlockSize;

IMPORT BOOL	cacheIToEnable;
IMPORT BOOL	cacheDToEnable;
IMPORT STATUS	cacheArchEnable (CACHE_TYPE cache);
IMPORT STATUS	cacheArchFlush(CACHE_TYPE cache, void *address, size_t bytes);
IMPORT STATUS	cacheArchDisableFromMmu (CACHE_TYPE  cache);
IMPORT void     mmuE500TlbDynamicInvalidate();
IMPORT void     mmuE500TlbStaticInvalidate();

/* globals */

/*
 * a translation table to hold the descriptors for the global transparent
 * translation of physical to virtual memory
 */

MMU_TRANS_TBL * mmuGlobalTransTbl;	/* global translation table */	
TLB_ENTRY_DESC *mmuE500StaticTlbArray;

/*
 * An array of 256 translation table pointers is allocated to store up to 255
 * (entry 0 unused) unique address maps.  This array is indexed by the PID
 * value. A value of -1 denotes an unused entry.
 */
MMU_TRANS_TBL *	mmuAddrMapArray [MMU_ADDR_MAP_ARRAY_SIZE];

/* locals */

/*
 * This table is used to map vmLib per-page mapping attributes to
 * the architecture-specific values stored in the TLB.  Omission of
 * a vmLib attribute combination implies that that combination is not
 * supported in the architecture-specific MMU library.
 */

LOCAL STATE_TRANS_TUPLE mmuStateTransArrayLocal [] =
    {
    {VM_STATE_MASK_VALID,		MMU_STATE_MASK_VALID,
     VM_STATE_VALID,			MMU_STATE_VALID},

    {VM_STATE_MASK_VALID,		MMU_STATE_MASK_VALID,
     VM_STATE_VALID_NOT,		MMU_STATE_VALID_NOT},

    {VM_STATE_MASK_WRITABLE,		MMU_STATE_MASK_WRITABLE,
     VM_STATE_WRITABLE,			MMU_STATE_WRITABLE},

    {VM_STATE_MASK_WRITABLE,		MMU_STATE_MASK_WRITABLE,
     VM_STATE_WRITABLE_NOT,		MMU_STATE_WRITABLE_NOT},

    {VM_STATE_MASK_CACHEABLE,		MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE,		MMU_STATE_CACHEABLE},

    {VM_STATE_MASK_CACHEABLE,		MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE_NOT,		MMU_STATE_CACHEABLE_NOT},

    {VM_STATE_MASK_CACHEABLE,		MMU_STATE_MASK_CACHEABLE,
     VM_STATE_CACHEABLE_WRITETHROUGH,	MMU_STATE_CACHEABLE_WRITETHROUGH},

    {VM_STATE_MASK_GUARDED,		MMU_STATE_MASK_GUARDED,
     VM_STATE_GUARDED,			MMU_STATE_GUARDED},

    {VM_STATE_MASK_GUARDED,		MMU_STATE_MASK_GUARDED,
     VM_STATE_GUARDED_NOT,		MMU_STATE_GUARDED_NOT}
    };

LOCAL UINT32	mmuE500Selected;		/* mmu type selected */


/* forward declarations */

LOCAL MMU_TRANS_TBL *	mmuE500TransTblCreate ();
LOCAL STATUS		mmuE500TransTblDelete (MMU_TRANS_TBL *transTbl);
LOCAL STATUS		mmuE500Enable (BOOL enable);
LOCAL STATUS		mmuE500StateSet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				     UINT stateMask, UINT state);
LOCAL STATUS		mmuE500StateGet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				     UINT *state);
LOCAL STATUS		mmuE500PageMap (MMU_TRANS_TBL *transTbl,
				     void * virtualAddress, void *physPage);
LOCAL STATUS		mmuE500GlobalPageMap (void * virtualAddress,
				    void * physPage);
LOCAL STATUS		mmuE500Translate (MMU_TRANS_TBL * transTbl,
				      void * virtAddress, void ** physAddress);
LOCAL void		mmuE500CurrentSet (MMU_TRANS_TBL * transTbl);
LOCAL STATUS		mmuE500TransTblInit (MMU_TRANS_TBL * pNewTransTbl);
LOCAL LEVEL_1_DESC *	mmuE500Lvl1DescAddrGet (MMU_TRANS_TBL *	pTransTbl,
				    void * effectiveAddr);
LOCAL STATUS		mmuE500Lvl2DescAddrGet (MMU_TRANS_TBL * pTransTbl,
				void * effectiveAddr,
				LEVEL_2_DESC ** ppLvl2Desc);
LOCAL void		mmuE500Lvl1DescUpdate (LEVEL_1_DESC * pLvl1Desc,
				LEVEL_1_DESC lvl1Desc);
LOCAL STATUS		mmuE500Lvl1DescInit (MMU_TRANS_TBL * pTransTbl,
				LEVEL_1_DESC * pLvl1Desc, void * effectiveAddr);
LOCAL void		mmuE500Lvl2DescUpdate (LEVEL_2_DESC * pLvl2Desc,
				LEVEL_2_DESC lvl2Desc);
LOCAL BOOL		mmuE500IsOn (int mmuType);
LOCAL UINT8 		mmuE500PidAlloc (MMU_TRANS_TBL *transTbl);
LOCAL void 		mmuE500PidFree (UINT8 pid);
LOCAL void              mmuE500MemPagesWriteDisable ( MMU_TRANS_TBL * pTransTbl); 
void	                mmuE500TlbStaticInit (int numDescs, 
				              TLB_ENTRY_DESC *pTlbDesc, 
				              BOOL cacheAllow);
/* locals (need forward declarations) */

LOCAL MMU_LIB_FUNCS mmuLibFuncsLocal =
    {
    mmuE500LibInit,
    mmuE500TransTblCreate,
    mmuE500TransTblDelete,
    mmuE500Enable,
    mmuE500StateSet,
    mmuE500StateGet,
    mmuE500PageMap,
    mmuE500GlobalPageMap,
    mmuE500Translate,
    mmuE500CurrentSet
    };

/******************************************************************************
*
* mmuE500LibInit - MMU library initialization
*
* This routine initializes data structures used to store mmu page tables
* so that subsequent page mapping operations can be performed, and so that
* the TLB miss handler exceptions can consult the data structures with
* meaningful results.
*
* The staticTlbNum argument specifies how many static TLB entries are
* defined in the pStaticTlbDesc array.  TLB indices lower than
* staticTlbNum are used for static page mapping.  staticTlbNum also
* specifies the lowest TLB index that the mmuE500Lib is allowed to use
* for dynamic page mapping.
*
* RETURNS: OK, or ERROR if <mmuType> is incorrect or memory allocation
*	failed.
*/

STATUS mmuE500LibInit
    (
    int 	mmuType,		/* data and/or instr. MMU to init */
    int		staticTlbNum,		/* number of static TLB Entries */
    TLB_ENTRY_DESC * pStaticTlbDesc	/* array of static TLB descriptions */
    )
    {

    /* check if the MMU type to initialize is coherent */
    if (!(mmuType & MMU_INST) && !(mmuType & MMU_DATA))
	{
	/*
	 * too soon in boot process to print a string, so store one in the
	 * exception message area.
	 */
	strcpy(sysExcMsg, "e500 MMU config failed: either enable I or D MMU, "
			  "or remove MMU support\n");
	return (ERROR);
	}

    /* save the Data and/or Instruction MMU selected */

    mmuE500Selected = mmuType;

    /* initialize the exception table:
     * 	At the exception offset, we put a branch instruction (0x48000002)
     *  OR'ed with the address of the TLB miss handler.
     */
    if (mmuType & MMU_INST)
	{
	if ((UINT32)mmuPpcInstTlbMissHandler > 0x03fffffc)
	    {
	    strcpy(sysExcMsg, "e500 MMU config failed: TLB miss handler "
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
	    strcpy(sysExcMsg, "e500 MMU config failed: TLB miss handler "
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

    /* Remove old CAM TLB1 entries, leave TLB0 entries as required for mem access*/
    mmuE500TlbStaticInvalidate(); /* Just CAMS TLBSEL = 1 */

    /* set up the static TLB entries with caching on */

    mmuE500TlbStaticInit(staticTlbNum, pStaticTlbDesc, TRUE);

    /* create the global translation table */

    mmuGlobalTransTbl = mmuE500TransTblCreate();

    if (mmuGlobalTransTbl == NULL)
	{
	strcpy(sysExcMsg, "e500 MMU config failed: could not allocate "
	    "global trans table\n");
	return (ERROR);
	}

    /* initialize the PID register (it won't be accessed until MSR[IS,DS]
     * gets set later) and invalidate all dynamic TLB entries
     */

    mmuPpcPidSet (mmuGlobalTransTbl->pid);

    /* initialize the data objects that are shared with vmLib.c */

    mmuStateTransArray = &mmuStateTransArrayLocal [0];

    mmuStateTransArraySize =
		sizeof (mmuStateTransArrayLocal) / sizeof (STATE_TRANS_TUPLE);

    mmuLibFuncs = mmuLibFuncsLocal;

    mmuPageBlockSize = MMU_PAGE_SIZE;

    /* Invalidate all dynamic TLB entries before MMU is enabled */
    mmuE500TlbDynamicInvalidate();    


    return (OK);

    }

/******************************************************************************
*
* mmuE500TransTblCreate - create a new translation table.
*
* RETURNS: address of new object or NULL if allocation failed.
*/

LOCAL MMU_TRANS_TBL * mmuE500TransTblCreate (void)
    {
    MMU_TRANS_TBL *	pNewTransTbl;		/* new translation table */

    /* allocate a piece of memory to save the new translation table */

    pNewTransTbl = (MMU_TRANS_TBL *) malloc (sizeof (MMU_TRANS_TBL));

    /* if the memory can not allocated then return the NULL pointer */

    if (pNewTransTbl == NULL)
    {
	return (NULL);
    }
    /* get a free PID for the new translation table */

    pNewTransTbl->pid = mmuE500PidAlloc (pNewTransTbl);

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

    if (mmuE500TransTblInit (pNewTransTbl) == ERROR)
	{
	free ((char *) pNewTransTbl);
	return (NULL);
	}

    /* return the new translation table created */

    return (pNewTransTbl);
    }

/******************************************************************************
*
* mmuE500TransTblInit - initialize a new translation table
*
* Initialize a new translation table.  The level 1 table is copied from the
* global translation mmuGlobalTransTbl, so that we will share the global
* virtual memory with all other translation tables.
*
* RETURNS: OK, or ERROR if unable to allocate memory.
*/

LOCAL STATUS mmuE500TransTblInit
    (
    MMU_TRANS_TBL * pNewTransTbl	/* translation table to initialize */
    )
    {
    /*
     * Allocate memory space for a new Level 1 descriptor table.  This memory
     * needs to be page aligned because, we write protect all the page tables
     * later, and we don't want other variables sharing a page with the page
     * table itself.
     */

    pNewTransTbl->l1TblPtr.pL1Desc =
	(LEVEL_1_DESC *) memalign (MMU_PAGE_SIZE, MMU_PAGE_SIZE);

    /* if the memory cannot be allocated then return ERROR */

    if (pNewTransTbl->l1TblPtr.pL1Desc == NULL)
	return (ERROR);

    /* invalidate all entries in the table */

    memset ((void *) pNewTransTbl->l1TblPtr.pL1Desc, 0x00, MMU_PAGE_SIZE);

    if (mmuGlobalTransTbl != NULL)
	{
	/* copy the global level 1 descriptor table to the new table */

	memcpy ((void *) pNewTransTbl->l1TblPtr.pL1Desc,
	    (void *) mmuGlobalTransTbl->l1TblPtr.pL1Desc, MMU_PAGE_SIZE);
	}

    /* In AE, would page protect the new L1 descriptor table here */

    return (OK);
    }

/******************************************************************************
*
* mmuE500TransTblDelete - delete a translation table.
*
* This routine deletes a translation table.
*
* RETURNS: OK always.
*/

LOCAL STATUS mmuE500TransTblDelete
    (
    MMU_TRANS_TBL * pTransTbl		/* translation table to be deleted */
    )
    {
    LEVEL_1_DESC 	lvl1Desc;	/* level 1 descriptor */
    UINT32		ix;

    /* free the PID element for this translation table */

    mmuE500PidFree (pTransTbl->pid);

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
* mmuE500Enable - turn mmu on or off
*
* On the PPCE500, the MMU is always on, so turning it off is a misnomer.
* Instead, this function changes the MSR[IS,DS] values, which change which TLB
* entries match -- either the static ones that emulate 'real mode', or the ones
* that provide dynamic mmu page mapping.
*
* RETURNS: OK
*/

LOCAL STATUS mmuE500Enable
    (
    BOOL enable			/* TRUE to enable, FALSE to disable MMU */
    )
    {
    int lockKey;		/* lock key for intUnlock() */

    /* lock the interrupt */

    lockKey = intLock ();

    if (enable)
	{

	if (mmuE500Selected & MMU_INST)
	    {
	    mmuPpcAEnable (MMU_I_ADDR_TRANS);	/* enable instruction MMU */
	    mmuPpcIEnabled = TRUE;		/* tell I MMU is turned on */

	    /* test if the Instruction cache should be enabled too */

	    if (cacheIToEnable)			
		cacheArchEnable (_INSTRUCTION_CACHE);	/* enable the I cache */
	    }

	if (mmuE500Selected & MMU_DATA)
	    {
	    mmuPpcAEnable (MMU_D_ADDR_TRANS);	/* enable data MMU */
	    mmuPpcDEnabled = TRUE;		/* tell D MMU is turned on */

	    /* test if the Data cache should be enabled too */

	    if (cacheDToEnable)
		cacheArchEnable (_DATA_CACHE);		/* enable the D cache */
	    }

	}
    else
	{

	if (mmuE500Selected & MMU_INST)
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

	if (mmuE500Selected & MMU_DATA)
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
	}
	
    /* AE would unmap EA 0x0 - 0x2fff here, but only for user mode tasks */

    intUnlock (lockKey);			/* unlock the interrupt */

    return (OK);
    }

/******************************************************************************
*
* mmuE500GlobalPageMap - map physical memory page to global virtual memory page
*
* mmuPpcGlobalPageMap is used to map physical pages into global virtual memory
* that is shared by all virtual memory contexts.  The translation tables
* for this section of the virtual space are shared by all virtual memory
* contexts.
*
* RETURNS: OK, or ERROR if no pte for given virtual page.
*/

LOCAL STATUS mmuE500GlobalPageMap
    (
    void *  effectiveAddr, 	/* effective address */
    void *  physicalAddr	/* physical address */
    )
    {
    return (mmuE500PageMap (mmuGlobalTransTbl, effectiveAddr, physicalAddr));
    }


/******************************************************************************
*
* mmuE500PageMap - map physical memory page to virtual memory page
*
* The physical page address is entered into the level 2 descriptor
* corresponding to the given virtual page.  The state of a newly mapped page
* is undefined.
*
* RETURNS: OK, or ERROR if translation table creation failed.
*/

LOCAL STATUS mmuE500PageMap
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

    /* get the level 1 descriptor address */

    pLvl1Desc = mmuE500Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    /* get the level 1 descriptor */

    lvl1Desc.l1desc = pLvl1Desc->l1desc;

    if (!lvl1Desc.field.v)
	{
	if (mmuE500Lvl1DescInit(pTransTbl, pLvl1Desc, effectiveAddr) == ERROR)
	    return (ERROR);
	}

    /*
     * Get the level 2 descriptor address. If the level 2 descriptor doesn't
     * exist then return ERROR.
     */

    if (mmuE500Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	return (ERROR);

    /* get the level 2 descriptor */

    lvl2Desc = *pLvl2Desc;

    /* save the real address & effective addr in the level 2 descriptors */

    lvl2Desc.field.rpn = (UINT32) physicalAddr >> MMU_RPN_SHIFT;
    lvl2Desc.field.epn = (UINT32) effectiveAddr >> MMU_RPN_SHIFT;

    /* set the valid bit in the level 2 descriptor */
    lvl2Desc.field.v = 1;

    /* update the Level 2 descriptor in table */

    mmuE500Lvl2DescUpdate (pLvl2Desc, lvl2Desc);

    /* invalidate the tlb entry for this effective addr */
    mmuPpcE500Tlbie (pTransTbl, effectiveAddr);

    return (OK);
    }


/***********************************************************************
*
* mmuE500Lvl1DescInit -- initialize a level 1 descriptor
*
* Create the level 2 descriptor table, fill it in with appropriate
* defaults, and set up the level 1 descriptor to point at it.
*/

LOCAL STATUS mmuE500Lvl1DescInit
    (
    MMU_TRANS_TBL *	pTransTbl, 	/* translation table */
    LEVEL_1_DESC *	pLvl1Desc,	/* level 1 descriptor address */
    void *		effectiveAddr 	/* effective address */
    )
    {
    LEVEL_2_DESC *	pLvl2Desc;	/* Level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc;	/* Level 2 descriptor copy */
    LEVEL_1_DESC	lvl1Desc;	/* level 1 descriptor copy */
    int			ix;		/* general index counter */

    /*
     * Allocate memory to save the level 2 descriptor table.
     * The level 2 table needs to be aligned on a page boundary
     * and has a size of 1024 entries * 16 bytes/entry = 16K.
     */

    pLvl2Desc = (LEVEL_2_DESC *) memalign (MMU_PAGE_SIZE,
			    MMU_LVL_2_DESC_NB * sizeof(LEVEL_2_DESC));

    /*
     * check if the level 2 descriptor table was created properly.
     * If not then return ERROR.
     */

    if (pLvl2Desc == NULL)
	return (ERROR);
	
    /*
     * Initialize the very first level 2 descriptor in the table.
     * Note it is set up invalid.
     */

    /* word 0 */
    lvl2Desc.field.v     = 0;		/* initially invalid */
    lvl2Desc.field.iprot = 0;		/* not invalidate protected */
    lvl2Desc.field.rsvd1 = 0;
    lvl2Desc.field.tid   = 0;		/* tid = 0  */
    lvl2Desc.field.rsvd2 = 0;
    lvl2Desc.field.ts    = 1;		/* translation space 1 */
    lvl2Desc.field.tsize = 1;		/* default 4KB page */
    lvl2Desc.field.rsvd3 = 0;

    /* word 1 */
    lvl2Desc.field.epn    = 0;		/* effective page number */
    lvl2Desc.field.rsvd4  = 0;
    lvl2Desc.field.sharen = 0;		/* Do not enable cache fills to use shared cache stat */
    lvl2Desc.field.rsvd5  = 0;
    lvl2Desc.field.x0     = 0;		/* user defined 0 */
    lvl2Desc.field.x1     = 0;		/* user defined 1 */
    lvl2Desc.field.w      = 0;		/* no write thru */
    lvl2Desc.field.i      = 0;		/* no cache inhibit */
    lvl2Desc.field.m      = 0;		/* memory coherent: no effect */
    lvl2Desc.field.g      = 0;		/* memory unguarded */
    lvl2Desc.field.e      = 0;		/* big endian */

    /* word 2 */
    lvl2Desc.field.rpn   = 0;		/* real page number */
    lvl2Desc.field.rsvd6 = 0;	
    lvl2Desc.field.u0 = 0;		/* user attribute 0 unused */
    lvl2Desc.field.u1 = 0;		/* user attribute 1 unused */
    lvl2Desc.field.u2 = 0;		/* user attribute 2 unused */
    lvl2Desc.field.u3 = 0;		/* user attribute 3 unused */
    lvl2Desc.field.ux = 0;		/* user execute off */
    lvl2Desc.field.sx = 1;		/* supervisor execute on */
    lvl2Desc.field.uw = 0;		/* user write off */
    lvl2Desc.field.sw = 0;		/* supervisor write off */
    lvl2Desc.field.ur = 0;		/* user read off */
    lvl2Desc.field.sr = 1;		/* supervisor read on */

    /* word 3 */
    lvl2Desc.field.rsvd7 = 0;		

    /*
     * duplicate the first L2 descriptor through the rest of the table
     */

    for (ix = 0; ix < MMU_LVL_2_DESC_NB; ix ++)
	pLvl2Desc[ix] = lvl2Desc;

    /*
     * set up the Level 1 Descriptor with the new level 2 table pointer
     */

    lvl1Desc.l1desc = ((UINT32) pLvl2Desc) & MMU_LVL_1_L2BA_MSK;
    lvl1Desc.field.v   = 1;	/* segment valid */

    /* update the Level 1 descriptor in table */

    mmuE500Lvl1DescUpdate (pLvl1Desc, lvl1Desc);

    return (OK);
    }


/*******************************************************************************
*
* mmuE500Lvl1DescUpdate - update a level 1 descriptor
*
* This function updates a level 1 descriptor. The address of the level 1
* descriptor is handled by <pLvl1Desc> and the new value of the level 1
* descriptor by <lvl1Desc>.
*
* RETURNS: N/A
*/

LOCAL void mmuE500Lvl1DescUpdate
    (
    LEVEL_1_DESC *	pLvl1Desc,	/* Level 1 descriptor address */
    LEVEL_1_DESC	lvl1Desc	/* Level 1 descriptor */
    )
    {
    UINT32	key;

    if (mmuE500IsOn (MMU_INST)  || mmuE500IsOn (MMU_DATA))
	{
	/* circumvent page protection by turning MMU off to write entry */

	key = intLock();			/* lock interrupt */
	mmuE500Enable (FALSE);                   /* disable the mmu */
	pLvl1Desc->l1desc = lvl1Desc.l1desc;	/* update the descriptor */
	mmuE500Enable (TRUE);			/* enable the MMU */
	intUnlock(key);				/* re-enable interrupt */
	}
    else
	pLvl1Desc->l1desc = lvl1Desc.l1desc;	/* update the descriptor */
    }


/*******************************************************************************
*
* mmuE500Lvl2DescAddrGet - get the address of a level 2 Desciptor
*
* This routine finds the address of a level 2 descriptor corresponding to the
* <effectiveAddr> in the translation table pointed to by <pTransTbl> structure.
* If a matching level 2 Descriptor exists, the routine save the level 2
* descriptor address at the address pointed to by <ppLvl2Desc>.
* If any level 2 Descriptor matching the <effectiveAddr> is not found then
* the function return ERROR.
*
* RETURNS: OK or ERROR.
*/

LOCAL STATUS mmuE500Lvl2DescAddrGet
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

    pLvl1Desc = mmuE500Lvl1DescAddrGet (pTransTbl, effectiveAddr);

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
* mmuE500Lvl2DescUpdate - update a level 2 descriptor
*
* This function updates a level 2 descriptor. The addess of the level 2
* descriptor is handled by <pLvl2Desc> and the new value of the level 2
* descriptor by <lvl2Desc>.
*
* RETURNS: N/A
*/

LOCAL void mmuE500Lvl2DescUpdate
    (
    LEVEL_2_DESC *	pLvl2Desc,	/* Level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc	/* Level 2 descriptor */
    )
    {
    UINT32	key;

    if (mmuE500IsOn (MMU_INST)  || mmuE500IsOn (MMU_DATA))
	{
	/* circumvent page protection by turning MMU off to write entry */

	key = intLock();			/* lock interrupt */
	mmuE500Enable (FALSE);                   /* disable the mmu */
	*pLvl2Desc = lvl2Desc;			/* update the descriptor */
	mmuE500Enable (TRUE);			/* enable the MMU */
	intUnlock(key);				/* re-enable interrupt */
	}
    else
	*pLvl2Desc = lvl2Desc;			/* update the descriptor */
    }

/*******************************************************************************
*
* mmuE500Lvl1DescAddrGet - get the address of a level 1 descriptor
*
* This function returns the address of the level 1 descriptor corresponding
* to the effective address pointed to by <effectiveAddr>.
*
* RETRUNS: always the address of the level 1 descriptor
*
*/

LOCAL LEVEL_1_DESC * mmuE500Lvl1DescAddrGet
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
* mmuE500IsOn - return the state of the MMU
*
* This function returns TRUE if the MMU selected by <mmuType> is set to
* translation space 1.
*
* RETURNS: TRUE or FALSE
*
*/

LOCAL BOOL mmuE500IsOn
    (
    int	mmuType			/* MMU type to return the state of */
    )
    {

    switch (mmuType)
	{
	case MMU_INST:		/* Instruction MMU to test */
	    return (vxMsrGet () & _PPC_MSR_IS);
	    break;

	case MMU_DATA:		/* Data MMU to test */
	    return (vxMsrGet () & _PPC_MSR_DS);
	    break;

	default:		/* default value */
	    return (FALSE);
	}
    }


/*******************************************************************************
*
* mmuE500PidAlloc - get a free PID for use with a new address map from
*		mmuAddrMapArray, and set the address map element
*		to point to MMU_TRANS_TBL pointer.
*
* NOTE: For MMU library internal use only
*
* RETURNS: index of free array element, or -1 for ERROR.
*/
LOCAL UINT8 mmuE500PidAlloc (MMU_TRANS_TBL *transTbl)
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
* mmuE500PidFree - Free (mark as invalid) the pid entry
*
* NOTE: For MMU library internal use only
*
*/
LOCAL void mmuE500PidFree (UINT8 pid)
    {
    mmuAddrMapArray [pid] = MMU_ADDR_MAP_ARRAY_INV;
    }

/*******************************************************************************
*
* mmuE500TlbStaticEntrySet - write a static TLB entry
*
* This function writes one MMU TLB Entry based on the given TLB Entry
* Description.
*
* CAVEAT: If previously-enabled caching is being disabled, the caller must
* pre-flush or pre-invalidate the appropriate cache lines prior to calling
* this function.
*
* NOTE: For MMU library internal use only.
*
*/

LOCAL void mmuE500TlbStaticEntrySet
    (
    int		     index,	/* index of TLB Entry to set */
    TLB_ENTRY_DESC * pTlbDesc,	/* description of TLB Entry to set */
    BOOL	     cacheAllow	/* if TRUE allow caching to be turned on */
    )
    {
    LEVEL_2_DESC	lvl2Desc;	/* TLB entry */

    /*
     * fill in all fields of a LEVEL_2_DESC with data from the
     * TLB_ENTRY_DESC. Use that to write the TLB Entry words.
     */

    lvl2Desc.field.epn = pTlbDesc->effAddr >> MMU_RPN_SHIFT;
    lvl2Desc.field.rsvd1 = 0;
    lvl2Desc.field.v = 1;		/* valid */
    lvl2Desc.field.iprot = ((pTlbDesc->attr & _MMU_TLB_IPROT) ? 1 : 0);	
    lvl2Desc.field.ts = ((pTlbDesc->attr & _MMU_TLB_TS_1) ? 1 : 0);
    lvl2Desc.field.tsize =
	((pTlbDesc->attr & _MMU_TLB_SZ_MASK) >> _MMU_TLB_SZ_SHIFT);
    lvl2Desc.field.rsvd2 = 0;

    lvl2Desc.field.rpn = pTlbDesc->realAddr >> MMU_RPN_SHIFT;
    lvl2Desc.field.rsvd3 = 0;	
    lvl2Desc.field.tid = 0;

    lvl2Desc.field.rsvd4 = 0;	
    lvl2Desc.field.u0 = 0;		/* user attribute 0 unused */
    lvl2Desc.field.u1 = 0;		/* user attribute 1 unused */
    lvl2Desc.field.u2 = 0;		/* user attribute 2 unused */
    lvl2Desc.field.u3 = 0;		/* user attribute 3 unused */

    if (cacheAllow == TRUE)
	{
	/* cache as desired */
	lvl2Desc.field.w = (pTlbDesc->attr & _MMU_TLB_ATTR_W ? 1 : 0);
	lvl2Desc.field.i = (pTlbDesc->attr & _MMU_TLB_ATTR_I ? 1 : 0);
	}
    else
	{
	/* cache inhibited -- warning, caller must preflush if necessary */
	lvl2Desc.field.w = 0;
	lvl2Desc.field.i = 1;
	}

    lvl2Desc.field.m = (pTlbDesc->attr & _MMU_TLB_ATTR_M ? 1 : 0); 
    lvl2Desc.field.g = (pTlbDesc->attr & _MMU_TLB_ATTR_G ? 1 : 0);
    lvl2Desc.field.e = 0;		/* big endian */
    lvl2Desc.field.rsvd5 = 0;	
    lvl2Desc.field.ux = 0;		/* user execute off */
    lvl2Desc.field.uw = 0;		/* user write off */
    lvl2Desc.field.ur = 0;		/* user read off */
    lvl2Desc.field.sx = (pTlbDesc->attr & _MMU_TLB_PERM_X ? 1 : 0);
    lvl2Desc.field.sw = (pTlbDesc->attr & _MMU_TLB_PERM_W ? 1 : 0);
    lvl2Desc.field.sr = 1;		/* supervisor read on */
    lvl2Desc.field.rsvd6 = 0;	

    /* write current entry -- uses MMUCR[STID] as a side effect */
    _WRS_ASM("sync");
    mmuPpcTlbWriteEntryWord0 ((UINT32)lvl2Desc.words.word0);
    mmuPpcTlbWriteEntryWord1 ((UINT32)lvl2Desc.words.word1);
    mmuPpcTlbWriteEntryWord2 ((UINT32)lvl2Desc.words.word2);
    mmuPpcTlbWriteExecute(((index << _PPC_MAS0_ESEL_BIT) & _PPC_MAS0_ESEL_MASK) |  _PPC_MAS0_TLBSEL1);
    }

/*******************************************************************************
*
* mmuE500TlbStaticInit - initialize all static TLB entries
*
* This function initializes MMU TLB Entries from the supplied array of
* TLB Entry Descriptions.
*
* CAVEAT: If previously-enabled caching is being disabled, the caller must
* pre-flush or pre-invalidate the appropriate cache lines prior to calling
* this function.
*
* NOTE: For MMU library internal use only.
*
*/
void mmuE500TlbStaticInit
    (
    int		     numDescs,	/* number of TLB Entry Descriptors */
    TLB_ENTRY_DESC * pTlbDesc,	/* pointer to array of TLB Entries */
    BOOL	     cacheAllow	/* if TRUE, caching will be enabled */
    )
    {
    UINT32		index;		/* current index being init'ed */

    for (index = 0; index < numDescs; index++, pTlbDesc++)
	mmuE500TlbStaticEntrySet(index, pTlbDesc, cacheAllow);
    }

/******************************************************************************
*
* mmuE500StateSet - set state of virtual memory page
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

LOCAL STATUS mmuE500StateSet
    (
    MMU_TRANS_TBL *	pTransTbl, 	/* translation table */
    void *		effectiveAddr,	/* page whose state to modify */
    UINT 		stateMask,	/* mask of which state bits to modify */
    UINT		state		/* new state bit values */
    )
    {
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc;	/* level 2 descriptor */
    BOOL		flush = FALSE;	/* page must be flushed from cache */

    /*
     * get the level 2 descriptor address. If this descriptor address doesn't
     * exist then set errno and return ERROR.
     */

    if (mmuE500Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* make a working copy of the Level 2 Descriptor */

    lvl2Desc = *pLvl2Desc;

    if (stateMask & MMU_STATE_MASK_CACHEABLE)
	{
	/*
	 * Check if the state to set page corresponding to <effectiveAddr>
	 * will not set the cache inhibited and writethrough mode. This mode
	 * is not supported by the cache.
	 */

	if ((state & MMU_STATE_CACHEABLE_NOT) &&
	    (state & MMU_STATE_CACHEABLE_WRITETHROUGH))
	    {
	    return (ERROR);
	    }

	/*
	 * if the page is presently COPYBACK, and we plan to set it to
	 * cache inhibited or writeback, flush the page before continuing.
	 */

	if (lvl2Desc.field.v &&
	    ((lvl2Desc.words.word2 & MMU_STATE_MASK_CACHEABLE) ==
	     MMU_STATE_CACHEABLE_COPYBACK) &&
	    ((state & MMU_STATE_MASK_CACHEABLE) !=
	     MMU_STATE_CACHEABLE_COPYBACK))
	    {
	    flush = TRUE;
	    }
	}

    /*
     * set or reset the VALID bit if requested. Since the Valid bit
     * in MMU_STATE is in a different bit position than in the TLB Word 0,
     * we use an if statement to express the logic clearly rather than
     * use a complicated mixture of shift, or, and and.
     */

    if (stateMask & MMU_STATE_MASK_VALID)
	{
	if (state & stateMask & MMU_STATE_MASK_VALID)
	    lvl2Desc.field.v = 1;
	else
	    lvl2Desc.field.v = 0;
	}

    /*
     * set or reset write/execute bits as requested. The write/execute bits
     * are not in the same bit positions in MMU_STATE as in TLB Word 2.
     * They are shifted left by 8 bits as compared to there position in TLB word 2
     */
    lvl2Desc.words.word2 &= ~(((stateMask & MMU_STATE_MASK_WRITABLE_EXECUTE) >> 8));
    lvl2Desc.words.word2 |= (((state & stateMask &
			     MMU_STATE_MASK_WRITABLE_EXECUTE) >> 8));

    /*
     * set or reset the WIMG bits as requested. WIMG are in the same bit 
     * positions in MMU_STATE as in TLB Word 2, so we can use bitwise arithmetic
     */
    lvl2Desc.words.word1 &= ~(stateMask & MMU_STATE_MASK_WIMG);
    lvl2Desc.words.word1 |= (state & stateMask &
			     MMU_STATE_MASK_WIMG);

    if (stateMask & MMU_STATE_MASK_GUARDED)
	{
	  if (state & MMU_STATE_GUARDED)
	      {
	      lvl2Desc.field.ux = 0;		/* user execute off */
	      lvl2Desc.field.sx = 0;		/* supervisor execute off */
	      }
	  else
	      {
	      lvl2Desc.field.ux = 0;		/* user execute off */
	      lvl2Desc.field.sx = 1;		/* supervisor execute on */
	      }
	}

    /* flush out any copyback data before we change the attribute mapping */

    if (flush == TRUE)
	cacheArchFlush(DATA_CACHE, effectiveAddr, MMU_PAGE_SIZE);

    /* update the Level 2 Descriptor */

    mmuE500Lvl2DescUpdate (pLvl2Desc, lvl2Desc);

    /* invalidate the tlb entry for this effective address */

    mmuPpcE500Tlbie (pTransTbl, effectiveAddr);

    return (OK);
    }

/******************************************************************************
*
* mmuE500StateGet - get state of virtual memory page
*
*/

LOCAL STATUS mmuE500StateGet
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

    if (mmuE500Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* make a working copy the Level 2 Descriptor */

    lvl2Desc = *pLvl2Desc;

    /* 
     * extract the state of the VALID, WIMG and EX, WR bits.
     */

    * state = (lvl2Desc.field.v ? MMU_STATE_VALID : 0);
    * state |= lvl2Desc.words.word1 & MMU_STATE_MASK_WIMG;
    
    /* 
     * Note that the writable & execute bits are in a different bit position in 
     * L2 desc than in the MMU_STATE.
     */

    * state |= ( (lvl2Desc.words.word2 & (MMU_STATE_MASK_WRITABLE_EXECUTE>>8)) << 8);

    return (OK);
    }


/******************************************************************************
*
* mmuE500CurrentSet - change active translation table
*
* This function changes the virtual memory context by loading the PID
* register with the PID value saved in the translation
* table structure pointed to by <pTransTbl>.
*
* RETURNS: N/A
*
*/

LOCAL void mmuE500CurrentSet
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
	 mmuE500MemPagesWriteDisable (mmuGlobalTransTbl);
	 mmuE500MemPagesWriteDisable (pTransTbl);

	 firstTime = FALSE;
	 }

    lockKey = intLock ();

    /*
     * save the PID value in the PID register via
     * mmuPpcPidSet(). If one or both MMUs are turned on then disable
     * the MMU, set the PID register and re-enable the MMU.
     */
    
    if (mmuE500IsOn (MMU_INST)  || mmuE500IsOn (MMU_DATA))
	{
	mmuE500Enable (FALSE);			/* disable the MMU */
    	mmuPpcPidSet (pTransTbl->pid);
	mmuE500Enable (TRUE);			/* re-enable  the MMU */
	}
    else
    	mmuPpcPidSet (pTransTbl->pid);

    intUnlock (lockKey);
    }


/******************************************************************************
*
* mmuE500Translate - translate a virtual address to a physical address
*
* Traverse the translation table and extract the physical address for the
* given virtual address from the level 2 descriptor corresponding to the
* virtual address.
*
* RETURNS: OK, or ERROR if no level 2 descriptor found for given virtual address.
*/

LOCAL STATUS mmuE500Translate
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

    if (mmuE500Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) != OK)
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
* mmuE500MemPagesWriteDisable - write disable memory holding PTEs
*
* Memory containing translation table descriptors is marked as read only
* to protect the descriptors from being corrupted.  This routine write protects
* all the memory used to contain a given translation table's descriptors.
*
* RETURNS: N/A
*/

LOCAL void mmuE500MemPagesWriteDisable
    (
    MMU_TRANS_TBL * pTransTbl		/* Translation table to disable */
    )
    {
    int		 ix;			/* index of L1 entries */
    int		 jx;			/* index into L2 table pages */
    LEVEL_1_DESC lvl1Desc;		/* current L1 descriptor */

    /* we need to disable writes on the level 1 page table and each level 2
     * page table. The level 1 page table is MMU_PAGE_SIZE in size, whereas
     * the level 2 page table is 4 * MMU_PAGE_SIZE in size.
     */

    /* write protect the level 1 page table */
    mmuE500StateSet (pTransTbl, (void *)pTransTbl->l1TblPtr.pL1Desc,
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT);

    /* go thru the L 1 table and write protect each L 2 table */
    for (ix = 0 ; ix < MMU_LVL_2_DESC_NB; ix++)
	{
	lvl1Desc = * (pTransTbl->l1TblPtr.pL1Desc + ix);

	if (lvl1Desc.field.v)
	    {
	    for (jx = 0; jx < 4; jx++)
		{
		mmuE500StateSet (pTransTbl,
				 (void *)((lvl1Desc.field.l2ba << 2) + 
					  (jx * MMU_PAGE_SIZE)),
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT);
		}
	    }
	}
    }
