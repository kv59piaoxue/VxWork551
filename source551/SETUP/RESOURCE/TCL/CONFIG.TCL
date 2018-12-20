# CONFIG.TCL - Setup configuration file 
#
# Note: This file may be modified during the pool manufacturing process to
#       add additional configuration statements. This file is sourced by
#       INSTW32.TCL.
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03c,03oct02,bjl  fixed instructional comments and added banner setting
#                  (spr 77983).  
# 03b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 

# Product name used in Setup message text.  

cdromDescSet "Tornado"

# Banner text displayed in the background for Windows Setup.

cdromBannerSet "Tornado 2.2"

# Note: Only one of TORNADO_PRODUCT, STAND_ALONE, and WRS_STANDALONE should
# be set to 1.  The other two values should be set to 0.   

global TORNADO_PRODUCT STAND_ALONE WRS_STAND_ALONE

# TORNADO_PRODUCT indicates that the CD installs Tornado products.  This
#                 includes the Tornado core, BSPs, and optional products 
#                 that install into a Tornado tree.  

set TORNADO_PRODUCT 1

# STAND_ALONE indicates that the product is a FULL stand-alone product. 
#             The product installs into its own tree, separate from Tornado.
#             Setup does not write any registry values used by Wind River.  
#
#  Implications:
#   SKIP: Wind River related registry reading/writing such as username, 
#         company, key, etc.
#   SKIP: Tornado-centric code
#   REMOVE: appConfig and projectInfo page
#   Process registry writing in <$productName>.INF file

set STAND_ALONE 0

# WRS_STAND_ALONE indicates that the product is a stand-alone product sold
#                 by Wind River.  The product installs into its own tree, not 
#                 into a Tornado tree.  Setup writes registry values used 
#                 by Wind River.  
#
#  Implications:
#   NOT-SKIPPED: Wind River related registry reading/writing such as
#                username, company, key, etc., since it's still a 
#                Wind River product.  
#   NOT-SKIPPED: Wind River related registry processing in <$productName>.INF
#   REMOVE  : appConfig page
#   SKIP    : Tornado-centric code

set WRS_STAND_ALONE 0

# Name and version of the core product, used by Setup to set the default 
# installation directory, registry entries, license management details,
# uninstall text, etc.  Do NOT change these values if the product installs
# into a Tornado tree.  Change these values only if the product is a 
# stand-alone product.  
# 

setProdInfo name "Tornado"
setProdInfo version "2.2"

