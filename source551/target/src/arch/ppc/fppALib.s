/* fppALib.s - PowerPC floating-point unit support assembly language routines */

/*
modification history
--------------------
01g,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01f,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01e,07aug97,tam  undid modification 01d (SPR #8943).
01d,10feb97,tam  removed code which was setting MSR[FP] bit.
01c,13nov96,tam	 adjusted offset for register FPCSR when saving/restoring it
		 since it is saved/restore as a double (spr #7464).
01b,02feb95,yao  added conditional for _PPC_MSR_FP.
           +caf  cleanup.
01a,12jan95,caf  created.
*/

#define _ASMLANGUAGE

#include "vxWorks.h"
#include "fppLib.h"

	FUNC_EXPORT(fppSave)
	FUNC_EXPORT(fppRestore)

	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* fppSave - save the floating-pointing coprocessor context
*
* This routine saves the floating-point coprocessor context.
* The context saved is:
*
*       - registers fr0 - fr31
*       - the fpscr register
*
* RETURNS: N/A
*
* SEE ALSO: fppRestore(), PowerPC 601 RISC Microprocessor User's Manual

* void fppSave
*    (
*    FP_CONTEXT *  pFpContext  /@ where to save context @/
*    )

*/

FUNC_LABEL(fppSave)

#ifdef	_PPC_MSR_FP
        /*
	 * make sure FPU is enabled by setting MSR[FP] bit: this is necessary
	 * since fppSave() may be called from an non-floating point context,
	 * such as an ISR for instance.
	 */

        mfmsr   p2                              /* load msr         */
        ori     p2, p2, _PPC_MSR_FP             /* set FP bit       */
        mtmsr   p2                              /* UNLOCK INTERRUPT */
        isync                                   /* syncronize       */

	stfd	fr0,  FPX_OFFSET(0)(p0)		/* save fr0 */
	stfd	fr1,  FPX_OFFSET(1)(p0)		/* save fr1 */
	stfd	fr2,  FPX_OFFSET(2)(p0)		/* save fr2 */
	stfd	fr3,  FPX_OFFSET(3)(p0)		/* save fr3 */
	stfd	fr4,  FPX_OFFSET(4)(p0)		/* save fr4 */
	stfd	fr5,  FPX_OFFSET(5)(p0)		/* save fr5 */
	stfd	fr6,  FPX_OFFSET(6)(p0)		/* save fr6 */
	stfd	fr7,  FPX_OFFSET(7)(p0)		/* save fr7 */
	stfd	fr8,  FPX_OFFSET(8)(p0)		/* save fr8 */
	stfd	fr9,  FPX_OFFSET(9)(p0)		/* save fr9 */
	stfd	fr10, FPX_OFFSET(10)(p0)	/* save fr10 */
	stfd	fr11, FPX_OFFSET(11)(p0)	/* save fr11 */
	stfd	fr12, FPX_OFFSET(12)(p0)	/* save fr12 */
	stfd	fr13, FPX_OFFSET(13)(p0)	/* save fr13 */
	stfd	fr14, FPX_OFFSET(14)(p0)	/* save fr14 */
	stfd	fr15, FPX_OFFSET(15)(p0)	/* save fr15 */
	stfd	fr16, FPX_OFFSET(16)(p0)	/* save fr16 */
	stfd	fr17, FPX_OFFSET(17)(p0)	/* save fr17 */
	stfd	fr18, FPX_OFFSET(18)(p0)	/* save fr18 */
	stfd	fr19, FPX_OFFSET(19)(p0)	/* save fr19 */
	stfd	fr20, FPX_OFFSET(20)(p0)	/* save fr20 */
	stfd	fr21, FPX_OFFSET(21)(p0)	/* save fr21 */
	stfd	fr22, FPX_OFFSET(22)(p0)	/* save fr22 */
	stfd	fr23, FPX_OFFSET(23)(p0)	/* save fr23 */
	stfd	fr24, FPX_OFFSET(24)(p0)	/* save fr24 */
	stfd	fr25, FPX_OFFSET(25)(p0)	/* save fr25 */
	stfd	fr26, FPX_OFFSET(26)(p0)	/* save fr26 */
	stfd	fr27, FPX_OFFSET(27)(p0)	/* save fr27 */
	stfd	fr28, FPX_OFFSET(28)(p0)	/* save fr28 */
	stfd	fr29, FPX_OFFSET(29)(p0)	/* save fr29 */
	mffs	fr28				/* use fp28 to save fpscr */
	stfd	fr30, FPX_OFFSET(30)(p0)	/* save fr30 */
	stfd	fr28, (FPCSR_OFFSET - 4)(p0)   	/* save fpscr as a double */
	stfd	fr31, FPX_OFFSET(31)(p0)	/* save fr31: only after */
						/* fpscr has been saved */
	lfd 	fr28, FPX_OFFSET(28)(p0)	/* restore fr28 */
#endif	/* _PPC_MSR_FP */

	blr			/* return to caller */

/*******************************************************************************
*
* fppRestore - restore the floating-point coprocessor context
*
* This routine restores the floating-point coprocessor context.
* The context restored is:
*
*       - registers fr0 - fr31
*       - the fpscr register
*
* RETURNS: N/A
*
* SEE ALSO: fppSave(), PowerPC 601 RISC Microprocessor User's Manual

* void fppRestore
*    (
*    FP_CONTEXT *  pFpContext  /@ from where to restore context @/
*    )

*/

FUNC_LABEL(fppRestore)

#ifdef	_PPC_MSR_FP
        /*
	 * make sure FPU is enabled by setting MSR[FP] bit: this is necessary
	 * since fppRestore() may be called from an non-floating point context,
	 * such as an ISR for instance.
	 */

        mfmsr   p2                              /* load msr         */
        ori     p2, p2, _PPC_MSR_FP             /* set FP bit       */
        mtmsr   p2                              /* UNLOCK INTERRUPT */
        isync                                   /* syncronize       */

	lfd	fr1,  (FPCSR_OFFSET - 4)(p0)	/* load fpscr as a double */
	mtfsf	255,  fr1			/* restore fpscr    */
	lfd	fr0,  FPX_OFFSET(0)(p0)		/* restore fr0      */
	lfd	fr1,  FPX_OFFSET(1)(p0)		/* restore fr1      */
	lfd	fr2,  FPX_OFFSET(2)(p0)		/* restore fr2      */
	lfd	fr3,  FPX_OFFSET(3)(p0)		/* restore fr3      */
	lfd	fr4,  FPX_OFFSET(4)(p0)		/* restore fr4      */
	lfd	fr5,  FPX_OFFSET(5)(p0)		/* restore fr5      */
	lfd	fr6,  FPX_OFFSET(6)(p0)		/* restore fr6      */
	lfd	fr7,  FPX_OFFSET(7)(p0)		/* restore fr7      */
	lfd	fr8,  FPX_OFFSET(8)(p0)		/* restore fr8      */
	lfd	fr9,  FPX_OFFSET(9)(p0)		/* restore fr9      */
	lfd	fr10, FPX_OFFSET(10)(p0)	/* restore fr10     */
	lfd	fr11, FPX_OFFSET(11)(p0)	/* restore fr11     */
	lfd	fr12, FPX_OFFSET(12)(p0)	/* restore fr12     */
	lfd	fr13, FPX_OFFSET(13)(p0)	/* restore fr13     */
	lfd	fr14, FPX_OFFSET(14)(p0)	/* restore fr14     */
	lfd	fr15, FPX_OFFSET(15)(p0)	/* restore fr15     */
	lfd	fr16, FPX_OFFSET(16)(p0)	/* restore fr16     */
	lfd	fr17, FPX_OFFSET(17)(p0)	/* restore fr17     */
	lfd	fr18, FPX_OFFSET(18)(p0)	/* restore fr18     */
	lfd	fr19, FPX_OFFSET(19)(p0)	/* restore fr19     */
	lfd	fr20, FPX_OFFSET(20)(p0)	/* restore fr20     */
	lfd	fr21, FPX_OFFSET(21)(p0)	/* restore fr21     */
	lfd	fr22, FPX_OFFSET(22)(p0)	/* restore fr22     */
	lfd	fr23, FPX_OFFSET(23)(p0)	/* restore fr23     */
	lfd	fr24, FPX_OFFSET(24)(p0)	/* restore fr24     */
	lfd	fr25, FPX_OFFSET(25)(p0)	/* restore fr25     */
	lfd	fr26, FPX_OFFSET(26)(p0)	/* restore fr26     */
	lfd	fr27, FPX_OFFSET(27)(p0)	/* restore fr27     */
	lfd	fr28, FPX_OFFSET(28)(p0)	/* restore fr28     */
	lfd	fr29, FPX_OFFSET(29)(p0)	/* restore fr29     */
	lfd	fr30, FPX_OFFSET(30)(p0)	/* restore fr30     */
	lfd	fr31, FPX_OFFSET(31)(p0)	/* restore fr31     */

#endif	/* _PPC_MSR_FP */
	blr			/* return to caller */
