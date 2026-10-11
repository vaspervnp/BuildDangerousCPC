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
        ld b,#7f                ; gate array again (LDIR left BC=0)
        ld hl,ink_table
        xor a
.ink:   out (c),a               ; select pen A
        ld d,(hl)
        out (c),d
        inc hl
        inc a
        cp 4
        jr nz,.ink
        ld a,#10                ; select border
        out (c),a
        ld a,INK_BLACK
        out (c),a
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

; Draw the room-map tile at D=row, E=col. Preserves DE; trashes AF,BC,HL.
draw_cell:
        call map_addr
        ld a,(hl)
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
        call .half
        inc d
        call cell_addr
        call .half
        dec d
        ret
.half:  push de
        ld de,(spr_ptr)
        ld c,8
.line:  push hl
        ld b,4
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
        ld (spr_ptr),de
        pop de
        ret

row_scr:
rowi = 0
        repeat 25
        dw SCREEN + rowi*SCR_ROW_BYTES
rowi = rowi + 1
        rend
