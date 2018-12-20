/* ffsALib.s - find first set function */

/* Copyright 1984-1995 Wind River Systems, Inc. */
        /* XXX .globl   copyright_wind_river */

/*
modification history
--------------------
01e,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01d,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01c,21mar95,caf  used FUNC_LABEL macro.
01b,10feb95,caf  optimized further.
01a,11jan95,caf  created, based on 68k version.
*/

/*
DESCRIPTION
This library implements ffsMsb() which returns the most significant bit set. By
taking advantage of the "cntlzw" instruction of PowerPC processors, the
implementation determines the first bit set in constant time.
*/	

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"


#if (defined(PORTABLE))
#define ffsALib_PORTABLE
#endif

#ifndef ffsALib_PORTABLE

	/* exports */
	FUNC_EXPORT(ffsMsb)

	
	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* ffsMsb - find first set bit (searching from the most significant bit)
*
* This routine finds the first bit set in the argument passed it and
* returns the index of that bit.  Bits are numbered starting
* at 1 from the least significant bit.  A return value of zero indicates that
* the value passed is zero.
*

* void ffsMsb
*     (
*     int i        /@ argument to find first set bit in @/
*     )

*/

FUNC_LABEL(ffsMsb)
	cntlzw	p0, p0			/* p0 = # leading zeros */
        subfic  p0, p0, 32              /* p0 = 32 - p0         */
        blr                             /* return to the caller */

#endif  /* ! ffsALib_PORTABLE */
