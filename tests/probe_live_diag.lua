-- 探针 3：定位主窗口黑屏
-- 已知：插件已加载（LycheeNoteDB 是 table、LycheeNoteEvents 存在）。
-- 探针环境是受限沙箱：没有 loadfile / IsAddOnLoaded，_G 可读。
-- 假设 A：UI.Show() 抛错 → 只建到外壳，内容全黑。
-- 假设 B：内容建出来了但尺寸/字体/纹理有问题。
-- 输出全部 ASCII 转义，避免国服 GBK 字节触发 report_invalid_utf8。

local probe = ...
assert(probe:Async(30))

local out = {}
local function esc(s)
  if type(s) ~= "string" then s = tostring(s) end
  return (s:gsub("[^\32-\126]", function(c) return string.format("<%02X>", string.byte(c)) end))
end
local function put(k, v) out[#out + 1] = tostring(k) .. "=" .. esc(v) end
local function oneLine(s) return (tostring(s or ""):gsub("[\r\n]+", " | ")) end

local LN = _G.LycheeNote
put("haveLN", LN ~= nil)

if not LN then probe:Finish(out) return end

for _, name in ipairs({ "Theme", "Components", "Layer", "Config", "Notes", "Inspect", "Menus", "UI", "Dialogs", "Events", "MeetingStone" }) do
  out[#out + 1] = "mod." .. name .. "=" .. tostring(LN[name] ~= nil)
end
put("records", LN.Notes and LN.Notes.Count and LN.Notes.Count() or -1)
put("enabled", LN.Config and LN.Config.IsEnabled and tostring(LN.Config.IsEnabled()) or "?")

put("STANDARD_TEXT_FONT", type(STANDARD_TEXT_FONT))
put("fontPath", type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT or "?")

-- 假设 A：复现
local Layer = LN.Layer
if Layer and Layer.HideBase then pcall(Layer.HideBase) end

local ok, err = pcall(function() return LN.UI.Show() end)
put("show.ok", tostring(ok))
put("show.err", oneLine(err))

local base = Layer and Layer.GetBase and Layer.GetBase()
put("haveWindow", base ~= nil)

-- 侧栏导航钮引用，页面切换段用它们核对红条随选区翻转。
local navFrames = {}

if base then
  put("win.size", string.format("%dx%d", base:GetWidth() or -1, base:GetHeight() or -1))
  put("win.alpha", string.format("%.2f", base:GetAlpha() or -1))
  put("win.level", base:GetFrameLevel())
  put("win.shown", tostring(base:IsShown()))

  local counts, texts, textures, sizes = {}, {}, {}, {}
  local function walk(node, depth)
    if depth > 6 or type(node.GetChildren) ~= "function" then return end
    -- GetChildren 返回多值；pcall 只捕获第一个返回值会漏掉全部子框体，
    -- 必须用 { pcall(...) } 打包后再遍历（实机踩过一次）。
    local packed = { pcall(node.GetChildren, node) }
    if not packed[1] then return end
    for index = 2, #packed do
      local child = packed[index]
      if type(child) ~= "table" and type(child) ~= "userdata" then break end
      local kind = "?"
      if type(child.GetObjectType) == "function" then
        local okk, k = pcall(child.GetObjectType, child)
        if okk then kind = tostring(k) end
      end
      counts[kind] = (counts[kind] or 0) + 1
      if kind == "FontString" then
        if #texts < 20 and type(child.GetText) == "function" then
          local okt, t = pcall(child.GetText, child)
          if okt and t and t ~= "" then
            texts[#texts + 1] = oneLine(t) .. " [fw=" .. tostring(child.__lnFontSize or -1) .. "]"
          end
        end
      elseif kind == "Texture" then
        if #textures < 20 and type(child.GetTexture) == "function" then
          local okg, g = pcall(child.GetTexture, child)
          textures[#textures + 1] = (okg and tostring(g) or "ERR")
            .. " [shown=" .. tostring(child:IsShown())
            .. " " .. tostring(child:GetWidth()) .. "x" .. tostring(child:GetHeight()) .. "]"
        end
      elseif kind == "Frame" or kind == "Button" then
        if #sizes < 12 then
          sizes[#sizes + 1] = string.format("%s %dx%d shown=%s",
            kind, child:GetWidth() or -1, child:GetHeight() or -1, tostring(child:IsShown()))
        end
      end
      walk(child, depth + 1)
    end
    -- 文字与贴图挂在 GetRegions 上，GetChildren 看不到（上一版探针因此漏掉全部文本）。
    if type(node.GetRegions) == "function" then
      local packedRegions = { pcall(node.GetRegions, node) }
      if packedRegions[1] then
        for index = 2, #packedRegions do
          local regionItem = packedRegions[index]
          if type(regionItem) ~= "table" and type(regionItem) ~= "userdata" then break end
          local kind = "?"
          if type(regionItem.GetObjectType) == "function" then
            local okk, k = pcall(regionItem.GetObjectType, regionItem)
            if okk then kind = tostring(k) end
          end
          counts[kind] = (counts[kind] or 0) + 1
          if kind == "FontString" and #texts < 20 then
            local okt, t = pcall(regionItem.GetText, regionItem)
            if okt and type(t) == "string" and t ~= "" then
              local _, sh = pcall(regionItem.GetStringHeight, regionItem)
              texts[#texts + 1] = oneLine(t) .. " [h=" .. tostring(sh) .. "]"
            end
          elseif kind == "Texture" and #textures < 20 then
            local okg, g = pcall(regionItem.GetTexture, regionItem)
            if okg and g then
              textures[#textures + 1] = tostring(g) .. " " .. tostring(regionItem:GetWidth())
                .. "x" .. tostring(regionItem:GetHeight())
            end
          end
        end
      end
    end
  end
  walk(base, 0)

  local kinds = {}
  for k, v in pairs(counts) do kinds[#kinds + 1] = k .. ":" .. v end
  table.sort(kinds)
  put("children", table.concat(kinds, ","))
  put("frameSizes", table.concat(sizes, ","))
  put("textCount", #texts)
  for i = 1, math.min(#texts, 10) do put("t" .. i, texts[i]) end
  put("texCount", #textures)
  for i = 1, math.min(#textures, 6) do put("x" .. i, textures[i]) end

  -- 签名控件断言（替代旧标签栏探针）：侧栏导航 + 底栏联系入口 + 无暴雪滚动条箭头。
  -- 实机锚定算出的尺寸是浮点（407.999 这类），一律用 near() 容差，不能 ==。
  local function near(value, target) return math.abs((value or 0) - target) < 1.5 end

  -- 侧栏 172×408 是唯一 172 宽的直接子框体；头部/底栏都是 760×56，按贴底区分。
  local sidebar, footer
  for _, child in ipairs({ base:GetChildren() }) do
    if child.GetObjectType and child:GetObjectType() == "Frame" then
      local w, h = child:GetWidth() or 0, child:GetHeight() or 0
      if near(w, 172) and near(h, 408) then sidebar = child end
      if near(w, 760) and near(h, 56) then
        if math.abs((child:GetBottom() or 0) - (base:GetBottom() or 0)) < 2 then footer = child end
      end
    end
  end

  if sidebar then
    put("sidebar", string.format("%.0fx%.0f", sidebar:GetWidth(), sidebar:GetHeight()))
    local navs = {}
    for _, child in ipairs({ sidebar:GetChildren() }) do
      if child.GetObjectType and child:GetObjectType() == "Button" then navs[#navs + 1] = child end
    end
    put("navButtons", #navs)
    for index, button in ipairs(navs) do
      put("nav" .. index, string.format("%.0fx%.0f", button:GetWidth() or -1, button:GetHeight() or -1))
      local barShown, barW, barH, labelText
      for _, region in ipairs({ button:GetRegions() }) do
        local kind = region.GetObjectType and region:GetObjectType() or "?"
        if kind == "Texture" then
          barShown = region:IsShown()
          barW, barH = region:GetWidth() or -1, region:GetHeight() or -1
        elseif kind == "FontString" then
          labelText = region:GetText()
        end
      end
      put("nav" .. index .. ".bar", string.format("shown=%s %.0fx%.0f",
        tostring(barShown), barW or -1, barH or -1))
      put("nav" .. index .. ".label", labelText or "?")
      -- 期望文本按 UTF-8 字节转义写死，避免源码编码干扰比较。
      local expected = (index == 1)
        and "\232\174\176\229\189\149\229\144\141\229\141\149"  -- 记录名单
        or "\232\174\190\231\189\174"                           -- 设置
      put("nav" .. index .. ".label.ok", tostring(labelText == expected))
      navFrames[index] = button
    end
  else
    put("sidebar", "missing")
  end

  if footer then
    put("footer", string.format("%.0fx%.0f", footer:GetWidth() or -1, footer:GetHeight() or -1))
    local social
    for _, child in ipairs({ footer:GetChildren() }) do
      if near(child:GetWidth() or 0, 64) and near(child:GetHeight() or 0, 28) then social = child end
    end
    if social then
      put("social.bar", string.format("%.0fx%.0f", social:GetWidth(), social:GetHeight()))
      local socialButtons = {}
      for _, child in ipairs({ social:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" then
          socialButtons[#socialButtons + 1] = child
        end
      end
      put("social.buttons", #socialButtons)
      for index, button in ipairs(socialButtons) do
        put("social" .. index, string.format("%.0fx%.0f",
          button:GetWidth() or -1, button:GetHeight() or -1))
        for _, region in ipairs({ button:GetRegions() }) do
          if region.GetObjectType and region:GetObjectType() == "Texture" then
            local okg, texture = pcall(region.GetTexture, region)
            put("social" .. index .. ".icon", string.format("%s %.0fx%.0f",
              okg and tostring(texture) or "ERR", region:GetWidth() or -1, region:GetHeight() or -1))
          end
        end
      end
    else
      put("social.bar", "missing")
    end
    -- 底栏不允许再出现文字署名：收集非空文本并核对作者 ID 字节（昼 = E6 98 BC）。
    local authorBytes = "\230\153\180\230\152\188"
    local found, listed = false, {}
    local function scanTexts(node, depth)
      if depth > 4 or type(node.GetRegions) ~= "function" then return end
      for _, region in ipairs({ node:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
          local okt, text = pcall(region.GetText, region)
          if okt and text and text ~= "" then
            listed[#listed + 1] = oneLine(text)
            if text:find(authorBytes, 1, true) then found = true end
          end
        end
      end
      for _, child in ipairs({ node:GetChildren() }) do
        if type(child.GetRegions) == "function" then scanTexts(child, depth + 1) end
      end
    end
    scanTexts(footer, 0)
    put("footer.texts", #listed)
    put("footer.authorText", tostring(found))
    for i, text in ipairs(listed) do if i <= 4 then put("footerText" .. i, text) end end
  else
    put("footer", "missing")
  end

  -- 滚动条回归判据：UIPanelScrollFrameTemplate 会带出两个 18×15 的暴雪箭头按钮；
  -- 换成裸 ScrollFrame 之后全树不应再有任何 18×15 的 Button。
  local strayArrows = 0
  local function scanArrows(node, depth)
    if depth > 6 or type(node.GetChildren) ~= "function" then return end
    for _, child in ipairs({ node:GetChildren() }) do
      local kind = child.GetObjectType and child:GetObjectType() or "?"
      if kind == "Button" and near(child:GetWidth() or 0, 18) and near(child:GetHeight() or 0, 15) then
        strayArrows = strayArrows + 1
      end
      scanArrows(child, depth + 1)
    end
  end
  scanArrows(base, 0)
  put("strayArrows", strayArrows)
end

-- 页面切换 + 侧栏红条随选区翻转
if LN.UI and LN.UI.SelectPage then
  local function barShown(button)
    if not button then return "?" end
    for _, region in ipairs({ button:GetRegions() }) do
      if region.GetObjectType and region:GetObjectType() == "Texture" then
        return tostring(region:IsShown())
      end
    end
    return "?"
  end
  local okp, errp = pcall(LN.UI.SelectPage, 2)
  put("page2", tostring(okp) .. " " .. oneLine(errp))
  put("page2.nav1bar", barShown(navFrames[1]))
  put("page2.nav2bar", barShown(navFrames[2]))
  pcall(LN.UI.SelectPage, 1)
  put("page1.nav1bar", barShown(navFrames[1]))
  put("page1.nav2bar", barShown(navFrames[2]))
end

-- 弹窗
if LN.Dialogs and LN.Dialogs.ShowAddDialog then
  local okd, errd = pcall(LN.Dialogs.ShowAddDialog, "TARGET", "TESTREALM")
  put("dialog", tostring(okd) .. " " .. oneLine(errd))
  if Layer and Layer.HideModal then pcall(Layer.HideModal) end
end

-- 集合石 hook：实机崩过一次（iconHandler → GetLycheeNoteMatched → 已改名的方法）。
if LN.MeetingStone then
  local okr, errr = pcall(LN.MeetingStone.Refresh)
  put("ms.refresh", tostring(okr) .. " " .. oneLine(errr))

  -- 直接打被 patch 过的列头 iconHandler：不依赖集合石当前有没有搜索结果。
  local okv, env = pcall(function()
    local lib = LibStub and LibStub("NetEaseEnv-1.0", true)
    return lib and lib._NSList and lib._NSList.MeetingStone
  end)
  local value = okv and env and env.BrowsePanel or _G.MeetingStone_BrowsePanel
  if value and value.ActivityList then
    local list = value.ActivityList
    -- 走真实渲染路径：Refresh/Update 会带着真实 activity 触发 OnItemFormatted
    -- → 被 patch 的 iconHandler → GetLycheeNoteMatched → LN.Notes.Find。
    -- 上一版探针给 iconHandler 传 nil/假表，报错来自集合石自身，属于探针无效输入。
    local realItems = 0
    for _, key in ipairs({ "items", "buttons", "rows" }) do
      if type(list[key]) == "table" then realItems = math.max(realItems, #list[key]) end
    end
    put("ms.items", realItems)
    for _, method in ipairs({ "Update", "Refresh", "UpdateItems" }) do
      if type(list[method]) == "function" then
        local okm, errm = pcall(list[method], list)
        put("ms." .. method, tostring(okm) .. " " .. oneLine(errm))
      end
    end
    -- 直接打一次真实条目（若列表里已有数据）
    local sample
    for _, key in ipairs({ "items", "buttons", "rows" }) do
      if type(list[key]) == "table" and list[key][1] then sample = list[key][1] break end
    end
    if sample and type(sample.GetLeader) == "function" then
      local okg, errg = pcall(sample.GetLeader, sample)
      put("ms.sampleLeader", tostring(okg) .. " " .. oneLine(errg))
      local okmatch, errmatch = pcall(function()
        return sample.GetLycheeNoteMatched and sample:GetLycheeNoteMatched()
      end)
      put("ms.sampleMatched", tostring(okmatch) .. " " .. oneLine(errmatch))
    end
  else
    put("ms.browse", "absent")
  end

  -- 名单查询路径本身
  local okq, errq = pcall(LN.Notes.Find, "NOPE", "REALM")
  put("ms.lookup", tostring(okq) .. " " .. oneLine(errq))

  -- 直奔崩过的那一行：我们注入到集合石 Activity 类上的 GetLycheeNoteMatched。
  -- 造一个只带 GetLeader 的最小对象，方法本体与实机完全一致。
  if okv and env then
    for _, className in ipairs({ "Activity", "Applicant" }) do
      local class = env[className]
      if type(class) == "table" and type(class.GetLycheeNoteMatched) == "function" then
        local fake = setmetatable({}, { __index = class })
        fake.GetLeader = function() return "NOPE-REALM" end
        fake.GetName = function() return "NOPE" end
        local okf, errf = pcall(class.GetLycheeNoteMatched, fake)
        put("ms." .. className .. "Matched", tostring(okf) .. " " .. tostring(errf ~= nil and errf or ""))
      else
        put("ms." .. className .. "Class", "absent")
      end
    end
  else
    put("ms.env", "absent")
  end
end

if Layer and Layer.HideBase then pcall(Layer.HideBase) end
probe:Finish(out)
