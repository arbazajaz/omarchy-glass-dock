-- Native Hyprland workspaces created from the Glass Dock overview.
o.spaces = {}

local state_dir = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/omarchy"
local state_file = state_dir .. "/glass-dock-spaces"
local managed = {}

local function name_for(serial)
  return "Glass-Space-" .. serial
end

local function create(serial)
  local name = name_for(serial)
  managed[name] = hl.workspace_rule({ workspace = "name:" .. name, persistent = true })
  return name
end

local function save()
  local file = io.open(state_file .. ".tmp", "w")
  if not file then return false end
  for name in pairs(managed) do
    file:write(name:match("(%d+)$"), "\n")
  end
  if not file:close() then return false end
  return os.rename(state_file .. ".tmp", state_file) ~= nil
end

local file = io.open(state_file, "r")
if file then
  for line in file:lines() do
    local serial = tonumber(line:match("^(%d+)$"))
    if serial and serial >= 1 and serial <= 9999 and not managed[name_for(serial)] then create(serial) end
  end
  file:close()
end

local function selector(id)
  local workspace = hl.get_workspace(id)
  if workspace and workspace.special then return end
  if id > 0 then return tostring(id) end
  if workspace then return "name:" .. workspace.name end
end

local function notify(message)
  hl.notification.create({ text = message, timeout = 3500 })
end

function o.spaces.focus(id)
  local destination = selector(id)
  if destination then hl.dispatch(hl.dsp.focus({ workspace = destination })) end
end

function o.spaces.add()
  local serial = 1
  while serial <= 9999 and (managed[name_for(serial)] or hl.get_workspace("name:" .. name_for(serial))) do
    serial = serial + 1
  end
  if serial > 9999 then return end
  local name = create(serial)
  if not save() then notify("This Space could not be saved for the next session.") end
  hl.dispatch(hl.dsp.focus({ workspace = "name:" .. name }))
end

function o.spaces.move(address, id)
  local destination = selector(id)
  local window = hl.get_window("address:" .. address)
  if not window or not destination or (window.workspace and window.workspace.id == id) then return end
  hl.dispatch(hl.dsp.window.move({ window = window, workspace = destination, follow = false }))
end

function o.spaces.remove(id, destination_id, allow_move)
  local workspace = hl.get_workspace(id)
  if not workspace or not managed[workspace.name] or id == destination_id then return end
  local name = workspace.name
  local source = "name:" .. name
  local destination = selector(destination_id)
  if not destination then return end

  local windows = hl.get_workspace_windows(source)
  if #windows > 0 and not allow_move then
    notify("This Space has open windows. Confirm before moving them.")
    return
  end
  for _, window in ipairs(windows) do
    if not window.workspace or window.workspace.id ~= id then return end
    hl.dispatch(hl.dsp.window.move({ window = window, workspace = destination, follow = false }))
  end
  if #hl.get_workspace_windows(source) ~= 0 then
    notify("Some windows could not move. The Space was kept.")
    return
  end

  local rule = managed[name]
  managed[name] = nil
  if not save() then
    managed[name] = rule
    notify("The Space could not be removed from saved settings.")
    return
  end
  if hl.get_active_workspace() and hl.get_active_workspace().id == id then
    hl.dispatch(hl.dsp.focus({ workspace = destination }))
  end
  rule:set_enabled(false)
end
