--!nonstrict
-- An encounter card in the top-right corner: a merchant's challenge, a monster contract,
-- a traveller's saying or a badge. Opened by the events service; Accept / Dismiss answer it,
-- closing it any other way counts as Dismiss. Nothing happens until you answer.

local cfg = require("./lib/config.luau")

local WIDTH = 360
local answered = false

local function send(op: string)
  answered = true
  noctalia.state.set("km.cmd", { op = op, seq = noctalia.nowMs() })
  panel.close()
end

local function render()
  local e = noctalia.state.get("km.encounter")
  if type(e) ~= "table" then
    panel.render(ui.column({ width = WIDTH, padding = 18 }, {
      ui.label({ text = "The road is quiet.", fontSize = 13, color = "on_surface_variant" }),
    }))
    return
  end
  local buttons = {}
  if e.accept then
    table.insert(buttons, ui.button({ text = e.accept, variant = "primary", onClick = function()
      send("encounter-accept")
    end }))
    table.insert(buttons, ui.button({ text = "Not now", variant = "ghost", onClick = function()
      send("encounter-dismiss")
    end }))
  else
    table.insert(buttons, ui.button({ text = if e.kind == "badge" then "Splendid" else "Thanks", variant = "primary",
      onClick = function()
        send("encounter-dismiss")
      end }))
  end
  panel.render(ui.column({ width = WIDTH, gap = 10, padding = 18 }, {
    ui.row({ gap = 10, align = "center" }, {
      ui.glyph({ name = e.glyph or "route", size = 22, color = "primary" }),
      ui.label({ text = e.title or "", fontSize = 15, fontWeight = "bold", fontFamily = cfg.titleFont or "",
        maxWidth = WIDTH - 70 }),
    }),
    ui.label({ text = e.text or "", fontSize = 13, color = "on_surface", maxWidth = WIDTH - 36, maxLines = 5 }),
    ui.row({ gap = 8, justify = "end" }, buttons),
  }))
end

function onOpen(_context)
  answered = false
  render()
end

function onClose()
  if not answered then
    noctalia.state.set("km.cmd", { op = "encounter-closed", seq = noctalia.nowMs() })
  end
end

noctalia.state.watch("km.encounter", function()
  render()
end)
