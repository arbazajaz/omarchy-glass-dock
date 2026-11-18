-- Change the default Omarchy look'n'feel.

-- Opt another application in to Omarchy's standard transparency.
-- Find its class with: hyprctl clients
-- o.transparent_window("my-app")
-- o.transparent_window("my-app", "0.9 0.85") -- Custom active/inactive opacity.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Frost the dock while leaving its transparent input area and shadow clear.
hl.layer_rule({
  match = { namespace = "^omarchy-dock$" },
  blur = true,
  ignore_alpha = 0.12,
})

hl.layer_rule({
  match = { namespace = "^omarchy-dock-plain$" },
  no_anim = true,
})

-- Blur the full-screen launcher and overview using the existing glass settings.
hl.layer_rule({
  match = { namespace = "^(omarchy-dock-apps|omarchy-mission-control)$" },
  blur = true,
  ignore_alpha = 0.20,
  no_anim = true,
})
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.8, bezier = "easeOutQuint", style = "slide" })

-- Light compositor-native window motion. Omarchy's global animation toggle
-- still controls whether these animations play.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.6, bezier = "easeOutQuint", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.2, bezier = "easeOutQuint", style = "popin 90%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.8, bezier = "easeOutQuint" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.0, bezier = "almostLinear" })
