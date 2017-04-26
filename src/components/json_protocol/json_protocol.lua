json_protocol_encode = {}

function json_protocol_encode:request_new(iface_name)
    print("#### ", iface_name)
end

function json_protocol_encode:request_call(func, ...)
    print("#### ", tostring(func) .. ":", ...)
end

function json_protocol_encode:request_del()
    print("#### request_del")
end

json_protocol_decode = {}

function json_protocol_decode:process(data)
    print("$$$$", data)
end
