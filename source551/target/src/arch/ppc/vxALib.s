/* vxALib.s - miscellaneous assembly language routines */

/* Copyright 1984-2002 Wind River Systems, Inc. */
	.data
	.globl	copyright_wind_river
	.long	copyright_wind_river

/*
modification history 
--------------------
03e,18jun03,mil  Fixed build error with Diab.
03d,21feb03,dtr  Adding vxHid1Set function fixed timebase function 
	         compilation error.
03c,02dec02,mil  Updated for PPC85XX.
03b,03sep02,dtr  Wrap #ifndef around some insructions not available for 85XX.
03a,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
02z,09may02,dtr  Adding vxPlprcrSet function for SPR34619.
02y,24apr02,pch  add sync instructions in vxMemProbeSup() to ensure exception
                 is detected before function returns
02x,19apr02,pch  SPR 73195
02w,17apr02,jtp  Fix SPR 73662. remove PPC440 vxDecReload declaration.
	         Apply FUNC_BEGIN/FUNC_END throughout
02v,12dec01,kab  Added vxImmr*Get routines to return ISB and DEV.
02u,03dec01,sn   Moved save/restore functions to target/src/tool/common
02t,24oct01,jtp  Added 440 Decrementer Interrupt support
02s,22oct01,dtr  Fix for SPR65678. Code for PPC860 should lock/unlock keyed
                 registers due to board lock up/register corruption. S/W fix
                 for h/w problem.
02r,08oct01,mil  modified workaround for 750CX/CXe erratum #16 for stwcx. wrong
                 store (SPR 65319).
02q,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
02p,15aug01,pch  Add PPC440 support
02o,29may01,pch  Fix for IBM 750CX errata #16 (SPR 65319)
02n,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
02m,17apr01,dat  65984, portable C Code, added vxDecReload, vxHid1Get
02l,04dec00,s_m  updated due to changes in ppc405.h
02k,25oct00,s_m  renamed PPC405 cpu types
02j,18oct00,s_m  fixed reading of timebase for PPC405
02i,06oct00,sm   PPC405 support
02h,14mar00,tam  added vxMdCtrSet/Get, vxMiCtrSet/Get and vxMTwbGet
02g,22feb00,jgn  update global syms to use GTEXT & GDATA
02f,24mar99,tpr  added PowerPC 555 and 509 support.
02e,18aug98,tpr  added PowerPC EC 603 support.
02d,01aug97,mas  added eieio ordering to vxTas() (SPR 9061).
02c,22jul97,tpr  added sync instruction arround HID0 modification (SPR #8976)
02b,14jul97,mas  added support for DAR, DSISR, SRR0 and SRR1 regs (SPR 8918).
02a,28mar97,tam  added some DMA register access routines (PPC403 specific).
01z,10feb97,tam  added vxFpscrGet/Set() functions.
01y,23oct96,tam  added vxPowerDown() to enable power management. 
01x,08nov96,mas  changed sync to isync in vxMemProbeSup (SPR 7444).
01w,29jul96,jds  added vxEieio() to enforce in-order execution for drivers
01v,18jun96,tam  added PPC403 specific routines to access debug register.
01u,17jun96,tpr  added vxDerGet() and vxDerSet() for PPC860
		 added vxImmrGet() and vxImmrSet().
01t,29may96,tam  changed code and fixed typo error for vxTimeBaseGet() 
		 (spr #6614). Added PPC403 support for vxTimeBaseGet/Set.
01s,13may96,ms   vxPvrGet no longer masks off lower bits
01r,08mar96,tam  added forward declarations for PPC403. Added function 
		 vxBesrSet ().
01q,29feb96,kkk  added vxHid0[GS]et() for PPC601.
01p,27feb96,ms   removed vxMemProbeTrap. Made "vmpxx" global.
01o,23feb96,tpr  added vxHid0Set() and vxPvrGet().
01n,14feb96,tpr  split PPC603 and PPC604.
01m,07dec95,kvk  added vxTas().
01l,09oct95,tpr  added vxGhsFlagSet().
01k,24sep95,tpr  added vxHid0Get ().
01j,03aug95,caf  no longer modify machine state register in vxFitIntEnable().
01i,22jun95,caf  cleanup of register save/restore routines.
01h,27apr95,caf  removed vxDecIntEnable().
01g,29mar95,caf  added register save/restore routine names in order
		 to satisfy both Diab Data and Green Hills tools.
		 removed #ifndef _GREEN_TOOL.
01f,22mar95,caf  added register save/restore routines, courtesy Diab Data.
01e,09feb95,yao  fixed vxMemProbeTrap for PPC403.
01d,03feb95,caf  cleanup.
01c,19jan95,yao  added vxFirstBit(), vxExisrGet(), vxExisrClear(),
		 vxExier{G,S}et(), vxDccr{G,S}et(), vxIccr{G,S}et(), 
		 vxIocr{G,S}et(), vxEvpr{G,S}et() for 403. added vxMsrGet ()
		 for debugging popourse.  changed to use m{t,f}tb[u] mnemonics.
		 forced tbl to zero before setting the timer base.
01b,10oct94,yao  added vxMemProbeSup, vxMemProbeTrap.
01a,02jun94,yao  written.
*/

/*
DESCRIPTION
This module contains miscellaneous VxWorks support routines.

SEE ALSO: vxLib
*/

#define PPC750CX_ERRATUM_16_STWCX    /* IBM PPC750CX/CXe DD2.0-2.3 erratum #16
                                      * stwcx. after snoop hit may store wrong
                                      * data. As cost to eval PVR might be
                                      * higher using static workaround for now
                                      */

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "arch/ppc/excPpcLib.h"
	
#if	(CPU == PPC860)	/* necessary to prevent name clashes */
#define PLPRCR_OFFSET 0x284 /* see MPC860 Users Manual */
#endif	/* CPU == PPC860 */

	FUNC_EXPORT(vxTimeBaseSet)
	FUNC_EXPORT(vxTimeBaseGet)
	FUNC_EXPORT(vxMemProbeSup)
	FUNC_EXPORT(vxMsrGet)
	FUNC_EXPORT(vxMsrSet)
#if (CPU == PPC85XX)
	FUNC_EXPORT(vxDearGet)
	FUNC_EXPORT(vxDearSet)
	FUNC_EXPORT(vxCsrr0Get)
	FUNC_EXPORT(vxCsrr0Set)
	FUNC_EXPORT(vxCsrr1Get)
	FUNC_EXPORT(vxCsrr1Set)
	FUNC_EXPORT(vxMcsrr0Get)
	FUNC_EXPORT(vxMcsrr0Set)
	FUNC_EXPORT(vxMcsrr1Get)
	FUNC_EXPORT(vxMcsrr1Set)
	FUNC_EXPORT(vxSpefscrGet)
	FUNC_EXPORT(vxSpefscrSet)
	FUNC_EXPORT(vxDecarSet)
	FUNC_EXPORT(vxL1CSR0Get)
	FUNC_EXPORT(vxL1CSR0Set)
	FUNC_EXPORT(vxL1CSR1Get)
	FUNC_EXPORT(vxL1CSR1Set)
	FUNC_EXPORT(vxL1CFG0Get)
	FUNC_EXPORT(vxL1CFG1Get)
#else  /* CPU == PPC85XX */
	FUNC_EXPORT(vxDarGet)
	FUNC_EXPORT(vxDarSet)
	FUNC_EXPORT(vxDsisrGet)
	FUNC_EXPORT(vxDsisrSet)
#endif  /* CPU == PPC85XX */
	FUNC_EXPORT(vxSrr0Get)
	FUNC_EXPORT(vxSrr0Set)
	FUNC_EXPORT(vxSrr1Get)
	FUNC_EXPORT(vxSrr1Set)
	FUNC_EXPORT(vxPvrGet)
	FUNC_EXPORT(vxFirstBit)
	FUNC_EXPORT(vxEieio)
	FUNC_EXPORT(vxPowerDown)

#if	((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
         (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	 (CPU == PPC405F))
	FUNC_EXPORT(vxFpscrGet)
	FUNC_EXPORT(vxFpscrSet)
#endif	/* ((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
            (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604)) */

#if     ((CPU == PPC601) || (CPU == PPC603) || (CPU == PPCEC603) || \
	 (CPU == PPC604) || (CPU == PPC85XX))
	FUNC_EXPORT(vxHid0Get)
	FUNC_EXPORT(vxHid0Set)
	FUNC_EXPORT(vxHid1Get)
	FUNC_EXPORT(vxHid1Set)
#endif /* CPU == PPC6xx, PPC85XX */

	FUNC_EXPORT(vxGhsFlagSet)
	FUNC_EXPORT(vxTas)
	FUNC_EXPORT(vmpxx)

#if	((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
         (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	 (CPU == PPC860) || (CPU == PPC440) || (CPU == PPC85XX))
	FUNC_EXPORT(vxDecSet)
	FUNC_EXPORT(vxDecGet)
#endif	/* ((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
            (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	    (CPU == PPC860) || (CPU == PPC440) || (CPU == PPC85XX)) */

#if	((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
         (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	 (CPU == PPC860))
	FUNC_EXPORT(vxDecReload)
#endif	/* ((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
            (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	    (CPU == PPC860)) */
	
#if     (CPU == PPC860 )
	FUNC_EXPORT(vxKeyedDecReload)
	FUNC_EXPORT(vxPlprcrSet)	/* Set the PLPRCR memory based register */
#endif  /* CPU==PPC860 */
	
#if	((CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F) || \
	 (CPU == PPC440) || (CPU == PPC85XX))
# if	 ((CPU == PPC440) || (CPU == PPC85XX))
	FUNC_EXPORT(vxDbcr2Get)
	FUNC_EXPORT(vxDbcr2Set)
	FUNC_EXPORT(vxDecIntEnable)
	FUNC_EXPORT(vxDecIntAck)
# else	/* CPU == PPC440 */
	FUNC_EXPORT(vxPitSet)
	FUNC_EXPORT(vxPitGet)
	FUNC_EXPORT(vxPitIntEnable)
	FUNC_EXPORT(vxPitIntAck)
# endif	/* CPU == PPC440 */
	FUNC_EXPORT(vxFitIntEnable)
	FUNC_EXPORT(vxFitIntDisable)
	FUNC_EXPORT(vxFitIntAck)
# if     (CPU == PPC403)
	FUNC_EXPORT(vxExisrGet)
	FUNC_EXPORT(vxExisrClear)
	FUNC_EXPORT(vxExierGet)
	FUNC_EXPORT(vxExierSet)
# endif /* (CPU == PPC403) */
# ifndef PPC_NO_REAL_MODE
	FUNC_EXPORT(vxDccrGet)
	FUNC_EXPORT(vxDccrSet)
	FUNC_EXPORT(vxIccrGet)
	FUNC_EXPORT(vxIccrSet)
# endif	/* PPC_NO_REAL_MODE */
# ifdef IVPR
	FUNC_EXPORT(vxIvprGet)
	FUNC_EXPORT(vxIvprSet)
# else	/* IVPR */
	FUNC_EXPORT(vxEvprGet)
	FUNC_EXPORT(vxEvprSet)
# endif	/* IVPR */
# if     (CPU == PPC403)
	FUNC_EXPORT(vxIocrSet)
	FUNC_EXPORT(vxIocrGet)
# endif /* (CPU == PPC403) */
	FUNC_EXPORT(vxTcrGet)
	FUNC_EXPORT(vxTcrSet)
	FUNC_EXPORT(vxTsrGet)
	FUNC_EXPORT(vxTsrSet)
# if     (CPU == PPC403)
	FUNC_EXPORT(vxBesrSet)
	FUNC_EXPORT(vxDbcrGet)
	FUNC_EXPORT(vxDbcrSet)
# elif	((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
	 (CPU == PPC85XX))
	FUNC_EXPORT(vxDbcr0Get)
	FUNC_EXPORT(vxDbcr0Set)
	FUNC_EXPORT(vxDbcr1Get)
	FUNC_EXPORT(vxDbcr1Set)
# if	 ((CPU == PPC440) || (CPU == PPC85XX))
	FUNC_EXPORT(vxDbcr2Get)
	FUNC_EXPORT(vxDbcr2Set)
# endif	/* CPU == PPC440, PPC85XX */
# endif /* (CPU == PPC403 : PPC405 || PPC405F || PPC440 || PPC85XX */
	FUNC_EXPORT(vxDbsrGet)
	FUNC_EXPORT(vxDbsrClear)
	FUNC_EXPORT(vxDac1Get)
	FUNC_EXPORT(vxDac1Set)
	FUNC_EXPORT(vxDac2Get)
	FUNC_EXPORT(vxDac2Set)
	FUNC_EXPORT(vxIac1Get)
	FUNC_EXPORT(vxIac1Set)
	FUNC_EXPORT(vxIac2Get)
	FUNC_EXPORT(vxIac2Set)
# if     ((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440))
        FUNC_EXPORT(vxIac3Get)
        FUNC_EXPORT(vxIac3Set)
        FUNC_EXPORT(vxIac4Get)
        FUNC_EXPORT(vxIac4Set)
# endif /* ((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440)) */
# if 	(CPU == PPC403)
	FUNC_EXPORT(vxDmacrSet)
	FUNC_EXPORT(vxDmacrGet)
	FUNC_EXPORT(vxDmasrSet)
	FUNC_EXPORT(vxDmasrGet)
	FUNC_EXPORT(vxDmaccSet)
	FUNC_EXPORT(vxDmaccGet)
	FUNC_EXPORT(vxDmactSet)
	FUNC_EXPORT(vxDmactGet)
	FUNC_EXPORT(vxDmadaSet)
	FUNC_EXPORT(vxDmadaGet)
	FUNC_EXPORT(vxDmasaSet)
	FUNC_EXPORT(vxDmasaGet)
# endif	/* (CPU == PPC403) */
#endif	/* CPU == PPC4xx, PPC85XX */

#if	((CPU == PPC555) || (CPU == PPC860))
	FUNC_EXPORT(vxImmrSet)		/* Set the IMMR register */
	FUNC_EXPORT(vxImmrGet) 		/* Get the IMMR register */
#endif	/* ((CPU == PPC555) || (CPU == PPC860)) */

#if	((CPU == PPC555) || (CPU == PPC860) || \
	 (CPU == PPC603) || (CPU == PPC604) || (CPU == PPC85XX))
	FUNC_EXPORT(vxImmrIsbGet)	/* Get ISB bits of IMMR */
	FUNC_EXPORT(vxImmrDevGet)	/* Get PART/MASK bits of IMMR */
#endif	/* ((CPU == PPC555 || PPC860) || PPC603) || PC604)) */


#if	((CPU == PPC509) || (CPU == PPC860))
	FUNC_EXPORT(vxIcCstSet)		/* Set the IC_CST register */
	FUNC_EXPORT(vxIcCstGet)		/* Get the IC_CST register */
	FUNC_EXPORT(vxIcAdrSet)		/* Set the IC_ADR register */
	FUNC_EXPORT(vxIcDatGet)		/* Get the IC_DAT register */
#endif	/* ((CPU == PPC509) || (CPU == PPC860)) */

#if	(CPU == PPC555)
	FUNC_EXPORT(vxImemBaseSet)	/* Set the internal memory base addr */
	FUNC_EXPORT(vxImemBaseGet) 	/* Get the internal memory base addr */
#endif	/* (CPU == PPC555) */

#if	(CPU == PPC860)
	FUNC_EXPORT(vxDerSet)		/* Set the DER register */
	FUNC_EXPORT(vxDerGet)		/* Get the DER register */
	FUNC_EXPORT(vxMTwbSet)		/* Set the M_TWB register */
	FUNC_EXPORT(vxMTwbGet)		/* Get the M_TWB register */
	FUNC_EXPORT(vxMdCtrSet)		/* Set the MD_CTR register */
	FUNC_EXPORT(vxMdCtrGet)		/* Get the MD_CTR register */
	FUNC_EXPORT(vxMiCtrSet)		/* Set the MI_CTR register */
	FUNC_EXPORT(vxMiCtrGet)		/* Get the MI_CTR register */
	FUNC_EXPORT(vxDcCstSet)		/* Set the DC_CST register */
	FUNC_EXPORT(vxDcCstGet)		/* Get the DC_CST register */
	FUNC_EXPORT(vxDcAdrSet)		/* Set the DC_ADR register */
	FUNC_EXPORT(vxDcDatGet)		/* Get the DC_DAT register */
#endif	/* (CPU == PPC860) */

	.extern	VAR_DECL(vxPowMgtEnable) /* power management status */
#if (CPU == PPC860)
	.extern VAR_DECL(vx860KeyedRegUsed) /* ppc keyed reg used for bsps with */
#endif
	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* vxTas - this routine performs the atomic test and set for the PowerPC arch.
*
* RETURN: None.
*/

FUNC_BEGIN(vxTas)
	lis	r4, 0x8000	/* set the upper bit of r4 */
#ifdef PPC750CX_ERRATUM_16_STWCX
        sync                    /* SPR 65319:  empty L1 store queues
                                 * to ensure they are not full when stwcx.
                                 * executes.  The next lwarx might cause
                                 * one L1 store queue to fill (dirty blk
                                 * replacement) but another should be
                                 * empty.
                                 * ****************************************
                                 * **** Future code change might need  ****
                                 * **** to replace sync with eieio and ****
                                 * **** add sync closer to stwcx.      ****
                                 * ****************************************
                                 */
#else
        eieio                   /* simple ordered store using eieio */
#endif  /* PPC750CX_ERRATUM_16_STWCX */
	lwarx	r5, 0, r3	/* load and reserve */
	cmpwi	r5, 0		/* done if word */
	bne	vxTasEnd	/* not equal to 0 */

	stwcx.	r4, 0, r3	/* try to store non-zero */
	eieio			/* preserve load/store order */
	bne-	vxTas
	li	r3, 0x01
	blr
vxTasEnd:
	li	r3, 0
	blr
FUNC_END(vxTas)

/*******************************************************************************
*
* vxMsrGet - this routine returns the content of msr
*
* RETURN: content of msr.
*/

FUNC_BEGIN(vxMsrGet)
	mfmsr	p0			/* read msr */
	blr
FUNC_END(vxMsrGet)

/*******************************************************************************
*
* vxMsrSet - this routine returns the content of msr
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxMsrSet)
	mtmsr	p0			/* set msr */
	isync
	blr
FUNC_END(vxMsrSet)

#if (CPU == PPC85XX)

/***************************************************************************
*
* vxDearGet - this routine returns the content of DEAR
*
* RETURNS: content of DEAR
*
*/

FUNC_BEGIN(vxDearGet)
        mfspr   p0, DEAR
        blr
FUNC_END(vxDearGet)

/***************************************************************************
*
* vxDearSet - this routine sets the content of DEAR
*
* RETURNS: none
*
*/

FUNC_BEGIN(vxDearSet)
        mtspr   DEAR, p0
        blr
FUNC_END(vxDearSet)

/***************************************************************************
*
* vxCsrr0Get - this routine returns the content of CSRR0
*
* RETURNS: content of CSRR0
*
*/

FUNC_BEGIN(vxCsrr0Get)
        mfspr   p0, CSRR0
        blr
FUNC_END(vxCsrr0Get)

/***************************************************************************
*
* vxCsrr0Set - this routine sets the content of CSRR0
*
* RETURNS: none
*
*/

FUNC_BEGIN(vxCsrr0Set)
        mtspr   CSRR0, p0
        blr
FUNC_END(vxCsrr0Set)

/***************************************************************************
*
* vxCsrr1Get - this routine returns the content of CSRR1
*
* RETURNS: content of CSRR1
*
*/

FUNC_BEGIN(vxCsrr1Get)
        mfspr   p0, CSRR1
        blr
FUNC_END(vxCsrr1Get)

/***************************************************************************
*
* vxCsrr1Set - this routine sets the content of CSRR1
*
* RETURNS: none
*
*/

FUNC_BEGIN(vxCsrr1Set)
        mtspr   CSRR1, p0
        blr
FUNC_END(vxCsrr1Set)

/***************************************************************************
*
* vxMcsrr0Get - this routine returns the content of MCSRR0
*
* RETURNS: content of MCSRR0
*
*/

FUNC_BEGIN(vxMcsrr0Get)
        mfspr   p0, MCSRR0
        blr
FUNC_END(vxMcsrr0Get)

/***************************************************************************
*
* vxMcsrr0Set - this routine sets the content of MCSRR0
*
* RETURNS: none
*
*/

FUNC_BEGIN(vxMcsrr0Set)
        mtspr   MCSRR0, p0
        blr
FUNC_END(vxMcsrr0Set)

/***************************************************************************
*
* vxMcsrr1Get - this routine returns the content of MCSRR1
*
* RETURNS: content of MCSRR1
*
*/

FUNC_BEGIN(vxMcsrr1Get)
        mfspr   p0, MCSRR1
        blr
FUNC_END(vxMcsrr1Get)

/***************************************************************************
*
* vxMcsrr1Set - this routine sets the content of MCSRR1
*
* RETURNS: none
*
*/

FUNC_BEGIN(vxMcsrr1Set)
        mtspr   MCSRR1, p0
        blr
FUNC_END(vxMcsrr1Set)

/***************************************************************************
*
* vxSpefscrGet - this routine returns the content of SPEFSCR
*
* RETURNS: content of SPEFSCR
*
*/

FUNC_BEGIN(vxSpefscrGet)
        mfspr   p0, SPEFSCR
        blr
FUNC_END(vxSpefscrGet)

/***************************************************************************
*
* vxSpefscrSet - this routine sets the content of SPEFSCR
*
* RETURNS: none
*
*/

FUNC_BEGIN(vxSpefscrSet)
        mtspr   SPEFSCR, p0
        blr
FUNC_END(vxSpefscrSet)

/***************************************************************************
*
* vxDecarSet - this routine sets the content of the DECAR register
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxDecarSet)
	mtspr	DECAR,p0			/* set DECAR */
	blr
FUNC_END(vxDecarSet)

/***************************************************************************
*
* vxL1CSR0Get - this routine sets the content of the L1CSR0 register
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxL1CSR0Get)
	mfspr	p0,L1CSR0			/* get L1CSR0 */
	blr
FUNC_END(vxL1CSR0Get)

/***************************************************************************
*
* vxL1CSR0Set - this routine sets the content of the L1CSR0 register
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxL1CSR0Set)
	mtspr	L1CSR0,p0			/* set L1CSR0 */
	blr
FUNC_END(vxL1CSR0Set)

/***************************************************************************
*
* vxL1CSR1Get - this routine sets the content of the L1CSR0 register
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxL1CSR1Get)
	mfspr	p0,L1CSR1			/* get L1CSR1 */
	blr
FUNC_END(vxL1CSR1Get)

/***************************************************************************
*
* vxL1CSR1Set - this routine sets the content of the L1CSR0 register
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxL1CSR1Set)
	mtspr	L1CSR1,p0			/* set L1CSR1 */
	blr
FUNC_END(vxL1CSR1Set)

/***************************************************************************
*
* vxL1CFG0Get - this routine gets the content of the L1CRG0 register
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxL1CFG0Get)
	mfspr	p0,L1CFG0			/* get L1CFG0 */
	blr
FUNC_END(vxL1CFG0Get)

/***************************************************************************
*
* vxL1CFG1Get - this routine sets the content of the L1CFG1 register
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxL1CFG1Get)
	mfspr	p0,L1CFG1			/* get L1CSR1 */
	blr
FUNC_END(vxL1CFG1Get)

#elif ((CPU != PPC403) && (CPU != PPC405) && \
       (CPU != PPC440))                         /* CPU==PPC85XX */

/*******************************************************************************
*
* vxDarGet - this routine returns the content of DAR
*
* RETURN: content of dar.
*/
FUNC_BEGIN(vxDarGet)
        mfdar   p0
        blr
FUNC_END(vxDarGet)

/*******************************************************************************
*
* vxDarSet - this routine modifies the content of DAR
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxDarSet)
        mtdar   p0
        blr
FUNC_END(vxDarSet)

/*******************************************************************************
*
* vxDsisrGet - this routine returns the content of DSISR
*
* RETURN: content of dsisr.
*/
FUNC_BEGIN(vxDsisrGet)
        mfdsisr p0
        blr
FUNC_END(vxDsisrGet)

/*******************************************************************************
*
* vxDsisrSet - this routine modifies the content of DSISR
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxDsisrSet)
        mtdsisr p0
        blr
FUNC_END(vxDsisrSet)

#endif  /* CPU == PPC85XX, PPC403, PPC405, PPC440 */

/*******************************************************************************
*
* vxSrr0Get - this routine returns the content of SRR0
*
* RETURN: content of srr0.
*/
FUNC_BEGIN(vxSrr0Get)
        mfsrr0  p0
        blr
FUNC_END(vxSrr0Get)

/*******************************************************************************
*
* vxSrr0Set - this routine modifies the content of SRR0
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxSrr0Set)
        mtsrr0  p0
        blr
FUNC_END(vxSrr0Set)

/*******************************************************************************
*
* vxSrr1Get - this routine returns the content of SRR1
*
* RETURN: content of srr1.
*/
FUNC_BEGIN(vxSrr1Get)
        mfsrr1  p0
        blr
FUNC_END(vxSrr1Get)

/*******************************************************************************
*
* vxSrr1Set - this routine modifies the content of SRR1
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxSrr1Set)
        mtsrr1  p0
        blr
FUNC_END(vxSrr1Set)

/*******************************************************************************
*
* vxFirstBit - this routine returns the first bit set in the register
*
* RETURN: the number of first bit set.
*/
FUNC_BEGIN(vxFirstBit)
	cntlzw	p0, p0				/* first bit set count in p0 */
	blr
FUNC_END(vxFirstBit)

/******************************************************************************
*
* vxPvrGet - Get the processor type from the Processor Version Register
*/

FUNC_BEGIN(vxPvrGet)
	mfspr	p0, PVR
	blr
FUNC_END(vxPvrGet)


	
/******************************************************************************
*
* vxEieio - Execute the eieio instruction to enforce in-order execution
*
* This routine is useful for drivers that try to write I/O registers and
* the registers have an inherent order dependency.
* 
* RETURN: N/A.
*/

FUNC_BEGIN(vxEieio)
	eieio	
	blr
FUNC_END(vxEieio)

/*******************************************************************************
*
* vxPowerDown - turn the processor in reduced power mode
*
* This routine activates the reduced power mode if power management is enabled.
* It is called by the scheduler when the kernel enters the iddle loop.
* The power management mode is selected via the routine vxPowerModeSet().
*
* RETURNS: OK, or ERROR if power management is not supported, or external
* interrupts are disabled.
*
* SEE ALSO: vxPowerModeSet(), vxPowerModeGet().

* STATUS vxPowerDown (void)

*/

FUNC_BEGIN(vxPowerDown)
#if     ((CPU == PPC555) || (CPU == PPC603) || (CPU == PPCEC603) || \
         (CPU == PPC604) || (CPU == PPC860))

	/* test if power management is enabled */

	lis	p0, HIADJ(vxPowMgtEnable)
	lwz	p0, LO(vxPowMgtEnable)(p0)
	cmpwi	p0, TRUE		/* test vxPowMgtEnable == TRUE */
	bne	powerExitOk		/* exit without setting POW bit */
	
	/* test if external interrupt are enabled */

powerEnable:
	mfmsr	p1			/* load p1 with MSR register val */
	rlwinm.	p0, p1, 0, _PPC_MSR_BIT_EE, _PPC_MSR_BIT_EE 
	bne	powerDownGo
	li	p0, -1			/* returns ERROR : external interrupt */
	blr				/* are disabled. */

	/* set MSR(POW) bit */

powerDownGo:
	sync				/* synchronize */
	oris	p1, p1, _PPC_MSR_POW_U	/* set POW bit of MSR */ 
	mtmsr	p1
	isync				/* synchronize */

powerExitOk:
	li	p0, 0			/* returns OK */
	blr

#else	/* CPU==PPC555||CPU==PPC603||CPU==PPCEC603||CPU==PPC604||CPU==PPC860 */

	li      p0, -1                  /* returns ERROR: power management */
	blr				/* is not supported */

#endif	/* CPU==PPC555||CPU==PPC603||CPU==PPCEC603||CPU==PPC604||CPU==PPC860 */
FUNC_END(vxPowerDown)

#if	((CPU == PPC601) || (CPU == PPC603) || (CPU == PPCEC603) || \
	 (CPU == PPC604) || (CPU == PPC85XX))
/*******************************************************************************
*
* vxHid0Set - this routine Set the content of HID0
*/

FUNC_BEGIN(vxHid0Set)
# if	(CPU == PPC604)
	sync
# endif	/* (CPU == PPC604) */
	mtspr	HID0,p0
# if	(CPU == PPC604)
	sync
# endif	/* (CPU == PPC604) */
	blr
FUNC_END(vxHid0Set)

/*******************************************************************************
*
* vxHid0Get - this routine returns the content of HID0
*/

FUNC_BEGIN(vxHid0Get)
	mfspr	p0,HID0
	blr
FUNC_END(vxHid0Get)

/*******************************************************************************
*
* vxHid1Set - this routine Set the content of HID0
*/

FUNC_BEGIN(vxHid1Set)
# if	(CPU == PPC604)
	sync
# endif	/* (CPU == PPC604) */
	mtspr	HID1,p0
# if	(CPU == PPC604)
	sync
# endif	/* (CPU == PPC604) */
	blr
FUNC_END(vxHid1Set)

/*******************************************************************************
*
* vxHid1Get - this routine returns the content of HID1
*/

FUNC_BEGIN(vxHid1Get)
	mfspr	p0,HID1
	blr
FUNC_END(vxHid1Get)

#endif	/* CPU == PPC601, PPC603, PPC604, PPC85XX */

#if	((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
         (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	 (CPU == PPC405F))
/*******************************************************************************
*
* vxFpscrSet - this routine Set the content of FPSCR
*
* RETURN: N/A
*/

FUNC_BEGIN(vxFpscrSet)
	addi	sp, sp, -16		/* reserve some stack */
	stw	p0, 4(sp)		/* push param on the stack */
	li	p0, 0
	stw	p0, 0(sp)		/* clear other half of dword */
	stfd	fr0, 8(sp)		/* push fr0 */
	lfd	fr0, 0(sp)
	mtfsf	255, fr0
	lfd	fr0, 8(sp)		/* pop fr0 */
	addi	sp, sp, +16		/* clean up stack */
	blr
FUNC_END(vxFpscrSet)

/*******************************************************************************
*
* vxFpscrGet - this routine returns the content of FPSCR
*
* RETURN: value of the floating point status and control register (FPSCR).
*/

FUNC_BEGIN(vxFpscrGet)
	addi	sp, sp, -16		/* reserve some stack */
	stfd	fr0, 8(sp)		/* push fr0 */
	mffs	fr0
	stfd	fr0, 0(sp)		/* push FPSCR on the stack */
	lwz	p0, 4(sp)
	lfd	fr0, 8(sp)		/* pop fr0 */
	addi	sp, sp, +16		/* get frame stack */
	blr
FUNC_END(vxFpscrGet)
#endif	/* ((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
            (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	    (CPU == PPC405F)) */

/*******************************************************************************
*
* vxTimeBaseSet - set time base
*
* This routine set the time base.  Register p0 has the upper 32 bit value
* and p1 has the lower 32 bit. For CPU==PPC860 the option of locking the key
* registers is there. In this case it is also done in a interrupt handler
* so it needs to interrupt safe. As the routine isn't called that often it's 
* not that wasteful. 
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxTimeBaseSet)
	li      p2, 0
#if 	((CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F))
	mtspr	TBLO, p2		/* set TBLO to zero, preventing carry */
	mtspr	TBHI, p0		/* set TBHI */
	mtspr	TBLO, p1		/* set TBLO */
#elif	((CPU == PPC440) || (CPU == PPC85XX))
	mtspr	TBL_W, p2		/* set TBLO to zero, preventing carry */
	mtspr	TBU_W, p0		/* set TBHI */
	mtspr	TBL_W, p1		/* set TBLO */
#else	/* CPU == PPC4xx, PPC85XX */
# if	(CPU == PPC860)
	lis	p5, HIADJ(vx860KeyedRegUsed)
	lwz	p5, LO(vx860KeyedRegUsed)(p5)
	cmpwi	p5, TRUE		/* test  == TRUE */
        bne	vxTimeStateSetStandard  /* branch to normal non keyed reg use */
	mfspr   p4, IMMR		/* move IMMR register to P4 */
	rlwinm  p4, p4, 0, 0, 15	/* the address should be 64K aligned */
        lis     p3, HIADJ(  0x55CCAA33 ) /* KEYED_REG_UNLOCK_VALUE */
        addi    p3, p3, LO( 0x55CCAA33 ) /* KEYED_REG_UNLOCK_VALUE */
	lis     p5, HIADJ(  ~0x55CCAA33 ) /* KEYED_REG_LOCK_VALUE */
        addi    p5, p5, LO( ~0x55CCAA33 ) /* KEYED_REG_LOCK_VALUE */
	mfmsr	p6			/* read msr to p0 */
	INT_MASK(p6,p7)	/* unset ee bit */
	mtmsr	p7			/* disable interrupt */
	sync
        stw     p3, 0x30C(p4) /* unlock TB registers*/
	isync
	mttbl   p2                      /* force TBL to zero */
	mttbu   p0                      /* set TBU */
	mttbl   p1                      /* set TBL */
        stw     p5, 0x30C(p4) /* unlock TB register*/
	mtmsr	p6			/* enable interrupt */
	sync
	blr
vxTimeStateSetStandard:	
# endif	/* CPU == PPC860 */
	mttbl   p2			/* set TBL to zero, preventing carry */
	mttbu   p0			/* set TBU */
	mttbl   p1			/* set TBL */
#endif  /* CPU == PPC4xx, PPC85XX */
	blr
FUNC_END(vxTimeBaseSet)

/*******************************************************************************
*
* vxTimeBaseGet - get time base
*
* RETURN: upper 32 bit value of time in *(uint *)p0, 
*         lower 32 bit value of time in *(uint *)p1.
*/

FUNC_BEGIN(vxTimeBaseGet)

	/* Because of the possibility of a carry from TBL to TBU occurring 
	 * between reads of TBL and TBU, the following reading sequence 
	 * is necessary.
	 */

#if 	((CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F))
	mfspr	p2, TBHI                /* load from TBHI */
	mfspr	p3, TBLO                /* load from TBLO */
	mfspr	p4, TBHI                /* load from TBHI */
#elif	((CPU == PPC440) || (CPU == PPC85XX))
	mfspr	p2, TBU_R		/* load from TBHI */
	mfspr	p3, TBL_R		/* load from TBLO */
	mfspr	p4, TBU_R		/* load from TBHI */
#else	/* CPU == PPC4xx, PPC85XX */
	mftbu	p2                      /* load from TBU */
	mftb	p3                      /* load from TBL */
	mftbu	p4                      /* load from TBU */
#endif  /* CPU == PPC4xx, PPC85XX */
	cmpw	p2, p4			/* if old = new */
	bne	vxTimeBaseGet
	stw	p2, 0x0(p0)
	stw	p3, 0x0(p1)
	blr
FUNC_END(vxTimeBaseGet)

#if	((CPU == PPC440) || (CPU == PPC85XX))
/*******************************************************************************
*
* vxDecSet - set decrementer
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxDecSet)
	mtspr	DEC, p0
	mtspr	DECAR, p0	/* Also set the auto-reload register */
	blr
FUNC_END(vxDecSet)

/*******************************************************************************
*
* vxDecGet - get decrementer
*
* RETURN: the value of decrementer.
*/
FUNC_BEGIN(vxDecGet)
	mfspr	p0, DEC
	blr
FUNC_END(vxDecGet)

/*******************************************************************************
*
* vxDecIntEnable - enable decrementer timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxDecIntEnable)
        mfspr   p1, TCR
        oris    p1, p1, _PPC_TCR_DIE_U      /* set decrementerinterrupt enable */
        mtspr   TCR, p1
        mfmsr   p0                      /* read msr to p0 */
        ori     p0, p0, _PPC_MSR_EE     /* set ee bit */
        mtmsr   p0                      /* enable interrupt */
        blr
FUNC_END(vxDecIntEnable)

/*******************************************************************************
*
* vxDecIntAck - acknowledge decrementer timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxDecIntAck)
        addis    p0, r0, _PPC_TSR_DIS_U      /* load status mask bit */
        mtspr   TSR, p0                         /* clear decrementer pending bit */
        blr
FUNC_END(vxDecIntAck)
#endif /* CPU == PPC440, PPC85XX */

#if	((CPU == PPC509) || (CPU == PPC555)   || (CPU == PPC601) || \
         (CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	 (CPU == PPC860))
/*******************************************************************************
*
* vxDecSet - set decrementer
* For CPU==PPC860 the option of locking the key registers is there. 
* In this case it is also done in a interrupt handler so it needs to 
* interrupt safe. As the routine isn't called that often it's 
* not that wasteful. 
* RETURN: N/A.
*/
FUNC_BEGIN(vxDecSet)
#if  (CPU == PPC860)
	lis	p5, HIADJ(vx860KeyedRegUsed)
	lwz	p5, LO(vx860KeyedRegUsed)(p5)
	cmpwi	p5, TRUE		/* test  == TRUE */
        bne	vxDecSetStandard  /* branch to normal non keyed reg use */	
	mfspr	p1, IMMR		/* move IMMR register to P0 */
	rlwinm	p1, p1, 0, 0, 15	/* the address should be 64K aligned */
        lis     p3, HIADJ(  0x55CCAA33 ) /* KEYED_REG_UNLOCK_VALUE */
        addi    p3, p3, LO( 0x55CCAA33 ) /* KEYED_REG_UNLOCK_VALUE */
        lis     p5, HIADJ( ~0x55CCAA33 ) /* KEYED_REG_LOCK_VALUE */
        addi    p5, p5, LO( ~0x55CCAA33 ) /* KEYED_REG_LOCK_VALUE */
	mfmsr	p4			/* read msr to p0 */
        INT_MASK(p4, p2)	        /* mask ee bit */
	mtmsr	p2			/* disable interrupt */
	isync
        stw     p3, 0x30C(p1)		/* unlock TB registers. 0x30c is TBK */
        isync
        mtdec   p0 
        stw     p5, 0x30C(p1)		/* lock TB registers. 0x30c is TBK */
	mtmsr	p4			/* enable interrupt */
	blr
vxDecSetStandard:
#endif		
	mtdec	p0
	blr
FUNC_END(vxDecSet)

/*******************************************************************************
*
* vxDecGet - get decrementer
*
* RETURN: the value of decrementer.
*/
FUNC_BEGIN(vxDecGet)
	mfdec	p0
	blr
FUNC_END(vxDecGet)

/*******************************************************************************
*
* vxDecReload - reload decrementer
*
* Reload the decrementer with a multiple of input argument.  This is
* necessary to insure that a positive number is reloaded.
*
* This code is supposedly for use of the decrementer as the system clock.
* The decrementer counts down from a preset value and generates an interrupt
* when the value counts below 0.  When the interrupt is processed the
* decrementer has to be reloaded with the initial count.  However, there
* is always a delay from the time the interrupt is generated until the CPU
* enters the service routine.  The decrementer is still counting, so the reload
* has to take into account the actual current value of the decrementer.
*
* Since we could have actually missed more than one system tick, we need to
* be able to add more than a single multiple of the initial count value.
* The algorithm insures that we load a positive number into the decrementer.
* We keep track of how many initial count values we had to add to the
* decrementer.  This is the number of elapsed 'ticks' since the last time
* the counter was reloaded.  The normal value will be '1'.  If it is greater
* than one then multiple ticks have been skipped.
*
* RETURN: Returns the number of multiples added (or system 'ticks').
*/

FUNC_BEGIN(vxDecReload)
	ori	p1,p0,0x0	/* p1 = p0 */
	li	p0,0		/* p0 = 0 */
	mfdec	p2		/* p2 = decrementer */
reloadLoop:			/* do { */
	addi	p0,p0,1		/* p0 += 1 */
	add.	p2,p1,p2	/* p2 += p1 */
	blt	reloadLoop	/* } while (p2 < 0) */
	mtdec	p2		/* decrementer = p2 */
	blr			/* return p0 */
FUNC_END(vxDecReload)
#endif	/* ((CPU == PPC5xx) || (CPU==PPC60[134]) || (CPU == PPC860)) */

#if (CPU==PPC860)
/*******************************************************************************
*
* vxKeyedDecReload - reload decrementer
*
* Reload the decrementer with a multiple of input argument.  This is
* necessary to insure that a positive number is reloaded.
*
* This code is supposedly for use of the decrementer as the system clock.
* The decrementer counts down from a preset value and generates an interrupt
* when the value counts below 0.  When the interrupt is processed the
* decrementer has to be reloaded with the initial count.  However, there
* is always a delay from the time the interrupt is generated until the CPU
* enters the service routine.  The decrementer is still counting, so the reload
* has to take into account the actual current value of the decrementer.
*
* Since we could have actually missed more than one system tick, we need to
* be able to add more than a single multiple of the initial count value.
* The algorithm insures that we load a positive number into the decrementer.
* We keep track of how many initial count values we had to add to the
* decrementer.  This is the number of elapsed 'ticks' since the last time
* the counter was reloaded.  The normal value will be '1'.  If it is greater
* than one then multiple ticks have been skipped.
*
* This function also unlocks/locks the KEYED registers in addition to what 
* vxDecReload does. This is to cut down on the possibilty that the registers
* get corrupted( h/w errata ).The bsp must define USE_KEY_REGS for the timer. 
*
* RETURN: Returns the number of multiples added (or system 'ticks').
*/

FUNC_BEGIN(vxKeyedDecReload)
	ori	p1,p0,0x0	/* p1 = p0 */
	li	p0,0		/* p0 = 0 */
	mfdec	p2		/* p2 = decrementer */
keyedReloadLoop:			/* do { */
	addi	p0,p0,1		/* p0 += 1 */
	add.	p2,p1,p2	/* p2 += p1 */
	blt	keyedReloadLoop	/* } while (p2 < 0) */
	mfspr	p3, IMMR		/* move IMMR register to P0 */
	rlwinm	p3, p3, 0, 0, 15	/* the address should be 64K aligned */
        lis     p4, HIADJ(  0x55CCAA33 ) /* KEYED_REG_UNLOCK_VALUE */
        addi    p4, p4, LO( 0x55CCAA33 ) /* KEYED_REG_UNLOCK_VALUE */
        lis     p1, HIADJ(  ~0x55CCAA33 ) /* KEYED_REG_LOCK_VALUE */
        addi    p1, p1, LO( ~0x55CCAA33 ) /* KEYED_REG_LOCK_VALUE */
        stw     p4, 0x30C(p3)		/* unlock TB registers */
	isync
	mtdec	p2		/* decrementer = p2 */
        stw     p1, 0x30C(p3)   /* lock reg TB registers */	
	blr			/* return p0 */
FUNC_END(vxKeyedDecReload)

/*****************************************************************************
*
* vxPlprcrSet - Set the PLPRCR memory mapped register for LPM and 
*               reset control.
*
* Use for Errata SIU9 MPC860
*   
* vxPlpcrset (UINT32 *ImmrAddr,UINT32 value,UINT32 delay)
* 
* The delay can be calculated as follows :	
*	(delay * 16 clock cycles ) + 2
*
* RETURN :	N/A
*/

    .balign 16            /* For cache line alignment */
	
FUNC_BEGIN(vxPlprcrSet)
	stw p1,PLPRCR_OFFSET(p0)
	isync
delayLoop:
/* Note p0(IMMR address) should never be zero */
	divw p1,p0,p0  /* 13 clocks */
	addi  p2,p2,-1 /* 1 clock   */
	cmpwi p2,0     /* 1 clock   */
	bgt delayLoop  /* 1 clock   */
	blr 
FUNC_END(vxPlprcrSet)

#endif /* (CPU==PPC860) */
	
#if	((CPU == PPC403) || (CPU == PPC405) || (CPU == PPC405F) || \
	 (CPU == PPC440) || (CPU == PPC85XX))

# if	((CPU != PPC440) && (CPU != PPC85XX))
/*******************************************************************************
*
* vxPitSet - set the programmable interval timer to specified value
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxPitSet)
	mtspr	PIT, p0
	blr
FUNC_END(vxPitSet)

/*******************************************************************************
*
* vxPitGet - get the value of the programmable interval timer
*
* RETURN: the value of the programmable interval timer.
*/
FUNC_BEGIN(vxPitGet)
	mfspr	p0, PIT
	blr
FUNC_END(vxPitGet)
# endif /* CPU != PPC440, PPC85XX */

# if (CPU==PPC403)
/*******************************************************************************
*
* vxPitIntEnable - enable programmable interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxPitIntEnable)
	mfspr	p1, TCR
	oris	p1, p1, _PPC403_TCR_PIEM_U	/* set pit interrupt enable */
	mtspr	TCR, p1
	mfmsr	p0			/* read msr to p0 */
	ori	p0, p0, _PPC_MSR_EE	/* set ee bit */
	mtmsr	p0			/* enable interrupt */
	blr
FUNC_END(vxPitIntEnable)

/*******************************************************************************
*
* vxPitIntAck - acknowledge programmable interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxPitIntAck)
	oris	p0, r0, _PPC403_TSR_PISM_U	/* load status mask bit */
	mtspr 	TSR, p0				/* clear pit pending bit */
	blr
FUNC_END(vxPitIntAck)

/*******************************************************************************
*
* vxFitIntDisable - disable fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntDisable)
	mfspr	p0, TCR
	addis	p1, r0, _PPC403_TCR_FIEM_U	/* set fit interrupt enable */
	andc	p1, p0, p1		/* mask off fie bit */
	mtspr	TCR, p1
	blr
FUNC_END(vxFitIntDisable)

/*******************************************************************************
*
* vxFitIntEnable - enable fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntEnable)
	mfspr	p1, TCR
	oris	p1, p1, _PPC403_TCR_FIEM_U	/* set fit interrupt enable */
	mtspr	TCR, p1
	blr
FUNC_END(vxFitIntEnable)

/*******************************************************************************
*
* vxFitIntAck - acknowledge fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntAck)
	oris	p0, r0, _PPC403_TSR_FISM_U	/* load status mask bit */
	mtspr 	TSR, p0				/* clear fit pending bit */
	blr
FUNC_END(vxFitIntAck)

/*******************************************************************************
*
* vxDbcrGet - this routine gets DBCR register value 
*
* RETURN: debug control register value.
*/

FUNC_BEGIN(vxDbcrGet)
	mfspr	p0, DBCR	/* move dbcr to p0 */
	blr
FUNC_END(vxDbcrGet)

/*******************************************************************************
*
* vxDbcrSet - this routine sets DBCR register to a specific value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxDbcrSet)
	mtspr	DBCR, p0	/* move p0 to dbcr */
	blr
FUNC_END(vxDbcrSet)

# elif ((CPU==PPC405) || (CPU==PPC405F))
/*******************************************************************************
*
* vxPitIntEnable - enable programmable interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxPitIntEnable)
        mfspr   p1, TCR
        oris    p1, p1, _PPC405_TCR_PIEM_U      /* set pit interrupt enable */
        mtspr   TCR, p1
        mfmsr   p0                      /* read msr to p0 */
        ori     p0, p0, _PPC_MSR_EE     /* set ee bit */
        mtmsr   p0                      /* enable interrupt */
        blr
FUNC_END(vxPitIntEnable)

/*******************************************************************************
*
* vxPitIntAck - acknowledge programmable interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxPitIntAck)
        addis    p0, r0, _PPC405_TSR_PISM_U      /* load status mask bit */
        mtspr   TSR, p0                         /* clear pit pending bit */
        blr
FUNC_END(vxPitIntAck)

/*******************************************************************************
*
* vxFitIntAck - acknowledge fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntAck)
	addis	p0, r0, _PPC405_TSR_FISM_U	/* load status mask bit */
	mtspr 	TSR, p0				/* clear fit pending bit */
	blr
FUNC_END(vxFitIntAck)

/*******************************************************************************
*
* vxFitIntDisable - disable fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntDisable)
        mfspr   p0, TCR
        addis   p1, r0, _PPC405_TCR_FIEM_U      /* set fit interrupt enable */
        andc    p1, p0, p1              /* mask off fie bit */
        mtspr   TCR, p1
        blr
FUNC_END(vxFitIntDisable)

/*******************************************************************************
*
* vxFitIntEnable - enable fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntEnable)
        mfspr   p1, TCR
        oris    p1, p1, _PPC405_TCR_FIEM_U      /* set fit interrupt enable */
        mtspr   TCR, p1
        blr
FUNC_END(vxFitIntEnable)
# endif /* (CPU == PPC403) : ((CPU == PPC405) || (CPU == PPC405F)) */

# if ((CPU == PPC405) || (CPU == PPC405F) || (CPU == PPC440) || \
      (CPU == PPC85XX))
/*******************************************************************************
*
* vxDbcr0Get - this routine gets DBCR0 register value 
*
* RETURN: debug control register value.
*/

FUNC_BEGIN(vxDbcr0Get)
	mfspr	p0, DBCR0	/* move dbcr0 to p0 */
	blr
FUNC_END(vxDbcr0Get)

/*******************************************************************************
*
* vxDbcr0Set - this routine sets DBCR0 register to a specific value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxDbcr0Set)
	mtspr	DBCR0, p0	/* move p0 to dbcr0 */
	blr
FUNC_END(vxDbcr0Set)

/*******************************************************************************
*
* vxDbcr1Get - this routine gets DBCR1 register value 
*
* RETURN: debug control register value.
*/

FUNC_BEGIN(vxDbcr1Get)
	mfspr	p0, DBCR1	/* move dbcr1 to p0 */
	blr
FUNC_END(vxDbcr1Get)

/*******************************************************************************
*
* vxDbcr1Set - this routine sets DBCR1 register to a specific value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxDbcr1Set)
	mtspr	DBCR1, p0	/* move p0 to dbcr1 */
	blr
FUNC_END(vxDbcr1Set)

# if	((CPU == PPC440) || (CPU == PPC85XX))
/*******************************************************************************
*
* vxDbcr2Get - this routine gets DBCR2 register value 
*
* RETURN: debug control register value.
*/

FUNC_BEGIN(vxDbcr2Get)
	mfspr	p0, DBCR2	/* move dbcr2 to p0 */
	blr
FUNC_END(vxDbcr2Get)

/*******************************************************************************
*
* vxDbcr2Set - this routine sets DBCR2 register to a specific value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxDbcr2Set)
	mtspr	DBCR2, p0	/* move p0 to dbcr2 */
	blr
FUNC_END(vxDbcr2Set)

/*******************************************************************************
*
* vxFitIntAck - acknowledge fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntAck)
	addis	p0, r0, _PPC_TSR_FIS_U		/* load status mask bit */
	mtspr 	TSR, p0				/* clear fit pending bit */
	blr
FUNC_END(vxFitIntAck)

/*******************************************************************************
*
* vxFitIntDisable - disable fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntDisable)
        mfspr   p0, TCR
        addis   p1, r0, _PPC_TCR_FIE_U	/* set fit interrupt enable */
        andc    p1, p0, p1		/* mask off fie bit */
        mtspr   TCR, p1
        blr
FUNC_END(vxFitIntDisable)

/*******************************************************************************
*
* vxFitIntEnable - enable fixed interval timer interrupt
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxFitIntEnable)
        mfspr   p1, TCR
        oris    p1, p1, _PPC_TCR_FIE_U	/* set fit interrupt enable */
        mtspr   TCR, p1
        blr
FUNC_END(vxFitIntEnable)
# endif /* CPU == PPC440, PPC85XX */

# endif /* CPU == PPC405, PPC405F, PPC440, PPC85XX */

# if 	(CPU == PPC403)
/*******************************************************************************
*
* vxExisrGet - get external interrupt status register
*
* RETURN: value of exisr.
*/
FUNC_BEGIN(vxExisrGet)
	mfdcr	p0,EXISR  			/* read exisr to p0 */
	blr
FUNC_END(vxExisrGet)

/*******************************************************************************
*
* vxExisrClear - this routine clears the specified bit in exisr
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxExisrClear)
	mtdcr	EXISR,p0			/* clear specified bit */
	mfdcr	p0,EXISR			/* read exisr for debug */
	blr
FUNC_END(vxExisrClear)

/*******************************************************************************
*
* vxExierGet - this routine returns the value of exier
*
* RETURN: value of exier.
*/
FUNC_BEGIN(vxExierGet)
	mfdcr	p0,EXIER			/* read exier to p0 */
	blr
FUNC_END(vxExierGet)

/*******************************************************************************
*
* vxExierSet - this routine sets exier to the specified value
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxExierSet)
	mtdcr	EXIER,p0			/* set exier */
	blr
FUNC_END(vxExierSet)
# endif	/* (CPU==PPC403) */

# ifndef PPC_NO_REAL_MODE
/*******************************************************************************
*
* vxIccrGet - this routine returns the content of ICCR
*
* RETURN: value of iccr.
*/
FUNC_BEGIN(vxIccrGet)
	mfspr	p0, ICCR			/* read iccr */
	blr
FUNC_END(vxIccrGet)

/*******************************************************************************
*
* vxIccrSet - this routine sets the content of ICCR
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxIccrSet)
	mtspr	ICCR, p0			/* set iccr */
	blr
FUNC_END(vxIccrSet)
# endif	/* PPC_NO_REAL_MODE */

/*******************************************************************************
*
* vxTcrGet - this routine returns the content of TCR
*
* RETURN: value of tcr.
*/
FUNC_BEGIN(vxTcrGet)
	mfspr	p0, TCR				/* read TCR */
	blr
FUNC_END(vxTcrGet)

/*******************************************************************************
*
* vxTcrSet - this routine sets the content of TCR
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxTcrSet)
	mtspr	TCR, p0				/* write to TCR */
	blr
FUNC_END(vxTcrSet)

/*******************************************************************************
*
* vxTsrGet - this routine returns the content of TSR
*
* RETURN: value of tsr.
*/

FUNC_BEGIN(vxTsrGet)
	mfspr	p0, TSR				/* read TSR */
	blr
FUNC_END(vxTsrGet)

/*******************************************************************************
*
* vxTsrSet - this routine sets the content of TSR
*
* RETURN: N/A.
*/
FUNC_BEGIN(vxTsrSet)
	mtspr	TSR, p0				/* write to TSR */
	/* XXX mfspr	p0, TSR			/* return new TSR */
	blr
FUNC_END(vxTsrSet)

# ifndef PPC_NO_REAL_MODE
/*******************************************************************************
*
* vxDccrGet - this routine returns the content of DCCR
*
* RETURN: value of dccr.
*/

FUNC_BEGIN(vxDccrGet)
	mfspr	p0, DCCR			/* read dccr */
	blr
FUNC_END(vxDccrGet)

/*******************************************************************************
*
* vxDccrSet - this routine sets the DCCR to the specified value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxDccrSet)
	mtspr	DCCR, p0			/* write to dccr */
	blr
FUNC_END(vxDccrSet)
# endif	/* PPC_NO_REAL_MODE */

# ifdef	IVPR
/*******************************************************************************
*
* vxIvprGet - this routine returns the content of IVPR
*
* RETURN: value of IVPR.
*/

FUNC_BEGIN(vxIvprGet)
	mfspr	p0, IVPR
	blr
FUNC_END(vxIvprGet)

/*******************************************************************************
*
* vxIvprSet - this routine sets the IVPR to the specified value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxIvprSet)
	mtspr	IVPR, p0
	blr
FUNC_END(vxIvprSet)

# else /* IVPR */

/*******************************************************************************
*
* vxEvprGet - this routine returns the content of EVPR
*
* RETURN: value of evpr.
*/

FUNC_BEGIN(vxEvprGet)
	mfspr	p0, EVPR
	blr
FUNC_END(vxEvprGet)

/*******************************************************************************
*
* vxEvprSet - this routine sets the EVPR to the specified value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxEvprSet)
	mtspr	EVPR, p0
	blr
FUNC_END(vxEvprSet)
# endif /* IVPR */

# if 	(CPU == PPC403)
/*******************************************************************************
*
* vxIocrGet - this routine returns the content of IOCR
*
* RETURN: value of iocr.
*/

FUNC_BEGIN(vxIocrGet)
	mfdcr	p0, IOCR
	blr
FUNC_END(vxIocrGet)

/*******************************************************************************
*
* vxIocrSet - this routine sets the IOCR to the specified value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxIocrSet)
	mtdcr	IOCR, p0
	blr
FUNC_END(vxIocrSet)

/*******************************************************************************
*
* vxBesrSet - this routine sets the BESR to the specified value
*
* RETURN: N/A.
*/

FUNC_BEGIN(vxBesrSet)
	mtdcr   BESR, p0        /* set dbcr */
	blr
FUNC_END(vxBesrSet)
# endif	/* (CPU==PPC403) */

/*******************************************************************************
*
* vxDbsrGet - return value of debug status register
*
* RETURNS: value of debug status register. 
*/

FUNC_BEGIN(vxDbsrGet)
	mfspr	p0, DBSR	/* move dbsr to p0 */
	blr
FUNC_END(vxDbsrGet)

/*******************************************************************************
*
* vxDbsrClear - clear debug status register bits
*
* RETURNS: N/A. 
*/

FUNC_BEGIN(vxDbsrClear)
	mtspr	DBSR, p0	/* move p0 to dbsr */
	blr
FUNC_END(vxDbsrClear)

/*******************************************************************************
*
* vxDac1Get - return value of data adress compare register 1
*
* RETURNS: value of data adress compare register 1.
*/

FUNC_BEGIN(vxDac1Get)
	mfspr	p0, DAC1	/* move dac1 to p0 */
	blr
FUNC_END(vxDac1Get)

/*******************************************************************************
*
* vxDac1Set - set data adress compare register 1 to a specific value
*
* RETURNS: N/A. 
*/

FUNC_BEGIN(vxDac1Set)
	mtspr	DAC1, p0	/* move p0 to dac1 */
	blr
FUNC_END(vxDac1Set)

/*******************************************************************************
*
* vxDac2Get - return value of data adress compare register 2
*
* RETURNS: value of data adress compare register 2.
*/

FUNC_BEGIN(vxDac2Get)
	mfspr	p0, DAC2	/* move dac2 to p0 */
	blr
FUNC_END(vxDac2Get)

/*******************************************************************************
*
* vxDac2Set - set data adress compare register 2 to a specific value
*
* RETURNS: N/A. 
*/

FUNC_BEGIN(vxDac2Set)
	mtspr	DAC2, p0	/* move p0 to dac2 */
	blr
FUNC_END(vxDac2Set)

/*******************************************************************************
*
* vxIac1Get - return value of instruction adress compare register 1
*
* RETURNS: value of instruction adress compare register 1.
*/

FUNC_BEGIN(vxIac1Get)
	mfspr	p0, IAC1	/* move iac1 to p0 */
	blr
FUNC_END(vxIac1Get)

/*******************************************************************************
*
* vxIac1Set - set instruction adress compare register 1 to a specific value
*
* RETURNS: N/A. 
*/

FUNC_BEGIN(vxIac1Set)
	mtspr	IAC1, p0	/* move p0 to iac1 */
	blr
FUNC_END(vxIac1Set)

/*******************************************************************************
*
* vxIac2Get - return value of instruction adress compare register 2
*
* RETURNS: value of instruction adress compare register 2.
*/

FUNC_BEGIN(vxIac2Get)
	mfspr	p0, IAC2	/* move iac2 to p0 */
	blr
FUNC_END(vxIac2Get)

/*******************************************************************************
*
* vxIac2Set - set instruction adress compare register 2 to a specific value
*
* RETURNS: N/A. 
*/

FUNC_BEGIN(vxIac2Set)
	mtspr	IAC2, p0	/* move p0 to iac2 */
	blr
FUNC_END(vxIac2Set)

# if ((CPU==PPC405) || (CPU==PPC405F) || (CPU==PPC440))
/*******************************************************************************
*
* vxIac3Get - return value of instruction adress compare register 3
*
* RETURNS: value of instruction adress compare register 3.
*/

FUNC_BEGIN(vxIac3Get)
        mfspr   p0, IAC3        /* move iac3 to p0 */
        blr
FUNC_END(vxIac3Get)

/*******************************************************************************
*
* vxIac3Set - set instruction adress compare register 3 to a specific value
*
* RETURNS: N/A.
*/

FUNC_BEGIN(vxIac3Set)
        mtspr   IAC3, p0        /* move p0 to iac3 */
        blr
FUNC_END(vxIac3Set)

/*******************************************************************************
*
* vxIac4Get - return value of instruction adress compare register 4
*
* RETURNS: value of instruction adress compare register 4.
*/

FUNC_BEGIN(vxIac4Get)
        mfspr   p0, IAC4        /* move iac4 to p0 */
        blr
FUNC_END(vxIac4Get)

/*******************************************************************************
*
* vxIac4Set - set instruction adress compare register 4 to a specific value
*
* RETURNS: N/A.
*/

FUNC_BEGIN(vxIac4Set)
        mtspr   IAC4, p0        /* move p0 to iac4 */
        blr
FUNC_END(vxIac4Set)

# endif /* ((CPU==PPC405) || (CPU==PPC405F) || (CPU==PPC440)) */

# if	(CPU == PPC403)
/*******************************************************************************
*
* vxDmacrSet - set a DMA Channel Control register (0 to 3)
*
* This routine sets a DMA Channel Control register selected by <dmaRegNo>
* to a new value.
*
* RETURNS: N/A. 

* void vxDmacrSet
*       (
*       UINT32 regVal,		/@ value to set the register with @/
*	UINT32 dmaRegNo		/@ DMA Control register No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmacrSet)
	andi.	p1, p1, 0x3		/* p1  between 0 and 3 included */ 
	cmpwi	p1, 0x0
	beq	vxDmacr0Set
	cmpwi	p1, 0x1
	beq	vxDmacr1Set
	cmpwi	p1, 0x2
	beq	vxDmacr2Set
	cmpwi	p1, 0x3
	beq	vxDmacr3Set
	li	p1, -1			/* returns ERROR */
	blr
	
vxDmacr0Set:
	mtdcr	DMACR0, p0
	blr
vxDmacr1Set:
	mtdcr	DMACR1, p0
	blr
vxDmacr2Set:
	mtdcr	DMACR2, p0
	blr
vxDmacr3Set:
	mtdcr	DMACR3, p0
	blr
FUNC_END(vxDmacrSet)

/*******************************************************************************
*
* vxDmacrGet - return value of a DMA Channel Control register (0 to 3) 
*
* This routine returns the value of one of the 4 DMA Channel Control registers
* selected via <dmaRegNo>.
*
* RETURNS: value of a DMA Channel Control register (0 to 3).

* UINT32 vxDmacrGet
*       (
*	UINT32 dmaRegNo		/@ DMA Control register No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmacrGet)
	andi.	p0, p0, 0x3		/* p0  between 0 and 3 included */ 
	cmpwi	p0, 0x0
	beq	vxDmacr0Get
	cmpwi	p0, 0x1
	beq	vxDmacr1Get
	cmpwi	p0, 0x2
	beq	vxDmacr2Get
	cmpwi	p0, 0x3
	beq	vxDmacr3Get
	li	p0, -1			/* return ERROR */
	blr
	
vxDmacr0Get:
	mfdcr	p0, DMACR0
	blr
vxDmacr1Get:
	mfdcr	p0, DMACR1
	blr
vxDmacr2Get:
	mfdcr	p0, DMACR2
	blr
vxDmacr3Get:
	mfdcr	p0, DMACR3
	blr
FUNC_END(vxDmacrGet)

/*******************************************************************************
*
* vxDmasrSet - set DMA Channel Status register
*
* This routine sets the PPC403 DMA Channel Status register.
*
* RETURNS: N/A. 

* void vxDmasrSet
*       (
*       UINT32 regVal		/@ value to set the register with @/
*       )

*/

FUNC_BEGIN(vxDmasrSet)
	mtdcr	DMASR, p0
	blr
FUNC_END(vxDmasrSet)

/*******************************************************************************
*
* vxDmasrGet - return value of the PPC403 DMA Channel Status register
*
* RETURNS: value of the PPC403 DMA Channel Status register.

* UINT32 vxDmasrGet ()

*/

FUNC_BEGIN(vxDmasrGet)
	mfdcr	p0, DMASR
	blr
FUNC_END(vxDmasrGet)

/*******************************************************************************
*
* vxDmaccSet - set a DMA Chained Count register (0 to 3)
*
* This routine sets a DMA Chained Count register selected by <dmaRegNo>
* to a new value.
*
* RETURNS: N/A. 

* void vxDmaccSet
*       (
*       UINT32 regVal,		/@ value to set the register with @/
*	UINT32 dmaRegNo		/@ DMA Chained Count register No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmaccSet)
	andi.	p1, p1, 0x3		/* p1  between 0 and 3 included */ 
	cmpwi	p1, 0x0
	beq	vxDmacc0Set
	cmpwi	p1, 0x1
	beq	vxDmacc1Set
	cmpwi	p1, 0x2
	beq	vxDmacc2Set
	cmpwi	p1, 0x3
	beq	vxDmacc3Set
	li	p1, -1			/* returns ERROR */
	blr
	
vxDmacc0Set:
	mtdcr	DMACC0, p0
	blr
vxDmacc1Set:
	mtdcr	DMACC1, p0
	blr
vxDmacc2Set:
	mtdcr	DMACC2, p0
	blr
vxDmacc3Set:
	mtdcr	DMACC3, p0
	blr
FUNC_END(vxDmaccSet)

/*******************************************************************************
*
* vxDmaccGet - return value of a DMA Chained Count register (0 to 3)
*
* This routine returns the value of one of the 4 DMA Chained Count registers
* selected via <dmaRegNo>.
*
* RETURNS: value of a DMA Chained Count register (0 to 3).

* UINT32 vxDmaccGet
*       (
*	UINT32 dmaRegNo		/@ DMA Chained Count register No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmaccGet)
	andi.	p0, p0, 0x3		/* p0  between 0 and 3 included */ 
	cmpwi	p0, 0x0
	beq	vxDmacc0Get
	cmpwi	p0, 0x1
	beq	vxDmacc1Get
	cmpwi	p0, 0x2
	beq	vxDmacc2Get
	cmpwi	p0, 0x3
	beq	vxDmacc3Get
	li	p0, -1			/* return ERROR */
	blr
	
vxDmacc0Get:
	mfdcr	p0, DMACC0
	blr
vxDmacc1Get:
	mfdcr	p0, DMACC1
	blr
vxDmacc2Get:
	mfdcr	p0, DMACC2
	blr
vxDmacc3Get:
	mfdcr	p0, DMACC3
	blr
FUNC_END(vxDmaccGet)

/*******************************************************************************
*
* vxDmactSet - set a DMA Count register (0 to 3)
*
* This routine sets a DMA Count register selected by <dmaRegNo> to a new 
* value.
*
* RETURNS: N/A. 

* void vxDmactSet
*       (
*       UINT32 regVal,		/@ value to set the register with @/
*	UINT32 dmaRegNo		/@ DMA Count register No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmactSet)
	andi.	p1, p1, 0x3		/* p1  between 0 and 3 included */ 
	cmpwi	p1, 0x0
	beq	vxDmact0Set
	cmpwi	p1, 0x1
	beq	vxDmact1Set
	cmpwi	p1, 0x2
	beq	vxDmact2Set
	cmpwi	p1, 0x3
	beq	vxDmact3Set
	li	p1, -1			/* returns ERROR */
	blr
	
vxDmact0Set:
	mtdcr	DMACT0, p0
	blr
vxDmact1Set:
	mtdcr	DMACT1, p0
	blr
vxDmact2Set:
	mtdcr	DMACT2, p0
	blr
vxDmact3Set:
	mtdcr	DMACT3, p0
	blr
FUNC_END(vxDmactSet)

/*******************************************************************************
*
* vxDmactGet - return value of a DMA Count register (0 to 3)
*
* This routine returns the value of one of the 4 DMA Count registers
* selected via <dmaRegNo>.
*
* RETURNS: value of a DMA Count register (0 to 3).

* UINT32 vxDmactGet
*       (
*	UINT32 dmaRegNo		/@ DMA Count register No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmactGet)
	andi.	p0, p0, 0x3		/* p0  between 0 and 3 included */ 
	cmpwi	p0, 0x0
	beq	vxDmact0Get
	cmpwi	p0, 0x1
	beq	vxDmact1Get
	cmpwi	p0, 0x2
	beq	vxDmact2Get
	cmpwi	p0, 0x3
	beq	vxDmact3Get
	li	p0, -1			/* return ERROR */
	blr
	
vxDmact0Get:
	mfdcr	p0, DMACT0
	blr
vxDmact1Get:
	mfdcr	p0, DMACT1
	blr
vxDmact2Get:
	mfdcr	p0, DMACT2
	blr
vxDmact3Get:
	mfdcr	p0, DMACC3
	blr
FUNC_END(vxDmactGet)

/*******************************************************************************
*
* vxDmadaSet - set a DMA Destination Address register (0 to 3)
*
* This routine sets a DMA Destination Address register selected by <dmaRegNo>
* to a new value.
*
* RETURNS: N/A. 

* void vxDmadaSet
*       (
*       UINT32 regVal,		/@ value to set the register with @/
*	UINT32 dmaRegNo		/@ DMA Destination Address reg. No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmadaSet)
	andi.	p1, p1, 0x3		/* p1  between 0 and 3 included */ 
	cmpwi	p1, 0x0
	beq	vxDmada0Set
	cmpwi	p1, 0x1
	beq	vxDmada1Set
	cmpwi	p1, 0x2
	beq	vxDmada2Set
	cmpwi	p1, 0x3
	beq	vxDmada3Set
	li	p1, -1			/* returns ERROR */
	blr
	
vxDmada0Set:
	mtdcr	DMADA0, p0
	blr
vxDmada1Set:
	mtdcr	DMADA1, p0
	blr
vxDmada2Set:
	mtdcr	DMADA2, p0
	blr
vxDmada3Set:
	mtdcr	DMADA3, p0
	blr
FUNC_END(vxDmadaSet)

/*******************************************************************************
*
* vxDmadaGet - return value of a DMA Destination Address register (0 to 3)
*
* This routine returns the value of one of the 4 DMA Destination Address 
* registers selected via <dmaRegNo>.
*
* RETURNS: value of a DMA Destination Address register (0 to 3).

* UINT32 vxDmadaGet
*       (
*	UINT32 dmaRegNo		/@ DMA Destination Address reg. No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmadaGet)
	andi.	p0, p0, 0x3		/* p0  between 0 and 3 included */ 
	cmpwi	p0, 0x0
	beq	vxDmada0Get
	cmpwi	p0, 0x1
	beq	vxDmada1Get
	cmpwi	p0, 0x2
	beq	vxDmada2Get
	cmpwi	p0, 0x3
	beq	vxDmada3Get
	li	p0, -1			/* return ERROR */
	blr
	
vxDmada0Get:
	mfdcr	p0, DMADA0
	blr
vxDmada1Get:
	mfdcr	p0, DMADA1
	blr
vxDmada2Get:
	mfdcr	p0, DMADA2
	blr
vxDmada3Get:
	mfdcr	p0, DMADA3

	blr
FUNC_END(vxDmadaGet)

/*******************************************************************************
*
* vxDmasaSet - set a DMA Source Address register (0 to 3)
*
* This routine sets a DMA Source Address register selected by <dmaRegNo>
* to a new value.
*
* RETURNS: N/A. 

* void vxDmasaSet
*       (
*       UINT32 regVal,		/@ value to set the register with @/
*	UINT32 dmaRegNo		/@ DMA Source Address register No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmasaSet)
	andi.	p1, p1, 0x3		/* p1  between 0 and 3 included */ 
	cmpwi	p1, 0x0
	beq	vxDmasa0Set
	cmpwi	p1, 0x1
	beq	vxDmasa1Set
	cmpwi	p1, 0x2
	beq	vxDmasa2Set
	cmpwi	p1, 0x3
	beq	vxDmasa3Set
	li	p1, -1			/* returns ERROR */
	blr
	
vxDmasa0Set:
	mtdcr	DMASA0, p0
	blr
vxDmasa1Set:
	mtdcr	DMASA1, p0
	blr
vxDmasa2Set:
	mtdcr	DMASA2, p0
	blr
vxDmasa3Set:
	mtdcr	DMASA3, p0
	blr
FUNC_END(vxDmasaSet)

/*******************************************************************************
*
* vxDmasaGet - return value of a DMA Source Address register (0 to 3)
*
* This routine returns the value of one of the 4 DMA Source Address 
* registers selected via <dmaRegNo>.
*
* RETURNS: value of a DMA Source Address register (0 to 3).

* UINT32 vxDmasaGet
*       (
*	UINT32 dmaRegNo		/@ DMA Source Address register No (0 to 3) @/
*       )

*/

FUNC_BEGIN(vxDmasaGet)
	andi.	p0, p0, 0x3		/* p0  between 0 and 3 included */ 
	cmpwi	p0, 0x0
	beq	vxDmasa0Get
	cmpwi	p0, 0x1
	beq	vxDmasa1Get
	cmpwi	p0, 0x2
	beq	vxDmasa2Get
	cmpwi	p0, 0x3
	beq	vxDmasa3Get
	li	p0, -1			/* return ERROR */
	blr
	
vxDmasa0Get:
	mfdcr	p0, DMASA0
	blr
vxDmasa1Get:
	mfdcr	p0, DMASA1
	blr
vxDmasa2Get:
	mfdcr	p0, DMASA2
	blr
vxDmasa3Get:
	mfdcr	p0, DMASA3
	blr
FUNC_END(vxDmasaGet)
# endif	/* (CPU==PPC403) */

#endif	/* CPU == PPC4xx, PPC85XX */

/*******************************************************************************
*
* vxMemProbeSup - vxMemProbe support routine
*
* This routine is called to try to read byte, word, or long, as specified
* by length, from the specified source to the specified destination.
*
* NOMANUAL

STATUS vxMemProbeSup (length, src, dest)
    (
    int 	length,	// length of cell to test (1, 2, 4, 8, 16) *
    char *	src,	// address to read *
    char *	dest	// address to write *
    )

*/

FUNC_BEGIN(vxMemProbeSup)
	addi	p7, p0, 0	/* save length to p7 */
	xor	p0, p0, p0	/* set return status */
	cmpwi	p7, 1		/* check for byte access */
	bne	vmpShort	/* no, go check for short word access */
	lbz	p6, 0(p1)	/* load byte from source */
	stb	p6, 0(p2)	/* store byte to destination */
	sync			/* ensure load/store are performed */
	isync			/* enforce for immediate exception handling */
	blr
vmpShort:
	cmpwi	p7, 2		/* check for short word access */
	bne	vmpWord		/* no, check for word access */
	lhz	p6, 0(p1)	/* load half word from source */
	sth	p6, 0(p2)	/* store half word to destination */
	sync			/* ensure load/store are performed */
	isync			/* enforce for immediate exception handling */
	blr
vmpWord:
	cmpwi	p7, 4		/* check for short word access */
	bne	vmpxx		/* no, check for double word access */
	lwz	p6, 0(p1)	/* load half word from source */
	stw	p6, 0(p2)	/* store half word to destination */
	sync			/* ensure load/store are performed */
	isync			/* enforce for immediate exception handling */
	blr
vmpxx:
	/*
	 * If the access attempted above causes an exception, the handler
	 * causes us to come here and return a failure indication.  Also
	 * come here if the length parameter is not recognized.
	 */
	li	p0, -1
	blr
FUNC_END(vxMemProbeSup)

/*******************************************************************************
*
* vxGhsFlagSet - set the flag to allow print() to display floating point value
*
* This Pb is Green Hill specific.  Should be removed when Green Hill will
* be EABI compatible.
*/

FUNC_BEGIN(vxGhsFlagSet)
	creqv	6,6,6
	blr
FUNC_END(vxGhsFlagSet)

#if	((CPU == PPC555) || (CPU == PPC860))
/*******************************************************************************
*
* vxImmrSet - Set the IMMR register to a specific value
*
* This routine sets the IMMR register to a specific value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxImmrSet)
	mtspr	IMMR,p0		/* move P0 to IMMR */
	blr
FUNC_END(vxImmrSet)

/*******************************************************************************
*
* vxImmrGet - return the IMMR register value 
*
* This routine returns the IMMR register value
*
* RETURNS: IMMR register value 
*
*/

FUNC_BEGIN(vxImmrGet)
	mfspr	p0, IMMR		/* move IMMR register to P0 */
	rlwinm	p0, p0, 0, 0, 15	/* the address should be 64K aligned */
	blr
FUNC_END(vxImmrGet)

#endif	/* ((CPU == PPC555) || (CPU == PPC860)) */

#if	((CPU == PPC555) || (CPU == PPC860) || \
	 (CPU == PPC603) || (CPU == PPC604) || (CPU == PPC85XX))
/* XXX - make this a token other than CPU: _WRS_PPC_HAS_SIU or similar.
 * XXX - also reconsider where this lives; it should ideally be only
 * XXX - included in BSP's that actually need it, not on the general
 * XXX - 603/604 archive - if there is a clean way to do it. -- kab
 */
/*******************************************************************************
*
* vxImmrIsbGet - return the IMMR[ISB] register value 
*
* This routine returns the IMMR[ISB] register value.
* Although neither the PPC603 or 604 have an IMMR,
* they can have an 82xx slave SIU which does.
*
* RETURNS: IMMR[ISB] register value 
*
*/

FUNC_BEGIN(vxImmrIsbGet)
	mfspr	p0, IMMR		/* move IMMR register to P0 */
	rlwinm	p0, p0, 0, 0, 15	/* mask PART & MASK bits */
	blr
FUNC_END(vxImmrIsbGet)

/*******************************************************************************
*
* vxImmrDevGet - return the IMMR[PART+MASK] register value 
*
* This routine returns the IMMR[PART+MASK] register value.
*
* Although neither the PPC603 or 604 have an IMMR directly,
* they can have an 82xx slave which does.
* RETURNS: IMMR[PART+MASK] register value 
*
*/

FUNC_BEGIN(vxImmrDevGet)
	mfspr	p0, IMMR		/* move IMMR register to P0 */
	rlwinm	p0, p0, 0, 16, 31	/* mask ISB bits */
	blr
FUNC_END(vxImmrDevGet)

#endif	/* ((CPU == PPC555) || PPC860 || PPC603 || PPC604) */

#if	((CPU == PPC509) || (CPU == PPC860))
/*******************************************************************************
*
* vxIcCstSet - Set the IC_CST register to a specific value
*
* This routine sets the IC_CST (Instruction Cache Control and Status) register
* to a specific value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxIcCstSet)
	mtspr	IC_CST, p0	/* move PO to IC_CST */
	blr
FUNC_END(vxIcCstSet)

/*******************************************************************************
*
* vxIcCstGet - return the IC_CST register value 
*
* This routine returns the IC_CST (Instruction Cache Control and Status)
* register value
*
* RETURNS: IC_CST register value 
*
*/

FUNC_BEGIN(vxIcCstGet)
	mfspr	p0, IC_CST	/* move IC_CST to P0 */
	blr
FUNC_END(vxIcCstGet)

/*******************************************************************************
*
* vxIcAdrSet - Set the IC_ADR register to a specific value
*
* This routine sets the IC_ADR (Instruction Cache Address) register to a
* specific value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxIcAdrSet)
	mtspr	IC_ADR, p0	/* move P0 to IC_ADR */
	blr
FUNC_END(vxIcAdrSet)

/*******************************************************************************
*
* vxIcDatGet - return the IC_DAT register value 
*
* This routine returns the IC_DAT (Instruction Cache Data) register value
*
* RETURNS: IC_DAT register value 
*
*/

FUNC_BEGIN(vxIcDatGet)
	mfspr	p0, IC_DAT	/* move IC_DAT to P0 */
	blr
FUNC_END(vxIcDatGet)

#endif	/* ((CPU == PPC509) || (CPU == PPC860)) */

#if	(CPU == PPC555)
/*******************************************************************************
*
* vxImemBaseSet - Set the IMMR register's ISB bits
*
* This routine sets the IMMR register's ISB bits
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxImemBaseSet)
	rlwinm	p0, p0, 11, 28, 30	/* shift address to get ISB bits */
	mfspr	p1, IMMR		/* move IMMR register to P0 */
	rlwinm  p1, p1, 0, 31, 27	/* clear the ISB bits */
	or	p0, p0, p1		/* set new ISB bits */
	mtspr	IMMR, p0		/* move P0 to IMMR */
	blr
FUNC_END(vxImemBaseSet)


/*******************************************************************************
*
* vxImemBaseGet - return the Internal Memory Base Address
*
* This routine returns Internal Memory Base Address
*
* RETURNS: Internal Memory Base Address
*
*/

FUNC_BEGIN(vxImemBaseGet)
	mfspr	p0, IMMR		/* move IMMR register to P0 */
	rlwinm	p0, p0, 21, 7, 9	/* BA = (IMMR & 0x0e) << 21 */
	blr
FUNC_END(vxImemBaseGet)

#endif	/* (CPU == PPC555) */

#if	(CPU == PPC860)
/*******************************************************************************
*
* vxDerSet - Set the DER register to a specific value
*
* This routine sets the DER register to a specific value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxDerSet)
	mtspr	DER,p0		/* move P0 to DER */
	blr
FUNC_END(vxDerSet)

/*******************************************************************************
*
* vxDerGet - return the DER register value 
*
* This routine returns the DER register value
*
* RETURNS: DER register value 
*
*/

FUNC_BEGIN(vxDerGet)
	mfspr	p0, DER		/* move DER register to P0 */
	blr
FUNC_END(vxDerGet)

/*******************************************************************************
*
* vxMTwbSet - Set the M_TWB register to a specific value
*
* This routine sets the M_TWB (MMU TableWalk Base) register to a specific value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxMTwbSet)
	mtspr	M_TWB, p0	/* move P0 to M_TWB */
	blr
FUNC_END(vxMTwbSet)

/*******************************************************************************
*
* vxMTwbGet - return the M_TWB register value
*
* This routine returns the M_TWB (MMU TableWalk Base) register value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxMTwbGet)
	mfspr	p0, M_TWB	/* move M_TWB to P0 */
	blr
FUNC_END(vxMTwbGet)

/*******************************************************************************
*
* vxMdCtrSet - Set the MD_CTR register to a specific value
*
* This routine sets the MD_CTR register to a specific value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxMdCtrSet)
	mtspr	MD_CTR, p0	/* move P0 to MD_CTR */
	blr
FUNC_END(vxMdCtrSet)

/*******************************************************************************
*
* vxMdCtrGet - return the MD_CTR register value
*
* This routine returns the MD_CTR register value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxMdCtrGet)
	mfspr	p0, MD_CTR	/* move MD_CTR to P0 */
	blr
FUNC_END(vxMdCtrGet)

/*******************************************************************************
*
* vxMiCtrSet - Set the MI_CTR register to a specific value
*
* This routine sets the MI_CTR register to a specific value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxMiCtrSet)
	mtspr	MI_CTR, p0	/* move P0 to MI_CTR */
	blr
FUNC_END(vxMiCtrSet)

/*******************************************************************************
*
* vxMiCtrGet - return the MI_CTR register value
*
* This routine returns the MI_CTR register value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxMiCtrGet)
	mfspr	p0, MI_CTR	/* move MI_CTR to P0 */
	blr
FUNC_END(vxMiCtrGet)

/*******************************************************************************
*
* vxDcCstSet - Set the DC_CST register to a specific value
*
* This routine sets the DC_CST (Data Cache Control and Status) register to a
* specific value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxDcCstSet)
	mtspr	DC_CST, p0	/* move P0 to DC_CST */
	blr
FUNC_END(vxDcCstSet)

/*******************************************************************************
*
* vxDcCstGet - return the DC_CST register value 
*
* This routine returns the DC_CST (Data Cache Control and Status) register
* value
*
* RETURNS: DC_CST register value 
*
*/

FUNC_BEGIN(vxDcCstGet)
	mfspr	p0, DC_CST	/* move DC_CST to P0 */
	blr
FUNC_END(vxDcCstGet)

/*******************************************************************************
*
* vxDcAdrSet - Set the DC_ADR register to a specific value
*
* This routine sets the DC_ADR (Data Cache Address) register to a specific
* value 
*
* RETURNS: N/A
*/

FUNC_BEGIN(vxDcAdrSet)
	mtspr	DC_ADR, p0	/* move P0 to DC_ADR */
	blr
FUNC_END(vxDcAdrSet)

/*******************************************************************************
*
* vxDcDatGet - return the DC_DAT register value 
*
* This routine returns the DC_DAT (Data Cache Data) register value
*
* RETURNS: DC_DAT register value 
*
*/

FUNC_BEGIN(vxDcDatGet)
	mfspr	p0, DC_DAT	/* move DC_DAT to P0 */
	blr
FUNC_END(vxDcDatGet)

#endif	/* (CPU == PPC860) */	
