local ADDON_NAME, ns = ...

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")

local function EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if ns.Options and ns.Options.MigrateLegacyOptionKeys then
    ns.Options.MigrateLegacyOptionKeys()
  end
  if ns.UnitFrames and ns.UnitFrames.MigrateLegacyAuraLayout then
    ns.UnitFrames.MigrateLegacyAuraLayout()
  end
  if ns.Debug and ns.Debug.Init then
    ns.Debug.Init()
  end
  ns.DB = ns.DB or {}
  if ns.DB.ApplyDefaults then
    ns.DB.ApplyDefaults(_G.FlexxUIDB, ns.DB.Defaults)
  end
  -- Legacy: combat center used FlexxUILayout.movers; position now lives in FlexxUIDB.combatCenter.anchorX/Y.
  do
    local m = _G.FlexxUILayout and _G.FlexxUILayout.movers and _G.FlexxUILayout.movers.combatCenter
    if m and type(m.x) == "number" and type(m.y) == "number" then
      local cc = _G.FlexxUIDB and _G.FlexxUIDB.combatCenter
      if cc then
        cc.anchorX = m.x
        cc.anchorY = m.y
      end
      if ns.Movers and ns.Movers.ClearSavedPosition then
        ns.Movers.ClearSavedPosition("combatCenter")
      end
    end
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

  if ns.CombatCenter and ns.CombatCenter.Create then
    ns.CombatCenter.Create()
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
