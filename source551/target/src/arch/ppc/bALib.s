/* bALib.s - buffer manipulation library assembly language routines */

/* Copyright 1984-1995 Wind River Systems, Inc. */

/*
modification history
--------------------
01d,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01c,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01b,17apr01,dtr  Making bfill etc into funtions fot linking.
01a,27apr95,caf  made bcopy() use cr6 instead of nonvolatile cr2.
01a,30jan95,caf  created.
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

	/* functions */

	FUNC_EXPORT(bcopy)
	FUNC_EXPORT(bcopyBytes)
	FUNC_EXPORT(bcopyWords)
	FUNC_EXPORT(bcopyLongs)
	FUNC_EXPORT(bfill)
	FUNC_EXPORT(bfillBytes)
	FUNC_EXPORT(swab)

	_WRS_TEXT_SEG_START
	
/*******************************************************************************
*
* bcopy - copy one buffer to another
*
* This routine copies the first <nbytes> characters from <source> to
* <destination>.  Overlapping buffers are handled correctly.  Copying is done
* in the most efficient way possible, which may include long-word, or even
* multiple-long-word moves on some architectures.  In general, the copy
* will be significantly faster if both buffers are long-word aligned.
* (For copying that is restricted to byte, word, or long-word moves, see
* the manual entries for bcopyBytes(), bcopyWords(), and bcopyLongs().)
*
* RETURNS: N/A
*
* SEE ALSO: bcopyBytes(), bcopyWords(), bcopyLongs()
*
* NOMANUAL - manual entry in bLib

* void bcopy
*     (
*     const char *source,         /@ pointer to source buffer      @/
*     char *destination,          /@ pointer to destination buffer @/
*     int nbytes                  /@ number of bytes to copy       @/
*     )

*/

FUNC_LABEL(bcopy)

	cmpwi	p2,0
	beqlr			/* if (<nbytes> == 0) we're done            */
	cmplw	p0,p1
	beqlr			/* if (<dst> == <src>) we're done           */
      	cmpwi	cr6,p2,8
	bgt	bcfwd		/* if (<src> > <dst>) copy forward          */

	/* copy reverse */

	add	p0,p0,p2	/* <src> += <nbytes>                        */
	add	p1,p1,p2	/* <dst> += <nbytes>                        */
      	blt	cr6,bcrBCopy	/* if (<nbytes> < 8) byte copy reverse   */

	andi.	r11,p0,3
	andi.	r12,p1,3
	xor.	p5,r11,r12	/* p5 = ((<src> & 3) ^ (<dst> & 3)) */

	/* p5 reflects relative alignment of <src> and <drv> (0 - 3) */

	beq	bcrL1		/* if (p5 == 0) then reverse longword copy  */
      	cmpwi	p5,2
	beq	bcrH1		/* if (p5 == 2) then reverse halfword copy  */
      	b	bcrBCopy	/* ...otherwise reverse byte copy           */

	/* longword reverse copy */

bcrL1:	cmpwi	r11,0		/* already longword aligned?                */
	beq	bcrL3

	/* copy 1 - 3 bytes to align on longword boundary */

	mtctr	r11

bcrL2:  lbzu    p4,-1(p0)	/* load...                                  */
	addi	p2,p2,-1	/* -- <nbytes>                              */
        stbu    p4,-1(p1)	/* ...store                                 */
        bdnz    bcrL2           /* decrement CTR and branch if != 0         */

bcrL3:  andi.	p3,p2,3		/* p3 = (<nbytes> & 3)                      */
        srwi	p2,p2,2		/* <nbytes> = (<nbytes> / 4)                */

bcrLCopy:

	/*
         * Entry point from bcopyLongs()
         *
         *   p0 = source pointer
         *   p1 = destination pointer
         *   p2 = number of longwords (1 or more)
         *   p3 = number of trailing bytes (0 to 3)
	 */

        mtctr   p2		/* CTR = <nlongs>                           */

bcrLGO: lwzu    p4,-4(p0)	/* load...                                  */
        stwu    p4,-4(p1)	/* ...store                                 */
        bdnz    bcrLGO          /* decrement CTR and branch if != 0         */

       	or.	p2,p3,p3
	beqlr			/* if (p3 == 0) we're done                  */

bcrBCopy:

	/*
         * Entry point from bcopyBytes()
         *
         *   p0 = source pointer
         *   p1 = destination pointer
         *   p2 = number of bytes (1 or more)
	 */

        mtctr   p2		/* CTR = <nbytes>                           */

bcrBGO: lbzu    p4,-1(p0)	/* load...                                  */
        stbu    p4,-1(p1)	/* ...store                                 */
        bdnz    bcrBGO          /* decrement CTR and branch if != 0         */

	blr			/* return                                   */

	/* halfword reverse copy */

bcrH1:	andi.	r11,r11,1	/* already halfword aligned?                */
	beq	bcrH2

	/* copy one byte to align on halfword boundary */

	lbzu    p4,-1(p0)	/* load...                                  */
	addi	p2,p2,-1	/* -- <nbytes>                              */
        stbu    p4,-1(p1)	/* ...store                                 */
	
bcrH2:  andi.	p3,p2,1		/* p3 = (<nbytes> & 1)                      */
        srwi	p2,p2,1		/* <nbytes> = (<nbytes> / 2)                */

bcrHCopy:

	/*
         * Entry point from bcopyWords()
         *
         *   p0 = source pointer
         *   p1 = destination pointer
         *   p2 = number of halfwords (1 or more)
         *   p3 = number of trailing bytes (0 to 1)
	 */

        mtctr   p2		/* CTR = <nwords>                           */

bcrHGO:	lhzu    p4,-2(p0)	/* load...                                  */
        sthu    p4,-2(p1)	/* ...store                                 */
        bdnz    bcrHGO          /* decrement CTR and branch if != 0         */

       	cmplwi	p3,0
	beqlr			/* if (p3 == 0) we're done                  */

	/* copy last byte */

	lbz     p4,-1(p0)	/* load...                                  */
        stb     p4,-1(p1)	/* ...store                                 */
	blr			/* finally done                             */

	/* copy forward */

bcfwd:	blt	cr6,bcfBCopy	/* if (<nbytes> < 8) byte copy forward   */

	andi.	r11,p0,3
	andi.	r12,p1,3
	xor.	p5,r11,r12	/* p5 = ((<src> & 3) ^ (<dst> & 3)) */

	/* p5 reflects relative alignment of <src> and <drv> (0 - 3) */

	beq	bcfL1		/* if (p5 == 0) then forward longword copy  */
      	cmpwi	p5,2
	beq	bcfH1		/* if (p5 == 2) then forward halfword copy  */
      	b	bcfBCopy	/* ...otherwise forward byte copy           */

	/* forward longword copy */

bcfL1:	cmpwi	r11,0		/* already longword aligned?                */
	beq	bcfL3

	/* copy 1 - 3 bytes to align on longword boundary */

bcfL2:  lbzu    p4,0(p0)	/* load...                                  */
	addi	p2,p2,-1	/* -- <nbytes>                              */
	addi	r11,r11,1	/* ++ r11                                   */
        stbu    p4,0(p1)	/* ...store                                 */
	addi	p0,p0,1		/* ++ <src>                                 */
	addi	p1,p1,1		/* ++ <dst>                                 */
      	cmpwi	r11,4		/* longword aligned?                        */
        bne     bcfL2
	
bcfL3:  andi.	p3,p2,3		/* p3 = (<nbytes> & 3)                      */
        srwi	p2,p2,2		/* p2 = (<nbytes> / 4)                      */

bcfLCopy:

	/*
         * Entry point from bcopyLongs()
         *
         *   p0 = source pointer
         *   p1 = destination pointer
         *   p2 = number of longwords (1 or more)
         *   p3 = number of trailing bytes (0 to 3)
	 */

	addi    p0,p0,-4	/* <src> -= 4                               */
	addi    p1,p1,-4	/* <dst> -= 4                               */
	mtctr   p2		/* CTR = <nlongs>                           */

bcfLGO: lwzu    p4,4(p0)	/* load...                                  */
	stwu    p4,4(p1)	/* ...store                                 */
	bdnz    bcfLGO          /* decrement CTR and branch if != 0         */

	or.	p2,p3,p3
	beqlr			/* if (p3 == 0) we're done                  */
	addi    p0,p0,4		/* <src> += 4                               */
	addi    p1,p1,4		/* <dst> += 4                               */

bcfBCopy:

	/*
         * Entry point from bcopyBytes()
         *
         *   p0 = source pointer
         *   p1 = destination pointer
         *   p2 = number of bytes (1 or more)
	 */

	addi    p0,p0,-1	/* <src> -= 1                               */
	addi    p1,p1,-1	/* <dst> -= 1                               */
        mtctr   p2		/* CTR = <nbytes>                           */

bcfBGO: lbzu    p4,1(p0)	/* load...                                  */
        stbu    p4,1(p1)	/* ...store                                 */
        bdnz    bcfBGO          /* decrement CTR and branch if != 0         */

	blr			/* return                                   */

	/* halfword forward copy */

bcfH1:	andi.	r11,r11,1	/* already halfword aligned?                */
	beq	bcfH2

	/* copy one byte to align on halfword boundary */

	lbzu    p4,0(p0)	/* load...                                  */
	addi	p2,p2,-1	/* -- <nbytes>                              */
        stbu    p4,0(p1)	/* ...store                                 */
	addi    p0,p0,1		/* <src> += 1                               */
	addi    p1,p1,1		/* <dst> += 1                               */
	
bcfH2:  andi.	p3,p2,1		/* p3 = (<nbytes> & 1)                      */
        srwi	p2,p2,1		/* <nbytes> = (<nbytes> / 2)                */

bcfHCopy:

	/*
         * Entry point from bcopyWords()
         *
         *   p0 = source pointer
         *   p1 = destination pointer
         *   p2 = number of halfwords (1 or more)
         *   p3 = number of trailing bytes (0 to 1)
	 */

	addi    p0,p0,-2	/* <src> -= 2                               */
	addi    p1,p1,-2	/* <dst> -= 2                               */
        mtctr   p2		/* CTR = <nwords>                           */

bcfHGO:	lhzu    p4,2(p0)	/* load...                                  */
        sthu    p4,2(p1)	/* ...store                                 */
        bdnz    bcfHGO          /* decrement CTR and branch if != 0         */

       	cmplwi	p3,0
	beqlr			/* if (p3 == 0) we're done                  */

	/* copy last byte */

	lbz     p4,2(p0)	/* load...                                  */
        stb     p4,2(p1)	/* ...store                                 */
	blr			/* finally done                             */

/*******************************************************************************
*
* bcopyBytes - copy one buffer to another one byte at a time
*
* This routine copies the first <nbytes> characters from <source> to
* <destination> one byte at a time.  This may be desirable if a buffer can
* only be accessed with byte instructions, as in certain byte-wide
* memory-mapped peripherals.
*
* RETURNS: N/A
*
* SEE ALSO: bcopy()
*
* NOMANUAL - manual entry in bLib

* void bcopyBytes
*     (
*     char *source,       /@ pointer to source buffer      @/
*     char *destination,  /@ pointer to destination buffer @/
*     int nbytes          /@ number of bytes to copy       @/
*     )

*/

FUNC_LABEL(bcopyBytes)

	cmpwi	p2,0		/* <nbytes> == 0?                           */
	beqlr			/* if so, we're done                        */
	cmpw	p0,p1		/* <dst> == <src>?                          */
	beqlr			/* if so, we're done                        */
	bgt	bcfBCopy	/* forward byte copy                        */
	add	p0,p0,p2	/* <src> += <nbytes>                        */
	add	p1,p1,p2	/* <dst> += <nbytes>                        */
	b	bcrBCopy	/* reverse byte copy                        */

/*******************************************************************************
*
* bcopyWords - copy one buffer to another one word at a time
*
* This routine copies the first <nwords> words from <source> to <destination>
* one word at a time.  This may be desirable if a buffer can only be accessed
* with word instructions, as in certain word-wide memory-mapped peripherals.
* The source and destination must be word-aligned.
*
* RETURNS: N/A
*
* SEE ALSO: bcopy()
*
* NOMANUAL - manual entry in bLib

* void bcopyWords
*     (
*     char *source,       /@ pointer to source buffer      @/
*     char *destination,  /@ pointer to destination buffer @/
*     int nwords          /@ number of words to copy       @/
*     )

*/

FUNC_LABEL(bcopyWords)

	cmpwi	p2,0		/* <nwords> == 0?                           */
	beqlr			/* if so, we're done                        */
	cmpw	p0,p1		/* <dst> == <src>?                          */
	beqlr			/* if so, we're done                        */
	li	p3,0		/* for bcfHCopy or bcrHCopy                 */
	bgt	bcfHCopy	/* forward halfword copy                    */
	slwi	r11,p2,1
	add	p0,p0,r11	/* <src> += (<nwords> * 2)                  */
	add	p1,p1,r11	/* <dst> += (<nwords> * 2)                  */
	b	bcrHCopy	/* reverse halfword copy                    */

/*******************************************************************************
*
* bcopyLongs - copy one buffer to another one long word at a time
*
* This routine copies the first <nlongs> characters from <source> to
* <destination> one long word at a time.  This may be desirable if a buffer
* can only be accessed with long instructions, as in certain long-word-wide
* memory-mapped peripherals.  The source and destination must be
* long-aligned.
*
* RETURNS: N/A
*
* SEE ALSO: bcopy()
*
* NOMANUAL - manual entry in bLib

* void bcopyLongs
*     (
*     char *source,       /@ pointer to source buffer      @/
*     char *destination,  /@ pointer to destination buffer @/
*     int nlongs          /@ number of longs to copy       @/
*     )

*/

FUNC_LABEL(bcopyLongs)

	cmpwi	p2,0		/* <nlongs> == 0?                           */
	beqlr			/* if so, we're done                        */
	cmpw	p0,p1		/* <dst> == <src>?                          */
	beqlr			/* if so, we're done                        */
	li	p3,0		/* for bcfLCopy or bcrLCopy                 */
	bgt	bcfLCopy	/* forward longword copy                    */
	slwi	r11,p2,2
	add	p0,p0,r11	/* <src> += (<nwords> * 4)                  */
	add	p1,p1,r11	/* <dst> += (<nwords> * 4)                  */
	b	bcrLCopy	/* reverse longword copy                    */

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
* SEE ALSO: bfillBytes()
*
* NOMANUAL - manual entry in bLib

* void bfill
*     (
*     FAST char *buf,           /@ pointer to buffer              @/
*     int nbytes,               /@ number of bytes to fill        @/
*     FAST int ch               /@ char with which to fill buffer @/
*     )

*/

FUNC_LABEL(bfill)

      	cmpwi	p1,12
	blt	bffBFill	/* if (<nbytes> < 12) just copy bytes       */
	andi.	r11,p0,3	/* r11 = (<dst> & 3)                        */
	beq	bffLFill        /* if already aligned go fill longs         */

	/* fill 1 - 3 bytes to align on longword boundary */

bffL1:	addi	p1,p1,-1	/* -- <nbytes>                              */
	addi	r11,r11,1	/* ++ r11                                   */
        stbu    p2,0(p0)	/* ...store                                 */
	addi	p0,p0,1		/* ++ <dst>                                 */
      	cmpwi	r11,4		/* longword aligned?                        */
        bne     bffL1

	/* fill longs */

bffLFill:
	andi.	p2,p2,0xff
	slwi	p5,p2,8
	or	p2,p2,p5
	slwi	p5,p2,16
	or	p2,p2,p5	/* p2 now has byte repeated four times      */
	
	srwi	p3,p1,2		/* p3 = (<nbytes> / 4)                      */
	andi.	p1,p1,3		/* p1 = (<nbytes> & 3)                      */

        mtctr   p3
	addi	p0,p0,-4

bffLGO: stwu    p2,4(p0)	/* ...store                                 */
        bdnz    bffLGO          /* decrement CTR and branch if != 0         */

	addi	p0,p0,4

	/* FALL THROUGH */

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
* SEE ALSO: bfill()
*
* NOMANUAL - manual entry in bLib

* void bfillBytes
*     (
*     FAST char *buf,        /@ pointer to buffer              @/
*     int nbytes,            /@ number of bytes to fill        @/
*     FAST int ch            /@ char with which to fill buffer @/
*     )

*/

FUNC_LABEL(bfillBytes)

bffBFill:

	cmpwi	p1,0		/* <nbytes> == 0?                           */
	beqlr			/* if so, we're done                        */
	mtctr   p1		/* CTR = <nbytes>                           */
	addi	p0,p0,-1

bffBGO: stbu    p2,1(p0)	/* ...store                                 */
	bdnz    bffBGO		/* decrement CTR and branch if != 0         */

	blr                     /* return                                   */

/*******************************************************************************
*
* swab - swap bytes
*
* This routine gets the specified number of bytes from <source>,
* exchanges the adjacent even and odd bytes, and puts them in <destination>.
* The buffers <source> and <destination> should not overlap.
* It is an error for <nbytes> to be odd.
*
* RETURNS: N/A
*
* NOMANUAL - manual entry in bLib

* void swab
*     (
*     char *source,               /@ pointer to source buffer      @/
*     char *destination,          /@ pointer to destination buffer @/
*     int nbytes                  /@ number of bytes to exchange   @/
*     )

*/

FUNC_LABEL(swab)
	cmpwi	p2,0		/* <nbytes> = 0?                            */
	beqlr			/* if so, we're done                        */
	srwi	p2,p2,1		/* <nbytes> was supposed to be even         */
	li	r11,0		/* r11 is index, start at zero              */
        mtctr   p2              /* CTR = (<nbytes> >> 1)                    */
swloop:	lhbrx   r12,p0,r11	/* load byte-reversed...                    */
        sthx    r12,p1,r11	/* ...store                                 */
	addi	r11,r11,2	/* update index                             */
        bdnz    swloop		/* decrement CTR and branch if != 0         */
        blr

#endif	/* !PORTABLE */
