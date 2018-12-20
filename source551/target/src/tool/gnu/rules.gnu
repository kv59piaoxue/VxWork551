# rules.gnu - rules for extracting objects from GNU libraries
#
# modification history
# --------------------
# 01c,03jun03,sn   added support for GCC 3.x
# 01b,06nov01,sn   define OBJ_PREFIX
# 01a,15oct01,sn   wrote
#
# DESCRIPTION
# Generic rules for extracting objects from GNU libraries.
# Subdirectory Makefiles for specific libraries should
# set GNULIBDIR and GNULIBRARY and include this file.
#
  
# Ask the compiler driver for the version (e.g. gcc-2.6) and
# machine (e.g. powerpc-wrs-vxworksae). This info may
# be used by subdirectory Makefiles to compute GNULIBDIR.

CC_VERSION	= $(shell $(CC) -dumpversion)
CC_MACHINE	= $(shell $(CC) -dumpmachine)

MULTISUBDIR	= $(CPU)$(TOOL)

TOOL_LIB	= $(GNULIBDIR)/$(MULTISUBDIR)/$(GNULIBRARY)

OBJ_PREFIX      = _x_gnu_

include $(TGT_DIR)/h/make/rules.library

ifneq (,$(findstring 3., $(CC_VERSION)))
GNU_VERSION     = _3

# This is pretty horrible; however it has the advantage of working on
# both Unix and Windows. It does not work if $(WIND_BASE) happens to
# contain the string $(WIND_HOST_TYPE).

GNU_BASE        = $(shell $(CC) -print-libgcc-file-name | sed "s@\($(WIND_HOST_TYPE)\).*@\1@")
else
# GCC 2.96
GNU_VERSION     = 
GNU_BASE        = $(WIND_BASE)/host/$(WIND_HOST_TYPE)
endif

include $(TGT_DIR)/src/tool/rules.tool
