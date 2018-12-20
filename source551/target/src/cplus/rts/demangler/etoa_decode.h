/*
	Intent of this file is only to get a compile time validation
	of the 'type translation' from EDG's generic types to basic ones.

	Without this translation we would have to drag in EDG's include
	files in demangle.c
*/

#ifndef ETOA_DECODE_H
#define ETOA_DECODE_H 1

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef size_t	sizeof_t;
typedef size_t  true_size_t;
typedef int	a_boolean;

#define FALSE 0
#define TRUE 1

extern void decode_identifier(char   *id,
			      char   *output_buffer,
			      sizeof_t output_buffer_size,
			      int    *err,
			      int    *buffer_overflow_err,
			      sizeof_t *required_buffer_size);


void cfront_decode_identifier(char      *id,
			      char      *output_buffer,
			      sizeof_t  output_buffer_size,
			      a_boolean *err,
			      a_boolean *buffer_overflow_err,
			      sizeof_t  *required_buffer_size);

a_boolean is_IA64_encoded_identifier(char * id);

void IA64_decode_identifier(char      *id,
			    char      *output_buffer,
			    sizeof_t  output_buffer_size,
			    a_boolean *err,
			    a_boolean *buffer_overflow_err,
			    sizeof_t  *required_buffer_size);

#ifndef ENABLE_GNU_LIKE_OUTPUT
#define ENABLE_GNU_LIKE_OUTPUT TRUE
#endif

#if ENABLE_GNU_LIKE_OUTPUT
void decode_identifier_styled(char      *id,
			      int       act_like_gnu,
			      int       suppress_function_params,
			      char      *output_buffer,
			      sizeof_t  output_buffer_size,
			      a_boolean *err,
			      a_boolean *buffer_overflow_err,
			      sizeof_t  *required_buffer_size);
#endif

#endif /* ifndef ETOA_DECODE_H */
