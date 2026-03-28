local _, ns = ...
local UF = ns.UnitFrames

function UF.GetTexturePath(name)
  return UF.const.textures[name or ""] or UF.const.textures["default"]
end

--- Player "dark zinc" fill (see ApplyPlayerHealthColor); deficit sits a bit lighter so it reads against the fill, not the frame.
local DARK_HEALTH_FILL_R, DARK_HEALTH_FILL_G, DARK_HEALTH_FILL_B = 0.11, 0.12, 0.14
local DARK_HEALTH_DEFICIT_LIFT = 0.065

function UF.ApplyHealthBarMissingColor(bar, unit)
  if not bar then return end
  UF.EnsureDB()
  unit = unit or bar._flexxUnit
  local db = _G.FlexxUIDB or {}
  if unit == "player" and (db.playerHealthColorMode or "class") == "dark" then
    local r = math.min(1, DARK_HEALTH_FILL_R + DARK_HEALTH_DEFICIT_LIFT)
    local g = math.min(1, DARK_HEALTH_FILL_G + DARK_HEALTH_DEFICIT_LIFT)
    local b = math.min(1, DARK_HEALTH_FILL_B + DARK_HEALTH_DEFICIT_LIFT)
    local a = (db.healthBarMissingColor and db.healthBarMissingColor.a) or 0.55
    bar:SetBackdropColor(r, g, b, math.max(a, 0.9))
    return
  end
  local c = db.healthBarMissingColor or { r = 0, g = 0, b = 0, a = 0.55 }
  local r, g, b, a = c.r or 0, c.g or 0, c.b or 0, c.a or 0.55
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

