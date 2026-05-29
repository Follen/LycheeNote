local ADDON_NAME, ns = ...

ns.addonName = ns.addonName or ADDON_NAME
ns.RememberNoobStyle = ns.RememberNoobStyle or {}

local BACKDROP = {
  bgFile = "Interface\\Buttons\\WHITE8x8",
  edgeFile = "Interface\\Buttons\\WHITE8x8",
  edgeSize = 1,
}

local TOKENS = {
  PANEL_BACKDROP = BACKDROP,
  PANEL_BG = { 0.07, 0.07, 0.09, 0.88 },
  PANEL_BG_DARK = { 0.045, 0.045, 0.06, 0.90 },
  PANEL_BORDER = { 0.20, 0.20, 0.23, 0.56 },
  L1_BG = { 0.055, 0.055, 0.07, 0.90 },
  L2_BG = { 0.075, 0.075, 0.095, 0.88 },
  LABEL_COLOR = { 0.70, 0.70, 0.76, 1 },
  VALUE_COLOR = { 0.92, 0.92, 0.95, 1 },
  ACCENT_COLOR = { 0.408, 0.659, 0.671, 1 },
  DANGER_COLOR = { 0.85, 0.25, 0.25, 1 },
  VALUE_BOX_BG = { 0.12, 0.12, 0.14, 0.90 },
  VALUE_BOX_BORDER = { 0.22, 0.22, 0.26, 0.70 },
  ROW_EVEN = { 0.055, 0.055, 0.07, 0.50 },
  ROW_ODD = { 0.075, 0.075, 0.095, 0.50 },
  ROW_HOVER = { 0.12, 0.12, 0.14, 0.70 },
  HEADER_BG = { 0.10, 0.10, 0.12, 0.90 },
  TAB_ACTIVE_BG = { 0.12, 0.12, 0.14, 0.90 },
  TAB_INACTIVE_BG = { 0.055, 0.055, 0.07, 0.70 },
  CLOSE_BG_HOVER = { 0.85, 0.25, 0.25, 0.85 },
  CLOSE_BORDER_HOVER = { 0.85, 0.25, 0.25, 0.20 },
  CLOSE_BG_REST = { 0, 0, 0, 0 },
  CLOSE_BORDER_REST = { 0, 0, 0, 0 },
}

function ns.RememberNoobStyle.Get(name)
  return TOKENS[name]
end
