/* mathSoftLib.c - software floating-point math library */

/* Copyright 1984-1997 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,08jan97,tpr  reworked math functions dragging mechanism (SPR #7847).
01b,25jan97,tpr  added single precision fonctions.
01a,10nov96,tpr	 written.
*/

/*
DESCRIPTION
This library provides support routines for using the software 
floating-point emulation functions.
*/

#include "vxWorks.h"
#include "math.h"

DBLFUNCPTR	mathAcosPtr;	/* double-precision function ptrs */
DBLFUNCPTR	mathAtanPtr;
DBLFUNCPTR	mathCeilPtr;
DBLFUNCPTR	mathCosPtr;
DBLFUNCPTR	mathCoshPtr;
DBLFUNCPTR	mathFabsPtr;
DBLFUNCPTR	mathFloorPtr;
DBLFUNCPTR	mathFmodPtr;
DBLFUNCPTR	mathLogPtr;
DBLFUNCPTR	mathLog10Ptr;
DBLFUNCPTR	mathPowPtr;
DBLFUNCPTR	mathSinhPtr;
DBLFUNCPTR	mathTanPtr;
DBLFUNCPTR	mathTanhPtr;

FLTFUNCPTR	mathAcosfPtr;	/* single-precision function ptrs */
FLTFUNCPTR	mathAtanfPtr;
FLTFUNCPTR	mathCeilfPtr;
FLTFUNCPTR	mathCosfPtr;
FLTFUNCPTR	mathCoshfPtr;
FLTFUNCPTR	mathExpfPtr;
FLTFUNCPTR	mathFabsfPtr;
FLTFUNCPTR	mathFloorfPtr;
FLTFUNCPTR	mathFmodfPtr;
FLTFUNCPTR	mathLogfPtr;
FLTFUNCPTR	mathLog10fPtr;
FLTFUNCPTR	mathPowfPtr;
FLTFUNCPTR	mathSinfPtr;
FLTFUNCPTR	mathSinhfPtr;
FLTFUNCPTR	mathSqrtfPtr;	
FLTFUNCPTR	mathTanfPtr;
FLTFUNCPTR	mathTanhfPtr;


/*****************************************************************************
*
* mathSoftInit - initialize software floating-point math support
*
* This routine is called from usrConfig if INCLUDE_SW_FP is defined.  
* It will intialize the floating-point software support library, and 
* also cause the linker resolve the reference to mathSoftInit().
*/

void mathSoftInit (void)
    {
    /* Initialize double-precision routines */

    mathAcosPtr  = (DBLFUNCPTR) acos;	/* drag acos(), asin(), sqrt(),atan2()*/
    mathAtanPtr  = (DBLFUNCPTR) atan;	/* drag atan(), atan2() */

    mathCeilPtr  = (DBLFUNCPTR) ceil;	/* drag ceil() */
    mathCosPtr   = (DBLFUNCPTR) cos;	/* drag cos(), sin() */
    mathCoshPtr  = (DBLFUNCPTR) cosh;	/* drag cosh, exp() */

    mathFabsPtr  = (DBLFUNCPTR) fabs;	/* drag fabs() */
    mathFloorPtr = (DBLFUNCPTR) floor;	/* drag floor() */
    mathFmodPtr  = (DBLFUNCPTR) fmod;	/* drag fmod() */

    mathLogPtr   = (DBLFUNCPTR) log;	/* drag log() */
    mathLog10Ptr = (DBLFUNCPTR) log10;	/* drag log10() */

    mathPowPtr   = (DBLFUNCPTR) pow;	/* drag pow() */

    mathSinhPtr  = (DBLFUNCPTR) sinh;	/* drag sinh() */

    mathTanPtr   = (DBLFUNCPTR) tan;	/* drag tan() */
    mathTanhPtr  = (DBLFUNCPTR) tanh;	/* drag tanh() */

    /* Initialize single-precision routines */

    mathAtanfPtr  = (FLTFUNCPTR) atanf;	/* drag atanf(), atan2f(), asinf(), */
					/*      acosf() */

    mathCeilfPtr  = (FLTFUNCPTR) ceilf;	/* drag ceilf() */
    mathCoshfPtr  = (FLTFUNCPTR) coshf;	/* drag coshf(), sinhf(), tanhf() */

    mathExpfPtr   = (FLTFUNCPTR) expf;	/* drag expf() */

    mathFabsfPtr  = (FLTFUNCPTR) fabsf;	/* drag fabsf() */
    mathFloorfPtr = (FLTFUNCPTR) floorf;	/* drag floorf() */
    mathFmodfPtr  = (FLTFUNCPTR) fmodf;	/* drag fmodf(), frexpf(), ldexpf(), */
					/*      modff() */

    mathLogfPtr   = (FLTFUNCPTR) logf;	/* drag logf(), log10f() */

    mathPowfPtr   = (FLTFUNCPTR) powf;	/* drag powf() */

    mathSqrtfPtr  = (FLTFUNCPTR) sqrtf;	/* drag sqrtf() */

    mathSinfPtr   = (FLTFUNCPTR) sinf;	/* drag sinf(), cosf(), tanf() */
    }
