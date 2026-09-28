--- 荔枝笔记动效层
-- 移植荔枝家族的有界动画：窗口 Presence（16px 上浮 + 淡入 0.42s）、
-- 页面与弹层 Slide（12px 上浮 0.18s / 退出 8px 0.10s）、选中红条 Fade（0.10s）、
-- 品牌弹跳 Brand（1.386s，开窗时一次）。驱动只在动画期间运行，结束即解绑；
-- 战斗与「动态效果」关闭时全部直接落定，不产生常驻每帧回调。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Motion = {}
LN.Motion = Motion

local DURATION_PRESENCE = 0.42
local DURATION_SLIDE_IN = 0.18
local DURATION_SLIDE_OUT = 0.10
local DURATION_FADE = 0.10

local driver
local presence  -- {frame, anchor, phase, direction, done}
local slide     -- {frame, anchor, phase, leaving, done}
local brand     -- {region, size, anchor, elapsed}
local fades = {} -- {region, from, to, elapsed, duration, done, hideAtEnd}
local moves = {} -- {region, parent, from, to, elapsed} 开关滑块的纯水平位移
local tick      -- 前置声明：startDriver 要挂在 OnUpdate 上

local function reduced()
  return LN.Config and LN.Config.GetBool and LN.Config.GetBool("reduceMotion") == true
end

local function blocked()
  return (InCombatLockdown and InCombatLockdown()) or reduced()
end

local function ensureDriver()
  if not driver then
    driver = CreateFrame("Frame")
    driver:Hide()
  end
end

local function startDriver()
  ensureDriver()
  if not driver:GetScript("OnUpdate") then driver:SetScript("OnUpdate", tick) end
  driver:Show()
end

local function maybeSleep()
  if not presence and not slide and not brand and #fades == 0 and #moves == 0 then
    driver:SetScript("OnUpdate", nil)
    driver:Hide()
  end
end

--- 把 frame 送回锚点原位并恢复不透明。
local function settle(job)
  local frame = job.frame
  if frame then
    local a = job.anchor
    if a and a[1] then
      frame:ClearAllPoints()
      frame:SetPoint(a[1], a[2], a[3], a[4], a[5])
    end
    frame:SetAlpha(1)
  end
end

--- 取第一条锚点；拿不到锚点的框体不能参与位移动画。
local function captureAnchor(frame)
  local p, relative, rp, x, y = frame:GetPoint(1)
  if not p then return nil end
  return { p, relative, rp, x, y }
end

--- 窗口级进出：进场上浮 16px，退场下沉，缓动 q*(2-q)，alpha 在前 0.10s 内到位。
function Motion:Presence(frame, shown, done)
  if not frame or frame:IsShown() ~= true and shown ~= true then
    if done then done() end
    return
  end
  if presence and presence.frame ~= frame then
    settle(presence)
  end
  if blocked() then
    if presence then settle(presence) end
    presence = nil
    frame:SetAlpha(1)
    if done then done() end
    return
  end
  local anchor = captureAnchor(frame)
  if not anchor then
    if done then done() end
    return
  end
  presence = {
    frame = frame,
    anchor = anchor,
    phase = shown and 0 or 1,
    direction = shown and 1 or -1,
    done = done,
  }
  startDriver()
end

--- 页面与弹层滑入滑出：进场 12px 上浮 + alpha 0.4→1，退场 8px 下沉 + 淡出。
function Motion:Slide(frame, direction, leaving, done)
  if slide and slide.frame ~= frame then
    settle(slide)
  end
  if blocked() or not frame or frame:IsShown() ~= true then
    if slide then settle(slide) end
    slide = nil
    if done then done() end
    return
  end
  local anchor = captureAnchor(frame)
  if not anchor then
    if done then done() end
    return
  end
  slide = {
    frame = frame,
    anchor = anchor,
    phase = 0,
    direction = direction or 1,
    leaving = leaving == true,
    done = done,
  }
  if not slide.leaving then frame:SetAlpha(0.4) end
  startDriver()
end

--- 选中红条等小纹理的透明度过渡；目标为 0 时结束后隐藏。
function Motion:Fade(region, target, done)
  if not region or not region.SetAlpha then
    if done then done() end
    return
  end
  for index, job in ipairs(fades) do
    if job.region == region then table.remove(fades, index) break end
  end
  local current = region:GetAlpha() or 1
  if blocked() or math.abs(current - target) < 0.001 then
    region:SetAlpha(target)
    if target == 0 then region:Hide() else region:Show() end
    if done then done() end
    return
  end
  region:Show()
  fades[#fades + 1] = {
    region = region, from = current, to = target,
    elapsed = 0, duration = DURATION_FADE, done = done,
  }
  startDriver()
end

--- 开关滑块的纯水平位移：只动 x，不碰透明度，0.18s cubic-out。
function Motion:MoveX(region, parent, target)
  if not region or not region.ClearAllPoints then return end
  for index, job in ipairs(moves) do
    if job.region == region then table.remove(moves, index) break end
  end
  local current = region.__lnMoveX
  if current == nil then current = target end
  local function place(x)
    region.__lnMoveX = x
    region:ClearAllPoints()
    region:SetPoint("LEFT", parent, "LEFT", x, 0)
  end
  if blocked() or math.abs(current - target) < 0.001 then
    place(target)
    return
  end
  moves[#moves + 1] = { region = region, parent = parent, from = current, to = target, elapsed = 0 }
  startDriver()
end

-- 荔枝的挤压 / 抬升 / 回落姿势表， 来自 LycheeTalent Motion:Brand。
local brandPoses = {
  { 0.168, 1.075, 0.925, 0, .42, 0, .70, 1, .42, 0, .75, 1 },
  { 0.504, 0.960, 1.045, 7, .16, .6, .25, 1, .16, .6, .25, 1 },
  { 0.840, 1.035, 0.965, 0, .30, 0, .60, 1, .42, 0, .60, 1 },
  { 1.092, 0.990, 1.012, 1, .16, .7, .30, 1, .16, .7, .30, 1 },
  { 1.386, 1, 1, 0, .20, .7, .30, 1, .20, .7, .30, 1 },
}

local function brandEase(u, x1, y1, x2, y2)
  if u <= 0 then return 0 elseif u >= 1 then return 1 end
  local low, high, t = 0, 1, u
  for _ = 1, 16 do
    t = (low + high) * 0.5
    local v = 1 - t
    if 3 * v * v * t * x1 + 3 * v * t * t * x2 + t * t * t < u then low = t else high = t end
  end
  local v = 1 - t
  return 3 * v * v * t * y1 + 3 * v * t * t * y2 + t * t * t
end

function Motion:StopBrand()
  local job = brand
  brand = nil
  if not job then return end
  if blocked() then return end
  job.region:SetSize(job.size, job.size)
  local a = job.anchor
  job.region:ClearAllPoints()
  job.region:SetPoint(a[1], a[2], a[3], a[4], a[5])
end

--- 品牌标志的 squash / lift / settle 弹跳，窗口打开时播放一次。
function Motion:Brand(region, size)
  if brand and brand.region == region then return end
  self:StopBrand()
  if blocked() or not region or region:IsShown() ~= true then return end
  local anchor = captureAnchor(region)
  if not anchor then return end
  brand = { region = region, size = size or region:GetWidth(), anchor = anchor, elapsed = 0 }
  startDriver()
end

function tick(_, elapsed)
  if presence then
    local job = presence
    if not job.frame:IsShown() then
      settle(job)
      presence = nil
    else
      job.phase = math.max(0, math.min(1, job.phase + elapsed * job.direction / DURATION_PRESENCE))
      local q = job.phase
      local eased = q * (2 - q)
      local alpha = math.min(1, q * DURATION_PRESENCE / 0.10)
      alpha = alpha * (2 - alpha)
      local a = job.anchor
      job.frame:ClearAllPoints()
      job.frame:SetPoint(a[1], a[2], a[3], a[4] + 16 * (1 - eased), a[5])
      job.frame:SetAlpha(alpha)
      if (job.direction == 1 and q == 1) or (job.direction == -1 and q == 0) then
        settle(job)
        presence = nil
        if job.done then job.done() end
      end
    end
  end

  if slide then
    local job = slide
    if not job.frame:IsShown() then
      settle(job)
      slide = nil
    else
      local duration = job.leaving and DURATION_SLIDE_OUT or DURATION_SLIDE_IN
      job.phase = math.min(1, job.phase + elapsed / duration)
      local q = job.phase
      local eased = 1 - (1 - q) ^ 3
      local distance = job.direction * (job.leaving and -8 or 12)
      local a = job.anchor
      job.frame:ClearAllPoints()
      job.frame:SetPoint(a[1], a[2], a[3], a[4] + distance * (job.leaving and eased or 1 - eased), a[5])
      job.frame:SetAlpha(job.leaving and 1 - eased or 0.4 + 0.6 * eased)
      if q == 1 then
        settle(job)
        slide = nil
        if job.done then job.done() end
      end
    end
  end

  if brand then
    local job = brand
    if blocked() or job.region:IsShown() ~= true then
      Motion:StopBrand()
    else
      job.elapsed = job.elapsed + elapsed
      if job.elapsed >= 1.386 then
        Motion:StopBrand()
      else
        local at, sx, sy, offset = 0, 1, 1, 0
        for _, pose in ipairs(brandPoses) do
          if job.elapsed <= pose[1] then
            local t = (job.elapsed - at) / (pose[1] - at)
            local scale = brandEase(t, pose[5], pose[6], pose[7], pose[8])
            local move = brandEase(t, pose[9], pose[10], pose[11], pose[12])
            local x2, y2 = sx + (pose[2] - sx) * scale, sy + (pose[3] - sy) * scale
            local a = job.anchor
            job.region:SetSize(job.size * x2, job.size * y2)
            job.region:ClearAllPoints()
            job.region:SetPoint(a[1], a[2], a[3], a[4],
              a[5] + job.size / 128 * (39 * (y2 - 1) + offset + (pose[4] - offset) * move))
            break
          end
          at, sx, sy, offset = pose[1], pose[2], pose[3], pose[4]
        end
      end
    end
  end

  for index = #fades, 1, -1 do
    local job = fades[index]
    if not job.region.SetParent or job.region:IsShown() ~= true then
      table.remove(fades, index)
    else
      job.elapsed = math.min(job.duration, job.elapsed + elapsed)
      local q = job.elapsed / job.duration
      job.region:SetAlpha(job.from + (job.to - job.from) * (1 - (1 - q) ^ 3))
      if q == 1 then
        table.remove(fades, index)
        job.region:SetAlpha(job.to)
        if job.to == 0 then job.region:Hide() end
        if job.done then job.done() end
      end
    end
  end

  for index = #moves, 1, -1 do
    local job = moves[index]
    job.elapsed = math.min(DURATION_SLIDE_IN, job.elapsed + elapsed)
    local q = job.elapsed / DURATION_SLIDE_IN
    local x = job.from + (job.to - job.from) * (1 - (1 - q) ^ 3)
    job.region.__lnMoveX = x
    job.region:ClearAllPoints()
    job.region:SetPoint("LEFT", job.parent, "LEFT", x, 0)
    if q == 1 then table.remove(moves, index) end
  end

  maybeSleep()
end

--- 立即落定全部动画（战斗强制进入、测试收尾时用）。
function Motion:FinishAll()
  if presence then settle(presence) presence = nil end
  if slide then settle(slide) slide = nil end
  brand = nil
  for index = #fades, 1, -1 do
    local job = fades[index]
    job.region:SetAlpha(job.to)
    if job.to == 0 then job.region:Hide() end
    table.remove(fades, index)
  end
  for index = #moves, 1, -1 do
    local job = moves[index]
    job.region:ClearAllPoints()
    job.region:SetPoint("LEFT", job.parent, "LEFT", job.to, 0)
    job.region.__lnMoveX = job.to
    table.remove(moves, index)
  end
  if driver then driver:SetScript("OnUpdate", nil) driver:Hide() end
end
