# Noctalia 5: bar, launcher, control centre, notifications, OSD, wallpaper,
# lock screen and idle — one shell instead of Waybar/Fuzzel/Mako/hyprlock/swaybg/swayidle.
#
# This file is the base config. Changes made in Noctalia's own Settings window are saved to
# ~/.local/state/noctalia/settings.toml and override this file; delete that file to reset.
{ config, settings, ... }:
let
  palette = import ../../theme/palette.nix;
  hex = v: "#${v}";

  # Palette in Noctalia's colour roles
  toNoctalia =
    p:
    with builtins.mapAttrs (_: hex) (removeAttrs p [ "scheme" "author" ]);
    {
      mPrimary = accent; # amber
      mOnPrimary = onAccent;
      mSecondary = base04; # steel
      mOnSecondary = base00;
      mTertiary = base09; # orange
      mOnTertiary = base00;
      mError = base08;
      mOnError = base00;
      mSurface = base00;
      mOnSurface = base05;
      mSurfaceVariant = base01;
      mOnSurfaceVariant = base04;
      mOutline = base02;
      mShadow = shadow;
      mHover = hover;
      mOnHover = base05;
      terminal = {
        foreground = base05;
        background = base00;
        cursor = accent;
        cursorText = base00;
        selectionFg = base06;
        selectionBg = hover;
        normal = {
          black = base00;
          red = base08;
          green = base0B;
          yellow = base0A;
          blue = base0D;
          magenta = base0E;
          cyan = base0C;
          white = base05;
        };
        bright = {
          black = base03;
          red = base08;
          green = base0B;
          yellow = base0A;
          blue = base0D;
          magenta = base0E;
          cyan = base0C;
          white = base07;
        };
      };
    };

  fonts = config.stylix.fonts;
  dark = config.stylix.polarity == "dark";
  # Thin light edge on glass panels (solid hex; Noctalia's panel border takes no alpha)
  glassBorder = if dark then "#4A5466" else "#FFFFFF";

  # Liquid-glass card behind desktop widgets (Niri blurs what's under it)
  glassCard = {
    background = true;
    background_color = "surface";
    background_opacity = 0.42;
    background_radius = 24.0;
    background_padding = 16.0;
    font_family = fonts.sansSerif.name;
  };
in
{
  stylix.targets.noctalia.enable = false; # palette mapped by hand above (amber accent)

  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    # "witcher" is the School of the Wolf; km-cat / km-griffin / km-bear only change the accent
    customPalettes =
      let
        schools = import ../../theme/schools.nix;
        mk = school: {
          dark = toNoctalia (palette.dark // schools.${school}.dark);
          light = toNoctalia (palette.light // schools.${school}.light);
        };
      in
      {
        witcher = mk "wolf";
        km-cat = mk "cat";
        km-griffin = mk "griffin";
        km-bear = mk "bear";
      };

    settings = {
      shell = {
        font_family = fonts.sansSerif.name;
        corner_radius_scale = 1.5;
        time_format = "{:%H:%M}";
        date_format = "%A, %d %B";
        telemetry_enabled = false;
        niri_overview_type_to_launch_enabled = true; # start typing in the overview to launch
        settings_show_advanced = true;
        setup_wizard_enabled = false; # palette, mode and wallpaper are set here, not by the wizard

        shadow = {
          direction = "down";
          alpha = 0.45;
        };
        # Liquid glass: translucent panels and cards, a thin light edge, blur from Niri
        panel = {
          transparency_mode = "glass";
          borders = true;
          border_color = glassBorder;
          border_width = 1.0;
          shadow = true;
          launcher_placement = "floating";
          launcher_position = "center";
          control_center_placement = "floating";
          clipboard_placement = "floating";
        };
        launcher = {
          layout = "full";
          width = 760;
          default_view = "recent";
          pinned = [
            "google-chrome"
            "code"
            "com.mitchellh.ghostty"
            "org.gnome.Nautilus"
          ];
        };
      };

      theme = {
        mode = if dark then "dark" else "light"; # follows `theme light|dark`
        source = "custom";
        custom_palette = "witcher";
      };

      wallpaper = {
        enabled = true;
        fill_mode = "crop";
        transition = [ "fade" ];
        transition_duration = 900;
        default.path = "${config.stylix.image}";
      };

      # Blurred copy of the wallpaper behind Niri's overview
      backdrop = {
        enabled = true;
        blur_intensity = 0.6;
        tint_intensity = 0.35;
      };

      notification = {
        background_opacity = 0.72;
        border_color = glassBorder;
        offset_x = 16;
        offset_y = 10;
      };

      osd = {
        position = "top_center";
        background_opacity = 0.72;
        border_color = glassBorder;
      };

      lockscreen = {
        enabled = true;
        transition = [ "fade" ];
        transition_duration = 600;
        blur_intensity = 0.8;
        tint_intensity = 0.35;
      };

      # Pup naps at 2 min (kaer-morhen.nix), lock at 10, screen off at 15, lock + suspend at 30.
      # No dimming fade: Noctalia would also fade the screen before the pup's nap.
      idle = {
        pre_action_fade_seconds = 0.0;
        behavior_order = [
          "pup-nap"
          "lock"
          "screen-off"
          "suspend"
        ];
        behavior = {
          lock = {
            timeout = 600;
            action = "lock";
            enabled = true;
          };
          screen-off = {
            timeout = 900;
            action = "screen_off";
            enabled = true;
          };
          suspend = {
            timeout = 1800;
            action = "lock_and_suspend";
            enabled = true;
          };
        };
      };

      # Short floating glass pill in the middle of the top edge.
      # Its length = screen width minus margin_ends on each side. Too short or too long?
      # Change the two margin_ends numbers (laptop below, any external monitor above).
      bar.main = {
        position = "top";
        thickness = 32;
        background_opacity = 0.45;
        compositor_blur = true;
        border = glassBorder; # thin light glass edge
        border_width = 1.0;
        radius = 16; # fully round ends
        margin_ends = 640; # external monitor
        margin_edge = 8;
        padding = 10;
        widget_spacing = 4;
        shadow = true;
        capsule = false;
        # Wolf medallion (launcher), workspaces, then the pup's track up to the clock
        start = [
          "medallion"
          "workspaces"
          "pup"
        ];
        center = [ "clock" ];
        end = [
          "tray"
          "group:status"
          "control-center"
        ];
        # Wi-Fi, sound and battery share one small frosted pill
        capsule_group = [
          {
            id = "status";
            members = [
              "network"
              "volume"
              "battery"
            ];
            fill = "surface_variant";
            opacity = 0.55;
            padding = 8.0;
            widget_spacing = 10;
          }
        ];
        monitor.laptop = {
          match = "eDP-1";
          margin_ends = 430;
        };
      };

      widget = {
        # Small dots; the active workspace becomes an amber pill with its app icon
        workspaces = {
          style = "focus_hint";
          show_labels = false;
          show_icons = true;
          focused_color = "primary";
          occupied_color = "on_surface_variant";
          empty_color = "outline";
          urgent_color = "error";
        };
        clock = {
          format = "{:%H:%M}";
          tooltip_format = "{:%A, %d %B %Y}";
          font_family = fonts.serif.name;
          font_weight = 600;
        };
        # School medallions: Wolf opens the launcher, Griffin the control centre
        launcher = {
          custom_image = "${../../theme/icons/wolf.png}";
          custom_image_colorize = false;
        };
        control-center = {
          custom_image = "${../../theme/icons/griffin.png}";
          custom_image_colorize = false;
        };
        # Status pill: Wi-Fi glyph only (name and signal in the tooltip), no VPN shield,
        # speaker without a number, battery drawn as a small battery with the % inside it
        network = {
          show_label = false;
          vpn_status = "hidden";
        };
        volume.show_label = false;
        battery = {
          display_mode = "graphic";
          show_label = true;
        };
        # Tray apps tuck behind one small button instead of a row of mismatched icons
        tray = {
          drawer = true;
          drawer_columns = 3;
        };
      };

      dock.enabled = false;

      # Weather for the lock screen card and the control centre (Open-Meteo, no account)
      location = {
        auto_locate = false;
        address = settings.city;
      };
      weather = {
        enabled = true;
        unit = "metric";
        refresh_minutes = 30;
        effects = true;
      };

      # Calendar: the month grid works with no account. To see Outlook/Teams events, add the
      # calendar in Settings → Calendar → Accounts → Add Account → ICS URL (kept out of git).
      calendar = {
        enabled = true;
        event_date_format = "%A %e %B";
        event_time_format = "%H:%M";
        reminders = {
          enabled = true;
          default_lead_minutes = 10;
          all_day_digest_time = "08:30";
        };
      };

      # ── Desktop widgets (visible on an empty workspace) ──────────────────────────
      # Positions are the card centres in logical pixels on the 1536×960 laptop screen
      # (Noctalia rescales them on other monitors). Cards sit 32px from the screen edges and
      # keep clear of the tower (left) and Geralt (bottom right) in the wallpaper. Fine-tune by dragging: Settings → Desktop → Toggle Editor
      # (what you drag is saved to settings.toml and wins over this file).
      desktop_widgets = {
        enabled = true;
        widget = {
          # Calendar card, top right. The events list beside the grid is off until a
          # calendar account is added (then set show_events = true and move cx left ~140).
          calendar = {
            type = "calendar";
            cx = 1315.0;
            cy = 275.0;
            settings = glassCard // {
              show_events = false;
              show_week_numbers = true;
            };
          };

          # Vitals, bottom left: CPU load + temperature graph, with the RAM and GPU
          # gauges underneath, aligned to the graph's left and right edges
          vitals-cpu = {
            type = "sysmon";
            cx = 138.0;
            cy = 802.0;
            settings = glassCard // {
              display = "graph";
              stat = "cpu_usage";
              stat2 = "cpu_temp";
              color = "primary";
              color2 = "tertiary"; # orange line for temperature
              show_label = true;
              shadow = false;
            };
          };
          vitals-ram = {
            type = "sysmon";
            cx = 75.0;
            cy = 905.0;
            settings = glassCard // {
              display = "gauge";
              stat = "ram_pct";
              gauge_layout = "horizontal";
              color = "primary";
              highlight_color = "error";
              shadow = false;
            };
          };
          vitals-gpu = {
            type = "sysmon";
            cx = 201.0;
            cy = 905.0;
            settings = glassCard // {
              display = "gauge";
              stat = "gpu_usage";
              gauge_layout = "horizontal";
              color = "secondary";
              highlight_color = "error";
              shadow = false;
            };
          };

          # The Forge: running Docker containers and their ports, bottom centre on the path
          forge = {
            type = "konstanty/kaer-morhen:forge";
            cx = 700.0;
            cy = 860.0;
            settings = removeAttrs glassCard [ "font_family" ];
          };

          # Contract board: your Claude task cards, left side above the vitals
          # (plugin widget from kaer-morhen.nix)
          contracts = {
            type = "konstanty/kaer-morhen:contracts";
            cx = 192.0;
            cy = 590.0;
            settings = removeAttrs glassCard [ "font_family" ];
          };
        };
      };

      # ── Lock screen ──────────────────────────────────────────────────────────────
      # Wolf medallion, big Cinzel clock and the date above the password card;
      # the password card below shows weather, what's playing and power buttons.
      # Rearrange: Settings → Security → Lock screen → Toggle Editor.
      lockscreen_widgets = {
        enabled = true;
        widget = {
          medallion = {
            type = "sticker";
            cx = 768.0;
            cy = 130.0;
            box_width = 96.0;
            box_height = 96.0;
            settings = {
              image_path = "${../../theme/icons/wolf.png}";
              opacity = 0.92;
              background = false;
            };
          };
          time = {
            type = "clock";
            cx = 768.0;
            cy = 265.0;
            box_width = 440.0;
            box_height = 150.0;
            settings = {
              clock_style = "digital";
              format = "{:%H:%M}";
              center_text = true;
              font_family = fonts.serif.name;
              color = "on_surface";
              shadow = true;
              background = false;
            };
          };
          # The pup meditating by a campfire (animated)
          campfire = {
            type = "sticker";
            cx = 768.0;
            cy = 520.0;
            box_width = 216.0;
            box_height = 132.0;
            settings = {
              image_path = "${../../theme/witcher-plugin/assets/pup/campfire.gif}";
              opacity = 0.95;
              background = false;
            };
          };
          date = {
            type = "clock";
            cx = 768.0;
            cy = 362.0;
            box_width = 380.0;
            box_height = 38.0;
            settings = {
              clock_style = "digital";
              format = "{:%A, %d %B}";
              center_text = true;
              color = "on_surface_variant";
              shadow = true;
              background = false;
            };
          };
        };
      };
    };
  };
}
