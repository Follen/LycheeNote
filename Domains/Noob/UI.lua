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

function UI.CreateListPanel(listPanel)
  local headers = {"玩家姓名", "服务器名称", "职业专精", "加入时间", "加入原因"}
  local columnWidths = {110, 110, 120, 100, 220}

  local headerFrame = CreateFrame("Frame", nil, listPanel, "BackdropTemplate")
  headerFrame:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 0, 0)
  headerFrame:SetSize(680, 30)
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
  scrollFrame:SetSize(680, 340)
  StyleScrollBar(scrollFrame)
  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(660, 1)
  scrollFrame:SetScrollChild(content)

  listPanel.scrollFrame = scrollFrame
  listPanel.content = content
  listPanel.columnWidths = columnWidths
end

function UI.RefreshListPanel(listPanel)
  if not listPanel.content then return end
  local content = listPanel.content
  local columnWidths = listPanel.columnWidths or {110, 110, 120, 100, 220}

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
    row:SetSize(660, baseRowHeight)
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
    tipText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -20)
  end

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", tipText or panel, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetSize(560, 260)

  -- Input backdrop
  local inputBg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
  inputBg:SetSize(540, 260)
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
    tipText:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, -20)
  end

  local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", tipText or panel, "BOTTOMLEFT", 0, -10)
  scrollFrame:SetSize(560, 260)

  local displayBg = CreateFrame("Frame", nil, scrollFrame, "BackdropTemplate")
  displayBg:SetSize(540, 260)
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

function UI.ShowManagementUI()
  if _G["RememberNoobManagementFrame"] then
    LayerManager.HideClass1()
    _G["RememberNoobManagementFrame"] = nil
  end

  local frame = CreateFrame("Frame", "RememberNoobManagementFrame", UIParent, "BackdropTemplate")
  frame:SetSize(740, 500)
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

  -- Tab bar
  local tabContainer = CreateFrame("Frame", nil, frame)
  tabContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -45)
  tabContainer:SetSize(700, 30)

  local tabButtons = {}
  local tabPanels = {}
  local tabNames = {"笨蛋列表", "导入数据", "导出数据"}
  local tabWidth = 100
  local currentTab = 1

  for i, tabName in ipairs(tabNames) do
    local tabBtn = Controls and Controls.CreateTabButton and
      Controls.CreateTabButton(tabContainer, tabName, tabWidth, 26, i == 1)
    if tabBtn then
      tabBtn:SetPoint("LEFT", tabContainer, "LEFT", (i - 1) * (tabWidth + 5), 0)
      tabBtn.tabIndex = i
      tabButtons[i] = tabBtn
      tabBtn:SetScript("OnClick", function()
        if currentTab == i then return end
        tabButtons[currentTab]:SetActive(false)
        tabButtons[i]:SetActive(true)
        for j = 1, #tabPanels do tabPanels[j]:Hide() end
        tabPanels[i]:Show()
        currentTab = i
      end)
    end
  end

  -- Content area
  local contentContainer = CreateFrame("Frame", nil, frame)
  contentContainer:SetPoint("TOPLEFT", tabContainer, "BOTTOMLEFT", 0, -10)
  contentContainer:SetSize(700, 380)

  for i = 1, 3 do
    local panel = CreateFrame("Frame", nil, contentContainer)
    panel:SetAllPoints(contentContainer)
    panel:Hide()
    tabPanels[i] = panel
  end

  frame.tabButtons = tabButtons

  -- List tab
  local listPanel = tabPanels[1]
  UI.CreateListPanel(listPanel)
  frame.listPanel = listPanel

  -- Import tab
  UI.CreateImportPanel(tabPanels[2], listPanel)

  -- Export tab
  UI.CreateExportPanel(tabPanels[3])

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

  tabPanels[1]:Show()
  UI.RefreshListPanel(listPanel)
  LayerManager.ShowClass1(frame)
end

function UI.RefreshManagementUIIfOpen()
  local frame = _G["RememberNoobManagementFrame"]
  if frame and frame:IsShown() and frame.listPanel then
    UI.RefreshListPanel(frame.listPanel)
  end
end
