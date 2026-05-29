local ADDON_NAME, ns = ...

local Noob = {}
ns.RememberNoobNoob = Noob

if not string.trim then
  function string:trim()
    return self:match("^%s*(.-)%s*$")
  end
end

function Noob.GetNoobList()
  local db = ns.db
  local list = {}
  for name, data in pairs(db.noobs) do
    table.insert(list, {
      name = name,
      server = data.server,
      timestamp = data.timestamp,
      reason = data.reason,
      classSpec = data.classSpec or "尚未获取"
    })
  end
  table.sort(list, function(a, b) return a.timestamp > b.timestamp end)
  return list
end

function Noob.RemoveNoobMark(playerName)
  local db = ns.db
  if db.noobs[playerName] then
    db.noobs[playerName] = nil
    print("|cff00ff00已移除 " .. playerName .. " 的笨蛋标记！|r")
    if ns.RememberNoobUI and ns.RememberNoobUI.RefreshManagementUIIfOpen then
      ns.RememberNoobUI.RefreshManagementUIIfOpen()
    end
    return true
  end
  return false
end

function Noob.IsNoob(playerName)
  if not playerName then return false end
  local cleanName = playerName
  if string.find(playerName, "-", 1, true) then
    cleanName = strsplit("-", playerName)
  end
  local db = ns.db
  return db.noobs[cleanName] ~= nil
end

function Noob.AddNoobMark(playerName, reason, targetServer, preClassSpec)
  local success, errorMsg = pcall(function()
    if not playerName or playerName == "" then return end
    if playerName == UnitName("player") then
      print("|cffff0000RememberNoob: 不能把自己加入笨蛋名单！|r")
      return
    end

    local cleanName = playerName
    local actualServer = targetServer
    local classSpec = preClassSpec or "尚未获取"
    local targetUnit = nil

    if not targetServer then
      local actualName = playerName
      if UnitExists("target") then
        local targetName = UnitName("target")
        if targetName == playerName then
          actualName = GetUnitName("target", true) or playerName
          targetUnit = "target"
        end
      elseif UnitExists("mouseover") then
        local mouseoverName = UnitName("mouseover")
        if mouseoverName == playerName then
          actualName = GetUnitName("mouseover", true) or playerName
          targetUnit = "mouseover"
        end
      end
      if actualName:find("-") then
        cleanName, actualServer = strsplit("-", actualName)
      else
        cleanName = actualName
      end
    else
      cleanName = playerName:gsub("%-.*", "")
    end

    if targetUnit and not preClassSpec then
      if ns.RememberNoobInspect then
        classSpec = ns.RememberNoobInspect.GetTargetClassSpec(targetUnit) or "尚未获取"
      end
    end

    local db = ns.db
    db.noobs[cleanName] = {
      server = actualServer,
      timestamp = time(),
      reason = reason or "无理由",
      classSpec = classSpec
    }

    print("|cff00ff00已添加笨蛋标记: " .. cleanName .. " (" .. (reason or "无理由") .. ")|r")

    if ns.RememberNoobUI and ns.RememberNoobUI.RefreshManagementUIIfOpen then
      ns.RememberNoobUI.RefreshManagementUIIfOpen()
    end
  end)

  if not success then
    print("|cffff0000RememberNoob错误: 添加笨蛋标记时发生异常 - " .. tostring(errorMsg) .. "|r")
  end
end

function Noob.MarkAsNoob(playerName, server, unit)
  if not playerName or playerName == "" then return end
  if playerName == UnitName("player") then
    print("|cffff0000RememberNoob: 不能把自己加入笨蛋名单！|r")
    return
  end
  if ns.RememberNoobDialogs then
    ns.RememberNoobDialogs.ShowReasonDialog(playerName, server, unit)
  end
end

--- Serializer

local function SerializeValue(v)
  if type(v) == "string" then
    return '"' .. v:gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r') .. '"'
  elseif type(v) == "number" then
    return tostring(v)
  elseif type(v) == "boolean" then
    return tostring(v)
  elseif type(v) == "table" then
    return Noob.SerializeTable(v)
  else
    return '""'
  end
end

function Noob.SerializeTable(t)
  local isArray = true
  local maxIndex = 0
  local count = 0
  for k, v in pairs(t) do
    count = count + 1
    if type(k) == "number" and k == math.floor(k) and k > 0 then
      if k > maxIndex then maxIndex = k end
    else
      isArray = false
      break
    end
  end
  if isArray and count == maxIndex then
    local result = "["
    for i = 1, maxIndex do
      if i > 1 then result = result .. "," end
      result = result .. SerializeValue(t[i])
    end
    result = result .. "]"
    return result
  else
    local result = "{"
    local first = true
    for k, v in pairs(t) do
      if not first then result = result .. "," end
      first = false
      result = result .. '"' .. tostring(k) .. '":' .. SerializeValue(v)
    end
    result = result .. "}"
    return result
  end
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
    local endPos = pos + 1
    while endPos <= #str do
      local c = str:sub(endPos, endPos)
      if c == '"' and str:sub(endPos - 1, endPos - 1) ~= '\\' then break end
      endPos = endPos + 1
    end
    if endPos > #str then return nil, pos end
    local value = str:sub(pos + 1, endPos - 1)
    value = value:gsub('\\"', '"'):gsub('\\n', '\n'):gsub('\\r', '\r')
    return value, endPos + 1
  elseif char == '[' then
    local array = {}
    pos = pos + 1
    pos = skipWhitespace(str, pos)
    if pos <= #str and str:sub(pos, pos) == ']' then return array, pos + 1 end
    while pos <= #str do
      local value, newPos = parseValue(str, pos)
      if value == nil then return nil, pos end
      table.insert(array, value)
      pos = skipWhitespace(str, newPos)
      if pos <= #str and str:sub(pos, pos) == ']' then return array, pos + 1 end
      if pos <= #str and str:sub(pos, pos) == ',' then
        pos = pos + 1
        pos = skipWhitespace(str, pos)
      else
        return nil, pos
      end
    end
    return nil, pos
  elseif char == '{' then
    local obj = {}
    pos = pos + 1
    pos = skipWhitespace(str, pos)
    if pos <= #str and str:sub(pos, pos) == '}' then return obj, pos + 1 end
    while pos <= #str do
      local key, newPos = parseValue(str, pos)
      if type(key) ~= "string" then return nil, pos end
      pos = skipWhitespace(str, newPos)
      if pos > #str or str:sub(pos, pos) ~= ':' then return nil, pos end
      pos = pos + 1
      local value, newPos2 = parseValue(str, pos)
      if value == nil then return nil, pos end
      obj[key] = value
      pos = skipWhitespace(str, newPos2)
      if pos <= #str and str:sub(pos, pos) == '}' then return obj, pos + 1 end
      if pos <= #str and str:sub(pos, pos) == ',' then
        pos = pos + 1
        pos = skipWhitespace(str, pos)
      else
        return nil, pos
      end
    end
    return nil, pos
  else
    local endPos = pos
    while endPos <= #str and not str:sub(endPos, endPos):match("[%s,}%]]") do
      endPos = endPos + 1
    end
    local valueStr = str:sub(pos, endPos - 1)
    if valueStr == "true" then return true, endPos
    elseif valueStr == "false" then return false, endPos
    elseif valueStr == "null" then return nil, endPos end
    return tonumber(valueStr) or valueStr, endPos
  end
end

function Noob.DeserializeTable(jsonStr)
  if not jsonStr or jsonStr == "" then return {} end
  local result = parseValue(jsonStr, 1)
  if type(result) ~= "table" then return {} end
  return result
end

function Noob.Base64Encode(data)
  local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return ((data:gsub('.', function(x)
    local r, bv = '', x:byte()
    for i = 8, 1, -1 do r = r .. (bv % 2 ^ i - bv % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if (#x < 6) then return '' end
    local c = 0
    for i = 1, 6 do c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0) end
    return b:sub(c + 1, c + 1)
  end) .. ({'', '==', '='})[#data % 3 + 1])
end

function Noob.Base64Decode(data)
  local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  data = string.gsub(data, '[^' .. b .. '=]', '')
  return (data:gsub('.', function(x)
    if (x == '=') then return '' end
    local r, f = '', (b:find(x) - 1)
    for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0') end
    return r
  end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
    if (#x ~= 8) then return '' end
    local c = 0
    for i = 1, 8 do c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0) end
    return string.char(c)
  end))
end
