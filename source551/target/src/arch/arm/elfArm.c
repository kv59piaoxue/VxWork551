/* elfArm.c - ELF/ARM relocation unit */

/* Copyright 2001-2002 Wind River Systems, Inc. */
#include "copyright_wrs.h"

/*
modification history
--------------------
01c,13feb02,jn   Add printed error messages when CHECK_FITS fails
01b,21nov01,pad  Minor changes: added error messages, made elfArmSegReloc
                 local, etc.
01a,28aug01,jn   written, based on AE version (elfArm.c@@/main/tor3_x/12)
		 and ppc specific parts of loadElfLib.c@@/main/8 
*/

/*
DESCRIPTION
This file contains the relocation unit for the ELF/ARM combination.

Each relocation entry is applied to the sections loaded in the target memory
image in order to eventually get an executable program linked at the required
address.

The relocation computations handled by this relocation unit are:

	R_ARM_NONE	none,		no computation
	R_ARM_PC24	word32,		S + A - P
	R_ARM_ABS32	word32,		S + A
	R_ARM_REL32	word32,		S + A - P
	R_ARM_THM_PC22  BL pair		S - P + A
	R_ARM_THM_PC9	low8,		S - P + A
	R_ARM_THM_PC11	low11,		S - P + A

With:
   A - the addend used to compute the value of the relocatable field.
   S - the value (address) of the symbol whose index resides in the
       relocation entry. Note that this function uses the value stored
       in the external symbol value array instead of the symbol's
       st_value field.
   P - the place (section offset or address) of the storage unit being
       relocated (computed using r_offset) prior to the relocation.

Both the Elf32_Rel and Elf32_Rela relocation entry types are accepted
by this relocation unit, as permitted by the ELF ABI for the ARM
architecture.

*/

/* Includes */

#include "vxWorks.h"
#include "string.h"
#include "stdio.h"
#include "elf.h"
#include "elftypes.h"
#include "errnoLib.h"
#include "moduleLib.h"
#include "loadLib.h"
#include "loadElfLib.h" 
#include "private/vmLibP.h"
#include "symbol.h"
#include "symLib.h"
#include "arch/arm/elfArm.h"


/* Defines */

#define MEM_READ_32(pRelocAdrs, offset)	  (offset = *((UINT32 *)(pRelocAdrs)))
#define MEM_READ_16(pRelocAdrs, offset)	  (offset = *((UINT16 *)(pRelocAdrs)))
#define MEM_READ_8(pRelocAdrs, offset)    (offset = *((UINT8 *)(pRelocAdrs)))

#define MEM_WRITE_32(pRelocAdrs, value32)				\
    (*((UINT32 *)(pRelocAdrs)) = (value32))
#define MEM_WRITE_16(pRelocAdrs, value16)				\
    (*((UINT16 *)(pRelocAdrs)) = (value16))
#define MEM_WRITE_8(pRelocAdrs, value8)					\
    (*((UINT8 *)(pRelocAdrs)) = (value8))

/* Locals */

LOCAL STATUS elfArmPc24Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation 	      */
    Elf32_Sword  relocAddend   /* Addend from reloc. - arg used for RELA only */
    );

LOCAL STATUS elfArmAbs32Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation          */
    Elf32_Sword  relocAddend,  /* Addend from reloc. - arg used for RELA only */
    SYM_TYPE	 symType       /* Type of symbol			      */
    );

LOCAL STATUS elfArmRel32Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation 	      */
    Elf32_Sword  relocAddend   /* Addend from reloc. - arg used for RELA only */
    );

LOCAL STATUS elfThumbPc22Reloc
    (
    Elf32_Word	 sh_type,     /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,  /* Relocation address 			     */
    void *	 pSymAdrs,    /* Addr of sym involved in relocation 	     */
    Elf32_Sword  relocAddend  /* Addend from reloc. - arg used for RELA only */
    );

LOCAL STATUS elfThumbPc9Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation 	      */
    Elf32_Sword  relocAddend   /* Addend from reloc. - arg used for RELA only */
    );

LOCAL STATUS elfThumbPc11Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation 	      */
    Elf32_Sword  relocAddend   /* Addend from reloc. - arg used for RELA only */
    );

LOCAL STATUS relocationSelect
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA) */
    void *	 pRelocAdrs,   /* Addr where the relocation applies  */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation */
    Elf32_Word	 relocInfo,    /* Info from relocation command */
    Elf32_Sword  relocAddend,  /* Addend from reloc. - arg used for RELA only */
    SYM_TYPE	 symType       /* Type of sym involved in relocation */
    );

/**************************************************************************
*
* elfArmSegReloc - perform relocation commands for ARM rel or rela segments
*
* This routine reads the relocation command segments and dispatches
* the relocation work to either relArmSegmentRel or relArmSegment depending
* on whether the relocation section is type REL or RELA. The relocation 
* commands reside in the sections with section type SHT_RELA or SHT_REL.
*
* RETURNS: OK or ERROR
*/

LOCAL STATUS elfArmSegReloc
    (
    int          fd,            /* object file to read in */
    MODULE_ID    moduleId,      /* ID of object module being relocated */
    int          loadFlag,      /* load options (not used here) */
    int          posCurRelocCmd,/* position of current relocation command */
    Elf32_Shdr * pScnHdrTbl,    /* ptr to section header table (unused here) */
    Elf32_Shdr * pRelHdr,       /* pointer to relocation section header */
    SCN_ADRS *   pScnAddr,      /* section address once loaded */
    SYM_INFO_TBL symInfoTbl,    /* array of absolute symbol values and types */
    Elf32_Sym *  pSymsArray,    /* pointer to symbols array (not used here) */
    SYMTAB_ID    symTbl,        /* current symbol table (not used here) */
    SEG_INFO *   pSeg           /* section addresses and sizes */
    )

    {
    Elf32_Rela	 relaRelocCmd;	/* relocation structure, RELA version */
    Elf32_Rel	 relRelocCmd;	/* relocation structure, REL version */
    Elf32_Addr	 relocOffset = 0;/* offset from relocation structure */
    Elf32_Word	 relocInfo = 0;	 /* info from relocation structure */	
    Elf32_Sword	 relocAddend = 0;/* addend from reloc struct. (RELA only) */
    UINT32	 relocNum;	/* number of reloc entries in section */
    UINT32	 relocIdx;	/* index of the reloc entry being processed */
    void *	 pRelocAdrs;	/* relocation address */
    void *	 pSymAdrs;	/* address of symbol involved in relocation */
    SYM_TYPE	 symType;	/* type of symbol involved in relocation */
    STATUS	 status = OK;	/* whether or not all relocations were ok */

    /* Sanity checking */

    if (pRelHdr->sh_type == SHT_RELA)
        {
	if (pRelHdr->sh_entsize != sizeof (Elf32_Rela))
	    {
	    printErr ("Wrong relocation entry size.\n");
	    errnoSet (S_loadElfLib_RELOC);
	    return ERROR;
	    }
	}
    else if (pRelHdr->sh_type == SHT_REL)
        {
	if (pRelHdr->sh_entsize != sizeof (Elf32_Rel))
	    {
	    printErr ("Wrong relocation entry size.\n");
	    errnoSet (S_loadElfLib_RELOC);
	    return ERROR;
	    }
	}
    else
        {
	printErr ("Unknown relocation entry type.\n");
        errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}


    /* Get the number of relocation entries */

    relocNum = pRelHdr->sh_size / pRelHdr->sh_entsize;

    /* Relocation loop */

    for (relocIdx = 0; relocIdx < relocNum; relocIdx++)
        {
	/* Read relocation command (SHT_RELA or SHT_REL type) */

	if (pRelHdr->sh_type == SHT_RELA)
            {
	    if ((posCurRelocCmd = elfRelocRelaEntryRd (fd,
						       posCurRelocCmd,
						       &relaRelocCmd)) == ERROR)
	        {
		errnoSet (S_loadElfLib_READ_SECTIONS);
		return ERROR;
		}

	    relocOffset = relaRelocCmd.r_offset;
	    relocInfo   = relaRelocCmd.r_info;
	    relocAddend = relaRelocCmd.r_addend;
	    }
	else if (pRelHdr->sh_type == SHT_REL)
	    {
	    if ((posCurRelocCmd = elfRelocRelEntryRd (fd,
						      posCurRelocCmd,
						      &relRelocCmd)) == ERROR)
	        {
		errnoSet (S_loadElfLib_READ_SECTIONS);
		return ERROR;
		}

	    relocOffset = relRelocCmd.r_offset;
	    relocInfo   = relRelocCmd.r_info;
	    relocAddend = 0;  /* addend is extracted from memory in REL case. */
	    }

	/*
	 * If the target symbol's address is null, then this symbol is
	 * undefined. The computation of its value can be out of range
	 * so let's not waste our time on it. A warning message has already 
	 * been displayed for this symbol.
	 *
	 * Note: ELF32_R_SYM(relocInfo) gives the index of the symbol in
	 *       the module's symbol table. This same index is used to
	 *       store the symbol information (address and type for
	 *       now) in the symInfoTbl table (see loadElfSymTabProcess()).  
	 */

	if ((pSymAdrs = symInfoTbl [ELF32_R_SYM(relocInfo)].pAddr) == NULL)
	    continue;

	/*
	 * Calculate actual remote address that needs relocation, and
	 * perform external or section relative relocation.
	 */

	pRelocAdrs = (void *)((Elf32_Addr)*pScnAddr + relocOffset);

	symType = symInfoTbl [ELF32_R_SYM (relocInfo)].type;

	if (relocationSelect (pRelHdr->sh_type, pRelocAdrs, pSymAdrs,
			      relocInfo, relocAddend, symType) != OK)
	    status = ERROR;
	}

    return status;
    }

/*******************************************************************************
*
* relocationSelect - select, and execute, the appropriate relocation
*
* This routine selects, then executes, the relocation computation as per the
* relocation command.
*
* NOTE
* This routine should use two different errnos:
*  - S_loadElfLib_UNSUPPORTED: when a relocation type is not supported on 
*    purpose.
*  - S_loadElfLib__UNRECOGNIZED_RELOCENTRY: when a relocation type is not 
*    recognized (default case of the switch).
*
* RETURNS : OK or ERROR if computed value can't be written down in target
*           memory.
*/

LOCAL STATUS relocationSelect
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA) */
    void *	 pRelocAdrs,   /* Addr where the relocation applies  */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation */
    Elf32_Word	 relocInfo,    /* Info from relocation command */
    Elf32_Sword  relocAddend,  /* Addend from reloc. - arg used for RELA only */
    SYM_TYPE	 symType       /* Type of sym involved in relocation */
    )
    {
    switch (ELF32_R_TYPE (relocInfo))
	{
	case (R_ARM_NONE):			/* none */
	    break;

	case (R_ARM_PC24):			/* word32, S + A - P */
	    if (elfArmPc24Reloc (sh_type, pRelocAdrs, pSymAdrs, 
				 relocAddend) != OK)
		return ERROR;
	    break;

	case (R_ARM_ABS32):			/* word32, S + A */
	    if (elfArmAbs32Reloc (sh_type, pRelocAdrs, pSymAdrs, 
				  relocAddend, symType) != OK)
		return ERROR;
	    break;

	case (R_ARM_REL32):			/* word32, S + A - P */
	    if (elfArmRel32Reloc (sh_type, pRelocAdrs, pSymAdrs, 
				  relocAddend) != OK)
		return ERROR;
	    break;

	case (R_ARM_PC13):			/* low12 + U-but, S + A - P */
	case (R_ARM_ABS16):			/* word16, S + A */
	case (R_ARM_ABS12):			/* low12, S + A */
	case (R_ARM_THM_ABS5):			/* 6-10 bits, S + A */
	case (R_ARM_ABS8):			/* byte8, S + A */
	    printErr ("Unsupported relocation type %d\n",
		      ELF32_R_TYPE (relocInfo));
	    errnoSet (S_loadElfLib_UNSUPPORTED);
	    return ERROR;
	    break;

	case (R_ARM_THM_PC22):                 /* BL pair, S - P + A */
	    if (elfThumbPc22Reloc (sh_type, pRelocAdrs, pSymAdrs, 
				   relocAddend) != OK)
		return ERROR;
	    break;

	case (R_ARM_THM_PC8):			/* low8, S - P + A */
	    printErr ("Unsupported relocation type %d\n",
		      ELF32_R_TYPE (relocInfo));
	    errnoSet (S_loadElfLib_UNSUPPORTED);
	    return ERROR;
	    break;

	case (R_ARM_THM_PC9):			/* low8, S - P + A */
	    if (elfThumbPc9Reloc (sh_type, pRelocAdrs, pSymAdrs, 
				  relocAddend) != OK)
		return ERROR;
	    break;

	case (R_ARM_THM_PC11):			/* low11, S - P + A */
	    if (elfThumbPc11Reloc (sh_type, pRelocAdrs, pSymAdrs,
				   relocAddend) != OK)
		return ERROR;
	    break;

	default:
	    printErr ("Unknown relocation type %d\n",
		      ELF32_R_TYPE (relocInfo));
	    errnoSet (S_loadElfLib_UNRECOGNIZED_RELOCENTRY);
	    return ERROR;
	    break;
	}

    return OK;
    }

/*******************************************************************************
*
* elfArmPc24Reloc - perform the R_ARM_PC24 relocation
*
* This routine handles the R_ARM_PC24 relocation (B/BL low24, (S - P + A) >> 2).
*
* RETURNS : OK or ERROR if computed value can't be written down in target
*	    memory or offset too large for relocation.
*/

LOCAL STATUS elfArmPc24Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation 	      */
    Elf32_Sword  relocAddend   /* Addend from reloc. - arg used for RELA only */
    )
    {
    UINT32	 value;		/* Relocation value 	    */
    UINT32	 memValue;	/* Previous value in memory */
    UINT32	 addend = 0;	/* Relocation Addend initially extracted 
				   from memValue */

    MEM_READ_32 (pRelocAdrs, memValue);	

    /*
     * The offset should be stored in the relocation as 24 bits, sign-extended
     * to 32 bits but, in case it's not, we extract it and sign-extend it
     * appropriately.
     */

    LOW24_INSERT(addend, memValue);

    addend = addend << 2;				/* byte offset */
    addend = SIGN_EXTEND (addend, 26);			/* sign extend */

    if (sh_type == SHT_RELA)
        {
	/* 
	 * The ARM ELF ABI specifies that with RELA, the addend is the sum 
	 * of the value extracted from the storage unit being relocated and 
	 * the addend field in the relocation instruction.  
	 */  

	addend += relocAddend;   
	}

    value = (UINT32)pSymAdrs - (UINT32)pRelocAdrs + addend;

    /*
     * Do some checking: R_ARM_PC24 relocation must fit in 26 bits and
     * lowest 2 bits should always be zero.  It will then be shifted right
     * two bits so that it is a 24-bit, signed, word offset.
     */

    if (!CHECK_FITS (value, 26))
	{
	printErr ("Relocation value does not fit in 26 bits.\n");
	errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}

    if (value & 0x3)
	{
	printErr ("Relocation value's lowest 2 bits not zero.\n");
	errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}

    LOW24_INSERT (memValue, value >> 2);

    MEM_WRITE_32(pRelocAdrs, memValue);

    return OK;
    }

/*******************************************************************************
*
* elfArmAbs32Reloc - perform the R_ARM_ABS32 relocation 
*
* This routine handles the R_ARM_ABS32 relocation (word32, S + A).
*
* RETURNS : OK or ERROR if computed value can't be written down in target
*	    memory.
*/

LOCAL STATUS elfArmAbs32Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation          */
    Elf32_Sword  relocAddend,  /* Addend from reloc. - arg used for RELA only */
    SYM_TYPE	 symType       /* Type of symbol			      */
    )
    {
    UINT32	 value;		/* Relocation value */
    UINT32	 addend;	/* Addend */

    MEM_READ_32 (pRelocAdrs, addend);	

    if (sh_type == SHT_RELA)
        {
	/* 
	 * The ARM ELF ABI specifies that with RELA, the addend is the sum 
	 * of the value extracted from the storage unit being relocated and 
	 * the addend field in the relocation instruction.  
	 */  

	addend += relocAddend;   
	}

    value = (UINT32)pSymAdrs + addend;

    /* check for and handle Thumb */

    /* XXX There's no mention of changing this bit in the ABI.  This
     * approach is basically 'faked' interworking.  There are special
     * relocation types that are designed to be used for cross links
     * between Thumb and ARM code (R_ARM_XPC25 and R_ARM_THM_XPC22) -
     * we don't currently support these, but that is the proper method
     * to use when we eventually support interworking.
     */

    if (symType & SYM_THUMB)
	value |= 1;

    MEM_WRITE_32(pRelocAdrs, value);

    return OK;
    }

/*******************************************************************************
*
* elfArmRel32Reloc - perform the R_ARM_REL32 relocation 
*
* This routine handles the R_ARM_REL32 relocation (word32, S + A - P).
*
* RETURNS : OK or ERROR if computed value can't be written down in target
*	    memory.
*/

LOCAL STATUS elfArmRel32Reloc
    (
    Elf32_Word	 sh_type,     /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,  /* Relocation address 			     */
    void *	 pSymAdrs,    /* Addr of sym involved in relocation 	     */
    Elf32_Sword  relocAddend  /* Addend from reloc. - arg used for RELA only */
    )
    {
    UINT32	 value;		/* Relocation value */
    UINT32	 addend;	/* Addend */

    MEM_READ_32 (pRelocAdrs, addend);	

    if (sh_type == SHT_RELA)
        {
	/* 
	 * The ARM ELF ABI specifies that with RELA, the addend is the sum 
	 * of the value extracted from the storage unit being relocated and 
	 * the addend field in the relocation instruction.  
	 */  

	addend += relocAddend;   
	}

    value = (UINT32)pSymAdrs + addend - (UINT32)pRelocAdrs;

    MEM_WRITE_32 (pRelocAdrs, value);

    return OK;
    }

/*******************************************************************************
*
* elfThumbPc22Reloc - perform the R_ARM_THM_PC22 relocation
*
* This routine handles the R_ARM_THM_PC22 reloc (BL pair, (S - P + A) >> 1).
*
* RETURNS : OK or ERROR if computed value can't be written down in target
*	    memory or offset too large for relocation.
*/


LOCAL STATUS elfThumbPc22Reloc
    (
    Elf32_Word	 sh_type,     /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,  /* Relocation address 			     */
    void *	 pSymAdrs,    /* Addr of sym involved in relocation 	     */
    Elf32_Sword  relocAddend  /* Addend from reloc. - arg used for RELA only */
    )
    {
    UINT32	 value;		/* Relocation value 	    */
    UINT16	 memValue1;	/* Previous value in memory in first BL ins. */
    UINT16	 memValue2;	/* Previous value in memory in first BL ins. */
    UINT32	 addend = 0;	/* Relocation Addend extracted from memValue */
    UINT32       tmp = 0;       /* variable needed to extract addend bits */

    MEM_READ_16 (pRelocAdrs, memValue1);	 
    MEM_READ_16 ((char *) pRelocAdrs+2, memValue2); 

    /*
     * The offset should be stored in the relocation as 22 bits spread
     * between 2 words, sign-extended to 32 bits but, in case it's not,
     * we extract it and sign-extend it appropriately.
     */

    LOW11_INSERT(addend, memValue1);

    addend = addend << 12;				/* byte offset */
    addend = SIGN_EXTEND (addend, 23);			/* sign extend */

    LOW11_INSERT(tmp, memValue2);

    addend += tmp << 1;

    if (sh_type == SHT_RELA)
        {
	/* 
	 * The ARM ELF ABI specifies that with RELA, the addend is the sum 
	 * of the value extracted from the storage unit being relocated and 
	 * the addend field in the relocation instruction.  
	 */  

	addend += relocAddend;   
	}

    value = (UINT32)pSymAdrs - (UINT32)pRelocAdrs + addend;

    /*
     * Do some checking: R_ARM_THM_PC22 relocation must fit in 23 bits and
     * lowest bit should always be zero.
     */

    if (!CHECK_FITS (value, 23))
	{
	printErr ("Relocation value does not fit in 23 bits.\n"); 
	errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}

    if (value & 1)
	{
	printErr ("Relocation value's lowest bit is not zero.\n");
	errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}

    LOW11_INSERT (memValue1, value >> 12);
    LOW11_INSERT (memValue2, value >> 1);

    MEM_WRITE_16(pRelocAdrs, memValue1);
    MEM_WRITE_16((char *) pRelocAdrs+2, memValue2);

    return OK;
    }

/*******************************************************************************
*
* elfThumbPc9Reloc - perform the R_ARM_THM_PC9 relocation 
*
* This routine handles the R_ARM_THM_PC9 relocation (Bcc (S - P + A) << 1).
*
* RETURNS : OK or ERROR if computed value can't be written down in target
*	    memory or offset too large for relocation.
*/

LOCAL STATUS elfThumbPc9Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation 	      */
    Elf32_Sword  relocAddend   /* Addend from reloc. - arg used for RELA only */
    )
    {
    UINT32	value;		/* Relocation value 	    */
    UINT16	memValue;	/* Previous value in memory */
    UINT32	addend=0;	/* Relocation addend extracted from memValue */

    MEM_READ_16 (pRelocAdrs, memValue);	

    LOW8_INSERT (addend, memValue);

    addend = addend << 1;				/* halfword offset */
    addend = SIGN_EXTEND(addend, 9);			/* sign extend */

    if (sh_type == SHT_RELA)
        {
	/* 
	 * The ARM ELF ABI specifies that with RELA, the addend is the sum 
	 * of the value extracted from the storage unit being relocated and 
	 * the addend field in the relocation instruction.  
	 */  

	addend += relocAddend;   
	}

    value = (UINT32)pSymAdrs + addend - (UINT32)pRelocAdrs;

    /* Do some checking: R_ARM_THM_PC9 relocations must fit in 9 bits */

    if (!CHECK_FITS (value, 9))
	{
        printErr ("Relocation value does not fit in 9 bits.\n");
	errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}

    if (value & 1)
	{
	printErr ("Relocation value's lowest bit is not zero.\n");
	errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}

    LOW8_INSERT (memValue, value >> 1);

    MEM_WRITE_16 (pRelocAdrs, memValue);

    return OK;
    }

/*******************************************************************************
*
* elfThumbPc11Reloc - perform the R_ARM_THM_PC11 relocation 
*
* This routine handles the R_ARM_THM_PC11 relocation (B (S - P + A) << 1).
*
* RETURNS : OK or ERROR if computed value can't be written down in target
*	    memory or offset too large for relocation.
*/

LOCAL STATUS elfThumbPc11Reloc
    (
    Elf32_Word	 sh_type,      /* Relocation sec. type (SHT_REL or SHT_RELA)  */
    void *	 pRelocAdrs,   /* Relocation address 			      */
    void *	 pSymAdrs,     /* Addr of sym involved in relocation 	      */
    Elf32_Sword  relocAddend   /* Addend from reloc. - arg used for RELA only */
    )
    {
    UINT32	value;		/* Relocation value 	    */
    UINT16	memValue;	/* Previous value in memory */
    UINT32	addend = 0;	/* Relocation addend extracted from memValue */

    MEM_READ_16 (pRelocAdrs, memValue);	

    LOW11_INSERT (addend, memValue);

    addend = addend << 1;				/* halfword offset */
    addend = SIGN_EXTEND (addend, 12);			/* sign extend */

    if (sh_type == SHT_RELA)
        {
	/* 
	 * The ARM ELF ABI specifies that with RELA, the addend is the sum 
	 * of the value extracted from the storage unit being relocated and 
	 * the addend field in the relocation instruction.  
	 */  

	addend += relocAddend;   
	}

    value = (UINT32)pSymAdrs + addend - (UINT32)pRelocAdrs;

    /* Do some checking: R_ARM_THM_PC11 relocations must fit in 12 bits */

    if (!CHECK_FITS (value, 12))
	{
        printErr ("Relocation value does not fit in 12 bits.\n");
	errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}

    if (value & 1)
	{
	printErr ("Relocation value's lowest bit is not zero.\n");
	errnoSet (S_loadElfLib_RELOC);
	return ERROR;
	}

    LOW11_INSERT (memValue, value >> 1);

    MEM_WRITE_16 (pRelocAdrs, memValue);

    return OK;
    }


/******************************************************************************
*
* elfArmModuleVerify - check the object module format for ARM target arch.
*
* This routine contains the heuristic required to determine if the object
* file belongs to the OMF handled by this OMF reader, with care for the target
* architecture.
* It is the underlying routine for loadElfModuleIsOk().
*
* RETURNS: TRUE or FALSE if the object module can't be handled.
*/

LOCAL BOOL elfArmModuleVerify
    (
    UINT32	machType,	/* Module's target arch 	    */
    BOOL *	sdaIsRequired	/* TRUE if SDA are used by the arch */
    )
    {
    BOOL	moduleIsForTarget = TRUE;   /* TRUE if intended for target */

    *sdaIsRequired = FALSE;

    if (machType != EM_ARCH_MACHINE)
	{
	moduleIsForTarget = FALSE;
	errnoSet (S_loadElfLib_HDR_READ);
	}

    return moduleIsForTarget;
    }

/******************************************************************************
*
* elfArmInit - Initialize arch-dependent parts of loader
*
* This routine initializes the function pointers for module verification
* and segment relocation.
*
* RETURNS : OK
*/

STATUS elfArmInit
    (
    FUNCPTR * pElfModuleVerifyRtn,
    FUNCPTR * pElfRelSegRtn
    )
    {
    *pElfModuleVerifyRtn = &elfArmModuleVerify;
    *pElfRelSegRtn 	 = &elfArmSegReloc;

    return OK;
    }


