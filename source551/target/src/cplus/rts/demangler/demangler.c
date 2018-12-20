/* demangler.c - WR wrapper around GNU libiberty C++ demangler */

/* Copyright 2001 Wind River Systems, Inc. */

/*
modification history
--------------------
02d,07may03,sn   implemented suggestions and bug fix from code review with f_b
02c,30apr03,sn   removed include copyright_wrs.h to enable standalone testing
02b,15apr03,sn   moved to share/src/demangler
02a,08apr03,sn   new demangler source location, new wr-demangler.h interface file
01b,13mar02,sn   SPR 74061 - xrealloc and xmalloc must never return 0
01a,28nov01,sn   wrote
*/

/*
DESCRIPTION
This module implements an interface to the GNU libiberty demangler.
*/

/* includes */

#include <stdlib.h>
#include <string.h>

#include "demangler.h"
#include "wr-demangle.h"

struct manglingStyles
    {
        char * name;
	DEMANGLER_STYLE style;
    };

struct manglingStyles manglingStyles[] =
    {
	    {"gnu", DMGL_STYLE_GNU},
	    {"diab", DMGL_STYLE_DIAB},
            {"ia64", DMGL_STYLE_IA64_ABI},
	    {"gnu_v3", DMGL_STYLE_IA64_ABI},
    };

DEMANGLER_STYLE demanglerStyleFromName
    (
    const char * styleName,
    DEMANGLER_STYLE defaultStyle
    )
    {
    int i;
    for (i = 0; i != ARRAY_SIZE(manglingStyles); ++i)
        {
        if (strcmp(styleName, manglingStyles[i].name) == 0)
            {
            return manglingStyles[i].style;
            }
        }
    return defaultStyle;
    }

const char * demanglerNameFromStyle
    (
    DEMANGLER_STYLE style
    )
    {
    int i;
    for (i = 0; i != ARRAY_SIZE(manglingStyles); ++i)
        {
        if (style == manglingStyles[i].style)
            {
            return manglingStyles[i].name;
            }
        }
    return "unknown";
    }

/*******************************************************************************
*
* demangle - decode a C++ mangled name
*
* This routines decodes a C++ mangled symbol name using a scheme
* determined by <style> and going to an effort specified by
* <mode>. If <mode> is OFF, no work is done. If it it TERSE,
* only the function name is printed. Finally if it is COMPLETE,
* full demangling is performed.
*
* On memory exhaustion the routine returns NULL.
*
* RETURNS: a, possibly null, string which should be deallocated using free
*
* ERRORS: N/A
*
*/

char * demangle
    (
    const char * mangledSymbol,
    DEMANGLER_STYLE style,      /* DEFAULT/GNU/DIAB/... */
    DEMANGLER_MODE mode         /* OFF/TERSE/COMPLETE */
    )
    {
    int options = 0;

    switch (mode)
        {
	case DMGL_MODE_OFF:
	    {
	    char * result = malloc(strlen(mangledSymbol) + 1);
	    if (result)
	        {
		strcpy(result, mangledSymbol);
	        }
	    return result;
	    }
	case DMGL_MODE_TERSE:
	    options = 0;
	    break;
	case DMGL_MODE_COMPLETE:
	    options = DMGL_PARAMS | DMGL_ANSI;
            break;
	}
    switch (style)
	{
	case DMGL_STYLE_GNU:
            options |= DMGL_GNU;
	    break;
	case DMGL_STYLE_DIAB:
	    options |= DMGL_EDG;
	    break;
	case DMGL_STYLE_ARM:
	    options |= DMGL_ARM;
	    break;
	case DMGL_STYLE_IA64_ABI:
	    options |= DMGL_IA64_ABI;
	    break;
	default:
	    options |= DMGL_EDG;
	    break;   
	}
    return  cplus_demangle (mangledSymbol, options);
    }

/* xmalloc and xrealloc are needed by the libiberty demangler */

#ifdef HOST
#define cplusDemanglerAbort abort
#else
extern void cplusDemanglerAbort();
#endif

void * xmalloc
    (
    size_t n
    )
    {
    void * p = malloc(n);
    if (!p) cplusDemanglerAbort();
    return p;
    }

void * xrealloc
    (
    void * p,
    size_t n
    )
    {
    if (p)
	{
	p = realloc(p, n);
	}
    else
	{
	p = malloc(n);
	}
    if (!p) cplusDemanglerAbort();
    return p;
    }

char * xstrdup
    (
    const char * str
    )
    { 
    char * copied_str = 0;
    if (str == 0) return 0;
    copied_str = xmalloc(strlen(str) + 1);
    strcpy(copied_str, str);
    return copied_str;
    }
