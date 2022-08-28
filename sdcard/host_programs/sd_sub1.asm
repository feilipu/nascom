;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; subroutines for low-level access to nascom_sdcard
;;; https://github.com/nealcrook/nascom
;;;
;;; Putting them at the start means that the start of each test
;;; program is identical - useful if you are hand-typing the hex
;;; in (as I did when testing)
;;;
;;; PIO port A is used for data and is switched between in and out
;;; PIO port B is used for control (3 bits)
;;;
;;; portB[2] - CMD Input  "Command"         mask 4
;;; portB[1] - H2T Output "Host to Target"  mask 2
;;; portB[0] - T2H Input  "Target to host"  mask 1
;;;
;;; The behaviour of the handshakes is illustrated here:
;;; https://github.com/nealcrook/nascom/blob/master/sdcard/doc/protocol.pdf
;;;
;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;; assume: currently in OUTPUT
;;; command is in A
;;; send command, toggle handshake, wait for handshake in to match
;;; to show that target has received it.
;;; corrupts: A,F
putcmd: out     (PIOAD), a      ;send command
        in      a, (PIOBD)
        or      4               ;CMD=1
        jr      pvx             ;common code for cmd/data


;;; assume: currently in OUTPUT
;;; value is in A
;;; send value, toggle handshake, wait for handshake in to match
;;; to show that target has received it.
;;; corrupts: A,F
putval: out     (PIOAD), a      ;send value
pv0:    in      a, (PIOBD)
        and     $fb             ;CMD=0

pvx:    xor     2               ;toggle H2T
        out     (PIOBD), a

        ;; fall-through and subroutine
        ;; wait until handshakes match
        ;; corrupts A,F
waitm:  in      a, (PIOBD)      ;get status
        and     3               ;look at handshakes
        ret     z               ;both 0 => done
        cp      3
        ret     z               ;both 1 => done
        jr      waitm		;test again..


;;; assume: currently in OUTPUT. Go to INPUT
;;; leave CMD=0 (but irrelevant)
;;; corrupts: A,F
gorx:   ld      a, $cf          ;"control" mode
        out     (PIOAC), a
        ld      a, $ff
        out     (PIOAC), a      ;port A all input
        jr      getend


;;; assume: currently in INPUT. Go to OUTPUT
;;; leave CMD bit unchanged
;;; corrupts: NOTHING
gotx:   push    af
        call    waitm           ;wait for hs to match
        pop     af

        ;; fall-through and subroutine
        ;; set port A to output
        ;; corrupts nothing
a2out:  push    af
        ld      a, $cf          ;"control" mode
        out     (PIOAC), a
        xor     a               ;A=0
        out     (PIOAC), a      ;port A all output
        pop     af
        ret


;;; assume: currently in INPUT
;;; get a byte; return it in A
;;; corrupts: A,F
getval: call    waitm           ;wait for hs to match
        in      a, (PIOAD)      ;get data byte

        ;; fall-through and subroutine
        ;; toggle H2T.
getend: push    af
        in      a, (PIOBD)
        xor     2               ;toggle H2T
        out     (PIOBD), a
        pop     af
        ret

;;; end
