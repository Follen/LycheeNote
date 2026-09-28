--- 记录存储
-- 名单位于 LN.db.records，键为 "名字-服务器"。序列化与 Base64 只出现在数据边界。
-- 本模块不持有 UI，也不主动打印；调用方决定何时反馈。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Notes = {}
LN.Notes = Notes

local RECORD_VERSION = 2
local DEFAULT_REALM = "未知服务器"
local DEFAULT_REASON = "无理由"
local DEFAULT_SPEC = "尚未获取"

--- "名字-服务器" → 名字、服务器。缺少服务器时回落到本服。
function Notes.SplitIdentity(playerName, server)
  playerName = LN.Trim(playerName)
  if playerName == "" then return nil end

  local cleanName = playerName:gsub("%-.*", "")
  local parsedServer = playerName:match("^[^%-]+%-(.+)$")
  local normalizedServer = LN.Trim(server)
  local hasServer = normalizedServer ~= "" or parsedServer ~= nil
  local realm = normalizedServer ~= "" and normalizedServer or parsedServer or (GetRealmName() or DEFAULT_REALM)
  if realm == "" then realm = DEFAULT_REALM end
  return cleanName, realm, hasServer
end

function Notes.Key(name, server)
  return name .. "-" .. server
end

local function IsSelf(playerName, server, unit)
  if unit and UnitExists and UnitExists(unit) and UnitIsUnit and UnitIsUnit(unit, "player") then
    return true
  end
  local name, realm = Notes.SplitIdentity(playerName, server)
  local localName = UnitName and UnitName("player")
  return name ~= nil and localName ~= nil and name == localName and realm == (GetRealmName() or "")
end

local function TimestampOf(record)
  return type(record) == "table" and type(record.timestamp) == "number" and record.timestamp or 0
end

local function NormalizeRecord(key, data)
  if type(data) ~= "table" then return nil end
  local name, server = Notes.SplitIdentity(data.name or tostring(key), data.server)
  if not name then return nil end
  local reason = LN.Trim(data.reason)
  local classSpec = LN.Trim(data.classSpec)
  return {
    name = name,
    server = server,
    timestamp = TimestampOf(data),
    reason = reason ~= "" and reason or DEFAULT_REASON,
    classSpec = classSpec ~= "" and classSpec or DEFAULT_SPEC,
  }
end

function Notes.Initialize()
  local db = LN.db
  if type(db) ~= "table" then return false end
  if db.__lycheeNoteRecords == RECORD_VERSION then return true end

  local source = type(db.records) == "table" and db.records or {}
  local migrated = {}
  for key, data in pairs(source) do
    local record = NormalizeRecord(key, data)
    if record then
      local newKey = Notes.Key(record.name, record.server)
      local existing = migrated[newKey]
      if not existing or record.timestamp >= TimestampOf(existing) then
        migrated[newKey] = record
      end
    end
  end

  db.records = migrated
  db.__lycheeNoteRecords = RECORD_VERSION
  return true
end

--- 返回 record、key、cleanName、realm。跨服重名时返回 nil。
function Notes.Find(playerName, server)
  Notes.Initialize()
  local db = LN.db
  if type(db) ~= "table" or type(db.records) ~= "table" then return nil end
  local name, realm, hasServer = Notes.SplitIdentity(playerName, server)
  if not name then return nil end

  if hasServer then
    local key = Notes.Key(name, realm)
    local record = db.records[key]
    return record, record and key or nil, name, realm
  end

  local currentRealm = GetRealmName() or DEFAULT_REALM
  local currentKey = Notes.Key(name, currentRealm)
  if db.records[currentKey] then
    return db.records[currentKey], currentKey, name, currentRealm
  end

  local match, matchKey, matchRealm
  for key, record in pairs(db.records) do
    if type(record) == "table" and record.name == name then
      if match then return nil end
      match, matchKey, matchRealm = record, key, record.server
    end
  end
  return match, matchKey, name, matchRealm
end

function Notes.List()
  Notes.Initialize()
  local db = LN.db
  local list = {}
  if type(db) ~= "table" or type(db.records) ~= "table" then return list end
  for key, data in pairs(db.records) do
    if type(data) == "table" then
      list[#list + 1] = {
        key = key,
        name = data.name or tostring(key):match("^([^%-]+)") or tostring(key),
        server = data.server or DEFAULT_REALM,
        timestamp = TimestampOf(data),
        reason = data.reason or DEFAULT_REASON,
        classSpec = data.classSpec or DEFAULT_SPEC,
      }
    end
  end
  table.sort(list, function(a, b)
    if a.timestamp == b.timestamp then return a.key < b.key end
    return a.timestamp > b.timestamp
  end)
  return list
end

function Notes.Count()
  local db = LN.db
  if type(db) ~= "table" or type(db.records) ~= "table" then return 0 end
  local count = 0
  for _ in pairs(db.records) do count = count + 1 end
  return count
end

function Notes.Get(playerName, server)
  return Notes.Find(playerName, server)
end

function Notes.Has(playerName, server)
  return Notes.Find(playerName, server) ~= nil
end

function Notes.Add(playerName, reason, targetServer, preClassSpec)
  local ok, err = pcall(function()
    if type(playerName) ~= "string" or playerName == "" then return end
    if IsSelf(playerName, targetServer) then
      LN.Log.Error("不能把自己记进去。")
      return
    end

    local cleanName, actualServer = Notes.SplitIdentity(playerName, targetServer)
    local classSpec = preClassSpec or DEFAULT_SPEC
    local targetUnit

    if not targetServer then
      local actualName = playerName
      if UnitExists("target") then
        local targetName = UnitName("target")
        if targetName == playerName or (targetName and targetName:gsub("%-.*", "") == cleanName) then
          actualName = GetUnitName("target", true) or playerName
          targetUnit = "target"
        end
      end
      if not targetUnit and UnitExists("mouseover") then
        local mouseoverName = UnitName("mouseover")
        if mouseoverName == playerName or (mouseoverName and mouseoverName:gsub("%-.*", "") == cleanName) then
          actualName = GetUnitName("mouseover", true) or playerName
          targetUnit = "mouseover"
        end
      end
      cleanName, actualServer = Notes.SplitIdentity(actualName, nil)
    end

    if not cleanName then return end
    if targetUnit and not preClassSpec and LN.Inspect.GetClassSpec then
      classSpec = LN.Inspect.GetClassSpec(targetUnit) or DEFAULT_SPEC
    end

    LN.db.records[Notes.Key(cleanName, actualServer)] = {
      name = cleanName,
      server = actualServer,
      timestamp = time(),
      reason = reason or DEFAULT_REASON,
      classSpec = classSpec,
    }

    LN.Log.Success("已记录：" .. cleanName .. "-" .. actualServer .. "（" .. (reason or DEFAULT_REASON) .. "）")
    if LN.UI.RefreshIfOpen then LN.UI.RefreshIfOpen() end
  end)

  if not ok then LN.Log.Error("写入记录时发生异常：" .. tostring(err)) end
  return ok
end

function Notes.Remove(playerName, server)
  local record, key = Notes.Find(playerName, server)
  if not record or not key then return false end
  LN.db.records[key] = nil
  LN.Log.Success("已移除 " .. (record.name or playerName) .. "-"
    .. (record.server or server or GetRealmName()) .. " 的记录。")
  if LN.UI.RefreshIfOpen then LN.UI.RefreshIfOpen() end
  return true
end

function Notes.SetReason(playerName, server, reason)
  local record = Notes.Find(playerName, server)
  if not record then return false end
  reason = LN.Trim(reason)
  record.reason = reason ~= "" and reason or DEFAULT_REASON
  return true
end

--- 合并导入记录；返回 写入数、无效数。
function Notes.Merge(records)
  Notes.Initialize()
  if type(records) ~= "table" then return 0, 0 end
  local merged, skipped = 0, 0
  for _, item in ipairs(records) do
    local name, server
    if type(item) ~= "table" or not item.name then
      skipped = skipped + 1
    else
      name, server = Notes.SplitIdentity(item.name, item.server)
      if not name then
        skipped = skipped + 1
      else
        local incoming = {
          name = name,
          server = server,
          timestamp = TimestampOf(item) > 0 and TimestampOf(item) or time(),
          reason = LN.Trim(item.reason) ~= "" and LN.Trim(item.reason) or DEFAULT_REASON,
          classSpec = LN.Trim(item.classSpec) ~= "" and LN.Trim(item.classSpec) or DEFAULT_SPEC,
        }
        local key = Notes.Key(name, server)
        local current = LN.db.records[key]
        if not current or incoming.timestamp > TimestampOf(current) then
          LN.db.records[key] = incoming
          merged = merged + 1
        end
      end
    end
  end
  return merged, skipped
end

--- 标记入口：按设置决定是否先问理由。
function Notes.Mark(playerName, server, unit)
  if type(playerName) ~= "string" or playerName == "" then return end
  if IsSelf(playerName, server, unit) then
    LN.Log.Error("不能把自己记进去。")
    return
  end
  if not LN.Config.AskReason() then
    return Notes.Add(playerName, DEFAULT_REASON, server)
  end
  if LN.Dialogs.ShowAddDialog then LN.Dialogs.ShowAddDialog(playerName, server, unit) end
end

-- ---------------------------------------------------------------- 序列化

local function SerializeValue(v)
  local kind = type(v)
  if kind == "string" then
    return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r') .. '"'
  elseif kind == "number" or kind == "boolean" then
    return tostring(v)
  elseif kind == "table" then
    return Notes.Serialize(v)
  end
  return '""'
end

function Notes.Serialize(t)
  local isArray = true
  local maxIndex, count = 0, 0
  for k in pairs(t) do
    count = count + 1
    if type(k) == "number" and k == math.floor(k) and k > 0 then
      if k > maxIndex then maxIndex = k end
    else
      isArray = false
      break
    end
  end
  if isArray and count == maxIndex then
    local out = { "[" }
    for index = 1, maxIndex do
      if index > 1 then out[#out + 1] = "," end
      out[#out + 1] = SerializeValue(t[index])
    end
    out[#out + 1] = "]"
    return table.concat(out)
  end

  local out, first = { "{" }, true
  for k, v in pairs(t) do
    if not first then out[#out + 1] = "," end
    first = false
    out[#out + 1] = '"' .. tostring(k) .. '":' .. SerializeValue(v)
  end
  out[#out + 1] = "}"
  return table.concat(out)
end

local function skipWhitespace(str, pos)
  while pos <= #str and str:sub(pos, pos):match("%s") do
    pos = pos + 1
  end
  return pos
end

local function parseValue(str, pos)
  pos = skipWhitespace(str, pos)
  if pos > #str then return nil, pos end
  local char = str:sub(pos, pos)

  if char == '"' then
    local endPos, escaped = pos + 1, false
    while endPos <= #str do
      local c = str:sub(endPos, endPos)
      if c == '"' and not escaped then break end
      escaped = (c == "\\") and not escaped or false
      endPos = endPos + 1
    end
    if endPos > #str then return nil, pos end
    local raw = str:sub(pos + 1, endPos - 1)
    local value, index = {}, 1
    while index <= #raw do
      local c = raw:sub(index, index)
      if c == "\\" and index < #raw then
        local nextChar = raw:sub(index + 1, index + 1)
        value[#value + 1] = (nextChar == "n" and "\n") or (nextChar == "r" and "\r") or nextChar
        index = index + 2
      else
        value[#value + 1] = c
        index = index + 1
      end
    end
    return table.concat(value), endPos + 1

  elseif char == "[" then
    local array = {}
    pos = skipWhitespace(str, pos + 1)
    if pos <= #str and str:sub(pos, pos) == "]" then return array, pos + 1 end
    while pos <= #str do
      local value, newPos = parseValue(str, pos)
      if value == nil then return nil, pos end
      array[#array + 1] = value
      pos = skipWhitespace(str, newPos)
      if pos <= #str and str:sub(pos, pos) == "]" then return array, pos + 1 end
      if pos <= #str and str:sub(pos, pos) == "," then
        pos = skipWhitespace(str, pos + 1)
      else
        return nil, pos
      end
    end
    return nil, pos

  elseif char == "{" then
    local obj = {}
    pos = skipWhitespace(str, pos + 1)
    if pos <= #str and str:sub(pos, pos) == "}" then return obj, pos + 1 end
    while pos <= #str do
      local key, newPos = parseValue(str, pos)
      if type(key) ~= "string" then return nil, pos end
      pos = skipWhitespace(str, newPos)
      if pos > #str or str:sub(pos, pos) ~= ":" then return nil, pos end
      local value, newPos2 = parseValue(str, pos + 1)
      if value == nil then return nil, pos end
      obj[key] = value
      pos = skipWhitespace(str, newPos2)
      if pos <= #str and str:sub(pos, pos) == "}" then return obj, pos + 1 end
      if pos <= #str and str:sub(pos, pos) == "," then
        pos = skipWhitespace(str, pos + 1)
      else
        return nil, pos
      end
    end
    return nil, pos
  end

  local endPos = pos
  while endPos <= #str and not str:sub(endPos, endPos):match("[%s,}%]]") do
    endPos = endPos + 1
  end
  local literal = str:sub(pos, endPos - 1)
  if literal == "true" then return true, endPos end
  if literal == "false" then return false, endPos end
  if literal == "null" then return nil, endPos end
  return tonumber(literal) or literal, endPos
end

function Notes.Parse(jsonStr)
  if type(jsonStr) ~= "string" or jsonStr == "" then return {} end
  local result, nextPos = parseValue(jsonStr, 1)
  if type(result) ~= "table" then return {} end
  nextPos = skipWhitespace(jsonStr, nextPos or 1)
  if nextPos <= #jsonStr then return {} end
  return result
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function Notes.EncodeBase64(data)
  return ((data:gsub(".", function(x)
    local bits, byte = "", x:byte()
    for i = 8, 1, -1 do bits = bits .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and "1" or "0") end
    return bits
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
    if #bits < 6 then return "" end
    local index = 0
    for i = 1, 6 do index = index + (bits:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
    return B64:sub(index + 1, index + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

function Notes.DecodeBase64(data)
  data = string.gsub(data, "[^" .. B64 .. "=]", "")
  return (data:gsub(".", function(x)
    if x == "=" then return "" end
    local bits, index = "", (B64:find(x) - 1)
    for i = 6, 1, -1 do bits = bits .. (index % 2 ^ i - index % 2 ^ (i - 1) > 0 and "1" or "0") end
    return bits
  end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
    if #bits ~= 8 then return "" end
    local byte = 0
    for i = 1, 8 do byte = byte + (bits:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
    return string.char(byte)
  end))
end
