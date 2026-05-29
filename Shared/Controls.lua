local ADDON_NAME, ns = ...

ns.addonName = ns.addonName or ADDON_NAME
ns.RememberNoobControls = ns.RememberNoobControls or {}

local unpack = unpack or table.unpack

local function Style(name)
  return ns.RememberNoobStyle and ns.RememberNoobStyle.Get and ns.RememberNoobStyle.Get(name)
end

local function SetColor(region, methodName, color)
  if region and region[methodName] and color then
    region[methodName](region, unpack(color))
  end
end

function ns.RememberNoobControls.ApplyBackdrop(frame, bgName)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop(Style("PANEL_BACKDROP"))
  SetColor(frame, "SetBackdropColor", Style(bgName or "PANEL_BG"))
  SetColor(frame, "SetBackdropBorderColor", Style("PANEL_BORDER"))
end

function ns.RememberNoobControls.CreateText(parent, text, font, colorName)
  if not parent or not parent.CreateFontString then return nil end
  local template = type(font) == "string" and font or nil
  local region = parent:CreateFontString(nil, "OVERLAY", template)
  if region.SetText then region:SetText(text or "") end
  if font and type(font) ~= "string" and region.SetFontObject then region:SetFontObject(font) end
  SetColor(region, "SetTextColor", Style(colorName or "VALUE_COLOR"))
  return region
end

local localizedClassTokens = nil

local function BuildLocalizedClassTokens()
  localizedClassTokens = {}
  local sources = {LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE}
  for _, source in ipairs(sources) do
    if source then
      for classToken, localizedName in pairs(source) do
        if localizedName then localizedClassTokens[localizedName] = classToken end
      end
    end
  end
end

function ns.RememberNoobControls.GetClassSpecColor(classSpec)
  if not classSpec then return nil end
  if not localizedClassTokens then BuildLocalizedClassTokens() end

  local className = classSpec:match("^([^-]+)")
  local classToken = className and localizedClassTokens[className]
  local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
  local color = classToken and colors and colors[classToken]
  if color then return {color.r, color.g, color.b, 1} end
end

function ns.RememberNoobControls.SetClassSpecText(fontString, prefix, classSpec, fallbackColorName)
  if not fontString then return end
  local value = classSpec or "尚未获取"
  local color = ns.RememberNoobControls.GetClassSpecColor(value)
  local displayValue = value
  if color then
    displayValue = string.format("|cff%02x%02x%02x%s|r",
      math.floor(color[1] * 255 + 0.5),
      math.floor(color[2] * 255 + 0.5),
      math.floor(color[3] * 255 + 0.5),
      value)
  end
  if fontString.SetText then fontString:SetText((prefix or "") .. displayValue) end
  SetColor(fontString, "SetTextColor", Style(fallbackColorName or "LABEL_COLOR"))
end

function ns.RememberNoobControls.CreateButton(parent, text, width, height, onClick)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  if button.SetSize then button:SetSize(width or 96, height or 24) end
  ns.RememberNoobControls.ApplyBackdrop(button, "VALUE_BOX_BG")

  local label = ns.RememberNoobControls.CreateText(button, text, "GameFontHighlightSmall", "VALUE_COLOR")
  if label and label.SetPoint then label:SetPoint("CENTER", button, "CENTER", 0, 0) end
  if label and label.SetJustifyH then label:SetJustifyH("CENTER") end
  if label and label.SetJustifyV then label:SetJustifyV("MIDDLE") end

  button.label = label
  button.text = label
  if onClick and button.SetScript then button:SetScript("OnClick", onClick) end
  return button
end

function ns.RememberNoobControls.CreateCloseButton(parent, onClick)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  if button.SetSize then button:SetSize(20, 20) end

  if button.SetBackdrop then
    button:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      edgeSize = 1,
    })
    if button.SetBackdropColor then button:SetBackdropColor(0, 0, 0, 0) end
    if button.SetBackdropBorderColor then button:SetBackdropBorderColor(0, 0, 0, 0) end
  end

  local function CreateCloseLine(rotation)
    local line = button.CreateTexture and button:CreateTexture(nil, "ARTWORK") or nil
    if not line then return nil end
    if line.SetColorTexture then line:SetColorTexture(0.92, 0.96, 0.96, 1) end
    if line.SetSize then line:SetSize(11, 2) end
    if line.SetPoint then line:SetPoint("CENTER", button, "CENTER", 0, 0) end
    if line.SetRotation then line:SetRotation(rotation) end
    return line
  end

  button.closeLineA = CreateCloseLine(math.rad(45))
  button.closeLineB = CreateCloseLine(math.rad(-45))

  if button.SetScript then
    button:SetScript("OnEnter", function(self)
      SetColor(self, "SetBackdropColor", Style("CLOSE_BG_HOVER"))
      SetColor(self, "SetBackdropBorderColor", Style("CLOSE_BORDER_HOVER"))
      if self.closeLineA and self.closeLineA.SetColorTexture then
        self.closeLineA:SetColorTexture(1, 1, 1, 1)
      end
      if self.closeLineB and self.closeLineB.SetColorTexture then
        self.closeLineB:SetColorTexture(1, 1, 1, 1)
      end
    end)
    button:SetScript("OnLeave", function(self)
      SetColor(self, "SetBackdropColor", Style("CLOSE_BG_REST"))
      SetColor(self, "SetBackdropBorderColor", Style("CLOSE_BORDER_REST"))
      if self.closeLineA and self.closeLineA.SetColorTexture then
        self.closeLineA:SetColorTexture(0.92, 0.96, 0.96, 0.85)
      end
      if self.closeLineB and self.closeLineB.SetColorTexture then
        self.closeLineB:SetColorTexture(0.92, 0.96, 0.96, 0.85)
      end
    end)
    if onClick then button:SetScript("OnClick", onClick) end
  end
  return button
end

function ns.RememberNoobControls.CreateTabButton(parent, text, width, height, active, onClick)
  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  if button.SetSize then button:SetSize(width or 100, height or 26) end
  ns.RememberNoobControls.ApplyBackdrop(button, active and "TAB_ACTIVE_BG" or "TAB_INACTIVE_BG")

  local label = ns.RememberNoobControls.CreateText(button, text, "GameFontHighlightSmall", active and "VALUE_COLOR" or "LABEL_COLOR")
  if label and label.SetPoint then label:SetPoint("CENTER", button, "CENTER", 0, 0) end
  if label and label.SetJustifyH then label:SetJustifyH("CENTER") end
  if label and label.SetJustifyV then label:SetJustifyV("MIDDLE") end

  button.label = label
  button.text = label

  function button:SetActive(isActive)
    ns.RememberNoobControls.ApplyBackdrop(self, isActive and "TAB_ACTIVE_BG" or "TAB_INACTIVE_BG")
    SetColor(self.label, "SetTextColor", Style(isActive and "VALUE_COLOR" or "LABEL_COLOR"))
  end

  if onClick and button.SetScript then button:SetScript("OnClick", onClick) end
  return button
end
