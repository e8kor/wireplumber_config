local rule_microphone = {
  matches = {
    {
      { "node.name", "equals", "alsa_input.usb-Kingston_HyperX_QuadCast_S_4100-00.analog-stereo" },
    },
  },
  apply_properties = {
    ["node.name"] = "HyperX Microphone",
    ["user.target.media.role"] = "comm",
  },
}

local rule_headset = {
  matches = {
    {
      { "node.name", "equals", "alsa_output.usb-Kingston_HyperX_QuadCast_S_4100-00.analog-stereo" },
    },
  },
  apply_properties = {
    ["node.name"] = "HyperX Stereo",
    ["user.target.media.role"] = "media",
  },
}

table.insert(alsa_monitor.rules, rule_microphone)
table.insert(alsa_monitor.rules, rule_headset)

-- Disable unused devices

local rule_disable_usb_aad = {
  matches = {
    {
      { "node.description", "equals", "USB Advanced Audio Device Analog Stereo" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}

local rule_disable_usb_pnp_1 = {
  matches = {
    {
      { "node.description", "equals", "USB PnP Audio Device Mono" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}
local rule_disable_usb_pnp_2 = {
  matches = {
    {
      { "node.description", "equals", "USB PnP Audio Device Analog Stereo" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}

local rule_disable_usb_ga102 = {
  matches = {
    {
      { "node.description", "equals", "GA102 High Definition Audio Controller Digital Stereo (HDMI)" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}

local rule_disable_usb_starship = {
  matches = {
    {
      { "node.description", "equals", "Starship/Matisse HD Audio Controller Digital Stereo (IEC958)" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}

table.insert(alsa_monitor.rules, rule_disable_usb_starship)
table.insert(alsa_monitor.rules, rule_disable_usb_ga102)
table.insert(alsa_monitor.rules, rule_disable_usb_aad)
table.insert(alsa_monitor.rules, rule_disable_usb_pnp_1)
table.insert(alsa_monitor.rules, rule_disable_usb_pnp_2)
