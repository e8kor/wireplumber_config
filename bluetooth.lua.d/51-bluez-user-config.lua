local rule_trekz = {
  matches = {
    {
      { "node.name", "equals", "bluez_output.20_74_CF_34_ED_F7.a2dp-sink" },
    },
    {
      { "node.name", "equals", "bluez_output.20_74_CF_34_ED_F7.headset-head-unit" },
    },
    {
      { "node.name", "equals", "bluez_input.20_74_CF_34_ED_F7.headset-head-unit" },
    }
  },
  apply_properties = {
    ["node.nick"] = "Trekz Headset",
    ["media.target.tag"] = "work-hub;comm-hub;media-hub",
  },
}

local rule_apple_air_pro = {
  matches = {
    {
      { "node.name", "equals", "bluez_output.2C_76_00_CC_20_01.a2dp-sink" },
    },
    {
      { "node.name", "equals", "bluez_output.2C_76_00_CC_20_01.headset-head-unit" },
    },
    {
      { "node.name", "equals", "bluez_input.2C_76_00_CC_20_01.headset-head-unit" },
    },
  },
  apply_properties = {
    ["node.nick"] = "Apple AirPods Pro",
    ["media.target.tag"] = "work-hub;comm-hub;media-hub",
  },
}

local rule_philips = {
  matches = {
    {
      { "node.name", "equals", "bluez_output.58_17_C1_07_48_52.a2dp-sink" },
    },
    {
      { "node.name", "equals", "bluez_output.58_17_C1_07_48_52.headset-head-unit" },
    },
    {
      { "node.name", "equals", "bluez_input.58_17_C1_07_48_52.headset-head-unit" },
    }
  },
  apply_properties = {
    ["node.nick"] = "Philips Headset",
    ["media.target.tag"] = "work-hub;comm-hub;media-hub",
  },
}

local rule_bose = {
  matches = {
    {
      { "node.name", "equals", "bluez_output.4C_87_5D_28_F6_91.a2dp-sink" },
    },
    {
      { "node.name", "equals", "bluez_output.4C_87_5D_28_F6_91.headset-head-unit" },
    },
    {
      { "node.name", "equals", "bluez_input.4C_87_5D_28_F6_91.headset-head-unit" },
    }
  },
  apply_properties = {
    ["node.nick"] = "Bose Headset",
    ["media.target.tag"] = "work-hub;comm-hub;media-hub",
  },
}

local rule_disable = {
  matches = {
    {
      { "node.name", "equals", "bluez_input.20_74_CF_34_ED_F7.headset-head-unit" },
    },
  },
  apply_properties = {
    ["device.disabled"] = true,
  },
}

table.insert(bluez_monitor.rules, rule_apple_air_pro)
table.insert(bluez_monitor.rules, rule_philips)
table.insert(bluez_monitor.rules, rule_trekz)
table.insert(bluez_monitor.rules, rule_bose)
table.insert(bluez_monitor.rules, rule_disable)
