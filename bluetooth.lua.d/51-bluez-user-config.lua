local rule_trekz = {
    matches = {
      {
        { "node.name", "equals", "bluez_output.20_74_CF_34_ED_F7.a2dp-sink" },
      },
    },
    apply_properties = {
      ["node.description"] = "Trekz Headset",
      ["node.nick"] = "headset_aftershokz",
      ["node.autoconnect"] = true,
      ["user.managed"] = true,
      ["user.node.target"] = "cable-a-source",
    },
  }

  local rule_bose = {
    matches = {
      {
        { "node.name", "equals", "bluez_output.4C_87_5D_28_F6_91.a2dp-sink" },
      },
    },
    apply_properties = {
      ["node.description"] = "Onyx Headset",
      ["node.nick"] = "headset_bose",
      ["node.autoconnect"] = true,
      ["user.managed"] = true,
      ["user.node.target"] = "cable-a-source",
    },
  }

table.insert(bluez_monitor.rules, rule_trekz)
table.insert(bluez_monitor.rules, rule_bose)