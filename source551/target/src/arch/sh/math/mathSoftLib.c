/* mathSoftLib.c - software floating-point math library */

/* Copyright 1993-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01k,20mar02,zl   pull in software FP supporting routines.
01j,07sep01,zl   re-organized SH math library support (SPR #69834).
01i,16sep00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
		 reorder funcs. delete ANSI-math bindings in mathSoftInit.
01h,27aug99,zl   moved SH4 mathHardInit() to mathHardLib.c
01g,09jun99,zl   hitachi SH4 architecture port, provided by Highlander
                  Engineering
01f,03mar99,hk   added support for SH7750, SH7729, and SH7410.
01e,15jun98,hk   added SH7718(SH3e) on-chip FPU support. took mc68k-01o as
                 the baseline, inspired with a prototype from hms.
01d,03jul95,hk   documentation review.
01c,24apl95,sa 	 FUNCPTR dummyFuncPtr; -> volatile FUNCPTR dummyFuncPtr;
01b,08feb95,sa 	 Hitachi SH GO-FAST support.
01a,15jul93,jwt	 written, based on mathHardLib.c, to resolve mathSoftInit().
*/

/*
DESCRIPTION
This library provides support routines for using the software 
floating-point emulation functions.
*/

#include "vxWorks.h"

extern char ___sh_swfp_single_o();
extern char ___sh_swfp_double_o();

/* This array will force inclusion of support routines */

void * shSwfpIntrinsics[] =
    {
    (void *) &___sh_swfp_single_o,
    (void *) &___sh_swfp_double_o
    };

/******************************************************************************
*
* mathSoftInit - initialize software floating-point math support
*
* This routine references the emulated low-level math functions required for
* to force them to be linked in vxWorks image.
*
* NOTE:	This routine is called from usrRoot() in usrConfig.c, if INCLUDE_SW_FP
*	is defined.
*/

void mathSoftInit (void)
    {
    }
