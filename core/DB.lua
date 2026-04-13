local _, ns = ...

ns.DB = ns.DB or {}

ns.DB.Defaults = {
  locked = false,
  --- Custom unit frames replace stock; hiding default player/target matches typical expectations.
  hideBlizzard = true,
  --- Minimap launcher: show/hide and angle (degrees) on the minimap ring; legacy X/Y migrates on load.
  minimapButtonShow = true,
  minimapButtonAngle = 177,
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
  --- Tint only: "none" = full saturation, "dark" = muted (legacy saved "default" migrates to "none").
  powerBarColorStyle = "none",
  --- Same keys as health bar texture: none = flat WHITE8x8, default = Blizzard UI-StatusBar strip, flat = flat matte.
  powerBarTexture = "none",
  powerBarUseCustomColor = false,
  powerBarCustomColor = { r = 0.22, g = 0.52, b = 0.95 },
  --- full = resource bar below health (default). inset = thin bar overlapping bottom edge of health.
  powerBarLayout = "full",
  --- Top class resource pips (combo, holy power, chi, etc.): default bright class tint vs muted dark.
  classBarColorStyle = "default",
  castBarFillStyle = "default",
  -- Depleted / missing health (StatusBar backdrop behind the fill). Explicit so it stays correct if frame bg changes.
  healthBarMissingColor = { r = 0, g = 0, b = 0, a = 0.55 },
  showHealthBarOverlays = true,
  -- Dark panel behind player/target unit frames (dialog backdrop fill).
  unitFrameBackdropShow = true,
  showSecondaryResource = true,
  --- Player / target unit frame auras are separate (Auras.lua). Legacy unitFrameAura* mirror player for older API.
  playerAuraBuffs = true,
  targetAuraBuffs = true,
  playerAuraDebuffDisplay = "icons",
  targetAuraDebuffDisplay = "icons",
  optionsUnitSubTab = "player",
  optionsPlayerSubTab = "health",
  optionsTargetSubTab = "frame",
  castBarEnabled = true,
  castBarShowIdle = false,
  castBarTargetEnabled = true,
  castBarTargetShowIdle = false,
  hideBlizzardCastBar = false,
  -- Cast bar spell name + timer: light (default UI), dark (readable on bright fill), Flexx gold (warm_yellow; matches name "yellow" preset).
  castBarTextColorMode = "light",
  optionsGeneralSubTab = "settings",
  optionsFontsSubTab = "ui",
  optionsDevSubTab = "cast",
  optionsCombatSubTab = "overview",
  optionsShowAdvanced = false,
  debugActionLogEnabled = false,
  debugActionMonitorShown = false,
  optionsCollapsed = {},
  combatCenter = {
    enabled = true,
    onlyInCombat = false,
    lockFrame = false,
    --- Screen offset from UIParent center (px). Negative Y moves the block down.
    anchorX = 0,
    anchorY = -180,
    scale = 1,
    iconSize = 44,
    spacing = 8,
    debuffSize = 54,
    showResourceLane = true,
    showRotationLane = true,
    showCooldownLane = true,
    showDebuffLane = true,
    trackOnlyRelevantDebuffs = true,
    --- Lane 3: only show cooldowns at least this long (seconds). Action bar only — no full spellbook (avoids fishing/profs).
    lane3MinCooldownSeconds = 8,
    --- Optional spell IDs to always consider for lane 3 (e.g. trinket not on bar). Uses bar slot when placed on an action slot.
    extraCooldownSpellIDs = {},
  },
  --- Aura layout (px): BOTTOMLEFT of row → TOPLEFT of health. Per-unit; legacy unitFrameAura*Anchor* migrate on load.
  playerAuraBuffAnchorX = 0,
  playerAuraBuffAnchorY = 50,
  playerAuraDebuffAnchorX = 0,
  playerAuraDebuffAnchorY = 18,
  targetAuraBuffAnchorX = 0,
  targetAuraBuffAnchorY = 50,
  targetAuraDebuffAnchorX = 0,
  targetAuraDebuffAnchorY = 18,
  unitFrameAuraDevPreviewBuff = false,
  unitFrameAuraDevPreviewDebuff = false,
  unitFrameAuraDevPreviewBars = false,
  --- Dev Settings: show raid-style group label (G1) on player frame while solo for layout testing.
  devGroupIndicatorShowSolo = false,
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

