local config = ... or {}

function contains(t, key)
    for _, value in ipairs(t) do
        if key == value then
            return true
        end
    end
    return false
end

function split(s, delimiter)
    result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result;
end

function parseSetAt(t, key)
    local set = {}
    for _, value in ipairs(split(t[key], ";")) do
        table.insert(set, value)
    end
    return set
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
        ["out.node.name"] = si_props["node.name"],
        ["in.node.name"] = target_ep_props["node.name"],
        ["out.item"] = out_item,
        ["in.item"] = in_item,
        ["out.item.port.context"] = "output",
        ["in.item.port.context"] = "input",
        -- ["is.policy.endpoint.client.link"] = true,
        ["target.media.class"] = target_ep_props["media.class"],
        ["item.plugged.usec"] = si_props["item.plugged.usec"],
        ["media.user.managed"] = true
    } then
        Log.warning (si_link, "failed to configure si-standard-link")
        return
    else 
        Log.info (si_link, "si-standard-link configured successfully")
    end

    -- register
    si_link:register()
    si_link:activate(Feature.SessionItem.ACTIVE, function (l, e)
        out_name = l.properties["out.node.name"]
        in_name = l.properties["in.node.name"]
        direction_msg = string.format("link %s <-> %s", out_name, in_name)
        if e then
          Log.info (l, "failed to activate si-standard-link ".. direction_msg .. ": " .. tostring(e))
          l:remove ()
        else
          Log.info (l, "activated si-standard-link " .. direction_msg)
        end
      end)
end

function findTargetWithMediaClass(items, mediaclass)
    for _,target in ipairs(items) do
        local np = getProperties(target)
        if np["media.class"] == mediaclass then
            return target
        end
    end
    return nil
end

function findTargetNodes(key, lookup_roles, lookup_media_classes)
    local targets = {}
    for _, lookup_role in ipairs(lookup_roles) do
        local collected = {}
        for target in host_om:iterate() do
            local np =  getProperties(target)
            local node_name = np["node.name"]
            if np[key] then
                Log.info("checking target node: " .. node_name)

                local roles = parseSetAt(np, key)
                for _,item in pairs(roles) do
                    Log.info("..  with role: " .. item)
                end

                if contains(roles, lookup_role) then
                    Log.info("found target node by role: " .. node_name)
                    table.insert(collected, target)
                end
            else
                Log.info("skinning node: " .. node_name)
            end
        end

        for _, lookup_media_class in ipairs(lookup_media_classes) do
            Log.info("..  with media class: " .. lookup_media_class)
            local target = findTargetWithMediaClass(collected, lookup_media_class)
            if target then
                Log.info("..  found target node by media class: " .. target.properties["node.name"])
                table.insert(targets, target)
                break
            end
        end

    end
    return targets
end

function findTargetNode(lookup_node_name)
    local lookup_node_names = split(lookup_node_name, ";")
    local targets = {}
    for target in host_om:iterate() do
        local np = getProperties(target)
        local node_name = np["node.name"]
        if node_name and contains(lookup_node_names, node_name) then
            table.insert(targets,target)
        end
    end
    return targets
end

function findExistingLinks(si)
    local si_id = si.id
    local visited = {}
    for link in links_om:iterate() do
        local out_id = tonumber(link.properties["out.item.id"])
        local out_name = link.properties["out.node.name"]
        local in_id  = tonumber(link.properties["in.item.id"])
        local in_name = link.properties["in.node.name"]

        if out_id == si_id or in_id == si_id then
            Log.info("already linked: " .. out_name .. " <-> " .. in_name)
        end
        if out_id == si_id then
            visited[link.properties["out.item.id"]] = link
        elseif in_id == si_id then
            visited[link.properties["in.item.id"]] = link
        end
    end
    return visited
end

function possibleTargetMediaClasses(si)
    local media_class = si.properties["media.class"]
    local media_classes = {
        ["Audio/Source"] = { "Audio/Source/Virtual" },
        ["Stream/Output/Audio"] = { "Audio/Sink" },

        ["Audio/Sink"] = { "Audio/Sink" },
        ["Stream/Input/Audio"] = { "Audio/Source/Virtual" }
    }
    return media_classes[media_class] or {}
end

function getProperties(si)
    local si_np = si.properties
    if (si_np["media.user.role"] or si_np["media.user.target.role"]) and si_np["media.class"] then
        return si_np
    else
    local node = si:get_associated_proxy("node")
    return node.properties
    end
end

function createNodeLink(si, lookup_key, target_key)
    Log.info("handling linkable: ".. si.id)
    Log.info(".. si properties: ")
    for key, value in pairs(si.properties) do
        Log.info(".... " .. key .. ": " .. value)
    end

    local np = getProperties(si)
    
    Log.info(".. node properties: ")
    for key, value in pairs(np) do
        Log.info(".... " .. key .. ": " .. value)
    end

    local lookup_roles = parseSetAt(np, lookup_key)
    for _, item in ipairs(lookup_roles) do
        Log.info("..  with expected target role: " .. item)
    end

    local node_name = np['node.name']
    Log.info(".. node name: " .. node_name)

    local lookup_media_classes = possibleTargetMediaClasses(si)
    Log.info(".. looking for media classes: " .. table.concat(lookup_media_classes, ", "))

    local visited = findExistingLinks(si)
    Log.info(".. visited nodes: " .. table.concat(visited, ", "))

    local targets = findTargetNodes(target_key, lookup_roles, lookup_media_classes)
    local lookup_node_name = np["media.user.target.object.name"]
    if lookup_node_name then
        Log.info(".. looking for nodes with name: " .. tostring(lookup_node_name))
        for _, target in ipairs(findTargetNode(lookup_node_name)) do
            table.insert(targets, target)
        end
    else
        Log.info(".. no lookup node name")
    end

    -- for _, target in ipairs(targets) do 
    --     Log.info(".. discovered target node: " .. target.properties["node.name"])
    -- end

    Log.info("connecting nodes to " .. node_name)
    for _, target in ipairs(targets) do
        local target_node_id = target.id
        local target_np = getProperties(target)
        local target_node_name = target_np["node.name"]
        if not visited[target_node_id] then
            Log.info(".. with target " .. target_node_name)
            createLink(si, target)
        else
            Log.info(".. skipping node " .. target_node_name .. ", as already connected")
        end
    end
end

function unhandleLinkable(si, isAll)
    local props = getProperties(si)
    Log.info(string.format("user-config: unhandling item: %s (%s)", tostring(props["node.name"]), tostring(si.id)))
    local visited = findExistingLinks(si)
    for id, silink in pairs(visited) do
        if (isAll or not silink.properties["media.user.managed"]) then
            silink:remove ()
            Log.info(silink, "... link removed to " .. id)
        end
    end
end


links_om = ObjectManager {
    Interest {
        type = "SiLink",
        -- only handle links created by this policy
        Constraint { "media.user.managed", "=", true, type = "pw-global" },
    }
}

links_om:connect("object-added", function(om, si)
    Log.info(si, "hub link added")
end)

links_om:connect("object-removed", function(om, si)
    Log.info(si, "hub link removed")
end)

links_om:activate()

host_om = ObjectManager {
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.role", "is-present" },
    }
}

host_om:connect("object-added", function(om, si)
    Log.info(si, "host linkable added")
    for client_si in client_om:iterate() do
        unhandleLinkable(client_si, false)
        createNodeLink(client_si, "media.user.target.role", "media.user.role")
    end
end)

host_om:connect("object-removed", function(om, si)
    Log.info(si, "host linkable removed")
end)

host_om:activate()

client_om = ObjectManager {
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.target.role", "is-present"},
    }
}

client_om:connect("objects-changed", function (om)
    for si in om:iterate() do
        unhandleLinkable(si, false)
        createNodeLink(si, "media.user.target.role", "media.user.role")
    end
end)

client_om:connect("object-added", function (om, si)
    Log.info(si, "client linkable added")
    unhandleLinkable(si, false)
    createNodeLink(si, "media.user.target.role", "media.user.role")
end)

client_om:connect("object-removed", function(om, si)
    Log.info(si, "client linkable removed")
    unhandleLinkable(si, true)
end)

client_om:activate()
