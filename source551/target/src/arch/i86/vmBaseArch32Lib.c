/* vmBaseArch32Lib.c - VM (bundled) library for PentiumPro/2/3/4 32 bit mode */

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
This library provides the virtual memory mapping and virtual address
translation that works with the bundled VM library.  The architecture
specific VM library APIs are linked in automatically when INCLUDE_MMU_BASIC 
and INCLUDE_MMU_P6_32BIT are both defined in the BSP.  The provided APIs are 
vmBaseArch32Map() and vmBaseArch32Translate().

The 4KB-page and 4MB-page are supported.  The page size is configurable by 
VM_PAGE_SIZE macro in the BSP.  

INCLUDE FILES: mmuPro32Lib.h

SEE ALSO: vmLib, Intel Architecture Software Developer's Manual

*/


/* includes */

#include "vxWorks.h"
#include "errno.h"
#include "mmuLib.h"
#include "private/vmLibP.h"
#include "arch/i86/mmuPro32Lib.h"


/* imports */

IMPORT VM_CONTEXT *	currentContext;		/* vmBaseLib.c */
IMPORT MMU_LIB_FUNCS	mmuLibFuncs;		/* mmuLib.c */


/* defines */

#define NOT_PAGE_ALIGNED(addr)	(((UINT)(addr)) & ((UINT)pageSize - 1))
#define MMU_PAGE_MAP		(*(mmuLibFuncs.mmuPageMap))
#define MMU_TRANSLATE		(*(mmuLibFuncs.mmuTranslate))


/****************************************************************************
*
* vmBaseArch32LibInit - initialize the arch specific bundled VM library
*
* This routine links the arch specific bundled VM library into the VxWorks 
* system.  It is called automatically when \%INCLUDE_MMU_BASIC and 
* \%INCLUDE_MMU_P6_32BIT are both defined in the BSP.
*
* RETURNS: N/A
*/

void vmBaseArch32LibInit (void)
    {
    } 

/****************************************************************************
*
* vmBaseArch32Map - map 32bit physical to the 32bit virtual memory
*
* vmBaseArch32Map maps 32bit physical pages into a contiguous block of 32bit
* virtual memory.  <virtAddr> and <physAddr> must be on page boundaries,
* and <len> must be evenly divisible by the page size.  After the mapping
* the specified state is set to all pages in the newly mapped virtual memory.
* 
* This routine should not be called from interrupt level.
* 
* RETURNS: OK, or ERROR if <virtAddr> or <physAddr> are not on page
* boundaries, <len> is not a multiple of the page size, the validation fails,
* or the mapping fails.
* 
* ERRNO:
* S_vmLib_NOT_PAGE_ALIGNED
* 
*/

STATUS vmBaseArch32Map 
    (
    void * virtAddr, 		/* 32bit virtual address */
    void * physAddr, 		/* 32bit physical address */
    UINT32 stateMask,		/* state mask */
    UINT32 state,		/* state */
    UINT32 len			/* length */
    )
    {
    INT32 pageSize      = vmBasePageSizeGet ();
    INT8 * thisVirtPage = (INT8 *) virtAddr;
    INT8 * thisPhysPage = (INT8 *) physAddr;
    FAST UINT32 numBytesProcessed = 0;
    STATUS retVal	= OK;

    if (!vmLibInfo.vmBaseLibInstalled)
	return (ERROR);

    if ((NOT_PAGE_ALIGNED (thisVirtPage)) ||
        (NOT_PAGE_ALIGNED (thisPhysPage)) ||
        (NOT_PAGE_ALIGNED (len)))
	{
	errno = S_vmLib_NOT_PAGE_ALIGNED;
        return (ERROR); 
	}

    semTake (&currentContext->sem, WAIT_FOREVER);

    while (numBytesProcessed < len)
	{
	if (MMU_PAGE_MAP (currentContext->mmuTransTbl,
			  thisVirtPage, thisPhysPage) != OK)
	    {
	    retVal = ERROR;
	    break;
	    }

	if (vmBaseStateSet (currentContext, thisVirtPage, 
			    pageSize, stateMask, state) != OK)
	    {
	    retVal = ERROR;
	    break;
	    }

	thisVirtPage += pageSize;
	thisPhysPage += pageSize;
	numBytesProcessed += pageSize;
	}

    semGive (&currentContext->sem);

    return (retVal);
    }

/****************************************************************************
*
* vmBaseArch32Translate - translate a 32bit virtual address to a 32bit physical address
*
* vmBaseArch32Translate retrieves mapping information for a 32bit virtual 
* address from the page translation tables.  If the specified virtual 
* address has never been mapped, the returned status is ERROR.
* 
* This routine is callable from interrupt level.
* 
* RETURNS: OK, or ERROR if validation or translation fails.
*/

STATUS vmBaseArch32Translate 
    (
    void *  virtAddr, 		/* virtual address */
    void ** physAddr		/* place to put result */
    )
    {
    STATUS retVal;

    if (!vmLibInfo.vmBaseLibInstalled)
	return (ERROR);

    retVal = MMU_TRANSLATE (currentContext->mmuTransTbl, virtAddr, physAddr);

    return (retVal);
    }

