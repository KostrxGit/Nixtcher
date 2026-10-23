--!nonstrict
-- Vesna, the wolf pup living in the bar.
--
-- Wanders along her own little track, sits by the clock and blinks, naps while you are
-- away, pants when the CPU runs hot, pricks her ears at notifications, hops when a
-- rebuild or tests pass, droops when they fail, and howls at midnight.
-- Click: a trick. Right-click: start / stop a focus session (she meditates, with a countdown).
-- State comes from the `events` service through noctalia.state (km.event, km.focus, km.ranger).

local cfg = require("./lib/config.luau")
local NAME = cfg.petName or "Vesna"

local TRACK = 112        -- width of the pup's track inside the bar (logical px)
local SPRITE_W = 26
local SPRITE_H = 24
local TICK = 110         -- ms per animation step while she moves (walk, hop, howl, pant)
local SIT_TICK = 300     -- sitting: only blinks, so a slower clock is enough
local CALM_TICK = 1000   -- asleep or meditating
local STEP = 2           -- px per walk step
local MAX_X = TRACK - SPRITE_W

local HOT_TEMP = 82      -- °C
local HOT_LOAD = 85      -- % CPU

local x = math.random(0, MAX_X)
local dir = 1            -- 1 = facing right, -1 = facing left
local tick = 0
local now = 0

-- base behaviour: "walk" | "sit"; overlays: temporary moods that win while active
local base = "sit"
local target = x
local baseUntil = 0
local sleeping = false
local hot = false
local mood: string? = nil   -- "alert" | "hop" | "sad" | "howl"
local moodUntil = 0
local moodLabel = ""
local nextBlink = 0
local lastSeq = -1
local lastStats = 0
local lastDrawn = ""     -- what the bar shows now; skip redraws when nothing changed
local focus = { phase = "idle", endsAt = 0 }
local ranger = false

local function clock(ms: number): string
  local secs = math.max(0, math.floor(ms / 1000 + 0.5))
  return string.format("%d:%02d", secs // 60, secs % 60)
end

local function rand(a: number, b: number): number
  return a + math.random() * (b - a)
end

local function setMood(m: string, ms: number, label: string)
  now = noctalia.nowMs()
  mood = m
  moodUntil = now + ms
  moodLabel = label
  noctalia.setUpdateInterval(TICK) -- react now, even from the slow sleeping clock
end

local function frame(name: string): string
  return `assets/pup/{name}_{if dir > 0 then "r" else "l"}.png`
end

local function chooseBase()
  if math.random() < 0.55 then
    base = "walk"
    -- every few walks, head for the clock end of the track and sit there
    target = if math.random() < 0.35 then MAX_X else math.random(0, MAX_X)
    dir = if target >= x then 1 else -1
  else
    base = "sit"
    baseUntil = now + rand(4000, 11000)
  end
end

local function readStats()
  if now - lastStats < 2000 then
    return
  end
  lastStats = now
  local s = noctalia.systemStats()
  if s == nil or s.cpu == nil then
    hot = false
    return
  end
  local temp = s.cpu.tempC
  hot = (temp ~= nil and temp >= HOT_TEMP) or (s.cpu.usagePercent or 0) >= HOT_LOAD
end

local function currentFrame(): (string, string, string?)
  -- temporary moods first
  if mood and now < moodUntil then
    if mood == "alert" then
      return frame("alert_0"), moodLabel
    elseif mood == "hop" then
      local seq = { "hop_0", "hop_1", "hop_2", "hop_1", "hop_0", "sit_0" }
      return frame(seq[(tick % #seq) + 1]), moodLabel
    elseif mood == "sad" then
      return frame("sad_0"), moodLabel
    elseif mood == "howl" then
      return frame(if (tick // 4) % 2 == 0 then "howl_0" else "howl_1"), moodLabel
    end
  end
  mood = nil

  if focus.phase == "focus" then
    local left = clock(focus.endsAt - now)
    return frame(if (tick // 4) % 2 == 0 then "meditate_0" else "meditate_1"),
      `{NAME} meditates · {left} of focus left · right-click to stop`, left
  end
  local breakNote = if focus.phase == "break" then ` · break, {clock(focus.endsAt - now)} left` else ""

  if sleeping then
    return frame(if (tick // 3) % 2 == 0 then "sleep_0" else "sleep_1"), `{NAME} naps until you're back`
  end
  if hot then
    return frame(if (tick // 2) % 2 == 0 then "pant_0" else "pant_1"), `{NAME} is too hot! The CPU is working hard`
  end
  if base == "walk" then
    local f = frame(`walk_{tick % 4}`)
    x += dir * STEP
    if (dir > 0 and x >= target) or (dir < 0 and x <= target) then
      x = math.clamp(target, 0, MAX_X)
      base = "sit"
      baseUntil = now + rand(3000, 9000)
    end
    return f, `{NAME} is patrolling the bar{breakNote}`
  end
  -- sitting: blink now and then
  if now >= baseUntil then
    chooseBase()
  end
  local blinking = now >= nextBlink and now < nextBlink + 320
  if now >= nextBlink + 320 then
    nextBlink = now + rand(2500, 6000)
  end
  local where = if x >= MAX_X - 4 then `{NAME} sits by the clock` else `{NAME} keeps watch`
  return frame(if blinking then "sit_1" else "sit_0"), where .. breakNote
end

local function render(force: boolean?)
  local img, label, countdown = currentFrame()
  local key = `{img}|{math.floor(x)}|{label}|{countdown or ""}`
  if key == lastDrawn and not force then
    return -- same picture as last time: don't make the bar repaint
  end
  lastDrawn = key
  local children = {}
  if countdown then
    -- meditating: sit at the start of the track with the countdown beside her
    table.insert(children, ui.image({ path = img, width = SPRITE_W, height = SPRITE_H, fit = "contain" }))
    table.insert(children, ui.label({ text = countdown, fontSize = 11, color = "primary", fontWeight = "semibold" }))
  else
    local pad = math.clamp(math.floor(x), 0, MAX_X)
    table.insert(children, ui.spacer({ width = pad })) -- invisible gap (ui.box would draw a line)
    table.insert(children, ui.image({ path = img, width = SPRITE_W, height = SPRITE_H, fit = "contain" }))
  end
  table.insert(children, ui.spacer({ flexGrow = 1 }))
  barWidget.render(ui.row({ width = TRACK, height = SPRITE_H, align = "center", gap = 4, tooltip = label }, children))
end

local function onEvent(ev)
  if type(ev) ~= "table" or ev.seq == lastSeq then
    return
  end
  lastSeq = ev.seq
  local kind = ev.kind
  if kind == "idle" then
    sleeping = true
  elseif kind == "active" then
    if sleeping then
      sleeping = false
      setMood("alert", 1800, `{NAME}: you're back!`)
    end
  elseif kind == "notify" then
    if not mood then
      setMood("alert", 2500, `{NAME} heard something arrive`)
    end
  elseif kind == "agent" then
    sleeping = false
    setMood("alert", 4000, `{NAME}: an agent needs you`)
  elseif kind == "build-ok" or kind == "test-ok" or kind == "agent-done" then
    sleeping = false
    local text = ev.text or ""
    local label = if kind == "test-ok" then "Tests passed!"
      elseif kind == "agent-done" then "An agent finished its turn"
      elseif text == "Contract complete" then "Contract complete!"
      elseif text ~= "" then `{text} brewed!`
      else "Well brewed!"
    setMood("hop", if kind == "agent-done" then 1400 else 2600, label)
  elseif kind == "build-fail" or kind == "test-fail" then
    sleeping = false
    setMood("sad", 5000, if kind == "test-fail" then "Tests failed…" else "The potion spoiled…")
  elseif kind == "reward" then
    sleeping = false
    setMood("hop", 2600, if (ev.text or "") ~= "" then `Crowns earned: {ev.text}` else "Crowns earned!")
  elseif kind == "howl" then
    setMood("howl", 6000, "Awoooo! Midnight")
  end
end

noctalia.state.watch("km.event", onEvent)
noctalia.state.watch("km.focus", function(f)
  if type(f) == "table" then
    if f.phase == "focus" and focus.phase ~= "focus" then
      x = 0
      sleeping = false
    end
    focus = f
  end
end)
noctalia.state.watch("km.ranger", function(on)
  ranger = on == true
end)
do
  local f = noctalia.state.get("km.focus")
  if type(f) == "table" then
    focus = f
  end
  ranger = noctalia.state.get("km.ranger") == true
end

function update()
  now = noctalia.nowMs()
  tick += 1
  readStats()
  local calm = not mood and (sleeping or focus.phase == "focus")
  local moving = mood ~= nil or hot or base == "walk"
  noctalia.setUpdateInterval(if calm then CALM_TICK
    elseif not moving then SIT_TICK
    elseif ranger then 220
    else TICK)
  render()
end

function onClick()
  now = noctalia.nowMs()
  if sleeping then
    sleeping = false
    setMood("alert", 1500, `{NAME}: huh? I'm awake!`)
  elseif math.random() < 0.5 then
    setMood("howl", 2600, "Awoooo!")
  else
    setMood("hop", 1800, `Good {NAME}!`)
  end
  render()
end

function onRightClick()
  noctalia.state.set("km.cmd", { op = "focus", seq = noctalia.nowMs() })
end

nextBlink = noctalia.nowMs() + 3000
