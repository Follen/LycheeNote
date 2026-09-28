--- 荔枝笔记离线冒烟测试
-- 用最小 WoW API 替身按 TOC 顺序加载全部文件，然后走一遍真实入口。
-- 目的：抓加载顺序、顶层 nil 访问、事件派发和主要界面路径的运行时错误。
-- 替身不能证明客户端事件顺序、受保护操作或像素渲染；实机验收另见 DESIGN.md。

local scriptPath = debug.getinfo(1, "S").source:sub(2)
local ADDON_DIR = scriptPath:match("^(.*)[\\/]tests[\\/]smoke%.lua$") or "."
if ADDON_DIR == "" then ADDON_DIR = "." end

-- ---------------------------------------------------------------- 替身

local log = {}
local errors = {}

local function record(level, ...)
  log[#log + 1] = level .. ": " .. table.concat({ ... }, " ")
end

-- 12.1.0 权威控件方法表，由 lycheedev 从客户端 API 文档提取。
local REAL_METHODS = dofile((debug.getinfo(1, "S").source:sub(2):match("^(.*)[\\/]tests[\\/]") or ".") .. "/tests/wow_api_methods.lua")

local function Region(kind)
  local region = {
    __kind = kind, __scripts = {}, __children = {}, __points = {}, __events = {},
  }

  local noop = function() end

  -- 尺寸从锚点推断：两个相对边贴住（含对角）时客户端会算出尺寸。
  -- 早期替身直接返回固定值，于是「第二条锚点把第一条清掉、宽度归零」在离线全绿。
  local function anchorSet()
    local has = {}
    for _, p in ipairs(region.__points) do has[p[1]] = true end
    return has
  end
  local function reference()
    if type(region.__allPoints) == "table" then return region.__allPoints end
    for _, p in ipairs(region.__points) do
      if type(p[3]) == "table" and p[3].GetWidth then return p[3] end
    end
    return region.__parent
  end
  local function inferredWidth()
    local target = reference()
    local base = target and target:GetWidth() or 100
    if region.__allPoints then return base end
    local has = anchorSet()
    if (has.TOPLEFT and has.TOPRIGHT) or (has.BOTTOMLEFT and has.BOTTOMRIGHT)
      or (has.LEFT and has.RIGHT) or (has.TOPLEFT and has.BOTTOMRIGHT)
      or (has.TOPRIGHT and has.BOTTOMLEFT) then
      return base
    end
    return 0
  end
  local function inferredHeight()
    local target = reference()
    local base = target and target:GetHeight() or 20
    if region.__allPoints then return base end
    local has = anchorSet()
    if (has.TOPLEFT and has.BOTTOMLEFT) or (has.TOPRIGHT and has.BOTTOMRIGHT)
      or (has.TOP and has.BOTTOM) or (has.TOPLEFT and has.BOTTOMRIGHT)
      or (has.TOPRIGHT and has.BOTTOMLEFT) then
      return base
    end
    return 0
  end

  region.GetWidth = function() return region.__width or inferredWidth() end
  region.GetHeight = function() return region.__height or inferredHeight() end
  region.GetSize = function() return region:GetWidth(), region:GetHeight() end
  region.GetText = function() return region.__text or "" end
  region.GetStringWidth = function() return #(region.__text or "") * 7 end
  region.GetStringHeight = function() return 14 end
  region.IsShown = function() return region.__shown == true end
  region.IsVisible = function() return region.__shown == true end
  region.GetAlpha = function() return region.__alpha or 1 end
  region.GetName = function() return region.__name end
  region.GetParent = function() return region.__parent end
  region.IsMouseOver = function() return region.__hover == true end
  region.IsObjectType = function(self, t) return self.__kind == t end
  region.GetObjectType = function(self) return self.__kind end
  region.GetEffectiveScale = function() return 1 end
  region.SetScale = function(self, scale) region.__scale = scale end
  region.GetScale = function() return region.__scale end
  region.GetTop = function() return 0 end
  region.GetNumPoints = function() return #region.__points end
  region.GetPoint = function(self, index)
    local p = region.__points[index or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
  end
  region.GetFrameLevel = function() return region.__level or 1 end
  region.GetVerticalScroll = function() return region.__scroll or 0 end
  region.GetAttribute = function() return nil end

  -- 与客户端一致：GetChildren 只返回框体，纹理/字体串走 GetRegions。
  local function isFrameKind(kind)
    return kind ~= "Texture" and kind ~= "FontString"
  end
  region.GetChildren = function()
    local out = {}
    for _, child in ipairs(region.__children) do
      if isFrameKind(child.__kind) then out[#out + 1] = child end
    end
    return unpack(out)
  end
  region.GetRegions = function()
    local out = {}
    for _, child in ipairs(region.__children) do
      if not isFrameKind(child.__kind) then out[#out + 1] = child end
    end
    return unpack(out)
  end
  region.GetScript = function(self, name) return self.__scripts[name] end
  region.GetNormalTexture = function() return nil end
  region.GetPushedTexture = function() return nil end
  region.GetDisabledTexture = function() return nil end
  region.GetHighlightTexture = function() return nil end
  region.GetFontString = function() return region.__fontString end

  region.Show = function(self) self.__shown = true end
  region.Hide = function(self) self.__shown = false end
  region.SetShown = function(self, shown) self.__shown = shown and true or false end
  region.SetAlpha = function(self, a) self.__alpha = a end
  region.SetSize = function(self, w, h) self.__width, self.__height = w, h end
  region.SetWidth = function(self, w) self.__width = w end
  region.SetHeight = function(self, h) self.__height = h end
  region.SetPoint = function(self, ...) self.__points[#self.__points + 1] = { ... } end
  region.ClearAllPoints = function(self) self.__points = {} end
  region.SetAllPoints = function(self, other) self.__allPoints = other or true end
  region.SetText = function(self, t) self.__text = t end
  region.SetTextColor = function(self, r, g, b, a) self.__textColor = { r, g, b, a } end
  region.SetColorTexture = function(self, r, g, b, a) self.__color = { r, g, b, a } end
  region.SetVertexColor = function(self, r, g, b, a) self.__color = { r, g, b, a } end
  region.SetTexture = function(self, t) self.__texture = t end
  region.GetTexture = function(self) return self.__texture end
  region.SetTexCoord = noop
  region.SetRotation = noop
  region.SetFont = function() return true end
  region.SetShadowOffset = noop
  region.SetJustifyH = noop
  region.SetJustifyV = noop
  region.SetWordWrap = noop
  region.SetMaxLines = noop
  region.SetTextInsets = noop
  region.SetFontObject = noop
  region.SetMultiLine = noop
  region.SetAutoFocus = noop
  region.SetMaxLetters = noop
  region.SetCursorPosition = noop
  region.SetFocus = function(self) self.__focused = true end
  region.ClearFocus = function(self) self.__focused = false end
  region.HighlightText = function(self) self.__highlighted = true end
  region.Enable = function(self) self.__enabled = true end
  region.Disable = function(self) self.__enabled = false end
  region.EnableMouse = noop
  region.EnableKeyboard = noop
  region.EnableDrag = noop
  region.RegisterForClicks = noop
  region.RegisterForDrag = noop
  region.RegisterEvent = function(self, e) self.__events[e] = true end
  region.UnregisterEvent = function(self, e) self.__events[e] = nil end
  region.IsEventRegistered = function(self, e) return self.__events[e] == true end
  region.SetFrameStrata = function(self, s) self.__strata = s end
  region.SetFrameLevel = function(self, l) self.__level = l end
  region.SetToplevel = noop
  region.SetClampedToScreen = noop
  region.SetMovable = noop
  region.StartMoving = noop
  region.StopMovingOrSizing = noop
  region.SetPropagateKeyboardInput = noop
  region.SetParent = function(self, p) self.__parent = p end
  region.SetScrollChild = function(self, c) self.__scrollChild = c end
  region.UpdateScrollChildRect = noop
  region.SetVerticalScroll = function(self, v) self.__scroll = v end
  region.SetAttribute = noop
  region.Click = function(self) if self.__scripts.OnClick then self.__scripts.OnClick(self, "LeftButton") end end
  region.SetChecked = noop

  region.SetScript = function(self, name, fn) self.__scripts[name] = fn end
  region.HookScript = function(self, name, fn)
    local previous = self.__scripts[name]
    self.__scripts[name] = function(...)
      if previous then previous(...) end
      return fn(...)
    end
  end

  -- 注意：__spawn 用点号调用，签名里没有 self，否则 kind 会落进 self 槽、
  -- Region() 收到的是 layer 名（曾把每个区域都建成 "BACKGROUND"）。
  local function spawn(kind, layer)
    local child = Region(kind)
    child.__layer = layer
    child.__parent = region
    region.__children[#region.__children + 1] = child
    return child
  end
  region.__spawn = spawn
  -- CreateTexture / CreateFontString 的第 2 个参数是 layer，第 3 个是 template。
  region.CreateTexture = function(_, layer) return spawn("Texture", layer) end
  region.CreateFontString = function(_, layer) return spawn("FontString", layer) end

  return setmetatable(region, { __index = function(self, key)
    -- 插件自定义字段以 nil 呈现（与真实客户端一致）。
    if type(key) == "string" and key:sub(1, 2) == "__" then return nil end
    -- 只承认 12.1.0 真实存在的控件方法；其余一律报错。
    -- 这条规则来自实机事故：frame:EnableDrag(...) 在客户端是 nil，
    -- 报错发生在 CreateWindow 中途，主窗口只剩外壳，表现为「全黑面板」。
    -- 旧版替身对未知方法一律返回空操作，所以离线全绿、实机崩。
    if not REAL_METHODS[key] then
      local fn = function()
        error("调用了 12.1.0 不存在的控件方法: " .. tostring(key), 2)
      end
      rawset(self, key, fn)
      return fn
    end
    local fn = function() end
    rawset(self, key, fn)
    return fn
  end })
end

local uiParent = Region("Frame")
uiParent.__shown = true
uiParent.__width, uiParent.__height = 1920, 1080

_G.UIParent = uiParent
_G.GetTime = function() return 1000 end
_G.time = function() return 1700000000 end
_G.date = function() return "26/01/01" end
_G.strtrim = function(s) return tostring(s):match("^%s*(.-)%s*$") end
_G.strsplit = function(sep, s) local a, b = s:match("^(.-)" .. sep .. "(.*)$"); return a, b end
function noopPlaceholder() end
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = noopPlaceholder
_G.ToggleDropDownMenu = noopPlaceholder
_G.GetUnitName = function() return "路人甲-测试服" end
_G.GetCursorPosition = function() return 400, 400 end
_G.InCombatLockdown = function() return _G.__combat == true end
_G.IsMouseButtonDown = function() return false end
_G.GetRealmName = function() return "测试服" end
_G.LEVEL = "等级"
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.RAID_CLASS_COLORS = {
  WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
  MAGE = { r = 0.41, g = 0.80, b = 0.94 },
}
_G.LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "战士", MAGE = "法师" }
_G.LOCALIZED_CLASS_NAMES_FEMALE = { WARRIOR = "战士", MAGE = "法师" }
_G.SlashCmdList = {}
_G.C_Timer = {
  After = function(_, fn) fn() end,
  NewTimer = function(_, fn) fn() return nil end,
}
_G.__hooks = {}
_G.hooksecurefunc = function(name, fn)
  local list = _G.__hooks[name]
  if not list then list = {}; _G.__hooks[name] = list end
  list[#list + 1] = fn
end
_G.__modifyMenu = {}
_G.LibStub = nil
_G.Menu = { ModifyMenu = function(tag) _G.__modifyMenu[tag] = true end }
_G.CanInspect = function() return true end
_G.NotifyInspect = function() end
_G.GetSpecializationInfoByID = function() return 262, "武器", "", "", "", nil, nil end
_G.C_SpecializationInfo = {
  GetSpecialization = function() return 262 end,
  GetInspectSpecialization = function() return 262 end,
  GetSpecializationInfo = function() return 262, "武器" end,
}
_G.C_TooltipInfo = { GetUnit = function() return nil end }
_G.C_LFGList = nil
_G.UnitExists = function(unit) return unit == "player" end
_G.UnitIsPlayer = function() return true end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitName = function(unit)
  if unit == "player" then return "我" end
  return "路人甲", "测试服"
end
_G.UnitClass = function() return "战士" end
_G.UnitGUID = function() return "GUID-1" end
_G.UnitInParty = function() return false end
_G.UnitInRaid = function() return false end
_G.IsInRaid = function() return false end
_G.GetNumGroupMembers = function() return 1 end

_G.CreateFrame = function(kind, name, parent, template)
  local frame = Region(kind)
  frame.__name = name
  frame.__template = template
  frame.__parent = parent
  -- 客户端里带 parent 创建的框体会出现在 parent:GetChildren() 中；
  -- 早期替身漏了这一步，于是「子区域宽度为 0」这类布局事故在离线完全不可见。
  if type(parent) == "table" and type(parent.__children) == "table" then
    parent.__children[#parent.__children + 1] = frame
  end
  if name then _G[name] = frame end
  return frame
end

-- ---------------------------------------------------------------- 加载

local TOC = {
  "Core/Bootstrap.lua",
  "Shared/Theme.lua",
  "Shared/Motion.lua",
  "Shared/Components.lua",
  "Shared/Layer.lua",
  "Core/Config.lua",
  "Core/Init.lua",
  "Domains/Note/Note.lua",
  "Domains/Note/Inspect.lua",
  "Domains/Note/Events.lua",
  "Domains/Note/Menus.lua",
  "Domains/Note/MeetingStone.lua",
  "Domains/Note/UI.lua",
  "Domains/Note/Dialogs.lua",
}

-- WoW 的 TOC 加载器给每个文件传入同一个插件私有表，这里保持一致。
local ns = {}
local sources = {}
for _, relative in ipairs(TOC) do
  local handle = io.open(ADDON_DIR .. "/" .. relative, "r")
  if handle then sources[relative] = handle:read("*a"); handle:close() end
  local chunk, err = loadfile(ADDON_DIR .. "/" .. relative)
  if not chunk then
    errors[#errors + 1] = relative .. " 加载失败：" .. tostring(err)
  else
    local ok, result = pcall(chunk, "LycheeNote", ns)
    if not ok then
      errors[#errors + 1] = relative .. " 执行失败：" .. tostring(result)
    end
  end
end

-- 沙箱没有帧驱动，动画 OnUpdate 永不触发，延迟 Hide 会把「关窗」卡在中间态。
-- 离线一律跑 reduceMotion=true：Motion 走直接落定分支，断言只认终态；
-- 补间本身的正确性由实机探针验证。
_G.LycheeNoteDB = { reduceMotion = true }

--- 跨模块 API 契约检查。
--- 实机事故：模块改名后 MeetingStone.lua / Events.lua 仍在调 LN.Notes.FindRecord，
--- 该方法已改名 Find，于是集合石列表每次格式化都报 nil 调用。
--- 这里从源码里抽出所有 LN.<模块>.<方法> 引用，逐个核对运行时是否真的存在。
local function CheckModuleCalls()
  local LN = ns.LycheeNote
  local missing = {}
  for relative, text in pairs(sources) do
    local line = 0
    for prefix in text:gmatch("[^\n]*") do
      line = line + 1
      for moduleName, method in prefix:gmatch("LN%.(%a[%w]*)%.(%a[%w_]*)") do
        local module = LN[moduleName]
        if type(module) == "table" then
          local value = module[method]
          -- 只检查函数调用形态，跳过字段读取（如 LN.db.records）
          if value == nil and prefix:find("LN%." .. moduleName .. "%." .. method .. "%s*%(") then
            missing[#missing + 1] = relative .. ":" .. line .. " LN." .. moduleName .. "." .. method
          end
        end
      end
    end
  end
  return missing
end

-- ---------------------------------------------------------------- 驱动

local function FireEvent(frame, event, ...)
  local handler = frame:GetScript("OnEvent")
  if not handler then return end
  local ok, err = pcall(handler, frame, event, ...)
  if not ok then errors[#errors + 1] = "事件 " .. event .. "：" .. tostring(err) end
end

local function Check(label, fn)
  local ok, err = pcall(fn)
  if not ok then errors[#errors + 1] = label .. "：" .. tostring(err) end
  record("check", label, ok and "ok" or "FAIL")
end

--- 实机回归：主窗口的每个区域都必须算得出非零尺寸。
local function AssertLaidOut(frame, label)
  assert(frame, label .. " 不存在")
  assert(frame:GetWidth() > 0, label .. " 宽度为 0（锚点被清掉）")
  assert(frame:GetHeight() > 0, label .. " 高度为 0（锚点被清掉）")
end

Check("跨模块 API 契约：LN.<模块>.<方法> 全部存在", function()
  local missing = CheckModuleCalls()
  assert(#missing == 0, "引用了不存在的方法：\n    " .. table.concat(missing, "\n    "))
end)

Check("ADDON_LOADED 派发", function()
  FireEvent(_G.LycheeNoteEvents, "ADDON_LOADED", "LycheeNote")
end)

Check("SavedVariables 名称", function()
  assert(ns.LycheeNote.Config.DB == "LycheeNoteDB", "DB 名不是 LycheeNoteDB")
  assert(type(ns.LycheeNote.db) == "table", "db 未初始化")
  assert(ns.LycheeNote.db.records ~= nil, "noobs 表缺失")
  assert(ns.LycheeNote.db.meetingStone == nil, "meetingStone 配置未清理")
  assert(ns.LycheeNote.db.debug == nil, "debug 配置未清理")
end)

Check("主窗口首次打开", function()
  assert(ns.LycheeNote.UI.Show() == true)
  assert(ns.LycheeNote.Layer.GetBase() ~= nil, "主窗口未进入 Layer")
end)

Check("锚点集合：双锚不清掉第一条", function()
  local Theme = ns.LycheeNote.Theme
  local probe = CreateFrame("Frame", nil, _G.UIParent)
  Theme:Anchor(probe, "TOPLEFT", _G.UIParent, "TOPLEFT", 0, 0)
  Theme:Anchor(probe, "TOPRIGHT", _G.UIParent, "TOPRIGHT", 0, 0)
  assert(#probe.__points == 2, "双锚应保留 2 条，实际 " .. #probe.__points)
  assert(probe:GetWidth() == _G.UIParent:GetWidth(), "双锚后宽度应等于父级宽度")

  -- 幂等：完全相同的锚点不应新增也不应重设
  Theme:Anchor(probe, "TOPRIGHT", _G.UIParent, "TOPRIGHT", 0, 0)
  assert(#probe.__points == 2, "幂等调用不应新增锚点")

  -- 同点换偏移：替换那一条，不追加
  Theme:Anchor(probe, "TOPLEFT", _G.UIParent, "TOPLEFT", 0, -40)
  assert(#probe.__points == 2, "同点换偏移应替换而非追加")

  -- 上下双锚决定高度
  Theme:Anchor(probe, "BOTTOMLEFT", _G.UIParent, "BOTTOMLEFT", 0, 0)
  assert(probe:GetHeight() == _G.UIParent:GetHeight(), "上下双锚后高度应等于父级高度")
end)

--- 递归收集整棵子树（客户端 Frame:GetChildren 只给直接子框体）。
local function CollectTree(root)
  local counts, texts, textures = {}, {}, {}
  local function walk(node, depth)
    if depth > 8 then return end
    for _, child in ipairs({ node:GetChildren() }) do
      local kind = child:GetObjectType()
      counts[kind] = (counts[kind] or 0) + 1
      assert(child:GetWidth() > 0, kind .. " 宽度为 0（锚点丢失）")
      assert(child:GetHeight() > 0, kind .. " 高度为 0（锚点丢失）")
      walk(child, depth + 1)
    end
    for _, region in ipairs({ node:GetRegions() }) do
      local kind = region:GetObjectType()
      counts[kind] = (counts[kind] or 0) + 1
      if kind == "FontString" then
        if region.GetText then
          local text = region:GetText()
          if type(text) == "string" and text ~= "" then texts[#texts + 1] = text end
        end
      elseif kind == "Texture" then
        if region.GetTexture and region:GetTexture() then
          textures[#textures + 1] = region:GetTexture()
        end
      end
    end
  end
  walk(root, 0)
  return counts, texts, textures
end

--- 几何与 Lychee 启动器同源：头/底 56、行高 46 行距 6、底部图标 28/18。
Check("主窗口几何与 Lychee 对齐", function()
  local M = ns.LycheeNote.Theme.Metrics
  assert(M.headerHeight == 56 and M.footerHeight == 56, "头/底应为 56")
  assert(M.rowHeight == 46 and M.rowGap == 6, "列表行应为 46/6")
  assert(M.switchWidth == 32 and M.switchHeight == 18, "开关应为 32×18")
  assert(M.footerIconHit == 28 and M.footerIconSize == 18, "底部图标应为 28 命中 / 18 图形")
  assert(M.footerIconStride == 36, "底部图标间距应为 36（28 命中 + 8 空隙）")
  assert(M.selectionWidth == 2 and M.selectionHeight == 22, "当前项红条应为 2×22")
end)

Check("主窗口各区域都有非零尺寸", function()
  local base = ns.LycheeNote.Layer.GetBase()
  local M = ns.LycheeNote.Theme.Metrics
  AssertLaidOut(base, "主窗口")
  assert(base:GetWidth() == M.windowWidth, "窗口宽 " .. base:GetWidth())
  assert(base:GetHeight() == M.windowHeight, "窗口高 " .. base:GetHeight())

  local counts, texts, textures = CollectTree(base)
  assert((counts.FontString or 0) >= 10, "文本区域数量不足，实际 " .. tostring(counts.FontString))
  assert(#texts >= 8, "有文字的 FontString 不足，实际 " .. #texts)
  assert(#textures >= 8, "有贴图的 Texture 不足，实际 " .. #textures)

  -- 头部与底栏必须真的算出了宽度（黑屏事故的判据）。
  -- 两者高度都是 56，按锚点区分：贴顶的是头部，贴底的是底栏。
  local header, footer, sidebar
  for _, child in ipairs({ base:GetChildren() }) do
    if child:GetObjectType() == "Frame" then
      local points = {}
      for _, p in ipairs(child.__points) do points[p[1]] = true end
      if points.TOPLEFT and points.TOPRIGHT then header = child end
      if points.BOTTOMLEFT and points.BOTTOMRIGHT and not points.TOPLEFT then footer = child end
      if points.TOPLEFT and points.BOTTOMLEFT and not points.TOPRIGHT then sidebar = child end
    end
  end
  assert(header, "找不到贴顶的头部（锚点可能丢失）")
  assert(header:GetWidth() == M.windowWidth, "头部宽应为 " .. M.windowWidth .. "，实际 " .. header:GetWidth())
  assert(footer, "找不到贴底的底栏")
  assert(footer:GetWidth() == M.windowWidth, "底栏宽应为 " .. M.windowWidth .. "，实际 " .. footer:GetWidth())
  assert(sidebar, "找不到侧栏（TOPLEFT + BOTTOMLEFT 双锚）")
  assert(sidebar:GetWidth() == M.sidebarWidth, "侧栏宽应为 " .. M.sidebarWidth .. "，实际 " .. sidebar:GetWidth())
  assert(sidebar:GetHeight() > 300, "侧栏高度异常：" .. sidebar:GetHeight())
end)

--- 侧栏沿用 Lychee 的「当前项」语言：2 × 22 荔枝红短条 + 文字转 text。
Check("侧栏：当前项红条 + 文字提亮", function()
  local base = ns.LycheeNote.Layer.GetBase()
  local M = ns.LycheeNote.Theme.Metrics
  local sidebar
  for _, child in ipairs({ base:GetChildren() }) do
    if child:GetObjectType() == "Frame" then
      local points = {}
      for _, p in ipairs(child.__points) do points[p[1]] = true end
      if points.TOPLEFT and points.BOTTOMLEFT and not points.TOPRIGHT then sidebar = child end
    end
  end
  assert(sidebar, "找不到侧栏")

  local navs = {}
  for _, child in ipairs({ sidebar:GetChildren() }) do
    if child:GetObjectType() == "Button" then navs[#navs + 1] = child end
  end
  assert(#navs == 2, "侧栏应有 2 项，实际 " .. #navs)

  for _, nav in ipairs(navs) do
    assert(nav:GetWidth() > 0 and nav:GetHeight() > 0, "导航项尺寸为 0")
    -- 每一项都带一条预备好的红条贴图，只在当前项显示
    local bar
    for _, region in ipairs({ nav:GetRegions() }) do
      if region:GetObjectType() == "Texture" and region.__color then
        local c = region.__color
        if c[1] > 0.7 and c[2] < 0.4 then bar = region end
      end
    end
    assert(bar, "导航项缺少红色竖条贴图")
  end

  -- 第 1 页时第 1 项亮条、第 2 项不亮；切页后互换。
  -- 红条带 0.10s 淡入淡出：断言前先落定全部动画，只认终态。
  local Motion = ns.LycheeNote.Motion
  assert(Motion and Motion.FinishAll, "Motion 模块缺失或缺少 FinishAll")
  local function barOf(nav)
    for _, region in ipairs({ nav:GetRegions() }) do
      if region:GetObjectType() == "Texture" and region:IsShown() then return region end
    end
  end
  ns.LycheeNote.UI.SelectPage(1)
  Motion.FinishAll()
  assert(barOf(navs[1]), "第 1 页时第 1 项应显示红条")
  assert(not barOf(navs[2]), "第 1 页时第 2 项不应显示红条")
  ns.LycheeNote.UI.SelectPage(2)
  Motion.FinishAll()
  assert(barOf(navs[2]), "第 2 页时第 2 项应显示红条")
  assert(not barOf(navs[1]), "第 2 页时第 1 项不应显示红条")
  ns.LycheeNote.UI.SelectPage(1)
  Motion.FinishAll()
end)

--- 底部联系入口与 Lychee 同形，且不再有作者文字。
Check("底栏：作者微信 + GitHub 两个图标，无文字署名", function()
  local base = ns.LycheeNote.Layer.GetBase()
  local M = ns.LycheeNote.Theme.Metrics
  local footer
  for _, child in ipairs({ base:GetChildren() }) do
    if child:GetObjectType() == "Frame" then
      local points = {}
      for _, p in ipairs(child.__points) do points[p[1]] = true end
      if points.BOTTOMLEFT and points.BOTTOMRIGHT and not points.TOPLEFT then footer = child end
    end
  end
  assert(footer, "找不到底栏")

  local bar
  for _, child in ipairs({ footer:GetChildren() }) do
    if child:GetObjectType() == "Frame" then bar = child end
  end
  assert(bar, "找不到联系入口容器")

  local buttons, icons = {}, 0
  for _, child in ipairs({ bar:GetChildren() }) do
    if child:GetObjectType() == "Button" then buttons[#buttons + 1] = child end
  end
  assert(#buttons == 2, "应有 2 个入口（作者微信 / GitHub），实际 " .. #buttons)
  for index, button in ipairs(buttons) do
    assert(button:GetWidth() == M.footerIconHit, "命中区应为 " .. M.footerIconHit)
    assert(button:GetHeight() == M.footerIconHit, "命中区高应为 " .. M.footerIconHit)
    local anchor
    for _, point in ipairs(button.__points) do
      if point[1] == "LEFT" then anchor = point end
    end
    assert(anchor, "入口缺少 LEFT 锚点")
    if index == 1 then
      assert(anchor[4] == 0, "第 1 项偏移应为 0，实际 " .. tostring(anchor[4]))
    else
      assert(anchor[4] == M.footerIconStride, "第 2 项偏移应为 " .. M.footerIconStride
        .. "，实际 " .. tostring(anchor[4]))
    end
    for _, region in ipairs({ button:GetRegions() }) do
      if region:GetObjectType() == "Texture" and region:GetTexture() then icons = icons + 1 end
    end
  end
  assert(icons == 2, "两个入口都应挂上图标贴图，实际 " .. icons)

  -- 底栏不应再有作者文字
  local credited = false
  for _, region in ipairs({ footer:GetRegions() }) do
    if region:GetObjectType() == "FontString" and (region:GetText() or ""):find("晴昼秋岚") then
      credited = true
    end
  end
  assert(not credited, "底栏不应再有作者文字署名")
  for _, child in ipairs({ footer:GetChildren() }) do
    for _, region in ipairs({ child:GetRegions() }) do
      if region:GetObjectType() == "FontString" and (region:GetText() or ""):find("晴昼秋岚") then
        credited = true
      end
    end
  end
  assert(not credited, "底栏子控件里仍有作者文字署名")
end)

--- uiScale 是「整体偏小 13%」事故的修正：所有窗口都必须真的缩放。
Check("窗口与浮层应用 uiScale", function()
  local M = ns.LycheeNote.Theme.Metrics
  local base = ns.LycheeNote.Layer.GetBase()
  assert(base:GetScale() == M.uiScale, "主窗口缩放应为 " .. M.uiScale .. "，实际 " .. tostring(base:GetScale()))
  local dialog = ns.LycheeNote.Dialogs
  dialog.ShowAddDialog("缩放测试", "测试服")
  local modal = ns.LycheeNote.Layer.HasModal()
  assert(modal, "弹窗应处于模态状态")
  -- 模态弹窗就是当前 shells 里的 frame，从 Layer 拿不到引用，走遍历找 FULLSCREEN_DIALOG 窗口。
  local found
  for _, frame in ipairs({ _G.UIParent:GetChildren() }) do
    if frame.GetScale and frame:GetScale() == M.uiScale and frame:GetWidth() == M.dialogWidth then
      found = frame
    end
  end
  assert(found, "弹窗未应用 uiScale")
  if ns.LycheeNote.Layer.HideModal then ns.LycheeNote.Layer.HideModal(found) end
end)

--- 联系弹窗的荔枝方案：锚在入口栏上方右对齐，不再居中于 UIParent。
Check("联系弹窗锚在入口栏上方", function()
  local Components = ns.LycheeNote.Components
  local Motion = ns.LycheeNote.Motion
  local host = CreateFrame("Frame", nil, _G.UIParent)
  local view = Components.CreateSocialBar(host, {
    { icon = "github", title = "GitHub", url = "https://example.com" },
  })
  view:Open(view.entries[1])
  Motion.FinishAll()
  assert(view.popup, "弹窗未创建")
  local point = view.popup.__points[1]
  assert(point and point[1] == "BOTTOMRIGHT", "弹窗第一锚点应为 BOTTOMRIGHT")
  assert(point[2] == view.frame, "弹窗应锚在入口栏框体上")
  assert(point[3] == "TOPRIGHT", "弹窗应锚在入口栏上方")
  assert(view.backdrop and view.backdrop:IsShown(), "点击遮罩应处于显示状态")
  view:Close()
end)

--- 设置页 = 三行开关（含动态效果）+ 数据段（小节头 / 28 高按钮 / 滚动文本区）。
Check("设置页结构：三行开关与数据段", function()
  local base = ns.LycheeNote.Layer.GetBase()
  ns.LycheeNote.UI.SelectPage(2)
  ns.LycheeNote.Motion.FinishAll()

  local buttons, texts, scrollFrames = {}, {}, 0
  local function walk(node)
    for _, child in ipairs({ node:GetChildren() }) do
      local kind = child:GetObjectType()
      if kind == "Button" then buttons[#buttons + 1] = child end
      if kind == "ScrollFrame" then scrollFrames = scrollFrames + 1 end
      walk(child)
    end
    for _, region in ipairs({ node:GetRegions() }) do
      if region:GetObjectType() == "FontString" and (region:GetText() or "") ~= "" then
        texts[#texts + 1] = region:GetText()
      end
    end
  end
  walk(base)

  local joined = table.concat(texts, "\n")
  assert(joined:find("动态效果", 1, true), "缺少「动态效果」开关行")
  assert(joined:find("数据", 1, true), "缺少数据段小节头")
  local actionButtons = 0
  for _, button in ipairs(buttons) do
    if button:GetWidth() == 48 and button:GetHeight() == 28 then actionButtons = actionButtons + 1 end
  end
  assert(actionButtons == 3, "数据段应有 3 个 48×28 文字按钮，实际 " .. actionButtons)
  -- 列表页 + 设置页各一个滚动视口；文本区内嵌第三个（TextArea 的滚动壳）。
  assert(scrollFrames >= 3, "应有 ≥3 个裸 ScrollFrame（两页视口 + 文本区），实际 " .. scrollFrames)
  ns.LycheeNote.UI.SelectPage(1)
  ns.LycheeNote.Motion.FinishAll()
end)

--- 行池上限与名单长度无关。
Check("行池上限 12 且与名单长度无关", function()
  local source = sources["Domains/Note/UI.lua"]
  assert(source, "读不到 UI.lua")
  local limit = source:match("local MAX_ROWS = (%d+)")
  assert(limit == "12", "行池上限应为 12，实际 " .. tostring(limit))
  assert(not source:find("index", 1, true) or not source:find('key = "index"', 1, true),
    "不应再有序号列")
end)

Check("标记与读取", function()
  ns.LycheeNote.Notes.Add("路人甲", "站位送人头", "测试服", "战士-武器")
  local list = ns.LycheeNote.Notes.List()
  assert(#list == 1, "名单条数应为 1，实际 " .. #list)
  assert(list[1].reason == "站位送人头")
  assert(ns.LycheeNote.Notes.Has("路人甲", "测试服"))
end)

Check("重复标记覆盖", function()
  ns.LycheeNote.Notes.Add("路人甲", "第二次", "测试服")
  assert(ns.LycheeNote.Notes.Count() == 1, "重复标记应覆盖而非新增")
end)

Check("自己不能被标记", function()
  ns.LycheeNote.Notes.Add("我", "自测", "测试服")
  assert(not ns.LycheeNote.Notes.Has("我", "测试服"), "自己不应进入名单")
end)

Check("列表刷新复用行池", function()
  ns.LycheeNote.UI.RefreshIfOpen()
  for index = 1, 60 do
    ns.LycheeNote.Notes.Add("玩家" .. index, "理由" .. index, "测试服")
  end
  ns.LycheeNote.UI.RefreshIfOpen()
  local list = ns.LycheeNote.Notes.List()
  assert(#list == 61, "名单应累计 61 条，实际 " .. #list)
  record("check", "大名单刷新无错误", "ok")
end)

Check("理由弹窗开关", function()
  ns.LycheeNote.Config.SetBool("askReason", true)
  ns.LycheeNote.Notes.Mark("路人甲", "测试服")
  assert(ns.LycheeNote.Layer.HasModal(), "askReason=true 时应弹出弹窗")
  ns.LycheeNote.Layer.HideModal()
  ns.LycheeNote.Config.SetBool("askReason", false)
  local before = ns.LycheeNote.Notes.Count()
  ns.LycheeNote.Notes.Mark("右键哥", "测试服")
  assert(ns.LycheeNote.Notes.Count() == before + 1, "askReason=false 时应直接写入")
end)

Check("导出与导入往返", function()
  local list = ns.LycheeNote.Notes.List()
  local encoded = ns.LycheeNote.Notes.EncodeBase64(ns.LycheeNote.Notes.Serialize(list))
  local decoded = ns.LycheeNote.Notes.Parse(ns.LycheeNote.Notes.DecodeBase64(encoded))
  assert(type(decoded) == "table" and #decoded == #list, "往返条数不一致")
  local merged, skipped = ns.LycheeNote.Notes.Merge(decoded)
  assert(merged == 0, "同时间戳重复导入应为 0，实际 " .. merged)
  assert(skipped == 0, "合法记录不应被跳过")
end)

Check("移除标记", function()
  assert(ns.LycheeNote.Notes.Remove("玩家60", "测试服") == true)
  assert(not ns.LycheeNote.Notes.Has("玩家60", "测试服"))
end)

Check("页面切换", function()
  ns.LycheeNote.UI.SelectPage(2)
  ns.LycheeNote.UI.SelectPage(3)
  ns.LycheeNote.UI.SelectPage(1)
  assert(true)
end)

Check("停用后取消队伍订阅", function()
  ns.LycheeNote.SetEnabled(false)
  assert(not _G.LycheeNoteEvents:IsEventRegistered("GROUP_ROSTER_UPDATE"), "停用后不应继续订阅")
  ns.LycheeNote.SetEnabled(true)
  assert(_G.LycheeNoteEvents:IsEventRegistered("GROUP_ROSTER_UPDATE"), "启用后应恢复订阅")
end)

Check("右键菜单入口已注册", function()
  assert(next(_G.__modifyMenu) ~= nil, "Menu.ModifyMenu 未注册任何单位类型")
  assert(_G.__hooks.ToggleDropDownMenu ~= nil, "旧下拉兜底未安装")
end)

Check("职业专精缓存", function()
  local value = ns.LycheeNote.Inspect.GetCachedClassSpec("路人甲")
  record("check", "缓存初值", tostring(value))
  ns.LycheeNote.Inspect.ClearCache()
  assert(ns.LycheeNote.Inspect.GetCachedClassSpec("路人甲") == nil, "清缓存后应为空")
end)

Check("战斗进入只隐藏", function()
  _G.__combat = true
  FireEvent(_G.LycheeNoteEvents, "PLAYER_REGEN_DISABLED")
  assert(ns.LycheeNote.Layer.GetBase() == nil, "进入战斗应隐藏主窗口")
  _G.__combat = false
end)

Check("ESC 层级", function()
  ns.LycheeNote.UI.Show()
  ns.LycheeNote.Layer.OnEscape()
  assert(ns.LycheeNote.Layer.GetBase() == nil, "ESC 应关闭主窗口")
  ns.LycheeNote.UI.Show()
  ns.LycheeNote.Dialogs.ShowEditDialog("路人甲", "测试服", function() end)
  assert(ns.LycheeNote.Layer.HasModal(), "应打开编辑弹窗")
  assert(ns.LycheeNote.Layer.OnEscape() and not ns.LycheeNote.Layer.HasModal(), "ESC 应先关弹窗")
  assert(ns.LycheeNote.Layer.GetBase() ~= nil, "关闭弹窗后主窗口应保留")
  ns.LycheeNote.Layer.OnEscape()
  assert(ns.LycheeNote.Layer.GetBase() == nil, "再按 ESC 应关闭主窗口")
end)

Check("斜杠命令", function()
  assert(SLASH_LYCHEENOTE1 == "/note", "主命令应为 /note，实际 " .. tostring(SLASH_LYCHEENOTE1))
  SlashCmdList["LYCHEENOTE"]("")
  assert(ns.LycheeNote.Layer.GetBase() ~= nil, "/note 应打开窗口")
  SlashCmdList["LYCHEENOTE"]("off")
  assert(ns.LycheeNote.Config.IsEnabled() == false)
  SlashCmdList["LYCHEENOTE"]("on")
  assert(ns.LycheeNote.Config.IsEnabled() == true)
  SlashCmdList["LYCHEENOTE"]("add 斜杠理由")
  assert(ns.LycheeNote.Notes.Has("路人甲", "测试服"), "/note add 未写入记录")
  assert(SlashCmdList["LNADD"] == nil, "/lnadd 不应再注册")
end)

Check("集合石缺席时零副作用", function()
  _G.MeetingStone_ApplicantPanel = nil
  ns.LycheeNote.MeetingStone.Refresh()
  record("check", "集合石未安装", "ok")
end)

-- ---------------------------------------------------------------- 汇总

print(string.format("—— 冒烟测试：%d 项检查，%d 个错误 ——", #log, #errors))
for _, entry in ipairs(log) do print("  " .. entry) end
if #errors > 0 then
  print("失败明细：")
  for _, entry in ipairs(errors) do print("  ✗ " .. entry) end
  os.exit(1)
end
print("全部通过。")
os.exit(0)
