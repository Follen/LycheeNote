local ADDON_NAME, ns = ...

local MeetingStone = {}
ns.RememberNoobMeetingStone = MeetingStone

local hooked = false

local function GetMeetingStoneEnv()
  local ok, env = pcall(function()
    local lib = LibStub and LibStub("NetEaseEnv-1.0", true)
    return lib and lib._NSList and lib._NSList.MeetingStone
  end)
  if ok then return env end
end

local function GetMeetingStoneValue(key)
  local env = GetMeetingStoneEnv()
  return (env and env[key]) or _G[key]
end

local function GetMeetingStoneAddon()
  return GetMeetingStoneValue("Addon")
end

local function GetMeetingStoneClass(className)
  local addon = GetMeetingStoneAddon()
  if addon and addon.GetClass then
    return addon:GetClass(className)
  end
end

local function GetSetting(key)
  if ns.Config and ns.Config.Get then
    return ns.Config.Get("meetingStone." .. key) == true
  end
  return false
end

local function NormalizeName(name)
  if type(name) ~= "string" or name == "" then return nil end
  local shortName = Ambiguate and Ambiguate(name, "short") or name
  local cleanName = shortName:gsub("%-.*", "")
  if cleanName == "" then return nil end
  return cleanName
end

local function GetNoobRecord(name)
  local cleanName = NormalizeName(name)
  local db = ns.db or RememberNoobDB
  if not cleanName or type(db) ~= "table" or type(db.noobs) ~= "table" then
    return nil
  end
  return db.noobs[cleanName], cleanName
end

local function FindApplicantNoobRecord(applicant)
  if not applicant then return nil end

  if C_LFGList and C_LFGList.GetApplicantMemberInfo and applicant.GetID and applicant.GetNumMembers then
    local id = applicant:GetID()
    local numMembers = applicant:GetNumMembers()
    for index = 1, numMembers or 0 do
      local memberName = C_LFGList.GetApplicantMemberInfo(id, index)
      local record, cleanName = GetNoobRecord(memberName)
      if record then
        return record, cleanName
      end
    end
  end

  if applicant.GetName then
    return GetNoobRecord(applicant:GetName())
  end
end

local function FormatDate(timestamp)
  if type(timestamp) == "number" and timestamp > 0 then
    return date("%Y/%m/%d", timestamp)
  end
  return "未知"
end

local function AddTooltipLines(tooltip, name, record, matchedName)
  if not tooltip or not record then return end
  if tooltip.AddSepatator then tooltip:AddSepatator() end
  tooltip:AddLine("他是个笨蛋" .. (matchedName and ("：" .. matchedName) or ""), 1, 0.1, 0.1)
  tooltip:AddLine("加入时间：" .. FormatDate(record.timestamp), 1, 1, 1)
  tooltip:AddLine("加入理由：" .. (record.reason or "无理由"), 1, 1, 1, true)
end

local function ApplicantHasNoob(applicant)
  if not applicant then return false end
  if applicant.GetRememberNoobMatched then
    return applicant:GetRememberNoobMatched()
  end
  return FindApplicantNoobRecord(applicant) ~= nil
end

local function ActivityHasNoobLeader(activity)
  if not activity or not activity.GetLeader then return false end
  return GetNoobRecord(activity:GetLeader()) ~= nil
end

local function SetRejectButtonState(panel)
  if not panel or not panel.RememberNoobRejectButton then return end
  if GetSetting("enableOneClickReject") then
    panel.RememberNoobRejectButton:Show()
  else
    panel.RememberNoobRejectButton:Hide()
  end
end

local function ApplyOperationNoobIcon(grid)
  if not grid or not grid.RememberNoobLogo then return end
  if not GetSetting("showIcon") then
    grid.RememberNoobLogo:Hide()
  elseif grid.RememberNoobLogo.isRememberNoob then
    grid.RememberNoobLogo:Show()
  end
end

local function RefreshMeetingStone()
  local applicantPanel = GetMeetingStoneValue("ApplicantPanel")
  local managerPanel = GetMeetingStoneValue("ManagerPanel")
  local browsePanel = GetMeetingStoneValue("BrowsePanel") or _G.MeetingStone_BrowsePanel

  if applicantPanel and applicantPanel.UpdateRememberNoobRejectButton then
    pcall(applicantPanel.UpdateRememberNoobRejectButton, applicantPanel)
  end
  SetRejectButtonState(applicantPanel)
  SetRejectButtonState(managerPanel)

  if applicantPanel and applicantPanel.UpdateApplicantsList then
    pcall(applicantPanel.UpdateApplicantsList, applicantPanel)
  end
  SetRejectButtonState(applicantPanel)
  SetRejectButtonState(managerPanel)

  if browsePanel and browsePanel.ActivityList and browsePanel.ActivityList.Refresh then
    pcall(browsePanel.ActivityList.Refresh, browsePanel.ActivityList)
  end

  local applicantList = applicantPanel and applicantPanel.ApplicantList
  if applicantList and applicantList.Refresh then
    pcall(applicantList.Refresh, applicantList)
  end

  if applicantList and type(applicantList.buttons) == "table" then
    for _, button in ipairs(applicantList.buttons) do
      if button and button.Option then
        ApplyOperationNoobIcon(button.Option)
      end
      if button and button.noobBg and not GetSetting("highlightNoob") then
        button.noobBg:Hide()
      end
    end
  end
end

function MeetingStone.Refresh()
  RefreshMeetingStone()
end

local function HookApplicantClass()
  local Applicant = GetMeetingStoneValue("Applicant")
  if not Applicant or Applicant.__RememberNoobHooked then return end
  Applicant.__RememberNoobHooked = true

  local oldGetRememberNoobMatched = Applicant.GetRememberNoobMatched
  function Applicant:GetRememberNoobMatched()
    if oldGetRememberNoobMatched then
      return oldGetRememberNoobMatched(self)
    end
    return FindApplicantNoobRecord(self) ~= nil
  end

  local oldGetRememberNoobName = Applicant.GetRememberNoobName
  function Applicant:GetRememberNoobName()
    if oldGetRememberNoobName then
      return oldGetRememberNoobName(self)
    end
    local _, cleanName = FindApplicantNoobRecord(self)
    return cleanName
  end

  local oldGetRememberNoobReason = Applicant.GetRememberNoobReason
  function Applicant:GetRememberNoobReason()
    if oldGetRememberNoobReason then
      return oldGetRememberNoobReason(self)
    end
    local record = FindApplicantNoobRecord(self)
    return record and record.reason
  end

  local oldGetRememberNoobTimestamp = Applicant.GetRememberNoobTimestamp
  function Applicant:GetRememberNoobTimestamp()
    if oldGetRememberNoobTimestamp then
      return oldGetRememberNoobTimestamp(self)
    end
    local record = FindApplicantNoobRecord(self)
    return record and record.timestamp
  end
end

local function HookActivityClass()
  local Activity = GetMeetingStoneValue("Activity")
  if not Activity or Activity.__RememberNoobHooked then return end
  Activity.__RememberNoobHooked = true

  function Activity:GetRememberNoobMatched()
    return ActivityHasNoobLeader(self)
  end
end

local function HookApplicantItem()
  local ApplicantItem = GetMeetingStoneClass("ApplicantItem")
  if not ApplicantItem or ApplicantItem.__RememberNoobSetHighlightHooked or not ApplicantItem.SetRememberNoobHighlight then return end
  ApplicantItem.__RememberNoobSetHighlightHooked = true

  local oldSetRememberNoobHighlight = ApplicantItem.SetRememberNoobHighlight
  function ApplicantItem:SetRememberNoobHighlight(enable)
    oldSetRememberNoobHighlight(self, enable and GetSetting("highlightNoob"))
    if self.noobBg and not GetSetting("highlightNoob") then
      self.noobBg:Hide()
    end
  end
end

local function HookOperationGrid()
  local OperationGrid = GetMeetingStoneClass("OperationGrid")
  if not OperationGrid or OperationGrid.__RememberNoobOperationHooked then return end
  if not OperationGrid.SetMember or not OperationGrid.SetSpinner or not OperationGrid.SetText then return end
  OperationGrid.__RememberNoobOperationHooked = true

  local oldSetMember = OperationGrid.SetMember
  function OperationGrid:SetMember(...)
    oldSetMember(self, ...)
    ApplyOperationNoobIcon(self)
  end

  local oldSetSpinner = OperationGrid.SetSpinner
  function OperationGrid:SetSpinner(...)
    oldSetSpinner(self, ...)
    ApplyOperationNoobIcon(self)
  end

  local oldSetText = OperationGrid.SetText
  function OperationGrid:SetText(...)
    oldSetText(self, ...)
    ApplyOperationNoobIcon(self)
  end
end

local function PatchNoobIconHeader(list)
  if not list or list.__RememberNoobIconPatched or type(list.sortButtons) ~= "table" then return end
  for _, header in ipairs(list.sortButtons) do
    if header.key == "Icon" or header.key == "@" then
      local oldIconHandler = header.iconHandler
      header.iconHandler = function(data)
        if data and GetSetting("showIcon") and ((data.GetRememberNoobMatched and data:GetRememberNoobMatched()) or ActivityHasNoobLeader(data)) then
          return [[Interface\TargetingFrame\UI-RaidTargetingIcon_8]]
        end
        if oldIconHandler then
          return oldIconHandler(data)
        end
      end
      list.__RememberNoobIconPatched = true
      return
    end
  end
end

local function PatchLeaderHeader(list)
  if not list or list.__RememberNoobLeaderPatched or type(list.sortButtons) ~= "table" then return end
  for _, header in ipairs(list.sortButtons) do
    if header.key == "Leader" and header.showHandler then
      local oldShowHandler = header.showHandler
      header.showHandler = function(activity)
        local text, r, g, b = oldShowHandler(activity)
        if GetSetting("highlightNoob") and ActivityHasNoobLeader(activity) then
          return text, 1, 0.1, 0.1
        end
        return text, r, g, b
      end
      list.__RememberNoobLeaderPatched = true
      return
    end
  end
end

local function PatchApplicantNameHeader(list)
  if not list or list.__RememberNoobNamePatched or type(list.sortButtons) ~= "table" then return end
  for _, header in ipairs(list.sortButtons) do
    if header.key == "Name" and header.showHandler then
      local oldShowHandler = header.showHandler
      header.showHandler = function(applicant)
        local text, r, g, b = oldShowHandler(applicant)
        if GetSetting("highlightNoob") and ApplicantHasNoob(applicant) then
          return text, 1, 0.1, 0.1
        end
        return text, r, g, b
      end
      list.__RememberNoobNamePatched = true
      return
    end
  end
end

local function HookApplicantPanel()
  local ApplicantPanel = GetMeetingStoneValue("ApplicantPanel")
  local ManagerPanel = GetMeetingStoneValue("ManagerPanel")
  if not ApplicantPanel then return end

  if ApplicantPanel.UpdateRememberNoobRejectButton and not ApplicantPanel.__RememberNoobUpdateRejectHooked then
    ApplicantPanel.__RememberNoobUpdateRejectHooked = true
    local oldUpdateRejectButton = ApplicantPanel.UpdateRememberNoobRejectButton
    function ApplicantPanel:UpdateRememberNoobRejectButton()
      oldUpdateRejectButton(self)
      SetRejectButtonState(self)
      SetRejectButtonState(ManagerPanel)
    end
  end

  if ApplicantPanel.DeclineRememberNoobs and not ApplicantPanel.__RememberNoobDeclineHooked then
    ApplicantPanel.__RememberNoobDeclineHooked = true
    local oldDeclineRememberNoobs = ApplicantPanel.DeclineRememberNoobs
    function ApplicantPanel:DeclineRememberNoobs()
      if not GetSetting("enableOneClickReject") then return end
      oldDeclineRememberNoobs(self)
    end
  end

  SetRejectButtonState(ApplicantPanel)
  SetRejectButtonState(ManagerPanel)
end

local function HookMainPanel()
  local MainPanel = GetMeetingStoneValue("MainPanel")
  if not MainPanel or MainPanel.__RememberNoobActivityTooltipHooked or not MainPanel.OpenActivityTooltip then return end
  MainPanel.__RememberNoobActivityTooltipHooked = true

  local oldOpenActivityTooltip = MainPanel.OpenActivityTooltip
  function MainPanel:OpenActivityTooltip(activity, tooltip)
    oldOpenActivityTooltip(self, activity, tooltip)
    local targetTooltip = tooltip or self.GameTooltip
    if activity and activity.GetLeader then
      local record, cleanName = GetNoobRecord(activity:GetLeader())
      if record and targetTooltip then
        AddTooltipLines(targetTooltip, activity:GetLeader(), record, cleanName)
        targetTooltip:Show()
      end
    end
  end
end

local function HookBrowsePanel()
  local BrowsePanel = GetMeetingStoneValue("BrowsePanel") or _G.MeetingStone_BrowsePanel
  if not BrowsePanel or BrowsePanel.__RememberNoobInitializeHooked or not BrowsePanel.OnInitialize then return end
  BrowsePanel.__RememberNoobInitializeHooked = true

  local oldOnInitialize = BrowsePanel.OnInitialize
  function BrowsePanel:OnInitialize(...)
    oldOnInitialize(self, ...)
    PatchNoobIconHeader(self.ActivityList)
    PatchLeaderHeader(self.ActivityList)
  end
end

local function HookApplicantPanelList()
  local ApplicantPanel = GetMeetingStoneValue("ApplicantPanel")
  if not ApplicantPanel then return end
  if ApplicantPanel.ApplicantList then
    PatchNoobIconHeader(ApplicantPanel.ApplicantList)
    PatchApplicantNameHeader(ApplicantPanel.ApplicantList)
  end
  if ApplicantPanel.UpdateRememberNoobRejectButton then
    pcall(ApplicantPanel.UpdateRememberNoobRejectButton, ApplicantPanel)
  end
end

local function HookBrowsePanelList()
  local BrowsePanel = GetMeetingStoneValue("BrowsePanel") or _G.MeetingStone_BrowsePanel
  if BrowsePanel and BrowsePanel.ActivityList then
    PatchNoobIconHeader(BrowsePanel.ActivityList)
    PatchLeaderHeader(BrowsePanel.ActivityList)
  end
end

local function HookMeetingStone()
  HookApplicantClass()
  HookActivityClass()
  HookApplicantItem()
  HookOperationGrid()
  HookApplicantPanel()
  HookMainPanel()
  HookBrowsePanel()
  HookApplicantPanelList()
  HookBrowsePanelList()
  RefreshMeetingStone()
end

function MeetingStone.Initialize()
  if hooked then return end
  hooked = true

  local frame = CreateFrame("Frame")
  frame:RegisterEvent("ADDON_LOADED")
  frame:RegisterEvent("PLAYER_LOGIN")
  frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName ~= "MeetingStone" then return end
    HookMeetingStone()
    C_Timer.After(0, HookMeetingStone)
    C_Timer.After(1, HookMeetingStone)
  end)

  HookMeetingStone()
end

function MeetingStone:OnInitialize()
  HookMeetingStone()
  if C_Timer then
    C_Timer.After(0, HookMeetingStone)
  end
end

if ns.RegisterModule then
  ns.RegisterModule("MeetingStone", MeetingStone)
end

MeetingStone.Initialize()
