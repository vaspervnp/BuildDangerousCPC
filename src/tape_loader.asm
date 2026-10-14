; Tape loader for the CPC 464 (build/bd.cdt). RUN"" loads this first file and runs it,
; with the firmware still on: Mode 0 with the loading picture's inks, tape messages off,
; then SCREEN (straight onto the screen at #C000, so it appears as it loads) and GAME
; (to #0040, main.asm LOAD_ADDR), and into the game. The disk version does the same in
; BASIC (BD.BAS).
;
; The game fills memory from #0040 almost to #A600, so this sits just above it, under
; HIMEM (#A67F with a disc interface, #AB7F without), and has no 2K tape buffer of its
; own. CAS IN OPEN reads a file's first block into the buffer it is given; CAS IN DIRECT
; copies that block to the file's address and reads the rest straight into place. So each
; file's buffer is where its own second block will go: by the time that block is read
; over it, the first has been copied out. (SCREEN's would be on screen; it uses the empty
; middle of memory instead.)

CAS_NOISY       equ #bc6b
CAS_IN_OPEN     equ #bc77
CAS_IN_CLOSE    equ #bc7a
CAS_IN_DIRECT   equ #bc83
SCR_SET_MODE    equ #bc0e
SCR_SET_INK     equ #bc32
SCR_SET_BORDER  equ #bc38
GAME_ADDR       equ #0040           ; main.asm LOAD_ADDR
SCREEN_BUFFER   equ #4000
GAME_BUFFER     equ GAME_ADDR+#800  ; its second block's place

        org #a600

start:
        ld a,1                  ; no "Press PLAY" / "Loading" messages
        call CAS_NOISY
        xor a
        call SCR_SET_MODE
        ld bc,0
        call SCR_SET_BORDER
        ld hl,inks
        xor a
.ink:   push af
        push hl
        ld b,(hl)
        ld c,b
        call SCR_SET_INK
        pop hl
        pop af
        inc hl
        inc a
        cp 16
        jr nz,.ink
        ld hl,screen_name
        ld b,screen_name_end-screen_name
        ld de,SCREEN_BUFFER
        call load
        ld hl,game_name
        ld b,game_name_end-game_name
        ld de,GAME_BUFFER
        call load
        jp (hl)                 ; the game's entry point

; In: HL = file name, B = its length, DE = a 2K buffer. Loads the file at its own address.
; Out: HL = its entry address. A read error starts the machine again.
load:
        call CAS_IN_OPEN
        jr nc,.fail
        ex de,hl                ; DE = where the file goes
        call CAS_IN_DIRECT
        jr nc,.fail
        push hl
        call CAS_IN_CLOSE
        pop hl
        ret
.fail:  rst 0

screen_name:    db "SCREEN"
screen_name_end:
game_name:      db "GAME"
game_name_end:

inks:           incbin "build/inks.bin"     ; firmware colours for pens 0-15 (loadscreen.py)

        assert $ <= #a67f, "the loader must stay under HIMEM with a disc interface (#A67F)"
