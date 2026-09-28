--- 荔枝笔记生命周期
-- 固定事件白名单：ADDON_LOADED、PLAYER_LOGIN、PLAYER_REGEN_DISABLED、GROUP_ROSTER_UPDATE。
-- 初始化顺序显式声明；停用时立即取消订阅并清掉高亮，不卸载不可逆的 hook。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local events = CreateFrame("Frame", "LycheeNoteEvents")
LN.events = events

local initialized = false
local partyWatchRegistered = false

--- 显式初始化顺序：存储 → 界面 → 右键菜单 → 集合石高亮 → 队伍检查。
local function InitializeDomains()
  if initialized then return end
  initialized = true
  LN.SafeCall("Notes.Initialize", LN.Notes.Initialize)
  LN.SafeCall("UI.Initialize", LN.UI.Initialize)
  LN.SafeCall("Menus.Setup", LN.Menus.Setup)
  LN.SafeCall("MeetingStone.Initialize", LN.MeetingStone.Initialize)
end

--- 只有启用状态下的功能才订阅 GROUP_ROSTER_UPDATE 并应用集合石高亮。
local function SyncEnabledFeatures()
  local enabled = LN.Config.IsEnabled()
  if enabled and not partyWatchRegistered then
    partyWatchRegistered = true
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    LN.SafeCall("Menus.Setup", LN.Menus.Setup)
    LN.SafeCall("MeetingStone.Initialize", LN.MeetingStone.Initialize)
  elseif not enabled and partyWatchRegistered then
    partyWatchRegistered = false
    events:UnregisterEvent("GROUP_ROSTER_UPDATE")
    LN.SafeCall("MeetingStone.Refresh", LN.MeetingStone.Refresh)
    LN.SafeCall("UI.RefreshIfOpen", LN.UI.RefreshIfOpen)
  end
end

function LN.SetEnabled(enabled)
  LN.Config.SetBool("enabled", enabled)
  SyncEnabledFeatures()
  LN.Log.Info(enabled and "已启用。" or "已停用：右键标记与集合石高亮已关闭。")
end

--- /note            打开 / 关闭主窗口
--- /note on|off     启用 / 停用（右键与集合石高亮一并停止）
--- /note add 理由   记录当前选中目标
local function MarkTarget(reason)
  if not UnitExists("target") or not UnitIsPlayer("target") then
    LN.Log.Error("没有选中有效的玩家目标。")
    return
  end
  local name = GetUnitName("target", false)
  if LN.Trim(reason) == "" then
    LN.Notes.Mark(name)
  else
    LN.Notes.Add(name, reason)
  end
end

local function RegisterSlashCommands()
  SLASH_LYCHEENOTE1 = "/note"
  SlashCmdList["LYCHEENOTE"] = function(msg)
    local command, rest = (msg or ""):match("^(%S+)%s*(.-)$")
    command = command or ""
    if command == "on" then
      LN.SetEnabled(true)
      return
    end
    if command == "off" then
      LN.SetEnabled(false)
      return
    end
    if command == "add" then
      MarkTarget(rest)
      return
    end
    if LN.UI.Toggle then LN.UI.Toggle() end
  end
end

events:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... ~= ADDON_NAME then return end
    events:UnregisterEvent("ADDON_LOADED")
    LN.SafeCall("Config.Initialize", LN.Config.Initialize)
    RegisterSlashCommands()
    InitializeDomains()
    SyncEnabledFeatures()
    return
  end

  if event == "PLAYER_LOGIN" then
    events:UnregisterEvent("PLAYER_LOGIN")
    LN.SafeCall("Menus.Setup", LN.Menus.Setup)
    return
  end

  if event == "GROUP_ROSTER_UPDATE" then
    if LN.Events.CheckParty then LN.Events.CheckParty() end
    return
  end

  if event == "PLAYER_REGEN_DISABLED" then
    LN.SafeCall("Layer.OnCombatLockdown", LN.Layer.OnCombatLockdown)
  end
end)

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
