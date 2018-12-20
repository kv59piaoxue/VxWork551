# Makefile - makefile for vw/src/arch/coldfire
#
# modification history
# --------------------
# 01b,25oct01,tam  updated for repackaging
# 01a,17mar00,dra  Created from T1.0.1 ColdFire and T2 m68k ports.
#
# DESCRIPTION
# This file contains the makefile rules for building the vx library
#
#*/

TGT_DIR=$(WIND_BASE)/target

DOC_FILES  =

LIB_BASE_NAME   = arch

OBJS_BASE  = bALib.o dbgArchLib.o dllALib.o dsmLib.o excALib.o excArchLib.o \
	     excArchShow.o ffsALib.o fppALib.o fppArchLib.o intALib.o \
	     intArchLib.o qPriBMapALib.o qPriHeapALib.o semALib.o semCALib.o \
	     semMALib.o sllALib.o taskArchLib.o trcLib.o vxALib.o \
	     vxLib.o wdbDbgArchLib.o wdbDbgALib.o windALib.o workQALib.o \
	     sigCtxLib.o sigCtxALib.o taskArchShow.o cacheColdALib.o

CACHE_UNIFIED = cacheColdUnifiedLib.o cacheColdUnifiedALib.o
CACHE_5204    = cacheMCF5204ALib.o cacheMCF5204Lib.o
CACHE_5407    = cacheMCF5407ALib.o cacheMCF5407Lib.o

OBJS_MCF5200 = $(OBJS_BASE) $(CACHE_UNIFIED) $(CACHE_5204)
OBJS_MCF5400 = $(OBJS_BASE) $(CACHE_5407)

OBJS=$(OBJS_$(CPU))

include $(TGT_DIR)/h/make/rules.library
