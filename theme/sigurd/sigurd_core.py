"""Sigurd's behaviour, kept free of GTK so it can be tested on its own.

A visit: Sigurd trots in from one edge, wanders to a spot, grazes or stands for a while
(maybe twice), then trots out the other side. Clicking him shows a speech bubble with a
joke, a tip or a shortcut. `say` makes him carry a message in.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field

HORSE_W = 68  # logical px on screen
HORSE_H = 48
SPEED = 46.0  # px per second
BUBBLE_SECONDS = 8.0


@dataclass
class Message:
    text: str
    action_label: str | None = None
    command: str | None = None


JOKES = [
    "Why did the witcher refuse to use tabs? He only trusts silver spaces.",
    "I asked the alchemist for a quick fix. He brewed a hotfix potion. Side effects: Friday deploys.",
    "A drowner walks into a repo. It was a merge conflict all along.",
    "My favourite monster? The off-by-one. Always one step behind you.",
    "There are 10 kinds of horses: those who understand binary, and those who just want an apple.",
    "I don't trot, I stream. Lazily evaluated hooves.",
    "Nix rebuilt the whole world because I changed one comment. Purity has a price.",
    "Vesna says she'll meditate with you. I say: grass first, focus later.",
    "Rebase, merge or squash? I just roll in the meadow.",
    "Legends say there's a bug-free commit somewhere in the Blue Mountains.",
]

TIPS = [
    "Super + / shows every keybind on one page.",
    "`z part-of-name` jumps to any folder you've visited before.",
    "Super + O zooms out to the overview. Type to launch an app from there.",
    "`cleanup` keeps only the last 3 system versions and frees space.",
    "`gens` lists your system versions; pick an older one in the boot menu if something breaks.",
    "Super + Shift + G flips the terminal between frost and dark glass.",
    "Super + R cycles a column's width: a third, a half, two thirds.",
    "Super + W turns a column into tabs. Handy for terminals.",
    "`ports` shows what's listening, in case a dev server is stuck.",
    "`task list` shows every contract card and worktree in a repo.",
    "Scroll on the medallion in the bar to change your Witcher school.",
    "`ranger travel` charges to 100% before a long day away from a socket.",
]

SHORTCUTS = [
    Message("Need the agent guide? The Witcher's Codex has it all.", "Open the Codex", "ghostty --class=dev.codex --title=Codex -e guide"),
    Message("Time to focus? Vesna is ready to meditate with you.", "Start focus", "focus"),
    Message("Want today's overview? Weather, contracts, repos.", "Morning brief", "brief"),
    Message("Lost a keybind? The cheatsheet remembers.", "Cheatsheet", "ghostty --class=dev.cheatsheet --title=Cheatsheet -e cheatsheet"),
    Message("Curious what you've discovered? The bestiary keeps count.", "Bestiary", "bestiary"),
]


def random_message(rng: random.Random) -> Message:
    pool = rng.choices(["joke", "tip", "shortcut"], weights=[4, 4, 2])[0]
    if pool == "joke":
        return Message(rng.choice(JOKES))
    if pool == "tip":
        return Message("Traveller's tip: " + rng.choice(TIPS))
    return rng.choice(SHORTCUTS)


@dataclass
class Horse:
    """Position and mood of Sigurd during a visit. All times in seconds, x in logical px."""

    width: float
    rng: random.Random = field(default_factory=random.Random)
    x: float = 0.0
    dir: int = 1
    state: str = "hidden"  # hidden | walking | grazing | idle | leaving
    target: float = 0.0
    state_left: float = 0.0
    stops_left: int = 0
    frame_clock: float = 0.0
    frame_index: int = 0
    bubble: Message | None = None
    bubble_left: float = 0.0
    carrying: Message | None = None  # message to show once he stops

    # ── visits ──
    def start_visit(self, carrying: Message | None = None) -> None:
        self.dir = self.rng.choice([1, -1])
        self.x = -HORSE_W if self.dir > 0 else self.width
        self.carrying = carrying
        self.stops_left = 1 if carrying else self.rng.choice([1, 1, 2])
        self._walk_to_spot()

    def _walk_to_spot(self) -> None:
        lo, hi = self.width * 0.2, self.width * 0.8 - HORSE_W
        self.target = self.rng.uniform(lo, max(lo, hi))
        self.dir = 1 if self.target >= self.x else -1
        self.state = "walking"

    def _leave(self) -> None:
        self.state = "leaving"
        self.target = self.width + 10 if self.dir > 0 else -HORSE_W - 10

    @property
    def visible(self) -> bool:
        return self.state != "hidden"

    # ── interaction ──
    def click(self) -> Message | None:
        """Toggle the bubble; returns the message shown (or None when it was hidden)."""
        if self.bubble is not None:
            self.bubble = None
            return None
        self.show(random_message(self.rng))
        if self.state in ("walking", "leaving"):
            self.state = "idle"  # stop so you can read
            self.state_left = BUBBLE_SECONDS
            self.stops_left = max(self.stops_left, 1)
        return self.bubble

    def show(self, msg: Message, seconds: float = BUBBLE_SECONDS) -> None:
        self.bubble = msg
        self.bubble_left = seconds

    # ── time ──
    def step(self, dt: float) -> None:
        if self.state == "hidden":
            return
        if self.bubble is not None:
            self.bubble_left -= dt
            if self.bubble_left <= 0:
                self.bubble = None
        moving = self.state in ("walking", "leaving")
        self.frame_clock += dt
        period = 0.11 if moving else 0.5
        while self.frame_clock >= period:
            self.frame_clock -= period
            self.frame_index += 1

        if moving:
            self.x += self.dir * SPEED * dt
            arrived = (self.dir > 0 and self.x >= self.target) or (self.dir < 0 and self.x <= self.target)
            if arrived:
                if self.state == "leaving":
                    self.state = "hidden"
                    self.bubble = None
                    return
                self.x = self.target
                self.state = self.rng.choice(["grazing", "idle"])
                self.state_left = self.rng.uniform(4.0, 9.0)
                if self.carrying is not None:
                    self.state = "idle"
                    self.show(self.carrying, BUBBLE_SECONDS + 2)
                    self.state_left = BUBBLE_SECONDS + 2
                    self.carrying = None
        else:
            if self.bubble is not None and self.state_left < self.bubble_left:
                self.state_left = self.bubble_left  # wait until you've read it
            self.state_left -= dt
            if self.state_left <= 0:
                self.stops_left -= 1
                if self.stops_left > 0:
                    self._walk_to_spot()
                else:
                    self.dir = self.rng.choice([1, -1])
                    self._leave()

    # ── drawing ──
    def frame_name(self) -> str:
        side = "r" if self.dir > 0 else "l"
        if self.state in ("walking", "leaving"):
            return f"walk_{self.frame_index % 4}_{side}"
        if self.state == "grazing":
            return f"graze_{self.frame_index % 2}_{side}"
        blink = self.frame_index % 9 == 0
        return f"idle_{1 if blink else 0}_{side}"


class Scheduler:
    """Decides when Sigurd visits on his own: random gaps around a mean, only in active hours."""

    def __init__(self, mean_minutes: float, active_from: int, active_to: int, rng: random.Random | None = None):
        self.mean = max(1.0, mean_minutes) * 60
        self.active_from = active_from
        self.active_to = active_to
        self.rng = rng or random.Random()
        self.next_at: float | None = None

    def plan(self, now: float) -> None:
        # between half and one and a half times the mean
        self.next_at = now + self.rng.uniform(0.5, 1.5) * self.mean

    def due(self, now: float, hour: int) -> bool:
        if self.next_at is None:
            self.plan(now)
        if now < self.next_at:
            return False
        self.plan(now)
        return self.active_from <= hour < self.active_to


def parse_command(line: str) -> tuple[str, str]:
    """Socket protocol: one line, `say <text>` or `visit`."""
    line = line.strip()
    if not line:
        return "", ""
    verb, _, rest = line.partition(" ")
    return verb.lower(), rest.strip()
