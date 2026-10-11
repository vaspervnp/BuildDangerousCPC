; ---------------------------------------------------------------- trap vignettes
; A vignette is a short script of full 16x16 Thanos frames. Each step is 4 bytes:
;   db frame (VF_* or VF_NONE), frames to hold, fx (FX_*), dy (signed rows from where he stands)
; terminated by VIG_END. Input is locked while it plays; when it ends the hazard is disarmed.
; FX recolour pen 0 (the background) for the step: the room floods, fills with gas, etc.

VIG_END         equ #ff
VF_NONE         equ #fe             ; draw nothing: he is off screen / inside the vent

FX_NONE         equ 0
FX_FLASH        equ 1
FX_FIRE         equ 2
FX_WATER        equ 3
FX_GAS          equ 4
FX_ICE          equ 5
FX_DUST         equ 6

fx_inks:        ; pen 0 ink per FX_*
        db INK_BLACK, INK_BRWHITE, #4c, #44, #56, #5b, #40
                ;      flash   bright red, blue, green, pastel cyan, grey

; Frames in build/vignettes.bin
VF_ZAP_A        equ 0               ; lit up, hat blown off his head
VF_ZAP_B        equ 1               ; x-ray
VF_ZAP_C        equ 2               ; singed and smoking
VF_BITE_A       equ 3
VF_BITE_B       equ 4
VF_BITE_C       equ 5               ; bandaged ankle
VF_DROWN_A      equ 6               ; bubbles
VF_DROWN_B      equ 7               ; bobbing, rubber duck on the hat
VF_DROWN_C      equ 8               ; dripping
VF_HEAD_A       equ 9               ; lamp on the hat
VF_HEAD_B       equ 10              ; accordion
VF_HEAD_C       equ 11              ; stars
VF_CUT_A        equ 12              ; doors slam
VF_CUT_B        equ 13              ; two halves
VF_CUT_C        equ 14              ; taped together
VF_IMP_A        equ 15              ; sits down
VF_IMP_B        equ 16              ; leaps
VF_IMP_C        equ 17              ; plaster
VF_SQ_A         equ 18              ; walls close in
VF_SQ_B         equ 19              ; pancake
VF_SQ_C         equ 20              ; springs back
VF_FIRE_A       equ 21              ; fireball
VF_FIRE_B       equ 22              ; briquette
VF_FIRE_C       equ 23              ; smoking briquette
VF_ICE_A        equ 24              ; ice block
VF_ICE_B        equ 25              ; cracking
VF_ICE_C        equ 26              ; shards
VF_POI_A        equ 27              ; wobble left
VF_POI_B        equ 28              ; wobble right
VF_POI_C        equ 29              ; deflated
VF_SUCK_A       equ 30              ; lifted
VF_SUCK_B       equ 31              ; legs only
VF_UPSIDE_DOWN  equ 32              ; spat out / falling back down
VF_CAT_A        equ 33              ; crouch
VF_CAT_B        equ 34              ; launched
VF_CAT_D        equ 35              ; landed, plaster and feathers
VF_READ         equ 36              ; reading the owner's papers

vig_electric:
        db VF_ZAP_A, 3, FX_FLASH, 0
        db VF_ZAP_B, 3, FX_NONE, 0
        db VF_ZAP_A, 3, FX_FLASH, 0
        db VF_ZAP_B, 3, FX_NONE, 0
        db VF_ZAP_A, 3, FX_FLASH, 0
        db VF_ZAP_B, 5, FX_NONE, 0
        db VF_ZAP_C, 30, FX_NONE, 0
        db VIG_END

vig_bite:
        db VF_BITE_A, 3, FX_NONE, 0
        db VF_BITE_B, 3, FX_NONE, 0
        db VF_BITE_A, 3, FX_NONE, 0
        db VF_BITE_B, 3, FX_NONE, 0
        db VF_BITE_A, 3, FX_NONE, 0
        db VF_BITE_B, 3, FX_NONE, 0
        db VF_BITE_C, 30, FX_NONE, 0
        db VIG_END

vig_drown:
        db VF_DROWN_A, 6, FX_WATER, 0
        db VF_DROWN_B, 6, FX_WATER, 0
        db VF_DROWN_A, 6, FX_WATER, 0
        db VF_DROWN_B, 10, FX_WATER, 0
        db VF_DROWN_C, 30, FX_NONE, 0
        db VIG_END

vig_head:
        db VF_HEAD_A, 4, FX_NONE, 0
        db VF_HEAD_B, 2, FX_DUST, 0
        db VF_HEAD_B, 10, FX_NONE, 0
        db VF_HEAD_C, 30, FX_NONE, 0
        db VIG_END

vig_cut:
        db VF_CUT_A, 3, FX_DUST, 0
        db VF_CUT_B, 20, FX_NONE, 0
        db VF_CUT_C, 30, FX_NONE, 0
        db VIG_END

vig_impale:
        db VF_IMP_A, 6, FX_NONE, 0
        db VF_IMP_B, 3, FX_NONE, -1
        db VF_IMP_B, 3, FX_NONE, -2
        db VF_IMP_B, 3, FX_NONE, -1
        db VF_IMP_C, 30, FX_NONE, 0
        db VIG_END

vig_squash:
        db VF_SQ_A, 4, FX_NONE, 0
        db VF_SQ_B, 2, FX_DUST, 0
        db VF_SQ_B, 14, FX_NONE, 0
        db VF_SQ_C, 30, FX_NONE, 0
        db VIG_END

vig_fire:
        db VF_FIRE_A, 3, FX_FIRE, 0
        db VF_FIRE_A, 3, FX_FLASH, 0
        db VF_FIRE_A, 3, FX_FIRE, 0
        db VF_FIRE_A, 3, FX_FLASH, 0
        db VF_FIRE_B, 10, FX_NONE, 0
        db VF_FIRE_C, 30, FX_NONE, 0
        db VIG_END

vig_ice:
        db VF_ICE_A, 20, FX_ICE, 0
        db VF_ICE_B, 8, FX_ICE, 0
        db VF_ICE_C, 30, FX_NONE, 0
        db VIG_END

vig_poison:
        db VF_POI_A, 4, FX_GAS, 0
        db VF_POI_B, 4, FX_GAS, 0
        db VF_POI_A, 4, FX_GAS, 0
        db VF_POI_B, 4, FX_GAS, 0
        db VF_POI_C, 30, FX_NONE, 0
        db VIG_END

vig_suck:
        db VF_SUCK_A, 4, FX_NONE, -1
        db VF_SUCK_B, 4, FX_NONE, -2
        db VF_NONE, 20, FX_NONE, 0
        db VF_UPSIDE_DOWN, 3, FX_DUST, 0
        db VF_UPSIDE_DOWN, 20, FX_NONE, 0
        db VIG_END

vig_catapult:                       ; up through every floor above, then back down
        db VF_CAT_A, 8, FX_NONE, 0
        db VF_CAT_B, 2, FX_NONE, -3
        db VF_CAT_B, 2, FX_NONE, -6
        db VF_CAT_B, 2, FX_NONE, -9
        db VF_CAT_B, 2, FX_NONE, -12
        db VF_CAT_B, 2, FX_NONE, -15
        db VF_CAT_B, 2, FX_NONE, -19
        db VF_NONE, 15, FX_NONE, 0
        db VF_UPSIDE_DOWN, 2, FX_NONE, -19
        db VF_UPSIDE_DOWN, 2, FX_NONE, -15
        db VF_UPSIDE_DOWN, 2, FX_NONE, -11
        db VF_UPSIDE_DOWN, 2, FX_NONE, -7
        db VF_UPSIDE_DOWN, 2, FX_NONE, -3
        db VF_CAT_D, 3, FX_DUST, 0
        db VF_CAT_D, 30, FX_NONE, 0
        db VIG_END

vig_evidence:
        db VF_READ, 50, FX_NONE, 0
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
        ld a,(pl_y)
        ld (vig_row),a
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
        ld b,(hl)               ; dy
        inc hl
        ld (vig_ptr),hl
        push bc
        call set_fx
        call vig_erase
        pop bc
        ld a,(pl_y)             ; row = pl_y + dy, kept below the HUD
        add a,b
        cp HUD_ROWS
        jr c,.clamp
        cp #80
        jr c,.row
.clamp: ld a,HUD_ROWS
.row:   ld (vig_row),a
        ld a,c
        cp VF_NONE
        ret z
        ld l,a                  ; HL = vignette_gfx + frame*128
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
        ld a,(vig_row)
        ld d,a
        ld a,(pl_x)
        ld e,a
        jp draw_sprite16

.done:  xor a
        call set_fx
        call vig_erase
        ld ix,(vig_hazard)
        ld (ix+HZ_STATE),HZ_DISARMED
        ld e,(ix+HZ_X)
        ld d,(ix+HZ_ROW)
        call draw_cell
        ld de,SCORE_DISARM
        ld a,(ix+HZ_TYPE)
        cp HZ_EVIDENCE
        jr nz,.score
        ld (evidence),a         ; non-zero: found
        ld de,SCORE_EVIDENCE
.score: call score_add
        ld a,PS_WALK
        ld (pl_state),a
        jp player_draw

; Restore the background where the last vignette frame was drawn.
vig_erase:
        ld a,(vig_row)
        ld d,a
        ld a,(pl_x)
        ld e,a
        jp restore_2x2

; In: A = FX_*. Sets pen 0 to that effect's ink. Trashes AF,BC,HL.
set_fx:
        ld hl,fx_inks
        add a,l
        ld l,a
        adc a,h
        sub l
        ld h,a
        ld a,(hl)
        jp set_pen0
