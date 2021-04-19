;----------------------------------------------
;
;	PolyDos 2 (Version ??)
;       PolyDos Controller ROM
;
;       By Anders Hejlsberg
;       Copyright (C) 1982
;       Poly-Data microcenter ApS
;
;----------------------------------------------

;;	REFS	SYSEQU
;;	REF
        include "SYSEQU.asm"

SCAL:   MACRO FOO
        RST 18H
        DB FOO
        ENDM

;; the RCAL pseudo-op is not documented in the polyzap manual..
RCAL:   MACRO FOO
        RST 10H
        DB FOO - $ - 1
        ENDM

;; the HIGH() function is not documented in the polyzap manual


;;; 4 virtual drives, 0-3.
MAXDRV:	EQU	4
FFLP:	EQU	0045H

;;; I/O ports (special for NASCOM 4)
SDDATA: EQU     $10
SDCTRL: EQU     $11
SDLBA0: EQU     $12
SDLBA1: EQU     $13
SDLBA2: EQU     $14

;;; SDcard commands
SDWR:   EQU     $1
SDRD:   EQU     $0

	ORG	PDCROM
;;[NAC HACK 2018Mar30] defines the load and execute address
;;	IDNT	$,$


;----------------------------------------------
; Here on power-up or RESET
;----------------------------------------------

	JP	$+3		;RESET jump
	LD	SP,STACK	;Set SP
	CALL	STMON		;Initialize NAS-SYS
	RST	PRS		;Prompt user
	DB	'PolyDos local SD. Boot which drive? ',0

PDC1:	SCAL	ZBLINK		;Get drive number
	cp	'N'		;NAS-SYS?
	JR	NZ,PDC2		;No => skip
	RST	PRS		;Clear screen
	DB	ESC,0
	JP	5		;Go to NAS-SYS
PDC2:	CP	'0'		;Test drive number
	JR	C,PDC1
	CP	MAXDRV+'0'+1
	JR	NC,PDC1
	RST	ROUT		;Print it
	SUB	'0'		;Adjust
	PUSH	AF		;Save on stack
	LD	HL,TOP		;Initialize workspace
	LD	B,0
PDC3:	LD	(HL),0
	INC	HL
	DJNZ	PDC3
	LD	A,-1
	LD	(DDRV),A	;No directory
	LD	(DRVCOD),A	;No drive selected
	LD	(OVNAM),A	;No overlay
	LD	HL,(STAB)	;Get start addr of
	LD	DE,82H		;NAS-SYS SCAL table
	ADD	HL,DE
	LD	DE,SCTB		;Copy to SCTB
	LD	BC,3CH*2
	LDIR
	LD	HL,PDSCTB	;Get start addr of
	LD	BC,13H*2	;PolyDos SCAL table
	LDIR			;Copy to SCTB
	LD	HL,SCTBS	;Activate SCAL table
	LD	(STAB),HL
	LD	HL,PDOSW	;Modify MRET vector
	SCAL	ZSSCV
	DB	ZMRET
	LD	HL,CRT		;Modify CRT vector
	SCAL	ZSSCV
	DB	ZCRT
	LD	HL,BLINK	;Modify BLINK vector
	SCAL	ZSSCV
	DB	ZBLINK
	LD	HL,DNNIM	;Modify NNIM vector
	SCAL	ZSSCV
	DB	ZNNIM
	SCAL	ZNNIM		;Activate input table
	LD	HL,POUT		;Make printer user
	LD	(UOUTA),HL	;output device
	LD	HL,DBREAK	;Initialize BREAK jump
	LD	(BREAK),HL	;vector
	POP	AF		;Restore drive number
	LD	(MDRV),A	;Make master drive
	LD	C,A		;Put in C
	CALL	INIT		;Initialize controller
	JR	Z,PDOSW		;Skip if no error
	LD	(ERRCOD),A	;Save error code
	JP	ABORT		;Abort PolyDos


;----------------------------------------------
; MRET routine entry point
;----------------------------------------------

PDOSW:	LD	SP,STACK	;Set SP
	XOR	A		;Clear A
	SCAL	ZCOV		;Invoke Exec
	DB	'Exec'
	JR	PDOSW		;Loop if Exec returns


; Disk read
;----------------------------------------------
; Entry: HL:  Memory address
;	 DE:  Disk address
;	 B:   Number of sectors
;	 C:   Drive
; Exit:  HL:  Unchanged
;	 DE:  Unchanged
;	 BC:  Unchanged
;	 AF:  Status
;----------------------------------------------

DRD:	XOR	A		;A=0 => read
	JR	DRW


; Disk write
;----------------------------------------------
; Entry: HL:  Memory address
;	 DE:  Disk address
;	 B:   Number of sectors
;	 C:   Drive
; Exit:  HL:  Unchanged
;	 DE:  Unchanged
;	 BC:  Unchanged
;	 AF:  Status
;----------------------------------------------

DWR:	LD	A,-1		;A=-1 => write
DRW:	PUSH	DE		;Save
	PUSH	BC
	PUSH	HL
	CALL	RWSCTS		;Do read/write
	POP	HL		;Restore
	POP	BC
	POP	DE
	RET


; Read directory
;----------------------------------------------
; Entry: C:   Drive number
; Exit:  HL:  Unchanged
;	 DE:  Unchanged
;	 BC:  Unchanged
;----------------------------------------------

RDIR:	LD	A,(DDRV)	;Is directory already
	SUB	C		;there?
	RET	Z		;Yes => return
	LD	A,C		;Save as new directory
	LD	(DDRV),A	;drive number
	PUSH	BC		;Save
	PUSH	DE
	PUSH	HL
	LD	HL,DIRBUF	;Read into DIRBUF
	LD	DE,0		;From sector 0
	LD	B,4		;4 sectors
	SCAL	ZDRD		;Do the read
	POP	HL		;Restore
	POP	DE
	POP	BC
	RET	Z		;No error => return
	PUSH	HL		;Save
	LD	HL,DDRV		;Make directory invalid
	LD	(HL),-1
	POP	HL		;Restore
	RET


; Write directory
;----------------------------------------------
; Entry: No parameters required
; Exit:  HL:  Unchanged
;	 DE:  Unchanged
;	 BC:  Unchanged
;----------------------------------------------

WDIR:	PUSH	BC		;Save
	PUSH	DE
	PUSH	HL
	LD	HL,DIRBUF	;Write from DIRBUF
	LD	DE,0		;To sector 0
	LD	B,4		;4 sectors
	LD	A,(DDRV)	;On drive DDRV
	LD	C,A
	SCAL	ZDWR		;Do the write
	POP	HL		;Restore
	POP	DE
	POP	BC
	RET


; Convert a file specifier
;----------------------------------------------
; Entry: HL:  FCB address
;	 DE:  Line buffer address
;	 B:   B0=1  Name optional
;	      B1=1  Extension optional
;	      B2=1  Drive optional
; Exit:  HL:  Unchanged
;	 DE:  Next line buffer address
;	 B:   B0=1  No name
;	      B1=1  No extension
;	      B2=1  No drive
;	 C:   Drive number (MDRV if B.B2=1)
;----------------------------------------------

CFS:	PUSH	HL		;Save FCB addr
	LD	A,B		;Compute flag mask
	CPL
	AND	111B
	PUSH	AF		;Save on stack
	LD	BC,709H		;Init flags and counter
CFS1:	LD	A,(DE)		;Get character
	CP	' '		;Jump to CFS3 if it is
	JR	Z,CFS3		;a delimiter
	CP	'.'
	JR	Z,CFS3
	CP	':'
	JR	Z,CFS3
	CP	','
	JR	Z,CFS3
	CP	';'
	JR	Z,CFS3
	CP	CR
	JR	Z,CFS3
	CP	TAB
	JR	Z,CFS3
	OR	A
	JR	Z,CFS3
	RCAL	TSTCH		;Test character
	DEC	C		;8 characters done?
	JR	Z,CFS2		;Yes => skip
	LD	(HL),A		;Save in FCB
	INC	HL		;Point to next
	INC	DE
	RES	0,B		;Name specified
	JR	CFS1
CFS2:	LD	A,11H		;Error 11
	JR	CFS9
CFS3:	LD	A,C		;Get counter
CFS4:	DEC	C		;Filling done?
	JR	Z,CFS11		;Yes => skip
	CP	9		;Was name specified?
	JR	Z,CFS12		;No => skip
	LD	(HL),' '	;Blank fill
CFS12:	INC	HL		;Point to next
	JR	CFS4		;Repeat
CFS11:	LD	A,(DE)		;Get character
	CP	'.'		;Period?
	JR	NZ,CFS5		;No => skip
	INC	DE		;Point to next
	RCAL	GETCH		;Get and test
	LD	(HL),A		;Save in FEXT
	INC	HL		;Point to next
	RCAL	GETCH		;Get and test
	LD	(HL),A		;Save in FEXT
	INC	HL		;Point to next
	RES	1,B		;Extension specified
CFS5:	LD	A,(MDRV)	;Default is MDRV
	LD	C,A
	LD	A,(DE)		;Get character
	CP	':'		;Colon?
	JR	NZ,CFS6		;No => skip
	INC	DE		;Point to next
	LD	A,(DE)		;Get character
	INC	DE		;Point to next
	SUB	'0'		;Adjust
	JR	C,CFS8		;Error => skip
	CP	MAXDRV+1	;Too big?
	JR	NC,CFS8		;Yes => skip
	LD	C,A		;Put drive number in C
	RES	2,B		;Drive specified
CFS6:	LD	A,(DE)		;Skip blanks
	CP	' '
	JR	NZ,CFS7
	INC	DE
	JR	CFS6
CFS7:	POP	AF		;Get flag mask
	POP	HL		;Get FCB addr
	AND	B		;Flags ok?
	RET	Z		;Yes => return
	LD	B,12H		;Compute error code
CFS10:	INC	B
	RRA
	JR	NC,CFS10
	LD	A,B		;Put in A
	OR	A		;Indicate error
	RET
CFS8:	LD	A,12H		;Error 12
CFS9:	POP	HL		;Adjust
	POP	HL		;Get FCB addr
	OR	A		;Indicate error
	RET

GETCH:	LD	A,(DE)		;Get character
	INC	DE		;Point to next
TSTCH:	CP	21H		;Control character?
	JR	C,TCH1		;Yes => skip
	CP	80H		;Graphic character
	RET	C		;No => return
TCH1:	POP	HL		;Adjust
	LD	A,10H		;Error 10
	JR	CFS9

; Lookup file in current directory
;----------------------------------------------
; Entry: HL:  Lookup FCB address
;	 DE:  Previous directory FCB address
;	 B:   B0=1  Don't match file name
;	      B1=1  Don't match extension
;	      B4=1  Copy dir FCB to look FCB
;	      B5=1  Include locked files
;	      B6=1  Include deleted files
;	      B7=1  Not first look
; Exit:  HL:  Unchanged
;	 DE:  Directory FCB address
;	 B:   B7 set, B6-B0 unchanged
;	 C:   Unchanged
;----------------------------------------------

LOOK:	BIT	7,B		;First look?
	JR	NZ,LK1		;No => skip
	LD	DE,FCBS-20	;Start with first FCB
	SET	7,B		;Next time not first
LK1:	PUSH	HL		;Save FCB addr
LK2:	LD	HL,20		;Point to next FCB
	ADD	HL,DE
	EX	DE,HL		;Put in DE
	LD	HL,(NXTFCB)	;Done all FCBs?
	SCF
	SBC	HL,DE
	POP	HL		;(restore FCB addr)
	JR	NC,LK3		;No => skip
	LD	A,30H		;Error 30
	OR	A
	RET
LK3:	PUSH	HL		;Save lookup FCB addr
	PUSH	DE		;Save dir FCB addr
	LD	A,8		;Compare names
	RCAL	CMPS
	JR	Z,LK4		;Match => skip
	BIT	0,B		;Should they match?
	JR	Z,LK5		;Yes => skip
LK4:	LD	A,2		;Compare extensions
	RCAL	CMPS
	JR	Z,LK6		;Match => skip
	BIT	1,B		;Should thay match?
	JR	NZ,LK6		;No => skip
LK5:	POP	DE		;Restore dir FCB addr
	JR	LK2		;Try next
LK6:	LD	A,(DE)		;Locked?
	BIT	0,A
	JR	Z,LK7		;No => skip
	BIT	5,B		;Include locked files?
	JR	Z,LK5		;No => try next
LK7:	BIT	1,A		;Deleted?
	JR	Z,LK8		;No => skip
	BIT	6,B		;Include deleted files?
	JR	Z,LK5		;No => try next
LK8:	POP	DE		;Restore dir FCB addr
	POP	HL		;Restore look FCB addr
	BIT	4,B		;Copy directory FCB?
	JR	Z,LK9		;No => skip
	PUSH	BC		;Save
	PUSH	DE
	PUSH	HL
	EX	DE,HL		;Copy FCB
	LD	BC,20
	LDIR
	POP	HL		;Restore
	POP	DE
	POP	BC
LK9:	XOR	A		;No error
	RET

; Compare string at DE to string at HL for
; A characters

CMPS:	PUSH	BC		;Save BC
	LD	B,A		;Put length in B
	LD	C,0		;Clear C
CPS1:	LD	A,(DE)		;Get character
	CP	(HL)		;Match?
	JR	Z,CPS2		;Yes => skip
	DEC	C		;No match
CPS2:	INC	HL		;Point to next
	INC	DE
	DJNZ	CPS1		;Fall thru when done
	INC	C		;Status to Z flag
	DEC	C
	POP	BC		;Restore BC
	RET


; Enter file in current directory
;----------------------------------------------
; Entry: HL:  Address of FCB to be entered
; Exit:  HL:  Unchanged
;	 DE:  Directory FCB address
;	 BC:  Unchanged
;----------------------------------------------

ENTER:	PUSH	BC		;Save
	PUSH	HL
	LD	B,00100000B	;Look it up
	SCAL	ZLOOK
	JR	NZ,ENT1		;Non-existing => skip
	LD	A,31H		;Error 31
	JR	ENT2
ENT1:	LD	DE,(NXTFCB)	;Is directory full?
	LD	HL,FCBS+50*20
	SCF
	SBC	HL,DE
	LD	A,32H		;(Error 32 if so)
	JR	C,ENT2		;Yes => skip
	POP	HL		;Restore FCB addr
	PUSH	HL
	LD	BC,20		;Copy 20 bytes
	LDIR
	LD	(NXTFCB),DE	;Save new end addr
	LD	DE,FNSC-20	;Get FNSC into DE
	ADD	HL,DE
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	LD	HL,(NXTSEC)	;Add FNSC to NXTSEC
	ADD	HL,DE
	LD	(NXTSEC),HL
	SCAL	ZWDIR		;Write dir to disk
ENT2:	POP	HL		;Restore
	POP	BC
	OR	A		;Status to Z flag
	RET


; Call an overlay
;----------------------------------------------
; Entry: Registers defined by overlay
; Exit:  Registers defined by overlay
;----------------------------------------------

COV:	EX	(SP),HL		;Get overlay name
	CALL	TROVN
	EX	(SP),HL
	CALL	GETOV		;Read overlay
	JP	OVRLY		;Go to it


; Call an overlay and restore current overlay
;----------------------------------------------
; Entry: Registers defined by overlay
; Exit:  Registers defined by overlay
;----------------------------------------------

COVR:	EX	(SP),HL		;Get overlay name
	CALL	TROVN
	EX	(SP),HL
	PUSH	HL		;Save return addr
	LD	HL,(OVNAM)	;Push name of current
	EX	(SP),HL		;overlay onto stack
	PUSH	HL
	LD	HL,(OVNAM+2)
	EX	(SP),HL
	CALL	GETOV		;Read new overlay
	CALL	OVRLY		;Call it
	EX	(SP),HL		;Get previous overlay
	LD	(OVFCB+2),HL	;name
	POP	HL
	EX	(SP),HL
	LD	(OVFCB),HL
	POP	HL

; Read overlay in OVFCB into memory

GETOV:	PUSH	AF		;Save all
	PUSH	BC
	PUSH	DE
	PUSH	HL
	LD	HL,OVFCB+FNAM	;Is it there already?
	LD	DE,OVNAM
	LD	A,4
	CALL	CMPS
	JR	Z,GOV2		;Yes => don't read
	LD	B,4		;Blank fill remainder
GOV1:	LD	(HL),' '
	INC	HL
	DJNZ	GOV1
	LD	(HL),'O'	;Insert extension
	INC	HL
	LD	(HL),'V'
	LD	A,(MDRV)	;Read from MDRV
	LD	C,A
	SCAL	ZRDIR		;Read directory
	SCAL	ZCKER		;Check for error
	LD	HL,OVFCB	;Look it up
	LD	B,00100000B	;Include locked files
	SCAL	ZLOOK
	SCAL	ZCKER		;Check for error
	LD	HL,FSEC		;Point to FSEC slot
	ADD	HL,DE
	LD	E,(HL)		;Get FSEC into DE
	INC	HL
	LD	D,(HL)
	INC	HL
	LD	B,(HL)		;Get FNSC into B
	LD	HL,OVAREA	;Read into OVAREA
	SCAL	ZDRD		;Do the read
	SCAL	ZCKER		;Check for error
GOV2:	POP	HL		;Restore all
	POP	DE
	POP	BC
	POP	AF
	RET

; Transfer overlay name to OVFCB

TROVN:	PUSH	AF
	PUSH	BC
	PUSH	DE
	LD	DE,OVFCB+FNAM
	LD	BC,4
	LDIR
	POP	DE
	POP	BC
	POP	AF
	RET


; Check for error
;----------------------------------------------
; Entry: A:   Error code (0 => no error)
; Exit:  If no error, all registers unchanged
;	 otherwise CKER never returns
;----------------------------------------------

CKER:	OR	A		;Error?
	RET	Z		;No => bye
	LD	B,A		;Put code in B
	SCAL	ZNNOM		;Normal output
	LD	A,(ERRFLG)	;Second error?
	OR	A
	JR	NZ,ABORT	;Yes => trouble
	DEC	A		;Set error flag
	LD	(ERRFLG),A
	LD	A,B		;Save error code
	LD	(ERRCOD),A
	SCAL	ZCOV		;Call Emsg to print the
	DB	'Emsg'		;error message
	SCAL	ZCRLF
	XOR	A		;Clear error flag
	LD	(ERRFLG),A
DBREAK:	SCAL	ZCFMA		;Abort cmd file mode
	SCAL	ZMRET		;Back to Exec

; Abort PolyDos, print error code, and return
; control to NAS-SYS

ABORT:	CALL	STMON		;Initialize NAS-SYS
	RST	PRS		;Print error message
	DB	'(Error ',0
	LD	A,(ERRCOD)
	SCAL	ZB2HEX
	RST	PRS
	DB	')',CR,0
	SCAL	ZMRET		;Back to NAS-SYS


; Check for break
;----------------------------------------------
; If CTRL/SHIFT/@ is pressed, abort any
; operation, and return to via MRET
;----------------------------------------------

CKBRK:	LD	A,2		;Reset KBD pointer
	CALL	FFLP
	IN	A,(0)		;Read first row
	OR	80H		;Ignore bit 7
	CP	-1-38H		;CTRL/SHIFT/@?
	RET	NZ		;No => bye
	LD	A,(BLINKF)	;Aborted from BLINK?
	OR	A
	JR	Z,CKB1		;No => skip
	LD	HL,(CURSOR)	;Reinsert character
	LD	(HL),A		;at cursor
	XOR	A		;Clear BLINK flag
	LD	(BLINKF),A
CKB1:	LD	HL,(BREAK)	;Go to BREAK handler
	JP	(HL)


; Abort command file mode
;----------------------------------------------
; If command file mode is active, abort it and
; display (Cmdf abort)
;----------------------------------------------

CFMA:	LD	HL,CFFLG	;Is CFFLG set?
	XOR	A
	CP	(HL)
	RET	Z		;No => bye
	LD	(HL),A		;Clear it
	RST	PRS		;Display message
	DB	'(Cmdf abort)',CR,0
	RET


; Set SCAL vector
;----------------------------------------------
; Entry: HL:  New jump vector address
;	 Call is followed by routine number
; Exit:  HL:  Previous jump vector address
;	 DE:  Junk
;	 BC:  Junk
;----------------------------------------------

SSCV:	EX	(SP),HL		;Get routine number
	LD	E,(HL)
	INC	HL
	EX	(SP),HL
	PUSH	HL		;Save HL
	LD	D,0		;Clear D
	LD	HL,(STAB)	;Calculate addr in
	ADD	HL,DE		;SCAL table
	ADD	HL,DE
	POP	BC		;Get new vector
	LD	E,(HL)		;Read old
	LD	(HL),C		;Save new
	INC	HL		;Point to next byte
	LD	D,(HL)		;Read old
	LD	(HL),B		;Save new
	EX	DE,HL		;Put old vector in HL
	RET


;Execute jump table
;----------------------------------------------
; Entry: A:   Jump vector number
;	 Jump vectors follow call as DW's
; Exit:  Jumps to selected routine with all
;	 registers intact
;----------------------------------------------

JUMP:	EX	(SP),HL		;Point to jump table
	PUSH	DE		;Save
	PUSH	AF
	LD	E,A		;Calculate vector addr
	LD	D,0
	ADD	HL,DE
	ADD	HL,DE
	LD	E,(HL)		;Get vector into DE
	INC	HL
	LD	D,(HL)
	EX	DE,HL		;Put into HL
	POP	AF		;Restore
	POP	DE
	EX	(SP),HL
	RET			;Go there


; Output character to printer
;----------------------------------------------
; Entry: A:   Holds character to be printed
; Exit:  HL:  Junk
;	 DE:  Junk
;	 BC:  Junk
;	 AF:  Unchanged
;----------------------------------------------

POUT:	PUSH	AF		;Save char
	LD	HL,PPOS		;Point to PPOS
	CP	CR		;Is it CR?
	JR	NZ,PO4		;No => skip
	CALL	PRCH		;Print it
	LD	(HL),0		;Clear PPOS
	DEC	HL		;Point to PLCT
	INC	(HL)		;Increment it
	LD	A,(PBMG)	;Get PBMG
	LD	B,A		;Put into B
	LD	A,(PLPP)	;Get PLPP
	SUB	B		;Subtract PBMG
	SUB	(HL)		;Subtract PLCT
	JR	NZ,PO11		;Not zero => skip
PO1:	INC	B		;Adjust B
PO2:	DEC	B		;Decrement count
	JR	Z,PO3		;Zero => skip
	LD	A,CR		;Print CR/LF
	CALL	PRCH
	INC	(HL)		;Increment PLCT
	JR	PO2
PO3:	LD	(HL),B		;Clear PLCT
	JR	PO11		;Done
PO4:	CP	FF		;Is it FF?
	JR	NZ,PO5		;No => skip
	LD	(HL),0		;Clear PPOS
	DEC	HL		;Point to PLCT
	LD	A,(PLPP)	;Calculate number of
	SUB	(HL)		;CR/LFs to print
	LD	B,A		;Put in B
	JR	PO1		;Go print them
PO5:	LD	A,(PCPL)	;At right margin?
	CP	(HL)
	JR	NZ,PO6		;No => skip
	PUSH	BC
	PUSH	HL
	LD	A,CR		;Move to next line
	CALL	POUT
	POP	HL
	POP	BC
PO6:	LD	A,(HL)		;Is PPOS zero?
	OR	A
	JR	NZ,PO8		;No => skip
	LD	A,(PLMG)	;Get PLMG
	LD	B,A		;Put in B
	INC	B		;Adjust
PO7:	DEC	B		;Decrement count
	JR	Z,PO8		;Zero => skip
	LD	A,' '		;Print blank
	CALL	PRCHT
	JR	PO7
PO8:	POP	AF		;Restore char
	PUSH	AF
	CP	TAB		;Is it TAB?
	LD	B,1		;(Print 1 char if not)
	JR	NZ,PO10		;No => skip
	LD	A,(PLMG)	;Calculate number of
	SUB	(HL)		;blanks to expand the
	DEC	A		;TAB into
	AND	7
	INC	A
	LD	B,A		;Put in B
PO9:	LD	A,' '		;Print blank(s)
PO10:	CALL	PRCHT		;Print character
	DJNZ	PO9		;Fall thru when done
PO11:	POP	AF		;Restore char
	RET

; Print character with right margin test

PRCHT:	LD	C,A		;Put char in C
	LD	A,(PCPL)	;Still room on line?
	CP	(HL)
	RET	Z		;No => return
	LD	A,C		;Get char
	CALL	PRCH		;Print it
	INC	(HL)		;Increment PPOS
	RET

; Transfer character to user defined output
; routine, and add a LF in case of CR

PRCH:	PUSH	BC		;Save
	PUSH	HL
	PUSH	AF
	CALL	PCHR		;Call user routine
	POP	AF		;Restore
	POP	HL
	POP	BC
	CP	CR		;Was it CR?
	RET	NZ		;No => return
	LD	A,LF		;Supply LF
	JR	PRCH


; Output to CRT
;----------------------------------------------
; Output character in A to the CRT. TAB chars
; are expanded into one or more spaces
;----------------------------------------------

CRT:	CP	' '		;Control char
	JR	NC,CRTC		;No => go print
	OR	A		;Zero?
	RET	Z		;Yes => bye
	PUSH	AF		;Save char
	CP	TAB		;Is it TAB?
	JR	Z,CRT1		;Yes => skip
	LD	B,A		;Put char in B
	LD	A,(6)		;Get NAS-SYS byte
	CP	0FEH		;NAS-SYS 3?
	LD	A,B		;(Restore char)
	JP	NZ,152H		;Yes => jump
	JP	193H		;Must be NAS-SYS 1
CRT1:	LD	A,(CURSOR)	;Expand TAB
	AND	3FH
	CPL
	ADD	A,10
	AND	7
	INC	A
	LD	B,A		;Put count in B
CRT2:	PUSH	BC		;Save BC
	LD	A,' '		;Print blank
	CALL	CRTC
	POP	BC		;Restore BC
	DJNZ	CRT2		;Fall thru when done
	POP	AF		;Restore char
	RET
CRTC:	PUSH	AF		;Save char
	LD	HL,(CURSOR)	;Store at cursor
	LD	(HL),A
	INC	HL		;Move cursor right
	LD	A,(HL)		;Is there a margin?
	OR	A
	JR	Z,CRTC1		;Yes => skip
	LD	(CURSOR),HL	;Save new cursor
	POP	AF		;Restore char
	RET
CRTC1:	LD	A,(6)		;NAS-SYS 3?
	CP	0FEH
	JP	NZ,20EH		;Yes => jump
	JP	24FH		;Must be NAS-SYS 1?


; Normalize input table
;----------------------------------------------
; Restores normal input channels, i.e. routines
; RKBD and SRLIN. On exit HL contains address
; of previous input table
;----------------------------------------------

DNNIM:	LD	HL,INTBL
	SCAL	ZNIM
	RET

INTBL:	DB	ZRKBD,ZSRLIN,0


; Input from keyboard or command file
;----------------------------------------------
; If command file mode is active, get the
; character from the command file, else input
; it with a blinking cursor as normally.
; Pressing CTRL/SHIFT/@ will warm-boot the
; system
;----------------------------------------------

BLINK:	LD	A,(CFFLG)	;Command file mode?
	OR	A
	JR	NZ,BL3		;Yes => skip
BL1:	LD	HL,(CURSOR)	;Get char at cursor
	LD	A,(HL)
	LD	(BLINKF),A	;Save in BLINKF
	LD	A,(CURCHR)	;Put cursor on screen
	LD	(HL),A
	RCAL	BIN		;Scan KBD
	PUSH	AF		;Save char
	LD	A,(BLINKF)	;Restore char at cursor
	LD	(HL),A
	XOR	A		;Clear BLINK flag
	LD	(BLINKF),A
	POP	AF		;Restore input char
	RET	C		;Character => return
	RCAL	BIN		;Scan KBD
	JR	NC,BLINK	;No char => repeat
	RET
BIN:	LD	A,(CURBLR)	;Get blink rate
	LD	E,A		;Put in E
BIN1:	SCAL	ZIN		;Scan inputs
	RET	C		;Char => return
	DEC	E		;Decrement count
	JR	NZ,BIN1		;Loop until done
	RET
BL3:	CALL	CKBRK		;Check for break
	LD	A,(CFSBP)	;Get sector buffer ptr
	OR	A		;Buffer empty?
	JR	NZ,BL4		;No => skip
	LD	A,(CFNSC)	;Get sector count
	LD	(CFFLG),A	;Save as flag
	OR	A		;Zero?
	JR	Z,BL1		;Yes => skip
	DEC	A		;Decrement count
	LD	(CFNSC),A	;Save it
	LD	HL,SECBUF	;Read into SECBUF
	LD	DE,(CFSEC)	;From CFSEC
	PUSH	BC		;Save BC
	LD	B,1		;Read one sector
	LD	A,(CFDRV)	;From CFDRV
	LD	C,A
	SCAL	ZDRD		;Do the read
	SCAL	ZCKER		;Check for error
	POP	BC		;Restore BC
	INC	DE		;Increment sector addr
	LD	(CFSEC),DE	;Save it
;;[NAC HACK 2018Mar30] no way to implement this as a macro..
;;BL4:	LD	H,HIGH(SECBUF)	;Set MSB of address

BL4:	LD	H,SECBUF>>8	;Set MSB of address

LD	L,A		;Set LSB
	INC	A		;Increment pointer
	LD	(CFSBP),A	;Save it
	LD	A,(HL)		;Get char
	OR	A		;Filler?
	JR	Z,BL3		;Yes => repeat
	RET


; Scan keyboard with repeat
;----------------------------------------------
; If character is available it is returned in A
; with carry set. Otherwise carry is cleared.
; Registers HL, DE, and BC are modified.
; Pressing CTRL/SHIFT/@ warm-boots system.
;----------------------------------------------

RKBD:	CALL	CKBRK		;Check for break
	LD	HL,(RKROW)	;Get bit/row into HL
	INC	L		;Is row zero?
	DEC	L
	JR	Z,RK3		;Yes => no repeat char
	LD	B,8		;Do all 8 rows
RK1:	LD	A,1		;Move to next row
	CALL	FFLP
	PUSH	AF		;Delay
	POP	AF
	LD	A,L		;Repeat key row?
	CP	B
	JR	NZ,RK2		;No => skip
	IN	A,(0)		;Read row status
	CPL			;Complement
	LD	C,A		;Put in C
RK2:	DJNZ	RK1		;Fall thru when done
	LD	A,H		;Is repeat key down?
	AND	C
	JR	NZ,RK11		;Yes => skip
RK3:	LD	HL,KMAP		;Point to KMAP
	IN	A,(0)		;Read first row
	CPL			;Complement
	LD	(HL),A		;Store in KMAP
	LD	B,8		;Do 8 rows
RK4:	LD	A,1		;Move to next row
	CALL	FFLP
	INC	HL		;Increment KMAP pointer
	IN	A,(0)		;Read row status
	CPL			;Complement
	AND	7FH		;Ignore bit 7
	XOR	(HL)		;Same as last time?
	JR	NZ,RK7		;No => find out why
RK5:	DJNZ	RK4		;Fall thru when done
RK6:	XOR	A		;Clear carry
	LD	(RKROW),A	;No repeat key
	RET
RK7:	LD	C,-1		;Compute bit mask and
	LD	D,0		;column number
	SCF
RK8:	RL	D
	INC	C
	RRA
	JR	NC,RK8
	LD	A,D		;Get bit mask
	XOR	(HL)		;Update map
	LD	(HL),A
	LD	A,D		;Get bit mask
	AND	(HL)		;Key released?
	JR	Z,RK5		;Yes => ignore
	LD	HL,RKROW	;Point to KBD data
	LD	(HL),B		;Save row number
	INC	HL
	LD	(HL),D		;Save bit mask
	LD	A,(6)		;NAS-SYS 3?
	CP	0FEH
	JR	NZ,RK9		;No => skip
	CALL	113H		;Call NAS-SYS 3 
	JR	RK10
RK9:	CALL	0C9H		;Call NAS-SYS 1
RK10:	JR	NC,RK6		;Undefined key => skip
	LD	(RKVAL),A	;Save ASCII value
	LD	HL,(RKLON)	;Long delay
	JR	RK12
RK11:	LD	HL,(RKCNT)	;Get counter
	DEC	HL		;Decrement
	LD	A,H		;Zero?
	OR	L
	JR	NZ,RK13		;No => skip
	LD	HL,(RKSHO)	;Short delay
RK12:	LD	A,(RKVAL)	;Get ASCII value
	SCF			;Indicate char
RK13:	LD	(RKCNT),HL	;Save counter
	RET


; Print 2 spaces
;----------------------------------------------
; Print 2 spaces using the SPACE routine
;----------------------------------------------

SP2:	SCAL	ZSPACE
	SCAL	ZSPACE
	RET


; Call routine number E
;----------------------------------------------
; Call SCAL routine number E
;----------------------------------------------

SCALI:	PUSH	HL
	PUSH	DE
	PUSH	AF
	LD	D,0
	LD	HL,(STAB)
	ADD	HL,DE
	ADD	HL,DE
	LD	E,(HL)
	INC	HL
	LD	D,(HL)
	EX	DE,HL
	POP	AF
	POP	DE
	EX	(SP),HL
	RET


;----------------------------------------------
; PolyDos SCAL table (routines 7DH to 8FH)
;----------------------------------------------

PDSCTB:	DW	RKBD		;7DH
	DW	SP2		;7EH
	DW	SCALI		;7FH
	DW	DSIZE		;80H
	DW	DRD		;81H
	DW	DWR		;82H
	DW	RDIR		;83H
	DW	WDIR		;84H
	DW	CFS		;85H
	DW	LOOK		;86H
	DW	ENTER		;87H
	DW	COV		;88H
	DW	COVR		;89H
	DW	CKER		;8AH
	DW	CKBRK		;8BH
	DW	CFMA		;8CH
	DW	SSCV		;8DH
	DW	JUMP		;8EH
	DW	POUT		;8FH

;----------------------------------------------
;
;	PolyDos 2 (Version ??)
;	Disk Driver Routines Section
;
;	By Neal Crook
;
;	Routines will control an sdcard
;	decoded in I/O space and providing
;	up to four virtual floppy disk drives.
;	Each virtual drive has 2048 sectors.
;
;	First virtual drive is at block 0x800
;
;----------------------------------------------

; Initialize disk drivers and select drive specified in C
;;; This is called during the ROM init

INIT:   xor     a
        out     (SDLBA2),a      ;high block address is ALWAYS 0
	CALL	CNVCOD		;Convert drive code
	JP	TSTDSK		;Test for disk

; Return disk size of drive C in HL
;;; This is a Polydos SCAL
;;; Corrupts: AF

DSIZE:	LD	A,MAXDRV	;Too big?
	CP	C
	LD	A,28H		;(Error 28 if so)
	RET	C		;Yes => return
	XOR	A		;No error
	LD      HL,2048 	;2048*256=512Kbytes
	RET

; Read or write B sectors starting at sector DE
; on drive C to or from memory starting at HL.
; A=0 indicates read, A=-1 indicates write
;;; This is the main driver routine called from the
;;; portable part of the ROM.
;;; corrupts: AF, BC, DE, HL

RWSCTS:	PUSH	AF		;Save R/W flag
        ld      a,MAXDRV        ;Too big?
        cp      c
	LD	A,28H		;(Error 28 if so)
        jr      c,RWS2		;Yes => return

        ld      a,c
        ld      (DRVCOD),a      ;Probably never used..


;;; TODO convert from drive in C to block start address. For now, just
;;; support 1 drive, starting at block 0x800

;;; Convert DE from sector offset to absolute sector address
        push    hl
        ld      hl,$400         ;base for PolyDos images
        xor     a               ;clear carry
        adc     hl, de          ;start block address
        ld      d,h
        ld      e,l
        pop     hl              ;restore address

        pop     af              ;Restore R/W flag
        push    af              ;TODO may not need this any more.. discarded later using POP HL
        or      a               ;0=>read
        jr      z,rs

;;; write. Block DE, Data from HL, B sectors of 256 bytes each

;;; Didn't need this in 6809 code but, in Z80 code, without this
;;; it sometimes reads an extra byte when this routine is called
;;; in a loop - but not when I breakpoint after each iteration of
;;; the loop. Would need to add observation for external scope to
;;; understand what's going on here; don't have an adequate tb
;;; representation of the SDcard to simulate this scenario.
ws:     in      a,(SDCTRL)
        cp      $80             ;want WRRDY=1, all other bits clear
        jr      nz, ws          ;wait until SDcard is ready

        ld      a,d
        out     (SDLBA1),a
        ld      a,e
        out     (SDLBA0),a
        ld      a,SDWR
        out     (SDCTRL), a     ;issue the write command

        push    bc
        ld      b,0             ;counts as 256

wd:     in      a,(SDCTRL)      ;status
        cp      $a0
        jr      nz, wd          ;busy - wait for space
        ld      a,(hl)          ;get byte
        out     (SDDATA),a      ;store byte

        inc     hl
        djnz    wd              ;loop writing 256 bytes

;;; b is now 0 again. Write 256 x 0 to pad to 512 bytes
wdpad:  in      a,(SDCTRL)      ;status
        cp      $a0
        jr      nz, wdpad       ;busy
        xor     a
        out     (SDDATA),a
        djnz    wdpad           ;write padding data for the sector

        pop     bc
        inc     de              ;next block address
        djnz    ws              ;write data loop for B sectors

        xor     a               ;success
        jr      RWS2            ;tidy stack and return

;;; read. Block DE, Data to HL, B sectors of 256 bytes each

;;; Didn't need this in 6809 code but, in Z80 code, without this
;;; it sometimes reads an extra byte when this routine is called
;;; in a loop - but not when I breakpoint after each iteration of
;;; the loop. Would need to add observation for external scope to
;;; understand what's going on here; don't have an adequate tb
;;; representation of the SDcard to simulate this scenario.
rs:     in      a,(SDCTRL)
        cp      $80             ;want WRRDY=1, all other bits clear
        jr      nz, rs          ;wait until SDcard is ready

        ld      a,d
        out     (SDLBA1),a
        ld      a,e
        out     (SDLBA0),a
        ld      a,SDRD
        out     (SDCTRL), a     ;issue the read command

        push    bc
        ld      b,0             ;counts as 256

rd:     in      a,(SDCTRL)
        cp      $e0
        jr      nz, rd          ;busy - wait for data
        in      a,(SDDATA)      ;get byte
        ld      (hl),a          ;store byte
        inc     hl
        djnz    rd              ;loop reading 256 bytes

;;; b is now 0 again. Read 256 padding bytes and discard them

rdpad:  in      a,(SDCTRL)
        cp      $e0
        jr      nz, rdpad       ;busy - wait for data
        in      a,(SDDATA)      ;get byte
        djnz    rdpad           ;loop reading 256 bytes

        pop     bc
        inc     de              ;next block address
        djnz    rs              ;read data loop for B sectors

        xor     a               ;success
        jr      RWS2            ;tidy stack and return

;;; TODO currently no way to get "Error 29" - I need to find out how the SDcontroller responds
;;; when no SDcard is present - probably need a timeout right at the start.

RWS2A:  LD	A,29H		;Error 29
RWS2:	POP	HL		;Adjust
	OR	A		;Status to Z flag
	RET

; Convert drive number in C to a drive code
;;; ..and save in DRVCOD.
;;; bits 1:0 of drive number are the physical drive
;;; bit 2 is the DD bit. The drive code is the 1-hot
;;; value written to the FDC control register
;;; where bits 0:3 select physical drives 0-3
;;; respectively and bit 4 is the DD select.
;;; For nascom_sdcard, store the FID in DRVCOD.
;;; Initialisation code shows DRVCOD=-1 means
;;; "no drive selected". However, original TSTDSK
;;; sets DRVCOD=0 to mean "no drive selected".
;;; This TSTDSK uses -1.
;;; Corrupts: AF

CNVCOD: LD      A,C		;Drive number == FID
        AND     0x03		;Sanity
	LD	(DRVCOD),A	;Save as drive code
	RET


; Test that a disk is present in selected drive
;;; For local SDcard (just) need to test that an
;;; SDcard is present at all
;;; TODO how to do that??
;;; Return OK: Z set
;;; Return Err: Z clear, error code in A
;;; Corrupts: AF
TSTDSK:	xor     a               ;set Z to indicate success
	RET


;;; pad ROM to 2Kbytes.
MSGLEN: EQU 28h
SIZE:   EQU $ - PDCROM
PAD1:   EQU 800h - SIZE
        DS  PAD1 - MSGLEN, 0ffh

	DEFM 'Copyright (C) PolyData microcenter ApS  '

$END:	END
