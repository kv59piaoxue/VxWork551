/* vmArch36Lib.c - VM (VxVMI) library for PentiumPro/2/3/4 36 bit mode */

/* Copyright 2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,10oct02,hdn  updated the documentation. (spr 82229)
01a,12jun02,hdn  written
*/

/*
DESCRIPTION:
The 36 bit physical addressing mechanism of P6 (Pentium II and III) family
processors and P7 (Pentium4) family processors are supported by this library.
This library provides the virtual memory mapping and virtual address
translation that works with the unbundled VM library VxVMI.  The architecture
specific VM library APIs are linked in automatically when INCLUDE_MMU_FULL 
and INCLUDE_MMU_P6_36BIT are both defined in the BSP.  The provided APIs are 
vmArch36Map() and vmArch36Translate().

The 4KB-page and 2MB-page are supported.  The page size is configurable by 
VM_PAGE_SIZE macro in the BSP.  

The memory description table sysPhysMemDesc[] in sysLib.c has not changed
and only allows 32 bit virtual and physical address mapping description.
Thus the first 4GB 32 bit address space of the 36 bit physical address is used
at the initialization/boot time.  Then, the physical address beyond the 4GB 
can be mapped in somewhere outside of the system memory pool in the 32 bit
virtual address space with above APIs.

INCLUDE FILES: mmuPro36Lib.h

SEE ALSO: vmLib, Intel Architecture Software Developer's Manual

*/


/* includes */

#include "vxWorks.h"
#include "errno.h"
#include "mmuLib.h"
#include "private/vmLibP.h"
#include "arch/i86/mmuPro36Lib.h"


/* imports */

IMPORT UINT8 *		globalPageBlockArray;	/* vmLib.c */


/* defines */

#define NOT_PAGE_ALIGNED(addr)  (((UINT)(addr)) & ((UINT)pageSize - 1))
#define MMU_PAGE_MAP		(mmuPro36PageMap)
#define MMU_TRANSLATE		(mmuPro36Translate)


/****************************************************************************
*
* vmArch36LibInit - initialize the arch specific unbundled VM library (VxVMI Option)
*
* This routine links the arch specific unbundled VM library into 
* the VxWorks system.  It is called automatically when \%INCLUDE_MMU_FULL 
* and \%INCLUDE_MMU_P6_36BIT are both defined in the BSP.
*
* RETURNS: N/A
*/

void vmArch36LibInit (void)
    {
    } 

/*******************************************************************************
*
* vmArch36Map - map 36bit physical space into 32bit virtual space (VxVMI Option)
*
* vmArch36Map maps 36bit physical pages into a contiguous block of 32bit 
* virtual memory.  <virtAddr> and <physAddr> must be on page boundaries,
* and <len> must be evenly divisible by the page size.  After the mapping
* the specified state is set to all pages in the newly mapped virtual memory.
*
* The vmArch36Map() routine can fail if the specified virtual address space
* conflicts with the translation tables of the global virtual memory space.
* The global virtual address space is initialized at boot time.
* If a conflict results, `errno' is set to S_vmLib_ADDR_IN_GLOBAL_SPACE.
* To avoid this conflict, use vmGlobalInfoGet() to ascertain which portions
* of the virtual address space are reserved for the global virtual address
* space.  If <context> is specified as NULL, the current virtual memory
* context is used.
*
* This routine should not be called from interrupt level.
*
* AVAILABILITY
* This routine is distributed as a component of the unbundled virtual memory
* support option, VxVMI.
*
* RETURNS: OK, or ERROR if <virtAddr> or <physAddr> are not on page 
* boundaries, <len> is not a multiple of the page size, the validation fails,
* or the mapping fails.
*
* ERRNO:
* S_vmLib_NOT_PAGE_ALIGNED,
* S_vmLib_ADDR_IN_GLOBAL_SPACE
*/

STATUS vmArch36Map 
    (
    VM_CONTEXT_ID context, 	/* context - NULL == currentContext */
    void * virtAddr, 		/* 32bit virtual address */
    LL_INT physAddr,		/* 36bit physical address */
    UINT32 stateMask,		/* state mask */
    UINT32 state,		/* state */
    UINT32 len			/* len of virtual and physical spaces */
    )
    {
    INT32 pageSize      = vmPageSizeGet ();
    INT32 pageBlockSize = vmPageBlockSizeGet ();
    INT8 * thisVirtPage = (INT8 *) virtAddr;
    LL_INT thisPhysPage = physAddr;
    FAST UINT32 numBytesProcessed = 0;
    STATUS retVal = OK;

    if (!vmLibInfo.vmLibInstalled)
	return (ERROR);

    if (context == NULL)
	context = vmCurrentGet ();

    if ((NOT_PAGE_ALIGNED (thisVirtPage)) ||
        (NOT_PAGE_ALIGNED (thisPhysPage)) ||
        (NOT_PAGE_ALIGNED (len)))
	{
	errno = S_vmLib_NOT_PAGE_ALIGNED;
        return (ERROR); 
	}

    /* take mutual exclusion semaphore to protect translation table */

    semTake (&context->sem, WAIT_FOREVER);

    while (numBytesProcessed < len)
	{
	/* make sure there isn't a conflict with global virtual memory */

	if (globalPageBlockArray[(UINT32) thisVirtPage / pageBlockSize])
	    {
	    errno = S_vmLib_ADDR_IN_GLOBAL_SPACE;
	    retVal = ERROR;
	    break;
	    }

	if (MMU_PAGE_MAP (context->mmuTransTbl, thisVirtPage, 
			  thisPhysPage) == ERROR)
	    {
	    retVal = ERROR;
	    break;
	    }

        if (vmStateSet (context, thisVirtPage, pageSize,
			stateMask, state) != OK)
	    {
	    retVal = ERROR;
	    break;
	    }

	thisVirtPage += pageSize;
	thisPhysPage += pageSize;
	numBytesProcessed += pageSize;
	}

    semGive (&context->sem);

    return (retVal);
    }

/*******************************************************************************
*
* vmArch36Translate - translate a 32bit virtual address to a 36bit physical address (VxVMI Option)
*
* vmArch36Translate retrieves mapping information for a 32bit virtual address 
* from the page translation tables.  If the specified virtual address has 
* never been mapped, the returned status is ERROR.  If <context> is specified 
* as NULL, the current context is used.
*
* This routine is callable from interrupt level.
*
* AVAILABILITY
* This routine is distributed as a component of the unbundled virtual memory
* support option, VxVMI.
*
* RETURNS: OK, or ERROR if the validation or translation fails.
*/

STATUS vmArch36Translate 
    (
    VM_CONTEXT_ID context, 	/* context - NULL == currentContext */
    void * virtAddr, 		/* 32bit virtual address */
    LL_INT * physAddr		/* place to put 36bit result */
    )
    {
    STATUS retVal;

    if (!vmLibInfo.vmLibInstalled)
	return (ERROR);

    if (context == NULL)
	context = vmCurrentGet ();

    retVal = MMU_TRANSLATE (context->mmuTransTbl, virtAddr, physAddr);

    return (retVal);
    }

