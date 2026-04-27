local _, ns = ...
local CC = ns.CombatCenter
local C = CC.const
local LANE3_MIN_SPELL_CD_DURATION = C.LANE3_MIN_SPELL_CD_DURATION
local ROTATION_LONG_CD_MIN_DURATION = C.ROTATION_LONG_CD_MIN_DURATION

local SpellCooldown
local SpellIcon

local function DB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if type(_G.FlexxUIDB.combatCenter) ~= "table" then
    _G.FlexxUIDB.combatCenter = {}
  end
  local db = _G.FlexxUIDB.combatCenter
  --- Fill missing keys (empty table after coercion skips one-shot ApplyDefaults at login).
  local defs = ns.DB and ns.DB.Defaults and ns.DB.Defaults.combatCenter
  if defs and ns.DB.ApplyDefaults then
    ns.DB.ApplyDefaults(db, defs)
  end
  if db.enabled == nil then
    db.enabled = true
  end
  if db.onlyInCombat == nil then
    db.onlyInCombat = false
  end
  if db.iconDesaturateUnusable == nil then db.iconDesaturateUnusable = true end
  if db.iconShowCooldownSwipe == nil then db.iconShowCooldownSwipe = true end
  if db.iconUnusableAlpha == nil then db.iconUnusableAlpha = 0.65 end
  if db.iconUsableAlpha == nil then db.iconUsableAlpha = 1 end
  if db.lane3MinCooldownSeconds == nil then db.lane3MinCooldownSeconds = 8 end
  if db.showPrimaryLane == nil then
    db.showPrimaryLane = true
  end
  --- Runtime safety for revamp migration: ensure lane 2 starts visible once.
  if db._lane2RevampVisibilityMigrated ~= true then
    db.showPrimaryLane = true
    db._lane2RevampVisibilityMigrated = true
  end
  if type(db.lane1OffsetX) ~= "number" then db.lane1OffsetX = 0 end
  if type(db.lane1OffsetY) ~= "number" then db.lane1OffsetY = 0 end
  if type(db.lane2OffsetX) ~= "number" then db.lane2OffsetX = 0 end
  if type(db.lane2OffsetY) ~= "number" then db.lane2OffsetY = 0 end
  return db
end

--- modRate may be a secret number; comparisons outside pcall can error (tainted value).
local function SanitizeCooldownModRate(m)
  if m == nil then return 1 end
  local ok, result = pcall(function()
    if type(m) ~= "number" or m ~= m or m <= 0 then return 1 end
    return m
  end)
  if ok then return result end
  return m
end

--- WoW 12+: global GetActionCooldown may be absent; C_ActionBar.GetActionCooldown returns a table (LibActionButton pattern).
local function ActionCooldown(slot)
  if not slot then return 0, 0, true, 1 end
  if C_ActionBar and C_ActionBar.GetActionCooldown then
    local ok, info = pcall(C_ActionBar.GetActionCooldown, slot)
    if ok and type(info) == "table" then
      local st = info.startTime
      local du = info.duration
      local en = info.isEnabled ~= false
      local m = SanitizeCooldownModRate(info.modRate)
      return st, du, en, m
    end
  end
  if GetActionCooldown then
    local ok, s, d, e, m = pcall(GetActionCooldown, slot)
    if not ok then return 0, 0, true, 1 end
    return s, d, (e ~= 0), SanitizeCooldownModRate(m)
  end
  return 0, 0, true, 1
end

--- True only when we can *read* duration as finished (~0). If comparisons fail (secrets), not inactive â€” avoids clear/set flicker.
local function CooldownPlainInactive(duration)
  if duration == nil then return true end
  local ok, dead = pcall(function()
    return type(duration) == "number" and duration <= 0.0001
  end)
  if ok then return dead end
  return false
end

--- Compare last applied cooldown params without stringifying (tostring on secrets taints).
--- If == fails (secrets), treat as unchanged so we do not spam SetCooldown every tick.
local function CooldownTripleUnchanged(st, du, mo, last)
  if not last or last.st == nil then return false end
  local ok, same = pcall(function()
    return st == last.st and du == last.du and mo == last.mo
  end)
  if ok then return same end
  return true
end

--- Seconds until cooldown ends, or nil if arithmetic is not allowed (secret values).
--- Do not treat failure as 0 â€” that hides GCD/spell swipes while duration is still active.
local function CooldownRemain(startTime, duration, now)
  now = now or (GetTime and GetTime() or 0)
  local ok, r = pcall(function()
    local x = (startTime + duration) - now
    if type(x) ~= "number" or x ~= x then return nil end
    if x < 0 then return 0 end
    return x
  end)
  if not ok then return nil end
  return r
end

--- Secret numbers cannot be compared with > / >= outside pcall (taint errors).
local function SafeNumberGt(a, b)
  if a == nil or b == nil then return false end
  local ok, v = pcall(function()
    return a > b
  end)
  return ok and v
end

local function SafeNumberGte(a, b)
  if a == nil or b == nil then return false end
  local ok, v = pcall(function()
    return a >= b
  end)
  return ok and v
end

--- Retail may use Enum.ActionType.* instead of the string names.
local function IsSpellActionKind(kind)
  if kind == "spell" then return true end
  if type(kind) == "number" and Enum and Enum.ActionType and Enum.ActionType.Spell then
    return kind == Enum.ActionType.Spell
  end
  return false
end

local function IsMacroActionKind(kind)
  if kind == "macro" then return true end
  if type(kind) == "number" and Enum and Enum.ActionType and Enum.ActionType.Macro then
    return kind == Enum.ActionType.Macro
  end
  return false
end

--- Macro bars are common; GetActionInfo returns "macro", not "spell". Resolve to a castable spell ID like the default UI.
local function SpellIDFromMacroIndex(macroIndex)
  if not macroIndex or not GetMacroSpell then return nil end
  local a, b, c = GetMacroSpell(macroIndex)
  if type(a) == "number" then return a end
  if type(b) == "number" then return b end
  if type(c) == "number" then return c end
  if type(a) == "string" and C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, a)
    if ok and type(info) == "table" and info.spellID then return info.spellID end
  end
  return nil
end

local function SpellIDFromActionSlot(slot)
  if not GetActionInfo then return nil end
  --- subType: for macros, "spell" means id is already a spell ID (same as LibActionButton GetSpellId).
  local ok, kind, id, subType = pcall(GetActionInfo, slot)
  if not ok or kind == nil then return nil end
  local idNum = tonumber(id)
  if IsSpellActionKind(kind) and idNum then
    return idNum
  end
  if IsMacroActionKind(kind) and idNum then
    if subType == "spell" then
      return idNum
    end
    return SpellIDFromMacroIndex(idNum)
  end
  return nil
end

local function RefreshSpellBookSpellIDCache()
  wipe(CC.spellBookSpellIDs)
  if not C_SpellBook or not C_SpellBook.GetNumSpellBookSkillLines then return end
  pcall(function()
    local n = C_SpellBook.GetNumSpellBookSkillLines()
    if type(n) ~= "number" or n < 1 then return end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for i = 1, n do
      local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
      if line and type(line.itemIndexOffset) == "number" and type(line.numSpellBookItems) == "number" then
        local o = line.itemIndexOffset
        for j = o + 1, o + line.numSpellBookItems do
          local info = C_SpellBook.GetSpellBookItemInfo(j, bank)
          if info and type(info.spellID) == "number" then
            CC.spellBookSpellIDs[#CC.spellBookSpellIDs + 1] = info.spellID
          end
        end
      end
    end
  end)
end

local function SpellRemainBeatsAction(sRemain, aRemain, sDuration, aDuration)
  if CooldownPlainInactive(sDuration) then return false end
  if sRemain ~= nil then
    if aRemain == nil then return SafeNumberGt(sRemain, 0) end
    return SafeNumberGt(sRemain, aRemain)
  end
  if CooldownPlainInactive(aDuration) then return true end
  local ok, pick = pcall(function()
    return type(sDuration) == "number" and type(aDuration) == "number" and sDuration > aDuration + 0.01
  end)
  return ok and pick
end

local function MergeActionAndSpellCooldown(spellID, slot)
  local now = GetTime and GetTime() or 0
  local aStart, aDuration, aEnabled, aModRate = ActionCooldown(slot)
  local sStart, sDuration, sEnabled, sModRate = SpellCooldown(spellID)
  local aRemain = CooldownRemain(aStart, aDuration, now)
  local sRemain = CooldownRemain(sStart, sDuration, now)
  local startTime, duration, enabled, modRate = aStart, aDuration, aEnabled, aModRate
  local pickSpell = false
  pcall(function()
    pickSpell = SpellRemainBeatsAction(sRemain, aRemain, sDuration, aDuration)
  end)
  if pickSpell then
    startTime, duration, enabled, modRate = sStart, sDuration, sEnabled, sModRate
  end
  return startTime, duration, enabled, modRate
end

local function CooldownForRotationIcon(spellID, slot)
  if not spellID or not slot then
    return SpellCooldown(spellID)
  end
  return MergeActionAndSpellCooldown(spellID, slot)
end

--- Lane 3 / default: hide Blizzard center numbers (we draw remain on FontString). Rotation lane: show center numbers.
local function ApplyCooldownNumberVisibility(cd)
  if not cd or not cd.SetHideCountdownNumbers then return end
  if cd._flexxUseBlizzardCenterCooldownNumbers then
    cd:SetHideCountdownNumbers(false)
  else
    cd:SetHideCountdownNumbers(true)
  end
end

local function StripCooldownTemplateBorder(cd)
  if not cd then return end
  pcall(function()
    for _, region in ipairs({ cd:GetRegions() }) do
      if region:IsObjectType("Texture") then
        local hide = false
        local rname = region:GetName()
        if rname and rname:lower():find("border", 1, true) then
          hide = true
        end
        local tex = region:GetTexture()
        if type(tex) == "string" then
          local tl = tex:lower()
          if tl:find("border", 1, true) or tl:find("quickslot2", 1, true) then
            hide = true
          end
        end
        if hide then
          region:Hide()
        end
      end
    end
  end)
end

local function ApplyIconCooldownSwipe(cd, startTime, duration, modRate)
  if not cd then return end
  local m = SanitizeCooldownModRate(modRate)
  if CooldownPlainInactive(duration) then
    pcall(function()
      if cd.Clear then
        cd:Clear()
      else
        cd:SetCooldown(0, 0)
      end
    end)
    return
  end
  pcall(function()
    if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
    if cd.SetDrawEdge then cd:SetDrawEdge(true) end
    ApplyCooldownNumberVisibility(cd)
    cd:Show()
  end)
  local ok = pcall(function()
    cd:SetCooldown(startTime, duration, m)
  end)
  if ok then return end
  if CooldownFrame_SetCooldown then
    ok = pcall(function()
      CooldownFrame_SetCooldown(cd, startTime, duration, m)
    end)
    if ok then return end
    pcall(function()
      CooldownFrame_SetCooldown(cd, startTime, duration, true, m)
    end)
  end
end

local function ClearLaneCooldownVisual(cd)
  if not cd then return end
  pcall(function()
    ApplyCooldownNumberVisibility(cd)
    if cd.Clear then
      cd:Clear()
    else
      cd:SetCooldown(0, 0)
    end
  end)
end

local function LegacyRemainSeconds(spellID)
  if not spellID or not GetSpellCooldown then return nil end
  local ok, s, d = pcall(GetSpellCooldown, spellID)
  if not ok or type(s) ~= "number" or type(d) ~= "number" or d <= 0 then return nil end
  local now = GetTime and GetTime() or 0
  return math.max(0, s + d - now)
end

--- Standard spell used to read global cooldown remaining (same as many UIs).
local GCD_TRACKER_SPELL_ID = 61304

local function GetGcdRemain(now)
  now = now or (GetTime and GetTime() or 0)
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, GCD_TRACKER_SPELL_ID)
    if ok and type(info) == "table" and not CooldownPlainInactive(info.duration) then
      return CooldownRemain(info.startTime, info.duration, now)
    end
  end
  if GetSpellCooldown then
    local ok2, s, d = pcall(GetSpellCooldown, GCD_TRACKER_SPELL_ID)
    if ok2 and type(s) == "number" and type(d) == "number" and not CooldownPlainInactive(d) then
      return CooldownRemain(s, d, now)
    end
  end
  return nil
end

--- Slot/spell on cooldown; checks action, C_Spell, then merged legacy (do not trust isActive==false alone).
local function CooldownApiActive(spellID, actionSlot, legacyDuration)
  if actionSlot and C_ActionBar and C_ActionBar.GetActionCooldown then
    local ok, info = pcall(C_ActionBar.GetActionCooldown, actionSlot)
    if ok and type(info) == "table" then
      if info.isActive == true then return true end
      if not CooldownPlainInactive(info.duration) then return true end
    end
  end
  if spellID and C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(info) == "table" then
      if info.isActive == true then return true end
      if not CooldownPlainInactive(info.duration) then return true end
    end
  end
  return not CooldownPlainInactive(legacyDuration)
end

--- Uses SetCooldownFromDurationObject when supported (Retail secret cooldowns).
local function ApplyCooldownToIcon(cd, spellID, actionSlot, startTime, duration, modRate)
  if not cd then return end
  if cd.SetCooldownFromDurationObject then
    if actionSlot and C_ActionBar and C_ActionBar.GetActionCooldown and C_ActionBar.GetActionCooldownDuration then
      local ok, info = pcall(C_ActionBar.GetActionCooldown, actionSlot)
      local ok2, durObj = pcall(C_ActionBar.GetActionCooldownDuration, actionSlot)
      local showCd = false
      if ok and type(info) == "table" and info.isActive ~= false then
        showCd = info.isActive == true or not CooldownPlainInactive(info.duration)
      end
      if showCd and ok2 and durObj then
        pcall(function()
          cd:SetDrawSwipe(true)
          if cd.SetDrawEdge then cd:SetDrawEdge(true) end
          ApplyCooldownNumberVisibility(cd)
          cd:Show()
          cd:SetCooldownFromDurationObject(durObj)
        end)
        return
      end
    end
    if spellID and C_Spell and C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldownDuration then
      local ok, sinfo = pcall(C_Spell.GetSpellCooldown, spellID)
      local ok2, durObj = pcall(C_Spell.GetSpellCooldownDuration, spellID)
      local showCd = false
      if ok and type(sinfo) == "table" and sinfo.isActive ~= false then
        showCd = sinfo.isActive == true or not CooldownPlainInactive(sinfo.duration)
      end
      if showCd and ok2 and durObj then
        pcall(function()
          cd:SetDrawSwipe(true)
          if cd.SetDrawEdge then cd:SetDrawEdge(true) end
          ApplyCooldownNumberVisibility(cd)
          cd:Show()
          cd:SetCooldownFromDurationObject(durObj)
        end)
        return
      end
    end
    ClearLaneCooldownVisual(cd)
    return
  end
  ApplyIconCooldownSwipe(cd, startTime, duration, modRate)
end

--- Stance/possess/stealth/druid form abilities live on the bonus bar (73â€“84). Scanning 1â€“120 in order
--- always filled rotation lane from main bars first, so cat/bear/stealth bars never appeared.
local BONUS_BAR_FIRST, BONUS_BAR_LAST = 73, 84

local function BonusBarActive()
  local fn = _G.GetBonusBarOffset
  if not fn then return false end
  local ok, off = pcall(fn)
  return ok and type(off) == "number" and off > 0
end

--- Same pixels the default action bar uses; works for spell, macro, and flyout when spell texture API fails.
local function TextureFromActionSlot(slot)
  if not slot or not GetActionTexture then return nil end
  local ok, tex = pcall(GetActionTexture, slot)
  if ok and tex and tex ~= "" then return tex end
  return nil
end

--- First bar slot index for each spell ID (bonus bar + 1â€“120 order matches CollectActionBarEntries).
local function BuildSpellToSlotMap()
  local map = {}
  local function note(slot)
    local sid = SpellIDFromActionSlot(slot)
    if sid and map[sid] == nil then
      map[sid] = slot
    end
  end
  if BonusBarActive() then
    for slot = BONUS_BAR_FIRST, BONUS_BAR_LAST do
      note(slot)
    end
  end
  for slot = 1, 120 do
    note(slot)
  end
  return map
end

local function CollectActionBarEntries()
  local out = {}
  if not GetActionInfo then return out end
  local seenSpell = {}

  local function considerSlot(slot)
    local sid = SpellIDFromActionSlot(slot)
    if sid and type(sid) == "number" and not seenSpell[sid] then
      seenSpell[sid] = true
      local tex = TextureFromActionSlot(slot) or SpellIcon(sid)
      local startTime, duration, enabled, modRate = MergeActionAndSpellCooldown(sid, slot)
      out[#out + 1] = {
        spellID = sid,
        --- First bar slot for this spell â€” used every refresh for live GetActionCooldown (same as other addons).
        actionSlot = slot,
        texture = tex,
        startTime = startTime,
        duration = duration,
        enabled = enabled,
        modRate = modRate,
      }
    end
  end

  if BonusBarActive() then
    for slot = BONUS_BAR_FIRST, BONUS_BAR_LAST do
      considerSlot(slot)
    end
  end
  for slot = 1, 120 do
    considerSlot(slot)
  end
  return out
end

--- When spell API reports ~0 duration but the cooldown is still active, total length may only exist on the duration object (Retail 12+).
local function SpellTotalDurationFromDurationObject(spellID)
  if not spellID or not C_Spell or not C_Spell.GetSpellCooldownDuration then return nil end
  local ok, durObj = pcall(C_Spell.GetSpellCooldownDuration, spellID)
  if not ok or not durObj then return nil end
  local total = nil
  pcall(function()
    if durObj.GetTotalDuration then total = durObj:GetTotalDuration() end
    if (type(total) ~= "number" or total <= 0.0001) and durObj.GetCooldownDuration then
      total = durObj:GetCooldownDuration()
    end
  end)
  if type(total) == "number" and total > 0.0001 then return total end
  return nil
end

--- Raw start/duration/modRate for Cooldown:SetCooldown (Retail may use secret values; keep them in pcall paths).
SpellCooldown = function(spellID)
  if not spellID then return 0, 0, true, 1 end
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(info) == "table" then
      local en = info.isEnabled ~= false
      if not CooldownPlainInactive(info.duration) then
        return info.startTime, info.duration, en, SanitizeCooldownModRate(info.modRate)
      end
      local recover = false
      pcall(function()
        if info.isActive == true then recover = true end
      end)
      if not recover then
        local okSt, stPos = pcall(function()
          return type(info.startTime) == "number" and info.startTime > 0
        end)
        if okSt and stPos then recover = true end
      end
      if recover then
        local total = SpellTotalDurationFromDurationObject(spellID)
        if total then
          local okSt, stPos = pcall(function()
            return type(info.startTime) == "number" and info.startTime > 0
          end)
          if okSt and stPos then
            return info.startTime, total, en, SanitizeCooldownModRate(info.modRate)
          end
        end
      end
    end
  end
  if GetSpellCooldown then
    local ok, s, d, e = pcall(GetSpellCooldown, spellID)
    if ok and s ~= nil and d ~= nil and not CooldownPlainInactive(d) then
      return s, d, (e ~= 0), 1
    end
  end
  return 0, 0, true, 1
end

SpellIcon = function(spellID)
  if not spellID then return nil end
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, spellID)
    if ok and tex then return tex end
  end
  if GetSpellTexture then
    local ok, tex = pcall(GetSpellTexture, spellID)
    if ok and tex then return tex end
  end
  return nil
end

--- Match the action bar: dim when the slot cannot be used (OOM, wrong form, etc.). Prefer IsUsableAction(slot) when we mirror a bar slot.
local function SpellUsableLikeActionBar(spellID, actionSlot)
  if actionSlot and IsUsableAction then
    local ok, u = pcall(IsUsableAction, actionSlot)
    if ok then
      return u and true or false
    end
  end
  if not IsUsableSpell then return true end
  local ok, usable = pcall(IsUsableSpell, spellID)
  if not ok then return true end
  return usable and true or false
end

--- Ferocious Bite â†’ Ravage (BITS) and similar: bar id stays base spell; combat log uses the override id. GetBaseSpell links them (11.1.7+).
local function GetBaseSpellIdSafe(spellId)
  if not spellId or not C_Spell or not C_Spell.GetBaseSpell then return nil end
  local ok, base = pcall(C_Spell.GetBaseSpell, spellId)
  if ok and type(base) == "number" then return base end
  return nil
end

--- Cast spell id vs bar spell id can differ (override, ranks, secondary/BITS procs). Compare via C_Spell when raw numbers differ.
local function SpellIdsMatchBarCast(barSpellId, castSpellId)
  if not barSpellId or not castSpellId then return false end
  if barSpellId == castSpellId then return true end
  if C_Spell and C_Spell.GetBaseSpell then
    local baseCast = GetBaseSpellIdSafe(castSpellId)
    if baseCast and baseCast == barSpellId then return true end
    local baseBar = GetBaseSpellIdSafe(barSpellId)
    if baseBar and baseBar == castSpellId then return true end
    if baseCast and baseBar and baseCast == baseBar then return true end
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok1, ib = pcall(C_Spell.GetSpellInfo, barSpellId)
    local ok2, ic = pcall(C_Spell.GetSpellInfo, castSpellId)
    if ok1 and ok2 and type(ib) == "table" and type(ic) == "table" then
      if ib.spellID and ic.spellID and ib.spellID == ic.spellID then return true end
      --- Secondary casts (e.g. some Ravage / proc paths) use a different numeric id but same ability name on the bar.
      local nb, nc = ib.name, ic.name
      if type(nb) == "string" and type(nc) == "string" and nb ~= "" and nb == nc then
        return true
      end
      --- Some builds expose a stable base id for variants.
      local ob = ib.originalSpellID or ib.baseSpellID
      local oc = ic.originalSpellID or ic.baseSpellID
      if type(ob) == "number" and type(oc) == "number" and ob == oc then
        return true
      end
      if type(ob) == "number" and ob == castSpellId then return true end
      if type(oc) == "number" and oc == barSpellId then return true end
    end
  end
  return false
end

local function LastCastIsInRotationRow(lastId, rotSet)
  if not rotSet then return true end
  if lastId and rotSet[lastId] then return true end
  if lastId then
    local base = GetBaseSpellIdSafe(lastId)
    if base and rotSet[base] then return true end
  end
  local lastName = CC.state.lastCastSpellName
  for sid in pairs(rotSet) do
    if lastId and SpellIdsMatchBarCast(sid, lastId) then return true end
    if lastName and C_Spell and C_Spell.GetSpellInfo then
      local ok, ib = pcall(C_Spell.GetSpellInfo, sid)
      if ok and type(ib) == "table" and type(ib.name) == "string" and ib.name == lastName then
        return true
      end
    end
  end
  return false
end

local function UpdateRotationLongCdEndCache(spellID, startTime, duration, onCd, now, remainCd)
  if not spellID then return end
  local ends = CC.state.rotationLongCdEnd
  if not ends then
    ends = {}
    CC.state.rotationLongCdEnd = ends
  end
  if ends[spellID] and now >= ends[spellID] then
    ends[spellID] = nil
  end
  if not onCd then
    ends[spellID] = nil
    return
  end
  pcall(function()
    if type(duration) == "number" and duration > LANE3_MIN_SPELL_CD_DURATION and type(startTime) == "number" then
      ends[spellID] = startTime + duration
      return
    end
  end)
  if ends[spellID] then return end
  pcall(function()
    if type(remainCd) == "number" and remainCd > LANE3_MIN_SPELL_CD_DURATION + 0.2 then
      ends[spellID] = now + remainCd
    end
  end)
end

local function SpellHasMeaningfulCooldownBeyondGcd(spellID, gcdRemain, now)
  if not spellID or not gcdRemain then return false end
  local ends = CC.state.rotationLongCdEnd
  if ends then
    local tEnd = ends[spellID]
    if tEnd and now < tEnd - 0.05 then
      return true
    end
  end
  local sStart, sDur = SpellCooldown(spellID)
  local sRem = CooldownRemain(sStart, sDur, now)
  if sRem == nil and GetSpellCooldown then
    local ok, s, d = pcall(GetSpellCooldown, spellID)
    if ok and type(s) == "number" and type(d) == "number" and d > 0 then
      sRem = math.max(0, s + d - now)
    end
  end
  if sRem ~= nil then
    return SafeNumberGt(sRem, gcdRemain + 0.12)
  end
  local leg = LegacyRemainSeconds(spellID)
  if leg ~= nil then
    return SafeNumberGt(leg, gcdRemain + 0.12)
  end
  return false
end

--- True when this icon should skip applying a fresh cooldown swipe (non-caster during a recent rotation GCD).
local function ShouldSuppressGcdOnlySwipe(spellID, now)
  now = now or (GetTime and GetTime() or 0)
  local lastId = CC.state.lastCastSpellId
  local lastAt = CC.state.lastCastAt
  local lastName = CC.state.lastCastSpellName
  if not lastAt or (now - lastAt) > 3.0 then
    return false
  end
  if not lastId and not lastName then
    return false
  end
  local rotSet = CC.state._rotationSpellIdSet
  if rotSet and not LastCastIsInRotationRow(lastId, rotSet) then
    return false
  end
  if lastId and SpellIdsMatchBarCast(spellID, lastId) then
    return false
  end
  if lastName and C_Spell and C_Spell.GetSpellInfo then
    local ok, ib = pcall(C_Spell.GetSpellInfo, spellID)
    if ok and type(ib) == "table" and type(ib.name) == "string" and ib.name == lastName then
      return false
    end
  end
  local gcdRemain = GetGcdRemain(now)
  if not gcdRemain or not SafeNumberGt(gcdRemain, 0.02) then
    return false
  end
  if SpellHasMeaningfulCooldownBeyondGcd(spellID, gcdRemain, now) then
    return false
  end
  return true
end

--- Normalize SpellChargeInfo / GetActionCharges table (Retail field names vary; bar slot is authoritative for lane 2).
local function ParseChargePairFromTable(info)
  if type(info) ~= "table" then return nil, nil end
  local mx = info.maxCharges or info.max or info.maxChargeCount
  mx = type(mx) == "number" and mx or tonumber(mx)
  if type(mx) ~= "number" or not SafeNumberGt(mx, 1) then return nil, nil end
  local cur = info.currentCharges or info.currentChargeCount or info.activeCharges or info.numCharges
  if cur == nil then cur = info.charges end
  if cur == nil then cur = info.current end
  cur = type(cur) == "number" and cur or tonumber(cur)
  return cur, mx
end

--- Action bar + spell-id charge APIs (merge: slot can report 0 current while C_Spell has the real count, or the reverse).
local function SpellChargeDisplay(spellID, actionSlot)
  local function fromSpellId(sid)
    if not sid then return nil, nil end
    if C_Spell and C_Spell.GetSpellCharges then
      local ok, info = pcall(C_Spell.GetSpellCharges, sid)
      if ok and type(info) == "table" then
        local cur, mx = ParseChargePairFromTable(info)
        if mx then return cur, mx end
      end
    end
    if GetSpellCharges then
      local ok, cur, maxC = pcall(GetSpellCharges, sid)
      if ok and type(maxC) == "number" and SafeNumberGt(maxC, 1) then
        local c = type(cur) == "number" and cur or tonumber(cur)
        return c, maxC
      end
    end
    return nil, nil
  end

  local curA, mxA
  if actionSlot then
    if C_ActionBar and C_ActionBar.GetActionCharges then
      local ok, info = pcall(C_ActionBar.GetActionCharges, actionSlot)
      if ok and type(info) == "table" then
        curA, mxA = ParseChargePairFromTable(info)
      end
    end
    if (not mxA) and GetActionCharges then
      local ok, c, m = pcall(GetActionCharges, actionSlot)
      if ok and type(m) == "number" and SafeNumberGt(m, 1) then
        curA, mxA = (type(c) == "number" and c or tonumber(c)), m
      end
    end
  end

  local curS, mxS = fromSpellId(spellID)
  if mxA and mxS and mxA == mxS then
    local okA = curA ~= nil and SafeNumberGt(curA, 0)
    local okS = curS ~= nil and SafeNumberGt(curS, 0)
    if okS and not okA then return curS, mxS end
    if okA and not okS then return curA, mxA end
    if curS ~= nil and curA == nil then return curS, mxS end
    if curA ~= nil and curS == nil then return curA, mxA end
    if curA ~= nil and curS ~= nil then
      return curA, mxA
    end
    return curA or curS, mxA
  end
  if mxA then
    if curA == nil and mxS ~= nil and mxA == mxS and curS ~= nil then
      return curS, mxA
    end
    return curA, mxA
  end
  if mxS then return curS, mxS end
  local base = GetBaseSpellIdSafe(spellID)
  if base and base ~= spellID then
    return fromSpellId(base)
  end
  return nil, nil
end

--- Charge counts may be secret (Retail). Only format via plain math + tostring inside pcall; never tostring(secret)
--- or the result stays tainted and comparisons like stackTxt ~= "0" error in UpdateLaneIcons.
local function FormatChargeStackText(cur)
  if cur == nil then return nil end
  local ok, s = pcall(function()
    local n = cur
    if type(n) ~= "number" then n = tonumber(n) end
    if type(n) ~= "number" then return nil end
    return tostring(math.max(0, math.floor(n + 0.5)))
  end)
  return ok and s or nil
end

local function FormatRemainCount(remain)
  if remain == nil then return "" end
  if SafeNumberGte(remain, 10) then
    local ok, s = pcall(function()
      return tostring(math.floor(remain + 0.5))
    end)
    return ok and s or ""
  end
  local ok, s = pcall(function()
    return string.format("%.1f", remain)
  end)
  return ok and s or ""
end

--- Multi-charge stack text: plain strings from FormatChargeStackText when possible; secret counts use SetText(raw)
--- (same idea as default action buttons). Recharge timer only when zero is detectable without tainted string compares.
local function SetLaneIconChargeAndTimerText(countFs, curCharges, maxCharges, remainCd, onCd, showSwipe, useBlizzardCenterTimer)
  if maxCharges == nil or not SafeNumberGt(maxCharges, 1) then
    return false
  end
  local stackTxt = FormatChargeStackText(curCharges)
  if stackTxt then
    if stackTxt == "0" then
      if showSwipe and onCd and SafeNumberGte(remainCd, 0.05) then
        --- Center Cooldown text handles the timer when enabled; avoid duplicating bottom-right.
        if useBlizzardCenterTimer then
          countFs:SetText("")
        else
          countFs:SetText(FormatRemainCount(remainCd))
        end
      else
        countFs:SetText("0")
      end
    else
      countFs:SetText(stackTxt)
    end
    return true
  end
  local ok0, atZero = pcall(function()
    if curCharges == nil then return false end
    local n = curCharges
    if type(n) ~= "number" then n = tonumber(n) end
    if type(n) ~= "number" then return false end
    return n <= 0
  end)
  if ok0 and atZero and showSwipe and onCd and SafeNumberGte(remainCd, 0.05) then
    if useBlizzardCenterTimer then
      countFs:SetText("")
    else
      countFs:SetText(FormatRemainCount(remainCd))
    end
    return true
  end
  if curCharges ~= nil then
    pcall(function()
      countFs:SetText(curCharges)
    end)
  else
    countFs:SetText("")
  end
  return true
end

--- opts.rotationLane: lane 2 only — strip CooldownFrameTemplate border chrome, crop icon like action buttons; use Blizzard center CD + gold swipe edge.
local function NewIcon(parent, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(40, 40)

  --- Match ActionButton: spell art on ARTWORK; Cooldown is a child with higher FrameLevel so the swipe draws on top.
  --- BACKGROUND was used to sit under the swipe, but on some builds it never composites visibly (blank lane-2 icons).
  f.icon = f:CreateTexture(nil, "ARTWORK")
  pcall(function()
    f.icon:SetDrawLayer("ARTWORK", 0)
  end)
  f.icon:SetAllPoints(f)
  if opts.rotationLane then
    pcall(function()
      f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end)
  end
  f.icon:Show()
  pcall(function() f:EnableMouse(false) end)

  f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  f.cd:SetAllPoints(f)
  if opts.rotationLane then
    f.cd._flexxUseBlizzardCenterCooldownNumbers = true
    StripCooldownTemplateBorder(f.cd)
  end
  pcall(function() f.cd:EnableMouse(false) end)
  local base = (f:GetFrameLevel() or 0)
  f.cd:SetFrameLevel(base + 50)
  pcall(function()
    f.cd:Raise()
  end)
  pcall(function()
    if f.cd.SetDrawSwipe then f.cd:SetDrawSwipe(true) end
    if f.cd.SetDrawEdge then f.cd:SetDrawEdge(true) end
    ApplyCooldownNumberVisibility(f.cd)
  end)

  --- Flexx gold font (`FlexxUIFont_FlexxGold`) or highlight + Theme RGB if Fonts API unavailable.
  if ns.Fonts and ns.Fonts.CreateFlexxGoldFontString then
    f.count = ns.Fonts.CreateFlexxGoldFontString(f, "OVERLAY", "unit")
  else
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if ns.SetFontStringFlexxGoldColor then ns.SetFontStringFlexxGoldColor(f.count) end
  end
  f.count:SetDrawLayer("OVERLAY", 7)
  f.count:SetPoint("BOTTOMRIGHT", -2, 2)
  f.count:SetText("")
  return f
end

local function PlayerInCombatForUi()
  --- Use combat APIs only — requiring a target hid the panel during AoE, target drops, and many real combat situations.
  --- Training dummies / rested areas: REGEN_ENABLED may never fire to clear this; sync when APIs say we're OOC with regen.
  if CC.state.regenCombatUi == true then
    local uac = UnitAffectingCombat and UnitAffectingCombat("player")
    local regenOn = PlayerRegenEnabled and PlayerRegenEnabled()
    --- Dummy / phasing: REGEN_ENABLED may never fire and PlayerRegenEnabled can stay false while UAC is already false.
    if (not uac) or regenOn then
      CC.state.regenCombatUi = nil
    end
  end
  --- REGEN_DISABLED sets true. Storing false on REGEN_ENABLED made every later check skip UnitAffectingCombat until REGEN fired again (bad for auto-attack entries that lag REGEN).
  if CC.state.regenCombatUi == true then
    return true
  end
  if UnitAffectingCombat and UnitAffectingCombat("player") then
    return true
  end
  --- Mirrors default UI â€œregen disabledâ€ / combat in edge cases where UAC lags (e.g. at range).
  if PlayerRegenEnabled and not PlayerRegenEnabled() then
    return true
  end
  return false
end

local function UpdateVisibility()
  local db = DB()
  local f = CC.state.frame
  if not f then return end
  if not db.enabled then f:Hide(); return end
  if db.onlyInCombat and not PlayerInCombatForUi() then
    f:Hide()
    return
  end
  f:Show()
end
--- emptySlotPlaceholders: when true (cooldown lane), show dim tiles for unused icon slots so the row is visible even with no CDs tracked.
local function UpdateLaneIcons(iconPool, spellList, laneShown, isRotationLane, emptySlotPlaceholders)
  local db = DB()
  local size = db.iconSize or 44
  local usableAlpha = db.iconUsableAlpha or 1
  local unusableAlpha = db.iconUnusableAlpha or 0.65
  local desatUnusable = db.iconDesaturateUnusable ~= false
  local showSwipe = db.iconShowCooldownSwipe ~= false
  local now = GetTime and GetTime() or 0
  for i = 1, #iconPool do
    local iconFrame = iconPool[i]
    iconFrame:SetSize(size, size)
    local entry = spellList[i]
    if laneShown and entry then
      local spellID = entry.spellID or entry
      iconFrame:Show()
      local tex = entry.texture or SpellIcon(spellID)
      if tex then
        iconFrame.icon:SetTexture(tex)
        iconFrame.icon:SetVertexColor(1, 1, 1, 1)
      else
        iconFrame.icon:SetTexture("Interface\\Buttons\\WHITE8x8")
        iconFrame.icon:SetVertexColor(0.08, 0.08, 0.10, 0.95)
      end
      -- Live cooldowns: use action-slot timing whenever we know the bar slot (lane 2 + lane 3 with slot).
      local startTime, duration, enabled, modRate
      if entry.actionSlot then
        startTime, duration, enabled, modRate = CooldownForRotationIcon(spellID, entry.actionSlot)
      else
        startTime, duration, enabled, modRate = SpellCooldown(spellID)
      end
      local remainCd = CooldownRemain(startTime, duration, now)
      if remainCd == nil and spellID then
        remainCd = LegacyRemainSeconds(spellID)
      end
      local onCd = CooldownApiActive(spellID, entry.actionSlot, duration)
      if isRotationLane and spellID then
        local ends = CC.state.rotationLongCdEnd
        if not onCd and ends and ends[spellID] and now < ends[spellID] - 0.05 then
          onCd = true
        end
        if not onCd and remainCd and SafeNumberGt(remainCd, 0.05) then
          pcall(function()
            if type(duration) == "number" and duration > LANE3_MIN_SPELL_CD_DURATION then
              onCd = true
            end
          end)
        end
      elseif not isRotationLane and spellID then
        --- Cooldown lane (lane 3): same masked-duration issue — trust remain when APIs say inactive.
        if not onCd and remainCd and SafeNumberGt(remainCd, 0.05) then
          onCd = true
        end
      end
      if isRotationLane then
        UpdateRotationLongCdEndCache(spellID, startTime, duration, onCd, now, remainCd)
      end
      local suppressGcd = false
      if isRotationLane then
        suppressGcd = ShouldSuppressGcdOnlySwipe(spellID, now)
      end
      local edgeOn = onCd and not (iconFrame._flexxWasOnCd or false)
      iconFrame._flexxWasOnCd = onCd
      local useDurationObject = iconFrame.cd and iconFrame.cd.SetCooldownFromDurationObject
      local longMergedCd = false
      pcall(function()
        longMergedCd = type(duration) == "number" and duration > ROTATION_LONG_CD_MIN_DURATION
      end)
      if showSwipe and onCd then
        local skipCdApply = suppressGcd and not longMergedCd
        if not skipCdApply then
          if useDurationObject then
            ApplyCooldownToIcon(iconFrame.cd, spellID, entry.actionSlot, startTime, duration, modRate)
          elseif edgeOn then
            iconFrame._flexxLastCd = { st = startTime, du = duration, mo = modRate }
            ApplyIconCooldownSwipe(iconFrame.cd, startTime, duration, modRate)
          elseif not CooldownTripleUnchanged(startTime, duration, modRate, iconFrame._flexxLastCd) then
            iconFrame._flexxLastCd = { st = startTime, du = duration, mo = modRate }
            ApplyIconCooldownSwipe(iconFrame.cd, startTime, duration, modRate)
          end
        end
      else
        iconFrame._flexxWasOnCd = false
        if useDurationObject then
          ClearLaneCooldownVisual(iconFrame.cd)
        elseif iconFrame._flexxLastCd then
          iconFrame._flexxLastCd = nil
          pcall(function()
            if iconFrame.cd.Clear then
              iconFrame.cd:Clear()
            else
              iconFrame.cd:SetCooldown(0, 0)
            end
          end)
        end
      end
      local curCharges, maxCharges = SpellChargeDisplay(spellID, entry.actionSlot)
      local useCenterTimer = iconFrame.cd and iconFrame.cd._flexxUseBlizzardCenterCooldownNumbers
      if not SetLaneIconChargeAndTimerText(iconFrame.count, curCharges, maxCharges, remainCd, onCd, showSwipe, useCenterTimer) then
        if showSwipe and onCd and SafeNumberGte(remainCd, 0.05) then
          if useCenterTimer then
            iconFrame.count:SetText("")
          else
            iconFrame.count:SetText(FormatRemainCount(remainCd))
          end
        else
          iconFrame.count:SetText("")
        end
      end
      if SpellUsableLikeActionBar(spellID, entry.actionSlot) then
        iconFrame.icon:SetDesaturated(false)
        iconFrame:SetAlpha(onCd and math.max(0.55, usableAlpha * 0.85) or usableAlpha)
      else
        iconFrame.icon:SetDesaturated(desatUnusable)
        iconFrame:SetAlpha(unusableAlpha)
      end
    elseif laneShown and emptySlotPlaceholders then
      iconFrame:Show()
      iconFrame._flexxLastCd = nil
      iconFrame._flexxWasOnCd = false
      iconFrame.count:SetText("")
      pcall(function()
        if iconFrame.cd and iconFrame.cd.Clear then
          iconFrame.cd:Clear()
        elseif iconFrame.cd then
          iconFrame.cd:SetCooldown(0, 0)
        end
      end)
      iconFrame.icon:SetTexture("Interface\\Buttons\\WHITE8x8")
      iconFrame.icon:SetVertexColor(0.14, 0.16, 0.20, 0.5)
      iconFrame.icon:SetDesaturated(false)
      iconFrame:SetAlpha(0.75)
    else
      iconFrame._flexxLastCd = nil
      iconFrame._flexxWasOnCd = false
      iconFrame.count:SetText("")
      pcall(function()
        if iconFrame.cd and iconFrame.cd.Clear then
          iconFrame.cd:Clear()
        elseif iconFrame.cd then
          iconFrame.cd:SetCooldown(0, 0)
        end
      end)
      iconFrame:Hide()
    end
  end
end

CC.DB = DB
CC.SpellCooldown = SpellCooldown
CC.SpellIcon = SpellIcon
CC.RefreshSpellBookSpellIDCache = RefreshSpellBookSpellIDCache
CC.CollectActionBarEntries = CollectActionBarEntries
CC.BuildSpellToSlotMap = BuildSpellToSlotMap
CC.CooldownForRotationIcon = CooldownForRotationIcon
CC.CooldownRemain = CooldownRemain
CC.LegacyRemainSeconds = LegacyRemainSeconds
CC.CooldownApiActive = CooldownApiActive
CC.SafeNumberGt = SafeNumberGt
CC.SafeNumberGte = SafeNumberGte
CC.TextureFromActionSlot = TextureFromActionSlot
CC.ClearLaneCooldownVisual = ClearLaneCooldownVisual
CC.UpdateLaneIcons = UpdateLaneIcons
CC.UpdateVisibility = UpdateVisibility
CC.NewIcon = NewIcon