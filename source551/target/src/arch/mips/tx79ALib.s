/* tx79ALib.s - Toshiba TX79 Support Routines */

/* Copyright 2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river

/*
 * This file has been developed or significantly modified by the
 * MIPS Center of Excellence Dedicated Engineering Staff.
 * This notice is as per the MIPS Center of Excellence Master Partner
 * Agreement, do not remove this notice without checking first with
 * WR/Platforms MIPS Center of Excellence engineering management.
 */

/*
modification history
--------------------

01a,23aug02,jmt   created
*/

/*
DESCRIPTION
	
This library contains the TX79 family support assembler routines.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "esf.h"
#include "fppLib.h"
#include "arch/mips/archMips.h"
#include "arch/mips/excMipsLib.h"
#include "private/taskLibP.h"
#include "arch/mips/fpSoft.h"
#include "asm.h"
#include "iv.h"

/* defines */

	/* internals */

#if (CPU == MIPS64)
	.globl	GTEXT(tx79AMult64)
#endif

        /* externals */

	.text
	.set	reorder

/******************************************************************************
* tx79AMult64 - 64 bit Multiply for Tx79
*
* This routine simulates a 64 bit unsigned multiply using 32 bit multiplies
* and 64 bit adds.
*
* The register state on entry to this routine is:
* 
*    a0 - first multiplier
*    a1 - second multiplier
*    a2 - pointer to lower half of result
*    a3 - pointer to upper half of result
*
* The multiply will be broken up into 4 32-bit multiplies.  The results will
* be combined using 32-bit adds to insure that data is not lost due to an
* overflow.  AB * CD = (AC << 64) + ((AD + BC) << 32) + BD
*
*  The registers are being used in the following way:
*	t0 - lower 32 bit of first multiplier and temp var
*	t1 - upper 32 bit of first multiplier and temp var
*	t2 - lower 32 bit of second multiplier
*	t3 - upper 32 bit of second multiplier
*	t4 - temp result #1
*	t5 - low accumulator
*	t6 - middle accumulator
*	t7 - temp result #2 and high accumulator
*/

#if (CPU == MIPS64)
	.ent	tx79AMult64
FUNC_LABEL(tx79AMult64)

	/* Extract lower 32 bit multiplier values */
	move	t0,a0		/* copy mult1 */
	dsll32	t0,t0,0		/* clear upper 32 bits */
	dsrl32	t0,t0,0
	move	t2,a1		/* copy mult2 */
	dsll32	t2,t2,0		/* clear upper 32 bits */
	dsrl32	t2,t2,0

	/* Extract upper 32 bit multiplier 1 values */
	move	t1,a0		/* copy mult1 */
	dsrl32	t1,t1,0		/* clear lower 32 bits */

	/* compute lower part of multiply */
	multu	t0,t2		/* perform lower portion of mult */

	/* Extract upper 32 bit multiplier 2 values */
	move	t3,a1		/* copy mult2 */
	dsrl32	t3,t3,0		/* clear lower 32 bits */

	/* get result of multiply and store */
	mfhi	t6		/* get upper 32 bits of result */
	mflo	t5		/* get lower 32 bits of result */
	HAZARD_CP_READ

	/* start second mult */
	multu	t0,t3		/* middle portion */

	/* clear upper 32 bits of each result */
	dsll32	t6,t6,0
	dsrl32	t6,t6,0
	dsll32	t5,t5,0
	dsrl32	t5,t5,0
	
	/* get result of second multiply */
	mfhi	t7		/* get upper 32 bits of result */
	mflo	t4		/* get lower 32 bits of result */
	HAZARD_CP_READ

	/* start third mult */
	multu	t1,t2		/* middle portion */

	/* clear upper 32 bits of each result */
	dsll32	t7,t7,0
	dsrl32	t7,t7,0
	dsll32	t4,t4,0
	dsrl32	t4,t4,0
	
	/* save result of second mult */
	daddu	t6,t6,t4	/* add lower bits to middle acc */

	/* get results of third mult */
	mfhi	t4		/* get upper 32 bits of result */
	mflo	t0		/* get lower 32 bits of result */
	HAZARD_CP_READ

	/* start last mult */
	multu	t1,t3		/* upper portion */

	/* clear upper 32 bits of each result */
	dsll32	t4,t4,0
	dsrl32	t4,t4,0
	dsll32	t0,t0,0
	dsrl32	t0,t0,0
	
	/* save result of third mult */
	daddu	t6,t6,t0	/* add lower bits to middle acc */
	daddu	t7,t7,t4	/* add upper bits to upper acc */

	/* get results of last mult */
	mfhi	t4		/* get upper 32 bits of result */
	mflo	t1		/* get lower 32 bits of result */
	HAZARD_CP_READ

	/* clear upper 32 bits of each result */
	dsll32	t4,t4,0
	dsrl32	t4,t4,0
	dsll32	t1,t1,0
	dsrl32	t1,t1,0
	
	/* combine lower 32 bits of middle acc to lower acc */
	move	t0,t6		/* get lower bits */
	dsll32	t0,t0,0		/* shift up 32 bits */
	daddu	t5,t5,t0	/* add to lower acc */
	sd	t5,0(a2)	/* save lower 64 bits */

	/* combine upper 32 bits of middle acc to upper acc */
	dsrl32	t6,t6,0		/* clear lower bits */
	daddu	t7,t7,t6	/* add upper bits to upper acc */
	daddu	t7,t7,t1	/* add last mult results to upper acc */
	dsll32	t4,t4,0
	daddu	t7,t7,t4
	sd	t7,0(a3)	/* save upper 64 bits */
	
	/* return */
	jr	ra
	
	.end	tx79AMult64
#endif

