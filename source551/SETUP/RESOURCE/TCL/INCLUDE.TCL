# INCLUDE.TCL - Setup procedures common to both INSTW32.TCL and UNINST.TCL
#
# Copyright 1999 Wind River Systems, Inc
#
# modification history
# --------------------
# 03d,12dec02,bjl  modified cdromBanner to return cdromDescGet if no
#                  banner setting.  
# 03c,03oct02,bjl  added cdromBanner procedures.
# 03b,05mar02,bwd  Modified SETUP to be non-tornado centric
# 03a,12jun01,j_w  Modified for Tornado 2.2
# 01c,09jun00,bwd  Added another host type check for x86-linux2
# 01b,21oct99,bjl  removed parisc-hpux support.
# 01a,27jan99,tcy  extracted from INSTW32.TCL, INSTALL.TCL and UNINST.TCL.
#

#############################################################################
#
# isUnix - determine whether host platform is Unix or not
#
# This procedure will determine whether host platform is Unix or not
#
# SYNOPSIS
# .tS
# isUnix
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if host platform is not Unix
#          1 if host platform is Unix
#
# ERRORS: N/A
#

proc isUnix {} {
    global env

    if {[info exists env(WIND_HOST_TYPE)]} {
        if { [string match sun4* $env(WIND_HOST_TYPE)] ||
             [string match "x86-linux2" $env(WIND_HOST_TYPE)]  ||
             [string match parisc* $env(WIND_HOST_TYPE)] } {

            return 1;
        } else {
            return 0;
        }
    } else {
        return [info exists env(MWHOME)]
    }
}

#############################################################################
#
# dosToUnix - convert backward slashes to forward slashes
#
# This procedure will convert backward slashes to forward slashes
#
# SYNOPSIS
# .tS
# dosToUnix <path>
# .tE
#
# PARAMETERS:
# .IP path
# path with slashes
#
# RETURNS: new path with forward slashes
#
# ERRORS: N/A
#

proc dosToUnix {path} {
    regsub -all {\\} $path {/} newpath
    return $newpath
}

#############################################################################
#
# unixToDos - convert forward slashes to backward slashes
#
# This procedure will convert forward slashes to backward slashes
#
# SYNOPSIS
# .tS
# unixToDos <path>
# .tE
#
# PARAMETERS:
# .IP path
# path with slashes
#
# RETURNS: new path with backward slashes
#
# ERRORS: N/A
#

proc unixToDos {path} {
    regsub -all {/} $path {\\} newpath
    return $newpath
}

#############################################################################
#
# getDate - return the current date time stamp
#
# This procedure will return the current date time stamp
#
# SYNOPSIS
# .tS
# getDate
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: return the current date time stamp
#
# ERRORS: N/A
#

proc getDate {} {
    return [clock format [clock second] -format "%d-%b-%y.%H:%M"]
}

##############################################################################
#
# instKeySet - sets the installation key.
#
# Sets the global variable setupVals(instKey) to the installation key.
#
# MUST add this procedure here:
# When user uses setupSDK to manufacture a cd with -nokey option, poolMfg
# script adds "instKeySet none" line to CONFIG.TCL, and new UNINST script
# (for stand-alone product) sources CONFIG.TCL, so this procedure must
# be defined to avoid error: "invalid command name instKeySet"
#
# SYNOPSIS:
# instKeySet val
#
# PARAMETERS:
# <val>
# Contains the installation key.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc instKeySet {val} {
    global setupVals

    set setupVals(instKey) $val
}

##############################################################################
#
# cdromDescGet - returns the CD-ROM description.
#
# This routine returns the CD-ROM description string set by the global
# variable setupVals(cdDesc).  If the description has not been set, an empty
# string is returned.
#
# SYNOPSIS:
# cdromDescGet
#
# PARAMETERS: N/A
#
# RETURNS: the CD-ROM description string, else 0 if it does not exist.
#
# ERRORS: N/A
#

proc cdromDescGet {} {
    global setupVals

    if {[info exists setupVals(cdDesc)]} {
        return $setupVals(cdDesc)
    } else {
        return 0
    }
}

##############################################################################
#
# cdromDescSet - sets the CD-ROM description.
#
# Sets the global variable setupVals(cdDesc) to the CD-ROM description.
#
# SYNOPSIS:
# cdromDescSet val
#
# PARAMETERS:
# <val>
# Contains the CD-ROM description.
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc cdromDescSet {val} {
    global setupVals

    set setupVals(cdDesc) $val
}

##############################################################################
#
# cdromBannerGet - returns the CD-ROM banner text.
#
# This routine returns the CD-ROM banner text set by the global
# variable setupVals(cdBanner).  If the description has not been set, return 
# the cdrom description string. 
#
# SYNOPSIS:
# cdromBannerGet
#
# PARAMETERS: N/A
#
# RETURNS: the CD-ROM banner text, else cdromDescGet. 
#
# ERRORS: N/A
#

proc cdromBannerGet {} {
    global setupVals

    if {[info exists setupVals(cdBanner)]} {
        return $setupVals(cdBanner)
    } else {
        return [list "Wind River" "[cdromDescGet] Setup"]
    }
}

##############################################################################
#
# cdromBannerSet - sets the CD-ROM Banner text.
#
# Sets the global variable setupVals(cdBanner) to the specified text.  The
# banner text is displayed in the background for a Windows host.  
#
# SYNOPSIS:
# cdromBannerSet val
#
# PARAMETERS:
# <val>
# Contains the CD-ROM banner.  
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc cdromBannerSet {val} {
    global setupVals

    set setupVals(cdBanner) [list "Wind River" "$val Setup"]
}


##############################################################################
#
# getProdInfo - returns requested information about the product
#
# This routine returns requested information about the product (name or
# version). If the value has not been set, an empty string is
# returned. The product name, for example "Tornado", contains the 
# product name used to referred to by SETUP. The version is
# the version of the released product/CD
#     Ex. procedure calls:
#         getProdInfo name
#         getProdInfo version
#
# SYNOPSIS:
# getProdInfo
#
# PARAMETERS: 
#    <info> : an information of a product
#
# RETURNS: string of requested info, else 0 if it does not exist.
#
# ERRORS: N/A
#

proc getProdInfo {info} {
    global prodInfo

    switch $info {
        name { return $prodInfo(name) }
        version { return $prodInfo(version) }
        default { 
            puts "getProdInfo: unknown info: $info" 
            return ""
        }
    }
}

##############################################################################
#
# setProdInfo - sets specific information to a specified value
#
# This routine sets specific information (name or version) to a specified
# value. The product name, for example "Tornado", contains the 
# product name used to referred to by SETUP. The version is
# the version of the released product/CD
#     Ex. procedure calls:
#         setProdInfo name "Tornado"
#         setProdInfo version "3.1"
#
# SYNOPSIS:
# setProdInfo info val
#
# PARAMETERS:
#    <info>  : an information of a product
#    [value] : new value of an attribute
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc setProdInfo {info {value ""}} {
    global prodInfo

    switch $info {
        name { set prodInfo(name) $value }
        version { set prodInfo(version) $value }
        default { puts "setProdInfo: unknown info: $info" }
    }
}

##############################################################################
#
# fileNameAbbreviate - shorten the filename for GUI displaying purpose
#
# This procedure shorten filename if it's longer than <length> chars.  The
# shorten filename will be in the form firstDir/.../lastDir/fileName.
# There is no warranty that the resulted filename will be any shorter than
# the original one.
#
# SYNOPSIS
# fileNameAbbreviate <fileName> <length>
#
# PARAMETERS:
#    fileName : a path filename
#    length : length of the filename
#
# RETURNS: shorten filename
#
# ERRORS: N/A
#

proc fileNameAbbreviate {fileName length} {
    set shortName $fileName

    if {[string length $fileName] > $length} {
        if [regexp {(^[^/]+)/.*/([^/]+/[^/]+$)} $fileName junk\
                 firstPart lastPart] {
            set shortName "$firstPart/.../$lastPart"
        }
    }
    return $shortName
}
