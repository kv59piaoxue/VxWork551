# VERSION.TCL - contains the setup's version string.
#
# Copyright 1984-1997 Wind River Systems, Inc
#
# modification history:
# ---------------------
# 03f,03oct02,bjl  made versions independent of config.tcl product settings
#                  (spr 77983).  
# 03e,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03d,05jan02,j_w  Replace T3.0 with T2.2
# 03c,18dec01,j_w  temporary replace T2.2 with T3.0 until database is ready
# 03b,05dec01,j_w  set setupVals(torVer) to T2.2
# 03a,12jun01,j_w  Added for Tornado 2.2
# 03v,13mar01,j_w  Replaced setup version with setupVals(torVersionNum)
# 03u,21jan00,j_w  Define setupVals(torVer) -- parameter for licInfoGetAll
#                  procedure
# 03t,30sep99,j_w  Modified for T3
# 03s,20aug98,wmd  v2.0: new release for Tornado 2.0.
# 01d,17mar98,pdn  v1.4: fixed MULTIPLE_VERSION logic to conform to the 
#                        design spec.
# 01c,07jan98,pdn  v1.3: allowed SETUP to continue even BAD_CD_REVISION message
#                        is returned.
# 01b,07jan98,pdn  v1.2: added a list of overwriten files to the setup.log.
# 01a,12aug97,pdn  v1.1: started tracking modification of the SETUP script.
#
# Note: When modifying any of the setup script/binary/dll, a version increase
# is required.  The first digit specifies a major modification, and the second
# one specifies a minor modification.
#
# This version number will be recorded in the setup.log.
#

# setup version (ex: "SETUP-2.2")
set setupVals(version) "SETUP-2.2"

# Parameter for licInfoGetAll
# first char of product name and the product version (ex: "T2.2")
set setupVals(prodVer) "T2.2"
