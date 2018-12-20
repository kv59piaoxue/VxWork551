/* wdbArchLib.c - SH specific debug library */

/* Copyright 1996-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01x,05mar02,h_k  added support for SH-DSP and SH3-DSP in wdbDbgGetNpc (SPR
                 #73006).
01w,24oct01,zl  fixes for doc builds.
01v,16feb01,hk  prefix underscore to UBC_xxx macro (in conflict with sh7XXX.h).
01u,24sep00,zl  moved _func_wdbUbcInit to windALib.s.
01t,06sep00,zl  rewrote HW hardware breakpoint support.
01s,03apr00,frf Add SH support for T2:wdbXxx()->wdbDbgXxx().
01r,18aug99,zl  use WDB_XXX error numbers
01q,29jun99,zl  included SH7750 in hardware breakpoint support
01p,11mar99,hk  moved _archHelp_msg to dbgArchLib.
01o,10mar99,hk  made _archHelp_msg to be CPU specific.
01n,17feb99,jmb added missing macro for SH7700.
01m,21dec98,jmb added a dummy definition of wdbHwBreakpoint so that
                targets without hardware breakpoint support could link.
01l,21oct98,kab added hardware breakpoint support for SH7410.
01k,16oct98,jmb fixed usage of DBG_HARDWARE_BP 
01j,15oct98,kab added hardware breakpoint support.
01i,08may98,jmc added support for SH-DSP and SH3-DSP.
01i,16jul98,st  added SH7750 support.
01h,28apr97,hk  changed dbg_trap_handler() to wdbTrap(). deleted bpFind() from
                wdbGetNpc(). merged wdbArchBreakpoint() for SH family.
01g,25apr97,hk  changed SH704X to SH7040.
01f,03mar97,hk  reviewed wdbGetNpc().
01e,23feb97,hk  put wdbBpStub() for SH7700. made wdbArchBreakpoint() simple.
                reviewed wdbGetNpc().
01d,24sep96,wt	enabled dbg_trap_handler().
		deleted the messages for debug.
		shaped up source code.
01c,17sep96,hk  disabled dbg_trap_handler() and bareg[] access for SH7700.
01b,05sep96,wt  wrote wdbArchBreakpoint () and wdbGetNpc ().
                filled the body of wdbTraceModeSet (), wdbTraceModeClear ()
                and wdbArchInit ().
01a,24jul96,wt  derived from i960.
                nullfied all function.
*/

/*
DESCRIPTION
This module contains SH architecture dependent portions of the breakpoint
handling facilities.
*/

/* includes */

#include "vxWorks.h"
#include "dsmLib.h"
#include "esf.h"
#include "iv.h"
#include "wdb/wdbDbgLib.h"
#include "string.h"
#include "dbgLib.h"
#include "intLib.h"
#include "sysLib.h"

/* defines */

/* macros to decode a next instruction to be executed. */

#define SEXT8(x)	(((x&0xff) ^ (~0x7f))+0x80)
#define SEXT12(x)	(((x&0xfff) ^ (~0x7ff))+0x800)

#define IS_RTS(inst)	(((inst) & 0xffff) == 0x000b)
#define IS_JMP(inst)	(((inst) & 0xf0ff) == 0x402b)
#define IS_JSR(inst)	(((inst) & 0xf0ff) == 0x400b)
#define IS_BRAF(inst)	(((inst) & 0xf0ff) == 0x0023)
#define IS_BSRF(inst)	(((inst) & 0xf0ff) == 0x0003)
#define IS_BF(inst)	(((inst) & 0xff00) == 0x8b00)
#define IS_BFS(inst)	(((inst) & 0xff00) == 0x8f00)
#define IS_BT(inst)	(((inst) & 0xff00) == 0x8900)
#define IS_BTS(inst)	(((inst) & 0xff00) == 0x8d00)
#define IS_BRA(inst)	(((inst) & 0xf000) == 0xa000)
#define IS_BSR(inst)	(((inst) & 0xf000) == 0xb000)
#define IS_RTE(inst)	(((inst) & 0xffff) == 0x002b)
#define IS_TRAPA(inst)	(((inst) & 0xff00) == 0xc300)
#define IS_PPI(inst)	(((inst) & 0xfc00) == 0xf800)

/* typedefs */

/* extern declarations */

extern void	excExcHandle ();
#if (CPU==SH7600 || CPU==SH7000)
extern void wdbDbgBpStub();
#if DBG_HARDWARE_BP
extern void wdbDbgHwBpStub();
#endif /* DBG_HARDWARE_BP */
#endif /* (CPU==SH7600 || CPU==SH7000) */

/* globals */


/* forward declarations */

void wdbDbgArchBreakpoint (int vecNum, TRACE_ESF * pInfo, REG_SET * pRegs);

#if DBG_HARDWARE_BP
#if (CPU==SH7750 || CPU==SH7700)
void wdbDbgHwBpStub (int, ESFSH *, REG_SET *);
#endif /* (CPU==SH7750 || CPU==SH7700) */
void wdbDbgHwBreakpoint (int, ESFSH *, REG_SET *);
void wdbDbgRegsSet (DBG_REGS *);
void wdbDbgRegsGet (DBG_REGS *);
void wdbDbgRegsClear (void);
#endif /* DBG_HARDWARE_BP */

/* local variables */

#if DBG_HARDWARE_BP
LOCAL UBC ubc;
#endif  /* DBG_HARDWARE_BP */

#if (CPU==SH7750 || CPU==SH7700)
/*******************************************************************************
*
* wdbDbgBpStub - breakpoint handling trap
*
* INTERNAL
* On entry, r4 & r5 contain the PC & nPC at time of trap, sp points to area
* in which excEnter saved regs, traps are enabled.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void wdbDbgBpStub
    (
    int		vecNum,	/* exception vector number */
    ESFSH *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    /* Always correct, as BP insn is always 16 bits */
    --(pEsf->pc);

    wdbDbgArchBreakpoint (vecNum, pEsf, pRegs);
    }
#endif /* (CPU==SH7750 || CPU==SH7700) */

/******************************************************************************
*
* wdbArchInit - set exception handlers for the break and the trace.
*
* RETURNS: N/A
*
* NOMANUAL
*/ 

void wdbDbgArchInit (void)
    {
    /* insert the new breakpoint and trace vectors */

    intVecSet ((FUNCPTR *) INUM_TO_IVEC (DBG_TRAP_NUM), (FUNCPTR) wdbDbgBpStub);

#if DBG_HARDWARE_BP
    intVecSet ((FUNCPTR *) IV_USER_BREAK, (FUNCPTR) wdbDbgHwBpStub);
#endif  /* DBG_HARDWARE_BP */
    }

/*******************************************************************************
*
* wdbDbgArchBreakpoint - setup to call wdbTrap()
*
* RETURNS: N/A
*
* NOMANUAL
*/

void wdbDbgArchBreakpoint
    (
    int		vecNum,		/* exception vector number */
    TRACE_ESF *	pInfo,		/* pointer to esf info saved on stack */
    REG_SET * 	pRegs		/* pointer to buf containing saved regs */
    )
    {
    INSTR insn = *pRegs->pc;

    /* Dispatch the exception as needed */
    if (insn == DBG_BREAK_INST)
	wdbDbgTrap (pRegs->pc, pRegs, pInfo, NULL, FALSE);
    else
	excExcHandle (vecNum, pInfo, pRegs);
    }

/*******************************************************************************
*
* wdbDbgGetNpc - returns the adress of the next instruction to be executed.
*
* RETURNS: Adress of the next instruction to be executed.
*
* NOMANUAL
*/

INSTR *wdbDbgGetNpc 
    (
    REG_SET *  pRegs		/* pointer to task registers */
    )
    {
    INSTR      machInstr;		/* Machine instruction */
    INSTR *    npc;			/* next program counter */
    INSTR *    pc;			/* program counter */

    npc = (pc = pRegs->pc) + 1;		/* Default nPC */

    machInstr = *(INSTR *)(pc);

    if (IS_RTS (machInstr))
	{
	npc = pRegs->pr;
	}
    else if ((IS_JMP (machInstr)) || (IS_JSR (machInstr)))
	{
	int m = ((machInstr) >> 8) & 0xf;

	if (m < 8) npc = (INSTR *)(pRegs->voreg[m]);
	else       npc = (INSTR *)(pRegs->nvreg[m-8]);
	}
    else if ((IS_BRAF (machInstr)) || (IS_BSRF (machInstr)))
	{
	int m = ((machInstr) >> 8) & 0xf;

	if (m < 8) npc = (INSTR *)(((int)pc) + pRegs->voreg[m] + 4);
	else       npc = (INSTR *)(((int)pc) + pRegs->nvreg[m-8] + 4);
	}
    else if ((IS_BF (machInstr)) || (IS_BFS (machInstr)))
	{
	int tBit = (pRegs->sr) & 1;

	if (!tBit)
	    npc = (INSTR *)(((int)pc) + ((SEXT8 (machInstr)) << 1) + 4);
	else if (IS_BFS (machInstr))
	    npc++;
	}
    else if ((IS_BT (machInstr)) || (IS_BTS (machInstr)))
	{
	BOOL tBit = (pRegs->sr) & 1;

	if (tBit)
	    npc = (INSTR *)(((int)pc) + ((SEXT8 (machInstr)) << 1) + 4);
	else if (IS_BTS (machInstr))
	    npc++;
	}
    else if ((IS_BRA (machInstr)) || (IS_BSR (machInstr)))
	{
	    npc = (INSTR *)(((int)pc) + ((SEXT12 (machInstr)) << 1) + 4);
	}
#if (CPU==SH7750 || CPU==SH7700)
    else if (IS_RTE (machInstr))
	{
	npc = pRegs->pc;
	}
    else if (IS_TRAPA (machInstr))
	{
	npc = (INSTR *)(((int)(pRegs->vbr)) + 0x100);
	}
#elif (CPU==SH7600 || CPU==SH7000)
    else if (IS_RTE (machInstr))
	{
	npc = *((INSTR **)(pRegs->spReg));
	}
    else if (IS_TRAPA (machInstr))
	{
	npc = *((INSTR **)(((int)(pRegs->vbr)) + ((machInstr & 0xff)<<2)));
	}
#endif
#if (CPU==SH7700 || CPU==SH7600)
    else if (IS_PPI (machInstr))
	{
	npc += 1;
	}
#endif
    return (npc);
    }

/******************************************************************************
*
* wdbDbgTraceModeSet - lock interrupts and set the trace bit.
*
* Because SH has no trace mode, all this routine needs to do is
* lock interrupts for the reg set.
*
* RETURNS: the old int level
*
* NOMANUAL
*/ 

int wdbDbgTraceModeSet
    (
    REG_SET *pRegs
    )
    {
    return (intRegsLock (pRegs));
    }

/******************************************************************************
*
* wdbDbgTraceModeClear - restore old int lock level and clear the trace bit.
*
* Because SH has no trace mode, all this routine needs to do is
* restore the int mask from the last wdbDbgTraceModeSet().
*
* RETURNS: N/A
*
* NOMANUAL
*/ 

void wdbDbgTraceModeClear
    (
    REG_SET *pRegs,
    int traceData
    )
    {
    intRegsUnlock (pRegs, traceData);
    }

#if DBG_HARDWARE_BP
#if (CPU==SH7750 || CPU==SH7700)
/*******************************************************************************
*
* wdbDbgHwBpStub - H/W breakpoint handling trap
*
* INTERNAL
* The SH7729 USER_BREAK sets everything up for us, we don't have to hand
* build the ESF or the REG_SET.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void wdbDbgHwBpStub
    (
    int		vecNum,	/* exception vector number */
    ESFSH *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    wdbDbgHwBreakpoint (vecNum, pEsf, pRegs);
    }
#endif /* (CPU==SH7750 || CPU==SH7700) */

/*******************************************************************************
*
* wdbDbgHwBreakpoint - H/W breakpoint handling trap
*
* INTERNAL
* This is called either from the asm or C wdbDbgHwBpStub(), which will have
* fixed up the ESF data and built the stact REG_SET. vecNum is no longer
* used, but preserved for posterity.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void wdbDbgHwBreakpoint
    (
    int		vecNum,	/* exception vector number - IGNORED */
    ESFSH *	pEsf,	/* pointer to exception stack frame */
    REG_SET *	pRegs	/* pointer to register info on stack */
    )
    {
    DBG_REGS dbgRegs;

    wdbDbgRegsGet (&dbgRegs);
    wdbDbgRegsClear ();

    wdbDbgTrap (pRegs->pc, pRegs, (void *) NULL, (void *) &dbgRegs, TRUE);
    }


/*******************************************************************************
*
* wdbDbgHwAddrCheck - can hardware breakpoint be set at addr?
*
* This routine checks if a hardware breakpoint of type can be set at addr.
* Fails if:
*	type INSN and addr on byte boundary
*
* RETURNS: OK or ERROR if the address is not appropriate.
*
* NOMANUAL
*/

STATUS wdbDbgHwAddrCheck
    (
    UINT32      addr,           /* address for hardware breakpoint */
    UINT32      type,           /* hardware breakpoint type */
    FUNCPTR     memProbeRtn     /* memProbe routine */
    )
    {
    /* error for insn break on odd address */
    if (((type & BH_BREAK_MASK) == BH_BREAK_INSN) && (addr & 0x1))
	return (ERROR);

    return (OK);
    }

/******************************************************************************
*
* wdbDbgUbcInit - initialize hardware breakpoint registers
*
* This routine initializes the UBC registers.
*
* RETURNS: N/A.
*
* NOMANUAL
*/

LOCAL void wdbDbgUbcInit (void)
    {
    /* initialize to something safe */

    ubc.brcrSize = BRCR_NONE;
    _UBC_TYPE(0) = 0;
    _UBC_TYPE(1) = 0;
    _UBC_TYPE(2) = 0;
    _UBC_TYPE(3) = 0;

    /* Let the BSP initialize the UBC structure */

    if (_func_wdbUbcInit != NULL)
	{
	(* _func_wdbUbcInit)(&ubc);
	}

    /* Initialize registers */

    switch (ubc.brcrSize)
	{
	case BRCR_0_1:				/* SH7000, SH7050 */
	    *_UBC_BAMR32(0) = 0;
	    break;
	case BRCR_16_1:				/* SH7055, SH7604 */
	    *_UBC_BRCR16    = ubc.brcrInit;
	    *_UBC_BAMR32(0) = 0;
	    break;
	case BRCR_16_2:				/* SH7750, SH7709 */
	    *_UBC_BRCR16    = ubc.brcrInit;
	    *_UBC_BAMR8(0)  = UBC_BAMR_BASM;
	    *_UBC_BAMR8(1)  = UBC_BAMR_BASM;
	    break;
	case BRCR_32_2:				/* SH7709A, SH7729 */
	    *_UBC_BRCR32    = ubc.brcrInit;
	    *_UBC_BAMR32(0) = 0;
	    *_UBC_BAMR32(1) = 0;
	    break;
	case BRCR_32_4:				/* SH7615 */
	    *_UBC_BRCR32    = ubc.brcrInit;
	    *_UBC_BAMR32(0) = 0;
	    *_UBC_BAMR32(1) = 0;
	    *_UBC_BAMR32(2) = 0;
	    *_UBC_BAMR32(3) = 0;
	    break;
	}
    }

/******************************************************************************
*
* wdbDbgChannelGet - get an unused debug channel
*
* This routine searches for an unused debug channel that supports the features
* specifyed by type.
*
* RETURNS: OK, or WDB_ERR_X  if no channel is available.
*
* NOMANUAL
*/

LOCAL STATUS wdbDbgChannelGet
    (
    DBG_REGS *  pDbgRegs,       		/* debug registers */
    UINT32      access,         		/* access type */
    int *	pChan
    )
    {
    switch (ubc.brcrSize)
	{
	case BRCR_0_1:				/* SH7050, SH7000 */
	case BRCR_16_1:				/* SH7055, SH7604 */
	    if (pDbgRegs->type[0] == 0)
		*pChan = 0;
	    else
		return WDB_ERR_HW_REGS_EXHAUSTED;
	    break;

	case BRCR_16_2:				/* SH7750, SH7709 */
	case BRCR_32_2:				/* SH7729, SH7709A */
	    if ((access & BH_BUS_MASK) != 0)
		{
		/* only chan B supports X/Y */

		if (pDbgRegs->type[1] == 0)
		    *pChan = 1;
		else
		    return WDB_ERR_HW_REGS_EXHAUSTED;
		}
	    else
		{
		if (pDbgRegs->type[0] == 0)
		    *pChan = 0;
		else if (pDbgRegs->type[1] == 0)
		    *pChan = 1;
		else
		    return WDB_ERR_HW_REGS_EXHAUSTED;
		}
	    break;

	case BRCR_32_4:				/* SH7615 */
	    if ((access & BH_BUS_MASK) != 0)
		{
		/* only chan C and D support X/Y */

		if (pDbgRegs->type[2] == 0)
		    *pChan = 2;
		else if (pDbgRegs->type[3] == 0)
		    *pChan = 3;
		else
		    return WDB_ERR_HW_REGS_EXHAUSTED;
		}
	    else
		{
		if (pDbgRegs->type[0] == 0)
		    *pChan = 0;
		else if (pDbgRegs->type[1] == 0)
		    *pChan = 1;
		else if (pDbgRegs->type[2] == 0)
		    *pChan = 2;
		else if (pDbgRegs->type[3] == 0)
		    *pChan = 3;
		else
		    return WDB_ERR_HW_REGS_EXHAUSTED;
		}
	    break;

	case BRCR_NONE:				/* None */
	default:
	    return (WDB_ERR_INVALID_HW_BP);
	}
    return OK;
    }

/******************************************************************************
*
* wdbDbgHwBpSet - configure hardware breakpoint
*
* addr is the address of the data or insn for the breakpoint.
* access is the type of access that will generate a breakpoint.  This does
* not attempt to identify all "meaningless" breakpoints, e.g., break on
* byte wide insn fetch of the X data channel.
*
* RETURNS: OK, or WDB_ERR_X if breakpoint already set or cannot be configured.
*
* NOMANUAL
*/

STATUS wdbDbgHwBpSet
    (
    DBG_REGS *  pDbgRegs,       /* debug registers */
    UINT32      access,         /* access type */
    UINT32      addr            /* breakpoint addr */
    )
    {
    STATUS	stat;
    int		chan;
    UINT16	bbrValue = 0;
    static BOOL	beenHere = FALSE;

    /* first time detect UBC type and initialize it's registers */

    if (!beenHere)
	{
	wdbDbgUbcInit();
	beenHere = TRUE;
	}

    /* Get new break channel */

    if ((stat = wdbDbgChannelGet (pDbgRegs, access, &chan)) != OK)
	return (stat);

    /* Tear apart the access bits & configure pDbgRegs for bp list. */

    switch (access & BH_BREAK_MASK)
	{
	case BH_BREAK_INSN:
	    bbrValue |= UBC_BBR_ID0;    		/* set insn break */
	    break;
	case BH_BREAK_DATA:
	    bbrValue |= UBC_BBR_ID1;    		/* set data break */
	    break;
	case BH_BREAK_ANY:				/* default any type */
	default:
	    bbrValue |= (UBC_BBR_ID0 | UBC_BBR_ID1);
	}

    switch (access & BH_CYCLE_MASK)
	{
	case BH_CYCLE_READ:
	    bbrValue |= UBC_BBR_RW0;			/* break on read */
	    break;
	case BH_CYCLE_WRITE:
	    bbrValue |= UBC_BBR_RW1;			/* break on write */
	    break;
	case BH_CYCLE_ANY:				/* default to R/W */
	case BH_CYCLE_RW:
	    bbrValue |= (UBC_BBR_RW0 | UBC_BBR_RW1);
	    break;
	}

    switch (access & BH_SIZE_MASK)
	{
	case BH_ANY:					/* default any size */
	    break;
	case BH_8:
	    bbrValue |= UBC_BBR_SZ0;			/* byte access only */
	    break;
	case BH_16:
	    bbrValue |= UBC_BBR_SZ1;			/* word access only */
	    break;
	case BH_32:
	    bbrValue |= (UBC_BBR_SZ0 | UBC_BBR_SZ1);    /* dword access only */
	    break;
	}

    if (ubc.brcrSize == BRCR_16_2)			/* !SH7709, !SH7750   */
	{						/* must avoid because */
	if ((access & BH_CPU_MASK) != 0)		/* on SH7750 these    */
	    return (WDB_ERR_INVALID_HW_BP);		/* have different     */
	}						/* meaning (SZ2)      */
    else
	{
	switch (access & BH_CPU_MASK)
	    {
	    case BH_CPU:				/* default is CPU */
		bbrValue |= UBC_BBR_CD0;
		break;
	    case BH_DMAC:				/* DMAC */
		bbrValue |= UBC_BBR_CD1;
		break;
	    case BH_DMAC_CPU:				/* DMAC and CPU */
		bbrValue |= UBC_BBR_CD0 | UBC_BBR_CD1;
		break;
	    default:
		return (WDB_ERR_INVALID_HW_BP);
	    }
	}

    switch (access & BH_BUS_MASK)
	{
	case BH_IBUS:					/* I bus (default) */
	    break;
	case BH_XBUS:
	    bbrValue |= UBC_BBR_XYE;			/* X bus enable */
	    addr = (addr & 0xffff) << 16;		/* X in upper 16 */
	    break;
	case BH_YBUS:
	    bbrValue |= UBC_BBR_XYE | UBC_BBR_XYS;	/* Y bus */
	    addr = (addr & 0xffff);			/* X in lower 16 */
	    break;
	default:
	    return (WDB_ERR_INVALID_HW_BP);
	}

    /* save type for global state */

    pDbgRegs->type[chan] = access | BRK_HARDWARE;
	
    /* address register and bus cycle register */

    pDbgRegs->bar[chan] = addr;

    pDbgRegs->bbr[chan] = bbrValue;

    return (OK);
    }

/******************************************************************************
*
* wdbDbgHwBpFind - Find the hardware breakpoint
*
* This routine finds the type and the address of the
* hardware breakpoint that is set in the DBG_REGS structure.
* This information is stored in the pType and pAddr arguments.
* pAddr is the address *as set in the breakpoint*, not the
* current/stopped PC.
*
* Note that multiple break conditions may be met, e.g., both A and B 
* chan break, at the same time, but we can only return the match for 
* one of the H/W breakpoints.
*
* RETURNS: OK, or ERROR if unable to find a hardware breakpoint
*
* NOMANUAL
*/

STATUS wdbDbgHwBpFind
    (
    DBG_REGS *  pDbgRegs,       /* debug registers */
    UINT32 *    pType,          /* return type info via this pointer */
    UINT32 *    pAddr           /* return address info via this pointer */
    )
    {
    UINT32	cond;

    switch (ubc.brcrSize)
	{
	case BRCR_0_1:				/* SH7050, SH7000 */
	case BRCR_16_1:				/* SH7055, SH7604 */
	    *pType = pDbgRegs->type[0];
	    *pAddr = pDbgRegs->bar[0];
	    return (OK);

	case BRCR_16_2:				/* SH7750, SH7709 */
	    cond = pDbgRegs->brcr & UBC_BRCR_CONDITION_MASK_16_2;

	    if (cond & UBC_BRCR_CMFA)		/* Ch A */
		{
		*pType = pDbgRegs->type[0];
		*pAddr = pDbgRegs->bar[0];
		return (OK);
		}
	    if (cond & UBC_BRCR_CMFB)		/* Ch B */
		{
		*pType = pDbgRegs->type[1];
		*pAddr = pDbgRegs->bar[1];
		return (OK);
		}
	    break;

	case BRCR_32_2:				/* SH7709A, SH7729 */
	    cond = pDbgRegs->brcr & UBC_BRCR_CONDITION_MASK_32_2;

	    if ((cond & UBC_BRCR_SCMFCA) ||	/* Ch A, CPU */
		(cond & UBC_BRCR_SCMFDA))	/* Ch A, DMAC */
		{
		*pType = pDbgRegs->type[0];
		*pAddr = pDbgRegs->bar[0];
		return (OK);
		}
	    if ((cond & UBC_BRCR_SCMFCB) ||	/* Ch B, CPU */
		(cond & UBC_BRCR_SCMFDB))	/* Ch B, DMAC */
		{
		*pType = pDbgRegs->type[1];
		*pAddr = pDbgRegs->bar[1];
		return (OK);
		}
	    break;

	case BRCR_32_4:				/* SH7615 */
	    cond = pDbgRegs->brcr & UBC_BRCR_CONDITION_MASK_32_4;

	    if ((cond & UBC_BRCR_CMFCA) ||	/* Ch A, CPU */
		(cond & UBC_BRCR_CMFPA))	/* Ch A, DMAC */
		{
		*pType = pDbgRegs->type[0];
		*pAddr = pDbgRegs->bar[0];
		return (OK);
		}
	    if ((cond & UBC_BRCR_CMFCB) ||	/* Ch B, CPU */
		(cond & UBC_BRCR_CMFPB))	/* Ch B, DMAC */
		{
		*pType = pDbgRegs->type[1];
		*pAddr = pDbgRegs->bar[1];
		return (OK);
		}
	    if ((cond & UBC_BRCR_CMFCC) ||	/* Ch C, CPU */
		(cond & UBC_BRCR_CMFPC))	/* Ch C, DMAC */
		{
		*pType = pDbgRegs->type[2];
		*pAddr = pDbgRegs->bar[2];
		return (OK);
		}
	    if ((cond & UBC_BRCR_CMFCD) ||	/* Ch D, CPU */
		(cond & UBC_BRCR_CMFPD))	/* Ch D, DMAC */
		{
		*pType = pDbgRegs->type[3];
		*pAddr = pDbgRegs->bar[3];
		return (OK);
		}
	}

    return (ERROR);
    }

/******************************************************************************
*
* wdbDbgRegsSet - config the hardware for a given breakpoint.
*
* This is called at context switch to set the HW registers for the
* given breakpoint.
*
* RETURNS: N/A
*
* NOMANUAL
*/ 

void wdbDbgRegsSet
    (
    DBG_REGS *	pRegs
    )
    {
    int chan = 0;

    /* Set BRCR safe before setting up other registers */

    switch (ubc.brcrSize)
	{
	case BRCR_0_1:				/* SH7050, SH7000 */
	    chan = 1;
	    break;
	case BRCR_16_1:				/* SH7055, SH7604 */
	    *_UBC_BRCR16 = ubc.brcrInit;
	    chan = 1;
	    break;
	case BRCR_16_2:				/* SH7750, SH7709 */
	    *_UBC_BRCR16 = ubc.brcrInit;
	    chan = 2;
	    break;
	case BRCR_32_2:				/* SH7709A, SH7729 */
	    *_UBC_BRCR32 = ubc.brcrInit;
	    chan = 2;
	    break;
	case BRCR_32_4:				/* SH7615 */
	    *_UBC_BRCR32 = ubc.brcrInit;
	    chan = 4;
	    break;
	}

    while (chan > 0)
	{
	chan--;
	_UBC_TYPE(chan) = pRegs->type[chan];
	*_UBC_BAR(chan) = pRegs->bar[chan];
	*_UBC_BBR(chan) = pRegs->bbr[chan];
	}
    }

/******************************************************************************
*
* wdbDbgRegsGet - get the hardware regs for a given breakpoint.
*
* This is called by the breakpoint handler to get the HW registers for the
* given breakpoint.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void wdbDbgRegsGet
    (
    DBG_REGS *	pRegs
    )
    {
    int chan = 0;

    switch (ubc.brcrSize)
	{
	case BRCR_0_1:				/* SH7050, SH7000 */
	    chan = 1;
	    break;
	case BRCR_16_1:				/* SH7055, SH7604 */
	    chan = 1;
	    pRegs->brcr    = *_UBC_BRCR16;
	    break;
	case BRCR_16_2:				/* SH7750, SH7709 */
	    chan = 2;
	    pRegs->brcr    = *_UBC_BRCR16;
	    break;
	case BRCR_32_2:				/* SH7709A, SH7729 */
	    chan = 2;
	    pRegs->brcr    = *_UBC_BRCR32;
	    break;
	case BRCR_32_4:				/* SH7615 */
	    chan = 4;
	    pRegs->brcr    = *_UBC_BRCR32;
	    break;
	}

    while (chan > 0)
	{
	chan--;
	pRegs->type[chan] = _UBC_TYPE(chan);
	pRegs->bar[chan]  = *_UBC_BAR(chan);
	pRegs->bbr[chan]  = *_UBC_BBR(chan);
	}
    }

/******************************************************************************
*
* wdbDbgRegsClear - clear hardware break point registers
*
* This routine clears the hardware breakpoint registers.  Interrupt and task
* switch locking is handled by wdbLib.
*
* RETURNS: N/A.
*
* NOMANUAL
*/

void wdbDbgRegsClear (void)
    {
    int chan = 0;

    switch (ubc.brcrSize)
	{
	case BRCR_0_1:				/* SH7050, SH7000 */
	    chan = 1;
	    break;
	case BRCR_16_1:				/* SH7055, SH7604 */
	    *_UBC_BRCR16 = ubc.brcrInit;
	    chan = 1;
	    break;
	case BRCR_16_2:				/* SH7750, SH7709 */
	    *_UBC_BRCR16 = ubc.brcrInit;
	    chan = 2;
	    break;
	case BRCR_32_2:				/* SH7709A, SH7729 */
	    *_UBC_BRCR32 = ubc.brcrInit;
	    chan = 2;
	    break;
	case BRCR_32_4:				/* SH7615 */
	    *_UBC_BRCR32 = ubc.brcrInit;
	    chan = 4;
	    break;
	}

    while (chan > 0)
	{
	chan--;
	_UBC_TYPE(chan) = 0;
	*_UBC_BAR(chan) = 0;
	*_UBC_BBR(chan) = 0;
	}
    }

#ifdef WDB_DBG_DEBUG
/******************************************************************************
*
* wdbDbgRegsPrint - display hardware break point registers
*
* This routine displays the hardware breakpoint registers.
*
* RETURNS: N/A.
*
* NOMANUAL
*/

void wdbDbgRegsPrint (void)
    {
    int chan = 0;
    int i;

    switch (ubc.brcrSize)
	{
	case BRCR_0_1:				/* SH7050, SH7000 */
	    chan = 1;
	    break;
	case BRCR_16_1:				/* SH7055 */
	    *_UBC_BRCR16 = ubc.brcrInit;
	    chan = 1;
	    break;
	case BRCR_16_2:				/* SH7750, SH7709 */
	    *_UBC_BRCR16 = ubc.brcrInit;
	    chan = 2;
	    break;
	case BRCR_32_2:				/* SH7709A, SH7729 */
	    *_UBC_BRCR32 = ubc.brcrInit;
	    chan = 2;
	    break;
	case BRCR_32_4:				/* SH7615 */
	    *_UBC_BRCR32 = ubc.brcrInit;
	    chan = 4;
	    break;
	}

    printf ("\n");

    for (i = 0 ; i < chan; i++)
	{
	printf ("Break channel %d:  BAR=0x%08x  BBR=0x%08x (type=0x%08x) \n",
		i, *_UBC_BAR(i), *_UBC_BBR(i), _UBC_TYPE(i));
	}
    }
#endif /* WDB_DBG_DEBUG */

#else /* DBG_HARDWARE_BP */

    void wdbDbgHwBreakpoint() {}  /* This is just a stub to satisfy wdbALib.s */

#endif  /* DBG_HARDWARE_BP */
