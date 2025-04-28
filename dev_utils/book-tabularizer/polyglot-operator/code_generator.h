#ifndef _GENERATOR_H_
#define _GENERATOR_H_

#include <stdio.h>

#define GENERATOR_OK 0
#define GENERATOR_ERR (-1)

int generate(FILE *rfp, FILE* wfp);

#endif /* _GENERATOR_H_ */
