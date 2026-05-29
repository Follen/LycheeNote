local ADDON_NAME, ns = ...

local Inspect = {}
ns.RememberNoobInspect = Inspect

local inspectCache = {}
local pendingInspects = {}
local lastInspectTime = 0
local INSPECT_COOLDOWN = 1
local inspectFrame = CreateFrame("Frame")

local function CacheResult(cleanName, result)
  if cleanName and result then
    inspectCache[cleanName] = {result = result, timestamp = GetTime()}
  end
end

local function BuildClassSpecResult(localizedClass, specName)
  if localizedClass and specName and specName ~= "" then
    return localizedClass .. "-" .. specName
  end
end

local function EscapePattern(text)
  return text and text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function GetSpecFromTooltipLine(text, localizedClass)
  if not text or not localizedClass then return nil end
  if not text:find(localizedClass, 1, true) then return nil end
  if text:find(LEVEL, 1, true) then return nil end
  if tonumber(text:match("^%s*(%d+)")) then return nil end

  local beforeClass = text:match("^(.-)%s*" .. EscapePattern(localizedClass))
  if not beforeClass then return nil end
  beforeClass = beforeClass:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):trim()
  if beforeClass == "" or beforeClass == localizedClass then return nil end

  local specName = beforeClass:match("([^%s]+)$")
  if not specName or specName == localizedClass then return nil end
  return specName
end

local function GetTooltipClassSpec(unit, localizedClass)
  if not C_TooltipInfo or not C_TooltipInfo.GetUnit then return nil end

  local data = C_TooltipInfo.GetUnit(unit)
  if not data or not data.lines then return nil end

  for _, lineData in ipairs(data.lines) do
    local specName = GetSpecFromTooltipLine(lineData.leftText, localizedClass)
    local result = BuildClassSpecResult(localizedClass, specName)
    if result then return result end
  end
end

function Inspect.OnInspectReady(inspectedGUID)
  if not inspectedGUID then return end
  local targetUnit, unitName = nil, nil

  if UnitExists("target") and UnitGUID("target") == inspectedGUID then
    targetUnit, unitName = "target", UnitName("target")
  end
  if not targetUnit and UnitExists("mouseover") and UnitGUID("mouseover") == inspectedGUID then
    targetUnit, unitName = "mouseover", UnitName("mouseover")
  end
  if not targetUnit then
    for i = 1, GetNumGroupMembers() do
      local unit = IsInRaid() and ("raid" .. i) or ((i == 1) and "player" or ("party" .. (i - 1)))
      if UnitExists(unit) and UnitGUID(unit) == inspectedGUID then
        targetUnit, unitName = unit, UnitName(unit)
        break
      end
    end
  end
  if not targetUnit or not unitName then return end

  local localizedClass = UnitClass(targetUnit)
  local specID = GetInspectSpecialization(targetUnit)
  local specName = "未知专精"
  if specID and specID > 0 then
    local _, name = GetSpecializationInfoByID(specID)
    specName = name or "未知专精"
  end
  local result = localizedClass .. "-" .. specName

  local cleanName = unitName:gsub("%-.*", "")
  CacheResult(cleanName, result)

  if pendingInspects[cleanName] then
    for _, pendingData in ipairs(pendingInspects[cleanName]) do
      if pendingData and pendingData.callback then
        C_Timer.After(0, function() pendingData.callback(result) end)
      end
    end
    pendingInspects[cleanName] = nil
  end

  local hasPending = false
  for _ in pairs(pendingInspects) do hasPending = true; break end
  if not hasPending then inspectFrame:UnregisterEvent("INSPECT_READY") end
end

function Inspect.GetTargetClassSpec(unit, callback)
  if not unit or not UnitExists(unit) then
    if callback then callback(nil) end
    return nil
  end

  local localizedClass = UnitClass(unit)
  if not localizedClass then
    if callback then callback(nil) end
    return nil
  end

  local unitName = UnitName(unit)
  local cleanName = unitName and unitName:gsub("%-.*", "")

  -- Self: always know our own spec
  if UnitIsUnit(unit, "player") then
    local specID = GetSpecialization()
    if specID and specID > 0 then
      local _, specName = GetSpecializationInfo(specID)
      local result = localizedClass .. "-" .. (specName or "未知专精")
      CacheResult(cleanName, result)
      if callback then callback(result) end
      return result
    end
    local result = localizedClass .. "-未知专精"
    if callback then callback(result) end
    return result
  end

  -- Group members often have spec info immediately, but not always.
  -- If it is missing, fall through to the normal inspect request path.
  if UnitInParty(unit) or UnitInRaid(unit) then
    local specID = GetInspectSpecialization(unit)
    if specID and specID > 0 then
      local _, specName = GetSpecializationInfoByID(specID)
      if specName then
        local result = localizedClass .. "-" .. specName
        CacheResult(cleanName, result)
        if callback then callback(result) end
        return result
      end
    end
  end

  -- Check cache (5-min TTL)
  if cleanName and inspectCache[cleanName] then
    local cached = inspectCache[cleanName]
    if cached.timestamp and (GetTime() - cached.timestamp < 300) then
      if callback then callback(cached.result) end
      return cached.result
    end
    inspectCache[cleanName] = nil
  end

  -- Try existing spec without requesting new inspect
  local directSpecID = GetInspectSpecialization(unit)
  if directSpecID and directSpecID > 0 then
    local _, specName = GetSpecializationInfoByID(directSpecID)
    if specName then
      local result = localizedClass .. "-" .. specName
      CacheResult(cleanName, result)
      if callback then callback(result) end
      return result
    end
  end

  local tooltipResult = GetTooltipClassSpec(unit, localizedClass)
  if tooltipResult then
    CacheResult(cleanName, tooltipResult)
    if callback then callback(tooltipResult) end
    return tooltipResult
  end

  -- Request inspection
  if CanInspect(unit) then
    local currentTime = GetTime()
    if currentTime - lastInspectTime < INSPECT_COOLDOWN then
      C_Timer.After(INSPECT_COOLDOWN - (currentTime - lastInspectTime) + 0.1, function()
        Inspect.GetTargetClassSpec(unit, callback)
      end)
      if callback then callback(localizedClass .. "-检视中") end
      return localizedClass .. "-检视中"
    end
    lastInspectTime = currentTime

    if callback then
      if not pendingInspects[cleanName] then pendingInspects[cleanName] = {} end
      table.insert(pendingInspects[cleanName], {callback = callback, timestamp = currentTime})
      C_Timer.After(5, function()
        if pendingInspects[cleanName] then
          for i, pending in ipairs(pendingInspects[cleanName]) do
            if pending.callback == callback then
              pending.callback(localizedClass .. "-检视超时")
              table.remove(pendingInspects[cleanName], i)
              break
            end
          end
          if #pendingInspects[cleanName] == 0 then pendingInspects[cleanName] = nil end
        end
      end)
    end

    inspectFrame:RegisterEvent("INSPECT_READY")
    inspectFrame:SetScript("OnEvent", function(self, event, inspectedGUID)
      if event == "INSPECT_READY" then Inspect.OnInspectReady(inspectedGUID) end
    end)
    NotifyInspect(unit)

    if callback then callback(localizedClass .. "-检视中") end
    return localizedClass .. "-检视中"
  end

  -- Can't inspect — just return class
  local result = localizedClass .. "-无法检视"
  if callback then callback(result) end
  return result
end

function Inspect.GetCachedClassSpec(unitName)
  local cleanName = unitName and unitName:gsub("%-.*", "")
  local cached = cleanName and inspectCache[cleanName]
  if cached and cached.result then return cached.result end
  return nil
end

function Inspect.ClearCache()
  inspectCache = {}
  pendingInspects = {}
end
