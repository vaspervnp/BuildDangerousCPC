; ---------------------------------------------------------------- room
; The room map mirrors the screen: 40x25 cells. Rows 0-1 are the HUD band,
; rows 2-24 come from the room's RLE data: (count, tile)... terminated by count 0.
; The hazard list follows (see hazards.asm). Cells holding a hazard have bit 7 set.
; Room data lives in RAM and hazard states are written back into it, so a room
; remembers what was disarmed when it is loaded again.

MAP_W           equ 40
MAP_H           equ 25
HUD_ROWS        equ 2

; In: HL = room data.
room_load:
        push hl
        ld hl,room_map
        ld de,room_map+1
        ld bc,MAP_W*HUD_ROWS-1
        ld (hl),TILE_BLACK
        ldir
        pop hl
        ld de,room_map+MAP_W*HUD_ROWS
.run:   ld a,(hl)
        or a
        jr z,.hazards
        ld b,a
        inc hl
        ld a,(hl)
        inc hl
.fill:  ld (de),a
        inc de
        djnz .fill
        jr .run
.hazards:
        inc hl
        ld (room_hazards),hl
        ld b,(hl)
        inc hl
        ld a,b
        or a
        ret z
.mark:  ld e,(hl)               ; x
        inc hl
        ld d,(hl)               ; row
        inc hl
        inc hl
        inc hl
        push hl
        call map_addr
        set 7,(hl)
        pop hl
        djnz .mark
        ret

room_draw:
        ld d,0
.row:   ld e,0
.col:   call draw_cell
        inc e
        ld a,e
        cp MAP_W
        jr nz,.col
        inc d
        ld a,d
        cp MAP_H
        jr nz,.row
        ret

; In: D=row, E=col. Out: HL = &room_map[row][col]. Preserves DE; trashes A.
map_addr:
        push de
        ld l,d
        ld h,0
        add hl,hl
        ld de,row_map
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ld a,e
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; In: D=row, E=col. Out: A = tile flags. Preserves BC,DE; trashes HL.
flags_at:
        call map_addr
        ld a,(hl)
        and #7f
        ld hl,tile_flags
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        ret

; Two cells side by side. In: D=row, E=col. Out: B = flags(col), A = flags(col+1).
; Preserves C,DE.
flags_pair:
        call flags_at
        ld b,a
        inc e
        call flags_at
        dec e
        ret

; Two cells stacked. In: D=row, E=col. Out: A = flags(row,col) | flags(row+1,col).
; Preserves C,DE; trashes B.
flags_col:
        call flags_at
        ld b,a
        inc d
        call flags_at
        dec d
        or b
        ret

row_map:
rowi = 0
        repeat MAP_H
        dw room_map + rowi*MAP_W
rowi = rowi + 1
        rend
