-- Task cards from every repo in the code folders, shared by the contract board, the morning
-- brief, encounters and the ledger (bar + panel). The events service refreshes them every
-- 30 s and publishes them as km.cards; everything else just reads that.
--   docs/tasks/TIN-1234-01-login-form.md   card TIN-1234-01 of Linear issue TIN-1234
--   docs/tasks/003-login.md                older card without an issue
-- Progress inside a card = its ticked checkboxes (Steps + Acceptance criteria).
local M = {}

M.STATUS = {
  changes = { glyph = "alert-triangle", color = "error", label = "Fix", rank = 0 },
  working = { glyph = "swords", color = "primary", label = "In progress", rank = 1 },
  review = { glyph = "eye", color = "tertiary", label = "Review", rank = 2 },
  todo = { glyph = "pin", color = "on_surface_variant", label = "To do", rank = 3 },
  done = { glyph = "circle-check", color = "secondary", label = "Done", rank = 4 },
}

local function isDir(path: string): boolean
  local info = noctalia.fileInfo(path)
  return info ~= nil and info.isDir == true
end
M.isDir = isDir

-- Repos (folders) inside the code folders: { name, path }
function M.repos(codeDirs: { string })
  local out = {}
  for _, root in ipairs(codeDirs) do
    for _, name in ipairs(noctalia.listDir(root) or {}) do
      local path = root .. "/" .. name
      if string.sub(name, 1, 1) ~= "." and isDir(path) then
        table.insert(out, { name = name, path = path })
      end
    end
  end
  return out
end

local function statusKey(status: string, changes: boolean, hasWorktree: boolean): string
  -- approved = the reviewer is happy; what's left (commit, merge) is yours, so it counts as done
  if status == "done" or status == "merged" or status == "approved" then
    return "done"
  elseif status == "changes-requested" or (changes and status == "todo") then
    return "changes"
  elseif status == "review" or status == "in-review" then
    return "review"
  elseif hasWorktree or status == "in-progress" or status == "doing" then
    return "working"
  end
  return "todo"
end

local function stripTitle(t: string): string
  return (string.gsub(t, "^[%u%d%-]+%s*[%-–—:]+%s*", "")) -- "TIN-1234-01 — Add login" → "Add login"
end

-- Cards from the output of the kaer-morhen-cards script (one tab-separated line each; see
-- kaer-morhen.nix). Reading the files happens there, outside the shell's 25 ms per call.
-- Every card: { repo, path, file, num (= card ID), issue?, no, title, key, status, base?,
--               checksDone, checksTotal, mtime }
function M.fromRows(text: string)
  local found = {}
  for line in string.gmatch(text or "", "[^\n]+") do
    local f = string.split(line, "\t")
    if #f >= 15 then
      local status = if f[9] ~= "" then f[9] else "todo"
      local issue = if f[10] ~= "" then f[10] elseif f[5] ~= "" then f[5] else nil
      table.insert(found, {
        repo = f[1], path = f[2], file = f[3], num = f[4], no = f[6], issue = issue,
        status = status, base = if f[11] ~= "" then f[11] else nil, title = stripTitle(f[12]),
        key = statusKey(status, f[15] == "1", f[7] == "1"),
        checksDone = tonumber(f[13]) or 0, checksTotal = tonumber(f[14]) or 0,
        mtime = tonumber(f[8]) or 0, issueTitle = if f[16] and f[16] ~= "" then f[16] else nil,
      })
    end
  end
  table.sort(found, function(a, b)
    local ra, rb = M.STATUS[a.key].rank, M.STATUS[b.key].rank
    if ra ~= rb then
      return ra < rb
    end
    if a.repo ~= b.repo then
      return a.repo < b.repo
    end
    return a.num < b.num
  end)
  return found
end

-- The latest cards, as published by the events service (km.cards)
function M.current()
  local s = noctalia.state.get("km.cards")
  return if type(s) == "table" and type(s.cards) == "table" then s.cards else {}
end

-- Cards grouped by Linear issue, across projects (one issue can touch several repos). Cards
-- without an issue are grouped per project. Open groups first, most recently touched first.
-- { key, issue?, title?, repos = { name… }, cards, done, total, counts = { key → n }, mtime, open }
function M.issues(cards)
  local byKey, list = {}, {}
  for _, c in cards do
    local key = if c.issue then "issue:" .. c.issue else "repo:" .. c.repo
    local g = byKey[key]
    if not g then
      g = { key = key, issue = c.issue, title = nil, repos = {}, cards = {}, done = 0, total = 0, mtime = 0,
        counts = { changes = 0, working = 0, review = 0, todo = 0, done = 0 } }
      byKey[key] = g
      table.insert(list, g)
    end
    table.insert(g.cards, c)
    if not table.find(g.repos, c.repo) then
      table.insert(g.repos, c.repo)
    end
    g.title = g.title or c.issueTitle
    g.total += 1
    g.counts[c.key] += 1
    if c.key == "done" then
      g.done += 1
    end
    g.mtime = math.max(g.mtime, c.mtime or 0)
  end
  for _, g in list do
    g.open = g.done < g.total
    table.sort(g.repos)
    table.sort(g.cards, function(a, b)
      if a.repo ~= b.repo then
        return a.repo < b.repo
      end
      return a.num < b.num
    end)
  end
  table.sort(list, function(a, b)
    if a.open ~= b.open then
      return a.open
    end
    if (a.issue ~= nil) ~= (b.issue ~= nil) then
      return a.issue ~= nil -- issues before loose project cards
    end
    if a.mtime ~= b.mtime then
      return a.mtime > b.mtime
    end
    return a.key < b.key
  end)
  return list
end

return M
