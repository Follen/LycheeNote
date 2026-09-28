--- 荔枝笔记窗口层
-- 管理主窗口与模态弹窗的层级、键盘与战斗生命周期。
-- 只有一个 ESC 接收框，零订阅时解绑脚本；战斗只隐藏、不重开。

local ADDON_NAME, ns = ...
local LN = ns.LycheeNote

local Theme = LN.Theme
local Components = LN.Components
local Motion = LN.Motion

local Layer = {}
LN.Layer = Layer

--- 动画只在非战斗时进行；战斗路径全部直接落定。
local function canAnimate()
  return Motion ~= nil and not (InCombatLockdown and InCombatLockdown())
end

local baseFrame      -- 常规窗口
local modalFrame     -- 模态弹窗
local escapeFrame    -- 唯一的 ESC 接收框
local escapeBack     -- 「先返回上一页」钩子（设置页 → 名单），返回 true 表示已消费
local listeners = {} -- 需要在战斗中隐藏的窗口集合

--- 自有浮层（动作菜单）也算一个 ESC 层级，必须先于窗口关闭。
local function actionMenuIsOpen()
  local frame = _G.LycheeNoteActionMenu
  return frame ~= nil and frame:IsShown() == true
end

--- 页面注册 ESC 返回：动作菜单与模态都不在时，先退页再退窗。
function Layer.SetEscapeBack(fn)
  escapeBack = fn
end

function Layer.RegisterCombatHider(frame)
  if frame then listeners[frame] = true end
end

function Layer.UnregisterCombatHider(frame)
  if frame then listeners[frame] = nil end
end

--- ESC：动作菜单 → 模态弹窗 → 页面返回 → 主窗口 → 都不存在时交还给游戏。
function Layer.OnEscape()
  if actionMenuIsOpen() then
    Components.HideActionMenu()
    return true
  end
  if modalFrame then
    Layer.HideModal(modalFrame)
    return true
  end
  if baseFrame and escapeBack and escapeBack() then
    return true
  end
  if baseFrame then
    Layer.HideBase()
    return true
  end
end

function Layer.EnableEscape()
  if not escapeFrame then
    escapeFrame = CreateFrame("Frame", nil, UIParent)
    escapeFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    escapeFrame:SetFrameLevel(200)
    escapeFrame:EnableKeyboard(true)
    escapeFrame:Hide()
    escapeFrame:SetScript("OnKeyDown", function(frame, key)
      if key == "ESCAPE" then
        if Layer.OnEscape() then
          frame:SetPropagateKeyboardInput(false)
          return
        end
      end
      frame:SetPropagateKeyboardInput(true)
    end)
  end
  if not escapeFrame:IsShown() then
    escapeFrame:Show()
    escapeFrame:EnableKeyboard(true)
  end
end

function Layer.DisableEscape()
  if escapeFrame and escapeFrame:IsShown() then
    escapeFrame:Hide()
    escapeFrame:EnableKeyboard(false)
  end
end

local function UpdateInteraction()
  local modalActive = modalFrame ~= nil and modalFrame:IsShown()
  if baseFrame and baseFrame:IsShown() then
    baseFrame:EnableMouse(not modalActive)
    Theme:SetAlpha(baseFrame, modalActive and 0.70 or 1)
  end
end

function Layer.ShowBase(frame)
  if not frame then return end
  if modalFrame then Layer.HideModal(modalFrame) end
  baseFrame = frame
  Layer.RegisterCombatHider(frame)
  frame:Show()
  frame:Raise()
  if canAnimate() then Motion:Presence(frame, true) end
  Layer.EnableEscape()
  UpdateInteraction()
end

function Layer.HideBase()
  if not baseFrame then return end
  local frame = baseFrame
  baseFrame = nil
  Layer.UnregisterCombatHider(frame)
  Components.HideTooltip()
  Components.HideActionMenu()
  if canAnimate() then
    Motion:Presence(frame, false, function() frame:Hide() end)
  else
    frame:Hide()
  end
  if not modalFrame then Layer.DisableEscape() end
  UpdateInteraction()
end

function Layer.GetBase()
  return baseFrame
end

function Layer.ShowModal(frame)
  if not frame then return end
  modalFrame = frame
  Layer.RegisterCombatHider(frame)
  frame:Show()
  frame:Raise()
  if canAnimate() then Motion:Slide(frame, 1) end
  Layer.EnableEscape()
  UpdateInteraction()
end

function Layer.HideModal(frame)
  if modalFrame and frame and modalFrame ~= frame then return end
  local closing = modalFrame
  modalFrame = nil
  if closing then
    closing:Hide()
    Layer.UnregisterCombatHider(closing)
  end
  if baseFrame and baseFrame:IsShown() then baseFrame:Raise() end
  if not baseFrame or not baseFrame:IsShown() then Layer.DisableEscape() end
  UpdateInteraction()
end

function Layer.HasModal()
  return modalFrame ~= nil and modalFrame:IsShown() == true
end

--- 战斗中只隐藏，不在脱战时重开。
function Layer.OnCombatLockdown()
  if not (InCombatLockdown and InCombatLockdown()) then return end
  for frame in pairs(listeners) do
    if frame:IsShown() then frame:Hide() end
  end
  listeners = {}
  baseFrame = nil
  modalFrame = nil
  Layer.DisableEscape()
  Components.HideTooltip()
  Components.HideActionMenu()
end
