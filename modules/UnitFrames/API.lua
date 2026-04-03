local _, ns = ...
local UF = ns.UnitFrames

function UF.SetHealthBarTexture(name)
  UF.EnsureDB()
  if not UF.const.textures[name] then return false end
  _G.FlexxUIDB.healthBarTexture = name
  for _, f in pairs(UF.state.frames) do
    if f and f.health then
      UF.ApplyHealthBarTexture(f.health)
      if f.power then UF.ApplyPowerBarTexture(f.power) end
      UF.UpdateUnitFrame(f)
    end
  end
  return true
end

function UF.SetPlayerHealthColorMode(mode)
  UF.EnsureDB()
  if not UF.const.colorModes[mode] then return false end
  _G.FlexxUIDB.playerHealthColorMode = mode
  if UF.state.frames.player then
    UF.UpdateUnitFrame(UF.state.frames.player)
  end
  return true
end

function UF.SetPowerBarColorStyle(style)
  UF.EnsureDB()
  if style ~= "default" and style ~= "dark" then return false end
  _G.FlexxUIDB.powerBarColorStyle = style
  for _, f in pairs(UF.state.frames) do
    if f and f.power then
      UF.ApplyPowerBarTexture(f.power)
      if f.unit then UF.UpdateUnitFrame(f) end
    end
  end
  return true
end

function UF.SetPowerBarLayout(layout)
  UF.EnsureDB()
  if layout ~= "full" and layout ~= "inset" then return false end
  _G.FlexxUIDB.powerBarLayout = layout
  if UF.ApplyUnitFramePowerBarLayout then
    for _, f in pairs(UF.state.frames) do
      if f and f.power and f.health then
        UF.ApplyUnitFramePowerBarLayout(f)
        if f.unit then UF.UpdateUnitFrame(f) end
      end
    end
  end
  return true
end

function UF.SetUnitFrameAuraBuffs(enabled)
  UF.EnsureDB()
  _G.FlexxUIDB.playerAuraBuffs = enabled and true or false
  if UF.EnsureAuraDB then UF.EnsureAuraDB() end
  if UF.RefreshAurasFromOptions then UF.RefreshAurasFromOptions() end
  return true
end

function UF.SetUnitFrameAuraDebuffDisplay(mode)
  UF.EnsureDB()
  if mode ~= "none" and mode ~= "icons" and mode ~= "bars" then return false end
  _G.FlexxUIDB.playerAuraDebuffDisplay = mode
  if UF.EnsureAuraDB then UF.EnsureAuraDB() end
  if UF.RefreshAurasFromOptions then UF.RefreshAurasFromOptions() end
  return true
end

function UF.SetUnitFrameAuraDebuffs(enabled)
  return UF.SetUnitFrameAuraDebuffDisplay(enabled and "icons" or "none")
end

function UF.SetUnitFrameAuraBars(enabled)
  if enabled then
    return UF.SetUnitFrameAuraDebuffDisplay("bars")
  end
  UF.EnsureDB()
  if (_G.FlexxUIDB.playerAuraDebuffDisplay or "") == "bars" then
    return UF.SetUnitFrameAuraDebuffDisplay("icons")
  end
  return true
end

function UF.SetClassBarColorStyle(style)
  UF.EnsureDB()
  if style ~= "default" and style ~= "dark" then return false end
  _G.FlexxUIDB.classBarColorStyle = style
  for _, f in pairs(UF.state.frames) do
    if f and f.unit then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetHealthTextMode(mode)
  UF.EnsureDB()
  if not UF.const.healthTextModes[mode] then return false end
  _G.FlexxUIDB.healthTextMode = mode
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetHealthTextColorMode(mode)
  UF.EnsureDB()
  if not UF.const.healthTextColorModes[mode] then return false end
  _G.FlexxUIDB.healthTextColorMode = mode
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetHealthTextFollowNameColor(enabled)
  UF.EnsureDB()
  if enabled then
    _G.FlexxUIDB.healthTextColorMode = "class"
  end
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetNameTextColorMode(mode)
  UF.EnsureDB()
  if not UF.const.nameTextColorModes[mode] then return false end
  _G.FlexxUIDB.nameTextColorMode = mode
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  if ns.CastBar and ns.CastBar.RefreshFromOptions then
    ns.CastBar.RefreshFromOptions()
  end
  return true
end

--- nil = use global nameTextColorMode (Fonts → Unit). Otherwise class / white / yellow / dark for this frame only.
function UF.SetNameTextColorOverride(unitKey, mode)
  UF.EnsureDB()
  if unitKey ~= "player" and unitKey ~= "target" and unitKey ~= "pet" then
    return false
  end
  if mode ~= nil and not UF.const.nameTextColorModes[mode] then
    return false
  end
  local field = (unitKey == "player" and "nameTextColorOverridePlayer")
    or (unitKey == "target" and "nameTextColorOverrideTarget")
    or "nameTextColorOverridePet"
  _G.FlexxUIDB[field] = mode
  local f = UF.state.frames[unitKey]
  if f then UF.UpdateUnitFrame(f) end
  if ns.CastBar and ns.CastBar.RefreshFromOptions then
    ns.CastBar.RefreshFromOptions()
  end
  return true
end

function UF.SetShowHealthBarOverlays(enabled)
  UF.EnsureDB()
  _G.FlexxUIDB.showHealthBarOverlays = enabled and true or false
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetShowSecondaryResource(enabled)
  UF.EnsureDB()
  _G.FlexxUIDB.showSecondaryResource = enabled and true or false
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetUnitFrameBackdropShow(enabled)
  UF.EnsureDB()
  _G.FlexxUIDB.unitFrameBackdropShow = enabled and true or false
  for _, f in pairs(UF.state.frames) do
    if f then UF.ApplyUnitFrameBackdrop(f) end
  end
  return true
end

function UF.SetShowUnitFrameName(enabled)
  UF.EnsureDB()
  _G.FlexxUIDB.showUnitFrameName = enabled and true or false
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetHealthTextAlign(align)
  UF.EnsureDB()
  if not UF.const.healthTextAligns[align] then return false end
  _G.FlexxUIDB.healthTextAlign = align
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetPowerTextShow(enabled)
  UF.EnsureDB()
  _G.FlexxUIDB.powerTextShow = enabled and true or false
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetPowerTextAlign(align)
  UF.EnsureDB()
  if not UF.const.powerTextAligns[align] then return false end
  _G.FlexxUIDB.powerTextAlign = align
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetPowerTextMode(mode)
  UF.EnsureDB()
  if not UF.const.powerTextModes[mode] then return false end
  _G.FlexxUIDB.powerTextMode = mode
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetPowerTextColorMode(mode)
  UF.EnsureDB()
  if not UF.const.powerTextColorModes[mode] then return false end
  _G.FlexxUIDB.powerTextColorMode = mode
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetPowerTextColorSplit(enabled)
  UF.EnsureDB()
  _G.FlexxUIDB.powerTextColorSplit = enabled and true or false
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetPowerTextColorMana(mode)
  UF.EnsureDB()
  if not UF.const.powerTextColorModes[mode] then return false end
  _G.FlexxUIDB.powerTextColorMana = mode
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

function UF.SetPowerTextColorResource(mode)
  UF.EnsureDB()
  if not UF.const.powerTextColorModes[mode] then return false end
  _G.FlexxUIDB.powerTextColorResource = mode
  for _, f in pairs(UF.state.frames) do
    if f then UF.UpdateUnitFrame(f) end
  end
  return true
end

