/* mathHardLib.c - hardware floating point math library */

/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
 * This file has been developed or significantly modified by the
 * MIPS Center of Excellence Dedicated Engineering Staff.
 * This notice is as per the MIPS Center of Excellence Master Partner
 * Agreement, do not remove this notice without checking first with
 * WR/Platforms MIPS Center of Excellence engineering management.
 */

/*
modification history
--------------------
01d,16jul01,ros  add CofE comment
01c,24apr01,mem  Stub-out for soft-float builds.
01b,20sep92,kdl	 fixed typo in extern statement.
01a,19sep92,kdl	 written.
*/

/*
DESCRIPTION

This library provides support routines for using the hardware floating
point functions.

*/

#include "vxWorks.h"
#include "math.h"
#include "fppLib.h"

extern	void	mathHardALibInit (void);


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
#ifndef SOFT_FLOAT
    fppInit ();			/* init hardware support */

    if (fppProbe () == OK)
	mathHardALibInit ();	/* drag in assembly math functions */
#endif	/* SOFT_FLOAT */
    }
