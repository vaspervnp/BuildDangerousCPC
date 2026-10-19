; ---------------------------------------------------------------- input
; Scans the 10-line keyboard matrix through the PSG (register 14) and folds it into `keys`.
; Joystick 0 is matrix line 9. Its two fire buttons together are ESC (pause): one alone
; waits JOY_GRACE frames for the other before it counts as Fire / M (or counts as it is
; let go, for a quick tap); after both, nothing more until both are up.

JOY_GRACE       equ 5               ; 0.1 s: "together", for two thumbs
JOY_FIRES       equ %00110000       ; matrix line 9: bit 5 fire 1, bit 4 fire 2

KEY_UP          equ %00000001
KEY_DOWN        equ %00000010
KEY_LEFT        equ %00000100
KEY_RIGHT       equ %00001000
KEY_FIRE        equ %00010000
KEY_MARK        equ %00100000
KEY_LANG        equ %01000000
KEY_PAUSE       equ %10000000

input_read:
        ld hl,kb_matrix
        ld bc,#f40e             ; PSG register 14 (port A = keyboard)
        out (c),c
        ld bc,#f6c0             ; PSG: select register
        out (c),c
        ld bc,#f600             ; PSG: inactive
        out (c),c
        ld bc,#f792             ; PPI port A to input
        out (c),c
        ld a,#40                ; PSG read + matrix line 0
.line:  ld b,#f6
        out (c),a
        ld b,#f4
        in e,(c)
        ld (hl),e
        inc hl
        inc a
        cp #4a
        jr nz,.line
        ld bc,#f782             ; PPI port A back to output
        out (c),c
        ld bc,#f600
        out (c),c

        ld hl,key_map
        ld c,0
.map:   ld a,(hl)               ; matrix line, #ff ends the table
        cp #ff
        jr z,.done
        inc hl
        ld de,kb_matrix
        add a,e
        ld e,a
        adc a,d
        sub e
        ld d,a
        ld a,(de)
        and (hl)                ; matrix bits are 0 when pressed
        inc hl
        jr nz,.skip
        ld a,c
        or (hl)
        ld c,a
.skip:  inc hl
        jr .map
.done:  ld a,(kb_matrix+9)       ; the joystick's fire buttons
        cpl
        and JOY_FIRES
        jr nz,.fires
        ld a,(joy_lock)         ; both up: a tap let go before its time counts now
        or a
        jr nz,.free
        ld a,(joy_wait)
        or a
        jr z,.free
        cp JOY_GRACE+1
        jr nc,.free
        ld a,(joy_last)
        or c
        ld c,a
.free:  xor a
        ld (joy_lock),a
        ld (joy_wait),a
        jr .edge
.fires: ld b,a
        ld a,(joy_lock)
        or a
        jr nz,.edge             ; after a pause: until both are up
        ld a,b
        cp JOY_FIRES
        jr nz,.one
        ld (joy_lock),a         ; both: pause
        ld a,c
        or KEY_PAUSE
        ld c,a
        jr .edge
.one:   cp %00100000            ; one: fire 1 is Fire, fire 2 is M
        ld a,KEY_FIRE
        jr z,.which
        ld a,KEY_MARK
.which: ld (joy_last),a
        ld b,a
        ld a,(joy_wait)
        cp JOY_GRACE
        jr nc,.held
        inc a
        ld (joy_wait),a
        jr .edge
.held:  ld a,JOY_GRACE+1        ; past waiting: it counts while held
        ld (joy_wait),a
        ld a,c
        or b
        ld c,a
.edge:  ld a,(keys)              ; keys_new = pressed now but not last frame
        cpl
        and c
        ld (keys_new),a
        ld a,c
        ld (keys),a
        ret

; matrix line, bit mask, KEY_* flag
key_map:
        db 0,%00000001,KEY_UP           ; cursor up
        db 8,%00001000,KEY_UP           ; Q
        db 9,%00000001,KEY_UP           ; joystick up
        db 0,%00000100,KEY_DOWN         ; cursor down
        db 8,%00100000,KEY_DOWN         ; A
        db 9,%00000010,KEY_DOWN         ; joystick down
        db 1,%00000001,KEY_LEFT         ; cursor left
        db 4,%00000100,KEY_LEFT         ; O
        db 9,%00000100,KEY_LEFT         ; joystick left
        db 0,%00000010,KEY_RIGHT        ; cursor right
        db 3,%00001000,KEY_RIGHT        ; P
        db 9,%00001000,KEY_RIGHT        ; joystick right
        db 5,%10000000,KEY_FIRE         ; space
        db 4,%01000000,KEY_MARK         ; M
        db 4,%00010000,KEY_LANG         ; L
        db 8,%00000100,KEY_PAUSE        ; ESC
        db #ff
