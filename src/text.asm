; ---------------------------------------------------------------- text
; Font glyphs are stored as Mode 1 tiles drawn in pen 3, so printing in pen P is
; just AND-ing each byte with that pen's mask. Strings are glyph indices ending in #ff,
; generated from assets/text/strings.txt into two parallel tables (EN / GR).

PEN1_MASK       equ #f0
PEN2_MASK       equ #0f
PEN3_MASK       equ #ff

LANG_EN         equ 0
LANG_GR         equ 1

; In: A = STR_* id. Out: HL = string in the current language. Trashes AF,DE.
get_string:
        ld l,a
        ld h,0
        add hl,hl               ; ids go past 127
        ld a,(lang)
        or a
        ld de,strings_en
        jr z,.table
        ld de,strings_gr
.table: add hl,de
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ret

; In: HL = string, D=row, E=col, C = pen mask. Out: E past the text. Trashes AF,HL.
print_str:
        ld a,(hl)
        cp #ff
        ret z
        call print_char
        inc hl
        inc e
        jr print_str

; In: HL = string, D = row, C = pen mask. Centres it on the row.
print_centered:
        push hl
        ld e,0
.len:   ld a,(hl)
        cp #ff
        jr z,.got
        inc hl
        inc e
        jr .len
.got:   ld a,MAP_W
        sub e
        srl a
        ld e,a
        pop hl
        jr print_str

; Print B BCD bytes from HL (most significant first) as 2*B digits at D,E in pen mask C.
; print_bcd blanks leading zeros (the last digit always shows); print_bcd_zeros keeps them.
; Out: E past the digits. Trashes AF,B,HL.
print_bcd_zeros:
        xor a
        jr print_bcd.go
print_bcd:
        ld a,1
.go:    ld (bcd_lead),a
.byte:  ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        call .digit
        ld a,b
        dec a
        jr nz,.lo
        ld (bcd_lead),a         ; last byte: its low digit always shows
.lo:    ld a,(hl)
        call .digit
        inc hl
        djnz .byte
        ret
.digit: and #0f
        jr nz,.show
        ld a,(bcd_lead)
        or a
        jr z,.show              ; A is 0 again below: digit zero
        xor a                   ; glyph 0 is a space
        jr .put
.show:  push af
        xor a
        ld (bcd_lead),a
        pop af
        and #0f
        add a,GLYPH_0
.put:   call print_char
        inc e
        ret

; In: A = 0-99. Out: A = the same value in BCD. Preserves BC.
bin_to_bcd:
        push bc
        ld b,-1
.tens:  inc b
        sub 10
        jr nc,.tens
        add a,10
        ld c,a
        ld a,b
        add a,a
        add a,a
        add a,a
        add a,a
        or c
        pop bc
        ret

; In: A = glyph, D=row, E=col, C = pen mask. Preserves BC,DE,HL.
print_char:
        push hl
        push de
        push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,font_gfx
        add hl,de
        pop bc
        pop de
        push de
        push bc
        push hl
        call cell_addr
        pop de
        ld b,8
.line:  ld a,(de)
        and c
        ld (hl),a
        inc de
        inc l
        ld a,(de)
        and c
        ld (hl),a
        inc de
        dec l
        ld a,h
        add a,#08
        ld h,a
        djnz .line
        pop bc
        pop de
        pop hl
        ret

; ---------------------------------------------------------------- double-size text
; Each font pixel becomes 2x2: a glyph covers 2x2 cells. Used by the title and end screens.

; In: HL = string, D = top row, C = pen mask. Centres it (each glyph is 2 cells wide).
print_big_centered:
        push hl
        ld e,0
.len:   ld a,(hl)
        cp #ff
        jr z,.got
        inc hl
        inc e
        jr .len
.got:   ld a,MAP_W/2
        sub e
        ld e,a
        pop hl
.char:  ld a,(hl)
        cp #ff
        ret z
        call print_big_char
        inc hl
        inc e
        inc e
        jr .char

; In: A = glyph, D = top row, E = left column, C = pen mask. Preserves BC,DE,HL.
print_big_char:
        push hl
        push de
        push bc
        ld b,a
        ld a,c
        ld (big_pen),a
        ld l,b
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld bc,font_gfx
        add hl,bc
        ld (big_src),hl
        call cell_addr
        ld (big_top),hl
        inc d
        call cell_addr
        ld (big_bottom),hl
        ld b,0                  ; glyph row 0-7 -> screen lines 2b and 2b+1
.row:   ld hl,(big_src)
        ld a,(hl)
        ld (big_left),a
        inc hl
        ld a,(hl)
        ld (big_right),a
        inc hl
        ld (big_src),hl
        ld a,b
        cp 4
        ld hl,(big_top)
        jr c,.half
        ld hl,(big_bottom)
.half:  ld a,b
        add a,a
        and 7
        add a,a
        add a,a
        add a,a
        add a,h                 ; + line * #800
        ld h,a
        call .line
        ld a,h
        add a,#08
        ld h,a
        call .line
        inc b
        ld a,b
        cp 8
        jr nz,.row
        pop bc
        pop de
        pop hl
        ret
.line:  push hl
        ld a,(big_left)
        call big_pixels_01
        ld (hl),a
        inc hl
        ld a,(big_left)
        call big_pixels_23
        ld (hl),a
        inc hl
        ld a,(big_right)
        call big_pixels_01
        ld (hl),a
        inc hl
        ld a,(big_right)
        call big_pixels_23
        ld (hl),a
        pop hl
        ret

; In: A = a pen-3 font byte (4 pixels). Out: A = one screen byte holding its first (01) or
; last (23) two pixels doubled, in big_pen.
big_pixels_01:
        rlca
        rlca
        jr big_widen
big_pixels_23:
        rrca
        rrca
        rrca
        rrca
big_widen:
        and 3
        push hl
        ld hl,widen_table
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(big_pen)
        and (hl)
        pop hl
        ret

widen_table:                    ; 2 pixels (bit 1 = left) -> 4 pixels, pen 3
        db #00, #33, #cc, #ff
