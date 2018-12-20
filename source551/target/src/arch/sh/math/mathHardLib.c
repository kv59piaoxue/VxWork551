/* mathHardLib.c - hardware floating-point math library */

/* Copyright 1998-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01e,07sep01,zl   re-organized SH math library support (SPR #69834).
01d,20sep00,hk   moved external function pointer declarations to mathShLibP.h.
01c,27aug99,zl   added mathHardInit for SH7750
01b,15jun98,hk   reformatted to wrs style based on mc68k-01o.
01a,18mar98,asai written.
*/

/*
DESCRIPTION
This library provides support routines for using hardware floating-point
units.

The routines in this library are used automatically for high-level
math functions only if mathHardInit() has been called previously.

INCLUDE FILES: math.h

SEE ALSO: mathSoftLib, 
.I VxWorks Programmer's Guide
architecture-specific appendices
*/

#include "vxWorks.h"
#include "fppLib.h"

/******************************************************************************
*
* mathHardInit - initialize hardware floating-point math support
*
* This routine is called from usrConfig.c if INCLUDE_HW_FP is defined. 
*
* RETURNS: N/A
*
* SEE ALSO: mathSoftInit()
*/

void mathHardInit ()
    {
    /* initialize hardware FP support */

    fppInit();
    }
