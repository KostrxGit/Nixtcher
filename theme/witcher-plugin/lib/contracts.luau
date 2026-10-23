-- Task cards (docs/tasks/NNN-*.md) from every repo in the code folders, shared by the
-- contract board and the morning brief.
local M = {}

M.STATUS = {
  changes = { glyph = "alert-triangle", color = "error", label = "Needs another go", rank = 0 },
  working = { glyph = "swords", color = "primary", label = "Taken", rank = 1 },
  review = { glyph = "eye", color = "tertiary", label = "Reward to collect", rank = 2 },
  todo = { glyph = "pin", color = "on_surface_variant", label = "Posted", rank = 3 },
  done = { glyph = "circle-check", color = "secondary", label = "Completed", rank = 4 },
}

local function isDir(path: string): boolean
  local info = noctalia.fileInfo(path)
  return info ~= nil and info.isDir == true
end
M.isDir = isDir

local function parseCard(path: string)
  local text = noctalia.readFile(path)
  if not text then
    return nil
  end
  local status = string.match(text, "\nstatus:%s*([%w%-_]+)") or string.match(text, "^status:%s*([%w%-_]+)") or "todo"
  local title = string.match(text, "\n#%s+([^\n]+)") or ""
  title = string.gsub(title, "^%d+%s*[%-–—:]+%s*", "") -- "# 003 — Add login" → "Add login"
  return status, title, string.find(text, "## Changes requested", 1, true) ~= nil
end

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

function M.scan(codeDirs: { string })
  local found = {}
  for _, r in ipairs(M.repos(codeDirs)) do
    local tasksDir = r.path .. "/docs/tasks"
    if isDir(tasksDir) then
      for _, file in ipairs(noctalia.listDir(tasksDir) or {}) do
        local num = string.match(file, "^(%d+)%-.*%.md$")
        if num then
          local status, title, changes = parseCard(tasksDir .. "/" .. file)
          if status then
            local key = "todo"
            if status == "done" or status == "merged" then
              key = "done"
            elseif status == "changes-requested" or (changes and status == "todo") then
              key = "changes"
            elseif status == "review" or status == "in-review" or status == "approved" then
              key = "review"
            elseif isDir(r.path .. "/.claude/worktrees/task-" .. num) or status == "in-progress" or status == "doing" then
              key = "working"
            end
            table.insert(found, { repo = r.name, path = r.path, num = num, title = title, key = key })
          end
        end
      end
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

return M
