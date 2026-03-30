local ADDON_NAME, ns = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")

local function EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if _G.FlexxUIDB.optionsDevSubTab == nil and _G.FlexxUIDB.optionsDebugSubTab ~= nil then
    _G.FlexxUIDB.optionsDevSubTab = _G.FlexxUIDB.optionsDebugSubTab
  end
  if ns.UnitFrames and ns.UnitFrames.MigrateLegacyAuraLayout then
    ns.UnitFrames.MigrateLegacyAuraLayout()
  end
  ns.DB = ns.DB or {}
  if ns.DB.ApplyDefaults then
    ns.DB.ApplyDefaults(_G.FlexxUIDB, ns.DB.Defaults)
  end
  if ns.Fonts and ns.Fonts.EnsureDB then
    ns.Fonts.EnsureDB()
  end
end

local function BuildUI()
  if ns.UIBuilt then return end
  ns.UIBuilt = true

  if ns.Options and ns.Options.Register then
    ns.Options.Register()
  end

  if ns.Minimap and ns.Minimap.CreateButton then
    ns.Minimap.CreateButton()
  end

  if ns.UnitFrames and ns.UnitFrames.Create then
    ns.UnitFrames.Create()
  end

  if ns.CastBar and ns.CastBar.Create then
    ns.CastBar.Create()
  end

  if ns.Fonts and ns.Fonts.Apply then
    ns.Fonts.Apply()
  end
end

--- Legacy name: open the main options panel (same as /flexxui with no args).
function _G.FlexxUI_Toggle()
  if ns.Options and ns.Options.Open then
    ns.Options.Open()
  end
end

loader:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    EnsureDB()
  elseif event == "PLAYER_LOGIN" then
    EnsureDB()
    BuildUI()
  elseif event == "PLAYER_ENTERING_WORLD" then
    EnsureDB()
    if not ns.UIBuilt then
      BuildUI()
    end
  end
end)
