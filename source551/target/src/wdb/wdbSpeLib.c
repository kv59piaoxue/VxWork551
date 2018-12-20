/* wdbSpeLib.c - Spe register support for the external WDB agent */

/* Copyright 1984-1996 Wind River Systems, Inc. */

/*
modification history
--------------------
01a,01oct03,dtr  Fix for acces to registers before init.

01a,01sep02,dtr Created library from altivec.
*/

/*
DESCPRIPTION

This library contains routines to save, restore, get, and
set the spe registers. These operations are
not task-specific.
*/
#include "vxWorks.h"

#ifdef  _WRS_SPE_SUPPORT

#include "wdb/wdbRegs.h"
#include "string.h"
#include "speLib.h"
/* 
 * The SPE_REG_SET_OBJ is defined as a pointer and mem for it allocated at
 * run time. The reason for this is to ensure that this object especially the
 * first element speContext is 16 byte aligned.
 */

SPE_REG_SET_OBJ WRS_DATA_ALIGN_BYTES(_CACHE_ALIGN_SIZE) speRegSetObj = {{0},{0}};


/******************************************************************************
*
* wdbSpeSave - save the spe registers.
*/ 

void wdbSpeSave (void)
    {
    speSave (&speRegSetObj.speContext);
    }

/******************************************************************************
*
* wdbSpeRestore - restore the previously saved spe regs.
*/ 

void wdbSpeRestore (void)
    {
    speRestore (&speRegSetObj.speContext);
    }

/******************************************************************************
*
* wdbSpeGet - get a pointer to the spe reg block.
*/ 

void wdbSpeGet
    (
    void ** ppRegs
    )
    {
    *ppRegs = (void *) &speRegSetObj.speContext;
    }

/******************************************************************************
*
* wdbSpeSet - set the Spe reg block.
*/ 

void wdbSpeSet
    (
    void * pRegs
    )
    {
    bcopy ((char *)pRegs, (char *) &speRegSetObj.speContext, sizeof (SPE_CONTEXT));
    }

/******************************************************************************
*
* wdbSpeLibInit - initialize a WDB_REG_SET_OBJ representing spe regs.
*
* RETURNS: a pointer to a WDB_REG_SET_OBJ
*/ 

WDB_REG_SET_OBJ * wdbSpeLibInit (void)
    {

    WDB_REG_SET_OBJ * pRegSet = &speRegSetObj.regSet;

    speSave (&speRegSetObj.speContext);

    pRegSet->regSetType	= WDB_REG_SET_SPE;
    pRegSet->save	= wdbSpeSave;
    pRegSet->load	= wdbSpeRestore;
    pRegSet->get	= (void (*) (char **)) wdbSpeGet;
    pRegSet->set	= (void (*) (char *))  wdbSpeSet;

    return (pRegSet);
    }

#endif /* (_WRS_SPE_SUPPORT==TRUE) */



