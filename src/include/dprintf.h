#ifndef DPRINTF_H
#define DPRINTF_H

#include <stdio.h>

#ifdef DEBUG
#define DPRINTF(x...) printf(x)
#else
#define DPRINTF(x...)
#endif

#endif