plain_factory = {}

function plain_factory:new(iface_name)
    iface_t = "server_" .. iface_name
    if iface_t == nil then
        return false, "Unknown interface type: " .. iface_name
    end
    local status, iface = pcall(iface_t)
    if not status then
        return false, iface
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
