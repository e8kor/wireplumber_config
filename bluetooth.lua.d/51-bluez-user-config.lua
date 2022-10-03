local rule_trekz = {
  matches = {
    {
      { "node.name", "equals", "bluez_output.20_74_CF_34_ED_F7.a2dp-sink" },
    },
    {
      { "node.name", "equals", "bluez_output.20_74_CF_34_ED_F7.headset-head-unit" },
    },
  },
  apply_properties = {
    ["node.nick"] = "Trekz Headset",
    ["media.user.target.role"] = "work-hub;comm-hub;media-hub",
  },
}

local rule_philips = {
  matches = {
    {
      { "node.name", "equals", "bluez_output.58_17_C1_07_48_52.a2dp-sink" },
    },
  },
  apply_properties = {
    ["node.nick"] = "Philips Headset",
    ["media.user.target.role"] = "work-hub;comm-hub;media-hub",
  },
}

local rule_bose = {
  matches = {
    {
      { "node.name", "equals", "bluez_output.4C_87_5D_28_F6_91.a2dp-sink" },
    },
  },
  apply_properties = {
    ["node.nick"] = "Bose Headset",
    ["media.user.target.role"] = "work-hub;comm-hub;media-hub",
  },
}

table.insert(bluez_monitor.rules, rule_philips)
table.insert(bluez_monitor.rules, rule_trekz)
table.insert(bluez_monitor.rules, rule_bose)

local rule_disable = {
  matches = {
    {
      { "node.name", "equals", "bluez_input.20_74_CF_34_ED_F7.headset-head-unit" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  },
}

table.insert(bluez_monitor.rules, rule_disable)
