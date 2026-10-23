--!nonstrict
-- Kaer Morhen event service (headless). The one place that keeps state, plays sounds and
-- sends notifications; the bar widgets, panels and tiles only display what it publishes.
--
-- Inputs
--   shell / hooks:  noctalia msg plugin konstanty/kaer-morhen:events all <event> [text]
--                   (the `witcher` command wraps this; Noctalia's lock hooks call it too)
--   UI entries:     noctalia.state "km.cmd" = { op, arg, seq }
--   notifications:  dbus-monitor on the session bus (any app's Notify call)
-- Outputs (noctalia.state)
--   km.event   { kind, text, seq }        one-off events for the pup and medallion
--   km.school  "wolf" | "cat" | "griffin" | "bear"
--   km.focus   { phase, endsAt, round, todayRounds }   focus timer
--   km.scroll  { round, minutes, todayRounds }         last completed focus session
--   km.health  battery health in percent (or nil)
--   km.ranger  boolean

local cfg = require("./lib/config.luau")
local sun = require("./lib/sun.luau")

local SCHOOLS = { "wolf", "cat", "griffin", "bear" }
local SCHOOL_NAMES = { wolf = "Wolf", cat = "Cat", griffin = "Griffin", bear = "Bear" }
local PALETTES = cfg.palettes or { wolf = "witcher", cat = "km-cat", griffin = "km-griffin", bear = "km-bear" }
local FOCUS_MIN = cfg.focusMinutes or 25
local BREAK_MIN = cfg.breakMinutes or 5
local LONG_BREAK_MIN = cfg.longBreakMinutes or 15
local PET = cfg.petName or "Vesna"

-- ── Persistent state (pluginDataDir/state.json) ─────────────────────────────
local dataDir = noctalia.pluginDataDir()
local statePath = if dataDir then dataDir .. "/state.json" else nil
local saved = { school = "wolf", briefDate = "", healthWarned = "", roundsDate = "", rounds = 0 }
if statePath then
  local raw = noctalia.readFile(statePath)
  local decoded = if raw then noctalia.json.decode(raw) else nil
  if type(decoded) == "table" then
    for k, v in decoded do
      saved[k] = v
    end
  end
end
local function save()
  if statePath then
    noctalia.writeFile(statePath, noctalia.json.encode(saved))
  end
end

local function today(): string
  return os.date("%Y-%m-%d") :: string
end

local seq = 0
local function publish(kind: string, text: string?)
  seq += 1
  noctalia.state.set("km.event", { kind = kind, text = text or "", seq = seq, at = noctalia.nowMs() })
end

local function msg(...)
  if cfg.noctalia then
    noctalia.runAsync({ cfg.noctalia, "msg", ... })
  end
end

-- Filled in by the encounters section further down (focus done, builds, tests, schools)
local hooks: { [string]: any } = {}
local quietUntil = 0 -- no encounter cards before this (another panel is showing)

-- ── Sounds ───────────────────────────────────────────────────────────────────
local loaded = {}
local function loadSound(name: string, file: string)
  noctalia.sound.load(name, "assets/sounds/" .. file, function(ok, err)
    loaded[name] = ok
    if not ok then
      noctalia.log(`kaer-morhen: could not load {file}: {err}`)
    end
  end)
end
for _, s in SCHOOLS do
  loadSound("hum-" .. s, `hum-{s}.wav`)
end
loadSound("blade", "blade.wav")
loadSound("done", "potion-done.wav")
loadSound("fail", "potion-fail.wav")
loadSound("scroll", "scroll.wav")
loadSound("break", "break-over.wav")
loadSound("chime", "chime.wav")

local function play(name: string)
  if name == "hum" then
    name = "hum-" .. saved.school
  end
  if loaded[name] then
    noctalia.sound.play(name)
  end
end

-- ── Schools ──────────────────────────────────────────────────────────────────
local function setSchool(name: string, announce: boolean)
  if not SCHOOL_NAMES[name] then
    noctalia.notifyError("Unknown school", `"{name}". Choose wolf, cat, griffin or bear.`)
    return
  end
  saved.school = name
  save()
  noctalia.state.set("km.school", name)
  if hooks.school then
    hooks.school(name)
  end
  if announce then
    msg("color-scheme-set", "custom", PALETTES[name])
    play("hum")
    noctalia.notify(`School of the {SCHOOL_NAMES[name]}`, "Palette, medallion and sounds changed.")
  end
end

local function stepSchool(dir: number)
  local idx = 1
  for i, s in SCHOOLS do
    if s == saved.school then
      idx = i
    end
  end
  setSchool(SCHOOLS[((idx - 1 + dir) % #SCHOOLS) + 1], true)
end

-- ── Focus timer (Vesna meditates) ───────────────────────────────────────────
local focus = { phase = "idle", endsAt = 0, round = 0 }

local function todayRounds(): number
  if saved.roundsDate ~= today() then
    saved.roundsDate = today()
    saved.rounds = 0
  end
  return saved.rounds
end

local function publishFocus()
  noctalia.state.set("km.focus", {
    phase = focus.phase, endsAt = focus.endsAt, round = focus.round, todayRounds = todayRounds(),
  })
end

local function startFocus()
  focus.phase = "focus"
  focus.round += 1
  focus.endsAt = noctalia.nowMs() + FOCUS_MIN * 60000
  publishFocus()
  noctalia.notify(`{PET} begins to meditate`, `Focus for {FOCUS_MIN} minutes. Right-click her to stop.`)
end

local function stopFocus()
  focus.phase = "idle"
  focus.endsAt = 0
  publishFocus()
end

local function finishFocus()
  saved.rounds = todayRounds() + 1
  save()
  quietUntil = noctalia.nowMs() + 12000 -- let the scroll finish first
  if hooks.focusDone then
    hooks.focusDone()
  end
  local long = focus.round % 4 == 0
  local rest = if long then LONG_BREAK_MIN else BREAK_MIN
  noctalia.state.set("km.scroll", {
    round = focus.round, minutes = FOCUS_MIN, todayRounds = saved.rounds, rest = rest, pet = PET,
  })
  play("scroll")
  noctalia.togglePanel("konstanty/kaer-morhen:scroll")
  focus.phase = "break"
  focus.endsAt = noctalia.nowMs() + rest * 60000
  publishFocus()
  publish("build-ok", "Contract complete")
end

local function finishBreak()
  play("break")
  noctalia.notify("Back to the Path", `{PET} is rested. Right-click her for another focus session.`)
  stopFocus()
  publish("active", "")
end

local function toggleFocus()
  if focus.phase == "idle" then
    startFocus()
  else
    stopFocus()
    noctalia.notify(`{PET} stops meditating`, "Focus timer stopped.")
  end
end

-- ── Battery health ───────────────────────────────────────────────────────────
local function readNumber(path: string): number?
  local raw = noctalia.readFile(path)
  return if raw then tonumber(noctalia.string.trim(raw)) else nil
end

local function batteryHealth(): number?
  local bat = cfg.battery or "/sys/class/power_supply/BAT0"
  local full = readNumber(bat .. "/energy_full") or readNumber(bat .. "/charge_full")
  local design = readNumber(bat .. "/energy_full_design") or readNumber(bat .. "/charge_full_design")
  if not full or not design or design <= 0 then
    return nil
  end
  return math.floor(full / design * 100 + 0.5)
end

local lastHealthCheck = -1
local function checkHealth()
  local now = noctalia.nowMs()
  if lastHealthCheck >= 0 and now - lastHealthCheck < 3600000 then
    return
  end
  lastHealthCheck = now
  local h = batteryHealth()
  noctalia.state.set("km.health", h)
  local week = os.date("%Y-%W") :: string
  if h and h < (cfg.healthWarnBelow or 80) and saved.healthWarned ~= week then
    saved.healthWarned = week
    save()
    noctalia.notify("Battery health is fading", `The battery holds {h}% of its original capacity.`)
    publish("hum", `Battery health {h}%`)
  end
end

-- ── Ranger mode: long sessions on battery ───────────────────────────────────
local ranger = false
local savedBrightness: number? = nil

local function brightnessPercent(): number?
  local dir = cfg.backlight
  if not dir then
    local devices = noctalia.listDir("/sys/class/backlight")
    dir = if devices and devices[1] then "/sys/class/backlight/" .. devices[1] else nil
  end
  if not dir then
    return nil
  end
  local cur, max = readNumber(dir .. "/brightness"), readNumber(dir .. "/max_brightness")
  if not cur or not max or max <= 0 then
    return nil
  end
  return math.floor(cur / max * 100 + 0.5)
end

local function setRanger(on: boolean)
  if on == ranger then
    return
  end
  ranger = on
  if on then
    savedBrightness = brightnessPercent()
    msg("power-set", "power-saver")
    msg("brightness-set", "*", "40%")
    noctalia.notify("Ranger mode", "Power saver, dimmer screen, a calmer pup. Long road ahead.")
  else
    msg("power-set", "balanced")
    msg("brightness-set", "*", `{savedBrightness or 70}%`)
    noctalia.notify("Ranger mode off", "Back to normal power.")
  end
  noctalia.state.set("km.ranger", ranger)
end

-- ── Morning brief: first login or unlock of the day ─────────────────────────
local briefPending = false
local function maybeBrief()
  local d = os.date("*t") :: any
  if saved.briefDate ~= today() and d.hour >= 5 then
    briefPending = true
  end
end

local function openBrief()
  saved.briefDate = today()
  save()
  quietUntil = noctalia.nowMs() + 60000
  noctalia.togglePanel("konstanty/kaer-morhen:brief")
end

-- ── Encounters and the bestiary ─────────────────────────────────────────────
local E = require("./lib/encounters.luau")
local contractsLib = require("./lib/contracts.luau")
local ENC = cfg.encounters or {}
local ENC_PER_DAY = ENC.perDay or 5
local ENC_FROM, ENC_TO = ENC.from or 9, ENC.to or 22
local TEASERS = {
  merchant = "A merchant asked me to find you. He's waiting in the corner.",
  monster = "Contract posted on the board! Something lurks near the repos.",
  traveller = "A hooded traveller left a message for you.",
}
E.init(saved)

local daily = { date = "", builds = 0, tests = 0 }
local function dailyCounts()
  if daily.date ~= today() then
    daily = { date = today(), builds = 0, tests = 0 }
  end
  return daily
end
local commitsToday, contractsReviewDone = 0, 0

local function countReviewDone(): number
  local n = 0
  for _, c in contractsLib.scan(cfg.codeDirs or {}) do
    if c.key == "review" or c.key == "done" then
      n += 1
    end
  end
  return n
end

local function metrics()
  local d = dailyCounts()
  return {
    focusToday = todayRounds(), buildsToday = d.builds, testsToday = d.tests,
    commitsToday = commitsToday, contractsToday = contractsReviewDone,
  }
end

local function publishBestiary()
  local progress, goal, c = E.challengeProgress(saved, today(), metrics())
  noctalia.state.set("km.bestiary", {
    crowns = saved.crowns, badges = saved.badges, hunts = saved.hunts, bestiary = saved.bestiary,
    challenge = if c then { title = c.title, text = c.text, progress = progress, goal = goal,
      done = saved.challenge.done, reward = c.reward } else nil,
    paused = saved.encPaused == true, perDay = ENC_PER_DAY, seq = noctalia.nowMs(),
  })
end

local function checkProgress()
  local c = E.checkChallenge(saved, today(), metrics())
  if c then
    save()
    play("done")
    noctalia.notify(`Challenge complete: {c.title}`, `The merchant pays {c.reward} crowns. Purse: {saved.crowns}.`)
    publish("reward", c.title)
  end
  publishBestiary()
end

local function refreshCounters()
  contractsReviewDone = countReviewDone()
  local repos = contractsLib.repos(cfg.codeDirs or {})
  if not cfg.git or #repos == 0 then
    checkProgress()
    return
  end
  local total, pending = 0, #repos
  for _, r in repos do
    noctalia.runAsync({ cfg.git, "-C", r.path, "rev-list", "--count", "--since=midnight", "--all" }, function(res)
      pending -= 1
      if res.exitCode == 0 then
        total += tonumber(noctalia.string.trim(res.stdout)) or 0
      end
      if pending == 0 then
        commitsToday = total
        checkProgress()
      end
    end)
  end
end

local current = nil -- the encounter card on screen
local queue = {}    -- badges waiting for a quiet moment
local encSeq = 0
local idleNow, lockedNow = false, false

local function showEncounter(enc)
  encSeq += 1
  enc.seq = encSeq
  current = enc
  noctalia.state.set("km.encounter", enc)
  noctalia.togglePanel("konstanty/kaer-morhen:encounter")
  play(if enc.kind == "badge" then "scroll" else "chime")
  if cfg.sigurd and ENC.sigurd ~= false and TEASERS[enc.kind] then
    noctalia.runAsync({ cfg.sigurd, "say", TEASERS[enc.kind] })
  end
end

local function grantBadges()
  local new = E.checkBadges(saved, {
    today = today(),
    daysAgo = function(n)
      return os.date("%Y-%m-%d", os.time() - n * 86400) :: string
    end,
  })
  for _, b in new do
    table.insert(queue, { kind = "badge", id = b.id, title = "A bard sings of your deeds",
      text = `{b.name}: {b.text} +{b.reward} crowns.`, glyph = b.glyph, reward = b.reward })
  end
  if #new > 0 then
    save()
    publishBestiary()
  end
end

hooks.focusDone = function()
  E.record(saved, "focus", { today = today(), hour = (os.date("*t") :: any).hour })
  grantBadges()
  checkProgress()
end
hooks.build = function()
  dailyCounts().builds += 1
  E.record(saved, "build", {})
  grantBadges()
  checkProgress()
end
hooks.test = function()
  dailyCounts().tests += 1
  checkProgress()
end
hooks.school = function(name)
  E.record(saved, "school:" .. name, {})
  grantBadges()
end

local nextEncounterAt = 0
local function planEncounter(now: number)
  local meanMs = (ENC_TO - ENC_FROM) * 3600000 / math.max(1, ENC_PER_DAY)
  nextEncounterAt = now + (0.5 + math.random()) * meanMs
end

local function encounterTick(now: number)
  if current or now < quietUntil or focus.phase == "focus" or idleNow or lockedNow then
    return
  end
  if #queue > 0 then
    showEncounter(table.remove(queue, 1))
    return
  end
  if ENC.enabled == false or saved.encPaused then
    return
  end
  if nextEncounterAt == 0 then
    planEncounter(now)
    return
  end
  if now < nextEncounterAt then
    return
  end
  planEncounter(now)
  local h = (os.date("*t") :: any).hour
  if h < ENC_FROM or h >= ENC_TO or E.remainingToday(saved, today(), ENC_PER_DAY) <= 0 then
    return
  end
  E.countEncounter(saved, today())
  save()
  showEncounter(E.roll(saved, today(), math.random))
end

local function answerEncounter(choice: string)
  local enc = current
  if not enc then
    return
  end
  current = nil
  if choice == "accept" then
    if enc.kind == "merchant" then
      contractsReviewDone = countReviewDone() -- baseline for the contract challenge
    end
    E.accept(saved, enc, today(), metrics())
    if enc.kind == "monster" then
      noctalia.notify("Contract taken", "Mark it slain in the bestiary (Super+Shift+A) when it's done.")
    elseif enc.kind == "merchant" then
      noctalia.notify("Deal", "Today's challenge is in the bestiary (Super+Shift+A).")
      refreshCounters()
    end
  else
    E.dismiss(saved, enc, today())
  end
  save()
  publishBestiary()
end

local function slay(index: number)
  local m = E.slay(saved, index, today())
  if m then
    play("done")
    noctalia.notify(`{m.name} slain`, `+{m.reward} crowns. Purse: {saved.crowns}.`)
    publish("reward", `{m.name} slain`)
    grantBadges()
    save()
    publishBestiary()
  end
end

local function setEncounters(on: boolean)
  saved.encPaused = not on
  save()
  publishBestiary()
  noctalia.notify(if on then "Encounters resumed" else "Encounters paused",
    if on then `Up to {ENC_PER_DAY} a day, between {ENC_FROM}:00 and {ENC_TO}:00.` else "`encounters on` brings them back.")
end

-- ── Events from the shell, hooks and UI ─────────────────────────────────────
local lockedAt: number? = nil

local function handle(kind: string, text: string)
  if kind == "idle" then
    idleNow = true
  elseif kind == "active" then
    idleNow = false
  elseif kind == "locked" then
    lockedNow = true
  elseif kind == "unlocked" then
    lockedNow = false
  elseif kind == "test-ok" then
    hooks.test()
  end
  if kind == "agent" then
    play("hum")
    noctalia.notify("The medallion hums", if text ~= "" then text else "A Claude agent needs you.")
  elseif kind == "build-ok" then
    hooks.build()
    play("done")
    noctalia.notify(`{if text ~= "" then text else "Potion"} brewed`, "The system was rebuilt successfully.")
  elseif kind == "build-fail" then
    play("fail")
    noctalia.notifyError("The potion spoiled", "Rebuild failed. Check the terminal for the error.")
  elseif kind == "hum" then
    play("hum")
  elseif kind == "locked" then
    lockedAt = os.time()
    return
  elseif kind == "unlocked" then
    play("blade")
    if lockedAt then
      local mins = math.floor((os.time() - lockedAt) / 60)
      if mins >= 1 then
        local away = if mins >= 60 then `{mins // 60} h {mins % 60} min` else `{mins} min`
        noctalia.notify("Welcome back to Kaer Morhen", `You meditated for {away}.`)
      end
    end
    lockedAt = nil
    maybeBrief()
    kind = "active"
  elseif kind == "school" then
    if text == "" then
      stepSchool(1)
    else
      setSchool(string.lower(text), true)
    end
    return
  elseif kind == "focus" then
    toggleFocus()
    return
  elseif kind == "ranger" then
    if text == "on" then
      setRanger(true)
    elseif text == "off" then
      setRanger(false)
    else
      setRanger(not ranger)
    end
    return
  elseif kind == "brief" then
    openBrief()
    return
  elseif kind == "wallpaper" then
    hooks.wallpaper(text)
    return
  elseif kind == "bestiary" then
    publishBestiary()
    noctalia.togglePanel("konstanty/kaer-morhen:bestiary")
    return
  elseif kind == "encounters" then
    if text == "on" or text == "off" then
      setEncounters(text == "on")
    elseif text == "now" then
      if not current then
        showEncounter(E.roll(saved, today(), math.random))
      end
    else
      setEncounters(saved.encPaused == true)
    end
    return
  elseif not ({ ["agent-done"] = true, ["test-ok"] = true, ["test-fail"] = true, idle = true,
    active = true, brewing = true, notify = true, howl = true })[kind] then
    noctalia.log(`kaer-morhen: unknown event {kind}`)
    return
  end
  publish(kind, text)
end

function onIpc(event, payload)
  handle(tostring(event or ""), tostring(payload or ""))
end

local lastCmd = -1
noctalia.state.watch("km.cmd", function(c)
  if type(c) ~= "table" or c.seq == lastCmd then
    return
  end
  lastCmd = c.seq
  if c.op == "focus" then
    toggleFocus()
  elseif c.op == "ranger" then
    setRanger(not ranger)
  elseif c.op == "school-next" then
    stepSchool(1)
  elseif c.op == "school-prev" then
    stepSchool(-1)
  elseif c.op == "wallpaper-next" then
    hooks.wallpaper("next")
  elseif c.op == "encounter-accept" then
    answerEncounter("accept")
  elseif c.op == "encounter-dismiss" or c.op == "encounter-closed" then
    answerEncounter("dismiss")
  elseif c.op == "slay" then
    slay(tonumber(c.arg) or 0)
  elseif c.op == "encounters-toggle" then
    setEncounters(saved.encPaused == true)
  end
end)

-- ── Notifications from any app ──────────────────────────────────────────────
local lastNotify = 0
if cfg.dbusMonitor then
  noctalia.runStream(
    cfg.dbusMonitor .. " --session \"type='method_call',interface='org.freedesktop.Notifications',member='Notify'\"",
    function(line)
      if string.find(line, "member=Notify", 1, true) then
        local now = noctalia.nowMs()
        if now - lastNotify > 1500 then
          lastNotify = now
          publish("notify", "")
        end
      end
    end
  )
end

-- ── Wallpapers, tinted by day / night ───────────────────────────────────────
-- cfg.wallpapers: id -> { title, dawn, day, dusk, night }; cfg.wallpaperOrder: ids in order.
-- (An older config with a single { dawn, day, dusk, night } set still works.)
local WALLS = cfg.wallpapers or {}
if type(WALLS.day) == "string" then
  WALLS = { default = WALLS }
end
local WALL_ORDER = cfg.wallpaperOrder or {}
if #WALL_ORDER == 0 then
  for id in WALLS do
    table.insert(WALL_ORDER, id)
  end
  table.sort(WALL_ORDER)
end
local currentPeriod = ""
local shownWall = ""

local function wallId(): string
  local id = saved.wallpaper
  if id and WALLS[id] then
    return id
  end
  return WALL_ORDER[1] or ""
end

local function showWallpaper()
  local set = WALLS[wallId()]
  if not set then
    return
  end
  local p = if currentPeriod ~= "" then currentPeriod else "day"
  local path = set[p] or set.day
  if path and path ~= shownWall and noctalia.fileExists(path) then
    shownWall = path
    noctalia.setWallpaper(path)
  end
end

local function applyPeriod()
  if not cfg.daynight or not cfg.latitude or not cfg.longitude then
    showWallpaper()
    return
  end
  local p = sun.period(cfg.latitude, cfg.longitude)
  if p ~= currentPeriod then
    currentPeriod = p
    noctalia.state.set("km.period", p)
  end
  showWallpaper()
end

local function setWallpaper(choice: string)
  local id = choice
  if choice == "" or choice == "next" or choice == "prev" then
    local at = table.find(WALL_ORDER, wallId()) or 1
    local n = #WALL_ORDER
    if n == 0 then
      return
    end
    at = if choice == "prev" then ((at - 2) % n) + 1 else (at % n) + 1
    id = WALL_ORDER[at]
  end
  if not WALLS[id] then
    noctalia.notifyError("Unknown wallpaper", `"{choice}". Try: {table.concat(WALL_ORDER, ", ")}.`)
    return
  end
  saved.wallpaper = id
  save()
  showWallpaper()
  noctalia.state.set("km.wallpaper", id)
  noctalia.notify(WALLS[id].title or id, `Wallpaper {table.find(WALL_ORDER, id) or 1} of {#WALL_ORDER}.`)
end
hooks.wallpaper = setWallpaper

-- ── Midnight howl ────────────────────────────────────────────────────────────
local howledOn = ""
local function checkMidnight()
  local d = os.date("*t") :: any
  if d.hour == 0 and d.min == 0 and howledOn ~= today() then
    howledOn = today()
    publish("howl", "")
  end
end

-- ── Tick ─────────────────────────────────────────────────────────────────────
local ticks = 0
local lastCounters = 0
function update()
  ticks += 1
  local now = noctalia.nowMs()
  if focus.phase == "focus" and now >= focus.endsAt then
    finishFocus()
  elseif focus.phase == "break" and now >= focus.endsAt then
    finishBreak()
  end
  -- second ticks while the timer runs, otherwise every 20 s
  noctalia.setUpdateInterval(if focus.phase ~= "idle" then 1000 else 20000)
  if briefPending and ticks >= 2 then
    briefPending = false
    openBrief()
  end
  if ticks % 20 == 1 or focus.phase == "idle" then
    applyPeriod()
    checkMidnight()
    checkHealth()
  end
  encounterTick(now)
  local _, _, ch = E.challengeProgress(saved, today(), metrics())
  if ch and not saved.challenge.done and (ch.metric == "commitsToday" or ch.metric == "contractsToday")
    and now - lastCounters > 600000 then
    lastCounters = now
    refreshCounters()
  end
end

-- start-up
noctalia.state.set("km.school", saved.school)
noctalia.state.set("km.ranger", false)
publishFocus()
applyPeriod()
checkHealth()
maybeBrief()
publishBestiary()
