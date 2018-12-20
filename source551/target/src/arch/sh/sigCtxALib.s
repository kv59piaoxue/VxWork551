/* sigCtxALib.s - software signal architecture support library */

/* Copyright 1994-2000 Wind River Systems, Inc. */

	.data
	.global	_copyright_wind_river
	.long	_copyright_wind_river

/*
modification history
--------------------
01v,31aug00,hk   lock interrupts in _sigCtxLoad before jumping to dispatch stub
		 (SH7750/SH7700). minor pipeline optimization(SH7600/SH7000).
01u,21aug00,hk   merge SH7729 to SH7700, merge SH7410 and SH7040 to SH7600.
01t,10apr00,hk   got rid of .ptext section: changed _sigCtxLoad to jump at
                 VBR-relative dispatchStub in P1/P2.
01s,28mar00,hk   added .type directive to function names.
01r,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01q,08jun99,zl   added .ptext attribute "ax"
01p,16jul98,st   added SH7750 support.
01o,08may98,jmc  added support for SH-DSP and SH3-DSP.
01n,25apr97,hk   changed SH704X to SH7040.
01m,03mar97,hk   fixed comment for bank-1 register usage in _sigCtxLoad.
01l,16dec96,wt   moved __sigCtxLoad to .ptext section. fixed this to be called
           +hk   on bank-0. changed not to touch logical memory after blocking.
01k,01oct96,hk   rewrote __sigCtxLoad to minimize interrupt blocking section.
01j,01oct96,hk   changed __sigCtxLoad to set BL=1 before restoring spc/ssr.
01i,26sep96,hk   fixed [SPR: #H1005] bug in inlined intLock() for SH7700.
01h,02sep96,hk   code review, made sigCtxLoad more robust for SH7700.
01g,05aug96,hk   removed unnecessary register saving in __sigCtxSave. tried
		 to skip loading in __sigCtxLoad but it was necessary (#if 1).
		 added rte delayed slot optimization in __sigCtxLoad for SH7700.
01f,05aug96,hk   fixed intLock code in __sigCtxLoad for SH7700.
01e,04aug96,hk   added support for SH7700.
01d,15mar95,hk   initial functional version.
01c,08mar95,hk   writing body.
01b,28feb95,hk   adding APK comments, copyright year 1995.
01a,08oct94,hk   written based on sparc 01i.
*/

/*
This library provides the architecture specific support needed by
software signals for SH.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"
#include "arch/sh/ivSh.h"
#include "arch/sh/regsSh.h"
#include "esf.h"
#include "iv.h"


#if (CPU==SH7750 || CPU==SH7700)
#if (SH7700_DISPATCH_STUB_OFFSET > 0x7f)
#error SH7700_DISPATCH_STUB_OFFSET > 0x7f, check ivSh.h and adjust _sigCtxLoad.
#else
#define DISPATCH_STUB	SH7700_DISPATCH_STUB_OFFSET
#endif
#endif /* CPU==SH7750 || CPU==SH7700 */


	/* globals */

	.global	__sigCtxLoad
	.global	__sigCtxSave
	.global	_setjmp
        .global _sigsetjmp

	.text

/*******************************************************************************
*
* setjmp - set non-local goto
*
* This routine saves the current task context and program counter in <env>
* for later use by longjmp().   It returns 0 when called.  However, when
* program execution returns to the point at which setjmp() was called and the
* task context is restored by longjmp(), setjmp() will then return the value
* <val>, as specified in longjmp().
*
* RETURNS: 0 or <val> if return is via longjmp().
*
* SEE ALSO: longjmp()

* int setjmp
*    (
*    jmp_buf env        /@ where to save stack environment @/
*    )

* [APK]
* This routine is _sigCtxSave() with a call to __setjmpSetup() first. The input
* argument jmp_buf is passed with the second argument of 1 to __setjmpSetup().
* jmp_buf is identical to the REG_SET pointer argument in _sigCtxSave().
*/
	.align	_ALIGN_TEXT
	.type	_setjmp,@function

_setjmp:					/* r4 -> jmp_buf env    */
	mov	#1,r5				/* __setjmpSet (env, 1) */

	/* FALL THROUGH */

/*******************************************************************************
*
* sigsetjmp - set non-local goto with option to save signal mask
*
* This routine saves the current task context and program counter in <env>
* for later use by siglongjmp().   It returns 0 when called.  However, when
* program execution returns to the point at which sigsetjmp() was called and the
* task context is restored by siglongjmp(), sigsetjmp() will then return the
* value <val>, as specified in siglongjmp().
*
* If the value of <savemask> argument is not zero, the sigsetjmp() function
* shall save the current signal mask of the task as part of the calling
* environment.
*
* RETURNS: 0 or <val> if return is via siglongjmp().
*
* SEE ALSO: longjmp()

* int sigsetjmp
*     (
*     jmp_buf env,       /@ where to save stack environment @/
*     int     savemask	 /@ whether or not to save the current signal mask @/
*     )

* [APK]
* This routine is _sigCtxSave() with a call to __setjmpSetup() first. The input
* argument jmp_buf is passed with the signal mask as the second argument to
* __setjmpSetup().  jmp_buf is identical to the REG_SET pointer argument in
* _sigCtxSave().
*/
	.type	_sigsetjmp,@function

_sigsetjmp:
	mov.l	SetjmpSetup,r0
	mov.l	r4,@-sp				/* push jmp_buf pointer */
	sts.l	pr,@-sp
	jsr	@r0		/* __setjmpSetup (jmp_buf env, int savemask) */
	nop
	lds.l	@sp+,pr
	mov.l	@sp+,r4				/* pop jmp_buf pointer */

	/* FALL THROUGH */

/*******************************************************************************
*
* _sigCtxSave - Save the current context of the current task
*
* This is just like setjmp except it doesn't worry about saving any sigmask.
* It must also always return 0.
*
* RETURNS: 0

* int _sigCtxSave
*     (
*     REG_SET *pRegs		/@ Location to save current context @/
*     )

* [APK]
* This assembly language routine is similar to the code in windExit() that
* moves the registers to the task's TCB.  The REG_SET passed as the argument
* to this routine is loaded from the processor registers.  It is also similar
* in functionality to setjmp().
*
* INTERNAL
*
* _sigPendRun:
*	mov.l   r8,@-r15					_________
*	mov.l   r9,@-r15					|_______| +100
*	sts.l   pr,@-r15				JMP_DATA|_______| +96
*	add     #-124,r15					|_______| +92
*	  :							|  sr	| +88
*	mov.l   @(56,pc),r0 (= __sigCtxSave)			|pc(=pr)| +84
*	jsr     @r0					    +----- r15	| +80
*      (mov     r8,r4) ---------+		 <STACK>    |	|  r14	| +76
*	tst	r0,r0		|		|	|   |	|  r13	| +72
*	  :			|		|  r8	|   |	|  r12	| +68
*	add     #124,r15	|		|  r9	|   |	|  r11	| +64
*	lds.l   @r15+,pr	|	   sp->	|  pr	|   |	|  r10	| +60
*	mov.l   @r15+,r9	|	    :	|	|   |	|  r9	| +56
*	rts			|	    :	|	|   |	|  r8	| +52
*      (mov.l   @r15+,r8)	|	    :	|	|   |	|  macl	| +48
*				|	    v	|	|   |	|  mach	| +44
*				|	   sp->	|	|<--+	|  r7	| +40
*				|		|	|	|  r6	| +36
*				|		|	|	|  r5	| +32
*				|		0		|  r4	| +28
*				|				|  r3	| +24
*				|				|  r2	| +20
*				|				|  r1	| +16
*				|				|  r0	| +12
*				|				|  pr	| +8
*				|				|  gbr	| +4
*				+--------------	r4 --->	REG_SET	|  vbr	| 0
*								+-------+
*								<jmp_buf>
*
* <setjmp.h>  typedef int jmp_buf [(sizeof (REG_SET) / sizeof (int)) + 3];
*/
	.type	__sigCtxSave,@function

__sigCtxSave:
	add	#92, r4
	stc.l	sr,  @-r4			/* save sr                   */
	sts.l	pr,  @-r4			/* save return address as PC */
	mov.l	sp,  @-r4			/* save r15		     */
	mov.l	r14, @-r4			/* save r14		     */
	mov.l	r13, @-r4			/* save r13		     */
	mov.l	r12, @-r4			/* save r12		     */
	mov.l	r11, @-r4			/* save r11		     */
	mov.l	r10, @-r4			/* save r10		     */
	mov.l	r9,  @-r4			/* save r9		     */
	mov.l	r8,  @-r4			/* save r8		     */
#if 0
	sts.l	macl,@-r4			/* volatile, not necessary */
	sts.l	mach,@-r4
	mov.l	r7,  @-r4
	mov.l	r6,  @-r4
	mov.l	r5,  @-r4
	mov.l	r4,  @-r4
	mov.l	r3,  @-r4
	mov.l	r2,  @-r4
	mov.l	r1,  @-r4
	mov.l	r0,  @-r4
	sts.l	pr,  @-r4
	stc.l	gbr, @-r4
	stc.l	vbr, @-r4
#endif
	rts;
	xor	r0,  r0				/* must return zero */

		.align	2
SetjmpSetup:	.long	__setjmpSetup


#if (CPU==SH7750 || CPU==SH7700)
/*******************************************************************************
*
* _sigCtxLoad - Load a new context in the current task (SH7750/SH7700)
*
* This is just like longjmp, but every register must be loaded.
* You could also look at this as half a context switch.
*
* RETURNS: Never returns

* void _sigCtxLoad
*     (
*     REG_SET *pRegs		/@ Context to load @/
*     )

* [APK]
* This assembly language routine mimics windLoadContext() and setjmp().
* The REG_SET passed as the argument to this routine is loaded into the
* registers and the signal handler started.
*
* NOTE:  Only called from longjmp() or sigreturn().
*
* INTERNAL
*			_________
*			|_______|
*		JMP_DATA|_______|
*			|_______|
*		    +88	|  sr	| --> ssr
*		    +84	|pc(=pr)| --> spc
*		    +80	|  r15	| --> sp
*		    +76	|  r14	|
*		    +72	|  r13	|
*		    +68	|  r12	|
*		    +64	|  r11	|
*		    +60	|  r10	|
*		    +56	|  r9	|
*		    +52	|  r8	|
*		    +48	|  macl	|
*		    +44	|  mach	|
*		    +40	|  r7	|
*		    +36	|  r6	|
*		    +32	|  r5	|
*		    +28	|  r4	|
*		    +24	|  r3	|
*		    +20	|  r2	|
*		    +16	|  r1	|
*		    +12	|  r0	|
*		     +8	|  pr	|
*		     +4	|  gbr	|
*	r4 --->	REG_SET	|  vbr	|
*			+-------+
*			<jmp_buf>
*
*  [usage of bank-1 registers]
*
*    r0, r1, r2, r3, r4, r5, r6, r7: used by excStub.
*    r0, r1, r2, r3:                 used by intStub.
*    r0, r1, r2, r3:                 used by mmuStub.
*/
	.align	_ALIGN_TEXT
	.type	__sigCtxLoad,@function
				/* MD=1, RB=0, BL=0, IM=? */
__sigCtxLoad:
	mov	r4,r14		/* copy jmp_buf pointer to r14 */
	add	#8,r14		/* skip vbr/gbr */
	lds.l	@r14+,pr
	mov.l	@r14+,r0
	mov.l	@r14+,r1
	mov.l	@r14+,r2
	mov.l	@r14+,r3
	mov.l	@r14+,r4
	mov.l	@r14+,r5
	mov.l	@r14+,r6
	mov.l	@r14+,r7
	lds.l	@r14+,mach
	lds.l	@r14+,macl
	mov.l	@r14+,r8
	mov.l	@r14+,r9;		mov.l	IntLockSR,r12
	stc	vbr,r11;		mov.l	@r12,r12
	add	#DISPATCH_STUB,r11;	ldc	r12,sr	/* LOCK INTERRUPTS */
	jmp	@r11;
	mov.l	@r14+,r10

		.align	2
IntLockSR:	.long	_intLockTaskSR

#elif (CPU==SH7600 || CPU==SH7000)
/*******************************************************************************
*
* _sigCtxLoad - Load a new context in the current task (SH7600/SH7000)
*
* This is just like longjmp, but every register must be loaded.
* You could also look at this as half a context switch.
*
* RETURNS: Never returns

* void _sigCtxLoad
*     (
*     REG_SET *pRegs		/@ Context to load @/
*     )

* [APK]
* This assembly language routine mimics windLoadContext() and setjmp().
* The REG_SET passed as the argument to this routine is loaded into the
* registers and the signal handler started.
*
* NOTE:  Only called from longjmp() or sigreturn().
*
* INTERNAL
*			_________
*			|_______|		 <STACK>
*		JMP_DATA|_______|		|	|
*			|_______|	+- r1 ->|	|
*		    +88	|  sr	|	|	|  sr	|
*		    +84	|pc(=pr)|	|	|  pc	|<- sp, then rte.
*		    +80	|  r15 ---------+	|	|
*		    +76	|  r14	|
*		    +72	|  r13	|
*		    +68	|  r12	|
*		    +64	|  r11	|
*		    +60	|  r10	|
*		    +56	|  r9	|
*		    +52	|  r8	|
*		    +48	|  macl	|
*		    +44	|  mach	|
*		    +40	|  r7	|
*		    +36	|  r6	|
*		    +32	|  r5	|
*		    +28	|  r4	|
*		    +24	|  r3	|
*		    +20	|  r2	|
*		    +16	|  r1	|
*		    +12	|  r0	|
*		     +8	|  pr	|
*		     +4	|  gbr	|
*	r4 --->	REG_SET	|  vbr	|
*			+-------+
*			<jmp_buf>
*/
	.align	_ALIGN_TEXT
	.type	__sigCtxLoad,@function

__sigCtxLoad:
	/* r14 -> jmp_buf */
	mov	r4, r14;	add	#80, r4	/* r4 -> r15 in jmp_buf */
				mov.l	@r4+,r1	/* get new sp */
				mov.l	@r4+,r2	/* get new pc */
	/* skip vbr/gbr */	mov.l	@r4, r3	/* get new sr */
	add	#8,r14;		mov.l	r3,@-r1	/* push sr(dummy excep. frame)*/
				mov.l	r2,@-r1	/* push pc(dummy excep. frame)*/
				mov.l	r1,@-sp	/* save new sp to old stack */
	/* load register set */
	lds.l	@r14+,pr
	mov.l	@r14+,r0
	mov.l	@r14+,r1
	mov.l	@r14+,r2
	mov.l	@r14+,r3
	mov.l	@r14+,r4
	mov.l	@r14+,r5
	mov.l	@r14+,r6
	mov.l	@r14+,r7
	lds.l	@r14+,mach
	lds.l	@r14+,macl
	mov.l	@r14+,r8
	mov.l	@r14+,r9
	mov.l	@r14+,r10
	mov.l	@r14+,r11
	mov.l	@r14+,r12
	mov.l	@r14+,r13
	mov.l	@r14,r14
	mov.l	@sp,sp			/* load new sp from old stack	*/
	rte				/* enter new task's context	*/
	nop

#endif /* CPU==SH7600 || CPU==SH7000 */
