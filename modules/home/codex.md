# ⚔  The Witcher's Codex

*How contracts are posted, taken and paid for. Working with Claude agents on this machine.*

Scroll with **↑ ↓ / PgUp PgDn / Space**, search with **/**, close with **q**.
Open it again any time with **Super + G**.

---

## The cast

| In Kaer Morhen | On your machine | What it does |
|---|---|---|
| **The alderman** | `manager` | Listens to your request, asks questions, posts **contracts** (task cards) on the notice board. Never touches the code. |
| **The notice board** | `docs/tasks/NNN-*.md` | One card per job: goal, steps, files, acceptance criteria. Also shown on your desktop as the **Contracts** card. |
| **A witcher** | `task start NNN` | A coding agent that takes one contract and works it in its own camp. |
| **The witcher's camp** | `.claude/worktrees/task-NNN` | A separate copy of the repo (git worktree). Your own checkout stays untouched. |
| **The trophy inspection** | `task review NNN` | A reviewer agent compares the work with the contract and writes its verdict into the card. |
| **The coin** | `task diff NNN` → commit | **You** read the changes and commit them yourself. No agent can commit, push or merge. |

---

## Before the first hunt in a repo

1. Go to the repo: `codework` or `codepersonal` (pick from the list), or `w name` / `p name`.
2. Dev shell, if the repo has none yet:
   - your own repo: `nix flake init -t ~/nixos#node` (or `#expo`, `#python`, `#rust`),
     then `git add flake.nix .envrc && direnv allow`
   - a work repo nobody else uses Nix in:
     `echo 'use flake "path:$HOME/nixos/templates/node"' > .envrc`,
     `printf '.envrc\n.direnv/\ndocs/tasks/\n' >> .git/info/exclude`, `direnv allow`
3. Let Claude learn the place: run `claude`, type `/init`, quit with `/exit`.
   It writes `CLAUDE.md` (project notes every agent reads).

---

## The contract cycle

```
  you ──▶ manager ──▶ docs/tasks/003-login.md ──▶ task start 003 ──▶ agent works
                                                                         │
  merge ◀── you commit ◀── task diff 003 ◀── task review 003 ◀───────────┘
```

**1. Post the contract**
```
manager
```
Describe what you want in plain words. The alderman asks questions, then writes one or
more cards and tells you which can run **in parallel** and which must **wait**.
Read the card before you start it. Edit it by hand if something is off.

**2. Send a witcher**
```
task start 003
```
A new terminal window opens with the coding agent, in its own worktree.
It **asks before** running commands or editing. Answer in that window:
- **Enter / 1**: yes, this once
- **2**: yes, and don't ask again for this kind of action (this session)
- **Esc**: no / stop. Then tell it what to do instead.

When it needs you, the **wolf medallion** in the bar starts humming.
When it finishes a turn, the **pup** hops.

**3. Inspect the trophy**
```
task review 003
```
The reviewer checks the diff against the card and writes its verdict into the card.
- *Approved*: go to step 4.
- *Changes requested*: open `manager` again, show it the verdict, it updates the card;
  then `task start 003` again.

**4. Pay the coin**
```
task diff 003
```
Opens **lazygit** in the agent's worktree:
`space` stage file · `c` commit · `↑ ↓` move · `enter` view the diff · `q` quit.

**5. Bring the trophy home**
```
git worktree list              # shows the agent's branch name
git merge <that-branch>        # in your main checkout
git push
task clean 003                 # removes the camp (the branch stays until you delete it)
```

---

## Several witchers at once

- Start cards that touch **different files** together: `task start 004`, `task start 005`.
  Each gets its own window and its own worktree; they cannot step on each other.
- Cards that touch the same files: one after the other (the manager tells you which).
- `task list` shows every card with its status and every open worktree.
- `claude agents` shows every agent that is running.
- The **Contracts** card on the desktop shows everything across all your repos:

| Sign | Meaning |
|---|---|
| ⚠ red | needs another go (changes requested) |
| ⚔ blue | taken: an agent has a worktree for it |
| 👁 orange | waiting for your review / commit |
| 📌 grey | posted, nobody took it yet |
| ✔ | completed |

Click a contract to open a terminal in that repo.

---

## Signs and omens

| Omen | Meaning | What to do |
|---|---|---|
| Medallion **hums blue** and keeps trembling | An agent is waiting for your answer or permission | Find its window and answer. Click the medallion to calm it |
| Medallion **glows red** | `rebuild` failed | Read the terminal; a good `rebuild` calms it |
| Pup **hops** | An agent finished a turn, or tests / build passed | Check its work |
| Pup **droops** | Tests or build failed (`t`, `b`) | Read the output |
| Pup **sleeps** | You've been away 2 minutes | Move the mouse; it wakes |

---

## Silver and steel: automatic checks

Every agent works with two blades you don't have to think about:

- **The language servers** (TypeScript, Python, Rust): after each edit Claude sees the same
  errors your editor shows (type errors, missing or unused imports) and fixes them in the same
  step. Press **Ctrl+O** in Claude to read them yourself.
- **The lint hook**: after each edit the repo's own formatter and linter run on that file
  (Prettier/ESLint or Biome, Ruff, rustfmt). Unused imports are removed automatically;
  anything else goes straight back to Claude to fix before it continues.
  Repos without those tools are left alone (Python still gets the unused-import check).

---

## Life in the keep

| What | How |
|---|---|
| **Focus session** | **Super + M** or right-click Vesna. She meditates for 25 minutes with a countdown, then a *Contract complete* scroll unrolls and you rest 5 minutes (15 after every fourth). Right-click again to stop |
| **Morning brief** | Opens by itself on the first login or unlock of the day; **Super + Shift + B** any time. Weather, contracts, repos with uncommitted or unpushed work, battery health |
| **Schools** | Scroll on the bar medallion, or `school cat` / `griffin` / `bear` / `wolf`. Changes the shell's accent colour, the medallion and its hum |
| **Ranger mode** | The *Ranger* tile in the control centre (Super + S) or `ranger`: power saver, dimmer screen, a calmer pup. The tile also shows battery health |
| **Full charge for a trip** | `ranger travel` charges to 100% once; `ranger home` (or a reboot) goes back to the 80% limit |
| **The Forge** | Desktop card with your Docker containers and ports. Click one to follow its logs |
| **Sigurd** | A pony who trots along the bottom of the screen every 40 minutes or so (9:00 to 22:00). Click him for a joke, a tip or a shortcut. When `rebuild`, `b` or `t` runs longer than a minute he brings the result. `sigurd visit` calls him over |
| **Encounters** | About five a day a card appears in the top-right corner: a **merchant** with a daily challenge the system checks for you, a **monster contract** (a small real task; mark it *Slain* when done), a **traveller** with a saying or a tip, or a rare **badge** for something you did. Never during focus, when idle or locked. *Not now* or closing the card dismisses it. `encounters off` / `on` pauses them, `encounters now` summons one |
| **Bestiary** | **Super + Shift + A** or `bestiary`: your crowns, today's challenge, open contracts, badges and every creature you've met. Frequency and hours live in `modules/home/kaer-morhen.nix` → `encounters` |
| **Wallpapers** | **Super + Alt + W** next, **+ Shift** back, or `wall keep` / `wall list`. The choice is remembered and still gets the dawn / dusk / night tint. Add one: put it in `theme/wallpapers/`, add a line to `wallpaperList` in `modules/home/kaer-morhen.nix` |
| **Your phone** | KDE Connect: install it on Android, open the KDE Connect icon in the bar's tray and pair. Phone notifications then show up here |

---

## Quick jobs without a contract

For a small question or a one-line fix you don't need the whole cycle:
```
claude                    # in the repo; ask directly
claude -c                 # continue your last conversation here
claude -r                 # pick an older conversation to resume
```
Useful inside Claude: `/clear` start fresh · `/compact` shrink a long conversation ·
**Shift+Tab** switch to *plan mode* (it plans before touching anything) ·
**Esc** interrupt · **Esc Esc** rewind to an earlier message · `/exit` quit.

---

## The witcher's code (rules every agent follows)

- Never commits, pushes, merges, rebases or resets. **History is yours.**
- Never uses `sudo`, never reads `.env` files or your SSH keys.
- Asks before `rm`, `docker` and `nix` commands, and before adding a dependency.
- Uses tools from the repo's dev shell; says what is missing instead of installing globally.
- Databases run in Docker Compose inside the repo.

These rules live in `~/code/personal/claude-agents` (`settings.json`, `CLAUDE.md`).
Edit them there; no rebuild needed.

---

## Bestiary: common monsters and how to slay them

**Drowner**: *a merge conflict.* Two contracts touched the same file.
→ Merge one branch, then in the other worktree ask the agent to rebase its work on top
(or resolve in lazygit). Next time let the manager put those tasks in one card.

**Noonwraith**: *the agent wanders off scope.* It edits files the card never mentioned.
→ Press **Esc**, point it back to the card's *Files* and *Out of scope* sections.

**Leshen**: *a contract too big to kill in one go.* The agent runs for ages, loses the thread.
→ Stop it. Ask the manager to split the card into smaller ones.

**Nekker swarm**: *endless permission prompts.* → Answer **2** ("don't ask again") for safe,
repeated commands like running tests.

**Wraith in the camp**: *a leftover worktree.* `task list` shows camps for finished work.
→ `task clean NNN`, then `git branch -d <branch>` once it is merged.

**Botchling**: *the agent says "done" but the tests fail.* → `task review` catches it.
Paste the failing output back into the agent's window.

**Godling** (friendly): *Claude asks a good clarifying question.* Answer it. Contracts with
clear acceptance criteria come back finished.

---

## Command scroll

| Command | Does |
|---|---|
| `manager` | Plan with Claude; writes contract cards |
| `task start NNN` | Send a coding agent on card NNN |
| `task review NNN` | Reviewer checks the work |
| `task diff NNN` | Lazygit in the agent's worktree: review and commit |
| `task clean NNN` | Remove the worktree after merging |
| `task list` | Cards and worktrees in this repo |
| `claude agents` | All running agents |
| `codework` / `codepersonal` | Jump to a repo |
| `t` / `b` / `dev` | Test / build / run dev server (the pup reacts) |
| `gs` `gd` `glog` | Git status / diff / history |
| **Super + G** | This codex |
| **Super + /** | Keybind cheatsheet |
| **Super + M** / `focus` | Focus session with Vesna |
| `brief` / `school` / `ranger` | Morning brief / change school / power saving |
| **Super + Shift + A** / `bestiary` | Crowns, badges, contracts |
| `encounters [on\|off\|now]` / `sigurd visit` | Encounters / call Sigurd |

*A contract is finished when the coin changes hands, and the coin is your commit.*
