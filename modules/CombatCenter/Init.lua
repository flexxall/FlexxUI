local _, ns = ...

--- Public API table (filled by Core / lane modules / CombatCenter.lua).
ns.CombatCenter = ns.CombatCenter or {}
local CC = ns.CombatCenter

CC.state = CC.state or {
  frame = nil,
  lane1Wrap = nil,
  lane1Bg = nil,
  lane1BgBottom = nil,
  lane1 = nil,
  lane1Pips = {},
  lane2 = nil,
  lane3 = nil,
  lane1Bar = nil,
  lane2Icons = {},
  lane3Icons = {},
  updater = nil,
  dragHandle = nil,
  lastCastSpellId = nil,
  lastCastSpellName = nil,
  lastCastAt = nil,
  rotationLongCdEnd = nil,
  regenCombatUi = nil,
}

--- Spellbook id cache (lane 3); mutated by Core.RefreshSpellBookSpellIDCache.
CC.spellBookSpellIDs = CC.spellBookSpellIDs or {}

--- Shared layout / tuning constants for all Combat Center chunks.
CC.const = CC.const or {
  ICONS_LANE2 = 8,
  ICONS_LANE3 = 5,
  LANE1_STATUS_H = 10,
  PIP_H = 6,
  MAX_PIPS = 8,
  --- Gap between lane 1 pip segments; also used between lane 2 / lane 3 icons (CombatCenter Layout).
  PIP_SEGMENT_GAP = 3,
  LANE1_POOL_MAX_THRESHOLD = 20,
  PIP_WRAP_PAD = 2,
  PIP_WRAP_BG_A = 0.34,
  PIP_BG_PAD = 2,
  LANE1_BOTTOM_BG_H = 1,
  PIP_ROTATION_GAP = 2,
  DRAG_HANDLE_H = 28,
  PIP_EMPTY_R = 0.10,
  PIP_EMPTY_G = 0.11,
  PIP_EMPTY_B = 0.13,
  PIP_EMPTY_A = 0.58,
  PIP_BAR_WIDTH_FRAC = 0.8,
  --- Just above typical GCD so short procs still qualify; lane 3 also uses action-bar duration when spell APIs mask it.
  LANE3_MIN_SPELL_CD_DURATION = 1.55,
  ROTATION_LONG_CD_MIN_DURATION = 2.5,
  BONUS_BAR_FIRST = 73,
  BONUS_BAR_LAST = 84,
  GCD_TRACKER_SPELL_ID = 61304,
  DK_RUNE_COUNT = 6,
}
