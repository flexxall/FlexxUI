local _, ns = ...
local UF = ns.UnitFrames

local FULL_POWER_H = 10
local INSET_POWER_H = 5
--- Inset bar is this many pixels narrower than the health bar (total, split evenly on each side).
local INSET_POWER_NARROWER = 20
local POWER_GAP = 4
local BOTTOM_PAD = 8

--- Width of inset power bar vs current health bar (call after health has width).
function UF.SyncInsetPowerBarWidth(f)
  if not f or not f.power or not f.health then return end
  UF.EnsureDB()
  if (_G.FlexxUIDB.powerBarLayout or "full") ~= "inset" then return end
  local w = f.health:GetWidth()
  if w and w > 0 then
    f.power:SetWidth(math.max(1, w - INSET_POWER_NARROWER))
  end
end

--- Health bar position/size are identical in both layouts. Only the power bar changes: full strip below vs inset overlap.
function UF.ApplyUnitFramePowerBarLayout(f)
  if not f or not f.power or not f.health then return end
  UF.EnsureDB()
  local mode = _G.FlexxUIDB.powerBarLayout or "full"
  if mode ~= "inset" then mode = "full" end

  local healthBottom = BOTTOM_PAD + FULL_POWER_H + POWER_GAP

  f.health:ClearAllPoints()
  f.health:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, healthBottom)
  f.health:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, healthBottom)

  f.power:ClearAllPoints()
  if mode == "full" then
    f.power:SetHeight(FULL_POWER_H)
    f.power:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, BOTTOM_PAD)
    f.power:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, BOTTOM_PAD)
  else
    f.power:SetHeight(INSET_POWER_H)
    f.power:SetPoint("CENTER", f.health, "BOTTOM", 0, 0)
    UF.SyncInsetPowerBarWidth(f)
  end

  UF.ApplyUnitFrameChildLevels(f)
  if UF.ApplyPowerTextLayout then UF.ApplyPowerTextLayout(f) end
  if UF.AnchorTopResourceBarToHealth then UF.AnchorTopResourceBarToHealth(f) end
end

--- After f:SetFrameLevel, re-apply stacking so children stay ordered (threat under health under prediction strips).
function UF.ApplyUnitFrameChildLevels(f)
  if not f then return end
  local z = f:GetFrameLevel() or 0
  if f.power and f.power.SetFrameLevel then
    local inset = _G.FlexxUIDB and _G.FlexxUIDB.powerBarLayout == "inset"
    f.power:SetFrameLevel(z + (inset and 3 or 2))
  end
  if f.health and f.health.SetFrameLevel then f.health:SetFrameLevel(z + 2) end
  if f.healthPrediction and f.healthPrediction.SetFrameLevel then f.healthPrediction:SetFrameLevel(z + 100) end
  if f.healthTextLayer and f.healthTextLayer.SetFrameLevel then f.healthTextLayer:SetFrameLevel(z + 110) end
  if f.topBarFrame and f.topBarFrame.SetFrameLevel then f.topBarFrame:SetFrameLevel(z + 5) end
  if f._threatGlowRoot and f._threatGlowRoot.SetFrameLevel then f._threatGlowRoot:SetFrameLevel(z + 1) end
end

local function EnsureBlizzardHooks()
  if UF.state.blizzardHooksInstalled then return end
  if not PlayerFrame or not TargetFrame then return end
  UF.state.blizzardHooksInstalled = true

  PlayerFrame:HookScript("OnShow", function(self)
    if _G.FlexxUIDB and _G.FlexxUIDB.hideBlizzard then self:Hide() end
  end)
  TargetFrame:HookScript("OnShow", function(self)
    if _G.FlexxUIDB and _G.FlexxUIDB.hideBlizzard then self:Hide() end
  end)
end

local function RestoreBlizzardUnitFrames()
  if not PlayerFrame or not TargetFrame then return end
  PlayerFrame:SetAlpha(1)
  PlayerFrame:EnableMouse(true)
  PlayerFrame:Show()
  TargetFrame:SetAlpha(1)
  TargetFrame:EnableMouse(true)
  TargetFrame:Show()
end

local function HideBlizzardUnitFrames()
  if not PlayerFrame or not TargetFrame then return end
  EnsureBlizzardHooks()
  PlayerFrame:SetAlpha(0); PlayerFrame:EnableMouse(false); PlayerFrame:Hide()
  TargetFrame:SetAlpha(0); TargetFrame:EnableMouse(false); TargetFrame:Hide()
end

function UF.ApplyHideBlizzard()
  UF.EnsureDB()
  if not PlayerFrame or not TargetFrame then return end
  if _G.FlexxUIDB.hideBlizzard then HideBlizzardUnitFrames() else RestoreBlizzardUnitFrames() end
end

local function BuildPlayerResting(f)
  -- Same layer as name/health text but above the StatusBar fill: parent to healthTextLayer (high FrameLevel) + draw sublayer on top.
  local zParent = f.healthTextLayer or f
  local zSmall = (ns.Fonts and ns.Fonts.CreateFontString(zParent, "OVERLAY", "GameFontHighlightSmall", "unit")) or zParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  -- BOTTOMLEFT→health TOPLEFT: here, positive Y shifts the row *up* above the bar; use negative Y to sit lower so zzz overlaps the top edge of the fill.
  local restingZOverlapY = -4
  zSmall:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, restingZOverlapY)
  zSmall:SetText("z")
  zSmall:SetTextColor(1, 0.88, 0.35)
  zSmall:SetShadowOffset(1, -1)
  pcall(function() zSmall:SetDrawLayer("OVERLAY", 9) end)
  zSmall:Hide()

  local zMid
  if ns.Fonts and ns.Fonts.CreateFontString then
    zMid = ns.Fonts.CreateFontString(zParent, "OVERLAY", "GameFontHighlight", "unit")
    zMid._flexxFontExtraSize = 2
  else
    zMid = zParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pcall(function()
      local fh, sz, fl = zMid:GetFont()
      if fh and type(sz) == "number" then zMid:SetFont(fh, sz + 2, fl) end
    end)
  end
  -- Bottom-align widget corners; different templates still draw glyphs with slightly different optical baselines.
  -- Nudge mid + big down 1px so they line up with HighlightSmall’s “z” (widget bottom ≠ typographic baseline).
  local zChainDy = -1
  zMid:SetPoint("BOTTOMLEFT", zSmall, "BOTTOMRIGHT", 2, zChainDy)
  zMid:SetText("z")
  zMid:SetTextColor(1, 0.88, 0.35)
  zMid:SetShadowOffset(1, -1)
  pcall(function() zMid:SetDrawLayer("OVERLAY", 9) end)
  zMid:Hide()

  local zBig = (ns.Fonts and ns.Fonts.CreateFontString(zParent, "OVERLAY", "GameFontNormal", "unit")) or zParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local zBigExtraX = 1
  zBig:SetPoint("BOTTOMLEFT", zMid, "BOTTOMRIGHT", 2 + zBigExtraX, zChainDy)
  zBig:SetText("Z")
  zBig:SetTextColor(1, 0.88, 0.35)
  zBig:SetShadowOffset(1, -1)
  pcall(function() zBig:SetDrawLayer("OVERLAY", 9) end)
  zBig:Hide()

  local function Lerp(a, b, t) return a + (b - a) * t end
  f.restingIcons = { zSmall, zMid, zBig }
  f.restingPulseTime = 0
  f.restingPulseDriver = CreateFrame("Frame", nil, zParent)
  f.restingPulseDriver:Hide()
  f.restingPulseOnUpdate = function(_, elapsed)
    local minA, maxA = 0.18, 1
    local fadeDur, half, pause = 0.6, 0.3, 0.8
    local smallIn, midIn, bigIn = 0, half, half + half
    local smallOut, midOut, bigOut = bigIn + fadeDur, bigIn + fadeDur + half, bigIn + fadeDur + half + half
    local cycle = bigOut + fadeDur + pause
    f.restingPulseTime = (f.restingPulseTime + elapsed) % cycle
    local t = f.restingPulseTime
    local function AlphaAt(startIn, startOut)
      if t < startIn then return minA
      elseif t < startIn + fadeDur then return Lerp(minA, maxA, (t - startIn) / fadeDur)
      elseif t < startOut then return maxA
      elseif t < startOut + fadeDur then return Lerp(maxA, minA, (t - startOut) / fadeDur)
      else return minA end
    end
    zSmall:SetAlpha(AlphaAt(smallIn, smallOut))
    zMid:SetAlpha(AlphaAt(midIn, midOut))
    zBig:SetAlpha(AlphaAt(bigIn, bigOut))
  end
end

local function UnitFrame_ShowTooltip(self)
  if not self or not self.unit or not UnitExists(self.unit) then return end
  local tip = GameTooltip
  if not tip or tip:IsForbidden() then return end
  tip:SetOwner(self, "ANCHOR_NONE")
  local okAnchor = pcall(function()
    if GameTooltip_SetDefaultAnchor then
      GameTooltip_SetDefaultAnchor(tip, self)
    else
      tip:SetOwner(self, "ANCHOR_RIGHT")
    end
  end)
  if not okAnchor then
    tip:SetOwner(self, "ANCHOR_RIGHT")
  end
  tip:SetUnit(self.unit)
  tip:Show()
end

local function UnitFrame_HideTooltip()
  local tip = GameTooltip
  if not tip or tip:IsForbidden() then return end
  tip:Hide()
end

local function RegisterEvents(frame, unit)
  frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_THREAT_LIST_UPDATE" then
      UF.UpdateUnitFrame(self)
      return
    end
    if event == "PLAYER_TARGET_CHANGED" then
      if self.unit == "target" then
        UF.UpdateUnitFrame(self)
        -- Health/max sometimes populate a frame after the event; refresh again so the bar is not stuck at 0 max.
        if C_Timer and C_Timer.After then
          C_Timer.After(0, function()
            if not self or self.unit ~= "target" then return end
            UF.UpdateUnitFrame(self)
          end)
        end
      end
      return
    end
    if event == "PLAYER_UPDATE_RESTING" or event == "UPDATE_EXHAUSTION" then
      if self.unit == "player" then UF.UpdatePlayerResting(self) end
      return
    end
    if event == "PLAYER_ENTERING_WORLD" then
      UF.UpdateUnitFrame(self)
      return
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
      if self.unit == "player" then UF.UpdateUnitFrame(self) end
      return
    end
    if arg1 and arg1 ~= self.unit then
      if not UnitIsUnit or not UnitIsUnit(arg1, self.unit) then return end
    end
    UF.UpdateUnitFrame(self)
  end)

  if unit == "player" then
    frame:RegisterUnitEvent("UNIT_HEALTH", "player")
    frame:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
    frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "player")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("PLAYER_UPDATE_RESTING")
    frame:RegisterEvent("UPDATE_EXHAUSTION")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  else
    frame:RegisterUnitEvent("UNIT_HEALTH", "target")
    frame:RegisterUnitEvent("UNIT_MAXHEALTH", "target")
    frame:RegisterUnitEvent("UNIT_NAME_UPDATE", "target")
    frame:RegisterEvent("PLAYER_TARGET_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  end
  -- Unit-scoped so heal prediction / absorb fires for this unit; fall back to RegisterEvent if the client rejects RegisterUnitEvent.
  local function regUnit(ev)
    local ok = pcall(function() frame:RegisterUnitEvent(ev, unit) end)
    if not ok then frame:RegisterEvent(ev) end
  end
  regUnit("UNIT_ABSORB_AMOUNT_CHANGED")
  regUnit("UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
  regUnit("UNIT_HEAL_PREDICTION")
  regUnit("UNIT_AURA")
  frame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
  frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
  frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
  frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
end

local function MakeUnitFrame(key, unit, defaultPoint)
  local f = CreateFrame("Button", "FlexxUI_UnitFrame_" .. key, UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
  f:SetSize(245, 80)
  f.unit = unit
  f.unitFrameKey = key
  f:RegisterForClicks("AnyUp")
  f:SetAttribute("unit", unit)
  f:SetAttribute("*type1", "target")
  f:SetAttribute("*type2", "togglemenu")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })

  -- Top strip: class color, or secondary resource pips (combo, holy power, chi, shards, etc.).
  if UF.CreateTopResourceBar then UF.CreateTopResourceBar(f) end

  f.power = UF.CreatePowerBar(f, 200, FULL_POWER_H)
  f.power._flexxBarRole = "power"

  f.powerText = (ns.Fonts and ns.Fonts.CreateFontString(f.power, "OVERLAY", "GameFontHighlightSmall", "unit")) or f.power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.powerText:SetPoint("CENTER", f.power, "CENTER", 0, 0)
  f.powerText:SetJustifyH("CENTER")
  f.powerText:SetDrawLayer("OVERLAY", 7)
  f.powerText:SetShadowOffset(1, -1)
  f.powerText:SetShadowColor(0, 0, 0, 0.9)
  f.powerText:SetText("")

  f.health = UF.CreateStatusBar(f, 200, 28)
  f.health._flexxUnit = unit
  f.health:EnableMouse(false)

  UF.ApplyUnitFramePowerBarLayout(f)

  -- Prediction sits above the health fill; name/health % need their own layer above prediction (FontStrings have no FrameLevel).
  f.healthPrediction = CreateFrame("Frame", nil, f)
  f.healthPrediction:SetPoint("TOPLEFT", f.health, "TOPLEFT")
  f.healthPrediction:SetPoint("BOTTOMLEFT", f.health, "BOTTOMLEFT")
  f.healthPrediction:SetFrameLevel((f:GetFrameLevel() or 0) + 100)
  f.healthPrediction:EnableMouse(false)
  local function SyncHealthPredictionWidth()
    pcall(function()
      local w = f.health:GetWidth()
      if w and w > 0 then
        -- Clip incoming/absorb at 102% of bar width (not flush at 100%) so strips can show a sliver past full health.
        f.healthPrediction:SetWidth(w * 1.02)
      end
    end)
    UF.SyncInsetPowerBarWidth(f)
  end
  SyncHealthPredictionWidth()
  f.health:HookScript("OnSizeChanged", SyncHealthPredictionWidth)
  -- Clip children to this slightly wider rect (still inside unit frame margins in practice).
  pcall(function()
    if f.healthPrediction.SetClipsChildren then f.healthPrediction:SetClipsChildren(true) end
  end)

  -- Incoming heal / shield: StatusBars so SetValue can use engine-side numbers (12.x secrets break addon Lua math).
  f.incomingHealBar = CreateFrame("StatusBar", nil, f.healthPrediction)
  f.incomingHealBar:SetOrientation("HORIZONTAL")
  f.incomingHealBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  do
    local t = f.incomingHealBar:GetStatusBarTexture()
    if t and t.SetDrawLayer then pcall(function() t:SetDrawLayer("ARTWORK", 0) end) end
  end
  -- Darker than stock bright greens so strips read on class/dark health fills.
  f.incomingHealBar:SetStatusBarColor(0.12, 0.52, 0.26, 0.92)
  f.incomingHealBar:SetMinMaxValues(0, 1)
  f.incomingHealBar:SetValue(0)
  f.incomingHealBar:Hide()

  f.absorbHealBar = CreateFrame("StatusBar", nil, f.healthPrediction)
  f.absorbHealBar:SetOrientation("HORIZONTAL")
  f.absorbHealBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
  do
    local t = f.absorbHealBar:GetStatusBarTexture()
    if t and t.SetDrawLayer then pcall(function() t:SetDrawLayer("ARTWORK", 1) end) end
  end
  f.absorbHealBar:SetStatusBarColor(0.06, 0.44, 0.58, 0.90)
  f.absorbHealBar:SetMinMaxValues(0, 1)
  f.absorbHealBar:SetValue(0)
  f.absorbHealBar:Hide()

  f.healAbsorbTex = f.healthPrediction:CreateTexture(nil, "OVERLAY")
  f.healAbsorbTex:SetTexture("Interface\\Buttons\\WHITE8x8")
  f.healAbsorbTex:SetVertexColor(0.55, 0.12, 0.12, 0.92)
  f.healAbsorbTex:Hide()

  f.healthTextLayer = CreateFrame("Frame", nil, f)
  f.healthTextLayer:SetAllPoints(f.health)
  f.healthTextLayer:SetFrameLevel((f:GetFrameLevel() or 0) + 110)
  f.healthTextLayer:EnableMouse(false)

  f.name = (ns.Fonts and ns.Fonts.CreateFontString(f.healthTextLayer, "OVERLAY", "GameFontNormal", "unit")) or f.healthTextLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("LEFT", f.health, "LEFT", 6, -1)
  f.name:SetPoint("RIGHT", f.health, "RIGHT", -6, -1)
  f.name:SetJustifyH("LEFT")
  f.name:SetDrawLayer("OVERLAY", 7)
  f.name:SetShadowOffset(1, -1)
  f.name:SetShadowColor(0, 0, 0, 0.85)

  f.healthText = (ns.Fonts and ns.Fonts.CreateFontString(f.healthTextLayer, "OVERLAY", "GameFontHighlightSmall", "unit")) or f.healthTextLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.healthText:SetPoint("RIGHT", f.health, "RIGHT", -6, -1)
  f.healthText:SetJustifyH("RIGHT")
  f.healthText:SetDrawLayer("OVERLAY", 8)
  f.healthText:SetShadowOffset(1, -1)
  f.healthText:SetShadowColor(0, 0, 0, 0.9)
  f.healthText:SetText("")

  if unit == "player" then
    BuildPlayerResting(f)
    UF.RemoveFrameBorder(f)
    UF.RemoveStatusBarBorder(f.health)
    UF.RemovePowerBarBorder(f.power)
  elseif unit == "target" then
    UF.RemoveFrameBorder(f)
    UF.RemoveStatusBarBorder(f.health)
  end
  UF.ApplyUnitFrameBackdrop(f)

  if UF.CreateUnitAuras then UF.CreateUnitAuras(f) end

  -- Poll health prediction + heal/absorb APIs (same as Blizzard compact frames); target had no refresh before.
  f.healthRefreshElapsed = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    self.healthRefreshElapsed = self.healthRefreshElapsed + elapsed
    if self.healthRefreshElapsed >= 0.25 then
      self.healthRefreshElapsed = 0
      UF.UpdateUnitFrame(self)
    end
  end)

  f:HookScript("OnEnter", UnitFrame_ShowTooltip)
  f:HookScript("OnLeave", UnitFrame_HideTooltip)

  if ns.Movers and ns.Movers.MakeMovable then
    ns.Movers.MakeMovable("unitframe_" .. key, f, defaultPoint)
  else
    f:SetPoint(unpack(defaultPoint))
  end

  -- Parent/strata/level before first UpdateUnitFrame so threat glow and child levels use the final stack.
  f:SetParent(UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetFrameLevel(0)
  UF.ApplyUnitFrameChildLevels(f)

  RegisterEvents(f, unit)
  UF.UpdateUnitFrame(f)
  UF.state.frames[key] = f
  return f
end

function UF.Create()
  UF.EnsureDB()
  if UF.state.frames.player or UF.state.frames.target then return end
  MakeUnitFrame("player", "player", { "TOPLEFT", UIParent, "BOTTOMLEFT", 0, -20 })
  MakeUnitFrame("target", "target", { "TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, -20 })
  UF.ApplyHideBlizzard()
end

