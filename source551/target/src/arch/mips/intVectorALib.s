/* intVectorALib.s - assembly language vectored interrupt handling stubs */

/* Copyright 2001 Wind River Systems, Inc. */
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
01e,18jan02,agf  add explicit align directive to data section(s)
01d,01aug01,mem  Diab integration.
01c,16jul01,ros  add CofE comment
01b,12jun01,agf  make vectored interrupt's arguement to WindView unique from
                 non-vectored interrupt's
01a,21may01,agf  intiial creation

*/

/*
DESCRIPTION
This module contains the assembly language vectored interrupt handling
stubs intVectorVec<0-15> and intVectorStub. The intVectorVec<0-15> are
placed at each of the addresses corresponding to a RM7K interrupt
vector address. The vector routines mark the vector and call the common
stub routine which saves the context and calls the appropriate ISR.

intVectorVec15 is special in that it automatically calls the intStub
routine. This is done for the purpose of backwards compatibility. If
only one or two vectored interrupts are desired, the remaining vectors
can be set with an IPL of 15 and continue to work without any change.

There are no user-callable routines in this module.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "private/eventP.h"
#include "asm.h"
#include "esf.h"
#include "sysLib.h"

/* registers */
#define C0_1_IC		$20		/* Interrupt control (CP0 set 1) */
#define C0_1_IPLHI	$19		/* Int Priority Level High	 */
#define C0_1_IPLLO	$18		/* Int Priority Level Low	 */

/* bit masks/fields */
#define VS_0		0x00		/* all IPLs use base vector	 */
#define VS_32		0x01		/* 32  byte vector spacing	 */
#define VS_64		0x02		/* 64  byte vector spacing	 */
#define VS_128		0x04		/* 128 byte vector spacing	 */
#define VS_256		0x08		/* 256 byte vector spacing	 */
#define VS_512		0x10		/* 512 byte vector spacing	 */

#define CAUSE_IV	0x01000000	/* Int Vectoring enable		 */

/* constants */
#define WV_VEC_INT_OFFSET      16	/* match to size of intPrioTable */

#define	IPL_DEFAULT_LO	0xffffffff	/* IM[7:0] use priority 15	 */
#define	IPL_DEFAULT_HI	0x00ffffff	/* IM[13:0] use priority 15	 */

#define INTERRUPT_VECTOR_0	0	/* constant for mark of the	 */
					/*   active interrupt vector	 */


/* WARNING!!!
 *   The following defines must be updated whenever the routine 
 *    intVectorVec0  is touched
 */
#define VS_VECTOR_MASK		VS_32	/* VS set by intVectorVecInit	 */

#define VECTOR_SPACING		32	/* num of bytes between the	 */
					/*  intVectorVec<0-14> routines	 */

#define MAGIC_INSTRUCT_V14	0x241a000e
				/* combination of INTERRUPT_VECTOR_14    */
				/*   AND the preceding instruction;      */
				/*   nec. for word alignment constraints */

#define VECTOR_MARK_OFFSET	0	/* number of bytes from start of    */
					/*  vector to locate the mark MOD 4 */

#define	IPL0_VECTOR_ADDR	0x80000200 /* memory location of intVectors */
#define	IPL1_VECTOR_ADDR	0x80000220 /* these all change based on the */
#define	IPL2_VECTOR_ADDR	0x80000240 /*   VS value of VECTORVEC_SIZE  */
#define	IPL3_VECTOR_ADDR	0x80000260
#define	IPL4_VECTOR_ADDR	0x80000280
#define	IPL5_VECTOR_ADDR	0x800002a0
#define	IPL6_VECTOR_ADDR	0x800002c0
#define	IPL7_VECTOR_ADDR	0x800002e0
#define	IPL8_VECTOR_ADDR	0x80000300
#define	IPL9_VECTOR_ADDR	0x80000320
#define	IPL10_VECTOR_ADDR	0x80000340
#define	IPL11_VECTOR_ADDR	0x80000360
#define	IPL12_VECTOR_ADDR	0x80000380
#define	IPL13_VECTOR_ADDR	0x800003a0
#define	IPL14_VECTOR_ADDR	0x800003c0
#define	IPL15_VECTOR_ADDR	0x800003e0
/* end WARNING!!! */


	/* internal */

	.globl  intVectorVecInit /* BSP initialization routine  */

	/* external */

	.extern	intCnt			/* interrupt depth	*/
	.extern	areWeNested		/* Boolean for int nesting */
	.extern	vxIntStackBase		/* interrupt stack base */
	.extern	errno			/* unix like errno */
	.extern bcopy			/* func ptr */
	.extern cacheTextUpdate 	/* func ptr */ 

#ifdef WV_INSTRUMENTATION
	.extern	_func_evtLogT0			/* _func_evtLogT0 func ptr */
	.extern	_func_trgCheck			/* _func_trgCheck func ptr */
	.extern	evtAction    			
	.extern	wvEvtClass		
	.extern	trgEvtClass			

#endif /* WV_INSTRUMENTATION */

	.data
	.align	4
intActiveIPL:
	.word	0

	.text
	.set	reorder


/*******************************************************************************
*
* intVectorStub	- save context and dispatch interrupt service routines
*
* This is the interrupt dispatcher that is pointed to by the individual
* interrupt vectors.  In this routine we take care of saving state, and
* jumping to the appropriate routines.  On exit from handling we also
* return here to restore state properly.
*
* This routine is not callable!!  This routine does not include save and
* restore of floating point state.
*
* INTERNAL
* The goal here is to turn interrupts back on a quickly as possible.
* Some guidelines we have followed are that k0 and k1 can ONLY be 
* used in non-interruptible sections. Control is finally passed to intExit
* with interrupts disabled.  Also, before we turn interrupts back on we must 
* save as a minimum the state of the processor that changed upon interrupt 
* generation (volatile registers).  Volatile registers include the EPC, 
* and STATUS registers.  Also saved before interrupts are enabled, are the 
* sp, v0, and at regs.  These registers are not volatile, but used in reading 
* and saving volatile registers, and calculation of the interrupted processor 
* state.  Saved registers (s regs) are not saved upon interrupts because the 
* MIPS compiler philosophy is to save any s-regs they use before any call.
*
*		at	- so assembler can use at	(non-volatile)
*		sp	- we use interrupt stack	(non-volatile)
*		epc	- changed upon excpt generation	(volatile)
*		cause	- changed upon excpt generation	(volatile)
*		status	- must read to bugging int	(volatile)
*		badva	- changed upon excpt generation	(volatile)
*		v0	- holds calculated int cause	(non-volatile)
*
* All interrupts that are are of a lower priority than the active one are
* allowed.  This is done by using the mask field from the intVecTable array
* defined by the BSP author and turning those interrupt enables OFF.
*
* NOMANUAL

* void intVectorStub()

*/

	.globl	intVectorStub
	.ent	intVectorStub
intVectorStub:
	.set	noat
/*
 *	Are we nested interrupt ???
 */
	lw	k1, areWeNested		/* grab areWeNested */
	bne	k1, zero, nested	/* if in isr don't reset sp	 */
	lw	k0, vxIntStackBase	/* else {grab addr of int stack	 */
	subu	k0, ESTKSIZE		/* make room for frame		 */
	SW	sp, E_STK_SP(k0)	/* save sp on int stack		 */
	move	sp, k0			/* init new int stack ptr}	 */
	b	save_critical		/* jump over stack manip	 */
nested:
	SW	sp, E_STK_SP-ESTKSIZE(sp) /* save sp in new intstk frame */
	subu	sp, ESTKSIZE		/* make new int stk frame	 */
save_critical:
	SW	AT,E_STK_AT(sp)		/* save as resvd reg	         */
	.set	at
#ifndef WV_INSTRUMENTATION
	SW	v0,E_STK_V0(sp)		/* save return reg 0	         */
#endif /* WV_INSTRUMENTATION */

	/*
         * The following code replaces intEnt so I don't need
	 * to save ra while interrupts are masked
         */

	addu	k1, 1  			/* increment areWeNested         */
	sw	k1, areWeNested		/* update value	                 */
	lw	k1, intCnt		/* load intCnt	                 */
	addu	k1, 1  			/* increment intCnt              */
	sw	k1, intCnt		/* update value	                 */
#ifdef WV_INSTRUMENTATION

/*
 * Begin state save
 */

intStateSave:
	SW	zero,E_STK_ZERO(sp)	/* init zero reg storage	 */
        SW      v0,E_STK_V0(sp)         /* save func return 0            */
        SW      v1,E_STK_V1(sp)         /* save func return 1            */
        SW      a0,E_STK_A0(sp)         /* save passed param 0           */
        SW      a1,E_STK_A1(sp)         /* save passed param 1           */
        SW      a2,E_STK_A2(sp)         /* save passed param 2           */
        SW      a3,E_STK_A3(sp)         /* save passed param 3           */
        SW      t0,E_STK_T0(sp)         /* save temp reg 0               */
        SW      t1,E_STK_T1(sp)         /* save temp reg 1               */
        SW      t2,E_STK_T2(sp)         /* save temp reg 2               */
        SW      t3,E_STK_T3(sp)         /* save temp reg 3               */
        SW      t4,E_STK_T4(sp)         /* save temp reg 4               */
        SW      t5,E_STK_T5(sp)         /* save temp reg 5               */
        SW      t6,E_STK_T6(sp)         /* save temp reg 6               */
        SW      t7,E_STK_T7(sp)         /* save temp reg 7               */
        SW      t8,E_STK_T8(sp)         /* save temp reg 8               */
        SW      t9,E_STK_T9(sp)         /* save temp reg 9               */
        SW      ra,E_STK_RA(sp)         /* save return address           */
        mflo    t2                      /* read entry lo reg             */
        mfhi    t3                      /* read entry hi reg             */
        SW      t2,E_STK_LO(sp)         /* save entry lo reg             */
        SW      t3,E_STK_HI(sp)         /* save entry hi reg             */
0:	

#else /* WV_INSTRUMENTATION */
	lw	k0,errno
	sw	k0,E_ERRNO(sp)		/* save errno                    */
#endif /* WV_INSTRUMENTATION */
	.set	noreorder
	mfc0	k1, C0_SR		/* read status register          */
	mfc0	k0, C0_EPC		/* read exception pc             */
	mfc0	v0, C0_CAUSE		/* read cause register           */
	HAZARD_CP_READ
	sw	k1, E_STK_SR(sp)	/* save status on stack          */
	sw	k0, E_STK_EPC(sp)	/* save EPC on stack             */
	sw	v0, E_STK_CAUSE(sp)	/* save cause on stack           */
	.set	reorder

#ifdef WV_INSTRUMENTATION

        /*
         * windview instrumentation - BEGIN
         * enter an interrupt handler.
         */
        lw      t0, evtAction                   /* is instrumentation on? */
        beqz    t0, noIntEnt

	/* we are checking
	 * if ((wvEvtClass&(WV_CLASS_1_ON)) != (WV_CLASS_1_ON)) 
	 * leave WV instrumentation and check triggering 
	 */
        lw      t0, wvEvtClass                   
        li      t4, WV_CLASS_1_ON               
        and     t0, t0, t4
        bne     t4, t0, trgCheckIntEnt

        /* interrupts are locked */
        /* all registers are saved */

	lw	t2, intActiveIPL	/* get interrupting vector's mark */
        addu    a0, t2, MIN_INT_ID+WV_VEC_INT_OFFSET+1

        lw      t1, _func_evtLogT0
        jal     t1                              /* call evtLogT0 routine */

        lw      v0, E_STK_CAUSE(sp)     /* restore the value of v0. We    */
					/* might have lost it in evtLogT0 */
trgCheckIntEnt:

        lw      t0, trgEvtClass
        li      t4, TRG_CLASS_1_ON
        and     t0, t0, t4
        bne     t4, t0, noIntEnt

	lw	t2, intActiveIPL	/* get interrupting vector's mark */
        addu    a0, t2, MIN_INT_ID+WV_VEC_INT_OFFSET+1

        li      a1, TRG_CLASS1_INDEX
        li      a2, 0x0

        lw      t1, _func_trgCheck
        jal     t1                              /* call evtLogT0 routine */

        lw      v0, E_STK_CAUSE(sp)     /* restore the value of v0. We    */
noIntEnt:
        /* windview instrumentation - END */

        lw      k0,errno
        sw      k0,E_ERRNO(sp)          /* save errno                    */

#else /* WV_INSTRUMENTATION */
      	SW	t3,E_STK_T3(sp)		/* save temp reg 3 (early)       */
      	SW	t2,E_STK_T2(sp)		/* save temp reg 2 (early)       */
	SW	t1,E_STK_T1(sp)		/* save temp reg 1 (early)       */
#endif /* WV_INSTRUMENTATION */


/*
 * Check for spurious interrupts  -- SKIP for vectored interrupts
 */


/*
 * Disable all lower priority interrupts
 */
	/* k1 has STATUS and v0 has CAUSE */

	cfc0	t3, C0_1_IC		/* get IntControl		 */
	SW	t3, E_STK_ZERO(sp)	/* stash IntCount in ESF	 */

        lw      k0, intActiveIPL	/* get mark for calling vector	 */
	sll	k0, 3			/* mult index by 2*word size	 */
	lw	t1, intVecTable+0(k0)	/* get index into Bsr table	 */
	lw	t2, intVecTable+4(k0)	/* get mask bits for this IPL	 */
	and	k0, t2, 0xff00		/* isolate IM[15:8]		 */
	not	k0			/* invert interrupt mask	 */
	and	t3, k0			/* apply the mask		 */
	ctc0	t3, C0_1_IC		/* set IntControl		 */

	and	k0, t2, 0x00ff		/* isolate IM[7:0]		 */
	sll	k0, 8			/* align with SR[IM] field	 */
	not	k0			/* invert interrupt mask	 */
	and	k1, k0			/* apply the mask		 */
	and 	k1, ~SR_EXL
	mtc0	k1, C0_SR		/* enable interrupts w/ new mask */
	

/*
 * Begin state save
 */

#ifndef WV_INSTRUMENTATION
intStateSave:
	mflo	t2			/* read entry lo reg	         */
	SW	t2,E_STK_LO(sp)		/* save entry lo reg        	 */
	mfhi	t2			/* read entry hi reg	         */
	SW	t2,E_STK_HI(sp)		/* save entry hi reg	         */
0:					/* save func return 0, see above */
	SW	v1,E_STK_V1(sp)		/* save func return 1	         */
	SW	a0,E_STK_A0(sp)		/* save passed param 0        	 */
	SW	a1,E_STK_A1(sp)		/* save passed param 1	         */
	SW	a2,E_STK_A2(sp)		/* save passed param 2	         */
	SW	a3,E_STK_A3(sp)		/* save passed param 3	         */
	SW	t0,E_STK_T0(sp)		/* save temp reg 0	         */
					/* save temp reg 1, see above	 */
					/* save temp reg 2, see above	 */
					/* save temp reg 3, see above	 */
	SW	t4,E_STK_T4(sp)		/* save temp reg 4	         */
	SW	t5,E_STK_T5(sp)		/* save temp reg 5	         */
	SW	t6,E_STK_T6(sp)		/* save temp reg 6	         */
	SW	t7,E_STK_T7(sp)		/* save temp reg 7	         */
	SW	t8,E_STK_T8(sp)		/* save temp reg 8	         */
	SW	t9,E_STK_T9(sp)		/* save temp reg 9	         */
	SW	ra,E_STK_RA(sp)		/* save return address	         */

#endif /* WV_INSTRUMENTATION */

/*
 * Call the application ISR
 */

	move	a0, t1			/* pass vector number		 */
	move	a1, sp			/* pass exc stack frame		 */
	sll	t1, 2			/* mult index by wordsize	 */
	lw	v1, excBsrTbl(t1)	/* get ISR address 		 */
	jal	v1			/* jump to service routine 	 */

/*
 * Begin state restoration
 */

Restore:
	lw	t2,E_ERRNO(sp)
	sw	t2,errno		/* restore errno                 */
	LW	v1,E_STK_V1(sp)		/* restore func ret 0	         */
	LW	a0,E_STK_A0(sp)		/* restore passed param 0	 */
	LW	a1,E_STK_A1(sp)		/* restore passed param 1	 */
	LW	a2,E_STK_A2(sp)		/* restore passed param 2	 */
	LW	a3,E_STK_A3(sp)		/* restore passed param 3	 */
	LW	t0,E_STK_T0(sp)		/* restore temp reg 0            */
	LW	t4,E_STK_T4(sp)		/* restore temp reg 4            */
	LW	t5,E_STK_T5(sp)		/* restore temp reg 5            */
	LW	t6,E_STK_T6(sp)		/* restore temp reg 6            */
	LW	t7,E_STK_T7(sp)		/* restore temp reg 7            */
	LW	t8,E_STK_T8(sp)		/* restore temp reg 8            */
	LW	ra,E_STK_RA(sp)		/* restore return addr           */
	LW	t9,E_STK_LO(sp)		/* grab entry hi reg             */
	mtlo	t9			/* restore entry hi reg          */
	LW	t9,E_STK_HI(sp)		/* grab entry lo reg             */
	mthi	t9			/* restore entry hi reg          */
0:	
	LW	t9,E_STK_T9(sp)		/* restore temp reg 9            */

	/*
	 * Registers restored after this point must only be registers
	 * which are considered volatile.  This currently 
	 * includes SR, EPC, AT, sp, v0, t1, and t2.  Any additions to
	 * the volatile set of registers (see comments above) should
	 * be mirrored with restores after the label restoreVolatile.
	 */

restoreVolatile:
	lw	t1,E_STK_SR(sp)		/* read old SR		         */
	/* ensure imask == 0 before setting EXL */
	li	v0,SR_IE	
	HAZARD_VR5400
	mtc0	v0,C0_SR
	HAZARD_CP_WRITE

	.set	noreorder

	LW	t2, E_STK_ZERO(sp)	/* get IntCount from ESF	 */
	ctc0	t2, C0_1_IC		/* set IntControl		 */
	mtc0	t1,C0_SR		/* put on processor	         */
	.set	reorder
	LW	v0,E_STK_V0(sp)		/* restore func ret 0	         */
	LW	t3,E_STK_T3(sp)		/* restore temp reg 3            */
      	LW	t2,E_STK_T2(sp)		/* restore temp reg 2	         */
	LW	t1,E_STK_T1(sp)		/* restore temp reg 1	         */

	j	intExit			/* exit kernel, exception frame  */
					/* on interrupt stack            */
	
intVectorStubEnd:
	.end	intVectorStub


/*********************************************************************
*
* intVectorVecInit - Initialization routine which installs the interrupt
*                    vector service routines to their proper locations
*                    in memory and initializes the appropriate registers
*                    so as to enable vectored interupt handling
*
* NOMANUAL

* void intVectorVecInit()
*/

	.ent	intVectorVecInit
intVectorVecInit:
        SETFRAME(intVectorVecInit,3)
        subu    sp, FRAMESZ(intVectorVecInit)          /* need some stack */
        sw      ra, FRAMERA(intVectorVecInit)(sp)      /* save ra */
        sw      s6, FRAMER0(intVectorVecInit)(sp)      /* save s6 */
        sw      s7, FRAMER1(intVectorVecInit)(sp)      /* save s7 */

/*
 * first copy the special backwards-compatibility handler for IPL 15
 */
	la	a0, intVectorVec15	/* source			*/
	li	a1, IPL15_VECTOR_ADDR	/* destination			*/
	lw	a2, intVecSize15	/* number of bytes to copy	*/
					/* save s0 so we can use it	*/
	la	s7, bcopy		/* now call bcopy()		*/ 
	jal	s7

/*
 * next copy the interrupt handler for IPLs 0-14
 */

	la	s6, intVectorVec0	/* a0 gets wrecked by bcopy 
					 * after each call, so use s0	*/

	move	a0, s6			/* source			*/
	li	a1, IPL0_VECTOR_ADDR	/* destination			*/
	lw	a2, intVecSize0		/* number of bytes to copy	*/
	jal	s7			/* bcopy() still in s7		*/

	move	a0, s6			/* restore source arg		*/
	li	a1, IPL1_VECTOR_ADDR	/* load new destination		*/
	jal	s7

	move	a0, s6
	li	a1, IPL2_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL3_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL4_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL5_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL6_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL7_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL8_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL9_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL10_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL11_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL12_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL13_VECTOR_ADDR
	jal	s7
	move	a0, s6
	li	a1, IPL14_VECTOR_ADDR
	jal	s7

/*
 * manually update the memory locations of the vector mark index
 *   start with vector 14 and decrement until vector 0
 */
					
	li	t0, MAGIC_INSTRUCT_V14	/* t0 = instruct + mark		*/
	li	t1, IPL14_VECTOR_ADDR+VECTOR_MARK_OFFSET
					/* t1 = vector address to write	*/
	and	t2, t0, 0xffffff00	/* t2 = mask for mark equals 0  */
0:
	sw	t0, (t1)		/* update the address		*/
	subu	t1, VECTOR_SPACING	/* get next vector address	*/
	subu	t0, 1			/* decrement the mark		*/
	bne	t0, t2, 0b		/* finished once mark is zero	*/

/*
 * now sync the D-cache
 */
	li	a0, IPL0_VECTOR_ADDR
	li	a1, IPL15_VECTOR_ADDR+VECTOR_SPACING
	la	s7, cacheTextUpdate	/* sync cache			*/
	jal	s7

/*
 * lastly, initialize the registers
 */
	cfc0	t1, C0_1_IC		/* read the IntControl register	*/
	or	t1, VS_VECTOR_MASK	/* set the VS field for 	*/
					/*    spacing between vectors	*/
	ctc0	t1, C0_1_IC 		/* write the ICR		*/
	li	t1, IPL_DEFAULT_LO	/* set all IPLs to level 15   	*/
	ctc0	t1, C0_1_IPLLO
	li 	t1, IPL_DEFAULT_HI
	ctc0	t1, C0_1_IPLHI
	mfc0	t1, C0_CAUSE		/* read the CAUSE register	*/
	or	t1, CAUSE_IV		/* turn interrupt vectoring ON	*/
	mtc0	t1, C0_CAUSE		/* write the CAUSE register	*/

        lw      s7, FRAMER1(intVectorVecInit)(sp)      /* restore s7 */
        lw      s6, FRAMER0(intVectorVecInit)(sp)      /* restero s6 */
        lw      ra, FRAMERA(intVectorVecInit)(sp)      /* restore ra */
        addu    sp, FRAMESZ(intVectorVecInit)          

	j	ra			/* return			*/

	.end	intVectorVecInit


/*********************************************************************
*
* intVectorVec<0-14> - Instructions to load at the Rm7000 vectored interrupt
*                      vectors
*
* These instructions are copied to 0x80000200 + (VS * IPL), the vectored
* interrupt vector by the startup routine intVectorVecInit.  We must use the
* assembler pseudo op .noat  so the la instruction will not use the at
* register and mess with process state.  The .set noreorder takes instruction
* reorder control away from the assembler, and puts it in our hands.  We are
* using load address and jump to register so that we may run vxWorks out of
*  prom (see j and jal instruction definitions).
*
* WARNING:
* DO NOT MODIFY THIS ROUTINE WITHOUT ALSO UPDATING THE CONSTANTS
*   AT THE TOP OF THIS FILE
*
* NOMANUAL

* void intVectorVec<0-14>()
*/

	.ent	intVectorVec0
	.set	noat
intVectorVec0:
	li      k0, INTERRUPT_VECTOR_0  /* mark which vector */
	la	k1, intActiveIPL        /*   is calling the handler */
	sw	k0, (k1)
	la	k0, intVectorStub
	j	k0			/* jump to interrupt handler */
intVecEnd0:
	.set	at
	.end	intVectorVec0

	.data
	.align	4
intVecSize0:
	.word	intVecEnd0-intVectorVec0
	.text


/*********************************************************************
*
* intVectorVec15 - Instructions to load at the Rm7000 interrupt 
*                  priority level (IPL) 15 vector
*
* These instructions are copied to 0x80000200 + (VS * IPL_15), the vectored 
* interrupt address, by the startup routine intVectorVecInit. This routine is
* unique to the rest of the IPLs because IPL15 is reserved for backwards
* compatibility. It only calls intStub.
*
* We must use the assembler pseudo op .noat  so the la instruction will not
* use the at register and mess with process state.  We are using load 
* address and jump to register so that we may run vxWorks out of prom (see j,
* and jal instruction definitions).
*
* NOMANUAL

* void intVectorVec15()
*/

	.ent	intVectorVec15
	.set	noat
intVectorVec15:
	lw	k1, areWeNested		/* grab areWeNested */
	la	k0, excIntStub
	j	k0			/* jump to interrupt handler */
intVecEnd15:
	.set	at
	.end	intVectorVec15

	.data
	.align	4
intVecSize15:
	.word	intVecEnd15-intVectorVec15
	.text

