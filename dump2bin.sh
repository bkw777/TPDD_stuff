#!/bin/bash
# Read the "M" machine-readable format output from TPDD2_sector.bas
# and output a binary image
#
# TT  = track 0-39 or 0-79
# S   = sector 0-1
# OOO = offset 000-4F0
# HH  = 16 hex pairs
#
# TT  S OOO HH HH HH HH HH HH HH HH HH HH HH HH HH HH HH HH
#
# 3  1 170 20 46 37 3A 20 46 6F 72 6D 61 74 09 46 38 3A 20
# 3  1 180 4D 65 6E 75 0D 0A 0A 53 65 6C 65 63 74 20 46 31
# 3  1 190 20 2D 20 46 38 20 3F 00 4F 6B 00 44 72 69 76 65
# 3  1 1A0 20 6E 6F 74 20 52 65 61 64 79 00 43 6F 6D 6D 75
# 3  1 1B0 6E 69 63 61 74 69 6F 6E 20 45 72 72 6F 72 00 41
# 3  1 1C0 62 6F 72 74 00 46 69 6C 65 20 6E 6F 74 20 46 6F



while read T S O H ;do echo -e "\x${H// /\\x}\c" ;done
