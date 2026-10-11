-- Loading screen painting for Build Dangerous. Run inside Aseprite (via MCP):
--   dofile("<repo>\\tools\\art\\gen_loadscreen.lua")
-- Paints assets/gfx/loadscreen.png (+ .aseprite): 320x200, full colour, smooth shading.
-- tools/loadscreen.py turns it into a 16-colour Mode 0 CPC screen (160x200, dithered).
--
-- The scene: dusk; a new high-rise right of centre, scaffolding and a crane swinging a
-- girder over its top; warm windows, one sparking blue, one pouring water; a darker
-- skyline behind; lit lobby doors with a red ribbon on two posts, a waiting crowd, street
-- lamps; Inspector Thanos in the foreground (white hard hat, orange hi-vis vest, clipboard),
-- unimpressed; the title in the sky: BUILD in bricks, DANGEROUS in hazard stripes.

local W, H = 320, 200
local root = "\\\\wsl.localhost\\Ubuntu\\home\\vasilhs\\repos\\BuildDangerousCPC\\assets\\gfx\\"

local px = {}
for i = 0, W * H - 1 do px[i] = { 0, 0, 0 } end

local DY = 0                                  -- vertical offset for what's being drawn
local function clamp(v) if v < 0 then return 0 elseif v > 255 then return 255 end return v end
local function set(x, y, r, g, b)
  y = y + DY
  if x >= 0 and x < W and y >= 0 and y < H then px[y * W + x] = { clamp(r), clamp(g), clamp(b) } end
end
local function get(x, y) return px[y * W + x] end
local function blend(x, y, r, g, b, a)
  y = y + DY
  if x < 0 or x >= W or y < 0 or y >= H then return end
  local c = px[y * W + x]
  px[y * W + x] = { clamp(c[1] + (r - c[1]) * a), clamp(c[2] + (g - c[2]) * a), clamp(c[3] + (b - c[3]) * a) }
end
local function rect(x0, y0, x1, y1, f)       -- f(x, y) -> r, g, b
  for y = math.max(0, y0), math.min(H - 1, y1) do
    for x = math.max(0, x0), math.min(W - 1, x1) do set(x, y, f(x, y)) end
  end
end
local function lerp(a, b, t) return a + (b - a) * t end
local function mix(c1, c2, t) return lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t) end
local function glow(cx, cy, rad, col, strength)
  for y = math.floor(cy - rad), math.ceil(cy + rad) do
    for x = math.floor(cx - rad), math.ceil(cx + rad) do
      local d = math.sqrt((x - cx) ^ 2 + ((y - cy) * 1.0) ^ 2) / rad
      if d < 1 then blend(x, y, col[1], col[2], col[3], strength * (1 - d) ^ 2) end
    end
  end
end
local function ellipse(cx, cy, rx, ry, f)
  for y = math.floor(cy - ry), math.ceil(cy + ry) do
    for x = math.floor(cx - rx), math.ceil(cx + rx) do
      local dx, dy = (x - cx) / rx, (y - cy) / ry
      if dx * dx + dy * dy <= 1 then
        local r, g, b = f(x, y, dx, dy)
        if r then set(x, y, r, g, b) end
      end
    end
  end
end
local seed = 12345
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648 return seed / 2147483648 end

------------------------------------------------------------------ sky
local top, mid, horizon = { 22, 14, 60 }, { 110, 40, 110 }, { 255, 130, 50 }
rect(0, 0, W - 1, H - 1, function(x, y)
  local t = y / 150
  if t < 0.55 then return mix(top, mid, t / 0.55) end
  return mix(mid, horizon, math.min(1, (t - 0.55) / 0.45))
end)
for i = 1, 40 do
  local x, y = math.floor(rnd() * W), math.floor(rnd() * 70)
  local b = 150 + rnd() * 105
  set(x, y, b, b, b * 0.9)
end
glow(250, 150, 90, { 255, 170, 80 }, 0.35)          -- the sun just gone

------------------------------------------------------------------ skyline behind
local x = 0
while x < W do
  local w = 14 + math.floor(rnd() * 22)
  local h = 30 + math.floor(rnd() * 55)
  local shade = 30 + rnd() * 20
  rect(x, 160 - h, x + w - 1, 160, function(xx, yy)
    return shade + 20, shade, shade + 45
  end)
  for wy = 160 - h + 4, 156, 6 do
    for wx = x + 2, x + w - 4, 5 do
      if rnd() < 0.22 then rect(wx, wy, wx + 1, wy + 2, function() return 240, 190, 110 end) end
    end
  end
  x = x + w + math.floor(rnd() * 4)
end

------------------------------------------------------------------ the tower
local BX0, BX1, BY0, BY1 = 186, 282, 34, 160       -- front face
local SX1 = 304                                      -- side face to here
rect(BX0, BY0, BX1, BY1, function(xx, yy)            -- glass and steel, lit from the west
  local t = (xx - BX0) / (BX1 - BX0)
  local v = (yy - BY0) / (BY1 - BY0)
  return lerp(120, 70, t) + v * 20, lerp(110, 70, t) + v * 10, lerp(150, 110, t)
end)
for yy = BY0, BY1 do                                 -- side face, in shadow, perspective
  local slope = (yy - BY0) * 0.0
  for xx = BX1 + 1, SX1 do
    local tt = (xx - BX1) / (SX1 - BX1)
    if yy >= BY0 + tt * 8 then set(xx, yy, 45, 40, 75) end
  end
end
for yy = BY0, BY1, 9 do                              -- floor slabs
  rect(BX0, yy, BX1, yy, function() return 160, 150, 170 end)
  for xx = BX1 + 1, SX1 do set(xx, yy + math.floor((xx - BX1) / (SX1 - BX1) * 8), 70, 60, 95) end
end
for col = 0, 7 do                                    -- windows
  for row = 0, 12 do
    local wx, wy = BX0 + 5 + col * 11, BY0 + 3 + row * 9
    if wy + 5 < BY1 - 14 then
      local lit = rnd() < 0.6
      rect(wx, wy, wx + 7, wy + 5, function(xx, yy)
        if lit then return 255, 205 - (yy - wy) * 8, 120 end
        return 40, 50, 90 + (xx - wx) * 4
      end)
      if lit then glow(wx + 3.5, wy + 2.5, 7, { 255, 200, 120 }, 0.18) end
    end
  end
end
-- a window sparking blue (electrocution waiting) and one pouring water
local ex, ey = BX0 + 5 + 2 * 11, BY0 + 3 + 6 * 9
rect(ex, ey, ex + 7, ey + 5, function() return 190, 230, 255 end)
glow(ex + 4, ey + 3, 14, { 120, 200, 255 }, 0.8)
for i = 0, 6 do set(ex + 2 + i, ey - 2 + (i % 3) * 2, 255, 255, 255) end
local wx, wy = BX0 + 5 + 6 * 11, BY0 + 3 + 9 * 9
rect(wx, wy, wx + 7, wy + 5, function() return 60, 120, 230 end)
for yy = wy + 6, wy + 30 do
  for k = 0, 2 do blend(wx + 2 + k + math.floor(math.sin(yy * 0.5) + 0.5), yy, 140, 200, 255, 0.7) end
end
-- scaffolding round the top floors
for xx = BX0 - 4, SX1 + 2, 8 do rect(xx, 14, xx + 1, BY0 + 26, function() return 200, 160, 60 end) end
for yy = 14, BY0 + 26, 7 do rect(BX0 - 4, yy, SX1 + 2, yy, function() return 200, 160, 60 end) end
for yy = 14, BY0 + 20, 7 do
  for k = 0, 6 do set(BX0 - 4 + k + (yy % 14 == 0 and 0 or 1) * 8, yy + k, 170, 130, 50) end
end
-- the crane: mast, jib, cable, a girder swinging over the roof
rect(308, 0, 311, 160, function(xx, yy) return (yy % 6 < 3) and 230 or 200, 170, 40 end)
rect(150, 6, 319, 9, function(xx, yy) return 240, 185, 50 end)
for xx = 152, 318, 6 do for k = 0, 3 do set(xx + k, 9 - k, 200, 150, 40) end end
rect(214, 10, 215, 34, function() return 40, 40, 50 end)
rect(196, 35, 236, 38, function(xx, yy) return 110 + (yy - 35) * 20, 110, 130 end)

------------------------------------------------------------------ street level
rect(0, 160, W - 1, 167, function(xx, yy) return 120, 110, 120 end)      -- pavement
rect(0, 168, W - 1, H - 1, function(xx, yy)                                 -- road
  local t = (yy - 168) / 32
  return 40 - t * 15, 38 - t * 15, 55 - t * 15
end)
for xx = 0, W - 1, 24 do rect(xx, 184, xx + 11, 185, function() return 200, 190, 150 end) end
-- lobby doors, lit, and the ribbon
rect(220, 140, 250, 159, function(xx, yy) return 255, 225, 160 end)
rect(234, 140, 235, 159, function() return 90, 80, 90 end)
glow(235, 152, 30, { 255, 210, 140 }, 0.35)
rect(212, 146, 213, 162, function() return 200, 180, 60 end)
rect(257, 146, 258, 162, function() return 200, 180, 60 end)
for xx = 214, 256 do
  local yy = 151 + math.floor(2.5 * math.sin((xx - 214) / 42 * math.pi))
  set(xx, yy, 230, 30, 40); set(xx, yy + 1, 170, 15, 30)
end
ellipse(235, 154, 3, 2.5, function() return 230, 30, 40 end)            -- the bow
-- street lamps
for _, lx in ipairs({ 140, 290 }) do
  rect(lx, 128, lx + 1, 167, function() return 50, 50, 60 end)
  rect(lx - 3, 126, lx + 4, 128, function() return 255, 240, 200 end)
  glow(lx + 0.5, 132, 26, { 255, 220, 150 }, 0.45)
end
-- the crowd, waiting
for i = 0, 15 do
  local cx = 120 + i * 6 + math.floor(rnd() * 3)
  local hh = 8 + math.floor(rnd() * 4)
  local cr, cg, cb = 30 + rnd() * 30, 20 + rnd() * 20, 50 + rnd() * 30
  rect(cx - 2, 166 - hh, cx + 2, 166, function() return cr, cg, cb end)
  ellipse(cx, 164 - hh, 2, 2, function() return cr + 30, cg + 20, cb + 10 end)
end

------------------------------------------------------------------ Inspector Thanos
-- foreground, left of centre: about 110 px tall, warm light from the right
local TX = 62
DY = 34                                       -- stands lower than the title
local function shade(base, xx, cx, rx)        -- light from the right
  local t = (xx - (cx - rx)) / (2 * rx)
  return base[1] * (0.55 + 0.6 * t), base[2] * (0.55 + 0.6 * t), base[3] * (0.55 + 0.6 * t)
end
-- legs
rect(TX - 16, 160, TX - 3, 199, function(xx) return shade({ 55, 55, 75 }, xx, TX, 18) end)
rect(TX + 3, 160, TX + 16, 199, function(xx) return shade({ 55, 55, 75 }, xx, TX, 18) end)
-- torso: dark shirt, hi-vis vest with reflective stripes
ellipse(TX, 132, 30, 34, function(xx, yy, dx, dy)
  local vest = math.abs(dx) > 0.18
  local base = vest and { 255, 120, 20 } or { 60, 70, 90 }
  if vest and (math.abs(yy - 128) <= 2 or math.abs(yy - 146) <= 2) then base = { 225, 225, 230 } end
  return shade(base, xx, TX, 30)
end)
-- arms; the right one holding the clipboard
rect(TX - 36, 112, TX - 26, 160, function(xx) return shade({ 255, 120, 20 }, xx, TX - 31, 6) end)
rect(TX + 26, 112, TX + 36, 140, function(xx) return shade({ 255, 120, 20 }, xx, TX + 31, 6) end)
ellipse(TX - 31, 163, 6, 5, function(xx) return shade({ 230, 160, 110 }, xx, TX - 31, 6) end)
rect(TX + 16, 128, TX + 44, 166, function(xx, yy)                -- clipboard
  if yy < 132 and xx > TX + 26 and xx < TX + 34 then return 170, 170, 180 end
  if xx < TX + 18 or xx > TX + 42 or yy > 164 then return 120, 80, 40 end
  if (yy - 136) % 6 == 0 and xx > TX + 20 and xx < TX + 40 then return 90, 90, 110 end
  return 240, 240, 230
end)
for i = 0, 6 do set(TX + 22 + i, 150 - math.abs(i - 3), 220, 40, 40) end   -- a cross on it
ellipse(TX + 36, 150, 6, 5, function(xx) return shade({ 230, 160, 110 }, xx, TX + 36, 6) end)
-- head
ellipse(TX, 86, 17, 20, function(xx, yy, dx, dy) return shade({ 235, 165, 115 }, xx, TX, 17) end)
rect(TX - 9, 82, TX - 4, 83, function() return 40, 30, 30 end)     -- weary eyes
rect(TX + 4, 82, TX + 9, 83, function() return 40, 30, 30 end)
rect(TX - 10, 78, TX - 3, 79, function() return 90, 60, 40 end)    -- flat brows
rect(TX + 3, 78, TX + 10, 79, function() return 90, 60, 40 end)
rect(TX - 6, 96, TX + 6, 97, function() return 150, 70, 60 end)    -- a straight mouth
ellipse(TX + 1, 90, 2.5, 3, function(xx) return shade({ 215, 140, 95 }, xx, TX, 17) end)
-- hard hat
ellipse(TX, 68, 21, 14, function(xx, yy, dx, dy)
  if yy > 70 then return nil end
  local r, g, b = shade({ 250, 250, 245 }, xx, TX, 21)
  if dx > 0.2 and dx < 0.45 and dy < -0.3 then return 255, 255, 255 end
  return r, g, b
end)
rect(TX - 26, 70, TX + 26, 73, function(xx) return shade({ 230, 230, 225 }, xx, TX, 26) end)
rect(TX - 2, 54, TX + 2, 70, function(xx) return 210, 210, 205 end)
glow(TX + 40, 100, 70, { 255, 190, 120 }, 0.12)      -- warm rim light from the lobby
DY = 0

------------------------------------------------------------------ the title: BUILD in bricks, DANGEROUS in hazard stripes
local FONT = {
  B = { "11110", "10001", "10001", "11110", "10001", "10001", "11110" },
  U = { "10001", "10001", "10001", "10001", "10001", "10001", "01110" },
  I = { "11111", "00100", "00100", "00100", "00100", "00100", "11111" },
  L = { "10000", "10000", "10000", "10000", "10000", "10000", "11111" },
  D = { "11110", "10001", "10001", "10001", "10001", "10001", "11110" },
  A = { "01110", "10001", "10001", "11111", "10001", "10001", "10001" },
  N = { "10001", "11001", "10101", "10101", "10011", "10001", "10001" },
  G = { "01111", "10000", "10000", "10111", "10001", "10001", "01111" },
  E = { "11111", "10000", "10000", "11110", "10000", "10000", "11111" },
  R = { "11110", "10001", "10001", "11110", "10100", "10010", "10001" },
  O = { "01110", "10001", "10001", "10001", "10001", "10001", "01110" },
  S = { "01111", "10000", "10000", "01110", "00001", "00001", "11110" },
}
local function word(text, ox, oy, cell, paint, advance)
  advance = advance or 6 * cell
  for i = 1, #text do
    local g = FONT[text:sub(i, i)]
    for r = 1, 7 do
      for c = 1, 5 do
        if g[r]:sub(c, c) == "1" then
          local x0, y0 = ox + (i - 1) * advance + (c - 1) * cell, oy + (r - 1) * cell
          for yy = y0, y0 + cell - 1 do
            for xx = x0, x0 + cell - 1 do set(xx, yy, paint(xx, yy, x0, y0)) end
          end
          -- drop shadow
          for yy = y0 + 2, y0 + cell + 1 do blend(x0 + cell, yy, 10, 5, 20, 0.6) end
          for xx = x0 + 2, x0 + cell do blend(xx, y0 + cell, 10, 5, 20, 0.6) end
        end
      end
    end
  end
end
local function brick(xx, yy)
  local by = math.floor(yy / 4)
  local bx = math.floor((xx + (by % 2) * 4) / 8)
  if yy % 4 == 3 or (xx + (by % 2) * 4) % 8 == 7 then return 215, 200, 185 end   -- mortar
  local v = ((bx * 7 + by * 13) % 5) * 9
  return 180 + v, 60 + v * 0.5, 40
end
word("BUILD", 8, 6, 6, brick)                       -- 6 px blocks: 174 x 42
-- DANGEROUS on a construction banner: black, hazard tape top and bottom, solid yellow
-- letters in exact CPC colours (so the dithering leaves them alone), 4 px blocks
rect(0, 52, W - 1, 87, function(xx, yy)
  if yy <= 54 or yy >= 85 then
    if (xx + yy) % 12 < 6 then return 255, 255, 0 end
    return 0, 0, 0
  end
  return 0, 0, 0
end)
word("DANGEROUS", 50, 57, 4, function() return 255, 255, 0 end, 24)   -- 212 x 28, centred

------------------------------------------------------------------ save
local spr = Sprite(W, H, ColorMode.RGB)
local img = Image(W, H, ColorMode.RGB)
for y = 0, H - 1 do
  for x = 0, W - 1 do
    local c = px[y * W + x]
    img:drawPixel(x, y, app.pixelColor.rgba(math.floor(c[1]), math.floor(c[2]), math.floor(c[3]), 255))
  end
end
spr:newCel(spr.layers[1], 1, img, Point(0, 0))
spr:saveAs(root .. "loadscreen.aseprite")
spr:saveCopyAs(root .. "loadscreen.png")
spr:close()
print("loadscreen: " .. W .. "x" .. H)
