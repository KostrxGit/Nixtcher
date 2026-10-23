-- Sunrise / sunset (NOAA approximation), returned as local minutes after midnight.
local M = {}

local rad, deg = math.rad, math.deg

local function utcOffsetMinutes(t: number): number
  local l = os.date("*t", t) :: any
  local u = os.date("!*t", t) :: any
  l.isdst = false
  return math.floor(os.difftime(os.time(l), os.time(u)) / 60 + 0.5)
end

-- Returns sunriseMin, sunsetMin (local time), or nil when the sun does not rise/set.
function M.times(lat: number, lon: number, t: number?): (number?, number?)
  local now = t or os.time()
  local d = os.date("*t", now) :: any
  local doy = d.yday
  local gamma = 2 * math.pi / 365 * (doy - 1 + 0.5)
  local eqtime = 229.18 * (0.000075 + 0.001868 * math.cos(gamma) - 0.032077 * math.sin(gamma)
    - 0.014615 * math.cos(2 * gamma) - 0.040849 * math.sin(2 * gamma))
  local decl = 0.006918 - 0.399912 * math.cos(gamma) + 0.070257 * math.sin(gamma)
    - 0.006758 * math.cos(2 * gamma) + 0.000907 * math.sin(2 * gamma)
    - 0.002697 * math.cos(3 * gamma) + 0.00148 * math.sin(3 * gamma)
  local cosHa = math.cos(rad(90.833)) / (math.cos(rad(lat)) * math.cos(decl)) - math.tan(rad(lat)) * math.tan(decl)
  if cosHa > 1 or cosHa < -1 then
    return nil, nil
  end
  local ha = deg(math.acos(cosHa))
  local offset = utcOffsetMinutes(now)
  local sunrise = 720 - 4 * (lon + ha) - eqtime + offset
  local sunset = 720 - 4 * (lon - ha) - eqtime + offset
  return sunrise, sunset
end

-- "dawn" | "day" | "dusk" | "night" for the given time.
function M.period(lat: number, lon: number, t: number?): string
  local now = t or os.time()
  local d = os.date("*t", now) :: any
  local m = d.hour * 60 + d.min
  local rise, set = M.times(lat, lon, now)
  if rise == nil or set == nil then
    -- polar day/night: fall back to the clock
    return if m >= 7 * 60 and m < 19 * 60 then "day" else "night"
  end
  if m >= rise - 40 and m < rise + 50 then
    return "dawn"
  elseif m >= rise + 50 and m < set - 70 then
    return "day"
  elseif m >= set - 70 and m < set + 35 then
    return "dusk"
  end
  return "night"
end

return M
