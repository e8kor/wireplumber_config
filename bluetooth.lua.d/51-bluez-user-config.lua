local rule_trekz = {
    matches = {
      {
        { "node.name", "equals", "bluez_output.20_74_CF_34_ED_F7.a2dp-sink" },
      },
    },
    apply_properties = {
      ["node.name"] = "Trekz Headset",
      ["media.user.target.role"] = "work;comm;media;soundboard",
    },
  }

  local rule_bose = {
    matches = {
      {
        { "node.name", "equals", "bluez_output.4C_87_5D_28_F6_91.a2dp-sink" },
      },
    },
    apply_properties = {
      ["node.name"] = "Bose Headset",
      ["media.user.target.role"] = "work;comm;media;soundboard",
    },
  }

table.insert(bluez_monitor.rules, rule_trekz)
table.insert(bluez_monitor.rules, rule_bose)