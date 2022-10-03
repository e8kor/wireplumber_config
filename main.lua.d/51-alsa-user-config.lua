local rule_microphone = {
  matches = { {
    { "node.name", "equals", "alsa_input.usb-Kingston_HyperX_QuadCast_S_4100-00.analog-stereo" },
  } },
  apply_properties = {
    ["node.nick"] = "HyperX Microphone",
    ["media.user.target.role"] = "work-source;comm-source;media-source",
  },
}

local rule_rode_microphone = {
  matches = { {
    { "node.name", "equals", "alsa_input.usb-R__DE_Microphones_Wireless_GO_II_RX_216F2176-01.analog-stereo" },
  } },
  apply_properties = {
    ["node.nick"] = "RODE Microphone",
    ["media.user.target.role"] = "work-source;comm-source;media-source",
  },
}

local rule_headset = {
  matches = { {
    { "node.name", "equals", "alsa_output.usb-Kingston_HyperX_QuadCast_S_4100-00.analog-stereo" },
  } },
  apply_properties = {
    ["node.nick"] = "HyperX Headset out",
    ["media.user.target.role"] = "work-sink;comm-sink;media-sink",
  },
}

local rule_soundux = {
  matches = { {
    { "node.name", "equals", "soundux_sink" },
  } },
  apply_properties = {
    ["media.user.role"] = "soundboard-hub",
    ["media.user.target.node.name"] = "Communication Source;Communication Sink",
  },
}
local rule_usb_starship = {
  matches = { {
      { "node.description", "equals", "Starship/Matisse HD Audio Controller Digital Stereo (IEC958)" },
    } },
  apply_properties = {
    ["node.nick"] = "Soundbar",
    ["media.user.target.role"] = "media-sink",
    ["node.disabled"] = false,
  }
}

table.insert(alsa_monitor.rules, rule_usb_starship)
table.insert(alsa_monitor.rules, rule_rode_microphone)
table.insert(alsa_monitor.rules, rule_microphone)
table.insert(alsa_monitor.rules, rule_headset)
table.insert(alsa_monitor.rules, rule_soundux)

local disable_rules = {
  matches = {
    -- output/headsets
    {{ "node.name", "equals", "alsa_output.pci-0000_0b_00.1.hdmi-stereo.3" }},
    {{ "node.name", "equals", "alsa_output.pci-0000_0b_00.1.hdmi-stereo.2" }},
    {{ "node.name", "equals", "alsa_output.pci-0000_0b_00.1.hdmi-stereo" }},
    {{ "node.name", "equals", "alsa_output.platform-snd_aloop.0.analog-stereo" }},
    {{ "node.name", "equals", "alsa_output.platform-snd_aloop.0.analog-stereo.2" }},
    {{ "node.name", "equals", "alsa_output.pci-0000_0b_00.1.hdmi-stereo" }},
    {{ "node.name", "equals", "alsa_output.platform-snd_aloop.0.analog-stereo" }},
    {{ "node.name", "equals", "alsa_output.usb-0c76_USB_PnP_Audio_Device-00.analog-stereo" }},

    -- input/mic 
    {{ "node.name", "equals", "alsa_input.platform-snd_aloop.0.analog-stereo" }},
    {{ "node.name", "equals", "alsa_input.platform-snd_aloop.0.analog-stereo.2" }},
    {{ "node.name", "equals", "alsa_input.usb-0c76_USB_PnP_Audio_Device-00.mono-fallback" }},
    {{ "node.name", "equals", "alsa_input.usb-C-Media_Electronics_Inc._USB_Advanced_Audio_Device-00.analog-stereo" }},
    {{ "node.name", "equals", "alsa_input.usb-046d_BRIO_4K_Stream_Edition_718B3D42-02.analog-stereo" }},
    
    -- devices
    {{ "device.name", "equals", "alsa_card.platform-snd_aloop.0" }},
    {{ "device.name", "equals", "alsa_card.pci-0000_0b_00.1" }},
    {{ "device.name", "equals", "alsa_card.usb-C-Media_Electronics_Inc._USB_Advanced_Audio_Device-00" }},
    {{ "device.name", "equals", "alsa_card.usb-0c76_USB_PnP_Audio_Device-00" }},
    {{ "device.name", "equals", "alsa_card.usb-046d_BRIO_4K_Stream_Edition_718B3D42-02" }},
  },
  apply_properties = {
    ["node.disabled"] = true,
  },
}

table.insert(alsa_monitor.rules, disable_rules)
