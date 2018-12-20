/* cacheMCF5407ALib.s - MCF5407 cache management assembly routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl  _copyright_wind_river
	.long   _copyright_wind_river

/*
modification history
--------------------
01b,07mar03,dee  fix SPR#86341 cache problem with breakpoints
01a,25oct00,dh   taken from Motorola T101 BSP for 5407, "Tornado-ised" and cleaned up
*/

/*
DESCRIPTION
This library contains routines to manipulate the MCF5407 cache.  All
of the routines in this file are specific to the MCF5407, and thus
contain "5407" in their name.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
.I "Motorola ColdFire Programmer's Reference Manual"
.I "MCF5407 ColdFire Integrated Microprocessor User's Manual"

*/

#define _ASMLANGUAGE

#include "vxWorks.h"
#include "asm.h"

	.globl	_cacheMCF5407DataPushAll
	.globl	_cacheMCF5407DataPushLine

	.globl	_cacheMCF5407InstPushAll
	.globl	_cacheMCF5407InstPushLine

	.text
	.even

/******************************************************************************
*
* cacheMCF5407DataPushAll - push and invalidate specified cache lines
*
* This routine pushes the specified number of data cache lines to the
* main memory.
*
* RETURNS: N/A
*
* void cacheMCF5407DataPushAll
*     (
*     int nlines			/@ number of cache lines  @/
*     )
*/
_cacheMCF5407DataPushAll:
	link	a6,#0
	movel	#0,a0		/* initialize a0 */
	movel	a6@(ARG1),d0	/* get nlines */
3:
	CPUSHL(dc,a0@)		/* push line, way 0 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(dc,a0@)		/* push line, way 1 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(dc,a0@)		/* push line, way 2 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(dc,a0@)		/* push line, way 3 */
	addl	#16-3,a0	/* increment cache set pointer */
	subql	#1,d0		/* decrement count */
	bne	3b
	unlk	a6
	rts

/******************************************************************************
*
* cacheMCF5407DataPushLine - push and invalidate specified cache line
*
* This routine pushes the data cache line containing the specified
* address to the main memory.
*
* RETURNS: N/A
*
* void cacheMCF5407DataPushLine
*     (
*     void *address 	/@ cache line @/
*     )
*/
_cacheMCF5407DataPushLine:
	link	a6,#0
	movel	a6@(ARG1),a0		/* get line */
	CPUSHL(dc,a0@)			/* push line, way 0 */
	addl	#1,a0			/* increment way number */	
	CPUSHL(dc,a0@)			/* push line, way 1 */
	addl	#1,a0			/* increment way number */	
	CPUSHL(dc,a0@)			/* push line, way 2 */
	addl	#1,a0			/* increment way number */	
	CPUSHL(dc,a0@)			/* push line, way 3 */
	unlk	a6
	rts

/******************************************************************************
*
* cacheMCF5407InstPushAll - push and invalidate specified cache lines
*
* This routine pushes the specified number of instruction cache lines to the
* main memory.
*
* RETURNS: N/A
*
* void cacheMCF5407InstPushAll
*     (
*     int nlines			/@ number of cache lines  @/
*     )
*/
_cacheMCF5407InstPushAll:
	link	a6,#0
	movel	#0,a0		/* initialize a0 */
	movel	a6@(ARG1),d0	/* get nlines */
4:
	CPUSHL(ic,a0@)		/* push line, way 0 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(ic,a0@)		/* push line, way 1 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(ic,a0@)		/* push line, way 2 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(ic,a0@)		/* push line, way 3 */
	addl	#16-3, a0	/* increment cache set pointer */
	subql	#1,d0		/* decrement count */
	bne	4b		/* branch if more to do */
	unlk	a6
	rts

/******************************************************************************
*
* cacheMCF5407InstPushLine - push and invalidate specified cache line
*
* This routine pushes the instruction cache line containing the specified
* address to the main memory.
*
* RETURNS: N/A
*
* void cacheMCF5407InstPushLine
*     (
*     void *address 	/@ cache line @/
*     )
*/
_cacheMCF5407InstPushLine:
	link	a6,#0
	nop			/* flush the push and store buffer */
	movel	a6@(ARG1),a0	/* get line */
	CPUSHL(ic,a0@)		/* push line, way 0 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(ic,a0@)		/* push line, way 1 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(ic,a0@)		/* push line, way 2 */
	addl	#1,a0		/* increment way number */	
	CPUSHL(ic,a0@)		/* push line, way 3 */
	unlk	a6
	rts
