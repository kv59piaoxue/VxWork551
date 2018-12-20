# Makefile - makefile for extracting objects from libgcc.a
#
# modification history
# --------------------
# 01f,03jun03,sn   cleaned up GCC 3.x support
# 01e,26mar03,dtr  Adding in GCC3.3 library specifics.
# 01d,13nov01,sn   gnuc++ -> gnucplus
# 01c,06nov01,sn   extract objects into a special directory to avoid stomping
#                  on VxWorks object files with the same name
# 01b,31oct01,tam  updated for repackaging
# 01a,24oct01,sn   wrote
#
# DESCRIPTION
# This file contains the definitions needed for extracting objects
# from libgcc.a (GNU C++ compiler support).

TGT_DIR=$(WIND_BASE)/target
TOOL=gnu

LIB_BASE_NAME	 = gnucplus
LIB_COMMON	 = false

GCCLIB		 = $(GNU_BASE)/lib/gcc-lib

GNULIBBASE	 = $(GCCLIB)/$(CC_MACHINE)/$(CC_VERSION)
GNULIBBASE_3     = $(GNU_BASE)/$(CC_MACHINE)/lib

GNULIBDIR        = $(GNULIBBASE$(GNU_VERSION))

GNULIBNAME	= libgcc.a
GNULIBNAME_3    = libsupc++.a

GNULIBRARY	 = $(GNULIBNAME$(GNU_VERSION))

CONFIGLETTE_NAME    = gplusplus_intrinsics

# C++ runtime library

include $(TGT_DIR)/src/tool/gnu/libg++/defs.g++

REAL_OBJS=$(OBJS_CPLUS)

include $(TGT_DIR)/src/tool/gnu/rules.gnu
