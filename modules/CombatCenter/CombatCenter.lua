local _, ns = ...
local CC = ns.CombatCenter
local C = CC.const
local ICONS_LANE2 = C.ICONS_LANE2
local ICONS_LANE3 = C.ICONS_LANE3
local MAX_PIPS = C.MAX_PIPS
local PIP_WRAP_BG_A = C.PIP_WRAP_BG_A
local PIP_EMPTY_R, PIP_EMPTY_G, PIP_EMPTY_B = C.PIP_EMPTY_R, C.PIP_EMPTY_G, C.PIP_EMPTY_B
local PIP_EMPTY_A = C.PIP_EMPTY_A
local PIP_BAR_WIDTH_FRAC = C.PIP_BAR_WIDTH_FRAC
local LANE1_STATUS_H = C.LANE1_STATUS_H
local PIP_H = C.PIP_H
local PIP_WRAP_PAD = C.PIP_WRAP_PAD
local LANE1_BOTTOM_BG_H = C.LANE1_BOTTOM_BG_H
local PIP_ROTATION_GAP = C.PIP_ROTATION_GAP
local PIP_SEGMENT_GAP = C.PIP_SEGMENT_GAP
local DRAG_HANDLE_H = C.DRAG_HANDLE_H

--- Cooldown events: update lanes only — avoids full Layout()/EnableMouse() like default UI cooldown refreshes.
local function UpdateLanesOnly()
  if not CC.state.frame then return end
  CC.UpdateVisibility()
  CC.UpdateLane1()
  CC.UpdateLane2And3()
end

--- After combat, last-cast GCD suppression + long-CD cache + frozen swipe state can make cooldowns look "stuck" like combat until the next API tick. Clear and redraw from fresh cooldown data (does not change WoW combat state).
local function ResetCooldownPresentationAfterLeaveCombat()
  CC.state.lastCastSpellId = nil
  CC.state.lastCastAt = nil
  CC.state.lastCastSpellName = nil
  CC.state.rotationLongCdEnd = {}
  local function clearPool(pool)
    if not pool then return end
    for i = 1, #pool do
      local iconFrame = pool[i]
      if iconFrame then
        iconFrame._flexxLastCd = nil
        iconFrame._flexxWasOnCd = false
        if iconFrame.cd then
          CC.ClearLaneCooldownVisual(iconFrame.cd)
        end
      end
    end
  end
  clearPool(CC.state.lane3Icons)
end

local function Layout()
  local db = CC.DB()
  local f = CC.state.frame
  if not f then return end
  local size = db.iconSize or 44
  local showPrimary = db.showPrimaryLane ~= false
  local showCooldown = db.showCooldownLane ~= false
  local lane1OffsetX = type(db.lane1OffsetX) == "number" and db.lane1OffsetX or 0
  local lane1OffsetY = type(db.lane1OffsetY) == "number" and db.lane1OffsetY or 0
  local lane2OffsetX = type(db.lane2OffsetX) == "number" and db.lane2OffsetX or 0
  local lane2OffsetY = type(db.lane2OffsetY) == "number" and db.lane2OffsetY or 0
  --- Horizontal gap between lane 2/3 icons matches lane 1 pip segment gap (`PIP_SEGMENT_GAP`).
  local iconGap = PIP_SEGMENT_GAP
  local rotationW = ICONS_LANE2 * size + (ICONS_LANE2 - 1) * iconGap
  local lane2W = math.floor(rotationW * PIP_BAR_WIDTH_FRAC + 0.5)
  local lane2H = math.max(LANE1_STATUS_H, 14)
  local cooldownW = ICONS_LANE3 * size + (ICONS_LANE3 - 1) * iconGap
  local frameW = math.max(rotationW, cooldownW, lane2W)
  local pipBarW = rotationW * PIP_BAR_WIDTH_FRAC
  local lane1InnerH = math.max(LANE1_STATUS_H, PIP_H)
  local lane1ContentH = lane1InnerH + (PIP_WRAP_PAD * 2)
  local lane1H = lane1ContentH + LANE1_BOTTOM_BG_H
  local lane23Rows = (showPrimary and 1 or 0) + (showCooldown and 1 or 0)
  --- Vertical gap between lane 2 and lane 3 matches horizontal icon gap (`PIP_SEGMENT_GAP`).
  local lane23BetweenGap = (showPrimary and showCooldown) and PIP_SEGMENT_GAP or 0
  local totalH = lane1H
    + (lane23Rows > 0 and (1 + (showPrimary and lane2H or 0) + (showCooldown and size or 0) + lane23BetweenGap) or 0)
  f:SetSize(frameW, totalH)

  local wrapW = pipBarW + (PIP_WRAP_PAD * 2)
  local lane1BaseX = 0
  local lane1BaseY = -5
  CC.state.lane1Wrap:ClearAllPoints()
  CC.state.lane1Wrap:SetSize(wrapW, lane1H)
  CC.state.lane1Wrap:SetPoint("TOP", f, "TOP", lane1BaseX + lane1OffsetX, lane1BaseY + lane1OffsetY)
  local lane1CenterYOff = 3
  if CC.state.lane1 then
    CC.state.lane1:ClearAllPoints()
    CC.state.lane1:SetSize(pipBarW, lane1InnerH)
    CC.state.lane1:SetPoint("CENTER", CC.state.lane1Wrap, "CENTER", 0, lane1CenterYOff)
  end

  local lane2BaseX = 0
  local lane2BaseY = -(lane1H + 4)
  CC.state.lane2:ClearAllPoints()
  CC.state.lane2:SetSize(lane2W, lane2H)
  CC.state.lane2:SetPoint("TOP", f, "TOP", lane2BaseX + lane2OffsetX, lane2BaseY + lane2OffsetY)
  if CC.state.lane2Bar then
    CC.state.lane2Bar:ClearAllPoints()
    CC.state.lane2Bar:SetSize(lane2W, lane2H)
    CC.state.lane2Bar:SetPoint("TOPLEFT", CC.state.lane2, "TOPLEFT", 0, 0)
  end

  local lane3BaseX = 0
  local lane3BaseY = lane2BaseY
  if showPrimary then
    lane3BaseY = lane3BaseY - lane2H
    if showCooldown then
      lane3BaseY = lane3BaseY - PIP_SEGMENT_GAP
    end
  end
  CC.state.lane3:ClearAllPoints()
  CC.state.lane3:SetSize(cooldownW, size)
  CC.state.lane3:SetPoint("TOP", f, "TOP", lane3BaseX, lane3BaseY)

  --- Lane 2 is now a primary resource bar (not an icon row).
  for i = 1, ICONS_LANE3 do
    local icon = CC.state.lane3Icons[i]
    icon:ClearAllPoints()
    icon:SetSize(size, size)
    if i == 1 then
      icon:SetPoint("TOPLEFT", CC.state.lane3, "TOPLEFT", 0, 0)
    else
      icon:SetPoint("TOPLEFT", CC.state.lane3Icons[i - 1], "TOPRIGHT", iconGap, 0)
    end
  end

  CC.UpdateLane1()
end

local function ApplyCombatAnchor()
  local f = CC.state.frame
  if not f or not f.ClearAllPoints then return end
  local db = CC.DB()
  local ax = type(db.anchorX) == "number" and db.anchorX or 0
  local ay = type(db.anchorY) == "number" and db.anchorY or -180
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", ax, ay)
end

local function ApplyDragHandleMouse()
  local dh = CC.state.dragHandle
  if not dh or not dh.EnableMouse then return end
  local db = CC.DB()
  local locked = db.lockFrame or (_G.FlexxUIDB and _G.FlexxUIDB.locked)
  pcall(function()
    dh:EnableMouse(not locked)
  end)
end

function CC.RefreshFromOptions()
  if not CC.state.frame then return end
  --- Combat blocks anchoring/layout; retry once after combat ends (avoid timer spam).
  if InCombatLockdown and InCombatLockdown() then
    pcall(CC.UpdateVisibility)
    if not CC.state._refreshAfterCombatScheduled and C_Timer and C_Timer.After then
      CC.state._refreshAfterCombatScheduled = true
      C_Timer.After(0.5, function()
        CC.state._refreshAfterCombatScheduled = nil
        if CC.RefreshFromOptions then
          CC.RefreshFromOptions()
        end
      end)
    end
    return
  end
  CC.RefreshSpellBookSpellIDCache()
  local db = CC.DB()
  pcall(ApplyCombatAnchor)
  if CC.state.frame.SetScale then
    pcall(function()
      CC.state.frame:SetScale(db.scale or 1)
    end)
  end
  ApplyDragHandleMouse()
  pcall(Layout)
  pcall(CC.UpdateVisibility)
  pcall(CC.UpdateLane1)
  pcall(CC.UpdateLane2And3)
end

local function CreateFrameOnce()
  if CC.state.frame then return end
  local f = CreateFrame("Frame", "FlexxUI_CombatCenter", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(20)
  f:EnableMouse(false)
  CC.state.frame = f

  CC.state.lane1Wrap = CreateFrame("Frame", nil, f)
  CC.state.lane1Wrap:EnableMouse(false)
  CC.state.lane1Bg = CC.state.lane1Wrap:CreateTexture(nil, "BACKGROUND")
  CC.state.lane1Bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  CC.state.lane1Bg:SetVertexColor(0, 0, 0, PIP_WRAP_BG_A)
  CC.state.lane1Bg:Hide()
  --- Child frame + texture (not a second Texture on the wrap): avoids client quirks with multi-layer BACKGROUND textures.
  do
    local bot = CreateFrame("Frame", nil, CC.state.lane1Wrap)
    CC.state.lane1BgBottom = bot
    bot:SetFrameLevel(CC.state.lane1Wrap:GetFrameLevel() + 1)
    local tex = bot:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    tex:SetVertexColor(0, 0, 0, PIP_WRAP_BG_A)
    tex:SetAllPoints(bot)
    bot:Hide()
    bot:EnableMouse(false)
  end
  CC.state.lane1 = CreateFrame("Frame", nil, CC.state.lane1Wrap)
  CC.state.lane1:SetFrameLevel(CC.state.lane1Wrap:GetFrameLevel() + 2)
  CC.state.lane1:EnableMouse(false)
  for i = 1, MAX_PIPS do
    local holder = CreateFrame("Frame", nil, CC.state.lane1)
    holder:EnableMouse(false)
    local bgTex = holder:CreateTexture(nil, "BACKGROUND")
    bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    local fillTex = holder:CreateTexture(nil, "ARTWORK", nil, 1)
    fillTex:SetTexture("Interface\\Buttons\\WHITE8x8")
    CC.state.lane1Pips[i] = { holder = holder, bgTex = bgTex, fillTex = fillTex, tex = fillTex }
  end
  CC.state.lane2 = CreateFrame("Frame", nil, f)
  CC.state.lane3 = CreateFrame("Frame", nil, f)
  CC.state.lane2:EnableMouse(false)
  CC.state.lane3:EnableMouse(false)
  do
    local bar = CreateFrame("StatusBar", nil, CC.state.lane2)
    CC.state.lane2Bar = bar
    bar:SetFrameLevel(CC.state.lane2:GetFrameLevel() + 2)
    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    CC.state.lane2BarBg = bg
    bg:SetAllPoints(bar)
    bg:SetTexture("Interface\\Buttons\\WHITE8x8")
    bg:SetVertexColor(0.08, 0.10, 0.14, 0.45)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    local st = bar:GetStatusBarTexture()
    if st then
      st:SetHorizTile(false)
      st:SetVertTile(false)
    end
    bar:SetMinMaxValues(0, 100)
    bar:SetValue(0)
    bar:Hide()
    bar:EnableMouse(false)
  end
  for i = 1, ICONS_LANE3 do
    CC.state.lane3Icons[i] = CC.NewIcon(CC.state.lane3)
  end

  ApplyCombatAnchor()
  f:SetMovable(true)
  do
    local dh = CreateFrame("Frame", nil, f)
    CC.state.dragHandle = dh
    dh:SetFrameLevel((f:GetFrameLevel() or 0) + 100)
    dh:SetPoint("TOPLEFT", f, "TOPLEFT")
    dh:SetPoint("TOPRIGHT", f, "TOPRIGHT")
    dh:SetHeight(DRAG_HANDLE_H)
    dh:RegisterForDrag("LeftButton")
    dh:SetScript("OnDragStart", function()
      if CC.DB().lockFrame then return end
      if _G.FlexxUIDB and _G.FlexxUIDB.locked then return end
      if InCombatLockdown() then return end
      pcall(function()
        f:StartMoving()
      end)
    end)
    dh:SetScript("OnDragStop", function()
      pcall(function()
        f:StopMovingOrSizing()
      end)
      local pt, rel, relPt, x, y = f:GetPoint(1)
      if rel == UIParent and relPt == "CENTER" and pt == "CENTER" then
        local d = CC.DB()
        d.anchorX = x
        d.anchorY = y
      end
    end)
  end
end

--- COMBAT_LOG_EVENT_UNFILTERED omitted: RegisterEvent for it triggers secure-action errors on Retail 12+ during load. Last-cast uses UNIT_* + C_Spell.GetBaseSpell for overrides.
local function EnsureCombatUpdater()
  if CC.state.updater then return end
  local u = CreateFrame("Frame")
  CC.state.updater = u
  u:RegisterEvent("PLAYER_ENTERING_WORLD")
  u:RegisterEvent("PLAYER_REGEN_DISABLED")
  u:RegisterEvent("PLAYER_REGEN_ENABLED")
  u:RegisterEvent("UNIT_POWER_UPDATE")
  u:RegisterEvent("UNIT_MAXPOWER")
  u:RegisterEvent("SPELL_UPDATE_COOLDOWN")
  u:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
  u:RegisterEvent("PLAYER_TALENT_UPDATE")
  u:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
  u:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  u:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
  u:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
  u:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
  u:RegisterEvent("SPELL_UPDATE_CHARGES")
  u:RegisterEvent("SPELLS_CHANGED")
  u:RegisterEvent("UNIT_SPELLCAST_SENT")
  u:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  pcall(function()
    u:RegisterEvent("RUNE_POWER_UPDATE")
  end)
  u:SetScript("OnEvent", function(_, ev, unit, castGUID, spellID)
    if ev == "UNIT_SPELLCAST_SENT" or ev == "UNIT_SPELLCAST_SUCCEEDED" then
      if unit ~= "player" then return end
      if type(spellID) == "number" then
        CC.state.lastCastSpellId = spellID
        CC.state.lastCastAt = GetTime and GetTime() or 0
        CC.state.lastCastSpellName = nil
        if C_Spell and C_Spell.GetSpellInfo then
          local ok, inf = pcall(C_Spell.GetSpellInfo, spellID)
          if ok and type(inf) == "table" and type(inf.name) == "string" then
            CC.state.lastCastSpellName = inf.name
          end
        end
      end
      return
    end
    if ev == "RUNE_POWER_UPDATE" then
      CC.UpdateLane1()
      return
    end
    if ev == "UNIT_POWER_UPDATE" or ev == "UNIT_MAXPOWER" then
      if unit and unit ~= "player" then return end
      CC.UpdateLane1()
      return
    end
    if ev == "SPELLS_CHANGED" then
      CC.RefreshSpellBookSpellIDCache()
      UpdateLanesOnly()
      return
    end
    if ev == "PLAYER_ENTERING_WORLD"
      or ev == "PLAYER_TALENT_UPDATE"
      or ev == "ACTIVE_TALENT_GROUP_CHANGED"
      or ev == "PLAYER_SPECIALIZATION_CHANGED" then
      if ev == "PLAYER_ENTERING_WORLD" then
        CC.state.regenCombatUi = nil
      end
      CC.RefreshFromOptions()
      return
    end
    if ev == "PLAYER_REGEN_DISABLED" then
      CC.state.regenCombatUi = true
      UpdateLanesOnly()
      return
    end
    if ev == "PLAYER_REGEN_ENABLED" then
      CC.state.regenCombatUi = nil
      ResetCooldownPresentationAfterLeaveCombat()
      UpdateLanesOnly()
      return
    end
    UpdateLanesOnly()
  end)
  --- Lane 2/3 rebuilds spell lists (action bar + spellbook scan) — never run at the DK rune fast lane-1 rate.
  local LANE23_ONUPDATE_INTERVAL = 0.25
  u:SetScript("OnUpdate", function(_, elapsed)
    if not CC.state.frame then return end
    --- Clear stuck REGEN hint without waiting for PLAYER_REGEN_ENABLED (dummies, phasing).
    if CC.state.regenCombatUi == true then
      local uac = UnitAffectingCombat and UnitAffectingCombat("player")
      local regenOn = PlayerRegenEnabled and PlayerRegenEnabled()
      if (not uac) or regenOn then
        CC.state.regenCombatUi = nil
        ResetCooldownPresentationAfterLeaveCombat()
        CC.UpdateVisibility()
        UpdateLanesOnly()
      end
    end
    --- onlyInCombat: poll visibility (no target => hide; else REGEN hint or UAC).
    local dbVis = CC.DB()
    if dbVis.onlyInCombat then
      CC.UpdateVisibility()
    end
    if not CC.state.frame:IsShown() then return end
    CC.state._accLane1 = (CC.state._accLane1 or 0) + elapsed
    CC.state._accLane23 = (CC.state._accLane23 or 0) + elapsed
    --- DK rune pips: ~28 Hz lane 1 only; rotation/cooldown icons stay ~4 Hz.
    local lane1Int = CC.state.lane1FastTick and 0.035 or LANE23_ONUPDATE_INTERVAL
    if CC.state._accLane1 >= lane1Int then
      CC.state._accLane1 = 0
      CC.UpdateLane1()
    end
    if CC.state._accLane23 >= LANE23_ONUPDATE_INTERVAL then
      CC.state._accLane23 = 0
      CC.UpdateLane2And3()
    end
  end)
end

function CC.Create()
  CreateFrameOnce()
  local function finish()
    EnsureCombatUpdater()
    CC.RefreshFromOptions()
  end
  --- Defer RegisterEvent + layout off BuildUI stack (avoids secure errors on /reload).
  if C_Timer and C_Timer.After then
    C_Timer.After(0, finish)
  else
    finish()
  end
end

