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
    Controls.CreateText(parent, title, "GameFontHighlight", "VALUE_COLOR")
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

local function CreateConfigCheckButton(parent, label, description, configPath, yOffset)
  local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)
  row:SetSize(640, 58)
  row:EnableMouse(true)
  row:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(row, "SetBackdropColor", {0.075, 0.075, 0.095, 0.72})
  SetColor(row, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.40})

  local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
  check:SetPoint("LEFT", row, "LEFT", 10, 0)
  check:SetSize(24, 24)
  check:SetChecked(ns.Config and ns.Config.Get and ns.Config.Get(configPath) == true)
  check:SetScript("OnClick", function(self)
    if ns.Config and ns.Config.Set then
      ns.Config.Set(configPath, self:GetChecked() and true or false)
    end
  end)

  local labelText = Controls and Controls.CreateText and
    Controls.CreateText(row, label, "GameFontNormal", "VALUE_COLOR")
  if labelText and labelText.SetPoint then
    labelText:SetPoint("TOPLEFT", check, "TOPRIGHT", 8, 2)
  end

  local descText = Controls and Controls.CreateText and
    Controls.CreateText(row, description, "GameFontNormalSmall", "LABEL_COLOR")
  if descText and descText.SetPoint then
    descText:SetPoint("TOPLEFT", labelText or check, labelText and "BOTTOMLEFT" or "TOPRIGHT", 0, -5)
    descText:SetWidth(560)
    descText:SetJustifyH("LEFT")
  end

  row:SetScript("OnMouseUp", function()
    check:SetChecked(not check:GetChecked())
    if ns.Config and ns.Config.Set then
      ns.Config.Set(configPath, check:GetChecked() and true or false)
    end
  end)

  return row
end

function UI.CreateListPanel(listPanel)
  local headers = {"玩家姓名", "服务器名称", "职业专精", "加入时间", "加入原因"}
  local columnWidths = {100, 95, 115, 85, 225}

  local _, subtitleText = CreatePageTitle(listPanel, "笨蛋列表", "右键玩家条目可编辑备注或移除标记。")

  local headerFrame = CreateFrame("Frame", nil, listPanel, "BackdropTemplate")
  headerFrame:SetPoint("TOPLEFT", subtitleText or listPanel, subtitleText and "BOTTOMLEFT" or "TOPLEFT", 0, -16)
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

function UI.CreateMeetingStoneSettingsPanel(panel)
  local _, subtitleText = CreatePageTitle(panel, "集合石设置", "控制集合石列表中命中笨蛋名单时的展示和快捷处理方式。")

  local startY = -58
  CreateConfigCheckButton(
    panel,
    "是否显示图标",
    "命中笨蛋名单时，在集合石相关条目旁显示提示图标。",
    "meetingStone.showIcon",
    startY)
  CreateConfigCheckButton(
    panel,
    "是否标红高亮",
    "命中笨蛋名单时，将玩家姓名或所在条目用红色高亮。",
    "meetingStone.highlightNoob",
    startY - 68)
  CreateConfigCheckButton(
    panel,
    "是否启用一键拒绝笨蛋",
    "后续接入集合石申请列表后，允许对命中的申请人快速拒绝。",
    "meetingStone.enableOneClickReject",
    startY - 136)

  CreateWrappedText(
    panel,
    "这些开关会先保存配置；实际集合石列表标记和拒绝逻辑将在过滤功能确认后接入。",
    subtitleText or panel,
    0,
    -242,
    620)
end

function UI.CreateMeetingStoneFilterPanel(panel)
  local titleText = CreatePageTitle(panel, "集合石过滤", "这里先放过滤方案，等规则确认后再接入集合石实际列表和申请事件。")

  local planTitle = Controls and Controls.CreateText and
    Controls.CreateText(panel, "建议方案", "GameFontNormal", "VALUE_COLOR")
  if planTitle and planTitle.SetPoint then
    planTitle:SetPoint("TOPLEFT", titleText or panel, titleText and "BOTTOMLEFT" or "TOPLEFT", 0, -36)
  end

  local items = {
    "过滤对象：优先匹配申请人，其次可扩展到队伍成员和队长。",
    "命中来源：先只使用笨蛋列表，避免额外规则误伤正常玩家。",
    "处理动作：提供仅提示、标红显示、一键拒绝三个层级。",
    "例外规则：后续可加入好友、公会成员、当前队伍成员不处理。",
    "记录回溯：保存最近过滤记录，方便查看被拦截玩家和原因。",
  }

  local anchor = planTitle
  for index, text in ipairs(items) do
    local item = CreateWrappedText(panel, index .. ". " .. text, anchor or panel, 0, index == 1 and -12 or -10, 620)
    anchor = item
  end
end

function UI.CreateDataManagementPanel(panel, listPanel)
  local _, subtitleText = CreatePageTitle(panel, "数据管理", "导入、导出笨蛋列表数据，用于备份或分享。")

  local switchContainer = CreateFrame("Frame", nil, panel)
  switchContainer:SetPoint("TOPLEFT", subtitleText or panel, subtitleText and "BOTTOMLEFT" or "TOPLEFT", 0, -14)
  switchContainer:SetSize(640, 30)

  local content = CreateFrame("Frame", nil, panel)
  content:SetPoint("TOPLEFT", switchContainer, "BOTTOMLEFT", 0, -12)
  content:SetSize(640, 338)

  local importPanel = CreateFrame("Frame", nil, content)
  importPanel:SetAllPoints(content)
  local exportPanel = CreateFrame("Frame", nil, content)
  exportPanel:SetAllPoints(content)

  UI.CreateImportPanel(importPanel, listPanel)
  UI.CreateExportPanel(exportPanel)

  local importButton = Controls and Controls.CreateTabButton and
    Controls.CreateTabButton(switchContainer, "导入数据", 100, 26, true)
  local exportButton = Controls and Controls.CreateTabButton and
    Controls.CreateTabButton(switchContainer, "导出数据", 100, 26, false)

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
  frame:SetSize(860, 540)
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
  sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -48)
  sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 48)
  sidebar:SetWidth(150)
  sidebar:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(sidebar, "SetBackdropColor", {0.055, 0.055, 0.07, 0.72})
  SetColor(sidebar, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.40})

  local contentContainer = CreateFrame("Frame", nil, frame)
  contentContainer:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 18, 0)
  contentContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 48)

  local navButtons = {}
  local pagePanels = {}
  local pageNames = {"笨蛋列表", "集合石设置", "集合石过滤", "数据管理"}
  local currentPage = 1

  for i, pageName in ipairs(pageNames) do
    local navButton = Controls and Controls.CreateTabButton and
      Controls.CreateTabButton(sidebar, pageName, 126, 34, i == 1)
    if navButton then
      navButton:SetPoint("TOP", sidebar, "TOP", 0, -12 - (i - 1) * 42)
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
