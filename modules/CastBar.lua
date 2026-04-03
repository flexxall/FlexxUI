local _, ns = ...

--- Player + target cast bars (same size as unit-frame power bar: UnitFrames/Frames.lua powerH + insets).
local CB = {}
ns.CastBar = CB

CB.state = CB.state or {}

-- Bar fill width 225px (matches unit power bar). Optional spell icon on the left.
local CAST_BAR_W = 225
local CAST_BAR_H = 10
local CAST_ICON_SIZE = 10
local CAST_ICON_GAP = 2
local CAST_FRAME_W = CAST_ICON_SIZE + CAST_ICON_GAP + CAST_BAR_W
--- TOPLEFT→unit BOTTOMLEFT Y offset. Positive moves the cast bar up on screen (tighter under the frame). Ignored until you reset a saved drag position (layout DB overrides defaults).
local CAST_BAR_UF_Y_OFFSET = 10
--- Same horizontal inset as the health bar (Frames.lua: health BOTTOMLEFT x from unit frame).
local UNIT_FRAME_HEALTH_INSET = 10
--- X offset for the cast bar *frame* TOPLEFT→unit BOTTOMLEFT so the **status bar fill** (right of icon+gap) lines up with the health bar left — not the outer frame, which includes the spell icon on the left.
local CAST_BAR_FRAME_ANCHOR_X = UNIT_FRAME_HEALTH_INSET - CAST_ICON_SIZE - CAST_ICON_GAP

local UF = ns.UnitFrames

function CB.EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  -- Legacy: layout preview duplicated "show empty bar"; migrate once.
  if _G.FlexxUIDB.castBarLayoutPreview then
    _G.FlexxUIDB.castBarShowIdle = true
    _G.FlexxUIDB.castBarTargetShowIdle = true
    _G.FlexxUIDB.castBarLayoutPreview = nil
  end
  if _G.FlexxUIDB.castBarEnabled == nil then _G.FlexxUIDB.castBarEnabled = true end
  if _G.FlexxUIDB.castBarShowIdle == nil then _G.FlexxUIDB.castBarShowIdle = false end
  if _G.FlexxUIDB.castBarTargetEnabled == nil then _G.FlexxUIDB.castBarTargetEnabled = true end
  if _G.FlexxUIDB.castBarTargetShowIdle == nil then _G.FlexxUIDB.castBarTargetShowIdle = false end
  if _G.FlexxUIDB.hideBlizzardCastBar == nil then _G.FlexxUIDB.hideBlizzardCastBar = false end
  if _G.FlexxUIDB.castBarTextColorMode == nil then _G.FlexxUIDB.castBarTextColorMode = "light" end
  if _G.FlexxUIDB.castBarFillStyle == nil then _G.FlexxUIDB.castBarFillStyle = "default" end
end

--- Default cast bars are secure; Hide/Show from hooks or option clicks (tainted) causes "Interface action failed" / addon blocked.
local function HideBlizzardCastBarFrame(bar)
  if not bar then return end
  if InCombatLockdown and InCombatLockdown() then
    pcall(function()
      bar:SetAlpha(0)
    end)
    pcall(function()
      if bar.EnableMouse then
        bar:EnableMouse(false)
      end
    end)
  else
    pcall(function()
      bar:SetAlpha(1)
    end)
    pcall(function()
      bar:Hide()
    end)
  end
end

local function ShowBlizzardCastBarFrame(bar)
  if not bar then return end
  pcall(function()
    bar:SetAlpha(1)
  end)
  pcall(function()
    if bar.EnableMouse then
      bar:EnableMouse(true)
    end
  end)
  pcall(function()
    bar:Show()
  end)
end

local function HookHideBlizzardCastOnShow(bar)
  if not bar or not bar.HookScript or bar._flexxUICastHook then return end
  bar._flexxUICastHook = true
  bar:HookScript("OnShow", function(self)
    if not (_G.FlexxUIDB and _G.FlexxUIDB.hideBlizzardCastBar) then return end
    HideBlizzardCastBarFrame(self)
  end)
end

local function CastBarFillRGB(kind)
  CB.EnsureDB()
  local dark = (_G.FlexxUIDB.castBarFillStyle or "default") == "dark"
  if kind == "idle" then
    if dark then return 0.11, 0.12, 0.14 end
    return 0.22, 0.22, 0.26
  end
  if kind == "channel" then
    if dark then return 0.10, 0.48, 0.22 end
    return 0.2, 0.82, 0.38
  end
  -- cast
  if dark then return 0.72, 0.38, 0.08 end
  return 1, 0.62, 0.12
end

local function ApplyHideBlizzardCastBar()
  CB.EnsureDB()
  local hide = _G.FlexxUIDB.hideBlizzardCastBar
  if InCombatLockdown and InCombatLockdown() then
    if not CB.state.blizzardRetry then
      local rf = CreateFrame("Frame")
      rf:SetScript("OnEvent", function(self, event)
        if event ~= "PLAYER_REGEN_ENABLED" then return end
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        ApplyHideBlizzardCastBar()
      end)
      CB.state.blizzardRetry = rf
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        local rf = CB.state.blizzardRetry
        if rf and rf.RegisterEvent then
          rf:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
      end)
    else
      CB.state.blizzardRetry:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    return
  end

  local bar = _G.PlayerCastingBar
  if bar and bar.HookScript then
    if hide then
      HideBlizzardCastBarFrame(bar)
      HookHideBlizzardCastOnShow(bar)
    else
      ShowBlizzardCastBarFrame(bar)
    end
  end

  -- Default target cast UI (also used by other addons); hiding avoids duplicate bars with FlexxUI target cast and reduces taint issues in Blizzard CastingBarFrame.
  local tbar = _G.TargetFrameSpellBar
  if tbar and tbar.HookScript then
    if hide then
      HideBlizzardCastBarFrame(tbar)
      if not tbar._flexxUITargetCastHook then
        tbar._flexxUITargetCastHook = true
        tbar:HookScript("OnShow", function(self)
          if _G.FlexxUIDB and _G.FlexxUIDB.hideBlizzardCastBar then
            HideBlizzardCastBarFrame(self)
          end
        end)
      end
    else
      ShowBlizzardCastBarFrame(tbar)
      pcall(function()
        if _G.TargetFrame_Update and _G.TargetFrame then
          _G.TargetFrame_Update(_G.TargetFrame)
        end
      end)
    end
  end
end

--- Options / UI paths are tainted; defer Blizzard frame changes to next frame.
local function ScheduleApplyHideBlizzardCastBar()
  if C_Timer and C_Timer.After then
    C_Timer.After(0, ApplyHideBlizzardCastBar)
  else
    ApplyHideBlizzardCastBar()
  end
end

--- Cast APIs may return secret values on Retail; never do Lua math on raw returns.
--- spellId is the 9th return; icon file id/path is the 3rd return (texture) from UnitCastingInfo / UnitChannelInfo.
local function GetUnitCast(unit)
  if unit == "target" and (not UnitExists("target")) then
    return nil
  end
  local ok, name, _text, iconTexture, startMS, endMS, _trade, _cid, _nintr, spellId = pcall(UnitCastingInfo, unit)
  if ok and name then
    return "cast", name, startMS, endMS, spellId, iconTexture
  end
  ok, name, _text, iconTexture, startMS, endMS, _trade, _cid, _nintr, spellId = pcall(UnitChannelInfo, unit)
  if ok and name then
    return "channel", name, startMS, endMS, spellId, iconTexture
  end
  return nil
end

local function SetCastBarSpellIcon(self, spellId, iconTextureFromApi)
  local tex = self.spellIcon
  if not tex then return end
  local path
  if spellId then
    if C_Spell and C_Spell.GetSpellTexture then
      local ok, t = pcall(function()
        return C_Spell.GetSpellTexture(spellId)
      end)
      if ok and t then path = t end
    end
    if not path and GetSpellTexture then
      local ok, t = pcall(GetSpellTexture, spellId)
      if ok and t then path = t end
    end
  end
  if not path and iconTextureFromApi then
    path = iconTextureFromApi
  end
  if path then
    tex:SetTexture(path)
    tex:Show()
  else
    tex:Hide()
  end
end

-- Fishing is a channel; bar should deplete (count down) instead of filling like other channels.
local FISHING_SPELL_IDS = {
  [7620] = true, -- Fishing (classic / retail base spell; variants may differ by expansion)
}

local function IsFishingChannel(spellId, name)
  if spellId and FISHING_SPELL_IDS[spellId] then
    return true
  end
  -- Name from UnitCastingInfo/UnitChannelInfo may be a secret string: no :lower() / :find().
  if name == nil then return false end
  local ok, fishing = pcall(function()
    local n = tostring(name)
    if n == "" then return false end
    n = string.lower(n)
    return string.find(n, "fishing", 1, true) ~= nil
  end)
  return ok and fishing == true
end

local function ComputeCastProgress(startMS, endMS)
  local s = UF.PlainNumber(startMS, nil)
  local e = UF.PlainNumber(endMS, nil)
  local nowMs = UF.PlainNumber(GetTime() * 1000, nil)
  if s ~= nil and e ~= nil and nowMs ~= nil then
    local dur = e - s
    if dur < 1 then dur = 1 end
    local p = (nowMs - s) / dur
    if p < 0 then p = 0 end
    if p > 1 then p = 1 end
    local remain = (e - nowMs) / 1000
    if remain < 0 then remain = 0 end
    return p, remain
  end
  local ok, p, remain = pcall(function()
    local sm = startMS + 0
    local em = endMS + 0
    local now = GetTime() * 1000
    local dur = em - sm
    if dur < 1 then dur = 1 end
    local prog = (now - sm) / dur
    if prog < 0 then prog = 0 end
    if prog > 1 then prog = 1 end
    local rem = (em - now) / 1000
    if rem < 0 then rem = 0 end
    return prog, rem
  end)
  if ok and type(p) == "number" and type(remain) == "number" then
    return p, remain
  end
  return 0, 0
end

local function SetCastNameText(fs, name)
  if not fs then return end
  local ok, txt = pcall(function()
    if name == nil then return "" end
    return tostring(name)
  end)
  fs:SetText(ok and txt or "")
end

--- Spell name + cast time use the same color (see castBarTextColorMode in options).
local function ApplyCastTextColor(self)
  if not self or not self.nameText or not self.timeText then return end
  CB.EnsureDB()
  local mode = _G.FlexxUIDB.castBarTextColorMode or "light"
  local r, g, b
  if mode == "class_color" then
    local unit = self.watchUnit
    local fr = (unit == "player" and UF.state.frames.player) or (unit == "target" and UF.state.frames.target)
    if fr and UF.GetEffectiveNameTextColorRGB then
      r, g, b = UF.GetEffectiveNameTextColorRGB(fr)
    else
      r, g, b = 0.95, 0.95, 0.95
    end
  elseif mode == "dark" then
    r, g, b = 0.12, 0.12, 0.14
  elseif mode == "warm_yellow" then
    r, g, b = 1, 0.88, 0.35
  else
    r, g, b = 0.95, 0.95, 0.95
  end
  self.nameText:SetTextColor(r, g, b)
  self.timeText:SetTextColor(r, g, b)
end

local function ApplyIdle(self)
  self.bar:SetMinMaxValues(0, 1)
  self.bar:SetValue(0)
  self.bar:SetStatusBarColor(0.22, 0.22, 0.26)
  self.nameText:SetText("")
  self.timeText:SetText("")
  if self.spellIcon then self.spellIcon:Hide() end
  ApplyCastTextColor(self)
  self:Show()
end

local unitSpellEvents = {
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTED",
  "UNIT_SPELLCAST_DELAYED",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_CHANNEL_UPDATE",
}

local function UpdateCastBarFrame(self)
  CB.EnsureDB()
  local unit = self.watchUnit
  local enabled
  if unit == "player" then
    enabled = _G.FlexxUIDB.castBarEnabled ~= false
  else
    enabled = _G.FlexxUIDB.castBarTargetEnabled ~= false
  end
  if not enabled then
    self:Hide()
    return
  end

  if unit == "target" and not UnitExists("target") then
    self:Hide()
    return
  end

  local kind, name, startMS, endMS, spellId, iconTexture = GetUnitCast(unit)
  if not kind then
    local showIdle
    if unit == "player" then
      showIdle = _G.FlexxUIDB.castBarShowIdle == true
    else
      showIdle = _G.FlexxUIDB.castBarTargetShowIdle == true and UnitExists("target")
    end
    if showIdle then
      ApplyIdle(self)
    else
      self:Hide()
    end
    return
  end

  local p, remain = ComputeCastProgress(startMS, endMS)

  self.bar:SetMinMaxValues(0, 1)
  -- Fishing channel: show remaining time as a shrinking bar (same progress math, inverted fill).
  local fill = p
  if kind == "channel" and IsFishingChannel(spellId, name) then
    fill = 1 - p
  end
  self.bar:SetValue(fill)

  SetCastNameText(self.nameText, name)
  local okFmt, timeStr = pcall(function()
    return string.format("%.1f", remain)
  end)
  self.timeText:SetText(okFmt and timeStr or "--")

  if kind == "channel" then
    local r, g, b = CastBarFillRGB("channel")
    self.bar:SetStatusBarColor(r, g, b)
  else
    local r, g, b = CastBarFillRGB("cast")
    self.bar:SetStatusBarColor(r, g, b)
  end

  ApplyCastTextColor(self)
  SetCastBarSpellIcon(self, spellId, iconTexture)
  self:Show()
end

function CB.RefreshFromOptions()
  CB.EnsureDB()
  local function refreshCastBackdrop(fr)
    if fr and fr.bar and UF.ApplyPowerBarBackdrop then
      UF.ApplyPowerBarBackdrop(fr.bar)
    end
  end
  refreshCastBackdrop(CB.state.frame)
  refreshCastBackdrop(CB.state.frameTarget)
  if CB.state.frame then
    UpdateCastBarFrame(CB.state.frame)
  end
  if CB.state.frameTarget then
    UpdateCastBarFrame(CB.state.frameTarget)
  end
  ScheduleApplyHideBlizzardCastBar()
end

--- Default anchor for player or target cast bar (same rules as initial Create).
function CB.GetDefaultCastBarPoint(unit)
  if not UF then
    return unit == "target" and { "CENTER", UIParent, "CENTER", 0, -180 } or { "CENTER", UIParent, "CENTER", 0, -120 }
  end
  if unit == "player" then
    local playerUF = UF.state and UF.state.frames and UF.state.frames.player
    return playerUF and { "TOPLEFT", playerUF, "BOTTOMLEFT", CAST_BAR_FRAME_ANCHOR_X, CAST_BAR_UF_Y_OFFSET }
      or { "CENTER", UIParent, "CENTER", 0, -120 }
  end
  if unit == "target" then
    local targetUF = UF.state and UF.state.frames and UF.state.frames.target
    return targetUF and { "TOPLEFT", targetUF, "BOTTOMLEFT", CAST_BAR_FRAME_ANCHOR_X, CAST_BAR_UF_Y_OFFSET }
      or { "CENTER", UIParent, "CENTER", 0, -180 }
  end
  return { "CENTER", UIParent, "CENTER", 0, 0 }
end

--- Reset one cast bar's saved position to the current default (does not affect other movers or options).
function CB.ResetCastBarPosition(unit)
  if unit ~= "player" and unit ~= "target" then return end
  local key = unit == "target" and "castbar_target" or "castbar"
  local frame = unit == "target" and CB.state.frameTarget or CB.state.frame
  if not frame then return end
  local def = CB.GetDefaultCastBarPoint(unit)
  if ns.Movers and ns.Movers.ResetToDefault then
    ns.Movers.ResetToDefault(key, frame, def)
  else
    frame:ClearAllPoints()
    frame:SetPoint(unpack(def))
  end
end

local function CreateCastBarUnitFrame(unit, moverKey, defaultPoint)
  local frameName = unit == "player" and "FlexxUI_CastBar" or "FlexxUI_CastBarTarget"
  local f = CreateFrame("Frame", frameName, UIParent)
  f.watchUnit = unit
  f:SetSize(CAST_FRAME_W, CAST_BAR_H)

  f.spellIcon = f:CreateTexture(nil, "ARTWORK")
  f.spellIcon:SetSize(CAST_ICON_SIZE, CAST_ICON_SIZE)
  f.spellIcon:SetPoint("LEFT", f, "LEFT", 0, 0)
  f.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.spellIcon:Hide()

  f.bar = UF.CreatePowerBar(f, CAST_BAR_W, CAST_BAR_H)
  f.bar._flexxBarRole = "cast"
  f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", CAST_ICON_SIZE + CAST_ICON_GAP, 0)
  f.bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
  f.bar:EnableMouse(false)

  -- StatusBar fill draws above sibling FontStrings; text must live on a higher FrameLevel layer.
  f.textOverlay = CreateFrame("Frame", nil, f)
  f.textOverlay:SetAllPoints(f.bar)
  f.textOverlay:SetFrameLevel((f.bar:GetFrameLevel() or 0) + 15)
  f.textOverlay:EnableMouse(false)

  f.nameText = (ns.Fonts and ns.Fonts.CreateFontString(f.textOverlay, "OVERLAY", "GameFontHighlightSmall", "unit")) or f.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.nameText:SetPoint("LEFT", f.textOverlay, "LEFT", 4, 0)
  f.nameText:SetPoint("RIGHT", f.textOverlay, "RIGHT", -52, 0)
  f.nameText:SetJustifyH("LEFT")
  f.nameText:SetMaxLines(1)
  f.nameText:SetWordWrap(false)
  if f.nameText.SetDrawLayer then
    pcall(function() f.nameText:SetDrawLayer("OVERLAY", 7) end)
  end
  f.nameText:SetShadowOffset(1, -1)
  f.nameText:SetShadowColor(0, 0, 0, 0.9)

  f.timeText = (ns.Fonts and ns.Fonts.CreateFontString(f.textOverlay, "OVERLAY", "GameFontHighlightSmall", "unit")) or f.textOverlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.timeText:SetPoint("RIGHT", f.textOverlay, "RIGHT", -4, 0)
  f.timeText:SetJustifyH("RIGHT")
  if f.timeText.SetDrawLayer then
    pcall(function() f.timeText:SetDrawLayer("OVERLAY", 7) end)
  end
  f.timeText:SetShadowOffset(1, -1)
  f.timeText:SetShadowColor(0, 0, 0, 0.9)

  f:SetScript("OnUpdate", function(self)
    UpdateCastBarFrame(self)
  end)

  for _, ev in ipairs(unitSpellEvents) do
    pcall(function()
      f:RegisterUnitEvent(ev, unit)
    end)
  end
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  if unit == "target" then
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
  end

  f:SetScript("OnEvent", function(self)
    UpdateCastBarFrame(self)
  end)

  CB.EnsureDB()
  ApplyCastTextColor(f)

  if ns.Movers and ns.Movers.MakeMovable then
    ns.Movers.MakeMovable(moverKey, f, defaultPoint)
  else
    f:ClearAllPoints()
    f:SetPoint(unpack(defaultPoint))
  end

  f:SetParent(UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetFrameLevel(0)

  return f
end

function CB.Create()
  if CB.state.frame then return end
  if not UF or not UF.CreatePowerBar then return end

  CB.state.frame = CreateCastBarUnitFrame("player", "castbar", CB.GetDefaultCastBarPoint("player"))
  CB.state.frameTarget = CreateCastBarUnitFrame("target", "castbar_target", CB.GetDefaultCastBarPoint("target"))

  CB.EnsureDB()
  UpdateCastBarFrame(CB.state.frame)
  UpdateCastBarFrame(CB.state.frameTarget)
  ScheduleApplyHideBlizzardCastBar()
end
