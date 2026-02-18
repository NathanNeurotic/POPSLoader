local function Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function Round(value)
  return math.floor(value + 0.5)
end

local function ResolveDelta(state, dt_or_timer_time)
  if type(dt_or_timer_time) == "number" then
    return dt_or_timer_time
  end
  if state.timer == nil then
    state.timer = Timer.new()
  end
  local now = Timer.getTime(state.timer)
  local last = state.last_time or now
  state.last_time = now
  return now - last
end

local Transition = {}

function Transition.new(hooks, options)
  hooks = hooks or {}
  options = options or {}

  local state = {
    active = false,
    phase = "out",
    target = nil,
    args = nil,
    allow_scene_write = false,
    timer = nil,
    elapsed = 0,
    last_time = nil,
    max_step = options.max_step or 33,
    duration_out = options.duration_out or 350,
    duration_in = options.duration_in or 350,
    alpha = 0
  }

  local instance = {}

  function instance.request(next_scene_id, optional_args)
    if next_scene_id == nil then return end
    if hooks.get_scene ~= nil and next_scene_id == hooks.get_scene() then return end
    if state.active == true then return end

    state.active = true
    state.phase = "out"
    state.target = next_scene_id
    state.args = optional_args
    state.elapsed = 0
    state.last_time = nil
    state.alpha = 0
  end

  function instance.update(dt_or_timer_time)
    if not state.active then
      state.alpha = 0
      return 0
    end

    local delta = ResolveDelta(state, dt_or_timer_time)
    if delta < 0 then delta = 0 end
    delta = Clamp(delta, 0, state.max_step)
    state.elapsed = state.elapsed + delta

    local duration = state.phase == "out" and state.duration_out or state.duration_in
    if duration <= 0 then duration = 1 end
    local t = Clamp(state.elapsed / duration, 0, 1)
    local alpha = state.phase == "out" and Round(128 * t) or Round(128 * (1 - t))

    if t >= 1 then
      if state.phase == "out" then
        local previous_scene = hooks.get_scene ~= nil and hooks.get_scene() or nil
        if hooks.on_scene_exit ~= nil then
          hooks.on_scene_exit(previous_scene, state.target)
        end

        if hooks.set_last_scene ~= nil then
          hooks.set_last_scene(previous_scene)
        end

        state.allow_scene_write = true
        if hooks.set_scene ~= nil then
          hooks.set_scene(state.target)
        end
        state.allow_scene_write = false

        local next_scene = hooks.get_scene ~= nil and hooks.get_scene() or state.target
        if hooks.on_scene_enter ~= nil then
          hooks.on_scene_enter(previous_scene, next_scene)
        end

        state.phase = "in"
        state.elapsed = 0
        state.last_time = nil
        alpha = 128
      else
        state.active = false
        state.target = nil
        state.args = nil
        alpha = 0
      end
    end
    state.alpha = alpha
    return alpha
  end

  function instance.reset()
    state.active = false
    state.phase = "out"
    state.target = nil
    state.args = nil
    state.allow_scene_write = false
    state.elapsed = 0
    state.last_time = nil
    state.alpha = 0
  end

  function instance.drawOverlay()
    if not state.active then
      return
    end
    local alpha = instance.update()
    if alpha > 0 then
      Graphics.drawRect(0, 0, UI.SCR.X, UI.SCR.Y, Color.new(0, 0, 0, alpha))
    end
  end

  function instance.isSceneWriteAllowed()
    return state.allow_scene_write
  end

  setmetatable(instance, {
    __index = function(_, key)
      if key == "active" then
        return state.active
      end
      return nil
    end
  })

  return instance
end

return Transition
