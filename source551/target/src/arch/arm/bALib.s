/* bALib.s - ARM assembler buffer manipulation routines */

/* Copyright 1991-1998 Advanced RISC Machines Ltd. */


/*
modification history
--------------------
01g,17oct01,t_m  convert to FUNC_LABEL:
01f,11oct01,jb  Enabling removal of pre-pended underscores for new compilers
                 (Diab/Gnu elf)
01e,15jul98,cdp  added big-endian support.
01d,25feb98,cdp  replaced ARM_ARCH4 stuff by ARM_HAS_HALFWORD_INSTRUCTIONS.
01c,27oct97,kkk  took out "***EOF***" line from end of file.
01b,23may97,jpd  Amalgamated into VxWorks.
01a,09jul96,ams  Ported from ARM asm.
*/

/*
DESCRIPTION
These are buffer manipulation routines, written by ARM/Acorn. It was
taken from the ARM C Library in assembler and ported here to gas.
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

	.data
	.globl	FUNC(copyright_wind_river)
	.long	FUNC(copyright_wind_river)

#if (defined(PORTABLE))
#define bALib_PORTABLE
#endif


#ifndef bALib_PORTABLE

#if (_BYTE_ORDER == _BIG_ENDIAN)
#define SLA LSL			/* shift towards low address end */
#define SHA LSR			/* shift towards high address end */
#else
#define SLA LSR			/* shift towards low address end */
#define SHA LSL			/* shift towards high address end */
#endif


/* Register aliases */

src	.req	r0
dst	.req	r1
n	.req	r2
tmp1	.req	r3
tmp3	.req	r12


/* globals */

	.global	FUNC(bcopy)			/* copy buffer as fast as possible */
	.global	FUNC(bcopyBytes)		/* copy buffer byte at a time */
	.global	FUNC(bcopyWords)		/* copy buffer word at a time */
	.global	FUNC(bcopyLongs)		/* copy buffer long at a time */
	.global	FUNC(bfill)			/* fill buffer as fast as possible */
	.global	FUNC(bfillBytes)		/* fill buffer byte at a time */

	.text
	.balign	4

/*******************************************************************************
*
* bcopy - copy one buffer to another
*
* This routine copies the first <nbytes> characters from <source> to
* <destination>.  Overlapping buffers are handled correctly.  Copying is done
* in the most efficient way possible.  In general, the copy will be
* significantly faster if both buffers are long-word aligned.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void bcopy
*	(
*	const char *	source,		/@ pointer to source buffer @/
*	char *		destination,	/@ pointer to destination buffer @/
*	int		nbytes		/@ number of bytes to copy @/
*	)
*/

FUNC_LABEL(bcopy)

	cmp	src, dst		/* copying up or down */
	blo	CopyDown		/* Copy down then if lower */
	moveq	pc, lr			/* dst == src, no move, RETURN */

	stmfd	sp!, {lr}		/* Preserve lr */

	/* Copy Up */

	subs	n, n, #4		/* need at least 4 bytes */
	blt	Up_TrailingBytes	/* < 4 bytes to go */

	/*
	 * word align the dst - first find out how many bytes must be
	 * stored to do this.  If the number is 0 check the src too.
	 */

	ands	tmp3, dst, #3		/* eq means aligned! */
	bne	Up_AlignDst
	ands	tmp3, src, #3
	bne	Up_SrcUnaligned 	/* more difficult! */

	/*
	 * We are here when source and destination are both aligned.
	 * number of bytes to transfer is (n+4), n is >= 0.
	 */
Up_SrcDstAligned:
	subs	n, n, #12-4		/* 12 bytes or more? */
	blt	Up_TrailingWords

	/*
	 * We only have three registers to play with.  It is
	 * worth gaining more only if the number of bytes to
	 * transfer is greater than 12+8*<registers stacked>
	 * We need to stack 8 (4+4) registers to gain 8 temporaries,
	 * so look for >=44 bytes.  Since we would save 8*4 = 32
	 * bytes at a time we actually compare with 64.
	 */

	subs	n, n, #32-12		/* test for n+32 to go. */
	blt	Up_16			/* Less than 16 to go */

	stmfd	sp!, {v1}		/* Save register */

Up_Loop4:
	/* loop loading 4 registers per time, twice (32 bytes) */

	ldmia	src!, {tmp1, v1, tmp3, lr}
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmia	src!, {tmp1, v1, tmp3, lr}
	stmia	dst!, {tmp1, v1, tmp3, lr}
	subs	n, n, #32
	bge	Up_Loop4


	/* see if we can handle another 8 */

	cmn	n, #16
	ldmgeia src!, {tmp1, v1, tmp3, lr}
	stmgeia dst!, {tmp1, v1, tmp3, lr}
	subge	n, n, #16

	/*
	 * Reload the register - note that we still have (n+32)
	 * bytes to go, and that this is <16.
	 */
	ldmfd	sp!, {v1}

Up_16:
	/* Here when there are fewer than 16 bytes to go. */

	adds	n, n, #32-12		/* (n-12) to go */

Up_12:
	/* Ok - do three words at a time. */

	ldmgeia src!, {tmp1, tmp3, lr}
	stmgeia dst!, {tmp1, tmp3, lr}
	subges	n, n, #12
	bge	Up_12

Up_TrailingWords:
	/* (n-12) bytes to go - 0, 1 or 2 words.  Check which. */

	adds	n, n, #12-4		/* (n-4) to go */
	blt	Up_TrailingBytes	/* < 4 bytes to go */
	subs	n, n, #4
	ldrlt	tmp1, [src], #4
	strlt	tmp1, [dst], #4
	ldmgeia src!, {tmp1, tmp3}
	stmgeia dst!, {tmp1, tmp3}
	subge	n, n, #4

Up_TrailingBytes:
	/* Here with less than 4 bytes to go */

	adds	n, n, #4
	ldmeqfd	sp!, {pc}		/* 0 bytes, RETURN */
	cmp	n, #2			/* 1, 2 or 3 bytes */

	ldrb	tmp1, [src], #1		/* 1 */
	strb	tmp1, [dst], #1		/* 1 */
	ldrgeb	tmp1, [src], #1		/* 2 */
	strgeb	tmp1, [dst], #1		/* 2 */
	ldrgtb	tmp1, [src], #1		/* 3 */
	strgtb	tmp1, [dst], #1		/* 3 */

	ldmfd	sp!, {pc}		/* Return */

/************************************************************
 *
 * word align dst - tmp3 contains current destination
 * alignment.  We can store at least 4 bytes here.
 */

Up_AlignDst:
	rsb	tmp3, tmp3, #4		/* 1-3 bytes to go */
	cmp	tmp3, #2

	ldrb	tmp1, [src], #1		/* 1 */
	strb	tmp1, [dst], #1		/* 1 */
	ldrgeb	tmp1, [src], #1		/* 2 */
	strgeb	tmp1, [dst], #1		/* 2 */
	ldrgtb	tmp1, [src], #1		/* 3 */
	strgtb	tmp1, [dst], #1		/* 3 */

	subs	n, n, tmp3		/* check number to go */
	blt	Up_TrailingBytes	/* less than 4 bytes */
	ands	tmp3, src, #3
	beq	Up_SrcDstAligned	/* coaligned case */

	/*
	 * The source is not coaligned with the destination,
	 * the destination IS currently word aligned.
	 */
Up_SrcUnaligned:
	bic	src, src, #3		/* tmp3 holds extra! */
	ldr	lr, [src], #4		/* 1-3 useful bytes */
	cmp	tmp3, #2
	bgt	Up_OneByte		/* one byte in tmp1 */
	beq	Up_TwoBytes		/* two bytes in tmp1 */

/*
 * The next three source bytes are in tmp1, one byte must
 * come from the next source word. At least four bytes
 * more must be stored.	Check first to see if there are a
 * sufficient number of bytes to go to justify using stm/ldm
 * instructions.
 */

Up_ThreeBytes:
	cmp	n, #16-4		/* at least 16 bytes? */
	blt	Up_LT16a		/* no			1	*/
	sub	n, n, #16-4		/* (n+16) bytes to go	1	*/

	/*
	 * save some work registers.  The point at which this
	 * is done is based on the ldm/stm time being = (n+3)+(n/4)S
	 */
	stmfd	sp!, {v1, v2}

	/*
	 * loop doing 16 bytes at a time.  There are currently
	 * three useful bytes in lr.
	 */
Up_GE16:
	mov	tmp1, lr, SLA #8	/* first three bytes	1	*/
	ldmia	src!, {v1, v2, tmp3, lr}	/*		12/13	*/
	orr	tmp1, tmp1, v1, SHA #24		/* word 1	1	*/
	mov	v1, v1, SLA #8			/*		...	*/
	orr	v1, v1, v2, SHA #24		/* word 2	2 (1+1)	*/
	mov	v2, v2, SLA #8
	orr	v2, v2, tmp3, SHA #24		/* word 3	2	*/
	mov	tmp3, tmp3, SLA #8
	orr	tmp3, tmp3, lr, SHA #24		/* word 4	2	*/
	stmia	dst!, {tmp1, v1, v2, tmp3}	/*		12/13	*/
	subs	n, n, #16			/*		1	*/
	bge	Up_GE16				/*		4 / 1	*/

	/*
	 * loop timing (depends on alignment) for n loops:-
	 *
	 *	pre:	17
	 *		((45/46/47)n - 3) for 32n bytes
	 *	post:	13/14
	 *	total:	(45/46/47)n+(27/28)
	 *	32 bytes:	72-75
	 *	64 bytes:	117-122
	 *	96 bytes:	162-169
	 */

	ldmfd	sp!, {v1, v2}		/* Reload registers 12/13 ????	*/
	adds	n, n, #16-4		/* check for at least 4	*/
	blt	Up_LT4a			/* < 4 bytes		*/

Up_LT16a:
	mov	tmp3, lr, SLA #8	/* first three bytes	1	*/
	ldr	lr, [src], #4		/* next four bytes	4	*/
	orr	tmp3, tmp3, lr, SHA #24	/*			1	*/
	str	tmp3, [dst], #4 	/*			4	*/
	subs	n, n, #4		/*			1	*/
	bge	Up_LT16a		/* tmp1 contains three bytes 1 / 4 */

	/*
	 * Loop timing:
	 *
	 *		15n-3	for 4n bytes
	 *	32:	117
	 *	64:	237
	 */

Up_LT4a:
	/* Less than four bytes to go - readjust the src address. */

	sub	src, src, #3
	b	Up_TrailingBytes

/*
 * The next two source bytes are in tmp1, two bytes must
 * come from the next source word. At least four bytes
 * more must be stored.
 */

Up_TwoBytes:
	cmp	n, #16-4		/* at least 16 bytes?		*/
	blt	Up_LT16b		/* no				*/
	sub	n, n, #16-4		/* (n+16) bytes to go		*/

	stmfd	sp!, {v1, v2}		/* save registers */

	/*
	 * loop doing 32 bytes at a time.  There are currently
	 * two useful bytes in lr.
	 */
Up_32b:
	mov	tmp1, lr, SLA #16	/* first two bytes		*/
	ldmia	src!, {v1, v2, tmp3, lr}
	orr	tmp1, tmp1, v1, SHA #16	/* word 1			*/
	mov	v1, v1, SLA #16
	orr	v1, v1, v2, SHA #16	/* word 2			*/
	mov	v2, v2, SLA #16
	orr	v2, v2, tmp3, SHA #16	/* word 3			*/
	mov	tmp3, tmp3, SLA #16
	orr	tmp3, tmp3, lr, SHA #16	/* word 4			*/
	stmia	dst!, {tmp1, v1, v2, tmp3}
	subs	n, n, #16
	bge	Up_32b

	ldmfd	sp!, {v1, v2}		/* Reload registers */

	adds	n, n, #16-4		/* check number of bytes	*/
	blt	Up_LT4b
Up_LT16b:
	mov	tmp3, lr, SLA #16	/* first two bytes		*/
	ldr	lr, [src], #4		/* next four bytes		*/
	orr	tmp3, tmp3, lr, SHA #16
	str	tmp3, [dst], #4
	subs	n, n, #4
	bge	Up_LT16b		/* tmp1 contains two bytes	*/

Up_LT4b:
	/* Less than four bytes to go - readjust the src address. */

	sub	src, src, #2
	b	Up_TrailingBytes

/*
 * The next source byte is in tmp1, three bytes must
 * come from the next source word. At least four bytes
 * more must be stored.
 */

Up_OneByte:
	cmp	n, #16-4		/* at least 16 bytes?		*/
	blt	Up_LT16c		/* no				*/
	sub	n, n, #16-4		/* (n+16) bytes to go		*/

	stmfd	sp!, {v1, v2}		/* save registers */

	/*
	 * loop doing 32 bytes at a time.  There is currently
	 * one useful byte in lr
	 */
Up_32c:
	mov	tmp1, lr, SLA #24	/* first byte			*/
	ldmia	src!, {v1, v2, tmp3, lr}
	orr	tmp1, tmp1, v1, SHA #8	/* word 1			*/
	mov	v1, v1, SLA #24
	orr	v1, v1, v2, SHA #8	/* word 2			*/
	mov	v2, v2, SLA #24
	orr	v2, v2, tmp3, SHA #8	/* word 3			*/
	mov	tmp3, tmp3, SLA #24
	orr	tmp3, tmp3, lr, SHA #8	/* word 4			*/
	stmia	dst!, {tmp1, v1, v2, tmp3}
	subs	n, n, #16
	bge	Up_32c

	ldmfd	sp!, {v1, v2}		/* Reload registers */

	adds	n, n, #16-4		/* check number of bytes	*/
	blt	Up_LT4c
Up_LT16c:
	mov	tmp3, lr, SLA #24	/* first byte			*/
	ldr	lr, [src], #4		/* next four bytes		*/
	orr	tmp3, tmp3, lr, SHA #8
	str	tmp3, [dst], #4
	subs	n, n, #4
	bge	Up_LT16c		/* tmp1 contains one byte	*/

Up_LT4c:
	/* Less than four bytes to go - one already in tmp3. */

	sub	src, src, #1
	b	Up_TrailingBytes

/**********************************************************************
 * Copy down code
 * ==============
 *
 *	This is exactly the same as the copy up code -
 *	but it copies in the opposite direction.
 */

CopyDown:
	add	src, src, n		/* points beyond end */
	add	dst, dst, n

	subs	n, n, #4		/* need at least 4 bytes */
	blt	Down_TrailingBytes	/* < 4 bytes to go */

	/*
	 * word align the dst - first find out how many bytes
	 * must be stored to do this.  If the number is 0
	 * check the src too.
	 */

	ands	tmp3, dst, #3		/* eq means aligned! */
	bne	Down_AlignDst
	ands	tmp3, src, #3
	bne	Down_SrcUnaligned	/* more difficult! */

	/*
	 * here when source and destination are both aligned.
	 * number of bytes to transfer is (n+4), n is >= 0.
	 */

Down_SrcDstAligned:
	subs	n, n, #12-4		/* 12 bytes or more? */
	blt	Down_TrailingWords

	/*
	 * We only have three registers to play with.  It is
	 * worth gaining more only if the number of bytes to
	 * transfer is greater than 12+8*<registers stacked>
	 * We need to stack 8 (4+4) registers to gain 8 temporaries,
	 * so look for >=44 bytes.  Since we would save 8*4 = 32
	 * bytes at a time we actually compare with 64.
	 */

	stmfd	sp!, {v1, lr}
	subs	n, n, #32-12		/* n+32 to go. */
	blt	Down_16a

Down_32a:
	/* loop loading 4 registers per time, twice (32 bytes) */

	ldmdb	src!, {tmp1, v1, tmp3, lr}
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmdb	src!, {tmp1, v1, tmp3, lr}
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	subs	n, n, #32
	bge	Down_32a

Down_16a:
	/* see if we can handle another 16 */

	cmn	n, #16
	ldmgedb src!, {tmp1, v1, tmp3, lr}
	stmgedb dst!, {tmp1, v1, tmp3, lr}
	subge	n, n, #16

	/* Here when there are fewer than 16 bytes to go. */

	adds	n, n, #32-12		/* (n-12) to go */

	/* Ok - do three words at a time. */

	ldmgedb src!, {tmp1, tmp3, lr}
	stmgedb dst!, {tmp1, tmp3, lr}
	subge	n, n, #12


	ldmfd	sp!, {v1, lr}		/* Restore registers */

	/* (n-12) bytes to go - 0, 1 or 2 words.  Check which. */

Down_TrailingWords:
	adds	n, n, #12-4		/* (n-4) to go */
	blt	Down_TrailingBytes	/* < 4 bytes to go */
	subs	n, n, #4
	ldrlt	tmp1, [src, #-4]!
	strlt	tmp1, [dst, #-4]!
	ldmgedb src!, {tmp1, tmp3}
	stmgedb dst!, {tmp1, tmp3}
	subge	n, n, #4

Down_TrailingBytes:
	/* Here with less than 4 bytes to go */

	adds	n, n, #4
	moveq	pc, lr			/* 0 bytes, RETURN	*/

	cmp	n, #2			/* 1, 2 or 3 bytes	*/

	ldrb	tmp1, [src, #-1]!	/* 1 */
	strb	tmp1, [dst, #-1]!	/* 1 */
	ldrgeb	tmp1, [src, #-1]!	/* 2 */
	strgeb	tmp1, [dst, #-1]!	/* 2 */
	ldrgtb	tmp1, [src, #-1]!	/* 3 */
	strgtb	tmp1, [dst, #-1]!	/* 3 */

	mov	pc, lr			/* RETURN */

/************************************************************
 *
 * word align dst - tmp3 contains current destination
 * alignment.  We can store at least 4 bytes here.  We are
 * going downwards - so tmp3 is the actual number of bytes
 * to store.
 */

Down_AlignDst:
	cmp	tmp3, #2		/* 1, 2 or 3 bytes */

	ldrb	tmp1, [src, #-1]!	/* 1 */
	strb	tmp1, [dst, #-1]!	/* 1 */
	ldrgeb	tmp1, [src, #-1]!	/* 2 */
	strgeb	tmp1, [dst, #-1]!	/* 2 */
	ldrgtb	tmp1, [src, #-1]!	/* 3 */
	strgtb	tmp1, [dst, #-1]!	/* 3 */

	subs	n, n, tmp3		/* check number to go */
	blt	Down_TrailingBytes	/* less than 4 bytes */
	ands	tmp3, src, #3
	beq	Down_SrcDstAligned	/* coaligned case */

	/*
	 * The source is not coaligned with the destination,
	 * the destination IS currently word aligned.
	 */

Down_SrcUnaligned:
	bic	src, src, #3		/* tmp3 holds extra! */
	ldr	tmp1, [src]		/* 1-3 useful bytes */
	cmp	tmp3, #2
	blt	Down_OneByte		/* one byte in tmp1 */
	beq	Down_TwoBytes		/* two bytes in tmp1 */

/*
 * The last three source bytes are in tmp1, one byte must
 * come from the previous source word. At least four bytes
 * more must be stored.	Check first to see if there are a
 * sufficient number of bytes to go to justify using stm/ldm
 * instructions.
 */

Down_ThreeBytes:
	cmp	n, #16-4		/* at least 16 bytes? */
	blt	Down_LT16b		/* no */
	sub	n, n, #16-4		/* (n+16) bytes to go */

	stmfd	sp!, {v1, v2, lr}	/* save registers */

	/*
	 * loop doing 32 bytes at a time.  There are currently
	 * three useful bytes in tmp1 (a4).
	 */

Down_32b:
	mov	lr, tmp1, SHA #8	/* last three bytes	*/
	ldmdb	src!, {tmp1, v1, v2, tmp3}
	orr	lr, lr, tmp3, SLA #24	/* word 4		*/
	mov	tmp3, tmp3, SHA #8
	orr	tmp3, tmp3, v2, SLA #24	/* word 3		*/
	mov	v2, v2, SHA #8
	orr	v2, v2, v1, SLA #24	/* word 2		*/
	mov	v1, v1, SHA #8
	orr	v1, v1, tmp1, SLA #24	/* word 1		*/
	stmdb	dst!, {v1, v2, tmp3, lr}
	subs	n, n, #16
	bge	Down_32b

	ldmfd	sp!, {v1, v2, lr}	/* Reload registers */

	adds	n, n, #16-4		/* check for at least 4	*/
	blt	Down_LT4b		/* < 4 bytes		*/
Down_LT16b:
	mov	tmp3, tmp1, SHA #8	/* last three bytes	*/
	ldr	tmp1, [src, #-4]!	/* previous four bytes	*/
	orr	tmp3, tmp3, tmp1, SLA #24
	str	tmp3, [dst, #-4]!
	subs	n, n, #4
	bge	Down_LT16b		/* tmp1 contains three bytes */

Down_LT4b:
	/* Less than four bytes to go - readjust the src address. */

	add	src, src, #3
	b	Down_TrailingBytes

/*
 * The last two source bytes are in tmp1, two bytes must
 * come from the previous source word. At least four bytes
 * more must be stored.
 */

Down_TwoBytes:
	cmp	n, #16-4		/* at least 16 bytes?	*/
	blt	Down_LT16c		/* no			*/
	sub	n, n, #16-4		/* (n+16) bytes to go	*/

	stmfd	sp!, {v1, v2, lr}	/* Save registers */

	/*
	 * loop doing 32 bytes at a time.  There are currently
	 * two useful bytes in tmp1 (a4).
	 */
Down_32c:
	mov	lr, tmp1, SHA #16	/* last two bytes	*/
	ldmdb	src!, {tmp1, v1, v2, tmp3}
	orr	lr, lr, tmp3, SLA #16	/* word 4		*/
	mov	tmp3, tmp3, SHA #16
	orr	tmp3, tmp3, v2, SLA #16	/* word 3		*/
	mov	v2, v2, SHA #16
	orr	v2, v2, v1, SLA #16	/* word 2		*/
	mov	v1, v1, SHA #16
	orr	v1, v1, tmp1, SLA #16	/* word 1		*/
	stmdb	dst!, {v1, v2, tmp3, lr}
	subs	n, n, #16
	bge	Down_32c

	ldmfd	sp!, {v1, v2, lr}	/* Reload registers */

	adds	n, n, #16-4		/* check for at least 4	*/
	blt	Down_LT4c		/* < 4 bytes		*/
Down_LT16c:
	mov	tmp3, tmp1, SHA #16	/* last two bytes	*/
	ldr	tmp1, [src, #-4]!	/* previous four bytes	*/
	orr	tmp3, tmp3, tmp1, SLA #16
	str	tmp3, [dst, #-4]!
	subs	n, n, #4
	bge	Down_LT16c		/* tmp1 contains two bytes */

Down_LT4c:
	/* Less than four bytes to go - readjust the src address. */

	add	src, src, #2
	b	Down_TrailingBytes

/*
 * The last source byte is in tmp1, three bytes must
 * come from the previous source word. At least four bytes
 * more must be stored.
 */

Down_OneByte:
	cmp	n, #16-4		/* at least 16 bytes?	*/
	blt	Down_4d			/* no			*/
	sub	n, n, #16-4		/* (n+16) bytes to go	*/

	stmfd	sp!, {v1, v2, lr}	/* save registers */

	/*
	 * loop doing 32 bytes at a time.  There is currently
	 * one useful byte in tmp1 (a4).
	 */
Down_32d:
	mov	lr, tmp1, SHA #24	/* last byte		*/
	ldmdb	src!, {tmp1, v1, v2, tmp3}
	orr	lr, lr, tmp3, SLA #8	/* word 4		*/
	mov	tmp3, tmp3, SHA #24
	orr	tmp3, tmp3, v2, SLA #8	/* word 3		*/
	mov	v2, v2, SHA #24
	orr	v2, v2, v1, SLA #8	/* word 2		*/
	mov	v1, v1, SHA #24
	orr	v1, v1, tmp1, SLA #8	/* word 1		*/
	stmdb	dst!, {v1, v2, tmp3, lr}
	subs	n, n, #16
	bge	Down_32d

	ldmfd	sp!, {v1, v2, lr}	/* Reload registers */

	adds	n, n, #16-4		/* check for at least 4	*/
	blt	Down_LT4d		/* < 4 bytes		*/
Down_4d:
	mov	tmp3, tmp1, SHA #24	/* last byte		*/
	ldr	tmp1, [src, #-4]!	/* previous four bytes	*/
	orr	tmp3, tmp3, tmp1, SLA #8
	str	tmp3, [dst, #-4]!
	subs	n, n, #4
	bge	Down_4d			 /* tmp1 contains one byte */

Down_LT4d:
	/* Less than four bytes to go - one already in tmp3. */

	add	src, src, #1
	b	Down_TrailingBytes

/*******************************************************************************
*
* bcopyBytes - copy one buffer to another one byte at a time
*
* This routine copies the first <nbytes> characters from <source> to
* <destination> one byte at a time.  This may be desirable if a buffer can
* only be accessed with byte instructions, as in certain byte-wide
* memory-mapped peripherals.
*
* RETURNS N/A
*
* NOMANUAL
*
* void bcopyBytes
*	(
*	char *	source,		/@ pointer to source buffer @/
*	char *	destination,	/@ pointer to destination buffer @/
*	int	nbytes		/@ number of bytes to copy @/
*	)
*/

FUNC_LABEL(bcopyBytes)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */


	/* Quick check for 0 */

	cmp	n, #0

#ifdef STACK_FRAMES
	ldmeqdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr
#endif /* STACK_FRAMES */

	/* Determine if forward or backward copy required */

	subs	tmp1, dst, src

#ifdef STACK_FRAMES
	ldmeqdb	fp, {fp, sp, pc}	/* Same */
#else /* !STACK_FRAMES */
	moveq	pc, lr			/* Same */
#endif /* STACK_FRAMES */

	blt	copyBytes_Forward
	cmp	tmp1, n
	bge	copyBytes_Forward

/*
 * backward copy
 * The copy loop is rolled out in one loop of 16 byte copies. The loop is
 * initiated by jumping into the loop at location (n % 16).
 */
	/* Adjust pointers to the end of the buffer */

	add	dst, dst, n
	add	src, src, n

	/* Compute jump offset if necessary */

	ands	tmp1, n, #0x0f			/* Odd count */
	rsbne	tmp1, tmp1, #16			/* Offset to jump into */
	addne	tmp1, pc, tmp1, lsl #3		/* Jump address */
	movne	pc, tmp1			/* Do the dirty */

BacwB_Loop:
	/* Loop here while we have bytes to copy */

	ldrb	tmp3, [src, #-1]!		/* 16 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 15 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 14 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 13 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 12 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 11 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 10 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 9 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 8 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 7 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 6 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 5 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 4 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 3 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 2 */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 1 */
	strb	tmp3, [dst, #-1]!

	/* Finished iteration */

	subs	n, n, #16			/* > 0 (and / 16) if any left */
	bgt	BacwB_Loop			/* Another 16 ? */

	/* Return */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */

/*
 * forward copy
 * The copy loop is rolled out in one loop of 16 byte copies. The loop is
 * initiated by jumping into the loop at location (n % 16).
 */
copyBytes_Forward:
	/* Compute jump offset if necessary */

	ands	tmp1, n, #0x0f			/* Odd count */
	rsbne	tmp1, tmp1, #16			/* Offset to jump into */
	addne	tmp1, pc, tmp1, lsl #3		/* Jump address */
	movne	pc, tmp1			/* Do the dirty */

ForwB_Loop:
	/* Loop here while we have bytes to copy */

	ldrb	tmp1, [src], #1			/* 16 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 15 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 14 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 13 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 12 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 11 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 10 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 9 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 8 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 7 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 6 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 5 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 4 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 3 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 2 */
	strb	tmp1, [dst], #1
	ldrb	tmp1, [src], #1			/* 1 */
	strb	tmp1, [dst], #1

	/* Next iteration ? */
	subs	n, n, #16			/* > 0 (and / 16) if any left */
	bgt	ForwB_Loop			/* Another 16 ? */

	/* Return */
#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */

/*******************************************************************************
*
* bcopyWords - copy one buffer to another one half-word (16 bits) at a time
*
* This routine copies the first <nwords> words from <source> to <destination>
* one word at a time.  This may be desirable if a buffer can only be accessed
* with word instructions, as in certain word-wide memory-mapped peripherals.
* The source and destination must be word-aligned.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void bcopyWords
*	(
*	char *	source,		/@ pointer to source buffer @/
*	char *	destination,	/@ pointer to destination buffer @/
*	int	nwords		/@ number of words to copy @/
*	)
*/

FUNC_LABEL(bcopyWords)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {v1, fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */


	/* Quick check for 0 */

	cmp	n, #0

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr
#endif /* STACK_FRAMES */

	/* Determine if forward or backward copy required */

	subs	tmp1, dst, src

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr			/* Same */
#endif /* STACK_FRAMES */

#if ARM_HAS_HALFWORD_INSTRUCTIONS

	/* Find direction */

	blt	copyWords_Forward
	mov	tmp3, n, asl #1		/* Convert to bytes */
	cmp	tmp1, tmp3
	bge	copyWords_Forward

/*
 * backward copy
 * The copy loop is rolled out in one loop of 16 word copies. The loop is
 * initiated by jumping into the loop at location (n % 16).
 */
	/* Adjust pointers to the end of the buffer */

	add	dst, dst, tmp3
	add	src, src, tmp3

	/* Compute jump offset if necessary */

	ands	tmp1, n, #0x0f			/* Odd count */
	rsbne	tmp1, tmp1, #16			/* Offset to jump into */
	addne	tmp1, pc, tmp1, lsl #3		/* Jump address */
	movne	pc, tmp1			/* Do the dirty */

BacwW_Loop:
	/* Loop here while we have words to copy */

	ldrh	tmp3, [src, #-2]!		/* 16 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 15 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 14 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 13 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 12 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 11 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 10 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 9 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 8 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 7 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 6 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 5 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 4 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 3 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 2 */
	strh	tmp3, [dst, #-2]!
	ldrh	tmp3, [src, #-2]!		/* 1 */
	strh	tmp3, [dst, #-2]!

	/* Iteration complete */

	subs	n, n, #16			/* > 0 (and / 16) if any left */
	bgt	BacwW_Loop			/* Another 16 ? */

	/* Return */
#ifdef STACK_FRAMES
	ldmdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */

/*
 * forward copy
 * The copy loop is rolled out in one loop of 16 word copies. The loop is
 * initiated by jumping into the loop at location (n % 16).
 */
copyWords_Forward:

	/* Compute jump offset if necessary */

	ands	tmp1, n, #0x0f			/* Odd count */
	rsbne	tmp1, tmp1, #16			/* Offset to jump into */
	addne	tmp1, pc, tmp1, lsl #3		/* Jump address */
	movne	pc, tmp1			/* Do the dirty */

ForwW_Loop:
	/* Loop here while we have words to copy */

	ldrh	tmp1, [src], #2			/* 16 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 15 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 14 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 13 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 12 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 11 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 10 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 9 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 8 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 7 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 6 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 5 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 4 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 3 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 2 */
	strh	tmp1, [dst], #2
	ldrh	tmp1, [src], #2			/* 1 */
	strh	tmp1, [dst], #2

	/* Iteration complete */

	subs	n, n, #16			/* > 0 (and / 16) if any left */
	bgt	ForwW_Loop			/* Another 16 ? */

	/* Return */
#ifdef STACK_FRAMES
	ldmdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */

#else  /* ! ARM_HAS_HALFWORD_INSTRUCTIONS */

#ifndef STACK_FRAMES
	stmfd	sp!, {v1, lr}		/* Save regs */
#endif /* STACK_FRAMES */

	/* Find direction */

	blt	copyWords_Forward
	mov	tmp3, n, asl #1		/* Convert to bytes */
	cmp	tmp1, tmp3
	bge	copyWords_Forward

/* backward copy: adjust pointers to the end of the buffer */

	add	dst, dst, tmp3
	add	src, src, tmp3

	/* Check if 16-bit aligned */

	tst	src, #2				/* 16 bit aligned */
	beq	BacwW_Aligned

	ldrb	tmp3, [src, #-1]!		/* Extra word, 1st byte*/
	strb	tmp3, [dst, #-1]!		
	ldrb	tmp3, [src, #-1]!		/* Extra word, 2nd byte*/
	strb	tmp3, [dst, #-1]!		
	subs	n, n, #1			/* One less */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Done ? */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Done ? */
#endif /* STACK_FRAMES */

BacwW_Aligned:

/* The copy loop is rolled out in one loop of 16 32-bit copies.  */

	/* Copy 16 longs (32 shorts) ? */

	subs	n, n, #32
	blt	CWB_LT32

BacwW_Loop:
	/* Loop here while we have > 32 words to copy */

	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 8 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 16 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 24 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 32 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	subs	n, n, #32
	bge	BacwW_Loop

CWB_LT32:
	/* Here if less than 32 longs to copy */

	adds	n, n, #32

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Done */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Done */
#endif /* STACK_FRAMES */

	/* Possible 24 to copy */

	movs	tmp1, n, asr #3			/* How many groups of 8 ? */
	beq	CWB_LT8				/* None */

	/* Remove 8/16/24 from the counter */

	sub	n, n, tmp1, asl #3

	/* 8, 16 or 24 words */

	cmp	tmp1, #2
	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 8 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmgedb	src!, {tmp1, v1, tmp3, lr}	/* 16 */
	stmgedb	dst!, {tmp1, v1, tmp3, lr}
	ldmgtdb	src!, {tmp1, v1, tmp3, lr}	/* 24 */
	stmgtdb	dst!, {tmp1, v1, tmp3, lr}

	/* Less than 8 words to copy */

	cmp	n, #0				/* Anything left ? */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Nope, done */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Nope, done */
#endif /* STACK_FRAMES */

CWB_LT8:
	/* Convert to complete 32-bit words (0,1,2,3) */

	movs	tmp1, n, asr #1			/* 32-bit words */
	beq	CWB_EQ1				/* 0*32-bit, 1*16 words left? */

	cmp	tmp1, #2
	ldr	tmp3, [src, #-4]!		/* 1 */
	str	tmp3, [dst, #-4]!
	ldrge	tmp3, [src, #-4]!		/* 2 */
	strge	tmp3, [dst, #-4]!
	ldrgt	tmp3, [src, #-4]!		/* 3 */
	strgt	tmp3, [dst, #-4]!

	subs	n, n, tmp1, asl #1		/* Take off what we copied */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Done ? */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Done ? */
#endif /* STACK_FRAMES */
	
CWB_EQ1:
	ldrb	tmp3, [src, #-1]!		/* 1st byte */
	strb	tmp3, [dst, #-1]!
	ldrb	tmp3, [src, #-1]!		/* 2nd byte */
	strb	tmp3, [dst, #-1]!

#ifdef STACK_FRAMES
	ldmdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmfd	sp!, {v1, pc}			/* Done */
#endif /* STACK_FRAMES */

/*
 * forward copy:
 * The copy loop is rolled out in one loop of 16 word copies. The loop is
 * initiated by jumping into the loop at location (n % 16).
 */
copyWords_Forward:
	/* Check if 16-bit aligned */

	tst	src, #2				/* 16 bit aligned */
	beq	ForwW_Aligned

	ldrb	tmp3, [src], #1			/* Extra word, 1st byte*/
	strb	tmp3, [dst], #1		
	ldrb	tmp3, [src], #1			/* Extra word, 2nd byte*/
	strb	tmp3, [dst], #1		
	subs	n, n, #1			/* One less */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Done ? */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Done ? */
#endif /* STACK_FRAMES */

ForwW_Aligned:
	/* Copy 16 longs (32 shorts) ? */

	subs	n, n, #32
	blt	CWF_LT32

ForwW_Loop:
	/* Loop here while we have > 32 words to copy */

	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 8 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 16 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 24 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 32 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	subs	n, n, #32
	bge	ForwW_Loop

CWF_LT32:
	/* Here is less than 32 longs to copy */

	adds	n, n, #32

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Done */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Done */
#endif /* STACK_FRAMES */

	/* Possible 24 to copy */

	movs	tmp1, n, asr #3			/* How many groups of 8 ? */
	beq	CWF_LT8				/* None */

	/* Remove 8/16/24 from the counter */

	sub	n, n, tmp1, asl #3

	/* 8, 16 or 24 words */

	cmp	tmp1, #2
	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 8 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmgeia	src!, {tmp1, v1, tmp3, lr}	/* 18 */
	stmgeia	dst!, {tmp1, v1, tmp3, lr}
	ldmgtia	src!, {tmp1, v1, tmp3, lr}	/* 24 */
	stmgtia	dst!, {tmp1, v1, tmp3, lr}

	/* Less than 8 words to copy */

	cmp	n, #0				/* Anything left ? */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Nope, done */
#endif /* STACK_FRAMES */

	/* Convert to complete 32-bit words (0,1,2,3) */
CWF_LT8:
	movs	tmp1, n, asr #1			/* 32-bit words */
	beq	CWF_EQ1				/* 0*32-bit, 1*16 words left? */

	cmp	tmp1, #2
	ldr	tmp3, [src], #4			/* 1 */
	str	tmp3, [dst], #4
	ldrge	tmp3, [src], #4			/* 2 */
	strge	tmp3, [dst], #4
	ldrgt	tmp3, [src], #4			/* 3 */
	strgt	tmp3, [dst], #4

	subs	n, n, tmp1, asl #1		/* Take off amount we copied */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Done ? */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Done ? */
#endif /* STACK_FRAMES */

CWF_EQ1:
	ldrb	tmp3, [src], #1			/* 1st byte */
	strb	tmp3, [dst], #1
	ldrb	tmp3, [src], #1			/* 2nd byte */
	strb	tmp3, [dst], #1

#ifdef STACK_FRAMES
	ldmdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmfd	sp!, {v1, pc}			/* Done */
#endif /* STACK_FRAMES */

#endif /* ARM_HAS_HALFWORD_INSTRUCTIONS */

/* bcopyWords End */

/*******************************************************************************
*
* bcopyLongs - copy one buffer to another one long at a time
*
* This routine copies the first <nlongs> longs from <source> to <destination>
* one long at a time.  This may be desirable if a buffer can only be accessed
* with long instructions, as in certain long-wide memory-mapped peripherals.
* The source and destination must be long-aligned.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void bcopyLongs
*	(
*	char *	source,		/@ pointer to source buffer @/
*	char *	destination,	/@ pointer to destination buffer @/
*	int	longs		/@ number of longs to copy @/
*	)
*/

FUNC_LABEL(bcopyLongs)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {v1, fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	/* Quick check for 0 */
	cmp	n, #0

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr
#endif /* STACK_FRAMES */

	/* Determine if forward or backward copy required */

	subs	tmp1, dst, src

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr			/* Same */
#endif /* STACK_FRAMES */

#ifndef STACK_FRAMES
	stmfd	sp!, {v1, lr}		/* Save regs */
#endif /* STACK_FRAMES */

	blt	copyLongs_Forward
	mov	tmp3, n, asl #2		/* Convert to bytes */
	cmp	tmp1, tmp3
	bge	copyLongs_Forward

/*
 * backward copy
 * The copy loop is rolled out in one loop of 16 long copies and
 * one of 4 long copies. The remainder is done on a simple conditional.
 */
	/* Adjust pointers to the end of the buffer */

	add	dst, dst, tmp3
	add	src, src, tmp3


	/* Copy 16 Longs ? */

	subs	n, n, #16
	blt	CLB_LT16

CLB_16:
	/* Loop here while we have > 16 longs to copy */

	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 4 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 8 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 12 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 16 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	subs	n, n, #16
	bge	CLB_16

CLB_LT16:
	/* Here if less than 16 longs to copy */

	adds	n, n, #16

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Done */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Done */
#endif /* STACK_FRAMES */

	/* Possible 12 to copy */

	movs	tmp1, n, asr #2			/* How many groups of 4 ? */
	beq	CLB_LT4				/* None ! */

	/* Remove 4/8/12 from the counter */

	sub	n, n, tmp1, asl #2

	/* 4, 8 or 12 longs */

	cmp	tmp1, #2
	ldmdb	src!, {tmp1, v1, tmp3, lr}	/* 4 */
	stmdb	dst!, {tmp1, v1, tmp3, lr}
	ldmgedb	src!, {tmp1, v1, tmp3, lr}	/* 8 */
	stmgedb	dst!, {tmp1, v1, tmp3, lr}
	ldmgtdb	src!, {tmp1, v1, tmp3, lr}	/* 12 */
	stmgtdb	dst!, {tmp1, v1, tmp3, lr}

	/* Less than 4 longs to copy */

	cmp	n, #0				/* Anything left ? */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Nope, done */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Nope, done */
#endif /* STACK_FRAMES */

CLB_LT4:
	/* 1, 2 or 3 */

	cmp	n, #2
	ldr	tmp3, [src, #-4]!		/* 1 */
	str	tmp3, [dst, #-4]!
	ldrge	tmp3, [src, #-4]!		/* 2 */
	strge	tmp3, [dst, #-4]!
	ldrgt	tmp3, [src, #-4]!		/* 3 */
	strgt	tmp3, [dst, #-4]!

	/* Return */
#ifdef STACK_FRAMES
	ldmdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmfd	sp!, {v1, pc}
#endif /* STACK_FRAMES */

/*
 * forward copy
 * The copy loop is rolled out in one loop of 16 long copies and
 * one of 4 long copies. The remainder is done on a simple conditional.
 */
copyLongs_Forward:

	/* Copy 16 Longs ? */

	subs	n, n, #16
	blt	CLF_LT16

CLF_16:
	/* Loop here while we have > 16 longs to copy */

	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 4 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 8 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 12 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 16 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	subs	n, n, #16
	bge	CLF_16

CLF_LT16:
	/* Here if less than 16 longs to copy */

	adds	n, n, #16

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Done */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Done */
#endif /* STACK_FRAMES */

	/* Possible 12 to copy */

	movs	tmp1, n, asr #2			/* How many groups of 4 ? */
	beq	CLF_LT4				/* None ! */

	/* Remove 4/8/12 from the counter */

	sub	n, n, tmp1, asl #2

	/* 4, 8 or 12 longs */

	cmp	tmp1, #2
	ldmia	src!, {tmp1, v1, tmp3, lr}	/* 4 */
	stmia	dst!, {tmp1, v1, tmp3, lr}
	ldmgeia	src!, {tmp1, v1, tmp3, lr}	/* 8 */
	stmgeia	dst!, {tmp1, v1, tmp3, lr}
	ldmgtia	src!, {tmp1, v1, tmp3, lr}	/* 12 */
	stmgtia	dst!, {tmp1, v1, tmp3, lr}

	/* Less than 4 longs to copy */

	cmp	n, #0				/* Anything left ? */

#ifdef STACK_FRAMES
	ldmeqdb	fp, {v1, fp, sp, pc}		/* Nope, done */
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {v1, pc}			/* Nope, done */
#endif /* STACK_FRAMES */

CLF_LT4:
	/* 1, 2 or 3 */

	cmp	n, #2
	ldr	tmp3, [src], #4			/* 1 */
	str	tmp3, [dst], #4
	ldrge	tmp3, [src], #4			/* 2 */
	strge	tmp3, [dst], #4
	ldrgt	tmp3, [src], #4			/* 3 */
	strgt	tmp3, [dst], #4

	/* Return */
#ifdef STACK_FRAMES
	ldmdb	fp, {v1, fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmfd	sp!, {v1, pc}
#endif /* STACK_FRAMES */


/*******************************************************************************
*
* bfill - fill a buffer with a specified character
*
* This routine fills the first <nbytes> characters of a buffer with the
* character <ch>.  Filling is done in the most efficient way possible,
* which may be long-word, or even multiple-long-word stores, on some
* architectures.  In general, the fill will be significantly faster if
* the buffer is long-word aligned.  (For filling that is restricted to
* byte stores, see the manual entry for bfillBytes().)
*
* RETURNS: N/A
*
* NOMANUAL
*
* void bfill
*	(
*	char *	buf,	/@ pointer to buffer @/
*	int	nbytes,	/@ number of bytes to fill @/
*	int	ch	/@ char with which to fill buffer @/
*	)
*/

/* Register aliases: gas does not allow redefining symbols as different regs */

buf	.req	r0
n_f	.req	r1
ch	.req	r2

FUNC_LABEL(bfill)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#else /* !STACK_FRAMES */
	stmfd	sp!, {lr}		/* Preserve return address */
#endif /* STACK_FRAMES */

	subs	n_f, n_f, #4		/* need at least 4 bytes */
	bmi	TrailingBytes		/* < 4 bytes to go */

	/*
	 * word align the dst - first find out how many bytes
	 * must be stored to do this.
	 */

	ands	tmp3, buf, #3		/* eq means aligned! */
	bne	AlignDst

	/*
	 * here when destination is word-aligned,
	 * number of bytes to transfer is (n+4), n is >= 0.
	 */
DstAligned:
	and	ch, ch, #0xff		/* pad src */
	orr	ch, ch, ch, ASL #8
	orr	ch, ch, ch, ASL #16
	mov	tmp1, ch
	mov	tmp3, ch
	mov	lr, ch

	subs	n_f, n_f, #12-4		/* 12 bytes or more? */
	blt	TrailingWords

	subs	n_f, n_f, #32-12		/* n+32 to go. */
	blt	1f

0:
	stmia	buf!, {ch, tmp1, tmp3, lr}
	stmia	buf!, {ch, tmp1, tmp3, lr}
	subs	n_f, n_f, #32
	bge	0b

	/* see if we can handle another 8 */

	cmn	n_f, #16
	stmgeia buf!, {ch, tmp1, tmp3, lr}
	subge	n_f, n_f, #16

	/* note that we still have (n+32) bytes to go, and this is <16. */

1:
	/* Here when there are fewer than 16 bytes to go. */

	adds	n_f, n_f, #32-12		   /* (n-12) to go */

2:
	/* Ok - do three words at a time. */

	stmgeia buf!, {tmp1, tmp3, lr}
	subges	n_f, n_f, #12
	bge	2b

TrailingWords:
	/* (n-12) bytes to go - 0, 1 or 2 words.  Check which. */

	adds	n_f, n_f, #12-4		/* (n-4) to go */
	blt	TrailingBytes		/* < 4 bytes to go */
	subs	n_f, n_f, #4
	strlt	ch, [buf], #4
	stmgeia buf!, {ch, tmp1}
	subge	n_f, n_f, #4


TrailingBytes:
	/* Here with less than 4 bytes to go */

	adds	n_f, n_f, #4

#ifdef STACK_FRAMES
	ldmeqdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmeqfd	sp!, {pc}		/* 0 bytes, RETURN */
#endif /* STACK_FRAMES */

	cmp	n_f, #2			/* 1, 2 or 3 bytes */
	strb	ch, [buf], #1		/* 1 */
	strgeb	ch, [buf], #1		/* 2 */
	strgtb	ch, [buf], #1		/* 3 */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	ldmfd	sp!, {pc}		/* RETURN */
#endif /* STACK_FRAMES */

/*
 * word align dst - tmp3 contains current destination
 * alignment.  We can store at least 4 bytes here.
 */
AlignDst:
	rsb	tmp3, tmp3, #4		/* 1-3 bytes to go */
	cmp	tmp3, #2
	strb	ch, [buf], #1		/* 1 */
	strgeb	ch, [buf], #1		/* 2 */
	strgtb	ch, [buf], #1		/* 3 */

	subs	n_f, n_f, tmp3		/* check number to go */
	blt	TrailingBytes		/* less than 4 bytes */
	b	DstAligned

/*******************************************************************************
*
* bfillBytes - fill buffer with a specified character one byte at a time
*
* This routine fills the first <nbytes> characters of the specified buffer
* with the character <ch> one byte at a time.  This may be desirable if a
* buffer can only be accessed with byte instructions, as in certain
* byte-wide memory-mapped peripherals.
*
* RETURNS: N/A
*
* NOMANUAL
*
* void bfillBytes
*	(
*	char *	buf,	/@ pointer to buffer @/
*	int	nbytes,	/@ number of bytes to fill @/
*	int	ch	/@ char with which to fill buffer @/
*	)
*/


FUNC_LABEL(bfillBytes)

#ifdef STACK_FRAMES
	mov	ip, sp
	stmdb	sp!, {fp, ip, lr, pc}
	sub	fp, ip, #4
#endif /* STACK_FRAMES */

	/* Quick check for 0 */
	cmp	n_f, #0

#ifdef STACK_FRAMES
	ldmeqdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	moveq	pc, lr
#endif /* STACK_FRAMES */

	/*
	 * The fill loop is rolled out in one loop of 16 byte fills.
	 * It is entered by jumping to the relative location.
	 */

	/* Compute jump offset if necessary */

	ands	tmp1, n_f, #0x0f		/* Odd count */
	rsbne	tmp1, tmp1, #16			/* Offset to jump into */
	addne	tmp1, pc, tmp1, lsl #2		/* Jump address */
	movne	pc, tmp1			/* Do the dirty */

	/* Loop here while we have > 16 bytes to copy */

Fill_Loop:
	strb	ch, [buf], #1			/* 16 */
	strb	ch, [buf], #1			/* 15 */
	strb	ch, [buf], #1			/* 14 */
	strb	ch, [buf], #1			/* 13 */
	strb	ch, [buf], #1			/* 12 */
	strb	ch, [buf], #1			/* 11 */
	strb	ch, [buf], #1			/* 10 */
	strb	ch, [buf], #1			/* 9 */
	strb	ch, [buf], #1			/* 8 */
	strb	ch, [buf], #1			/* 7 */
	strb	ch, [buf], #1			/* 6 */
	strb	ch, [buf], #1			/* 5 */
	strb	ch, [buf], #1			/* 4 */
	strb	ch, [buf], #1			/* 3 */
	strb	ch, [buf], #1			/* 2 */
	strb	ch, [buf], #1			/* 1 */


	/* Another iteration */

	subs	n_f, n_f, #16			/* > 0 (and / 16) if any left */
	bgt	Fill_Loop			/* Another 16 ? */

	/* Return */

#ifdef STACK_FRAMES
	ldmdb	fp, {fp, sp, pc}
#else /* !STACK_FRAMES */
	mov	pc, lr
#endif /* STACK_FRAMES */
	

#endif /* ! bALib_PORTABLE */
