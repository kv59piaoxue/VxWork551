/* taskArchShow.c - ColdFire-specific task show routines */

/* Copyright 2000 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01b,26nov01,dee  remove references to MCF5200
01a,04aug00,dh   Created
*/

/*
DESCRIPTION
This library provides ColdFire-specific task show routines.

SEE ALSO: taskShow
*/

/* LINTLIBRARY */

#include "vxWorks.h"
#include "taskArchLib.h"
#include "regs.h"
#include "private/taskLibP.h"
#include "private/windLibP.h"
#include "stdio.h"


/* globals */
extern char *taskRegsFmt;

REG_INDEX taskRegName[] =
    {
    {"d0", D_REG_OFFSET(0), 4, 1},
    {"d1", D_REG_OFFSET(1), 4, 1},
    {"d2", D_REG_OFFSET(2), 4, 1},
    {"d3", D_REG_OFFSET(3), 4, 1},
    {"d4", D_REG_OFFSET(4), 4, 1},
    {"d5", D_REG_OFFSET(5), 4, 1},
    {"d6", D_REG_OFFSET(6), 4, 1},
    {"d7", D_REG_OFFSET(7), 4, 1},
    {"a0", A_REG_OFFSET(0), 4, 1},
    {"a1", A_REG_OFFSET(1), 4, 1},
    {"a2", A_REG_OFFSET(2), 4, 1},
    {"a3", A_REG_OFFSET(3), 4, 1},
    {"a4", A_REG_OFFSET(4), 4, 1},
    {"a5", A_REG_OFFSET(5), 4, 1},
    {"a6/fp", A_REG_OFFSET(6), 4, 1},
    {"a7/sp", A_REG_OFFSET(7), 4, 1},
    {"sr", SR_OFFSET, 2, 1},
    {"pc", PC_OFFSET, 4, 1},
    {"", 0, 0, 0},
    {"", 0, 0, 0},
    {"acc", MAC_OFFSET, 4, 0},
    {"macsr", MACSR_OFFSET, 2, 0},
    {"mask", MASK_OFFSET, 2, 0},
    {NULL, 0},
    };

/*******************************************************************************
*
* taskArchRegsShow - display the contents of a task's registers
*
* This routine displays the register contents of a specified task
* on standard output.
*
* RETURNS: N/A
*/

void taskArchRegsShow(REG_SET *regSet)
    {
    int ix;
    unsigned regVal;

    /* print out normal registers */

    for (ix = 0; taskRegName[ix].regName != NULL; ix++)
	{
	if (taskRegName[ix].regStandard || _coldfireHasMac)
	    {
	    printf ( ((ix % 4) == 0) ? "\n" : "   ");

	    if (taskRegName[ix].regWidth != 0)
		{
		switch (taskRegName[ix].regWidth)
		    {
		    case 4:
			regVal = *(unsigned int *)((int)regSet + taskRegName[ix].regOff);
			break;
		    case 2:
			regVal = *(unsigned short *)((int)regSet + taskRegName[ix].regOff);
			break;
		    default:	/* Oops! not supported! */
			regVal = 0xdeadbeef;
			break;
		    }
		printf (taskRegsFmt, taskRegName[ix].regName, regVal);
		}
	    else
	        printf ("%17s", "");
	    }
	}
    printf ("\n");

    }
