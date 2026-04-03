local _, ns = ...

local CC = {}
ns.CombatCenter = CC

CC.state = CC.state or {
  frame = nil,
  lane1Wrap = nil,
  lane1Bg = nil,
  lane1 = nil,
  lane2 = nil,
  lane3 = nil,
  lane1Pips = {},
  lane2Icons = {},
  lane3Icons = {},
  updater = nil,
  --- Rotation lane: show GCD swipe only on the spell that triggered it (see ShouldSuppressGcdOnlySwipe).
  lastCastSpellId = nil,
  lastCastSpellName = nil,
  lastCastAt = nil,
}

local MAX_PIPS = 8
local ICONS_LANE2 = 8
local ICONS_LANE3 = 5
--- Pip row: height of each segment; gap between segments inside the pip bar.
local PIP_H = 5
local PIP_SEGMENT_GAP = 4
local PIP_WRAP_PAD = 3
local PIP_WRAP_BG_A = 0.34
--- Vertical gap between pip strip (wrapper bottom) and rotation row (lane2 top).
local PIP_ROTATION_GAP = 2
--- Unfilled pip slots: flat translucent dark (no gradient).
local PIP_EMPTY_R, PIP_EMPTY_G, PIP_EMPTY_B = 0.07, 0.07, 0.08
local PIP_EMPTY_A = 0.42
--- Dark end of the active gradient (fraction of class RGB). Lower = stronger shading.
local PIP_DARK_MULT = 0.82
--- Inner square must cover the pip rect when rotated (diagonal = sqrt(w²+h²)).
local PIP_INNER_SCALE = 1.08
--- Added to atan2(PIP_H,segW)-π/2 (radians). Positive = more CCW in WoW SetRotation.
local PIP_GRADIENT_ROT_BIAS = 0.12
--- Pip bar width as fraction of rotation row width (8 icons, edge-to-edge).
local PIP_BAR_WIDTH_FRAC = 0.8
--- Bottom cooldown lane: ignore GCD and other short timers (API reports GCD on many spells at once).
local LANE3_MIN_SPELL_CD_DURATION = 2.1
local SpellCooldown
local toPlainNumber
local SpellIcon
--- Cached player spellbook spell IDs (refreshed on SPELLS_CHANGED) so lane 3 can show CDs for spells not on the bar.
local spellBookSpellIDs = {}

local function DB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  _G.FlexxUIDB.combatCenter = _G.FlexxUIDB.combatCenter or {}
  local db = _G.FlexxUIDB.combatCenter
  if db.iconDesaturateUnusable == nil then db.iconDesaturateUnusable = true end
  if db.iconShowCooldownSwipe == nil then db.iconShowCooldownSwipe = true end
  if db.iconUnusableAlpha == nil then db.iconUnusableAlpha = 0.65 end
  if db.iconUsableAlpha == nil then db.iconUsableAlpha = 1 end
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

--- True only when we can *read* duration as finished (~0). If comparisons fail (secrets), not inactive — avoids clear/set flicker.
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
--- Do not treat failure as 0 — that hides GCD/spell swipes while duration is still active.
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
  wipe(spellBookSpellIDs)
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
            spellBookSpellIDs[#spellBookSpellIDs + 1] = info.spellID
          end
        end
      end
    end
  end)
end

--- Same merge as the default UI: bar slot timer vs spell timer (whichever has more time left).
local function MergeActionAndSpellCooldown(spellID, slot)
  local now = GetTime and GetTime() or 0
  local aStart, aDuration, aEnabled, aModRate = ActionCooldown(slot)
  local sStart, sDuration, sEnabled, sModRate = SpellCooldown(spellID)
  local aRemain = CooldownRemain(aStart, aDuration, now)
  local sRemain = CooldownRemain(sStart, sDuration, now)
  local startTime, duration, enabled, modRate = aStart, aDuration, aEnabled, aModRate
  local pickSpell = false
  pcall(function()
    pickSpell = (sRemain > aRemain) and (not CooldownPlainInactive(sDuration))
  end)
  if pickSpell then
    startTime, duration, enabled, modRate = sStart, sDuration, sEnabled, sModRate
  end
  return startTime, duration, enabled, modRate
end

--- First icon row below the pips ("rotation" lane): match the default **action button** on that slot, then merge/spell.
--- Using merge-only here often hid swipes because spell vs action timers disagreed.
local function CooldownForRotationIcon(spellID, slot)
  if not spellID or not slot then
    return SpellCooldown(spellID)
  end
  local aStart, aDuration, aEnabled, aModRate = ActionCooldown(slot)
  local now = GetTime and GetTime() or 0
  local aRemain = CooldownRemain(aStart, aDuration, now)
  --- Prefer slot timing whenever the button reports an active timer (GCD or spell CD), even if remain is secret.
  if (not CooldownPlainInactive(aDuration)) and (aRemain == nil or SafeNumberGt(aRemain, 0)) then
    return aStart, aDuration, aEnabled, aModRate
  end
  return MergeActionAndSpellCooldown(spellID, slot)
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
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
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

--- Retail (build ~66562+): numeric SetCooldown no longer drives the swipe for secret cooldowns.
--- Match LibActionButton: Cooldown:SetCooldownFromDurationObject + C_ActionBar / C_Spell duration APIs.
local function ClearLaneCooldownVisual(cd)
  if not cd then return end
  pcall(function()
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    if cd.Clear then
      cd:Clear()
    else
      cd:SetCooldown(0, 0)
    end
  end)
end

--- Seconds for overlay text when legacy GetSpellCooldown still returns numbers (optional).
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

--- Whether the slot or spell reports an active cooldown (secret-safe fields when present).
local function CooldownApiActive(spellID, actionSlot, legacyDuration)
  if actionSlot and C_ActionBar and C_ActionBar.GetActionCooldown then
    local ok, info = pcall(C_ActionBar.GetActionCooldown, actionSlot)
    if ok and type(info) == "table" then
      if info.isActive == true then return true end
      if info.isActive == false then return false end
      if not CooldownPlainInactive(info.duration) then return true end
    end
  end
  if spellID and C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(info) == "table" then
      if info.isActive == true then return true end
      if info.isActive == false then return false end
      if not CooldownPlainInactive(info.duration) then return true end
    end
  end
  return not CooldownPlainInactive(legacyDuration)
end

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
          cd:SetHideCountdownNumbers(true)
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
          cd:SetHideCountdownNumbers(true)
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

--- Stance/possess/stealth/druid form abilities live on the bonus bar (73–84). Scanning 1–120 in order
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

--- First bar slot index for each spell ID (bonus bar + 1–120 order matches CollectActionBarEntries).
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
        --- First bar slot for this spell — used every refresh for live GetActionCooldown (same as other addons).
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

local function BuildLiveLaneSpellLists()
  local all = CollectActionBarEntries()
  local spellSlot = BuildSpellToSlotMap()
  local rotation = {}
  local cooldowns = {}
  local db = DB()

  for i = 1, math.min(ICONS_LANE2, #all) do
    rotation[#rotation + 1] = all[i]
  end

  local now = GetTime and GetTime() or 0
  local cd = {}
  local seenCd = {}

  local function tryAddLane3Cooldown(sid, texOverride, actionSlotOpt)
    if not sid or type(sid) ~= "number" or seenCd[sid] then return end
    local sStart, sDuration, sEnabled, sModRate
    if actionSlotOpt then
      sStart, sDuration, sEnabled, sModRate = CooldownForRotationIcon(sid, actionSlotOpt)
    else
      sStart, sDuration, sEnabled, sModRate = SpellCooldown(sid)
    end
    local remain = CooldownRemain(sStart, sDuration, now)
    local longEnough = false
    pcall(function()
      longEnough = type(sDuration) == "number" and sDuration >= LANE3_MIN_SPELL_CD_DURATION
    end)
    if longEnough and SafeNumberGt(remain, 0.05) then
      seenCd[sid] = true
      local tex = texOverride or TextureFromActionSlot(actionSlotOpt) or SpellIcon(sid)
      cd[#cd + 1] = {
        remain = remain,
        entry = {
          spellID = sid,
          actionSlot = actionSlotOpt,
          texture = tex,
          startTime = sStart,
          duration = sDuration,
          enabled = sEnabled,
          modRate = sModRate,
        },
      }
    end
  end

  for _, entry in ipairs(all) do
    if entry.spellID then
      tryAddLane3Cooldown(entry.spellID, entry.texture, entry.actionSlot)
    end
  end

  -- Known spells on cooldown even if not placed on an action bar (e.g. Barkskin off-bar).
  for _, sid in ipairs(spellBookSpellIDs) do
    tryAddLane3Cooldown(sid, nil, spellSlot[sid])
  end

  if type(db.extraCooldownSpellIDs) == "table" then
    for _, sid in ipairs(db.extraCooldownSpellIDs) do
      if type(sid) == "number" then
        tryAddLane3Cooldown(sid, nil, spellSlot[sid])
      end
    end
  end

  table.sort(cd, function(a, b)
    return (a.remain or 0) > (b.remain or 0)
  end)
  for i = 1, math.min(ICONS_LANE3, #cd) do
    cooldowns[#cooldowns + 1] = cd[i].entry
  end
  return rotation, cooldowns
end

--- GetSpellCooldown / C_Spell may return secret numbers; never return them (no arithmetic/compare on secrets).
toPlainNumber = function(v)
  if v == nil then return 0 end
  local function coerce(x)
    if x == nil then return 0 end
    local ok, n = pcall(function()
      return tonumber(string.format("%.10f", x))
    end)
    if ok and type(n) == "number" and n == n then return n end
    ok, n = pcall(function()
      return tonumber(tostring(x))
    end)
    if ok and type(n) == "number" and n == n then return n end
    return 0
  end
  if type(v) == "number" then
    return coerce(v)
  end
  local ok, s = pcall(string.format, "%.10f", v)
  if ok and s then
    local n = tonumber(s)
    if n and n == n then return n end
  end
  ok, s = pcall(tostring, v)
  if ok and s then
    local n = tonumber(s)
    if n and n == n then return n end
  end
  return 0
end

--- Raw start/duration/modRate for Cooldown:SetCooldown (Retail secret values must not pass through toPlainNumber).
--- If C_Spell reports no active duration, fall back to GetSpellCooldown.
SpellCooldown = function(spellID)
  if not spellID then return 0, 0, true, 1 end
  if C_Spell and C_Spell.GetSpellCooldown then
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(info) == "table" then
      local en = info.isEnabled ~= false
      if not CooldownPlainInactive(info.duration) then
        return info.startTime, info.duration, en, SanitizeCooldownModRate(info.modRate)
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

--- Ferocious Bite → Ravage (BITS) and similar: bar id stays base spell; combat log uses the override id. GetBaseSpell links them (11.1.7+).
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

--- Spell has cooldown remaining clearly longer than the GCD sweep (own CD, not gcd-only on that icon).
local function SpellHasMeaningfulCooldownBeyondGcd(spellID, gcdRemain, now)
  if not spellID or not gcdRemain then return false end
  local sStart, sDur = SpellCooldown(spellID)
  local sRem = CooldownRemain(sStart, sDur, now)
  if sRem ~= nil then
    return SafeNumberGt(sRem, gcdRemain + 0.12)
  end
  if GetSpellCooldown then
    local ok, s, d = pcall(GetSpellCooldown, spellID)
    if ok and type(s) == "number" and type(d) == "number" and d > 0 then
      local rem = math.max(0, s + d - now)
      return SafeNumberGt(rem, gcdRemain + 0.12)
    end
  end
  return false
end

--- Rotation lane: show GCD swipe only on the spell you just cast. (Old slotRemain≈gcdRemain failed with secret values.)
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

local function SpellChargeDisplay(spellID)
  if not spellID then return nil, nil end
  if C_Spell and C_Spell.GetSpellCharges then
    local ok, info = pcall(C_Spell.GetSpellCharges, spellID)
    if ok and type(info) == "table" then
      local isMulti, cur, mx = false, nil, nil
      pcall(function()
        local m = info.maxCharges
        if m == nil then return end
        if m > 1 then
          isMulti = true
          cur, mx = info.currentCharges, m
        end
      end)
      if isMulti then return cur, mx end
    end
  end
  if GetSpellCharges then
    local ok, cur, maxC = pcall(GetSpellCharges, spellID)
    if ok then
      local isMulti = false
      pcall(function()
        if maxC == nil then return end
        if maxC > 1 then isMulti = true end
      end)
      if isMulti then return cur, maxC end
    end
  end
  return nil, nil
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

local function NewIcon(parent)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(40, 40)

  --- Match ActionButton: spell art on ARTWORK; Cooldown is a child with higher FrameLevel so the swipe draws on top.
  --- BACKGROUND was used to sit under the swipe, but on some builds it never composites visibly (blank lane-2 icons).
  f.icon = f:CreateTexture(nil, "ARTWORK")
  pcall(function()
    f.icon:SetDrawLayer("ARTWORK", 0)
  end)
  f.icon:SetAllPoints(f)
  f.icon:Show()

  f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
  f.cd:SetAllPoints(f)
  local base = (f:GetFrameLevel() or 0)
  f.cd:SetFrameLevel(base + 50)
  pcall(function()
    f.cd:Raise()
  end)
  pcall(function()
    if f.cd.SetDrawSwipe then f.cd:SetDrawSwipe(true) end
    --- Gold leading edge on the sweep (same toggle as default action buttons).
    if f.cd.SetDrawEdge then f.cd:SetDrawEdge(true) end
    if f.cd.SetHideCountdownNumbers then f.cd:SetHideCountdownNumbers(true) end
  end)

  f.count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.count:SetDrawLayer("OVERLAY", 7)
  f.count:SetPoint("BOTTOMRIGHT", -2, 2)
  f.count:SetText("")
  return f
end

local function UpdateVisibility()
  local db = DB()
  local f = CC.state.frame
  if not f then return end
  if not db.enabled then f:Hide(); return end
  if db.onlyInCombat and not UnitAffectingCombat("player") then
    f:Hide()
    return
  end
  f:Show()
end

local function ApplyPipInactiveFlat(tex)
  tex:SetTexture("Interface\\Buttons\\WHITE8x8")
  if tex.SetRotation then
    pcall(function()
      tex:SetRotation(0)
    end)
  end
  tex:SetVertexColor(PIP_EMPTY_R, PIP_EMPTY_G, PIP_EMPTY_B, PIP_EMPTY_A)
end

--- VERTICAL: bottom = class, top = darker. Rotation maps texture +Y (dark) toward holder top-right; + class at bottom-left.
local function ApplyPipActiveGradient(tex, r, g, b, rotRad)
  tex:SetTexture("Interface\\Buttons\\WHITE8x8")
  tex:SetVertexColor(1, 1, 1, 1)
  if tex.SetRotation then
    pcall(function()
      tex:SetRotation(0)
    end)
  end
  local dm = PIP_DARK_MULT
  local lr, lg, lb = r, g, b
  local dr, dg, db = r * dm, g * dm, b * dm
  local a = 1
  local ok = false
  if CreateColor and tex.SetGradient then
    ok = pcall(function()
      tex:SetGradient("VERTICAL", CreateColor(lr, lg, lb, a), CreateColor(dr, dg, db, a))
    end)
  end
  if not ok then
    tex:SetVertexColor((lr + dr) * 0.5, (lg + dg) * 0.5, (lb + db) * 0.5, a)
    return
  end
  if tex.SetRotation then
    local rad = rotRad
    local okRot = pcall(function()
      tex:SetRotation(rad, { x = 0.5, y = 0.5 })
    end)
    if not okRot then
      pcall(function()
        tex:SetRotation(rad)
      end)
    end
  end
end

local function SecondaryPowerTypeColor(pt)
  if Enum and Enum.PowerType then
    local E = Enum.PowerType
    if pt == E.HolyPower then return 0.95, 0.82, 0.32 end
    if pt == E.ComboPoints then return 0.92, 0.20, 0.18 end
    if pt == E.Chi then return 0.38, 0.90, 0.82 end
    if pt == E.SoulShards then return 0.60, 0.32, 0.95 end
    if pt == E.ArcaneCharges then return 0.82, 0.44, 0.95 end
    if pt == E.Essence then return 0.32, 0.78, 0.98 end
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

local function RepositionPips(n, filled, pt)
  local lane = CC.state.lane1
  if not lane then return end
  local barW = lane:GetWidth()
  if not barW or barW <= 0 then return end
  if n <= 0 then
    for i = 1, MAX_PIPS do
      local slot = CC.state.lane1Pips[i]
      if slot and slot.holder then
        slot.holder:Hide()
      end
    end
    return
  end
  local gap = PIP_SEGMENT_GAP
  local totalGap = (n - 1) * gap
  local segW = (barW - totalGap) / n
  if segW < 2 then segW = 2 end
  local r, g, b = SecondaryPowerTypeColor(pt)
  local laneH = lane:GetHeight() or (PIP_H + 2)
  local y = math.max(0, (laneH - PIP_H) / 2)
  for i = 1, MAX_PIPS do
    local slot = CC.state.lane1Pips[i]
    if not slot or not slot.holder or not slot.tex then
      -- Corrupt state; skip until reload recreates frames.
    elseif i <= n then
      local holder, tex = slot.holder, slot.tex
      holder:Show()
      holder:SetSize(segW, PIP_H)
      holder:ClearAllPoints()
      holder:SetPoint("LEFT", lane, "LEFT", (i - 1) * (segW + gap), y)
      if i <= filled then
        local inner = math.max(PIP_H, math.sqrt(segW * segW + PIP_H * PIP_H) * PIP_INNER_SCALE)
        tex:SetSize(inner, inner)
        tex:ClearAllPoints()
        tex:SetPoint("CENTER", holder, "CENTER", 0, 0)
        -- Angle so unrotated +Y (dark end) aligns with direction center → top-right of segment.
        local rotRad = math.atan2(PIP_H, segW) - (math.pi / 2) + PIP_GRADIENT_ROT_BIAS
        ApplyPipActiveGradient(tex, r, g, b, rotRad)
      else
        tex:SetSize(segW, PIP_H)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
        ApplyPipInactiveFlat(tex)
      end
    else
      slot.holder:Hide()
    end
  end
end

local function UpdateLane1()
  local db = DB()
  local lane = CC.state.lane1
  local wrap = CC.state.lane1Wrap
  if not lane or not wrap then return end
  wrap:SetShown(db.showResourceLane ~= false)
  if not wrap:IsShown() then return end

  local pt, cur, mx = nil, 0, 0
  if ns.UnitFrames and ns.UnitFrames.GetSecondaryPowerValues then
    pt, cur, mx = ns.UnitFrames.GetSecondaryPowerValues("player")
  end
  if not pt or mx <= 0 then
    for i = 1, MAX_PIPS do
      local slot = CC.state.lane1Pips[i]
      if slot and slot.holder then
        slot.holder:Hide()
      end
    end
    return
  end
  local n = math.min(MAX_PIPS, math.max(1, math.floor(mx + 0.5)))
  local filled = math.min(n, math.max(0, math.floor(cur + 1e-3)))
  RepositionPips(n, filled, pt)
end

local function UpdateLaneIcons(iconPool, spellList, laneShown, isRotationLane)
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
      local suppressGcd = false
      if isRotationLane then
        suppressGcd = ShouldSuppressGcdOnlySwipe(spellID, now)
      end
      if suppressGcd then
        remainCd = nil
      end
      --- Re-apply on CD edge (false→true) always; else only when API tuple differs. Edge avoids secret-compare misses.
      --- Duration-object path (Retail secret CDs) re-applies cheaply; legacy numeric still uses triple gate.
      local edgeOn = onCd and not (iconFrame._flexxWasOnCd or false)
      iconFrame._flexxWasOnCd = onCd
      local useDurationObject = iconFrame.cd and iconFrame.cd.SetCooldownFromDurationObject
      if showSwipe and onCd then
        if suppressGcd then
          iconFrame._flexxLastCd = nil
          ClearLaneCooldownVisual(iconFrame.cd)
        elseif useDurationObject then
          ApplyCooldownToIcon(iconFrame.cd, spellID, entry.actionSlot, startTime, duration, modRate)
        elseif edgeOn then
          iconFrame._flexxLastCd = { st = startTime, du = duration, mo = modRate }
          ApplyIconCooldownSwipe(iconFrame.cd, startTime, duration, modRate)
        elseif not CooldownTripleUnchanged(startTime, duration, modRate, iconFrame._flexxLastCd) then
          iconFrame._flexxLastCd = { st = startTime, du = duration, mo = modRate }
          ApplyIconCooldownSwipe(iconFrame.cd, startTime, duration, modRate)
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
      local curCharges, maxCharges = SpellChargeDisplay(spellID)
      if maxCharges ~= nil and SafeNumberGt(maxCharges, 1) then
        if SafeNumberGt(curCharges, 0) then
          local txt = ""
          pcall(function()
            txt = tostring(curCharges)
          end)
          iconFrame.count:SetText(txt ~= "" and txt or "")
        elseif showSwipe and onCd and SafeNumberGte(remainCd, 0.05) then
          iconFrame.count:SetText(FormatRemainCount(remainCd))
        else
          iconFrame.count:SetText("0")
        end
      elseif showSwipe and onCd and SafeNumberGte(remainCd, 0.05) then
        iconFrame.count:SetText(FormatRemainCount(remainCd))
      else
        iconFrame.count:SetText("")
      end
      if SpellUsableLikeActionBar(spellID, entry.actionSlot) then
        iconFrame.icon:SetDesaturated(false)
        iconFrame:SetAlpha(onCd and math.max(0.55, usableAlpha * 0.85) or usableAlpha)
      else
        iconFrame.icon:SetDesaturated(desatUnusable)
        iconFrame:SetAlpha(unusableAlpha)
      end
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

local function UpdateLane2And3()
  local db = DB()
  local rotationList, cooldownList = BuildLiveLaneSpellLists()
  local rotSet = {}
  for _, e in ipairs(rotationList) do
    if e.spellID then
      rotSet[e.spellID] = true
    end
  end
  CC.state._rotationSpellIdSet = rotSet
  CC.state.lane2:SetShown(db.showRotationLane ~= false)
  CC.state.lane3:SetShown(db.showCooldownLane ~= false)
  UpdateLaneIcons(CC.state.lane2Icons, rotationList, CC.state.lane2:IsShown(), true)
  UpdateLaneIcons(CC.state.lane3Icons, cooldownList, CC.state.lane3:IsShown(), false)
end

--- Cooldown events: update lanes only — avoids full Layout()/EnableMouse() like default UI cooldown refreshes.
local function UpdateLanesOnly()
  if not CC.state.frame then return end
  UpdateVisibility()
  UpdateLane1()
  UpdateLane2And3()
end

local function Layout()
  local db = DB()
  local f = CC.state.frame
  if not f then return end
  local size = db.iconSize or 44
  -- Rotation / cooldown rows: edge-to-edge icons (no gaps).
  local iconGap = 0
  local rotationW = ICONS_LANE2 * size + (ICONS_LANE2 - 1) * iconGap
  local cooldownW = ICONS_LANE3 * size + (ICONS_LANE3 - 1) * iconGap
  local frameW = math.max(rotationW, cooldownW)
  local pipBarW = rotationW * PIP_BAR_WIDTH_FRAC
  local lane1H = PIP_H + (PIP_WRAP_PAD * 2)
  local totalH = lane1H + PIP_ROTATION_GAP + size + size
  f:SetSize(frameW, totalH)

  local wrapW = pipBarW + (PIP_WRAP_PAD * 2)
  CC.state.lane1Wrap:ClearAllPoints()
  CC.state.lane1Wrap:SetSize(wrapW, lane1H)
  CC.state.lane1Wrap:SetPoint("TOPLEFT", f, "TOPLEFT", (frameW - wrapW) / 2, 0)
  CC.state.lane1:ClearAllPoints()
  CC.state.lane1:SetSize(pipBarW, PIP_H)
  CC.state.lane1:SetPoint("TOPLEFT", CC.state.lane1Wrap, "TOPLEFT", PIP_WRAP_PAD, -PIP_WRAP_PAD)

  CC.state.lane2:ClearAllPoints()
  CC.state.lane2:SetSize(rotationW, size)
  CC.state.lane2:SetPoint("TOPLEFT", f, "TOPLEFT", (frameW - rotationW) / 2, -(lane1H + PIP_ROTATION_GAP))

  CC.state.lane3:ClearAllPoints()
  CC.state.lane3:SetSize(cooldownW, size)
  CC.state.lane3:SetPoint("TOPLEFT", f, "TOPLEFT", (frameW - cooldownW) / 2, -(lane1H + PIP_ROTATION_GAP + size))

  for i = 1, ICONS_LANE2 do
    local icon = CC.state.lane2Icons[i]
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", CC.state.lane2, "TOPLEFT", (i - 1) * (size + iconGap), 0)
  end
  for i = 1, ICONS_LANE3 do
    local icon = CC.state.lane3Icons[i]
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", CC.state.lane3, "TOPLEFT", (i - 1) * (size + iconGap), 0)
  end

  UpdateLane1()
end

local function ApplyCombatAnchor()
  local f = CC.state.frame
  if not f or not f.ClearAllPoints then return end
  local db = DB()
  local ax = type(db.anchorX) == "number" and db.anchorX or 0
  local ay = type(db.anchorY) == "number" and db.anchorY or -180
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", ax, ay)
end

function CC.RefreshFromOptions()
  if not CC.state.frame then return end
  --- Combat blocks anchoring/layout; retry once after combat ends (avoid timer spam).
  if InCombatLockdown and InCombatLockdown() then
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
  RefreshSpellBookSpellIDCache()
  local db = DB()
  pcall(ApplyCombatAnchor)
  if CC.state.frame.SetScale then
    pcall(function()
      CC.state.frame:SetScale(db.scale or 1)
    end)
  end
  if CC.state.frame.EnableMouse then
    pcall(function()
      CC.state.frame:EnableMouse(not db.lockFrame)
    end)
  end
  pcall(Layout)
  pcall(UpdateVisibility)
  pcall(UpdateLane1)
  pcall(UpdateLane2And3)
end

local function CreateFrameOnce()
  if CC.state.frame then return end
  local f = CreateFrame("Frame", "FlexxUI_CombatCenter", UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(20)
  CC.state.frame = f

  CC.state.lane1Wrap = CreateFrame("Frame", nil, f)
  CC.state.lane1Bg = CC.state.lane1Wrap:CreateTexture(nil, "BACKGROUND")
  CC.state.lane1Bg:SetAllPoints(CC.state.lane1Wrap)
  CC.state.lane1Bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  CC.state.lane1Bg:SetVertexColor(0, 0, 0, PIP_WRAP_BG_A)
  CC.state.lane1 = CreateFrame("Frame", nil, CC.state.lane1Wrap)
  CC.state.lane2 = CreateFrame("Frame", nil, f)
  CC.state.lane3 = CreateFrame("Frame", nil, f)

  for i = 1, MAX_PIPS do
    local holder = CreateFrame("Frame", nil, CC.state.lane1)
    pcall(function()
      holder:SetClipsChildren(true)
    end)
    local tex = holder:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Buttons\\WHITE8x8")
    CC.state.lane1Pips[i] = { holder = holder, tex = tex }
  end
  for i = 1, ICONS_LANE2 do
    CC.state.lane2Icons[i] = NewIcon(CC.state.lane2)
  end
  for i = 1, ICONS_LANE3 do
    CC.state.lane3Icons[i] = NewIcon(CC.state.lane3)
  end

  ApplyCombatAnchor()
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if DB().lockFrame then return end
    if _G.FlexxUIDB and _G.FlexxUIDB.locked then return end
    if InCombatLockdown() then return end
    pcall(function()
      self:StartMoving()
    end)
  end)
  f:SetScript("OnDragStop", function(self)
    pcall(function()
      self:StopMovingOrSizing()
    end)
    local pt, rel, relPt, x, y = self:GetPoint(1)
    if rel == UIParent and relPt == "CENTER" and pt == "CENTER" then
      local d = DB()
      d.anchorX = x
      d.anchorY = y
    end
  end)
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
    if ev == "UNIT_POWER_UPDATE" then
      if unit and unit ~= "player" then return end
      UpdateLane1()
      return
    end
    if ev == "SPELLS_CHANGED" then
      RefreshSpellBookSpellIDCache()
      UpdateLanesOnly()
      return
    end
    if ev == "PLAYER_ENTERING_WORLD"
      or ev == "PLAYER_TALENT_UPDATE"
      or ev == "ACTIVE_TALENT_GROUP_CHANGED"
      or ev == "PLAYER_SPECIALIZATION_CHANGED" then
      CC.RefreshFromOptions()
      return
    end
    if ev == "PLAYER_REGEN_DISABLED" or ev == "PLAYER_REGEN_ENABLED" then
      UpdateLanesOnly()
      return
    end
    UpdateLanesOnly()
  end)
  u:SetScript("OnUpdate", function(_, elapsed)
    CC.state._ticker = (CC.state._ticker or 0) + elapsed
    --- ~4 Hz: enough to resync swipes/counts; triple+resync gate avoids restarting the spiral every tick.
    if CC.state._ticker < 0.25 then return end
    CC.state._ticker = 0
    if not CC.state.frame or not CC.state.frame:IsShown() then return end
    UpdateLane2And3()
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

