--!nonstrict
-- School medallion in the bar (Wolf, Cat, Griffin or Bear).
-- Click: launcher (and calms the medallion). Right click: control centre. Scroll: change school.
-- Trembles with a glow in the school's colour when something needs you (notification, an
-- agent waiting) and red when a rebuild or tests fail. Agent and rebuild alerts keep humming
-- until clicked.

local cfg = require("./lib/config.luau")

local SIZE = 24
local FRAME_MS = 70

local color: string? = nil    -- "accent" | "red" while trembling
local school = "wolf"
local SCHOOL_NAMES = { wolf = "Wolf", cat = "Cat", griffin = "Griffin", bear = "Bear" }
local untilMs = 0             -- 0 = keep trembling until clicked
local message = ""
local frameIdx = 0
local lastSeq = -1

local function msg(...)
  local args = { ... }
  if cfg.noctalia then
    noctalia.runAsync({ cfg.noctalia, "msg", table.unpack(args) })
  end
end

local function tremble(c: string, ms: number, text: string)
  color = c
  untilMs = if ms > 0 then noctalia.nowMs() + ms else 0
  message = text
end

local function calm()
  color = nil
  message = ""
end

local function render()
  local now = noctalia.nowMs()
  if color and untilMs > 0 and now >= untilMs then
    calm()
  end
  local path = `assets/medallion/{school}/rest.png`
  if color then
    frameIdx = (frameIdx + 1) % 4
    path = `assets/medallion/{school}/hum_{color}_{frameIdx}.png`
  end
  local tip = if message ~= "" then message .. "  ·  click to calm"
    else `School of the {SCHOOL_NAMES[school] or "Wolf"}  ·  click: launcher  ·  scroll: change school`
  barWidget.render(ui.row({ align = "center", tooltip = tip }, {
    ui.image({ path = path, width = SIZE, height = SIZE, fit = "contain" }),
  }))
  noctalia.setUpdateInterval(if color then FRAME_MS else 1000)
end

noctalia.state.watch("km.event", function(ev)
  if type(ev) ~= "table" or ev.seq == lastSeq then
    return
  end
  lastSeq = ev.seq
  local kind, text = ev.kind, ev.text or ""
  if kind == "notify" then
    if color == nil then
      tremble("accent", 2500, "")
    end
  elseif kind == "agent" then
    tremble("accent", 0, if text ~= "" then text else "A Claude agent needs you")
  elseif kind == "build-fail" then
    tremble("red", 0, "Rebuild failed")
  elseif kind == "test-fail" then
    if color == nil then
      tremble("red", 3500, "Tests failed")
    end
  elseif kind == "hum" then
    tremble("accent", 3000, text)
  elseif kind == "build-ok" and color == "red" then
    calm()
  end
  render()
end)

noctalia.state.watch("km.school", function(s)
  if type(s) == "string" and SCHOOL_NAMES[s] then
    school = s
    render()
  end
end)

local initial = noctalia.state.get("km.school")
if type(initial) == "string" and SCHOOL_NAMES[initial] then
  school = initial
end

function update()
  render()
end

function onScroll(axis, steps, startsGesture)
  if axis ~= "vertical" or not startsGesture then
    return
  end
  noctalia.state.set("km.cmd", { op = if steps > 0 then "school-next" else "school-prev", seq = noctalia.nowMs() })
end

function onClick()
  calm()
  render()
  msg("panel-toggle", "launcher")
end

function onRightClick()
  msg("panel-toggle", "control-center")
end

render()
