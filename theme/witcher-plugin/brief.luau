--!nonstrict
-- Morning brief: opens on the first login or unlock of the day, or with Super+Shift+B.
-- Weather (Open-Meteo), your contracts, repos with uncommitted or unpushed work, battery
-- health and yesterday's focus. Your calendar is one click away in the control centre.

local cfg = require("./lib/config.luau")
local contractsLib = require("./lib/contracts.luau")

local WIDTH = 520
local NAME = cfg.userName or ""
local PET = cfg.petName or "Vesna"

local weather = nil      -- { temp, code, max, min, rain, wind } or false when it failed
local repos = {}         -- name -> { branch, changed, ahead, behind }
local pending = 0
local contracts = {}

local WMO = {
  [0] = { "sun", "clear sky" }, [1] = { "sun", "mostly clear" }, [2] = { "cloud", "partly cloudy" },
  [3] = { "cloud", "overcast" }, [45] = { "cloud-fog", "fog" }, [48] = { "cloud-fog", "freezing fog" },
  [51] = { "cloud-rain", "light drizzle" }, [53] = { "cloud-rain", "drizzle" }, [55] = { "cloud-rain", "heavy drizzle" },
  [61] = { "cloud-rain", "light rain" }, [63] = { "cloud-rain", "rain" }, [65] = { "cloud-rain", "heavy rain" },
  [66] = { "cloud-rain", "freezing rain" }, [67] = { "cloud-rain", "freezing rain" },
  [71] = { "snowflake", "light snow" }, [73] = { "snowflake", "snow" }, [75] = { "snowflake", "heavy snow" },
  [77] = { "snowflake", "snow grains" }, [80] = { "cloud-rain", "rain showers" }, [81] = { "cloud-rain", "rain showers" },
  [82] = { "cloud-storm", "violent showers" }, [85] = { "cloud-snow", "snow showers" }, [86] = { "cloud-snow", "snow showers" },
  [95] = { "cloud-storm", "thunderstorm" }, [96] = { "cloud-storm", "thunderstorm, hail" }, [99] = { "cloud-storm", "thunderstorm, hail" },
}

local function greeting(): string
  local h = (os.date("*t") :: any).hour
  local part = if h < 5 then "Long night" elseif h < 12 then "Good morning" elseif h < 18 then "Good afternoon" else "Good evening"
  return if NAME ~= "" then `{part}, {NAME}` else part
end

local function section(title: string, glyph: string, children)
  local rows = { ui.row({ gap = 8, align = "center" }, {
    ui.glyph({ name = glyph, size = 16, color = "primary" }),
    ui.label({ text = title, fontSize = 13, fontWeight = "bold", color = "on_surface_variant" }),
  }) }
  for _, c in children do
    table.insert(rows, c)
  end
  return ui.column({ gap = 4 }, rows)
end

local function line(text: string, color: string?)
  return ui.label({ text = text, fontSize = 13, color = color or "on_surface", maxWidth = WIDTH - 40, maxLines = 2 })
end

local function render()
  local body = {}

  -- header
  table.insert(body, ui.column({ gap = 2 }, {
    ui.label({ text = greeting(), fontSize = 22, fontWeight = "bold", fontFamily = cfg.titleFont or "" }),
    ui.label({ text = os.date("%A, %d %B") :: string, fontSize = 13, color = "on_surface_variant" }),
  }))

  -- weather
  local w = {}
  if weather == nil then
    table.insert(w, line("Reading the sky…", "on_surface_variant"))
  elseif weather == false then
    table.insert(w, line("The weather could not be fetched.", "on_surface_variant"))
  else
    local info = WMO[weather.code] or { "cloud", "unsettled" }
    table.insert(w, ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = info[1], size = 28, color = "primary" }),
      ui.column({ gap = 1 }, {
        ui.label({ text = `{math.floor(weather.temp + 0.5)}°  {info[2]}`, fontSize = 16, fontWeight = "semibold" }),
        ui.label({
          text = `↑ {math.floor(weather.max + 0.5)}°  ↓ {math.floor(weather.min + 0.5)}°  ·  rain {weather.rain or 0}%  ·  wind {math.floor(weather.wind + 0.5)} km/h`,
          fontSize = 12, color = "on_surface_variant",
        }),
      }),
    }))
  end
  table.insert(body, section(cfg.city or "Weather", "sunrise", w))

  -- contracts
  local counts = { changes = 0, working = 0, review = 0, todo = 0 }
  for _, c in contracts do
    if counts[c.key] then
      counts[c.key] += 1
    end
  end
  local open = counts.changes + counts.working + counts.review + counts.todo
  local cl = {}
  if open == 0 then
    table.insert(cl, line("The notice board is empty.", "on_surface_variant"))
  else
    local parts = {}
    for _, k in { "changes", "working", "review", "todo" } do
      if counts[k] > 0 then
        table.insert(parts, `{counts[k]} {string.lower(contractsLib.STATUS[k].label)}`)
      end
    end
    table.insert(cl, line(table.concat(parts, "  ·  ")))
    local shown = 0
    for _, c in contracts do
      if c.key ~= "done" and shown < 3 then
        shown += 1
        table.insert(cl, line(`  {c.repo} {c.num}  {c.title}`, "on_surface_variant"))
      end
    end
  end
  table.insert(body, section("Contracts", "swords", cl))

  -- repos
  local rl = {}
  if pending > 0 then
    table.insert(rl, line("Checking repos…", "on_surface_variant"))
  else
    local names = {}
    local extra = 0
    for name in repos do
      table.insert(names, name)
    end
    table.sort(names)
    for _, name in names do
      local r = repos[name]
      local bits = {}
      if r.changed > 0 then
        table.insert(bits, `{r.changed} uncommitted`)
      end
      if r.ahead > 0 then
        table.insert(bits, `{r.ahead} to push`)
      end
      if r.behind > 0 then
        table.insert(bits, `{r.behind} to pull`)
      end
      if #bits > 0 then
        if #rl < 5 then
          table.insert(rl, line(`{name}  ({r.branch})  ·  {table.concat(bits, ", ")}`))
        else
          extra += 1
        end
      end
    end
    if extra > 0 then
      table.insert(rl, line(`+{extra} more`, "on_surface_variant"))
    end
    if #rl == 0 then
      table.insert(rl, line("Every repo is clean and pushed.", "on_surface_variant"))
    end
  end
  table.insert(body, section("Repos", "git-branch", rl))

  -- camp: battery health and focus
  local camp = {}
  local health = noctalia.state.get("km.health")
  if health then
    table.insert(camp, line(`Battery health {health}%` .. (if health < 80 then " (fading)" else ""),
      if health < 80 then "error" else "on_surface"))
  end
  local f = noctalia.state.get("km.focus")
  local rounds = if type(f) == "table" then f.todayRounds or 0 else 0
  table.insert(camp, line(if rounds > 0 then `{rounds} focus sessions so far today` else `{PET} is ready to meditate with you`))
  table.insert(body, section("Camp", "flame", camp))

  table.insert(body, ui.row({ gap = 8, justify = "end" }, {
    ui.button({ text = "Start focus", glyph = "hourglass", variant = "primary", onClick = function()
      noctalia.state.set("km.cmd", { op = "focus", seq = noctalia.nowMs() })
      panel.close()
    end }),
    ui.button({ text = "Close", variant = "ghost", onClick = function()
      panel.close()
    end }),
  }))

  panel.render(ui.column({ width = WIDTH, gap = 14, padding = 22 }, body))
end

local function fetchWeather()
  if not cfg.latitude or not cfg.longitude then
    weather = false
    return
  end
  local url = "https://api.open-meteo.com/v1/forecast?latitude=" .. cfg.latitude .. "&longitude=" .. cfg.longitude
    .. "&current=temperature_2m,weather_code,wind_speed_10m"
    .. "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=auto&forecast_days=1"
  noctalia.http({ url = url }, function(res)
    local data = if res.ok and res.status == 200 then noctalia.json.decode(res.body) else nil
    if type(data) == "table" and data.current and data.daily then
      weather = {
        temp = data.current.temperature_2m or 0, code = data.current.weather_code or 3,
        wind = data.current.wind_speed_10m or 0,
        max = (data.daily.temperature_2m_max or {})[1] or 0, min = (data.daily.temperature_2m_min or {})[1] or 0,
        rain = (data.daily.precipitation_probability_max or {})[1],
      }
    else
      weather = false
    end
    render()
  end)
end

local function parseStatus(out: string)
  local branch, ahead, behind, changed = "?", 0, 0, 0
  for l in string.gmatch(out, "[^\n]+") do
    if string.sub(l, 1, 3) == "## " then
      branch = string.match(l, "^## ([^%.%s]+)") or branch
      ahead = tonumber(string.match(l, "ahead (%d+)") or "0") or 0
      behind = tonumber(string.match(l, "behind (%d+)") or "0") or 0
    else
      changed += 1
    end
  end
  return { branch = branch, changed = changed, ahead = ahead, behind = behind }
end

local function checkRepos()
  repos = {}
  pending = 0
  if not cfg.git then
    return
  end
  for _, r in contractsLib.repos(cfg.codeDirs) do
    if contractsLib.isDir(r.path .. "/.git") or noctalia.fileExists(r.path .. "/.git") then
      pending += 1
      noctalia.runAsync({ cfg.git, "-C", r.path, "status", "--porcelain=v1", "--branch" }, function(res)
        pending -= 1
        if res.exitCode == 0 then
          repos[r.name] = parseStatus(res.stdout)
        end
        if pending == 0 then
          render()
        end
      end)
    end
  end
end

function onOpen(_context)
  weather = nil
  contracts = contractsLib.scan(cfg.codeDirs)
  checkRepos()
  fetchWeather()
  render()
end
