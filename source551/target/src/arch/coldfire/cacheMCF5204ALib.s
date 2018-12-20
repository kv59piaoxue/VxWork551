/* cacheMCF5204ALib.s - MCF5204 cache management assembly routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl  _copyright_wind_river
	.long   _copyright_wind_river

/*
modification history
--------------------
01b,27jun00,dh   updated to Tornado 2.0
01a,02jan97,kab  written; based on cacheMCF5202ALib.s
*/

/*
DESCRIPTION
This library contains routines to manipulate the MCF5204 cache.  All
of the routines in this file are specific to the MCF5204, and thus
contain "5204" in their name.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
.I "Motorola ColdFire Programmer's Reference Manual"
.I "MCF5204 ColdFire Integrated Microprocessor User's Manual"

*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "cacheLib.h"
#include "asm.h"

	.globl  _cacheMCF5204PushLine		/* push and invalidate cache */

	.text
	.even

/******************************************************************************
*
* cacheMCF5204PushLine - push and invalidate the specified cache line
*
* This routine pushes the specified cache line to the main memory.
*
* RETURNS: N/A

* void cacheMCF5204PushLine
*     (
*     int line				/@ cache line  @/
*     )

*/

_cacheMCF5204PushLine:
	link	a6,#0
	nop				/* flush the push and store buffer */
	movel	a6@(ARG1),a0		/* get line */
	CPUSHL(bc,a0@)			/* push line, set 0 */
	unlk	a6
	rts

