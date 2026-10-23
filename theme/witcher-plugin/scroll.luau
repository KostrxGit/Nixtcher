--!nonstrict
-- "Contract complete": a parchment scroll that unrolls when a focus session ends.
-- Opened by the events service; closes itself after a few seconds or on click.

local cfg = require("./lib/config.luau")

local SHOW_SECONDS = 9
local opened = 0

local INK = "#4A3520"
local FADED = "#7A5C3A"

local function render()
  local s = noctalia.state.get("km.scroll") or {}
  local pet = s.pet or "Vesna"
  local rounds = s.todayRounds or 1
  local minutes = (s.minutes or 25) * rounds
  local total = if minutes >= 60 then `{minutes // 60} h {minutes % 60} min` else `{minutes} min`
  panel.render(ui.column({ align = "center", gap = 0, onClick = "dismiss" }, {
    ui.image({ path = "assets/scroll/roll.png", width = 420, height = 26 }),
    ui.column({ width = 380, gap = 8, padding = 20, fill = "#EADBB8", align = "center" }, {
      ui.label({ text = "CONTRACT COMPLETE", fontSize = 20, fontWeight = "bold", color = INK,
        fontFamily = cfg.titleFont or "" }),
      ui.separator({ thickness = 1, color = FADED }),
      ui.label({ text = `Focus session {s.round or 1} · {s.minutes or 25} minutes`, fontSize = 14, color = INK }),
      ui.label({ text = `{pet} kept watch. Rest for {s.rest or 5} minutes.`, fontSize = 13, color = FADED,
        textAlign = "center", maxWidth = 340 }),
      ui.label({ text = `Today: {rounds} {if rounds == 1 then "contract" else "contracts"} · {total}`, fontSize = 12,
        fontWeight = "semibold", color = INK }),
    }),
    ui.image({ path = "assets/scroll/roll.png", width = 420, height = 26 }),
  }))
end

function dismiss()
  panel.close()
end

function onOpen(_context)
  opened = 0
  panel.setWantsSecondTicks(true)
  render()
end

function update()
  opened += 1
  if opened >= SHOW_SECONDS then
    panel.close()
  end
end
