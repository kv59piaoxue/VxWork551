/* wdbDbgALib.s - debugging aids assembly language interface */

/* Copyright 1984-1998 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history
--------------------
01u,02dec02,mil  Updated support for PPC85XX.
01t,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
01s,01may02,dtr  Putting long calls in the debug stubs.
01r,23oct01,jab  removed unnecessary .type directive
01q,25sep01,yvp  Fix SPR62760:	Use _WRS_TEXT_SEG_START macro instead of .align
01p,23aug01,pch  Add PPC440; clean up refs to wdbDbgTrace and wdbDbgTraceStub;
		 clean up function labels.
01o,24jul01,r_s  added .globl  FUNC(wdbDbgTraceStub) directive
01n,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01m,31oct00,s_m  fixed 405 CPU types (use &&›s instead of ||s)
01l,25oct00,s_m  renamed PPC405 cpu types
01k,13jun2k,alp  Added PPC405 Support.
01j,19apr99,zl   added support for PPC509 and PPC555
01i,13oct98,elg  added hardware breakpoints for PPC603 and PPC604
01h,27jul98,elg  added hardware breakpoints
01g,09jan98,dbt  modified for new breakpoint scheme
01f,12feb97,tam  removed wdbBpStub().
01e,09jul96,ms   403 now works with new breakpoint library
01d,29feb96,ms   no longer need to bump stack pointer.
01c,28feb96,tam  added support for the PPC403.
01b,20feb96,tpr  re-worked following new exception handling.
01a,28nov95,tpr  written from /arch/mc68k/wdbALib.s 01c version.
*/

/*
DESCRIPTION
This module contains assembly language routines needed for the debug
package and the PowerPC exception vectors.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "esf.h"
#include "arch/ppc/dbgPpcLib.h"

	/* globals */

#ifdef	_PPC_MSR_SE
	FUNC_EXPORT(wdbDbgTraceStub)	/* trace exceptions handler */
#endif	/* _PPC_MSR_SE */

#if	DBG_HARDWARE_BP
# if	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))
	FUNC_EXPORT(dbgCmpaGet)	/* get the value of comparator A */
	FUNC_EXPORT(dbgCmpaSet)	/* set the value of comparator A */
	FUNC_EXPORT(dbgCmpbGet)	/* get the value of comparator B */
	FUNC_EXPORT(dbgCmpbSet)	/* set the value of comparator B */
	FUNC_EXPORT(dbgCmpcGet)	/* get the value of comparator C */
	FUNC_EXPORT(dbgCmpcSet)	/* set the value of comparator C */
	FUNC_EXPORT(dbgCmpdGet)	/* get the value of comparator D */
	FUNC_EXPORT(dbgCmpdSet)	/* set the value of comparator D */
	FUNC_EXPORT(dbgCmpeGet)	/* get the value of comparator E */
	FUNC_EXPORT(dbgCmpeSet)	/* set the value of comparator E */
	FUNC_EXPORT(dbgCmpfGet)	/* get the value of comparator F */
	FUNC_EXPORT(dbgCmpfSet)	/* set the value of comparator F */
	FUNC_EXPORT(dbgLctrl1Get)	/* get the value of LCTRL1 */
	FUNC_EXPORT(dbgLctrl1Set)	/* set the value of LCTRL1 */
	FUNC_EXPORT(dbgLctrl2Get)	/* get the value of LCTRL2 */
	FUNC_EXPORT(dbgLctrl2Set)	/* set the value of LCTRL2 */
	FUNC_EXPORT(dbgIctrlGet)	/* get the value of ICTRL */
	FUNC_EXPORT(dbgIctrlSet)	/* set the value of ICTRL */
# endif	/* (CPU == PPC5xx) || (CPU == PPC860) */

# if	(CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)
	FUNC_EXPORT(wdbDbgIabrGet)		/* read the value of IABR */
	FUNC_EXPORT(wdbDbgIabrSet)		/* set the value of IABR */
# endif	/* (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) */

# if	(CPU == PPC604)
	FUNC_EXPORT(wdbDbgDabrGet)		/* read the value of DABR */
	FUNC_EXPORT(wdbDbgDabrSet)		/* set the value of DABR */
	FUNC_EXPORT(wdbDbgDarGet)		/* read the value of DAR */
	FUNC_EXPORT(wdbDbgDataAccessStub)	/* data access handler */
# endif	/* (CPU == PPC604) */

# if	(CPU == PPC403)
	FUNC_EXPORT(wdbDbgDbcrGet)		/* read the value of DBCR */
	FUNC_EXPORT(wdbDbgDbcrSet)		/* set the value of DBCR */
	FUNC_EXPORT(wdbDbgDbsrGet)		/* read the value of DBSR */
	FUNC_EXPORT(wdbDbgDbsrSet)		/* set the value of DBSR */
	FUNC_EXPORT(wdbDbgDac1Get)		/* read the value of DAC1 */
	FUNC_EXPORT(wdbDbgDac1Set)		/* set the value of DAC1 */
	FUNC_EXPORT(wdbDbgDac2Get)		/* read the value of DAC2 */
	FUNC_EXPORT(wdbDbgDac2Set)		/* set the value of DAC2 */
	FUNC_EXPORT(wdbDbgIac1Get)		/* read the value of IAC1 */
	FUNC_EXPORT(wdbDbgIac1Set)		/* set the value of IAC1 */
	FUNC_EXPORT(wdbDbgIac2Get)		/* read the value of IAC2 */
	FUNC_EXPORT(wdbDbgIac2Set)		/* set the value of IAC2 */
# endif	/* (CPU == PPC403) */

# if	((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
	 (CPU == PPC85XX))
	FUNC_EXPORT(wdbDbgDbcr0Get)		/* read the value of DBCR0 */
	FUNC_EXPORT(wdbDbgDbcr0Set)		/* set the value of DBCR0 */
	FUNC_EXPORT(wdbDbgDbcr1Get)		/* read the value of DBCR1 */
	FUNC_EXPORT(wdbDbgDbcr1Set)		/* set the value of DBCR1 */
#  if	((CPU == PPC440) || (CPU == PPC85XX))
	FUNC_EXPORT(wdbDbgDbcr2Get)		/* read the value of DBCR2 */
	FUNC_EXPORT(wdbDbgDbcr2Set)		/* set the value of DBCR2 */
#  endif  /* CPU == PPC440, PPC85XX */
	FUNC_EXPORT(wdbDbgDbsrGet)		/* read the value of DBSR */
	FUNC_EXPORT(wdbDbgDbsrSet)		/* set the value of DBSR */
	FUNC_EXPORT(wdbDbgDac1Get)		/* read the value of DAC1 */
	FUNC_EXPORT(wdbDbgDac1Set)		/* set the value of DAC1 */
	FUNC_EXPORT(wdbDbgDac2Get)		/* read the value of DAC2 */
	FUNC_EXPORT(wdbDbgDac2Set)		/* set the value of DAC2 */
	FUNC_EXPORT(wdbDbgIac1Get)		/* read the value of IAC1 */
	FUNC_EXPORT(wdbDbgIac1Set)		/* set the value of IAC1 */
	FUNC_EXPORT(wdbDbgIac2Get)		/* read the value of IAC2 */
	FUNC_EXPORT(wdbDbgIac2Set)		/* set the value of IAC2 */
#  if	(CPU != PPC85XX)
	FUNC_EXPORT(wdbDbgIac3Get)		/* read the value of IAC3 */
	FUNC_EXPORT(wdbDbgIac3Set)		/* set the value of IAC3 */
	FUNC_EXPORT(wdbDbgIac4Get)		/* read the value of IAC4 */
	FUNC_EXPORT(wdbDbgIac4Set)		/* set the value of IAC4 */
#  endif  /* CPU != PPC85XX */
# endif	/* CPU == PPC405, PPC405F, PPC440, PPC85XX */

	FUNC_EXPORT(wdbDbgHwBpStub)	/* breakpoint handler */
#endif	/* DBG_HARDWARE_BP */

	/* externals */

#ifdef	_PPC_MSR_SE
	FUNC_IMPORT(wdbDbgTrace)	/* trace processing routine */
#endif	/* _PPC_MSR_SE */

#if	DBG_HARDWARE_BP
	FUNC_IMPORT(wdbDbgHwBpHandle)	/* hardware breakpoint handler */
#endif	/* DBG_HARDWARE_BP */
	
	_WRS_TEXT_SEG_START
	
/*
 * Conditioning this on _PPC_MSR_SE rather than !DBG_NO_SINGLE_STEP
 * because it is for the specific case of a unique trace interrupt
 * which is not shared with other debugging facilities.
 */
#ifdef	_PPC_MSR_SE
/**************************************************************************
*
* wdbDbgTraceStub - trace exception processing
*
* This routine is attached to the trace exception vector.  It saves the
* entire task context on the stack and calls wdbDbgTrace () to handle the
* event.
*
* NOMANUAL
*/

FUNC_BEGIN(wdbDbgTraceStub)
	/* At the entry of this function, the following is done */
	/* mtspr	SPRG3, p0		/@ save P0 to SPRG3 */
	/* mflr		p0 			/@ load LR to P0 */
	/* bla		excEnt 			/@ call excEnt() */
	/* addi		r3, sp, 0		/@ save ESF pointer to R3 */
	/* addi		sp, sp, -FRAMEBASESZ	/@ carve frame */
	/* bla		wdbDbgTraceStub		/@ branch to this stub */

	lis	p1,HIADJ(wdbDbgTrace)
	addi	p1,p1,LO(wdbDbgTrace)
	mtlr	p1
	addi	p1, p0, _PPC_ESF_REG_BASE 	/* pass REG_SET to P1 */
	blrl					/* do exception processing */
FUNC_END(wdbDbgTraceStub)
#endif	/* _PPC_MSR_SE */

#if	DBG_HARDWARE_BP
#if	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))
/**************************************************************************
*
* dbgCmpaGet - read the current value of the comparator A
*
* RETURNS: the CMPA value
*
* NOMANUAL
*
* UINT dbgCmpaGet ()
*/

FUNC_BEGIN(dbgCmpaGet)
	mfspr	p0, CMPA			/* get the CMPA value */
	blr					/* return to caller */
FUNC_END(dbgCmpaGet)

/**************************************************************************
*
* dbgCmpaSet - set the value of the comparator A
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgCmpaSet
*	(
*	UINT val	/@ CMPA value @/
*	)
*/

FUNC_BEGIN(dbgCmpaSet)
	mtspr 	CMPA, p0			/* set the CMPA value */
	blr					/* return to caller */
FUNC_END(dbgCmpaSet)

/**************************************************************************
*
* dbgCmpbGet - read the current value of the comparator B
*
* RETURNS: the CMPB value
*
* NOMANUAL
*
* UINT dbgCmpbGet ()
*/

FUNC_BEGIN(dbgCmpbGet)
	mfspr	p0, CMPB			/* get the CMPB value */
	blr					/* return to caller */
FUNC_END(dbgCmpbGet)

/**************************************************************************
*
* dbgCmpbSet - set the value of the comparator B
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgCmpbSet
*	(
*	UINT val	/@ CMPB value @/
*	)
*/

FUNC_BEGIN(dbgCmpbSet)
	mtspr 	CMPB, p0			/* set the CMPB value */
	blr					/* return to caller */
FUNC_END(dbgCmpbSet)

/**************************************************************************
*
* dbgCmpcGet - read the current value of the comparator C
*
* RETURNS: the CMPC value
*
* NOMANUAL
*
* UINT dbgCmpcGet ()
*/

FUNC_BEGIN(dbgCmpcGet)
	mfspr	p0, CMPC			/* get the CMPC value */
	blr					/* return to caller */
FUNC_END(dbgCmpcGet)

/**************************************************************************
*
* dbgCmpcSet - set the value of the comparator C
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgCmpcSet
*	(
*	UINT val	/@ CMPC value @/
*	)
*/

FUNC_BEGIN(dbgCmpcSet)
	mtspr 	CMPC, p0			/* set the CMPC value */
	blr					/* return to caller */
FUNC_END(dbgCmpcSet)

/**************************************************************************
*
* dbgCmpdGet - read the current value of the comparator D
*
* RETURNS: the CMPD value
*
* NOMANUAL
*
* UINT dbgCmpdGet ()
*/

FUNC_BEGIN(dbgCmpdGet)
	mfspr	p0, CMPD			/* get the CMPD value */
	blr					/* return to caller */
FUNC_END(dbgCmpdGet)

/**************************************************************************
*
* dbgCmpdSet - set the value of the comparator D
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgCmpdSet
*	(
*	UINT val	/@ CMPD value @/
*	)
*/

FUNC_BEGIN(dbgCmpdSet)
	mtspr 	CMPD, p0			/* set the CMPD value */
	blr					/* return to caller */
FUNC_END(dbgCmpdSet)

/**************************************************************************
*
* dbgCmpeGet - read the current value of the comparator E
*
* RETURNS: the CMPE value
*
* NOMANUAL
*
* UINT dbgCmpeGet ()
*/

FUNC_BEGIN(dbgCmpeGet)
	mfspr	p0, CMPE			/* get the CMPE value */
	blr					/* return to caller */
FUNC_END(dbgCmpeGet)

/**************************************************************************
*
* dbgCmpeSet - set the value of the comparator E
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgCmpeSet
*	(
*	UINT val	/@ CMPE value @/
*	)
*/

FUNC_BEGIN(dbgCmpeSet)
	mtspr 	CMPE, p0			/* set the CMPE value */
	blr					/* return to caller */
FUNC_END(dbgCmpeSet)

/**************************************************************************
*
* dbgCmpfGet - read the current value of the comparator F
*
* RETURNS: the CMPF value
*
* NOMANUAL
*
* UINT dbgCmpfGet ()
*/

FUNC_BEGIN(dbgCmpfGet)
	mfspr	p0, CMPF			/* get the CMPF value */
	blr					/* return to caller */
FUNC_END(dbgCmpfGet)

/**************************************************************************
*
* dbgCmpfSet - set the value of the comparator F
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgCmpfSet
*	(
*	UINT val	/@ CMPF value @/
*	)
*/

FUNC_BEGIN(dbgCmpfSet)
	mtspr 	CMPF, p0			/* set the CMPF value */
	blr					/* return to caller */
FUNC_END(dbgCmpfSet)

/**************************************************************************
*
* dbgLctrl1Get - read the current value of the LCTRL1 register
*
* RETURNS: the LCTRL1 value
*
* NOMANUAL
*
* UINT dbgLctrl1Get ()
*/

FUNC_BEGIN(dbgLctrl1Get)
	mfspr	p0, LCTRL1			/* get the LCTRL1 value */
	blr					/* return to caller */
FUNC_END(dbgLctrl1Get)

/**************************************************************************
*
* dbgLctrl1Set - set the value of the LCTRL1 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgLctrl1Set
*	(
*	UINT val	/@ LCTRL1 value @/
*	)
*/

FUNC_BEGIN(dbgLctrl1Set)
	mtspr 	LCTRL1, p0			/* set the LCTRL1 value */
	blr					/* return to caller */
FUNC_END(dbgLctrl1Set)

/**************************************************************************
*
* dbgLctrl2Get - read the current value of the LCTRL2 register
*
* RETURNS: the LCTRL2 value
*
* NOMANUAL
*
* UINT dbgLctrl2Get ()
*/

FUNC_BEGIN(dbgLctrl2Get)
	mfspr	p0, LCTRL2			/* get the LCTRL2 value */
	blr					/* return to caller */
FUNC_END(dbgLctrl2Get)

/**************************************************************************
*
* dbgLctrl2Set - set the value of the LCTRL2 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgLctrl2Set
*	(
*	UINT val	/@ LCTRL2 value @/
*	)
*/

FUNC_BEGIN(dbgLctrl2Set)
	mtspr 	LCTRL2, p0			/* set the LCTRL2 value */
	blr					/* return to caller */
FUNC_END(dbgLctrl2Set)

/**************************************************************************
*
* dbgIctrlGet - read the current value of the ICTRL register
*
* RETURNS: the ICTRL value
*
* NOMANUAL
*
* UINT dbgIctrlGet ()
*/

FUNC_BEGIN(dbgIctrlGet)
	mfspr	p0, ICTRL			/* get the ICTRL value */
	blr					/* return to caller */
FUNC_END(dbgIctrlGet)

/**************************************************************************
*
* dbgIctrlSet - set the value of the ICTRL register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void dbgIctrlSet
*	(
*	UINT val	/@ ICTRL value @/
*	)
*/

FUNC_BEGIN(dbgIctrlSet)
	mtspr 	ICTRL, p0			/* set the ICTRL value */
	blr					/* return to caller */
FUNC_END(dbgIctrlSet)
#endif	/* (CPU == PPC5xx) || (CPU == PPC860) */

#if	(CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)
/**************************************************************************
*
* wdbDbgIabrGet - read the value of the IABR register
*
* RETURNS : the IABR value
*
* NOMANUAL
*
* UINT wdbDbgIabrGet (void)
*
*/

FUNC_BEGIN(wdbDbgIabrGet)
	mfspr	p0, IABR			/* read the IABR value */
	blr					/* return to caller */
FUNC_END(wdbDbgIabrGet)

/**************************************************************************
*
* wdbDbgIabrSet - set the value of the IABR register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgIabrSet
*     (
*     UINT val		/@ IABR value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgIabrSet)
	mtspr	IABR, p0			/* set the IABR value */
	blr					/* return to caller */
FUNC_END(wdbDbgIabrSet)
#endif	/* (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) */

#if	(CPU == PPC604)
/*************************************************************************
*
* wdbDbgDabrGet - read the value of the DABR register
*
* RETURNS : the DABR value
*
* NOMANUAL
*
* UINT wdbDbgDabrGet (void)
*
*/

FUNC_BEGIN(wdbDbgDabrGet)
	mfspr	p0, DABR			/* read the DABR value */
	blr					/* return to caller */
FUNC_END(wdbDbgDabrGet)

/*************************************************************************
*
* wdbDbgDabrSet - set the value of the DABR register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDabrSet
*     (
*     UINT val				/@ DABR value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDabrSet)
	mtspr	DABR, p0			/* set the DABR value */
	blr					/* return to caller */
FUNC_END(wdbDbgDabrSet)

/*************************************************************************
*
* wdbDbgDarGet - read the value of the DAR register
*
* RETURNS : the DAR value
*
* NOMANUAL
*
* UINT wdbDbgDarGet (void)
*
*/

FUNC_BEGIN(wdbDbgDarGet)
	mfspr	p0, DAR				/* read the DAR value */
	blr					/* return to caller */
FUNC_END(wdbDbgDarGet)

/**************************************************************************
*
* wdbDbgDataAccessStub - data access handling (low level)
*
* This routine is the low level routine for data access exception (DSI).
* If the exception is caused by a hardware data breakpoint, the routine
* calls wdbDbgHwBpHandle(), otherwise it calls excExcHandle().
*
* NOMANUAL
*/

FUNC_BEGIN(wdbDbgDataAccessStub)
	/* At the entry of this function, the following is done */
	/* mtspr	SPRG3, p0		/@ save P0 to SPRG3 */
	/* mflr		p0			/@ load LR to P0 */
	/* bla		excEnt			/@ call excEnt () */
	/* addi		r3, sp, 0		/@ save ESF pointer to r3 */
	/* addi 	sp, sp, -FRAMEBASESZ	/@ carve frame */
	/* bla 		wdbDbgHwBpStub		/@ branch to this stub */
	mfspr	p1, DSISR			/* read DSISR register */
	rlwinm	p1, p1, 16, 25, 25		/* extract DSISR[9] */
	cmplwi	p1, 64				/* is DSISR[9] == 1 ? */
	beq	hwDataBp
	mflr    p1				/* Need to save original link register value */
	mtspr	SPRG0,p1			/* SPRG0 used in handler stub but released */
	lis	p1,HIADJ(excExcHandle)
	addi	p1,p1,LO(excExcHandle)
	mtlr	p1
	blrl					/* FUNC(excExcHandle)	 no, default treatment */
	mfspr	p1,SPRG0			/* Restore link register */
	mtlr    p1	
	blrl					/* return to restore regs */
hwDataBp:
	lis	p1,HIADJ(wdbDbgHwBpHandle)
	addi	p1,p1,LO(wdbDbgHwBpHandle)
	mtlr	p1
	addi	p1, p0, _PPC_ESF_REG_BASE	/* pass REG_SET to P1 */
	blrl					/* FUNC(wdbDbgHwBpHandle) do exception processing */
FUNC_END(wdbDbgDataAccessStub)
#endif	/* (CPU == PPC604) */

#if	(CPU == PPC403)
/*************************************************************************
*
* wdbDbgDbcrGet - read the value of the DBCR register
*
* RETURNS : the DBCR value
*
* NOMANUAL
*
* UINT wdbDbgDbcrGet (void)
*
*/

FUNC_BEGIN(wdbDbgDbcrGet)
	mfspr	p0, DBCR			/* read the DBCR value */
	blr					/* return to caller */
FUNC_END(wdbDbgDbcrGet)

/*************************************************************************
*
* wdbDbgDbcrSet - set the value of the DBCR register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDbcrSet
*     (
*     UINT val				/@ DBCR value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDbcrSet)
	mtspr	DBCR, p0			/* set the DBCR value */
	blr					/* return to caller */
FUNC_END(wdbDbgDbcrSet)

/*************************************************************************
*
* wdbDbgDbsrGet - read the value of the DBSR register
*
* RETURNS : the DBSR value
*
* NOMANUAL
*
* UINT wdbDbgDbsrGet (void)
*
*/

FUNC_BEGIN(wdbDbgDbsrGet)
	mfspr	p0, DBSR			/* read the DBSR value */
	blr					/* return to caller */
FUNC_END(wdbDbgDbsrGet)

/*************************************************************************
*
* wdbDbgDbsrSet - set the value of the DBSR register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDbsrSet
*     (
*     UINT val				/@ DBSR value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDbsrSet)
	mtspr	DBSR, p0			/* set the DBSR value */
	blr					/* return to caller */
FUNC_END(wdbDbgDbsrSet)

/*************************************************************************
*
* wdbDbgDac1Get - read the value of the DAC1 register
*
* RETURNS : the DAC1 value
*
* NOMANUAL
*
* UINT wdbDbgDac1Get (void)
*
*/

FUNC_BEGIN(wdbDbgDac1Get)
	mfspr	p0, DAC1			/* read the DAC1 value */
	blr					/* return to caller */
FUNC_END(wdbDbgDac1Get)

/*************************************************************************
*
* wdbDbgDac1Set - set the value of the DAC1 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDac1Set
*     (
*     UINT val				/@ DAC1 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDac1Set)
	mtspr	DAC1, p0			/* set the DAC1 value */
	blr					/* return to caller */
FUNC_END(wdbDbgDac1Set)

/*************************************************************************
*
* wdbDbgDac2Get - read the value of the DAC2 register
*
* RETURNS : the DAC2 value
*
* NOMANUAL
*
* UINT wdbDbgDac2Get (void)
*
*/

FUNC_BEGIN(wdbDbgDac2Get)
	mfspr	p0, DAC2			/* read the DAC2 value */
	blr					/* return to caller */
FUNC_END(wdbDbgDac2Get)

/*************************************************************************
*
* wdbDbgDac2Set - set the value of the DAC2 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDac2Set
*     (
*     UINT val				/@ DAC2 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDac2Set)
	mtspr	DAC2, p0			/* set the DAC2 value */
	blr					/* return to caller */
FUNC_END(wdbDbgDac2Set)

/*************************************************************************
*
* wdbDbgIac1Get - read the value of the IAC1 register
*
* RETURNS : the IAC1 value
*
* NOMANUAL
*
* UINT wdbDbgIac1Get (void)
*
*/

FUNC_BEGIN(wdbDbgIac1Get)
	mfspr	p0, IAC1			/* read the IAC1 value */
	blr					/* return to caller */
FUNC_END(wdbDbgIac1Get)

/*************************************************************************
*
* wdbDbgIac1Set - set the value of the IAC1 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgIac1Set
*     (
*     UINT val				/@ IAC1 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgIac1Set)
	mtspr	IAC1, p0			/* set the IAC1 value */
	blr					/* return to caller */
FUNC_END(wdbDbgIac1Set)

/*************************************************************************
*
* wdbDbgIac2Get - read the value of the IAC2 register
*
* RETURNS : the IAC2 value
*
* NOMANUAL
*
* UINT wdbDbgIac2Get (void)
*
*/

FUNC_BEGIN(wdbDbgIac2Get)
	mfspr	p0, IAC2			/* read the IAC2 value */
	blr					/* return to caller */
FUNC_END(wdbDbgIac2Get)

/*************************************************************************
*
* wdbDbgIac2Set - set the value of the IAC2 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgIac2Set
*     (
*     UINT val				/@ IAC2 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgIac2Set)
	mtspr	IAC2, p0			/* set the IAC2 value */
	blr					/* return to caller */
FUNC_END(wdbDbgIac2Set)
#endif	/* (CPU == PPC403) */

#if     ((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
	 (CPU == PPC85XX))
/*************************************************************************
*
* wdbDbgDbcr0Get - read the value of the DBCR register
*
* RETURNS : the DBCR value
*
* NOMANUAL
*
* UINT wdbDbgDbcr0Get (void)
*
*/

FUNC_BEGIN(wdbDbgDbcr0Get)
        mfspr   p0, DBCR0                        /* read the DBCR value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDbcr0Get)

/*************************************************************************
*
* wdbDbgDbcr0Set - set the value of the DBCR register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDbcr0Set
*     (
*     UINT val                          /@ DBCR value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDbcr0Set)
        mtspr   DBCR0, p0                        /* set the DBCR value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDbcr0Set)

/*************************************************************************
*
* wdbDbgDbcr1Get - read the value of the DBCR1 register
*
* RETURNS : the DBCR value
*
* NOMANUAL
*
* UINT wdbDbgDbcr1Get (void)
*
*/

FUNC_BEGIN(wdbDbgDbcr1Get)
        mfspr   p0, DBCR1                        /* read the DBCR1 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDbcr1Get)

/*************************************************************************
*
* wdbDbgDbcr1Set - set the value of the DBCR register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDbcr1Set
*     (
*     UINT val                          /@ DBCR1 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDbcr1Set)
        mtspr   DBCR1, p0                        /* set the DBCR1 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDbcr1Set)

#  if	((CPU == PPC440) || (CPU == PPC85XX))
/*************************************************************************
*
* wdbDbgDbcr2Get - read the value of the DBCR2 register
*
* RETURNS : the DBCR value
*
* NOMANUAL
*
* UINT wdbDbgDbcr2Get (void)
*
*/

FUNC_BEGIN(wdbDbgDbcr2Get)
        mfspr   p0, DBCR2                        /* read the DBCR2 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDbcr2Get)

/*************************************************************************
*
* wdbDbgDbcr2Set - set the value of the DBCR register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDbcr2Set
*     (
*     UINT val                          /@ DBCR2 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDbcr2Set)
        mtspr   DBCR2, p0                        /* set the DBCR2 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDbcr2Set)
#  endif  /* CPU == PPC440, PPC85XX */

/*************************************************************************
*
* wdbDbgDbsrGet - read the value of the DBSR register
*
* RETURNS : the DBSR value
*
* NOMANUAL
*
* UINT wdbDbgDbsrGet (void)
*
*/

FUNC_BEGIN(wdbDbgDbsrGet)
        mfspr   p0, DBSR                        /* read the DBSR value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDbsrGet)

/*************************************************************************
*
* wdbDbgDbsrSet - set the value of the DBSR register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDbsrSet
*     (
*     UINT val                          /@ DBSR value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDbsrSet)
        mtspr   DBSR, p0                        /* set the DBSR value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDbsrSet)

/*************************************************************************
*
* wdbDbgDac1Get - read the value of the DAC1 register
*
* RETURNS : the DAC1 value
*
* NOMANUAL
*
* UINT wdbDbgDac1Get (void)
*
*/

FUNC_BEGIN(wdbDbgDac1Get)
        mfspr   p0, DAC1                        /* read the DAC1 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDac1Get)

/*************************************************************************
*
* wdbDbgDac1Set - set the value of the DAC1 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDac1Set
*     (
*     UINT val                          /@ DAC1 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDac1Set)
        mtspr   DAC1, p0                        /* set the DAC1 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDac1Set)

/*************************************************************************
*
* wdbDbgDac2Get - read the value of the DAC2 register
*
* RETURNS : the DAC2 value
*
* NOMANUAL
*
* UINT wdbDbgDac2Get (void)
*
*/

FUNC_BEGIN(wdbDbgDac2Get)
        mfspr   p0, DAC2                        /* read the DAC2 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDac2Get)

/*************************************************************************
*
* wdbDbgDac2Set - set the value of the DAC2 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgDac2Set
*     (
*     UINT val                          /@ DAC2 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgDac2Set)
        mtspr   DAC2, p0                        /* set the DAC2 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgDac2Set)

/*************************************************************************
*
* wdbDbgIac1Get - read the value of the IAC1 register
*
* RETURNS : the IAC1 value
*
* NOMANUAL
*
* UINT wdbDbgIac1Get (void)
*
*/

FUNC_BEGIN(wdbDbgIac1Get)
        mfspr   p0, IAC1                        /* read the IAC1 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgIac1Get)

/*************************************************************************
*
* wdbDbgIac1Set - set the value of the IAC1 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgIac1Set
*     (
*     UINT val                          /@ IAC1 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgIac1Set)
        mtspr   IAC1, p0                        /* set the IAC1 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgIac1Set)

/*************************************************************************
*
* wdbDbgIac2Get - read the value of the IAC2 register
*
* RETURNS : the IAC2 value
*
* NOMANUAL
*
* UINT wdbDbgIac2Get (void)
*
*/

FUNC_BEGIN(wdbDbgIac2Get)
        mfspr   p0, IAC2                        /* read the IAC2 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgIac2Get)

/*************************************************************************
*
* wdbDbgIac2Set - set the value of the IAC2 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgIac2Set
*     (
*     UINT val                          /@ IAC2 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgIac2Set)
        mtspr   IAC2, p0                        /* set the IAC2 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgIac2Set)

#  if	(CPU != PPC85XX)

/*************************************************************************
*
* wdbDbgIac3Get - read the value of the IAC1 register
*
* RETURNS : the IAC1 value
*
* NOMANUAL
*
* UINT wdbDbgIac3Get (void)
*
*/

FUNC_BEGIN(wdbDbgIac3Get)
        mfspr   p0, IAC3                        /* read the IAC3 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgIac3Get)

/*************************************************************************
*
* wdbDbgIac3Set - set the value of the IAC1 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgIac3Set
*     (
*     UINT val                          /@ IAC3 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgIac3Set)
        mtspr   IAC3, p0                        /* set the IAC3 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgIac3Set)

/*************************************************************************
*
* wdbDbgIac4Get - read the value of the IAC4 register
*
* RETURNS : the IAC4 value
*
* NOMANUAL
*
* UINT wdbDbgIac4Get (void)
*
*/

FUNC_BEGIN(wdbDbgIac4Get)
        mfspr   p0, IAC4                        /* read the IAC4 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgIac4Get)

/*************************************************************************
*
* wdbDbgIac4Set - set the value of the IAC2 register
*
* RETURNS : N/A
*
* NOMANUAL
*
* void wdbDbgIac4Set
*     (
*     UINT val                          /@ IAC4 value @/
*     )
*
*/

FUNC_BEGIN(wdbDbgIac4Set)
        mtspr   IAC4, p0                        /* set the IAC4 value */
        blr                                     /* return to caller */
FUNC_END(wdbDbgIac4Set)

#  endif  /* CPU != PPC85XX */

#endif  /* CPU == PPC405, PPC405F, PPC440, PPC85XX */

/**************************************************************************
*
* wdbDbgHwBpStub - breakpoint handling (low level)
*
* NOMANUAL
*/

FUNC_BEGIN(wdbDbgHwBpStub)
	/* At the entry of this function, the following is done */
	/* mtspr	SPRG3, p0		/@ save P0 to SPRG3 */
	/* mflr		p0			/@ load LR to P0 */
	/* bla		excEnt			/@ call excEnt () */
	/* addi		r3, sp, 0		/@ save ESF pointer to r3 */
	/* addi 	sp, sp, -FRAMEBASESZ	/@ carve frame */
	/* bla 		wdbDbgHwBpStub		/@ branch to this stub */	
	lis	p1,HIADJ(wdbDbgHwBpHandle)
	addi	p1,p1,LO(wdbDbgHwBpHandle)
	mtlr	p1
	addi	p1, p0, _PPC_ESF_REG_BASE	/* pass REG_SET to P1 */
	blrl	/* do exception processing */
FUNC_END(wdbDbgHwBpStub)

#endif	/* DBG_HARDWARE_BP */
