local rule_soundux = {
  matches = {
    {
      { "item.node.name", "equals", "soundux_sink" },
    },
  },
  apply_properties = {
    ["node.autoconnect"]               = false,
    ["node.description"]               = "Soundux Application",
    ["media.user.role"]                = "soundboard",
  },
}

table.insert(default_policy.rules, rule_soundux)