local _, ns = ...

local D = {}
ns.Debug = D

D.state = D.state or {
  frame = nil,
  lines = {},
  maxLines = 80,
  monitorFrame = nil,
  actionLogEventsRegistered = false,
}

local function SafeToString(v)
  local ok, s = pcall(function() return tostring(v) end)
  if ok and s then return s end
  return "<unprintable>"
end

local function Stamp()
  local ok, s = pcall(function() return date("%H:%M:%S") end)
  if ok and s then return s end
  return "??:??:??"
end

local function Push(msg)
  if not msg or msg == "" then return end
  local lines = D.state.lines
  lines[#lines + 1] = "[" .. Stamp() .. "] " .. msg
  while #lines > D.state.maxLines do
    table.remove(lines, 1)
  end
end

local function IsEnabled()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if _G.FlexxUIDB.debugActionLogEnabled == nil then
    _G.FlexxUIDB.debugActionLogEnabled = true
  end
  return _G.FlexxUIDB.debugActionLogEnabled == true
end

local function IsMonitorEnabled()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if _G.FlexxUIDB.debugActionMonitorShown == nil then
    _G.FlexxUIDB.debugActionMonitorShown = false
  end
  return _G.FlexxUIDB.debugActionMonitorShown == true
end

local function SyncOptionsControls()
  if ns.Options and ns.Options.RefreshControls then
    pcall(function()
      ns.Options.RefreshControls()
    end)
  end
end

local function MakeUiButton(parent, text, w, h, onClick)
  local O = ns.Options
  if O and O.MakeFlatButton then
    local b = O.MakeFlatButton(parent, text, w, h, onClick)
    return b
  end
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 80, h or 20)
  b:SetText(text or "")
  b:SetScript("OnClick", onClick)
  return b
end

function D.SetEnabled(enabled)
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  _G.FlexxUIDB.debugActionLogEnabled = enabled and true or false
  if _G.FlexxUIDB.debugActionLogEnabled then
    Push("Debug action logging enabled.")
  else
    Push("Debug action logging disabled.")
  end
end

function D.Clear()
  D.state.lines = {}
end

function D.GetLogText(limit)
  local lines = D.state.lines
  local n = #lines
  if n == 0 then
    return "No debug entries yet. Enter combat and reproduce the issue."
  end
  local startIdx = 1
  if type(limit) == "number" and limit > 0 and n > limit then
    startIdx = n - limit + 1
  end
  local out = {}
  for i = startIdx, n do
    out[#out + 1] = lines[i]
  end
  return table.concat(out, "\n")
end

local function EnsureMonitorFrame()
  if D.state.monitorFrame then return D.state.monitorFrame end
  local f = CreateFrame("Frame", "FlexxUI_DebugMonitorFrame", UIParent, "BackdropTemplate")
  f:SetSize(620, 250)
  f:SetPoint("TOP", UIParent, "TOP", 0, -120)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(450)
  if ns.Options and ns.Options.StyleSurface then
    ns.Options.StyleSurface(f, 0.80)
    -- Match settings shell feel: darker outer chrome.
    f:SetBackdropColor(0.06, 0.07, 0.10, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 0.92)
  else
    f:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
  end
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  local function BringToFront(self)
    if self.SetFrameStrata then self:SetFrameStrata("FULLSCREEN_DIALOG") end
    if self.Raise then pcall(function() self:Raise() end) end
    if self.GetFrameLevel and self.SetFrameLevel then
      local lvl = self:GetFrameLevel() or 0
      self:SetFrameLevel(lvl + 40)
    end
    local panel = ns.Options and ns.Options.state and ns.Options.state.panel
    if panel and panel.SetFrameStrata then
      panel:SetFrameStrata("DIALOG")
    end
  end
  f:HookScript("OnMouseDown", BringToFront)
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
  title:SetText("FlexxUI Action Debug")

  local btnSelect = MakeUiButton(f, "Select all", 86, 20, nil)
  btnSelect:SetPoint("TOPRIGHT", f, "TOPRIGHT", -166, -8)

  local btnClear = MakeUiButton(f, "Clear", 70, 20, function()
    D.Clear()
  end)
  btnClear:SetPoint("TOPRIGHT", f, "TOPRIGHT", -90, -8)

  local btnClose = MakeUiButton(f, "X", 26, 20, function()
    D.SetMonitorShown(false)
  end)
  btnClose:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -8)

  local O = ns.Options
  local logHolder
  if O and O.CreateScrollablePage then
    -- Same component as settings pages: custom slider + arrows + wheel behavior.
    logHolder = O.CreateScrollablePage(f, false)
    logHolder:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -36)
    logHolder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    if logHolder.SetBackdropColor then
      -- Slightly lighter inner body, like settings content panes.
      logHolder:SetBackdropColor(0.11, 0.13, 0.17, 0.88)
      logHolder:SetBackdropBorderColor(0, 0, 0, 0)
    end
  else
    logHolder = CreateFrame("Frame", nil, f, "BackdropTemplate")
    logHolder:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -36)
    logHolder:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
  end

  local eb = CreateFrame("EditBox", nil, logHolder.content or logHolder)
  eb:SetMultiLine(true)
  eb:SetFontObject("GameFontHighlightSmall")
  eb:SetAutoFocus(false)
  eb:EnableMouse(true)
  eb:SetPoint("TOPLEFT", logHolder.content or logHolder, "TOPLEFT", 0, 0)
  eb:SetPoint("TOPRIGHT", logHolder.content or logHolder, "TOPRIGHT", 0, 0)
  eb:SetWidth(560)
  -- Keep a tall fixed child height for compatibility (some clients do not expose EditBox:GetStringHeight).
  eb:SetHeight(2400)
  eb:SetTextInsets(2, 2, 0, 0)
  eb:SetScript("OnMouseDown", function(self)
    BringToFront(f)
    self:SetFocus()
  end)
  eb:SetScript("OnEditFocusGained", function(self)
    self._flexxSelecting = true
    self:HighlightText()
  end)
  eb:SetScript("OnEditFocusLost", function(self)
    self._flexxSelecting = false
  end)
  eb:SetScript("OnEscapePressed", function()
    eb:ClearFocus()
    D.SetMonitorShown(false)
  end)
  f.scrollHolder = logHolder
  f.editBox = eb

  btnSelect:SetScript("OnClick", function()
    eb:SetText(D.GetLogText(200))
    eb:SetFocus()
    eb:HighlightText()
  end)

  f._tick = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    self._tick = (self._tick or 0) + elapsed
    if self._tick < 0.25 then return end
    self._tick = 0
    if self.editBox and self.editBox._flexxSelecting then return end
    self.editBox:SetText(D.GetLogText(200))
  end)

  f:Hide()
  D.state.monitorFrame = f
  return f
end

function D.SetMonitorShown(shown)
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  _G.FlexxUIDB.debugActionMonitorShown = shown and true or false
  local f = EnsureMonitorFrame()
  if _G.FlexxUIDB.debugActionMonitorShown then
    f.editBox:SetText(D.GetLogText(200))
    f:Show()
    if f.Raise then pcall(function() f:Raise() end) end
  else
    f:Hide()
  end
  if C_Timer and C_Timer.After then
    C_Timer.After(0, SyncOptionsControls)
  else
    SyncOptionsControls()
  end
end

function D.Init()
  D.SetEnabled(IsEnabled())
  D.SetMonitorShown(IsMonitorEnabled())
  --- Action logging via RegisterEvent(UI_ERROR_MESSAGE/...) causes secure-action spam on Retail 12+ reload; disabled.
  D.state.actionLogEventsRegistered = true
end

function D.RegisterActionLogEvents()
  --- No-op: registering any of these events can trigger ADDON_ACTION_FORBIDDEN on load. Use Blizzard chat filter / BugGrabber if needed.
end

