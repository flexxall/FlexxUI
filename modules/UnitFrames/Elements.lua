local _, ns = ...
local UF = ns.UnitFrames

function UF.SetHealCombatLogEnabled(_enabled)
end

function UF.ResetIncomingHealLogCache()
end

function UF.TickPlayerIncomingHealLog()
end

function UF.EnsureHealLogTicker()
end

function UF.PlainNumber(n, fallback)
  if n == nil then return fallback end
  if type(n) == "number" then
    local ok, v = pcall(function() return n + 0 end)
    if ok and type(v) == "number" then return v end
  end
  local okConv, conv = pcall(function() return tonumber(n) end)
  if okConv and type(conv) == "number" then
    local okNum, v = pcall(function() return conv + 0 end)
    if okNum and type(v) == "number" then return v end
  end
  local okStr, s = pcall(function() return tostring(n) end)
  if okStr and s ~= nil then
    local okTonumber, v = pcall(function() return tonumber(s) end)
    if okTonumber and type(v) == "number" then return v end
  end
  return fallback
end

--- Heal/absorb APIs may return secret numbers: never compare them outside pcall; prove layout math works before returning.
function UF.CoerceAmount(x)
  if x == nil then return 0 end
  local ok, res = pcall(function()
    local v = x + 0
    if v < 0 then v = 0 end
    local _ = (v / 1) + (v * 1)
    return v
  end)
  if ok and type(res) == "number" and res == res then
    return res
  end
  local n = UF.PlainNumber(x, 0)
  local ok2 = pcall(function()
    local _ = n / 1
  end)
  if ok2 and type(n) == "number" and n == n then
    if n < 0 then n = 0 end
    return n
  end
  return 0
end


function UF.CoerceNumber(val)
  local okNum, num = pcall(function() return val + 0 end)
  if okNum and type(num) == "number" then return num end
  if type(val) == "string" then
    local n = tonumber(val)
    if n then return n end
  end
  return nil
end

--- UnitHealth / UnitHealthMax may return secret numbers: never compare them to literals outside pcall (runtime error).
--- UnitHealthMax can be 0 briefly after targeting; StatusBar needs max > 0 — clamp max only inside pcall.
function UF.GetUnitHealthValues(unit)
  local cur, maxH = 0, 1
  pcall(function()
    cur = UnitHealth(unit)
    maxH = UnitHealthMax(unit)
  end)
  pcall(function()
    if maxH == nil or maxH <= 0 then maxH = 1 end
  end)
  return cur, maxH
end

local function ParseDigitsString(s)
  if not s or s == "" then return nil end
  local digits = s:gsub("[^%d]", "")
  if digits == "" then return nil end
  return tonumber(digits)
end

local function GetBlizzardHealthTextData(unit)
  local candidates = {}
  if unit == "player" then
    candidates = { _G.PlayerFrameHealthBarText, _G.PlayerFrameHealthBarTextLeft, _G.PlayerFrameHealthBarTextRight, _G.PlayerFrameHealthBar and _G.PlayerFrameHealthBar.TextString, _G.PlayerFrameHealthBar and _G.PlayerFrameHealthBar.LeftText, _G.PlayerFrameHealthBar and _G.PlayerFrameHealthBar.RightText }
  elseif unit == "target" then
    candidates = { _G.TargetFrameHealthBarText, _G.TargetFrameHealthBarTextLeft, _G.TargetFrameHealthBarTextRight, _G.TargetFrameHealthBar and _G.TargetFrameHealthBar.TextString, _G.TargetFrameHealthBar and _G.TargetFrameHealthBar.LeftText, _G.TargetFrameHealthBar and _G.TargetFrameHealthBar.RightText }
  end
  for _, fs in ipairs(candidates) do
    if fs and fs.GetText then
      local text = fs:GetText()
      if text and text ~= "" then
        local pct = text:match("(%d+)%%")
        if pct then return tonumber(pct), nil, nil end
        local a, b = text:match("([%d%.,]+)%s*/%s*([%d%.,]+)")
        if a and b then return nil, ParseDigitsString(a), ParseDigitsString(b) end
      end
    end
  end
  return nil, nil, nil
end

--- Parse "NN%" from default unit frame power/mana font strings (secret-safe pcall). Used when UnitPower math fails.
local function GetBlizzardPowerTextPercentString(unit)
  local candidates = {}
  if unit == "player" then
    candidates = {
      _G.PlayerFrameManaBarText,
      _G.PlayerFrameManaBarTextLeft,
      _G.PlayerFrameManaBarTextRight,
      _G.PlayerFrameManaBar and _G.PlayerFrameManaBar.TextString,
      _G.PlayerFrameManaBar and _G.PlayerFrameManaBar.LeftText,
      _G.PlayerFrameManaBar and _G.PlayerFrameManaBar.RightText,
      _G.PlayerFrameAlternateManaBar and _G.PlayerFrameAlternateManaBar.TextString,
      _G.PlayerFrameAlternateManaBar and _G.PlayerFrameAlternateManaBar.LeftText,
      _G.PlayerFrameAlternateManaBar and _G.PlayerFrameAlternateManaBar.RightText,
      _G.PlayerFramePowerBar and _G.PlayerFramePowerBar.TextString,
      _G.PlayerFramePowerBar and _G.PlayerFramePowerBar.LeftText,
      _G.PlayerFramePowerBar and _G.PlayerFramePowerBar.RightText,
    }
  elseif unit == "target" then
    candidates = {
      _G.TargetFrameManaBarText,
      _G.TargetFrameManaBarTextLeft,
      _G.TargetFrameManaBarTextRight,
      _G.TargetFrameManaBar and _G.TargetFrameManaBar.TextString,
      _G.TargetFrameManaBar and _G.TargetFrameManaBar.LeftText,
      _G.TargetFrameManaBar and _G.TargetFrameManaBar.RightText,
      _G.TargetFramePowerBar and _G.TargetFramePowerBar.TextString,
      _G.TargetFramePowerBar and _G.TargetFramePowerBar.LeftText,
      _G.TargetFramePowerBar and _G.TargetFramePowerBar.RightText,
    }
  end
  for _, fs in ipairs(candidates) do
    if fs and fs.GetText then
      local okText, text = pcall(function() return fs:GetText() end)
      if okText and text then
        local okPct, out = pcall(function()
          local s = tostring(text)
          local pct = s:match("(%d+)%%")
          if pct then return pct .. "%" end
          return nil
        end)
        if okPct and out then return out end
      end
    end
  end
  return nil
end

local function GetEffectiveNameTextColorMode(f)
  local db = _G.FlexxUIDB
  if not db then return "class" end
  local global = db.nameTextColorMode or "class"
  local fk = f and f.unitFrameKey
  if fk == "player" and db.nameTextColorOverridePlayer ~= nil then
    return db.nameTextColorOverridePlayer
  end
  if fk == "target" and db.nameTextColorOverrideTarget ~= nil then
    return db.nameTextColorOverrideTarget
  end
  if fk == "pet" and db.nameTextColorOverridePet ~= nil then
    return db.nameTextColorOverridePet
  end
  return global
end

--- Class-colored names sit on busy health fills; a stronger shadow keeps them readable.
local function ApplyTextShadow(fs, strength)
  if not fs then return end
  if strength == "class" then
    fs:SetShadowOffset(2, -2)
    fs:SetShadowColor(0, 0, 0, 0.96)
  else
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.85)
  end
end

--- Same RGB rules as the unit name string (Fonts → Unit + per-frame overrides). Do not use FontString:GetTextColor for health/power/cast — it can diverge from class color.
function UF.GetEffectiveNameTextColorRGB(f)
  if not f or not f.unit then return 0.95, 0.95, 0.95 end
  local mode = GetEffectiveNameTextColorMode(f)
  if mode == "white" then
    return 0.95, 0.95, 0.95
  elseif mode == "yellow" then
    return 1, 0.88, 0.35
  elseif mode == "dark" then
    return 0.08, 0.08, 0.1
  end
  if UnitIsPlayer(f.unit) then
    local _, class = UnitClass(f.unit)
    local c = class and RAID_CLASS_COLORS[class]
    if c then
      return c.r, c.g, c.b
    end
  end
  return 0.95, 0.95, 0.95
end

--- Shared unit-text styling helper for DRY color/shadow behavior across name/health/power text.
function UF.ApplyUnitTextStyle(fs, f, mode)
  if not fs then return end
  mode = mode or "class"
  local r, g, b
  if mode == "white" then
    r, g, b = 0.95, 0.95, 0.95
  elseif mode == "yellow" then
    r, g, b = 1, 0.88, 0.35
  elseif mode == "dark" then
    r, g, b = 0.08, 0.08, 0.1
  else
    r, g, b = UF.GetEffectiveNameTextColorRGB(f)
    mode = "class"
  end
  fs:SetTextColor(r, g, b)

  local classShadow = false
  if mode == "class" and f and f.unit and UnitIsPlayer(f.unit) then
    local _, class = UnitClass(f.unit)
    classShadow = class and RAID_CLASS_COLORS[class] ~= nil
  end
  ApplyTextShadow(fs, classShadow and "class" or "default")
end

local function ApplyHealthTextColor(f)
  if not f or not f.healthText then return end
  local mode = (_G.FlexxUIDB and _G.FlexxUIDB.healthTextColorMode) or "class"
  UF.ApplyUnitTextStyle(f.healthText, f, mode)
end

local function ApplyNameTextColor(f)
  if not f or not f.name then return end
  local mode = GetEffectiveNameTextColorMode(f)
  UF.ApplyUnitTextStyle(f.name, f, mode)
end

function UF.ApplyUnitFrameNameAndHealthLayout(f)
  if not f or not f.health or not f.healthText then return end
  UF.EnsureDB()
  local db = _G.FlexxUIDB or {}
  if db.showUnitFrameName == false then
    if f.name then f.name:Hide() end
  else
    if f.name then f.name:Show() end
  end

  local align = db.healthTextAlign or "right"
  if align ~= "center" and align ~= "right" then align = "right" end

  f.healthText:ClearAllPoints()
  if align == "center" then
    f.healthText:SetPoint("CENTER", f.health, "CENTER", 0, -1)
    f.healthText:SetJustifyH("CENTER")
  else
    f.healthText:SetPoint("RIGHT", f.health, "RIGHT", -6, -1)
    f.healthText:SetJustifyH("RIGHT")
  end
end

function UF.ApplyPowerTextLayout(f)
  if not f or not f.power or not f.powerText then return end
  UF.EnsureDB()
  local db = _G.FlexxUIDB or {}
  local align = db.powerTextAlign or "center"
  if align ~= "left" and align ~= "center" and align ~= "right" then align = "center" end
  f.powerText:ClearAllPoints()
  local inset = 4
  if align == "center" then
    f.powerText:SetPoint("CENTER", f.power, "CENTER", 0, 0)
    f.powerText:SetJustifyH("CENTER")
  elseif align == "left" then
    f.powerText:SetPoint("LEFT", f.power, "LEFT", inset, 0)
    f.powerText:SetJustifyH("LEFT")
  else
    f.powerText:SetPoint("RIGHT", f.power, "RIGHT", -inset, 0)
    f.powerText:SetJustifyH("RIGHT")
  end
end

local function FormatPowerPercent(c, m)
  if m == nil or m <= 0 then return "0%" end
  if c == nil then c = 0 end
  if c >= m then return "100%" end
  local p = math.floor((c / m) * 100 + 0.5)
  if p < 0 then p = 0 end
  if p > 100 then p = 100 end
  return tostring(p) .. "%"
end

local function ApplyPowerTextColorPreset(fs, preset, f)
  if preset == "class_color" and f then
    UF.ApplyUnitTextStyle(fs, f, "class")
  elseif preset == "power_bar" and f and f.power then
    local r, g, b = f.power:GetStatusBarColor()
    fs:SetTextColor(r, g, b)
  elseif preset == "amber" then
    fs:SetTextColor(0.95, 0.82, 0.45)
  elseif preset == "ice" then
    fs:SetTextColor(0.45, 0.88, 1)
  else
    fs:SetTextColor(0.95, 0.95, 0.95)
  end
end

--- Match-bar and class-colored power text sit on the bar fill like names on health; stronger shadow aids contrast.
local function ApplyPowerTextShadow(f, preset)
  if not f or not f.powerText then return end
  if preset == "power_bar" or preset == "class_color" then
    f.powerText:SetShadowOffset(2, -2)
    f.powerText:SetShadowColor(0, 0, 0, 0.96)
  else
    f.powerText:SetShadowOffset(1, -1)
    f.powerText:SetShadowColor(0, 0, 0, 0.9)
  end
end

function UF.ApplyPowerTextColor(f)
  if not f or not f.powerText then return end
  UF.EnsureDB()
  local db = _G.FlexxUIDB or {}
  local preset = db.powerTextColorMode or "white"
  if db.powerTextColorSplit then
    local manaType = 0
    if Enum and Enum.PowerType and Enum.PowerType.Mana ~= nil then
      manaType = Enum.PowerType.Mana
    end
    local okPt, pt = pcall(function()
      if f.unit and UnitExists(f.unit) then
        return select(1, UnitPowerType(f.unit))
      end
      return nil
    end)
    if okPt and pt ~= nil and pt == manaType then
      preset = db.powerTextColorMana or "white"
    else
      preset = db.powerTextColorResource or "white"
    end
  end
  ApplyPowerTextColorPreset(f.powerText, preset, f)
  ApplyPowerTextShadow(f, preset)
end

function UF.UpdatePowerText(f, cur, maxP, barVisible)
  if not f or not f.powerText then return end
  if not barVisible or (_G.FlexxUIDB and _G.FlexxUIDB.powerTextShow == false) then
    f.powerText:SetText("")
    f.powerText:Hide()
    return
  end

  UF.EnsureDB()
  local db = _G.FlexxUIDB or {}
  -- Only "value" selects current/max; anything else (nil, typo) is percent.
  local textMode = (db.powerTextMode == "value") and "value" or "percent"

  local unit = f.unit
  local txt

  if textMode == "value" then
    -- Never compare txt to literals after it may hold a secret string from UnitPower (taint error).
    local valueNeedFallback = true
    txt = "-- / --"
    if unit and UnitExists(unit) then
      local pt = select(1, UnitPowerType(unit))
      if pt == nil then pt = 0 end
      local ok, s = pcall(function()
        return string.format("%s / %s", UnitPower(unit, pt), UnitPowerMax(unit, pt))
      end)
      if ok and s then
        txt = s
        valueNeedFallback = false
      end
    end
    if valueNeedFallback and cur ~= nil and maxP ~= nil then
      local ok2, s2 = pcall(function()
        return string.format("%s / %s", cur, maxP)
      end)
      if ok2 and s2 then
        txt = s2
        valueNeedFallback = false
      end
    end
    if valueNeedFallback then
      local c = UF.PlainNumber(cur, nil)
      local m = UF.PlainNumber(maxP, nil)
      if c ~= nil and m ~= nil then
        txt = string.format("%d / %d", math.floor(c + 0.5), math.floor(m + 0.5))
        valueNeedFallback = false
      end
    end
    if valueNeedFallback and f.power and f.power.GetValue and f.power.GetMinMaxValues then
      local ok3, s3 = pcall(function()
        return string.format("%s / %s", f.power:GetValue(), select(2, f.power:GetMinMaxValues()))
      end)
      if ok3 and s3 then
        txt = s3
        valueNeedFallback = false
      end
    end
  else
    -- Percent: match UpdateHealthText — Retail UnitPowerPercent (ShestakUI/oUF) is the reliable API; manual math often fails on secrets.
    local pctNeedFallback = true
    txt = "--%"
    local scaleTo100 = CurveConstants and CurveConstants.ScaleTo100 or nil

    if unit and UnitExists(unit) and UnitPowerPercent then
      local pt = select(1, UnitPowerType(unit))
      if pt == nil then pt = 0 end
      local okPct, pct = pcall(function()
        return UnitPowerPercent(unit, pt, true, scaleTo100)
      end)
      if not okPct or pct == nil then
        okPct, pct = pcall(function()
          return UnitPowerPercent(unit, nil, true, scaleTo100)
        end)
      end
      if okPct and pct ~= nil then
        local okFmt, s = pcall(function()
          return string.format("%d%%", pct)
        end)
        if okFmt and s then
          txt = s
          pctNeedFallback = false
        else
          local n = UF.CoerceNumber(pct)
          if n ~= nil then
            local ok2, s2 = pcall(function()
              return string.format("%d%%", math.floor(n + 0.5))
            end)
            if ok2 and s2 then
              txt = s2
              pctNeedFallback = false
            end
          end
        end
      end
    end

    if pctNeedFallback then
      local c = UF.PlainNumber(cur, nil)
      local m = UF.PlainNumber(maxP, nil)
      if c ~= nil and m ~= nil then
        txt = FormatPowerPercent(c, m)
        pctNeedFallback = false
      end
    end
    if pctNeedFallback and cur ~= nil and maxP ~= nil then
      local ok, res = pcall(function()
        local c = cur
        local m = maxP
        if m <= 0 then return "0%" end
        if c >= m then return "100%" end
        local p = math.floor((c / m) * 100 + 0.5)
        if p < 0 then p = 0 end
        if p > 100 then p = 100 end
        return tostring(p) .. "%"
      end)
      if ok and res then
        txt = res
        pctNeedFallback = false
      end
    end
    if pctNeedFallback and unit and UnitExists(unit) then
      local blizz = GetBlizzardPowerTextPercentString(unit)
      if blizz then
        txt = blizz
        pctNeedFallback = false
      end
    end
    if pctNeedFallback and unit and UnitExists(unit) then
      local ok, s = pcall(function()
        local c = UnitPower(unit)
        local m = UnitPowerMax(unit)
        if m <= 0 then return "0%" end
        return string.format("%d%%", math.floor((c / m) * 100 + 0.5))
      end)
      if ok and s then
        txt = s
        pctNeedFallback = false
      end
    end
    if pctNeedFallback and unit and UnitExists(unit) then
      local pt = select(1, UnitPowerType(unit))
      if pt == nil then pt = 0 end
      local ok, res = pcall(function()
        local c = UnitPower(unit, pt)
        local m = UnitPowerMax(unit, pt)
        if m <= 0 then return "0%" end
        if c >= m then return "100%" end
        local p = math.floor((c / m) * 100 + 0.5)
        if p < 0 then p = 0 end
        if p > 100 then p = 100 end
        return tostring(p) .. "%"
      end)
      if ok and res then
        txt = res
        pctNeedFallback = false
      end
    end
    if pctNeedFallback and unit and UnitExists(unit) then
      local pt = select(1, UnitPowerType(unit))
      if pt == nil then pt = 0 end
      local ok, s = pcall(function()
        local c = UnitPower(unit, pt)
        local m = UnitPowerMax(unit, pt)
        if m <= 0 then return "0%" end
        return string.format("%d%%", math.floor((c / m) * 100 + 0.5))
      end)
      if ok and s then
        txt = s
        pctNeedFallback = false
      end
    end
    if pctNeedFallback and f.power and f.power.GetValue and f.power.GetMinMaxValues then
      local ok, res = pcall(function()
        local c = f.power:GetValue()
        local _, m = f.power:GetMinMaxValues()
        if m <= 0 then return "0%" end
        if c >= m then return "100%" end
        local p = math.floor((c / m) * 100 + 0.5)
        if p < 0 then p = 0 end
        if p > 100 then p = 100 end
        return tostring(p) .. "%"
      end)
      if ok and res then
        txt = res
        pctNeedFallback = false
      end
    end
    if pctNeedFallback and f.power and f.power.GetValue and f.power.GetMinMaxValues then
      local ok, s = pcall(function()
        local c = f.power:GetValue()
        local _, m = f.power:GetMinMaxValues()
        if m <= 0 then return "0%" end
        return string.format("%d%%", math.floor((c / m) * 100 + 0.5))
      end)
      if ok and s then
        txt = s
      end
    end
  end

  f.powerText:SetText(txt)
  UF.ApplyPowerTextColor(f)
  f.powerText:Show()
end

function UF.UpdateHealthText(f, hp, maxHp)
  if not f or not f.healthText then return end
  local mode = (_G.FlexxUIDB and _G.FlexxUIDB.healthTextMode) or "percent"
  if mode == "none" then
    f.healthText:SetText("")
    f.healthText:Hide()
    return
  end

  f.healthText:Show()
  if mode == "value" then
    local rawValue
    if f.unit then
      rawValue = UnitHealth(f.unit, true)
      if rawValue == nil then rawValue = UnitHealth(f.unit, false) end
      if rawValue == nil then rawValue = UnitHealth(f.unit) end
    end
    if rawValue == nil then rawValue = hp end
    if rawValue == nil and f.health and f.health.GetValue then rawValue = f.health:GetValue() end

    if rawValue ~= nil then
      if BreakUpLargeNumbers then
        local okBreak, broken = pcall(function() return BreakUpLargeNumbers(rawValue) end)
        if okBreak and broken then
          local okSet = pcall(function() f.healthText:SetText(broken) end)
          if not okSet then
            f.healthText:SetFormattedText("%d", rawValue)
          end
        else
          f.healthText:SetFormattedText("%d", rawValue)
        end
      else
        f.healthText:SetFormattedText("%d", rawValue)
      end
    else
      f.healthText:SetText("0")
    end
  else
    local pct
    local okPct = false
    if f.unit and UnitHealthPercent then
      okPct, pct = pcall(function()
        return UnitHealthPercent(f.unit, true, CurveConstants and CurveConstants.ScaleTo100 or nil)
      end)
    end
    if okPct and pct ~= nil then
      f.healthText:SetFormattedText("%d%%", pct)
    else
      local blizzPct = f.unit and select(1, GetBlizzardHealthTextData(f.unit)) or nil
      if blizzPct ~= nil then
        f.healthText:SetFormattedText("%d%%", blizzPct)
      else
        f.healthText:SetText("0%")
      end
    end
  end

  ApplyHealthTextColor(f)
end

--- Pixel width of a prediction strip: amount/max * bar width (oUF-style, bar-local coords).
local function HealthStripWidth(amount, maxH, barW)
  local w = 0
  pcall(function()
    local v = UF.CoerceAmount(amount)
    local mx = UF.CoerceAmount(maxH)
    if mx <= 0 then mx = 1 end
    local bw = UF.PlainNumber(barW, 0)
    if v <= 0 or bw <= 0 then return end
    local s = (v / mx) * bw
    if s < 1 then s = 1 end
    w = s
  end)
  return w
end

--- Pixels from left of the health bar where the fill ends (current HP fraction * width).
local function HealthFillRightOffset(bar, unit)
  local off = 0
  pcall(function()
    local bw = UF.PlainNumber(bar:GetWidth(), 0)
    if bw <= 0 then return end
    local cur, mx = 0, 1
    if unit and UnitExists(unit) then
      cur, mx = UF.GetUnitHealthValues(unit)
    else
      cur = UF.PlainNumber(bar:GetValue(), 0)
      local _, m = bar:GetMinMaxValues()
      mx = UF.PlainNumber(m, 1)
    end
    cur = UF.CoerceAmount(cur)
    mx = UF.CoerceAmount(mx)
    if mx <= 0 then mx = 1 end
    local frac = cur / mx
    if frac < 0 then frac = 0 end
    if frac > 1 then frac = 1 end
    off = frac * bw
  end)
  return off
end

--- Incoming heal / absorbs: drive StatusBars with raw calculator/API values. Retail 12.x often returns *secret*
--- numbers; StatusBar:SetValue / SetMinMaxValues accept those, but Lua width math + CoerceAmount collapses to 0.
function UF.UpdateHealthBarOverlays(f)
  local bar = f.health
  local layer = f.healthPrediction
  local incomingBar = f.incomingHealBar
  local absorbBar = f.absorbHealBar
  local healAbsorbTex = f.healAbsorbTex
  if not bar or not layer or not incomingBar or not absorbBar then return end

  local unit = f.unit
  if not unit or not UnitExists(unit) then return end

  if _G.FlexxUIDB and _G.FlexxUIDB.showHealthBarOverlays == false then
    incomingBar:Hide()
    absorbBar:Hide()
    if healAbsorbTex then healAbsorbTex:Hide() end
    return
  end

  local barW, barH = 1, 1
  pcall(function()
    barW = UF.PlainNumber(bar:GetWidth(), 1)
    barH = UF.PlainNumber(bar:GetHeight(), 1)
    if barW <= 0 then barW = 1 end
    if barH <= 0 then barH = 1 end
  end)

  local tex = bar:GetStatusBarTexture()
  local x0 = HealthFillRightOffset(bar, unit)

  incomingBar:ClearAllPoints()
  incomingBar:SetOrientation("HORIZONTAL")
  -- 2 px shorter than health fill; anchored to current-health right edge (same as full bar height minus 1 px top/bottom inset).
  if tex then
    incomingBar:SetPoint("TOPLEFT", tex, "TOPRIGHT", 0, 1)
    incomingBar:SetPoint("BOTTOMLEFT", tex, "BOTTOMRIGHT", 0, -1)
    incomingBar:SetWidth(barW)
  else
    incomingBar:SetPoint("TOPLEFT", layer, "TOPLEFT", x0, -1)
    incomingBar:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", x0, 1)
    incomingBar:SetWidth(barW)
  end

  local incomingOk, absorbOk = false, false
  local calc = f._healPredCalc
  if CreateUnitHealPredictionCalculator and UnitGetDetailedHealPrediction then
    if not calc then
      calc = CreateUnitHealPredictionCalculator()
      f._healPredCalc = calc
    end
    pcall(function()
      if not pcall(UnitGetDetailedHealPrediction, unit, "player", calc) then
        pcall(UnitGetDetailedHealPrediction, unit, nil, calc)
      end
    end)
    incomingOk = pcall(function()
      incomingBar:SetMinMaxValues(0, calc:GetMaximumHealth())
      incomingBar:SetValue(select(1, calc:GetIncomingHeals()))
    end)
  end
  if not incomingOk and UnitGetIncomingHeals then
    incomingOk = pcall(function()
      local _, mx = bar:GetMinMaxValues()
      incomingBar:SetMinMaxValues(0, mx)
      incomingBar:SetValue(UnitGetIncomingHeals(unit))
    end)
  end
  if incomingOk then
    incomingBar:Show()
  else
    incomingBar:Hide()
  end

  local anchorForAbsorb = tex
  if incomingOk then
    local inFill = incomingBar:GetStatusBarTexture()
    if inFill then anchorForAbsorb = inFill end
  end

  absorbBar:ClearAllPoints()
  absorbBar:SetOrientation("HORIZONTAL")
  -- 2 px shorter than incoming strip (4 px shorter than health) when anchored past incoming; else 4 px shorter than health fill.
  if anchorForAbsorb then
    absorbBar:SetPoint("TOPLEFT", anchorForAbsorb, "TOPRIGHT", 0, 1)
    absorbBar:SetPoint("BOTTOMLEFT", anchorForAbsorb, "BOTTOMRIGHT", 0, -1)
    absorbBar:SetWidth(barW)
  else
    absorbBar:SetPoint("TOPLEFT", layer, "TOPLEFT", x0, -2)
    absorbBar:SetPoint("BOTTOMLEFT", layer, "BOTTOMLEFT", x0, 2)
    absorbBar:SetWidth(barW)
  end

  if calc and UnitGetDetailedHealPrediction then
    absorbOk = pcall(function()
      absorbBar:SetMinMaxValues(0, calc:GetMaximumHealth())
      absorbBar:SetValue(select(1, calc:GetDamageAbsorbs()))
    end)
  end
  if not absorbOk and UnitGetTotalAbsorbs then
    absorbOk = pcall(function()
      local _, mx = bar:GetMinMaxValues()
      absorbBar:SetMinMaxValues(0, mx)
      absorbBar:SetValue(UnitGetTotalAbsorbs(unit))
    end)
  end
  if absorbOk then
    absorbBar:Show()
  else
    absorbBar:Hide()
  end

  local maxH = 1
  local healAbsorbN = 0
  pcall(function()
    local _, m = bar:GetMinMaxValues()
    maxH = UF.CoerceAmount(m)
    if maxH <= 0 then maxH = 1 end
  end)
  if CreateUnitHealPredictionCalculator and f._healPredCalc and f._healPredCalc.GetHealAbsorbs then
    pcall(function()
      pcall(UnitGetDetailedHealPrediction, unit, "player", f._healPredCalc)
      healAbsorbN = UF.CoerceAmount(select(1, f._healPredCalc:GetHealAbsorbs()))
    end)
  end
  local wHab = HealthStripWidth(healAbsorbN, maxH, barW)
  if healAbsorbTex and wHab > 0 then
    healAbsorbTex:ClearAllPoints()
    healAbsorbTex:SetPoint("TOPRIGHT", layer, "TOPRIGHT", 0, -2)
    healAbsorbTex:SetPoint("BOTTOMRIGHT", layer, "BOTTOMRIGHT", 0, 2)
    healAbsorbTex:SetWidth(wHab)
    healAbsorbTex:Show()
  elseif healAbsorbTex then
    healAbsorbTex:Hide()
  end
end

function UF.UpdatePowerBar(f)
  local bar = f.power
  if not bar or not f.unit then return end
  if not UnitExists(f.unit) then return end
  local unit = f.unit
  local pt = nil
  local okPt, vPt = pcall(UnitPowerType, unit)
  if okPt and vPt ~= nil then
    pt = vPt
  else
    pt = 0
  end
  local maxP = UnitPowerMax(unit, pt)
  local cur = UnitPower(unit, pt)

  local okEmpty, empty = pcall(function() return maxP <= 0 end)
  if okEmpty and empty then
    bar:Hide()
    UF.UpdatePowerText(f, nil, nil, false)
    return
  end

  -- Secret power values: comparisons / arithmetic must run inside pcall; never compare cur/maxP raw.
  local okNorm, cNum, mNum = pcall(function()
    local c = cur + 0
    local m = maxP + 0
    if m <= 0 then return nil, nil end
    if c > m then c = m end
    if c < 0 then c = 0 end
    return c, m
  end)
  if okNorm and cNum ~= nil and mNum ~= nil then
    bar:Show()
    bar:SetMinMaxValues(0, mNum)
    bar:SetValue(cNum)
    UF.ApplyPowerBarColor(bar, unit, pt)
    UF.UpdatePowerText(f, cNum, mNum, true)
    return
  end

  local okRaw = pcall(function()
    bar:SetMinMaxValues(0, maxP)
    bar:SetValue(cur)
  end)
  if okRaw then
    bar:Show()
    UF.ApplyPowerBarColor(bar, unit, pt)
    -- Pass raw cur/maxP so text can mirror the bar when +0 coercion failed (secret values).
    UF.UpdatePowerText(f, cur, maxP, true)
    return
  end
  bar:Hide()
  UF.UpdatePowerText(f, nil, nil, false)
end

function UF.UpdatePlayerResting(f)
  if not f or f.unit ~= "player" or not f.restingIcons then return end
  --- IsResting() stays true in rested areas while fighting (e.g. dummies); hide zzz whenever in combat.
  local showRest = IsResting() and not (UnitAffectingCombat and UnitAffectingCombat("player"))
  if showRest then
    if not f.restingActive then
      f.restingActive = true
      for _, fs in ipairs(f.restingIcons) do fs:Show() end
      if f.restingPulseDriver then
        f.restingPulseTime = 0
        f.restingPulseDriver:SetScript("OnUpdate", f.restingPulseOnUpdate)
        f.restingPulseDriver:Show()
      end
    end
  elseif f.restingActive then
    f.restingActive = false
    if f.restingPulseDriver then
      f.restingPulseDriver:SetScript("OnUpdate", nil)
      f.restingPulseDriver:Hide()
    end
    for _, fs in ipairs(f.restingIcons) do
      fs:SetAlpha(1)
      fs:Hide()
    end
  end
end

local function EnsureUnitFrameVisibilityRetry()
  if UF.state._unitFrameVisRetry then return UF.state._unitFrameVisRetry end
  local rf = CreateFrame("Frame")
  rf:SetScript("OnEvent", function(self, event)
    if event ~= "PLAYER_REGEN_ENABLED" then return end
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for _, fr in pairs(UF.state.frames or {}) do
      if fr and fr._flexxPendingShown ~= nil then
        local want = fr._flexxPendingShown == true
        fr._flexxPendingShown = nil
        if fr.unit == "target" then
          --- Secure target button: avoid Hide/Show here; alpha + mouse only (same as SetUnitFrameShownSafe OOC).
          if not fr:IsShown() then fr:Show() end
          pcall(function() fr:SetAlpha(want and 1 or 0) end)
          pcall(function() fr:EnableMouse(want and true or false) end)
        elseif want then
          if not fr:IsShown() then fr:Show() end
          pcall(function() fr:SetAlpha(1) end)
          pcall(function() fr:EnableMouse(true) end)
        else
          if fr:IsShown() then fr:Hide() end
          pcall(function() fr:SetAlpha(1) end)
          pcall(function() fr:EnableMouse(false) end)
        end
      end
    end
  end)
  UF.state._unitFrameVisRetry = rf
  return rf
end

local function SetUnitFrameShownSafe(f, shown)
  if not f then return end
  if InCombatLockdown and InCombatLockdown() then
    f._flexxPendingShown = shown and true or false
    --- SecureUnitButtonTemplate (target): Show/Hide/EnableMouse are ADDON_ACTION_BLOCKED in combat.
    --- Only adjust alpha in combat; full mouse/show state is replayed on PLAYER_REGEN_ENABLED.
    if f.unit == "target" then
      pcall(function() f:SetAlpha(shown and 1 or 0) end)
    end
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        local rf = EnsureUnitFrameVisibilityRetry()
        if rf and rf.RegisterEvent then
          rf:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
      end)
    else
      EnsureUnitFrameVisibilityRetry():RegisterEvent("PLAYER_REGEN_ENABLED")
    end
    return
  end
  f._flexxPendingShown = nil
  if f.unit == "target" then
    --- Keep target frame Shown at all times; use alpha 0 when no unit (never Hide — avoids Show() in combat).
    if not f:IsShown() then f:Show() end
    pcall(function() f:EnableMouse(shown and true or false) end)
    pcall(function() f:SetAlpha(shown and 1 or 0) end)
    return
  end
  pcall(function() f:SetAlpha(1) end)
  pcall(function() f:EnableMouse(shown and true or false) end)
  if shown then
    if not f:IsShown() then f:Show() end
  else
    if f:IsShown() then f:Hide() end
  end
end

function UF.UpdateUnitFrame(f)
  if not f or not f.unit then return end
  if not UnitExists(f.unit) then
    if f.healthText then f.healthText:SetText("") end
    if f.name then f.name:SetText("") end
    if f.powerText then f.powerText:SetText("") end
    SetUnitFrameShownSafe(f, false)
    return
  end

  SetUnitFrameShownSafe(f, true)
  if UF.UpdateTopResourceBar then UF.UpdateTopResourceBar(f) end
  UF.ApplyUnitFrameNameAndHealthLayout(f)
  UF.ApplyPowerTextLayout(f)
  if f.name then f.name:SetText(UnitName(f.unit) or f.unit) end
  ApplyNameTextColor(f)

  local hp, maxHp = UF.GetUnitHealthValues(f.unit)
  f.health:SetMinMaxValues(0, maxHp)
  f.health:SetValue(hp)

  if UnitIsPlayer(f.unit) then
    if f.unit == "player" then
      UF.ApplyPlayerHealthColor(f.health, f.unit)
    else
      local _, class = UnitClass(f.unit)
      local c = class and RAID_CLASS_COLORS[class]
      if c then f.health:SetStatusBarColor(c.r, c.g, c.b) else f.health:SetStatusBarColor(0.2, 0.8, 0.2) end
    end
  else
    f.health:SetStatusBarColor(0.8, 0.2, 0.2)
  end

  UF.UpdateHealthText(f, hp, maxHp)
  UF.UpdateHealthBarOverlays(f)
  UF.UpdatePowerBar(f)
  if f.unit == "player" then
    UF.UpdatePlayerResting(f)
    UF.UpdatePlayerLowHealthChrome(f)
  end
  UF.UpdateThreatGlow(f)
  if UF.UpdateUnitAuras then UF.UpdateUnitAuras(f) end
end

