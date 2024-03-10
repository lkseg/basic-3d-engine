package game


import sarr "core:container/small_array"
import mu "vendor:microui"
import engine "../engine"
import "core:fmt"
import la "core:math/linalg"
import "core:unicode/utf8"
import str "core:strings"

get_mouse_position :: engine.get_mouse_position
get_mouse_position_ii :: engine.get_mouse_position_ii
get_mouse_scroll :: engine.get_mouse_scroll


ui_begin :: proc(ctx: ^mu.Context) {
	for item, index in ctx.container_pool {
		if item.id != 0 {
			// container := &ctx.containers[index]
			// container.active = false
		}
	}	
	mu.begin(ctx)
}
ui_end :: proc(ctx: ^mu.Context) {
	mu.end(ctx)
}

@(export)
ui_update :: proc(data: engine.Engine_Data, handle: engine.Engine_Interface, args: ..any) -> engine.Ui_Info {
	engine.set_engine_data(data)
	delta := cast_any(args[0], f32)
	selected_entity := cast_any(args[1], ^engine.Entity)
	
	ctx: ^mu.Context = data.ui_context
	ui_begin(ctx)
	// fmt.println(ctx.hover_id, ctx.focus_id, ctx.last_id)
	assets := data.asset_manager
	es := data.entity_manager
	
	mu.input_mouse_move(ctx, i32(get_mouse_position().x), i32(get_mouse_position().y))
	mu.input_scroll(ctx, i32(get_mouse_scroll().x * 10), i32(get_mouse_scroll().y * 10))
	queue := data.input_manager.queue
	for i := 0; i < queue.len; i+=1 {
		key := sarr.get(queue, i)
		#partial switch id in key.id {
			case engine.Mouse_Key:
				type: mu.Mouse = .LEFT if id == .Left else .RIGHT if id == .Right else .MIDDLE
				// @todo? It should be the position of the click which should be just the current position?
				if key.pressed {
					mu.input_mouse_down(ctx, get_mouse_position_ii(), type)
				} else {
					mu.input_mouse_up(ctx, get_mouse_position_ii(), type)
				}
			case engine.Keyboard_Key:
				if key.pressed && .A<=id && id<=.Z {
					// Doesn't support runes
					// rune_bytes, size := utf8.encode_rune(rune(id))
					// s := string(rune_bytes[:size])
					arr := []byte{byte(id)}
					mu.input_text(ctx, string(arr))
				}
		}
	}
	

	@static opts := mu.Options{.NO_CLOSE}
	
	settings := mu.Options{.NO_CLOSE}
	
	if mu.window(ctx, "Engine Data", {0, 0, 300, 300}, settings+{.NO_INTERACT}) {
		
		mu.label(ctx, fmt.tprintf("%v", delta))
		/* if .ACTIVE in mu.header(ctx, "Buttons", {.EXPANDED}) {
			mu.layout_row(ctx, {80, -100, -1})
			mu.label(ctx, "Test buttons 1:")
			if .SUBMIT in mu.button(ctx, "Button 1"){}
			if .SUBMIT in mu.button(ctx, "Button 2"){}
		}
		if .ACTIVE in mu.header(ctx, "Window Options") {
			mu.layout_row(ctx, {120, 120, 120}, 0)
			for opt in mu.Opt {
				state := opt in opts
				if .CHANGE in mu.checkbox(ctx, fmt.tprintf("%v", opt), &state)  {
					if state {
						opts += {opt}
					} else {
						opts -= {opt}
					}
				}
			}
		} */
		
		if .ACTIVE in mu.header(ctx, "Entities") {
			for _, entity in es.entities {
				mu.layout_row(ctx, {120}, 0)
				mu.label(ctx, fmt.tprintf("id: %v", entity.id))
			}
			
		}
		if .ACTIVE in mu.header(ctx, "Materials") {
			for _, m in assets.materials {
				mu.layout_row(ctx, {120}, 0)
				mu.label(ctx, fmt.tprintf("%v", m.name))
			}
			
		}
		if .ACTIVE in mu.header(ctx, "Info", {.NO_CLOSE, .EXPANDED}) {
			mu.layout_row(ctx, {120}, 0)
			mu.label(ctx, "Usage:")
			mu.label(ctx, "5 => Toggle between Play/Editor")
			mu.label(ctx, "R => Recompile and hot reload the game code")
			mu.label(ctx, "W,A,S,D => Move in play mode")
			mu.label(ctx, "H => Wireframe")
			mu.label(ctx, "LeftClick => Select")
			mu.label(ctx, "G => Depth Map")
			mu.label(ctx, "C => Cull Face")
		}
		
	}

	@static chosen: engine.Voxel_Type
	@static chosen_string: string

	wsize := handle.get_window_size()
	//  + {.NO_INTERACT}
	if selected_entity != nil do if mu.window(ctx, "Selected", {wsize.x-400, 0, wsize.x, 400}, settings) {
		entity := selected_entity
		pawn := get_derived(entity)
		
		if .ACTIVE in mu.header(ctx, "Pawn", {.EXPANDED}) {
			
			entity := selected_entity
			pawn := get_derived(entity)
			
			assert(type_of(pawn) == ^Pawn)
			
			mu.layout_row(ctx, {120}, 0)
			
			it := make_type_info_struct_iterator(pawn)
			for val, i in iterate(&it) {
				if it.info.names[i] == "entity" do continue
				if it.info.names[i] == "point" {
					mu.label(ctx, fmt.tprintf("%v: %v", it.info.names[i] ,val))
					@static buffer: [255]byte
					@static buffer_len: int
					ret := mu.textbox(ctx, buffer[:], &buffer_len)

					if .SUBMIT in ret {
						mu.set_focus(ctx, ctx.last_id)
					}
				} else {
					mu.label(ctx, fmt.tprintf("%v: %v", it.info.names[i] ,val))
				}

			}
		}
	} else {
		println("false")
	}
	
	ui_end(ctx)

	// check if there is a collision between a window and cursor
	mouse_col := false
	for item, index in ctx.container_pool {
		if item.id != 0 {
			container := ctx.containers[index]
			r := container.rect
			// if container.active && container.open && is_in_rect(to_vector2i(get_mouse_position()), Vector2i{r.x, r.y}, Vector2i{r.w, r.h}) {
			// 	mouse_col = true
			// 	break;
			// }
		}
	}
	// do stuff with selected entity based on input
	if selected_entity != nil && selected_entity.derived != nil {
		
		pawn := get_derived(selected_entity)
		
		
		camera := handle.get_active_camera()
		x, _, z := get_basis(camera.transform)

		// mirror since we take the positive z-axis
		f := normalize(Vector2{-z.x, z.z})
		r := normalize(Vector2{x.x, -x.z})
		
		sf := to_vector3i(xy_to_3d(round(vector_snap(f, Vector2{0, 1}, PI/4))))
		sr := to_vector3i(xy_to_3d(round(vector_snap(r, Vector2{1, 0}, PI/4))))
		
		v: Vector3i
		dir := engine.get_just_input_direction()
		
		
		switch {
			case dir.x != 0:
			v = sr*i32(sign(dir.x))
			case dir.y != 0:
			v = sf*i32(sign(dir.y))
			case engine.is_just_pressed(.Q):
			v.y = 1
			case engine.is_just_pressed(.E):
			v.y = -1
		}
		
		if v != {0,0,0} {
			pawn_move(pawn, v)
			pawn_update(pawn)
		}
		
	}
	return {
		is_mouse_colliding = mouse_col,
		selected_voxel_type = chosen,
	}
	
}

