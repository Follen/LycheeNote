local ADDON_NAME, ns = ...

local Dialogs = {}
ns.RememberNoobDialogs = Dialogs

local unpack = unpack or table.unpack
local Controls = ns.RememberNoobControls

local DIALOG_W = 400
local DIALOG_H = 290

local function SetColor(region, methodName, color)
  if region and region[methodName] and color then
    region[methodName](region, unpack(color))
  end
end

local function ApplyPanel(frame)
  if Controls and Controls.ApplyBackdrop then
    Controls.ApplyBackdrop(frame, "PANEL_BG")
  else
    -- Fallback: apply backdrop directly
    if frame and frame.SetBackdrop then
      frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
      })
      SetColor(frame, "SetBackdropColor", {0.07, 0.07, 0.09, 0.88})
      SetColor(frame, "SetBackdropBorderColor", {0.20, 0.20, 0.23, 0.56})
    end
  end
end

local function CreateEditBoxBg(parent, width, height)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetSize(width, height)
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  SetColor(frame, "SetBackdropColor", {0.12, 0.12, 0.14, 0.90})
  SetColor(frame, "SetBackdropBorderColor", {0.22, 0.22, 0.26, 0.70})
  return frame
end

local function CreateEditBox(parent, width, height)
  local box = CreateFrame("EditBox", nil, parent)
  box:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -8)
  box:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, 8)
  box:SetMultiLine(true)
  box:SetAutoFocus(true)
  box:SetFontObject("ChatFontNormal")
  box:SetMaxLetters(200)
  return box
end

--- Reason Dialog

function Dialogs.ShowReasonDialog(playerName, server, unit)
  if _G["RememberNoobReasonDialog"] and _G["RememberNoobReasonDialog"]:IsShown() then return end

  local targetServer = server

  -- Validate unit: must exist and point to the right player.
  local targetUnit = nil
  if unit and UnitExists(unit) and UnitIsPlayer(unit) then
    local uName = UnitName(unit)
    if uName and uName:gsub("%-.*", "") == playerName then
      targetUnit = unit
      if not targetServer or targetServer == "" then
        local _, unitServer = UnitName(unit)
        targetServer = unitServer
      end
    end
  end
  if not targetServer or targetServer == "" then
    targetServer = GetRealmName()
  end

  local dialog = CreateFrame("Frame", "RememberNoobReasonDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(DIALOG_W, DIALOG_H)
  dialog:SetPoint("CENTER")
  dialog:EnableMouse(true)
  dialog:SetMovable(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  dialog:SetToplevel(true)
  dialog:SetClampedToScreen(true)
  ApplyPanel(dialog)

  dialog:SetScript("OnHide", function(self)
    if _G["RememberNoobReasonDialog"] == self then
      _G["RememberNoobReasonDialog"] = nil
    end
  end)

  -- Close X
  local closeBtn = Controls and Controls.CreateCloseButton and
    Controls.CreateCloseButton(dialog, function() ns.RememberNoobLayerManager.HideClass2() end)
  if closeBtn and closeBtn.SetPoint then
    closeBtn:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -12, -12)
  end
  dialog.closeButton = closeBtn

  -- Title
  local title = Controls and Controls.CreateText and
    Controls.CreateText(dialog, "添加笨蛋标记", "GameFontHighlight", "VALUE_COLOR")
  if title and title.SetPoint then
    title:SetPoint("TOP", dialog, "TOP", 0, -16)
  end

  -- Player info row
  local infoText = "|cffff6600" .. playerName .. "-" .. targetServer .. "|r"
  local nameLabel = Controls and Controls.CreateText and
    Controls.CreateText(dialog, infoText, "GameFontNormal", "LABEL_COLOR")
  if nameLabel and nameLabel.SetPoint then
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -50)
  end

  -- Class / spec row
  local classSpecLabel = Controls and Controls.CreateText and
    Controls.CreateText(dialog, "职业专精: 获取中...", "GameFontNormal", "LABEL_COLOR")
  if classSpecLabel and classSpecLabel.SetPoint then
    classSpecLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -74)
  end

  if targetUnit then
    local currentClassSpec = ns.RememberNoobInspect.GetTargetClassSpec(targetUnit, function(updated)
      if classSpecLabel and classSpecLabel:IsShown() then
        if Controls and Controls.SetClassSpecText then
          Controls.SetClassSpecText(classSpecLabel, "职业专精: ", updated, "LABEL_COLOR")
        else
          classSpecLabel:SetText("职业专精: " .. (updated or "获取中..."))
        end
      end
    end)
    if Controls and Controls.SetClassSpecText then
      Controls.SetClassSpecText(classSpecLabel, "职业专精: ", currentClassSpec, "LABEL_COLOR")
    else
      classSpecLabel:SetText("职业专精: " .. (currentClassSpec or "获取中..."))
    end
  else
    classSpecLabel:SetText("职业专精: 尚未获取")
  end

  -- Reason label
  local reasonLabel = Controls and Controls.CreateText and
    Controls.CreateText(dialog, "他犯了什么罪:", "GameFontNormal", "LABEL_COLOR")
  if reasonLabel and reasonLabel.SetPoint then
    reasonLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -104)
  end

  -- Input box
  local inputBg = CreateEditBoxBg(dialog, 352, 60)
  inputBg:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -126)

  local editBox = CreateEditBox(inputBg, 352, 60)
  dialog.editBox = editBox

  -- Buttons
  local confirmBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(dialog, "送进监狱", 100, 28)
  if confirmBtn and confirmBtn.SetPoint then
    confirmBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -24, 20)
  end

  local cancelBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(dialog, "取消", 80, 28)
  if cancelBtn and cancelBtn.SetPoint then
    cancelBtn:SetPoint("RIGHT", confirmBtn, "LEFT", -10, 0)
  end
  if cancelBtn and cancelBtn.SetScript then
    cancelBtn:SetScript("OnClick", function()
      ns.RememberNoobLayerManager.HideClass2()
    end)
  end

  editBox:SetScript("OnEnterPressed", function() confirmBtn:Click() end)

  if confirmBtn and confirmBtn.SetScript then
    confirmBtn:SetScript("OnClick", function()
      local ok, err = pcall(function()
        local reason = editBox:GetText():trim()
        if reason == "" then reason = "无理由" end

        if targetUnit and UnitExists(targetUnit) then
          ns.RememberNoobInspect.GetTargetClassSpec(targetUnit, function(classSpec)
            ns.RememberNoobNoob.AddNoobMark(playerName, reason, targetServer, classSpec)
            ns.RememberNoobLayerManager.HideClass2()
          end)
        else
          ns.RememberNoobNoob.AddNoobMark(playerName, reason, targetServer)
          ns.RememberNoobLayerManager.HideClass2()
        end
      end)
      if not ok then
        print("|cffff0000RememberNoob错误: " .. tostring(err) .. "|r")
        ns.RememberNoobLayerManager.HideClass2()
      end
    end)
  end

  ns.RememberNoobLayerManager.ShowClass2(dialog)
end

--- Edit Reason Dialog

function Dialogs.ShowEditReasonDialog(playerName, refreshCallback)
  if _G["RememberNoobEditDialog"] and _G["RememberNoobEditDialog"]:IsShown() then return end

  local currentData = ns.db.noobs[playerName]
  if not currentData then return end

  local dialog = CreateFrame("Frame", "RememberNoobEditDialog", UIParent, "BackdropTemplate")
  dialog:SetSize(DIALOG_W, DIALOG_H)
  dialog:SetPoint("CENTER")
  dialog:EnableMouse(true)
  dialog:SetMovable(true)
  dialog:RegisterForDrag("LeftButton")
  dialog:SetScript("OnDragStart", dialog.StartMoving)
  dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
  dialog:SetToplevel(true)
  dialog:SetClampedToScreen(true)
  ApplyPanel(dialog)

  dialog:SetScript("OnHide", function(self)
    if _G["RememberNoobEditDialog"] == self then
      _G["RememberNoobEditDialog"] = nil
    end
    if refreshCallback then refreshCallback() end
  end)

  -- Close X
  local closeBtn = Controls and Controls.CreateCloseButton and
    Controls.CreateCloseButton(dialog, function() ns.RememberNoobLayerManager.HideClass2() end)
  if closeBtn and closeBtn.SetPoint then
    closeBtn:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -12, -12)
  end
  dialog.closeButton = closeBtn

  -- Title
  local title = Controls and Controls.CreateText and
    Controls.CreateText(dialog, "编辑备注", "GameFontHighlight", "VALUE_COLOR")
  if title and title.SetPoint then
    title:SetPoint("TOP", dialog, "TOP", 0, -16)
  end

  -- Player info
  local serverName = currentData.server or GetRealmName()
  local infoText = "|cffff6600" .. playerName .. "-" .. serverName .. "|r"
  local nameLabel = Controls and Controls.CreateText and
    Controls.CreateText(dialog, infoText, "GameFontNormal", "LABEL_COLOR")
  if nameLabel and nameLabel.SetPoint then
    nameLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -50)
  end

  -- Class spec
  local classSpec = currentData.classSpec or "尚未获取"
  local classSpecLabel = Controls and Controls.CreateText and
    Controls.CreateText(dialog, "职业专精: " .. classSpec, "GameFontNormal", "LABEL_COLOR")
  if classSpecLabel and classSpecLabel.SetPoint then
    classSpecLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -74)
  end
  if Controls and Controls.SetClassSpecText then
    Controls.SetClassSpecText(classSpecLabel, "职业专精: ", classSpec, "LABEL_COLOR")
  end

  -- Reason label
  local reasonLabel = Controls and Controls.CreateText and
    Controls.CreateText(dialog, "备注内容:", "GameFontNormal", "LABEL_COLOR")
  if reasonLabel and reasonLabel.SetPoint then
    reasonLabel:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -104)
  end

  -- Input box
  local inputBg = CreateEditBoxBg(dialog, 352, 60)
  inputBg:SetPoint("TOPLEFT", dialog, "TOPLEFT", 24, -126)

  local editBox = CreateEditBox(inputBg, 352, 60)
  editBox:SetText(currentData.reason or "")
  dialog.editBox = editBox

  -- Buttons
  local confirmBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(dialog, "确认", 100, 28)
  if confirmBtn and confirmBtn.SetPoint then
    confirmBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -24, 20)
  end

  local cancelBtn = Controls and Controls.CreateButton and
    Controls.CreateButton(dialog, "取消", 80, 28)
  if cancelBtn and cancelBtn.SetPoint then
    cancelBtn:SetPoint("RIGHT", confirmBtn, "LEFT", -10, 0)
  end
  if cancelBtn and cancelBtn.SetScript then
    cancelBtn:SetScript("OnClick", function() ns.RememberNoobLayerManager.HideClass2() end)
  end

  if confirmBtn and confirmBtn.SetScript then
    confirmBtn:SetScript("OnClick", function()
      local newReason = editBox:GetText():trim()
      if newReason == "" then newReason = "无理由" end
      currentData.reason = newReason
      print("|cff00ff00已更新 " .. playerName .. " 的备注！|r")
      ns.RememberNoobLayerManager.HideClass2()
      if refreshCallback then refreshCallback() end
    end)
  end

  editBox:SetScript("OnEnterPressed", function() confirmBtn:Click() end)

  ns.RememberNoobLayerManager.ShowClass2(dialog)
end
