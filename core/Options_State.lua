local _, ns = ...
ns.Options = ns.Options or {}
local O = ns.Options

O.state = O.state or {
  panel = nil,
  pages = {},
  pageHolders = {},
  controls = {},
  tabButtons = {},
  unitSubTabButtons = {},
  unitFrameHolders = {},
  playerSubTabButtons = {},
  applyPlayerSubTab = nil,
  generalNavButtons = {},
  fontsSubTabButtons = {},
  applyGeneralSubTab = nil,
  applyFontsSubTab = nil,
}

function O.EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if _G.FlexxUIDB.hideBlizzard == nil then _G.FlexxUIDB.hideBlizzard = false end
  if _G.FlexxUIDB.playerHealthColorMode == nil then _G.FlexxUIDB.playerHealthColorMode = "class" end
  if _G.FlexxUIDB.healthBarTexture == nil then _G.FlexxUIDB.healthBarTexture = "default" end
  if _G.FlexxUIDB.healthTextMode == nil then _G.FlexxUIDB.healthTextMode = "percent" end
  if _G.FlexxUIDB.healthTextColorMode == nil then _G.FlexxUIDB.healthTextColorMode = "name" end
  if _G.FlexxUIDB.healthTextColorMode == "dynamic" then _G.FlexxUIDB.healthTextColorMode = "name" end
  -- Legacy: "follow name" toggled; migrate to explicit mode.
  if _G.FlexxUIDB.healthTextFollowNameColor == true then
    _G.FlexxUIDB.healthTextColorMode = "name"
  end
  _G.FlexxUIDB.healthTextFollowNameColor = nil
  if _G.FlexxUIDB.nameTextColorMode == nil then _G.FlexxUIDB.nameTextColorMode = "class" end
  if _G.FlexxUIDB.healthBarMissingColor == nil then
    _G.FlexxUIDB.healthBarMissingColor = { r = 0, g = 0, b = 0, a = 0.55 }
  end
  if _G.FlexxUIDB.showHealthBarOverlays == nil then _G.FlexxUIDB.showHealthBarOverlays = true end
  if _G.FlexxUIDB.unitFrameBackdropShow == nil then _G.FlexxUIDB.unitFrameBackdropShow = true end
  if _G.FlexxUIDB.showSecondaryResource == nil then _G.FlexxUIDB.showSecondaryResource = true end
  if _G.FlexxUIDB.showUnitFrameName == nil then _G.FlexxUIDB.showUnitFrameName = true end
  if _G.FlexxUIDB.healthTextAlign == nil then _G.FlexxUIDB.healthTextAlign = "right" end
  if _G.FlexxUIDB.powerTextShow == nil then _G.FlexxUIDB.powerTextShow = true end
  if _G.FlexxUIDB.powerTextMode == nil then _G.FlexxUIDB.powerTextMode = "percent" end
  if _G.FlexxUIDB.powerTextColorMode == nil then _G.FlexxUIDB.powerTextColorMode = "white" end
  if _G.FlexxUIDB.powerTextColorSplit == nil then _G.FlexxUIDB.powerTextColorSplit = false end
  if _G.FlexxUIDB.powerTextColorMana == nil then _G.FlexxUIDB.powerTextColorMana = _G.FlexxUIDB.powerTextColorMode or "white" end
  if _G.FlexxUIDB.powerTextColorResource == nil then _G.FlexxUIDB.powerTextColorResource = _G.FlexxUIDB.powerTextColorMode or "white" end
  -- Legacy / typo: health-style "class" vs resource preset "class_color"
  local validPowerTextColor = { white = true, class_color = true, power_bar = true, amber = true, ice = true }
  for _, key in ipairs({ "powerTextColorMode", "powerTextColorMana", "powerTextColorResource" }) do
    local v = _G.FlexxUIDB[key]
    if v == "class" then _G.FlexxUIDB[key] = "class_color" end
    v = _G.FlexxUIDB[key]
    if v ~= nil and not validPowerTextColor[v] then _G.FlexxUIDB[key] = "white" end
  end
  if _G.FlexxUIDB.powerTextAlign == nil then _G.FlexxUIDB.powerTextAlign = "center" end
  if _G.FlexxUIDB.powerBarColorStyle == nil then _G.FlexxUIDB.powerBarColorStyle = "default" end
  if _G.FlexxUIDB.classBarColorStyle == nil then _G.FlexxUIDB.classBarColorStyle = "default" end
  if _G.FlexxUIDB.castBarFillStyle == nil then _G.FlexxUIDB.castBarFillStyle = "default" end
  if _G.FlexxUIDB.outputLogWindowOpen == nil then _G.FlexxUIDB.outputLogWindowOpen = false end
  if _G.FlexxUIDB.optionsUnitSubTab == nil then _G.FlexxUIDB.optionsUnitSubTab = "player" end
  if _G.FlexxUIDB.optionsPlayerSubTab == nil then _G.FlexxUIDB.optionsPlayerSubTab = "health" end
  if _G.FlexxUIDB.castBarEnabled == nil then _G.FlexxUIDB.castBarEnabled = true end
  if _G.FlexxUIDB.castBarShowIdle == nil then _G.FlexxUIDB.castBarShowIdle = false end
  if _G.FlexxUIDB.castBarLayoutPreview == nil then _G.FlexxUIDB.castBarLayoutPreview = false end
  if _G.FlexxUIDB.castBarTargetEnabled == nil then _G.FlexxUIDB.castBarTargetEnabled = true end
  if _G.FlexxUIDB.castBarTargetShowIdle == nil then _G.FlexxUIDB.castBarTargetShowIdle = false end
  if _G.FlexxUIDB.hideBlizzardCastBar == nil then _G.FlexxUIDB.hideBlizzardCastBar = false end
  if _G.FlexxUIDB.castBarTextColorMode == nil then _G.FlexxUIDB.castBarTextColorMode = "light" end
  if ns.Fonts and ns.Fonts.EnsureDB then ns.Fonts.EnsureDB() end
  if _G.FlexxUIDB.optionsGeneralSubTab == nil then _G.FlexxUIDB.optionsGeneralSubTab = "settings" end
  if _G.FlexxUIDB.optionsFontsSubTab == nil then _G.FlexxUIDB.optionsFontsSubTab = "ui" end
end

function O.StyleSurface(frame, alpha)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = nil,
    tile = false,
    edgeSize = 0,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
  })
  frame:SetBackdropColor(0.06, 0.07, 0.09, alpha or 0.96)
  -- BackdropTemplate can still draw a default edge; hide it for flat fills.
  frame:SetBackdropBorderColor(0, 0, 0, 0)
end

function O.RefreshScrollPages()
  local function refresh(holder)
    if holder and holder.RefreshScroll then
      holder:RefreshScroll()
    end
  end
  for _, holder in pairs(O.state.pageHolders) do
    refresh(holder)
  end
  for _, holder in pairs(O.state.unitFrameHolders) do
    refresh(holder)
  end
end

function O.RefreshControls()
  O.EnsureDB()
  for _, ctrl in ipairs(O.state.controls) do
    if ctrl.Refresh then ctrl:Refresh() end
  end
  O.RefreshScrollPages()
end

function O.SelectPlayerSubTab(subKey)
  O.EnsureDB()
  if subKey ~= "health" and subKey ~= "power" and subKey ~= "classbar" and subKey ~= "cast" and subKey ~= "general" then
    subKey = "health"
  end
  _G.FlexxUIDB.optionsPlayerSubTab = subKey
  for _, btn in pairs(O.state.playerSubTabButtons) do
    if btn and btn.RefreshPlayerSub then btn:RefreshPlayerSub() end
  end
  if O.state.applyPlayerSubTab then
    O.state.applyPlayerSubTab()
  end
  O.RefreshScrollPages()
end

function O.SelectUnitSubTab(subKey)
  O.EnsureDB()
  if subKey ~= "player" and subKey ~= "target" and subKey ~= "pet" then
    subKey = "player"
  end
  _G.FlexxUIDB.optionsUnitSubTab = subKey
  for key, holder in pairs(O.state.unitFrameHolders) do
    if holder then holder:SetShown(key == subKey) end
  end
  for _, btn in pairs(O.state.unitSubTabButtons) do
    if btn and btn.RefreshNav then btn:RefreshNav() end
  end
  if subKey == "player" and O.state.applyPlayerSubTab then
    O.state.applyPlayerSubTab()
  end
  O.RefreshScrollPages()
end

function O.SelectGeneralSubTab(subKey)
  O.EnsureDB()
  if subKey ~= "settings" and subKey ~= "fonts" then
    subKey = "settings"
  end
  _G.FlexxUIDB.optionsGeneralSubTab = subKey
  for _, btn in pairs(O.state.generalNavButtons) do
    if btn and btn.RefreshGeneralNav then btn:RefreshGeneralNav() end
  end
  if O.state.applyGeneralSubTab then
    O.state.applyGeneralSubTab()
  end
  O.RefreshScrollPages()
end

function O.SelectFontsSubTab(subKey)
  O.EnsureDB()
  if subKey ~= "ui" and subKey ~= "unit" then
    subKey = "ui"
  end
  _G.FlexxUIDB.optionsFontsSubTab = subKey
  for _, btn in pairs(O.state.fontsSubTabButtons) do
    if btn and btn.RefreshFontsSub then btn:RefreshFontsSub() end
  end
  if O.state.applyFontsSubTab then
    O.state.applyFontsSubTab()
  end
  O.RefreshScrollPages()
end

function O.SelectTab(tabKey)
  for key, holder in pairs(O.state.pageHolders) do
    holder:SetShown(key == tabKey)
  end
  if O.state.panel then
    O.state.panel.activeTab = tabKey
  end
  for _, btn in pairs(O.state.tabButtons) do
    if btn.RefreshTab then
      btn:RefreshTab()
    end
  end
  if tabKey == "unit" then
    O.SelectUnitSubTab(_G.FlexxUIDB.optionsUnitSubTab or "player")
  end
  if tabKey == "general" and O.state.applyGeneralSubTab then
    O.state.applyGeneralSubTab()
  end
  O.RefreshScrollPages()
end

