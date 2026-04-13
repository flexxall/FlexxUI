local _, ns = ...
local CC = ns.CombatCenter
local C = CC.const

--- Lane 3: "extended" CDs use `minSec` (DB). Never use raw `>=` on durations/remain — Retail taints break comparisons.
local function Lane3ClassifiesMajorDuration(spellID, sDuration, minSec)
  local floor = C.LANE3_MIN_SPELL_CD_DURATION
  if type(minSec) ~= "number" or minSec ~= minSec then minSec = 8 end
  if minSec < floor then minSec = floor end
  if CC.SafeNumberGte(sDuration, minSec) then return true end
  if not spellID then return false end
  if C_Spell and C_Spell.GetSpellCooldownDuration then
    local ok2, durObj = pcall(C_Spell.GetSpellCooldownDuration, spellID)
    if ok2 and durObj then
      local ok3, total = pcall(function()
        if durObj.GetTotalDuration then return durObj:GetTotalDuration() end
        if durObj.GetCooldownDuration then return durObj:GetCooldownDuration() end
        return nil
      end)
      if ok3 and CC.SafeNumberGte(total, minSec) then
        return true
      end
    end
  end
  return false
end

--- When C_Spell merge reports 0 duration, bar slot cooldown can still be authoritative (Retail 12+ table API or legacy returns).
local function ActionBarCooldownForLane3(slot, now)
  if not slot then return nil end
  local st, du, en, mr
  if C_ActionBar and C_ActionBar.GetActionCooldown then
    local ok, info = pcall(C_ActionBar.GetActionCooldown, slot)
    if ok and type(info) == "table" then
      st = info.startTime
      du = info.duration
      en = info.isEnabled ~= false
      mr = 1
      pcall(function()
        local m = info.modRate
        if type(m) == "number" and m == m and m > 0 then mr = m end
      end)
    end
  end
  if st == nil and GetActionCooldown then
    local ok, s, d, e, m = pcall(GetActionCooldown, slot)
    if ok and s ~= nil and d ~= nil then
      st, du = s, d
      en = (e ~= 0)
      mr = 1
      pcall(function()
        if type(m) == "number" and m == m and m > 0 then mr = m end
      end)
    end
  end
  if st == nil or du == nil then return nil end
  local rem = CC.CooldownRemain(st, du, now)
  if not CC.SafeNumberGt(rem, 0.05) then return nil end
  return st, du, en ~= false, mr or 1, rem
end

--- Action bar only (no full spellbook — avoids fishing, professions, random book entries).
--- Prefer spells *not* on the rotation row when sorting; then fill from the rest of the bar by remaining time.
local function BuildLane3CooldownList(all, spellSlot, rotationList)
  local db = CC.DB()
  local now = GetTime and GetTime() or 0
  local cd = {}
  local seenCd = {}
  local floor = C.LANE3_MIN_SPELL_CD_DURATION
  local minSec = tonumber(db.lane3MinCooldownSeconds)
  if minSec == nil or minSec ~= minSec then minSec = 8 end
  if minSec < floor then minSec = floor end
  local icons3 = C.ICONS_LANE3

  local rotIds = {}
  if type(rotationList) == "table" then
    for _, e in ipairs(rotationList) do
      if e and type(e.spellID) == "number" then
        rotIds[e.spellID] = true
      end
    end
  end

  local function tryAdd(sid, texOverride, actionSlotOpt)
    if not sid or type(sid) ~= "number" or seenCd[sid] then return end
    if IsPassiveSpell then
      local okP, passive = pcall(IsPassiveSpell, sid)
      if okP and passive then return end
    end
    local st, du, en, mr
    if actionSlotOpt then
      st, du, en, mr = CC.CooldownForRotationIcon(sid, actionSlotOpt)
    else
      st, du, en, mr = CC.SpellCooldown(sid)
    end
    local remain = CC.CooldownRemain(st, du, now)
    if remain == nil and sid then
      remain = CC.LegacyRemainSeconds(sid)
    end
    if actionSlotOpt and not CC.SafeNumberGt(remain, 0.05) then
      local ast, adu, aen, amr, arem = ActionBarCooldownForLane3(actionSlotOpt, now)
      if CC.SafeNumberGt(arem, 0.05) then
        st, du, en, mr, remain = ast, adu, aen, amr, arem
      end
    end
    if actionSlotOpt and CC.SafeNumberGt(remain, 0.05) then
      local okDu = false
      pcall(function()
        okDu = type(du) == "number" and du > 0.0001
      end)
      if not okDu then
        local ast, adu, aen, amr, arem = ActionBarCooldownForLane3(actionSlotOpt, now)
        if CC.SafeNumberGt(arem, 0.05) then
          st, du, en, mr, remain = ast, adu, aen, amr, arem
        end
      end
    end
    --- Prefer slot cooldown when it shows more time left (Retail often masks spell-side duration).
    if actionSlotOpt then
      local ast, adu, aen, amr, arem = ActionBarCooldownForLane3(actionSlotOpt, now)
      if ast and CC.SafeNumberGt(arem, 0.05) then
        if not CC.SafeNumberGt(remain, 0.05) or CC.SafeNumberGt(arem, remain) then
          st, du, en, mr, remain = ast, adu, aen, amr, arem
        end
      end
    end
    if not CC.SafeNumberGt(remain, 0.05) then return end

    local major = Lane3ClassifiesMajorDuration(sid, du, minSec)
    --- Remaining time is often the only reliable signal when duration is masked or secret.
    if not major then
      major = CC.SafeNumberGte(remain, minSec)
    end
    if not major then return end

    seenCd[sid] = true
    local tex = texOverride or CC.TextureFromActionSlot(actionSlotOpt) or CC.SpellIcon(sid)
    cd[#cd + 1] = {
      remain = remain,
      inRotation = rotIds[sid] and true or false,
      entry = {
        spellID = sid,
        actionSlot = actionSlotOpt,
        texture = tex,
        startTime = st,
        duration = du,
        enabled = en,
        modRate = mr,
      },
    }
  end

  for _, entry in ipairs(all) do
    if entry.spellID then
      tryAdd(entry.spellID, entry.texture, entry.actionSlot)
    end
  end
  if type(db.extraCooldownSpellIDs) == "table" then
    for _, sid in ipairs(db.extraCooldownSpellIDs) do
      if type(sid) == "number" then
        tryAdd(sid, nil, spellSlot and spellSlot[sid])
      end
    end
  end

  table.sort(cd, function(a, b)
    local ar = a.inRotation and 1 or 0
    local br = b.inRotation and 1 or 0
    if ar ~= br then return ar < br end
    return (a.remain or 0) > (b.remain or 0)
  end)
  local cooldowns = {}
  for i = 1, math.min(icons3, #cd) do
    cooldowns[#cooldowns + 1] = cd[i].entry
  end
  return cooldowns
end

CC.BuildLane3CooldownList = BuildLane3CooldownList
