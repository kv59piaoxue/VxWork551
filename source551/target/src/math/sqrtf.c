/* sqrtf.c - software version of single precision square-root routine */

/* Copyright 2003 Wind River Systems, Inc. */

/*
modification history
--------------------
01a,03jun03,sn   wrote
*/

#include <math.h>

/******************************************************************************
*
* sqrt - compute a single precision square root
*
* INTERNAL:
*
* This is an extremely unoptimized implementation of sqrtf, provided
* for architectures which do not have an optimized version to allow
* code bases such as the GNU 3.x C++ library to compile and link. Feel
* free to replace this with an optimized implementation.
*
* NOMANUAL
*/

float sqrtf
    (
    float x
    )
    {
    return (float) sqrt(x);
    }

