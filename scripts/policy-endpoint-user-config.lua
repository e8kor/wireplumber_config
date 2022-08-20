local config = ... or {}

function split(s, delimiter)
    result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        result[match] = true
    end
    return result;
end

function intersect(m,n)
    local intersection = {}
    for item, _ in pairs (m) do
        if n [item] then
            intersection [item] = true
        end
    end
    return next(intersection) ~= nil
end

function createLink (si, si_target_ep)
    local out_item = nil
    local in_item = nil
    local si_props = si.properties
    local target_ep_props = si_target_ep.properties
    Log.info("creating link between " .. si_props["node.name"] .. " and " .. target_ep_props["node.name"])

    if si_props["item.node.direction"] == "output" then
        -- playback
        out_item = si
        in_item = si_target_ep
        Log.info("it is playback")
    else
        -- capture
        out_item = si_target_ep
        in_item = si
        Log.info("it is capture")
    end

    Log.info(string.format("link %s <-> %s",
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
        ["target.media.class"] = target_ep_props["media.class"],
        ["item.plugged.usec"] = si_props["item.plugged.usec"],
    } then
        Log.warning (si_link, "failed to configure si-standard-link")
        return
    else 
        Log.info (si_link, "si-standard-link configured successfully")
    end

    -- register
    si_link:register()
    si_link:activate(Feature.SessionItem.ACTIVE)
end

function findTarget(lookup_roles, key_name, direction)
    local targets = {}
    for target in user_roles_om:iterate() do
        local node_name = target.properties["node.name"]
        if target.properties[key_name] then
            local node = target:get_associated_proxy("node")
            Log.info("checking target node: " .. node_name)
            local role_raw = node.properties[key_name]
            Log.info("..  with roles: " .. role_raw)
            local roles = split(role_raw, ":")
            local id = tostring(target.id)
            if intersect(lookup_roles, roles) and target.properties["item.node.direction"] == direction then
                Log.info("found target node: " .. node_name)
                table.insert(targets, target)
            end
        else 
            Log.info("skinning node: " .. node_name)
        end
    end
    return targets
end

function createNodeLink(si, lookup_key, target_key)
    local node = si:get_associated_proxy("node")

    local node_id = si.id
    local node_name = node.properties['node.name']
    local lookup_role_raw = si.properties[lookup_key]
    Log.info("handling: " ..  node_name .. ":" .. node_id .. ", expected target role: " .. lookup_role_raw)
    local lookup_roles = split(lookup_role_raw, ":")
    local visited = {}
    for link in links_om:iterate() do
        local out_id = tonumber(link.properties["out.item.id"])
        local in_id  = tonumber(link.properties["in.item.id"])
        if out_id == node_id or in_id == node_id then
            Log.info("already linked: " .. in_id .. " <-> " .. out_id)
        end
        if out_id == node_id then
            table.insert(visited, link.properties["out.item.id"], link)
        elseif in_id == node_id then
            table.insert(visited, link.properties["in.item.id"], link)
        end
    end
    local direction = ""
    if si.properties["item.node.direction"] == "output" then
        direction = "input"
    else
        direction = "output"
    end
    local targets = findTarget(lookup_roles, target_key, direction)
    for _, target in ipairs(targets) do
        local target_node_id = target.id
        local target_node = target:get_associated_proxy("node")
        local target_node_name = target_node.properties["node.name"]
        if not visited[target_node_id] then
            Log.info("connecting ".. node_name .. " with target " .. target_node_name)
            createLink(si, target)
        else
            Log.info("skipping ".. node_name .. " with target " .. target_node_name .. ", as already connected")
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

user_roles_om = ObjectManager {
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.target.role", "is-present"},
    },
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.role", "is-present" },
    }
}

user_roles_om:connect("object-added", function (om, si)
    local props = si.properties
    Log.info(string.format("user-config: handling item: %s (%s)", tostring(props["node.name"]), tostring(props["node.id"])))
    
    if props["media.user.target.role"] then
        createNodeLink(si, "media.user.target.role", "media.user.role")
    elseif props["media.user.role"] then
        createNodeLink(si, "media.user.role", "media.user.target.role")
    else
        Log.info("unable to recognize node skipping: " .. tostring(si))
    end
end)

user_roles_om:connect("object-removed", function(om, node)
    Log.info(string.format("user-config: unhandling item: %s (%s)", tostring(node["node.name"]), tostring(node["node.id"])))
    -- remove any links associated with this item
    for silink in links_om:iterate() do
        local out_id = tonumber (silink.properties["out.item.id"])
        local in_id = tonumber (silink.properties["in.item.id"])
        if out_id == node["node.id"] or in_id == node["node.id"] then
            silink:remove ()
            Log.info (silink, "... link removed")
        end
    end
end)

links_om:activate()
user_roles_om:activate()
