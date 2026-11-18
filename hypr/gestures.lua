-- Include empty Omarchy slots and any other native desktops on this output.
function o.workspaces.swipe_step(delta)
  local monitor = hl.get_active_monitor()
  local current = monitor and monitor.active_workspace
  if not current or current.special then return end

  local ids, seen = {}, {}
  local function add(id)
    if not seen[id] then
      seen[id] = true
      ids[#ids + 1] = id
    end
  end
  for slot = 1, o.workspaces.slots do add(o.workspaces.workspace_id(monitor, slot)) end
  for _, workspace in ipairs(hl.get_workspaces()) do
    if not workspace.special and workspace.monitor and workspace.monitor.name == monitor.name then add(workspace.id) end
  end
  table.sort(ids, function(a, b)
    if a > 0 and b < 0 then return true end
    if a < 0 and b > 0 then return false end
    if a < 0 then return a > b end
    return a < b
  end)
  for index, id in ipairs(ids) do
    if id == current.id and ids[index + delta] then
      local target = ids[index + delta]
      local slot = target - o.workspaces.workspace_id(monitor, 1) + 1
      if target > 0 and slot >= 1 and slot <= o.workspaces.slots then
        o.workspaces.focus(slot, monitor.name)()
      elseif o.spaces then
        o.spaces.focus(target)
      end
      return
    end
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
