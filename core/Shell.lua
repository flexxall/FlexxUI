local _, ns = ...

ns.Shell = ns.Shell or {}

local shell

local function EnsureDB()
  _G.FlexxUIDB = _G.FlexxUIDB or {}
  if _G.FlexxUIDB.enabled == nil then _G.FlexxUIDB.enabled = true end
  if _G.FlexxUIDB.locked == nil then _G.FlexxUIDB.locked = false end
end

local function MakeButton(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetText(text)
  b:SetHeight(18)
  b:SetWidth(90)
  b:SetScript("OnClick", onClick)
  return b
end

local function UpdateLockButton()
  if not shell or not shell.lockBtn then return end
  if _G.FlexxUIDB.locked then
    shell.lockBtn:SetText("Unlock")
  else
    shell.lockBtn:SetText("Lock")
  end
end

function ns.Shell.Create()
  if shell then return shell end
  EnsureDB()

  shell = CreateFrame("Frame", "FlexxUI_Shell", UIParent, "BackdropTemplate")
  shell:SetSize(520, 80)
  shell:SetPoint("TOP", UIParent, "TOP", 0, -40)
  shell:SetFrameStrata("DIALOG")

  shell:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  shell:SetBackdropColor(0, 0, 0, 0.65)

  local logoPath = (ns.media and ns.media.logo) or "Interface\\AddOns\\FlexxUI\\Media\\FlexxUi.png"
  shell.logo = shell:CreateTexture(nil, "OVERLAY")
  shell.logo:SetSize(28, 28)
  shell.logo:SetPoint("TOPLEFT", 10, -8)
  shell.logo:SetTexture(logoPath)

  shell.title = (ns.Fonts and ns.Fonts.CreateFontString(shell, "OVERLAY", "GameFontNormal", "all")) or shell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  shell.title:SetPoint("TOPLEFT", shell.logo, "TOPRIGHT", 8, -2)
  shell.title:SetText("FlexxUI")

  shell.sub = (ns.Fonts and ns.Fonts.CreateFontString(shell, "OVERLAY", "GameFontHighlightSmall", "all")) or shell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  shell.sub:SetPoint("TOPLEFT", shell.title, "BOTTOMLEFT", 0, -2)
  shell.sub:SetText("Drag frames when unlocked. /flexxui toggles this panel.")

  shell.lockBtn = MakeButton(shell, "Lock", function()
    EnsureDB()
    _G.FlexxUIDB.locked = not _G.FlexxUIDB.locked
    UpdateLockButton()
  end)
  shell.lockBtn:SetPoint("BOTTOMLEFT", 12, 10)

  shell.optionsBtn = MakeButton(shell, "Settings", function()
    if ns.Options and ns.Options.Open then
      ns.Options.Open()
    end
  end)
  shell.optionsBtn:SetPoint("LEFT", shell.lockBtn, "RIGHT", 8, 0)

  shell.hideBtn = MakeButton(shell, "Hide", function()
    shell:Hide()
  end)
  shell.hideBtn:SetPoint("LEFT", shell.optionsBtn, "RIGHT", 8, 0)

  shell.logBtn = MakeButton(shell, "Log", function()
    if ns.OutputLog and ns.OutputLog.Toggle then
      ns.OutputLog.Toggle()
    end
  end)
  shell.logBtn:SetPoint("LEFT", shell.hideBtn, "RIGHT", 8, 0)

  shell.reloadBtn = MakeButton(shell, "Reload UI", function()
    ReloadUI()
  end)
  shell.reloadBtn:SetPoint("LEFT", shell.logBtn, "RIGHT", 8, 0)

  if ns.Movers and ns.Movers.MakeMovable then
    ns.Movers.MakeMovable("shell", shell, { "TOP", UIParent, "TOP", 0, -40 })
  end

  UpdateLockButton()

  if not _G.FlexxUIDB.enabled then
    shell:Hide()
  end

  return shell
end

function ns.Shell.Toggle()
  EnsureDB()
  if not shell then ns.Shell.Create() end

  if shell:IsShown() then
    shell:Hide()
    _G.FlexxUIDB.enabled = false
  else
    shell:Show()
    _G.FlexxUIDB.enabled = true
  end
end

function ns.Shell.Get()
  return shell
end

