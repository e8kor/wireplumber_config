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

ApplicationOM = ObjectManager {
    Interest {
        type = "SiLinkable",
        -- only handle si-audio-adapter and si-node
        Constraint { "media.user.target.role", "is-absent" },
        Constraint { "media.user.role", "is-absent" },
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
            if type(k) == 'number'
            then x = x .. ToString(v)
            else x = '["'..k..'"] = ' .. ToString(v)
            end
            if s ~= ''
            then s = s .. ', '
            end
            s = s .. x
        end
        return '{ ' .. s .. ' } '
    else
        return tostring(o)
    end
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
    local safe = string or ""
    for match in (safe .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result;
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
        -- LogInfo("checking rule: " .. ToString(r))
        if r.apply_properties then
            for _, interest in ipairs(r.interests) do
                -- LogInfo(".... checking interest: " .. ToString(interest))
                if interest:matches(properties) then
                    has_match = true
                    for k, v in pairs(r.apply_properties) do
                        -- LogInfo("inserting property with " .. k .. ": " .. v)
                        properties[k] = v
                    end
                end
            end
        end
    end
    if has_match == false then
        -- LogInfo("no interests matched, applying fallback properties")
        for k, v in pairs(config.fallback) do
            if not properties[k] then
                -- LogInfo("inserting fallback property with " .. k .. ": " .. v)
                properties[k] = v
            end
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

    LogInfo(string.format("establishing link %s <-> %s", out_name, in_name))

    -- create and configure link
    local link = SessionItem("si-standard-link")
    if not link:configure {
        ["in.node.name"]          = in_name,
        ["in.item.port.context"]  = "input",
        ["in.item"]               = in_si,
        ["out.node.name"]         = out_name,
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

function FindExistingLinksForLinkable(si)
    local links = {}
    local si_name = GetName(si)
    for link in LinksOM:iterate{
        Constraint { "out.node.name", "equals", si_name },
    } do
        table.insert(links, link)
    end

    for link in LinksOM:iterate{
        Constraint { "in.node.name", "equals", si_name },
    } do
        table.insert(links, link)
    end
    return links
end

function GetLookupMediaClassFromLinkable(si)
    local props = GetProperties(si)
    local media_class = props["media.class"]
    local media_classes = {
        ["Audio/Source"] = { "Audio/Source/Virtual" },
        ["Stream/Output/Audio"] = { "Audio/Sink", "Stream/Input/Audio" },

        ["Audio/Sink"] = { "Audio/Sink" },
        ["Stream/Input/Audio"] = { "Audio/Source/Virtual", "Stream/Output/Audio" }
    }
    return media_classes[media_class] or {}
end

function IsHubToHubOrSelfLink(si1, si2)
    local si1_prop = GetProperties(si1)
    local si2_prop = GetProperties(si2)
    local isSelfLink = si1.id == si2.id
    local isHubToHub = string.find(si1_prop["node.description"] or "", "Hub") and string.find(si2_prop["node.description"] or "", "Hub")
    return isSelfLink or isHubToHub
end

function FindByPropName(prop_name, keywords, om, targets)
    for _, keyword in ipairs(keywords) do
        if keyword and keyword ~= "" then
            for si in om:iterate{
                Constraint { prop_name, "matches", '*' .. keyword .. '*' },
            } do
                local name = GetName(si)
                LogInfo("queueing target node: " .. name)
                table.insert(targets, si)
            end
        end
    end
    return targets
end

function CreateNodeLink(client_si)
    local from_name = GetName(client_si)
    LogInfo("Creating links for linkable node: " .. from_name)
    -- LogInfo(".. si properties: ")
    -- for key, value in pairs(from_si.properties) do
    --     LogInfo(".... " .. key .. ": " .. value)
    -- end

    local from_props = GetProperties(client_si)
    -- LogInfo(".. node properties: ")
    -- for key, value in pairs(from_props) do
    --     LogInfo(".... " .. key .. ": " .. value)
    -- end

    local lookup_media_classes = GetLookupMediaClassFromLinkable(client_si) or {}
    LogInfo(".. looking for media classes: " .. ToString(lookup_media_classes))
    

    local lookup_roles = SplitStringByDelimiter(from_props["media.user.target.role"], ";") or {}
    LogInfo(".. looking for media roles " .. ToString(lookup_roles))

    local lookup_node_names = SplitStringByDelimiter(from_props["media.user.target.node.name"], ";") or {}
    LogInfo(".. looking for user node names: " .. ToString(lookup_node_names))

    local role_node_names = SplitStringByDelimiter(from_props["media.user.target.role.node.name"], ";") or {}
    LogInfo(".. looking for role.node.name: " .. ToString(role_node_names))

    local targets = {}
    for _, lookup_role in ipairs(lookup_roles) do
        local cons = {}
        table.insert(cons, Constraint { "media.user.role", "matches", '*' .. lookup_role .. '*' })
        if next(lookup_media_classes) ~= nil then
            table.insert(cons,  Constraint { "media.class", "in-list", table.unpack(lookup_media_classes) } )
        end
        for si in HostOM:iterate{table.unpack(cons)} do
            local to_name = GetName(si)
            if not IsHubToHubOrSelfLink(client_si, si) then
                LogInfo("adding target node: " .. to_name)
                LogInfo(".. with role: " .. si.properties["media.user.role"])
                LogInfo(".. with media class: " .. si.properties["media.class"])

                table.insert(targets, MatchInputToOutput(client_si, si))
            end
        end
    end

    local by_role_node_name = {}
    by_role_node_name = FindByPropName("node.name", role_node_names, ApplicationOM, by_role_node_name)

    for _, si in ipairs(by_role_node_name) do
        local to_name = GetName(si)
            LogInfo("adding target node: " .. to_name)
            table.insert(targets, MatchInputToOutput(client_si, si))
    end

    local by_node_name = {}
    by_node_name = FindByPropName("node.name", lookup_node_names, HostOM, by_node_name)
    by_node_name = FindByPropName("node.name", lookup_node_names, DevicesOM, by_node_name)
    by_node_name = FindByPropName("node.name", lookup_node_names, ApplicationOM, by_node_name)

    for _, si in ipairs(by_node_name) do
        local to_name = GetName(si)
        LogInfo("adding target node: " .. to_name)
        local t = {
            ['out'] = si,
            ['in'] = client_si,
        }
        table.insert(targets, t)
    end

    local visited = FindExistingLinksForLinkable(client_si)

    for _, details in ipairs(targets) do
        local to_si_name = GetName(details['in'])
        if not visited[to_si_name] then
            EstablishLink(details)
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
    local visited = FindExistingLinksForLinkable(si)
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


HostOM:connect("object-added", function(om, si)
    LogInfo("Host linkable added: " .. si.id)
    RemoveLinksFromLinkable(si, false)
    -- for si in DevicesOM:iterate() do
    --     RemoveLinksFromLinkable(si, false)
    --     CreateNodeLink(si)
    -- end
end)

HostOM:connect("object-removed", function(om, si)
    local name = GetName(si)
    LogInfo("Host linkable removed: " .. name)
end)

DevicesOM:connect("object-added", function(om, si)
    local name = GetName(si)
    LogInfo("Linking user managed new device: " .. name)
    -- RemoveLinksFromLinkable(si, true)
    CreateNodeLink(si)
end)

DevicesOM:connect("objects-changed", function(om)
    LogInfo("Managed device changed")
    -- for si in om:iterate() do
    --     RemoveLinksFromLinkable(si, false)
    --     CreateNodeLink(si)
    -- end
end)

DevicesOM:connect("object-removed", function(om, si)
    local name = GetName(si)
    LogInfo("Unlinking user managed device removed: " .. name)
    RemoveLinksFromLinkable(si, true)
end)

ApplicationOM:connect("objects-changed", function(om)
    LogInfo("Linking returning non user managed application")
    for si in om:iterate() do
        -- RemoveLinksFromLinkable(si, false)
        CreateNodeLink(si)
    end
end)

ApplicationOM:connect("object-added", function(om, si)
    local name = GetName(si)
    LogInfo("Linking non user managed new application: " .. name)
    -- RemoveLinksFromLinkable(si, true)
    CreateNodeLink(si)
end)

ApplicationOM:connect("object-removed", function(om, si)
    local name = GetName(si)
    LogInfo("Unlinking non user managed application: " .. name)
    RemoveLinksFromLinkable(si, true)
end)

HostOM:activate()
LinksOM:activate()
DevicesOM:activate()
ApplicationOM:activate()
