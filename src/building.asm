; ---------------------------------------------------------------- building
; A building is a list of rooms. Each room has one "signed off" bit in bld_marked.
; Signing off a room that still holds an armed hazard is a Miss: it costs more energy
; than any trap and goes on the tally, but the room still counts as signed off.
; The exit opens once every room has been signed off, Misses included.

MAX_ROOMS       equ 32          ; bld_marked is 4 bytes
MISS_COST       equ 2
MISS_TALLY_MAX  equ 99
MISS_BORDER_FRAMES equ 12

; db room count, then dw room data per room
building_test:
        db 1
        dw room_test

building_gallery:               ; one of every hazard type except electric
        db 1
        dw room_gallery

; In: HL = building.
building_start:
        ld a,(hl)
        ld (bld_rooms),a
        inc hl
        ld (bld_room_list),hl
        xor a
        ld (miss_tally),a
        ld hl,bld_marked
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        inc hl
        ld (hl),a
        ; fall through: enter room 0

; In: A = room index. Loads and draws it.
room_enter:
        ld (cur_room),a
        add a,a
        ld hl,(bld_room_list)
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        call room_load
        jp room_draw

; In: A = room index. Out: HL = its byte in bld_marked, A = its bit. Preserves C,DE.
room_bit:
        ld b,a
        rrca
        rrca
        rrca
        and #1f
        ld hl,bld_marked
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,b
        and 7
        ld b,a
        ld a,1
        inc b
.shift: dec b
        ret z
        add a,a
        jr .shift

; Out: Z set if the current room is not signed off yet. Trashes AF,B,HL.
room_is_marked:
        ld a,(cur_room)
        call room_bit
        and (hl)
        ret

; Out: NZ if any hazard in the current room is still armed. Trashes AF,B,HL.
room_any_armed:
        ld hl,(room_hazards)
        ld b,(hl)
        ld a,b
        or a
        ret z
        inc hl
        inc hl
        inc hl
        inc hl                  ; -> state of the first hazard
.loop:  ld a,(hl)
        cp HZ_ARMED
        jr z,.armed
        inc hl
        inc hl
        inc hl
        inc hl
        djnz .loop
        xor a
        ret
.armed: or 1
        ret

; Mark-safe key: sign off the current room. A room's outcome is decided the first
; time it is signed off; later presses only say so.
try_mark:
        ld a,(cur_room)
        call room_bit
        ld b,a
        and (hl)
        ld a,STR_MARK_ALREADY
        jp nz,caption_show
        ld a,(hl)
        or b
        ld (hl),a
        call hud_draw_room_status
        call room_any_armed
        ld a,STR_MARK_SAFE
        jp z,caption_show
        ld a,(miss_tally)
        cp MISS_TALLY_MAX
        jr z,.capped
        inc a
        ld (miss_tally),a
.capped:
        ld b,MISS_COST
        call energy_lose
        ld a,INK_ORANGE
        call set_border
        ld a,MISS_BORDER_FRAMES
        ld (border_timer),a
        ld a,STR_MARK_MISS
        jp caption_show

; Out: carry set if Thanos is standing in front of the exit door.
at_exit:
        ld de,(pl_x)
        inc d                   ; feet row
        call map_addr
        ld a,(hl)
        and #7f
        cp TILE_EXIT_B
        scf
        ret z
        inc hl
        ld a,(hl)
        and #7f
        cp TILE_EXIT_B
        scf
        ret z
        or a
        ret

; Up at the exit door: leave if every room is signed off.
try_exit:
        ld a,(bld_rooms)
.room:  or a
        jr z,.open
        dec a
        ld c,a
        call room_bit
        and (hl)
        ld a,STR_EXIT_LOCKED
        jp z,caption_show
        ld a,c
        jr .room
.open:  ld a,PS_DONE
        ld (pl_state),a
        ld a,STR_EXIT_DONE
        jp caption_show
