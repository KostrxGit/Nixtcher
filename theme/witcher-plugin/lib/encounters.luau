-- Encounters and the bestiary: content and rules, without side effects.
-- The events service owns the timing, sounds, panels and notifications; this module only
-- decides what happens and keeps the record in `saved` (persisted as JSON).
--
--   merchant   a daily challenge the system can check (focus, rebuilds, tests, commits, contracts)
--   monster    a short real-life or code-hygiene task; accept it, then mark it slain in the bestiary
--   traveller  an original saying or a tip for this machine
--   badge      a rare reward for something you actually did (granted by checkBadges)
-- Crowns are the purse: challenges, slain monsters and badges pay out.

local E = {}

E.CHALLENGES = {
  { id = "focus2", title = "Two meditations", text = "Finish two focus sessions today.", metric = "focusToday", goal = 2, reward = 15 },
  { id = "focus4", title = "The long vigil", text = "Finish four focus sessions today.", metric = "focusToday", goal = 4, reward = 30 },
  { id = "brew", title = "A clean brew", text = "Rebuild the system without spoiling the potion.", metric = "buildsToday", goal = 1, reward = 10 },
  { id = "trial", title = "Trial of the tests", text = "Get a passing test or build run (`t` or `b`).", metric = "testsToday", goal = 1, reward = 10 },
  { id = "marks", title = "Make your mark", text = "Make three commits today, in any repo.", metric = "commitsToday", goal = 3, reward = 20 },
  { id = "reward", title = "Collect a reward", text = "Get one contract card to review or done today.", metric = "contractsToday", goal = 1, reward = 25 },
}

E.MONSTERS = {
  { id = "drowner", name = "Drowner", task = "Delete one merged branch (`git branch --merged`).", reward = 10 },
  { id = "nekkers", name = "Nekker swarm", task = "Clear five TODO comments in one repo.", reward = 15 },
  { id = "ghoul", name = "Ghoul", task = "Remove one dependency nobody uses any more.", reward = 15 },
  { id = "noonwraith", name = "Noonwraith", task = "Close every browser tab you haven't looked at today.", reward = 5 },
  { id = "wraith", name = "Wraith", task = "Run `cleanup` and banish old system versions.", reward = 5 },
  { id = "leshen", name = "Leshen", task = "Split one oversized task card into smaller contracts.", reward = 20 },
  { id = "bruxa", name = "Bruxa", task = "Fix one linter warning that has been whispering at you.", reward = 10 },
  { id = "werewolf", name = "Werewolf", task = "Update one project's dependencies and run its tests.", reward = 20 },
  { id = "griffin", name = "Griffin", task = "Write the README section you keep avoiding.", reward = 15 },
  { id = "alghoul", name = "Alghoul", task = "Delete ten old files from Downloads.", reward = 5 },
  { id = "fiend", name = "Fiend", task = "Walk away from the screen for ten minutes.", reward = 10 },
  { id = "kikimore", name = "Kikimore", task = "Answer the oldest message you've been ignoring.", reward = 10 },
}

E.TRAVELLERS = {
  "A sharp blade is nothing without a steady hand. Commit small, commit often.",
  "Every monster has a weakness. Every bug has a stack trace. Read it twice.",
  "The road is long, but the inn is warm. Take your breaks.",
  "Old witchers keep their notes. Write down why, not just what.",
  "Silver for monsters, steel for men, tests for code.",
  "A contract half-read is a contract half-done.",
  "Even Kaer Morhen was built one stone at a time.",
  "Tip: Super + O shows every window at once; start typing to launch an app.",
  "Tip: `z` plus part of a folder name jumps anywhere you've been before.",
  "Tip: `gens` lists system versions. Any of them can be chosen in the boot menu.",
  "Tip: Super + W turns a column into tabs, good for a stack of terminals.",
  "Tip: `task list` shows every contract card and agent camp in a repo.",
}

E.BADGES = {
  { id = "first-focus", name = "First Meditation", text = "Finished your first focus session.", glyph = "hourglass", reward = 10 },
  { id = "focus-10", name = "Steady Mind", text = "Ten focus sessions.", glyph = "hourglass", reward = 25 },
  { id = "focus-50", name = "Master of Meditation", text = "Fifty focus sessions.", glyph = "hourglass", reward = 60 },
  { id = "brewer-25", name = "Alchemist", text = "Twenty-five clean rebuilds.", glyph = "flask", reward = 25 },
  { id = "schools", name = "Wanderer of Schools", text = "Wore all four medallions.", glyph = "swords", reward = 20 },
  { id = "hunter-5", name = "Monster Slayer", text = "Slew five monsters.", glyph = "sword", reward = 25 },
  { id = "merchant-5", name = "Trusted Trader", text = "Completed five merchant challenges.", glyph = "coin", reward = 25 },
  { id = "night-owl", name = "Night Owl", text = "Finished a focus session after 23:00.", glyph = "moon", reward = 10 },
  { id = "early-bird", name = "Early Bird", text = "Finished a focus session before 8:00.", glyph = "sunrise", reward = 10 },
  { id = "streak-3", name = "Three Days on the Path", text = "Focused on three days in a row.", glyph = "flame", reward = 20 },
}

local function find(list, id)
  for _, item in list do
    if item.id == id then
      return item
    end
  end
  return nil
end
E.find = find

-- Fill in missing parts of the saved record (first run, or an older version of it).
function E.init(saved)
  saved.crowns = saved.crowns or 0
  saved.bestiary = saved.bestiary or {}      -- id → { count, first }
  saved.badges = saved.badges or {}          -- id → date earned
  saved.hunts = saved.hunts or {}            -- accepted monster contracts
  saved.challenge = saved.challenge or nil   -- { date, id, accepted, done, baseline }
  saved.stats = saved.stats or {}
  local st = saved.stats
  st.focus = st.focus or 0
  st.builds = st.builds or 0
  st.slain = st.slain or 0
  st.challenges = st.challenges or 0
  st.schools = st.schools or { wolf = true }
  st.focusDays = st.focusDays or {}          -- recent dates with a focus session
  saved.encDate = saved.encDate or ""
  saved.encToday = saved.encToday or 0
  return saved
end

local function discover(saved, id: string, today: string)
  local entry = saved.bestiary[id]
  if entry then
    entry.count += 1
  else
    saved.bestiary[id] = { count = 1, first = today }
  end
end
E.discover = discover

-- Pick the next encounter. `rand(n)` returns 1..n (math.random in the shell).
function E.roll(saved, today: string, rand)
  local options = {}
  local function add(kind, weight)
    for _ = 1, weight do
      table.insert(options, kind)
    end
  end
  if not saved.challenge or saved.challenge.date ~= today then
    add("merchant", 3)
  end
  if #saved.hunts < 3 then
    add("monster", 4)
  end
  add("traveller", 3)
  local kind = options[rand(#options)]
  if kind == "merchant" then
    local c = E.CHALLENGES[rand(#E.CHALLENGES)]
    return { kind = "merchant", id = c.id, title = "A merchant hails you",
      text = `{c.title}: {c.text} Reward: {c.reward} crowns.`, glyph = "coin", accept = "Accept", reward = c.reward }
  elseif kind == "monster" then
    local m = E.MONSTERS[rand(#E.MONSTERS)]
    return { kind = "monster", id = m.id, title = `Contract: {m.name}`, text = `{m.task} Reward: {m.reward} crowns.`,
      glyph = "swords", accept = "Take the contract", reward = m.reward }
  end
  local line = E.TRAVELLERS[rand(#E.TRAVELLERS)]
  return { kind = "traveller", id = "traveller", title = "A mysterious traveller", text = line, glyph = "route",
    accept = nil, reward = 0 }
end

-- Accepting an encounter; `metrics` gives the current counters (for the challenge baseline).
function E.accept(saved, enc, today: string, metrics)
  if enc.kind == "merchant" then
    local c = find(E.CHALLENGES, enc.id)
    saved.challenge = { date = today, id = enc.id, accepted = true, done = false,
      baseline = if c then metrics[c.metric] or 0 else 0 }
    discover(saved, "merchant", today)
  elseif enc.kind == "monster" then
    if #saved.hunts < 3 then
      table.insert(saved.hunts, { id = enc.id, accepted = today })
    end
    discover(saved, "monster:" .. enc.id, today)
  else
    discover(saved, "traveller", today)
  end
end

function E.dismiss(saved, enc, today: string)
  if enc.kind == "merchant" then
    saved.challenge = { date = today, id = enc.id, accepted = false, done = false, baseline = 0 }
  end
  if enc.kind == "traveller" then
    discover(saved, "traveller", today)
  end
end

-- Progress of today's challenge: progress, goal, challenge (or nil when there is none).
function E.challengeProgress(saved, today: string, metrics)
  local ch = saved.challenge
  if not ch or ch.date ~= today or not ch.accepted then
    return nil
  end
  local c = find(E.CHALLENGES, ch.id)
  if not c then
    return nil
  end
  local value = metrics[c.metric] or 0
  if c.metric == "contractsToday" then -- contracts moved to review/done since accepting
    value -= ch.baseline or 0
  end
  return math.clamp(value, 0, c.goal), c.goal, c
end

-- Returns the challenge when it has just been completed (and pays out), otherwise nil.
function E.checkChallenge(saved, today: string, metrics)
  local progress, goal, c = E.challengeProgress(saved, today, metrics)
  if not c or saved.challenge.done or progress < goal then
    return nil
  end
  saved.challenge.done = true
  saved.crowns += c.reward
  saved.stats.challenges += 1
  return c
end

function E.slay(saved, index: number, today: string)
  local hunt = saved.hunts[index]
  if not hunt then
    return nil
  end
  table.remove(saved.hunts, index)
  local m = find(E.MONSTERS, hunt.id)
  saved.stats.slain += 1
  saved.crowns += if m then m.reward else 5
  local key = "slain:" .. hunt.id
  discover(saved, key, today)
  return m
end

-- Record something that happened; ctx = { today, hour, yesterday? }
function E.record(saved, what: string, ctx)
  local st = saved.stats
  if what == "focus" then
    st.focus += 1
    st.lastFocusHour = ctx.hour
    if st.focusDays[#st.focusDays] ~= ctx.today then
      table.insert(st.focusDays, ctx.today)
      while #st.focusDays > 7 do
        table.remove(st.focusDays, 1)
      end
    end
  elseif what == "build" then
    st.builds += 1
  elseif string.sub(what, 1, 7) == "school:" then
    st.schools[string.sub(what, 8)] = true
  end
end

-- Badges earned but not yet granted; grants them (and pays) and returns the list.
function E.checkBadges(saved, ctx)
  local st = saved.stats
  local function schoolsAll()
    return st.schools.wolf and st.schools.cat and st.schools.griffin and st.schools.bear
  end
  local function streak3()
    local days = st.focusDays
    if #days < 3 or not ctx.daysAgo then
      return false
    end
    return days[#days] == ctx.daysAgo(0) and days[#days - 1] == ctx.daysAgo(1) and days[#days - 2] == ctx.daysAgo(2)
  end
  local earned = {
    ["first-focus"] = st.focus >= 1,
    ["focus-10"] = st.focus >= 10,
    ["focus-50"] = st.focus >= 50,
    ["brewer-25"] = st.builds >= 25,
    ["schools"] = schoolsAll() == true,
    ["hunter-5"] = st.slain >= 5,
    ["merchant-5"] = st.challenges >= 5,
    ["night-owl"] = st.lastFocusHour ~= nil and st.lastFocusHour >= 23,
    ["early-bird"] = st.lastFocusHour ~= nil and st.lastFocusHour < 8 and st.lastFocusHour >= 4,
    ["streak-3"] = streak3(),
  }
  local new = {}
  for _, b in E.BADGES do
    if earned[b.id] and not saved.badges[b.id] then
      saved.badges[b.id] = ctx.today
      saved.crowns += b.reward
      table.insert(new, b)
    end
  end
  return new
end

-- How many encounters may still happen today (resets the counter on a new day).
function E.remainingToday(saved, today: string, perDay: number): number
  if saved.encDate ~= today then
    saved.encDate = today
    saved.encToday = 0
  end
  return perDay - saved.encToday
end

function E.countEncounter(saved, today: string)
  E.remainingToday(saved, today, 0)
  saved.encToday += 1
end

return E
