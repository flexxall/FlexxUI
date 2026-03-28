local _, ns = ...
local O = ns.Options

--- Shared chrome for top tabs, unit sub-tabs, and flat action buttons (same as General tab).
O.chromeButtonSize = { w = 132, h = 24 }

function O.MakeFlatButton(parent, text, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  local cw, ch = O.chromeButtonSize.w, O.chromeButtonSize.h
  b:SetSize(w or cw, h or ch)
  O.StyleSurface(b, 0.96)
  b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)

  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormal", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER")
  label:SetText(text or "")

  b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.18, 0.24, 0.34, 0.96) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.14, 0.18, 0.25, 0.96) end)
  b:SetScript("OnClick", onClick)
  return b
end

--- @param rowWidth number|nil Hit width (default 520). Use ~300 in 320px columns or the row overlaps the next column and steals clicks.
function O.MakeToggle(parent, label, onGet, onSet, rowWidth)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(rowWidth or 520, 26)
  row:RegisterForClicks("LeftButtonUp")

  local box = CreateFrame("Frame", nil, row, "BackdropTemplate")
  box:SetPoint("LEFT", 0, 0)
  box:SetSize(16, 16)
  O.StyleSurface(box, 1)
  box:SetBackdropColor(0.22, 0.24, 0.28, 1)
  box:EnableMouse(false)

  local mark = box:CreateTexture(nil, "OVERLAY")
  -- Same inset as MakeRadio fill so checkbox inner matches radio selected dot.
  mark:SetPoint("TOPLEFT", 4, -4)
  mark:SetPoint("BOTTOMRIGHT", -4, 4)
  mark:SetTexture("Interface\\Buttons\\WHITE8x8")
  mark:SetVertexColor(0.29, 0.74, 0.99, 1)

  local text = (ns.Fonts and ns.Fonts.CreateFontString(row, "OVERLAY", "GameFontHighlight", "all")) or row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("LEFT", box, "RIGHT", 10, 0)
  text:SetText(label)

  row:SetScript("OnClick", function()
    onSet(not onGet())
    row:Refresh()
  end)
  row.Refresh = function() mark:SetShown(onGet() and true or false) end
  return row
end

function O.MakeRadio(parent, label, onGet, value, onSet)
  local row = CreateFrame("Button", nil, parent)
  row:SetSize(300, 24)
  row:RegisterForClicks("LeftButtonUp")
  row._optionEnabled = true

  local dot = CreateFrame("Frame", nil, row, "BackdropTemplate")
  dot:SetPoint("LEFT", 0, 0)
  dot:SetSize(16, 16)
  O.StyleSurface(dot, 1)
  dot:SetBackdropColor(0.22, 0.24, 0.28, 1)
  -- Must not capture mouse; otherwise clicks on the circle never reach the parent Button.
  dot:EnableMouse(false)

  local fill = dot:CreateTexture(nil, "OVERLAY")
  fill:SetPoint("TOPLEFT", 4, -4)
  fill:SetPoint("BOTTOMRIGHT", -4, 4)
  fill:SetTexture("Interface\\Buttons\\WHITE8x8")
  fill:SetVertexColor(0.29, 0.74, 0.99, 1)

  local text = (ns.Fonts and ns.Fonts.CreateFontString(row, "OVERLAY", "GameFontHighlight", "all")) or row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("LEFT", dot, "RIGHT", 10, 0)
  text:SetText(label)

  row:SetScript("OnClick", function()
    if not row._optionEnabled then return end
    onSet(value)
  end)
  row.Refresh = function() fill:SetShown(onGet() == value) end
  row.SetOptionEnabled = function(self, enabled)
    self._optionEnabled = enabled and true or false
    if self._optionEnabled then
      self:SetAlpha(1)
      self:EnableMouse(true)
    else
      self:SetAlpha(0.45)
      -- Disabled rows must not capture clicks (would block overlapping or stacked hit targets).
      self:EnableMouse(false)
    end
  end
  return row
end

function O.MakeUnitNavButton(parent, text, key)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(O.chromeButtonSize.w, O.chromeButtonSize.h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormal", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER")
  label:SetText(text or "")

  function b:RefreshNav()
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsUnitSubTab) or "player"
    local active = sub == key
    if active then
      b:SetBackdropColor(0.22, 0.30, 0.44, 0.96)
    else
      b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
    end
  end

  b:SetScript("OnEnter", function(self)
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsUnitSubTab) or "player"
    local active = sub == key
    if active then
      self:SetBackdropColor(0.26, 0.34, 0.48, 0.96)
    else
      self:SetBackdropColor(0.18, 0.24, 0.34, 0.96)
    end
  end)
  b:SetScript("OnLeave", function(self) self:RefreshNav() end)
  b:SetScript("OnClick", function() O.SelectUnitSubTab(key) end)

  O.state.unitSubTabButtons[key] = b
  b:RefreshNav()
  return b
end

--- Horizontal sub-tabs inside Unit Frames → Player (health / resource / class bar / cast / name).
function O.MakePlayerSubTabButton(parent, text, key, anchorTo)
  local w, h = 112, 24
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormalSmall", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER")
  label:SetText(text or "")

  function b:RefreshPlayerSub()
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsPlayerSubTab) or "health"
    local active = sub == key
    if active then
      b:SetBackdropColor(0.22, 0.30, 0.44, 0.96)
    else
      b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
    end
  end

  b:SetScript("OnEnter", function(self)
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsPlayerSubTab) or "health"
    local active = sub == key
    if active then
      self:SetBackdropColor(0.26, 0.34, 0.48, 0.96)
    else
      self:SetBackdropColor(0.18, 0.24, 0.34, 0.96)
    end
  end)
  b:SetScript("OnLeave", function(self) self:RefreshPlayerSub() end)
  b:SetScript("OnClick", function()
    if O.SelectPlayerSubTab then O.SelectPlayerSubTab(key) end
  end)

  if anchorTo then
    b:SetPoint("LEFT", anchorTo, "RIGHT", 6, 0)
  else
    b:SetPoint("TOPLEFT", 0, 0)
  end
  O.state.playerSubTabButtons[key] = b
  b:RefreshPlayerSub()
  return b
end

--- Left column on General tab: Settings | Fonts (same chrome as Unit Frames → Player / Target / Pet).
function O.MakeGeneralNavButton(parent, text, key)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(O.chromeButtonSize.w, O.chromeButtonSize.h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormal", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER")
  label:SetText(text or "")

  function b:RefreshGeneralNav()
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsGeneralSubTab) or "settings"
    local active = sub == key
    if active then
      b:SetBackdropColor(0.22, 0.30, 0.44, 0.96)
    else
      b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
    end
  end

  b:SetScript("OnEnter", function(self)
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsGeneralSubTab) or "settings"
    local active = sub == key
    if active then
      self:SetBackdropColor(0.26, 0.34, 0.48, 0.96)
    else
      self:SetBackdropColor(0.18, 0.24, 0.34, 0.96)
    end
  end)
  b:SetScript("OnLeave", function(self) self:RefreshGeneralNav() end)
  b:SetScript("OnClick", function()
    if O.SelectGeneralSubTab then O.SelectGeneralSubTab(key) end
  end)

  O.state.generalNavButtons[key] = b
  b:RefreshGeneralNav()
  return b
end

--- Horizontal sub-tabs under General → Fonts (same layout as Unit Frames → Player → Health / Power / …).
function O.MakeFontsSubTabButton(parent, text, key, anchorTo)
  local w, h = 112, 24
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormalSmall", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER")
  label:SetText(text or "")

  function b:RefreshFontsSub()
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsFontsSubTab) or "ui"
    local active = sub == key
    if active then
      b:SetBackdropColor(0.22, 0.30, 0.44, 0.96)
    else
      b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
    end
  end

  b:SetScript("OnEnter", function(self)
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsFontsSubTab) or "ui"
    local active = sub == key
    if active then
      self:SetBackdropColor(0.26, 0.34, 0.48, 0.96)
    else
      self:SetBackdropColor(0.18, 0.24, 0.34, 0.96)
    end
  end)
  b:SetScript("OnLeave", function(self) self:RefreshFontsSub() end)
  b:SetScript("OnClick", function()
    if O.SelectFontsSubTab then O.SelectFontsSubTab(key) end
  end)

  if anchorTo then
    b:SetPoint("LEFT", anchorTo, "RIGHT", 6, 0)
  else
    b:SetPoint("TOPLEFT", 0, 0)
  end
  O.state.fontsSubTabButtons[key] = b
  b:RefreshFontsSub()
  return b
end

--- Horizontal scale slider; getScale/setScale use 1.0 = 100%. Min/max in whole percent (e.g. 70–150).
function O.MakeScalePercentSlider(parent, title, minPct, maxPct, stepPct, getScale, setScale)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(520, 58)
  local fs = (ns.Fonts and ns.Fonts.CreateFontString(row, "ARTWORK", "GameFontHighlightSmall", "all")) or row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 0, 0)
  fs:SetText(title)
  local val = (ns.Fonts and ns.Fonts.CreateFontString(row, "ARTWORK", "GameFontNormalSmall", "all")) or row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  val:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
  val:SetText("100%")

  local slider = CreateFrame("Slider", nil, row)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("TOPLEFT", val, "BOTTOMLEFT", 0, -10)
  slider:SetSize(300, 22)
  -- Visible track (Slider does not draw a bar by default; thumb was hard to see alone).
  local trackBg = slider:CreateTexture(nil, "BACKGROUND")
  trackBg:SetTexture("Interface\\Buttons\\WHITE8x8")
  trackBg:SetVertexColor(0.12, 0.16, 0.22, 1)
  trackBg:SetPoint("LEFT", slider, "LEFT", 0, 0)
  trackBg:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  trackBg:SetHeight(12)

  slider:SetMinMaxValues(minPct, maxPct)
  slider:SetValueStep(stepPct)
  slider:SetObeyStepOnDrag(true)
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local thumb = slider:GetThumbTexture()
  if thumb then
    thumb:SetSize(20, 20)
  end

  slider:SetScript("OnValueChanged", function(_, raw)
    local v = math.max(minPct, math.min(maxPct, raw))
    if stepPct and stepPct > 0 then
      v = math.floor(v / stepPct + 0.5) * stepPct
    end
    setScale(v / 100)
    val:SetText(string.format("%d%%", math.floor(v + 0.5)))
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    if ns.OutputLog and ns.OutputLog.ReapplyLogTitleAccent then ns.OutputLog.ReapplyLogTitleAccent() end
  end)

  row.Refresh = function()
    local s = getScale()
    if type(s) ~= "number" or s ~= s then s = 1 end
    local pct = math.floor(s * 100 + 0.5)
    pct = math.max(minPct, math.min(maxPct, pct))
    slider:SetValue(pct)
    val:SetText(string.format("%d%%", pct))
  end
  return row
end

function O.MakeTabButton(parent, text, key, anchorTo)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(O.chromeButtonSize.w, O.chromeButtonSize.h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormal", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER")
  label:SetText(text or "")

  function b:RefreshTab()
    local active = O.state.panel and O.state.panel.activeTab == key
    if active then
      b:SetBackdropColor(0.22, 0.30, 0.44, 0.96)
    else
      b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
    end
  end

  b:SetScript("OnEnter", function(self)
    local active = O.state.panel and O.state.panel.activeTab == key
    if active then
      self:SetBackdropColor(0.26, 0.34, 0.48, 0.96)
    else
      self:SetBackdropColor(0.18, 0.24, 0.34, 0.96)
    end
  end)
  b:SetScript("OnLeave", function(self) self:RefreshTab() end)
  b:SetScript("OnClick", function() O.SelectTab(key) end)

  if anchorTo then
    b:SetPoint("LEFT", anchorTo, "RIGHT", 8, 0)
  else
    b:SetPoint("TOPLEFT", 16, -44)
  end
  O.state.tabButtons[key] = b
  b:RefreshTab()
  return b
end

--- @param skipHolderBackdrop boolean|nil If true, holder has no backdrop (parent should supply the panel fill — avoids a nested "wrapper + floating scroll" look).
function O.CreateScrollablePage(parent, skipHolderBackdrop)
  local holder
  if skipHolderBackdrop then
    holder = CreateFrame("Frame", nil, parent)
  else
    holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    O.StyleSurface(holder, 0.22)
  end
  holder:SetClipsChildren(true)

  local scroll = CreateFrame("ScrollFrame", nil, holder)
  scroll:SetPoint("TOPLEFT", 0, 0)
  local scrollRightInset = skipHolderBackdrop and 12 or 16
  scroll:SetPoint("BOTTOMRIGHT", -scrollRightInset, 0)

  local scrollbar = CreateFrame("Slider", nil, holder, "BackdropTemplate")
  scrollbar:SetPoint("TOPRIGHT", 0, -8)
  scrollbar:SetPoint("BOTTOMRIGHT", 0, 8)
  scrollbar:SetWidth(12)
  O.StyleSurface(scrollbar, 0.35)
  local thumb = scrollbar:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
  thumb:SetVertexColor(0.29, 0.74, 0.99, 0.95)
  scrollbar:SetThumbTexture(thumb)
  scrollbar:GetThumbTexture():SetSize(10, 32)
  scrollbar:SetMinMaxValues(0, 0)
  scrollbar:SetValueStep(16)
  scrollbar:SetObeyStepOnDrag(true)
  scrollbar:SetValue(0)
  scrollbar:SetScript("OnValueChanged", function(_, value) scroll:SetVerticalScroll(value) end)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetPoint("TOPLEFT", 0, 0)
  content:SetSize(1, 1)
  content:EnableMouse(true)
  scroll:SetScrollChild(content)

  local function UpdateScrollRange()
    local viewWidth = scroll:GetWidth()
    if viewWidth and viewWidth > 0 then content:SetWidth(viewWidth) end
    local range = math.max(0, content:GetHeight() - scroll:GetHeight())
    scrollbar:SetMinMaxValues(0, range)
    if scrollbar:GetValue() > range then scrollbar:SetValue(range) end
  end

  local function OnScrollMouseWheel(_, delta)
    local minVal, maxVal = scrollbar:GetMinMaxValues()
    if maxVal <= minVal then return end
    local step = 36
    local newVal = scrollbar:GetValue() - (delta * step)
    if newVal < minVal then newVal = minVal end
    if newVal > maxVal then newVal = maxVal end
    scrollbar:SetValue(newVal)
  end

  holder:SetScript("OnSizeChanged", UpdateScrollRange)
  scroll:SetScript("OnSizeChanged", UpdateScrollRange)
  content:SetScript("OnSizeChanged", UpdateScrollRange)

  holder:EnableMouseWheel(true)
  holder:SetScript("OnMouseWheel", OnScrollMouseWheel)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", OnScrollMouseWheel)
  content:EnableMouseWheel(true)
  content:SetScript("OnMouseWheel", OnScrollMouseWheel)

  holder.RefreshScroll = UpdateScrollRange
  holder:SetScript("OnShow", function()
    if C_Timer and C_Timer.After then
      C_Timer.After(0, UpdateScrollRange)
    else
      UpdateScrollRange()
    end
  end)

  holder.content = content
  holder.scrollbar = scrollbar
  return holder
end

