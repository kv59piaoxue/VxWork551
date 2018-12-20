# Makefile - makefile for target/src/cplus/rts
#
# modification history
# --------------------
# 02e,07may03,sn   symlink to sources instead of copying
# 02d,05may03,sn   added cplusDemStyle.o, fixed Windows build
# 02c,30apr03,sn   added etoa_decode.h
# 02b,14apr03,sn   reuse demangler.c rather than duplicating functionality in cplusDem.c
# 02a,08apr03,sn   new demangler source location, new wr-demangler.h interface file
# 01b,13mar02,sn   SPR 74061 - integrated EDG demangler
# 01a,26nov01,sn   created
# 
# DESCRIPTION
# This file contains the makefile rules for building the C++ demangler
#

TGT_DIR         = $(WIND_BASE)/target

LIB_BASE_NAME	= cplus
LIB_COMMON	= false

OBJS            = cplusDem.o \
                  cplusDemStub.o \
		  cplusDemStyle.o \
		  cplus-dem.o \
		  safe-ctype.o \
		  etoa_decode.o \
		  demangler.o

EXTRA_DEFINE    = $(OPTION_DEFINE_MACRO)HAVE_STDLIB_H
EXTRA_INCLUDE   = -I.

include $(TGT_DIR)/h/make/rules.library
