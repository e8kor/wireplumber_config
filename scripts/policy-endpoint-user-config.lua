local self = {}
self.scanning = false
self.pending_rescan = false

function string_split(s, sep)
  local fields = {}
  
  local sep = sep or " "
  local pattern = string.format("([^%s]+)", sep)
  string.gsub(s, pattern, function(c) fields[#fields + 1] = c end)
  
  return fields
end

function has_value (tab, val)
  for index, value in ipairs(tab) do
      if value == val then
          return true
      end
  end

  return false
end

function createLink (si, si_target_ep)
  local out_item = nil
  local in_item = nil
  local si_props = si.properties
  local target_ep_props = si_target_ep.properties
  Log.message("creating link between " .. si_props["node.name"] .. " and " .. target_ep_props["node.name"])

  if si_props["item.node.direction"] == "output" then
    -- playback
    out_item = si
    in_item = si_target_ep
    Log.message("it is playback")
  else
    -- capture
    out_item = si_target_ep
    in_item = si
    Log.message("it is capture")
  end

  Log.message(string.format("link %s <-> %s",
      tostring(si_props["node.name"]),
      tostring(target_ep_props["node.name"])))

  -- create and configure link
  local si_link = SessionItem ( "si-standard-link" )
  if not si_link:configure {
    ["out.item"] = out_item,
    ["in.item"] = in_item,
    ["out.item.port.context"] = "output",
    ["in.item.port.context"] = "input",
    ["is.policy.endpoint.client.link"] = true,
    ["media.role"] = target_ep_props["role"],
    ["target.media.class"] = target_ep_props["media.class"],
    ["item.plugged.usec"] = si_props["item.plugged.usec"],
  } then
    Log.warning (si_link, "failed to configure si-standard-link")
    return
  end

  -- register
  si_link:register()
  si_link:activate(Feature.SessionItem.ACTIVE)
end

function findTarget(node)
  for target in linkables_om:iterate() do
    local target_node = target:get_associated_proxy("node")
    local target_nick = target_node.properties["node.nick"] or target_node.properties["node.name"]
    local target_nodes = string_split(node.properties["user.node.target"], ";")
    Log.message("checking target node: " .. target_nick)
    if has_value(target_nodes, target_nick) then
      Log.message("found target node: " .. target_nick)
      return target
    end
  end
  Log.message("cannot create link for: " .. node.properties['node.nick'] )
end

function createNodeLink(om, item)
  local node = item:get_associated_proxy("node")
  if not node or not node.properties then
    Log.message("skipping item: " .. item)
    return
  end
  Log.message("handling: " .. item.properties['node.nick'] .. ", target: " .. item.properties['user.node.target'])
  for link in om:iterate() do
    local out_id = tonumber(link.properties["out.item.id"])
    local in_id  = tonumber(link.properties["in.item.id"])
    if out_id == item.id or in_id == item.id then
      Log.message("already linked: " .. in_id .. " <-> " .. out_id)
    end
  end
  local target = findTarget(node)
  if target then
    createLink(item, target)
  end
end

function unhandleLinkable (om, si)
  si_props = si.properties

  Log.info (si, string.format("unhandling item: %s (%s)",
      tostring(si_props["node.name"]), tostring(si_props["node.id"])))

  -- remove any links associated with this item
  for silink in links_om:iterate() do
    local out_id = tonumber (silink.properties["out.item.id"])
    local in_id = tonumber (silink.properties["in.item.id"])
    if out_id == si.id or in_id == si.id then
      silink:remove ()
      Log.info (silink, "... link removed")
    end
  end
end

links_om = ObjectManager {
  Interest {
    type = "SiLink",
    -- only handle links created by this policy
    Constraint { "is.policy.endpoint.device.link", "=", true, type = "pw-global" },
  }
}

links_om:activate()

linkables_om = ObjectManager {
  Interest {
    type = "SiLinkable",
    -- only handle device si-audio-adapter items
    Constraint { "item.factory.name", "=", "si-audio-adapter", type = "pw-global" },
    Constraint { "item.node.type", "=", "device", type = "pw-global" },
    Constraint { "active-features", "!", 0, type = "gobject" },
  }
}

linkables_om:activate()

audio_cable_om = ObjectManager {
  Interest {
    type = "SiLinkable",
    Constraint { "user.managed", "=", "true" },
  }
}

audio_cable_om:connect("object-added", createNodeLink)

audio_cable_om:activate()


