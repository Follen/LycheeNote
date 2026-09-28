-- 探针：动画终态验证（Shared/Motion.lua 的驱动在实机真的会 tick）。
-- 主探针在同一帧内读不到淡出结束后的状态，这里用 C_Timer 延迟读取：
-- 切到第 1 页 0.3s 后，第 2 项红条必须已隐藏、alpha 已落定；窗口 Presence
-- 结束后 alpha 必须回到 1、锚点必须复位。输出全部 ASCII 转义。

local probe = ...
assert(probe:Async(30))

local out = {}
local function esc(s)
  if type(s) ~= "string" then s = tostring(s) end
  return (s:gsub("[^\32-\126]", function(c) return string.format("<%02X>", string.byte(c)) end))
end
local function put(k, v) out[#out + 1] = tostring(k) .. "=" .. esc(v) end

local LN = _G.LycheeNote
if not LN or not LN.Motion or not C_Timer then
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
  local p, rel, rp, x, y = base:GetPoint(1)
  anchorAtShow = string.format("%s|%s|%s|%s|%s", tostring(p), tostring(rel), tostring(rp), tostring(x), tostring(y))
end
put("anchorAtShow", anchorAtShow or "?")

-- 中间帧：Presence 进行中，alpha 可能 < 1（视读取时机而定）
put("alphaEarly", base and string.format("%.2f", base:GetAlpha() or -1) or "?")

pcall(LN.UI.SelectPage, 1)

-- 0.35s 后：Presence（0.42s）未完、红条淡出（0.10s）必已完。
-- 1.0s 后：全部动画必须落定。
C_Timer.After(0.35, function()
  local sidebar, navs = nil, {}
  if base then
    for _, child in ipairs({ base:GetChildren() }) do
      if child.GetObjectType and child:GetObjectType() == "Frame" then
        local w = child:GetWidth() or 0
        if math.abs(w - 172) < 2 then sidebar = child break end
      end
    end
  end
  if sidebar then
    for _, child in ipairs({ sidebar:GetChildren() }) do
      if child.GetObjectType and child:GetObjectType() == "Button" then navs[#navs + 1] = child end
    end
  end
  local function barShown(button)
    if not button then return "?" end
    for _, region in ipairs({ button:GetRegions() }) do
      if region.GetObjectType and region:GetObjectType() == "Texture" then
        return tostring(region:IsShown())
      end
    end
    return "?"
  end
  put("t350.nav1bar", barShown(navs[1]))
  put("t350.nav2bar", barShown(navs[2]))

  C_Timer.After(0.65, function()
    if base then
      put("t1000.alpha", string.format("%.2f", base:GetAlpha() or -1))
      local p, rel, rp, x, y = base:GetPoint(1)
      local settled = string.format("%s|%s|%s|%s|%s", tostring(p), tostring(rel), tostring(rp), tostring(x), tostring(y))
      put("t1000.anchor", settled)
      put("t1000.anchorSettled", tostring(settled == anchorAtShow))
      put("t1000.shown", tostring(base:IsShown()))
    end
    pcall(LN.UI.SelectPage, 2)
    C_Timer.After(0.35, function()
      local function barOf(button)
        if not button then return "?" end
        for _, region in ipairs({ button:GetRegions() }) do
          if region.GetObjectType and region:GetObjectType() == "Texture" then
            return tostring(region:IsShown())
          end
        end
        return "?"
      end
      local sidebar2, nav1, nav2
      for _, child in ipairs({ base:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Frame" then
          local w = child:GetWidth() or 0
          if math.abs(w - 172) < 2 then sidebar2 = child break end
        end
      end
      if sidebar2 then
        local list = {}
        for _, child in ipairs({ sidebar2:GetChildren() }) do
          if child.GetObjectType and child:GetObjectType() == "Button" then list[#list + 1] = child end
        end
        nav1, nav2 = list[1], list[2]
      end
      put("t1350.page2.nav1bar", barOf(nav1))
      put("t1350.page2.nav2bar", barOf(nav2))
      if Layer and Layer.HideBase then pcall(Layer.HideBase) end
      probe:Finish(out)
    end)
  end)
end)
