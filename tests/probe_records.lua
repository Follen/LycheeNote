-- 探针：记录丢失定位。拿事实——db 身份、records 内容、名单页渲染状态。
local probe = ...
assert(probe:Async(30))

local out = {}
local function esc(s)
  if type(s) ~= "string" then s = tostring(s) end
  return (s:gsub("[^\32-\126]", function(c) return string.format("<%02X>", string.byte(c)) end))
end
local function put(k, v) out[#out + 1] = tostring(k) .. "=" .. esc(v) end

local LN = _G.LycheeNote
if not LN then put("haveLN", "false") probe:Finish(out) return end

put("count", tostring(LN.Notes and LN.Notes.Count and LN.Notes.Count() or "?"))
put("dbIsGlobal", tostring(_G.LycheeNoteDB == LN.db))
put("dbType", type(LN.db))
put("recordsType", type(LN.db and LN.db.records))
put("schemaMarker", tostring(LN.db and LN.db.__lycheeNoteRecords))

local keys = {}
for key, value in pairs(LN.db.records or {}) do
  keys[#keys + 1] = key .. "(" .. tostring(value and value.name) .. "," .. tostring(value and value.server)
    .. ",ts=" .. tostring(value and value.timestamp) .. ")"
end
put("keys", #keys > 0 and table.concat(keys, ";") or "EMPTY")
put("listCount", tostring(LN.Notes.List and #LN.Notes.List() or "?"))

-- 名单页渲染状态
if LN.UI and LN.UI.Show then pcall(LN.UI.Show, LN.UI) end
local base = LN.Layer and LN.Layer.GetBase and LN.Layer.GetBase()
if base then
  put("win.shown", tostring(base:IsShown()))
  -- 找到名单页里的空状态文字与行
  local emptyText, rows = nil, 0
  local function walk(node, depth)
    if depth > 6 then return end
    for _, child in ipairs({ node:GetChildren() }) do
      if child.GetObjectType and child:GetObjectType() == "Button" then rows = rows + 1 end
      walk(child, depth + 1)
    end
    for _, region in ipairs({ node:GetRegions() }) do
      if region.GetObjectType and region:GetObjectType() == "FontString" then
        local okt, t = pcall(region.GetText, region)
        if okt and t == "\232\191\152\230\178\161\230\156\137\232\174\176\229\189\149" then -- 还没有记录
          emptyText = tostring(region:IsShown())
        end
      end
    end
  end
  walk(base, 0)
  put("page1.emptyTextShown", emptyText or "notfound")
  put("page1.buttons", rows)
end

probe:Finish(out)
