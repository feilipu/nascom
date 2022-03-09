; Annotated source code for Zen; behaviour inferred by Mike and Neal, Feb2022
; Warning: lots of this code has been space-optimised to use 8-bit values where
; it would be more natural to use 16-bit values. For example, the high byte
; (page) addressing the messages M1, M2 etc. is implied. The messages and the TBUF
; must be on the same page for things to work correctly. Therefore, there are some
; origin addresses where the code will assemble but not work. Origin with low byte
; of 00H or (as here) 50H work correctly. YMMV!

        ORG 0C50H
;
; Character values - T4 doesn't use ASCII for BS/CR. Stored edit buffer uses CR to separate lines
;
NBS:    EQU 29 ;(1Dh)  NASCOM T4 backspace
NL:     EQU 31 ;(1Fh)  NASCOM T4 newline
CR:     EQU 13 ;(0Dh)  ASCII carriage return for printer output/edit buffer storage
LF:     EQU 10 ;(0Ah)  ASCII line feed for printer output
FF:     EQU 12 ;(0Ch)  ASCII form feed for printer output
NFF:    EQU 30 ;(1Eh)  NASCOM T4 clear screen
;
; T4 routine addresses
;
STRT0:  EQU 0359H
SRLOUT: EQU 005DH
CHIN:   EQU 003EH
CRT:    EQU 0C4AH
KBD:    EQU 0C4DH
MOTFLP: EQU 0051H ; *same* address in T4 and NAS-SYS!!
CURSOR: EQU 0C18H
S:      EQU 80H

; Initialised to "V" for Video, reset to "V" on error.
; ASK ORs in 0B8H to set bits 7, 5, 4, 3
; b7 to 0 when ORG encountered
;    to
; b6    0 selects silent output (tested in OPTION) see ASK
; b5 to 0 for assemble pass 2
;       1 for assemble pass 1
;         set to 1 by ASK at start of assemble command
;         tested in SYM and JR??
;
; b4 to 0 when LOAD encountered
;       1 when ORG  encountered
; b3    unused
; b2    0 selects CASSETTE output
; b1    0 selects EXT (printer) output - uses pager
; b0    0 selects VIDEO (tested in OPTION)
F1:     EQU 0
F2:     EQU 1
F3:     EQU 2
; Output line count; used for pager. Hard-coded default is 60 lines/page
F5:     EQU 3
F6:     EQU 4
F7:     EQU 5
; Just used as scratch in SAVE
F8:     EQU 6
F9:     EQU 7
ENTRY:  JP ZEN
M1:     DEFB "Z",">".S        ;Prompt
M2:     DEFB "HUH","?".S
; BS, BS, NL, CR is used at the end of a .NAS format line. When it is displayed on the screen the BS/BS erases
; over the 9th (checksum) byte. When printed or sent to tape, the checksum byte is displayed/stored
M3:     DEFB NBS,NBS,NL,CR
M5:     DEFB "EO","F".S
M7:     DEFB "OPTION",">".S
M10:    DEFB "MSG",">".S
M12:    DEFB "RSV","D".S
M14:    DEFB "FUL","L".S
M13:    DEFB "DBL."           ;DBL.SYMBOL (no terminator so falls through to M15)
M15:    DEFB "SYMBO","L".S
M16:    DEFB "OPN","D".S
M17:    DEFB "UNDE","F".S
M18:    DEFB "OR","G".S
M20:    DEFB "ME","M".S
;
; Buffer space - PR1 assumes this is in the same page as the M* messages above, which will not be true in a ROMed
; version (but it's trivial to fix at the cost of 1 byte..)
;
TBUFF:  DEFS 45 ; size of input buffer. See comments by label US3
FLAGS:  DEFB "V",0,0
        DEFB 0,0,0,0,0
;
; Various 16 bit pointer stores
;
LCT:    DEFW 0 ; Current line number (initialised to 1)
CUR:    DEFW 0 ; Start address of current line (initialised to SOFP)
TEMP:   DEFW 0
SOFP:   DEFW 2400H ; Start address of edit buffer. Space between end of ZEN and here holds symbol table.
EOFP:   DEFW 2400H ; End address of edit buffer
FEP:    DEFW 0 ; Next free address in the symbol table
STK:    DEFW 0
LBLP:   DEFW 0
PC:     DEFW 0 ; Virtual PC ($) during assembly
OBJ:    DEFW 0 ; Where to store generated code. Loaded by LOADH when pseudo-op LOAD is encountered
;
; Entry point
;
ZEN:    LD IX,FLAGS ; permanent assignment
        LD SP,STACK
        CALL TOP ; move to top of edit buffer
        CALL CLEAR ; clear screen
        LD HL,$  ; set HL to memory page 0C
        PUSH HL
        LD (STK),SP   ;save stack value after HL stashed away
        LD (IX+F1),"V"
        LD L,M1&255
        CALL CUE ; print Z> prompt and get command line. 1st char is in A, length is in C
        DEC C
        JP Z,CLEAR ; blank line - clear screen
        CP "S"     ; handle sort
        JP Z,SORT
        EX DE,HL
        LD HL,(CUR) ; @CUR=00 initially
        CP "L"      ; handle locate
        JR Z,LCTE
;
; Now check other commands
;
        PUSH HL
        PUSH DE
        PUSH BC
        LD C,1
        LD DE,TBUFF
        LD HL,COMTB
        CALL SEARCH
        JP C,E10 ; HUH? -> illegal command
        POP BC
        EX (SP),HL
        CALL ARG ; get numeric argument in BC
        LD A,B
        OR C
        JR NZ,ZN2
        INC BC ; change argument from 0 (explicit/illegal or no argument) to 1
ZN2:    POP HL
        EX (SP),HL
        RET ; end up executing the command. ??But how does the command's RET get back to the command loop
;
; Command: LOCATE: search edit buffer for string. String is in TBUF at offset 1
LCTE:   DEC C
        JP Z,E10 ; HUH? -> nothing to search for
        PUSH BC
        CALL NEXT
        POP BC
        DEC HL
        PUSH HL
LC1:    POP HL
        LD A,(HL)
        INC HL
        CP CR ; end of line in edit buffer
        CALL Z,UPDATE ; go to next line
        CALL EOF ; abort if end of edit buffer
        LD B,C ; ?save length of string to be searched for
        LD DE,TBUFF+1 ; point to string to be searched for
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
;
; Command: UP: go up N lines
UP:     CALL LAST
        JR NC,LINE
        DEC BC ; decrement N
        LD A,B
        OR C
        JR NZ,UP
        JR LINE
;
;Command: CLOSE: delete edit buffer by resetting EOFP and going to top
CLOSE:  LD HL,(SOFP)
        LD (EOFP),HL ; FALL-THROUGH
;
;Command: TOP: set line number and address to top of edit buffer
TOP:    LD HL,1
        LD (LCT),HL
        LD HL,(SOFP)
        LD (CUR),HL
        RET
;
; Command: BTM: go to bottom of edit buffer.
BTM:    DEC BC ; N=0 so loop until EOF. FALL-THROUGH
;
; Command: DOWN: go down N lines.
DOWN:   PUSH BC ; N lines
        CALL NEXT ; go down 1 line; abort if EOF
        POP BC
        CALL UPDATE ; update pointers
        DEC BC
        LD A,B
        OR C
        JR NZ,DOWN ; continue
LINE:   CALL EOF
        CALL LO
        JP PR3
;
; Command: ZAP: delete N lines.
ZAP:    PUSH HL
        PUSH BC ; N lines
        CALL LOT
        POP BC
        POP HL
        DEC BC
        LD A,B
        OR C
        JR NZ,ZAP ; continue
        JR LINE
;
; Command: QUIT: return to T4 monitor
QUIT:   LD SP,0C33H
        JP STRT0
;
; Symbol Error: Point to low byte of message
E0:     LD L,M15&255 ; FALL-THROUGH
;
; Error handling. Reset stack pointer
ER:     LD SP,(STK)
        CALL ERR2 ; set output to Video
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
;
; Command: ENTER: Start line entry loop; quit with ".". HOW??
ENTER:  CALL LO
        EX DE,HL
        CALL USER
        CP "."
        RET Z ; Return to top-level command loop
        CALL LIN
        EX DE,HL
        CALL UPDATE
        JR ENTER
;
; Command: NEW: delete current line and ENTER. HOW??
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
        JR E3
;
; Command: WRITE: Save edit buffer in ZEN custom format. HOW??
WRITE:  LD L,M10&255 ; MSG>
        CALL CUE ; get file name from the user to TBUFF
        CALL MOTOR
        LD DE,TBUFF
        LD A,1
        CALL WR5 ; 0x01 x 8 ??followed by file name
        CALL WAIT
        LD HL,(EOFP)
        LD DE,(SOFP)
        OR A
        SBC HL,DE
        INC H
WR2:    DEC H
        JR Z,WR3
        CALL WR4
        JR WR2
;
WR3:    LD C,L
        INC C
WR4:    LD A,2
WR5:    LD B,8
WR6:    PUSH AF
        CALL SOUT
        POP AF
        DJNZ WR6
        LD A,C
        CALL WR8
WR7:    LD A,(DE)
        PUSH BC
        LD B,1
        CALL WR9
        POP BC
        ADD A,B
        LD B,A
        INC DE
        DEC C
        JR NZ,WR7
        XOR A
        SUB B
        CALL WR8
        LD A,H
        CALL WR8
        XOR A
WR8:    LD B,8
WR9:    PUSH AF
        CP 20H
        JR NC,WR10
        SET 7,A
        PUSH AF
        LD A,10H
        CALL SOUT
        POP AF
WR10:   CALL SOUT
        POP AF
        DJNZ WR9
        RET
;
; Command: READ: Load edit buffer from tape in custom ZEN format. HOW??
; Data is stored in numbered blocks, with the file name in block 1 and
; text in subsequent blocks. Lines of text are terminated LF CR but with B7
; set on the CR.

READ:   LD HL,TBUFF
        LD B,1
        CALL BLOK    ; look for block header 1 (file name) load to TBUFF
        CALL PR1     ; .. and print it
RD1:    LD HL,(EOFP) ; loaded after any existing edit buffer content
RD2:    LD B,2
        CALL BLOK    ; look for block header 2..N (source code) append to current source
        JR Z,RD3
        CALL RD4
E3:     LD L,M20&255 ; MEM -> out of memory (see comments in BL3)
        JP ERR
;
RD3:    INC B
        DJNZ RD2
RD4:    DEC HL
        LD (EOFP),HL
        DEC HL
        LD (HL),CR ; FALL-THROUGH
;
; Command: HOWBIG: report start/end of edit buffer

HOWBIG: LD HL,(SOFP)
        CALL WORD
        LD HL,(EOFP)
        CALL WORD
        JP CRLF
;
; Command: SORT: print sorted symbol table or, if argument given, all symbols that start with that character
; BUG: sorted list only prints symbols starting A-Z but a-z are also legal..

SORT:   LD HL,CRLF
        PUSH HL
        LD A,(TBUFF+1) ;search for symbols starting with this letter (CR means.. all symbols)
        PUSH AF
        CALL ASK ; prompt for output option "OPTION>"
        POP AF
        LD C,A
        CP CR
        JR NZ,SCAN ; argument present - report all symbols that start with this letter
        LD C,"A" ; no argument so do alphabetical list starting with A..
SRT2:   CALL SCAN
        INC C
        LD A,C
        CP "Z"+1 ; ..and ending with Z
        JR NZ,SRT2
        RET

; Input Char to search for in C
; HL > source buffer area (end marked with FFh)
;
SCAN:   LD HL,AEND-1
SN1:    INC HL  ;set to start
SN2:    INC HL
        LD A,(HL)
        INC A   ; FFh found?
        RET Z
        LD B,0  ;make B=count
        LD D,H  ;make DE buffer ptr
        LD E,L
SN3:    INC B
        BIT 7,(HL)
        INC HL
        JR Z,SN3  ;while char<80h
        LD A,(DE) ;get chr
        CP C      ;same as wanted?
        JR NZ,SN1 ;go for next
        DEC (IX+F9)
        JR NZ,SN4
        CALL CRLF
        LD (IX+F9),3
        PUSH DE
        CALL PAGE
        POP DE
SN4:    EX DE,HL ;DE>HL, HL>DE
        PUSH DE  ;really HL
        LD D,B   ;D=count
        LD A,8   ; why 8?
        CALL NAME
        POP HL   ;get back HL
        LD E,(HL);set DE
        INC HL
        LD D,(HL)
        EX DE,HL ;word value to HL
        CALL WORD ;print word
        EX DE,HL  ;source ptr to HL
        JR SN2
;
; Command table. L and S are handled separately because they can take a string argument. All the other
; commands are in a table of subroutines here. They each take no arguments or a numeric argument.

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
;
EOF:    PUSH DE
        EX DE,HL
        LD HL,(EOFP)
        DEC HL
        OR A
        SBC HL,DE
        EX DE,HL
        POP DE
        RET NC
        LD L,M5&255 ; EOF
ERR:    LD SP,(STK) ; reset stack pointer
ERR2:   LD (IX+F1),"V" ; set output to Video
        JP PR2
;
;Output space and conditionally a delay if Serial out
;convert control chars, add new line etc
;
SPACE:  LD A,20H
OUTPUT: BIT 1,(IX+F1)
        JR Z,EXT      ; output to EXT (Printer)
        BIT 2,(IX+F1)
        JR Z,SOUT     ; output to Cassette
VDU:    RES 7,A       ; must Video. Strip top bit if any
        CP LF
        RET Z           ; if LF exit
        CP CR
        JR NZ,VID3      ; output without LF
        LD A,NL         ; add LF
VID3:   JP CRT
;
KI:     CALL KBD        ; scan for key
        JR NC,KI        ; and wait until key
        RES 7,A         ; reset any top bit
        CP NL           ; if T4 new line..
        RET NZ
        LD A,CR         ; ..replace with CR
        RET
;
SIN:    JP CHIN     ; fixed JP to CHIN
;
EXT:    RES 7,A   ;ensure no bit 7 set
        NOP           ;patched to NOP?
        NOP
        NOP
        CP NFF        ; check T4 FF
        JR NZ,EXT2
        LD A,FF       ; make form feed
EXT2:   NOP      ; space for user to patch in code to
        NOP      ; drive EXTERNAL device (printer)
        NOP      ; .. in this case it just falls through
        NOP      ; to serial output (aka CASSETTE)
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
        NOP
SOUT:   JP SRLOUT
;
; Print prompt message @(HL) (well, L; H is implied) then fall through
CUE:    CALL STRING ; FALL-THROUGH
;
; Point to text input buffer and accept line of input from user, terminated by CR. Handle
; backspace. Return with A=1st character in buffer.
USER:   LD HL,TBUFF
        LD BC,0 ; C=offset in buffer OPTIMISE: B is unused
US1:    CALL KI ; get input character (replaces NASCOM NL with CR)
        LD (HL),A ; store in buffer
        CP NBS ; NASCOM back-space
        JR NZ,US2
        DEC C ; handle backspace: reduce count
        JP M,USER ; tried to go past start of buffer; reset/restart
        DEC HL ; back up in buffer
        JR US4 ; continue
;
US2:    CP CR
        JR NZ,US3
        INC C ; count the character
        CALL CRLF ; do CRLF rather than just echoing the CR
        LD A,(TBUFF) ; get 1st character in A
        RET ; done
;
US3:    LD A,C
        ; By experiment: input line accepts 43 characters then cursor sits on 44th position and only accepts
        ; backspace or CR.
        ; At the Z> prompt 1st character is entered on column 3 of 48 so 44th position is column 46 of 48.
        ; The editor prompt is a 4-digit line number + space: 1st character is entered on column 6 of 48  so the 44th
        ; position is column 49 of 48 -- ie, the line wraps and maybe scrolls. Input still works correctly.
        ; In both cases, cannot backspace over the prompt/line number, and the CR is also stored in the buffer.
        ; So, the "CP 43" here allows 44 characters to be stored in the buffer. TBUFF is 45 so the last byte is
        ; wasted/never used. (The buffer size and compare value here should be related through an EQU).

        CP 43 ;
        JR Z,US1 ; buffer is full. Ignore character
        LD A,(HL) ; all good. Restore A
        INC C ; count this character
        INC HL ; point to next location in buffer
US4:    CALL OUTPUT ; echo
        JR US1 ; and continue
;
        DEFS 48
STACK:  DEFS 2
;
; Print the contents of the text buffer, terminated by CR.
PR1:    LD L,TBUFF&255
PR2:    LD H,M1/256
PR3:    CALL STR1
CRLF:   LD A,CR
        CALL OUTPUT
        LD A,LF
        JP OUTPUT
;
RIN:    CALL SIN
        CP 10H
        RET NZ
        CALL SIN
        RES 7,A
        RET
;
; Tape load: look for and load a block. B=block number, HL=destination address
; The block number is repeated 8 times but this code does not look rugged:
; it looks for 1 instance of the block number and then simply skips the next
; 7 bytes.
BLOK:   CALL SIN
        CP B
        JR NZ,BLOK ; keep looking
        LD B,7     ; found it, skip next 7 bytes
BL2:    CALL SIN
        DJNZ BL2
        LD D,B     ; D=0 Used for accumulating checksum?
        CALL PAR
BL3:    CALL RIN   ; RIN only works on LF (0ah) if found gets next chr with bit 7 stripped
        LD (HL),A  ; store..
        CP (HL)    ; ..can we read what we read?
        RET NZ     ; no! No RAM here => out of memory
        ADD A,D
        LD D,A
        INC HL
        DJNZ BL3
        CALL PAR
        LD A,B
        ADD A,D
        LD A,"*"
        CALL NZ,OUTPUT
PAR:    LD BC,0107H
        CALL RIN
        LD E,A
PAR2:   CALL RIN
        CP E
        LD E,A
        JR NZ,PAR3
        LD B,A
PAR3:   DEC C
        JR NZ,PAR2
        RET
;
; String output: Enter with L=string offset from 0C00
;
STRING: LD H,M1/256 ; Set H to RAM base (0Ch) FALL-THROUGH
;
; String output: Enter with HL=string
;
STR1:   LD A,(HL)
        CP CR
        RET Z             ;exit on CR
        CALL OUTPUT       ;output chars while no top bit set
        BIT 7,(HL)
        INC HL
        JR Z,STR1
        RET
;
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
;
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
;
PAGE:   DEC (IX+F5)
        RET NZ
        LD A,14        ;14 lines/page for VDU
        BIT 1,(IX+F1)  ;EXT (printer) output?
        JR NZ,PG2      ;not EXT
        LD A,60        ;60 lines/page for EXT output
PG2:    LD (IX+F5),A
        CALL WAIT
        CALL C,KI
CLEAR:  LD A,NFF ; Clear screen
        JP OUTPUT
;
;Looks like a Hex to decimal convert
;Set C to input mode, hex,oct,dec
;
CONV:   DEC HL
        LD A,(HL)
        LD C,16   ;16 if Hex
        CP "H"
        JR Z,CV0
        LD C,8    ;8 if Octal
        CP "O"
        JR Z,CV0
        LD C,10   ;Else default to Decimal
        INC B     ;correct for next
CV0:    DEC B     ;come with with C=number base
        LD HL,0   ;accumulator
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
        LD E,L    ;HL=0 first time round
        LD D,H    ;else value from previous
        BIT 1,C   ;01000000 =2
        JR NZ,CV3
        LD DE,0
        BIT 3,C   ;00010000 =8
        JR NZ,CV3
        ADD HL,HL ;only add if C not 2 or 8
;
CV3:    ADD HL,HL  ;x2
        ADD HL,HL  ;x4
        ADD HL,DE  ;x5
        ADD HL,HL  ;x10
        LD E,A     ; next value
        LD D,0     ;make 16 bit
        ADD HL,DE  ;add it
        POP DE     ;restore buffr
        RET C      ;done on cy
        INC DE     ;next
        DJNZ CV1   ;loop
        RET
;
TOF:    PUSH DE
        EX DE,HL
        LD HL,(SOFP)
        OR A
        SBC HL,DE
        EX DE,HL
        POP DE
        RET
;
MOTOR:  CALL MOTFLP
        LD HL,MOTFLP
        EX (SP),HL
        PUSH HL
WAIT:   PUSH BC
        LD B,12
WT1:    LD C,2
WT2:    LD DE,(CURSOR)
        LD A,(DE)
        XOR 7FH
        LD (DE),A
        LD DE,8000
WT3:    DEC DE
        LD A,D
        OR E
        JR NZ,WT3
        DEC C
        JR NZ,WT2
        CALL KBD
        JR C,WT4
        DJNZ WT1
WT4:    POP BC
        RET
;
; Increment HL to move to end of current line in edit buffer. Count line length in BC
; Abort if at bottom of buffer
NEXT:   CALL EOF
        LD BC,0
NX1:    LD A,(HL)
        INC HL
        INC BC
        CP CR
        JR NZ,NX1
        RET
;
LO:     PUSH HL
        PUSH BC
        LD HL,TBUFF+33
        PUSH HL
        LD B,5
LO1:    LD (HL),20H ; clear 5 bytes to "space"
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
;
;Output HL as four Hex digits
;
WORD:   LD A,H  ;this is equivalent to TBCD3 in Nascom
        CALL BYT
        LD A,L
BYTE:   PUSH HL
        LD HL,SPACE
        EX (SP),HL
BYT:    PUSH AF ;this is B2HEX
        RRCA
        RRCA
        RRCA
        RRCA
        CALL NYB
        POP AF
NYB:    AND 0FH ;this is B1HEX
        ADD A,90H
        DAA
        ADC A,40H
        DAA
        JP OUTPUT ; end up here 4 times; tail recurse.
;
; HL=start of next line; update CUR and increment line number. Leave HL unchanged
UPDATE: LD (CUR),HL
LINC:   PUSH HL
        LD HL,(LCT)
        INC HL
        LD (LCT),HL
        POP HL
        RET
;
; Table lengths
;
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
; Register Pair Idents
IBC:    EQU 0
IDE:    EQU 2
IHL:    EQU 4
IAF:    EQU 0EH
ISP:    EQU 6
; Register Identifiers
IB:     EQU 0
IC:     EQU 1
ID:     EQU 2
IE:     EQU 3
IH:     EQU 4
IL:     EQU 5
IA:     EQU 7
; Index registers
IIX:    EQU 0DDH
IIY:    EQU 0FDH
; special registers
IREF:   EQU 8
IINT:   EQU 0
; Condition Code Idents
ICY:    EQU 18H
INCY:   EQU 10H
IZ:     EQU 8
INZ:    EQU 0
IPO:    EQU 20H
IPE:    EQU 28H
IMIN:   EQU 38H
IPOS:   EQU 30H
; Parser Exit Tokens
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
; Intermediate Tokens
TALPHA: EQU 30H
TLAB:   EQU 31H
TOPD:   EQU 32H
TCOM:   EQU 33H
TIND:   EQU 34H
; Arithmetical
TADD:   EQU 40H
TSUB:   EQU 0C0H
TMUL:   EQU 80H
TDIV:   EQU 81H
TAND:   EQU 82H
TOR:    EQU 83H
TDEF:   EQU 35H
TLIT:   EQU 36H
;
; Command: Assemble.
ASMB:   CALL ASK
        LD HL,AEND+1
        LD (HL),0FFH  ; Insert end-of-symbol-table marker to delete any symbols from previous assembly
        LD (FEP),HL   ; and reset next-free-location pointer
        CALL PASS     ; Do 1st pass; then fall-through to do 2nd pass
        RES 5,(IX+F1) ;F1=0 b5=0 => pass2
        CALL OPTION   ;set flags from F1
        CALL NZ,MOTOR ;only if cassette output
PASS:   CALL TOP      ; move to start of edit buffer
PS1:    LD HL,(CUR)   ; process one line
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
        JR NZ,E1 ; non alpha
        CALL OPTSCH
        JR C,E1
        LD (IX+F6),C
        CALL JUMP
        JP NZ,E6
        CALL PARSER
        CP TCR
        JR NZ,E1
PS2:    POP HL
        CALL OPTION ; set flags based on F1
        CALL C,LIST; video or ext output
        CALL LINC
        INC B
        JR NZ,PS1 ; do next line
        RET
E1:     LD L,M2&255
        JP ER
;
; Output device? Options are
; <nothing> (fastest)
; V - video
; C - cassette (NAS format hex-dump style)
; E - external
; ..but there is no checking here.. the option used seems to be
; simply dependent on some bit masks
;       7654 3210
; cr 0D 0000.1101           1011.1101
; V  56 0101.0110 -> or B8  1111.1110
; C  43 0100.0011           1111.1011
; E  45 0100.0101           1111.1101
; **PORTABILITY: if interface gave different line ending
; would it still work.. in this case, the input routine is
; swapping NASCOM T4 line ending to 0D so, yes, it would.
ASK:    LD L,M7&255
        CALL CUE
        OR 0B8H
        LD (IX+F1),A
        LD (IX+F5),1 ; set pager line count to 1
        LD (IX+F9),1
        RET
SYM:    SET 1,(IX+F2)
        INC C
        LD (IX+F7),C
        DEC C
        JP Z,E0       ; SYM error
        CALL OPDSCH
        JR NC,E2 ; RESVD error
        CALL OPTSCH
        JR NC,E2 ; RESVD error
        CALL SYMSCH
        LD (LBLP),IY
        BIT 5,(IX+F1)
        JR Z,SY2 ; Pass 2 ??symbols must be resolved
        LD L,M13&255 ; Duplicate symbol?
        JP NC,ER
        LD HL,(FEP)
        PUSH HL
        LD B,0
        ADD HL,BC
        INC HL
        INC HL
        INC HL
        CALL TOF
        LD L,M14&255 ; Symbol table full
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
        LD (FEP),HL  ;mark end of symbol table
SY2:    JP CLASS
;
E2:     LD L,M12&255
        JP ER
;
; Jump table process
;
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
        CP 39           ; entries in JPTAB are split here between code addresses and data table addresses??
        JP C,PARSER     ; ?? TAB entry.. do a 2nd level of decode??
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
;
; Every operator in KEYTB and friends, has an associated entry in this table. The
; comments show which operators use which entry.
; Operators marked thus' have MSB set on 1st byte.
; Offsets 0-38 are subroutines. Offsets 40-56 are additional lookup tables.
; Some of these entries are code/subroutines, others are data tables. ??How does the lookup know which are which?
JPTAB:  DEFW MOFB    ; 0  NOP, HALT, CCF, CPL, DAA, DI, SCF, EXX, EI, RLCA, RLA, RRCA, RRA,
        DEFW L30     ; 2  NEG, LDI, LDIR, LDD, LDDR, CPI, CPIR, CPD, CPDR, INI, INIR, IND,
                     ;    INDR, OUTI, OTIR, OUTD, OTDR, RLD, RRD, RETI, RETN,
        DEFW ENDH    ; 4  END
        DEFW RSTH    ; 6  RST
        DEFW RETH    ; 8  RET'
        DEFW PPH     ; 10 PUSH, POP
        DEFW JRH     ; 12 JR'
        DEFW DJH     ; 14 DJNZ, RCAL
        DEFW INCH    ; 16 DEC,
        DEFW ML1     ; 18 XOR, AND, CP, SUB, SCAL, OR
        DEFW SRH     ; 20 SLA, SRA, SRL, RL, RLC, RR, RRC,
        DEFW BITH    ; 22 BIT, SET, RES
        DEFW DWH     ; 24 DEFW
        DEFW DBH     ; 26 DEFB
        DEFW DSH     ; 28 DEFS
        DEFW EQUH    ; 30 EQU
        DEFW ORGH    ; 32 ORG
        DEFW IMH     ; 34 IM
        DEFW RDH     ; 36 ?? does not seem to be referenced but there is code at RDH..
        DEFW LOADH   ; 38 LOAD

        ; remaining entries are data, not code.
        DEFW LTAB    ; 40 LD
        DEFW CALTAB  ; 42 CALL'
        DEFW JMPTAB  ; 44 JP'
        DEFW XTAB    ; 46 EX
        DEFW INTAB   ; 48 IN
        DEFW ADDTAB  ; 50 ADD
        DEFW ADCTAB  ; 52 ADC
        DEFW SBCTAB  ; 54 SBC
        DEFW OUTAB   ; 56 OUT
;
; List 1 line to selected output devices
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
;
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
;
NAME:   INC D
        SUB D
        PUSH AF
NM2:    DEC D
        JR Z,NM3
        LD A,(HL)
        CALL OUTPUT
        INC HL
        JR NM2
;
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
;
SYMSCH: LD HL,AEND+1 ; start of symbol table
        JR SEARCH
;
OPDSCH: LD HL,CCST
        BIT 3,(IX+F2)
        JR Z,SEARCH
        LD HL,REGS
        JR SEARCH
;
; Search for operator.
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
;
; Part of SEARCH. The current entry in the table does not match the string;
; Get to the start of the next entry in the table (move to the end of the string (MSB set)
; then step over the 2 data bytes) and restore DE (what we're searching for).
BAD:    BIT 7,(HL) ;check high char
        INC HL     ;next
        JR Z,BAD   ;step over search string
        INC HL     ;skip over next 2 bytes
        INC HL
        POP DE     ;restore pointer to search string -- FALL-THROUGH to SEARCH
;
; Search data structure. Used to search
; - COMTB (command table)
; - Symbol table
; - KEYTB, LOPS, COPS etc. (operators)
; - CCST (condition codes - and registers)
; Each table entry is:
; - a string; one or more characters, MSB set on last byte
; - 2 bytes (for COMTB this is the execution address, for KEYTB and friends it's more complicated)
; Table is terminated by FFH
;
; on entry: HL = address of table to search
;           DE = address of thing to search for
;           C  = number of bytes to match @(DE)
; on exit:  Not found: Carry set
;           Found: HL = 2 bytes from found entry in table
;                  IY = address of last byte from found entry in table
;           AF is not preserved
;           DE is     preserved
SEARCH: LD A,(HL)  ;check table entry
        INC A      ;FFh found ?
        SCF        ;set carry
        RET Z      ;FF => end of table. Exit with cy
        PUSH DE    ;save buffer
        LD B,C     ;get length
SC2:    LD A,(DE)  ;get char
        DJNZ SC3   ;decr count
        SET 7,A    ;set
SC3:    INC B      ;correct count
        CP (HL)    ;compare
        JR NZ,BAD  ;not found
        INC DE     ;move up buffer
        INC HL     ;and table
        DJNZ SC2   ;loop for rest
        LD E,(HL)  ;get lsb addr
        INC HL     ;point to msb
        LD D,(HL)  ;get it
        EX (SP),HL ;table ptr to stack, recover preserved DE
        EX DE,HL   ;DE as on entry, HL is 2 bytes found from table
        POP IY     ;address of last byte of found entry
        RET
;
; Set flags based on value of F1
OPTION: LD A,(IX+F1)
        XOR 32     ;Clear C. toggle b4 => LOAD encountered??
        BIT 5,A
        RET Z      ;return with Z if doing assembly pass 2
        BIT 6,A
        RET Z      ;return with Z if silent (no output)
        SCF
        BIT 0,A
        RET Z      ;return with Z and C if video output
        BIT 1,A
        RET Z      ;return with Z and C if ext (printer) output
        OR A
        RET        ;return NZ, NC if cassette output
;
RESOLV: CP NO
        JR NZ,E6 ; OPND?
        LD A,(IX+F2)
        BIT 4,A
        JP NZ,E7 ; UNDEF?
        BIT 1,A
        RET
;
LITLE:  CP NO
        JR NZ,E6
LITLE2: BIT 5,(IX+F1)
        RET NZ ;return if in assembly pass 1
        LD A,H
        OR A
        RET Z
E6:     LD L,M16&255 ; OPND?
        JP ER
;
; Memory/Object output ??what byte
MOFMIX: LD E,L
MOFMX2: BIT 3,E
        JR NZ,E6
        LD A,E
        RLCA
        RLCA
        RLCA
        OR B
        JR MOF
;
; Memory/Object output prefix byte (0EDH)
MOFPRE: LD A,0EDH
        JR MOF
;
; Memory/Object output values in L and H
MOFLH:  LD A,L
        CALL MOF ; FALL-THROUGH
;
; Memory/Object output value in H
MOFH:   LD A,H
        JR MOF
;
; Memory/Object output value in B
MOFB:   LD A,B ; FALL-THROUGH
;
; Memory/Object output value in A
MOF:    PUSH HL
        CALL CL2
        INC HL
        LD (PC),HL
        BIT 4,(IX+F1)
        JR NZ,MOF2 ; No LOAD statement
        LD HL,(OBJ)
        LD (HL),A ; store byte
        INC HL ; and increment
        LD (OBJ),HL
MOF2:   POP HL
SAVE:   PUSH HL
        PUSH DE
        PUSH BC
        LD D,A
        CALL OPTION
        JR C,SV2 ; video or EXT output
        JR Z,SV3 ; silent (no output)
        LD BC,(FLAGS+F8) ; cassette output: NAS-format object dump
        DJNZ SV1
        LD HL,(PC)
        DEC HL
        LD A,L
        ADD A,H
        LD C,A
        LD B,8 ; 8 bytes
        CALL WORD ; emit address
SV1:    LD A,D
        ADD A,C
        LD C,A
        LD (FLAGS+F8),BC
        LD A,D
        CALL BYTE ; emit byte
        DJNZ SV3
        LD A,C
        CALL BYT ; emit checksum byte??
        LD L,M3&255
        CALL STRING ; end of .NAS format line for object code dump
        JR SV3
;
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
;
PARSER: BIT 0,(IX+F2)
        LD A,TCR
        RET NZ
        PUSH BC
        CALL PA1
        POP BC
        RET
;
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
;
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
;
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
;
PA6:    POP AF
        RET
;
; 16-bit Maths/Logic routines
; token for op is in A. Operands in HL, DE. Return in HL
; op is one of TADD, TSUB, TMUL, TDIV, TAND, TOR else error "OPND?"
;
MATH:   CP TADD  ;Add?
        JR NZ,MA2
        ADD HL,DE
        RET
;
MA2:    CP TSUB  ;Sub?
        JR NZ,MA3
        SBC HL,DE
        RET
;
MA3:    CP TAND  ;And?
        JR NZ,MA4
        LD A,E
        AND L
        LD L,A
        LD A,D
        AND H
        LD H,A
        RET
;
MA4:    CP TOR  ;Or?
        JR NZ,MA5
        LD A,E
        OR L
        LD L,A
        LD A,D
        OR H
        LD H,A
        RET
;
MA5:    LD C,E
        LD B,D
        EX DE,HL
        CP TDIV  ;81h
        JR NZ,MA6
;
; Do Divide
;
MA50:   LD HL,0
        LD A,17
        OR A
MA51:   ADC HL,HL
        SBC HL,BC
        JR NC,MA52 ;no overflow
        ADD HL,BC
        SCF
MA52:   CCF
        RL E
        RL D
        DEC A
        JR NZ,MA51
        EX DE,HL
        RET
;
; Do Mult
;
MA6:    CP TMUL
        JR NZ,PER ; out of options. PER-> E6 "OPND?" error
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
;
; Other type tokens
;
TERM:   CALL CLASS
        CP TLAB
        JP Z,E6   ;error
TE2:    CP TCR
        JR NZ,TE3
        SET 0,(IX+F2)
        SCF
        RET
;
TE3:    CP TCOM   ;comment?
        SCF
        RET Z
        CP TALPHA
        SCF
        CCF
        RET NZ
        CALL OPDSCH
        LD A,TOPD
        RET NC ; A=TOPD shows that a condition code/register was found
        CALL SYMSCH
        LD A,NO
        RET NC ; A=NO shows that a match was found in the symbol table
        CCF
        SET 4,(IX+F2)
        BIT 5,(IX+F1)
        RET NZ ; return if assembly Pass 1
E7:     LD L,M17&255 ; UNDEF?
        JP ER
;
; process instruction type
; ??return with a code address in IY (caller does JP (IY))
TYPE:   LD HL,(CUR) ;current location
        CALL EOF         ;check NOT Eof
        INC HL
        LD (CUR),HL      ;set new current location
        DEC HL           ;point to last
        LD A,(HL)        ;get value
        LD IY,TYPTAB     ;point to type table
FIND:   PUSH DE          ;save DE
        PUSH IY          ;put IY to stack
        EX (SP),HL       ;into HL
        LD E,(HL)        ;get value from IY
        LD D,E           ;set MSB
FIN1:   INC HL
        CP (HL)          ;found ?
        JR Z,FIN2        ;yes
        DEC D            ;check count
        JR NZ,FIN1       ;not yet
FIN2:   LD D,0           ;set msb=0
        ADD HL,DE        ;add offset
        LD A,(HL)        ;get value
        ADD HL,DE        ;add offset
        LD E,A           ;save in E
        LD A,(HL)        ;get value
        BIT 7,E          ;test top bit set Z?
        RES 7,E          ;reset it
        ADD HL,DE        ;add offset
        EX (SP),HL       ;set to stack
        POP IY           ;restore regs
        POP DE
        RET              ;exit with Z?
;
; set 8 bit offset to access routines
; by type  TL: EQU 10h == number of entries, including the terminating 0
; eg: CR processed by CL3
;     '  processed by CL4
;     $  processed by CL2
;     */+-&.( processed by CL3
;     ) processed by CLASS
;
; Each entry i
;
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
;
        DEFB TCR,0,NO,TMUL,TDIV
        DEFB TADD,TSUB,TAND,TOR
        DEFB TIND,0,0,TLAB
        DEFB 0,TCOM,TDEF
;
; Class operation types
;
CLASS:  CALL TYPE
        LD BC,2100H
        JP (IY)
;
; exit when TCR found
;
CL1:    CALL TYPE
        CP TCR
        JR NZ,CL1
CL3:    RET
;
CL2:    LD HL,(PC)
        BIT 7,(IX+F1) ; Have we encountered ORG?
        RET Z         ; yes, all is OK
E11:    LD L,M18&255  ; no, origin error
        JP ER
;
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
;
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
;
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
;
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
        JR NZ,DJ2 ; assemble Pass 1 so don't try to resolve; emit anything?
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
        JP MOF ; emit branch destination byte
;
DWH:    CP NO
        RET NZ
        JP MOFLH
;
DBH:    CP TLIT
        JR NZ,DBH3
DBH1:   INC DE
        LD A,(DE)
        CALL MOF
        DEC H
        JR NZ,DBH1
        JR DBH4
;
DBH3:   CALL LITLE
        LD A,L
        CALL MOF
DBH4:   CALL PARSER
        CP TCR
        JR NZ,DBH
        RET
;
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
;
LOADH:  CALL RESOLV
        LD (OBJ),HL
        RES 4,(IX+F1) ; LOAD is OK??
        XOR A
        RET
;
ORGH:   CALL RESOLV
        LD (PC),HL
        SET 4,(IX+F1) ; LOAD is not OK (LOAD is reset by an ORG - see manual)
        RES 7,(IX+F1) ; ORG encountered
        CALL NZ,EQ2
ENDH:   CALL OPTION
        RET Z
FILL:   LD A,(IX+F9)
        DEC A
        JR Z,FILL2
        CALL SAVE
        JR FILL
;
FILL2:  LD A,B
        OR A
        RET Z
        LD A,"."
        CALL OUTPUT
        LD A,NL
        CALL OUTPUT
        XOR A
        RET
;
EQUH:   CALL RESOLV
        JP Z,E0
EQ2:    EX DE,HL
        LD HL,(LBLP)
        LD (HL),D
        DEC HL
        LD (HL),E
        XOR A
        RET
;
LTAB:   DEFB LL         ; LL=21, the number of entries that follow including the 0
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
;
;absolute byte value calculated from
;(higher order bytes (>7Fh)
;routine addr(Ln)-table addr-fixed offset LL(15h)+80h
;(lower order bytes) (<80h)
;routine addr(Ln)-table addr-fixed offset LL(15h)
;
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
;
        DEFB 16H,6,47H,57H,40H
        DEFB 0F9H,22H,2AH,21H,32H
        DEFB 3AH,22H,2AH,0F9H,36H
        DEFB 1,2,0AH,2,0AH,0
;
L1:     LD A,E
        CP IHL
        RET NZ
L2:     CALL LITLE2
        CALL MOFMX2
        LD A,L
L21:    JP MOF
;
L3:     BIT 2,E
        JR Z,LER
        LD A,L
        OR B
        LD B,A
L30:    CALL MOFPRE
L31:    JP MOFB
;
L4:     LD A,L
        OR B
        LD B,A
        JP MOFMX2
;
L5:     CP ISP*16.IHL
        RET NZ
        JR L31
;
L6:     LD A,E
L61:    CALL MOF
L62:    CALL MOFB
L63:    JP MOFLH
;
L7:     BIT 2,E
        JR NZ,L62
LER:    JP E6
;
L8:     LD A,E
        CP IHL
        JR Z,L62
        CALL MOFPRE
        LD A,B
        XOR 61H
        LD B,A
        CALL MOFMX2
        JP MOFLH
;
L9:     LD A,E
        CP ISP
        RET NZ
        LD H,B
        JR L63
;
LA:     CALL LITLE2
        LD A,D
        LD H,L
        LD L,E
        JR L61
;
LB:     CALL MOFMX2
        JR L63
;
LC:     CALL MOFH
        CALL LE1
        LD A,L
        JR L21
;
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
;
RSTH:   CALL LITLE
        JR NZ,RST2
        LD A,L
        AND B
        RET NZ
RST2:   LD A,B
        OR L
        JP MOF
;
RETH:   CP CC
        JR Z,RST2
        LD B,0C9H
        CP TCR
        JR JMP21
;
JMPTAB: DEFB JL
        DEFB XYI*16.TCR
        DEFB RPI*16.TCR
        DEFB 0
        DEFB JMP1-$-JL
        DEFB JMP2-$-JL
        DEFB JMP3-$-JL
        DEFB 0E9H,0E9H,0C3H
;
JMP1:   LD H,B
        JP MOFLH
;
JMP2:   LD A,L
        CP IHL
JMP21:  RET NZ
        JP MOFB
;
CALTAB: DEFB CL   ; =1
        DEFB  0
        DEFB JMP3-$-CL
        DEFB 0CDH
;
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
;
PPH:    CP RP
        JR NZ,PP2
        LD A,L
        CP ISP
        JP Z,E6
        RES 3,L
        JP MOFMIX
;
PP2:    CP XY
        RET NZ
PP21:   SET 5,B
        LD H,B
        JP MOFLH
;
IMH:    CALL LITLE
        JR NZ,IM2
        LD A,2
        SUB L
        RET C
IM2:    LD DE,IMTAB
        ADD HL,DE
        LD B,(HL)
        JP L30
;
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
;
ADCTAB: DEFB AL
        DEFB RP*16.RP
        DEFB 0
        DEFB DL1-$-AL
        DEFB DL5-$-AL.S
        DEFB 4AH,8EH
;
SBCTAB: DEFB SBL
        DEFB RP*16.RP
        DEFB 0
        DEFB DL1-$-SBL
        DEFB DL5-$-SBL.S
        DEFB 42H,9EH
;
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
;
RDH:    LD E,L
DL1:    CALL MOFPRE
DL2:    LD A,L
        CP IHL
        RET NZ
        JP MOFMX2
;
DL3:    LD A,E
        CP IHL
        JP Z,E6
        LD A,L
        CALL MOF
        JP MOFMX2
;
DL4:    LD A,E
        CP L
        LD H,B
        RET NZ
        JP MOFLH
;
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
;
ML2:    CP XYD
        JR NZ,ML3
        CALL MOFH
        JR ML12
;
ML3:    CP RPI
        JP Z,JMP2
        OR A
        RET NZ
        LD A,B
        AND 0F8H
        OR L
        JP MOF
;
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
;
SR2:    PUSH AF
        LD A,0CBH
        CALL MOF
        POP AF
        JR ML3
INTAB:  DEFB INL ; =3
        DEFB TR*16.NOI
        DEFB TR*16.RI
        DEFB 0
;
        DEFB IO1-$-INL.S
        DEFB IO2-$-INL.S
        DEFB IOER-$-INL
        DEFB 0DBH,40,0
;
OUTAB:  DEFB OL ; =3
        DEFB NOI*16.TR
        DEFB RI*16.TR
        DEFB 0
;
        DEFB IO1-$-OL
        DEFB IO2-$-OL
        DEFB IOER-$-OL
        DEFB 0D3H,41H,0
;
IO1:    BIT 2,E
        JR Z,IOER
        JP ML11
;
IO2:    CALL MOFPRE
        DEC L
        JP Z,MOFMX2
IOER:   JP E6
;
XTAB:   DEFB XL ; =4
        DEFB RP*16.RP
        DEFB RPI*16.RP
        DEFB RPI*16.XY
        DEFB 0
;
        DEFB X1-$-XL
        DEFB X2-$-XL
        DEFB X3-$-XL.S
        DEFB XER-$-XL
        DEFB 0EBH,0E3H,0E3H,0
;
X1:     CP IDE*16.IHL
        JP Z,MOFB
        LD B,8
        CP IAF*16.IAF
        JP Z,MOFB
XER:    JR IOER
;
X2:     JP L5
;
X3:     JP L9
;
; Condition codes
CCST:   DEFB "C".S,ICY,CC
        DEFB "N","C".S,INCY,CC
        DEFB "Z".S,IZ,CC
        DEFB "N","Z".S,INZ,CC
        DEFB "P".S,IPOS,CC
        DEFB "M".S,IMIN,CC
        DEFB "P","O".S,IPO,CC
        DEFB "P","E".S,IPE,CC
;
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
;
; 2-level list of operators. LOPS is all the operators starting with L, and so on. This is followed
; by a list of left-overs, which don't have a table of their own (JP, JR and so on). The order of the
; tables and of entries within a table should be chosen to put most-frequently-used first, to speed
; up the searches. Each entry ends with MSB set and two trailing bytes:
;
; - first byte is an offset into JMPTAB (sometimes MSB is set; it's stripped off to select the JMPTAB entry)
; - second byte is used as an argument for that JMPTAB code -- part of the op-code?
;
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
        DEFB 0FFH ; End of KEYTB, start of misc.
;
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
;
; "L"
;
LOPS:   DEFB "D".S,40,0         ;LD
        DEFB "OA","D".S,38,0    ;LOAD
        DEFB "D","I".S,2,0A0H   ;LDI
        DEFB "DI","R".S,2,0B0H  ;LDIR
        DEFB "D","D".S,2,0A8H   ;LDD
        DEFB "DD","R".S,2,0B8H  ;LDDR
        DEFB 0FFH
;
; "C"
;
COPS:   DEFB "AL","L".S,42.S,0  ;CALL
        DEFB "P".S,18,0BEH      ;CP
        DEFB "C","F".S,0,3FH    ;CCF
        DEFB "P","L".S,0,2FH    ;CPL
        DEFB "P","I".S,2,0A1H   ;CPI
        DEFB "PI","R".S,2,0B1H  ;CPIR
        DEFB "P","D".S,2,0A9H   ;CPD
        DEFB "PD","R".S,2,0B9H  ;CPDR
        DEFB 0FFH
;
; "D"
;
DOPS:   DEFB "E","C".S,16,0BH   ;DEC
        DEFB "JN","Z".S,14,10H  ;DJNZ
        DEFB "EF","B".S,26,0    ;DEFB
        DEFB "EF","W".S,24,0    ;DEFW
        DEFB "EF","S".S,28,0    ;DEFS
        DEFB "A","A".S,0,27H    ;DAA
        DEFB "I".S,0,0F3H       ;DI
        DEFB 0FFH
;
; "I"
;
IOPS:   DEFB "N","C".S,16,3     ;INC
        DEFB "M".S,34,0         ;IM
        DEFB "N".S,48,0         ;IN
        DEFB "N","I".S,2,0A2H   ;INI
        DEFB "NI","R".S,2,0B2H  ;INIR
        DEFB "N","D".S,2,0AAH   ;IND
        DEFB "ND","R".S,2,0BAH  ;INDR
        DEFB 0FFH
;
; "S"
;
SOPS:   DEFB "B","C".S,54,0     ;SBC
        DEFB "C","F".S,0,37H    ;SCF
        DEFB "L","A".S,20,26H   ;SLA
        DEFB "R","A".S,20,2EH   ;SRA
        DEFB "R","L".S,20,3EH   ;SRL
        DEFB "E","T".S,22,0C6H  ;SET
        DEFB "U","B".S,18,96H   ;SUB
        DEFB "CA","L".S,18,0DFH ;SCAL special for NASCOM
        DEFB 0FFH
;
; "O"
;
OOPS:   DEFB "R".S,18,0B6H      ;OR
        DEFB "R","G".S,32,0     ;ORG
        DEFB "U","T".S,56,0     ;OUT
        DEFB "UT","I".S,2,0A3H  ;OUTI
        DEFB "TI","R".S,2,0B3H  ;OUTIR
        DEFB "UT","D".S,2,0ABH  ;OUTD
        DEFB "TD","R".S,2,0BBH  ;OUTDR
        DEFB 0FFH
;
; "E"
;
EOPS:   DEFB "X".S,46,0         ;EX
        DEFB "X","X".S,0,0D9H   ;EXX
        DEFB "Q","U".S,30,0     ;EQU
        DEFB "I".S,0,0FBH       ;EI
        DEFB "N","D".S,4,0FFH   ;END assembler directive
        DEFB 0FFH
;
; "R"
;
ROPS:   DEFB "E","T".S,8.S,0C0H ;RET
        DEFB "S","T".S,6,0C7H   ;RST
        DEFB "E","S".S,22,86H   ;RES
        DEFB "L".S,20,16H       ;RL
        DEFB "L","C".S,20,6     ;RLC
        DEFB "LC","A".S,0,7     ;RLCA
        DEFB "L","A".S,0,17H    ;RLA
        DEFB "R".S,20,1EH       ;RR
        DEFB "R","C".S,20,0EH   ;RRC
        DEFB "RC","A".S,0,0FH   ;RRCA
        DEFB "R","A".S,0,1FH    ;RRA
        DEFB "L","D".S,2,6FH    ;RLD
        DEFB "R","D".S,2,67H    ;RRD
        DEFB "ET","I".S,2,4DH   ;RET
        DEFB "ET","N".S,2,45H   ;RETN
        DEFB "CA","L".S,14,0D7H ;RCAL special for NASCOM

; The first FF marks the start of the symbol table. The second FF marks the end
; (ie, this is pre-initialised as an empty symbol table). An entry in the symbol table is:
; - a string with the MSB set on the last byte, followed by
; - 2 bytes showing the address of the symbol
; ??why is there a need to mark the *start*? surely the symbol table is only searched
; linearly from start to end.. wasted byte or undetected cunning?
;
AEND:   DEFB 0FFH
        DEFB 0FFH
        END
