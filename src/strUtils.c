#ifndef STRUTILS_H
#define STRUTILS_H

char** str_split(char* a_str, const char a_delim);


/**
 * @brief  method returns true if it can extract needed info from path, otherwise false.
 * In case of true, it also updates mountString, mountPoint and newCWD parameters
 * It splits path by ":", and requires a minimum of 3 elements
 * @example if path = hdd0:__common:pfs:/retroarch/ then: mountString = "pfs:", mountPoint = "hdd0:__common", newCWD = pfs:/retroarch/
 * @param path input parameter with full hdd path (`hdd0:__common:pfs:/retroarch/`)
 * @param mountString pointer to char* wich will contain pfs mountpoint (`pfs:`)
 * @param mountPoint returns the path of mounted partition (`hdd0:__common`)
 * @param newCWD returns the path to the file as pfs mount point string
 * @return true on success
*/
int getMountInfo(char *path, char *mountString, char *mountPoint, char *newCWD);

#endif