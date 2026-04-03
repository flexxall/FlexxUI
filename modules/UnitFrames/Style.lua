local _, ns = ...
local UF = ns.UnitFrames

function UF.GetTexturePath(name)
  return UF.const.textures[name or ""] or UF.const.textures["default"]
end

--- Player "dark zinc" fill (see ApplyPlayerHealthColor); depleted chunk uses a distinct dark red so it does not read as more grey bar.
local DARK_HEALTH_FILL_R, DARK_HEALTH_FILL_G, DARK_HEALTH_FILL_B = 0.11, 0.12, 0.14
--- Missing health (backdrop behind fill): dark wine / brown-red, visibly separate from the charcoal fill.
local DARK_HEALTH_DEFICIT_R, DARK_HEALTH_DEFICIT_G, DARK_HEALTH_DEFICIT_B = 0.34, 0.12, 0.14
local DARK_HEALTH_DEFICIT_A = 0.78

function UF.ApplyHealthBarMissingColor(bar, unit)
  if not bar then return end
  UF.EnsureDB()
  unit = unit or bar._flexxUnit
  local db = _G.FlexxUIDB or {}
  local r, g, b, a
  if unit == "player" and (db.playerHealthColorMode or "class") == "dark" then
    a = (db.healthBarMissingColor and type(db.healthBarMissingColor.a) == "number") and db.healthBarMissingColor.a or DARK_HEALTH_DEFICIT_A
    a = math.max(0.55, math.min(0.95, a))
    r, g, b = DARK_HEALTH_DEFICIT_R, DARK_HEALTH_DEFICIT_G, DARK_HEALTH_DEFICIT_B
  else
    local c = db.healthBarMissingColor or { r = 0, g = 0, b = 0, a = 0.55 }
    r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 0.55
  end
  --- Deficit on its own frame (f.healthMissingBg) so incoming/absorb can sit *between* deficit and the fill texture.
  if bar._flexxMissingBg and bar._flexxMissingBg._flexxDeficitTex then
    pcall(function()
      bar._flexxMissingBg._flexxDeficitTex:SetVertexColor(r, g, b, a)
    end)
    pcall(function()
      bar:SetBackdropColor(0, 0, 0, 0)
    end)
    return
  end
  bar:SetBackdropColor(r, g, b, a)
end

function UF.ApplyHealthBarTexture(bar)
  if not bar then return end
  local mode = (_G.FlexxUIDB and _G.FlexxUIDB.healthBarTexture) or "default"
  bar:SetStatusBarTexture(UF.GetTexturePath(mode))
  local tex = bar:GetStatusBarTexture()
  if tex then
    tex:SetHorizTile(false)
    tex:SetVertTile(false)
    tex:SetVertexColor(1, 1, 1, 1)
  end

  if not bar.edgeFades then
    bar.edgeFades = {}
    local top1 = bar:CreateTexture(nil, "OVERLAY")
    top1:SetPoint("TOPLEFT", 0, 0)
    top1:SetPoint("TOPRIGHT", 0, 0)
    top1:SetHeight(1)
    top1:SetTexture("Interface\\Buttons\\WHITE8x8")
    top1:SetVertexColor(0, 0, 0, 0.16)

    local top2 = bar:CreateTexture(nil, "OVERLAY")
    top2:SetPoint("TOPLEFT", 0, -1)
    top2:SetPoint("TOPRIGHT", 0, -1)
    top2:SetHeight(1)
    top2:SetTexture("Interface\\Buttons\\WHITE8x8")
    top2:SetVertexColor(0, 0, 0, 0.10)

    local top3 = bar:CreateTexture(nil, "OVERLAY")
    top3:SetPoint("TOPLEFT", 0, -2)
    top3:SetPoint("TOPRIGHT", 0, -2)
    top3:SetHeight(1)
    top3:SetTexture("Interface\\Buttons\\WHITE8x8")
    top3:SetVertexColor(0, 0, 0, 0.05)

    local bottom1 = bar:CreateTexture(nil, "OVERLAY")
    bottom1:SetPoint("BOTTOMLEFT", 0, 0)
    bottom1:SetPoint("BOTTOMRIGHT", 0, 0)
    bottom1:SetHeight(1)
    bottom1:SetTexture("Interface\\Buttons\\WHITE8x8")
    bottom1:SetVertexColor(0, 0, 0, 0.16)

    local bottom2 = bar:CreateTexture(nil, "OVERLAY")
    bottom2:SetPoint("BOTTOMLEFT", 0, 1)
    bottom2:SetPoint("BOTTOMRIGHT", 0, 1)
    bottom2:SetHeight(1)
    bottom2:SetTexture("Interface\\Buttons\\WHITE8x8")
    bottom2:SetVertexColor(0, 0, 0, 0.10)

    local bottom3 = bar:CreateTexture(nil, "OVERLAY")
    bottom3:SetPoint("BOTTOMLEFT", 0, 2)
    bottom3:SetPoint("BOTTOMRIGHT", 0, 2)
    bottom3:SetHeight(1)
    bottom3:SetTexture("Interface\\Buttons\\WHITE8x8")
    bottom3:SetVertexColor(0, 0, 0, 0.05)

    bar.edgeFades.top1 = top1
    bar.edgeFades.top2 = top2
    bar.edgeFades.top3 = top3
    bar.edgeFades.bottom1 = bottom1
    bar.edgeFades.bottom2 = bottom2
    bar.edgeFades.bottom3 = bottom3
  end

  if not bar.smoothShade then
    local shade = bar:CreateTexture(nil, "OVERLAY")
    shade:SetAllPoints()
    shade:SetTexture("Interface\\Buttons\\WHITE8x8")
    if shade.SetGradientAlpha then
      shade:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.18, 0, 0, 0, 0.02)
    else
      shade:SetColorTexture(0, 0, 0, 0.10)
    end
    bar.smoothShade = shade
  end

  if not bar.flatMatte then
    local matte = bar:CreateTexture(nil, "OVERLAY")
    matte:SetAllPoints()
    matte:SetTexture("Interface\\Buttons\\WHITE8x8")
    matte:SetVertexColor(0, 0, 0, 0.08)
    bar.flatMatte = matte
  end

  bar.edgeFades.top1:SetShown(false)
  bar.edgeFades.top2:SetShown(false)
  bar.edgeFades.top3:SetShown(false)
  bar.edgeFades.bottom1:SetShown(false)
  bar.edgeFades.bottom2:SetShown(false)
  bar.edgeFades.bottom3:SetShown(false)
  bar.smoothShade:SetShown(mode == "smooth")
  bar.flatMatte:SetShown(mode == "flat")
  UF.ApplyHealthBarMissingColor(bar)
end

function UF.CreateStatusBar(parent, w, h)
  local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
  bar:SetSize(w, h)
  UF.ApplyHealthBarTexture(bar)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  bar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  UF.ApplyHealthBarMissingColor(bar)
  return bar
end

function UF.RemoveStatusBarBorder(bar)
  if not bar then return end
  bar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = nil,
    tile = false,
    edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  UF.ApplyHealthBarMissingColor(bar)
end

function UF.RemovePowerBarBorder(bar)
  if not bar then return end
  bar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = nil,
    tile = false,
    edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  UF.ApplyPowerBarBackdrop(bar)
end

function UF.ApplyPowerBarTexture(bar)
  if not bar then return end
  -- Thin bars need a solid texture; UI-StatusBar often reads as a dark line at low height.
  bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  local tex = bar:GetStatusBarTexture()
  if tex then
    tex:SetHorizTile(false)
    tex:SetVertTile(false)
    tex:SetVertexColor(1, 1, 1, 1)
  end
  UF.ApplyPowerBarBackdrop(bar)
end

function UF.ApplyPowerBarBackdrop(bar)
  if not bar then return end
  UF.EnsureDB()
  local db = _G.FlexxUIDB or {}
  local role = bar._flexxBarRole or "power"
  local dark = (role == "cast" and (db.castBarFillStyle or "default") == "dark")
    or (role ~= "cast" and (db.powerBarColorStyle or "default") == "dark")
  if dark then
    bar:SetBackdropColor(0.08, 0.09, 0.11, 0.92)
  else
    bar:SetBackdropColor(0.14, 0.14, 0.16, 0.9)
  end
end

function UF.CreatePowerBar(parent, w, h)
  local bar = CreateFrame("StatusBar", nil, parent, "BackdropTemplate")
  bar:SetSize(w, h)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  bar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = nil,
    tile = false,
    edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  UF.ApplyPowerBarTexture(bar)
  return bar
end

function UF.ApplyPowerBarColor(bar, unit, powerType)
  if not bar or not unit then return end
  UF.EnsureDB()
  local pType = powerType
  if pType == nil then
    local ok, v = pcall(UnitPowerType, unit)
    pType = (ok and v ~= nil) and v or 0
  end
  local mana = 0
  if Enum and Enum.PowerType and Enum.PowerType.Mana ~= nil then
    mana = Enum.PowerType.Mana
  end
  local dark = (_G.FlexxUIDB.powerBarColorStyle or "default") == "dark"
  if pType == mana then
    if dark then
      bar:SetStatusBarColor(0.10, 0.30, 0.68)
    else
      bar:SetStatusBarColor(0.22, 0.52, 0.95)
    end
  else
    if dark then
      bar:SetStatusBarColor(0.55, 0.48, 0.12)
    else
      bar:SetStatusBarColor(0.93, 0.86, 0.22)
    end
  end
  UF.ApplyPowerBarBackdrop(bar)
end

function UF.RemoveFrameBorder(frame)
  if not frame then return end
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = nil,
    tile = true,
    tileSize = 16,
    edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
end

--- Dialog-style panel fill behind player/target unit frames (after border strip).
function UF.ApplyUnitFrameBackdrop(frame)
  if not frame or not frame.SetBackdropColor then return end
  UF.EnsureDB()
  local show = _G.FlexxUIDB.unitFrameBackdropShow ~= false
  if show then
    frame:SetBackdropColor(0, 0, 0, 0.55)
  else
    frame:SetBackdropColor(0, 0, 0, 0)
  end
end

function UF.ApplyPlayerHealthColor(bar, unit)
  local mode = (_G.FlexxUIDB and _G.FlexxUIDB.playerHealthColorMode) or "class"
  if not bar.blizzardOverlays then
    local light = bar:CreateTexture(nil, "OVERLAY")
    light:SetAllPoints()
    light:SetTexture("Interface\\Buttons\\WHITE8x8")
    if light.SetGradientAlpha then
      light:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 0.10, 1, 1, 1, 0.00)
    else
      light:SetColorTexture(1, 1, 1, 0.05)
    end
    local dark = bar:CreateTexture(nil, "OVERLAY")
    dark:SetAllPoints()
    dark:SetTexture("Interface\\Buttons\\WHITE8x8")
    if dark.SetGradientAlpha then
      dark:SetGradientAlpha("VERTICAL", 0, 0, 0, 0.00, 0, 0, 0, 0.16)
    else
      dark:SetColorTexture(0, 0, 0, 0.08)
    end
    bar.blizzardOverlays = { light = light, dark = dark }
  end

  if mode == "blizzard" then
    bar:SetStatusBarColor(0.22, 0.78, 0.22)
    bar.blizzardOverlays.light:Show()
    bar.blizzardOverlays.dark:Show()
    UF.ApplyHealthBarMissingColor(bar, unit)
    return
  end
  bar.blizzardOverlays.light:Hide()
  bar.blizzardOverlays.dark:Hide()

  if mode == "dark" then
    bar:SetStatusBarColor(DARK_HEALTH_FILL_R, DARK_HEALTH_FILL_G, DARK_HEALTH_FILL_B)
    UF.ApplyHealthBarMissingColor(bar, unit)
    return
  end

  local _, class = UnitClass(unit)
  local c = class and RAID_CLASS_COLORS[class]
  if c then
    bar:SetStatusBarColor(c.r, c.g, c.b)
  else
    bar:SetStatusBarColor(0.2, 0.8, 0.2)
  end
  UF.ApplyHealthBarMissingColor(bar, unit)
end

local PLAYER_LOW_HEALTH_PCT = 0.35

--- Red border around the player health bar when HP is low (outline sits just outside the bar).
function UF.EnsurePlayerLowHealthChrome(f)
  if not f or f.unit ~= "player" or not f.health then return end
  if f._playerLowHealthChrome then return end
  local h = f.health
  local glow = CreateFrame("Frame", nil, f, "BackdropTemplate")
  glow:SetFrameStrata(f:GetFrameStrata())
  local hz = (h.GetFrameLevel and h:GetFrameLevel()) or 0
  glow:SetFrameLevel(hz + 1)
  glow:SetPoint("TOPLEFT", h, "TOPLEFT", -3, 3)
  glow:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 3, -3)
  glow:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  glow:SetBackdropColor(0, 0, 0, 0)
  glow:SetBackdropBorderColor(1, 0.2, 0.15, 0)
  glow:EnableMouse(false)
  glow:Hide()
  f._playerLowHealthChrome = glow
end

--- Low HP border: all math on health must stay inside one pcall (Retail secret UnitHealth / bar values).
function UF.UpdatePlayerLowHealthChrome(f)
  if not f or f.unit ~= "player" or not f.health then return end
  UF.EnsurePlayerLowHealthChrome(f)
  local g = f._playerLowHealthChrome
  if not g then return end
  if UnitIsDeadOrGhost("player") then
    g:Hide()
    return
  end

  local ok, res = pcall(function()
    if not UnitHealthPercent then
      return { hide = true }
    end
    local scale = _G.CurveConstants and _G.CurveConstants.ScaleTo100
    local n = UnitHealthPercent("player", true, scale)
    local pct = (n + 0) / 100
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end
    if pct > PLAYER_LOW_HEALTH_PCT then
      return { hide = true }
    end
    local t = pct / PLAYER_LOW_HEALTH_PCT
    local intensity = 1 - t
    return { show = true, a = 0.38 + 0.58 * intensity }
  end)

  if ok and res and res.show and type(res.a) == "number" then
    g:SetBackdropBorderColor(1, 0.22, 0.18, res.a)
    g:Show()
  else
    g:Hide()
  end
end

--- Single aggro art texture around the health bar (Media/aggroMask.png); tinted by threat color.
--- Frame size matches the PNG pixel size (1:1 UI units at scale 1) via GetFileWidth/GetFileHeight.
function UF.EnsureThreatGlow(f)
  if not f or f._threatGlowRoot then return end
  if f.unit == "target" then return end
  local h = f.health
  if not h then return end

  local root = CreateFrame("Frame", nil, f)
  root:SetFrameStrata(f:GetFrameStrata())
  local z = (f.GetFrameLevel and f:GetFrameLevel()) or 0
  -- z+1: under health fill and prediction; see UF.ApplyUnitFrameChildLevels.
  root:SetFrameLevel(z + 1)
  root:EnableMouse(false)
  root:Hide()

  local path = (ns.media and ns.media.aggroMask) or "Interface\\AddOns\\FlexxUI\\Media\\aggroMask.png"
  local tex = root:CreateTexture(nil, "ARTWORK")
  tex:SetTexture(path)
  tex:SetBlendMode("BLEND")
  local fw = tex.GetFileWidth and tex:GetFileWidth() or 0
  local fh = tex.GetFileHeight and tex:GetFileHeight() or 0
  if type(fw) ~= "number" or type(fh) ~= "number" or fw <= 0 or fh <= 0 then
    fw, fh = 245, 70
  end
  root:SetSize(fw, fh)
  tex:SetAllPoints()
  root:SetPoint("CENTER", h, "CENTER", 0, 0)

  f._threatGlowRoot = root
  f._threatGlowTex = tex
  if UF.ApplyUnitFrameChildLevels then UF.ApplyUnitFrameChildLevels(f) end
end

local function ThreatRgbForSituation(situation)
  if GetThreatStatusColor then
    local ok, r, g, b = pcall(function()
      return GetThreatStatusColor(situation)
    end)
    if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
      return r, g, b
    end
  end
  if situation == 3 then return 1, 0.2, 0.2 end
  if situation == 2 then return 1, 0.5, 0.2 end
  if situation == 1 then return 0.95, 0.9, 0.3 end
  return 0.7, 0.7, 0.7
end

function UF.UpdateThreatGlow(f)
  if not f then return end
  if f.unit == "target" then return end
  UF.EnsureThreatGlow(f)
  local root = f._threatGlowRoot
  local tex = f._threatGlowTex
  if not root or not tex then return end
  if UnitIsDeadOrGhost("player") then
    root:Hide()
    return
  end

  local ok, situation = pcall(function()
    return UnitThreatSituation("player")
  end)
  if not ok or situation == nil then
    root:Hide()
    return
  end
  local sn = situation
  if type(sn) ~= "number" or sn <= 0 then
    root:Hide()
    return
  end

  local r, g, b = ThreatRgbForSituation(sn)
  local a = 0.55 + sn * 0.12
  if sn == 3 then a = a + 0.1 end
  a = math.min(0.95, a)
  tex:SetVertexColor(r, g, b, a)
  root:Show()
end
