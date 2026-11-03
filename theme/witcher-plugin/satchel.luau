--!nonstrict
-- The witcher's satchel: Kaer Morhen commands in the launcher.
-- Type /witcher to list them all, or just start typing ("focus", "bestiary", "griffin",
-- "novigrad") and they show up next to your apps.

local cfg = require("./lib/config.luau")

local BIN = cfg.bin or ""
local SCHOOLS = {
  { id = "wolf", name = "Wolf", text = "Frost blue. The classic." },
  { id = "cat", name = "Cat", text = "Amber and gold. Quick and sly." },
  { id = "griffin", name = "Griffin", text = "Teal. Scholars and signs." },
  { id = "bear", name = "Bear", text = "Copper. Heavy armour, warm hearth." },
}

-- id, title, subtitle, glyph, category, extra search words
local ITEMS = {
  { "focus", "Meditate", "Start or stop a 25-minute focus session with Vesna", "hourglass", "Keep", "focus pomodoro timer" },
  { "brief", "Morning brief", "Weather, contracts, repos, battery health", "sunrise", "Keep", "today weather" },
  { "ledger", "Ledger", "Your issues, their cards and how far they are", "notebook", "Keep", "tasks cards progress issues linear" },
  { "bestiary", "Bestiary", "Crowns, today's challenge, contracts and badges", "book", "Keep", "badges crowns" },
  { "encounter", "Seek an encounter", "Summon a merchant, monster or traveller now", "swords", "Keep", "encounters" },
  { "encounters", "Pause or resume encounters", "Toggle the encounter cards", "bell-off", "Keep", "encounters quiet" },
  { "ranger", "Ranger mode", "Power saver, dimmer screen, a calmer pup", "leaf", "Keep", "battery power saver" },
  { "sigurd", "Call Sigurd", "The pony trots over with a joke or a tip", "horse", "Keep", "pony horse" },
  { "wall-next", "Next wallpaper", "Cycle to the next picture", "photo", "Wallpapers", "wallpaper background" },
  { "codex", "The Witcher's Codex", "How to work with the Claude agents", "book-2", "Lore", "guide agents claude help" },
  { "cheatsheet", "Cheatsheet", "Every keybind and command on one page", "keyboard", "Lore", "keys shortcuts help" },
  { "lock", "Rest by the fire", "Lock the screen", "flame", "Keep", "lock" },
}
for _, s in SCHOOLS do
  table.insert(ITEMS, { "school-" .. s.id, `School of the {s.name}`, s.text, "shield", "Schools", "school medallion theme " .. s.id })
end
for i, id in cfg.wallpaperOrder or {} do
  local w = (cfg.wallpapers or {})[id] or {}
  table.insert(ITEMS, { "wall-" .. id, w.title or id, `Wallpaper {i}`, "photo", "Wallpapers", "wallpaper background " .. id })
end

local function ipc(kind: string, arg: string?)
  noctalia.state.set("km.cmd", { op = "ipc", kind = kind, arg = arg or "", seq = noctalia.nowMs() })
end

local function terminal(class: string, title: string, cmd: string)
  noctalia.runAsync({ BIN .. "/ghostty", "--class=" .. class, "--title=" .. title, "-e", BIN .. "/" .. cmd })
end

function onQuery(query)
  local text = noctalia.string.trim(query or ""):lower()
  local words = {}
  for w in text:gmatch("%S+") do
    table.insert(words, w)
  end
  local rows = {}
  for _, it in ITEMS do
    local hay = (it[2] .. " " .. it[3] .. " " .. it[6]):lower()
    local ok = true
    for _, w in words do
      if not hay:find(w, 1, true) then
        ok = false
        break
      end
    end
    if ok then
      local starts = #words > 0 and it[2]:lower():sub(1, #words[1]) == words[1]
      table.insert(rows, { id = it[1], title = it[2], subtitle = it[3], glyph = it[4], category = it[5],
        score = if starts then 0.9 else 0.5 })
    end
  end
  launcher.setResults(query, rows)
end

function onActivate(id)
  if id == "focus" or id == "brief" or id == "bestiary" or id == "ranger" then
    ipc(id)
  elseif id == "ledger" then
    noctalia.togglePanel("konstanty/kaer-morhen:ledger-book")
  elseif id == "encounter" then
    ipc("encounters", "now")
  elseif id == "encounters" then
    ipc("encounters", "")
  elseif id == "sigurd" then
    if cfg.sigurd then
      noctalia.runAsync({ cfg.sigurd, "visit" })
    end
  elseif id == "codex" then
    terminal("dev.codex", "Codex", "guide")
  elseif id == "cheatsheet" then
    terminal("dev.cheatsheet", "Cheatsheet", "cheatsheet")
  elseif id == "lock" then
    noctalia.runAsync({ cfg.noctalia, "msg", "session", "lock" })
  elseif id:sub(1, 7) == "school-" then
    ipc("school", id:sub(8))
  elseif id == "wall-next" then
    ipc("wallpaper", "next")
  elseif id:sub(1, 5) == "wall-" then
    ipc("wallpaper", id:sub(6))
  end
end
