--- 荔枝笔记配置层
-- SavedVariables 的唯一所有者：LycheeNoteDB（存档文件 LycheeNote.lua）。
-- 热路径不反复解析 db，只在低频入口读取快照。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Config = {}
LN.Config = Config

Config.DB = "LycheeNoteDB"

local SCHEMA_VERSION = 3

local defaults = {
  schemaVersion = SCHEMA_VERSION,
  enabled = true,
  askReason = true,
}

local function CopyDefaults(src, dst)
  for key, value in pairs(src) do
    if type(value) == "table" then
      if type(dst[key]) ~= "table" then dst[key] = {} end
      CopyDefaults(value, dst[key])
    elseif dst[key] == nil then
      dst[key] = value
    end
  end
end

function Config.Initialize()
  _G[Config.DB] = type(_G[Config.DB]) == "table" and _G[Config.DB] or {}
  local db = _G[Config.DB]
  db.records = type(db.records) == "table" and db.records or {}
  CopyDefaults(defaults, db)
  db.schemaVersion = SCHEMA_VERSION
  LN.db = db
  return db
end

function Config.Get(path)
  local node = LN.db
  for part in string.gmatch(path, "[^.]+") do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return node
end

function Config.Set(path, value)
  local node = LN.db
  if type(node) ~= "table" then return false end
  local last
  for part in string.gmatch(path, "[^.]+") do
    if last then
      node[last] = type(node[last]) == "table" and node[last] or {}
      node = node[last]
    end
    last = part
  end
  if last then node[last] = value end
  return true
end

function Config.GetBool(path)
  return Config.Get(path) == true
end

function Config.SetBool(path, value)
  return Config.Set(path, value and true or false)
end

function Config.IsEnabled()
  return Config.GetBool("enabled")
end

function Config.AskReason()
  return Config.GetBool("askReason")
end
