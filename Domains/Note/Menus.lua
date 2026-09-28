--- 玩家右键菜单集成
-- 三条入口按优先级：现代 Menu.ModifyMenu → LibDropDownExtension → 旧 ToggleDropDownMenu。
-- 每条 hook 只安装一次；停用时不卸载 hook，只让回调立即短路。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Menus = {}
LN.Menus = Menus

local modernReady, legacyReady = false, false
local extensionReady = false

local VALID_TYPES = {
  ARENAENEMY = true, ENEMY_PLAYER = true, FOCUS = true, PARTY = true,
  PLAYER = true, RAID = true, RAID_PLAYER = true, TARGET = true,
}

local INJECT_KEY = {}
local INJECT_TTL = 0.25

local function IsEnabled()
  return LN.Config and LN.Config.GetBool("enabled")
end

local function IsValidMenuType(which)
  if type(which) ~= "string" then return false end
  return VALID_TYPES[which:gsub("^MENU_UNIT_", "")] == true
end

--- 把任意来源（Menu contextData 或旧 dropdown frame）解析为 名字/服务器/unit。
function Menus.ResolveTarget(source, fallbackUnit)
  local unit = (source and source.unit) or fallbackUnit
  local name = (source and (source.name or source.Name))
  local server = (source and (source.server or source.Server))

  if not name and unit and UnitExists(unit) and UnitIsPlayer(unit) then
    name, server = UnitName(unit)
  end

  if type(name) == "string" and (not server or server == "") then
    local parsedName, parsedServer = strsplit("-", name)
    if parsedServer then
      name, server = parsedName, parsedServer
    else
      name = parsedName
    end
  end

  if type(name) ~= "string" or name == "" then return nil end
  name = name:gsub("%-.*", "")
  if name == "" or name == UnitName("player") then return nil end

  if not server or server == "" then server = GetRealmName() end
  return name, server, unit
end

local function BuildEntries(playerName, server, unit)
  if LN.Notes.Has(playerName, server) then
    return { {
      text = "移除记录",
      danger = true,
      onClick = function() LN.Notes.Remove(playerName, server) end,
    } }
  end
  return { {
    text = "标记并记录",
    onClick = function() LN.Notes.Mark(playerName, server, unit) end,
  } }
end

--- 现代右键菜单：MENU_UNIT_* 与旧式标签同时注册。
local function ModifyMenuCallback(_, rootDescription, contextData)
  if not IsEnabled() or not contextData then return end
  local playerName, server, unit = Menus.ResolveTarget(contextData)
  if not playerName then return end

  rootDescription:CreateDivider()
  for _, entry in ipairs(BuildEntries(playerName, server, unit)) do
    rootDescription:CreateButton(entry.text, entry.onClick)
  end
end

local function RegisterModernMenus()
  if modernReady then return true end
  if not (Menu and Menu.ModifyMenu) then return false end
  for tagName in pairs(VALID_TYPES) do
    Menu.ModifyMenu("MENU_UNIT_" .. tagName, ModifyMenuCallback)
    Menu.ModifyMenu(tagName, ModifyMenuCallback)
  end
  modernReady = true
  return true
end

--- 旧式下拉兜底：部分第三方 UI 绕过 Menu.ModifyMenu 强制走旧下拉管线。
-- 12.1.0 已移除 UnitPopup_ShowMenu，单位菜单统一走 UnitPopup_OpenMenu，
-- 该路径由 Menu.ModifyMenu 覆盖，这里只保留 ToggleDropDownMenu 一条。
local function RegisterLegacyHooks()
  if legacyReady then return true end
  if not (ToggleDropDownMenu and not INJECT_KEY.ToggleDropDownMenu) then return false end

  hooksecurefunc("ToggleDropDownMenu", function(_, _, dropdownFrame)
    if not IsEnabled() or not dropdownFrame then return end
    if dropdownFrame.which and not IsValidMenuType(dropdownFrame.which) then return end
    local fallbackUnit = dropdownFrame.GetAttribute and dropdownFrame:GetAttribute("unit")
    local playerName, server, unit = Menus.ResolveTarget(dropdownFrame, fallbackUnit)
    if not playerName then return end

    -- 同一个下拉在短时间内可能被多次展开，按键去抖避免重复注入。
    local key = tostring(playerName) .. ":" .. tostring(server) .. ":" .. tostring(unit)
    local now = GetTime()
    if dropdownFrame.__lnInjectKey == key and dropdownFrame.__lnInjectTime
      and now - dropdownFrame.__lnInjectTime < INJECT_TTL then
      return
    end
    dropdownFrame.__lnInjectKey = key
    dropdownFrame.__lnInjectTime = now

    local info = UIDropDownMenu_CreateInfo()
    info.text = " "; info.disabled = true; info.notClickable = true
    info.isTitle = true; info.notCheckable = true
    UIDropDownMenu_AddButton(info, 1)

    for _, entry in ipairs(BuildEntries(playerName, server, unit)) do
      local item = UIDropDownMenu_CreateInfo()
      item.text = entry.text
      item.notCheckable = true
      item.colorCode = entry.danger and "|cffff5560" or "|cff00ff00"
      item.func = entry.onClick
      UIDropDownMenu_AddButton(item, 1)
    end
  end)

  INJECT_KEY.ToggleDropDownMenu = true
  legacyReady = true
  return true
end

local function RegisterExtension()
  if extensionReady then return true end
  local lib = LibStub and LibStub:GetLibrary("LibDropDownExtension-1.0", true)
  if not lib then return false end

  lib:RegisterEvent("OnShow", function(dropdown, _, _, _, data)
    if not IsEnabled() then return end
    if not IsValidMenuType(dropdown.which) then return end
    local playerName, server, unit = Menus.ResolveTarget(dropdown)
    if not playerName then return end

    local entries = BuildEntries(playerName, server, unit)
    local options = data
    local index = 0
    local header = { text = " ", disabled = true, notClickable = true, isTitle = true, notCheckable = true }
    options[#options + 1] = header
    index = #options
    for _, entry in ipairs(entries) do
      options[#options + 1] = {
        text = entry.text,
        notCheckable = true,
        colorCode = entry.danger and "|cffff5560" or "|cff00ff00",
        func = entry.onClick,
      }
    end
    return index >= 1
  end, 1)

  extensionReady = true
  return true
end

--- 幂等：已注册的入口不重复安装，未就绪的入口在后续事件中重试。
function Menus.Setup()
  if not IsEnabled() then return false end
  RegisterModernMenus()
  RegisterLegacyHooks()
  RegisterExtension()
  return modernReady or legacyReady or extensionReady
end

--- 列表行右键：使用自有浮层，不进入原生 Menu manager。
function Menus.ShowRowActions(owner, playerName, server, onChanged)
  local entries = BuildEntries(playerName, server)
  table.insert(entries, {
    text = "编辑理由",
    onClick = function()
      if LN.Dialogs and LN.Dialogs.ShowEditDialog then
        LN.Dialogs.ShowEditDialog(playerName, server, onChanged)
      end
    end,
  })
  LN.Components.ShowActionMenu(owner, entries)
end
