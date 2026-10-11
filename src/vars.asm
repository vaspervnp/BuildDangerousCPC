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
pl_stair:       defs 1          ; tile flags of the step he stands on mid-flight, else 0
pl_stepped:     defs 1          ; 1: this step was along a flight (walking pose, not climbing)
old_xy:         defs 2

game_state:     defs 1          ; GS_*
camp_ptr:       defs 2          ; campaign being played
camp_index:     defs 1          ; its current building
evidence:       defs 1          ; non-zero once the owner's papers are found
hi_score:       defs 3          ; BCD, this session
big_pen:        defs 1          ; double-size text
big_src:        defs 2
big_top:        defs 2
big_bottom:     defs 2
big_left:       defs 1
big_right:      defs 1
outcome:        defs 1          ; OUT_*
score:          defs 3          ; BCD, most significant byte first
bonus_time:     defs 2          ; BCD, high byte first (these three are cleared together)
bonus_energy:   defs 2
bonus_clean:    defs 2
bcd_lead:       defs 1

clock_hi:       defs 1          ; seconds left, BCD; clock_hi/clock_lo adjacent
clock_lo:       defs 1
clock_frames:   defs 1
dial_step:      defs 1          ; seconds per eighth of the dial
dial_ctr:       defs 1
dial_index:     defs 1          ; 0 full .. DIAL_STEPS empty

energy:         defs 1
border_timer:   defs 1
caption_timer:  defs 1
caption_ptr:    defs 2          ; next character to type, 0 when done
caption_col:    defs 1

vig_ptr:        defs 2
vig_timer:      defs 1
vig_hazard:     defs 2
vig_row:        defs 1          ; row the last vignette frame was drawn at

bld_ptr:        defs 2          ; building being played
bld_start:      defs 1          ; room Thanos enters first
bld_sign:       defs 1          ; STR_* lit up on the facade
bld_welcome:    defs 1          ; STR_* the owner opens with
bld_rooms:      defs 1
rooms_bcd:      defs 1
bld_signed:     defs 1          ; rooms signed off
signed_bcd:     defs 1
miss_ok:        defs 1          ; BCD: Misses still graded "good"
bld_room_list:  defs 2
bld_marked:     defs MAX_ROOMS/8 ; bit per room: signed off
cur_room:       defs 1
cur_exits:      defs 4          ; neighbours: left, right, up, down (NO_EXIT = none)
miss_tally:     defs 1          ; BCD

scene_ptr:      defs 2
scene_wait:     defs 1
scene_mode:     defs 1          ; SM_*
scene_tick:     defs 1
scene_speaker:  defs 1
scene_hold:     defs 1
scene_actor:    defs 1
scene_target:   defs 1
scene_delay:    defs 1
scene_count:    defs 1
actors:         defs ACTOR_COUNT*ACT_SIZE

room_hazards:   defs 2          ; -> hazard list inside the current room's data
room_map:       defs MAP_W*MAP_H
snd_voice0:     defs V_SIZE         ; sound.asm voices
snd_voice1:     defs V_SIZE
snd_babble:     defs 7              ; one speech syllable, built on the fly
