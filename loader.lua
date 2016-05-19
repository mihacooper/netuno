function LoadInterface(module, name, lang)
	package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"
	require "helpers"
	require "dsl"
	require(lang)

	require(module)
	local interface = GetInterface(name)
	 _G[name] = interface
	for _, func in pairs(interface) do
	    if IsTable(func) then
	        interface[func.funcName] = func.impl
	    end
	end
end