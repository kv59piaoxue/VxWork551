/* bALib.s - buffer manipulation library assembly language routines */

/* Copyright 1984-2000 Wind River Systems, Inc. */
	.data
	.globl  _copyright_wind_river
	.long   _copyright_wind_river


/*
modification history
--------------------
01b,20jun00,ur   Removed all non-Coldfire stuff.
01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
*/

/*
DESCRIPTION
This library contains optimized versions of the routines in bLib.c
for manipulating buffers of variable-length byte arrays.

NOMANUAL

SEE ALSO: bLib, ansiString
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

#ifndef	PORTABLE

	/* exports */

	.globl	_bcopy
	.globl	_bcopyBytes
	.globl	_bcopyWords
	.globl	_bcopyLongs
	.globl	_bfill
	.globl	_bfillBytes

	.text
	.even

/*******************************************************************************
*
* bcopy - copy one buffer to another
*
* This routine copies the first `nbytes' characters from
* `source' to `destination'.  Overlapping buffers are handled correctly.
* The copy is optimized by copying 4 bytes at a time if possible,
* (see bcopyBytes (2) for copying a byte at a time only).
*
* SEE ALSO: bcopyBytes (2)
*
* NOMANUAL - manual entry in bLib (1)

* void bcopy (source, destination, nbytes)
*     char *	source;		/* pointer to source buffer      *
*     char *	destination	/* pointer to destination buffer *
*     int 	nbytes;		/* number of bytes to copy       *

*/

_bcopy:
	link	a6,#0
	movel	d2,a7@-			/* save d2 */

	/* put src in a0, dest in a1, and count in d0 */

	movel	a6@(ARG1),a0		/* source */
	movel	a6@(ARG2),a1		/* destination */
	movel	a6@(ARG3),d0		/* nbytes */

	/* Find out if there is an overlap problem.
	 * We have to copy backwards if destination lies within source,
	 * i.e. ((destination - source) > 0 && < nbytes) */

	movel	a1,d1			/* destination */
	subl	a0,d1			/* - source */
	jls	cFwd			/* <= 0 means copy forward */
	cmpl	d0,d1			/* compare to nbytes */
	jcs	cBak			/* < nbytes means copy backwards */

cFwd:
	/* if length is less than 16, it's cheaper to do a byte copy */

	cmpl	#16,d0			/* test count */
	jcs	cFwd10			/* do byte copy */

	/* 
	 * If destination and source are not both odd, or both even,
	 * we must do a byte copy, rather than a long copy.
	 *
	 * Note: this restriction does NOT apply to the 68040 and 68060.
	 */

	movew	a0,d1
	movew	a1,d2
	eorl	d2,d1			/* d1 = destination ^ source */
	btst	#0,d1
	jne	cFwd10

	/* If the buffers are odd-aligned, copy the first byte */

	btst	#0,d2			/* d2 has source */
	jeq	cFwd0			/* if even-aligned */
	moveb	a0@+,a1@+		/* copy the byte */
	subl	#1,d0			/* decrement count by 1 */

cFwd0:
	/* No DBcc instructions, so the logic is a fair bit different. */
	
	movel	d0,d2
	andl	#0x0f,d0		/* remainder in d0 */
	asrl	#4,d2			/* count /= 16 */
	jra	cFwd3			/* do the test first */
cFwd2:
	movel	a0@+,a1@+		/* move 4 bytes */
	movel	a0@+,a1@+		/* move 4 bytes */
	movel	a0@+,a1@+		/* move 4 bytes */
	movel	a0@+,a1@+		/* move 4 bytes */
cFwd3:
	subql	#1, d2			/* decrement count */
	bpl	cFwd2			/* loop test */
	
	/* byte by byte copy */

cFwd10:	jra	cFwd13			/* do the test first */
cFwd12:	moveb	a0@+,a1@+		/* move a byte */
cFwd13:	subql	#1, d0			/* decrement count */
	bpl	cFwd12			/* loop test */
	
cFwd14:	
	movel	a7@+,d2			/* restore d2 */
	unlk	a6
	rts


	/* -------------------- copy backwards ---------------------- */
cBak:
	addl	d0,a0			/* make a0 point at end of from buf */
	addl	d0,a1			/* make a1 point at end of to buffer */

	/* if length is less than 10, cheaper to do a byte move */

	cmpl	#10,d0			/* test count */
	jcs	cBak10			/* do byte move */

	/*
	 * If destination and source are not both odd, or both even,
	 * we must do a byte copy, rather than a long copy.
	 *
	 * Note: this restriction does NOT apply to the 68040 and 68060.
	 */

	movew	a0,d1
	movew	a1,d2
	eorl	d2,d1			/* d1 = destination ^ source */
	btst	#0,d1
	jne	cBak10

	/* If the buffers are odd-aligned, copy the first byte */

	btst	#0,d2			/* d2 has source */
	jeq	cBak0			/* if even-aligned */
	moveb	a0@-,a1@-		/* copy the byte */
	subl	#1,d0			/* decrement count by 1 */

	/* Since we're copying 4 bytes at a crack, divide count by 4.
	 * Keep the remainder in d0, so we can do those bytes at the
	 * end of the loop. */

cBak0:
	movel	d0,d2

	/* No DBcc instructions, so the logic is a fair bit different. */
	
	andl	#0x0f,d0		/* remainder in d0 */
	asrl	#4,d2			/* count /= 16 */
	jra	cBak3			/* do the test first */
cBak2:
	movel	a0@-,a1@-		/* move 4 bytes */
	movel	a0@-,a1@-		/* move 4 bytes */
	movel	a0@-,a1@-		/* move 4 bytes */
	movel	a0@-,a1@-		/* move 4 bytes */
cBak3:
	subql	#1, d2			/* decrement count */
	bpl	cBak2			/* loop test */
	
	/* byte by byte copy */

cBak10:	jra	cBak13			/* do the test first */
cBak12:	moveb	a0@-,a1@-		/* move a byte */
cBak13:	subql	#1, d0			/* decrement count */
	bpl	cBak12			/* loop test */
	
	movel	a7@+,d2			/* restore d2 */
	unlk	a6
	rts

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
*     char *	source;		/* pointer to source buffer      *
*     char *	destination;	/* pointer to destination buffer *
*     int 	nbytes;		/* number of bytes to copy       *

*/


_bcopyBytes:
	link	a6,#0

	/* put src in a0, dest in a1, and count in d0 */

	movel	a6@(ARG1),a0		/* source */
	movel	a6@(ARG2),a1		/* destination */
	movel	a6@(ARG3),d0		/* count */

	/* 
	 * Find out if there is an overlap problem.
	 * We have to copy backwards if destination lies within source,
	 * i.e. ((destination - source) > 0 && < nbytes)
	 */

	movel	a1,d1			/* destination */
	subl	a0,d1			/* - source */
	jls	cbFwd			/* <= 0 means copy forward */
	cmpl	d0,d1			/* compare to nbytes */
	jcs	cbBak			/* < nbytes means copy backwards */

	/* Copy the whole thing forward, byte by byte */

cbFwd:
	jra	cbFwd3
cbFwd1:	moveb	a0@+,a1@+		/* move a byte */
cbFwd3:	subql	#1, d0			/* decrement count */
	bpl	cbFwd1
	
	unlk	a6
	rts

	/* Copy the whole thing backward, byte by byte */

cbBak:
	addl	d0,a0			/* make a0 point at end of from buffer*/
	addl	d0,a1			/* make a1 point at end of to buffer */

	jra	cbBak3			/* do the test first */
cbBak2:	moveb	a0@-,a1@-		/* move a byte */
cbBak3:	subql	#1, d0			/* decrement count */
	bpl	cbBak2			/* loop test */

	unlk	a6
	rts

/*******************************************************************************
*
* bcopyWords - copy one buffer to another a word at a time
*
* This routine copies the first `nwords' words from
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
*     char *	source;		/* pointer to source buffer      *
*     char *	destination;	/* pointer to destination buffer *
*     int	nwords;		/* number of words to copy       *

*/


_bcopyWords:
	link	a6,#0

	/* put src in a0, dest in a1, and count in d0 */

	movel	a6@(ARG1),a0		/* source */
	movel	a6@(ARG2),a1		/* destination */
	movel	a6@(ARG3),d0		/* count */

	asll	#1,d0			/* convert count to bytes */

	/*
	 * Find out if there is an overlap problem.
	 * We have to copy backwards if destination lies within source,
	 * i.e. ((destination - source) > 0 && < nbytes)
	 */

	movel	a1,d1			/* destination */
	subl	a0,d1			/* - source */
	jls	cwFwd			/* <= 0 means copy forward */
	cmpl	d0,d1			/* compare to nbytes */
	jcs	cwBak			/* < nbytes means copy backwards */

	/* Copy the whole thing forward, word by word */

cwFwd:
	asrl	#1,d0			/* convert count to words */

	jra	cwFwd3			/* do the test first */
cwFwd2:	movew	a0@+,a1@+		/* move a word */
cwFwd3:	subql	#1, d0			/* decrement count */
	bpl	cwFwd2			/* loop test */
	
	unlk	a6
	rts


	/* Copy the whole thing backward, word by word */

cwBak:
	addl	d0,a0			/* make a0 point at end of from buffer*/
	addl	d0,a1			/* make a1 point at end of to buffer */

	asrl	#1,d0			/* convert count to words */

	jra	cwBak3			/* do the test first */
cwBak2:	movew	a0@-,a1@-		/* move a word */
cwBak3:	subql	#1, d0			/* decrement count */
	bpl	cwBak2			/* loop test */
	
	unlk	a6
	rts

/*******************************************************************************
*
* bcopyLongs - copy one buffer to another a long at a time
*
* This routine copies the first `nlongs' longs from
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
*     char *	source;		/* pointer to source buffer      *
*     char *	destination;	/* pointer to destination buffer *
*     int 	nlongs;		/* number of longs to copy       *

*/


_bcopyLongs:
	link	a6,#0

	/* put src in a0, dest in a1, and count in d0 */

	movel	a6@(ARG1),a0		/* source */
	movel	a6@(ARG2),a1		/* destination */
	movel	a6@(ARG3),d0		/* count */

	asll	#2,d0			/* convert count to bytes */

	/* 
	 * Find out if there is an overlap problem.
	 * We have to copy backwards if destination lies within source,
	 * i.e. ((destination - source) > 0 && < nbytes)
	 */

	movel	a1,d1			/* destination */
	subl	a0,d1			/* - source */
	jls	clFwd			/* <= 0 means copy forward */
	cmpl	d0,d1			/* compare to nbytes */
	jcs	clBak			/* < nbytes means copy backwards */

	/* Copy the whole thing forward, long by long */

clFwd:
	asrl	#2,d0			/* convert count to longs */

	jra	clFwd3			/* do the test first */
clFwd2:	movel	a0@+,a1@+		/* move a long */
clFwd3:	subql	#1, d0			/* decrement count */
	bpl	clFwd2			/* loop test */
	
	unlk	a6
	rts


	/* Copy the whole thing backward, long by long */

clBak:
	addl	d0,a0			/* make a0 point at end of from buffer*/
	addl	d0,a1			/* make a1 point at end of to buffer */

	asrl	#2,d0			/* convert count to longs */

	jra	clBak3			/* do the test first */
clBak2:	movel	a0@-,a1@-		/* move a long */
clBak3:	subql	#1, d0			/* decrement count */
	bpl	clBak2			/* loop test */
	
	unlk	a6
	rts

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
*     char *	buf;		/* pointer to buffer              *
*     int 	nbytes;		/* number of bytes to fill        *
*     char 	ch;		/* char with which to fill buffer *

*/

_bfill:
	link	a6,#0
	movel	d2,a7@-
	movel	d3,a7@-

	/* put buf in a0, nbytes in d0, and ch in d1 */

	movel	a6@(ARG1),a0		/* get buf */
	movel	a6@(ARG2),d0		/* nbytes */
	movel	a6@(ARG3),d1		/* ch */

	/* if length is less than 20, cheaper to do a byte fill */

	cmpl	#20,d0			/* test count */
	jcs	fb5			/* do byte fill */

	/* Put ch in all four bytes of d1, so we can fill 4 bytes at a crack */

	clrl	d2		/* d1 == ??????XY d2 == 00000000 */
	moveb	d1, d2		/* d1 == ??????XY d2 == 000000XY */
	moveb	d2, d1		/* d1 == 000000XY d2 == 000000XY */
	lsll	#8,d2		/* d1 == 0000XY00 d2 == 0000XY00 */
	orl	d2, d1		/* d1 == 0000XYXY d2 == 0000XY00 */
	movew	d1, d2		/* d1 == 0000XYXY d2 == 0000XYXY */
	swapw	d1		/* d1 == XYXY0000 d2 == 0000XYXY */
	orl	d2, d1		/* d1 == XYXYXYXY d2 == 0000XYXY */
		
	/* If the buffer is odd-aligned, copy the first byte */

	movew	a0,d2
	btst	#0,d2			/* d2 has source */
	jeq	fb0			/* if even-aligned */

	moveb	d1,a0@+			/* copy the byte */
	subl	#1,d0			/* decrement count by 1 */

	/* 
	 * Since we're copying 4 bytes at a crack, divide count by 4.
	 * Keep the remainder in d0, so we can do those bytes at the
	 * end of the loop.
	 */

fb0:
	movel	d0,d3
	andl	#3,d0			/* remainder in d0 */
	asrl	#2,d3			/* count /= 4 */

	jra	fb3			/* do the test first */

fb2:	movel	d1,a0@+			/* move 4 bytes */
fb3:	subql	#1,d3			/* decrement count */
	bpl	fb2			/* loop test */

	/* do the extras at the end */

	jra	fb5			/* do the test first */
fb4:	moveb	d1,a0@+			/* move 1 byte */
fb5:	subql	#1,d0			/* decrement count */
	bpl	fb4			/* loop test */
	
	movel	a7@+,d3
	movel	a7@+,d2

	unlk	a6
	rts

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
*     char *	buf;		/* pointer to buffer              *
*     int 	nbytes;		/* number of bytes to fill        *
*     char 	ch;		/* char with which to fill buffer *

*/

_bfillBytes:
	link	a6,#0
	movel	d2,a1			/* save d2 in a1 */

	/* put src in a0, dest in a1, and count in d0 */

	movel	a6@(ARG1),a0		/* get destination */
	movel	a6@(ARG2),d0		/* count */
	movel	a6@(ARG3),d1		/* ch */

	/* Copy the whole thing, byte by byte */

	movel	d0,d2			/* Set up d2 as the outer loop ctr */
	swap	d2			/* get upper word into dbra counter */
	jra	fby3			/* do the test first */

fby2:	moveb	d1,a0@+			/* fill a byte */
fby3:	subql	#1, d0			/* decrement count */
	bpl	fby2			/* loop test */
	
	movel	a1,d2			/* restore d2 */
	unlk	a6
	rts
#endif	/* !PORTABLE */
