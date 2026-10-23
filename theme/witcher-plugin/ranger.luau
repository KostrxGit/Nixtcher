--!nonstrict
-- Control-centre tile: Ranger mode for long sessions on battery
-- (power saver, dimmer screen, a calmer pup). The label shows battery health.

local function render()
  local on = noctalia.state.get("km.ranger") == true
  local health = noctalia.state.get("km.health")
  shortcut.setLabel(if health then `Ranger · {health}%` else "Ranger")
  shortcut.setIcon("trekking")
  shortcut.setActive(on)
end

noctalia.state.watch("km.ranger", render)
noctalia.state.watch("km.health", render)

function onClick()
  noctalia.state.set("km.cmd", { op = "ranger", seq = noctalia.nowMs() })
end

render()
