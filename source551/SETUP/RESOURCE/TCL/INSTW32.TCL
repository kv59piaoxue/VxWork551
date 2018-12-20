# INSTW32.TCL - UITcl script for Windows/UNIX Installation schemes
#
# Copyright 1996-2003 Wind River Systems, Inc.
#
# modification history
# --------------------
# 17h,05sep03,s_l  Revert changes done earlier.
# 17g,29aug03,s_l  set new values for lmVals with host Powel. This change
# is temportarly for testing only. It nees to be rever for FCS.
# 17f,03may03,bjl  remove temp dir for exit test (spr 88192).  
# 17e,29apr03,bjl  set setupVals(toolset) to default set (spr 87803), added
#                  lmVals(succesfulDbQuery) (spr 88068).  
# 17d,04apr03,bjl  added exit test for spr 87398, fixed switches in 
#                  parseCmdLine for Unix (spr 87400).  
# 17c,28feb03,bjl  added setupVals(toolset) to globalInit.
# 17b,20feb03,bjl  added licinfo page.
# 17a,14feb03,bjl  modified for ELM licensing page sequences, added ELM and 
#                  manual licensing variables, project info page removed.
# 16z,27jan03,wmd  Modify to use licInfoGetAll2 for ALI.
# 16y,03oct02,bjl  fixed /OVERRIDE flag from being truncated (spr 80428), 
#                  made banner text independent (spr 77983).  
# 16x,25jul02,wmd  Fix isBSPcd procedure.
# 16w,15jul02,wmd  Modify Setup to add new /PATCH command line parameter.
# 16v,11jul02,wmd  Fix spr# 79358 - add space for program folder name.
# 16u,26jun02,j_w  Pointed ALI to use the production database (ALIP)
# 16t,31may02,bwd  Modified SETUP banner to display Tornado 2.2. Setup
# 16s,29may02,wmd  Preserve setupVals(WRS) as Wind River Systems, Inc.
# 16r,20may02,wmd  Fix SPR # 77610 - Change Wind River Systems, Inc to
#                  Wind River as recommend by Jim Irwin.
# 16q,13may02,j_w  Changed default program group to Tornado 2.2
# 16p,03may02,bwd  SPR 76643: added backward compatibility support for patches
#                  made by pre-veloce setupSDK
# 16o,05mar02,bwd  Source CONFIG.TCL first to define product name and version
# 16n,05mar02,bwd  Modified SETUP to be non-tornado centric
# 16m,07feb02,j_w  Workaround for cgi script problem - replace
#                  www.windriver.com to web1.windriver.com
# 16l,05feb02,j_w  Use database on powell for EAR2 testing
# 16k,05feb02,bwd  Modified default directory to Tornado2.2
# 16j,24jan02,wmd  Add variable instVals(evaluation), init to 0.
# 16i,20dec01,bwd  Modified to handle BSP CD installation
# 16h,06nov01,bwd  Added SETUP option OVERRIDE to allow user to bypass
#                  installation-over-a-tree policy
# 16g,02nov01,bjl  execute windHostTypeSet sooner so the temp directory can
#                  be created if no env temp vars exist (spr 33750).
# 16f,29oct01,bwd  Added warnings for installation on unrecognized platform on
#                  Windows
# 16e,17sep01,bwd  spr 70204 check return value from hostIdGen
# 16d,11sep01,bwd  Added page APPCONFG. SPR 70283: set destDir value if 
#                  "fileAssociation" SETUP.
# 16c,10sep01,bwd  Added warning on Solaris 2.5 and 2.6 installation
# 16b,02may01,j_w  set hostId to use ether address by default
# 16a,19mar01,j_w  Removed background if option is -L
# 15z,16mar01,j_w  Added Setup /R option for tornado registry configuration
# 15y,16mar01,wmd  Add new command line parameter to Setup for file type
#                  assocations.
# 15x,13mar01,j_w  update version 3.0 to 3.1
# 15w,12mar01,j_w  remove project page (spr 63959)
# 15v,18jan01,bwd  Removed fix for spr 63555
# 15t,10jan01,bwd  SPR 63395: additional fixes - previous fix broke solaris
#                  2.7 patch checking
# 15s,09jan01,bwd  SPR 63395 display warning if user runs SETUP on Linux with
#                  higher Kernel version
# 15r,08jan01,bwd  Initialize variable setupVals(keyString)
# 15q,15dec00,wmd  Correct grammatical and punctualtion errors in pages.
# 15p,02nov00,j_w  Name change - Tornado AE
# 15o,30oct00,j_w  set install type to be licenseSetup and added
#                  destDir page back for setup /L option
# 15n,23oct00,j_w  removed the dbQuery page for setup -C option
# 15m,17oct00,j_w  removed cdObj variable initialization
# 15l,09oct00,j_w  Added the -F option (copy FlexLM files) 
# 15k,03oct00,bwd  SPR 34877: removed checking for X-Server. Log
#                  patch-check warnings to setup.log
# 15j,19sep00,bwd  Added an argument when call hostIdGen
# 15i,18sep00,j_w  renamed page libExtract to libUpdate
# 15h,11sep00,j_w  Initialized the value of ctrlVals(screenW) and 
#                  ctrlVals(screenH) 
# 15g,07sep00,j_w  Used -nocontexthelp in dialogCreate
# 15f,22aug00,bwd  Changed X Window System checking procedure
# 15e,14aug00,bwd  Updated warning message for linux version checking
# 15d,11aug00,bwd  SPR 33076: change the linux kernel version to 2.2.12 in
#                  patchCheck procedure
# 15c,07aug00,bwd  Fixed minor TCL error
# 15b,04aug00,bwd  SPR 33076: added checks for the versions of linux and other
#                  required components in patchCheck
# 15a,10jul00,wmd  Added fix to display solaris host warning correctly for text
#                  mode.
# 14z,07jul00,j_w  Added lmVals(reloadExistingLicense)
# 14y,28jun00,bwd  Removed patch-checking messages for linux in procedure
#                  patchCheck
# 14x,22jun00,wmd  Change the severity of the warning message for solaris 2.5,
#                  2.6.
# 14w,18jun00,wmd  update for linux.
# 14v,09jun00,bwd  Added another host type (x86-linux2) and path (X86/LINUX2)
# 14u,07jun00,bwd  Use setupVals(lmError) to check to remove background
#                  screen, instead of using DISK_ID
# 14t,06jun00,bwd  SPR 31443: added a warning that T3 does not support Solaris
#                  2.5.x and 2.6
# 14s,31may00,bwd  SPR 31564: added currLicInfo page in lmInstOptions pageList
#                  for node locked licensing
# 14r,24may00,j_w  Added setupVals(lmInstType) variable and initialized it to
#                  ""
# 14q,23may00,j_w  Do not create uninstall icon if doing LM installation. This
#                  is a workaround until until uninstall for LM available
# 14p,19may00,wmd  SPR 31003 - Add lmVals(httpToken) value, and cancelDBQUERY
#                  for db tranactions.
# 14o,17may00,bwd  SPR 31030 - design change. Make dbQuery and lmInstOptions 
#                  their own page group
# 14n,15may00,bwd  SPR 31062 - change page list for node lock to go to finish
#                  page instead of lmFinish page
# 14m,11may00,bwd  SPR 31004 - removed REGDLL page
# 14l,10may00,bwd  Fix SPR 31096 - add additional SETUP page, appConfig
# 14k,09may00,bwd  Added a check in applicationExit if the main window/dialog
#                  exists before closing
# 14j,24apr00,j_w  Added dbQuery page to the page list if lmError occurs
# 14i,19apr00,j_w  Removed regTornado page. No need to register dll anymore
# 14h,10apr00,bwd  Remove background for SETUP when prompting error about
#                  License Management
# 14g,27mar00,bwd  Added/initialized additional lmVals for LM
#                  (lmFeaturesTotal)
# 14f,23mar00,bwd  Added documentation for lmVals lists used for License
#                  Management Installation/Configuration.
# 14e,07feb00,bwd  Declared ctrlVals in exitWithMessage proc
# 14d,07feb00,j_w  Include summary page on windows full installation path
# 14c,04feb00,j_w  Add SUMMARY.TCL in tcl file list
# 14b,03feb00,j_w  Add lmExit setupPageList
# 14a,01feb00,bwd  Set setupVals(cancel) to 1 for test automation when
#                  applicationExit is called
# 13z,31jan00,j_w  Added setupVals(userPhone) setupVals(userEmail)
#                  setupVals(sysAdminName)
# 13y,27jan00,j_w  Added checking for windows 2000 (NT5x)
# 13x,25jan00,j_w  Added lmVals(lastServPort)
# 13w,25jan00,j_w  Rename lmPortVal page to licServerPort page and rename
#                  CHKPORT to LICPORT
# 13v,25jan00,bwd  Corrected "startProg" to display correct start page for
#                  TEXT mode
# 13u,24jan00,j_w  Added lmPortVal page 
# 13t,21jan00,j_w  Added lmVals(defaultServPort)
# 13s,21jan00,j_w  Renamed setupVals(lmStartupOptions) to 
#                  setupVals(lmStartupOption)
# 13r,19jan00,j_w  Remove the remoteRegistryHost page - no longer needed in T3
# 13q,11jan00,j_w  Commented the line to source HELPW32.TCL
# 13p,06jan00,j_w  change lambro.wrs.com to www.wrs.com
# 13o,04jan00,bwd  Added licManual page for manual license configuration
# 13n,17dec99,clc  make return value from prompt all lower case
# 13m,16dec99,clc  add parameters call to uninstStop in prompt
# 13l,14dec99,wmd  Add option -L for system administrators to configure only
#                  license management.
# 13k,10dec99,j_w  Initialize CGI program lmVals
# 13j,09dec99,clc  aadd text mode to exitWithMessage
# 13i,08dec99,j_w  Fixed typo
# 13h,07dec99,wmd  Fix error handling.
# 13g,06dec99,wmd  Add code to handle command line options.
# 13f,06dec99,j_w  Add setupVals(licensedProdInstalled) variable
# 13e,24nov99,j_w  Removed support for NT 3.x
# 13d,23nov99,j_w  Remove lmVals(lmRegName)
# 13c,23nov99,j_w  Add lmVals(lmRegName) - Tornado LM registry name 
#                  (see LICMGNT.INF)
# 13b,23nov99,j_w  Add lmVals(lmServName) - Tornado LM service name
#                  (see LICMGNT.INF)
# 13a,17nov99,wmd  Add lmVals(lmHostOrder), lmVals(lmAvailHosts)
# 12z,17nov99,wmd  Need to add new lmVals(reload) variable and initialize it.
# 12y,16nov99,wmd  Add totalRecs init, and remove lmFeaturesTotal.
# 12x,16nov99,clc  add default value for setupVals(cmdMode)
# 12w,16nov99,clc  change text mode variable to setupVals(cmdMode)
# 12v,13nov99,wmd  Fix mispelling of lmLicensedProductNames element for lmVals.
# 12u,11nov99,wmd  Add more lmVals variables.
# 12t,11nov99,j_w  Added lmVals(lmLicenseFile)
# 12s,29oct99,bwd  Testing auto setup (Moved initialization of useInputScript 
#                  in globalInit to be before checking for auto setup)
# 12r,03nov99,j_w  added lmVals(lmPinRequired)
# 12q,31oct99,wmd  Add variable array lmVals for license management.
# 12p,30oct99,wmd  Modify the nodelock page list to add licFileConfig, but
#                  remove lmStartupOptions.
# 12o,29oct99,wmd  Add the endUser and nodeLocked license management pages.
# 12n,27oct99,bwd  Set useInputScript to 0 for manual setup
# 12m,26oct99,bwd  Moved autoSetupLog from UTILW32.TCL
# 12l,26oct99,bjl  close uninstall files in bkgndExit so tmp dir can be
#                  removed.
# 12k,25oct99,bjl  added tmp dir creation for Unix if TMP not set.
# 12j,22oct99,j_w  removed compatibility page on unix and windows
# 12i,21oct99,bjl  removed parisc-hpux support.
# 12h,20oct99,bjl  added preliminary parsing of command line arguments.
# 12g,20oct99,j_w  removed compatibility and howTo page and some comment
#                  Used hostIdGen to set setupVals(hostId)
# 12f,06oct99,clc  modified to add text mode.
# 12e,18oct99,bjl  changed location of libuitclcontrols to cd directory,
#                  changed libUpdate to libExtract.
# 12d,18oct99,j_w  removed duplicate of lmhostid
# 12c,01Oct99,j_w  Changed licGetFinish to licEmailFinish
# 12b,30sep99,j_w  remove http package debugging msg
# 12a,30Sep99,j_w  Modified for T3
# 11b,26apr99,bjl  Check for KDE in dlgFrmCreate, restoreOriginalDialog,
#                  and meterCreate.
# 11a,21apr99,wmd  Fix spr #25970 - by utilizing controlHide first, then
#                  destroying the control, we avoid the refresh problem.
# 10z,08apr99,wmd  Move the unused background window to 10000 10000.
# 10y,08apr99,wmd  Do not use windowSetSize 0 0, use windowShow xxx 0 instead.
# 10x,02apr99,wmd  More fixes for resize problem.
# 10w,31mar99,wmd  Fix resizing problem.
# 10v,31mar99,wmd  Fix spr #226197 by introducing a pause between updates of
#                  ole and com.
# 10u,24mar99,bjl  workaround UITclSh problem with resizing Unix window.
# 10t,22mar99,bjl  move back button to the left on Unix to prevent overlap.
# 10s,19mar99,wmd  Output to a file any debug messages.
# 10r,16mar99,tcy  Added compatiblity and howto pages to UNIX Setup
# 10q,16mar99,tcy  Added safeguard to prevent setup from wiping out
#                  program folders
# 10p,15mar99,tcy  minor fix: need to escape quote in message
# 10o,12mar99,bjl  restored gradient background and banner for windows.
# 10n,01mar99,wmd  Fix progStart to work for all window managers.
# 10m,23feb99,tcy  minimize system rebooting to only once (fix for SPR 22838)
# 10l,18feb99,tcy  placed remoteRegistryHost page after registry page
# 10k,17feb99,tcy  added REGDLL page to program group installation
#                  (partial fix for SPR 24897)
# 10j,11feb99,tcy  added COMPTBLE and HOWTO pages for backward compatibility
# 10i,09feb99,bjl  do not resize next button in restoreOriginalDialog to
#                  fix final oversized OK button on some Unix hosts.
# 10h,03feb99,tcy  hardcode file versions for OLE32.DLL and COMCTL32.DLL
#                  (fix for SPR 24191)
# 10g,03feb99,tcy  fixed "Overwrite one file" bug (SPR 24715, 24135)
# 10f,28jan99,tcy  create new page configSys for configuration user system
# 10e,27jan99,tcy  moved some procedures to INCLUDE.TCL
# 10d,26jan99,tcy  moved regOptionRegValueRead() to REGISTRY.TCL
# 10c,26jan99,tcy  use for loop to source wizard pages
# 10b,26jan99,tcy  added sourcing of permission page
# 10a,25jan99,tcy  reorganize INSTW32.TCL -- move procs to wizard page files
# 09f,25jan99,tcy  added fileContentGet();
#                  convert calls from cdRomRootDirGet() to cdFileNameGet();
#                  move some messages to MESSAGES.TCL
# 09e,25jan99,wmd  Fixed spr 24181, allow partial selection of Tornado product
#                  to be installed without dragging in the driver object.
# 09d,22jan99,wmd  Fix bug in proc onProjLicRecordOK, $error should be error.
# 09c,20jan99,tcy  added more comment headers
# 09b,19jan99,tcy  added comment headers to all procedures;
#                  updated file according to WRS coding convention;
#                  removed license management
# 09a,18jan99,wmd  Fix test automation stuff.
# 08z,14jan99,wmd  Need to eliminate use of FSPACE.TCL, its functions are now
#                  in GLOBAL.TCL.
# 08y,14jan99,wmd  Changename of proc fileAppreviate to fileAbbreviate.
# 08x,10dec98,tcy  corrected logic to show program group for non-administrators
# 08w,09dec98,bjl  added superceding patch messages to patchinfo.
# 08v,04dev98,bjl  allow choice to continue Setup for required patches.
# 08u,04dec98,tcy  remove extra space in first user folder (fixes SPR 23700)
# 08t,03dec98,tcy  reset uninstall link location to SETUP directory
# 08s,02dec98,bjl  convert Unix style slashes to backslashes for Windows
#                  in pageProcess(destDir).
# 08r,25nov98,tcy  use kbyteToMbyte to get available disk space for Windows
# 08q,24nov98,bjl  do not allow any directory starting with a number
#                  for destDir.
# 08p,24nov98,tcy  run htmlBook utility at end of SETUP for UNIX
# 08o,23nov98,tcy  adjusted welcome screen to incoporate new warning message
# 08n,20nov98,bjl  skip filesCopy if user chooses to exit during setupCopy.
# 08m,20nov98,tcy  made last mod applicable for Windows only
# 08l,19nov98,tcy  prevent user from choosing directory with leading numbers
#                  or directory without absolute paths
# 08n,19nov98,bjl  append web site location to patchinfo.
# 08m,18nov98,bjl  create patchinfo file during Unix patch checking to be
#                  displayed at the shell when setup exits.
# 08l,17nov98,bjl  lowered space required/available labels for Unix (fixes
#                  spr 23328).
# 08k,13nov98,wmd  fix spacing for choice button text.
# 08j,13nov98,wmd  create page for installation or program group icon
#                  installation choices for the user.
# 08i,13nov98,bjl  move torRegistry radio buttons up for Win95, changed
#                  order of radio button creation.
# 08h,12nov98,tcy  provide option for FAE to not save installation key
# 08g,12nov98,wmd  change order of choice boxes in Tornado Registry page,
#                  change shortcut key for browse to be 'r' in destDir page.
# 08f,11nov98,bjl  replaced all group boxes with labels and frames (fixes
#                  spr 23061).
# 08e,11nov98,bjl  restore window in restoreOriginalDialog before resizing
#                  (fixes spr 22841).
# 08d,10nov98,tcy  removed batch file creation for regTornado.bat;
#                  added call to backupFileQueueFlush to command queue;
#                  disallow white space in destination directory (fix for SPR
#                  22793); run htmlbook tool
# 08c,09nov98,wmd  need to make setupVals(drvIndex) and array of indices.
# 08b,30oct98,bjl  added noColorMgr check, remove setup icon from welcome page
#                  if color manager not running.
# 08a,28oct98,wmd  if the installation key is "none" remove the projInfo page.
# 07z,28oct98,bjl  allow overwrite of existing products for test automation,
#                  fixed problem with Next button after minimize on Unix.
# 07y,27oct98,bjl  do not check for tornadoInstalled in folderSelect for icon
#                  install, open explorer in iconFinish, reduce tor registry
#                  label height for win95, do not display message about
#                  exiting all programs for Unix, fixed various labels for
#                  mw build 96.
# 07x,27oct98,bjl  added patchCheck procedure and recommended patch handling.
# 07w,27oct98,tcy  added nextCallback for finish page in automated test
# 07v,26oct98,tcy  changed "Select Components" to "Select Products"
#                  added check for disk space on Windows
# 07u,25oct98,tcy  added backupFileQueueFlush call after filesCopy and
#                  fixed return values of tempDirectory
# 07t,22oct98,wmd  change title of "I accept" button, check key shortcuts.
# 07s,21oct98,tcy  set focus on OK button in finish page; create folder
#                  before creating icons if tornado is not installed
# 07r,21oct98,wmd  fix bug when compsel page is wrapped around using space key
#                  when selected/deselecting the drv/objects.
# 07q,20oct98,tcy  fixed typo in prgGrp variable ; removed newDestDir variable
# 07p,20oct98,tcy  added sourcing of REGSAVE.TCL for updating registry to T2;
#                  update comctl32.dll on Win95 if necessary
# 07o,20oct98,bjl  reduced height for tor reg description label for win95,
#                  do not display reg desc. on remote page for Windows,
#                  lower meter for billboard display.
# 07n,20oct98,wmd  fix some button coordinates.
# 07m,20oct98,wmd  same fix for tornadoSelected.
# 07l,20oct98,wmd  make sure setupVals(devIndex) is valid before using it.
# 07k,19oct98,bjl  lower license agreement button for Unix, added
#                  tornado registry description to torRegistry page, make
#                  torRegistry and remoteRegistryHost titles consistent.
# 07j,16oct98,wmd  if Tornado selected, don't allow de-selection of driver
#                  product.
# 07i,16oct98,wmd  bold the message to exit all programs.
# 07h,19oct98,bjl  added code to place billboards in dialog window. Set
#                  the env variable SETUP_REMOVEBACKGROUND=1 to activate.
# 07g,16oct98,tcy  do not write installation key to registry if user is FAE
# 07f,15oct98,tcy  do not copy atl.dll to system directory
# 07e,15oct98,tcy  enable detail button for all product with subparts
# 07d,13oct98,wmd  Reverse the order for the Registry and Project Info pages,
#                  and automatically extract the WRS license field.
# 06c,09oct98,bjl  added code to remove background and limit colors. Set
#                  the env variable SETUP_LIMITCOLORS=1 to activate.
# 06b,09oct98,wmd  fix for test automation.
# 06a,09oct98,bjl  use solid background and product label bitmap for Windows.
# 05z,09oct98,tcy  fixed patch scenario
# 05y,07oct98,bjl  do not call uninstStop unless uninstHomeDir is set.
# 05x,06oct98,bjl  added permissions page for Unix.
# 05w,06oct98,tcy  save tornado registry option in registry
# 05v,06oct98,wmd  fixed bug in installedProdGet.
# 05u,06oct98,tcy  used defGroupGet instead of Tornado for
#                  opening program folder; added CD description to
#                  welcome and registry frames
# 05t,05oct98,bjl  removed unsupported -topmost flag from proc dlgFrmCreate.
# 05s,01oct98,wmd  open explorer on the Tornado group for windows hosts.
# 05r,29sep98,wmd  fix envPathSet to respect UNIX names.
# 05q,29sep98,wmd  move display of README.TXT to right after welcome screen
# 05p,30sep98,tcy  move setupCopy ahead of filesCopy
# 05o,29sep98,wmd  added readmeDlg to ask if user wishes to read README.TXT.
# 05n,29sep98,tcy  added "yes_exit" dialog box
# 05m,29sep98,tcy  update Uninstall string from Tornado 1.0.1 to Tornado 2.0
# 05l,29sep98,wmd  fix hardcoding of SUN4/SOLARIS2 for CD_BIN
# 05k,29sep98,tcy  check for dcom95 installation at start and removed dcom page
# 05j,28sep98,bjl  display README.TXT and NEW.TXT at finish.
# 05i,26sep98,tcy  added progressmeter to DLL registration page
# 05h,25sep98,bjl  added required patch checking before setup starts, remove
#                  setup.log.abort at finish.
# 05g,25sep98,tcy  make sure ATL.DLL is run first
# 05f,25sep98,wmd  display blank lines in license.txt for clarity.
# 05e,25sep98,wmd  left out some procs while merging, fixed it.
# 05d,25sep98,wmd  add warning if any installed product is about to be
#                  overwritten, fix how to use choice buttons in proc dialog.
# 05c,24Sep98,vhe  Corrected boggus desc in partGuiChkLstUpdate
#                  Added automatic selection of WTX component for
#                  automatic setup
# 05b,24sep98,tcy  For dll registration, call batch file if exec does not work
# 05a,23sep98,tcy  use batch file to workaround exec bug ;
#                  set overwritePolicy if user installs to new directory
# 04z,22sep98,bjl  added tornado-vxsim for tornadoInstalled setting, changed
#                  setupVals(prodRegEntry) to Tornado 2.0, do not write
#                  reg values immediately for remote registry, fixed remote
#                  registry writing for unix, close mainWindow in
#                  applicationExit to fix exit problems.
# 04y,22sep98,tcy  added regTornado page and rearranged dCom page and
#                  regTornado proc; retain duplicate products; enabled
#                  workaround for exit program on Windows; copied Tornado
#                  DLLs before calling regTornado
# 04x,22sep98,wmd  fixed the product info screen dimensions for controls.
# 04w,21sep98,bjl  removed setupBannerAttach, added product label for Windows
#                  and product bitmap for unix.
# 04v,21sep98,tcy  remove duplicate products from product list
# 04u,19sep98,tcy  fixed missing folder names on Win95 and
#                  reregister debugger if failed once
# 04t,17sep98,tcy  adjust finish page and added dcom warning page
#                  disable detail button initially
# 04s,17sep98,bjl  write registry values immediately, do not run uninstStop
#                  if disk is full.
# 04r,17sep98,wmd  fix syntax problems from merging previous checkin.
# 04q,17sep98,wmd  use proc cdFileNameGet, fix onProjRecordOK proc.
# 04p,16sep98,vhe  Add automatic selection of product from configuration file
# 04o,16sep98,tcy  adjusted compSelect page
# 04n,15sep98,wmd  remove confirmation of project info page, changed some
#                  wording, changed how proc dialogCreate worked.
# 04m,14sep98,tcy  print list of products after finish page
# 04l,14sep98,bjl  focus on backgroundWindow first for unix to set correct
#                  colors for welcome page.
# 04k,14sep98,j_w  fix auto setup in registration page
# 04j,11sep98,tcy  added regTornado to register Tornado binaries
# 04i,11sep98,j_w  display products installed in log file in auto install
# 04h,10sep98,j_w  add test modification
# 04g,09sep98,bjl  fixed remove unix tempDir on exit, modified isUnix
#                  procedure, workaround setup.ico with setupico.bmp, moved
#                  projInfo registry values to inf file, workaround for
#                  application exit for unix, include fspace.tcl for unix
#                  available space, use different minimized icon for unix.
# 04f,04sep98,bjl  changed tornado.inf to uppercase, modified tempDirectory
#                  procedure to work with setup wrapper.
# 04e,03sep98,bjl  removed torRegistry page for unix, added tornadoInstalled
#                  check to compSelect, lowered button and frame on license
#                  text page for unix display.
# 04d,03sep98,wmd  removed horizontal scroll bar from license text page.
# 04c,03sep98,bjl  modified to handle unix directories, added borders to
#                  text boxes, removed folderSelect page for unix,
#                  fixed exit dialogs to return values for unix.
# 04b,02sep98,tcy  torRegistry/remoteRegistryHost pages moved before filesCopy
# 04a,01sep98,wmd  incorporate license/project info into the setup widzard.
# 03z,26aug98,tcy  added context-sensitive help for all dialogs/controls
# 03Y,25aug98,wmd  fix the license text to fit into dialog frame nicely.
# 03X,24aug98,wmd  allign input text boxes for project info.
# 03W,20aug98,wmd  modify to identify and prevent installation over T101 tree.
# 03v,19aug98,wmd  modified for Mainwin.
# 03u,19aug98,tcy  added dialog box prompting for WIND directory if ZIP files
#                  are not found
# 03t,17aug98,j_w  fix various pages for auto installation
# 03s,12aug98,wmd  add license agreement page, license record dialog to Setup.
# 03r,14aug98,j_w  add modification for test automation
# 03q,10aug98,tcy  added extra argument "args" for linkCreateLog
# 03p,10aug98,tcy  use COM interface functions to create folders and links
# 03o,06aug98,tcy  fixed bug of missing curly brace in keyData registry
# 03n,05aug98,bjl  write user data to registry from tornado.inf when setup
#                  finishes.
# 03m,04aug98,tcy  fixed meter for libUpdate()
# 03l,04aug98,bjl  added processing of warning message file from inf file.
# 03k,04aug98,wmd  modified to add check for coreProd, and edited some warnings.
# 03j,03aug98,bjl  modified setup /ICON to update registry and use inf file.
# 03i,30jul98,bjl  added inf file processing; removed service install of
#                  Tornado Registry, Tornado icon functions, functions that
#                  store Tornado specific data into the Windows Registry,
#                  and fileDup of .TXT files (now handled by inf files);
#                  allow installation of Registry as a service without
#                  the portmapper.
# 03h,29jul98.wmd  added error handling to check responses for overwrite/core
#                  installation.
# 03g,28jul98,tcy  modified for new UITclSh
# 03f,27jul98,tcy  changed to controlPropertySet in libUpdate frame
# 03e,24jul98,wmd  fixed bitmap fading for bbrdUpdate.
# 03d,23jul98,wmd  add dialog for corefile installation, new dialog for setting
#                  overwrite policy, uitclsh t2 changes.
# 03c,23jul98,tcy  added multi-key selection capability
# 03b,22jul98,tcy  added system check for TCP-IP and long filename
# 03a,22jul98,tcy  removed portMapper and moved License procs to LICW32.TCL
# 02j,01apr98,pdn  fixed localHost to localhost
# 02i,09feb98,pdn  continued even after getting BAD_CD_REVISION message.
# 02h,16sep97,pdn  allowed the 'none' key to be changed.
# 02g,01jul97,pdn  fixed the available diskspace problem.
# 02f,13jun97,pdn  added error handling in case key vendor mismatch.
# 02e,08apr97,pdn  fixed remote icon install problem, fixed mail sending
#                  problem, copied *.TXT from root of CDROM to root of
#                  tornado tree.
# 02d,28mar97,pdn  fixed the problem that torVarCreate get call too early
# 02c,25mar97,pdn  asigned 'localHost' to WIND_REGISTRY if user chooses to
#                  run wtxregd.exe locally.
# 02b,17mar97,pdn  used "WindLM" instead of "Wind License Manager" for
#                  service name on NT.
# 02a,12mar97,pdn  fixed setup problem when portMapper is running.
# 01z,07mar97,pdn  fixed the resource logging problem.
# 01y,05mar97,pdn  sorted the product list.
# 01w,03mar97,pdn  added the minimize flag when creating icons in the startup
#                  group.  created uninstall icon for all Window hosts.
#                  added -p option for patch installation.
# 01v,13feb97,pdn  improved license installation steps.
# 01u,09feb97,pdn  added option to configure a floating license server
# 01t,04feb97,pdn  filted out unused messages from checklist box.
# 01s,24jan97,pdn  cleanup
# 01r,24jan97,pdn  adjusted welcome, and component select dialog.
# 01q,22jan97,pdn  fixed folder install bug.
# 01p,21jan97,pdn  saved the last Tornado group, fixed license install
# 01o,20jan97,pdn  used backslashes where possible, saved installation key
# 01n,16jan97,pdn  surrounded the if conditions w/ braces
# 01m,13jan97,pdn  fixed WIND_REGISTRY location, fixed checklist logic,
#                  moved uninstBinCopy() to INSTALL.TCL, and clean up.
# 01l,06jan97,pdn  updated billboard cyling by product.  cleanup text.
# 01k,18dec96,sks  cleaned up; better error handling on startup; rearranged code
#                  a bit; create & destroy TMP dir.; change location of "TCL" &
#                  "BITMAPS" directories; renamed "TEXT.TCL" to "MESSAGES.TCL"
# 01j,12dec96,pdn  added BAD_CD_REVISION check
# 01i,11dec96,pdn  displayed the feature id/description
# 01h,24nov96,sj   eliminated premature returns.
# 01g,18nov96,sj   replaced global variables with functions
#                  from GLOBAL.TCL
# 01f,14nov96,sj   moved all text messages to TEXT.TCL
# 01e,08nov96,sj   queued up all registry key and value
#                  writes until the end of uninstBinCopy.
# 01d,06nov96,sj   setup now works on 95 and NTs.
# 01c,30oct96,sj   completed the license setup
# 01b,10may96,pdn  adding setup wizard.
# 01a,19apr96,sks  written.

# DESCRIPTION
# This module is the Tcl code for the Setup program. It creates the wizard
# pages.
#
# RESOURCE FILES
# etc/tools/resource/mfg/setup/RESOURCE/TCL/INSTALL.TCL
# etc/tools/resource/mfg/setup/RESOURCE/TCL/GLOBAL.TCL
# etc/tools/resource/mfg/setup/RESOURCE/TCL/MESSAGES.TCL
# etc/tools/resource/mfg/setup/RESOURCE/TCL/CONFIG.TCL
# etc/tools/resource/mfg/setup/RESOURCE/TCL/INF.TCL
# etc/tools/resource/mfg/setup/RESOURCE/TCL/HELPW32.TCL
# etc/tools/resource/mfg/setup/RESOURCE/TCL/UTILW32.TCL

# globals



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
#
proc isUnix {} {
    global env

    if {[info exists env(WIND_HOST_TYPE)]} {
        if { [string match sun4* $env(WIND_HOST_TYPE)]        ||
             [string match "x86-linux2" $env(WIND_HOST_TYPE)] ||
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
# noColorMgr - determine whether environment variable SETUP_NOCOLORMGR is set
#
# This procedure will determine whether environment variable
# SETUP_NOCOLORMGR is set
#
# SYNOPSIS
# .tS
# noColorMgr
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: 0 if enviroment variable SETUP_NOCOLORMGR is not set
#          1 if enviroment variable SETUP_NOCOLORMGR is set
#
# ERRORS: N/A
#
#
#proc noColorMgr {} {
#    global env
#
#    if {[info exists env(SETUP_NOCOLORMGR)]} {
#        if {$env(SETUP_NOCOLORMGR)==1} {
#            return 1
#        }
#    }
#
#    return 0
#}

#############################################################################
#
# parseCmdLine - parse command line arguments
#
# This procedure will parse command line argument
#
# SYNOPSIS
# .tS
# parseCmdLine <switches>
# .tE
#
# PARAMETERS:
# .IP switches
# [/ICON | /I | -I]  install icons only
# [/HELP | /H | /?]  print help messages
# [/TEXT | /T | -T]  text mode
# [/PATCH]=<pathToPatch>  patch mode
# [/L | -L]          license mode
# [/A | -A]          register file type associations
# [/R | -R]          Tornado registry reconfiguration at startup
# [/U | -U | /M | -M | /C | -C | /E | -E] <lmFeatureName> <lmRcStr> <lmErrString>
#                        license error mode
#
# RETURNS: 1 if there is a usage error
#          0 if there are no usage errors
#
# ERRORS: N/A
#

proc parseCmdLine {switches} {
    global tornadoInstalled
    global setupVals patchPath
    global usageError
    global displayedUsageError
    global skipInstalloverCheck

    regsub -all {\\\}} $switches {"} tmp
    regsub -all {\\\{} $tmp {"} tmp1
    regsub -all {\\} $tmp1 {/} switches

    # check for usageError and switches to handle
    # recursive calls.

    if {![info exists usageError]} {
        set usageError 0
        set displayedUsageError 0
    } else {
        if {$usageError != 0} {
            return $usageError
        }
    }

    if {$switches==""} {
        return 0
    }
    
    set usageError [expr [llength $switches] > 6]

    if {!$usageError} {
        set option [string range [lindex $switches 0] 0 8]
        switch -regexp ($option) {
            \-I -
            /I -
            \-i -
            /i -
            /ICON {
                if { [instTypeGet] != "text" } {
                    instTypeSet icon
                    set tornadoInstalled 1
                    parseCmdLine [lrange $switches 1 end]
                } else {
                    puts [strTableGet 1550_USAGE]
                    set displayedUsageError 1
                    set usageError 1
                }
            }
            \-U -
            /U -
            \-u -
            /u -
            \-M -
            /M -
            \-m -
            /m -
            \-C -
            /C -
            \-c -
            /c -
            \-E -
            /E -
            \-e -
            /e {
                dbgputs "parseCmdLine: got licenseError $[lindex $switches 3]"
                instTypeSet licenseError
                set setupVals(lmError) [string toupper [lindex $switches 0]]
                dbgputs "parseCmdLine: lmError detected - $setupVals(lmError)"
                set setupVals(lmFeatureName) [lindex $switches 1]
                set setupVals(lmRcStr) [lindex $switches 2]
                set setupVals(lmErrString) [lindex $switches 3]
                if {$setupVals(lmFeatureName)=="" || $setupVals(lmRcStr)=="" ||
                    $setupVals(lmErrString)=="" } {
                    set usageError 1
                } else {
                    parseCmdLine [lrange $switches 4 end]
                }
	 	if {$setupVals(lmFeatureName) == "WindRiver_GCC"} {
		    # force Setup to simply exit if the feature is gcc

		    set displayedUsageError 1
		    set usageError 1
		    tempDirectory destroy
		}
            }
            \-f -
            /f -
            \-F -
            /F {
                dbgputs "parseCmdLine: flexlm Installation, switch is [lindex $switches 0]"
                instTypeSet flexInst
                parseCmdLine [lrange $switches 1 end]
            }
            \-l -
            /l -
            \-L -
            /L {
                dbgputs "parsCmdLine: license management setup"
                instTypeSet licenseSetup
                parseCmdLine [lrange $switches 1 end]
            }
            \-r -
            /r -
            \-R -
            /R {
                instTypeSet registryInst
                parseCmdLine [lrange $switches 1 end]
            }
            \-t -
            /t -
            \-T -
            /T -
            /TEXT {
                if { [instTypeGet] != "icon" } {
                    set setupVals(cmdMode) "text"
                    parseCmdLine [lrange $switches 1 end]
                } else {
                    puts [strTableGet 1550_USAGE]
                    set displayedUsageError 1
                    set usageError 1
                }
            }
            \-a -
            /a -
            \-A -
            /A {
                instTypeSet fileAssociation
                parseCmdLine [lrange $switches 1 end]
            }
            \-OVERRIDE -
            /OVERRIDE {                
                set skipInstalloverCheck 1
                parseCmdLine [lrange $switches 1 end]
            }
            /? -
            /H -
            /HELP -
            default {
                set option [lindex $switches 0]
                if {[string index $option 0] == "/"  || [string index $option 0] == "-"} {
                    set option [string range $option 1 end]
                    if {[string first "PATCH" $option] == 0 && [string index $option 5] == "="} {
                        # This is a patch specification

                        set patchPath [string range $option 6 end]
                        set patchPath [string trim $patchPath]
                        instKeySet none
                        set skipInstalloverCheck 1
                    } else {
                        set usageError 1
                    }
                } else {
                    set usageError 1
                }
            }
        }
    }

    if {$usageError && $displayedUsageError == 0} {
        messageBox -ok -informationicon [strTableGet 1550_USAGE]
        set displayedUsageError 1
    }
    return $usageError
}


#############################################################################
#
# constructPages - contruct list of pages based on types of installation
#
# This procedure will construct list of pages based on types of installation
#
# SYNOPSIS
# .tS
# constructPages
# .tE
#
# PARAMETERS:
# .IP mode
# icon -- icon installation only
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc constructPages {mode} {
    global ctrlVals
    global dll

    set retVal 1
    set ctrlVals(pageList) {}

    # Initialize page list
    initPageList

    set ctrlVals(currPage) [lindex $ctrlVals(pageList) 0]
    set ctrlVals(pageListBack) $ctrlVals(pageList)
    return $retVal
}

#############################################################################
#
# initPageList - init procedure to construct the default page list
#
# This procedure is a init procedure to construct the default page list
#
# SYNOPSIS
# .tS
# initPageList
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc initPageList {} {
    global ctrlVals setupPageList

    set ctrlVals(pageList) $setupPageList(commonPages)

    if {($ctrlVals(admin) == "1") || ($ctrlVals(NT) != "1")} {
        pageRemove privilege
    }

}


#############################################################################
#
# applicationExit - close the main and background windows for Setup
#
# This procedure will close the main and background windows for Setup
#
# SYNOPSIS
# .tS
# applicationExit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc applicationExit {} {
    global ctrlVals

    closeSetupDebugLog

    set wExist [windowExists -title $ctrlVals(mainWindow)]

    if { $wExist } {
        windowClose $ctrlVals(mainWindow)
    }

    windowClose $ctrlVals(backgroundWindow)
}


#############################################################################
#
# previousPage - return to the previous wizard page
#
# This procedure will bring Setup to the previous wizard page
#
# SYNOPSIS
# .tS
# previousPage
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#
#
#proc previousPage {} {
#    global ctrlVals
#
#    set currPageIndex [lsearch $ctrlVals(pageList) $ctrlVals(currPage)]
#    set prevPageIndex [expr $currPageIndex - 1]
#
#    return [lindex $ctrlVals(pageList) $prevPageIndex]
#}


#############################################################################
#
# exitWithMessage - display exiting messages
#
# This procedure will display exiting messages
#
# SYNOPSIS
# .tS
# exitWithMessage <message>
# .tE
#
# PARAMETERS:
# .IP message
# message to be displayed
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc exitWithMessage {message} {
    global setupVals ctrlVals

    if { "$setupVals(cmdMode)" != "text" } {

        if {$message == ""} {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "[strTableGet 1213_FINISH]"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1
            } else {
                messageBox -ok -stopicon [strTableGet 1213_FINISH]
            }
        } else {
            if { $ctrlVals(useInputScript) } {
                autoSetupLog "$message"
                autoSetupLog "Application Exit\n"
                set setupVals(cancel) 1
            } else {
                messageBox -ok -stopicon "$message"
            }
            uninstLog setupLog "\tSetup terminated: $message"
        }
        applicationExit
        return 0

    } else { # text mode
        if {$message == ""} {
            puts [strTableGet 1213_FINISH]
        } {
            puts $message
            uninstLog setupLog "\tSetup terminated: $message"
        }
        return 0
    }   
}

#############################################################################
#
# bkgndInit - init procedure called when background window is created
#
# This procedure is an initialization procedure called when background
# window is created
#
# SYNOPSIS
# .tS
# bkgndInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc bkgndInit {} {
    global ctrlVals
    global setupVals

    if ![catch {setupScreenDimensionsGet} dimension] {
        set dimension \
            [pixelsToDialogUnits $ctrlVals(backgroundWindow) $dimension]
        set ctrlVals(screenW) [lindex $dimension 0]
        set ctrlVals(screenH) [lindex $dimension 1]
    }

    #dbgputs "screenW = $ctrlVals(screenW)"
    #dbgputs "screenH = $ctrlVals(screenH)"

    set bkgnd [cdFileNameGet [file join RESOURCE BITMAPS BKGNDSOL.BMP]]

    set control [list bitmap -name bitmap \
                             -title $bkgnd \
                             -x 0 -y 0 -stretch \
                             -w $ctrlVals(screenW) \
                             -h $ctrlVals(screenH) \
    ]

    if {[removeBackground]} {
        # this will effectively cause the background to disappear.

        windowShow $ctrlVals(backgroundWindow) 0
    } else {
        windowSizeSet $ctrlVals(backgroundWindow) $ctrlVals(screenW) \
                              $ctrlVals(screenH)
    }

    controlCreate $ctrlVals(backgroundWindow) $control

    if {![removeBackground]} {
        setupBannerAttach [windowHandleGet $ctrlVals(backgroundWindow)] \
                [controlHandleGet $ctrlVals(backgroundWindow).bitmap] \
                [cdromBannerGet]
    }

    windowQueryCloseCallbackSet $ctrlVals(backgroundWindow) quitCallback

#   Next line commented out because it's not guaranteed to work,
#   Left in as a lesson to be learned: window managers affect program behavior.
#   windowActivateCallbackSet $ctrlVals(backgroundWindow) startProg

    startProg
}

#############################################################################
#
# bkgndExit - exit procedure invoked when background is closed
#
# This procedure is a exit procedure invoked when background is closed
#
# SYNOPSIS
# .tS
# bkgndExit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc bkgndExit {} {
    global ctrlVals
    global setupVals
    global env

    beginWaitCursor
    if {[uninstHomeDirGet] != "" && ![info exists setupVals(diskfull)]} {

        # workaround until uninstall for LM install is available
        # Do not create uninstall icon if do floating license installation
        if {"$setupVals(lmInstType)" != "floating"} {
            uninstStop [getProdInfo name] [getProdInfo version]
                }
    } else {
        # call queueExecute here since we don't call it in uninstStop

        queueExecute

        # close uninstall files so the temp directory can be removed.

        uninstFileClose
    }

    if {[isUnix]} {
        #  do not destroy temp directory yet if TMP/patchinfo exists.
            #  The SETUP script will remove the temp directory after the
            #  patchinfo message is displayed.
        if {![file exists $env(TMP)/patchinfo]} {
            catch {tempDirectory destroy}
        }
    } else {
        catch {tempDirectory destroy}
    }

    endWaitCursor
}

#############################################################################
#
# applicationStart - create the background and main windows
#
# This procedure will create the background and main windows
#
# SYNOPSIS
# .tS
# applicationStart
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc applicationStart {} {
    global setupVals
    global ctrlVals

    if { $setupVals(cmdMode) != "text" } {
        set ctrlVals(parentDialog) $ctrlVals(backgroundWindow)
        if {![isUnix]} {

            dialogCreate -title "Setup" \
                         -name $ctrlVals(backgroundWindow) \
                         -nocontexthelp \
                         -init bkgndInit \
                         -exit bkgndExit \
                         -icon [cdFileNameGet \
                               [file join RESOURCE BITMAPS SETUP.ICO]] \
                         -thinframe -minibox -maxibox \
                         -x 0 -y 0

        } elseif {![removeBackground]} {
            # use an icon for Unix with less colors than Windows
            dialogCreate -title "Setup" \
                         -name $ctrlVals(backgroundWindow) \
                         -nocontexthelp \
                         -init bkgndInit \
                         -exit bkgndExit \
                         -thinframe -minibox -maxibox \
                         -x 0 -y 0
#                        -icon [cdFileNameGet
#                              [file join RESOURCE BITMAPS SETUPUNX.ICO]]

        } else {
            # This is the case for when we want to remove the background.

            # remove the title, otherwise a small residual window appears, even
            # when the window size is set to 0 0 in bkgndInit.  A thinframe is
            # also necessary.

           dialogCreate -notitle \
                         -name $ctrlVals(backgroundWindow) \
                         -helpfile $setupVals(setupHelp) \
                         -nocontexthelp \
                         -init bkgndInit \
                         -exit bkgndExit \
                         -thinframe \
                         -x 10000 -y 10000
#                         -icon [cdFileNameGet
#                        [file join RESOURCE BITMAPS SETUPUNX.ICO]]
        }
    } else {  # TEXT mode
        startProg
    }

    return $setupVals(cancel)
}

#############################################################################
#
# startProg - callback procedure invoked when Setup window is active
#
# This procedure is a callback procedure invoked when Setup window is active
#
# SYNOPSIS
# .tS
# startProg
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc startProg {} {
    global ctrlVals env
    global setupVals

    set lic 0
    set pageName [lindex $ctrlVals(pageList) 0]

    if { $setupVals(cmdMode) != "text"} {
        windowActivateCallbackSet $ctrlVals(backgroundWindow) ""

        pageCreate($pageName)

        if {[isUnix]} {
            # focus on backgroundWindow first to set correct colors
            # for welcome screen
            setupWindowFocusSet $ctrlVals(backgroundWindow)
        }

    } else {
        pageCreate($pageName)
    }
}


#############################################################################
#
# envPathSet - add bin directory to the PATH environment variable
#
# This procedure will add bin directory to the PATH environment variable
#
# SYNOPSIS
# .tS
# envPathSet
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc envPathSet {} {
    global env

    if {[isUnix]} {
        set exePath [dosToUnix [file dirname [info nameofexecutable]]]
    } else {
        set exePath [unixToDos [file dirname [info nameofexecutable]]]
    }

    foreach elem [array names env] {
        if {[string compare [string tolower $elem] "path"] == 0} {
            if {[isUnix]} {
                set env($elem) "[cdromBinDirGet]:$exePath:$env($elem)"
            } else {
                set env($elem) "[cdromBinDirGet];$exePath;$env($elem)"
            }
            return
        }
    }
    if {[isUnix]} {
        set env(PATH) "[cdromBinDirGet]:$exePath"
    } else {
        set env(PATH) "[cdromBinDirGet];$exePath"
    }
}

#############################################################################
#
# tempDirectory - create, destroy or return the temp directory based on option
#
# This procedure will create, destroy or return the temp directory based
# on option
#
# SYNOPSIS
# .tS
# tempDirectory <option>
# .tE
#
# PARAMETERS:
# .IP options
# create  -- create the temp directory
# destroy -- destroy the temp directory
# get     -- return the temp directory path
#
# RETURNS: return the temp directory path if option is create or get;
#          nothing otherwise
#
# ERRORS: N/A
#

proc tempDirectory {option} {
    global env

    if { $option == "create" } {
        # Determine the "temp" directory

        set uninstTemp "WIND_TMP[pid]"

        foreach elem [array names env] {
            if {[string compare [string tolower $elem] "tmp"] == 0} {
                set env(TMP) $env($elem)
            }
            if {[string compare [string tolower $elem] "temp"] == 0} {
               set env(TEMP) $env($elem)
            }
            if {[string compare [string tolower $elem] "tmpdir"] == 0} {
               set env(TMPDIR) $env($elem)
            }
        }

        if { ![isUnix] } {
            if {[info exists env(TEMP)] && [file isdir $env(TEMP)]} {
                set env(TMP) $env(TEMP)\\$uninstTemp
            } elseif {[info exists env(TMP)] && [file isdir $env(TMP)]} {
                set env(TMP) $env(TMP)\\$uninstTemp
            } elseif {[info exists env(TMPDIR)] && [file isdir $env(TMPDIR)]} {
                set env(TMP) $env(TMPDIR)\\$uninstTemp
            } else {
                if {[windHostTypeGet] == "x86-win32"} {
                    set env(TMP) "C:\\$uninstTemp"
                }
            }
        }

        if { [isUnix] } {
            if {![info exists env(TMP)]} {
                set env(TMP) /tmp/$uninstTemp
                file mkdir $env(TMP)
            } else {
                set env(TMP) [dosToUnix $env(TMP)]
            }
        }

        if { ![isUnix] } {
            # tmp directory already exists for unix from setup wrapper

            file mkdir $env(TMP)
        }

        return $env(TMP)

    } elseif {$option == "destroy"} {
        if {![isUnix]} {
            cd c:/
        }
        file delete -force $env(TMP)

    } elseif {$option == "get"} {
        return $env(TMP)

    } else {
        error "unknown option: $option"
    }
}

#############################################################################
#
# patchCheck - check if patches need to be applied to UNIX user systems
#
# This procedure will check if patches need to be applied to UNIX user systems
# For T2.2: Give warnings for Solaris 2.5 and 2.6 installations (not supported).
#
# SYNOPSIS
# .tS
# patchCheck
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc patchCheck {} {
    global setupVals
    global ctrlVals
    global env

    if {[isUnix]} {
        # bypass patch checking for test automation
        # test automation

        if {$ctrlVals(useInputScript)} {
            autoSetupLog "Unix patch checking: Skipped"
            return 1
        }

        # check OS version

        catch {exec /bin/uname -r} osversion
        dbgputs "CheckPatch: osversion = $osversion"

        if {$osversion == "5.6"} {
            set solaris26 1
            set solaris "2.6"
        } else {
            set solaris26 0
        }

        if {[regsub 5\.5 $osversion {} ignore]} {
            set solaris25 1
            set solaris "2.5.x"
        } else {
            set solaris25 0
        }

        if { $solaris26 || $solaris25 } {
            # warn user that T2.2 does not support Solaris 2.5.x and 2.6

            set message "WARNING: SETUP has detected that this machine is\
                         running on Solaris $solaris. [cdromDescGet] does\
                         not officially support Solaris 2.5.x and Solaris 2.6."

            if { $setupVals(cmdMode) != "text" } {
                set msg "$message If you wish to continue with [cdromDescGet]\
                         products installation, please click OK.\
                         Otherwise, click Cancel to exit SETUP."

                switch -- [dialog ok_cancel "SETUP" $msg] {
                    "0" { # proceed with installation

                        uninstLog setupLog \
                            "SETUP detected the following warning, and\
                             installation was continued:\n\"$message\""
                    }
                    "1" {  
                        uninstLog setupLog \
                            "SETUP detected the following warning and\
                             was terminated:\n\"$message\""
                        return 0  
                    }
                }
                } else {
                set msg "$message\nIf you wish to continue with [cdromDescGet]\
                         products installation, please press the \<Return\>\
                         key. Otherwise, type \'exit\' to exit SETUP."

                set ret [prompt "$msg\n"]

                        if { [regexp {[eE][xX][iI][tT]} $ret] } {
                    uninstLog setupLog \
                        "SETUP detected the following warning and\
                         was terminated:\n\"$message\""
                            return 0
                } else {
                    uninstLog setupLog \
                        "SETUP detected the following warning, and\
                         installation was continued:\n\"$message\""
                }
            }
        }

        # For supported version of UNIX, do not display warnings.
        # Proceed to check patches.

        set prod [string toupper [getProdInfo name]]
        searchAndProcessSection CheckPatch [cdFileNameGet \
            [file join RESOURCE INF $prod.INF]]
        if {$setupVals(uninstalledPatches_required) != ""} {

            set patchText [strTableGet 5000_PATCHES_REQUIRED_TEXT]
            set patchinfoText \
                [strTableGet 5003_PATCHES_REQUIRED_FORMATTED_TEXT]
            append patchText $setupVals(uninstalledPatches_required)
            append patchinfoText $setupVals(uninstalledPatches_required)

            if {$setupVals(uninstalledPatches_recommended) != ""} {
                append patchText [strTableGet 5001_PATCHES_RECOMMENDED_TEXT] 
                append patchText $setupVals(uninstalledPatches_recommended)
                append patchinfoText \
                    [strTableGet 5004_PATCHES_RECOMMENDED_FORMATTED_TEXT] 
                append patchinfoText $setupVals(uninstalledPatches_recommended)
            }

            if {$env(WIND_HOST_TYPE)=="sun4-solaris2"} {
                append patchText [strTableGet 5006_PATCHES_SUN_LOCATION]
                append patchinfoText [strTableGet 5006_PATCHES_SUN_LOCATION]
            } elseif {$env(WIND_HOST_TYPE)=="parisc-hpux10"} {
                append patchText [strTableGet 5007_PATCHES_HP_LOCATION]
                append patchinfoText [strTableGet 5007_PATCHES_HP_LOCATION]
            }

            append patchText [strTableGet 5008_PATCHES_UPDATE]
            append patchinfoText [strTableGet 5009_PATCHES_UPDATE_FORMATTED]
           
            # write patch info to TMP/patchinfo to be printed to the
            # console later.  This will allow the user to cut and
            # paste information since cut and paste is not allowed from
            # a messagebox.
            set patchfile "$env(TMP)/patchinfo"
            set patchfileId [open $patchfile w]
            puts $patchfileId $patchinfoText
            close $patchfileId
            
            append patchText "\nNote: This message will also be reprinted to\
                              your shell when you exit."
            append patchText "\n\nWould you prefer to continue with SETUP?\n\n\
                              If you click the Yes button, SETUP will proceed\
                              with installation.  However, this may cause\
                              SETUP and/or your system to become unstable, and\
                              we strongly recommend that you install the\
                              patches before proceeding.  (If you know that\
                              you have installed patches that supercede or\
                              are equal to those listed above, it should be\
                              safe to continue.)  SETUP will exit if\
                              you click the No button."
            set result [messageBox -yesno -stopicon $patchText]
            if {$result == "no"} {
                return 0
            }
        } elseif {$setupVals(uninstalledPatches_recommended) != ""} {
            set patchText [strTableGet 5002_PATCHES_RECOMMENDED_TEXT]
            append patchText $setupVals(uninstalledPatches_recommended)
            set patchinfoText \
                [strTableGet 5005_PATCHES_RECOMMENDED_FORMATTED_TEXT]
            append patchinfoText $setupVals(uninstalledPatches_recommended)
            
            if {$env(WIND_HOST_TYPE)=="sun4-solaris2"} {
                append patchText [strTableGet 5006_PATCHES_SUN_LOCATION]
                append patchinfoText [strTableGet 5006_PATCHES_SUN_LOCATION]
            } elseif {$env(WIND_HOST_TYPE)=="parisc-hpux10"} {
                append patchText [strTableGet 5007_PATCHES_HP_LOCATION]
                append patchinfoText [strTableGet 5007_PATCHES_HP_LOCATION]
            }

            append patchText [strTableGet 5008_PATCHES_UPDATE]
            append patchinfoText [strTableGet 5009_PATCHES_UPDATE_FORMATTED]
            
            # write patch info to TMP/patchinfo to be printed to the
            # console later.  This will allow the user to cut and
            # paste information since cut and paste is not allowed from
            # a messagebox.

            set patchfile "$env(TMP)/patchinfo"
            set patchfileId [open $patchfile w]
            puts $patchfileId $patchinfoText
            close $patchfileId

            append patchText "\nNote: This message will also be reprinted to\
                              your shell when you exit SETUP."
            messageBox $patchText
        }
    } elseif {![windowsSystemCheck]} {
        return 0
    } 
    return 1
}

#############################################################################
#
# printPageTitle - prints header for command-line setup pages
#
# SYNOPSIS
# .tS
# printPageTitle
# .tE
#
# PARAMETERS:
# .IP msg
# title message to be displayed
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc printPageTitle {msg} {

    for {set i 0} {$i < 2} {incr i} {
        puts ""
    }
    for {set i 0} {$i < 80} {incr i} {
        puts -nonewline "="
    }
    puts ""
    set space [expr (80 - [string length $msg]) / 2 ]
    for {set i 0} {$i < $space} {incr i} {
        puts -nonewline " "
    }
    puts -nonewline "$msg"
    puts ""
    for {set i 0} {$i < 80} {incr i} {
        puts -nonewline "="
    }
    puts ""
}

#############################################################################
#
# prompt - prints a message and prompt for input
#
# This procedure will print a message if provided and display a prompt for
# input
#
# SYNOPSIS
# .tS
# prompt
# .tE
#
# PARAMETERS:
# .IP msg
# message to be displayed
#
# RETURNS: user input at prompt
#
# ERRORS: N/A
#

proc prompt {{msg ""}} {

    global setupVals

    if { "$msg" != "" } {
        puts $msg
    }
    puts -nonewline "-> "
    flush stdout
    set ans [gets stdin]
    set ans [string trim $ans " " ]
    puts ""
    if { [regexp {[eE][xX][iI][tT]} $ans] } {
        catch {
            uninstLog setup "\tUser aborted!"
            if {[uninstHomeDirGet] != "" && ![info exists setupVals(diskfull)]} {
                uninstStop [getProdInfo name] [getProdInfo version]
            }
        }
    }
    return $ans
}

#############################################################################
#
# autoSetupLog - put message in setup log file for test automation
#
# This procedure will put message in setup log file for test automation
#
# SYNOPSIS
# .tS
# autoSetupLog <msg>
# .tE
#
# PARAMETERS:
# .IP msg
# message to be inserted in setup log file for test automation
#
# RETURNS: N/A
#
# ERRORS: -1 if unsuccessful
#

proc autoSetupLog {msg} {
    global autoSetupLogFile

    if [catch {open $autoSetupLogFile a+} file] {
        puts "Error in writing $autoSetupLogFile"
        return -1
    }
    puts $file "[getDate]: $msg"
    close $file
}

#############################################################################
#
# checkBSPcd - check for BSP CD
#
# This procedure will set internal variable to indicate this is a BSB CD
#
# SYNOPSIS
# .tS
# checkBSPcd
# .tE
#
# PARAMETERS: None
# 
#
# RETURNS: N/A
#
# ERRORS: None
#

proc checkBSPcd {} {
    global env
    global setupVals

    if ![catch {open [file join $env(CD_ROOT) DISK_ID] r} fId] {
        # get the 2nd line (pool desc)
        gets $fId line
        gets $fId line  
        if [regexp {BSPs*} $line] {
            set setupVals(BSPcd) 1
        }
        close $fId
    }
}

#############################################################################
#
# globalInit - initialize all global variables
#
# This procedure will initialize all global variables
#
# SYNOPSIS
# .tS
# globalInit
# .tE
#
# PARAMETERS: N/A
#
# RETURNS: N/A
#
# ERRORS: N/A
#

proc globalInit {} {
    global setupVals ctrlVals env dll argv cdObj
    global autoSetupLogFile
    global projLic
    global projName
    global projLicUsers
    global lmVals lmTotalRecs lmHostFeaturesNum lmHostRecs lmHostRecsLen
    global cancelDBQUERY patchPath lmPackages lmPurchasedProds

    # Get the CD root directory
    if {![isUnix]} {
        # change slashes for win32

        regsub -all {/} [lindex $argv 0] {\\} env(CD_ROOT)
        if {![info exists env(HOME)]} {
            set env(HOME) "C:"
        }
    } else {
        set env(CD_ROOT) [lindex $argv 0]
        if {![info exists env(HOME)]} {
            set env(HOME) "~"
        }
    }

    # make sure we can read the filename on the CD
    # INCLUDE.TCL - procedures sourced by INSTW32.TCL and INCLUDE.TCL
    # GLOBAL.TCL  - procedures sourced by INSTW32.TCL only

    set sourceList "GLOBAL INCLUDE"
    
    foreach includeFile $sourceList {
        set fileName [file join RESOURCE TCL $includeFile.TCL]
        set fn [string toupper $fileName]
        if {[file exists [file join $env(CD_ROOT) $fn]]} {
            set globFile [file join $env(CD_ROOT) $fn]
        }
        set fn [string tolower $fileName]
        if {[file exists  [file join $env(CD_ROOT) $fn]]} {
            set globFile [file join $env(CD_ROOT) $fn]
        }
        source $globFile
    }

    # set env(CD_BIN)
    if {[isUnix]} {
        if {$env(WIND_HOST_TYPE) == "sun4-solaris2"} {
            set env(CD_BIN) "$env(CD_ROOT)/SUN4/SOLARIS2"
        } elseif {$env(WIND_HOST_TYPE) == "x86-linux2"} {
            set env(CD_BIN) "$env(CD_ROOT)/X86/LINUX2"
        } elseif {$env(WIND_HOST_TYPE) == "parisc-hpux10"} {
            set env(CD_BIN) "$env(CD_ROOT)/PARISC/HPUX10"
        }
    } else {
        set env(CD_BIN) "$env(CD_ROOT)\\X86\\WIN32"
    }
    
    # load setuptcl.dll or setuptcl.so
    load [cdromBinDirGet]/SETUPTCL[string toupper [info sharedlibextension]]

    # load dll for email
    if { ![isUnix] } {
        # Load the Support.dll which contains the mail API
        if [catch {dllLoad [cdromBinDirGet]\\SUPPORT.DLL} dll(1)] {
            messageBox -ok -stopicon $dll(1)
            return 0
        }
                
        # Load the TGensock.dll which contains the socket API
        if [catch {dllLoad "[cdromBinDirGet]\\TGENSOCK.DLL"} dll(2)] {
            messageBox -ok -stopicon $dll(2)
            return 0
        }
    }
        
    # Detect the version of windows/UNIX we are running
    # if unix, setupWinVerGet will return "WIN31s"
    set ctrlVals(version) [setupWinVerGet]

    if {$ctrlVals(version) == "NT4x" || $ctrlVals(version) == "NT5x" \
        || $ctrlVals(version) == "XP" } {
        set ctrlVals(NT) 1

    } elseif {$ctrlVals(version) == "WIN95" || $ctrlVals(version) == "WIN98" } {
        set ctrlVals(NT) 0
        # exit if not a valid windows platfrom
        if { ![isUnix] } {
            set msg "Unsupported windows Platform detected. The supported\
                    platforms are Windows NT 4.0, Windows 2000, and Windows XP.\n"
            messageBox -ok -stopicon $msg
            return 0
        }
    } else {
        set ctrlVals(NT) 0
        # WARN if unrecognized platform
        if { ![isUnix] } {
            set msg "The windows platform you are running on is unrecognized\
                     by SETUP. The supported platforms are Windows NT 4.0, Windows\
                     2000, and Windows XP. However, you may proceed to install at\
                     your own risk. Would you like to continue?\n"
            switch [messageBox -yesno -questionicon $msg] {
                no { return 0 }
            }
        }
    }

    # add bin directory to PATH
    envPathSet

    # Work around for the case sensitivity clash of the environment vars
    # between Windows and TCL.

    foreach elem [array names env] {
       if {[string compare [string tolower $elem] "tmp"] == 0} {
           regsub -all {/} $env($elem) {\\} env(TMP)
           break
       }
    }

    if [isUnix] {
        windHostTypeSet $env(WIND_HOST_TYPE)
    } else {
        windHostTypeSet "x86-win32"
    }

    # Create the "temp" directory (destroyed in "bkgndExit")

    if [catch {tempDirectory create} errStr] {
        messageBox "Unable to create temporary directory: $errStr"
        return -1
    }

    set setupVals(BSPcd) 0
    # Check if core or BSP installation
    checkBSPcd
    set projLic ""
    set projName ""
    set projLicUsers ""

    set ctrlVals(useInputScript) 0
    set setupVals(uninstalledPatches_required) ""
    set setupVals(uninstalledPatches_recommended) ""
    set setupVals(evaluation) 0
    set setupVals(errorCount) 0
    set setupVals(cancel) 0
    set setupVals(uninstFile) ""
    set setupVals(instMode) ""
    set setupVals(keyString) ""   
    
    # This is the default toolset as of Tornado 2.2.1.

    # Substrings must come later in the list, for example "gnu" must come 
    # after "sfgnule|sfgnu".  This is because the toolset is used
    # as a pattern matcher during archiving to strip out any existing cpu 
    # variant from the "tool" string.  Regexp will match the first 
    # string found, so we don't want only "sfgnu" extracted out of 
    # "sfgnule_vr54xx" for example (refer to newLibUpdateHelper in 
    # LIBUPDTE.TCL).

    set setupVals(toolset) "sfr3kdiab|sfdiable|diable|sfdiab|diabbe|diab|sfr3kgnu|sfgnule|sfgnu|gnule|gnube|gnu"

    # get hostname and hostId

    set setupVals(hostName) [info host]

    set setupVals(hostId) [hostIdGen]
    if { $setupVals(hostId) == -1 } {
        # if invalid hostId, exit       
        return -1
    }

    set setupVals(sysAdminName) ""
    set setupVals(userPhone) ""
    set setupVals(userEmail) ""
    set setupVals(components) ""
    set setupVals(commandQueue) ""
    set setupVals(fileName) ""
    set setupVals(WRS) "Wind River Systems"

    # Note: For the following variables, CONFIG.TCL must first be 
    # sourced to define name and version. These variables will be
    # defined later after CONFIG.TCL is sourced
    #    ** Do not define them here **
    #
    set setupVals(torRegServName) ""
    set setupVals(torVersionNum) ""
    set setupVals(defGroup) ""    
    set setupVals(prodRegEntry) ""
    set setupVals(defDestDirWin32) ""
    set setupVals(defDestDirUnix) ""
    set lmVals(lmServName) ""
                       
    set setupVals(keyList) ""
    set setupVals(drvIndex) -1    
    set setupVals(licensedProdInstalled) 0

    set setupVals(ELMUser) 0
    set setupVals(lmManual) 0
    set setupVals(lmHostManual) ""
    set setupVals(lmInstOptions) ""
    set setupVals(installChoice) ""
    set setupVals(lmStartupOption) ""
    set setupVals(dbQueryOptions) ""
    set setupVals(licConfigType) ""
    set setupVals(lmOptions) ""
    set setupVals(lmAutoManChoice) ""
    set setupVals(lmError) ""
    set setupVals(WRSLicense) ""
    set setupVals(lmFeatureName) ""
    set setupVals(lmErrString) ""
    set setupVals(lmRcStr) ""
    set setupVals(lmChoice) ""
    set setupVals(lmInstType) ""
    set cancelDBQUERY 0

    # initialize textmode variable
    set setupVals(cmdMode) ""

    # initialize license management values
    #
    # CGI program
    set lmVals(cgiHost) "web1.windriver.com"
    set lmVals(cgiHostPort) "80"
    set lmVals(licGetAllCgi) \
            "$lmVals(cgiHost)/cgi-bin/licProp/licGetAll2.cgi"
    set lmVals(licFileConfigCgi) \
            "$lmVals(cgiHost)/cgi-bin/licProp/licFileConfig.cgi"
    set lmVals(ackCommitCgi) \
            "$lmVals(cgiHost)/cgi-bin/licProp/ackCommit.cgi"
    set lmVals(authorizePINCgi) \
            "$lmVals(cgiHost)/cgi-bin/licProp/authorizePIN.cgi"

    # other lmVals
    set lmVals(lmLicenseFile) ""
    set lmVals(lmHostName) $setupVals(hostName)
    set lmVals(lmHostId) $setupVals(hostId)
    set lmVals(lmPort) 0
    set lmVals(lmLicMode) ""
    set lmVals(lmPinRequired) 0
    set lmVals(pinNum) ""
    set lmVals(reload) 0
    set lmVals(reloadExistingLicense) 0
    set lmVals(defaultServPort) 27000
    set lmVals(lastServPort) 27009
    set lmVals(successfulDbQuery) 0

    set lmTotalRecs {}
    set lmHostRecsLen 0
    set lmHostRecs {} 
    set lmHostFeaturesNum {}
    set lmVals(httpToken) ""
    set lmPurchasedProds {}
    set lmPackages {}

    # new lmVals for ALI 2.0
    set lmVals(WRSLicense) 0
    set lmVals(projName) ""
    set lmVals(lmFLFeaturesAllocated) {}
    set lmVals(lmNLFeaturesAllocated) {}
    set lmVals(lmFLFeaturesAvailable) {}
    set lmVals(lmNLFeaturesAvailable) {}
    set lmVals(lmFLFeaturesRequested) {}
    set lmVals(lmNLFeaturesRequested) {}


    #######################################################################
    # lmVals structure for license management
    #
    # lmHosts: list of host names for all hosts
    #    ex: {{warta} {delphi} {meuse}}
    #
    # lmHostIds: list of host IDs for all hosts
    #    ex: {{80b0cf2a} {80b1be21} {8093c64e}}
    #
    # lmHostPorts: list of ports for all hosts
    #    ex: {{27000} {27001} {27002}}
    #
    # lmAvailHosts: list of available hosts returned from the database to
    #               be used for LM configuration as End-User
    #    ex: {delphi holston yswyth}
    #
    # lmHostOrder: list of hosts in the order that user selects for 
    #              LM configuration as End-User
    #    ex: {holston yswyth delphi}
    #
    # lmHostSelected: list of hosts selected by user for LM End-User
    #    ex: {holston yswyth}
    #
    # lmLicensedProductNames: list of all licensed products' names for all hosts
    #    ex: {tornado windview codetest}
    #
    # lmLicensedProductCodes: list of all licensed products' ID for all hosts
    #    ex: {10 20 30}
    #
    # lmFeaturesTotal: total number of licenses for each feature
    #    ex: {{tornado 200} {windview 150} {codetest 100}}
    #
    # lmFeaturesAllocated: total number of licenses allocated at ALL hosts
    #                      for EACH feature
    #    ex: {{tornado 150} {windview 100} {codetest 80}}
    #
    # lmFeaturesAvailable: number of licenses available for each feature
    #    ex: {{tornado 50} {windview 50} {codetest 20}}
    #
    # lmFeaturesRequested: number of licenses requested by users for this host
    #    ex: only tornado and windview are available for this host and user 
    #        requests 10 tornado and 5 windview => {10 5}
    #
    # lmHostManual: server name entered on the manual license configuration
    #               dialog
    #    ex: servername
    # lmHostPortManual: port number entered on the manual license configuration
    #                   dialog
    #    ex: 27000

    # initialize lists of lists for license mangement

    set lmVals(lmHostPorts) {}
    set lmVals(lmHostIds) {}
    set lmVals(lmHosts) {}
    set lmVals(lmAvailHosts) {}
    set lmVals(lmHostOrder) {}
    set lmVals(lmHostSelected) {}
    set lmVals(lmLicensedProductNames) ""
    set lmVals(lmLicensedProductCodes) ""
    set lmVals(lmFeaturesAvailable) ""
    set lmVals(lmFeaturesAllocated) ""
    set lmVals(lmFeaturesRequested) ""
    set lmVals(lmFeaturesTotal) ""
    set lmVals(lmHostManual) ""
    set lmVals(lmPortManual) ""   

    # set patch variables 
    set patchPath ""
    set skipInstalloverCheck 0
 
    # Cannot use cdFileNameGet here because cdFileNameGet() uses
    # ctrlVals(version) which is not set now until later in this proc;
    # so we stick with cdromRootDirGet ()

    cdromZipDirSet [file join [cdromRootDirGet] WIND]

    if { [info exists env(SETUP_ANS_FILE)] } {
        puts "Use Setup Answer file"
        
        set ctrlVals(useInputScript) 1
                
        if { [info exists env(SETUP_LOG_FILE)] } {
            set autoSetupLogFile $env(SETUP_LOG_FILE)
        } else {
            set autoSetupLogFile "c:\\autoSetup.log"
        }
        
        puts "log file is $autoSetupLogFile"
                
        if { ![file exists $env(SETUP_ANS_FILE)] } {
            puts "Input script $env(SETUP_ANS_FILE) not exists!"
            autoSetupLog "Input script $env(SETUP_ANS_FILE) not exists!\n"
            return -1
        }
        if [catch {source $env(SETUP_ANS_FILE)} e] {
            puts "Error in sourcing $env(SETUP_ANS_FILE) $e"
            append logMsg "Error in sourcing $env(SETUP_ANS_FILE)\n"
            return -1
        }
    }
        
    openSetupDebugLog

    set ctrlVals(torRegAction) ""

    set ctrlVals(bbrdList) ""
    set ctrlVals(bbrdW) 400
    set ctrlVals(bbrdH) 300
    set ctrlVals(numBbrd) 1
    set ctrlVals(volatileFrm) ""
    set ctrlVals(meterWg) ""
    set ctrlVals(meterTagWg) ""
    set ctrlVals(mainWindow) "wizardDialog"
    set ctrlVals(backgroundWindow) "backgroundWindow"
    set ctrlVals(parentDialog) ""

    # define initial screen size. On windows, value is based on 1024x768 
    # screen resolution
    if {[isUnix]} {
        set ctrlVals(screenW) 730
        set ctrlVals(screenH) 530
    } else {
        set ctrlVals(screenW) 850
        set ctrlVals(screenH) 520
    }

    if {![isUnix]} {
        if ![catch {setupSysDirGet} dir] {
            sysDirSet $dir
        } else {
            puts "\tCannot determine system directory: $dir"
        }
    }

    # Detect if the user has admin privileges
    set ctrlVals(admin) [setupRunningAsAdmin]

    # set this value here, need ctrlVals(version) to be set first

    set ctrlVals(dlgImage) [cdFileNameGet \
                [file join RESOURCE BITMAPS DIALOG.BMP]]

    # Get a list of existing groups in the program manager

    set ctrlVals(folders) ""
    if [catch {setupExistingFoldersGet 1} userFolder] {
         dbgputs "Cannot get user folder: $userFolder"
         set userFolder ""
    }
    if [catch {setupExistingFoldersGet 0} commonFolder] {
         dbgputs "Cannot get common folder: $commonFolder"
         set commonFolder ""
    }

    set folderList [lsort [split "$commonFolder$userFolder" "\n\r"]]
    foreach folder $folderList {
        if {"$folder" != ""} {
            lappend ctrlVals(folders) $folder
        }
    }
    
    # check for Setup display options
    if {[info exists env(SETUP_LIMITCOLORS)]} {
        if {$env(SETUP_LIMITCOLORS) == 1} {
            set env(SETUP_REMOVEBACKGROUND) 1
        }
    }

    return 1
}

###########################################################################
#
# INSTW32.TCL - Initialization code
#
# This code is executed when the file is sourced. It does all the
# necessary initialization to start the Setup program.
#

if {[info exists env(INST_MODE)]} {
    if {$env(INST_MODE) != "text"} {
        applicationTitleSet "Setup"
    }
}

# initialize global variables
if {[globalInit] != "1"} {
    return 0
}

# CONFIG.TCL sourced before calling to get product name and version
set file [cdFileNameGet [file join RESOURCE TCL CONFIG.TCL]]
source $file

# Added backward compatibility support for patches created by pre-veloce SETUP
# Initialize all variables defined in veloce CONFIG.TCL here if not defined

foreach var {STAND_ALONE WRS_STAND_ALONE TORNADO_PRODUCT} {
    if ![info exist $var] {
        global $var
        set value 0
        if ![string compare $var "WRS_STAND_ALONE"] {
            # default to WRS_STAND_ALONE product since this is
            # not a tornado product but still Wind River product
            set value 1
        }
        set $var $value
        dbgputs "Defined $var=$value"
    }
}

if ![info exist prodInfo] {
    # for pre-veloce patches, default prod name to cdRom-description 
    # and empty for product version (since we won't know the version
    # or the version number may be a part of cdRom-description
    setProdInfo name [cdromDescGet]
    setProdInfo version ""
    dbgputs "Defined prod name=[getProdInfo name]"
    dbgputs "Defined prod version=[getProdInfo version]"
}

# INSTALL.TCL and MESSAGES.TCL must be sourced before parsing the
# command line to make the strTableGet procedure available.

set file [cdFileNameGet [file join RESOURCE TCL INSTALL.TCL]]
source $file
set file [cdFileNameGet [file join RESOURCE TCL MESSAGES.TCL]]
source $file
# parse command line to see whether we are running in
# INSTALL, LICENSE, or ICONINSTALL mode

dbgputs "argv is $argv"

if {[parseCmdLine [lrange $argv 1 [expr [llength $argv] - 1]]]} {
    return 0
}

set WIND_HOST_TYPE [windHostTypeGet]

if {$WIND_HOST_TYPE == "x86-win32"} {
    dllLoad  [cdFileNameGet [file join X86 WIN32 UITCLCONTROLS.DLL]] \
              _UITclControls_Init
} elseif { $WIND_HOST_TYPE == "sun4-solaris2" ||
           $WIND_HOST_TYPE == "x86-linux2" } {
    dllLoad  [tmpDirGet]/libuitclcontrols.so _UITclControls_Init
} elseif {$WIND_HOST_TYPE == "parisc-hpux10"} {
    dllLoad  [tmpDirGet]/libuitclcontrols.sl _UITclControls_Init
}



# source TCL files
# command line to make the strTableGet procedure available.
set file [cdFileNameGet [file join RESOURCE TCL HTTP.TCL]]
source $file
set file [cdFileNameGet [file join RESOURCE TCL UTILW32.TCL]]
source $file
set file [cdFileNameGet [file join RESOURCE TCL INF.TCL]]
source $file

# Tornado version, default group are initialized here coz the are defined
# in CONFIG.TCL. They cannot be set until CONFIG.TCL is sourced
set setupVals(torRegServName) "[getProdInfo name] Registry"
set setupVals(torVersionNum) [getProdInfo version]
#set setupVals(defGroup) "[cdromDescGet]"
set setupVals(defGroup) "[getProdInfo name] [getProdInfo version]"
set setupVals(prodRegEntry) "[getProdInfo name] [getProdInfo version]"
set setupVals(defDestDirWin32) "C:\\[getProdInfo name][getProdInfo version]"
set setupVals(defDestDirUnix) "/usr/[getProdInfo name][getProdInfo version]"
set lmVals(lmServName) "[getProdInfo name] License Manager"

set setupVals(CDnumber) [cdNameGet number]
set setupVals(CDdescription) [cdNameGet description]
set setupVals(setupHelp) [cdFileNameGet \
        [file join RESOURCE HELP SETUP.HLP]]

# source all wizard page files

set allWizardPages "\
WELCOME README LICAGREE PRVLEGE REGISTER CHOICE DESTDIR COMPSLCT \
FOLDER PERMISSN FILECOPY LIBUPDTE REGISTRY APPCONFG SYSCONFG SUMMARY \
FINISH ICONFIN SMTP LICMANUAL LICEMAIL EMFINISH LICPHONE LMUTIL LMINST \
FLEXCOPY LICINFO LMSTARTUP LMFINISH DBQUERY LMINFO GETPIN LICPORT LICCFG \
LMAUMAN LMOPTION LMEXIT LMCONFIG LMREGIST LMERROR LMCHOICE REGHOST \
COMPTBLE REGDLL"

foreach wizardPage $allWizardPages {
    source [cdFileNameGet [file join RESOURCE TCL $wizardPage.TCL]]
}

### define setup pages ###
global setupPageList

# determine common pages
if {$setupVals(lmError) != ""} {

    # Setup has been invoked by a license management failure
    # Based on the error code invoke the correct pages

    switch $setupVals(lmError) {
        \-U -
        /U {
            # license file is corrupted

            set setupPageList(commonPages) {lmError privilege registration \
                lmAutoManChoice}
            set licOpt 1
        }

        \-M -
        /M {
            # no licenses are available (they're all in use)

            set setupPageList(commonPages) {lmError}
        }

        \-C -
        /C {
            # no license server is detected

            set setupPageList(commonPages) {lmError privilege registration \
                lmAutoManChoice}
            set licOpt 1
        }

        \-E -
        /E {
            # license has expired or date in license file is bad

            set setupPageList(commonPages) {lmError}
        }
    }
} elseif {[instTypeGet] == "flexInst"} {

        # user has invoked Setup with /F or -F to copy flexLM files
        set setupPageList(commonPages) {lmUtilInst lmFilesCopy lmFinish}

} elseif {[instTypeGet] == "licenseSetup"} {

    set env(SETUP_REMOVEBACKGROUND) 1

        # user has invoked Setup with /L or -L to configure license management
    set setupPageList(commonPages) \
                        {welcome privilege registration destDir lmAutoManChoice}

} elseif {[instTypeGet] == "registryInst"} {

        set env(SETUP_REMOVEBACKGROUND) 1

        # user has invoked Setup with /R or -R to configure Registry startup
        set setupPageList(commonPages) {privilege torRegistry}

} elseif {[instTypeGet] == "fileAssociation"} {

    set env(SETUP_REMOVEBACKGROUND) 1

    # user has invoked to register file associations

    if {[isUnix]} { return 0 }

    if { [info exists env(WIND_BASE)] } {
        destDirSet $env(WIND_BASE)
    } else {
        messageBox "WIND_BASE value is not set!\nPlease set\
                    WIND_BASE before configuring file associations."
        return 0
    }

    set setupPageList(commonPages) {appConfig}

} else {

    if { [info exists env(SETUP_LICMGNT)] && $env(SETUP_LICMGNT) == 1} {
        # if launches from Tornado GUI

        set setupPageList(commonPages) {welcome privilege registration \
                lmAutoManChoice}
        set licOpt 1
    } else {
        set setupPageList(commonPages) {welcome readme licAgreement privilege \
                registration installChoice}
        set licOpt 0
    }
}

# Full Installation pages for windows
set setupPageList(winFullInstPages) {destDir compSelect \
    folderSelect torRegistry remoteRegistryHost compatibility howTo \
    appConfig filesCopy libUpdate regTornado systemConfig summary lmAutoManChoice}

# Full Installation pages for UNIX
set setupPageList(unixFullInstPages) {destDir compSelect \
    permission remoteRegistryHost compatibility \
    howTo filesCopy libUpdate systemConfig summary lmAutoManChoice}

# Program Group pages
set setupPageList(winPrgGrpPages) {destDir folderSelect torRegistry \
    remoteRegistryHost appConfig iconFinish}

# Email pages
set setupPageList(email) {licManual licEmail licEmailFinish}

# Phone pages
set setupPageList(phone) {licManual licPhone}

# Auto License Install pages
set setupPageList(autoInst) {dbQuery userAuthorization licServerPort \
                licConfig lmStartupOptions lmFinish}

# Page list for floating license installation
set setupPageList(floatLicInst) {lmUtilInst lmFilesCopy \
        currLicInfo lmInstOptions}

# Page list for ELM license configuration
set setupPageList(ELM) {lmConfig lmRegister finish}

# Page list for Automatic End user license configuration
set setupPageList(endUser) {lmConfig lmRegister finish}

# Page list for Manual end user license configuration
set setupPageList(endUserManual) {lmRegister finish}
set setupPageList(endUserManualUnix) {finish}

# Page list for Node Locked license installation
set setupPageList(nodeLock) {currLicInfo userAuthorization licConfig finish}

# Page list for DBQUERY
set setupPageList(dbQuery) {dbQuery lmInfo}

# Page list for LM Options
set setupPageList(lmOptions) {lmOptions}

# Page list for LM Installation Options
set setupPageList(lmInstOptions) {currLicInfo lmInstOptions}

# Page list for License Server Exit
set setupPageList(lmExit) {lmExit}

# define all the page lists
set pList "commonPages email phone autoInst floatLicInst endUser nodeLock \
           dbQuery lmInstOptions lmExit"

if {$setupVals(lmError) != ""} {
    set setupPageList(searchableList) $pList
} elseif {[isUnix]} {
    set setupPageList(searchableList) \
            [concat $pList unixFullInstPages]
} else {
    set setupPageList(searchableList) \
            [concat $pList winFullInstPages winPrgGrpPages]
}

set setupPageList(currPageGrp) commonPages
set setupPageList(pageGroupList) commonPages
#dbgputs "page group list: $setupPageList(searchableList)"

### end definition ###

if { $ctrlVals(useInputScript) } {
    autoSetupLog "\n\n********** TEST AUTOMATION **********"
}

if ![constructPages [instTypeGet]] {
    return 0
}

# check for required patches

if { ![isStandAlone] } {
    # check for required patches for the product

    if {![patchCheck]} {  return 0  }
}

# if LM error, remove background for SETUP
if {$setupVals(lmError) != ""} {
    set env(SETUP_REMOVEBACKGROUND) 1
}

applicationStart
