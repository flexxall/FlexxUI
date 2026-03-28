local ADDON_NAME, ns = ...
ns.OutputLog = ns.OutputLog or {}
local OL = ns.OutputLog

local MAX_LINES = 200
local lines = {}
local frame
local scroll
local edit
local updatingEditText = false
local refreshDriver
local refreshQueued = false
local stats = {
  appendCalls = 0,
  appended = 0,
  droppedEmpty = 0,
  safeUnprintable = 0,
  safeOmitted = 0,
  prefixFallback = 0,
  refreshCalls = 0,
}

local function EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if _G.FlexxUIDB.outputLogWindowOpen == nil then _G.FlexxUIDB.outputLogWindowOpen = false end
end

local function SafeLine(v)
  if v == nil then return "" end
  local ok, s = pcall(tostring, v)
  if not ok or type(s) ~= "string" then
    stats.safeUnprintable = stats.safeUnprintable + 1
    local ok2, s2 = pcall(function()
      return string.format("(%s)", type(v))
    end)
    if ok2 and type(s2) == "string" then return s2 end
    return "[unprintable]"
  end
  local okCmp, isEmpty = pcall(function() return s == "" end)
  if not okCmp then
    stats.safeOmitted = stats.safeOmitted + 1
    return "[omitted]"
  end
  if isEmpty then return "" end
  return s
end

local function ConcatLines()
  return table.concat(lines, "\n")
end

local function RefreshEdit()
  if not edit or not scroll then return end
  stats.refreshCalls = stats.refreshCalls + 1
  local text = ConcatLines()
  pcall(function()
    updatingEditText = true
    edit:SetText(text)
    edit:SetWidth(math.max(200, scroll:GetWidth() - 8))
    local _, n = text:gsub("\n", "\n")
    local _, fh = edit:GetFont()
    fh = fh or 12
    local h = math.max(scroll:GetHeight() + 8, (n + 1) * fh + 24)
    edit:SetHeight(h)
    local len = string.len(text)
    edit:SetCursorPosition(len)
    updatingEditText = false
  end)
end

-- Never refresh the EditBox synchronously from Append: callers include combat-adjacent paths.
-- Queue a single next-frame refresh on a neutral frame so we are not on the combat/event stack.
local function ScheduleRefreshEdit()
  if not frame or not edit or not frame:IsShown() then return end
  if refreshQueued then return end
  refreshQueued = true
  if not refreshDriver then
    refreshDriver = CreateFrame("Frame", "FlexxUI_OutputLogRefresh", UIParent)
  end
  refreshDriver:SetScript("OnUpdate", function(self)
    self:SetScript("OnUpdate", nil)
    refreshQueued = false
    pcall(RefreshEdit)
  end)
end

function OL.Append(msg)
  stats.appendCalls = stats.appendCalls + 1
  local line = SafeLine(msg)
  local okEmpty, isEmpty = pcall(function() return line == "" end)
  if okEmpty and isEmpty then
    stats.droppedEmpty = stats.droppedEmpty + 1
    return
  end
  local t = date and date("%H:%M:%S") or ""
  local okPrefix, prefixed = pcall(function()
    if t ~= "" then
      return "[" .. t .. "] " .. line
    end
    return line
  end)
  if okPrefix then
    line = prefixed
  else
    stats.prefixFallback = stats.prefixFallback + 1
    line = "[omitted]"
  end
  lines[#lines + 1] = line
  stats.appended = stats.appended + 1
  while #lines > MAX_LINES do
    table.remove(lines, 1)
  end
  if frame and frame:IsShown() and edit then
    ScheduleRefreshEdit()
  end
end

function OL.Clear()
  wipe(lines)
  if edit then
    pcall(function()
      updatingEditText = true
      edit:SetText("")
      updatingEditText = false
    end)
    pcall(RefreshEdit)
  end
end

function OL.Ensure()
  if frame then return frame end
  EnsureDB()

  local f = CreateFrame("Frame", "FlexxUI_OutputLog", UIParent, "BackdropTemplate")
  f:SetSize(480, 320)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(100)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0.09, 0.09, 0.12, 0.97)
  f:SetBackdropBorderColor(0.45, 0.38, 0.28, 0.9)

  local titleBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
  titleBg:SetPoint("TOPLEFT", 12, -10)
  titleBg:SetPoint("TOPRIGHT", -12, -10)
  titleBg:SetHeight(34)
  titleBg:EnableMouse(true)
  titleBg:SetScript("OnMouseDown", function()
    f:StartMoving()
  end)
  titleBg:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
  end)
  if titleBg.SetBackdrop then
    titleBg:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true,
      tileSize = 8,
      edgeSize = 8,
      insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    titleBg:SetBackdropColor(0.18, 0.15, 0.1, 0.85)
    titleBg:SetBackdropBorderColor(0.35, 0.3, 0.22, 0.9)
  end

  local title = (ns.Fonts and ns.Fonts.CreateFontString(titleBg, "OVERLAY", "GameFontNormalLarge", "all")) or titleBg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("LEFT", titleBg, "LEFT", 10, 0)
  title:SetTextColor(0.95, 0.92, 0.75)
  title:SetText("FlexxUI — Log")
  f.logTitleFont = title

  local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
  closeBtn:SetScript("OnClick", function()
    OL.Hide()
  end)

  local hint = (ns.Fonts and ns.Fonts.CreateFontString(f, "OVERLAY", "GameFontHighlightSmall", "all")) or f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", titleBg, "BOTTOMLEFT", 0, -8)
  hint:SetPoint("TOPRIGHT", titleBg, "BOTTOMRIGHT", 0, -8)
  hint:SetJustifyH("LEFT")
  hint:SetText("Drag the title bar to move. Click the log, select text, Ctrl+C to copy. Use Select all, then Ctrl+C for everything.")

  local outputBg = CreateFrame("Frame", nil, f, "BackdropTemplate")
  outputBg:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -6)
  outputBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 44)
  outputBg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 8,
    edgeSize = 8,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  outputBg:SetBackdropColor(0.18, 0.15, 0.1, 0.95)
  outputBg:SetBackdropBorderColor(0.32, 0.28, 0.22, 0.9)

  scroll = CreateFrame("ScrollFrame", "FlexxUI_OutputScroll", outputBg, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 4, -4)
  scroll:SetPoint("BOTTOMRIGHT", -24, 4)

  edit = CreateFrame("EditBox", "FlexxUI_OutputEdit", scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(scroll:GetWidth() or 400)
  edit:SetHeight(400)
  edit:SetTextInsets(6, 6, 6, 6)
  edit:SetMaxLetters(999999)
  scroll:SetScrollChild(edit)

  edit:SetScript("OnTextChanged", function(self, userInput)
    if updatingEditText or not userInput then return end
    updatingEditText = true
    self:SetText(ConcatLines())
    updatingEditText = false
  end)

  scroll:SetScript("OnSizeChanged", function()
    if edit and scroll then
      pcall(function()
        edit:SetWidth(math.max(200, scroll:GetWidth() - 8))
      end)
      ScheduleRefreshEdit()
    end
  end)

  local clearBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  clearBtn:SetSize(90, 22)
  clearBtn:SetPoint("BOTTOMLEFT", 16, 12)
  clearBtn:SetText("Clear")
  clearBtn:SetScript("OnClick", function()
    OL.Clear()
  end)

  local selectAllBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  selectAllBtn:SetSize(100, 22)
  selectAllBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
  selectAllBtn:SetText("Select all")
  selectAllBtn:SetScript("OnClick", function()
    if not edit then return end
    local txt = ConcatLines()
    pcall(function()
      updatingEditText = true
      edit:SetText(txt)
      if edit.HighlightText then
        edit:HighlightText(0, -1)
      end
      updatingEditText = false
      edit:SetFocus()
    end)
  end)

  f:SetScript("OnShow", function()
    pcall(RefreshEdit)
  end)

  frame = f
  f:Hide()
  return f
end

function OL.Show()
  EnsureDB()
  OL.Ensure()
  if frame then
    _G.FlexxUIDB.outputLogWindowOpen = true
    pcall(RefreshEdit)
    frame:Show()
  end
end

function OL.Hide()
  EnsureDB()
  if frame then
    _G.FlexxUIDB.outputLogWindowOpen = false
    frame:Hide()
  end
end

function OL.Toggle()
  if frame and frame:IsShown() then
    OL.Hide()
  else
    OL.Show()
  end
end

function OL.IsShown()
  return frame and frame:IsShown()
end

function OL.ReapplyLogTitleAccent()
  if frame and frame.logTitleFont and frame.logTitleFont.SetTextColor then
    frame.logTitleFont:SetTextColor(0.95, 0.92, 0.75)
  end
end

function OL.GetStats()
  local out = {}
  for k, v in pairs(stats) do out[k] = v end
  out.lineCount = #lines
  return out
end

function _G.FlexxUI_Log(msg)
  OL.Append(msg)
end

function _G.FlexxUI_LogDiag(tag, msg)
  local s = OL.GetStats()
  local label = (tag and tostring(tag) or "diag")
  local body = (msg and tostring(msg) or "")
  OL.Append(string.format(
    "[logdiag/%s] appendCalls=%d appended=%d droppedEmpty=%d safeUnprintable=%d safeOmitted=%d prefixFallback=%d refreshCalls=%d lines=%d %s",
    label,
    s.appendCalls or 0,
    s.appended or 0,
    s.droppedEmpty or 0,
    s.safeUnprintable or 0,
    s.safeOmitted or 0,
    s.prefixFallback or 0,
    s.refreshCalls or 0,
    s.lineCount or 0,
    body
  ))
end
