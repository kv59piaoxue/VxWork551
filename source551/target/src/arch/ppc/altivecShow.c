/* altivecpShow.c - altivec show routines */

/* Copyright 1984-1994 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,07mar02,pcs  Install pointer to altivecTaskRegsShow only for Altivec aware
                 processors.
01a,29mar01,pcs  Implement code review suggestions.
*/

/*
DESCRIPTION
This library provides the routines necessary to show a task's optional 
altivec context.  To use this facility, it must first be
installed using altivecShowInit(), which is called automatically
when the altivec show facility is configured into VxWorks
using either of the following methods:
.iP
If you use the configuration header files, define
INCLUDE_SHOW_ROUTINES in config.h.
.iP
.LP

This library enhances task information routines, such as ti(), to display
the altivec context.

INCLUDE FILES: altivecLib.h 

SEE ALSO: altivecLib
*/

#include "vxWorks.h"
#include "stdio.h"
#include "regs.h"
#include "altivecLib.h"
#include "private/funcBindP.h"

/* global variables */


/******************************************************************************
*
* altivecShowInit - initialize the altivec show facility
*
* This routine links the altivec show facility into the VxWorks system.
* It is called automatically when the altivec show facility is
* configured into VxWorks using either of the following methods:
* .iP
* If you use the configuration header files, define
* INCLUDE_SHOW_ROUTINES in config.h.
* .iP
* If you use the Tornado project facility, select INCLUDE_SHOW_ROUTINES.
*
* RETURNS: N/A
*/

void altivecShowInit (void)
    {
       if ( altivecProbe() == OK )
       {
          /* avoid direct coupling with altivecShow with this global variable */

          _func_altivecTaskRegsShow = (FUNCPTR) altivecTaskRegsShow;
       }
    }

/*******************************************************************************
*
* altivecTaskRegsShow - print the contents of a task's altivec registers
*
* This routine prints to standard output the contents of a task's
* altivec registers.
*
* RETURNS: N/A
*/

void altivecTaskRegsShow
    (
    int task		/* task to display altivec registers for */
    )
    {
    ALTIVEC_CONTEXT *	pRegs;
    WIND_TCB *		pTcb;
    int			reg;
    UINT32 *		pInt;
    
    pTcb = taskTcb (task);
    pRegs = ALTIVEC_CONTEXT_GET (pTcb);

    if (pRegs)
        {
    
    printf ("vrsave=%#x vscr=%#x\n", pRegs->vrsave, pRegs->vscr[3]);

    for (reg=0; reg<32; reg++)
        {
        pInt = (UINT32 *)&pRegs->vrfile[reg];
        printf ("vreg%02d: 0x%08x_%08x_%08x_%08x\n",
                reg, pInt[0], pInt[1], pInt[2], pInt[3]);
        }
     } else
       {
        printf ("No AltiVec Context\n");

       }
    }


