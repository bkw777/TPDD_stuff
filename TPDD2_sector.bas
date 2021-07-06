10 ' SECTR2.DO (SECTOR.BA 3.0) github.com/bkw777/TPDD2_stuff Cris Courson 19890304, Robert Benson 19890616, Brian K. White 20210701
20 ' Modified from: https://ftp.whtech.com/club100/drv/sector.ba
30 ' 
40 ' This file, TPDD2_sector.bas, is not intended to be loaded onto the portable, although it is valid and will run.
50 ' Instead, use "make" to generate the stripped & packed version, SECTR2.DO, for actual execution on the portable.
60 ' (or download from https://github.com/bkw777/TPDD2_sector/releases)
70 '
80 ' Reads the raw sector contents of a TPDD disk in a TPDD2 drive.
90 ' Requires a 26-3814 Tandy Portable Disk Drive 2 aka TPDD2.
100 ' Does not work on 26-3808 Tandy Portable Disk Drive aka TPDD1.
110 ' Only reads the logical sector, the data section of each sector, not the full physical disk sector.
120 ' Read-only. Reads both TPDD1 and TPDD2 disks.
130 '
140 ' BKW modifications:
150 '  Comments. Makefile. https://github.com/bkw777/BA_stuff. Continuous whole-disk mode (Z and L options).
160 '  F key toggles between 2 output formats, one better for human viewing, one better for machine processing of whole disk dump.
170 '    (track & sector included in output, display field removed)
180 '  Current settings & status displayed in menu and progress header.
190 '  Removed formfeed button.
200 '
210 '
220 ' Variables
230 ' P$(), P : output port; 0=LCD(default) 1=LPT 2=CRT 
240 ' A$,B$,C$,A,B,C,Y : general re-used tmp, usually related, example A$ is a string associated with int A, etc.
250 ' D   : number of bytes per TPDD sector fragment read request, and per line of dump output, 8 for LCD or width40 CRT, 16 for LPT or width80 CRT
260 ' T   : current track #
270 ' S   : current sector #
280 ' I   : current D-sized fragment number within current sector
290 ' H$  : allowable chars for hex input
300 ' I$  : list of all hot keys / menu keys
310 ' X   : Current operation mode/state, What to do on return from hot-key
320 '   0 = menu, wait for input
330 '   1 = track loaded, dump in progress, fetch next fragment
340 '   2 = track or sector has changed, load new track
350 '       X is different from original, I couldn't figure out it's original intent fully, and ended up breaking it
360 '       and re-solving the problem over the hard way. But it was roughly similar usage. This documents how it's used
370 '       in THIS version. I suspect X previously also did the job currently done by R.
380 ' TX$ : data to write to tpdd, not including the "ZZ"
390 ' RX$ : data read from tpdd
400 ' Q   : pointer to poked machine language
410 ' 
420 ' File Handles
430 ' 1   : COM: output to TPDD
440 ' 2   : COM: input from TPDD
450 ' 3   : LCD:/CRT:/LPT: output for dump
460 '
470 ' BKW added
480 ' L   : LPT page length, 0=no pagination 60=laser 66=matrix (6lpi)
490 ' W   : CRT width  40/80
510 ' J   : Jump / start address requested by the user. Used to override I
510 ' J$  : Jump / start address, hex string version for display
520 ' Z   : 0=dump one sector 1=dump whole drive
530 ' R   : 1=redraw the screen - returning from a hot-key that used the pop-up dialog
540 '
550 '
560 '_______________ SETUP _______________
570 '
580 '
590 CLS :CLEAR :SCREEN 0
600 '
610 '
620 '------ poke some unknown machine code
630 ' * 30 bytes of machine code including 4 bytes whose values are derived from HIMEM at run-time,
640 '   poked into an address range derived from HIMEM at run-time.
650 ' * 3 more bytes with values derived from HIMEM at run-time,
660 '   poked into fixed addresses above the cold-start himem,
670 '   so that is probably 1 to 3 pointers to the just-poked routine,
680 '   loaded into 1 to 3 rom hook addresses and/or uart control registers?.
690 ' * 256 more bytes of un-used space above HIMEM, probably serial I/O buffer?
710 '
710 ' move HIMEM down by 287 (256+30+1?)
720 ' poke 30 bytes into the space from (the new, lower) HIMEM+1 to HIMEM+30
730 MAXFILES=3 :CLEAR 1024,HIMEM-287 :A=HIMEM+1 :FOR B = A TO A+29 :READ C :IF C>4 GOTO 790 
740 ' 4 of the data bytes with values 1, 2, 3, & 4 are place-holders for values derived from HIMEM at run-time
750 D=(A+31)/256 AND 255 :IF C=1 THEN  D=A+31-(D*256) :GOTO 780 
760 IF C=2 GOTO 780 
770 D=(A+30)/256 AND 255 :IF C=3 THEN  D=A+30-(D*256)
780 C=D
790 POKE B,C :NEXT B
810 ' poke 3 more bytes into rom hook space? uart control registers?
810 A=A+1 :B=62974 :C=A/256 AND 255 :POKE B,C :POKE B-1,A-(C*256) :POKE B-2,195 :Q=A+30
820 ' 30 bytes of mystery machine code, except the 1,2,3,4 values are replaced with run-time values
830 DATA 201,229,213,197,245,33,1,2,175,87,58,3,4,95,25,219,200,119,33
840 DATA 3,4,52,241,193,209,225,227,225,251,201
850 '
860 '
870 '------ initialize variables and open the TPDD com port
880 T=0 :S=0 :P=0 :W=0 :D=8 :J=0 :J$="000" :L=0 :Z=0
890 H$="0123456789ABCDEF" :I$=CHR$(13)+" "+CHR$(27)+"PpOoWwLlDdTtSsZzFf"
900 DIM P$(2),Z$(1),V$(1) :P$(0)="LCD" :P$(1)="LPT" :P$(2)="CRT" :Z$(0)="(sect)" :Z$(1)="(disk)" :V$(0)="H" :V$(1)="M"
910 ON ERROR GOTO 2850 
920 OPEN "COM:98N1D" FOR OUTPUT AS 1 :OPEN "COM:98N1D" FOR INPUT AS 2
930 '
940 '
950 '_______________ MENU _______________
960 '
970 '
980 '------ display the main menu
990 CLS :X=0 '<-- [ENTER]
1000 R=0 '   "#######################################"
1010 PRINT@0,"         TPDD2 Sector Examiner         "
1020 PRINT   "[ENTER] This Menu           [ESC] EXIT "
1030 PRINT   "[SPACE] Continue/Resume                "
1040 PRINT   "[D] Dump           [Z] Sector/Disk     "
1050 PRINT   "[P] Output Port:                       "
1060 PRINT   "[T] Track  :                           "
1070 PRINT   "[S] Sector :                           "
1080 PRINT   "[O] Offset :       [F] Log Format:     ";
1090 '------ display current values in the menu
1100 GOSUB 2480 :PRINT@177,P$(P); :PRINT@293,J$; :PRINT@252,S; :PRINT@212,T;  :PRINT@129,Z$(Z); :PRINT@315,V$(V); 
1110 IF P=1 THEN  PRINT@259,"[L] LPT lines :"; :PRINT@274,L;
1120 IF P=2 THEN  PRINT@259,"[W] CRT width :"; :PRINT@274,W;
1130 '------ user input
1140 A$=INKEY$ :IF A$="" GOTO 1140 
1150 A=INSTR(I$,A$)
1160 '       ENTER,SPACE,ESC,  P,   p,   O,   o,   W,   w,   L,   l,   D,   d,   T,   t,   S,   s,   Z,   z,   F,   f
1170 ON A GOTO 990,1210,1310,1350,1350,1650,1650,1450,1450,1500,1500,1850,1850,1540,1540,1590,1590,1720,1720,1770,1770 :GOTO 1140 
1180 '
1190 '
1200 '------ return from hot-key
1210 IF X=2 THEN 1850 ' track or sector has changed, load new sector
1220 IF X=1 THEN  GOSUB 2540 :GOTO 1880 ' mid-sector, redraw progress screen, fetch next fragment '<-- [SPACE]
1230 IF R=1 THEN 1000 ELSE 1100 ' update or full menu redraw, wait for input
1240 '
1250 '
1260 '___________ HOT-KEY HANDLERS (most) ___________
1270 '
1280 '
1290 '------ EXIT
1300 ' restore a rom hook or uart control register back to normal, move HIMEM back where it was, release variable space, exit
1310 POKE 62972,201 :CLEAR 50,HIMEM+287 :MAXFILES=1 :MENU  '<-- [ESC]
1320 '
1330 '
1340 '------ select output port
1350 A$="Port  [0]=LCD 1=LPT 2=CRT :" :A=1 :GOSUB 2600 :P=VAL(A$) :IF P<0 OR P>2 THEN  P=0 '<-- [P]
1360 IF P=2 THEN  D=W/5 :SCREEN 1 :WIDTH W :CLS :SCREEN 0
1370 IF P=1 THEN  D=16 :A=0 :GOSUB 2340 :IF A>0 THEN  P=0 :D=8 :GOTO 2710 
1380 IF P=0 THEN  D=8 :CALL 16959
1390 OPEN P$(P)+":" FOR OUTPUT AS 3
1400 GOTO 1210 
1410 '
1420 '
1430 '------ set CRT width
1450 IF W=0 THEN 1210 
1450 A=1 :A$="CRT Width: [1]=40 2=80" :GOSUB 2600 :A=VAL(A$) :IF A<>2 THEN  A=1 '<-- [W]
1460 W=40*A :WIDTH W :D=8*A :GOTO 1210 
1470 '
1480 '
1490 '------ set LPT page length - 0 to disable pagination for continuous dump
1500 A$="LPT page length:" :A=3 :GOSUB 2600 :L=VAL(A$) :GOTO 1000 '<-- [L]
1510 '
1520 '
1530 '------ select track
1540 Y=T :A$="Track :" :A=2 :GOSUB 2600 :T=VAL(A$) :IF T<>Y THEN  S=0 :I=0 :IF X=1 THEN  X=2 '<-- [T]
1550 GOTO 1210 
1560 '
1570 '
1580 '------ toggle sector
1590 I=0 :IF S=0 THEN  S=1 ELSE  S=0 '<-- [S]
1600 IF X=1 THEN  X=2
1610 GOTO 1210 
1620 '
1630 '
1640 '------ select offset
1650 A=3 :A$="Jump to (000-4F0): " :GOSUB 2600 '<-- [O]
1660 B$=RIGHT$(A$,2) :A$="0"+LEFT$(A$,1) :GOSUB 2390 :B=A*256
1670 A$=B$ :GOSUB 2390 :A=A+B :IF A=0 THEN  J=0 ELSE  IF A>1279 THEN  J=0 ELSE  J=FIX(A/D)
1680 I=J :GOTO 1210 
1690 '
1700 '
1710 '------ toggle continuous dump mode
1720 IF Z=0 THEN  Z=1 ELSE  Z=0 '<-- [Z]
1730 GOTO 1210 
1740 '
1750 '
1760 '------ toggle dump format
1770 IF V=0 THEN  V=1 ELSE  V=0 '<-- [F]
1780 GOTO 1210 
1790 '
1800 '
1810 '________________ MAIN ________________
1820 '
1830 '
1840 '------ load track T sector S from disk into drive's cache
1850 GOSUB 2540 :TX$=CHR$(48)+CHR$(5)+CHR$(0)+CHR$(0)+CHR$(T)+CHR$(0)+CHR$(S)
1860 GOSUB 2120 :X=1 :IF A=0 THEN  I=0 ELSE 2710 
1870 '------ fetch D bytes (8 or 16) of the loaded sector from the drive's cache
1880 IF J>=0 THEN  I=J :J=-1
1890 IF I=0 THEN  A=0 ELSE  A=I*D/256 AND 255
1900 TX$=CHR$(50)+CHR$(4)+CHR$(0)+CHR$(A)+CHR$((I*D)-(A*256))+CHR$(D)
1910 GOSUB 2120 :IF A>0 GOTO 2710 
1920 '------ output the hex pairs
1930 GOSUB 2480 :IF V=1 THEN  PRINT#3,USING"## ";T;:PRINT#3,USING"# ";S;
1940 PRINT#3,J$+" ";:FOR C = 1 TO D :A=ASC(MID$(RX$,C,1)) :GOSUB 2430 :PRINT#3,A$+" "; :NEXT C :IF V=1 THEN 1980 
1950 '------ output the printable bytes
1960 PRINT#3,"  "; :FOR C = 1 TO D :A$=MID$(RX$,C,1) :IF A$<" " OR A$>"~" THEN  PRINT#3,"."; ELSE  PRINT#3,A$;
1970 NEXT C
1980 PRINT#3,"" :I=I+1 :IF I*D > 1279 THEN 2270 ELSE  A$=INKEY$ :IF A$<>"" GOTO 1150 
1990 '------ paginate the dump output
2000 '------ CRT 24 lines, LCD 7 lines, beep and pause
2010 IF (P=2 AND (I MOD 24 = 0)) OR (P=0 AND (I MOD 7 = 0)) THEN  SOUND 1280,1 :GOTO 1140 
2020 '------ LPT L lines, insert 4 CR's
2030 IF P=1 AND L>4 AND I MOD (L-4) = 0 THEN  PRINT#3,STRING$(4,CHR$(13))
2040 GOTO 1880 
2050 '
2060 '
2070 '______________ TPDD SEND/RECIEVE ______________
2080 '
2090 '
2100 '------ send
2110 'CLOSE 1 :OPEN "COM:98N1D" FOR OUTPUT AS 1
2120 POKE Q-1,0 :C=0 :PRINT#1,"ZZ";
2130 FOR A = 1 TO LEN(TX$) :B=ASC(MID$(TX$,A,1)) :C=C+B :PRINT#1,CHR$(B); :NEXT A
2140 PRINT#1,CHR$(NOT C AND 255);
2150 '------ receive
2160 FOR A = 1 TO 500 :IF PEEK(Q-1)=0 THEN  NEXT :A=3 :RETURN
2170 IF PEEK(Q)=56 AND PEEK(Q+2)=112 THEN  A=2 :RETURN
2180 IF PEEK(Q)=56 AND PEEK(Q+2)=0 THEN  A=0 :RETURN
2190 IF PEEK(Q)<>57 THEN  A=1 :RETURN
2200 RX$="" :FOR A = 5 TO 5+D :RX$=RX$+CHR$(PEEK(Q+A)) :NEXT A :A=0 :RETURN
2210 '
2220 '
2230 '______________ UTILS / HELPERS ______________
2240 '
2250 '
2260 '------ end of sector
2270 I=0
2280 IF Z=0 THEN  SOUND 1180,5 :SOUND 1280,5 :X=0 :R=1 :GOTO 1140 
2290 IF S=1 THEN  T=T+1
2300 X=2 :GOTO 1590 
2310 '
2320 '
2330 '------ get printer status
2340 C=INP(179) AND 6 :IF C=6 THEN  A=7 ELSE  IF C=4 THEN  A=8 ELSE  A=0
2350 RETURN
2360 '
2370 '
2380 '------ hex str A$ 00-FF to decimal int A 0-255
2390 A=INSTR(H$,LEFT$(A$,1)) :A=A*16-16 :A=A+INSTR(H$,RIGHT$(A$,1))-1 :RETURN
2400 '
2410 '
2420 '------ decimal int A 0-255 to hex str A$ 00-FF
2430 A$=MID$(H$,(A AND 15)+1,1) :IF A=0 THEN  A=1 ELSE  A=(A/16 AND 15)+1
2440 A$=MID$(H$,A,1)+A$ :RETURN
2450 '
2460 '
2470 '------ fill J$ with the 3-digit hex representation of I*D (current offset within sector)
2480 A=I*D/256 AND 255 :GOSUB 2430 :J$=RIGHT$(A$,1) :A=I*D/256 AND 255 :A=(I*D)-(A*256) :GOSUB 2430 :J$=J$+A$ :RETURN
2490 '
2500 '
2510 '------ open output
2520 'CLOSE 3 :OPEN P$(P)+":" FOR OUTPUT AS 3
2530 '------ progress / status header
2540 CALL 16959 :CLS :PRINT "Output:"+P$(P)+"  Track:"T" Sector:"S" "+Z$(Z) :RETURN
2550 '
2560 '
2570 '------ pop-up dialog
2580 ' does not clean up after itself, you must know on returning from hot-key handler
2590 ' whether a pop-up was used and you need to re-draw the screen. R=1 tells you that.
2600 R=1 :B=LEN(A$)+A+2 :C=140-(B/2) :PRINT@C,CHR$(240)+STRING$(B-2,CHR$(241))+CHR$(242);
2610 PRINT@C+40,CHR$(245)+A$+STRING$(A," ")+CHR$(245);
2620 PRINT@C+80,CHR$(246)+STRING$(B-2,CHR$(241))+CHR$(247);
2630 IF A=0 THEN 2670 ELSE  PRINT@C+41+LEN(A$),""; :A$="000" :B=0
2640 B$=INPUT$(1) :IF B$=CHR$(13) THEN 2660 
2650 A$=A$+B$ :B=B+1 :IF B=A THEN 2660 ELSE  PRINT B$; :GOTO 2640 
2660 A$=RIGHT$(A$,A) :RETURN
2670 A$=INKEY$ :IF A$="" THEN 2670 ELSE  RETURN
2680 '
2690 '
2700 '------ display error
2710 SOUND 1280,1 :SOUND 1180,1 :SOUND 1180,1 :SOUND 1280,1 :SOUND 1180,3
2720 ON A GOSUB 2750,2760,2770,,,,2810,2820,2830,2840 
2730 A=0 :GOSUB 2600 :GOTO 990 
2740 '  "#######################################" max length
2750 A$="Disk I/O error" :RETURN
2760 A$="Insert disk" :RETURN
2770 A$="Drive not responding" :RETURN
2780 '
2790 '
2800 '
2810 A$="Printer off/not connected" :RETURN
2820 A$="Printer not ready" :RETURN
2830 A$="CRT not available" :RETURN
2840 A$="Unexpected Error :"+STR$(B)+" in"+STR$(ERL) :RETURN
2850 IF ERL=84 OR ERL=96 THEN  A=9 :P=2 :RESUME 2710 
2860 A=10 :B=ERR :RESUME 2710 
