package engine
import "core:time"
import "core:os"
import "core:fmt"
import str "core:strings"
import gl "vendor:OpenGL"
import tt "vendor:stb/truetype"
import sarr "core:container/small_array"
import slice "core:slice"
SHADER_PATH :: "shaders/"
System :: struct {
	last_file_check: time.Time,
}
system: System

modification_time :: proc(file: os.File_Info) -> i64 {
	return file.modification_time._nsec
}
update_last_file_check :: proc(t: time.Time) {
	last := last_file_check()
	system.last_file_check._nsec = max(last, t._nsec)
	// if system.last_file_check._nsec != last do println("last check: ", system.last_file_check._nsec)
}
last_file_check :: #force_inline proc "contextless" () -> i64 {
	// time_to_unix_nano
	return system.last_file_check._nsec
}

Asset_Manager :: struct {
	// texture_id_count: int,
	textures: map[string] Texture,
	shaders:  map[iShader] Shader,
	shader_uid: map[string] iShader,
	
	materials:  map[iMaterial] Material,
	material_uid: map[string] iMaterial,
	
	shader_counter: iShader,
	material_counter: iMaterial,
	default_font: Font,
	
	script: Script, // for now one
}; asset_manager: ^Asset_Manager

init_asset_manager :: proc() {
	
	// font_data, ok := os.read_entire_file("data/arial.ttf"); defer delete(font_data)
	// assert(ok)
	// info: tt.fontinfo
	// if !tt.InitFont(&info, &font_data[0], 0) {
	// 	panic("")
	// }
	// asset_manager.default_font = Font{info = &info}
	sarr.clear(&get_input_manager().queue)
	

	script_lib = load_lib(DLL_NAME)
	
	
	symbol := load_symbol(Ui_Update_Symbol)
	
	asset_manager.script.symbols = {symbol, load_symbol(Make_Game_Symbol), load_symbol(Game_Update_Symbol), load_symbol(Delete_Game_Symbol)}
	asset_manager.script.symbols = slice.clone(asset_manager.script.symbols)
	asset_manager.script.just_reloaded = true
}

delete_assets :: proc() {
	for key, uid in asset_manager.shader_uid {
		delete_shader(get_shader(uid))
		delete(key)
	}
	for key, uid in asset_manager.material_uid {
		delete(key)
	}
	
	for key, tex in asset_manager.textures {
		delete(tex.data)
		delete(key)
	}
	delete(asset_manager.materials)
	delete(asset_manager.material_uid)
	
	delete(asset_manager.shaders)
	delete(asset_manager.shader_uid)
	
	delete(asset_manager.textures)
	delete(asset_manager.script.symbols)
}

get_asset_manager :: #force_inline proc "contextless" () -> ^Asset_Manager {
	return asset_manager
}

get_shader_uid :: proc(uid: iShader) -> Shader {
	return asset_manager.shaders[uid]
}
get_shader_string :: proc(s: string) -> Shader {
	uid, ok := asset_manager.shader_uid[s]
	assert(ok)
	a, _ok := asset_manager.shaders[uid]
	assert(_ok)
	return a
}
get_shader :: proc {get_shader_uid, get_shader_string}

get_material_uid :: proc "contextless" (uid: iMaterial) -> (Material, bool) #optional_ok {
	s, ok := asset_manager.materials[uid]
	return s, ok
}
get_material_string :: proc "contextless" (s: string) -> (Material, bool) #optional_ok {
	uid, ok := asset_manager.material_uid[s]
	return asset_manager.materials[uid]
}

get_material :: proc {get_material_uid, get_material_string}

update_material :: proc(material: Material) {
	manager := get_asset_manager()
	uid, ok := manager.materials[material.id]
	assert(ok)
	manager.materials[material.id]=material
	
}
shader_get_file_path :: proc(shader: Shader) -> string {
	return str.concatenate( {SHADER_PATH, shader.name, ".shader"}, context.temp_allocator)
}

get_texture :: proc (name: string) -> Texture {
	v, ok := asset_manager.textures[name]
	assert(ok)
	return v
}


get_name_and_suffix_temp :: proc(s: string) -> (name, suffix: string){
	parts := str.split(s, ".", context.temp_allocator)
	suffix = parts[len(parts)-1]
	name = s[:len(s)-len(suffix)-1] // - suffix and the dot
	return
}

reload_shader :: proc(shader: Shader) -> Shader {
	println("reload:")
	new_shader, ok :=  load_shader(shader.name, false)
	if !ok do return new_shader
	
	delete_shader(shader)
	return new_shader
}

load_shader_source :: proc(name: string) -> (u32, bool) #optional_ok {
	t := str.concatenate( {SHADER_PATH, name, ".shader"}, context.temp_allocator)
	src, file_ok := os.read_entire_file(t); assert(file_ok)
	defer delete(src)
	
	
	lines := str.split_lines(string(src))
	// Remove comments
	for line in &lines {
		idx := str.index(line, "//")
		if idx < 0 do continue
		line = line[:idx]
		
	}
	clean_src := str.join(lines, "\n")
	
	fields := str.fields(clean_src)
	
	version := concat({fields[0], " ", fields[1], " ", fields[2], "\n"})
	defer { delete(lines); delete(clean_src); delete(fields); delete(version)}
	
	// after header
	start := 3
	if fields[3] != "#VERTEX" {
		println(clean_src)
		panic("No vertex shader")
	}
	fields[3] = version

	index := int(-1)
	for f, i in fields {
		if f == "#FRAGMENT" {
			index = i
			break
		}
	}
	
	assert(index>=0)
	fields[index] = version
	
	v_src := str.join(fields[start:index], " ")
	f_src := str.join(fields[index:], " ")
	defer {delete(v_src); delete(f_src)}
	// vertex, v_ok := gl.compile_shader_from_source(v_src, .VERTEX_SHADER)
	// fragment, f_ok := gl.compile_shader_from_source(f_src, .FRAGMENT_SHADER)
	// id, id_ok := gl.create_and_link_program({vertex, fragment})
	id, id_ok := gl.load_shaders_source(v_src, f_src);
	return id, id_ok
}
// Nothing wrong with this. Just replace the loading with the specific procedure.
// load_shader_source_type :: proc(name: string, type: gl.Shader_Type) -> u32 {
// 	
// 	suffix: string
// 	#partial switch type {
// 	case .VERTEX_SHADER:
// 		suffix = ".vs"
// 	case .FRAGMENT_SHADER:
// 		suffix = ".fs"
// 	case .GEOMETRY_SHADER:
// 		suffix = ".gs"
// 	case:
// 		panic("shader type not implemented")
// 	}
// 	t := str.concatenate( {SHADER_PATH, name, suffix}, context.temp_allocator)
// 	src, file_ok := os.read_entire_file(t); assert(file_ok)
// 	defer delete(src)
// 	
// 	id, ok := gl.compile_shader_from_source(string(src), type)
// 	return id
// }

load_shader :: proc(name: string, panic_on_error := true) -> (Shader, bool) #optional_ok {
	
	shader: Shader; ok: bool
	shader.program, ok = load_shader_source(name)
	if !ok {
		fmt.eprintln("Shader Compilation Failed")
		when ODIN_DEBUG { // does not print in debug by itself
			msg, shader_type := gl.get_last_error_message()
			fmt.eprintf(msg)
			fmt.eprintln("FOR ", name)
			delete(msg)
		}
		if panic_on_error {
			panic("Couldn't load shader")
		}
		return shader, false
	}
	shader.name = str.clone(name)
	println("loaded shader: ", shader.name)
	
	uid: iShader
	if shader.name in asset_manager.shader_uid {
		key, val := delete_key(&asset_manager.shader_uid, shader.name)
		delete(key)
		// use the same uid
		shader.id = val
	} else {
		asset_manager.shader_counter += 1
		shader.id = asset_manager.shader_counter
	}
	shader.uniforms = gl.get_uniforms_from_program(shader.program)
	asset_manager.shader_uid[str.clone(shader.name)] = shader.id
	asset_manager.shaders[shader.id] = shader
	return shader, true
}

// TODO
check_for_last_file_check :: proc() {
	fd, ok := os.open("./shaders", os.O_RDONLY)
	assert(ok == os.ERROR_NONE)
	
	dir, dir_ok := os.read_dir(fd, 0)
	assert(dir_ok == os.ERROR_NONE)
	
	defer {
		os.file_info_slice_delete(dir)
		os.close(fd)
	}
	max_ns := i64(-1)
	for file in dir {
		
		if str.has_prefix(file.name, "#") || str.has_prefix(file.name, ".") do continue
		ns := modification_time(file)
		max_ns = max(max_ns, ns)
		
	}
	update_last_file_check(time.Time{max_ns})
}

update_assets :: proc() {
	
	max_ns := i64(-1)
	for _, shader in asset_manager.shaders {
		path := shader_get_file_path(shader)
		file, file_ok := os.stat(path); defer os.file_info_delete(file)
						
		if file_ok != os.ERROR_NONE {
			fmt.eprintln("Could not find files for shader ", shader)
			panic("")
		}
		ns := modification_time(file)
		if ns <= last_file_check() do continue
		max_ns = max(max_ns, ns)
		reload_shader(shader)
	}
	
	
	SCRIPT_NAMES :: []string{DLL_NAME}
	// If both get updated at the same time then the earlier one might get loaded
	loop: for name in SCRIPT_NAMES {

		// It looks like there are always exactly 2 passes?
		// {
		// 	temp := concat({"build/", "scripts.dll"}, context.temp_allocator)
		// 	info, ok := os.stat(temp, context.temp_allocator)
		// 	ns := info.modification_time._nsec
		// 	if ns > system.last_file_check._nsec {
		// 		println("UPDATE")
		// 	}
		// 	max_ns = max(max_ns, ns)
		// }
		
		// The creaton/modification of the text file ensures that the creation of the dll is actually finished.
		// This is needed since the modification time of the dll is being updated before the creation of it is completed.
		temp := concat({"build/", "building_dll_finished.txt"}, context.temp_allocator)
		file, ok := os.stat(temp)
		defer os.file_info_delete(file)
		ns := modification_time(file)
		
		
		if ns > last_file_check() {
			delete_game := script_get(asset_manager.script, Delete_Game_Symbol)
			delete_game()
			unload_lib(script_lib)
			println("reload scripts")
			script_lib = load_lib(name)
			
			for symbol in &asset_manager.script.symbols {
				switch s in &symbol {
				case Ui_Update_Type:
					s = load_symbol(s)
				case Make_Game_Type:
					s = load_symbol(s)
				case Game_Update_Type:
					s = load_symbol(s)
				case Delete_Game_Type:
					s = load_symbol(s)
				}
			}
			asset_manager.script.just_reloaded = true
			max_ns = max(max_ns, ns)
			break loop
		}
		
	}
	update_last_file_check(time.Time{max_ns})
}
