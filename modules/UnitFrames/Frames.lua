local _, ns = ...
local UF = ns.UnitFrames

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
  local zSmall = (ns.Fonts and ns.Fonts.CreateFontString(f, "OVERLAY", "GameFontHighlightSmall", "unit")) or f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  zSmall:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, 4)
  zSmall:SetText("z")
  zSmall:SetTextColor(1, 0.88, 0.35)
  zSmall:SetShadowOffset(1, -1)
  zSmall:Hide()

  local zMid = (ns.Fonts and ns.Fonts.CreateFontString(f, "OVERLAY", "GameFontHighlight", "unit")) or f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  zMid:SetPoint("LEFT", zSmall, "RIGHT", 2, 0)
  zMid:SetText("z")
  zMid:SetTextColor(1, 0.88, 0.35)
  zMid:SetShadowOffset(1, -1)
  zMid:Hide()

  local zBig = (ns.Fonts and ns.Fonts.CreateFontString(f, "OVERLAY", "GameFontNormal", "unit")) or f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  zBig:SetPoint("LEFT", zMid, "RIGHT", 2, 0)
  zBig:SetText("Z")
  zBig:SetTextColor(1, 0.88, 0.35)
  zBig:SetShadowOffset(1, -1)
  zBig:Hide()

  local function Lerp(a, b, t) return a + (b - a) * t end
  f.restingIcons = { zSmall, zMid, zBig }
  f.restingPulseTime = 0
  f.restingPulseDriver = CreateFrame("Frame", nil, f)
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
    if event == "PLAYER_TARGET_CHANGED" then
      if self.unit == "target" then UF.UpdateUnitFrame(self) end
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
  frame:RegisterUnitEvent("UNIT_POWER_UPDATE", unit)
  frame:RegisterUnitEvent("UNIT_MAXPOWER", unit)
  frame:RegisterUnitEvent("UNIT_DISPLAYPOWER", unit)
end

local function MakeUnitFrame(key, unit, defaultPoint)
  local f = CreateFrame("Button", "FlexxUI_UnitFrame_" .. key, UIParent, "SecureUnitButtonTemplate,BackdropTemplate")
  local powerH, gap = 10, 4
  local bottomPad = 8
  local healthBottom = bottomPad + powerH + gap
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

  f.power = UF.CreatePowerBar(f, 200, powerH)
  f.power._flexxBarRole = "power"
  f.power:SetPoint("BOTTOMLEFT", 10, bottomPad)
  f.power:SetPoint("BOTTOMRIGHT", -10, bottomPad)
  f.power:SetFrameLevel(f:GetFrameLevel())

  f.powerText = (ns.Fonts and ns.Fonts.CreateFontString(f.power, "OVERLAY", "GameFontHighlightSmall", "unit")) or f.power:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.powerText:SetPoint("CENTER", f.power, "CENTER", 0, 0)
  f.powerText:SetJustifyH("CENTER")
  f.powerText:SetDrawLayer("OVERLAY", 7)
  f.powerText:SetShadowOffset(1, -1)
  f.powerText:SetShadowColor(0, 0, 0, 0.9)
  f.powerText:SetText("")

  f.health = UF.CreateStatusBar(f, 200, 28)
  f.health._flexxUnit = unit
  f.health:SetPoint("BOTTOMLEFT", 10, healthBottom)
  f.health:SetPoint("BOTTOMRIGHT", -10, healthBottom)
  f.health:SetFrameLevel(f:GetFrameLevel())
  f.health:EnableMouse(false)

  f.name = (ns.Fonts and ns.Fonts.CreateFontString(f, "OVERLAY", "GameFontNormal", "unit")) or f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.name:SetPoint("LEFT", f.health, "LEFT", 6, -5)
  f.name:SetPoint("RIGHT", f.health, "RIGHT", -6, -5)
  f.name:SetJustifyH("LEFT")
  f.name:SetDrawLayer("OVERLAY", 7)
  f.name:SetShadowOffset(1, -1)
  f.name:SetShadowColor(0, 0, 0, 0.85)

  f.healthText = (ns.Fonts and ns.Fonts.CreateFontString(f, "OVERLAY", "GameFontHighlightSmall", "unit")) or f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.healthText:SetPoint("RIGHT", f.health, "RIGHT", -6, -5)
  f.healthText:SetJustifyH("RIGHT")
  f.healthText:SetDrawLayer("OVERLAY", 8)
  f.healthText:SetShadowOffset(1, -1)
  f.healthText:SetShadowColor(0, 0, 0, 0.9)
  f.healthText:SetText("")

  -- Prediction layer: child Frame of f (not of f.health) with high FrameLevel so it draws above name/healthText.
  -- Textures use default OVERLAY (sublevel 0–7 cap); frame stacking handles ordering vs font strings.
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

  if unit == "player" then
    BuildPlayerResting(f)
    UF.RemoveFrameBorder(f)
    UF.RemoveStatusBarBorder(f.health)
    UF.RemovePowerBarBorder(f.power)
  elseif unit == "target" then
    UF.RemoveFrameBorder(f)
  end
  UF.ApplyUnitFrameBackdrop(f)

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

  RegisterEvents(f, unit)
  UF.UpdateUnitFrame(f)
  UF.state.frames[key] = f
  -- Parent to UIParent only: FlexxUI_Shell uses DIALOG strata; parenting HUD to it pulls frames above mining/profession UI.
  f:SetParent(UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetFrameLevel(0)
  return f
end

function UF.Create()
  UF.EnsureDB()
  if UF.state.frames.player or UF.state.frames.target then return end
  local shell = ns.Shell and ns.Shell.Get and ns.Shell.Get()
  local anchor = shell or UIParent
  MakeUnitFrame("player", "player", { "TOPLEFT", anchor, "BOTTOMLEFT", 0, -20 })
  MakeUnitFrame("target", "target", { "TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -20 })
  UF.ApplyHideBlizzard()
end

