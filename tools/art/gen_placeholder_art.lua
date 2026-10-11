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
-- Clock dial: ring with the time left as an orange pie, emptying clockwise from 12 o'clock.
local function dial(eighthsGone)
  local rows = {}
  for y = 0, 7 do
    local r = {}
    for x = 0, 7 do
      local dx, dy = x - 3.5, y - 3.5
      local d = math.sqrt(dx * dx + dy * dy)
      local ch = "K"
      if d <= 3.9 then
        if d > 2.9 then
          ch = "W"
        else
          local a = math.atan(dx, -dy)
          if a < 0 then a = a + 2 * math.pi end
          ch = (a / (2 * math.pi) < eighthsGone / 8) and "K" or "O"
        end
      end
      r[#r + 1] = ch
    end
    rows[#rows + 1] = table.concat(r)
  end
  return rows
end

gen.tiles = function()
  local list = {
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
    { "KKKKKKKK","KKKWBKKK","KKWWKBKK","KWWWKKBK","KWWOKKBK","WWWWBBBB","KKKKKKKK","KKKKKKKK" }, -- 17 HAT_HALF
    { "KKKKKKKK","KOKKKKOK","KKOKKOKK","KKKOOKKK","KKKOOKKK","KKOKKOKK","KOKKKKOK","KKKKKKKK" }, -- 18 MISS icon
  }
  for s = 0, 8 do list[#list + 1] = dial(s) end                                                     -- 19-27 DIAL_0..8
  for _, t in ipairs({
    { "KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKWKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKK" }, -- 28 STAR
    { "KKWWWKKK","KWWWWKKK","WWWWKKKK","WWWWKKKK","WWWWKKKK","KWWWWKKK","KKWWWKKK","KKKKKKKK" }, -- 29 MOON
    { "KOOOOOOK","KOOOOWOK","KOKKKKOK","WWWWWWWW","WWWWWWWW","KOKKKKOK","KOOOOOOK","KOOOOOOK" }, -- 30 RIBBON
    { "KOOOOOOK","KOOOOWOK","KOKKKKOK","WWKOOKWW","WOKOOKOW","KOKKKKOW","KOOOOOOK","KOOOOOOK" }, -- 31 RIBBON_CUT
    -- building decor (32-39) and decoys that look like traps but aren't (40-42)
    { "WWWWWWWW","KOKBKWOK","KOKBKWOK","WWWWWWWW","KBKOKOBK","KBKOKOBK","WWWWWWWW","KKKKKKKK" }, -- 32 SHELF
    { "KKBKBKKK","KBBBKBKK","KKBBBKKK","KBKBKBKK","KKKBKKKK","KKOOOKKK","KKOOOKKK","KKKOKKKK" }, -- 33 PLANT
    { "KKKKKKKK","KKKKKKKK","WKKKKKKK","WWWKKKKK","WWWWWWWW","BBBBBBBB","BKKKKKKK","BKKKKKKK" }, -- 34 BED_L
    { "KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKKKW","WWWWWWWW","BBBBBBBB","KKKKKKKB","KKKKKKKB" }, -- 35 BED_R
    { "WWWWWWWW","WWWOOWWW","WWWOOWWW","WOOOOOOW","WOOOOOOW","WWWOOWWW","WWWOOWWW","WWWWWWWW" }, -- 36 CROSS
    { "KKKKKKKK","KKKKKKKK","KKBBBKKK","KKBWBKKK","KKKBKKKK","OOOOOOOO","OKKKKKKK","OKKKKKKK" }, -- 37 DESK_L
    { "KKKKKKKK","KKKKKKKK","KKKKKKKK","KKKKKWWK","KKKKKWWK","OOOOOOOO","KKKKKKKO","KKKKKKKO" }, -- 38 DESK_R
    { "KKKWKKKK","KKKWKKKK","KWWWWWKK","WKOKOKWK","KWKWKWKK","KOKOKOKK","KKKKKKKK","KKKKKKKK" }, -- 39 CHANDELIER
    { "KKKKKKKK","WWWWWWWW","WKWKWKWK","WKWKWKWK","WKWKWKWK","WWWWWWWW","KKKKKKKK","KKKKKKKK" }, -- 40 GRILLE (decoy)
    { "KKKKKKKK","KOOOOOKK","KOKKKOKK","KOOOOOKK","KOKKKOKK","KOOOOOKK","KKKKKKKK","KKKKKKKK" }, -- 41 DRUM (decoy)
    { "WWWWWWWW","WKWKWKWW","WKWKWKWW","WKWKWKWW","WKWKWKWW","WWWWWWWW","KKKKKKKK","KKKKKKKK" }, -- 42 VENT (decoy)
    { "WWWWWWWW","OBBBBBBK","OBBBBBKK","OBBBBKKK","OBBBKKKK","OBBKKKKK","OBKKKKKK","OKKKKKKK" }, -- 43 STAIR_R
    { "WWWWWWWW","KBBBBBBO","KKBBBBBO","KKKBBBBO","KKKKBBBO","KKKKKBBO","KKKKKKBO","KKKKKKKO" }, -- 44 STAIR_L
    { "WKWKWKWK","WOOOOOOK","WOWOOOKK","WWOWOKKK","WOOOKKKK","WOOKKKKK","WOKKKKKK","WKKKKKKK" }, -- 45 ESC_UP_R
    { "KWKWKWKW","KOOOOOOW","KKOOOWOW","KKKOWOWW","KKKKOOOW","KKKKKOOW","KKKKKKOW","KKKKKKKW" }, -- 46 ESC_UP_L
    { "WKWKWKWK","WOOOOOOK","WWOWOOKK","WOWOOKKK","WOOOKKKK","WOOKKKKK","WOKKKKKK","WKKKKKKK" }, -- 47 ESC_DN_R
    { "KWKWKWKW","KOOOOOOW","KKOOWOWW","KKKOOWOW","KKKKOOOW","KKKKKOOW","KKKKKKOW","KKKKKKKW" }, -- 48 ESC_DN_L
    { "OOOOOOOW","OOOOOOOW","OOOOOOOW","WWWWWWWW","OOOWOOOO","OOOWOOOO","OOOWOOOO","WWWWWWWW" }, -- 49 TITLE_BRICK
    { "OOOOWWWW","OOOWWWWO","OOWWWWOO","OWWWWOOO","WWWWOOOO","WWWOOOOW","WWOOOOWW","WOOOOWWW" }, -- 50 BARRIER
    { "BBBBBBBB","BWBBBWBB","BBBBBBBB","KBKKKKBK","KKBKKBKK","BBBBBBBB","BBWBBBWB","BBBBBBBB" }, -- 51 GIRDER
    { "KBBBBBKK","KBWWWBKO","KBOWOBKO","KBWWWBKO","KBBBBBOK","KBKWKBKK","KBBBBBKK","KBBBBBKK" }, -- 52 SLOT
    { "KKKKKKWW","KKKKKWWK","KKKKWKKK","KOOOWKKK","OOWOOKKK","OOOOOKKK","OOOOKKKK","KOOKKKKK" }, -- 53 GUITAR
    { "WWWWWWWW","WKKKKKKW","WKBBBBKW","WBBKKBBW","WBBKKBBW","WKBBBBKW","WKKKKKKW","WWWWWWWW" }, -- 54 AMP
    { "KKKKKKKK","KKOOOOOO","KOOOOOOO","OOOOOOOO","OOWWWWWW","OOOOOOOO","OOOOOOOO","KWKKKKKK" }, -- 55 SOFA_L
    { "KKKKKKKK","OOOOOOKK","OOOOOOOK","OOOOOOOO","WWWWWWOO","OOOOOOOO","OOOOOOOO","KKKKKKWK" }, -- 56 SOFA_R
    { "OOOOOOOO","OBBBBBBO","OBWBBBBO","OBBBBBBO","OBBOBBBO","OOOOOOOO","KKKKKKKK","KKKKKKKK" }, -- 57 PICTURE
    { "KKWWWWKK","KWKKKKWK","WKKOKKKW","WKKOKKKW","WKKOOOKW","WKKKKKKW","KWKKKKWK","KKWWWWKK" }, -- 58 CLOCK
    { "KKWKKWKK","KKKWWKKK","WWWWWWWW","WBBBBBBW","WBWBBBBW","WBBBBBBW","WWWWWWWW","KWKKKKWK" }, -- 59 TV
    { "KWWWWWWK","KWWWWWWK","KWWWWWOK","KWWWWWOK","KWWWWWWK","KWWWWWWK","KKKKKKKK","KWWWWWWK" }, -- 60 FRIDGE_T
    { "KWWWWWOK","KWWWWWOK","KWWWWWWK","KWWWWWWK","KWWWWWWK","KWWWWWWK","KWWWWWWK","KKWKKWKK" }, -- 61 FRIDGE_B
    { "KKKKKKKK","KKKKKKKK","KWWWWWWK","KKWWWWKK","KKWKWWKK","KKWKWWKK","KKWKWWKK","KKWWWWKK" }, -- 62 BIN
    { "OOOOOOOO","OBWBKWBO","OBWBKWBO","OBWBKWBO","OOOOOOOO","OWBKBWKO","OWBKBWKO","OWBKBWKO" }, -- 63 BOOKCASE_T
    { "OOOOOOOO","OKBWWBKO","OKBWWBKO","OKBWWBKO","OOOOOOOO","OKKKKKKO","OKOOOOKO","OOOOOOOO" }, -- 64 BOOKCASE_B
    { "KKKKKKKK","KKWWWWKK","KWBBBBWK","KWBBBBWK","KWBBBBWK","KKWBBWKK","KKKWWKKK","KWWWWWWK" }, -- 65 COOLER_T
    { "KWWWWWWK","KWOKWWWK","KWWWWWWK","KWWWWWWK","KWWWWWWK","KWWWWWWK","KWWWWWWK","KWKKKKWK" }, -- 66 COOLER_B
    { "KKKKKKKK","KKKKKKKK","WWWWWWWW","OOOOOOOO","OBBBBBBB","OOOOOOOO","OOOOOOOO","OOOOOOOO" }, -- 67 DESK_FRONT_L
    { "KKKOKKKK","KKOOOKKK","WWWWWWWW","OOOOOOOO","BBBBBBBB","OOOOOOOO","OOOOOOOO","OOOOOOOO" }, -- 68 DESK_FRONT_M
    { "KKKKKKKK","KKKKKKKK","WWWWWWWW","OOOOOOOO","BBBBBBBO","OOOOOOOO","OOOOOOOO","OOOOOOOO" }, -- 69 DESK_FRONT_R
  }) do list[#list + 1] = t end
  saveStrip("tiles", cells(list), 8, 8)
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

  -- Frame-building helpers. Rows are 1-based; overlays use '.' for "keep the base pixel".
  local std, stdT = concat(head, legsApart), concat(head, legsTogether)
  local E16 = string.rep(".", 16)
  local function over(base, ov)
    local t = {}
    for i = 1, 16 do
      local b, o = base[i], ov[i]
      if o then
        assert(#o == 16, "overlay row " .. i .. " has " .. #o .. " columns")
        local s = {}
        for x = 1, 16 do
          local c = o:sub(x, x)
          s[x] = (c == ".") and b:sub(x, x) or c
        end
        b = table.concat(s)
      end
      t[i] = b
    end
    return t
  end
  local function keep(base, list) -- keep only these rows, standing on the bottom edge
    local t, pad = {}, 16 - #list
    for i = 1, pad do t[i] = E16 end
    for i, r in ipairs(list) do t[pad + i] = base[r] end
    return t
  end
  local function shiftx(row, n)
    if n >= 0 then return (string.rep(".", n) .. row):sub(1, 16) end
    return (row .. string.rep(".", -n)):sub(1 - n, 16 - n)
  end
  local function shiftRows(base, from, to, n)
    local t = {}
    for i = 1, 16 do t[i] = (i >= from and i <= to) and shiftx(base[i], n) or base[i] end
    return t
  end
  local function up(base, n) -- move the whole frame up n rows (negative = down)
    local t = {}
    for i = 1, 16 do t[i] = base[i + n] or E16 end
    return t
  end
  local function flipv(base)
    local t = {}
    for i = 1, 16 do t[i] = base[17 - i] end
    return t
  end
  local function recolor(base, map)
    local t = {}
    for i = 1, 16 do t[i] = (base[i]:gsub(".", function(c) return map[c] or c end)) end
    return t
  end
  local function framed(base)
    local ov = {}
    for i = 1, 16 do ov[i] = (i == 1 or i == 16) and string.rep("W", 16) or ("W" .. string.rep(".", 14) .. "W") end
    return over(base, ov)
  end
  local walls = {}
  for i = 1, 16 do walls[i] = "WW............WW" end
  local wind = { [12] = "W.W.W.W.W.W.W.W.", [14] = ".W.W.W.W.W.W.W.W", [16] = "W.W.W.W.W.W.W.W." }

  -- bitten: the "guard ferret" hangs off his ankle
  local biteA = over(std, { [15] = "OOOWK...........", [16] = "O.O............." })
  local biteB = over(stdT, { [13] = "OOW.............", [14] = "O..O............" })
  local biteC = over(std, { [15] = "....WWW........." })                    -- bandaged
  -- drowned: room floods (palette), bubbles, a rubber duck he did not bring
  local drownA = over(std, { [1] = "..W.............", [3] = ".W..............", [5] = "W..............." })
  local drownB = over(up(std, -2), { [1] = ".......OO.......", [2] = "......OOOOW....." })
  local drownC = over(std, { [11] = "..B.............", [13] = "..B............B", [16] = "B.............B." })
  -- hit on the head: lamp lands on the hat, accordion squash, stars
  local headA = over(std, { [1] = "....OOOOOOO.....", [2] = "...OOOOOOOOO...." })
  local headB = over(keep(std, { 1, 2, 3, 4, 5, 7, 9, 10, 11, 13, 15, 16 }),
                     { [5] = "....OOOOOOO.....", [6] = "...OOOOOOOOO...." })
  local headC = over(std, { [1] = "W.W.........W.W.", [2] = ".W...........W..", [3] = "W.W.........W.W." })
  -- cut in half: doors slam, top half slides off, taped back together
  local cutA = over(std, walls)
  local cutB = shiftRows(shiftRows(std, 1, 12, 2), 13, 16, -1)
  local cutC = over(std, { [13] = "...WWWWWWWWWW..." })
  -- impaled: sits on the "cushion", leaps, plaster on the seat
  local impA = over(keep(std, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16 }), { [16] = "...W.W.W.W.W...." })
  local impB = over(stdT, { [1] = "W.............W.", [2] = "W.............W.", [4] = "W.............W." })
  local impC = over(std, { [12] = "..WW............", [13] = "..WW............" })
  -- squashed: walls close in, pancake, springs back
  local sqA = over(std, walls)
  local sqB = keep(std, { 1, 4, 6, 8, 10, 12, 14, 16 })
  local sqC = over(std, { [11] = "..W..........W..", [12] = ".W............W.", [13] = "..W..........W.." })
  -- incinerated: fireball, then a walking briquette with one unimpressed eye
  local fireA = {
    ".....OOOOOO.....",
    "...OOOOOOOOOO...",
    "..OOOWWWWWWOOO..",
    ".OOWWWWWWWWWWOO.",
    ".OOWWWWWWWWWWOO.",
    "OOWWWWWWWWWWWWOO",
    "OOWWWWKKWWWWWWOO",
    "OOWWWWWWWWWWWWOO",
    "OOWWWWWWWWWWWWOO",
    "OOWWWWWWWWWWWWOO",
    ".OOWWWWWWWWWWOO.",
    ".OOWWWWWWWWWWOO.",
    "..OOOWWWWWWOOO..",
    "...OOOOOOOOOO...",
    ".....OOOOOO.....",
    E16,
  }
  local briquette = recolor(std, { O = "K", B = "K", W = "K" })
  local fireB = over(briquette, { [7] = ".........W......", [9] = "....O...........", [12] = "......O.....O..." })
  local fireC = over(fireB, { [1] = "...W.....W......", [2] = "..W.....W......." })
  -- frozen: ice block, cracks, shards
  local iceA = framed(recolor(std, { ["."] = "B" }))
  local iceB = over(iceA, { [3] = "..K.....K.......", [4] = "...K...K........", [5] = "....K.K.....K...",
                            [6] = ".....K.....K....", [10] = "........K....K..", [11] = ".......K......K." })
  local iceC = over(std, { [3] = "W..............W", [6] = ".W............W.", [10] = "W..............W", [14] = ".W............W." })
  -- poisoned: wobble left, wobble right, deflate
  local poiA = shiftRows(std, 1, 9, -1)
  local poiB = shiftRows(std, 1, 9, 1)
  local poiC = keep(std, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 16 })
  -- sucked up: lifted, only the legs left, spat out upside down (also used for falling)
  local suckA = over(up(std, 2), wind)
  local suckB = {}
  for i = 1, 16 do suckB[i] = E16 end
  suckB[1], suckB[2] = std[15], std[16]
  suckB = over(suckB, wind)
  local suckC = flipv(std)
  -- catapulted: crouch, launch (arms up, speed lines), land with plaster and feathers
  local catA = keep(std, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 15, 16 })
  local catB = over(stdT, { [2] = "O.............O.", [3] = "B.............B.", [4] = "B.............B.",
                            [15] = "..W..........W..", [16] = "..W..........W.." })
  local catD = over(std, { [1] = "..W.........W...", [2] = "...W.......W....", [5] = "W..............W" })
  -- evidence: reading the owner's insurance papers, held up in front of his face
  local read = over(std, { [5] = "........WWWWWW..", [6] = "........WKKKKW..", [7] = "........WWWWWW..",
                           [8] = "........WKKKWW..", [9] = "........WWWWWW..", [10] = "........OWWWWO.." })

  -- on the phone to Tasha: handset at his ear, eyes on the ceiling
  local phone = over(std, { [4] = "............KKK.", [5] = ".............KWK", [6] = ".............KWK",
    [7] = ".............KWK", [8] = "............OKK.", [9] = "...........OO..." })
  saveStrip("vignettes", cells({
    zapA, zapB, zapC, biteA, biteB, biteC, drownA, drownB, drownC, headA, headB, headC,
    cutA, cutB, cutC, impA, impB, impC, sqA, sqB, sqC, fireA, fireB, fireC,
    iceA, iceB, iceC, poiA, poiB, poiC, suckA, suckB, suckC, catA, catB, catD, read, phone,
  }), 16, 16)
end

------------------------------------------------------------------ outdoor scene people (16x16)
-- Order must match AF_* in src/scene.asm (people frames start at AF_OWNER_IDLE). Frames come
-- in pairs that scenes flip between: talk/idle, cut/shrug, idle/cheer.
gen.people = function()
  local function edit(base, rows)
    local t = {}
    for i = 1, 16 do t[i] = rows[i] or base[i] end
    return t
  end
  local owner = {
    "................",
    ".....OOOOO......",
    "....OOOOOOO.....",
    "....OKOOOKO.....",
    "....OOOOOOO.....",
    "....OOKKKOO.....",
    ".....OOOOO......",
    "...KKKWOWKKK....",
    "..KKKKWOWKKKK...",
    "..KKKKWOWKKKK...",
    "..OKKKWOWKKKO...",
    "...KKKKKKKKK....",
    "...KKKKKKKKK....",
    "....KKK.KKK.....",
    "....KKK.KKK.....",
    "...KKKK.KKKK....",
  }
  local ownerTalk = edit(owner, { [6] = "....OOWWWOO.....", [8] = "...KKKWOWKKK..O.",
    [9] = "..KKKKWOWKKKKK..", [11] = "..OKKKWOWKKK...." })
  local ownerCut = edit(owner, { [8] = "...KKKWOWKKKKWW.", [9] = "..KKKKWOWKKKOWWW",
    [10] = "..KKKKWOWKKKKWW.", [11] = "..OKKKWOWKKK...." })
  local ownerShrug = edit(owner, { [8] = ".O.KKKWOWKKK.O..", [9] = ".KKKKKWOWKKKKK..",
    [11] = "..KKKKWOWKKKK..." })
  local grandma = {
    "......WWW.......",
    ".....WWWWW......",
    "....WOOOOOW.....",
    "....WOKOKOW.....",
    ".....OOOOO......",
    "......OOO.......",
    "....BBBBBBB.....",
    "...BBBBBBBBB....",
    "...OBBBBBBBO....",
    "....BBBBBBB.....",
    "....BBBBBBB.....",
    "...BBBBBBBBB....",
    "...BBBBBBBBB....",
    ".....O...O......",
    ".....O...O......",
    "....KK...KK.....",
  }
  local grandmaCheer = edit(grandma, { [7] = "..O.BBBBBBB.O...", [8] = "..BBBBBBBBBBB...", [9] = "....BBBBBBB....." })
  local man = {
    "................",
    ".....BBBBB......",
    "....BBBBBBBB....",
    ".....OOOOO......",
    ".....OKOKO......",
    ".....OOOOO......",
    "......OOO.......",
    "....WWWWWWW.....",
    "...WWWWWWWWW....",
    "...OWWWWWWWO....",
    "....WWWWWWW.....",
    "....BBBBBBB.....",
    "....BBB.BBB.....",
    "....BBB.BBB.....",
    "....BBB.BBB.....",
    "...KKKK.KKKK....",
  }
  local manCheer = edit(man, { [8] = "..O.WWWWWWW.O...", [9] = "..WWWWWWWWWWW...", [10] = "....WWWWWWW....." })
  local kid = {
    "................",
    "................",
    "................",
    "................",
    "......BBBB......",
    ".....BBBBBB.....",
    ".....OOOOOO.....",
    ".....OKOOKO.....",
    ".....OOOOOO.....",
    "....WBWBWBW.....",
    "....WBWBWBW.....",
    "....OBWBWBO.....",
    ".....BBBBB......",
    ".....BB.BB......",
    ".....BB.BB......",
    "....KKK.KKK.....",
  }
  local kidCheer = edit(kid, { [10] = "..O.WBWBWBW.O...", [11] = "...BWBWBWBWB....", [12] = ".....BWBWB......" })
  -- Bambis, the owner's nephew: influencer, cap backwards, shades, phone always out
  local nephew = {
    "......KKKK......",
    ".....KBBBBK.....",
    "....KBBBBBBKKK..",
    "....KOOOOOOK....",
    "....KKKKKKKK....",
    "....KOKKKKOK....",
    "....KOOWWOOK....",
    ".....KOOOOK.....",
    "...KKWWWWWWKK...",
    "..KWWWWBBWWWWK..",
    "..KWKWWBBWWKWK..",
    "..KOKWWWWWWKOK..",
    "....KWWWWWWK....",
    "....KKKKKKKK....",
    "....KKK..KKK....",
    "...WWWW..WWWW...",
  }
  local nephewStep = edit(nephew, { [15] = ".....KKKKKK.....", [16] = ".....WWWWWWW...." })
  local nephewSelfie = edit(nephew, { [1] = "......KKKK..KKK.", [2] = ".....KBBBBK.KWK.",
    [3] = "....KBBBBBBKKWK.", [4] = "....KOOOOOOK.KK.", [5] = "....KKKKKKKK.OK.",
    [6] = "....KOKKKKOK.OK.", [7] = "....KOOWWOOK.OK.", [8] = ".....KOOOOK..OK.",
    [9] = "...KKWWWWWWKKOK.", [10] = "..KWWWWBBWWWWK..", [11] = "..KWKWWBBWWWWK..",
    [12] = "..KOKWWWWWWWWK.." })
  saveStrip("people", cells({ owner, ownerTalk, ownerCut, ownerShrug, grandma, grandmaCheer,
    man, manCheer, kid, kidCheer, nephew, nephewStep, nephewSelfie }), 16, 16)
end

------------------------------------------------------------------ hazard tells (8x8, masked)
-- Order must match HAZARD_TYPES in tools/cpcgfx.py / HZ_* in src/hazards.asm:
-- per hazard type its armed tell (sprite type*2), then its disarmed look (type*2+1).
gen.hazards = function()
  saveStrip("hazards", cells({
    { "......W.",".WWWWWOW",".WKWKWO.",".WWWWWO.",".WKWKW.O",".WWWWW.O",".......O","......OO" }, -- electric: socket, live wire
    { "........",".WWWWW..",".WOWOW..",".WWOWW..",".WOWOW..",".WWWWW..","........","........" }, --   taped
    { "........","WWWWWWWW","WKWKWKWK","WOWKWOWK","WKWKWKWK","WWWWWWWW","........","........" }, -- bite: grille, eyes inside
    { "........","WWWWWWWW","WKWKWKWK","WKWOOKWK","WKWOOKWK","WWWWWWWW","........","........" }, --   padlocked
    { "........","BBBBBBBB","BBBOOBBB","BBBOOBBB","BBBBBBBB","....B...","........","....B..." }, -- drown: pipe valve, dripping
    { "........","BBBBBBBB","BBWOOWBB","BBWOOWBB","BBBBBBBB","........","........","........" }, --   taped
    { "...O....","....O...","...O....","..OOO...",".OOOOO..","OOOOOOO.","..WWW...","........" }, -- head: lamp on a frayed cord
    { "...B....","...B....","...B....","..OOO...",".OOOOO..","OOOOOOO.","..WWW...","........" }, --   cord fixed
    { "........",".WWWWW..",".WKKKW..",".WKOKW..",".WKKKW..",".WWWWW..","...O....","........" }, -- cut: door sensor, sparking
    { "........",".WWWWW..",".WKKKW..",".WKBKW..",".WKKKW..",".WWWWW..","........","........" }, --   reset
    { "........","........","........","........",".OOOOOO.","OWOWOWOO","OOOOOOOO","........" }, -- impale: stapled cushion
    { "........","........","........","........",".OOOOOO.","OOOOOOOO","OOOOOOOO","........" }, --   just a cushion
    { "........","WWWWWWWW","WKWKKWKW","WWWWWWWW","WKKWKWKW","WWWWWWWW","...K....","...K...." }, -- squash: "NOT A COMPACTOR"
    { "........","WWWWWWWW","WOOOOOOW","WWWWWWWW","WOOOOOOW","WWWWWWWW","...K....","...K...." }, --   struck out
    { ".W......","..W.....",".W......","........","...B....","..BWB...","..BBB...","OOOOOOO." }, -- fire: gas wisp, pilot light
    { "........","........","........","........","........","...K....","........","OOOOOOO." }, --   off
    { "BBBBBBBB","BWBBBBBB","BWWWWWBB","BWBKBWBB","BWWWWWBB","BWBBBBBB","BBBBBBBB","BBBBBBBB" }, -- ice: cracked freezer handle
    { "BBBBBBBB","BWBBBBBB","BWWWWWBB","BWOOOWBB","BWWWWWBB","BWBBBBBB","BBBBBBBB","BBBBBBBB" }, --   taped
    { "........",".OOOOO..",".OKKKO..",".OOOOO..",".OKKKO..",".OOOOO..","...B....","..BBB..." }, -- poison: leaking drum
    { "........",".OOOOO..",".OKKKO..",".OOOOO..",".OKKKO..",".OOOOO..","........","........" }, --   sealed
    { "WWWWWWWW","WKKKKKKW","WKKKKKKW","WKKKKKKW","WKKKKKKW","WWWWWWWW","W.W.W...","........" }, -- suck: vent, no grille
    { "WWWWWWWW","WKWKWKWW","WKWKWKWW","WKWKWKWW","WKWKWKWW","WWWWWWWW","........","........" }, --   grille back on
    { "...O....","...W....","..O.O...","...O....","...O....","...O....","WWWWWWWW","BBBBBBBB" }, -- catapult: frayed cable
    { "...O....","...O....","...O....","...O....","...O....","...O....","WWWWWWWW","BBBBBBBB" }, --   new cable
    { "........","........",".OOOOOO.",".WWWWWO.",".WKKWWO.",".WWWWWO.",".OOOOOO.","........" }, -- evidence: folder
    { "........","........","........","........","........","........","........","........" }, --   taken
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

------------------------------------------------------------------ Tasha (32x32 portrait)
-- Thanos's wife on the phone: orange bouffant in curlers, handset, raised eyebrows.
-- Frame 0 mouth shut, frame 1 open; they differ only inside the 8x8 mouth patch at
-- (12,22), which cpcgfx.py cuts out as its own little sprite. Background is pen 2.
gen.tasha = function()
  local function frame(open)
    local rows = {}
    for y = 0, 31 do
      local r = {}
      for x = 0, 31 do
        local function ell(cx, cy, rx, ry) local dx, dy = (x - cx) / rx, (y - cy) / ry return dx * dx + dy * dy end
        local ch = "B"
        if ell(16, 37, 15, 8) <= 1 then ch = ((x + y) % 5 == 0 and y > 30) and "W" or "K" end  -- shoulders
        local hair = ell(16, 12, 14.5, 10.5)
        if hair <= 1 then ch = (hair > 0.82) and "K" or "O" end             -- bouffant
        for _, c in ipairs({ { 7, 5 }, { 16, 2 }, { 25, 5 }, { 3, 13 }, { 29, 13 } }) do  -- curlers
          local d = ell(c[1], c[2], 2.3, 2.3)
          if d <= 1 then ch = (d < 0.3) and "B" or "W" end
        end
        local face = ell(16, 19, 8.5, 10.5)
        if face <= 1 then ch = (face > 0.8) and "K" or "W" end
        if face <= 1 and y < 12 then ch = "O" end                           -- fringe
        if y == 14 and ((x >= 11 and x <= 14) or (x >= 18 and x <= 21)) then ch = "K" end  -- brows, up
        if y == 13 and (x == 11 or x == 21) then ch = "K" end
        if (y == 16 or y == 17) and (x == 13 or x == 19) then ch = "K" end  -- eyes
        if y == 15 and (x == 12 or x == 14 or x == 18 or x == 20) then ch = "K" end  -- lashes
        if y == 21 and (x == 10 or x == 22) then ch = "O" end               -- blush
        if y == 19 and x == 16 then ch = "K" end                            -- nose
        if open then
          if y >= 23 and y <= 27 and x >= 13 and x <= 18 then
            ch = (y == 23 or y == 27 or x == 13 or x == 18) and "O" or "K"
          end
        elseif y == 24 and x >= 13 and x <= 18 then ch = "O" end
        if ell(7, 22, 1.2, 1.2) <= 1 then ch = "O" end                      -- earring
        if x >= 24 and x <= 27 and y >= 14 and y <= 28 then                  -- handset
          ch = (x == 25 and y > 15 and y < 27) and "W" or "K"
        end
        if x >= 22 and x <= 28 and y >= 26 and y <= 29 and ch ~= "K" then ch = "O" end  -- hand
        r[#r + 1] = ch
      end
      rows[#rows + 1] = table.concat(r)
    end
    return rows
  end
  saveStrip("tasha", cells({ frame(false), frame(true) }), 32, 32)
end

------------------------------------------------------------------
for name, fn in pairs(gen) do
  if ONLY == nil or ONLY[name] then fn() end
end
ONLY = nil
