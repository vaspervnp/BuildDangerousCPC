; Build Dangerous - Amstrad CPC (64K), Mode 1
; Loaded at #0040, as low as memory goes (disk: RUN"BD, BD.BAS's RUN"GAME" loads it over
; the BASIC; tape: src/tape_loader.asm, which waits just above it), then takes over the
; machine: firmware and ROMs off. Below #0040 are the Z80's restart addresses (#0038 is
; ours: the interrupt handler).

LOAD_ADDR       equ #0040
        org LOAD_ADDR

start:
        di
        ld sp,#c000
        ld bc,#fa7e             ; disc drive motor off (we never return to AMSDOS)
        xor a
        out (c),a
        ld hl,#c9fb             ; RST #38 handler = EI : RET
        ld (#0038),hl
        im 1
        ld hl,vars_start        ; variables start zeroed
        ld de,vars_start+1
        ld bc,vars_end-vars_start-1
        ld (hl),0
        ldir
        ld hl,#ace1             ; xorshift needs a non-zero seed
        ld (rnd_seed),hl
        call video_init         ; also pages out the ROMs, so #0038 now reads our RAM
        call sound_init
        xor a
        ld (lang),a             ; English until L is pressed in the menu
        ld (keys),a
        call title_show
        ei

main_loop:
        call wait_vbl
        call input_read
        call sound_update
        call rand               ; keep the generator moving: player timing seeds it
        ld a,(game_state)
        cp GS_PLAY
        jr z,.play
        cp GS_RESULTS
        jr z,.results
        cp GS_TITLE
        jr z,.title
        cp GS_END
        jr z,.end
        call hud_update         ; an outdoor scene: Fire skips it
        ld a,(keys_new)
        and KEY_FIRE
        jr nz,.scene_end
        call scene_update
        jr nc,main_loop
.scene_end:
        call scene_finish
        jr main_loop
.play:  ld a,(keys_new)
        and KEY_PAUSE
        call nz,pause_toggle
        ld a,(paused)
        or a
        jr nz,main_loop         ; paused: everything waits, the clock too
        call blackout_update
        call player_update
        call nephew_update
        call worker_update
        call hint_update
        call hud_update
        call play_update
        jr main_loop
.results:
        call outcome_update
        jr main_loop
.title: call title_update
        jr main_loop
.end:   call end_update
        jr main_loop

boot_campaign:  dw campaign_main   ; the test harness pokes this to play other campaigns

        include "video.asm"
        include "input.asm"
        include "tiles.asm"
        include "room.asm"
        include "building.asm"
        include "hazards.asm"
        include "vignette.asm"
        include "player.asm"
        include "text.asm"
        include "hud.asm"
        include "outcome.asm"
        include "scene.asm"
        include "campaign.asm"
        include "sound.asm"
        include "phone.asm"
        include "nephew.asm"
        include "workers.asm"
        include "hints.asm"
        include "blackout.asm"
        include "build/strings.asm"

; ---------------------------------------------------------------- buildings
; Generated from assets/buildings/*.txt. Room data stays in RAM: hazard states are
; written into it.
        include "build/bld_sunnyvale.asm"
        include "build/bld_test.asm"
        include "build/bld_gallery.asm"
        include "build/bld_mall.asm"
        include "build/bld_hotel.asm"
        include "build/bld_hospital.asm"
        include "build/bld_hardknock.asm"
        include "build/bld_skyscraper.asm"
        include "build/room_outdoor.asm"
        include "build/title.asm"

; ---------------------------------------------------------------- assets
tiles_gfx:      incbin "build/tiles.bin"
font_gfx:       incbin "build/font.bin"
thanos_gfx:     incbin "build/thanos.bin"
vignette_gfx:   incbin "build/vignettes.bin"
hazard_gfx:     incbin "build/hazards.bin"
people_gfx:     incbin "build/people.bin"
tasha_gfx:      incbin "build/tasha.bin"

code_end:
        assert code_end < #a600, "binary overlaps AMSDOS/firmware workspace at load time"

; ---------------------------------------------------------------- variables
; Above the loaded binary, in what was AMSDOS/firmware workspace (unused once the
; firmware is off); not part of the file. Boot zeroes them. The stack grows down from #C000.
        nocode
        org #a600
vars_start:
        include "vars.asm"
vars_end:
        code
        assert vars_end < #bc00, "variables run into the stack"
