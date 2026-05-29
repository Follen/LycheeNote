local ADDON_NAME, ns = ...

local UI = {}
ns.RememberNoobUI = UI

local unpack = unpack or table.unpack
local Controls = ns.RememberNoobControls
local Style = ns.RememberNoobStyle

--- Layer Manager

local LayerManager = {}
ns.RememberNoobLayerManager = LayerManager
local activeClass1 = nil
local activeClass2 = nil
local keyboardFrame = nil

function LayerManager.InitKeyboardListener()
  if keyboardFrame then return end
  keyboardFrame = CreateFrame("Frame", nil, UIParent)
  keyboardFrame:Hide()
  keyboardFrame:SetScript("OnKeyDown", function(frame, key)
    if key == "ESCAPE" then
      if activeClass2 and activeClass2:IsShown() then
        LayerManager.HideClass2()
        frame:SetPropagateKeyboardInput(false)
        return
      end
      if activeClass1 and activeClass1:IsShown() then
        LayerManager.HideClass1()
        frame:SetPropagateKeyboardInput(false)
        return
      end
      frame:SetPropagateKeyboardInput(true)
    else
      frame:SetPropagateKeyboardInput(true)
    end
  end)
  keyboardFrame:EnableKeyboard(true)
end

function LayerManager.EnableKeyboardListener()
  LayerManager.InitKeyboardListener()
  if keyboardFrame then
    keyboardFrame:Show()
    keyboardFrame:EnableKeyboard(true)
    keyboardFrame:SetFrameStrata("DIALOG")
    keyboardFrame:SetFrameLevel(150)
  end
end

function LayerManager.DisableKeyboardListener()
  if keyboardFrame then
    keyboardFrame:Hide()
    keyboardFrame:EnableKeyboard(false)
  end
end

function LayerManager.UpdateInteractionState()
  if activeClass1 then
    local isInteractionEnabled = (activeClass2 == nil)
    activeClass1:EnableMouse(isInteractionEnabled)
    if activeClass1.closeButton then
      activeClass1.closeButton:SetEnabled(isInteractionEnabled)
    end
    if activeClass1.tabButtons then
      for _, btn in ipairs(activeClass1.tabButtons) do
        btn:SetEnabled(isInteractionEnabled)
      end
    end
    if activeClass1.scrollFrame and activeClass1.scrollFrame.content then
      local content = activeClass1.scrollFrame.content
      local children = {content:GetChildren()}
      for _, row in ipairs(children) do
        if row:IsObjectType("Frame") then row:EnableMouse(isInteractionEnabled) end
      end
    end
    activeClass1:SetAlpha(isInteractionEnabled and 1.0 or 0.7)
  end
end

function LayerManager.ShowClass1(frame)
  if not frame then return end
  activeClass1 = frame
  frame:SetFrameStrata("DIALOG")
  frame:SetFrameLevel(50)
  frame:Show()
  LayerManager.EnableKeyboardListener()
  LayerManager.UpdateInteractionState()
end

function LayerManager.HideClass1()
  if not activeClass1 then return end
  activeClass1:Hide()
  activeClass1 = nil
  LayerManager.UpdateInteractionState()
  if not activeClass1 and not activeClass2 then
    LayerManager.DisableKeyboardListener()
  end
end

function LayerManager.ShowClass2(frame)
  if not frame then return end
  activeClass2 = frame
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(100)
  frame:Show()
  LayerManager.EnableKeyboardListener()
  frame:EnableKeyboard(true)
  frame:SetPropagateKeyboardInput(false)
  if frame.editBox and frame.editBox.SetFocus then
    frame.editBox:SetFocus()
  end
  LayerManager.UpdateInteractionState()
end

function LayerManager.HideClass2()
  if not activeClass2 then return end
  activeClass2:Hide()
  activeClass2 = nil
  LayerManager.UpdateInteractionState()
  if activeClass1 then activeClass1:Raise() end
  if not activeClass1 and not activeClass2 then
    LayerManager.DisableKeyboardListener()
  end
end

--- Management UI

local function SetColor(region, methodName, color)
  if region and region[methodName] and color then
    region[methodName](region, unpack(color))
  end
end

local function ApplyPanelBackdrop(frame)
  if Controls and Controls.ApplyBackdrop then
    Controls.ApplyBackdrop(frame, "PANEL_BG")
  else
    frame:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    SetColor(frame, "SetBackdropColor", {0.07, 0.07, 0.09, 0.88})
    SetColor(frame, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.56})
  end
end

local function GetClassSpecColor(classSpec)
  return Controls and Controls.GetClassSpecColor and Controls.GetClassSpecColor(classSpec)
end

local function HideTexture(texture)
  if texture and texture.SetTexture then texture:SetTexture(nil) end
  if texture and texture.Hide then texture:Hide() end
end

local function HideButton(button)
  if not button then return end
  if button.Hide then button:Hide() end
  if button.SetAlpha then button:SetAlpha(0) end
  if button.EnableMouse then button:EnableMouse(false) end
  if button.GetNormalTexture then HideTexture(button:GetNormalTexture()) end
  if button.GetPushedTexture then HideTexture(button:GetPushedTexture()) end
  if button.GetDisabledTexture then HideTexture(button:GetDisabledTexture()) end
  if button.GetHighlightTexture then HideTexture(button:GetHighlightTexture()) end
end

local function StyleScrollBar(scrollFrame)
  if not scrollFrame then return end
  local scrollBar = scrollFrame.ScrollBar
  if not scrollBar then return end

  HideButton(scrollBar.Back)
  HideButton(scrollBar.Forward)
  HideButton(scrollBar.ScrollUpButton)
  HideButton(scrollBar.ScrollDownButton)
  HideTexture(scrollBar.Background)
  HideTexture(scrollBar.Track)

  if scrollBar.ClearAllPoints then
    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 4, -2)
    scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 4, 2)
  end
  if scrollBar.SetWidth then scrollBar:SetWidth(8) end

  if not scrollBar.rnTrack then
    local track = CreateFrame("Frame", nil, scrollBar, "BackdropTemplate")
    track:SetPoint("TOP", scrollBar, "TOP", 0, 0)
    track:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 0)
    track:SetWidth(6)
    track:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    SetColor(track, "SetBackdropColor", {0.045, 0.045, 0.06, 0.52})
    SetColor(track, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.42})
    scrollBar.rnTrack = track
  end

  local thumb = scrollBar.Thumb or (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture())
  if thumb then
    if thumb.SetTexture then thumb:SetTexture("Interface\\Buttons\\WHITE8x8") end
    if thumb.SetColorTexture then
      SetColor(thumb, "SetColorTexture", Style and Style.Get and Style.Get("ACCENT_COLOR") or {0.408, 0.659, 0.671, 1})
    elseif thumb.SetVertexColor then
      SetColor(thumb, "SetVertexColor", {0.408, 0.659, 0.671, 0.95})
    end
    if thumb.SetWidth then thumb:SetWidth(6) end
  end
end

local function CreatePageTitle(parent, title, subtitle)
  local titleText = Controls and Controls.CreateText and
    Controls.CreateText(parent, title, "GameFontNormalLarge", "VALUE_COLOR")
  if titleText and titleText.SetPoint then
    titleText:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  end

  if subtitle then
    local subtitleText = Controls and Controls.CreateText and
      Controls.CreateText(parent, subtitle, "GameFontNormalSmall", "LABEL_COLOR")
    if subtitleText and subtitleText.SetPoint then
      subtitleText:SetPoint("TOPLEFT", titleText or parent, "BOTTOMLEFT", 0, -6)
      subtitleText:SetWidth(640)
      subtitleText:SetJustifyH("LEFT")
    end
    return titleText, subtitleText
  end

  return titleText
end

local function CreateWrappedText(parent, text, anchor, xOffset, yOffset, width)
  local fontString = Controls and Controls.CreateText and
    Controls.CreateText(parent, text, "GameFontNormalSmall", "LABEL_COLOR")
  if fontString and fontString.SetPoint then
    fontString:SetPoint("TOPLEFT", anchor or parent, anchor and "BOTTOMLEFT" or "TOPLEFT", xOffset or 0, yOffset or 0)
    fontString:SetWidth(width or 620)
    fontString:SetJustifyH("LEFT")
    fontString:SetWordWrap(true)
  end
  return fontString
end

local function GetConfigValue(configPath)
  return ns.Config and ns.Config.Get and ns.Config.Get(configPath) == true
end

local function SetConfigValue(configPath, value)
  if ns.Config and ns.Config.Set then
    ns.Config.Set(configPath, value and true or false)
  end
  if ns.RememberNoobMeetingStone and ns.RememberNoobMeetingStone.Refresh then
    ns.RememberNoobMeetingStone.Refresh()
  end
end

local function IsDebugPanelEnabled()
  return ns.Config and ns.Config.Get and ns.Config.Get("debug.showPanel") == true
end

local function SetShown(frame, shown)
  if not frame then return end
  if frame.SetShown then
    frame:SetShown(shown)
  elseif shown and frame.Show then
    frame:Show()
  elseif frame.Hide then
    frame:Hide()
  end
end

local function CreateSidebarButton(parent, text, width, height, active)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(width or 136, height or 34)
  button:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  if button.SetPushedTextOffset then button:SetPushedTextOffset(0, -1) end

  button.hover = button:CreateTexture(nil, "BACKGROUND")
  button.hover:SetAllPoints(button)
  button.hover:SetColorTexture(0.408, 0.659, 0.671, 0.14)
  button.hover:Hide()

  button.accent = button:CreateTexture(nil, "ARTWORK")
  button.accent:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -5)
  button.accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 5)
  button.accent:SetWidth(3)
  button.accent:SetColorTexture(0.408, 0.659, 0.671, 1)

  local label = Controls and Controls.CreateText and
    Controls.CreateText(button, text, "GameFontNormal", "VALUE_COLOR")
  if label and label.SetPoint then label:SetPoint("LEFT", button, "LEFT", 18, 0) end
  if label and label.SetJustifyH then label:SetJustifyH("LEFT") end
  button.label = label

  function button:SetActive(isActive)
    self.active = isActive and true or false
    SetColor(self, "SetBackdropColor", self.active and {0.10, 0.10, 0.12, 0.82} or {0.055, 0.055, 0.07, 0.18})
    SetColor(self, "SetBackdropBorderColor", self.active and {0.408, 0.659, 0.671, 0.65} or {0.20, 0.20, 0.23, 0.18})
    SetColor(self.label, "SetTextColor", self.active and {0.92, 0.92, 0.95, 1} or {0.70, 0.70, 0.76, 1})
    SetShown(self.accent, self.active)
    SetShown(self.hover, self.active)
  end

  button:SetScript("OnEnter", function(self)
    SetShown(self.hover, true)
    if not self.active then
      SetColor(self, "SetBackdropBorderColor", {0.408, 0.659, 0.671, 0.34})
    end
  end)
  button:SetScript("OnLeave", function(self)
    SetShown(self.hover, self.active)
    if not self.active then
      SetColor(self, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.18})
    end
  end)

  button:SetActive(active)
  return button
end

local function CreateConfigCheckButton(parent, label, configPath, yOffset)
  local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
  row:SetSize(640, 34)
  row:EnableMouse(true)
  row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  SetColor(row, "SetBackdropColor", {0.055, 0.055, 0.07, 0.24})

  local check = CreateFrame("Button", nil, row, "BackdropTemplate")
  check:SetPoint("LEFT", row, "LEFT", 2, 0)
  check:SetSize(18, 18)
  check:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(check, "SetBackdropColor", {0.12, 0.12, 0.14, 0.90})

  check.inner = check:CreateTexture(nil, "ARTWORK")
  check.inner:SetPoint("TOPLEFT", check, "TOPLEFT", 4, -4)
  check.inner:SetPoint("BOTTOMRIGHT", check, "BOTTOMRIGHT", -4, 4)
  SetColor(check.inner, "SetColorTexture", Style and Style.Get and Style.Get("ACCENT_COLOR") or {0.408, 0.659, 0.671, 1})

  local labelText = Controls and Controls.CreateText and
    Controls.CreateText(row, label, "GameFontHighlight", "VALUE_COLOR")
  if labelText and labelText.SetPoint then
    labelText:SetPoint("LEFT", check, "RIGHT", 14, 0)
  end

  function check:Refresh()
    local checked = GetConfigValue(configPath)
    SetShown(self.inner, checked)
    SetColor(self, "SetBackdropBorderColor", checked and {0.408, 0.659, 0.671, 1} or {0.20, 0.20, 0.23, 0.56})
  end

  local function Toggle()
    SetConfigValue(configPath, not GetConfigValue(configPath))
    if check.Refresh then check:Refresh() end
  end

  check:SetScript("OnClick", Toggle)
  row:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then
      Toggle()
    end
  end)

  check:Refresh()
  return row
end

local function CreateDebugCategoryDropdown(parent)
  local pve = Enum and Enum.LFGListFilter and Enum.LFGListFilter.PvE or 1
  local pvp = Enum and Enum.LFGListFilter and Enum.LFGListFilter.PvP or 2
  local menuTable = {
    {text = "地下堡", value = "delve", categoryID = 121, baseFilter = pve},
    {text = "地下城", value = "dungeon", categoryID = 2, baseFilter = pve},
    {text = "团队副本", value = "raid", categoryID = 3, baseFilter = pve},
    {text = "PVP", value = "pvp", categoryID = 4, baseFilter = pvp, searchPlan = {
      {categoryID = 4, baseFilter = pvp, label = "PVP"},
      {categoryID = 7, baseFilter = pvp, label = "PVP"},
      {categoryID = 8, baseFilter = pvp, label = "PVP"},
      {categoryID = 9, baseFilter = pvp, label = "PVP"},
      {categoryID = 10, baseFilter = pvp, label = "PVP"},
    }},
    {text = "自定义", value = "custom", categoryID = 6, baseFilter = pve},
    {text = "任务", value = "quest", categoryID = 1, baseFilter = pve},
  }

  local dropdown = CreateFrame("Button", nil, parent, "BackdropTemplate")
  dropdown:SetSize(150, 28)
  dropdown.item = menuTable[1]
  dropdown:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(dropdown, "SetBackdropColor", {0.055, 0.055, 0.07, 0.70})
  SetColor(dropdown, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.56})

  local label = Controls and Controls.CreateText and
    Controls.CreateText(dropdown, menuTable[1].text, "GameFontHighlightSmall", "VALUE_COLOR")
  if label and label.SetPoint then
    label:SetPoint("LEFT", dropdown, "LEFT", 10, 0)
  end
  dropdown.label = label

  local arrow = Controls and Controls.CreateText and
    Controls.CreateText(dropdown, "v", "GameFontHighlightSmall", "LABEL_COLOR")
  if arrow and arrow.SetPoint then
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -10, 0)
  end

  local menu = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -4)
  menu:SetSize(150, #menuTable * 26 + 8)
  menu:SetFrameLevel(parent:GetFrameLevel() + 30)
  menu:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(menu, "SetBackdropColor", {0.045, 0.045, 0.06, 0.96})
  SetColor(menu, "SetBackdropBorderColor", {0.408, 0.659, 0.671, 0.46})
  menu:Hide()

  local function SelectItem(item)
    dropdown.item = item
    if dropdown.label then dropdown.label:SetText(item.text) end
    menu:Hide()
    if ns.RememberNoobMeetingStone and ns.RememberNoobMeetingStone.SearchDebugCategory then
      ns.RememberNoobMeetingStone.SearchDebugCategory(item)
    end
  end

  for index, item in ipairs(menuTable) do
    local option = CreateFrame("Button", nil, menu, "BackdropTemplate")
    option:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - (index - 1) * 26)
    option:SetSize(142, 24)
    option:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8"})
    SetColor(option, "SetBackdropColor", {0, 0, 0, 0})
    local optionText = Controls and Controls.CreateText and
      Controls.CreateText(option, item.text, "GameFontHighlightSmall", "VALUE_COLOR")
    if optionText and optionText.SetPoint then
      optionText:SetPoint("LEFT", option, "LEFT", 8, 0)
    end
    option:SetScript("OnEnter", function(self)
      SetColor(self, "SetBackdropColor", {0.408, 0.659, 0.671, 0.18})
    end)
    option:SetScript("OnLeave", function(self)
      SetColor(self, "SetBackdropColor", {0, 0, 0, 0})
    end)
    option:SetScript("OnClick", function()
      SelectItem(item)
    end)
  end

  dropdown.GetItem = function(self) return self.item end
  dropdown:SetScript("OnClick", function()
    SetShown(menu, not menu:IsShown())
  end)
  dropdown:SetScript("OnEnter", function(self)
    SetColor(self, "SetBackdropBorderColor", {0.408, 0.659, 0.671, 0.70})
  end)
  dropdown:SetScript("OnLeave", function(self)
    SetColor(self, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.56})
  end)

  dropdown.menu = menu
  return dropdown
end

function UI.CreateListPanel(listPanel)
  local headers = {"玩家姓名", "服务器名称", "职业专精", "加入时间", "加入原因"}
  local columnWidths = {100, 95, 115, 85, 225}

  local titleText = CreatePageTitle(listPanel, "笨蛋列表")

  local headerFrame = CreateFrame("Frame", nil, listPanel, "BackdropTemplate")
  headerFrame:SetPoint("TOPLEFT", titleText or listPanel, titleText and "BOTTOMLEFT" or "TOPLEFT", 0, -18)
  headerFrame:SetSize(640, 30)
  headerFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(headerFrame, "SetBackdropColor", {0.10, 0.10, 0.12, 0.90})
  SetColor(headerFrame, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.40})

  local xOffset = 0
  for i, headerText in ipairs(headers) do
    local header = Controls and Controls.CreateText and
      Controls.CreateText(headerFrame, headerText, "GameFontNormalSmall", "LABEL_COLOR")
    if header and header.SetPoint then
      header:SetPoint("LEFT", headerFrame, "LEFT", xOffset + 5, 0)
    end
    xOffset = xOffset + columnWidths[i]
  end

  local scrollFrame = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -5)
  scrollFrame:SetSize(640, 338)
  StyleScrollBar(scrollFrame)
  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(620, 1)
  scrollFrame:SetScrollChild(content)

  listPanel.scrollFrame = scrollFrame
  listPanel.content = content
  listPanel.columnWidths = columnWidths
end

function UI.RefreshListPanel(listPanel)
  if not listPanel.content then return end
  local content = listPanel.content
  local columnWidths = listPanel.columnWidths or {100, 95, 115, 85, 225}

  local children = {content:GetChildren()}
  for i = 1, #children do
    children[i]:Hide()
    children[i]:SetParent(nil)
  end

  local list = ns.RememberNoobNoob.GetNoobList()
  local baseRowHeight = 25
  local yOffset = 0

  for index, data in ipairs(list) do
    local row = CreateFrame("Button", nil, content, "BackdropTemplate")
    row:SetSize(620, baseRowHeight)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
    row:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
    })

    local bgColor = (index % 2 == 0) and {0.055, 0.055, 0.07, 0.50} or {0.075, 0.075, 0.095, 0.50}
    SetColor(row, "SetBackdropColor", bgColor)

    row:SetScript("OnEnter", function(self)
      SetColor(self, "SetBackdropColor", {0.12, 0.12, 0.14, 0.70})
    end)
    row:SetScript("OnLeave", function(self)
      SetColor(self, "SetBackdropColor", bgColor)
    end)

    row:RegisterForClicks("RightButtonUp")
    row:SetScript("OnMouseUp", function(self, button)
      if button == "RightButton" then
        local refreshCallback = function() UI.RefreshListPanel(listPanel) end
        if ns.RememberNoobMenu then
          ns.RememberNoobMenu.ShowRowContextMenu(data.name, refreshCallback)
        end
      end
    end)

    local columnData = {
      data.name,
      data.server or GetRealmName(),
      data.classSpec or "尚未获取",
      date("%y/%m/%d", data.timestamp),
      data.reason or "无理由"
    }

    local labels = {}
    local xOffset = 0
    for i, text in ipairs(columnData) do
      local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      label:SetPoint("TOPLEFT", row, "TOPLEFT", xOffset + 5, -6)
      label:SetWidth(columnWidths[i] - 10)
      label:SetJustifyH("LEFT")
      label:SetWordWrap(false)
      label:SetMaxLines(1)
      label:SetText(text)
      SetColor(label, "SetTextColor", (i == 3 and GetClassSpecColor(text)) or {0.70, 0.70, 0.76, 1})
      if i == 5 then
        label:SetWordWrap(true)
        label:SetMaxLines(0)
      end
      labels[i] = label
      xOffset = xOffset + columnWidths[i]
    end

    local reasonHeight = labels[5] and labels[5].GetStringHeight and labels[5]:GetStringHeight() or 0
    local rowHeight = math.max(baseRowHeight, math.ceil(reasonHeight + 12))
    row:SetHeight(rowHeight)
    yOffset = yOffset + rowHeight
  end

  content:SetHeight(math.max(yOffset, 1))

  if listPanel.scrollFrame.ScrollBar then
    if #list == 0 then
      listPanel.scrollFrame.ScrollBar:Hide()
    else
      listPanel.scrollFrame.ScrollBar:Show()
    end
  end
end

function UI.CreateImportPanel(panel, listPanel)
  local tipText = Controls and Controls.CreateText and
    Controls.CreateText(panel, "请在下方输入框中粘贴导入数据：", "GameFontNormal", "LABEL_COLOR")
  if tipText and tipText.SetPoint then
    tipText:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  end

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", tipText or panel, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetSize(624, 240)
  StyleScrollBar(scrollFrame)

  local inputBg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
  inputBg:SetSize(606, 240)
  inputBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(inputBg, "SetBackdropColor", {0.12, 0.12, 0.14, 0.90})
  SetColor(inputBg, "SetBackdropBorderColor", {0.22, 0.22, 0.26, 0.70})

  local editBox = CreateFrame("EditBox", nil, inputBg)
  editBox:SetPoint("TOPLEFT", inputBg, "TOPLEFT", 8, -8)
  editBox:SetPoint("BOTTOMRIGHT", inputBg, "BOTTOMRIGHT", -8, 8)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject("ChatFontNormal")
  editBox:SetMaxLetters(10000)
  editBox:SetCursorPosition(0)
  editBox:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then self:SetFocus() end
  end)
  scrollFrame:SetScrollChild(inputBg)

  local importBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(panel, "导入数据", 100, 28)
  if importBtn and importBtn.SetPoint then
    importBtn:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -10)
  end
  if importBtn and importBtn.SetScript then
    importBtn:SetScript("OnClick", function()
      local importData = editBox:GetText():trim()
      if importData == "" then return end

      local base64Data = importData
      if importData:sub(1, 3) == "RB-" then
        base64Data = importData:sub(4)
      else
        print("|cffff0000RememberNoob: 导入数据格式不正确，缺少RB-前缀|r")
        return
      end

      if not base64Data:match("^[A-Za-z0-9+/]*=*$") then
        print("|cffff0000RememberNoob: 导入数据格式不正确|r")
        return
      end

      local ok, decodedData = pcall(function() return ns.RememberNoobNoob.Base64Decode(base64Data) end)
      if not ok then
        print("|cffff0000RememberNoob: Base64解码失败 - " .. tostring(decodedData) .. "|r")
        return
      end

      local ok2, importedList = pcall(function()
        local result = ns.RememberNoobNoob.DeserializeTable(decodedData)
        if type(result) ~= "table" then result = {} end
        return result
      end)
      if not ok2 then
        print("|cffff0000RememberNoob: 数据反序列化过程中发生异常|r")
        return
      end

      local currentList = ns.RememberNoobNoob.GetNoobList()
      local mergedCount = 0
      for _, importItem in ipairs(importedList) do
        if importItem.name and importItem.timestamp then
          local exists = false
          for _, currentItem in ipairs(currentList) do
            if currentItem.name == importItem.name and
               (currentItem.server or GetRealmName()) == (importItem.server or GetRealmName()) then
              exists = true
              break
            end
          end
          if not exists then
            table.insert(currentList, importItem)
            mergedCount = mergedCount + 1
          end
        end
      end

      local db = ns.db
      for _, item in ipairs(currentList) do
        if item.name then
          db.noobs[item.name] = {
            server = item.server or GetRealmName(),
            timestamp = item.timestamp or time(),
            reason = item.reason or "无理由",
            classSpec = item.classSpec or "尚未获取"
          }
        end
      end

      print("|cff00ff00RememberNoob: 成功导入 " .. mergedCount .. " 条数据|r")
      UI.RefreshListPanel(listPanel)
      editBox:SetText("")
    end)
  end

  local clearBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(panel, "清空", 80, 28)
  if clearBtn and clearBtn.SetPoint then
    clearBtn:SetPoint("LEFT", importBtn, "RIGHT", 10, 0)
  end
  if clearBtn and clearBtn.SetScript then
    clearBtn:SetScript("OnClick", function() editBox:SetText("") end)
  end
end

function UI.CreateExportPanel(panel)

  local tipText = Controls and Controls.CreateText and
    Controls.CreateText(panel, "复制下方的编码数据进行备份或分享：", "GameFontNormal", "LABEL_COLOR")
  if tipText and tipText.SetPoint then
    tipText:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
  end

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", tipText or panel, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetSize(624, 240)
  StyleScrollBar(scrollFrame)

  local displayBg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
  displayBg:SetSize(606, 240)
  displayBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(displayBg, "SetBackdropColor", {0.12, 0.12, 0.14, 0.90})
  SetColor(displayBg, "SetBackdropBorderColor", {0.22, 0.22, 0.26, 0.70})

  local editBox = CreateFrame("EditBox", nil, displayBg)
  editBox:SetPoint("TOPLEFT", displayBg, "TOPLEFT", 8, -8)
  editBox:SetPoint("BOTTOMRIGHT", displayBg, "BOTTOMRIGHT", -8, 8)
  editBox:SetMultiLine(true)
  editBox:SetAutoFocus(false)
  editBox:SetFontObject("ChatFontNormal")
  editBox:SetMaxLetters(10000)
  editBox:SetCursorPosition(0)
  editBox:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then self:SetFocus() end
  end)
  scrollFrame:SetScrollChild(displayBg)

  local function GenerateExportData()
    local list = ns.RememberNoobNoob.GetNoobList()
    if #list == 0 then
      editBox:SetText("暂无数据可导出")
      return
    end
    local ok, serializedData = pcall(function() return ns.RememberNoobNoob.SerializeTable(list) end)
    if not ok or not serializedData or serializedData == "" then
      editBox:SetText("序列化失败")
      return
    end
    local ok2, encodedData = pcall(function() return ns.RememberNoobNoob.Base64Encode(serializedData) end)
    if not ok2 then
      editBox:SetText("Base64编码失败: " .. tostring(encodedData))
      return
    end
    editBox:SetText("RB-" .. encodedData)
  end

  local selectAllBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(panel, "全选", 100, 28)
  if selectAllBtn and selectAllBtn.SetPoint then
    selectAllBtn:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -10)
  end
  if selectAllBtn and selectAllBtn.SetScript then
    selectAllBtn:SetScript("OnClick", function()
      editBox:SetFocus()
      editBox:HighlightText()
    end)
  end

  local refreshBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(panel, "刷新数据", 100, 28)
  if refreshBtn and refreshBtn.SetPoint then
    refreshBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 10, 0)
  end
  if refreshBtn and refreshBtn.SetScript then
    refreshBtn:SetScript("OnClick", GenerateExportData)
  end

  panel:SetScript("OnShow", GenerateExportData)
end

function UI.CreateMeetingStoneSettingsPanel(panel)
  CreatePageTitle(panel, "集合石设置")

  local startY = -54
  CreateConfigCheckButton(
    panel,
    "是否显示图标",
    "meetingStone.showIcon",
    startY)
  CreateConfigCheckButton(
    panel,
    "是否标红高亮",
    "meetingStone.highlightNoob",
    startY - 46)
  CreateConfigCheckButton(
    panel,
    "是否启用一键拒绝笨蛋",
    "meetingStone.enableOneClickReject",
    startY - 92)
end

function UI.CreateMeetingStoneFilterPanel(panel)
  CreatePageTitle(panel, "集合石过滤")
end

function UI.RefreshDebugLogPanel()
  local frame = _G["RememberNoobManagementFrame"]
  local panel = frame and frame.debugPanel
  if not panel then return end

  local meetingStone = ns.RememberNoobMeetingStone
  local enabled = meetingStone and meetingStone.IsFilterLogEnabled and meetingStone.IsFilterLogEnabled()
  local count = meetingStone and meetingStone.GetFilterLogCount and meetingStone.GetFilterLogCount() or 0
  local status = meetingStone and meetingStone.GetFilterLogStatus and meetingStone.GetFilterLogStatus() or ""
  local text = meetingStone and meetingStone.GetFilterLogText and meetingStone.GetFilterLogText() or ""
  local displayText = meetingStone and meetingStone.GetFilterLogDisplayText and meetingStone.GetFilterLogDisplayText() or text
  local rows = meetingStone and meetingStone.GetFilterLogDisplayRows and meetingStone.GetFilterLogDisplayRows() or nil

  if panel.logButton and panel.logButton.label then
    panel.logButton.label:SetText(enabled and "关闭集合石过滤日志" or "开启集合石过滤日志")
  end
  if panel.countText then
    local current = status:match("^结果:%s*(%d+)$")
    if current then
      panel.countText:SetText("累计：" .. count .. "  当前列表：" .. current)
    else
      panel.countText:SetText("累计：" .. count .. (status ~= "" and ("  " .. status) or ""))
    end
  end
  local lineCount = 1
  for _ in string.gmatch(displayText, "\n") do
    lineCount = lineCount + 1
  end
  if type(rows) == "table" and #rows > 0 then
    lineCount = #rows
  end
  local contentHeight = math.max(316, lineCount * 16 + 20)

  if panel.logRows then
    for i = 1, #panel.logRows do
      panel.logRows[i]:Hide()
    end
  end
  if panel.logBg and type(rows) == "table" then
    panel.logRows = panel.logRows or {}
    for i, line in ipairs(rows) do
      local row = panel.logRows[i]
      if not row then
        row = panel.logBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row:SetJustifyH("LEFT")
        row:SetWordWrap(false)
        row:SetWidth(600)
        SetColor(row, "SetTextColor", {0.92, 0.92, 0.95, 1})
        panel.logRows[i] = row
      end
      row:SetPoint("TOPLEFT", panel.logBg, "TOPLEFT", 8, -8 - (i - 1) * 16)
      row:SetText(line)
      row:Show()
    end
  end
  if panel.logText then
    panel.logText:SetText("")
    panel.logText:Hide()
  end
  if panel.copyBox then
    panel.copyBox:SetText(displayText)
    panel.copyBox:SetCursorPosition(0)
    panel.copyBox:SetHeight(contentHeight - 16)
    panel.copyBox:Show()
    panel.copyBox:SetAlpha(0.01)
  end
  if panel.logBg then
    panel.logBg:SetHeight(contentHeight)
  end
end

local function EnableDebugLogCopy(panel)
  if not panel or not panel.copyBox then return end
  local copyBox = panel.copyBox
  copyBox:EnableMouse(true)
  copyBox:SetEnabled(true)
  copyBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  copyBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  copyBox:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" then
      self:SetFocus()
      self:HighlightText()
    end
  end)
end

local function SelectDebugLog(panel)
  if not panel then return end
  UI.RefreshDebugLogPanel()
  if panel.copyBox then
    panel.copyBox:Show()
    panel.copyBox:SetAlpha(0.01)
    panel.copyBox:EnableMouse(true)
    panel.copyBox:SetEnabled(true)
    panel.copyBox:SetFocus()
    panel.copyBox:HighlightText()
  end
  print("|cff00ff00RememberNoob: 已全选 Lua 数据，按 Ctrl+C 复制|r")
end

function UI.ShowDebugLogCopyFrame(text, rows)
  if not UI.debugLogCopyFrame then
    local frame = CreateFrame("Frame", "RememberNoobDebugLogCopyFrame", UIParent, "BackdropTemplate")
    frame:SetSize(720, 500)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(200)
    frame:EnableMouse(true)
    ApplyPanelBackdrop(frame)

    local title = Controls and Controls.CreateText and
      Controls.CreateText(frame, "复制 Lua 数据", "GameFontNormalLarge", "VALUE_COLOR")
    if title then
      title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -16)
    end

    local closeButton = Controls and Controls.CreateButton and
      Controls.CreateButton(frame, "关闭", 78, 28)
    if closeButton then
      closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -12)
      closeButton:SetScript("OnClick", function()
        frame:Hide()
      end)
    end

    local selectButton = Controls and Controls.CreateButton and
      Controls.CreateButton(frame, "全选", 78, 28)
    if selectButton then
      selectButton:SetPoint("RIGHT", closeButton, "LEFT", -8, 0)
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -56)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 18)
    StyleScrollBar(scrollFrame)

    local bg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
    bg:SetSize(650, 410)
    bg:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    SetColor(bg, "SetBackdropColor", {0.08, 0.08, 0.10, 0.96})
    SetColor(bg, "SetBackdropBorderColor", {0.22, 0.22, 0.26, 0.70})

    local editBox = CreateFrame("EditBox", nil, bg)
    editBox:SetPoint("TOPLEFT", bg, "TOPLEFT", 10, -10)
    editBox:SetPoint("BOTTOMRIGHT", bg, "BOTTOMRIGHT", -10, 10)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextColor(0.92, 0.92, 0.95, 1)
    editBox:SetMaxLetters(800000)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
      frame:Hide()
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
      self:HighlightText()
    end)
    scrollFrame:SetScrollChild(bg)

    frame.rows = {}
    if selectButton then
      selectButton:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
      end)
    end

    frame.editBox = editBox
    frame.bg = bg
    UI.debugLogCopyFrame = frame
  end

  local frame = UI.debugLogCopyFrame
  frame:Show()
  frame.editBox:SetText(text or "")
  frame.editBox:SetCursorPosition(0)
  local lineCount = 1
  for _ in string.gmatch(text or "", "\n") do
    lineCount = lineCount + 1
  end
  if type(rows) == "table" and #rows > 0 then
    lineCount = #rows
  end
  frame.bg:SetHeight(math.max(410, lineCount * 16 + 24))
  if frame.rows then
    for i = 1, #frame.rows do
      frame.rows[i]:Hide()
    end
  end
  if type(rows) ~= "table" then
    rows = {}
    for line in (text or ""):gmatch("[^\n]+") do
      rows[#rows + 1] = line
    end
  end
  for i, line in ipairs(rows) do
    local row = frame.rows[i]
    if not row then
      row = frame.bg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      row:SetJustifyH("LEFT")
      row:SetWordWrap(false)
      row:SetWidth(620)
      SetColor(row, "SetTextColor", {0.92, 0.92, 0.95, 1})
      frame.rows[i] = row
    end
    row:SetPoint("TOPLEFT", frame.bg, "TOPLEFT", 10, -10 - (i - 1) * 16)
    row:SetText(line)
    row:Show()
  end
  frame.editBox:SetAlpha(0.01)
  frame.editBox:SetFocus()
  frame.editBox:HighlightText()
  print("|cff00ff00RememberNoob: 已打开 Lua 数据复制框，按 Ctrl+C 复制|r")
end

local function UpdateDebugLogHeight(panel)
  if not panel or not panel.copyBox then return end
  local text = panel.copyBox:GetText() or ""
  local lineCount = 1
  for _ in string.gmatch(text, "\n") do
    lineCount = lineCount + 1
  end
  local contentHeight = math.max(316, lineCount * 16 + 20)
  if panel.logText then panel.logText:SetHeight(contentHeight - 16) end
  panel.copyBox:SetHeight(contentHeight - 16)
  if panel.logBg then
    panel.logBg:SetHeight(contentHeight)
  end
end

function UI.CreateDebugPanel(panel)
  local titleText = CreatePageTitle(panel, "调试")

  local categoryDropdown = CreateDebugCategoryDropdown(panel)
  if categoryDropdown and categoryDropdown.SetPoint then
    categoryDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -42)
  end

  local logButton = Controls and Controls.CreateButton and
    Controls.CreateButton(panel, "开启集合石过滤日志", 150, 28)
  if logButton and logButton.SetPoint then
    logButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -42)
  end

  local selectButton = Controls and Controls.CreateButton and
    Controls.CreateButton(panel, "复制 Lua", 88, 28)
  if selectButton and selectButton.SetPoint then
    selectButton:SetPoint("RIGHT", logButton, "LEFT", -8, 0)
  end

  local countText = Controls and Controls.CreateText and
    Controls.CreateText(panel, "记录：0", "GameFontNormalSmall", "LABEL_COLOR")
  if countText and countText.SetPoint then
    countText:SetPoint("RIGHT", selectButton or logButton or panel, (selectButton or logButton) and "LEFT" or "TOPRIGHT", -12, 0)
  end

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -84)
  scrollFrame:SetSize(640, 316)
  StyleScrollBar(scrollFrame)

  local logBg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
  logBg:SetSize(622, 316)
  logBg:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(logBg, "SetBackdropColor", {0.12, 0.12, 0.14, 0.90})
  SetColor(logBg, "SetBackdropBorderColor", {0.22, 0.22, 0.26, 0.70})

  local logText = logBg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  logText:SetPoint("TOPLEFT", logBg, "TOPLEFT", 8, -8)
  logText:SetPoint("RIGHT", logBg, "RIGHT", -8, 0)
  logText:SetJustifyH("LEFT")
  logText:SetJustifyV("TOP")
  logText:SetWordWrap(false)
  SetColor(logText, "SetTextColor", {0.92, 0.92, 0.95, 1})

  local copyBox = CreateFrame("EditBox", nil, logBg)
  copyBox:SetPoint("TOPLEFT", logBg, "TOPLEFT", 8, -8)
  copyBox:SetPoint("BOTTOMRIGHT", logBg, "BOTTOMRIGHT", -8, 8)
  copyBox:SetMultiLine(true)
  copyBox:SetAutoFocus(false)
  copyBox:SetFontObject("ChatFontNormal")
  copyBox:SetTextColor(0.92, 0.92, 0.95, 1)
  copyBox:SetWidth(606)
  copyBox:SetMaxLetters(500000)
  copyBox:SetAlpha(0.01)
  copyBox:SetJustifyH("LEFT")
  copyBox:SetJustifyV("TOP")
  copyBox:SetScript("OnTextChanged", function()
    UpdateDebugLogHeight(panel)
  end)
  scrollFrame:SetScrollChild(logBg)

  if logButton and logButton.SetScript then
    logButton:SetScript("OnClick", function()
      local wasEnabled = ns.RememberNoobMeetingStone and ns.RememberNoobMeetingStone.IsFilterLogEnabled and
        ns.RememberNoobMeetingStone.IsFilterLogEnabled()
      if ns.RememberNoobMeetingStone and ns.RememberNoobMeetingStone.ToggleFilterLog then
        ns.RememberNoobMeetingStone.ToggleFilterLog()
      end
      local item = categoryDropdown and categoryDropdown.GetItem and categoryDropdown:GetItem()
      if not wasEnabled and item and ns.RememberNoobMeetingStone and ns.RememberNoobMeetingStone.SearchDebugCategory then
        ns.RememberNoobMeetingStone.SearchDebugCategory(item)
      end
      UI.RefreshDebugLogPanel()
    end)
  end

  if selectButton and selectButton.SetScript then
    selectButton:SetScript("OnClick", function()
      SelectDebugLog(panel)
    end)
  end

  panel.categoryDropdown = categoryDropdown
  panel.logButton = logButton
  panel.selectButton = selectButton
  panel.countText = countText
  panel.logBg = logBg
  panel.logText = logText
  panel.copyBox = copyBox
  panel.logRows = {}
  EnableDebugLogCopy(panel)
  panel:SetScript("OnShow", UI.RefreshDebugLogPanel)
  UI.RefreshDebugLogPanel()
end

function UI.CreateDataManagementPanel(panel, listPanel)
  local titleText = CreatePageTitle(panel, "数据管理")

  local switchContainer = CreateFrame("Frame", nil, panel)
  switchContainer:SetPoint("TOPLEFT", titleText or panel, titleText and "BOTTOMLEFT" or "TOPLEFT", 0, -18)
  switchContainer:SetSize(640, 30)

  local content = CreateFrame("Frame", nil, panel)
  content:SetPoint("TOPLEFT", switchContainer, "BOTTOMLEFT", 0, -24)
  content:SetSize(640, 316)

  local importPanel = CreateFrame("Frame", nil, content)
  importPanel:SetAllPoints(content)
  local exportPanel = CreateFrame("Frame", nil, content)
  exportPanel:SetAllPoints(content)

  UI.CreateImportPanel(importPanel, listPanel)
  UI.CreateExportPanel(exportPanel)

  local importButton = Controls and Controls.CreateTabButton and
    Controls.CreateTabButton(switchContainer, "导入数据", 120, 30, true)
  local exportButton = Controls and Controls.CreateTabButton and
    Controls.CreateTabButton(switchContainer, "导出数据", 120, 30, false)

  if importButton then
    importButton:SetPoint("LEFT", switchContainer, "LEFT", 0, 0)
    importButton:SetScript("OnClick", function()
      importButton:SetActive(true)
      if exportButton then exportButton:SetActive(false) end
      importPanel:Show()
      exportPanel:Hide()
    end)
  end

  if exportButton then
    exportButton:SetPoint("LEFT", importButton or switchContainer, importButton and "RIGHT" or "LEFT", 8, 0)
    exportButton:SetScript("OnClick", function()
      if importButton then importButton:SetActive(false) end
      exportButton:SetActive(true)
      importPanel:Hide()
      exportPanel:Show()
    end)
  end

  importPanel:Show()
  exportPanel:Hide()
end

function UI.ShowManagementUI()
  if _G["RememberNoobManagementFrame"] then
    LayerManager.HideClass1()
    _G["RememberNoobManagementFrame"] = nil
  end

  local frame = CreateFrame("Frame", "RememberNoobManagementFrame", UIParent, "BackdropTemplate")
  frame:SetSize(900, 560)
  frame:SetPoint("CENTER")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  _G["RememberNoobManagementFrame"] = frame

  ApplyPanelBackdrop(frame)

  -- Title
  local title = Controls and Controls.CreateText and
    Controls.CreateText(frame, "笨蛋管理", "GameFontHighlight", "VALUE_COLOR")
  if title and title.SetPoint then
    title:SetPoint("TOP", frame, "TOP", 0, -15)
  end

  -- Close button (top-right corner)
  local closeBtn = Controls and Controls.CreateCloseButton and
    Controls.CreateCloseButton(frame, function() LayerManager.HideClass1() end)
  if closeBtn and closeBtn.SetPoint then
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
  end
  frame.closeButton = closeBtn

  local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -56)
  sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 48)
  sidebar:SetWidth(166)
  sidebar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
  })
  SetColor(sidebar, "SetBackdropColor", {0.035, 0.035, 0.045, 0.32})

  local contentContainer = CreateFrame("Frame", nil, frame)
  contentContainer:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 24, 0)
  contentContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 48)

  local navButtons = {}
  local pagePanels = {}
  local pageNames = {"笨蛋列表", "集合石设置", "集合石过滤", "数据管理"}
  if IsDebugPanelEnabled() then
    pageNames[#pageNames + 1] = "调试"
  end
  local currentPage = 1

  for i, pageName in ipairs(pageNames) do
    local navButton = CreateSidebarButton(sidebar, pageName, 142, 38, i == 1)
    if navButton then
      navButton:SetPoint("TOP", sidebar, "TOP", 0, -12 - (i - 1) * 50)
      navButton.pageIndex = i
      navButtons[i] = navButton
      navButton:SetScript("OnClick", function()
        if currentPage == i then return end
        navButtons[currentPage]:SetActive(false)
        navButtons[i]:SetActive(true)
        for j = 1, #pagePanels do pagePanels[j]:Hide() end
        pagePanels[i]:Show()
        currentPage = i
      end)
    end
  end

  for i = 1, #pageNames do
    local panel = CreateFrame("Frame", nil, contentContainer)
    panel:SetAllPoints(contentContainer)
    panel:Hide()
    pagePanels[i] = panel
  end

  frame.tabButtons = navButtons

  local listPanel = pagePanels[1]
  UI.CreateListPanel(listPanel)
  frame.listPanel = listPanel

  UI.CreateMeetingStoneSettingsPanel(pagePanels[2])
  UI.CreateMeetingStoneFilterPanel(pagePanels[3])
  UI.CreateDataManagementPanel(pagePanels[4], listPanel)
  if pagePanels[5] then
    frame.debugPanel = pagePanels[5]
    UI.CreateDebugPanel(pagePanels[5])
  end

  -- Bottom bar with author
  local bottomBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  bottomBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  bottomBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  bottomBar:SetHeight(36)
  bottomBar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(bottomBar, "SetBackdropColor", {0.055, 0.055, 0.07, 0.90})
  SetColor(bottomBar, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.40})

  local authorLabel = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  authorLabel:SetPoint("LEFT", bottomBar, "LEFT", 16, 0)
  authorLabel:SetText("作者：晴昼秋岚#5278")
  SetColor(authorLabel, "SetTextColor", {0.55, 0.55, 0.60, 1})

  -- Bottom close button
  local bottomCloseBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(bottomBar, "关闭", 80, 24, function() LayerManager.HideClass1() end)
  if bottomCloseBtn and bottomCloseBtn.SetPoint then
    bottomCloseBtn:SetPoint("RIGHT", bottomBar, "RIGHT", -16, 0)
  end

  pagePanels[1]:Show()
  UI.RefreshListPanel(listPanel)
  LayerManager.ShowClass1(frame)
end

function UI.RefreshManagementUIIfOpen()
  local frame = _G["RememberNoobManagementFrame"]
  if frame and frame:IsShown() and frame.listPanel then
    UI.RefreshListPanel(frame.listPanel)
  end
end

function UI.ToggleDebugPanel()
  local enabled = not IsDebugPanelEnabled()
  if ns.Config and ns.Config.Set then
    ns.Config.Set("debug.showPanel", enabled)
  end
  print("|cff66a8abRememberNoob: 调试标签" .. (enabled and "已显示" or "已隐藏") .. "|r")
  if enabled or _G["RememberNoobManagementFrame"] then
    UI.ShowManagementUI()
  end
end
