--- 职业专精侦测
-- 按“自身 → 队伍 → 缓存 → 直接读取 → 提示框 → 主动检视”顺序求值，任一步成功即返回。
-- 缓存有界（128 条、5 分钟 TTL），失败路径不写缓存。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Inspect = {}
LN.Inspect = Inspect

local CACHE_LIMIT = 128
local CACHE_TTL = 300
local INSPECT_COOLDOWN = 1
local INSPECT_TIMEOUT = 5

local cache = {}
local cacheOrder = {}
local cacheSize = 0
local pending = {}
local lastInspectTime = 0
local eventFrame

local function CacheResult(cleanName, result)
  if type(cleanName) ~= "string" or cleanName == "" or type(result) ~= "string" then return end
  if not cache[cleanName] then
    cacheOrder[#cacheOrder + 1] = cleanName
    cacheSize = cacheSize + 1
  end
  cache[cleanName] = { result = result, timestamp = GetTime() }
  while cacheSize > CACHE_LIMIT do
    local oldest = table.remove(cacheOrder, 1)
    if oldest then
      cache[oldest] = nil
      cacheSize = cacheSize - 1
    end
  end
end

local function CacheGet(cleanName)
  local entry = cleanName and cache[cleanName]
  if not entry then return nil end
  if GetTime() - entry.timestamp >= CACHE_TTL then
    cache[cleanName] = nil
    return nil
  end
  return entry.result
end

local function SafeCall(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
end

local function GetInspectSpecialization(unit)
  if not C_SpecializationInfo then return nil end
  local specID = SafeCall(C_SpecializationInfo.GetInspectSpecialization, unit)
  return type(specID) == "number" and specID or nil
end

local function GetSpecializationNameByID(specID)
  if type(GetSpecializationInfoByID) ~= "function" then return nil end
  local _, _, name = SafeCall(GetSpecializationInfoByID, specID)
  return type(name) == "string" and name or nil
end

local function GetSpecializationName(specID)
  if not C_SpecializationInfo or type(C_SpecializationInfo.GetSpecializationInfo) ~= "function" then
    return nil
  end
  local _, _, name = SafeCall(C_SpecializationInfo.GetSpecializationInfo, specID)
  return type(name) == "string" and name or nil
end

local function Compose(localizedClass, specName)
  if localizedClass and specName and specName ~= "" then
    return localizedClass .. "-" .. specName
  end
end

local function EscapePattern(text)
  return text and text:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") or text
end

--- 提示框兜底：等级行和纯数字行不是专精。
local function SpecFromTooltipLine(text, localizedClass)
  if type(text) ~= "string" or not localizedClass then return nil end
  if not text:find(localizedClass, 1, true) then return nil end
  if text:find(LEVEL, 1, true) then return nil end
  if tonumber(text:match("^%s*(%d+)")) then return nil end

  local before = text:match("^(.-)%s*" .. EscapePattern(localizedClass))
  if not before then return nil end
  before = LN.Trim(before:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  if before == "" or before == localizedClass then return nil end

  local specName = before:match("([^%s]+)$")
  if not specName or specName == localizedClass then return nil end
  return specName
end

local function SpecFromTooltip(unit, localizedClass)
  if not C_TooltipInfo or type(C_TooltipInfo.GetUnit) ~= "function" then return nil end
  local data = SafeCall(C_TooltipInfo.GetUnit, unit)
  if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  for _, line in ipairs(data.lines) do
    local result = Compose(localizedClass, SpecFromTooltipLine(line.leftText, localizedClass))
    if result then return result end
  end
end

local function ResolveUnit(inspectedGUID)
  if UnitExists("target") and UnitGUID("target") == inspectedGUID then
    return "target", UnitName("target")
  end
  if UnitExists("mouseover") and UnitGUID("mouseover") == inspectedGUID then
    return "mouseover", UnitName("mouseover")
  end
  for _, unit in ipairs(PartyUnits()) do
    if UnitExists(unit) and UnitGUID(unit) == inspectedGUID then
      return unit, UnitName(unit)
    end
  end
end

local function EnsureEventFrame()
  if eventFrame then return eventFrame end
  eventFrame = CreateFrame("Frame", "LycheeNoteInspectFrame")
  eventFrame:SetScript("OnEvent", function(_, event, inspectedGUID)
    if event == "INSPECT_READY" then Inspect.OnInspectReady(inspectedGUID) end
  end)
  return eventFrame
end

function Inspect.OnInspectReady(inspectedGUID)
  if not inspectedGUID then return end
  local unit, unitName = ResolveUnit(inspectedGUID)
  if not unit or not unitName then return end

  local localizedClass = UnitClass(unit)
  local specID = GetInspectSpecialization(unit)
  local specName = specID and specID > 0 and GetSpecializationNameByID(specID) or "未知专精"
  local result = localizedClass .. "-" .. (specName or "未知专精")

  local cleanName = unitName:gsub("%-.*", "")
  CacheResult(cleanName, result)

  local waiting = pending[cleanName]
  if waiting then
    pending[cleanName] = nil
    for _, entry in ipairs(waiting) do
      if entry.callback then C_Timer.After(0, function() entry.callback(result) end) end
    end
  end

  if not next(pending) and eventFrame then
    eventFrame:UnregisterEvent("INSPECT_READY")
  end
end

--- 返回 "职业-专精" 字符串；callback 收到 (value, isFinal)。
function Inspect.GetClassSpec(unit, callback)
  if not unit or not UnitExists(unit) then
    if callback then callback(nil, true) end
    return nil
  end

  local localizedClass = UnitClass(unit)
  if not localizedClass then
    if callback then callback(nil, true) end
    return nil
  end

  local unitName = UnitName(unit)
  local cleanName = unitName and unitName:gsub("%-.*", "")

  if UnitIsUnit(unit, "player") then
    local specID = C_SpecializationInfo and C_SpecializationInfo.GetSpecialization
      and C_SpecializationInfo.GetSpecialization() or nil
    local result = specID and specID > 0
      and Compose(localizedClass, GetSpecializationName(specID)) or (localizedClass .. "-未知专精")
    CacheResult(cleanName, result)
    if callback then callback(result, true) end
    return result
  end

  local inspectSpec = GetInspectSpecialization(unit)
  -- UnitInRaid 在 12.1.0 返回 raidIndex（luaIndex），只按真值判断，绝不当计数用。
  local inGroup = (UnitInParty(unit) or UnitInRaid(unit)) and true or false
  if inGroup and inspectSpec and inspectSpec > 0 then
    local result = Compose(localizedClass, GetSpecializationNameByID(inspectSpec))
    if result then
      CacheResult(cleanName, result)
      if callback then callback(result, true) end
      return result
    end
  end

  local cached = CacheGet(cleanName)
  if cached then
    if callback then callback(cached, true) end
    return cached
  end

  if inspectSpec and inspectSpec > 0 then
    local result = Compose(localizedClass, GetSpecializationNameByID(inspectSpec))
    if result then
      CacheResult(cleanName, result)
      if callback then callback(result, true) end
      return result
    end
  end

  local tooltipResult = SpecFromTooltip(unit, localizedClass)
  if tooltipResult then
    CacheResult(cleanName, tooltipResult)
    if callback then callback(tooltipResult, true) end
    return tooltipResult
  end

  if CanInspect(unit) then
    local now = GetTime()
    if now - lastInspectTime < INSPECT_COOLDOWN then
      C_Timer.After(INSPECT_COOLDOWN - (now - lastInspectTime) + 0.1, function()
        Inspect.GetClassSpec(unit, callback)
      end)
      if callback then callback(localizedClass .. "-检视中", false) end
      return localizedClass .. "-检视中"
    end
    lastInspectTime = now

    if callback then
      pending[cleanName] = pending[cleanName] or {}
      table.insert(pending[cleanName], { callback = callback, timestamp = now })
      C_Timer.After(INSPECT_TIMEOUT, function()
        local waiting = pending[cleanName]
        if not waiting then return end
        for index = #waiting, 1, -1 do
          if waiting[index].callback == callback then
            table.remove(waiting, index)
            callback(localizedClass .. "-检视超时", true)
            break
          end
        end
        if not pending[cleanName] or #pending[cleanName] == 0 then pending[cleanName] = nil end
      end)
    end

    EnsureEventFrame():RegisterEvent("INSPECT_READY")
    NotifyInspect(unit)

    if callback then callback(localizedClass .. "-检视中", false) end
    return localizedClass .. "-检视中"
  end

  local result = localizedClass .. "-无法检视"
  if callback then callback(result, true) end
  return result
end

function Inspect.GetCachedClassSpec(unitName)
  local cleanName = unitName and unitName:gsub("%-.*", "")
  return CacheGet(cleanName)
end

function Inspect.ClearCache()
  cache = {}
  cacheOrder = {}
  cacheSize = 0
  pending = {}
end
