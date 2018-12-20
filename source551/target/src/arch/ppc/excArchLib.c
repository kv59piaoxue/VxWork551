/* excArchLib.c - PowerPC exception handling facilities */

/* Copyright 1984-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02o,25aug03,mil  Fixed reg corruption of machine check stub code.
02o,25aug03,dtr  Wrap new ESF info mcesr with CPU==PPC85XX.
02n,13aug03,mil  Consolidated esr and mcsr as well as dear and mcar for e500.
02m,19nov02,mil  Updated support for PPC85XX.
02l,03aug02,pcs  Add support for PPC85XX and make it the same as PPC603 for
                 the present.
02k,22may02,mil  Added back excIntConnectTimer() for compatibility.
02j,08may02,mil  Relocated _EXC_OFF_PERF to avoid corruption by the extended
                 _EXC_ALTIVEC_UNAVAILABLE vector (SPR #76916).  Patched
                 calculation of wrong relocated vector offset (SPR #77145).
                 Added _EXC_OFF_THERMAL for PPC604 (SPR #77552).
02i,04apr02,pch  SPR 74348: Enable PPC Machine Check exception ASAP
02h,13nov01,yvp  Fix SPR 27916, 8179: Added extended (32-bit) vectors for 
                 exception handling.
02g,05oct01,pch  SPR's 68093 & 68585:  handle critical vectors in excVecGet()
		 and excVecSet().  Comment changes (only) supporting rework
		 of SPR 69328 fix
02f,15aug01,pch  Add PPC440 support
02e,14jun01,kab  Fixed Altivec Unavailable Exchandler, SPR 68206
02d,30nov00,s_m  fixed bus error handling for 405
02c,25oct00,s_m  renamed PPC405 cpu types
02b,13oct00,sm   modified machine check handling for PPC405
02a,06oct00,sm   PPC405 GF & PPC405 support
01z,12mar99,zl   added PowerPC 509 and PowerPC 555 support.
01y,24aug98,cjtc intEnt logging for PPC is now performed in a single step
		 instead of the two-stage approach which gave problems with
		 out-of-order timestamps in the event log.
	   	 Global evtTimeStamp no longer required (SPR 21868)
01x,18aug98,tpr  added PowerPC EC 603 support.
01w,09jan98,dbt  modified for new breakpoint scheme
01v,06aug97,tam  fixed problem with CE interrupt (SPR #8964)
01u,26mar97,tam	 added test for DBG_BREAK_INST in excExcHandle() (SPR #8217).
01t,26mar97,jdi,tam doc cleanup.
01s,20mar97,tam  added function excIntCrtConnect for PPC403 Critical Intr.
01r,24feb97,tam  added support for 403GC/GCX exceptions.
01q,10feb97,tam  added support to handle floating point exceptions (SPR #7840).
01p,05feb97,tpr  reawork PPC860 support in excExcHandle() (SPR 7881).
01o,16jan97,tpr  Changed CACHE_TEXT_UPDATE() address in excVecSet(). (SPR #7754)
01n,03oct96,tpr  Reworked excGetInfoFromESF () to include DSISR and DAR
		 registers for PPC860 (SPR# 7254)
01o,11jul96,pr   cleanup windview instrumentation 
01n,08jul96,pr   added windview instrumentation - conditionally compiled
01m,31may96,tpr  added PowerPC 860 support.
01l,12mar96,tam  re-worked exception handling for the PPC403 FIT and PIT 
		 interrupts. Added excIntConnectTimer().
01k,28feb96,tam  added excCrtConnect() for critical exceptions on the PPC403
		 cpu. 
01j,27feb96,ms   made excConnectCode use "stwu" instead of "addi".
                 fixed compiler warnings. Change logMsg to func_logMsg.
01i,23feb96,tpr  added excConnect() & excIntConnect(), renamed excCode[] 
		 by excConnectCode.
01h,05oct95,tpr  changed excCode[] code.
01g,23may95,caf  fixed unterminated comment in version 01f.
01f,22may95,caf  enable PowerPC 603 MMU.
01e,09feb95,yao  changed machine check exception handler to excCrtStub for
		 PPC403.
01d,07feb95,yao  fixed excExcHandler () for PPC403.  removed _AIX_TOOL support.
01c,02feb95,yao  changed to set timer exceptions to excClkStub for PPC403.
		 changed to call vxEvpr{S,G}et for PPC403.
01b,07nov94,yao  cleanup.
01a,09sep94,yao  written.
*/

/*
This module provides architecture-dependent facilities for handling PowerPC 
exceptions.  See excLib for the portions that are architecture independent.

INITIALIZATION
Initialization of exception handling facilities is in two parts.  First,
excVecInit() is called to set all the PowerPC exception, trap, and interrupt
vectors to the default handlers provided by this module.  The rest of this
package is initialized by calling excInit() (in excLib), which spawns the
exception support task, excTask(), and creates the pipe used to communicate
with it.  See the manual entry for excLib for more information.

SEE ALSO: excLib,
.pG "Debugging"
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "esf.h"
#include "iv.h"
#include "sysLib.h"
#include "intLib.h"
#include "msgQLib.h"
#include "signal.h"
#include "cacheLib.h"
#include "errnoLib.h"
#include "string.h"
#include "rebootLib.h"
#include "excLib.h"
#include "vxLib.h"
#include "private/funcBindP.h"
#include "private/sigLibP.h"
#include "private/taskLibP.h"
#include "wdb/wdbDbgLib.h"
#ifdef _WRS_ALTIVEC_SUPPORT
#include "altivecLib.h"
#endif /* _WRS_ALTIVEC_SUPPORT */

typedef	struct excTbl
    {
    UINT32 vecOff;		/* vector offset */
    STATUS (*excCnctRtn) ();	/* routine to connect the exception handler*/
    void   (*excHandler) ();	/* exception handler routine */
    UINT32 vecOffReloc;		/* vector offset relocation address */
    } EXC_TBL;

/* externals  */

IMPORT FUNCPTR	excExcepHook;    /* add'l rtn to call when exceptions occur */
IMPORT void	excEnt (void);	 /* exception entry routine */
IMPORT void	excExit (void);	 /* exception exit routine */
#ifdef	_PPC_MSR_CE
IMPORT void	excCrtExit (void); /* critical exception stub  */
IMPORT void	excCrtEnt (void);  /* critical exception stub  */
IMPORT void	intCrtExit (void); /* external critical exception stub  */
IMPORT void	intCrtEnt (void);  /* external critical exception stub  */
IMPORT FUNCPTR	_dbgDsmInstRtn;
#endif 	/* _PPC_MSR_CE */
#ifdef	_PPC_MSR_MCE
IMPORT void	excMchkExit (void); /* machine check exception stub  */
IMPORT void	excMchkEnt (void);  /* machine check exception stub  */
#endif 	/* _PPC_MSR_MCE */
IMPORT void	intEnt (void);	 /* interrupt entry routine */
IMPORT void	intExit (void);	 /* interrupt exit routine */
IMPORT void     excEPSet (FUNCPTR *);

/* globals */

FUNCPTR _func_excTrapRtn = NULL;	/* trap handling routine */

/* 
 * Option to use extended (full 32-bit) vectors to jump from the vector table 
 * to handler functions. Normally we use a 26-bit address, which suffices for
 * a vast majority of functions. However a 26-bit address restricts branches
 * to within 32MB which may be a problem for some systems. 
 * 
 * Setting excExtendedVectors to TRUE enables branching to an absolute 32-bit
 * address. This option increases interrupt latency by about 20%, but there is
 * no other choice left when the handler routine is more than 32MB away.
 */

BOOL	excExtendedVectors = FALSE;	/* extended exception stubs flag */

/* Macro to sign-extend a 26-bit integer value */

#define SEXT_26BIT(x) (((0x03ffffff & (INSTR) (x)) ^ 0x02000000) - 0x02000000)
#define SPR_SET(x) (((((x) & 0x1f) << 5) | (((x) & 0x3e0) >> 5)) << 11)


/* locals */

LOCAL FUNCPTR *	excVecBase = NULL;	/* exception vector base address */

LOCAL int       entOffset, exitOffset, isrOffset;

#ifdef _EXC_OFF_CRTL
LOCAL int       entCrtOffset, exitCrtOffset, isrCrtOffset;
#endif /* _EXC_OFF_CRTL */

LOCAL int	excGetInfoFromESF (FAST int vecNum, FAST ESFPPC *pEsf,
			      EXC_INFO *pExcInfo);

/*
 * Vector type definitions for local function excConnectVector()
 */
#define VEC_TYPE_UNDEF	0		/* to catch default values */
#define VEC_TYPE_NORM	1		/* normal vector type */
#define VEC_TYPE_CRT	2		/* critical vector type */
#define VEC_TYPE_MCHK	3		/* machine check vector type */

LOCAL STATUS excConnectVector (
    INSTR 	* newVector,		/* calculated exc vector */
    int           vecType,		/* norm/crit/mchk? */
    VOIDFUNCPTR	  entry,		/* handler entry */
    VOIDFUNCPTR	  routine,		/* routine to be called */
    VOIDFUNCPTR	  exit			/* handler exit */
    );

/* forward declarations */

STATUS      excRelocConnect (VOIDFUNCPTR *, VOIDFUNCPTR, VOIDFUNCPTR *);
STATUS      excRelocIntConnect (VOIDFUNCPTR *, VOIDFUNCPTR, VOIDFUNCPTR *);
STATUS      excRelocCrtConnect (VOIDFUNCPTR *, VOIDFUNCPTR, VOIDFUNCPTR *);
STATUS      excRelocIntCrtConnect (VOIDFUNCPTR *, VOIDFUNCPTR, VOIDFUNCPTR *);
STATUS      excRelocMchkConnect (VOIDFUNCPTR *, VOIDFUNCPTR, VOIDFUNCPTR *);
UINT32      vecOffRelocMatch (UINT32 vector);
UINT32      vecOffRelocMatchRev (UINT32 vector);
void        excExcHandle (ESFPPC * pEsf);
void        excIntHandle ();
void        excVecSet (FUNCPTR * vector, FUNCPTR function);
FUNCPTR *   excVecBaseGet (void);
#ifdef IVOR0
void        excIvorInit (void);
#endif

/*
 * Exception vector table
 *
 * Each entry in the exception vector table is consists of:
 * - the vector offset (from the vector base address) of the exception type
 * - the connect routine to be used, and must be one of:
 *   excConnect()        or  excRelocConnect()
 *   excIntConnect()     or  excRelocIntConnect()
 *   excCrtConnect()     or  excRelocCrtConnect()
 *   excIntCrtConnect()  or  excRelocIntCrtConnect()
 *   excMchkConnect()    or  excRelocMchkConnect()
 *   excIntConnectTimer() (phasing out)
 * - the handler routine, which is one of:
 *   excExcHandle()
 *   excIntHandle()
 * - the relocated vector offset (from the vector base address)
 *
 * The original implementation of the exception handling routines do not
 * have facility to relocate vectors.  To find out the vector offset of
 * the exception that causes the instance of excEnt()/intEnt() to run, a
 * pre-computed value is subtracted from the beginning of the stub whose
 * address is put into LR by the bl excEnt or bl intEnt in the stub.
 * However, a stub which is relocated to another address will cause
 * the calculation in excEnt() and intEnt() to yield a wrong vector.
 * With SPRG0-SPRG3 all used up, the same excEnt()/intEnt() routines used
 * for both the un-relocated and relocated cases cannot find an efficient
 * way to calculate the right vector offset.
 *
 * As a temporary workaround, excEnt() and intEnt() are hard coded to
 * detect the relocated vectors and patch them up with the right
 * values before saving them to the ESF.  This causes limitations if
 * a user wants to install their own exception handling routines that
 * span through a relocated vector address.  This also means that they
 * need to treat the relocated vectors as special cases.  They need to
 * use excVecSet() with the relocated vector offset instead of the
 * original vector offset.  Ditto to excVecGet().  Note also that adding
 * any relocated vectors require to add the patch up code in excEnt()
 * and/or intEnt() in excALib.s and/or intALib.s respectively.
 */

LOCAL EXC_TBL excBlTbl[] =
    {
#if	( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) )
    {_EXC_OFF_CRTL,     excIntCrtConnect, excIntHandle, 0}, /* crit int */
    {_EXC_OFF_MACH,     excCrtConnect,    excExcHandle, 0}, /* machine chk */
    {_EXC_OFF_PROT,     excConnect,       excExcHandle, 0}, /* protect viol */
    {_EXC_OFF_INST,	excConnect,	  excExcHandle, 0}, /* instr access */
    {_EXC_OFF_INTR,	excIntConnect,    excIntHandle, 0}, /* ext int */
    {_EXC_OFF_ALIGN,	excConnect,	  excExcHandle, 0}, /* alignment */
    {_EXC_OFF_PROG,	excConnect,	  excExcHandle, 0}, /* program */
# if (CPU == PPC405F)	/* 405GF supports a FPU */
    {_EXC_OFF_FPU,	excConnect,	  excExcHandle, 0}, /* fp unavail */
# endif
    {_EXC_OFF_SYSCALL,	excConnect,	  excExcHandle, 0}, /* system call */
#ifdef _EXC_NEW_OFF_PIT  /* prog timer */
    {_EXC_OFF_PIT,	excRelocIntConnect, excIntHandle, _EXC_NEW_OFF_PIT},
#else
    {_EXC_OFF_PIT,	excIntConnect,    excIntHandle, 0}, /* prog timer */
#endif  /* _EXC_NEW_OFF_PIT */
#ifdef _EXC_NEW_OFF_FIT  /* fixed timer */
    {_EXC_OFF_FIT,	excRelocIntConnect, excIntHandle, _EXC_NEW_OFF_FIT},
#else
    {_EXC_OFF_FIT,	excIntConnect,    excIntHandle, 0}, /* fixed timer */
#endif  /* _EXC_NEW_OFF_FIT */
    {_EXC_OFF_WD,	excIntCrtConnect, excIntHandle, 0}, /* watchdog */
    {_EXC_OFF_DATA_MISS,excConnect,       excExcHandle, 0}, /* data TLB miss */
    {_EXC_OFF_INST_MISS,excConnect,       excExcHandle, 0}, /* inst TLB miss */
    {_EXC_OFF_DBG,	excCrtConnect,    excExcHandle, 0}, /* debug events */

#elif	(CPU == PPC440)
    {_EXC_OFF_CRTL,	excIntCrtConnect, excIntHandle, 0}, /* critical int */
    {_EXC_OFF_MACH,	excCrtConnect,    excExcHandle, 0}, /* machine chk  */
    {_EXC_OFF_DATA,	excConnect,	  excExcHandle, 0}, /* data storage */
    {_EXC_OFF_INST,	excConnect,	  excExcHandle, 0}, /* instr access */
    {_EXC_OFF_INTR,	excIntConnect,    excIntHandle, 0}, /* ext int */
    {_EXC_OFF_ALIGN,	excConnect,	  excExcHandle, 0}, /* alignment */
    {_EXC_OFF_PROG,	excConnect,	  excExcHandle, 0}, /* program */
    {_EXC_OFF_FPU,	excConnect,	  excExcHandle, 0}, /* fp unavail */
    {_EXC_OFF_SYSCALL,	excConnect,	  excExcHandle, 0}, /* system call */
    {_EXC_OFF_APU,	excConnect,	  excExcHandle, 0}, /* auxp unavail*/
    {_EXC_OFF_DECR,	excIntConnect,    excIntHandle, 0}, /* decrementer */
    {_EXC_OFF_FIT,	excIntConnect,    excIntHandle, 0}, /* fixed timer */
    {_EXC_OFF_WD,	excIntCrtConnect, excIntHandle, 0}, /* watchdog */
    {_EXC_OFF_DATA_MISS,excConnect,	  excExcHandle, 0}, /* data TLB miss */
    {_EXC_OFF_INST_MISS,excConnect,	  excExcHandle, 0}, /* inst TLB miss */
    {_EXC_OFF_DBG,	excCrtConnect,    excExcHandle, 0}, /* debug events */

#elif	(CPU == PPC85XX)	/* placed here to reflect on 440 */
    {_EXC_OFF_CRTL,	excIntCrtConnect, excIntHandle, 0}, /* critical int */
    {_EXC_OFF_MACH,	excMchkConnect,   excExcHandle, 0}, /* machine chk  */
    {_EXC_OFF_DATA,	excConnect,	  excExcHandle, 0}, /* data storage */
    {_EXC_OFF_INST,	excConnect,	  excExcHandle, 0}, /* instr access */
    {_EXC_OFF_INTR,	excIntConnect,    excIntHandle, 0}, /* ext int */
    {_EXC_OFF_ALIGN,	excConnect,	  excExcHandle, 0}, /* alignment */
    {_EXC_OFF_PROG,	excConnect,	  excExcHandle, 0}, /* program */
    {_EXC_OFF_FPU,	excConnect,	  excExcHandle, 0}, /* fp unavail */
    {_EXC_OFF_SYSCALL,	excConnect,	  excExcHandle, 0}, /* system call */
    {_EXC_OFF_APU,	excConnect,	  excExcHandle, 0}, /* auxp unavail*/
    {_EXC_OFF_DECR,	excIntConnect,    excIntHandle, 0}, /* decrementer */
    {_EXC_OFF_FIT,	excIntConnect,    excIntHandle, 0}, /* fixed timer */
    {_EXC_OFF_WD,	excIntCrtConnect, excIntHandle, 0}, /* watchdog */
    {_EXC_OFF_DATA_MISS,excConnect,	  excExcHandle, 0}, /* data TLB miss */
    {_EXC_OFF_INST_MISS,excConnect,	  excExcHandle, 0}, /* inst TLB miss */
    {_EXC_OFF_DBG,	excCrtConnect,    excExcHandle, 0}, /* debug events */
    {_EXC_OFF_SPE,	excConnect,       excExcHandle, 0}, /* SPE */
    {_EXC_OFF_VEC_DATA,	excConnect,       excExcHandle, 0}, /* vector data */
    {_EXC_OFF_VEC_RND,	excConnect,       excExcHandle, 0}, /* vector round */
    {_EXC_OFF_PERF_MON,	excConnect,       excExcHandle, 0}, /* perf monitor */

#elif	((CPU == PPC509) || (CPU == PPC555))
    {_EXC_OFF_RESET,	excConnect,	  excExcHandle, 0}, /* system reset */
    {_EXC_OFF_MACH,	excConnect,	  excExcHandle, 0}, /* machine chk */
    {_EXC_OFF_INTR,	excIntConnect,    excIntHandle, 0}, /* ext int */
    {_EXC_OFF_ALIGN,	excConnect,	  excExcHandle, 0}, /* alignment */
    {_EXC_OFF_PROG,	excConnect,	  excExcHandle, 0}, /* program */
    {_EXC_OFF_FPU,	excConnect,	  excExcHandle, 0}, /* fp unavail */
    {_EXC_OFF_DECR,	excIntConnect,    excIntHandle, 0}, /* decrementer */
    {_EXC_OFF_SYSCALL,	excConnect,	  excExcHandle, 0}, /* system call */
    {_EXC_OFF_TRACE,	excConnect,	  excExcHandle, 0}, /* trace except */
    {_EXC_OFF_FPA,	excConnect,	  excExcHandle, 0}, /* fp assist */
    {_EXC_OFF_SW_EMUL,	excConnect,	  excExcHandle, 0}, /* sw emul */
# if	(CPU == PPC555)
    {_EXC_OFF_IPE,	excConnect,	  excExcHandle, 0}, /* instr prot */
    {_EXC_OFF_DPE,	excConnect,	  excExcHandle, 0}, /* data prot */
# endif	(CPU == PPC555)
    {_EXC_OFF_DATA_BKPT,excConnect,	  excExcHandle, 0}, /* data breakpt */
    {_EXC_OFF_INST_BKPT,excConnect,	  excExcHandle, 0}, /* instr breakpt */
    {_EXC_OFF_PERI_BKPT,excConnect,	  excExcHandle, 0}, /* peripheral BP */
    {_EXC_OFF_NM_DEV_PORT, excConnect,	  excExcHandle, 0}, /* non maskable */

#elif	(CPU == PPC601)
    {_EXC_OFF_RESET,	excConnect,	  excExcHandle, 0}, /* system reset */
    {_EXC_OFF_MACH,	excConnect,	  excExcHandle, 0}, /* machine chk */
    {_EXC_OFF_DATA,	excConnect,	  excExcHandle, 0}, /* data access */
    {_EXC_OFF_INST,	excConnect,	  excExcHandle, 0}, /* instr access */
    {_EXC_OFF_INTR,	excIntConnect,    excIntHandle, 0}, /* ext int */
    {_EXC_OFF_ALIGN,	excConnect,	  excExcHandle, 0}, /* alignment */
    {_EXC_OFF_PROG,	excConnect,	  excExcHandle, 0}, /* program */
    {_EXC_OFF_FPU,	excConnect,	  excExcHandle, 0}, /* fp unavail */
    {_EXC_OFF_DECR,	excIntConnect,    excIntHandle, 0}, /* decrementer */
    {_EXC_OFF_IOERR,	excConnect,	  excExcHandle, 0}, /* i/o ctrl err */
    {_EXC_OFF_SYSCALL,	excConnect,	  excExcHandle, 0}, /* system call */
    {_EXC_OFF_RUN_TRACE,excConnect,	  excExcHandle, 0}, /* run/trace */

#elif	((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604))
    {_EXC_OFF_RESET,	excConnect,	  excExcHandle, 0}, /* system reset */
    {_EXC_OFF_MACH,	excConnect,	  excExcHandle, 0}, /* machine chk */
    {_EXC_OFF_DATA,	excConnect,	  excExcHandle, 0}, /* data access */
    {_EXC_OFF_INST,	excConnect,	  excExcHandle, 0}, /* instr access */
    {_EXC_OFF_INTR,	excIntConnect,    excIntHandle, 0}, /* ext int */
    {_EXC_OFF_ALIGN,	excConnect,	  excExcHandle, 0}, /* alignment */
    {_EXC_OFF_PROG,	excConnect,	  excExcHandle, 0}, /* program */
    {_EXC_OFF_FPU,	excConnect,	  excExcHandle, 0}, /* fp unavail */
    {_EXC_OFF_DECR,	excIntConnect,    excIntHandle, 0}, /* decrementer */
    {_EXC_OFF_SYSCALL,	excConnect,	  excExcHandle, 0}, /* system call */
    {_EXC_OFF_TRACE,	excConnect,	  excExcHandle, 0}, /* trace excepti */
# if	((CPU == PPC603) || (CPU == PPCEC603))
    {_EXC_OFF_INST_MISS,excConnect,	  excExcHandle, 0}, /* i-trsl miss */
    {_EXC_OFF_LOAD_MISS,excConnect,       excExcHandle, 0}, /* d-trsl miss */
    {_EXC_OFF_STORE_MISS,  excConnect,	  excExcHandle, 0}, /* d-trsl miss */
# else	/* (CPU == PPC604) */
#ifdef _EXC_NEW_OFF_PERF  /* perf mon */
    {_EXC_OFF_PERF,	excRelocConnect,  excExcHandle, _EXC_NEW_OFF_PERF},
#else
    {_EXC_OFF_PERF,	excConnect,	  excExcHandle, 0}, /* perf mon */
#endif  /* _EXC_NEW_OFF_PERF */
#  ifdef _WRS_ALTIVEC_SUPPORT
    {_EXC_ALTIVEC_UNAVAILABLE, excConnect,excExcHandle, 0}, /* altivec unav */
    {_EXC_ALTIVEC_ASSIST,  excConnect,   excExcHandle, 0},  /* altivec asst */
#  endif /* _WRS_ALTIVEC_SUPPORT */
    {_EXC_OFF_THERMAL, 	excConnect,	  excExcHandle, 0}, /* thermal */
# endif	/* (CPU == PPC604) */
    {_EXC_OFF_INST_BRK,	excConnect,	  excExcHandle, 0}, /* instr BP */
    {_EXC_OFF_SYS_MNG,	excConnect,	  excExcHandle, 0}, /* sys mgt*/

#elif	(CPU == PPC860)
    {_EXC_OFF_RESET,	excConnect,	  excExcHandle, 0}, /* system reset */
    {_EXC_OFF_MACH,	excConnect,	  excExcHandle, 0}, /* machine chk */
    {_EXC_OFF_DATA,	excConnect,	  excExcHandle, 0}, /* data access */
    {_EXC_OFF_INST,	excConnect,	  excExcHandle, 0}, /* instr access */
    {_EXC_OFF_INTR,	excIntConnect,    excIntHandle, 0}, /* ext int */
    {_EXC_OFF_ALIGN,	excConnect,	  excExcHandle, 0}, /* alignment */
    {_EXC_OFF_PROG,	excConnect,	  excExcHandle, 0}, /* program */
    {_EXC_OFF_FPU,	excConnect,	  excExcHandle, 0}, /* fp unavail */
    {_EXC_OFF_DECR,	excIntConnect,    excIntHandle, 0}, /* decrementer */
    {_EXC_OFF_SYSCALL,	excConnect,	  excExcHandle, 0}, /* system call */
    {_EXC_OFF_TRACE,	excConnect,	  excExcHandle, 0}, /* trace except */
    {_EXC_OFF_SW_EMUL,	excConnect,	  excExcHandle, 0}, /* sw emul */
    {_EXC_OFF_INST_MISS,excConnect,	  excExcHandle, 0}, /* inst TLB Miss */
    {_EXC_OFF_DATA_MISS,excConnect,	  excExcHandle, 0}, /* data TLB Miss */
    {_EXC_OFF_INST_ERROR,  excConnect,	  excExcHandle, 0}, /* inst TLB err */
    {_EXC_OFF_DATA_ERROR,  excConnect,	  excExcHandle, 0}, /* data TLB err */
    {_EXC_OFF_DATA_BKPT,excConnect,	  excExcHandle, 0}, /* data BP */
    {_EXC_OFF_INST_BKPT,excConnect,	  excExcHandle, 0}, /* instr BP */
    {_EXC_OFF_PERI_BKPT,excConnect,	  excExcHandle, 0}, /* peripheral BP */
    {_EXC_OFF_NM_DEV_PORT,  excConnect,	  excExcHandle, 0}, /* non maskable */

#endif	/* 40x : 440 : 5xx : 601 : 603 | 604 : 860 */

    {0,  (STATUS (*)()) NULL,  (void (*) ()) NULL,  0},      /* end of table */
    };

/*
 * XXX - The special handling of critical events during normal ones seems
 *       bogus:  if the critical handler does proper state-save/restore
 *       it should be able to safely interrupt the normal handler.
 *
 * It is necessary to clear the MSR[CE] bit upon an external interrupt
 * on the PowerPC 403 architecture, to prevent this interrupt being
 * interrupted by a critical interrupt before the context is saved.
 * There's still a window of 5 instructions were the external interrupt 
 * can be interrupted. This is taken care of, in the critical interrupt
 * entry code (intCrtEnt), by saving SPRG3 before using it and restoring
 * its original value later on.
 *
 * In excConnectCode,
 *   xxxEnt is either intEnt or excEnt.
 *   xxxHandler is either excIntHandle or excExcHandle.
 *   xxxExit is either intExit or excExit.
 *
 * Changes here may affect code in excALib.s:excEnt(), e.g. the offsets
 * used in calculating the original vector address from the LR value.
 */

LOCAL INSTR excConnectCode[]=
    {
    /*  data	      word    byte     opcode  operands		      */
    0x7c7343a6,	    /*  0     0x00     mtspr   SPRG3, p0	      */
#ifdef	_EXC_OFF_CRTL
    0x7c6000a6,	    /*  1     0x04     mfmsr   p0		      */
    0x546303da,	    /*  2     0x08     rlwinm  p0,p0,0,15,13  clear MSR [CE] */
    0x7c600124,	    /*  3     0x0c     mtmsr   p0		      */
    0x4c00012c,	    /*  4     0x10     isync			      */
#endif	/* _EXC_OFF_CRTL */
    /* If _EXC_OFF_CRTL, then add 4 words/0x10 bytes to following offsets */
    0x7c6802a6,	    /*  1     0x04     mflr    p0		      */
    0x48000001,	    /*  2(6)  0x08/18  bl      xxxEnt		      */
    0x38610000,	    /*  3     0x0c     addi    r3, sp, 0	      */
    0x9421fff0,	    /*  4     0x10     stwu    sp, -FRAMEBASESZ(sp)   */ 
    0x48000001,	    /*  5(9)  0x14/24  bl      xxxHandler	      */
    0x38210010,	    /*  6     0x18     addi    sp, sp, FRAMEBASESZ    */
    0x48000001	    /*  7(11) 0x1c/2c  bl      xxxExit		      */
    };

/* 
 * Stub code for extended-branch vectors. This stub will be installed into
 * the trap table if excExtendedVectors is TRUE. Branches to the xxxEnt,
 * xxxExit and xxxHandler functions are made via an absolute 32-bit address
 * stored in the LR.
 */

LOCAL INSTR excExtConnectCode[]=
    {
    /*  data	      word    byte     opcode  operands		      */
    0x7c7343a6,	    /*  0     0x00     mtspr	  SPRG3, p0	      */
#ifdef	_EXC_OFF_CRTL
    0x7c6000a6,	    /*  1     0x04     mfmsr   p0 		      */
    0x546303da,	    /*  2     0x08     rlwinm  p0,p0,0,15,13  clear MSR [CE] */
    0x7c600124,	    /*  3     0x0c     mtmsr   p0 		      */
    0x4c00012c,	    /*  4     0x19     isync    		      */
#endif	/* _EXC_OFF_CRTL */
    /* If _EXC_OFF_CRTL, then add 4 words/0x10 bytes to following offsets */
    0x7c6802a6,	    /*  1     0x04     mflr    p0                     */
    0x7c7043a6,	    /*  2     0x08     mtspr   SPRG0, p0              */
    0x3c600000,	    /*  3(7)  0x0c     lis     p0, HI(xxxEnt)         */
    0x60630000,	    /*  4(8)  0x10     ori     p0, p0, LO(xxxEnt)     */
    0x7c6803a6,	    /*  5     0x14     mtlr    p0                     */
    0x7c7042a6,	    /*  6     0x18     mfspr   p0, SPRG0              */
    0x4e800021,	    /*  7     0x1c     blrl                           */
    0x3c600000,	    /*  8(12) 0x20     lis     p0, HI(xxxHandler)     */
    0x60630000,	    /*  9(13) 0x24     ori     p0, p0, LO(xxxHandler) */
    0x7c6803a6,	    /* 10     0x28     mtlr    p0                     */
    0x38610000,	    /* 11     0x2c     addi    p0, sp, 0              */
    0x9421fff0,     /* 12     0x30     stwu    sp, -FRAMEBASESZ(sp)   */ 
    0x4e800021,	    /* 13     0x34     blrl                           */
    0x38210010,	    /* 14     0x38     addi    sp, sp, FRAMEBASESZ    */
    0x3c600000,	    /* 15(19) 0x3c     lis     p0, HI(xxxExit)        */
    0x60630000,	    /* 16(20) 0x40     ori     p0, p0, LO(xxxExit)    */
    0x7c6803a6,	    /* 17     0x44     mtlr    p0                     */
    0x4e800021	    /* 18     0x48     blrl                           */
    };

#ifdef	_EXC_OFF_CRTL
/*
 * In excCrtConnectCode,
 *   xxxCrtEnt is either intCrtEnt or excCrtEnt.
 *   xxxHandler is either excIntHandle or excExcHandle.
 *   xxxCrtExit is either intCrtExit or excCrtExit.
 *
 * Changes here may affect code in excALib.s:excCrtEnt(), e.g. the offset
 * used in calculating the original vector address from the LR value.
 *
 * In order to determine which type of vector is being accessed, code
 * in excVecGet() and excVecSet() depends on excCrtConnectCode[0] and
 * excConnectCode[0] being different.
 */

LOCAL INSTR excCrtConnectCode[]=
    {
    /*  data	      word  byte  opcode  operands		     */
    0x7c7243a6,	    /*  0   0x00  mtspr   SPRG2, p0 # SPRG4 for mchk */
    0x7c6802a6,	    /*  1   0x04  mflr    p0			     */
    0x48000003,	    /*  2   0x08  bla     xxxCrtEnt		     */
    0x38610000,	    /*  3   0x0c  addi    r3, sp, 0		     */
    0x9421fff0,	    /*  4   0x10  stwu    sp, -FRAMEBASESZ(sp)	     */ 
    0x48000003,	    /*  5   0x14  bla     xxxHandler		     */
    0x38210010,	    /*  6   0x18  addi    sp, sp, FRAMEBASESZ	     */
    0x48000003	    /*  7   0x1c  bla     xxxCrtExit		     */
    };

LOCAL INSTR excExtCrtConnectCode[]=
    {
    /*  data	      word  byte  opcode  operands		     */
    0x7c7243a6,	    /*  0   0x00  mtspr   SPRG2, p0 # SPRG4 for mchk */
    0x7c6802a6,	    /*  1   0x00  mflr    p0                         */
    0x7c7043a6,	    /*  2   0x00  mtspr	  SPRG0, p0                  */
    0x3c600000,	    /*  3   0x00  lis	  p0, HI(xxxEnt)             */
    0x60630000,	    /*  4   0x00  ori	  p0, p0, LO(xxxEnt)         */
    0x7c6803a6,	    /*  5   0x00  mtlr	  p0                         */
    0x7c7042a6,	    /*  6   0x00  mfspr	  p0, SPRG0                  */
    0x4e800021,	    /*  7   0x00  blrl                               */
    0x3c600000,	    /*  8   0x00  lis	  p0, HI(xxxHandler)         */
    0x60630000,	    /*  9   0x00  ori	  p0, p0, LO(xxxHandler)     */
    0x7c6803a6,	    /*  10  0x00  mtlr	  p0                         */
    0x38610000,	    /*  11  0x00  addi	  p0, sp, 0                  */
    0x9421fff0,     /*  12  0x00  stwu    sp, -FRAMEBASESZ(sp)       */ 
    0x4e800021,	    /*  13  0x00  blrl                               */
    0x38210010,	    /*  14  0x00  addi	  sp, sp, FRAMEBASESZ        */
    0x3c600000,	    /*  15  0x00  lis	  p0, HI(xxxExit)            */
    0x60630000,	    /*  16  0x00  ori	  p0, p0, LO(xxxExit)        */
    0x7c6803a6,	    /*  17  0x00  mtlr	  p0                         */
    0x4e800021	    /*  18  0x00  blrl                               */
    };

/* Word offsets to the branch instructions in
 * the excConnectCode and excCrtConnectCode arrays
 *
 * Changes affecting ENT_OFF or ENT_CRT_OFF will require corresponding
 * changes in excALib.s:excEnt() and excCrtEnt() when calculating the
 * original vector address from the LR value.
 */

#   define	ENT_OFF		 6	/* offset for intEnt/excEnt */
#   define	ISR_OFF		 9	/* offset for ISR or exc. handler */
#   define	EXIT_OFF	 11	/* offset for intExit/excExit */
#   define	EXT_ENT_OFF	 7	/* offset for ext intEnt/excEnt */
#   define	EXT_ISR_OFF	 12	/* offset for ext ISR or exc handler */
#   define	EXT_EXIT_OFF	 19	/* offset for ext intExit/excExit */
#   define	EXT_ENT_CRT_OFF	 3	/* offset for ext intEnt/excEnt */
#   define	EXT_ISR_CRT_OFF	 8	/* offset for ext ISR or exc handler */
#   define	EXT_EXIT_CRT_OFF 15	/* offset for ext intExit/excExit */
#   define	ENT_CRT_OFF	 2	/* offset for intEnt/excEnt */
#   define	ISR_CRT_OFF	 5	/* offset for ISR or exc. handler */
#   define	EXIT_CRT_OFF	 7	/* offset for intCrtExit/excCrtExit */
#else	/* _EXC_OFF_CRTL */
#   define	ENT_OFF		 2	/* offset for intEnt/excEnt */
#   define	ISR_OFF		 5	/* offset for ISR or exc. handler */
#   define	EXIT_OFF	 7	/* offset for intExit/excExit */
#   define	EXT_ENT_OFF	 3	/* offset for ext intEnt/excEnt */
#   define	EXT_ISR_OFF	 8	/* offset for ext ISR or exc handler */
#   define	EXT_EXIT_OFF	 15	/* offset for ext intExit/excExit */
#endif	/* _EXC_OFF_CRTL */

/*******************************************************************************
*
* excVecInit - initialize the exception vectors
*
* This routine sets up PowerPC exception vectors to point to the 
* appropriate default exception handlers.
*
* WHEN TO CALL
* This routine is usually called from the system start-up routine
* usrInit() in usrConfig.c, before interrupts are enabled.
*
* RETURNS: OK (always).
*
* SEE ALSO: excLib
*
* INTERNAL:  excCnctRtn is one of excConnect, excIntConnect,
*            excCrtConnect, excIntCrtConnect, or the reloc versions of
*            them as excReloc*Connect
*/

STATUS excVecInit (void)
    {
    FAST int ix;

    /* 
     * Set the values of entOffset, exitOffset and isrOffset once. These are
     * offsets into the exception stubs where the respective ent, exit and ISR
     * function addresses are located. 
     * These offsets are set once during the lifetime of the system, so they
     * cannot (and are not meant to) handle runtime changes in the value of
     * the global excExtendedVectors.
     */
    if (excExtendedVectors == TRUE)
	{
	entOffset     = EXT_ENT_OFF;
	isrOffset     = EXT_ISR_OFF;
	exitOffset    = EXT_EXIT_OFF;
#ifdef _EXC_OFF_CRTL
	entCrtOffset  = EXT_ENT_CRT_OFF;
	isrCrtOffset  = EXT_ISR_CRT_OFF;
	exitCrtOffset = EXT_EXIT_CRT_OFF;
#endif  /* _EXC_OFF_CRTL */
	}
    else
        {
	entOffset     = ENT_OFF;
	isrOffset     = ISR_OFF;
	exitOffset    = EXIT_OFF;
#ifdef _EXC_OFF_CRTL
	entCrtOffset  = ENT_CRT_OFF;
	isrCrtOffset  = ISR_CRT_OFF;
	exitCrtOffset = EXIT_CRT_OFF;
#endif  /* _EXC_OFF_CRTL */
        }


    for (ix = 0; excBlTbl[ix].excHandler != (void (*)()) NULL; ix++)
	{
        /* harmless extra 3rd argument to non-Reloc exc*Connect */
	excBlTbl[ix].excCnctRtn ((VOIDFUNCPTR *) excBlTbl[ix].vecOff, 
				 (VOIDFUNCPTR ) excBlTbl[ix].excHandler,
                                 (VOIDFUNCPTR *) excBlTbl[ix].vecOffReloc);
	}
#if	(defined(IVPR) || defined(EVPR))
    excVecBaseSet((FUNCPTR *)NULL);	/* may want *excVecBase in future */
#endif	/* defined(IVPR) || defined(EVPR) */
#ifdef	IVOR0
    excIvorInit();
#endif	/* IVOR0 */

    /* Now that the vectors are set up, enable Machine Check exceptions */
    vxMsrSet (vxMsrGet() | _PPC_MSR_ME);

    return (OK);
    }

/*******************************************************************************
*
* blCompute - compute branch-and-link instruction to reach a specified address
*
* This routine attempts to find a single branch-and-link (i.e BL or BLA) 
* instruction, located at address branch, that can reach address target.
*
* RETURNS: The actual branch-and-link instruction opcode, 
*          or zero if the target address is too far away for a BL/BLA instr.
*
* INTERNAL:  Used by the exc*Connect routines.
*/

LOCAL INSTR blCompute
    (
    VOIDFUNCPTR target,			/* target address */
    INSTR * branch			/* address of branch instruction */
    )
    {
    INSTR offset;

    /* Try a PC-relative branch (bl). */

    offset = ((int)target - (int)branch);
    if (SEXT_26BIT(offset) == offset)
	return (0x48000001 | (offset & 0x03fffffc));

    /* Next try an absolute branch (bla). */

    offset = (int)target;
    if (SEXT_26BIT(offset) == offset)
	return (0x48000003 | (offset & 0x03fffffc));

    /* Address cannot be reached by a short branch instruction at <branch>. */

    return (INSTR) 0;
    }

/*******************************************************************************
*
* blExtract - compute target address of a specified branch instruction
*
* This routine returns the destination address of a branch instruction inst
* which is located at address.
*
* RETURNS: target address of the branch.
*/

LOCAL INSTR blExtract
    (
    INSTR   inst,			/* branch instruction word */
    INSTR * address			/* address of branch instruction */
    )
    {
    INSTR target = SEXT_26BIT(inst & 0x03fffffc);

    /* If the AA bit is not set, then this is a PC-relative branch. */

    if ( (inst & 0x2) == 0 )
	target += (INSTR) address;

    return target;
    }

/***************************************************************************
*
* vecOffRelocMatch - lookup vector table for relocation offset
*
* This routine looks up the exception vector table excBlTbl[] for the vector
* offset specified.  If the vector offset is found to be relocated, it
* returns the relocated offset.  If it is not relocated, or if such an entry
* is not found, it returns the vector offset given to it as input.
* The status (found unrelocated, found relocated, not found) has no current
* use and thus is not returned to optimize performance.  This can be added
* in future if API not published by then.  Probably a user specified
* relocation table as well.
*
* RETURNS: The input vector offset if not relocated or if not found in
*          excBlTbl[], or the relocated vector offset value.
*
*/

UINT32 vecOffRelocMatch
    (
    UINT32 vector                       /* original vector to match */
    )
    {
    FAST int i = 0;

    while (excBlTbl[i].vecOff != 0)
        {
        if (excBlTbl[i].vecOff == vector)
            {
            if (excBlTbl[i].vecOffReloc == 0)
                return (vector);
            else
                return (excBlTbl[i].vecOffReloc);
            }
        i++;
        }
    return vector;
    }

/***************************************************************************
*
* vecOffRelocMatchRev - reverse lookup vector table for relocation offset
*
* This routine looks up the exception vector table excBlTbl[] for the
* relocated  vector offset specified.  If such a relocated vector offset
* is found, it returns the original offset.  If it has not been relocated,
* or if such an entry is not found, it returns the vector offset given to
* it as input.
*
* RETURNS: The input vector offset if not relocated or if not found in
*          excBlTbl[], or the relocated vector offset value.
*
*/

UINT32 vecOffRelocMatchRev
    (
    UINT32 vector                       /* relocated vector to match */
    )
    {
    FAST int i = 0;

    while (excBlTbl[i].vecOff != 0)
        {
        if (excBlTbl[i].vecOffReloc == vector)
                return (excBlTbl[i].vecOff);
        i++;
        }
    return vector;
    }

/*******************************************************************************
*
* excConnect - connect a C routine to an exception vector
*
* This routine connects a specified C routine to a specified exception
* vector.  An exception stub is created and in placed at <vector> in the
* exception table.  The address of <routine> is stored in the exception stub
* code.  When an exception occurs, the processor jumps to the exception stub
* code, saves the registers, and call the C routines.
*
* The routine can be any normal C code, except that it must not
* invoke certain operating system functions that may block or perform
* I/O operations.
*
* The registers are saved to an Exception Stack Frame (ESF) which is placed
* on the stack of the task that has produced the exception.  The ESF structure
* is defined in /h/arch/ppc/esfPpc.h.
*
* The only argument passed by the exception stub to the C routine is a pointer
* to the ESF containing the registers values.  The prototype of this C routine
* is as follows:
* .CS
*     void excHandler (ESFPPC *);
* .CE
*
* When the C routine returns, the exception stub restores the registers saved
* in the ESF and continues execution of the current task.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for a 26-bit offset.
* 
* SEE ALSO: excIntConnect(), excVecSet()
* 
*/

STATUS excConnect
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine               /* routine to be called */
    )
    {
    return ( excRelocConnect (vector, routine, (VOIDFUNCPTR *) 0) );
    }

/*******************************************************************************
*
* excRelocConnect - connect a C routine to an exception vector with possible
*                   relocation
*
* This routine is same as excConnect with an added parameter, which is
* the relocation offset of the vector to be installed.  If the extra
* parameter is non-zero, the vector is installed at this offset instead
* of the standard offset specified in the first parameter.  A branch
* instruction is then written to the original offset to reach the
* relocated vector.  A relative branch will be used, unless out of the
* 26-bit offset range where it will attempt an absolute branch.  The
* caller should take care of the branch instruction clobbering useful
* data specified by vector, including the stub being installed should
* the original offset overlaps the stub of the relocated vector.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for one branch instr.
*
*/

STATUS excRelocConnect
    (
    VOIDFUNCPTR * vector,		/* exception vector to attach to */
    VOIDFUNCPTR	  routine,		/* routine to be called */
    VOIDFUNCPTR * vectorReloc		/* relocated exception vector */
    )
    {
    FAST STATUS  rc;
    FAST INSTR   branch;
    FAST INSTR * newVector;
    FAST int     base = (int) excVecBaseGet ();

    if ((int) vectorReloc == 0)
        {
        newVector = (INSTR *) ( base | (int) vector );
        }
    else
        {
        vector = (VOIDFUNCPTR *) ( base | (int) vector );
        newVector = (INSTR *) ( base | (int) vectorReloc );
        }

    rc = excConnectVector(newVector, VEC_TYPE_NORM, excEnt, routine, excExit);

    if ( ((int) vectorReloc != 0) && (rc == OK) )
        {
        /* if relocated vector, write branch (with link bit cleared) */
        branch = blCompute ( (VOIDFUNCPTR) newVector, (INSTR *) vector );
        if (branch == 0)
            return ERROR;
        *vector = (VOIDFUNCPTR) (branch & 0xfffffffe);
        CACHE_TEXT_UPDATE ((void *) vector, sizeof(INSTR));
        }

    return (rc);
    }

/*******************************************************************************
*
* excIntConnect - connect a C routine to an asynchronous exception vector
*
* This routine connects a specified C routine to a specified asynchronous 
* exception vector, such as the external interrupt vector (0x500) and the
* decrementer vector (0x900).  An interrupt stub is created and placed at
* <vector> in the exception table.  The address of <routine> is stored in the
* interrupt stub code.  When the asynchronous exception occurs, the processor
* jumps to the interrupt stub code, saves only the requested registers, and
* calls the C routines.
*
* When the C routine is invoked, interrupts are still locked.  It is the
* C routine responsibility to re-enable interrupts.
*
* The routine can be any normal C code, except that it must not
* invoke certain operating system functions that may block or perform
* I/O operations.
*
* Before the requested registers are saved, the interrupt stub switches from the
* current task stack to the interrupt stack.  In the case of nested interrupts,
* no stack switching is performed, because the interrupt is already set.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for a 26-bit offset.
* 
* SEE ALSO: excConnect(), excVecSet()
*/

STATUS excIntConnect
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine               /* routine to be called */
    )
    {
    return ( excRelocIntConnect (vector, routine, (VOIDFUNCPTR *) 0) );
    }

/*******************************************************************************
*
* excRelocIntConnect - connect a C routine to an exception vector with
*                      possible relocation
*
* This routine is same as excIntConnect with an added parameter, which is
* the relocation offset of the vector to be installed.  If the extra
* parameter is non-zero, the vector is installed at this offset instead
* of the standard offset specified in the first parameter.  A branch
* instruction is then written to the original offset to reach the
* relocated vector.  A relative branch will be used, unless out of the
* 26-bit offset range where it will attempt an absolute branch.  The
* caller should take care of the branch instruction clobbering useful
* data specified by vector, including the stub being installed should
* the original offset overlaps the stub of the relocated vector.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for one branch instr.
*
*/

STATUS excRelocIntConnect
    (
    VOIDFUNCPTR * vector,		/* exception vector to attach to */
    VOIDFUNCPTR	  routine,		/* routine to be called */
    VOIDFUNCPTR * vectorReloc           /* relocated exception vector */
    )
    {
    FAST STATUS  rc;
    FAST INSTR   branch;
    FAST INSTR * newVector;
    FAST int     base = (int) excVecBaseGet ();

    if ((int) vectorReloc == 0)
        {
        newVector = (INSTR *) ( base | (int) vector );
        }
    else
        {
        vector = (VOIDFUNCPTR *) ( base | (int) vector );
        newVector = (INSTR *) ( base | (int) vectorReloc );
        }

    rc = excConnectVector(newVector, VEC_TYPE_NORM, intEnt, routine, intExit);

    if ( ((int) vectorReloc != 0) && (rc == OK) )
        {
        /* if relocated vector, write branch (with link bit cleared) */
        branch = blCompute ( (VOIDFUNCPTR) newVector, (INSTR *) vector );
        if (branch == 0)
            return ERROR;
        *vector = (VOIDFUNCPTR) (branch & 0xfffffffe);
        CACHE_TEXT_UPDATE ((void *) vector, sizeof(INSTR));
        }

    return (rc);
    }

/*******************************************************************************
*
* excConnectVector - connect a C routine to an asynchronous exception vector
*
* Code factored from original excIntConnect/excExcConnect.
*
* Should never be called directly except by 
*   excConnect(),        or excRelocConnect()
*   excIntConnect(),     or excRelocIntConnect()
*   excCrtConnect(),     or excRelocCrtConnect()
*   excIntCrtConnect(),  or excRelocIntCrtConnect()
*   excMchkConnect(),    or excRelocMchkConnect()
*   excIntConnectTimer() (phasing out)
*
* NOMANUAL
*/

LOCAL STATUS excConnectVector
    (
    INSTR 	* newVector,		/* calculated exc vector */
    int		  vecType,		/* norm/crit/mchk? */
    VOIDFUNCPTR	  entry,		/* handler entry */
    VOIDFUNCPTR	  routine,		/* routine to be called */
    VOIDFUNCPTR	  exit			/* handler exit */
    )
    {
    INSTR   entBranch, routineBranch, exitBranch, scratch;
    int	    entOff, isrOff, exitOff;
    int	    vecSize;

    /* Set offsets into handler */
    if ((vecType == VEC_TYPE_CRT) || (vecType == VEC_TYPE_MCHK))
        {
#ifdef _EXC_OFF_CRTL
	entOff = entCrtOffset;
	isrOff = isrCrtOffset; 
	exitOff = exitCrtOffset;
#else
	return ERROR;	/* no critical exception handler
			   for either crt or mchk class */
#endif /* _EXC_OFF_CRTL */
        } 
    else if (vecType == VEC_TYPE_NORM)
        {
	entOff = entOffset;
	isrOff = isrOffset;
	exitOff = exitOffset;
        }
    else		/* vecType == VEC_TYPE_UNDEF or undef */
	{
	return ERROR;	/* check only once in excConnectVector */
	}

    if (excExtendedVectors == TRUE)
	{
        /* copy the vector template code into the vector and save the size */
        if ((vecType == VEC_TYPE_CRT) || (vecType == VEC_TYPE_MCHK))
            {
#ifdef _EXC_OFF_CRTL    /* VEC_TYPE_MCHK requireds _EXC_OFF_CRTL defined */
	    vecSize = sizeof(excExtCrtConnectCode);
	    bcopy ((char *) excExtCrtConnectCode, (char *) newVector, 
                   vecSize);
#ifdef _PPC_MSR_MCE
            if (vecType == VEC_TYPE_MCHK)
                {
                /* use SPRG4 for mchk */
                scratch = *newVector;
                *newVector = (scratch & 0xffe007ff) | SPR_SET(SPRG4_W);
                }
#endif  /* _PPC_MSR_MCE */

#else  /* _EXC_OFF_CRTL */
	    return ERROR;
#endif /* _EXC_OFF_CRTL */
	    } 
        else		/* vecType == VEC_TYPE_NORM */
            {
	    vecSize = sizeof(excExtConnectCode);
	    bcopy ((char *) excExtConnectCode, (char *) newVector, vecSize);
	    }

        /* fill in the two halves of the 32-bit function addresses */

	newVector[entOff]    = (INSTR) (0x3c600000 | MSW((int)entry));
	newVector[entOff+1]  = (INSTR) (0x60630000 | LSW((int)entry));
	newVector[isrOff]    = (INSTR) (0x3c600000 | MSW((int)routine));
	newVector[isrOff+1]  = (INSTR) (0x60630000 | LSW((int)routine));
	newVector[exitOff]   = (INSTR) (0x3c600000 | MSW((int)exit));
	newVector[exitOff+1] = (INSTR) (0x60630000 | LSW((int)exit));
	}
    else  /* excExtendedVectors == TRUE */
	{
	/* Compute branch instructions for short stub, or 0. */

	entBranch     = blCompute (entry, &newVector[entOff]);
	routineBranch = blCompute (routine, &newVector[isrOff]);
	exitBranch    = blCompute (exit, &newVector[exitOff]);

	/*
	 * If any branch was out of range, return ERROR
	 */

	if ( (entBranch == (INSTR) 0)     ||
	     (routineBranch == (INSTR) 0) ||
	     (exitBranch == (INSTR) 0) )
	    return ERROR;

        /* copy the vector template code into the vector and save the size */
	if ((vecType == VEC_TYPE_CRT) || (vecType == VEC_TYPE_MCHK))
            {
#ifdef _EXC_OFF_CRTL    /* VEC_TYPE_MCHK requireds _EXC_OFF_CRTL defined */
	    vecSize = sizeof(excCrtConnectCode);
	    bcopy ((char *) excCrtConnectCode, (char *) newVector, vecSize);
#ifdef _PPC_MSR_MCE
            if (vecType == VEC_TYPE_MCHK)
                {
                /* use SPRG4 for mchk */
                scratch = *newVector;
                *newVector = (scratch & 0xffe007ff) | SPR_SET(SPRG4_W);
                }
#endif  /* _PPC_MSR_MCE */

#else  /* _EXC_OFF_CRTL */
	    return ERROR;
#endif /* _EXC_OFF_CRTL */
	    } 
        else 		/* vecType == VEC_TYPE_NORM */
            {
	    vecSize = sizeof(excConnectCode);
	    bcopy ((char *) excConnectCode, (char *) newVector, vecSize);
	    }

	/* fill in the branch instructions */

        newVector[entOff]  = entBranch;
        newVector[isrOff]  = routineBranch;
        newVector[exitOff] = exitBranch;
	}  /* excExtendedVectors == TRUE */

    CACHE_TEXT_UPDATE((void *) newVector, vecSize);   /* synchronize cache */

    return (OK);
    }

#ifdef	_PPC_MSR_CE
# ifdef	_EXC_OFF_CRTL	/* if not, excCrtConnectCode does not exist */
/*******************************************************************************
*
* excCrtConnect - connect a C routine to a critical exception vector (PPC4xx)
*
* This routine connects a specified C routine to a specified critical exception
* vector.  An exception stub is created and in placed at <vector> in the
* exception table.  The address of <routine> is stored in the exception stub
* code.  When an exception occurs, the processor jumps to the exception stub
* code, saves the registers, and call the C routines.
*
* The routine can be any normal C code, except that it must not
* invoke certain operating system functions that may block or perform
* I/O operations.
*
* The registers are saved to an Exception Stack Frame (ESF) which is placed
* on the stack of the task that has produced the exception.  The ESF structure
* is defined in h/arch/ppc/esfPpc.h.
*
* The only argument passed by the exception stub to the C routine is a pointer
* to the ESF containing the register values.  The prototype of this C routine
* is as follows:
* .CS
*     void excHandler (ESFPPC *);
* .CE
*
* When the C routine returns, the exception stub restores the registers saved
* in the ESF and continues execution of the current task.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for a 26-bit offset.
* 
* SEE ALSO: excIntConnect(), excIntCrtConnect, excVecSet()
*/

STATUS excCrtConnect
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine               /* routine to be called */
    )
    {
    return ( excRelocCrtConnect (vector, routine, (VOIDFUNCPTR *) 0) );
    }

/*******************************************************************************
*
* excRelocCrtConnect - connect a C routine to an exception vector with
*                      possible relocation
*
* This routine is same as excCrtConnect with an added parameter, which is
* the relocation offset of the vector to be installed.  If the extra
* parameter is non-zero, the vector is installed at this offset instead
* of the standard offset specified in the first parameter.  A branch
* instruction is then written to the original offset to reach the
* relocated vector.  A relative branch will be used, unless out of the
* 26-bit offset range where it will attempt an absolute branch.  The
* caller should take care of the branch instruction clobbering useful
* data specified by vector, including the stub being installed should
* the original offset overlaps the stub of the relocated vector.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for one branch instr.
*
*/

STATUS excRelocCrtConnect
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine,              /* routine to be called */
    VOIDFUNCPTR * vectorReloc           /* relocated exception vector */
    )
    {    
    FAST STATUS  rc;
    FAST INSTR   branch;
    FAST INSTR * newVector;
    FAST int     base = (int) excVecBaseGet ();

    if ((int) vectorReloc == 0)
        {
        newVector = (INSTR *) ( base | (int) vector );
        }
    else
        {
        vector = (VOIDFUNCPTR *) ( base | (int) vector );
        newVector = (INSTR *) ( base | (int) vectorReloc );
        }

    rc = excConnectVector(newVector, VEC_TYPE_CRT, excCrtEnt, routine, excCrtExit);

    if ( ((int) vectorReloc != 0) && (rc == OK) )
        {
        /* if relocated vector, write branch (with link bit cleared) */
        branch = blCompute ( (VOIDFUNCPTR) newVector, (INSTR *) vector );
        if (branch == 0)
            return ERROR;
        *vector = (VOIDFUNCPTR) (branch & 0xfffffffe);
        CACHE_TEXT_UPDATE ((void *) vector, sizeof(INSTR));
        }

    return (rc);
    }

/*******************************************************************************
*
* excIntCrtConnect - connect a C routine to a critical interrupt vector (PPC4xx)
*
* This routine connects a specified C routine to a specified asynchronous 
* critical exception vector such as the critical external interrupt vector 
* (0x100), or the watchdog timer vector (0x1020).  An interrupt stub is created 
* and placed at <vector> in the exception table.  The address of <routine> is 
* stored in the interrupt stub code.  When the asynchronous exception occurs,
* the processor jumps to the interrupt stub code, saves only the requested 
* registers, and calls the C routines.
*
* When the C routine is invoked, interrupts are still locked.  It is the
* C routine's responsibility to re-enable interrupts.
*
* The routine can be any normal C routine, except that it must not
* invoke certain operating system functions that may block or perform
* I/O operations.
*
* Before the requested registers are saved, the interrupt stub switches from the
* current task stack to the interrupt stack.  In the case of nested interrupts,
* no stack switching is performed, because the interrupt stack is already set.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for a 26-bit offset.
* 
* SEE ALSO: excConnect(), excCrtConnect, excVecSet()
*/

STATUS excIntCrtConnect
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine               /* routine to be called */
    )
    {
    return ( excRelocIntCrtConnect (vector, routine, (VOIDFUNCPTR *) 0) );
    }

/*******************************************************************************
*
* excRelocIntCrtConnect - connect a C routine to an exception vector with
*                         possible relocation
*
* This routine is same as excIntCrtConnect with an added parameter, which
* is the relocation offset of the vector to be installed.  If the extra
* parameter is non-zero, the vector is installed at this offset instead
* of the standard offset specified in the first parameter.  A branch
* instruction is then written to the original offset to reach the
* relocated vector.  A relative branch will be used, unless out of the
* 26-bit offset range where it will attempt an absolute branch.  The
* caller should take care of the branch instruction clobbering useful
* data specified by vector, including the stub being installed should
* the original offset overlaps the stub of the relocated vector.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for one branch instr.
*
*/

STATUS excRelocIntCrtConnect
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine,              /* routine to be called */
    VOIDFUNCPTR * vectorReloc           /* relocated exception vector */
    )
    {
    FAST STATUS  rc;
    FAST INSTR   branch;
    FAST INSTR * newVector;
    FAST int     base = (int) excVecBaseGet ();

    if ((int) vectorReloc == 0)
        {
        newVector = (INSTR *) ( base | (int) vector );
        }
    else
        {
        vector = (VOIDFUNCPTR *) ( base | (int) vector );
        newVector = (INSTR *) ( base | (int) vectorReloc );
        }

    rc = excConnectVector(newVector, VEC_TYPE_CRT, intCrtEnt, routine, intCrtExit);

    if ( ((int) vectorReloc != 0) && (rc == OK) )
        {
        /* if relocated vector, write branch (with link bit cleared) */
        branch = blCompute ( (VOIDFUNCPTR) newVector, (INSTR *) vector );
        if (branch == 0)
            return ERROR;
        *vector = (VOIDFUNCPTR) (branch & 0xfffffffe);
        CACHE_TEXT_UPDATE ((void *) vector, sizeof(INSTR));
        }

    return (rc);
    }
# endif	/* _EXC_OFF_CRTL */
#endif	/* _PPC_MSR_CE */

#ifdef	_PPC_MSR_MCE
# ifdef	_EXC_OFF_CRTL	/* also need excCrtConnectCode like critical int */
/*******************************************************************************
*
* excMchkConnect - connect a C routine to a machine chk exception vector
*
* This routine connects a specified C routine to a specified mcheck exception
* vector.  An exception stub is created and in placed at <vector> in the
* exception table.  The address of <routine> is stored in the exception stub
* code.  When an exception occurs, the processor jumps to the exception stub
* code, saves the registers, and call the C routines.
*
* The routine can be any normal C code, except that it must not
* invoke certain operating system functions that may block or perform
* I/O operations.
*
* The registers are saved to an Exception Stack Frame (ESF) which is placed
* on the stack of the task that has produced the exception.  The ESF structure
* is defined in h/arch/ppc/esfPpc.h.
*
* The only argument passed by the exception stub to the C routine is a pointer
* to the ESF containing the register values.  The prototype of this C routine
* is as follows:
* .CS
*     void excHandler (ESFPPC *);
* .CE
*
* When the C routine returns, the exception stub restores the registers saved
* in the ESF and continues execution of the current task.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for a 26-bit offset.
* 
* SEE ALSO: excIntConnect(), excIntCrtConnect, excVecSet()
*/

STATUS excMchkConnect
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine               /* routine to be called */
    )
    {
    return ( excRelocMchkConnect (vector, routine, (VOIDFUNCPTR *) 0) );
    }

/*******************************************************************************
*
* excRelocMchkConnect - connect a C routine to an exception vector with
*                       possible relocation
*
* This routine is same as excMchkConnect with an added parameter, which is
* the relocation offset of the vector to be installed.  If the extra
* parameter is non-zero, the vector is installed at this offset instead
* of the standard offset specified in the first parameter.  A branch
* instruction is then written to the original offset to reach the
* relocated vector.  A relative branch will be used, unless out of the
* 26-bit offset range where it will attempt an absolute branch.  The
* caller should take care of the branch instruction clobbering useful
* data specified by vector, including the stub being installed should
* the original offset overlaps the stub of the relocated vector.
*
* RETURNS: OK if the routine connected successfully, or
*          ERROR if the routine was too far away for one branch instr.
*
*/

STATUS excRelocMchkConnect
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine,              /* routine to be called */
    VOIDFUNCPTR * vectorReloc           /* relocated exception vector */
    )
    {    
    FAST STATUS  rc;
    FAST INSTR   branch;
    FAST INSTR * newVector;
    FAST int     base = (int) excVecBaseGet ();

    if ((int) vectorReloc == 0)
        {
        newVector = (INSTR *) ( base | (int) vector );
        }
    else
        {
        vector = (VOIDFUNCPTR *) ( base | (int) vector );
        newVector = (INSTR *) ( base | (int) vectorReloc );
        }

    rc = excConnectVector(newVector, VEC_TYPE_MCHK, excMchkEnt, routine, excMchkExit);

    if ( ((int) vectorReloc != 0) && (rc == OK) )
        {
        /* if relocated vector, write branch (with link bit cleared) */
        branch = blCompute ( (VOIDFUNCPTR) newVector, (INSTR *) vector );
        if (branch == 0)
            return ERROR;
        *vector = (VOIDFUNCPTR) (branch & 0xfffffffe);
        CACHE_TEXT_UPDATE ((void *) vector, sizeof(INSTR));
        }

    return (rc);
    }
# endif	/* _EXC_OFF_CRTL */
#endif	/* _PPC_MSR_CE */

#if     defined(_EXC_NEW_OFF_PIT) || defined(_EXC_NEW_OFF_FIT)
/*******************************************************************************
*
* excIntConnectTimer - connect a C routine to the FIT or PIT interrupt vector
*
* NOTE: phasing out, should use excRelocIntConnect(), currently still
*       used by BSPs (evb403, walnut, and wrSbc405gp)
*
*/

STATUS excIntConnectTimer
    (
    VOIDFUNCPTR * vector,               /* exception vector to attach to */
    VOIDFUNCPTR   routine               /* routine to be called */
    )
    {
    VOIDFUNCPTR * newVector;

    newVector = (VOIDFUNCPTR *) vecOffRelocMatch ((UINT32) vector);

    /*
     * not in other exc*Connect, but to preserve original behavior of
     * excIntConnectTimer(), NULL is checked here.
     */
    if ((INSTR *) newVector == NULL)
        return ERROR;

    return ( excRelocIntConnect(vector, routine, newVector) );
    }
#endif  /* _EXC_NEW_OFF_PIT || _EXC_NEW_OFF_FIT */

/*******************************************************************************
*
* excVecSet - set a CPU exception vector
*
* This routine set the C routine that will be called when the exception
* corresponding to <vector> will occur. This function doesn't create the
* exception stub. Just replace the C routine to call in the exception 
* stub. 
*
* SEE ALSO: excVecGet(), excConnect(), excIntConnect()
*/

void excVecSet 
    (
    FUNCPTR * vector,		/* vector offset */
    FUNCPTR   function		/* address to place in vector */
    )
    {
    INSTR * newVector;

    /*
     * SPR #77145: See Exception Vector Table comment near top of file.
     * Relocated vectors saves wrong vector offset in ESF, thus need to
     * be patched to get right.  Note also that pEsf->vecOffset (or
     * _PPC_ESF_VEC_OFF) is supposed to contain the offset only, but
     * excEnt and intEnt save the full address in current implementation.
     * They are same now because vector base is at 0x0, but will need work
     * when flexible vecotr positioning is supported, like using IVPR and
     * IVORn on the 440 and e500 book E compliant cores.
     */

#if TRUE
    vector = (FUNCPTR *) vecOffRelocMatch ((UINT32) vector);
#else  /* TRUE */

    /*
     * function call to vecOffRelocMatch() is cleaner but more expensive
     * can use following code instead (register compare/branch/set,
     * instead of table walk each entry compare/branch/memset)
     */

#if     ( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) )
#   ifdef  _EXC_NEW_OFF_PIT
    if ((UINT32) vector == _EXC_OFF_PIT)
        {
        vector = (FUNCPTR *) _EXC_NEW_OFF_PIT;
        }
    else
#   endif  /* _EXC_NEW_OFF_PIT */
        {
#   ifdef  _EXC_NEW_OFF_FIT
        if ((UINT32) vector == _EXC_OFF_FIT)
            {
            vector = (FUNCPTR *) _EXC_NEW_OFF_FIT;
            }
#   endif  /* _EXC_NEW_OFF_FIT */
        }
#endif  /* ( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) ) */

#if     (CPU == PPC604)
#   ifdef  _EXC_NEW_OFF_PERF
    if ((UINT32) vector == _EXC_OFF_PERF)
        {
        vector = (FUNCPTR *) _EXC_NEW_OFF_PERF;
        }
#   endif  /* _EXC_NEW_OFF_PERF */
#endif  /* (CPU == PPC604) */

#endif  /* TRUE */

    /* vector is offset by the vector base address */

    newVector = (INSTR *) ((int) vector | (int) excVecBaseGet ());

    /*
     * One of the connect functions (excConnect, excIntConnect, excCrtConnect,
     * or excIntCrtConnect) has previously copied the appropriate stub code
     * (excConnectCode[] or excCrtConnectCode[] or their extended versions to
     * the vector location.  We now need to change an instruction in the stub
     * to jump to the new handler function.
     *
     * If the processor supports "critical" exceptions, there are two
     * different stubs and the offset of the jump instruction within
     * the stub depends on whether it is the "critical" or the "normal"
     * stub.  To distinguish between them, we examine the first word of
     * the stub.
     */

    if (excExtendedVectors == TRUE)
	{
#ifdef	ISR_CRT_OFF
        if (excExtCrtConnectCode[0] == newVector[0])
	    {
	    newVector[isrCrtOffset]   = (INSTR) (0x3c600000 | 
                                                 MSW((int)function));
	    newVector[isrCrtOffset+1] = (INSTR) (0x60630000 | 
                                                 LSW((int)function));
	    CACHE_TEXT_UPDATE((void *) &newVector[isrCrtOffset], 
                              2*sizeof(INSTR *));
	    }
        else
#endif	/* ISR_CRT_OFF */
	    {
	    newVector[isrOffset]   = (INSTR) (0x3c600000 | MSW((int)function));
	    newVector[isrOffset+1] = (INSTR) (0x60630000 | LSW((int)function));

	    CACHE_TEXT_UPDATE((void *) &newVector[isrOffset], 2 * sizeof(INSTR *));
	    }
	}
    else    /* non-extended vectors */
	{
#ifdef	ISR_CRT_OFF
        if (excCrtConnectCode[0] == newVector[0])
	    {
   	    INSTR routineBranch = blCompute ( (VOIDFUNCPTR) function, 
                                              &newVector[isrCrtOffset] );
            /* 
	     * if the function is too far for a 26-bit offset, blCompute will
	     * return 0. Could set an errno in that case.
	     */
	    if (routineBranch == 0)
		{
		if (_func_logMsg != NULL)
		    _func_logMsg ("Target %08lx for vector %x out of range\n",
				  function, &newVector[isrCrtOffset], 0,0,0,0);
		}
	    else
		{
	        newVector[isrCrtOffset] = routineBranch;
		CACHE_TEXT_UPDATE((void *) &newVector[isrCrtOffset],
				sizeof(INSTR *));
		}
	    }
        else
#endif	/* ISR_CRT_OFF */
	    {
   	    INSTR routineBranch = blCompute ( (VOIDFUNCPTR) function, 
                                              &newVector[isrOffset] );
            /* 
	     * if the function is too far for a 26-bit offset, blCompute will
	     * return 0. Could set an errno in that case.
	     */
	    if (routineBranch == 0)
		{
		if (_func_logMsg != NULL)
		    _func_logMsg ("Target %08lx for vector %x out of range\n",
				  function, &newVector[isrOffset], 0,0,0,0);
		}
	    else
		{
		newVector[isrOffset] = routineBranch;
		CACHE_TEXT_UPDATE((void *) &newVector[isrOffset],
				sizeof(INSTR *));
		}
	    }
	}
    }

/*******************************************************************************
*
* excVecGet - get a CPU exception vector
*
* This routine returns the address of the current C routine connected to
* the <vector>.
*
* RETURNS: the address of the C routine.
*
* SEE ALSO: excVecSet()
*/

FUNCPTR excVecGet 
    (
    FUNCPTR * vector 			/* vector offset */
    )
    {
    INSTR * vec;
    INSTR routine;

    /*
     * SPR #77145: See Exception Vector Table comment near top of file.
     * Relocated vectors saves wrong vector offset in ESF, thus need to
     * be patched to get right.  Note also that pEsf->vecOffset (or
     * _PPC_ESF_VEC_OFF) is supposed to contain the offset only, but
     * excEnt and intEnt save the full address in current implementation.
     * They are same now because vector base is at 0x0, but will need work
     * when flexible vecotr positioning is supported, like using IVPR and
     * IVORn on the 440 and e500 book E compliant cores.
     */

#if TRUE
    vector = (FUNCPTR *) vecOffRelocMatch ((UINT32) vector);
#else  /* TRUE */

    /*
     * function call to vecOffRelocMatch() is cleaner but more expensive
     * can use following code instead (register compare/branch/set,
     * instead of table walk each entry compare/branch/memset)
     */

#if     ( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) )
#   ifdef  _EXC_NEW_OFF_PIT
    if ((UINT32) vector == _EXC_OFF_PIT)
        {
        vector = (FUNCPTR *) _EXC_NEW_OFF_PIT;
        }
    else
#   endif  /* _EXC_NEW_OFF_PIT */
        {
#   ifdef  _EXC_NEW_OFF_FIT
        if ((UINT32) vector == _EXC_OFF_FIT)
            {
            vector = (FUNCPTR *) _EXC_NEW_OFF_FIT;
            }
#   endif  /* _EXC_NEW_OFF_FIT */
        }
#endif  /* ( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) ) */

#if     (CPU == PPC604)
#   ifdef  _EXC_NEW_OFF_PERF
    if ((UINT32) vector == _EXC_OFF_PERF)
        {
        vector =  (FUNCPTR *) _EXC_NEW_OFF_PERF;
        }
#   endif  /* _EXC_NEW_OFF_PERF */
#endif  /* (CPU == PPC604) */

#endif  /* TRUE */

    /* vector is offset by vector base address */

    vec = (INSTR *) ((int) vector | (int) excVecBaseGet ());

    /*
     * One of the "connect" functions (excConnect, excIntConnect,
     * excCrtConnect, or excIntCrtConnect) has previously copied the
     * appropriate stub code (excConnectCode[] or excCrtConnectCode[])
     * to the vector location.  We now need to examine an instruction
     * in the stub and extract a pointer to the handler function.
     *
     * If the processor supports "critical" exceptions, there are two
     * different stubs and the offset of the jump instruction within
     * the stub depends on whether it is the "critical" or the "normal"
     * stub.  To distinguish between them, we examine the first word of
     * the stub.
     */

    /* extract the routine address from the instruction */

    if (excExtendedVectors == TRUE)
	{
	/* extract the two halves of the routine address from the stub */

#ifdef	ISR_CRT_OFF
        if (excExtCrtConnectCode[0] == vec[0])
	    routine = (vec[isrCrtOffset] << 16)
			| (vec[isrCrtOffset+1] & 0x0000ffff);
        else
#endif	/* ISR_CRT_OFF */

	    routine = (vec[isrOffset] << 16) | (vec[isrOffset+1] & 0x0000ffff);
	}
    else
	{
            /* extract the routine address from the instruction */

#ifdef	ISR_CRT_OFF
        if (excCrtConnectCode[0] == vec[0])
	    routine = blExtract (vec[isrCrtOffset],  &vec[isrCrtOffset]);
        else
#endif	/* ISR_CRT_OFF */

	    routine = blExtract (vec[isrOffset], &vec[isrOffset]);
	}

    return ((FUNCPTR) routine);
    }

/*******************************************************************************
*
* excVecBaseSet - set the exception vector base address
*
* This routine sets the vector base address.  The MSR's IP bit is set to zero 
* or one according to the specified value, and subsequent calls to excVecGet() 
* or excVecSet() will use this base address.  The vector base address is
* initially 0, until changed by calls to this routine.
*
* NOTE:
* Most PowerPC processors do not have a vector base register.  However,
* the IP or EP bit in the machine state register set the prefix of the
* exception vector.  Thus the vector base can only be set to 0x00000000
* or 0xfff00000.
*
* RETURNS: N/A
*
* SEE ALSO: excVecBaseGet(), excVecGet(), excVecSet()
*/

void excVecBaseSet
    (
    FUNCPTR * baseAddr       	/* new vector base address */
    )
    {
#if 	( (CPU == PPC403)||(CPU==PPC405)||(CPU==PPC405F)|| \
          (CPU==PPC440)||(CPU==PPC85XX) )
    excVecBase = (FUNCPTR *)((uint32_t)baseAddr & 0x0ffff0000);
# if	((CPU == PPC440) || (CPU == PPC85XX))
    vxIvprSet ((int) excVecBase);
# else	/* CPU==PPC440,PPC85XX */
    vxEvprSet ((int) excVecBase);
# endif	/* CPU==PPC440,PPC85XX */
#else	/* (CPU == PPC4xx) */
    if ((int) baseAddr == _PPC_EXC_VEC_BASE_LOW ||
	(int) baseAddr == _PPC_EXC_VEC_BASE_HIGH)
	{
    	excVecBase = baseAddr;	/* keep the base address in a static variable */

        excEPSet (baseAddr);	/* set the actual vector base register */
	}
#endif	/* CPU == PPC4xx,PPC85XX */
    }

/*******************************************************************************
*
* excVecBaseGet - get the vector base address
*
* This routine returns the current vector base address that has been set
* with the intVecBaseSet() routine.
*
* RETURNS: The current vector base address.
*
* SEE ALSO: intVecBaseSet()
*/

FUNCPTR * excVecBaseGet (void)
    {
    return (excVecBase);
    }

/*******************************************************************************
*
* excExcHandle - interrupt level handling of exceptions
*
* This routine handles exception traps. It is never be called except 
* from the special assembly language interrupt stub routine.
*
* It prints out a bunch of pertinent information about the trap that
* occurred via excTask.
*
* Note that this routine runs in the context of the task that got the
* exception.
*
* NOMANUAL
*/

void excExcHandle
    (
    ESFPPC *	pEsf			/* pointer to exception stack frame */
    )
    {
    EXC_INFO	excInfo;
    int		vecNum = pEsf->vecOffset;	/* exception vector number */
    REG_SET *	pRegs = &pEsf->regSet;		/* pointer to register on esf */

    /*
     * SPR #77145: See Exception Vector Table comment near top of file.
     * Relocated vectors saves wrong vector offset in ESF, thus need to
     * be patched to get right.  Note also that pEsf->vecOffset (or
     * _PPC_ESF_VEC_OFF) is supposed to contain the offset only, but
     * excEnt and intEnt save the full address in current implementation.
     * They are same now because vector base is at 0x0, but will need work
     * when flexible vecotr positioning is supported, like using IVPR and
     * IVORn on the 440 and e500 book E compliant cores.
     */

#if TRUE
    vecNum = (int) vecOffRelocMatchRev ((UINT32) vecNum);
    pEsf->vecOffset = vecNum;
#else  /* TRUE */

    /*
     * function call to vecOffRelocMatchRev() is cleaner but more expensive
     * can use following code instead (register compare/branch/set,
     * instead of table walk each entry compare/branch/memset)
     */

#if     ( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) )
#   ifdef  _EXC_NEW_OFF_PIT
    if (vecNum == _EXC_NEW_OFF_PIT)
        {
        vecNum = _EXC_OFF_PIT;
        pEsf->vecOffset = vecNum;
        }
    else
#   endif  /* _EXC_NEW_OFF_PIT */
        {
#   ifdef  _EXC_NEW_OFF_FIT
        if (vecNum == _EXC_NEW_OFF_FIT)
            {
            vecNum = _EXC_OFF_FIT;
            pEsf->vecOffset = vecNum;
            }
#   endif  /* _EXC_NEW_OFF_FIT */
        }
#endif  /* ( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) ) */

#if     (CPU == PPC604)
#   ifdef  _EXC_NEW_OFF_PERF
    if (vecNum == _EXC_NEW_OFF_PERF)
        {
        vecNum = _EXC_OFF_PERF;
        pEsf->vecOffset = vecNum;
        }
#   endif  /* _EXC_NEW_OFF_PERF */
#endif  /* (CPU == PPC604) */

#endif  /* TRUE */

#ifdef  WV_INSTRUMENTATION
    /* windview - level 3 event logging */
    EVT_CTX_1(EVENT_EXCEPTION, vecNum);
#endif

#if	( (CPU == PPC403)||(CPU==PPC405)||(CPU==PPC405F)|| \
	  (CPU==PPC440)||(CPU==PPC85XX) )
    if (((*(INSTR *) pEsf->regSet.pc) == DBG_BREAK_INST) && 
	 (_func_excTrapRtn != NULL))
	{
	(* _func_excTrapRtn) (pEsf->regSet.pc , pRegs, pEsf, NULL, FALSE);
	}
    else
#elif	((CPU == PPC509)   || (CPU == PPC555) || (CPU == PPC603)  || \
         (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC860))
    if ((pEsf->regSet.msr & _EXC_PROG_SRR1_TRAP) && (_func_excTrapRtn != NULL)
	&& ((*(INSTR *) pEsf->regSet.pc) == DBG_BREAK_INST))
	{
	pEsf->regSet.msr &= ~_EXC_PROG_SRR1_TRAP;
	(* _func_excTrapRtn) (pEsf, pRegs, NULL, FALSE);
	}
    else
#endif	/* 403|405|405F|440|85XX : 509|555|603|EC603|604|860 */
	{
	excGetInfoFromESF (vecNum, pEsf, &excInfo);

	if ((_func_excBaseHook != NULL) &&		/* user hook around? */
	    ((* _func_excBaseHook) (vecNum, pEsf, pRegs, &excInfo)))
	    return;					/* user hook fixed it */

	if (INT_CONTEXT ())
	    {
	    if (_func_excPanicHook != NULL)		/* panic hook? */
		(*_func_excPanicHook) (vecNum, pEsf, pRegs, &excInfo);

	    reboot (BOOT_NORMAL);
	    return;					/* reboot returns?! */
	    }

	if (ioGlobalStdGet(STD_ERR) == ERROR)	/* I/O not set up yet */
	    {
	    if (_func_excPanicHook != NULL)		/* panic hook? */
		{
		++intCnt;   /* so printExc will put the message in sysExcMsg */
		(*_func_excPanicHook) (vecNum, pEsf, pRegs, &excInfo);
		--intCnt;
		}

	    /* It died in or before tRootTask, so no point in rebooting */
	    reboot (BOOT_NO_AUTOBOOT);
	    return;					/* reboot returns?! */
	    }

	/* task caused exception */

	taskIdCurrent->pExcRegSet = pRegs;		/* for taskRegs[GS]et */

	taskIdDefault ((int)taskIdCurrent);		/* update default tid */

	bcopy ((char *) &excInfo, (char *) &(taskIdCurrent->excInfo),
	       sizeof (EXC_INFO));			/* copy in exc info */

	if (_func_sigExcKill != NULL)
	    _func_sigExcKill((int) vecNum, vecNum, pRegs);

	if (_func_excInfoShow != NULL)			/* default show rtn? */
	    (*_func_excInfoShow) (&excInfo, TRUE);

	if (excExcepHook != NULL)
	    (* excExcepHook) (taskIdCurrent, vecNum, pEsf);

	taskSuspend (0);				/* whoa partner... */

	taskIdCurrent->pExcRegSet = (REG_SET *) NULL;	/* invalid after rts */
	}
    }

/*******************************************************************************
*
* excIntHandle - interrupt level handling of interrupts
*
* This routine handles interrupts. It is never to be called except
* from the special assembly language interrupt stub routine.
*
* It prints out a bunch of pertinent information about the trap that
* occurred, via excTask.
*
* NOMANUAL
*/

void excIntHandle
    (
    ESFPPC *    pEsf                    /* pointer to exception stack frame */
    )
    {
    int         vecNum = pEsf->vecOffset;       /* exception vector number */

    /*
     * SPR #77145: See Exception Vector Table comment near top of file.
     * Relocated vectors saves wrong vector offset in ESF, thus need to
     * be patched to get right.  Note also that pEsf->vecOffset (or
     * _PPC_ESF_VEC_OFF) is supposed to contain the offset only, but
     * excEnt and intEnt save the full address in current implementation.
     * They are same now because vector base is at 0x0, but will need work
     * when flexible vecotr positioning is supported, like using IVPR and
     * IVORn on the 440 and e500 book E compliant cores.
     */

#if TRUE
    vecNum = (int) vecOffRelocMatchRev ((UINT32) vecNum);
    pEsf->vecOffset = vecNum;
#else  /* TRUE */

    /*
     * function call to vecOffRelocMatchRev() is cleaner but more expensive
     * can use following code instead (register compare/branch/set,
     * instead of table walk each entry compare/branch/memset)
     */

#if     ( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) )
#   ifdef  _EXC_NEW_OFF_PIT
    if (vecNum == _EXC_NEW_OFF_PIT)
        {
        vecNum = _EXC_OFF_PIT;
        pEsf->vecOffset = vecNum;
        }
    else
#   endif  /* _EXC_NEW_OFF_PIT */
        {
#   ifdef  _EXC_NEW_OFF_FIT
        if (vecNum == _EXC_NEW_OFF_FIT)
            {
            vecNum = _EXC_OFF_FIT;
            pEsf->vecOffset = vecNum;
            }
#   endif  /* _EXC_NEW_OFF_FIT */
        }
#endif  /* ( (CPU == PPC403) || (CPU==PPC405) || (CPU==PPC405F) ) */

#if     (CPU == PPC604)
#   ifdef  _EXC_NEW_OFF_PERF
    if (vecNum == _EXC_NEW_OFF_PERF)
        {
        vecNum = _EXC_OFF_PERF;
        pEsf->vecOffset = vecNum;
        }
#   endif  /* _EXC_NEW_OFF_PERF */
#endif  /* (CPU == PPC604) */

#endif  /* TRUE */

#ifdef  WV_INSTRUMENTATION
    /*
     * windview - level 3 event is not logged here, since this
     * function is not used for the moment
     */

#if FALSE
    EVT_CTX_1(EVENT_EXCEPTION, vecNum);
#endif
#endif

    if (_func_excIntHook != NULL)
	(*_func_excIntHook) ();

    if (_func_logMsg != NULL)
        _func_logMsg ("Uninitialized interrupt\n", 0,0,0,0,0,0);
    }

/*****************************************************************************
*
* excGetInfoFromESF - get relevent info from exception stack frame
*
* RETURNS: size of specified ESF
*
* INTERNAL: This code assumes that, for any PPC CPU type, each of bear,
*	    besr, dar, dear, dsisr, fpscr exists either in both ESFPPC
*	    and EXC_INFO, or in neither; and that the member exists in
*	    the structures iff the corresponding _EXC_INFO_* symbol is
*	    #define-d.  ESFPPC and EXC_INFO are defined in esfPpc.h and
*	    excPpcLib.h respectively.
*/

LOCAL int excGetInfoFromESF
    (
    FAST int vecNum,
    FAST ESFPPC *pEsf,
    EXC_INFO *pExcInfo 
    )
    {
    pExcInfo->vecOff = vecNum;
    pExcInfo->cia = pEsf->regSet.pc;		/* copy cia/nia */
    pExcInfo->msr = pEsf->regSet.msr;		/* copy msr */
    pExcInfo->cr = pEsf->regSet.cr;		/* copy cr */
    switch (vecNum)
	{
	case _EXC_OFF_MACH:
#if     ((CPU == PPC403) || (CPU == PPC405))
	   pExcInfo->bear = pEsf->bear;
	   pExcInfo->besr = pEsf->besr;
	   pExcInfo->valid = (_EXC_INFO_DEFAULT | _EXC_INFO_NIA | 
			      _EXC_INFO_BEAR | _EXC_INFO_BESR) & ~_EXC_INFO_CIA;
#elif	(CPU == PPC405F)
	    /* there is no space in the exception info structure to store
	     * besr for 405F, so we just get the bear.
	     */
	    pExcInfo->bear = pEsf->bear;
	    pExcInfo->valid = (_EXC_INFO_DEFAULT | _EXC_INFO_NIA | 
			       _EXC_INFO_BEAR) & ~_EXC_INFO_CIA;
#elif	((CPU == PPC509) || (CPU == PPC555) || (CPU == PPC860))
	    pExcInfo->dsisr = pEsf->dsisr;
	    pExcInfo->dar   = pEsf->dar;
	    pExcInfo->valid = _EXC_INFO_DEFAULT | _EXC_INFO_DSISR |
			      _EXC_INFO_DAR;
#elif	(CPU == PPC85XX)
	    pExcInfo->mcesr = pEsf->esr;
	    pExcInfo->dear  = pEsf->dear;
	    pExcInfo->valid = (_EXC_INFO_DEFAULT |
                               _EXC_INFO_MCSR | _EXC_INFO_NIA) &
                              ~_EXC_INFO_CIA;
#else	/* 403 | 405 : 405F : 5xx | 860 : 85XX */
	    pExcInfo->valid = (_EXC_INFO_DEFAULT | _EXC_INFO_NIA) &
								 ~_EXC_INFO_CIA;
#endif 	/* 403 | 405 : 405F : 5xx | 860 : 85XX */
	    break;

#if	((CPU == PPC603) || (CPU == PPCEC603) || (CPU == PPC604) || \
	 (CPU == PPC860) || (CPU == PPC85XX))
	case _EXC_OFF_DATA:
#if	  (CPU == PPC85XX)
	    pExcInfo->dear  = pEsf->dear;
	    pExcInfo->mcesr = pEsf->esr;
	    pExcInfo->valid = _EXC_INFO_DEFAULT | _EXC_INFO_DEAR |
			      _EXC_INFO_ESR;
#else	  /* CPU == PPC85XX */
	    pExcInfo->dsisr = pEsf->dsisr;
	    pExcInfo->dar   = pEsf->dar;
	    pExcInfo->valid = _EXC_INFO_DEFAULT | _EXC_INFO_DSISR |
			      _EXC_INFO_DAR;
#endif	  /* CPU == PPC85XX */
	    break;

	case _EXC_OFF_INST:
#if	  (CPU == PPC85XX)
	    pExcInfo->mcesr = pEsf->esr;
	    /* XXX
	    pExcInfo->valid = _EXC_INFO_DEFAULT | _EXC_INFO_NIA;
	    */
	    pExcInfo->valid = (_EXC_INFO_DEFAULT | _EXC_INFO_NIA |
                               _EXC_INFO_ESR) &
                              ~_EXC_INFO_CIA;
#else	  /* CPU == PPC85XX */
	    /* XXX
	    pExcInfo->valid = _EXC_INFO_DEFAULT | _EXC_INFO_NIA;
	    */
	    pExcInfo->valid = (_EXC_INFO_DEFAULT | _EXC_INFO_NIA) &
								 ~_EXC_INFO_CIA;
#endif	  /* CPU == PPC85XX */
	    break;
#endif	/* PPC603 : PPC604 : PPC860 : PPC85XX */

#if	((CPU == PPC509)   || (CPU == PPC555) || (CPU == PPC603) || \
         (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC860) || \
	 (CPU == PPC405F))
	case _EXC_OFF_FPU:
	    break;
#endif	/* ((CPU == PPC509)   || (CPU == PPC555) || (CPU == PPC603) || \
            (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC860) || \
	    (CPU == PPC405F)) */

	case _EXC_OFF_PROG:
#ifdef	_PPC_MSR_FP
	    if (((taskIdCurrent->options & VX_FP_TASK) != 0) &&
		((vxMsrGet() & _PPC_MSR_FP) != 0))
		{
		/* get the floating point status and control register */

		pEsf->fpcsr = vxFpscrGet();
		pExcInfo->fpcsr = pEsf->fpcsr;
		}
#endif	/* _PPC_MSR_FP */
    	    pExcInfo->valid = _EXC_INFO_DEFAULT;
#if	  (CPU == PPC85XX)
	    pExcInfo->mcesr = pEsf->esr;
    	    pExcInfo->valid |= _EXC_INFO_ESR;
#endif	  /* CPU == PPC85XX */
	    break;

	case _EXC_OFF_ALIGN:
#ifdef	_EXC_INFO_DEAR
	/* Processors which have a DEAR also set it on
	 * any of the following which they implement.
	 */
	/* cleanup - it is wrong within `case_EXC_OFFALIGN' to add other
	 * exception type cases inside `ifdef _EXC_INFO_DEAR'.  Keeping 
	 * for now in e500 for non-e500 compatability with 2.2.1
	 */
# ifdef	_EXC_OFF_PROT
	case _EXC_OFF_PROT:
# endif	/* _EXC_OFF_PROT */
# ifdef	_EXC_OFF_DATA
#  if (CPU != PPC85XX)
	case _EXC_OFF_DATA:
#  endif  /* CPU != PPC85XX */
# endif	/* _EXC_OFF_DATA */
# ifdef	_EXC_OFF_DATA_MISS
	case _EXC_OFF_DATA_MISS:
# endif	/* _EXC_OFF_DATA_MISS */
	    pExcInfo->dear   = pEsf->dear;
# if	(CPU == PPC85XX)
	    pExcInfo->mcesr  = pEsf->esr;
	    pExcInfo->valid = _EXC_INFO_DEFAULT | _EXC_INFO_DEAR |
                              _EXC_INFO_ESR;
# else	/* CPU == PPC85XX */
	    pExcInfo->valid = _EXC_INFO_DEFAULT | _EXC_INFO_DEAR;
# endif	/* CPU == PPC85XX */

#else	/* _EXC_INFO_DEAR */
	    pExcInfo->dsisr = pEsf->dsisr;
	    pExcInfo->dar   = pEsf->dar;
	    pExcInfo->valid = _EXC_INFO_DEFAULT | _EXC_INFO_DSISR |
			      _EXC_INFO_DAR;
#endif	/* _EXC_INFO_DEAR */
	    break;

	case _EXC_OFF_SYSCALL:
	    pExcInfo->valid = _EXC_INFO_DEFAULT;
	    break;

#if	(CPU == PPC601)
	case _EXC_OFF_IOERR:
	    break;

	case _EXC_OFF_RUN_TRACE:
#elif	((CPU == PPC509)   || (CPU == PPC555) || (CPU == PPC603)  || \
         (CPU == PPCEC603) || (CPU == PPC604) || (CPU == PPC860))
	case _EXC_OFF_TRACE:
# if	((CPU == PPC509) || (CPU == PPC555))
	case _EXC_OFF_FPA:
	case _EXC_OFF_SW_EMUL:
#  if	(CPU == PPC555)
	case _EXC_OFF_IPE:
	case _EXC_OFF_DPE:
#  endif  /* (CPU == PPC555) */
	case _EXC_OFF_DATA_BKPT:
	case _EXC_OFF_INST_BKPT:
	case _EXC_OFF_PERI_BKPT:
	case _EXC_OFF_NM_DEV_PORT:
# elif	((CPU == PPC603) || (CPU == PPCEC603))
	case _EXC_OFF_INST_MISS:
	case _EXC_OFF_LOAD_MISS:
	case _EXC_OFF_STORE_MISS:
# elif	(CPU == PPC604)
	case _EXC_OFF_INST_BRK:
	case _EXC_OFF_SYS_MNG:
# elif	(CPU == PPC860)
	case _EXC_OFF_SW_EMUL:
	case _EXC_OFF_INST_MISS:
	case _EXC_OFF_DATA_MISS:
	case _EXC_OFF_INST_ERROR:
	case _EXC_OFF_DATA_ERROR:
	case _EXC_OFF_DATA_BKPT:
	case _EXC_OFF_INST_BKPT:
	case _EXC_OFF_PERI_BKPT:
	case _EXC_OFF_NM_DEV_PORT:
# endif	/* 5xx : 603 : 604 : 860 */
#elif     ( (CPU == PPC403)||(CPU==PPC405)||(CPU==PPC405F) )
	case _EXC_OFF_WD:
        case _EXC_OFF_DBG:
	case _EXC_OFF_INST:
	case _EXC_OFF_INST_MISS:
            pExcInfo->valid = _EXC_INFO_DEFAULT;
            break;
#endif  /* 601 : 5xx | 60x | 860 : 40x -- none needed for 440 */
	default:
    	    pExcInfo->valid = _EXC_INFO_DEFAULT;
	    break;
	}

    return (sizeof (ESFPPC));
    }
