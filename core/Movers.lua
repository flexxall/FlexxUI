local _, ns = ...

ns.Movers = ns.Movers or {}

--- Layout (frame positions) lives in FlexxUILayout, not FlexxUIDB, so "Reset settings" does not wipe dragged positions.
local function EnsureLayoutDB()
  _G.FlexxUILayout = _G.FlexxUILayout or {}
  _G.FlexxUILayout.movers = _G.FlexxUILayout.movers or {}
  local m = _G.FlexxUILayout.movers
  -- One-time migration from pre-split saves (FlexxUIDB.movers).
  local old = _G.FlexxUIDB and _G.FlexxUIDB.movers
  if type(old) == "table" then
    for k, v in pairs(old) do
      if m[k] == nil then
        m[k] = v
      end
    end
    _G.FlexxUIDB.movers = nil
  end
end

local function SavePoint(key, frame)
  EnsureLayoutDB()
  if not frame or not frame.GetPoint then return end

  local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(1)
  local relName = relativeTo and relativeTo.GetName and relativeTo:GetName() or nil

  _G.FlexxUILayout.movers[key] = {
    point = point,
    relativeTo = relName,
    relativePoint = relativePoint,
    x = xOfs,
    y = yOfs,
  }
end

local function ResolveRelative(name)
  if not name then return UIParent end
  return _G[name] or UIParent
end

local function RestorePoint(key, frame, defaultPoint)
  EnsureLayoutDB()
  local saved = _G.FlexxUILayout.movers[key]

  frame:ClearAllPoints()
  if saved then
    frame:SetPoint(saved.point or "CENTER", ResolveRelative(saved.relativeTo), saved.relativePoint or "CENTER", saved.x or 0, saved.y or 0)
  elseif defaultPoint then
    frame:SetPoint(unpack(defaultPoint))
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

local function IsLocked()
  return _G.FlexxUIDB and _G.FlexxUIDB.locked
end

function ns.Movers.MakeMovable(key, frame, defaultPoint)
  if not key or not frame then return end

  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  RestorePoint(key, frame, defaultPoint)

  frame:SetScript("OnDragStart", function(self)
    if IsLocked() then return end
    -- Moving frames while combat lockdown is active can trigger "Interface action failed" with no Lua error.
    if InCombatLockdown() then return end
    pcall(function()
      self:StartMoving()
    end)
  end)

  frame:SetScript("OnDragStop", function(self)
    pcall(function()
      self:StopMovingOrSizing()
    end)
    SavePoint(key, self)
  end)
end

function ns.Movers.Restore(key, frame, defaultPoint)
  if not key or not frame then return end
  RestorePoint(key, frame, defaultPoint)
end

--- Remove one mover entry from saved layout (other frames unchanged).
function ns.Movers.ClearSavedPosition(key)
  EnsureLayoutDB()
  if key and _G.FlexxUILayout.movers then
    _G.FlexxUILayout.movers[key] = nil
  end
end

--- Clear saved position for this key and apply defaultPoint immediately (no reload).
function ns.Movers.ResetToDefault(key, frame, defaultPoint)
  if not key or not frame then return end
  ns.Movers.ClearSavedPosition(key)
  frame:ClearAllPoints()
  if defaultPoint then
    frame:SetPoint(unpack(defaultPoint))
  else
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  end
end

--- Clear all saved anchor data; frames use built-in defaults on next reload. Does not touch FlexxUIDB options.
function ns.Movers.ResetSavedPositions()
  _G.FlexxUILayout = { movers = {} }
end

