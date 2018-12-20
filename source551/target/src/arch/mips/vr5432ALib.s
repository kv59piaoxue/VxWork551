/* vr5432ALib.s - NEC Vr5432 support assembly routines */

/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

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
01c,02aug01,mem  Diab integration
01b,16jul01,ros  add CofE comment
01a,05jun01,mem written.
*/

/*
DESCRIPTION
This library contains routines to be used to support the 
NEC Vr5432 processor.

SEE ALSO:
fppLib
.I "MIPS RISC Architecture"
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "fppLib.h"
#include "esf.h"
#include "dsmLib.h"
#include "private/taskLibP.h"
#include "asm.h"

	/* internals */

#if !defined(SOFT_FLOAT) && (_WRS_FP_REGISTER_SIZE == 8)
	.globl GTEXT(vr5432FppSave)
	.globl GTEXT(vr5432FppRestore)
	.globl GTEXT(vr5432FppInitialize)
#endif	/* !defined(SOFT_FLOAT) && (_WRS_FP_REGISTER_SIZE == 8) */

	.text
	.set	reorder

#if !defined(SOFT_FLOAT) && (_WRS_FP_REGISTER_SIZE == 8)
/******************************************************************************
*
* vr5432FppSave - save the floating-point coprocessor context
*
* This routine saves the Vr5432 accumulator register.
*
* RETURNS: N/A

* void vr5432FppSave
*     (
*     FP_CONTEXT *  pFpContext	/* where to save context *
*     )

*/

	.ent	vr5432FppSave
FUNC_LABEL(vr5432FppSave)
	dmfc1	a1,fp0		/* save fp0 */
        racl.ob fp0
        sdc1    fp0,FPEXTRA(a0)
        racm.ob fp0
        sdc1    fp0,FPEXTRA+8(a0)
        rach.ob fp0
        sdc1    fp0,FPEXTRA+16(a0)
	dmtc1	a1,fp0		/* restore fp0 */
	j	ra
	.end	vr5432FppSave

/******************************************************************************
*
* vr5432FppRestore - restore the floating-point coprocessor context
*
* This routine restores the Vr5432 accumulator register.
*
* RETURNS: N/A
*

* void vr5432FppRestore
*    (
*    FP_CONTEXT *  pFpContext	/* from where to restore context *
*    )

*/

	.ent	vr5432FppRestore
FUNC_LABEL(vr5432FppRestore)
	dmfc1	a1,fp0		/* save fp0 */
	dmfc1	a2,fp1		/* save fp1 */
        ldc1    fp0,FPEXTRA(a0)
        ldc1    fp1,FPEXTRA+8(a0)
        wacl.ob fp1,fp0
        ldc1    fp0,FPEXTRA+16(a0)
        wach.ob fp0
	dmtc1	a1,fp0		/* restore fp0 */
	dmtc1	a2,fp1		/* restore fp1 */
	j	ra
	.end	vr5432FppRestore

/******************************************************************************
*
* vr5432FppInitialize - initialize the floating-point coprocessor
*
* This routine initializes the Vr5432 accumulator register.
*
* RETURNS: N/A
*
* NOMANUAL

* void vr5432FppInitialize ()

*/

	.ent	vr5432FppInitialize
FUNC_LABEL(vr5432FppInitialize)
	wacl.ob	fp1,fp1			/* zero the accumulator */
	wach.ob	fp1	
	j	ra
	.end	vr5432FppInitialize

#endif	/* !defined(SOFT_FLOAT) && (_WRS_FP_REGISTER_SIZE == 8) */
