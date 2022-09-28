local rule_microphone = {
  matches = {
    {
      { "node.name", "equals", "alsa_input.usb-Kingston_HyperX_QuadCast_S_4100-00.analog-stereo" },
    },
  },
  apply_properties = {
    ["node.nick"] = "HyperX Microphone",
    ["media.user.target.role"] = "work;comm;media",
  },
}

local rule_rode_microphone = {
  matches = {
    {
      { "node.name", "equals", "alsa_input.usb-R__DE_Microphones_Wireless_GO_II_RX_216F2176-01.analog-stereo" },
    },
  },
  apply_properties = {
    ["node.nick"] = "RODE Microphone",
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
    ["node.nick"] = "HyperX Headset out",
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

table.insert(alsa_monitor.rules, rule_rode_microphone)
table.insert(alsa_monitor.rules, rule_microphone)
table.insert(alsa_monitor.rules, rule_headset)
table.insert(alsa_monitor.rules, rule_soundux)

-- Disable unused devices

local rule_brio = {
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

local rule_usb_aad = {
  matches = {
    {
      { "node.description", "equals", "USB Advanced Audio Device Analog Stereo" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}

local rule_usb_pnp_1 = {
  matches = {
    {
      { "node.description", "equals", "USB PnP Audio Device Mono" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}
local rule_usb_pnp_2 = {
  matches = {
    {
      { "node.description", "equals", "USB PnP Audio Device Analog Stereo" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}

local rule_usb_ga102 = {
  matches = {
    {
      { "node.description", "equals", "GA102 High Definition Audio Controller Digital Stereo (HDMI)" },
    },
  },
  apply_properties = {
    ["node.disabled"] = true,
  }
}

local rule_usb_starship = {
  matches = {
    {
      { "node.description", "equals", "Starship/Matisse HD Audio Controller Digital Stereo (IEC958)" },
    },
  },
  apply_properties = {
    ["node.nick"] = "Starship Audio out",
    ["media.user.target.role"] = "media",
    ["node.disabled"] = false,
  }
}

local rule_hdmi = {
  matches = {
    {
      { "node.name", "equals", "alsa_output.pci-0000_0b_00.1.hdmi-stereo" },
    },
  },
  apply_properties = {
    ["node.nick"] = "Aorus Display HDMI",
    ["node.disabled"] = true,
  },
}

local rule_nvidia_hdmi = {
  matches = {
    {
      { "node.name", "equals", "alsa_output.pci-0000_0b_00.1.hdmi-stereo.2" },
    },
  },
  apply_properties = {
    ["node.nick"] = "NVidia HDMI",
    ["node.disabled"] = true,
  },
}

local rule_aorus_hdmi = {
  matches = {
    {
      { "node.name", "equals", "alsa_output.pci-0000_0b_00.1.hdmi-stereo.3" },
    },
  },
  apply_properties = {
    ["node.nick"] = "AORUS Display DP",
    ["node.disabled"] = true,
  },
}

local rule_loopback_pcm_input = {
  matches = {
    {
      { "node.name", "equals", "alsa_input.platform-snd_aloop.0.analog-stereo" },
    },
  },
  apply_properties = {
    ["node.nick"] = "Build-in Audio Input",
    ["node.disabled"] = true,
  },
}

local rule_loopback_pcm_output = {
  matches = {
    {
      { "node.name", "equals", "alsa_output.platform-snd_aloop.0.analog-stereo" },
    },
  },
  apply_properties = {
    ["node.nick"] = "Build-in Audio Output",
    ["node.disabled"] = true,
  },
}

table.insert(alsa_monitor.rules, rule_usb_starship)
table.insert(alsa_monitor.rules, rule_usb_ga102)
table.insert(alsa_monitor.rules, rule_usb_aad)
table.insert(alsa_monitor.rules, rule_usb_pnp_1)
table.insert(alsa_monitor.rules, rule_usb_pnp_2)
table.insert(alsa_monitor.rules, rule_brio)
table.insert(alsa_monitor.rules, rule_hdmi)
table.insert(alsa_monitor.rules, rule_nvidia_hdmi)
table.insert(alsa_monitor.rules, rule_aorus_hdmi)
table.insert(alsa_monitor.rules, rule_loopback_pcm_input)
table.insert(alsa_monitor.rules, rule_loopback_pcm_output)
