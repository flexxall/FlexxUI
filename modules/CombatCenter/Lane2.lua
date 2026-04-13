local _, ns = ...
local CC = ns.CombatCenter
local C = CC.const

function CC.UpdateLane2And3()
  local db = CC.DB()
  local all = CC.CollectActionBarEntries()
  local rotationList = {}
  for i = 1, math.min(C.ICONS_LANE2, #all) do
    rotationList[#rotationList + 1] = all[i]
  end
  local spellSlot = CC.BuildSpellToSlotMap()
  local cooldownList = CC.BuildLane3CooldownList(all, spellSlot, rotationList)
  local rotSet = {}
  for _, e in ipairs(rotationList) do
    if e.spellID then
      rotSet[e.spellID] = true
    end
  end
  CC.state._rotationSpellIdSet = rotSet
  local showL2 = db.showRotationLane ~= false
  local showL3 = db.showCooldownLane ~= false
  CC.state.lane2:SetShown(showL2)
  CC.state.lane3:SetShown(showL3)
  --- Tie icon visibility to the combat panel: lane*:IsShown() ignores parent chain and left stale icons when the panel hid.
  local panelUp = CC.state.frame and CC.state.frame:IsShown()
  CC.UpdateLaneIcons(CC.state.lane2Icons, rotationList, showL2 and panelUp, true)
  CC.UpdateLaneIcons(CC.state.lane3Icons, cooldownList, showL3 and panelUp, false, true)
end
