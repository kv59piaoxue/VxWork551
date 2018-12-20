/* mathHardLib.c - hardware floating point math library */

/* Copyright 1984-1996 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,10nov96,tpr	 written.
*/

/*
DESCRIPTION

This library provides support routines for using the hardware floating
point functions.

*/

#include "vxWorks.h"
#include "math.h"
#include "fppLib.h"

/******************************************************************************
*
* mathHardInit - initialize hardware floating point math support
*
* This routine is called from usrConfig if INCLUDE_HW_FP is defined.  
* This routine will intialize the floating point hardware support 
* library (fppLib) and also cause the linker to include the functions
* in mathHardALib.s.  
*
*/

void mathHardInit ()
    {
    fppInit ();			/* initialize the hardware support */
    }
