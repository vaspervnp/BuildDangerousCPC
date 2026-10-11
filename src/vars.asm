; ---------------------------------------------------------------- variables
; Uninitialised RAM; it is part of the loaded binary for now (small enough not to matter).

keys:           defs 1
keys_new:       defs 1          ; pressed this frame, not the previous one
kb_matrix:      defs 10
lang:           defs 1          ; LANG_EN / LANG_GR

spr_ptr:        defs 2
blit_w:         defs 1

pl_x:           defs 1          ; pl_x/pl_y adjacent: `ld de,(pl_x)` gives E=x, D=y
pl_y:           defs 1
pl_state:       defs 1          ; PS_*
pl_dir:         defs 1
pl_anim:        defs 1
pl_climb:       defs 1
pl_wait:        defs 1
pl_onladder:    defs 1
old_xy:         defs 2

energy:         defs 1
border_timer:   defs 1
caption_timer:  defs 1
caption_ptr:    defs 2          ; next character to type, 0 when done
caption_col:    defs 1

vig_ptr:        defs 2
vig_timer:      defs 1
vig_hazard:     defs 2
vig_row:        defs 1          ; row the last vignette frame was drawn at

bld_rooms:      defs 1
bld_room_list:  defs 2
bld_marked:     defs MAX_ROOMS/8 ; bit per room: signed off
cur_room:       defs 1
cur_exits:      defs 4          ; neighbours: left, right, up, down (NO_EXIT = none)
miss_tally:     defs 1

room_hazards:   defs 2          ; -> hazard list inside the current room's data
room_map:       defs MAP_W*MAP_H
