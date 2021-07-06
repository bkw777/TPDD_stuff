10 ' SECTR2.DO 1.4 C.Courson 1989, R.Benson 1989, B.White 2021
20 ' TPDD_sector.bas github.com/bkw777/TPDD2_stuff
30 ' Modified from: https://ftp.whtech.com/club100/drv/sector.ba
40 ' 
50 ' This file, TPDD2_sector.bas, is not intended to be loaded onto the portable, although it is valid and will run.
60 ' Instead, use "make" to generate the stripped & packed version, SECTR2.DO, for actual execution on the portable.
70 ' (or download from https://github.com/bkw777/TPDD2_sector/releases)
80 '
90 ' Reads the raw sector contents of a TPDD disk in a TPDD2 drive.
100 ' Requires a 26-3814 Tandy Portable Disk Drive 2 aka TPDD2.
110 ' Does not work on 26-3808 Tandy Portable Disk Drive aka TPDD1.
120 ' Only reads the logical sector, the data section of each sector, not the full physical disk sector.
130 ' Read-only. Reads both TPDD1 and TPDD2 disks.
140 '
150 ' BKW modifications:
160 '  Comments. Makefile. https://github.com/bkw777/BA_stuff. Continuous whole-disk mode (Z and L options).
170 '  F key toggles between 2 output formats, one better for human viewing, one better for machine processing of whole disk dump.
180 '    (track & sector included in output, display field removed)
190 '  Current settings & status displayed in menu and progress header.
200 '  Removed formfeed button.
210 '
220 '
230 ' Variables
240 ' P$(), P : output port; 0=LCD(default) 1=LPT 2=CRT 
250 ' A$,B$,C$,A,B,C,Y : general re-used tmp, usually related, example A$ is a string associated with int A, etc.
260 ' D   : number of bytes per TPDD sector fragment read request, and per line of dump output, 8 for LCD or width40 CRT, 16 for LPT or width80 CRT
270 ' T   : current track #
280 ' S   : current sector #
290 ' I   : current D-sized fragment number within current sector
300 ' H$  : allowable chars for hex input
310 ' I$  : list of all hot keys / menu keys
320 ' X   : Current operation mode/state, What to do on return from hot-key
330 '   0 = menu, wait for input
340 '   1 = track loaded, dump in progress, fetch next fragment
350 '   2 = track or sector has changed, load new track
360 '       X is different from original, I couldn't figure out it's original intent fully, and ended up breaking it
370 '       and re-solving the problem over the hard way. But it was roughly similar usage. This documents how it's used
380 '       in THIS version. I suspect X previously also did the job currently done by R.
390 ' TX$ : data to write to tpdd, not including the "ZZ"
400 ' RX$ : data read from tpdd
410 ' Q   : pointer to poked machine language
420 ' 
430 ' File Handles
440 ' 1   : COM: output to TPDD
450 ' 2   : COM: input from TPDD
460 ' 3   : LCD:/CRT:/LPT: output for dump
470 '
480 ' BKW added
490 ' L   : LPT page length, 0=no pagination 60=laser 66=matrix (6lpi)
500 ' W   : CRT width  40/80
520 ' J   : Jump / start address requested by the user. Used to override I
520 ' J$  : Jump / start address, hex string version for display
530 ' Z   : 0=dump one sector 1=dump whole drive
540 ' R   : 1=redraw the screen - returning from a hot-key that used the pop-up dialog
550 '
560 '
570 '_______________ SETUP _______________
580 '
590 '
600 CLS :CLEAR :SCREEN 0
610 '
620 '
630 '------ poke some unknown machine code
640 ' * 30 bytes of machine code including 4 bytes whose values are derived from HIMEM at run-time,
650 '   poked into an address range derived from HIMEM at run-time.
660 ' * 3 more bytes with values derived from HIMEM at run-time,
670 '   poked into fixed addresses above the cold-start himem,
680 '   so that is probably 1 to 3 pointers to the just-poked routine,
690 '   loaded into 1 to 3 rom hook addresses and/or uart control registers?.
700 ' * 256 more bytes of un-used space above HIMEM, probably serial I/O buffer?
720 '
720 ' move HIMEM down by 287 (256+30+1?)
730 ' poke 30 bytes into the space from (the new, lower) HIMEM+1 to HIMEM+30
740 MAXFILES=3 :CLEAR 1024,HIMEM-287 :A=HIMEM+1 :FOR B = A TO A+29 :READ C :IF C>4 GOTO 800 
750 ' 4 of the data bytes with values 1, 2, 3, & 4 are place-holders for values derived from HIMEM at run-time
760 D=(A+31)/256 AND 255 :IF C=1 THEN  D=A+31-(D*256) :GOTO 790 
770 IF C=2 GOTO 790 
780 D=(A+30)/256 AND 255 :IF C=3 THEN  D=A+30-(D*256)
790 C=D
800 POKE B,C :NEXT B
820 ' poke 3 more bytes into rom hook space? uart control registers?
820 A=A+1 :B=62974 :C=A/256 AND 255 :POKE B,C :POKE B-1,A-(C*256) :POKE B-2,195 :Q=A+30
830 ' 30 bytes of mystery machine code, except the 1,2,3,4 values are replaced with run-time values
840 DATA 201,229,213,197,245,33,1,2,175,87,58,3,4,95,25,219,200,119,33
850 DATA 3,4,52,241,193,209,225,227,225,251,201
860 '
870 '
880 '------ initialize variables and open the TPDD com port
890 T=0 :S=0 :P=0 :W=0 :D=8 :J=0 :J$="000" :L=0 :Z=0
900 H$="0123456789ABCDEF" :I$=CHR$(13)+" "+CHR$(27)+"PpOoWwLlDdTtSsZzFf"
910 DIM P$(2),Z$(1),V$(1) :P$(0)="LCD" :P$(1)="LPT" :P$(2)="CRT" :Z$(0)="(sect)" :Z$(1)="(disk)" :V$(0)="H" :V$(1)="M"
920 ON ERROR GOTO 2860 
930 OPEN "COM:98N1D" FOR OUTPUT AS 1 :OPEN "COM:98N1D" FOR INPUT AS 2
940 '
950 '
960 '_______________ MENU _______________
970 '
980 '
990 '------ display the main menu
1000 CLS :X=0 '<-- [ENTER]
1010 R=0 '   "#######################################"
1020 PRINT@0,"         TPDD2 Sector Examiner         "
1030 PRINT   "[ENTER] This Menu           [ESC] EXIT "
1040 PRINT   "[SPACE] Continue/Resume                "
1050 PRINT   "[D] Dump           [Z] Sector/Disk     "
1060 PRINT   "[P] Output Port:                       "
1070 PRINT   "[T] Track  :                           "
1080 PRINT   "[S] Sector :                           "
1090 PRINT   "[O] Offset :       [F] Log Format:     ";
1100 '------ display current values in the menu
1110 GOSUB 2490 :PRINT@177,P$(P); :PRINT@293,J$; :PRINT@252,S; :PRINT@212,T;  :PRINT@129,Z$(Z); :PRINT@315,V$(V); 
1120 IF P=1 THEN  PRINT@259,"[L] LPT lines :"; :PRINT@274,L;
1130 IF P=2 THEN  PRINT@259,"[W] CRT width :"; :PRINT@274,W;
1140 '------ user input
1150 A$=INKEY$ :IF A$="" GOTO 1150 
1160 A=INSTR(I$,A$)
1170 '       ENTER,SPACE,ESC,  P,   p,   O,   o,   W,   w,   L,   l,   D,   d,   T,   t,   S,   s,   Z,   z,   F,   f
1180 ON A GOTO 1000,1220,1320,1360,1360,1660,1660,1460,1460,1510,1510,1860,1860,1550,1550,1600,1600,1730,1730,1780,1780 :GOTO 1150 
1190 '
1200 '
1210 '------ return from hot-key
1220 IF X=2 THEN 1860 ' track or sector has changed, load new sector
1230 IF X=1 THEN  GOSUB 2550 :GOTO 1890 ' mid-sector, redraw progress screen, fetch next fragment '<-- [SPACE]
1240 IF R=1 THEN 1010 ELSE 1110 ' update or full menu redraw, wait for input
1250 '
1260 '
1270 '___________ HOT-KEY HANDLERS (most) ___________
1280 '
1290 '
1300 '------ EXIT
1310 ' restore a rom hook or uart control register back to normal, move HIMEM back where it was, release variable space, exit
1320 POKE 62972,201 :CLEAR 50,HIMEM+287 :MAXFILES=1 :MENU  '<-- [ESC]
1330 '
1340 '
1350 '------ select output port
1360 A$="Port  [0]=LCD 1=LPT 2=CRT :" :A=1 :GOSUB 2610 :P=VAL(A$) :IF P<0 OR P>2 THEN  P=0 '<-- [P]
1370 IF P=2 THEN  D=W/5 :SCREEN 1 :WIDTH W :CLS :SCREEN 0
1380 IF P=1 THEN  D=16 :A=0 :GOSUB 2350 :IF A>0 THEN  P=0 :D=8 :GOTO 2720 
1390 IF P=0 THEN  D=8 :CALL 16959
1400 OPEN P$(P)+":" FOR OUTPUT AS 3
1410 GOTO 1220 
1420 '
1430 '
1440 '------ set CRT width
1460 IF W=0 THEN 1220 
1460 A=1 :A$="CRT Width: [1]=40 2=80" :GOSUB 2610 :A=VAL(A$) :IF A<>2 THEN  A=1 '<-- [W]
1470 W=40*A :WIDTH W :D=8*A :GOTO 1220 
1480 '
1490 '
1500 '------ set LPT page length - 0 to disable pagination for continuous dump
1510 A$="LPT page length:" :A=3 :GOSUB 2610 :L=VAL(A$) :GOTO 1010 '<-- [L]
1520 '
1530 '
1540 '------ select track
1550 Y=T :A$="Track :" :A=2 :GOSUB 2610 :T=VAL(A$) :IF T<>Y THEN  S=0 :I=0 :IF X=1 THEN  X=2 '<-- [T]
1560 GOTO 1220 
1570 '
1580 '
1590 '------ toggle sector
1600 I=0 :IF S=0 THEN  S=1 ELSE  S=0 '<-- [S]
1610 IF X=1 THEN  X=2
1620 GOTO 1220 
1630 '
1640 '
1650 '------ select offset
1660 A=3 :A$="Jump to (000-4F0): " :GOSUB 2610 '<-- [O]
1670 B$=RIGHT$(A$,2) :A$="0"+LEFT$(A$,1) :GOSUB 2400 :B=A*256
1680 A$=B$ :GOSUB 2400 :A=A+B :IF A=0 THEN  J=0 ELSE  IF A>1279 THEN  J=0 ELSE  J=FIX(A/D)
1690 I=J :GOTO 1220 
1700 '
1710 '
1720 '------ toggle continuous dump mode
1730 IF Z=0 THEN  Z=1 ELSE  Z=0 '<-- [Z]
1740 GOTO 1220 
1750 '
1760 '
1770 '------ toggle dump format
1780 IF V=0 THEN  V=1 ELSE  V=0 '<-- [F]
1790 GOTO 1220 
1800 '
1810 '
1820 '________________ MAIN ________________
1830 '
1840 '
1850 '------ load track T sector S from disk into drive's cache
1860 GOSUB 2550 :TX$=CHR$(48)+CHR$(5)+CHR$(0)+CHR$(0)+CHR$(T)+CHR$(0)+CHR$(S)
1870 GOSUB 2130 :X=1 :IF A=0 THEN  I=0 ELSE 2720 
1880 '------ fetch D bytes (8 or 16) of the loaded sector from the drive's cache
1890 IF J>=0 THEN  I=J :J=-1
1900 IF I=0 THEN  A=0 ELSE  A=I*D/256 AND 255
1910 TX$=CHR$(50)+CHR$(4)+CHR$(0)+CHR$(A)+CHR$((I*D)-(A*256))+CHR$(D)
1920 GOSUB 2130 :IF A>0 GOTO 2720 
1930 '------ output the hex pairs
1940 GOSUB 2490 :IF V=1 THEN  PRINT#3,USING"## ";T;:PRINT#3,USING"# ";S;
1950 PRINT#3,J$+" ";:FOR C = 1 TO D :A=ASC(MID$(RX$,C,1)) :GOSUB 2440 :PRINT#3,A$+" "; :NEXT C :IF V=1 THEN 1990 
1960 '------ output the printable bytes
1970 PRINT#3,"  "; :FOR C = 1 TO D :A$=MID$(RX$,C,1) :IF A$<" " OR A$>"~" THEN  PRINT#3,"."; ELSE  PRINT#3,A$;
1980 NEXT C
1990 PRINT#3,"" :I=I+1 :IF I*D > 1279 THEN 2280 ELSE  A$=INKEY$ :IF A$<>"" GOTO 1160 
2000 '------ paginate the dump output
2010 '------ CRT 24 lines, LCD 7 lines, beep and pause
2020 IF (P=2 AND (I MOD 24 = 0)) OR (P=0 AND (I MOD 7 = 0)) THEN  SOUND 1280,1 :GOTO 1150 
2030 '------ LPT L lines, insert 4 CR's
2040 IF P=1 AND L>4 AND I MOD (L-4) = 0 THEN  PRINT#3,STRING$(4,CHR$(13))
2050 GOTO 1890 
2060 '
2070 '
2080 '______________ TPDD SEND/RECIEVE ______________
2090 '
2100 '
2110 '------ send
2120 'CLOSE 1 :OPEN "COM:98N1D" FOR OUTPUT AS 1
2130 POKE Q-1,0 :C=0 :PRINT#1,"ZZ";
2140 FOR A = 1 TO LEN(TX$) :B=ASC(MID$(TX$,A,1)) :C=C+B :PRINT#1,CHR$(B); :NEXT A
2150 PRINT#1,CHR$(NOT C AND 255);
2160 '------ receive
2170 FOR A = 1 TO 500 :IF PEEK(Q-1)=0 THEN  NEXT :A=3 :RETURN
2180 IF PEEK(Q)=56 AND PEEK(Q+2)=112 THEN  A=2 :RETURN
2190 IF PEEK(Q)=56 AND PEEK(Q+2)=0 THEN  A=0 :RETURN
2200 IF PEEK(Q)<>57 THEN  A=1 :RETURN
2210 RX$="" :FOR A = 5 TO 5+D :RX$=RX$+CHR$(PEEK(Q+A)) :NEXT A :A=0 :RETURN
2220 '
2230 '
2240 '______________ UTILS / HELPERS ______________
2250 '
2260 '
2270 '------ end of sector
2280 I=0
2290 IF Z=0 THEN  SOUND 1180,5 :SOUND 1280,5 :X=0 :R=1 :GOTO 1150 
2300 IF S=1 THEN  T=T+1
2310 X=2 :GOTO 1600 
2320 '
2330 '
2340 '------ get printer status
2350 C=INP(179) AND 6 :IF C=6 THEN  A=7 ELSE  IF C=4 THEN  A=8 ELSE  A=0
2360 RETURN
2370 '
2380 '
2390 '------ hex str A$ 00-FF to decimal int A 0-255
2400 A=INSTR(H$,LEFT$(A$,1)) :A=A*16-16 :A=A+INSTR(H$,RIGHT$(A$,1))-1 :RETURN
2410 '
2420 '
2430 '------ decimal int A 0-255 to hex str A$ 00-FF
2440 A$=MID$(H$,(A AND 15)+1,1) :IF A=0 THEN  A=1 ELSE  A=(A/16 AND 15)+1
2450 A$=MID$(H$,A,1)+A$ :RETURN
2460 '
2470 '
2480 '------ fill J$ with the 3-digit hex representation of I*D (current offset within sector)
2490 A=I*D/256 AND 255 :GOSUB 2440 :J$=RIGHT$(A$,1) :A=I*D/256 AND 255 :A=(I*D)-(A*256) :GOSUB 2440 :J$=J$+A$ :RETURN
2500 '
2510 '
2520 '------ open output
2530 'CLOSE 3 :OPEN P$(P)+":" FOR OUTPUT AS 3
2540 '------ progress / status header
2550 CALL 16959 :CLS :PRINT "Output:"+P$(P)+"  Track:"T" Sector:"S" "+Z$(Z) :RETURN
2560 '
2570 '
2580 '------ pop-up dialog
2590 ' does not clean up after itself, you must know on returning from hot-key handler
2600 ' whether a pop-up was used and you need to re-draw the screen. R=1 tells you that.
2610 R=1 :B=LEN(A$)+A+2 :C=140-(B/2) :PRINT@C,CHR$(240)+STRING$(B-2,CHR$(241))+CHR$(242);
2620 PRINT@C+40,CHR$(245)+A$+STRING$(A," ")+CHR$(245);
2630 PRINT@C+80,CHR$(246)+STRING$(B-2,CHR$(241))+CHR$(247);
2640 IF A=0 THEN 2680 ELSE  PRINT@C+41+LEN(A$),""; :A$="000" :B=0
2650 B$=INPUT$(1) :IF B$=CHR$(13) THEN 2670 
2660 A$=A$+B$ :B=B+1 :IF B=A THEN 2670 ELSE  PRINT B$; :GOTO 2650 
2670 A$=RIGHT$(A$,A) :RETURN
2680 A$=INKEY$ :IF A$="" THEN 2680 ELSE  RETURN
2690 '
2700 '
2710 '------ display error
2720 SOUND 1280,1 :SOUND 1180,1 :SOUND 1180,1 :SOUND 1280,1 :SOUND 1180,3
2730 ON A GOSUB 2760,2770,2780,,,,2820,2830,2840,2850 
2740 A=0 :GOSUB 2610 :GOTO 1000 
2750 '  "#######################################" max length
2760 A$="Disk I/O error" :RETURN
2770 A$="Insert disk" :RETURN
2780 A$="Drive not responding" :RETURN
2790 '
2800 '
2810 '
2820 A$="Printer off/not connected" :RETURN
2830 A$="Printer not ready" :RETURN
2840 A$="CRT not available" :RETURN
2850 A$="Unexpected Error :"+STR$(B)+" in"+STR$(ERL) :RETURN
2860 IF ERL=84 OR ERL=96 THEN  A=9 :P=2 :RESUME 2720 
2870 A=10 :B=ERR :RESUME 2720 
