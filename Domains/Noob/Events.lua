local ADDON_NAME, ns = ...

local Events = {}
ns.RememberNoobEvents = Events

local lastCheckTime = 0
local lastCheckHash = ""

function Events.CheckPartyMembers()
  C_Timer.After(0.5, function()
    local groupSize = GetNumGroupMembers()
    if groupSize <= 1 then return end

    local currentTime = GetTime()
    if currentTime - lastCheckTime < 2 then return end
    lastCheckTime = currentTime

    local foundNoobs = {}
    local checkHash = ""

    for i = 1, groupSize do
      local unit = IsInRaid() and ("raid" .. i) or ((i == 1) and "player" or ("party" .. (i - 1)))
      local name, server = UnitName(unit)
      if name and name ~= UnitName("player") then
        local cleanName = name:gsub("%-.*", "")
        if ns.RememberNoobNoob and ns.RememberNoobNoob.IsNoob(cleanName) then
          local db = ns.db
          local noobData = db.noobs[cleanName]
          local serverName = server or GetRealmName()
          table.insert(foundNoobs, {
            name = cleanName,
            server = serverName,
            reason = noobData.reason or "无理由"
          })
          checkHash = checkHash .. cleanName .. serverName
        end
      end
    end

    if checkHash == lastCheckHash then return end
    lastCheckHash = checkHash

    if #foundNoobs > 0 then
      for _, noobInfo in ipairs(foundNoobs) do
        print("|cffff0000RememberNoob: 队伍中有已标记的笨蛋 [" .. noobInfo.name .. "] - " .. noobInfo.reason .. "|r")
      end
    end
  end)
end
