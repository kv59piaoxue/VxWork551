/* speALib.s  - SPE assembly routines */

/* Copyright 2000 - 2003 Wind River, Inc */

/*
modification history
--------------------
01a,02sep02,dtr  created.
*/

/* includes */

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "arch/ppc/spePpcLib.h"

         /* globals */
        FUNC_EXPORT(speSave)
        FUNC_EXPORT(speRestore)

        _WRS_TEXT_SEG_START

/**********************************************************************
 *   speRestore - restores from memory values back into upper 32 bits 
 *                of the general purpose registers. It requires specific
 *		  SP APU instructions to do this so enables the SPE bit in
 *		  MSR. It also restores the accumulator.
 */

	
speRestore:	
	mfmsr  r4                       
        mr     r5, r4                  
        oris   r5, r5, %hi(_PPC_MSR_SPE)     /* Set SPE Bit so SPE instructions 
						don't cause exception */
        sync                       
        mtmsr  r5                       
        sync
	evldd r5,SPE_OFFSET(32)(r3)  /* Offset 32 words into structure for 
					the accumulator */
	evmra r5,r5	/* r5 corrupted so done before restore of r5 */

	mr  r5,r3	/* Move ptr to spe register structure into r5 */
	evmergelohi r3,r3,r3         /* Swap upper and lower words around */
	lwz r3,SPE_OFFSET(3)(r5)     /* Load lower word (was upper) to 
					offset for r3 */
	evmergelohi r3,r3,r3	     /* Swap r3 back with upper bits now new
					context value. Lower bits restored*/
	evmergelohi r4,r4,r4         /* Move lower word to upper word to 
					retain lower word */   
	lwz r4,SPE_OFFSET(4)(r3)     /* Load upper word into lower word and 
					swap  */
	evmergelohi r4,r4,r4	     /* move new context value into upper 
					word and restore lower */ 
	
	/* General approach is to swap upper and lower words
	   Load into lower word from SPE context.
	   Swap upper and lower to restore upper word and retain lower 
	   word value */
	/* Load instructions are done together to make full use of cache */
		
	evmergelohi r0,r0,r0
	evmergelohi r1,r1,r1
	evmergelohi r2,r2,r2
	evmergelohi r5,r5,r5
	evmergelohi r6,r6,r6
	evmergelohi r7,r7,r7
	evmergelohi r8,r8,r8
	evmergelohi r9,r9,r9
	evmergelohi r10,r10,r10
	evmergelohi r11,r11,r11
	evmergelohi r12,r12,r12
	evmergelohi r13,r13,r13
	evmergelohi r14,r14,r14
	evmergelohi r15,r15,r15
	evmergelohi r16,r16,r16
	evmergelohi r17,r17,r17
	evmergelohi r18,r18,r18
	evmergelohi r19,r19,r19
	evmergelohi r20,r20,r20
	evmergelohi r21,r21,r21
	evmergelohi r22,r22,r22
	evmergelohi r23,r23,r23
	evmergelohi r24,r24,r24
	evmergelohi r25,r25,r25
	evmergelohi r26,r26,r26
	evmergelohi r27,r27,r27
	evmergelohi r28,r28,r28
	evmergelohi r29,r29,r29
	evmergelohi r30,r30,r30
	evmergelohi r31,r31,r31
	lwz r0,SPE_OFFSET(0)(r3)
	lwz r1,SPE_OFFSET(1)(r3)
	lwz r2,SPE_OFFSET(2)(r3)
	lwz r5,SPE_OFFSET(5)(r3)
	lwz r6,SPE_OFFSET(6)(r3)
	lwz r7,SPE_OFFSET(7)(r3)
	lwz r8,SPE_OFFSET(8)(r3)
	lwz r9,SPE_OFFSET(9)(r3)
	lwz r10,SPE_OFFSET(10)(r3)
	lwz r11,SPE_OFFSET(11)(r3)
	lwz r12,SPE_OFFSET(12)(r3)
	lwz r13,SPE_OFFSET(13)(r3)
	lwz r14,SPE_OFFSET(14)(r3)
	lwz r15,SPE_OFFSET(15)(r3)
	lwz r16,SPE_OFFSET(16)(r3)
	lwz r17,SPE_OFFSET(17)(r3)
	lwz r18,SPE_OFFSET(18)(r3)
	lwz r19,SPE_OFFSET(19)(r3)
	lwz r20,SPE_OFFSET(20)(r3)
	lwz r21,SPE_OFFSET(21)(r3)
	lwz r22,SPE_OFFSET(22)(r3)
	lwz r23,SPE_OFFSET(23)(r3)
	lwz r24,SPE_OFFSET(24)(r3)
	lwz r25,SPE_OFFSET(25)(r3)
	lwz r26,SPE_OFFSET(26)(r3)
	lwz r27,SPE_OFFSET(27)(r3)
	lwz r28,SPE_OFFSET(28)(r3)
	lwz r29,SPE_OFFSET(29)(r3)
	lwz r30,SPE_OFFSET(30)(r3)
	lwz r31,SPE_OFFSET(31)(r3)
	evmergelohi r0,r0,r0
	evmergelohi r1,r1,r1
	evmergelohi r2,r2,r2
	evmergelohi r5,r5,r5
	evmergelohi r6,r6,r6
	evmergelohi r7,r7,r7
	evmergelohi r8,r8,r8
	evmergelohi r9,r9,r9
	evmergelohi r10,r10,r10
	evmergelohi r11,r11,r11
	evmergelohi r12,r12,r12
	evmergelohi r13,r13,r13
	evmergelohi r14,r14,r14
	evmergelohi r15,r15,r15
	evmergelohi r16,r16,r16
	evmergelohi r17,r17,r17
	evmergelohi r18,r18,r18
	evmergelohi r19,r19,r19
	evmergelohi r20,r20,r20
	evmergelohi r21,r21,r21
	evmergelohi r22,r22,r22
	evmergelohi r23,r23,r23
	evmergelohi r24,r24,r24
	evmergelohi r25,r25,r25
	evmergelohi r26,r26,r26
	evmergelohi r27,r27,r27
	evmergelohi r28,r28,r28
	evmergelohi r29,r29,r29
	evmergelohi r30,r30,r30
	evmergelohi r31,r31,r31
        mtmsr  r4                       
        sync
	blr

/**********************************************************************
 *   speSave -    Saves the upper 32 bits of the general purpose registers. 
 *	  	  It requires specific SP APU instructions to do this so 
 *                enables the SPE bit in MSR. It also saves the 
 *		  accumulator.
 */
	
speSave:	
	mfmsr  r4                       
        mr     r5, r4                  
        oris   r5,r5,%hi(_PPC_MSR_SPE)	/* Set SPE Bit so SPE instructions 
					   don't cause exception */  
        sync                       
        mtmsr  r5               
        sync
	evstwwe r0,SPE_OFFSET(0)(r3)	/* Store Upper word into context 
					   offset for r0  */
	evstwwe r1,SPE_OFFSET(1)(r3)
	evstwwe r2,SPE_OFFSET(2)(r3)
	evstwwe r3,SPE_OFFSET(3)(r3)
	evstwwe r4,SPE_OFFSET(4)(r3)
	evstwwe r5,SPE_OFFSET(5)(r3)
	evstwwe r6,SPE_OFFSET(6)(r3)
	evstwwe r7,SPE_OFFSET(7)(r3)
	evstwwe r8,SPE_OFFSET(8)(r3)
	evstwwe r9,SPE_OFFSET(9)(r3)
	evstwwe r10,SPE_OFFSET(10)(r3)
	evstwwe r11,SPE_OFFSET(11)(r3)
	evstwwe r12,SPE_OFFSET(12)(r3)
	evstwwe r13,SPE_OFFSET(13)(r3)
	evstwwe r14,SPE_OFFSET(14)(r3)
	evstwwe r15,SPE_OFFSET(15)(r3)
	evstwwe r16,SPE_OFFSET(16)(r3)
	evstwwe r17,SPE_OFFSET(17)(r3)
	evstwwe r18,SPE_OFFSET(18)(r3)
	evstwwe r19,SPE_OFFSET(19)(r3)
	evstwwe r20,SPE_OFFSET(20)(r3)
	evstwwe r21,SPE_OFFSET(21)(r3)
	evstwwe r22,SPE_OFFSET(22)(r3)
	evstwwe r23,SPE_OFFSET(23)(r3)
	evstwwe r24,SPE_OFFSET(24)(r3)
	evstwwe r25,SPE_OFFSET(25)(r3)
	evstwwe r26,SPE_OFFSET(26)(r3)
	evstwwe r27,SPE_OFFSET(27)(r3)
	evstwwe r28,SPE_OFFSET(28)(r3)
	evstwwe r29,SPE_OFFSET(29)(r3)
	evstwwe r30,SPE_OFFSET(30)(r3)
	evstwwe r31,SPE_OFFSET(31)(r3)
	/* To avoid corruption of r5 this is done at the end */
	evxor r5, r5, r5 
	evmwumiaa r5, r5, r5
	evstdd  r5,SPE_OFFSET(32)(r3) /* Offset 32 words into structure for acc */
        mtmsr  r4                       
        sync
	
	blr


