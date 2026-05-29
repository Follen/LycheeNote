local ADDON_NAME, ns = ...

local MenuModule = {}
ns.RememberNoobMenu = MenuModule
local modernMenusRegistered = false
local toggleDropDownHooked = false
local unitPopupHooked = false

local validTypes = {
  ARENAENEMY = true, ENEMY_PLAYER = true, FOCUS = true,
  PARTY = true, PLAYER = true, RAID = true, RAID_PLAYER = true,
  TARGET = true, WORLD_STATE_SCORE = true,
}

local function IsValidMenuType(which)
  if type(which) ~= "string" then return false end
  which = which:gsub("^MENU_UNIT_", "")
  return validTypes[which] == true
end

local function GetFullNameFromUnit(unit)
  if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return nil, nil end

  local name, server = UnitName(unit)
  if not name or name == "" then return nil, nil end
  if not server or server == "" then
    local fullName = GetUnitName(unit, true)
    if fullName and fullName:find("-", 1, true) then
      name, server = strsplit("-", fullName)
    end
  end
  if not server or server == "" then
    server = GetRealmName()
  end
  return name, server
end

local function ResolveMenuTarget(source, fallbackUnit, fallbackName, fallbackServer)
  local unit = (source and source.unit) or fallbackUnit
  local name = (source and (source.name or source.Name)) or fallbackName
  local server = (source and (source.server or source.Server)) or fallbackServer

  if unit and UnitExists(unit) then
    if not UnitIsPlayer(unit) then return nil end
    local unitName, unitServer = GetFullNameFromUnit(unit)
    name = name or unitName
    server = server or unitServer
  end

  if not name or name == "" then return nil end

  local playerName = name:gsub("%-.*", "")
  if playerName == "" or playerName == UnitName("player") then return nil end
  if not server and name:find("-", 1, true) then
    local _, parsedServer = strsplit("-", name)
    server = parsedServer
  end
  if not server or server == "" then
    server = GetRealmName()
  end

  return playerName, server, unit
end

local function HasSpecCached(unit, playerName)
  if not unit or not UnitExists(unit) then return false end
  if UnitInParty(unit) or UnitInRaid(unit) then
    local specID = GetInspectSpecialization(unit)
    if specID and specID > 0 then return true end
  end
  return ns.RememberNoobInspect.GetCachedClassSpec(playerName) ~= nil
end

local function InjectNoobEntry(rootDescription, playerName, server, unit)
  rootDescription:CreateButton("是个笨蛋", function()
    ns.RememberNoobNoob.MarkAsNoob(playerName, server, unit)
  end)
end

local function ModifyMenuCallback(_, rootDescription, contextData)
  if not contextData then return end
  local playerName, server, unit = ResolveMenuTarget(contextData)
  if not playerName then return end

  local db = ns.db
  rootDescription:CreateDivider()
  if db and db.noobs[playerName] then
    rootDescription:CreateButton("移除笨蛋标记", function()
      ns.RememberNoobNoob.RemoveNoobMark(playerName)
    end)
  else
    InjectNoobEntry(rootDescription, playerName, server, unit)
  end
end

local function RegisterModernMenus()
  if modernMenusRegistered or not Menu or not Menu.ModifyMenu then return false end
  for tagName in pairs(validTypes) do
    Menu.ModifyMenu("MENU_UNIT_" .. tagName, ModifyMenuCallback)
    Menu.ModifyMenu(tagName, ModifyMenuCallback)
  end
  modernMenusRegistered = true
  return true
end

RegisterModernMenus()

-- ============================================
-- Legacy LibDropDownExtension
-- ============================================
local LibDropDownExtension = LibStub and LibStub:GetLibrary("LibDropDownExtension-1.0", true)
if LibDropDownExtension then
  local function IsUnitDropDown(dropdown)
    return IsValidMenuType(dropdown.which)
  end

  local function OnShow(dropdown, event, options, level, data)
    if not IsUnitDropDown(dropdown) then return end
    local playerName, server, unit = ResolveMenuTarget(dropdown)
    if not playerName then return end
    if options[1] then return true end

    local db = ns.db
    local index = 0
    index = index + 1
    options[index] = {
      text = " ", disabled = true, notClickable = true, isTitle = true, notCheckable = true,
    }
    index = index + 1
    if db and db.noobs[playerName] then
      options[index] = {
        text = "移除笨蛋标记", notCheckable = true, colorCode = "|cffff0000",
        func = function() ns.RememberNoobNoob.RemoveNoobMark(playerName) end,
      }
    else
      options[index] = {
        text = "是个笨蛋", notCheckable = true, colorCode = "|cff00ff00",
        func = function()
          ns.RememberNoobNoob.MarkAsNoob(playerName, server, unit)
        end,
      }
    end
    return true
  end

  LibDropDownExtension:RegisterEvent("OnShow", OnShow, 1)
end

-- ============================================
-- Path D: Legacy ToggleDropDownMenu hook for pre-11.0 dropdowns
-- NDui's TaintLess forces unit frame menus through the old dropdown
-- plumbing, completely bypassing Menu.ModifyMenu and UnitPopupManager.
-- ============================================
local function RegisterLegacyHooks()
  local function injectLegacy(dropdownFrame)
    if not dropdownFrame then return end
    if dropdownFrame.which and not IsValidMenuType(dropdownFrame.which) then return end

    local fallbackUnit = dropdownFrame.GetAttribute and dropdownFrame:GetAttribute("unit")
    local playerName, server, unit = ResolveMenuTarget(dropdownFrame, fallbackUnit)
    if not playerName then return end

    local injectKey = tostring(playerName) .. ":" .. tostring(server or "") .. ":" .. tostring(unit or "")
    local now = GetTime()
    if dropdownFrame._noobLegacyInjectedKey == injectKey and
      dropdownFrame._noobLegacyInjectedTime and
      now - dropdownFrame._noobLegacyInjectedTime < 0.25 then
      return
    end
    dropdownFrame._noobLegacyInjectedKey = injectKey
    dropdownFrame._noobLegacyInjectedTime = now

    local db = ns.db
    local sep = UIDropDownMenu_CreateInfo()
    sep.text = ""; sep.disabled = true; sep.notClickable = true
    sep.isTitle = true; sep.notCheckable = true
    UIDropDownMenu_AddButton(sep, 1)

    if db and db.noobs[playerName] then
      local info = UIDropDownMenu_CreateInfo()
      info.text = "移除笨蛋标记"; info.notCheckable = true; info.colorCode = "|cffff0000"
      info.func = function() ns.RememberNoobNoob.RemoveNoobMark(playerName) end
      UIDropDownMenu_AddButton(info, 1)
    else
      local info = UIDropDownMenu_CreateInfo()
      info.text = "是个笨蛋"; info.notCheckable = true; info.colorCode = "|cff00ff00"
      info.func = function()
        ns.RememberNoobNoob.MarkAsNoob(playerName, server, unit)
      end
      UIDropDownMenu_AddButton(info, 1)
    end
  end

  if not toggleDropDownHooked and ToggleDropDownMenu then
    hooksecurefunc("ToggleDropDownMenu", function(_, _, dropdownFrame)
      injectLegacy(dropdownFrame)
    end)
    toggleDropDownHooked = true
  end

  if not unitPopupHooked and UnitPopup_ShowMenu then
    hooksecurefunc("UnitPopup_ShowMenu", function(dropdownFrame, which, unit, name, userData)
      if dropdownFrame then
        dropdownFrame.which = which or dropdownFrame.which
        dropdownFrame.unit = unit or dropdownFrame.unit
        dropdownFrame.name = name or dropdownFrame.name
        if type(userData) == "table" then
          dropdownFrame.server = dropdownFrame.server or userData.server
        end
        injectLegacy(dropdownFrame)
      end
    end)
    unitPopupHooked = true
  end

  return toggleDropDownHooked and unitPopupHooked
end

RegisterLegacyHooks()

local setupFrame = CreateFrame("Frame")
setupFrame:RegisterEvent("PLAYER_LOGIN")
setupFrame:RegisterEvent("ADDON_LOADED")
setupFrame:SetScript("OnEvent", function(self)
  RegisterModernMenus()
  RegisterLegacyHooks()
  if modernMenusRegistered and toggleDropDownHooked and unitPopupHooked then
    self:UnregisterEvent("PLAYER_LOGIN")
    self:UnregisterEvent("ADDON_LOADED")
  end
end)

function MenuModule.SetupMenuSystem()
  RegisterModernMenus()
  RegisterLegacyHooks()
end

function MenuModule.ShowRowContextMenu(playerName, refreshCallback)
  local menu = CreateFrame("Frame", "RememberNoobRowMenu", UIParent, "UIDropDownMenuTemplate")
  local function InitializeMenu(self, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = "编辑备注"
    info.func = function()
      if ns.RememberNoobDialogs then
        ns.RememberNoobDialogs.ShowEditReasonDialog(playerName, refreshCallback)
      end
    end
    info.notCheckable = true; info.colorCode = "|cff00ff00"
    UIDropDownMenu_AddButton(info)
    info = UIDropDownMenu_CreateInfo()
    info.text = "移除"
    info.func = function()
      ns.RememberNoobNoob.RemoveNoobMark(playerName)
      if refreshCallback then refreshCallback() end
    end
    info.notCheckable = true; info.colorCode = "|cffff0000"
    UIDropDownMenu_AddButton(info)
    info = UIDropDownMenu_CreateInfo()
    info.text = "取消"
    info.func = function() end
    info.notCheckable = true; info.colorCode = "|cff888888"
    UIDropDownMenu_AddButton(info)
  end
  UIDropDownMenu_Initialize(menu, InitializeMenu, "MENU")
  ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end
