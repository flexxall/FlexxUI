local _, ns = ...
local UF = ns.UnitFrames

local FULL_POWER_H = 10
local INSET_POWER_H = 5
--- Inset bar is this many pixels narrower than the health bar (total, split evenly on each side).
local INSET_POWER_NARROWER = 20
local POWER_GAP = 4
local BOTTOM_PAD = 8
--- Text along the top of the health bar: bottom edge vs health TOP* (negative Y = lower / more overlap on fill).
local HEALTH_TOP_EDGE_TEXT_Y = -4
local HEALTH_TOP_EDGE_GROUP_Y = HEALTH_TOP_EDGE_TEXT_Y - 2

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

--- Stacking (back→front): threat → deficit → incoming/absorb → health fill → power (above health for inset overlap) → top pips → text.
--- Deficit is f.healthMissingBg; prediction between deficit and health fill; power must be above f.health so the resource strip paints on top.
function UF.ApplyUnitFrameChildLevels(f)
  if not f then return end
  local z = f:GetFrameLevel() or 0
  if f._threatGlowRoot and f._threatGlowRoot.SetFrameLevel then f._threatGlowRoot:SetFrameLevel(z + 1) end
  if f.healthMissingBg and f.healthMissingBg.SetFrameLevel then f.healthMissingBg:SetFrameLevel(z + 2) end
  if f.healthPrediction and f.healthPrediction.SetFrameLevel then f.healthPrediction:SetFrameLevel(z + 3) end
  if f.health and f.health.SetFrameLevel then f.health:SetFrameLevel(z + 4) end
  if f.power and f.power.SetFrameLevel then f.power:SetFrameLevel(z + 6) end
  if f.topBarFrame and f.topBarFrame.SetFrameLevel then f.topBarFrame:SetFrameLevel(z + 7) end
  if f.healthTextLayer and f.healthTextLayer.SetFrameLevel then f.healthTextLayer:SetFrameLevel(z + 10) end
  if f._playerLowHealthChrome and f._playerLowHealthChrome.SetFrameLevel and f.health then
    pcall(function()
      f._playerLowHealthChrome:SetFrameLevel(f.health:GetFrameLevel() + 1)
    end)
  end
  --- Buff/debuff/timer rows must stay above name text & bars so their tooltips win; re-sync if frame level changes.
  local az = z + 200
  if f.auraDebuffHost and f.auraDebuffHost.SetFrameLevel then f.auraDebuffHost:SetFrameLevel(az) end
  if f.auraBuffHost and f.auraBuffHost.SetFrameLevel then f.auraBuffHost:SetFrameLevel(az) end
  if f.auraTimerBarHost and f.auraTimerBarHost.SetFrameLevel then f.auraTimerBarHost:SetFrameLevel(az) end
end

local EnsureBlizzardStockUnitFrameHooks

local function EnsureBlizzardRetryFrame()
  if UF.state.blizzardRetryFrame then return UF.state.blizzardRetryFrame end
  local rf = CreateFrame("Frame")
  rf:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
      self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
    if event == "ADDON_LOADED" then
      --- PlayerFrame_Update / PlayerFrame do not exist until Blizzard_UnitFrame loads (after this file).
      if EnsureBlizzardStockUnitFrameHooks then EnsureBlizzardStockUnitFrameHooks() end
      if _G.FlexxUIDB and _G.FlexxUIDB.hideBlizzard then
        UF.ApplyHideBlizzard()
      end
      return
    end
    if EnsureBlizzardStockUnitFrameHooks then EnsureBlizzardStockUnitFrameHooks() end
    UF.ApplyHideBlizzard()
  end)
  rf:RegisterEvent("PLAYER_ENTERING_WORLD")
  rf:RegisterEvent("ADDON_LOADED")
  UF.state.blizzardRetryFrame = rf
  return rf
end

local function IsInCombatLockdown()
  return InCombatLockdown and InCombatLockdown()
end

--- RegisterEvent from secure hooks / combat paths is tainted; defer to next frame (Retail ADDON_ACTION_FORBIDDEN on RegisterEvent).
local function RegisterRegenRetryDeferred()
  if not C_Timer or not C_Timer.After then
    EnsureBlizzardRetryFrame():RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  C_Timer.After(0, function()
    local rf = EnsureBlizzardRetryFrame()
    if rf and rf.RegisterEvent then
      rf:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
  end)
end

--- First ApplyHideBlizzard often runs before frames exist, or while InCombatLockdown() is true. Poll until each stock frame is hidden.
--- Do not require both PlayerFrame and TargetFrame: TargetFrame can load later; waiting for both left the player default frame visible.
local hideBlizzardRetrySeq = 0
local function ScheduleHideBlizzardRetry()
  if not C_Timer or not C_Timer.After then return end
  hideBlizzardRetrySeq = hideBlizzardRetrySeq + 1
  local seq = hideBlizzardRetrySeq
  local n = 0
  local function tick()
    if seq ~= hideBlizzardRetrySeq then return end
    n = n + 1
    if n > 400 then return end
    UF.EnsureDB()
    if not _G.FlexxUIDB.hideBlizzard then return end
    UF.ApplyHideBlizzard()
    if not _G.FlexxUIDB.hideBlizzard then return end
    if IsInCombatLockdown() then
      C_Timer.After(0, tick)
      return
    end
    local needRetry = not PlayerFrame or not TargetFrame
    if PlayerFrame and PlayerFrame:IsShown() then needRetry = true end
    if TargetFrame and TargetFrame:IsShown() then needRetry = true end
    if needRetry then
      C_Timer.After(0, tick)
    end
  end
  C_Timer.After(0, tick)
end

local function HookBlizzardUnitOnShow(frame)
  if not frame or not frame.HookScript or frame._flexxBlizzardHideHook then return end
  frame._flexxBlizzardHideHook = true
  frame:HookScript("OnShow", function(self)
    if not _G.FlexxUIDB or not _G.FlexxUIDB.hideBlizzard then return end
    if IsInCombatLockdown() then
      RegisterRegenRetryDeferred()
      ScheduleHideBlizzardRetry()
      return
    end
    pcall(function()
      self:SetAlpha(0)
      self:EnableMouse(false)
      self:Hide()
    end)
  end)
end

local function RestoreBlizzardUnitFrames()
  if IsInCombatLockdown() then
    RegisterRegenRetryDeferred()
    return
  end
  if PlayerFrame then
    pcall(function()
      PlayerFrame:SetAlpha(1)
      PlayerFrame:EnableMouse(true)
      PlayerFrame:Show()
    end)
    for _, key in ipairs({ "PlayerFrameContainer", "PlayerFrameContent" }) do
      local c = PlayerFrame[key] or _G[key]
      if c then
        pcall(function()
          c:SetAlpha(1)
          c:EnableMouse(true)
          c:Show()
        end)
      end
    end
  end
  if TargetFrame then
    pcall(function()
      TargetFrame:SetAlpha(1)
      TargetFrame:EnableMouse(true)
      TargetFrame:Show()
    end)
    for _, key in ipairs({ "TargetFrameContainer", "TargetFrameContent" }) do
      local c = TargetFrame[key] or _G[key]
      if c then
        pcall(function()
          c:SetAlpha(1)
          c:EnableMouse(true)
          c:Show()
        end)
      end
    end
  end
end

--- Retail splits chrome across Container + Content; hide each root Blizzard may Show independently.
local function HideBlizzardUnitFrameExtraRoots(frame)
  if frame == PlayerFrame and PlayerFrame then
    for _, key in ipairs({ "PlayerFrameContainer", "PlayerFrameContent" }) do
      local c = PlayerFrame[key] or _G[key]
      if c and c.Hide then
        HookBlizzardUnitOnShow(c)
        pcall(function()
          c:SetAlpha(0)
          c:EnableMouse(false)
          c:Hide()
        end)
      end
    end
  elseif frame == TargetFrame and TargetFrame then
    for _, key in ipairs({ "TargetFrameContainer", "TargetFrameContent" }) do
      local c = TargetFrame[key] or _G[key]
      if c and c.Hide then
        HookBlizzardUnitOnShow(c)
        pcall(function()
          c:SetAlpha(0)
          c:EnableMouse(false)
          c:Hide()
        end)
      end
    end
  end
end

local playerFramePostHidePending
local targetFramePostHidePending
local function RequestDeferredBlizzardUnitHide(which)
  if not C_Timer or not C_Timer.After then return end
  if which == "player" then
    if playerFramePostHidePending then return end
    playerFramePostHidePending = true
    C_Timer.After(0, function()
      playerFramePostHidePending = nil
      if not _G.FlexxUIDB or not _G.FlexxUIDB.hideBlizzard then return end
      if IsInCombatLockdown() then
        RegisterRegenRetryDeferred()
        ScheduleHideBlizzardRetry()
        return
      end
      if PlayerFrame and PlayerFrame:IsShown() then
        HideOneBlizzardUnitFrame(PlayerFrame)
      end
    end)
  elseif which == "target" then
    if targetFramePostHidePending then return end
    targetFramePostHidePending = true
    C_Timer.After(0, function()
      targetFramePostHidePending = nil
      if not _G.FlexxUIDB or not _G.FlexxUIDB.hideBlizzard then return end
      if IsInCombatLockdown() then
        RegisterRegenRetryDeferred()
        ScheduleHideBlizzardRetry()
        return
      end
      if TargetFrame and TargetFrame:IsShown() then
        HideOneBlizzardUnitFrame(TargetFrame)
      end
    end)
  end
end

local function HideOneBlizzardUnitFrame(frame)
  if not frame then return end
  HookBlizzardUnitOnShow(frame)
  HideBlizzardUnitFrameExtraRoots(frame)
  pcall(function()
    frame:SetAlpha(0)
    frame:EnableMouse(false)
    frame:Hide()
  end)
end

--- Installed after Blizzard_UnitFrame loads: at FlexxUI file load, PlayerFrame_Update is still nil so hooks must be deferred.
local blizzardPlayerUpdateHooked = false
local blizzardTargetUpdateHooked = false
local blizzardPlayerShowHooked = false
local blizzardTargetShowHooked = false

EnsureBlizzardStockUnitFrameHooks = function()
  if not hooksecurefunc then return end
  if not blizzardPlayerUpdateHooked and type(_G.PlayerFrame_Update) == "function" then
    blizzardPlayerUpdateHooked = true
    hooksecurefunc("PlayerFrame_Update", function()
      if not _G.FlexxUIDB or not _G.FlexxUIDB.hideBlizzard then return end
      RequestDeferredBlizzardUnitHide("player")
    end)
  end
  if not blizzardTargetUpdateHooked and type(_G.TargetFrame_Update) == "function" then
    blizzardTargetUpdateHooked = true
    hooksecurefunc("TargetFrame_Update", function()
      if not _G.FlexxUIDB or not _G.FlexxUIDB.hideBlizzard then return end
      RequestDeferredBlizzardUnitHide("target")
    end)
  end
  local pf = _G.PlayerFrame
  if not blizzardPlayerShowHooked and pf then
    blizzardPlayerShowHooked = true
    hooksecurefunc(pf, "Show", function(self)
      if not _G.FlexxUIDB or not _G.FlexxUIDB.hideBlizzard then return end
      if self == pf then
        RequestDeferredBlizzardUnitHide("player")
      end
    end)
  end
  local tf = _G.TargetFrame
  if not blizzardTargetShowHooked and tf then
    blizzardTargetShowHooked = true
    hooksecurefunc(tf, "Show", function(self)
      if not _G.FlexxUIDB or not _G.FlexxUIDB.hideBlizzard then return end
      if self == tf then
        RequestDeferredBlizzardUnitHide("target")
      end
    end)
  end
end

local function HideBlizzardUnitFrames()
  if IsInCombatLockdown() then
    RegisterRegenRetryDeferred()
    ScheduleHideBlizzardRetry()
    return
  end
  HideOneBlizzardUnitFrame(PlayerFrame)
  HideOneBlizzardUnitFrame(TargetFrame)
  if not PlayerFrame or not TargetFrame then
    ScheduleHideBlizzardRetry()
  end
end

function UF.ApplyHideBlizzard()
  UF.EnsureDB()
  EnsureBlizzardStockUnitFrameHooks()
  if _G.FlexxUIDB.hideBlizzard then
    HideBlizzardUnitFrames()
  else
    RestoreBlizzardUnitFrames()
  end
end

local function BuildPlayerResting(f)
  -- Same layer as name/health text but above the StatusBar fill: parent to healthTextLayer (high FrameLevel) + draw sublayer on top.
  local zParent = f.healthTextLayer or f
  local zSmall = (ns.Fonts and ns.Fonts.CreateFontString(zParent, "OVERLAY", "GameFontHighlightSmall", "unit")) or zParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  -- BOTTOMLEFT→health TOPLEFT: here, positive Y shifts the row *up* above the bar; use negative Y to sit lower so zzz overlaps the top edge of the fill.
  zSmall:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, HEALTH_TOP_EDGE_TEXT_Y)
  zSmall:SetText("z")
  ns.SetFontStringFlexxGoldColor(zSmall)
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
  ns.SetFontStringFlexxGoldColor(zMid)
  zMid:SetShadowOffset(1, -1)
  pcall(function() zMid:SetDrawLayer("OVERLAY", 9) end)
  zMid:Hide()

  local zBig = (ns.Fonts and ns.Fonts.CreateFontString(zParent, "OVERLAY", "GameFontNormal", "unit")) or zParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  local zBigExtraX = 1
  zBig:SetPoint("BOTTOMLEFT", zMid, "BOTTOMRIGHT", 2 + zBigExtraX, zChainDy)
  zBig:SetText("Z")
  ns.SetFontStringFlexxGoldColor(zBig)
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
    if event == "PLAYER_UPDATE_RESTING"
      or event == "UPDATE_EXHAUSTION"
      or event == "PLAYER_REGEN_DISABLED"
      or event == "PLAYER_REGEN_ENABLED" then
      --- Full refresh: resting + threat/aggro mask (REGEN alone used to skip UpdateThreatGlow until next OnUpdate).
      if self.unit == "player" then UF.UpdateUnitFrame(self) end
      return
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
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
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_UPDATE_RESTING")
    frame:RegisterEvent("UPDATE_EXHAUSTION")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
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

  -- Full-bar "missing health" color on its own layer *under* incoming heal/absorb; StatusBar backdrop cleared in ApplyHealthBarMissingColor.
  f.healthMissingBg = CreateFrame("Frame", nil, f)
  f.healthMissingBg:SetPoint("TOPLEFT", f.health, "TOPLEFT")
  f.healthMissingBg:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT")
  f.healthMissingBg:SetFrameLevel((f:GetFrameLevel() or 0) + 2)
  f.healthMissingBg:EnableMouse(false)
  local defTex = f.healthMissingBg:CreateTexture(nil, "BACKGROUND")
  defTex:SetAllPoints()
  defTex:SetTexture("Interface\\Buttons\\WHITE8x8")
  f.healthMissingBg._flexxDeficitTex = defTex
  f.health._flexxMissingBg = f.healthMissingBg
  UF.ApplyHealthBarMissingColor(f.health)

  UF.ApplyUnitFramePowerBarLayout(f)

  -- Incoming heal / absorb: between deficit layer and health fill (see ApplyUnitFrameChildLevels).
  f.healthPrediction = CreateFrame("Frame", nil, f)
  f.healthPrediction:SetPoint("TOPLEFT", f.health, "TOPLEFT")
  f.healthPrediction:SetPoint("BOTTOMLEFT", f.health, "BOTTOMLEFT")
  f.healthPrediction:SetFrameLevel((f:GetFrameLevel() or 0) + 3)
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
  f.healthTextLayer:SetFrameLevel((f:GetFrameLevel() or 0) + 10)
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
    do
      local zParent = f.healthTextLayer or f
      -- Slightly larger than health row + outline (via Fonts.lua) so G# reads clearly on the bar edge.
      local gInd = (ns.Fonts and ns.Fonts.CreateFontString(zParent, "OVERLAY", "GameFontHighlight", "unit")) or zParent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      gInd._flexxFontExtraSize = 1
      gInd._flexxFontOutline = true
      -- Slightly below the zzz row so the larger outlined G# sits on the bar edge cleanly.
      gInd:SetPoint("BOTTOMRIGHT", f.health, "TOPRIGHT", -6, HEALTH_TOP_EDGE_GROUP_Y)
      gInd:SetJustifyH("RIGHT")
      gInd:SetTextColor(1, 0.94, 0.78)
      -- Outline provides the edge; drop shadow would stack ugly on top.
      gInd:SetShadowOffset(0, 0)
      gInd:SetShadowColor(0, 0, 0, 0)
      pcall(function() gInd:SetDrawLayer("OVERLAY", 9) end)
      gInd:Hide()
      f.groupIndicator = gInd
    end
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

  f:HookScript("OnEnter", function(self)
    --- Parent OnEnter can fire over the same pixels as aura rows and overwrite spell tooltips with the unit tip.
    if UF.IsMouseOverAuraHosts and UF.IsMouseOverAuraHosts(self) then
      return
    end
    UnitFrame_ShowTooltip(self)
  end)
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
  if not UF.state.frames.player then
    MakeUnitFrame("player", "player", { "TOPLEFT", UIParent, "BOTTOMLEFT", 0, -20 })
  end
  if not UF.state.frames.target then
    MakeUnitFrame("target", "target", { "TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, -20 })
  end
  --- Next frame + retry until stock frames exist and lockdown allows hiding (see ScheduleHideBlizzardRetry).
  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      UF.ApplyHideBlizzard()
      if _G.FlexxUIDB.hideBlizzard then
        ScheduleHideBlizzardRetry()
      end
    end)
  else
    UF.ApplyHideBlizzard()
  end
end

