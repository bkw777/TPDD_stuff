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
160 '  V key toggles between 2 output formats, one better for viewing, one better for collecting whole disk dump via github.com/bkw777/LPT_Capture.
170 '  
180 '   (track & sector included in output, display field removed)
190 '  Current settings & status dislayed in menu and heading.
200 '  Remove formfeed button.
210 '
220 '
230 ' P$(), P : output port; 1=CRT 2=LCD 3=LPT
240 ' A$,B$,C$,A,B,C : general re-used tmp, usually related, example A$ is a string associated with int A, etc.
250 '
260 ' Variables
270 ' T    : current track #
280 ' S   : current sector #
290 ' H$  : allowable chars for hex input
300 ' I$  : list of all hot keys / menu keys
310 ' X   : current operation mode/state? 0=menu 1=track loaded, 2=???, 3=???
320 '
330 ' TX$ : data to write to tpdd, not including the "ZZ"
340 ' RX$ : data read from tpdd
350 ' I   : current byte number within current sector, number not contents
360 ' D   : number of bytes per TPDD sector fragment read request, and per line of dump output, 8 for LCD or width40 CRT, 16 for LPT or width80 CRT
370 ' 
380 ' File Handles
390 ' 1   : COM: output to TPDD
400 ' 2   : COM: input from TPDD
410 ' 3   : LCD:/CRT:/LPT: output for dump
420 '
430 ' BKW added
440 ' L   : LPT page length, 0=no pagination 60=laser 66=matrix (6lpi)
450 ' W   : CRT width  40/80
470 ' J   : Jump / start address requested by the user. Used to override I
470 ' J$  : Jump / start address, hex string version for display
480 ' Z   : 0=dump one sector 1=dump whole drive
490 ' R   : 1=redraw the screen - returning from a hot-key that used the pop-up dialog
500 '
510 '
520 CLS :CLEAR 255 :SCREEN 0
530 '
540 '
550 '------ poke some unknown machine code
560 MAXFILES=3 :CLEAR 1024,HIMEM-287 :A=HIMEM+1 :FOR B = A TO A+29 :READ C :IF C>4 GOTO 610 
570 D=(A+31)/256 AND 255 :IF C=1 THEN  D=A+31-(D*256) :GOTO 600 
580 IF C=2 GOTO 600 
590 D=(A+30)/256 AND 255 :IF C=3 THEN  D=A+30-(D*256)
600 C=D
610 POKE B,C :NEXT B
620 A=A+1 :B=62974 :C=A/256 AND 255 :POKE B,C :POKE B-1,A-(C*256) :POKE B-2,195 :Q=A+30
630 DATA 201,229,213,197,245,33,1,2,175,87,58,3,4,95,25,219,200,119,33
640 DATA 3,4,52,241,193,209,225,227,225,251,201
650 '
660 '
670 '------ initialize variables and open the TPDD com port
680 DIM P$(3) :H$="0123456789ABCDEF" :T=0 :S=0 :P=2 :W=40 :D=W/5 :J=0 :J$="000" :L=0 :Z=0
690 ON ERROR GOTO 2440 :I$=CHR$(13)+" "+CHR$(27)+"PpOoWwLlDdTtSsZzFf"
700 FOR A = 1 TO 3 :READ P$(A) :NEXT A
710 DATA "CRT","LCD","LPT"
720 Z$(0)="(sect)" :Z$(1)="(disk)" :V$(0)="H" :V$(1)="M"
730 OPEN "COM:98N1D" FOR OUTPUT AS 1 :OPEN "COM:98N1D" FOR INPUT AS 2
740 '
750 '
760 '------ display the main menu
770 CLS :X=0
780 R=0 '   "#######################################"
790 PRINT@0,"         TPDD2 Sector Examiner         "
800 PRINT   "[ENTER] This Menu           [ESC] EXIT "
810 PRINT   "[SPACE] Continue/Resume                "
820 PRINT   "[D] Dump           [Z] Sector/Disk     "
830 PRINT   "[P] Output Port:                       "
840 PRINT   "[T] Track  :       [F] Log Format:     "
850 PRINT   "[S] Sector :       [L] LPT lines :     "
860 PRINT   "[O] Offset :       [W] CRT width :     ";
870 '
880 '------ display current values in the menu
890 GOSUB 1670 :PRINT@177,P$(P); :PRINT@293,J$; :PRINT@252,S; :PRINT@274,L; :PRINT@212,T; :PRINT@314,W; :PRINT@129,Z$(Z); :PRINT@235,V$(V); 
900 '------ user input
910 A$=INKEY$ :IF A$="" GOTO 910 
920 A=INSTR(I$,A$)
930 '       ENTER,SPACE,ESC,  P,   p,   O,   o,   W,   w,   L,   l,   D,   d,   T,   t,   S,   s,   Z,   z,   F,   f
940 ON A GOTO 770,980,1030,1070,1070,2010,2010,1200,1200,1240,1240,1280,1280,1910,1910,1960,1960,2080,2080,2140,2140 :GOTO 910 
950 '
960 '
970 '------ return from hot-key
980 IF X>0 THEN  X=2 :GOSUB 1710 :GOTO 1310 
990 IF R=1 THEN 780 ELSE 890 
1000 '
1010 '
1020 '------ EXIT
1030 POKE 62972,201 :CLEAR 50,HIMEM+287 :MAXFILES=1 :MENU
1040 '
1050 '
1060 '------ select output port
1070 A$="Port  1="+P$(1)+" [2]="+P$(2)+" 3="+P$(3)+":" :A=1 :GOSUB 2190 :P=VAL(A$) :IF P<1 OR P>3 THEN  P=2
1080 IF P=3 THEN  D=16 :A=0 :GOSUB 1150 :IF A>0 THEN  D=W/5 :P=2 :GOTO 2300 
1090 IF P=2 THEN  CALL 16959
1100 IF P=1 THEN  WIDTH W :SCREEN 1 :CLS :SCREEN 0
1110 GOTO 980 
1120 '
1130 '
1140 '------ get printer status
1150 C=INP(179) AND 6 :IF C=6 THEN  A=7 ELSE  IF C=4 THEN  A=8 ELSE  A=0
1160 RETURN
1170 '
1180 '
1190 '------ set CRT width
1200 A=1 :A$="CRT Width: [1]=40 2=80" :GOSUB 2190 :A=VAL(A$) :IF A<>2 THEN  A=1 :W=40*A :WIDTH W :D=8*A :GOTO 780 
1210 '
1220 '
1230 '------ set LPT page length - 0 to disable pagination for continuous dump
1240 A$="LPT page length:" :A=3 :GOSUB 2190 :L=VAL(A$) :GOTO 780 
1250 '
1260 '
1270 '------ load track T sector S from disk into drive's cache
1280 GOSUB 1710 :TX$=CHR$(48)+CHR$(5)+CHR$(0)+CHR$(0)+CHR$(T)+CHR$(0)+CHR$(S)
1290 GOSUB 1780 :X=1 :IF A=0 THEN  I=0 ELSE 2300 
1300 '------ fetch D bytes (8 or 16) of the loaded sector from the drive's cache
1310 IF J>=0 THEN  I=J :J=-1
1320 IF I=0 THEN  A=0 ELSE  A=I*D/256 AND 255
1330 TX$=CHR$(50)+CHR$(4)+CHR$(0)+CHR$(A)+CHR$((I*D)-(A*256))+CHR$(D)
1340 GOSUB 1780 :IF A>0 GOTO 2300 
1350 '------ output the hex pairs
1360 GOSUB 1670 :IF V=1 THEN  PRINT#3,T""S;
1370 PRINT#3,J$+" ";:FOR C = 1 TO D :A=ASC(MID$(RX$,C,1)) :GOSUB 1620 :PRINT#3,A$+" "; :NEXT C :IF V=1 THEN 1410 
1380 '------ output the printable bytes
1390 PRINT#3,"  "; :FOR C = 1 TO D :A$=MID$(RX$,C,1) :IF A$>CHR$(31) THEN  PRINT #3,A$;ELSE  PRINT#3,".";
1400 NEXT C
1410 PRINT#3,"" :I=I+1 :IF I*D > 1279 THEN  GOTO 1510 ELSE  A$=INKEY$ :IF A$<>"" GOTO 920 
1420 '------ paginate the dump output
1430 '------ CRT 24 lines, LCD 7 lines, beep and pause
1440 IF (P=1 AND (I MOD 24 = 0)) OR (P=2 AND (I MOD 7 = 0)) THEN  SOUND 1280,1 :GOTO 910 
1450 '------ LPT L lines, insert 4 CR's
1460 IF P=3 AND L>4 AND I MOD (L-4) = 0 THEN  PRINT#3,STRING$(4,CHR$(13))
1470 GOTO 1310 
1480 '
1490 '
1500 '------ end of sector
1510 I=0
1520 IF Z=0 THEN  SOUND 1180,5 :SOUND 1280,5 :GOTO 910 
1530 IF S=1 THEN  T=T+1
1540 X=1 :GOTO 1960 
1550 '
1560 '
1570 '------ hex str A$ 00-FF to decimal int A 0-255
1580 A=INSTR(H$,LEFT$(A$,1)) :A=A*16-16 :A=A+INSTR(H$,RIGHT$(A$,1))-1 :RETURN
1590 '
1600 '
1610 '------ decimal int A 0-255 to hex str A$ 00-FF
1620 A$=MID$(H$,(A AND 15)+1,1) :IF A=0 THEN  A=1 ELSE  A=(A/16 AND 15)+1
1630 A$=MID$(H$,A,1)+A$ :RETURN
1640 '
1650 '
1660 '------ fill J$ with the 3-digit hex representation of I*D (current offset within sector)
1670 A=I*D/256 AND 255 :GOSUB 1620 :J$=RIGHT$(A$,1) :A=I*D/256 AND 255 :A=(I*D)-(A*256) :GOSUB 1620 :J$=J$+A$ :RETURN
1680 '
1690 '
1700 '------ open output
1710 CLOSE 3 :OPEN P$(P)+":" FOR OUTPUT AS 3
1720 '------ progress / status header
1730 CALL 16959 :CLS :PRINT "Output:"+P$(P)+" Track:"T" Sector:"S""+Z$(Z) :RETURN
1740 '
1750 '
1760 '------ TPDD SEND/RECEIVE
1770 '------ send
1780 CLOSE 1 :OPEN "COM:98N1D" FOR OUTPUT AS 1
1790 POKE Q-1,0 :C=0 :PRINT#1,"ZZ";
1800 FOR A = 1 TO LEN(TX$) :B=ASC(MID$(TX$,A,1)) :C=C+B :PRINT#1,CHR$(B); :NEXT A
1810 PRINT#1,CHR$(NOT C AND 255);
1820 '------ receive
1830 FOR A = 1 TO 500 :IF PEEK(Q-1)=0 THEN  NEXT :A=3 :RETURN
1840 IF PEEK(Q)=56 AND PEEK(Q+2)=112 THEN  A=2 :RETURN
1850 IF PEEK(Q)=56 AND PEEK(Q+2)=0 THEN  A=0 :RETURN
1860 IF PEEK(Q)<>57 THEN  A=1 :RETURN
1870 RX$="" :FOR A = 5 TO 5+D :RX$=RX$+CHR$(PEEK(Q+A)) :NEXT A :A=0 :RETURN
1880 '
1890 '
1900 '------ select track
1910 Y=T :A$="Track :" :A=2 :GOSUB 2190 :T=VAL(A$) :IF T<>Y THEN  S=0 :I=0
1920 GOTO 980 
1930 '
1940 '
1950 '------ toggle sector
1960 I=0 :IF S=0 THEN  S=1 ELSE  S=0
1970 GOTO 980 
1980 '
1990 '
2000 '------ select offset
2010 A=3 :A$="Jump to (000-4F0): " :GOSUB 2190 
2020 B$=RIGHT$(A$,2) :A$="0"+LEFT$(A$,1) :GOSUB 1580 :B=A*256
2030 A$=B$ :GOSUB 1580 :A=A+B :IF A=0 THEN  J=0 ELSE  IF A>1279 THEN  J=0 ELSE  J=FIX(A/D)
2040 I=J :GOTO 980 
2050 '
2060 '
2070 '------ toggle continuous dump mode
2080 IF Z=0 THEN  Z=1 ELSE  Z=0
2090 'GOSUB 1730 :IF X=1 THEN 1310 ELSE 890 
2100 GOTO 980 
2110 '
2120 '
2130 '------ toggle dump format
2140 IF V=0 THEN  V=1 ELSE  V=0
2150 GOTO 980 
2160 '
2170 '
2180 '------ pop-up dialog
2190 R=1 :B=LEN(A$)+A+2 :C=140-(B/2) :PRINT@C,CHR$(240)+STRING$(B-2,CHR$(241))+CHR$(242);
2200 PRINT@C+40,CHR$(245)+A$+STRING$(A," ")+CHR$(245);
2210 PRINT@C+80,CHR$(246)+STRING$(B-2,CHR$(241))+CHR$(247);
2220 IF A=0 THEN 2260 ELSE  PRINT@C+41+LEN(A$),""; :A$="000" :B=0
2230 B$=INPUT$(1) :IF B$=CHR$(13) THEN 2250 
2240 A$=A$+B$ :B=B+1 :IF B=A THEN 2250 ELSE  PRINT B$; :GOTO 2230 
2250 A$=RIGHT$(A$,A) :RETURN
2260 A$=INKEY$ :IF A$="" THEN 2260 ELSE  RETURN
2270 '
2280 '
2290 '------ display error
2300 SOUND 1280,1 :SOUND 1180,1 :SOUND 1180,1 :SOUND 1280,1 :SOUND 1180,3
2310 ON A GOSUB 2340,2350,2360,,,,2400,2410,2420,2430 
2320 A=0 :GOSUB 2190 :GOTO 770 
2330 '  "#######################################" max length
2340 A$="Disk I/O error" :RETURN
2350 A$="Insert disk" :RETURN
2360 A$="Drive not responding" :RETURN
2370 '
2380 '
2390 '
2400 A$="Printer off/not connected" :RETURN
2410 A$="Printer not ready" :RETURN
2420 A$="CRT not available" :RETURN
2430 A$="Unexpected Error :"+STR$(B)+" in"+STR$(ERL) :RETURN
2440 IF ERL=84 OR ERL=96 THEN  A=9 :P=2 :RESUME 2300 
2450 A=10 :B=ERR :RESUME 2300 
