-- Step through Omarchy's numbered slots, including empty workspaces.
function o.workspaces.swipe_step(delta)
  local monitor = hl.get_active_monitor()
  local current = monitor and monitor.active_workspace
  if not current or current.id < 1 then return end

  local slots = o.workspaces.slots
  local slot = current.id - o.workspaces.workspace_id(monitor, 1) + 1
  if slot < 1 or slot > slots then return end

  local target = slot + delta
  if target >= 1 and target <= slots then
    o.workspaces.focus(target, monitor.name)()
  end
end

local horizontal_travel = 0
local function accumulate_horizontal(event)
  horizontal_travel = horizontal_travel + event.delta.x
end

hl.gesture({
  fingers = 4, direction = "horizontal",
  action = {
    start = function(event) horizontal_travel = event.delta.x end,
    update = accumulate_horizontal,
    finish = function(event)
      local travel = horizontal_travel
      horizontal_travel = 0
      if not event.cancelled and math.abs(travel) >= 35 then
        o.workspaces.swipe_step(travel < 0 and 1 or -1)
      end
    end,
  },
})
hl.gesture({
  fingers = 4, direction = "up",
  action = function() hl.exec_cmd("omarchy-shell omarchy.dock overviewOpen") end,
})
hl.gesture({
  fingers = 4, direction = "down",
  action = function() hl.exec_cmd("omarchy-shell omarchy.dock overviewClose") end,
})
