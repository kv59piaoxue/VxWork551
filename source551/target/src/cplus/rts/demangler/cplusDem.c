/* cplusDem.c - C++ link name demangler */

/* Copyright 1993 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
02b,14apr03,sn   simplify _cplusDemangle to reuse functionality from 
                 share/src/demangler/demangler.c
02a,08apr03,sn   new demangler source location, new wr-demangler.h interface file
02e,13mar02,sn   SPR 74275 - allow demangler to be decoupled from target shell
02d,22jan02,sn   Changed to C file
02c,07dec01,sn   autodeduce correct demangling style
02b,12jun98,sn   merged in fix to spr 8947 which moves the work of
                 the demangler into cplus-dem.c.
		 fixed (disastrous) typo in cplusDemanglerInit
		 moved code that removes compiler prepended leading underscores
                 to cplusDemStub.cpp so that we can use it even if the
		 C++ runtime isn't included.
		 made _cplusDemangle distinguish between modes TERSE and
                 COMPLETE as required by the docs for cplusDemanglerSet.
02a,10apr98,sn   moved a stub definition of cplusDemangle into cplusDemStub.cpp
                 but retained the body under the new name _cplusDemangle.
		 added cplusDemanglerInit.
01d,03jun93,srh  doc cleanup
01c,23apr93,srh  implemented new force-link/initialization scheme
01b,22apr92,srh  Added support for T<n> and N<n><n> constructs.
		 The demangler should be cleaned up and rewritten, using
		 the T and N support generally, instead of redundantly.
01a,31jan93,srh  written.
*/

/*
DESCRIPTION
This module provides an interface to a C++ name demangler. It contains 
no user-callable routines.

INTERNAL

The real work of the demangler is done in cplus-dem.c. In this
file we provide extra functionality required by the target show
routines such as lkup.

NOMANUAL
*/

/* includes */

#include "vxWorks.h"
#include "ctype.h"
#include "string.h"
#include "stdlib.h"
#include "cplusLib.h"
#include "demangler.h"
#include "taskLib.h"

/* defines */

#define STRINGIFY(x) #x
#define TOOL_FAMILY_STR STRINGIFY(TOOL_FAMILY)

/* typedefs */

char __cplusDem_o = 0;

/* globals */

extern CPLUS_DEMANGLER_MODES cplusDemanglerMode;
extern DEMANGLER_STYLE cplusDemanglerStyle;

/* locals */

/*******************************************************************************
*
* _cplusDemangle - demangle symbol
*
* This routine takes a C or C++ symbol and attempts to demangle it
* in the manner specified by cplusDemanglerMode. It does not
* attempt to remove compiler prepended underscores. The caller
* must take care of this.
*
* See documentation for cplusDemanglerSet for an explanation
* of the demangler modes.
*
* RETURNS:
* Destination string if demangling is successful, otherwise source string.
*
* NOMANUAL
*/

char * _cplusDemangle
    (
    char * source,                /* mangled name */
    char	* dest,                  /* buffer for demangled copy */
    int n                         /* maximum length of copy */
    )
    {
    char *buf;
    buf = demangle(source, cplusDemanglerStyle, cplusDemanglerMode);
    if (buf !=0)
	{
	strncpy (dest, buf, n);
	free (buf);
	return dest;
	}
    else
	{
	return source;
	}	  
    }

/*******************************************************************************
*
* cplusDemanglerInit -  initialize the demangler
*
* RETURNS: N/A
* 
*
* NOMANUAL
*/

void cplusDemanglerInit ()
{
    cplusDemangleFunc = _cplusDemangle;
}

void cplusDemanglerAbort()
{
  if (_func_logMsg != 0)
      {
      (* _func_logMsg) ("Memory exhausted while demangling C++ symbol", 0, 0, 0, 0, 0, 0);
      }
  taskSuspend (0);
}
