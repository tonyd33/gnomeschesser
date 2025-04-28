#ifndef _MERGE_H_
#define _MERGE_H_

#include <stdio.h>

#define MERGE_OK 0
#define MERGE_ERR (-1)

int merge(FILE **books, int books_len, FILE *ofp);

#endif /* _MERGE_H_ */
