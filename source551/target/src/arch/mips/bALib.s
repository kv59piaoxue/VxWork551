/* bALib.s - buffer manipulation library assembly language routines */

/* Copyright 1984-2001 Wind River Systems, Inc. */
	.data


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
02t,24jan02,agf  Remove copyright notice variable
02s,02aug01,mem  Diab integration
02r,16jul01,ros  add CofE comment
02q,07jun01,dxc  Get rid of extra nop, fix bfillBytes to handle nbytes < 1
02p,07aug00,dra  replace sd instruction for 5476
02o,18jan99,dra  added VR4100, VR5000 and VR5400 support.
02p,18mar98,kkk  fixed typo in bfill, introduced in 02o.
02o,30may97,kkk  fixed bug in Bkwd.
02n,20nov96,kkk  fixed bfill() (spr# 7498)
02m,14oct96,kkk  added R4650 support.
02l,04oct95,cd   fixed bug in R4000 aligned bcopy where too many bytes
		 were copied if 10<=len<16
02k,15dec94,cd   made endianess independent
		 use 64 bit operations if available
02j,19oct93,cd   enabled these routines for all MIPS processors. 
02k,17oct94,rhp  mark library explicitly NOMANUAL
02j,17oct94,rhp  delete obsolete doc references to strLib, spr#3712
02i,08aug92,kdl  changed cpu symbol from MIPS_R3000 to R3000.
02h,26may92,rrr  the tree shuffle
02g,15oct91,ajm  pulled in optimizations
02f,04oct91,rrr  passed through the ansification filter
		  -fixed #else and #endif
		  -changed VOID to void
		  -changed ASMLANGUAGE to _ASMLANGUAGE
		  -changed copyright notice
02e,01oct91,ajm   bcopyLongs, bcopyWords check for zero, and odd aligned boundries
		   correctly optimized with partial word instructions (lwl, lwr, swl, swr)
02d,22aug91,ajm   fixed bcopyBytes
02c,12sep90,ajm   fixed word count on bcopyWord, also word count on bcopyLongs
		  fixed unaligned bfill
02b,09sep90,ajm   changed address compares from ble to bleu, bgt to bgtu
		  changed cFwdm2 "lwl t4, 3(a0)", to "lwl t4, 0(a0)"
		  changed cFwdm2 "lwr t4, 0(a0)", to "lwl t4, 3(a0)"
		  fixed unaligned bcopy backwards
02a,09apr90,dcb   replaced 680x0 with MIPS asm code
01o,10feb89,jcf   added bcopyWords (), and bcopyLongs ().
01n,30aug88,gae   more documentation tweaks.
01m,20aug88,gae   documentation.
01l,22jun88,dnw   changed bcopy() and bcopyBytes() to handle overlapping buffers
		    correctly, and deleted bmove() and bmoveBytes().
01k,05jun88,dnw   changed from bufALib to bALib.
01j,30may88,dnw   changed to v4 names.
01i,13feb88,dnw   added .data before .asciz above, for Intermetrics assembler.
01h,05nov87,jlf   documentation
01g,24mar87,jlf   documentation
01f,21dec86,dnw   changed to not get include files from default directories.
01e,31oct86,dnw   Eliminated magic f/b numeric labels which mitToMot can't
		    handle.
		  Changed "moveml" instructions to use Motorola style register
		    lists, which are now handled by "aspp".
		  Changed "mov[bwl]" to "move[bwl]" for compatiblity w/Sun as.
01d,26mar86,dnw   Fixed bugs introduced in 01c w/ not saving enough regs.
01c,18mar86,dnw   Added cpybytes, filbytes, and movbytes.
		  More optimizations.
		  Fixed documentation.
		  Fixed bug in movbuf.
01b,18sep85,jlf   Made cpybuf, filbuf, and movbuf work properly
		      with 0 length strings.
01a,17jul85,jlf   Written, by modifying bufLib.c, v01h.
*/

/*
DESCRIPTION
This library contains routines to manipulate buffers, which are just
variable length byte arrays.  These routines are highly optimized.
Operations are performed on long words where possible, even though the
buffer lengths are specified in terms of bytes.
This particular optimization will only occur if source and
destination buffers are aligned such that either both start on an
odd address, or both start at an even address.  If one is even and one is odd,
operations must be done a byte at a time (because of alignment problems
inherent in the MC68000) and the process will be slower.

Certain applications, such as byte-wide memory-mapped peripherals,
may require that only byte operations be performed.  For this purpose,
the routines bcopyBytes and bfillBytes provide the same functions
as bcopy and bfill but only using byte at a time operations.

These routines do not check for null termination.

NOMANUAL

SEE ALSO: bLib, ansiString
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

/* optimized version available for MIPS architecture */

#if defined(PORTABLE)
#define bALib_PORTABLE
#endif

#ifndef	bALib_PORTABLE

	/* exports */

	.globl	bcopy
	.globl	bcopyBytes
	.globl	bcopyWords
	.globl	bcopyLongs
	.globl	bfill
	.globl	bfillBytes

	.text
	.set	reorder


/*******************************************************************************
*
* bcopy - copy one buffer to another
*
* This routine copies the first `nbytes' characters from
* `source' to `destination'.  Overlapping buffers are handled correctly.
* The copy is optimized by copying 4 bytes (or 8 bytes on 64 bit processors)
* at a time if possible, (see bcopyBytes (2) for copying a byte at a time only).
*
* SEE ALSO: bcopyBytes (2)
*
* NOMANUAL - manual entry in bLib (1)

* void bcopy (source, destination, nbytes)
*     char *source;       /* pointer to source buffer      *
*     char *destination;  /* pointer to destination buffer *
*     int nbytes;         /* number of bytes to copy       *

*/

#if (_WRS_INT_REGISTER_SIZE == 8)
#define L	ld
#define LL	ldl
#define LR	ldr
#define S	sd
#define SL	sdl
#define SR	sdr
#define SLL	dsll
#define RS	8
#define RSLOG2  3
#else
#define L	lw
#define LL	lwl
#define LR	lwr
#define S	sw
#define SL	swl
#define SR	swr
#define RS	4
#define SLL	sll
#define RSLOG2  2
#endif
	
#if (_BYTE_ORDER == _LITTLE_ENDIAN)
#define	LHI	LR
#define	LLO	LL
#define	SHI	SR
#define	SLO	SL
#elif  (_BYTE_ORDER == _BIG_ENDIAN)
#define	LHI	LL
#define	LLO	LR
#define	SHI	SL
#define	SLO	SR
#else
#error "bad byte order"
#endif

	.ent	bcopy
bcopy:
	.set	noreorder
	subu	v0,a1,a0		/* temp = dest - source	*/
	blez	v0,Fwd			/* copy forward		*/
	.set	noat
	slt	AT,v0,a2	 	/* compare temp and dest */
	bne	AT,zero,Bkwd		/* copy backwards	*/
	move	v0,a1			/* BDS: dstend = destination */
Fwd:
	slti	AT,a2,2*RS+2		/* nbytes < 2 * width + pad? */
	bne	AT,zero,bcopyfwd	/* bytecopy forward	*/
	.set	at
	addu	v0,a1,a2		/* create destend 	*/
	xor	t6,a1,a0		/* dest xor source	*/
	andi	t7,t6,RS-1		/* check alignment	*/
	bne	t7,zero,bcopyfwd1	/* both unaligned, bytecopy */
	.set	noat
	sltu	AT,a1,v0		/* compare destend and
					   dest in delay slot*/
	.set	at
	andi	t8,a1,RS-1		/* compare byte alignment */
	beq	t8,zero,aligned		/* are bytes aligned	*/
	move	v1,a0			/* copy src in delay slot*/
oddalgn:
	lbu	t9,0(a0)		/* odd aligned copy byte*/
	addiu	a1,a1,1			/* increment dest ptr	*/
	andi	t0,a1,RS-1		/* check if not aligned */
	addiu	a0,a0,1			/* increment source ptr	*/

	bne	t0,zero,oddalgn		/* still odd aligned?  	*/
	sb	t9,-1(a1)		/* store byte		*/
	move	v1,a0			/* v1 = src (long) ptr  */
aligned:
	move	t4,a1			/* t4 = dst (long) ptr  */
	addiu	a3,v0,-RS		/* destend - width	*/
lcopy:
	L	t1,0(v1)		/* DO copy longs	*/
	addu	t4,RS			/* bump long ptr dst	*/
	.set	noat
	sltu	AT,a3,t4		/* compare dest with destend */
	addu	v1,RS			/* bump long ptr src	*/
	beq	AT,zero,lcopy		/* WHILE dst < dstend	*/
	.set	at
	S	t1,-RS(t4)		/* store it in delay slot */
	move	a1,t4			/* restore destination ptr*/
	move	a0,v1			/* restore source pointer */
	.set	noat
	sltu	AT,a1,v0		/* is dest < dstend */
	beq	AT,zero,cEnd		/* if not we are done */
	nop
	.set	at
wordTail:				/* while dest < destend	*/
	addiu	a1,a1,1			/* advance the dest pointer*/
	lbu	t2,0(a0)		/* load a byte frm source */
	.set	noat
	sltu	AT,a1,v0 		/* check for destend	*/
	addiu	a0,a0,1			/* advance the source ptr*/
	bne	AT,zero,wordTail	/* loop to bloop	*/
	.set	at
	sb	t2,-1(a1)
	j	ra			/* over and out */
	nop

	.set	noat
bcopyfwd:
	sltu	AT,a1,v0		/* is dest < dstend */
bcopyfwd1:
	beq	AT,zero,cEnd		/* if not we are done */
	nop
	.set	at
	/* optimization for byte unaligned transfers */
byteOptFwd:
	sltu	t0, a2, RS		/* compare with width bytes */
	bne	zero, t0, bloop		/* less than width then do by byte */
	srl	t1, a2, RSLOG2		/* bytes div width */
bOptFwdLoop:
	LHI	t0, 0(a0)		/* read first part */
	LLO	t0, RS-1(a0)		/* read second part */
	addiu	a0, RS			/* advance the source pointer */
	SHI	t0, 0(a1)		/* store first part */
	subu	t1, 1			/* decrement word counter */
	SLO	t0, RS-1(a1)		/* store second part */
	bne	zero, t1, bOptFwdLoop	/* are we done ? */
	addiu	a1, RS			/* advance the destination pointer */
	.set	noat
	sltu	AT,a1,v0 		/* check for destend	*/
	beq	AT,zero,bEnd		/* are we done ? */
	nop
	.set	at
bloop:					/* while dest < destend	*/
	addiu	a1,a1,1			/* advance the dest pointer*/
	lbu	t2,0(a0)		/* load a byte frm source */
	.set	noat
	sltu	AT,a1,v0 		/* check for destend	*/
	addiu	a0,a0,1			/* advance the source ptr*/
	bne	AT,zero,bloop		/* loop to bloop	*/
	.set	at
	sb	t2,-1(a1)
bEnd:
	j	ra			/* over and out */
	nop
Bkwd:
	addu	a1,a1,a2		/* dest = dest + nbytes	*/
	addu	a0,a0,a2		/* source = source+ nbytes*/
	.set	noat
	slti	AT,a2,2*RS+2		/* nbytes < 2 * width + pad ?	*/
	addiu	a1,a1,-1		/* bump back dest ptr	*/
	bne	AT,zero,bcbwd		/* byte copy backward?	*/
	addiu	a0,a0,-1		/* bump back source ptr	*/
	xor	t3,a1,a0		/* dest xor source	*/
	andi	t4,t3,RS-1		/* check alignment	*/
	bne	t4,zero,bcbwd1		/* bytes copy backward	*/
	sltu	AT,a1,v0		/* check for end in delay slot */
	.set	at
	andi	t5,a1,RS-1		/* check for alignment  */
	beq	t5,zero,baligned	/*     we're aligned?	*/
	move	v1,a0			/* v1 gets src in delay slot */
boddalgn:
	lbu	t6,0(a0)		/* odd aligned copy bytes */
	addiu	a1,a1,-1		/* back up dest ptr	*/
	andi	t7,a1,RS-1		/* check if not aligned	*/
	addiu	a0,a0,-1		/* back up source ptr	*/
	bne	t7,zero,boddalgn	/* still not aligned	*/
	sb	t6,1(a1)		/* store byte		*/
	move	v1,a0			/* v1 = src(long)ptr	*/
baligned:                  		/* now we're aligned	*/
	move	a2,a1			/* a2 = dst(long)ptr	*/
blcopy:
	L	t8,0(v1)		/* load */
	addiu	a2,a2,-RS		/* decrement dst */
	.set	noat
	sltu	AT,a2,v0		/* compare dst and dstend */
	addiu	v1,v1,-RS		/* decrement src */
	beq	AT,zero,blcopy		/* are we done ? */
	.set at
	S	t8,RS(a2)		/* store in delay slot */
	addiu	a1,a2,RS		/* destination = dst + width */
	addiu	a0,v1,RS		/* source = src + width */
	.set noat
	sltu	AT,a1,v0		/* is  dest < destend   */
	bne	AT,zero,cEnd		/* if so we are done    */
	nop
	.set at
wordtailbwd:
	addiu	a1,a1,-1		/* back up dest ptr	*/
	lbu	t9,0(a0)		/* load a byte 		*/
	.set	noat
	sltu	AT,a1,v0		/* check for done ?	*/
	addiu	a0,a0,-1		/* back up source ptr 	*/
	beq	AT,zero,wordtailbwd	/* one more time? 	*/
	.set	at
	sb	t9,1(a1)		/* store in delay slot	*/
	j	ra			/* over and out		*/
	nop


	.set noat
bcbwd:
	sltu	AT,a1,v0		/* compare dest and destend */
bcbwd1:
	bne	AT,zero,cEnd		/* are we done ? */
	nop
	.set at


byteOptBwd:
	sltu	t0, a2, RS 		/* compare with width bytes */
	bne	zero, t0, bloopbwd	/* less than width, do bytes */
	srl	t1, a2, RSLOG2		/* bytes div width */
	addu	a0, a0, 1		/* one beyond last source byte */
	addu	a1, a1, 1		/* one beyond last dest byte */
bOptBwdLoop:
	addu	a0, a0,-RS		/* decrement source word pointer */
	LHI	t0, 0(a0)		/* read first part */
	addu	a1, a1,-RS		/* decrement dest word pointer */
	LLO	t0, RS-1(a0)		/* read second part */
	subu	t1, 1			/* decrement word counter */
	SHI	t0, 0(a1)		/* store first part */
	bne	zero, t1, bOptBwdLoop	/* are we done ? */
	SLO	t0, RS-1(a1)		/* store second part */
	.set noat
	sltu	AT,a1,v0		/* compare dest and destend */
	bne	AT,zero,cEnd 		/* are we done ? */
	nop
	.set at
bloopbwd:
	addiu	a1,a1,-1		/* back up dest ptr	*/
	lbu	t9,0(a0)		/* load a byte 		*/
	.set	noat
	sltu	AT,a1,v0		/* check for done ?	*/
	addiu	a0,a0,-1		/* back up source ptr 	*/
	beq	AT,zero,bloopbwd	/* one more time? 	*/
	.set	at
	sb	t9,1(a1)		/* store in delay slot	*/
cEnd:
	j	ra			/* over and out */
	nop
	.set	reorder
	.end	bcopy

/*******************************************************************************
*
* bcopyBytes - copy one buffer to another a byte at a time
*
* This routine copies the first `nbytes' characters from
* `source' to `destination'.
* It is identical to bcopy except that the copy is always performed
* a byte at a time.  This may be desirable if one of the buffers
* can only be accessed with byte instructions, as in certain byte-wide
* memory-mapped peripherals.
*
* SEE ALSO: bcopy (2)
*
* NOMANUAL - manual entry in bLib (1)

* void bcopyBytes (source, destination, nbytes)
*     char *source;       /* pointer to source buffer      *
*     char *destination;  /* pointer to destination buffer *
*     int nbytes;         /* number of bytes to copy       *

*/


	.ent	bcopyBytes
bcopyBytes:

	/* Find out if there is an overlap problem.
	 * We have to copy backwards if destination lies within source,
	 * i.e. ((destination - source) > 0 && < nbytes) */

	blez	a2, cbEnd		/* optimize first while */
	subu	t3, a1, a0		/* destination - source */
	blez	t3, cbFwd		/* <= 0 means copy forward */
	bltu	t3, a2, cbBak		/* < nbytes means copy backwards */

	/* Copy the whole thing forward, byte by byte */
cbFwd:
	addu	a3, a2, a1		/* add bytes + destination */
cbFwdLoop:
	lbu	t4, 0(a0)		/* load source byte */
	sb	t4, 0(a1)		/* store dest byte */
	addiu	a0, a0, 1		/* bump source pointer */
	addiu	a1, a1, 1		/* bump dest pointer */
	sltu	t0, a1, a3		/* compare destination and end */
	bne	t0, zero, cbFwdLoop	/* done? */
	j	ra			/* return */

	/* Copy the whole thing backward, byte by byte */
cbBak:
	move	a3, a1			/* copy destination to a3 */
	addu	a1, a1, a2		/* point to end of dest */
	addu	a0, a0, a2		/* point to end of source */
	addiu	a0, a0, -1		/* adjust to last source byte */
	addiu	a1, a1, -1		/* adjust to last dest byte */
cbBak1:
	lbu	t4, 0(a0)		/* load source byte */
	sb	t4, 0(a1)		/* store dest byte */
	addiu	a0, a0, -1		/* decrement source pointer */
	addiu	a1, a1, -1		/* decrement dest pointer */
	subu	t0, a1, a3		/* t0 <-- (destination - end) */
	bgez	t0, cbBak1		/* done? */
cbEnd:
	j	ra			/* return */

	.end	bcopyBytes


/*******************************************************************************
*	!!!!!!! in this context bcopyWords refers to 2 byte entities !!!!!!
* bcopyWords - copy one buffer to another a word at a time
*
* This routine copies the first `nwords' characters from
* `source' to `destination'.
* It is similar to bcopy except that the copy is always performed
* a word at a time.  This may be desirable if one of the buffers
* can only be accessed with word instructions, as in certain word-wide
* memory-mapped peripherals.  The source and destination must be word-aligned.
*
* SEE ALSO: bcopy (2)
*
* NOMANUAL - manual entry in bLib (1)

* void bcopyWords (source, destination, nwords)
*     char *source;       /* pointer to source buffer      *
*     char *destination;  /* pointer to destination buffer *
*     int nwords;         /* number of words to copy       *

*/


	.ent	bcopyWords
bcopyWords:

	/* Find out if there is an overlap problem.
	 * We have to copy backwards if destination lies within source,
	 * i.e. ((destination - source) > 0 && < nbytes) */

	blez	a2, cwEnd		/* do we have at least one */
	move	t2,a2			/* save half word count */
	sll	t4,a2,1			/* convert to bytes */
	subu	t3, a1, a0		/* destination - source */
	blez	t3,cwFwd		/* <= 0 means copy forward */
	bltu	t3,t4,cwBak		/* < nbytes means copy backwards */


	/* Copy the whole thing forward, 2 byte by 2 byte */
cwFwd:
	lh 	t4,0(a0)		/* load source 2 byte */
	sh	t4,0(a1)		/* store dest 2 byte */
	addiu	a0,a0,2			/* bump source pointer */
	addiu	a1,a1,2			/* bump dest pointer */
	addiu	t2,t2,-1		/* decrement counter */
	bne	t2,zero,cwFwd		/* done? */
	j	ra			/* return */

	/* Copy the whole thing backward, 2 byte by 2 byte */
cwBak:
	sll	t3, t2, 1		/* convert half to bytes */
	addu	a0,a0,t3		/* point to end of source */
	addu	a1,a1,t3		/* point to end of dest */
	addiu	a0,a0,-2		/* adjust to last source byte */
	addiu	a1,a1,-2		/* adjust to last dest byte */
cwBak1:
	lh 	t4,0(a0)		/* load source 2 byte */
	sh	t4,0(a1)		/* store dest 2 byte */
	addiu	a0,a0,-2		/* decrement source pointer */
	addiu	a1,a1,-2		/* decrement dest pointer */
	addiu	t2,t2,-1		/* decrement counter */
	bne	t2,zero,cwBak1		/* done? */
cwEnd:
	j	ra			/* return */

	.end	bcopyWords

/*******************************************************************************
*	!!!!!!!! in this context longs refers to 4 byte quantities !!!!!!!!
* bcopyLongs - copy one buffer to another a long at a time
*
* This routine copies the first `nlongs' characters from
* `source' to `destination'.
* It is similar to bcopy except that the copy is always performed
* a long at a time.  This may be desirable if one of the buffers
* can only be accessed with long instructions, as in certain long-wide
* memory-mapped peripherals.  The source and destination must be long-aligned.
*
* SEE ALSO: bcopy (2)
*
* NOMANUAL - manual entry in bLib (1)

* void bcopyLongs (source, destination, nlongs)
*     char *source;       /* pointer to source buffer      *
*     char *destination;  /* pointer to destination buffer *
*     int nlongs;         /* number of longs to copy       *

*/


	.ent	bcopyLongs
bcopyLongs:

	/* Find out if there is an overlap problem.
	 * We have to copy backwards if destination lies within source,
	 * i.e. ((destination - source) > 0 && < nbytes) */

	blez	a2, clEnd		/* do we have at least one */
	move	t2,a2			/* save long word count */
	sll	t4,a2,2			/* convert to bytes */
	subu	t3, a1, a0		/* destination - source */
	blez	t3,clFwd		/* <= 0 means copy forward */
	bltu	t3,t4,clBak		/* < nbytes means copy backwards */


	/* Copy the whole thing forward, word by word */
clFwd:
	lw	t4,0(a0)		/* load source word */
	sw	t4,0(a1)		/* store dest word */
	addiu	a0,a0,4			/* bump source pointer */
	addiu	a1,a1,4			/* bump dest pointer */
	addiu	t2,t2,-1		/* decrement counter */
	bne	t2,zero,clFwd		/* done? */
	j	ra			/* return */

	/* Copy the whole thing backward, word by word */
clBak:
	sll	t3, t2, 2		/* convert word to bytes */
	addu	a0,a0,t3		/* point to end of source */
	addu	a1,a1,t3		/* point to end of dest */
	addiu	a0,a0,-4		/* adjust to last source byte */
	addiu	a1,a1,-4		/* adjust to last dest byte */
clBak1:
	lw	t4,0(a0)		/* load source word */
	sw	t4,0(a1)		/* store dest word */
	addiu	a0,a0,-4		/* decrement source pointer */
	addiu	a1,a1,-4		/* decrement dest pointer */
	addiu	t2,t2,-1		/* decrement counter */
	bne	t2,zero,clBak1		/* done? */
clEnd:
	j	ra			/* return */

	.end	bcopyLongs

/*******************************************************************************
*
* bfill - fill buffer with character
*
* This routine fills the first `nbytes' characters of the specified buffer
* with the specified character.
* The fill is optimized by filling 4 bytes at a time if possible,
* (see bfillBytes (2) for filling a byte at a time only).
*
* SEE ALSO: bfillBytes (2)
*
* NOMANUAL - manual entry in bLib (1)

* void bfill (buf, nbytes, ch)
*     char *buf;		/* pointer to buffer              *
*     int nbytes;		/* number of bytes to fill        *
*     char ch;			/* char with which to fill buffer *

*/

	.ent	bfill
bfill:
	beq	zero, a1, bFild		/* take care of no byte copy */
	addiu	t4,a1,-(2*RS+2)		/* nbytes < 2 * width + pad */
	bltz	t4,bFilb

	/* propogate byte across word */
	and 	a2,0xff
	SLL	t3,a2,8			/* move to bits 8-15 */
	or	t3,a2			/* combine with 0-7 */
	SLL	t1,t3,16		/* move result to 16-31 */
	or	t3,t1			/* combine again */
#if (_WRS_INT_REGISTER_SIZE == 8)
	dsll32	t1,t3,0			/* move to bits 32-64 */
	or	t3,t1			/* combine again */
#endif
	and	t0,a0,RS-1		/* pointer offset */
	beq	t0,zero,bFil1		/* start on word boundry */
	SHI	t3,0(a0)		/* store partial word */
	li	t4,RS			/* set to compute bytes moved */
	subu	t4,t0			/* width - ptr mod width = # bytes moved */
	addu	a0,t4			/* update pointer */
	subu	a1,t4			/*   and counter */
bFil1:
	and 	t2,a1,RS-1		/* count modulo n */
	srl	a3,a1,RSLOG2		/* byte count to word count */
	blez	a3, bFilb		/* if no more word count
					 * but with bytes left */
bFil2:
	S	t3,0(a0)		/* store n bytes */
	addu	a0,RS			/* bump pointer */
	sub	a3,1			/* decrement word counter */
	bgtz	a3,bFil2		/* done ? */
	beqz	t2,bFild		/* partial word left? */
#ifdef	FULLY_OPTIMIZED
	addu	a0,t2			/* need to point at last byte */
	SLO	t3,-1(a0)		/* store partial word */
	j	ra			/* return */
#else	/* FULLY_OPTIMIZED */
	move	a1, t2			/* bytes left to copy */
#endif	/* FULLY_OPTIMIZED */

bFilb:
	sb	a2,0(a0)		/* byte to buffer */
	addiu	a0,a0,1			/* increment buffer pointer */
	addiu	a1,a1,-1		/* decrement counter */
	bne	a1,zero,bFilb		/* done? */
bFild:
	j	ra			/* return */

	.end	bfill


/*******************************************************************************
*
* bfillBytes - fill buffer with character a byte at a time
*
* This routine fills the first `nbytes' characters of the
* specified buffer with the specified character.
* It is identical to bfill (2) except that the fill is always performed
* a byte at a time.  This may be desirable if the buffer
* can only be accessed with byte instructions, as in certain byte-wide
* memory-mapped peripherals.
*
* SEE ALSO: bfill (2)
*
* NOMANUAL - manual entry in bLib (1)

* void bfillBytes (buf, nbytes, ch)
*     char *buf;	/* pointer to buffer              *
*     int nbytes;	/* number of bytes to fill        *
*     char ch;		/* char with which to fill buffer *

*/

	.ent	bfillBytes
bfillBytes:
	blez	a1,bfillBytesEnd        /* return if nbytes <= 0 */
bFilby:
	sb	a2,0(a0)		/* byte to buffer */
	addiu	a0,a0,1			/* increment buffer pointer */
	addiu	a1,a1,-1		/* decrement counter */
	bne	a1,zero,bFilby		/* done? */
bfillBytesEnd:
	j	ra			/* return */

	.end	bfillBytes

#endif /* bALib_PORTABLE */
