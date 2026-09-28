--- 荔枝笔记主窗口
-- 侧栏导航 + 内容区，几何与控件取自 Lychee 启动器：头/底 56、行高 46 行距 6、
-- 底部 28 命中 / 18 图形的联系入口。侧栏的「当前项」沿用 Lychee 的 2 × 22 红条。
-- 首次打开惰性创建，之后复用；页面切换只改显隐，不重建控件。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Theme = LN.Theme
local Components = LN.Components
local Layer = LN.Layer
local Motion = LN.Motion

local UI = {}
LN.UI = UI

local metrics = Theme.Metrics
local EXPORT_PREFIX = "LN-"

--- 行池上限与名单长度无关：视口最多 7 行，余量覆盖缩放变化。
local MAX_ROWS = 12
local ROW_STRIDE = metrics.rowHeight + metrics.rowGap
local HEADER_ROW_HEIGHT = 24
local HEADER_ROW_GAP = 6

local NAV_NAMES = { "记录名单", "设置" }

--- 列偏移合计 556（去掉序号列后由内容区宽度决定），末列吃满剩余宽度。
local COLUMNS = {
  { key = "name", title = "玩家", x = 0, width = 112, role = "body" },
  { key = "server", title = "服务器", x = 112, width = 104, role = "meta" },
  { key = "classSpec", title = "职业专精", x = 216, width = 112, role = "meta" },
  { key = "timestamp", title = "加入时间", x = 328, width = 84, role = "meta" },
  { key = "reason", title = "理由", x = 412, width = 144, role = "meta" },
}

--- 底部联系入口，与 Lychee 中文版一致：作者微信 + GitHub。
local SOCIAL = {
  { icon = "wechat", title = "作者微信", code = "wechat-contact" },
  { icon = "github", title = "GitHub", url = "https://github.com/Follen/LycheeNote" },
}

local window
local headerLogo
local navItems = {}
local pages = {}
local rowPool = {}
local listState
local currentPage = 0

-- ---------------------------------------------------------------- 列表行

local function FormatTimestamp(timestamp)
  if type(timestamp) ~= "number" or timestamp <= 0 then return "未知" end
  return date("%y/%m/%d", timestamp)
end

local function ApplyRow(row, record)
  local cells = row.cells
  Components.SetText(cells.name, record.name)
  Components.SetText(cells.server, record.server or GetRealmName())
  Components.SetText(cells.classSpec, record.classSpec or "尚未获取")
  Components.SetText(cells.timestamp, FormatTimestamp(record.timestamp))
  Components.SetText(cells.reason, record.reason or "无理由")

  local rgb = Components.GetClassSpecColor(record.classSpec)
  if rgb then
    cells.classSpec:SetTextColor(rgb[1], rgb[2], rgb[3])
  else
    Theme:SetTextColor(cells.classSpec, "textMuted")
  end
  Theme:SetTextColor(cells.reason, "textMuted")
  row.record = record
end

--- 释放行的数据与浮层归属；控件留在池里复用。
local function ReleaseRow(row)
  row.record = nil
  Components.HideTooltip(row.frame)
  Components.HideActionMenu(row.frame)
end

local function CreateHeaderRow(parent)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(metrics.resultTileWidth, HEADER_ROW_HEIGHT)
  for _, column in ipairs(COLUMNS) do
    local header = Components.CreateText(frame, column.title, "meta", "textDim", "LEFT")
    Theme:Anchor(header, "LEFT", frame, "LEFT", column.x, 0)
    column.header = header
  end
  return frame
end

local function CreateRow(parent)
  local row = Components.CreateListRow(parent, { width = metrics.resultTileWidth })
  local cells = {}
  for _, column in ipairs(COLUMNS) do
    local cell = Components.CreateText(row.frame, "", column.role,
      column.key == "name" and "text" or "textMuted", "LEFT")
    cell:SetWordWrap(false)
    cell:SetMaxLines(1)
    cell:SetWidth(column.width - 8)
    Theme:Anchor(cell, "LEFT", row.frame, "LEFT", column.x, 0)
    cells[column.key] = cell
  end
  row.cells = cells

  row.frame:RegisterForClicks("RightButtonUp")
  row.frame:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and self.record then
      LN.Menus.ShowRowActions(self, self.record.name, self.record.server, UI.RefreshList)
    end
  end)
  row.frame:HookScript("OnEnter", function(self)
    if not self.record then return end
    Components.ShowTooltip(self, {
      self.record.name .. "-" .. tostring(self.record.server),
      self.record.classSpec or "尚未获取",
      FormatTimestamp(self.record.timestamp),
      self.record.reason or "无理由",
    })
  end)
  row.frame:HookScript("OnLeave", function(self)
    Components.HideTooltip(self)
  end)

  rowPool[#rowPool + 1] = row
  return row
end

local function UpdateEmptyState(count)
  if not listState then return end
  Theme:SetShown(listState.empty, count == 0)
end

function UI.RefreshList()
  if not listState or not window or not window:IsShown() then return end
  local records = LN.Notes.List()
  local content = listState.view.content
  local width = metrics.resultTileWidth

  Theme:Anchor(listState.headerRow, "TOPLEFT", content, "TOPLEFT", 0, 0)

  local viewport = listState.view.frame
  local available = math.max(1,
    math.floor(((viewport:GetHeight() or 1) - HEADER_ROW_HEIGHT - HEADER_ROW_GAP) / ROW_STRIDE))
  local visible = math.min(#records, available, MAX_ROWS)

  for index = 1, visible do
    local row = rowPool[index] or CreateRow(content)
    Theme:SetSize(row.frame, width, metrics.rowHeight)
    Theme:Anchor(row.frame, "TOPLEFT", content, "TOPLEFT", 0,
      -HEADER_ROW_HEIGHT - HEADER_ROW_GAP - (index - 1) * ROW_STRIDE)
    Theme:SetShown(row.frame, true)
    ApplyRow(row, records[index])
  end
  for index = visible + 1, #rowPool do
    local row = rowPool[index]
    ReleaseRow(row)
    Theme:SetShown(row.frame, false)
  end

  Theme:SetSize(content, width,
    HEADER_ROW_HEIGHT + HEADER_ROW_GAP + math.max(#records, available) * ROW_STRIDE)
  listState.view.Sync()
  UpdateEmptyState(#records)
end

-- ---------------------------------------------------------------- 记录名单页

local function CreateListPage(parent)
  local view = Components.CreateScrollView(parent)
  listState = { view = view }
  listState.headerRow = CreateHeaderRow(view.content)

  local empty = Components.CreateText(parent, "还没有记录", "title", "textDim", "CENTER")
  Theme:Anchor(empty, "CENTER", view.frame, "CENTER", 0, 0)
  listState.empty = empty
  Theme:SetShown(empty, false)
end

-- ---------------------------------------------------------------- 设置页

local function DecodeImport(text)
  if text:sub(1, #EXPORT_PREFIX) ~= EXPORT_PREFIX then
    return nil, "缺少 " .. EXPORT_PREFIX .. " 前缀"
  end
  local payload = text:sub(#EXPORT_PREFIX + 1)
  if payload == "" or not payload:match("^[A-Za-z0-9+/]*=*$") then
    return nil, "不是有效的 Base64 文本"
  end
  local ok, decoded = pcall(LN.Notes.DecodeBase64, payload)
  if not ok then return nil, "Base64 解码失败" end
  local ok2, records = pcall(LN.Notes.Parse, decoded)
  if not ok2 or type(records) ~= "table" then return nil, "数据解析失败" end
  return records, nil
end

local SETTINGS = {
  { key = "enabled", name = "启用插件", detail = "关闭后停止右键标记与集合石高亮" },
  { key = "askReason", name = "标记时询问理由", detail = "关闭后直接记入「无理由」" },
  { key = "reduceMotion", name = "动态效果", detail = "关闭后窗口与控件的过渡动画直接落定" },
}

local function CreateToggleRow(parent, item, index)
  local row = CreateFrame("Frame", nil, parent)
  row:SetSize(metrics.resultTileWidth, metrics.rowHeight)
  Theme:Anchor(row, "TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_STRIDE)

  local name = Components.CreateText(row, item.name, "body", "text", "LEFT")
  Theme:Anchor(name, "TOPLEFT", row, "TOPLEFT", 0, -7)
  local detail = Components.CreateText(row, item.detail, "meta", "textMuted", "LEFT")
  Theme:Anchor(detail, "TOPLEFT", name, "BOTTOMLEFT", 0, -3)

  local stateText = Components.CreateText(row, "", "meta", "textMuted", "RIGHT")
  Theme:Anchor(stateText, "RIGHT", row, "RIGHT", -44, 0)

  local toggle = Components.CreateToggle(row, function(checked)
    LN.Config.SetBool(item.key, checked)
    Components.SetText(stateText, checked and "开启" or "关闭")
    if item.key == "reduceMotion" and checked and Motion then Motion.FinishAll() end
  end)
  Theme:Anchor(toggle.frame, "RIGHT", row, "RIGHT", 0, 0)

  row.toggle, row.stateText, row.key = toggle, stateText, item.key
  return row
end

--- 数据段沿用荔枝的天赋方案：meta 灰字小节头、28 高文字按钮、
--- field 质感的滚动文本区、一行状态文字。不再是一排悬空的小按钮。
local DATA_ACTIONS = {
  { text = "导出" },
  { text = "导入" },
  { text = "全选" },
}

local function CreateSettingsPage(parent)
  local scroll = Components.CreateScrollView(parent)
  local content = scroll.content
  Theme:SetSize(content, metrics.resultTileWidth, 1)

  local rows = {}
  for index, item in ipairs(SETTINGS) do
    rows[index] = CreateToggleRow(content, item, index)
  end

  local dataTop = #SETTINGS * ROW_STRIDE + 24

  local sectionHeader = Components.CreateText(content, "数据", "meta", "textDim", "LEFT")
  Theme:Anchor(sectionHeader, "TOPLEFT", content, "TOPLEFT", 0, -dataTop)

  local actions = CreateFrame("Frame", nil, content)
  actions:SetSize(metrics.resultTileWidth, 28)
  Theme:Anchor(actions, "TOPLEFT", content, "TOPLEFT", 0, -(dataTop + 24))

  local status = Components.CreateText(content, "", "meta", "textMuted", "LEFT")
  Theme:Anchor(status, "TOPLEFT", content, "TOPLEFT", 0, -(dataTop + 58 + metrics.textareaHeight + 8))

  local area = Components.CreateTextArea(content, { height = metrics.textareaHeight })
  Theme:SetSize(area.frame, metrics.resultTileWidth, metrics.textareaHeight)
  Theme:Anchor(area.frame, "TOPLEFT", content, "TOPLEFT", 0, -(dataTop + 58))

  local function BuildExport()
    local records = LN.Notes.List()
    if #records == 0 then
      Components.SetText(status, "名单为空")
      return
    end
    local ok, serialized = pcall(LN.Notes.Serialize, records)
    if not ok or not serialized or serialized == "" then
      Components.SetText(status, "序列化失败")
      return
    end
    local ok2, encoded = pcall(LN.Notes.EncodeBase64, serialized)
    if not ok2 then
      Components.SetText(status, "编码失败")
      return
    end
    area.box:SetText(EXPORT_PREFIX .. encoded)
    area.box:SetCursorPosition(0)
    Components.SetText(status, "已生成 " .. #records .. " 条")
  end

  local function RunImport()
    local text = (area.box:GetText() or ""):match("^%s*(.-)%s*$")
    if text == "" then
      Components.SetText(status, "没有可导入的内容")
      return
    end
    local records, err = DecodeImport(text)
    if not records then
      Components.SetText(status, err)
      return
    end
    local merged, skipped = LN.Notes.Merge(records)
    Components.SetText(status, "已导入 " .. merged .. " 条"
      .. (skipped > 0 and ("，跳过 " .. skipped) or ""))
    UI.RefreshList()
  end

  local handlers = { [1] = BuildExport, [2] = RunImport, [3] = function() area:FocusAndSelect() end }
  local previous
  for index, entry in ipairs(DATA_ACTIONS) do
    local button = Components.CreateNavigationButton(actions, {
      width = 48, height = 28, text = entry.text, onClick = handlers[index],
    })
    if previous then
      Theme:Anchor(button.frame, "LEFT", previous, "RIGHT", 16, 0)
    else
      Theme:Anchor(button.frame, "LEFT", actions, "LEFT", 0, 0)
    end
    previous = button.frame
  end

  Theme:SetSize(content, metrics.resultTileWidth, dataTop + 58 + metrics.textareaHeight + 30)

  local function Refresh()
    for _, row in ipairs(rows) do
      local checked = LN.Config.GetBool(row.key)
      row.toggle:SetChecked(checked)
      Components.SetText(row.stateText, checked and "开启" or "关闭")
    end
  end
  parent:HookScript("OnShow", Refresh)
  Refresh()
end

-- ---------------------------------------------------------------- 外壳

local function CreateHeader(frame)
  local header = CreateFrame("Frame", nil, frame)
  Theme:Anchor(header, "TOPLEFT", frame, "TOPLEFT", 0, 0)
  Theme:Anchor(header, "TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  header:SetHeight(metrics.headerHeight)

  local logo = header:CreateTexture(nil, "ARTWORK")
  logo:SetSize(metrics.brandIconSize, metrics.brandIconSize)
  Theme:Anchor(logo, "LEFT", header, "LEFT", metrics.contentPadding, 0)
  if logo.SetTexCoord then logo:SetTexCoord(0, 1, 0, 1) end
  logo:SetTexture(Theme.Media.logo)
  headerLogo = logo

  local title = Components.CreateText(header,
    Theme.BrandColor .. "荔枝" .. Theme.BrandColorClose .. "笔记", "brand", "text", "LEFT")
  Theme:Anchor(title, "LEFT", logo, "RIGHT", metrics.brandLabelGap, 0)

  local close = Components.CreateCloseButton(header, function() Layer.HideBase() end)
  Theme:Anchor(close.frame, "RIGHT", header, "RIGHT", -metrics.contentPadding, 0)
  return header
end

--- content 必须是窗口的子框体，否则窗口 Hide 时内容仍留在 UIParent 上。
local function CreateWindow()
  local frame = Components.CreateWindow(UIParent, {
    width = metrics.windowWidth,
    height = metrics.windowHeight,
  })
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnHide", function()
    Components.HideTooltip()
    Components.HideActionMenu()
  end)
  window = frame

  CreateHeader(frame)

  -- 侧栏：无底色块、无分隔线，只靠文字明度与红色竖条表达状态。
  local sidebar = CreateFrame("Frame", nil, frame)
  Theme:Anchor(sidebar, "TOPLEFT", frame, "TOPLEFT", 0, -metrics.headerHeight)
  Theme:Anchor(sidebar, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, metrics.footerHeight)
  sidebar:SetWidth(metrics.sidebarWidth)

  local navY = 8
  for index, name in ipairs(NAV_NAMES) do
    local item = Components.CreateNavItem(sidebar, name, function() UI.SelectPage(index) end)
    Theme:Anchor(item.frame, "TOPLEFT", sidebar, "TOPLEFT", metrics.navInset, -navY)
    navY = navY + metrics.navHeight + metrics.navGap
    navItems[index] = item
  end

  local body = CreateFrame("Frame", nil, frame)
  Theme:Anchor(body, "TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
  Theme:Anchor(body, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -metrics.contentPadding, metrics.footerHeight)

  local footer = CreateFrame("Frame", nil, frame)
  Theme:Anchor(footer, "BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
  Theme:Anchor(footer, "BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
  footer:SetHeight(metrics.footerHeight)
  Components.CreateSocialBar(footer, SOCIAL)

  return frame, body
end

-- ---------------------------------------------------------------- 页面切换

function UI.SelectPage(index)
  if not window then return end
  index = math.max(1, math.min(#NAV_NAMES, index))
  if currentPage == index then return end
  for page = 1, #pages do Theme:SetShown(pages[page], page == index) end
  for page = 1, #navItems do navItems[page]:SetSelected(page == index) end
  currentPage = index
  if Motion then Motion:Slide(pages[index], 1) end
  if index == 1 then UI.RefreshList() end
end

function UI.RefreshIfOpen()
  if window and window:IsShown() then UI.RefreshList() end
end

function UI.Toggle()
  if window and window:IsShown() then
    Layer.HideBase()
    return false
  end
  UI.Show()
  return true
end

function UI.Show()
  if not window then
    local body
    window, body = CreateWindow()
    for index = 1, #NAV_NAMES do
      local page = CreateFrame("Frame", nil, body)
      Theme:Anchor(page, "TOPLEFT", body, "TOPLEFT", metrics.contentPadding, 0)
      Theme:Anchor(page, "BOTTOMRIGHT", body, "BOTTOMRIGHT", -6, 0)
      page:Hide()
      pages[index] = page
    end
    CreateListPage(pages[1])
    CreateSettingsPage(pages[2])
  end

  currentPage = 0
  UI.SelectPage(1)
  UI.RefreshList()
  Layer.ShowBase(window)
  if Motion and headerLogo then Motion:Brand(headerLogo, metrics.brandIconSize) end
  return true
end

--- 生命周期钩子：窗口在首次打开时才惰性创建，这里没有加载期工作。
function UI.Initialize() end
