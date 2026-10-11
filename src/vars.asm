; ---------------------------------------------------------------- variables
; Uninitialised RAM; it is part of the loaded binary for now (small enough not to matter).

keys:           defs 1
kb_matrix:      defs 10
spr_ptr:        defs 2

pl_x:           defs 1          ; pl_x/pl_y adjacent: `ld de,(pl_x)` gives E=x, D=y
pl_y:           defs 1
pl_dir:         defs 1
pl_anim:        defs 1
pl_climb:       defs 1
pl_wait:        defs 1
pl_onladder:    defs 1
old_xy:         defs 2

room_map:       defs MAP_W*MAP_H
