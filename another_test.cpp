#include <iostream>
#include "LuaBridge/LuaBridge.h"
#include <stdlib.h>
#include <stdio.h>

extern "C"
{
    #include "lua.h"
    #include "lauxlib.h"
    #include "lualib.h"
}

using namespace luabridge;

class MyClass
{
public:
	int Foo(int a)
	{
		printf("c++: %d\n", a);
		return a;
	}
};

#define CHECK(x, msg) { \
    if(x) { printf("ERROR at %s:%d\n\t%s ", __FILE__, __LINE__, #x); \
        throw std::runtime_error(msg);} }

int main()
{
	//lua_tostring(m_luaState, -1);
    lua_State* m_luaState = luaL_newstate();
	luaL_loadfile(m_luaState, "/home/mihacooper/prj/tmp/loader.lua");
    luaL_openlibs(m_luaState);
    //printf("asd");
    lua_pcall(m_luaState, 0, 0, 0);
    getGlobalNamespace(m_luaState)
    	.beginNamespace("test")
    	.beginClass<MyClass>("MyClass")
    	.addFunction("Foo", &MyClass::Foo)
    	.endClass()
    	.endNamespace()
	;
    //LuaRef loadFunc = getGlobal(m_luaState, "LoadInterface");
}