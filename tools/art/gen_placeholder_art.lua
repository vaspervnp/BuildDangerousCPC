-- Bootstrap generator for placeholder art. Run inside Aseprite (via MCP), e.g.:
--   ONLY = { font = true }; dofile("<repo>\\tools\\art\\gen_placeholder_art.lua")
-- With ONLY unset every asset is regenerated. Writes assets/gfx/<name>.aseprite (editable
-- source) and <name>.png (read by tools/cpcgfx.py).
-- Re-running an asset OVERWRITES hand edits to it; once it is polished in Aseprite, leave it out.

local root = "\\\\wsl.localhost\\Ubuntu\\home\\vasilhs\\repos\\BuildDangerousCPC\\assets\\gfx\\"

local function rgba(r, g, b) return app.pixelColor.rgba(r, g, b, 255) end

-- Mode 1 palette for building 1: K=black O=orange B=sky blue W=bright white. '.' = transparent.
local pal = { K = rgba(0, 0, 0), O = rgba(255, 128, 0), B = rgba(0, 128, 255), W = rgba(255, 255, 255) }

local function paint(img, ox, oy, rows, w, h, mirror, name)
  assert(#rows == h, name .. ": expected " .. h .. " rows, got " .. #rows)
  for y, row in ipairs(rows) do
    assert(#row == w, name .. " row " .. y .. ": expected " .. w .. " columns, got " .. #row)
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

-- One strip image: all cells side by side, saved as <name>.aseprite and <name>.png.
local function saveStrip(name, cells, w, h)
  local spr = Sprite(w * #cells, h, ColorMode.RGB)
  setPal(spr)
  local img = Image(w * #cells, h, ColorMode.RGB)
  for i, c in ipairs(cells) do paint(img, (i - 1) * w, 0, c.rows, w, h, c.mirror, name .. "#" .. i) end
  spr:newCel(spr.layers[1], 1, img, Point(0, 0))
  spr:saveAs(root .. name .. ".aseprite")
  spr:saveCopyAs(root .. name .. ".png")
  spr:close()
  print(name .. ": " .. #cells)
end

local function cells(list)
  local t = {}
  for i, r in ipairs(list) do t[i] = { rows = r } end
  return t
end

local gen = {}

------------------------------------------------------------------ tiles (8x8)
-- Order must match TILE_* in src/tiles.asm and ROOM_LEGEND in tools/cpcgfx.py.
gen.tiles = function()
  saveStrip("tiles", cells({
    { "KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK" }, -- 0 BLACK
    { "KKKKKKKK","KKKBKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKB","KKKKKKKK","KKKKKKKK" }, -- 1 WALLPAPER
    { "WWWWWWWW","OOOOOOKO","OOOOOOKO","KKKKKKKK","BKBBBBBB","BBBBBKBB","BBKBBBBB","KKKKKKKK" }, -- 2 FLOOR
    { "BBBBBBBK","BBBBBBBK","BBBBBBBK","KKKKKKKK","BBBKBBBB","BBBKBBBB","BBBKBBBB","KKKKKKKK" }, -- 3 BRICK
    { "KWKKKKKK","KWKKKKKK","KWWWWWWW","KWKKKKKK","KWKKKKKK","KWKKKKKK","KWWWWWWW","KWKKKKKK" }, -- 4 LADDER_L
    { "KKKKKKWK","KKKKKKWK","WWWWWWWK","KKKKKKWK","KKKKKKWK","KKKKKKWK","WWWWWWWK","KKKKKKWK" }, -- 5 LADDER_R
    { "OOOOOOOO","OBBBOBBO","OBWBOBBO","OBBBOBBO","OOOOOOOO","OBBBOBBO","OBBBOBWO","OOOOOOOO" }, -- 6 WINDOW
    { "KKKKKKKK","KOOOOOOK","KOKKKKOK","KOKOOKOK","KOKOOKOK","KOKKKKOK","KOOOOOOK","KOOOOOOK" }, -- 7 DOOR_T
    { "KOOOOOOK","KOOOOWOK","KOKKKKOK","KOKOOKOK","KOKOOKOK","KOKKKKOK","KOOOOOOK","KOOOOOOK" }, -- 8 DOOR_B
    { "KKKBKKKK","KKKBKKKK","KKKBKKKK","KKOOOKKK","KOOOOOKK","OOOOOOOK","KKWWWKKK","KKKKKKKK" }, -- 9 LAMP
    { "KKKKKKKK","KWWWWWKK","KWKWKWKK","KWWWWWKK","KWKWKWKK","KWWWWWKK","KKKKKKKK","KKKKKKKK" }, -- 10 SOCKET (safe)
    { "KKKKKKKK","KKKWWKKK","KKWWWWKK","KWWWWWWK","KWWOOWWK","WWWWWWWW","KKKKKKKK","KKKKKKKK" }, -- 11 HAT_FULL
    { "KKKKKKKK","KKKBBKKK","KKBKKBKK","KBKKKKBK","KBKKKKBK","BBBBBBBB","KKKKKKKK","KKKKKKKK" }, -- 12 HAT_EMPTY
    { "KKKKKKKK","KWWWWWWK","KWKKKKWK","KWKKKKWK","KWKKKKWK","KWKKKKWK","KWWWWWWK","KKKKKKKK" }, -- 13 CHECK_EMPTY
    { "KKKKKKKK","KWWWWWWO","KWKKKKOK","KWKKKOWK","KOKKOKWK","KWOOKKWK","KWWOWWWK","KKKKKKKK" }, -- 14 CHECK_DONE
    { "WWWWWWWW","WBBBBBBW","WBBBOBBW","WBBBOOBW","WOOOOOOW","WBBBOOBW","WBBBOBBW","WBBBBBBW" }, -- 15 EXIT_T
    { "WBBBBBBW","WBBBBBBW","WBBBBBBW","WBBBBBBW","WBBBBBBW","WBBBBBBW","WBBBBBBW","WBBBBBBW" }, -- 16 EXIT_B
  }), 8, 8)
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
local body = { table.unpack(head, 11, 14) }

local function concat(...)
  local t = {}
  for _, part in ipairs({ ... }) do for _, r in ipairs(part) do t[#t + 1] = r end end
  return t
end

local legsApart = { "....KKK..KKK....", "...KKKK..KKKK..." }
local legsTogether = { ".....KKKKKK.....", ".....KKKKKKK...." }

-- Frame order must match THANOS_* in src/player.asm: 0 walk A, 1 walk B, 2 climb A,
-- 3 climb B (mirrored climb A). Left-facing frames come from cpcgfx.py --mirror.
gen.thanos = function()
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
  saveStrip("thanos", {
    { rows = concat(head, legsApart) },
    { rows = concat(head, legsTogether) },
    { rows = climb },
    { rows = climb, mirror = true },
  }, 16, 16)
end

------------------------------------------------------------------ trap vignettes (16x16)
-- Order must match VF_* in src/vignette.asm.
gen.vignettes = function()
  local zapA = concat({
    ".....KKKKK......",
    "....KWWWWWK.....",
    "...KKKKKKKKK....",
    "..W.K.W.K.W.....",
    "....KOOOOOOOK...",
    "....KOOOKKOOK...",
    "W...KOOOOWOOK..W",
    "....KOOOOOOOOK..",
    "....KOOKKKKOK...",
    ".W...KKOOOOKK...",
    "....KBBBBBBKWWK.",
    "..WKBBBBBBBKWWK.",
    "...KBBKBBBOOWWKW",
    "....KBBBBBBKKK..",
    "..W.KKK..KKK....",
    "...KKKK..KKKK.W.",
  })
  local zapB = { -- x-ray
    "......KKKKK.....",
    ".....KWWWWWK....",
    "....KWWWWWWWK...",
    "...KKKKKKKKKKKK.",
    "....KKWWWWWKK...",
    "....KWKKWKKWK...",
    "....KWWWWWWWK...",
    "....KKWKWKWKKK..",
    "....KKKWWWKKK...",
    ".....KKKWKKK....",
    "....KWWWWWWWKWK.",
    "...KKKKWKKKKKWK.",
    "...KWWWWWWWKWWK.",
    "....KKKKWKKKKK..",
    "....KWK..KWK....",
    "...KKWK..KWKK...",
  }
  local zapC = concat({ -- singed, smoking, still unimpressed
    ".......W..W.....",
    "......W..W......",
    "......KKKKK.....",
    ".....KWWWWWK....",
    "...KKKKKKKKKKK..",
    "...K.K.K.K.K....",
    "....KKKKKKKKK...",
    "....KKKKWKKKK...",
    "....KKKKKKKKKK..",
    "....KKKKKKKKK...",
  }, body, legsApart)
  saveStrip("vignettes", cells({ zapA, zapB, zapC }), 16, 16)
end

------------------------------------------------------------------ hazard tells (8x8, masked)
-- Order must match HSPR_* in src/hazards.asm: each hazard has its armed tell, then disarmed.
gen.hazards = function()
  saveStrip("hazards", cells({
    { "......W.",".WWWWWOW",".WKWKWO.",".WWWWWO.",".WKWKW.O",".WWWWW.O",".......O","......OO" }, -- socket, live wire
    { "........",".WWWWW..",".WOWOW..",".WWOWW..",".WOWOW..",".WWWWW..","........","........" }, -- socket, taped
  }), 8, 8)
end

------------------------------------------------------------------ font (8x8, white on transparent)
-- Glyph order must match FONT_CHARS in tools/cpcgfx.py. Capitals only; Greek letters that
-- look like Latin ones (A B E Z H I K M N O P T Y X) reuse the Latin glyph.
local FONT = {
  { " ", { ".....", ".....", ".....", ".....", ".....", ".....", "....." } },
  { "A", { ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" } },
  { "B", { "####.", "#...#", "#...#", "####.", "#...#", "#...#", "####." } },
  { "C", { ".###.", "#...#", "#....", "#....", "#....", "#...#", ".###." } },
  { "D", { "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####." } },
  { "E", { "#####", "#....", "#....", "####.", "#....", "#....", "#####" } },
  { "F", { "#####", "#....", "#....", "####.", "#....", "#....", "#...." } },
  { "G", { ".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####" } },
  { "H", { "#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" } },
  { "I", { ".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###." } },
  { "J", { "..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.." } },
  { "K", { "#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#" } },
  { "L", { "#....", "#....", "#....", "#....", "#....", "#....", "#####" } },
  { "M", { "#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#" } },
  { "N", { "#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#" } },
  { "O", { ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." } },
  { "P", { "####.", "#...#", "#...#", "####.", "#....", "#....", "#...." } },
  { "Q", { ".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#" } },
  { "R", { "####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#" } },
  { "S", { ".####", "#....", "#....", ".###.", "....#", "....#", "####." } },
  { "T", { "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.." } },
  { "U", { "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." } },
  { "V", { "#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.." } },
  { "W", { "#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#." } },
  { "X", { "#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#" } },
  { "Y", { "#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.." } },
  { "Z", { "#####", "....#", "...#.", "..#..", ".#...", "#....", "#####" } },
  { "0", { ".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###." } },
  { "1", { "..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###." } },
  { "2", { ".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####" } },
  { "3", { "#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###." } },
  { "4", { "...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#." } },
  { "5", { "#####", "#....", "####.", "....#", "....#", "#...#", ".###." } },
  { "6", { "..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###." } },
  { "7", { "#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..." } },
  { "8", { ".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###." } },
  { "9", { ".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.." } },
  { ".", { ".....", ".....", ".....", ".....", ".....", ".##..", ".##.." } },
  { ",", { ".....", ".....", ".....", ".....", ".##..", "..#..", ".#..." } },
  { "!", { "..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.." } },
  { "?", { ".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.." } },
  { ":", { ".....", ".##..", ".##..", ".....", ".##..", ".##..", "....." } },
  { ";", { ".....", ".##..", ".##..", ".....", ".##..", "..#..", ".#..." } },
  { "-", { ".....", ".....", ".....", "#####", ".....", ".....", "....." } },
  { "'", { "..#..", "..#..", ".#...", ".....", ".....", ".....", "....." } },
  { "/", { "....#", "....#", "...#.", "..#..", ".#...", "#....", "#...." } },
  { "Γ", { "#####", "#....", "#....", "#....", "#....", "#....", "#...." } },
  { "Δ", { "..#..", "..#..", ".#.#.", ".#.#.", "#...#", "#...#", "#####" } },
  { "Θ", { ".###.", "#...#", "#...#", "#####", "#...#", "#...#", ".###." } },
  { "Λ", { "..#..", "..#..", ".#.#.", ".#.#.", "#...#", "#...#", "#...#" } },
  { "Ξ", { "#####", ".....", ".....", ".###.", ".....", ".....", "#####" } },
  { "Π", { "#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#" } },
  { "Σ", { "#####", "#....", ".#...", "..#..", ".#...", "#....", "#####" } },
  { "Φ", { "..#..", ".###.", "#.#.#", "#.#.#", "#.#.#", ".###.", "..#.." } },
  { "Ψ", { "#.#.#", "#.#.#", "#.#.#", ".###.", "..#..", "..#..", "..#.." } },
  { "Ω", { ".###.", "#...#", "#...#", "#...#", ".#.#.", ".#.#.", "##.##" } },
}

gen.font = function()
  local list = {}
  for i, g in ipairs(FONT) do
    local rows = {}
    for r = 1, 7 do rows[r] = "." .. g[2][r]:gsub("#", "W") .. ".." end
    rows[8] = "........"
    list[i] = rows
  end
  saveStrip("font", cells(list), 8, 8)
end

------------------------------------------------------------------
for name, fn in pairs(gen) do
  if ONLY == nil or ONLY[name] then fn() end
end
ONLY = nil
