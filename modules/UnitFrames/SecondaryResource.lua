local _, ns = ...
local UF = ns.UnitFrames

local MAX_PIPS = 7
local PIP_W, PIP_H = 12, 7
--- Pip row height; centered on health top so half sits above the bar (same idea as inset power straddling the bottom edge).
local TOP_BAR_H = 12

--- Power types to probe (first match with UnitPowerMax > 0 wins). Covers combo, holy power, chi, shards, arcane, essence.
local function SecondaryPowerProbeList()
  if not Enum or not Enum.PowerType then return {} end
  local E = Enum.PowerType
  return {
    E.ComboPoints,
    E.HolyPower,
    E.Chi,
    E.SoulShards,
    E.ArcaneCharges,
    E.Essence,
  }
end

--- Returns powerType, current, max or nil, 0, 0 if none.
function UF.GetSecondaryPowerValues(unit)
  if not unit or not UnitExists(unit) then return nil, 0, 0 end
  for _, pt in ipairs(SecondaryPowerProbeList()) do
    local okMx, mx = pcall(function() return UnitPowerMax(unit, pt) end)
    if okMx and type(mx) == "number" and mx > 0 then
      local okC, cur = pcall(function() return UnitPower(unit, pt) end)
      local c = (okC and type(cur) == "number") and cur or 0
      return pt, c, mx
    end
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
  f.topBarFrame:SetFrameLevel(f:GetFrameLevel() + 5)
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
  if pt == nil or mx <= 0 then
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

  local r, g, b = 0.95, 0.85, 0.35
  if UnitIsPlayer(f.unit) then
    local _, class = UnitClass(f.unit)
    local c = class and RAID_CLASS_COLORS[class]
    if c then r, g, b = c.r, c.g, c.b end
  end

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
