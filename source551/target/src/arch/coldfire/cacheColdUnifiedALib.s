/* cacheColdUnifiedALib.s - ColdFire unified cache assembly routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl  _copyright_wind_river
	.long   _copyright_wind_river

/*
modification history
--------------------
01c,15jun00,dh   T2/Coldfire merge.
01b,18may98,mem  moved disable of cache to after pushl flushing to
		 workaround mcf5307 errata.
01a,06may98,mem  written; based on old cacheMCF5202ALib.s
*/

/*
DESCRIPTION
This library contains routines to manipulate the ColdFire unified
cache.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
.I "Motorola ColdFire Programmer's Reference Manual"

*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "cacheLib.h"
#include "asm.h"

	.globl	_cacheColdUnifiedDataDisable	/* data cache disable routine*/
	.globl  _cacheColdUnifiedPushAll	/* push and invalidate cache */
	.globl  _cacheColdUnifiedPushLine	/* push and invalidate cache */

	.text
	.even
	
/******************************************************************************
*
* cacheColdUnifiedDataDisable - push, invalidate, and disable the cache.
*
* This is the support routine for turning off the ColdFire unified cache.
* This routine pushes the entire cache to the main memory,
* invalidates the data cache, and finally disables the CACR bit for the
* data cache.
*
* The MCF5202 provides a four-entry store buffer, other processors
* will probably have one as well.
* This store buffer is used to defer pending writes in order to
* increase the processor performance. When enabled the store buffer is used
* only in writethrough mode and cache inhibited non-serial mode. The store
* buffer and push buffer are flushed when synchronize instructions (i.e. nop)
* are excecuted.
*
* Interrupts are locked out during the execution of this routine.
*
 
* void cacheColdUnifiedDataDisable (int nlines)
 
* NOMANUAL
*/

_cacheColdUnifiedDataDisable:
	link	a6,#0
	movel	a6@(ARG1),d0		/* get nlines */
	nop				/* flush the push and store buffer */
	movel	#0,a0			/* initialize a0 */
1:
	CPUSHL(bc,a0@)			/* push line, set 0 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 1 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 2 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 3 */
	addl	#16-3,a0		/* increment cache line pointer */
	subql	#1,d0			/* decrement count */
	bne	1b
	nop				/* flush the push and store buffer */
	clrl	d1
	movec	d1,cacr			/* turn off cache */
	nop
	unlk	a6
	rts

/******************************************************************************
*
* cacheColdUnifiedPushAll - push and invalidate the entire cache
*
* This routine pushes the entire cache to the main memory.
*
* RETURNS: N/A

* void cacheColdUnifiedPushAll (int nlines)

*/

_cacheColdUnifiedPushAll:
	link	a6,#0
	movel	#0,a0			/* initialize a0 */
	movel	a6@(ARG1),d0		/* get nlines */
1:
	CPUSHL(bc,a0@)			/* push line, set 0 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 1 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 2 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 3 */
	addl	#16-3,a0		/* increment cache line pointer */
	subql	#1,d0			/* decrement count */
	bne	1b
	unlk	a6
	rts

/******************************************************************************
*
* cacheColdUnifiedPushLine - push and invalidate the specified cache line
*
* This routine pushes the specified cache line to the main memory.
*
* RETURNS: N/A

* void cacheColdUnifiedPushLine
*     (
*     int line				/@ cache line  @/
*     )

*/

_cacheColdUnifiedPushLine:
	link	a6,#0
	nop				/* flush the push and store buffer */
	movel	a6@(ARG1),a0		/* get line */
	CPUSHL(bc,a0@)			/* push line, set 0 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 1 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 2 */
	addl	#1,a0			/* increment set number */	
	CPUSHL(bc,a0@)			/* push line, set 3 */
	unlk	a6
	rts

