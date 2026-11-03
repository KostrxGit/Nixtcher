--!nonstrict
-- The ledger (Super+Shift+L, or "ledger" in the launcher): your Linear issues and how far
-- each one is. One entry per issue, across all projects it touches: its title, a progress
-- bar of finished cards and what is waiting. Click an issue to see its open cards.
-- Older cards without an issue are listed per project at the bottom.
-- Done and approved cards only count toward the progress.

local cfg = require("./lib/config.luau")
local lib = require("./lib/contracts.luau")

local WIDTH = 680          -- content width inside the panel
local BLOCK = WIDTH - 32   -- inside an entry
local ID_W, BAR_W, COUNT_W, STATUS_W = 64, 72, 34, 82
local TITLE_W = BLOCK - 16 - ID_W - BAR_W - COUNT_W - STATUS_W - 5 * 10
local DONE_SHOWN = 5
local WAITING = { -- in this order, as "1 to fix · 2 in review …"
  { "changes", "to fix" }, { "review", "in review" }, { "working", "in progress" }, { "todo", "to do" },
}

local isOpen = false
local render -- defined below; entries re-render on click
local expanded = {} -- entry key → true while its cards are shown

local function ago(mtime: number): string
  if not mtime or mtime <= 0 then
    return ""
  end
  local secs = if mtime > 1e11 then mtime / 1000 else mtime -- seconds or milliseconds
  local d = os.time() - secs
  if d < 3600 then
    return "just now"
  elseif d < 86400 then
    return `{math.floor(d / 3600)} h ago`
  elseif d < 2 * 86400 then
    return "yesterday"
  end
  return `{math.floor(d / 86400)} days ago`
end

local function bar(width: number, height: number, value: number)
  return ui.progress({ width = width, height = height, radius = height / 2, progress = math.clamp(value, 0, 1),
    fill = "primary", track = "outline" })
end

local function cardRow(c, showRepo: boolean)
  local s = lib.STATUS[c.key]
  local id = if c.issue then c.no else c.num
  return ui.row({ gap = 10, align = "center", paddingV = 2 }, {
    ui.glyph({ name = s.glyph, size = 15, color = s.color }),
    ui.label({ text = if showRepo then `{c.repo} {id}` else id, width = ID_W, maxWidth = ID_W, maxLines = 1,
      fontSize = 12, fontWeight = "bold", color = "on_surface_variant" }),
    ui.label({ text = c.title, width = TITLE_W, maxWidth = TITLE_W, fontSize = 13, maxLines = 1 }),
    if c.checksTotal > 0 then bar(BAR_W, 5, c.checksDone / c.checksTotal) else ui.spacer({ width = BAR_W }),
    ui.label({ text = if c.checksTotal > 0 then `{c.checksDone}/{c.checksTotal}` else "", width = COUNT_W,
      fontSize = 11, color = "on_surface_variant" }),
    ui.label({ text = s.label, width = STATUS_W, fontSize = 12, fontWeight = "semibold", color = s.color,
      textAlign = "end" }),
  })
end

-- "1 to fix · 2 in review" as small coloured glyph + text pairs
local function waiting(g)
  local items = {}
  for _, w in WAITING do
    local n = g.counts[w[1]]
    if n > 0 then
      local s = lib.STATUS[w[1]]
      table.insert(items, ui.glyph({ name = s.glyph, size = 13, color = s.color }))
      table.insert(items, ui.label({ text = `{n} {w[2]}`, fontSize = 12, color = s.color }))
    end
  end
  return items
end

local function entry(g)
  local open = expanded[g.key] == true
  local heading = {
    ui.glyph({ name = if open then "chevron-down" else "chevron-right", size = 16, color = "on_surface_variant" }),
  }
  if g.issue then
    table.insert(heading, ui.label({ text = g.issue, fontSize = 16, fontWeight = "bold", color = "primary" }))
    table.insert(heading, ui.label({ text = g.title or "", fontSize = 15, fontWeight = "semibold", maxLines = 1,
      maxWidth = BLOCK - 260 }))
  else
    table.insert(heading, ui.label({ text = g.repos[1], fontSize = 16, fontWeight = "bold",
      fontFamily = cfg.titleFont or "" }))
  end
  table.insert(heading, ui.spacer({ flexGrow = 1 }))
  table.insert(heading, ui.label({ text = ago(g.mtime), fontSize = 11, color = "on_surface_variant" }))

  local status = waiting(g)
  table.insert(status, ui.spacer({ flexGrow = 1 }))
  if g.issue then
    table.insert(status, ui.glyph({ name = "folder", size = 13, color = "on_surface_variant" }))
    table.insert(status, ui.label({ text = table.concat(g.repos, " · "), fontSize = 12, color = "on_surface_variant",
      maxLines = 1, maxWidth = 240 }))
  end

  local rows = {
    ui.row({ gap = 10, align = "center" }, heading),
    ui.row({ gap = 12, align = "center" }, {
      bar(BLOCK - 150, 10, g.done / math.max(1, g.total)),
      ui.label({ text = `{g.done} of {g.total} {if g.total == 1 then "card" else "cards"} done`, width = 138,
        fontSize = 13, fontWeight = "semibold", textAlign = "end" }),
    }),
    ui.row({ gap = 6, align = "center" }, status),
  }
  if open then
    table.insert(rows, ui.separator({ thickness = 1, color = "outline" }))
    for _, c in g.cards do
      if c.key ~= "done" then
        table.insert(rows, cardRow(c, #g.repos > 1))
      end
    end
  end
  return ui.column({ key = g.key, width = WIDTH, gap = 8, padding = 16, radius = 14, fill = "surface_variant",
    onClick = function()
      expanded[g.key] = not open
      render()
    end }, rows)
end

render = function()
  local groups = lib.issues(lib.current())
  local issues, loose, finished = {}, {}, {}
  local openCards = 0
  for _, g in groups do
    if not g.open then
      table.insert(finished, g)
    else
      openCards += g.total - g.done
      table.insert(if g.issue then issues else loose, g)
    end
  end

  local body = {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = "notebook", size = 22, color = "primary" }),
      ui.label({ text = "Ledger", fontSize = 22, fontWeight = "bold", fontFamily = cfg.titleFont or "" }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({ text = `{#issues} {if #issues == 1 then "issue" else "issues"} open · {openCards} {if openCards == 1 then "card" else "cards"} to go`,
        fontSize = 12, color = "on_surface_variant" }),
    }),
  }
  if #issues == 0 and #loose == 0 then
    table.insert(body, ui.label({ text = "Nothing open. Start with `manager` in a repo.", fontSize = 13,
      color = "on_surface_variant" }))
  end
  for _, g in issues do
    table.insert(body, entry(g))
  end
  if #loose > 0 then
    table.insert(body, ui.label({ text = "Without a Linear issue", fontSize = 13, fontWeight = "bold",
      color = "on_surface_variant" }))
    for _, g in loose do
      table.insert(body, entry(g))
    end
  end

  if #finished > 0 then
    local rows = { ui.label({ text = "Finished", fontSize = 13, fontWeight = "bold", color = "on_surface_variant" }) }
    for i, g in finished do
      if i > DONE_SHOWN then
        break
      end
      local name = if g.issue then `{g.issue}{if g.title then "  " .. g.title else ""}` else g.repos[1]
      table.insert(rows, ui.row({ gap = 8, align = "center" }, {
        ui.glyph({ name = "circle-check", size = 14, color = "secondary" }),
        ui.label({ text = name, fontSize = 12, maxLines = 1, maxWidth = WIDTH - 220 }),
        ui.label({ text = `{g.total} {if g.total == 1 then "card" else "cards"}`, fontSize = 12, color = "on_surface_variant" }),
        ui.spacer({ flexGrow = 1 }),
        ui.label({ text = ago(g.mtime), fontSize = 11, color = "on_surface_variant" }),
      }))
    end
    table.insert(body, ui.column({ gap = 4 }, rows))
  end

  panel.render(ui.scroll({ width = WIDTH + 40, gap = 12, padding = 20 }, body))
end

function onOpen(_context)
  isOpen = true
  render()
  noctalia.state.set("km.cmd", { op = "cards-refresh", seq = noctalia.nowMs() }) -- fresh numbers
end

function onClose()
  isOpen = false
end

noctalia.state.watch("km.cards", function()
  if isOpen then
    render()
  end
end)
