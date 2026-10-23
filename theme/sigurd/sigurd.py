#!/usr/bin/env python3
"""Sigurd, a little pony who now and then trots along the bottom of the screen.

Runs as a layer-shell overlay (gtk4-layer-shell) on the focused monitor. The overlay only
takes clicks where Sigurd and his speech bubble are; everything else passes through to the
windows underneath. He's below fullscreen windows, so he never interrupts a video or game.

  sigurd                 run (the user service does this)
  sigurd visit           ask him to come by now
  sigurd say <text>      he trots in carrying a message
"""

from __future__ import annotations

import json
import os
import random
import socket
import subprocess
import sys
import time

import sigurd_core as core

SOCKET = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "sigurd.sock")
CONFIG = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "sigurd", "config.json")
TICK_MS = 50
STRIP_H = 220  # overlay height (logical px); only the horse and bubble take input
GROUND = 4  # gap between his hooves and the screen edge


def client(argv: list[str]) -> int:
    verb = argv[0]
    if verb not in ("say", "visit"):
        print("usage: sigurd [visit | say <text>]")
        return 1
    line = verb + (" " + " ".join(argv[1:]) if len(argv) > 1 else "")
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.connect(SOCKET)
            s.sendall((line + "\n").encode())
    except OSError:
        print("Sigurd isn't running (systemctl --user start sigurd).", file=sys.stderr)
        return 1
    return 0


def load_config() -> dict:
    cfg = {"enabled": True, "visitEveryMinutes": 40, "activeFrom": 9, "activeTo": 22, "frames": None}
    try:
        with open(CONFIG) as f:
            cfg.update(json.load(f))
    except (OSError, ValueError):
        pass
    if not cfg["frames"]:
        cfg["frames"] = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frames")
    return cfg


def run() -> int:
    import gi

    gi.require_version("Gtk", "4.0")
    gi.require_version("Gtk4LayerShell", "1.0")
    gi.require_foreign("cairo")
    import cairo
    from gi.repository import Gdk, Gio, GLib, Gtk
    from gi.repository import Gtk4LayerShell as LayerShell

    cfg = load_config()
    rng = random.Random()
    scheduler = core.Scheduler(cfg["visitEveryMinutes"], cfg["activeFrom"], cfg["activeTo"], rng)

    css = Gtk.CssProvider()
    css_text = (
        """
        window.sigurd, window.sigurd > * { background: transparent; box-shadow: none; }
        .bubble {
          background: alpha(#161C26, 0.88);
          color: #DEE5EE;
          border: 1px solid alpha(#DEE5EE, 0.22);
          border-radius: 14px;
          padding: 10px 14px;
        }
        .bubble label { font-size: 11pt; }
        .bubble button {
          margin-top: 6px;
          padding: 2px 12px;
          border-radius: 9px;
          background: #8DB3E2;
          color: #161C26;
          border: none;
        }
        """
    )
    if hasattr(css, "load_from_string"):  # GTK 4.12+
        css.load_from_string(css_text)
    else:
        css.load_from_data(css_text.encode())

    class App(Gtk.Application):
        def __init__(self):
            super().__init__(application_id="dev.sigurd", flags=Gio.ApplicationFlags.NON_UNIQUE)
            self.win = None
            self.horse: core.Horse | None = None
            self.pending: core.Message | None = None
            self.textures: dict[str, Gdk.Texture] = {}
            self.last = time.monotonic()

        # ── start-up ──
        def do_activate(self):
            self.hold()  # keep running between visits (no window then)
            Gtk.StyleContext.add_provider_for_display(
                Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            )
            for name in os.listdir(cfg["frames"]):
                if name.endswith(".png"):
                    self.textures[name[:-4]] = Gdk.Texture.new_from_filename(os.path.join(cfg["frames"], name))
            self.listen()
            GLib.timeout_add_seconds(20, self.on_schedule)

        def listen(self):
            try:
                os.unlink(SOCKET)
            except FileNotFoundError:
                pass
            self.service = Gio.SocketService()
            self.service.add_address(
                Gio.UnixSocketAddress.new(SOCKET), Gio.SocketType.STREAM, Gio.SocketProtocol.DEFAULT, None
            )
            self.service.connect("incoming", self.on_incoming)
            self.service.start()

        def on_incoming(self, _service, connection, _source):
            stream = Gio.DataInputStream.new(connection.get_input_stream())
            line, _length = stream.read_line_utf8(None)
            verb, text = core.parse_command(line or "")
            if verb == "say" and text:
                self.deliver(core.Message(text))
            elif verb == "visit":
                self.deliver(None)
            return True

        def on_schedule(self):
            lt = time.localtime()
            if cfg["enabled"] and self.win is None and scheduler.due(time.time(), lt.tm_hour):
                self.deliver(None)
            return True

        # ── visits ──
        def deliver(self, msg: core.Message | None):
            if self.horse is not None and self.horse.visible:
                if msg is not None:
                    self.horse.show(msg)
                    if self.horse.state in ("walking", "leaving"):
                        self.horse.state = "idle"
                        self.horse.state_left = core.BUBBLE_SECONDS
                        self.horse.stops_left = max(self.horse.stops_left, 1)
                return
            self.pending = msg
            self.open_window()

        def open_window(self):
            win = Gtk.Window(application=self)
            win.add_css_class("sigurd")
            win.set_decorated(False)
            LayerShell.init_for_window(win)
            LayerShell.set_namespace(win, "sigurd")
            LayerShell.set_layer(win, LayerShell.Layer.TOP)  # under fullscreen windows
            for edge in (LayerShell.Edge.BOTTOM, LayerShell.Edge.LEFT, LayerShell.Edge.RIGHT):
                LayerShell.set_anchor(win, edge, True)
            LayerShell.set_exclusive_zone(win, -1)  # sit on the very edge, reserve nothing
            LayerShell.set_keyboard_mode(win, LayerShell.KeyboardMode.NONE)
            win.set_default_size(-1, STRIP_H)

            self.fixed = Gtk.Fixed()
            self.picture = Gtk.Picture()
            self.picture.set_size_request(core.HORSE_W, core.HORSE_H)
            self.picture.set_can_shrink(True)
            self.picture.set_content_fit(Gtk.ContentFit.FILL)
            click = Gtk.GestureClick()
            click.connect("pressed", self.on_horse_click)
            self.picture.add_controller(click)
            self.fixed.put(self.picture, -core.HORSE_W, STRIP_H - core.HORSE_H - GROUND)

            self.bubble = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            self.bubble.add_css_class("bubble")
            self.label = Gtk.Label(wrap=True, max_width_chars=38, xalign=0)
            self.button = Gtk.Button()
            self.button.connect("clicked", self.on_action)
            self.bubble.append(self.label)
            self.bubble.append(self.button)
            self.bubble.set_visible(False)
            self.fixed.put(self.bubble, 0, 0)

            win.set_child(self.fixed)
            self.win = win
            self.horse = None
            self.shown_msg = None
            win.present()
            self.last = time.monotonic()
            GLib.timeout_add(TICK_MS, self.on_tick)

        def close_window(self):
            if self.win is not None:
                self.win.destroy()
            self.win = None
            self.horse = None

        # ── events ──
        def on_horse_click(self, *_args):
            if self.horse is not None:
                self.horse.click()

        def on_action(self, _button):
            msg = self.horse.bubble if self.horse else None
            if msg and msg.command:
                subprocess.Popen(["sh", "-c", msg.command], start_new_session=True,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if self.horse:
                self.horse.bubble = None

        # ── animation ──
        def on_tick(self):
            if self.win is None:
                return False
            width = self.win.get_width()
            if width <= 0:
                return True  # not mapped yet
            now = time.monotonic()
            dt, self.last = min(0.2, now - self.last), now
            if self.horse is None:
                self.horse = core.Horse(width=width, rng=rng)
                self.horse.start_visit(self.pending)
                self.pending = None
            self.horse.width = width
            self.horse.step(dt)
            if not self.horse.visible:
                self.close_window()
                return False
            self.draw()
            return True

        def draw(self):
            h = self.horse
            tex = self.textures.get(h.frame_name())
            if tex is not None:
                self.picture.set_paintable(tex)
            hx, hy = int(h.x), STRIP_H - core.HORSE_H - GROUND
            self.fixed.move(self.picture, hx, hy)
            rects = [(hx, hy, core.HORSE_W, core.HORSE_H)]

            if h.bubble is not None:
                if h.bubble is not self.shown_msg:
                    self.shown_msg = h.bubble
                    self.label.set_text(h.bubble.text)
                    self.button.set_visible(bool(h.bubble.command))
                    self.button.set_label(h.bubble.action_label or "")
                self.bubble.set_visible(True)
                _, bw, _, _ = self.bubble.measure(Gtk.Orientation.HORIZONTAL, -1)
                _, bh, _, _ = self.bubble.measure(Gtk.Orientation.VERTICAL, bw)
                bx = max(8, min(int(h.x + core.HORSE_W / 2 - bw / 2), self.win.get_width() - bw - 8))
                by = max(0, hy - bh - 6)
                self.fixed.move(self.bubble, bx, by)
                rects.append((bx, by, bw, bh))
            else:
                self.shown_msg = None
                self.bubble.set_visible(False)

            surface = self.win.get_surface()
            if surface is not None:
                region = cairo.Region([cairo.RectangleInt(x, y, w, hh) for x, y, w, hh in rects])
                surface.set_input_region(region)

    if not LayerShell.is_supported():
        print("sigurd: this compositor has no layer-shell support", file=sys.stderr)
        return 1
    return App().run([sys.argv[0]])


def main() -> int:
    if len(sys.argv) > 1:
        return client(sys.argv[1:])
    return run()


if __name__ == "__main__":
    sys.exit(main())
