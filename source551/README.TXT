README.TXT: Tornado 2.2 / VxWorks 5.5 Source Code Product
v0502


Please read the contents of the Tornado 2.2/VxWorks 5.5 Release Notes document that is shipped with the product.  It contains important information regarding host requirements, host patches, installation and run-time issues.

Up-to-date product bulletins, information on known problems and problems fixed/changes made in this release, as well as essential reference documentation such as the Getting Started, Installation, and Migration Guides can be obtained from the Wind River web site at:

  http://www.windriver.com/corporate/support/prodbullet/T2.2


Installation:
-------------
Be sure you are installing on a supported host that includes up-to-date patch levels. 


Windows:
--------
 - Windows NT 4.0 with service pack 5 or higher, Windows 2000 Professional or XP Professional.

 - CD-ROM drive for installation.

 - Administrator rights. 

 - Netscape 4.5 or Internet Explorer 5.0 or higher. (One of these browsers at this level or higher must be installed.) 


UNIX:
-----
 - The Solaris 2.7, 2.8, or 2.9 operating systems are supported:
    - On Solaris 2.7, prior to installing Tornado be certain you have Solaris Patch Cluster 7 installed, available from http://sunsolve.sun.com.  Without this patch, the X server or the system may become unstable. See the Release Notes for details on required patches).
    - On Solaris 2.8 and 2.9, only 32-bit mode is supported - Tornado will not run properly if your host machine is set to 64-bit mode.

 - A CD-ROM drive for installation.

 - Netscape 4.5 or Internet Explorer 5.0 or higher must be in your path.  (Internet Explorer is available for Solaris at: http://www.microsoft.com )

 - CDE Window Manager is recommended.  In addition, fvwm2 has been tested with success.  Some installations of KDE do not work with Tornado.  If you have difficulties using an alternative window manager, return to the supported window manager.


Licensing:
----------
This Source CD may be installed only according to the terms in your Source Code License agreement.  If you wish to see a copy of your Source Code License, please contact Wind River Systems, Inc. at 1-800-545-9463 or your local Wind River sales representative.


Installation Keys:
------------------
Installation keys are case-sensitive and are printed on the Installation Keys sheet in the Getting Started portfolio shipped with the Tornado 2.2 CD-ROM(s).

If you cannot find the installation keys, contact Wind River by e-mail at license@windriver.com.  Please include your sales order number.

You can also call (800) 545-WIND(9463) if you are in North America and ask for Key Administration.  In other locations, contact your nearest Wind River office.

New on Rev ZC-01 of this CD
---------------------------
Support for the Motorola PPC85XX Architecture, including two 
additional compilers for use with that Arch only: Diab 5.1.2 
and GCC 3.3.