local ADDON_NAME, ns = ...

local MeetingStone = {}
ns.RememberNoobMeetingStone = MeetingStone

local hooked = false

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

local function RefreshMeetingStone()
  if _G.ApplicantPanel and ApplicantPanel.UpdateRememberNoobRejectButton then
    pcall(ApplicantPanel.UpdateRememberNoobRejectButton, ApplicantPanel)
  end
  if _G.ApplicantPanel and ApplicantPanel.UpdateApplicantsList then
    pcall(ApplicantPanel.UpdateApplicantsList, ApplicantPanel)
  end
  if _G.BrowsePanel and BrowsePanel.ActivityList and BrowsePanel.ActivityList.Refresh then
    pcall(BrowsePanel.ActivityList.Refresh, BrowsePanel.ActivityList)
  end
end

function MeetingStone.Refresh()
  RefreshMeetingStone()
end

local function HookApplicantClass()
  local Applicant = _G.Applicant
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
  local Activity = _G.Activity
  if not Activity or Activity.__RememberNoobHooked then return end
  Activity.__RememberNoobHooked = true

  function Activity:GetRememberNoobMatched()
    return ActivityHasNoobLeader(self)
  end
end

local function HookApplicantItem()
  local Addon = _G.Addon
  local ApplicantItem = Addon and Addon.GetClass and Addon:GetClass("ApplicantItem")
  if not ApplicantItem or ApplicantItem.__RememberNoobHooked then return end
  ApplicantItem.__RememberNoobHooked = true

  local oldSetRememberNoobHighlight = ApplicantItem.SetRememberNoobHighlight
  function ApplicantItem:SetRememberNoobHighlight(enable)
    if oldSetRememberNoobHighlight then
      oldSetRememberNoobHighlight(self, enable and GetSetting("highlightNoob"))
    elseif self.noobBg then
      self.noobBg:SetShown(enable and GetSetting("highlightNoob"))
    end
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
  if not _G.ApplicantPanel or ApplicantPanel.__RememberNoobHooked then return end
  ApplicantPanel.__RememberNoobHooked = true

  local oldUpdateRejectButton = ApplicantPanel.UpdateRememberNoobRejectButton
  function ApplicantPanel:UpdateRememberNoobRejectButton()
    if oldUpdateRejectButton then oldUpdateRejectButton(self) end
    if self.RememberNoobRejectButton and not GetSetting("enableOneClickReject") then
      self.RememberNoobRejectButton:Hide()
    end
  end

  local oldDeclineRememberNoobs = ApplicantPanel.DeclineRememberNoobs
  function ApplicantPanel:DeclineRememberNoobs()
    if not GetSetting("enableOneClickReject") then return end
    if oldDeclineRememberNoobs then oldDeclineRememberNoobs(self) end
  end
end

local function HookMainPanel()
  if not _G.MainPanel or MainPanel.__RememberNoobHooked then return end
  MainPanel.__RememberNoobHooked = true

  local oldOpenActivityTooltip = MainPanel.OpenActivityTooltip
  function MainPanel:OpenActivityTooltip(activity, tooltip)
    if oldOpenActivityTooltip then
      oldOpenActivityTooltip(self, activity, tooltip)
    end
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
  if not _G.BrowsePanel or BrowsePanel.__RememberNoobHooked then return end
  BrowsePanel.__RememberNoobHooked = true

  local oldOnInitialize = BrowsePanel.OnInitialize
  function BrowsePanel:OnInitialize(...)
    if oldOnInitialize then oldOnInitialize(self, ...) end
    PatchNoobIconHeader(self.ActivityList)
    PatchLeaderHeader(self.ActivityList)
  end
end

local function HookApplicantPanelList()
  if not _G.ApplicantPanel then return end
  if ApplicantPanel.ApplicantList then
    PatchNoobIconHeader(ApplicantPanel.ApplicantList)
    PatchApplicantNameHeader(ApplicantPanel.ApplicantList)
  end
  if ApplicantPanel.UpdateRememberNoobRejectButton then
    pcall(ApplicantPanel.UpdateRememberNoobRejectButton, ApplicantPanel)
  end
end

local function HookBrowsePanelList()
  if _G.BrowsePanel and BrowsePanel.ActivityList then
    PatchNoobIconHeader(BrowsePanel.ActivityList)
    PatchLeaderHeader(BrowsePanel.ActivityList)
  end
end

local function HookMeetingStone()
  HookApplicantClass()
  HookActivityClass()
  HookApplicantItem()
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
