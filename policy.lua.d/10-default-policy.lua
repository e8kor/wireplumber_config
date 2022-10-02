default_policy = {}
default_policy.enabled = true
default_policy.properties = {}
default_policy.endpoints = {}
default_policy.rules = {}
default_policy.user_rules = {}

default_policy.fallback = {
  ["media.user.target.role"] = "media"
}

table.insert(default_policy.user_rules, {
  name = "VirtualBoxVM",
  matches = { {
    { "application.binary.name", "equals", "VirtualBoxVM" },
  }, {
    { "application.process.binary", "equals", "VirtualBoxVM" },
  } },
  apply_properties = {
    ["media.user.target.role"] = "work",
  }
})
table.insert(default_policy.user_rules, {
  name = "Firefox",
  matches = { {
    { "application.process.binary", "matches", "firefox*" }
  } },
  apply_properties = {
    ["media.user.target.role"] = "media"
  }
})

table.insert(default_policy.user_rules, {
  name = "Chromium",
  matches = { {
    { "application.process.binary", "matches", "chrome*" }
  } },
  apply_properties = {
    ["media.user.target.role"] = "media"
  }
})

table.insert(default_policy.user_rules, {
  name = "Telegram",
  matches = { {
    { "application.process.binary", "equals", "telegram-desktop" }
  } },
  apply_properties = {
    ["media.user.target.role"] = "comm"
  }
})

table.insert(default_policy.user_rules, {
  name = "Totem Player",
  matches = { {
    { "application.process.binary", "equals", "totem" }
  } },
  apply_properties = {
    ["media.user.target.role"] = "media"
  }
})

table.insert(default_policy.user_rules, {
  name = "Soundux Soundboard",
  matches = { {
    { "node.name", "equals", "soundux_sink" },
  } },
  apply_properties = {
    ["node.autoconnect"] = false,
    ["node.nick"]        = "Soundux Soundboard",
    ["media.user.role"]  = "soundboard",
  },
})

table.insert(default_policy.user_rules, {
  name = "Bypass mapped objects",
  matches = { {
    { "media.user.role", "is-present" }
  },{
    { "media.user.target.role", "is-present" }
  },{
    { "media.user.target.object.name", "is-present" }
  } },
  apply_properties = { }
})

default_policy.policy = {
  ["move"] = true, -- moves session items when metadata target.node changes
  ["follow"] = true, -- moves session items to the default device when it has changed

  -- Whether to forward the ports format of filter stream nodes to their
  -- associated filter device nodes. This is needed for application to stream
  -- surround audio if echo-cancel is enabled.
  ["filter.forward-format"] = false,

  -- Set to 'true' to disable channel splitting & merging on nodes and enable
  -- passthrough of audio in the same format as the format of the device.
  -- Note that this breaks JACK support; it is generally not recommended
  ["audio.no-dsp"] = false,

  -- how much to lower the volume of lower priority streams when ducking
  -- note that this is a linear volume modifier (not cubic as in pulseaudio)
  ["duck.level"] = 0.3,
}

bluetooth_policy = {}

bluetooth_policy.policy = {
  -- Whether to store state on the filesystem.
  ["use-persistent-storage"] = true,

  -- Whether to use headset profile in the presence of an input stream.
  ["media-role.use-headset-profile"] = true,

  -- Application names correspond to application.name in stream properties.
  -- Applications which do not set media.role but which should be considered
  -- for role based profile switching can be specified here.
  ["media-role.applications"] = { "Firefox", "Chromium input", "Google Chrome input", "Brave input",
    "Microsoft Edge input", "Vivaldi input", "ZOOM VoiceEngine", "Telegram Desktop", "telegram-desktop", "linphone",
    "Mumble" },
}

function default_policy.enable()
  if default_policy.enabled == false then
    return
  end

  -- Session item factories, building blocks for the session management graph
  -- Do not disable these unless you really know what you are doing
  load_module("si-node")
  load_module("si-audio-adapter")
  load_module("si-standard-link")
  load_module("si-audio-endpoint")

  -- API to access default nodes from scripts
  load_module("default-nodes-api")

  -- API to access mixer controls, needed for volume ducking
  load_module("mixer-api")

  -- Create endpoints statically at startup
  load_script("static-endpoints.lua", default_policy.endpoints)

  -- Create items for nodes that appear in the graph
  load_script("create-item.lua", {
    policy = default_policy.policy,
    rules = default_policy.rules
  })

  -- Link nodes to each other to make media flow in the graph
  load_script("policy-node.lua", default_policy.policy)

  -- Link client nodes with endpoints to make media flow in the graph
  load_script("policy-endpoint-client.lua", default_policy.policy)
  load_script("policy-endpoint-client-links.lua", default_policy.policy)

  -- Link endpoints with device nodes to make media flow in the graph
  load_script("policy-endpoint-device.lua", default_policy.policy)

  -- Switch bluetooth profile based on media.role
  load_script("policy-bluetooth.lua", bluetooth_policy.policy)

  -- User wiring config
  load_script("policy-endpoint-user-config.lua", {
    policy = default_policy.policy,
    rules = default_policy.user_rules,
    fallback = default_policy.fallback
  })

end
