/* ipLib.c - ip protocol interface library */

/* Copyright 1984 - 2003 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01p,22jan03,wap  maintain compatibility with old API
01o,14jan03,rae  Merged from velocecp branch
01n,15oct01,rae  merge from truestack ver 01n, base 01m (VIRTUAL_STACK)
01m,13nov97,vin  consolidated all flags into _ipCfgFlags.
01b,15jul97,spm  made IP checksum calculation configurable (SPR #7836)
01a,20jan97,vin  written
*/

/*
DESCRIPTION
This library contains the interface to the ip protocol. The IP protocol
is configured in this library. 

The routine ipLibInit() is responsible for configuring the ip protocol
with various parameters.

INCLUDE FILES: netLib.h

.pG "Network"

NOMANUAL
*/

/* includes */
#include "vxWorks.h"
#include "netLib.h"
#include "net/protosw.h"
#include "net/domain.h"
#include "net/mbuf.h"
#include "netinet/in.h"
#include "netinet/in_systm.h"
#include "netinet/ip.h"
#include "netinet/ip_var.h"

#ifdef VIRTUAL_STACK
#include "netinet/vsLib.h"
#include "netinet/vsIp.h"
#include "netinet/vsNetCore.h" 	/* for protocol switch table */
#include "memPartLib.h"
#endif /* VIRTUAL_STACK */

/* externs */

#ifndef VIRTUAL_STACK
IMPORT int		_ipCfgFlags;
IMPORT int		_protoSwIndex;
IMPORT struct protosw 	inetsw [IP_PROTO_NUM_MAX]; 
IMPORT int		ip_defttl;
IMPORT int 		ipqmaxlen;
IMPORT int		ipfragttl;
#endif /* VIRTUAL_STACK */

/* globals */

/* defines */

/* typedefs */


/* locals */


/* forward declarations */

STATUS rawIpLibInit (void);
STATUS rawLibInit (void);

STATUS ipLibInit 
    (
    IP_CFG_PARAMS * 	ipCfg	     /* ip config parameters */
    )
    {
    return (ipLibMultiInit (ipCfg, 1));
    }

STATUS ipLibMultiInit 
    (
    IP_CFG_PARAMS * 	ipCfg,	     /* ip config parameters */
    int 		maxUnits     /* limit for MUX attachments to IP */
    )
    {
    FAST struct protosw	* pProtoSwitch; 

    if (_protoSwIndex >= sizeof(inetsw)/sizeof(inetsw[0]))
	return (ERROR) ;

    pProtoSwitch = &inetsw [_protoSwIndex]; 

    if (pProtoSwitch->pr_domain != NULL)
	return (OK); 				/* already initialized */

#ifdef VIRTUAL_STACK
    /* Allocate space for former global variables. */

    if (vsTbl[myStackNum]->pIpGlobals == NULL)
        {
        vsTbl[myStackNum]->pIpGlobals =
                              (VS_IP *) KHEAP_ALLOC (sizeof (VS_IP));
        if (vsTbl[myStackNum]->pIpGlobals == NULL)
            return (ERROR);

        bzero ( (char *)vsTbl [myStackNum]->pIpGlobals, sizeof (VS_IP));

        /*
         * Allocate the ipDrvCtrl array based on the given maxUnits. For
         * non-virtual stacks, the compiler performs this step automatically.
         */

        ipMaxUnits = maxUnits ? maxUnits : 1;

        ipDrvCtrl = (IP_DRV_CTRL *)
                       KHEAP_ALLOC(ipMaxUnits * sizeof(IP_DRV_CTRL));
        if (ipDrvCtrl == (IP_DRV_CTRL *) NULL)
            {
            KHEAP_FREE (vsTbl[myStackNum]->pIpGlobals);
            vsTbl [myStackNum]->pIpGlobals = NULL;
            return (ERROR);
            }

        bzero ( (char *)ipDrvCtrl, ipMaxUnits * sizeof(IP_DRV_CTRL));
        }
#endif

    pProtoSwitch->pr_type   	=  0;
    pProtoSwitch->pr_domain   	=  &inetdomain;
    pProtoSwitch->pr_protocol   =  0;
    pProtoSwitch->pr_flags	=  0;
    pProtoSwitch->pr_input	=  0;
    pProtoSwitch->pr_output	=  ip_output;
    pProtoSwitch->pr_ctlinput	=  0;
    pProtoSwitch->pr_ctloutput	=  0;
    pProtoSwitch->pr_usrreq	=  0;
    pProtoSwitch->pr_init	=  ip_init;
    pProtoSwitch->pr_fasttimo	=  0;
    pProtoSwitch->pr_slowtimo	=  ip_slowtimo;
    pProtoSwitch->pr_drain	=  ip_drain;
    pProtoSwitch->pr_sysctl	=  0;

    _protoSwIndex++; 

    /* initialize ip configuration parameters */

    _ipCfgFlags = ipCfg->ipCfgFlags;		/* ip configuration flags */
    ip_defttl 	= ipCfg->ipDefTtl; 		/* ip default time to live */
    ipqmaxlen 	= ipCfg->ipIntrQueueLen;	/* ip queue maximum length */
    ipfragttl	= ipCfg->ipFragTtl; 		/* ip fragment time to live */

    return (OK); 
    }

STATUS rawIpLibInit (void)
    {
    FAST struct protosw	* pProtoSwitch; 

    if (_protoSwIndex >= sizeof(inetsw)/sizeof(inetsw[0]))
	return (ERROR) ;

    pProtoSwitch = &inetsw [_protoSwIndex]; 

    if (pProtoSwitch->pr_domain != NULL)
	return (OK); 				/* already initialized */

    pProtoSwitch->pr_type   	=  SOCK_RAW;
    pProtoSwitch->pr_domain   	=  &inetdomain;
    pProtoSwitch->pr_protocol   =  IPPROTO_RAW;
    pProtoSwitch->pr_flags	=  PR_ATOMIC | PR_ADDR;
    pProtoSwitch->pr_input	=  rip_input;
    pProtoSwitch->pr_output	=  rip_output;
    pProtoSwitch->pr_ctlinput	=  0;
    pProtoSwitch->pr_ctloutput	=  rip_ctloutput;
    pProtoSwitch->pr_usrreq	=  rip_usrreq;
    pProtoSwitch->pr_init	=  0;
    pProtoSwitch->pr_fasttimo	=  0;
    pProtoSwitch->pr_slowtimo	=  0;
    pProtoSwitch->pr_drain	=  0;
    pProtoSwitch->pr_sysctl	=  0;

    _protoSwIndex++; 
    return (OK); 
    }

STATUS rawLibInit (void)
    {
    FAST struct protosw	* pProtoSwitch; 

    if (_protoSwIndex >= sizeof(inetsw)/sizeof(inetsw[0]))
	return (ERROR) ;

    pProtoSwitch = &inetsw [_protoSwIndex]; 

    if (pProtoSwitch->pr_domain != NULL)
	return (OK); 				/* already initialized */

    pProtoSwitch->pr_type   	=  SOCK_RAW;
    pProtoSwitch->pr_domain   	=  &inetdomain;
    pProtoSwitch->pr_protocol   =  0;
    pProtoSwitch->pr_flags	=  PR_ATOMIC | PR_ADDR;
    pProtoSwitch->pr_input	=  rip_input;
    pProtoSwitch->pr_output	=  rip_output;
    pProtoSwitch->pr_ctlinput	=  0; 
    pProtoSwitch->pr_ctloutput	=  rip_ctloutput;
    pProtoSwitch->pr_usrreq	=  rip_usrreq;
    pProtoSwitch->pr_init	=  rip_init;
    pProtoSwitch->pr_fasttimo	=  0;
    pProtoSwitch->pr_slowtimo	=  0;
    pProtoSwitch->pr_drain	=  0;
    pProtoSwitch->pr_sysctl	=  0;

    _protoSwIndex++; 
    return (OK); 
    }



