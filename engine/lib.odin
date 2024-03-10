package engine

import "core:fmt"
import "core:os"
import reflect "core:reflect"
import dll "core:dynlib"

DLL :: dll.Library
script_lib: dll.Library

DLL_NAME :: "game.dll"
load_lib :: proc(dll_name := DLL_NAME) -> dll.Library {
	
	path := concat({"build/", dll_name})
	defer delete(path)
	
	info, info_ok  := os.stat(path)
	defer os.file_info_delete(info)
	
	data, ok := os.read_entire_file(path)
	assert(ok)
	defer delete(data)
	
	
	
	__path := concat({"build/__", dll_name})
	defer delete(__path)
	handle, errno := os.open(__path, os.O_CREATE)
	defer os.close(handle)
	assert(errno == os.ERROR_NONE)
	
	os.write(handle, data)
	os.close(handle)
	
	lib, dll_ok := dll.load_library(__path)
	if !dll_ok do panic("can't load lib")
	
	return lib
}
lib_load :: proc(lib: dll.Library, proc_name: string, $T: typeid) -> T {
	foo, foo_ok := dll.symbol_address(lib, proc_name)
	if !foo_ok do panic("can't load proc")
	return cast(T) foo
}
lib_load_raw :: proc(lib: dll.Library, proc_name: string, T: typeid) -> rawptr {
	foo, foo_ok := dll.symbol_address(lib, proc_name)
	if !foo_ok do panic("can't load proc")
	return foo
}
unload_lib :: proc(lib: dll.Library) {
	if !dll.unload_library(lib) do panic("failed unloading")
}

Symbol :: struct($Name: string, $T: typeid) {
	data: T,
}

Script :: struct {
	just_reloaded: bool,
	symbols: []Any_Symbol,
}
load_symbol :: proc(s: Symbol($S, $T), lib := script_lib) -> Symbol(S, T) {
	l: Symbol(S, T)
	l.data = lib_load(lib, S, T)
	return l
}
get_symbol_data :: proc(s: Symbol($Name, $T)) -> T {
	return s.data
}

script_get :: proc(script: Script, s: $L/Symbol($S, $T)) -> T {
	for symbol in script.symbols {
		if reflect.union_variant_typeid(symbol) == L {
			return symbol.(L).data
		}
	}
	panic("Symbol doesn't exist")
	// return nil
}