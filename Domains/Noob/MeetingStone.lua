local ADDON_NAME, ns = ...

local MeetingStone = {}
ns.RememberNoobMeetingStone = MeetingStone

local hooked = false
local filterLogEnabled = false
local filterLogRecords = {}
local filterLogLines = {}
local filterLogDisplayLines = {}
local filterLogSeen = {}
local filterLogHeader = "时间\t活动分类\t活动类型\t活动名称\t活动标题\t团长\t说明"
local filterLogDisplayHeader = "时间 | 活动分类 | 活动类型 | 活动名称 | 活动标题 | 团长 | 说明"
local filterLogLimit = 2000
local filterLogNotifyPending = false
local filterLogScanToken = 0
local debugSearchCategoryID = 121
local debugSearchBaseFilter = Enum and Enum.LFGListFilter and Enum.LFGListFilter.PvE or 1
local debugLogStatus = "待搜索"
local debugSearchQueue = nil
local debugSearchQueueIndex = 0
local debugSearchActive = false

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

local function NotifyFilterLogChanged()
  if ns.RememberNoobUI and ns.RememberNoobUI.RefreshDebugLogPanel then
    ns.RememberNoobUI.RefreshDebugLogPanel()
  end
end

local function ScheduleFilterLogChanged()
  if filterLogNotifyPending then return end
  filterLogNotifyPending = true
  if C_Timer and C_Timer.After then
    C_Timer.After(0.1, function()
      filterLogNotifyPending = false
      NotifyFilterLogChanged()
    end)
  else
    filterLogNotifyPending = false
    NotifyFilterLogChanged()
  end
end

local function CleanLogValue(value)
  if value == nil then return "" end
  value = tostring(value)
  value = value:gsub("[\r\n\t]+", " ")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")
  return value
end

local function EscapeLuaString(value)
  value = CleanLogValue(value)
  value = value:gsub("\\", "\\\\")
  value = value:gsub("\"", "\\\"")
  return value
end

local function SafeCFunction(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, result = pcall(fn, ...)
  if ok then return result end
end

local function GetSearchResultActivityID(info)
  if not info then return nil end
  if info.activityID then return info.activityID end
  if info.activityIDs then
    local ok, activityID = pcall(function() return info.activityIDs[1] end)
    if ok then return activityID end
  end
end

local function GetActivityInfo(activityID)
  if not activityID or not C_LFGList or not C_LFGList.GetActivityInfoTable then return nil end
  local info = SafeCFunction(C_LFGList.GetActivityInfoTable, activityID)
  if type(info) == "table" then return info end
end

local function GetActivityCategoryFromInfo(activityInfo)
  if type(activityInfo) ~= "table" then return "" end
  local categoryID = activityInfo.categoryID or activityInfo.groupFinderCategoryID
  if categoryID and C_LFGList and C_LFGList.GetLfgCategoryInfo then
    return SafeCFunction(C_LFGList.GetLfgCategoryInfo, categoryID) or ""
  end
  return ""
end

local function GetActivityGroupName(activityInfo)
  if type(activityInfo) ~= "table" then return "" end
  local groupID = activityInfo.groupFinderActivityGroupID
  if groupID and C_LFGList and C_LFGList.GetActivityGroupInfo then
    local value = SafeCFunction(C_LFGList.GetActivityGroupInfo, groupID)
    if type(value) == "table" and value.name then
      return value.name
    end
    return value or ""
  end
  return ""
end

local function GetActivityCategoryNameFromActivity(activity, activityInfo)
  if not activity then return "" end
  local getter = activity.GetCategoryName or activity.GetActivityCategoryName
  if getter then
    local ok, value = pcall(getter, activity)
    if ok and value then
      return value
    end
  end
  if type(activityInfo) == "table" then
    local categoryID = activityInfo.categoryID or activityInfo.groupFinderCategoryID
    if categoryID and C_LFGList and C_LFGList.GetLfgCategoryInfo then
      local categoryInfo = SafeCFunction(C_LFGList.GetLfgCategoryInfo, categoryID)
      if type(categoryInfo) == "table" and categoryInfo.name then
        return categoryInfo.name
      elseif type(categoryInfo) == "string" then
        return categoryInfo
      end
    end
  end
  return ""
end

local function GetActivityTypeName(activity, activityInfo)
  if not activity then return "" end
  local getter = activity.GetShortName or activity.GetModeText
  if getter then
    local ok, value = pcall(getter, activity)
    if ok and value and value ~= "" then
      return value
    end
  end
  if type(activityInfo) == "table" then
    local groupName = GetActivityGroupName(activityInfo)
    if groupName ~= "" then
      return groupName
    end
    if activityInfo.shortName then
      return activityInfo.shortName
    end
  end
  return ""
end

local function ClearMeetingStoneSearchText()
  if C_LFGList and C_LFGList.ClearSearchTextFields then
    pcall(C_LFGList.ClearSearchTextFields)
  end
  local browsePanel = GetMeetingStoneValue("BrowsePanel") or _G.MeetingStone_BrowsePanel
  local searchBox = browsePanel and browsePanel.SearchBox
  if searchBox and searchBox.SetText then
    pcall(searchBox.SetText, searchBox, "")
  end
  if searchBox and searchBox.ClearFocus then
    pcall(searchBox.ClearFocus, searchBox)
  end
end

local function BuildFilterLogRecordFromActivity(activity)
  if not activity then return nil end
  local resultID = SafeCFunction(activity.GetID, activity)
  local activityID = SafeCFunction(activity.GetActivityID, activity)
  local activityInfo = GetActivityInfo(activityID)
  return {
    resultID = resultID,
    time = date("%Y-%m-%d %H:%M:%S"),
    category = CleanLogValue(GetActivityCategoryNameFromActivity(activity, activityInfo)),
    activityType = CleanLogValue(GetActivityTypeName(activity, activityInfo)),
    activityName = CleanLogValue(SafeCFunction(activity.GetName, activity) or ""),
    title = CleanLogValue(SafeCFunction(activity.GetSummary, activity) or ""),
    leader = CleanLogValue(SafeCFunction(activity.GetLeader, activity) or ""),
    comment = CleanLogValue(SafeCFunction(activity.GetComment, activity) or ""),
  }
end

local function BuildFilterLogLineFromRecord(record, separator)
  if not record then return nil end
  separator = separator or "\t"
  return table.concat({
    record.time or "",
    record.category or "",
    record.activityType or "",
    record.activityName or "",
    record.title or "",
    record.leader or "",
    record.comment or "",
  }, separator)
end

local function BuildFilterLogSavedVariables()
  local lines = {"RememberNoobMeetingStoneFilterLog = {"}
  for index, record in ipairs(filterLogRecords) do
    lines[#lines + 1] = "  [" .. index .. "] = {"
    if record.resultID then
      lines[#lines + 1] = "    resultID = " .. tostring(record.resultID) .. ","
    end
    lines[#lines + 1] = "    time = \"" .. EscapeLuaString(record.time) .. "\","
    lines[#lines + 1] = "    category = \"" .. EscapeLuaString(record.category) .. "\","
    lines[#lines + 1] = "    activityType = \"" .. EscapeLuaString(record.activityType) .. "\","
    lines[#lines + 1] = "    activityName = \"" .. EscapeLuaString(record.activityName) .. "\","
    lines[#lines + 1] = "    title = \"" .. EscapeLuaString(record.title) .. "\","
    lines[#lines + 1] = "    leader = \"" .. EscapeLuaString(record.leader) .. "\","
    lines[#lines + 1] = "    comment = \"" .. EscapeLuaString(record.comment) .. "\","
    lines[#lines + 1] = "  },"
  end
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

local function AddFilterLogActivity(activity)
  local record = BuildFilterLogRecordFromActivity(activity)
  if not record then return false end
  local code = SafeCFunction(activity.GetCode, activity) or
    (record.leader .. ":" .. record.title .. ":" .. record.activityName)
  local key = tostring(record.resultID or code)
  if filterLogSeen[key] then return false end

  filterLogSeen[key] = true
  filterLogRecords[#filterLogRecords + 1] = record
  local line = BuildFilterLogLineFromRecord(record, "\t")
  local displayLine = BuildFilterLogLineFromRecord(record, " | ")
  filterLogLines[#filterLogLines + 1] = line
  filterLogDisplayLines[#filterLogDisplayLines + 1] = displayLine or line:gsub("\t", " | ")
  if #filterLogLines > filterLogLimit then
    local removed = table.remove(filterLogLines, 1)
    table.remove(filterLogRecords, 1)
    table.remove(filterLogDisplayLines, 1)
    if removed then
      for seenKey in pairs(filterLogSeen) do
        if seenKey:find(removed, 1, true) then
          filterLogSeen[seenKey] = nil
          break
        end
      end
    end
  end
  return true
end

local function ResetFilterLog()
  table.wipe(filterLogRecords)
  table.wipe(filterLogLines)
  table.wipe(filterLogDisplayLines)
  table.wipe(filterLogSeen)
  debugLogStatus = "待搜索"
end

local function RecordCurrentSearchResults()
  if not filterLogEnabled then return end
  local lfgService = GetMeetingStoneValue("LfgService")
  local activities = lfgService and lfgService.GetActivityList and lfgService:GetActivityList()
  if type(activities) ~= "table" then
    debugLogStatus = "结果: 0"
    NotifyFilterLogChanged()
    return
  end

  debugLogStatus = "结果: " .. #activities

  filterLogScanToken = filterLogScanToken + 1
  local token = filterLogScanToken
  local index = 1
  local batchSize = 20

  local function ScanBatch()
    if token ~= filterLogScanToken or not filterLogEnabled then return end
    local changed = false
    local batchEnd = math.min(index + batchSize - 1, #activities)
    for i = index, batchEnd do
      changed = AddFilterLogActivity(activities[i]) or changed
    end
    if changed then ScheduleFilterLogChanged() end
    index = batchEnd + 1
    if index <= #activities and C_Timer and C_Timer.After then
      C_Timer.After(0, ScanBatch)
    end
  end

  ScanBatch()
end

local function StartDebugSearch(plan, statusText)
  debugSearchQueue = plan or nil
  debugSearchQueueIndex = 0
  debugSearchActive = debugSearchQueue ~= nil and #debugSearchQueue > 0
  if filterLogEnabled then
    filterLogScanToken = filterLogScanToken + 1
  end
  if statusText and statusText ~= "" then
    debugLogStatus = statusText
  end
  NotifyFilterLogChanged()
end

local function ContinueDebugSearch()
  if not debugSearchActive or not debugSearchQueue then
    debugSearchActive = false
    return
  end

  debugSearchQueueIndex = debugSearchQueueIndex + 1
  local step = debugSearchQueue[debugSearchQueueIndex]
  if not step then
    debugSearchActive = false
    debugSearchQueue = nil
    debugLogStatus = "完成: " .. tostring(#filterLogLines)
    NotifyFilterLogChanged()
    return
  end

  debugSearchCategoryID = step.categoryID or debugSearchCategoryID
  debugSearchBaseFilter = step.baseFilter or debugSearchBaseFilter
  debugLogStatus = "搜索中: " .. tostring(step.label or debugSearchCategoryID)
  NotifyFilterLogChanged()
  ClearMeetingStoneSearchText()

  local lfgService = GetMeetingStoneValue("LfgService")
  if lfgService and lfgService.Search then
    lfgService:Search(debugSearchCategoryID, debugSearchBaseFilter, step.activityID)
  elseif C_LFGList and C_LFGList.Search then
    local languages = C_LFGList.GetLanguageSearchFilter and C_LFGList.GetLanguageSearchFilter()
    local advancedFilter = debugSearchCategoryID == 2 and C_LFGList.GetAdvancedFilter and C_LFGList.GetAdvancedFilter()
    local filterValue = 0
    if debugSearchCategoryID == 2 and Enum and Enum.LFGListFilter and bit then
      filterValue = bit.band(bit.bnot(Enum.LFGListFilter.NotRecommended), Enum.LFGListFilter.Recommended)
    end
    pcall(C_LFGList.Search, debugSearchCategoryID, filterValue, debugSearchBaseFilter or 0, languages, nil, advancedFilter)
  end
end

function MeetingStone.SearchDebugCategory(categoryOrItem, baseFilter)
  local item = type(categoryOrItem) == "table" and categoryOrItem or nil
  local categoryID = item and item.categoryID or categoryOrItem
  local label = item and item.text or tostring(categoryID)

  ResetFilterLog()

  if item and item.searchPlan and type(item.searchPlan) == "table" then
    StartDebugSearch(item.searchPlan, "搜索中: " .. label)
    ContinueDebugSearch()
    return true
  end

  debugSearchCategoryID = categoryID or debugSearchCategoryID
  debugSearchBaseFilter = baseFilter or (item and item.baseFilter) or debugSearchBaseFilter
  StartDebugSearch(nil, "搜索中: " .. tostring(label))
  debugSearchActive = false
  ClearMeetingStoneSearchText()

  local lfgService = GetMeetingStoneValue("LfgService")
  if lfgService and lfgService.Search then
    local ok, err = pcall(lfgService.Search, lfgService, debugSearchCategoryID, debugSearchBaseFilter, item and item.activityID or nil)
    if not ok then
      debugLogStatus = "搜索失败: " .. tostring(err)
      NotifyFilterLogChanged()
      return false
    end
    return true
  end

  if C_LFGList and C_LFGList.Search then
    local languages = C_LFGList.GetLanguageSearchFilter and C_LFGList.GetLanguageSearchFilter()
    local advancedFilter = debugSearchCategoryID == 2 and C_LFGList.GetAdvancedFilter and C_LFGList.GetAdvancedFilter()
    local filterValue = 0
    if debugSearchCategoryID == 2 and Enum and Enum.LFGListFilter and bit then
      filterValue = bit.band(bit.bnot(Enum.LFGListFilter.NotRecommended), Enum.LFGListFilter.Recommended)
    end
    local ok, err = pcall(C_LFGList.Search, debugSearchCategoryID, filterValue, debugSearchBaseFilter or 0, languages, nil, advancedFilter)
    if not ok then
      debugLogStatus = "搜索失败: " .. tostring(err)
      NotifyFilterLogChanged()
      return false
    end
    return true
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

local function CanDeclineApplicant(applicant)
  if not applicant or not applicant.GetStatus then return false end
  local status = applicant:GetStatus()
  return status == "applied" or status == "invited"
end

local function GetRememberNoobApplicantIDs(applicants)
  local ids = {}
  local seen = {}
  for _, applicant in ipairs(applicants or {}) do
    local id = applicant.GetID and applicant:GetID()
    if id and CanDeclineApplicant(applicant) and ApplicantHasNoob(applicant) and not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  return ids
end

local function EnsureNoobBackground(button)
  if not button then return nil end
  if button.noobBg then return button.noobBg end

  local noobBg = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  noobBg:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -1)
  noobBg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
  noobBg:SetColorTexture(0.85, 0.05, 0.05)
  noobBg:SetAlpha(0.28)
  noobBg:Hide()
  button.noobBg = noobBg
  return noobBg
end

local function SetButtonNoobHighlight(button, enable, endButton)
  local noobBg = EnsureNoobBackground(button)
  if not noobBg then return end

  local shown = enable and GetSetting("highlightNoob") or false
  button.rememberNoobHighlight = shown

  noobBg:ClearAllPoints()
  noobBg:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -1)
  if endButton then
    noobBg:SetPoint("BOTTOMRIGHT", endButton, "BOTTOMRIGHT", 0, 1)
  else
    noobBg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 1)
  end
  noobBg:SetColorTexture(0.85, 0.05, 0.05)
  noobBg:SetAlpha(0.28)
  noobBg:SetShown(shown)
end

local function SetRejectButtonState(panel)
  if not panel or not panel.RememberNoobRejectButton then return end
  if GetSetting("enableOneClickReject") then
    panel.RememberNoobRejectButton:Show()
  else
    panel.RememberNoobRejectButton:Hide()
  end
end

local function SkinRejectButton(button)
  if not button or button.__RememberNoobSkinned then return end

  local elv = _G.ElvUI and _G.ElvUI[1]
  local elvSkins = elv and elv.GetModule and elv:GetModule("Skins", true)
  if elvSkins and elvSkins.ESProxy then
    pcall(elvSkins.ESProxy, elvSkins, "HandleButton", button, nil, nil, nil, true, "Transparent")
    if button.backdrop and button.backdrop.ClearAllPoints and button.backdrop.SetOutside then
      button.backdrop:ClearAllPoints()
      button.backdrop:SetOutside(button, -1, -2)
    end
    button.__RememberNoobSkinned = true
    return
  end

  local nd = _G.NDui
  local ndSkin = nd and nd[1]
  if ndSkin and ndSkin.Reskin then
    pcall(ndSkin.Reskin, button)
    button.__RememberNoobSkinned = true
    return
  end

  button.__RememberNoobSkinned = true
end

local function CreateRejectButton(applicantPanel, managerPanel)
  if not applicantPanel or not managerPanel or applicantPanel.RememberNoobRejectButton then return end
  if not managerPanel.RefreshButton then return end

  local RefreshButton = GetMeetingStoneClass("RefreshButton")
  local button = RefreshButton and RefreshButton.New and RefreshButton:New(managerPanel) or
    CreateFrame("Button", nil, managerPanel, "UIMenuButtonStretchTemplate")

  button:SetSize(92, 28)
  button:SetPoint("TOPRIGHT", managerPanel.RefreshButton, "TOPLEFT", -6, 0)
  button:SetNormalFontObject("GameFontNormal")
  button:SetHighlightFontObject("GameFontHighlight")
  button:SetDisabledFontObject("GameFontDisable")
  if button.Icon then button.Icon:Hide() end
  local label = button.GetFontString and button:GetFontString()
  if label then
    label:ClearAllPoints()
    label:SetPoint("CENTER", button, "CENTER", 0, 0)
  end
  button:SetScript("OnClick", function()
    if applicantPanel.DeclineRememberNoobs then
      applicantPanel:DeclineRememberNoobs()
    end
  end)

  applicantPanel.RememberNoobRejectButton = button
  managerPanel.RememberNoobRejectButton = button
  SkinRejectButton(button)
  SetRejectButtonState(applicantPanel)
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

function MeetingStone.IsFilterLogEnabled()
  return filterLogEnabled
end

function MeetingStone.SetFilterLogEnabled(enabled)
  filterLogEnabled = enabled and true or false
  if filterLogEnabled then
    RecordCurrentSearchResults()
  else
    filterLogScanToken = filterLogScanToken + 1
  end
  NotifyFilterLogChanged()
end

function MeetingStone.ToggleFilterLog()
  MeetingStone.SetFilterLogEnabled(not filterLogEnabled)
  return filterLogEnabled
end

function MeetingStone.GetFilterLogText()
  return BuildFilterLogSavedVariables()
end

function MeetingStone.GetFilterLogDisplayText()
  return BuildFilterLogSavedVariables()
end

function MeetingStone.GetFilterLogCount()
  return #filterLogLines
end

function MeetingStone.GetFilterLogDisplayRows()
  local rows = {}
  for line in BuildFilterLogSavedVariables():gmatch("[^\n]+") do
    rows[#rows + 1] = line
  end
  return rows
end

function MeetingStone.GetFilterLogStatus()
  return debugLogStatus
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
  if not ApplicantItem then return end

  if ApplicantItem.Constructor and not ApplicantItem.__RememberNoobConstructorHooked then
    ApplicantItem.__RememberNoobConstructorHooked = true
    local oldConstructor = ApplicantItem.Constructor
    function ApplicantItem:Constructor(...)
      oldConstructor(self, ...)
      EnsureNoobBackground(self)
    end
  end

  if ApplicantItem.SetAlpha and not ApplicantItem.__RememberNoobSetAlphaHooked then
    ApplicantItem.__RememberNoobSetAlphaHooked = true
    local oldSetAlpha = ApplicantItem.SetAlpha
    function ApplicantItem:SetAlpha(alpha, button)
      oldSetAlpha(self, alpha, button)
      SetButtonNoobHighlight(self, self.rememberNoobHighlight, button)
    end
  end

  if ApplicantItem.SetBackground and not ApplicantItem.__RememberNoobSetBackgroundHooked then
    ApplicantItem.__RememberNoobSetBackgroundHooked = true
    local oldSetBackground = ApplicantItem.SetBackground
    function ApplicantItem:SetBackground(enable)
      oldSetBackground(self, enable)
      SetButtonNoobHighlight(self, self.rememberNoobHighlight)
    end
  end

  if not ApplicantItem.__RememberNoobSetHighlightHooked then
    ApplicantItem.__RememberNoobSetHighlightHooked = true
    local oldSetRememberNoobHighlight = ApplicantItem.SetRememberNoobHighlight
    function ApplicantItem:SetRememberNoobHighlight(enable)
      if oldSetRememberNoobHighlight then
        oldSetRememberNoobHighlight(self, enable and GetSetting("highlightNoob"))
      end
      SetButtonNoobHighlight(self, enable)
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

local function PatchNoobIconHeader(list, preferredKey)
  if not list or list.__RememberNoobIconPatched or type(list.sortButtons) ~= "table" then return end
  for _, header in ipairs(list.sortButtons) do
    if (preferredKey and header.key == preferredKey) or (not preferredKey and (header.key == "Icon" or header.key == "@")) then
      if preferredKey == "starTarget" and header.SetText then
        header:SetText("RN评价")
      end
      local oldIconHandler = header.iconHandler
      header.iconHandler = function(data)
        if data and GetSetting("showIcon") and ((data.GetRememberNoobMatched and data:GetRememberNoobMatched()) or ActivityHasNoobLeader(data)) then
          return [[Interface\TargetingFrame\UI-RaidTargetingIcon_8]], nil, nil, nil, nil, 18, 18
        end
        if preferredKey == "starTarget" then return nil end
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

local function HookApplicantPanel()
  local ApplicantPanel = GetMeetingStoneValue("ApplicantPanel")
  local ManagerPanel = GetMeetingStoneValue("ManagerPanel")
  if not ApplicantPanel then return end

  CreateRejectButton(ApplicantPanel, ManagerPanel)

  if not ApplicantPanel.__RememberNoobUpdateRejectHooked then
    ApplicantPanel.__RememberNoobUpdateRejectHooked = true
    local oldUpdateRejectButton = ApplicantPanel.UpdateRememberNoobRejectButton
    function ApplicantPanel:UpdateRememberNoobRejectButton()
      if oldUpdateRejectButton then
        oldUpdateRejectButton(self)
      end
      if self.RememberNoobRejectButton then
        local count = #GetRememberNoobApplicantIDs(self.ApplicantList and self.ApplicantList:GetItemList())
        self.RememberNoobRejectButton:SetEnabled(count > 0)
        self.RememberNoobRejectButton:SetText(count > 0 and ("拒绝笨蛋(" .. count .. ")") or "拒绝笨蛋")
      end
      SetRejectButtonState(self)
      SetRejectButtonState(ManagerPanel)
    end
  end

  if ApplicantPanel.UpdateApplicantsList and not ApplicantPanel.__RememberNoobUpdateApplicantsHooked then
    ApplicantPanel.__RememberNoobUpdateApplicantsHooked = true
    local oldUpdateApplicantsList = ApplicantPanel.UpdateApplicantsList
    function ApplicantPanel:UpdateApplicantsList(...)
      oldUpdateApplicantsList(self, ...)
      if self.UpdateRememberNoobRejectButton then
        self:UpdateRememberNoobRejectButton()
      end
    end
  end

  if not ApplicantPanel.__RememberNoobDeclineHooked then
    ApplicantPanel.__RememberNoobDeclineHooked = true
    local oldDeclineRememberNoobs = ApplicantPanel.DeclineRememberNoobs
    function ApplicantPanel:DeclineRememberNoobs()
      if not GetSetting("enableOneClickReject") then return end
      if oldDeclineRememberNoobs then
        oldDeclineRememberNoobs(self)
        return
      end

      for _, id in ipairs(GetRememberNoobApplicantIDs(self.ApplicantList and self.ApplicantList:GetItemList())) do
        local info = C_LFGList.GetApplicantInfo(id)
        if info and self.Decline then
          self:Decline(id, info.applicationStatus)
        end
      end
      if self.UpdateApplicantsList then
        self:UpdateApplicantsList()
      end
    end
  end

  if not ApplicantPanel.__RememberNoobApplicantUpdatedHooked and ApplicantPanel.LFG_LIST_APPLICANT_UPDATED then
    ApplicantPanel.__RememberNoobApplicantUpdatedHooked = true
    local oldApplicantUpdated = ApplicantPanel.LFG_LIST_APPLICANT_UPDATED
    function ApplicantPanel:LFG_LIST_APPLICANT_UPDATED(...)
      oldApplicantUpdated(self, ...)
      if self.UpdateRememberNoobRejectButton then
        self:UpdateRememberNoobRejectButton()
      end
    end
  end

  SetRejectButtonState(ApplicantPanel)
  SetRejectButtonState(ManagerPanel)
end

local function HookMainPanel()
  local MainPanel = GetMeetingStoneValue("MainPanel")
  if not MainPanel then return end

  if MainPanel.OpenActivityTooltip and not MainPanel.__RememberNoobActivityTooltipHooked then
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

  if MainPanel.OpenApplicantTooltip and not MainPanel.__RememberNoobApplicantTooltipHooked then
    MainPanel.__RememberNoobApplicantTooltipHooked = true
    local oldOpenApplicantTooltip = MainPanel.OpenApplicantTooltip
    function MainPanel:OpenApplicantTooltip(applicant)
      oldOpenApplicantTooltip(self, applicant)
      local targetTooltip = self.GameTooltip
      if applicant and applicant.GetName and targetTooltip then
        local record, cleanName = FindApplicantNoobRecord(applicant)
        if record then
          AddTooltipLines(targetTooltip, applicant:GetName(), record, cleanName)
          targetTooltip:Show()
        end
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

  local function HookResultHandler(methodName, advanceQueue)
    local flagName = "__RememberNoob" .. methodName .. "Hooked"
    if not BrowsePanel[methodName] or BrowsePanel[flagName] then return end
    BrowsePanel[flagName] = true
    local oldMethod = BrowsePanel[methodName]
    BrowsePanel[methodName] = function(self, ...)
      oldMethod(self, ...)
      RecordCurrentSearchResults()
      if advanceQueue and debugSearchActive and debugSearchQueue then
        if C_Timer and C_Timer.After then
          C_Timer.After(0.05, ContinueDebugSearch)
        else
          ContinueDebugSearch()
        end
      end
    end
  end

  HookResultHandler("MEETINGSTONE_ACTIVITIES_RESULT_RECEIVED", true)
  HookResultHandler("MEETINGSTONE_ACTIVITIES_RESULT_UPDATED", false)
end

local function HookApplicantPanelList()
  local ApplicantPanel = GetMeetingStoneValue("ApplicantPanel")
  if not ApplicantPanel then return end
  if ApplicantPanel.ApplicantList then
    PatchNoobIconHeader(ApplicantPanel.ApplicantList, "starTarget")

    local list = ApplicantPanel.ApplicantList
    if type(list.buttons) == "table" then
      for _, button in ipairs(list.buttons) do
        if button and button.starTarget and button.starTarget.Icon then
          button.starTarget.width = 18
          button.starTarget.height = 18
          button.starTarget.Icon:SetSize(18, 18)
        end
      end
    end

    if not list.__RememberNoobGroupedHooked and list.events and list.events.OnItemGrouped then
      list.__RememberNoobGroupedHooked = true
      local oldOnItemGrouped = list.events.OnItemGrouped
      list:SetCallback("OnItemGrouped", function(view, button, applicant, ...)
        oldOnItemGrouped(view, button, applicant, ...)
        if button and button.SetRememberNoobHighlight then
          button:SetRememberNoobHighlight(ApplicantHasNoob(applicant))
        end
      end)
    end
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
  RecordCurrentSearchResults()
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
  frame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
  frame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
  frame:RegisterEvent("LFG_LIST_SEARCH_FAILED")
  frame:SetScript("OnEvent", function(self, event, addonName)
    if event == "LFG_LIST_SEARCH_RESULTS_RECEIVED" or event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
      return
    end
    if event == "LFG_LIST_SEARCH_FAILED" then
      debugLogStatus = "搜索失败事件"
      NotifyFilterLogChanged()
      return
    end
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
