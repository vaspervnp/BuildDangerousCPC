; ---------------------------------------------------------------- first-trap hints
; The first three traps Thanos comes within reach of (campaign-wide, so in practice in
; Sunny Vale) open a window: "You are in front of a trap. Press SPACE to activate it."
; The third adds "From now on, you are on your own. Find and activate all the traps."
; The window closes when the trap goes off or he walks away, and opens again if he comes
; back to that trap. After the third trap, no more.

HINT_TRAPS      equ 3
HINT_ROWS       equ 6               ; bricks, four lines, bricks
HINT_TOP        equ 2               ; where he isn't: the top, or just above the bottom
HINT_BOTTOM     equ MAP_H-HINT_ROWS

; Close the window, if one is up: put those rows of the room back.
hint_hide:
        ld a,(hint_row)
        or a
        ret z
        ld d,a
        xor a
        ld (hint_row),a
        ld b,HINT_ROWS
        call rows_restore
        jp player_draw

; Redraw B rows of the room from row D. Trashes AF,BC,DE,HL.
rows_restore:
        push bc
        ld e,0
.cell:  call draw_cell
        inc e
        ld a,e
        cp MAP_W
        jr nz,.cell
        inc d
        pop bc
        djnz rows_restore
        ret

; Every play frame, after the player.
hint_update:
        ld a,(pl_state)
        or a                    ; walking only; a trap, a call or a selfie closes it
        jr nz,hint_hide
        call hazard_in_reach
        jr nc,hint_hide
        push ix                 ; the trap the last window was for?
        pop de
        ld hl,(hint_ptr)
        or a
        sbc hl,de
        jr z,.show
        ld a,(hint_count)       ; a new trap: one of the first three?
        cp HINT_TRAPS
        jr nc,hint_hide
        inc a
        ld (hint_count),a
        ld (hint_ptr),ix
        call hint_hide          ; (a window still up for another trap)
.show:  ld a,(hint_row)
        or a
        ret nz                  ; already up
        ld a,(pl_y)
        cp 12
        ld a,HINT_TOP
        jr nc,.row
        ld a,HINT_BOTTOM
.row:   ld (hint_row),a
        ld d,a
        call brick_row
        ld b,HINT_ROWS-2        ; the sides, black inside
.side:  inc d
        push bc
        ld e,0
.cell:  ld a,e
        or a
        jr z,.brick
        cp MAP_W-1
        ld a,TILE_BLACK
        jr nz,.put
.brick: ld a,TILE_BRICK
.put:   call draw_tile_at
        inc e
        ld a,e
        cp MAP_W
        jr nz,.cell
        pop bc
        djnz .side
.bottom:
        inc d
        call brick_row
        ld a,(hint_count)       ; the text: two lines, or four on the last
        cp HINT_TRAPS
        ld a,(hint_row)
        jr z,.four
        add a,2
        jr .two
.four:  inc a
        push af
        add a,2
        ld d,a
        ld a,STR_HINT_OWN1
        ld c,PEN1_MASK
        call print_text_centered
        pop af
        push af
        add a,3
        ld d,a
        ld a,STR_HINT_OWN2
        ld c,PEN1_MASK
        call print_text_centered
        pop af
.two:   ld d,a
        push de
        ld a,STR_HINT_TRAP1
        ld c,PEN3_MASK
        call print_text_centered
        pop de
        inc d
        ld a,STR_HINT_TRAP2
        ld c,PEN3_MASK
        jp print_text_centered
