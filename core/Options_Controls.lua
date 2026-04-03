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
  b.Label = label
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

--- Horizontal sub-tabs inside Unit Frames → Player (health / resource / class bar / auras / cast / name).
function O.MakePlayerSubTabButton(parent, text, key, anchorTo)
  -- Narrow so six tabs fit the options panel; gap between buttons (see SetPoint below).
  local w, h = 92, 24
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormalSmall", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER")
  label:SetWidth(w - 6)
  label:SetMaxLines(1)
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
    b:SetPoint("LEFT", anchorTo, "RIGHT", 4, 0)
  else
    b:SetPoint("TOPLEFT", 0, 0)
  end
  O.state.playerSubTabButtons[key] = b
  b:RefreshPlayerSub()
  return b
end

--- Horizontal sub-tabs inside Unit Frames → Target (frame vs cast bar).
function O.MakeTargetSubTabButton(parent, text, key, anchorTo)
  local w, h = 92, 24
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(w, h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormalSmall", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  label:SetPoint("CENTER")
  label:SetWidth(w - 6)
  label:SetMaxLines(1)
  label:SetText(text or "")

  function b:RefreshTargetSub()
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsTargetSubTab) or "frame"
    local active = sub == key
    if active then
      b:SetBackdropColor(0.22, 0.30, 0.44, 0.96)
    else
      b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
    end
  end

  b:SetScript("OnEnter", function(self)
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsTargetSubTab) or "frame"
    local active = sub == key
    if active then
      self:SetBackdropColor(0.26, 0.34, 0.48, 0.96)
    else
      self:SetBackdropColor(0.18, 0.24, 0.34, 0.96)
    end
  end)
  b:SetScript("OnLeave", function(self) self:RefreshTargetSub() end)
  b:SetScript("OnClick", function()
    if O.SelectTargetSubTab then O.SelectTargetSubTab(key) end
  end)

  if anchorTo then
    b:SetPoint("LEFT", anchorTo, "RIGHT", 4, 0)
  else
    b:SetPoint("TOPLEFT", 0, 0)
  end
  O.state.targetSubTabButtons[key] = b
  b:RefreshTargetSub()
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

  local settingFromCode = false
  slider:SetScript("OnValueChanged", function(_, raw)
    if settingFromCode then return end
    local v = math.max(minPct, math.min(maxPct, raw))
    if stepPct and stepPct > 0 then
      v = math.floor(v / stepPct + 0.5) * stepPct
    end
    setScale(v / 100)
    val:SetText(string.format("%d%%", math.floor(v + 0.5)))
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
  end)

  row.Refresh = function()
    local s = getScale()
    if type(s) ~= "number" or s ~= s then s = 1 end
    local pct = math.floor(s * 100 + 0.5)
    pct = math.max(minPct, math.min(maxPct, pct))
    settingFromCode = true
    slider:SetValue(pct)
    settingFromCode = false
    val:SetText(string.format("%d%%", pct))
  end
  return row
end

--- Integer px slider (e.g. aura row nudge). getInt/setInt use whole numbers.
function O.MakeIntSlider(parent, title, minV, maxV, stepV, getInt, setInt)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(520, 58)
  local fs = (ns.Fonts and ns.Fonts.CreateFontString(row, "ARTWORK", "GameFontHighlightSmall", "all")) or row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 0, 0)
  fs:SetText(title)
  local val = (ns.Fonts and ns.Fonts.CreateFontString(row, "ARTWORK", "GameFontNormalSmall", "all")) or row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  val:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -6)
  val:SetText("0")

  local slider = CreateFrame("Slider", nil, row)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("TOPLEFT", val, "BOTTOMLEFT", 0, -10)
  slider:SetSize(300, 22)
  local trackBg = slider:CreateTexture(nil, "BACKGROUND")
  trackBg:SetTexture("Interface\\Buttons\\WHITE8x8")
  trackBg:SetVertexColor(0.12, 0.16, 0.22, 1)
  trackBg:SetPoint("LEFT", slider, "LEFT", 0, 0)
  trackBg:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
  trackBg:SetHeight(12)

  slider:SetMinMaxValues(minV, maxV)
  slider:SetValueStep(stepV or 1)
  slider:SetObeyStepOnDrag(true)
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  local thumb = slider:GetThumbTexture()
  if thumb then
    thumb:SetSize(20, 20)
  end

  local settingFromCode = false
  slider:SetScript("OnValueChanged", function(_, raw)
    if settingFromCode then return end
    local v = math.max(minV, math.min(maxV, raw))
    local st = stepV or 1
    if st > 0 then
      v = math.floor(v / st + 0.5) * st
    end
    setInt(v)
    val:SetText(tostring(math.floor(v + 0.5)))
  end)

  row.Refresh = function()
    local n = getInt()
    if type(n) ~= "number" or n ~= n then n = minV end
    n = math.max(minV, math.min(maxV, n))
    local st = stepV or 1
    if st > 0 then
      n = math.floor(n / st + 0.5) * st
    end
    settingFromCode = true
    slider:SetValue(n)
    settingFromCode = false
    val:SetText(tostring(math.floor(n + 0.5)))
  end
  return row
end

--- Left column on Dev Settings tab: Cast bars | Auras (same chrome as General → Settings).
function O.MakeDevNavButton(parent, text, key, anchorTo)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(O.chromeButtonSize.w, O.chromeButtonSize.h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormal", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER")
  label:SetText(text or "")

  function b:RefreshDevNav()
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsDevSubTab) or "cast"
    local active = sub == key
    if active then
      b:SetBackdropColor(0.22, 0.30, 0.44, 0.96)
    else
      b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
    end
  end

  b:SetScript("OnEnter", function(self)
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsDevSubTab) or "cast"
    local active = sub == key
    if active then
      self:SetBackdropColor(0.26, 0.34, 0.48, 0.96)
    else
      self:SetBackdropColor(0.18, 0.24, 0.34, 0.96)
    end
  end)
  b:SetScript("OnLeave", function(self) self:RefreshDevNav() end)
  b:SetScript("OnClick", function()
    if O.SelectDevSubTab then O.SelectDevSubTab(key) end
  end)

  if anchorTo then
    b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -8)
  else
    b:SetPoint("TOPLEFT", 0, 0)
  end
  if not O.state.devNavButtons then O.state.devNavButtons = {} end
  O.state.devNavButtons[key] = b
  b:RefreshDevNav()
  return b
end

--- Left column on Combat tab.
function O.MakeCombatNavButton(parent, text, key, anchorTo)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(O.chromeButtonSize.w, O.chromeButtonSize.h)
  O.StyleSurface(b, 0.96)
  local label = (ns.Fonts and ns.Fonts.CreateFontString(b, "OVERLAY", "GameFontNormal", "all")) or b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER")
  label:SetText(text or "")

  function b:RefreshCombatNav()
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsCombatSubTab) or "overview"
    local active = sub == key
    if active then
      b:SetBackdropColor(0.22, 0.30, 0.44, 0.96)
    else
      b:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
    end
  end

  b:SetScript("OnEnter", function(self)
    local sub = (_G.FlexxUIDB and _G.FlexxUIDB.optionsCombatSubTab) or "overview"
    local active = sub == key
    if active then
      self:SetBackdropColor(0.26, 0.34, 0.48, 0.96)
    else
      self:SetBackdropColor(0.18, 0.24, 0.34, 0.96)
    end
  end)
  b:SetScript("OnLeave", function(self) self:RefreshCombatNav() end)
  b:SetScript("OnClick", function()
    if O.SelectCombatSubTab then O.SelectCombatSubTab(key) end
  end)

  if anchorTo then
    b:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -8)
  else
    b:SetPoint("TOPLEFT", 0, 0)
  end
  if not O.state.combatNavButtons then O.state.combatNavButtons = {} end
  O.state.combatNavButtons[key] = b
  b:RefreshCombatNav()
  return b
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
  scrollbar:SetPoint("TOPRIGHT", 0, -30)
  scrollbar:SetPoint("BOTTOMRIGHT", 0, 30)
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

  local function ScrollByStep(sign)
    local minVal, maxVal = scrollbar:GetMinMaxValues()
    if maxVal <= minVal then return end
    local step = 36
    local newVal = scrollbar:GetValue() + (sign * step)
    if newVal < minVal then newVal = minVal end
    if newVal > maxVal then newVal = maxVal end
    scrollbar:SetValue(newVal)
  end

  local arrowUp = CreateFrame("Button", nil, holder, "BackdropTemplate")
  arrowUp:SetSize(16, 16)
  arrowUp:SetPoint("TOPRIGHT", 2, -8)
  O.StyleSurface(arrowUp, 0.96)
  arrowUp:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
  local upText = (ns.Fonts and ns.Fonts.CreateFontString(arrowUp, "OVERLAY", "GameFontNormalSmall", "all")) or arrowUp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  upText:SetPoint("CENTER", 0, -1)
  upText:SetText("^")
  arrowUp:SetScript("OnEnter", function(self) self:SetBackdropColor(0.18, 0.24, 0.34, 0.96) end)
  arrowUp:SetScript("OnLeave", function(self) self:SetBackdropColor(0.14, 0.18, 0.25, 0.96) end)
  arrowUp:SetScript("OnClick", function() ScrollByStep(-1) end)

  local arrowDown = CreateFrame("Button", nil, holder, "BackdropTemplate")
  arrowDown:SetSize(16, 16)
  arrowDown:SetPoint("BOTTOMRIGHT", 2, 8)
  O.StyleSurface(arrowDown, 0.96)
  arrowDown:SetBackdropColor(0.14, 0.18, 0.25, 0.96)
  local downText = (ns.Fonts and ns.Fonts.CreateFontString(arrowDown, "OVERLAY", "GameFontNormalSmall", "all")) or arrowDown:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  downText:SetPoint("CENTER", 0, 1)
  downText:SetText("v")
  arrowDown:SetScript("OnEnter", function(self) self:SetBackdropColor(0.18, 0.24, 0.34, 0.96) end)
  arrowDown:SetScript("OnLeave", function(self) self:SetBackdropColor(0.14, 0.18, 0.25, 0.96) end)
  arrowDown:SetScript("OnClick", function() ScrollByStep(1) end)

  local function UpdateScrollRange()
    local viewWidth = scroll:GetWidth()
    if viewWidth and viewWidth > 0 then content:SetWidth(viewWidth) end
    local range = math.max(0, content:GetHeight() - scroll:GetHeight())
    scrollbar:SetMinMaxValues(0, range)
    if scrollbar:GetValue() > range then scrollbar:SetValue(range) end
    local hasRange = range > 0
    arrowUp:SetAlpha(hasRange and 1 or 0.45)
    arrowDown:SetAlpha(hasRange and 1 or 0.45)
  end

  local function OnScrollMouseWheel(_, delta)
    ScrollByStep(-delta)
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
  holder.scrollUpButton = arrowUp
  holder.scrollDownButton = arrowDown
  return holder
end

--- Label + WoW-style select: one row shows the current choice; click opens a floating list.
--- @param items { value: string, text: string }[]
--- @param getValue fun(): string
--- @param setValue fun(value: string)  -- should persist and call O.RefreshControls when appropriate
function O.MakeEnumSelect(parent, label, items, getValue, setValue, width)
  local w = width or 220
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(400, 52)

  local lbl = (ns.Fonts and ns.Fonts.CreateFontString(row, "OVERLAY", "GameFontHighlightSmall", "all")) or row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  lbl:SetPoint("TOPLEFT", 0, 0)
  lbl:SetText(label or "")

  local btn = CreateFrame("Button", nil, row, "BackdropTemplate")
  O.StyleSurface(btn, 0.96)
  btn:SetSize(w, 28)
  btn:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)

  -- Modern clients often ship dropdown art as atlases; file-only paths can render invisible.
  local chev = btn:CreateTexture(nil, "OVERLAY")
  if chev.SetDrawLayer then chev:SetDrawLayer("OVERLAY", 2) end
  chev:SetSize(16, 16)
  chev:SetPoint("RIGHT", -6, 0)
  local chevOk = chev.SetAtlas and pcall(chev.SetAtlas, chev, "common-dropdown-icon-back", true)
  if chevOk then
    -- Atlas is a "back" chevron; use +pi/2 so it points down (not up). Keep default atlas tint (yellow/gold).
    chev:SetRotation(math.pi / 2)
  else
    chev:SetTexture("Interface\\Buttons\\UI-ScrollBar-ArrowButton-Down-Up")
    chev:SetVertexColor(0.82, 0.86, 0.92)
  end

  local txt = (ns.Fonts and ns.Fonts.CreateFontString(btn, "OVERLAY", "GameFontHighlightSmall", "all")) or btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  txt:SetPoint("LEFT", 10, 0)
  txt:SetPoint("RIGHT", chev, "LEFT", -6, 0)
  txt:SetJustifyH("LEFT")

  local list = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetFrameLevel(5000)
  list:Hide()
  O.StyleSurface(list, 0.98)

  local overlay = CreateFrame("Button", nil, UIParent)
  overlay:SetFrameStrata("FULLSCREEN_DIALOG")
  overlay:SetFrameLevel(4999)
  overlay:SetAllPoints(UIParent)
  overlay:SetAlpha(0)
  overlay:EnableMouse(true)
  overlay:Hide()
  overlay:SetScript("OnClick", function()
    list:Hide()
    overlay:Hide()
  end)

  local function labelForValue(v)
    for _, it in ipairs(items) do
      if it.value == v then return it.text end
    end
    return (items[1] and items[1].text) or ""
  end

  local rowH = 26
  local pad = 4
  local n = #items
  list:SetSize(w, pad * 2 + n * rowH)

  for i, it in ipairs(items) do
    local opt = CreateFrame("Button", nil, list, "BackdropTemplate")
    opt:SetSize(w - pad * 2, rowH - 2)
    opt:SetPoint("TOPLEFT", pad, -pad - (i - 1) * rowH)
    O.StyleSurface(opt, 0.88)
    opt:SetBackdropColor(0.12, 0.16, 0.22, 0.95)
    local ost = (ns.Fonts and ns.Fonts.CreateFontString(opt, "OVERLAY", "GameFontHighlightSmall", "all")) or opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ost:SetPoint("LEFT", 8, 0)
    ost:SetText(it.text)
    opt:SetScript("OnEnter", function(self) self:SetBackdropColor(0.18, 0.24, 0.32, 0.98) end)
    opt:SetScript("OnLeave", function(self) self:SetBackdropColor(0.12, 0.16, 0.22, 0.95) end)
    opt:SetScript("OnClick", function()
      setValue(it.value)
      list:Hide()
      overlay:Hide()
    end)
  end

  btn:SetScript("OnClick", function()
    if list:IsShown() then
      list:Hide()
      overlay:Hide()
      return
    end
    txt:SetText(labelForValue(getValue()))
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    overlay:Show()
    list:Show()
  end)

  function row:Refresh()
    txt:SetText(labelForValue(getValue()))
  end

  row:SetScript("OnHide", function()
    list:Hide()
    overlay:Hide()
  end)

  row:Refresh()
  return row
end

