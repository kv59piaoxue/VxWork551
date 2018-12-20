/* cacheColdALib.s - ColdFire cache management assembly routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl  _copyright_wind_river
	.long   _copyright_wind_river

/*
modification history
--------------------
01a,22apr96,mem  written; based on cacheALib.s
*/

/*
DESCRIPTION
This library contains routines to manipulate ColdFire caches.  Routines
in this file are considered general enough to be used across all of the
ColdFire product members.  There are no dependecies in this code on
cache size or layout.

INCLUDE FILES: cacheLib.h

SEE ALSO: cacheLib
.I "Motorola ColdFire Programmer's Reference Manual"

*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "cacheLib.h"
#include "asm.h"

	.globl	_cacheCACRSet			/* set CACR register */
	.globl	_cacheWriteBufferFlush		/* flush the push buffer */
	.globl	_cacheACRSet			/* set ACR register */

	.text
	.even
	
/******************************************************************************
*
* cacheCACRSet - set the CACR register
*
* This routine sets the CACR control register.
*
* RETURNS: N/A
*
* SEE ALSO: 
* .I "Motorola ColdFire Programmer's Reference Manual"

* void cacheCACRSet
*     (
*     int newValue		/@ new value for the CACR @/
*     )

*/

_cacheCACRSet:
	link	a6,#0
	movel	a6@(ARG1),d0		/* put new CACR value */
	movec	d0,cacr
	unlk	a6
	rts

/******************************************************************************
*
* cacheWriteBufferFlush - flush the store buffer.
*
* This routine forces the store buffer to be flushed.
*
* RETURNS: N/A

* STATUS cacheWriteBufferFlush (void)

*/

_cacheWriteBufferFlush:
	nop				/* Flush the push and store buffer */
	clrl	d0			/* return OK */
	rts

/******************************************************************************
*
* cacheACRSet - set an ACR register
*
* This routine sets an ACR control register.
*
* RETURNS: N/A
*
* SEE ALSO: 
* .I "Motorola ColdFire Programmer's Reference Manual"

* void cacheACRSet
*     (
*     int acrNum		/@ ACR number (0..1, 0..3 on 54xx) @/
*     int newValue		/@ new value for the CACR @/
*     )

*/

_cacheACRSet:
	link	a6,#0
	movel	a6@(ARG1),d0		/* get ACR number */

#if (CPU==MCF5400)
	cmpl	#3,d0			/* ACR3? */
	bne	setAcr2
	movel	a6@(ARG2),d0		/* put new ACR3 value */
	movec	d0,acr3
	bra	setAcrEnd

setAcr2:
	cmpl	#2,d0			/* ACR2? */
	bne	setAcr1
	movel	a6@(ARG2),d0		/* put new ACR2 value */
	movec	d0,acr2
	bra	setAcrEnd
#endif

setAcr1:
	cmpl	#1,d0			/* ACR1? */
	bne	setAcr0
	movel	a6@(ARG2),d0		/* put new ACR1 value */
	movec	d0,acr1
	bra	setAcrEnd

setAcr0:
	cmpl	#0,d0			/* ACR0 ? */
	bne	setAcrEnd		/* ignore illegal ACR numbers */
	movel	a6@(ARG2),d0		/* put new ACR0 value */
	movec	d0,acr0
	bra	setAcrEnd

setAcrEnd:
	unlk	a6
	rts
