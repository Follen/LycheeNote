local ADDON_NAME, ns = ...

ns.addonName = ADDON_NAME
ns.events = ns.events or CreateFrame("Frame", "RememberNoobEventFrame")
ns.modules = ns.modules or {}

if not ns.SafeCall then
  function ns.SafeCall(label, fn, ...)
    if type(fn) ~= "function" then return true end
    local ok, err = pcall(fn, ...)
    if not ok then
      print("|cffff3333[RememberNoob]|r " .. tostring(label) .. ": " .. tostring(err))
      return false
    end
    return true
  end
end

if not ns.RegisterModule then
  function ns.RegisterModule(name, module)
    ns.modules[name] = module
  end
end

local function Dispatch(event, ...)
  for name, module in pairs(ns.modules) do
    local handler = module and module[event]
    if handler then
      ns.SafeCall(name .. "." .. event, handler, module, ...)
    end
  end
end

ns.events:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    local loadedName = ...
    if loadedName ~= ADDON_NAME then return end
    ns.events:UnregisterEvent("ADDON_LOADED")

    if ns.Config and ns.Config.Initialize then
      ns.Config.Initialize()
    end

    Dispatch("OnInitialize")

    SLASH_REMEMBERNOOB1 = "/noob"
    SlashCmdList["REMEMBERNOOB"] = function(msg)
      msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if msg == "debug" then
        if ns.RememberNoobUI and ns.RememberNoobUI.ToggleDebugPanel then
          ns.RememberNoobUI.ToggleDebugPanel()
        end
        return
      end
      if ns.RememberNoobUI and ns.RememberNoobUI.ShowManagementUI then
        ns.RememberNoobUI.ShowManagementUI()
      end
    end

    SLASH_RNADD1 = "/rnadd"
    SlashCmdList["RNADD"] = function(msg)
      if UnitExists("target") and UnitIsPlayer("target") then
        local name = GetUnitName("target", false)
        if msg and msg ~= "" then
          if ns.RememberNoobNoob then
            ns.RememberNoobNoob.AddNoobMark(name, msg)
          end
        else
          if ns.RememberNoobNoob then
            ns.RememberNoobNoob.MarkAsNoob(name)
          end
        end
      else
        print("|cffff0000RememberNoob: 没有选中有效的玩家目标|r")
      end
    end

    ns.events:RegisterEvent("GROUP_ROSTER_UPDATE")
    return
  end

  if event == "GROUP_ROSTER_UPDATE" then
    if ns.RememberNoobEvents and ns.RememberNoobEvents.CheckPartyMembers then
      ns.RememberNoobEvents.CheckPartyMembers()
    end
    return
  end

  Dispatch(event, ...)
end)

ns.events:RegisterEvent("ADDON_LOADED")
