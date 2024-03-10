package engine

import "core:fmt"

import "core:math"
import "core:thread"
import "core:runtime"
import glm "core:math/linalg/glsl"
import "core:time"
import "core:os"
import "core:log"
import "core:mem"
import str "core:strings"
import img "vendor:stb/image"
import mu "vendor:microui"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"

import "core:intrinsics"
import "core:unicode/utf8"
import "core:math/bits"
import "core:io"
import sarr "core:container/small_array"
import reflect "core:reflect"
import slice "core:slice"

import "core:c/libc" // libc.system("reload")


DEFAULT_SPRITE: Sprite
_default_sprite_material: ^Material


WINDOW_WIDTH  :: 1920
WINDOW_HEIGHT :: 1080

make_light_matrix :: proc(position: Vector3, target := Vector3{}, range := f32(10)) -> Matrix4 {
	// @todo Use linalg
	proj := glm.mat4Ortho3d(-range, range, -range, range, 0.1, 10)
	view :=  glm.mat4LookAt(auto_cast position, auto_cast target, {0,1,0})
	
	return proj*view;
}

app_main :: proc() {
	
	input_manager = &Input_Manager{}
	asset_manager = &Asset_Manager{}
	entity_manager = &Entity_Manager{}

		
	
	using glfw
	
	if !bool(Init()) do println("glfw failed")
	
	handle := CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Window", nil, nil)
	window := Window{ size = {WINDOW_WIDTH, WINDOW_HEIGHT}, handle = handle}
	defer {
		Terminate()
		DestroyWindow(handle)
	}
	if handle == nil {
		println("window failed")
	}
	app_window = window
	
	
	
	MakeContextCurrent(handle)
	gl.load_up_to(GL_VERSION_MAJOR, GL_VERSION_MINOR, glfw.gl_set_proc_address)
	

	init_asset_manager()
	init_input_manager()
	defer delete_entity_manager()	
	defer delete_assets()

	keyboard_keys_info := get_keyboard_keys_info(); mouse_keys_info := get_mouse_keys_info()
	defer delete(keyboard_keys_info^); defer delete(mouse_keys_info^)
		
	
	
	load_and_generate_texture("default.png")

	// load_and_generate_texture("magma_normal.jpg")
	// load_and_generate_texture(file_name = "cubemap.png", store_data = false, wrap = gl.MIRRORED_REPEAT)
	
	RECT_RENDER_OBJECT = make_render_object(default_rect_vertices, default_rect_indices)
	camera := get_engine_camera()
	camera^ = make_camera()
	camera.position = {0, 0, -6}
	camera.target = {0, 0, 0}
	camera.angles.y = -PI/2.
	camera.angles.x = -PI/4.
	// camera.angles.y = PI/2.
	set_active_camera(camera^)
	
	FRAME_TIME := f64(1)/60
	prev_time := get_time()
	time := get_time()
	
	load_shader("default")
	load_shader("sprite")
	load_shader("simple_text")
	load_shader("default_2d")
	load_shader("screen")
	load_shader("screen_depth")
	load_shader("primitive")
	load_shader("basic")
	load_shader("depth")

	sprite_mat := make_material("sprite", get_shader("sprite"))
	
	SPRITE_MAT := &sprite_mat
	DEFAULT_SPRITE = make_sprite(get_texture("default"), sprite_mat)
	sprite_set_size(&DEFAULT_SPRITE, {1, 1})
	
	material := make_material("default", get_shader("default"))
		
	screen_ro := make_render_object(default_rect_vertices_centered_2, default_rect_indices_centered)

	render: [dynamic]Render_Object	
	
	
	
	
	xyz_lines := Basic_Mesh {
		vertices = {
			{position = {-10000, 0, 0}, color = {255,0,0,255}}, {position = {10000, 0, 0}, color = {255,0,0,255}},
			{position = {0, -10000, 0}, color = {0,255,0,255}}, {position = {0, 10000, 0}, color = {0,255,0,255}},
			{position = {0, 0, -10000}, color = {0,0,255,255}}, {position = {0, 0, 10000}, color = {0,0,255,255}},
		},
		indices = {0, 1, 2, 3, 4, 5},
	}
	
	basic_material := make_material("basic", get_shader("basic"))
	primitive_material := make_material("primitive", get_shader("primitive"))
	new_primitive(xyz_lines, .Line, primitive_material, true)

	
	defer { for prim in primitive_render_list do free_primitive(prim); delete(primitive_render_list)}
	sphere_prim: ^Primitive
	{
		vertices: [dynamic]Vertex
		indices: [dynamic]vIndex
		
		make_default_icosphere(&vertices, &indices)
		new_indices := split_triangles(&vertices, indices[:])
		vertices_set_color(vertices[:], {0, 0, 0, 255})
		p := new_primitive({vertices[:], new_indices[:]}, .Triangle, primitive_material, true)
		set_translation(&p.transform, Vector3{10, 0, 0})
		set_scale(&p.transform, 0.2)
		sphere_prim = p
		delete(vertices); delete(indices); delete(new_indices)
	}

	
	c_vert, c_ind := get_cube_mesh()
	
	vertices_set_color(c_vert[:], {255,255,255,255})
	
	g_cube_primitive = new_primitive(
		Basic_Mesh{vertices = c_vert[:], indices = c_ind[:]}, .Triangle, material,
		)
	defer free_primitive(g_cube_primitive)
	

	bitmap_to_data :: proc(bitmap: []byte, size: Vector2i) -> []Color {
		data := make([]Color, size.x*size.y)
		stride := size.x
		// opengl starts on the lower left corner :)
		for y in 0..<size.y do for x in 0..<size.x {
			i := x + (size.y-1-y) * stride

			data[i].rgb = 0xff
			data[i].a   = bitmap[x + y*stride]
		}
		return data
	}
	
	data := bitmap_to_data(mu.default_atlas_alpha[:], {mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT})
	get_ui_manager().font_texture = make_texture(data, {mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT})
	delete(data)
	
	

	framebuffer := make_msaa_frame_buffer()
	link_framebuffer := make_link_frame_buffer()
	depth_map := make_depth_map()
	gl.BindFramebuffer(gl.FRAMEBUFFER, 0)


	check_for_last_file_check()
	init_ui()
	ui_state: Ui_Info
	script := &get_asset_manager().script

	set_texture(&material, get_texture("default").id, 0)
	set_texture(&material, depth_map.color, 1)		
	update_material(material)
	reloading := true
	render_wireframe := false
	cull_face := false
	render_depth := false
	for !WindowShouldClose(handle) {
		
		
		time = get_time()
		delta := f32(time - prev_time)
		if time - prev_time < FRAME_TIME do continue
		prev_time = time
		// FRAMESTART ====================================
		// RENDER =========================================
		
		
		defer {
			size := get_window_size()
			gl.BindFramebuffer(gl.READ_FRAMEBUFFER, framebuffer.fbo)
			gl.BindFramebuffer(gl.DRAW_FRAMEBUFFER, link_framebuffer.fbo)
			gl.BlitFramebuffer(0, 0, size.x, size.y, 0, 0, size.x, size.y, gl.COLOR_BUFFER_BIT, gl.NEAREST);
			
			gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
			gl.ClearColor(0, 0, 0, 1)
			gl.Clear(gl.COLOR_BUFFER_BIT)
			
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.FILL)
			enable_cull_mode()
			gl.Disable(gl.DEPTH_TEST)

			// normal
			if !render_depth {
				shader := get_shader("screen")
				use_shader(shader.id)
				// note we did not actually set the texture
				// so if we need more than one texture this needs to be changed
				gl.ActiveTexture(gl.TEXTURE0)
				gl.BindTexture(gl.TEXTURE_2D, link_framebuffer.color)
				draw_render_object(screen_ro)
			} else {
				shader := get_shader("screen_depth")
				use_shader(shader.id)
				gl.ActiveTexture(gl.TEXTURE0)
				gl.BindTexture(gl.TEXTURE_2D, depth_map.color)
				draw_render_object(screen_ro)
			}
		}
		// ================================================
		update_assets()
		cursor := get_cursor()
		cursor.updated = false
		cursor.scroll = {}
		PollEvents()
		fetch_cursor_motion()
		
		if is_key_pressed(.Escape) {
			break
		}		
		if is_just_pressed(.H) do render_wireframe = !render_wireframe
		if is_just_pressed(.C) do cull_face = !cull_face
		if is_just_pressed(.G) do render_depth = !render_depth
		if is_just_pressed(.Five) {
			state := get_editor_state()
			if state != .Playing {
				state = .Playing
			} else {
				state = .Default
			}
			set_editor_state(state)
		}
		if is_just_pressed(.R) && !reloading {
			reloading = true
			// @todo Fix leak
			worker_proc :: proc() {
				libc.system("reload")
			}
			thread.run(worker_proc)
		}
		// global
		gl.Enable(gl.DEPTH_TEST)
		
		{
			set_cull_mode(.Front)
			gl.Viewport(0, 0, depth_map.size.x, depth_map.size.y)
			gl.BindFramebuffer(gl.FRAMEBUFFER, depth_map.fbo)
			
			gl.Clear(gl.DEPTH_BUFFER_BIT)
			
			
			use_shader(get_shader("depth").id)
			cam := get_active_camera()
			
			lmat := make_light_matrix({0, 3, -4}, {}, 20) 
			
			_LIGHTM = lmat
			
			safe_set_uniform(get_shader("depth"), "light_space", lmat)
			raw_draw_entities(get_shader("depth"))
			set_cull_mode(.Back)
		}
		gl.BindFramebuffer(gl.FRAMEBUFFER, framebuffer.fbo)
		gl.Viewport(0, 0, get_window_size().x, get_window_size().y)
		if render_wireframe do gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
		
		if cull_face do enable_cull_mode(); else do disable_cull_mode()
		
		gl.Enable(gl.BLEND)
		gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
		gl.ClearColor(0.5, 0, 1, 1)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)


		draw_primitives()
		update_entities(delta)

		engine_data := get_engine_data()

		
		if(script.just_reloaded) {
			reloading = false
			println("start new game")
			script.just_reloaded = false
			delete_entity_manager()
			init_entity_manager()
			make_game := script_get(script^, Make_Game_Symbol)
			make_game(engine_data, DEFAULT_ENGINE_INTERFACE)
		}
		if get_editor_state() == .Playing {
			game_update := script_get(script^, Game_Update_Symbol)
			game_update(engine_data, delta)
		} else {
			ui_update := script_get(script^, Ui_Update_Symbol)
			ui_manager.info = ui_update(engine_data, DEFAULT_ENGINE_INTERFACE, delta, get_selected_entity())
			info := ui_manager.info
			if !info.is_mouse_colliding && is_just_pressed_mouse(.Left) {
				e, info := get_entity_under_mouse()
				ui_manager.selected_entity = e.id if e != nil else 0
				set_translation(&sphere_prim.transform, info.position)
				type := ui_manager.info.selected_voxel_type
				if e != nil && type != .None {
					// voxel_set_type(e, ui_manager.info.selected_voxel_type)
				}
			}
			
			
			handle_engine_camera_input()
			render_ui()
			// draw_sprite(atlas_sprite)
			
		}
		
		gl.Enable(gl.DEPTH_TEST)
		SwapBuffers(handle)
		
		input_manager_clear()
		free_all(context.temp_allocator)
	}
	delete_game := script_get(script^, Delete_Game_Symbol)
	delete_game()
}

main :: proc() {
	
	// Odin context -------------------
	logger_options := log.Options {.Level, .Line, .Time, .Short_File_Path}
	when ODIN_DEBUG {
		lowest :: log.Level.Debug
	} else {
		lowest :: log.Level.Info
	}
	context.logger = log.create_console_logger(opt=logger_options, lowest=lowest)
	tracking_allocator: mem.Tracking_Allocator

	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator=mem.tracking_allocator(&tracking_allocator)
	defer {
		for key, val in tracking_allocator.allocation_map {
			fmt.printf("%v: %v\n", val.location, val.size)
		}
		mem.tracking_allocator_destroy(&tracking_allocator)
	}
	// Should probably set temp_allocator
	
	defer free_all(context.temp_allocator)
    // --------------------------------
    println("Start")
    app_main()
    println("Finish")	
}




