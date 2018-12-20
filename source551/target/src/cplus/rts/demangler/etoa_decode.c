/******************************************************************************
*                                                             \  ___  /       *
*                                                               /   \         *
* Edison Design Group C++/C Front End                        - | \^/ | -      *
*                                                               \   /         *
*                                                             /  | |  \       *
* Copyright 1996-2002 Edison Design Group Inc.                   [_]          *
*                                                                             *
******************************************************************************/
/*
Copyright (c) 1996-2002, Edison Design Group, Inc.

Redistribution and use in source and binary forms are permitted
provided that the above copyright notice and this paragraph are
duplicated in all source code forms.  The name of Edison Design
Group, Inc. may not be used to endorse or promote products derived
from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
Any use of this software is at the user's own risk.
*/
/*

decode.c -- Name demangler for C++.

The demangling is intended to work only on names of external entities.
There is some name mangling done for internal entities, or by the
C-generating back end, that this program does not try to decode.

When IA64_ABI is defined as 1, the demangling matches the IA-64 ABI,
which in addition to its use on Itanium is used on a lot of versions of
gcc.
*/

#include "etoa_decode.h"

/* 
Notice that we have changed the semantics of IA64_ABI from the
original EDG sources. In the Diab implementation IA64_ABI TRUE
simply means that the IA64_decode_identifier function is provided.
The actual demangling style to used is autodeduced in
decode_identifier.
*/
#undef IA64_ABI
#define IA64_ABI TRUE

#ifndef DEFAULT_EMULATE_GNU_ABI_BUGS
#define DEFAULT_EMULATE_GNU_ABI_BUGS TRUE
#endif

/*
Block used to hold state variables.  A block is used so that these routines
will be reentrant.
*/
typedef struct a_decode_control_block *a_decode_control_block_ptr;
typedef struct a_decode_control_block {
  unsigned long
		input_id_len;
			/* Length of the input identifier, not counting the
			   final null. */
  char		*output_id;
			/* Pointer to buffer for demangled version of
			   the current identifier. */
  sizeof_t	output_id_len;
			/* Length of output_id, not counting the final
			   null. */
  sizeof_t	output_id_size;
			/* Allocated size of output_id. */
  a_boolean	err_in_id;
			/* TRUE if any error was encountered in the current
			   identifier. */
  a_boolean	output_overflow_err;
			/* TRUE if the demangled output overflowed the
			   output buffer. */
  unsigned long	suppress_id_output;
			/* If > 0, demangled id output is suppressed.  This
			   might be because of an error or just as a way
			   of avoiding output during some processing. */
  char		*end_of_constant;
			/* While scanning a constant, this can be set to the
			   character after the end of the constant as an
			   aid to disambiguation.  NULL otherwise. */
  sizeof_t	uncompressed_length;
			/* If non-zero, the original name was compressed,
			   and this indicates the length of the uncompressed
			   (but still mangled) name. */
#if IA64_ABI
  unsigned long	suppress_substitution_recording;
			/* If > 0, suppress recording of substitutions. */
#endif /* IA64_ABI */
#if ENABLE_GNU_LIKE_OUTPUT
  a_boolean	suppress_function_params;
			/* TRUE if we do not want to see function parameters;
			   used by GDB to compose a stack trace. */
  a_boolean	suppress_return_types;
			/* TRUE if we should avoid printing return types
			   (since they don't participate in overloading).  */
  a_boolean	sourcelike_template_params;
			/* TRUE if we should display template parameters so
			   they look like a usage in program source code.  */
#endif
} a_decode_control_block;

a_boolean is_IA64_encoded_identifier(char * id)
{
  return (id[0] == '_' && id[1] == 'Z');
}

void decode_identifier(char      *id,
                       char      *output_buffer,
                       sizeof_t  output_buffer_size,
                       a_boolean *err,
                       a_boolean *buffer_overflow_err,
                       sizeof_t  *required_buffer_size)
{

	(is_IA64_encoded_identifier(id) ? 
	 IA64_decode_identifier : 
	 cfront_decode_identifier) (id, 
				  output_buffer, 
				  output_buffer_size, 
				  err, 
				  buffer_overflow_err, 
				  required_buffer_size);
}

static void clear_control_block(a_decode_control_block_ptr dctl)
/*
Clear a decoding control block.
*/
{
  dctl->input_id_len = 0;
  dctl->output_id = NULL;
  dctl->output_id_len = 0;
  dctl->output_id_size = 0;
  dctl->err_in_id = FALSE;
  dctl->output_overflow_err = FALSE;
  dctl->suppress_id_output = 0;
  dctl->end_of_constant = NULL;
  dctl->uncompressed_length = 0;
#if IA64_ABI
  dctl->suppress_substitution_recording = 0;
#endif /* IA64_ABI */
}  /* clear_control_block */

#define demangle_type			cfront_demangle_type
#define get_number			cfront_get_number
#define demangle_name			cfront_demangle_name
#define demangle_type_specifier		cfront_demangle_type_specifier
#define skip_extern_C_indication	cfront_skip_extern_C_indication
#define demangle_type_first_part	cfront_demangle_type_first_part
#define demangle_type_second_part	cfront_demangle_type_second_part
#define demangle_type			cfront_demangle_type
#define demangle_local_name		cfront_demangle_local_name
#define decode_identifier		cfront_decode_identifier

/*
Block that contains information used to control the output of template
parameter lists.
*/
typedef struct a_template_param_block *a_template_param_block_ptr;
typedef struct a_template_param_block {
  unsigned long	nesting_level;
			/* Number of levels of template nesting at this
			   point (1 == top level). */
  char		*final_specialization;
			/* Set to point to the mangled encoding for the final
			   specialization encountered while working from
			   outermost template to innermost.  NULL if
			   no specialization has been found yet. */
  a_boolean	set_final_specialization;
			/* TRUE if final_specialization should be set while
			   scanning. */
  a_boolean	actual_template_args_until_final_specialization;
			/* TRUE if template parameter names should not be
			   put out.  Reset when the final_specialization
			   position is reached. */
  a_boolean	output_only_correspondences;
			/* TRUE if doing a post-pass to output only template
			   parameter/argument correspondences and not
			   anything else.  suppress_id_output will have been
			   incremented to suppress everything else, and
			   gets decremented temporarily when correspondences
			   are output. */
  a_boolean	first_correspondence;
			/* TRUE until the first template parameter/argument
			   correspondence is put out. */
  a_boolean	use_old_form_for_template_output;
			/* TRUE if templates should be output in the old
			   form that always puts actual argument values
			   in template argument lists. */
#if ENABLE_GNU_LIKE_OUTPUT
  a_boolean	base_name_only;
			/* TRUE if we are printing a bare basename, without
			   template parameters; this is used for printing the
			   implicit names of Constructors and Destructors. */
#endif
} a_template_param_block;


/*
Declarations needed because of forward references:
*/
static char *demangle_name_with_preceding_length(
                                char                       *ptr,
                                a_boolean                  allow_member,
                                a_template_param_block_ptr temp_par_info,
                                a_decode_control_block_ptr dctl);
static char *demangle_operation(char                       *ptr,
                                a_decode_control_block_ptr dctl);
static char *demangle_operator(char      *ptr,
                               int       *mangled_length,
                               a_boolean *takes_type);
static char *demangle_type(char                       *ptr,
                           a_decode_control_block_ptr dctl);
static char *full_demangle_type_name(char                       *ptr,
                                     a_boolean                  base_name_only,
                                     a_template_param_block_ptr temp_par_info,
                                     a_decode_control_block_ptr dctl);
static char *demangle_template_arguments(
                                      char                       *ptr,
                                      a_boolean                  partial_spec,
                                      a_template_param_block_ptr temp_par_info,
                                      a_decode_control_block_ptr dctl);
/*
Interface to full_demangle_type_name for the simple case.
*/
#define demangle_type_name(ptr, dctl)                                 \
  full_demangle_type_name((ptr), /*base_name_only=*/FALSE,            \
                          /*temp_par_info=*/(a_template_param_block_ptr)NULL, \
                          (dctl))
static char *full_demangle_identifier(char                       *ptr,
                                      unsigned long              nchars,
                                      a_decode_control_block_ptr dctl);
/* Interface to full_demangle_identifier for the simple case. */
#define demangle_identifier(ptr, dctl)                                \
  full_demangle_identifier((ptr), (unsigned long)0, (dctl))


static void write_id_ch(char                       ch,
                        a_decode_control_block_ptr dctl)
/*
Add the indicated character to the demangled version of the current identifier.
*/
{
  if (!dctl->suppress_id_output) {
    if (!dctl->output_overflow_err) {
      /* Test for buffer overflow, leaving room for a terminating null. */
      if (dctl->output_id_len+1 >= dctl->output_id_size) {
        /* There's no room for the character in the buffer. */
        dctl->output_overflow_err = TRUE;
        /* Make sure the (truncated) output is null-terminated. */
        if (dctl->output_id_size != 0) {
          dctl->output_id[dctl->output_id_size-1] = '\0';
        }  /* if */
      } else {
        /* No overflow; put the character in the buffer. */
        dctl->output_id[dctl->output_id_len] = ch;
      }  /* if */
    }  /* if */
    /* Keep track of the number of characters (even if output has overflowed
       the buffer). */
    dctl->output_id_len++;
  }  /* if */
}  /* write_id_ch */


static void write_id_str(char                      *str,
                        a_decode_control_block_ptr dctl)
/*
Add the indicated string to the demangled version of the current identifier.
*/
{
  char *p = str;

  if (!dctl->suppress_id_output) {
    for (; *p != '\0'; p++) write_id_ch(*p, dctl);
  }  /* if */
}  /* write_id_str */


static void bad_mangled_name(a_decode_control_block_ptr dctl)
/*
A bad name mangling has been encountered.  Record an error.
*/
{
  if (!dctl->err_in_id) {
    dctl->err_in_id = TRUE;
    dctl->suppress_id_output++;
#if IA64_ABI
    dctl->suppress_substitution_recording++;
#endif /* IA64_ABI */
  }  /* if */
}  /* bad_mangled_name */


static a_boolean start_of_id_is(char *str, char *id)
/*
Return TRUE if the identifier (at id) begins with the string str.
*/
{
  a_boolean is_start = FALSE;

  for (;;) {
    char chs = *str++;
    if (chs == '\0') {
      is_start = TRUE;
      break;
    }  /* if */
    if (chs != *id++) break;
  }  /* for */
  return is_start;
}  /* start_of_id_is */


static char *advance_past(char                       ch,
                          char                       *p,
                          a_decode_control_block_ptr dctl)
/*
The character ch is expected at *p.  If it's there, advance past it.  If
not, call bad_mangled_name.  In either case, return the updated value of p.
*/
{
  if (*p == ch) {
    p++;
  } else {
    bad_mangled_name(dctl);
  }  /* if */
  return p;
}  /* advance_past */


static char *advance_past_underscore(char                       *p,
                                     a_decode_control_block_ptr dctl)
/*
An underscore is expected at *p.  If it's there, advance past it.  If
not, call bad_mangled_name.  In either case, return the updated value of p.
*/
{
  return advance_past('_', p, dctl);
}  /* advance_past_underscore */


static char *get_length(char                       *p,
                        unsigned long              *num,
                        a_decode_control_block_ptr dctl)
/*
Accumulate a number indicating a length, starting at position p, and
return its value in *num.  Return a pointer to the character position
following the number.
*/
{
  unsigned long n = 0;

  if (!isdigit((unsigned char)*p)) {
    bad_mangled_name(dctl);
    goto end_of_routine;
  }  /* if */
  do {
    n = n*10 + (*p - '0');
    if (n > dctl->input_id_len) {
      /* Bad number. */
      bad_mangled_name(dctl);
      n = dctl->input_id_len;
      goto end_of_routine;
    }  /* if */
    p++;
  } while (isdigit((unsigned char)*p));
end_of_routine:
  *num = n;
  return p;
}  /* get_length */


static char *get_number(char                       *p,
                        unsigned long              *num,
                        a_decode_control_block_ptr dctl)
/*
Accumulate a number starting at position p and return its value in *num.
Return a pointer to the character position following the number.
*/
{
  unsigned long n = 0;

  if (!isdigit((unsigned char)*p)) {
    bad_mangled_name(dctl);
    goto end_of_routine;
  }  /* if */
  do {
    n = n*10 + (*p - '0');
    p++;
  } while (isdigit((unsigned char)*p));
end_of_routine:
  *num = n;
  return p;
}  /* get_number */


static char *get_single_digit_number(char                       *p,
                                     unsigned long              *num,
                                     a_decode_control_block_ptr dctl)
/*
Accumulate a number starting at position p and return its value in *num.
The number is a single digit.  Return a pointer to the character position
following the number.
*/
{
  *num = 0;
  if (!isdigit((unsigned char)*p)) {
    bad_mangled_name(dctl);
    goto end_of_routine;
  }  /* if */
  *num = (*p - '0');
  p++;
end_of_routine:
  return p;
}  /* get_single_digit_number */


static char *get_length_with_optional_underscore(
                                               char                       *p,
                                               unsigned long              *num,
                                               a_decode_control_block_ptr dctl)
/*
Accumulate a number starting at position p and return its value in *num.
If the number has more than one digit, it is followed by an underscore.
(Or, in a newer representation, surrounded by underscores.)
Return a pointer to the character position following the number.
*/
{
  if (*p == '_') {
    /* New encoding (not from cfront) -- the length is surrounded by
       underscores whether it's a single digit or several digits,
       e.g., "L_10_1234567890". */
    p++;
    /* Multi-digit number followed by underscore. */
    p = get_length(p, num, dctl);
    p = advance_past_underscore(p, dctl);
  } else if (isdigit((unsigned char)p[0]) && isdigit((unsigned char)p[1]) &&
             (dctl->end_of_constant == NULL || p+2 < dctl->end_of_constant) &&
             p[2] == '_') {
    /* The cfront version -- a multi-digit length is followed by an
       underscore, e.g., "L10_1234567890".  This doesn't work well because
       something like "L11", intended to have a one-digit length, can
       be made ambiguous by following it by a "_" for some other reason.
       (That's resolved in most cases by the check against end_of_constant.)
       So this form is not used in new cases where that can come up, e.g.,
       nontype template arguments for functions.  In any case, interpret
       "multi-digit" as "2-digit" and don't look further for the underscore. */
    /* Multi-digit number followed by underscore. */
    p = get_length(p, num, dctl);
    p = advance_past_underscore(p, dctl);
  } else {
    /* Single-digit number not followed by underscore. */
    p = get_single_digit_number(p, num, dctl);
  }  /* if */
  return p;
}  /* get_length_with_optional_underscore */


static a_boolean is_immediate_type_qualifier(char *p)
/*
Return TRUE if the encoding pointed to is one that indicates type
qualification.
*/
{
  a_boolean is_type_qual = FALSE;

  if (*p == 'C' || *p == 'V') {
    /* This is a type qualifier. */
    is_type_qual = TRUE;
  }  /* if */
  return is_type_qual;
}  /* is_immediate_type_qualifier */


static void write_template_parameter_name(unsigned long              depth,
                                          unsigned long              position,
                                          a_boolean                  nontype,
                                          a_decode_control_block_ptr dctl)
/*
Output a representation of a template parameter with depth and position
as indicated.  It's a nontype parameter if nontype is TRUE.
*/
{
  char buffer[100];
  char letter = '\0';

  if (nontype) {
    /* Nontype parameter. */
    /* Use a code letter for the first few levels, then the depth number. */
    if (depth == 1) {
      letter = 'N';
    } else if (depth == 2) {
      letter = 'O';
    } else if (depth == 3) {
      letter = 'P';
    }  /* if */
    if (letter != '\0') {
      (void)sprintf(buffer, "%c%lu", letter, position);
    } else {
      (void)sprintf(buffer, "N_%lu_%lu", depth, position);
    }  /* if */
  } else {
    /* Normal type parameter. */
    /* Use a code letter for the first few levels, then the depth number. */
    if (depth == 1) {
      letter = 'T';
    } else if (depth == 2) {
      letter = 'U';
    } else if (depth == 3) {
      letter = 'V';
    }  /* if */
    if (letter != '\0') {
      (void)sprintf(buffer, "%c%lu", letter, position);
    } else {
      (void)sprintf(buffer, "T_%lu_%lu", depth, position);
    }  /* if */
  }  /* if */
  write_id_str(buffer, dctl);
}  /* write_template_parameter_name */


static char *demangle_template_parameter_name(
                                            char                       *ptr,
                                            a_boolean                  nontype,
                                            a_decode_control_block_ptr dctl)
/*
Demangle a template parameter name at the indicated location.  The parameter
is a nontype parameter if nontype is TRUE.  Return a pointer to the character
position following what was demangled.
*/
{
  char          *p = ptr;
  unsigned long position, depth = 1;

  /* This comes up with the modern mangling for template functions.
     Form is "ZnZ" or "Zn_mZ", where n is the parameter number and m
     is the depth number (1 if not specified). */
  p++;  /* Advance past the "Z". */
  /* Get the position number. */
  p = get_number(p, &position, dctl);
  if (*p == '_' && p[1] != '_') {
    /* Form including depth ("Zn_mZ"). */
    p++;
    p = get_number(p, &depth, dctl);
  }  /* if */
  /* Output the template parameter name. */
  write_template_parameter_name(depth, position, nontype, dctl);
  if (p[0] == '_' && p[1] == '_' && p[2] == 't' && p[3] == 'm' &&
      p[4] == '_' && p[5] == '_') {
    /* A template template parameter followed by a template
       argument list. */
    p = demangle_template_arguments(p+6, /*partial_spec=*/FALSE,
                                    (a_template_param_block_ptr)NULL, dctl);
  }  /* if */
  /* Check for the final "Z".  This appears in the mangling to avoid
     ambiguities when the template parameter is followed by something whose
     encoding begins with a digit, e.g., a class name. */
  if (*p != 'Z') {
    bad_mangled_name(dctl);
  } else {
    p++;
  }  /* if */
  return p;
}  /* demangle_template_parameter_name */


static char *demangle_constant(char                       *ptr,
                               a_decode_control_block_ptr dctl)
/*
Demangle a constant (e.g., a nontype template class argument) beginning at
ptr, and output the demangled form.  Return a pointer to the character
position following what was demangled.
*/
{
  char          *p = ptr, *type = NULL, *index;
  unsigned long nchars;

  /* A constant has a form like
       CiL15   <-- integer constant 5
           ^-- Literal constant representation.
          ^--- Length of literal constant.
         ^---- L indicates literal constant; c indicates address
               of variable, etc.
       ^^----- Type of template argument, with "const" added.
     A template parameter constant or a constant expression does not have
     the initial "C" and type.
  */
  if (*p == 'C') {
    /* Advance past the type. */
    type = p;
    dctl->suppress_id_output++;
    p = demangle_type(p, dctl);
    dctl->suppress_id_output--;
  }  /* if */
  /* The next thing has one of the following forms:
       3abc        Address of "abc".
       L211        Literal constant; length ("2") followed by the characters of
                   the constant ("11").
       LM0_L2n1_1j Pointer-to-member-function constant; the three parts
                   correspond to the triplet of values in the __mptr
                   data structure.
       Z1Z         Template parameter.
       Opl2Z1ZZ2ZO Expression.
  */
  if (isdigit((unsigned char)*p)) {
    /* A name preceded by its length, e.g., "3abc".  Put out "&name". */
    write_id_ch('&', dctl);
    /* Process the length and name. */
    p = demangle_name_with_preceding_length(p, /*allow_member=*/TRUE,
                                            (a_template_param_block_ptr)NULL,
                                            dctl);
  } else if (*p == 'L') {
    if (p[1] != 'M') {
      /* Normal literal constant.  Form is something like
           L3n12     encoding for -12
             ^^^---- Characters of constant.  Some characters get remapped:
                       n --> -
                       p --> +
                       d --> .
            ^------- Length of constant.
         Output is
           (type)constant
         That is, the literal constant preceded by a cast to the right type.
      */
      /* See if the type is bool. */
      a_boolean is_bool = (type+2 == p && *(type+1) == 'b'), is_nonzero;
      /* If the type is bool, don't put out the cast. */
      if (!is_bool) {
        write_id_ch('(', dctl);
        /* Start at type+1 to avoid the "C" for const. */
        (void)demangle_type(type+1, dctl);
        write_id_ch(')', dctl);
      }  /* if */
      p++;  /* Advance past the "L". */
      /* Get the length of the constant. */
      p = get_length_with_optional_underscore(p, &nchars, dctl);
      /* Process the characters of the literal constant. */
      is_nonzero = FALSE;
      for (; nchars > 0; nchars--, p++) {
        /* Remap characters where necessary. */
        char ch = *p;
        switch (ch) {
          case '\0':
          case '_':
            /* Ran off end of string. */
            bad_mangled_name(dctl);
            goto end_of_routine;
          case 'p':
            ch = '+';
            break;
          case 'n':
            ch = '-';
            break;
          case 'd':
            ch = '.';
            break;
        }  /* switch */
        if (is_bool) {
          /* For the bool case, just keep track of whether the constant is
             non-zero; true or false will be output later. */
          if (ch != '0') is_nonzero = TRUE;
        } else {
          /* Normal (non-bool) case.  Output the character of the constant. */
          write_id_ch(ch, dctl);
        }  /* if */
      }  /* for */
      if (is_bool) {
        /* For bool, output true or false. */
        write_id_str((char *)(is_nonzero ? "true" : "false"), dctl);
      }  /* if */
    } else {
      /* Pointer-to-member-function.  The form of the constant is
           LM0_L2n1_1j  Non-virtual function
           LM0_L11_0    Virtual function
           LM0_L10_0    Null pointer
         The three parts match the three components of the __mptr structure:
         (delta, index, function or offset).  The index is -1 for a non-virtual
         function, 0 for a null pointer, and greater than 0 for a virtual
         function.  The index is represented like an integer constant (see
         above).  For virtual functions, the last component is always "0"
         even if the offset is not zero. */
      /* Advance past the "LM". */
      p += 2;
      /* Advance over the first component, ignoring it. */
      while (isdigit((unsigned char)*p)) p++;
      p = advance_past_underscore(p, dctl);
      /* The index component should be next. */
      if (*p != 'L') {
        bad_mangled_name(dctl);
        goto end_of_routine;
      }  /* if */
      p++;
      /* Get the index length. */
      /* Note that get_length_with_optional_underscore is not used because
         this is an ambiguous situation: an underscore follows the index
         value, and there's no way to tell if it's the multi-digit
         indicator for the length or the separator between fields. */
      if (*p == '_') {
        /* New-form encoding, no ambiguity. */
        p = get_length_with_optional_underscore(p, &nchars, dctl);
      } else {
        p = get_single_digit_number(p, &nchars, dctl);
      }  /* if */
      /* Remember the start of the index. */
      index = p;
      /* Skip the rest of the index. */
      while (isdigit((unsigned char)*p) || (*p == 'n')) p++;
      p = advance_past_underscore(p, dctl);
      /* If the index number starts with 'n', this is a non-virtual
         function. */
      if (*index == 'n') {
        /* Non-virtual function. */
        /* The third component is a name preceded by its length, e.g.,
           "1f".  Put out "&A::f", where "A" is the class type retrieved
           from the type. */
        write_id_ch('&', dctl);
        /* Start at type+2 to skip the "C" for const and the "M" for
           pointer-to-member. */
        (void)demangle_type_name(type+2, dctl);
        write_id_str("::", dctl);
        /* Demangle the length and name. */
        p = demangle_name_with_preceding_length(p, /*allow_member=*/FALSE,
                                              (a_template_param_block_ptr)NULL,
                                                dctl);
      } else {
        /* Not a non-virtual function.  The encoding for the third component
           should be simply "0". */
        if (*p != '0') {
          bad_mangled_name(dctl);
          goto end_of_routine;
        }  /* if */
        p++;
        if (nchars == 1 && *index == '0') {
          /* Null pointer constant.  Output "(type)0", that is, a zero cast
             to the pointer-to-member type. */
          write_id_ch('(', dctl);
          (void)demangle_type(type, dctl);
          write_id_str(")0", dctl);
        } else {
          /* Virtual function.  This case can't really be demangled properly,
             because the mangled name doesn't have enough information.
             Output "&A::virtual-function-n". */
          write_id_ch('&', dctl);
          /* Start at type+2 to skip the "C" for const and the "M" for
             pointer-to-member. */
          (void)demangle_type_name(type+2, dctl);
          write_id_str("::", dctl);
          write_id_str("virtual-function-", dctl);
          /* Write the index number. */
          for (; nchars > 0; nchars--, index++) write_id_ch(*index, dctl);
        }  /* if */
      }  /* if */
    }  /* if */
  } else if (*p == 'Z') {
    /* A template parameter. */
    p = demangle_template_parameter_name(p, /*nontype=*/TRUE, dctl);
  } else if (*p == 'O') {
    /* An operation. */
    p = demangle_operation(p, dctl);
  } else {
    /* The constant starts with something unexpected. */
    bad_mangled_name(dctl);
  }  /* if */
end_of_routine:
  return p;
}  /* demangle_constant */


static char *demangle_operation(char                       *ptr,
                                a_decode_control_block_ptr dctl)
/*
Demangle an operation in a constant expression (these come up in template
arguments and array sizes, in template function parameter lists) beginning
at ptr, and output the demangled form.  Return a pointer to the character
position following what was demangled.
*/
{
  char          *p = ptr, *operator_str, *close_str = "";
  int           op_length;
  unsigned long num_operands;
  a_boolean     takes_type;

  /* An operation has the form
       Opl2Z1ZZ2ZO <-- "Z1 + Z2", Z1/Z2 indicating nontype template parameters.
                 ^---- "O" to end the operation encoding.
              ^^^----- Second operand.
           ^^^-------- First operand.
          ^----------- Count of operands.
        ^^------------ Operation, using same encoding as for operator
                       function names.
       ^-------------- "O" for operation.
  */
  p++;  /* Advance past the "O". */
  /* Decode the operator name, e.g., "pl" is "+". */
  operator_str = demangle_operator(p, &op_length, &takes_type);
  if (operator_str == NULL) {
    bad_mangled_name(dctl);
  } else {
    p += op_length;
    /* Put parentheses around the operation. */
    write_id_ch('(', dctl);
    /* For a cast, sizeof, or __alignof__, get the type. */
    if (takes_type) {
      if (strcmp(operator_str, "cast") == 0) {
        write_id_ch('(', dctl);
        operator_str = "";
      } else {
        write_id_str(operator_str, dctl);
      }  /* if */
      if (*p == 'e') {
        /* "e" indicates a sizeof (etc.) based on an expression.  Do not
           scan the type.  Note that the expression is not present either. */
        write_id_str("expr", dctl);
        p++;
      } else {
        p = demangle_type(p, dctl);
      }  /* if */
      write_id_ch(')', dctl);
    }  /* if */
    /* Get the count of operands. */
    p = get_single_digit_number(p, &num_operands, dctl);
    /* sizeof and __alignof__ take zero operands. */
    if (num_operands != 0) {
      if (num_operands == 1) {
        /* Unary operator -- operator comes first. */
        write_id_str(operator_str, dctl);
      }  /* if */
      /* Process the first operand. */
      p = demangle_constant(p, dctl);
      if (num_operands > 1) {
        /* Binary and ternary operators -- operator comes after first
           operand. */
        if (strcmp(operator_str, "[]") == 0) {
          /* For subscripting, put one "[" between the operands and one
             at the end. */
          operator_str = "[";
          close_str = "]";
        }  /* if */
        write_id_str(operator_str, dctl);
        /* Process the second operand. */
        p = demangle_constant(p, dctl);
        if (num_operands > 2) {
          /* Ternary operand -- "?". */
          write_id_ch(':', dctl);
          /* Process the third operand. */
          p = demangle_constant(p, dctl);
        }  /* if */
      }  /* if */
    }  /* if */
    write_id_str(close_str, dctl);
    write_id_ch(')', dctl);
    /* Check for the final "O". */
    if (*p != 'O') {
      bad_mangled_name(dctl);
    } else {
      p++;
    }  /* if */
  }  /* if */
  return p;
}  /* demangle_operation */


static void clear_template_param_block(a_template_param_block_ptr tpbp)
/*
Clear the fields of the indicated template parameter block.
*/
{
  tpbp->nesting_level = 0;
  tpbp->final_specialization = NULL;
  tpbp->set_final_specialization = FALSE;
  tpbp->actual_template_args_until_final_specialization = FALSE;
  tpbp->output_only_correspondences = FALSE;
  tpbp->first_correspondence = FALSE;
  tpbp->use_old_form_for_template_output = FALSE;
#if ENABLE_GNU_LIKE_OUTPUT
  tpbp->base_name_only = FALSE;
#endif
}  /* clear_template_param_block */


static char *demangle_template_arguments(
                                      char                       *ptr,
                                      a_boolean                  partial_spec,
                                      a_template_param_block_ptr temp_par_info,
                                      a_decode_control_block_ptr dctl)
/*
Demangle the template class arguments beginning at ptr and output the
demangled form.  Return a pointer to the character position following what was
demangled.  ptr points to just past the "__tm__", "__ps__", or "__pt__"
string.  partial_spec is TRUE if this is a partial-specialization
parameter list ("__ps__").  When temp_par_info != NULL, it points to a
block that controls output of extra information on template parameters.
*/
{
  char          *p = ptr, *arg_base;
  unsigned long nchars, position;
  a_boolean     nontype, skipped, unskipped;

  if (temp_par_info != NULL && !partial_spec) temp_par_info->nesting_level++;
  /* A template argument list looks like
       __tm__3_ii
               ^^---- Argument types.
             ^------- Size of argument types, including the underscore.
             ^------- ptr points here.
     For the first argument list of a partial specialization, "__tm__" is
     replaced by "__ps__".  For old-form mangling of templates, "__tm__"
     is replaced by "__pt__".
  */
  write_id_ch('<', dctl);
  /* Scan the size. */
  p = get_length(p, &nchars, dctl);
  arg_base = p;
  p = advance_past_underscore(p, dctl);
  /* Loop to process the arguments. */
  for (position = 1;; position++) {
    if (dctl->err_in_id) break;  /* Avoid infinite loops on errors. */
    if (*p == '\0' || *p == '_') {
      /* We ran off the end of the string. */
      bad_mangled_name(dctl);
      break;
    }  /* if */
    /* "X" identifies the beginning of a nontype argument. */
    nontype = (*p == 'X');
    skipped = unskipped = FALSE;
    if (!partial_spec && temp_par_info != NULL &&
        !temp_par_info->use_old_form_for_template_output &&
        !temp_par_info->actual_template_args_until_final_specialization) {
      /* Doing something special: writing out the template parameter name. */
      if (temp_par_info->output_only_correspondences) {
        /* This is the second pass, which writes out parameter/argument
           correspondences, e.g., "T1=int".  Output has been suppressed
           in general, and is turned on briefly here. */
        dctl->suppress_id_output--;
        unskipped = TRUE;
        /* Put out a comma between entries and a left bracket preceding the
           first entry. */
        if (temp_par_info->first_correspondence) {
          write_id_str(" [with ", dctl);
          temp_par_info->first_correspondence = FALSE;
        } else {
          write_id_str(", ", dctl);
        }  /* if */
      }  /* if */
      /* Write the template parameter name. */
      write_template_parameter_name(temp_par_info->nesting_level, position,
                                    nontype, dctl);
      if (temp_par_info->output_only_correspondences) {
        /* This is the second pass, to write out correspondences, so put the
           argument value out after the parameter name. */
        write_id_ch('=', dctl);
      } else {
        /* This is the first pass.  The argument value is skipped.  In
           the second pass, its value will be written out. */
        /* We still have to scan over the argument value, but suppress
           output. */
        dctl->suppress_id_output++;
        skipped = TRUE;
      }  /* if */
    }  /* if */
    /* Write the argument value. */
    if (nontype) {
      /* Nontype argument. */
      char *saved_end_of_constant = dctl->end_of_constant;
      p++;  /* Advance past the "X". */
      /* Note the end position of the constant.  This is used to decide
         that certain lengths are implausible as a way to resolve
         ambiguities. */
      dctl->end_of_constant = arg_base + nchars;
      p = demangle_constant(p, dctl);
      dctl->end_of_constant = saved_end_of_constant;
    } else {
      /* Type argument. */
      p = demangle_type(p, dctl);
    }  /* if */
    if (skipped) dctl->suppress_id_output--;
    if (unskipped) dctl->suppress_id_output++;
    /* Stop after the last argument. */
    if ((p - arg_base) >= nchars) break;
    write_id_str(", ", dctl);
  }  /* for */
  write_id_ch('>', dctl);
  return p;
}  /* demangle_template_arguments */


static char *demangle_operator(char      *ptr,
                               int       *mangled_length,
                               a_boolean *takes_type)
/*
Examine the first few characters at ptr to see if they are an encoding for
an operator (e.g., "pl" for plus).  If so, return a pointer to a string for
the operator (e.g., "+"), set *mangled_length to the number of characters
in the encoding, and *takes_type to TRUE if the operator takes a type
modifier (e.g., cast).  If the first few characters are not an operator
encoding, return NULL.
*/
{
  char *s;
  int  len = 2;

  *takes_type = FALSE;
  /* The length-3 codes are tested first to avoid taking their first two
     letters as one of the length-2 codes. */
  if (start_of_id_is("apl", ptr)) {
    s = "+=";
    len = 3;
  } else if (start_of_id_is("ami", ptr)) {
    s = "-=";
    len = 3;
  } else if (start_of_id_is("amu", ptr)) {
    s = "*=";
    len = 3;
  } else if (start_of_id_is("adv", ptr)) {
    s = "/=";
    len = 3;
  } else if (start_of_id_is("amd", ptr)) {
    s = "%=";
    len = 3;
  } else if (start_of_id_is("aer", ptr)) {
    s = "^=";
    len = 3;
  } else if (start_of_id_is("aad", ptr)) {
    s = "&=";
    len = 3;
  } else if (start_of_id_is("aor", ptr)) {
    s = "|=";
    len = 3;
  } else if (start_of_id_is("ars", ptr)) {
    s = ">>=";
    len = 3;
  } else if (start_of_id_is("als", ptr)) {
    s = "<<=";
    len = 3;
  } else if (start_of_id_is("nwa", ptr)) {
    s = "new[]";
    len = 3;
  } else if (start_of_id_is("dla", ptr)) {
    s = "delete[]";
    len = 3;
  } else if (start_of_id_is("nw", ptr)) {
    s = "new";
  } else if (start_of_id_is("dl", ptr)) {
    s = "delete";
  } else if (start_of_id_is("pl", ptr)) {
    s = "+";
  } else if (start_of_id_is("mi", ptr)) {
    s = "-";
  } else if (start_of_id_is("ml", ptr)) {
    s = "*";
  } else if (start_of_id_is("dv", ptr)) {
    s = "/";
  } else if (start_of_id_is("md", ptr)) {
    s = "%";
  } else if (start_of_id_is("er", ptr)) {
    s = "^";
  } else if (start_of_id_is("ad", ptr)) {
    s = "&";
  } else if (start_of_id_is("or", ptr)) {
    s = "|";
  } else if (start_of_id_is("co", ptr)) {
    s = "~";
  } else if (start_of_id_is("nt", ptr)) {
    s = "!";
  } else if (start_of_id_is("as", ptr)) {
    s = "=";
  } else if (start_of_id_is("lt", ptr)) {
    s = "<";
  } else if (start_of_id_is("gt", ptr)) {
    s = ">";
  } else if (start_of_id_is("ls", ptr)) {
    s = "<<";
  } else if (start_of_id_is("rs", ptr)) {
    s = ">>";
  } else if (start_of_id_is("eq", ptr)) {
    s = "==";
  } else if (start_of_id_is("ne", ptr)) {
    s = "!=";
  } else if (start_of_id_is("le", ptr)) {
    s = "<=";
  } else if (start_of_id_is("ge", ptr)) {
    s = ">=";
  } else if (start_of_id_is("aa", ptr)) {
    s = "&&";
  } else if (start_of_id_is("oo", ptr)) {
    s = "||";
  } else if (start_of_id_is("pp", ptr)) {
    s = "++";
  } else if (start_of_id_is("mm", ptr)) {
    s = "--";
  } else if (start_of_id_is("cm", ptr)) {
    s = ",";
  } else if (start_of_id_is("rm", ptr)) {
    s = "->*";
  } else if (start_of_id_is("rf", ptr)) {
    s = "->";
  } else if (start_of_id_is("cl", ptr)) {
    s = "()";
  } else if (start_of_id_is("vc", ptr)) {
    s = "[]";
  } else if (start_of_id_is("qs", ptr)) {
    s = "?";
  } else if (start_of_id_is("cs", ptr)) {
    s = "cast";
    *takes_type = TRUE;
  } else if (start_of_id_is("sz", ptr)) {
    s = "sizeof(";
    *takes_type = TRUE;
  } else if (start_of_id_is("af", ptr)) {
    s = "__alignof__(";
    *takes_type = TRUE;
  } else if (start_of_id_is("uu", ptr)) {
    s = "__uuidof(";
    *takes_type = TRUE;
  } else {
    s = NULL;
  }  /* if */
  *mangled_length = len;
  return s;
}  /* demangle_operator */


static a_boolean is_operator_function_name(char *ptr,
                                           char **demangled_name,
                                           int  *mangled_length)
/*
Examine the string beginning at ptr to see if it is the mangled name for
an operator function.  If so, return TRUE and set *demangled_name to
the demangled form, and *mangled_length to the length of the mangled form.
*/
{
  char      *s, *end_ptr;
  int       len;
  a_boolean takes_type;

  /* Get the operator name.*/
  s = demangle_operator(ptr, &len, &takes_type);
  if (s != NULL) {
    /* Make sure we took the whole name and nothing more. */
    end_ptr = ptr + len;
    if (*end_ptr == '\0' || (end_ptr[0] == '_' && end_ptr[1] == '_')) {
      /* Okay. */
    } else {
      s = NULL;
    }  /* if */
  }  /* if */
  *demangled_name = s;
  *mangled_length = len;
  return (s != NULL);
}  /* is_operator_function_name */


static void note_specialization(char                       *ptr,
                                a_template_param_block_ptr temp_par_info)
/*
Note the fact that a specialization indication has been encountered at ptr
while scanning a mangled name.  temp_par_info, if non-NULL, points to
a block of information related to template parameter processing.
*/
{
  if (temp_par_info != NULL) {
    if (temp_par_info->set_final_specialization) {
      /* Remember the location of the last specialization seen. */
      temp_par_info->final_specialization = ptr;
    } else if (temp_par_info->actual_template_args_until_final_specialization&&
               ptr == temp_par_info->final_specialization) {
      /* Stop doing the special processing for specializations when the
         final specialization is reached. */
      temp_par_info->actual_template_args_until_final_specialization = FALSE;
    }  /* if */
  }  /* if */
}  /* note_specialization */


static char get_char(char          *ptr,
                     char          *base_ptr,
                     unsigned long nchars)
/*
Get and return the character pointed to by ptr.  However, if nchars is
non-zero, the string from which the character is to be extracted starts
at base_ptr and has length nchars.  An attempt to get a character past
the end of the string returns a null character.
*/
{
  char ch;

  if (nchars > 0 && ptr >= base_ptr+nchars) {
    ch = '\0';
  } else {
    ch = *ptr;
  }  /* if */
  return ch;
}  /* get_char */


static char *demangle_name(char                       *ptr,
                           unsigned long              nchars,
                           a_boolean                  stop_on_underscores,
                           unsigned long              *nchars_left,
                           char                       *mclass,
                           a_template_param_block_ptr temp_par_info,
                           a_decode_control_block_ptr dctl)
/*
Demangle the name at ptr and output the demangled form.  Return a pointer
to the character position following what was demangled.  A "name" is
usually just a string of alphanumeric characters.  However, names of
constructors, destructors, and operator functions require special
handling, as do template entity names.  nchars indicates the number
of characters in the name, or is zero if the name is open-ended
(it's ended by a null or double underscore).  A double underscore
ends the name if stop_on_underscores is TRUE (though some sequences
beginning with two underscores, e.g., "__pt", end the name even if
stop_on_underscores is FALSE).  If nchars_left is non-NULL, no
error is issued if too few characters are taken to satisfy nchars;
the count of remaining characters is placed in *nchars_left.
mclass, when non-NULL, points to the mangled form of the class of
which this name is a member.  When it's non-NULL, constructor and
destructor names will be put out in the proper form (otherwise,
they are left in their original forms).  When temp_par_info != NULL,
it points to a block that controls output of extra information on
template parameters.
*/
{
  char      *p, *end_ptr = NULL;
  a_boolean is_special_name = FALSE, is_pt, is_partial_spec = FALSE;
  a_boolean partial_spec_output_suppressed = FALSE;
  char      *demangled_name;
  int       mangled_length;

  if (nchars_left != NULL) *nchars_left = 0;
  /* See if the name is special in some way. */
  if ((nchars == 0 || nchars >= 3) && ptr[0] == '_' && ptr[1] == '_') {
    /* Name beginning with two underscores. */
    p = ptr + 2;
    if (start_of_id_is("ct", p)) {
      /* Constructor. */
      end_ptr = p + 2;
      if (mclass == NULL) {
        /* The mangled name for the class is not provided, so handle this as
           a normal name. */
      } else {
        /* Output the class name for the constructor name. */
        is_special_name = TRUE;
        (void)full_demangle_type_name(mclass, /*base_name_only=*/TRUE,
                                      /*temp_par_info=*/
                                              (a_template_param_block_ptr)NULL,
                                      dctl);
      }  /* if */
    } else if (start_of_id_is("dt", p)) {
      /* Destructor. */
      end_ptr = p + 2;
      if (mclass == NULL) {
        /* The mangled name for the class is not provided, so handle this as
           a normal name. */
      } else {
        /* Output ~class-name for the destructor name. */
        is_special_name = TRUE;
        write_id_ch('~', dctl);
        (void)full_demangle_type_name(mclass, /*base_name_only=*/TRUE,
                                      /*temp_par_info=*/
                                              (a_template_param_block_ptr)NULL,
                                      dctl);
      }  /* if */
    } else if (start_of_id_is("op", p)) {
      /* Conversion function.  Name looks like __opi__... where the part
         after "op" encodes the type (e.g., "opi" is "operator int"). */
      is_special_name = TRUE;
      write_id_str("operator ", dctl);
      end_ptr = demangle_type(p+2, dctl);
    } else if (is_operator_function_name(p, &demangled_name,
                                         &mangled_length)) {
      /* Operator function. */
      is_special_name = TRUE;
      write_id_str("operator ", dctl);
      write_id_str(demangled_name, dctl);
      end_ptr = p + mangled_length;
    } else if (nchars != 0 && start_of_id_is("N", p)) {
      /* __Nxxxx: unnamed namespace name.  Put out "<unnamed>" and ignore
         the characters after "__N".  For nested unnamed namespaces there
         is no number after the "__N". */
      is_special_name = TRUE;
      write_id_str("<unnamed>", dctl);
      end_ptr = p + nchars - 2;
    } else {
      /* Something unrecognized. */
    }  /* if */
  }  /* if */
  /* Here, end_ptr non-null means the end of the string has been found
     already (because the name is special in some way). */
  if (end_ptr == NULL) {
    /* Not a special name. Find the end of the string and set end_ptr.
       Also look for template-related things that terminate the name
       earlier. */
    for (p = ptr; ; p++) {
      char ch = get_char(p, ptr, nchars);
      /* Stop at the end of the string (real, or as indicated by nchars). */
      if (ch == '\0') break;
      /* Stop on a double underscore, but not one at the start of the string.
         More than 2 underscores in a row does not terminate the string,
         so that something like the name for "void f_()" (i.e., "f___Fv")
         can be demangled successfully. */
      if (ch == '_' && p != ptr &&
          get_char(p+1, ptr, nchars) == '_' &&
          get_char(p+2, ptr, nchars) != '_' &&
          /* When stop_on_underscores is FALSE, stop only on "__tm", "__ps",
             "__pt", or "__S".  Double underscores can appear in the middle
             of some names, e.g., member names used as template arguments. */
          (stop_on_underscores ||
           (get_char(p+2, ptr, nchars) == 't' &&
            get_char(p+3, ptr, nchars) == 'm') ||
           (get_char(p+2, ptr, nchars) == 'p' &&
            get_char(p+3, ptr, nchars) == 's') ||
           (get_char(p+2, ptr, nchars) == 'p' &&
            get_char(p+3, ptr, nchars) == 't') ||
           get_char(p+2, ptr, nchars) == 'S')) {
        break;
      }  /* if */
    }  /* for */
    end_ptr = p;
  }  /* if */
  /* Here, end_ptr indicates the character after the end of the initial
     part of the name. */
  if (!is_special_name) {
    /* Output the characters of the base name. */
    for (p = ptr; p < end_ptr; p++) write_id_ch(*p, dctl);
  }  /* if */
  /* If there's a template argument list for a partial specialization
     (beginning with "__ps__"), process it. */
  if ((nchars == 0 || (end_ptr-ptr+6) < nchars) &&
      start_of_id_is("__ps__", end_ptr)) {
    /* Write the arguments.  This first argument list gives the arguments
       that appear in the partial specialization declaration:
         template <class T, class U> struct A { ... };
         template <class T> struct A<T *, int> { ... };
                                     ^^^^^^^^this argument list
       This first argument list will be followed by another argument list
       that gives the arguments according to the partial specialization.
       For A<int *, int> according to the example above, the second
       argument list is <int>.  The second argument list is scanned but
       not put out, except when argument correspondences are output. */
    end_ptr = demangle_template_arguments(end_ptr+6, /*partial_spec=*/TRUE,
                                          temp_par_info, dctl);
    note_specialization(end_ptr, temp_par_info);
    is_partial_spec = TRUE;
  }  /* if */
  /* If there's a specialization indication ("__S"), ignore it. */
  if (get_char(end_ptr, ptr, nchars)   == '_' &&
      get_char(end_ptr+1, ptr, nchars) == '_' &&
      get_char(end_ptr+2, ptr, nchars) == 'S') {
    note_specialization(end_ptr, temp_par_info);
    end_ptr += 3;
  }  /* if */
  /* If there's a template argument list (beginning with "__pt__" or "__tm__"),
     process it. */
  if ((nchars == 0 || (end_ptr-ptr+6) < nchars) &&
      ((is_pt = start_of_id_is("__pt__", end_ptr)) ||
       start_of_id_is("__tm__", end_ptr))) {
    /* The "__pt__ form indicates an old-style mangled template name. */
    if (is_pt && temp_par_info != NULL ) {
      temp_par_info->use_old_form_for_template_output = TRUE;
    }  /* if */
    /* For the second argument list of a partial specialization,
       process the argument list but suppress output. */
    if (is_partial_spec && temp_par_info != NULL &&
        !temp_par_info->output_only_correspondences) {
      dctl->suppress_id_output++;
      partial_spec_output_suppressed = TRUE;
    }  /* if */
    /* Write the arguments. */
#if ENABLE_GNU_LIKE_OUTPUT
    /* But not if we are printing an implicit Ctor/Dtor name! */
    if (temp_par_info != NULL && temp_par_info->base_name_only)
      dctl->suppress_id_output++;
#endif
    end_ptr = demangle_template_arguments(end_ptr+6, /*partial_spec=*/FALSE,
                                          temp_par_info, dctl);
#if ENABLE_GNU_LIKE_OUTPUT
    if (temp_par_info != NULL && temp_par_info->base_name_only)
      dctl->suppress_id_output--;
#endif
    if (partial_spec_output_suppressed) dctl->suppress_id_output--;
    /* If there's a(nother) specialization indication ("__S"), ignore it. */
    if (get_char(end_ptr, ptr, nchars)   == '_' &&
        get_char(end_ptr+1, ptr, nchars) == '_' &&
        get_char(end_ptr+2, ptr, nchars) == 'S') {
      note_specialization(end_ptr, temp_par_info);
      end_ptr += 3;
    }  /* if */
  }  /* if */
  /* Check that we took exactly the characters we should have. */
  if (((nchars != 0) ? (end_ptr-ptr == nchars) : (*end_ptr == '\0')) ||
      (stop_on_underscores &&
       get_char(end_ptr,   ptr, nchars) == '_' &&
       get_char(end_ptr+1, ptr, nchars) == '_')) {
    /* Okay. */
  } else if (nchars_left != NULL) {
    /* Return the count of characters not taken. */
    *nchars_left = nchars-(end_ptr-ptr);
  } else {
    bad_mangled_name(dctl);
  }  /* if */
  return end_ptr;
}  /* demangle_name */


static char *demangle_function_local_indication(
                                             char                       *ptr,
                                             unsigned long              nchars,
                                             a_decode_control_block_ptr dctl)
/*
Demangle the function name and block number in a function-local indication:

    __L2__f__Fv
               ^-- returned pointer points here
          ^------- mangled function name
       ^---------- block number within function (ptr points here on entry)

ptr points to the character after the "__L".  If nchars is non-zero, it
indicates the length of the string, starting from ptr.  Return a pointer
to the character following the mangled function name.  Output a function
indication like "f(void)::".
*/
{
  char          *p = ptr;
  unsigned long block_number;

  /* Get the block number. */
  p = get_number(ptr, &block_number, dctl);
  /* Check for the two underscores following the block number.  For local
     class names in some older versions of the mangling scheme, there is no
     following function name. */
  if (p[0] == '_' && p[1] == '_') {
    p += 2;
    /* Put out the function name. */
    if (nchars != 0) nchars -= (p - ptr);
    p = full_demangle_identifier(p, nchars, dctl);
    /* Put out the block number if needed.  Block 0 is the top-level block
       of the function, and need not be identified. */
    if (block_number != 0) {
     char buffer[30];
      write_id_str("[block ", dctl);
      (void)sprintf(buffer, "%lu", block_number);
      write_id_str(buffer, dctl);
      write_id_ch(']', dctl);
    }  /* if */
    write_id_str("::", dctl);
  }  /* if */
  return p;
}  /* demangle_function_local_indication */


static char *demangle_name_with_preceding_length(
                                   char                       *ptr,
                                   a_boolean                  allow_member,
                                   a_template_param_block_ptr temp_par_info,
                                   a_decode_control_block_ptr dctl)
/*
Demangle a name that is preceded by a length, e.g., "3abc" for the type
name "abc".  Return a pointer to the character position following what
was demangled.  When temp_par_info != NULL, it points to a block that
controls output of extra information on template parameters.
If allow_member is TRUE, the name may be a member name.
*/
{
  char          *p = ptr;
  char          *p2;
  unsigned long nchars, nchars2;
  a_boolean     has_function_local_info = FALSE;
  a_boolean     is_member = FALSE;

  /* Get the length. */
  p = get_length(p, &nchars, dctl);
  if (nchars >= 8) {
    /* Look for a function-local indication, e.g., "__Ln__f" for block
       "n" of function "f". */
    for (p2 = p+1; p2+6 < p+nchars; p2++) {
      if (p2[0] == '_' && p2[1] == '_' && p2[2] == 'L') {
        has_function_local_info = TRUE;
        nchars2 = nchars;
        /* Set the length for the scan below to stop just before "__L". */
        nchars = p2 - p;
        p2 += 3;  /* Points to block number after "__L". */
        nchars2 -= (p2 - p);
        /* Scan over (but do not output) the block number and function name. */
        dctl->suppress_id_output++;
        p2 = demangle_function_local_indication(p2, nchars2, dctl);
        dctl->suppress_id_output--;
        break;
      }  /* if */
    }  /* for */
  }  /* if */
  if (allow_member) {
    /* This might be a member name.  Demangle once to see if we take
       the whole name.  If not, the rest should be two underscores
       and the parent name. */
    unsigned long nchars_left, old_nchars;
    dctl->suppress_id_output++;
    p2 = demangle_name(p, nchars, /*stop_on_underscores=*/FALSE,
                       &nchars_left, (char *)NULL,
                       (a_template_param_block_ptr)NULL, dctl);
    dctl->suppress_id_output--;
    if (nchars_left != 0) {
      /* We came up short on the name.  Expect two underscores and the
         parent type. */
      if (p2[0] != '_' || p2[1] != '_') {
        bad_mangled_name(dctl);
      } else {
        is_member = TRUE;
        old_nchars = nchars;
        nchars = p2 - p;
        p2 += 2;
        p2 = demangle_type_name(p2, dctl);
        write_id_str("::", dctl);
        /* See if we ended up in the right place. */
        if (p2 != p+old_nchars) {
          bad_mangled_name(dctl);
        }  /* if */
      }  /* if */
    }  /* if */
  }  /* if */
  /* Demangle the name. */
  p = demangle_name(p, nchars, /*stop_on_underscores=*/FALSE,
                    (unsigned long *)NULL,
                    (char *)NULL, temp_par_info, dctl);
  if (has_function_local_info || is_member) p = p2;
  return p;
}  /* demangle_name_with_preceding_length */


static char *demangle_simple_type_name(
                                   char                       *ptr,
                                   a_template_param_block_ptr temp_par_info,
                                   a_decode_control_block_ptr dctl)
/*
Demangle a type name (or namespace name) consisting of a length followed
by the name.  Return a pointer to the character position following what
was demangled.  The name is not a nested name, but it can have template
arguments.  When temp_par_info != NULL, it points to a block that
controls output of extra information on template parameters.
*/
{
  char *p = ptr;

  if (*p == 'Z') {
    /* A template parameter name. */
    p = demangle_template_parameter_name(p, /*nontype=*/FALSE, dctl);
  } else {
    /* A simple mangled type name consists of digits indicating the length of
       the name followed by the name itself, e.g., "3abc". */
    p = demangle_name_with_preceding_length(p, /*allow_member=*/FALSE,
                                            temp_par_info, dctl);
  }  /* if */
  return p;
}  /* demangle_simple_type_name */


static char *full_demangle_type_name(char                       *ptr,
                                     a_boolean                  base_name_only,
                                     a_template_param_block_ptr temp_par_info,
                                     a_decode_control_block_ptr dctl)
/*
Demangle the type name at ptr and output the demangled form.  Return a pointer
to the character position following what was demangled.  The name can be
a simple type name or a nested type name, or the name of a namespace.
If base_name_only is TRUE, do not put out any nested type qualifiers,
e.g., put out "A::x" as simply "x".  When temp_par_info != NULL, it
points to a block that controls output of extra information on template
parameters.  Note that this routine is called for namespaces too
(the mangling is the same as for class names; you can't actually tell
the difference in a mangled name).  See demangle_type_name for an
interface to this routine for the simple case.
*/
{
  char          *p = ptr;
  unsigned long nquals;

  if (*p == 'Q') {
    /* A nested type name has the form
         Q2_5outer5inner   (outer::inner)
            ^-----^--------Names from outermost to innermost
          ^----------------Number of levels of qualification.
       Note that the levels in the qualifier can be class names or namespace
       names. */
    p = get_number(p+1, &nquals, dctl);
    p = advance_past_underscore(p, dctl);
    /* Handle each level of qualification. */
    for (; nquals > 0; nquals--) {
      if (dctl->err_in_id) break;  /* Avoid infinite loops on errors. */
      /* Do not put out the nested type qualifiers if base_name_only is
         TRUE. */
      if (base_name_only && nquals != 1) dctl->suppress_id_output++;
      p = demangle_simple_type_name(p, temp_par_info, dctl);
      if (nquals != 1) write_id_str("::", dctl);
      if (base_name_only && nquals != 1) dctl->suppress_id_output--;
    }  /* for */
  } else {
#if ENABLE_GNU_LIKE_OUTPUT
    a_template_param_block ctdt_temp_par_info;
    if (base_name_only)
      {
	/* Also need to suppress template parameters when printing these! */
	temp_par_info = &ctdt_temp_par_info;
	clear_template_param_block(temp_par_info);
	temp_par_info->base_name_only = TRUE;
      }
    /* N.B. when base_name_only is true, temp_par_info is also NULL.
	We need it to pass down base_name_only, so we create a blank one
	at this level. But note, we don't preserve temp_par_info so if you
	add code that needs the old one, also add code to save/restore it. */
#endif
    /* A simple (non-nested) type name. */
    p = demangle_simple_type_name(p, temp_par_info, dctl);
  }  /* if */
  return p;
}  /* full_demangle_type_name */


static char *demangle_vtbl_class_name(char                       *ptr,
                                      a_decode_control_block_ptr dctl)
/*
Demangle a class or base class name that is one component of a virtual
function table name.  Such names are mangled mostly as types, but with
a few special quirks.
*/
{
  char      *p = ptr;
  a_boolean nested_name_case = FALSE;

  /* If the name begins with a number, "Q", and another number, assume
     it's a name with a form like "7Q2_1A1B", which is used to encode
     A::B as the complete object class name component of a virtual
     function table name.  This doesn't have any particular sense to
     it; it's just what cfront does (and EDG's front end does the same
     at ABI versions >= 2.30 in cfront compatibility mode).  This could
     fail if the user actually has a class with a name that begins
     like "Q2_", but there's not much we can do about that. */
  if (isdigit((unsigned char)*p)) {
    do { p++; } while (isdigit((unsigned char)*p));
    if (*p == 'Q') {
      char *save_p = p;
      p++;
      if (isdigit((unsigned char)*p)) {
        do { p++; } while (isdigit((unsigned char)*p));
        if (*p == '_') {
          /* Yes, this is the strange nested name case.  Start the demangling
             at the "Q". */
          nested_name_case = TRUE;
          p = save_p;
        }  /* if */
      }  /* if */
    }  /* if */
  }  /* if */
  if (!nested_name_case) p = ptr;
  /* Now use the normal routine to demangle the class name. */
  p = demangle_type_name(p, dctl);
  return p;
}  /* demangle_vtbl_class_name */


static char *demangle_type_qualifiers(
                                     char                       *ptr,
                                     a_boolean                  trailing_space,
                                     a_decode_control_block_ptr dctl)
/*
Demangle any type qualifiers (const/volatile) at the indicated location.
Return a pointer to the character position following what was demangled.
If trailing_space is TRUE, add a space at the end if any qualifiers were
put out.
*/
{
  char      *p = ptr;
  a_boolean any_quals = FALSE;

  for (;; p++) {
    if (*p == 'C') {
      if (any_quals) write_id_ch(' ', dctl);
      write_id_str("const", dctl);
    } else if (*p == 'V') {
      if (any_quals) write_id_ch(' ', dctl);
      write_id_str("volatile", dctl);
    } else {
      break;
    }  /* if */
    any_quals = TRUE;
  }  /* for */
  if (any_quals && trailing_space) write_id_ch(' ', dctl);
  return p;
}  /* demangle_type_qualifiers */


static char *demangle_type_specifier(char                       *ptr,
                                     a_decode_control_block_ptr dctl)
/*
Demangle the type at ptr and output the specifier part.  Return a pointer
to the character position following what was demangled.
*/
{
  char *p = ptr, *s;

  /* Process type qualifiers. */
  p = demangle_type_qualifiers(p, /*trailing_space=*/TRUE, dctl);
  if (isdigit((unsigned char)*p) || *p == 'Q' || *p == 'Z') {
    /* Named type, like class or enum, e.g., "3abc". */
    p = demangle_type_name(p, dctl);
  } else {
    /* Builtin type. */
    /* Handle signed and unsigned. */
    if (*p == 'S') {
      write_id_str("signed ", dctl);
      p++;
    } else if (*p == 'U') {
      write_id_str("unsigned ", dctl);
      p++;
    }  /* if */
    switch (*p++) {
      case 'v':
        s = "void";
        break;
      case 'c':
        s = "char";
        break;
      case 'w':
        s = "wchar_t";
        break;
      case 'b':
        s = "bool";
        break;
      case 's':
        s = "short";
        break;
      case 'i':
        s = "int";
        break;
      case 'l':
        s = "long";
        break;
      case 'L':
        s = "long long";
        break;
      case 'f':
        s = "float";
        break;
      case 'd':
        s = "double";
        break;
      case 'r':
        s = "long double";
        break;
      case 'm':
        /* Microsoft intrinsic __intN types (Visual C++ 6.0 and later). */
        switch (*p++) {
          case '1':
            s = "__int8";
            break;
          case '2':
            s = "__int16";
            break;
          case '4':
            s = "__int32";
            break;
          case '8':
            s = "__int64";
            break;
          default:
            bad_mangled_name(dctl);
            s = "";
        }  /* switch */
        break;
      case 'B':
        /* Altivec vector */
        switch (*p++) {
          case 'U':
	    switch(*p++) {
	      case 'c':
		s = "vector unsigned char";
		break;
	      case 's':
		s = "vector unsigned short int";
		break;
	      case 'i':
		s = "vector unsigned int";
		break;
	      default:
		bad_mangled_name(dctl);
		s = "";
	    } /* switch */
	    break;
          case 'S':
	    switch(*p++) {
	      case 'c':
		s = "vector signed char";
		break;
	      case 's':
		s = "vector signed short int";
		break;
	      case 'i':
		s = "vector signed int";
		break;
	      default:
		bad_mangled_name(dctl);
		s = "";
	    } /* switch */
	    break;
          case 'b':
	    switch(*p++) {
	      case 'c':
		s = "vector bool char";
		break;
	      case 's':
		s = "vector bool short int";
		break;
	      case 'i':
		s = "vector bool int";
		break;
	      default:
		bad_mangled_name(dctl);
		s = "";
	    } /* switch */
	    break;
          case 'f':
            s = "vector float";
            break;
          case 'p':
            s = "vector pixel";
            break;
          default:
            bad_mangled_name(dctl);
            s = "";
        }  /* switch */
        break;
      case 'E':
        /* E500 vector */
        switch (*p++) {
          case 'U':
	    switch(*p++) {
	      case 's':
		s = "__ev64_u16__";
		break;
	      case 'i':
		s = "__ev64_u32__";
		break;
	      case 'L':
		s = "__ev64_u64__";
		break;
	      default:
		bad_mangled_name(dctl);
		s = "";
	    } /* switch */
	    break;
          case 'S':
	    switch(*p++) {
	      case 's':
		s = "__ev64_s16__";
		break;
	      case 'i':
		s = "__ev64_s32__";
		break;
	      case 'L':
		s = "__ev64_s64__";
		break;
	      default:
		bad_mangled_name(dctl);
		s = "";
	    } /* switch */
	    break;
          case 'f':
            s = "__ev64_fs__";
            break;
          case 'v':
            s = "__ev64_opaque__";
            break;
          default:
            bad_mangled_name(dctl);
            s = "";
        }  /* switch */
        break;
      default:
        bad_mangled_name(dctl);
        s = "";
    }  /* switch */
    write_id_str(s, dctl);
  }  /* if */
  return p;
}  /* demangle_type_specifier */


static char *demangle_function_parameters(char                       *ptr,
                                          a_decode_control_block_ptr dctl)
/*
Demangle the parameter list beginning at ptr and output the demangled form.
Return a pointer to the character position following what was demangled.
*/
{
  char      *p = ptr;
  char      *param_pos[10];
  unsigned  long curr_param_num, param_num, nreps;
  a_boolean any_params = FALSE;

  write_id_ch('(', dctl);
  if (*p == 'v') {
    /* Void parameter list. */
    p++;
  } else {
    any_params = TRUE;
    /* Loop for each parameter. */
    curr_param_num = 1;
    for (;;) {
      if (dctl->err_in_id) break;  /* Avoid infinite loops on errors. */
      if (*p == 'T' || *p == 'N') {
        /* Tn means repeat the type of parameter "n". */
        /* Nmn means "m" repetitions of the type of parameter "n".  "m"
           is a one-digit number. */
        /* "n" is also treated as a single-digit number; the front end enforces
           that (in non-cfront object code compatibility mode).  cfront does
           not, which leads to some ambiguities when "n" is followed by
           a class name. */
        if (*p++ == 'N') {
          /* Get the number of repetitions. */
          p = get_single_digit_number(p, &nreps, dctl);
        } else {
          nreps = 1;
        }  /* if */
        /* Get the parameter number. */
        p = get_single_digit_number(p, &param_num, dctl);
        if (param_num < 1 || param_num >= curr_param_num ||
            param_pos[param_num] == NULL) {
          /* Parameter number out of range. */
          bad_mangled_name(dctl);
          goto end_of_routine;
        }  /* if */
        /* Produce "nreps" copies of parameter "param_num". */
        for (; nreps > 0; nreps--) {
          if (dctl->err_in_id) break;  /* Avoid infinite loops on errors. */
          if (curr_param_num < 10) param_pos[curr_param_num] = NULL;
          (void)demangle_type(param_pos[param_num], dctl);
          if (nreps != 1) write_id_str(", ", dctl);
          curr_param_num++;
        }  /* if */
      } else {
        /* A normal parameter. */
        if (curr_param_num < 10) param_pos[curr_param_num] = p;
        p = demangle_type(p, dctl);
        curr_param_num++;
      }  /* if */
      /* Stop after the last parameter. */
      if (*p == '\0' || *p == 'e' || *p == '_' || *p == 'F') break;
      write_id_str(", ", dctl);
    }  /* for */
  }  /* if */
  if (*p == 'e') {
    /* Ellipsis. */
    if (any_params) write_id_str(", ", dctl);
    write_id_str("...", dctl);
    p++;
  }  /* if */
  write_id_ch(')', dctl);
end_of_routine:
  return p;
}  /* demangle_function_parameters */


static char *skip_extern_C_indication(char *ptr)
/*
ptr points to the character after the "F" of a function type.  Skip over
and ignore an indication of extern "C" following the "F", if one is present.
Return a pointer to the character following the extern "C" indication.
There's no syntax for representing the extern "C" in the function type, so
just ignore it.
*/
{
  if (*ptr == 'K') ptr++;
  return ptr;
}  /* skip_extern_C_indication */


static char *demangle_type_first_part(
                               char                       *ptr,
                               a_boolean                  under_lhs_declarator,
                               a_boolean                  need_trailing_space,
                               a_decode_control_block_ptr dctl)
/*
Demangle the type at ptr and output the specifier part and the part of the
declarator that precedes the name.  Return a pointer to the character
position following what was demangled.  If under_lhs_declarator is TRUE,
this type is directly under a type that uses a left-side declarator,
e.g., a pointer type.  (That's used to control use of parentheses around
parts of the declarator.)  If need_trailing_space is TRUE, put a space
at the end of the specifiers part (needed if the declarator part is
not empty, because it contains a name or a derived type).
*/
{
  char *p = ptr, *qualp = p;
  char kind;

  /* Remove type qualifiers. */
  while (is_immediate_type_qualifier(p)) p++;
  kind = *p;
  if (kind == 'P' || kind == 'R') {
    /* Pointer or reference type, e.g., "Pc" is pointer to char. */
    p = demangle_type_first_part(p+1, /*under_lhs_declarator=*/TRUE,
                                 /*need_trailing_space=*/TRUE, dctl);
    /* Output "*" or "&" for pointer or reference. */
    if (kind == 'R') {
      write_id_ch('&', dctl);
    } else {
      write_id_ch('*', dctl);
    }  /* if */
    /* Output the type qualifiers on the pointer, if any. */
    (void)demangle_type_qualifiers(qualp, /*trailing_space=*/TRUE, dctl);
  } else if (kind == 'M') {
    /* Pointer-to-member type, e.g., "M1Ai" is pointer to member of A of
       type int. */
    char *classp = p+1;
    /* Skip over the class name. */
    dctl->suppress_id_output++;
    p = demangle_type_name(classp, dctl);
    dctl->suppress_id_output--;
    p = demangle_type_first_part(p, /*under_lhs_declarator=*/TRUE,
                                 /*need_trailing_space=*/TRUE, dctl);
    /* Output Classname::*. */
    (void)demangle_type_name(classp, dctl);
    write_id_str("::*", dctl);
    /* Output the type qualifiers on the pointer, if any. */
    (void)demangle_type_qualifiers(qualp, /*trailing_space=*/TRUE, dctl);
  } else if (kind == 'F') {
    /* Function type, e.g., "Fii_f" is function(int, int) returning float.
       The return type is not present for top-level function types (except
       for template functions). */
    p = skip_extern_C_indication(p+1);
    /* Skip over the parameter types without outputting anything. */
    dctl->suppress_id_output++;
    p = demangle_function_parameters(p, dctl);
    dctl->suppress_id_output--;
    if (*p == '_' && p[1] != '_') {
      /* The return type is present. */
#if ENABLE_GNU_LIKE_OUTPUT
      if (dctl->suppress_return_types) dctl->suppress_id_output++;
#endif
      p = demangle_type_first_part(p+1, /*under_lhs_declarator=*/FALSE,
                                   /*need_trailing_space=*/TRUE, dctl);
#if ENABLE_GNU_LIKE_OUTPUT
      if (dctl->suppress_return_types) dctl->suppress_id_output--;
#endif
    }  /* if */
    /* This is a right-side declarator, so if it's under a left-side declarator
       parentheses are needed. */
    if (under_lhs_declarator) write_id_ch('(', dctl);
  } else if (kind == 'A') {
    /* Array type, e.g., "A10_i" is array[10] of int. */
    p++;
    if (*p == '_') {
      /* Length is specified by a constant expression based on template
         parameters.  Ignore the expression. */
      p++;
      dctl->suppress_id_output++;
      p = demangle_constant(p, dctl);
      dctl->suppress_id_output--;
    } else {
      /* Normal constant number of elements. */
      /* Skip the array size. */
      while (isdigit((unsigned char)*p)) p++;
    }  /* if */
    p = advance_past_underscore(p, dctl);
    /* Process the element type. */
    p = demangle_type_first_part(p, /*under_lhs_declarator=*/FALSE,
                                 /*need_trailing_space=*/TRUE, dctl);
    /* This is a right-side declarator, so if it's under a left-side declarator
       parentheses are needed. */
    if (under_lhs_declarator) write_id_ch('(', dctl);
  } else {
    /* No declarator part to process.  Handle the specifier type. */
    p = demangle_type_specifier(qualp, dctl);
    if (need_trailing_space) write_id_ch(' ', dctl);
  }  /* if */
  return p;
}  /* demangle_type_first_part */


static void demangle_type_second_part(
                               char                       *ptr,
                               a_boolean                  under_lhs_declarator,
                               a_decode_control_block_ptr dctl)
/*
Demangle the type at ptr and output the part of the declarator that follows the
name.  This routine does not return a pointer to the character position
following what was demangled; it is assumed that the caller will save
that from the call of demangle_type_first_part, and it saves a lot of
time if this routine can avoid scanning the specifiers again.
If under_lhs_declarator is TRUE, this type is directly under a type that
uses a left-side declarator, e.g., a pointer type.  (That's used to control
use of parentheses around parts of the declarator.)
*/
{
  char *p = ptr, *qualp = p;
  char kind;

  /* Remove type qualifiers. */
  while (is_immediate_type_qualifier(p)) p++;
  kind = *p;
  if (kind == 'P' || kind == 'R') {
    /* Pointer or reference type, e.g., "Pc" is pointer to char. */
    demangle_type_second_part(p+1, /*under_lhs_declarator=*/TRUE, dctl);
  } else if (kind == 'M') {
    /* Pointer-to-member type, e.g., "M1Ai" is pointer to member of A of
       type int. */
    /* Advance over the class name. */
    dctl->suppress_id_output++;
    p = demangle_type_name(p+1, dctl);
    dctl->suppress_id_output--;
    demangle_type_second_part(p, /*under_lhs_declarator=*/TRUE, dctl);
  } else if (kind == 'F') {
    /* Function type, e.g., "Fii_f" is function(int, int) returning float.
       The return type is not present for top-level function types (except
       for template functions). */
    /* This is a right-side declarator, so if it's under a left-side declarator
       parentheses are needed. */
    if (under_lhs_declarator) write_id_ch(')', dctl);
    p = skip_extern_C_indication(p+1);
    /* Put out the parameter types. */
#if ENABLE_GNU_LIKE_OUTPUT
    if (dctl->suppress_function_params) dctl->suppress_id_output++;
#endif
    p = demangle_function_parameters(p, dctl);
#if ENABLE_GNU_LIKE_OUTPUT
    if (dctl->suppress_function_params) dctl->suppress_id_output--;
#endif
    /* Put out any cv-qualifiers (member functions). */
    /* Note that such things could come up on nonmember functions in the
       presence of typedefs.  In such a case what we generate here will not
       be valid C, but it's a reasonable representation of the mangled
       type, and there's no way of getting the typedef name in there,
       so let it be. */
    if (*qualp != 'F') {
      write_id_ch(' ', dctl);
      (void)demangle_type_qualifiers(qualp, /*trailing_space=*/FALSE, dctl);
    }  /* if */
    if (*p == '_' && p[1] != '_') {
      /* Process the return type. */
      demangle_type_second_part(p+1, /*under_lhs_declarator=*/FALSE, dctl);
    }  /* if */
  } else if (kind == 'A') {
    /* Array type, e.g., "A10_i" is array[10] of int. */
    /* This is a right-side declarator, so if it's under a left-side declarator
       parentheses are needed. */
    if (under_lhs_declarator) write_id_ch(')', dctl);
    write_id_ch('[', dctl);
    p++;
    if (*p == '_') {
      /* Length is specified by a constant expression based on template
         parameters. */
      p++;
      p = demangle_constant(p, dctl);
    } else {
      /* Normal constant number of elements. */
      if (*p == '0' && p[1] == '_') {
        /* Size is zero, so do not put out a size (the result is "[]"). */
        p++;
      } else {
        /* Put out the array size. */
        while (isdigit((unsigned char)*p)) write_id_ch(*p++, dctl);
      }  /* if */
    }  /* if */
    p = advance_past_underscore(p, dctl);
    write_id_ch(']', dctl);
    /* Process the element type. */
    demangle_type_second_part(p, /*under_lhs_declarator=*/FALSE, dctl);
  } else {
    /* No declarator part to process.  No need to scan the specifiers type --
       it was done by demangle_type_first_part. */
  }  /* if */
}  /* demangle_type_second_part */


static char *demangle_type(char                       *ptr,
                           a_decode_control_block_ptr dctl)
/*
Demangle the type at ptr and output the demangled form.  Return a pointer to
the character position following what was demangled.
*/
{
  char *p;

  /* Generate the specifier part of the type. */
  p = demangle_type_first_part(ptr, /*under_lhs_declarator=*/FALSE,
                               /*need_trailing_space=*/FALSE, dctl);
  /* Generate the declarator part of the type. */
  demangle_type_second_part(ptr, /*under_lhs_declarator=*/FALSE, dctl);
  return p;
}  /* demangle_type */


static char *full_demangle_identifier(char                       *ptr,
                                      unsigned long              nchars,
                                      a_decode_control_block_ptr dctl)
/*
Demangle the identifier at ptr and output the demangled form.  Return
a pointer to the character position following what was demangled.
If nchars > 0, take no more than that many characters.
*/
{
  char          *p = ptr, *pname, *end_ptr, *function_local_end_ptr = NULL;
  char          *final_specialization, *end_ptr_first_scan;
  char          ch;
  a_boolean     member_function = TRUE;
  a_template_param_block
                temp_par_info;
  a_boolean     is_externalized_static = FALSE;

  clear_template_param_block(&temp_par_info);
  if ((nchars == 0 || nchars > 7) && start_of_id_is("__STF__", ptr)) {
#if ENABLE_GNU_LIKE_OUTPUT
  if (dctl->sourcelike_template_params)
    temp_par_info.use_old_form_for_template_output = TRUE;
#endif
    /* Static function made external by addition of prefix "__STF__" and
       suffix of module id. */
    is_externalized_static = TRUE;
    /* Advance past __STF__. */
    ptr += 7;
    if (nchars > 0) nchars -= 7;
    p = ptr;
  }  /* if */
  /* Scan through the name (the first part of the mangled name) without
     generating output, to see what's beyond it.  Special processing is
     necessary for names of constructors, conversion routines, etc. */
  /* If the name has a specialization indication in it (which can happen for
     function names), note that fact. */
  temp_par_info.set_final_specialization = TRUE;
  dctl->suppress_id_output++;
  p = demangle_name(ptr, nchars, /*stop_on_underscores=*/TRUE,
                    (unsigned long *)NULL,
                    (char *)NULL, &temp_par_info, dctl);
  dctl->suppress_id_output--;
  final_specialization = temp_par_info.final_specialization;
  clear_template_param_block(&temp_par_info);
#if ENABLE_GNU_LIKE_OUTPUT
  if (dctl->sourcelike_template_params)
    temp_par_info.use_old_form_for_template_output = TRUE;
#endif
  temp_par_info.final_specialization = final_specialization;
  if (get_char(p, ptr, nchars) == '\0') {
    /* There is no mangled part of the name.  This happens for strange
       cases like
         extern "C" int operator +(A, A);
       which gets mangled as "__pl".  Just write out the name and stop. */
    end_ptr = demangle_name(ptr, nchars,
                            /*stop_on_underscores=*/TRUE,
                            (unsigned long *)NULL,
                            (char *)NULL,
                            (a_template_param_block_ptr)NULL, dctl);
  } else {
    /* There's more.  There should be a "__" between the name and the
       additional mangled information. */
    if (get_char(p, ptr, nchars) != '_' || get_char(p+1, ptr, nchars) != '_') {
      bad_mangled_name(dctl);
      end_ptr = p;
      goto end_of_routine;
    }  /* if */
    end_ptr = p + 2;
    /* Now ptr points to the original-name part of the mangled name, and
       end_ptr points to the mangled-name part at the end.
         f__1AFv
            ^---- end_ptr
         ^------- ptr
       The mangled-name part is
         (a)  A class name for a static data member.
         (b)  A class name followed by "F" followed by the encoding for the
              parameter types for a member function.
         (c)  "F" followed by the encoding for the parameter types for a
              nonmember function.
         (d)  "L" plus a local block number, followed by the mangled function
              name, for a function-local entity.
       Members of namespaces are encoded similarly. */
    p = end_ptr;
    pname = NULL;
    ch = get_char(end_ptr, ptr, nchars);
    if (ch == 'L') {
      unsigned long nchars2 = nchars;
      /* The name of an entity within a function, mangled on promotion out
         of the function.  For example, "i__L1__f__Fv" for "i" from block 1
         of function "f(void)".  Note that this is not the same mangling
         used by cfront (in the cfront scheme, the __L1 is at the end, and
         the number is different). */
      /* Set a length for the name without the function-local indication,
         for the processing in the rest of this routine. */
      nchars = (p - 2) - ptr;
      /* Demangle the function name and block number. */
      p++;  /* Points to the block number following "__L". */
      if (nchars2 != 0) nchars2 -= (p - ptr);
      function_local_end_ptr =
                          demangle_function_local_indication(p, nchars2, dctl);
      p = end_ptr = ptr + nchars;
      member_function = FALSE;
      /* Go on to demangle the name of the local entity. */
    } else if (ch != 'F') {
      /* A class (or namespace) name must be next. */
      /* Remember the location of the parent entity name. */
      pname = end_ptr;
      /* Scan over the class name, producing no output, and remembering the
         position of the final specialization, if any.  If we already
         found a specialization on the function name, it's the final one
         and we shouldn't change it. */
      dctl->suppress_id_output++;
      if (temp_par_info.final_specialization == NULL) {
        temp_par_info.set_final_specialization = TRUE;
      }  /* if */
      end_ptr = full_demangle_type_name(pname, /*base_name_only=*/FALSE,
                                        &temp_par_info, dctl);
      temp_par_info.set_final_specialization = FALSE;
      dctl->suppress_id_output--;
      /* If the name ends here, this is a simple member (e.g., a static
         data member). */
      ch = get_char(end_ptr, ptr, nchars);
      if (ch == '\0' ||
          (ch == '_' && get_char(end_ptr+1, ptr, nchars) == '_')) {
        member_function = FALSE;
      }  /* if */
    }  /* if */
    if (member_function) {
      /* "S" here means a static member function (ignore). */
      if (get_char(end_ptr, ptr, nchars) == 'S') end_ptr++;
      /* Write the specifier part of the type. */
      end_ptr_first_scan =
                  demangle_type_first_part(end_ptr,
                                           /*under_lhs_declarator=*/FALSE,
                                           /*need_trailing_space=*/TRUE, dctl);
    }  /* if */
    temp_par_info.nesting_level = 0;
    if (pname != NULL) {
      /* Write the parent class or namespace qualifier. */
      if (temp_par_info.final_specialization != NULL) {
        /* Up to the final specialization, put out actual template arguments
           for specializations. */
        temp_par_info.actual_template_args_until_final_specialization = TRUE;
      }  /* if */
      (void)full_demangle_type_name(pname, /*base_name_only=*/FALSE,
                                    &temp_par_info, dctl);
      /* Force template parameter information out on the function even if
         it is specialized. */
      temp_par_info.actual_template_args_until_final_specialization = FALSE;
      write_id_str("::", dctl);
    }  /* if */
    /* Write the name of the member. */
    (void)demangle_name(ptr, nchars, /*stop_on_underscores=*/TRUE,
                        (unsigned long *)NULL,
                        pname, &temp_par_info, dctl);
    if (member_function) {
      /* Write the declarator part of the type. */
      demangle_type_second_part(end_ptr, /*under_lhs_declarator=*/FALSE,
                                dctl);
      end_ptr = end_ptr_first_scan;
    }  /* if */
    if (!temp_par_info.use_old_form_for_template_output &&
        temp_par_info.nesting_level != 0) {
      /* Put out correspondences for template parameters, e.g, "T=int". */
      temp_par_info.nesting_level = 0;
      temp_par_info.first_correspondence = TRUE;
      temp_par_info.output_only_correspondences = TRUE;
      /* Output is suppressed in general, and turned on only where
         appropriate. */
      dctl->suppress_id_output++;
      if (pname != NULL) {
        /* Write the parent class or namespace qualifier. */
        if (temp_par_info.final_specialization != NULL) {
          /* Up to the final specialization, put out actual template arguments
             for specializations. */
          temp_par_info.actual_template_args_until_final_specialization = TRUE;
        }  /* if */
        (void)full_demangle_type_name(pname, /*base_name_only=*/FALSE,
                                      &temp_par_info, dctl);
      }  /* if */
      /* Force template parameter information out on the function even if
         it is specialized. */
      temp_par_info.actual_template_args_until_final_specialization = FALSE;
      /* Write the name of the member. */
      (void)demangle_name(ptr, nchars, /*stop_on_underscores=*/TRUE,
                          (unsigned long *)NULL,
                          pname, &temp_par_info, dctl);
      dctl->suppress_id_output--;
      if (!temp_par_info.first_correspondence) {
        /* End the list of correspondences. */
        write_id_ch(']', dctl);
      }  /* if */
    }  /* if */
  }  /* if */
end_of_routine:
  /* When a function-local indication is scanned, end_ptr has been set
     to the end of the local entity name, and needs to be set to after the
     function-local indication at the end of the whole name. */
  if (function_local_end_ptr != NULL) end_ptr = function_local_end_ptr;
  if (is_externalized_static) {
    /* Advance over the module id part of the name. */
    while (get_char(end_ptr, ptr, nchars) != '\0') end_ptr++;
  }  /* if */
  return end_ptr;
}  /* full_demangle_identifier */


static char *demangle_static_variable_name(char                       *ptr,
                                           a_decode_control_block_ptr dctl)
/*
Demangle the name of a static variable promoted to being external by
addition of a prefix "__STV__" and a suffix of a module id.  Just put out
the part in the middle, which is the original name.
*/
{
  char *start_ptr;

  ptr += 7;  /* Move to after "__STV__". */
  /* Copy the name until "__". */
  start_ptr = ptr;
  while (*ptr != '_' || ptr[1] != '_' || ptr == start_ptr) {
    if (*ptr == '\0') {
      bad_mangled_name(dctl);
      break;
    }  /* if */
    write_id_ch(*ptr, dctl);
    ptr++;
  }  /* while */
  /* Advance over the module id part of the name. */
  while (*ptr != '\0') ptr++;
  return ptr;
}  /* demangle_static_variable_name */


static char *demangle_local_name(char                       *ptr,
                                 a_decode_control_block_ptr dctl)
/*
Demangle the local name at ptr and output the demangled form.  Return
a pointer to the character position following what was demangled.
This demangles the "__nn_mm_name" form produced by the C-generating
back end.  This is not something visible unless the C-generating back end
is used, and it's a local name, which is ordinarily outside the charter
of these demangling routines, but it's an easy and common case, so...

Also handles the cfront-style __nnName form.
*/
{
  char *p = ptr+2;

  /* Check for the initial two numbers and underscores.  The caller checked
     for the two initial underscores and the digit following that. */
  do { p++; } while (isdigit((unsigned char)*p));
  if (isalpha((unsigned char)*p)) {
    /* Cfront-style local name, like "__2name". */
  } else {
    if (*p != '_') {
      bad_mangled_name(dctl);
      goto end_of_routine;
    }  /* if */
    p++;
    if (!isdigit((unsigned char)*p)) {
      bad_mangled_name(dctl);
      goto end_of_routine;
    }  /* if */
    do { p++; } while (isdigit((unsigned char)*p));
    if (*p != '_') {
      bad_mangled_name(dctl);
      goto end_of_routine;
    }  /* if */
    p++;
  }  /* if */
  /* Copy the rest of the string to output. */
  while (*p != '\0') {
    write_id_ch(*p, dctl);
    p++;
  }  /* while */
end_of_routine:
  return p;
}  /* demangle_local_name */


static char *uncompress_mangled_name(char                       *id,
                                     a_decode_control_block_ptr dctl)
/*
Uncompress the compressed mangled name beginning at id.  Return the
address of the uncompressed name.
*/
{
  char          *uncompressed_name = id;
  unsigned long length;

  /* Advance past "__CPR". */
  id += 5;
  /* Accumulate the length of the uncompressed name. */
  if (!isdigit((unsigned char)*id)) {
    bad_mangled_name(dctl);
    goto end_of_routine;
  }  /* if */
  id = get_number(id, &length, dctl);
  /* Check for the two underscores following the length. */
  if (id[0] != '_' || id[1] != '_') {
    bad_mangled_name(dctl);
    goto end_of_routine;
  }  /* if */
  /* Save the uncompressed length so it can be used later in telling the
     caller how big a buffer is required. */
  dctl->uncompressed_length = length;
  id += 2;
  if (length+1 >= dctl->output_id_size) {
    /* The buffer supplied by the caller is too small to contain the
       uncompressed name. */
    dctl->output_overflow_err = TRUE;
    goto end_of_routine;
  } else {
    char *src, *dst;
    /* Uncompress to the end of the buffer supplied by the caller, then
       do the demangling in the space remaining at the beginning. */
    uncompressed_name = dctl->output_id+dctl->output_id_size-(length+1);
    dctl->output_id_size -= length+1;
    /* Set the "input length" -- really the output size -- now.  This
       is used for error checking on the numbers scanned in the decompression
       processing (which are positions in the uncompressed string, really,
       not in the input string). */
    dctl->input_id_len = length;
    dst = uncompressed_name;
    for (src = id; *src != '\0';) {
      char ch = *src++;
      if (ch != 'J') {
        /* Just copy this character. */
        *dst++ = ch;
      } else {
        if (*src == 'J') {
          /* "JJ" indicates a simple "J". */
          /* Simple "J". */
          *dst++ = 'J';
        } else {
          /* "JnnnJ" indicates a repetition of a string that appeared
             earlier, at position "nnn". */
          unsigned long pos, prev_len;
          char          *prev_str, *prev_str2;
          src = get_length(src, &pos, dctl);
          if (*src != 'J') {
            bad_mangled_name(dctl);
            goto end_of_routine;
          }  /* if */
          prev_str = uncompressed_name+pos;
          if (!isdigit(*prev_str)) {
            bad_mangled_name(dctl);
            goto end_of_routine;
          }  /* if */
          /* Get the length of the repeated string. */
          prev_str2 = get_length(prev_str, &prev_len, dctl);
          /* Copy the repeated string to the uncompressed output. */
          prev_str2 += prev_len;
          while (prev_str < prev_str2) *dst++ = *prev_str++;
        }  /* if */
        /* Advance past the final "J". */
        src++;
      }  /* if */
    }  /* for */
    if (dst - uncompressed_name != length) {
      /* The length didn't come out right. */
      bad_mangled_name(dctl);
    }  /* if */
    /* Add the final null. */
    *dst++ = '\0';
  }  /* if */
end_of_routine:;
  return uncompressed_name;
}  /* uncompress_mangled_name */

void decode_identifier(char      *id,
                       char      *output_buffer,
                       sizeof_t  output_buffer_size,
                       a_boolean *err,
                       a_boolean *buffer_overflow_err,
                       sizeof_t  *required_buffer_size)
/*
Demangle the identifier id (which is null-terminated), and put the demangled
form (null-terminated) into the output_buffer provided by the caller.
output_buffer_size gives the allocated size of output_buffer.  If there
is some error in the demangling process, *err will be returned TRUE.
In addition, if the error is that the output buffer is too small,
*buffer_overflow_err will (also) be returned TRUE, and *required_buffer_size
is set to the size of buffer required to do the demangling.  Note that
if the mangled name is compressed, and the buffer size is smaller than
the size of the uncompressed mangled name, the size returned will be
enough to uncompress the name but not enough to produce the demangled form.
The caller must be prepared in that case to loop a second time (the
length returned the second time will be correct).
*/
#if ENABLE_GNU_LIKE_OUTPUT
{
  decode_identifier_styled(id, /* act_like_gnu= */ 0,
			   /* suppress_function_params= */ 0,
			   output_buffer, output_buffer_size,
			   err, buffer_overflow_err, required_buffer_size);
}

void decode_identifier_styled(char      *id,
			      int       act_like_gnu,
			      int       suppress_function_params,
			      char      *output_buffer,
			      sizeof_t  output_buffer_size,
			      a_boolean *err,
			      a_boolean *buffer_overflow_err,
			      sizeof_t  *required_buffer_size)
#endif
{
  char                       *end_ptr, *p;
  a_decode_control_block     control_block;
  a_decode_control_block_ptr dctl = &control_block;

  clear_control_block(dctl);
  dctl->input_id_len = strlen(id);
  dctl->output_id = output_buffer;
  dctl->output_id_size = output_buffer_size;
#if ENABLE_GNU_LIKE_OUTPUT
  dctl->suppress_function_params = suppress_function_params ? TRUE : FALSE;
  dctl->suppress_return_types = act_like_gnu ? TRUE : FALSE;
  dctl->sourcelike_template_params = act_like_gnu ? TRUE : FALSE;
#endif
  if (start_of_id_is("__CPR", id)) {
    /* Uncompress a compressed name. */
    id = uncompress_mangled_name(id, dctl);
  }  /* if */
  /* Check for special cases. */
  if (dctl->output_overflow_err) {
    /* Previous error (not enough room in the buffer to uncompress). */
  } else if (start_of_id_is("__vtbl__", id)) {
    write_id_str("virtual function table for ", dctl);
    /* Note that if the first name is a base class name and it's not simple,
       this will produce output containing partially-mangled information.
       It's hard to do better given the cfront encoding form. */
    end_ptr = demangle_vtbl_class_name(id+8, dctl);
    if (start_of_id_is("__A", end_ptr)) {
      /* "__A" indicates an ambiguous base class. */
      write_id_str(" (ambiguous)", dctl);
      end_ptr += 3;
      /* Ignore the number following __A, if any. */
      while (isdigit((unsigned char)*end_ptr)) end_ptr++;
    }  /* if */
    if (start_of_id_is("__", end_ptr)) {
      /* Virtual function table for base class in derived class. */
      end_ptr += 2;
      write_id_str(" in ", dctl);
      end_ptr = demangle_vtbl_class_name(end_ptr, dctl);
    }  /* if */
    if (start_of_id_is("__", end_ptr)) {
      /* Further derived class. */
      end_ptr += 2;
      write_id_str(" in ", dctl);
      end_ptr = demangle_vtbl_class_name(end_ptr, dctl);
    }  /* if */
  } else if (start_of_id_is("__CBI__", id)) {
    write_id_str("can-be-instantiated flag for ", dctl);
    end_ptr = demangle_identifier(id+7, dctl);
  } else if (start_of_id_is("__DNI__", id)) {
    write_id_str("do-not-instantiate flag for ", dctl);
    end_ptr = demangle_identifier(id+7, dctl);
  } else if (start_of_id_is("__TIR__", id)) {
    write_id_str("template-instantiation-request flag for ", dctl);
    end_ptr = demangle_identifier(id+7, dctl);
  } else if (start_of_id_is("__LSG__", id)) {
    write_id_str("initialization guard variable for ", dctl);
    end_ptr = demangle_identifier(id+7, dctl);
  } else if (start_of_id_is("__TID_", id)) {
    write_id_str("type identifier for ", dctl);
    end_ptr = demangle_type(id+6, dctl);
  } else if (start_of_id_is("__T_", id)) {
    write_id_str("typeinfo for ", dctl);
    end_ptr = demangle_type(id+4, dctl);
  } else if (start_of_id_is("__VFE__", id)) {
    write_id_str("surrogate in class ", dctl);
    p = demangle_type(id+7, dctl);
    if (p[0] != '_' || p[1] != '_') {
      bad_mangled_name(dctl);
      end_ptr = p;
    } else {
      write_id_str(" for ", dctl);
      end_ptr = demangle_identifier(p+2, dctl);
    }  /* if */
  } else if (start_of_id_is("__Q", id)) {
    /* Nested class name. */
    end_ptr = demangle_type_name(id+2, dctl);
  } else if (start_of_id_is("__STV__", id)) {
    /* Static variable made external by addition of prefix "__STV__" and
       suffix of module id. */
    end_ptr = demangle_static_variable_name(id, dctl);
  } else if (start_of_id_is("__", id) && isdigit((unsigned char)id[2])) {
    /* Local variable mangled by the C-generating back end: __nn_mm_name,
       where "nn" and "mm" are decimal integers. */
    end_ptr = demangle_local_name(id, dctl);
  } else {
    /* Normal case: function name, static data member name, or
       name of type or variable promoted out of function. */
    end_ptr = demangle_identifier(id, dctl);
  }  /* if */
  if (dctl->output_overflow_err) {
    dctl->err_in_id = TRUE;
  } else {
    /* Add a terminating null. */
    dctl->output_id[dctl->output_id_len] = 0;
  }  /* if */
  /* Make sure the whole identifier was taken. */
  if (!dctl->err_in_id && *end_ptr != '\0') bad_mangled_name(dctl);
  *err = dctl->err_in_id;
  *buffer_overflow_err = dctl->output_overflow_err;
  *required_buffer_size = dctl->output_id_len + 1; /* +1 for final null. */
  /* If the name is compressed, we need room for the uncompressed
     form, and a null, in the buffer. */
  if (dctl->uncompressed_length != 0) {
    *required_buffer_size += dctl->uncompressed_length+1;
  }  /* if */
}  /* decode_identifier */

#if IA64_ABI

/*
Start of demangling code for IA-64 ABI.
*/

#undef demangle_type_first_part
#undef demangle_type_second_part
#undef demangle_type
#undef demangle_name
#undef get_number
#undef demangle_type_specifier
#undef skip_extern_C_indication
#undef demangle_local_name
#undef demangle_name
#undef decode_identifier

#define demangle_type_first_part	IA64_demangle_type_first_part
#define demangle_type_second_part	IA64_demangle_type_second_part
#define demangle_type			IA64_demangle_type
#define demangle_name			IA64_demangle_name
#define get_number			IA64_get_number
#define demangle_type_specifier		IA64_demangle_type_specifier
#define skip_extern_C_indication	IA64_skip_extern_C_indication
#define demangle_local_name		IA64_demangle_local_name
#define demangle_name			IA64_demangle_name
#define decode_identifier		IA64_decode_identifier

/*
TRUE if the bugs in the g++ 3.2 implementation of the IA-64 ABI should
be emulated.  Can be changed by a command line option.
*/
a_boolean	emulate_gnu_abi_bugs = DEFAULT_EMULATE_GNU_ABI_BUGS;

/*
TRUE if the host integer representation is little-endian.
*/
static a_boolean
		host_little_endian;

/*
Bits used to represent cv-qualifiers in a bit set.
*/
typedef int a_cv_qualifier_set;
#define CVQ_NONE	((a_cv_qualifier_set)0)
#define CVQ_CONST	((a_cv_qualifier_set)0x1)
#define CVQ_VOLATILE	((a_cv_qualifier_set)0x2)
#define CVQ_RESTRICT	((a_cv_qualifier_set)0x4)


/*
Information about a function that has to be preserved from the
time of scanning of the name (e.g., in a <nested-name>) until later use
in processing the <bare-function-type>.
*/
typedef struct a_func_block {
  a_boolean	no_return_type;
			/* TRUE if the function is one that will not have
			   a return type encoded in the function type. */
  a_cv_qualifier_set
		cv_quals;
			/* If the function is a cv-qualified member function,
			   the set of cv-qualifiers.  0 otherwise. */
  char		ctor_dtor_kind;
			/* If the function is a constructor or destructor,
			   the character from the mangled name identifying its
			   kind, e.g., '2' for a subobject constructor/
			   destructor.  ' ' if the function is not a
			   constructor or destructor. */
} a_func_block;


/*
Information about an entity in the mangled name that may be reused
by referring back to it by number as a "substitution".
*/
/* Code for type of syntactic object substituted for: */
typedef enum a_substitution_kind {
  subk_unscoped_template_name,
			/* An <unscoped-template-name>. */
  subk_prefix,		/* A <prefix>. */
  subk_template_prefix,	/* A <template-prefix>. */
  subk_type,		/* A <type>. */
  subk_template_template_param
			/* A <template-template-param>. */
} a_substitution_kind;

typedef struct a_substitution {
  char		*start;	/* First character of the encoding of the entity. */
  a_substitution_kind
		kind;	/* Kind of entity. */
  unsigned long	num_levels;
			/* For subk_prefix and subk_template_prefix, the
			   number of levels of the prefix included.  That is,
			   is the substitution A:: or A::B:: or A::B::C::.
			   For the subk_template_prefix case, the count
			   is the number of complete levels (name plus
			   optional template argument list) that precede
			   the final name (and no template argument list)
			   that is part of the substitution.  (Therefore,
			   the count could be zero.) */
} a_substitution;

static a_substitution
		*substitutions = NULL;
			/* A dynamically allocated array.  substitutions[n]
			   gives the meaning of the substitution numbered
			   "n". */
static unsigned long
		num_substitutions = 0;
			/* The number of substitutions currently defined, i.e.,
			   the number of elements of the array that have
			   been set. */
static unsigned long
		allocated_substitutions = 0;
			/* The allocated size of the array, as a number of
			   elements. */


static char *demangle_type_first_part(
                               char                       *ptr,
                               a_cv_qualifier_set         cv_quals,
                               a_boolean                  under_lhs_declarator,
                               a_boolean                  need_trailing_space,
                               a_decode_control_block_ptr dctl);
static void demangle_type_second_part(
                               char                       *ptr,
                               a_cv_qualifier_set         cv_quals,
                               a_boolean                  under_lhs_declarator,
                               a_decode_control_block_ptr dctl);
static char *demangle_type(char                       *ptr,
                           a_decode_control_block_ptr dctl);
static char *demangle_template_args(char                       *ptr,
                                    a_decode_control_block_ptr dctl);
static char *demangle_name(char                       *ptr,
                           a_func_block               *func_block,
                           a_decode_control_block_ptr dctl);
static char *demangle_expression(char                       *ptr,
                                 a_decode_control_block_ptr dctl);
static char *demangle_encoding(char                       *ptr,
                               a_boolean                  include_func_params,
                               a_decode_control_block_ptr dctl);
static char *demangle_nested_name_components(
                              char                       *ptr,
                              unsigned long              num_levels,
                              a_boolean                  *is_no_return_name,
                              a_boolean                  *has_templ_arg_list,
                              char                       *ctor_dtor_kind,
                              char                       **last_component_name,
                              a_decode_control_block_ptr dctl);
static char *demangle_unscoped_name(char                       *ptr,
                                    a_func_block               *func_block,
                                    a_decode_control_block_ptr dctl);
static char *demangle_unqualified_name(
                                 char                       *ptr,
                                 a_boolean                  *is_no_return_name,
                                 a_decode_control_block_ptr dctl);
static char *demangle_template_param(char                       *ptr,
                                     a_decode_control_block_ptr dctl);


static void clear_func_block(a_func_block *func_block)
/*
Clear a function information block to default values.
*/
{
  func_block->no_return_type = FALSE;
  func_block->cv_quals = 0;
  func_block->ctor_dtor_kind = ' ';
}  /* clear_func_block */


static char *get_number(char                       *p,
                        long                       *num,
                        a_decode_control_block_ptr dctl)
/*
Accumulate a number starting at position p and return its value in *num.
Return a pointer to the character position following the number.
A negative number is indicated by a leading "n".
*/
{
  long      n = 0;
  a_boolean negative = FALSE;

  if (*p == 'n') {
    negative = TRUE;
    p++;
  }  /* if */
  if (!isdigit((unsigned char)*p)) {
    bad_mangled_name(dctl);
  } else {
    do {
      n = n*10 + (*p - '0');
      p++;
    } while (isdigit((unsigned char)*p));
  }  /* if */
  if (negative) n = -n;
  *num = n;
  return p;
}  /* get_number */


static void record_substitutable_entity(char                       *start,
                                        a_substitution_kind        kind,
                                        unsigned long              num_levels,
                                        a_decode_control_block_ptr dctl)
/*
Record the entity whose mangled name starts at "start", and whose
kind (of syntax term) is given by "kind", as a potentially
substitutable entity, one that can be used again by referencing
it in a later substitution.  num_levels gives added information
for the subk_prefix and subk_template_prefix cases.
*/
{
  /* Do not record anything if we are suppressing recording of substitutions.
     One case in which that is true is when an error has been detected. */
  if (!dctl->suppress_substitution_recording) {
    unsigned long  number = num_substitutions++;
    a_substitution *subp;
    if (num_substitutions > allocated_substitutions) {
      /* Need to allocate or extend the substitutions array. */
      true_size_t new_size;
      allocated_substitutions += 500;
      new_size = allocated_substitutions*sizeof(a_substitution);
      if (substitutions == NULL) {
        substitutions = malloc(new_size);
      } else {
        substitutions = realloc(substitutions, new_size);
      }  /* if */
      if (substitutions == NULL) {
        bad_mangled_name(dctl);
        return;
      }  /* if */
    } /* if */
    subp = &substitutions[number];
    subp->start = start;
    subp->kind = kind;
    subp->num_levels = num_levels;
  }  /* if */
}  /* record_substitutable_entity */


static char *demangle_substitution(
                             char                       *ptr,
                             int                        type_pass_num,
                             a_cv_qualifier_set         cv_quals,
                             a_boolean                  under_lhs_declarator,
                             a_boolean                  need_trailing_space,
                             char                       **last_component_name,
                             a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <substitution> and output the demangled form.
Return a pointer to the character position following what was demangled.
A <substitution> repeats a construct previously encoded in the
mangled name by referring to it by number, as a way to reduce the
size of mangled names.  There are also some predefined substitutions,
for entities from the standard library that are likely to come up
often.  The syntax is:

   <substitution> ::= S <seq-id> _
                  ::= S_
   <substitution> ::= St # ::std::
   <substitution> ::= Sa # ::std::allocator
   <substitution> ::= Sb # ::std::basic_string
   <substitution> ::= Ss # ::std::basic_string < char,
                                                 ::std::char_traits<char>,
                                                 ::std::allocator<char> >
   <substitution> ::= Si # ::std::basic_istream<char,  std::char_traits<char> >
   <substitution> ::= So # ::std::basic_ostream<char,  std::char_traits<char> >
   <substitution> ::= Sd # ::std::basic_iostream<char, std::char_traits<char> >

When the substitution is a type, type_pass_num indicates whether to
do the first-part (1) or second-part (2) processing.  type_pass_num == 0
means do both parts, i.e., the whole type.  cv_quals,
under_lhs_declarator, and need_trailing_space give extra information
to be passed through to the type demangling routines in that case.  If
last_component_name is non-NULL, and the substitution decoded is a
prefix of a nested name, a pointer to the encoding for the last
component of the nested name is returned in *last_component_name.  It
will not be a substitution.  This is needed for generating the names
of constructors and destructors.
*/
{
  char ch2 = ptr[1];

  if (last_component_name != NULL) *last_component_name = NULL;
  if (islower((unsigned char)ch2)) {
    /* Predefined substitution. */
    char *last_name = "";
    if (ch2 == 't') {
      write_id_str("std", dctl);
      last_name = "3std";
    } else if (ch2 == 'a') {
      write_id_str("std::allocator", dctl);
      last_name = "9allocator";
    } else if (ch2 == 'b') {
      write_id_str("std::basic_string", dctl);
      last_name = "12basic_string";
    } else if (ch2 == 's') {
      write_id_str(
      "std::basic_string<char, std::char_traits<char>, std::allocator<char>>",
      dctl);
      last_name = "12basic_string";
    } else if (ch2 == 'i') {
      write_id_str("std::basic_istream<char, std::char_traits<char>>", dctl);
      last_name = "13basic_istream";
    } else if (ch2 == 'o') {
      write_id_str("std::basic_ostream<char, std::char_traits<char>>", dctl);
      last_name = "13basic_ostream";
    } else if (ch2 == 'd') {
      write_id_str("std::basic_iostream<char, std::char_traits<char>>", dctl);
      last_name = "13basic_iostream";
    }  /* if */
    ptr += 2;
    if (last_component_name != NULL) *last_component_name = last_name;
  } else {
    /* Not a predefined substitution.  Convert the base-36 sequence number. */
    unsigned long  number = 0;
    a_substitution *subp;
    char           *p;
    ptr++;
    if (ch2 != '_') {
      do {
        static char digits[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
        number *= 36;
        if (*ptr == '\0') {
          bad_mangled_name(dctl);
          break;
        }  /* if */
        p = strchr(digits, *ptr);
        if (p == NULL) {
          bad_mangled_name(dctl);
          break;
        }  /* if */
        number += (p - digits);
        ptr++;
      } while (*ptr != '_');
      number++;
    }  /* if */
    if (number >= num_substitutions) {
      bad_mangled_name(dctl);
    } else {
      a_func_block func_block;
      ptr = advance_past_underscore(ptr, dctl);
      subp = &substitutions[number];
      p = subp->start;
      /* Rescan the encoding for the entity, outputting the demangled form
         again at the current output position.  Don't record substitutions
         when rescanning. */
      dctl->suppress_substitution_recording++;
      if (type_pass_num == 2 && subp->kind != subk_type) {
        /* If we're expecting a type, and we want the second-pass
           processing, and we get something other than a type, ignore it.
           It's a type specifier, and we don't put those out on the
           second pass. */
      } else {
        switch (subp->kind) {
          case subk_unscoped_template_name:
            (void)demangle_unscoped_name(p, &func_block, dctl);
            break;
          case subk_prefix:
          case subk_template_prefix:
            { a_boolean is_no_return_name, has_templ_arg_list;
              char      ctor_dtor_kind;
              /* Take the right number of levels of the name.  Note that a
                 substitution counts as one level even if it represents
                 several. */
              if (subp->num_levels > 0) {
                p = demangle_nested_name_components(p,
                                                    subp->num_levels,
                                                    &is_no_return_name,
                                                    &has_templ_arg_list,
                                                    &ctor_dtor_kind,
                                                    last_component_name,
                                                    dctl);
              }  /* if */
              if (subp->kind == subk_template_prefix) {
                /* For the template prefix case, take one more
                   <unqualified-name>. */
                if (subp->num_levels > 0) write_id_str("::", dctl);
                p = demangle_unqualified_name(p, &is_no_return_name, dctl);
              }  /* if */
            }
            break;
          case subk_type:
            if (type_pass_num == 1 || type_pass_num == 0) {
              (void)demangle_type_first_part(p, cv_quals,
                                             under_lhs_declarator,
                                             need_trailing_space,
                                             dctl);
            }  /* if */
            if (type_pass_num == 2 || type_pass_num == 0) {
              demangle_type_second_part(p, cv_quals,
                                        under_lhs_declarator, dctl);
            }  /* if */
            break;
          case subk_template_template_param:
            (void)demangle_template_param(p, dctl);
            break;
          default:
            bad_mangled_name(dctl);
        }  /* switch */
      }  /* if */
      dctl->suppress_substitution_recording--;
    }  /* if */
  }  /* if */
  return ptr;
}  /* demangle_substitution */


static char *demangle_bare_function_type(
                                     char                       *ptr,
                                     a_boolean                  no_return_type,
                                     a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <bare-function-type> and output the demangled form.
Return a pointer to the character position following what was demangled.
A <bare-function-type> encodes the return and parameter types of a
function type without the surrounding F/E delimiters.  It is used
in cases where the only possibility is a function type, e.g., in a
top-level encoding for a function.  The syntax is:

  <bare-function-type> ::= <signature type>+
        # types are possible return type, then parameter types

That is, the <bare-function-type> is one or more type encodings.
The output adds the "( )" surrounding the parameter types.
no_return_type is TRUE if the return type is not present.
*/
{
#define end_of_param_list(p) (*(p) == 'E' || *(p) == '\0')

  if (!no_return_type) {
    /* Skip the return type. */
    dctl->suppress_id_output++;
    /* Substitutions do get recorded on this scan. */
    ptr = demangle_type(ptr, dctl);
    dctl->suppress_id_output--;
  }  /* if */
  write_id_ch('(', dctl);
  if (end_of_param_list(ptr)) {
    /* Error, there are no parameter types (there's supposed to be at
       least a "v" for a void parameter list).  This is likely caused
       by absence of a return type when one is expected. */
    bad_mangled_name(dctl);
  } else if (*ptr == 'v' && end_of_param_list(ptr+1)) {
    /* An empty parameter list is encoded as a single void type.
       Put out just "()" for that case. */
    ptr++;
  } else {
    for (;;) {
      if (*ptr == 'z') {
        /* Encoding for ellipsis. */
        write_id_str("...", dctl);
        ptr++;
        if (!end_of_param_list(ptr)) {
          bad_mangled_name(dctl);
          break;
        }  /* if */
      } else {
        /* Normal type, not an ellipsis. */
        ptr = demangle_type(ptr, dctl);
      }  /* if */
      /* Stop on an "E" or at the end of the input. */
      if (end_of_param_list(ptr)) break;
      /* Stop on an error. */
      if (dctl->err_in_id) break;
      /* Continuing, so we need a comma between parameter types. */
      write_id_str(", ", dctl);
    }  /* if */
  }  /* if */
  write_id_ch(')', dctl);
  return ptr;
#undef end_of_param_list
}  /* demangle_bare_function_type */


static char *get_cv_qualifiers(char               *ptr,
                               a_cv_qualifier_set *cv_quals)
/*
Advance over any cv-qualifiers (const/volatile) at the indicated location
and return in *cv_quals a bit set indicating the qualifiers encountered.
Return a pointer to the character position following what was demangled.
*/
{
  *cv_quals = 0;
  for (;; ptr++) {
    if (*ptr == 'K') {
      *cv_quals |= CVQ_CONST;
    } else if (*ptr == 'V') {
      *cv_quals |= CVQ_VOLATILE;
    } else if (*ptr == 'r') {
      *cv_quals |= CVQ_RESTRICT;
    } else {
      break;
    }  /* if */
  }  /* for */
  return ptr;
}  /* get_cv_qualifiers */


static void output_cv_qualifiers(a_cv_qualifier_set         cv_quals,
                                 a_boolean                  trailing_space,
                                 a_decode_control_block_ptr dctl)
/*
Output any cv-qualifiers (const/volatile) in the bit set cv_quals.
If trailing_space is TRUE, add a space at the end if any qualifiers were
put out.
*/
{
  a_boolean any_previous = FALSE;

  if (cv_quals & CVQ_CONST   ) {
    write_id_str("const", dctl);
    any_previous = TRUE;
  }  /* if */
  if (cv_quals & CVQ_VOLATILE) {
    if (any_previous) write_id_ch(' ', dctl);
    write_id_str("volatile", dctl);
    any_previous = TRUE;
  }  /* if */
  if (cv_quals & CVQ_RESTRICT) {
    if (any_previous) write_id_ch(' ', dctl);
    write_id_str("restrict", dctl);
    any_previous = TRUE;
  }  /* if */
  if (any_previous && trailing_space) write_id_ch(' ', dctl);
}  /* output_cv_qualifiers */


static char *demangle_template_param(char                       *ptr,
                                     a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <template-param> and output the demangled form.  Return
a pointer to the character position following what was demangled.
A <template-param> encodes a reference to a template parameter.
The syntax is:

  <template-param> ::= T_       # first template parameter
                   ::= T <parameter-2 non-negative number> _

*/
{
  long num = 1;
  char buffer[50];

  /* Advance past the "T". */
  ptr++;
  if (*ptr != '_') {
    ptr = get_number(ptr, &num, dctl);
    if (num < 0) {
      bad_mangled_name(dctl);
    } else {
      num += 2;
    }  /* if */
  }  /* if */
  ptr = advance_past_underscore(ptr, dctl);
  (void)sprintf(buffer, "T%lu", num);
  write_id_str(buffer, dctl);
  return ptr;
}  /* demangle_template_param */


static char *demangle_type_specifier(char                       *ptr,
                                     a_decode_control_block_ptr dctl)
/*
Demangle the type at ptr and output the specifier part.  Return a pointer
to the character position following what was demangled.  The syntax is:

  <type> ::= <builtin-type>
         ::= <class-enum-type>
         ::= <template-param>
         ::= <template-template-param> <template-args>

Other parts of <type> are handled in demangle_type_first_part and
demangle_type_second_part.  In particular, substitutions are handled
at that level.  cv-qualifiers have been handled by the caller.
*/
{
  char *p = ptr, *s;

  /* Builtin type encodings are all lower-case.  Names begin with
     a digit or an upper-case letter. */
  if (!islower((unsigned char)*p)) {
    if (*p == 'T') {
      /* A template parameter, possibly a template template parameter. */
      char *tstart = p;
      p = demangle_template_param(p, dctl);
      if (*p == 'I') {
        /* A <template-args> list. */
        /* Record the template template parameter as a potential
           substitution. */
        record_substitutable_entity(tstart, subk_template_template_param, 0L,
                                    dctl);
        p = demangle_template_args(p, dctl);
      }  /* if */
    } else {
      /* <class-enum-type>, i.e., <name> */
      a_func_block func_block;
      p = demangle_name(p, &func_block, dctl);
    }  /* if */
  } else {
    /* Builtin type. */
    switch (*p++) {
      case 'v':
        s = "void";
        break;
      case 'w':
        s = "wchar_t";
        break;
      case 'b':
        s = "bool";
        break;
      case 'c':
        s = "char";
        break;
      case 'a':
        s = "signed char";
        break;
      case 'h':
        s = "unsigned char";
        break;
      case 's':
        s = "short";
        break;
      case 't':
        s = "unsigned short";
        break;
      case 'i':
        s = "int";
        break;
      case 'j':
        s = "unsigned int";
        break;
      case 'l':
        s = "long";
        break;
      case 'm':
        s = "unsigned long";
        break;
      case 'x':
        s = "long long";
        break;
      case 'y':
        s = "unsigned long long";
        break;
      case 'f':
        s = "float";
        break;
      case 'd':
        s = "double";
        break;
      case 'e':
        s = "long double";
        break;
      case 'z':  /* Ellipsis not handled here;
                    see demangle_bare_function_type. */
      default:
        bad_mangled_name(dctl);
        s = "";
    }  /* switch */
    write_id_str(s, dctl);
  }  /* if */
  return p;
}  /* demangle_type_specifier */


static char *skip_extern_C_indication(char *ptr)
/*
ptr points to the character after the "F" of a function type.  Skip over
and ignore an indication of extern "C" following the "F", if one is present.
Return a pointer to the character following the extern "C" indication.
There's no syntax for representing the extern "C" in the function type, so
just ignore it.
*/
{
  if (*ptr == 'Y') ptr++;
  return ptr;
}  /* skip_extern_C_indication */


static char *demangle_type_first_part(
                               char                       *ptr,
                               a_cv_qualifier_set         cv_quals,
                               a_boolean                  under_lhs_declarator,
                               a_boolean                  need_trailing_space,
                               a_decode_control_block_ptr dctl)
/*
Demangle the type at ptr and output the specifier part and the part of the
declarator that precedes the name.  Return a pointer to the character
position following what was demangled.  If under_lhs_declarator is TRUE,
this type is directly under a type that uses a left-side declarator,
e.g., a pointer type.  (That's used to control use of parentheses around
parts of the declarator.)  If need_trailing_space is TRUE, put a space
at the end of the specifiers part (needed if the declarator part is
not empty, because it contains a name or a derived type).  cv_quals
indicates any previously-scanned cv-qualifiers that are to be considered
to be on top of the type.
*/
{
  char               *p = ptr, *qualp = p, *unqualp;
  char               kind;
  a_cv_qualifier_set local_cv_quals;
  a_boolean          record_substitution = TRUE;

  /* Accumulate cv-qualifiers. */
  p = get_cv_qualifiers(p, &local_cv_quals);
  cv_quals |= local_cv_quals;
  unqualp = p;
  kind = *p;
  if (kind == 'S' &&
      /* "St" for "std::" is the beginning of a name, not a type. */
      p[1] != 't') {
    /* A substitution. */
    p = demangle_substitution(p, 1, cv_quals,
                              under_lhs_declarator,
                              need_trailing_space,
                              (char **)NULL,
                              dctl);
    record_substitution = FALSE;
    if (*p == 'I') {
      /* A <template-args> list (the substitution must be a template). */
      p = demangle_template_args(p, dctl);
      record_substitution = TRUE;
    }  /* if */
  } else if (kind == 'P' || kind == 'R') {
    /* Pointer or reference type, P <type> or R <type>. */
    p = demangle_type_first_part(p+1, CVQ_NONE, /*under_lhs_declarator=*/TRUE,
                                 /*need_trailing_space=*/TRUE, dctl);
    /* Output "*" or "&" for pointer or reference. */
    if (kind == 'R') {
      write_id_ch('&', dctl);
    } else {
      write_id_ch('*', dctl);
    }  /* if */
    /* Output the cv-qualifiers on the pointer, if any. */
    output_cv_qualifiers(cv_quals, /*trailing_space=*/TRUE, dctl);
  } else if (kind == 'M') {
    /* Pointer-to-member type, M <class type> <member type>. */
    char *classp = p+1;
    /* Skip over the class name. */
    /* Substitutions do get recorded on this scan. */
    dctl->suppress_id_output++;
    p = demangle_type(classp, dctl);
    dctl->suppress_id_output--;
    p = demangle_type_first_part(p, CVQ_NONE, /*under_lhs_declarator=*/TRUE,
                                 /*need_trailing_space=*/TRUE, dctl);
    /* Output Classname::*. */
    dctl->suppress_substitution_recording++;
    (void)demangle_type(classp, dctl);
    dctl->suppress_substitution_recording--;
    write_id_str("::*", dctl);
    /* Output the cv-qualifiers on the pointer, if any. */
    output_cv_qualifiers(cv_quals, /*trailing_space=*/TRUE, dctl);
  } else if (kind == 'F') {
    /* Function type, F [Y] <bare-function-type> E
       where "Y" indicates extern "C" (and is ignored here). */
    p = skip_extern_C_indication(p+1);
    /* Output the return type. */
    p = demangle_type_first_part(p, CVQ_NONE, /*under_lhs_declarator=*/FALSE,
                                 /*need_trailing_space=*/TRUE, dctl);
    /* Skip over the parameter types without outputting anything. */
    /* Substitutions do get recorded on this scan. */
    dctl->suppress_id_output++;
    p = demangle_bare_function_type(p, /*no_return_type=*/TRUE, dctl);
    dctl->suppress_id_output--;
    p = advance_past('E', p, dctl);
    /* This is a right-side declarator, so if it's under a left-side declarator
       parentheses are needed. */
    if (under_lhs_declarator) write_id_ch('(', dctl);
  } else if (kind == 'A') {
    /* Array type,
         A <positive dimension number> _ <element type>
         A [ <dimension expression> ]  _ <element type>
    */
    p++;
    if (!isdigit((unsigned char)*p)) {
      if (*p != '_') {
        /* Length is specified by an expression based on template
           parameters.  Ignore the expression. */
        /* Substitutions do get recorded on this scan. */
        dctl->suppress_id_output++;
        p = demangle_expression(p, dctl);
        dctl->suppress_id_output--;
      }  /* if */
    } else {
      /* Normal constant number of elements. */
      /* Skip the array size. */
      while (isdigit((unsigned char)*p)) p++;
    }  /* if */
    p = advance_past_underscore(p, dctl);
    /* Process the element type. */
    p = demangle_type_first_part(p, CVQ_NONE, /*under_lhs_declarator=*/FALSE,
                                 /*need_trailing_space=*/TRUE, dctl);
    /* This is a right-side declarator, so if it's under a left-side declarator
       parentheses are needed. */
    if (under_lhs_declarator) write_id_ch('(', dctl);
  } else {
    /* No declarator part to process.  Handle the specifier type. */
    output_cv_qualifiers(cv_quals, /*trailing_space=*/TRUE, dctl);
    p = demangle_type_specifier(p, dctl);
    if (need_trailing_space) write_id_ch(' ', dctl);
    if (p == unqualp+1) {
      /* Do not record a substitution for a builtin type.  (Builtin types
         are the only one-character encodings.) */
      record_substitution = FALSE;
    }  /* if */
  }  /* if */
  if (record_substitution) {
    /* Record the non-cv-qualified version of the type as a potential
       substitution. */
    record_substitutable_entity(unqualp, subk_type, 0L, dctl);
  }  /* if */
  if (qualp != unqualp) {
    /* The type is cv-qualified, so record another potential substitution
       for the fully-qualified type. */
    record_substitutable_entity(qualp, subk_type, 0L, dctl);
  }  /* if */
  return p;
}  /* demangle_type_first_part */


static void demangle_type_second_part(
                               char                       *ptr,
                               a_cv_qualifier_set         cv_quals,
                               a_boolean                  under_lhs_declarator,
                               a_decode_control_block_ptr dctl)
/*
Demangle the type at ptr and output the part of the declarator that follows the
name.  This routine does not return a pointer to the character position
following what was demangled; it is assumed that the caller will save
that from the call of demangle_type_first_part, and it saves a lot of
time if this routine can avoid scanning the specifiers again.
If under_lhs_declarator is TRUE, this type is directly under a type that
uses a left-side declarator, e.g., a pointer type.  (That's used to control
use of parentheses around parts of the declarator.)  cv_quals
indicates any previously-scanned cv-qualifiers that are to considered
to be on top of the type.
*/
{
  char               *p = ptr;
  char               kind;
  a_cv_qualifier_set local_cv_quals;

  /* Accumulate cv-qualifiers. */
  p = get_cv_qualifiers(p, &local_cv_quals);
  cv_quals |= local_cv_quals;
  kind = *p;
  if (kind == 'S' &&
      /* "St" for "std::" is the beginning of a name, not a type. */
      p[1] != 't') {
    /* A substitution. */
    p = demangle_substitution(p, 2, cv_quals,
                              under_lhs_declarator,
                              /*need_trailing_space=*/FALSE,
                              (char **)NULL,
                              dctl);
    /* No need to scan the <template-args> list if there is one -- 
       that was done by demangle_type_first_part. */
  } else if (kind == 'P' || kind == 'R') {
    /* Pointer or reference type, P <type> or R <type>. */
    demangle_type_second_part(p+1, CVQ_NONE, /*under_lhs_declarator=*/TRUE,
                              dctl);
  } else if (kind == 'M') {
    /* Pointer-to-member type, M <class type> <member type>. */
    /* Advance over the class name. */
    dctl->suppress_id_output++;
    dctl->suppress_substitution_recording++;
    p = demangle_type(p+1, dctl);
    dctl->suppress_substitution_recording--;
    dctl->suppress_id_output--;
    demangle_type_second_part(p, CVQ_NONE, /*under_lhs_declarator=*/TRUE,
                              dctl);
  } else if (kind == 'F') {
    char *returnt;
    /* Function type, F [Y] <bare-function-type> E
       where "Y" indicates extern "C" (and is ignored here). */
    /* This is a right-side declarator, so if it's under a left-side declarator
       parentheses are needed. */
    if (under_lhs_declarator) write_id_ch(')', dctl);
    p = skip_extern_C_indication(p+1);
    /* Put out the parameter types (the return type is skipped and not
       output). */
    returnt = p;
    dctl->suppress_substitution_recording++;
    p = demangle_bare_function_type(p, /*no_return_type=*/FALSE, dctl);
    dctl->suppress_substitution_recording--;
    p = advance_past('E', p, dctl);
    /* Put out any cv-qualifiers (member functions). */
    /* Note that such things could come up on nonmember functions in the
       presence of typedefs.  In such a case what we generate here will not
       be valid C, but it's a reasonable representation of the mangled
       type, and there's no way of getting the typedef name in there,
       so let it be. */
    if (cv_quals != 0) {
      write_id_ch(' ', dctl);
      output_cv_qualifiers(cv_quals, /*trailing_space=*/FALSE, dctl);
    }  /* if */
    /* Output the return type. */
    demangle_type_second_part(returnt, CVQ_NONE,
                              /*under_lhs_declarator=*/FALSE, dctl);
  } else if (kind == 'A') {
    /* Array type,
         A <positive dimension number> _ <element type>
         A [ <dimension expression> ]  _ <element type>
    */
    /* This is a right-side declarator, so if it's under a left-side declarator
       parentheses are needed. */
    if (under_lhs_declarator) write_id_ch(')', dctl);
    write_id_ch('[', dctl);
    p++;
    if (!isdigit((unsigned char)*p)) {
      if (*p != '_') {
        /* Length is specified by a constant expression based on template
           parameters. */
        dctl->suppress_substitution_recording++;
        p = demangle_expression(p, dctl);
        dctl->suppress_substitution_recording--;
      }  /* if */
    } else {
      /* Normal constant number of elements. */
      /* Put out the array size. */
      while (isdigit((unsigned char)*p)) write_id_ch(*p++, dctl);
    }  /* if */
    p = advance_past_underscore(p, dctl);
    write_id_ch(']', dctl);
    /* Process the element type. */
    demangle_type_second_part(p, CVQ_NONE, /*under_lhs_declarator=*/FALSE,
                              dctl);
  } else {
    /* No declarator part to process.  No need to scan the specifiers type --
       it was done by demangle_type_first_part. */
  }  /* if */
}  /* demangle_type_second_part */


static char *demangle_type(char                       *ptr,
                           a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <type> and output the demangled form.  Return a pointer
to the character position following what was demangled.  A <type> encodes
a type.  The syntax is:

  <type> ::= <builtin-type>
         ::= <function-type>
         ::= <class-enum-type>
         ::= <array-type>
         ::= <pointer-to-member-type>
         ::= <template-param>
         ::= <template-template-param> <template-args>
         ::= <substitution>
         ::= <CV-qualifiers> <type>
         ::= P <type>   # pointer-to
         ::= R <type>   # reference-to
  <function-type> ::= F [Y] <bare-function-type> E
  <class-enum-type> ::= <name>
  <array-type> ::= A <positive dimension number> _ <element type>
               ::= A [<dimension expression>] _ <element type>
  <pointer-to-member-type> ::= M <class type> <member type>

*/
{
  char *p;

  /* Generate the specifier part of the type. */
  p = demangle_type_first_part(ptr, CVQ_NONE, /*under_lhs_declarator=*/FALSE,
                               /*need_trailing_space=*/FALSE, dctl);
  /* Generate the declarator part of the type. */
  demangle_type_second_part(ptr, CVQ_NONE, /*under_lhs_declarator=*/FALSE,
                            dctl);
  return p;
}  /* demangle_type */


static char *get_operator_name(char                       *ptr,
                               int                        *num_operands,
                               char                       **close_str,
                               a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <operator-name> and return the demangled form.
Return NULL if the operator is invalid.  An <operator-name> encodes
an operator in an expression or operator function name.  The names
are two characters long.  *num_operands is set to the number of
operands expected by the operator.  *close_str is set to a string
that closes the operator, if necessary, e.g., "]" for subscripting;
it is set to "" if not needed.
*/
{
  char *str = NULL;

  *num_operands = 2;
  *close_str = "";
  if (*ptr == '\0') {
    bad_mangled_name(dctl);
  } else {
    char ch2 = ptr[1];
    switch (*ptr) {
      case 'a':
        if (ch2 == 'a') {
          str = "&&";
        } else if (ch2 == 'd') {
          str = "&";
          *num_operands = 1;
        } else if (ch2 == 'n') {
          str = "&";
        } else if (ch2 == 'N') {
          str = "&=";
        } else if (ch2 == 'S') {
          str = "=";
        }  /* if */
        break;
      case 'c':
        if (ch2 == 'l') {
          str = "()";
          *num_operands = 0;  /* Call is variable-length. */
        } else if (ch2 == 'm') {
          str = ",";
        } else if (ch2 == 'o') {
          str = "~";
          *num_operands = 1;
        } else if (ch2 == 'v') {
          str = "cast";
          *num_operands = 1;
        }  /* if */
        break;
      case 'd':
        if (ch2 == 'a') {
          str = "delete[] ";
        } else if (ch2 == 'e') {
          str = "*";
          *num_operands = 1;
        } else if (ch2 == 'l') {
          str = "delete ";
        } else if (ch2 == 'v') {
          str = "/";
        } else if (ch2 == 'V') {
          str = "/=";
        }  /* if */
        break;
      case 'e':
        if (ch2 == 'o') {
          str = "^";
        } else if (ch2 == 'O') {
          str = "^=";
        } else if (ch2 == 'q') {
          str = "==";
        }  /* if */
        break;
      case 'g':
        if (ch2 == 'e') {
          str = ">=";
        } else if (ch2 == 't') {
          str = ">";
        }  /* if */
        break;
      case 'i':
        if (ch2 == 'x') {
          str = "[";
          *close_str = "]";
        }  /* if */
        break;
      case 'l':
        if (ch2 == 'e') {
          str = "<=";
        } else if (ch2 == 's') {
          str = "<<";
        } else if (ch2 == 'S') {
          str = "<<=";
        } else if (ch2 == 't') {
          str = "<";
        }  /* if */
        break;
      case 'm':
        if (ch2 == 'i') {
          str = "-";
        } else if (ch2 == 'I') {
          str = "-=";
        } else if (ch2 == 'l') {
          str = "*";
        } else if (ch2 == 'L') {
          str = "*=";
        } else if (ch2 == 'm') {
          str = "--";
        }  /* if */
        break;
      case 'n':
        if (ch2 == 'a') {
          str = "new[] ";
        } else if (ch2 == 'e') {
          str = "!=";
        } else if (ch2 == 'g') {
          str = "-";
          *num_operands = 1;
        } else if (ch2 == 't') {
          str = "!";
          *num_operands = 1;
        } else if (ch2 == 'w') {
          str = "new ";
        }  /* if */
        break;
      case 'o':
        if (ch2 == 'o') {
          str = "||";
        } else if (ch2 == 'r') {
          str = "|";
        } else if (ch2 == 'R') {
          str = "|=";
        }  /* if */
        break;
      case 'p':
        if (ch2 == 'l') {
          str = "+";
        } else if (ch2 == 'L') {
          str = "+=";
        } else if (ch2 == 'm') {
          str = "->*";
        } else if (ch2 == 'p') {
          str = "++";
        } else if (ch2 == 's') {
          str = "+";
          *num_operands = 1;
        } else if (ch2 == 't') {
          str = "->";
        }  /* if */
        break;
      case 'q':
        if (ch2 == 'u') {
          str = "?";
          *num_operands = 3;
        }  /* if */
        break;
      case 'r':
        if (ch2 == 'm') {
          str = "%";
        } else if (ch2 == 'M') {
          str = "%=";
        } else if (ch2 == 's') {
          str = ">>";
        } else if (ch2 == 'S') {
          str = ">>=";
        }  /* if */
        break;
      case 's':
        if (ch2 == 't') {
          /* sizeof(type) */
          str = "sizeof(";
          *num_operands = 0;
          *close_str = ")";
        } else if (ch2 == 'r') {
          /* Scope resolution operator "::". */
          str = "::";
          *num_operands = 0;
        } else if (ch2 == 'z') {
          /* sizeof(expression) */
          str = "sizeof(";
          *close_str = ")";
          *num_operands = 1;
        }  /* if */
        break;
      default:
        break;
    }  /* switch */
  }  /* if */
  return str;
}  /* get_operator_name */


static char *demangle_source_name(
                                 char                       *ptr,
                                 a_boolean                  is_module_id,
                                 a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <source-name> and output the demangled form.
Return a pointer to the character position following what was demangled.
A <source-name> encodes an unqualified name as a length plus the
characters of the name. The syntax is:

    <source-name> ::= <positive length number> <identifier>
    <identifier> ::= <unqualified source code identifier>

If is_module_id is TRUE, the identifier is a module id string, which
begins with a (second) count that gives the length of the file name
part.  Just put out the file name part (continue scanning, but do not
output the rest of the string).  This is used for an EDG extension.
*/
{
  long      num, num_chars_to_output;
  a_boolean output_chars = TRUE;

  ptr = get_number(ptr, &num, dctl);
  if (num <= 0) {
    bad_mangled_name(dctl);
  } else {
    if (is_module_id) {
      /* A module id name (an EDG extension), which has the form
           <length> _ <file-name-length> _ <file-name> <rest-of-module-id>
         Only the file name part is put out.  The rest is passed over
         but not output. */
      if (*ptr != '_' || !isdigit((unsigned char)ptr[1])) {
        bad_mangled_name(dctl);
      } else {
        char *end_num = get_number(ptr+1, &num_chars_to_output, dctl);
        if (!dctl->err_in_id) {
          long prefix_len = (end_num-ptr)+1;
          if (*end_num != '_' ||
              num_chars_to_output <= 0 ||
              num < (num_chars_to_output + prefix_len)) {
            bad_mangled_name(dctl);
          } else {
            num -= prefix_len;
            ptr += prefix_len;
          }  /* if */
        }  /* if */
      }  /* if */
      if (dctl->err_in_id) is_module_id = FALSE;
    } else if (num >= 11 && start_of_id_is("_GLOBAL__N_", ptr)) {
      /* g++ uses names beginning with "_GLOBAL__N_" to identify unnamed
         namespaces, and the EDG C++ Front End does also to be compatible
         with that. */
      write_id_str("<unnamed>", dctl);
      output_chars = FALSE;
    }  /* if */
    for (; num > 0; ptr++, num--) {
      if (*ptr == '\0') {
        /* The name string ends before enough characters have been
           accumulated. */
        bad_mangled_name(dctl);
        break;
      } else if (!isalnum((unsigned char)*ptr) && *ptr != '_') {
        /* Invalid character in identifier. */
        /* g++ names for unnamed namespaces contain bad characters,
           e.g., periods. */
        if (output_chars) {
          bad_mangled_name(dctl);
          break;
        }  /* if */
      } else if (output_chars) {
        write_id_ch(*ptr, dctl);
        if (is_module_id) {
          num_chars_to_output--;
          if (num_chars_to_output == 0) output_chars = FALSE;
        }  /* if */
      }  /* if */
    }  /* for */
  }  /* if */
  return ptr;
}  /* demangle_source_name */


static char *demangle_unqualified_name(
                                 char                       *ptr,
                                 a_boolean                  *is_no_return_name,
                                 a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <unqualified-name> and output the demangled form.
Return a pointer to the character position following what was demangled.
An <unqualified-name> encodes a name that is not qualified, e.g.,
"f" rather than "A::f".  The syntax is:

    <unqualified-name> ::= <operator-name>
                       ::= <ctor-dtor-name>  # Not handled here
                       ::= <source-name>   

Constructor and destructor names do not get here; see
demangle_nested_name_components.  *is_no_return_name is returned TRUE
if the name is one that does not get a return type (e.g., a
conversion function).  is_no_return_name can be NULL if the
caller does not need the value.
*/
{
  if (is_no_return_name != NULL) *is_no_return_name = FALSE;
  if (isdigit((unsigned char)*ptr)) {
    /* A <source-name>, which has a length followed by the characters
       of the identifier, as in "3abc". */
    ptr = demangle_source_name(ptr, /*is_module_id=*/FALSE, dctl);
  } else {
    /* <operator-name> */
    write_id_str("operator ", dctl);
    if (*ptr == 'c' && ptr[1] == 'v') {
      /* A conversion function. */
      if (is_no_return_name != NULL) *is_no_return_name = TRUE;
      ptr = demangle_type(ptr+2, dctl);
    } else {
      /* Other operator function (not conversion function). */
      int  num_operands;
      char *op_str, *close_str;
      op_str = get_operator_name(ptr, &num_operands, &close_str, dctl);
      if (op_str == NULL) {
        bad_mangled_name(dctl);
      } else {
        write_id_str(op_str, dctl);
        write_id_str(close_str, dctl);
        ptr += 2;
      }  /* if */
    }  /* if */
  }  /* if */
  return ptr;
}  /* demangle_unqualified_name */


static int get_hex_digit(char                       *ptr,
                         a_decode_control_block_ptr dctl)
/*
Convert a hexadecimal digit at ptr to an integral value, and return the
value.
*/
{
  int           value;
  unsigned char ch = (unsigned char)ptr[0];

  if (isdigit(ch)) {
    value = (ch - '0');
  } else if (isxdigit(ch) && islower(ch)) {
    value = (ch - 'a' + 10);
  } else {
    bad_mangled_name(dctl);
    value = 0;
  }  /* if */
  return value;
}  /* get_hex_digit */


static char *demangle_float_literal(char                       *ptr,
                                    a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 float literal and output the demangled form.
Return a pointer to the character position following what was demangled.
The syntax is:

  <expr-primary> ::= L <type <value float> E

<float> is the hexadecimal representation of the floating-point value,
high-order bytes first, using lower-case letters.
*/
{
  int  i, length;
  char *p;
  union {
#if USE_LONG_DOUBLE_FOR_HOST_FP_VALUE
    long double ld;
#endif /* USE_LONG_DOUBLE_FOR_HOST_FP_VALUE */
    double d;
    float f;
  } x;

  /* Zero the bits of x. */
#if USE_LONG_DOUBLE_FOR_HOST_FP_VALUE
  x.ld = 0.0;
#else /* !USE_LONG_DOUBLE_FOR_HOST_FP_VALUE */
  x.d = 0.0;
#endif /* USE_LONG_DOUBLE_FOR_HOST_FP_VALUE */
  /* Put parentheses around the type to make a cast. */
  write_id_ch('(', dctl);
  ptr = demangle_type(ptr+1, dctl);
  write_id_ch(')', dctl);
  /* Determine the number of digits in the value by scanning to the
     terminating "E". */
  length = 0;
  p = ptr;
  while (*p != 'E' && *p != '\0') {
    length++;
    p++;
  }  /* while */
  if (length % 2 != 0) {
    /* An odd number of bytes is an error. */
    bad_mangled_name(dctl);
    length -= 1;
  }  /* if */
  /* Convert the length to a byte count. */
  length /= 2;
  if (length > sizeof(x)) {
    /* Too many bytes is an error. */
    bad_mangled_name(dctl);
    length = sizeof(x);
  }  /* if */
  /* Convert the right number of bytes. */
  for (i = 0; i < length; i++, ptr+=2) {
    unsigned char byte = get_hex_digit(ptr, dctl);
    if (dctl->err_in_id) break;
    byte = byte<<4 | get_hex_digit(ptr+1, dctl);
    if (dctl->err_in_id) break;
    if (host_little_endian) {
      ((unsigned char *)&x)[length-1-i] = byte;
    } else {
      ((unsigned char *)&x)[i] = byte;
    }  /* if */
  }  /* for */
  if (!dctl->err_in_id) {
    /* Convert the floating-point value in x to a string. */
    char str[60];
    int  ndig;
    if (i <= sizeof(float)) {
#ifdef FLT_DIG
      ndig = FLT_DIG;
#else /* !defined(FLT_DIG) */
      ndig = 6;
#endif /* ifdef FLT_DIG */
      (void)sprintf(str, "%.*g", ndig, x.f);
#if USE_LONG_DOUBLE_FOR_HOST_FP_VALUE
    } else if (i > sizeof(double)) {
#ifdef LDBL_DIG
      ndig = LDBL_DIG;
#else /* !defined(LDBL_DIG) */
      ndig = 18;
#endif /* ifdef LDBL_DIG */
      (void)sprintf(str, "%.*Lg", ndig, x.ld);
#endif /* USE_LONG_DOUBLE_FOR_HOST_FP_VALUE */
    } else {
#ifdef DBL_DIG
      ndig = DBL_DIG;
#else /* !defined(DBL_DIG) */
      ndig = 15;
#endif /* ifdef DBL_DIG */
      (void)sprintf(str, "%.*g", ndig, x.d);
    }  /* if */
    /* Add trailing ".0" if no decimal point was put out (meaning the
       value is a whole number). */
    if (strchr(str, '.') == NULL &&
        strchr(str, 'e') == NULL) {
      p = str + strlen(str);
      *p++ = '.';
      *p++ = '0';
      *p++ = '\0';
    }  /* if */
    write_id_str(str, dctl);
    /* Skip the final "E". */
    ptr = advance_past('E', ptr, dctl);
  }  /* if */
  return ptr;
} /* demangle_float_literal */


static char *demangle_literal(char                       *ptr,
                              a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 literal or external name and output the demangled form.
Return a pointer to the character position following what was demangled.
The syntax is:

  <expr-primary> ::= L <type> <value number> E  # integer literal
                 ::= L <type <value float> E    # floating literal
                 ::= L_Z <encoding> E           # external name

*/
{
  if (ptr[1] == '_') {
    /* External name, L_Z <encoding> E. */
    if (ptr[2] != 'Z') {
      bad_mangled_name(dctl);
    } else {
      ptr = demangle_encoding(ptr+3, /*include_func_params=*/FALSE, dctl);
      ptr = advance_past('E', ptr, dctl);
    }  /* if */
  } else if (ptr[1] == 'f' || ptr[1] == 'd' ||
             ptr[1] == 'e' || ptr[1] == 'g') {
    /* Float literal, L <type> <hex> E, where <hex> is the hexadecimal
       representation of the value, high-order bytes first, with
       lower-case hex letters. */
    ptr = demangle_float_literal(ptr, dctl);
  } else {
    /* Integer literal, L <type> <value number> E. */
    /* Put parentheses around the type to make a cast. */
    write_id_ch('(', dctl);
    ptr = demangle_type(ptr+1, dctl);
    write_id_ch(')', dctl);
    /* Copy the literal value.  "n" is translated to a "-". */
    if (*ptr == 'n') {
      write_id_ch('-', dctl);
      ptr++;
    }  /* if */
    /* g++ 3.2 puts out L1xE instead of L_Z1xE, which gets demangled
       sort of okay in the g++ demangler because the name is treated
       as a type and a cast is put out with nothing following it: (x) */
    if (!isdigit((unsigned char)*ptr) && !emulate_gnu_abi_bugs) {
      bad_mangled_name(dctl);
    } else {
      while (isdigit((unsigned char)*ptr)) {
        write_id_ch(*ptr, dctl);
        ptr++;
      }  /* while */
    }  /* if */
    ptr = advance_past('E', ptr, dctl);
  }  /* if */
  return ptr;
}  /* demangle_literal */


static char *demangle_expression(char                       *ptr,
                                 a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <expression> and output the demangled form.
Return a pointer to the character position following what was demangled.
An <expression> encodes an expression (usually for a nontype
template argument value written in terms of template parameters).
The syntax is:

  <expression> ::= <unary operator-name> <expression>
               ::= <binary operator-name> <expression> <expression>
               ::= <trinary operator-name> <expression> <expression>
                                                                  <expression>
               ::= st <type>                    # sizeof(type)
               ::= <template-param>
               ::= sr <type> <unqualified-name> # dependent name
               ::= sr <type> <unqualified-name> <template-args>
                                                # dependent template-id
               ::= <expr-primary>

  <expr-primary> ::= L <type> <value number> E  # integer literal
                 ::= L <type <value float> E    # floating literal
                 ::= L <mangled-name> E         # external name

*/
{
  if (*ptr == 'L') {
    /* A literal or external name. */
    ptr = demangle_literal(ptr, dctl);
  } else if (*ptr == 'T') {
    /* A template parameter. */
    ptr = demangle_template_param(ptr, dctl);
  } else {
    int  num_operands;
    char *op_str = NULL, *close_str = "";
    /* An expression beginning with an operator name. */
    if (*ptr == 'v') {
      /* Vendor extended operator, used for alignof. */
      if (start_of_id_is("v112__alignof__e", ptr)) {
        /* __alignof__(expr) */
        op_str = "__alignof__(";
        close_str = ")";
        num_operands = 1;
        ptr += 16;
      } else if (start_of_id_is("v111__alignof__", ptr)) {
        /* __alignof__(type) */
        op_str = "__alignof__(";
        close_str = ")";
        num_operands = 0;
        ptr += 15;
      } else if (start_of_id_is("v19__uuidofe", ptr)) {
        /* __uuidof(expr) */
        op_str = "__uuidof(";
        close_str = ")";
        num_operands = 1;
        ptr += 12;
      } else if (start_of_id_is("v18__uuidof", ptr)) {
        /* __uuidof(type) */
        op_str = "__uuidof(";
        close_str = ")";
        num_operands = 0;
        ptr += 11;
      }  /* if */
    } else {
      /* Not an extended operator. */
      op_str = get_operator_name(ptr, &num_operands, &close_str, dctl);
      if (op_str != NULL) ptr += 2;
    }  /* if */
    if (op_str == NULL) {
      bad_mangled_name(dctl);
    } else {
      write_id_ch('(', dctl);
      if (num_operands == 1) {
        /* Unary operations. */
        if (strcmp(op_str, "cast") == 0) {
          /* Cast. */
          write_id_ch('(', dctl);
          ptr = demangle_type(ptr, dctl);
          write_id_ch(')', dctl);
        } else {
          /* Normal unary operator, not cast. */
          write_id_str(op_str, dctl);
        }  /* if */
        ptr = demangle_expression(ptr, dctl);
      } else if (num_operands == 2) {
        /* Binary operations. */
        ptr = demangle_expression(ptr, dctl);
        write_id_str(op_str, dctl);
        ptr = demangle_expression(ptr, dctl);
      } else if (num_operands == 3) {
        /* Ternary operations ("?"). */
        ptr = demangle_expression(ptr, dctl);
        write_id_str(op_str, dctl);
        ptr = demangle_expression(ptr, dctl);
        write_id_str(":", dctl);
        ptr = demangle_expression(ptr, dctl);
      } else {
        /* Special cases: sizeof(type), __alignof__(type),
           __uuidof(type), scope resolution "::" */
        if (strcmp(op_str, "sizeof(") == 0) {
          /* sizeof(type). */
          write_id_str(op_str, dctl);
          ptr = demangle_type(ptr, dctl);
        } else if (strcmp(op_str, "__alignof__(") == 0) {
          /* __alignof__(type). */
          write_id_str(op_str, dctl);
          ptr = demangle_type(ptr, dctl);
        } else if (strcmp(op_str, "__uuidof(") == 0) {
          /* __uuidof(type). */
          write_id_str(op_str, dctl);
          ptr = demangle_type(ptr, dctl);
        } else if (strcmp(op_str, "::") == 0) {
          /* Scope resolution "::":
               sr <type> <name>
             The <name> is limited to <unqualified-name> or
             <unqualified-name> <template-args>, but we don't check that. */
          a_func_block func_block;
          a_boolean    gpp_qualified_name = FALSE;
          if (emulate_gnu_abi_bugs) {
            /* g++ 3.2 sometimes puts out a qualified name as the second
               operand.  Look ahead to see whether that form is used.
               If so, we want to skip over the type but not output it,
               because the qualified name repeats that type. */
            char *ptr2;
            dctl->suppress_id_output++;
            dctl->suppress_substitution_recording++;
            ptr2 = demangle_type(ptr, dctl);
            dctl->suppress_id_output--;
            dctl->suppress_substitution_recording--;
            if (*ptr2 == 'N') {
              gpp_qualified_name = TRUE;
              /* Scan the type again to get substitutions recorded. */
              dctl->suppress_id_output++;
              ptr = demangle_type(ptr, dctl);
              dctl->suppress_id_output--;
            }  /* if */
          }  /* if */
          if (!gpp_qualified_name) {
            ptr = demangle_type(ptr, dctl);
            write_id_str(op_str, dctl);
          }  /* if */
          ptr = demangle_name(ptr, &func_block, dctl);
          if (emulate_gnu_abi_bugs) {
            /* g++ 3.2 puts out the parameter types following the name
               of a function. */
            int  num_operands;
            char *close_str;
            if (*ptr == 'E' || *ptr == '_') {
              /* No expression or parameter list next. */
            } else if (*ptr == 'L' ||
                       get_operator_name(ptr, &num_operands,
                                         &close_str, dctl) != NULL) {
              /* Another expression is next, so no parameter list. */
            } else {
              /* Scan the parameter list. */
              dctl->suppress_id_output++;
              ptr = demangle_bare_function_type(ptr, /*no_return_type=*/TRUE,
                                                dctl);
              dctl->suppress_id_output--;
            }  /* if */
          }  /* if */
        } else {
          bad_mangled_name(dctl);
        }  /* if */
      }  /* if */
      write_id_str(close_str, dctl);
      write_id_ch(')', dctl);
    }  /* if */
  }  /* if */
  return ptr;
}  /* demangle_expression */


static char *demangle_template_args(char                       *ptr,
                                    a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <template-args> and output the demangled form.
Return a pointer to the character position following what was demangled.
A <template-args> encodes a template argument list.  The syntax is:

  <template-args> ::= I <template-arg>+ E
  <template-arg> ::= <type>                     # type or template
                 ::= L <type> <value number> E  # literal
                 ::= L_Z <encoding> E           # external name
                 ::= X <expression> E           # expression

*/
{
  /* Advance past the "I". */
  ptr++;
  write_id_ch('<', dctl);
  for (;;) {
    if (*ptr == 'X') {
      /* An expression, X <expression> E. */
      ptr = demangle_expression(ptr+1, dctl);
      ptr = advance_past('E', ptr, dctl);
    } else if (*ptr == 'L') {
      /* Literal or external name. */
      ptr = demangle_literal(ptr, dctl);
    } else {
      /* Type template argument. */
      ptr = demangle_type(ptr, dctl);
    }  /* if */
    /* "E" ends the template argument list. */
    if (*ptr == 'E') break;
    /* Stop on an error. */
    if (dctl->err_in_id) break;
    /* Continuing, so put out a comma between template arguments. */
    write_id_str(", ", dctl);
  }  /* for */
  ptr = advance_past('E', ptr, dctl);
  write_id_ch('>', dctl);
  return ptr;
}  /* demangle_template_args */


static char *demangle_nested_name_components(
                              char                       *ptr,
                              unsigned long              num_levels,
                              a_boolean                  *is_no_return_name,
                              a_boolean                  *has_templ_arg_list,
                              char                       *ctor_dtor_kind,
                              char                       **last_component_name,
                              a_decode_control_block_ptr dctl)
/*
Demangle one or more name level components of an IA-64 <nested-name>.
Each level is either an unqualified name or a substitution, optionally
followed by a template argument list.  ptr points to the beginning of
the <nested-name>, after the initial "N" and the <CV-qualifiers> if any.
If num_levels is zero, scan all components of the nested name, stopping
on the final "E"; otherwise, scan num_levels levels and then stop.
Note that a substitution counts as one level even if it represents
several.  Return a pointer to the character position following what
was demangled.  *is_no_return_name is returned TRUE if the final
component scanned is a function name of a kind that does not take a
return type (constructor, destructor, or conversion function).
*has_templ_arg_list is returned TRUE if the final component includes a
template argument list.  If the final component is a constructor or
destructor name, *ctor_dtor_kind is set to the character identifying
the kind of constructor or destructor.  If last_component_name is non-NULL,
*last_component_name will be set to the start position of the encoding
for the name of the last component.  If the last component is a
substitution, the name of the last component in the substitution is used.
*/
{
  char          *prev_component_name = NULL;
  char          *first_component_start = ptr;
  unsigned long level_num = 0;

  *is_no_return_name = FALSE;
  *has_templ_arg_list = FALSE;
  *ctor_dtor_kind = ' ';
  for (;;) {
    /* Demangle one level of the nested name. */
    a_boolean is_substitution = FALSE;
    level_num++;
    *is_no_return_name = FALSE;
    *has_templ_arg_list = FALSE;
    if (*ptr == 'E' || *ptr == '\0') {
      /* Error, unexpected end of nested name. */
      bad_mangled_name(dctl);
    } else if (*ptr == 'S') {
      /* A substitution. */
      is_substitution = TRUE;
      ptr = demangle_substitution(ptr, 0, CVQ_NONE,
                                  /*under_lhs_declarator=*/FALSE,
                                  /*need_trailing_space=*/FALSE,
                                  &prev_component_name, dctl);
      /* A substitution cannot be the last thing; it must be followed
         by another name or a template argument list. */
      if (*ptr == 'E') {
        bad_mangled_name(dctl);
      }  /* if */
    } else if (*ptr == 'T') {
      /* A <template-param>. */
      ptr = demangle_template_param(ptr, dctl);
    } else {
      /* Not a substitution or template parameter, so an <unqualified-name>. */
      if (*ptr != 'C' && *ptr != 'D') {
        /* Normal case, not a constructor or destructor name. */
        prev_component_name = ptr;
        ptr = demangle_unqualified_name(ptr, is_no_return_name, dctl);
      } else {
        /* A constructor or destructor name.  Put out the class name again
           (it's provided by prev_component_name). */
        *is_no_return_name = TRUE;
        if (*ptr == 'D') write_id_ch('~', dctl);
        if (prev_component_name == NULL ||
            *prev_component_name == 'S') {
          /* The constructor or destructor code is the first thing in the
             nested name or the previous name is a substitution (we're
             supposed to have gotten the name from inside the
             substitution).  */
          bad_mangled_name(dctl);
        } else {
          a_boolean dummy;
          /* Rescan and output the class name (no template argument list). */
          (void)demangle_unqualified_name(prev_component_name, &dummy, dctl);
          /* Check that the second character of the constructor/destructor
             name is a valid digit. */
          /* '9' is the code used by the EDG C++ Front End for the
             underlying routine called by the various entry points.
             It's not part of the ABI spec. */
          if (ptr[1] == '1' || ptr[1] == '2' || ptr[1] == '9' ||
              (ptr[0] == 'C' ? ptr[1] == '3' :
                               ptr[1] == '0')) {
            /* Okay. */
            *ctor_dtor_kind = ptr[1];
            ptr += 2;
          } else {
            /* The second character of the constructor or destructor name
               encoding is bad. */
            bad_mangled_name(dctl);
          }  /* if */
        }  /* if */
      }  /* if */
    }  /* if */
    if (*ptr == 'I') {
      /* A <template-args> list. */
      /* Record a potential substitution on the template prefix up to
         this point, but not if the entire prefix is a substitution. */
      if (!is_substitution) {
        record_substitutable_entity(first_component_start,
                                    subk_template_prefix, level_num-1, dctl);
      }  /* if */
      /* Scan the template argument list. */
      ptr = demangle_template_args(ptr, dctl);
      *has_templ_arg_list = TRUE;
      is_substitution = FALSE;
    }  /* if */
    /* "E" marks the end of the list. */
    if (*ptr == 'E') break;
    if (!is_substitution) {
      /* Record a potential substitution on the prefix up to this point,
         but not if the entire prefix is a substitution (without
         template argument list). */
      record_substitutable_entity(first_component_start, subk_prefix,
                                  level_num, dctl);
    }  /* if */
    /* Stop on an error. */
    if (dctl->err_in_id) break;
    /* Stop if we've done enough levels. */
    if (num_levels != 0 && level_num >= num_levels) break;
    /* Going around again, so the part put out so far is a qualifier and
       needs to be followed by "::". */
    write_id_str("::", dctl);
  }  /* for */
  if (last_component_name != NULL) *last_component_name = prev_component_name;
  return ptr;
}  /* demangle_nested_name_components */


static char *demangle_nested_name(char                       *ptr,
                                  a_func_block               *func_block,
                                  a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <nested-name> and output the demangled form.  Return
a pointer to the character position following what was demangled.
A <nested-name> represents a qualified name, e.g., A::B::x.
The syntax is:

    <nested-name> ::= N [<CV-qualifiers>] <prefix> <unqualified-name> E
                  ::= N [<CV-qualifiers>] <template-prefix> <template-args> E
    <prefix> ::= <prefix> <unqualified-name>
             ::= <template-prefix> <template-args>
             ::= <template-param>
             ::= # empty
             ::= <substitution>
    <template-prefix> ::= <prefix> <template unqualified-name>
                      ::= <template-param>
                      ::= <substitution>

For function names, additional information is returned in *func_block.
*/
{
  a_boolean has_templ_arg_list;
  a_boolean is_no_return_name;

  clear_func_block(func_block);
  /* Skip the initial "N". */
  ptr++;
  /* Accumulate <CV-qualifiers> if present. */
  ptr = get_cv_qualifiers(ptr, &func_block->cv_quals);
  /* Get all the components of the nested name. */
  ptr = demangle_nested_name_components(ptr,
                                        /*num_levels=*/0,
                                        &is_no_return_name,
                                        &has_templ_arg_list,
                                        &func_block->ctor_dtor_kind,
                                        (char **)NULL,
                                        dctl);
  ptr = advance_past('E', ptr, dctl);
  /* The function will have no return type if it is not a template. */
  if (!has_templ_arg_list) {
    func_block->no_return_type = TRUE;
  }  /* if */
  /* The function will have no return type if it is a constructor,
     destructor, or conversion function. */
  if (is_no_return_name) {
    func_block->no_return_type = TRUE;
  }  /* if */
  return ptr;
}  /* demangle_nested_name */


static char *demangle_local_name(char                       *ptr,
                                 a_func_block               *func_block,
                                 a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <local-name> and output the demangled form.  Return
a pointer to the character position following what was demangled.
A <local-name> represents an entity local to a function, and
includes the mangled name of the enclosing function.
The syntax is:

  <local-name> := Z <function encoding> E <entity name> [<discriminator>]
               := Z <function encoding> E s [<discriminator>]
  <discriminator> := _ <non-negative number> 

For function names, additional information is returned in *func_block.
*/
{
  clear_func_block(func_block);
  /* Skip over the "Z". */
  ptr++;
  /* Demangle the function name. */
  ptr = demangle_encoding(ptr, /*include_func_params=*/TRUE, dctl);
  ptr = advance_past('E', ptr, dctl);
  write_id_str("::", dctl);
  if (*ptr == 's') {
    /* String literal. */
    write_id_str("string", dctl);
    ptr++;
  } else {
    /* Demangle the entity name. */
    ptr = demangle_name(ptr, func_block, dctl);
  }  /* if */
  if (*ptr == '_') {
    /* Demangle the discriminator. */
    long num;
    ptr = get_number(ptr+1, &num, dctl);
    if (num < 0) {
      bad_mangled_name(dctl);
    } else {
      char buffer[50];
      write_id_str(" (instance ", dctl);
      (void)sprintf(buffer, "%ld", num+2);
      write_id_str(buffer, dctl);
      write_id_ch(')', dctl);
    }  /* if */
  }  /* if */
  return ptr;
}  /* demangle_local_name */


static char *demangle_unscoped_name(char                       *ptr,
                                    a_func_block               *func_block,
                                    a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <unscoped-name> and output the demangled form.
Return a pointer to the character position following what was demangled.
The syntax is:

    <unscoped-name> ::= <unqualified-name>
                    ::= St <unqualified-name>   # ::std::

For function names, additional information is updated in *func_block.
*/
{
  a_boolean is_no_return_name;

  if (*ptr == 'S' && ptr[1] == 't') {
    /* "St" for "std::". */
    write_id_str("std::", dctl);
    ptr += 2;
  }  /* if */
  ptr = demangle_unqualified_name(ptr, &is_no_return_name, dctl);
  func_block->no_return_type = is_no_return_name;
  return ptr;
}  /* demangle_unscoped_name */


static char *demangle_name(char                       *ptr,
                           a_func_block               *func_block,
                           a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <name> and output the demangled form.  Return
a pointer to the character position following what was demangled.
The syntax is:

    <name> ::= <nested-name>
           ::= <unscoped-name>
           ::= <unscoped-template-name> <template-args>
           ::= <local-name>
    <unscoped-template-name> ::= <unscoped-name>
                             ::= <substitution>

For function names, additional information is returned in *func_block.

As an EDG extension, allow

    B <source-name>

as a prefix to specify a module id for an externalized name.
*/
{
  clear_func_block(func_block);
  if (*ptr == 'B') {
    /* Module-id prefix for externalized name. */
    write_id_str("[static from ", dctl);
    ptr = demangle_source_name(ptr+1, /*is_module_id=*/TRUE, dctl);
    write_id_str("] ", dctl);
  }  /* if */
  if (*ptr == 'N') {
    /* Nested name, for something like "A::f". */
    ptr = demangle_nested_name(ptr, func_block, dctl);
  } else if (*ptr == 'Z') {
    /* Local name, identifies function and entity local to the function. */
    ptr = demangle_local_name(ptr, func_block, dctl);
  } else {
    /* <unscoped-name> or <unscoped-template-name> <template-args>. */
    if (*ptr == 'S' && ptr[1] != '\0' && ptr[2] == 'I') {
      /* <substitution> in <unscoped-template-name>, because it's
         followed by the "I" beginning a <template-args>. */
      ptr = demangle_substitution(ptr, 0, CVQ_NONE,
                                  /*under_lhs_declarator=*/FALSE,
                                  /*need_trailing_space=*/FALSE,
                                  (char **)NULL, dctl);
    } else {
      /* An <unscoped-name>, possibly as the whole of an
         <unscoped-template-name>.  */
      char *start = ptr;
      ptr = demangle_unscoped_name(ptr, func_block, dctl);
      if (*ptr == 'I') {
        /* This is a template because it is followed by a template arguments
           list.  Record the template as a potential substitution. */
        record_substitutable_entity(start, subk_unscoped_template_name, 0L,
                                    dctl);
      }  /* if */
    }  /* if */
    if (*ptr == 'I') {
      /* A <template-args> list. */
      ptr = demangle_template_args(ptr, dctl);
    } else {
      /* Non-template functions do not have return types encoded. */
      func_block->no_return_type = TRUE;
    }  /* if */
  }  /* if */
  return ptr;
}  /* demangle_name */


static char *demangle_call_offset(char                       *ptr,
                                  a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <call_offset> and output the demangled form.  Return
a pointer to the character position following what was demangled.
A <call-offset> is used in the encoded name for a thunk for a
virtual function.  The syntax is:

  <call-offset> ::= h <nv-offset> _
                ::= v <v-offset> _
  <nv-offset> ::= <offset number> # non-virtual base override
  <v-offset>  ::= <offset number> _ <virtual offset number>
                                  # virtual base override, with vcall offset

*/
{
  long      num;
  char      buffer[50];
  a_boolean v_form = FALSE;

  if (*ptr != 'h' && *ptr != 'v') {
    bad_mangled_name(dctl);
  } else {
    v_form = (*ptr == 'v');
    write_id_str("(offset ", dctl);
    ptr = get_number(ptr+1, &num, dctl);
    (void)sprintf(buffer, "%ld", num);
    write_id_str(buffer, dctl);
    if (v_form) {
      write_id_str(", virtual offset ", dctl);
      ptr = advance_past_underscore(ptr, dctl);
      ptr = get_number(ptr, &num, dctl);
      (void)sprintf(buffer, "%ld", num);
      write_id_str(buffer, dctl);
    }  /* if */
    ptr = advance_past_underscore(ptr, dctl);
    write_id_str(") ", dctl);
  }  /* if */
  return ptr;
}  /* demangle_call_offset */


static char *demangle_special_name(char                       *ptr,
                                   a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <special-name> and output the demangled form.  Return
a pointer to the character position following what was demangled.
Special names are used for generated things like virtual function tables.
The syntax is:

  <special-name> ::= TV <type>  # virtual table
                 ::= TT <type>  # VTT structure (construction vtable index)
                 ::= TI <type>  # typeinfo structure
                 ::= TS <type>  # typeinfo name (null-terminated byte string)
                 ::= GV <object name> # Guard variable for one-time init
                 ::= T <call-offset> <base encoding>
                      # base is the nominal target function of thunk
                 ::= Tc <call-offset> <call-offset> <base encoding>
                      # base is the nominal target function of thunk
                      # first call-offset is 'this' adjustment
                      # second call-offset is result adjustment

*/
{
  if (*ptr == 'G') {
    if (ptr[1] == 'V') {
      /* Guard variable, GV <object name>. */
      a_func_block func_block;
      write_id_str("Initialization guard variable for ", dctl);
      ptr = demangle_name(ptr+2, &func_block, dctl);
    } else {
      bad_mangled_name(dctl);
    }  /* if */
  } else if (*ptr == 'T') {
    if (ptr[1] == 'V') {
      /* Virtual table, TV <type>. */
      write_id_str("Virtual function table for ", dctl);
      ptr = demangle_type(ptr+2, dctl);
    } else if (ptr[1] == 'T') {
      /* Virtual table table, TT <type>. */
      write_id_str("Virtual table table for ", dctl);
      ptr = demangle_type(ptr+2, dctl);
    } else if (ptr[1] == 'I') {
      /* Typeinfo, TI <type>. */
      write_id_str("Typeinfo for ", dctl);
      ptr = demangle_type(ptr+2, dctl);
    } else if (ptr[1] == 'S') {
      /* Typeinfo name, TS <type>. */
      write_id_str("Typeinfo name for ", dctl);
      ptr = demangle_type(ptr+2, dctl);
    } else if (ptr[1] == 'c') {
      /* Covariant thunk, Tc <call-offset> <call-offset> <base encoding>. */
      write_id_str("Covariant thunk for ", dctl);
      ptr = demangle_call_offset(ptr+2, dctl);
      ptr = demangle_call_offset(ptr, dctl);
      ptr = demangle_encoding(ptr, /*include_func_params=*/TRUE, dctl);
    } else if (ptr[1] == 'h' || ptr[1] == 'v') {
      /* Thunk, T <call-offset> <base encoding>. */
      write_id_str("Thunk for ", dctl);
      ptr = demangle_call_offset(ptr+1, dctl);
      ptr = demangle_encoding(ptr, /*include_func_params=*/TRUE, dctl);
    } else {
      bad_mangled_name(dctl);
    }  /* if */
  } else {
    bad_mangled_name(dctl);
  }  /* if */
  return ptr;
}  /* demangle_special_name */


static char *demangle_encoding(char                       *ptr,
                               a_boolean                  include_func_params,
                               a_decode_control_block_ptr dctl)
/*
Demangle an IA-64 <encoding> and output the demangled form.  Return
a pointer to the character position following what was demangled.
<encoding> is almost the top-level term in the grammar; it's what
follows the initial "_Z" in a mangled name.  The syntax is:

    <encoding> ::= <function name> <bare-function-type>
               ::= <data name>
               ::= <special-name>

Do not output function parameters if include_func_params is FALSE.
*/
{
  /* Special names begin with "T" (e.g., TV for a virtual function table)
     or "GV" for a guard variable. */
  if (*ptr == 'T' || (*ptr == 'G' && ptr[1] == 'V')) {
    ptr = demangle_special_name(ptr, dctl);
  } else {
    /* Function or data name. */
    a_func_block func_block;
    ptr = demangle_name(ptr, &func_block, dctl);
    /* If there's more, it's the <bare-function-type>. */
    if (*ptr != '\0' && *ptr != 'E') {
      if (!include_func_params) dctl->suppress_id_output++;
      ptr = demangle_bare_function_type(ptr, func_block.no_return_type, dctl);
      if (include_func_params && func_block.cv_quals != 0) {
        /* Put out cv-qualifiers for a member function. */
        write_id_ch(' ', dctl);
        output_cv_qualifiers(func_block.cv_quals,
                             /*trailing_space=*/FALSE, dctl);
      }  /* if */
      if (!include_func_params) dctl->suppress_id_output--;
    }  /* if */
    if (func_block.ctor_dtor_kind != ' ') {
      /* Identify the kind of constructor or destructor if necessary. */
      switch (func_block.ctor_dtor_kind) {
        case '0':
          write_id_str(" [deleting]", dctl);
          break;
        case '1':
          /* Complete constructor or destructor gets no extra label. */
          break;
        case '2':
          write_id_str(" [subobject]", dctl);
          break;
        case '3':
          write_id_str(" [allocating]", dctl);
          break;
        case '9':
          /* The EDG front end uses '9' for the routine called by the
             other entry points. */
          write_id_str(" [internal]", dctl);
          break;
        default:
          /* Bad character.  This shouldn't happen, because the character
             was checked earlier. */
          bad_mangled_name(dctl);
      }  /* switch */
    }  /* if */
  }  /* if */
  return ptr;
}  /* demangle_encoding */


void decode_identifier(char      *id,
                       char      *output_buffer,
                       sizeof_t  output_buffer_size,
                       a_boolean *err,
                       a_boolean *buffer_overflow_err,
                       sizeof_t  *required_buffer_size)
/*
Demangle the identifier id (which is null-terminated), and put the demangled
form (null-terminated) into the output_buffer provided by the caller.
A name that is not mangled is copied unchanged to output_buffer.
output_buffer_size gives the allocated size of output_buffer.  If there
is some error in the demangling process, *err will be returned TRUE.
In addition, if the error is that the output buffer is too small,
*buffer_overflow_err will (also) be returned TRUE, and *required_buffer_size
is set to the size of buffer required to do the demangling.  Note that
if the mangled name is compressed, and the buffer size is smaller than
the size of the uncompressed mangled name, the size returned will be
enough to uncompress the name but not enough to produce the demangled form.
The caller must be prepared in that case to loop a second time (the
length returned the second time will be correct).
*/
{
  char                       *end_ptr;
  a_decode_control_block     control_block;
  a_decode_control_block_ptr dctl = &control_block;

  clear_control_block(dctl);
  dctl->input_id_len = strlen(id);
  dctl->output_id = output_buffer;
  dctl->output_id_size = output_buffer_size;
  num_substitutions = 0;
  {
    /* Determine whether host is little-endian or big-endian. */
    int i = 1;
    host_little_endian = (*(char *)&i) == 1;
  }
  if (start_of_id_is("_Z", id)) {
    /* A mangled name, beginning with "_Z". */
    end_ptr = demangle_encoding(id+2, /*include_func_params=*/TRUE, dctl);
  } else {
    /* A non-mangled name.  Just copy. */
    write_id_str(id, dctl);
    end_ptr = NULL;
  }  /* if */
  if (dctl->output_overflow_err) {
    dctl->err_in_id = TRUE;
  } else {
    /* Add a terminating null. */
    dctl->output_id[dctl->output_id_len] = 0;
  }  /* if */
  /* Make sure the whole identifier was taken. */
  if (!dctl->err_in_id && end_ptr != NULL && *end_ptr != '\0') {
    bad_mangled_name(dctl);
  }  /* if */
  *err = dctl->err_in_id;
  *buffer_overflow_err = dctl->output_overflow_err;
  *required_buffer_size = dctl->output_id_len + 1; /* +1 for final null. */
}  /* decode_identifier */


/*
Result status codes used by __cxa_demangle.
*/
#define CXA_DEMANGLE_SUCCESS		 0
#define CXA_DEMANGLE_ALLOC_FAILURE	-1
#define CXA_DEMANGLE_INVALID_NAME	-2
#define CXA_DEMANGLE_INVALID_ARGUMENTS	-3

#define EXTERN_C
EXTERN_C char *__cxa_demangle(char		*mangled_name,
			      char		*user_buffer,
			      true_size_t	*user_buffer_size,
			      int		*status)
/*
Demangling library interface specified by the IA-64 ABI. "mangled_name"
is the name to be demangled.  "user_buffer" is the buffer into which the
demangled name should be placed.  "user_buffer_size" is the size of
"user_buffer".  If "user_buffer" is NULL or is too small, it is reallocated
and "user_buffer_size" is set to the new size.
*/
{
#define TEMP_BUFFER_SIZE 256
  int		result_status = CXA_DEMANGLE_SUCCESS;
  char		temp_buffer[TEMP_BUFFER_SIZE];
  char		*buf_to_use = NULL;
  a_boolean	temp_buffer_used = FALSE;
  sizeof_t	buf_size = 0;

  if (user_buffer != NULL && user_buffer_size == NULL) {
    /* A buffer was provided but its size is not specified. */
    result_status = CXA_DEMANGLE_INVALID_ARGUMENTS;
  } else {
    /* Demangle the name. */
    a_boolean	err;
    a_boolean	buffer_overflow_err;
    sizeof_t	required_buffer_size;
    /* If no buffer was provided by the caller, try using temp_buffer. */
    if (user_buffer == NULL) {
      buf_to_use = temp_buffer;
      temp_buffer_used = TRUE;
      buf_size = TEMP_BUFFER_SIZE;
    } else {
      buf_to_use = user_buffer;
      buf_size = *user_buffer_size;
    }  /* if */
    do {
      decode_identifier(mangled_name, buf_to_use, buf_size, &err,
                        &buffer_overflow_err, &required_buffer_size);
      if (buffer_overflow_err) {
        /* The buffer was too small.  Allocate a new buffer. */
        if (temp_buffer_used || buf_to_use == user_buffer) {
          /* We previously used a local buffer or we used the buffer
             supplied by the user.  Allocate a new one.  Note that we
             don't free the user buffer yet because an error might still
             occur and we can only provide the new buffer address in cases
             where we return successfully. */
          buf_to_use = malloc((true_size_t)required_buffer_size);
          temp_buffer_used = FALSE;
        } else {
          /* We are using a user-buffer.  Reallocate that buffer. */
          buf_to_use = realloc(buf_to_use, (true_size_t)required_buffer_size);
        }  /* if */
        buf_size = required_buffer_size;
        if (buf_to_use == NULL) {
          /* The allocation failed. */
          result_status = CXA_DEMANGLE_ALLOC_FAILURE;
        }  /* if */
      } else if (err) {
        /* A name decoding error occurred. */
        result_status = CXA_DEMANGLE_INVALID_NAME;
      }  /* if */
      /* Continue looping until decode_identifier succeeds.  If an error
         was detected, terminate the loop. */
    } while (err && result_status == CXA_DEMANGLE_SUCCESS);
    if (result_status == CXA_DEMANGLE_SUCCESS && temp_buffer_used) {
      /* The temporary buffer was used.  Copy the result to a dynamically
         allocated buffer. */
      true_size_t	size;
      size = strlen(temp_buffer) + 1;
      buf_to_use = malloc(size);
      if (buf_to_use == NULL) {
        result_status = CXA_DEMANGLE_ALLOC_FAILURE;
      } else {
        (void)strcpy(buf_to_use, temp_buffer);
      }  /* if */
    }  /* if */
  }  /* if */
  /* Return the status to the caller. */
  if (status != NULL) *status = result_status;
  /* Return NULL if there was an error. */
  if (result_status != CXA_DEMANGLE_SUCCESS) {
    /* If the buffer being used was allocated above, free it now. */
    if (!temp_buffer_used &&
        user_buffer != NULL && buf_to_use != user_buffer) {
       free(buf_to_use);
    }  /* if */
    buf_to_use = NULL;
  } else {
    /* The demangling was successful. */
    /* If the buffer being returned is not the buffer supplied by the
       user, free the user buffer. */
    if (user_buffer != NULL && buf_to_use != user_buffer) {
      free(user_buffer);
      /* Update the size parameter passed in. */
      if (user_buffer_size != NULL) {
        *user_buffer_size = buf_size;
      }  /* if */
    }  /* if */
  }  /* if */
  return buf_to_use;
#undef TEMP_BUFFER_SIZE
}  /* __cxa_demangle */

#endif /* !IA64_ABI */

/******************************************************************************
*                                                             \  ___  /       *
*                                                               /   \         *
* Edison Design Group C++/C Front End                        - | \^/ | -      *
*                                                               \   /         *
*                                                             /  | |  \       *
* Copyright 1996-2002 Edison Design Group Inc.                   [_]          *
*                                                                             *
******************************************************************************/
