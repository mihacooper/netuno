function get_factory()
    local singleton_factory = {
        interface_instances = {},
        instances_map = {}
    }

    function singleton_factory:new(iface_name)
        if self.instances_map[iface_name] then
            return true, self.instances_map[iface_name]
        else
            local iface = component:load_instate("system::interface::" .. iface_name)
            if not iface then
                return false, "Unknown interface " .. iface_name
            end
            local id = self:get_id(iface)
            self.interface_instances[id] = iface
            self.instances_map[iface_name] = id
            return true, id
        end
    end

    function singleton_factory:get(id)
        return self.interface_instances[id]
    end

    function singleton_factory:del(id)
        --component:unload(self.interface_instances[id])
        --self.interface_instances[id] = nil
    end

    function singleton_factory:get_id(iface)
        local str = tostring(iface)
        local _, id_pos = string.find(str, "0x")
        return string.upper(string.sub(str, id_pos + 1))
    end
    return singleton_factory
end