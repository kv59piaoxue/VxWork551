/* cdromFsLib.c - ISO 9660 CD-ROM read-only file system library */

/* Copyright 1989-2002 Wind River Systems, Inc. */

#include "copyright_wrs.h"

/*
modification history
--------------------
07o,05dec02,tkj  cdromFs joliet code review changes.
07n,30oct02,tkj  1. Fix failure of cdcompat on multi-extent files.
		 2. Move cdromFsVersion.h to target/h/private.
		 3. Make multi-session support conditional.
07m,15oct02,tkj  First release candiidate of the Joliet project.
		 1. Finish removing translation from Joliet to ASCII.
		 2. Fix endian bug in reading TOC from CD.
		 3. Make MODE_AUTO combination of directories conditional upon
		    CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS.
		 4. Make ioctl() to get multi-session TOC conditional upon
		    CDROMFS_MULTI_SESSION_ATAPI_IOCTL
		 5. Revise refgen output.  Convert refgen to new mark-up style.
		 6. Change name of cdromFs ioct() defines
07l,10oct02,tkj  1. Code cleanup: Remove debugging code, Improve refgen output.
		 2. cdromFsLib.h split into cdromFsLib.h and cdromFsLibP.h.
07k,03oct02,tkj  1. Remove translation from Unicode to ASCII.
		 2. Fix SPR#79162 - It had a bug that showed up in llr()
		    before.
		 3. Fix SPR#80396 - It was not fixed before.
07j,01oct02,tkj  Fix SPR#78416 Handles .. wrong.  Accepts path xx/../yy even
                 if xx does not exist.
07i,17sep02,tkj  1. Add enhancement SPR#78709 Get volume descriptor.
		 2. Modify enhancement SPR#78687 Get version number.
07h,28aug02,tkj  Fix compilation problem with DEBUG off.
07g,28aug02,tkj  Changes since last ClearCase checkin 07c:
		 Finished since 07b: 
		 Current status of Productize Joliet extensions project.

		 Enhancements done in 07g (now): SPR#79162.

		 Enhancements not done yet: SPR#78208, SPR#78687, SPR#78709.

		 Bugs fixed in 07g (now): SPR#34659/SPR#34826, SPR#75766,
		 SPR#80396, SPR#80424.

		 Bugs fixed in 07b: SPR#32715, SPR#70072, SPR#78415,
		 SPR#78452, SPR#78454, SPR#78455, SPR#78456.

		 Bugs not fixed yet: SPR#78416.
07f,21aug02,smz  Solved bug regarding the recursive listing of a Joliet
                 directory which is more then 3 blocks long.
		 Not checked into ClearCase.
07e,19aug02,tkj  More work on SPR#78208 - Productice Joliet extensions.
		 Not checked into ClearCase.
07d,12aug02,smz  Added cdromFsTocRead function for simulated reading of table
                 of contents when the ioctl call to the block device driver
                 fails.  Not checked into ClearCase.
07c,27jun02,tkj  More work on SPR#78208 - Productice Joliet extensions.
07b,26jun02,tkj  Enchancememts: SPR#78208 - Productice Joliet extensions.
		 Bug fixes: SPR#32715/SPR#34826, SPR#78415, SPR#78452,
		 SPR#78454, SPR#78455, SPR#78456, SPR#79162.
		 Bugs not fixed yet: SPR#34659, SPR#75766, SPR#78416,
		 SPR#79162.
07a,26jun02,tkj  Checkin cdromFsLib Joliet extensions as received from Wind
                 River Services in the Netherlands.  It needs work to be
                 productized.
06c,19Mrz02,mbl  added multisession for Joliet
06b,07Mrz02,mbl  remove all warnings and tested all Joliet functionalitys.
06a,26Feb02,mbl	 added new functionality to support Joliet extensions.
05a,03jun99,pfl  fixed directory and file month entries (SPR# 26756)
04r,15nov98,jdi  added instructions on modifying BSP to include cdromFS.
04e,14jul98,cn   added prototype for cdromFsWrite().
04d,10jul98,cn   updated documentation, changed cdromFS to cdromFsLib
		 (SPR# 21732). Also removed every reference to Rock
		 Ridge extensions support (SPR# 21590). Moved cdromFsInit()
		 to the beginning of the file.
04c,08apr98,kbw  made minor man page edits
04b,30apr97,jdi  doc: cleanup.
04a,10apr97,dds  SPR#7538: add CDROM file system support to vxWorks.
03f,17jul96,rst  productized for release.
03e,25jun96,vld	 file was compiled with "Tornado". All warnings were
		 fixed up.
03c,25jun96,vld  new functionality: uppercase names may be reached via
		 case insensitive path string.
03b,23jun96,leo  the bug in cdromFsFixPos() was fixed up (type of second
		 argument was changed to long).
03a,23jun96,leo  the bug in cdromFsFindFileInDir() was fixed up
		 (the bug came from ASCI order, wwhere ';' > '.').
02a,23jan96,vld	 the new interpretation of ISO_DIR_REC_EAR_LEN
		 and ISO_PT_REC_EAR_LEN: it is assumed now that
		 the length of EAR is counted in logical blocks.
		 Data always starts from LB bound.
01e,23jan96,vld  the bug in cdromFsFixPos was fixed up
01d,12oct95,rst	 FCS release, ported to 5.2
01c,03jul95,rst	 Beta release, code revew.
01b,10apr95,rst	 alex, vlad total revision of the joined text
01a,22feb95,rst	 initial version
*/

/*
DESCRIPTION
This library defines cdromFsLib, a utility that lets you use standard POSIX
I/O calls to read data from a CD-ROM, CD-R, or CD-RW formatted according to
the ISO 9660 standard file system.

It provides access to CD file systems using any standard
BLOCK_DEV structure (that is, a disk-type driver).

The basic initialization sequence is similar to installing a DOS file system
on a SCSI device.

1. Initialize the cdrom file system library
(preferably in sysScsiConfig() in sysScsi.c):
\cs
    cdromFsInit ();
\ce

2. Locate and create a SCSI physical device:
\cs
    pPhysDev=scsiPhysDevCreate (pSysScsiCtrl,0,0,0,NONE,1,0,0);
\ce

3. Create a SCSI block device on the physical device:
\cs
    pBlkDev = (SCSI_BLK_DEV *) scsiBlkDevCreate (pPhysDev, 0, 0);
\ce

4. Create a CD file system on the block device:
\cs
    cdVolDesc = cdromFsDevCreate ("cdrom:", (BLK_DEV *) pBlkDev);
\ce

Call cdromFsDevCreate() once for each CD drive attached to your target.
After the successful completion of cdromFsDevCreate(), the CD
file system will be available like any DOS file system, and
you can access data on the named CD device using open(), close(), read(),
ioctl(), readdir(), and stat().	 A write() always returns an error.

The cdromFsLib utility supports multiple drives, concurrent access from
multiple tasks, and multiple open files.

ISO 9660 FILE AND DIRECTORY NAMING
The strict ISO 9660 specification allows only uppercase file names
consisting of 8 characters plus a 3 character suffix.

To accommodate users familiar with MS-DOS, cdromFsLib lets you use lowercase
name arguments to access files with names consisting entirely of uppercase
characters.  Mixed-case file and directory names are accessible only if you
specify their exact case-correct names.

JOLIET EXTENSIONS FILE AND DIRECTORY NAMING

The Joliet extensions to the ISO 9660 specification are designed to handle
long file names up to 340 characters long.

File names must be case correct.  The above use of lowercase characters to
access files named entirely with uppercase characters is not supported.

cdromFs with Joliet extensions does not support Unicode file names.  The
file names on the CD are stored in 16 bit Unicode characters.
However, they are converted to 8 bit characters inside cdromFs by dropping
the most significant byte of each 16 bit character.

FILE AND DIRECTORY NAMING COMMON TO ISO 9660 AND THE JOLIET EXTENSIONS
To support multiple
versions of the same file, the ISO 9660 specification also supports version
numbers.  When specifying a file name in an open() call, you can select the
file version by appending the file name with a semicolon (;) followed by a
decimal number indicating the file version.  If you omit the version number,
cdromFsLib opens the latest version of the file.

For the time being, cdromFsLib further accommodates MS-DOS users by
allowing "\/" (backslash) instead of "/" in pathnames.	However, the use
of the backslash is discouraged because it may not be supported in
future versions of cdromFsLib.

Finally, cdromFsLib uses an 8-bit clean implementation of ISO 9660.  Thus,
cdromFsLib is compatible with CDs using either Latin or Asian characters
in the file names.

IOCTL CODES SUPPORTED
\is
\i `FIOGETNAME'
Returns the file name for a specific file descriptor.

\i `FIOLABELGET'
Retrieves the volume label.  This code can be used to verify that a
particular volume has been inserted into the drive.

\i `FIOWHERE'
Determines the current file position.

\i `FIOWHERE64'
Determines the current file position.  This is the 64 bit version.

\i `FIOSEEK'
Changes the current file position.

\i `FIOSEEK64'
Changes the current file position.  This is the 64 bit version.

\i `FIONREAD'
Tells you the number of bytes between the current location and the end of
this file.

\i `FIONREAD64'
Tells you the number of bytes between the current location and the end of
this file.  This is the 64 bit version.

\i `FIOREADDIR'
Reads the next directory entry.

\i `FIODISKCHANGE'
Announces that a disk has been replaced (in case the block driver is
not able to provide this indication).

\i `FIOUNMOUNT'
Announces that the a disk has been removed (all currently open file
descriptors are invalidated).

\i `FIOFSTATGET'
Gets the file status information (directory entry data).

\i `CDROMFS_DIR_MODE_SET'
This is part of the Joliet extensions. It sets the directory mode to the
ioctl() arg value.  That controls whether a file is opened with or without
the Joliet extensions.	Settings MODE_ISO9660, MODE_JOLIET, and MODE_AUTO
do not use Joliet, use Joliet, or try opening the directory first without
Joliet and then with Joliet, respectively.

This ioctl() unmounts the file system.	Thus any open file descriptors are
marked obsolete.

\i `CDROMFS_DIR_MODE_GET'
This is part of the Joliet extensions. It gets and returns the directory
mode set by CDROMFS_DIR_MODE_SET.

\i `CDROMFS_STRIP_SEMICOLON'
This sets the readdir() strip semicolon setting to FALSE if arg is 0, and
TRUE otherwise.  If TRUE, readdir() removes the semicolon and following
version number from the directory entries returned.

\i `CDROMFS_GET_VOL_DESC'
This returns the primary or supplementary volume descriptor by which the
volume is mouned in arg.  arg must be type T_ISO_PVD_SVD_ID as defined in
cdromFsLib.h.  The result is the volume descriptor adjusted for the
endianness of the processor, not the raw volume descriptor from the CD.
The result is directly usable by the processor.  The result also includes
some information not in the volume descriptor, for example which volume
descriptor is in-use.
\ie

INTERNAL
Add the following to the \is list above, without the conditional or the
list start/stop, if the macro CDROMFS_MULTI_SESSION_SUPPORT is defined in
cdromFsLibP.h.  Note, the issues explained in the comment in cdromFsLibP.h
must be resolved.

\is
\i `CDROMFS_SESSION_NUMBER_SET'
This is part of multi-session support.	CD-Rs and CD-RWs can be written in
multiple sessions, or all at once.  If multiple sessions are used, each
session updates the previous session.  Only the changes from the previous
session are stored.  Files that are not changed are reused, not stored
again.	The last session on the disk gives the current state of the disk.
The earlier sessions are normally not accessed.	 If accessed they give
earlier states of the disk.

This ioctl() function sets which session is accessed.  Normally the last
session is accessed, and this ioctl() is not used.  Sessions are numbered
starting with 1.  Session value 100, i.e. DEFAULT_SESSION, means the last
session on the CD.

Multi-session support prefers that the physical disk driver support the
ioctl() function FIOREADTOCINFO 0xf8 to read the CD volume table of
contents.  If the disk driver does not support FIOCREADTOCINFO, cdromFs
determines the CD volume table of contents itself.  However, this is both
slower than asking the driver, and does not work for every combination of
CD drive and CD.

This ioctl() unmounts the file system.	Thus any open file descriptors are
marked obsolete.

\i `CDROMFS_SESSION_NUMBER_GET'
This is part of multi-session support. It gets and returns the session
number set by CDROMFS_SESSION_NUMBER_SET.

\i `CDROMFS_MAX_SESSION_NUMBER_GET'
This is part of multi-session support. It gets and returns the maximum
session on the CD.
\ie

MODIFYING A BSP TO USE CDROMFS IN VXWORKS AE
\ml
\m 1.
Add the component "INCLUDE_CDROMFS" to your kernel domain project.  This
will bring in the CDROMFS library modules and initialize them.

\m 2.
Continue with step 3 underneath "Modify the definition of sysScsiInit() to
include the following:" in section MODIFYING A BSP TO USE CDROMFS IN
VXWORKS.
\me

MODIFYING A BSP TO USE CDROMFS IN VXWORKS
The following example describes mounting cdromFS on a SCSI device.

Edit your BSP's config.h to make the following changes:
\ml
\m 1.
Insert the following macro definition:
\cs
    #define INCLUDE_CDROMFS
\ce

\m 2.
Change FALSE to TRUE in the section under the following comment:
\cs
    /@ change FALSE to TRUE for SCSI interface @/
\ce
\me

Make the following changes in sysScsi.c
(or sysLib.c if your BSP has no sysScsi.c):
\ml
\m 1.
Add the following declaration to the top of the file:
\cs
    #ifdef INCLUDE_CDROMFS
    #include "cdromFsLib.h"
    STATUS cdromFsInit (void);
    #endif
\ce

\m 2.
Modify the definition of sysScsiInit() to include the following:
\cs
    #ifdef INCLUDE_CDROMFS
    cdromFsInit ();
    #endif
\ce

The call to cdromFsInit() initializes cdromFS.	This call must
be made only once and must complete successfully before you can
call any other cdromFsLib routines, such as cdromFsDevCreate().
Typically, you make the cdromFSInit() call at system startup.
Because cdromFS is used with SCSI CD devices, it is natural
to call cdromFSInit() from within sysScsiInit().

\m 3.
Modify the definition of sysScsiConfig() (if included in your BSP)
to include the following:
\cs
/@ configure a SCSI CDROM at busId 6, LUN = 0 @/

#ifdef INCLUDE_CDROMFS

if ((pSpd60 = scsiPhysDevCreate (pSysScsiCtrl, 6, 0, 0, NONE, 0, 0, 0)) ==
    (SCSI_PHYS_DEV *) NULL)
    {
    SCSI_DEBUG_MSG ("sysScsiConfig: scsiPhysDevCreate failed for CDROM.\n",
		    0, 0, 0, 0, 0, 0);
    return (ERROR);
    }
else if ((pSbdCd = scsiBlkDevCreate (pSpd60, 0, 0) ) == NULL)
    {
    SCSI_DEBUG_MSG ("sysScsiConfig: scsiBlkDevCreate failed for CDROM.\n",
		    0, 0, 0, 0, 0, 0);
    return (ERROR);
    }

/@
 * Create an instance of a CD device in the I/O system.
 * A block device must already have been created.  Internally,
 * cdromFsDevCreate() calls iosDrvInstall(), which enters the
 * appropriate driver routines in the I/O driver table.
 @/

if ((cdVolDesc = cdromFsDevCreate ("cdrom:", (BLK_DEV *) pSbdCd )) == NULL)
    {
    return (ERROR);
    }

#endif /@ end of #ifdef INCLUDE_CDROMFS @/
\ce

\m 4.
Before the definition of sysScsiConfig(), declare the following
global variables used in the above code fragment:
\cs
    SCSI_PHYS_DEV *pSpd60;
    BLK_DEV *pSbdCd;
    CDROM_VOL_DESC_ID cdVolDesc;
\ce
\me

The main goal of the above code fragment is to call cdromFsDevCreate().
As input, cdromFsDevCreate() expects a pointer to a block device.
In the example above, the scsiPhysDevCreate() and scsiBlkDevCreate()
calls set up a block device interface for a SCSI CD device.

After the successful completion of cdromFsDevCreate(), the device called
"cdrom" is accessible using the standard open(), close(), read(), ioctl(),
readdir(), and stat() calls.

INCLUDE FILES: cdromFsLib.h

CAVEATS
The cdromFsLib utility does not support CD sets containing multiple disks.

SEE ALSO: ioLib, ISO 9660 Specification, Joliet extension Specification
*/

/*
 * Note: Only the following routines have man output: cdromFsInit(),
 * cdromFsVolConfigShow(), cdromFsVersionDisplay(), cdromFsDevCreate(),
 * cdromFsVersionNumGet().
 */

/* includes */

#include <vxWorks.h>

#include <ctype.h>
#include <dirent.h>
#include <errnoLib.h>
#include <in.h>
#include <iosLib.h>
#include <memLib.h>
#include <memPartLib.h>		     /* KHEAP_ALLOC, KHEAP_FREE */
#include <netinet/in.h>		     /* htonl, ntohl */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sysLib.h>
#include <usrLib.h>

#include <private/cdromFsVersionP.h> /* CDROMFS_VERSION SPR#78687 */
#include <cdromFsLib.h>
#include <private/cdromFsLibP.h>     /* Must be after cdromFsLib.h */

/* For common source with VxWorks AE */

#ifdef	_WRS_VXWORKS_5_X	/* Built for Veloce T2.2 */
#undef	VXWORKS_AE		/* Not built for VxWorks AE */

#elif	!defined(KHEAP_ALLOC)	/* Built for T2 VxWorks 5.4 */
#undef	VXWORKS_AE		/* Not built for VxWorks AE */
#define KHEAP_ALLOC	malloc
#define KHEAP_FREE	free

#else  /* VxWorks AE */
#define VXWORKS_AE		/* Built for VxWorks AE */

#include <objLib.h>		/* objOwnerSet() */
#include <pdLlib.h>		/* pdIdKernelGet() */
#endif /* VxWorks AE */

/* defines */

#define SIZE64

/* DEBUG */

#ifdef	DEBUG
#undef	NDEBUG			/* assert() is active */
#define ERR_SET_SELF		/* Display errnoSet() calls */

#undef	LOCAL
#define LOCAL

    int		cdromFsDbg	= 0;
    u_char	dbgvBuf[2048];

#define DBG_MSG(level)\
	if ((level)<=cdromFsDbg) printf

#define DBG_COP_TO_BUF(str, len)\
	{\
	bzero (dbgvBuf, sizeof(dbgvBuf));\
	bcopy ((str), dbgvBuf, (len));\
	}

extern void d (FAST void *adrs, int nunits, int width);

#else  /* DEBUG */
#define NDEBUG			   /* assert() is inactive */
#undef  ERR_SET_SELF		   /* Do not display errnoSet calls */

#define DBG_MSG(level)		     if (0) printf
#define DBG_COP_TO_BUF(str, len)	(str,len)

#endif	/* DEBUG */

#include <assert.h>		   /* This must follow the ifdef DEBUG */

/* sybsystem version fields SPR#78687 */

#define SUBSYSTEM_VERSION_MAJOR(VERSION)	LMSB(VERSION)
#define SUBSYSTEM_VERSION_MINOR(VERSION)	LNMSB(VERSION)
#define SUBSYSTEM_VERSION_PATCH(VERSION)	LNLSB(VERSION)
#define SUBSYSTEM_VERSION_BUILD(VERSION)	LLSB(VERSION)

/* paramaters (Can be changed) */

#define CDROM_LIB_MAX_PT_SIZE (4*64 KB) /* maximum path table size supported */

/* constants (Cannot be changed or no need to change) */

#define SLASH		'/'
#define BACK_SLASH	'\\'
#define POINT		'.'
#define SEMICOL		';'

/* SEC_BUF struct constant */

#define CDROM_COM_BUF_SIZE	  3	/* sectors to read via single access */

/*
 * All character variables in the module are defined as u_char (*).
 * Following macros are defined to prevent compilation warnings
 */

#define bzero(a,b)	bzero ((char *)(a), (b))
#define bcopy(a,b,c)	bcopy ((char *)(a), (char *)(b), (c))
#define strncpy(a,b,c)	strncpy ((char *)(a), (char *)(b), (c))
#define strcpy(a,b)	strcpy ((char *)(a), (char *)(b))
#define strncmp(a,b,c)	strncmp ((char *)(a), (char *)(b), (c))
#define strcmp(a,b)	strcmp ((char *)(a), (char *)(b))
#define strchr(a,b)	strchr ((char *)(a), (b))
#define strspn(a,b)	strspn ((char *)(a), (char *)(b))

/*
 * Under development all errors are not set to <errno> directly, but
 * logged on the console with some comments
 */

#ifdef ERR_SET_SELF
#define errnoSet(a)	errnoSetOut (__LINE__, (u_char *)#a, (a))
#endif

/* Macros */

/* data fields in buffer may not be bounded correctly */

#define C_BUF_TO_SHORT(dest, source, start)\
	{\
	CDROM_SHORT buf;\
	bcopy ((u_char *)(source)+ (start), (u_char *)&buf, sizeof(buf));\
	(dest) = buf;\
	}

#define C_BUF_TO_LONG(dest, source, start)\
	{\
	CDROM_LONG buf;\
	bcopy ((u_char *)(source)+ (start), (u_char *)&buf, sizeof(buf));\
	(dest) = buf;\
	}

#define LAST_BITS(val,bitNum)	((~((u_long)(-1)<<(bitNum)))&((u_long)val))

					/* Rounded up number of as per b */
#define A_PER_B(a,b)		(((a)+(b)-1)/(a))

/* to get some fields from path table records */

#define PT_REC_SIZE(size, pPT)	((size) = ((u_char)(*(pPT)+(*(pPT)&1))+ISO_PT_REC_DI))

#define PT_PARENT_REC(prev, pPT)\
	C_BUF_TO_SHORT (prev, pPT, ISO_PT_REC_PARENT_DIR_N)

/* to assign secBuf as empty */

#define LET_SECT_BUF_EMPTY(pSecBuf)	((pSecBuf)->numSects = 0)

/* Logical expressions */

#define	IF_A_THEN_B(A,B)	(~((A) && ~(B)))

/* typedefs */

#ifdef SIZE64
typedef long long	fsize_t;
#else
typedef size_t		fsize_t;
#endif /* SIZE64 */

typedef u_short CDROM_SHORT;	/* 2-bytes fields */
typedef u_long	CDROM_LONG;	/* 4-bytes fields */

/* globals */

STATUS cdromFsInit (void);

/* cdrom file system number in driver table */

int	cdromFsDrvNum = ERROR;

/* locals */

#ifdef	DEBUG
/*
 *  Pointers to structs for symbolic debugging use
 *
 * If you need to display a struct, set one of these pointers and then
 * print it.
 */

T_ISO_VD_HEAD *	     pCdromFsDbgTIsoVdHead; /* VD header */

T_ISO_VD_DATE_TIME * pCdromFsDbgTIsoVdDateTime; /* VolDesc date/time */

T_ISO_PVD_SVD *	     pCdromFsDbgTIsoPvdSvd; /* Prim/Sup Volume Descriptor */

SEC_BUF *	     pCdromFsDbgSecBuf; /* Sector buf (Disk cache) */

CDROM_VOL_DESC *     pCdromFsDbgVolDesc; /* Mounted CD volume */

T_CDROMFS_VD_LST *   pCdromFsDbgTCdromfsVdLst; /* VolDesc of mounted volume */

T_FILE_DATE_TIME *   pCdromFsDbgTFileDateTime; /* Directory date/time */

T_CDROM_FILE *	     pCdromFsCdromFile;	/* File descriptor */
#endif

/* forward declarations */

#ifdef ERR_SET_SELF
LOCAL VOID errnoSetOut(int line, const u_char * str, int err);
#endif

LOCAL T_CDROM_FILE_ID	cdromFsFDAlloc (CDROM_VOL_DESC_ID pVolDesc);
LOCAL void		cdromFsFDFree (T_CDROM_FILE_ID pFD);
LOCAL STATUS		cdromFsSectBufAlloc (CDROM_VOL_DESC_ID pVolDesc,
					     SEC_BUF_ID pSecBuf,
					     int numSectInBuf);
LOCAL STATUS		cdromFsSectBufAllocBySize (CDROM_VOL_DESC_ID pVolDesc,
						   SEC_BUF_ID pSecBuf,
						   int size);
LOCAL void		cdromFsSectBufFree (SEC_BUF_ID pSecBuf);
LOCAL u_char *		cdromFsGetLS (CDROM_VOL_DESC_ID pVolDesc, u_long LSNum,
				      u_long maxLBs, SEC_BUF_ID secBuf);
LOCAL u_char *		cdromFsGetLB (T_CDROMFS_VD_LST_ID pVDLst, u_long LBNum,
				      u_long maxLBs, SEC_BUF_ID secBuf);
LOCAL u_char *		cdromFsDIRGet (T_CDROM_FILE_ID	pFD);
LOCAL u_char *		cdromFsPTGet (T_CDROMFS_VD_LST_ID pVdLst,
				      SEC_BUF_ID pSecBuf);
LOCAL u_long		cdromFsNextPTRec (u_char ** ppPT, u_long offset,
					  u_long PTSize);
LOCAL u_char		cdromFsShiftCount (u_long source, u_long dest);
LOCAL STATUS		cdromFsVDAddToList (CDROM_VOL_DESC_ID pVolDesc,
					    const u_char * pVDData,
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
					    u_long SesiPseudoLBNum,
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
					    u_long VDPseudoLBNum,
					    u_short uniCodeLev,
					    u_char VDSizeToLSSizeShift);
LOCAL void		cdromFsVolUnmount (CDROM_VOL_DESC_ID pVolDesc);
LOCAL STATUS		cdromFsVolMount (CDROM_VOL_DESC_ID pVolDesc);
LOCAL time_t		cdromFsDirDateTime2Long (const T_FILE_DATE_TIME *
						 pDateTime);
LOCAL STATUS		cdromFsFillFDForDir (T_CDROMFS_VD_LST_ID pVDList,
					     T_CDROM_FILE_ID pFD,
					     u_char * pPTRec,
					     u_int dirRecNumInPT);
LOCAL STATUS		cdromFsFillFDForFile (T_CDROMFS_VD_LST_ID pVDList,
					      T_CDROM_FILE_ID pFD);
#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
LOCAL u_long		cdromFsFindDirEntered (const u_char * pPTRec,
					       u_short LBSize);
LOCAL u_long		cdromFsAddRecsToFD (u_char *	RecpPTRec,
					    u_int RecStartOff,
					    u_char * FdpPTRec,
					    u_int FdStartOff,
					    u_int numOfRecCopy,
					    u_int destSize);
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */
LOCAL int		cdromFsStrUpcaseCmp (const u_char * string1,
					     const u_char * string2);
LOCAL STATUS		cdromFsFindFileInDir (T_CDROMFS_VD_LST_ID pVDList,
					      T_CDROM_FILE_ID pFD,
					      const u_char * name,
					      u_char * pPTRec,
					      u_int dirRecNumInPT);
LOCAL int		cdromFsFilenameLength (const u_char * name);
LOCAL int		cdromFsFilenameCompare (const u_char * name,
						const u_char * string,
						u_int stringLen, BOOL upCase);
#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
LOCAL int		cdromFsDirEntryCompare (const u_char * name1,
						const u_char * name2,
						u_int name1Len,
						u_int name2Len,
						BOOL upCase);
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */
LOCAL int		cdromFsFindDirOnLevel (T_CDROMFS_VD_LST_ID pVDList,
					       const u_char * name,
					       u_char * pPT,
					       u_int parDirNum,
					       u_int * pPathLev,
					       u_char ** ppRecord);
#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
LOCAL STATUS		cdromFsDirEntriesOtherVDAdd (T_CDROMFS_VD_LST_ID
						     pVDList,
						     const u_char * path,
						     T_CDROM_FILE_ID pFD);
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */
LOCAL STATUS		cdromFsFindPathInDirHierar(T_CDROMFS_VD_LST_ID pVDList,
						   const u_char * path,
						   T_CDROM_FILE_ID pFD,
						   int options);
LOCAL T_CDROM_FILE_ID	cdromFsFindPath (CDROM_VOL_DESC_ID pVolDesc,
					 const u_char * path, int options);
LOCAL STATUS		cdromFsFillStat (T_CDROM_FILE_ID fd,struct stat * arg);
#if 0			/* NOT USED until record format files supported */
LOCAL STATUS		cdromFsCountMdu (T_CDROM_FILE_ID fd, int prevabsoff);
#endif /* NOT USED until record format files supported */
LOCAL STATUS		cdromFsFillPos (T_CDROM_FILE_ID fd,u_char *PrevDirPtr,
					short i, int len, int NewOffs);
LOCAL STATUS		cdromFsSkipDirRec (T_CDROM_FILE_ID fd, u_char flags);
LOCAL STATUS		cdromFsDirBound (T_CDROM_FILE_ID fd);
LOCAL void		cdromFsSkipGap (T_CDROM_FILE_ID fd , u_long * fsLb,
					long absPos);
LOCAL void		cdromFsFixFsect (T_CDROM_FILE_ID fd);
LOCAL STATUS		cdromFsVolLock (CDROM_VOL_DESC_ID pVolDesc,
					int errorValue,
					BOOL mountIfNotMounted);
LOCAL T_CDROM_FILE_ID	cdromFsOpen (CDROM_VOL_DESC_ID	pVolDesc,
				     const u_char * path, int options);
LOCAL STATUS		cdromFsClose (T_CDROM_FILE_ID pFD);
LOCAL STATUS		cdromFsReadOnlyError (void);
LOCAL STATUS		cdromFsLabelGet (T_CDROM_FILE_ID fd, char * pLabel);
LOCAL STATUS		cdromFsSeek (T_CDROM_FILE_ID fd, fsize_t posArg);
LOCAL STATUS		cdromFsDirSeek (T_CDROM_FILE_ID fd, DIR * pDir);
LOCAL u_char *		cdromFsUnicodeStrncpy (u_char * dstString,
					       size_t dstLen,
					       const u_char * srcString,
					       size_t srcLen);
LOCAL STATUS		cdromFsDirRead (T_CDROM_FILE_ID fd, DIR * pDir);
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
LOCAL STATUS		cdromFsTocRead (CDROM_VOL_DESC_ID pVolDesc,
					CDROM_TRACK_RECORD * pCdStatus);
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
LOCAL STATUS		cdromFsIoctl (T_CDROM_FILE_ID fd, int function,
				      int arg);
LOCAL STATUS		cdromFsRead (int desc, u_char * buffer,
				     size_t maxBytes);
LOCAL STATUS		cdromFsReadyChange (CDROM_VOL_DESC_ID pVDList);
LOCAL STATUS		cdromFsVolDescGet (T_CDROMFS_VD_LST_ID pVDList,
					   T_ISO_PVD_SVD * pVolDescOut);
LOCAL CDROM_VOL_DESC_ID	cdromFsDevDelete (void * arg, STATUS retStat);
#ifdef	DEBUG
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
void			cdromFsTocPrint (CDROM_TRACK_RECORD * pCdStatus);
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
void			cdromFsDiskDirDateTimePrint (const T_FILE_DATE_TIME *
						     pDateTime);
const u_char *		cdromFsDiskDirPrint (const u_char * pDirRec,
					     T_CDROMFS_VD_LST_ID pVDList);
T_CDROM_FILE_ID		cdromFsFDPrint (T_CDROM_FILE_ID	pFD, BOOL printEAR,
					u_char * message, u_long line);
const u_char *		cdromFsDiskPTPrint (const u_char * pPTRec);
LOCAL time_t		cdromFsVDDateTime2Long (const T_ISO_VD_DATE_TIME *
						pDateTime);
void			cdromFsDiskVDDateTimePrint (const T_ISO_VD_DATE_TIME *
						    pDateTime);
void			cdromFsDiskEARPrint (const u_char * pEAR);
LOCAL STATUS		cdromFsSectBufAllocByLB (T_CDROMFS_VD_LST_ID pVDList,
						 SEC_BUF_ID pSecBuf,
						 int numLB);
int			cdDump (CDROM_VOL_DESC_ID pVolDesc, u_long LBRead);
#endif	/* DEBUG */

/***************************************************************************
*
* cdromFsInit - initialize cdromFsLib
*
* This routine initializes cdromFsLib.	It must be called exactly
* once before calling any other routine in cdromFsLib.
*
* RETURNS: OK or ERROR, if driver can not be installed.
*
* ERRNO: S_iosLib_DRIVER_GLUT
*
* SEE ALSO: cdromFsDevCreate(), iosLib.h
*/

STATUS cdromFsInit (void)
    {
    if (cdromFsDrvNum != ERROR)
	{
	return OK;		/* SPR#78456 */
	}

    /* install cdromFs into driver table */

    cdromFsDrvNum = iosDrvInstall (
	 (FUNCPTR) cdromFsReadOnlyError, /* pointer to driver create func */
	 (FUNCPTR) cdromFsReadOnlyError, /* pointer to driver delete func */
	 (FUNCPTR) cdromFsOpen,		 /* pointer to driver open func */
	 (FUNCPTR) cdromFsClose,	 /* pointer to driver close func */
	 (FUNCPTR) cdromFsRead,		 /* pointer to driver read func */
	 (FUNCPTR) cdromFsReadOnlyError, /* pointer to driver write func */
	 (FUNCPTR) cdromFsIoctl		 /* pointer to driver ioctl func */
	);

    if (cdromFsDrvNum == ERROR)
	{
	printf ("cdromFsLib: iosDrvInstall failed\n");
	/* SPR#32715, SPR#32726 */
	}
#ifdef	DEBUG
    else
	{
	DBG_MSG (1)("%d. cdromFsLib: Initialized\n", __LINE__);
	}
#endif	/* DEBUG */

    return (cdromFsDrvNum == ERROR ? ERROR : OK); /* SPR#78456 */
    } /* cdromFsInit() */

#ifdef ERR_SET_SELF
/***************************************************************************
*
* errnoSetOut - put error message
*
* This routine is called instead of errnoSet() during module creation.
*
* RETURNS: N/A
*/

LOCAL VOID errnoSetOut
    (
    int line,
    const u_char * str,
    int err
    )
    {
    printf ("ERROR: line %d : %s = 0x%x\n", line, str, err);
    errno = err;
    }
#endif	/* ERR_SET_SELF */

/***************************************************************************
*
* cdromFsFDAlloc - allocate file descriptor structure
*
* This routine allocates a file descriptor structure and initializes some
* of its base members, such as 'magic' and 'sectBuf'.  Later, you can use
* this file descriptor structure when opening a file.  However, be aware that
* the file descriptor allocated here is not yet connected to the volume's file
* descriptor list.  To free the file descriptor structure allocated here,
* use cdromFsFDFree ().
*
* RETURNS: ptr to FD or NULL.
*
* ERRNO: S_memLib_NOT_ENOUGH_MEMORY
*/

LOCAL T_CDROM_FILE_ID cdromFsFDAlloc
    (
    CDROM_VOL_DESC_ID	pVolDesc	/* processed volume */
    )
    {
    T_CDROM_FILE_ID	pFD = KHEAP_ALLOC (sizeof(T_CDROM_FILE));

    if (pFD == NULL)
	return NULL;

    bzero (pFD, sizeof (T_CDROM_FILE));

    /* allocate sector reading buffer (by default size) */

    if (cdromFsSectBufAlloc (pVolDesc, & (pFD->sectBuf), 0) == ERROR)
	{
	KHEAP_FREE ((char *)pFD);
	return (NULL);
	}

    pFD->inList = 0;		/* FD not included to volume FD list yet */
    pFD->magic = FD_MAG;

    return (pFD);
    }

/***************************************************************************
*
* cdromFsFDFree - deallocate a file descriptor structure
*
* This routine deallocates all allocated memory associated with the specified
* file descriptor structure.
*
* RETURNS: N/A.
*/

LOCAL void cdromFsFDFree
    (
    T_CDROM_FILE_ID	pFD
    )
    {
    pFD->magic = 0;
    cdromFsSectBufFree (&(pFD->sectBuf));

#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
    if (pFD->pMultDir != 0)	   /* Moved here from cdromFsClose() */
	KHEAP_FREE (pFD->pMultDir);
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */

    if (pFD->FRecords != NULL)
	KHEAP_FREE (pFD->FRecords);

    if (pFD->inList)
	lstDelete (&(pFD->pVDList->pVolDesc->FDList), (NODE *)pFD);

    pFD->inList = 0;

    KHEAP_FREE ((char *)pFD);
    }

/***************************************************************************
*
* cdromFsSectBufAlloc - allocate a buffer for reading volume sectors
*
* This routine is designed to allocate a buffer for reading volume data
* by Logical Sectors.  If the <numSectInBuf> parameter is a value greater
* than zero, the buffer size is assumed to be equal to <numSectInBuf>
* times the sector size.  If you specify a <numSectInBuf> of 0, the buffer
* size is CDROM_COM_BUF_SIZE.
*
* The buffer may already have been connected with given control structure.
* If one is large enough, but not two, it is just left intact, if not, -
* free it.
*
* After use, buffer must be deallocated by means of cdromFsSectBufFree ().
*
* RETURNS: OK or ERROR;
*
* ERRNO: S_memLib_NOT_ENOUGH_MEMORY
*/

LOCAL STATUS cdromFsSectBufAlloc
    (
    CDROM_VOL_DESC_ID	pVolDesc,
    SEC_BUF_ID	pSecBuf,	/* buffer control structure */
				/* to which buffer is connected */
    int numSectInBuf		/* LS in buffer */
    )
    {
    assert (pVolDesc != NULL);
    assert (pSecBuf != NULL);

    numSectInBuf = (numSectInBuf == 0)?	 CDROM_COM_BUF_SIZE: numSectInBuf;

    /*
     * may be, any buffer has already been connected with given
     * control structure. Check its size.
     */

    if (pSecBuf->magic == SEC_BUF_MAG && pSecBuf->sectData != NULL)
	{
	if (pSecBuf->maxSects >= numSectInBuf &&
	    pSecBuf->maxSects <= numSectInBuf + 1)
	    return OK;

	pSecBuf->magic = 0;
	KHEAP_FREE (pSecBuf->sectData);
	}

    /* newly init control structure */

    LET_SECT_BUF_EMPTY (pSecBuf);
    pSecBuf->maxSects	= numSectInBuf;

    /* allocation */

    pSecBuf->sectData = KHEAP_ALLOC (numSectInBuf * pVolDesc->sectSize);

    if (pSecBuf->sectData == NULL)
	return ERROR;

    pSecBuf->magic = SEC_BUF_MAG;

    return (OK);
    }

/***************************************************************************
*
* cdromFsSectBufAllocBySize - allocate buffer for reading volume.
*
* After use, buffer must be deallocated by means of cdromFsSectBufFree ().
* This routine calls cdromFsSectBufAlloc() with sufficient
* number of sectors covers <size>.
* If <size> == 0, allocated buffer is  1 sector size.
*
* RETURNS: OK or ERROR;
*/

LOCAL STATUS cdromFsSectBufAllocBySize
    (
    CDROM_VOL_DESC_ID	pVolDesc,
    SEC_BUF_ID	pSecBuf,	/* buffer control structure */
				/* to which buffer is connected */
    int size			/* minimum buffer size in bytes */
    )
    {
    assert (pVolDesc != NULL);	/* SPR#34659 failed */
    assert (pSecBuf != NULL);

    return (cdromFsSectBufAlloc (pVolDesc , pSecBuf,
				 A_PER_B (pVolDesc->sectSize, size) + 1));
    }

/***************************************************************************
*
* cdromFsSectBufFree - deallocate volume sector buffer.
*
* RETURNS: N/A
*/

LOCAL void cdromFsSectBufFree
    (
    SEC_BUF_ID	pSecBuf		/* buffer control structure */
    )
    {
    assert (pSecBuf != NULL);

    if (pSecBuf->magic == SEC_BUF_MAG && pSecBuf->sectData != NULL)
	KHEAP_FREE (pSecBuf->sectData);

    /* buffer structure is unusable now */

    pSecBuf->sectData = NULL;
    pSecBuf->magic = 0;
    }

/***************************************************************************
*
* cdromFsGetLS - read logical sector from volume.
*
* This routine tries to find requested LS in <pSecBuf> and, if failed,
* reads sector from device. Number of read sectors equal to buffer size.
*
* RETURNS: ptr on LS within buffer or NULL if error accessing device.
*
* ERRNO: S_cdromFsLib_DEVICE_REMOVED, if CD disk has not been ejected;
* or any, may be set by block device driver read function.
*/

LOCAL u_char * cdromFsGetLS
    (
    CDROM_VOL_DESC_ID	pVolDesc,
    u_long		LSNum,		/* logical sector to get */
    u_long		maxLSs,		/* maximum LS to read */
    SEC_BUF_ID		pSecBuf		/* sector data control structure, */
					/* to put data to */
    )
    {
    assert (pVolDesc != NULL);
    assert (pSecBuf->sectData != NULL);
    assert (pSecBuf->magic == SEC_BUF_MAG);
				/* SPR#75766 Next assert() failed. */

    assert (LSNum < pVolDesc->pBlkDev->bd_nBlocks / pVolDesc->LSToPhSSizeMult);

    if (maxLSs == 0)
	maxLSs = 1;

    DBG_MSG(400)("%d. access for sector %lu\n", __LINE__, LSNum);

    /* check for disk has not been ejected */

    if (pVolDesc->pBlkDev->bd_readyChanged)
	{
	cdromFsVolUnmount (pVolDesc);
	errnoSet (S_cdromFsLib_DEVICE_REMOVED);
	return (NULL);
	}

    /* may be sector already in buffer ('if' for negative condition) */

    if (pSecBuf->numSects == 0 ||
	LSNum < pSecBuf->startSecNum ||
	LSNum >= pSecBuf->startSecNum + pSecBuf->numSects)
	{
	/* sector not in the buffer, read it from disk */

	BLK_DEV * pBlkDev = pVolDesc->pBlkDev;
	u_long	  numLSRead;

	assert (pBlkDev != NULL);

	/*
	 * num read sects must not exceed last CD volume sector
	 * This is needed to avoid reading off the end of a volume.
	 */

	numLSRead = min (pBlkDev->bd_nBlocks / pVolDesc->LSToPhSSizeMult -
			 LSNum, pSecBuf->maxSects);

	/*
	 * num read sects must not exceed last allowed read ahead sector
	 * This is needed to avoid reading off the end of a file section.
	 * On a CD-R those blocks might not be recorded at all.
	 */

	numLSRead = min (numLSRead, maxLSs);

	/* Do the read */

	if (pBlkDev->bd_blkRd (pBlkDev, LSNum * pVolDesc->LSToPhSSizeMult,
			       numLSRead * pVolDesc->LSToPhSSizeMult,
			       pSecBuf->sectData) == ERROR)
	    {
	    LET_SECT_BUF_EMPTY (pSecBuf);
	    DBG_MSG(0)("%d. CDROM ERROR: error reading volume sect"
		       " %lu - %lu\a\n",
		       __LINE__, LSNum, pSecBuf->numSects);
	    return (NULL);
	    }

	/* successfully read */

	pSecBuf->startSecNum = LSNum;
	pSecBuf->numSects = numLSRead;
	}

    return (pSecBuf->sectData +
	     (LSNum - pSecBuf->startSecNum) * pVolDesc->sectSize);
    }

/***************************************************************************
*
* cdromFsGetLB - get logical block
*
* This routine tries to find requested LB in <pSecBuf> and, if it fails,
* reads sector, containing the LB from device.
* <pSecBuf> is used as sector buffer. If <pSecBuf> is NULL, global
* volume buffer is used.
*
* RETURNS: ptr on LB within buffer or NULL if error with set errno
* to appropriate value.
*/

LOCAL u_char * cdromFsGetLB
    (
    T_CDROMFS_VD_LST_ID pVDList,
    u_long	LBNum,			/* logical block to get */
    u_long	maxLBs,			/* maximum LB to read */
    SEC_BUF_ID	pSecBuf			/* sector data control structure, */
					/* to put data to */
    )
    {
    u_int	secNum;		/* LS, contane LB */
    u_int	maxLSs;		/* maximum LS to read */
    u_char *	pData;		/* ptr to LB within read data buffer */
    CDROM_VOL_DESC_ID	pVolDesc;

    assert (pVDList != NULL);
    assert (LBNum > 15);	/* SPR#80424 failed */

    pVolDesc = pVDList->pVolDesc;

    assert (pVolDesc != NULL);

    if (pSecBuf == NULL)	/* to use common buffer */
	pSecBuf = &(pVDList->pVolDesc->sectBuf);

    assert (pSecBuf->sectData != NULL);

    DBG_MSG(300)("%d. access for LB %lu\n", __LINE__, LBNum);

    secNum = LBNum >> pVDList->LBToLSShift;		/* LS, contain LB  */

    maxLSs =  maxLBs >> pVDList->LBToLSShift;

    pData = cdromFsGetLS (pVolDesc, secNum, maxLSs, pSecBuf);

    if (pData == NULL)
	return NULL;

    DBG_MSG(400)("%d. offset in buf: %lu(last bits = %lu)\n",
		 __LINE__,
		 pVDList->LBSize * LAST_BITS (LBNum, pVDList->LBToLSShift),
		 LAST_BITS (LBNum, pVDList->LBToLSShift));

    return (pData + pVDList->LBSize *
		     LAST_BITS (LBNum, pVDList->LBToLSShift));
    }

/***************************************************************************
*
* cdromFsDIRGet - get directory from the current root folder
*
* This routine tries to find requested directory for an specifically FD.
* The routine call the function cdromFsGetLB with Directory RecLB
*
* RETURNS: ptr on LB from directory buffer or NULL if any error occurred.
*/

LOCAL u_char * cdromFsDIRGet
    (
	T_CDROM_FILE_ID pFD	/* FD to fill, containing parent */
    )
    {
    u_long	headSizeLB;	/* Size of directory in LBs */
    u_long	headLBIndex;	/* (Destination) LB in dir preceding head */
    u_long	headLBNum;	/* (Destination) LB containing dir record */
    u_long	headRemLB;	/* (Destination) Remaining LB in the directory */
    u_char *	pHeadLb;	/* (Destination) Point to LB of dir record */
#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
    u_char *	pNextLb;	/* (Source) Point to LB of same directory */
				/* in another volume descriptor */
    u_int	headDirEnt;	/* (Destination) # of dir records in pHead dir */
    u_int	nextDirEnt;	/* (Source) # of dir records in pNext dir */
    u_int	nrMulVD;	/* Loop index */
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */

    assert (pFD != NULL);

    /* Get the logical block that contains the directory record */

    headLBIndex = pFD->FCDirRecAbsOff / pFD->pVDList->LBSize;

    headLBNum = pFD->FCDirFirstRecLB + headLBIndex;

    headSizeLB
	= ROUND_UP (pFD->FSize, pFD->pVDList->LBSize) / pFD->pVDList->LBSize;

    headRemLB = headSizeLB - headLBIndex;

    pHeadLb = cdromFsGetLB (pFD->pVDList, headLBNum, headRemLB, &(pFD->sectBuf));

#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
    if (pFD->nrMultDir !=0 && pFD->pMultDir[0] !=0)
	{
	for (nrMulVD = 0; nrMulVD < pFD->nrMultDir; nrMulVD++)
	    {
	    headDirEnt = cdromFsFindDirEntered (pHeadLb, pFD->pVDList->LBSize);

	    /* Get the logical block that contains the alternate record */

	    pNextLb = cdromFsGetLB (pFD->pVDList, pFD->pMultDir[nrMulVD], 1, 0);

	    nextDirEnt = cdromFsFindDirEntered (pNextLb, pFD->pVDList->LBSize);

	    if (nextDirEnt > 2)
		{
		cdromFsAddRecsToFD (pNextLb, 2, pHeadLb, headDirEnt,
				    nextDirEnt-2,
				    (pFD->sectBuf.numSects -
				     (headLBNum - pFD->sectBuf.startSecNum)) *
				    pFD->pVDList->pVolDesc->sectSize);
		}
	    }
	}
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */

    return (pHeadLb);
    }

/***************************************************************************
*
* cdromFsPTGet - retrieve Path Table for given VD from volume.
*
* By default, if pSecBuf == NULL, volume dir hierarchy PT buffer
* is used for storing path table. It is allocated only once and
* is deallocated over volume unmounting.
*
* Only if pSecBuf != NULL required space for PT automaticly allocated in it.
*
* RETURNS: ptr to PT or NULL if any error occurred.
*/

LOCAL u_char * cdromFsPTGet
    (
    T_CDROMFS_VD_LST_ID pVdLst,
    SEC_BUF_ID	pSecBuf		/* may be NULL. Ptr to buffer control */
				/* structure to read PT to */
    )
    {
    u_char *	pPT;		/* Return value */
    u_long	PTSizeLB;	/* Number of LB in path table */

    assert (pVdLst != NULL);

    if (pSecBuf == NULL)	/* use volume dir hierarchy PT buffer */
	pSecBuf = &(pVdLst->PTBuf);

    /*
     * if the buffer already has been allocated, the following call does
     * nothing
     */

    /*
     * SPR#34659 Problem pVdList->pVolDesc can be set to NULL by
     * cdromFsVolUnmount() concurrent with cdromFsOpen().  This is fixed
     * by cdromFsVolLock() added to cdromFsOpen().
     */

    if (cdromFsSectBufAllocBySize (pVdLst->pVolDesc, pSecBuf,
				   pVdLst->PTSize) == ERROR)
	return NULL;

    /* Compute size of PT in blocks */

    PTSizeLB = ROUND_UP (pVdLst->PTSize, pVdLst->LBSize) / pVdLst->LBSize;

    /* if PT already in buffer, following call do nothing */

    pPT = cdromFsGetLB (pVdLst, pVdLst->PTStartLB, PTSizeLB, pSecBuf);

    return (pPT);
    }

/***************************************************************************
*
* cdromFsNextPTRec - pass to a next PT record.
*
* As result, *ppPT points to the next PT record.
*
* RETURNS: offset of record from PT start or 0 if last record encounted
*/

LOCAL u_long cdromFsNextPTRec
    (
    u_char **	ppPT,		/* address of ptr to current record */
				/* within buffer, containing PT */
    u_long	offset,		/* offset of current record from PT start */
    u_long	PTSize		/* path table size (stored in volume */
				/* descriptor */
    )
    {
    short	size;	/* current PT record size */

    /* skip current PT record */

    PT_REC_SIZE (size, *ppPT);
    offset += size;
    *ppPT += size;

    /*
     * set of zero bytes may follow PT record, if that is last record in LB.
     * First non zero byte starts next record
     */

    for (; offset < PTSize; offset++, (*ppPT)++)
	if (**ppPT != 0)
	    break;

    return (offset);
    }

/***************************************************************************
*
* cdromFsShiftCount - count shift for transfer <source> to <dest>.
*
* This routine takes two values, that are power of two and counts
* the difference of powers, which is, for instance, the number of
* bits to shift <source> in order to get <dest>.

* If <source> <= <dest>, the result is positive and <dest> == <source>
* << the result.
*
* If <source> > <dest>, the result is negative and <dest> == <source>
* >> - the result.
*
* Because <dest> may be less, than <source>, (-1) may not be used as error
* indication return code, so an impossible value of 100 is taken for this
* purpose.
*
* RETURNS: number of bits to shift <source>, in order to get <dest>
* or a value of (100) if it is impossible to calculate shift count.
*
* ERRNO: S_cdromFsLib_ONE_OF_VALUES_NOT_POWER_OF_2.
*/

LOCAL u_char cdromFsShiftCount
    (
    u_long	source,
    u_long	dest
    )
    {
    u_char	i;

    if (source <= dest)
	{
	for (i = 0; i < sizeof (u_long) * 8; i++)
	    if ((source << i) == dest)
		return i;
	}
    else	/* source > dest */
	{
	for (i = 1; i < sizeof (u_long) * 8; i++)
	    if ((dest << i) == source)
		return (-i);
	}

    errnoSet (S_cdromFsLib_ONE_OF_VALUES_NOT_POWER_OF_2);
    return (100);
    }

/***************************************************************************
*
* cdromFsVDAddToList - add VD to VD list.
*
* Allocate VD list structure, fill in its fields (from <pVDData> buffer)
* and add to VD list.
*
* RETURNS: OK or ERROR if any failed.
*
* ERRNO: S_cdromFsLib_SUCH_PATH_TABLE_SIZE_NOT_SUPPORTED,
* S_cdromFsLib_MAX_DIR_HIERARCHY_LEVEL_OVERFLOW,
* S_memLib_NOT_ENOUGH_MEMORY
*/

LOCAL STATUS cdromFsVDAddToList
    (
    CDROM_VOL_DESC_ID	pVolDesc,
    const u_char *	pVDData,	/* data, has been got from disk */
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
    u_long	SesiPseudoLBNum,	/* LB number at which session starts */
					/* if let (LB size = VD size) */
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
    u_long	VDPseudoLBNum,		/* LB number, contains given VD, */
					/* if let (LB size = VD size) */
    u_short	uniCodeLev,		/* See T_CDROMFS_VD_LST.uniCodeLev */
    u_char	VDSizeToLSSizeShift	/* relation between VD size */
					/* and LS size */
    )
    {
    T_CDROMFS_VD_LST_ID pVDList;

    assert (pVolDesc != NULL);
    assert (pVDData != NULL);

    pVDList = KHEAP_ALLOC (sizeof (T_CDROMFS_VD_LST));
    if (pVDList == NULL)
	return (ERROR);

    bzero ((u_char *) pVDList, sizeof (T_CDROMFS_VD_LST));

    pVDList->uniCodeLev = uniCodeLev;
    pVDList->pVolDesc = pVolDesc;

    C_BUF_TO_LONG (pVDList->volSize, pVDData, ISO_VD_VOL_SPACE_SIZE);

    /* since PT is stored in memory, max PT size is restricted */

    C_BUF_TO_LONG (pVDList->PTSize, pVDData, ISO_VD_PT_SIZE);
    C_BUF_TO_LONG (pVDList->PTSizeOnCD, pVDData, ISO_VD_PT_SIZE);

    if (pVDList->PTSizeOnCD > CDROM_LIB_MAX_PT_SIZE)
	{
	errnoSet (S_cdromFsLib_SUCH_PATH_TABLE_SIZE_NOT_SUPPORTED);
	KHEAP_FREE ((char *)pVDList);
	return (ERROR);
	}

    C_BUF_TO_LONG (pVDList->PTStartLB, pVDData, ISO_VD_PT_OCCUR);
    C_BUF_TO_LONG (pVDList->rootDirSize, pVDData,
		   ISO_VD_ROOT_DIR_REC + ISO_DIR_REC_DATA_LEN);
    C_BUF_TO_LONG (pVDList->rootDirStartLB, pVDData,
		   ISO_VD_ROOT_DIR_REC + ISO_DIR_REC_EXTENT_LOCATION);
    C_BUF_TO_SHORT (pVDList->volSetSize, pVDData, ISO_VD_VOL_SET_SIZE);
    C_BUF_TO_SHORT (pVDList->volSeqNum, pVDData, ISO_VD_VOL_SEQUENCE_N);

    /*
     * ISO-9660 6.2.2 Logical Block
     * sizeof(Logical Block) <= sizeof(Logical Sector).
     * sizeof(Logical Block) is always a power of 2.
     *
     * cdromFsLib implementation
     * sizeof(Logical Block) = pVDList->LBSize.
     * sizeof(Logical Sector) = sizeof(Logical Block) << pVDList->LSToLSShift.
     */

    C_BUF_TO_SHORT (pVDList->LBSize, pVDData, ISO_VD_LB_SIZE);
    pVDList->LBToLSShift = cdromFsShiftCount (pVDList->LBSize,
					      pVolDesc->sectSize);
    pVDList->type	= ((T_ISO_VD_HEAD_ID)pVDData)->type;
    pVDList->fileStructVersion	= *(pVDData + ISO_VD_FILE_STRUCT_VER);

    pVDList->VDPseudoLBNum	= VDPseudoLBNum;

    /*
     * read PT to buffer and init dirLevBorders...[].
     * In accordance with ISO9660 all directories records in
     * PT are sorted by hierarchy levels and are numbered from 1.
     * (only root has number 1 and lays on level 1).
     * Number of levels restricted to 8 for ISO 9660 or 120 for Joliet.
     * dirLevBordersOff[ n ] contains offset of first PT record on level
     * (n+2) (root excluded and array encounted from 0) from PT start.
     * dirLevLastRecNum[ n ] contains number of last PT record on level
     * (n+2).
     * Base of algorithm:
     * Storing number of last PT rec on hierarchy level <n> in
     * <prevLevLastRecNum>, will skip level <n+1>, on which all
     * directories have parent only within n; first directory
     * which parent dir number exceeds <prevLevLastRecNum>
     * starts level n+2.
     */
    {
    u_char * pPT;
    u_int	 offset,		/* absolute offset from PT start */
		 level,			/* hierarchy level (minus 2) */
		 prevLevLastRecNum,	/* number of last PT rec on */
					/* previous hierarchy level */
		 prevRecNum ;		/* previous PT record number */

    pPT = cdromFsPTGet (pVDList, NULL);

    if (pPT == NULL)
	{
	KHEAP_FREE ((char *)pVDList);
	return (ERROR);
	}

    /*
     * pass over root dir entry, dir hierarchy level 1;
     * root dir record is first PT record and its number is 1
     */

    offset = cdromFsNextPTRec (&pPT, 0, pVDList->PTSize);

    level = 0;	/* not put to array data for root directory */
    prevRecNum = 1;	/*  root number in PT */
    prevLevLastRecNum = 1;
    bzero ((u_char *)(pVDList->dirLevBordersOff),
	   sizeof(pVDList->dirLevBordersOff));
    bzero ((u_char *)(pVDList->dirLevLastRecNum),
	   sizeof(pVDList->dirLevLastRecNum));

    /*
     * over this loop all dir hierarchy levels' bounds in PT
     * will be found.
     */

    pVDList->dirLevBordersOff[0] = offset;
    for (; offset < pVDList->PTSize && level < CDROM_MAX_DIR_LEV - 1;)
	{
	u_int prev;	/* parent dir number for current record */

	PT_PARENT_REC (prev, pPT);

#ifdef	DEBUG
	/* debugging */

	DBG_COP_TO_BUF (pPT + ISO_PT_REC_DI, *pPT);
	DBG_MSG(200)("%d. %4d\t%20s\tparent # %3d, D_ID_LEN %2d	 level %d\n",
		     __LINE__, prevRecNum + 1, dbgvBuf, (int)prev, (int)*pPT,
		     level + 2);
#endif	/* DEBUG */

	/* if directory level overed */

	if (prev > prevLevLastRecNum)
	    {
	    /* close level */

	    pVDList->dirLevLastRecNum[level] = prevRecNum;

	    level++;
	    if (level > CDROM_MAX_DIR_LEV - 1)
		break;

	    /* current level first record offset within PT */

	    pVDList->dirLevBordersOff[level] = offset;
	    prevLevLastRecNum = prevRecNum;
	    }

	prevRecNum ++;

	offset = cdromFsNextPTRec (&pPT, offset, pVDList->PTSize);
	}

    /* close last level */

    pVDList->dirLevLastRecNum[level] = prevRecNum;

    /*
     * may be loop breaking only because CDROM_MAX_DIR_LEV overloading
     * before fully PT exhausting, that is an error
     */

    if (offset < pVDList->PTSize)
	{
	KHEAP_FREE ((char *)pVDList);
	errnoSet (S_cdromFsLib_MAX_DIR_HIERARCHY_LEVEL_OVERFLOW);
	return (ERROR);
	}

    pVDList->numDirLevs = level + 1;	   /* <level> starts from 0 */
    pVDList->numPTRecs = prevRecNum;
    }  /* hierarchy bounds init */

    /* VD have been built. Add it to VD list */

    pVDList->magic = VD_LIST_MAG;

    lstAdd (&(pVolDesc->VDList), (NODE *)pVDList);

    return (OK);
    }

/***************************************************************************
*
* cdromFsVolUnmount - mark in all device depends data, that volume unmounted.
*
* All volume descriptors are deallocated.
* FDList not deallocated, but only marked as "file unaccessible.
*
* RETURNS: N/A
*
* ERRNO: S_cdromFsLib_SEMGIVE_ERROR
*/

LOCAL void cdromFsVolUnmount
    (
    CDROM_VOL_DESC_ID	pVolDesc  /* cdrom volume decriptor id */
    )
    {
    T_CDROM_FILE_ID	pFDList;
    T_CDROMFS_VD_LST_ID pVDList;

    assert (pVolDesc != NULL);
    assert (pVolDesc->mDevSem != NULL);

    if (semTake (pVolDesc->mDevSem, WAIT_FOREVER) == ERROR)
	return;

    /*
     * mark all opened	files as unaccessible
     *
     *	SPR#70072  This must be done before the below
     *	lstFree (&(pVolDesc->VDList)); so that cdromFsFDFree() does not
     *	corrupt memory by removing the FD from that list after the list
     *	has already been freed.
     */

    for (pFDList = (T_CDROM_FILE_ID)lstFirst (&(pVolDesc->FDList));
	 pFDList != NULL;
	 pFDList = (T_CDROM_FILE_ID)lstNext ((NODE *)pFDList))
	{
	pFDList->inList = 0;	   /* SPR#70072 */
	}

    /* free VD list with PT buffers */

    for (pVDList = (T_CDROMFS_VD_LST_ID)lstFirst (&(pVolDesc->VDList));
	 pVDList != NULL;
	 pVDList = (T_CDROMFS_VD_LST_ID)lstNext ((NODE *)pVDList))
	{
	cdromFsSectBufFree (&(pVDList->PTBuf));
	}

    lstFree (&(pVolDesc->VDList));

    /* mark in VD, that volume unmounted */

    pVolDesc->unmounted = 1;

#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
    /* for Multisession, set Session to default */

    pVolDesc->SesiToRead = DEFAULT_SESSION;
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */

    if (semGive (pVolDesc->mDevSem) == ERROR)
	errnoSet (S_cdromFsLib_SEMGIVE_ERROR);

    assert (lstCount (&(pVolDesc->VDList)) == 0);
    }

/***************************************************************************
*
* cdromFsVolMount - mount cdrom volume.
*
* This routine reads the volume descriptors and creates VD lists.
* This routine checks which CD-Rom mode is set and adds only this VD's
* to the list which mode is set. (mode can be Joliet, ISO9660 or AUTO mode)
*
* RETURNS: OK or ERROR
*
* ERRNO: S_cdromFsLib_UNKNOWN_FILE_SYSTEM, S_cdromFsLib_SEMGIVE_ERROR, or
* any errno may be set by supplementary functions, for example
* S_memLib_NOT_ENOUGH_MEMORY from malloc().
*/

LOCAL STATUS cdromFsVolMount
    (
    CDROM_VOL_DESC_ID	pVolDesc  /* cdrom volume decriptor id */
    )
    {
    T_CDROMFS_VD_LST	VDList;	       /* volume descriptor list  */
    u_long		LBRead;	       /* logical blk to read	  */
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
    u_long		sesStartLB;    /* Session start LB */
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
    u_char		VDLast = 0;
    u_char		primVDMounted; /* primary VD mounted flag */
    u_char		UCSLevel;      /* which UCS-2 Level is used */
    u_char *		pVDData;

    assert (pVolDesc != NULL);
    assert (pVolDesc->mDevSem != NULL);

    /* private semaphore */

    if (semTake (pVolDesc->mDevSem, WAIT_FOREVER) == ERROR)
	return ERROR;

    /* before mount new volume, it have to unmount previous */

    if (! pVolDesc->unmounted)
	cdromFsVolUnmount (pVolDesc);

    pVolDesc->pBlkDev->bd_readyChanged = FALSE;

    /*
     * before VD was read let LB size equal to VD size, since
     * each VD defines its own LB size. Because VD size and LS size are
     * powers of 2, one may be get from second by means of shift.
     */

    VDList.LBSize = ISO_VD_SIZE;
    VDList.LBToLSShift = cdromFsShiftCount (ISO_VD_SIZE, pVolDesc->sectSize);
    VDList.pVolDesc = pVolDesc;

    /* data in buffer remain from unmounted volume, so invalid */

    LET_SECT_BUF_EMPTY (&(VDList.pVolDesc->sectBuf));

    /* no one primary VD was found yet */

    primVDMounted = 0;

#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
    sesStartLB =
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
	LBRead = 0;	/* set LB to session 0 */

    /* Determine session to use */
    {
    /* calculated  ISO_PVD_BASE_LS */
    CDROM_TRACK_RECORD	cdStatus;

    cdStatus.bufferLength = (CDROM_MAX_TRACKS * sizeof (readTocHeaderType)) +
	sizeof (readTocSessionDescriptorType);

    cdStatus.statBuffer = KHEAP_ALLOC (cdStatus.bufferLength);

#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
    if (cdromFsTocRead(pVolDesc, &cdStatus) == OK)
	{
	u_short SesiNum;

	readTocHeaderType * pTocHeader
	    = (readTocHeaderType *) cdStatus.statBuffer;

	readTocSessionDescriptorType * pTocSessionDescriptor;

	/* determine latest session on CD */

	pVolDesc->SesiOnCD = pTocHeader->lastSessionNumber - 1;

	/* and use this as the default session */

	SesiNum = pVolDesc->SesiOnCD;

	/* is there another session requested ? */

	if (pVolDesc->SesiToRead != DEFAULT_SESSION)
	    {
	    /*
	     * Yes.  Requested session must be smaller than number of
	     * sessions on disc
	     */

	    if (pVolDesc->SesiToRead < pVolDesc->SesiOnCD)
		/* use this one instead of the default */

		SesiNum = pVolDesc->SesiToRead;
	    else
		/*
		 * Requested session is too large.
		 * Switch to default session.
		 */

		pVolDesc->SesiToRead = DEFAULT_SESSION;
	    }

	
	pTocSessionDescriptor
	    = (readTocSessionDescriptorType *) (pTocHeader + 1);

	pTocSessionDescriptor += SesiNum;

	sesStartLB
	    = ntohl (*(UINT32 *) (pTocSessionDescriptor->sessionStartAddress));

	LBRead = sesStartLB;
	}
#else	/* CDROMFS_MULTI_SESSION_SUPPORT */
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */

    KHEAP_FREE (cdStatus.statBuffer);
    }	/* Multisession */

    /* by ISO/Joliet, first volume descriptor always lays in ISO_PVD_BASE_LS */

    LBRead += ISO_PVD_BASE_LS;
    for (VDLast = 0;
	 ! VDLast && LBRead < pVolDesc->pBlkDev->bd_nBlocks;
	 LBRead ++)
	{
	/* read VD from disk */

	pVDData = cdromFsGetLB (&VDList, LBRead, 1, NULL);

	if (pVDData == NULL)
	    {
	    cdromFsVolUnmount (pVolDesc);
	    semGive (pVolDesc->mDevSem);
	    return ERROR;
	    }

	/* check standard ISO volume ID */

	if (strncmp (((T_ISO_VD_HEAD_ID)pVDData)->stdID, ISO_STD_ID ,
		    ISO_STD_ID_SIZE))
	    {
	    /* not ISO volume ID */

	    /*
	     * may be any unknown VD in set, but not first, that must be
	     * ISO primary VD only (at least in current version)
	     */

	    if (primVDMounted)	/* primary have been found already */
		continue;

	    else
		{
		cdromFsVolUnmount (pVolDesc);
		semGive (pVolDesc->mDevSem);
		DBG_MSG(0)("%d. Warning: unknown CR-ROM format detected,"
			   " ignored.\n", __LINE__);
		errnoSet (S_cdromFsLib_UNKNOWN_FILE_SYSTEM);
		return ERROR;
		}
	    } /* check VD ID */

	/*
	 * Only VD set termination, primary and supplementary VD are
	 * interesting; and not process secondary copies of primary VD.
	 *
	 * Check ISO 2022 UCS-2 Escape Sequences as recorded in the ISO
	 * 9660 SVD.
	 */

	if (memcmp(pVDData + ISO_VD_ESCAPE_SEC, UCS_2_LEVEL1_ID, 3) == 0)
		UCSLevel = 1;	/* UCS-2 Level 1 is used */

	/*
	 * check ISO 2022 UCS-2 Escape Sequences as recorded in the ISO
	 * 9660 SVD
	 */

	else if(memcmp(pVDData + ISO_VD_ESCAPE_SEC, UCS_2_LEVEL2_ID, 3) == 0)
		UCSLevel = 2;	/* UCS-2 Level 2 is used */

	/*
	 * check ISO 2022 UCS-2 Escape Sequences as recorded in the ISO
	 * 9660 SVD
	 */

	else if(memcmp(pVDData + ISO_VD_ESCAPE_SEC, UCS_2_LEVEL3_ID, 3) == 0)
		UCSLevel = 3;	/* UCS-2 Level 3 is used */

	else
		UCSLevel = 0;

	if (((T_ISO_VD_HEAD_ID)pVDData)->type == ISO_VD_SETTERM)
	    VDLast = 1;
	else if ((((T_ISO_VD_HEAD_ID)pVDData)->type == ISO_VD_PRIMARY &&
		  ! primVDMounted) ||
		 ((T_ISO_VD_HEAD_ID)pVDData)->type == ISO_VD_SUPPLEM)
	    {
	    /* first VD on volume must be primary (look ISO 9660) */

	    if (((T_ISO_VD_HEAD_ID)pVDData)->type == ISO_VD_SUPPLEM &&
		! primVDMounted)
		{
		cdromFsVolUnmount (pVolDesc);

		/*
		 * The following DIRMode change is required for the
		 * following reason: If we try to switch from ISO to
		 * Joliet on a disc that does not contain a SVD, then the
		 * mounting will fail. If we do not switch back to
		 * default, then it is not possible to do this using IOCTL
		 * commands. It is also not possible in this circumstance
		 * to open the device as it can not read anything from the
		 * disc anymore.
		 */

                pVolDesc->DIRMode = MODE_DEFAULT;

		semGive (pVolDesc->mDevSem);
		DBG_MSG(0)("%d. Warning: unknown CR-ROM format detected,"
			   " ignored.\n", __LINE__);
		errnoSet (S_cdromFsLib_UNKNOWN_FILE_SYSTEM);

		return ERROR;
		}

	    if (pVolDesc->DIRMode == MODE_AUTO)
		{
		if (cdromFsVDAddToList (pVolDesc, pVDData,
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
					sesStartLB,
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
					LBRead,
					UCSLevel,
					VDList.LBToLSShift) == ERROR)
		    {
		    cdromFsVolUnmount (pVolDesc);
		    semGive (pVolDesc->mDevSem);
		    return ERROR;
		    }
		}
	    else if ((UCSLevel > 0) && (pVolDesc->DIRMode == MODE_JOLIET))
		{
		if (cdromFsVDAddToList (pVolDesc, pVDData,
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
					sesStartLB,
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
					LBRead,
					UCSLevel,
					VDList.LBToLSShift) == ERROR)
		    {
		    cdromFsVolUnmount (pVolDesc);
		    semGive (pVolDesc->mDevSem);
		    return ERROR;
		    }
		}
	    else if ((UCSLevel == 0) && (pVolDesc->DIRMode == MODE_ISO9660))
		{
		if (cdromFsVDAddToList (pVolDesc, pVDData,
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
					sesStartLB,
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
					LBRead,
					UCSLevel,
					VDList.LBToLSShift) == ERROR)
		    {
		    cdromFsVolUnmount (pVolDesc);
		    semGive (pVolDesc->mDevSem);
		    return ERROR;
		    }
		}

	    /* if primary VD found in VD set */

	    if (((T_ISO_VD_HEAD_ID)pVDData)->type == ISO_VD_PRIMARY)
		primVDMounted = 1;
	    } /* else if */
	} /* for */

    /* each volume contains at least one, primary volume descriptor. */

    if (lstCount (&(pVolDesc->VDList)) == 0)
	{
	cdromFsVolUnmount (pVolDesc);

	/*
	 * The following DIRMode change is required for the the same
	 * reason as above.
	 */

        pVolDesc->DIRMode = MODE_DEFAULT;

	semGive (pVolDesc->mDevSem);

	DBG_MSG(0)("%d. Warning: unknown CR-ROM format detected, ignored.\n",
		   __LINE__);
	errnoSet (S_cdromFsLib_UNKNOWN_FILE_SYSTEM);

	return ERROR;
	}

    assert (lstFirst(&(pVolDesc->VDList)) != NULL);

    /* device successfully mounted */

    pVolDesc->unmounted = 0;

    /* return semaphore */

    if (semGive (pVolDesc->mDevSem) == ERROR)
	{
	cdromFsVolUnmount (pVolDesc);
	errnoSet (S_cdromFsLib_SEMGIVE_ERROR);
	return ERROR;
	}

    return OK;
    }

/***************************************************************************
*
* cdromFsDirDateTime2Long - convert ISO directory Date/Time to UNIX time_t
*
* This routine converts date/time in ISO directory format
* (T_FILE_DATE_TIME) to the UNIX long time format.
* See ISO-9660 Section 9.1.5, Table 9, page 20.
*
* RETURNS: Converted time
*
* NOMANUAL
*/

LOCAL time_t cdromFsDirDateTime2Long
    (
    const T_FILE_DATE_TIME *	pDateTime /* Pointer to ISO date/time */
    )
    {
    struct tm			recTime;  /* For mktime() */

    recTime.tm_sec	=  pDateTime->seconds;
    recTime.tm_min	=  pDateTime->minuts;
    recTime.tm_hour	=  pDateTime->hour;
    recTime.tm_mday	=  pDateTime->day;
    recTime.tm_mon	=  pDateTime->month - 1;
    recTime.tm_year	=  pDateTime->year;

    return (mktime (&recTime));
    }

/***************************************************************************
*
* cdromFsFillFDForDir - fill T_CDROM_FILE for directory (only from PT record).
*
* This routine fill in fields of T_CDROM_FILE structure (ptr on with
* comes in <pFD>) for directory, that is described by <pPTRec> PT record
*
* INTERNAL
* Changes pPTRec.
*
* RETURNS: OK or ERROR if malloc() or disk access error occur.
*
* ERRNO: S_cdromFsLib_INVALID_DIRECTORY_STRUCTURE,
* S_memLib_NOT_ENOUGH_MEMORY.
*/

LOCAL STATUS cdromFsFillFDForDir
    (
    T_CDROMFS_VD_LST_ID pVDList,	/* ptr to VD list		*/
    T_CDROM_FILE_ID	pFD,		/* FD to fill			*/
    u_char *	  	pPTRec,		/* directory PT record		*/
    u_int		dirRecNumInPT	/* dir number in PT		*/
    )
    {
    u_short		EARSize;	/* EAR size in bytes */

    assert (pVDList != NULL);
    assert (pVDList->magic == VD_LIST_MAG);
    assert (pVDList->pVolDesc != NULL);
    assert (pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (pFD != NULL);
    assert (pPTRec != NULL);
    assert (*pPTRec != 0);	/* DIR ID Length */

    /*
     * These fields are not needed to be filled for a directory:
     * pFD->FRecords;
     * pFD->FCSStartLB;
     * pFD->FCSFUSizeLB;
     * pFD->FCSGapSizeLB;
     */

    bzero (pFD->name, sizeof (pFD->name));
    bcopy (pPTRec + ISO_PT_REC_DI, pFD->name, *pPTRec);

    PT_PARENT_REC (pFD->parentDirNum, pPTRec);
    C_BUF_TO_LONG (pFD->FStartLB, pPTRec, ISO_PT_REC_EXTENT_LOCATION);
    EARSize = *(pPTRec + ISO_PT_REC_EAR_LEN);

    pFD->FStartLB += EARSize;

    /*
     * Directory is stored as one extension, without records and
     * interleaving
     */

    pFD->FCSInterleaved = CDROM_NOT_INTERLEAVED;
    pFD->FType		= S_IFDIR;

    /* init buffer for device access */

    if (cdromFsSectBufAlloc (pVDList->pVolDesc, &(pFD->sectBuf), 0) == ERROR)
	return ERROR;

    /* current condition for readDir call */

    pFD->FCDirRecAbsOff = 0;	/* Current entry is first */
    pFD->FCDirFirstRecLB = pFD->FStartLB;

    /* First file section */

    pFD->FCSAbsOff	= 0;

    pFD->FDType		= (u_short)(-1);  /* not one request was served */
    pFD->FCDAbsPos	= 0;
    pFD->FCEOF		= 0;

    /* some directory specific fields */

    pFD->DNumInPT	= dirRecNumInPT;
#if 0			/* NOT USED until record format files supported */
    pFD->DRecLBPT	= 0;	/*
				 * TBD: not need currently. May be counted in
				 * principal by parent function
				 */
    pFD->DRecOffLBPT	= 0;
#endif /* NOT USED until record format files supported */

    /*
     * read first directory record and get special dir descriptions
     *
     * Size of directory not known, therefore do not read ahead.
     */

    pPTRec = cdromFsGetLB (pVDList, pFD->FStartLB, 1, &(pFD->sectBuf));

    if (pPTRec == NULL)
	{
	cdromFsSectBufFree (&(pFD->sectBuf));
	return ERROR;
	}

    pFD->FCDirRecPtr = pPTRec;

    /* first directory record must contain 0x00 as name */

    if (*(pPTRec + ISO_DIR_REC_FI) != 0)
	{
	errnoSet (S_cdromFsLib_INVALID_DIRECTORY_STRUCTURE);
	cdromFsSectBufFree (&(pFD->sectBuf));
	return ERROR;
	}

    C_BUF_TO_LONG (pFD->FSize, pPTRec, ISO_DIR_REC_DATA_LEN);
    pFD->FCSSize	= pFD->FSize;

    /* fill FAbsTime field (u_long time format) */

    pFD->FDateTimeLong
	    = cdromFsDirDateTime2Long ((T_FILE_DATE_TIME_ID)
				       (pPTRec + ISO_DIR_REC_DATA_TIME));

    pFD->pVDList	= pVDList;
    pFD->magic		= FD_MAG;

    /* connect to volume's FD list */

    if (!pFD->inList)
	lstAdd (&(pVDList->pVolDesc->FDList), (NODE *)pFD);

    pFD->inList = 1;

    /*
     * Directory invariant
     *
     * 1. fd is valid and mounted.
     * 2. fd is on a valid valume.
     * 3. fd has a valid primary or secondary volume descriptor.
     * 4. If end-of-file, then position 1 byte past data in the file.
     * 5. If not end-of-file, then position within file.
     *
     * Directory just opened invariant
     * 6. File section is same as the file.
     */

    assert (pFD != NULL && pFD->magic == FD_MAG && pFD->inList != 0); /* 1 */
    assert (pFD->pVDList != NULL &&				      /* 2 */
	    pFD->pVDList->magic == VD_LIST_MAG);
    assert (pFD->pVDList->pVolDesc != NULL &&			      /* 3 */
	    pFD->pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (IF_A_THEN_B (pFD->FCEOF != 0,			      /* 4 */
			 pFD->FCDAbsPos == pFD->FSize));
    assert (IF_A_THEN_B (pFD->FCEOF == 0,			      /* 5 */
			 pFD->FCDAbsPos < pFD->FSize));
    assert (pFD->FCSAbsOff == 0 && pFD->FCSSize == pFD->FSize);	      /* 6 */

    /* Return succsss */

    return OK;
    }

/***************************************************************************
*
* cdromFsFillFDForFile - fill T_CDROM_FILE for file (from file's dir record).
*
* At the beginning, pFD points to FD, which contains description of file
* parent directory, and exact file's entry as encounted over
* internal cdromFsIoctl readDir calls.
* This routine fill in the fields of T_CDROM_FILE structure, pointed by <pFD>,
* for file, exchanging its previous content.
*
* RETURNS: OK or ERROR.
*
* ERRNO: S_memLib_NOT_ENOUGH_MEMORY
*/

LOCAL STATUS cdromFsFillFDForFile
    (
    T_CDROMFS_VD_LST_ID pVDList,	/* ptr to vol desc list */
    T_CDROM_FILE_ID	pFD		/* FD to fill, containing parent */
					/* directory description currently */
    )
    {
    T_CDROM_FILE   workFD;
    u_short	   EARSize;
    u_char *	   pDirRec;
    u_long	   dirRecsTotSize;	/* all file's dir records total size */
    u_long	   numLBToRead;		/* Number LB to read to read all */
					/* directory entries of the file */
    u_long	   dirLBIndex;		/* LBs preceding the current position */

    assert (pVDList != NULL);
    assert (pVDList->magic == VD_LIST_MAG);
    assert (pFD != NULL);
    assert ( (*(pFD->FCDirRecPtr + ISO_DIR_REC_FLAGS) & DRF_DIRECTORY) == 0);

    /*
     * SUm total file size in dirRecsTotSize from file's dir records
     */

    /* for return to current state, let store pFD */

    workFD = *pFD;

    /* Sum all records */

    dirRecsTotSize = 0;		/* SPR#80396 */

    do
	{
	dirRecsTotSize += *(pFD->FCDirRecPtr); /* SPR#80396 */
	}
    while (cdromFsSkipDirRec (pFD, DRF_LAST_REC) == OK);

    /* (restore FD) initial state to pFD from workFD */

    workFD.sectBuf.startSecNum = pFD->sectBuf.startSecNum;
    workFD.sectBuf.numSects = pFD->sectBuf.numSects;
    *pFD = workFD;

    /* Compute read-ahead to read all directory records of the file */

    numLBToRead = ROUND_UP ((pFD->FCDirRecAbsOff & (pFD->pVDList->LBSize - 1)) +
			    dirRecsTotSize, pFD->pVDList->LBSize) /
	pFD->pVDList->LBSize;

    /* Read the first directory record of the file */

    dirLBIndex = pFD->FCDirRecAbsOff / pFD->pVDList->LBSize;

    pFD->FCDirRecPtr
	= cdromFsGetLB ((*pFD).pVDList,
			pFD->FCDirFirstRecLB + dirLBIndex,
			numLBToRead, &(pFD->sectBuf));

    if (pFD->FCDirRecPtr == NULL)
        return ERROR;

    pFD->FCDirRecPtr += pFD->FCDirRecAbsOff & (pFD->pVDList->LBSize - 1);

    /*
     * Initialize FD for file.
     */

    /* ptr to first file's dir record */

    pDirRec		= pFD->FCDirRecPtr;

    /* init workFD */

    bzero (&workFD, sizeof(workFD));
    workFD.sectBuf = pFD->sectBuf;

    workFD.FRecords = KHEAP_ALLOC (dirRecsTotSize);

    if (workFD.FRecords == NULL)
	return ERROR;

    /* fill static file data */

    bcopy (pDirRec + ISO_DIR_REC_FI, workFD.name,
	   *(pDirRec + ISO_DIR_REC_LEN_FI));

    C_BUF_TO_LONG (workFD.FStartLB, pDirRec, ISO_DIR_REC_EXTENT_LOCATION);
    EARSize = *(pDirRec + ISO_DIR_REC_EAR_LEN);

    workFD.FStartLB		+= EARSize;
    workFD.FType		= S_IFREG;

    /* fill FAbsTime field (u_long time format) */

    workFD.FDateTimeLong
	    = cdromFsDirDateTime2Long ((T_FILE_DATE_TIME_ID)
				       (pDirRec + ISO_DIR_REC_DATA_TIME));

    /* parent directory description */

    workFD.parentDirNum		= pFD->DNumInPT;

    /* current file section description */

    C_BUF_TO_LONG (workFD.FCSSize, pDirRec, ISO_DIR_REC_DATA_LEN);

    /*	interleaving */

    workFD.FCSFUSizeLB		= *(pDirRec + ISO_DIR_REC_FU_SIZE);
    workFD.FCSGapSizeLB		= *(pDirRec + ISO_DIR_REC_IGAP_SIZE);
    workFD.FCSInterleaved	= (workFD.FCSFUSizeLB)? CDROM_INTERLEAVED :
							CDROM_NOT_INTERLEAVED;
    /* TBD: read EAR and time and permissions init */

    workFD.FCSAbsOff	= 0;	   /* First file section */
    workFD.FCSStartLB	= workFD.FStartLB;

    /* current data position */

    workFD.FCDAbsPos	= 0;
    workFD.FCEOF	= 0;

    /*
     * fill in file's dir records buffer and count file length
     */

    assert (workFD.FRecords != NULL);
    pDirRec = workFD.FRecords;
    workFD.FSize = 0;

    do
	{
	bcopy (pFD->FCDirRecPtr, pDirRec, *(pFD->FCDirRecPtr));

	C_BUF_TO_LONG (dirRecsTotSize, pDirRec, ISO_DIR_REC_DATA_LEN);
	workFD.FSize += dirRecsTotSize;
	pDirRec += *(pFD->FCDirRecPtr);
	}
    while (cdromFsSkipDirRec (pFD, DRF_LAST_REC) == OK);

    /*
     * Finish initializing workFD
     */

    workFD.FCDirRecPtr	= workFD.FRecords;
    workFD.pVDList	= pVDList;
    workFD.magic	= FD_MAG;

    /* pFD already in FD-list (so comes) */

    workFD.list		= pFD->list;
    workFD.inList	= 1;

    /*
     * Return workFD in *pFD
     */

    *pFD = workFD;

    /*
     * File invariant
     *
     * 1. fd is valid and mounted.
     * 2. fd is on a valid valume.
     * 3. fd has a valid primary or secondary volume descriptor.
     * 4. If end-of-file, then position 1 byte past data in the file.
     * 5. If not end-of-file, then position within file.
     * 6. If not end-of-file, then file section is within the file.
     * 7. If not end-of-file, then position within file section.
     *
     * File just opened invariant
     * 8. File position 0.
     * 9. File section starts at start of file.
     */

    assert (pFD != NULL && pFD->magic == FD_MAG && pFD->inList != 0); /* 1 */
    assert (pFD->pVDList != NULL &&				      /* 2 */
	    pFD->pVDList->magic == VD_LIST_MAG);
    assert (pFD->pVDList->pVolDesc != NULL &&			      /* 3 */
	    pFD->pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (IF_A_THEN_B (pFD->FCEOF != 0,			      /* 4 */
			 pFD->FCDAbsPos == pFD->FSize));
    assert (IF_A_THEN_B (pFD->FCEOF == 0,			      /* 5 */
			 pFD->FCDAbsPos < pFD->FSize));
    assert (IF_A_THEN_B (pFD->FCEOF == 0,			      /* 6 */
			 (pFD->FCSAbsOff + pFD->FCSSize) <= pFD->FSize));
    assert (IF_A_THEN_B (pFD->FCEOF == 0,			      /* 7 */
			 pFD->FCSAbsOff <= pFD->FCDAbsPos &&
			 pFD->FCDAbsPos < (pFD->FCSAbsOff + pFD->FCSSize)));
    assert (pFD->FCDAbsPos == 0);				      /* 8 */
    assert (pFD->FCSAbsOff == 0 && pFD->FCSStartLB == pFD->FStartLB); /* 9 */

    /* Return success */

    return OK;
    }

#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
/***************************************************************************
*
* cdromFsFindDirEntered - find in a Dir Record number of included Records.
*
* This routine find in a Dir Record number of included Records.
* this function can use with Unicode or standard.
*
* INTERNAL
* This is called from only cdromFsDIRGet().
*
* RETURNS: nuber of files/folders in the Record or ERROR if any failed.
*/

LOCAL u_long cdromFsFindDirEntered
    (
    const u_char *	pPTRec,		/* Dir Record */
    u_short		LBSize		/* Size of DIR record */
    )
    {
    u_int		dirOffset;	/* Offset of a directory recotd */
    u_int		dirEntry;	/* Count of directory records */

    if (pPTRec == NULL)
	return (0);

    /*
     * The check below was removed since it fails for the final directory
     * entry in a block.  This happens if a directory is exactly one block
     * long or over one block long.
     *
     * 	if (*(pPTRec + ISO_DIR_REC_FI) != 0)
     * 	    {
     * 	    errnoSet (S_cdromFsLib_INVALID_DIRECTORY_STRUCTURE);
     * 	    return ERROR;
     * 	    }
     */

    dirEntry	= 0;

    for (dirOffset = 0;
	 dirOffset <= LBSize && pPTRec[dirOffset] != 0;
	 dirEntry++)
	dirOffset += pPTRec[dirOffset];

    return (dirEntry);
    }

/***************************************************************************
*
* cdromFsAddRecsToFD - added <numOfRecCopy> record to an existing directory.
*
* This routine copy 'numOfRecCopy' from (RecpPTRec + RecStartOff) to a
* existing directory with position (FdpPTRec + FdStartOff).
* before  this funktion added the record to the directory ckeck if this
* record is already exist.
*
* INTERNAL
* This is called from only cdromFsDIRGet().
*
* RETURNS: number  of files/folders in the Record or ERROR if any failed.
*/

LOCAL u_long cdromFsAddRecsToFD
    (
    u_char *	RecpPTRec,	/* source (alternate) directory PT record */
    u_int	RecStartIndex,	/* start index of first source record */
    u_char *	FdpPTRec,	/* destination (original) dir PT record  */
    u_int	FdStartIndex,	/* start index for first destination record */
    u_int	numOfRecCopy,	/* number of records to copy */
    u_int	destSize	/* To prevent destination buffer overfurn */
    )
    {
    u_int	RecOffset;	/* Offset in RecpPTRec From which to copy */
    u_int	FdOffset;	/* Offset in RdpPTRec to which to copy */
    int		RecStNum;	/* Loop variable down counter: ResStartIndex */
    int		FdStNum;	/* Loop variable up counter: FdStartIndex */
    int		recCopy;	/* Loop variable down counter: numOfRecCopy */

    if (RecpPTRec == NULL || FdpPTRec == NULL)
	return ERROR;

    /* Determine RecOffset from RecStartIndex */

    RecOffset =0;
    for (RecStNum = RecStartIndex; RecStNum != 0; RecStNum--)
	RecOffset += RecpPTRec[RecOffset + ISO_DIR_REC_REC_LEN];

    /* Copy numOfRecCopy directory recotds from RecpPTRec to FdpPTRec */

    for (recCopy = numOfRecCopy; recCopy != 0; recCopy--)
	{
	/*
	 * Compare destination records versus the source record to copy
	 *
	 * If a destination record matches, replace it with the source record.
	 * If not, add the source record to the end of the destination records.
	 */

	FdOffset = 0;
	for (FdStNum = 0; FdStNum != FdStartIndex; FdStNum++)
	    {
	    if (RecpPTRec[RecOffset + ISO_DIR_REC_REC_LEN] ==
		FdpPTRec[FdOffset + ISO_DIR_REC_REC_LEN] &&
		cdromFsDirEntryCompare
		(RecpPTRec + (RecOffset + ISO_DIR_REC_FI), /* Source (Alt) */
		 FdpPTRec + (FdOffset + ISO_DIR_REC_FI),   /* Destination */
		 RecpPTRec[RecOffset + ISO_DIR_REC_LEN_FI],
		 FdpPTRec[FdOffset + ISO_DIR_REC_LEN_FI],
		 FALSE) == 0)
		{
		FdStartIndex--;	/* Net change 0 after increment */
		break;
		}

/* Original: Replace or append, Allow upCase source (Alternate) match */

	    if (RecpPTRec[RecOffset + ISO_DIR_REC_REC_LEN] ==
		FdpPTRec[FdOffset + ISO_DIR_REC_REC_LEN] &&
		cdromFsDirEntryCompare
		(RecpPTRec + (RecOffset + ISO_DIR_REC_FI), /* Source (Alt) */
		 FdpPTRec + (FdOffset + ISO_DIR_REC_FI),   /* Destination */
		 RecpPTRec[RecOffset + ISO_DIR_REC_LEN_FI],
		 FdpPTRec[FdOffset + ISO_DIR_REC_LEN_FI],
		 TRUE) == 0)
		{
		/* Replace source with destination */

		FdStartIndex--;	/* Net change 0 after increment */
		break;
		}

	    /* Not a match.  Go on to the next destination directory entry */

	    FdOffset += FdpPTRec[FdOffset + ISO_DIR_REC_REC_LEN];
	    }

	/*
	 * Does the new desitination entry overflow the logical block?
	 *
	 * If a match, it always fits.
	 */

	if ((FdOffset + RecpPTRec[RecOffset + ISO_DIR_REC_REC_LEN]) <= destSize)
	    {			/* Yes */

	    /*
	     * Match: Replace destination directory entry
	     * or No match: Append to end of destination directory entries.
	     */

	    memcpy ((FdpPTRec + FdOffset), (RecpPTRec + RecOffset),
		    RecpPTRec[RecOffset + ISO_DIR_REC_REC_LEN]);

	    /* Increment count of destination directory entriess. */

	    FdStartIndex++;
	    }

	/* Advance source directory entry */

	RecOffset += RecpPTRec[RecOffset + ISO_DIR_REC_REC_LEN];
	}

    return (FdStartIndex);
    }
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */

/***************************************************************************
*
* cdromFsStrUpcaseCmp - compare two strings uppercasing the first one
*
* This routine compares two strings uppercasing the first one.  It is like
* strcasecmp() except it uppercases only the first string.
*
* RETURNS: < 0 if <name> < <string>, 0 if <name> == <string>, or > 0 if
* <name> > <string>
*/

LOCAL int cdromFsStrUpcaseCmp
    (
    const u_char * string1,	 /* string upcased */
    const u_char * string2	 /* string not upcased */
    )
    {
    int		index = 0;	 /* Index into string1 and string2 */
    u_char	string1Char;	 /* Current character from string1 */

    /* Do comparison */

    index = 0;

    for ( ;; )
	{
	/* The next line is the only difference between the varients. */

	string1Char = toupper (string1[index]);

	/* Loop continue condition */

	if (!(string1Char == string2[index]))
	    break;

	/* Loop body */

	if (string1Char == '\0')
	    return (0);

	/* Loop iterartion */

	index++;
	}

    return (string1Char - string2[index]);
    }

/***************************************************************************
*
* cdromFsFindFileInDir - to find file in given directory.
*
* This routine searches directory, described by <pFD> for name <name>.
* If <name> includes version number (xxx{;ver num}), it's considered
* as absolute file name, If no version supplied (xx[;]),
* routine searches directory for last file version.
* If file found, cdromFsFillFDForFile() is called, to refill
* <pFD> fields for file.
*
* INTERNAL
* Upcases parameter name.
* Changes pPTRec.
*
* RETURNS: OK if file found and <pFD> refilled, or ERROR.
*/

LOCAL STATUS cdromFsFindFileInDir
    (
    T_CDROMFS_VD_LST_ID pVDList,       /* ptr to volume descriptor list */
    T_CDROM_FILE_ID	pFD,	       /* cdrom file descriptor ID */
    const u_char *	name,	       /* file name */
    u_char *		pPTRec,	       /* ptr to path table record */
    u_int		dirRecNumInPT  /* dir record no. in path table */
    )
    {
    DIR		   dir;
    BOOL	   absName = FALSE;
    T_CDROM_FILE   bufFD;
    char *	   pChar;
    char	   found;	     /* -1: Not found uppercase name, */
				     /* 0: Not found, don't uppercase name*/
				     /* 1: Found */
    u_long	   dirSizeLB;	     /* Size of the directory in LBs */
    u_long	   dirLBIndex;	     /* LBs preceding the current position */
    u_long	   dirRemLB;	     /* Remaining LB in the directory */

    assert (pVDList != NULL);
    assert (pFD != NULL);
    assert (name != NULL);

    DBG_MSG(300)("%d. name = %s\n", __LINE__, name);

    /* what is the name, - absolute or to find last version? */

    pChar = strchr (name, SEMICOL);

    if (pChar != NULL)
	{
	if (0 != isdigit ((int)*(pChar + 1)))
	    absName = TRUE;
	else
	    *(pChar) = EOS;
	}

    found = 0;			     /* Not found, Don't uppercase name */

retry:
    while (cdromFsDirRead(pFD, &dir) == OK)
	{
	int compRes;

	/* truncate current name in case last version search */

	if (!absName)
	    {
	    pChar = strchr (dir.dd_dirent.d_name, SEMICOL);
	    if (pChar != NULL)
		*pChar = EOS;
	    }

	compRes = (found == (char)(-1)
		   ? cdromFsStrUpcaseCmp (name, dir.dd_dirent.d_name)
		   : strcmp (name, dir.dd_dirent.d_name) );

	/* names in dir are sorted lexicographically */

#if 0
	/* 
	 * Leave this out.  I have a CD that sorts both the ISO and Joliet
	 * directories in ISO order.  This violates the Joliet standard.  If
	 * this is included, some files on that CD can not be opened via
	 * Joliet since the Joliet directory contains some uppercase names
	 * after lowercase names.  If this is left out, it works.
	 *
	 * Others might have this problem too.  Therefore, leave this out.
	 */
		    
	if (!absName && compRes < 0)
	    break;
#endif

	/* any version of file found */
	if (compRes == 0)
	    {
	    found = 1;		     /* Found */

	    /* if requested version */

	    if (absName)
		return (cdromFsFillFDForFile (pVDList, pFD));

	    bufFD = *pFD;	/* safe found */
	    }
	}	/* while */

    if (found == 0)
	{
	/* case sensitive not found */

	if (cdromFsFillFDForDir (pVDList, pFD, pPTRec, dirRecNumInPT) == ERROR)
	    return ERROR;

	found = (char)(-1);	/* Not found, Uppercase name */

	/* Unicode? */

	if (pVDList->uniCodeLev == 0)
	    {			/* No */
	    /* Do case insensitive comparison */
	    goto retry;
	    }
	}

    if (found == (char)(-1))
	return ERROR;	/* Neither case sensitive nor insensitive found */

    /* (restore FD) return to a last found version (From bufFD to pFD) */

    bufFD.sectBuf.startSecNum = pFD->sectBuf.startSecNum;
    bufFD.sectBuf.numSects = pFD->sectBuf.numSects;
    *pFD = bufFD;

    /* Compute read-ahead to read the remaining directory records */

    dirSizeLB = ROUND_UP (pFD->FSize, pFD->pVDList->LBSize) /
	pFD->pVDList->LBSize;

    dirLBIndex = pFD->FCDirRecAbsOff / pFD->pVDList->LBSize;

    dirRemLB = dirSizeLB - dirLBIndex;

    /* Read the first directory record of the file */

    pFD->FCDirRecPtr
	= cdromFsGetLB ((*pFD).pVDList,
			pFD->FCDirFirstRecLB + dirLBIndex,
			dirRemLB, &(pFD->sectBuf));

    if (pFD->FCDirRecPtr == NULL)
        return ERROR;

    pFD->FCDirRecPtr += pFD->FCDirRecAbsOff & (pFD->pVDList->LBSize - 1);

    return (cdromFsFillFDForFile (pVDList, pFD));
    }

/***************************************************************************
*
* cdromFsFilenameLength - get the length of a file name
*
* This routine gets the lenfth a file name from a path <name>.  It is
* similar to strlen().  However, <name> can be terminated by a forward
* slash (/), a backward slash (\\), or a NULL.
*
* RETURNS: length
*
*/

LOCAL int cdromFsFilenameLength
    (
    const u_char * name		 /* directory name from path */
    )
    {
    int		nameIndex;	 /* Index into name */
    u_char	nameChar;	 /* Current character fro */
    

    for (nameIndex = 0; ; nameIndex++)
	{
	nameChar = name[nameIndex];

	if (nameChar == '/' || nameChar == '\\' || nameChar == '\0')
	    break;
	}

    return (nameIndex);
    }

/***************************************************************************
*
* cdromFsFilenameCompare - compare a file name with a string
*
* This routine compares a file name from a path <name> with a directory
* entry or path table entry <string> of length <stringLen>.  It is similar to
* strncmp().  However, <name> can be terminated by a forward slash (/), a
* backward slash (\\), or a NULL.  <string> can be terminated by a NUL or
* by the length count.  The comparision up cases <name> but not <string>
* if <upCase> is true.
*
* RETURNS: < 0 if <name> < <string>, 0 if <name> == <string>, or > 0 if
* <name> > <string>
*
* INTERNAL
*
* his implementation assumes that <string> does not contain either a
* forward slash (/) or a backward slash (\\).
*/

LOCAL int cdromFsFilenameCompare
    (
    const u_char * name,	 /* directory name from path */
    const u_char * string,	 /* string from path table or directory */
    u_int	   stringLen,	 /* length of <string> */
    BOOL	   upCase	 /* TRUE if upper case <name> */
    )
    {
    int		nameIndex = 0;	 /* Index into name */
    int		stringIndex = 0; /* Index into string */
    int		stringIncrement; /* stringIndex increment */
    u_char	nameChar;	 /* Current character from name */
    
    /* Special handling for . and .. directory entries */

    if (stringLen == 1 && *string == '\0')
	string = ".";

    else if (stringLen == 1 && *string == '\1')
	{
	string = "..";
	stringLen = 2;
	}

    /* Determine increment: 2 if Unicode, or 1 otherwise */

    /* Is <string> Unicode? */

    if (stringLen >= 2 && string[0] == '\0' && (stringLen & 1) == 0)
	{			 /* Yes, Unicode */
	stringIndex = 1;	 /* Skip first character */
	stringIncrement = 2;	 /* Skip later NULs */
	}

    else			 /* No, not Unicode */
	stringIncrement = 1;

    /* Do comparison */

    nameIndex = 0;

    for ( ;; )
	{
	nameChar = name[nameIndex];

	if (upCase)
	    nameChar = toupper (nameChar);

	if (nameChar == '/' || nameChar == '\\')
	    nameChar = '\0';

	/* Loop continue condition */

	if (!(stringIndex < stringLen && nameChar == string[stringIndex]))
	    break;

	/* Loop body */

	if (nameChar == '\0')
	    {
	    return (0);
	    }

	/* Loop iterartion */

	nameIndex++;
	stringIndex += stringIncrement;
	}

    if (stringIndex < stringLen)
	{
	return (nameChar - string[stringIndex]);
	}

    else
	{
	return (nameChar);
	}
    }

#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
/***************************************************************************
*
* cdromFsDirEntryCompare - compare file name of two directory entries
*
* This routine compares the file name of two directory or path table
* entries: <name1> or length <length1> and <name2> or length <length2>.
* It is similar to strncmp().  However, either name can be in ASCII or
* Unicode.  The comparision up cases <name1> but not <name2> if <upCase>
* is true.
*
* RETURNS: < 0 if <name1> < <name2>, 0 if <name1> == <name2>, or > 0 if
* <name1> > <name2>
*/

LOCAL int cdromFsDirEntryCompare
    (
    const u_char * name1,	 /* directory or path table name 1 */
    const u_char * name2,	 /* directory or path table name 2 */
    u_int	   name1Len,	 /* length of <name1> */
    u_int	   name2Len,	 /* length of <name2> */
    BOOL	   upCase	 /* TRUE if upper case <name1> */
    )
    {
    u_int	name1Index = 0;	 /* Index into name1 */
    u_int	name1Increment;	 /* name1Index increment */
    u_int	name2Index = 0;	 /* Index into name2 */
    u_int	name2Increment;	 /* name2Index increment */
    u_char	name1Char;	 /* Current character from name1 */

    /*
     * Special handling for . and .. directory entries
     */

    if (name1Len == 1 && *name1 == '\0')
	name1 = ".";

    else if (name1Len == 1 && *name1 == '\1')
	{
	name1 = "..";
	name1Len = 2;
	}

    if (name2Len == 1 && *name2 == '\0')
	name2 = ".";

    else if (name2Len == 1 && *name2 == '\1')
	{
	name2 = "..";
	name2Len = 2;
	}

    /*
     * Determine increment: 2 if Unicode, or 1 otherwise
     */

    /* Is <name1> Unicode? */

    if (name1Len >= 2 && name1[0] == '\0' && (name1Len & 1) == 0)
	name1Increment = 2;	     /* Yes, Unicode */

    else			     /* No, not Unicode */
	name1Increment = 1;

    /* Is <name2> Unicode? */

    if (name2Len >= 2 && name2[0] == '\0' && (name2Len & 1) == 0)
	name2Increment = 2;	     /* Yes, Unicode */

    else			     /* No, not Unicode */
	name2Increment = 1;

    /*
     * Adjust if only one of them is Unicode or both are Unicode
     */

    /* Is only <name1> Unicode? */

    if (name1Increment > name2Increment)
	name1Index = 1;		     /* Yes, skip first character */

    /* Is only <name2> Unicode? */

    else if (name2Increment > name1Increment)
	name2Index = 1;		     /* Yes, skip first character */

    /* Are both <name1> and <name2> Unicode? */

    else if (name1Increment == 2)
	{			     /* Yes */
	name1Increment = 1;	     /* Compare every byte */
	name2Increment = 1;
	}
	
    /* Do comparison */

    for ( ;; )
	{
	/*
	 * Loop continue condition
	 */

	if (!(name1Index < name1Len && name2Index < name2Len))
	    break;

	/* Compare characters */

	name1Char = name1[name1Index];

	if (upCase)
	    name1Char = toupper (name1Char);

	if (name1Char != name2[name2Index])
	    return (name1Char - name2[name2Index]);

	/* Loop iterartion */

	name1Index += name1Increment;
	name2Index += name2Increment;
	}

    /*
     * All characters matched.  One or both names are exhausted
     */

    /*
     * Are both strings exhausted?
     *
     * >= instead of == for increment 2, starting indes 1
     */

    if (name1Index >= name1Len && name2Index >= name2Len)
	return (0);		/* Yes, match */

    /* Is name1 shorter? */

    if (name1Index == name1Len)
	return (-1);		 /* Yes, name1 < name2 */

    /* name2 is shorter */

    else
	return (1);		 /* name1 > name2 */
    }
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */

/***************************************************************************
*
* cdromFsFindDirOnLevel - find directory within given PT dir hierarchy level.
*
* This routine trys to find <name> within <dirLev>
* PT dir hierarchy level, that have parent dir number <parDirNum>.
* <pPT> points to PT buffer.
* In <pPTRec> will be returned ptr to found PT record (if will).
*
* RETURNS: record number of path table record <*ppRecord> or 0 if not found.
*/

LOCAL int cdromFsFindDirOnLevel
    (
    T_CDROMFS_VD_LST_ID pVDList,   /* ptr to volume descriptor list */
    const u_char *      name,	   /* dir name to search for */
    u_char *	        pPTBuf,	   /* PT buffer */
    u_int	        parDirNum, /* Parent directory (Path found so far) */
    u_int *	        pPathLev,  /* Called: level of <name>\'s parent */
				   /* Return: level of <name> within path */
    u_char **	        ppRecord   /* Called: path table of <name>\'s parent */
				   /* Return: path table of <name> */
    )
    {
    u_char *	pPT;		    /* Path table entry of parent of name */
    int		offset;		    /* abs offset from PT start */
    u_char *    pUpCaseName = NULL; /* ptr to upper case name found */
    u_short	recNum;		    /* current record number */
    u_short	upCaseRecNum = 0;   /* record num of upper case name found */
    u_short	curRecParent;	    /* current record's parent record number */
    u_short	nameLen;	    /* <name> length */


    /* Overflowed the path table? */

    if (*pPathLev >= CDROM_MAX_DIR_LEV)
	return (0);

    /*
     * let us path = "/d0/d1/---[/fname]"
     * first path name <d0> lays on zero path level, but on second directory
     * hierarchy level, so if Level is dir hierarchy level, on which
     * lays <name>, Level = <pPathLev>+2, and therefore <pPathLev> may
     * be used for encounting  dir hierarchy levels' bounds arrays.
     */

    nameLen = cdromFsFilenameLength (name);

    /*
     * Special handling for /, \, . and ..
     *
     * / or |: nameLeng == 0, Treat as current directory.
     * .: Current dirctory, Stay on same level.
     * ..: Parent directory, Go up one level.
     */

    if (nameLen == 0 || (nameLen == 1 && name[0] == '.') )
	/* parDirNum, *pPathLev, and *ppRecord do not change */
	return (parDirNum);

    else if (nameLen == 2 && name[0] == '.' && name[1] == '.')
	{
	/* Decrease *pPathLev and return parent of parDirNum */

	/*
	 * Root or one level down? 
	 *
	 * Note, parent of root is the root.
	 */

	if (*pPathLev <= 1)
	    {
	    *pPathLev = 0;
	    *ppRecord = pPTBuf;
	    return (1);
	    }

	/* Decrease level */

	(*pPathLev)--;

	/* Set to parent path table number */

	PT_PARENT_REC (parDirNum, *ppRecord);

	/* Find parent path table */

	/* Array uses root = 1, *pPathLev uses root = 0 */

	offset = pVDList->dirLevBordersOff[*pPathLev-1];
	pPT = pPTBuf + offset;

	recNum = ( (*pPathLev == 1)
		   ? 2
		   /* Array uses root = 1, *pPathLev uses root = 0 */

		   : pVDList->dirLevLastRecNum[*pPathLev-2] + 1 );

	assert (recNum <= parDirNum);
	assert (parDirNum <= pVDList->dirLevLastRecNum[*pPathLev-1]);

	for (; recNum != parDirNum;
	     recNum ++,
		 offset = cdromFsNextPTRec (&pPT, offset, pVDList->PTSize))
	    ;

	/* Return results */

	*ppRecord = pPT;

	return (parDirNum);
	}

    /* Search the path table for the first component of name */

    offset = pVDList->dirLevBordersOff[ *pPathLev ];
    pPT = pPTBuf + offset;
    recNum = ( (*pPathLev == 0)	   /* *pPathLev == level of parent */
	       ? 2		   /* Start of level 1 */
	       :		   /* Start of level *pPathLev + 1 */
	       pVDList->dirLevLastRecNum[ *pPathLev -1 ] + 1 );

    for (; recNum <= pVDList->dirLevLastRecNum[ *pPathLev ];
	 recNum ++, offset = cdromFsNextPTRec (&pPT, offset, pVDList->PTSize))
	{
	int	compRes;	/* strncmp result */
	u_int	asciiDirLen;	/* Length of path table directory in ASCII */

	PT_PARENT_REC (curRecParent, pPT);

	/* Determine length of path table directory name in ACSII */

	asciiDirLen = *pPT;

	if (asciiDirLen == 1 && (pPT + ISO_PT_REC_DI)[0] == '\0')
	    asciiDirLen = 1;

	else if (asciiDirLen == 1 && (pPT + ISO_PT_REC_DI)[0] == '\1')
	    asciiDirLen = 2;

	else if (asciiDirLen >= 2 && (pPT + ISO_PT_REC_DI)[0] == '\0' &&
		 (asciiDirLen & 1) == 0)
	    asciiDirLen /= 2;

	/* Quick equality check: Same parent and length */

	if (curRecParent != parDirNum || nameLen != asciiDirLen)
	    continue;

	compRes = cdromFsFilenameCompare (name, pPT + ISO_PT_REC_DI, *pPT,
					  FALSE);

	if (compRes == 0)
	    {
	    (*pPathLev)++;
	    *ppRecord = pPT;
	    return (recNum);
	    }

	else if (cdromFsFilenameCompare (name, pPT + ISO_PT_REC_DI, *pPT,
					 TRUE) == 0)
	    {
	    pUpCaseName = pPT;
	    upCaseRecNum = recNum;
	    }
#if 0
	/* 
	 * Leave this out.  I have a CD that sorts both the ISO and Joliet
	 * directories in ISO order.  This violates the Joliet standard.  If
	 * this is included, some files on that CD can not be opened via
	 * Joliet since the Joliet directory contains some uppercase names
	 * after lowercase names.  If this is left out, it works.
	 *
	 * Others might have this problem too.  Therefore, leave this out.
	 */
		    
	else if (compRes < 0)	/* PT records are sorted by name increasing */
	    {
	    break;
	    }
#endif
	}

    if (pUpCaseName == NULL)	/* not found */
	{
	return 0;
	}

    /* name found in upper case only */

    (*pPathLev)++;
    *ppRecord = pUpCaseName;

    return (upCaseRecNum);
    }

#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
/***************************************************************************
*
* cdromFsDirEntriesOtherVDAdd - add dir entries from other volume descriptors
*
* This routine adds directory entries from other volume desctiptors to the
* directory of the current volume descriptor.  Thus directory entreis from
* all volume descriptos show up in the directory of the current volume
* descriptor.
*
* INTERNAL
* This routine was derived from cdromFsFindPathInDIrHier().
*
* RETURNS: N/A
*/

LOCAL STATUS cdromFsDirEntriesOtherVDAdd
    (
    T_CDROMFS_VD_LST_ID pVDList,     /* ptr to volume desc list */
    const u_char *	path,	     /* path */
    T_CDROM_FILE_ID	pFD	     /* FD to fill if full path found */
    )
    {
    int		   curPathLev;	     /* Level being parsed (0 - MAX-1) */
    int		   parDirNum;	     /* Parent of curPathLev */
    u_char *	   pPT;
    u_char *	   pPTRec;
    const u_char * nVDpath;	     /* Copy of path used in inner loop */

    u_int	VDInList;	     /* Down counter */

    u_short	EARSize;
    int		nrVDList;

    VDInList = lstCount (&(pVDList->pVolDesc->VDList));

    pFD->pMultDir = KHEAP_ALLOC (VDInList * sizeof(u_long));

    if (pFD->pMultDir == NULL)
	return (ERROR);

    bzero (pFD->pMultDir, VDInList * sizeof(u_long));

    VDInList--;	   /* First VD already checked */

    for (nrVDList = 0; VDInList != 0; VDInList--)
	{
	pVDList = (T_CDROMFS_VD_LST_ID) lstNext ((NODE *)pVDList);

	if (pVDList == (T_CDROMFS_VD_LST_ID) NULL)
	    break;

	nVDpath = path;

	pPT = cdromFsPTGet (pVDList, NULL);

	if (pPT == (const u_char *) NULL)
	    break;

	for (curPathLev = 0, parDirNum = 1, pPTRec = pPT; *nVDpath != '\0';
	     nVDpath += cdromFsFilenameLength (nVDpath) + 1)
	    {
	    parDirNum = cdromFsFindDirOnLevel (pVDList, nVDpath, pPT, parDirNum,
					       &curPathLev, &pPTRec);

	    if (parDirNum == 0)	/* last name not found */
		{
		curPathLev++;
		break;
		}
	    }

	/* Directory found, i.e. no unmatched path components? */

	if (*nVDpath == '\0')
	    {	   /* Found */
	    C_BUF_TO_LONG (pFD->pMultDir[nrVDList], pPTRec,
			   ISO_PT_REC_EXTENT_LOCATION);
	    EARSize = *(pPTRec + ISO_PT_REC_EAR_LEN);
	    pFD->pMultDir[nrVDList] += EARSize;
	    nrVDList++;
	    }
	}

    /* Were any paths found? */

    if (nrVDList != 0)
	{
	/* Yes, add terminator (last entree must be a 0) */

	(u_long)pFD->pMultDir[nrVDList] = 0;

	pFD->nrMultDir = nrVDList;
	}
    else
	{
	/* no entree found then free pointer */

	KHEAP_FREE (pFD->pMultDir);
	pFD->pMultDir = 0;
	pFD->nrMultDir = 0;
	}

    return (OK);
    }
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */

/***************************************************************************
*
* cdromFsFindPathInDirHierar - find file/directory within given dir hierarchy.
*
* This routine tries to find <path> within given VD dir hierarchy.
* and fill in T_CDROM_FILE structure.
* Levels in path have to be split by '\' or '/'.
*
* RETURNS: OK or ERROR if path not found.
*/

LOCAL STATUS cdromFsFindPathInDirHierar
    (
    T_CDROMFS_VD_LST_ID pVDList,     /* ptr to volume desc list */
    const u_char *	path,	     /* path */
    T_CDROM_FILE_ID	pFD,	     /* FD to fill if full path found */
    int			options	     /* not used currently */
    )
    {
    int		   curPathLev;	     /* Level being parsed (0 - MAX-1) */
    int		   parDirNum;	     /* Parent of curPathLev */
    u_char *	   pPT;		     /* Start of path table */
    u_char *	   pPTRec;	     /* Parent of curPathLev */
    const u_char * nVDpath;
    STATUS	   retStat = ERROR;  /* Return value */
    
    assert (pVDList != NULL);
    assert (path != NULL);
    assert (pFD != NULL);

    pPT = cdromFsPTGet (pVDList, NULL);

    if (pPT == NULL)
        return(ERROR);

    nVDpath = path;		/* save Path pointer */

    for (curPathLev = 0, parDirNum = 1, pPTRec = pPT;
	 *path != '\0';
	 path += cdromFsFilenameLength (path) + 1)
	{
	parDirNum = cdromFsFindDirOnLevel (pVDList, path, pPT, parDirNum,
					   &curPathLev, &pPTRec);

	if (parDirNum == 0)	/* last name not found */
	    {
	    curPathLev++;
	    break;
	    }
	
#ifndef	NDEBUG
	if (curPathLev == 0)
	    {
	    assert (parDirNum == 1);
	    assert (pPTRec == pPT);
	    }
	else if (curPathLev == 1)
	    {
	    assert (parDirNum > 1);
	    assert (parDirNum <= pVDList->dirLevLastRecNum[curPathLev - 1]);
	    assert (pPTRec >= pPT + pVDList->dirLevBordersOff[curPathLev - 1]);
	    }
	else
	    {
	    assert (parDirNum > pVDList->dirLevLastRecNum[curPathLev - 2]);
	    assert (parDirNum <= pVDList->dirLevLastRecNum[curPathLev - 1]);
	    assert (pPTRec >= pPT + pVDList->dirLevBordersOff[curPathLev - 1]);
	    }
#endif /* !NDEBUG */
	}

    /* Directory found, i.e. no unmatched path components? */

    if (*path == '\0')
	{			     /* Yes, directory found */
	/* Fill FD for directory */

	retStat = cdromFsFillFDForDir (pVDList, pFD, pPTRec, parDirNum);

#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
	/* Add dir entries from other volume descriptors to the directory */

	if (pVDList->pVolDesc->DIRMode != 0 &&
	    lstCount (&(pVDList->pVolDesc->VDList)) > 1)
	    retStat = cdromFsDirEntriesOtherVDAdd (pVDList, nVDpath, pFD);
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */
	}

    /* File not found, i.e. only one unmatched path compoent? */

    else if (path [cdromFsFilenameLength (path)] == '\0')
	{			     /* Yes, file not found */
	/* Fill FD for parent directory, i.e. last directory matched */

	retStat = cdromFsFillFDForDir (pVDList, pFD, pPTRec, parDirNum);

	/* Search for file in directory */

	if (retStat != ERROR)
	    retStat = cdromFsFindFileInDir (pVDList, pFD, path, pPTRec,
					    parDirNum);

	}

    /*
     * Directory not found, i.e. more than one unmatched path component
     */

    else
	{
	/* Fall through and return ERROR */
	}

    return (retStat);
    }

/***************************************************************************
*
* cdromFsFindPath - find file/directory on given volume.
*
* This routine trys to find <path> within all volume
* primary/supplementary directory hierarcies and creates and fills in
* T_CDROM_FILE structure for following accsess.
* Levels in path have to be split by '\' or '/'.
*
* RETURNS: T_CDROM_FILE_ID or NULL if any error encounted.
*
* ERRNO: S_cdromFsLib_MAX_DIR_LEV_OVERFLOW,
* S_cdromFsLib_NO_SUCH_FILE_OR_DIRECTORY,
* S_cdromFsLib_INVALID_PATH_STRING.
*/

LOCAL T_CDROM_FILE_ID cdromFsFindPath
    (
    CDROM_VOL_DESC_ID	pVolDesc,   /* ptr to volume descriptor */
    const u_char *	path,	    /* path */
    int options			    /* search options */
    )
    {
    T_CDROMFS_VD_LST_ID pVDList;
    T_CDROM_FILE_ID	pFD;

    assert (pVolDesc != NULL);
    assert (path != NULL);

#ifndef ERR_SET_SELF
    errnoSet (OK);
#else
    errno = OK;
#endif

    /* allocate T_CDROM_FILE structure */

    pFD = cdromFsFDAlloc (pVolDesc);

    if (pFD == NULL)
	return (T_CDROM_FILE_ID)ERROR;


    for (pVDList = (T_CDROMFS_VD_LST_ID) lstFirst (&(pVolDesc->VDList));
	 pVDList != NULL;
	 pVDList = (T_CDROMFS_VD_LST_ID) lstNext ((NODE *)pVDList))
	{
	if (cdromFsFindPathInDirHierar (pVDList, path, pFD, options) == OK)
		return pFD;
	}

    /* file/directory not found */

    cdromFsFDFree (pFD);

    if (errnoGet () == OK)
	errnoSet (S_cdromFsLib_NO_SUCH_FILE_OR_DIRECTORY);

    return (T_CDROM_FILE_ID)ERROR;
    }

/***************************************************************************
*
* cdromFsFillStat - filling of stat structure
*
* This routine transfers data from T_CDROM_FILE structure to stat structure
* defined in <sys/stat.h>
*
* INTERNAL
* Fields not filled in: st_dev, st_ino, st_nlink, st_rdev, st_attrib,
* rexerved1 - reserved6.
*
* Fields filled in: st_mode, st_uid, st_gid, st_size, st_atime, st_mtime,
* st_ctime, st_blksize, st_blocks.
*
* RETURNS: OK or ERROR if it cannot fill stat structure
*
* ERRNO: S_cdromFsLib_INVALID_DIR_REC_STRUCT
*/

LOCAL STATUS cdromFsFillStat
    (
    T_CDROM_FILE_ID fd,			/* File descriptor */
    struct stat * arg			/* Pointer to stat structure */
    )
    {
    u_char *ptr;			/* pointer to LogBlock	     */
    short tmp = 0;			/* to form permission flags  */
    short tmp2 = 0;			/* to convert flags from EAR */

    bzero ((char *) arg, sizeof (*arg)); /* Must zero st_attrib */

    arg->st_blksize = fd->pVDList->LBSize;   /* We read by LogBlocks */

    if (fd->FType == S_IFDIR)	/* In the case of directory */
	{
	if ((ptr = cdromFsDIRGet (fd)) == NULL)
	    return ERROR;
	}
    else
	{
	ptr = fd->FRecords;	/* In the case of File Section */
	}
    arg->st_size = fd->FSize;
    arg->st_blocks = A_PER_B (fd->pVDList->LBSize, fd->FSize);

    /* time fields */

    /*
     * The DOS-FS time fields are not supported from VxWorks 5.2
     * and above, but REQUIRED for 5.1.1 and lower to see valid
     * file dates.
     */

    arg->st_atime = arg->st_mtime = arg->st_ctime = fd->FDateTimeLong;

    /* bits of permissions  processing */

    if (*(ptr + ISO_DIR_REC_FLAGS) & DRF_PROTECT)
	{
	if (*(ptr + ISO_DIR_REC_EAR_LEN) == 0) /* EAR must appear */
	    {
	    errnoSet (S_cdromFsLib_INVALID_DIR_REC_STRUCT);
	    return ERROR;
	    }

	/*
	 * Read ExtAttrRecord
	 *
	 * Note, only 1 LB is needed since ISO_EAR_PERMIT + 1 = 9 is as
	 * far as we reference in the EAR.  If we wanted to read the whole
	 * EAR we would use *(ptr + ISO_DIR_REC_EAR_LEN) instead of 1.
	 */

	ptr = cdromFsGetLB (fd->pVDList,
			    fd->FStartLB - *(ptr + ISO_DIR_REC_EAR_LEN),
			    1, &(fd->sectBuf));
	if (ptr == NULL)
	    return ERROR;

	/*
	 * Now we should transfer permission bits from ExtAttrRec
	 * Sequential reading of two bytes (processor independent)
	 */

	tmp2 = (*(ptr + ISO_EAR_PERMIT) << 8) |
	       *(ptr + ISO_EAR_PERMIT + 1);

	tmp |= (tmp2 & 0x01) ? 0 : S_IROTH;
	tmp |= (tmp2 & 0x04) ? 0 : S_IXOTH;
	tmp |= (tmp2 & 0x10) ? 0 : S_IRUSR;
	tmp |= (tmp2 & 0x40) ? 0 : S_IXUSR;
	tmp |= (tmp2 & 0x100) ? 0 : S_IRGRP;
	tmp |= (tmp2 & 0x400) ? 0 : S_IXGRP;
	tmp |= (tmp2 & 0x1000) ? 0 : S_IROTH;
	tmp |= (tmp2 & 0x4000) ? 0 : S_IXOTH;

	/* Fill in fields other than st_mode */

	C_BUF_TO_SHORT (arg->st_uid, ptr, ISO_EAR_ONER);
	C_BUF_TO_SHORT (arg->st_gid, ptr, ISO_EAR_GROUPE);
	}

    else
	{
	/* Every user has rights to read and execute */

	tmp = S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | /* SPR#78454 */
	      S_IXGRP | S_IROTH | S_IXOTH;
	}
    arg->st_mode = fd->FType | tmp;		/* not fd->FDType */
    return OK;
    }

#if 0			/* NOT USED until record format files supported */
/***************************************************************************
*
* cdromFsCountMdu - counts current position offset in MDU
*
* This function counts only one value contained in a file descriptor of
* cdromFs system - FCDOffInMDU. For this purpose reading of the file itself
* is necessary (sequential, record after record). It is assumed that
* absolute position of file pointer is written in the fd, and the previous
* file pointer position is the second parametr
* NOW WE DON'T SUPPORT RECORD STRUCTURES IN FILES.
*
* RETURNS: OK or ERROR
*/

LOCAL STATUS cdromFsCountMdu
    (
    T_CDROM_FILE_ID fd,				/* File descriptor	  */
    int prevOffs				/* AbsPos before "seek"	  */
    )
    {
    u_long lowBound;				/*  low bound of a record */

    if (fd->FCDAbsPos >= prevOffs)		    /* Initial settings */
	{
	/* to the beginning of current MDU */

	lowBound = prevOffs - fd->FCDOffInMDU;

	if (fd->FMDUType & CDROM_MDU_TYPE_FIX)
	    lowBound -= 0;  /* fixed length record has only even last byte */

	else if (fd->FMDUType & CDROM_MDU_TYPE_VAR_LE ||
		 fd->FMDUType & CDROM_MDU_TYPE_VAR_BE)
	    lowBound -= 0;			 /* variable-length record */

	else
	    return ERROR;			/* Unknown type of records */
	}
    /*	THAT'S ALL: WE DON'T SUPPORT RECORD STRUCTURES NOW ! */

    return OK;
    }
#endif /* NOT USED until record format files supported */

/***************************************************************************
*
*  cdromFsFillPos - fills some fields in fd after executing "seek"
*
* That's the very simple function. The only thing it implements -
* filling of fields in T_CDROM_FILE structure after changing of
* a file pointer position
*
* RETURNS: OK
*/

LOCAL STATUS cdromFsFillPos
    (
    T_CDROM_FILE_ID fd,	 /* pointer to the file descriptor		  */
    u_char *PrevDirPtr,	 /* pointer to DirRec includes point requested	  */
    short i,		 /* The seq.number of DirRec with requested point */
    int len,		 /* length of all File Sections from 0 to current */
    int NewOffs		 /* the offset (arg from ioctl).It's always < len */
    )
    {
    /*	We know the only File Section, contains the position needed	  */

    fd->FCDirRecPtr = PrevDirPtr;

    /* absolute number of LB, which contains current FileDirRec */

    C_BUF_TO_LONG (fd->FCSStartLB, PrevDirPtr, ISO_DIR_REC_EXTENT_LOCATION);

    /* Section data start LB depends on ExtAttrRec inclusion in FileSect  */

    fd->FCSStartLB += *(PrevDirPtr + ISO_DIR_REC_EAR_LEN);

    C_BUF_TO_LONG (fd->FCSSize, PrevDirPtr, ISO_DIR_REC_DATA_LEN);
    fd->FCSAbsOff = len - fd->FCSSize;
    fd->FCDAbsPos = NewOffs;

    /* MDU (file records structures) are not supported */

    return OK;
    }

/***************************************************************************
*
* cdromFsSkipDirRec - skipping current directory entry
*
* This routine skips all DirRecs belongs to the same directory entry
*
* RETURNS: OK or ERROR
*/

LOCAL STATUS cdromFsSkipDirRec
    (
    T_CDROM_FILE_ID fd,				/* File descriptor	   */
    u_char flags				/* Flags tested in DirRecs */
    )
    {
    u_char last = 0;			  /* NOT the last DirRec for entry */

    if (fd->FCEOF == 1)
	/* If an end of file was found out already */
	return ERROR;

    /* Last directory record of the current entry ? */

    if (((*(fd->FCDirRecPtr + ISO_DIR_REC_FLAGS) & flags) ^ flags) != 0)
	last = 1;      /* The last DirRec for entry */

    /* search for next DirRec */

    if (cdromFsDirBound (fd) == ERROR)	       /* errno is set already */
	return ERROR;

    /* File Section of directory is not finished yet, BUT... */

    return (last ? ERROR : OK);	    /* It depends if the DirRec was last */

    }

/***************************************************************************
*
* cdromFsDirBound - sets new pointers to Dir Record
*
* This routine assigns a new value to pointers to the current directory
* record skipping empty places in logical sector
*
* RETURNS: OK or ERROR
*/

LOCAL STATUS cdromFsDirBound
    (
    T_CDROM_FILE_ID fd	  /* File descriptor */
    )
    /*
     * Hereafter the local definition will be set out. It can be used
     * only inside this function and will be excepted after the function
     * definition end.
     */

#define L_DRLEN * (fd->FCDirRecPtr + ISO_DIR_REC_REC_LEN)

    {
    u_int	 FCDirRecOffInLB; /* current dir rec offset within LB */
    u_long	 FCDirRecIndex;	  /* Relative LB within directory */
    u_long	 FCDirRecLB;	  /* LB containing directory record */
    u_long	 FCDirRecSizeLB;  /* Size of directory in logical blocks */
    u_long	 FCDirRecRemLBs;  /* Remaining logical blocks in directory */

    /* Compute old LB and offset */

    FCDirRecOffInLB = fd->FCDirRecAbsOff & (fd->pVDList->LBSize - 1);

    FCDirRecIndex = fd->FCDirRecAbsOff / fd->pVDList->LBSize;

    FCDirRecSizeLB
	= ROUND_UP (fd->FSize, fd->pVDList->LBSize) / fd->pVDList->LBSize;
 
    /* Advance position */

    fd->FCDirRecAbsOff += L_DRLEN; /* To a new DirRec */
    FCDirRecOffInLB += L_DRLEN;
    fd->FCDirRecPtr += L_DRLEN;	   /* Skip the length of prev. DirRec */

    /* In a new logical block? */
	
    if (FCDirRecOffInLB >= fd->pVDList->LBSize)
	{				/* Yes */
	/* go to a new logical block */

	FCDirRecIndex++;

	FCDirRecOffInLB -= fd->pVDList->LBSize;

	/* Read the new logical block */

	FCDirRecLB = fd->FCDirFirstRecLB + FCDirRecIndex;

	FCDirRecRemLBs = FCDirRecSizeLB - FCDirRecIndex;

	fd->FCDirRecPtr = cdromFsGetLB (fd->pVDList, FCDirRecLB,
					FCDirRecRemLBs, &(fd->sectBuf));
	if (fd->FCDirRecPtr == NULL)
	    return ERROR;

	/* Point into the new logical block */

	fd->FCDirRecPtr += FCDirRecOffInLB;
	}
    /*
     * Comment for else: No, in the same logical block
     * Comment for if: End of DirRecs in a Logical Sector?
     */

    else if (L_DRLEN == 0)
	{				/* Yes */
	short offset;	/* offset in Logical Sector */

	FCDirRecLB = fd->FCDirFirstRecLB + FCDirRecIndex;

	offset = LAST_BITS (FCDirRecLB, fd->pVDList->LBToLSShift) *
		 fd->pVDList->LBSize + FCDirRecOffInLB;

	/* Advance just past the end of current logical sector */

	fd->FCDirRecAbsOff += fd->pVDList->pVolDesc->sectSize - offset;

	FCDirRecIndex += 1 + fd->pVDList->LBToLSShift -
	    LAST_BITS (FCDirRecLB, fd->pVDList->LBToLSShift);

	/* End-of-file? */

	if (fd->FCDirRecAbsOff >= fd->FSize)
	    {				/* Yes */
	    fd->FCEOF = 1;

	    return OK;	    /* It's the first time  */
	    }

	/* Read the first logical block in the next logical sector */

	FCDirRecLB = fd->FCDirFirstRecLB + FCDirRecIndex;

	FCDirRecRemLBs = FCDirRecSizeLB - FCDirRecIndex;

	if ((fd->FCDirRecPtr = cdromFsGetLB (fd->pVDList, FCDirRecLB,
					     FCDirRecRemLBs, &(fd->sectBuf))) ==
	    NULL)
	    return ERROR;

	/* No need to advance fd->FCDirRecPtr since FCDirRecOffInLB = 0 */
	}
    return OK;
#undef L_DRLEN
    }

/***************************************************************************
*
* cdromFsSkipGap - sets pointers to the new current data Logical Block
*
* This routine fixes data connected with new Logical Block found
*
* RETURNS: N/A
*/

LOCAL void cdromFsSkipGap
    (
    T_CDROM_FILE_ID fd,		/* file descriptor	   */
    u_long * fsLb,		/* Relative LB within file section */
    long absPos			/* new abs position	   */
    )
    {
    /* End of FSect ? */

    if (absPos - fd->FCSAbsOff >= fd->FCSSize)
	{				/* Yes */
	/* next file section */

	fd->FCDirRecAbsOff += *(fd->FCDirRecPtr + ISO_DIR_REC_REC_LEN);
	fd->FCSAbsOff += fd->FCSSize;
	fd->FCDirRecPtr += *(fd->FCDirRecPtr + ISO_DIR_REC_REC_LEN);
	C_BUF_TO_LONG (fd->FCSSize, fd->FCDirRecPtr,
			       ISO_DIR_REC_DATA_LEN);

	cdromFsFixFsect (fd);

	*fsLb = 0ul;			/* SPR#80396 */
	}

    /* Interleaved and end of file unit? */

    else if ((fd->FCSInterleaved & CDROM_INTERLEAVED) != 0 &&
	     *fsLb % (fd->FCSFUSizeLB + fd->FCSGapSizeLB) ==
	     fd->FCSFUSizeLB)
	    {				/* End of FUnit */
	    *fsLb += fd->FCSGapSizeLB;	/* Next FUnit   */
	    }

    return;
    }

/***************************************************************************
* cdromFsFixFsect - sets pointers to the new current File Section
*
* This routine fixes data connected with new File Section found
*
* RETURNS: N/A
*/

LOCAL void cdromFsFixFsect
    (
    T_CDROM_FILE_ID fd	 /* cdrom file descriptor id */
    )
    {
    UINT32 place1;			 /* Buffer to read long from DR	 */

    /* new pointer to the New DirRec is already set in fd->FCDirRecPtr */

    memmove (&place1, fd->FCDirRecPtr + ISO_DIR_REC_EXTENT_LOCATION, LEN32);
    fd->FCSStartLB = place1 + *(fd->FCDirRecPtr + ISO_DIR_REC_EAR_LEN);
    memmove (&place1, fd->FCDirRecPtr + ISO_DIR_REC_DATA_LEN, LEN32);

    fd->FCSSize = place1;
    fd->FCSGapSizeLB = *(fd->FCDirRecPtr + ISO_DIR_REC_IGAP_SIZE);
    fd->FCSFUSizeLB = *(fd->FCDirRecPtr + ISO_DIR_REC_FU_SIZE);
    fd->FDType = (*(fd->FCDirRecPtr + ISO_DIR_REC_FLAGS) & DRF_DIRECTORY) ?
		 S_IFDIR : S_IFREG;    /* constants are from io.h */

    return;
    }

/***************************************************************************
*
* cdromFsVolLock - lock volume from mount/unmount
*
* This routine locks the volume from mount/unmount and verifies that the
* volume has not been removed.  It is used to lock the volume by calls
* that fail if the volume has been removed.
*
* Note, the volume semaphore is left acquited if it returns OK.
*
* RETURNS: OK if lock succeeds, or ERROR if any error encounted.
*
* ERRNO: S_cdromFsLib_INVAL_VOL_DESCR,
* S_cdromFsLib_VOL_UNMOUNTED,
* Any errno from semTake().
*/

LOCAL STATUS cdromFsVolLock		   /* SPR#34659 */
    (
    CDROM_VOL_DESC_ID	pVolDesc,	   /* ptr to volume descriptor */
    int			errorValue,        /* To set if unmounted */
    BOOL		mountIfNotMounted  /* Automount if TRUE */
    )
        {
    if ((pVolDesc == NULL) || pVolDesc->magic != VD_SET_MAG ||
	pVolDesc->mDevSem == NULL)
	{
	errnoSet (S_cdromFsLib_INVAL_VOL_DESCR);
	return (ERROR);
	}

    /* private semaphore */

    if (semTake (pVolDesc->mDevSem, WAIT_FOREVER) == ERROR)
	/* leave errno as set by semLib */
	return (ERROR);

    /* check for volume was mounted and has not been changed */

    if ((pVolDesc->pBlkDev->bd_statusChk != NULL) &&
	pVolDesc->pBlkDev->bd_statusChk(pVolDesc->pBlkDev) == ERROR)
	{
	cdromFsVolUnmount (pVolDesc);

	/* Following if will be true due to pVolDesc->unmounted */
	}

    if (pVolDesc->unmounted || pVolDesc->pBlkDev->bd_readyChanged)
	{
	if (!mountIfNotMounted)
	    {
	    semGive (pVolDesc->mDevSem);
	    errnoSet (errorValue);
	    return (ERROR);
	    }
	else if (cdromFsVolMount (pVolDesc) == ERROR)
	    {
	    semGive (pVolDesc->mDevSem);
	    return (ERROR);
	    }
	}

    /* Leave pVolDesc->mSem acquited */

    return (OK);
    }

/***************************************************************************
*
* cdromFsOpen - open file/directory for following access.
*
* This routine tries to find absolute <path> within all volume
* primary/supplementary directory hierarchys and create and fill in
* T_CDROM_FILE structure for following accsess.
* levels in path have to be split by '\' or '/'.
*
* RETURNS: T_CDROM_FILE_ID or ERROR if any error encounted.
*
* ERRNO: S_cdromFsLib_MAX_DIR_LEV_OVERFLOW,
* S_cdromFsLib_NO_SUCH_FILE_OR_DIRECTORY,
* S_cdromFsLib_INVAL_VOL_DESCR,
* S_cdromFsLib_VOL_UNMOUNTED,
* S_cdromFsLib_INVALID_PATH_STRING,
* Any errno from semTake().
*/

LOCAL T_CDROM_FILE_ID cdromFsOpen
    (
    CDROM_VOL_DESC_ID	pVolDesc, /* ptr to volume descriptor */
    const u_char *	path,	  /* absolute path to directory/file to open */
    int			options	  /* spare, not used currently */
    )
    {
    T_CDROM_FILE_ID	openFile; /* Result value */

    if (cdromFsVolLock (pVolDesc, S_cdromFsLib_VOL_UNMOUNTED, TRUE) != OK)
	return (T_CDROM_FILE_ID)ERROR;

    /* Check for invalid path */

    if (path == NULL)
	{
	semGive (pVolDesc->mDevSem);
	errnoSet (S_cdromFsLib_INVALID_PATH_STRING);
	return (T_CDROM_FILE_ID)ERROR;
	}

    /* Open the file */

    openFile = cdromFsFindPath (pVolDesc,  path, options);

    /* All done */

    semGive (pVolDesc->mDevSem);

    return (openFile);
    }

/***************************************************************************
*
* cdromFsClose - close file/directory
*
* This routine deallocates all memory, allocated over opening
* given file/directory and excludes FD from volume FD list.
*
* RETURNS: OK or ERROR if bad FD supplied.
*
* ERRNO: S_cdromFsLib_INVALID_FILE_DESCRIPTOR
*/

LOCAL STATUS cdromFsClose
    (
    T_CDROM_FILE_ID	pFD  /* ptr to cdrom file id */
    )
    {
    if ((pFD == NULL) || pFD->magic != FD_MAG)
	{
	errnoSet (S_cdromFsLib_INVALID_FILE_DESCRIPTOR);
	return ERROR;
	}

    cdromFsFDFree (pFD);

    return OK;
    }

/***************************************************************************
*
* cdromFsReadOnlyError - return error for create/delete/write operations
*
* CD is read-only device.
*
* RETURNS: ERROR.
*
* ERRNO: S_cdromFsLib_READ_ONLY_DEVICE
*/

LOCAL STATUS cdromFsReadOnlyError ()
    {
    errnoSet (S_cdromFsLib_READ_ONLY_DEVICE);
    return ERROR;
    }

/***************************************************************************
*
* cdromFsLabelGet - get disk label
*
* This routine gets the disk label.  It implements ioctl() funciton
* FIOLABELGET.
*
* RETURNS: OK or ERROR
*
* ERRNO: S_cdromFsLib_DEVICE_REMOVED,
* S_cdromFsLib_SEMGIVE_ERROR,
* Any errno from semTake().
*
* NOMANUAL
*/

LOCAL STATUS cdromFsLabelGet
    (
    T_CDROM_FILE_ID	fd,	/* file descriptor*/
    char *		pLabel	/* where to return the label */
    )
    {
    u_char * sectData;		/* for the temp. allocation */

    /* Volume label - in the 1st (relative) sector  */

    sectData = cdromFsGetLB (fd->pVDList,
			    (fd->pVDList->pVolDesc->sectSize /
			     fd->pVDList->LBSize) * fd->pVDList->VDPseudoLBNum,
			     1, NULL );

    if (sectData == NULL)
	{
	semGive (fd->pVDList->pVolDesc->mDevSem); /* No checking */
	return ERROR;
	}

    /*	It's assumed that there's sufficient place pointed by pLabel */

    strncpy (pLabel, sectData + ISO_VD_VOLUME_ID ,
	     ISO_VD_VOLUME_ID_SIZE);
    *(pLabel + ISO_VD_VOLUME_ID_SIZE) = '\0';

    if (semGive (fd->pVDList->pVolDesc->mDevSem) == ERROR)
	{
	errnoSet (S_cdromFsLib_SEMGIVE_ERROR);
	return ERROR;
	}
    return OK;
    }

/***************************************************************************
*
* cdromFsSeek - set position in a file
*
* This routine sets the position in a file.  It implements ioctl()
* functions FIOSEEK and FIOSEEK64.
*
* RETURNS: OK or ERROR
*
* NOMANUAL
*/

LOCAL STATUS cdromFsSeek
    (
    T_CDROM_FILE_ID fd,		/* file descriptor*/
    fsize_t	    posArg	/* position */
    )
    {
    u_long	pos;		/* position truncated to fit */
    u_char *	ptr;		/* ptr to CurDirRec */
    int		save;		/* temp. buf. with position */
    long	len = 0;	/* Sum length of all prev.FileSect */
    UINT32	add;		/* temp. buffer */
    long	i = 0;		/* Number of File Sections tested */

    /* 'Seek' is not defined for directories, 'pos' is not neg.	 */

    if (fd->FType == S_IFDIR)
	{
	return ERROR;
	}

    pos = (u_long) posArg;

    if ((fsize_t) pos != posArg || pos > fd->FSize)
	{
	errnoSet (S_cdromFsLib_INV_ARG_VALUE);
	return ERROR;
	}

    if (pos == fd->FSize)
	{
	fd->FCEOF = 1;

	return OK;
	}
    else
	fd->FCEOF = 0;

    save = fd->FCDAbsPos;

    /*
     * Firstly we should test if it isn't the same LB
     * and if "pos" isn't out of high bound of the File Section
     */

    if (((fd->FCDAbsPos ^ pos) <  fd->pVDList->LBSize) &&
	 (pos < (fd->FCSAbsOff + fd->FCSSize)))
	{				 /* The same logical block */
	fd->FCDAbsPos = pos;
	}

    else	    /* if the new offset needs dir reading */
	{
	ptr = fd->FRecords;
	while (len <= pos)			 /* skipping entry */
	    {
	    memmove (&add, ptr + ISO_DIR_REC_DATA_LEN , LEN32);
	    len += (u_long)add;

	    if ((*(ptr + ISO_DIR_REC_FLAGS) & DRF_LAST_REC) == 0)
		break;				/* The last DirRec */

	    i++;
	    ptr += *(ptr + ISO_DIR_REC_REC_LEN);
	    }

	if (len < pos)		/* the new offset is out of bounds */
	    {
	    if (semGive (fd->pVDList->pVolDesc->mDevSem) == ERROR)
		errnoSet (S_cdromFsLib_SEMGIVE_ERROR);

	    return ERROR;
	    }

	/*
	 * len > pos, 'prev' points the necessary File Section
	 * i - number of the File Section, the offset belongs to
	 */

	cdromFsFillPos (fd, ptr, i, len, pos);
	}

#if 0			/* NOT USED until record format files supported */
    cdromFsCountMdu (fd, save);	 /* new offset in MDU for the pos,*/
#endif /* NOT USED until record format files supported */

    if (semGive (fd->pVDList->pVolDesc->mDevSem) == ERROR)
	{
	errnoSet (S_cdromFsLib_SEMGIVE_ERROR);
	return ERROR;
	}

    return OK;
    }

/***************************************************************************
*
* cdromFsDirSeek - seek a directory stream for readdir()
*
* This routine seeks a directory stream for readdir().  It implements
* rewinddir() and assigning to DIR.dd_cookie.
*
* INTERNAL
* pDir->dd_cookie is interpreted as follows.
* \ml
* \m < 0
* - End of file.
* \m 0
* - Read 0 next.
* \m 1
* - Read the directory entry after 0 next.
* \m Anything else
* - Read the directory entry after that next.
* \me
*
* RETURNS: address of directory entry or NULL on ERROR
*
* NOMANUAL
*/

LOCAL STATUS cdromFsDirSeek	/* SPR#79162 */
    (
    T_CDROM_FILE_ID fd,		/* file descriptor*/
    DIR *	    pDir	/* the open directory */
    )
    {
    /*
     * Directory invariant
     *
     * 1. fd is valid and mounted.
     * 2. fd is on a valid valume.
     * 3. fd has a valid primary or secondary volume descriptor.
     * 4. If end-of-file, then position 1 byte past data in the file.
     * 5. If not end-of-file, then position within file.
     */

    assert (fd != NULL && fd->magic == FD_MAG && fd->inList != 0);     /* 1 */
    assert (fd->pVDList != NULL && fd->pVDList->magic == VD_LIST_MAG); /* 2 */
    assert (fd->pVDList->pVolDesc != NULL &&			       /* 3 */
	    fd->pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (IF_A_THEN_B (fd->FCEOF != 0, fd->FCDAbsPos == fd->FSize)); /* 4 */
    assert (IF_A_THEN_B (fd->FCEOF == 0, fd->FCDAbsPos < fd->FSize));  /* 5 */

    /* Which type of seek? */

    if (pDir->dd_cookie < 0)
	fd->FCEOF = 1;
    else
	{
	fd->FCEOF = 0;

	switch (pDir->dd_cookie)
	    {
	    case 0:			   /* Read directory entry 0 */
		fd->FCDirRecAbsOff = 0;	   /* Read 0 */
		fd->FDType = (u_short) -1; /* Do not skip */
		break;

	    case 1:			   /* Read directory entry after 0 */
		fd->FCDirRecAbsOff = 0;    /* Read 0 */
		fd->FDType = (u_short) 0;  /* Skip */
		break;

	    default:			   /* Read dir entry after cookie */
		fd->FCDirRecAbsOff = pDir->dd_cookie;
		fd->FDType = (u_short) 0;  /* Skip */
		break;
	    }
	}

    /*
     * Directory invariant
     *
     * 1. fd is valid and mounted.
     * 2. fd is on a valid valume.
     * 3. fd has a valid primary or secondary volume descriptor.
     * 4. If end-of-file, then position 1 byte past data in the file.
     * 5. If not end-of-file, then position within file.
     */

    assert (fd != NULL && fd->magic == FD_MAG && fd->inList != 0);     /* 1 */
    assert (fd->pVDList != NULL && fd->pVDList->magic == VD_LIST_MAG); /* 2 */
    assert (fd->pVDList->pVolDesc != NULL &&			       /* 3 */
	    fd->pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (IF_A_THEN_B (fd->FCEOF != 0, fd->FCDAbsPos == fd->FSize)); /* 4 */
    assert (IF_A_THEN_B (fd->FCEOF == 0, fd->FCDAbsPos < fd->FSize));  /* 5 */

    /* Return sucsess */

    return OK;
    }

/***************************************************************************
*
* cdromFsUnicodeStrncpy - copy a possibly Unicode string to an ASCII string
*
* This routine copies from <srcString> to <dstString> converting from
* Unicode to ASCII if needed.  It is similar to strncpy().  However,
* lengths are independently given for both <srcString> and <dstString>.
*
* RETURNS: <dstString>
*/

LOCAL u_char * cdromFsUnicodeStrncpy
    (
    u_char *	   dstString,	/* To string - ASCII */
    size_t	   dstLen,	/* Maximum size of dstString */
    const u_char * srcString,	/* From string - Can be Unicode */
    size_t	   srcLen	/* Maximum size of srcString */
    )
    {
    size_t	srcIndex = 0;	/* Index into srcString */
    size_t	dstIndex = 0;	/* Index into dstString */
    size_t	srcIncrement;	/* srcString Increment */

    /* Determine increment: 2 if Unicode, or 1 otherwise */

    /* Is <string> Unicode? */

    if (srcLen >= 2 && srcString[0] == '\0' && (srcLen & 1) == 0)
	{			 /* Yes, Unicode */
	/* Adjust start and increment for Unicode */

	srcIndex++;
	srcIncrement = 2;	 /* Skip later NULs */

	/* Adjust srcLen so only one length check is needed for loop */

	if (srcLen/2 > dstLen)
	    srcLen = 2*dstLen;
	}

    else			 /* No, not Unicode */
	{
	/* Set increment for ASCII */

	srcIncrement = 1;

	/* Adjust srcLen so only one length check is needed for loop */

	if (srcLen > dstLen)
	    srcLen = dstLen;
	}

    /* Do copy */

    for (; srcIndex < srcLen ;
	 dstIndex++, srcIndex += srcIncrement)
	dstString[dstIndex] = srcString[srcIndex];

    /* Fill remainder, if any, of dstString with NULs */

    for (; dstIndex < dstLen ; dstIndex++)
	dstString[dstIndex] = '\0';

    return (dstString);
    }

/***************************************************************************
*
* cdromFsDirRead - read a directory entry for readdir()
*
* This routine reads a directory entry for readdir().  It implements
* ioctl() function FIOREADDIR.
*
* RETURNS: address of directory entry or NULL on ERROR
*
* NOMANUAL
*/

LOCAL STATUS cdromFsDirRead
    (
    T_CDROM_FILE_ID fd,		/* file descriptor*/
    DIR *	    pDir	/* the open directory */
    )
    {
    u_char * ptr;	       /* temp.pointer to LogBlock */

    /*
     * Directory invariant
     *
     * 1. fd is valid and mounted.
     * 2. fd is on a valid valume.
     * 3. fd has a valid primary or secondary volume descriptor.
     * 4. If end-of-file, then position 1 byte past data in the file.
     * 5. If not end-of-file, then position within file.
     */

    assert (fd != NULL && fd->magic == FD_MAG && fd->inList != 0);     /* 1 */
    assert (fd->pVDList != NULL && fd->pVDList->magic == VD_LIST_MAG); /* 2 */
    assert (fd->pVDList->pVolDesc != NULL &&			       /* 3 */
	    fd->pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (IF_A_THEN_B (fd->FCEOF != 0, fd->FCDAbsPos == fd->FSize)); /* 4 */
    assert (IF_A_THEN_B (fd->FCEOF == 0, fd->FCDAbsPos < fd->FSize));  /* 5 */

    if ((ptr = cdromFsDIRGet (fd)) == NULL)
	{
	/* errno is set already */
	return ERROR;
	}
    else
	fd->FCDirRecPtr
	    = ptr + (fd->FCDirRecAbsOff & (fd->pVDList->LBSize - 1));;

    if (fd->FCEOF == 1)
	{
	return ERROR;
	}

    /* skip current directory entry */

    /*
     * if fd->FDType == (u_short)-1, i.e. the entry is the first
     * in directory, I have to return current point (truly - first
     * point).if not - next
    */

    if (fd->FDType != (u_short)(-1))
	{
	while (cdromFsSkipDirRec (fd, DRF_LAST_REC) == OK)
	    {
	    ; /* While not the last record is found out */
	    }

	if (fd->FCDirRecAbsOff >= fd->FSize)	  /* End of File ? */
	    {
	    fd->FCEOF = 1;

	    /* Update the cookie */

	    pDir->dd_cookie = -1;	   /* EOF */

	    return ERROR;
	    }
	}

    /* Update the cookie */

    if (fd->FCEOF != 0)
	pDir->dd_cookie = -1;			  /* EOF */

    else if (fd->FCDirRecAbsOff == 0)
	pDir->dd_cookie = 1;			  /* Next after record 0 */

    else
	pDir->dd_cookie = fd->FCDirRecAbsOff;	  /* Next after this record */

    /*
     * We have skipped already the last DirRec of previous
     * directory entry. And we do know that we didn't come to
     * the end of file: some DirRec's remain (a new entry)
     */

    /*
     * Prepare for reading the file section refered to by the current
     * directory entry.
     */

    cdromFsFixFsect (fd);

    /* Codes of root and parent directory should be changed	   */

    if (*(fd->FCDirRecPtr + ISO_DIR_REC_LEN_FI) == 1 &&
	*(fd->FCDirRecPtr + ISO_DIR_REC_FI) == '\0')
	{
	pDir->dd_dirent.d_name[0] = '.';	 /* itself */
	pDir->dd_dirent.d_name[1] = EOS;
	}

    else if (*(fd->FCDirRecPtr + ISO_DIR_REC_LEN_FI) == 1 &&
	     *(fd->FCDirRecPtr + ISO_DIR_REC_FI) == '\001')
	{
	pDir->dd_dirent.d_name[0] = '.';     /* parent dir */
	pDir->dd_dirent.d_name[1] = '.';
	pDir->dd_dirent.d_name[2] = EOS;
	}

    else
	{
	/*  We must truncate the name to fit it in the struct DIR  */

	(void) cdromFsUnicodeStrncpy (pDir->dd_dirent.d_name,
				      sizeof (pDir->dd_dirent.d_name) - 1,
				      fd->FCDirRecPtr + ISO_DIR_REC_FI,
				      *(fd->FCDirRecPtr + ISO_DIR_REC_LEN_FI));

	pDir->dd_dirent.d_name[sizeof(pDir->dd_dirent.d_name) - 1] = EOS;
	}

    /*
     * Directory invariant
     *
     * 1. fd is valid and mounted.
     * 2. fd is on a valid valume.
     * 3. fd has a valid primary or secondary volume descriptor.
     * 4. If end-of-file, then position 1 byte past data in the file.
     * 5. If not end-of-file, then position within file.
     */

    assert (fd != NULL && fd->magic == FD_MAG && fd->inList != 0);     /* 1 */
    assert (fd->pVDList != NULL && fd->pVDList->magic == VD_LIST_MAG); /* 2 */
    assert (fd->pVDList->pVolDesc != NULL &&			       /* 3 */
	    fd->pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (IF_A_THEN_B (fd->FCEOF != 0, fd->FCDAbsPos == fd->FSize)); /* 4 */
    assert (IF_A_THEN_B (fd->FCEOF == 0, fd->FCDAbsPos < fd->FSize));  /* 5 */

    /* Return sucsess */

    return OK;
    }

#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
/***************************************************************************
*
* cdromFsTocRead - read the Table Of Contents (TOC) from the disc
*
* This routine reads the table of contents from the disc. It will issue the
* READTOCATIP ioctl call to the block device driver. If this call fails it
* will try to figure out how the disc is organized.
*
* Disc contents for a multisession disc is organised as followed :
* Session 1
* Transisition area containing post gap, lead out, lead in, pre gap = 11550
* blocks give or take 10 blocks.
* Session 2 and higher
* Transisition area containing post gap, lead out, lead in, pre gap = 7050
* blocks give or take 10 blocks.
* Last session
* Lead out area only, 150 blocks.
*
* It will require more time, but the file system will still be able to use
* multisession.
*
* RETURNS: OK or ERROR
*
* NOMANUAL
*/

LOCAL STATUS cdromFsTocRead
    (
    CDROM_VOL_DESC_ID    pVolDesc,
    CDROM_TRACK_RECORD * pCdStatus
    )
    {
    int                            numberOfSessions    = 1;
    UINT32                         sessionStartAddress = 0;
    UINT32                         volumeSpaceSize;
    readTocHeaderType            * pTocHeader;
    readTocSessionDescriptorType * pSessionDescriptor;

#ifdef CDROMFS_MULTI_SESSION_ATAPI_IOCTL /* Ask ATAPI driver for TOC */
    /* get the TOC using the FIOREADTOCINFO ioctl call */

    if ((pVolDesc->pBlkDev->bd_ioctl ( pVolDesc->pBlkDev, FIOREADTOCINFO,
                                       pCdStatus)) != OK)
#endif /* CDROMFS_MULTI_SESSION_ATAPI_IOCTL */
        {
        /* The IOCTL call failed, we have to do it ourself */
        int    discBlocksToRead = 32;
        int    discBlockSize    = pVolDesc->pBlkDev->bd_bytesPerBlk;
        int    discBlockIndex;

        char   cdSignatureString[8];
        BOOL   cdSignatureFound;

        /* Allocate memory for required disc blocks */
        char * pDiscBlocks = KHEAP_ALLOC (discBlocksToRead * discBlockSize);

        DBG_MSG(500)("HAVE TO DISCOVER TOC OURSELF !!!!!\n");

        /* Build up the cdSignatureString */
        cdSignatureString[0] = 1;
        strcpy(&cdSignatureString[1], "CD001");

        sessionStartAddress = 0;

        pTocHeader          = (readTocHeaderType *)pCdStatus->statBuffer;
        pSessionDescriptor
	    = (readTocSessionDescriptorType *)(pCdStatus->statBuffer +
					       sizeof(readTocHeaderType));

        /* Set BOOL to enter for the first session. */
        cdSignatureFound    = TRUE;

        /* Read as long as there are valid sessions on the disc. */
        while (cdSignatureFound)
            {
            /* Clear BOOL, will be overwritten when we find a valid session. */

            cdSignatureFound = FALSE;

	    /* Are we at the end of the disc? */

	    if ((sessionStartAddress + ISO_PVD_BASE_LS)
		>= pVolDesc->pBlkDev->bd_nBlocks)
		{		 /* Yes */
		DBG_MSG(1)("%d. cdromFsTocRead()"
			   " End of disc, numberOfSessions %d\n",
			   __LINE__, numberOfSessions);
		break;
		}

	    /* Fill in the session descriptor */

            pSessionDescriptor->control                = 4; /* default */
            pSessionDescriptor->adr                    = 1; /* default */
            pSessionDescriptor->sessionNumber          = numberOfSessions;

	    *(UINT32 *) (pSessionDescriptor->sessionStartAddress)
		= htonl (sessionStartAddress);

            pSessionDescriptor++;

            /* Read the block containing the PVD. */

            if ((pVolDesc->pBlkDev->bd_blkRd ( pVolDesc->pBlkDev,
                                               sessionStartAddress +
					       ISO_PVD_BASE_LS,
                                               1,
                                               pDiscBlocks)) == OK)
                {
                /* Determine the end of this volume */
                volumeSpaceSize
		    = *(UINT32 *)(pDiscBlocks + ISO_VD_VOL_SPACE_SIZE);

                /* Calculate the possible PVD for the next session. If we are
                in the first session, then adjust for another 4500 blocks (see
                mscd10.pdf document). */

                sessionStartAddress = volumeSpaceSize + 7055;

                if (numberOfSessions == 1)
                    sessionStartAddress += 4500;

		/* Are we at the end of the disc? */

		if ((sessionStartAddress + discBlocksToRead)
		    > pVolDesc->pBlkDev->bd_nBlocks)
		    {		 /* Yes */
		    DBG_MSG(1)("%d. cdromFsTocRead()"
			       " End of disc, numberOfSessions %d\n",
			       __LINE__, numberOfSessions);
		    break;
		    }

                /* Attempt to read enough blocks to overcome the 5 blocks
                jitter */
                if ((pVolDesc->pBlkDev->bd_blkRd ( pVolDesc->pBlkDev,
                                                   sessionStartAddress,
                                                   discBlocksToRead,
                                                   pDiscBlocks)) == OK)
                    {
                    /* We successfully got the blocks from the disc. Now we
                    need to determine if one of the blocks is indeed containing
                    the PVD for the session. */
                    for (discBlockIndex = 0;
                        (discBlockIndex < discBlocksToRead) &&
			     !cdSignatureFound;
                        discBlockIndex++)
                        {
                        /* We need to check if the block does contain the
                        cd identification string. */
                        if (strncmp((char *)(pDiscBlocks +
					     (discBlockIndex * discBlockSize)),
                                    cdSignatureString, 6) == 0)
                            {
                            /* Found the cdSignatureString, calculate the
                            proper sessionStartAddress. */
                            sessionStartAddress += discBlockIndex;
                            sessionStartAddress -= ISO_PVD_BASE_LS;

                            /* Exit loop. */
                            cdSignatureFound = TRUE;
                            }
                        } /* End for */
                    } /* End if bd_blkRd */
                } /* End if bd_blkRd */

            if (cdSignatureFound)
                /* Try again for next session. */
                numberOfSessions++;

            } /* End while */

        /* Last track contains the lead out area info */
        pSessionDescriptor->control                = 4; /* default */
        pSessionDescriptor->adr                    = 1; /* default */
        pSessionDescriptor->sessionNumber          = 0xAA;
        pSessionDescriptor->sessionStartAddress[0]
	    = ((pVolDesc->pBlkDev->bd_nBlocks >> 24) & 0xff);
        pSessionDescriptor->sessionStartAddress[1]
	    = ((pVolDesc->pBlkDev->bd_nBlocks >> 16) & 0xff);
        pSessionDescriptor->sessionStartAddress[2]
	    = ((pVolDesc->pBlkDev->bd_nBlocks >> 8) & 0xff);
        pSessionDescriptor->sessionStartAddress[3]
	    = (pVolDesc->pBlkDev->bd_nBlocks & 0xff);

        /* Update all relevant info in structure */
        pTocHeader->tocDataLength[0]
	    = (((2 + (numberOfSessions * sizeof(readTocSessionDescriptorType)))
		>> 8) & 0xff);
        pTocHeader->tocDataLength[1]
	    = ((2 + (numberOfSessions * sizeof(readTocSessionDescriptorType)))
	       & 0xff);
        pTocHeader->firstSessionNumber = 1;
        pTocHeader->lastSessionNumber  = numberOfSessions;

        KHEAP_FREE (pDiscBlocks);
        }

#ifdef DEBUG
	if (1 <= cdromFsDbg)
	    cdromFsTocPrint (pCdStatus);
#endif

    return(OK);
    }
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */

/***************************************************************************
*
* cdromFsIoctl -  I/O control routine for "cdromFs" file system
*
* This routine performs the subset of control functions defined in ioLib.h
* These functions are possible to be applied to cdromFs file system.
*
* RETURNS: OK, ERROR or the file pointer position (if requested)
*
* ERRNO: S_cdromFsLib_INVALID_FILE_DESCRIPTOR, S_cdromFsLib_VOL_UNMOUNTED,
* S_cdromFsLib_SEMGIVE_ERROR.
*/

LOCAL STATUS cdromFsIoctl
    (
    T_CDROM_FILE_ID fd,		/* file descriptor*/
    int function,		/* an action number */
    int arg			/* special parameter for each function */
    )
    {
    STATUS	retValue;	/* Return value */

    if ((fd == NULL) || (fd->magic != FD_MAG))
	{
	errnoSet (S_cdromFsLib_INVALID_FILE_DESCRIPTOR);
	return ERROR;		/* fd - exists at least ? */
	}

    /* check for volume has not been changed */

    if (cdromFsVolLock (fd->pVDList->pVolDesc,
			S_cdromFsLib_VOL_UNMOUNTED, FALSE) != OK)
	return ERROR;

#ifdef NODEF
    /*
     * TBD: Vlad: You must to make this check, but, may be,
     * not for all FIO-Codes
     */

    if (fd->inList == 0)		/* No valid Volume */
	{
	semGive (fd->pVDList->pVolDesc->mDevSem);
	errnoSet (S_cdromFsLib_VOL_UNMOUNTED);
	return ERROR;
	}
#endif /* NODEF */

    switch (function)
	{
	case FIOGETNAME:
	    strcpy ((u_char *)arg, fd->name);
	    retValue = OK;
	    break;

	case FIOLABELGET:
	    retValue = cdromFsLabelGet (fd, (char *) arg);
	    break;

	case FIOWHERE:		      /* Current position */
	    retValue = fd->FCDAbsPos; /* doesn't return OK or ERROR */
	    break;

	case FIOWHERE64:	      /* Current position (64 bit) */

	    if ((void *) arg == NULL)
		{
		errnoSet (S_cdromFsLib_INV_ARG_VALUE);
		retValue = ERROR;
		break;
		}

	    *(fsize_t *) arg = fd->FCDAbsPos;

	    retValue = OK;
	    break;

	case FIOSEEK:		      /* Setting of current position */

	    if (arg < 0)
		{
		retValue = ERROR; /* the offset is non-negative */
		break;
		}

	    retValue = cdromFsSeek (fd, (fsize_t) arg);
	    break;

	case FIOSEEK64:		/* Setting of current position (64 bit) */

	    if ((void *) arg == NULL)
		{
		errnoSet (S_cdromFsLib_INV_ARG_VALUE);
		retValue = ERROR;
		break;
		}

	    retValue = cdromFsSeek (fd, *(fsize_t *)arg);
	    break;

	case FIONREAD:		/* Number of unread bytes in the file */
	    if ((void *) arg == NULL)
		{
		errnoSet (S_cdromFsLib_INV_ARG_VALUE);
		retValue = ERROR;
		break;
		}

	    *(u_long *) arg = fd->FSize - fd->FCDAbsPos;
	    retValue = OK;
	    break;

	case FIONREAD64:     /* Number of unread bytes in the file (64 bits) */
	    if ((void *) arg == NULL)
		{
		errnoSet (S_cdromFsLib_INV_ARG_VALUE);
		retValue = ERROR;
		break;
		}

	    *(fsize_t *) arg = fd->FSize - fd->FCDAbsPos;
	    retValue = OK;
	    break;

	case FIOREADDIR:	       /* Next directory entry */
	    /* SPR#79162 */
	    /* Seek to directory according to DIR.dd_cookie */

	    retValue = cdromFsDirSeek (fd, (DIR *)arg);

	    if (retValue == ERROR)
		break;

	    /* Read directory entry */

	    retValue = cdromFsDirRead (fd, (DIR *)arg);

	    /* Optionally remove file version number */

            if (retValue != ERROR && fd->pVDList->pVolDesc->StripSemicolon)
                {
                char * ptr;

                ptr = strchr(((DIR *)arg)->dd_dirent.d_name, SEMICOL);
                if (ptr != NULL)
                    *ptr = EOS;
		}

	    break;

	case FIODISKCHANGE:		    /* setting of 'ready change' */

	    retValue = cdromFsReadyChange (fd->pVDList->pVolDesc);
	    break;

	case FIOUNMOUNT:		   /* device unmounting */
	    cdromFsVolUnmount (fd->pVDList->pVolDesc);
	    retValue = OK;
	    break;

	case FIOFSTATGET:		   /* taking of the file status */
	    cdromFsFillStat (fd, (struct stat *)arg);
	    retValue = OK;
	    break;

        case CDROMFS_DIR_MODE_SET:	   /* set PathTable mode */
					   /* Added for Joliet */
	    if (arg > MODE_MAX)
		{
		retValue = ERROR;
		break;
		}

	    fd->pVDList->pVolDesc->DIRMode = arg;
	    cdromFsVolUnmount (fd->pVDList->pVolDesc);
	    retValue = OK;
	    break;

        case CDROMFS_DIR_MODE_GET:	   /* set PathTable mode */
					   /* Added for Joliet */
	    retValue = fd->pVDList->pVolDesc->DIRMode;
	    break;

#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
        case CDROMFS_SESSION_NUMBER_SET:   /* set session number */
					   /* Added for multi-session */
	    if (arg > fd->pVDList->pVolDesc->SesiOnCD)
		{
		errnoSet (S_cdromFsLib_SESSION_NR_NOT_SUPPORTED);
		retValue = ERROR;
		break;
		}

	    /* unmount set the session to default */

	    cdromFsVolUnmount (fd->pVDList->pVolDesc);
	    fd->pVDList->pVolDesc->SesiToRead = arg;
	    retValue = OK;
	    break;

        case CDROMFS_SESSION_NUMBER_GET:     /* get session number */
					     /* Added for multi-session */
            retValue = fd->pVDList->pVolDesc->SesiToRead;
	    break;

        case CDROMFS_MAX_SESSION_NUMBER_GET: /* get max session number */
					     /* Added for multi-session */
            retValue = fd->pVDList->pVolDesc->SesiOnCD;
	    break;
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */

        case CDROMFS_STRIP_SEMICOLON:	   /* Strip semicolon on/off */
            if ( arg == 0 )
                fd->pVDList->pVolDesc->StripSemicolon = FALSE;
            else
                fd->pVDList->pVolDesc->StripSemicolon = TRUE;
	    retValue = OK;
	    break;

        case CDROMFS_GET_VOL_DESC:	   /* Get volume descriptor */
					   /* SPR#78709 */
	    retValue = cdromFsVolDescGet (fd->pVDList, (T_ISO_PVD_SVD_ID) arg);
	    break;

	default:
	    if (fd->pVDList->pVolDesc->pBlkDev->bd_ioctl == NULL)
		{		/* No 'ioctl' function in blk_dev driver */
		retValue = ERROR;
		break;
		}

	    retValue = fd->pVDList->pVolDesc->pBlkDev->bd_ioctl(
						fd->pVDList->pVolDesc->pBlkDev,
						function, arg);
	    break;
	} /* switch */

    	semGive (fd->pVDList->pVolDesc->mDevSem);

	return (retValue);
    }

/***************************************************************************
*
* cdromFsRead - routine for reading data from a CD
*
* This routine reads data from a CD into a buffer provided by user.
*
* RETURNS: 0 - if end of file is found out,
* number of bytes were read - if any,
* ERROR - error reading or access behind an end of file*
*
* ERRNO: S_cdromFsLib_INVALID_FILE_DESCRIPTOR, S_cdromFsLib_SEMGIVE_ERROR,
* S_cdromFsLib_VOL_UNMOUNTED.
*/

LOCAL STATUS cdromFsRead
    (
    int desc,		/* file descriptor */
    u_char * buffer,	/* buffer for data provided by user */
    size_t maxBytes	/* number of bytes to be read */
    )
    {
    T_CDROM_FILE_ID fd = (T_CDROM_FILE_ID) desc;	/* file descriptor */
    u_long rest;		/* number of unread bytes */

    u_long fsPos;		/* Byte position within file section */
    u_long fsLb;		/* Relative LB within file section */
    u_long fsSizeLb;		/* File section size in LBs */
    u_int  FCDOffInLB;		/* offset within current LB */

    u_long absPos;		/* absolute position in the file SPR#78455 */
    u_char * ptr;		/* pointer to file data */
    u_long field;		/* length of current portion within LB */
    u_char flag = 0;		/* flag EOF */

    if ((fd == NULL) || (fd->magic != FD_MAG))
	{
	errnoSet (S_cdromFsLib_INVALID_FILE_DESCRIPTOR);
	return ERROR;  /* fd - exists at least ? */
	}

    /* check for volume has not been changed */

    if (cdromFsVolLock (fd->pVDList->pVolDesc, S_cdromFsLib_VOL_UNMOUNTED,
			FALSE) != OK)
	return ERROR;

    /*
     * File invariant
     *
     * 1. fd is valid and mounted.
     * 2. fd is on a valid valume.
     * 3. fd has a valid primary or secondary volume descriptor.
     * 4. If end-of-file, then position 1 byte past data in the file.
     * 5. If not end-of-file, then position within file.
     * 6. If not end-of-file, then file section is within the file.
     * 7. If not end-of-file, then position within file section.
     */

    assert (fd != NULL && fd->magic == FD_MAG && fd->inList != 0);     /* 1 */
    assert (fd->pVDList != NULL && fd->pVDList->magic == VD_LIST_MAG); /* 2 */
    assert (fd->pVDList->pVolDesc != NULL &&			       /* 3 */
	    fd->pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (IF_A_THEN_B (fd->FCEOF != 0, fd->FCDAbsPos == fd->FSize)); /* 4 */
    assert (IF_A_THEN_B (fd->FCEOF == 0, fd->FCDAbsPos < fd->FSize));  /* 5 */
    assert (IF_A_THEN_B (fd->FCEOF == 0,			       /* 6 */
			 (fd->FCSAbsOff + fd->FCSSize) <= fd->FSize));
    assert (IF_A_THEN_B (fd->FCEOF == 0,			       /* 7 */
			 fd->FCSAbsOff <= fd->FCDAbsPos &&
			 fd->FCDAbsPos < (fd->FCSAbsOff + fd->FCSSize)));

    /* CHeck for end-of-file */

    if (fd->FCEOF == 1)
	{
	semGive (fd->pVDList->pVolDesc->mDevSem);   /* Without checking */
	return 0;					    /* End of File */
	}

    /*
     * Compute fsLb - Relative LB within file section
     *
     * 1. Compute position in file section.
     * 2. Compute logical block for that position.
     * 3. If interleaved, adjust for gaps.
     */

    fsPos = fd->FCDAbsPos - fd->FCSAbsOff;
    fsLb = fsPos / fd->pVDList->LBSize;

    fsSizeLb = ROUND_UP (fd->FCSSize, fd->pVDList->LBSize) / fd->pVDList->LBSize;

    if ((fd->FCSInterleaved & CDROM_INTERLEAVED) != 0)
	{
	u_long fsFu;		/* Relative file unit within file section */

	/* Add to fsLb the number of blocks in the gaps passed so far */

	fsFu = fsLb / fd->FCSFUSizeLB;

	fsLb += fsFu * fd->FCSGapSizeLB;

	/* Add to fsSizeLb the total number of blocks in all gaps */

	fsSizeLb += ((fd->FCSSize - 1) / fd->FCSFUSizeLB) * fd->FCSGapSizeLB;
	}

    /* Adjust maxBytes to end of file if it exceeds the file size */

    if ((fd->FCDAbsPos + maxBytes) >= fd->FSize)
	{	/* to prevent reading after bound */
	maxBytes = fd->FSize - fd->FCDAbsPos;
	flag = 1;
	}

    /* Initialize for read loop */

    absPos = fd->FCDAbsPos;	/* SPR#78455 */
    FCDOffInLB = absPos % fd->pVDList->LBSize;
    rest = maxBytes;		/* Nothing read yet */

    /* Amount left to read in the current LB */

    field = min (rest, fd->pVDList->LBSize - FCDOffInLB);

    /* Loop reading and copying to output */

    while (rest > 0)
	{
	/* Read current logical block and set ptr at position within it */

	if ((ptr = cdromFsGetLB (fd->pVDList, fd->FCSStartLB + fsLb,
				 fsSizeLb - fsLb, &(fd->sectBuf))) == NULL)
	    {
	    fd->FCDAbsPos = absPos;
	    semGive (fd->pVDList->pVolDesc->mDevSem);   /* Without checking */

	    /* Was anything read? */

	    return ((maxBytes - rest) > 0 ?
		    maxBytes - rest :	/* Yes, return number bytes read */
		    ERROR);		/* No, return I/O error */
	    }

	ptr += FCDOffInLB;		/* Starting position */

	/* Copy current logical block to output */

	bcopy (ptr, buffer, field);

	/* Advance position */

	buffer += field;
	absPos += field;
	fsLb += (FCDOffInLB + field) / fd->pVDList->LBSize;

	rest -= field;

	/* Adjust position for new file section or new file unit */

	cdromFsSkipGap (fd, &fsLb, absPos);

	/* Every time except the first, read from the beginning of a LB */

	FCDOffInLB = 0;
	field = min (rest, fd->pVDList->LBSize);
	}

    if	(flag)
	{
	fd->FCEOF = 1;
	}  /* EOF */

    fd->FCDAbsPos = absPos;

    if (semGive (fd->pVDList->pVolDesc->mDevSem) == ERROR)
	{
	errnoSet (S_cdromFsLib_SEMGIVE_ERROR);
	return ERROR;
	}

    /*
     * File invariant
     *
     * 1. fd is valid and mounted.
     * 2. fd is on a valid valume.
     * 3. fd has a valid primary or secondary volume descriptor.
     * 4. If end-of-file, then position 1 byte past data in the file.
     * 5. If not end-of-file, then position within file.
     * 6. If not end-of-file, then file section is within the file.
     * 7. If not end-of-file, then position within file section.
     */

    assert (fd != NULL && fd->magic == FD_MAG && fd->inList != 0);     /* 1 */
    assert (fd->pVDList != NULL && fd->pVDList->magic == VD_LIST_MAG); /* 2 */
    assert (fd->pVDList->pVolDesc != NULL &&			       /* 3 */
	    fd->pVDList->pVolDesc->magic == VD_SET_MAG);
    assert (IF_A_THEN_B (fd->FCEOF != 0, fd->FCDAbsPos == fd->FSize)); /* 4 */
    assert (IF_A_THEN_B (fd->FCEOF == 0, fd->FCDAbsPos < fd->FSize));  /* 5 */
    assert (IF_A_THEN_B (fd->FCEOF == 0,			       /* 6 */
			 (fd->FCSAbsOff + fd->FCSSize) <= fd->FSize));
    assert (IF_A_THEN_B (fd->FCEOF == 0,			       /* 7 */
			 fd->FCSAbsOff <= fd->FCDAbsPos &&
			 fd->FCDAbsPos < (fd->FCSAbsOff + fd->FCSSize)));

    /* Return succsss */

    return (maxBytes);
    }

/***************************************************************************
*
* cdromFsReadyChange - sets special sign in the volume descriptor
*
* This function sets the value with meaning "CD was changed in the
* unit" to the block device structure assigned to the unit. The function can
* be called from the interrupt level
*
* RETURNS: N/A
*/

LOCAL STATUS cdromFsReadyChange
    (
    CDROM_VOL_DESC_ID arg
    )
    {
    if (arg == NULL)
	return ERROR;

    arg->pBlkDev->bd_readyChanged = TRUE;     /* It is "short", not a bit */
    return OK;
    }

/***************************************************************************
*
* cdromFsVolDescGet - get the current primary/supplementary volume descriptor
*
* This routine gets the current primary/supplementary volume descriptor.
*
* RETURNS: N/A
*
* SEE ALSO: cdromFsVolConfigShow()
*/

LOCAL STATUS cdromFsVolDescGet	    /* SPR#78709 */
    (
    T_CDROMFS_VD_LST_ID pVDList,    /* In: Primary/Supp vol descriptor */
    T_ISO_PVD_SVD *	pVolDescOut /* Out: Vol descriptor in return format */
    )
    {
    u_char	VDSizeToLBSizeShift; /* Logical block size to sector shift */
    u_char *	pData;		     /* Block continaing volume descriptor */

    bzero (pVolDescOut, sizeof (*pVolDescOut));

    /* Read volume descriptor */

    VDSizeToLBSizeShift
	= cdromFsShiftCount (ISO_VD_SIZE, pVDList->pVolDesc->sectSize);

#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
    pVolDescOut->volDescNum
	= (pVDList->VDPseudoLBNum - pVDList->pVolDesc->SesiPseudoLBNum) -
	ISO_PVD_BASE_LS + 1;
#else	/* CDROMFS_MULTI_SESSION_SUPPORT */
    pVolDescOut->volDescNum = pVDList->VDPseudoLBNum - ISO_PVD_BASE_LS + 1;
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */

    pVolDescOut->volDescSector = pVDList->VDPseudoLBNum >> VDSizeToLBSizeShift;

    pVolDescOut->volDescOffInSect
	= LAST_BITS (pVDList->VDPseudoLBNum, VDSizeToLBSizeShift) *
	ISO_VD_SIZE;

    /*
     * Read volume descriptor without read ahead.
     * We do not know how much read ahead is safe.
     */

    pData = cdromFsGetLS (pVDList->pVolDesc, pVolDescOut->volDescSector,
			  1, &(pVDList->pVolDesc->sectBuf));

    if (pData == NULL)
	{
	return (ERROR);
	}

    pData += pVolDescOut->volDescOffInSect;

    /* fill in volume configuration structure */

    pVolDescOut->volSize	= pVDList->volSize;
    pVolDescOut->PTSize		= pVDList->PTSize;
    pVolDescOut->PTSizeOnCD	= pVDList->PTSizeOnCD;

    pVolDescOut->PTOccur	= pVDList->PTStartLB;
    C_BUF_TO_LONG (pVolDescOut->PTOptOccur, pData, ISO_VD_PT_OPT_OCCUR);

    pVolDescOut->rootDirSize	= pVDList->rootDirSize;
    pVolDescOut->rootDirStartLB	= pVDList->rootDirStartLB;
    
    /* volDescSector: Up above */
    /* volDescOffInSect: Up above */
    /* volDescNum: Up above */

    pVolDescOut->volSetSize	= pVDList->volSetSize;
    pVolDescOut->volSeqNum	= pVDList->volSeqNum;

#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
    pVolDescOut->SesiOnCd	= 1 + pVDList->pVolDesc->SesiOnCD;
    pVolDescOut->ReadSession
	= 1 + (pVDList->pVolDesc->SesiToRead != DEFAULT_SESSION
	       ? pVDList->pVolDesc->SesiToRead /* Not default */
	       : pVDList->pVolDesc->SesiOnCD); /* DEFAULT_SESSION */
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
    pVolDescOut->LBSize		= pVDList->LBSize;
    pVolDescOut->type		= pVDList->type;
    pVolDescOut->uniCodeLev	= pVDList->uniCodeLev;
    pVolDescOut->fileStructVersion	= pVDList->fileStructVersion;

    bcopy (((T_ISO_VD_HEAD_ID)pData)->stdID, pVolDescOut->stdID,
	   ISO_STD_ID_SIZE );
    bcopy (pData + ISO_VD_SYSTEM_ID , pVolDescOut->systemId,
	   ISO_VD_SYSTEM_ID_SIZE );
    bcopy (pData + ISO_VD_VOLUME_ID , pVolDescOut->volumeId,
	   ISO_VD_ID_STD_SIZE );
    bcopy (pData + ISO_VD_VOL_SET_ID , pVolDescOut->volSetId,
	   ISO_VD_ID_STD_SIZE);
    bcopy (pData + ISO_VD_PUBLISH_ID , pVolDescOut->publisherId,
	   ISO_VD_ID_STD_SIZE );
    bcopy (pData + ISO_VD_DATA_PREP_ID , pVolDescOut->preparerId,
	   ISO_VD_ID_STD_SIZE );
    bcopy (pData + ISO_VD_APPLIC_ID , pVolDescOut->applicatId,
	   ISO_VD_ID_STD_SIZE );

    bcopy (pData + ISO_VD_COPYR_F_ID , pVolDescOut->cprightFId,
	   ISO_VD_F_ID_STD_SIZE );
    bcopy (pData + ISO_VD_ABSTR_F_ID , pVolDescOut->abstractFId,
	   ISO_VD_F_ID_STD_SIZE );
    bcopy (pData + ISO_VD_BIBLIOGR_F_ID , pVolDescOut->bibliogrFId,
	   ISO_VD_F_ID_STD_SIZE );

    /* date - time */
    pVolDescOut->creationDate =
	    *(T_ISO_VD_DATE_TIME_ID)(pData + ISO_VD_VOL_CR_DATE_TIME);
    pVolDescOut->modificationDate =
	    *(T_ISO_VD_DATE_TIME_ID)(pData + ISO_VD_VOL_MODIF_DATE_TIME);
    pVolDescOut->expirationDate =
	    *(T_ISO_VD_DATE_TIME_ID)(pData + ISO_VD_VOL_EXPIR_DATE_TIME);
    pVolDescOut->effectiveDate =
	    *(T_ISO_VD_DATE_TIME_ID)(pData + ISO_VD_VOL_EFFECT_DATE_TIME);

    return (OK);
    }

/***************************************************************************
*
* cdromFsVolConfigShow - show the volume configuration information
*
* This routine retrieves the volume configuration for the named cdromFsLib
* device and prints it to standard output.  The information displayed is
* retrieved from the BLK_DEV structure for the specified device.
*
* RETURNS: N/A
*
* SEE ALSO: cdromFsVersionDisplay()
*/

VOID cdromFsVolConfigShow
    (
    void *	arg		/* device name or CDROM_VOL_DESC * */
    )
    {
    CDROM_VOL_DESC *	pVolDesc = arg;	/* Mounted volume */
    char *		devName	 = arg;
    T_CDROMFS_VD_LST_ID pVDList; /* Primary/Supplementary volume descriptor */
    const char *	nameTail;

    if (arg == NULL)
	{
	printf ("\
	device name or CDROM_VOL_DESC * must be supplyed as parameter\n");
	return;
	}

    /* check type of supplyed argument */

    if (pVolDesc->magic != VD_SET_MAG)
	{
	/* if not CDROM_VOL_DESC_ID, may be device name */

	pVolDesc = (CDROM_VOL_DESC_ID)iosDevFind (devName, (char **)&nameTail);

	if (nameTail == devName ||
	    (pVolDesc == NULL) || pVolDesc->magic != VD_SET_MAG)
	    {
	    printf ("not cdrom fs device\n");
	    return;
	    }
	}

    devName = pVolDesc->devHdr.name;

    printf ("\
\ndevice config structure ptr	0x%lx\n\
device name			%s\n\
bytes per blkDevDrv sector	%ld\n",
	(u_long)pVolDesc,
	devName,
	pVolDesc->pBlkDev->bd_bytesPerBlk);

    if (pVolDesc->unmounted)
	{
	printf ("no volume mounted\n");
	return;
	}

    /* Loop through all volume descriptors */

    for (pVDList = (T_CDROMFS_VD_LST_ID) lstFirst (&(pVolDesc->VDList));
	 pVDList != NULL;
	 pVDList = (T_CDROMFS_VD_LST_ID) lstNext ((NODE *)pVDList))
	{
	T_ISO_PVD_SVD	volDesc;
	char *	non  = "none";
	char *	space = " ";

	/*
	 * This is T_ISO_VD_DATE_TIME with greenwOffBy15Minute deleted and
	 * 1 extra character for each member.
	 */

	struct
	{
	    char	year[ ISO_V_DATE_TIME_YEAR_SIZE +1 ],
			month[ ISO_V_DATE_TIME_FIELD_STD_SIZE +1 ],
			day[ ISO_V_DATE_TIME_FIELD_STD_SIZE +1 ],
			hour[ ISO_V_DATE_TIME_FIELD_STD_SIZE +1 ],
			minute[ ISO_V_DATE_TIME_FIELD_STD_SIZE +1 ],
			sec[ ISO_V_DATE_TIME_FIELD_STD_SIZE +1 ],
			sec100[ ISO_V_DATE_TIME_FIELD_STD_SIZE +1 ];
	    } date;

	if (semTake (pVolDesc->mDevSem, WAIT_FOREVER) == ERROR)
	    return;

	/* Get the volume descriptor and convert to output format */

	if (cdromFsVolDescGet (pVDList, &volDesc) != OK)
	    {
	    semGive (pVolDesc->mDevSem);
	    printf ("error reading volume\n");
	    return;
	    }

	printf ("\
\t%s directory hierarchy:	\n\n\
volume descriptor number	:%d\n\
descriptor logical sector	:%ld\n\
descriptor offset in sector	:%ld\n\
standard ID			:%s\n\
volume descriptor version	:%u\n\
UCS unicode level  (0=ISO9660)	:%u\n\
system ID			:%s\n\
volume ID			:%s\n\
volume size			:%lu = %lu MB\n\
number of logical blocks	:%lu = 0x%lx\n"

#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
"sessions on volume		:%u\n\
reading session			:%u\n"
#endif

"volume set size			:%u\n\
volume sequence number		:%u\n\
logical block size		:%u\n\
path table memory size (bytes)	:%lu\n\
path table size on CD (bytes)	:%lu\n\
path table entries		:%u\n\
volume set ID			:%s\n\
volume publisher ID		:%s\n\
volume data preparer ID		:%s\n\
volume application ID		:%s\n\
copyright file name		:%s\n\
abstract file name		:%s\n\
bibliographic file name		:%s\n",
	       (volDesc.type == ISO_VD_PRIMARY)? "\nPrimary" :
						   "\nSuplementary",
		volDesc.volDescNum,
		volDesc.volDescSector,
		volDesc.volDescOffInSect,
		volDesc.stdID,
		(u_int)volDesc.fileStructVersion,
		volDesc.uniCodeLev,
		volDesc.systemId,
		volDesc.volumeId,
		volDesc.volSize * volDesc.LBSize,
		volDesc.volSize * volDesc.LBSize / 0x100000,
		volDesc.volSize,
		volDesc.volSize,
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
		volDesc.SesiOnCd,
		volDesc.ReadSession,
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
		(u_int)volDesc.volSetSize,
		(u_int)volDesc.volSeqNum,
		(u_int)volDesc.LBSize,
		volDesc.PTSize,
		volDesc.PTSizeOnCD,
		pVDList->numPTRecs,
		volDesc.volSetId,
		volDesc.publisherId,
		volDesc.preparerId,
		volDesc.applicatId,
		(strspn (volDesc.cprightFId, space) == ISO_VD_F_ID_STD_SIZE)?
			non : (char *)volDesc.cprightFId,
		(strspn (volDesc.abstractFId, space) == ISO_VD_F_ID_STD_SIZE)?
			non : (char *)volDesc.abstractFId,
		(strspn (volDesc.bibliogrFId, space) == ISO_VD_F_ID_STD_SIZE)?
			non : (char *)volDesc.bibliogrFId
	     );

	/* date - time */
	bzero (&date, sizeof (date));
	bcopy (volDesc.creationDate.year , date.year,
	       ISO_V_DATE_TIME_YEAR_SIZE );
	bcopy (volDesc.creationDate.month , date.month,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.creationDate.day , date.day,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.creationDate.hour , date.hour,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.creationDate.minute , date.minute,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.creationDate.sec , date.sec,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.creationDate.sec100 , date.sec100,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );

	printf ("\
creation date			:%s.%s.%s  %s:%s:%s:%s\n",
	       date.day, date.month, date.year,
	       date.hour, date.minute, date.sec, date.sec100
	     );

	bzero (&date, sizeof(date));
	bcopy (volDesc.modificationDate.year , date.year,
	       ISO_V_DATE_TIME_YEAR_SIZE );
	bcopy (volDesc.modificationDate.month , date.month,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.modificationDate.day , date.day,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.modificationDate.hour , date.hour,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.modificationDate.minute , date.minute,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.modificationDate.sec , date.sec,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.modificationDate.sec100 , date.sec100,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );

	printf ("\
modification date		:%s.%s.%s  %s:%s:%s:%s\n",
	       date.day, date.month, date.year,
	       date.hour, date.minute, date.sec, date.sec100
	     );

	bzero (&date, sizeof(date));
	bcopy (volDesc.expirationDate.year , date.year,
	       ISO_V_DATE_TIME_YEAR_SIZE );
	bcopy (volDesc.expirationDate.month , date.month,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.expirationDate.day , date.day,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.expirationDate.hour , date.hour,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.expirationDate.minute , date.minute,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.expirationDate.sec , date.sec,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.expirationDate.sec100 , date.sec100,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );

	printf ("\
expiration date			:%s.%s.%s  %s:%s:%s:%s\n",
	       date.day, date.month, date.year,
	       date.hour, date.minute, date.sec, date.sec100
	     );

	bzero (&date, sizeof(date));
	bcopy (volDesc.effectiveDate.year , date.year,
	       ISO_V_DATE_TIME_YEAR_SIZE );
	bcopy (volDesc.effectiveDate.month , date.month,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.effectiveDate.day , date.day,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.effectiveDate.hour , date.hour,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.effectiveDate.minute , date.minute,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.effectiveDate.sec , date.sec,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );
	bcopy (volDesc.effectiveDate.sec100 , date.sec100,
	       ISO_V_DATE_TIME_FIELD_STD_SIZE );

	printf ("\
effective date			:%s.%s.%s  %s:%s:%s:%s\n",
	       date.day, date.month, date.year,
	       date.hour, date.minute, date.sec, date.sec100
	     );

	semGive (pVolDesc->mDevSem);
	} /* End for */

    return;
    }

/***************************************************************************
*
* cdromFsVersionDisplay - display the cdromFs version number
*
* This routine displays the cdromFs version number.
*
* RETURNS: N/A
*
* SEE ALSO: cdromFsVersionNumGet(), cdromFsVolConfigShow()
*/

void cdromFsVersionDisplay		/* SPR#78687 */
    (
    int level			/* level of display, not used */
    )
    {
    printf ("CD ISO 9660 file system with Joliet extensions (cdromFs)"
	    " version 0x%08x\t"
	    "Major %d Minor %d Patch level %d Build %d\n",
	    CDROMFS_VERSION,
	    SUBSYSTEM_VERSION_MAJOR(CDROMFS_VERSION),
	    SUBSYSTEM_VERSION_MINOR(CDROMFS_VERSION),
	    SUBSYSTEM_VERSION_PATCH(CDROMFS_VERSION),
	    SUBSYSTEM_VERSION_BUILD(CDROMFS_VERSION));
    }

/***************************************************************************
*
* cdromFsVersionNumGet - return the cdromFs version number
*
* This routine returns the cdromFs version number.
*
* RETURNS: the cdromFs version number.
*
* SEE ALSO: cdromFsVersionDisplay()
*/

uint32_t cdromFsVersionNumGet (void) /* SPR#78687 */
    {
    return ((uint32_t) CDROMFS_VERSION);
    }

/***************************************************************************
*
* cdromFsDevDelete - delete a cdromFsLib device from I/O system.
*
* This routine unmounts device and deallocates all memory.
* Argument <arg> defines device to be reset. It may be device name
* or ptr to CDROM_VOL_DESC.
* Argument <retStat> must be 0.
*
* RETURNS: NULL
*
* SEE ALSO:  cdromFsInit(), cdromFsDevCreate()
*/

LOCAL CDROM_VOL_DESC_ID cdromFsDevDelete
    (
    void *	arg,		/* device name or ptr to CDROM_VOL_DESC */
    STATUS	retStat		/* 0 only */
    )
    {
    CDROM_VOL_DESC_ID	pVolDesc = arg;
    char *		devName = arg;
    const char *	nameTail;

    if (retStat == ERROR)
	printf ("cdromFsLib ERROR: device init failed: ");
	/* SPR#32715, SPR#32726 */

    if (arg == NULL)
	{
	printf ("Invalid argument\n");
        return (NULL);
	}

    /* check type of supplyed argument */

    if (pVolDesc->magic != VD_SET_MAG)
	{
	/* if not CDROM_VOL_DESC_ID, may be device name? */

	pVolDesc = (CDROM_VOL_DESC_ID)iosDevFind (devName, (char **)&nameTail);

	if (nameTail == devName ||
	    (pVolDesc == NULL) || pVolDesc->magic != VD_SET_MAG)
	    {
	    printf ("not cdrom fs device\n");
            return (NULL);
	    }
	}

    /*
     * retStat == ERROR indicates request from cdromFsDevCreate
     * routine in case one failed, and so device not connected to list yet.
     * If not,- delete device from list
     */

    if (retStat != ERROR)
	iosDevDelete (&(pVolDesc->devHdr));

    /* make all resets and memory deallocations */

    /* firstly, private semaphore */

    if (pVolDesc->mDevSem != NULL)
	semTake (pVolDesc->mDevSem, WAIT_FOREVER);

    cdromFsVolUnmount (pVolDesc);	/* this routine resets VD and
					 * FD lists */
    cdromFsSectBufFree (&(pVolDesc->sectBuf));

    /* volume descriptor inconsistent */

    pVolDesc->magic = 0;
    pVolDesc->pBlkDev = NULL;

    if (pVolDesc->mDevSem != NULL)
	{
	semGive (pVolDesc->mDevSem);
	semDelete (pVolDesc->mDevSem);
	}

    KHEAP_FREE ((char *)pVolDesc);

    return (NULL);
    }

/***************************************************************************
*
* cdromFsDevCreate - create a cdromFsLib device
*
* This routine creates an instance of a cdromFsLib device in the I/O system.
* As input, this function requires a pointer to a BLK_DEV structure for
* the CD drive on which you want to create a cdromFsLib device.	 Thus,
* you should already have called scsiBlkDevCreate() prior to calling
* cdfromFsDevCreate().
*
* RETURNS: CDROM_VOL_DESC_ID, or NULL if error.
*
* ERRNO: S_memLib_NOT_ENOUGH_MEMORY
*
* SEE ALSO: cdromFsInit()
*/

CDROM_VOL_DESC_ID cdromFsDevCreate
    (
    char *	devName,    /* device name */
    BLK_DEV *	pBlkDev	    /* ptr to block device */
    )
    {
    CDROM_VOL_DESC_ID	pVolDesc;
    unsigned long	nStdBlocks; /* Num standard blocks on the device */

    if (cdromFsDrvNum == ERROR)
	{
	if (cdromFsInit () == ERROR)
	    return (NULL);
	}

    pVolDesc = KHEAP_ALLOC (sizeof(CDROM_VOL_DESC));

    if (pVolDesc == NULL)
	/* Call cdromFsDevDelete() solely to print error messages */

	return (cdromFsDevDelete (pVolDesc, ERROR));

    bzero ((u_char *) pVolDesc, sizeof(CDROM_VOL_DESC));

    pVolDesc->mDevSem = NULL;		/* semaphore not created */
    lstInit (&(pVolDesc->VDList));	/* preparing for VD list */
    lstInit (&(pVolDesc->FDList));	/* preparing for FD list */
    pVolDesc->unmounted = 1;		/* VDList must be built */
    pVolDesc->pBlkDev  = pBlkDev;

    /*
     * adapt to blkDevDrv block size (think of CDROM_STD_LS_SIZE is
     * less than or multiple of bd_bytesPerBlk)
     *
     * ISO-9660 6.1.2 Logical Sector
     * If sizeof(Physical Sector) <= 2048, sizeof(Logical Sector) = 2048.
     * Otherwise, sizeof(Logical Sector) = Largest power of 2 <=
     * sizeof(Physical Sector).
     *
     * sizeof(Logical Sector) is always a power of 2.
     * sizeof(Physical Sector) is not necessarily a power of 2.
     *
     * If sizeof(Physical Sector) > 2048 and sizeof(Phusical Sector)
     * is not a power of 2, sizeof(Physical Sector) > sizeof(Logical
     * Sector)
     * Otherwise, sizeof(Physical Sector) <= sizeof(Logical Sector).
     *
     * cdromFsLib implementation
     * sizeof(Physical Sector) = pBlkDev->bd_bytesPerBlk.
     * sizeof(Logical Sector) = pVolDesc->sectSize.
     *
     * sizeof(Physical Sector) not a power of 2 is not supported.
     * Therefore if sizeof(Physical Sector) > 2048, sizeof(Logical Sector)
     * == sizeof(Physical Sector).  Thus sizeof(Physical Sector) <=
     * sizeof(Logical Sector) and sizeof(Logical Sector) ==
     * pVolDesc->LSToPhSSizeMult * sizeof(Physical Sector).
     */

    if (pBlkDev->bd_bytesPerBlk < CDROM_STD_LS_SIZE)
	{
	pVolDesc->sectSize = CDROM_STD_LS_SIZE;
	pVolDesc->LSToPhSSizeMult =
				   CDROM_STD_LS_SIZE / pBlkDev->bd_bytesPerBlk;

	/* Verify bd_bytesPerBlk SPR#75766, SPR#80424 */

	if (cdromFsShiftCount (pBlkDev->bd_bytesPerBlk, CDROM_STD_LS_SIZE)
	    == 100)
	    return (cdromFsDevDelete (pVolDesc, ERROR));

	/* verify bd_nBlocks SPR#75766, SPR#80424 */

	nStdBlocks = pBlkDev->bd_nBlocks / pVolDesc->LSToPhSSizeMult;
	}
    else
	{
	pVolDesc->sectSize = pBlkDev->bd_bytesPerBlk;
	pVolDesc->LSToPhSSizeMult = 1;

	/* verify bd_nBlocks SPR#75766, SPR#80424 */

	nStdBlocks = pBlkDev->bd_nBlocks *
	    (pBlkDev->bd_bytesPerBlk / CDROM_STD_LS_SIZE);
	}

    /* verify bd_nBlocks SPR#75766, SPR#80424
     *
     * A CD has up to 80 min * 60 sec/min * 75 blks/sec = 360,000 blocks
     * since up to 80 minutes are possible.  (Most are 74 minutes)
     *
     * Each block is: Mode 1 - 2,048 bytes; Mode 2 Form 1 - 2,048 bytes;
     * Mode 2 Form 2 - 2,324 bytes.  ISO 9660 uses mode 1.
     *
     * A DVD is DVD-5 - 4,7 x 10^9 to DVD-19 - 1.08 * 10^9 bytes.  At
     * 2,366 bytes per sector (including error correction) this is
     * 1,986,475.063 to 7,218,934.911 sectors.
     */

    if (nStdBlocks < (ISO_PVD_BASE_LS + 1) ||
	nStdBlocks > 80000000ul)	/* Use 10 * largest DVD for growth */
	return (cdromFsDevDelete (pVolDesc, ERROR));

    /* common sectors buffer initiation */

    pVolDesc->sectBuf.sectData = NULL;

    if (cdromFsSectBufAlloc (pVolDesc, &(pVolDesc->sectBuf), 0) == ERROR)
	return (cdromFsDevDelete (pVolDesc, ERROR));

    /* create device protection mutual-exclusion semaphore */

    pVolDesc->mDevSem = semMCreate (SEM_Q_PRIORITY | SEM_INVERSION_SAFE);

    if (pVolDesc->mDevSem == NULL)
	return (cdromFsDevDelete (pVolDesc, ERROR));

#ifdef	VXWORKS_AE
    /*
     * Prevent semaphore from being deleted if calling task's home PD is
     * deleted..
     */

    objOwnerSet (pVolDesc->mDevSem, pdIdKernelGet ());
#endif /* VXWORKS_AE */

    pVolDesc->DIRMode = MODE_ISO9660;
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
    pVolDesc->SesiToRead = DEFAULT_SESSION;
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */
    pVolDesc->StripSemicolon = FALSE;

    pVolDesc->magic = VD_SET_MAG;

    /* add device to device list */

    if (iosDevAdd (&(pVolDesc->devHdr), devName,
		   cdromFsDrvNum) == ERROR)
	return (cdromFsDevDelete (pVolDesc, ERROR));

    DBG_MSG(50)("%d. cdromFsDevCreate done for BLK_DEV * = %p, sect = %d\n",
		__LINE__, pBlkDev, pVolDesc->sectSize);

    return (pVolDesc);
    }

#ifdef	DEBUG
#ifdef	CDROMFS_MULTI_SESSION_SUPPORT
/***************************************************************************
*
* cdromFsTocPrint - print the Table Of Contents (TOC) read from the disc
*
* This routine prints the table of contents read from the disc.
* For debugging purpose only, to be removed when done !!!
*
* RETURNS: void
*
* NOMANUAL
*/
void cdromFsTocPrint
    (
    CDROM_TRACK_RECORD * pCdStatus
    )
    {
    int                            index;
    UINT32                         sessionStartAddress;
    UINT16			   tocDataLength;

    readTocHeaderType            * pTocHeader;
    readTocSessionDescriptorType * pSessionDescriptor;

    pTocHeader = (readTocHeaderType *) pCdStatus->statBuffer;

    printf ("TOC header: \n");

    tocDataLength = ntohs (*((UINT16 *)pTocHeader->tocDataLength));

    d ((char *) pTocHeader,
       MEMBER_SIZE(readTocHeaderType,	/* Not included in todDataLength? */
		   tocDataLength) +
       tocDataLength +
       sizeof				/* Extra added by cdromFsTocRead() */
       (readTocSessionDescriptorType),
       1);

    printf ("\tTOC data length     : %d\n", tocDataLength);
    printf ("\tFirst session number: %d\n", pTocHeader->firstSessionNumber);
    printf ("\tLast session number : %d\n", pTocHeader->lastSessionNumber);

    pSessionDescriptor = (readTocSessionDescriptorType *)(pTocHeader + 1);

    for (index = 0;
	 index < (pTocHeader->lastSessionNumber + 1);
	 index++, pSessionDescriptor++)
        {
        sessionStartAddress
	    = ntohl (*((UINT32 *)pSessionDescriptor->sessionStartAddress));

        printf ("Session descriptor: %d\n", index + 1);
        printf ("\tControl             : %d\n", pSessionDescriptor->control);
        printf ("\tADR                 : %d\n", pSessionDescriptor->adr);
        printf ("\tSession number      : %d\n",
		pSessionDescriptor->sessionNumber);
        printf ("\tSession starting LBA: %d\n", sessionStartAddress);
        }
    }
#endif	/* CDROMFS_MULTI_SESSION_SUPPORT */

/***************************************************************************
*
* cdromFsDiskDirDateTimePrint - print a directory date/time that is in disk byte order.
*
* This routine prints a directory date/time that is in disk byte order.
* See ISO-9660 Section 9.1.5, Table 9, page 20.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void cdromFsDiskDirDateTimePrint
    (
    const T_FILE_DATE_TIME * pDateTime /* Directory date/time filed */
    )
    {
    int	year;
    int month;
    int day;
    int hour;
    int minute;
    int second;
    int offset;

    /*
     * Assign all structure members to variables for ease of comparison to
     * zero
     */

    year = pDateTime->year;
    month = pDateTime->month;
    day = pDateTime->day;
    hour = pDateTime->hour;
    minute = pDateTime->minuts;
    second = pDateTime->seconds;
    offset = (signed char) (pDateTime->fromGreenwOf);

    /* Are all of them zero? */

    if ((year|month|day|hour|minute|second|offset) == 0)
	{				 /* Yes, no date/time recorded */
	printf ("No date/time\n");
	}
    else
	{				 /* No, Print date/time */
	year += 1900;

	printf ("%2d/%2d/%4d %2d:%2d:%2d\tOffset %d minutes = %ld UNIX time\n",
		month, day, year, hour, minute, second, 15 * offset,
		(long) cdromFsDirDateTime2Long (pDateTime));
	}
    }

/***************************************************************************
*
* cdromFsDiskDirPrint - print a directory entry that is in disk byte order.
*
* This routine prints a directory entry that is in disk byte order.
* See ISO-9660 Section 9.1, Table 8, page 19.
*
* This is designed to be used from the shell to display successive
* directory entries as follows.
*
* \cs
* pRP = Address of first directory record
* pRP = cdromFsDiskDirPrint (pRP, 0)
* Repeat the above line for each directory record
* \ce
*
* RETURNS: a pointer to the next directory entry
*
* NOMANUAL
*/

const u_char * cdromFsDiskDirPrint
    (
    const u_char *	pDirRec, /* directory record to print */
    T_CDROMFS_VD_LST_ID pVDList	 /* Print EAR if not NULL */
				 /* volume descriptor that contains */
				 /* this directory */
    )
    {
    UINT32	 extentStartBlock;
    UINT32	 dataLength;	   /* In characters */
    UINT16	 volumeSequence;
    unsigned int fileFlags;

    /* Verify pDirRec */

    if (pDirRec == NULL)
	{
	printf ("pDirRec NULL\n");
	return ((u_char *) NULL);
	}

    /* Print address of the directory entry */

    printf ("pDirRec %p\n", pDirRec);

    /* Dump name of the directory entry */

    d ((char *) pDirRec + ISO_DIR_REC_FI, *(pDirRec + ISO_DIR_REC_LEN_FI), 1);

    /* Dump entire directory entry */

    d ((char *) pDirRec, *(pDirRec + ISO_DIR_REC_REC_LEN), 1);

    /*
     * Print the directory entry
     */

    /* Convert fields longer than one byte to avoid unalligned access */

    C_BUF_TO_LONG (extentStartBlock, pDirRec, ISO_DIR_REC_EXTENT_LOCATION);

    C_BUF_TO_LONG (dataLength, pDirRec, ISO_DIR_REC_DATA_LEN);

    C_BUF_TO_SHORT (volumeSequence, pDirRec, ISO_DIR_REC_VOL_SEQU_N);

    /* Print fields in order */

    printf ("\tDir rec len\t\t%d\n"
	    "\tEAR len\t\t\t%d\n"
	    "\tExtent start block\t%u\n"
	    "\tData length\t\t%u\n"
	    "\tDate/Time\t\t",
	    *(pDirRec + ISO_DIR_REC_REC_LEN),
	    (int) *(pDirRec + ISO_DIR_REC_EAR_LEN),
	    extentStartBlock,
	    dataLength);

    cdromFsDiskDirDateTimePrint ((const T_FILE_DATE_TIME *)
				 (pDirRec + ISO_DIR_REC_DATA_TIME));

    fileFlags = (int) *(pDirRec + ISO_DIR_REC_FLAGS);

    printf ("\tFile flags\t\t0x%x%s%s%s%s%s%s%s%s\n"
	    "\tFile unit size\t\t%d\n"
	    "\tInterleave gap size\t%d\n"
	    "\tVolume seq num\t\t%u\n"
	    "\tFile name len\t\t%d\n",
	    fileFlags,
	    (fileFlags & 1)    ? " !Ex" : "",
	    (fileFlags & 2)    ? " Dir" : "",
	    (fileFlags & 4)    ? " AssF" : "",
	    (fileFlags & 8)    ? " Rec" : "",
	    (fileFlags & 0x10) ? " Prot" : "",
	    (fileFlags & 0x20) ? " 0x20" : "",
	    (fileFlags & 0x40) ? " 0x40" : "",
	    (fileFlags & 0x80) ? " Cont" : " Last",
	    (int) *(pDirRec + ISO_DIR_REC_FU_SIZE),
	    (int) *(pDirRec + ISO_DIR_REC_IGAP_SIZE),
	    (unsigned) volumeSequence,
	    (int) *(pDirRec + ISO_DIR_REC_LEN_FI));

    /* Print the EAR? - Enabled and one exists */

    if (pVDList != (T_CDROMFS_VD_LST_ID) NULL)
	{
	const u_char *	pEAR;	   /* EAR lobical block */
	int		lbCounter; /* Loop variable */
	u_long		lbNum;	   /* LB to get */

	/* Loop through all blocks of the EAR */

	for (lbCounter = 0, lbNum = extentStartBlock;
	     lbCounter < *(pDirRec + ISO_DIR_REC_EAR_LEN);
	     lbCounter++)
	    {
	    pEAR = cdromFsGetLB (pVDList, lbNum,
				 *(pDirRec + ISO_DIR_REC_EAR_LEN) - lbCounter,
				 (SEC_BUF_ID) NULL);

	    /* Did an I/O error occur? */

	    if (pEAR == (const u_char *) NULL)
		break;		   /* Yes */

	    /* Print the EAR contents */
	    
	    /* First block? */

	    if (lbCounter == 0)
		{			 /* Yes, print formatted */
		cdromFsDiskEARPrint (pEAR);
		}

	    /* Dump the EAR contents (Except the first block) */

	    else
		{
		printf ("EAR block %d in block %ld\n",
			lbCounter + 1, lbNum);

		d ((char *) pEAR, pVDList->LBSize, 1);
		}
	    }
	}

    /* Return the address of next directory entry */

    return (pDirRec + *(pDirRec + ISO_DIR_REC_REC_LEN));
    }

/***************************************************************************
*
* cdromFsFDPrint - print a FD
*
* This routine prints a FD.
*
* RETURNS: the FD
*
* NOMANUAL
*/

T_CDROM_FILE_ID cdromFsFDPrint
    (
    T_CDROM_FILE_ID	pFD,	  /* file desriptor to print */
    BOOL		printEAR, /* Print EAR, if any, if TRUE */
    u_char *		message,  /* message to print */
    u_long		line      /* line number to print */
    )
    {
#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
    u_int	nrMulVD;
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */

    /* Verify pFD */

    if (pFD == NULL)
	printf ("%lu. %s\tpFD NULL\n", line, message);

    else if (pFD->magic != FD_MAG)
	printf ("%lu. %s\tpFD %p has bad magic %d\n",
		line, message, pFD, pFD->magic);

    else
	{				 /* OK, print it */
	/* Print the file descriptor */

	printf ("%lu. %s\tpFD %p\n"
		/* list */
		/* magic */
		"\tinList\t\t\t%u\n"
		/* pVDList */
		"\tname\t\t\t%s\n"
		"\tparentDirNum\t\t%u\n"
		"\tFRecords\t\t%p\n"
		"\tFStartLB\t\t%lu\n"
		"\tFSize\t\t\t%lu\n"
		"\tFType\t\t\t0x%x\n"
		/* FDateTime or FDateTimeLong */
		/* sectBuf */
		"\tFCDirRecPtr\t\t%p\n"
		"\tFCDirRecAbsOff\t\t%u\n"
		"\tFCDirFirstRecLB\t\t%lu\n"
		"\tFCSStartLB\t\t%lu\n"
		"\tFCSSize\t\t\t%lu\n"
		"\tFCSAbsOff\t\t%lu\n"
		"\tFDType\t\t\t0x%x\n"
		"\tFCSInterleaved\t\t%u\n"
		"\tFCSFUSizeLB\t\t%u\n"
		"\tFCSGapSizeLB\t\t%u\n"
		"\tFCDAbsPos\t\t%lu\n"
		"\tFCEOF\t\t\t%u\n"
		"\tDNumInPT\t\t%u\n"
#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
		"\tpMultDir\t\t%p\n"
		"\tnrMultDir\t\t%u\n"
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */
		"\tpVDList->LBSize\t\t\t%u\n"
		"\tpVDList->pVolDesc->sectSize\t%u\n",
		line, message, pFD,
		(unsigned) pFD->inList,
		pFD->name,
		(unsigned) pFD->parentDirNum,
		pFD->FRecords,
		pFD->FStartLB,
		pFD->FSize,
		(unsigned) pFD->FType,
		pFD->FCDirRecPtr,
		pFD->FCDirRecAbsOff,
		pFD->FCDirFirstRecLB,
		pFD->FCSStartLB,
		pFD->FCSSize,
		pFD->FCSAbsOff,
		(unsigned) pFD->FDType,
		(unsigned) pFD->FCSInterleaved,
		(unsigned) pFD->FCSFUSizeLB,
		(unsigned) pFD->FCSGapSizeLB,
		pFD->FCDAbsPos,
		pFD->FCEOF,
		(unsigned) pFD->DNumInPT,
#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
		pFD->pMultDir,
		pFD->nrMultDir,
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */
		(unsigned) pFD->pVDList->LBSize,
		pFD->pVDList->pVolDesc->sectSize);

	/* Print the first directory record of the file */

	(void) cdromFsDiskDirPrint (pFD->FCDirRecPtr,
				    (printEAR
				     ? pFD->pVDList
				     : (T_CDROMFS_VD_LST_ID) NULL));

#ifdef	CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS
	/* Are there any other volume descriptors? */

	if (pFD->pMultDir != NULL)
	    /* Yes, print block numbers in other volume descriptors */

	    for (nrMulVD = 0; nrMulVD < pFD->nrMultDir; nrMulVD++)
		{
		printf ("\t%d\tpFD->pMultDir[%d]\t%ld\n",
			nrMulVD, nrMulVD, pFD->pMultDir[nrMulVD]);
		}
#endif	/* CDROMFS_MODE_AUTO_COMBINE_VOLUME_DESCRIPTORS */
	}

    /* Return the file descriptor */

    return (pFD);
    }

/***************************************************************************
*
* cdromFsDiskPTPrint - print a path table entry that is in disk byte order.
*
* This routine prints a path table entry that is in disk byte order.
* See ISO-9660 Section 9.4, Table 11, page 22.
*
* This is designed to be used from the shell to display successive
* path table entries as follows.
*
* \cs
* pPT = Address of first path table entry
* pPT = cdromFsDiskPTPrint (pPT)
* Repeat the above line for each path table entry
* \ce
*
* RETURNS: a pointer to the next path table entry
*
* NOMANUAL
*/

const u_char * cdromFsDiskPTPrint
    (
    const u_char *	pPTRec /* path table record to print */
    )
    {
    UINT32	 extentStartBlock;
    int		 ptRecLength;
    UINT16	 parentDirectory;

    /* Verify pPTRec */

    if (pPTRec == NULL)
	{
	printf ("pPTRec NULL\n");
	return ((u_char *) NULL);
	}

    /* Print address of the path table record */

    printf ("pPTRec %p\n", pPTRec);

    /* Dump name of the path table entry */

    d ((char *) pPTRec + ISO_PT_REC_DI, *(pPTRec + ISO_PT_REC_LEN_DI), 1);

    /* Convert fields longer than one byte to avoid unalligned access */

    C_BUF_TO_LONG (extentStartBlock, pPTRec, ISO_PT_REC_EXTENT_LOCATION);

    C_BUF_TO_SHORT (parentDirectory, pPTRec, ISO_PT_REC_PARENT_DIR_N);

    /*
     * Print the path table entry
     */

    printf ("\tEAR len\t\t\t%d\n"
	    "\tExtent start block\t%u\n"
	    "\tParent directory\t%hu\n",
	    (int) *(pPTRec + ISO_PT_REC_EAR_LEN),
	    extentStartBlock,
	    parentDirectory);

    /* Return the address of the next path table entry */

    PT_REC_SIZE (ptRecLength, pPTRec);

    return (pPTRec + ptRecLength);
    }

/***************************************************************************
*
* cdromFsVDDateTime2Long - convert ISO volume descriptor Date/Time to UNIX time_t
*
* This routine converts date/time in ISO volume descriptor or EAR format
* (T_ISO_VD__DATE_TIME) to the UNIX long time format.
* See ISO-9660 Section 8.4.26.1, Table 5, page 15.
*
* RETURNS: Converted time
*
* NOMANUAL
*/

LOCAL time_t cdromFsVDDateTime2Long
    (
    const T_ISO_VD_DATE_TIME *	pDateTime /* Pointer to ISO date/time */
    )
    {
    struct tm			recTime;  /* For mktime() */
    u_char year[ISO_V_DATE_TIME_YEAR_SIZE + 1];
    u_char other[ISO_V_DATE_TIME_FIELD_STD_SIZE + 1];

    /* Are all fields zero? */

    if (pDateTime->greenwOffBy15Minute == 0 &&
	strncmp ((char *) pDateTime, "0000000000000000", 16) == 0)
	{				 /* Yes, no date/time recorded */
	return (0);
	}

    /* No, convert date/time */

    memcpy (year, &(pDateTime->year), sizeof(year) - 1);
    year[sizeof(year) - 1] = '\0';
    recTime.tm_year	=  atoi (year) - 1900;

    memcpy (other, &(pDateTime->month), sizeof(other) - 1);
    other[sizeof(other) - 1] = '\0';
    recTime.tm_mon	=  atoi (other) - 1;

    memcpy (other, &(pDateTime->day), sizeof(other) - 1);
    recTime.tm_mday	=  atoi (other);

    memcpy (other, &(pDateTime->hour), sizeof(other) - 1);
    recTime.tm_hour	=  atoi (other);

    memcpy (other, &(pDateTime->minute), sizeof(other) - 1);
    recTime.tm_min	=  atoi (other);

    memcpy (other, &(pDateTime->sec), sizeof(other) - 1);
    recTime.tm_sec	=  atoi (other);

    return (mktime (&recTime));
    }

/***************************************************************************
*
* cdromFsDiskVDDateTimePrint - print an volume desc date/time that is in disk byte order.
*
* This routine prints an EAR or volume descriptor date/time that is in
* disk byte order.
* See ISO-9660 Section 8.4.26.1, Table 5, page 15.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void cdromFsDiskVDDateTimePrint
    (
    const T_ISO_VD_DATE_TIME *	pDateTime /* EAR/Volume dexcr date/time */
    )
    {
    u_char year[ISO_V_DATE_TIME_YEAR_SIZE + 1];
    u_char month[ISO_V_DATE_TIME_FIELD_STD_SIZE + 1];
    u_char day[ISO_V_DATE_TIME_FIELD_STD_SIZE + 1];
    u_char hour[ISO_V_DATE_TIME_FIELD_STD_SIZE + 1];
    u_char minute[ISO_V_DATE_TIME_FIELD_STD_SIZE + 1];
    u_char sec[ISO_V_DATE_TIME_FIELD_STD_SIZE + 1];
    u_char sec100[ISO_V_DATE_TIME_FIELD_STD_SIZE + 1];

    /* Are all fields zero? */

    if (pDateTime->greenwOffBy15Minute == 0 &&
	strncmp ((char *) pDateTime, "0000000000000000", 16) == 0)
	{				 /* Yes, no date/time recorded */
	printf ("No date/time\n");
	}
    else
	{				 /* No, Print date/time */
	/* Copy strings */

	memcpy (year, &(pDateTime->year), sizeof(year) - 1);
	memcpy (month, &(pDateTime->month), sizeof(month) - 1);
	memcpy (day, &(pDateTime->day), sizeof(day) - 1);
	memcpy (hour, &(pDateTime->hour), sizeof(hour) - 1);
	memcpy (minute, &(pDateTime->minute), sizeof(minute) - 1);
	memcpy (sec, &(pDateTime->sec), sizeof(sec) - 1);
	memcpy (sec100, &(pDateTime->sec100), sizeof(sec100) - 1);

	/* NUL terminate strings */

	year[sizeof(year) - 1] = '\0';
	month[sizeof(month) - 1] = '\0';
	day[sizeof(day) - 1] = '\0';
	hour[sizeof(hour) - 1] = '\0';
	minute[sizeof(minute) - 1] = '\0';
	sec[sizeof(sec) - 1] = '\0';
	sec100[sizeof(sec100) - 1] = '\0';
 
	/* Print strings and UNIX time value */

	printf ("%s/%s/%s %s:%s:%s.%s\tOffset %d minutes = %ld UNIX time\n",
		month, day, year, hour, minute, sec, sec100,
		15 * pDateTime->greenwOffBy15Minute,
		cdromFsVDDateTime2Long (pDateTime));
	}
    }

/***************************************************************************
*
* cdromFsDiskEARPrint - print an EAR record that is in disk byte order.
*
* This routine prints an extended attribute record (EAR) that is in disk
* byte order.
* See ISO-9660 Section 9.5, Table 12, page 23.
*
* RETURNS: N/A
*
* NOMANUAL
*/

void cdromFsDiskEARPrint
    (
    const u_char *	pEAR	/* EAR to print */
    )
    {
    UINT16	owner;		/* UID */
    UINT16	group;		/* GID */
    UINT16	permissions;	/* Different than UNIX permissions */
    UINT16	recordLength;
    UINT16	lenAu;		/* Length of Application Use */
    UINT16	lenEsc;		/* Length of Excape Sequences */

    /* Verify pEAR */

    if (pEAR == NULL)
	{
	printf ("pEAR NULL\n");
	return;
	}

    /*
     * Print EAR
     */

    /* Convert fields longer than one byte to avoid unalligned access */

    C_BUF_TO_SHORT (owner, pEAR, ISO_EAR_ONER);
    C_BUF_TO_SHORT (group, pEAR, ISO_EAR_GROUPE);
    C_BUF_TO_SHORT (permissions, pEAR, ISO_EAR_PERMIT);

    /* Print fields in order */

    printf ("pEAR %p\n"
	    "\tOwner\t%hu\n"
	    "\tGroup\t%hu\n"
	    "\tPermissions\t%hu\t%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s\n"
	    "\tFile creation\t",
	    pEAR, owner, group, permissions,
	    (permissions &      1) ? "" : " SysR",
	    (permissions &      2) ? "" : " !2",
	    (permissions &      4) ? "" : " SysX",
	    (permissions &      8) ? "" : " !8",
	    (permissions &   0x10) ? "" : " OwnR",
	    (permissions &   0x20) ? "" : " !20",
	    (permissions &   0x40) ? "" : " OwnX",
	    (permissions &   0x80) ? "" : " !80",
	    (permissions &  0x100) ? "" : " GrpR",
	    (permissions &  0x200) ? "" : " !200",
	    (permissions &  0x400) ? "" : " GrpX",
	    (permissions &  0x800) ? "" : " !800",
	    (permissions & 0x1000) ? "" : " OthR",
	    (permissions & 0x2000) ? "" : " !2000",
	    (permissions & 0x4000) ? "" : " OthX",
	    (permissions & 0x8000) ? "" : " !8000");

    cdromFsDiskVDDateTimePrint ((const T_ISO_VD_DATE_TIME *)
				(pEAR + ISO_EAR_F_CR_DATE_TIME));

    printf ("\tFile modification\t");

    cdromFsDiskVDDateTimePrint ((const T_ISO_VD_DATE_TIME *)
				(pEAR + ISO_EAR_F_MODIF_DATE_TIME));

    printf ("\tFile expiration\t");

    cdromFsDiskVDDateTimePrint ((const T_ISO_VD_DATE_TIME *)
				(pEAR + ISO_EAR_F_EXPIR_DATE_TIME));

    printf ("\tFile Effective\t");

    cdromFsDiskVDDateTimePrint ((const T_ISO_VD_DATE_TIME *)
				(pEAR + ISO_EAR_F_EFFECT_DATE_TIME));

    printf ("\tRecord Format\t%d = \n", (int) pEAR[ISO_EAR_REC_FORMAT]);

    switch (pEAR[ISO_EAR_REC_FORMAT])
	{
	case 0:
	    printf ("Not specified");
	    break;

	case 1:
	    printf ("Fixed-length");
	    break;

	case 2:
	    printf ("Variable-length little-endian");
	    break;

	case 3:
	    printf ("Variable-length big-endian");
	    break;

	default:
	    if (pEAR[ISO_EAR_REC_FORMAT] <= 127)
		printf ("Reserved for further standardization");
	    else
		printf ("Reserved for system use");
	}

    printf ("\n\tRecord Attributes\t%d", (int) pEAR[ISO_EAR_REC_ATTR]);

    if (pEAR[ISO_EAR_REC_FORMAT] != 0)
	switch (pEAR[ISO_EAR_REC_ATTR])
	    {
	    case 0:
		printf (" = CRLF");
		break;

	    case 1:
		printf ("ISO 1539");
		break;

	    case 2:
		printf ("In record");
		break;

	    default:
		printf ("Reserved for future standardization");
		break;
	    }

    C_BUF_TO_SHORT (recordLength, pEAR, ISO_EAR_REC_LEN);

    printf ("\n\tRecord Length\t%hu\n"
	    "\tSystem Identifier\n",
	    recordLength);

    /* Dump system identifier */

    d ((char *) (pEAR + ISO_EAR_SYS_ID), ISO_EAR_SYS_ID_SIZE, 1);

    /* Dump system use */

    printf ("\tSystem Use\n");

    d ((char *) (pEAR + ISO_EAR_SYS_USE), ISO_EAR_SYS_USE_SIZE, 1);

    printf ("\tEAR Version\t%d\n"
	    "\tReserved\n",
	    (int) pEAR[ISO_EAR_VERSION]);

    /* Dump reserved */

    d ((char *) (pEAR + ISO_EAR_RESERVED), ISO_EAR_RESERVED_SIZE, 1);

    /* DUmp application use */

    printf ("\tApplication Use\n");

    C_BUF_TO_SHORT (lenAu, pEAR, ISO_EAR_LEN_AU);

    d ((char *) (pEAR + ISO_EAR_APP_USE), lenAu, 1);

    /* Dump escape sequences */

    printf ("\tEscape sequences\n");

    C_BUF_TO_SHORT (lenEsc, pEAR, ISO_EAR_LEN_ESC);

    d ((char *) (pEAR + (ISO_EAR_APP_USE - 1) + lenAu), lenEsc, 1);

    return;
    }

/***************************************************************************
*
* cdromFsSectBufAllocByLB - allocate by number of LB buffer for reading volume.
*
* After using, buffer must be deallocated by means of cdromFsSectBufFree().
* This routine calls cdromFsSectBufAllocBySize() with
* size equals to total <numLB> logical blocks size.
* If <numLB> == 0, allocated buffer is of 1 sectors size.
*
* RETURNS: OK or ERROR;
*/

LOCAL STATUS cdromFsSectBufAllocByLB
    (
    T_CDROMFS_VD_LST_ID pVDList,
    SEC_BUF_ID	pSecBuf,	/* buffer control structure */
				/* to which buffer is connected */
    int numLB			/* minimum LS in buffer */
    )
    {
    assert (pVDList != NULL);
    assert (pVDList->pVolDesc != NULL);
    assert (pSecBuf != NULL);

    return (cdromFsSectBufAllocBySize (pVDList->pVolDesc , pSecBuf,
				       numLB * pVDList->LBSize));
    }

/***************************************************************************
*
* cdDump - Test program by MBL.
*
* This routine is a test program by MBL.
*
* RETURNS: OK or ERROR, if cdromFsLib has already been initialized.
*
* NOMANUAL
*/

int cdDump
    (
    CDROM_VOL_DESC_ID	pVolDesc,  /* cdrom volume decriptor id */
    u_long		LBRead	   /* logical blk to read     */
    )
    {
    T_CDROMFS_VD_LST	VDList;	   /* volume descriptor list  */
    u_char *		pVDData;


    if (! pVolDesc->unmounted)
	cdromFsVolUnmount (pVolDesc);

    pVolDesc->pBlkDev->bd_readyChanged = FALSE;

    VDList.LBSize = ISO_VD_SIZE;
    VDList.LBToLSShift = cdromFsShiftCount (ISO_VD_SIZE, pVolDesc->sectSize);

    /* Check for valid sectSize SPR#75766 */

    if (VDList.LBToLSShift == 100)
	{
	printf ("error in volume sectSize %u\n", pVolDesc->sectSize);
	return ((int) NULL);
	}

    VDList.pVolDesc = pVolDesc;

    LET_SECT_BUF_EMPTY (&(VDList.pVolDesc->sectBuf));

    pVDData = cdromFsGetLB (&VDList, LBRead, 1, NULL);

    printf ("MBL=>>>>>>>>>>>>>>>>>>>>>>> %p <<<<<<<<<<=\n", pVDData);

    return ((int) pVDData);
    }
#endif	/* DEBUG */
