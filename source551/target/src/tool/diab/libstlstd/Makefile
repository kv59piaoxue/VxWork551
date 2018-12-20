# Makefile - makefile for extracting objects from libstl.a
#
# modification history
# --------------------
# 01e,26feb03,s_l  merged from tor2_2-cp1-diab
# 01e,18feb03,sn   added support for Diab 5.1 standard vs abridged library
# 01d,13nov01,sn   (implicitly) use exclude list from defs.exclude
# 01c,06nov01,sn   extract objects into a special directory to avoid stomping
#                  on VxWorks object files with the same name
# 01b,31oct01,tam  updated for repackaging
# 01a,24oct01,sn   wrote
#
# DESCRIPTION
# This file contains the definitions needed for extracting objects
# from libstl.a (C++ Standard Library).

TGT_DIR          = $(WIND_BASE)/target

CXX_STL_VARIANT  = standard
DIABLIBRARY      = libstlstd.a libstl.a

include $(TGT_DIR)/src/tool/diab/libstlstd/defs.stl

