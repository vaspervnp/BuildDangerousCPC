; ---------------------------------------------------------------- trap vignettes
; A vignette is a short script of full 16x16 Thanos frames drawn where he stands:
;   db frame (VF_*), frames to hold, fx flags ... terminated by VIG_END.
; Input is locked while it plays; when it ends the hazard is disarmed.

VIG_END         equ #ff
FX_FLASH        equ 1           ; turn pen 0 white for this step

; Frames in build/vignettes.bin
VF_ZAP_A        equ 0           ; lit up, hat blown off his head
VF_ZAP_B        equ 1           ; x-ray
VF_ZAP_C        equ 2           ; singed and smoking

vig_electric:
        db VF_ZAP_A, 3, FX_FLASH
        db VF_ZAP_B, 3, 0
        db VF_ZAP_A, 3, FX_FLASH
        db VF_ZAP_B, 3, 0
        db VF_ZAP_A, 3, FX_FLASH
        db VF_ZAP_B, 5, 0
        db VF_ZAP_C, 30, 0
        db VIG_END

; In: IX = hazard entry. Charges the energy, shows the caption, starts the script.
vig_start:
        ld (vig_hazard),ix
        ld a,(ix+HZ_TYPE)
        call hz_type_entry
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld (vig_ptr),de
        inc hl
        inc hl
        inc hl
        ld b,(hl)               ; cost
        dec hl
        ld a,(hl)               ; caption
        push af
        call energy_lose
        pop af
        call caption_show
        xor a
        ld (vig_timer),a
        ld a,PS_VIGNETTE
        ld (pl_state),a
        ret

vig_update:
        ld a,(vig_timer)
        or a
        jr z,.step
        dec a
        ld (vig_timer),a
        ret
.step:  ld hl,(vig_ptr)
        ld a,(hl)
        cp VIG_END
        jr z,.done
        ld c,a                  ; frame
        inc hl
        ld a,(hl)
        ld (vig_timer),a
        inc hl
        ld a,(hl)               ; fx
        inc hl
        ld (vig_ptr),hl
        push bc
        call set_flash
        ld de,(pl_x)
        call restore_2x2
        pop bc
        ld l,c                  ; HL = vignette_gfx + frame*128
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,vignette_gfx
        add hl,de
        ld de,(pl_x)
        jp draw_sprite16

.done:  xor a
        call set_flash
        ld ix,(vig_hazard)
        ld (ix+HZ_STATE),HZ_DISARMED
        ld e,(ix+HZ_X)
        ld d,(ix+HZ_ROW)
        call draw_cell
        ld a,PS_WALK
        ld (pl_state),a
        ld de,(pl_x)
        call restore_2x2
        jp player_draw
