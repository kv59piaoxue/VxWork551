/* gv3Show.c - Thermal Monitor and Geyserville III show routine */

/* Copyright 2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,28aug02,hdn  written.
*/

/*
DESCRIPTION
This library provides Thermal Monitor and Geyserville III Technology 
specific show routine. 

SEE ALSO:
*/

/* includes */

#include "vxWorks.h"
#include "stdio.h"
#include "wdLib.h"
#include "regs.h"
#include "arch/i86/pentiumLib.h"
#include "arch/i86/regsGv3.h"


/* defines */

#undef	GV3_DEBUG			/* define to debug wo GV3 CPU */
#ifdef	GV3_DEBUG
    IMPORT UINT8 stateIx;		/* index of the stateLog[] */
    IMPORT UINT8 stateLog[256];		/* hold previous 256 state */
#endif	/* GV3_DEBUG */


/* externals */

IMPORT CPUID  sysCpuId;			/* CPUID structure */
IMPORT INT32  sysProcessor;		/* processor family */
IMPORT STATUS gv3LibState;		/* the initialization status */
IMPORT UINT32 gv3Mode;			/* Thermal Monitor mode */
IMPORT UINT32 sysThermNhotInt;		/* Thermal Monitor hot int count */
IMPORT UINT32 sysThermNcoldInt;		/* Thermal Monitor cold int count */
IMPORT UINT8  gv3DutyCycleIx;		/* current clock duty cycle */
IMPORT FREQ_VID_HEADER * gv3Header;	/* current FREQ_VID_HEADER */
IMPORT FREQ_VID_STATE *  gv3State;	/* current FREQ_VID_STATE */
IMPORT SYS_THERM sysTherm;		/* Thermal Monitor int rtns */
IMPORT WDOG_ID   gv3WdogId;		/* WDOG ID for GV3 */


/* globals */


/* locals */

LOCAL INT8 * gv3DutyCycleStr[] = {
    "reserved",
    "12.5 %",
    "25.0 %",
    "37.5 %",
    "50.0 %",
    "62.5 %",
    "75.0 %",
    "87.5 %",
    };


/*******************************************************************************
*
* gv3ShowInit - initialize the Geyserville 3 Technology show facility
*
* NOMANUAL
*/

VOID gv3ShowInit (void)
    {
    }

/*******************************************************************************
*
* gv3Show - show the Geyserville 3 Technology attributes
*
* This routine shows the Geyserville 3 Technology attributes.
*
* RETURNS: N/A
*/

VOID gv3Show (void)
    {
    INT32 value[2];		/* 64 bit MSR value */
    INT8  bootVid;		/* boot vid */
    INT8  bootRatio;		/* boot bus ratio */
    INT8  minRatio;		/* minimum bus ratio */
    UINT32 upUtil;		/* utilization(%) to go up */
    UINT32 downUtil;		/* utilization(%) to go down */
    UINT32 upTime;		/* time(millisec) to go up */
    UINT32 downTime;		/* time(millisec) to go down */
    INT32 ix;


    /* show the gv3Lib initialization status */

    printf ("The gv3Lib initialization is ");
    switch (gv3LibState)
	{
	case GV3_INIT_NOT_DONE:
	    printf ("not done.\n");
	    return;

	case GV3_ERR_NO_TM:
	    printf ("failed : no Thermal Monitor exist.\n");
	    return;
	}

    printf ("succeeded.\n");
    
    if (gv3LibState & GV3_OK_TM1)
	printf (" TM1 is used.\n");
    if (gv3LibState & GV3_OK_NO_GV)
	printf (" no GV1+ or GV3 exist.\n");
    if (gv3LibState & GV3_OK_GV3)
	printf (" GV3 exist.\n");
    if (gv3LibState & GV3_OK_NO_MATCH)
	printf (" no matching FREQ_VID table.\n");
    if (gv3LibState & GV3_OK_TM2)
	printf (" GV3 TM2 is used.\n");
    if (gv3LibState & GV3_OK_AC)
	printf (" power source is AC.\n");
    if (gv3LibState & GV3_OK_BATT)
	printf (" power source is Battery.\n");

    /* show the configured thermal monitor mode */

    printf ("Configured thermal monitor mode is ");
    switch (gv3Mode)
	{
	case GV3_MAX_PERF:
	    printf ("max performance.\n");
	    break;

	case GV3_AUTO:
	    printf ("automatic.\n");
	    break;

	case GV3_OPT_BATT:
	    printf ("battery optimized.\n");
	    break;

	case GV3_MAX_BATT:
	    printf ("max battery.\n");
	    break;

	case GV3_DEFAULT:
	    printf ("not specified.\n");
	    break;
	}

    /* shows connected TM HOT/COLD interrupt routines and parameters */

    printf ("Thermal Monitor HOT  interrupt handler is ");
    if (sysTherm.hotConnected)
	{
	printf ("connected.\n routine = 0x%x, arg = 0x%x\n",
		(int)sysTherm.hotRoutine, sysTherm.hotArg);
	}
    else
	printf ("not connected.\n");

    printf ("Thermal Monitor COLD interrupt handler is ");
    if (sysTherm.coldConnected)
	{
	printf ("connected.\n routine = 0x%x, arg = 0x%x\n",
		(int)sysTherm.coldRoutine, sysTherm.coldArg);
	}
    else
	printf ("not connected.\n");

    /* shows TM HOT/COLD interrupt counter */

    printf ("Thermal Monitor HOT  interrupt happened : %d\n", 
	    sysThermNhotInt);
    printf ("Thermal Monitor COLD interrupt happened : %d\n", 
	    sysThermNcoldInt);

    /* shows the state transition policy parameters */

    gv3AutoGet (&upUtil, &downUtil, &upTime, &downTime);
    printf ("If CPU utilization is above %d %% of state S for %d "
    	    "millisecond,\n transition CPU to state S+1.\n", 
	    upUtil, upTime);
    printf ("If CPU utilization is below %d %% of state S for %d "
    	    "millisecond,\n transition CPU to state S-1.\n", 
	    downUtil, downTime);

    printf ("The processor is ");
    if (gv3HotCheck())
	printf ("hot now.\n");
    else
	printf ("not hot now.\n");

    printf ("On-Demand Thermal Control Circuit is ");
    if (gv3DutyCycleCheck())
	printf ("enabled.\n");
    else
	printf ("disabled.\n");

    /* show the GV3 FREQ_VID state */

    if (gv3LibState & GV3_OK_GV3)
        {
	printf ("Geyserville III technology is used.\n");
        printf (" Matching Frequency-VID state was ");
        if (gv3Header->cpuId == 0x0)
	    printf ("not found.\n");
        else
	    printf ("found.\n");

        printf (" cpuId=0x%x, maxVid=0x%x, maxRatio=0x%x, nState=%d\n",
            gv3Header->cpuId, 
	    gv3Header->maxVid, 
	    gv3Header->maxRatio,
            gv3Header->nState);

        for (ix = 0; ix < gv3Header->nState; ix++)
	    {
	    printf (" %02d : Vid=0x%02x, BusRatio=%03d, power=%d(mW)\n",
	        (gv3Header->pState + ix)->no,
	        (gv3Header->pState + ix)->vid,
	        (gv3Header->pState + ix)->ratio,
	        (gv3Header->pState + ix)->power);
	    }

        /* show more info */

        pentiumMsrGet (MSR_PERF_STS, (LL_INT *)&value);
        bootVid   = (value[1] & GV_VID_BOOT) >> 16;
        bootRatio = (value[1] & BUS_RATIO_BOOT) >> 24;
        minRatio  = (value[0] & BUS_RATIO_MIN) >> 24;
        printf (" Boot Vid=0x%x, Boot Bus Ratio=0x%x, Min Bus Ratio=%d\n",
	    bootVid, bootRatio, minRatio);
	}
    else
	{
	printf ("Software Controlled Clock Modulation is used.\n");
        pentiumMsrGet (IA32_THERM_CONTROL, (LL_INT *)&value);
        ix = (value[0] & THERM_DUTY_CYCLE) >> 1;
        printf (" current  duty cycle = %s\n", gv3DutyCycleStr[ix]);
        printf (" intended duty cycle = %s\n", gv3DutyCycleStr[gv3DutyCycleIx]);
	}

    printf ("Watch dog is ");
    if (gv3WdogId != NULL)
	{
	printf ("created.\n");
	wdShow (gv3WdogId);
	}
    else
	printf ("not created.\n");

#ifdef	GV3_DEBUG
    {
    INT32 iy;
    INT32 iz = 0;

    printf ("-- state change happened %d times so far --\n", stateIx);
    for (ix = 0; ix < 16; ix++)
	{
	printf ("%03d : ", ix * 16);
	for (iy = 0; iy < 16; iy++)
	    printf (" %03d", stateLog[iz++]);
	printf ("\n");
	}
    }
#endif	/* GV3_DEBUG */

    }

