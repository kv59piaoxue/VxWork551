# Makefile - makefile for src/wrn/util
#
# modification history
# --------------------
# 01j,14jan03,rae  Merged from velocecp branch
# 01i,19oct01,tam  added support for new archive directory hierarchy
# 01h,14nov00,rae  remove igmpPortLib, cleanup
# 01g,20jul00,rae  removed PRE_INCLUDE
# 01f,16may00,rae  added  -DVIRTUAL_STACK
# 01e,22mar00,sj   removed debug flag -g
# 01d,10mar00,rae  add WRN/include
# 01c,10mar00,rae  add include to include path
# 01b,17feb00,adb  avlLib.o
# 01a,07jan00,sj   created 
#
# DESCRIPTION
# This file contains the makefile rules for building the wrn utilities.
#
#*/

TGT_DIR=$(WIND_BASE)/target

DOC_FILES=

LIB_BASE_NAME   = net

OBJS=   avlLib.o 

ifneq ($(subst diab,,$(TOOL)), $(TOOL))
CFLAGS_avlLib.o= -Xrelax-alias=0x3
else
CFLAGS_avlLib.o= -fno-strict-aliasing
endif

include $(TGT_DIR)/h/make/rules.library
