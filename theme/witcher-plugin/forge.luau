--!nonstrict
-- The Forge: desktop card with your running Docker containers and their ports.
-- Click a container to follow its logs in a terminal.

local cfg = require("./lib/config.luau")

local WIDTH = 300
local REFRESH_MS = 10000
local containers = {}
local state = "loading"   -- "loading" | "ok" | "down"

local function ports(raw: string): string
  local seen, out = {}, {}
  for host in string.gmatch(raw or "", ":(%d+)%->") do
    if not seen[host] then
      seen[host] = true
      table.insert(out, host)
    end
  end
  return table.concat(out, " · ")
end

local function running(): number
  local n = 0
  for _, c in containers do
    if c.State == "running" then
      n += 1
    end
  end
  return n
end

local function render()
  local rows = {}
  if state == "down" then
    table.insert(rows, ui.label({ text = "Docker is asleep. It starts with your first `docker` command.",
      fontSize = 12, color = "on_surface_variant", maxWidth = WIDTH - 10 }))
  elseif #containers == 0 then
    table.insert(rows, ui.label({ text = if state == "loading" then "Stoking the fire…"
      else "The forge is cold. `pg`, `redis` or `dcu` lights it.", fontSize = 12, color = "on_surface_variant",
      maxWidth = WIDTH - 10 }))
  else
    for i, c in containers do
      if i > 6 then
        break
      end
      local p = ports(c.Ports)
      table.insert(rows, ui.row({ key = c.Names, gap = 10, align = "center", paddingV = 3, onClick = function()
        noctalia.runInTerminal(`{cfg.docker or "docker"} logs -f --tail 100 '{c.Names}'`)
      end }, {
        ui.glyph({ name = if c.State == "running" then "flame" else "circle-dashed", size = 16,
          color = if c.State == "running" then "tertiary" else "on_surface_variant" }),
        ui.column({ gap = 1, flexGrow = 1 }, {
          ui.label({ text = c.Names, fontSize = 13, fontWeight = "semibold", maxLines = 1, maxWidth = WIDTH - 110 }),
          ui.label({ text = `{c.Image}  ·  {c.Status}`, fontSize = 11, color = "on_surface_variant", maxLines = 1,
            maxWidth = WIDTH - 110 }),
        }),
        ui.label({ text = p, fontSize = 12, color = "primary", fontWeight = "semibold" }),
      }))
    end
  end
  desktopWidget.render(ui.column({ width = WIDTH, gap = 6 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "brand-docker", size = 18, color = "primary" }),
      ui.label({ text = "THE FORGE", fontSize = 16, fontWeight = "bold", fontFamily = cfg.titleFont or "" }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({ text = if running() > 0 then `{running()} burning` else "", fontSize = 11,
        color = "on_surface_variant" }),
    }),
    ui.separator({ thickness = 1, color = "outline" }),
    ui.column({ gap = 2 }, rows),
  }))
end

local function refresh()
  -- rootless Docker listens in the user's runtime dir
  local cmd = 'DOCKER_HOST="${DOCKER_HOST:-unix://$XDG_RUNTIME_DIR/docker.sock}" '
    .. (cfg.docker or "docker") .. " ps -a --format '{{json .}}'"
  noctalia.runAsync(cmd, function(res)
    if res.exitCode ~= 0 then
      state = "down"
      containers = {}
    else
      state = "ok"
      containers = {}
      for l in string.gmatch(res.stdout, "[^\n]+") do
        local c = noctalia.json.decode(l)
        if type(c) == "table" and c.Names then
          table.insert(containers, c)
        end
      end
      table.sort(containers, function(a, b)
        if (a.State == "running") ~= (b.State == "running") then
          return a.State == "running"
        end
        return a.Names < b.Names
      end)
    end
    render()
  end)
end

function update()
  noctalia.setUpdateInterval(REFRESH_MS)
  refresh()
end

render()
refresh()
