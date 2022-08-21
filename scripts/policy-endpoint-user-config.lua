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

-- function intersect(m,n)
--     for item, _  in pairs(m) do
--         Log.info("checking item: " .. item .. " result: " .. tostring(n[item] ~= nil))
--         if n[item] then
--             return true
--         end
--     end
--     return false
-- end

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
        ["media.user.managed"] = true
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

function findTargetWithMediaClass(items, mediaclass)
    for _,target in ipairs(items) do
        local node = target:get_associated_proxy("node")
        if node.properties["media.class"] == mediaclass then
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
            local node_name = target.properties["node.name"]
            if target.properties[key] then
                local node = target:get_associated_proxy("node")
                local props = node.properties
                Log.info("checking target node: " .. node_name)

                local roles = parseSetAt(props, key)
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

function findExistingLinks(si)
    local si_id = si.id
    local visited = {}
    for link in links_om:iterate() do
        local out_id = tonumber(link.properties["out.item.id"])
        local in_id  = tonumber(link.properties["in.item.id"])
        if out_id == si_id or in_id == si_id then
            Log.info("already linked: " .. in_id .. " <-> " .. out_id)
        end
        if out_id == si_id then
            table.insert(visited, link.properties["out.item.id"], link)
        elseif in_id == si_id then
            table.insert(visited, link.properties["in.item.id"], link)
        end
    end
    return visited
end

function possibleTargetMediaClasses(si)
    local media_class = si.properties["media.class"]
    local media_classes = {
        ["Audio/Source"] = { "Audio/Source/Virtual", "Audio/Sink"},
        ["Stream/Output/Audio"] = { "Audio/Sink" },

        ["Audio/Sink"] = { "Audio/Source/Virtual", "Audio/Source" },
        ["Stream/Input/Audio"] = { "Audio/Source" }
    }
    return media_classes[media_class] or {}
end

function createNodeLink(si, lookup_key, target_key)
    Log.info("handling linkable: " .. si.id)
    local node = si:get_associated_proxy("node")
    
    
    Log.info(".. properties: ")
    for key, value in pairs(node.properties) do
        
        Log.info(".. " .. key .. ": " .. value)
    end

    local lookup_roles = parseSetAt(node.properties, lookup_key)
    for _, item in ipairs(lookup_roles) do
        Log.info("..  with expected target role: " .. item)
    end
    

    local node = si:get_associated_proxy("node")
    local node_name = node.properties['node.name']
    Log.info(".. node name: " .. node_name)

    local lookup_media_classes = possibleTargetMediaClasses(si)
    Log.info(".. looking for media classes: " .. table.concat(lookup_media_classes, ", "))

    local visited = findExistingLinks(si)
    Log.info(".. visited nodes: " .. table.concat(visited, ", "))

    local targets = findTargetNodes(target_key, lookup_roles, lookup_media_classes)

    -- for _, target in ipairs(targets) do 
    --     Log.info(".. discovered target node: " .. target.properties["node.name"])
    -- end
    
    Log.info("connecting nodes to " .. node_name)
    for _, target in ipairs(targets) do
        local target_node_id = target.id
        local target_node = target:get_associated_proxy("node")
        local target_node_name = target_node.properties["node.name"]
        if not visited[target_node_id] then
            Log.info(".. with target " .. target_node_name)
            createLink(si, target)
        else
            Log.info(".. skipping node " .. target_node_name .. ", as already connected")
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
    Log.info(si, "hub linkable added")
end)

host_om:connect("object-removed", function(om, si)
    Log.info(si, "hub linkable removed")
end)

host_om:activate()

client_om = ObjectManager {
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.target.role", "is-present"},
    }
}

client_om:connect("object-added", function (om, si)
    createNodeLink(si, "media.user.target.role", "media.user.role")
end)

client_om:connect("object-removed", function(om, si)
    local node = si:get_associated_proxy("node")
    local props = node.properties
    Log.info(string.format("user-config: unhandling item: %s (%s)", tostring(props["node.name"]), tostring(props["node.id"])))
    -- remove any links associated with this item
    for silink in links_om:iterate() do
        local out_id = tonumber (silink.properties["out.item.id"])
        local in_id = tonumber (silink.properties["in.item.id"])
        if out_id == props["node.id"] or in_id == props["node.id"] then
            silink:remove ()
            Log.info (silink, "... link removed")
        end
    end
end)

client_om:activate()
