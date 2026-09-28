--- 队伍检查
-- 只在 GROUP_ROSTER_UPDATE 时做一次去抖比对；没有变化时不打印。
-- 不使用常驻 timer：待执行任务最多一个，执行后自我清理。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Events = {}
LN.Events = Events

local MIN_INTERVAL = 2
local MAX_PENDING = 1

local lastRunTime = 0
local lastHash = ""
local pending
local running = false

local function PartyUnits()
  return LN.GetGroupUnits()
end

local function Run()
  pending = nil
  running = false

  local groupSize = GetNumGroupMembers()
  if groupSize <= 1 then return end

  local now = GetTime()
  if now - lastRunTime < MIN_INTERVAL then return end
  lastRunTime = now

  local found = {}
  local parts = {}
  local localName = UnitName("player")

  for _, unit in ipairs(PartyUnits()) do
    local name, server = UnitName(unit)
    if name and name ~= localName then
      local cleanName = name:gsub("%-.*", "")
      local record = LN.Notes.Find(cleanName, server)
      if record then
        found[#found + 1] = { name = cleanName, reason = record.reason or "无理由" }
        parts[#parts + 1] = cleanName .. "\031" .. tostring(server or "")
      end
    end
  end

  table.sort(parts)
  local hash = table.concat(parts, "\030")
  if hash == lastHash then return end
  lastHash = hash

  for _, entry in ipairs(found) do
    LN.Log.Info("队伍里有记录过的人：" .. entry.name .. " —— " .. entry.reason)
  end
end

function Events.CheckParty()
  if running or (pending and #pending > 0) then return end
  running = true
  pending = { C_Timer.NewTimer(0.5, Run) }
  if #pending > MAX_PENDING then pending = { pending[1] } end
end

--- 角色切换时重置比对基线；事件订阅由 Core/Init.lua 统一管理。
function Events.OnPlayerLogin()
  lastHash = ""
  lastRunTime = 0
end
