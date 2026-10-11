; ---------------------------------------------------------------- HUD band (rows 0-1)
; Row 0: energy as hard hats. Row 1: caption line, typed out a few characters per
; frame (keeps every frame inside budget) and cleared after CAPTION_FRAMES.
; Row 1 must stay plain black (TILE_BLACK): caption_clear just zeroes it.

ENERGY_MAX      equ 8
ENERGY_ROW      equ 0
ENERGY_COL      equ 1
ROOM_ICON_ROW   equ 0
ROOM_ICON_COL   equ 11
CAPTION_ROW     equ 1
CAPTION_FRAMES  equ 150         ; 3 seconds
CAPTION_CPF     equ 2           ; characters typed per frame

hud_init:
        ld a,ENERGY_MAX
        ld (energy),a
        xor a
        ld (caption_timer),a
        ld (border_timer),a
        ld h,a
        ld l,a
        ld (caption_ptr),hl
        call hud_draw_room_status
        jp hud_draw_energy

; In: B = energy to lose (stops at 0). Redraws the hats.
energy_lose:
        ld a,(energy)
        sub b
        jr nc,.set
        xor a
.set:   ld (energy),a
        jp hud_draw_energy

; Checkbox for the current room: empty until it has been signed off.
hud_draw_room_status:
        call room_is_marked
        ld a,TILE_CHECK_EMPTY
        jr z,.set
        ld a,TILE_CHECK_DONE
.set:   ld d,ROOM_ICON_ROW
        ld e,ROOM_ICON_COL
        call map_addr_keep_a
        ld (hl),a
        jp draw_cell

; Hats are written into the HUD rows of the room map, so redraws keep them.
hud_draw_energy:
        ld d,ENERGY_ROW
        ld e,ENERGY_COL
.hat:   ld a,(energy)
        ld c,a
        ld a,e
        sub ENERGY_COL
        cp c                    ; hat index < energy -> full
        ld a,TILE_HAT_FULL
        jr c,.set
        ld a,TILE_HAT_EMPTY
.set:   call map_addr_keep_a
        ld (hl),a
        call draw_cell
        inc e
        ld a,e
        cp ENERGY_COL+ENERGY_MAX
        jr nz,.hat
        ret

; map_addr that keeps A. In: D,E. Out: HL. Preserves DE.
map_addr_keep_a:
        push af
        call map_addr
        pop af
        ret

; In: A = STR_* id. The text appears over the next frames (see hud_update).
caption_show:
        push af
        call caption_clear
        pop af
        call get_string
        ld (caption_ptr),hl
        xor a
        ld (caption_col),a
        ld a,CAPTION_FRAMES
        ld (caption_timer),a
        ret

caption_clear:
        ld hl,SCREEN+CAPTION_ROW*SCR_ROW_BYTES
        ld a,8
.line:  push hl
        ld d,h
        ld e,l
        inc de
        ld (hl),0
        ld bc,SCR_ROW_BYTES-1
        ldir
        pop hl
        ld bc,#0800
        add hl,bc
        dec a
        jr nz,.line
        ret

hud_update:
        ld a,(border_timer)
        or a
        jr z,.caption
        dec a
        ld (border_timer),a
        jr nz,.caption
        ld a,INK_BLACK
        call set_border
.caption:
        ld hl,(caption_ptr)
        ld a,h
        or l
        jr z,.timer
        ld a,(caption_col)
        ld e,a
        ld d,CAPTION_ROW
        ld c,PEN3_MASK
        ld b,CAPTION_CPF
.char:  ld a,(hl)
        cp #ff
        jr z,.typed
        call print_char
        inc hl
        inc e
        djnz .char
        ld (caption_ptr),hl
        ld a,e
        ld (caption_col),a
        ret
.typed: ld hl,0
        ld (caption_ptr),hl
        ret
.timer: ld a,(caption_timer)
        or a
        ret z
        dec a
        ld (caption_timer),a
        ret nz
        jp caption_clear
