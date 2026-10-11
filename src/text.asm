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
        add a,a
        ld l,a
        ld h,0
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
