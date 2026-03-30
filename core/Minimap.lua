local _, ns = ...

ns.Minimap = ns.Minimap or {}

local function EnsureDB()
  if ns.DB and ns.DB.ApplyDefaults and _G.FlexxUIDB then
    ns.DB.ApplyDefaults(_G.FlexxUIDB, ns.DB.Defaults)
  end
end

--- Distance from Minimap center to button center: outside the map circle (past the rim).
local function GetRingRadius(button)
  local w = Minimap:GetWidth() or 140
  local half = w * 0.5 -- radius of the circular minimap
  local btn = (button and button:GetWidth()) or 24
  local gap = 2 -- space between map edge and button
  return math.max(half + btn * 0.5 + gap, 8)
end

local function GetAngleDeg()
  EnsureDB()
  local db = _G.FlexxUIDB
  if type(db.minimapButtonAngle) == "number" then
    return db.minimapButtonAngle
  end
  -- One-time migration from older offset storage (Cartesian from center).
  local ox = db.minimapButtonOffsetX
  local oy = db.minimapButtonOffsetY
  if type(ox) == "number" and type(oy) == "number" then
    db.minimapButtonAngle = math.deg(math.atan2(oy, ox))
    return db.minimapButtonAngle
  end
  return (ns.DB and ns.DB.Defaults and ns.DB.Defaults.minimapButtonAngle) or 177
end

function ns.Minimap.SavePosition(button)
  if not button then return end
  EnsureDB()
  local point, relativeTo, _, x, y = button:GetPoint()
  if point == "CENTER" and relativeTo == Minimap and type(x) == "number" and type(y) == "number" then
    _G.FlexxUIDB.minimapButtonAngle = math.deg(math.atan2(y, x))
  end
end

function ns.Minimap.ApplyPosition(button)
  if not button then return end
  local rad = math.rad(GetAngleDeg())
  local R = GetRingRadius(button)
  local ox = math.cos(rad) * R
  local oy = math.sin(rad) * R
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
end

--- Show or hide the launcher from saved prefs (General → Show minimap button).
function ns.Minimap.ApplyVisibility()
  local b = ns.Minimap._button
  if not b then return end
  EnsureDB()
  local show = _G.FlexxUIDB.minimapButtonShow ~= false
  if show then
    ns.Minimap.ApplyPosition(b)
    b:Show()
  else
    b:Hide()
  end
end

--- Single minimap button: opens the options panel (same as /flexxui). Draggable on the minimap ring; angle saved.
function ns.Minimap.CreateButton()
  if ns.Minimap._button then
    ns.Minimap.ApplyVisibility()
    return ns.Minimap._button
  end

  local b = CreateFrame("Button", "FlexxUIMinimapButton", Minimap)
  b:SetSize(24, 24)
  b:SetFrameStrata("LOW")
  b:SetFrameLevel(Minimap:GetFrameLevel() + 5)
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

  local tex = b:CreateTexture(nil, "BACKGROUND")
  tex:SetAllPoints()
  local icon = (ns.media and ns.media.minimapMini) or "Interface\\AddOns\\FlexxUI\\Media\\FlexxUiMini.png"
  tex:SetTexture(icon)
  tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  ns.Minimap.ApplyPosition(b)

  Minimap:HookScript("OnSizeChanged", function()
    if ns.Minimap._button and ns.Minimap._button:IsShown() then
      ns.Minimap.ApplyPosition(ns.Minimap._button)
    end
  end)

  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("LeftButton")

  local dragStartX, dragStartY

  b:SetScript("OnDragStart", function(self)
    dragStartX, dragStartY = GetCursorPosition()
    self._dragMoved = false
    self:SetScript("OnUpdate", function()
      local nx, ny = GetCursorPosition()
      if dragStartX and (math.abs(nx - dragStartX) > 3 or math.abs(ny - dragStartY) > 3) then
        self._dragMoved = true
      end
      local mx, my = Minimap:GetCenter()
      local scale = Minimap:GetEffectiveScale()
      local px, py = nx / scale, ny / scale
      local dx, dy = px - mx, py - my
      local angle = math.atan2(dy, dx)
      local R = GetRingRadius(self)
      local ox = math.cos(angle) * R
      local oy = math.sin(angle) * R
      self:ClearAllPoints()
      self:SetPoint("CENTER", Minimap, "CENTER", ox, oy)
    end)
  end)

  b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    if self._dragMoved then
      ns.Minimap.SavePosition(self)
    end
  end)

  b:SetScript("OnClick", function(self)
    if self._dragMoved then
      self._dragMoved = false
      return
    end
    if ns.Options and ns.Options.Open then ns.Options.Open() end
  end)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("FlexxUI", 1, 1, 1)
    GameTooltip:AddLine("Click to open settings.", nil, nil, nil, true)
    GameTooltip:AddLine("Drag to move along the minimap edge.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)

  ns.Minimap._button = b
  ns.Minimap.ApplyVisibility()
  return b
end
