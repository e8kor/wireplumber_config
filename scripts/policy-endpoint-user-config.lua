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

function parse_set_at_key(t, key)
    local set = {}
    for _, value in ipairs(split(t[key], ";")) do
        table.insert(set, value)
    end
    return set
end

function find_input_and_outputs(si1, si2)
    local prop1 = get_props(si1)

    if prop1["item.node.direction"] == "output" then
        -- playback
        Log.info("it is playback")
        return {
            ["in"] = si2,
            ["out"] = si1
        }
    else
        -- capture
        Log.info("it is capture")
        return {
            ["in"] = si1,
            ["out"] = si2
        }
    end

end

function establish_link (t)
    local out_si = t["out"]
    local in_si = t["in"]

    local out_props = get_props(out_si)
    local in_props = get_props(in_si)

    Log.info(string.format("link %s <-> %s", tostring(out_props["node.name"]), tostring(in_props["node.name"])))

    -- create and configure link
    local link = SessionItem ( "si-standard-link" )
    if not link:configure {
        ["in.node.name"]          = in_props["node.name"],
        ["out.node.name"]         = out_props["node.name"],
        ["out.item"]              = out_si,
        ["in.item"]               = in_si,
        ["out.item.port.context"] = "output",
        ["in.item.port.context"]  = "input",
        ["target.media.class"]    = in_props["media.class"],
        ["item.plugged.usec"]     = out_props["item.plugged.usec"],
        ["media.user.managed"]    = true,
        -- ["is.policy.endpoint.client.link"] = true,
    } then
        Log.warning (link, "failed to configure si-standard-link")
        return
    else 
        Log.info (link, "si-standard-link configured successfully")
    end

    -- register
    link:register()
    link:activate(Feature.SessionItem.ACTIVE, function (l, e)
        props = l.properties
        out_name = props["out.node.name"]
        in_name = props["in.node.name"]
        msg = string.format("link %s <-> %s", out_name, in_name)
        if e then
          Log.info (l, "failed to activate si-standard-link ".. msg .. ": " .. tostring(e))
          l:remove ()
        else
          Log.info (l, "activated si-standard-link " .. msg)
        end
      end)
end

function target_has_expected_media_class(items, mediaclass)
    for _,target in ipairs(items) do
        local np = get_props(target)
        if np["media.class"] == mediaclass then
            return target
        end
    end
    return nil
end

function find_target_nodes_by_roles_and_media_class(key, lookup_roles, lookup_media_classes)
    local targets = {}
    for _, lookup_role in ipairs(lookup_roles) do
        local collected = {}
        for target in host_om:iterate() do
            local np =  get_props(target)
            local name = np["node.name"]
            if np[key] then
                Log.info("checking target node: " .. name)

                local roles = parse_set_at_key(np, key)
                for _,item in pairs(roles) do
                    Log.info("..  with role: " .. item)
                end

                if contains(roles, lookup_role) then
                    Log.info("found target node by role: " .. name)
                    table.insert(collected, target)
                end
            else
                Log.info("skinning node: " .. name)
            end
        end

        for _, lookup_media_class in ipairs(lookup_media_classes) do
            Log.info("..  with media class: " .. lookup_media_class)
            local target = target_has_expected_media_class(collected, lookup_media_class)
            if target then
                Log.info("..  found target node by media class: " .. target.properties["node.name"])
                table.insert(targets, target)
                break
            end
        end

    end
    return targets
end

function find_target_nodes_by_name(lookup_node_name, hosts_om)
    local lookup_node_names = split(lookup_node_name, ";")
    local targets = {}
    for target in hosts_om:iterate() do
        local p = get_props(target)
        local name = p["node.name"]
        if name and contains(lookup_node_names, name) then
            table.insert(targets,target)
        end
    end
    return targets
end

function find_existing_links(si, links_om)
    local visited = {}
    for link in links_om:iterate() do
        local out_id = tonumber(link.properties["out.item.id"])
        local in_id  = tonumber(link.properties["in.item.id"])
        local out_name = link.properties["out.node.name"]
        local in_name = link.properties["in.node.name"]

        if out_id == si.id or in_id == si.id then
            Log.info("already linked: " .. out_name .. " <-> " .. in_name)
        end

        if out_id == si.id then
            visited[link.properties["out.item.id"]] = link
        elseif in_id == si.id then
            visited[link.properties["in.item.id"]] = link
        end
    end
    return visited
end

function get_target_media_classes(si)
    local np = get_props(si)
    local media_class = np["media.class"]
    local media_classes = {
        ["Audio/Source"] = { "Audio/Source/Virtual" },
        ["Stream/Output/Audio"] = { "Audio/Sink" },

        ["Audio/Sink"] = { "Audio/Sink" },
        ["Stream/Input/Audio"] = { "Audio/Source/Virtual" }
    }
    return media_classes[media_class] or {}
end

function get_props(si)
    local si_np = si.properties
    if (si_np["media.user.role"] or si_np["media.user.target.role"]) and si_np["media.class"] then
        return si_np
    else
    local node = si:get_associated_proxy("node")
    return node.properties
    end
end

function create_node_link(from_si, lookup_key, target_key)
    Log.info("handling linkable: ".. from_si.id)
    Log.info(".. si properties: ")
    for key, value in pairs(from_si.properties) do
        Log.info(".... " .. key .. ": " .. value)
    end

    local from_props = get_props(from_si)
    local name = from_props['node.name']
    Log.info(".. node name: " .. name)
    
    Log.info(".. node properties: ")
    for key, value in pairs(from_props) do
        Log.info(".... " .. key .. ": " .. value)
    end

    local lookup_roles = parse_set_at_key(from_props, lookup_key)
    for _, item in ipairs(lookup_roles) do
        Log.info("..  with expected target role: " .. item)
    end

    local lookup_media_classes = get_target_media_classes(from_si)
    Log.info(".. looking for media classes: " .. table.concat(lookup_media_classes, ", "))

    local visited = find_existing_links(from_si, links_om)

    Log.info("connecting nodes to " .. name)
    for _, to_si in ipairs(find_target_nodes_by_roles_and_media_class(target_key, lookup_roles, lookup_media_classes)) do
        local p = get_props(to_si)
        local to_si_name = p["node.name"]
        if not visited[to_si.id] then
            Log.info(".. with target " .. to_si_name)
            establish_link(find_input_and_outputs(from_si, to_si))
        else
            Log.info(".. skipping node " .. to_si_name .. ", as already connected")
        end
    end

    local lookup_node_name = from_props["media.user.target.object.name"] or ""
    for _, to_si in ipairs(find_target_nodes_by_name(lookup_node_name, host_om)) do
        local p = get_props(to_si)
        local to_si_name = p["node.name"]
        if not visited[to_si.id] then
            Log.info(".. with target " .. to_si_name)
            local t = {
                ['out'] = from_si,
                ['in'] = to_si,
            }
            establish_link(t)
        else
            Log.info(".. skipping node " .. to_si_name .. ", as already connected")
        end
    end
    
end

function unhandle_linkable(si, is_all)
    local props = get_props(si)
    Log.info(string.format("user-config: unhandling item: %s (%s)", tostring(props["node.name"]), tostring(si.id)))
    local visited = find_existing_links(si, links_om)
    for id, silink in pairs(visited) do
        if (is_all or not silink.properties["media.user.managed"]) then
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
        unhandle_linkable(client_si, false)
        create_node_link(client_si, "media.user.target.role", "media.user.role")
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
        unhandle_linkable(si, false)
        create_node_link(si, "media.user.target.role", "media.user.role")
    end
end)

client_om:connect("object-added", function (om, si)
    Log.info(si, "client linkable added")
    unhandle_linkable(si, false)
    create_node_link(si, "media.user.target.role", "media.user.role")
end)

client_om:connect("object-removed", function(om, si)
    Log.info(si, "client linkable removed")
    unhandle_linkable(si, true)
end)

client_om:activate()
