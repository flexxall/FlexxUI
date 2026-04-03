local _, ns = ...
local UF = ns.UnitFrames

local ICON_SIZE = 30
local ICON_GAP = 2
--- How many harmful/helpful auras to scan and pool UI for (Blizzard uses NUM_TOTAL_AURA_DISPLAYS, typically 32; we previously stopped at 10).
local MAX_AURA_DISPLAY = 32
do
  local n = _G.NUM_TOTAL_AURA_DISPLAYS or _G.NUM_AURA_DISPLAYS
  if type(n) == "number" and n >= 16 then
    MAX_AURA_DISPLAY = math.min(64, n)
  end
end
local MAX_ICONS = MAX_AURA_DISPLAY
local MAX_TIMER_ROWS = MAX_AURA_DISPLAY
--- Debuff timer bar row height (icon + status strip). +50% vs original 18px ("half again as tall").
local TIMER_ROW_H = 27
local TIMER_ICON = 24
local TIMER_ROW_GAP = 3
local TIMER_BAR_TRIM = 6
local TIMER_ICON_PAD = 6

-- Debuff row / timer stack above the health bar. Y offset: small gap + half health bar height (matches Frames.lua health h≈28 → +14).
local HEALTH_BAR_REF_H = 28
local DEFAULT_DEBUFF_AX = 0
local DEFAULT_DEBUFF_AY = 4 + math.floor(HEALTH_BAR_REF_H / 2)
local DEFAULT_BUFF_AX = 0
local DEFAULT_BUFF_AY = DEFAULT_DEBUFF_AY + ICON_SIZE + ICON_GAP

local function MigrateLegacyAuraAnchors(db)
  if not db then return end
  if db.unitFrameAuraBuffAnchorX == nil and db.unitFrameAuraAnchorX ~= nil then
    db.unitFrameAuraBuffAnchorX = db.unitFrameAuraAnchorX
    db.unitFrameAuraDebuffAnchorX = db.unitFrameAuraAnchorX
  end
  if db.unitFrameAuraBuffAnchorY == nil and db.unitFrameAuraAnchorY ~= nil then
    local gap = db.unitFrameAuraBuffGap or 4
    local row = ICON_SIZE + gap
    db.unitFrameAuraDebuffAnchorY = db.unitFrameAuraAnchorY
    db.unitFrameAuraBuffAnchorY = db.unitFrameAuraAnchorY + row
  end
end

--- Copy shared unitFrameAura*Anchor* into player/target when missing (one-time migration path).
local function CopySharedAnchorsToPerUnit(db)
  if not db then return end
  for _, side in ipairs({ "player", "target" }) do
    if db[side .. "AuraBuffAnchorX"] == nil and db.unitFrameAuraBuffAnchorX ~= nil then
      db[side .. "AuraBuffAnchorX"] = db.unitFrameAuraBuffAnchorX
      db[side .. "AuraBuffAnchorY"] = db.unitFrameAuraBuffAnchorY
      db[side .. "AuraDebuffAnchorX"] = db.unitFrameAuraDebuffAnchorX
      db[side .. "AuraDebuffAnchorY"] = db.unitFrameAuraDebuffAnchorY
    end
  end
end

local function GetAuraLayout(db, side)
  db = db or _G.FlexxUIDB or {}
  if side ~= "player" and side ~= "target" then side = "player" end
  MigrateLegacyAuraAnchors(db)
  CopySharedAnchorsToPerUnit(db)
  local bax = db[side .. "AuraBuffAnchorX"]
  local bay = db[side .. "AuraBuffAnchorY"]
  local dax = db[side .. "AuraDebuffAnchorX"]
  local day = db[side .. "AuraDebuffAnchorY"]
  if bax == nil then bax = DEFAULT_BUFF_AX end
  if bay == nil then bay = DEFAULT_BUFF_AY end
  if dax == nil then dax = DEFAULT_DEBUFF_AX end
  if day == nil then day = DEFAULT_DEBUFF_AY end
  return bax, bay, dax, day
end

local function GetTestDebuffPlaceholders()
  local now = GetTime()
  return {
    {
      icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
      spellId = 589,
      name = "[Preview] Shadow Word: Pain",
      duration = 12,
      expirationTime = now + 8,
    },
    {
      icon = "Interface\\Icons\\Spell_Nature_StrangleVines",
      spellId = 339,
      name = "[Preview] Entangling Roots",
      duration = 24,
      expirationTime = now + 18,
    },
  }
end

local function GetTestBuffPlaceholders()
  local now = GetTime()
  return {
    {
      icon = "Interface\\Icons\\Spell_Holy_SealOfVengeance",
      spellId = 31801,
      name = "[Preview] Blessing",
      duration = 3600,
      expirationTime = now + 2400,
    },
    {
      icon = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
      spellId = 25898,
      name = "[Preview] Greater Blessing",
      duration = 3600,
      expirationTime = now + 3000,
    },
  }
end

local function MigrateDebuffDisplayMode(db)
  if db.unitFrameAuraDebuffDisplay ~= nil then
    local v = db.unitFrameAuraDebuffDisplay
    if v == "none" or v == "icons" or v == "bars" then return v end
  end
  if db.unitFrameAuraDebuffs == false then return "none" end
  if db.unitFrameAuraBars == true then return "bars" end
  return "icons"
end

local function SyncLegacyDebuffFlags(db)
  local m = db.unitFrameAuraDebuffDisplay
  if m == "none" then
    db.unitFrameAuraDebuffs = false
    db.unitFrameAuraBars = false
  elseif m == "bars" then
    db.unitFrameAuraDebuffs = true
    db.unitFrameAuraBars = true
  else
    db.unitFrameAuraDebuffs = true
    db.unitFrameAuraBars = false
  end
end

--- Mirror player aura settings into legacy keys for older API callers.
local function SyncLegacyFromPlayer(db)
  if not db then return end
  db.unitFrameAuraDebuffDisplay = db.playerAuraDebuffDisplay or "icons"
  db.unitFrameAuraBuffs = db.playerAuraBuffs ~= false
  SyncLegacyDebuffFlags(db)
end

local function EnsureAuraDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  local db = _G.FlexxUIDB
  MigrateLegacyAuraAnchors(db)
  local legacyMode = MigrateDebuffDisplayMode(db)
  if db.playerAuraBuffs == nil then
    db.playerAuraBuffs = db.unitFrameAuraBuffs ~= false
  end
  if db.targetAuraBuffs == nil then
    db.targetAuraBuffs = db.unitFrameAuraBuffs ~= false
  end
  if db.playerAuraDebuffDisplay == nil then
    db.playerAuraDebuffDisplay = legacyMode
  end
  if db.targetAuraDebuffDisplay == nil then
    db.targetAuraDebuffDisplay = legacyMode
  end
  CopySharedAnchorsToPerUnit(db)
  if db.playerAuraBuffAnchorX == nil then db.playerAuraBuffAnchorX = DEFAULT_BUFF_AX end
  if db.playerAuraBuffAnchorY == nil then db.playerAuraBuffAnchorY = DEFAULT_BUFF_AY end
  if db.playerAuraDebuffAnchorX == nil then db.playerAuraDebuffAnchorX = DEFAULT_DEBUFF_AX end
  if db.playerAuraDebuffAnchorY == nil then db.playerAuraDebuffAnchorY = DEFAULT_DEBUFF_AY end
  if db.targetAuraBuffAnchorX == nil then db.targetAuraBuffAnchorX = DEFAULT_BUFF_AX end
  if db.targetAuraBuffAnchorY == nil then db.targetAuraBuffAnchorY = DEFAULT_BUFF_AY end
  if db.targetAuraDebuffAnchorX == nil then db.targetAuraDebuffAnchorX = DEFAULT_DEBUFF_AX end
  if db.targetAuraDebuffAnchorY == nil then db.targetAuraDebuffAnchorY = DEFAULT_DEBUFF_AY end
  if db.unitFrameAuraBuffAnchorX == nil then db.unitFrameAuraBuffAnchorX = db.playerAuraBuffAnchorX end
  if db.unitFrameAuraBuffAnchorY == nil then db.unitFrameAuraBuffAnchorY = db.playerAuraBuffAnchorY end
  if db.unitFrameAuraDebuffAnchorX == nil then db.unitFrameAuraDebuffAnchorX = db.playerAuraDebuffAnchorX end
  if db.unitFrameAuraDebuffAnchorY == nil then db.unitFrameAuraDebuffAnchorY = db.playerAuraDebuffAnchorY end
  if db.unitFrameAuraDevPreviewBuff == nil then db.unitFrameAuraDevPreviewBuff = false end
  if db.unitFrameAuraDevPreviewDebuff == nil then db.unitFrameAuraDevPreviewDebuff = false end
  if db.unitFrameAuraDevPreviewBars == nil then db.unitFrameAuraDevPreviewBars = false end
  --- One-time: debuff row was +4px; now +4 + half reference health bar (14px) = 18. Buff row follows stack spacing when still legacy.
  if db._auraDebuffYRaised2026 == nil then
    local legacyD, legacyB = 4, 4 + ICON_SIZE + ICON_GAP
    local newD, newB = DEFAULT_DEBUFF_AY, DEFAULT_BUFF_AY
    local function bumpPair(prefix)
      local dk = prefix .. "AuraDebuffAnchorY"
      local bk = prefix .. "AuraBuffAnchorY"
      if db[dk] == legacyD then
        db[dk] = newD
        if db[bk] == legacyB then
          db[bk] = newB
        end
      end
    end
    bumpPair("player")
    bumpPair("target")
    if db.unitFrameAuraDebuffAnchorY == legacyD then
      db.unitFrameAuraDebuffAnchorY = newD
      if db.unitFrameAuraBuffAnchorY == legacyB then
        db.unitFrameAuraBuffAnchorY = newB
      end
    end
    db._auraDebuffYRaised2026 = true
  end
  SyncLegacyFromPlayer(db)
end

local function CollectAuras(unit, filter, maxN)
  local out = {}
  if not unit or not UnitExists(unit) then return out end
  if not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex then return out end
  maxN = maxN or MAX_AURA_DISPLAY
  --- Blizzard helper: same index walk as the default aura UI (handles client quirks vs a raw loop).
  if AuraUtil and AuraUtil.ForEachAura then
    local okScan = pcall(function()
      --- 5th arg `true`: use AuraData tables (matches default UI); omitting can change what the callback receives.
      AuraUtil.ForEachAura(unit, filter, maxN, function(aura)
        if aura then
          out[#out + 1] = aura
        end
      end, true)
    end)
    if okScan then
      return out
    end
    out = {}
  end
  local i = 1
  local cap = math.min(maxN, 64)
  while #out < maxN and i <= cap do
    local ok, data = pcall(function()
      return C_UnitAuras.GetAuraDataByIndex(unit, i, filter)
    end)
    if not ok or not data then break end
    out[#out + 1] = data
    i = i + 1
  end
  return out
end

local function CreateAuraButton(parent, isDebuff)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(ICON_SIZE, ICON_SIZE)
  btn:EnableMouse(true)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
  border:SetVertexColor(isDebuff and 0.9 or 0.35, isDebuff and 0.2 or 0.65, isDebuff and 0.15 or 0.35, 1)

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
  pcall(function()
    if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
  end)
  cd:Hide()

  btn.icon = icon
  btn.border = border
  btn.cooldown = cd
  btn.isDebuff = isDebuff
  btn:Hide()

  btn:SetScript("OnEnter", function(self)
    local tip = GameTooltip
    if not tip or tip:IsForbidden() then return end
    tip:SetOwner(self, "ANCHOR_RIGHT")
    local usedSpell = false
    if self.spellId ~= nil then
      usedSpell = select(1, pcall(function()
        tip:SetSpellByID(self.spellId)
      end))
    end
    if not usedSpell and self.auraName ~= nil then
      pcall(function()
        tip:SetText(tostring(self.auraName), 1, 1, 1)
      end)
    end
    tip:Show()
  end)
  btn:SetScript("OnLeave", function()
    local tip = GameTooltip
    if tip and not tip:IsForbidden() then tip:Hide() end
  end)

  return btn
end

local function ApplyButtonLayout(btn)
  btn:SetSize(ICON_SIZE, ICON_SIZE)
  btn.border:ClearAllPoints()
  btn.border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
  btn.border:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
  btn.border:SetHeight(ICON_SIZE)

  btn.icon:ClearAllPoints()
  btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
  btn.icon:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -1, -1)
  btn.icon:SetHeight(ICON_SIZE - 2)

  btn.cooldown:ClearAllPoints()
  btn.cooldown:SetPoint("TOPLEFT", btn.icon, "TOPLEFT", 0, 0)
  btn.cooldown:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", 0, 0)
end

--- Buff/debuff icons: cooldown swipe on the icon; optional remaining seconds when duration is readable.
local function UpdateAuraButton(btn, data, devPreviewCooldown)
  if not data then
    btn:Hide()
    return
  end
  ApplyButtonLayout(btn)

  local tex = data.icon or data.iconFileID
  if tex then
    btn.icon:SetTexture(tex)
  end
  btn.spellId = data.spellId or data.spellID
  btn.auraName = data.name
  btn.border:SetVertexColor(btn.isDebuff and 0.9 or 0.35, btn.isDebuff and 0.2 or 0.65, btn.isDebuff and 0.15 or 0.35, 1)

  local dur = UF.PlainNumber(data.duration, nil)
  local exp = UF.PlainNumber(data.expirationTime, nil)
  local cd = btn.cooldown
  local hasTimer = dur and exp and dur > 0 and exp > 0
  if devPreviewCooldown and not hasTimer then
    dur = 60
    exp = GetTime() + 40
    hasTimer = true
  end

  if not btn.cdText then
    btn.cdText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    btn.cdText:SetPoint("BOTTOMRIGHT", btn.icon, "BOTTOMRIGHT", 0, 2)
  end

  if hasTimer then
    pcall(function()
      local start = exp - dur
      cd:SetCooldown(start, dur)
    end)
    cd:Show()
    local remain = 0
    pcall(function()
      remain = exp - GetTime()
      if remain < 0 then remain = 0 end
    end)
    if remain > 0 and remain < 3600 then
      if remain >= 60 then
        btn.cdText:SetFormattedText("%dm", math.floor(remain / 60))
      else
        btn.cdText:SetFormattedText("%.0f", remain)
      end
      btn.cdText:Show()
    else
      btn.cdText:Hide()
    end
  else
    pcall(function()
      cd:Clear()
    end)
    cd:Hide()
    btn.cdText:Hide()
  end

  btn:Show()
end

local function CreateTimerBarRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(TIMER_ROW_H)
  local icon = row:CreateTexture(nil, "ARTWORK")
  icon:SetSize(TIMER_ICON, TIMER_ICON)
  icon:SetPoint("LEFT", 0, 0)
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local bar = CreateFrame("StatusBar", nil, row)
  bar:SetHeight(math.max(8, TIMER_ROW_H - TIMER_BAR_TRIM))
  bar:SetPoint("LEFT", icon, "RIGHT", TIMER_ICON_PAD, 0)
  bar:SetPoint("RIGHT", row, "RIGHT", 0, 0)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(1)
  bar:SetStatusBarColor(0.88, 0.22, 0.18, 0.95)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.5)
  row.icon = icon
  row.bar = bar
  row:Hide()
  return row
end

local function UpdateTimerBarRow(row, data, devPreviewTimer)
  row._flexxDur = nil
  row._flexxExp = nil
  if not data then
    row:Hide()
    return
  end
  local dur = UF.PlainNumber(data.duration, nil)
  local exp = UF.PlainNumber(data.expirationTime, nil)
  local hasTimer = dur and exp and dur > 0 and exp > 0
  if devPreviewTimer and not hasTimer then
    dur = 45
    exp = GetTime() + 30
    hasTimer = true
  end
  if not hasTimer then
    row:Hide()
    return
  end
  local tex = data.icon or data.iconFileID
  if tex then
    row.icon:SetTexture(tex)
  end
  -- Persist plain numbers for OnUpdate: UNIT_AURA does not fire every tick while auras tick down.
  row._flexxDur = dur
  row._flexxExp = exp
  local remain = 0
  pcall(function()
    remain = UF.PlainNumber(exp - GetTime(), 0) or 0
    if remain < 0 then remain = 0 end
  end)
  row.bar:SetMinMaxValues(0, dur)
  row.bar:SetValue(remain)
  row:Show()
end

--- Smooth countdown: StatusBar only updates when this runs; aura events alone are too sparse.
local function AuraTimerBarHost_OnUpdate(host)
  if not host or not host:IsShown() then return end
  local uf = host:GetParent()
  if not uf or not uf.auraTimerBarRows then return end
  local now = GetTime()
  for i = 1, MAX_TIMER_ROWS do
    local row = uf.auraTimerBarRows[i]
    if row and row:IsShown() and row._flexxExp and row._flexxDur and row._flexxDur > 0 then
      local remain = 0
      pcall(function()
        remain = UF.PlainNumber(row._flexxExp - now, 0) or 0
        if remain < 0 then remain = 0 end
      end)
      row.bar:SetMinMaxValues(0, row._flexxDur)
      row.bar:SetValue(remain)
    end
  end
end

function UF.CreateUnitAuras(f)
  if not f or f._flexxAurasBuilt then return end
  f._flexxAurasBuilt = true

  local z = (f:GetFrameLevel() or 0) + 125

  f.auraTimerBarHost = CreateFrame("Frame", nil, f)
  f.auraTimerBarHost:SetFrameLevel(z)
  f.auraTimerBarHost:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, DEFAULT_DEBUFF_AY)
  f.auraTimerBarHost:SetWidth(200)
  f.auraTimerBarHost:Hide()
  f.auraTimerBarHost:SetScript("OnUpdate", AuraTimerBarHost_OnUpdate)
  f.auraTimerBarRows = {}
  for i = 1, MAX_TIMER_ROWS do
    f.auraTimerBarRows[i] = CreateTimerBarRow(f.auraTimerBarHost)
  end

  f.auraDebuffHost = CreateFrame("Frame", nil, f)
  f.auraDebuffHost:SetFrameLevel(z)
  f.auraDebuffHost:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 0, DEFAULT_DEBUFF_AY)
  f.auraDebuffHost:SetWidth((ICON_SIZE + ICON_GAP) * MAX_ICONS)
  f.auraDebuffHost:SetHeight(ICON_SIZE)
  f.auraDebuffHost:EnableMouse(false)

  f.auraDebuffButtons = {}
  for i = 1, MAX_ICONS do
    f.auraDebuffButtons[i] = CreateAuraButton(f.auraDebuffHost, true)
  end

  f.auraBuffHost = CreateFrame("Frame", nil, f)
  f.auraBuffHost:SetFrameLevel(z)
  f.auraBuffHost:SetWidth((ICON_SIZE + ICON_GAP) * MAX_ICONS)
  f.auraBuffHost:SetHeight(ICON_SIZE)
  f.auraBuffHost:EnableMouse(false)
  f.auraBuffHost:Hide()

  f.auraBuffButtons = {}
  for i = 1, MAX_ICONS do
    f.auraBuffButtons[i] = CreateAuraButton(f.auraBuffHost, false)
  end
end

function UF.UpdateUnitAuras(f)
  if not f or not f._flexxAurasBuilt or not f.unit then return end
  EnsureAuraDB()
  local db = _G.FlexxUIDB
  local unit = f.unit
  if not UnitExists(unit) then
    f.auraDebuffHost:Hide()
    if f.auraBuffHost then f.auraBuffHost:Hide() end
    if f.auraTimerBarHost then f.auraTimerBarHost:Hide() end
    return
  end

  local side = (unit == "target") and "target" or "player"
  local userBuffs = db[side .. "AuraBuffs"] ~= false
  local debuffMode = db[side .. "AuraDebuffDisplay"] or "icons"
  if debuffMode ~= "none" and debuffMode ~= "icons" and debuffMode ~= "bars" then debuffMode = "icons" end

  local prevB = (side == "player") and (db.unitFrameAuraDevPreviewBuff == true)
  local prevD = (side == "player") and (db.unitFrameAuraDevPreviewDebuff == true)
  local prevTimer = (side == "player") and (db.unitFrameAuraDevPreviewBars == true)

  local userDebuffIcons = debuffMode == "icons"
  local userTimerBarMode = debuffMode == "bars"

  local showBuffRow = userBuffs or prevB
  -- Debuff icons: dev "preview timer bars" hides the icon row so you only see the bar stack (unless preview debuff icons).
  local showDebuffIconRow = (userDebuffIcons or prevD) and (not userTimerBarMode or prevD) and not (prevTimer and not prevD)
  -- Timer bars: live "bars" mode, or dev preview timer (any player debuff mode — preview is layout-only).
  local showTimerBarList = not prevD and (userTimerBarMode or prevTimer)
  local forceTimerPlaceholders = not prevD and prevTimer and debuffMode == "none"

  local buffAx, buffAy, debuffAx, debuffAy = GetAuraLayout(db, side)

  local rowH = ICON_SIZE

  -- ——— Debuff timer bars (stacked, icon + bar) ———
  if f.auraTimerBarHost and f.auraTimerBarRows then
    if showTimerBarList then
      local list
      if forceTimerPlaceholders then
        list = GetTestDebuffPlaceholders()
      else
        list = CollectAuras(unit, "HARMFUL", MAX_TIMER_ROWS)
      end
      -- Dev preview timer: placeholders if empty (player frame only). Live "bars" uses real auras only.
      if prevTimer and #list == 0 then
        list = GetTestDebuffPlaceholders()
      end
      local n = math.min(#list, MAX_TIMER_ROWS)
      if n == 0 then
        f.auraTimerBarHost:Hide()
        for j = 1, MAX_TIMER_ROWS do
          f.auraTimerBarRows[j]:Hide()
        end
      else
        local hw = f.health and f.health:GetWidth() or 200
        if hw < 80 then hw = 200 end
        f.auraTimerBarHost:ClearAllPoints()
        f.auraTimerBarHost:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", debuffAx, debuffAy)
        f.auraTimerBarHost:SetWidth(hw)
        for i = 1, MAX_TIMER_ROWS do
          if i <= n then
            UpdateTimerBarRow(f.auraTimerBarRows[i], list[i], prevTimer)
            local row = f.auraTimerBarRows[i]
            row:SetWidth(hw)
            row:ClearAllPoints()
            row:SetPoint("BOTTOMLEFT", f.auraTimerBarHost, "BOTTOMLEFT", 0, (i - 1) * (TIMER_ROW_H + TIMER_ROW_GAP))
          else
            f.auraTimerBarRows[i]:Hide()
          end
        end
        local stackH = n * (TIMER_ROW_H + TIMER_ROW_GAP) - TIMER_ROW_GAP
        f.auraTimerBarHost:SetHeight(math.max(stackH, 1))
        f.auraTimerBarHost:Show()
      end
    else
      f.auraTimerBarHost:Hide()
      for i = 1, MAX_TIMER_ROWS do
        f.auraTimerBarRows[i]:Hide()
      end
    end
  end

  -- ——— Debuff icons ———
  if showDebuffIconRow then
    local list
    if prevD then
      list = GetTestDebuffPlaceholders()
    else
      list = CollectAuras(unit, "HARMFUL", MAX_ICONS)
    end
    local n = math.min(#list, MAX_ICONS)
    f.auraDebuffHost:ClearAllPoints()
    f.auraDebuffHost:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", debuffAx, debuffAy)
    f.auraDebuffHost:SetHeight(rowH)
    f.auraDebuffHost:Show()
    for i = 1, MAX_ICONS do
      if i <= n then
        UpdateAuraButton(f.auraDebuffButtons[i], list[i], prevD)
        local btn = f.auraDebuffButtons[i]
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", f.auraDebuffHost, "BOTTOMLEFT", (i - 1) * (ICON_SIZE + ICON_GAP), 0)
      else
        f.auraDebuffButtons[i]:Hide()
      end
    end
  else
    f.auraDebuffHost:Hide()
    for i = 1, MAX_ICONS do
      f.auraDebuffButtons[i]:Hide()
    end
  end

  -- ——— Buff icons ———
  if showBuffRow and f.auraBuffHost and f.auraBuffButtons then
    local list
    if prevB then
      list = GetTestBuffPlaceholders()
    else
      list = CollectAuras(unit, "HELPFUL", MAX_ICONS)
    end
    local n = math.min(#list, MAX_ICONS)
    local buffY = buffAy
    if showTimerBarList and f.auraTimerBarHost and f.auraTimerBarHost:IsShown() then
      local th = f.auraTimerBarHost:GetHeight() or 0
      buffY = math.max(buffAy, debuffAy + th + 4)
    elseif showDebuffIconRow and f.auraDebuffHost and f.auraDebuffHost:IsShown() then
      buffY = math.max(buffAy, debuffAy + rowH + 4)
    end
    f.auraBuffHost:ClearAllPoints()
    f.auraBuffHost:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", buffAx, buffY)
    f.auraBuffHost:SetHeight(rowH)
    f.auraBuffHost:Show()
    for i = 1, MAX_ICONS do
      if i <= n then
        UpdateAuraButton(f.auraBuffButtons[i], list[i], prevB)
        local btn = f.auraBuffButtons[i]
        btn:ClearAllPoints()
        btn:SetPoint("BOTTOMLEFT", f.auraBuffHost, "BOTTOMLEFT", (i - 1) * (ICON_SIZE + ICON_GAP), 0)
      else
        f.auraBuffButtons[i]:Hide()
      end
    end
  elseif f.auraBuffHost then
    f.auraBuffHost:Hide()
    if f.auraBuffButtons then
      for i = 1, MAX_ICONS do
        f.auraBuffButtons[i]:Hide()
      end
    end
  end
end

function UF.RefreshAurasFromOptions()
  EnsureAuraDB()
  for _, fr in pairs(UF.state.frames or {}) do
    if fr and fr._flexxAurasBuilt then
      UF.UpdateUnitAuras(fr)
    end
  end
end

UF.EnsureAuraDB = EnsureAuraDB

function UF.MigrateLegacyAuraLayout()
  local db = _G.FlexxUIDB or {}
  MigrateLegacyAuraAnchors(db)
  CopySharedAnchorsToPerUnit(db)
end
