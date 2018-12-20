# Makefile - makefile for extracting objects from libstdc++.a
#
# modification history
# --------------------
# 01v,03jun03,sn   Use (smaller) exclude list in defs.exclude rather
#                  than specifying a (larger) positive object list here.
# 01u,26mar03,dtr  Adding file list for GNU3.3.
# 01t,06dec01,sn   handle non-unique libstdc++.a
# 01s,05dec01,sn   autodeduce name of libstdc++.a
# 01r,30nov01,ish  add library name for new MIPS toolchain
# 01q,14nov01,sn   removed extraneous lines
# 01p,06nov01,sn   specify an explicit list of objects
# 01o,30oct01,sn   moved to tool/gnu/libstdc++
# 01n,19oct01,tam  updated for repackaging
# 01m,16aug01,max  add library for PENTIUM
# 01l,13aug01,t_m  move GNULIBRARY version for ARM/XSCALE
# 01k,24jul01,scm  modify XScale name to fit coding standard...
# 01j,18jul01,t_m  remove xscale from version string
# 01i,09apr01,t_m  move to 2.10-xscale-010207 library for ARM targets.
# 01h,09nov99,tdl  removed following from LIBIO_OBJS:
# iofflush.o \
# iofflush_u.o \
# iofgets.o \
# iofopen.o \
# iofprintf.o \
# iofputs.o \
# ioftell.o \
# iofwrite.o \
# iogets.o \
# ioputs.o \
# ioscanf.o \
# iosetbuffer.o \
# iosetvbuf.o \
# iosprintf.o \
# iosscanf.o \
# iovsprintf.o \
# iovsscanf.o
# 01g,15nov99,sn   wrote
#
# DESCRIPTION
# This file contains the definitions needed for extracting objects
# from libstdc++.a (C++ Standard Library).
#
# Note: this file tries to find a file matching the name
# libstdc++.a* in $(GNULIBDIR). If no library or multiple
# different libraries are found you will see an error like
# make[2]: *** No rule to make target ...

TGT_DIR=$(WIND_BASE)/target

LIB_BASE_NAME	= cplus
LIB_COMMON      = false

CONFIGLETTE_NAME = gnu_cplusplus_std_library

GNULIBDIR	= $(GNU_BASE)/$(CC_MACHINE)/lib

# Some installation contain several libstdc++.a* files all of them
# symlinks to the "real" libstdc++.a. Choose the first one.
GNULIBRARY      = $(notdir $(word 1,$(wildcard $(GNULIBDIR)/libstdc++.a*)))

include $(TGT_DIR)/src/tool/gnu/rules.gnu


