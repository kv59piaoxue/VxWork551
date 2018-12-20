/* tx79Lib.c - Toshiba Tx79 support library */

/* Copyright 1984-2002 Wind River Systems, Inc. */
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
01c,15nov02,jmt  Add Interrupt Exception Handler
01b,03oct02,jmt  Modify to resolve code review issues
01a,04sep02,jmt  written.
*/

/*
DESCRIPTION
This library provides a low-level support for the Toshiba Tx79 processor.

INITIALIZATION

SEE ALSO:

*/

#include "vxWorks.h"
#include "iv.h"
#include "intLib.h"
#include "esf.h"
#include "arch/mips/dsmMipsLib.h"

/* imports */
extern void excNormVecInit(void *vecAdrs);

#if (CPU == MIPS64)
extern void excExcHandle(int vecNum, ESFMIPS * pEsf, REG_SET * pRegs);
extern STATUS fppEmulateBranch (ESFMIPS *pEsf, uint32_t brInstr,
				uint32_t fpcsr);
extern void tx79AMult64(uint64_t j, uint64_t k, uint64_t* pResLow,
			uint64_t* pResHigh);
#endif	/* (CPU == MIPS64) */

/* globals */

/* The define below this comment will enable the use of the C language
 * version of the 64 bit mult (tx79Mult64) instead of the Asm version.
 * They both do the same job, the assembly is faster.
 */
/* #define USE_C_MULT64_ROUTINE */

/* Instruction Encodings for Unsupported Instructions
 *
 * Note: Mask only allows for two operand instructions (per MIPS spec)
 */

#define INSTR_MASK         (0xFC00FFFF)
#define DDIV_INSTR         (0x0000001E)
#define DDIVU_INSTR        (0x0000001F)
#define DMULT_INSTR        (0x0000001C)
#define DMULTU_INSTR       (0x0000001D)
#if 0
/* for testing on tx49 */
#define DDIV_INSTR         (0x00000001)
#define DDIVU_INSTR        (0x00000005)
#define DMULT_INSTR        (0x0000000a)
#define DMULTU_INSTR       (0x0000000b)
#endif

/* Interrupt Exception Definition */

#define TX79_INT_VEC       (K0BASE+0x200)          /* interrupt vector */

#if (CPU == MIPS64)
/* Protect from initializing more than once */

uint8_t tx79LibInitialized = FALSE;

/* storage for old Reserved Inst Handler */

typedef void (*resIntHandlerType)(int vecNum, ESFMIPS * pEsf, REG_SET * pRegs);

resIntHandlerType oldResInstHandler;
#endif  /* (CPU == MIPS64) */

/* forward declarations */

#if (CPU == MIPS64)
void tx79ResvdInstHandler (int vectorNum, ESFMIPS *pEsf, REG_SET *pRegs);
void tx79ddiv(uint64_t j, uint64_t k, uint64_t* pRes, uint64_t* pRem);
void tx79ddivu(uint64_t j, uint64_t k, uint64_t* pRes, uint64_t* pRem);
void tx79dmult(uint64_t j, uint64_t k, uint64_t* pResLow, uint64_t* pResHigh);
void tx79dmultu(uint64_t j, uint64_t k, uint64_t* pResLow, uint64_t* pResHigh);
#endif	/* (CPU == MIPS64) */

/******************************************************************************
*
* tx79ArchInit - initialize tx79 support.
*
* This routine must be called before using unsupported 64 bit mult/div
* instructions.
*
* NOMANUAL
*/

void tx79ArchInit (void)
    {
    /* initialize Interrupt Exception Handler */

    excNormVecInit((void *) TX79_INT_VEC);

#if (CPU == MIPS64)

    /* only initialize once */
    
    if (tx79LibInitialized == FALSE)
	{
	tx79LibInitialized = TRUE;
	
	/* save old reserved instruction handler */
    
	oldResInstHandler = (resIntHandlerType)
	  intVecGet((FUNCPTR *) INUM_TO_IVEC(IV_RESVDINST_VEC));
    
	/* Register Reserved Instruction Handler */
    
	intVecSet((FUNCPTR *) INUM_TO_IVEC(IV_RESVDINST_VEC),
		  (FUNCPTR) tx79ResvdInstHandler);
	}
#endif	/* (CPU == MIPS64) */
    }

#if (CPU == MIPS64)

/* Tx79 does not support 64-bit mult/div insns */

/******************************************************************************
*
* tx79ResvdInstHandler - Reserved Instruction Handler for the TX79
*
* This routine is called when a Reserved Instruction exception is raised
* in the TX79.  If the instruction is an unsupported 64 bit mult/div
* instruction, we will simulate the instruction and return.  Otherwise,
* we will raise an exception by calling excExcHandle.
*
* NOMANUAL
*/

void tx79ResvdInstHandler
    (
    int vectorNum,
    ESFMIPS *pEsf,
    REG_SET *pRegs
    )
    {
    INSTR instruction;
    INSTR *pNextInstr;
    STATUS status;
    REGISTERTYPE *pInstrDecode;
    uint64_t rs;
    uint64_t rt;
    uint64_t resultHigh;
    uint64_t resultLow;
    
    /* Determine the PC for the instruction that caused the exception */

    instruction = *pRegs->pc;

    /* calculate return address */
    /* Check to see if the instruction was in a Branch Delay slot */

    if ((pEsf->cause & CAUSE_BD) != 0)
	{
	/* Instruction is in the branch delay slot, simulate the branch */

	pNextInstr =
	  (INSTR *) fppEmulateBranch(pEsf, instruction, pEsf->fpcsr);
	if ((int) pNextInstr == 1)
	    {
	    /* branch emulation failed, raise exception */

	    if (oldResInstHandler != NULL)
		{
		oldResInstHandler(vectorNum, pEsf, pRegs);
		}
	    else
		{
		excExcHandle(vectorNum, pEsf, pRegs);
		}
	    }
	}
    else
	{
	pNextInstr = pRegs->pc + 1;
	}

    /* decode instruction */
    status = OK;
    switch (instruction & INSTR_MASK)
	{
	case DMULT_INSTR:
	case DMULTU_INSTR:
	case DDIV_INSTR:
	case DDIVU_INSTR:
	    /* decode the instruction */

	    pInstrDecode = (REGISTERTYPE *) &instruction;
	    rs = pRegs->gpreg[pInstrDecode->rs];
	    rt = pRegs->gpreg[pInstrDecode->rt];

	    /* emulate instruction */
	    
	    switch (instruction & INSTR_MASK)
		{
		case DMULT_INSTR:
		    tx79dmult(rs, rt, &resultLow, &resultHigh);
		    break;
		case DMULTU_INSTR:
		    tx79dmultu(rs, rt, &resultLow, &resultHigh);
		    break;
		case DDIV_INSTR:
		    tx79ddiv(rs, rt, &resultLow, &resultHigh);
		    break;
		case DDIVU_INSTR:
		    tx79ddivu(rs, rt, &resultLow, &resultHigh);
		    break;
		}

	    /* save results in hi and lo */
	    pRegs->hi = resultHigh;
	    pRegs->lo = resultLow;
	    
	    break;
	    
	default:
	    status = ERROR;
	    break;
	}

    /* if the instruction was successfully emulated, return to the
     * instruction after the emulated instruction
     */

    if (status == OK)
	{
	/* update the epc to point to the next instruction */

	pRegs->pc = pNextInstr;
	}
    else
	{
	/* raise exception */

	excExcHandle(vectorNum, pEsf, pRegs);
	}
    }


/******************************************************************************
*
* tx79Div64 - perform a 64 bit unsigned divide
*
* This routine does a 64 bit unsigned divide and returns the result and
* remainder.  Do not call this routine directly, call either tx79ddiv or
* tx79ddivu.
*
* NOMANUAL
*/

static void tx79Div64(uint64_t j,
		      uint64_t k,
		      uint64_t *pRes,
		      uint64_t *pRem)
    {
    int64_t i, m;
    uint64_t n;
    uint32_t c;

    if (((k-1) & k) == 0)
	{
	/* Divide by power of 2. */

	*pRem = j & (k-1);

	/* shift value until k = 1 */
	
	n = j;
	if((k & 0x00000000ffffffffll) == 0)
	    {
	    k >>= 32;
	    n >>= 32;
	    }
	c = k;
	if((c & 0xffff) == 0)
	    {
	    c >>= 16;
	    n >>= 16;
	    }
	if((c & 0xff) == 0)
	    {
	    c >>= 8;
	    n >>= 8;
	    }
	while (c >>= 1)
	    {
	    n >>= 1;
	    }
	}
    else if(((m = j | k) & 0xffffffff00000000ll) == 0)
	{
	/* each value fits in 32 bits, use long word arithmetic */
	
	n = (uint32_t)j/(uint32_t)k;
	*pRem = (uint32_t)j - ((uint32_t)n * (uint32_t)k);
	}
    else
	{
	/* not a divide by power of 2 and more than 32 bits */

	/* set mask to uppermost byte that is non-zero */
	
	i = 0xff00000000000000ll;
	if ((m & i) == 0)
	    {
	    i >>= 8;
	    if ((m & i) == 0)
		{
		i >>= 8;
		if ((m & i) == 0)
		    {
		    i >>= 8;
		    }
		}
	    }

	/* shift the denominator to left until it is greater than
	 * the numerator.
	 */
	
	c = 0;            /* number of bits the denominator is shifted */
	while ((k & i) == 0)
	    {
	    k <<= 8;
	    c += 8;
	    }

	/* shift single bits until j < k */
	
	if(j & 0x8000000000000000ll)
	    {
	    while ((k & 0x8000000000000000ll) == 0)
		{
		k <<= 1;
		c++;
		}
	    n = 0;
	    if (j >= k)
		{
		j -= k;
		n |= 1;
		}
	    }
	else
	    {
	    while (k <= j)
		{
		k <<= 1;
		c++;
		}
	    n = 0;
	    }

	/* subtract the shifted denominator from numerator until the result
	 * bits are full
	 */
	
	while (c-- > 0)
	    {
	    k >>= 1;
	    n <<= 1;
	    if (j >= k)
		{
		j -= k;
		n |= 1;
		}
	    }

	/* save the remainder */
	
	*pRem = j;
	}

    /* result is stored in n */
    
    *pRes = n;
    }

#ifdef USE_C_MULT64_ROUTINE
/******************************************************************************
*
* tx79Mult64 - perform a 64 bit unsigned multiply
*
* This routine does a 64 bit unsigned multiply and returns the result as
* two 64 bit unsigned integers.  Do not call this routine directly, call
* either tx79dmult or tx79dmultu.
*
* The C compiler will truncate all results to 32 bits.  For this reason,
* 16 bit multiplies must be used.  The 16 bit values will be stored in
* 32 bit integers so that the 32 bit result will not be truncated.
*
* NOMANUAL
*/

static void tx79Mult64(uint64_t j,
		       uint64_t k,
		       uint64_t *pResLow,
		       uint64_t *pResHigh)
    {
    uint32_t j0, j1, j2, j3;
    uint32_t k0, k1, k2, k3;
    uint64_t res0, res1, res2;

    /* split up the incoming values */

    j0 = (uint32_t) (j & 0xffff);
    j1 = (uint32_t) ((j >> 16) & 0xffff);
    j2 = (uint32_t) ((j >> 32) & 0xffff);
    j3 = (uint32_t) ((j >> 48) & 0xffff);
    k0 = (uint32_t) (k & 0xffff);
    k1 = (uint32_t) ((k >> 16) & 0xffff);
    k2 = (uint32_t) ((k >> 32) & 0xffff);
    k3 = (uint32_t) ((k >> 48) & 0xffff);

    /* multiply the pieces
     * To keep the resN variables from overflowing while summing,
     * the values added to resN will never be greater than 48 bits.
     * Except for the j3 * k3 product.  If this overflows, the
     * result will overflow.
     */

    /* res0 stores the lower 32 bits of the result */
    
    res0 = (uint64_t) (j0 * k0);
    res0 += (uint64_t) (j0 * k1) << 16;
    res0 += (uint64_t) (j1 * k0) << 16;

    /* res1 stores the second 32 bits of the result
     * it starts out with the overflow from res0
     */

    res1 = (res0 >> 32);
    res1 += (uint64_t) (j1 * k1);
    res1 += (uint64_t) (j0 * k2);
    res1 += (uint64_t) (j2 * k0);
    res1 += (uint64_t) (j1 * k2) << 16;
    res1 += (uint64_t) (j2 * k1) << 16;
    res1 += (uint64_t) (j0 * k3) << 16;
    res1 += (uint64_t) (j3 * k0) << 16;

    /* res2 stores the upper 64 bits of the result
     * it starts out with the overflow from res1
     */

    res2 = (res1 >> 32);
    res2 += (uint64_t) (j2 * k2);
    res2 += (uint64_t) (j1 * k3);
    res2 += (uint64_t) (j3 * k1);
    res2 += (uint64_t) (j2 * k3) << 16;
    res2 += (uint64_t) (j3 * k2) << 16;
    res2 += (uint64_t) (j3 * k3) << 32;

    /* combine and save the results */
    
    *pResLow = (res0 & 0xffffffff) + ((res1 & 0xffffffff) << 32);
    *pResHigh = res2;
    
    }
#endif /* ifdef USE_C_MULT64_ROUTINE */

/******************************************************************************
*
* tx79ddiv - perform a 64 bit signed division
*
* This routine does a 64 bit signed division and returns the result as
* a 64 bit signed result and a 64 bit signed remainder.
*
* NOMANUAL
*/

void tx79ddiv(uint64_t j,
	      uint64_t k,
	      uint64_t* pRes,
	      uint64_t* pRem)
    {
    int s;  /* sign of result */
    int ns; /* sign of remainder */
    
    /* make values positive and determine sign of result */
    
    s = 0;
    ns = 0;
    if ((int64_t)j < 0)
	{
	j = -j;
	s ^= 1;
	ns = 1;
	}
    if ((int64_t)k <= 0)
	{
	/* handle divide by zero case */
	
	if ((int64_t)k == 0)
	    {
	    *pRes = s ? 0x8000000000000000ull : 0x7fffffffffffffffull;
	    *pRem = 0;
	    return;
	    }
	k = -k;
	s ^= 1;
	}

    /* use unsigned div routine */
    
    tx79Div64(j, k, pRes, pRem);

    /* modify result back to correct sign */
	
    *pRes = s ? -(*pRes) : *pRes;
    *pRem = ns ? -(*pRem) : *pRem;
}

/******************************************************************************
*
* tx79ddivu - perform a 64 bit unsigned division
*
* This routine does a 64 bit unsigned division and returns the result as
* a 64 bit unsigned result and a 64 bit unsigned remainder.
*
* NOMANUAL
*/

void tx79ddivu(uint64_t j,
	       uint64_t k,
	       uint64_t* pRes,
	       uint64_t* pRem)
    {

    /* handle divide by zero case */
    
    if (k == 0)
	{
	*pRes = 0;
	*pRem = 0;
	}
    else
	tx79Div64(j, k, pRes, pRem);
    }

/******************************************************************************
*
* tx79dmult - perform a 64 bit signed multiplication
*
* This routine does a 64 bit signed multiplication and returns the result as
* a 128 bit signed result.
*
* NOMANUAL
*/

void tx79dmult(uint64_t j,
	       uint64_t k,
	       uint64_t* pResLow,
	       uint64_t* pResHigh)
    {
    int s;

    /* take shortcut if either value is 0 */
    
    if ((j == 0) || (k == 0))
	{
	*pResLow = 0;
	*pResHigh = 0;
	}
    else
	{
	/* make values positive and determine sign of result */
    
	s = 0;
	if ((int64_t)j < 0)
	    {
	    j = -j;
	    s ^= 1;
	    }
	if ((int64_t)k < 0)
	    {
	    k = -k;
	    s ^= 1;
	    }

	/* use unsigned multiply */
	
#ifdef USE_C_MULT64_ROUTINE
	tx79Mult64(j, k, pResLow, pResHigh);
#else  /* ifdef USE_C_MULT64_ROUTINE */
	tx79AMult64(j, k, pResLow, pResHigh);
#endif /* ifdef USE_C_MULT64_ROUTINE */

	/* modify result back to correct sign */

	if (s == 1)
	    {
	    if (*pResLow != 0)
		{
		*pResLow = -(*pResLow);
		*pResHigh =  ~(*pResHigh);
		}
	    else
		{
		*pResHigh =  -(*pResHigh);
		}		
	    }
	}
    }

/******************************************************************************
*
* tx79dmultu - perform a 64 bit unsigned multiplication
*
* This routine does a 64 bit unsigned multiplication and returns the result as
* a 128 bit unsigned result.
*
* NOMANUAL
*/

void tx79dmultu(uint64_t j,
	       uint64_t k,
	       uint64_t* pResLow,
	       uint64_t* pResHigh)
    {
    if ((k == 0) || (j == 0))
	{
	*pResLow = 0;
	*pResHigh = 0;
	}
    else
#ifdef USE_C_MULT64_ROUTINE
	tx79Mult64(j, k, pResLow, pResHigh);
#else  /* ifdef USE_C_MULT64_ROUTINE */
	tx79AMult64(j, k, pResLow, pResHigh);
#endif /* ifdef USE_C_MULT64_ROUTINE */
    }

#endif	/* (CPU == MIPS64) */
