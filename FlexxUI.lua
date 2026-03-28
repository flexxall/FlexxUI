local ADDON_NAME, ns = ...
ns.name = ADDON_NAME
--- Semver from ## Version in FlexxUI.toc (GetAddOnMetadata).
ns.version = (GetAddOnMetadata and GetAddOnMetadata(ADDON_NAME, "Version")) or "dev"
--- Packaged logo; use for options header, shell, etc.
ns.media = {
  logo = "Interface\\AddOns\\FlexxUI\\Media\\FlexxUi.png",
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
    Print("Commands: |cffaaaaaa/flexxui|r — toggle shell  |  |cffaaaaaaconfig|r — options  |  |cffaaaaaaversion|r — version  |  |cffaaaaaalog|r — log  |  |cffaaaaaareload|r — ReloadUI")
    Print("More: |cffaaaaaareset|r |cffaaaaaaresetlayout|r |cffaaaaaacastpreview|r |cffaaaaaatexture|r |cffaaaaaacolor|r — see README.md")
    return
  end

  if msg == "log" then
    if ns.OutputLog and ns.OutputLog.Toggle then
      ns.OutputLog.Toggle()
    else
      Print("Log window not loaded yet.")
    end
    return
  end

  if msg == "logdiag" or msg == "diag" then
    if _G.FlexxUI_LogDiag then
      _G.FlexxUI_LogDiag("slash", "manual")
    elseif _G.FlexxUI_Log then
      _G.FlexxUI_Log("[logdiag/slash] manual")
    else
      Print("Log diagnostics unavailable.")
    end
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

  if msg == "castpreview" or msg == "castbarpreview" then
    if ns.CastBar and ns.CastBar.ToggleLayoutPreview then
      local on = ns.CastBar.ToggleLayoutPreview()
      Print("Cast bar layout preview: " .. (on and "on" or "off") .. "  (|cffaaaaaa/flexxui castpreview|r to toggle)")
    else
      Print("Cast bar not loaded yet.")
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

  if _G.FlexxUI_Toggle then
    _G.FlexxUI_Toggle()
  else
    Print("UI is not loaded yet.")
  end
end
