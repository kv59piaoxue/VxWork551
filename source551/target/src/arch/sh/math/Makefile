# Makefile - makefile skeleton for target/src/arch/sh/math
#
# modification history
# --------------------
# 01k,25oct01,tam  updated for repackaging
# 01j,06sep01,zl   moved USS files to uss directory, removed SH3-E support.
# 01i,05dec00,zl   removed OBJ_GCC.
# 01h,22nov00,zl   removed SUBDIRS.
# 01g,18oct00,hk   merge SH7729 to SH7700. merge SH7410 and SH7040 to SH7600.
#                  added mathSh7750ALib.o to OBJ_SH7750.
# 01f,03jul00,hk   added OBJ_USS to OBJ_SH7750.
# 01e,30aug99,zl   added mathHardLib.o to OBJ_SH7750.
# 01e,11aug99,zl   removed OBJ_GCC from OBJ_SH7750, use libgcc.a instead.
# 01d,08jun99,zl   removed OBJ_USS from OBJ_SH7750.
# 01c,03mar99,hk   changed OBJ_SH7750 to include OBJ_HW_SUPPORT.
# 01b,16jul98,st   added SH7750 support.
# 01b,08may98,jmc  added support for SH-DSP and SH3-DSP.
# 01d,07jul98,hk   changed OBJ_SH7700 to use OBJ_HW_SUPPORT.
# 01c,03jul98,st   delete OBJ_HMS (merged mathHardALib.s).
# 01b,01may98,hk   changed to use merged uss library.
# 01a,25apr97,hk   created from 01c of MakeSkel
#
# DESCRIPTION
# This file contains the makefile rules for building the vx library
#
#*/

TGT_DIR=$(WIND_BASE)/target

DOC_FILES	=

LIB_BASE_NAME   = arch

OBJ_SH7000	= mathSoftLib.o
OBJ_SH7600	= mathSoftLib.o
OBJ_SH7700	= mathSoftLib.o
OBJ_SH7750	= mathHardLib.o

OBJS=$(OBJ_$(CPU))

include $(TGT_DIR)/h/make/rules.library
