local _, ns = ...
local CC = ns.CombatCenter
local C = CC.const
local ICONS_LANE2 = C.ICONS_LANE2
local MAX_PIPS = C.MAX_PIPS
local PIP_H = C.PIP_H
local PIP_SEGMENT_GAP = C.PIP_SEGMENT_GAP
local LANE1_POOL_MAX_THRESHOLD = C.LANE1_POOL_MAX_THRESHOLD
local PIP_EMPTY_R, PIP_EMPTY_G, PIP_EMPTY_B = C.PIP_EMPTY_R, C.PIP_EMPTY_G, C.PIP_EMPTY_B
local PIP_EMPTY_A = C.PIP_EMPTY_A
local PIP_BAR_WIDTH_FRAC = C.PIP_BAR_WIDTH_FRAC
local PIP_WRAP_PAD = C.PIP_WRAP_PAD
local PIP_WRAP_BG_A = C.PIP_WRAP_BG_A
local LANE1_STATUS_H = C.LANE1_STATUS_H
local LANE1_BOTTOM_BG_H = C.LANE1_BOTTOM_BG_H
local PIP_BG_PAD = C.PIP_BG_PAD
local function SecondaryPowerTypeColor(pt)
  local UFw = ns.UnitFrames
  if UFw and UFw.GetDemonHunterSpecResourceRGB then
    local dr, dg, db = UFw.GetDemonHunterSpecResourceRGB("player", pt)
    if dr then return dr, dg, db end
  end
  if Enum and Enum.PowerType then
    local E = Enum.PowerType
    if pt == E.HolyPower then return 0.95, 0.82, 0.32 end
    if pt == E.ComboPoints then return 0.92, 0.20, 0.18 end
    if pt == E.Chi then return 0.38, 0.90, 0.82 end
    if pt == E.SoulShards then return 0.60, 0.32, 0.95 end
    if pt == E.ArcaneCharges then return 0.82, 0.44, 0.95 end
    if pt == E.Essence then return 0.32, 0.78, 0.98 end
    if pt == E.RunicPower then return 0.00, 0.82, 1.00 end
    if pt == E.Runes then
      local UFw = ns.UnitFrames
      if UFw and UFw.GetDeathKnightSpecResourceRGB then
        local r, g, b = UFw.GetDeathKnightSpecResourceRGB("player")
        if r then return r, g, b end
      end
      return 0.78, 0.16, 0.22
    end
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

--- True when Enum/table power types refer to the same resource (e.g. RunicPower vs index 6).
local function PowerTypesMatch(a, b)
  if a == nil or b == nil then return false end
  if a == b then return true end
  local na, nb
  pcall(function() na = a + 0 end)
  pcall(function() nb = b + 0 end)
  if type(na) == "number" and type(nb) == "number" and na == nb then return true end
  return false
end

local function Lane1UsePoolBar(mx, pt)
  local ok = false
  pcall(function()
    ok = type(mx) == "number" and mx > LANE1_POOL_MAX_THRESHOLD
  end)
  if ok then return true end
  local E = Enum and Enum.PowerType
  if E and E.RunicPower ~= nil and pt == E.RunicPower then return true end
  pcall(function()
    if type(pt) == "number" and pt == 6 then ok = true end
  end)
  return ok
end

--- Class/spec-aware lane 1: same selection as unit-frame top pips (SecondaryResource), then primary power bar.
--- For pool resources that are also the primary power bar (DK runic, warrior rage, â€¦), use the same tuple as UF.UpdatePowerBar.
---
--- Death Knight: UnitPowerType reports Runic Power first, but rotation is driven by Runes (Enum.PowerType.Runes, 0â€“6
--- available charges that deplete). Runic Power is the inverse meter (fills when you spend runes). Lane 1 uses Runes
--- so the strip matches Frost/Blood/Unholy â€œhow many runes are upâ€ playstyle.
---
--- Retail: UnitPower(Runes) does not reliably mirror per-rune spend/regen; use GetRuneCooldown (same as stock rune UI).
local function CountDeathKnightRunesReady()
  if not GetRuneCooldown then return nil end
  local n = 0
  local ok = pcall(function()
    for i = 1, C.DK_RUNE_COUNT do
      local start, duration, runeReady = GetRuneCooldown(i)
      --- Third return is boolean on most clients; some builds use 1/0.
      if runeReady == true or runeReady == 1 then
        n = n + 1
      elseif runeReady == false or runeReady == 0 then
        --- On cooldown.
      else
        --- Some builds omit the third return; treat as ready only when no CD is active.
        local d = duration
        local s = start
        if type(d) == "number" and type(s) == "number" and d <= 0 and s <= 0 then
          n = n + 1
        end
      end
    end
  end)
  if not ok then return nil end
  return n
end

--- 0 = just depleted, 1 = ready; mid values = recharge progress (elapsed / cooldown duration).
local function GetRuneRechargeProgress(runeIndex)
  if not GetRuneCooldown then return 1 end
  local start, duration, runeReady = GetRuneCooldown(runeIndex)
  if runeReady == true or runeReady == 1 then
    return 1
  end
  local dur = type(duration) == "number" and duration or 0
  local st = type(start) == "number" and start or 0
  if dur > 0 then
    local now = GetTime()
    local elapsed = now - st
    if elapsed < 0 then elapsed = 0 end
    return math.max(0, math.min(1, elapsed / dur))
  end
  if runeReady == false or runeReady == 0 then
    return 0
  end
  if st <= 0 and dur <= 0 then
    return 1
  end
  return 0
end

local function ReadPlayerPowerForLane1()
  local unit = "player"
  if not UnitExists(unit) then return nil, 0, 0 end
  local UFw = ns.UnitFrames
  if not UFw then return nil, 0, 0 end

  local classId = select(3, UnitClass(unit))
  if type(classId) == "number" and classId == 6 then
    local E = Enum and Enum.PowerType
    local runePt = E and E.Runes
    if runePt ~= nil then
      local ready = CountDeathKnightRunesReady()
      if ready ~= nil then
        return runePt, UFw.CoerceAmount(ready), C.DK_RUNE_COUNT
      end
      --- Fallback if GetRuneCooldown unavailable (should be rare).
      local cur, mx = 0, 0
      local okRead = pcall(function()
        mx = UnitPowerMax(unit, runePt) + 0
        cur = (UnitPower(unit, runePt) or 0) + 0
      end)
      local good = false
      pcall(function()
        good = okRead and type(mx) == "number" and mx == mx and mx > 0
      end)
      if good then
        return runePt, UFw.CoerceAmount(cur), UFw.CoerceAmount(mx)
      end
    end
  end

  local pt, pc, pm = nil, 0, 0

  if UFw.GetSecondaryPowerValues then
    local spt, cur, mx = UFw.GetSecondaryPowerValues(unit)
    if spt ~= nil then
      local c = UFw.CoerceAmount(cur)
      local m = UFw.CoerceAmount(mx)
      local use = false
      pcall(function()
        use = type(m) == "number" and m == m and m > 0
      end)
      if use then
        pt, pc, pm = spt, c, m
      end
    end
  end

  if pt == nil and UFw.GetUnitPowerBarValues then
    pt, pc, pm = UFw.GetUnitPowerBarValues(unit)
  end

  if pt == nil then return nil, 0, 0 end

  --- Do not merge DK lane-1 Runes with primary power bar; types differ (Runes vs Runic Power).
  local E = Enum and Enum.PowerType
  local isDkRunes = E and pt == E.Runes
  if UFw.GetUnitPowerBarValues and Lane1UsePoolBar(pm, pt) and not isDkRunes then
    local p2, c2, m2 = UFw.GetUnitPowerBarValues(unit)
    if p2 ~= nil and PowerTypesMatch(pt, p2) then
      local mc = UFw.CoerceAmount(m2)
      if mc > 0 then
        pt, pc, pm = p2, c2, m2
      end
    end
  end

  return pt, pc, pm
end

--- progressList: optional per-segment fill 0â€“1 (e.g. DK rune recharge).
local function RepositionPips(n, filled, pt, barW, progressList)
  local lane = CC.state.lane1
  if not lane then return end
  if n <= 0 or barW <= 0 then
    for i = 1, MAX_PIPS do
      local slot = CC.state.lane1Pips[i]
      if slot and slot.holder then
        slot.holder:Hide()
      end
    end
    return
  end
  local pipH = PIP_H
  local gap = PIP_SEGMENT_GAP
  local totalGap = (n - 1) * gap
  --- Integer widths + cumulative X so every gap is exactly `gap` px (fractional math rounds badly mid-row).
  local bw = math.max(1, math.floor(barW + 0.5))
  local inner = bw - totalGap
  if inner < n then inner = n end
  local baseW = math.floor(inner / n)
  local rem = inner - n * baseW
  local r, g, b = SecondaryPowerTypeColor(pt)
  local yPad = math.max(0, (lane:GetHeight() or pipH) - pipH) / 2
  local x = 0
  for i = 1, MAX_PIPS do
    local slot = CC.state.lane1Pips[i]
    if not slot or not slot.holder then
    elseif i <= n then
      local holder = slot.holder
      local bgTex = slot.bgTex or slot.tex
      local fillTex = slot.fillTex or slot.tex
      local wi = baseW + (i <= rem and 1 or 0)
      holder:Show()
      holder:SetSize(wi, pipH)
      holder:ClearAllPoints()
      holder:SetPoint("TOPLEFT", lane, "TOPLEFT", x, -yPad)
      x = x + wi + gap
      local p
      if progressList and type(progressList[i]) == "number" then
        p = progressList[i]
        if p < 0 then p = 0 elseif p > 1 then p = 1 end
      else
        p = (i <= filled) and 1 or 0
      end
      if bgTex and fillTex and bgTex ~= fillTex then
        bgTex:SetAllPoints(holder)
        bgTex:SetVertexColor(PIP_EMPTY_R, PIP_EMPTY_G, PIP_EMPTY_B, PIP_EMPTY_A)
        local fw = wi * p
        if p <= 0.001 then
          fillTex:Hide()
        else
          fillTex:Show()
          fillTex:ClearAllPoints()
          fillTex:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
          fillTex:SetWidth(math.max(1, fw))
          fillTex:SetHeight(pipH)
          fillTex:SetTexture("Interface\\Buttons\\WHITE8x8")
          local a = 0.52 + 0.43 * p
          fillTex:SetVertexColor(r, g, b, a)
        end
      else
        --- Legacy single-texture pip (no fill layer).
        fillTex:ClearAllPoints()
        fillTex:SetAllPoints(holder)
        if p >= 0.999 then
          fillTex:SetVertexColor(r, g, b, 0.95)
        else
          fillTex:SetVertexColor(PIP_EMPTY_R, PIP_EMPTY_G, PIP_EMPTY_B, PIP_EMPTY_A)
        end
      end
    else
      slot.holder:Hide()
    end
  end
end

local function UpdateLane1()
  local db = CC.DB()
  local wrap = CC.state.lane1Wrap
  local bar = CC.state.lane1Bar
  local pipLane = CC.state.lane1
  if not wrap then return end
  local lane1Bg = CC.state.lane1Bg
  wrap:SetShown(db.showResourceLane ~= false)
  if not wrap:IsShown() then
    CC.state.lane1FastTick = false
    if bar then bar:Hide() end
    if pipLane then pipLane:Hide() end
    if lane1Bg then lane1Bg:Hide() end
    if CC.state.lane1BgBottom then CC.state.lane1BgBottom:Hide() end
    return
  end
  if not bar or not bar.SetMinMaxValues then
    if lane1Bg then lane1Bg:Hide() end
    if CC.state.lane1BgBottom then CC.state.lane1BgBottom:Hide() end
    return
  end

  local pt, pc, pm = ReadPlayerPowerForLane1()
  local UFw = ns.UnitFrames
  if UFw and UFw.CoerceAmount then
    pc = UFw.CoerceAmount(pc)
    pm = UFw.CoerceAmount(pm)
  end
  local valid = false
  pcall(function()
    valid = pt ~= nil and type(pm) == "number" and pm == pm and pm > 0
  end)
  if not valid then
    CC.state.lane1FastTick = false
    bar:Hide()
    if pipLane then pipLane:Hide() end
    if lane1Bg then lane1Bg:Hide() end
    if CC.state.lane1BgBottom then CC.state.lane1BgBottom:Hide() end
    return
  end

  local size = db.iconSize or 44
  local rotationW = ICONS_LANE2 * size + (ICONS_LANE2 - 1) * PIP_SEGMENT_GAP
  local pipBarW = rotationW * PIP_BAR_WIDTH_FRAC
  local wrapInner = math.max(0, (wrap:GetWidth() or 0) - (PIP_WRAP_PAD * 2))
  local w = bar:GetWidth()
  local h = bar:GetHeight()
  if not w or w <= 0 then
    w = (wrapInner > 0) and wrapInner or pipBarW
  end
  if not h or h <= 0 then
    h = LANE1_STATUS_H
  end
  w = math.max(1, w or pipBarW)
  local lane1InnerH = math.max(LANE1_STATUS_H, PIP_H)
  bar:SetSize(w, LANE1_STATUS_H)
  if pipLane then
    --- Same height as Layout lane1 so pips can sit vertically centered in the strip (no wide bg wrapper).
    pipLane:SetSize(w, lane1InnerH)
  end

  CC.state.lane1FastTick = false
  local usePool = Lane1UsePoolBar(pm, pt)
  if usePool then
    if pipLane then pipLane:Hide() end
    local r, g, b = SecondaryPowerTypeColor(pt)
    --- Mirror UF.UpdatePowerBar: read by power type and use normalized values, else raw (secret-safe).
    local unit = "player"
    local maxP = UnitPowerMax(unit, pt)
    local cur = UnitPower(unit, pt)
    local okNorm, cNum, mNum = pcall(function()
      local c = cur + 0
      local m = maxP + 0
      if m <= 0 then return nil, nil end
      if c > m then c = m end
      if c < 0 then c = 0 end
      return c, m
    end)
    local setOk = false
    if okNorm and cNum ~= nil and mNum ~= nil then
      setOk = pcall(function()
        bar:SetMinMaxValues(0, mNum)
        bar:SetValue(cNum)
        bar:SetStatusBarColor(r, g, b, 1)
      end)
    end
    if not setOk then
      pcall(function()
        bar:SetMinMaxValues(0, maxP)
        bar:SetValue(cur)
      end)
      pcall(function()
        bar:SetStatusBarColor(r, g, b, 1)
      end)
    end
    local st = bar:GetStatusBarTexture()
    if st then st:SetAlpha(1) end
    bar:Show()
  else
    bar:Hide()
    if pipLane then
      pipLane:Show()
      local n = math.min(MAX_PIPS, math.max(1, math.floor(pm + 0.5)))
      local filled = math.min(n, math.max(0, math.floor(pc + 0.5)))
      local progressList
      local E = Enum and Enum.PowerType
      if E and pt == E.Runes and GetRuneCooldown then
        progressList = {}
        for i = 1, n do
          progressList[i] = GetRuneRechargeProgress(i)
        end
      end
      RepositionPips(n, filled, pt, w, progressList)
      CC.state.lane1FastTick = progressList ~= nil
    end
  end

  local yMainBg = math.floor(LANE1_BOTTOM_BG_H / 2)
  if lane1Bg then
    lane1Bg:ClearAllPoints()
    lane1Bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    lane1Bg:SetVertexColor(0, 0, 0, PIP_WRAP_BG_A)
    local bgH = usePool and (LANE1_STATUS_H + 2 * PIP_BG_PAD) or (PIP_H + 2 * PIP_BG_PAD)
    lane1Bg:SetSize(w + 2 * PIP_BG_PAD, bgH)
    lane1Bg:SetPoint("CENTER", wrap, "CENTER", 0, yMainBg)
    lane1Bg:Show()
  end
  local bgb = CC.state.lane1BgBottom
  if bgb and bgb.ClearAllPoints then
    bgb:ClearAllPoints()
    bgb:SetSize(w + 2 * PIP_BG_PAD, LANE1_BOTTOM_BG_H)
    bgb:SetPoint("BOTTOM", wrap, "BOTTOM", 0, PIP_WRAP_PAD)
    bgb:Show()
  end
end

CC.UpdateLane1 = UpdateLane1