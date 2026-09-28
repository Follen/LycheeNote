-- 探针：动画终态验证（Shared/Motion.lua 的驱动在实机真的会 tick）。
-- 主探针在同一帧内读不到淡出结束后的状态，这里用 C_Timer 延迟读取：
-- 切页 0.35s 后：目标页显示、另一页隐藏、头部动作按钮互换；
-- 页面锚点数与尺寸必须完好——双锚被动画拆掉曾导致整页空白（实机事故）。
-- 窗口 Presence 结束后 alpha 回 1、锚点组复位。输出全部 ASCII 转义。

local probe = ...
assert(probe:Async(30))

local out = {}
local function esc(s)
  if type(s) ~= "string" then s = tostring(s) end
  return (s:gsub("[^\32-\126]", function(c) return string.format("<%02X>", string.byte(c)) end))
end
local function put(k, v) out[#out + 1] = tostring(k) .. "=" .. esc(v) end

local LN = _G.LycheeNote
if not LN or not LN.Motion or not LN.UI or not C_Timer then
  put("skip", "true")
  probe:Finish(out)
  return
end

local Layer = LN.Layer
if Layer and Layer.HideBase then pcall(Layer.HideBase) end
local okShow = pcall(LN.UI.Show, LN.UI)
put("show.ok", tostring(okShow))

local base = Layer and Layer.GetBase and Layer.GetBase()
local anchorAtShow
if base then
  local points = {}
  local count = base:GetNumPoints()
  for index = 1, count do
    local p, rel, rp, x, y = base:GetPoint(index)
    points[#points + 1] = string.format("%s|%s|%s|%s|%s", tostring(p), tostring(rel), tostring(rp), tostring(x), tostring(y))
  end
  anchorAtShow = table.concat(points, ";")
end
put("anchorAtShow", anchorAtShow or "?")
put("alphaEarly", base and string.format("%.2f", base:GetAlpha() or -1) or "?")

local function findActionButtons()
  local acts = {}
  if not base then return acts end
  for _, child in ipairs({ base:GetChildren() }) do
    if child.GetObjectType and child:GetObjectType() == "Frame" then
      local w, h = child:GetWidth() or 0, child:GetHeight() or 0
      if math.abs(w - 640) < 2 and math.abs(h - 56) < 2 then
        for _, button in ipairs({ child:GetChildren() }) do
          if button.GetObjectType and button:GetObjectType() == "Button"
            and math.abs((button:GetWidth() or 0) - 32) < 1.5 then
            acts[#acts + 1] = button
          end
        end
        break
      end
    end
  end
  return acts
end

local function findPages()
  local pages = {}
  if not base then return pages end
  local function walk(node)
    for _, child in ipairs({ node:GetChildren() }) do
      local w, h = child:GetWidth() or 0, child:GetHeight() or 0
      if math.abs(w - 608) < 2 and math.abs(h - 328) < 2 then pages[#pages + 1] = child end
      walk(child)
    end
  end
  walk(base)
  return pages
end

pcall(LN.UI.SelectPage, 2)

-- 0.35s：切页 Slide（0.18s）必已完成。
C_Timer.After(0.35, function()
  local acts = findActionButtons()
  local pages = findPages()
  put("t350.actions", #acts)
  for index, button in ipairs(acts) do
    put("t350.action" .. index, tostring(button:IsShown()))
  end
  put("t350.pages", #pages)
  for index, page in ipairs(pages) do
    if page.IsShown and page:IsShown() then
      local okn, num = pcall(page.GetNumPoints, page)
      put("t350.page" .. index .. ".points", okn and tostring(num) or "?")
      put("t350.page" .. index .. ".size", string.format("%.0fx%.0f", page:GetWidth() or -1, page:GetHeight() or -1))
      put("t350.page" .. index .. ".alpha", string.format("%.2f", page:GetAlpha() or -1))
    end
  end

  -- 回名单页，再等 Presence（0.42s）完整结束。
  pcall(LN.UI.SelectPage, 1)
  C_Timer.After(0.65, function()
    if base then
      put("t1000.alpha", string.format("%.2f", base:GetAlpha() or -1))
      local points = {}
      local count = base:GetNumPoints()
      for index = 1, count do
        local p, rel, rp, x, y = base:GetPoint(index)
        points[#points + 1] = string.format("%s|%s|%s|%s|%s", tostring(p), tostring(rel), tostring(rp), tostring(x), tostring(y))
      end
      local settled = table.concat(points, ";")
      put("t1000.anchorSettled", tostring(settled == anchorAtShow))
      put("t1000.shown", tostring(base:IsShown()))
    end
    if Layer and Layer.HideBase then pcall(Layer.HideBase) end
    probe:Finish(out)
  end)
end)
