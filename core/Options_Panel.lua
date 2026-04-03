local _, ns = ...
local O = ns.Options

function O.Create()
  if O.state.panel then return O.state.panel end
  O.EnsureDB()

  local panel = CreateFrame("Frame", "FlexxUI_Options", UIParent, "BackdropTemplate")
  O.state.panel = panel
  panel:SetSize(960, 680)
  panel:SetPoint("CENTER", UIParent, "CENTER", 10, 0)
  panel:SetFrameStrata("DIALOG")
  panel:SetClampedToScreen(true)
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:RegisterForDrag("LeftButton")
  -- Lock state applies to unit frames / movers only, not this panel.
  local function PanelDragStart(self)
    pcall(function() self:StartMoving() end)
  end
  local function PanelDragStop(self)
    pcall(function() self:StopMovingOrSizing() end)
  end
  panel:SetScript("OnDragStart", PanelDragStart)
  panel:SetScript("OnDragStop", PanelDragStop)
  panel:SetResizable(true)
  if panel.SetResizeBounds then panel:SetResizeBounds(860, 520, 1300, 980) end
  O.StyleSurface(panel, 0.97)
  local function BringPanelToFront(self)
    if self.SetFrameStrata then self:SetFrameStrata("FULLSCREEN_DIALOG") end
    if self.Raise then pcall(function() self:Raise() end) end
    if self.GetFrameLevel and self.SetFrameLevel then
      local lvl = self:GetFrameLevel() or 0
      self:SetFrameLevel(lvl + 40)
    end
    local dbg = ns.Debug and ns.Debug.state and ns.Debug.state.monitorFrame
    if dbg and dbg.SetFrameStrata then
      dbg:SetFrameStrata("DIALOG")
    end
  end
  panel:HookScript("OnMouseDown", BringPanelToFront)

  local header = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  header:SetPoint("TOPLEFT", 10, -10)
  header:SetPoint("TOPRIGHT", -10, -10)
  header:SetHeight(92)
  O.StyleSurface(header, 0.30)
  if header.HookScript then
    header:HookScript("OnMouseDown", function() BringPanelToFront(panel) end)
  end
  -- Shells/scroll areas cover the panel; drag must register on the header (title strip) so StartMoving runs.
  header:SetMovable(false)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function()
    BringPanelToFront(panel)
    PanelDragStart(panel)
  end)
  header:SetScript("OnDragStop", function()
    PanelDragStop(panel)
  end)

  local addonVersion = ns.version or "dev"
  local logoPath = (ns.media and ns.media.logo) or "Interface\\AddOns\\FlexxUI\\Media\\FlexxUi.png"
  local logo = header:CreateTexture(nil, "ARTWORK")
  logo:SetSize(80, 80)
  logo:SetPoint("LEFT", 4, 0)
  logo:SetTexture(logoPath)

  local title = (ns.Fonts and ns.Fonts.CreateFontString(header, "ARTWORK", "GameFontNormalLarge", "all")) or header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("LEFT", logo, "RIGHT", 10, 8)
  title:SetText("FlexxUI")
  local version = (ns.Fonts and ns.Fonts.CreateFontString(header, "ARTWORK", "GameFontHighlightSmall", "all")) or header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  version:SetPoint("LEFT", title, "RIGHT", 10, -1)
  version:SetText("v" .. tostring(addonVersion))
  local subtitle = (ns.Fonts and ns.Fonts.CreateFontString(header, "ARTWORK", "GameFontHighlightSmall", "all")) or header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  subtitle:SetText("Settings")

  -- Declare first: Lua 5.1 does not scope `lockBtn` inside the OnClick closure when it's the same assignment line.
  local lockBtn
  lockBtn = O.MakeFlatButton(header, "Lock", 72, 22, function()
    O.EnsureDB()
    _G.FlexxUIDB.locked = not _G.FlexxUIDB.locked
    if lockBtn and lockBtn.Label then
      lockBtn.Label:SetText(_G.FlexxUIDB.locked and "Unlock" or "Lock")
    end
  end)
  local reloadHdrBtn = O.MakeFlatButton(header, "Reload UI", 100, 22, function() ReloadUI() end)
  local close = O.MakeFlatButton(header, "X", 26, 22, function() panel:Hide() end)
  close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -8, -8)
  reloadHdrBtn:SetPoint("RIGHT", close, "LEFT", -8, 0)
  lockBtn:SetPoint("RIGHT", reloadHdrBtn, "LEFT", -8, 0)

  local sizer = O.MakeFlatButton(panel, "///", 26, 20, nil)
  sizer:SetPoint("BOTTOMRIGHT", -8, 8)
  sizer:SetScript("OnMouseDown", function() panel:StartSizing("BOTTOMRIGHT") end)
  sizer:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)

  local tabGeneral = O.MakeTabButton(panel, "General", "general")
  tabGeneral:ClearAllPoints()
  tabGeneral:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 10, -10)
  local tabUnit = O.MakeTabButton(panel, "Unit Frames", "unit", tabGeneral)
  local tabCombat = O.MakeTabButton(panel, "Combat", "combat", tabUnit)
  O.MakeTabButton(panel, "Dev Settings", "dev", tabCombat)

  local pageBRX, pageBRY = -8, 36
  -- General: same shell + left nav + body as Unit Frames (Player / Target / Pet).
  local generalShell = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  O.StyleSurface(generalShell, 0.35)
  generalShell:SetBackdropBorderColor(0, 0, 0, 0)
  generalShell:SetPoint("TOPLEFT", tabGeneral, "BOTTOMLEFT", 0, -16)
  generalShell:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", pageBRX, pageBRY)

  local generalNav = CreateFrame("Frame", nil, generalShell)
  generalNav:SetPoint("TOPLEFT", 0, 0)
  generalNav:SetPoint("BOTTOMLEFT", 0, 0)
  generalNav:SetWidth(O.chromeButtonSize.w)

  local btnGeneralSettings = O.MakeGeneralNavButton(generalNav, "Settings", "settings")
  btnGeneralSettings:SetPoint("TOPLEFT", 0, 0)
  local btnGeneralFonts = O.MakeGeneralNavButton(generalNav, "Fonts", "fonts")
  btnGeneralFonts:SetPoint("TOPLEFT", btnGeneralSettings, "BOTTOMLEFT", 0, -8)

  local generalBody = CreateFrame("Frame", nil, generalShell, "BackdropTemplate")
  -- Nav (132) + 8px gap lines inner panel left edge with "Unit Frames" tab (tabGeneral + 132 + 8).
  local generalNavGap = 8
  generalBody:SetPoint("TOPLEFT", generalShell, "TOPLEFT", O.chromeButtonSize.w + generalNavGap, 0)
  generalBody:SetPoint("BOTTOMRIGHT", 0, 0)
  O.StyleSurface(generalBody, 0.22)
  generalBody:SetBackdropBorderColor(0, 0, 0, 0)

  local generalHolder = O.CreateScrollablePage(generalBody, true)
  generalHolder:SetAllPoints()
  O.state.pages.general = generalHolder.content
  O.state.pageHolders.general = generalShell
  generalShell.RefreshScroll = function()
    if generalHolder and generalHolder.RefreshScroll then
      generalHolder:RefreshScroll()
    end
  end

  local unitShell = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  O.StyleSurface(unitShell, 0.35)
  unitShell:SetBackdropBorderColor(0, 0, 0, 0)
  unitShell:SetPoint("TOPLEFT", tabGeneral, "BOTTOMLEFT", 0, -16)
  unitShell:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", pageBRX, pageBRY)
  O.state.pageHolders.unit = unitShell

  local unitNav = CreateFrame("Frame", nil, unitShell)
  unitNav:SetPoint("TOPLEFT", 0, 0)
  unitNav:SetPoint("BOTTOMLEFT", 0, 0)
  unitNav:SetWidth(O.chromeButtonSize.w)

  local btnPlayer = O.MakeUnitNavButton(unitNav, "Player", "player")
  btnPlayer:SetPoint("TOPLEFT", 0, 0)
  local btnTarget = O.MakeUnitNavButton(unitNav, "Target", "target")
  btnTarget:SetPoint("TOPLEFT", btnPlayer, "BOTTOMLEFT", 0, -8)
  local btnPet = O.MakeUnitNavButton(unitNav, "Pet", "pet")
  btnPet:SetPoint("TOPLEFT", btnTarget, "BOTTOMLEFT", 0, -8)

  -- Right column: one panel backdrop on unitBody; scroll holders are transparent (no double wrapper).
  local unitBody = CreateFrame("Frame", nil, unitShell, "BackdropTemplate")
  local navGap = 8
  unitBody:SetPoint("TOPLEFT", unitShell, "TOPLEFT", O.chromeButtonSize.w + navGap, 0)
  unitBody:SetPoint("BOTTOMRIGHT", 0, 0)
  O.StyleSurface(unitBody, 0.22)
  unitBody:SetBackdropBorderColor(0, 0, 0, 0)

  local unitPlayerHolder = O.CreateScrollablePage(unitBody, true)
  unitPlayerHolder:SetAllPoints()
  O.state.pages.unitPlayer = unitPlayerHolder.content
  O.state.unitFrameHolders.player = unitPlayerHolder

  local unitTargetHolder = O.CreateScrollablePage(unitBody, true)
  unitTargetHolder:SetAllPoints()
  unitTargetHolder:Hide()
  O.state.pages.unitTarget = unitTargetHolder.content
  O.state.unitFrameHolders.target = unitTargetHolder

  local unitPetHolder = O.CreateScrollablePage(unitBody, true)
  unitPetHolder:SetAllPoints()
  unitPetHolder:Hide()
  O.state.pages.unitPet = unitPetHolder.content
  O.state.unitFrameHolders.pet = unitPetHolder

  local devShell = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  O.StyleSurface(devShell, 0.35)
  devShell:SetBackdropBorderColor(0, 0, 0, 0)
  devShell:SetPoint("TOPLEFT", tabGeneral, "BOTTOMLEFT", 0, -16)
  devShell:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", pageBRX, pageBRY)
  O.state.pageHolders.dev = devShell

  local devNav = CreateFrame("Frame", nil, devShell)
  devNav:SetPoint("TOPLEFT", 0, 0)
  devNav:SetPoint("BOTTOMLEFT", 0, 0)
  devNav:SetWidth(O.chromeButtonSize.w)
  local btnDevCast = O.MakeDevNavButton(devNav, "Cast bars", "cast")
  O.MakeDevNavButton(devNav, "Auras", "auras", btnDevCast)

  local devBody = CreateFrame("Frame", nil, devShell, "BackdropTemplate")
  devBody:SetPoint("TOPLEFT", devShell, "TOPLEFT", O.chromeButtonSize.w + 8, 0)
  devBody:SetPoint("BOTTOMRIGHT", 0, 0)
  O.StyleSurface(devBody, 0.22)
  devBody:SetBackdropBorderColor(0, 0, 0, 0)

  local devCastHolder = O.CreateScrollablePage(devBody, true)
  devCastHolder:SetAllPoints()
  O.state.pages.devCast = devCastHolder.content

  local devAurasHolder = O.CreateScrollablePage(devBody, true)
  devAurasHolder:SetAllPoints()
  devAurasHolder:Hide()
  O.state.pages.devAuras = devAurasHolder.content

  devShell.RefreshScroll = function()
    if devCastHolder and devCastHolder.RefreshScroll then
      devCastHolder:RefreshScroll()
    end
    if devAurasHolder and devAurasHolder.RefreshScroll then
      devAurasHolder:RefreshScroll()
    end
  end

  local combatShell = CreateFrame("Frame", nil, panel, "BackdropTemplate")
  O.StyleSurface(combatShell, 0.35)
  combatShell:SetBackdropBorderColor(0, 0, 0, 0)
  combatShell:SetPoint("TOPLEFT", tabGeneral, "BOTTOMLEFT", 0, -16)
  combatShell:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", pageBRX, pageBRY)
  O.state.pageHolders.combat = combatShell

  local combatNav = CreateFrame("Frame", nil, combatShell)
  combatNav:SetPoint("TOPLEFT", 0, 0)
  combatNav:SetPoint("BOTTOMLEFT", 0, 0)
  combatNav:SetWidth(O.chromeButtonSize.w)
  local btnCombatOverview = O.MakeCombatNavButton(combatNav, "Overview", "overview")
  local btnCombatDisplay = O.MakeCombatNavButton(combatNav, "Display", "display", btnCombatOverview)
  O.MakeCombatNavButton(combatNav, "Tracking", "tracking", btnCombatDisplay)

  local combatBody = CreateFrame("Frame", nil, combatShell, "BackdropTemplate")
  combatBody:SetPoint("TOPLEFT", combatShell, "TOPLEFT", O.chromeButtonSize.w + 8, 0)
  combatBody:SetPoint("BOTTOMRIGHT", 0, 0)
  O.StyleSurface(combatBody, 0.22)
  combatBody:SetBackdropBorderColor(0, 0, 0, 0)

  local combatOverviewHolder = O.CreateScrollablePage(combatBody, true)
  combatOverviewHolder:SetAllPoints()
  O.state.pages.combatOverview = combatOverviewHolder.content

  local combatDisplayHolder = O.CreateScrollablePage(combatBody, true)
  combatDisplayHolder:SetAllPoints()
  combatDisplayHolder:Hide()
  O.state.pages.combatDisplay = combatDisplayHolder.content

  local combatTrackingHolder = O.CreateScrollablePage(combatBody, true)
  combatTrackingHolder:SetAllPoints()
  combatTrackingHolder:Hide()
  O.state.pages.combatTracking = combatTrackingHolder.content
  combatShell.RefreshScroll = function()
    if combatOverviewHolder and combatOverviewHolder.RefreshScroll then
      combatOverviewHolder:RefreshScroll()
    end
    if combatDisplayHolder and combatDisplayHolder.RefreshScroll then
      combatDisplayHolder:RefreshScroll()
    end
    if combatTrackingHolder and combatTrackingHolder.RefreshScroll then
      combatTrackingHolder:RefreshScroll()
    end
  end

  O.BuildGeneralPage(O.state.pages.general)
  O.BuildUnitPlayerPage(O.state.pages.unitPlayer)
  O.BuildUnitTargetPage(O.state.pages.unitTarget)
  O.BuildUnitPetPage(O.state.pages.unitPet)
  O.BuildCombatPage(O.state.pages.combatOverview, "overview")
  O.BuildCombatPage(O.state.pages.combatDisplay, "display")
  O.BuildCombatPage(O.state.pages.combatTracking, "tracking")
  O.BuildDevPage(O.state.pages.devCast, "cast")
  O.BuildDevPage(O.state.pages.devAuras, "auras")

  O.state.applyDevSubTab = function()
    O.EnsureDB()
    local key = (_G.FlexxUIDB and _G.FlexxUIDB.optionsDevSubTab) or "cast"
    if key ~= "cast" and key ~= "auras" then key = "cast" end
    devCastHolder:SetShown(key == "cast")
    devAurasHolder:SetShown(key == "auras")
  end
  O.state.applyCombatSubTab = function()
    O.EnsureDB()
    local key = (_G.FlexxUIDB and _G.FlexxUIDB.optionsCombatSubTab) or "overview"
    if key ~= "overview" and key ~= "display" and key ~= "tracking" then key = "overview" end
    combatOverviewHolder:SetShown(key == "overview")
    combatDisplayHolder:SetShown(key == "display")
    combatTrackingHolder:SetShown(key == "tracking")
  end
  O.state.applyDevSubTab()
  O.state.applyCombatSubTab()

  local top = panel:GetFrameLevel()
  close:SetFrameLevel(top + 50)
  reloadHdrBtn:SetFrameLevel(top + 50)
  lockBtn:SetFrameLevel(top + 50)
  sizer:SetFrameLevel(top + 50)

  panel:SetScript("OnShow", function()
    BringPanelToFront(panel)
    O.EnsureDB()
    _G.FlexxUIDB.optionsGeneralSubTab = "settings"
    if lockBtn.Label then
      lockBtn.Label:SetText(_G.FlexxUIDB.locked and "Unlock" or "Lock")
    end
    O.RefreshControls()
    O.SelectTab("general")
  end)

  local function HookBring(frame)
    if not frame or not frame.HookScript then return end
    pcall(function()
      frame:HookScript("OnMouseDown", function() BringPanelToFront(panel) end)
    end)
  end
  for _, fr in ipairs({ generalShell, generalBody, unitShell, unitBody, devShell, devBody, combatShell, combatBody }) do
    HookBring(fr)
  end

  panel:EnableMouseWheel(true)
  panel:SetScript("OnMouseWheel", function(self, delta)
    if not IsControlKeyDown() then return end
    local scale = self:GetScale()
    if delta > 0 then scale = math.min(1.4, scale + 0.05) else scale = math.max(0.8, scale - 0.05) end
    self:SetScale(scale)
  end)

  O.SelectTab("general")
  panel:Hide()
  return panel
end

function O.Open()
  local panel = O.state.panel or O.Create()
  if panel:IsShown() then panel:Hide() else panel:Show() end
end

function O.Register()
  O.Create()
end

