#!/bin/bash
# Read the "M" format output from TPDD2_sector.bas and output a binary image.
# ./dump2bin.sh <file.dump >file.img
#
# TT  = track  0-79
# S   = sector 0-1
# OOO = offset 000-4F0
# HH  = 16 hex pairs
#
# TT S OOO HH HH HH HH HH HH HH HH HH HH HH HH HH HH HH HH
#
#  3 1 170 20 46 37 3A 20 46 6F 72 6D 61 74 09 46 38 3A 20

while read T S O H ;do echo -en "\x${H// /\\x}" ;done
