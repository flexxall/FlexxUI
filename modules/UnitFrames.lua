local _, ns = ...

ns.UnitFrames = ns.UnitFrames or {}
local UF = ns.UnitFrames

UF.state = UF.state or {
  frames = {},
}

UF.const = UF.const or {
  textures = {
    ["none"] = "Interface\\Buttons\\WHITE8x8",
    ["default"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["flat"] = "Interface\\Buttons\\WHITE8x8",
  },
  colorModes = {
    class = true,
    blizzard = true,
    dark = true,
  },
  healthTextModes = {
    none = true,
    percent = true,
    value = true,
  },
  healthTextColorModes = {
    class = true,
    white = true,
    yellow = true,
    dark = true,
  },
  nameTextColorModes = {
    class = true,
    white = true,
    yellow = true,
    dark = true,
  },
  healthTextAligns = {
    right = true,
    center = true,
  },
  powerTextAligns = {
    left = true,
    center = true,
    right = true,
  },
  powerTextModes = {
    percent = true,
    value = true,
  },
  powerTextColorModes = {
    white = true,
    class_color = true,
    power_bar = true,
    amber = true,
    ice = true,
  },
}

function UF.EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if _G.FlexxUIDB.hideBlizzard == nil then _G.FlexxUIDB.hideBlizzard = true end
  if _G.FlexxUIDB.healthBarTexture == nil then _G.FlexxUIDB.healthBarTexture = "default" end
  if _G.FlexxUIDB.healthBarTexture == "dull" or _G.FlexxUIDB.healthBarTexture == "smooth" then _G.FlexxUIDB.healthBarTexture = "flat" end
  if not UF.const.textures[_G.FlexxUIDB.healthBarTexture] then
    _G.FlexxUIDB.healthBarTexture = "default"
  end
  if _G.FlexxUIDB.playerHealthColorMode == nil then _G.FlexxUIDB.playerHealthColorMode = "class" end
  if _G.FlexxUIDB.healthTextMode == nil then _G.FlexxUIDB.healthTextMode = "percent" end
  if _G.FlexxUIDB.healthTextColorMode == nil then _G.FlexxUIDB.healthTextColorMode = "class" end
  if _G.FlexxUIDB.healthTextColorMode == "dynamic" or _G.FlexxUIDB.healthTextColorMode == "name" then _G.FlexxUIDB.healthTextColorMode = "class" end
  if _G.FlexxUIDB.healthTextColorMode == "classdark" then _G.FlexxUIDB.healthTextColorMode = "dark" end
  if _G.FlexxUIDB.healthTextColorMode == "solid" then _G.FlexxUIDB.healthTextColorMode = "white" end
  if _G.FlexxUIDB.healthTextFollowNameColor == true then
    _G.FlexxUIDB.healthTextColorMode = "class"
  end
  _G.FlexxUIDB.healthTextFollowNameColor = nil
  if _G.FlexxUIDB.nameTextColorMode == nil then _G.FlexxUIDB.nameTextColorMode = "class" end
  if _G.FlexxUIDB.healthBarMissingColor == nil then
    _G.FlexxUIDB.healthBarMissingColor = { r = 0, g = 0, b = 0, a = 0.55 }
  end
  if _G.FlexxUIDB.showHealthBarOverlays == nil then _G.FlexxUIDB.showHealthBarOverlays = true end
  if _G.FlexxUIDB.unitFrameBackdropShow == nil then _G.FlexxUIDB.unitFrameBackdropShow = true end
  if _G.FlexxUIDB.showSecondaryResource == nil then
    local combatEnabled = _G.FlexxUIDB.combatCenter and _G.FlexxUIDB.combatCenter.enabled == true
    _G.FlexxUIDB.showSecondaryResource = not combatEnabled
  end
  if _G.FlexxUIDB.showUnitFrameName == nil then _G.FlexxUIDB.showUnitFrameName = true end
  if _G.FlexxUIDB.healthTextAlign == nil then _G.FlexxUIDB.healthTextAlign = "right" end
  if _G.FlexxUIDB.powerTextShow == nil then _G.FlexxUIDB.powerTextShow = true end
  if _G.FlexxUIDB.powerTextMode == nil then _G.FlexxUIDB.powerTextMode = "percent" end
  if _G.FlexxUIDB.powerTextColorMode == nil then _G.FlexxUIDB.powerTextColorMode = "white" end
  if _G.FlexxUIDB.powerTextColorSplit == nil then _G.FlexxUIDB.powerTextColorSplit = false end
  if _G.FlexxUIDB.powerTextColorMana == nil then _G.FlexxUIDB.powerTextColorMana = _G.FlexxUIDB.powerTextColorMode or "white" end
  if _G.FlexxUIDB.powerTextColorResource == nil then _G.FlexxUIDB.powerTextColorResource = _G.FlexxUIDB.powerTextColorMode or "white" end
  local validPTC = { white = true, class_color = true, power_bar = true, amber = true, ice = true }
  for _, key in ipairs({ "powerTextColorMode", "powerTextColorMana", "powerTextColorResource" }) do
    local v = _G.FlexxUIDB[key]
    if v == "class" then _G.FlexxUIDB[key] = "class_color" end
    v = _G.FlexxUIDB[key]
    if v ~= nil and not validPTC[v] then _G.FlexxUIDB[key] = "white" end
  end
  if _G.FlexxUIDB.powerTextAlign == nil then _G.FlexxUIDB.powerTextAlign = "center" end
  if _G.FlexxUIDB.powerBarColorStyle == nil then _G.FlexxUIDB.powerBarColorStyle = "none" end
  if _G.FlexxUIDB.powerBarColorStyle == "default" then _G.FlexxUIDB.powerBarColorStyle = "none" end
  if _G.FlexxUIDB.powerBarTexture == nil then _G.FlexxUIDB.powerBarTexture = "none" end
  if _G.FlexxUIDB.powerBarTexture ~= "none" and _G.FlexxUIDB.powerBarTexture ~= "default" and _G.FlexxUIDB.powerBarTexture ~= "flat" then
    _G.FlexxUIDB.powerBarTexture = "none"
  end
  if _G.FlexxUIDB.powerBarUseCustomColor == nil then _G.FlexxUIDB.powerBarUseCustomColor = false end
  if type(_G.FlexxUIDB.powerBarCustomColor) ~= "table" then
    _G.FlexxUIDB.powerBarCustomColor = { r = 0.22, g = 0.52, b = 0.95 }
  end
  if _G.FlexxUIDB.powerBarLayout == nil then _G.FlexxUIDB.powerBarLayout = "full" end
  if _G.FlexxUIDB.powerBarLayout ~= "full" and _G.FlexxUIDB.powerBarLayout ~= "inset" then
    _G.FlexxUIDB.powerBarLayout = "full"
  end
  if _G.FlexxUIDB.classBarColorStyle == nil then _G.FlexxUIDB.classBarColorStyle = "default" end
  if UF.EnsureAuraDB then UF.EnsureAuraDB() end
  if _G.FlexxUIDB.castBarFillStyle == nil then _G.FlexxUIDB.castBarFillStyle = "default" end
  if _G.FlexxUIDB.optionsPlayerSubTab == nil then _G.FlexxUIDB.optionsPlayerSubTab = "health" end
  if _G.FlexxUIDB.optionsTargetSubTab == nil then _G.FlexxUIDB.optionsTargetSubTab = "frame" end
end

