/* bALib.s - buffer manipulation library assembly language routines */

/* Copyright 1995-2000 Wind River Systems, Inc. */

	.data
	.global  _copyright_wind_river
	.long   _copyright_wind_river

/*
modification history
--------------------
01q,21aug00,hk   merge SH7729 to SH7700. simplify CPU conditionals.
01p,27mar00,hk   added .type directive to function names.
01o,17mar00,zl   made use of alignment macro _ALIGN_TEXT
01n,24feb99,hk   simplified CPU conditionals in default of shld instruction.
01m,14sep98,hk   simplified SH7000 specific CPU conditionals.
01l,16jul98,st   added SH7750 support.
01l,07may98,jmc  added support for SH-DSP and SH3-DSP.
01k,25apr97,hk   changed SH704X to SH7040.
01j,05aug96,hk   added bf.s optimization to bcopyLongs, bcopyWords.
		 added shld optimization to cLong, cWord, cByte, fbLong.
		 rearranged #if (CPU==SH7xxx) controls.  changed indentation
		 of bfillBytes. deleted unnecessary comments.
01i,29jul96,hk   changed to use 'mova'. added DEBUG_LOCAL_SYMBOLS option.
01h,10may96,hk   added SH7700 support.
01g,23jan96,hk   changed machine codes for bt/s, bf/s to use bt.s, bf.s.
01f,18dec95,hk   added support for SH704X.
01e,22may95,hk   reworked on documentation and code layout.
01d,19may95,hk   optimized more. worked around 'mova' alignment problem.
01c,08may95,hk   optimized bcopy(). some more possibility remains.
01b,03may95,hk   optimized all but bcopy().
01a,01may95,hk   written based on mc68k-01w.
*/

/*
DESCRIPTION
This library contains optimized versions of the routines in bLib.c
for manipulating buffers of variable-length byte arrays.

NOMANUAL

SEE ALSO: bLib(1), strLib(1)
*/

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "asm.h"

#ifndef	PORTABLE

	/* exports */

	.global	_bcopyLongs
	.global	_bcopyWords
	.global	_bcopyBytes
	.global	_bcopy
	.global	_bfill
	.global	_bfillBytes
#undef	DEBUG_LOCAL_SYMBOLS
#ifdef	DEBUG_LOCAL_SYMBOLS
	.global	clBak
	.global	clBakLoop
	.global	clFwd
	.global	clFwdLoop
	.global	clDone
	.global	cwBak
	.global	cwBakLoop
	.global	cwFwd
	.global	cwFwdLoop
	.global	cwDone
	.global	cbBak
	.global	cbBakLoop
	.global	cbFwdLoop
	.global	cbDone
	.global	cFwd
	.global	cFwdLongWord
	.global	cFwdLongAligned
	.global	cLong
	.global	cBak
	.global	cBakLongWord
	.global	cBakLongAligned
	.global	cFwdWord
	.global	cFwdWordAligned
	.global	cWord
	.global	cBakWord
	.global	cBakWordAligned
	.global	cFwdByte
	.global	cByte
	.global	cBakByte
	.global	cFwdLongLoop
	.global	cFwdLongCopy
	.global	cFwdLongLastByte
	.global	cFwdLastByte
	.global	cFwdWordLoop
	.global	cFwdWordCopy
	.global	cFwdByteLoop
	.global	cFwdByteCopy
	.global	cFwdDone
	.global	cBakLongLoop
	.global	cBakLongCopy
	.global	cBakLongLastByte
	.global	cBakLastByte
	.global	cBakWordLoop
	.global	cBakWordCopy
	.global	cBakByteLoop
	.global	cBakByteCopy
	.global	cBakDone
	.global	fbWord
	.global	fbLong
	.global	fbLoop
	.global	fbStart
	.global	fbLastByte
	.global	fbDone
	.global	fby1
	.global	fby2
#endif	/* DEBUG_LOCAL_SYMBOLS */

	.text

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

* void bcopyLongs
*     (
*     char *source,		/@ pointer to source buffer      @/
*     char *destination,	/@ pointer to destination buffer @/
*     int   nlongs		/@ number of longs to copy       @/
*     )

* NOTE:	This routine is not used at boot time.
*/
	.align	_ALIGN_TEXT
	.type	_bcopyLongs,@function

				/* r4: source      */
				/* r5: destination */
_bcopyLongs:			/* r6: nlongs      */
	cmp/pl	r6
	bf	clDone
#if (CPU==SH7000)
	shll2	r6		/* r6: nbytes      */
				/* r4:        {{{{{  source  }}}}}} */
	cmp/hi	r5,r4		/* r5: {{{  destination  }}}   ?    */
	bf	clBak		/*     If not, backward copy is ok. */
#else
	cmp/hi	r5,r4
	bf.s	clBak
	shll2	r6
#endif
	mov	r4,r0		/* r0: <===== r0 =====>                     */
	sub	r5,r0		/* r4: <== r6 ==> ?    {{{{{  source  }}}}} */
	cmp/ge	r6,r0		/* r5: {{{  destination  }}}                */
	bf	clFwd		/*     If not, forward copy is necessary.   */

	/* Copy the whole thing backward, long by long */
clBak:
	mov	r6,r0		/* r0: {offset to buffer tail} + 1 */
clBakLoop:
	add	#-4,r0
	mov.l	@(r0,r4),r1;
	cmp/pl	r0
#if (CPU==SH7000)
	mov.l	r1,@(r0,r5)
	bt	clBakLoop
#else
	bt.s	clBakLoop
	mov.l	r1,@(r0,r5)
#endif
	rts;
	nop

	/* Copy the whole thing forward, long by long */
clFwd:
	mov	#0,r0
clFwdLoop:
	mov.l	@(r0,r4),r1;
	mov.l	r1,@(r0,r5)
	add	#4,r0
	cmp/gt	r0,r6
	bt	clFwdLoop
clDone:
	rts;
	nop

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

* void bcopyWords
*     (
*     char *source,		/@ pointer to source buffer      @/
*     char *destination,	/@ pointer to destination buffer @/
*     int   nwords		/@ number of words to copy       @/
*     )

* NOTE:	This routine is not used at boot time.
*/
	.align	_ALIGN_TEXT
	.type	_bcopyWords,@function

				/* r4: source      */
				/* r5: destination */
_bcopyWords:			/* r6: nwords      */
	cmp/pl	r6
	bf	cwDone
#if (CPU==SH7000)
	shll	r6		/* r6: nbytes      */
				/* r4:        {{{{{  source  }}}}}} */
	cmp/hi	r5,r4		/* r5: {{{  destination  }}}   ?    */
	bf	cwBak		/*     If not, backward copy is ok. */
#else
	cmp/hi	r5,r4
	bf.s	cwBak
	shll	r6
#endif
	mov	r4,r0		/* r0: <===== r0 =====>                     */
	sub	r5,r0		/* r4: <== r6 ==> ?    {{{{{  source  }}}}} */
	cmp/ge	r6,r0		/* r5: {{{  destination  }}}                */
	bf	cwFwd		/*     If not, forward copy is necessary.   */

	/* Copy the whole thing backward, word by word */
cwBak:
	mov	r6,r0		/* r0: {offset to buffer tail} + 1 */
cwBakLoop:
	add	#-2,r0
	mov.w	@(r0,r4),r1;
	cmp/pl	r0
#if (CPU==SH7000)
	mov.w	r1,@(r0,r5)
	bt	cwBakLoop
#else
	bt.s	cwBakLoop
	mov.w	r1,@(r0,r5)
#endif
	rts;
	nop

	/* Copy the whole thing forward, word by word */
cwFwd:
	mov	#0,r0
cwFwdLoop:
	mov.w	@(r0,r4),r1;
	mov.w	r1,@(r0,r5)
	add	#2,r0
	cmp/gt	r0,r6
	bt	cwFwdLoop
cwDone:
	rts;
	nop

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

* void bcopyBytes
*     (
*     char *source,		/@ pointer to source buffer      @/
*     char *destination,	/@ pointer to destination buffer @/
*     int   nbytes		/@ number of bytes to copy       @/
*     )

* NOTE:	Backward copy is faster than forward copy, see code below.
*/
	.align	_ALIGN_TEXT
	.type	_bcopyBytes,@function

				/* r4: source      */
				/* r5: destination */
_bcopyBytes:			/* r6: nbytes      */
	cmp/pl	r6
	bf	cbDone
				/* r4:        {{{{{  source  }}}}}} */
	cmp/hi	r5,r4		/* r5: {{{  destination  }}}   ?    */
	bf	cbBak		/*     If not, backward copy is ok. */

	mov	r4,r0		/* r0: <===== r0 =====>                     */
	sub	r5,r0		/* r4: <== r6 ==> ?    {{{{{  source  }}}}} */
	cmp/ge	r6,r0		/* r5: {{{  destination  }}}                */
	bf	cbFwd		/*     If not, forward copy is necessary.   */

	/* Copy the whole thing backward, byte by byte */
cbBak:
	mov	r6,r0		/* r0: {offset to buffer tail} + 1 */
#if (CPU==SH7000)
cbBakLoop:
	add	#-1,r0
	mov.b	@(r0,r4),r1;
	cmp/pl	r0
	mov.b	r1,@(r0,r5)
	bt	cbBakLoop
#else
cbBakLoop:
	dt	r0
	mov.b	@(r0,r4),r1;
	bf.s	cbBakLoop
	mov.b	r1,@(r0,r5)
#endif
	rts;
	nop

	/* Copy the whole thing forward, byte by byte */
cbFwd:
#if (CPU==SH7000)
	mov	#0,r0
cbFwdLoop:
	mov.b	@(r0,r4),r1;
	mov.b	r1,@(r0,r5)
	add	#1,r0
	cmp/gt	r0,r6
	bt	cbFwdLoop
#else
cbFwdLoop:
	mov.b	@r4+,r1;
	dt	r6
	mov.b	r1,@r5
	bf.s	cbFwdLoop
	add	#1,r5
#endif
cbDone:
	rts;
	nop

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

* void bcopy
*     (
*     char *source,		/@ pointer to source buffer      @/
*     char *destination,	/@ pointer to destination buffer @/
*     int   nbytes		/@ number of bytes to copy       @/
*     )

* NOTE:	This routine is USED at boot time.
*	Backward copy is NOT used at boot time.

*   [usec]|
*      40 |    o: bcopy                                                   
*      39 |    x: bcopyBytes ( 1-byte  loop)                                x
*      38 |    c: bcopyBytes (16-bytes loop)                           
*      37 |                                                              x
*      36 |    DVE-SH7032  timexN                                     x
*      35 |    benchmarks                                                    
*      34 |    (4 bytes aligned)                                   x      
*      33 |                                                                
*      32 |                                                     x       
*      31 |              :                                          
*      30 |              :                                   x              c
*      29 |              :                                               c
*      28 |              :                                x                 
*      27 |              :                             x           c  c
*      26 |              :                           
*      25 |              :                          x           c            
*      24 |              :                                   c            
*      23 |              :                       x        c              
*      22 |              :                                             
*      21 |              :                    x        c            
*      20 |              :                          c            
*      19 |              :                 x     c            
*      18 |              :                                 
*      17 |              :              x  c  c                              
*      16 |              :           x                                   o  o
*      15 |              :              c                       o  o  o      
*      14 |              :        x  c                 o  o  o         
*      13 |              :        c           o  o  o                        
*      12 |              :    cx        o  o                        
*      11 |              :        o  o                                    
*      10 |              : cxo o                                       
*	9 |             cxo                                 
*	8 |          co  :                     
*	7 |        c  x  :               
*	6 |     c  o     :               
*	5 |  c     x     :               
*	4 c     o        :               
*	3 |     x        :               
*	2 |  o           :               
*	1 o  x           :               
*	  x--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
*         0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22
*                                                                     [nbytes]
*/
#define	NBYTES_LOW	5	/* use bcopyBytes() if (nbytes <= 5) */

	.align	_ALIGN_TEXT
	.type	_bcopy,@function

				/* r4: source      */
				/* r5: destination */
_bcopy:				/* r6: nbytes      */
	mov	#NBYTES_LOW,r0
	cmp/gt	r0,r6
	bf	_bcopyBytes

	cmp/pl	r6		/* r6: nbytes > 0 ? */
	bf	cbDone
				/* r4: {{{{{  source  }}}}}}          */
	cmp/hi	r4,r5		/* r5:        {{{  destination  }}} ? */
	bf	cFwd		/*     If not, forward copy is ok.    */

	mov	r5,r0		/* r0: <===== r0 =====>                      */
	sub	r4,r0		/* r4: {{{{{  source  }}}}}                  */
	cmp/ge	r6,r0		/* r5: <=== r6 ===>    {{{  destination  }}} */
	bf	cBak		/*     If not, backward copy is necessary.   */

cFwd:				/* forward copy */
	mov	r5,r0
	xor	r4,r0		/*     check alignment mismatch             */
	tst	#0x1,r0
	bf	cFwdByte	/*     bit-0 mismatch, have to do byte copy */
	tst	#0x2,r0
	bf	cFwdWord	/*     bit-1 mismatch, have to do word copy */

	mov	r5,r0
	tst	#0x1,r0		/*     are we on a word boundary? */
	bt	cFwdLongWord
	mov.b	@r4+,r1;	/*     one-byte copy, force word alignment */
	add	#-1,r6
	mov.b	r1,@r5
	add	#1,r5

cFwdLongWord:
	mov	r5,r0
	tst	#0x3,r0		/*     are we on a long boundary? */
	bt	cFwdLongAligned
	mov.w	@r4+,r1;	/*     one-word copy, force long alignment */
	add	#-2,r6
	mov.w	r1,@r5
	add	#2,r5
cFwdLongAligned:
	mova	cFwdLongCopy,r0
	mov	r0,r3
	mov	r6,r0		/* r0: nbytes */
cLong:
	and	#0x3c,r0	/* if r0 = 4 */
	neg	r0,r2		/* r2: -4 */
	shlr	r0		/* r0:  2 */
	sub	r0,r2		/* r2: -6 */
	add	r3,r2
	mov	r6,r0		/* r0: nbytes */
#if (CPU==SH7000 || CPU==SH7600)
	shlr2	r6
	shlr2	r6
	shlr2	r6
#else
	mov	#-6,r1
	shld	r1,r6
#endif
	jmp	@r2;
	add	#1,r6		/* r6: nbytes/64 + 1 */

cBak:				/* backward copy */
	add	r6,r4		/* r4: source      + nbytes */
	add	r6,r5		/* r5: destination + nbytes */
				/* r6: nbytes               */
	mov	r5,r0
	xor	r4,r0		/*     check alignment mismatch             */
	tst	#0x1,r0
	bf	cBakByte	/*     bit-0 mismatch, have to do byte copy */
	tst	#0x2,r0
	bf	cBakWord	/*     bit-1 mismatch, have to do word copy */

	mov	r5,r0
	tst	#0x1,r0		/*     are we on a word boundary? */
	bt	cBakLongWord
	add	#-1,r4		/*     one-byte copy, force word alignment */
	mov.b	@r4,r1;
	add	#-1,r6
	mov.b	r1,@-r5
cBakLongWord:
	mov	r5,r0
	tst	#0x3,r0		/*     are we on a long boundary? */
	bt	cBakLongAligned
	add	#-2,r4		/*     one-word copy, force long alignment */
	mov.w	@r4,r1;
	add	#-2,r6
	mov.w	r1,@-r5
cBakLongAligned:
	mova	cBakLongCopy,r0
	mov	r0,r3
	bra	cLong;
	mov	r6,r0		/* r0: nbytes */

	/* Word copy setup */

cFwdWord:			
	mov	r5,r0
	tst	#0x1,r0		/*     are we on a odd boundary? */
	bt	cFwdWordAligned
	mov.b	@r4+,r1;	/*     one-byte copy, force word alignment */
	add	#-1,r6
	mov.b	r1,@r5
	add	#1,r5
cFwdWordAligned:		/*     here we are on a word boundary */
	mova	cFwdWordCopy,r0
	mov	r0,r3
	mov	r6,r0		/* r0: nbytes */
cWord:
	and	#0x1e,r0	/* if r0 = 2 */
	neg	r0,r2		/* r2: -2 */
	shll	r0		/* r0:  4 */
	sub	r0,r2		/* r2: -6 */
	add	r3,r2
	mov	r6,r0		/* r0: nbytes */
#if (CPU==SH7000 || CPU==SH7600)
	shlr2	r6
	shlr2	r6
	shlr	r6
#else
	mov	#-5,r1
	shld	r1,r6
#endif
	jmp	@r2;
	add	#1,r6		/* r6: nbytes/32 + 1 */

cBakWord:
	mov	r5,r0
	tst	#0x1,r0		/*     are we on a odd boundary? */
	bt	cBakWordAligned
	add	#-1,r4		/*     one-byte copy, force word alignment */
	mov.b	@r4,r1;
	add	#-1,r6
	mov.b	r1,@-r5
cBakWordAligned:		/*     here we are on a word boundary */
	mova	cBakWordCopy,r0
	mov	r0,r3
	bra	cWord;
	mov	r6,r0		/* r0: nbytes */

	/* Byte copy setup */

cFwdByte:
	mova	cFwdByteCopy,r0
	mov	r0,r3
	mov	r6,r0		/* r0: nbytes */
cByte:
	and	#0xf,r0		/* if r0 = 1 */
	shll	r0		/* r0:  2 */
	neg	r0,r2		/* r2: -2 */
	shll	r0		/* r0:  4 */
	sub	r0,r2		/* r2: -6 */
	add	r3,r2
#if (CPU==SH7000 || CPU==SH7600)
	shlr2	r6
	shlr2	r6
#else
	mov	#-4,r1
	shld	r1,r6
#endif
	jmp	@r2;
	add	#1,r6		/* r6: nbytes/16 + 1 */

cBakByte:
	mova	cBakByteCopy,r0
	mov	r0,r3
	bra	cByte;
	mov	r6,r0		/* r0: nbytes */

	/* Forward copy section */

	.align	_ALIGN_TEXT
cFwdLongLoop:
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
	mov.l   @r4+,r1;    mov.l   r1,@r5;    add   #4,r5
cFwdLongCopy:
#if (CPU==SH7000)
	add	#-1,r6
	tst	r6,r6
#else
	dt	r6
#endif
	bf	cFwdLongLoop
	tst	#0x2,r0		/*     nbytes % 4 ? */
	bt	cFwdLongLastByte
	mov.w	@r4+,r1;
	mov.w	r1,@r5
	add	#2,r5
cFwdLongLastByte:
	tst	#0x1,r0		/*     nbytes % 2 ? */
cFwdLastByte:
	bt	cFwdDone
	mov.b	@r4+,r1;
	rts;
	mov.b	r1,@r5

	.align	_ALIGN_TEXT
cFwdWordLoop:
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
	mov.w   @r4+,r1;    mov.w   r1,@r5;    add     #2,r5
cFwdWordCopy:
#if (CPU==SH7000)
	add	#-1,r6
	tst	r6,r6
#else
	dt	r6
#endif
	bf	cFwdWordLoop
	bra	cFwdLastByte;
	tst	#0x1,r0		/*     nbytes % 2 ? */

	.align	_ALIGN_TEXT
cFwdByteLoop:
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
	mov.b   @r4+,r1;    mov.b   r1,@r5;    add     #1,r5
cFwdByteCopy:
#if (CPU==SH7000)
	add	#-1,r6
	tst	r6,r6
#else
	dt	r6
#endif
	bf	cFwdByteLoop
cFwdDone:
	rts;
	nop

	/* Backward copy section */

	.align	_ALIGN_TEXT
cBakLongLoop:
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
	add	#-4,r4;    mov.l   @r4,r1;    mov.l   r1,@-r5
cBakLongCopy:
#if (CPU==SH7000)
	add	#-1,r6
	tst	r6,r6
#else
	dt	r6
#endif
	bf	cBakLongLoop
	tst	#0x2,r0		/*     nbytes % 4 ? */
	bt	cBakLongLastByte
	add	#-2,r4
	mov.w	@r4,r1;
	mov.w	r1,@-r5
cBakLongLastByte:
	tst	#0x1,r0		/*     nbytes % 2 ? */
cBakLastByte:
	bt	cBakDone
	add	#-1,r4
	mov.b	@r4,r1;
	rts;
	mov.b	r1,@-r5

	.align	_ALIGN_TEXT
cBakWordLoop:
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
	add     #-2,r4;    mov.w   @r4,r1;    mov.w   r1,@-r5
cBakWordCopy:
#if (CPU==SH7000)
	add	#-1,r6
	tst	r6,r6
#else
	dt	r6
#endif
	bf	cBakWordLoop
	bra	cBakLastByte;
	tst	#0x1,r0		/*     nbytes % 2 ? */

	.align	_ALIGN_TEXT
cBakByteLoop:
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
	add     #-1,r4;    mov.b   @r4,r1;    mov.b   r1,@-r5
cBakByteCopy:
#if (CPU==SH7000)
	add	#-1,r6
	tst	r6,r6
#else
	dt	r6
#endif
	bf	cBakByteLoop
cBakDone:
	rts;
	nop

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

* void bfill
*     (
*     char *buf,		/@ pointer to buffer              @/
*     int   nbytes,		/@ number of bytes to fill        @/
*     int   ch			/@ char with which to fill buffer @/
*     )

* NOTE:	This routine is USED at boot time.
*
*
*   [usec]|
*      25 |    o: bfill (16-longs loop)                                     x
*      24 |    v: bfill ( 1-longs loop)                                  x
*      23 |    x: bfillBytes                                          x  x
*      22 |                                                        x  x
*      21 |                                                        x
*      20 |    DVE-SH7032  timexN                               x
*      19 |    benchmarks                                    x
*      18 |                                               x
*      17 |                 :                          x
*      16 |                 :                       x                       v
*      15 |                 :                    x              v        v
*      14 |                 :                 x  x  v        v        v
*      13 |                 :           v  x  x  v        v        v        v
*      12 |                 :           v  x           v        v  v
*      11 |                 :        v  x     v        v        v       vo  o
*      10 |                 :     v  x     v       vo  o  o vo  o  o vo  o  o
*	9 |                 :  vo xo o vo  o  o vo  o  o  v
*	8 |                 :  xo o  o  o     v
*	7 |              o vxo           
*	6 |             vxo :            
*	5 |          vxo    :            
*	4 |        vo       :            
*	3 |     vo x        :            
*	2 |  vo x           :            
*	1 vo x              :            
*	  x--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
*         0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22
*                                                                     [nbytes]
*/
	.align	_ALIGN_TEXT
	.type	_bfill,@function

				/* r4: buf    */
				/* r5: nbytes */
_bfill:				/* r6: ch     */
	mov	#6,r0
	cmp/gt	r0,r5
	bf	_bfillBytes	/* if (nbytes <= 6), do byte fill */

	cmp/pl	r5
	bf	fbDone		/* if (nbytes <= 0), then we are done */

	mov	r4,r0
	add	r5,r0		/* r0: buf + nbytes */
	tst	#0x1,r0		/*     are we on an word boundary?        */
	bt	fbWord
	mov.b	r6,@-r0		/*     fill one-byte, force word boundary */
	add	#-1,r5
fbWord:				/*    byte3  byte2  byte1  byte0 */
	extu.b	r6,r6		/* r6: 0x00 | 0x00 | 0x00 | (ch) */
	swap.b	r6,r1		/* r1: 0x00 | 0x00 | (ch) | 0x00 */
	or	r1,r6		/* r6: 0x00 | 0x00 | (ch) | (ch) */

	tst	#0x3,r0		/*     are we on an long boundary?        */
	bt	fbLong
	mov.w	r6,@-r0		/*     fill one-word, force long boundary */
	add	#-2,r5
fbLong:				/*    byte3  byte2  byte1  byte0 */
	swap.w	r6,r1		/* r1: (ch) | (ch) | 0x00 | 0x00 */
	or	r1,r6		/* r6: (ch) | (ch) | (ch) | (ch) */

	mov	r0,r7		/* r7: (end of buffer) + 1 */
	mov	r5,r0		/* r0: nbytes */
	and	#0x3c,r0	/* if (r0 == 4) */
	neg	r0,r2		/* r2: -4 */
	shar	r2		/* r2: -2 */
	mova	fbStart,r0
	add	r0,r2
	mov	r5,r0		/* r0: nbytes */
#if (CPU==SH7000 || CPU==SH7600)
	shlr2	r5
	shlr2	r5
	shlr2	r5
#else
	mov	#-6,r1
	shld	r1,r5
#endif
	jmp	@r2;
	add	#1,r5		/* r5: nbytes/64 + 1 */

	.align	_ALIGN_TEXT
fbLoop:
	mov.l r6,@-r7;  mov.l r6,@-r7;  mov.l r6,@-r7;  mov.l r6,@-r7
	mov.l r6,@-r7;  mov.l r6,@-r7;  mov.l r6,@-r7;  mov.l r6,@-r7
	mov.l r6,@-r7;  mov.l r6,@-r7;  mov.l r6,@-r7;  mov.l r6,@-r7
	mov.l r6,@-r7;  mov.l r6,@-r7;  mov.l r6,@-r7;  mov.l r6,@-r7
fbStart:
#if (CPU==SH7000)
	add	#-1,r5
	tst	r5,r5
#else
	dt	r5
#endif
	bf	fbLoop
	tst	#0x2,r0		/*     nbytes % 4 ? */
	bt	fbLastByte
	mov.w	r6,@-r7
fbLastByte:
	tst	#0x1,r0		/*     nbytes % 2 ? */
	bt	fbDone
	mov.b	r6,@-r7
fbDone:
	rts;
	nop

#if		FALSE
_bfill:		mov	#6,r0		/*** THIS BFILL IS SMALL, BUT SLOW. ***/
		cmp/gt	r0,r5
		bf	_bfillBytes	/* if (6 >= nbytes), do byte fill */
		cmp/pl	r5
		bf	fbDone		/* if (nbytes <= 0), then we are done */
		mov	r4,r0
		bra	fbTailChk;
		add	r5,r0		/* r0: buf + nbytes */
fbTailLoop:	mov.b	r6,@-r0
fbTailChk:	tst	#3,r0
		bf	fbTailLoop
		mov	r0,r7		/* r7: end of buffer */
		bra	fbHeadChk;
		mov	r4,r0
fbHeadLoop:	mov.b	r6,@r0
		add	#1,r0
fbHeadChk:	tst	#3,r0		/* r0: start of buffer */
		bf	fbHeadLoop	/*    byte3  byte2  byte1  byte0 */
fbBody:		extu.b	r6,r6		/* r6: 0x00 | 0x00 | 0x00 | (ch) */
		swap.b	r6,r1		/* r1: 0x00 | 0x00 | (ch) | 0x00 */
		or	r1,r6		/* r6: 0x00 | 0x00 | (ch) | (ch) */
		swap.w	r6,r1		/* r1: (ch) | (ch) | 0x00 | 0x00 */
		bra	fbBodyChk;
		or	r1,r6		/* r6: (ch) | (ch) | (ch) | (ch) */
fbBodyLoop:	mov.l	r6,@-r7
fbBodyChk:	cmp/hi	r0,r7
		bt	fbBodyLoop
fbDone:		rts;
		nop
#endif		/* FALSE */

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

* void bfillBytes
*     (
*     char *buf,	/@ pointer to buffer              @/
*     int   nbytes,	/@ number of bytes to fill        @/
*     int   ch		/@ char with which to fill buffer @/
*     )

* NOTE:  This routine is not used at boot time.  Be careful!
*/
	.align	_ALIGN_TEXT
	.type	_bfillBytes,@function

				/* r4: buf    */
_bfillBytes:			/* r5: nbytes */
	cmp/pl	r5
	bf	fby2
#if (CPU==SH7000)
	add	r4,r5		/* r5: buf + nbytes */
fby1:	mov.b	r6,@-r5		/* r6: ch           */
	cmp/hi	r4,r5
	bt	fby1
#else
	mov	r5,r0
fby1:	dt	r0
	bf.s	fby1
	mov.b	r6,@(r0,r4)
#endif
fby2:	rts;
	nop

#endif	/* !PORTABLE */
