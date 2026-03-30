local _, ns = ...

ns.UnitFrames = ns.UnitFrames or {}
local UF = ns.UnitFrames

UF.state = UF.state or {
  frames = {},
  blizzardHooksInstalled = false,
}

UF.const = UF.const or {
  textures = {
    ["none"] = "Interface\\Buttons\\WHITE8x8",
    ["default"] = "Interface\\TargetingFrame\\UI-StatusBar",
    ["flat"] = "Interface\\Buttons\\WHITE8x8",
    ["smooth"] = "Interface\\Buttons\\WHITE8x8",
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
    name = true,
    classdark = true,
    solid = true,
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
  if _G.FlexxUIDB.hideBlizzard == nil then _G.FlexxUIDB.hideBlizzard = false end
  if _G.FlexxUIDB.healthBarTexture == nil then _G.FlexxUIDB.healthBarTexture = "default" end
  if _G.FlexxUIDB.healthBarTexture == "dull" then _G.FlexxUIDB.healthBarTexture = "smooth" end
  if _G.FlexxUIDB.playerHealthColorMode == nil then _G.FlexxUIDB.playerHealthColorMode = "class" end
  if _G.FlexxUIDB.healthTextMode == nil then _G.FlexxUIDB.healthTextMode = "percent" end
  if _G.FlexxUIDB.healthTextColorMode == nil then _G.FlexxUIDB.healthTextColorMode = "name" end
  if _G.FlexxUIDB.healthTextColorMode == "dynamic" then _G.FlexxUIDB.healthTextColorMode = "name" end
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
  local validPTC = { white = true, class_color = true, power_bar = true, amber = true, ice = true }
  for _, key in ipairs({ "powerTextColorMode", "powerTextColorMana", "powerTextColorResource" }) do
    local v = _G.FlexxUIDB[key]
    if v == "class" then _G.FlexxUIDB[key] = "class_color" end
    v = _G.FlexxUIDB[key]
    if v ~= nil and not validPTC[v] then _G.FlexxUIDB[key] = "white" end
  end
  if _G.FlexxUIDB.powerTextAlign == nil then _G.FlexxUIDB.powerTextAlign = "center" end
  if _G.FlexxUIDB.powerBarColorStyle == nil then _G.FlexxUIDB.powerBarColorStyle = "default" end
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

