local _, ns = ...
local UF = ns.UnitFrames

local MAX_PIPS = 7
local PIP_W, PIP_H = 12, 7
--- Pip row height; centered on health top so half sits above the bar (same idea as inset power straddling the bottom edge).
local TOP_BAR_H = 12
--- Fallback if Enum.PowerType.RunicPower is unavailable; matches PowerDisplayRunicPower / classic index.
local RUNIC_POWER_TYPE_INDEX = 6

--- Power types to probe (first match with UnitPowerMax > 0 wins). Skip nil enums so ipairs never stops early.
local function SecondaryPowerProbeList()
  if not Enum or not Enum.PowerType then return {} end
  local E = Enum.PowerType
  local t = {}
  local function add(pt)
    if pt ~= nil then
      t[#t + 1] = pt
    end
  end
  add(E.ComboPoints)
  add(E.HolyPower)
  add(E.Chi)
  add(E.SoulShards)
  add(E.ArcaneCharges)
  add(E.Essence)
  add(E.RunicPower)
  return t
end

local function SecondaryPowerTypeColor(pt)
  -- Prefer explicit class-resource palette, then fall back to PowerBarColor if available.
  if Enum and Enum.PowerType then
    local E = Enum.PowerType
    if pt == E.HolyPower then return 0.95, 0.82, 0.32 end
    if pt == E.ComboPoints then return 0.92, 0.20, 0.18 end
    if pt == E.Chi then return 0.38, 0.90, 0.82 end
    if pt == E.SoulShards then return 0.60, 0.32, 0.95 end
    if pt == E.ArcaneCharges then return 0.82, 0.44, 0.95 end
    if pt == E.Essence then return 0.32, 0.78, 0.98 end
    if pt == E.RunicPower then return 0.00, 0.82, 1.00 end
  end
  local pbc = PowerBarColor and PowerBarColor[pt]
  if pbc then
    local r = pbc.r or pbc[1] or 0.95
    local g = pbc.g or pbc[2] or 0.85
    local b = pbc.b or pbc[3] or 0.35
    return r, g, b
  end
  return 0.95, 0.85, 0.35
end

--- Read one power type. All math on UnitPower* must run inside pcall — secrets break CoerceAmount/PlainNumber and compare as 0 outside.
local function ReadSecondaryPowerType(unit, pt)
  if pt == nil then return nil end
  local mxP, curP
  local ok = pcall(function()
    local mx = UnitPowerMax(unit, pt)
    local cur = UnitPower(unit, pt)
    mxP = mx + 0
    curP = (cur or 0) + 0
  end)
  if not ok then return nil end
  local goodMx = false
  pcall(function()
    goodMx = type(mxP) == "number" and mxP == mxP and mxP > 0
  end)
  if not goodMx then return nil end
  pcall(function()
    if type(curP) == "number" and curP < 0 then curP = 0 end
  end)
  if curP == nil or (type(curP) == "number" and curP ~= curP) then curP = 0 end
  return pt, curP, mxP
end

local function PowerTokenIsRunic(token)
  if type(token) ~= "string" then return false end
  local up = string.upper(token)
  return up == "RUNIC_POWER" or up == "RUNIC"
end

--- Returns powerType, current, max or nil, 0, 0 if none.
function UF.GetSecondaryPowerValues(unit)
  if not unit or not UnitExists(unit) then return nil, 0, 0 end

  local E = Enum and Enum.PowerType
  local rpEnum = E and E.RunicPower

  --- Prefer Blizzard's active power type (correct enum index even when constants shift).
  local okType, powerType, powerToken = pcall(function()
    return UnitPowerType(unit)
  end)
  if okType and powerType ~= nil then
    local isRunic = PowerTokenIsRunic(powerToken)
    if not isRunic and rpEnum ~= nil and powerType == rpEnum then
      isRunic = true
    end
    if not isRunic and powerType == RUNIC_POWER_TYPE_INDEX then
      isRunic = true
    end
    if isRunic then
      local a, b, c = ReadSecondaryPowerType(unit, powerType)
      if a then return a, b, c end
    end
  end

  --- className, classFilename, classId — use filename + id (do not rely on a single ambiguous return).
  local classFilename = select(2, UnitClass(unit))
  local classId = select(3, UnitClass(unit))
  local isDK = (type(classId) == "number" and classId == 6)
    or (type(classFilename) == "string" and string.upper(classFilename) == "DEATHKNIGHT")

  if isDK then
    if rpEnum ~= nil then
      local a, b, c = ReadSecondaryPowerType(unit, rpEnum)
      if a then return a, b, c end
    end
    local a2, b2, c2 = ReadSecondaryPowerType(unit, RUNIC_POWER_TYPE_INDEX)
    if a2 then return a2, b2, c2 end
    --- DK: primary power type from UnitPowerType is usually runic power; catches enum/index drift.
    do
      local okPt, ptype = pcall(function() return select(1, UnitPowerType(unit)) end)
      if okPt and ptype ~= nil then
        local a, b, c = ReadSecondaryPowerType(unit, ptype)
        if a then return a, b, c end
      end
    end
  end

  for _, pt in ipairs(SecondaryPowerProbeList()) do
    local a, b, c = ReadSecondaryPowerType(unit, pt)
    if a then return a, b, c end
  end
  return nil, 0, 0
end

--- Call after `f.health` exists. Pips sit on the health bar top edge (half above, half on the bar).
function UF.AnchorTopResourceBarToHealth(f)
  if not f or not f.topBarFrame or not f.health then return end
  local bar = f.topBarFrame
  bar:ClearAllPoints()
  bar:SetHeight(TOP_BAR_H)
  local half = TOP_BAR_H / 2
  bar:SetPoint("TOPLEFT", f.health, "TOPLEFT", 0, half)
  bar:SetPoint("TOPRIGHT", f.health, "TOPRIGHT", 0, half)
end

function UF.CreateTopResourceBar(f)
  f.topBarFrame = CreateFrame("Frame", nil, f)
  f.topBarFrame:SetHeight(TOP_BAR_H)
  f.topBarFrame:SetFrameLevel(f:GetFrameLevel() + 7)
  f.topBarFrame:EnableMouse(false)
  f.topBarFrame:Hide()

  f.secondaryPipContainer = CreateFrame("Frame", nil, f.topBarFrame)
  f.secondaryPipContainer:SetPoint("TOPLEFT", f.topBarFrame, "TOPLEFT", 0, 0)
  f.secondaryPipContainer:SetPoint("BOTTOMRIGHT", f.topBarFrame, "BOTTOMRIGHT", 0, 0)

  f.secondaryPips = {}
  for i = 1, MAX_PIPS do
    local pip = f.secondaryPipContainer:CreateTexture(nil, "ARTWORK")
    pip:SetSize(PIP_W, PIP_H)
    pip:SetTexture("Interface\\Buttons\\WHITE8x8")
    pip:SetVertexColor(0.15, 0.15, 0.18, 0.85)
    f.secondaryPips[i] = pip
  end
end

local function LayoutPips(f, n)
  local pips = f.secondaryPips
  if not pips or n <= 0 then return end
  local gap = 3
  for i = 1, MAX_PIPS do
    local pip = pips[i]
    if i <= n then
      pip:ClearAllPoints()
      local x = (i - 1 - (n - 1) / 2) * (PIP_W + gap)
      pip:SetPoint("CENTER", f.secondaryPipContainer, "CENTER", x, 0)
      pip:Show()
    else
      pip:Hide()
    end
  end
end

function UF.UpdateTopResourceBar(f)
  if not f or not f.topBarFrame or not f.unit then return end
  local db = _G.FlexxUIDB or {}
  local showSecondary = db.showSecondaryResource ~= false

  local function hideAll()
    f.topBarFrame:Hide()
    if f.secondaryPipContainer then f.secondaryPipContainer:Hide() end
    for i = 1, MAX_PIPS do
      if f.secondaryPips and f.secondaryPips[i] then f.secondaryPips[i]:Hide() end
    end
  end

  -- Secondary / class-colored top strip is player-only; target frame does not use it.
  if f.unit == "target" then
    hideAll()
    return
  end

  if not UnitExists(f.unit) or not showSecondary then
    hideAll()
    return
  end

  local pt, cur, mx = UF.GetSecondaryPowerValues(f.unit)
  local showBar = false
  pcall(function()
    showBar = pt ~= nil and type(mx) == "number" and mx == mx and mx > 0
  end)
  if not showBar then
    hideAll()
    return
  end

  f.secondaryPipContainer:Show()
  f.topBarFrame:SetHeight(TOP_BAR_H)
  f.topBarFrame:Show()

  local n
  if mx > 20 then
    n = math.min(MAX_PIPS, 5)
  else
    n = math.min(MAX_PIPS, math.max(1, math.floor(mx + 0.5)))
  end
  LayoutPips(f, n)

  local r, g, b = SecondaryPowerTypeColor(pt)

  local dark = (db.classBarColorStyle or "default") == "dark"
  if dark then
    r = r * 0.58 + 0.08
    g = g * 0.58 + 0.08
    b = b * 0.58 + 0.08
  end

  local filledFloat = mx > 0 and (cur / mx * n) or 0
  local filled = math.floor(filledFloat + 1e-4)
  if filled > n then filled = n end
  if filled < 0 then filled = 0 end

  for i = 1, n do
    local pip = f.secondaryPips[i]
    if i <= filled then
      pip:SetVertexColor(r, g, b, dark and 0.92 or 0.95)
    else
      local er, eg, eb = r * (dark and 0.38 or 0.28), g * (dark and 0.38 or 0.28), b * (dark and 0.38 or 0.28)
      pip:SetVertexColor(er, eg, eb, dark and 0.62 or 0.55)
    end
  end
end
