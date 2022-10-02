-- WirePlumber
--
-- Copyright © 2021 Collabora Ltd.
--    @author Julian Bouzas <julian.bouzas@collabora.com>
--
-- SPDX-License-Identifier: MIT

-- Receive script arguments from config.lua
local user_config = ... or {}
local config = user_config.policy or {}

items = {}
-- preprocess rules and create Interest objects
for _, r in ipairs(user_config.rules or {}) do
  r.interests = {}
  for _, i in ipairs(r.matches) do
    local interest_desc = { type = "properties" }
    for _, c in ipairs(i) do
      c.type = "pw"
      table.insert(interest_desc, Constraint(c))
    end
    local interest = Interest(interest_desc)
    table.insert(r.interests, interest)
  end
  r.matches = nil
end

function GetName(si)
  local si_id = tostring(si.id or si["client.id"])
  local node_props = si.properties
  local binary_name = node_props["application.process.binary"]
  local node_name = node_props["node.name"]
  local name = "undefined"

  if binary_name and binary_name ~= '' then
      name = string.format("%s (%s)", binary_name, si_id)
  elseif node_name and node_name ~= '' then
      name = string.format("%s (%s)", node_name, si_id)
  else
      name = string.format("unknown (%s)", si_id)
  end
  return name
end

-- applies properties from config.rules when asked to
function rulesApplyProperties(properties)
  for _, r in ipairs(user_config.rules or {}) do
    if r.apply_properties then
      for _, interest in ipairs(r.interests) do
        if interest:matches(properties) then
          for k, v in pairs(r.apply_properties) do
            properties[k] = v
          end
        end
      end
    end
  end
  return properties
end

function configProperties(node)
  local np = node.properties
  local properties = rulesApplyProperties({
    ["item.node.name"] = np["node.name"],
    ["item.node"] = node,
    ["item.plugged.usec"] = GLib.get_monotonic_time(),
    ["item.features.no-dsp"] = config["audio.no-dsp"],
    ["item.features.monitor"] = true,
    ["item.features.control-port"] = false,
    ["node.id"] = node["bound-id"],
    ["client.id"] = np["client.id"],
    ["object.path"] = np["object.path"],
    ["object.serial"] = np["object.serial"],
    ["target.object"] = np["target.object"],
    ["priority.session"] = np["priority.session"],
    ["device.id"] = np["device.id"],
    ["card.profile.device"] = np["card.profile.device"],
    ["user.managed"] = np["user.managed"] or false,
    ["user.node.target"] = np["user.node.target"] or nil,
  })

  for k, v in pairs(np) do
    if k:find("^node") or k:find("^stream") or k:find("^media") then
      properties[k] = v
    end
  end

  local media_class = properties["media.class"] or ""

  if not properties["media.type"] then
    for _, i in ipairs({ "Audio", "Video", "Midi" }) do
      if media_class:find(i) then
        properties["media.type"] = i
        break
      end
    end
  end

  properties["item.node.type"] =
      media_class:find("^Stream/") and "stream" or "device"

  if media_class:find("Sink") or
      media_class:find("Input") or
      media_class:find("Duplex") then
    properties["item.node.direction"] = "input"
  elseif media_class:find("Source") or media_class:find("Output") then
    properties["item.node.direction"] = "output"
  end
  return properties
end

function addItem (node, item_type)
  local id = node["bound-id"]
  local item

  -- create item
  item = SessionItem ( item_type )
  items[id] = item

  -- configure item
  if not item:configure(configProperties(node)) then
    Log.warning(item, "failed to configure item for node " .. tostring(id))
    return
  end

  item:register ()

  -- activate item
  items[id]:activate (Features.ALL, function (item, e)
    if e then
      Log.message(item, "failed to activate item: " .. tostring(e));
      if item then
        item:remove ()
      end
    else
      Log.info(item, "activated item for node " .. tostring(id))

      -- Trigger object managers to update status
      item:remove ()
      if item["active-features"] ~= 0 then
        item:register ()
      end
    end
  end)
end

nodes_om = ObjectManager {
  Interest {
    type = "node",
    Constraint { "media.class", "#", "Stream/*", type = "pw-global" },
  },
  Interest {
    type = "node",
    Constraint { "media.class", "#", "Video/*", type = "pw-global" },
  },
  Interest {
    type = "node",
    Constraint { "media.class", "#", "Audio/*", type = "pw-global" },
    Constraint { "wireplumber.is-endpoint", "-", type = "pw" },
  },
}

nodes_om:connect("object-added", function (om, node)
  local media_class = node.properties['media.class']
  local name = GetName(node)
  if string.find (media_class, "Audio") then
    Log.info("Adding SI Audio Adapter: " .. name)
    addItem (node, "si-audio-adapter")
  else
    Log.info("Adding SI Node: " .. name)
    addItem (node, "si-node")
  end
end)

nodes_om:connect("object-removed", function (om, node)
  local id = node["bound-id"]
  if items[id] then
    items[id]:remove ()
    items[id] = nil
  end
end)

nodes_om:activate()
