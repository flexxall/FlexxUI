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
  UF.EnsureDB()
  local mode = (_G.FlexxUIDB and _G.FlexxUIDB.powerBarTexture) or "none"
  if not UF.const.textures[mode] then
    mode = "none"
  end
  bar:SetStatusBarTexture(UF.GetTexturePath(mode))
  local tex = bar:GetStatusBarTexture()
  if tex then
    tex:SetHorizTile(false)
    tex:SetVertTile(false)
    tex:SetVertexColor(1, 1, 1, 1)
  end
  if not bar._flexxPowerFlatMatte then
    local matte = bar:CreateTexture(nil, "OVERLAY")
    matte:SetAllPoints()
    matte:SetTexture("Interface\\Buttons\\WHITE8x8")
    matte:SetVertexColor(0, 0, 0, 0.08)
    bar._flexxPowerFlatMatte = matte
  end
  bar._flexxPowerFlatMatte:SetShown(mode == "flat")
  UF.ApplyPowerBarBackdrop(bar)
end

function UF.ApplyPowerBarBackdrop(bar)
  if not bar then return end
  UF.EnsureDB()
  local db = _G.FlexxUIDB or {}
  local role = bar._flexxBarRole or "power"
  local dark = (role == "cast" and (db.castBarFillStyle or "default") == "dark")
    or (role ~= "cast" and (db.powerBarColorStyle or "none") == "dark")
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

--- Death Knight: Frost (cyan), Unholy (green), Blood (red) for runic bar + addons that mirror DK resources.
--- Returns r, g, b or nil if not a DK player.
function UF.GetDeathKnightSpecResourceRGB(unit)
  if not unit or unit ~= "player" or not UnitExists(unit) then return nil end
  local classId = select(3, UnitClass(unit))
  if type(classId) ~= "number" or classId ~= 6 then return nil end
  local spec = GetSpecialization and GetSpecialization()
  if spec == 1 then
    return 0.82, 0.14, 0.18
  end
  if spec == 2 then
    return 0.00, 0.82, 1.00
  end
  if spec == 3 then
    return 0.38, 0.82, 0.34
  end
  return 0.00, 0.82, 1.00
end

--- Demon Hunter: spec-matched primary bar colors. Havoc Fury #C942FD; Devourer Fury #00CBFF; Vengeance Pain #FF9C00.
--- Returns r, g, b or nil if not applicable.
function UF.GetDemonHunterSpecResourceRGB(unit, powerType)
  if not unit or unit ~= "player" or not UnitExists(unit) then return nil end
  local classId = select(3, UnitClass(unit))
  if type(classId) ~= "number" or classId ~= 12 then return nil end
  local spec = GetSpecialization and GetSpecialization()
  if spec ~= 1 and spec ~= 2 and spec ~= 3 then return nil end
  local pt = powerType
  local E = Enum and Enum.PowerType
  local furyEnum = E and E.Fury
  local painEnum = E and E.Pain
  local function isFury()
    if furyEnum ~= nil and pt == furyEnum then return true end
    local ok, v = pcall(function() return type(pt) == "number" and pt == 17 end)
    return ok and v
  end
  local function isPain()
    if painEnum ~= nil and pt == painEnum then return true end
    local ok, v = pcall(function() return type(pt) == "number" and pt == 18 end)
    return ok and v
  end
  if spec == 1 then
    if isFury() then
      return 201 / 255, 66 / 255, 253 / 255
    end
    return nil
  end
  if spec == 3 then
    if isFury() then
      return 0 / 255, 203 / 255, 255 / 255
    end
    return nil
  end
  if spec == 2 and isPain() then
    return 1.0, 156 / 255, 0.0
  end
  return nil
end

local function DimPowerBarRGB(r, g, b)
  return r * 0.58 + 0.08, g * 0.58 + 0.08, b * 0.58 + 0.08
end

local function GetBlizzardPowerBarRGB(pType)
  local pc = _G.PowerBarColor and _G.PowerBarColor[pType]
  if pc and type(pc.r) == "number" and type(pc.g) == "number" and type(pc.b) == "number" then
    return pc.r, pc.g, pc.b
  end
  return nil
end

--- Undimmed RGB for automatic coloring (same rules as ApplyPowerBarColor when custom fill is off).
--- texMode: "none" | "default" | "flat"
function UF.GetPowerBarAutomaticRGB(unit, powerType, texMode)
  local pType = powerType
  if pType == nil and unit then
    local ok, v = pcall(UnitPowerType, unit)
    pType = (ok and v ~= nil) and v or 0
  elseif pType == nil then
    pType = 0
  end
  local tm = texMode or "none"
  if tm ~= "none" and tm ~= "default" and tm ~= "flat" then
    tm = "none"
  end
  local mana = 0
  if Enum and Enum.PowerType and Enum.PowerType.Mana ~= nil then
    mana = Enum.PowerType.Mana
  end

  local function isRunic()
    local E = Enum and Enum.PowerType
    if E and E.RunicPower ~= nil and pType == E.RunicPower then
      return true
    end
    local r = false
    pcall(function()
      if type(pType) == "number" and pType == 6 then r = true end
    end)
    return r
  end

  if tm == "default" then
    if isRunic() then
      local dr, dg, dbk = UF.GetDeathKnightSpecResourceRGB(unit)
      if dr then
        return dr, dg, dbk
      end
    end
    local dhr, dhg, dhb = UF.GetDemonHunterSpecResourceRGB(unit, pType)
    if dhr then
      return dhr, dhg, dhb
    end
    local br, bg, bb = GetBlizzardPowerBarRGB(pType)
    if br then
      return br, bg, bb
    end
  end

  if pType == mana then
    return 0.22, 0.52, 0.95
  end
  if isRunic() then
    local dr, dg, dbk = UF.GetDeathKnightSpecResourceRGB(unit)
    if dr then
      return dr, dg, dbk
    end
  end
  local dhr2, dhg2, dhb2 = UF.GetDemonHunterSpecResourceRGB(unit, pType)
  if dhr2 then
    return dhr2, dhg2, dhb2
  end
  return 0.93, 0.86, 0.22
end

function UF.ApplyPowerBarColor(bar, unit, powerType)
  if not bar or not unit then return end
  UF.EnsureDB()
  local db = _G.FlexxUIDB or {}
  local pType = powerType
  if pType == nil then
    local ok, v = pcall(UnitPowerType, unit)
    pType = (ok and v ~= nil) and v or 0
  end
  local mana = 0
  if Enum and Enum.PowerType and Enum.PowerType.Mana ~= nil then
    mana = Enum.PowerType.Mana
  end
  local dark = (db.powerBarColorStyle or "none") == "dark"
  local texMode = db.powerBarTexture or "none"
  if texMode ~= "none" and texMode ~= "default" and texMode ~= "flat" then
    texMode = "none"
  end

  if db.powerBarUseCustomColor then
    local c = db.powerBarCustomColor or {}
    local r = type(c.r) == "number" and c.r or 0.5
    local g = type(c.g) == "number" and c.g or 0.5
    local b = type(c.b) == "number" and c.b or 0.5
    if dark then
      r, g, b = DimPowerBarRGB(r, g, b)
    end
    bar:SetStatusBarColor(r, g, b)
    UF.ApplyPowerBarBackdrop(bar)
    return
  end

  --- Blizzard UI-StatusBar strip: use PowerBarColor (and DK spec for runic) like the stock UI.
  if texMode == "default" then
    local isRunic = false
    local E = Enum and Enum.PowerType
    if E and E.RunicPower ~= nil and pType == E.RunicPower then
      isRunic = true
    else
      pcall(function()
        if type(pType) == "number" and pType == 6 then isRunic = true end
      end)
    end
    if isRunic then
      local dr, dg, dbk = UF.GetDeathKnightSpecResourceRGB(unit)
      if dr then
        if dark then
          local r, g, b = DimPowerBarRGB(dr, dg, dbk)
          bar:SetStatusBarColor(r, g, b)
        else
          bar:SetStatusBarColor(dr, dg, dbk)
        end
        UF.ApplyPowerBarBackdrop(bar)
        return
      end
    end
    do
      local dhr, dhg, dhb = UF.GetDemonHunterSpecResourceRGB(unit, pType)
      if dhr then
        if dark then
          dhr, dhg, dhb = DimPowerBarRGB(dhr, dhg, dhb)
        end
        bar:SetStatusBarColor(dhr, dhg, dhb)
        UF.ApplyPowerBarBackdrop(bar)
        return
      end
    end
    local br, bg, bb = GetBlizzardPowerBarRGB(pType)
    if br then
      if dark then
        br, bg, bb = DimPowerBarRGB(br, bg, bb)
      end
      bar:SetStatusBarColor(br, bg, bb)
      UF.ApplyPowerBarBackdrop(bar)
      return
    end
  end

  --- Flat / none texture: legacy FlexxUI preset fills (bright vs dark tint).
  if pType == mana then
    if dark then
      bar:SetStatusBarColor(0.10, 0.30, 0.68)
    else
      bar:SetStatusBarColor(0.22, 0.52, 0.95)
    end
  else
    local isRunic = false
    local E = Enum and Enum.PowerType
    if E and E.RunicPower ~= nil and pType == E.RunicPower then
      isRunic = true
    else
      pcall(function()
        if type(pType) == "number" and pType == 6 then isRunic = true end
      end)
    end
    if isRunic then
      local dr, dg, dbk = UF.GetDeathKnightSpecResourceRGB(unit)
      if dr then
        if dark then
          local r, g, b = DimPowerBarRGB(dr, dg, dbk)
          bar:SetStatusBarColor(r, g, b)
        else
          bar:SetStatusBarColor(dr, dg, dbk)
        end
        UF.ApplyPowerBarBackdrop(bar)
        return
      end
    end
    do
      local dhr, dhg, dhb = UF.GetDemonHunterSpecResourceRGB(unit, pType)
      if dhr then
        if dark then
          dhr, dhg, dhb = DimPowerBarRGB(dhr, dhg, dhb)
        end
        bar:SetStatusBarColor(dhr, dhg, dhb)
        UF.ApplyPowerBarBackdrop(bar)
        return
      end
    end
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

--- Media/aggroMask.png size when GetFileWidth/GetFileHeight are unavailable (keep in sync with the PNG).
local AGGRO_MASK_FALLBACK_W, AGGRO_MASK_FALLBACK_H = 280, 82

--- Native-sized texture (no scaling). PNG center aligns with health bar center; inner cutout is authored slightly smaller than the bar for gaps.
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
    fw, fh = AGGRO_MASK_FALLBACK_W, AGGRO_MASK_FALLBACK_H
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
  local h = f.health
  if not root or not tex or not h then return end
  root:ClearAllPoints()
  root:SetPoint("CENTER", h, "CENTER", 0, 0)
  if UnitIsDeadOrGhost("player") then
    root:Hide()
    return
  end

  local situation
  pcall(function()
    if UnitExists("target") then
      local okAtk, atk = pcall(UnitCanAttack, "player", "target")
      if okAtk and atk then
        situation = UnitThreatSituation("player", "target")
      end
    end
    if situation == nil then
      situation = UnitThreatSituation("player")
    end
  end)
  local sn = (type(situation) == "number") and situation or 0

  local uac = UnitAffectingCombat and UnitAffectingCombat("player")

  if sn > 0 then
    local r, g, b = ThreatRgbForSituation(sn)
    local a = 0.55 + sn * 0.12
    if sn == 3 then a = a + 0.1 end
    a = math.min(0.95, a)
    tex:SetVertexColor(r, g, b, a)
    root:Show()
    return
  end

  --- Threat can be nil/0 while out of range or before the table updates; still in combat with something.
  if uac then
    tex:SetVertexColor(0.92, 0.52, 0.16, 0.44)
    root:Show()
    return
  end

  root:Hide()
end
