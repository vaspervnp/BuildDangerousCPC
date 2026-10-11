; ---------------------------------------------------------------- hazards
; Room hazard list: count, then per hazard 4 bytes: x, row, type, state.
; Triggering an armed hazard is the only way to disarm it: it always plays the
; type's vignette and always costs energy.

HZ_ELECTRIC     equ 0           ; type ids follow HAZARD_TYPES in tools/cpcgfx.py

HZ_ARMED        equ 0
HZ_DISARMED     equ 1

HZ_X            equ 0
HZ_ROW          equ 1
HZ_TYPE         equ 2
HZ_STATE        equ 3
HZ_SIZE         equ 4

; Sprites in build/hazards.bin: per hazard the armed tell, then its disarmed look.
HSPR_SOCKET     equ 0

; Reach: Thanos can set off a hazard within one column of his body and anywhere
; from 4 rows above his head down to his feet, i.e. the whole storey he is on.
REACH_LEFT      equ 1
REACH_W         equ 4
REACH_UP        equ 4
REACH_H         equ 6

HZT_VIGNETTE    equ 0           ; dw script
HZT_SPRITE      equ 2           ; db armed tell sprite (disarmed = +1)
HZT_CAPTION     equ 3           ; db STR_* id
HZT_COST        equ 4           ; db energy lost
HZT_SIZE        equ 5

hz_types:
        dw vig_electric
        db HSPR_SOCKET, STR_CAP_ZAP, 1

; In: A = hazard type. Out: HL = its hz_types entry. Trashes AF.
hz_type_entry:
        push de
        ld l,a
        ld h,0
        ld e,l
        ld d,h
        add hl,hl
        add hl,hl
        add hl,de               ; *5
        ld de,hz_types
        add hl,de
        pop de
        ret

; Find the hazard at D=row, E=col. Out: carry set and HL = entry if found.
; Preserves DE; trashes AF,B.
hazard_find:
        ld hl,(room_hazards)
        ld b,(hl)
        inc hl
        ld a,b
        or a
        ret z
.loop:  ld a,(hl)
        cp e
        jr nz,.next
        inc hl
        ld a,(hl)
        dec hl
        cp d
        jr nz,.next
        scf
        ret
.next:  inc hl
        inc hl
        inc hl
        inc hl
        djnz .loop
        or a
        ret

; Overlay hazard HL's sprite on cell D=row, E=col. Preserves DE; trashes AF,BC,HL.
draw_hazard:
        inc hl
        inc hl
        ld a,(hl)               ; type
        inc hl
        ld c,(hl)               ; state: armed tell or disarmed look
        call hz_type_entry
        inc hl
        inc hl
        ld a,(hl)
        add a,c
        ld l,a                  ; HL = hazard_gfx + sprite*32
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        push de
        ld de,hazard_gfx
        add hl,de
        pop de
        jp draw_sprite8

; Fire pressed: set off the first armed hazard within reach.
; Out: carry set if a vignette started.
try_trigger:
        ld ix,(room_hazards)
        ld b,(ix+0)
        inc ix
        ld a,b
        or a
        ret z
.loop:  ld a,(ix+HZ_STATE)
        cp HZ_ARMED
        jr nz,.next
        ld a,(pl_x)
        sub REACH_LEFT
        ld c,a
        ld a,(ix+HZ_X)
        sub c
        cp REACH_W
        jr nc,.next
        ld a,(pl_y)
        sub REACH_UP
        ld c,a
        ld a,(ix+HZ_ROW)
        sub c
        cp REACH_H
        jr nc,.next
        call vig_start
        scf
        ret
.next:  ld de,HZ_SIZE
        add ix,de
        djnz .loop
        or a
        ret
