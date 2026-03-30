local _, ns = ...
local O = ns.Options

local function ArtFont(parent, templateName)
  if ns.Fonts and ns.Fonts.CreateFontString then
    return ns.Fonts.CreateFontString(parent, "ARTWORK", templateName, "all")
  end
  return parent:CreateFontString(nil, "ARTWORK", templateName)
end

--[[ Options UI copy (find / tweak quickly):
  hdr*   — section titles
  lbl*   — labels for the control directly below
  hint*  — optional supplementary lines (short subtitles, version, placeholders, one-off notes).
           Grep "hint" in this file to list or edit all helper-style copy. ]]

local function nameColorOverrideDbKey(unitKey)
  if unitKey == "player" then return "nameTextColorOverridePlayer" end
  if unitKey == "target" then return "nameTextColorOverrideTarget" end
  if unitKey == "pet" then return "nameTextColorOverridePet" end
  return nil
end

--- Effective radio: "inherit" or class/white/yellow/dark (override).
local function getNameColorOverrideValue(unitKey)
  local k = nameColorOverrideDbKey(unitKey)
  if not k then return "inherit" end
  local o = _G.FlexxUIDB and _G.FlexxUIDB[k]
  if o == nil then return "inherit" end
  return o
end

local function setNameColorOverrideValue(unitKey, value)
  local mode = (value == "inherit") and nil or value
  if ns.UnitFrames and ns.UnitFrames.SetNameTextColorOverride then
    ns.UnitFrames.SetNameTextColorOverride(unitKey, mode)
  end
  O.RefreshControls()
end

local UNIT_PAGE_CONTENT_HEIGHT = 1480
local TARGET_SUBTAB_HEIGHT = { frame = UNIT_PAGE_CONTENT_HEIGHT, cast = 360 }
local PLAYER_SUBTAB_HEIGHT = { health = 810, power = 1220, classbar = 300, auras = 400, cast = 520, general = 450 }

local function addResourceBarLayoutSection(parent, below, gap)
  gap = gap or 16
  local hdr = ArtFont(parent, "GameFontHighlight")
  hdr:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -gap)
  hdr:SetText("Text on bar")

  local cbPowerShow = O.MakeToggle(parent, "Show text on resource bar", function()
    return _G.FlexxUIDB.powerTextShow ~= false
  end, function(v)
    _G.FlexxUIDB.powerTextShow = v
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextShow then ns.UnitFrames.SetPowerTextShow(v) end
  end, 300)
  cbPowerShow:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbPowerShow)

  local lblFmt = ArtFont(parent, "GameFontHighlightSmall")
  lblFmt:SetPoint("TOPLEFT", cbPowerShow, "BOTTOMLEFT", 0, -10)
  lblFmt:SetText("Number")

  local rbPowerPct = O.MakeRadio(parent, "Percent", function() return _G.FlexxUIDB.powerTextMode or "percent" end, "percent", function(mode)
    _G.FlexxUIDB.powerTextMode = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextMode then ns.UnitFrames.SetPowerTextMode(mode) end
    O.RefreshControls()
  end)
  rbPowerPct:SetPoint("TOPLEFT", lblFmt, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerPct)

  local rbPowerVal = O.MakeRadio(parent, "Current / maximum", function() return _G.FlexxUIDB.powerTextMode or "percent" end, "value", function(mode)
    _G.FlexxUIDB.powerTextMode = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextMode then ns.UnitFrames.SetPowerTextMode(mode) end
    O.RefreshControls()
  end)
  rbPowerVal:SetPoint("TOPLEFT", rbPowerPct, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerVal)

  local posHdr = ArtFont(parent, "GameFontHighlightSmall")
  posHdr:SetPoint("TOPLEFT", rbPowerVal, "BOTTOMLEFT", 0, -14)
  posHdr:SetText("Align")

  local rbPowerLeft = O.MakeRadio(parent, "Left", function() return _G.FlexxUIDB.powerTextAlign or "center" end, "left", function(align)
    _G.FlexxUIDB.powerTextAlign = align
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextAlign then ns.UnitFrames.SetPowerTextAlign(align) end
    O.RefreshControls()
  end)
  rbPowerLeft:SetPoint("TOPLEFT", posHdr, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerLeft)
  local rbPowerCenter = O.MakeRadio(parent, "Center", function() return _G.FlexxUIDB.powerTextAlign or "center" end, "center", function(align)
    _G.FlexxUIDB.powerTextAlign = align
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextAlign then ns.UnitFrames.SetPowerTextAlign(align) end
    O.RefreshControls()
  end)
  rbPowerCenter:SetPoint("TOPLEFT", rbPowerLeft, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerCenter)
  local rbPowerRight = O.MakeRadio(parent, "Right", function() return _G.FlexxUIDB.powerTextAlign or "center" end, "right", function(align)
    _G.FlexxUIDB.powerTextAlign = align
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextAlign then ns.UnitFrames.SetPowerTextAlign(align) end
    O.RefreshControls()
  end)
  rbPowerRight:SetPoint("TOPLEFT", rbPowerCenter, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerRight)
end

local function addResourceBarColorSection(parent, belowHdr, gap)
  gap = gap or 8

  --- Choosing a uniform color turns off split mode and syncs mana/other presets so "All resources" always works.
  local function applyUniformPowerTextColor(mode)
    O.EnsureDB()
    if _G.FlexxUIDB.powerTextColorSplit then
      _G.FlexxUIDB.powerTextColorSplit = false
      if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorSplit then ns.UnitFrames.SetPowerTextColorSplit(false) end
    end
    _G.FlexxUIDB.powerTextColorMode = mode
    _G.FlexxUIDB.powerTextColorMana = mode
    _G.FlexxUIDB.powerTextColorResource = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorMode then ns.UnitFrames.SetPowerTextColorMode(mode) end
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorMana then ns.UnitFrames.SetPowerTextColorMana(mode) end
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorResource then ns.UnitFrames.SetPowerTextColorResource(mode) end
    O.RefreshControls()
  end

  local cbSplit = O.MakeToggle(parent, "Separate text colors: mana vs other", function()
    return _G.FlexxUIDB.powerTextColorSplit == true
  end, function(v)
    _G.FlexxUIDB.powerTextColorSplit = v and true or false
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorSplit then ns.UnitFrames.SetPowerTextColorSplit(v) end
    O.RefreshControls()
  end)
  cbSplit:SetPoint("TOPLEFT", belowHdr, "BOTTOMLEFT", 0, -gap)
  table.insert(O.state.controls, cbSplit)

  local lblUniform = ArtFont(parent, "GameFontHighlightSmall")
  lblUniform:SetPoint("TOPLEFT", cbSplit, "BOTTOMLEFT", 0, -10)
  lblUniform:SetText("All resources")

  local rbPCWhite = O.MakeRadio(parent, "White", function() return _G.FlexxUIDB.powerTextColorMode or "white" end, "white", applyUniformPowerTextColor)
  rbPCWhite:SetPoint("TOPLEFT", lblUniform, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPCWhite)
  local rbPCClass = O.MakeRadio(parent, "Class color", function() return _G.FlexxUIDB.powerTextColorMode or "white" end, "class_color", applyUniformPowerTextColor)
  rbPCClass:SetPoint("TOPLEFT", rbPCWhite, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPCClass)
  local rbPCBar = O.MakeRadio(parent, "Match bar fill", function() return _G.FlexxUIDB.powerTextColorMode or "white" end, "power_bar", applyUniformPowerTextColor)
  rbPCBar:SetPoint("TOPLEFT", rbPCClass, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPCBar)
  local rbPCAmber = O.MakeRadio(parent, "Amber", function() return _G.FlexxUIDB.powerTextColorMode or "white" end, "amber", applyUniformPowerTextColor)
  rbPCAmber:SetPoint("TOPLEFT", rbPCBar, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPCAmber)
  local rbPCIce = O.MakeRadio(parent, "Ice blue", function() return _G.FlexxUIDB.powerTextColorMode or "white" end, "ice", applyUniformPowerTextColor)
  rbPCIce:SetPoint("TOPLEFT", rbPCAmber, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPCIce)

  local lblMana = ArtFont(parent, "GameFontHighlightSmall")
  lblMana:SetPoint("TOPLEFT", rbPCIce, "BOTTOMLEFT", 0, -12)
  lblMana:SetText("Mana")

  local rbMWhite = O.MakeRadio(parent, "White", function() return _G.FlexxUIDB.powerTextColorMana or "white" end, "white", function(mode)
    _G.FlexxUIDB.powerTextColorMana = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorMana then ns.UnitFrames.SetPowerTextColorMana(mode) end
    O.RefreshControls()
  end)
  rbMWhite:SetPoint("TOPLEFT", lblMana, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbMWhite)
  local rbMClass = O.MakeRadio(parent, "Class color", function() return _G.FlexxUIDB.powerTextColorMana or "white" end, "class_color", function(mode)
    _G.FlexxUIDB.powerTextColorMana = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorMana then ns.UnitFrames.SetPowerTextColorMana(mode) end
    O.RefreshControls()
  end)
  rbMClass:SetPoint("TOPLEFT", rbMWhite, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbMClass)
  local rbMBar = O.MakeRadio(parent, "Match bar fill", function() return _G.FlexxUIDB.powerTextColorMana or "white" end, "power_bar", function(mode)
    _G.FlexxUIDB.powerTextColorMana = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorMana then ns.UnitFrames.SetPowerTextColorMana(mode) end
    O.RefreshControls()
  end)
  rbMBar:SetPoint("TOPLEFT", rbMClass, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbMBar)
  local rbMAmber = O.MakeRadio(parent, "Amber", function() return _G.FlexxUIDB.powerTextColorMana or "white" end, "amber", function(mode)
    _G.FlexxUIDB.powerTextColorMana = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorMana then ns.UnitFrames.SetPowerTextColorMana(mode) end
    O.RefreshControls()
  end)
  rbMAmber:SetPoint("TOPLEFT", rbMBar, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbMAmber)
  local rbMIce = O.MakeRadio(parent, "Ice blue", function() return _G.FlexxUIDB.powerTextColorMana or "white" end, "ice", function(mode)
    _G.FlexxUIDB.powerTextColorMana = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorMana then ns.UnitFrames.SetPowerTextColorMana(mode) end
    O.RefreshControls()
  end)
  rbMIce:SetPoint("TOPLEFT", rbMAmber, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbMIce)

  local lblOther = ArtFont(parent, "GameFontHighlightSmall")
  lblOther:SetPoint("TOPLEFT", rbMIce, "BOTTOMLEFT", 0, -12)
  lblOther:SetText("Other (energy, rage, focus, …)")

  local rbRWhite = O.MakeRadio(parent, "White", function() return _G.FlexxUIDB.powerTextColorResource or "white" end, "white", function(mode)
    _G.FlexxUIDB.powerTextColorResource = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorResource then ns.UnitFrames.SetPowerTextColorResource(mode) end
    O.RefreshControls()
  end)
  rbRWhite:SetPoint("TOPLEFT", lblOther, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbRWhite)
  local rbRClass = O.MakeRadio(parent, "Class color", function() return _G.FlexxUIDB.powerTextColorResource or "white" end, "class_color", function(mode)
    _G.FlexxUIDB.powerTextColorResource = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorResource then ns.UnitFrames.SetPowerTextColorResource(mode) end
    O.RefreshControls()
  end)
  rbRClass:SetPoint("TOPLEFT", rbRWhite, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbRClass)
  local rbRBar = O.MakeRadio(parent, "Match bar fill", function() return _G.FlexxUIDB.powerTextColorResource or "white" end, "power_bar", function(mode)
    _G.FlexxUIDB.powerTextColorResource = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorResource then ns.UnitFrames.SetPowerTextColorResource(mode) end
    O.RefreshControls()
  end)
  rbRBar:SetPoint("TOPLEFT", rbRClass, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbRBar)
  local rbRAmber = O.MakeRadio(parent, "Amber", function() return _G.FlexxUIDB.powerTextColorResource or "white" end, "amber", function(mode)
    _G.FlexxUIDB.powerTextColorResource = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorResource then ns.UnitFrames.SetPowerTextColorResource(mode) end
    O.RefreshControls()
  end)
  rbRAmber:SetPoint("TOPLEFT", rbRBar, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbRAmber)
  local rbRIce = O.MakeRadio(parent, "Ice blue", function() return _G.FlexxUIDB.powerTextColorResource or "white" end, "ice", function(mode)
    _G.FlexxUIDB.powerTextColorResource = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerTextColorResource then ns.UnitFrames.SetPowerTextColorResource(mode) end
    O.RefreshControls()
  end)
  rbRIce:SetPoint("TOPLEFT", rbRAmber, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbRIce)

  local uniformRows = { rbPCWhite, rbPCClass, rbPCBar, rbPCAmber, rbPCIce }
  local manaRows = { rbMWhite, rbMClass, rbMBar, rbMAmber, rbMIce }
  local resourceRows = { rbRWhite, rbRClass, rbRBar, rbRAmber, rbRIce }
  local function UpdatePowerTextSplitRows()
    local split = _G.FlexxUIDB and _G.FlexxUIDB.powerTextColorSplit
    -- Uniform "All resources" stays clickable: picking one clears split (see applyUniformPowerTextColor).
    for _, row in ipairs(uniformRows) do
      if row and row.SetOptionEnabled then row:SetOptionEnabled(true) end
    end
    for _, row in ipairs(manaRows) do
      if row and row.SetOptionEnabled then row:SetOptionEnabled(split) end
    end
    for _, row in ipairs(resourceRows) do
      if row and row.SetOptionEnabled then row:SetOptionEnabled(split) end
    end
    lblUniform:SetAlpha(split and 0.65 or 1)
    lblMana:SetAlpha(split and 1 or 0.45)
    lblOther:SetAlpha(split and 1 or 0.45)
  end
  local oldSplitRef = cbSplit.Refresh
  cbSplit.Refresh = function(...)
    if oldSplitRef then oldSplitRef(...) end
    UpdatePowerTextSplitRows()
  end
  UpdatePowerTextSplitRows()
end

function O.BuildGeneralPage(content)
  O.EnsureDB()

  local settingsCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
  settingsCard:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  settingsCard:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  settingsCard:SetHeight(340)
  O.StyleSurface(settingsCard, 0.80)
  settingsCard:SetBackdropColor(0.11, 0.13, 0.17, 0.78)
  settingsCard:SetBackdropBorderColor(0, 0, 0, 0)

  local panelSettings = CreateFrame("Frame", nil, settingsCard)
  panelSettings:SetPoint("TOPLEFT", 14, -14)
  panelSettings:SetPoint("TOPRIGHT", -14, -14)
  panelSettings:SetHeight(306)

  local fontsCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
  fontsCard:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  fontsCard:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  fontsCard:SetHeight(600)
  O.StyleSurface(fontsCard, 0.80)
  fontsCard:SetBackdropColor(0.11, 0.13, 0.17, 0.78)
  fontsCard:SetBackdropBorderColor(0, 0, 0, 0)

  local fontsNav = CreateFrame("Frame", nil, fontsCard)
  fontsNav:SetPoint("TOPLEFT", 14, -14)
  fontsNav:SetPoint("TOPRIGHT", -14, -14)
  fontsNav:SetHeight(32)

  local btnFontsUI = O.MakeFontsSubTabButton(fontsNav, "UI", "ui")
  local btnFontsUnit = O.MakeFontsSubTabButton(fontsNav, "Unit", "unit", btnFontsUI)

  local panelFontsUI = CreateFrame("Frame", nil, fontsCard)
  local panelFontsUnit = CreateFrame("Frame", nil, fontsCard)
  for _, p in ipairs({ panelFontsUI, panelFontsUnit }) do
    p:SetPoint("TOPLEFT", fontsNav, "BOTTOMLEFT", 0, -10)
    p:SetPoint("TOPRIGHT", fontsNav, "BOTTOMRIGHT", 0, -10)
  end
  panelFontsUI:SetHeight(348)
  panelFontsUnit:SetHeight(478)

  local ver = ns.version or "dev"
  local welcomeTitle = ArtFont(panelSettings, "GameFontNormalLarge")
  welcomeTitle:SetPoint("TOPLEFT", 0, 0)
  welcomeTitle:SetText("Welcome to FlexxUI")

  local hintWelcomeVersion = ArtFont(panelSettings, "GameFontHighlightSmall")
  hintWelcomeVersion:SetPoint("TOPLEFT", welcomeTitle, "BOTTOMLEFT", 0, -6)
  hintWelcomeVersion:SetText("|cffaaaaaaVersion " .. ver .. "|r")

  local hdrBlizzard = ArtFont(panelSettings, "GameFontHighlight")
  hdrBlizzard:SetPoint("TOPLEFT", hintWelcomeVersion, "BOTTOMLEFT", 0, -16)
  hdrBlizzard:SetText("Blizzard frames")

  local cbHide = O.MakeToggle(panelSettings, "Hide Blizzard player/target frames (experimental)", function()
    return _G.FlexxUIDB.hideBlizzard
  end, function(v)
    _G.FlexxUIDB.hideBlizzard = v
    if ns.UnitFrames and ns.UnitFrames.ApplyHideBlizzard then ns.UnitFrames.ApplyHideBlizzard() end
  end)
  cbHide:SetPoint("TOPLEFT", hdrBlizzard, "BOTTOMLEFT", 0, -6)
  table.insert(O.state.controls, cbHide)

  local hdrMinimap = ArtFont(panelSettings, "GameFontHighlight")
  hdrMinimap:SetPoint("TOPLEFT", cbHide, "BOTTOMLEFT", 0, -18)
  hdrMinimap:SetText("Minimap")

  local cbShowMinimap = O.MakeToggle(panelSettings, "Show minimap button", function()
    return _G.FlexxUIDB.minimapButtonShow ~= false
  end, function(v)
    _G.FlexxUIDB.minimapButtonShow = v and true or false
    if ns.Minimap and ns.Minimap.ApplyVisibility then
      ns.Minimap.ApplyVisibility()
    end
  end)
  cbShowMinimap:SetPoint("TOPLEFT", hdrMinimap, "BOTTOMLEFT", 0, -6)
  table.insert(O.state.controls, cbShowMinimap)

  local hdrMaint = ArtFont(panelSettings, "GameFontHighlight")
  hdrMaint:SetPoint("TOPLEFT", cbShowMinimap, "BOTTOMLEFT", 0, -18)
  hdrMaint:SetText("Maintenance")

  local reloadBtn = O.MakeFlatButton(panelSettings, "Reload UI", nil, nil, function() ReloadUI() end)
  reloadBtn:SetPoint("TOPLEFT", hdrMaint, "BOTTOMLEFT", 0, -6)
  local resetBtn = O.MakeFlatButton(panelSettings, "Reset Settings", nil, nil, function()
    if ns.DB and ns.DB.Reset then ns.DB.Reset() else _G.FlexxUIDB = {} end
    ReloadUI()
  end)
  resetBtn:SetPoint("LEFT", reloadBtn, "RIGHT", 12, 0)

  local hdrLayout = ArtFont(panelSettings, "GameFontHighlight")
  hdrLayout:SetPoint("TOPLEFT", reloadBtn, "BOTTOMLEFT", 0, -14)
  hdrLayout:SetText("Layout & positions")

  local resetPosBtn = O.MakeFlatButton(panelSettings, "Reset positions", nil, nil, function()
    if ns.Movers and ns.Movers.ResetSavedPositions then ns.Movers.ResetSavedPositions() end
    ReloadUI()
  end)
  resetPosBtn:SetPoint("TOPLEFT", hdrLayout, "BOTTOMLEFT", 0, -6)

  local fontUiHdr = ArtFont(panelFontsUI, "GameFontHighlight")
  fontUiHdr:SetPoint("TOPLEFT", 0, 0)
  fontUiHdr:SetText("Settings panel and options chrome")

  local rbUiDef = O.MakeRadio(panelFontsUI, "Default (Blizzard templates)", function() return _G.FlexxUIDB.flexxUIFontPresetUI or "default" end, "default", function(mode)
    _G.FlexxUIDB.flexxUIFontPresetUI = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end)
  rbUiDef:SetPoint("TOPLEFT", fontUiHdr, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbUiDef)

  local rbUiFriz = O.MakeRadio(panelFontsUI, "Friz Quadrata", function() return _G.FlexxUIDB.flexxUIFontPresetUI or "default" end, "friz", function(mode)
    _G.FlexxUIDB.flexxUIFontPresetUI = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end)
  rbUiFriz:SetPoint("TOPLEFT", rbUiDef, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbUiFriz)

  local rbUiArial = O.MakeRadio(panelFontsUI, "Arial Narrow", function() return _G.FlexxUIDB.flexxUIFontPresetUI or "default" end, "arial_narrow", function(mode)
    _G.FlexxUIDB.flexxUIFontPresetUI = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end)
  rbUiArial:SetPoint("TOPLEFT", rbUiFriz, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbUiArial)

  local rbUiRoboto = O.MakeRadio(panelFontsUI, "Roboto Condensed Bold", function() return _G.FlexxUIDB.flexxUIFontPresetUI or "default" end, "roboto_condensed", function(mode)
    _G.FlexxUIDB.flexxUIFontPresetUI = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end)
  rbUiRoboto:SetPoint("TOPLEFT", rbUiArial, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbUiRoboto)

  local scaleUi = O.MakeScalePercentSlider(panelFontsUI, "Size (relative to template)", 70, 150, 5, function()
    return _G.FlexxUIDB.flexxUIFontScaleUI or 1
  end, function(s)
    _G.FlexxUIDB.flexxUIFontScaleUI = s
  end)
  scaleUi:SetPoint("TOPLEFT", rbUiRoboto, "BOTTOMLEFT", 0, -16)
  table.insert(O.state.controls, scaleUi)

  local fontUnitHdr = ArtFont(panelFontsUnit, "GameFontHighlight")
  fontUnitHdr:SetPoint("TOPLEFT", 0, 0)
  fontUnitHdr:SetText("Player / target / pet frames and FlexxUI cast bars")

  local rbUDef = O.MakeRadio(panelFontsUnit, "Default (Blizzard templates)", function() return _G.FlexxUIDB.flexxUIFontPresetUnit or "default" end, "default", function(mode)
    _G.FlexxUIDB.flexxUIFontPresetUnit = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end)
  rbUDef:SetPoint("TOPLEFT", fontUnitHdr, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbUDef)

  local rbUFriz = O.MakeRadio(panelFontsUnit, "Friz Quadrata", function() return _G.FlexxUIDB.flexxUIFontPresetUnit or "default" end, "friz", function(mode)
    _G.FlexxUIDB.flexxUIFontPresetUnit = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end)
  rbUFriz:SetPoint("TOPLEFT", rbUDef, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbUFriz)

  local rbUArial = O.MakeRadio(panelFontsUnit, "Arial Narrow", function() return _G.FlexxUIDB.flexxUIFontPresetUnit or "default" end, "arial_narrow", function(mode)
    _G.FlexxUIDB.flexxUIFontPresetUnit = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end)
  rbUArial:SetPoint("TOPLEFT", rbUFriz, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbUArial)

  local rbURoboto = O.MakeRadio(panelFontsUnit, "Roboto Condensed Bold", function() return _G.FlexxUIDB.flexxUIFontPresetUnit or "default" end, "roboto_condensed", function(mode)
    _G.FlexxUIDB.flexxUIFontPresetUnit = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end)
  rbURoboto:SetPoint("TOPLEFT", rbUArial, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbURoboto)

  local scaleUnit = O.MakeScalePercentSlider(panelFontsUnit, "Size (relative to template or preset)", 70, 150, 5, function()
    return _G.FlexxUIDB.flexxUIFontScaleUnit or 1
  end, function(s)
    _G.FlexxUIDB.flexxUIFontScaleUnit = s
  end)
  scaleUnit:SetPoint("TOPLEFT", rbURoboto, "BOTTOMLEFT", 0, -16)
  table.insert(O.state.controls, scaleUnit)

  local nameColorDefaultHdr = ArtFont(panelFontsUnit, "GameFontHighlight")
  nameColorDefaultHdr:SetPoint("TOPLEFT", scaleUnit, "BOTTOMLEFT", 0, -20)
  nameColorDefaultHdr:SetText("Unit name text color (default)")

  local rbNmClass = O.MakeRadio(panelFontsUnit, "Class color", function() return _G.FlexxUIDB.nameTextColorMode or "class" end, "class", function(mode)
    _G.FlexxUIDB.nameTextColorMode = mode
    if ns.UnitFrames and ns.UnitFrames.SetNameTextColorMode then ns.UnitFrames.SetNameTextColorMode(mode) end
    O.RefreshControls()
  end)
  rbNmClass:SetPoint("TOPLEFT", nameColorDefaultHdr, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbNmClass)

  local rbNmWhite = O.MakeRadio(panelFontsUnit, "White", function() return _G.FlexxUIDB.nameTextColorMode or "class" end, "white", function(mode)
    _G.FlexxUIDB.nameTextColorMode = mode
    if ns.UnitFrames and ns.UnitFrames.SetNameTextColorMode then ns.UnitFrames.SetNameTextColorMode(mode) end
    O.RefreshControls()
  end)
  rbNmWhite:SetPoint("TOPLEFT", rbNmClass, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbNmWhite)

  local rbNmYellow = O.MakeRadio(panelFontsUnit, "Warm yellow", function() return _G.FlexxUIDB.nameTextColorMode or "class" end, "yellow", function(mode)
    _G.FlexxUIDB.nameTextColorMode = mode
    if ns.UnitFrames and ns.UnitFrames.SetNameTextColorMode then ns.UnitFrames.SetNameTextColorMode(mode) end
    O.RefreshControls()
  end)
  rbNmYellow:SetPoint("TOPLEFT", rbNmWhite, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbNmYellow)

  local rbNmDark = O.MakeRadio(panelFontsUnit, "Dark (near black)", function() return _G.FlexxUIDB.nameTextColorMode or "class" end, "dark", function(mode)
    _G.FlexxUIDB.nameTextColorMode = mode
    if ns.UnitFrames and ns.UnitFrames.SetNameTextColorMode then ns.UnitFrames.SetNameTextColorMode(mode) end
    O.RefreshControls()
  end)
  rbNmDark:SetPoint("TOPLEFT", rbNmYellow, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbNmDark)

  O.state.applyGeneralSubTab = function()
    local sub = _G.FlexxUIDB.optionsGeneralSubTab or "settings"
    if sub ~= "settings" and sub ~= "fonts" then
      sub = "settings"
    end
    settingsCard:SetShown(sub == "settings")
    fontsCard:SetShown(sub == "fonts")
    for _, b in pairs(O.state.generalNavButtons) do
      if b and b.RefreshGeneralNav then b:RefreshGeneralNav() end
    end
    if sub == "fonts" and O.state.applyFontsSubTab then
      O.state.applyFontsSubTab()
    end
  end

  O.state.applyFontsSubTab = function()
    local fsub = _G.FlexxUIDB.optionsFontsSubTab or "ui"
    panelFontsUI:SetShown(fsub == "ui")
    panelFontsUnit:SetShown(fsub == "unit")
    for _, b in pairs(O.state.fontsSubTabButtons) do
      if b and b.RefreshFontsSub then b:RefreshFontsSub() end
    end
  end

  O.state.applyGeneralSubTab()
  content:SetHeight(700)
end

function O.BuildDevPage(content)
  local DEV_PANEL_CAST = 200
  local DEV_PANEL_AURAS = 900

  local devCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
  O.StyleSurface(devCard, 0.80)
  devCard:SetBackdropColor(0.11, 0.13, 0.17, 0.78)
  devCard:SetBackdropBorderColor(0, 0, 0, 0)

  local panelCast = CreateFrame("Frame", nil, devCard)
  local panelAuras = CreateFrame("Frame", nil, devCard)
  for _, p in ipairs({ panelCast, panelAuras }) do
    p:SetPoint("TOPLEFT", 14, -14)
    p:SetPoint("TOPRIGHT", -14, -14)
  end
  panelCast:SetHeight(DEV_PANEL_CAST)
  panelAuras:SetHeight(DEV_PANEL_AURAS)

  local secCast = ArtFont(panelCast, "GameFontHighlight")
  secCast:SetPoint("TOPLEFT", 0, 0)
  secCast:SetText("Cast bars")

  local cbCastIdle = O.MakeToggle(panelCast, "Show empty player cast bar when not casting", function()
    return _G.FlexxUIDB.castBarShowIdle == true
  end, function(v)
    _G.FlexxUIDB.castBarShowIdle = v and true or false
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
  end, 520)
  cbCastIdle:SetPoint("TOPLEFT", secCast, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbCastIdle)

  local cbCastTargetIdle = O.MakeToggle(panelCast, "Show empty target cast bar when not casting", function()
    return _G.FlexxUIDB.castBarTargetShowIdle == true
  end, function(v)
    _G.FlexxUIDB.castBarTargetShowIdle = v and true or false
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
  end, 520)
  cbCastTargetIdle:SetPoint("TOPLEFT", cbCastIdle, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbCastTargetIdle)

  local secAuras = ArtFont(panelAuras, "GameFontHighlight")
  secAuras:SetPoint("TOPLEFT", 0, 0)
  secAuras:SetText("Player frame auras (layout & preview)")

  local function refreshAuraLayout()
    if ns.UnitFrames and ns.UnitFrames.RefreshAurasFromOptions then ns.UnitFrames.RefreshAurasFromOptions() end
  end

  local cbPrevBuff = O.MakeToggle(panelAuras, "Preview buff row (placeholder icons)", function()
    return _G.FlexxUIDB.unitFrameAuraDevPreviewBuff == true
  end, function(v)
    _G.FlexxUIDB.unitFrameAuraDevPreviewBuff = v and true or false
    refreshAuraLayout()
  end, 520)
  cbPrevBuff:SetPoint("TOPLEFT", secAuras, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbPrevBuff)

  local cbPrevDebuff = O.MakeToggle(panelAuras, "Preview debuff row (placeholder icons)", function()
    return _G.FlexxUIDB.unitFrameAuraDevPreviewDebuff == true
  end, function(v)
    _G.FlexxUIDB.unitFrameAuraDevPreviewDebuff = v and true or false
    refreshAuraLayout()
  end, 520)
  cbPrevDebuff:SetPoint("TOPLEFT", cbPrevBuff, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbPrevDebuff)

  local cbPrevBars = O.MakeToggle(panelAuras, "Preview debuff timer bars", function()
    return _G.FlexxUIDB.unitFrameAuraDevPreviewBars == true
  end, function(v)
    _G.FlexxUIDB.unitFrameAuraDevPreviewBars = v and true or false
    refreshAuraLayout()
  end, 520)
  cbPrevBars:SetPoint("TOPLEFT", cbPrevDebuff, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbPrevBars)

  local slBuffX = O.MakeIntSlider(panelAuras, "Buff row: offset left / right (px)", -80, 80, 1, function()
    return _G.FlexxUIDB.playerAuraBuffAnchorX or 0
  end, function(v)
    _G.FlexxUIDB.playerAuraBuffAnchorX = v
    refreshAuraLayout()
  end)
  slBuffX:SetPoint("TOPLEFT", cbPrevBars, "BOTTOMLEFT", 0, -14)
  table.insert(O.state.controls, slBuffX)

  local slBuffY = O.MakeIntSlider(panelAuras, "Buff row: offset up / down (px)", -80, 80, 1, function()
    return _G.FlexxUIDB.playerAuraBuffAnchorY or 36
  end, function(v)
    _G.FlexxUIDB.playerAuraBuffAnchorY = v
    refreshAuraLayout()
  end)
  slBuffY:SetPoint("TOPLEFT", slBuffX, "BOTTOMLEFT", 0, -4)
  table.insert(O.state.controls, slBuffY)

  local slDebuffX = O.MakeIntSlider(panelAuras, "Debuff icons / timer bars: offset left / right (px)", -80, 80, 1, function()
    return _G.FlexxUIDB.playerAuraDebuffAnchorX or 0
  end, function(v)
    _G.FlexxUIDB.playerAuraDebuffAnchorX = v
    refreshAuraLayout()
  end)
  slDebuffX:SetPoint("TOPLEFT", slBuffY, "BOTTOMLEFT", 0, -4)
  table.insert(O.state.controls, slDebuffX)

  local slDebuffY = O.MakeIntSlider(panelAuras, "Debuff icons / timer bars: offset up / down (px)", -80, 80, 1, function()
    return _G.FlexxUIDB.playerAuraDebuffAnchorY or 4
  end, function(v)
    _G.FlexxUIDB.playerAuraDebuffAnchorY = v
    refreshAuraLayout()
  end)
  slDebuffY:SetPoint("TOPLEFT", slDebuffX, "BOTTOMLEFT", 0, -4)
  table.insert(O.state.controls, slDebuffY)

  O.state.applyDevSubTab = function()
    O.EnsureDB()
    local key = (_G.FlexxUIDB and _G.FlexxUIDB.optionsDevSubTab) or "cast"
    if key ~= "cast" and key ~= "auras" then key = "cast" end
    panelCast:SetShown(key == "cast")
    panelAuras:SetShown(key == "auras")
  end
  O.state.applyDevSubTab()

  -- Scroll content must have height; devCard must fill it or the frame stays 0 tall and ClipsChildren hides everything.
  local contentH = math.max(DEV_PANEL_CAST, DEV_PANEL_AURAS) + 40
  content:SetHeight(contentH)
  devCard:ClearAllPoints()
  devCard:SetAllPoints(content)

  if O.state.pageHolders and O.state.pageHolders.dev and O.state.pageHolders.dev.RefreshScroll then
    O.state.pageHolders.dev:RefreshScroll()
  end
end

function O.BuildUnitPlayerPage(content)
  local playerCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
  playerCard:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  playerCard:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  O.StyleSurface(playerCard, 0.80)
  playerCard:SetBackdropColor(0.11, 0.13, 0.17, 0.78)
  playerCard:SetBackdropBorderColor(0, 0, 0, 0)

  local playerNav = CreateFrame("Frame", nil, playerCard)
  playerNav:SetPoint("TOPLEFT", 14, -14)
  playerNav:SetPoint("TOPRIGHT", -14, -14)
  playerNav:SetHeight(32)

  local btnHealth = O.MakePlayerSubTabButton(playerNav, "Health bar", "health")
  local btnPower = O.MakePlayerSubTabButton(playerNav, "Resource bar", "power", btnHealth)
  local btnClassBar = O.MakePlayerSubTabButton(playerNav, "Class bar", "classbar", btnPower)
  local btnAuras = O.MakePlayerSubTabButton(playerNav, "Auras", "auras", btnClassBar)
  local btnCast = O.MakePlayerSubTabButton(playerNav, "Cast bar", "cast", btnAuras)
  local btnGeneral = O.MakePlayerSubTabButton(playerNav, "Name & text", "general", btnCast)

  local panelHealth = CreateFrame("Frame", nil, playerCard)
  local panelPower = CreateFrame("Frame", nil, playerCard)
  local panelClassBar = CreateFrame("Frame", nil, playerCard)
  local panelAuras = CreateFrame("Frame", nil, playerCard)
  local panelCast = CreateFrame("Frame", nil, playerCard)
  local panelGeneral = CreateFrame("Frame", nil, playerCard)
  for _, p in ipairs({ panelHealth, panelPower, panelClassBar, panelAuras, panelCast, panelGeneral }) do
    p:SetPoint("TOPLEFT", playerNav, "BOTTOMLEFT", 0, -10)
    p:SetPoint("TOPRIGHT", playerNav, "BOTTOMRIGHT", 0, -10)
  end
  -- Without explicit height, panel height stays 0 → scroll holder clips everything (empty UI).
  panelHealth:SetHeight(PLAYER_SUBTAB_HEIGHT.health)
  panelPower:SetHeight(PLAYER_SUBTAB_HEIGHT.power)
  panelClassBar:SetHeight(PLAYER_SUBTAB_HEIGHT.classbar)
  panelAuras:SetHeight(PLAYER_SUBTAB_HEIGHT.auras)
  panelCast:SetHeight(PLAYER_SUBTAB_HEIGHT.cast)
  panelGeneral:SetHeight(PLAYER_SUBTAB_HEIGHT.general)

  -- ——— Health bar tab ———
  local leftH = CreateFrame("Frame", nil, panelHealth)
  leftH:SetPoint("TOPLEFT", 0, 0); leftH:SetSize(320, PLAYER_SUBTAB_HEIGHT.health)
  local rightH = CreateFrame("Frame", nil, panelHealth)
  rightH:SetPoint("TOPLEFT", 332, 0); rightH:SetSize(320, PLAYER_SUBTAB_HEIGHT.health)

  local lbl1 = ArtFont(leftH, "GameFontHighlight"); lbl1:SetPoint("TOPLEFT", 0, 0); lbl1:SetText("Health Bar: color")
  local rbClass = O.MakeRadio(leftH, "Class color", function() return _G.FlexxUIDB.playerHealthColorMode end, "class", function(mode)
    _G.FlexxUIDB.playerHealthColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetPlayerHealthColorMode then ns.UnitFrames.SetPlayerHealthColorMode(mode) end; O.RefreshControls()
  end); rbClass:SetPoint("TOPLEFT", lbl1, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbClass)
  local rbBlizzard = O.MakeRadio(leftH, "Blizzard green", function() return _G.FlexxUIDB.playerHealthColorMode end, "blizzard", function(mode)
    _G.FlexxUIDB.playerHealthColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetPlayerHealthColorMode then ns.UnitFrames.SetPlayerHealthColorMode(mode) end; O.RefreshControls()
  end); rbBlizzard:SetPoint("TOPLEFT", rbClass, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbBlizzard)
  local rbDark = O.MakeRadio(leftH, "Dark zinc / charcoal", function() return _G.FlexxUIDB.playerHealthColorMode end, "dark", function(mode)
    _G.FlexxUIDB.playerHealthColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetPlayerHealthColorMode then ns.UnitFrames.SetPlayerHealthColorMode(mode) end; O.RefreshControls()
  end); rbDark:SetPoint("TOPLEFT", rbBlizzard, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbDark)

  local cbUnitBackdrop = O.MakeToggle(leftH, "Show unit frame panel background", function()
    return _G.FlexxUIDB.unitFrameBackdropShow ~= false
  end, function(v)
    _G.FlexxUIDB.unitFrameBackdropShow = v
    if ns.UnitFrames and ns.UnitFrames.SetUnitFrameBackdropShow then ns.UnitFrames.SetUnitFrameBackdropShow(v) end
  end, 300)
  cbUnitBackdrop:SetPoint("TOPLEFT", rbDark, "BOTTOMLEFT", 0, -20)
  table.insert(O.state.controls, cbUnitBackdrop)

  local lbl3 = ArtFont(leftH, "GameFontHighlight"); lbl3:SetPoint("TOPLEFT", cbUnitBackdrop, "BOTTOMLEFT", 0, -20); lbl3:SetText("Health value: format")
  local rbPct = O.MakeRadio(leftH, "Show percent", function() return _G.FlexxUIDB.healthTextMode end, "percent", function(mode)
    _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls()
  end); rbPct:SetPoint("TOPLEFT", lbl3, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbPct)
  local rbVal = O.MakeRadio(leftH, "Show value", function() return _G.FlexxUIDB.healthTextMode end, "value", function(mode)
    _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls()
  end); rbVal:SetPoint("TOPLEFT", rbPct, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbVal)
  local rbHide = O.MakeRadio(leftH, "Hide health text", function() return _G.FlexxUIDB.healthTextMode end, "none", function(mode)
    _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls()
  end); rbHide:SetPoint("TOPLEFT", rbVal, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbHide)

  local lblPos = ArtFont(leftH, "GameFontHighlight"); lblPos:SetPoint("TOPLEFT", rbHide, "BOTTOMLEFT", 0, -20); lblPos:SetText("Health value: position")
  local rbAlignRight = O.MakeRadio(leftH, "Right", function() return _G.FlexxUIDB.healthTextAlign or "right" end, "right", function(align)
    _G.FlexxUIDB.healthTextAlign = align
    if ns.UnitFrames and ns.UnitFrames.SetHealthTextAlign then ns.UnitFrames.SetHealthTextAlign(align) end
    O.RefreshControls()
  end); rbAlignRight:SetPoint("TOPLEFT", lblPos, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbAlignRight)
  local rbAlignCenter = O.MakeRadio(leftH, "Center", function() return _G.FlexxUIDB.healthTextAlign or "right" end, "center", function(align)
    _G.FlexxUIDB.healthTextAlign = align
    if ns.UnitFrames and ns.UnitFrames.SetHealthTextAlign then ns.UnitFrames.SetHealthTextAlign(align) end
    O.RefreshControls()
  end); rbAlignCenter:SetPoint("TOPLEFT", rbAlignRight, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbAlignCenter)

  local lbl2 = ArtFont(rightH, "GameFontHighlight"); lbl2:SetPoint("TOPLEFT", 0, 0); lbl2:SetText("Health Bar: texture")
  local rbTexNone = O.MakeRadio(rightH, "None (solid color)", function() return _G.FlexxUIDB.healthBarTexture end, "none", function(name)
    _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls()
  end); rbTexNone:SetPoint("TOPLEFT", lbl2, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbTexNone)
  local rbTexDefault = O.MakeRadio(rightH, "Default", function() return _G.FlexxUIDB.healthBarTexture end, "default", function(name)
    _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls()
  end); rbTexDefault:SetPoint("TOPLEFT", rbTexNone, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbTexDefault)
  local rbTexFlat = O.MakeRadio(rightH, "Flat", function() return _G.FlexxUIDB.healthBarTexture end, "flat", function(name)
    _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls()
  end); rbTexFlat:SetPoint("TOPLEFT", rbTexDefault, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbTexFlat)
  local rbTexSmooth = O.MakeRadio(rightH, "Smooth", function() return _G.FlexxUIDB.healthBarTexture end, "smooth", function(name)
    _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls()
  end); rbTexSmooth:SetPoint("TOPLEFT", rbTexFlat, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbTexSmooth)

  local lbl4 = ArtFont(rightH, "GameFontHighlight"); lbl4:SetPoint("TOPLEFT", rbTexSmooth, "BOTTOMLEFT", 0, -20); lbl4:SetText("Health value: color")
  local rbHCName = O.MakeRadio(rightH, "Class color", function() return _G.FlexxUIDB.healthTextColorMode end, "name", function(mode)
    _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls()
  end); rbHCName:SetPoint("TOPLEFT", lbl4, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbHCName)
  local rbHCBar = O.MakeRadio(rightH, "Match health bar", function() return _G.FlexxUIDB.healthTextColorMode end, "classdark", function(mode)
    _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls()
  end); rbHCBar:SetPoint("TOPLEFT", rbHCName, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbHCBar)
  local rbHCSolid = O.MakeRadio(rightH, "Solid light gray", function() return _G.FlexxUIDB.healthTextColorMode end, "solid", function(mode)
    _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls()
  end); rbHCSolid:SetPoint("TOPLEFT", rbHCBar, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbHCSolid)

  local leftP = CreateFrame("Frame", nil, panelPower)
  leftP:SetPoint("TOPLEFT", 0, 0); leftP:SetSize(320, PLAYER_SUBTAB_HEIGHT.power)
  local rightP = CreateFrame("Frame", nil, panelPower)
  rightP:SetPoint("TOPLEFT", 332, 0); rightP:SetSize(320, PLAYER_SUBTAB_HEIGHT.power)

  local lblLayout = ArtFont(leftP, "GameFontHighlight")
  lblLayout:SetPoint("TOPLEFT", 0, 0)
  lblLayout:SetText("Layout")

  local rbPowerLayoutFull = O.MakeRadio(leftP, "Full width below health", function() return _G.FlexxUIDB.powerBarLayout or "full" end, "full", function(mode)
    _G.FlexxUIDB.powerBarLayout = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerBarLayout then ns.UnitFrames.SetPowerBarLayout(mode) end
    O.RefreshControls()
  end)
  rbPowerLayoutFull:SetPoint("TOPLEFT", lblLayout, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerLayoutFull)

  local rbPowerLayoutInset = O.MakeRadio(leftP, "Inset (overlaps health)", function() return _G.FlexxUIDB.powerBarLayout or "full" end, "inset", function(mode)
    _G.FlexxUIDB.powerBarLayout = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerBarLayout then ns.UnitFrames.SetPowerBarLayout(mode) end
    O.RefreshControls()
  end)
  rbPowerLayoutInset:SetPoint("TOPLEFT", rbPowerLayoutFull, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerLayoutInset)

  local lblBarFill = ArtFont(leftP, "GameFontHighlight")
  lblBarFill:SetPoint("TOPLEFT", rbPowerLayoutInset, "BOTTOMLEFT", 0, -14)
  lblBarFill:SetText("Bar fill")

  local rbPowerStyleDef = O.MakeRadio(leftP, "Default (bright)", function() return _G.FlexxUIDB.powerBarColorStyle or "default" end, "default", function(mode)
    _G.FlexxUIDB.powerBarColorStyle = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerBarColorStyle then ns.UnitFrames.SetPowerBarColorStyle(mode) end
    O.RefreshControls()
  end)
  rbPowerStyleDef:SetPoint("TOPLEFT", lblBarFill, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerStyleDef)

  local rbPowerStyleDark = O.MakeRadio(leftP, "Dark (muted)", function() return _G.FlexxUIDB.powerBarColorStyle or "default" end, "dark", function(mode)
    _G.FlexxUIDB.powerBarColorStyle = mode
    if ns.UnitFrames and ns.UnitFrames.SetPowerBarColorStyle then ns.UnitFrames.SetPowerBarColorStyle(mode) end
    O.RefreshControls()
  end)
  rbPowerStyleDark:SetPoint("TOPLEFT", rbPowerStyleDef, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPowerStyleDark)

  addResourceBarLayoutSection(leftP, rbPowerStyleDark, 16)

  local lblResTextColor = ArtFont(rightP, "GameFontHighlight")
  lblResTextColor:SetPoint("TOPLEFT", 0, 0)
  lblResTextColor:SetText("Text color")

  addResourceBarColorSection(rightP, lblResTextColor, 8)

  -- Class bar tab (secondary resource pips)
  local leftCB = CreateFrame("Frame", nil, panelClassBar)
  leftCB:SetPoint("TOPLEFT", 0, 0)
  leftCB:SetPoint("TOPRIGHT", 0, 0)
  leftCB:SetHeight(PLAYER_SUBTAB_HEIGHT.classbar)

  local classBarHdr = ArtFont(leftCB, "GameFontHighlight")
  classBarHdr:SetPoint("TOPLEFT", 0, 0)
  classBarHdr:SetText("Class bar (combo, holy power, chi, shards, …)")

  local cbClassPips = O.MakeToggle(leftCB, "Show class resource pips", function()
    return _G.FlexxUIDB.showSecondaryResource ~= false
  end, function(v)
    _G.FlexxUIDB.showSecondaryResource = v
    if ns.UnitFrames and ns.UnitFrames.SetShowSecondaryResource then ns.UnitFrames.SetShowSecondaryResource(v) end
  end)
  cbClassPips:SetPoint("TOPLEFT", classBarHdr, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbClassPips)

  local lblClassPipStyle = ArtFont(leftCB, "GameFontHighlight")
  lblClassPipStyle:SetPoint("TOPLEFT", cbClassPips, "BOTTOMLEFT", 0, -20)
  lblClassPipStyle:SetText("Pip colors")

  local rbClassBarDef = O.MakeRadio(leftCB, "Default (bright)", function() return _G.FlexxUIDB.classBarColorStyle or "default" end, "default", function(mode)
    _G.FlexxUIDB.classBarColorStyle = mode
    if ns.UnitFrames and ns.UnitFrames.SetClassBarColorStyle then ns.UnitFrames.SetClassBarColorStyle(mode) end
    O.RefreshControls()
  end)
  rbClassBarDef:SetPoint("TOPLEFT", lblClassPipStyle, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbClassBarDef)

  local rbClassBarDark = O.MakeRadio(leftCB, "Dark (muted)", function() return _G.FlexxUIDB.classBarColorStyle or "default" end, "dark", function(mode)
    _G.FlexxUIDB.classBarColorStyle = mode
    if ns.UnitFrames and ns.UnitFrames.SetClassBarColorStyle then ns.UnitFrames.SetClassBarColorStyle(mode) end
    O.RefreshControls()
  end)
  rbClassBarDark:SetPoint("TOPLEFT", rbClassBarDef, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbClassBarDark)

  -- ——— Auras tab (player frame only; target gets its own tab later) ———
  local leftAura = CreateFrame("Frame", nil, panelAuras)
  leftAura:SetPoint("TOPLEFT", 0, 0)
  leftAura:SetPoint("TOPRIGHT", 0, 0)
  leftAura:SetHeight(PLAYER_SUBTAB_HEIGHT.auras)

  local auraIntro = ArtFont(leftAura, "GameFontHighlightSmall")
  auraIntro:SetPoint("TOPLEFT", 0, 0)
  auraIntro:SetText("Player unit frame")

  local buffCard = CreateFrame("Frame", nil, leftAura, "BackdropTemplate")
  O.StyleSurface(buffCard, 0.78)
  buffCard:SetBackdropBorderColor(0, 0, 0, 0)
  buffCard:SetPoint("TOPLEFT", auraIntro, "BOTTOMLEFT", 0, -12)
  buffCard:SetPoint("TOPRIGHT", leftAura, "TOPRIGHT", 0, 0)
  buffCard:SetHeight(92)

  local hdrBuff = ArtFont(buffCard, "GameFontHighlight")
  hdrBuff:SetPoint("TOPLEFT", 12, -12)
  hdrBuff:SetText("Buffs")

  local cbAuraBuffs = O.MakeToggle(buffCard, "Show helpful aura icons", function()
    return _G.FlexxUIDB.playerAuraBuffs ~= false
  end, function(v)
    if ns.UnitFrames and ns.UnitFrames.SetUnitFrameAuraBuffs then ns.UnitFrames.SetUnitFrameAuraBuffs(v) end
  end, 400)
  cbAuraBuffs:SetPoint("TOPLEFT", hdrBuff, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbAuraBuffs)

  local debuffCard = CreateFrame("Frame", nil, leftAura, "BackdropTemplate")
  O.StyleSurface(debuffCard, 0.78)
  debuffCard:SetBackdropBorderColor(0, 0, 0, 0)
  debuffCard:SetPoint("TOPLEFT", buffCard, "BOTTOMLEFT", 0, -12)
  debuffCard:SetPoint("TOPRIGHT", buffCard, "TOPRIGHT", 0, 0)
  debuffCard:SetHeight(100)

  local hdrDebuff = ArtFont(debuffCard, "GameFontHighlight")
  hdrDebuff:SetPoint("TOPLEFT", 12, -12)
  hdrDebuff:SetText("Debuffs")

  local function getDebuffDisplay()
    O.EnsureDB()
    local m = _G.FlexxUIDB.playerAuraDebuffDisplay
    if m == "none" or m == "icons" or m == "bars" then return m end
    return "icons"
  end
  local function setDebuffDisplay(mode)
    if ns.UnitFrames and ns.UnitFrames.SetUnitFrameAuraDebuffDisplay then
      ns.UnitFrames.SetUnitFrameAuraDebuffDisplay(mode)
    else
      O.EnsureDB()
      _G.FlexxUIDB.playerAuraDebuffDisplay = mode
    end
    O.RefreshControls()
  end

  local ddDebuffDisplay = O.MakeEnumSelect(debuffCard, "Display", {
    { value = "none", text = "None" },
    { value = "icons", text = "Icons" },
    { value = "bars", text = "Timer bars" },
  }, getDebuffDisplay, setDebuffDisplay, 220)
  ddDebuffDisplay:SetPoint("TOPLEFT", hdrDebuff, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, ddDebuffDisplay)

  -- ——— Cast bar tab ———
  local castTitle = ArtFont(panelCast, "GameFontHighlight")
  castTitle:SetPoint("TOPLEFT", 0, 0)
  castTitle:SetText("FlexxUI cast bars")

  local castTextLbl = ArtFont(panelCast, "GameFontHighlightSmall")
  castTextLbl:SetPoint("TOPLEFT", castTitle, "BOTTOMLEFT", 0, -10)
  castTextLbl:SetText("Spell name & cast time color")

  local rbCastTxtLight = O.MakeRadio(panelCast, "Light", function() return _G.FlexxUIDB.castBarTextColorMode or "light" end, "light", function(mode)
    _G.FlexxUIDB.castBarTextColorMode = mode
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
    O.RefreshControls()
  end)
  rbCastTxtLight:SetPoint("TOPLEFT", castTextLbl, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbCastTxtLight)

  local rbCastTxtDark = O.MakeRadio(panelCast, "Dark", function() return _G.FlexxUIDB.castBarTextColorMode or "light" end, "dark", function(mode)
    _G.FlexxUIDB.castBarTextColorMode = mode
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
    O.RefreshControls()
  end)
  rbCastTxtDark:SetPoint("TOPLEFT", rbCastTxtLight, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbCastTxtDark)

  local rbCastTxtYellow = O.MakeRadio(panelCast, "Warm yellow (same as name preset)", function() return _G.FlexxUIDB.castBarTextColorMode or "light" end, "warm_yellow", function(mode)
    _G.FlexxUIDB.castBarTextColorMode = mode
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
    O.RefreshControls()
  end)
  rbCastTxtYellow:SetPoint("TOPLEFT", rbCastTxtDark, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbCastTxtYellow)

  local rbCastTxtClass = O.MakeRadio(panelCast, "Class color", function() return _G.FlexxUIDB.castBarTextColorMode or "light" end, "class_color", function(mode)
    _G.FlexxUIDB.castBarTextColorMode = mode
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
    O.RefreshControls()
  end)
  rbCastTxtClass:SetPoint("TOPLEFT", rbCastTxtYellow, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbCastTxtClass)

  local castFillHdr = ArtFont(panelCast, "GameFontHighlight")
  castFillHdr:SetPoint("TOPLEFT", rbCastTxtClass, "BOTTOMLEFT", 0, -16)
  castFillHdr:SetText("Cast bar fill (progress)")

  local rbCastFillDef = O.MakeRadio(panelCast, "Default (bright)", function() return _G.FlexxUIDB.castBarFillStyle or "default" end, "default", function(mode)
    _G.FlexxUIDB.castBarFillStyle = mode
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
    O.RefreshControls()
  end)
  rbCastFillDef:SetPoint("TOPLEFT", castFillHdr, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbCastFillDef)

  local rbCastFillDark = O.MakeRadio(panelCast, "Dark (muted)", function() return _G.FlexxUIDB.castBarFillStyle or "default" end, "dark", function(mode)
    _G.FlexxUIDB.castBarFillStyle = mode
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
    O.RefreshControls()
  end)
  rbCastFillDark:SetPoint("TOPLEFT", rbCastFillDef, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbCastFillDark)

  local castLblPlayer = ArtFont(panelCast, "GameFontHighlightSmall")
  castLblPlayer:SetPoint("TOPLEFT", rbCastFillDark, "BOTTOMLEFT", 0, -16)
  castLblPlayer:SetText("Player")

  local cbCastEnabled = O.MakeToggle(panelCast, "Show player cast bar", function()
    return _G.FlexxUIDB.castBarEnabled ~= false
  end, function(v)
    _G.FlexxUIDB.castBarEnabled = v
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
  end)
  cbCastEnabled:SetPoint("TOPLEFT", castLblPlayer, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, cbCastEnabled)

  local cbHideBlizzCast = O.MakeToggle(panelCast, "Hide default Blizzard cast bars (player & target)", function()
    return _G.FlexxUIDB.hideBlizzardCastBar == true
  end, function(v)
    _G.FlexxUIDB.hideBlizzardCastBar = v and true or false
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
  end)
  cbHideBlizzCast:SetPoint("TOPLEFT", cbCastEnabled, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbHideBlizzCast)

  local btnResetPlayerCast = O.MakeFlatButton(panelCast, "Reset player cast bar position", 280, 24, function()
    if ns.CastBar and ns.CastBar.ResetCastBarPosition then
      ns.CastBar.ResetCastBarPosition("player")
    end
  end)
  btnResetPlayerCast:SetPoint("TOPLEFT", cbHideBlizzCast, "BOTTOMLEFT", 0, -10)

  -- ——— Name & text tab ———
  local leftG = CreateFrame("Frame", nil, panelGeneral)
  leftG:SetPoint("TOPLEFT", 0, 0); leftG:SetSize(400, PLAYER_SUBTAB_HEIGHT.general)

  local nameColorLabel = ArtFont(leftG, "GameFontHighlight")
  nameColorLabel:SetPoint("TOPLEFT", 0, 0)
  nameColorLabel:SetText("Name text color (player frame)")

  local rbPInherit = O.MakeRadio(leftG, "Same as Fonts default", function() return getNameColorOverrideValue("player") end, "inherit", function(mode)
    setNameColorOverrideValue("player", mode)
  end)
  rbPInherit:SetPoint("TOPLEFT", nameColorLabel, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPInherit)
  local rbPClass = O.MakeRadio(leftG, "Class color", function() return getNameColorOverrideValue("player") end, "class", function(mode)
    setNameColorOverrideValue("player", mode)
  end)
  rbPClass:SetPoint("TOPLEFT", rbPInherit, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPClass)
  local rbPWhite = O.MakeRadio(leftG, "White", function() return getNameColorOverrideValue("player") end, "white", function(mode)
    setNameColorOverrideValue("player", mode)
  end)
  rbPWhite:SetPoint("TOPLEFT", rbPClass, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPWhite)
  local rbPYellow = O.MakeRadio(leftG, "Warm yellow", function() return getNameColorOverrideValue("player") end, "yellow", function(mode)
    setNameColorOverrideValue("player", mode)
  end)
  rbPYellow:SetPoint("TOPLEFT", rbPWhite, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPYellow)
  local rbPDark = O.MakeRadio(leftG, "Dark (near black)", function() return getNameColorOverrideValue("player") end, "dark", function(mode)
    setNameColorOverrideValue("player", mode)
  end)
  rbPDark:SetPoint("TOPLEFT", rbPYellow, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbPDark)

  local cbShowName = O.MakeToggle(leftG, "Show unit name", function()
    return _G.FlexxUIDB.showUnitFrameName ~= false
  end, function(v)
    _G.FlexxUIDB.showUnitFrameName = v
    if ns.UnitFrames and ns.UnitFrames.SetShowUnitFrameName then ns.UnitFrames.SetShowUnitFrameName(v) end
  end, 390)
  cbShowName:SetPoint("TOPLEFT", rbPDark, "BOTTOMLEFT", 0, -20)
  table.insert(O.state.controls, cbShowName)

  local function applyPlayerSubTab()
    O.EnsureDB()
    local key = (_G.FlexxUIDB and _G.FlexxUIDB.optionsPlayerSubTab) or "health"
    if key ~= "health" and key ~= "power" and key ~= "classbar" and key ~= "auras" and key ~= "cast" and key ~= "general" then
      key = "health"
    end
    panelHealth:SetShown(key == "health")
    panelPower:SetShown(key == "power")
    panelClassBar:SetShown(key == "classbar")
    panelAuras:SetShown(key == "auras")
    panelCast:SetShown(key == "cast")
    panelGeneral:SetShown(key == "general")
    local bodyH = PLAYER_SUBTAB_HEIGHT[key] or PLAYER_SUBTAB_HEIGHT.health
    local navH = 32
    local totalH = 14 + navH + 10 + bodyH + 24
    playerCard:SetHeight(totalH)
    content:SetHeight(totalH)
    O.RefreshScrollPages()
  end

  O.state.applyPlayerSubTab = applyPlayerSubTab
  applyPlayerSubTab()
end

function O.BuildUnitTargetPage(content)
  local targetCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
  targetCard:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  targetCard:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  O.StyleSurface(targetCard, 0.80)
  targetCard:SetBackdropColor(0.11, 0.13, 0.17, 0.78)
  targetCard:SetBackdropBorderColor(0, 0, 0, 0)

  local targetNav = CreateFrame("Frame", nil, targetCard)
  targetNav:SetPoint("TOPLEFT", 14, -14)
  targetNav:SetPoint("TOPRIGHT", -14, -14)
  targetNav:SetHeight(32)

  local btnTargetFrame = O.MakeTargetSubTabButton(targetNav, "Frame", "frame")
  local btnTargetCast = O.MakeTargetSubTabButton(targetNav, "Cast bar", "cast", btnTargetFrame)

  local panelFrame = CreateFrame("Frame", nil, targetCard)
  local panelCast = CreateFrame("Frame", nil, targetCard)
  panelFrame:SetPoint("TOPLEFT", targetNav, "BOTTOMLEFT", 0, -10)
  panelFrame:SetPoint("TOPRIGHT", targetNav, "BOTTOMRIGHT", 0, -10)
  panelCast:SetPoint("TOPLEFT", targetNav, "BOTTOMLEFT", 0, -10)
  panelCast:SetPoint("TOPRIGHT", targetNav, "BOTTOMRIGHT", 0, -10)
  panelFrame:SetHeight(TARGET_SUBTAB_HEIGHT.frame)
  panelCast:SetHeight(TARGET_SUBTAB_HEIGHT.cast)

  local leftCol = CreateFrame("Frame", nil, panelFrame)
  leftCol:SetPoint("TOPLEFT", 0, 0)
  leftCol:SetSize(320, TARGET_SUBTAB_HEIGHT.frame)
  local rightCol = CreateFrame("Frame", nil, panelFrame)
  rightCol:SetPoint("TOPLEFT", 332, 0)
  rightCol:SetSize(320, TARGET_SUBTAB_HEIGHT.frame)

  local nameColorLabel = ArtFont(leftCol, "GameFontHighlight")
  nameColorLabel:SetPoint("TOPLEFT", 0, 0)
  nameColorLabel:SetText("Name text color (target frame)")

  local rbTInherit = O.MakeRadio(leftCol, "Same as Fonts default", function() return getNameColorOverrideValue("target") end, "inherit", function(mode)
    setNameColorOverrideValue("target", mode)
  end)
  rbTInherit:SetPoint("TOPLEFT", nameColorLabel, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbTInherit)
  local rbTClass = O.MakeRadio(leftCol, "Class color", function() return getNameColorOverrideValue("target") end, "class", function(mode)
    setNameColorOverrideValue("target", mode)
  end)
  rbTClass:SetPoint("TOPLEFT", rbTInherit, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbTClass)
  local rbTWhite = O.MakeRadio(leftCol, "White", function() return getNameColorOverrideValue("target") end, "white", function(mode)
    setNameColorOverrideValue("target", mode)
  end)
  rbTWhite:SetPoint("TOPLEFT", rbTClass, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbTWhite)
  local rbTYellow = O.MakeRadio(leftCol, "Warm yellow", function() return getNameColorOverrideValue("target") end, "yellow", function(mode)
    setNameColorOverrideValue("target", mode)
  end)
  rbTYellow:SetPoint("TOPLEFT", rbTWhite, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbTYellow)
  local rbTDark = O.MakeRadio(leftCol, "Dark (near black)", function() return getNameColorOverrideValue("target") end, "dark", function(mode)
    setNameColorOverrideValue("target", mode)
  end)
  rbTDark:SetPoint("TOPLEFT", rbTYellow, "BOTTOMLEFT", 0, -8)
  table.insert(O.state.controls, rbTDark)

  local cbShowName = O.MakeToggle(leftCol, "Show unit name", function()
    return _G.FlexxUIDB.showUnitFrameName ~= false
  end, function(v)
    _G.FlexxUIDB.showUnitFrameName = v
    if ns.UnitFrames and ns.UnitFrames.SetShowUnitFrameName then ns.UnitFrames.SetShowUnitFrameName(v) end
  end)
  cbShowName:SetPoint("TOPLEFT", rbTDark, "BOTTOMLEFT", 0, -20)
  table.insert(O.state.controls, cbShowName)

  local lbl2 = ArtFont(rightCol, "GameFontHighlight"); lbl2:SetPoint("TOPLEFT", 0, 0); lbl2:SetText("Health Bar: texture")
  local rbTexNone = O.MakeRadio(rightCol, "None (solid color)", function() return _G.FlexxUIDB.healthBarTexture end, "none", function(name)
    _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls()
  end); rbTexNone:SetPoint("TOPLEFT", lbl2, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbTexNone)
  local rbTexDefault = O.MakeRadio(rightCol, "Default", function() return _G.FlexxUIDB.healthBarTexture end, "default", function(name)
    _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls()
  end); rbTexDefault:SetPoint("TOPLEFT", rbTexNone, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbTexDefault)
  local rbTexFlat = O.MakeRadio(rightCol, "Flat", function() return _G.FlexxUIDB.healthBarTexture end, "flat", function(name)
    _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls()
  end); rbTexFlat:SetPoint("TOPLEFT", rbTexDefault, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbTexFlat)
  local rbTexSmooth = O.MakeRadio(rightCol, "Smooth", function() return _G.FlexxUIDB.healthBarTexture end, "smooth", function(name)
    _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls()
  end); rbTexSmooth:SetPoint("TOPLEFT", rbTexFlat, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbTexSmooth)

  local cbOverlays = O.MakeToggle(rightCol, "Show incoming heals, absorbs, shields on health bar", function()
    return _G.FlexxUIDB.showHealthBarOverlays ~= false
  end, function(v)
    _G.FlexxUIDB.showHealthBarOverlays = v
    if ns.UnitFrames and ns.UnitFrames.SetShowHealthBarOverlays then ns.UnitFrames.SetShowHealthBarOverlays(v) end
  end, 300)
  cbOverlays:SetPoint("TOPLEFT", rbTexSmooth, "BOTTOMLEFT", 0, -20)
  table.insert(O.state.controls, cbOverlays)

  local lbl3 = ArtFont(leftCol, "GameFontHighlight"); lbl3:SetPoint("TOPLEFT", cbShowName, "BOTTOMLEFT", 0, -20); lbl3:SetText("Health value: format")
  local rbPct = O.MakeRadio(leftCol, "Show percent", function() return _G.FlexxUIDB.healthTextMode end, "percent", function(mode)
    _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls()
  end); rbPct:SetPoint("TOPLEFT", lbl3, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbPct)
  local rbVal = O.MakeRadio(leftCol, "Show value", function() return _G.FlexxUIDB.healthTextMode end, "value", function(mode)
    _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls()
  end); rbVal:SetPoint("TOPLEFT", rbPct, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbVal)
  local rbHide = O.MakeRadio(leftCol, "Hide health text", function() return _G.FlexxUIDB.healthTextMode end, "none", function(mode)
    _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls()
  end); rbHide:SetPoint("TOPLEFT", rbVal, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbHide)

  local lblPos = ArtFont(leftCol, "GameFontHighlight"); lblPos:SetPoint("TOPLEFT", rbHide, "BOTTOMLEFT", 0, -20); lblPos:SetText("Health value: position")
  local rbAlignRight = O.MakeRadio(leftCol, "Right", function() return _G.FlexxUIDB.healthTextAlign or "right" end, "right", function(align)
    _G.FlexxUIDB.healthTextAlign = align
    if ns.UnitFrames and ns.UnitFrames.SetHealthTextAlign then ns.UnitFrames.SetHealthTextAlign(align) end
    O.RefreshControls()
  end); rbAlignRight:SetPoint("TOPLEFT", lblPos, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbAlignRight)
  local rbAlignCenter = O.MakeRadio(leftCol, "Center", function() return _G.FlexxUIDB.healthTextAlign or "right" end, "center", function(align)
    _G.FlexxUIDB.healthTextAlign = align
    if ns.UnitFrames and ns.UnitFrames.SetHealthTextAlign then ns.UnitFrames.SetHealthTextAlign(align) end
    O.RefreshControls()
  end);   rbAlignCenter:SetPoint("TOPLEFT", rbAlignRight, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbAlignCenter)

  addResourceBarLayoutSection(leftCol, rbAlignCenter, 20)

  local lbl4 = ArtFont(rightCol, "GameFontHighlight"); lbl4:SetPoint("TOPLEFT", cbOverlays, "BOTTOMLEFT", 0, -20); lbl4:SetText("Health value: color")
  local rbHCName = O.MakeRadio(rightCol, "Class color", function() return _G.FlexxUIDB.healthTextColorMode end, "name", function(mode)
    _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls()
  end); rbHCName:SetPoint("TOPLEFT", lbl4, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbHCName)
  local rbHCBar = O.MakeRadio(rightCol, "Match health bar", function() return _G.FlexxUIDB.healthTextColorMode end, "classdark", function(mode)
    _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls()
  end); rbHCBar:SetPoint("TOPLEFT", rbHCName, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbHCBar)
  local rbHCSolid = O.MakeRadio(rightCol, "Solid light gray", function() return _G.FlexxUIDB.healthTextColorMode end, "solid", function(mode)
    _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls()
  end); rbHCSolid:SetPoint("TOPLEFT", rbHCBar, "BOTTOMLEFT", 0, -8); table.insert(O.state.controls, rbHCSolid)

  local lblResColorT = ArtFont(rightCol, "GameFontHighlight")
  lblResColorT:SetPoint("TOPLEFT", rbHCSolid, "BOTTOMLEFT", 0, -20)
  lblResColorT:SetText("Resource text color")

  addResourceBarColorSection(rightCol, lblResColorT, 8)

  local tcHdr = ArtFont(panelCast, "GameFontHighlight")
  tcHdr:SetPoint("TOPLEFT", 0, 0)
  tcHdr:SetText("Target cast bar")

  local cbCastTarget = O.MakeToggle(panelCast, "Show target cast bar", function()
    return _G.FlexxUIDB.castBarTargetEnabled ~= false
  end, function(v)
    _G.FlexxUIDB.castBarTargetEnabled = v
    if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end
  end)
  cbCastTarget:SetPoint("TOPLEFT", tcHdr, "BOTTOMLEFT", 0, -10)
  table.insert(O.state.controls, cbCastTarget)

  local btnResetTargetCast = O.MakeFlatButton(panelCast, "Reset target cast bar position", 280, 24, function()
    if ns.CastBar and ns.CastBar.ResetCastBarPosition then
      ns.CastBar.ResetCastBarPosition("target")
    end
  end)
  btnResetTargetCast:SetPoint("TOPLEFT", cbCastTarget, "BOTTOMLEFT", 0, -10)

  local function applyTargetSubTab()
    O.EnsureDB()
    local key = (_G.FlexxUIDB and _G.FlexxUIDB.optionsTargetSubTab) or "frame"
    if key ~= "frame" and key ~= "cast" then
      key = "frame"
    end
    panelFrame:SetShown(key == "frame")
    panelCast:SetShown(key == "cast")
    local bodyH = TARGET_SUBTAB_HEIGHT[key] or TARGET_SUBTAB_HEIGHT.frame
    local navH = 32
    local totalH = 14 + navH + 10 + bodyH + 24
    targetCard:SetHeight(totalH)
    content:SetHeight(totalH)
    O.RefreshScrollPages()
  end
  O.state.applyTargetSubTab = applyTargetSubTab
  applyTargetSubTab()
end

function O.BuildUnitPetPage(content)
  local card = CreateFrame("Frame", nil, content, "BackdropTemplate")
  card:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  card:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  card:SetHeight(120)
  O.StyleSurface(card, 0.80)
  card:SetBackdropColor(0.11, 0.13, 0.17, 0.78)
  card:SetBackdropBorderColor(0, 0, 0, 0)
  local hintPet = ArtFont(card, "GameFontHighlightSmall")
  hintPet:SetPoint("TOPLEFT", 14, -14)
  hintPet:SetWidth(640)
  hintPet:SetJustifyH("LEFT")
  hintPet:SetText("Coming soon.")
  content:SetHeight(120)
end

