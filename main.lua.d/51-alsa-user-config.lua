local rule_microphone = {
  matches = {
    {
      { "node.name", "equals", "alsa_input.usb-Kingston_HyperX_QuadCast_S_4100-00.analog-stereo" },
    },
  },
  apply_properties = {
    ["node.name"] = "HyperX Microphone",
    ["media.user.target.role"] = "work;comm;media",
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
    ["media.user.target.role"] = "work;comm;media",
  },
}


local rule_soundux = {
  matches = {
    {
      { "node.name", "equals", "soundux_sink" },
    },
  },
  apply_properties = {
    ["media.user.role"] = "soundboard",
    ["media.user.target.object.name"] = "Communication Source;Communication Sink",
  },
}

table.insert(alsa_monitor.rules, rule_microphone)
table.insert(alsa_monitor.rules, rule_headset)
table.insert(alsa_monitor.rules, rule_soundux)

-- Disable unused devices

local rule_disable_brio = {
  matches = {
    {
      { "node.description", "equals", "BRIO 4K Stream Edition Digital Stereo (IEC958)" },
    },
    {
      { "node.description", "equals", "BRIO 4K Stream Edition Analog Stereo" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}

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
table.insert(alsa_monitor.rules, rule_disable_brio)
