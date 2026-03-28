local _, ns = ...

--- Player + target cast bars (same size as unit-frame power bar: UnitFrames/Frames.lua powerH + insets).
local CB = {}
ns.CastBar = CB

CB.state = CB.state or {}

-- 245px frame, 10px horizontal inset each side → 225px wide; power bar height = 10.
local CAST_BAR_W = 225
local CAST_BAR_H = 10

local UF = ns.UnitFrames

function CB.EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if _G.FlexxUIDB.castBarEnabled == nil then _G.FlexxUIDB.castBarEnabled = true end
  if _G.FlexxUIDB.castBarShowIdle == nil then _G.FlexxUIDB.castBarShowIdle = false end
  if _G.FlexxUIDB.castBarLayoutPreview == nil then _G.FlexxUIDB.castBarLayoutPreview = false end
  if _G.FlexxUIDB.castBarTargetEnabled == nil then _G.FlexxUIDB.castBarTargetEnabled = true end
  if _G.FlexxUIDB.castBarTargetShowIdle == nil then _G.FlexxUIDB.castBarTargetShowIdle = false end
  if _G.FlexxUIDB.hideBlizzardCastBar == nil then _G.FlexxUIDB.hideBlizzardCastBar = false end
  if _G.FlexxUIDB.castBarTextColorMode == nil then _G.FlexxUIDB.castBarTextColorMode = "light" end
  if _G.FlexxUIDB.castBarFillStyle == nil then _G.FlexxUIDB.castBarFillStyle = "default" end
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
  local bar = _G.PlayerCastingBar
  if not bar or not bar.HookScript then return end
  if _G.FlexxUIDB.hideBlizzardCastBar then
    bar:Hide()
    if not bar._flexxUICastHook then
      bar._flexxUICastHook = true
      bar:HookScript("OnShow", function(self)
        if _G.FlexxUIDB and _G.FlexxUIDB.hideBlizzardCastBar then
          self:Hide()
        end
      end)
    end
  else
    bar:Show()
  end
end

--- Cast APIs may return secret values on Retail; never do Lua math on raw returns.
local function GetUnitCast(unit)
  if unit == "target" and (not UnitExists("target")) then
    return nil
  end
  local ok, name, _, _, startMS, endMS = pcall(UnitCastingInfo, unit)
  if ok and name then
    return "cast", name, startMS, endMS
  end
  ok, name, _, _, startMS, endMS = pcall(UnitChannelInfo, unit)
  if ok and name then
    return "channel", name, startMS, endMS
  end
  return nil
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

  local kind, name, startMS, endMS = GetUnitCast(unit)
  if not kind then
    local showIdle
    if unit == "player" then
      showIdle = _G.FlexxUIDB.castBarShowIdle or _G.FlexxUIDB.castBarLayoutPreview
    else
      showIdle = (_G.FlexxUIDB.castBarTargetShowIdle or _G.FlexxUIDB.castBarLayoutPreview) and UnitExists("target")
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
  self.bar:SetValue(p)

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
  ApplyHideBlizzardCastBar()
end

--- Toggle dev layout preview (empty bars visible for dragging). Returns new state.
function CB.ToggleLayoutPreview()
  CB.EnsureDB()
  _G.FlexxUIDB.castBarLayoutPreview = not _G.FlexxUIDB.castBarLayoutPreview
  CB.RefreshFromOptions()
  return _G.FlexxUIDB.castBarLayoutPreview
end

local function CreateCastBarUnitFrame(unit, moverKey, defaultPoint)
  local frameName = unit == "player" and "FlexxUI_CastBar" or "FlexxUI_CastBarTarget"
  local f = CreateFrame("Frame", frameName, UIParent)
  f.watchUnit = unit
  f:SetSize(CAST_BAR_W, CAST_BAR_H)

  f.bar = UF.CreatePowerBar(f, CAST_BAR_W, CAST_BAR_H)
  f.bar._flexxBarRole = "cast"
  f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
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

  local playerUF = UF.state and UF.state.frames and UF.state.frames.player
  local defaultPlayer = playerUF and { "TOPLEFT", playerUF, "BOTTOMLEFT", 0, -10 } or { "CENTER", UIParent, "CENTER", 0, -140 }
  CB.state.frame = CreateCastBarUnitFrame("player", "castbar", defaultPlayer)

  local targetUF = UF.state and UF.state.frames and UF.state.frames.target
  local defaultTarget = targetUF and { "TOPLEFT", targetUF, "BOTTOMLEFT", 0, -10 } or { "CENTER", UIParent, "CENTER", 0, -200 }
  CB.state.frameTarget = CreateCastBarUnitFrame("target", "castbar_target", defaultTarget)

  CB.EnsureDB()
  UpdateCastBarFrame(CB.state.frame)
  UpdateCastBarFrame(CB.state.frameTarget)
  ApplyHideBlizzardCastBar()
end
