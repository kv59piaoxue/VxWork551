/* mmuMapLib.c - MMU mapping library for ARM Ltd. processors */

/* Copyright 1998-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,14nov01,to   'void pointer arithmetic' shouldn't be used
01a,25nov98,jpd  written.
*/

/*
DESCRIPTION
This library provides additional MMU support routines.  These are
present in a separate module from mmuLib.c, so that these routines can
be used without including all the code in that object module.
*/


#include "vxWorks.h"
#include "vmLib.h"

/******************************************************************************
*
* mmuVirtToPhys - translate a virtual address to a physical address (ARM)
*
* This function converts a virtual address to a physical address using
* the information contained within the sysPhysMemDesc structure of the
* BSP.  This routine may be used both by the BSP MMU initialization and
* by the vm(Base)Lib code.
*
* If the BSP has a default mapping where physical and virtual
* addresses are not identical, then it must provide routines to the cache
* and MMU architecture code to convert between physical and virtual
* addresses.  If the mapping described within the sysPhysMemDesc structure
* is accurate, then the BSP may use this routine.  If it is not
* accurate, then routines must be provided within the BSP that are
* accurate.
*
* NOTE
* This routine simply performs a linear search through the
* sysPhysMemDesc structure looking for the first entry with an address
* range that includes the given address.  Typically, the performance of
* this should not be a problem, as this routine will generally be called
* to translate RAM addresses, and by convention, the RAM entries come
* first in the structure.  If this becomes an issue, the routine could be
* changed so that a separate structure to sysPhysMemDesc is used,
* containing the information in a more quickly accessible form.  In any
* case, if this is not satisfactory, the BSP can provide its own
* routines.
*
* SEE ALSO:
* mmuPhysToVirt
*
* RETURNS: the physical address
*/

void * mmuVirtToPhys
    (
    void *      virtAddr	/* virtual address to be translated */
    )
    {
    int i;

    for (i = 0; i < sysPhysMemDescNumEnt; i++)
	{
	if ((sysPhysMemDesc[i].virtualAddr <= virtAddr) &&
	    (((UINT)sysPhysMemDesc[i].virtualAddr + sysPhysMemDesc[i].len - 1)
							    >= (UINT)virtAddr))
	    return (void *)((UINT)sysPhysMemDesc[i].physicalAddr +
		    ((UINT)virtAddr - (UINT)sysPhysMemDesc[i].virtualAddr));
	}

    /* Not really much to be done here, we found no match */

    return virtAddr;
    }

/******************************************************************************
*
* mmuPhysToVirt - translate a physical address to a virtual address (ARM)
*
* This function converts a physical address to a virtual address using
* the information contained within the sysPhysMemDesc structure of the
* BSP.  This routine may be used both by the BSP MMU initialization and by
* the vm(Base)Lib code.
*
* If the BSP has a default mapping where physical and virtual
* addresses are not identical, then it must provide routines to the cache
* and MMU architecture code to convert between physical and virtual
* addresses.  If the mapping described within the sysPhysMemDesc structure
* is accurate, then the BSP may use this routine.  If it is not
* accurate, then routines must be provided within the BSP that are
* accurate.
*
* NOTE
* This routine simply performs a linear search through the
* sysPhysMemDesc structure looking for the first entry with an address
* range that includes the given address.  Typically, the performance of
* this should not be a problem, as this routine will generally be called
* to translate RAM addresses, and by convention, the RAM entries come
* first in the structure.  If this becomes an issue, the routine could be
* changed so that a separate structure to sysPhysMemDesc is used,
* containing the information in a more quickly accessible form.  In any
* case, if this is not satisfactory, the BSP can provide its own
* routines.
*
* SEE ALSO:
* mmuVirtToPhys
*
* RETURNS: the virtual address
*/

void * mmuPhysToVirt
    (
    void *	physAddr	/* physical address to be translated */
    )
    {
    int i;

    for (i = 0; i < sysPhysMemDescNumEnt; i++)
	{
	if ((sysPhysMemDesc[i].physicalAddr <= physAddr) &&
	    (((UINT)sysPhysMemDesc[i].physicalAddr + sysPhysMemDesc[i].len - 1)
							     >= (UINT)physAddr))
	    return (void *)((UINT)sysPhysMemDesc[i].virtualAddr +
		    ((UINT)physAddr - (UINT)sysPhysMemDesc[i].physicalAddr));
	}

    /* Not really much to be done here, we found no match */

    return physAddr;
    }
