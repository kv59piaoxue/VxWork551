/* mathHardALib - C callable math routines for the MIPS R3010 */

/* Copyright 1984-2001 Wind River Systems, Inc. */
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
02a,16jan02,agf  add warning about incorrect ceil & floor logic
01z,02aug01,mem  Diab integration
01y,16jul01,ros  add CofE comment
01x,25apr01,mem  Disable optimized FP routines.
01w,19apr01,roz  remove math functions now in c lib
01v,06feb01,roz  removed pow and other incorrect functions for mips
01u,28dec00,agf  Architecture update for MIPS32/64
01t,14jul00,dra  don't use pow for vr5400
01s,10sep99,myz  added CW4000_16 support.
01r,19jan99,dra  added CW4000, CW4011, VR4100, VR5000 and VR5400 support.
01q,20jan97,tam	 fixed more functions in order to handle non finite arguments 
		 (Nan, +/-Inf) and arguments out of the function domain 
		 correctly (spr #7784).
01p,30dec96,tam	 fixed log10, logf and log10f so that it returns Nan or -Inf 
		 instead of generating an exception (spr #6511).
		 fixed isNaNSingle().
01o,05dec96,tam	 reworked single precision support: 
		   -made all single precision routines use only single
		    precision floating point instructions.
		   -re-wrote expf routine.
		   -added powf, fabsf and fmodf routines.
01n,16nov95,mem  converted code to work with gas.
01m,12nov94,dvs  fixed clearcase conversion search/replace errors.
01l,19oct93,cd   added R4000 support.
01k,03aug93,yao  document cleanup.  fixed pow () to return correct value when 
		 dblX is <= 0 (SPR#2447).
01j,20jul93,yao  SPR#2047 - fixed pow () function.  added nop instruction
		 for the instruction pipeline constraints.  updated copyright 
		 notice.
01i,19sep92,kdl	 changed name to mathHardALib; changed mathHardInit() to
		 mathHardALibInit().
01i,30jul92,kdl	 changed to ANSI single precision names (e.g. fsin -> sinf);
		 changed mathInit() to mathHardInit().
01h,06jun92,ajm  5.0.5 merge, note mod history changes, rid single quotes for
		  make problems, also fixed if/else comments
01g,26may92,rrr  the tree shuffle
01f,06jan92,ajm	  fixed sqrt bug with MIPS_ARCH and denorm_sqrt
01e,31oct91,ajm	  added pow function
01d,04oct91,rrr  passed through the ansification filter
                  -fixed #else and #endif
                  -changed VOID to void
                  -changed ASMLANGUAGE to _ASMLANGUAGE
                  -changed copyright notice
01c,29aug91,wmd	  moved to r3k/math directory.
01b,16jul91,ajm   added fabs routine
01a,30apr91,ajm   merged from mips source
*/

/*
DESCRIPTION
This library provides a C interface to the high level math functions
on the MIPS R3010 floating point coprocessor.  Each routine has the following
format:

 . calculate fp function using double parameter 
 . transfer result to parameter storage

WARNING
This library only works if there is a MIPS R3010 coprocessor in the system!
Attempts to use these routines with no coprocessor present will result
in illegal instruction traps.

SEE ALSO: fppLib (1)
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

#ifndef	PORTABLE_MATHLIB
/*
 *-------------------------------------------------------------
 *|         RESTRICTED RIGHTS LEGEND                          |
 *| Use, duplication, or disclosure by the Government is      |
 *| subject to restrictions as set forth in subparagraph      |
 *| (c)(1)(ii) of the Rights in Technical Data and Computer   |
 *| Software Clause at DFARS 252.227-7013.                    |
 *|         MIPS Computer Systems, Inc.                       |
 *|         928 Arques Avenue                                 |
 *|         Sunnyvale, CA 94086                               |
 *-------------------------------------------------------------
 */
/* --------------------------------------------------------- */
/* | Copyright (c) 1986, 1989 MIPS Computer Systems, Inc.  | */
/* | All Rights Reserved.                                  | */
/* --------------------------------------------------------- */
/* Algorithm from Cody and Waite. */

/* asincos.s */

#define ACS_eps       3.72529029846191406250e-9
#define ACS_p5       -0.69674573447350646411e+0
#define ACS_p4       +0.10152522233806463645e+2
#define ACS_p3       -0.39688862997504877339e+2
#define ACS_p2       +0.57208227877891731407e+2
#define ACS_p1       -0.27368494524164255994e+2
#define ACS_q4       -0.23823859153670238830e+2
#define ACS_q3       +0.15095270841030604719e+3
#define ACS_q2       -0.38186303361750149284e+3
#define ACS_q1       +0.41714430248260412556e+3
#define ACS_q0       -0.16421096714498560795e+3
#define ACS_pio2      1.57079632679489661923
#define ACS_pi        3.14159265358979323846
#define one           1.0
#define two    	      2.0
#define half          0.5

/* atan.s */

#define ATAN_r7_16	0.4375 
#define ATAN_r11_16  	0.6875 
#define ATAN_r19_16	1.1875
#define ATAN_r39_16	2.4375 
#define ATAN_athfhi   	4.6364760900080609352E-1
#define ATAN_athflo   	4.6249969567426939759E-18
#define ATAN_PIo4     	7.8539816339744827900E-1
#define ATAN_at1fhi   	9.8279372324732905408E-1
#define ATAN_at1flo  	-2.4407677060164810007E-17
#define ATAN_p11      	1.6438029044759730479E-2
#define ATAN_p10     	-3.6700606902093604877E-2
#define ATAN_p9       	4.9850617156082015213E-2
#define ATAN_p8      	-5.8358371008508623523E-2
#define ATAN_p7       	6.6614695906082474486E-2
#define ATAN_p6      	-7.6919217767468239799E-2
#define ATAN_p5       	9.0908906105474668324E-2
#define ATAN_p4      	-1.1111110579344973814E-1
#define ATAN_p3       	1.4285714278004377209E-1
#define ATAN_p2      	-1.9999999999979536924E-1
#define ATAN_p1       	3.3333333333333942106E-1
#define ATAN_PI      	3.1415926535897931160E0
#define ATAN_PIo2    	1.5707963267948965580E0

/* asincosf.s */

#define  FACS_eps   3.72529029846191406250e-9
#define  FACS_p2   -0.504400557e+0
#define  FACS_p1   +0.933935835e+0
#define  FACS_q1   -0.554846723e+1
#define  FACS_q0   +0.560363004e+1
#define  FACS_pio2  1.57079632679489661923
#define  FACS_pi    3.14159265358979323846

/* atanf.s */

#define  FAT_mpio2   -1.57079632679489661923
#define  FAT_pio6     0.52359877559829887308
#define  FAT_p1      -0.5090958253e-1
#define  FAT_p0      -0.4708325141e+0
#define  FAT_q0       0.1412500740e+1
#define  FAT_twomr3   0.26794919243112270647
#define  FAT_sqrt3    1.73205080756887729353
#define  FAT_sqrt3m1  0.73205080756887729353
#define  FAT_pi       3.14159265358979323846

/* logf.s */

#define  FLOG_p0    -0.5527074855e+0
#define  FLOG_q0    -0.6632718214e+1
#define  FLOG_ln2    0.69314718055994530941
#define  FLOG_loge   0.43429448190325182765

/* sincosf.s */

#define	FSNCS_pio2 	 1.57079632679489661923
#define FSNCS_pi 	 3.14159265358979323846
#define FSNCS_ymax	 32000.0
#define FSNCS_oopi	 0.31830988618379067154
#define FSNCS_p4 	 0.2601903036e-5
#define FSNCS_p3	-0.1980741872e-3
#define FSNCS_p2 	 0.8333025139e-2
#define FSNCS_p1	-0.1666665668e+0

/* sinhf.s */

#define  SNF_eps    3.72529029846191406250e-9
#define  SNF_p1    -0.190333399e+0
#define  SNF_p0    -0.713793159e+1
#define  SNF_q0    -0.428277109e+2

/* tanf.s */

#define  TANF_pio4	0.78539816339744830961
#define  TANF_pio2    	1.57079632679489661923132
#define  TANF_ymax    	6433.0
#define  TANF_twoopi  	0.63661977236758134308
#define  TANF_p0       -0.958017723e-1
#define  TANF_q1      	0.971685835e-2
#define  TANF_q0       -0.429135777e+0

/* tanhf.s */

#define  TNHF_ln3o2    0.54930614433405484570
#define  TNHF_eps      3.72529029846191406250e-9
#define  TNHF_p1      -0.3831010665e-2
#define  TNHF_p0      -0.8237728127e+0
#define  TNHF_q0      +0.2471319654e+1
#define  TNHF_xbig     20.101268236238413961

/* hypot.s */

#define  HYPT_sqrt2  1.4142135623730951455E+00 /* 2^  0 *  1.6A09E667F3BCD */
#define  HYPT_r2p1hi 2.4142135623730949234E+00 /* 2^  1 *  1.3504F333F9DE6 */
#define  HYPT_r2p1lo 1.2537167179050217666E-16 /* 2^-53 *  1.21165F626CDD5 */

/* log.s */

#define  LG_loge    0.43429448190325182765

/* sincos.s */

#define	SNCS_pio2	 1.57079632679489661923
#define SNCS_ymax	 6746518852.0
#define SNCS_oopi	 0.31830988618379067154
#if FALSE
#define	SNCS_pihi	 3.1416015625
#define SNCS_pilo	-8.908910206761537356617e-6
#else	/* FALSE */
#define SNCS_pihi	 3.1415920257568359375
#define SNCS_pilo	 6.2783295730096264338e-7
#endif	/* FALSE */
#define SNCS_p7	 	 0.27204790957888846175e-14
#define SNCS_p6		-0.76429178068910467734e-12
#define SNCS_p5	 	 0.16058936490371589114e-9
#define SNCS_p4		-0.25052106798274584544e-7
#define SNCS_p3	 	 0.27557319210152756119e-5
#define SNCS_p2		-0.19841269841201840457e-3
#define SNCS_p1	 	 0.83333333333331650314e-2
#define SNCS_p0		-0.16666666666666665052e+0

/* sinh.s */

#define  SINH_eps     3.72529029846191406250e-9
#define  SINH_p3     -0.78966127417357099479e+0
#define  SINH_p2     -0.16375798202630751372e+3
#define  SINH_p1     -0.11563521196851768270e+5
#define  SINH_p0     -0.35181283430177117881e+6
#define  SINH_q2     -0.27773523119650701667e+3
#define  SINH_q1     +0.36162723109421836460e+5
#define  SINH_q0     -0.21108770058106271242e+7
#define  SINH_ybar    SINH_expmax
#define  SINH_expmax  709.78271289338397

/* tan.s */

#define TN_pio4	 	 0.78539816339744830961
#define	TN_pio2	 	 1.57079632679489661923
#define TN_ymax	 	 3373259426.0
#define TN_twoopi	 0.63661977236758134308
#define TN_pio2hi	 1.57080078125
#define TN_pio2lo	-4.454455103380768678308e-6
#define TN_p3		-0.17861707342254426711e-4
#define TN_p2	 	 0.34248878235890589960e-2
#define TN_p1		-0.13338350006421960681e+0
#define TN_q4	 	 0.49819433993786512270e-6
#define TN_q3		-0.31181531907010027307e-3
#define TN_q2	 	 0.25663832289440112864e-1
#define TN_q1		-0.46671683339755294240e+0
#define TN_q0	 	 1.0

/* tanh.s */

#define  TNH_ln3o2   0.54930614433405484570
#define  TNH_eps     3.72529029846191406250e-9
#define  TNH_p2     -0.96437492777225469787e+0
#define  TNH_p1     -0.99225929672236083313e+2
#define  TNH_p0     -0.16134119023996228053e+4
#define  TNH_q2     +0.11274474380534949335e+3
#define  TNH_q1     +0.22337720718962312926e+4
#define  TNH_q0     +0.48402357071988688686e+4
#define  TNH_xbig    20.101268236238413961

/* miscallenous */

#ifdef	MIPSEL
#define D(h,l) l,h
#endif	/* MIPSEL */

#ifdef	MIPSEB
#define D(h,l) h,l
#endif	/* MIPSEB */

#define RM_MASK 3

#define INF_HI_SHORT            0x7ff0
#define INF_HI_SHORT_SINGLE     0x7f80


#undef	INCLUDE_DOUBLE_PRECISION
#undef	INCLUDE_SINGLE_PRECISION

	.text
	.set	reorder

/*******************************************************************************
*
* mathHardALibInit - initialize hardware floating point math package
*
* This null routine is provided so the linker will pull in the math library.
* It is called from mathHardInit() in mathHardLib.
*
* WARNING
* This library only works if there is a MIPS R3010 coprocessor in the system!

* void mathHardALibInit ()

* NOMANUAL
*/

	.globl	mathHardALibInit
	.ent	mathHardALibInit
mathHardALibInit:
	j	ra
	.end	mathHardALibInit


#ifdef	INCLUDE_DOUBLE_PRECISION
		
/*******************************************************************************
*
* cabs - complex absolute value
*
* This function returns the absolute value of the double precesion complex 
* number

* double cabs(z)
* struct { double r, i;} z;
* {
* 	double hypot();
* 	return hypot(z.r,z.i);
* }

*/

	.globl 	cabs
	.ent 	cabs
cabs:
	.frame	sp, 0, ra
	dmtc1	$4, $f12
	dmtc1	$6, $f14
	j	hypot
	.end cabs
		
/*******************************************************************************
*
* expm1 - floating point inverse natural logarithm (e ** (x))
*

* INTERNAL
* Algorithm from
*	"Table-driven Implementation of the Exponential Function for
*	IEEE Floating Point", Peter Tang, Argonne National Laboratory,
*	December 3, 1987
*   as implemented in C by M. Mueller, April 20 1988, Evans & Sutherland.
*   Coded in MIPS assembler by Earl Killian.

* double expm1 (dblParam)
*     double dblParam;

*/
	.globl 	expm1
	.ent 	expm1
expm1:
	.frame sp, 0, ra
	/* argument in f12 */
	.set noreorder
	li.d	$f10, 709.78271289338397	/* expmax */
	cfc1	t4, $31				/* read fp control/status */
	c.ole.d	$f12, $f10			/* check if special */
	li.d	$f14, -37.429947750237041	/* -1 threshold */
	bc1f	90f				/* - if NaN, +Infinity, */
						/* or greater than expmax */
	 c.lt.d	$f12, $f14			/* check for expm1(x) = -1 */
	li	t1, -4
	bc1t	80f				/* -if less than -1 threshold */
	 and	t1, t4				/* rounding mode = nearest */
	li.d	$f10, -2.8768207245178096e-01	/* T1 */
	ctc1	t1, $31				/* write fp control/status */
	nop
	c.le.d	$f12, $f10
	li.d	$f14,  2.2314355131420976e-01	/* T2 */
	bc1t	20f
	 c.lt.d	$f12, $f14
	li.d	$f10, 5.5511151231257827e-17
	bc1f	20f
	 abs.d	$f0, $f12
	c.lt.d	$f0, $f10
	li.d	$f10, 2.4360682937111612e-08
	 li.d	$f14, 2.7582184028154369e-07
	bc1t	81f
	nop
	.set reorder
	mul.d	$f0, $f12, $f10
	li.d	$f10, 2.7558212415361945e-06
	add.d	$f0, $f14
	mul.d	$f0, $f12
	li.d	$f14, 2.4801576918453421e-05
	add.d	$f0, $f10
	mul.d	$f0, $f12
	li.d	$f10, 1.9841269447671544e-04
	add.d	$f0, $f14
	mul.d	$f0, $f12
	li.d	$f14, 1.3888888890687830e-03
	add.d	$f0, $f10
	mul.d	$f0, $f12
	li.d	$f10, 8.3333333334012268e-03
	add.d	$f0, $f14
	mul.d	$f0, $f12
	li.d	$f14, 4.1666666666665561e-02
	add.d	$f0, $f10
	mul.d	$f0, $f12
	li.d	$f10, 1.6666666666666632e-01
	add.d	$f0, $f14
	mul.d	$f0, $f12
	add.d	$f0, $f10
	mul.d	$f0, $f12
	mul.d	$f0, $f12
	mul.d	$f0, $f12

	cvt.s.d	$f2, $f12
	cvt.d.s	$f2, $f2
	sub.d	$f4, $f12, $f2
	li.d	$f14, 0.5
	mul.d	$f6, $f2, $f2
	mul.d	$f6, $f14
	add.d	$f8, $f12, $f2
	mul.d	$f8, $f4
	mul.d	$f8, $f14

	li.d	$f10, 0.0078125
	c.lt.d	$f6, $f10
	bc1t	10f

	add.d	$f10, $f2, $f6
	add.d	$f8, $f4
	add.d	$f0, $f8
	add.d	$f0, $f10
	ctc1	t4, $31				/* restore fp control/status */
	j	ra

10:	add.d	$f0, $f8
	add.d	$f0, $f6
	add.d	$f0, $f12
	ctc1	t4, $31				/* restore fp control/status */
	j	ra

20:	li.d	$f10, 4.6166241308446828e+01
	mul.d	$f0, $f12, $f10
	cvt.w.d	$f0, $f0
	mfc1	t0, $f0
	cvt.d.w	$f2, $f0
	li.d	$f4, -2.1660849390173098e-02
	mul.d	$f4, $f2
	add.d	$f4, $f12
	li.d	$f6, -2.3251928468788740e-12
	mul.d	$f6, $f2
	add.d	$f2, $f4, $f6

	li.d	$f10, 1.3888949086377719e-03
	li.d	$f14, 8.3333679843421958e-03
	mul.d	$f0, $f2, $f10
	li.d	$f10, 4.1666666666226079e-02
	add.d	$f0, $f14
	mul.d	$f0, $f2
	li.d	$f14, 1.6666666666526087e-01
	add.d	$f0, $f10
	mul.d	$f0, $f2
	li.d	$f10, 5.0000000000000000e-01
	add.d	$f0, $f14
	mul.d	$f0, $f2
	add.d	$f0, $f10
	mul.d	$f0, $f2
	mul.d	$f0, $f2
	add.d	$f0, $f6
	add.d	$f0, $f4

	and	t1, t0, 31
	sra	t0, 5
	sll	t1, 4
	l.d	$f14, EXP_DAT+0(t1)
	l.d	$f16, EXP_DAT+8(t1)
	add.d	$f8, $f14, $f16
	mul.d	$f0, $f8

	addu	t2, t0, 1023
	sll	t2, 20
	mtc1	t2, $f3
	mtc1	$0, $f2

	bge	t0, 53, 30f
	ble	t0, -7, 40f

	/* -6 <= M <= 52 */
	add.d	$f0, $f16
	li	t1, 1023
	subu	t1, t0
	sll	t1, 20
	mtc1	t1, $f5
	mtc1	$0, $f4
	sub.d	$f6, $f14, $f4
	add.d	$f0, $f6
	mul.d	$f0, $f2
	ctc1	t4, $31				/* restore fp control/status */
	j	ra

30:	/* M >= 53 */
	li	t1, 1023
	subu	t1, t0
	sll	t1, 20
	mtc1	t1, $f5
	mtc1	$0, $f4
	sub.d	$f4, $f16, $f4
	add.d	$f0, $f4
	add.d	$f0, $f14
	mul.d	$f0, $f2
	ctc1	t4, $31				/* restore fp control/status */
	j	ra

40:	/* M <= -7 */
	add.d	$f0, $f16
	add.d	$f0, $f14
	mul.d	$f0, $f2
	li.d	$f10, 1.0
	sub.d	$f0, $f10
	ctc1	t4, $31				/* restore fp control/status */
	j	ra

80:	/* X < -1 threshold */
	li.d	$f0, -1.0			/* should raise inexact */
	j	ra

81:	/* |X| < identity threshold */
	ctc1	t4, $31				/* restore fp control/status */
	mov.d	$f0, $f12			/* should raise inexact */
	j	ra

90:	/* raise Overflow and return +Infinity */
	mfc1	t0, $f13			/* extract argument exponent */
	sll	t0, 1
	srl	t0, 20+1
	beq	t0, 2047, 91f			/* - if NaN or Infinity */
	li.d	$f0, 0.898846567431158e308
	add.d	$f0, $f0			/* raise Overflow */
	j	ra
91:	mov.d	$f0, $f12			/* dont raise any flags */
						/* - if argument is exceptional */
						/* just return argument */
	j	ra
	.end expm1

/*******************************************************************************
*
* trunc - floating point truncation
*

* INTERNAL
* An alternate algorithm would to check for numbers < 2**53,
* set the rounding mode, add 2**53, and subtract 2**53. 

* double trunc (dblParam)
*     double dblParam;

*/
	.globl trunc
	.ent   trunc
trunc:
	.frame	sp, 0, ra
	mfc1	t1, $f13
	mfc1	t0, $f12
	srl	t2, t1, 20
	and	t2, 0x7FF
	sub	t2, 1023
	bge	t2, 0, trunc1
	mtc1	$0, $f0
	mtc1	$0, $f1
	j	ra
trunc1:
	sub	t2, 20
	bgt	t2, 0, trunc2
	neg	t2
	srl	t1, t2
	sll	t1, t2
	mtc1	$0, $f0
	mtc1	t1, $f1
	j	ra
trunc2:
	sub	t2, 32
	bge	t2, 0, trunc3
	neg	t2
	srl	t0, t2
	sll	t0, t2
trunc3:
	mtc1	t0, $f0
	mtc1	t1, $f1
	j	ra
	.end trunc


/*******************************************************************************
*
* z_abs_ - 
*
* NOMANUAL
*
* This entrypoint provided for FCOM for ZABS (complex absolute value),
* because FCOM has a hard time calling HYPOT directly.  Also used by
* FCOM when user writes INTRINSIC ZABS.  The latter must use pass by
* reference, of course. 
*/
	.globl z_abs_
	.ent   z_abs_
z_abs_:
	.frame	sp, 0, ra
	l.d	$f12, 0(a0)
	l.d	$f14, 8(a0)
	/* just fall through */
	.end z_abs_

/*******************************************************************************
*
* hypot - 
*
* NOMANUAL
*
*/
	.globl hypot
	.ent   hypot
hypot:
	.frame	sp, 0, ra
	.set noreorder
	abs.d	$f2, $f12
	abs.d	$f4, $f14
	mfc1	t0, $f3
	mfc1	t1, $f5
	li	t7, 2047
	srl	t2, t0, 20
	srl	t3, t1, 20
	beq	t2, t7, 70f
	 c.lt.d	$f2, $f4
	beq	t3, t7, 75f
	 subu	t4, t2, t3
	bc1f	10f
	 slt	t5, t4, 31
	abs.d	$f2, $f14
	abs.d	$f4, $f12
	move	t1, t0
	subu	t4, t3, t2
	slt	t5, t4, 31
10:	beq	t5, 0, 20f
	 mfc1	t0, $f4
11:	bne	t1, 0, 12f
	 sub.d	$f6, $f2, $f4
	beq	t0, 0, 20f
	 nop
12:
	.set reorder
	SETFRAME(hypot,4)
	subu	sp, FRAMESZ(hypot)
	SW	ra, FRAMERA(hypot)(sp)
	s.d	$f2, FRAMEA0(hypot)(sp)
	s.d	$f4, FRAMEA1(hypot)(sp)
	c.lt.d	$f4, $f6
	bc1f	13f

 	div.d	$f6, $f2, $f4
	li.d	$f2, one
	mul.d	$f12, $f6, $f6
	s.d	$f6, FRAMER0(hypot)(sp)
	add.d	$f12, $f2
	jal	sqrt
	l.d	$f6, FRAMER0(hypot)(sp)
	add.d	$f6, $f0
	b	14f
13:
	li.d	$f10, two
	div.d	$f6, $f4
	add.d	$f8, $f6, $f10
	mul.d	$f8, $f6
	s.d	$f6, FRAMER0(hypot)(sp)
	add.d	$f12, $f8, $f10
	s.d	$f8, FRAMER2(hypot)(sp)
	jal	sqrt
	li.d	$f10, HYPT_sqrt2
	l.d	$f6, FRAMER0(hypot)(sp)
	l.d	$f8, FRAMER2(hypot)(sp)
	add.d	$f0, $f10
	div.d	$f8, $f0
	add.d	$f6, $f8
	li.d	$f10, HYPT_r2p1lo
	li.d	$f12, HYPT_r2p1hi
	add.d	$f6, $f10
	add.d	$f6, $f12
14:
	l.d	$f4, FRAMEA2(hypot)(sp)
	LW	ra, FRAMERA(hypot)(sp)
	div.d	$f6, $f4, $f6
	l.d	$f2, FRAMEA0(hypot)(sp)
	addu	sp, FRAMESZ(hypot)
	add.d	$f0, $f6, $f2
	j	ra

20:	mov.d	$f0, $f2
	j	ra

22:	mov.d	$f0, $f4
	j	ra

70:	c.eq.d	$f12, $f12
	bc1t	20b
	beq	t3, t7, 75f
	mov.d	$f0, $f12
	j	ra

75:	c.eq.d	$f14, $f14
	bc1t	22b
	mov.d	$f0, $f14
	j	ra
	.end hypot


/*******************************************************************************
*
* log1p - 
*

* double log1p (dblParam)
*     double dblParam;

*/
	.globl log1p
	.ent   log1p
log1p:
	.frame	sp, 0, ra
	/* argument in f12 */
	.set noreorder
	cfc1	t5, $31
	and	t6, t5, -4
	li.d	$f10,  6.4494458917859432e-02	# ceil( exp( 1/16)-1)
	li.d	$f16, -6.0586937186524220e-02	# floor(exp(-1/16)-1)
	c.ult.d	$f12, $f10
	li.d	$f10, 1.0
	bc1f	1f
	 c.olt.d $f16, $f12
	neg.d	$f16, $f10
	bc1t	5f
	 c.ule.d $f12, $f16
	nop
	bc1t	8f
	 nop
1:	add.d	$f14, $f12, $f10
	li	t4, 2047
	mfc1	t0, $f15
	ctc1	t6, $31
	srl	t1, t0, 20
	beq	t1, t4, 7f
	 subu	t1, 1023
	.set reorder
	sll	t2, t1, 20
	subu	t9, t0, t2
	mtc1	t9, $f15
	li.d	$f16, 3.5184372088832000e+13	# 2^(53-8)
	mtc1	t1, $f8
	add.d	$f0, $f14, $f16
	la	t4, LOGC_TBL
	sub.d	$f18, $f0, $f16
	mfc1	t3, $f0

	slt	v0, t1, -1
	slt	v1, t1, 53
	beq	v0, 0, 2f
	sub.d	$f12, $f14, $f18
	b	4f
2:
	mfc1	t9, $f13
	subu	t9, t2
	mtc1	t9, $f13
	li	t8, 1023<<20
	subu	t8, t2
	mtc1	t8, $f1
	mtc1	$0, $f0
	bne	v1, 0, 3f
	sub.d	$f12, $f18
	add.d	$f12, $f0
	b	4f
3:
	sub.d	$f0, $f18
	add.d	$f12, $f0
4:
	add.d	$f12, $f12
	add.d	$f18, $f14
	div.d	$f12, $f18

	cvt.d.w	$f8, $f8
	l.d	$f10, 128*16+0(t4)	# log2head
	l.d	$f16, 128*16+8(t4)	# log2trail
	mul.d	$f0, $f8, $f10
	sll	t3, 4
	addu	t3, t4
	mul.d	$f2, $f8, $f16
	l.d	$f4, -128*16+0(t3)
	l.d	$f6, -128*16+8(t3)
	add.d	$f0, $f4
	add.d	$f2, $f6

	mul.d	$f18, $f12, $f12
	li.d	$f10, 1.2500053168098584e-02
	li.d	$f16, 8.3333333333039133e-02
	mul.d	$f14, $f18, $f10
	add.d	$f14, $f16
	mul.d	$f14, $f18
	mul.d	$f14, $f12
	add.d	$f14, $f2
	add.d	$f14, $f12
	ctc1	t5, $31
	add.d	$f0, $f14
	j	ra

5:	/* exp(-1/16)-1 < x < exp(1/16)-1 */
	/* use special approximation */
	li.d	$f16, 1.57e-16
	abs.d	$f14, $f12
	c.lt.d	$f14, $f16
	bc1t	7f
	ctc1	t6, $31
	add.d	$f16, $f10, $f10	# 2.0
	add.d	$f14, $f12, $f16
	div.d	$f14, $f10, $f14
	mul.d	$f2, $f12, $f14
	add.d	$f2, $f2
	mul.d	$f4, $f2, $f2
	li.d	$f10, 4.3488777770761457e-04
	li.d	$f16, 2.2321399879194482e-03
	mul.d	$f6, $f4, $f10
	add.d	$f6, $f16
	li.d	$f10, 1.2500000003771751e-02
	mul.d	$f6, $f4
	add.d	$f6, $f10
	li.d	$f16, 8.3333333333331788e-02
	mul.d	$f6, $f4
	add.d	$f6, $f16
	mul.d	$f6, $f4
	mul.d	$f6, $f2
	cvt.s.d	$f4, $f2
	cvt.d.s	$f4, $f4
	cvt.s.d	$f2, $f12
	cvt.d.s	$f2, $f2
	sub.d	$f8, $f12, $f2
	sub.d	$f0, $f12, $f4
	add.d	$f0, $f0
	mul.d	$f2, $f4
	sub.d	$f0, $f2
	mul.d	$f8, $f4
	sub.d	$f0, $f8
	mul.d	$f0, $f14
	add.d	$f0, $f6
	ctc1	t5, $31
	add.d	$f0, $f4
	j	ra

7:	/* log(+Infinity) = +Infinity */
	/* log(NaN) = NaN */
	mov.d	$f0, $f12
	j	ra

8:	/* x <= -1 or x = NaN */
	c.eq.d	$f12, $f16
	li.d	$f10, 0.0
	bc1f	9f
	div.d	$f0, $f16, $f10
	j	ra

9:	c.eq.d	$f12, $f12
	bc1f	7b
	div.d	$f0, $f10, $f10
	j	ra
	.end log1p

/********************************************************************************
* rint - convert double to integer
*
 
* int rint (dblParam)
*     double dblParam;
 
*/
	.globl rint
	.ent   rint
rint:
	.frame	sp, 0, ra
	li.d	$f4, 4503599627370496.0	/* 2^52 */
	abs.d	$f2, $f12		/* |arg| */
	c.olt.d	$f2, $f4		/* if |arg| >= 2^52 or arg is NaN */
	mfc1	t0, $f13
	mov.d	$f0, $f12
	bc1f	4f			/* then done */
	/* < 2^52 */
	sll	t1, t0, 1
	bgez	t0, 2f			/* if input negative, negate result */
	/* negative */
	beq	t1, 0, 3f		/* possible -0 */
1:	sub.d	$f0, $f12, $f4
	add.d	$f0, $f4
	j	ra
2:	/* positive */
	add.d	$f0, $f12, $f4		/* bias by 2^52 to force non-integer
					   bits off end */
	sub.d	$f0, $f4		/* unbias */
	j	ra

3:	/* msw = 80000000 */
	mfc1	t1, $f12		/* if -0, return -0 */
	bne	t1, 0, 1b		/* if negative denorm, process that */
4:	j	ra
	.end rint
		
/******************************************************************************
*
* isNaN - 
*
* This routine takes an input double-precision floating point
* parameter, <dbl>, and returns TRUE if <dbl> contains an IEEE not
* a number value.
*
*
* BOOL isNaN (dbl)
*     double	dbl;
*
* RETURNS: TRUE if <dbl> is NaN, else FALSE
*/
	.ent	isNaN
isNaN:
	mfc1	v0, fp13
	srl	v0, v0, 16
	li	t0, INF_HI_SHORT
	andi	v0, v0, 0x7fff
	swc1	fp12, 4(sp)
	slt	v0, t0, v0
	j	ra
	.end	isNaN

#endif	/* INCLUDE_DOUBLE_PRECISION */


#ifdef  INCLUDE_SINGLE_PRECISION
/*******************************************************************************
*
* acosf - floating point arc-cosine
*

* float acos (fltParam)
*     float fltParam;

*/
	.globl acosf
	.ent   acosf
acosf:
	.frame	sp, 0, ra
	li.s	$f8, half
	abs.s	$f14, $f12
	c.le.s	$f14, $f8
	li.s	$f10, FACS_eps
	move	t9, ra
	bc1f	acosf2
	c.lt.s	$f14, $f10
	mov.s	$f0, $f12
	bc1t	1f
	mul.s	$f2, $f12, $f12
	jal	asincosf2
1:	li.s	$f8, FACS_pio2
	sub.s	$f0, $f8, $f0
	j	t9
acosf2:
	jal	asincosf1
	/* nop */
	bltz	t0, 1f
	/* nop */
	neg.s	$f0
	j	t9
1:	li.s	$f8, FACS_pi
	add.s	$f0, $f8
	j	t9
	.end acosf

/*******************************************************************************
*
* asinf - floating point arc-sine
*

* float asinf (fltParam)
*     float fltParam;

*/
	.globl asinf
	.ent   asinf
asinf:
	.frame	sp, 0, ra
	li.s	$f8, half
	abs.s	$f14, $f12
	c.ole.s	$f14, $f8
	li.s	$f10, FACS_eps
	move	t9, ra
	bc1f	asinf2
	c.lt.s	$f14, $f10
	mul.s	$f2, $f12, $f12
	mov.s	$f0, $f12
	bc1f	asincosf2
	j	ra
	/* nop */

asinf2:
	jal	asincosf1
	/* nop */
	li.s	$f8, FACS_pio2
	add.s	$f0, $f8
	bltz	t0, 1f
	j	t9
	/* nop */
1:	neg.s	$f0
	j	t9


asincosf1:
	li.s	$f10, one
	sw	ra, 0(sp)
	c.ole.s	$f14, $f10
	s.s	$f12, 4(sp)
	sub.s	$f0, $f10, $f14
	bc1f	asinf_error
	mul.s	$f12, $f0, $f8
	s.s	$f12, 8(sp)
	subu	sp, 16
	jal	sqrtf
	addu	sp, 16
	l.s	$f2, 8(sp)
	lw	ra, 0(sp)
	lw	t0, 4(sp)
	add.s	$f0, $f0
	neg.s	$f0
	/* fall through */
asincosf2:
	li.s	$f8, FACS_p2
	li.s	$f10, FACS_q1
	mul.s	$f4, $f2, $f8
	add.s	$f6, $f2, $f10
	li.s	$f8, FACS_p1
	mul.s	$f6, $f2
	add.s	$f4, $f8
	li.s	$f10, FACS_q0
	mul.s	$f4, $f2
	add.s	$f6, $f10

	div.s	$f4, $f6
	mul.s	$f4, $f0
	add.s	$f0, $f4
	j	ra

asinf_error:	/* |x| > 1 */
	c.un.s	$f12, $f12	/* - if x = NaN, return x */
	li.s	$f0, 0.0	/* - else generate a NaN */
	bc1t	1f
	div.s	$f0, $f0
	j	t9
1:	mov.s	$f0, $f12
	j	t9
	.end asinf

/*******************************************************************************
*
* atan2f - single precision floating point arctangent
*

* float atan2f (fltParam)
*     float fltParam;

*/
	.globl atan2f
	.ent   atan2f
atan2f:
	.frame sp, 0, t3
	abs.s	$f0, $f12
	abs.s	$f2, $f14
	c.le.s	$f0, $f2
	mfc1	t0, $f12		/* save signs of both operands */
	mfc1	t1, $f14		/* ... */
	/* is $f12 or $f14 = +-Inf or Nan ? */
        sll     t2, t0, 1
        sll     t3, t1, 1
        srl     t2, t2, 1
        srl     t3, t3, 1
        li      t4, 255
        sll     t4, 23
        blt     t2, t4, 5f 
	bgt	t2, t4, 3f
        blt     t3, t4, 5f 
	bgt	t3, t4, 4f
        /* x and y are +/- Inf */
        li.s    $f0, TN_pio4                    /* f0 = pi/4 */
        bgez    t0, 1f
        neg.s   $f0                             /* f0 = -pi/4 */
1:      bgez    t1, 2f
        li.s    $f2, 3.0
        mul.s   $f0, $f2, $f0
2:      nop
	j	ra

3:      /* atan2f (Nan, ?) = Nan */
	mov.s	$f0, $f12
	j	ra

4:      /* atan2f (?, Nan) = Nan */
	mov.s	$f0, $f14
	j	ra

5:	move	t3, ra
	bc1t	atan2f1
	div.s	$f0, $f2, $f0
	li.s	$f2, FAT_mpio2
	b	atan2f2
atan2f1:
	beq	t1, 0, atan2fz
	div.s	$f0, $f2
	li.s	$f2, 0.0
atan2f2:
	li.s	$f10, FAT_twomr3
	jal	atan1
	bge	t1, 0, atan2f3
	li.s	$f2, FAT_pi
	sub.s	$f0, $f2, $f0
atan2f3:
	bge	t0, 0, atan2f4
	neg.s	$f0
	j	t3	
atan2f4:
	j	t3

atan2fz:
	/* break 0 */
	j	ra
	.end atan2f

/*******************************************************************************
*
* atanf - single precision floating point arctangent
*

* float atan (fltParam)
*     float fltParam;

*/
	.globl atanf
	.ent   atanf
atanf:
	.frame sp, 0, t3
	mfc1	t0, $f12
	move	t3, ra
	/* is $f12 = Nan ? */
        sll     t2, t0, 1
        srl     t2, t2, 1
        li      t4, 255
        sll     t4, 23
        ble     t2, t4, 1f
	/* atanf (Nan) = Nan */
	mov.s	$f0, $f12
	j	t3

1:	abs.s	$f0, $f12
	bge	t0, 0, atanf0
	jal	atanf0
	neg.s	$f0
	j	t3

atanf0:	li.s	$f14, one
	li.s	$f10, FAT_twomr3
	c.le.s	$f0, $f14
	li.s	$f2, 0.0
	bc1t	atan1
	div.s	$f0, $f14, $f0
	li.s	$f2, FAT_mpio2
atan1:	c.le.s	$f0, $f10
	li.s	$f14, FAT_sqrt3m1
	bc1t	latan2		/* branch to local atan2 */
	li.s	$f10, FAT_sqrt3
	mul.s	$f6, $f0, $f14
	add.s	$f4, $f0, $f10
	li.s	$f14, one
	sub.s	$f6, $f14
	add.s	$f0, $f6
	li.s	$f14, FAT_pio6
	div.s	$f0, $f4
	add.s	$f2, $f14
latan2:	mul.s	$f6, $f0, $f0
	li.s	$f14, FAT_p1
	li.s	$f10, FAT_p0
	mul.s	$f4, $f6, $f14
	add.s	$f4, $f10
	li.s	$f14, FAT_q0
	mul.s	$f12, $f4, $f6
	add.s	$f4, $f6, $f14
	div.s	$f4, $f12, $f4
	mul.s	$f4, $f0
	add.s	$f0, $f4
	mfc1	t4, $f2
	add.s	$f0, $f2
	bge	t4, 0, atan4
	neg.s	$f0
	j	ra
atan4:	j	ra
	.end atanf

/*******************************************************************************
*
* fabsf - single precision absolute value
*

* float fabs (fltParam)
*     float fltParam;

*/
        .globl fabsf
        .ent   fabsf
fabsf:
        abs.s   $f0, $f12
        j       ra
        .end fabsf

/*******************************************************************************
*
* fcabs - floating point single precision complex number
*
* RETURN THE ABSOLUTE VALUE OF THE SINGLE PRECISION COMPLEX NUMBER

* float fabs (z)
* struct { float r, i;} z;
* {
* 	return hypotf(z.r,z.i);
* }

*/
	.globl fcabs
	.ent   fcabs
fcabs:
	.frame	sp, 0, ra
	mtc1	$4, $f12
	mtc1	$5, $f14
	j	hypotf
	.end fcabs

/*******************************************************************************
*
* coshf - single precision floating point hyperbolic cosine
*

* float cosh (fltParam)
*     float fltParam;

*/
	.globl coshf
	.ent   coshf
coshf:
	.frame	sp, 0, ra
	li.s	$f10, 88.7228317
	abs.s	$f12
	c.ole.s	$f12, $f10
	SW	ra, 0(sp)
	bc1f	coshf_error
	subu	sp, 16
	jal	expf
	addu	sp, 16
	li.s	$f10, 0.5
	div.s	$f2, $f10, $f0
	LW	ra, 0(sp)
	mul.s	$f0, $f10
	add.s	$f0, $f2
	j	ra

coshf1:
#if	FALSE
	li.s	$f8, 0.69316101074218750000e+0
	li.s	$f6, expfmax
	sub.s	$f12, $f8
	c.lt.s	$f6, $f12
	SW	ra, 0(sp)
	bc1t	coshf_error
	subu	sp, 16
	jal	expf
	addu	sp, 16
	li.s	$f8, 1.0
	li.s	$f6, 0.13830277879601902638e-4
	sub.s	$f2, $f0, $f8
	LW	ra, 0(sp)
	mul.s	$f2, $f6
	add.s	$f0, $f2
	j	ra
#endif	/* FALSE */
coshf_error:
	/* raise Overflow and return +Infinity */
	mfc1	t0, $f12
	srl	t0, 23
	beq	t0, 255, 1f
	li.s	$f0, 2e38
	add.s	$f0, $f0
	j	ra
1:	mov.s	$f0, $f12
	j	ra
	.end coshf

/*******************************************************************************
*
* expf - floating point single precision exponetial function
*

* float expf (fltParam)
*     float fltParam;

*/
        .globl expf
        .ent   expf
expf:

        .frame sp, 0, ra
        /* argument in f12 */
        .set noreorder
        li.s    $f10, 88.7228317		/* expfmax */
        cfc1    t4, $31                         /* read fp control/status */
        c.ole.s $f12, $f10                      /* check if special */
        li.s    $f14, -103.2789299019278	/* expfmin */
        bc1f    90f                             /* - if NaN, +Infinity, */
                                                /* or greater than expmax */
        c.lt.s  $f12, $f14                      /* check for exp(x) = 0 */
        li      t1, -4
        bc1t    80f                             /* - if less than expmin */
        and     t1, t4                          /* rounding mode = nearest */
        .set reorder
        ctc1    t1, $31                         /* write fp control/status */
        /* argument reduction */
        li.s    $f10, 46.166241308446828
        mul.s   $f2, $f12, $f10
        li.s    $f14, 2.1660849390173098e-2
        li.s    $f10, -2.325192846878874e-12
        cvt.w.s $f2, $f2
        mfc1    t0, $f2
        and     t1, t0, 31                      /* region  32<t1<=0 */
        sra     t2, t0, 5                       /* scale t2=t0/32 */
        cvt.s.w $f2, $f2
        mul.s   $f4, $f2, $f14
        mul.s   $f6, $f2, $f10
        sub.s   $f4, $f12, $f4

        add.s   $f2, $f4, $f6
        li.s    $f10, 1.3888949086377719e-3
        li.s    $f14, 8.3333679843421958e-3
        mul.s   $f8, $f2, $f10
        add.s   $f0, $f8, $f14
        li.s    $f10, 4.1666666666226079e-2
        li.s    $f14, 1.6666666666526087e-1
        mul.s   $f0, $f2
        add.s   $f0, $f10
        mul.s   $f0, $f2
        add.s   $f0, $f14
        li.s    $f10, 0.5
        mul.s   $f0, $f2
        add.s   $f0, $f10
        mul.s   $f0, $f2
        mul.s   $f0, $f2
        add.s   $f0, $f6
        add.s   $f0, $f4
        sll     t1, 3
        la      t1, EXPF_DAT(t1)
        l.s     $f10, 0(t1)
        l.s     $f14, 4(t1)
        add.s   $f8, $f10, $f14
        mul.s   $f0, $f8
        add.s   $f0, $f14
        add.s   $f0, $f10
        beq     t2, 0, 60f              /* early out for 0 scale */
        mfc1    t0, $f0                 /* get result high word */
        ctc1    t4, $31                 /* restore control/status */
        sll     t1, t0, 1               /* extract exponent */
        srl     t1, 23+1                /* ... */
        addu    t1, t2                  /* add scale to check for denorm */
        sll     t2, 23
        blez    t1, 70f
        addu    t0, t2                  /* add scale */
        mtc1    t0, $f0                 /* put back in result high word */
        j       ra
60:     /* scale = 0, just restore control/status and return */
        ctc1    t4, $31
        j       ra
70:     /* denorm result */
        addu    t2, 64<<23
        addu    t0, t2
        mtc1    t0, $f1
        li.s    $f2, 5.4210108624275222e-20
        mul.s   $f0, $f2
        j       ra

80:     /* argument < expmin */
        li.s    $f0, 0.0		/* should raise underflow */
        j       ra

90:     /* raise Overflow and return +Infinity */
        mfc1    t0, $f12		/* extract argument exponent */
        sll     t0, 1
        srl     t0, 23+1
        beq     t0, 255, 91f		/* - if NaN or Infinity */
        li.s    $f0, 1.701411735e38
        add.s   $f0, $f0		/* raise Overflow */
        j       ra
91:     mov.s   $f0, $f12		/* dont raise any flags */
                                        /* - if argument is exceptional */ 
					/* just return argument */
        j       ra
        .end expf


/*******************************************************************************
*
* truncf - floating point single precision truncation
*

* float truncf (fltParam)
*     float fltParam;

*/
	.globl truncf
	.ent   truncf
truncf:
	.frame	sp, 0, ra
	mfc1	t0, $f12
	srl	t2, t0, 23
	and	t2, 0xFF
	sub	t2, 127
	bge	t2, 0, truncf1
	mtc1	$0, $f0
	j	ra
truncf1:	
	sub	t2, 23
	bge	t2, 0, truncf2
	neg	t2
	srl	t0, t2
	sll	t0, t2
truncf2:
	mtc1	t0, $f0
	j	ra
	.end truncf

/*******************************************************************************
*
* floorf - single precision floating point floor
*

* float floorf (fltParam)
*     float fltParam;

* XXX WARNING: 
*          following routine incorrectly returns 0 when +/- INF is the input
*          this should be corrected if this routine is to be used in the future
*/
	.globl floorf
	.ent   floorf
floorf:
	.frame	sp, 0, t3
	move	t3, ra
	/* is x = +/- Inf ? */
	mfc1    t0, $f12
        sll     t2, t0, 1
        srl     t2, t2, 1
        li      t4, 255
        sll     t4, 23
        bne     t2, t4, 1f
        /* x is +/- Inf */
        li.s    $f0, 0.0
        j       ra

1:	jal	truncf
	sub.s	$f2, $f12, $f0
	mfc1	t0, $f2
	li.s	$f2, 1.0
	sll	t1, t0, 1
	bge	t0, 0, 2f
	beq	t1, 0, 2f
	sub.s	$f0, $f2
2:	j	t3
	.end floorf

/*******************************************************************************
*
* ceilf - single precision floating point ceil
*

* float ceilf (fltParam)
*     float fltParam;

* XXX WARNING: 
*          following routine incorrectly returns 0 when +/- INF is the input
*          this should be corrected if this routine is to be used in the future
*/
	.globl ceilf
	.ent   ceilf
ceilf:
	.frame	sp, 0, t3
	move	t3, ra
	/* is x = +/- Inf ? */
	mfc1    t0, $f12
        sll     t2, t0, 1
        srl     t2, t2, 1
        li      t4, 255
        sll     t4, 23
        bne     t2, t4, 1f
        /* x is +/- Inf */
        li.s    $f0, 0.0
        j       ra

1: 	jal	truncf
	sub.s	$f2, $f12, $f0
	mfc1	t0, $f2
	li.s	$f2, 1.0
	ble	t0, 0, 2f
	add.s	$f0, $f2
2:	j	t3
	.end ceilf


/*******************************************************************************
*
* fmodf - single precision floating point fmod
*

* float fmodf (fltParamX, fltParamY)
*     float fltParamX;
*     float fltParamY;

*/
        .globl fmodf
        .ent   fmodf
fmodf:
        .frame  sp, 0, t3
	move	t3, ra
	abs.s	$f0, $f14
	mfc1    t0, $f0
	beq     t0, zero, retZero		/* |Y| = 0.0 ? */
	lui	t1, INF_HI_SHORT_SINGLE
	bgt	t0, t1, retY			/* |Y| = Nan ? */
	bge     t0, t1, retX			/* |Y| = Inf ? */
	abs.s   $f2, $f12
	mfc1    t2, $f2				/* |X| -> t2 */
	bge	t2, t1, retZero                 /* |X| = Nan or |X| = Inf ? */

	mov.s	$f16, $f12			/* save fltParamX to f16 */
        div.s   $f12, $f14			/* X/Y */
	jal	truncf				/* f0 = truncf(X/Y) */
	nop
	mul.s	$f2, $f0, $f14			
	sub.s	$f0, $f16, $f2	

	/* set result to sign of fltParamX */

	mfc1    t0, $f16
	srl	t0, 31
	sll	t0, 31
	mfc1    t1, $f0
	sll     t1, 1
	srl	t1, 1
	add	t0, t1
	mtc1	t0, $f0
	j	t3
	nop
retZero:
	li.s	$f0, 0.0
	j	t3
retX:	mov.s 	$f0, $f12
	j	t3
retY:	mov.s 	$f0, $f14
	j	t3
	.end fmodf

/*******************************************************************************
*
* hypotf - floating point single precision Euclidean distance
*

* float hypotf (fltX, fltY)
*     float fltX;
*     float fltY;
*
* NOMANUAL
*/
	.globl hypotf
	.ent   hypotf
hypotf:
	.frame	sp, 0, ra
	mul.s	$f12, $f12
	mul.s	$f14, $f14
	add.s	$f12, $f14
	mfc1	t0, $f13
	li	t2, -(1023<<19)+(1023<<20)
	sra	t1, t0, 20
	li	t3, 2047
	beq	t1, 0, 8f
	srl	t0, 1
	beq	t1, t3, 8f
	srl	t1, t0, 15-2
	and	t1, 31<<2
	lw	t1, _sqrttable(t1)
	addu	t0, t2
	subu	t0, t1
	mtc1	t0, $f1
	mtc1	$0, $f0
	/* 8 -> 18 bits */
	li	t2, (1<<20)
	div.s	$f2, $f12, $f0
	/* 18 cycle interlock */
	add.s	$f0, $f2
	/* 1 cycle interlock (2 cycle stall) */
	mfc1	t0, $f1
	add	t1, t2, 6	/* 17 -> 18 bits */
	subu	t0, t1
	mtc1	t0, $f1
	/* nop */
	/* 18 -> 37 bits */
	div.s	$f2, $f12, $f0
	/* 18 cycle interlock */
	add.s	$f0, $f2
	li.s	$f2, half
	mul.s	$f0, $f2
	j	ra

8:	mov.s	$f0, $f12
	abs.s	$f0
	j	ra
	.end hypotf


/*******************************************************************************
*
* logf - single precision floating point natural logarithm 
*

* float logf (fltParam)
*     float fltParam;

*/
	.globl logf
	.ent   logf
logf:
	.frame	sp, 0, ra
	mfc1	t0, $f12
	srl	t1, t0, 23
	ble	t0, 0, logferr
	beq	t1, 255, logfnan
	subu	t1, 126
	sll	t2, t1, 23
	subu	t0, t2
	mtc1	t0, $f12
	li.s	$f6, 0.70710678118654752440
	li.s	$f8, one
	c.lt.s	$f6, $f12
	li.s	$f6, two
	bc1t	logf1
	addu	t0, (1<<23)
	mtc1	t0, $f12
	subu	t1, 1
logf1:	sub.s	$f4, $f12, $f8
	mul.s	$f4, $f6
	add.s	$f0, $f12, $f8
	div.s	$f4, $f0
	mul.s	$f0, $f4, $f4
	li.s	$f6, FLOG_p0
	li.s	$f8, FLOG_q0
	mul.s	$f2, $f0, $f6
	add.s	$f0, $f0, $f8
	mtc1	t1, $f8
	div.s	$f2, $f0
	mul.s	$f2, $f4
	add.s	$f2, $f4
	beq	t1, 0, log2f
	li.s	$f6, FLOG_ln2
	cvt.s.w	$f8, $f8
	mul.s	$f8, $f6
	add.s	$f2, $f8
log2f:	mov.s	$f0, $f2
	j	ra
logferr:
	li.s	$f2, 0.0
	sll	t1, t0, 1
	beq	t1, 0, logf0
	/* return signaling Nan */
	li	t1, 0x7fff
	sll	t1, t1, 16
	mtc1	t1, $f0
	j	ra
logf0:
	li.s	$f0, -1.0
	div.s	$f0, $f2
	j	ra
logfnan:
	mov.s	$f0, $f12
	j	ra
	.end logf

#if FALSE
	.globl r_lg10
	.ent   r_lg10
r_lg10:
	l.s	$f12, (a0)
	.end r_lg10
#endif

/*******************************************************************************
*
* log10f - single precision floating point logarithm base 10 
*

* float log10f (fltParam)
*     float fltParam;

*/
	.globl log10f
	.ent   log10f
log10f:
	.frame	sp, 0, t3
	move	t3, ra
        /* is x < 0 ? */
        li.s    $f10, 0.0
        c.ult.s $f12, $f10
        nop
        bc1t    log10fNeg
        nop

        /* is x = 0 ? */
        c.ueq.s $f12, $f10
        nop
        bc1t    log10fZero

        /* return log(x)/log(10) */
	jal	logf
	li.s	$f6, FLOG_loge
	mul.s	$f0, $f6
	j	t3

log10fNeg:
        /* return signaling Nan */
        li      v0, 0x7fc0              /* set Nan return value */
        sll     v0, v0, 16
        mtc1    v0, $f0
        j       t3

log10fZero:
        /* returns -Inf */
        li      v0, 0xff80
        sll     v0, v0, 16              /* v0 = 0xff800000 */
        mtc1    v0, $f0
        j       t3
	.end log10f


/*******************************************************************************
*
* cosf - single precision floating point cosine
*

* float cosf (fltParam)
*     float fltParam;

*/
	.globl cosf
	.ent   cosf
cosf:
	.frame	sp, 0, ra
	li.s	$f6, FSNCS_ymax
	abs.s	$f12			# COS(-X) = COS(X)
	cfc1	t1, $31
	c.olt.s	$f12, $f6
	and	t0, t1, ~RM_MASK
	bc1f	sincos2
	ctc1	t0, $31
	/* Reduce argument */
	li.s	$f6, FSNCS_oopi
	li.s	$f8, half
	mul.s	$f2, $f12, $f6
	add.s	$f2, $f8
	cvt.w.s	$f4, $f2
	cvt.s.w	$f2, $f4
	mfc1	t0, $f4
	sub.s	$f2, $f8
	mov.s	$f10, $f12
	b	sincos
	.end cosf

/*******************************************************************************
*
* sinf - single precision floating point sine
*

* float sinf (fltParam)
*     float fltParam;

*/
	.globl sinf
	.ent   sinf
sinf:
	.frame	sp, 0, ra
	li.s	$f8, FSNCS_pio2
	abs.s	$f0, $f12
	c.olt.s	$f0, $f8
	cfc1	t1, $31
	mov.s	$f10, $f12
	bc1t	sincos1
	and	t0, t1, ~RM_MASK
	li.s	$f6, FSNCS_ymax
	c.olt.s	$f0, $f6
	li.s	$f6, FSNCS_oopi
	bc1f	sincos2
	ctc1	t0, $31
	/* Reduce argument */
	mul.s	$f2, $f12, $f6
	cvt.w.s	$f2, $f2
	mfc1	t0, $f2
	cvt.s.w	$f2, $f2
sincos:
	/* use extended precision arithmetic to subtract N*PI */
	li.s	$f6, FSNCS_pi
	and	t0, 1
	mul.s	$f2, $f6
	sub.s	$f10, $f2
	beq	t0, 0, sincos1
	neg.s	$f10
sincos1:
	mul.s	$f2, $f10, $f10		# g = f**2

	/* evaluate R(g) */
	li.s	$f6, FSNCS_p4
	li.s	$f8, FSNCS_p3
	mul.s	$f4, $f2, $f6
	add.s	$f4, $f8
	li.s	$f8, FSNCS_p2
	mul.s	$f4, $f2
	add.s	$f4, $f8
	li.s	$f8, FSNCS_p1
	mul.s	$f4, $f2
	add.s	$f4, $f8

	/* result is f+f*g*R(g) */
	mul.s	$f4, $f2
	mul.s	$f4, $f10
	add.s	$f0, $f10, $f4
	ctc1	t1, $31		# restore rounding mode
	j	ra

sincos2:
	li.s	$f0, 0.0
	div.s	$f0, $f0
	j	ra
	.end sinf

/*******************************************************************************
*
* sinhf - single precision floating point hyperbolic sine
*

* float sinhf (fltParam)
*     float fltParam;

*/

/*
lnv:	.float 0.69316101074218750000e+0
vo2m1:	.float 0.13830277879601902638e-4
*/

	.globl sinhf
	.ent   sinhf
sinhf:

	.frame	sp, 0, ra
	li.s	$f8, one
	abs.s	$f0, $f12
	c.ole.s	$f0, $f8
	li.s	$f8, SNF_eps
	bc1f	sinhf2
	c.lt.s	$f0, $f8
	bc1t	sinhf1

sinhf0:
	mul.s	$f2, $f0, $f0
	li.s	$f10, SNF_p1
	li.s	$f8, SNF_q0
	mul.s	$f4, $f2, $f10
	li.s	$f10, SNF_p0
	add.s	$f6, $f2, $f8
	add.s	$f4, $f10
	mul.s	$f4, $f2
	div.s	$f4, $f6
	mul.s	$f4, $f12
	add.s	$f0, $f4, $f12
	j	ra

sinhf1:
	mov.s	$f0, $f12
	j	ra

sinhf2:
	li.s	$f8, 88.7228317
	s.s	$f12, 8(sp)
	c.ole.s	$f0, $f8
	SW	ra, 0(sp)
	mov.s	$f12, $f0
	bc1f	sinhf3
	subu	sp, 16
	jal	expf
	addu	sp, 16
	li.s	$f8, half
	div.s	$f2, $f8, $f0
	mul.s	$f0, $f8
	lw	t0, 8(sp)
	LW	ra, 0(sp)
	bltz	t0, 1f
	sub.s	$f0, $f0, $f2
	j	ra
1:	sub.s	$f0, $f2, $f0
	j	ra

sinhf3:
/*
	li.s	$f8, lnv
	li.s	$f6, expfmax
	sub.s	$f12, $f8
	c.lt.s	$f6, $f12
	SW	ra, 0(sp)
	bc1t	sinhf_error
	subu	sp, 16
	jal	expf
	addu	sp, 16
	li.s	$f8, one
	li.s	$f6, vo2m1
	sub.s	$f2, $f0, $f8
	LW	ra, 0(sp)
	mul.s	$f2, $f6
	add.s	$f0, $f2
	j	ra
*/
sinhf_error:
	/* raise Overflow and return +-Infinity */
	lw	t0, 8(sp)
	sll	t1, t0, 1
	srl	t1, 23+1
	beq	t1, 255, 1f
	li.s	$f0, 2e38
	add.s	$f0, $f0
1:	bltz	t0, 2f
	j	ra
2:	neg.s	$f0
	j	ra
	.end sinhf


/*******************************************************************************
*
* sqrtf - single precision floating point square root
*
* 0.5ulp accurate algorithm using double precision for final iteration
*

* float sqrtf (fltParam)
*     float fltParam;

*/

	.globl sqrtf
	.ent   sqrtf
sqrtf:
	.frame	sp, 0, ra
#if	1
/* all MIPS processors that we support the FPU, would have the sqrt instruction */
/* #if	((CPU == R4650) || (CPU == R4000) || (CPU==VR5000) || (CPU==VR5400)) */
	sqrt.s  $f0,$f12
	j	ra
	.end sqrtf
#else	/* CPU == R3000 || CPU == CW4000 || CPU == CW4011 */
	mfc1	t0, $f12
	li	t2, -(127<<22)+(127<<23)
	sra	t1, t0, 23
	li	t3, 255
	blez	t1, 8f
	srl	t0, 1
	beq	t1, t3, 9f
	srl	t1, t0, 18-2
	and	t1, 31<<2
	lw	t1, local_sqrttable(t1)
	addu	t0, t2
	subu	t0, t1
	mtc1	t0, $f0

	/* 8 -> 18 bits */
	cfc1	t4, $31
	div.s	$f2, $f12, $f0
	cvt.d.s	$f12, $f12
	li	t2, (1<<23)
	/* 9 cycle interlock */
	add.s	$f0, $f2
	/* 1 cycle interlock (2 cycle stall) */
	mfc1	t0, $f0
	add	t1, t2, 6<<3	/* 17 -> 18 bits (instead of nop) */
	subu	t0, t1
	mtc1	t0, $f0

	/* 18 -> 37 */
	cvt.d.s	$f0, $f0
	div.d	$f2, $f12, $f0
	/* 18 cycle interlock */
	add.d	$f0, $f2
	/* 1 cycle interlock (2 cycle stall) */

	/* 37 -> 75 (53) */
	div.d	$f2, $f12, $f0
	mfc1	t0, $f1
	li	t1, (2<<20)
	subu	t0, t1
	mtc1	t0, $f1
	/* nop */
	/* 13 cycle interlock */
	add.d	$f0, $f2
	ctc1	t4, $31
	cvt.s.d	$f0, $f0
	j	ra

8:	/* sign = 1 or biased exponent = 0 */
	sll	t2, t0, 1
	bne	t2, 0, 1f
9:	/* x = 0.0, -0.0, +Infinity, or NaN */
	mov.s	$f0, $f12
	j	ra
1:	/* x < 0 or x = denorm */
	move	t8, ra
	bgez	t0, denorm_sqrtf
	li.s	$f0, 0.0
	div.s	$f0, $f0
	j	ra
	.end sqrtf

	.ent   denorm_sqrtf
denorm_sqrtf:
	.frame	sp, 0, t8
	cvt.d.s	$f12, $f12
	jal	sqrt
	cvt.s.d	$f0, $f0
	j	t8
	/* nop */
	.end denorm_sqrtf
#endif	/* (CPU == R4650) || (CPU == R4000) || (CPU==VR5000) || (CPU==VR5400) */

/*******************************************************************************
*
* tanf - single precision floating point tangent
*

* float tanf (fltParam)
*     float fltParam;

*/
	.globl tanf
	.ent   tanf
tanf:
	.frame	sp, 0, ra
	li.s	$f8, TANF_pio4
	abs.s	$f0, $f12
	c.olt.s	$f0, $f8
	cfc1	t1, $31
	mov.s	$f14, $f12
	li	t0, 0
	bc1t	tanf0
	and	t2, t1, ~RM_MASK
	li.s	$f8, TANF_ymax
	c.olt.s	$f0, $f8
	li.s	$f8, TANF_twoopi
	bc1f	tanf2

	mul.s	$f2, $f12, $f8

	/* convert to integer using round-to-nearest */
	ctc1	t2, $31
	cvt.w.s	$f2, $f2
	mfc1	t0, $f2
	and	t0, 1

	/* argument reduction */
	cvt.s.w	$f2, $f2
	li.s	$f6, TANF_pio2
	mul.s	$f2, $f6
	sub.s	$f14, $f2
tanf0:
	/* rational approximation */
	mul.s	$f2, $f14, $f14
	li.s	$f8, TANF_q1
	li.s	$f6, TANF_p0
	mul.s	$f10, $f2, $f8
	li.s	$f8, TANF_q0
	mul.s	$f4, $f2, $f6
	add.s	$f10, $f8
	mul.s	$f10, $f2
	li.s	$f8, one
	mul.s	$f4, $f14
	add.s	$f10, $f8
	add.s	$f14, $f4
	ctc1	t1, $31
	bne	t0, 0, tanf1
	div.s	$f0, $f14, $f10
	j	ra
tanf1:	div.s	$f0, $f10, $f14
	neg.s	$f0
	j	ra
tanf2:
	li.s	$f0, 0.0
	div.s	$f0, $f0
	j	ra
	.end tanf

/*******************************************************************************
*
* tanhf - single precision floating point hyperbolic tangent
*

* float tanhf (fltParam)
*     float fltParam;

*/
	.globl tanhf
	.ent   tanhf
tanhf:
	.frame	sp, 0, ra
        /* is $f12 = Nan ? */
	mfc1	t0, $f12
        sll     t2, t0, 1
        srl     t2, t2, 1
        li      t4, 255
        sll     t4, 23
        ble     t2, t4, 1f
        /* tanhf (Nan) = Nan */
        mov.s   $f0, $f12
        j       ra

1:	li.s	$f8, TNHF_ln3o2
	abs.s	$f0, $f12
	c.lt.s	$f8, $f0
	li.s	$f8, TNHF_eps
	bc1t	tanhf2
	c.lt.s	$f0, $f8
	bc1t	tanhf1
	mul.s	$f2, $f0, $f0
	li.s	$f10, TNHF_p1
	li.s	$f8, TNHF_q0
	mul.s	$f4, $f2, $f10
	li.s	$f10, TNHF_p0
	add.s	$f6, $f2, $f8
	add.s	$f4, $f10
	mul.s	$f4, $f2
	div.s	$f4, $f6
	mul.s	$f4, $f12
	add.s	$f0, $f4, $f12
	j	ra

tanhf1:
	mov.s	$f0, $f12
	j	ra

tanhf2:
	li.s	$f10, TNHF_xbig
	s.s	$f12, 8(sp)
	c.lt.s	$f10, $f0
	SW	ra, 0(sp)
	add.s	$f12, $f0, $f0
	bc1t	tanhf4
	subu	sp, 16
	jal	expf
	addu	sp, 16
	li.s	$f10, one
	li.s	$f8, two
	add.s	$f0, $f10
	div.s	$f0, $f8, $f0
	lw	t0, 8(sp)
	LW	ra, 0(sp)
	bltz	t0, 1f
	sub.s	$f0, $f10, $f0
	j	ra
1:	sub.s	$f0, $f0, $f10
	j	ra

tanhf4:
	lw	t0, 8(sp)
	li.s	$f0, one
	bltz	t0, 1f
	j	ra
1:	neg.s	$f0
	j	ra
	.end tanhf

/******************************************************************************
*
* powf - software floating point power function
*
* This routine takes two input single-precision floating point
* parameters, <sglX> and <sglY>, and returns the single-precision
* value of <sglX> to the <sglY> power.
*
*
* float pow (sglX, sglY)
*     float    sglX;
*     float    sglY;
*
* RETURNS: single-precision value of <dblX> to <dblY> power.
*/

#define ONE_PT_OWE      1.0

        .globl  powf
        .ent    powf
powf:
        SETFRAME(powf,1)
        subu    sp, FRAMESZ(powf)	/* reserve some space */
        SW      ra, FRAMERA(powf)(sp)   /* store the return addr */
        swc1    fp12, FRAMEA0(powf)(sp) /* store passed param sglX */
	mfc1	t0, fp14		/* Y = 0.0 ? */
	beq	t0, zero, 0f 
	li.s	fp2, one		/* Y = 1.0 ? */
	c.eq.s	fp2, fp14
	nop
	bc1t	2f
	nop
        mov.s   fp12, fp14              /* load parameter for isNaN */
        jal     isNaNSingle             /* is Y not a number */
        swc1    fp14, FRAMEA1(powf)(sp) /* store passed param sglY */
        beq     v0, zero, 1f         	/* if not NaN branch */
        mov.s   fp0, fp14               /* load return value */
        b       donePowf                /* else we are done */

0:	/* powf (?, 0.0) = 1.0 */
	li.s	fp0, one
	b	donePowf

1:	lwc1    fp12, FRAMEA0(powf)(sp) /* reload passed params */
	jal     isNaNSingle             /* is X not a number */
	lwc1	fp14, FRAMEA1(powf)(sp)
	lwc1	fp12, FRAMEA0(powf)(sp)	/* reload passed params */
	beq	v0, zero, isANf		/* if not NaN branch */
2:	mov.s	fp0, fp12
	b	donePowf

isANf:
        li.s    fp2, ONE_PT_OWE        	/* load 1.0 */
	abs.s	fp4, fp12
        c.eq.s  fp4, fp2                /* compare dlbX with 1.0 */
        bc1f    notOnef                 /* if not 1.0 */
	/* test if Y is +-Inf */
	mfc1	t0, fp14
	sll	t1, t0, 1
	srl	t0, t1, 1
	li	t1, INF_HI_SHORT_SINGLE
	sll	t2, t1, 16
	beq	t0, t2, valueNanf	/* powf (1.0, +-Inf) = Nan */
	/* powf (1.0, ?) = 1.0 */
	mfc1    t0, fp12
	bltz	t0, notOnef
	mov.s   fp0, fp2                /* load return value */
        b       donePowf                /* else we are done */

notOnef:
	abs.s	fp2, fp12		/* |x| */
        mfc1    t0, fp2
        bne     t0, zero, notZerof      /* if |X| == 0 ? */
        mfc1    t0, fp14                /* load sign bit of dblY into t0 */
        sra     t2, t0, 31              /* dblY sign bit to t2 */
        bne     t2, zero, valueInff     /* dblY < 0? */
        mov.s   fp0, fp2		/* return +0.0 */
        b       donePowf
notZerof:
	mfc1    t0, fp12
        sra     t3, t0, 31              /* get sign bit of X */
        beq     t3, zero, positivef     /* if X > 0 */
	/* X is negatif */
	/* test if Y is +-Inf */
	mfc1	t0, fp14
        sra     t4, t0, 31              /* get sign bit of Y */
	sll	t1, t0, 1
	srl	t0, t1, 1
	li	t1, INF_HI_SHORT_SINGLE
	sll	t2, t1, 16
	bne	t0, t2, 6f
	li.s	fp2, -1.0 
	c.lt.s	fp12, fp2
	nop
	bc1t	4f
	c.eq.s	fp12, fp2
	nop
	bc1t	6f
	/* x < -1.0 */
	beq	t4, zero, 5f
	b	valueInff

4:	/* x > -1.0 */
	beq     t4, zero, valueInff
5:	li.s	fp0, 0.0 
	b       donePowf                /* else we are done */

6:	abs.s   fp12, fp12              /* get absolute value */
positivef:
        SW      t3, FRAMER0(powf)(sp)   /* save dblX sign bit */
        swc1    fp14, FRAMEA0(powf)(sp) /* save dblX to stack */
        jal     logf                    /* take log of dlbX */
        lwc1    fp14, FRAMEA0(powf)(sp) /* reload dlbX from stack */
        mul.s   fp12, fp14, fp0         /* dblY * log result */
        jal     expf                    /* exp (dblY * log result) */

        LW      t3, FRAMER0(powf)(sp)   /* restore dblX sign bit */
        beq     t3, 0, donePowf         /* if dblX > 0 */
        lwc1    fp14, FRAMEA1(powf)(sp)	/* reload dblY */
        cvt.w.s fp2, fp14               /* convert to integer */
        mfc1    v0, fp2                 /* integer part into v0 */
        cvt.s.w fp4, fp2                /* convert to double */
        c.eq.s  fp4, fp14               /* dblY == int(dblY)? */
        bc1f    valueNanf               /* if no, return NaN */
        and     v0, t3, v0              /* odd or even */
        andi    v0, v0, 1               /* dblY even */
        beq     v0, zero, donePowf
        neg.s   fp0, fp0                /* negative value */
        b       donePowf
valueInff:
        li      v0, INF_HI_SHORT_SINGLE /* set Inf return value */
        sll     v0, v0, 16
        mtc1    v0, fp0
        b       donePowf
valueNanf:
        li      v0, 0x7fff              /* set Nan return value */
        sll     v0, v0, 16
        mtc1    v0, fp0
donePowf:
        LW      ra, FRAMERA(powf)(sp)   /* restore ra */
        addiu   sp, FRAMESZ(powf)       /* deallocate stack */
        j       ra                      /* return to caller */
        .end    powf


/******************************************************************************
*
* isNaNSingle - 
*
* This routine takes an input single-precision floating point
* parameter, <sgl>, and returns TRUE if <sgl> contains an IEEE not
* a number value.
*
*
* BOOL isNaNSingle (sgl)
*     float	sgl;
*
* RETURNS: TRUE if <sgl> is NaN, else FALSE
*/
	.ent	isNaNSingle
isNaNSingle:
	mfc1	v0, fp12
	srl	v0, v0, 16 
	li	t0, INF_HI_SHORT_SINGLE
	andi	v0, v0, 0x7fff
	slt	v0, t0, v0
	j	ra
	.end	isNaNSingle

#endif	/* INCLUDE_SINGLE_PRECISION */


/*******************************************************************************
*
* c_abs - 
*
* NOMANUAL

* This entrypoint provided for FCOM for CABS (complex absolute value),
* because FCOM has a hard time calling FHYPOT directly.  Also used by
* FCOM when user writes INTRINSIC CABS.  The latter must use pass by
* reference, of course. 
*/
	.globl c_abs_
	.ent   c_abs_
c_abs_:
	.frame	sp, 0, ra
	l.s	$f12, 0(a0)
	l.s	$f14, 4(a0)
	/* just fall through */
	.end c_abs_

/*******************************************************************************
*
* swapINX - 
*
*/
	.globl swapINX
	.ent   swapINX
swapINX:
	.frame	sp, 0, ra
	cfc1	t0, $31
	sll	a0, 2
	and	v0, t0, 1<<2
	xor	t0, v0
	or	t0, a0
	ctc1	t0, $31
	srl	v0, 2
	j	ra
	.end swapINX

/*******************************************************************************
*
* swapRM - 
*
*/
	.globl swapRM
	.ent   swapRM
swapRM:
	.frame	sp, 0, ra
	cfc1	t0, $31
	and	v0, t0, 3
	xor	t0, v0
	or	t0, a0
	ctc1	t0, $31
	j	ra
	.end swapRM


#ifdef	INCLUDE_DOUBLE_PRECISION
/*******************************************************************************
*
* EXP_DAT - data for table driven approach to exp, expm1 
*
* NOMANUAL
*/

.rdata
	.align	3
EXP_DAT:.word	D(0x3FF00000,0x00000000), D(0x00000000,0x00000000)
	.word	D(0x3FF059B0,0xD3158540), D(0x3D0A1D73,0xE2A475B4)
	.word	D(0x3FF0B558,0x6CF98900), D(0x3CEEC531,0x7256E308)
	.word	D(0x3FF11301,0xD0125B40), D(0x3CF0A4EB,0xBF1AED93)
	.word	D(0x3FF172B8,0x3C7D5140), D(0x3D0D6E6F,0xBE462876)
	.word	D(0x3FF1D487,0x3168B980), D(0x3D053C02,0xDC0144C8)
	.word	D(0x3FF2387A,0x6E756200), D(0x3D0C3360,0xFD6D8E0B)
	.word	D(0x3FF29E9D,0xF51FDEC0), D(0x3D009612,0xE8AFAD12)
	.word	D(0x3FF306FE,0x0A31B700), D(0x3CF52DE8,0xD5A46306)
	.word	D(0x3FF371A7,0x373AA9C0), D(0x3CE54E28,0xAA05E8A9)
	.word	D(0x3FF3DEA6,0x4C123400), D(0x3D011ADA,0x0911F09F)
	.word	D(0x3FF44E08,0x60618900), D(0x3D068189,0xB7A04EF8)
	.word	D(0x3FF4BFDA,0xD5362A00), D(0x3D038EA1,0xCBD7F621)
	.word	D(0x3FF5342B,0x569D4F80), D(0x3CBDF0A8,0x3C49D86A)
	.word	D(0x3FF5AB07,0xDD485400), D(0x3D04AC64,0x980A8C8F)
	.word	D(0x3FF6247E,0xB03A5580), D(0x3CD2C7C3,0xE81BF4B7)
	.word	D(0x3FF6A09E,0x667F3BC0), D(0x3CE92116,0x5F626CDD)
	.word	D(0x3FF71F75,0xE8EC5F40), D(0x3D09EE91,0xB8797785)
	.word	D(0x3FF7A114,0x73EB0180), D(0x3CDB5F54,0x408FDB37)
	.word	D(0x3FF82589,0x994CCE00), D(0x3CF28ACF,0x88AFAB35)
	.word	D(0x3FF8ACE5,0x422AA0C0), D(0x3CFB5BA7,0xC55A192D)
	.word	D(0x3FF93737,0xB0CDC5C0), D(0x3D027A28,0x0E1F92A0)
	.word	D(0x3FF9C491,0x82A3F080), D(0x3CF01C7C,0x46B071F3)
	.word	D(0x3FFA5503,0xB23E2540), D(0x3CFC8B42,0x4491CAF8)
	.word	D(0x3FFAE89F,0x995AD380), D(0x3D06AF43,0x9A68BB99)
	.word	D(0x3FFB7F76,0xF2FB5E40), D(0x3CDBAA9E,0xC206AD4F)
	.word	D(0x3FFC199B,0xDD855280), D(0x3CFC2220,0xCB12A092)
	.word	D(0x3FFCB720,0xDCEF9040), D(0x3D048A81,0xE5E8F4A5)
	.word	D(0x3FFD5818,0xDCFBA480), D(0x3CDC9768,0x16BAD9B8)
	.word	D(0x3FFDFC97,0x337B9B40), D(0x3CFEB968,0xCAC39ED3)
	.word	D(0x3FFEA4AF,0xA2A490C0), D(0x3CF9858F,0x73A18F5E)
	.word	D(0x3FFF5076,0x5B6E4540), D(0x3C99D3E1,0x2DD8A18B)

/*******************************************************************************
*
* LOGC_TBL - data for table driven approach to log
*
* NOMANUAL
*/

	.align	3
LOGC_TBL:.word	D(0x00000000,0x00000000), D(0x00000000,0x00000000)
	.word	D(0x3F7FE02A,0x6B200000), D(0xBD6F30EE,0x07912DF9)
	.word	D(0x3F8FC0A8,0xB1000000), D(0xBD5FE0E1,0x83092C59)
	.word	D(0x3F97B91B,0x07D80000), D(0xBD62772A,0xB6C0559C)
	.word	D(0x3F9F829B,0x0E780000), D(0x3D298026,0x7C7E09E4)
	.word	D(0x3FA39E87,0xBA000000), D(0xBD642A05,0x6FEA4DFD)
	.word	D(0x3FA77458,0xF6340000), D(0xBD62303B,0x9CB0D5E1)
	.word	D(0x3FAB42DD,0x71180000), D(0x3D671BEC,0x28D14C7E)
	.word	D(0x3FAF0A30,0xC0100000), D(0x3D662A66,0x17CC9717)
	.word	D(0x3FB16536,0xEEA40000), D(0xBD60A3E2,0xF3B47D18)
	.word	D(0x3FB341D7,0x961C0000), D(0xBD4717B6,0xB33E44F8)
	.word	D(0x3FB51B07,0x3F060000), D(0x3D383F69,0x278E686A)
	.word	D(0x3FB6F0D2,0x8AE60000), D(0xBD62968C,0x836CC8C2)
	.word	D(0x3FB8C345,0xD6320000), D(0xBD5937C2,0x94D2F567)
	.word	D(0x3FBA926D,0x3A4A0000), D(0x3D6AAC6C,0xA17A4554)
	.word	D(0x3FBC5E54,0x8F5C0000), D(0xBD4C5E75,0x14F4083F)
	.word	D(0x3FBE2707,0x6E2A0000), D(0x3D6E5CBD,0x3D50FFFC)
	.word	D(0x3FBFEC91,0x31DC0000), D(0xBD354555,0xD1AE6607)
	.word	D(0x3FC0D77E,0x7CD10000), D(0xBD6C69A6,0x5A23A170)
	.word	D(0x3FC1B72A,0xD52F0000), D(0x3D69E80A,0x41811A39)
	.word	D(0x3FC29552,0xF8200000), D(0xBD35B967,0xF4471DFC)
	.word	D(0x3FC371FC,0x201F0000), D(0xBD6C22F1,0x0C9A4EA8)
	.word	D(0x3FC44D2B,0x6CCB0000), D(0x3D6F4799,0xF4F6543E)
	.word	D(0x3FC526E5,0xE3A20000), D(0xBD62F217,0x46FF8A47)
	.word	D(0x3FC5FF30,0x70A80000), D(0xBD6B0B0D,0xE3077D7E)
	.word	D(0x3FC6D60F,0xE71A0000), D(0xBD56F1B9,0x55C4D1DA)
	.word	D(0x3FC7AB89,0x02110000), D(0xBD537B72,0x0E4A694B)
	.word	D(0x3FC87FA0,0x65210000), D(0xBD5B77B7,0xEFFB7F41)
	.word	D(0x3FC9525A,0x9CF40000), D(0x3D65AD1D,0x904C1D4E)
	.word	D(0x3FCA23BC,0x1FE30000), D(0xBD62A739,0xB23B93E1)
	.word	D(0x3FCAF3C9,0x4E810000), D(0xBD600349,0xCC67F9B2)
	.word	D(0x3FCBC286,0x742E0000), D(0xBD6CCA75,0x818C5DBC)
	.word	D(0x3FCC8FF7,0xC79B0000), D(0xBD697794,0xF689F843)
	.word	D(0x3FCD5C21,0x6B500000), D(0xBD611BA9,0x1BBCA682)
	.word	D(0x3FCE2707,0x6E2B0000), D(0xBD3A342C,0x2AF0003C)
	.word	D(0x3FCEF0AD,0xCBDC0000), D(0x3D664D94,0x8637950E)
	.word	D(0x3FCFB918,0x6D5E0000), D(0x3D5F1546,0xAAA3361C)
	.word	D(0x3FD04025,0x94B50000), D(0xBD67DF92,0x8EC217A5)
	.word	D(0x3FD0A324,0xE2738000), D(0x3D50E35F,0x73F7A018)
	.word	D(0x3FD1058B,0xF9AE8000), D(0xBD6A9573,0xB02FAA5A)
	.word	D(0x3FD1675C,0xABAB8000), D(0x3D630701,0xCE63EAB9)
	.word	D(0x3FD1C898,0xC1698000), D(0x3D59FAFB,0xC68E7540)
	.word	D(0x3FD22941,0xFBCF8000), D(0xBD3A6976,0xF5EB0963)
	.word	D(0x3FD2895A,0x13DE8000), D(0x3D3A8D7A,0xD24C13F0)
	.word	D(0x3FD2E8E2,0xBAE10000), D(0x3D5D309C,0x2CC91A85)
	.word	D(0x3FD347DD,0x9A988000), D(0xBD25594D,0xD4C58092)
	.word	D(0x3FD3A64C,0x55698000), D(0xBD6D0B1C,0x68651946)
	.word	D(0x3FD40430,0x86868000), D(0x3D63F1DE,0x86093EFA)
	.word	D(0x3FD4618B,0xC21C8000), D(0xBD609EC1,0x7A426426)
	.word	D(0x3FD4BE5F,0x95778000), D(0xBD3D7C92,0xCD9AD824)
	.word	D(0x3FD51AAD,0x872E0000), D(0xBD3F4BD8,0xDB0A7CC1)
	.word	D(0x3FD57677,0x17458000), D(0xBD62C9D5,0xB2A49AF9)
	.word	D(0x3FD5D1BD,0xBF580000), D(0x3D4394A1,0x1B1C1EE4)
	.word	D(0x3FD62C82,0xF2BA0000), D(0xBD6C3568,0x48506EAD)
	.word	D(0x3FD686C8,0x1E9B0000), D(0x3D54AEC4,0x42BE1015)
	.word	D(0x3FD6E08E,0xAA2B8000), D(0x3D60F1C6,0x09C98C6C)
	.word	D(0x3FD739D7,0xF6BC0000), D(0xBD67FCB1,0x8ED9D603)
	.word	D(0x3FD792A5,0x5FDD8000), D(0xBD6C2EC1,0xF512DC03)
	.word	D(0x3FD7EAF8,0x3B828000), D(0x3D67E1B2,0x59D2F3DA)
	.word	D(0x3FD842D1,0xDA1E8000), D(0x3D462E92,0x7628CBC2)
	.word	D(0x3FD89A33,0x86C18000), D(0xBD6ED2A5,0x2C73BF78)
	.word	D(0x3FD8F11E,0x87368000), D(0xBD5D3881,0xE8962A96)
	.word	D(0x3FD94794,0x1C210000), D(0x3D56FABA,0x4CDD147D)
	.word	D(0x3FD99D95,0x81180000), D(0xBD5F7534,0x56D113B8)
	.word	D(0x3FD9F323,0xECBF8000), D(0x3D584BF2,0xB68D766F)
	.word	D(0x3FDA4840,0x90E58000), D(0x3D6D8515,0xFE535B87)
	.word	D(0x3FDA9CEC,0x9A9A0000), D(0x3D40931A,0x909FEA5E)
	.word	D(0x3FDAF129,0x32478000), D(0xBD3E53BB,0x31EED7A9)
	.word	D(0x3FDB44F7,0x7BCC8000), D(0x3D4EC519,0x7DDB55D3)
	.word	D(0x3FDB9858,0x96930000), D(0x3D50FB59,0x8FB14F89)
	.word	D(0x3FDBEB4D,0x9DA70000), D(0x3D5B7BF7,0x861D37AC)
	.word	D(0x3FDC3DD7,0xA7CD8000), D(0x3D66A6B9,0xD9E0A5BD)
	.word	D(0x3FDC8FF7,0xC79A8000), D(0x3D5A21AC,0x25D81EF3)
	.word	D(0x3FDCE1AF,0x0B860000), D(0xBD482909,0x05A86AA6)
	.word	D(0x3FDD32FE,0x7E010000), D(0xBD542A9E,0x21373414)
	.word	D(0x3FDD83E7,0x258A0000), D(0x3D679F28,0x28ADD176)
	.word	D(0x3FDDD46A,0x04C20000), D(0xBD6DAFA0,0x8CECADB1)
	.word	D(0x3FDE2488,0x1A7C8000), D(0xBD53D9E3,0x4270BA6B)
	.word	D(0x3FDE7442,0x61D68000), D(0x3D3E1F8D,0xF68DBCF3)
	.word	D(0x3FDEC399,0xD2468000), D(0x3D49802E,0xB9DCA7E7)
	.word	D(0x3FDF128F,0x5FAF0000), D(0x3D3BB2CD,0x720EC44C)
	.word	D(0x3FDF6123,0xFA700000), D(0x3D645630,0xA2B61E5B)
	.word	D(0x3FDFAF58,0x8F790000), D(0xBD49C24C,0xA098362B)
	.word	D(0x3FDFFD2E,0x08580000), D(0xBD46CF54,0xD05F9367)
	.word	D(0x3FE02552,0xA5A5C000), D(0x3D60FEC6,0x9C695D7F)
	.word	D(0x3FE04BDF,0x9DA94000), D(0xBD692D9A,0x033EFF75)
	.word	D(0x3FE0723E,0x5C1CC000), D(0x3D6F404E,0x57963891)
	.word	D(0x3FE0986F,0x4F574000), D(0xBD55BE8D,0xC04AD601)
	.word	D(0x3FE0BE72,0xE4254000), D(0xBD657D49,0x676844CC)
	.word	D(0x3FE0E449,0x85D1C000), D(0x3D5917ED,0xD5CBBD2D)
	.word	D(0x3FE109F3,0x9E2D4000), D(0x3D592DFB,0xC7D93617)
	.word	D(0x3FE12F71,0x95940000), D(0xBD6043AC,0xFEDCE638)
	.word	D(0x3FE154C3,0xD2F4C000), D(0x3D65E9A9,0x8F33A396)
	.word	D(0x3FE179EA,0xBBD88000), D(0x3D69A0BF,0xC60E6FA0)
	.word	D(0x3FE19EE6,0xB467C000), D(0x3D52DD98,0xB97BAEF0)
	.word	D(0x3FE1C3B8,0x1F714000), D(0xBD3EDA1B,0x58389902)
	.word	D(0x3FE1E85F,0x5E704000), D(0x3D1A07BD,0x8B34BE7C)
	.word	D(0x3FE20CDC,0xD192C000), D(0xBD64926C,0xAFC2F08A)
	.word	D(0x3FE23130,0xD7BEC000), D(0xBD17AFA4,0x392F1BA7)
	.word	D(0x3FE2555B,0xCE990000), D(0xBD506987,0xF78A4A5E)
	.word	D(0x3FE2795E,0x1289C000), D(0xBD5DCA29,0x0F81848D)
	.word	D(0x3FE29D37,0xFEC2C000), D(0xBD5EEA6F,0x465268B4)
	.word	D(0x3FE2C0E9,0xED448000), D(0x3D5D1772,0xF5386374)
	.word	D(0x3FE2E474,0x36E40000), D(0x3D334202,0xA10C3491)
	.word	D(0x3FE307D7,0x334F0000), D(0x3D60BE1F,0xB590A1F5)
	.word	D(0x3FE32B13,0x39120000), D(0x3D6D7132,0x0556B67B)
	.word	D(0x3FE34E28,0x9D9D0000), D(0xBD6E2CE9,0x146D277A)
	.word	D(0x3FE37117,0xB5474000), D(0x3D4ED717,0x74092113)
	.word	D(0x3FE393E0,0xD3564000), D(0xBD65E656,0x3BBD9FC9)
	.word	D(0x3FE3B684,0x4A000000), D(0xBD3EEA83,0x8909F3D3)
	.word	D(0x3FE3D902,0x6A714000), D(0x3D66FAA4,0x04263D0B)
	.word	D(0x3FE3FB5B,0x84D18000), D(0xBD60BDA4,0xB162AFA3)
	.word	D(0x3FE41D8F,0xE8468000), D(0xBD5AA337,0x36867A17)
	.word	D(0x3FE43F9F,0xE2F9C000), D(0x3D5CCEF4,0xE4F736C2)
	.word	D(0x3FE4618B,0xC21C4000), D(0x3D6EC27D,0x0B7B37B3)
	.word	D(0x3FE48353,0xD1EA8000), D(0x3D51BEE7,0xABD17660)
	.word	D(0x3FE4A4F8,0x5DB04000), D(0xBD244FDD,0x840B8591)
	.word	D(0x3FE4C679,0xAFCD0000), D(0xBD61C64E,0x971322CE)
	.word	D(0x3FE4E7D8,0x11B74000), D(0x3D6BB09C,0xB0985646)
	.word	D(0x3FE50913,0xCC018000), D(0xBD6794B4,0x34C5A4F5)
	.word	D(0x3FE52A2D,0x265BC000), D(0x3D46ABB9,0xDF22BC57)
	.word	D(0x3FE54B24,0x67998000), D(0x3D6497A9,0x15428B44)
	.word	D(0x3FE56BF9,0xD5B40000), D(0xBD58CD7D,0xC73BD194)
	.word	D(0x3FE58CAD,0xB5CD8000), D(0xBD49DB3D,0xB43689B4)
	.word	D(0x3FE5AD40,0x4C358000), D(0x3D6F2CFB,0x29AAA5F0)
	.word	D(0x3FE5CDB1,0xDC6C0000), D(0x3D67648C,0xF6E3C5D7)
	.word	D(0x3FE5EE02,0xA9240000), D(0x3D667570,0xD6095FD2)
	.word	D(0x3FE60E32,0xF4478000), D(0x3D51B194,0xF912B417)
	.word	D(0x3FE62E42,0xFEFA4000), D(0xBD48432A,0x1B0E2634)

#endif	/* INCLUDE_DOUBLE_PRECISION */


#ifdef	INCLUDE_SINGLE_PRECISION
/*******************************************************************************
*
* EXPF_DAT - data for table driven approach to expf
*
* NOMANUAL
*/

.rdata
	.align	3
EXPF_DAT:.word  0x3f800000,0x00000000
        .word   0x3f82cd87,0x2850eb9f
        .word   0x3f85aac3,0x2776298c
        .word   0x3f88980e,0x2785275e
        .word   0x3f8b95c2,0x286b737e
        .word   0x3f8ea43a,0x2829e017
        .word   0x3f91c3d3,0x28619b08
        .word   0x3f94f4f0,0x2804b097
        .word   0x3f9837f0,0x27a96f47
        .word   0x3f9b8d3a,0x272a7145
        .word   0x3f9ef532,0x2808d6d0
        .word   0x3fa27043,0x28340c4e
        .word   0x3fa5fed7,0x281c750e
        .word   0x3fa9a15b,0x25ef8542
        .word   0x3fad583f,0x28256325
        .word   0x3fb123f6,0x26963e1f
        .word   0x3fb504f3,0x274908b3
        .word   0x3fb8fbaf,0x284f748e
        .word   0x3fbd08a4,0x26dafaa2
        .word   0x3fc12c4d,0x2794567c
        .word   0x3fc5672a,0x27dadd3e
        .word   0x3fc9b9be,0x2813d140
        .word   0x3fce248c,0x2780e3e2
        .word   0x3fd2a81e,0x27e45a12
        .word   0x3fd744fd,0x28357a1d
        .word   0x3fdbfbb8,0x26dd54f6
        .word   0x3fe0ccdf,0x27e11106
        .word   0x3fe5b907,0x2824540f
        .word   0x3feac0c7,0x26e4bb41
        .word   0x3fefe4ba,0x27f5cb46
        .word   0x3ff5257d,0x27cc2c7c
        .word   0x3ffa83b3,0x24ce9f09

/*******************************************************************************
*
* local_sqrttable - data for table driven approach to sqrt
*
* NOMANUAL
*/

local_sqrttable:
	.word 83599<<3
	.word 71378<<3
	.word 60428<<3
	.word 50647<<3
	.word 41945<<3
	.word 34246<<3
	.word 27478<<3
	.word 21581<<3
	.word 16499<<3
	.word 12183<<3
	.word 8588<<3
	.word 5674<<3
	.word 3403<<3
	.word 1742<<3
	.word 661<<3
	.word 130<<3
	.word 0<<3
	.word 1204<<3
	.word 3062<<3
	.word 5746<<3
	.word 9193<<3
	.word 13348<<3
	.word 18162<<3
	.word 23592<<3
	.word 29598<<3
	.word 36145<<3
	.word 43202<<3
	.word 50740<<3
	.word 58733<<3
	.word 67158<<3
	.word 75992<<3
	.word 85215<<3

#endif	/* INCLUDE_SINGLE_PRECISION */

	.globl _sqrttable
_sqrttable:
	.word 83599
	.word 71378
	.word 60428
	.word 50647
	.word 41945
	.word 34246
	.word 27478
	.word 21581
	.word 16499
	.word 12183
	.word 8588
	.word 5674
	.word 3403
	.word 1742
	.word 661
	.word 130
	.word 0
	.word 1204
	.word 3062
	.word 5746
	.word 9193
	.word 13348
	.word 18162
	.word 23592
	.word 29598
	.word 36145
	.word 43202
	.word 50740
	.word 58733
	.word 67158
	.word 75992
	.word 85215

#endif	/* PORTABLE_MATHLIB */
