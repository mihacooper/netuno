function LoadClientInterface(module, name, lang)
	package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"
	require "helpers"
	require "dsl"
	require("lang-" .. lang .. ".binding")

	dofile(module)
	local interface = GetInterface(name)
	 _G[name] = interface
	for _, func in pairs(interface) do
	    if IsTable(func) then
	        interface[func.funcName] = func.impl
	    end
	end
end

function LoadServerInterface(module, name, lang)
	package.path = package.path .. ";" .. os.getenv("LUA_RPC_SDK") .. "/?.lua"
	require "helpers"
	require "dsl"
	require("lang-" .. lang .. ".binding")

	dofile(module)
	local interface = GetInterface(name)
	interface.impl = _G[name]
	_G[name] = interface
	for _, func in ipairs(interface) do
	    if IsTable(func) then
	        interface[func.funcName] =
	        	function(...)
	        		return _G[name].impl[func.funcName](_G[name].impl, ...) 
	        	end
	    end
	end
	-- ++ JUST FOR TEST
	print(GetInterface(name).MyFunction1(1, 2))
	-- -- JUST FOR TEST
end