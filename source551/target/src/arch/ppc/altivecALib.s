/* altivecLib.s  - altivec assembly routines */

/* Copyright 2000 - 2001 Wind River, Inc */

/*
modification history
--------------------
01i,23oct01,jab  changed comments from as-style to c-style
01h,25sep01,yvp  Fix SPR62760: Use _WRS_TEXT_SEG_START macro instead of .align
01g,08may01,pch  Add assembler abstractions (FUNC_EXPORT, FUNC_BEGIN, etc.)
01f,24apr01,kab  Fixed restore of vrsave
01e,12apr01,kab  Fixed restore of MSR
01d,11apr01,pcs  Code Review Changes.
01c,28mar01,pcs  Make pnumonics compatable with gcc style.
01b,11Jan01,ksn  modified sysVecRegRead and sysVecRegWrite (teamf1)
01a,12Dec00,mno  created (teamf1)
*/

/* includes */

#define _ASMLANGUAGE
#include "vxWorks.h"
#include "altivecLib.h"

         /* globals */
        FUNC_EXPORT(altivecSave)
        FUNC_EXPORT(altivecRestore)

        _WRS_TEXT_SEG_START

/**************************************************************************
* altivecSave -
* This routine writes the contents of Vector file register to the specified
* memory.
* 
* void altivecSave (ALTIVEC_CONTEXT * pAltiCtx)
*/

FUNC_BEGIN(altivecSave)  
        mfmsr  p1                       /*  load MSR             */
        mr     p2, p1                   /*  Save the MSR read.   */
        oris   p2, p2, _PPC_MSR_VEC     /*  set ALTIVEC Bit      */
        sync                       
        mtmsr  p2                       /*  restore MSR          */
        sync

        mfspr  p2,  VRSAVE_REG
        stw    p2, VRSAVE_OFFSET(p0)    /*  Save vrsave register.  */
        sync

        stvx    v0, 0, p0
        addi    p3, p0, AVX_OFFSET(1)

        addi  p4,p0,VSCR_OFFSET
        sync
        mfvscr v0
        sync
        stvx    v0,0,p4

        lvx     v0,0,p0                 /* Restore v0 */

        stvx    v1, 0,  p3
        addi    p3, p0, AVX_OFFSET(2)
        stvx    v2, 0,  p3
        addi    p3, p0, AVX_OFFSET(3)
        stvx    v3, 0,  p3
        addi    p3, p0, AVX_OFFSET(4)
        stvx    v4, 0,  p3
        addi    p3, p0, AVX_OFFSET(5)
        stvx    v5, 0,  p3
        addi    p3, p0, AVX_OFFSET(6)
        stvx    v6, 0,  p3
        addi    p3, p0, AVX_OFFSET(7)
        stvx    v7, 0,  p3
        addi    p3, p0, AVX_OFFSET(8)
        stvx    v8, 0,  p3
        addi    p3, p0, AVX_OFFSET(9) 
        stvx    v9, 0,  p3
        addi    p3, p0, AVX_OFFSET(10)
        stvx    v10, 0,  p3
        addi    p3, p0, AVX_OFFSET(11)
        stvx    v11, 0,  p3
        addi    p3, p0, AVX_OFFSET(12)
        stvx    v12, 0,  p3
        addi    p3, p0, AVX_OFFSET(13)
        stvx    v13, 0,  p3
        addi    p3, p0, AVX_OFFSET(14)
        stvx    v14, 0, p3
        addi    p3, p0, AVX_OFFSET(15)
        stvx    v15, 0, p3
        addi    p3, p0, AVX_OFFSET(16)
        stvx    v16, 0, p3
        addi    p3, p0, AVX_OFFSET(17)
        stvx    v17, 0, p3
        addi    p3, p0, AVX_OFFSET(18)
        stvx    v18, 0, p3
        addi    p3, p0, AVX_OFFSET(19)
        stvx    v19, 0, p3
        addi    p3, p0, AVX_OFFSET(20)
        stvx    v20, 0, p3
        addi    p3, p0, AVX_OFFSET(21)
        stvx    v21, 0, p3
        addi    p3, p0, AVX_OFFSET(22)
        stvx    v22, 0, p3
        addi    p3, p0, AVX_OFFSET(23)
        stvx    v23, 0, p3
        addi    p3, p0, AVX_OFFSET(24)
        stvx    v24, 0, p3
        addi    p3, p0, AVX_OFFSET(25)
        stvx    v25, 0, p3
        addi    p3, p0, AVX_OFFSET(26)
        stvx    v26, 0, p3
        addi    p3, p0, AVX_OFFSET(27)
        stvx    v27, 0, p3
        addi    p3, p0, AVX_OFFSET(28)
        stvx    v28, 0, p3
        addi    p3, p0, AVX_OFFSET(29)
        stvx    v29, 0, p3
        addi    p3, p0, AVX_OFFSET(30)
        stvx    v30, 0, p3
        addi    p3, p0, AVX_OFFSET(31)
        stvx    v31, 0, p3
        mtmsr  p1                        /*  restore MSR from function entry */
retok:  sync
        blr
FUNC_END(altivecSave)  


/**************************************************************************
* altivecRestore -
* This routine writes to the vectore Registers from the memory specified. 
*
* void altivecRestore (ALTIVEC_CONTEXT * pAltiCtx)
*/

FUNC_BEGIN(altivecRestore)  
        mfmsr  p1                       /*  load MSR             */
        mr     p2, p1                   /*  Save the MSR read.   */
        oris   p2, p2, _PPC_MSR_VEC     /*  set ALTIVEC Bit      */
        sync
        mtmsr  p2                       /*  restore MSR          */
        sync

        lwz    p2, VRSAVE_OFFSET(p0)    /*  Restore vrsave register.  */
        mtspr  VRSAVE_REG, p2
        sync

        addi  p4,p0,VSCR_OFFSET
        lvx    v0, 0, p4         
        mtvscr v0                       /*  Restore vscr register.  */
        sync

        lvx     v0, 0, p0
        addi    p3, p0, AVX_OFFSET(1)
        lvx     v1, 0, p3
        addi    p3, p0, AVX_OFFSET(2)
        lvx     v2, 0, p3
        addi    p3, p0, AVX_OFFSET(3)
        lvx     v3, 0, p3
        addi    p3, p0, AVX_OFFSET(4)
        lvx     v4, 0, p3
        addi    p3, p0, AVX_OFFSET(5)
        lvx     v5, 0, p3
        addi    p3, p0, AVX_OFFSET(6)
        lvx     v6, 0, p3
        addi    p3, p0, AVX_OFFSET(7)
        lvx     v7, 0, p3
        addi    p3, p0, AVX_OFFSET(8)
        lvx     v8, 0, p3
        addi    p3, p0, AVX_OFFSET(9)
        lvx     v9, 0, p3
        addi    p3, p0, AVX_OFFSET(10)
        lvx     v10, 0, p3
        addi    p3, p0, AVX_OFFSET(11)
        lvx     v11, 0, p3
        addi    p3, p0, AVX_OFFSET(12)
        lvx     v12, 0, p3
        addi    p3, p0, AVX_OFFSET(13)
        lvx     v13, 0, p3
        addi    p3, p0, AVX_OFFSET(14)
        lvx     v14, 0, p3
        addi    p3, p0, AVX_OFFSET(15)
        lvx     v15, 0, p3
        addi    p3, p0, AVX_OFFSET(16)
        lvx     v16, 0, p3
        addi    p3, p0, AVX_OFFSET(17)
        lvx     v17, 0, p3
        addi    p3, p0, AVX_OFFSET(18)
        lvx     v18, 0, p3
        addi    p3, p0, AVX_OFFSET(19)
        lvx     v19, 0, p3
        addi    p3, p0, AVX_OFFSET(20)
        lvx     v20, 0, p3
        addi    p3, p0, AVX_OFFSET(21)
        lvx     v21, 0, p3
        addi    p3, p0, AVX_OFFSET(22)
        lvx     v22, 0, p3
        addi    p3, p0, AVX_OFFSET(23)
        lvx     v23, 0, p3
        addi    p3, p0, AVX_OFFSET(24)
        lvx     v24, 0, p3
        addi    p3, p0, AVX_OFFSET(25)
        lvx     v25, 0, p3
        addi    p3, p0, AVX_OFFSET(26)
        lvx     v26, 0, p3
        addi    p3, p0, AVX_OFFSET(27)
        lvx     v27, 0, p3
        addi    p3, p0, AVX_OFFSET(28)
        lvx     v28, 0, p3
        addi    p3, p0, AVX_OFFSET(29)
        lvx     v29, 0, p3
        addi    p3, p0, AVX_OFFSET(30)
        lvx     v30, 0, p3
        addi    p3, p0, AVX_OFFSET(31)
        lvx     v31, 0, p3
        mtmsr  p1                        /*  restore MSR from function entry */
restretok:  sync
        blr
FUNC_END(altivecRestore)  
