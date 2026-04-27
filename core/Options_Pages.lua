local _, ns = ...
local O = ns.Options

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

local UNIT_PAGE_CONTENT_HEIGHT = 2200
local TARGET_SUBTAB_HEIGHT = { frame = UNIT_PAGE_CONTENT_HEIGHT, cast = 420 }
local PLAYER_SUBTAB_HEIGHT = { health = 980, power = 2280, classbar = 360, auras = 360, cast = 760, general = 520 }

--- Automatic = Blizzard PowerBarColor (changes with class, spec, form). Custom = color picker.
local function getPowerBarFillMode()
  O.EnsureDB()
  return (_G.FlexxUIDB.powerBarUseCustomColor == true) and "custom" or "automatic"
end

local function setPowerBarFillMode(mode)
  O.EnsureDB()
  if mode == "custom" then
    if ns.UnitFrames and ns.UnitFrames.SetPowerBarUseCustomColor then
      ns.UnitFrames.SetPowerBarUseCustomColor(true)
    else
      _G.FlexxUIDB.powerBarUseCustomColor = true
    end
  else
    if ns.UnitFrames and ns.UnitFrames.ResetPowerBarToAutomaticColoring then
      ns.UnitFrames.ResetPowerBarToAutomaticColoring()
    else
      _G.FlexxUIDB.powerBarUseCustomColor = false
    end
  end
  O.RefreshControls()
end

--- Swatch + single button opening Blizzard ColorPickerFrame (no embedded ColorSelect).
local function buildPowerBarCustomColorPicker(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(640, 64)

  local lbl = O.ArtFont(row, "GameFontHighlightSmall")
  lbl:SetPoint("TOPLEFT", 0, 0)
  lbl:SetText("Custom color")

  local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
  swatch:SetSize(30, 30)
  swatch:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -6)
  O.StyleSurface(swatch, 1)
  swatch:SetBackdropBorderColor(0.35, 0.4, 0.45, 1)
  local tex = swatch:CreateTexture(nil, "ARTWORK")
  tex:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
  tex:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)
  tex:SetTexture("Interface\\Buttons\\WHITE8x8")

  local function getRGB()
    O.EnsureDB()
    local c = _G.FlexxUIDB.powerBarCustomColor or {}
    local r = type(c.r) == "number" and c.r or 0.22
    local g = type(c.g) == "number" and c.g or 0.52
    local b = type(c.b) == "number" and c.b or 0.95
    return r, g, b
  end

  local function refreshSwatch()
    tex:SetVertexColor(getRGB())
  end

  local function raiseColorPickerFrame()
    local CPF = _G.ColorPickerFrame
    if not CPF or not CPF.IsShown or not CPF:IsShown() then
      return
    end
    if CPF.SetFrameStrata then
      CPF:SetFrameStrata("FULLSCREEN_DIALOG")
    end
    if CPF.SetFrameLevel then
      CPF:SetFrameLevel(5000)
    end
  end

  local btn = O.MakeFlatButton(row, "Choose color…", 168, 26, function()
    local CPF = _G.ColorPickerFrame
    if not CPF or not CPF.SetupColorPickerAndShow then
      return
    end
    local r, g, b = getRGB()
    local function applyFromPicker()
      local nr, ng, nb = CPF:GetColorRGB()
      if ns.UnitFrames and ns.UnitFrames.SetPowerBarUseCustomColor then
        ns.UnitFrames.SetPowerBarUseCustomColor(true)
      else
        O.EnsureDB()
        _G.FlexxUIDB.powerBarUseCustomColor = true
      end
      if ns.UnitFrames and ns.UnitFrames.SetPowerBarCustomColorRGB then
        ns.UnitFrames.SetPowerBarCustomColorRGB(nr, ng, nb)
      else
        O.EnsureDB()
        _G.FlexxUIDB.powerBarCustomColor = { r = nr, g = ng, b = nb }
        _G.FlexxUIDB.powerBarUseCustomColor = true
      end
      refreshSwatch()
      O.RefreshControls()
    end
    CPF:SetupColorPickerAndShow({
      r = r,
      g = g,
      b = b,
      hasOpacity = false,
      swatchFunc = applyFromPicker,
      cancelFunc = function()
        local pr, pg, pb = CPF:GetPreviousValues()
        if type(pr) == "number" and type(pg) == "number" and type(pb) == "number" then
          if ns.UnitFrames and ns.UnitFrames.SetPowerBarCustomColorRGB then
            ns.UnitFrames.SetPowerBarCustomColorRGB(pr, pg, pb)
          else
            O.EnsureDB()
            _G.FlexxUIDB.powerBarCustomColor = { r = pr, g = pg, b = pb }
          end
          refreshSwatch()
          O.RefreshControls()
        end
      end,
    })
    if C_Timer and C_Timer.After then
      C_Timer.After(0, raiseColorPickerFrame)
    else
      raiseColorPickerFrame()
    end
  end)
  btn:SetPoint("LEFT", swatch, "RIGHT", 12, 0)

  row.Refresh = refreshSwatch
  refreshSwatch()
  return row
end

local function addResourceBarLayoutSection(parent, below, gap)
  gap = gap or 16
  local hdr = O.ArtFont(parent, "GameFontHighlight")
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

  local lblFmt = O.ArtFont(parent, "GameFontHighlightSmall")
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

  local posHdr = O.ArtFont(parent, "GameFontHighlightSmall")
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

  local lblUniform = O.ArtFont(parent, "GameFontHighlightSmall")
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

  local lblMana = O.ArtFont(parent, "GameFontHighlightSmall")
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

  local lblOther = O.ArtFont(parent, "GameFontHighlightSmall")
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
  settingsCard:SetHeight(900)
  O.StyleSurface(settingsCard, 0.80)
  settingsCard:SetBackdropColor(0.11, 0.13, 0.17, 0.78)
  settingsCard:SetBackdropBorderColor(0, 0, 0, 0)

  local panelSettings = CreateFrame("Frame", nil, settingsCard)
  panelSettings:SetPoint("TOPLEFT", 14, -14)
  panelSettings:SetPoint("TOPRIGHT", -14, -14)
  panelSettings:SetHeight(860)

  local fontsCard = CreateFrame("Frame", nil, content, "BackdropTemplate")
  fontsCard:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  fontsCard:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
  fontsCard:SetHeight(1320)
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
  panelFontsUI:SetHeight(1240)
  panelFontsUnit:SetHeight(1240)

  local ver = ns.version or "dev"
  O.BuildSchemaPage(panelSettings, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Welcome",
        hint = "Core addon settings and maintenance actions.",
        collapsedKey = "general_settings_welcome",
        controls = {
          { type = "note", text = "|cffaaaaaaVersion " .. ver .. "|r" },
        },
      },
      {
        title = "Blizzard frames",
        collapsedKey = "general_settings_blizzard",
        controls = {
          {
            type = "toggle",
            label = "Hide Blizzard player/target frames (experimental)",
            get = function() return _G.FlexxUIDB.hideBlizzard end,
            set = function(v)
              _G.FlexxUIDB.hideBlizzard = v and true or false
              if ns.UnitFrames and ns.UnitFrames.ApplyHideBlizzard then ns.UnitFrames.ApplyHideBlizzard() end
            end,
          },
        },
      },
      {
        title = "Minimap",
        collapsedKey = "general_settings_minimap",
        controls = {
          {
            type = "toggle",
            label = "Show minimap button",
            get = function() return _G.FlexxUIDB.minimapButtonShow ~= false end,
            set = function(v)
              _G.FlexxUIDB.minimapButtonShow = v and true or false
              if ns.Minimap and ns.Minimap.ApplyVisibility then ns.Minimap.ApplyVisibility() end
            end,
          },
        },
      },
      {
        title = "Maintenance",
        collapsedKey = "general_settings_maintenance",
        controls = {
          { type = "button", label = "Reload UI", onClick = function() ReloadUI() end, width = 140 },
          { type = "button", label = "Reset Settings", onClick = function()
              if ns.DB and ns.DB.Reset then ns.DB.Reset() else _G.FlexxUIDB = {} end
              ReloadUI()
            end, width = 160 },
          { type = "button", label = "Reset positions", onClick = function()
              if ns.Movers and ns.Movers.ResetSavedPositions then ns.Movers.ResetSavedPositions() end
              ReloadUI()
            end, width = 160 },
        },
      },
    },
  })

  local function applyUIFontPreset(mode)
    _G.FlexxUIDB.flexxUIFontPresetUI = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end
  O.BuildSchemaPage(panelFontsUI, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Settings panel and options chrome",
        collapsedKey = "general_fonts_ui",
        controls = {
          { type = "radio", label = "Default (Blizzard templates)", get = function() return _G.FlexxUIDB.flexxUIFontPresetUI or "default" end, value = "default", set = applyUIFontPreset },
          { type = "radio", label = "Friz Quadrata", get = function() return _G.FlexxUIDB.flexxUIFontPresetUI or "default" end, value = "friz", set = applyUIFontPreset },
          { type = "radio", label = "Arial Narrow", get = function() return _G.FlexxUIDB.flexxUIFontPresetUI or "default" end, value = "arial_narrow", set = applyUIFontPreset },
          { type = "radio", label = "Roboto Condensed Bold", get = function() return _G.FlexxUIDB.flexxUIFontPresetUI or "default" end, value = "roboto_condensed", set = applyUIFontPreset, gapAfter = 12 },
          { type = "slider_scale_pct", label = "Size (relative to template)", min = 70, max = 150, step = 5, get = function() return _G.FlexxUIDB.flexxUIFontScaleUI or 1 end, set = function(s) _G.FlexxUIDB.flexxUIFontScaleUI = s end },
        },
      },
    },
  })

  local function applyUnitFontPreset(mode)
    _G.FlexxUIDB.flexxUIFontPresetUnit = mode
    if ns.Fonts and ns.Fonts.Apply then ns.Fonts.Apply() end
    O.RefreshControls()
  end
  O.BuildSchemaPage(panelFontsUnit, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Player / target / pet frames and FlexxUI cast bars",
        collapsedKey = "general_fonts_unit_face",
        controls = {
          { type = "radio", label = "Default (Blizzard templates)", get = function() return _G.FlexxUIDB.flexxUIFontPresetUnit or "default" end, value = "default", set = applyUnitFontPreset },
          { type = "radio", label = "Friz Quadrata", get = function() return _G.FlexxUIDB.flexxUIFontPresetUnit or "default" end, value = "friz", set = applyUnitFontPreset },
          { type = "radio", label = "Arial Narrow", get = function() return _G.FlexxUIDB.flexxUIFontPresetUnit or "default" end, value = "arial_narrow", set = applyUnitFontPreset },
          { type = "radio", label = "Roboto Condensed Bold", get = function() return _G.FlexxUIDB.flexxUIFontPresetUnit or "default" end, value = "roboto_condensed", set = applyUnitFontPreset, gapAfter = 12 },
          { type = "slider_scale_pct", label = "Size (relative to template or preset)", min = 70, max = 150, step = 5, get = function() return _G.FlexxUIDB.flexxUIFontScaleUnit or 1 end, set = function(s) _G.FlexxUIDB.flexxUIFontScaleUnit = s end },
        },
      },
      {
        title = "Unit name text color (default)",
        collapsedKey = "general_fonts_unit_name",
        controls = {
          { type = "radio", label = "Class color", get = function() return _G.FlexxUIDB.nameTextColorMode or "class" end, value = "class", set = function(mode) _G.FlexxUIDB.nameTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetNameTextColorMode then ns.UnitFrames.SetNameTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "White", get = function() return _G.FlexxUIDB.nameTextColorMode or "class" end, value = "white", set = function(mode) _G.FlexxUIDB.nameTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetNameTextColorMode then ns.UnitFrames.SetNameTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Flexx gold", get = function() return _G.FlexxUIDB.nameTextColorMode or "class" end, value = "yellow", set = function(mode) _G.FlexxUIDB.nameTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetNameTextColorMode then ns.UnitFrames.SetNameTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Dark (near black)", get = function() return _G.FlexxUIDB.nameTextColorMode or "class" end, value = "dark", set = function(mode) _G.FlexxUIDB.nameTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetNameTextColorMode then ns.UnitFrames.SetNameTextColorMode(mode) end; O.RefreshControls() end },
        },
      },
    },
  })

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
  content:SetHeight(1400)
end

function O.BuildDevPage(content, mode)
  local function refreshAuraLayout()
    if ns.UnitFrames and ns.UnitFrames.RefreshAurasFromOptions then
      ns.UnitFrames.RefreshAurasFromOptions()
    end
  end

  --- Sliders must not use `v or default` for px: only nil should fall back (0 is valid). Sync legacy unitFrame* keys so player/target stay aligned.
  local function auraNum(key, default)
    local v = _G.FlexxUIDB and _G.FlexxUIDB[key]
    if type(v) == "number" then return v end
    return default
  end
  local function syncBuffX(v)
    local db = _G.FlexxUIDB
    db.playerAuraBuffAnchorX = v
    db.targetAuraBuffAnchorX = v
    db.unitFrameAuraBuffAnchorX = v
    refreshAuraLayout()
  end
  local function syncBuffY(v)
    local db = _G.FlexxUIDB
    db.playerAuraBuffAnchorY = v
    db.targetAuraBuffAnchorY = v
    db.unitFrameAuraBuffAnchorY = v
    refreshAuraLayout()
  end
  local function syncDebuffX(v)
    local db = _G.FlexxUIDB
    db.playerAuraDebuffAnchorX = v
    db.targetAuraDebuffAnchorX = v
    db.unitFrameAuraDebuffAnchorX = v
    refreshAuraLayout()
  end
  local function syncDebuffY(v)
    local db = _G.FlexxUIDB
    db.playerAuraDebuffAnchorY = v
    db.targetAuraDebuffAnchorY = v
    db.unitFrameAuraDebuffAnchorY = v
    refreshAuraLayout()
  end

  local sections
  if mode == "auras" then
    sections = {
      {
        title = "Player frame auras",
        hint = "Layout nudges and preview toggles for aura row and timer-bar testing.",
        collapsedKey = "dev_auras",
        controls = {
          { type = "note", text = "Offsets apply to player and target frames (and saved legacy mirror keys) so rows move reliably. Use whole px; 4 is a valid value (no longer auto-bumped on every load)." },
          { type = "toggle", label = "Preview buff row (placeholder icons)", get = function() return _G.FlexxUIDB.unitFrameAuraDevPreviewBuff == true end, set = function(v) _G.FlexxUIDB.unitFrameAuraDevPreviewBuff = v and true or false; refreshAuraLayout() end },
          { type = "toggle", label = "Preview debuff row (placeholder icons)", get = function() return _G.FlexxUIDB.unitFrameAuraDevPreviewDebuff == true end, set = function(v) _G.FlexxUIDB.unitFrameAuraDevPreviewDebuff = v and true or false; refreshAuraLayout() end },
          { type = "toggle", label = "Preview debuff timer bars", get = function() return _G.FlexxUIDB.unitFrameAuraDevPreviewBars == true end, set = function(v) _G.FlexxUIDB.unitFrameAuraDevPreviewBars = v and true or false; refreshAuraLayout() end, gapAfter = 12 },
          { type = "slider_int", label = "Buff row: offset left / right (px)", min = -80, max = 80, step = 1, get = function() return auraNum("playerAuraBuffAnchorX", 0) end, set = syncBuffX, gapAfter = 4 },
          { type = "slider_int", label = "Buff row: offset up / down (px)", min = -80, max = 80, step = 1, get = function() return auraNum("playerAuraBuffAnchorY", 50) end, set = syncBuffY, gapAfter = 4 },
          { type = "slider_int", label = "Debuff icons / timer bars: offset left / right (px)", min = -80, max = 80, step = 1, get = function() return auraNum("playerAuraDebuffAnchorX", 0) end, set = syncDebuffX, gapAfter = 4 },
          { type = "slider_int", label = "Debuff icons / timer bars: offset up / down (px)", min = -80, max = 80, step = 1, get = function() return auraNum("playerAuraDebuffAnchorY", 18) end, set = syncDebuffY },
        },
      },
    }
  else
    sections = {
      {
        title = "Cast bars",
        hint = "Debug-only toggles for showing empty cast bars while idle.",
        collapsedKey = "dev_cast",
        controls = {
          { type = "toggle", label = "Show empty player cast bar when not casting", get = function() return _G.FlexxUIDB.castBarShowIdle == true end, set = function(v) _G.FlexxUIDB.castBarShowIdle = v and true or false; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end end },
          { type = "toggle", label = "Show empty target cast bar when not casting", get = function() return _G.FlexxUIDB.castBarTargetShowIdle == true end, set = function(v) _G.FlexxUIDB.castBarTargetShowIdle = v and true or false; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end end },
        },
      },
    }
  end
  table.insert(sections, {
    title = "Unit frame panel",
    hint = "Developer-only visibility toggles for frame backdrop and the group indicator.",
    collapsedKey = "dev_unitframe_panel",
    controls = {
      { type = "toggle", label = "Show unit frame panel background", width = 320, get = function() return _G.FlexxUIDB.unitFrameBackdropShow ~= false end, set = function(v) _G.FlexxUIDB.unitFrameBackdropShow = v; if ns.UnitFrames and ns.UnitFrames.SetUnitFrameBackdropShow then ns.UnitFrames.SetUnitFrameBackdropShow(v) end end },
      {
        type = "toggle",
        label = "Show group indicator while solo (test)",
        width = 320,
        get = function() return _G.FlexxUIDB.devGroupIndicatorShowSolo == true end,
        set = function(v)
          _G.FlexxUIDB.devGroupIndicatorShowSolo = v and true or false
          local UF = ns.UnitFrames
          if UF and UF.UpdateUnitFrame and UF.state and UF.state.frames and UF.state.frames.player then
            UF.UpdateUnitFrame(UF.state.frames.player)
          end
        end,
      },
    },
  })
  table.insert(sections, {
    title = "Action block debug",
    hint = "Logs blocked/forbidden UI actions so combat taint can be diagnosed.",
    collapsedKey = "dev_action_block_debug",
    controls = {
      { type = "toggle", label = "Enable action-block logging", width = 320, get = function() return _G.FlexxUIDB.debugActionLogEnabled == true end, set = function(v) _G.FlexxUIDB.debugActionLogEnabled = v and true or false; if ns.Debug and ns.Debug.SetEnabled then ns.Debug.SetEnabled(v) end end, gapAfter = 6 },
      { type = "toggle", label = "Show floating debug monitor", width = 320, get = function() return _G.FlexxUIDB.debugActionMonitorShown == true end, set = function(v) _G.FlexxUIDB.debugActionMonitorShown = v and true or false; if ns.Debug and ns.Debug.SetMonitorShown then ns.Debug.SetMonitorShown(v) end end, gapAfter = 6 },
      { type = "button", label = "Clear debug log", width = 220, onClick = function() if ns.Debug and ns.Debug.Clear then ns.Debug.Clear() end end, gapAfter = 8 },
      {
        type = "custom",
        build = function(parent)
          local row = CreateFrame("Frame", nil, parent)
          row:SetSize(640, 240)
          local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          fs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
          fs:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, 0)
          fs:SetJustifyH("LEFT")
          fs:SetJustifyV("TOP")
          fs:SetNonSpaceWrap(true)
          fs:SetText("Debug log will appear here.")
          row._ticker = 0
          row:SetScript("OnUpdate", function(self, elapsed)
            self._ticker = (self._ticker or 0) + elapsed
            if self._ticker < 0.25 then return end
            self._ticker = 0
            if ns.Debug and ns.Debug.GetLogText then
              fs:SetText(ns.Debug.GetLogText(16))
            end
          end)
          return row
        end,
      },
    },
  })
  O.BuildSchemaPage(content, { sections = sections })
end

function O.BuildCombatPage(content, mode)
  local function refreshCombat()
    if ns.CombatCenter and ns.CombatCenter.RefreshFromOptions then
      ns.CombatCenter.RefreshFromOptions()
    end
  end

  local sections
  if mode == "display" then
    sections = {
      {
        title = "Display lanes",
        hint = "Lane 1 = secondary pips, lane 2 = primary resource bar, lane 3 = cooldown icons.",
        collapsedKey = "combat_lanes",
        controls = {
          { type = "toggle", label = "Show lane 1 (secondary pips)", get = function() return _G.FlexxUIDB.combatCenter.showResourceLane ~= false end, set = function(v) _G.FlexxUIDB.combatCenter.showResourceLane = v and true or false; refreshCombat() end },
          { type = "toggle", label = "Show primary resource lane (mana/energy/rage/etc.)", get = function() return _G.FlexxUIDB.combatCenter.showPrimaryLane ~= false end, set = function(v) _G.FlexxUIDB.combatCenter.showPrimaryLane = v and true or false; refreshCombat() end },
          { type = "toggle", label = "Show lane 3 (cooldowns)", get = function() return _G.FlexxUIDB.combatCenter.showCooldownLane ~= false end, set = function(v) _G.FlexxUIDB.combatCenter.showCooldownLane = v and true or false; refreshCombat() end, gapAfter = 12 },
        },
      },
      {
        title = "Lane placement",
        hint = "Fine-tune lane 1 and lane 2 position inside Combat Center.",
        collapsedKey = "combat_lane_placement",
        controls = {
          { type = "slider_int", label = "Lane 1 horizontal (px)", min = -200, max = 200, step = 1, get = function() return math.floor((_G.FlexxUIDB.combatCenter.lane1OffsetX or 0) + 0.5) end, set = function(v) _G.FlexxUIDB.combatCenter.lane1OffsetX = v; refreshCombat() end, gapAfter = 4 },
          { type = "slider_int", label = "Lane 1 vertical (px)", min = -200, max = 200, step = 1, get = function() return math.floor((_G.FlexxUIDB.combatCenter.lane1OffsetY or 0) + 0.5) end, set = function(v) _G.FlexxUIDB.combatCenter.lane1OffsetY = v; refreshCombat() end, gapAfter = 8 },
          { type = "slider_int", label = "Lane 2 horizontal (px)", min = -200, max = 200, step = 1, get = function() return math.floor((_G.FlexxUIDB.combatCenter.lane2OffsetX or 0) + 0.5) end, set = function(v) _G.FlexxUIDB.combatCenter.lane2OffsetX = v; refreshCombat() end, gapAfter = 4 },
          { type = "slider_int", label = "Lane 2 vertical (px)", min = -200, max = 200, step = 1, get = function() return math.floor((_G.FlexxUIDB.combatCenter.lane2OffsetY or 0) + 0.5) end, set = function(v) _G.FlexxUIDB.combatCenter.lane2OffsetY = v; refreshCombat() end, gapAfter = 10 },
          { type = "button", label = "Reset lane 1 and lane 2 positions", width = 300, onClick = function()
              _G.FlexxUIDB.combatCenter.lane1OffsetX = 0
              _G.FlexxUIDB.combatCenter.lane1OffsetY = 0
              _G.FlexxUIDB.combatCenter.lane2OffsetX = 0
              _G.FlexxUIDB.combatCenter.lane2OffsetY = 0
              refreshCombat()
            end, gapAfter = 12 },
          { type = "button", label = "Reset combat center anchor", width = 240, onClick = function()
              _G.FlexxUIDB.combatCenter.anchorX = 0
              _G.FlexxUIDB.combatCenter.anchorY = -180
              refreshCombat()
            end },
        },
      },
      {
        title = "Lane 3 settings",
        hint = "Cooldown lane filtering and icon behavior.",
        collapsedKey = "combat_lane3_settings",
        controls = {
          { type = "slider_int", label = "Cooldown lane: min seconds (action bar)", min = 5, max = 120, step = 1, get = function() return _G.FlexxUIDB.combatCenter.lane3MinCooldownSeconds or 8 end, set = function(v) _G.FlexxUIDB.combatCenter.lane3MinCooldownSeconds = v; refreshCombat() end, gapAfter = 4 },
          { type = "toggle", label = "Show cooldown swipe", get = function() return _G.FlexxUIDB.combatCenter.iconShowCooldownSwipe ~= false end, set = function(v) _G.FlexxUIDB.combatCenter.iconShowCooldownSwipe = v and true or false; refreshCombat() end },
          { type = "toggle", label = "Desaturate unusable icons", get = function() return _G.FlexxUIDB.combatCenter.iconDesaturateUnusable ~= false end, set = function(v) _G.FlexxUIDB.combatCenter.iconDesaturateUnusable = v and true or false; refreshCombat() end, gapAfter = 4 },
          { type = "slider_int", label = "Usable icon opacity (%)", min = 20, max = 100, step = 5, get = function() return math.floor(((_G.FlexxUIDB.combatCenter.iconUsableAlpha or 1) * 100) + 0.5) end, set = function(v) _G.FlexxUIDB.combatCenter.iconUsableAlpha = v / 100; refreshCombat() end, gapAfter = 4 },
          { type = "slider_int", label = "Unusable icon opacity (%)", min = 10, max = 100, step = 5, get = function() return math.floor(((_G.FlexxUIDB.combatCenter.iconUnusableAlpha or 0.65) * 100) + 0.5) end, set = function(v) _G.FlexxUIDB.combatCenter.iconUnusableAlpha = v / 100; refreshCombat() end },
        },
      },
      {
        title = "Sizing",
        hint = "Primary lane height follows icon size baseline; lane 3 uses icon size.",
        collapsedKey = "combat_sizing",
        controls = {
          { type = "slider_int", label = "Lane 3 icon size", min = 24, max = 80, step = 1, get = function() return _G.FlexxUIDB.combatCenter.iconSize or 44 end, set = function(v) _G.FlexxUIDB.combatCenter.iconSize = v; refreshCombat() end },
        },
      },
    }
  elseif mode == "tracking" then
    sections = {
      {
        title = "Tracking",
        hint = "Class-specific rule tables and debuff lists.",
        collapsedKey = "combat_tracking",
        controls = {
          { type = "toggle", label = "Track only class-relevant debuffs", get = function() return _G.FlexxUIDB.combatCenter.trackOnlyRelevantDebuffs ~= false end, set = function(v) _G.FlexxUIDB.combatCenter.trackOnlyRelevantDebuffs = v and true or false; refreshCombat() end },
          { type = "note", text = "Next step: class profiles (resource rules, rotation globals, cooldown lists, and debuff watchlists) will be data-driven and loaded per class/spec." },
        },
      },
    }
  else
    sections = {
      {
        title = "Overview",
        hint = "Lane 1 = secondary class pips, lane 2 = primary resource bar, lane 3 = cooldown lane (optional). If you see nothing, turn on \"Enable combat center manager\" below and disable \"Show only in combat\" while testing.",
        collapsedKey = "combat_overview",
        controls = {
          {
            type = "toggle",
            label = "Enable combat center manager",
            get = function() return _G.FlexxUIDB.combatCenter and _G.FlexxUIDB.combatCenter.enabled == true end,
            set = function(v)
              _G.FlexxUIDB.combatCenter = _G.FlexxUIDB.combatCenter or {}
              local enabled = v and true or false
              _G.FlexxUIDB.combatCenter.enabled = enabled
              -- Default behavior: when Combat Center is first enabled, hide unit-frame top pips.
              if enabled and _G.FlexxUIDB.combatCenter.topPipsUserSet ~= true then
                _G.FlexxUIDB.showSecondaryResource = false
                if ns.UnitFrames and ns.UnitFrames.SetShowSecondaryResource then
                  ns.UnitFrames.SetShowSecondaryResource(false)
                end
              end
              refreshCombat()
            end,
          },
          {
            type = "toggle",
            label = "Show only in combat",
            get = function() return _G.FlexxUIDB.combatCenter and _G.FlexxUIDB.combatCenter.onlyInCombat == true end,
            set = function(v) _G.FlexxUIDB.combatCenter.onlyInCombat = v and true or false; refreshCombat() end,
          },
          {
            type = "toggle",
            label = "Lock frame (disable dragging)",
            get = function() return _G.FlexxUIDB.combatCenter and _G.FlexxUIDB.combatCenter.lockFrame == true end,
            set = function(v) _G.FlexxUIDB.combatCenter.lockFrame = v and true or false; refreshCombat() end,
            gapAfter = 12,
          },
          {
            type = "slider_int",
            label = "Horizontal offset (from screen center)",
            min = -800,
            max = 800,
            step = 1,
            get = function() return math.floor((_G.FlexxUIDB.combatCenter and _G.FlexxUIDB.combatCenter.anchorX) or 0) end,
            set = function(v) _G.FlexxUIDB.combatCenter.anchorX = v; refreshCombat() end,
            gapAfter = 4,
          },
          {
            type = "slider_int",
            label = "Vertical offset (negative = lower)",
            min = -800,
            max = 800,
            step = 1,
            get = function() return math.floor((_G.FlexxUIDB.combatCenter and _G.FlexxUIDB.combatCenter.anchorY) or -180) end,
            set = function(v) _G.FlexxUIDB.combatCenter.anchorY = v; refreshCombat() end,
            gapAfter = 12,
          },
          {
            type = "slider_scale_pct",
            label = "Combat center scale",
            min = 70, max = 150, step = 1,
            get = function() return (_G.FlexxUIDB.combatCenter and _G.FlexxUIDB.combatCenter.scale) or 1 end,
            set = function(v) _G.FlexxUIDB.combatCenter.scale = v; refreshCombat() end,
          },
        },
      },
    }
  end
  O.BuildSchemaPage(content, { sections = sections })
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

  O.BuildSchemaPage(panelHealth, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Health bar",
        collapsedKey = "player_health_bar",
        controls = {
          { type = "note", text = "Color" },
          { type = "radio", label = "Class color", get = function() return _G.FlexxUIDB.playerHealthColorMode end, value = "class", set = function(mode) _G.FlexxUIDB.playerHealthColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetPlayerHealthColorMode then ns.UnitFrames.SetPlayerHealthColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Green", get = function() return _G.FlexxUIDB.playerHealthColorMode end, value = "blizzard", set = function(mode) _G.FlexxUIDB.playerHealthColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetPlayerHealthColorMode then ns.UnitFrames.SetPlayerHealthColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Dark", get = function() return _G.FlexxUIDB.playerHealthColorMode end, value = "dark", set = function(mode) _G.FlexxUIDB.playerHealthColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetPlayerHealthColorMode then ns.UnitFrames.SetPlayerHealthColorMode(mode) end; O.RefreshControls() end, gapAfter = 12 },
          { type = "note", text = "Texture" },
          { type = "radio", label = "None", get = function() return _G.FlexxUIDB.healthBarTexture end, value = "none", set = function(name) _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls() end },
          { type = "radio", label = "Default", get = function() return _G.FlexxUIDB.healthBarTexture end, value = "default", set = function(name) _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls() end },
          { type = "radio", label = "Flat", get = function() return _G.FlexxUIDB.healthBarTexture end, value = "flat", set = function(name) _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls() end, gapAfter = 12 },
          { type = "note", text = "Health value format" },
          { type = "radio", label = "Show percent", get = function() return _G.FlexxUIDB.healthTextMode end, value = "percent", set = function(mode) _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Show value", get = function() return _G.FlexxUIDB.healthTextMode end, value = "value", set = function(mode) _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Hide health text", get = function() return _G.FlexxUIDB.healthTextMode end, value = "none", set = function(mode) _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls() end, gapAfter = 12 },
          { type = "note", text = "Health value position" },
          { type = "radio", label = "Right", get = function() return _G.FlexxUIDB.healthTextAlign or "right" end, value = "right", set = function(align) _G.FlexxUIDB.healthTextAlign = align; if ns.UnitFrames and ns.UnitFrames.SetHealthTextAlign then ns.UnitFrames.SetHealthTextAlign(align) end; O.RefreshControls() end },
          { type = "radio", label = "Center", get = function() return _G.FlexxUIDB.healthTextAlign or "right" end, value = "center", set = function(align) _G.FlexxUIDB.healthTextAlign = align; if ns.UnitFrames and ns.UnitFrames.SetHealthTextAlign then ns.UnitFrames.SetHealthTextAlign(align) end; O.RefreshControls() end, gapAfter = 12 },
          { type = "note", text = "Health value color" },
          { type = "radio", label = "Class color", get = function() return _G.FlexxUIDB.healthTextColorMode end, value = "class", set = function(mode) _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Light", get = function() return _G.FlexxUIDB.healthTextColorMode end, value = "white", set = function(mode) _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Dark", get = function() return _G.FlexxUIDB.healthTextColorMode end, value = "dark", set = function(mode) _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Flexx gold", get = function() return _G.FlexxUIDB.healthTextColorMode end, value = "yellow", set = function(mode) _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls() end },
        },
      },
    },
  })

  O.BuildSchemaPage(panelPower, {
    cardAlpha = 0.80,
    sectionIndex = true,
    sections = {
      {
        title = "Layout",
        hint = "Where the primary resource bar sits on the player frame.",
        collapsedKey = "player_power_layout",
        controls = {
          { type = "radio", label = "Full width below health", get = function() return _G.FlexxUIDB.powerBarLayout or "full" end, value = "full", set = function(mode) _G.FlexxUIDB.powerBarLayout = mode; if ns.UnitFrames and ns.UnitFrames.SetPowerBarLayout then ns.UnitFrames.SetPowerBarLayout(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Inset (overlaps health)", get = function() return _G.FlexxUIDB.powerBarLayout or "full" end, value = "inset", set = function(mode) _G.FlexxUIDB.powerBarLayout = mode; if ns.UnitFrames and ns.UnitFrames.SetPowerBarLayout then ns.UnitFrames.SetPowerBarLayout(mode) end; O.RefreshControls() end, gapAfter = 12 },
        },
      },
      {
        title = "Bar texture",
        hint = "Art on the fill strip. Default matches the stock UI bar; None and Flat use solid colors you control under Fill color.",
        collapsedKey = "player_power_texture",
        controls = {
          { type = "radio", label = "None (solid)", get = function() return _G.FlexxUIDB.powerBarTexture or "none" end, value = "none", set = function(name) _G.FlexxUIDB.powerBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetPowerBarTexture then ns.UnitFrames.SetPowerBarTexture(name) end; O.RefreshControls() end },
          { type = "radio", label = "Default (Blizzard strip)", get = function() return _G.FlexxUIDB.powerBarTexture or "none" end, value = "default", set = function(name) _G.FlexxUIDB.powerBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetPowerBarTexture then ns.UnitFrames.SetPowerBarTexture(name) end; O.RefreshControls() end },
          { type = "radio", label = "Flat (matte overlay)", get = function() return _G.FlexxUIDB.powerBarTexture or "none" end, value = "flat", set = function(name) _G.FlexxUIDB.powerBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetPowerBarTexture then ns.UnitFrames.SetPowerBarTexture(name) end; O.RefreshControls() end, gapAfter = 12 },
        },
      },
      {
        title = "Tint",
        hint = "Dark (muted) softens the bar frame and dims bright fills. Independent of fill color mode below.",
        collapsedKey = "player_power_tint",
        controls = {
          { type = "radio", label = "None", get = function() return _G.FlexxUIDB.powerBarColorStyle or "none" end, value = "none", set = function(mode) _G.FlexxUIDB.powerBarColorStyle = mode; if ns.UnitFrames and ns.UnitFrames.SetPowerBarColorStyle then ns.UnitFrames.SetPowerBarColorStyle(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Dark (muted)", get = function() return _G.FlexxUIDB.powerBarColorStyle or "none" end, value = "dark", set = function(mode) _G.FlexxUIDB.powerBarColorStyle = mode; if ns.UnitFrames and ns.UnitFrames.SetPowerBarColorStyle then ns.UnitFrames.SetPowerBarColorStyle(mode) end; O.RefreshControls() end, gapAfter = 12 },
        },
      },
      {
        title = "Fill color",
        hint = "Automatic uses Blizzard PowerBarColor for your current spec and primary resource (e.g. DH Havoc Fury vs Vengeance Pain). Custom opens the standard game color window.",
        collapsedKey = "player_power_fill",
        controls = {
          { type = "radio", label = "Automatic (Blizzard / spec & resource)", get = getPowerBarFillMode, value = "automatic", set = setPowerBarFillMode },
          { type = "radio", label = "Custom (color picker)", get = getPowerBarFillMode, value = "custom", set = setPowerBarFillMode, gapAfter = 12 },
          { type = "note", text = "Preview swatch and Choose color… use the movable Blizzard picker (hex, eyedropper when available). Tint still applies when set to Dark." },
          { type = "custom", build = function(parent) return buildPowerBarCustomColorPicker(parent) end, gapAfter = 12 },
        },
      },
      {
        title = "Resource text",
        hint = "Numbers and text on the bar (separate from bar fill).",
        collapsedKey = "player_power_legacy",
        advanced = true,
        controls = {
          { type = "custom", build = function(parent) local row = CreateFrame("Frame", nil, parent); row:SetSize(640, 560); local anchor = CreateFrame("Frame", nil, row); anchor:SetPoint("TOPLEFT", 0, 0); anchor:SetSize(1, 1); addResourceBarLayoutSection(row, anchor, 0); return row end, gapAfter = 8 },
          { type = "custom", build = function(parent) local row = CreateFrame("Frame", nil, parent); row:SetSize(640, 980); local anchor = CreateFrame("Frame", nil, row); anchor:SetPoint("TOPLEFT", 0, 0); anchor:SetSize(1, 1); addResourceBarColorSection(row, anchor, 0); return row end },
        },
      },
    },
  })

  O.BuildSchemaPage(panelClassBar, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Class bar (combo, holy power, chi, shards, ...)",
        collapsedKey = "player_classbar",
        controls = {
          { type = "toggle", label = "Show top resource pips (above health bar)", get = function() return _G.FlexxUIDB.showSecondaryResource ~= false end, set = function(v) _G.FlexxUIDB.showSecondaryResource = v and true or false; _G.FlexxUIDB.combatCenter = _G.FlexxUIDB.combatCenter or {}; _G.FlexxUIDB.combatCenter.topPipsUserSet = true; if ns.UnitFrames and ns.UnitFrames.SetShowSecondaryResource then ns.UnitFrames.SetShowSecondaryResource(v) end end, gapAfter = 12 },
          { type = "radio", label = "Default (bright)", get = function() return _G.FlexxUIDB.classBarColorStyle or "default" end, value = "default", set = function(mode) _G.FlexxUIDB.classBarColorStyle = mode; if ns.UnitFrames and ns.UnitFrames.SetClassBarColorStyle then ns.UnitFrames.SetClassBarColorStyle(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Dark (muted)", get = function() return _G.FlexxUIDB.classBarColorStyle or "default" end, value = "dark", set = function(mode) _G.FlexxUIDB.classBarColorStyle = mode; if ns.UnitFrames and ns.UnitFrames.SetClassBarColorStyle then ns.UnitFrames.SetClassBarColorStyle(mode) end; O.RefreshControls() end },
        },
      },
    },
  })

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
  O.BuildSchemaPage(panelAuras, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Player unit frame buffs",
        collapsedKey = "player_auras_buffs",
        controls = {
          { type = "toggle", label = "Show helpful aura icons", width = 400, get = function() return _G.FlexxUIDB.playerAuraBuffs ~= false end, set = function(v) if ns.UnitFrames and ns.UnitFrames.SetUnitFrameAuraBuffs then ns.UnitFrames.SetUnitFrameAuraBuffs(v) end end },
        },
      },
      {
        title = "Player unit frame debuffs",
        collapsedKey = "player_auras_debuffs",
        controls = {
          { type = "enum", label = "Display", items = { { value = "none", text = "None" }, { value = "icons", text = "Icons" }, { value = "bars", text = "Timer bars" } }, get = getDebuffDisplay, set = setDebuffDisplay, width = 220 },
        },
      },
    },
  })

  O.BuildSchemaPage(panelCast, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Spell name and cast time color",
        collapsedKey = "player_cast_text",
        controls = {
          { type = "radio", label = "Light", get = function() return _G.FlexxUIDB.castBarTextColorMode or "light" end, value = "light", set = function(mode) _G.FlexxUIDB.castBarTextColorMode = mode; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end; O.RefreshControls() end },
          { type = "radio", label = "Dark", get = function() return _G.FlexxUIDB.castBarTextColorMode or "light" end, value = "dark", set = function(mode) _G.FlexxUIDB.castBarTextColorMode = mode; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end; O.RefreshControls() end },
          { type = "radio", label = "Flexx gold (same as name preset)", get = function() return _G.FlexxUIDB.castBarTextColorMode or "light" end, value = "warm_yellow", set = function(mode) _G.FlexxUIDB.castBarTextColorMode = mode; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end; O.RefreshControls() end },
          { type = "radio", label = "Class color", get = function() return _G.FlexxUIDB.castBarTextColorMode or "light" end, value = "class_color", set = function(mode) _G.FlexxUIDB.castBarTextColorMode = mode; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end; O.RefreshControls() end },
        },
      },
      {
        title = "Cast bar fill (progress)",
        collapsedKey = "player_cast_fill",
        controls = {
          { type = "radio", label = "Default (bright)", get = function() return _G.FlexxUIDB.castBarFillStyle or "default" end, value = "default", set = function(mode) _G.FlexxUIDB.castBarFillStyle = mode; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end; O.RefreshControls() end },
          { type = "radio", label = "Dark (muted)", get = function() return _G.FlexxUIDB.castBarFillStyle or "default" end, value = "dark", set = function(mode) _G.FlexxUIDB.castBarFillStyle = mode; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end; O.RefreshControls() end },
        },
      },
      {
        title = "Player cast bar",
        collapsedKey = "player_cast_player",
        controls = {
          { type = "toggle", label = "Show player cast bar", get = function() return _G.FlexxUIDB.castBarEnabled ~= false end, set = function(v) _G.FlexxUIDB.castBarEnabled = v; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end end },
          { type = "toggle", label = "Hide default Blizzard cast bars (player & target)", get = function() return _G.FlexxUIDB.hideBlizzardCastBar == true end, set = function(v) _G.FlexxUIDB.hideBlizzardCastBar = v and true or false; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end end },
          { type = "button", label = "Reset player cast bar position", width = 280, onClick = function() if ns.CastBar and ns.CastBar.ResetCastBarPosition then ns.CastBar.ResetCastBarPosition("player") end end },
        },
      },
    },
  })

  O.BuildSchemaPage(panelGeneral, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Name text color (player frame)",
        collapsedKey = "player_name_color",
        controls = {
          { type = "radio", label = "Same as Fonts default", get = function() return getNameColorOverrideValue("player") end, value = "inherit", set = function(mode) setNameColorOverrideValue("player", mode) end },
          { type = "radio", label = "Class color", get = function() return getNameColorOverrideValue("player") end, value = "class", set = function(mode) setNameColorOverrideValue("player", mode) end },
          { type = "radio", label = "White", get = function() return getNameColorOverrideValue("player") end, value = "white", set = function(mode) setNameColorOverrideValue("player", mode) end },
          { type = "radio", label = "Flexx gold", get = function() return getNameColorOverrideValue("player") end, value = "yellow", set = function(mode) setNameColorOverrideValue("player", mode) end },
          { type = "radio", label = "Dark (near black)", get = function() return getNameColorOverrideValue("player") end, value = "dark", set = function(mode) setNameColorOverrideValue("player", mode) end, gapAfter = 12 },
          { type = "toggle", label = "Show unit name", width = 390, get = function() return _G.FlexxUIDB.showUnitFrameName ~= false end, set = function(v) _G.FlexxUIDB.showUnitFrameName = v; if ns.UnitFrames and ns.UnitFrames.SetShowUnitFrameName then ns.UnitFrames.SetShowUnitFrameName(v) end end },
        },
      },
    },
  })

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

  O.BuildSchemaPage(panelFrame, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Name text color (target frame)",
        collapsedKey = "target_name_color",
        controls = {
          { type = "radio", label = "Same as Fonts default", get = function() return getNameColorOverrideValue("target") end, value = "inherit", set = function(mode) setNameColorOverrideValue("target", mode) end },
          { type = "radio", label = "Class color", get = function() return getNameColorOverrideValue("target") end, value = "class", set = function(mode) setNameColorOverrideValue("target", mode) end },
          { type = "radio", label = "White", get = function() return getNameColorOverrideValue("target") end, value = "white", set = function(mode) setNameColorOverrideValue("target", mode) end },
          { type = "radio", label = "Flexx gold", get = function() return getNameColorOverrideValue("target") end, value = "yellow", set = function(mode) setNameColorOverrideValue("target", mode) end },
          { type = "radio", label = "Dark (near black)", get = function() return getNameColorOverrideValue("target") end, value = "dark", set = function(mode) setNameColorOverrideValue("target", mode) end, gapAfter = 12 },
          { type = "toggle", label = "Show unit name", get = function() return _G.FlexxUIDB.showUnitFrameName ~= false end, set = function(v) _G.FlexxUIDB.showUnitFrameName = v; if ns.UnitFrames and ns.UnitFrames.SetShowUnitFrameName then ns.UnitFrames.SetShowUnitFrameName(v) end end, width = 390 },
        },
      },
      {
        title = "Health bar",
        collapsedKey = "target_health_bar",
        controls = {
          { type = "radio", label = "None", get = function() return _G.FlexxUIDB.healthBarTexture end, value = "none", set = function(name) _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls() end },
          { type = "radio", label = "Default", get = function() return _G.FlexxUIDB.healthBarTexture end, value = "default", set = function(name) _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls() end },
          { type = "radio", label = "Flat", get = function() return _G.FlexxUIDB.healthBarTexture end, value = "flat", set = function(name) _G.FlexxUIDB.healthBarTexture = name; if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture then ns.UnitFrames.SetHealthBarTexture(name) end; O.RefreshControls() end, gapAfter = 12 },
          { type = "toggle", label = "Show incoming heals, absorbs, shields on health bar", get = function() return _G.FlexxUIDB.showHealthBarOverlays ~= false end, set = function(v) _G.FlexxUIDB.showHealthBarOverlays = v; if ns.UnitFrames and ns.UnitFrames.SetShowHealthBarOverlays then ns.UnitFrames.SetShowHealthBarOverlays(v) end end, width = 390 },
        },
      },
      {
        title = "Health value",
        collapsedKey = "target_health_text",
        controls = {
          { type = "note", text = "Format" },
          { type = "radio", label = "Show percent", get = function() return _G.FlexxUIDB.healthTextMode end, value = "percent", set = function(mode) _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Show value", get = function() return _G.FlexxUIDB.healthTextMode end, value = "value", set = function(mode) _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Hide health text", get = function() return _G.FlexxUIDB.healthTextMode end, value = "none", set = function(mode) _G.FlexxUIDB.healthTextMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextMode then ns.UnitFrames.SetHealthTextMode(mode) end; O.RefreshControls() end, gapAfter = 12 },
          { type = "note", text = "Position" },
          { type = "radio", label = "Right", get = function() return _G.FlexxUIDB.healthTextAlign or "right" end, value = "right", set = function(align) _G.FlexxUIDB.healthTextAlign = align; if ns.UnitFrames and ns.UnitFrames.SetHealthTextAlign then ns.UnitFrames.SetHealthTextAlign(align) end; O.RefreshControls() end },
          { type = "radio", label = "Center", get = function() return _G.FlexxUIDB.healthTextAlign or "right" end, value = "center", set = function(align) _G.FlexxUIDB.healthTextAlign = align; if ns.UnitFrames and ns.UnitFrames.SetHealthTextAlign then ns.UnitFrames.SetHealthTextAlign(align) end; O.RefreshControls() end, gapAfter = 12 },
          { type = "note", text = "Color" },
          { type = "radio", label = "Class color", get = function() return _G.FlexxUIDB.healthTextColorMode end, value = "class", set = function(mode) _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Light", get = function() return _G.FlexxUIDB.healthTextColorMode end, value = "white", set = function(mode) _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Dark", get = function() return _G.FlexxUIDB.healthTextColorMode end, value = "dark", set = function(mode) _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls() end },
          { type = "radio", label = "Flexx gold", get = function() return _G.FlexxUIDB.healthTextColorMode end, value = "yellow", set = function(mode) _G.FlexxUIDB.healthTextColorMode = mode; if ns.UnitFrames and ns.UnitFrames.SetHealthTextColorMode then ns.UnitFrames.SetHealthTextColorMode(mode) end; O.RefreshControls() end },
        },
      },
      {
        title = "Resource bar text and layout",
        hint = "Legacy resource controls preserved while migrating to schema.",
        collapsedKey = "target_resource_legacy",
        advanced = true,
        controls = {
          {
            type = "custom",
            build = function(parent)
              local row = CreateFrame("Frame", nil, parent)
              row:SetSize(640, 560)
              local anchor = CreateFrame("Frame", nil, row)
              anchor:SetPoint("TOPLEFT", 0, 0)
              anchor:SetSize(1, 1)
              addResourceBarLayoutSection(row, anchor, 0)
              return row
            end,
            gapAfter = 8,
          },
          {
            type = "custom",
            build = function(parent)
              local row = CreateFrame("Frame", nil, parent)
              row:SetSize(640, 980)
              local anchor = CreateFrame("Frame", nil, row)
              anchor:SetPoint("TOPLEFT", 0, 0)
              anchor:SetSize(1, 1)
              addResourceBarColorSection(row, anchor, 0)
              return row
            end,
          },
        },
      },
    },
  })

  O.BuildSchemaPage(panelCast, {
    cardAlpha = 0.80,
    sections = {
      {
        title = "Target cast bar",
        collapsedKey = "target_castbar",
        controls = {
          { type = "toggle", label = "Show target cast bar", get = function() return _G.FlexxUIDB.castBarTargetEnabled ~= false end, set = function(v) _G.FlexxUIDB.castBarTargetEnabled = v; if ns.CastBar and ns.CastBar.RefreshFromOptions then ns.CastBar.RefreshFromOptions() end end },
          { type = "button", label = "Reset target cast bar position", width = 280, onClick = function() if ns.CastBar and ns.CastBar.ResetCastBarPosition then ns.CastBar.ResetCastBarPosition("target") end end },
        },
      },
    },
  })

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
  local hintPet = O.ArtFont(card, "GameFontHighlightSmall")
  hintPet:SetPoint("TOPLEFT", 14, -14)
  hintPet:SetWidth(640)
  hintPet:SetJustifyH("LEFT")
  hintPet:SetText("Coming soon.")
  content:SetHeight(120)
end

