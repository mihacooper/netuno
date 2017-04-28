plain_factory = {
    interface_instances = {}
}

function plain_factory:new(iface_name)
    print("plain_factory() ", iface_name)
    local iface = require_c("interface_" .. iface_name)
    if not iface then
        return false, "Unknown interface " .. iface_name
    end
    local id = self:get_id(iface)
    self.interface_instances[id] = iface
    print("plain_factory= ", id)
    print("plain_factory: ", tostring(iface))
    return true, id
end

function plain_factory:get(id)
    print("plain_factory::", "'"..id.."'", self.interface_instances[id])
    for k,v in pairs(self.interface_instances) do 
        print("** ", "'"..k.."'", v, k == id, type(k), type(id))
    end
    return self.interface_instances[id]
end

function plain_factory:del(id)
    self.interface_instances[id] = nil
end

function plain_factory:get_id(iface)
    local str = tostring(iface)
    local _, id_pos = string.find(str, "0x")
    return string.upper(string.sub(str, id_pos + 1))
end
