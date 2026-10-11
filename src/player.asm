; ---------------------------------------------------------------- player (Thanos)
; Position is the top-left cell of his 2x2-cell (16x16) footprint; all movement is
; one whole cell per step. Feet are on row y+1, the floor he stands on is row y+2.

STEP_DELAY      equ 4           ; frames between walk/climb steps
FALL_DELAY      equ 1

; Frames in build/thanos.bin: 0-3 as drawn, 4-7 mirrored copies (cpcgfx.py --mirror).
THANOS_WALK_R   equ 0
THANOS_CLIMB    equ 2
THANOS_WALK_L   equ 4

PS_WALK         equ 0
PS_VIGNETTE     equ 1           ; a trap is going off: input locked
PS_DONE         equ 2           ; left the building: input locked

; Position comes from building_start.
player_init:
        xor a
        ld (pl_state),a
        ld (pl_dir),a
        ld (pl_anim),a
        ld (pl_climb),a
        ld (pl_wait),a
        jp player_draw

player_update:
        ld a,(pl_state)
        or a
        jr z,.walking
        cp PS_VIGNETTE
        jp z,vig_update
        ret

; One-shot actions are checked every frame (keys_new lasts a single frame),
; movement only on step frames.
.walking:
        ld a,(keys_new)
        and KEY_FIRE
        jr z,.no_fire
        call try_trigger
        ret c
.no_fire:
        ld a,(keys_new)
        and KEY_MARK
        jp nz,try_mark
        ld a,(keys_new)
        and KEY_UP
        jr z,.no_exit
        call at_exit
        jp c,try_exit
.no_exit:
        ld a,(pl_wait)
        or a
        jr z,.act
        dec a
        ld (pl_wait),a
        ret

.act:   ld de,(pl_x)            ; E=x, D=y
        ld (old_xy),de
        inc d                   ; feet row: hanging on a ladder?
        call flags_pair
        and b
        and TILEF_CLIMB
        ld (pl_onladder),a
        jr nz,.input
        inc d                   ; row under the feet: solid under either foot,
        call flags_pair         ; or the top of a ladder under both
        ld c,a
        and b
        and TILEF_CLIMB
        jr nz,.input
        ld a,c
        or b
        and TILEF_SOLID
        jr nz,.input
        dec d                   ; nothing: fall one row
        ld a,d
        ld (pl_y),a
        xor a
        ld (pl_climb),a
        ld a,FALL_DELAY
        jr .moved

.input: ld a,(keys)
        ld c,a
        bit 0,c                 ; KEY_UP
        jr z,.no_up
        call try_up
        jr c,.climbed
.no_up: bit 1,c                 ; KEY_DOWN
        jr z,.no_down
        call try_down
        jr c,.climbed
.no_down:
        bit 2,c                 ; KEY_LEFT
        jr z,.no_left
        call try_left
        jr c,.walked
.no_left:
        bit 3,c                 ; KEY_RIGHT
        ret z
        call try_right
        ret nc
.walked:
        xor a
        jr .pose
.climbed:
        ld a,1
.pose:  ld (pl_climb),a
        ld a,(pl_anim)
        xor 1
        ld (pl_anim),a
        ld a,STEP_DELAY
.moved: ld (pl_wait),a
        ld de,(old_xy)
        call restore_2x2
        jp player_draw

; Each try_* moves one cell and returns carry set, or returns carry clear if blocked.
; At the edge of the room they move into the neighbouring room instead, if there is one.
; When blocked they preserve C (the key bits).
try_up:
        ld a,(pl_onladder)
        or a
        ret z
        ld de,(pl_x)
        ld a,d
        cp HUD_ROWS
        jr nz,.inside
        ld a,(cur_exits+EXIT_UP)  ; top of the screen: up the ladder into the room above
        cp NO_EXIT
        ret z
        ld b,a
        ld a,MAP_H-2
        ld (pl_y),a
        jp enter_neighbour
.inside:
        dec d                   ; row above the head must be free
        call flags_pair
        or b
        and TILEF_SOLID
        ret nz
        ld a,d
        ld (pl_y),a
        scf
        ret

try_down:
        ld de,(pl_x)
        ld a,d
        cp MAP_H-2
        jr nz,.inside
        ld a,(pl_onladder)        ; bottom of the screen: down the ladder into the room below
        or a
        ret z
        ld a,(cur_exits+EXIT_DOWN)
        cp NO_EXIT
        ret z
        ld b,a
        ld a,HUD_ROWS
        ld (pl_y),a
        jp enter_neighbour
.inside:
        inc d
        inc d                   ; ladder must continue under both feet
        call flags_pair
        and b
        and TILEF_CLIMB
        ret z
        dec d
        ld a,d
        ld (pl_y),a
        scf
        ret

try_left:
        ld a,1
        ld (pl_dir),a
        ld de,(pl_x)
        ld a,e
        or a
        jr nz,.inside
        ld a,(cur_exits+EXIT_LEFT)
        cp NO_EXIT
        ret z
        ld b,a
        ld a,MAP_W-2
        ld (pl_x),a
        jp enter_neighbour
.inside:
        dec e
        call flags_col
        and TILEF_SOLID
        ret nz
        ld a,e
        ld (pl_x),a
        scf
        ret

try_right:
        xor a
        ld (pl_dir),a
        ld de,(pl_x)
        ld a,e
        cp MAP_W-2
        jr nz,.inside
        ld a,(cur_exits+EXIT_RIGHT)
        cp NO_EXIT
        ret z
        ld b,a
        xor a
        ld (pl_x),a
        jp enter_neighbour
.inside:
        inc e
        inc e
        call flags_col
        and TILEF_SOLID
        ret nz
        dec e
        ld a,e
        ld (pl_x),a
        scf
        ret

; In: B = room to enter (pl_x/pl_y already set for it). Returns carry set.
enter_neighbour:
        ld a,b
        call room_change
        scf
        ret

; Redraw the background under a 2x2 footprint. In: D=row, E=col.
restore_2x2:
        call draw_cell
        inc e
        call draw_cell
        inc d
        call draw_cell
        dec e
        jp draw_cell

player_draw:
        ld a,(pl_climb)
        or a
        jr z,.walk
        ld a,(pl_anim)
        add a,THANOS_CLIMB
        jr .frame
.walk:  ld a,(pl_dir)           ; 0 right, 1 left -> frame base 0 or 4
        add a,a
        add a,a
        ld b,a
        ld a,(pl_anim)
        add a,b
.frame: ld l,a                  ; HL = thanos_gfx + frame*128
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,thanos_gfx
        add hl,de
        ld de,(pl_x)
        jp draw_sprite16
