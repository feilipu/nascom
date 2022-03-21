;TODO
;
;- parameterise input buffer size
; -> DONE. And reduced to not waste a byte!
;- change READ and WRITE routines to use some native provision
; -> DONE. write/read/append all tested and working.
;- remove the restriction that register names and op-code names cannot be used
;  for labels. Remove message M12 "RSVD"
; -> DONE.
;- add DEFM as an alias for DEFB
; -> DONE.
;- vectorize all I/O
;- move all RAM and stack to separate area and have cold and warm start
;- consider moving symbol table to beyond source. Just needs to be quashed on any edit command
;  after assembly
;- consider compressing symbol table by pointing to label in source text. As for moved symbol table, needs
;  to be quashed on any edit command after assembly
;- remove FF at the start of the symbol table and make sure everything still works
;- ROMable? Initialise with cold/warm start..
;
;Emulator enhancement: mark accessed locations and allow construction of a heat map
;
;
;Calls:
;
;Save source code from X to Y
;Load source code to X (NAS-SYS can apply offset)
;Char out
;Char in (blocking)
;Char in (non-blocking) - optional, for listing pause
;Char out to printer (paged)
;Char out to object dump
;
;Configurable:
;
;? ASCII codes
;Code start
;Workspace start
;Symbol table size
;Input buffer size
;
; "Sample port" to NAS-SYS





        ORG 1000H
        LOAD 8000H
NBS:    EQU 08
NL:     EQU 13
CR:     EQU 13
LF:     EQU 10
FF:     EQU 12
NFF:    EQU 12;
MOTFLP: EQU 0051H ; for T4 or NAS-SYS
; NAS-SYS routines
RSCAL:  EQU 0DFH
ZMRET:  EQU 05BH
RRIN:   EQU 0CFH
RROUT:  EQU 0F7H
ZSRLX:  EQU 06FH
ZIN:    EQU 062H
ZMFLP:  EQU 05FH;unused
ZBLINK: EQU 07BH
; NAS-SYS workspace
ARGN:   EQU 0C0BH ;8bit
ARG1:   EQU 0C0CH ;16bit
ARG2:   EQU 0C0EH ;16bit
ARGX:   EQU 0C2BH ;8bit
;
S:      EQU 80H
F1:     EQU 0
F2:     EQU 1
F3:     EQU 2
F5:     EQU 3
F6:     EQU 4
F7:     EQU 5
F8:     EQU 6
F9:     EQU 7
ENTRY:  JP ZEN
M1:     DEFB "Z",">".S
M2:     DEFB "HUH","?".S
M3:     DEFB NBS,NBS,NL,CR
M5:     DEFB "EO","F".S
M7:     DEFB "OPTION",">".S
M14:    DEFB "FUL","L".S
M13:    DEFB "DBL."
M15:    DEFB "SYMBO","L".S
M16:    DEFB "OPN","D".S
M17:    DEFB "UNDE","F".S
M18:    DEFB "OR","G".S
M20:    DEFB "ME","M".S
BUFSIZ: EQU 44 ; Longest input line - includes invisible CR
TBUFF:  DEFS BUFSIZ
FLAGS:  DEFB "V",0,0
        DEFB 0,0,0,0,0
LCT:    DEFW 0
CUR:    DEFW 0
TEMP:   DEFW 0
SOURCE: EQU 2800H ;where source code/edit buffer starts
SOFP:   DEFW SOURCE
EOFP:   DEFW SOURCE
FEP:    DEFW 0
STK:    DEFW 0
LBLP:   DEFW 0
PC:     DEFW 0
OBJ:    DEFW 0
ZEN:    LD IX,FLAGS
        LD SP,STACK
        CALL TOP
        CALL CLEAR
        LD HL,$
        PUSH HL
        LD (STK),SP
        LD (IX+F1),"V"
        LD L,M1&255
        CALL CUE
        DEC C
        JP Z,CLEAR
        CP "S"
        JP Z,SORT
        EX DE,HL
        LD HL,(CUR)
        CP "L"
        JR Z,LCTE
        PUSH HL
        PUSH DE
        PUSH BC
        LD C,1
        LD DE,TBUFF
        LD HL,COMTB
        CALL SEARCH
        JP C,E10
        POP BC
        EX (SP),HL
        CALL ARG
        LD A,B
        OR C
        JR NZ,ZN2
        INC BC
ZN2:    POP HL
        EX (SP),HL
        RET
LCTE:   DEC C
        JP Z,E10
        PUSH BC
        CALL NEXT
        POP BC
        DEC HL
        PUSH HL
LC1:    POP HL
        LD A,(HL)
        INC HL
        CP CR
        CALL Z,UPDATE
        CALL EOF
        LD B,C
        LD DE,TBUFF+1
        PUSH HL
LC2:    LD A,(DE)
        CP (HL)
        JR NZ,LC1
        INC DE
        INC HL
        DJNZ LC2
        POP HL
        CALL THIS
        JR LINE
UP:     CALL LAST
        JR NC,LINE
        DEC BC
        LD A,B
        OR C
        JR NZ,UP
        JR LINE
CLOSE:  LD HL,(SOFP)
        LD (EOFP),HL
TOP:    LD HL,1
        LD (LCT),HL
        LD HL,(SOFP)
        LD (CUR),HL
        RET
BTM:    DEC BC
DOWN:   PUSH BC
        CALL NEXT
        POP BC
        CALL UPDATE
        DEC BC
        LD A,B
        OR C
        JR NZ,DOWN
LINE:   CALL EOF
        CALL LO
        JP PR3
ZAP:    PUSH HL
        PUSH BC
        CALL LOT
        POP BC
        POP HL
        DEC BC
        LD A,B
        OR C
        JR NZ,ZAP
        JR LINE
E0:     LD L,M15&255
ER:     LD SP,(STK)
        CALL ERR2
        LD HL,(TEMP)
        LD BC,1
PRINT:  CALL LINE
        INC HL
        CALL UPDATE
        DEC BC
        LD A,B
        OR C
        JR NZ,PRINT
LAST:   PUSH HL
        LD HL,(LCT)
        DEC HL
        LD (LCT),HL
        POP HL
        DEC HL
THIS:   CALL TOF
        JR NC,TOP
        DEC HL
        LD A,(HL)
        CP CR
        JR NZ,THIS
        INC HL
        LD (CUR),HL
        SCF
        RET
ENTER:  CALL LO
        EX DE,HL
        CALL USER
        CP "."
        RET Z
        CALL LIN
        EX DE,HL
        CALL UPDATE
        JR ENTER
NEW:    PUSH HL
        CALL LOT
        CALL LO
        CALL USER
        POP DE
LIN:    PUSH DE
        PUSH BC
        LD HL,(EOFP)
        PUSH HL
        ADD HL,BC
        INC C
LIN1:   DEC C
        LD A,C
        LD (HL),A
        CP (HL)
        DEC HL
        JR NZ,LIN1
        INC HL
        LD (EOFP),HL
        EX (SP),HL
        PUSH HL
        SBC HL,DE
        EX (SP),HL
        POP BC
        POP DE
        INC BC
        LDDR
        POP BC
        POP DE
        OR A
        JP Z,E3
        CP C
        LD C,A
        LD HL,TBUFF
        LDIR
        RET Z
        DEC DE
        LD A,CR
        LD (DE),A
E3:     LD L,M20&255 ; MEM -> out of memory (see comments in BL3) ??how can this occur?
        JP ERR
; used to fall through to HOWBIG but does not any more.
HOWBIG: LD HL,(SOFP)
        CALL WORD
        LD HL,(EOFP)
        CALL WORD
        JP CRLF
SORT:   LD HL,CRLF
        PUSH HL
        LD A,(TBUFF+1)
        PUSH AF
        CALL ASK
        POP AF
        LD C,A
        CP CR
        JR NZ,SCAN
        LD C,"A"
SRT2:   CALL SCAN
        INC C
        LD A,C
        CP "Z"+1
        JR NZ,SRT2
        RET
SCAN:   LD HL,AEND-1
SN1:    INC HL
SN2:    INC HL
        LD A,(HL)
        INC A
        RET Z
        LD B,0
        LD D,H
        LD E,L
SN3:    INC B
        BIT 7,(HL)
        INC HL
        JR Z,SN3
        LD A,(DE)
        CP C
        JR NZ,SN1
        DEC (IX+F9)
        JR NZ,SN4
        CALL CRLF
        LD (IX+F9),3
        PUSH DE
        CALL PAGE
        POP DE
SN4:    EX DE,HL
        PUSH DE
        LD D,B
        LD A,8
        CALL NAME
        POP HL
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL
        CALL WORD
        EX DE,HL
        JR SN2
COMTB:  DEFB "U".S
        DEFW UP
        DEFB "Q".S
        DEFW QUIT
        DEFB "R".S
        DEFW READ
        DEFB "W".S
        DEFW WRITE
        DEFB "A".S
        DEFW ASMB
        DEFB "C".S
        DEFW CLOSE
        DEFB "H".S
        DEFW HOWBIG
        DEFB "E".S
        DEFW ENTER
        DEFB "T".S
        DEFW TOP
        DEFB "N".S
        DEFW NEW
        DEFB "B".S
        DEFW BTM
        DEFB "D".S
        DEFW DOWN
        DEFB "Z".S
        DEFW ZAP
        DEFB "P".S
        DEFW PRINT
        DEFB 0FFH
EOF:    PUSH DE
        EX DE,HL
        LD HL,(EOFP)
        DEC HL
        OR A
        SBC HL,DE
        EX DE,HL
        POP DE
        RET NC
        LD L,M5&255
ERR:    LD SP,(STK)
ERR2:   LD (IX+F1),"V"
        JP PR2
CUE:    CALL STRING
USER:   LD HL,TBUFF
        LD BC,0
US1:    CALL KI
        LD (HL),A
        CP NBS
        JR NZ,US2
        DEC C
        JP M,USER
        DEC HL
        JR US4
US2:    CP CR
        JR NZ,US3
        INC C
        CALL CRLF
        LD A,(TBUFF)
        RET
US3:    LD A,C
        CP BUFSIZ-1
        JR Z,US1
        LD A,(HL)
        INC C
        INC HL
US4:    CALL OUTPUT
        JR US1
        DEFS 48
STACK:  DEFS 2
PR1:    LD L,TBUFF&255
PR2:    LD H,M1/256
PR3:    CALL STR1
CRLF:   LD A,CR
        CALL OUTPUT
        LD A,LF
        JP OUTPUT
STRING: LD H,M1/256
STR1:   LD A,(HL)
        CP CR
        RET Z
        CALL OUTPUT
        BIT 7,(HL)
        INC HL
        JR Z,STR1
        RET
LOT:    PUSH HL
        CALL NEXT
        PUSH HL
        LD HL,(EOFP)
        PUSH HL
        OR A
        SBC HL,BC
        LD (EOFP),HL
        POP HL
        POP DE
        PUSH DE
        OR A
        SBC HL,DE
        EX (SP),HL
        POP BC
        POP DE
        RET Z
        LDIR
        RET
ARG:    INC DE
        DEC C
        RET Z
        LD B,C
        CALL CONV
        LD B,H
        LD C,L
        RET NC
E10:    LD L,M2&255
        JP ERR
PAGE:   DEC (IX+F5)
        RET NZ
        LD A,14
        BIT 1,(IX+F1)
        JR NZ,PG2
        LD A,60
PG2:    LD (IX+F5),A
        CALL WAIT
        CALL C,KI ; key pressed; wait for another.
CLEAR:  LD A,NFF
        JP OUTPUT
CONV:   DEC HL
        LD A,(HL)
        LD C,16
        CP "H"
        JR Z,CV0
        LD C,8
        CP "O"
        JR Z,CV0
        LD C,10
        INC B
CV0:    DEC B
        LD HL,0
CV1:    LD A,(DE)
        SUB 48
        CP 10
        JR C,CV2
        SUB 7
        CP 10
        RET C
CV2:    CP C
        CCF
        RET C
        PUSH DE
        LD E,L
        LD D,H
        BIT 1,C
        JR NZ,CV3
        LD DE,0
        BIT 3,C
        JR NZ,CV3
        ADD HL,HL
CV3:    ADD HL,HL
        ADD HL,HL
        ADD HL,DE
        ADD HL,HL
        LD E,A
        LD D,0
        ADD HL,DE
        POP DE
        RET C
        INC DE
        DJNZ CV1
        RET
TOF:    PUSH DE
        EX DE,HL
        LD HL,(SOFP)
        OR A
        SBC HL,DE
        EX DE,HL
        POP DE
        RET

; can corrupt DE, A. Pause at the end of a screen of output. Scan for keypress;
; return with C if key pressed, NC if no key. The delays here tune the screen
; output rate. TODO need a define elsewhere for #lines per screen and also for
; #lines on printer.
WAIT:   PUSH BC ; pause at end of screen page; scan for input: if input, pause until another keypress
        LD B,12 ; outer loop; number of keyboard scans
WT1:    LD C,2 ; mid loop
WT2:    LD DE,8000 ; inner loop - this used to control cursor flash rate but I subsumed that
WT3:    DEC DE
        LD A,D
        OR E
        JR NZ,WT3
        DEC C
        JR NZ,WT2
        DEFB RSCAL, ZIN; TODO poll for input (optional..)
        JR C,WT4 ; key pressed
        DJNZ WT1
WT4:    POP BC
        RET

NEXT:   CALL EOF
        LD BC,0
NX1:    LD A,(HL)
        INC HL
        INC BC
        CP CR
        JR NZ,NX1
        RET
LO:     PUSH HL
        PUSH BC
        LD HL,TBUFF+33
        PUSH HL
        LD B,5
LO1:    LD (HL),20H
        INC HL
        DJNZ LO1
        LD (HL),CR
        EX DE,HL
        DEC DE
        LD BC,10
        LD HL,(LCT)
LO2:    DEC DE
        PUSH DE
        EX DE,HL
        CALL MA50
        LD A,E
        POP DE
        ADD A,30H
        LD (DE),A
        LD A,L
        OR H
        JR NZ,LO2
        POP HL
        CALL STR1
        POP BC
        POP HL
        RET
WORD:   LD A,H
        CALL BYT
        LD A,L
BYTE:   PUSH HL
        LD HL,SPACE
        EX (SP),HL
BYT:    PUSH AF
        RRCA
        RRCA
        RRCA
        RRCA
        CALL NYB
        POP AF
NYB:    AND 0FH
        ADD A,90H
        DAA
        ADC A,40H
        DAA
        JP OUTPUT
UPDATE: LD (CUR),HL
LINC:   PUSH HL
        LD HL,(LCT)
        INC HL
        LD (LCT),HL
        POP HL
        RET
JL:     EQU 3
CL:     EQU 1
TL:     EQU 16
LL:     EQU 21
AL:     EQU 2
SBL:    EQU 2
ADL:    EQU 4
INL:    EQU 3
OL:     EQU 3
XL:     EQU 4
IBC:    EQU 0
IDE:    EQU 2
IHL:    EQU 4
IAF:    EQU 0EH
ISP:    EQU 6
IB:     EQU 0
IC:     EQU 1
ID:     EQU 2
IE:     EQU 3
IH:     EQU 4
IL:     EQU 5
IA:     EQU 7
IIX:    EQU 0DDH
IIY:    EQU 0FDH
IREF:   EQU 8
IINT:   EQU 0
ICY:    EQU 18H
INCY:   EQU 10H
IZ:     EQU 8
INZ:    EQU 0
IPO:    EQU 20H
IPE:    EQU 28H
IMIN:   EQU 38H
IPOS:   EQU 30H
TR:     EQU 0
RI:     EQU 4
RP:     EQU 1
RPI:    EQU 5
XY:     EQU 2
XYI:    EQU 6
NO:     EQU 3
NOI:    EQU 7
RE:     EQU 8
CC:     EQU 9
XYD:    EQU 10
TCR:    EQU 11
TALPHA: EQU 30H
TLAB:   EQU 31H
TOPD:   EQU 32H
TCOM:   EQU 33H
TIND:   EQU 34H
TADD:   EQU 40H
TSUB:   EQU 0C0H
TMUL:   EQU 80H
TDIV:   EQU 81H
TAND:   EQU 82H
TOR:    EQU 83H
TDEF:   EQU 35H
TLIT:   EQU 36H
ASMB:   CALL ASK
        LD HL,AEND+1
        LD (HL),0FFH
        LD (FEP),HL
        CALL PASS
        RES 5,(IX+F1)
        CALL OPTION
PASS:   CALL TOP
PS1:    LD HL,(CUR)
        LD (TEMP),HL
        LD HL,(PC)
        PUSH HL
        LD HL,0
        LD (FLAGS+F2 ),HL
        LD (FLAGS+F6),HL
        CALL CLASS
        CP TLAB
        CALL Z,SYM
        CP TCR
        JR Z,PS2
        CP TALPHA
        JR NZ,E1
        CALL OPTSCH
        JR C,E1
        LD (IX+F6),C
        CALL JUMP
        JP NZ,E6
        CALL PARSER
        CP TCR
        JR NZ,E1
PS2:    POP HL
        CALL OPTION
        CALL C,LIST
        CALL LINC
        INC B
        JR NZ,PS1
        RET
E1:     LD L,M2&255
        JP ER
ASK:    LD L,M7&255
        CALL CUE
        OR 0B8H
        LD (IX+F1),A
        LD (IX+F5),1
        LD (IX+F9),1
        RET
SYM:    SET 1,(IX+F2)
        INC C
        LD (IX+F7),C
        DEC C
        JP Z,E0
        CALL SYMSCH
        LD (LBLP),IY
        BIT 5,(IX+F1)
        JR Z,SY2
        LD L,M13&255
        JP NC,ER
        LD HL,(FEP)
        PUSH HL
        LD B,0
        ADD HL,BC
        INC HL
        INC HL
        INC HL
        CALL TOF
        LD L,M14&255
        JP C,ER
        POP HL
        EX DE,HL
        LDIR
        EX DE,HL
        DEC HL
        SET 7,(HL)
        POP BC
        POP DE
        PUSH DE
        PUSH BC
        INC HL
        LD (HL),E
        INC HL
        LD (HL),D
        LD (LBLP),HL
        INC HL
        LD (HL),0FFH
        LD (FEP),HL
SY2:    JP CLASS
JUMP:   LD B,H
        BIT 7,L
        JR NZ,JP2
        SET 3,(IX+F2)
JP2:    RES 7,L
        LD E,L
        LD D,0
        LD A,L
        LD HL,JPTAB
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        PUSH DE
        CP 5
        RET C
        CP 39
        JP C,PARSER
        CALL PARSER
        PUSH HL
        PUSH AF
        CALL PARSER
        LD C,A
        POP AF
        EX DE,HL
        POP HL
        RLCA
        RLCA
        RLCA
        RLCA
        OR C
        LD C,A
        POP IY
        CALL FIND
        LD B,A
        JR Z,JP3
        EX DE,HL
JP3:    LD A,L
        RLCA
        RLCA
        RLCA
        RLCA
        OR E
        JP (IY)
JPTAB:  DEFW MOFB
        DEFW L30
        DEFW ENDH
        DEFW RSTH
        DEFW RETH
        DEFW PPH
        DEFW JRH
        DEFW DJH
        DEFW INCH
        DEFW ML1
        DEFW SRH
        DEFW BITH
        DEFW DWH
        DEFW DBH
        DEFW DSH
DEFW    EQUH
        DEFW ORGH
        DEFW IMH
        DEFW RDH
        DEFW LOADH
        DEFW LTAB
        DEFW CALTAB
        DEFW JMPTAB
        DEFW XTAB
        DEFW INTAB
        DEFW ADDTAB
        DEFW ADCTAB
        DEFW SBCTAB
        DEFW OUTAB
LIST:   PUSH BC
        LD C,(IX+F3)
        LD DE,(FLAGS+F6)
        LD IY,TBUFF
LS1:    PUSH DE
        CALL PAGE
        CALL LO
        POP DE
        LD B,14
        INC C
        DEC C
        JR Z,LS4
        CALL WORD
        LD B,4
LS2:    LD A,(IY+0)
        CALL BYT
        INC IY
        INC HL
        DEC C
        JR Z,LS3
        DJNZ LS2
        INC B
LS3:    SLA B
        DEC B
LS4:    CALL SPACE
        DJNZ LS4
        PUSH HL
        LD HL,(TEMP)
        BIT 0,(IX+F2)
        JR Z,LS7
        LD A,8
        CALL NAME
        LD D,E
        LD A,5
        CALL NAME
        LD E,D
        PUSH HL
LS5:    LD A,(HL)
        CP CR
        JR Z,LS6
        CP 3BH
        JR Z,LS6
        INC D
        INC HL
        JR LS5
LS6:    POP HL
        LD A,10
        CALL NAME
LS7:    CALL PR3
        LD (TEMP),HL
        POP HL
        INC C
        DEC C
        JR NZ,LS1
        POP BC
        RET
NAME:   INC D
        SUB D
        PUSH AF
NM2:    DEC D
        JR Z,NM3
        LD A,(HL)
        CALL OUTPUT
        INC HL
        JR NM2
NM3:    POP AF
        JR C,NM5
        INC A
        LD B,A
NM4:    CALL SPACE
        DJNZ NM4
NM5:    LD A,(HL)
        INC HL
        CP 20H
        JR Z,NM5
        DEC HL
        RET
SYMSCH: LD HL,AEND+1
        JR SEARCH
OPDSCH: LD HL,CCST
        BIT 3,(IX+F2)
        JR Z,SEARCH
        LD HL,REGS
        JR SEARCH
OPTSCH: LD HL,KEYTB
        PUSH BC
        LD C,1
        CALL SEARCH
        POP BC
        INC HL
        JR C,SEARCH
        INC DE
        DEC C
        SCF
        CALL NZ,SEARCH
        INC BC
        DEC DE
        RET
BAD:    BIT 7,(HL)
        INC HL
        JR Z,BAD
        INC HL
        INC HL
        POP DE
SEARCH: LD A,(HL)
        INC A
        SCF
        RET Z
        PUSH DE
        LD B,C
SC2:    LD A,(DE)
        DJNZ SC3
        SET 7,A
SC3:    INC B
        CP (HL)
        JR NZ,BAD
        INC DE
        INC HL
        DJNZ SC2
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX (SP),HL
        EX DE,HL
        POP IY
        RET
OPTION: LD A,(IX+F1)
        XOR 32
        BIT 5,A
        RET Z
        BIT 6,A
        RET Z
        SCF
        BIT 0,A
        RET Z
        BIT 1,A
        RET Z
        OR A
        RET
RESOLV: CP NO
        JR NZ,E6
        LD A,(IX+F2)
        BIT 4,A
        JP NZ,E7
        BIT 1,A
        RET
LITLE:  CP NO
        JR NZ,E6
LITLE2: BIT 5,(IX+F1)
        RET NZ
        LD A,H
        OR A
        RET Z
E6:     LD L,M16&255
        JP ER
MOFMIX: LD E,L
MOFMX2: BIT 3,E
        JR NZ,E6
        LD A,E
        RLCA
        RLCA
        RLCA
        OR B
        JR MOF
MOFPRE: LD A,0EDH
        JR MOF
MOFLH:  LD A,L
        CALL MOF
MOFH:   LD A,H
        JR MOF
MOFB:   LD A,B
MOF:    PUSH HL
        CALL CL2
        INC HL
        LD (PC),HL
        BIT 4,(IX+F1)
        JR NZ,MOF2
        LD HL,(OBJ)
        LD (HL),A
        INC HL
        LD (OBJ),HL
MOF2:   POP HL
SAVE:   PUSH HL
        PUSH DE
        PUSH BC
        LD D,A
        CALL OPTION
        JR C,SV2
        JR Z,SV3
        LD BC,(FLAGS+F8)
        DJNZ SV1
        LD HL,(PC)
        DEC HL
        LD A,L
        ADD A,H
        LD C,A
        LD B,8
        CALL WORD
SV1:    LD A,D
        ADD A,C
        LD C,A
        LD (FLAGS+F8),BC
        LD A,D
        CALL BYTE
        DJNZ SV3
        LD A,C
        CALL BYT
        LD L,M3&255
        CALL STRING
        JR SV3
SV2:    LD HL,TBUFF
        LD A,(IX+F3)
        CP 20
        JR Z,SV3
        ADD A,L
        LD L,A
        LD (HL),D
        INC (IX+F3)
SV3:    POP BC
        POP DE
        POP HL
        XOR A
        RET
PARSER: BIT 0,(IX+F2)
        LD A,TCR
        RET NZ
        PUSH BC
        CALL PA1
        POP BC
        RET
PA1:    CALL TERM
        RET C
        CP TIND
        LD B,0
        JR NZ,PA2
        CALL TERM
        LD B,4
PA2:    CP TOPD
        JR NZ,PA7
        LD A,H
        OR B
        LD D,A
        PUSH HL
        CALL TERM
        POP HL
        LD C,A
        LD A,D
        RET C
        CP XYI
        JR NZ,PER
        BIT 6,C
        JR Z,PER
        LD B,L
        PUSH BC
        CALL TERM
        CALL PA4
        POP BC
        CALL LITLE2
        JR NZ,PA3
        LD A,L
        BIT 7,C
        JR Z,PA31
        NEG
        LD L,A
PA31:   XOR C
        JP M,E6
PA3:    LD H,B
        LD A,XYD
        RET
PA7:    CP TLIT
        JR NZ,PA4
        OR B
        LD L,A
        PUSH HL
        CALL TERM
        POP HL
        LD A,L
        RET C
PER:    JP E6
PA4:    CP NO
        JR NZ,PER
        OR B
        PUSH AF
PA5:    PUSH HL
        CALL TERM
        POP HL
        JR C,PA6
        PUSH AF
        PUSH HL
        CALL TERM
        EX DE,HL
        POP HL
        CP NO
        JR NZ,PER
        POP AF
        CALL MATH
        JR PA5
PA6:    POP AF
        RET
MATH:   CP TADD
        JR NZ,MA2
        ADD HL,DE
        RET
MA2:    CP TSUB
        JR NZ,MA3
        SBC HL,DE
        RET
MA3:    CP TAND
        JR NZ,MA4
        LD A,E
        AND L
        LD L,A
        LD A,D
        AND H
        LD H,A
        RET
MA4:    CP TOR
        JR NZ,MA5
        LD A,E
        OR L
        LD L,A
        LD A,D
        OR H
        LD H,A
        RET
MA5:    LD C,E
        LD B,D
        EX DE,HL
        CP TDIV
        JR NZ,MA6
MA50:   LD HL,0
        LD A,17
        OR A
MA51:   ADC HL,HL
        SBC HL,BC
        JR NC,MA52
        ADD HL,BC
        SCF
MA52:   CCF
        RL E
        RL D
        DEC A
        JR NZ,MA51
        EX DE,HL
        RET
MA6:    CP TMUL
        JR NZ,PER
        LD HL,0
        LD A,16
MA61:   SRL B
        RR C
        JR NC,MA62
        ADD HL,DE
MA62:   EX DE,HL
        ADD HL,HL
        EX DE,HL
        DEC A
        JR NZ,MA61
        RET
TERM:   CALL CLASS
        CP TLAB
        JP Z,E6
TE2:    CP TCR
        JR NZ,TE3
        SET 0,(IX+F2)
        SCF
        RET
TE3:    CP TCOM
        SCF
        RET Z
        CP TALPHA
        SCF
        CCF
        RET NZ
        CALL OPDSCH
        LD A,TOPD
        RET NC
        CALL SYMSCH
        LD A,NO
        RET NC
        CCF
        SET 4,(IX+F2)
        BIT 5,(IX+F1)
        RET NZ
E7:     LD L,M17&255
        JP ER
TYPE:   LD HL,(CUR)
        CALL EOF
        INC HL
        LD (CUR),HL
        DEC HL
        LD A,(HL)
        LD IY,TYPTAB
FIND:   PUSH DE
        PUSH IY
        EX (SP),HL
        LD E,(HL)
        LD D,E
FIN1:   INC HL
        CP (HL)
        JR Z,FIN2
        DEC D
        JR NZ,FIN1
FIN2:   LD D,0
        ADD HL,DE
        LD A,(HL)
        ADD HL,DE
        LD E,A
        LD A,(HL)
        BIT 7,E
        RES 7,E
        ADD HL,DE
        EX (SP),HL
        POP IY
        POP DE
        RET
TYPTAB: DEFB TL,CR,"'"
        DEFB "$*/+-&.()"
        DEFB 3BH,':",'
        DEFB 0
        DEFB CL3-$-TL
        DEFB CL4-$-TL
        DEFB CL2-$-TL
        DEFB CL3-$-TL
        DEFB CL3-$-TL
        DEFB CL3-$-TL
        DEFB CL3-$-TL
        DEFB CL3-$-TL
        DEFB CL3-$-TL
        DEFB CL3-$-TL
        DEFB CLASS-$-TL
        DEFB CL1-$-TL
        DEFB CL3-$-TL
        DEFB CL4-$-TL
        DEFB CL3-$-TL
        DEFB CL5-$-TL
        DEFB TCR,0,NO,TMUL,TDIV
        DEFB TADD,TSUB,TAND,TOR
        DEFB TIND,0,0,TLAB
        DEFB 0,TCOM,TDEF
CLASS:  CALL TYPE
        LD BC,2100H
        JP (IY)
CL1:    CALL TYPE
        CP TCR
        JR NZ,CL1
CL3:    RET
CL2:    LD HL,(PC)
        BIT 7,(IX+F1)
        RET Z
E11:    LD L,M18&255
        JP ER
CL4:    PUSH HL
        LD B,(HL)
CL41:   LD E,(HL)
        INC C
        CALL TYPE
        CP TCR
        JR Z,CLER
        LD A,(HL)
        CP B
        JR NZ,CL41
        EX DE,HL
        POP DE
        DEC C
        JR Z,CLER
        LD H,C
        LD A,NO
        DEC H
        RET Z
        INC H
        LD A,TLIT
        RET
CL5:    LD A,(HL)
        CP B
        JR C,CLASS
        CP 30H
        JR C,CL7
        CP 3AH
        JR NC,CL7
CL6:    CALL CL7
        CP TLAB
        JR Z,CLER
        LD B,C
        CALL CONV
        LD A,NO
        RET NC
CLER:   JP E6
CL7:    EX DE,HL
CL71:   INC C
        CALL TYPE
        CP TLAB
        RET Z
        CP TDEF
        JR NZ,CL72
        LD A,(HL)
        CP B
        JR NC,CL71
CL72:   LD (CUR),HL
        LD A,TALPHA
        RET
JRH:    CP CC
        JR NZ,DJH
        LD A,L
        AND 0E7H
        RET NZ
        LD B,L
        SET 5,B
        CALL PARSER
DJH:    CP NO
        RET NZ
        CALL MOFB
        BIT 5,(IX+F1)
        JR NZ,DJ2
        LD DE,(PC)
        SCF
        SBC HL,DE
        LD A,H
        INC H
        JR Z,DJ1
        DEC H
        RET NZ
DJ1:    XOR L
        RET M
DJ2:    LD A,L
        JP MOF
DWH:    CP NO
        RET NZ
        JP MOFLH
DBH:    CP TLIT
        JR NZ,DBH3
DBH1:   INC DE
        LD A,(DE)
        CALL MOF
        DEC H
        JR NZ,DBH1
        JR DBH4
DBH3:   CALL LITLE
        LD A,L
        CALL MOF
DBH4:   CALL PARSER
        CP TCR
        JR NZ,DBH
        RET
DSH:    CALL RESOLV
        CALL ENDH
        EX DE,HL
        LD HL,(PC)
        ADD HL,DE
        LD (PC),HL
        LD HL,(OBJ)
        ADD HL,DE
        LD (OBJ),HL
        RET
LOADH:  CALL RESOLV
        LD (OBJ),HL
        RES 4,(IX+F1)
        XOR A
        RET
ORGH:   CALL RESOLV
        LD (PC),HL
        SET 4,(IX+F1)
        RES 7,(IX+F1)
        CALL NZ,EQ2
ENDH:   CALL OPTION
        RET Z
FILL:   LD A,(IX+F9)
        DEC A
        JR Z,FILL2
        CALL SAVE
        JR FILL
FILL2:  LD A,B
        OR A
        RET Z
        LD A,"."
        CALL OUTPUT
        LD A,NL
        CALL OUTPUT
        XOR A
        RET
EQUH:   CALL RESOLV
        JP Z,E0
EQ2:    EX DE,HL
        LD HL,(LBLP)
        LD (HL),D
        DEC HL
        LD (HL),E
        XOR A
        RET
LTAB:   DEFB LL
        DEFB RPI*16.NO
        DEFB TR*16.NO
        DEFB RE*16.TR
        DEFB TR*16.RE
        DEFB TR*16.TR
        DEFB RP*16.RP
        DEFB NOI*16.XY
        DEFB XY*16.NOI
        DEFB XY*16.NO
        DEFB NOI*16.TR
        DEFB TR*16.NOI
        DEFB NOI*16.RP
        DEFB RP*16.NOI
        DEFB RP*16.XY
        DEFB XYD*16.NO
        DEFB RP*16.NO
        DEFB XYD*16.TR
        DEFB TR*16.XYD
        DEFB RPI*16.TR
        DEFB TR*16.RPI
        DEFB 0
        DEFB L1-$-LL.S
        DEFB L2-$-LL.S
        DEFB L3-$-LL
        DEFB L3-$-LL.S
        DEFB L4-$-LL.S
        DEFB L5-$-LL
        DEFB L6-$-LL
        DEFB L6-$-LL.S
        DEFB L6-$-LL.S
        DEFB L7-$-LL
        DEFB L7-$-LL.S
        DEFB L8-$-LL
        DEFB L8-$-LL.S
        DEFB L9-$-LL.S
        DEFB LA-$-LL.S
        DEFB LB-$-LL.S
        DEFB LC-$-LL
        DEFB LC-$-LL.S
        DEFB LE-$-LL
        DEFB LE-$-LL.S
        DEFB LER-$-LL
        DEFB 16H,6,47H,57H,40H
        DEFB 0F9H,22H,2AH,21H,32H
        DEFB 3AH,22H,2AH,0F9H,36H
        DEFB 1,2,0AH,2,0AH,0
L1:     LD A,E
        CP IHL
        RET NZ
L2:     CALL LITLE2
        CALL MOFMX2
        LD A,L
L21:    JP MOF
L3:     BIT 2,E
        JR Z,LER
        LD A,L
        OR B
        LD B,A
L30:    CALL MOFPRE
L31:    JP MOFB
L4:     LD A,L
        OR B
        LD B,A
        JP MOFMX2
L5:     CP ISP*16.IHL
        RET NZ
        JR L31
L6:     LD A,E
L61:    CALL MOF
L62:    CALL MOFB
L63:    JP MOFLH
L7:     BIT 2,E
        JR NZ,L62
LER:    JP E6
L8:     LD A,E
        CP IHL
        JR Z,L62
        CALL MOFPRE
        LD A,B
        XOR 61H
        LD B,A
        CALL MOFMX2
        JP MOFLH
L9:     LD A,E
        CP ISP
        RET NZ
        LD H,B
        JR L63
LA:     CALL LITLE2
        LD A,D
        LD H,L
        LD L,E
        JR L61
LB:     CALL MOFMX2
        JR L63
LC:     CALL MOFH
        CALL LE1
        LD A,L
        JR L21
LE:     CP IBC*16.IA
        JR Z,L31
        SET 4,B
        CP IDE*16.IA
        JR Z,L31
        LD A,L
        CP IHL
        RET NZ
LE1:    BIT 3,B
        LD B,46H
        JP NZ,MOFMX2
        LD A,E
        OR 70H
        JR L21
RSTH:   CALL LITLE
        JR NZ,RST2
        LD A,L
        AND B
        RET NZ
RST2:   LD A,B
        OR L
        JP MOF
RETH:   CP CC
        JR Z,RST2
        LD B,0C9H
        CP TCR
        JR JMP21
JMPTAB: DEFB JL
        DEFB XYI*16.TCR
        DEFB RPI*16.TCR
        DEFB 0
        DEFB JMP1-$-JL
        DEFB JMP2-$-JL
        DEFB JMP3-$-JL
        DEFB 0E9H,0E9H,0C3H
JMP1:   LD H,B
        JP MOFLH
JMP2:   LD A,L
        CP IHL
JMP21:  RET NZ
        JP MOFB
CALTAB: DEFB CL
        DEFB 0
        DEFB JMP3-$-CL
        DEFB 0CDH
JMP3:   LD A,C
        CP NO*16.TCR
        JP Z,L62
        CP CC*16.NO
        RET NZ
        LD A,B
        AND 0C6H
        OR L
        LD B,A
        EX DE,HL
        JP L62
PPH:    CP RP
        JR NZ,PP2
        LD A,L
        CP ISP
        JP Z,E6
        RES 3,L
        JP MOFMIX
PP2:    CP XY
        RET NZ
PP21:   SET 5,B
        LD H,B
        JP MOFLH
IMH:    CALL LITLE
        JR NZ,IM2
        LD A,2
        SUB L
        RET C
IM2:    LD DE,IMTAB
        ADD HL,DE
        LD B,(HL)
        JP L30
IMTAB:  DEFB 46H,56H,5EH
INCH:   CP XY
        JR Z,PP21
        CP RP
        JP Z,MOFMIX
        BIT 3,B
        LD B,34H
        JR Z,INC2
        INC B
INC2:   OR A
        JR NZ,ML2
        LD A,B
        AND 0C7H
        LD B,A
        JP MOFMIX
ADCTAB: DEFB AL
        DEFB RP*16.RP
        DEFB 0
        DEFB DL1-$-AL
        DEFB DL5-$-AL.S
        DEFB 4AH,8EH
SBCTAB: DEFB SBL
        DEFB RP*16.RP
        DEFB 0
        DEFB DL1-$-SBL
        DEFB DL5-$-SBL.S
        DEFB 42H,9EH
ADDTAB: DEFB ADL
        DEFB RP*16.RP
        DEFB XY*16.RP
        DEFB XY*16.XY
        DEFB 0
        DEFB DL2-$-ADL
        DEFB DL3-$-ADL
        DEFB DL4-$-ADL
        DEFB DL5-$-ADL.S
        DEFB 9,9,29H,86H
RDH:    LD E,L
DL1:    CALL MOFPRE
DL2:    LD A,L
        CP IHL
        RET NZ
        JP MOFMX2
DL3:    LD A,E
        CP IHL
        JP Z,E6
        LD A,L
        CALL MOF
        JP MOFMX2
DL4:    LD A,E
        CP L
        LD H,B
        RET NZ
        JP MOFLH
DL5:    LD A,C
        AND 0F0H
        RET NZ
        BIT 2,E
        JP Z,E6
        LD A,C
        AND 0FH
ML1:    CP NO
        JR NZ,ML2
        SET 6,B
ML11:   CALL LITLE2
ML12:   LD H,L
        LD L,B
        JP MOFLH
ML2:    CP XYD
        JR NZ,ML3
        CALL MOFH
        JR ML12
ML3:    CP RPI
        JP Z,JMP2
        OR A
        RET NZ
        LD A,B
        AND 0F8H
        OR L
        JP MOF
BITH:   CALL LITLE
        JR NZ,BIT2
        LD A,7
        SUB L
        RET C
BIT2:   LD A,L
        RLCA
        RLCA
        RLCA
        OR B
        LD B,A
        CALL PARSER
SRH:    CP XYD
        JR NZ,SR2
        PUSH HL
        LD L,H
        LD H,0CBH
        CALL MOFLH
        POP HL
        LD H,B
        JP MOFLH
SR2:    PUSH AF
        LD A,0CBH
        CALL MOF
        POP AF
        JR ML3
INTAB:  DEFB INL
        DEFB TR*16.NOI
        DEFB TR*16.RI
        DEFB 0
        DEFB IO1-$-INL.S
        DEFB IO2-$-INL.S
        DEFB IOER-$-INL
        DEFB 0DBH,40,0
OUTAB:  DEFB OL
        DEFB NOI*16.TR
        DEFB RI*16.TR
        DEFB 0
        DEFB IO1-$-OL
        DEFB IO2-$-OL
        DEFB IOER-$-OL
        DEFB 0D3H,41H,0
IO1:    BIT 2,E
        JR Z,IOER
        JP ML11
IO2:    CALL MOFPRE
        DEC L
        JP Z,MOFMX2
IOER:   JP E6
XTAB:   DEFB XL
        DEFB RP*16.RP
        DEFB RPI*16.RP
        DEFB RPI*16.XY
        DEFB 0
        DEFB X1-$-XL
        DEFB X2-$-XL
        DEFB X3-$-XL.S
        DEFB XER-$-XL
        DEFB 0EBH,0E3H,0E3H,0
X1:     CP IDE*16.IHL
        JP Z,MOFB
        LD B,8
        CP IAF*16.IAF
        JP Z,MOFB
XER:    JR IOER
X2:     JP L5
X3:     JP L9
CCST:   DEFB "C".S,ICY,CC
        DEFB "N","C".S,INCY,CC
        DEFB "Z".S,IZ,CC
        DEFB "N","Z".S,INZ,CC
        DEFB "P".S,IPOS,CC
        DEFB "M".S,IMIN,CC
        DEFB "P","O".S,IPO,CC
        DEFB "P","E".S,IPE,CC
REGS:   DEFB "H","L".S,IHL,RP
        DEFB "D","E".S,IDE,RP
        DEFB "B","C".S,IBC,RP
        DEFB "A","F".S,IAF,RP
        DEFB "S","P".S,ISP,RP
        DEFB "A".S,IA,TR
        DEFB "B".S,IB,TR
        DEFB "C".S,IC,TR
        DEFB "D".S,ID,TR
        DEFB "E".S,IE,TR
        DEFB "H".S,IH,TR
        DEFB "L".S,IL,TR
        DEFB "I".S,IINT,RE
        DEFB "R".S,IREF,RE
        DEFB "I","Y".S,IIY,XY
        DEFB "I","X".S,IIX,XY
        DEFB 0FFH
KEYTB:  DEFB "L".S
        DEFW LOPS-1
        DEFB "C".S
        DEFW COPS-1
        DEFB "D".S
        DEFW DOPS-1
        DEFB "I".S
        DEFW IOPS-1
        DEFB "S".S
        DEFW SOPS-1
        DEFB "O".S
        DEFW OOPS-1
        DEFB "E".S
        DEFW EOPS-1
        DEFB "R".S
        DEFW ROPS-1
        DEFB 0FFH
        DEFB "J","P".S,44.S,0
        DEFB "J","R".S,12.S,18H
        DEFB "PUS","H".S,10,0C5H
        DEFB "PO","P".S,10,0C1H
        DEFB "AD","D".S,50,0
        DEFB "AD","C".S,52,0
        DEFB "BI","T".S,22,46H
        DEFB "XO","R".S,18,0AEH
        DEFB "AN","D".S,18,0A6H
        DEFB "NO","P".S,0,0
        DEFB "NE","G".S,2,44H
        DEFB "HAL","T".S,0,76H
        DEFB 0FFH
LOPS:   DEFB "D".S,40,0
        DEFB "OA","D".S,38,0
        DEFB "D","I".S,2,0A0H
        DEFB "DI","R".S,2,0B0H
        DEFB "D","D".S,2,0A8H
        DEFB "DD","R".S,2,0B8H
        DEFB 0FFH
COPS:   DEFB "AL","L".S,42.S,0
        DEFB "P".S,18,0BEH
        DEFB "C","F".S,0,3FH
        DEFB "P","L".S,0,2FH
        DEFB "P","I".S,2,0A1H
        DEFB "PI","R".S,2,0B1H
        DEFB "P","D".S,2,0A9H
        DEFB "PD","R".S,2,0B9H
        DEFB 0FFH
DOPS:   DEFB "E","C".S,16,0BH
        DEFB "JN","Z".S,14,10H
        DEFB "EF","B".S,26,0
        DEFB "EF","M".S,26,0 ; DEFM alias for DEFB
        DEFB "EF","W".S,24,0
        DEFB "EF","S".S,28,0
        DEFB "A","A".S,0,27H
        DEFB "I".S,0,0F3H
        DEFB 0FFH
IOPS:   DEFB "N","C".S,16,3
        DEFB "M".S,34,0
        DEFB "N".S,48,0 ; errors in IN rr,(C)
        DEFB "N","I".S,2,0A2H
        DEFB "NI","R".S,2,0B2H
        DEFB "N","D".S,2,0AAH
        DEFB "ND","R".S,2,0BAH
        DEFB 0FFH
SOPS:   DEFB "B","C".S,54,0
        DEFB "C","F".S,0,37H
        DEFB "L","A".S,20,26H
        DEFB "R","A".S,20,2EH
        DEFB "R","L".S,20,3EH
        DEFB "E","T".S,22,0C6H
        DEFB "U","B".S,18,96H
        DEFB "CA","L".S,18,0DFH
        DEFB 0FFH
OOPS:   DEFB "R".S,18,0B6H
        DEFB "R","G".S,32,0
        DEFB "U","T".S,56,0
        DEFB "UT","I".S,2,0A3H
        DEFB "TI","R".S,2,0B3H
        DEFB "UT","D".S,2,0ABH
        DEFB "TD","R".S,2,0BBH
        DEFB 0FFH
EOPS:   DEFB "X".S,46,0
        DEFB "X","X".S,0,0D9H
        DEFB "Q","U".S,30,0
        DEFB "I".S,0,0FBH
        DEFB "N","D".S,4,0FFH
        DEFB 0FFH
ROPS:   DEFB "E","T".S,8.S,0C0H
        DEFB "S","T".S,6,0C7H
        DEFB "E","S".S,22,86H
        DEFB "L".S,20,16H
        DEFB "L","C".S,20,6
        DEFB "LC","A".S,0,7
        DEFB "L","A".S,0,17H
        DEFB "R".S,20,1EH
        DEFB "R","C".S,20,0EH
        DEFB "RC","A".S,0,0FH
        DEFB "R","A".S,0,1FH
        DEFB "L","D".S,2,6FH
        DEFB "R","D".S,2,67H
        DEFB "ET","I".S,2,4DH
        DEFB "ET","N".S,2,45H
        DEFB "CA","L".S,14,0D7H
;=====================================================================
;Target system porting
;
;*** Save source. Save source from (SOFP) to (EOFP). This uses the NAS-SYS tape format
; by calling the W command. (This allowed removal of M10). To allow the end-of-file
; to be detected after a subsequent load, insert a NUL (0) at the end and include it as
; part of the saved data
WRITE:  LD HL,(SOFP)
        LD (ARG1), HL
        LD HL,(EOFP) ;first free
        XOR A
        LD (HL),A    ;end-of-text marker used by "READ"
        INC HL       ;W needs 1 byte beyond final byte
        LD (ARG2), HL
        SCAL "W"
        RET
;*** End

;*** Load source. Load it at (EOFP) and update (EOFP). If (SOFP) = (EOFP) then the
; source/edit buffer is currently empty. If they are != then the new buffer is being
; appended to existing buffer - in which case its original load address needs to be
; changed (optional offset argument in HL, and need to set argn and argx).
; NAS-SYS provides no way of knowing how much data was loaded, so rely on the 0 at
; the end of saved source: search for it and set (EOFP).
; Two nasties in NAS-SYS3 when trying to call R:
; - must set (ARGX) to R (to distinguish from V)
; - for no offset, must set (ARGN) to 0
; - for offset, must set (ARGN) to 1 and (ARG1) to the offset
; (unlike original, this does NOT detect memory full)
READ:   LD A,"R"
        LD (ARGX),A ;R not V
        XOR A
        LD (ARGN),A ;Assume no offset
        LD HL, (SOFP)
        LD DE, (EOFP)
        OR A ; clear carry
        SBC HL,DE
        LD A, H
        OR L
        JR Z,NORDOS
        ;read offset
        LD A,1
        LD (ARGN),A
        LD HL, (EOFP)
        LD DE, SOURCE
        OR A
        SBC HL,DE
        LD (ARG1),HL
NORDOS: SCAL "R"
; The end of the loaded file is marked with a "00"
        LD HL, (EOFP)
        XOR A
        LD B,A
        LD C,A
        CPIR
        DEC HL ; HL now points to the 00 which is the first free location
        LD (EOFP), HL
        RET
;*** End

;*** Return to host environment
QUIT:
        DEFB 0, 0, 0, 0, RSCAL, ZMRET
;*** End

;*** Output routine, with a bit of other code to keep the relative jumps
SPACE:  LD A,20H
OUTPUT: BIT 1,(IX+F1)
        JR Z,EXT
        BIT 2,(IX+F1)
        JR Z,SOUT
VDU:    RES 7,A
        CP LF
        RET Z
        CP CR
        JR NZ,VID3
        LD A,NL
VID3:   DEFB RROUT ; TODO output..
        RET
;*** End

;*** External (printer) output, with paging, for listing source code and symbol table. Output char in A
EXT:    RES 7,A
        CP NFF ; convert form-feed
        JR NZ,EXT2
        LD A,FF
EXT2:   JP SOUT
;*** End

;*** Output for saving object code in .NAS ASCII format. Output char in A.
SOUT:   SCAL ZSRLX
        RET
;*** End

;*** Keyboard in. Wait for character, clear bit 7. Return character in A. Preserve other registers
KI:     PUSH HL
        PUSH DE
        SCAL ZBLINK
        RES 7,A
        POP DE
        POP HL
        RET
;*** End



AEND:   DEFB 0FFH
        DEFB 0FFH
        END
