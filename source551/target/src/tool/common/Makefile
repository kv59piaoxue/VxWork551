# Makefile - makefile for target/src/tool/common
#
# modification history
# --------------------
# 01d,09sep03,dtr  Adding save and restore for PPC85XX SPE APU.
# 01c,03jun03,sn   moved rules.library include here
# 01b,05dec01,to   added arm_call_via.o for Thumb mode
# 01a,03dec01,sn   wrote
# 
# DESCRIPTION
# Build toolchain independent assembly code

TGT_DIR	= $(WIND_BASE)/target

LIB_BASE_NAME	= commoncc
LIB_COMMON	= true

CONFIGLETTE_NAME = common_intrinsics

OBJS_PPC85XX = speSaveRest.o

OBJS_ppc = saverest.o 

OBJS_arm = arm_call_via.o

PRE_OBJS = $(OBJS_$(TOOLENV))
OBJS = $(OBJS_$(CPU))

include $(TGT_DIR)/h/make/rules.library
include $(TGT_DIR)/src/tool/rules.tool

