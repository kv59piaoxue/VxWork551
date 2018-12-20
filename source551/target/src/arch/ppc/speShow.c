/* speShow.c - spe show routines */

/* Copyright 1984-1994 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,17oct02,dtr  Correcting register display.
01b,07mar02,pcs  Install pointer to speTaskRegsShow only for Spe aware
                 processors.
01a,29mar01,pcs  Implement code review suggestions.
*/

/*
DESCRIPTION
This library provides the routines necessary to show a task's optional 
spe context.  To use this facility, it must first be
installed using speShowInit(), which is called automatically
when the spe show facility is configured into VxWorks
using either of the following methods:
.iP
If you use the configuration header files, define
INCLUDE_SHOW_ROUTINES in config.h.
.iP
.LP

This library enhances task information routines, such as ti(), to display
the spe context.

INCLUDE FILES: speLib.h 

SEE ALSO: speLib
*/

#include "vxWorks.h"
#include "stdio.h"
#include "regs.h"
#include "speLib.h"
#include "private/funcBindP.h"

/* global variables */


/******************************************************************************
*
* speShowInit - initialize the spe show facility
*
* This routine links the spe show facility into the VxWorks system.
* It is called automatically when the spe show facility is
* configured into VxWorks using either of the following methods:
* .iP
* If you use the configuration header files, define
* INCLUDE_SHOW_ROUTINES in config.h.
* .iP
* If you use the Tornado project facility, select INCLUDE_SHOW_ROUTINES.
*
* RETURNS: N/A
*/

void speShowInit (void)
    {
       if ( speProbe() == OK )
       {
          /* avoid direct coupling with speShow with this global variable */

          _func_speTaskRegsShow = (FUNCPTR) speTaskRegsShow;
       }
    }

/*******************************************************************************
*
* speTaskRegsShow - print the contents of a task's spe registers
*
* This routine prints to standard output the contents of a task's
* spe registers.
*
* RETURNS: N/A
*/

void speTaskRegsShow
    (
    int task		/* task to display spe registers for */
    )
    {
    SPE_CONTEXT *	pRegs;
    WIND_TCB *		pTcb;
    int			reg;
    UINT32 *		pInt;
    
    pTcb = taskTcb (task);
    pRegs = SPE_CONTEXT_GET (pTcb);

    if (pRegs)
        {
	printf ("\nUpper 32 bits of GPR \n");
        for (reg=0; reg<32; reg+=4)
            {
            printf ("r%d 0x%x r%d 0x%x r%d 0x%x r%d 0x%x\n", 
		    reg,pRegs->gpr[reg],
		    reg+1,pRegs->gpr[reg+1],
		    reg+2,pRegs->gpr[reg+2],
		    reg+3,pRegs->gpr[reg+3]);
	    
            }
        printf ("\naccumulator = %x %x \n", pRegs->acc[0], pRegs->acc[1]);

        } 
    else
        {
        printf ("No Spe Context\n");
        }
    }


