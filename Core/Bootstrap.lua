--- 荔枝笔记引导层
-- 只建立命名空间、输出通道和错误隔离，不做任何初始化工作。
-- 初始化顺序由 Core/Init.lua 显式声明，不使用隐式模块广播。
-- 本文件必须排在 TOC 首位：其余文件在加载期就要取到 LN 命名空间。
-- TOC 传入的 ns 是客户端私有表，不会出现在 _G 里；这里额外挂一个公开句柄，
-- 供 /run 调试、其他插件集成和实机探针定位问题。

local ADDON_NAME, ns = ...

local LN = {}
ns.LycheeNote = LN
_G.LycheeNote = LN

LN.addonName = ADDON_NAME
LN.displayName = "荔枝笔记"
LN.brandColor = "|cffd53c49"
LN.brandColorClose = "|r"

LN.Notes = LN.Notes or {}
LN.Inspect = LN.Inspect or {}
LN.Menus = LN.Menus or {}
LN.MeetingStone = LN.MeetingStone or {}
LN.UI = LN.UI or {}
LN.Dialogs = LN.Dialogs or {}
LN.Events = LN.Events or {}

-- ---------------------------------------------------------------- 公共工具

function LN.Trim(value)
  if type(value) ~= "string" then return "" end
  if strtrim then return strtrim(value) end
  return value:match("^%s*(.-)%s*$")
end

function LN.SafeCall(label, fn, ...)
  if type(fn) ~= "function" then return true end
  local ok, err = pcall(fn, ...)
  if not ok then
    LN.Log.Error(tostring(label) .. " 失败：" .. tostring(err))
    return false
  end
  return true
end

--- 当前队伍/团队的单位序列（含玩家自身），队伍与团队共用同一入口。
function LN.GetGroupUnits()
  local count = GetNumGroupMembers()
  if count <= 0 then return {} end
  local inRaid = IsInRaid()
  local units = {}
  for index = 1, count do
    if inRaid then
      units[#units + 1] = "raid" .. index
    else
      units[#units + 1] = index == 1 and "player" or ("party" .. (index - 1))
    end
  end
  return units
end

-- ---------------------------------------------------------------- 输出通道

--- 所有用户可见消息都经过这里，前缀与配色只在此处决定。
LN.Log = {}

function LN.Log.Write(color, message, ...)
  local text = select("#", ...) > 0 and string.format(message, ...) or message
  print(color .. LN.displayName .. "|r: " .. text)
end

function LN.Log.Info(message, ...) LN.Log.Write(LN.brandColor, message, ...) end
--- 前缀一律荔枝红（与 Lychee 启动器同源）；成功与普通消息只在内容上区分，不再染绿。
function LN.Log.Success(message, ...) LN.Log.Info(message, ...) end
function LN.Log.Error(message, ...) LN.Log.Write("|cffff5560", message, ...) end
