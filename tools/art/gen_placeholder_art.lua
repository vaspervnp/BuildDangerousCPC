-- Bootstrap generator for placeholder art. Run inside Aseprite (via MCP: dofile on this path).
-- Writes assets/gfx/*.aseprite (editable sources) and *.png (consumed by tools/cpcgfx.py).
-- Re-running OVERWRITES hand-edited art; once art is polished in Aseprite, stop using this.

local root = "\\\\wsl.localhost\\Ubuntu\\home\\vasilhs\\repos\\BuildDangerousCPC\\assets\\gfx\\"

local function rgba(r, g, b) return app.pixelColor.rgba(r, g, b, 255) end

-- Mode 1 palette for building 1: K=black O=orange B=sky blue W=bright white. '.' = transparent.
local pal = { K = rgba(0, 0, 0), O = rgba(255, 128, 0), B = rgba(0, 128, 255), W = rgba(255, 255, 255) }

local function paint(img, ox, oy, rows, mirror)
  for y, row in ipairs(rows) do
    local w = #row
    for x = 1, w do
      local c = pal[row:sub(x, x)]
      if c then
        local px = mirror and (w - x) or (x - 1)
        img:drawPixel(ox + px, oy + y - 1, c)
      end
    end
  end
end

local function setPal(spr)
  local p = Palette(4)
  p:setColor(0, Color{ r = 0, g = 0, b = 0 })
  p:setColor(1, Color{ r = 255, g = 128, b = 0 })
  p:setColor(2, Color{ r = 0, g = 128, b = 255 })
  p:setColor(3, Color{ r = 255, g = 255, b = 255 })
  spr:setPalette(p)
end

------------------------------------------------------------------ tiles (8x8)
-- Order must match TILE_* constants in src/tiles.asm.
local tiles = {
  { -- 0 BLACK
    "KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK" },
  { -- 1 WALLPAPER
    "KKKKKKKK","KKKBKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKB","KKKKKKKK","KKKKKKKK" },
  { -- 2 FLOOR slab
    "WWWWWWWW","OOOOOOKO","OOOOOOKO","KKKKKKKK","BKBBBBBB","BBBBBKBB","BBKBBBBB","KKKKKKKK" },
  { -- 3 BRICK
    "BBBBBBBK","BBBBBBBK","BBBBBBBK","KKKKKKKK","BBBKBBBB","BBBKBBBB","BBBKBBBB","KKKKKKKK" },
  { -- 4 LADDER_L
    "KWKKKKKK","KWKKKKKK","KWWWWWWW","KWKKKKKK","KWKKKKKK","KWKKKKKK","KWWWWWWW","KWKKKKKK" },
  { -- 5 LADDER_R
    "KKKKKKWK","KKKKKKWK","WWWWWWWK","KKKKKKWK","KKKKKKWK","KKKKKKWK","WWWWWWWK","KKKKKKWK" },
  { -- 6 WINDOW
    "OOOOOOOO","OBBBOBBO","OBWBOBBO","OBBBOBBO","OOOOOOOO","OBBBOBBO","OBBBOBWO","OOOOOOOO" },
  { -- 7 DOOR_T
    "KKKKKKKK","KOOOOOOK","KOKKKKOK","KOKOOKOK","KOKOOKOK","KOKKKKOK","KOOOOOOK","KOOOOOOK" },
  { -- 8 DOOR_B
    "KOOOOOOK","KOOOOWOK","KOKKKKOK","KOKOOKOK","KOKOOKOK","KOKKKKOK","KOOOOOOK","KOOOOOOK" },
  { -- 9 LAMP
    "KKKBKKKK","KKKBKKKK","KKKBKKKK","KKOOOKKK","KOOOOOKK","OOOOOOOK","KKWWWKKK","KKKKKKKK" },
}

do
  local n = #tiles
  local spr = Sprite(8 * n, 8, ColorMode.RGB)
  setPal(spr)
  local img = Image(8 * n, 8, ColorMode.RGB)
  for i, t in ipairs(tiles) do paint(img, (i - 1) * 8, 0, t) end
  spr:newCel(spr.layers[1], 1, img, Point(0, 0))
  spr:saveAs(root .. "tiles.aseprite")
  spr:saveCopyAs(root .. "tiles.png")
  spr:close()
  print("tiles: " .. n)
end

------------------------------------------------------------------ Thanos (16x16)
local head = {
  "......KKKKK.....",
  ".....KWWWWWK....",
  "....KWWWWWWWK...",
  "...KKKKKKKKKKKK.",
  "....KOOOOOOOK...",
  "....KOOOKKOOK...",
  "....KOOOOKOOK...",
  "....KOOOOOOOOK..",
  "....KOOKKKKOK...",
  ".....KKOOOOKK...",
  "....KBBBBBBKWWK.",
  "...KBBBBBBBKWWK.",
  "...KBBKBBBOOWWK.",
  "....KBBBBBBKKK..",
}
local function withLegs(a, b)
  local t = {}
  for i, r in ipairs(head) do t[i] = r end
  t[15] = a; t[16] = b
  return t
end

local walk0 = withLegs("....KKK..KKK....", "...KKKK..KKKK...")
local walk1 = withLegs(".....KKKKKK.....", ".....KKKKKKK....")
local climb = {
  "....KKKKKKKK....",
  "...KWWWWWWWWK...",
  "..KWWWWWWWWWWK..",
  ".KKKKKKKKKKKKKK.",
  "...KKKKKKKKKK...",
  "OK.KKKKKKKKKK...",
  "OK.KKKKKKKKKK...",
  "BK..KOOOOOOK....",
  "BKKKBBBBBBBBKKK.",
  ".KBBBBBBBBBBBBK.",
  "..KBBBBBBBBBBKBK",
  "..KBBBBBBBBBBKOK",
  "..KBBBBBBBBBBK..",
  "..KKKKKKKKKKKK..",
  "..KKKK....KKKK..",
  "..KKKK....KKKK..",
}

-- Frame order must match THANOS_* constants in src/player.asm:
-- 0 walk-right A, 1 walk-right B, 2 climb A, 3 climb B (mirrored climb A).
-- Left-facing frames are produced by cpcgfx.py --mirror, not drawn here.
local frames = { { walk0, false }, { walk1, false }, { climb, false }, { climb, true } }

do
  local spr = Sprite(16, 16, ColorMode.RGB)
  setPal(spr)
  local sheet = Image(16 * #frames, 16, ColorMode.RGB)
  for i, f in ipairs(frames) do
    if i > 1 then spr:newEmptyFrame() end
    local img = Image(16, 16, ColorMode.RGB)
    paint(img, 0, 0, f[1], f[2])
    spr:newCel(spr.layers[1], i, img, Point(0, 0))
    paint(sheet, (i - 1) * 16, 0, f[1], f[2])
  end
  spr:saveAs(root .. "thanos.aseprite")
  spr:close()
  local s2 = Sprite(16 * #frames, 16, ColorMode.RGB)
  s2:newCel(s2.layers[1], 1, sheet, Point(0, 0))
  s2:saveCopyAs(root .. "thanos.png")
  s2:close()
  print("thanos frames: " .. #frames)
end
