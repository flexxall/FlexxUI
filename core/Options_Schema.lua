local _, ns = ...
local O = ns.Options

local function registerControl(ctrl)
  if ctrl and ctrl.Refresh then
    table.insert(O.state.controls, ctrl)
  end
end

local function makeNote(parent, text, width)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(width or 640, 1)
  local fs = O.ArtFont(row, "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", 0, 0)
  fs:SetWidth(width or 640)
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")
  local h = math.max(16, math.floor((fs:GetStringHeight() or 16) + 4))
  row:SetHeight(h)
  return row
end

local function controlHeight(ctrl)
  if not ctrl or not ctrl.GetHeight then return 24 end
  local h = ctrl:GetHeight()
  if type(h) ~= "number" or h <= 0 then return 24 end
  return h
end

local function buildControl(parent, def)
  if not def or not def.type then return nil end

  if def.type == "toggle" then
    return O.MakeToggle(parent, def.label or "", def.get, def.set, def.width or 520)
  end

  if def.type == "radio" then
    return O.MakeRadio(parent, def.label or "", def.get, def.value, def.set)
  end

  if def.type == "enum" then
    return O.MakeEnumSelect(parent, def.label or "", def.items or {}, def.get, def.set, def.width or 220)
  end

  if def.type == "slider_int" then
    return O.MakeIntSlider(parent, def.label or "", def.min or 0, def.max or 100, def.step or 1, def.get, def.set)
  end

  if def.type == "slider_scale_pct" then
    return O.MakeScalePercentSlider(parent, def.label or "", def.min or 80, def.max or 140, def.step or 1, def.get, def.set)
  end

  if def.type == "button" then
    return O.MakeFlatButton(parent, def.label or "Button", def.width or 220, def.height or 24, def.onClick)
  end

  if def.type == "custom" and type(def.build) == "function" then
    return def.build(parent)
  end

  if def.type == "note" then
    return makeNote(parent, def.text or "", def.width or 640)
  end

  if def.type == "spacer" then
    local spacer = CreateFrame("Frame", nil, parent)
    spacer:SetSize(1, def.height or 10)
    return spacer
  end

  return nil
end

--- Build a vertical settings card from declarative sections/controls.
--- spec = { sections = { { title, hint, controls = {...}, collapsedKey? }, ... } }
function O.BuildSchemaPage(content, spec)
  O.EnsureDB()
  local card = CreateFrame("Frame", nil, content, "BackdropTemplate")
  card:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  card:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  O.StyleSurface(card, (spec and spec.cardAlpha) or 0.80)
  card:SetBackdropColor(0.11, 0.13, 0.17, 0.78)
  card:SetBackdropBorderColor(0, 0, 0, 0)

  local sections = {}
  local secDefs = (spec and spec.sections) or {}
  local useSectionIndex = (spec and spec.sectionIndex == true) and (#secDefs >= 3)
  local useAdvancedToggle = (spec and spec.advancedToggle == true)
  local function isAdvancedShown()
    if not useAdvancedToggle then return true end
    return _G.FlexxUIDB and _G.FlexxUIDB.optionsShowAdvanced == true
  end
  local indexW = useSectionIndex and 170 or 0
  local contentRightPad = 12 + (useSectionIndex and (indexW + 8) or 0)

  local toolsFrame
  local indexFrame
  if useAdvancedToggle or useSectionIndex then
    toolsFrame = CreateFrame("Frame", nil, card)
    toolsFrame:SetPoint("TOPLEFT", 12, -10)
    toolsFrame:SetPoint("TOPRIGHT", -(contentRightPad), -10)
    toolsFrame:SetHeight(28)
  end

  if useSectionIndex then
    indexFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
    O.StyleSurface(indexFrame, 0.62)
    indexFrame:SetBackdropBorderColor(0, 0, 0, 0)
    indexFrame:SetPoint("TOPRIGHT", -12, -10)
    indexFrame:SetWidth(indexW)
    indexFrame:SetHeight(32)
  end

  local function sectionCollapsed(key, defaultValue)
    if not key then return defaultValue and true or false end
    O.EnsureDB()
    _G.FlexxUIDB.optionsCollapsed = _G.FlexxUIDB.optionsCollapsed or {}
    if _G.FlexxUIDB.optionsCollapsed[key] == nil then
      _G.FlexxUIDB.optionsCollapsed[key] = defaultValue and true or false
    end
    return _G.FlexxUIDB.optionsCollapsed[key] == true
  end

  local function setSectionCollapsed(key, v)
    if not key then return end
    O.EnsureDB()
    _G.FlexxUIDB.optionsCollapsed = _G.FlexxUIDB.optionsCollapsed or {}
    _G.FlexxUIDB.optionsCollapsed[key] = v and true or false
  end

  local function findScrollHolder()
    local p = content and content:GetParent()
    if p then p = p:GetParent() end
    return p
  end

  local function scrollToSection(sec)
    local holder = findScrollHolder()
    if not holder or not holder.scrollbar then return end
    local cTop = content:GetTop()
    local sTop = sec:GetTop()
    if not cTop or not sTop then return end
    local target = math.max(0, math.floor(cTop - sTop - 6))
    holder.scrollbar:SetValue(target)
  end

  local function relayout()
    local prev
    local totalH = 0
    for _, sec in ipairs(sections) do
      if sec._isAdvanced and not isAdvancedShown() then
        sec:Hide()
      else
        sec:Show()
      end
      if sec:IsShown() then
        sec:ClearAllPoints()
        if prev then
          sec:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10)
          sec:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -10)
        else
          if toolsFrame then
            sec:SetPoint("TOPLEFT", toolsFrame, "BOTTOMLEFT", 0, -8)
            sec:SetPoint("TOPRIGHT", card, "TOPRIGHT", -contentRightPad, -46)
          else
            sec:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -12)
            sec:SetPoint("TOPRIGHT", card, "TOPRIGHT", -contentRightPad, -12)
          end
        end
        totalH = totalH + sec:GetHeight() + 10
        prev = sec
      end
    end
    totalH = math.max(80, totalH + (toolsFrame and 52 or 14))
    if indexFrame then
      indexFrame:SetHeight(math.max(32, totalH - 20))
    end
    card:SetHeight(totalH)
    content:SetHeight(totalH)
    O.RefreshScrollPages()
  end

  local function buildSection(def)
    local sec = CreateFrame("Frame", nil, card, "BackdropTemplate")
    O.StyleSurface(sec, 0.70)
    sec:SetBackdropColor(0.08, 0.10, 0.14, 0.72)
    sec:SetBackdropBorderColor(0, 0, 0, 0)

    local hdrBtn = CreateFrame("Button", nil, sec)
    hdrBtn:SetPoint("TOPLEFT", 10, -8)
    hdrBtn:SetPoint("TOPRIGHT", -10, -8)
    hdrBtn:SetHeight(22)

    local arrow = hdrBtn:CreateTexture(nil, "OVERLAY")
    arrow:SetPoint("LEFT", 0, 0)
    arrow:SetSize(14, 14)
    if arrow.SetAtlas then
      pcall(arrow.SetAtlas, arrow, "common-dropdown-icon-back", true)
    end
    arrow:SetVertexColor(0.95, 0.78, 0.28)

    local title = O.ArtFont(hdrBtn, "GameFontHighlight")
    title:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
    title:SetText(def.title or "Section")

    local hint
    if def.hint and def.hint ~= "" then
      hint = O.ArtFont(sec, "GameFontHighlightSmall")
      hint:SetPoint("TOPLEFT", hdrBtn, "BOTTOMLEFT", 0, -2)
      hint:SetPoint("TOPRIGHT", hdrBtn, "BOTTOMRIGHT", 0, -2)
      hint:SetJustifyH("LEFT")
      hint:SetText(def.hint)
    end

    local body = CreateFrame("Frame", nil, sec)
    body:SetPoint("TOPLEFT", hint or hdrBtn, "BOTTOMLEFT", 0, -8)
    body:SetPoint("TOPRIGHT", hint or hdrBtn, "BOTTOMRIGHT", 0, -8)

    local rows = {}
    for _, cdef in ipairs(def.controls or {}) do
      local ctrl = buildControl(body, cdef)
      if ctrl then
        table.insert(rows, { ctrl = ctrl, def = cdef })
        registerControl(ctrl)
      end
    end

    local function layoutRows()
      local y = 0
      for i, row in ipairs(rows) do
        local cdef = row.def
        local ctrl = row.ctrl
        local show = not cdef.advanced or isAdvancedShown()
        ctrl:SetShown(show)
        if show then
          ctrl:ClearAllPoints()
          ctrl:SetPoint("TOPLEFT", 0, y)
          if cdef.type == "button" and cdef.align == "right" then
            ctrl:ClearAllPoints()
            ctrl:SetPoint("TOPRIGHT", 0, y)
          end
          y = y - controlHeight(ctrl) - (cdef.gapAfter or 8)
        end
        if i == #rows then y = y + 8 end
      end
      local bodyH = math.max(1, -y)
      body:SetHeight(bodyH)
      return bodyH
    end

    local collapsed = sectionCollapsed(def.collapsedKey, def.defaultCollapsed)
    local hdrH = 22 + ((hint and math.max(16, hint:GetStringHeight() or 16) + 2) or 0)
    local bodyH = layoutRows()
    local collapsedH = hdrH + 10

    local function applyCollapsed()
      bodyH = layoutRows()
      local expandedH = hdrH + 8 + bodyH + 10
      body:SetShown(not collapsed)
      if collapsed then
        arrow:SetRotation(math.pi)
        sec:SetHeight(collapsedH)
      else
        arrow:SetRotation(math.pi / 2)
        sec:SetHeight(expandedH)
      end
      relayout()
    end

    hdrBtn:SetScript("OnClick", function()
      collapsed = not collapsed
      setSectionCollapsed(def.collapsedKey, collapsed)
      applyCollapsed()
    end)

    sec._isAdvanced = def.advanced == true
    applyCollapsed()
    return sec
  end

  for _, secDef in ipairs(secDefs) do
    table.insert(sections, buildSection(secDef))
  end

  if toolsFrame and useAdvancedToggle then
    local adv = O.MakeToggle(toolsFrame, "Show advanced settings", isAdvancedShown, function(v)
      _G.FlexxUIDB.optionsShowAdvanced = v and true or false
      relayout()
      O.RefreshControls()
    end, 220)
    adv:SetPoint("TOPLEFT", toolsFrame, "TOPLEFT", 0, 0)
    registerControl(adv)
  end

  if indexFrame then
    local idxTitle = O.ArtFont(indexFrame, "GameFontHighlightSmall")
    idxTitle:SetPoint("TOPLEFT", 8, -8)
    idxTitle:SetText("Jump to section")
    local y = -28
    for i, sec in ipairs(sections) do
      local title = (secDefs[i] and secDefs[i].title) or ("Section " .. i)
      local b = O.MakeFlatButton(indexFrame, title, indexW - 16, 20, function()
        scrollToSection(sec)
      end)
      b:SetPoint("TOPLEFT", 8, y)
      y = y - 24
    end
  end

  relayout()
  return card
end
