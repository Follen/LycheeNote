--- 集合石高亮集成
-- 只做一件事：在集合石的申请人/活动列表里标出已记录的人。始终开启，没有设置项、按钮和界面。
-- 不读取团队查找器数据，不产生日志，不订阅 LFG 搜索事件。
-- 集合石未安装时全部函数立即短路，不留事件和 timer。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote
local Theme = LN.Theme

local Bridge = {}
LN.MeetingStone = Bridge

local hooked = false
local attemptFrame
local attemptCount = 0
local MAX_ATTEMPTS = 8
local ATTEMPT_INTERVAL = 2

local NOTE_TEXTURE = [[Interface\TargetingFrame\UI-RaidTargetingIcon_8]]
local NOTE_ICON_SIZE = 14

--- 行背景 = 品牌红压到 26% 透明度；同色也用于团长姓名字段。
local HILITE = { Theme.NoteColor[1], Theme.NoteColor[2], Theme.NoteColor[3], 0.26 }

-- ---------------------------------------------------------------- 环境访问

local function GetEnv()
  local ok, env = pcall(function()
    local lib = LibStub and LibStub("NetEaseEnv-1.0", true)
    return lib and lib._NSList and lib._NSList.MeetingStone
  end)
  if ok then return env end
end

local function GetValue(key)
  local env = GetEnv()
  return (env and env[key]) or _G[key]
end

local function GetClass(className)
  local addon = GetValue("Addon")
  if addon and addon.GetClass then
    local ok, class = pcall(addon.GetClass, addon, className)
    if ok then return class end
  end
end

-- ---------------------------------------------------------------- 名单查询

local function LookupNote(unitName)
  if type(unitName) ~= "string" or unitName == "" then return nil end
  local cleanName, server = unitName:gsub("%-.*", ""), nil
  local parsed = unitName:match("^[^%-]+%-(.+)$")
  if parsed then server = parsed end
  if not LN.Notes then return nil end
  return LN.Notes.Find(cleanName, server)
end

--- 成员名列表：12.1.0 里 GetApplicantMemberInfo 未进 wowdoc，因此 pcall 包装，
-- 失败时回落到有文档的 GetApplicantInfo。
local function ApplicantMemberNames(applicant)
  if not (C_LFGList and applicant.GetID and applicant.GetNumMembers) then return nil end
  local id = applicant:GetID()
  local count = applicant:GetNumMembers() or 0
  if count <= 0 then return nil end

  if C_LFGList.GetApplicantMemberInfo then
    local ok, first = pcall(C_LFGList.GetApplicantMemberInfo, id, 1)
    if ok and type(first) == "string" and first ~= "" then
      local names = { first }
      for index = 2, count do
        local got, name = pcall(C_LFGList.GetApplicantMemberInfo, id, index)
        if got and type(name) == "string" and name ~= "" then names[#names + 1] = name end
      end
      return names
    end
  end

  if C_LFGList.GetApplicantInfo then
    local ok, info = pcall(C_LFGList.GetApplicantInfo, id)
    if ok and type(info) == "table" and type(info.members) == "table" then
      local names = {}
      for _, member in ipairs(info.members) do
        if type(member) == "table" and type(member.name) == "string" and member.name ~= "" then
          names[#names + 1] = member.name
        end
      end
      if #names > 0 then return names end
    end
  end
end

local function LookupApplicant(applicant)
  if not applicant then return nil end

  local names = ApplicantMemberNames(applicant)
  for _, name in ipairs(names or {}) do
    local record = LookupNote(name)
    if record then return record, name end
  end

  if applicant.GetName then
    local name = applicant:GetName()
    return LookupNote(name), name
  end
end

local function FormatDate(timestamp)
  if type(timestamp) == "number" and timestamp > 0 then return date("%Y/%m/%d", timestamp) end
  return "未知"
end

-- ---------------------------------------------------------------- 视觉

--- 每行一个背景贴图，创建一次后只改显隐和颜色。
local function EnsureHighlight(frame)
  if not frame or frame.__lnNoteBg then return frame and frame.__lnNoteBg end
  local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
  bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
  bg:SetColorTexture(HILITE[1], HILITE[2], HILITE[3], HILITE[4])
  bg:Hide()
  frame.__lnNoteBg = bg
  return bg
end

local function SetHighlight(frame, show)
  local bg = EnsureHighlight(frame)
  if not bg then return end
  bg:SetShown(show == true)
end

local function EnsureIcon(frame, anchorTo)
  if not frame or frame.__lnNoteIcon then return frame and frame.__lnNoteIcon end
  local icon = frame:CreateTexture(nil, "OVERLAY", nil, 2)
  icon:SetSize(NOTE_ICON_SIZE, NOTE_ICON_SIZE)
  icon:SetTexture(NOTE_TEXTURE)
  icon:Hide()
  if anchorTo and frame.__lnNoteAnchor ~= anchorTo then
    frame.__lnNoteAnchor = anchorTo
    icon:ClearAllPoints()
    icon:SetPoint("RIGHT", anchorTo, "LEFT", -2, 0)
  end
  frame.__lnNoteIcon = icon
  return icon
end

local function SetIcon(frame, anchorTo, show)
  local icon = EnsureIcon(frame, anchorTo)
  if not icon then return end
  icon:SetShown(show == true)
end

-- ---------------------------------------------------------------- tooltip

local function AppendNoteLines(tooltip, record, matchedName)
  if not tooltip or not record then return end
  if tooltip.AddSeparator then tooltip:AddSeparator() end
  tooltip:AddLine("荔枝笔记：此人已被记录" .. (matchedName and ("（" .. matchedName .. "）") or ""), 0.94, 0.36, 0.39)
  tooltip:AddLine("加入时间：" .. FormatDate(record.timestamp), 0.94, 0.93, 0.91)
  tooltip:AddLine("记录理由：" .. (record.reason or "无理由"), 0.94, 0.93, 0.91, true)
end

-- ---------------------------------------------------------------- 集合石挂钩

local function HookApplicantClass()
  local Applicant = GetValue("Applicant")
  if not Applicant or Applicant.__lnNoteHooked then return end
  Applicant.__lnNoteHooked = true

  function Applicant:GetLycheeNoteMatched()
    return LookupApplicant(self) ~= nil
  end

  function Applicant:GetLycheeNoteName()
    local _, cleanName = LookupApplicant(self)
    return cleanName
  end
end

local function HookActivityClass()
  local Activity = GetValue("Activity")
  if not Activity or Activity.__lnNoteHooked then return end
  Activity.__lnNoteHooked = true

  function Activity:GetLycheeNoteMatched()
    if self.GetLeader then return LookupNote(self:GetLeader()) ~= nil end
    return false
  end
end

local function HookListItemClass()
  local ApplicantItem = GetClass("ApplicantItem")
  if not ApplicantItem then return end

  if ApplicantItem.Constructor and not ApplicantItem.__lnNoteCtor then
    ApplicantItem.__lnNoteCtor = true
    local original = ApplicantItem.Constructor
    function ApplicantItem:Constructor(...)
      original(self, ...)
      EnsureHighlight(self)
    end
  end

  if ApplicantItem.SetAlpha and not ApplicantItem.__lnNoteAlpha then
    ApplicantItem.__lnNoteAlpha = true
    local original = ApplicantItem.SetAlpha
    function ApplicantItem:SetAlpha(alpha, button)
      original(self, alpha, button)
      if self.__lnNoteMarked then
        SetHighlight(self, true)
        if self.__lnNoteMarkedAnchor then SetIcon(self, self.__lnNoteMarkedAnchor, true) end
      end
    end
  end
end

local function HookOperationGridClass()
  local OperationGrid = GetClass("OperationGrid")
  if not OperationGrid or OperationGrid.__lnNoteHooked then return end
  if not (OperationGrid.SetMember or OperationGrid.SetSpinner or OperationGrid.SetText) then return end
  OperationGrid.__lnNoteHooked = true

  local function Mark(self)
    local marked = false
    local member = self.GetMember and self:GetMember()
    if type(member) == "string" and LookupNote(member) then marked = true end
    if not marked and type(self.text) == "string" and LookupNote(self.text) then marked = true end
    SetIcon(self, self.icon or self.Icon, marked)
  end

  if OperationGrid.SetMember then
    local original = OperationGrid.SetMember
    function OperationGrid:SetMember(...) original(self, ...); Mark(self) end
  end
  if OperationGrid.SetText then
    local original = OperationGrid.SetText
    function OperationGrid:SetText(...) original(self, ...); Mark(self) end
  end
end

--- 把列头图标处理替换为“命中即显示荔枝图标”。
local function PatchIconColumn(list, preferredKey)
  if not list or list.__lnNoteColumn or type(list.sortButtons) ~= "table" then return end
  for _, header in ipairs(list.sortButtons) do
    local matched = preferredKey
      and header.key == preferredKey
      or (not preferredKey and (header.key == "Icon" or header.key == "@"))
    if matched then
      local original = header.iconHandler
      header.iconHandler = function(data)
        local marked = false
        if data then
          if data.GetLycheeNoteMatched then marked = data:GetLycheeNoteMatched() == true
          elseif data.GetLeader then marked = LookupNote(data:GetLeader()) ~= nil end
        end
        if marked then
          return NOTE_TEXTURE, 14, 14, 18, 18, NOTE_ICON_SIZE, NOTE_ICON_SIZE
        end
        if original then return original(data) end
      end
      list.__lnNoteColumn = true
      return
    end
  end
end

local function PatchLeaderColumn(list)
  if not list or list.__lnNoteLeader or type(list.sortButtons) ~= "table" then return end
  for _, header in ipairs(list.sortButtons) do
    if header.key == "Leader" and header.showHandler then
      local original = header.showHandler
      header.showHandler = function(activity)
        local text, r, g, b = original(activity)
        if activity and activity.GetLeader and LookupNote(activity:GetLeader()) then
          return text, HILITE[1], HILITE[2], HILITE[3]
        end
        return text, r, g, b
      end
      list.__lnNoteLeader = true
      return
    end
  end
end

local function HookApplicantPanel()
  local panel = GetValue("ApplicantPanel")
  if not panel then return end
  local list = panel.ApplicantList
  if not list then return end

  PatchIconColumn(list, "starTarget")

  if not list.__lnNoteGroup and list.events and list.events.OnItemGrouped then
    list.__lnNoteGroup = true
    local original = list.events.OnItemGrouped
    list:SetCallback("OnItemGrouped", function(view, button, applicant, ...)
      original(view, button, applicant, ...)
      if not button then return end
      local record, matchedName = LookupApplicant(applicant)
      button.__lnNoteMarked = record ~= nil
      button.__lnNoteMarkedAnchor = button.starTarget or button.Icon
      SetHighlight(button, record ~= nil)
      SetIcon(button, button.__lnNoteMarkedAnchor, record ~= nil)
      if record and button.SetLycheeNoteTooltip then
        button.__lnNoteRecord = record
        button.__lnNoteName = matchedName
      end
    end)
  end
end

local function HookBrowsePanel()
  local panel = GetValue("BrowsePanel") or _G.MeetingStone_BrowsePanel
  if not panel or not panel.ActivityList then return end
  PatchIconColumn(panel.ActivityList)
  PatchLeaderColumn(panel.ActivityList)
end

local function HookMainPanel()
  local panel = GetValue("MainPanel")
  if not panel then return end

  if panel.OpenActivityTooltip and not panel.__lnNoteActivityTip then
    panel.__lnNoteActivityTip = true
    local original = panel.OpenActivityTooltip
    function panel:OpenActivityTooltip(activity, tooltip)
      original(self, activity, tooltip)
      local target = tooltip or self.GameTooltip
      if activity and activity.GetLeader and target then
        local record = LookupNote(activity:GetLeader())
        if record then
          AppendNoteLines(target, record, activity:GetLeader())
          target:Show()
        end
      end
    end
  end

  if panel.OpenApplicantTooltip and not panel.__lnNoteApplicantTip then
    panel.__lnNoteApplicantTip = true
    local original = panel.OpenApplicantTooltip
    function panel:OpenApplicantTooltip(applicant)
      original(self, applicant)
      local target = self.GameTooltip
      if applicant and applicant.GetName and target then
        local record, matchedName = LookupApplicant(applicant)
        if record then
          AppendNoteLines(target, record, matchedName)
          target:Show()
        end
      end
    end
  end
end

--- 列表项在重绘时可能被集合石清空标记，这里补一次。
local function RepaintExistingRows()
  local panel = GetValue("ApplicantPanel")
  local list = panel and panel.ApplicantList
  if not list or type(list.buttons) ~= "table" then return end
  for _, button in ipairs(list.buttons) do
    if button and button.__lnNoteMarked then
      SetHighlight(button, true)
      SetIcon(button, button.__lnNoteMarkedAnchor, true)
    end
  end
end

local function HookAll()
  if not LN.Config or LN.Config.IsEnabled() then
    HookApplicantClass()
    HookActivityClass()
    HookListItemClass()
    HookOperationGridClass()
    HookApplicantPanel()
    HookBrowsePanel()
    HookMainPanel()
    RepaintExistingRows()
  end
end

--- 有界重试：集合石晚于本插件加载时，最多 8 次、每 2 秒一次。
local function Attempt()
  attemptFrame = nil
  attemptCount = attemptCount + 1
  HookAll()
  if hooked then return end
  if GetValue("ApplicantPanel") and GetValue("MainPanel") then
    hooked = true
    return
  end
  if attemptCount < MAX_ATTEMPTS then Schedule() end
end

function Schedule()
  if hooked or attemptFrame then return end
  if not C_Timer or not C_Timer.After then return end
  attemptFrame = true
  C_Timer.After(ATTEMPT_INTERVAL, Attempt)
end

function Bridge.Initialize()
  HookAll()
  if not hooked then Schedule() end
end

--- 停用时让高亮立即消失；再次启用时重新应用。
function Bridge.Refresh()
  if LN.Config and not LN.Config.IsEnabled() then
    local panel = GetValue("ApplicantPanel")
    local list = panel and panel.ApplicantList
    if list and type(list.buttons) == "table" then
      for _, button in ipairs(list.buttons) do
        if button then
          button.__lnNoteMarked = false
          SetHighlight(button, false)
          SetIcon(button, button.__lnNoteMarkedAnchor, false)
        end
      end
    end
    local browse = GetValue("BrowsePanel") or _G.MeetingStone_BrowsePanel
    if browse and browse.ActivityList and browse.ActivityList.Refresh then
      pcall(browse.ActivityList.Refresh, browse.ActivityList)
    end
    return
  end
  HookAll()
end
