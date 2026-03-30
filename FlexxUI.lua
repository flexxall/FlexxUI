local ADDON_NAME, ns = ...
ns.name = ADDON_NAME

--- Semver from ## Version in FlexxUI.toc. Retail uses C_AddOns; older clients use GetAddOnMetadata.
local function ReadVersionFromTOC()
  local name = ADDON_NAME
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    local v = C_AddOns.GetAddOnMetadata(name, "Version")
    if v and v ~= "" then return v end
  end
  if GetAddOnMetadata then
    local v = GetAddOnMetadata(name, "Version")
    if v and v ~= "" then return v end
  end
  return nil
end

ns.version = ReadVersionFromTOC() or "dev"
--- Packaged logo; options header, minimap button, etc.
ns.media = {
  logo = "Interface\\AddOns\\FlexxUI\\Media\\FlexxUi.png",
  minimapMini = "Interface\\AddOns\\FlexxUI\\Media\\FlexxUiMini.png",
  --- Health bar threat / aggro overlay (replace strip quads in Style.lua).
  aggroMask = "Interface\\AddOns\\FlexxUI\\Media\\aggroMask.png",
}

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99FlexxUI|r " .. tostring(msg))
end

ns.Print = Print

SLASH_FLEXXUI1 = '/flexxui'
SLASH_FLEXXUI2 = '/flexx'
SlashCmdList['FLEXXUI'] = function(msg)
  msg = (msg or ""):lower()

  if msg == "version" or msg == "ver" then
    local toc = select(4, GetBuildInfo())
    Print("FlexxUI " .. tostring(ns.version) .. (toc and ("  |  Interface " .. tostring(toc)) or ""))
    return
  end

  if msg == "help" or msg == "?" then
    Print("Commands: |cffaaaaaa/flexxui|r — open settings  |  |cffaaaaaaversion|r — version  |  |cffaaaaaareload|r — ReloadUI")
    Print("More: |cffaaaaaareset|r |cffaaaaaaresetlayout|r |cffaaaaaatexture|r |cffaaaaaacolor|r — see README.md")
    return
  end

  if msg == "config" or msg == "settings" or msg == "options" then
    if ns.Options and ns.Options.Open then
      ns.Options.Open()
    else
      Print("Options not loaded yet.")
    end
    return
  end

  if msg == "reload" then
    ReloadUI()
    return
  end

  if msg == "reset" then
    if ns.DB and ns.DB.Reset then
      ns.DB.Reset()
      Print("Settings reset to defaults (layout positions unchanged). Reloading UI...")
      ReloadUI()
    else
      Print("Reset unavailable.")
    end
    return
  end

  if msg == "resetlayout" or msg == "resetpositions" then
    if ns.Movers and ns.Movers.ResetSavedPositions then
      ns.Movers.ResetSavedPositions()
      Print("Saved frame positions cleared. Reloading UI...")
      ReloadUI()
    else
      Print("Layout reset unavailable.")
    end
    return
  end

  if msg:match("^texture%s+") then
    local name = msg:match("^texture%s+(%S+)")
    if not name then
      Print("Usage: /flexxui texture none|default|flat|smooth")
      return
    end
    if ns.UnitFrames and ns.UnitFrames.SetHealthBarTexture and ns.UnitFrames.SetHealthBarTexture(name) then
      Print("Health bar texture set to: " .. name)
    else
      Print("Unknown texture. Use: none, default, flat, smooth")
    end
    return
  end

  if msg:match("^color%s+") then
    local mode = msg:match("^color%s+(%S+)")
    if not mode then
      Print("Usage: /flexxui color class|blizzard|dark")
      return
    end
    if ns.UnitFrames and ns.UnitFrames.SetPlayerHealthColorMode and ns.UnitFrames.SetPlayerHealthColorMode(mode) then
      Print("Player health color mode: " .. mode)
    else
      Print("Unknown mode. Use: class, blizzard, dark")
    end
    return
  end

  if msg == "" then
    if ns.Options and ns.Options.Open then
      ns.Options.Open()
    else
      Print("Options not loaded yet.")
    end
    return
  end

  Print("Unknown command. |cffaaaaaa/flexxui help|r")
end
