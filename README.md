# TPDD stuff

---- (sunset notice) ----

This project is essentially now obsolete. See [pdd.sh](https://github.com/bkw777/pdd.sh) instead.

SECTR2.BA below only works on TPDD2, can not read all parts of the disk, can not write to the disk, relies on some inscrutable machine code included inside the BASIC code (which I did not write and can not explain), and only runs on the slow vinatge computer.

SECTR2.BA is mildly interesting in that it lets you examine raw bytes on a disk directly from the portable.

But I have since written [pdd.sh](https://github.com/bkw777/pdd.sh) which allows both reading and writing raw sectors, including the metadata parts, supports both TPDD1 and TPDD2, relies on no machine code, and runs on any modern machine or OS.

---- (original readme) ----

Utilities related to the Tandy Portable Disk Drive and Tandy Portable Disk Drive 2

Initially there is only a modified version of SECTOR.BA, a TPDD2 sector reader.

The intent of this project is to use all of the references below to put together one or more tools implemented in a more open, generic, and flexible form than what's currently available.  
The info is spread among a few different places, but the necessary bits of info for both TPDD1 and TPDD2 are documented  

## TPDD1_sector.bas / SECTR1.DO
BASIC program to access raw sectors on a TPDD1  
Does not exist yet. Placeholder.

## TPDD2_sector.bas / SECTR2.DO
BASIC program to access raw sectors on a TPDD2

Modified from [SECTOR.BA](https://ftp.whtech.com/club100/drv/sector.ba)

Modified to include a whole-disk continuus dump option without stopping at the end of each sector, and no page breaks in the output, and an alternate output format that's better for processing by other tools.  
Intended to be used with [LPT_Capture](https://github.com/bkw777/LPT_Capture).

This does not require floppy.co or Powr-DOS or any other software installed on the portable, and this expanded version is a little easier to read and work on so the BASIC code is fairly scrutable, however unfortunately there still is a short machine language routine embedded in the BASIC code which is not explained or documented at all.

If this program is interrupted ungracefully, by pressing shift+break or if it crashes etc, the UART is left in a non-working state, and the serial port won't work any more.  
For instance, TS-DOS won't work.
If that happens, just re-enter the program and then exit gracefully by hitting the ESC key.

A packed version is in the [releases](../../releases/latest) tab.

## dump2bin.sh

Bash one-liner to convert the text hex dump to binary.  
Input is the "M" machine format whole-disk dump from TPDD2_sector.bas

Usage:

    dump2bin.sh <in.txt >out.bin

# dependencies
Makefile uses barenum and bapack from [BA_stuff](https://github.com/bkw777/BA_stuff)  
"make install" uses the bootstrap function in [dlplus](https://github.com/bkw777/dlplus)  

# references

TPDD1 operation manual https://archive.org/details/TandyPortableDiskDriveOperationManual26-3808/  
TPDD1 software manual (documents sector access) https://archive.org/details/TandyPortableDiskDriveSoftwareManual26-3808s/  
TPDD1 service manual https://archive.org/details/tandy-portable-disk-drive-service-manual-26-3808  

TPDD2 operation manual https://archive.org/details/Portable_Disk_Drive_2_Operation_Manual_1986_Tandy  
TPDD2 sector access notes and windows executable http://club100.org/memfiles/index.php?&direction=0&order=&directory=Kurt%20McCullum/TPDD%20Client  
TPDD2 sector access http://bitchin100.com/wiki/index.php?title=TPDD-2_Sector_Access_Protocol  
Original SECTOR.BA, TPDD2 sector reader https://ftp.whtech.com/club100/drv/sector.ba  

TPDD1 and TPDD2 Normal file access http://bitchin100.com/wiki/index.php?title=Base_Protocol  
Many discussions and programs in the M100SIG archive https://archive.org/details/M100SIG  
Python TPDD client https://trs80stuff.net/tpdd/  
Python TPDD server http://club100.org/memfiles/index.php?&direction=0&order=&directory=Kurt%20McCullum/mComm%20Python  
