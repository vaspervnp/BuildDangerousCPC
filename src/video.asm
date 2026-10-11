; ---------------------------------------------------------------- video
; Mode 1 screen at #C000: 25 character rows of 8 lines, 80 bytes per line.
; Address of (row,line) = #C000 + row*80 + line*#800. 4 pixels per byte.

SCREEN          equ #c000
SCR_ROW_BYTES   equ 80

; Gate array hardware inks (already OR'ed with #40 = "set ink" command)
INK_BLACK       equ #54
INK_ORANGE      equ #4e
INK_SKYBLUE     equ #57
INK_BRWHITE     equ #4b

video_init:
        ld bc,#7f8d             ; RMR: mode 1, lower + upper ROM disabled
        out (c),c
        call screen_clear
        call palette_normal
        ld a,INK_BLACK
        call set_border
        ld bc,#bc0c             ; CRTC R12/R13: screen base #C000, no scroll offset
        out (c),c
        ld bc,#bd30
        out (c),c
        ld bc,#bc0d
        out (c),c
        ld bc,#bd00
        out (c),c
        ret

; Pen order must match PENS in tools/cpcgfx.py
ink_table:
        db INK_BLACK, INK_ORANGE, INK_SKYBLUE, INK_BRWHITE
black_table:
        db INK_BLACK, INK_BLACK, INK_BLACK, INK_BLACK

palette_normal:
        ld hl,ink_table
        jr palette_set
palette_black:
        ld hl,black_table
; In: HL = 4 hardware inks for pens 0-3. Trashes AF,BC,D,HL.
palette_set:
        ld b,#7f
        xor a
.ink:   out (c),a               ; select pen A
        ld d,(hl)
        out (c),d
        inc hl
        inc a
        cp 4
        jr nz,.ink
        ret

screen_clear:
        ld hl,SCREEN
        ld de,SCREEN+1
        ld bc,#3fff
        ld (hl),0
        ldir
        ret

; Wait for the start of the next vertical sync (PPI port B bit 0).
wait_vbl:
        ld b,#f5
.end:   in a,(c)
        rra
        jr c,.end
.start: in a,(c)
        rra
        jr nc,.start
        ret

; In: D=row (0-24), E=col (0-39). Out: HL = screen address of the cell's top line.
; Trashes A.
cell_addr:
        push de
        ld l,d
        ld h,0
        add hl,hl
        ld de,row_scr
        add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        pop de
        ld a,e
        add a,a
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; Zero one character row of the screen (pen 0). In: D = row. Preserves DE; trashes AF,BC,HL.
clear_row:
        push de
        ld e,0
        call cell_addr
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
        pop de
        ret

; Draw the room-map cell at D=row, E=col: its tile, plus the hazard sitting on it if
; bit 7 is set. Preserves DE; trashes AF,BC,HL.
draw_cell:
        call map_addr
        ld a,(hl)
        or a
        jp p,draw_tile_at
        and #7f
        call draw_tile_at
        call hazard_find
        ret nc
        jp draw_hazard

; Draw tile A at D=row, E=col. Preserves DE; trashes AF,BC,HL.
draw_tile_at:
        push de
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,tiles_gfx
        add hl,bc
        push hl
        call cell_addr
        pop de
        ld b,8
.line:  ld a,(de)               ; cell start is even, so the 2-byte span never crosses a page
        ld (hl),a
        inc de
        inc l
        ld a,(de)
        ld (hl),a
        inc de
        dec l
        ld a,h
        add a,#08
        ld h,a
        djnz .line
        pop de
        ret

; Masked 16x16 sprite at cell D=row, E=col (tile aligned).
; In: HL = frame (16 lines x 4 x (mask,data)). Preserves DE; trashes AF,BC,HL.
draw_sprite16:
        ld (spr_ptr),hl
        call cell_addr
        push de
        ld de,(spr_ptr)
        ld b,4
        call blit_masked8
        ld (spr_ptr),de
        pop de
        inc d
        call cell_addr
        push de
        ld de,(spr_ptr)
        ld b,4
        call blit_masked8
        pop de
        dec d
        ret

; Masked 8x8 sprite at cell D=row, E=col.
; In: HL = frame (8 lines x 2 x (mask,data)). Preserves DE; trashes AF,BC,HL.
draw_sprite8:
        ld (spr_ptr),hl
        call cell_addr
        push de
        ld de,(spr_ptr)
        ld b,2
        call blit_masked8
        pop de
        ret

; 8 lines of masked bytes: screen = (screen AND mask) OR data.
; In: HL = screen, DE = (mask,data) pairs, B = width in bytes. Out: DE past the data.
; Trashes AF,BC,HL.
blit_masked8:
        ld a,b
        ld (blit_w),a
        ld c,8
.line:  push hl
        ld a,(blit_w)
        ld b,a
.byte:  ld a,(de)               ; mask
        and (hl)
        inc de
        ex de,hl
        or (hl)                 ; data
        ex de,hl
        ld (hl),a
        inc de
        inc hl
        djnz .byte
        pop hl
        ld a,h
        add a,#08
        ld h,a
        dec c
        jr nz,.line
        ret

; In: A = hardware ink for the border. Trashes BC.
set_border:
        ld bc,#7f10
        out (c),c
        out (c),a
        ret

; In: A = hardware ink for pen 0 (the background). Trashes BC.
set_pen0:
        ld bc,#7f00
        out (c),c
        out (c),a
        ret

row_scr:
rowi = 0
        repeat 25
        dw SCREEN + rowi*SCR_ROW_BYTES
rowi = rowi + 1
        rend
