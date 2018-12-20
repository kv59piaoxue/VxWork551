/* cplusDemStyle.c - C++ symbol demangler style */

/* Copyright 2003 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,05may03,sn   added support for GCC 3.x
01a,14apr03,sn   wrote
*/

/*
DESCRIPTION
Provides definition of cplusDemStyle which is used by both host 
and target tools to determine which demangling style to use.

NOMANUAL
*/

#include "cplusLib.h"

DEMANGLER_STYLE cplusDemanglerStyle;

/*******************************************************************************
*
* cplusDemanglerStyleInit - initialize C++ demangling style (C++)
*
* Called if INCLUDE_CPLUS_MIN is included.

* RETURNS: N/A
*/

void cplusDemanglerStyleInit (void)
    {
#ifdef __GNUC__
#if (__GNUC__ >= 3)
    cplusDemanglerStyle = DMGL_STYLE_IA64_ABI;
#else	/* (__GNUC >= 3) */
    cplusDemanglerStyle = DMGL_STYLE_GNU;
#endif	/* (__GNUC >= 3) */   
#else	/* __GNUC__ */
    cplusDemanglerStyle = DMGL_STYLE_DIAB;
#endif	/* __GNUC__ */
    }

/*******************************************************************************
*
* cplusDemanglerStyleSet - initialize change C++ demangling style (C++)
*
* This command sets the C++ demangling style to <style>.
* The default demangling style depends on the toolchain
* used to build the kernel. For example if the Diab
* toolchain is used to build the kernel then the default
* demangler style is DMGL_STYLE_DIAB.
*
* This routine is deprecated; there is no need to set
* the demangler style because it should always be
* set correctly by cplusDemanglerStyleInit.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void cplusDemanglerStyleSet
    (          
    DEMANGLER_STYLE style
    )          
    {
    cplusDemanglerStyle = style;
    }



