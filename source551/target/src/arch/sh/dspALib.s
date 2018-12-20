/* dspALib.s - dsp coprocessor support assembly language routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01f,23aug00,hk   merge SH7729 to SH7700. added .align directive to dspRestore.
01e,28mar00,hk   added .type directive to function names.
01d,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01c,26mar99,jmb  added intLock with DSP on for DSP save and restore because
                 the external WDB agent (system mode) accesses the DSP
                 after all exceptions, including TRAPA.
01b,31aug98,kab  added MOD reg.
01a,22jul98,mem  written.
*/

/*
DESCRIPTION
This library contains routines to support the SH-DSP dsp
coprocessor.  The routines dspSave() and dspRestore() save and restore all the
task dsp context information, which consists of the dsp and system dsp-related
registers.  Higher-level access mechanisms are found in dspLib.

SEE ALSO: dspLib, SH-DSP User's Manual
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "dspLib.h"
#include "asm.h"

	.text

	/* internals */

	.globl _dspSave
	.globl _dspRestore

/******************************************************************************
*
* dspSave - save the dsp context
*
* This routine saves the dsp context.
* The context saved is:
*
*	- System registers rs, re, mod
*	- DSP control register, dsr
*	- DSP data registers (all regs in the dsp context are 32bits wide; 
*		the high 24 bits of A0G and A1G are masked off.)
*		- a0, a1, a0g, a1g, m0, m1, x0, x1, y0, y1
*	
* If the internal state frame is null, the other registers are not saved.
*
* RETURNS: N/A
*
* SEE ALSO: dspRestore()

* void dspSave
*    (
*    DSP_CONTEXT *  pDspContext  @* where to save context *@
*    )

*/
	.align	_ALIGN_TEXT
	.type	_dspSave,@function

_dspSave:
	mov	r4,r3			/* save pDspContext */
	mov	r4,r2			/* save pDspContext */

	add	#56,  r4
#if (CPU==SH7700)		/* Make sure DSP bit enabled */
        stc	sr, r5
	mov.l	LockMask, r1
 	ldc	r1, sr
#endif
	stc.l	mod,  @-r4
	movs.l	y1,   @-r4
	movs.l	y0,   @-r4
	movs.l	x1,   @-r4
	movs.l	x0,   @-r4
	movs.l	m1,   @-r4
	movs.l	m0,   @-r4	
	movs.l	a1g,  @-r4
	movs.l	a0g,  @-r4
	movs.l	a1,   @-r4
	movs.l	a0,   @-r4
	sts.l	dsr,  @-r4
	stc.l	re,   @-r4
	stc.l	rs,   @-r4

#if (CPU==SH7700)
 	ldc	r5, sr
#endif

	/* mask undefined top 24 bits of guard registers */
	add	#DSPREG_SET_A0G,r3	/* set address of a0g in dspContext */
	mov.l	@r3,r1			/* fetch guard bits from dspContext */
	extu.b	r1,r0			/* zero extend */
	mov.l	r0,@r3			/* store back to dspContext */
	
	add	#DSPREG_SET_A1G,r2	/* set address of a1g in dspContext */
	mov.l	@r2,r1			/* fetch guard bits from dspContext */
	extu.b	r1,r0			/* zero extend */
	mov.l	r0,@r2			/* store back to dspContext */

	rts				/* return */
	nop


/******************************************************************************
*
* dspRestore - restore the dsp context
*
* This routine restores the dsp context.
* The context restored is:
*
*	- System registers rs, re, mod
*	- DSP control register, dsr
*	- DSP data registers (all regs in the dsp context are 32bits wide; 
*		the high 24 bits of A0G and A1G are masked off.)
*		- a0, a1, a0g, a1g, m0, m1, x0, x1, y0, y1
*
* If the internal state frame is null, the other registers are not restored.
*
* RETURNS: N/A
*
* SEE ALSO: dspSave()

* void dspRestore
*    (
*    DSP_CONTEXT *  pDspContext  @* from where to restore context *@
*    )

*/
	.align	_ALIGN_TEXT
	.type	_dspRestore,@function

_dspRestore:
#if (CPU==SH7700)
        stc	sr, r5
	mov.l	LockMask, r1
 	ldc	r1, sr
#endif
	ldc.l	@r4+,rs
	ldc.l	@r4+,re
	lds.l	@r4+,dsr
	/* sign extended into guard regs */
	movs.l	@r4+,a0
	movs.l	@r4+,a1
	/* top 24 bits ignored when saving guard bits */
	movs.l	@r4+,a0g
	movs.l	@r4+,a1g
	movs.l	@r4+,m0
	movs.l	@r4+,m1
	movs.l	@r4+,x0
	movs.l	@r4+,x1
	movs.l	@r4+,y0
	movs.l	@r4+,y1
	ldc.l	@r4+,mod
#if (CPU==SH7700)
 	ldc	r5, sr
#endif
	rts
	nop

#if (CPU==SH7700)
	.align 2
LockMask:
	.long 0x400010f0
#endif
