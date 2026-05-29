local ADDON_NAME, ns = ...

ns.Config = {}

local defaults = {
  enabled = true,
  meetingStone = {
    showIcon = true,
    highlightNoob = true,
    enableOneClickReject = false,
  },
  debug = {
    showPanel = false,
  },
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

function ns.Config.Initialize()
  RememberNoobDB = RememberNoobDB or {}
  CopyDefaults(defaults, RememberNoobDB)
  RememberNoobDB.noobs = RememberNoobDB.noobs or {}
  ns.db = RememberNoobDB
end

function ns.Config.Get(path)
  local node = ns.db
  for part in string.gmatch(path, "[^.]+") do
    if type(node) ~= "table" then return nil end
    node = node[part]
  end
  return node
end

function ns.Config.Set(path, value)
  local node = ns.db
  local last
  for part in string.gmatch(path, "[^.]+") do
    if last then
      node[last] = node[last] or {}
      node = node[last]
    end
    last = part
  end
  if last then node[last] = value end
end
