/* wr-demangle.h - demangler interface header */

/* Copyright 2003 Wind River Systems, Inc. */

/*
modification history
--------------------
01c,29apr03,sn   removed #include "copyright_wrs.h" since included by non-WRS files
01b,15apr03,sn   removed unneeded defs, added prototype of cplus_demangle
01a,08apr03,sn   wrote based on analysis of cplus-dem.c
*/

/*
DESCRIPTION
This is a replacement for several GNU libiberty headers that 
were previously included by cplus-dem.c and safe-ctype.c.
*/


#include <string.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

#define PARAMS(args) args

#define irrelevant 0

#define DMGL_ANSI	(1 << 1)
#define DMGL_PARAMS	(1 << 2)
#define DMGL_STYLE_MASK	(DMGL_ANSI | DMGL_PARAMS)

#define DMGL_NONE	(1 << 3)
#define DMGL_AUTO	(1 << 4)
#define DMGL_GNU	(1 << 5)
#define DMGL_EDG	(1 << 6)
#define DMGL_IA64_ABI	(1 << 7)

#define DMGL_ARM	irrelevant
#define DMGL_JAVA	irrelevant

/* for our purposes current_demangling_style is always auto_demangling */
enum demangling_styles
{
  no_demangling = DMGL_NONE,
  auto_demangling = DMGL_AUTO,
  gnu_demangling = DMGL_GNU | DMGL_ANSI | DMGL_PARAMS,
  edg_demangling = DMGL_EDG | DMGL_ANSI | DMGL_PARAMS,
  gnu_v3_demangling = DMGL_IA64_ABI | DMGL_ANSI | DMGL_PARAMS,
  lucid_demangling = irrelevant,
  arm_demangling = irrelevant,
  hp_demangling = irrelevant,
  java_demangling = irrelevant,
  gnat_demangling = irrelevant,
  unknown_demangling = irrelevant
};


#define ATTRIBUTE_NORETURN
#define ATTRIBUTE_UNUSED

struct demangler_engine
{
	char * dummy;
	enum demangling_styles demangling_style;
	char * demangling_style_name;
};

/* the values of these strings are irrelevant for our purposes*/
#define NO_DEMANGLING_STYLE_STRING ""
#define AUTO_DEMANGLING_STYLE_STRING ""
#define GNU_DEMANGLING_STYLE_STRING ""
#define LUCID_DEMANGLING_STYLE_STRING ""
#define ARM_DEMANGLING_STYLE_STRING ""
#define HP_DEMANGLING_STYLE_STRING ""
#define EDG_DEMANGLING_STYLE_STRING ""
#define GNU_V3_DEMANGLING_STYLE_STRING ""
#define JAVA_DEMANGLING_STYLE_STRING ""
#define GNAT_DEMANGLING_STYLE_STRING ""

#define ARRAY_SIZE(x) sizeof(x) / sizeof(struct x)

extern char * xstrdup(const char * str);
extern void * xmalloc(size_t);
extern void * xrealloc(void * p, size_t n);

/* CURRENT_DEMANGLING_STYLE is defined in cplus-dem.c */

#define AUTO_DEMANGLING   ((CURRENT_DEMANGLING_STYLE & DMGL_AUTO) != 0)
#define GNU_DEMANGLING    ((CURRENT_DEMANGLING_STYLE & DMGL_GNU) != 0)
#define GNU_V3_DEMANGLING ((CURRENT_DEMANGLING_STYLE & DMGL_IA64_ABI) != 0)
#define EDG_DEMANGLING    ((CURRENT_DEMANGLING_STYLE & DMGL_EDG) != 0)

#define HP_DEMANGLING	irrelevant
#define LUCID_DEMANGLING irrelevant
#define ARM_DEMANGLING irrelevant

char * cplus_demangle (const char *mangled, int options);

#undef min

#ifdef __cplusplus
}
#endif
