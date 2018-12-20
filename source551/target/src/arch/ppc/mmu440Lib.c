/* mmu440Lib.c - mmu library for PowerPC 440 series */

/* Copyright 2001-2003 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01e,30jan03,jtp  SPR 85792 support caching by allowing no selected MMUs
01d,02jan03,jtp  SPR 82770 move mmuPpcSelected to mmuArchVars.c
01c,08may02,pch  fix copy/paste error in previous checkin:
		 this is a 440, not a 405.
01b,25apr02,pch  SPR 74926: don't connect to unused vector
01a,17apr02,jtp	 written.
*/

/*
DESCRIPTION:

mmu440Lib.c provides the architecture dependent routines that directly
control the memory management unit for the PowerPC 440 series.  It
provides routines that are called by the higher level architecture
independent routines in vmLib.c or vmBaseLib.c.

The PPC440 is a BookE Specification processor.  BookE Memory Management
Units (MMU) are always on, and cannot be turned off.  The PPC440GP
contains a cache of 64 virtual-to-physical page mappings in a
Translation Lookaside Buffer (TLB) cache.  Each cache entry can be
addressed with a TLB Entry index.

Lower-numbered TLB indexes are used to set up a static mapping of
memory.  Typically large blocks of memory (256MB chunks) are mapped via
each static TLB entry. The lowest TLB entries set the Translation Space
(TS) field of the TLB entries to 0. These entries are used when the MSR
register IS and/or DS fields are set to '0', and are used to emulate
conventional 'real mode' access.  In the bootrom, romInit.s is
responsible for initializing a bare-bones static mapping.

Once booted, a description of the desired static TLB mappings is passed
in to mmu440LibInit, and it reinitializes the static TLB entries,
overwriting the ones established by romInit. A few of these entries have
the TS field set to 1, for use when the vmLib is 'enabled', and are used
to map program addresses to physical addresses that cannot be expressed
in a 32 bit pointer. Once initialized, these lower-numbered TLB entries
are largely left unperturbed by the mmu440Lib.

Higher-numbered TLB indexes are used by the 440 MMU library to
dynamically map memory.  The minimum usable TLB index is defined by the
BSP and passed in as an argument to mmu440LibInit during system
initialization.  All the pages mapped by this library set the TS
(Translation Space) field of the TLB entries to 1.  These entries are
used when the MSR IS and/or DS fields are set to '1'. The blocks of
memory mapped are 4KB (MMU_PAGE_SIZE) in size. As a result, the TLB
cache entries can only map a small fraction of the available program
address space and the TLB Miss handler recycles them as needed in a
round-robin fashion.

This implementation supports the use of multiple program address spaces.
TLB Entries with a TID field of 0 (causing them to match all program
address spaces) are used for the static mapping. TLB Entries with
non-zero TID fields are used for dynamic mapping.  The global trans
table (used for the kernel's initial vm context) uses a TID of 2, and
subsequent trans tables are given a copy of the global trans table's L1
table as they are created.

Cache library interaction: The Book E specification and the PPC440GP
implementation do not provide a means to set global cache enable/disable
without manipulating individual TLB entries.  Therefore, as in the
PPC60X series kernels, changes to the cacheability of individual blocks
and pages of memory are deferred to this MMU library: enabling the cache
requires the MMU library.

Furthermore, since cacheability is controlled by a single pair of bits
(W, I) on a per-TLB basis, the cacheability of instructions versus data
within the same virtual address mapping cannot be independently
controlled. In the PPC440 the selections for data and instruction cache
enablement and mode must be identical.

Lastly, the MMU library may be configured but neither I nor D MMU
selected for enablement. This permits the MMU libary to set up the
static TLB mappings and enable the cache on them, but it does not
make use of the dynamic TLB entries. This may be desired for some
applications.

For more details on the 440's cache implementation, see cache440ALib.s.

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
#include "arch/ppc/mmu440Lib.h"

/* defines */

/* typedefs */

/*
 * The MMUCR register is important for TLB entry search, read and write:
 *
 *   Search: sts and stid fields are used by tlbsx instruction.
 *   Read: stid field is set by a tlbre 0 instruction
 *   Write: stid field is used by tlbwe 0 instruction
 */

typedef union
    {
    struct
	{
	UINT32	rsvd1:7;
	UINT32	swoa:1;		/* Store W/O Allocate */
	UINT32	rsvd2:1;
	UINT32	u1te:1;		/* U1 Transient Enable */
	UINT32	u2swoae:1;	/* U2 Store W/O Allocate Enable */
	UINT32	rsvd3:1;
	UINT32	dulxe:1;	/* Data Cache Unlock Exc Enable */
	UINT32	iulxe:1;	/* Instr Cache Unlock Exc Enable */
	UINT32	rsvd4:1;
	UINT32	sts:1;		/* Search Translation Space */
	UINT32	rsvd5:8;
	UINT32	stid:8;		/* Search Translation ID */
	} field;

    UINT32 word;

    } MMUCR_REG;

/* externals */

IMPORT void	mmuPpcPidSet (UINT8 pid);
IMPORT UINT32	mmuPpcPidGet (void);
IMPORT void	mmuPpcMmucrSet (UINT32 pid);
IMPORT UINT32	mmuPpcMmucrGet (void);
IMPORT UINT32 	mmuPpcTlbReadEntryWord0 (UINT32 index);
IMPORT UINT32	mmuPpcTlbReadEntryWord1 (UINT32 index);
IMPORT UINT32	mmuPpcTlbReadEntryWord2 (UINT32 index);
IMPORT int	mmuPpcTlbSearch (void * effAddr);
IMPORT void 	mmuPpcTlbWriteEntryWord0 (UINT32 index, UINT32 word0);
IMPORT void 	mmuPpcTlbWriteEntryWord1 (UINT32 index, UINT32 word1);
IMPORT void 	mmuPpcTlbWriteEntryWord2 (UINT32 index, UINT32 word2);

IMPORT void	mmuPpcAEnable ();
IMPORT void	mmuPpcADisable ();

IMPORT void	mmuPpcInstTlbMissHandler();
IMPORT void	mmuPpcDataTlbMissHandler();

IMPORT STATE_TRANS_TUPLE *	mmuStateTransArray;
IMPORT int			mmuStateTransArraySize;
IMPORT MMU_LIB_FUNCS		mmuLibFuncs;
IMPORT int			mmuPageBlockSize;

IMPORT BOOL	cache440ToEnable;
STATUS		cache440Enable (CACHE_TYPE cache);
IMPORT STATUS	cacheArchFlush(CACHE_TYPE cache, void *address, size_t bytes);

IMPORT UINT32	mmuPpcSelected;		/* mmu type selected */

/* globals */

/*
 * a translation table to hold the descriptors for the global transparent
 * translation of physical to virtual memory
 */

MMU_TRANS_TBL * mmuGlobalTransTbl;	/* global translation table */	

/*
 * An array of 256 translation table pointers is allocated to store up to 255
 * (entry 0 unused) unique address maps.  This array is indexed by the PID
 * value. A value of -1 denotes an unused entry.
 */
MMU_TRANS_TBL *	mmuAddrMapArray [MMU_ADDR_MAP_ARRAY_SIZE];

/*
 * TLB replacement counter: mmuPpcTlbNext is used by the page fill exception
 * handler.  We use a round-robin strategy to determine which TLB entry to
 * replace.  mmuPpcTlbMin provides a minimum value, so that assigned Tlbs are
 * selected from mmuPpcTlbMin up to mmuPpcTlbMax.
 */
UINT32	mmuPpcTlbNext;
UINT32	mmuPpcTlbMin;
UINT32	mmuPpcTlbMax;

#ifdef DEBUG_MISS_HANDLER
UINT32	mmuPpcITlbMisses;
UINT32	mmuPpcITlbMissArray[256];
UINT32	mmuPpcDTlbMisses;
UINT32	mmuPpcDTlbMissArray[256];
UINT32	mmuPpcITlbErrors;
UINT32	mmuPpcDTlbErrors;
#endif /* DEBUG_MISS_HANDLER */

/*
 * pointer to array of static TLB entries, used mostly in conjunction
 * with the cache library to enable/disable caching
 */

TLB_ENTRY_DESC *mmu440StaticTlbArray;

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


/* forward declarations */

LOCAL MMU_TRANS_TBL *	mmu440TransTblCreate ();
LOCAL STATUS		mmu440TransTblDelete (MMU_TRANS_TBL *transTbl);
LOCAL STATUS		mmu440Enable (BOOL enable);
LOCAL STATUS		mmu440StateSet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				     UINT stateMask, UINT state);
LOCAL STATUS		mmu440StateGet (MMU_TRANS_TBL *transTbl, void *pageAddr,
				     UINT *state);
LOCAL STATUS		mmu440PageMap (MMU_TRANS_TBL *transTbl,
				     void * virtualAddress, void *physPage);
LOCAL STATUS		mmu440GlobalPageMap (void * virtualAddress,
				    void * physPage);
LOCAL STATUS		mmu440Translate (MMU_TRANS_TBL * transTbl,
				      void * virtAddress, void ** physAddress);
LOCAL void		mmu440CurrentSet (MMU_TRANS_TBL * transTbl);
LOCAL STATUS		mmu440TransTblInit (MMU_TRANS_TBL * pNewTransTbl);
LOCAL LEVEL_1_DESC *	mmu440Lvl1DescAddrGet (MMU_TRANS_TBL *	pTransTbl,
				    void * effectiveAddr);
LOCAL STATUS		mmu440Lvl2DescAddrGet (MMU_TRANS_TBL * pTransTbl,
				void * effectiveAddr,
				LEVEL_2_DESC ** ppLvl2Desc);
LOCAL void		mmu440Lvl1DescUpdate (LEVEL_1_DESC * pLvl1Desc,
				LEVEL_1_DESC lvl1Desc);
LOCAL STATUS		mmu440Lvl1DescInit (MMU_TRANS_TBL * pTransTbl,
				LEVEL_1_DESC * pLvl1Desc, void * effectiveAddr);
LOCAL void		mmu440Lvl2DescUpdate (LEVEL_2_DESC * pLvl2Desc,
				LEVEL_2_DESC lvl2Desc);
LOCAL BOOL		mmu440IsOn (int mmuType);
LOCAL UINT8 		mmu440PidAlloc (MMU_TRANS_TBL *transTbl);
LOCAL void 		mmu440PidFree (UINT8 pid);
LOCAL void 		mmu440Tlbie (MMU_TRANS_TBL *pTransTbl, void * effAddr);
LOCAL void		mmu440TlbDynamicInvalidate (void);
LOCAL void		mmu440TlbStaticInit (int numDescs, TLB_ENTRY_DESC *
				pTlbDesc, BOOL cacheAllow);

/* locals (need forward declarations) */

LOCAL MMU_LIB_FUNCS mmuLibFuncsLocal =
    {
    mmu440LibInit,
    mmu440TransTblCreate,
    mmu440TransTblDelete,
    mmu440Enable,
    mmu440StateSet,
    mmu440StateGet,
    mmu440PageMap,
    mmu440GlobalPageMap,
    mmu440Translate,
    mmu440CurrentSet
    };


/******************************************************************************
*
* mmu440LibInit - MMU library initialization
*
* This routine initializes data structures used to store mmu page tables
* so that subsequent page mapping operations can be performed, and so that
* the TLB miss handler exceptions can consult the data structures with
* meaningful results.
*
* The staticTlbNum argument specifies how many static TLB entries are
* defined in the pStaticTlbDesc array.  TLB indices lower than
* staticTlbNum are used for static page mapping.  staticTlbNum also
* specifies the lowest TLB index that the mmu440Lib is allowed to use
* for dynamic page mapping.
*
* RETURNS: OK, or ERROR if <mmuType> is incorrect or memory allocation
*	failed.
*/

STATUS mmu440LibInit
    (
    int 	mmuType,		/* data and/or instr. MMU to init */
    int		staticTlbNum,		/* number of static TLB Entries */
    TLB_ENTRY_DESC * pStaticTlbDesc	/* array of static TLB descriptions */
    )
    {
    /* save the Data and/or Instruction MMU selected */

    mmuPpcSelected = mmuType;

    /* set up the static TLB entries with caching off */

    mmu440TlbStaticInit(staticTlbNum, pStaticTlbDesc, FALSE);

    /* initialize the TLB replacement counter to the minimum tlb index */

    mmuPpcTlbMin = staticTlbNum;
    mmuPpcTlbMax = N_TLB_ENTRIES;
    mmuPpcTlbNext = mmuPpcTlbMin;
    mmu440StaticTlbArray = pStaticTlbDesc;

    /* initialize the exception table:
     * 	At the exception offset, we put a branch instruction (0x48000002)
     *  OR'ed with the address of the TLB miss handler.
     */

    if (mmuType & MMU_INST)
	{
	if ((UINT32)mmuPpcInstTlbMissHandler > 0x03fffffc)
	    {
	    strcpy(sysExcMsg, "440 MMU config failed: TLB miss handler "
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
	    strcpy(sysExcMsg, "440 MMU config failed: TLB miss handler "
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


    /* create the global translation table */

    mmuGlobalTransTbl = mmu440TransTblCreate();

    if (mmuGlobalTransTbl == NULL)
	{
	strcpy(sysExcMsg, "440 MMU config failed: could not allocate "
	    "global trans table\n");
	return (ERROR);
	}

    /* initialize the PID register (it won't be accessed until MSR[IS,DS]
     * gets set later) and invalidate all dynamic TLB entries
     */

    mmuPpcPidSet (mmuGlobalTransTbl->pid);
    mmu440TlbDynamicInvalidate();

    /* initialize the data objects that are shared with vmLib.c */

    mmuStateTransArray = &mmuStateTransArrayLocal [0];

    mmuStateTransArraySize =
		sizeof (mmuStateTransArrayLocal) / sizeof (STATE_TRANS_TUPLE);

    mmuLibFuncs = mmuLibFuncsLocal;

    mmuPageBlockSize = MMU_PAGE_SIZE;

    /* if caching turnon was delayed until mmu inited, do it now */

    if (cache440ToEnable == TRUE)
	{
	cache440Enable(0);
	cache440ToEnable = FALSE;
	}


    return (OK);

    }

#if FALSE
/******************************************************************************
*
* mmu440MemPagesWriteEnable - write enable the memory holding PTEs
*
* Each translation table has a linked list of physical pages that contain its
* table and page descriptors.  Before you can write into any descriptor, you
* must write enable the page it is contained in.  This routine enables all the
* pages used by a given translation table.
*
*/

LOCAL STATUS mmu440MemPagesWriteEnable
    (
    MMU_TRANS_TBL * pTransTbl		/* Translation table to enable */
    )
    {
    int		 ix;			/* index of L1 entries */
    int		 jx;			/* index into L2 table pages */
    LEVEL_1_DESC lvl1Desc;		/* current L1 descriptor */

    /* we need to enable writes on the level 1 page table and each level 2
     * page table. The level 1 page table is MMU_PAGE_SIZE in size, whereas
     * the level 2 page table is 4 * MMU_PAGE_SIZE in size.
     */

    /* write enable the level 1 page table */
    mmu440StateSet (pTransTbl, (void *)pTransTbl->l1TblPtr.pL1Desc,
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE);

    /* go thru the L 1 table and write enable each L 2 table */
    for (ix = 0 ; ix < MMU_LVL_2_DESC_NB; ix++)
	{
	lvl1Desc = * (pTransTbl->l1TblPtr.pL1Desc + ix);

	if (lvl1Desc.field.v)
	    {
	    for (jx = 0; jx < 4; jx++)
		{
		mmu440StateSet (pTransTbl,
		    (void *)(lvl1Desc.field.l2ba << 2) + (jx * MMU_PAGE_SIZE),
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE);
		}
	    }
	}

    return (OK);
    }
#endif /* FALSE */

/******************************************************************************
*
* mmu440MemPagesWriteDisable - write disable memory holding PTEs
*
* Memory containing translation table descriptors is marked as read only
* to protect the descriptors from being corrupted.  This routine write protects
* all the memory used to contain a given translation table's descriptors.
*
* RETURNS: N/A
*/

LOCAL void mmu440MemPagesWriteDisable
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
    mmu440StateSet (pTransTbl, (void *)pTransTbl->l1TblPtr.pL1Desc,
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT);

    /* go thru the L 1 table and write protect each L 2 table */
    for (ix = 0 ; ix < MMU_LVL_2_DESC_NB; ix++)
	{
	lvl1Desc = * (pTransTbl->l1TblPtr.pL1Desc + ix);

	if (lvl1Desc.field.v)
	    {
	    for (jx = 0; jx < 4; jx++)
		{
		mmu440StateSet (pTransTbl,
		    (void *)(lvl1Desc.field.l2ba << 2) + (jx * MMU_PAGE_SIZE),
		    MMU_STATE_MASK_WRITABLE, MMU_STATE_WRITABLE_NOT);
		}
	    }
	}
    }

/******************************************************************************
*
* mmu440TransTblCreate - create a new translation table.
*
* RETURNS: address of new object or NULL if allocation failed.
*/

LOCAL MMU_TRANS_TBL * mmu440TransTblCreate (void)
    {
    MMU_TRANS_TBL *	pNewTransTbl;		/* new translation table */

    /* allocate a piece of memory to save the new translation table */

    pNewTransTbl = (MMU_TRANS_TBL *) malloc (sizeof (MMU_TRANS_TBL));

    /* if the memory can not allocated then return the NULL pointer */

    if (pNewTransTbl == NULL)
	return (NULL);

    /* get a free PID for the new translation table */

    pNewTransTbl->pid = mmu440PidAlloc (pNewTransTbl);

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

    if (mmu440TransTblInit (pNewTransTbl) == ERROR)
	{
	free ((char *) pNewTransTbl);
	return (NULL);
	}

    /* return the new translation table created */

    return (pNewTransTbl);
    }

/******************************************************************************
*
* mmu440TransTblInit - initialize a new translation table
*
* Initialize a new translation table.  The level 1 table is copied from the
* global translation mmuGlobalTransTbl, so that we will share the global
* virtual memory with all other translation tables.
*
* RETURNS: OK, or ERROR if unable to allocate memory.
*/

LOCAL STATUS mmu440TransTblInit
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
* mmu440TransTblDelete - delete a translation table.
*
* This routine deletes a translation table.
*
* RETURNS: OK always.
*/

LOCAL STATUS mmu440TransTblDelete
    (
    MMU_TRANS_TBL * pTransTbl		/* translation table to be deleted */
    )
    {
    LEVEL_1_DESC 	lvl1Desc;	/* level 1 descriptor */
    UINT32		ix;

    /* free the PID element for this translation table */

    mmu440PidFree (pTransTbl->pid);

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
* mmu440Enable - turn mmu on or off
*
* On the PPC440, the MMU is always on, so turning it off is a misnomer.
* Instead, this function changes the MSR[IS,DS] values, which change which TLB
* entries match -- either the static ones that emulate 'real mode', or the ones
* that provide dynamic mmu page mapping.
*
* RETURNS: OK
*/

LOCAL STATUS mmu440Enable
    (
    BOOL enable			/* TRUE to enable, FALSE to disable MMU */
    )
    {
    int lockKey;		/* lock key for intUnlock() */

    if (mmuPpcSelected == 0)
	return (OK);

    /* lock the interrupt */

    lockKey = intLock ();

    if (enable)
	{
	if (mmuPpcSelected & MMU_INST)
	    mmuPpcAEnable (MMU_I_ADDR_TRANS);	/* enable instruction MMU */

	if (mmuPpcSelected & MMU_DATA)
	    mmuPpcAEnable (MMU_D_ADDR_TRANS);	/* enable data MMU */
	}
    else
	{
	if (mmuPpcSelected & MMU_INST)
	    mmuPpcADisable (MMU_I_ADDR_TRANS);	/* disable instruction MMU */

	if (mmuPpcSelected & MMU_DATA)
	    mmuPpcADisable (MMU_D_ADDR_TRANS);	/* disable data MMU */
	}

    /* AE would unmap EA 0x0 - 0x2fff here, but only for user mode tasks */

    intUnlock (lockKey);			/* unlock the interrupt */

    return (OK);
    }

/******************************************************************************
*
* mmu440StateSet - set state of virtual memory page
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

LOCAL STATUS mmu440StateSet
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

    if (mmu440Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
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
     * set or reset the WIMG bits as requested. WIMG and write/execute bits
     * are in the same bit positions in MMU_STATE as in TLB Word 2, so we
     * can use bitwise arithmetic
     */

    lvl2Desc.words.word2 &= ~(stateMask & MMU_STATE_MASK_WIMG_WRITABLE_EXECUTE);
    lvl2Desc.words.word2 |= (state & stateMask &
			     MMU_STATE_MASK_WIMG_WRITABLE_EXECUTE);

    /* flush out any copyback data before we change the attribute mapping */

    if (flush == TRUE)
	cacheArchFlush(DATA_CACHE, effectiveAddr, MMU_PAGE_SIZE);

    /* update the Level 2 Descriptor */

    mmu440Lvl2DescUpdate (pLvl2Desc, lvl2Desc);

    /* invalidate the tlb entry for this effective address */

    mmu440Tlbie (pTransTbl, effectiveAddr);

    return (OK);
    }

/******************************************************************************
*
* mmu440StateGet - get state of virtual memory page
*
*/

LOCAL STATUS mmu440StateGet
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

    if (mmu440Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	{
	errno = S_mmuLib_NO_DESCRIPTOR;
	return (ERROR);
	}

    /* make a working copy the Level 2 Descriptor */

    lvl2Desc = *pLvl2Desc;

    /* extract the state of the VALID, WIMG and EX, WR bits.
     * Note that the valid bit is in a different bit position in L2 desc
     * than in the MMU_STATE_VALID.
     */

    * state = (lvl2Desc.field.v ? MMU_STATE_VALID : 0);
    * state |= lvl2Desc.words.word2 & MMU_STATE_MASK_WIMG_WRITABLE_EXECUTE;

    return (OK);
    }

/******************************************************************************
*
* mmu440PageMap - map physical memory page to virtual memory page
*
* The physical page address is entered into the level 2 descriptor
* corresponding to the given virtual page.  The state of a newly mapped page
* is undefined.
*
* RETURNS: OK, or ERROR if translation table creation failed.
*/

LOCAL STATUS mmu440PageMap
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

    pLvl1Desc = mmu440Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    /* get the level 1 descriptor */

    lvl1Desc.l1desc = pLvl1Desc->l1desc;

    if (!lvl1Desc.field.v)
	{
	if (mmu440Lvl1DescInit(pTransTbl, pLvl1Desc, effectiveAddr) == ERROR)
	    return (ERROR);
	}

    /*
     * Get the level 2 descriptor address. If the level 2 descriptor doesn't
     * exist then return ERROR.
     */

    if (mmu440Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) == ERROR)
	return (ERROR);

    /* get the level 2 descriptor */

    lvl2Desc = *pLvl2Desc;

    /* save the real address & effective addr in the level 2 descriptors */

    lvl2Desc.field.rpn = (UINT32) physicalAddr >> MMU_RPN_SHIFT;
    lvl2Desc.field.epn = (UINT32) effectiveAddr >> MMU_RPN_SHIFT;

    /* set the valid bit in the level 2 descriptor */
    lvl2Desc.field.v = 1;

    /* update the Level 2 descriptor in table */

    mmu440Lvl2DescUpdate (pLvl2Desc, lvl2Desc);

    /* invalidate the tlb entry for this effective addr */
    mmu440Tlbie (pTransTbl, effectiveAddr);

    return (OK);
    }

/******************************************************************************
*
* mmu440GlobalPageMap - map physical memory page to global virtual memory page
*
* mmuPpcGlobalPageMap is used to map physical pages into global virtual memory
* that is shared by all virtual memory contexts.  The translation tables
* for this section of the virtual space are shared by all virtual memory
* contexts.
*
* RETURNS: OK, or ERROR if no pte for given virtual page.
*/

LOCAL STATUS mmu440GlobalPageMap
    (
    void *  effectiveAddr, 	/* effective address */
    void *  physicalAddr	/* physical address */
    )
    {
    return (mmu440PageMap (mmuGlobalTransTbl, effectiveAddr, physicalAddr));
    }

/******************************************************************************
*
* mmu440Translate - translate a virtual address to a physical address
*
* Traverse the translation table and extract the physical address for the
* given virtual address from the level 2 descriptor corresponding to the
* virtual address.
*
* RETURNS: OK, or ERROR if no level 2 descriptor found for given virtual address.
*/

LOCAL STATUS mmu440Translate
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

    if (mmu440Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) != OK)
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
* mmu440CurrentSet - change active translation table
*
* This function changes the virtual memory context by loading the PID
* register with the PID value saved in the translation
* table structure pointed to by <pTransTbl>.
*
* RETURNS: N/A
*
*/

LOCAL void mmu440CurrentSet
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
	 mmu440MemPagesWriteDisable (mmuGlobalTransTbl);
	 mmu440MemPagesWriteDisable (pTransTbl);

	 firstTime = FALSE;
	 }

    lockKey = intLock ();

    /*
     * save the PID value in the PID register via
     * mmuPpcPidSet(). If one or both MMUs are turned on then disable
     * the MMU, set the PID register and re-enable the MMU.
     */

    if (mmu440IsOn (MMU_INST)  || mmu440IsOn (MMU_DATA))
	{
	mmu440Enable (FALSE);			/* disable the MMU */
    	mmuPpcPidSet (pTransTbl->pid);
	mmu440Enable (TRUE);			/* re-enable  the MMU */
	}
    else
    	mmuPpcPidSet (pTransTbl->pid);

    intUnlock (lockKey);
    }

/*******************************************************************************
*
* mmu440Lvl2DescAddrGet - get the address of a level 2 Desciptor
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

LOCAL STATUS mmu440Lvl2DescAddrGet
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

    pLvl1Desc = mmu440Lvl1DescAddrGet (pTransTbl, effectiveAddr);

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
* mmu440Lvl1DescAddrGet - get the address of a level 1 descriptor
*
* This function returns the address of the level 1 descriptor corresponding
* to the effective address pointed to by <effectiveAddr>.
*
* RETRUNS: always the address of the level 1 descriptor
*
*/

LOCAL LEVEL_1_DESC * mmu440Lvl1DescAddrGet
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
* mmu440Lvl1DescUpdate - update a level 1 descriptor
*
* This function updates a level 1 descriptor. The address of the level 1
* descriptor is handled by <pLvl1Desc> and the new value of the level 1
* descriptor by <lvl1Desc>.
*
* RETURNS: N/A
*/

LOCAL void mmu440Lvl1DescUpdate
    (
    LEVEL_1_DESC *	pLvl1Desc,	/* Level 1 descriptor address */
    LEVEL_1_DESC	lvl1Desc	/* Level 1 descriptor */
    )
    {
    UINT32	key;

    if (mmu440IsOn (MMU_INST)  || mmu440IsOn (MMU_DATA))
	{
	/* circumvent page protection by turning MMU off to write entry */

	key = intLock();			/* lock interrupt */
	mmu440Enable (FALSE);                   /* disable the mmu */
	pLvl1Desc->l1desc = lvl1Desc.l1desc;	/* update the descriptor */
	mmu440Enable (TRUE);			/* enable the MMU */
	intUnlock(key);				/* re-enable interrupt */
	}
    else
	pLvl1Desc->l1desc = lvl1Desc.l1desc;	/* update the descriptor */
    }

/***********************************************************************
*
* mmu440Lvl1DescInit -- initialize a level 1 descriptor
*
* Create the level 2 descriptor table, fill it in with appropriate
* defaults, and set up the level 1 descriptor to point at it.
*/

LOCAL STATUS mmu440Lvl1DescInit
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

    lvl2Desc.field.epn = 0;		/* effective page number */
    lvl2Desc.field.rsvd1 = 0;
    lvl2Desc.field.v = 0;		/* initially invalid */
    lvl2Desc.field.ts = 1;		/* translation space 1 */
    lvl2Desc.field.size = 1;		/* default 4KB page */
    lvl2Desc.field.rsvd2 = 0;

    lvl2Desc.field.rpn = 0;		/* real page number */
    lvl2Desc.field.rsvd3 = 0;	
    lvl2Desc.field.erpn = 0;		/* extended real page number */

    lvl2Desc.field.rsvd4 = 0;	
    lvl2Desc.field.u0 = 0;		/* user attribute 0 unused */
    lvl2Desc.field.u1 = 0;		/* user attribute 1 unused */
    lvl2Desc.field.u2 = 0;		/* user attribute 2 unused */
    lvl2Desc.field.u3 = 0;		/* user attribute 3 unused */
    lvl2Desc.field.w = 0;		/* no write thru */
    lvl2Desc.field.i = 0;		/* no cache inhibit */
    lvl2Desc.field.m = 0;		/* memory coherent: no effect */
    lvl2Desc.field.g = 0;		/* memory unguarded */
    lvl2Desc.field.e = 0;		/* big endian */
    lvl2Desc.field.rsvd5 = 0;	
    lvl2Desc.field.ux = 0;		/* user execute off */
    lvl2Desc.field.uw = 0;		/* user write off */
    lvl2Desc.field.ur = 0;		/* user read off */
    lvl2Desc.field.sx = 1;		/* supervisor execute on */
    lvl2Desc.field.sw = 0;		/* supervisor write off */
    lvl2Desc.field.sr = 1;		/* supervisor read on */

    lvl2Desc.field.rsvd6 = 0;		

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

    mmu440Lvl1DescUpdate (pLvl1Desc, lvl1Desc);

    return (OK);
    }

/*******************************************************************************
*
* mmu440Lvl2DescUpdate - update a level 2 descriptor
*
* This function updates a level 2 descriptor. The addess of the level 2
* descriptor is handled by <pLvl2Desc> and the new value of the level 2
* descriptor by <lvl2Desc>.
*
* RETURNS: N/A
*/

LOCAL void mmu440Lvl2DescUpdate
    (
    LEVEL_2_DESC *	pLvl2Desc,	/* Level 2 descriptor address */
    LEVEL_2_DESC	lvl2Desc	/* Level 2 descriptor */
    )
    {
    UINT32	key;

    if (mmu440IsOn (MMU_INST)  || mmu440IsOn (MMU_DATA))
	{
	/* circumvent page protection by turning MMU off to write entry */

	key = intLock();			/* lock interrupt */
	mmu440Enable (FALSE);                   /* disable the mmu */
	*pLvl2Desc = lvl2Desc;			/* update the descriptor */
	mmu440Enable (TRUE);			/* enable the MMU */
	intUnlock(key);				/* re-enable interrupt */
	}
    else
	*pLvl2Desc = lvl2Desc;			/* update the descriptor */
    }

/*******************************************************************************
*
* mmu440IsOn - return the state of the MMU
*
* This function returns TRUE if the MMU selected by <mmuType> is set to
* translation space 1.
*
* RETURNS: TRUE or FALSE
*
*/

LOCAL BOOL mmu440IsOn
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
* mmu440PidAlloc - get a free PID for use with a new address map from
*		mmuAddrMapArray, and set the address map element
*		to point to MMU_TRANS_TBL pointer.
*
* NOTE: For MMU library internal use only
*
* RETURNS: index of free array element, or -1 for ERROR.
*/
LOCAL UINT8 mmu440PidAlloc (MMU_TRANS_TBL *transTbl)
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
* mmu440PidFree - Free (mark as invalid) the pid entry
*
* NOTE: For MMU library internal use only
*
*/
LOCAL void mmu440PidFree (UINT8 pid)
    {
    mmuAddrMapArray [pid] = MMU_ADDR_MAP_ARRAY_INV;
    }

/*******************************************************************************
*
* mmu440TlbDynamicInvalidate - invalidate all dynamic tlb entries
*
* Requires a subsequent context-synchronizing event in order to take effect.
*
* NOTE: For MMU library internal use only.
*/
LOCAL void mmu440TlbDynamicInvalidate (void)
    {
    UINT32 index;
    UINT32 word0;

    for (index = mmuPpcTlbMin; index < mmuPpcTlbMax; index++)
	{
	/* read current entry -- also sets MMUCR[STID] as a side effect */
	word0 = mmuPpcTlbReadEntryWord0 (index);

	/* clear valid bit */
	word0 &= ~(MMU_STATE_VALID << MMU_STATE_VALID_SHIFT);

	/* write back entry -- uses MMUCR[STID] as a side effect */
	_WRS_ASM("sync");
	mmuPpcTlbWriteEntryWord0 (index, word0);
	}	
    }

/*******************************************************************************
*
* mmu440MmucrStidSet - set the STID & STS fields of MMUCR
*
* NOTE: For MMU library internal use only.
*
*/

LOCAL void mmu440MmucrStidSet
    (
    UINT32	stid			/* new stid value */
    )
    {
    MMUCR_REG mmucr;

    /* set TID, TS */
    mmucr.word = mmuPpcMmucrGet();
    mmucr.field.stid = stid;
    mmucr.field.sts = 1;
    mmuPpcMmucrSet(mmucr.word);
    }

/*******************************************************************************
*
* mmu440Tlbie - Invalidate tlb entry for the specified effective addr
*
* NOTE: For MMU library internal use only.
*
*/
LOCAL void mmu440Tlbie (
    MMU_TRANS_TBL *	pTransTbl,	/* translation table */
    void * effAddr			/* EA to invalidate in tlb */
    )
    {
    UINT32 index;
    UINT32 word0;

    mmu440MmucrStidSet(pTransTbl->pid);

    if ((index = mmuPpcTlbSearch (effAddr)) != -1)
	{
	/* read current entry -- also sets MMUCR[STID] as a side effect */
	word0 = mmuPpcTlbReadEntryWord0 (index);

	/* clear valid bit */
	word0 &= ~(MMU_STATE_VALID << MMU_STATE_VALID_SHIFT);

	if (index < mmuPpcTlbMin)
	    {
	    /* assertion fails! must not invalidate static entries */

#if FALSE	/* useful for debugging */
	    strcpy(sysExcMsg, "mmu440Tlbie: static TLB entry invalidated\n");
	    sysToMonitor(BOOT_WARM_NO_AUTOBOOT);
#endif /* FALSE */

	    return; /* ERROR! */
	    }

	/* write back entry -- uses MMUCR[STID] as a side effect */
	_WRS_ASM("sync");
	mmuPpcTlbWriteEntryWord0 (index, word0);
	}	
    }

/*******************************************************************************
*
* mmu440TlbStaticEntrySet - write a static TLB entry
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

LOCAL void mmu440TlbStaticEntrySet
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
    lvl2Desc.field.ts = ((pTlbDesc->attr & _MMU_TLB_TS_1) ? 1 : 0);
    lvl2Desc.field.size =
	((pTlbDesc->attr & _MMU_TLB_SZ_MASK) >> _MMU_TLB_SZ_SHIFT);
    lvl2Desc.field.rsvd2 = 0;

    lvl2Desc.field.rpn = pTlbDesc->realAddr >> MMU_RPN_SHIFT;
    lvl2Desc.field.rsvd3 = 0;	
    lvl2Desc.field.erpn = pTlbDesc->realAddrExt;

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

    lvl2Desc.field.m = 0;		/* memory coherent: no effect */
    lvl2Desc.field.g = (pTlbDesc->attr & _MMU_TLB_ATTR_G ? 1 : 0);
    lvl2Desc.field.e = 0;		/* big endian */
    lvl2Desc.field.rsvd5 = 0;	
    lvl2Desc.field.ux = 0;		/* user execute off */
    lvl2Desc.field.uw = 0;		/* user write off */
    lvl2Desc.field.ur = 0;		/* user read off */
    lvl2Desc.field.sx = (pTlbDesc->attr & _MMU_TLB_PERM_X ? 1 : 0);
    lvl2Desc.field.sw = (pTlbDesc->attr & _MMU_TLB_PERM_W ? 1 : 0);
    lvl2Desc.field.sr = 1;		/* supervisor read on */

    /*
     * static TLB entries are always written with TID 0 so they will
     * match for all settings of the PID register.
     */

    mmu440MmucrStidSet(0);

    /* write current entry -- uses MMUCR[STID] as a side effect */
    _WRS_ASM("sync");
    mmuPpcTlbWriteEntryWord0 (index, lvl2Desc.words.word0);
    mmuPpcTlbWriteEntryWord1 (index, lvl2Desc.words.word1);
    mmuPpcTlbWriteEntryWord2 (index, lvl2Desc.words.word2);
    }

#if FALSE /* unused */
/*******************************************************************************
*
* mmu440TlbStaticEntryGet - read a static TLB entry
*
* This function reads a MMU TLB Entry and composes a TLB Entry
* Description.
*
* NOTE: For MMU library internal use only.
*
*/

LOCAL void mmu440TlbStaticEntryGet
    (
    int		     index,	/* index of TLB Entry to get */
    TLB_ENTRY_DESC * pTlbDesc	/* pointer to TLB Entry Description to write */
    )
    {
    LEVEL_2_DESC	lvl2Desc;	/* TLB entry */

    /* read entry */
    lvl2Desc.words.word0 = mmuPpcTlbReadEntryWord0 (index);
    lvl2Desc.words.word1 = mmuPpcTlbReadEntryWord1 (index);
    lvl2Desc.words.word2 = mmuPpcTlbReadEntryWord2 (index);

    /* translate to a TLB_ENTRY_DESC */

    pTlbDesc->effAddr = lvl2Desc.field.epn << MMU_RPN_SHIFT;
    pTlbDesc->realAddr = lvl2Desc.field.rpn << MMU_RPN_SHIFT;
    pTlbDesc->realAddrExt = lvl2Desc.field.erpn;

    pTlbDesc->attr = 0;
    pTlbDesc->attr |= (lvl2Desc.field.ts ? _MMU_TLB_TS_1 : 0);
    pTlbDesc->attr |= lvl2Desc.field.size << _MMU_TLB_SZ_SHIFT;
    pTlbDesc->attr |= (lvl2Desc.field.w ? _MMU_TLB_ATTR_W : 0);
    pTlbDesc->attr |= (lvl2Desc.field.i ? _MMU_TLB_ATTR_I : 0);
    pTlbDesc->attr |= (lvl2Desc.field.g ? _MMU_TLB_ATTR_G : 0);
    pTlbDesc->attr |= (lvl2Desc.field.sx ? _MMU_TLB_PERM_X : 0);
    pTlbDesc->attr |= (lvl2Desc.field.sw ? _MMU_TLB_PERM_W : 0);
    }
#endif /* FALSE - unused */

/*******************************************************************************
*
* mmu440TlbStaticInit - initialize all static TLB entries
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
LOCAL void mmu440TlbStaticInit
    (
    int		     numDescs,	/* number of TLB Entry Descriptors */
    TLB_ENTRY_DESC * pTlbDesc,	/* pointer to array of TLB Entries */
    BOOL	     cacheAllow	/* if TRUE, caching will be enabled */
    )
    {
    UINT32		index;		/* current index being init'ed */

    for (index = 0; index < numDescs; index++, pTlbDesc++)
	mmu440TlbStaticEntrySet(index, pTlbDesc, cacheAllow);
    }

/*******************************************************************************
*
* mmu440Show - show the level 1 and 2 descriptor for and effective address
*
* NOTE: For MMU library debug only
*/

void mmu440Show
    (
    MMU_TRANS_TBL *	pTransTbl,		/* translation table */
    void *		effectiveAddr		/* effective address */
    )
    {
    LEVEL_1_DESC *	pLvl1Desc;	/* level 1 descriptor address */
    LEVEL_2_DESC *	pLvl2Desc;	/* level 2 descriptor address */

    if (pTransTbl == NULL)
	pTransTbl = mmuGlobalTransTbl;

    /* get the level 1 descriptor address */

    pLvl1Desc = mmu440Lvl1DescAddrGet (pTransTbl, effectiveAddr);

    printf ("Level 1:\n");
    printf ("l2ba      = 0x%x\n", pLvl1Desc->field.l2ba);
    printf ("v         = %d\n", pLvl1Desc->field.v);

    if (mmu440Lvl2DescAddrGet (pTransTbl, effectiveAddr, &pLvl2Desc) != OK)
	return ;

    printf ("\n\n");
    printf ("Level 2:\n");
    printf ("epn       = 0x%x\n", pLvl2Desc->field.epn);
    printf ("v         = %d\n", pLvl2Desc->field.v);
    printf ("ts        = %d\n", pLvl2Desc->field.ts);
    printf ("size      = 0x%x\n", pLvl2Desc->field.size);
    printf ("\n");
    printf ("rpn       = 0x%x\n", pLvl2Desc->field.rpn);
    printf ("erpn      = 0x%x\n", pLvl2Desc->field.erpn);
    printf ("\n");
    printf ("u0,1,2,3  = %d,%d,%d,%d\n", pLvl2Desc->field.u0,
	pLvl2Desc->field.u1, pLvl2Desc->field.u2, pLvl2Desc->field.u3);
    printf ("w,i,m,g,e = %d,%d,%d,%d,%d\n", pLvl2Desc->field.w,
	pLvl2Desc->field.i, pLvl2Desc->field.m, pLvl2Desc->field.g,
	pLvl2Desc->field.e);
    printf ("ux,uw,ur  = %d,%d,%d\n", pLvl2Desc->field.ux,
	pLvl2Desc->field.uw, pLvl2Desc->field.ur);
    printf ("sx,sw,sr  = %d,%d,%d\n", pLvl2Desc->field.sx,
	pLvl2Desc->field.sw, pLvl2Desc->field.sr);
    }

/******************************************************************************
*
* mmu440TlbShow - Show 440 TLB Entry contents
*
* RETURNS: nothing
*/
void mmu440TlbShow (void)
    {
    int	ix;
    UINT32 word0, word1, word2;

    for (ix=0; ix<64; ix++)
	{
	word0 = mmuPpcTlbReadEntryWord0 (ix);
	word1 = mmuPpcTlbReadEntryWord1 (ix);
	word2 = mmuPpcTlbReadEntryWord2 (ix);
	printf ("TLB entry %02d : %8x %8x %8x\n", ix, word0, word1, word2);
	}
    }

#ifdef DEBUG_MISS_HANDLER

/******************************************************************************
*
* mmu440MetricsShow - Show Miss Handler metrics for debugging
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
void mmu440MetricsShow
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
