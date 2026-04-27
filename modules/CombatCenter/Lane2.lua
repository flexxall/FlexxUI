local _, ns = ...
local CC = ns.CombatCenter
local C = CC.const

local function PrimaryPowerColor(pt)
  local pbc = PowerBarColor and PowerBarColor[pt]
  if pbc then
    return pbc.r or pbc[1] or 0.2, pbc.g or pbc[2] or 0.45, pbc.b or pbc[3] or 0.9
  end
  if Enum and Enum.PowerType then
    local E = Enum.PowerType
    if pt == E.Mana then return 0.2, 0.45, 0.9 end
    if pt == E.Rage then return 0.78, 0.16, 0.22 end
    if pt == E.Energy then return 0.92, 0.82, 0.25 end
    if pt == E.Focus then return 0.90, 0.50, 0.22 end
    if pt == E.RunicPower then return 0.00, 0.82, 1.00 end
  end
  return 0.2, 0.45, 0.9
end

local function UpdateLane2PrimaryBar(showL2, panelUp)
  local lane2 = CC.state.lane2
  local bar = CC.state.lane2Bar
  local bg = CC.state.lane2BarBg
  if not lane2 or not bar then return end
  lane2:SetShown(showL2)
  if not (showL2 and panelUp) then
    bar:Hide()
    return
  end
  local pt, cNum, mNum
  local UFw = ns.UnitFrames
  if UFw and UFw.GetUnitPowerBarValues then
    pt, cNum, mNum = UFw.GetUnitPowerBarValues("player")
  end
  if pt == nil or cNum == nil or mNum == nil then
    pt = select(1, UnitPowerType("player"))
    local cur = UnitPower("player", pt)
    local mx = UnitPowerMax("player", pt)
    local ok
    ok, cNum, mNum = pcall(function()
      local c = cur + 0
      local m = mx + 0
      if m <= 0 then return nil, nil end
      if c < 0 then c = 0 end
      if c > m then c = m end
      return c, m
    end)
    if not ok then
      cNum, mNum = nil, nil
    end
  end
  if cNum == nil or mNum == nil then
    bar:Hide()
    return
  end
  local r, g, b = PrimaryPowerColor(pt)
  pcall(function()
    bar:SetMinMaxValues(0, mNum)
    bar:SetValue(cNum)
    bar:SetStatusBarColor(r, g, b, 1)
  end)
  if bg then
    pcall(function()
      bg:SetVertexColor(0.08, 0.10, 0.14, 0.45)
    end)
  end
  local st = bar:GetStatusBarTexture()
  if st then st:SetAlpha(1) end
  bar:Show()
end

function CC.UpdateLane2And3()
  local db = CC.DB()
  local all = CC.CollectActionBarEntries()
  local rotationList = {}
  local spellSlot = CC.BuildSpellToSlotMap()
  local cooldownList = CC.BuildLane3CooldownList(all, spellSlot, rotationList)
  CC.state._rotationSpellIdSet = {}
  local showL2 = db.showPrimaryLane ~= false
  local showL3 = db.showCooldownLane ~= false
  CC.state.lane3:SetShown(showL3)
  --- Tie icon visibility to the combat panel: lane*:IsShown() ignores parent chain and left stale icons when the panel hid.
  local panelUp = CC.state.frame and CC.state.frame:IsShown()
  UpdateLane2PrimaryBar(showL2, panelUp)
  CC.UpdateLaneIcons(CC.state.lane3Icons, cooldownList, showL3 and panelUp, false, true)
end
