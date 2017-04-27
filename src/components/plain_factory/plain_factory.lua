plain_factory = {}

local interface_instances = {}

function plain_factory:new(iface_name)
    local iface = require_c("interface_" .. iface_name)
    if not iface then
        return false, "Unknown interface iface_name"
    end
    local id = self:get_id(iface)
    interface_instances[id] = iface
    return true, id
end

function plain_factory:get(id)
    return interface_instances[id]
end

function plain_factory:del(id)
    interface_instances[id] = nil
end

function plain_factory:get_id(iface)
    local str = tostring(iface)
    local _, id_pos = string.find(str, "0x")
    return string.sub(str, id_pos + 1)
end
