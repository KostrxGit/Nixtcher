--!nonstrict
-- The bestiary (Super+Shift+A or `bestiary`): your purse, today's merchant challenge,
-- monster contracts you've taken, badges and everything you've met on the road.

local cfg = require("./lib/config.luau")
local E = require("./lib/encounters.luau")

local WIDTH = 500

local function section(title: string, glyph: string, children)
  local rows = { ui.row({ gap = 8, align = "center" }, {
    ui.glyph({ name = glyph, size = 16, color = "primary" }),
    ui.label({ text = title, fontSize = 13, fontWeight = "bold", color = "on_surface_variant" }),
  }) }
  for _, c in children do
    table.insert(rows, c)
  end
  return ui.column({ gap = 6 }, rows)
end

local function line(text: string, color: string?)
  return ui.label({ text = text, fontSize = 13, color = color or "on_surface", maxWidth = WIDTH - 50, maxLines = 3 })
end

local function cmd(op: string, arg)
  noctalia.state.set("km.cmd", { op = op, arg = arg, seq = noctalia.nowMs() })
end

local function render()
  local b = noctalia.state.get("km.bestiary") or {}
  local body = {}

  table.insert(body, ui.row({ gap = 10, align = "center" }, {
    ui.glyph({ name = "book", size = 24, color = "primary" }),
    ui.label({ text = "Bestiary", fontSize = 22, fontWeight = "bold", fontFamily = cfg.titleFont or "" }),
    ui.spacer({ flexGrow = 1 }),
    ui.glyph({ name = "coin", size = 18, color = "primary" }),
    ui.label({ text = `{b.crowns or 0} crowns`, fontSize = 14, fontWeight = "semibold" }),
  }))

  -- today's challenge
  local ch = {}
  if b.challenge then
    local c = b.challenge
    table.insert(ch, line(`{c.title}: {c.text}`))
    table.insert(ch, ui.row({ gap = 10, align = "center" }, {
      ui.progress({ width = WIDTH - 140, height = 8, progress = c.progress / math.max(1, c.goal), radius = 4 }),
      ui.label({ text = if c.done then "paid ✔" else `{c.progress} / {c.goal}`, fontSize = 12,
        color = "on_surface_variant" }),
    }))
  else
    table.insert(ch, line("No deal today. The merchant may still turn up.", "on_surface_variant"))
  end
  table.insert(body, section("Merchant's challenge", "coin", ch))

  -- monster contracts
  local hunts = {}
  for i, h in b.hunts or {} do
    local m = E.find(E.MONSTERS, h.id)
    if m then
      table.insert(hunts, ui.row({ gap = 10, align = "center" }, {
        ui.column({ gap = 1, flexGrow = 1 }, {
          ui.label({ text = `{m.name} · {m.reward} crowns`, fontSize = 13, fontWeight = "semibold" }),
          ui.label({ text = m.task, fontSize = 12, color = "on_surface_variant", maxWidth = WIDTH - 160, maxLines = 2 }),
        }),
        ui.button({ text = "Slain", glyph = "sword", variant = "primary", onClick = function()
          cmd("slay", i)
        end }),
      }))
    end
  end
  if #hunts == 0 then
    table.insert(hunts, line("No open contracts. Monsters show up on their own.", "on_surface_variant"))
  end
  table.insert(body, section("Contracts", "swords", hunts))

  -- badges
  local badges = {}
  local earned = 0
  for _, badge in E.BADGES do
    local date = (b.badges or {})[badge.id]
    if date then
      earned += 1
    end
    table.insert(badges, ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = if date then badge.glyph else "lock", size = 15,
        color = if date then "primary" else "on_surface_variant" }),
      ui.label({ text = if date then `{badge.name}: {badge.text}` else "???", fontSize = 12,
        color = if date then "on_surface" else "on_surface_variant", maxWidth = WIDTH - 80 }),
    }))
  end
  table.insert(body, section(`Badges · {earned} of {#E.BADGES}`, "award", badges))

  -- discoveries
  local seen = b.bestiary or {}
  local found = {}
  local met = 0
  for _, m in E.MONSTERS do
    local s = seen["monster:" .. m.id]
    local k = seen["slain:" .. m.id]
    if s then
      met += 1
      table.insert(found, line(`{m.name}: met {s.count}×` .. (if k then `, slain {k.count}×` else "")))
    end
  end
  local tr = seen.traveller
  local mer = seen.merchant
  table.insert(found, 1, line(`Monsters discovered: {met} of {#E.MONSTERS}`, "on_surface_variant"))
  if mer then
    table.insert(found, line(`Merchant deals: {mer.count}`))
  end
  if tr then
    table.insert(found, line(`Travellers met: {tr.count}`))
  end
  table.insert(body, section("Discovered", "skull", found))

  table.insert(body, ui.row({ gap = 8, align = "center" }, {
    ui.label({ text = if b.paused then "Encounters paused" else `Up to {b.perDay or 5} encounters a day`,
      fontSize = 12, color = "on_surface_variant", flexGrow = 1 }),
    ui.button({ text = if b.paused then "Resume" else "Pause", variant = "ghost", onClick = function()
      cmd("encounters-toggle")
    end }),
    ui.button({ text = "Close", variant = "ghost", onClick = function()
      panel.close()
    end }),
  }))

  panel.render(ui.scroll({ width = WIDTH, gap = 16, padding = 22 }, body))
end

function onOpen(_context)
  render()
end

noctalia.state.watch("km.bestiary", function()
  render()
end)
