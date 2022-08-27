local config = ... or {}

ActiveStatus = Feature.SessionItem.ACTIVE

function MakeItem(type)
    return SessionItem(type)
end

function LogInfo(msg)
    Log.info(msg)
end

function LogWarn(msg)
    Log.warning(msg)
end

function Contains(t, key)
    for _, value in ipairs(t) do
        if key == value then
            return true
        end
    end
    return false
end

function Split(s, delimiter)
    local result = {}
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match)
    end
    return result;
end

function ParseSetAtKey(t, key)
    local set = {}
    for _, value in ipairs(Split(t[key], ";")) do
        table.insert(set, value)
    end
    return set
end

function FindInputAndOutputs(si1, si2)
    local prop1 = GetProps(si1)

    if prop1["item.node.direction"] == "output" then
        -- playback
        LogInfo("it is playback")
        return {
            ["in"] = si2,
            ["out"] = si1
        }
    else
        -- capture
        LogInfo("it is capture")
        return {
            ["in"] = si1,
            ["out"] = si2
        }
    end

end

function EstablishLink (t)
    local out_si = t["out"]
    local in_si = t["in"]

    local out_props = GetProps(out_si)
    local in_props = GetProps(in_si)

    LogInfo(string.format("link %s <-> %s", tostring(out_props["node.name"]), tostring(in_props["node.name"])))

    -- create and configure link
    local link = MakeItem( "si-standard-link" )
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
        LogWarn("failed to configure si-standard-link")
        return
    else
        LogInfo("si-standard-link configured successfully")
    end

    -- register
    link:register()
    link:activate(ActiveStatus, function (l, e)
        local props = l.properties
        local out_name = props["out.node.name"]
        local in_name = props["in.node.name"]
        local msg = string.format("link %s <-> %s", out_name, in_name)
        if e then
          LogInfo("failed to activate si-standard-link ".. msg .. ": " .. tostring(e))
          l:remove ()
        else
          LogInfo("activated si-standard-link " .. msg)
        end
      end)
end

function TargetHasExpectedMediaClass(items, mediaclass)
    for _,target in ipairs(items) do
        local np = GetProps(target)
        if np["media.class"] == mediaclass then
            return target
        end
    end
    return nil
end

function FindTargetNodesByRolesAndMediaClass(key, lookup_roles, lookup_media_classes)
    local targets = {}
    for _, lookup_role in ipairs(lookup_roles) do
        local collected = {}
        for target in HostOM:iterate() do
            local np =  GetProps(target)
            local name = np["node.name"]
            if np[key] then
                LogInfo("checking target node: " .. name)

                local roles = ParseSetAtKey(np, key)
                for _,item in pairs(roles) do
                    LogInfo("..  with role: " .. item)
                end

                if Contains(roles, lookup_role) then
                    LogInfo("found target node by role: " .. name)
                    table.insert(collected, target)
                end
            else
                LogInfo("skinning node: " .. name)
            end
        end

        for _, lookup_media_class in ipairs(lookup_media_classes) do
            LogInfo("..  with media class: " .. lookup_media_class)
            local target = TargetHasExpectedMediaClass(collected, lookup_media_class)
            if target then
                LogInfo("..  found target node by media class: " .. target.properties["node.name"])
                table.insert(targets, target)
                break
            end
        end

    end
    return targets
end

function FindTargetNodesByName(lookup_node_name, hosts_om)
    local lookup_node_names = Split(lookup_node_name, ";")
    local targets = {}
    for target in hosts_om:iterate() do
        local p = GetProps(target)
        local name = p["node.name"]
        if name and Contains(lookup_node_names, name) then
            table.insert(targets,target)
        end
    end
    return targets
end

function FindExistingLinks(si, links_om)
    local visited = {}
    for link in links_om:iterate() do
        local out_id = tonumber(link.properties["out.item.id"])
        local in_id  = tonumber(link.properties["in.item.id"])
        local out_name = link.properties["out.node.name"]
        local in_name = link.properties["in.node.name"]

        if out_id == si.id or in_id == si.id then
            LogInfo("already linked: " .. out_name .. " <-> " .. in_name)
        end

        if out_id == si.id then
            visited[link.properties["out.item.id"]] = link
        elseif in_id == si.id then
            visited[link.properties["in.item.id"]] = link
        end
    end
    return visited
end

function GetTargetMediaClasses(si)
    local np = GetProps(si)
    local media_class = np["media.class"]
    local media_classes = {
        ["Audio/Source"] = { "Audio/Source/Virtual" },
        ["Stream/Output/Audio"] = { "Audio/Sink" },

        ["Audio/Sink"] = { "Audio/Sink" },
        ["Stream/Input/Audio"] = { "Audio/Source/Virtual" }
    }
    return media_classes[media_class] or {}
end

function GetProps(si)
    local si_np = si.properties
    if (si_np["media.user.role"] or si_np["media.user.target.role"]) and si_np["media.class"] then
        return si_np
    else
    local node = si:get_associated_proxy("node")
    return node.properties
    end
end

function CreateNodeLink(from_si, lookup_key, target_key)
    LogInfo("handling linkable: ".. from_si.id)
    LogInfo(".. si properties: ")
    for key, value in pairs(from_si.properties) do
        LogInfo(".... " .. key .. ": " .. value)
    end

    local from_props = GetProps(from_si)
    local name = from_props['node.name']
    LogInfo(".. node name: " .. name)

    LogInfo(".. node properties: ")
    for key, value in pairs(from_props) do
        LogInfo(".... " .. key .. ": " .. value)
    end

    local lookup_roles = ParseSetAtKey(from_props, lookup_key)
    for _, item in ipairs(lookup_roles) do
        LogInfo("..  with expected target role: " .. item)
    end

    local lookup_media_classes = GetTargetMediaClasses(from_si)
    LogInfo(".. looking for media classes: " .. table.concat(lookup_media_classes, ", "))

    local visited = FindExistingLinks(from_si, LinksOM)

    LogInfo("connecting nodes to " .. name)
    for _, to_si in ipairs(FindTargetNodesByRolesAndMediaClass(target_key, lookup_roles, lookup_media_classes)) do
        local p = GetProps(to_si)
        local to_si_name = p["node.name"]
        if not visited[to_si.id] then
            LogInfo(".. with target " .. to_si_name)
            EstablishLink(FindInputAndOutputs(from_si, to_si))
        else
            LogInfo(".. skipping node " .. to_si_name .. ", as already connected")
        end
    end

    local lookup_node_name = from_props["media.user.target.object.name"] or ""
    for _, to_si in ipairs(FindTargetNodesByName(lookup_node_name, HostOM)) do
        local p = GetProps(to_si)
        local to_si_name = p["node.name"]
        if not visited[to_si.id] then
            LogInfo(".. with target " .. to_si_name)
            local t = {
                ['out'] = from_si,
                ['in'] = to_si,
            }
            EstablishLink(t)
        else
            LogInfo(".. skipping node " .. to_si_name .. ", as already connected")
        end
    end
    
end

function UnhandleLinkable(si, is_all)
    local props = GetProps(si)
    LogInfo(string.format("user-config: unhandling item: %s (%s)", tostring(props["node.name"]), tostring(si.id)))
    local visited = FindExistingLinks(si, LinksOM)
    for id, silink in pairs(visited) do
        if (is_all or not silink.properties["media.user.managed"]) then
            silink:remove ()
            LogInfo("... link removed to " .. id)
        end
    end
end


LinksOM = ObjectManager {
    Interest {
        type = "SiLink",
        -- only handle links created by this policy
        Constraint { "media.user.managed", "=", true, type = "pw-global" },
    }
}

LinksOM:connect("object-added", function(om, si)
    LogInfo("hub link added: "  .. si.id)
end)

LinksOM:connect("object-removed", function(om, si)
    LogInfo("hub link removed: "  .. si.id)
end)

LinksOM:activate()

HostOM = ObjectManager {
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.role", "is-present" },
    }
}

HostOM:connect("object-added", function(om, si)
    LogInfo("host linkable added: "  .. si.id)
    for client_si in ClientOM:iterate() do
        UnhandleLinkable(client_si, false)
        CreateNodeLink(client_si, "media.user.target.role", "media.user.role")
    end
end)

HostOM:connect("object-removed", function(om, si)
    LogInfo("host linkable removed: " .. si.id)
end)

HostOM:activate()

 ClientOM = ObjectManager {
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.target.role", "is-present"},
    }
}

ClientOM:connect("objects-changed", function (om)
    for si in om:iterate() do
        UnhandleLinkable(si, false)
        CreateNodeLink(si, "media.user.target.role", "media.user.role")
    end
end)

ClientOM:connect("object-added", function (om, si)
    LogInfo("client linkable added: " .. si.id)
    UnhandleLinkable(si, false)
    CreateNodeLink(si, "media.user.target.role", "media.user.role")
end)

ClientOM:connect("object-removed", function(om, si)
    LogInfo("client linkable removed: " .. si.id)
    UnhandleLinkable(si, true)
end)

ClientOM:activate()
