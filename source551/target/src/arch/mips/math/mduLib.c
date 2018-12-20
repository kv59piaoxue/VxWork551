/* mduLib.c - LSI CW4000 MDU support */

/* Copyright 1984-2001 Wind River Systems, Inc. */
#include "copyright_wrs.h"

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
01c,16jul01,ros  add CofE comment
01b,07may97,mem changed return type of mduProbe() to int; 
		moved decl of mdu_present to gccMathALib.s.
01a,11apr96,mem written.
*/

/*
DESCRIPTION

SEE ALSO: gccMathALib
*/

/* includes */

#include "vxWorks.h"
#include "iv.h"
#include "intLib.h"
#include "taskLib.h"
#include "intLib.h"
#include "setjmp.h"
#include "private/funcBindP.h"

/* externs */

IMPORT	BOOL	_mdu_present;

/* locals */

LOCAL	jmp_buf	_mduJmpbuf;

/* forward declarations */

IMPORT	int	__mduProbe (void);
LOCAL	void	mduProbeTrap (void);

/******************************************************************************
*
* mduProbeTrap - return from failed mdu probe
*
* RETURNS: N/A
*/

LOCAL void mduProbeTrap ()
    {
    _func_excBaseHook = 0;
    longjmp (_mduJmpbuf, 1);
    }

/******************************************************************************
*
* mduProbe - determine if the MDU module is present.
*
* RETURNS:
* TRUE if the MDU is present in the system, and FALSE otherwise.
*/

int mduProbe()
    {
    volatile int lvl;
    volatile FUNCPTR oldHook;

    lvl = intLock ();
    oldHook = _func_excBaseHook;

    if (setjmp (_mduJmpbuf) != 0)
	{
	/* an exception occured - no MDU present */
	_mdu_present = FALSE;
	}
    else
	{
	/* Install our exception handler. */
	_func_excBaseHook = (FUNCPTR) mduProbeTrap;
	/* do the actual probe */
	__mduProbe();
	/* If we got this far, the MDU is present */
	_mdu_present = TRUE;
	}

    /* Restore the old exception handler and return. */
    _func_excBaseHook = oldHook;
    intUnlock (lvl);
    return (_mdu_present == TRUE) ? 1 : 0;
}
