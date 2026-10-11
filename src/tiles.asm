; ---------------------------------------------------------------- tile set
; Ids follow the order of assets/gfx/tiles.png and ROOM_LEGEND in tools/cpcgfx.py.

TILE_BLACK      equ 0
TILE_WALLPAPER  equ 1
TILE_FLOOR      equ 2
TILE_BRICK      equ 3
TILE_LADDER_L   equ 4
TILE_LADDER_R   equ 5
TILE_WINDOW     equ 6
TILE_DOOR_T     equ 7
TILE_DOOR_B     equ 8
TILE_LAMP       equ 9
TILE_SOCKET     equ 10          ; a safe one: the live ones are hazard overlays
TILE_HAT_FULL   equ 11          ; HUD energy icons
TILE_HAT_EMPTY  equ 12
TILE_CHECK_EMPTY equ 13         ; HUD: current room not signed off yet
TILE_CHECK_DONE equ 14
TILE_EXIT_T     equ 15          ; building exit door
TILE_EXIT_B     equ 16
TILE_HAT_HALF   equ 17          ; HUD: half a hat of energy left
TILE_MISS       equ 18          ; HUD: Miss tally icon
TILE_DIAL_0     equ 19          ; HUD: clock dial, full ... TILE_DIAL_0+8 empty

TILEF_SOLID     equ 1
TILEF_CLIMB     equ 2

tile_flags:
        db 0                    ; BLACK
        db 0                    ; WALLPAPER
        db TILEF_SOLID          ; FLOOR
        db TILEF_SOLID          ; BRICK
        db TILEF_CLIMB          ; LADDER_L
        db TILEF_CLIMB          ; LADDER_R
        db 0                    ; WINDOW
        db 0                    ; DOOR_T
        db 0                    ; DOOR_B
        db 0                    ; LAMP
        db 0                    ; SOCKET
        db 0                    ; HAT_FULL
        db 0                    ; HAT_EMPTY
        db 0                    ; CHECK_EMPTY
        db 0                    ; CHECK_DONE
        db 0                    ; EXIT_T
        db 0                    ; EXIT_B
        db 0                    ; HAT_HALF
        db 0                    ; MISS
        ds 9,0                  ; DIAL_0..8
