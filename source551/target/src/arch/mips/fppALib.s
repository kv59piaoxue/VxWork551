/* fppALib.s - floating-point coprocessor support assembly routines */

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
02d,18jan02,agf  add explicit align directive to data section(s)
02c,01aug01,mem  Diab integration.
02b,16jul01,ros  add CofE comment
02a,05jun01,mem  Added hooks for extended save/restore.
01z,09feb01,sru  implement new hazard model
01y,18jan01,pes  Cleanup handling of 32/64-bit floating point
                 init/save/restore.
01x,02jan01,pes  Correct usage of _WRS_VR5400_ERRATA conditionals around nops
01w,20dec00,pes  Update for MIPS32/MIPS64 target combinations.
01v,24aug00,dra  fix fp status reg for vr5074
01u,19jun00,dra  work around 5432 branch bug
01t,10jun99,dra	 Added FP_CONTEXT Expansion support for the NEC VR5464.
		 -Altered fppSave to support both 32 and 16 FP mode.
		 -Altered fppRestore to support both 32 and 16 FP mode.
01s,08may97,mem  added tests for SOFT_FLOAT.
01r,13aug98,kk	 fixed various bugs in fppEmulateBranch() (SPR# 20964, 21119).
		 Made regFetchTable use LW instead of lw to support both 
		 R3XXX & R4XXX.
01q,18oct93,cd   added R4000 support.
01q,18feb94,caf  fixed fppProbe() to just read the status register (SPR 3072).
01p,02sep93,yao  put back FPA emulation code.
02o,15sep92,jdi  ansified declarations for mangenable routines.
02n,12sep92,ajm  changed OPCODE_MASK to GENERAL_OPCODE_MASK, OFFSET_MASK to
		 OFFSET16_MASK
02m,22jul92,ajm  got rid of unused FPA emulation code (for space)
02l,05jun92,ajm  5.0.5 merge, notice mod history changes
02k,26may92,rrr  the tree shuffle
02j,04oct91,rrr  passed through the ansification filter
                  -changed VOID to void
                  -changed ASMLANGUAGE to _ASMLANGUAGE
                  -changed copyright notice
02i,16jan92,jdi  made fppInitialize() and fppClearFLoat() NOMANUAL.
02h,14jan92,jdi  documentation cleanup.
02g,08jan92,ajm  fixed restoration of fpp status reg in fppRestore
02f,16oct91,ajm  documentation
02e,24sep91,wmd  fixed for mangen.
02d,01aug91,ajm  moved in fppProbe.
02c,03mar91,ajm  moved clearing of fpa interrupt from sysALib.s.
02b,28jan91,ajm  read fpa control before write to insure float operations
		  are done.
02a,05jul90,ajm  port to MIPS R3000.
01g,28may88,dnw  fixed bug in fppProbe of only setting byte instead of long
		   flag.
		 made FPP_ASSEM conditionals.
		 cleaned-up.
		 removed extra spaces in .word declarations that may have
		   been screwing up the VMS port.
01f,31mar88,gae  took out save & restore in fppProbeSup() so that
		   privilege violation exceptions wouldn't be generated.
01g,28mar88,gae  oops! forgot hand-assembly for fp codes in 01f.
01f,18mar88,gae  now supports both MC68881 & MC68882.
01e,09mar88,gae  moved host specific _errno definition to hostALib.s.
01d,13feb88,dnw  added .data before .asciz above, for Intermetrics assembler.
01c,04dec87,gae  removed most HOST_TYPE dependencies - fp codes hand assembled.
01b,26aug87,gae  added include of asm.h and special HOST_IRIS version
		   of floating-point instructions.
01a,06aug87,gae  written/extracted from vxALib.s
*/

/*
DESCRIPTION
This library contains routines to be used to support the MIPS R-Series
floating-point coprocessor.
The routines fppSave() and fppRestore() save and restore all the task context
information, the programming model, which includes the 16 double precision
registers and the 1 control register.  The routine fppProbe() checks for the
presence of the MIPS floating point coprocessor.  Higher level access and
initialization routines are found in fppLib.

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

	.globl GTEXT(fppSave)
	.globl GTEXT(fppRestore)
	.globl GTEXT(fppInitialize)
	.globl GTEXT(fppClearFloat)	/* clear floating pt interrupt */
	.globl GTEXT(fppArgsToRegs)	/* place passed float args in fpa regs */
	.globl GTEXT(fppEmulateBranch)	/* emulate branch instructions */
	.globl GTEXT(fppProbe)		/* do we have an fpp present */

	.text
	.set	reorder

/******************************************************************************
*
* fppSave - save the floating-point coprocessor context
*
* This routine saves the floating-point coprocessor context.
* The context saved is:
*
*     fpcsr
*     fp0 - fp31
*
* RETURNS: N/A
*
* SEE ALSO:
* fppRestore(),
* .I "MIPS RISC Architecture"

* void fppSave
*     (
*     FP_CONTEXT *  pFpContext	/* where to save context *
*     )

*/

	.ent	fppSave
FUNC_LABEL(fppSave)
#ifndef SOFT_FLOAT
	cfc1	t0, C1_SR
	HAZARD_CP_READ
	sw	t0, FPCSR(a0)
	SWC1	fp0,FP0(a0)
	SWC1	fp1,FP1(a0)
	SWC1	fp2,FP2(a0)
	SWC1	fp3,FP3(a0)
	SWC1	fp4,FP4(a0)
	SWC1	fp5,FP5(a0)
	SWC1	fp6,FP6(a0)
	SWC1	fp7,FP7(a0)
	SWC1	fp8,FP8(a0)
	SWC1	fp9,FP9(a0)
	SWC1	fp10,FP10(a0)
	SWC1	fp11,FP11(a0)
	SWC1	fp12,FP12(a0)
	SWC1	fp13,FP13(a0)
	SWC1	fp14,FP14(a0)
	SWC1	fp15,FP15(a0)
	SWC1	fp16,FP16(a0)
	SWC1	fp17,FP17(a0)
	SWC1	fp18,FP18(a0)
	SWC1	fp19,FP19(a0)
	SWC1	fp20,FP20(a0)
	SWC1	fp21,FP21(a0)
	SWC1	fp22,FP22(a0)
	SWC1	fp23,FP23(a0)
	SWC1	fp24,FP24(a0)
	SWC1	fp25,FP25(a0)
	SWC1	fp26,FP26(a0)
	SWC1	fp27,FP27(a0)
	SWC1	fp28,FP28(a0)
	SWC1	fp29,FP29(a0)
	SWC1	fp30,FP30(a0)
	SWC1	fp31,FP31(a0)
	lw	t0,_func_fppSaveHook
	beqz	t0, 0f
	SETFRAME(fppSave,0)
	subu	sp, FRAMESZ(fppSave)		/* carve stack space */
	SW	ra, FRAMERA(fppSave)(sp)	/* save return address */
	jal	t0
	LW	ra, FRAMERA(fppSave)(sp)	/* get return address */
	addu 	sp, FRAMESZ(fppSave)		/* pop up stack */
0:
#endif	/* !SOFT_FLOAT */
	j	ra
	.end	fppSave

/******************************************************************************
*
* fppRestore - restore the floating-point coprocessor context
*
* This routine restores the coprocessor programming model.
* The context restored is:
*
*     fp0 - fp31
*     fpcsr
*
* RETURNS: N/A
*
* SEE ALSO:
* .I "MIPS RISC Architecture"

* void fppRestore
*    (
*    FP_CONTEXT *  pFpContext	/* from where to restore context *
*    )

*/

	.ent	fppRestore
FUNC_LABEL(fppRestore)
#ifndef SOFT_FLOAT
	lw	t0, _func_fppRestoreHook
	beqz	t0, 0f
	SETFRAME(fppSave,0)
	subu	sp, FRAMESZ(fppSave)		/* carve stack space */
	SW	ra, FRAMERA(fppSave)(sp)	/* save return address */
	jal	t0
	LW	ra, FRAMERA(fppSave)(sp)	/* get return address */
	addu 	sp, FRAMESZ(fppSave)		/* pop up stack */
0:
	LWC1	fp0,FP0(a0)
	LWC1	fp1,FP1(a0)
	LWC1	fp2,FP2(a0)
	LWC1	fp3,FP3(a0)
	LWC1	fp4,FP4(a0)
	LWC1	fp5,FP5(a0)
	LWC1	fp6,FP6(a0)
	LWC1	fp7,FP7(a0)
	LWC1	fp8,FP8(a0)
	LWC1	fp9,FP9(a0)
	LWC1	fp10,FP10(a0)
	LWC1	fp11,FP11(a0)
	LWC1	fp12,FP12(a0)
	LWC1	fp13,FP13(a0)
	LWC1	fp14,FP14(a0)
	LWC1	fp15,FP15(a0)
	LWC1	fp16,FP16(a0)
	LWC1	fp17,FP17(a0)
	LWC1	fp18,FP18(a0)
	LWC1	fp19,FP19(a0)
	LWC1	fp20,FP20(a0)
	LWC1	fp21,FP21(a0)
	LWC1	fp22,FP22(a0)
	LWC1	fp23,FP23(a0)
	LWC1	fp24,FP24(a0)
	LWC1	fp25,FP25(a0)
	LWC1	fp26,FP26(a0)
	LWC1	fp27,FP27(a0)
	LWC1	fp28,FP28(a0)
	LWC1	fp29,FP29(a0)
	LWC1	fp30,FP30(a0)
	LWC1	fp31,FP31(a0)
	lw	t0, FPCSR(a0)
	cfc1	t1, C1_SR	/* read to finish float operations */
	ctc1	t0, C1_SR	/* restore fpp status reg */
	HAZARD_CP_WRITE
#endif	/* !SOFT_FLOAT */
	j	ra
	.end	fppRestore

/******************************************************************************
*
* fppInitialize - initialize the floating-point coprocessor
*
* This routine initializes the coprocessor programming model.
* The context initialized is:
*
*     fp0 - fp31
*     fpcsr
*
* RETURNS: N/A
*
* SEE ALSO:
* .I "MIPS RISC Architecture"
*
* NOMANUAL

* void fppInitialize ()

*/

	.ent	fppInitialize
FUNC_LABEL(fppInitialize)
#ifndef SOFT_FLOAT
	MTC1	zero,fp0		/* zero the registers */
	MTC1	zero,fp1
	MTC1	zero,fp2
	MTC1	zero,fp3
	MTC1	zero,fp4
	MTC1	zero,fp5
	MTC1	zero,fp6
	MTC1	zero,fp7
	MTC1	zero,fp8
	MTC1	zero,fp9
	MTC1	zero,fp10
	MTC1	zero,fp11
	MTC1	zero,fp12
	MTC1	zero,fp13
	MTC1	zero,fp14
	MTC1	zero,fp15
	MTC1	zero,fp16
	MTC1	zero,fp17
	MTC1	zero,fp18
	MTC1	zero,fp19
	MTC1	zero,fp20
	MTC1	zero,fp21
	MTC1	zero,fp22
	MTC1	zero,fp23
	MTC1	zero,fp24
	MTC1	zero,fp25
	MTC1	zero,fp26
	MTC1	zero,fp27
	MTC1	zero,fp28
	MTC1	zero,fp29
	MTC1	zero,fp30
	MTC1	zero,fp31
	li	t0, FP_TASK_STATUS	/* see arch.h */
	cfc1	t1, C1_SR		/* read to finish float operations */
	ctc1	t0, C1_SR		/* load new status reg */
	HAZARD_CP_WRITE
#endif	/* !SOFT_FLOAT */
	j	ra
	.end	fppInitialize

/*******************************************************************************
*
* fppProbe - probe for the presence of a floating-point coprocessor
*
* This routine determines whether there is a
* floating-point coprocessor in the system.
*
* INTERNAL
* This routine simply reads the "coprocessor 1 usable" bit in the R-Series
* status register.  This bit must be correctly initialized in the BSP.  
* A deeper probe would be nice, but the previous attempt didn't work.
*
* RETURNS:
* OK, or ERROR if there is no floating-point coprocessor.
*
* SEE ALSO:
* .I "MIPS RISC Architecture"

* STATUS fppProbe ()

*/

	.ent	fppProbe
FUNC_LABEL(fppProbe)
#ifndef SOFT_FLOAT
	HAZARD_VR5400
	mfc0	t0, C0_SR
	HAZARD_CP_READ
	move	v0, zero		/* OK return value */
	and	t0, t0, SR_CU1		/* coprocessor 1 enabled? */
	bne	t0, zero, probeReturn
#endif	/* !SOFT_FLOAT */
	li	v0, -1			/* ERROR return value */
probeReturn:
	j	ra
	.end	fppProbe

/*******************************************************************************
*
* fppClearFloat -  clear a floating-point exception
*
* This routine zeros the exception bits from the MIPS floating-point
* unit, clearing the exception to the CPU.  It returns the contents
* of the original fpcsr register.
*
* RETURNS: The contents of the original fpcsr register.
*
* NOMANUAL

* ULONG fppClearFloat ()
 
*/
	.ent	fppClearFloat
FUNC_LABEL(fppClearFloat)
#ifndef SOFT_FLOAT
	cfc1	v0, C1_SR		/* read control/status reg	*/
	HAZARD_CP_READ
	and	a0, v0, ~FP_EXC_MASK	/* zero bits		*/
	ctc1	a0, C1_SR		/* clear interrupt		*/
	HAZARD_CP_WRITE
#endif	/* !SOFT_FLOAT */
	j	ra			/* return to caller		*/
	.end	fppClearFloat

/*******************************************************************************
*
* fppArgsToRegs - place floating-point arguments into FPA registers
*
* This routine reads two double-precision floating-point values from memory and
* places them in the parameter passing registers of the MIPS R-Series
* floating-point unit.
*
* RETURNS: N/A
*
* NOMANUAL

* void fppArgsToRegs (dblPtr)
*    double *dblPtr;
 
*/
	.ent	fppArgsToRegs
FUNC_LABEL(fppArgsToRegs)
#ifndef SOFT_FLOAT
#if (_WRS_FP_REGISTER_SIZE == 4)
	/* R3000, or R4000 in 32-bit f.p. compatibility mode */
	LWC1	fp12,(0*_WRS_FP_REGISTER_SIZE)(a0)
	LWC1	fp13,(1*_WRS_FP_REGISTER_SIZE)(a0)
	LWC1	fp14,(2*_WRS_FP_REGISTER_SIZE)(a0)
	LWC1	fp15,(3*_WRS_FP_REGISTER_SIZE)(a0)
#elif (_WRS_FP_REGISTER_SIZE == 8)
	/* R4000 in native 64-bit floating point mode */
	LWC1	fp12,(0*_WRS_FP_REGISTER_SIZE)(a0)
	LWC1	fp14,(1*_WRS_FP_REGISTER_SIZE)(a0)
#else /* _WRS_FP_REGISTER_SIZE */
#error "invalid _WRS_FP_REGISTER_SIZE value"
#endif /* _WRS_FP_REGISTER_SIZE */
#endif	/* !SOFT_FLOAT */
	j	ra			/* return to caller		*/
	.end	fppArgsToRegs

/*******************************************************************************
*
* fppEmulateBranch - calculates the result of a MIPS jump or branch instruction
*
* This routine calculates the resulting EPC when an exception/interrupt
* occurs in the branch delay slot.
*
* RETURNS: The address of the branch target.
*
* SEE ALSO:
* .I "MIPS RISC Architecture"
*
* NOMANUAL

* STATUS fppEmulateBranch (pEsf,brInstr,fpcsr)
*     ESFMIPS *pEsf;     /* pointer to exception stack frame *
*     ULONG   brInstr,  /* branch instruction to emulate    *
* 	      fpcsr;    /* fp control/status register       *

*/

	.ent	fppEmulateBranch
FUNC_LABEL(fppEmulateBranch)
#ifndef SOFT_FLOAT

	/* unconditional immediates are easy, 
	   so they go first (jal, j) */

	and	t0, a1, GENERAL_OPCODE_MASK	/* look at opcode field */

	li	t3, J_INSTR			/* load temp j value */
	bne	t0, t3, 1f			/* am I jump always */
	and	a1, TARGET_MASK			/* grab 26 bit target */
	sll	a1, 2				/* shift to word bounds */
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	

	addiu	t1, t1, 4			/* calculate BD slot addr */
	and	t2, t1, ~TARGET_MASK		/* grab upper 4 pc bits */
	or	v0, a1, t2			/* combine TARGET with pc top 
						   4 bits, return value */
	j	ra				/* return	*/

1:	and	t0, a1, GENERAL_OPCODE_MASK	/* look at opcode field */
	li	t3, JAL_INSTR			/* load temp jal value */
	bne	t0, t3, 2f			/* am I jump and link */

	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addu	t2, t1, 8			/* increment epc for ra */
	sw	t2, E_STK_RA(a0)		/* replace ra	*/
	and	a1, TARGET_MASK			/* grab 26 bit target */
	sll	a1, 2				/* shift to word bounds */
	addiu	t1, t1, 4			/* calculate BD slot addr */
	and	t2, t1, ~TARGET_MASK		/* grab upper 4 pc bits */
	or	v0, a1, t2			/* combine TARGET with pc top 
						   4 bits, return value */
	j	ra				/* return	*/

2:	bne	t0, zero, 4f			/* are we special opcode */

	/* now for unconditional registers (jr, jalr) */

	and	t0, a1, SPECIAL_MASK		/* look at special field */
	li	t3, JR_INSTR			/* load temp jr value */
	bne	t0, t3, 3f			/* am I jump register */
	srl	a1, (RS_POS - 2)		/* get table register
						   entry, notice word
						   offset (-2)	*/
	lw	t2, regFetchIndexTbl(a1)	/* grab correct instructions */
        move    t7, ra                          /* set return address */
	j	t2				/* excecute the instructions, 
						   return taken care of	*/

3:	and	t0, a1, SPECIAL_MASK		/* look at special field */
	li	t3, JALR_INSTR			/* load temp jalr value */
	bne	t0, t3 , 4f			/* am I jump and 
						   link register */
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addu	t2, t1, 8			/* increment epc for ra */
	sw	t2, E_STK_RA(a0)		/* replace ra	*/
	srl	a1, RS_POS - 2			/* get table register
						   entry, notice word
						   offset (-2)	*/
	lw	t2, regFetchIndexTbl(a1)	/* grab correct instructions */
        move    t7, ra                          /* set return address */
	j	t2				/* excecute the instructions,
						   return taken care of	*/
4:
	/* now for the hard part, branches.  Order of importance seems
	   to be as follows :   beq, bne, blez, bgez, bltz, bgtz,
				bcf, bct, bltzal, bgtzal
           we also check for branch likely instructions
	   exceptions occuring in the branch delay slot of a 
	   branch likely should mean that the branch will be taken
           (otherwise  the instruction shopuld have been nullified)
	   we go through the comparison routines just to be sure
	*/

	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	and	t3, t0, GENERAL_OPCODE_MASK	/* get branch opcode	*/

	beq	t3, BEQ_INSTR, 1f
	bne	t3, BEQL_INSTR, 5f		/* are we beq/beql instr */

1:	and	t2, t0, RS_MASK			/* look at RS only	*/
	srl	t2, (RS_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RS register	*/
	move	t4, v0				/* store value in t4	*/

	and	t2, t0, RT_MASK			/* look at RT only	*/
	srl	t2, (RT_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RT register	*/
	move	t5, v0				/* store value in t5	*/

	bne	t4, t5, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/

5:
	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	and	t3, t0, GENERAL_OPCODE_MASK	/* get branch opcode	*/
	beq	t3, BNE_INSTR,1f
	bne	t3, BNEL_INSTR,6f		/* are we bne/bnel instr */

1:	and	t2, t0, RS_MASK			/* look at RS only	*/
	srl	t2, (RS_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RS register	*/
	move	t4, v0				/* store value in t4	*/

	and	t2, t0, RT_MASK			/* look at RT only	*/
	srl	t2, (RT_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RT register	*/
	move	t5, v0				/* store value in t5	*/

	beq	t4, t5, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/

6:	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	and	t3, t0, GENERAL_OPCODE_MASK	/* get branch opcode	*/
	beq	t3, BLEZ_INSTR,1f
	bne	t3, BLEZL_INSTR,7f		/* are we blez/blezl instr */

1:	and	t2, t0, RS_MASK			/* look at RS only	*/
	srl	t2, (RS_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RS register	*/
	move	t4, v0				/* store value in t4	*/

	bgtz	t4, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/

7:
	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	or	t1, t0, REGIMM			/* turn on REGIMM bits  */
	and	t2, t1, RS_MASK			/* mask RS bits         */
	beq	t2, BGEZ_INSTR, 1f
	bne	t2, BGEZL_INSTR, 8f		/* are we bgez/bgezl instr */

1:	and	t2, t0, RS_MASK			/* look at RS only	*/
	srl	t2, (RS_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RS register	*/
	move	t4, v0				/* store value in t4	*/

	bltz	t4, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/

8:
	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	or	t1, t0, REGIMM			/* turn on REGIMM bits  */
	and	t2, t1, RS_MASK			/* mask RS bits         */
	beq	t2, BLTZ_INSTR, 1f
	bne	t2, BLTZL_INSTR, 9f		/* are we bltz/bltzl instr */

1:	and	t2, t0, RS_MASK			/* look at RS only	*/
	srl	t2, (RS_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RS register	*/
	move	t4, v0				/* store value in t4	*/

	bgez	t4, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/
9:
	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	and	t3, t0, GENERAL_OPCODE_MASK	/* get branch opcode	*/
	beq	t3, BGTZ_INSTR, 1f
	bne	t3, BGTZL_INSTR, 10f		/* are we bgtz/bgtzl instr */

1:	and	t2, t0, RS_MASK			/* look at RS only	*/
	srl	t2, (RS_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RS register	*/
	move	t4, v0				/* store value in t4	*/

	blez	t4, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/

10:
	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	and	t1, t0, ~CC_MASK		/* mask off bits 18-20  */	
	beq     t1, BC1F_INSTR, 1f
	bne	t1, BC1FL_INSTR, 11f		/* are we bc1f/bc1fl instr */

1:	and	t4, a2, CP1_VALUE		/* is fpa true		*/

	bne	zero, t4, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/
11:
	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	and	t1, t0, ~CC_MASK		/* mask off bits 18-20  */
	beq	t1, BC1T_INSTR, 1f
	bne	t1, BC1TL_INSTR, 12f		/* are we bc1t/bc1tl instr	*/

1:	and	t4, a2, CP1_VALUE		/* is fpa true		*/

	beq	zero, t4, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/
12:
	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	or	t1, t0, REGIMM			/* turn on REGIMM bits  */
	and	t2, t1, RS_MASK			/* mask RS bits         */
	beq	t2, BLTZAL_INSTR, 1f
	bne	t2, BLTZALL_INSTR, 13f		/* are we bltzal/bltzall instr */

1:	and	t2, t0, RS_MASK			/* look at RS only	*/
	srl	t2, (RS_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RS register	*/
	move	t4, v0				/* store value in t4	*/

	bgez	t4, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addu	t2, t1, 8			/* increment epc for ra */
	sw	t2, E_STK_RA(a0)		/* replace ra	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/
13:
	and	t0, a1, (OFFSET16_MASK << 16)	/* mask high 16 bits	*/
	or	t1, t0, REGIMM			/* turn on REGIMM bits  */
	and	t2, t1, RS_MASK			/* mask RS bits         */
	beq	t2, BGEZAL_INSTR,1f
	bne	t2, BGEZALL_INSTR,14f		/* are we bgtzal/bgtzall instr */

1:	and	t2, t0, RS_MASK			/* look at RS only	*/
	srl	t2, (RS_POS - 2)
	lw	t2, regFetchIndexTbl(t2)	/* get routine address	*/
	jalr	t7, t2				/* read RS register	*/
	move	t4, v0				/* store value in t4	*/

	bltz	t4, 15f 			/* don't take branch	*/
	and	a1, OFFSET16_MASK		/* look at ls 16 bits	*/
	sll	a1, IMMEDIATE_POS		/* sign extend	*/
	sra	a1, IMMEDIATE_POS - 2
	lw	t1, E_STK_EPC(a0)		/* grab epc	*/
	addu	t2, t1, 8			/* increment epc for ra */
	sw	t2, E_STK_RA(a0)		/* replace ra	*/
	addiu	t1, t1, 4			/* calculate BD slot addr */
	addu	v0, t1, a1			/* calculate new epc */
	j	ra				/* return	*/


#endif	/* !SOFT_FLOAT */
14:	/* it wasn't a branch that we recognised! */
	li	v0, 1				/* give up	*/

15:
	j	ra				/* return to caller	*/
	.end	fppEmulateBranch


/*******************************************************************************
*
* regFetchTable - returns the contents of a given register
*
* This routine has 32 entry points, one for each r3k general purpose
* register.  The user interface is to jal to the register offset of
* regFetchIndexTbl, and expect results in v0.  The return address register
* t7 is uses so we do not have to set up a stack frame.
*
* RETURNS: contents of given register
*
* NOMANUAL - not really a routine but a jump table

*/
	.ent	regFetchTable
regFetchTable:
reg0:
	move	v0, zero
	j	t7
reg1:
	LW	v0,E_STK_AT(a0)
	j	t7
reg2:
	LW	v0,E_STK_V0(a0)
	j	t7
reg3:
	LW	v0,E_STK_V1(a0)
	j	t7
reg4:
	LW	v0,E_STK_A0(a0)
	j	t7
reg5:
	LW	v0,E_STK_A1(a0)
	j	t7
reg6:
	LW	v0,E_STK_A2(a0)
	j	t7
reg7:
	LW	v0,E_STK_A3(a0)
	j	t7
reg8:
	LW	v0,E_STK_T0(a0)
	j	t7
reg9:
	LW	v0,E_STK_T1(a0)
	j	t7
reg10:
	LW	v0,E_STK_T2(a0)
	j	t7
reg11:
	LW	v0,E_STK_T3(a0)
	j	t7
reg12:
	LW	v0,E_STK_T4(a0)
	j	t7
reg13:
	LW	v0,E_STK_T5(a0)
	j	t7
reg14:
	LW	v0,E_STK_T6(a0)
	j	t7
reg15:
	LW	v0,E_STK_T7(a0)
	j	t7
reg16:
	LW	v0,E_STK_S0(a0)
	j	t7
reg17:
	LW	v0,E_STK_S1(a0)
	j	t7
reg18:
	LW	v0,E_STK_S2(a0)
	j	t7
reg19:
	LW	v0,E_STK_S3(a0)
	j	t7
reg20:
	LW	v0,E_STK_S4(a0)
	j	t7
reg21:
	LW	v0,E_STK_S5(a0)
	j	t7
reg22:
	LW	v0,E_STK_S6(a0)
	j	t7
reg23:
	LW	v0,E_STK_S7(a0)
	j	t7
reg24:
	LW	v0,E_STK_T8(a0)
	j	t7
reg25:
	LW	v0,E_STK_T9(a0)
	j	t7
reg26:
	LW	v0,E_STK_K0(a0)
	j	t7
reg27:
	LW	v0,E_STK_K1(a0)
	j	t7
reg28:
	LW	v0,E_STK_GP(a0)
	j	t7
reg29:
	LW	v0,E_STK_SP(a0)
	j	t7
reg30:
	LW	v0,E_STK_FP(a0)
	j	t7
reg31:
	LW	v0,E_STK_RA(a0)
	j	t7
	.end	regFetchTable

/*******************************************************************************
*
* regJumpTable - excecution code for jump instruction execution
*
* This routine contains the local symbols used by regJmpIndexTbl to determine
* what action should be taken by certain MIPS instructions.  This routine is
* not callable by any "C" or assembler routines.
*
* RETURNS: N/A
*
* NOMANUAL - not really a routine but a jump table

*/
	.ent	regJumpTable
regJumpTable:
jreg0:
	lw	t1,E_STK_ZERO(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg1:
	lw	t1,E_STK_AT(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg2:
	lw	t1,E_STK_V0(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg3:
	lw	t1,E_STK_V1(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg4:
	lw	t1,E_STK_A0(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg5:
	lw	t1,E_STK_A1(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg6:
	lw	t1,E_STK_A2(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg7:
	lw	t1,E_STK_A3(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg8:
	lw	t1,E_STK_T0(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg9:
	lw	t1,E_STK_T1(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg10:
	lw	t1,E_STK_T2(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg11:
	lw	t1,E_STK_T3(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg12:
	lw	t1,E_STK_T4(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg13:
	lw	t1,E_STK_T5(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg14:
	lw	t1,E_STK_T6(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg15:
	lw	t1,E_STK_T7(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg16:
	lw	t1,E_STK_S0(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg17:
	lw	t1,E_STK_S1(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg18:
	lw	t1,E_STK_S2(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg19:
	lw	t1,E_STK_S3(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg20:
	lw	t1,E_STK_S4(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg21:
	lw	t1,E_STK_S5(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg22:
	lw	t1,E_STK_S6(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg23:
	lw	t1,E_STK_S7(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg24:
	lw	t1,E_STK_T8(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg25:
	lw	t1,E_STK_T9(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg26:
	lw	t1,E_STK_K0(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg27:
	lw	t1,E_STK_K1(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg28:
	lw	t1,E_STK_GP(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg29:
	lw	t1,E_STK_SP(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg30:
	lw	t1,E_STK_FP(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
jreg31:
	lw	t1,E_STK_RA(a0)
	sw	t1,E_STK_EPC(a0)
	j	ra
	.end	regJumpTable

	.data
	.align	4
regJmpIndexTbl:
	.word	jreg0
	.word	jreg1
	.word	jreg2
	.word	jreg3
	.word	jreg4
	.word	jreg5
	.word	jreg6
	.word	jreg7
	.word	jreg8
	.word	jreg9
	.word	jreg10
	.word	jreg11
	.word	jreg12
	.word	jreg13
	.word	jreg14
	.word	jreg15
	.word	jreg16
	.word	jreg17
	.word	jreg18
	.word	jreg19
	.word	jreg20
	.word	jreg21
	.word	jreg22
	.word	jreg23
	.word	jreg24
	.word	jreg25
	.word	jreg26
	.word	jreg27
	.word	jreg28
	.word	jreg29
	.word	jreg30
	.word	jreg31

	.data
	.align	4
regFetchIndexTbl:
	.word	reg0
	.word	reg1
	.word	reg2
	.word	reg3
	.word	reg4
	.word	reg5
	.word	reg6
	.word	reg7
	.word	reg8
	.word	reg9
	.word	reg10
	.word	reg11
	.word	reg12
	.word	reg13
	.word	reg14
	.word	reg15
	.word	reg16
	.word	reg17
	.word	reg18
	.word	reg19
	.word	reg20
	.word	reg21
	.word	reg22
	.word	reg23
	.word	reg24
	.word	reg25
	.word	reg26
	.word	reg27
	.word	reg28
	.word	reg29
	.word	reg30
	.word	reg31
