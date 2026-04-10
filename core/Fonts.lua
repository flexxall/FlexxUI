local _, ns = ...

--- Central font presets for FlexxUI. Register FontStrings, then Apply() after UI exists or when the user changes options.
ns.Fonts = ns.Fonts or {}
local F = ns.Fonts

local regUnit = { small = {}, medium = {}, large = {} }
local regAll = { small = {}, medium = {}, large = {} }

local PRESETS = {
  default = nil,
  --- Blizzard Friz Quadrata (same family as much default UI text).
  friz = { file = "Fonts\\FRIZQT__.TTF", small = 11, medium = 12, large = 14 },
  --- Common addon choice; readable at small sizes.
  arial_narrow = { file = "Fonts\\ARIALN.TTF", small = 11, medium = 12, large = 14 },
  --- Roboto Condensed Bold (bundled under FlexxUI/Fonts; same face as Platynator default).
  roboto_condensed = { file = "Interface\\AddOns\\FlexxUI\\Fonts\\RobotoCondensed-Bold.ttf", small = 11, medium = 12, large = 14 },
}

local function isValidPresetKey(key)
  return key == "default" or key == "friz" or key == "arial_narrow" or key == "roboto_condensed"
end

local function categoryForTemplate(templateName)
  if templateName == "GameFontHighlightSmall" or templateName == "GameFontNormalSmall" then
    return "small"
  end
  if templateName == "GameFontNormalLarge" then
    return "large"
  end
  return "medium"
end

local function clampScale(s)
  s = tonumber(s) or 1
  if s < 0.5 then s = 0.5 end
  if s > 2.0 then s = 2.0 end
  return s
end

--- Migrate legacy flexxUIFontPreset + flexxUIFontScope into per-bucket presets and scales.
function F.EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  local db = _G.FlexxUIDB
  if db.flexxUIFontPresetUI == nil and db.flexxUIFontPresetUnit == nil then
    local oldP = db.flexxUIFontPreset or "default"
    local oldS = db.flexxUIFontScope or "all"
    if not isValidPresetKey(oldP) then
      oldP = "default"
    end
    if oldS == "unitframes" then
      db.flexxUIFontPresetUI = "default"
      db.flexxUIFontPresetUnit = oldP
    else
      db.flexxUIFontPresetUI = oldP
      db.flexxUIFontPresetUnit = oldP
    end
  elseif db.flexxUIFontPresetUI == nil then
    db.flexxUIFontPresetUI = "default"
  elseif db.flexxUIFontPresetUnit == nil then
    db.flexxUIFontPresetUnit = db.flexxUIFontPresetUI or "default"
  end
  if _G.FlexxUIDB.flexxUIFontScaleUI == nil then
    _G.FlexxUIDB.flexxUIFontScaleUI = 1.0
  end
  if _G.FlexxUIDB.flexxUIFontScaleUnit == nil then
    _G.FlexxUIDB.flexxUIFontScaleUnit = 1.0
  end
end

--- Register a FontString created with the given template name (for restoring "default").
function F.RegisterFontString(fs, templateName, scope)
  if not fs or not fs.SetFont or not templateName then return end
  fs._flexxFontTemplate = templateName
  local cat = categoryForTemplate(templateName)
  local bucket = (scope == "unit") and regUnit or regAll
  if not bucket[cat] then bucket[cat] = {} end
  table.insert(bucket[cat], fs)
end

--- Create a FontString on ARTWORK layer, register it, return it.
function F.CreateFontString(parent, layer, templateName, scope)
  local fs = parent:CreateFontString(nil, layer or "ARTWORK", templateName)
  F.RegisterFontString(fs, templateName, scope or "all")
  return fs
end

--- After base font apply; survives preset/scale changes (e.g. resting "zzz" middle letter).
local function applyFontExtraSize(fs)
  local d = fs and fs._flexxFontExtraSize
  if not d or type(d) ~= "number" or d == 0 then return end
  local ok, path, size, flags = pcall(function() return fs:GetFont() end)
  if ok and path and type(size) == "number" then
    pcall(function() fs:SetFont(path, size + d, flags or "") end)
  end
end

local function applyToBucket(bucket, presetKey, scale)
  F.EnsureDB()
  scale = clampScale(scale)
  local preset = PRESETS[presetKey]
  for _, list in pairs(bucket) do
    for _, fs in ipairs(list) do
      if fs and fs.SetFont and fs._flexxFontTemplate then
        local tmpl = _G[fs._flexxFontTemplate]
        if not preset then
          if tmpl and tmpl.GetFont then
            local ok, path, size, flags = pcall(function() return tmpl:GetFont() end)
            if ok and path and size then
              local sz = size * scale
              pcall(function() fs:SetFont(path, sz, flags or "") end)
            end
          end
        else
          local cat = categoryForTemplate(fs._flexxFontTemplate)
          local sz = (preset[cat] or preset.medium or 12) * scale
          pcall(function() fs:SetFont(preset.file, sz, "") end)
        end
        applyFontExtraSize(fs)
        if fs._flexxFontOutline then
          local okO, pathO, sizeO = pcall(function() return fs:GetFont() end)
          if okO and pathO and type(sizeO) == "number" then
            pcall(function() fs:SetFont(pathO, sizeO, "OUTLINE") end)
          end
        end
      end
    end
  end
end

function F.Apply()
  F.EnsureDB()
  local pUI = _G.FlexxUIDB.flexxUIFontPresetUI or "default"
  local pU = _G.FlexxUIDB.flexxUIFontPresetUnit or "default"
  if not isValidPresetKey(pUI) then pUI = "default" end
  if not isValidPresetKey(pU) then pU = "default" end
  local sUI = _G.FlexxUIDB.flexxUIFontScaleUI
  local sU = _G.FlexxUIDB.flexxUIFontScaleUnit
  applyToBucket(regAll, pUI, sUI)
  applyToBucket(regUnit, pU, sU)
end
