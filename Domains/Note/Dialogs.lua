--- 标记与编辑弹窗
-- 两个弹窗共用同一套外壳、控件与生命周期：首次创建后复用，不重复建壳。
-- 职业专精异步返回时只更新文字，不重建控件。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Theme = LN.Theme
local Components = LN.Components
local Layer = LN.Layer

local Dialogs = {}
LN.Dialogs = Dialogs

local metrics = Theme.Metrics
local shells = {}

local function SetStatus(shell, text, token)
  if shell.status then Components.SetText(shell.status, text) end
  if shell.input and shell.input.__lnField then
    shell.input.__lnField:SetInvalid(token == "danger")
  end
end

--- 通用弹窗外壳：标题、关闭按钮、单行输入、两个动作按钮、状态行。
local function EnsureShell(key, title)
  local shell = shells[key]
  if shell then return shell end

  local frame = Components.CreateWindow(UIParent, {
    width = metrics.dialogWidth,
    height = metrics.dialogHeight,
  })
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetFrameLevel(100)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, -40)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnHide", function()
    Components.HideTooltip()
  end)

  local heading = Components.CreateText(frame, title, "title", "text", "LEFT")
  Theme:Anchor(heading, "TOPLEFT", frame, "TOPLEFT", metrics.dialogInset, -metrics.dialogInset)

  local close = Components.CreateCloseButton(frame, function() Layer.HideModal(frame) end)
  Theme:Anchor(close.frame, "TOPRIGHT", frame, "TOPRIGHT", -metrics.dialogInset + 4, -metrics.dialogInset + 2)

  local subject = Components.CreateText(frame, "", "body", "accentHover", "LEFT")
  Theme:Anchor(subject, "TOPLEFT", frame, "TOPLEFT", metrics.dialogInset, -metrics.dialogInset - 28)

  local spec = Components.CreateText(frame, "", "meta", "textMuted", "LEFT")
  Theme:Anchor(spec, "TOPLEFT", frame, "TOPLEFT", metrics.dialogInset, -metrics.dialogInset - 50)

  local prompt = Components.CreateText(frame, "理由", "meta", "textDim", "LEFT")
  Theme:Anchor(prompt, "TOPLEFT", frame, "TOPLEFT", metrics.dialogInset, -metrics.dialogInset - 76)

  local input = Components.CreateInput(frame, { width = metrics.dialogWidth - metrics.dialogInset * 2, height = 34 })
  Theme:Anchor(input, "TOPLEFT", frame, "TOPLEFT", metrics.dialogInset, -metrics.dialogInset - 98)
  input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  local status = Components.CreateText(frame, "", "meta", "textDim", "LEFT")
  Theme:Anchor(status, "BOTTOMLEFT", frame, "BOTTOMLEFT", metrics.dialogInset, metrics.dialogInset + 36)

  local confirm = Components.CreateActionButton(frame, { text = "确认", width = 100, primary = true })
  Theme:Anchor(confirm.frame, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -metrics.dialogInset, metrics.dialogInset)

  local cancel = Components.CreateActionButton(frame, { text = "取消", width = 84 })
  Theme:Anchor(cancel.frame, "RIGHT", confirm.frame, "LEFT", -8, 0)
  cancel.frame:SetScript("OnClick", function() Layer.HideModal(frame) end)

  shell = {
    frame = frame, heading = heading, subject = subject, spec = spec,
    input = input, status = status, confirm = confirm, cancel = cancel,
  }
  shells[key] = shell
  return shell
end

--- 异步专精：等待中不写入，超时视为未获取。
local function IsPending(value)
  return type(value) == "string" and value:find("检视中", 1, true) ~= nil
end

function Dialogs.ShowAddDialog(playerName, server, unit)
  if LN.Layer.HasModal() then return end

  local targetServer = server
  local targetUnit
  if unit and UnitExists(unit) and UnitIsPlayer(unit) then
    local unitName = UnitName(unit)
    if unitName and unitName:gsub("%-.*", "") == playerName then
      targetUnit = unit
      if not targetServer or targetServer == "" then
        local _, unitServer = UnitName(unit)
        targetServer = unitServer
      end
    end
  end
  if not targetServer or targetServer == "" then targetServer = GetRealmName() end

  local shell = EnsureShell("add", "添加记录")
  local frame = shell.frame

  Components.SetText(shell.subject, playerName .. "-" .. tostring(targetServer))
  Components.SetText(shell.spec, "职业专精：检测中…")
  Components.SetText(shell.input, "")
  Components.SetText(shell.status, "")
  Components.SetText(shell.confirm.label, "写入记录")
  SetStatus(shell, "")

  local saved = false
  local savedReason = "无理由"
  local pendingSpec
  local saveRequested = false

  local function Commit(classSpec)
    if saved or IsPending(classSpec) then return false end
    saved = true
    if not classSpec or classSpec:find("检视超时", 1, true) then classSpec = "尚未获取" end
    LN.Notes.Add(playerName, savedReason, targetServer, classSpec)
    Layer.HideModal(frame)
    return true
  end

  local function OnSpec(value, isFinal)
    pendingSpec = value
    Components.SetClassSpecText(shell.spec, "职业专精：", value)
    if saveRequested then Commit(value, isFinal) end
  end

  shell.input:SetScript("OnEnterPressed", function() shell.confirm.frame:Click() end)
  shell.confirm.frame:SetScript("OnClick", function()
    local reason = LN.Trim(shell.input:GetText())
    if reason == "" then
      SetStatus(shell, "理由不能为空。", "danger")
      return
    end
    savedReason = reason
    if targetUnit and UnitExists(targetUnit) then
      saveRequested = true
      if pendingSpec == nil then
        LN.Inspect.GetClassSpec(targetUnit, OnSpec)
      else
        Commit(pendingSpec)
      end
    else
      saved = true
      LN.Notes.Add(playerName, reason, targetServer)
      Layer.HideModal(frame)
    end
  end)

  Layer.ShowModal(frame)
  if targetUnit then
    local initial = LN.Inspect.GetClassSpec(targetUnit, OnSpec)
    pendingSpec = initial
    Components.SetClassSpecText(shell.spec, "职业专精：", initial)
  else
    Components.SetText(shell.spec, "职业专精：尚未获取")
  end
  shell.input:SetFocus()
end

function Dialogs.ShowEditDialog(playerName, server, onChanged)
  if type(server) == "function" then
    onChanged = server
    server = nil
  end
  if LN.Layer.HasModal() then return end

  local record = LN.Notes.Get(playerName, server)
  if not record then return end

  local shell = EnsureShell("edit", "编辑记录")
  local frame = shell.frame

  Components.SetText(shell.subject, playerName .. "-" .. tostring(record.server or GetRealmName()))
  Components.SetClassSpecText(shell.spec, "职业专精：", record.classSpec)
  Components.SetText(shell.input, record.reason or "")
  Components.SetText(shell.confirm.label, "保存")
  SetStatus(shell, "")

  shell.input:SetScript("OnEnterPressed", function() shell.confirm.frame:Click() end)
  shell.confirm.frame:SetScript("OnClick", function()
    local reason = LN.Trim(shell.input:GetText())
    if reason == "" then
      SetStatus(shell, "理由不能为空。", "danger")
      return
    end
    LN.Notes.SetReason(playerName, record.server, reason)
    LN.Log.Success("已更新 " .. playerName .. " 的理由。")
    Layer.HideModal(frame)
    if onChanged then onChanged() end
  end)

  Layer.ShowModal(frame)
  shell.input:SetFocus()
end
