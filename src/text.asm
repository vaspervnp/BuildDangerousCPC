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
