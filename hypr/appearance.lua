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
