/* fppArchLib.c - Hitachi SH floating-point coprocessor support library */

/* Copyright 1984-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01n,05dec02,hk   restore PC and PR in case of fppExcHandle() error. (SPR#83145)
01m,10dec01,zl   removed local typedef of UINT64.
01l,11sep01,zl   replaced CPU conditionals with _WRS_HW_FP_SUPPORT.
01k,01dec00,zl   endian order in fppExcHandle() to comply with updated uss_xxx.
01j,12jul00,hk   added fppExcHandle() and fppExcFixup().
01i,28jun00,zl   added fpscrInitValue for SH7700
01h,05jun00,zl   changed default FPSCR value to support denormalized numbers
                 and use rounding to nearest policy.
01g,20mar00,zl   added extended floating point registers to the FP context.
		 removed fppReset.
01f,11aug,99zl   made __fpscr_values external (from gcclib.a) 
01e,08jun,99zl   hitachi SH4 architecture port, provided by 
                  Highlander Engineering. Initialize FPSCR.
		  Updated description to be more generic.
01d,08mar99,hk   added #if for FPU-less CPU types.
01c,15jun98,hk   implemented fppProbe().
01b,11may98,hk   paid some efforts for faster operation.
01a,26nov97,hms  written based on MC68K's fppArchLib.c
*/

/*
DESCRIPTION
This library provides the low-level interface to Hitachi SH on-chip
floating point facilities.
The routines fppTaskRegsSet() and fppTaskRegsGet() inspect and set
floating-point registers on a per task basis.  The routine fppProbe()
checks for the presence of the floating-point processor.
With the exception of fppProbe(), the higher level facilities in
dbgLib and usrLib should be used instead of these routines. 
See fppLib for architecture independent portion.

SEE ALSO: fppALib, intConnect(), Hitachi SH Hardware Manuals
*/

#include "vxWorks.h"
#include "objLib.h"
#include "taskLib.h"
#include "taskArchLib.h"
#include "memLib.h"
#include "string.h"
#include "iv.h"
#include "intLib.h"
#include "regs.h"
#include "fppLib.h"

#if (_BYTE_ORDER == _LITTLE_ENDIAN)
# define  HREG			1
# define  LREG			0
#else
# define  HREG			0
# define  LREG			1
#endif


#if (CPU==SH7750)

#undef FPP_DEBUG
#ifdef FPP_DEBUG
#include "fioLib.h"				/* to use printExc() */
#endif /*FPP_DEBUG*/

typedef union
    {
    UINT64 u64;
    UINT32 u32[2];
    } UNION64;

IMPORT UINT64 uss_dpadd (UINT64 d1, UINT64 d2);		/* d1 + d2 */
IMPORT UINT32 uss_fpadd (UINT32 f1, UINT32 f2);		/* f1 + f2 */
IMPORT UINT64 uss_dpsub (UINT64 d1, UINT64 d2);		/* d1 - d2 */
IMPORT UINT32 uss_fpsub (UINT32 f1, UINT32 f2);		/* f1 - f2 */
IMPORT UINT64 uss_dpmul (UINT64 d1, UINT64 d2);		/* d1 * d2 */
IMPORT UINT32 uss_fpmul (UINT32 f1, UINT32 f2);		/* f1 * f2 */
IMPORT UINT64 uss_dpdiv (UINT64 d1, UINT64 d2);		/* d1 / d2 */
IMPORT UINT32 uss_fpdiv (UINT32 f1, UINT32 f2);		/* f1 / f2 */
IMPORT UINT64 uss_dpsqrt (UINT64 d1);			/* d1 ^ 0.5 */
IMPORT UINT32 uss_fpsqrt (UINT32 f1);			/* f1 ^ 0.5 */
IMPORT UINT64 uss_fptodp (UINT32 f1);			/* (double)f1 */
IMPORT UINT32 uss_dptofp (UINT64 d1);			/* (float)d1  */

LOCAL INSTR *fppExcFixup (ESFSH *pEsf, REG_SET *pRegs);

#endif /* CPU==SH7750 */


/* globals */

REG_INDEX fpRegName [] =
    {
#ifdef	_WRS_HW_FP_SUPPORT
    {"fr0",  FPX_OFFSET(0)},
    {"fr1",  FPX_OFFSET(1)},
    {"fr2",  FPX_OFFSET(2)},
    {"fr3",  FPX_OFFSET(3)},
    {"fr4",  FPX_OFFSET(4)},
    {"fr5",  FPX_OFFSET(5)},
    {"fr6",  FPX_OFFSET(6)},
    {"fr7",  FPX_OFFSET(7)},
    {"fr8",  FPX_OFFSET(8)},
    {"fr9",  FPX_OFFSET(9)},
    {"fr10", FPX_OFFSET(10)},
    {"fr11", FPX_OFFSET(11)},
    {"fr12", FPX_OFFSET(12)},
    {"fr13", FPX_OFFSET(13)},
    {"fr14", FPX_OFFSET(14)},
    {"fr15", FPX_OFFSET(15)},
#if (FP_NUM_DREGS == 32)
    {"xf0",  FPX_OFFSET(16)},
    {"xf1",  FPX_OFFSET(17)},
    {"xf2",  FPX_OFFSET(18)},
    {"xf3",  FPX_OFFSET(19)},
    {"xf4",  FPX_OFFSET(20)},
    {"xf5",  FPX_OFFSET(21)},
    {"xf6",  FPX_OFFSET(22)},
    {"xf7",  FPX_OFFSET(23)},
    {"xf8",  FPX_OFFSET(24)},
    {"xf9",  FPX_OFFSET(25)},
    {"xf10", FPX_OFFSET(26)},
    {"xf11", FPX_OFFSET(27)},
    {"xf12", FPX_OFFSET(28)},
    {"xf13", FPX_OFFSET(29)},
    {"xf14", FPX_OFFSET(30)},
    {"xf15", FPX_OFFSET(31)},
#endif
#endif
    {NULL,   0},
    };

REG_INDEX fpCtlRegName [] =
    {
#ifdef	_WRS_HW_FP_SUPPORT
    {"fpul",  FPUL},
    {"fpscr", FPSCR},
#endif
    {NULL, 0},
    };

#if (CPU==SH7750)
IMPORT UINT32 __fpscr_values[2];	/* compiler generated code relies 
                                           on this to switch between single
					   precision and double precision.
					   It is in libgcc.a */
#endif

#ifdef	_WRS_HW_FP_SUPPORT
UINT32 fpscrInitValue = FPSCR_INIT;	/* default FPSCR value; can be changed
					   at startup if different value is 
					   needed */
#endif

/* locals */

#ifdef	_WRS_HW_FP_SUPPORT
LOCAL FP_CONTEXT fppInitContext;	/* initialized to initial fp context */
#endif


/*******************************************************************************
*
* fppArchInit - initialize floating-point coprocessor support
*
* This routine must be called before using the floating-point coprocessor.
* It is typically called from fppInit().
*
* NOMANUAL
*/

void fppArchInit (void)
    {
    fppCreateHookRtn = (FUNCPTR)NULL;

#ifdef	_WRS_HW_FP_SUPPORT
    bfill ((char *) &fppInitContext, sizeof (FP_CONTEXT), 
    	    0xff); 					/* fill with NaN */
    fppInitContext.fpul = 0;
    fppInitContext.fpscr = fpscrInitValue;
    fppRestore (&fppInitContext);

#if (CPU==SH7750)
    __fpscr_values[0] = fpscrInitValue & ~0x80000;	/* clear FPSCR[PR] */
    __fpscr_values[1] = fpscrInitValue;
#endif
#endif
    }

/*******************************************************************************
*
* fppArchTaskCreateInit - initialize floating-point coprocessor support for task
*
* NOMANUAL
*/

void fppArchTaskCreateInit
    (
    FP_CONTEXT *pFpContext		/* pointer to FP_CONTEXT */
    )
    {
#ifdef	_WRS_HW_FP_SUPPORT
    /* create NULL frame as initial frame */

    bcopy ((const char *) &fppInitContext, (char *)pFpContext,
	   sizeof (FP_CONTEXT));
#endif
    }

#ifdef	_WRS_HW_FP_SUPPORT
/******************************************************************************
*
* fppRegsToCtx - convert FPREG_SET to FP_CONTEXT.
*/ 

void fppRegsToCtx
    (
    FPREG_SET *  pFpRegSet,		/* input -  fpp reg set */
    FP_CONTEXT * pFpContext		/* output - fpp context */
    )
    {
#if 0
    *pFpContext = *pFpRegSet;
#else
    int ix;

    /* normal/idle state */

    for (ix = 0; ix < FP_NUM_DREGS; ix++)
        pFpContext->fpx[ix] = pFpRegSet->fpx [ix];

    pFpContext->fpul  = pFpRegSet->fpul;
    pFpContext->fpscr = pFpRegSet->fpscr;
#endif
    }

/******************************************************************************
*
* fppCtxToRegs - convert FP_CONTEXT to FPREG_SET.
*/ 

void fppCtxToRegs
    (
    FP_CONTEXT * pFpContext,		/* input -  fpp context */
    FPREG_SET *  pFpRegSet		/* output - fpp register set */
    )
    {
#if 0
    *pFpRegSet = *pFpContext;
#else
    int ix;

    /* normal/idle state */

    for (ix = 0; ix < FP_NUM_DREGS; ix++)
        pFpRegSet->fpx[ix] = pFpContext->fpx[ix];

    pFpRegSet->fpul  = pFpContext->fpul;
    pFpRegSet->fpscr = pFpContext->fpscr;
#endif
    }

#endif /* _WRS_HW_FP_SUPPORT */

/*******************************************************************************
*
* fppTaskRegsGet - get the floating-point registers from a task TCB
*
* This routine copies the floating-point registers of a task
* (PCR, PSR, and PIAR) to the locations whose pointers are passed as
* parameters.  The floating-point registers are copied in
* an array containing the 8 registers.
*
* NOTE
* This routine only works well if <task> is not the calling task.
* If a task tries to discover its own registers, the values will be stale
* (i.e., leftover from the last task switch).
*
* RETURNS: OK, or ERROR if there is no floating-point
* support or there is an invalid state.
*
* SEE ALSO: fppTaskRegsSet()
*/

STATUS fppTaskRegsGet
    (
    int task,           	/* task to get info about */
    FPREG_SET *pFpRegSet	/* pointer to floating-point register set */
    )
    {
#ifdef	_WRS_HW_FP_SUPPORT
    FAST FP_CONTEXT *pFpContext;
    FAST WIND_TCB *pTcb = taskTcb (task);

    if (pTcb == NULL)
	return (ERROR);

    pFpContext = pTcb->pFpContext;

    if (pFpContext == (FP_CONTEXT *)NULL)
	return (ERROR);			/* no coprocessor support */

    fppCtxToRegs (pFpContext, pFpRegSet);

    return (OK);
#else
    return (ERROR);
#endif
    }

/*******************************************************************************
*
* fppTaskRegsSet - set the floating-point registers of a task
*
* This routine loads the specified values into the specified task TCB.
* The 8 registers f0-f7 are copied to the array <fpregs>.
*
* RETURNS: OK, or ERROR if there is no floating-point
* support or there is an invalid state.
*
* SEE ALSO: fppTaskRegsGet()
*/

STATUS fppTaskRegsSet
    (
    int task,           	/* task whose registers are to be set */
    FPREG_SET *pFpRegSet	/* pointer to floating-point register set */
    )
    {
#ifdef	_WRS_HW_FP_SUPPORT
    FAST WIND_TCB *pTcb = taskTcb (task);
    FAST FP_CONTEXT *pFpContext;

    if (pTcb == NULL)
	return (ERROR);

    pFpContext = pTcb->pFpContext;

    if (pFpContext == (FP_CONTEXT *)NULL)
	return (ERROR);			/* no coprocessor support, PUT ERRNO */

    fppRegsToCtx (pFpRegSet, pFpContext);

    return (OK);
#else
    return (ERROR);
#endif
    }

/*******************************************************************************
*
* fppProbe - probe for the presence of a floating-point coprocessor
*
* This routine determines whether there is an SH7718(SH3e) on-chip
* floating-point coprocessor in the system.
*
* IMPLEMENTATION
* This routine sets the illegal coprocessor opcode trap vector and executes
* a coprocessor instruction.  If the instruction causes an exception,
* fppProbe() will return ERROR.  Note that this routine saves and restores
* the illegal coprocessor opcode trap vector that was there prior to this
* call.
*
* The probe is only performed the first time this routine is called.
* The result is stored in a static and returned on subsequent
* calls without actually probing.
*
* RETURNS:
* OK if the floating-point coprocessor is present, otherwise ERROR.
*/

STATUS fppProbe (void)
    {
#ifdef	_WRS_HW_FP_SUPPORT
    static int fppProbed = -2;		/* -2 = not done, -1 = ERROR, 0 = OK */
    FUNCPTR oldVec;

    if (fppProbed == -2)
	{
	/* save error vector */
	oldVec = intVecGet ((FUNCPTR *)INUM_TO_IVEC(INUM_ILLEGAL_INST_GENERAL));

	/* replace error vec */
	intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_ILLEGAL_INST_GENERAL),
		(FUNCPTR) fppProbeTrap);

	fppProbed = fppProbeSup ();     /* execute coprocessor instruction */

	/* replace old err vec*/
	intVecSet ((FUNCPTR *)INUM_TO_IVEC(INUM_ILLEGAL_INST_GENERAL),
		(FUNCPTR) oldVec);
	}
    return (fppProbed);
#else
    return (ERROR);
#endif
    }

#if (CPU==SH7750)
/******************************************************************************
*
* fppExcHandle - FPU error exception handler for IEEE754 denormalized number
*
* This routine handles FPU error exception traps caused by inputting IEEE754
* denormalized numbers to a specific set of SH7750 FPU instructions.  The goal
* is to support denormalized number computation on SH7750, by emulating those
* FPU instructions with integer arithmetics.  It first disassembles the FPU
* instruction which got the exception, and it picks up the related FPU
* registers(s) using fppRegGet().  The actual arithmetic computation is done
* by the USS GOFAST FP emulation library, and the result is set to a relevant
* FPU register by fppRegSet().  The following FPU instructions are emulated:
*
*	----------------------
*		single	double
*	----------------------
*	fadd	  o	  o
*	fsub	  o	  o
*	fmul	  o	  o
*	fdiv	  o	  o
*	fmac	  o	 n/a
*	fsqrt	  o	  o
*	fcnvsd	 n/a	  o
*	fcnvds	 n/a	  o
*	----------------------
*
* RETURNS: OK if FP emulation is successful, ERROR otherwise.
*
* NOMANUAL
*/

STATUS fppExcHandle
    (
    ESFSH   *pEsf,	/* pointer to exception stack frame */
    REG_SET *pRegs	/* pointer to register info on stack */
    )
    {
    INSTR *pcSave = pEsf->pc;	/* save PC before fppExcFixup() call */
    INSTR *prSave = pRegs->pr;	/* save PR before fppExcFixup() call */
    UINT32 fpscr = pEsf->info;
    INSTR *pFpeInsn = fppExcFixup (pEsf, pRegs);
    INSTR  insn;

    if (pFpeInsn != NULL)
	insn = *pFpeInsn;
    else
	goto FpError;

    switch (insn & FPE_MASK_2REG)
	{
	case FPE_INSN_FADD:
	    {
	    int m = (insn & 0x00f0) >> 4;
	    int n = (insn & 0x0f00) >> 8;

	    if (fpscr & FPSCR_DOUBLE_PRECISION)	/* FADD DRm,DRn: DRn+DRm->DRn */
		{
		UNION64 src, dst;

		if (fppRegGet (m,     &src.u32[HREG], 0) != OK ||
		    fppRegGet (m + 1, &src.u32[LREG], 0) != OK ||
		    fppRegGet (n,     &dst.u32[HREG], 0) != OK ||
		    fppRegGet (n + 1, &dst.u32[LREG], 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fadd dr%d,dr%d", m, n, 0, 0, 0);
		printExc (" (0x%08x%08x, 0x%08x%08x)\n",
			  src.u32[HREG], src.u32[LREG], dst.u32[HREG], dst.u32[LREG], 0);
#endif
		dst.u64 = uss_dpadd (dst.u64, src.u64);		/* dst + src */

		if (fppRegSet (n,     &dst.u32[HREG], 0) != OK ||
		    fppRegSet (n + 1, &dst.u32[LREG], 0) != OK)
		    goto FpError;
		}
	    else				/* FADD FRm,FRn: FRn+FRm->FRn */
		{
		UINT32 src, dst;

		if (fppRegGet (m, &src, 0) != OK ||
		    fppRegGet (n, &dst, 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fadd fr%d,fr%d (0x%08x, 0x%08x)\n",m,n,src,dst,0);
#endif
		dst = uss_fpadd (dst, src);			/* dst + src */

		if (fppRegSet (n, &dst, 0) != OK)
		    goto FpError;
		}
	    break;
	    }

	case FPE_INSN_FSUB:
	    {
	    int m = (insn & 0x00f0) >> 4;
	    int n = (insn & 0x0f00) >> 8;

	    if (fpscr & FPSCR_DOUBLE_PRECISION) /* FSUB DRm,DRn: DRn-DRm->DRn */
		{
		UNION64 src, dst;

		if (fppRegGet (m,     &src.u32[HREG], 0) != OK ||
		    fppRegGet (m + 1, &src.u32[LREG], 0) != OK ||
		    fppRegGet (n,     &dst.u32[HREG], 0) != OK ||
		    fppRegGet (n + 1, &dst.u32[LREG], 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fsub dr%d,dr%d", m, n, 0, 0, 0);
		printExc (" (0x%08x%08x, 0x%08x%08x)\n",
			  src.u32[HREG], src.u32[LREG], dst.u32[HREG], dst.u32[LREG], 0);
#endif
		dst.u64 = uss_dpsub (dst.u64, src.u64);		/* dst - src */

		if (fppRegSet (n,     &dst.u32[HREG], 0) != OK ||
		    fppRegSet (n + 1, &dst.u32[LREG], 0) != OK)
		    goto FpError;
		}
	    else				/* FSUB FRm,FRn: FRn-FRm->FRn */
		{
		UINT32 src, dst;

		if (fppRegGet (m, &src, 0) != OK ||
		    fppRegGet (n, &dst, 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fsub fr%d,fr%d (0x%08x, 0x%08x)\n",m,n,src,dst,0);
#endif
		dst = uss_fpsub (dst, src);			/* dst - src */

		if (fppRegSet (n, &dst, 0) != OK)
		    goto FpError;
		}
	    break;
	    }

	case FPE_INSN_FMUL:
	    {
	    int m = (insn & 0x00f0) >> 4;
	    int n = (insn & 0x0f00) >> 8;

	    if (fpscr & FPSCR_DOUBLE_PRECISION) /* FMUL DRm,DRn: DRn*DRm->DRn */
		{
		UNION64 src, dst;

		if (fppRegGet (m,     &src.u32[HREG], 0) != OK ||
		    fppRegGet (m + 1, &src.u32[LREG], 0) != OK ||
		    fppRegGet (n,     &dst.u32[HREG], 0) != OK ||
		    fppRegGet (n + 1, &dst.u32[LREG], 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fmul dr%d,dr%d", m, n, 0, 0, 0);
		printExc (" (0x%08x%08x, 0x%08x%08x)\n",
			  src.u32[HREG], src.u32[LREG], dst.u32[HREG], dst.u32[LREG], 0);
#endif
		dst.u64 = uss_dpmul (dst.u64, src.u64);		/* dst * src */

		if (fppRegSet (n,     &dst.u32[HREG], 0) != OK ||
		    fppRegSet (n + 1, &dst.u32[LREG], 0) != OK)
		    goto FpError;
		}
	    else				/* FMUL FRm,FRn: FRn*FRm->FRn */
		{
		UINT32 src, dst;

		if (fppRegGet (m, &src, 0) != OK ||
		    fppRegGet (n, &dst, 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fmul fr%d,fr%d (0x%08x, 0x%08x)\n",m,n,src,dst,0);
#endif
		dst = uss_fpmul (dst, src);			/* dst * src */

		if (fppRegSet (n, &dst, 0) != OK)
		    goto FpError;
		}
	    break;
	    }

	case FPE_INSN_FDIV:
	    {
	    int m = (insn & 0x00f0) >> 4;
	    int n = (insn & 0x0f00) >> 8;

	    if (fpscr & FPSCR_DOUBLE_PRECISION)	/* FDIV DRm,DRn: DRn/DRm->DRn */
		{
		UNION64 src, dst;

		if (fppRegGet (m,     &src.u32[HREG], 0) != OK ||
		    fppRegGet (m + 1, &src.u32[LREG], 0) != OK ||
		    fppRegGet (n,     &dst.u32[HREG], 0) != OK ||
		    fppRegGet (n + 1, &dst.u32[LREG], 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fdiv dr%d,dr%d", m, n, 0, 0, 0);
		printExc (" (0x%08x%08x, 0x%08x%08x)\n",
			  src.u32[HREG], src.u32[LREG], dst.u32[HREG], dst.u32[LREG], 0);
#endif
		dst.u64 = uss_dpdiv (dst.u64, src.u64);		/* dst / src */

		if (fppRegSet (n,     &dst.u32[HREG], 0) != OK ||
		    fppRegSet (n + 1, &dst.u32[LREG], 0) != OK)
		    goto FpError;
		}
	    else				/* FDIV FRm,FRn: FRn/FRm->FRn */
		{
		UINT32 src, dst;

		if (fppRegGet (m, &src, 0) != OK ||
		    fppRegGet (n, &dst, 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fdiv fr%d,fr%d (0x%08x, 0x%08x)\n",m,n,src,dst,0);
#endif
		dst = uss_fpdiv (dst, src);			/* dst / src */

		if (fppRegSet (n, &dst, 0) != OK)
		    goto FpError;
		}
	    break;
	    }

	case FPE_INSN_FMAC:
	    {
	    int m = (insn & 0x00f0) >> 4;
	    int n = (insn & 0x0f00) >> 8;

	    if (fpscr & FPSCR_DOUBLE_PRECISION)
		{
		goto FpError;		/* FMAC -- NO DOUBLE PRECISION */
		}
	    else			/* FMAC FR0,FRm,FRn: FR0*FRm+FRn->FRn */
		{
		UINT32 fr0, src, dst;

		if (fppRegGet (0, &fr0, 0) != OK ||
		    fppRegGet (m, &src, 0) != OK ||
		    fppRegGet (n, &dst, 0) != OK)
		    goto FpError;
#ifdef FPP_DEBUG
		printExc ("fmac fr0,fr%d,fr%d (0x%08x, 0x%08x, 0x%08x)\n",
			  m,n,fr0,src,dst);
#endif
		src = uss_fpmul (src, fr0);
		dst = uss_fpadd (dst, src);		/* dst + (src * fr0) */

		if (fppRegSet (n, &dst, 0) != OK)
		    goto FpError;
		}
	    break;
	    }

	default:
	    {
	    switch (insn & FPE_MASK_1REG)
		{
		case FPE_INSN_FSQRT:
		    {
		    int n = (insn & 0x0f00) >> 8;

		    if (fpscr & FPSCR_DOUBLE_PRECISION)		/* FSQRT DRn */
			{
			UNION64 dst;

			if (fppRegGet (n,     &dst.u32[HREG], 0) != OK ||
			    fppRegGet (n + 1, &dst.u32[LREG], 0) != OK)
			    goto FpError;
#ifdef FPP_DEBUG
			printExc ("fsqrt dr%d (0x%08x%08x)\n",
				  n, dst.u32[HREG], dst.u32[LREG], 0, 0);
#endif
			dst.u64 = uss_dpsqrt (dst.u64);

			if (fppRegSet (n,     &dst.u32[HREG], 0) != OK ||
			    fppRegSet (n + 1, &dst.u32[LREG], 0) != OK)
			    goto FpError;
			}
		    else					/* FSQRT FRn */
			{
			UINT32 dst;

			if (fppRegGet (n, &dst, 0) != OK)
			    goto FpError;
#ifdef FPP_DEBUG
			printExc ("fsqrt fr%d (0x%08x)\n",n,dst,0,0,0);
#endif
			dst = uss_fpsqrt (dst);

			if (fppRegSet (n, &dst, 0) != OK)
			    goto FpError;
			}
		    break;
		    }

		case FPE_INSN_FCNVSD:	/* FCNVSD FPUL,DRn: Double(FPUL)->DRn */
		    {
		    int n = (insn & 0x0f00) >> 8;

		    if (fpscr & FPSCR_DOUBLE_PRECISION)
			{
			UINT32 fpul;
			UNION64 dst;

			fpul = fppFpulGet ();
#ifdef FPP_DEBUG
			printExc ("fcnvsd fpul,dr%d (0x%08x)\n",n,fpul,0,0,0);
#endif
			dst.u64 = uss_fptodp (fpul);

			if (fppRegSet (n,     &dst.u32[HREG], 0) != OK ||
			    fppRegSet (n + 1, &dst.u32[LREG], 0) != OK)
			    goto FpError;
			}
		    else
			goto FpError;	/* FCNVSD -- NO SINGLE PRECISION */

		    break;
		    }

		case FPE_INSN_FCNVDS:	/* FCNVDS DRm,FPUL: (float)DRm->FPUL */
		    {
		    int m = (insn & 0x0f00) >> 8;

		    if (fpscr & FPSCR_DOUBLE_PRECISION)
			{
			UNION64 src;
			UINT32 fpul;

			if (fppRegGet (m,     &src.u32[HREG], 0) != OK ||
			    fppRegGet (m + 1, &src.u32[LREG], 0) != OK)
			    goto FpError;
#ifdef FPP_DEBUG
			printExc ("fcnvds dr%d,fpul (0x%08x%08x)\n",
				  m, src.u32[HREG], src.u32[LREG], 0, 0);
#endif
			fpul = uss_dptofp (src.u64);

			fppFpulSet (fpul);
			}
		    else
			goto FpError;	/* FCNVDS -- NO SINGLE PRECISION */

		    break;
		    }

		default:
		    goto FpError;	/* UNKNOWN FPU ERROR */
		}
	    }
	}
    return OK;
FpError:
    pEsf->pc = pcSave;		/* restore PC */
    pRegs->pr = prSave;		/* restore PR */
#ifdef FPP_DEBUG
    printExc ("fppExcHandle: PC=0x%x  FPSCR=0x%x \n",(int)pcSave, fpscr, 0,0,0);
#endif
    return ERROR;
    }

/******************************************************************************
*
* fppExcFixup - fix exception stack frame to prepare for resuming FP task
*
* This routine fixes pc (and pr) on exception stack frame, so as the task
* which got exception is able to resume its computation.  For most cases,
* it is just a matter of incrementing pc to skip the emulated FPU instruction.
* However the things are not so simple if the FPU instruction is located in
* a delay slot of branch instruction, since pc points at the branch instruction
* (NOT the FPU instruction) and the next pc depends on the branch operation.
* Namely we have to emulate the branch instruction also.  All the delayed
* branch instructions are listed below:
*
*	----------------------
* 		opcode	 mask
*	----------------------
*	rts	0x000b, 0xffff
*	rte	0x002b, 0xffff
*	bsrf	0x0003, 0xf0ff
*	braf	0x0023, 0xf0ff
*	jsr	0x400b, 0xf0ff
*	jmp	0x402b, 0xf0ff
*	bt/s	0x8d00, 0xff00
*	bf/s	0x8f00, 0xff00
*	bra	0xa000, 0xf000
*	bsr	0xb000, 0xf000
*	----------------------
*
* RETURNS: pointer to FPU instruction which got exception, or
*          NULL if failed to emulate a delayed branch instruction
*
* NOMANUAL
*/

LOCAL INSTR *fppExcFixup
    (
    ESFSH   *pEsf,	/* pointer to exception stack frame */
    REG_SET *pRegs	/* pointer to register info on stack */
    )
    {
    INSTR insn = *pEsf->pc;
    INSTR *pFpeInsn = pEsf->pc + 1;	/* if it is a delayed branch insn */
    INT32 pc = (INT32)pEsf->pc;
    INT32 npc;				/* next pc */
    BOOL updatePr = FALSE;

    if (insn == 0x000b)			/* RTS (PR->PC) */
	{
	npc = (INT32)pRegs->pr;
	}
    else if (insn == 0x002b)		/* RTE (SSR->SR, SPC->PC) */
	{
	/* The original ssr/spc are overwritten by this FPU error exception,
	 * hence we cannot emulate `rte' instruction here...
	 */
	return NULL;
	}
    else if ((insn & 0xf0ff) == 0x0003)	/* BSRF Rn (PC+4->PR, PC+4+Rn->PC) */
	{
	int n = (insn & 0x0f00) >> 8;
	npc = pc + 4 + (n < 8 ? (INT32)pRegs->voreg[n]
			      : (INT32)pRegs->nvreg[n - 8]);
	updatePr = TRUE;
	}
    else if ((insn & 0xf0ff) == 0x0023)	/* BRAF Rn (PC+4+Rn->PC) */
	{
	int n = (insn & 0x0f00) >> 8;
	npc = pc + 4 + (n < 8 ? (INT32)pRegs->voreg[n]
			      : (INT32)pRegs->nvreg[n - 8]);
	}
    else if ((insn & 0xf0ff) == 0x400b)	/* JSR @Rn (PC+4->PR, Rn->PC) */
	{
	int n = (insn & 0x0f00) >> 8;
	npc = n < 8 ? (INT32)pRegs->voreg[n] : (INT32)pRegs->nvreg[n - 8];
	updatePr = TRUE;
	}
    else if ((insn & 0xf0ff) == 0x402b)	/* JMP @Rn (Rn->PC) */
	{
	int n = (insn & 0x0f00) >> 8;
	npc = n < 8 ? (INT32)pRegs->voreg[n] : (INT32)pRegs->nvreg[n - 8];
	}
    else if ((insn & 0xff00) == 0x8d00)	/* BT/S label (PC+4+disp*2->PC) */
	{
	if (pEsf->sr & SR_BIT_T) npc = pc + 4 + (INT8)(insn & 0x00ff) * 2;
	else                     npc = pc + 4;
	}
    else if ((insn & 0xff00) == 0x8f00)	/* BF/S label (PC+4+disp*2->PC) */
	{
	if (pEsf->sr & SR_BIT_T) npc = pc + 4;
	else                     npc = pc + 4 + (INT8)(insn & 0x00ff) * 2;
	}
    else if ((insn & 0xf000) == 0xa000) /* BRA label (PC+4+disp*2->PC) */
	{
	INT16 disp = (insn & 0x0800) ? (insn | 0xf000) : (insn & 0x0fff);
	npc = pc + 4 + disp * 2;
	}
    else if ((insn & 0xf000) == 0xb000) /* BSR label(PC+4->PR,PC+4+disp*2->PC)*/
	{
	INT16 disp = (insn & 0x0800) ? (insn | 0xf000) : (insn & 0x0fff);
	npc = pc + 4 + disp * 2;
	updatePr = TRUE;
	}
    else
	{
	pFpeInsn = pEsf->pc;	/* Good!  FPE insn is not in delay slot, */
	npc = pc + 2;		/* simply skip FPU instruction */
	}

#ifdef FPP_DEBUG
    if (insn == 0x000b)
	printExc ("rts (to 0x%08x)\n",npc,0,0,0,0);
    else if (insn == 0x002b)
	printExc ("rte (cannot emulate)\n",0,0,0,0,0);
    else if ((insn & 0xf0ff) == 0x0003)
	printExc("bsrf r%d (==> 0x%08x)\n",(insn & 0x0f00)>>8,npc,0,0,0);
    else if ((insn & 0xf0ff) == 0x0023)
	printExc ("braf r%d (==> 0x%08x)\n",(insn & 0x0f00)>>8,npc,0,0,0);
    else if ((insn & 0xf0ff) == 0x400b)
	printExc ("jsr @r%d (==> 0x%08x)\n",(insn & 0x0f00)>>8,npc,0,0,0);
    else if ((insn & 0xf0ff) == 0x402b)
	printExc ("jmp @r%d (==> 0x%08x)\n",(insn & 0x0f00)>>8,npc,0,0,0);
    else if ((insn & 0xff00) == 0x8d00)
	printExc ("bt/s 0x%08x\n",npc,0,0,0,0);
    else if ((insn & 0xff00) == 0x8f00)
	printExc ("bf/s 0x%08x\n",npc,0,0,0,0);
    else if ((insn & 0xf000) == 0xa000)
	printExc ("bra 0x%08x\n",npc,0,0,0,0);
    else if ((insn & 0xf000) == 0xb000)
	printExc ("bsr 0x%08x\n",npc,0,0,0,0);
#endif /*FPP_DEBUG*/

    if (updatePr)
	pRegs->pr = (INSTR *)(pc + 4);		/* update PR on stack */

    pEsf->pc = (INSTR *)npc;			/* update PC on stack */

    return pFpeInsn;	/* return pointer to actual FPU instruction */
    }

#endif /* CPU==SH7750 */
