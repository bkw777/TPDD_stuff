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
230 ' P$(), P : output port; 1=CRT 2=LCD 3=LPT
240 ' A$,B$,C$,A,B,C : general re-used tmp, usually related, example A$ is a string associated with int A, etc.
250 ' T    : current track #
260 ' S   : current sector #
270 ' H$  : allowable chars for hex input
280 ' I$  : list of all hot keys / menu keys
290 ' X   : Current operation mode/state, What to do on return from hot-key
300 '   0 = menu, wait for input
310 '   1 = track loaded, dump in progress, fetch next fragment
320 '   2 = track or sector has changed, load new track
330 '       X is different from original, I couldn't figure out it's original intent fully, and ended up breaking it
340 '       and re-solving the problem over the hard way. But it was roughly similar usage. This documents how it's used
350 '       in THIS version. I suspect X previously also did the job currently done by R.
360 ' TX$ : data to write to tpdd, not including the "ZZ"
370 ' RX$ : data read from tpdd
380 ' I   : current byte number within current sector, number not contents
390 ' D   : number of bytes per TPDD sector fragment read request, and per line of dump output, 8 for LCD or width40 CRT, 16 for LPT or width80 CRT
400 ' 
410 ' File Handles
420 ' 1   : COM: output to TPDD
430 ' 2   : COM: input from TPDD
440 ' 3   : LCD:/CRT:/LPT: output for dump
450 '
460 ' BKW added
470 ' L   : LPT page length, 0=no pagination 60=laser 66=matrix (6lpi)
480 ' W   : CRT width  40/80
500 ' J   : Jump / start address requested by the user. Used to override I
500 ' J$  : Jump / start address, hex string version for display
510 ' Z   : 0=dump one sector 1=dump whole drive
520 ' R   : 1=redraw the screen - returning from a hot-key that used the pop-up dialog
530 '
540 '
550 '_______________ SETUP _______________
560 '
570 '
580 CLS :CLEAR 255 :SCREEN 0
590 '
600 '
610 '------ poke some unknown machine code
620 MAXFILES=3 :CLEAR 1024,HIMEM-287 :A=HIMEM+1 :FOR B = A TO A+29 :READ C :IF C>4 GOTO 670 
630 D=(A+31)/256 AND 255 :IF C=1 THEN  D=A+31-(D*256) :GOTO 660 
640 IF C=2 GOTO 660 
650 D=(A+30)/256 AND 255 :IF C=3 THEN  D=A+30-(D*256)
660 C=D
670 POKE B,C :NEXT B
680 A=A+1 :B=62974 :C=A/256 AND 255 :POKE B,C :POKE B-1,A-(C*256) :POKE B-2,195 :Q=A+30
690 DATA 201,229,213,197,245,33,1,2,175,87,58,3,4,95,25,219,200,119,33
700 DATA 3,4,52,241,193,209,225,227,225,251,201
710 '
720 '
730 '------ initialize variables and open the TPDD com port
740 DIM P$(3) :H$="0123456789ABCDEF" :T=0 :S=0 :P=2 :W=40 :D=W/5 :J=0 :J$="000" :L=0 :Z=0
750 ON ERROR GOTO 2650 :I$=CHR$(13)+" "+CHR$(27)+"PpOoWwLlDdTtSsZzFf"
760 FOR A = 1 TO 3 :READ P$(A) :NEXT A
770 DATA "CRT","LCD","LPT"
780 Z$(0)="(sect)" :Z$(1)="(disk)" :V$(0)="H" :V$(1)="M"
790 OPEN "COM:98N1D" FOR OUTPUT AS 1 :OPEN "COM:98N1D" FOR INPUT AS 2
800 '
810 '
820 '_______________ MENU _______________
830 '
840 '
850 '------ display the main menu
860 CLS :X=0 '<-- [ENTER]
870 R=0 '   "#######################################"
880 PRINT@0,"         TPDD2 Sector Examiner         "
890 PRINT   "[ENTER] This Menu           [ESC] EXIT "
900 PRINT   "[SPACE] Continue/Resume                "
910 PRINT   "[D] Dump           [Z] Sector/Disk     "
920 PRINT   "[P] Output Port:                       "
930 PRINT   "[T] Track  :       [F] Log Format:     "
940 PRINT   "[S] Sector :       [L] LPT lines :     "
950 PRINT   "[O] Offset :       [W] CRT width :     ";
960 '------ display current values in the menu
970 GOSUB 2280 :PRINT@177,P$(P); :PRINT@293,J$; :PRINT@252,S; :PRINT@274,L; :PRINT@212,T; :PRINT@314,W; :PRINT@129,Z$(Z); :PRINT@235,V$(V); 
980 '------ user input
990 A$=INKEY$ :IF A$="" GOTO 990 
1000 A=INSTR(I$,A$)
1010 '       ENTER,SPACE,ESC,  P,   p,   O,   o,   W,   w,   L,   l,   D,   d,   T,   t,   S,   s,   Z,   z,   F,   f
1020 ON A GOTO 860,1060,1150,1190,1190,1450,1450,1270,1270,1310,1310,1650,1650,1350,1350,1400,1400,1520,1520,1570,1570 :GOTO 990 
1030 '
1040 '
1050 '------ return from hot-key
1060 IF X=2 THEN 1650 ' track or sector has changed, load new sector
1070 IF X=1 THEN  GOSUB 2320 :GOTO 1680 ' mid-sector, redraw progress screen, fetch next fragment '<-- [SPACE]
1080 IF R=1 THEN 870 ELSE 970 ' update or full menu redraw, wait for input
1090 '
1100 '
1110 '___________ HOT-KEY HANDLERS (most) ___________
1120 '
1130 '
1140 '------ EXIT
1150 POKE 62972,201 :CLEAR 50,HIMEM+287 :MAXFILES=1 :MENU  '<-- [ESC]
1160 '
1170 '
1180 '------ select output port
1190 A$="Port  1="+P$(1)+" [2]="+P$(2)+" 3="+P$(3)+":" :A=1 :GOSUB 2400 :P=VAL(A$) :IF P<1 OR P>3 THEN  P=2 '<-- [P]
1200 IF P=3 THEN  D=16 :A=0 :GOSUB 2140 :IF A>0 THEN  D=W/5 :P=2 :GOTO 2510 
1210 IF P=2 THEN  CALL 16959
1220 IF P=1 THEN  WIDTH W :SCREEN 1 :CLS :SCREEN 0
1230 GOTO 1060 
1240 '
1250 '
1260 '------ set CRT width
1270 A=1 :A$="CRT Width: [1]=40 2=80" :GOSUB 2400 :A=VAL(A$) :IF A<>2 THEN  A=1 :W=40*A :WIDTH W :D=8*A :GOTO 870 '<-- [W]
1280 '
1290 '
1300 '------ set LPT page length - 0 to disable pagination for continuous dump
1310 A$="LPT page length:" :A=3 :GOSUB 2400 :L=VAL(A$) :GOTO 870 '<-- [L]
1320 '
1330 '
1340 '------ select track
1350 Y=T :A$="Track :" :A=2 :GOSUB 2400 :T=VAL(A$) :IF T<>Y THEN  S=0 :I=0 :X=2 '<-- [T]
1360 GOTO 1060 
1370 '
1380 '
1390 '------ toggle sector
1400 I=0 :IF S=0 THEN  S=1 ELSE  S=0 '<-- [S]
1410 X=2 :GOTO 1060 
1420 '
1430 '
1440 '------ select offset
1450 A=3 :A$="Jump to (000-4F0): " :GOSUB 2400 '<-- [O]
1460 B$=RIGHT$(A$,2) :A$="0"+LEFT$(A$,1) :GOSUB 2190 :B=A*256
1470 A$=B$ :GOSUB 2190 :A=A+B :IF A=0 THEN  J=0 ELSE  IF A>1279 THEN  J=0 ELSE  J=FIX(A/D)
1480 I=J :GOTO 1060 
1490 '
1500 '
1510 '------ toggle continuous dump mode
1520 IF Z=0 THEN  Z=1 ELSE  Z=0 '<-- [Z]
1530 GOTO 1060 
1540 '
1550 '
1560 '------ toggle dump format
1570 IF V=0 THEN  V=1 ELSE  V=0 '<-- [F]
1580 GOTO 1060 
1590 '
1600 '
1610 '________________ MAIN ________________
1620 '
1630 '
1640 '------ load track T sector S from disk into drive's cache
1650 GOSUB 2320 :TX$=CHR$(48)+CHR$(5)+CHR$(0)+CHR$(0)+CHR$(T)+CHR$(0)+CHR$(S)
1660 GOSUB 1910 :X=1 :IF A=0 THEN  I=0 ELSE 2510 
1670 '------ fetch D bytes (8 or 16) of the loaded sector from the drive's cache
1680 IF J>=0 THEN  I=J :J=-1
1690 IF I=0 THEN  A=0 ELSE  A=I*D/256 AND 255
1700 TX$=CHR$(50)+CHR$(4)+CHR$(0)+CHR$(A)+CHR$((I*D)-(A*256))+CHR$(D)
1710 GOSUB 1910 :IF A>0 GOTO 2510 
1720 '------ output the hex pairs
1730 GOSUB 2280 :IF V=1 THEN  PRINT#3,T""S;
1740 PRINT#3,J$+" ";:FOR C = 1 TO D :A=ASC(MID$(RX$,C,1)) :GOSUB 2230 :PRINT#3,A$+" "; :NEXT C :IF V=1 THEN 1780 
1750 '------ output the printable bytes
1760 PRINT#3,"  "; :FOR C = 1 TO D :A$=MID$(RX$,C,1) :IF A$>CHR$(31) THEN  PRINT #3,A$;ELSE  PRINT#3,".";
1770 NEXT C
1780 PRINT#3,"" :I=I+1 :IF I*D > 1279 THEN  GOTO 2070 ELSE  A$=INKEY$ :IF A$<>"" GOTO 1000 
1790 '------ paginate the dump output
1800 '------ CRT 24 lines, LCD 7 lines, beep and pause
1810 IF (P=1 AND (I MOD 24 = 0)) OR (P=2 AND (I MOD 7 = 0)) THEN  SOUND 1280,1 :GOTO 990 
1820 '------ LPT L lines, insert 4 CR's
1830 IF P=3 AND L>4 AND I MOD (L-4) = 0 THEN  PRINT#3,STRING$(4,CHR$(13))
1840 GOTO 1680 
1850 '
1860 '
1870 '______________ TPDD SEND/RECIEVE ______________
1880 '
1890 '
1900 '------ send
1910 CLOSE 1 :OPEN "COM:98N1D" FOR OUTPUT AS 1
1920 POKE Q-1,0 :C=0 :PRINT#1,"ZZ";
1930 FOR A = 1 TO LEN(TX$) :B=ASC(MID$(TX$,A,1)) :C=C+B :PRINT#1,CHR$(B); :NEXT A
1940 PRINT#1,CHR$(NOT C AND 255);
1950 '------ receive
1960 FOR A = 1 TO 500 :IF PEEK(Q-1)=0 THEN  NEXT :A=3 :RETURN
1970 IF PEEK(Q)=56 AND PEEK(Q+2)=112 THEN  A=2 :RETURN
1980 IF PEEK(Q)=56 AND PEEK(Q+2)=0 THEN  A=0 :RETURN
1990 IF PEEK(Q)<>57 THEN  A=1 :RETURN
2000 RX$="" :FOR A = 5 TO 5+D :RX$=RX$+CHR$(PEEK(Q+A)) :NEXT A :A=0 :RETURN
2010 '
2020 '
2030 '______________ UTILS / HELPERS ______________
2040 '
2050 '
2060 '------ end of sector
2070 X=2 :I=0
2080 IF Z=0 THEN  SOUND 1180,5 :SOUND 1280,5 :GOTO 990 
2090 IF S=1 THEN  T=T+1
2100 GOTO 1400 
2110 '
2120 '
2130 '------ get printer status
2140 C=INP(179) AND 6 :IF C=6 THEN  A=7 ELSE  IF C=4 THEN  A=8 ELSE  A=0
2150 RETURN
2160 '
2170 '
2180 '------ hex str A$ 00-FF to decimal int A 0-255
2190 A=INSTR(H$,LEFT$(A$,1)) :A=A*16-16 :A=A+INSTR(H$,RIGHT$(A$,1))-1 :RETURN
2200 '
2210 '
2220 '------ decimal int A 0-255 to hex str A$ 00-FF
2230 A$=MID$(H$,(A AND 15)+1,1) :IF A=0 THEN  A=1 ELSE  A=(A/16 AND 15)+1
2240 A$=MID$(H$,A,1)+A$ :RETURN
2250 '
2260 '
2270 '------ fill J$ with the 3-digit hex representation of I*D (current offset within sector)
2280 A=I*D/256 AND 255 :GOSUB 2230 :J$=RIGHT$(A$,1) :A=I*D/256 AND 255 :A=(I*D)-(A*256) :GOSUB 2230 :J$=J$+A$ :RETURN
2290 '
2300 '
2310 '------ open output
2320 CLOSE 3 :OPEN P$(P)+":" FOR OUTPUT AS 3
2330 '------ progress / status header
2340 CALL 16959 :CLS :PRINT "Output:"+P$(P)+" Track:"T" Sector:"S""+Z$(Z) :RETURN
2350 '
2360 '
2370 '------ pop-up dialog
2380 ' does not clean up after itself, you must know on returning from hot-key handler
2390 ' whether a pop-up was used and you need to re-draw the screen. R=1 tells you that.
2400 R=1 :B=LEN(A$)+A+2 :C=140-(B/2) :PRINT@C,CHR$(240)+STRING$(B-2,CHR$(241))+CHR$(242);
2410 PRINT@C+40,CHR$(245)+A$+STRING$(A," ")+CHR$(245);
2420 PRINT@C+80,CHR$(246)+STRING$(B-2,CHR$(241))+CHR$(247);
2430 IF A=0 THEN 2470 ELSE  PRINT@C+41+LEN(A$),""; :A$="000" :B=0
2440 B$=INPUT$(1) :IF B$=CHR$(13) THEN 2460 
2450 A$=A$+B$ :B=B+1 :IF B=A THEN 2460 ELSE  PRINT B$; :GOTO 2440 
2460 A$=RIGHT$(A$,A) :RETURN
2470 A$=INKEY$ :IF A$="" THEN 2470 ELSE  RETURN
2480 '
2490 '
2500 '------ display error
2510 SOUND 1280,1 :SOUND 1180,1 :SOUND 1180,1 :SOUND 1280,1 :SOUND 1180,3
2520 ON A GOSUB 2550,2560,2570,,,,2610,2620,2630,2640 
2530 A=0 :GOSUB 2400 :GOTO 860 
2540 '  "#######################################" max length
2550 A$="Disk I/O error" :RETURN
2560 A$="Insert disk" :RETURN
2570 A$="Drive not responding" :RETURN
2580 '
2590 '
2600 '
2610 A$="Printer off/not connected" :RETURN
2620 A$="Printer not ready" :RETURN
2630 A$="CRT not available" :RETURN
2640 A$="Unexpected Error :"+STR$(B)+" in"+STR$(ERL) :RETURN
2650 IF ERL=84 OR ERL=96 THEN  A=9 :P=2 :RESUME 2510 
2660 A=10 :B=ERR :RESUME 2510 
