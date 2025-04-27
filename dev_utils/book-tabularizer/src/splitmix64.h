#ifndef _SPLITMIX64_H_
#define _SPLITMIX64_H_
#include <stdint.h>

uint64_t next();
void seed(uint64_t);

#endif /* _SPLITMIX64_H_ */
