local config = ... or {}

for _, r in ipairs(config.rules or {}) do
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

ActiveStatus = Feature.SessionItem.ACTIVE

HostOM = ObjectManager {
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.role", "is-present" },
    }
}

LinksOM = ObjectManager {
    Interest {
        type = "SiLink",
        -- only handle links created by this policy
        Constraint { "media.user.managed", "=", true, type = "pw-global" },
    }
}

DevicesOM = ObjectManager {
    Interest {
        type = "SiLinkable",
        Constraint { "media.user.target.role", "is-present" },
    }
}
linkables_om = ObjectManager {
    Interest {
      type = "SiLinkable",
      -- only handle si-audio-adapter and si-node
      Constraint { "item.factory.name", "c", "si-audio-adapter", "si-node" },
      Constraint { "active-features", "!", 0, type = "gobject" },
    }
  }
ApplicationOM = ObjectManager {
    Interest {
        type = "SiLinkable",
        -- only handle si-audio-adapter and si-node
        Constraint { "item.factory.name", "c", "si-audio-adapter", "si-node" },
        Constraint { "active-features", "!", 0, type = "gobject" },
      }
}

function LogInfo(msg)
    Log.info(msg)
end

function LogWarn(msg)
    Log.warning(msg)
end

function ToString(o)
    if type(o) == 'table' then
        local s = ''
        for k,v in pairs(o) do
            local x = ''
            if type(k) == 'number' then
                x = x .. ToString(v)
            else
                x = '["'..k..'"] = ' .. ToString(v)
            end
            if s ~= '' then
                s = s .. ', '
            end
            s = s .. x
        end
        return '{ ' .. s .. ' } '
    else
        return tostring(o)
    end
end

function MakeItem(type)
    return SessionItem(type)
end

function SetContainsValue(set, value)
    for _, entry in ipairs(set) do
        if value == entry then
            return true
        end
    end
    return false
end

function SplitStringByDelimiter(string, delimiter)
    local result = {}
    for match in (string .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result;
end

function FindValueSetByKey(properties, key)
    local set = {}
    if properties[key] then
        for _, value in ipairs(SplitStringByDelimiter(properties[key], ";")) do
            table.insert(set, value)
        end
    end
    return set
end

function GetName(si)
    local si_id = ToString(si.id)
    local node = si:get_associated_proxy("node")
    local node_props = node.properties
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

function GetProperties(si_linkable)
    local props = si_linkable.properties
    local result = {}
    if (
        props and
        props["media.class"] and
        props["media.user.role"] or
        props["media.user.target.role"]
    ) then result = props
    else
        local node = si_linkable:get_associated_proxy("node")
        result = node.properties
    end
    result = InsertExtras(result)
    return result or {}
end

function InsertExtras(properties)
    local has_match = false
    for _, r in ipairs(config.rules or {}) do
        LogInfo("checking rule: " .. ToString(r))
        if r.apply_properties then
            for _, interest in ipairs(r.interests) do
                LogInfo(".... checking interest: " .. ToString(interest))
                if interest:matches(properties) then
                    has_match = true
                    for k, v in pairs(r.apply_properties) do
                        LogInfo("inserting property with " .. k .. ": " .. v)
                        properties[k] = v
                    end
                end
            end
        end
    end
    if has_match == false then
        for k, v in pairs(config.fallback) do
            -- LogInfo("inserting fallback property with " .. k .. ": " .. v)
            properties[k] = v
        end
    end
    return properties
end

function MatchInputToOutput(si1, si2)
    local props = GetProperties(si1)
    if props["item.node.direction"] == "output" or
       props["media.class"] == "Stream/Output/Audio"
    then
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

function EstablishLink(connection)
    local out_si = connection["out"]
    local in_si = connection["in"]

    local out_props = GetProperties(out_si)
    local in_props = GetProperties(in_si)
    local out_name = GetName(out_si)
    local in_name = GetName(in_si)

    LogInfo(string.format("establishin link %s <-> %s", out_name, in_name))

    -- create and configure link
    local link = MakeItem("si-standard-link")
    if not link:configure {
        ["in.node.name"]          = in_props["node.name"],
        ["in.item.port.context"]  = "input",
        ["in.item"]               = in_si,
        ["out.node.name"]         = out_props["node.name"],
        ["out.item.port.context"] = "output",
        ["out.item"]              = out_si,
        ["item.plugged.usec"]     = out_props["item.plugged.usec"],
        ["target.media.class"]    = in_props["media.class"],
        ["media.user.managed"]    = true,
        -- ["passive"] = false,
        -- ["passthrough"] = false,
        -- ["exclusive"] = true,
        -- ["is.policy.item.link"] = true,
        -- ["is.policy.endpoint.client.link"] = true,
    } then
        LogWarn("failed to configure si-standard-link")
        return
    else
        LogInfo("si-standard-link configured successfully")
    end

    -- register
    link:register()
    link:activate(ActiveStatus, function(l, e)
        local props = l.properties
        local out_name = props["out.node.name"]
        local in_name = props["in.node.name"]
        local msg = string.format("activating link %s <-> %s", out_name, in_name)
        if e then
            LogInfo("failed to activate si-standard-link " .. msg .. ": " .. ToString(e))
            l:remove()
        else
            LogInfo("activated si-standard-link " .. msg)
        end
    end)
end

function FindTargetNodesByRolesAndMediaClass(key, lookup_roles, lookup_media_classes)
    local targets = {}
    for _, lookup_role in ipairs(lookup_roles) do
        local collected = {}
        for target in HostOM:iterate() do
            local props = GetProperties(target)
            local name = GetName(target)
            LogInfo("checking target node: " .. name)
            local roles = FindValueSetByKey(props, key)

            -- for _, item in pairs(roles) do
            -- end
            LogInfo("..  with roles: " .. ToString(roles))

            if SetContainsValue(roles, lookup_role) then
                LogInfo("found target node by role: " .. name)
                table.insert(collected, target)
            end

        end

        for _, lookup_media_class in ipairs(lookup_media_classes) do
            LogInfo("..  with media class: " .. lookup_media_class)
            for _, target in ipairs(collected) do
                local props = GetProperties(target)
                local name = GetName(target)
                if props["media.class"] == lookup_media_class then
                    LogInfo("..  found target node by media class: " .. name)
                    table.insert(targets, target)
                    break
                end
            end
        end

    end
    return targets
end

function FindTargetNodesByName(lookup_node_name, om)
    local lookup_node_names = SplitStringByDelimiter(lookup_node_name, ";")
    local targets = {}
    for target in om:iterate() do
        local name = GetName(target)
        if name and SetContainsValue(lookup_node_names, name) then
            table.insert(targets, target)
        end
    end
    return targets
end

function FindExistingLinksForLinkable(si, om)
    local visited = {}
    local si_id = ToString(si.id)
    for link in om:iterate() do
        local out_id   = ToString(link.properties["out.item.id"])
        local in_id    = ToString(link.properties["in.item.id"])

        if out_id == si_id or in_id == si_id then
            local out_name = link.properties["out.node.name"]
            local in_name  = link.properties["in.node.name"]
            LogInfo("found link: " .. out_name .. " <-> " .. in_name)
        end

        if out_id == si_id then
            visited[out_id] = link
        elseif in_id == si_id then
            visited[in_id] = link
        end
    end
    return visited
end

function GetLookupMediaClassFromLinkable(si)
    local props = GetProperties(si)
    local media_class = props["media.class"]
    local media_classes = {
        ["Audio/Source"] = { "Audio/Source/Virtual" },
        ["Stream/Output/Audio"] = { "Audio/Sink" },

        ["Audio/Sink"] = { "Audio/Sink" },
        ["Stream/Input/Audio"] = { "Audio/Source/Virtual" }
    }
    return media_classes[media_class] or {}
end

function CreateNodeLink(from_si, lookup_key, target_key)
    local name = GetName(from_si)
    LogInfo("Creating links for linkable node: " .. name)
    -- LogInfo(".. si properties: ")
    -- for key, value in pairs(from_si.properties) do
    --     LogInfo(".... " .. key .. ": " .. value)
    -- end

    local from_props = GetProperties(from_si)
    -- LogInfo(".. node properties: ")
    -- for key, value in pairs(from_props) do
    --     LogInfo(".... " .. key .. ": " .. value)
    -- end

    local lookup_roles = FindValueSetByKey(from_props, lookup_key)
    LogInfo(".. with expected target role: " .. ToString(lookup_roles))

    local lookup_media_classes = GetLookupMediaClassFromLinkable(from_si)
    LogInfo(".. looking for media classes: " .. ToString(lookup_media_classes))

    local visited = FindExistingLinksForLinkable(from_si, LinksOM)

    LogInfo("connecting nodes to " .. name)
    for _, to_si in ipairs(FindTargetNodesByRolesAndMediaClass(target_key, lookup_roles, lookup_media_classes)) do
        local to_si_name = GetName(to_si)
        if not visited[to_si.id] then
            LogInfo(".. with target " .. to_si_name)
            EstablishLink(MatchInputToOutput(from_si, to_si))
        else
            LogInfo(".. skipping node " .. to_si_name .. ", as already connected")
        end
    end

    local lookup_node_name = from_props["media.user.target.object.name"] or ""
    for _, to_si in ipairs(FindTargetNodesByName(lookup_node_name, HostOM)) do
        local to_si_name = GetName(to_si)
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

function RemoveLinksFromLinkable(si, is_all)
    local props = GetProperties(si)
    local link_type = "own"
    if is_all then
        link_type = "all"
    end
    local name = GetName(si)
    LogInfo(string.format("Unhandling %s links for item: %s", link_type, name))
    local visited = FindExistingLinksForLinkable(si, LinksOM)
    for id, link in pairs(visited) do
        local is_user_managed = link.properties["media.user.managed"]
        if (is_all or not is_user_managed) then
            link:remove()
            LogInfo("... link removed to " .. id)
        end
    end
end

LinksOM:connect("object-added", function(om, si)
    LogInfo("Link was added: " .. si.id)
end)

LinksOM:connect("object-removed", function(om, si)
    LogInfo("Link was removed: " .. si.id)
end)

LinksOM:activate()

HostOM:connect("object-added", function(om, si)
    LogInfo("Host linkable added: " .. si.id)
    for client_si in DevicesOM:iterate() do
        RemoveLinksFromLinkable(client_si, false)
        CreateNodeLink(client_si, "media.user.target.role", "media.user.role")
    end
end)

HostOM:connect("object-removed", function(om, si)
    local name = GetName(si)
    LogInfo("Host linkable removed: " .. name)
end)

HostOM:activate()


DevicesOM:connect("object-added", function(om, si)
    local name = GetName(si)
    LogInfo("Linking user managed new device: " .. name)
    RemoveLinksFromLinkable(si, true)
    CreateNodeLink(si, "media.user.target.role", "media.user.role")
end)

DevicesOM:connect("objects-changed", function(om)
    for si in om:iterate() do
        RemoveLinksFromLinkable(si, false)
        CreateNodeLink(si, "media.user.target.role", "media.user.role")
    end
end)

DevicesOM:connect("object-removed", function(om, si)
    local name = GetName(si)
    LogInfo("Unlinking user managed device removed: " .. name)
    RemoveLinksFromLinkable(si, true)
end)

DevicesOM:activate()

ApplicationOM:connect("objects-changed", function(om)
    LogInfo("Linking returning non user managed application")
    for si in om:iterate() do
        RemoveLinksFromLinkable(si, false)
        CreateNodeLink(si, "media.user.target.role", "media.user.role")
    end
end)

ApplicationOM:connect("object-added", function(om, si)
    local name = GetName(si)
    LogInfo("Linking non user managed new application: " .. name)
    RemoveLinksFromLinkable(si, true)
    CreateNodeLink(si, "media.user.target.role", "media.user.role")
end)

ApplicationOM:connect("object-removed", function(om, si)
    local name = GetName(si)
    LogInfo("Unlinking non user managed application: " .. name)
    RemoveLinksFromLinkable(si, true)
end)

ApplicationOM:activate()
