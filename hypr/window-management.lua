-- Hyprland can focus a maximized floating window while still painting another
-- window over it. Reapply maximize after restacking so it remains full-width.
function o.raise_and_focus_window(window)
  if not window then return end

  if window.floating and window.fullscreen == 1 then
    hl.dispatch(hl.dsp.window.fullscreen({
      window = window, mode = "maximized", action = "unset", layout_aware = false,
    }))
    hl.dispatch(hl.dsp.window.alter_zorder({ window = window, mode = "top" }))
    hl.dispatch(hl.dsp.window.fullscreen({
      window = window, mode = "maximized", action = "set", layout_aware = false,
    }))
  else
    hl.dispatch(hl.dsp.window.alter_zorder({ window = window, mode = "top" }))
  end
  hl.dispatch(hl.dsp.focus({ window = window }))
end

-- Clicking an exposed part of a maximized floating window can focus it
-- before Hyprland updates the draw order. Restack after the click is handled.
local restacking_focused_window = false
hl.on("window.active", function(window)
  if restacking_focused_window or not window or not window.floating or window.fullscreen ~= 1 then
    return
  end

  local address = window.address
  hl.timer(function()
    local active = hl.get_active_window()
    if not active or active.address ~= address or not active.floating or active.fullscreen ~= 1 then
      return
    end
    restacking_focused_window = true
    o.raise_and_focus_window(active)
    restacking_focused_window = false
  end, { type = "oneshot", timeout = 1 })
end)

function o.cycle_and_raise_window()
  hl.dispatch(hl.dsp.window.cycle_next())
  o.raise_and_focus_window(hl.get_active_window())
end

o.rebind("ALT + TAB", "Focus next window and bring it forward", o.cycle_and_raise_window)

-- Hyprland has one maximize/fullscreen owner per workspace. Keep a displaced
-- floating maximized window at its on-screen geometry until that owner exits.
local preserved_maximum = {}

local function restore_displaced_maximum(owner)
  local saved = preserved_maximum[owner.address]
  if not saved then return end
  preserved_maximum[owner.address] = nil
  hl.timer(function()
    local peer = hl.get_window("address:" .. saved.address)
    if not peer or not peer.workspace or peer.workspace.id ~= saved.workspace
      or not peer.floating or peer.fullscreen ~= 0 then return end
    for _, window in ipairs(hl.get_workspace_windows(tostring(saved.workspace))) do
      if window.fullscreen ~= 0 then return end
    end
    if saved.normal then
      hl.dispatch(hl.dsp.window.resize({ window = peer, x = saved.normal.width, y = saved.normal.height }))
      hl.dispatch(hl.dsp.window.move({ window = peer, x = saved.normal.x, y = saved.normal.y }))
    end
    hl.dispatch(hl.dsp.window.fullscreen({
      window = peer, mode = "maximized", action = "set", layout_aware = false,
    }))
  end, { type = "oneshot", timeout = 25 })
end

hl.on("window.fullscreen", function(window)
  if window.fullscreen < 2 then restore_displaced_maximum(window) end
end)

hl.on("window.close", restore_displaced_maximum)

function o.fullscreen_preserving_peers()
  local selected = hl.get_active_window()
  if not selected or not selected.workspace then return end

  local workspace = selected.workspace.id
  if selected.fullscreen < 2 then
    for _, peer in ipairs(hl.get_workspace_windows(tostring(workspace))) do
      if peer.address ~= selected.address and peer.floating and peer.fullscreen == 1 then
        preserved_maximum[selected.address] = {
          address = peer.address, workspace = workspace,
          x = peer.at.x, y = peer.at.y, width = peer.size.x, height = peer.size.y,
        }
        break
      end
    end
  end

  hl.dispatch(hl.dsp.window.fullscreen({
    window = selected, mode = "fullscreen", layout_aware = false,
  }))

  local saved = preserved_maximum[selected.address]
  if not saved then return end
  local peer = hl.get_window("address:" .. saved.address)
  if peer and peer.fullscreen == 0 then
    saved.normal = { x = peer.at.x, y = peer.at.y, width = peer.size.x, height = peer.size.y }
    hl.dispatch(hl.dsp.window.resize({ window = peer, x = saved.width, y = saved.height }))
    hl.dispatch(hl.dsp.window.move({ window = peer, x = saved.x, y = saved.y }))
  end
end

o.rebind("SUPER + F", "Full screen", o.fullscreen_preserving_peers)
