--!nonstrict
-- Contract board: the Claude task cards (docs/tasks/NNN-*.md) from every repo in your code
-- folders, like notices pinned in a village. An open worktree (.claude/worktrees/task-NNN)
-- means a coding agent has taken the contract. Click a contract to open a terminal in its repo.

local cfg = require("./lib/config.luau")

local WIDTH = 320
local MAX_ROWS = 6
local REFRESH_MS = 30000

local lib = require("./lib/contracts.luau")
local STATUS = lib.STATUS

local contracts = {}

local function scan()
  contracts = lib.scan(cfg.codeDirs)
end

local function openRepo(path: string)
  noctalia.runInTerminal(`cd '{path}' && task list; exec $SHELL`)
end

local function row(c)
  local s = STATUS[c.key]
  return ui.row({ key = c.repo .. c.num, gap = 10, align = "center", paddingV = 4, onClick = function()
    openRepo(c.path)
  end }, {
    ui.glyph({ name = s.glyph, size = 16, color = s.color }),
    ui.column({ gap = 1, flexGrow = 1 }, {
      ui.label({ text = `{c.num}  {c.title}`, fontSize = 13, fontWeight = "semibold", maxLines = 1, maxWidth = WIDTH - 60 }),
      ui.label({ text = `{c.repo}  ·  {s.label}`, fontSize = 11, color = "on_surface_variant", maxLines = 1 }),
    }),
  })
end

local function render()
  local open, done = 0, 0
  for _, c in ipairs(contracts) do
    if c.key == "done" then
      done += 1
    else
      open += 1
    end
  end
  local rows = {}
  for i, c in ipairs(contracts) do
    if i > MAX_ROWS then
      break
    end
    table.insert(rows, row(c))
  end
  if #rows == 0 then
    table.insert(rows, ui.label({
      text = "No contracts posted. Run `manager` in a repo to write one.",
      fontSize = 12, color = "on_surface_variant", maxWidth = WIDTH - 20,
    }))
  end
  desktopWidget.render(ui.column({ width = WIDTH, gap = 6 }, {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = "swords", size = 18, color = "primary" }),
      ui.label({ text = "CONTRACTS", fontSize = 16, fontWeight = "bold", fontFamily = cfg.titleFont or "" }),
      ui.spacer({ flexGrow = 1 }),
      ui.label({ text = `{open} open · {done} done`, fontSize = 11, color = "on_surface_variant" }),
    }),
    ui.separator({ thickness = 1, color = "outline" }),
    ui.column({ gap = 2 }, rows),
  }))
end

function update()
  noctalia.setUpdateInterval(REFRESH_MS)
  scan()
  render()
end

scan()
render()
