;;; dskboot
;;;
;;; Utility for system start via CMD_PBOOT on NASCOM SDcard
;;; https://github.com/nealcrook/nascom
;;;
;;; Assemble at address xxxx and invoke from
;;; NAS-SYS like this:
;;;
;;;      E xxxx
;;;
;;; In its current form, this is designed as a companion
;;; to serboot. It can be loaded and run from powerup
;;; using the serial/tape interface. It contains the
;;; minimum code needed to talk to the NAScas parallel
;;; interface and can bootstrap load code across that
;;; interface.
;;;
;;; It requires a "profile record" to be stored in the
;;; NAScas Arduino's EEPROM. With default settings, it
;;; will look for these 4 files on the SDcard:
;;; SDBOOT0.DSK SDBOOT1.DSK SDBOOT2.DSK SDBOOT3.DSK
;;; Only the first one is important; the other three
;;; should be 0-sized files.
;;; This program will load the first "sector" from
;;; SDBOOT0.DSK into RAM at 0D00 and jump to it.
;;;
;;; In its current form this is just proof-of-concept.
;;; Here are 2 evolutions:
;;;
;;; - As a CP/M boot-loader. For example, it could
;;; replace the boot loader section of code in the
;;; MAP80 VFC ROM (it requires modification for a real
;;; CP/M system, because it cannot rely on NAS-SYS)
;;;
;;; - As a way to initialise system memory. In a
;;; system with 64K of RAM, ROM-less apart from NAS-SYS,
;;; the code in SDBOOT0.DSK could load images for
;;; ZEAP/BASIC/POLYDOS/NASDOS/NASPEN/NASPAS through a
;;; simple menu system, then return to NAS-SYS.
;;;
;;; EEPROM in the NAScas Arduino defines a set
;;; of "profiles" each of which has associated
;;; disk file names. This program loads profile 3
;;; for which the default disk image is SDBOOT0.DSK
;;; with a sector size of 512 bytes. It loads to
;;; RAM at $1000 and executes there.
;;;
;;; For reference, the CP/M bootstrap loaded in
;;; the MAP80 VFC ROM is 0xc1 bytes, including
;;; 28 bytes of message strings. This code is 0x81
;;; bytes, with no I/O code and no message strings.
;;; It could be made 10 bytes smaller by removing
;;; putval which is part of the common subroutines
;;; but which is not needed here.

START:  EQU     $0c80
LOADAT: EQU     $0d00

;;; Macros for using NAS-SYS routines
SCAL:   MACRO FOO
        RST 18H
        DB FOO
        ENDM

;;; Equates for communicating with NAS-SYS and NAS-SYS workspace
ZMRET:  EQU     $5b

        ORG     START

        jp      entry

;;; Defines and low-level subroutines
        include "sd_sub_defs.asm"
        include "sd_sub1.asm"

;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; main program
;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; initialise the PIO and train the interface
entry:  include "sd_sub2.asm"

;;; issue the command, select profile 3
        ld      a, CPBOOT + 3
        call    putcmd
        call    gorx
        ld      hl, LOADAT      ;where to put the data
        ld      bc, 512         ;sector size
next:   call    getval
        ld      (hl), a
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz, next

        call    getval          ;get status
        call    gotx            ;does not affect A
        or      a               ;update flags
        jp      nz, LOADAT      ;enter loaded program

        ;; fatal error - back to NAS-SYS
        SCAL    ZMRET

;;; end
