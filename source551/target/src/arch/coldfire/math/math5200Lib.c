/* math5200Lib.c - high-level floating-point emulation library for MCF5200 */

/* Copyright 1984-2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01d,14feb02,dyv  Testing - to remove the fltused symbol - VENKAT
01c,06dec01,rec change function prototypes to diab type.
01b,02sep98,mem removed __clear_sticky_bit.
01a,02jun98,mem	written
*/

/*
DESCRIPTION
This library provides software emulation of various high-level
floating-point operations for the ColdFire processors.

WARNING
Software floating point is not supported for all architectures.  See
the architecture-specific appendices of the
.I VxWorks Programmer's Guide.

INCLUDE FILES: math.h

SEE ALSO: mathHardLib, mathALib,
.I VxWorks Programmer's Guide
architecture-specific appendices
*/

#include "vxWorks.h"

/* diab fp intrinsics */
IMPORT void ___x_diab_almuld_o();
IMPORT void ___x_diab_dbtoll_o();
IMPORT void ___x_diab_double_o();
IMPORT void ___x_diab_dtof_o();
IMPORT void ___x_diab_dtol_o();
IMPORT void ___x_diab_fadd_o();
IMPORT void ___x_diab_faddf_o();
IMPORT void ___x_diab_fchip_o();
IMPORT void ___x_diab_fcmp_o();
IMPORT void ___x_diab_fdiv_o();
IMPORT void ___x_diab_fdivf_o();
IMPORT void ___x_diab_float_o();
IMPORT void ___x_diab_fltoll_o();
IMPORT void ___x_diab_fmul_o();
IMPORT void ___x_diab_fmulf_o();
IMPORT void ___x_diab_fnorm_o();
IMPORT void ___x_diab_fnormf_o();
IMPORT void ___x_diab_fpetrap_o();
IMPORT void ___x_diab_fsetup_o();
IMPORT void ___x_diab_fsetupf_o();
IMPORT void ___x_diab_ftod_o();
IMPORT void ___x_diab_ftol_o();
IMPORT void ___x_diab_hwtoll_o();
IMPORT void ___x_diab_lltodb_o();
IMPORT void ___x_diab_lltofl_o();
IMPORT void ___x_diab_lltohw_o();
IMPORT void ___x_diab_neg_o();
IMPORT void ___x_diab_ulltohw_o();
IMPORT void ___x_diab_realfp_o();
/* end of diab fp intrinsics */
VOIDFUNCPTR mathSoftModules [] =
    {
	    ___x_diab_almuld_o,
	    ___x_diab_dbtoll_o,
	    ___x_diab_double_o,
	    ___x_diab_dtof_o,
	    ___x_diab_dtol_o,
	    ___x_diab_fadd_o,
	    ___x_diab_faddf_o,
	    ___x_diab_fchip_o,
	    ___x_diab_fcmp_o,
	    ___x_diab_fdiv_o,
	    ___x_diab_fdivf_o,
	    ___x_diab_float_o,
	    ___x_diab_fltoll_o,
	    ___x_diab_fmul_o,
	    ___x_diab_fmulf_o,
	    ___x_diab_fnorm_o,
	    ___x_diab_fnormf_o,
	    ___x_diab_fpetrap_o,
	    ___x_diab_fsetup_o,
	    ___x_diab_fsetupf_o,
	    ___x_diab_ftod_o,
	    ___x_diab_ftol_o,
	    ___x_diab_hwtoll_o,
	    ___x_diab_lltodb_o,
	    ___x_diab_lltofl_o,
	    ___x_diab_lltohw_o,
	    ___x_diab_neg_o,
	    ___x_diab_ulltohw_o,
	    ___x_diab_realfp_o
    };

/******************************************************************************
*
* mathSoftInit - initialize software floating-point math support
*
* No operation is currently required for ColdFire.
*
* RETURNS: N/A
*
* SEE ALSO: mathHardInit()
*
*/

void mathSoftInit ()
    {
    }
