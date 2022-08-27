local rule_soundux = {
  matches = {
    {
      { "node.name", "equals", "soundux_sink" },
    },
  },
  apply_properties = {
    ["node.autoconnect"] = false,
    ["node.description"] = "Soundux Application",
    ["node.nick"]        = "soundux",
    ["media.user.role"]  = "soundboard",
  },
}

table.insert(default_policy.rules, rule_soundux)