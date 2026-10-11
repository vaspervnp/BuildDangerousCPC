; ---------------------------------------------------------------- input
; Scans the 10-line keyboard matrix through the PSG (register 14) and folds it into `keys`.
; Joystick 0 is matrix line 9.

KEY_UP          equ %00000001
KEY_DOWN        equ %00000010
KEY_LEFT        equ %00000100
KEY_RIGHT       equ %00001000
KEY_FIRE        equ %00010000
KEY_MARK        equ %00100000
KEY_LANG        equ %01000000

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
.done:  ld a,c
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
        db 9,%00100000,KEY_FIRE         ; joystick fire 1
        db 4,%01000000,KEY_MARK         ; M
        db 9,%00010000,KEY_MARK         ; joystick fire 2
        db 4,%00010000,KEY_LANG         ; L
        db #ff
