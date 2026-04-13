local _, ns = ...

--- FlexxUI accent gold: single RGB source for unit name/health "yellow", cast bar warm_yellow, combat lane stacks,
--- resting zzz, and any other warm-gold text. Change here to retheme the whole UI.
--- Paired font object: global `FlexxUIFont_FlexxGold` (see `core/Fonts.lua` — `EnsureFlexxGoldFont`).
ns.FlexxGold = { 1, 0.88, 0.35 }

function ns.GetFlexxGoldRGB()
  local t = ns.FlexxGold
  return t[1], t[2], t[3]
end

function ns.SetFontStringFlexxGoldColor(fs)
  if not fs or not fs.SetTextColor then return end
  fs:SetTextColor(ns.GetFlexxGoldRGB())
end
