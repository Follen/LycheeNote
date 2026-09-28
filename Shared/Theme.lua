--- 荔枝笔记主题层
-- 所有颜色、字号、圆角与尺寸的唯一来源。控件只引用令牌，不写字面量。
-- 视觉语言见 DESIGN.md：近黑底 + 荔枝红强调 + 10px 外壳圆角 + 平直内容行。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

ns.addonName = ns.addonName or ADDON_NAME

local Theme = {}
LN.Theme = Theme

Theme.Media = {
  logo = "Interface\\AddOns\\LycheeNote\\Media\\lychee-logo.tga",
  corner = "Interface\\AddOns\\LycheeNote\\Media\\rounded-corner.tga",
  settings = "Interface\\AddOns\\LycheeNote\\Media\\settings.tga",
  back = "Interface\\AddOns\\LycheeNote\\Media\\back-search.tga",
}

Theme.BrandColor = "|cffd53c49"
Theme.BrandColorClose = "|r"
Theme.MatchColorCode = "|cffff9aa2"

local function color(r, g, b, a) return { r, g, b, a or 1 } end

-- 令牌表按约定不可变：表格身份同时用作原生 setter 的缓存键。
local window = color(0.055, 0.055, 0.063)
Theme.Colors = {
  window = window,
  header = window,
  content = window,
  footer = window,
  sidebar = color(0.042, 0.042, 0.050),
  surface = window,
  surfaceHover = color(0.090, 0.090, 0.090),
  surfaceSelected = color(0.085, 0.085, 0.085),
  field = color(0.085, 0.085, 0.095),
  fieldBorder = color(0.400, 0.400, 0.420),
  border = color(0.110, 0.110, 0.125),
  borderStrong = color(0.285, 0.290, 0.315),
  action = color(0.075, 0.078, 0.088),
  actionHover = color(0.175, 0.115, 0.125),
  accent = color(0.835, 0.235, 0.285),
  accentHover = color(0.950, 0.350, 0.400),
  accentMuted = color(0.440, 0.155, 0.185),
  tooltipAccent = color(0.780, 0.460, 0.500),
  transparent = color(0, 0, 0, 0),
  text = color(0.940, 0.932, 0.910),
  textMuted = color(0.710, 0.705, 0.690),
  textDim = color(0.590, 0.580, 0.590),
  disabled = color(0.400, 0.400, 0.420),
  switchOff = color(0.215, 0.215, 0.230),
  success = color(0.310, 0.690, 0.455),
  warning = color(0.880, 0.645, 0.250),
  danger = color(0.895, 0.300, 0.315),
  tooltip = color(0.065, 0.065, 0.075),
  code = color(0.072, 0.072, 0.082),
}

-- 业务语义色：只在“已记录”标识上使用，不参与面板底色。
Theme.NoteColor = color(0.835, 0.235, 0.285)

Theme.FontSizes = {
  brand = 16,
  title = 14,
  body = 12,
  meta = 11,
  input = 16,
}

--- 尺寸与 Lychee 启动器一一对应：头/底 56、行高 46 行距 6、底部图标 28 命中 / 18 图形。
--- 设置与返回共用头部动作槽位（荔枝天赋样式）：32 命中 / 20 图形。
--- 名单贴片占满内容区：窗口 760 − 左右内距 16×2 = 728。
Theme.Metrics = {
  uiScale = 0.8,

  windowWidth = 760,
  windowHeight = 520,

  headerHeight = 56,
  footerHeight = 56,
  footerInset = 28,
  contentPadding = 16,

  brandIconSize = 42,
  brandLabelGap = 10,

  headerActionHit = 32,
  headerActionIcon = 20,

  footerIconHit = 28,
  footerIconSize = 18,
  footerIconStride = 36,

  listInset = 0,
  resultTileWidth = 728,
  rowHeight = 46,
  rowGap = 6,
  selectionWidth = 2,
  selectionHeight = 22,

  fieldHeight = 40,
  textareaHeight = 140,

  iconSize = 28,
  switchWidth = 32,
  switchHeight = 18,

  scrollWidth = 12,
  scrollThumbWidth = 3,
  scrollThumbMin = 24,
  scrollThumbMax = 48,
  scrollWheelStep = 52,

  popupCodeWidth = 208,
  popupCodeHeight = 252,
  popupLinkWidth = 316,
  popupLinkHeight = 100,
  popupCodeSize = 176,

  dialogWidth = 400,
  dialogHeight = 292,
  dialogInset = 20,

  border = 1,
  radiusPanel = 10,
  radiusControl = 6,
}

Theme.Spacing = {
  tight = 6,
  control = 10,
  content = 16,
  section = 24,
}

local function resolve(token)
  if type(token) == "string" then return Theme.Colors[token] end
  return token
end



--- 只修改自有区域；不触碰共享的 GameFont / tooltip 对象。
function Theme:SetFont(region, role)
  local size = Theme.FontSizes[role] or Theme.FontSizes.body
  if not region or not region.SetFont or not STANDARD_TEXT_FONT then return false end
  if region.__lnFontSize == size then return false end
  if region:SetFont(STANDARD_TEXT_FONT, size, "") == false then return false end
  if region.SetShadowOffset then region:SetShadowOffset(0, 0) end
  region.__lnFontSize = size
  return true
end

function Theme:SetColorTexture(texture, token)
  local value = resolve(token)
  if not texture or type(texture.SetColorTexture) ~= "function" or not value then return false end
  if texture.__lnColorToken == value then return false end
  texture:SetColorTexture(value[1], value[2], value[3], value[4] or 1)
  texture.__lnColorToken = value
  return true
end

function Theme:SetVertexColor(region, token)
  local value = resolve(token)
  if not region or type(region.SetVertexColor) ~= "function" or not value then return false end
  if region.__lnVertexToken == value then return false end
  region:SetVertexColor(value[1], value[2], value[3], value[4] or 1)
  region.__lnVertexToken = value
  return true
end

function Theme:SetTextColor(fontString, token)
  local value = resolve(token)
  if not fontString or type(fontString.SetTextColor) ~= "function" or not value then return false end
  if fontString.__lnTextToken == value then return false end
  fontString:SetTextColor(value[1], value[2], value[3], value[4] or 1)
  fontString.__lnTextToken = value
  return true
end

function Theme:SetAlpha(region, alpha)
  if not region or type(region.SetAlpha) ~= "function" or region.__lnAlpha == alpha then return false end
  region:SetAlpha(alpha)
  region.__lnAlpha = alpha
  return true
end

function Theme:SetShown(region, shown)
  shown = shown == true
  if not region or type(region.IsShown) ~= "function" then return false end
  if region:IsShown() == shown then return false end
  region:SetShown(shown)
  return true
end

function Theme:SetSize(region, width, height)
  if not region or not region.SetSize then return false end
  local w, h = region:GetWidth(), region:GetHeight()
  if w == width and h == height then return false end
  region:SetSize(width, height)
  return true
end

--- 多锚点安全的锚定。
-- 同一个 (point, relativePoint) 视为「替换那一条」，不同位置视为「追加一条」。
-- 早期版本只用一个 __lnAnchor 键做缓存并在每次调用前 ClearAllPoints，
-- 于是 header 的 TOPLEFT 会被随后的 TOPRIGHT 清掉，宽度归零、内容被推到屏幕外
-- （实机表现为整块黑面板）。这里按锚点集合整体重放，既幂等又支持双锚布局。
function Theme:Anchor(region, point, relativeTo, relativePoint, x, y)
  if not region or not region.SetPoint then return false end
  x, y = x or 0, y or 0

  local set = region.__lnAnchorSet
  if not set then
    set = {}
    region.__lnAnchorSet = set
  end

  local slot
  for index = 1, #set do
    local anchor = set[index]
    if anchor.point == point and anchor.relativePoint == relativePoint then
      slot = index
      break
    end
  end

  if slot then
    local old = set[slot]
    if old.relativeTo == relativeTo and old.x == x and old.y == y then return false end
    set[slot] = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
  else
    set[#set + 1] = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
  end

  region:ClearAllPoints()
  for index = 1, #set do
    local anchor = set[index]
    region:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y)
  end
  return true
end

--- 丢弃已记录的锚点集合，供复用控件切换到完全不同的布局时使用。
function Theme:ClearAnchors(region)
  if not region then return false end
  region.__lnAnchorSet = nil
  if region.ClearAllPoints then region:ClearAllPoints() end
  return true
end

--- 平直表面：背景一块、边框四条，共 5 个区域。
function Theme:CreateSurface(frame, backgroundToken, borderToken)
  if frame.__lnSurface then
    self:ApplySurface(frame, backgroundToken, borderToken)
    return frame.__lnSurface
  end
  local surface = { border = {} }
  surface.background = frame:CreateTexture(nil, "BACKGROUND", nil, -2)
  surface.background:SetAllPoints(frame)
  local thickness = self.Metrics.border
  local anchors = {
    { "TOPLEFT", "TOPRIGHT", 0, 0, 0, 0 },
    { "BOTTOMLEFT", "BOTTOMRIGHT", 0, 0, 0, 0 },
    { "TOPLEFT", "BOTTOMLEFT", 0, -thickness, 0, thickness },
    { "TOPRIGHT", "BOTTOMRIGHT", 0, -thickness, 0, thickness },
  }
  for index = 1, 4 do
    local edge = frame:CreateTexture(nil, "BORDER", nil, -1)
    if index <= 2 then edge:SetHeight(thickness) else edge:SetWidth(thickness) end
    local anchor = anchors[index]
    edge:SetPoint(anchor[1], frame, anchor[1], anchor[3], anchor[4])
    edge:SetPoint(anchor[2], frame, anchor[2], anchor[5], anchor[6])
    surface.border[index] = edge
  end
  frame.__lnSurface = surface
  self:ApplySurface(frame, backgroundToken, borderToken)
  return surface
end

function Theme:ApplySurface(frame, backgroundToken, borderToken)
  local surface = frame and frame.__lnSurface
  if not surface then return false end
  local changed = self:SetColorTexture(surface.background, backgroundToken)
  for index = 1, #surface.border do
    if self:SetColorTexture(surface.border[index], borderToken) then changed = true end
  end
  return changed
end

--- 圆角表面：七个可复用区域，面板变高时角部尺寸保持不变。
function Theme:CreateRoundedSurface(frame, token, radius, inset, layer)
  radius = radius or self.Metrics.radiusPanel
  inset = inset or 0
  layer = layer or "BACKGROUND"
  local surface = { regions = {} }
  function surface:SetColor(value)
    for _, region in ipairs(self.regions) do
      if region.__lnCorner then self:SetVertexColor(region, value)
      else self:SetColorTexture(region, value) end
    end
  end

  local middle = frame:CreateTexture(nil, layer)
  middle:SetPoint("TOPLEFT", frame, "TOPLEFT", radius + inset, -inset)
  middle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -radius - inset, inset)
  self:SetColorTexture(middle, token)
  surface.regions[#surface.regions + 1] = middle

  for _, side in ipairs({ "LEFT", "RIGHT" }) do
    local strip = frame:CreateTexture(nil, layer)
    strip:SetPoint("TOP" .. side, frame, "TOP" .. side, side == "LEFT" and inset or -inset, -radius - inset)
    strip:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, side == "LEFT" and inset or -inset, radius + inset)
    strip:SetWidth(radius)
    self:SetColorTexture(strip, token)
    surface.regions[#surface.regions + 1] = strip
  end

  local corners = {
    { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 },
    { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 },
  }
  for index = 1, #corners do
    local corner = corners[index]
    local texture = frame:CreateTexture(nil, layer)
    texture:SetSize(radius, radius)
    texture:SetPoint(corner[1], frame, corner[1], corner[2] == 0 and inset or -inset, corner[4] == 0 and -inset or inset)
    texture:SetTexture(self.Media.corner)
    if texture.SetTexCoord then texture:SetTexCoord(corner[2], corner[3], corner[4], corner[5]) end
    self:SetVertexColor(texture, token)
    texture.__lnCorner = true
    surface.regions[#surface.regions + 1] = texture
  end
  return surface
end

--- 外壳：圆角背景。层级只靠底色与文字明度建立，不加外发光、投影或方形描边。
function Theme:CreateShell(frame, backgroundToken)
  local shell = {}
  shell.background = self:CreateRoundedSurface(frame, backgroundToken or "window", self.Metrics.radiusPanel)
  return shell
end

--- 当前项标识：左侧 2 × 22 荔枝红竖条。
function Theme:CreateSelectionBar(frame)
  if frame.__lnBar then return frame.__lnBar end
  local metrics = self.Metrics
  local bar = frame:CreateTexture(nil, "ARTWORK", nil, 1)
  bar:SetWidth(metrics.selectionWidth)
  bar:SetHeight(metrics.selectionHeight)
  bar:SetPoint("LEFT", frame, "LEFT", 0, 0)
  self:SetColorTexture(bar, "accent")
  bar:Hide()
  frame.__lnBar = bar
  return bar
end
