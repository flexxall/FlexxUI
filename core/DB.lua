local _, ns = ...

ns.DB = ns.DB or {}

ns.DB.Defaults = {
  enabled = true,
  locked = false,
  hideBlizzard = false,
  healthBarTexture = "default",
  playerHealthColorMode = "class",
  healthTextMode = "percent",
  healthTextColorMode = "name",
  nameTextColorMode = "class",
  showUnitFrameName = true,
  healthTextAlign = "right",
  powerTextShow = true,
  powerTextMode = "percent",
  powerTextColorMode = "white",
  powerTextColorSplit = false,
  powerTextColorMana = "white",
  powerTextColorResource = "white",
  powerTextAlign = "center",
  powerBarColorStyle = "default",
  --- Top class resource pips (combo, holy power, chi, etc.): default bright class tint vs muted dark.
  classBarColorStyle = "default",
  castBarFillStyle = "default",
  -- Depleted / missing health (StatusBar backdrop behind the fill). Explicit so it stays correct if frame bg changes.
  healthBarMissingColor = { r = 0, g = 0, b = 0, a = 0.55 },
  showHealthBarOverlays = true,
  -- Dark panel behind player/target unit frames (dialog backdrop fill).
  unitFrameBackdropShow = true,
  showSecondaryResource = true,
  outputLogWindowOpen = false,
  optionsUnitSubTab = "player",
  optionsPlayerSubTab = "health",
  castBarEnabled = true,
  castBarShowIdle = false,
  castBarLayoutPreview = false,
  castBarTargetEnabled = true,
  castBarTargetShowIdle = false,
  hideBlizzardCastBar = false,
  -- Cast bar spell name + timer: light (default UI), dark (readable on bright fill), warm yellow (matches name "yellow" preset).
  castBarTextColorMode = "light",
  optionsGeneralSubTab = "settings",
  optionsFontsSubTab = "ui",
}

local function DeepCopy(src)
  if type(src) ~= "table" then return src end
  local out = {}
  for k, v in pairs(src) do
    out[k] = DeepCopy(v)
  end
  return out
end

local function ApplyDefaults(dst, defaults)
  if type(dst) ~= "table" then return end
  for k, v in pairs(defaults or {}) do
    if dst[k] == nil then
      dst[k] = DeepCopy(v)
    elseif type(v) == "table" and type(dst[k]) == "table" then
      ApplyDefaults(dst[k], v)
    end
  end
end

ns.DB.ApplyDefaults = ApplyDefaults
ns.DB.DeepCopy = DeepCopy

--- Replace options with defaults. Frame positions remain in FlexxUILayout (see core/Movers.lua).
function ns.DB.Reset()
  _G.FlexxUIDB = DeepCopy(ns.DB.Defaults or {})
  return _G.FlexxUIDB
end

