-- Settings written by Nix next to plugin.toml (config.json): binary paths,
-- code folders, coordinates and the four wallpaper variants.
local dir = noctalia.pluginDir()
local raw = noctalia.readFile(if dir then dir .. "/config.json" else "config.json")
local cfg = if raw then noctalia.json.decode(raw) else nil
if type(cfg) ~= "table" then
  noctalia.log("kaer-morhen: config.json missing or invalid, using defaults")
  cfg = {}
end
cfg.codeDirs = cfg.codeDirs or {}
cfg.wallpapers = cfg.wallpapers or {}
return cfg
