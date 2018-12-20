/* gv3Lib.c - I80X86 Thermal Monitor and Geyserville III library */

/* Copyright 2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01a,09aug02,hdn  written.
*/

/*
DESCRIPTION
This library provides Clock Modulation and Geyserville III technology 
specific routines.  This library has four configuration options to
manage the processor performance/power consumption state.  They are:
    - Maximum performance
      the highest performance state is used all the time.
    - Maximum battery life
      the lowest performance state is used all the time.
    - Optimized battery
      the highest performance state is used if power source is AC.
      the lowest performance state is used if power source is Battery.
    - Automatic
      the performance state is adjusted to match the current processor
      utilization.

.SS "Geyserville Technology"
Processor performance states are defined as discrete operating points
associated with and described by voltage and frequency (bus ratio) pairs.
By changing both the voltage and frequency simultaneously, the processor
effectively operates with a different execution efficiency (number of
instructions per unit time/power).
Geyserville I+ technology is an improvement over Geyserville I technology
that simply allows employing Geyserville I style transitions to utilize
more than two processor performance states.  It does this by managing 
voltage and bus ratio on die, such that the processor voltage and
frequency can be changed in unison after the processor enters the deep
sleep state using chip-set level controls.  This is not supported here.
Geyserville III technology is an entirely new architecture for managing
processor performance states, which allows the CPU performance and power
consumption levels to be altered while the computer is functioning.  
The key improvements in Geyserville III technology include very low 
hardware and software transition latencies (~10 us), MSR based interface,
and an architecture that moves all elements of processor performance
control to the CPU, thus centralizing and simplifying the system design.
It alters the performance of the CPU by changing the bus to core frequency
ratio and CPU voltage.  This allows the processor to run at different
core frequencies and voltages depending upon the system power source (AC
or battery in a mobile computer), CPU thermal state, or CPU utilization.
Note that the external bus frequency (processor system bus) is not 
altered.  Only the internal core frequency is changed.  In order to run
at different speeds, the voltage is altered in step with the bus ratio.
This works in accordance with voltage reduction technology that allows
a given processor to run at higher frequency when a higher voltage is 
applied.  The side result is that power is increased in a roughly cube-
law fashion as the performance is altered in this manner.  There are 
different transition events as follows:  
    - CPU utilization 
      transitions based upon the workload placed on the CPU. 
    - Thermal events 
      the CPU can overheat due to application load, abnormal ambient 
      conditions, etc.  Reducing the performance level of the processor 
      is effective in cooling down the processor and surrounding 
      components. 
    - Battery life 
      the user might prefer to maximize battery life at the expense of 
      performance.

.SS "Software Controlled Clock Modulation"
The software controlled clock modulation mechanism to control the core
temperature of the processor is introduced in the Pentium4 architecture.
The clock modulation duty cycle is selected based on the CPU utilization
to control the temperature and power consumption.  If on-demand clock
modulation and the thermal monitor are both enabled and thermal status 
of the processor is hot, clock modulation through the thermal monitor
takes precedence and the clock is modulated at a 50% duty cycle, 
regardless of the setting of the on-demand clock modulation duty cycle.

.SS "Thermal Monitor"
The Thermal Control Circuit is configured to perform one of two
automatic performance reduction features when the processor 
temperature goes above the maximum recommended operating temperature.
In one mode known as Intel Thermal Monitor 1, the processor may be
configured to reduce the internal effective clock frequency to 50%
of the current operating frequency (note that operating frequency may
be changed as a result of Geyserville transitions on the platform).
The second method known as Intel Thermal Monitor 2 performs an 
automatic Geyserville III transition to a lower operating point as 
specified in the GV_THERM control register.
If Intel Thermal Monitor 1 is enabled and the processor temperature 
drops below the maximum recommended operating temperature, the 
processor automatically disable the internal clock modulation and
returns to 100% internal effective clock frequency.
If Intel Thermal Monitor 2 is enabled and the processor temperature
drops below the maximum recommended operating temperature, the
processor automatically perform a Geyserville III transition back to 
the last requested operating point.  In this library, either one of
two modes is enabled at the same time.  The Intel Thermal Monitor 2
is enabled if the processor supports both capabilities.
The CPU utilization based transition uses the enabled mechanism,
that is clock duty cycle modulation in Intel Thermal Monitor 1 or
Geyserville III voltage/frequency transition in Intel Thermal 
Monitor 2.  Thermal interrupts are generated when the processor goes
cold to hot or hot to cold.  They are enabled in sysTherm.c in BSP.

.SS "CPU Utilization Based Transition"
The 64bit timestamp counter is read at the entrance and exit of the 
kernel idle loop.  The time between the second read and the initial 
read is a measure of how long the CPU is idle.  The summation of the
idle time in the sampling interval is the total CPU idle time.  The 
total CPU non-idle time is obtained in the same manner.  The CPU 
utilization (%) in the sampling time is calculated as follows.   
utilization (%) = (non-idle time) / (non-idle time + idle time).
There are two hook routines provided in this library to do this,
and a show routine vxIdleShow() is available to see the utilization.
The CPU Utilization Based Transition uses the following rule that is
recommended by Intel.  
    - If CPU utilization is above X<95> % of state S for N<300> 
      millisecond, transition CPU to state S+1.
    - If CPU utilization is below Y<95> % of state S for M<1000> 
      millisecond, transition CPU to state S-1.
    - Sampling interval is depending on the previous transition.
      If the most recent transition was to a higher state, sampling
      interval is N<300> millisecond.  If the most recent transition was 
      to a lower state, the sampling interval is M<1000> millisecond.
The value X, Y, N, and M are parameters of the initialization routine
gv3LibInit().  The watch dog routine runs at the sampling interval to
perform the transition if necessary.

.SS "Bibliography"
"Intel Architecture Software Developer's Manual, Volume 3"

SEE ALSO: sysTherm.c in the BSP, gv3Show.c, vxLib.c, vxShow.c
*/

/* includes */

#include "vxWorks.h"
#include "wdLib.h"
#include "regs.h"
#include "intLib.h"
#include "tickLib.h"
#include "arch/i86/vxI86Lib.h"
#include "arch/i86/regsGv3.h"
#include "arch/i86/pentiumLib.h"


/* defines */

#undef	GV3_DEBUG			/* define to debug wo GV3 CPU */
#ifdef	GV3_DEBUG
    UINT8 stateIx = 0;			/* index of the stateLog[] */
    UINT8 stateLog[256] = {0};		/* hold previous 256 state */
#endif	/* GV3_DEBUG */


/* externals */

IMPORT CPUID sysCpuId;
IMPORT int sysProcessor;
IMPORT int sysClkRateGet (void);


/* globals */

STATUS gv3LibState = GV3_INIT_NOT_DONE; /* initialization status */
UINT32 gv3Mode     = GV3_DEFAULT;	/* thermal monitor mode */
UINT32 gv3DutyCycleIx       = 0;	/* current clock duty cycle */
FREQ_VID_HEADER	* gv3Header = NULL;	/* current FREQ_VID_HEADER */
FREQ_VID_STATE	* gv3State  = NULL;	/* current FREQ_VID_STATE */
WDOG_ID gv3WdogId           = NULL;	/* WDOG ID for GV3 */


/* locals */

LOCAL FUNCPTR gv3AcCheckRtn = NULL;	/* AC check routine */
LOCAL UINT32 gv3UpUtil   = GV3_UP_UTIL;	  /* utilization(%) to go 1 up */
LOCAL UINT32 gv3DownUtil = GV3_DOWN_UTIL; /* utilization(%) to go 1 down */
LOCAL UINT32 gv3UpTime   = GV3_UP_TIME;	  /* time(millisec) to go 1 up */
LOCAL UINT32 gv3DownTime = GV3_DOWN_TIME; /* time(millisec) to go 1 down */
LOCAL UINT32 gv3UpTick       = 0;	/* time(sys tick) to go 1 up */
LOCAL UINT32 gv3DownTick     = 0;	/* time(sys tick) to go 1 down */
LOCAL UINT32 gv3PrevUtil     = 0;	/* previous utilization(%) */
LOCAL UINT32 gv3TotalTick    = 0;	/* total time spent in the util */
LOCAL UINT8 gv3ThrottleDuty  = GV3_DUTY_CYCLE; /* throttle duty cycle=50.0% */
LOCAL UINT8 gv3ThrottleRatio = GV3_BUS_RATIO;  /* throttle bus ratio=800Mhz */

LOCAL FREQ_VID_STATE	gv3FvidState[] = {
    {0, 0x35, 18, 36000}, /* 0 : FREQ_VID_HEADER {0x690, 0x35, 18, 7} */
    {1, 0x29, 16, 32000},
    {2, 0x23, 14, 28000},
    {3, 0x1d, 12, 24000},
    {4, 0x17, 10, 20000},
    {5, 0x11,  8, 16000},
    {6, 0x0b,  6, 12000},

    {0, 0x2c, 17, 34000}, /* 7 : FREQ_VID_HEADER {0x690, 0x2c, 17, 7} */
    {1, 0x29, 16, 32000},
    {2, 0x23, 14, 28000},
    {3, 0x1d, 12, 24000},
    {4, 0x17, 10, 20000},
    {5, 0x11,  8, 16000},
    {6, 0x0b,  6, 12000},

    {0, 0x29, 16, 32000}, /* 14 : FREQ_VID_HEADER {0x690, 0x29, 16, 6} */
    {1,	0x23, 14, 28000},
    {2,	0x1d, 12, 24000},
    {3,	0x17, 10, 20000},
    {4,	0x11,  8, 16000},
    {5,	0x0b,  6, 12000},

    {0,	0x29, 15, 30000}, /* 20 : FREQ_VID_HEADER {0x690, 0x29, 15, 6} */  
    {1,	0x26, 14, 28000},
    {2,	0x20, 12, 24000},
    {3,	0x1a, 10, 20000},
    {4,	0x14,  8, 16000},
    {5,	0x0e,  6, 12000},

    {0,	0x29, 14, 28000}, /* 26 : FREQ_VID_HEADER {0x690, 0x29, 14, 5} */  
    {1,	0x26, 12, 24000},
    {2,	0x23, 10, 20000},
    {3,	0x20,  8, 16000},
    {4,	0x1d,  6, 12000},

    {0,	0x29, 13, 26000}, /* 31 : FREQ_VID_HEADER {0x690, 0x29, 13, 5} */  
    {1,	0x26, 12, 24000},
    {2,	0x23, 10, 20000},
    {3,	0x20,  8, 16000},
    {4,	0x1d,  6, 12000},

    {0,	0x32, 13, 26000}, /* 36 : FREQ_VID_HEADER {0x691, 0x32, 13, 5} */  
    {1,	0x2c, 12, 24000},
    {2,	0x26, 10, 20000},
    {3,	0x20,  8, 16000},
    {4,	0x19,  6, 12000},

    {0,	0x32, 12, 24000}, /* 41 : FREQ_VID_HEADER {0x691, 0x32, 12, 4} */  
    {1,	0x2c, 10, 20000},
    {2,	0x23,  8, 16000},
    {3,	0x19,  6, 12000},

    {0,	0x32, 12, 24000}, /* 45 : FREQ_VID_HEADER {0x690, 0x32, 12, 3} */  
    {1,	0x29, 10, 20000},
    {2,	0x20,  8, 16000},

    {0, 0x2c, 12, 24000}, /* 48 : FREQ_VID_HEADER {0x690, 0x2c, 12, 3} */  
    {1, 0x20, 10, 20000},
    {2, 0x20,  8, 16000},

    {0, 0x00, 0, 0},	  /* 51 : FREQ_VID_HEADER {0x000, 0x00, 0, 0} */  
    {1, 0x00, 0, 0},
    };

LOCAL FREQ_VID_HEADER	gv3FvidHeader[] = {
    {0x690, 0x35, 18, 7, &gv3FvidState[0]},
    {0x690, 0x2c, 17, 7, &gv3FvidState[7]},
    {0x690, 0x29, 16, 6, &gv3FvidState[14]},
    {0x690, 0x29, 15, 6, &gv3FvidState[20]},
    {0x690, 0x29, 14, 5, &gv3FvidState[26]},
    {0x690, 0x29, 13, 5, &gv3FvidState[31]},
    {0x691, 0x32, 13, 5, &gv3FvidState[36]},
    {0x691, 0x32, 12, 4, &gv3FvidState[41]},
    {0x690, 0x32, 12, 3, &gv3FvidState[45]},
    {0x690, 0x2c, 12, 3, &gv3FvidState[48]},
    {0x000, 0x00, 00, 2, &gv3FvidState[51]}
    };

LOCAL INT8 gv3DutyCycle[] = {
    0x0,			/* reserved */
    0x2,			/* 12.5% */
    0x4,			/* 25.0% */
    0x6,			/* 37.5% */
    0x8,			/* 50.0% */
    0xa,			/* 62.5% */
    0xc,			/* 75.0% */
    0xe				/* 87.5% */
    };


/* forward declarations */

LOCAL VOID gv3WdogRtn (UINT32 prevDelay);


/*******************************************************************************
*
* gv3LibInit - initialize the Clock Modulation and Geyserville III Technology
*
* This routine initializes the Clock Modulation and Geyserville III Technology
* This routine detects if the processor has these features, and initializes
* them if it does.  The first parameter is the CPU performance state mode, and
* one of following four modes: Maximum performance, Maximum battery life,
* Optimized battery, Automatic.  The last parameter is a function pointer to
* routine that detect the power source, returns TRUE if it is AC.
*
* RETURNS: OK or ERROR if the Thermal Monitor is not supported.
*/

STATUS gv3LibInit 
    (
    UINT32 mode,		/* Thermal Monitor mode */
    UINT32 upUtil,		/* utilization(%) to go next state up */
    UINT32 downUtil,		/* utilization(%) to go next state down */
    UINT32 upTime,		/* time(millisec) to go next state up */
    UINT32 downTime,		/* time(millisec) to go next state down */
    FUNCPTR acCheckRtn		/* AC powered check rtn */
    )
    {
    INT32 value[2];
    INT32 cpuId;
    INT8  maxVid;
    INT8  maxRatio;
    INT8  bootVid;
    INT8  bootRatio;
    INT8  minRatio;
    BOOL  ac = TRUE;		/* TRUE if AC, FALSE if Battery */
    FREQ_VID_STATE * pState;	/* pointer to FREQ_VID_STATE table */
    INT32 stateNo;
    INT32 ix;


    /* check if it is already performed */

    if (gv3LibState != GV3_INIT_NOT_DONE)
	return (gv3LibState);

    gv3LibState &= ~GV3_INIT_NOT_DONE;	/* clear the bit */
    gv3AcCheckRtn = acCheckRtn;		/* remember the routine */
    gv3Mode = mode;			/* remember the mode */

#ifdef	GV3_DEBUG

    /* 
     * use the 1st FREQ_VID header[] entry for debug, that is
     * {0x690, 0x35, 18, 7, &gv3FvidState[0]},
     */

    gv3Header = &gv3FvidHeader[0];
    gv3State = gv3Header->pState;

#endif	/* GV3_DEBUG */

    /* check if the Thermal Monitor is supported */

    pentiumMsrGet (IA32_PLATFORM_ID, (LL_INT *)&value);
    if (value[0] & PFM_TM_DISABLED)
	{
        gv3LibState = GV3_ERR_NO_TM;
	return (ERROR);
	}

    if (sysCpuId.featuresEdx & CPUID_ACPI)
	{
	gv3LibState |= GV3_OK_TM1;
	}

    /* check if the Geyserville 1+ or 3 is supported */

    if ((value[1] & PFM_MOBILE_GV) == 0)
	{
        pentiumMsrGet (IA32_MISC_ENABLE, (LL_INT *)&value);
	value[0] &= ~(MSC_GV1_EN | MSC_GV3_EN);
	value[0] |= MSC_GV_SEL_LOCK;
        pentiumMsrSet (IA32_MISC_ENABLE, (LL_INT *)&value);
        gv3LibState |= GV3_OK_NO_GV;
	}

    /* check if the Geyserville III is supported */

    if ((sysCpuId.featuresEcx & CPUID_GV3) &&
        ((value[1] & PFM_GV3_DISABLED) == 0))
	{
        gv3LibState |= GV3_OK_GV3;

        /* CPU has the GV3.  get the matching FREQ_VID state table */

        cpuId = sysCpuId.signature & (CPUID_FAMILY | CPUID_MODEL | 
				      CPUID_STEPID);
        pentiumMsrGet (MSR_PERF_STS, (LL_INT *)&value);
        maxVid    = value[1] & GV_VID_MAX;
        maxRatio  = (value[1] & BUS_RATIO_MAX) >> 8;
        bootVid   = (value[1] & GV_VID_BOOT) >> 16;
        bootRatio = (value[1] & BUS_RATIO_BOOT) >> 24;
        minRatio  = (value[0] & BUS_RATIO_MIN) >> 24;

        for (ix = 0; ix < NELEMENTS (gv3FvidHeader); ix++)
	    {
	    gv3Header = &gv3FvidHeader[ix];
	    if ((cpuId == gv3Header->cpuId) &&
	        (maxVid == gv3Header->maxVid) &&
	        (maxRatio == gv3Header->maxRatio))
	        {
	        gv3State = gv3Header->pState;
	        }
	    }
    
        /* if there are no matching state, make it up */

        if (gv3State == NULL)
	    {
	    gv3State = gv3Header->pState;
	    (gv3State + 0)->vid = maxVid;
	    (gv3State + 0)->ratio = maxRatio;
	    (gv3State + 1)->vid = bootVid;
	    (gv3State + 1)->ratio = minRatio;

	    gv3LibState |= GV3_OK_NO_MATCH;
	    }

        /* enable the GV3 */

        pentiumMsrGet (IA32_MISC_ENABLE, (LL_INT *)&value);
        value[0] |= (MSC_GV3_EN | MSC_GV_SEL_LOCK);
        pentiumMsrSet (IA32_MISC_ENABLE, (LL_INT *)&value);

        /* check if the Thermal Monitor 2 is supported */

        pentiumMsrGet (IA32_PLATFORM_ID, (LL_INT *)&value);
        if ((sysCpuId.featuresEcx & CPUID_TM2) &&
            ((value[0] & PFM_GV3_TM_DISABLED) == 0))
	    {
	    gv3LibState |= GV3_OK_TM2;

	    /* get the matching state and set up the GV_THERM */

	    for (ix = 0; ix < gv3Header->nState; ix++)
	        {
	        pState = gv3Header->pState + ix;
	        if (gv3ThrottleRatio == pState->ratio)
		    {
    		    pentiumMsrGet (MSR_GV_THERM, (LL_INT *)&value);
		    value[0] &= ~(GV_THROT_SEL | 
				  BUS_RATIO_THROT | GV_VID_THROT);
		    value[0] |= GV_THROT_SEL |
			        ((pState->ratio << 8) & BUS_RATIO_THROT) |
			        (pState->vid & GV_VID_THROT);
    		    pentiumMsrSet (MSR_GV_THERM, (LL_INT *)&value);
		    gv3State = pState;
		    break;
		    }
	        }
	    }
        }

    /* enable Automatic Thermal Control Circuit (Automatic TCC) */

    pentiumMsrGet (IA32_MISC_ENABLE, (LL_INT *)&value);
    value[0] |= MSC_THERMAL_MON_ENABLE;
    pentiumMsrSet (IA32_MISC_ENABLE, (LL_INT *)&value);

    /* set up On-Demand Thermal Control Circuit (On-Demand TCC) */

    pentiumMsrGet (IA32_THERM_CONTROL, (LL_INT *)&value);
    value[0] &= ~(THERM_TCC_EN | THERM_DUTY_CYCLE);
    value[0] |= gv3ThrottleDuty;
    pentiumMsrSet (IA32_THERM_CONTROL, (LL_INT *)&value);
    
    /* get the power-source AC(default) or Battery */

    if (acCheckRtn != (FUNCPTR) NULL)
	ac = (* acCheckRtn) ();
       
    /* select the state for the specified mode */

    if (ac)
	{
	gv3LibState |= GV3_OK_AC;

	switch (mode)
	    {
	    case GV3_MAX_PERF:
	    case GV3_AUTO:
		stateNo = 0;
		gv3DutyCycleIx = NELEMENTS (gv3DutyCycle) - 1;
		break;

	    case GV3_OPT_BATT:
	    case GV3_MAX_BATT:
		stateNo = gv3Header->nState - 1;
		gv3DutyCycleIx = 1;
		break;

	    default:
		gv3Mode = GV3_DEFAULT;
		stateNo = 0;
		gv3DutyCycleIx = NELEMENTS (gv3DutyCycle) - 1;
		break;
	    }
	}
    else
	{
	gv3LibState |= GV3_OK_BATT;

	switch (mode)
	    {
	    case GV3_MAX_PERF:
		stateNo = 0;
		gv3DutyCycleIx = NELEMENTS (gv3DutyCycle) - 1;
		break;

	    case GV3_AUTO:
	    case GV3_OPT_BATT:
	    case GV3_MAX_BATT:
		stateNo = gv3Header->nState - 1;
		gv3DutyCycleIx = 1;
		break;

	    default:
		gv3Mode = GV3_DEFAULT;
		stateNo = gv3Header->nState - 1;
		gv3DutyCycleIx = 1;
		break;
	    }
	}

    /* set the selected state */

    if (gv3LibState & GV3_OK_TM2)
        gv3StateSet (stateNo);
    else if (gv3LibState & GV3_OK_TM1)
	gv3DutyCycleSet (gv3DutyCycleIx);

    /* set the parameters and enable the automatic state transition */

    if ((gv3Mode == GV3_AUTO) || (gv3Mode == GV3_DEFAULT))
	{
	gv3AutoSet (upUtil, downUtil, upTime, downTime);
	gv3AutoEnable (TRUE); 
	}

    return (OK);
    }

/*******************************************************************************
*
* gv3StateSet - perform the Geyserville III state transition
*
* This routine performs the Geyserville III state transition.
*
* RETURNS: OK or ERROR if the specified state is out of range.
*/

STATUS gv3StateSet 
    (
    UINT32 stateNo		/* GV3 FREQ_VID state index */
    )
    {
    INT32 value[2];
    INT32 oldLevel;

    /* sanity check */

    if (stateNo >= gv3Header->nState)
	return (ERROR);

#ifdef	GV3_DEBUG

    stateLog[stateIx++] = stateNo;

#endif	/* GV3_DEBUG */

    /* update the current state pointer, and perform the GV3 transition */

    oldLevel = intLock ();		/* LOCK INTERRUPTS */

    gv3State = gv3Header->pState + stateNo;

    pentiumMsrGet (MSR_PERF_CTL, (LL_INT *)&value);
    value[0] &= ~(BUS_RATIO_SEL | GV_VID_SEL);
    value[0] |= (((gv3State->ratio << 8) & BUS_RATIO_SEL) |
		 ((gv3State->vid) & GV_VID_SEL));
    pentiumMsrSet (MSR_PERF_CTL, (LL_INT *)&value);

    intUnlock (oldLevel);		/* UNLOCK INTERRUPTS */

    return (OK);
    }

/*******************************************************************************
*
* gv3HotCheck - check the thermal sensor high-temperature signal
*
* This routine checks the thermal sensor high-temperature signal.
* It checks the bit 0 of IA32_THERM_STATUS MSR that reflect the current 
* state of the thermal sensor.  The bit is 1 if the output signal 
* PROCHOT# is currently active, and 0 if it is not active.  
*
* RETURNS: TRUE if the bit 0 is set, FALSE otherwise.
*/

BOOL gv3HotCheck (void)
    {
    INT32 value[2];

    /* check the thermal sensor high-temparature output signal */

    pentiumMsrGet (IA32_THERM_STATUS, (LL_INT *)&value);

    if (value[0] & THERM_HOT_NOW)
	return (TRUE);
    else
	return (FALSE);
    }

/*******************************************************************************
*
* gv3DutyCycleSet - set the on-demand throttle clock duty cycle
*
* This routine sets on-demand throttle clock duty cycle.
*
* RETURNS: OK if the duty cycle has changed, ERROR otherwise.
*/

STATUS gv3DutyCycleSet 
    (
    UINT32 dutyCycleIx		/* clock duty cycle table index */
    )
    {
    INT32 value[2];
    INT32 oldLevel;
    
    /* sanity check */

    if ((dutyCycleIx >= NELEMENTS (gv3DutyCycle)) || (dutyCycleIx == 0))
	return (ERROR);

#ifdef	GV3_DEBUG

    stateLog[stateIx++] = dutyCycleIx;

#endif	/* GV3_DEBUG */

    /* update the duty cycle table index, and change the duty cycle */

    oldLevel = intLock ();		/* LOCK INTERRUPTS */

    gv3DutyCycleIx = dutyCycleIx;

    pentiumMsrGet (IA32_THERM_CONTROL, (LL_INT *)&value);
    value[0] &= ~(THERM_TCC_EN | THERM_DUTY_CYCLE);
    value[0] |= (THERM_TCC_EN | gv3DutyCycle[dutyCycleIx]);
    pentiumMsrSet (IA32_THERM_CONTROL, (LL_INT *)&value);
    
    intUnlock (oldLevel);		/* UNLOCK INTERRUPTS */

    return (OK);
    }

/*******************************************************************************
*
* gv3DutyCycleEnable - enable or disable the CPU on-demand throttling
*
* This routine enables or disables the CPU on-demand throttling.
*
* RETURNS: OK or ERROR if the on-demand throttling is not supported
*/

STATUS gv3DutyCycleEnable 
    (
    BOOL enable		/* TRUE to enable, FALSE to disable */
    )
    {
    INT32 value[2];

    if (gv3LibState & GV3_ERR_NO_TM)
	return (ERROR);

    /* toggle the On-Demand Thermal Control Circuit Enable bit */

    pentiumMsrGet (IA32_THERM_CONTROL, (LL_INT *)&value);

    if (enable)
	value[0] |= THERM_TCC_EN;
    else
	value[0] &= ~THERM_TCC_EN;

    pentiumMsrSet (IA32_THERM_CONTROL, (LL_INT *)&value);

    return (OK);
    }

/*******************************************************************************
*
* gv3DutyCycleCheck - check if the CPU on-demand throttling is enabled
*
* This routine checks if the CPU on-demand throttling is enabled.
*
* RETURNS: TRUE if the on-demand throttling is enabled, FALSE otherwise.
*/

BOOL gv3DutyCycleCheck (void)
    {
    INT32 value[2];

    /* toggle the On-Demand Thermal Control Circuit Enable bit */

    pentiumMsrGet (IA32_THERM_CONTROL, (LL_INT *)&value);

    if (value[0] & THERM_TCC_EN)
	return (TRUE);
    else
	return (FALSE);
    }

/*******************************************************************************
*
* gv3AcCheck - check the AC powered or Battery powered
*
* This routine checks the AC powered or Battery powered.
*
* RETURNS: TRUE if it is AC powered (default), FALSE otherwise.
*/

BOOL gv3AcCheck (void)
    {
    BOOL ac = TRUE;	/* default */

    /* get the power-source AC(default) or Battery */

    if (gv3AcCheckRtn != (FUNCPTR) NULL)
	ac = (* gv3AcCheckRtn) ();
       
    return (ac);
    }

/*******************************************************************************
*
* gv3WdogRtn - watch dog routine for the performance state transition
*
* This routine is the watch dog routine for the performance state transition.
* It is executed in the interrupt level.  The transition policy implemented 
* in this routine is suggested by Intel and is fast-up slow-down approach.
* - if CPU utilization is above X <gv3UpUtil> % of state S for 
*   N <gv3UpTime> millisecond, transition CPU to state S+1.
* - if CPU utilization is below Y <gv3DownUtil> % of state S for 
*   M <gv3DownTime> millisecond, transition CPU to state S-1.
* - sampling interval depends on the previous transition.  If the
*   previous transition was to a higher state, N millisecond is used.
*
* RETURNS: N/A
*/

LOCAL VOID gv3WdogRtn 
    (
    UINT32 prevDelay	/* previous sampling interval in system tick */
    )
    {
    UINT32 util  = vxIdleUtilGet ();	/* get CPU utilization */
    UINT32 delay = prevDelay;		/* get previous sampling interval */
    INT32 thermStatus[2];		/* value of IA32_THERM_STATUS */
    INT32 value[2];			/* value of other MSRs */
    FREQ_VID_STATE * pState;		/* FREQ_VID_STATE pointer */
    UINT16 busRatio;			/* bus ratio */
    INT8 dutyCycle;			/* duty cycle */
    INT32 ix;

    /* check if the On-Demand/Automatic TCC has been activated */

    pentiumMsrGet (IA32_THERM_STATUS, (LL_INT *)&thermStatus);
    if ((thermStatus[0] & THERM_HOT_LOG) &&
        ((thermStatus[0] & THERM_HOT_NOW) == 0))
	{
	/* reset the Thermal Status Log sticky bit */

        thermStatus[0] &= ~THERM_HOT_LOG;
        pentiumMsrSet (IA32_THERM_STATUS, (LL_INT *)&thermStatus);

	/* get the state lowered by the On-Demand/Automatic TCC */

	if (gv3LibState & GV3_OK_TM2)
	    {
            pentiumMsrGet (MSR_PERF_STS, (LL_INT *)&value);
	    busRatio = (value[0] & BUS_RATIO_STS) >> 8;
	    for (ix = 0; ix < gv3Header->nState; ix++)
	        {
	        pState = gv3Header->pState + ix;
	        if (busRatio == pState->ratio)
		    {
		    gv3State = pState;		/* update */
		    break;
		    }
	        }
	    }
	else if (gv3LibState & GV3_OK_TM1)
	    {
	    pentiumMsrGet (IA32_THERM_CONTROL, (LL_INT *)&value);
	    dutyCycle = value[0] & THERM_DUTY_CYCLE;
	    for (ix = 0; ix < NELEMENTS (gv3DutyCycle); ix++)
	        {
		if (dutyCycle == gv3DutyCycle[ix])
		    {
		    gv3DutyCycleIx = ix;	/* update */
		    break;
		    }
		}
	    }
	}

    /* perform the transition if it is necessary */

    if (util > gv3UpUtil)
	{
	/* 
	 * if CPU utilization is above X <gv3UpUtil> % of state S for 
	 * N <gv3UpTime> millisecond, and the CPU is not HOT,
	 * transition CPU to state S+1.
	 */

        if (gv3PrevUtil > gv3UpUtil)
	    gv3TotalTick += prevDelay;	/* accumulate */
	else
	    gv3TotalTick = prevDelay;	/* reset */

	if ((gv3TotalTick > gv3UpTick) &&
            ((thermStatus[0] & THERM_HOT_NOW) == 0))
	    {
	    /* transition CPU to the next state above */

	    if (gv3LibState & GV3_OK_TM2)
	        gv3StateSet (gv3State->no - 1);
	    else if (gv3LibState & GV3_OK_TM1)
		gv3DutyCycleSet (gv3DutyCycleIx + 1);
	    else
		;

	    gv3TotalTick = 0;		/* reset */
	    delay = gv3UpTick;		/* update the sampling interval */
	    }
	}
    else if (util < gv3DownUtil)
	{
	/* 
	 * if CPU utilization is below Y <gv3DownUtil> % of state S for 
	 * M <gv3DownTime> millisecond, transition CPU to state S-1.
	 */

        if (gv3PrevUtil < gv3DownUtil)
	    gv3TotalTick += prevDelay;	/* accumulate */
	else
	    gv3TotalTick = prevDelay;	/* reset */

	if (gv3TotalTick > gv3DownTick)
	    {
	    /* transition CPU to the next state below */

	    if (gv3LibState & GV3_OK_TM2)
	        gv3StateSet (gv3State->no + 1);
	    else if (gv3LibState & GV3_OK_TM1)
		gv3DutyCycleSet (gv3DutyCycleIx - 1);
	    else
		;

	    gv3TotalTick = 0;		/* reset */
	    delay = gv3DownTick;	/* update the sampling interval */
	    }
	}
    else
	{
	/* 
	 * utilization did not stay above gv3UpUtil or below gv3DownUtil.
	 * reset the totalTick, and use the previous sampling interval.
	 */

	gv3TotalTick = 0;		/* reset */
	}

    /* remember the previous utilization */

    gv3PrevUtil = util;

    /* restart the watch dog routine */

    wdStart (gv3WdogId, delay, (FUNCPTR)gv3WdogRtn, delay);
    }

/*******************************************************************************
*
* gv3AutoEnable - enable the automatic performance state transition
*
* This routine enables the automatic performance state transition.
* This routine creates/starts/stops the watch dog routine that runs at 
* the sampling interval.
*
* RETURNS: OK if succeeded, ERROR otherwise.
*/

STATUS gv3AutoEnable 
    (
    BOOL enable		/* TRUE to enable, or FALSE to disable */
    )
    {
    STATUS status;

    if (gv3LibState & GV3_ERR_NO_TM)
	return (ERROR);

    if (enable)
	{
	if (gv3WdogId == NULL)
	    {
	    if ((gv3WdogId = wdCreate ()) == NULL)
		return (ERROR);

	    /* convert milliseconds to system ticks */

	    gv3UpTick	= (gv3UpTime * sysClkRateGet ()) / 1000;
	    gv3DownTick	= (gv3DownTime * sysClkRateGet ()) / 1000;
	    }

	/* let's use the up (gv3UpTick) sampling interval */

	status = wdStart (gv3WdogId, gv3UpTick, (FUNCPTR)gv3WdogRtn, gv3UpTick);
	}
    else
	{
	if (gv3WdogId == NULL)
	    return (ERROR);

	status = wdCancel (gv3WdogId);

	/* reset the previous value */

	gv3PrevUtil = 0;		/* previous utilization(%) */
	gv3TotalTick = 0;		/* total time spent in the util */
	}

    return (status);
    }

/*******************************************************************************
*
* gv3AutoSet - set the automatic performance state transition parameters
*
* This routine sets the automatic performance state transition parameters.
*
* RETURNS: OK always
*/

STATUS gv3AutoSet 
    (
    UINT32 upUtil,	/* utilization(%) to go next state up */
    UINT32 downUtil,	/* utilization(%) to go next state down */
    UINT32 upTime,	/* time(millisec) to go next state up */
    UINT32 downTime	/* time(millisec) to go next state down */
    )
    {

    gv3UpUtil	= upUtil;
    gv3DownUtil	= downUtil;
    gv3UpTime	= upTime;
    gv3DownTime	= downTime;

    /* convert milliseconds to system ticks */

    gv3UpTick	= (upTime * sysClkRateGet ()) / 1000;
    gv3DownTick	= (downTime * sysClkRateGet ()) / 1000;

    return (OK);
    }

/*******************************************************************************
*
* gv3AutoGet - get the automatic performance state transition parameters
*
* This routine gets the automatic performance state transition parameters.
*
* RETURNS: OK always
*/

STATUS gv3AutoGet 
    (
    UINT32 * pUpUtil,	/* utilization(%) to go next state up */
    UINT32 * pDownUtil,	/* utilization(%) to go next state down */
    UINT32 * pUpTime,	/* time(millisec) to go next state up */
    UINT32 * pDownTime	/* time(millisec) to go next state down */
    )
    {

    *pUpUtil	= gv3UpUtil;
    *pDownUtil	= gv3DownUtil;
    *pUpTime	= gv3UpTime;
    *pDownTime	= gv3DownTime;

    return (OK);
    }

#ifdef	GV3_DEBUG

/*******************************************************************************
*
* gv3Loop - consume the processor power for the specified system ticks
*
* This routine consumes the processor power for the specified system ticks.
* This routine boost up the CPU utilization to cause the performance state 
* transition to the next level above for debugging.
*
* RETURNS: N/A
*/

void gv3Loop (UINT32 a)
    {
    UINT32 tick = tickGet ();

    while (1)
	{
	if (((UINT32)tickGet() - tick) > a)
	    break;
	}
    }

#endif	/* GV3_DEBUG */
