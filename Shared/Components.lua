--- 荔枝笔记控件层
-- 公共控件只负责外观与状态，不决定保存、启停或业务动作。
-- 所有控件首次创建后复用；事件驱动，不使用常驻每帧回调。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Theme = LN.Theme
local Motion = LN.Motion
local Components = {}
LN.Components = Components

local function setShown(region, shown)
  shown = shown == true
  if not region or type(region.IsShown) ~= "function" then return false end
  if region:IsShown() == shown then return false end
  region:SetShown(shown)
  return true
end
Components.SetShown = setShown

local function setText(label, value)
  value = value or ""
  if not label or type(label.GetText) ~= "function" then return false end
  if label:GetText() == value then return false end
  label:SetText(value)
  return true
end
Components.SetText = setText

--- 统一文本创建。role 取 Theme.FontSizes 中的键。
function Components.CreateText(parent, text, role, colorToken, justifyH)
  if not parent or not parent.CreateFontString then return nil end
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  Theme:SetFont(label, role)
  Theme:SetTextColor(label, colorToken or "text")
  setText(label, text)
  label:SetJustifyH(justifyH or "LEFT")
  label:SetJustifyV("MIDDLE")
  return label
end

--- 文字按钮，与 Lychee 的 CreateNavigationButton 同形：透明底、无边框，
--- 常态文字色，悬停与按下只把前景转 accentHover，不加矩形底也不加下划线。
--- options.feedbackIcon 传入的纯导航图形会跟随同一个状态着色（彩色内容图标不要传）。
function Components.CreateNavigationButton(parent, options)
  options = options or {}
  local frame = CreateFrame("Button", nil, parent)
  frame:SetSize(options.width or 48, options.height or 24)

  local label = Components.CreateText(frame, options.text, options.role or "body", "text", "CENTER")
  Theme:Anchor(label, "CENTER", frame, "CENTER", 0, 0)

  local component = { frame = frame, label = label, enabled = true }

  function component:Refresh()
    local enabled = self.enabled ~= false
    local hovered = enabled and frame:IsMouseOver()
    Theme:SetTextColor(self.label, not enabled and "disabled"
      or hovered and "accentHover" or "text")
    if self.feedbackIcon then
      Theme:SetVertexColor(self.feedbackIcon, not enabled and "disabled"
        or hovered and "accentHover" or "textMuted")
    end
  end

  function component:SetText(value) setText(self.label, value) end

  function component:SetEnabled(enabled)
    enabled = enabled ~= false
    if self.enabled == enabled then return end
    self.enabled = enabled
    if enabled and frame.Enable then frame:Enable() else frame:Disable() end
    self:Refresh()
  end

  frame:SetScript("OnEnter", function() component:Refresh() end)
  frame:SetScript("OnLeave", function() component:Refresh() end)
  if options.onClick then
    frame:SetScript("OnClick", function(...)
      if component.enabled ~= false then options.onClick(...) end
    end)
  end
  component:Refresh()
  return component
end

--- 侧栏导航项，沿用 Lychee 的「当前项」语言：透明底、无分隔线，
--- 常态 textMuted，当前项文字转 text 并在左侧亮起 2 × 22 的荔枝红短条。
function Components.CreateNavItem(parent, text, onClick)
  local metrics = Theme.Metrics
  local frame = CreateFrame("Button", nil, parent)
  frame:SetSize(metrics.sidebarWidth - metrics.navInset * 2, metrics.navHeight)

  local bar = Theme:CreateSelectionBar(frame)
  Theme:Anchor(bar, "LEFT", frame, "LEFT", -metrics.navInset + 4, 0)

  local label = Components.CreateText(frame, text, "body", "textMuted", "LEFT")
  Theme:Anchor(label, "LEFT", frame, "LEFT", 16, 0)
  Theme:Anchor(label, "RIGHT", frame, "RIGHT", -8, 0)

  local component = { frame = frame, label = label, bar = bar }
  function component:Refresh()
    if self.selected then
      Theme:SetTextColor(self.label, "text")
      Theme:SetColorTexture(self.bar, "accent")
      if Motion then Motion:Fade(self.bar, 1) else setShown(self.bar, true) end
    else
      Theme:SetTextColor(self.label, frame:IsMouseOver() and "accentHover" or "textMuted")
      if Motion then Motion:Fade(self.bar, 0) else setShown(self.bar, false) end
    end
  end
  function component:SetSelected(selected)
    selected = selected == true
    if self.selected == selected then return false end
    self.selected = selected
    self:Refresh()
    return true
  end
  frame:SetScript("OnEnter", function() component:Refresh() end)
  frame:SetScript("OnLeave", function() component:Refresh() end)
  if onClick then frame:SetScript("OnClick", onClick) end
  component:Refresh()
  return component
end

--- 底部联系入口，与 Lychee 同形：28 命中区 / 18 图形 / 间距 8 / 右边距 28。
--- entries: { { icon, title, url } 或 { icon, title, code } }；code 走扫码图，url 走可复制输入框。
function Components.CreateSocialBar(parent, entries)
  local metrics = Theme.Metrics
  local media = "Interface\\AddOns\\LycheeNote\\Media\\About\\"
  local bar = CreateFrame("Frame", nil, parent)
  bar:SetSize(#entries * metrics.footerIconStride - 8, metrics.footerIconHit)
  Theme:Anchor(bar, "RIGHT", parent, "RIGHT", -metrics.footerInset, 0)

  local view = { frame = bar, buttons = {}, entries = entries }

  local function EnsurePopup()
    if view.backdrop then return end
    local backdrop = CreateFrame("Button", nil, UIParent)
    backdrop:SetAllPoints(UIParent)
    backdrop:SetFrameStrata("FULLSCREEN_DIALOG")
    backdrop:EnableMouse(true)
    local shade = backdrop:CreateTexture(nil, "BACKGROUND")
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.2)
    backdrop:SetScript("OnClick", function() view:Close() end)

    local popup = CreateFrame("Frame", nil, backdrop)
    popup:EnableMouse(true)
    popup:SetClampedToScreen(true)
    Theme:CreateRoundedSurface(popup, "window", metrics.radiusPanel)

    local title = Components.CreateText(popup, "", "body", "text", "LEFT")
    Theme:Anchor(title, "TOPLEFT", popup, "TOPLEFT", 16, -12)

    local close = Components.CreateNavigationButton(popup, { width = 24, height = 24, text = "×" })
    Theme:Anchor(close.frame, "TOPRIGHT", popup, "TOPRIGHT", -8, -6)
    close.frame:SetScript("OnClick", function() view:Close() end)

    local input = CreateFrame("EditBox", nil, popup)
    input:SetAutoFocus(false)
    input:SetHeight(28)
    input:SetTextInsets(8, 8, 0, 0)
    Theme:Anchor(input, "TOPLEFT", popup, "TOPLEFT", 16, -38)
    Theme:Anchor(input, "RIGHT", popup, "RIGHT", -16, 0)
    Components.StyleEditBox(input)
    Theme:SetFont(input, "body")
    Theme:SetTextColor(input, "text")
    input:SetScript("OnMouseUp", function(box) box:HighlightText() end)
    input:SetScript("OnEscapePressed", function() view:Close() end)

    local code = popup:CreateTexture(nil, "ARTWORK")
    code:SetSize(metrics.popupCodeSize, metrics.popupCodeSize)
    Theme:Anchor(code, "TOP", popup, "TOP", 0, -40)

    local hint = Components.CreateText(popup, "", "meta", "textMuted", "CENTER")
    Theme:Anchor(hint, "BOTTOM", popup, "BOTTOM", 0, 12)

    view.backdrop, view.popup, view.title, view.hint = backdrop, popup, title, hint
    view.input, view.code = input, code
  end

  local function EnsureBackdropKey()
    if view.keyBound then return end
    view.keyBound = true
    local catcher = CreateFrame("Frame", nil, view.backdrop)
    catcher:SetAllPoints(view.backdrop)
    catcher:EnableKeyboard(true)
    catcher:SetScript("OnKeyDown", function(frame, key)
      if key ~= "ESCAPE" then return end
      view:Close()
      frame:SetPropagateKeyboardInput(false)
    end)
  end

  function view:Close()
    if not self.backdrop or not self.backdrop:IsShown() then return false end
    if self.input then self.input:ClearFocus() end
    self.backdrop:Hide()
    self.active = nil
    return true
  end

  function view:Open(entry)
    if not entry then return end
    if self.active == entry and self.backdrop and self.backdrop:IsShown() then
      self:Close()
      return
    end
    EnsurePopup()
    EnsureBackdropKey()
    Components.HideTooltip()
    Components.HideActionMenu()
    self.active = entry
    local isCode = entry.code ~= nil
    Theme:SetSize(self.popup, isCode and metrics.popupCodeWidth or metrics.popupLinkWidth,
      isCode and metrics.popupCodeHeight or metrics.popupLinkHeight)
    -- 荔枝的方案：弹窗锚在联系入口栏上方右对齐，缩放与窗口一致，滑入登场。
    -- 不再居中于 UIParent——那是与窗口脱节的浮岛。
    self.popup:SetScale(bar:GetEffectiveScale() / UIParent:GetEffectiveScale())
    self.popup:ClearAllPoints()
    self.popup:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 8)
    Components.SetText(self.title, entry.title)
    Components.SetText(self.hint, isCode and "微信扫一扫" or "Ctrl+C 复制 · Esc 退出")
    Theme:SetShown(self.input, not isCode)
    Theme:SetShown(self.code, isCode)
    if isCode then
      self.code:SetTexture(media .. entry.code .. ".tga")
    else
      self.input:SetText(entry.url or "")
    end
    Theme:SetShown(self.backdrop, true)
    if Motion then Motion:Slide(self.popup, 1) end
    if not isCode then
      self.input:SetFocus()
      self.input:HighlightText()
    end
  end

  for index, entry in ipairs(entries) do
    local button = Components.CreateNavigationButton(bar, {
      width = metrics.footerIconHit,
      height = metrics.footerIconHit,
      onClick = function()
        view:Open(entry)
        return true
      end,
    })
    Theme:Anchor(button.frame, "LEFT", bar, "LEFT", (index - 1) * metrics.footerIconStride, 0)
    local icon = button.frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(metrics.footerIconSize, metrics.footerIconSize)
    Theme:Anchor(icon, "CENTER", button.frame, "CENTER", 0, 0)
    icon:SetTexture(media .. entry.icon .. ".tga")
    button.feedbackIcon = icon
    button:Refresh()
    view.buttons[index] = button
  end

  return view
end


--- 动作按钮：平直边缘 + 1px 边界，按下与悬停使用 actionHover。
function Components.CreateActionButton(parent, options)
  options = options or {}
  local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
  frame:SetSize(options.width or 96, options.height or Theme.Metrics.fieldHeight)
  Theme:CreateSurface(frame, "action", "border")

  local label = Components.CreateText(frame, options.text, options.role or "body", "text", "CENTER")
  Theme:Anchor(label, "CENTER", frame, "CENTER", 0, 0)

  local component = { frame = frame, label = label, enabled = true, primary = options.primary }

  function component:Refresh()
    local enabled = self.enabled ~= false
    if not enabled then
      Theme:ApplySurface(frame, "action", "border")
      Theme:SetTextColor(self.label, "disabled")
    elseif self.primary then
      Theme:ApplySurface(frame, frame:IsMouseOver() and "accent" or "accentMuted", "transparent")
      Theme:SetTextColor(self.label, frame:IsMouseOver() and "text" or "text")
    else
      Theme:ApplySurface(frame, frame:IsMouseOver() and "actionHover" or "action", "border")
      Theme:SetTextColor(self.label, "text")
    end
  end

  function component:SetText(value) setText(self.label, value) end

  function component:SetEnabled(enabled)
    enabled = enabled ~= false
    if self.enabled == enabled then return end
    self.enabled = enabled
    if enabled and frame.Enable then frame:Enable() else frame:Disable() end
    self:Refresh()
  end

  frame:SetScript("OnEnter", function() component:Refresh() end)
  frame:SetScript("OnLeave", function() component:Refresh() end)
  if options.onClick then
    frame:SetScript("OnClick", function(...)
      if component.enabled ~= false then options.onClick(...) end
    end)
  end
  component:Refresh()
  return component
end

--- 开关：32 × 18 圆角底座 + 14 滑块，开启为荔枝红。动画由共享驱动处理。
function Components.CreateToggle(parent, onChanged)
  local metrics = Theme.Metrics
  local frame = CreateFrame("Button", nil, parent)
  frame:SetSize(metrics.switchWidth, metrics.switchHeight)

  local track = Theme:CreateRoundedSurface(frame, "switchOff", 8)
  local base = CreateFrame("Frame", nil, frame)
  base:SetAllPoints(frame)
  Theme:CreateRoundedSurface(base, "accent", 8)

  local knob = CreateFrame("Frame", nil, frame)
  knob:SetSize(14, 14)
  Theme:CreateRoundedSurface(knob, "text", 6.9)
  if knob.SetFrameLevel then knob:SetFrameLevel(base:GetFrameLevel() + 1) end

  local component = { frame = frame, base = base, knob = knob, track = track, enabled = true }

  function component:Paint(animated)
    local checked = self.checked == true
    local x = checked and metrics.switchWidth - 16 or 2
    if animated ~= false and Motion then
      Motion:MoveX(knob, frame, x)
      Motion:Fade(base, checked and 1 or 0)
    else
      knob.__lnMoveX = x
      knob:ClearAllPoints()
      knob:SetPoint("LEFT", frame, "LEFT", x, 0)
      base:SetAlpha(checked and 1 or 0)
      setShown(base, true)
    end
  end

  function component:SetChecked(checked, animated)
    checked = checked == true
    if self.checked == checked then return false end
    self.checked = checked
    self:Paint(animated)
    return true
  end

  function component:SetEnabled(enabled)
    enabled = enabled ~= false
    if self.enabled == enabled then return end
    self.enabled = enabled
    if enabled and frame.Enable then frame:Enable() else frame:Disable() end
    self.track:SetColor(enabled and "switchOff" or "disabled")
  end

  frame:SetScript("OnClick", function()
    if component.enabled ~= false and onChanged then onChanged(not component.checked) end
  end)

  component.checked = false
  component:Paint(false)
  return component
end

--- 表单输入框：field 底 + 1px fieldBorder 边界，焦点转 accentHover，错误优先。
function Components.StyleEditBox(input)
  if not input or input.__lnField then return input and input.__lnField end
  Theme:CreateSurface(input, "field", "fieldBorder")
  local style = { focused = false, invalid = false }
  input.__lnField = style
  function style:Apply()
    if not input.__lnSurface then return end
    Theme:ApplySurface(input, "field", self.invalid and "danger" or self.focused and "accentHover" or "fieldBorder")
  end
  function style:SetInvalid(invalid)
    invalid = invalid == true
    if self.invalid == invalid then return end
    self.invalid = invalid
    self:Apply()
  end
  input:HookScript("OnEditFocusGained", function() style.focused = true; style:Apply() end)
  input:HookScript("OnEditFocusLost", function() style.focused = false; style:Apply() end)
  input:HookScript("OnHide", function() style.focused = false; style.invalid = false; style:Apply() end)
  return style
end

function Components.CreateInput(parent, options)
  options = options or {}
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetSize(options.width or 260, options.height or Theme.Metrics.fieldHeight)
  Theme:SetFont(box, "input")
  Theme:SetTextColor(box, "text")
  box:SetAutoFocus(false)
  box:SetMaxLetters(options.maxLetters or 200)
  if options.multiLine then box:SetMultiLine(true) end
  Components.StyleEditBox(box)
  return box
end

--- 多行文本区：圆角外壳 + 内嵌滚动视口 + EditBox，供导入/导出共用。
--- 文字走 input 字号（16，无阴影），不再是继承的 ChatFontNormal；
--- 光标移动带动滚动、滚轮步进与列表一致——荔枝天赋 field 的同款做法。
function Components.CreateTextArea(parent, options)
  options = options or {}
  local metrics = Theme.Metrics
  local width = options.width or 400
  local height = options.height or metrics.textareaHeight
  local shell = CreateFrame("Frame", nil, parent)
  shell:SetSize(width, height)
  local background = Theme:CreateRoundedSurface(shell, "code", Theme.Metrics.radiusControl)

  local scroll = CreateFrame("ScrollFrame", nil, shell)
  Theme:Anchor(scroll, "TOPLEFT", shell, "TOPLEFT", 10, -10)
  Theme:Anchor(scroll, "BOTTOMRIGHT", shell, "BOTTOMRIGHT", -10, 10)
  shell:EnableMouseWheel(true)
  shell:SetScript("OnMouseWheel", function(_, delta)
    if InCombatLockdown and InCombatLockdown() then return end
    local maximum = scroll:GetVerticalScrollRange() or 0
    local target = (scroll:GetVerticalScroll() or 0) - delta * metrics.scrollWheelStep
    scroll:SetVerticalScroll(math.max(0, math.min(maximum, target)))
  end)

  local box = CreateFrame("EditBox", nil, scroll)
  box:SetWidth(math.max(1, width - 20))
  box:SetHeight(math.max(1, height - 20))
  Theme:SetFont(box, "input")
  box:SetMultiLine(options.multiLine ~= false)
  box:SetAutoFocus(false)
  box:SetMaxLetters(options.maxLetters or 800000)
  box:SetJustifyH("LEFT")
  box:SetJustifyV("TOP")
  box:SetTextInsets(0, 0, 0, 0)
  Theme:SetTextColor(box, "text")
  scroll:SetScrollChild(box)
  box:SetScript("OnCursorChanged", function(_, _, cursorY, _, cursorHeight)
    local top = scroll:GetVerticalScroll() or 0
    local viewport = scroll:GetHeight() or 1
    local position = -cursorY
    if position < top then
      scroll:SetVerticalScroll(math.max(0, position))
    elseif position + cursorHeight > top + viewport then
      scroll:SetVerticalScroll(position + cursorHeight - viewport)
    end
  end)

  local component = { frame = shell, box = box, background = background, scroll = scroll }
  function component:FocusAndSelect()
    box:SetFocus()
    box:HighlightText()
  end
  return component
end

--- 关闭按钮：两条旋转的短横线，常态暖白，悬停荔枝红。
function Components.CreateCloseButton(parent, onClick)
  local frame = CreateFrame("Button", nil, parent)
  frame:SetSize(24, 24)

  local hover = frame:CreateTexture(nil, "BACKGROUND")
  hover:SetAllPoints(frame)
  Theme:SetColorTexture(hover, "transparent")
  hover:Hide()

  local strokes = {}
  for index = 1, 2 do
    local stroke = frame:CreateTexture(nil, "ARTWORK")
    stroke:SetSize(11, 1.5)
    Theme:Anchor(stroke, "CENTER", frame, "CENTER", 0, 0)
    stroke:SetRotation(index == 1 and math.rad(45) or math.rad(-45))
    strokes[index] = stroke
  end

  local component = { frame = frame, strokes = strokes }
  function component:Refresh()
    local hovered = frame:IsMouseOver()
    setShown(self.hover, hovered)
    if hovered then Theme:SetColorTexture(self.hover, "actionHover") end
    for _, stroke in ipairs(self.strokes) do
      Theme:SetColorTexture(stroke, hovered and "accentHover" or "textMuted")
    end
  end

  frame:SetScript("OnEnter", function() component:Refresh() end)
  frame:SetScript("OnLeave", function() component:Refresh() end)
  frame:SetScript("OnHide", function() setShown(component.hover, false) end)
  if onClick then frame:SetScript("OnClick", onClick) end
  component:Refresh()
  return component
end

--- 列表行：中性底 + 左侧红条表示当前项，hover 使用 surfaceHover。
function Components.CreateListRow(parent, options)
  options = options or {}
  local metrics = Theme.Metrics
  local frame = CreateFrame("Button", nil, parent)
  frame:SetSize(options.width or 600, options.height or metrics.rowHeight)
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:Hide()
  local bar = Theme:CreateSelectionBar(frame)

  local component = { frame = frame, background = background, bar = bar, hover = false }
  function component:Paint()
    if self.hover and not self.selected then
      setShown(self.background, true)
      Theme:SetColorTexture(self.background, "surfaceHover")
    else
      setShown(self.background, self.selected == true)
      if self.selected then Theme:SetColorTexture(self.background, "surfaceSelected") end
    end
    if Motion then
      Motion:Fade(self.bar, self.selected and 1 or 0)
    else
      setShown(self.bar, self.selected == true)
    end
    if self.selected then Theme:SetColorTexture(self.bar, "accent") end
  end
  function component:Bind(state)
    state = state or {}
    self.hover = false
    self.selected = state.selected == true
    self:Paint()
  end
  frame:SetScript("OnEnter", function() component.hover = true; component:Paint() end)
  frame:SetScript("OnLeave", function() component.hover = false; component:Paint() end)
  frame:SetScript("OnHide", function() component.hover = false; component:Paint() end)
  component:Paint()
  return component
end

--- 滚动条：3 宽荔枝红滑块、无可见轨道、12 宽透明命中区。
function Components.CreateScrollbar(parent, onChanged)
  local metrics = Theme.Metrics
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetWidth(metrics.scrollWidth)
  Theme:Anchor(frame, "TOPRIGHT", parent, "TOPRIGHT", 0, -2)
  Theme:Anchor(frame, "BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 2)
  frame:EnableMouse(true)

  local thumb = frame:CreateTexture(nil, "ARTWORK")
  thumb:SetWidth(metrics.scrollThumbWidth)
  Theme:SetColorTexture(thumb, "accent")

  local bar = { frame = frame, thumb = thumb, maximum = 0, value = 0, total = 0, viewport = 0 }

  function bar:StopDrag()
    if self.dragOffset == nil then return end
    self.dragOffset = nil
    frame:SetScript("OnUpdate", nil)
  end

  function bar:SetRange(total, viewport, value)
    self.total, self.viewport = total, viewport
    self.maximum = math.max(0, total - viewport)
    self.value = math.max(0, math.min(self.maximum, value or 0))
    local height = math.max(0, frame:GetHeight())
    local thumbHeight = math.min(height, metrics.scrollThumbMax,
      math.max(metrics.scrollThumbMin, height * viewport / math.max(1, total)))
    self.travel = math.max(0, height - thumbHeight)
    local offset = self.maximum > 0 and self.travel * self.value / self.maximum or 0
    if self._height ~= thumbHeight then
      self._height = thumbHeight
      thumb:SetHeight(thumbHeight)
    end
    if self._offset ~= offset then
      self._offset = offset
      thumb:ClearAllPoints()
      thumb:SetPoint("TOP", frame, "TOP", 0, -offset)
    end
    if self.maximum == 0 then self:StopDrag() end
    setShown(frame, self.maximum > 0 and height > 0)
  end

  function bar:SetValue(value)
    if InCombatLockdown and InCombatLockdown() then self:StopDrag(); return end
    value = math.max(0, math.min(self.maximum, value))
    if value ~= self.value and onChanged then onChanged(value) end
  end

  local function cursorOffset()
    local _, y = GetCursorPosition()
    local top = frame:GetTop()
    return top and top - y / frame:GetEffectiveScale()
  end

  local function drag()
    if (InCombatLockdown and InCombatLockdown()) or not IsMouseButtonDown("LeftButton") then
      bar:StopDrag()
      return
    end
    local offset = cursorOffset()
    if offset and bar.travel > 0 then
      bar:SetValue((offset - bar.dragOffset) / bar.travel * bar.maximum)
    end
  end

  frame:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" or bar.maximum == 0 or (InCombatLockdown and InCombatLockdown()) then return end
    local offset = cursorOffset()
    if not offset then return end
    local relative = offset - bar._offset
    bar.dragOffset = relative >= 0 and relative <= bar._height and relative or bar._height / 2
    drag()
    if bar.dragOffset ~= nil then frame:SetScript("OnUpdate", drag) end
  end)
  frame:SetScript("OnMouseUp", function() bar:StopDrag() end)
  frame:SetScript("OnHide", function() bar:StopDrag() end)
  frame:Hide()

  return bar
end

--- 滚动视口。
--- 关键：用**裸 ScrollFrame**，不挂 UIPanelScrollFrameTemplate。
--- 模板会带出暴雪自带的上下箭头按钮和原生滑块，和自绘滑块叠在一起，
--- 实机上就是列表右缘那两个多余的方块（Lychee 同样只用裸 ScrollFrame）。
function Components.CreateScrollView(parent, options)
  options = options or {}
  local metrics = Theme.Metrics
  local frame = CreateFrame("ScrollFrame", nil, parent)
  Theme:Anchor(frame, options.point or "TOPLEFT", parent, options.relativePoint or "TOPLEFT",
    options.x or 0, options.y or 0)
  Theme:Anchor(frame, options.endPoint or "BOTTOMRIGHT", parent,
    options.endPoint or "BOTTOMRIGHT", options.endX or 0, options.endY or 0)
  frame:EnableMouseWheel(true)

  local content = CreateFrame("Frame", nil, frame)
  content:SetSize(math.max(1, (frame:GetWidth() or 1) - metrics.scrollWidth), 1)
  frame:SetScrollChild(content)

  local view
  local function Sync()
    local top = frame:GetVerticalScroll() or 0
    view.bar:SetRange(content:GetHeight(), frame:GetHeight(), top)
  end

  -- 拖拽滑块回调：设置滚动位置后立即重算，滑块 value 由 SetRange 统一维护。
  view = {
    frame = frame,
    content = content,
    bar = Components.CreateScrollbar(frame, function(value)
      frame:SetVerticalScroll(value)
      Sync()
    end),
    Sync = Sync,
  }
  frame.__lnBar = view.bar

  frame:SetScript("OnSizeChanged", Sync)
  content:SetScript("OnSizeChanged", Sync)
  frame:SetScript("OnMouseWheel", function(_, delta)
    if InCombatLockdown and InCombatLockdown() then return end
    local maximum = math.max(0, content:GetHeight() - frame:GetHeight())
    local target = (frame:GetVerticalScroll() or 0) - delta * metrics.scrollWheelStep
    frame:SetVerticalScroll(math.max(0, math.min(maximum, target)))
    Sync()
  end)

  view.Sync()
  return view
end

--- 窗口外壳：圆角背景 + 1px 边框 + 拖动，ESC 由 Shared/Layer.lua 处理。
--- 整窗按 uiScale 缩放：所有尺寸令牌按荔枝启动器口径设计，不缩放会整体偏小 13%。
function Components.CreateWindow(parent, options)
  options = options or {}
  local metrics = Theme.Metrics
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  frame:SetSize(options.width or metrics.windowWidth, options.height or metrics.windowHeight)
  frame:EnableMouse(true)
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetFrameStrata("DIALOG")
  frame:SetScale(metrics.uiScale)
  Theme:CreateShell(frame)
  return frame
end

--- 提示框：自有 Frame，不修改游戏全局 GameTooltip。
local tooltipFrame

--- 动作菜单：与提示框同底色、8 圆角，标题 14 + 操作 12，悬停转荔枝红。
-- 自有浮层，不进入原生 Menu manager，避免被全局换肤重画方形背景。
local actionMenuFrame
local ACTION_MENU_MAX = 12
local ACTION_ITEM_HEIGHT = 30
local ACTION_HEADER_HEIGHT = 34

local function EnsureActionMenu()
  if actionMenuFrame then return actionMenuFrame end
  local frame = CreateFrame("Frame", "LycheeNoteActionMenu", UIParent)
  frame:SetSize(160, ACTION_HEADER_HEIGHT + ACTION_ITEM_HEIGHT * 2)
  frame:SetFrameStrata("DIALOG")
  frame:SetScale(Theme.Metrics.uiScale)
  frame:EnableMouse(true)
  frame:Hide()
  Theme:CreateRoundedSurface(frame, "tooltip", 8)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  Theme:SetFont(title, "title")
  Theme:SetTextColor(title, "textDim")
  title:SetJustifyH("LEFT")
  Theme:Anchor(title, "TOPLEFT", frame, "TOPLEFT", 14, -10)

  local items = {}
  local owner

  local function EnsureItem(index)
    local item = items[index]
    if item then return item end
    item = { frame = CreateFrame("Button", nil, frame) }
    Theme:Anchor(item.frame, "LEFT", frame, "LEFT", 6, 0)
    Theme:Anchor(item.frame, "RIGHT", frame, "RIGHT", -6, 0)
    item.frame:SetHeight(ACTION_ITEM_HEIGHT)
    item.label = Components.CreateText(item.frame, "", "body", "text", "LEFT")
    Theme:Anchor(item.label, "LEFT", item.frame, "LEFT", 8, 0)
    item.label:SetWordWrap(false)
    item.frame:SetScript("OnEnter", function(self)
      if self.data then Theme:SetTextColor(self.label, "accentHover") end
    end)
    item.frame:SetScript("OnLeave", function(self)
      if self.data then Theme:SetTextColor(self.label, self.data.danger and "danger" or "text") end
    end)
    item.frame:SetScript("OnClick", function(self)
      local data = self.data
      if not data then return end
      Components.HideActionMenu(owner)
      if data.onClick then data.onClick() end
    end)
    items[index] = item
    return item
  end

  function frame:Present(entry, entries)
    owner = entry
    setText(title, "操作")

    local count = math.min(#entries, ACTION_MENU_MAX)
    local width = 160
    for index = 1, count do
      local item = EnsureItem(index)
      local data = entries[index]
      item.data = data
      setText(item.label, data.text)
      Theme:SetTextColor(item.label, data.danger and "danger" or "text")
      Theme:Anchor(item.frame, "TOP", frame, "TOP", 0, -ACTION_HEADER_HEIGHT - (index - 1) * ACTION_ITEM_HEIGHT)
      setShown(item.frame, true)
      width = math.max(width, math.ceil(item.label:GetStringWidth()) + 34)
    end
    for index = count + 1, #items do
      items[index].data = nil
      setShown(items[index].frame, false)
    end

    width = math.min(width, 288)
    Theme:SetSize(frame, width, ACTION_HEADER_HEIGHT + count * ACTION_ITEM_HEIGHT + 6)
    Theme:Anchor(title, "TOPLEFT", frame, "TOPLEFT", 14, -10)
    self:Show()
  end

  function frame:Dismiss(entry)
    if entry and owner and entry ~= owner then return end
    owner = nil
    self:Hide()
  end

  actionMenuFrame = frame
  return frame
end

function Components.HideActionMenu(owner)
  if actionMenuFrame then actionMenuFrame:Dismiss(owner) end
end

function Components.ShowActionMenu(owner, entries)
  if not owner or type(entries) ~= "table" or #entries == 0 then return end
  Components.HideTooltip(owner)
  Components.HideActionMenu()
  local menu = EnsureActionMenu()
  menu:Present(owner, entries)

  local scale = UIParent:GetEffectiveScale()
  local cursorX, cursorY = GetCursorPosition()
  local x, y = cursorX / scale, cursorY / scale
  local px = math.min(math.max(4, x - 4), UIParent:GetWidth() - menu:GetWidth() - 8)
  local py = math.min(math.max(4, y - 8), UIParent:GetHeight() - menu:GetHeight() - 8)
  menu:ClearAllPoints()
  menu:SetPoint("TOPLEFT", UIParent, "TOPLEFT", px, -py)
end

local function EnsureTooltip()
  if tooltipFrame then return tooltipFrame end
  local metrics = Theme.Metrics
  local frame = CreateFrame("Frame", "LycheeNoteTooltip", UIParent)
  frame:SetWidth(288)
  frame:SetScale(metrics.uiScale)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  frame:SetFrameStrata("DIALOG")
  frame:Hide()
  local background = Theme:CreateRoundedSurface(frame, "tooltip", 8)

  local parts = {}
  local roles = {
    { "title", "text" },
    { "meta", "textDim" },
    { "body", "textMuted" },
    { "meta", "tooltipAccent" },
  }
  for index = 1, 4 do
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    Theme:SetFont(label, roles[index][1])
    Theme:SetTextColor(label, roles[index][2])
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetWordWrap(true)
    label:Hide()
    parts[index] = label
  end

  local owner, content

  function frame:Layout(value)
    local y = -14
    for index = 1, 4 do
      local label = parts[index]
      local text = value[index]
      if type(text) == "string" and text ~= "" then
        label:SetText(text)
        Theme:Anchor(label, "TOPLEFT", frame, "TOPLEFT", 14, y)
        label:SetWidth(288 - 28)
        label:SetHeight(math.max(18, label:GetStringHeight()))
        y = y - label:GetHeight() - (index == 1 and 2 or 6)
        setShown(label, true)
      else
        setShown(label, false)
      end
    end
    Theme:SetSize(frame, 288, math.max(48, -y + 14))
  end

  function frame:ShowTooltip(entry, value)
    owner, content = entry, value
    self:Layout(value)
    Theme:SetColorTexture(background, "tooltip")
    self:Show()
  end

  function frame:HideTooltip(entry)
    if entry and owner and entry ~= owner then return end
    owner, content = nil, nil
    self:Hide()
  end

  frame:SetScript("OnUpdate", function(self)
    if not self:IsShown() then
      self:SetScript("OnUpdate", nil)
      return
    end
    local scale = UIParent:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    local x, y = cursorX / scale, cursorY / scale
    local width, height = self:GetWidth(), self:GetHeight()
    local parentWidth, parentHeight = UIParent:GetWidth(), UIParent:GetHeight()
    local px = math.min(math.max(x + 14, 8), parentWidth - width - 8)
    local py = math.min(math.max(y - height - 14, 8), parentHeight - height - 8)
    if self.__lnX ~= px or self.__lnY ~= py then
      self.__lnX, self.__lnY = px, py
      self:ClearAllPoints()
      self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", px, -py)
    end
  end)
  frame:SetScript("OnHide", function() frame.owner = nil end)

  tooltipFrame = frame
  return frame
end

function Components.ShowTooltip(owner, content)
  if not owner or not content then return end
  local frame = EnsureTooltip()
  if frame.owner and frame.owner ~= owner then frame:HideTooltip() end
  frame.owner = owner
  frame:ShowTooltip(owner, content)
end

function Components:HideTooltip(owner)
  if tooltipFrame then tooltipFrame:HideTooltip(owner) end
end

--- 职业颜色：从本地化职业名反查 classFileID。
local localizedClassTokens

local function BuildLocalizedClassTokens()
  localizedClassTokens = {}
  for _, source in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
    if type(source) == "table" then
      for classToken, localizedName in pairs(source) do
        if localizedName then localizedClassTokens[localizedName] = classToken end
      end
    end
  end
end

function Components.GetClassSpecColor(classSpec)
  if type(classSpec) ~= "string" or classSpec == "" then return nil end
  if not localizedClassTokens then BuildLocalizedClassTokens() end
  local className = classSpec:match("^([^-]+)")
  local classToken = className and localizedClassTokens[className]
  local palette = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  local value = classToken and palette and palette[classToken]
  if value then return { value.r, value.g, value.b, 1 } end
end

function Components.ColorizeClassSpec(classSpec, fallbackToken)
  local value = classSpec or "尚未获取"
  local rgb = Components.GetClassSpecColor(value)
  if not rgb then return value end
  return string.format("|cff%02x%02x%02x%s|r",
    math.floor(rgb[1] * 255 + 0.5),
    math.floor(rgb[2] * 255 + 0.5),
    math.floor(rgb[3] * 255 + 0.5),
    value)
end

function Components.SetClassSpecText(label, prefix, classSpec, fallbackToken)
  if not label then return end
  setText(label, (prefix or "") .. Components.ColorizeClassSpec(classSpec))
  Theme:SetTextColor(label, fallbackToken or "textMuted")
end
