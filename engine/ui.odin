package engine
import mu "vendor:microui"
import "core:fmt"
import sarr "core:container/small_array"
import gl "vendor:OpenGL"
import str "core:strings"
import tt "vendor:stb/truetype"
Ui_Info :: struct {
	selected_voxel_type: Voxel_Type,
	is_mouse_colliding: bool,
}

Ui_Manager :: struct {
	ui_context: mu.Context,
	default_material: iMaterial,
	selected_entity: iEntity,
	font_texture: Texture,
	info: Ui_Info,
}
ui_manager: Ui_Manager
get_ui_manager :: #force_inline proc() -> ^Ui_Manager {
	return &ui_manager
}

get_ui_context :: #force_inline proc() -> ^mu.Context {
	return &ui_manager.ui_context
}
init_ui :: proc() {
	ctx: mu.Context
	mu.init(&ctx)
	ui_manager.ui_context = ctx
	ui_set_font(nil, mu.default_atlas_text_width, mu.default_atlas_text_height)
	ui_manager.default_material = make_material("simple_text", get_shader("simple_text")).id
}
get_selected_entity :: proc() -> ^Entity {
	return get_entity(ui_manager.selected_entity)
}

ui_set_font :: proc(font: rawptr, text_width: proc(mu.Font,string) -> i32, text_height: proc(mu.Font) -> i32) {
	ctx := get_ui_context()
	ctx.text_width = text_width
	ctx.text_height = text_height
	ctx.style.font = mu.Font(font)
}

to_rectanglei :: proc(r: mu.Rect) -> Rectanglei {
	return {position = {r.x, r.y}, size = {r.w, r.h}}
}
Sprite :: struct {
	position: Vector2,
	scale: Vector2,
	size: Vector2, // size with scale applied; so it can be negative!
	texture: Texture, // has the original size
	material: iMaterial,
	tint: Color,
	render_object: Render_Object,
}

make_sprite :: proc(texture: Texture, material: Material, ro := RECT_RENDER_OBJECT) -> Sprite {
	sprite: Sprite
	sprite.texture = texture
	sprite.size = to_vector2(texture.size)
	sprite.scale = {1,1}
	sprite.material = material.id
	sprite.render_object = ro
	sprite.tint = {255, 255, 255, 255}
	return sprite
}



sprite_set_scale :: proc(sprite: ^Sprite, scale: Vector2) {
	sprite_set_size(sprite, to_vector2(sprite.texture.size) * scale)
}

sprite_set_size :: proc(sprite: ^Sprite, size: Vector2) {
	sprite.scale = size/to_vector2(sprite.texture.size)
	sprite.size = size
}

draw_sprite :: proc(sprite: Sprite) {
	
	m := make_model_matrix(to_vector3(sprite.position.xy), 1, to_vector3(sprite.size))
	
	mat := get_material(sprite.material)
	sprite_use_material_and_render(sprite, m, sprite.render_object)
	
}
render_ui :: proc() {
	gl.Disable(gl.DEPTH_TEST)

	font_texture := ui_manager.font_texture
		
	material := get_material(ui_manager.default_material)
	ctx := get_ui_context()
	pcm: ^mu.Command
	
	// TODO Optimize
	for command_variant in mu.next_command_iterator(ctx, &pcm) {
		#partial switch c in command_variant {
		case ^mu.Command_Text:
			dst := Rectanglei{{c.pos.x, c.pos.y}, {0, 0}}
			vertices: [dynamic]Vertex
			indices: [dynamic]vIndex
			defer {delete(vertices); delete(indices)}
			for char in c.str {
				// only support simple characters
				r := min(int(char), 127)
				
				src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
				dst.size.x = src.w
				dst.size.y = src.h
				
				render_add(font_texture, dst, to_rectanglei(src), &vertices, &indices)// c.color
				dst.position.x += dst.size.x
			}
			
			
			
			ro := make_render_object(vertices[:], indices[:])
			// simple_text ignores the size and position
			sprite := make_sprite(font_texture, material, ro)
			draw_sprite(sprite)
			
			delete_render_object(&ro)		
		case ^mu.Command_Rect:
			//color_to_float(Color{c.color.r, c.color.g, c.color.b, c.color.a})
			col := Color{c.color.r, c.color.g, c.color.b, c.color.a}
			
			rect := to_rectanglei(c.rect)
			
			p := get_rectangle_positions(rect)
			V3 :: to_vector3
			v := []Vertex {
				{position = V3(p[0]), color = col},
				{position = V3(p[1]), color = col},
				{position = V3(p[2]), color = col},
				{position = V3(p[3]), color = col},
			}
			vertices: [dynamic]Vertex
			indices: [dynamic]vIndex
			
			defer {delete(vertices); delete(indices)}
			append(&indices, 0, 2, 3,   0, 3, 1)
			for v in v {
				vert := Vertex{position = V3(screen_to_clip(v.position.xy)), color = v.color}
				append(&vertices, vert)
			}	
			use_shader(get_shader("default_2d").id)
			ro := make_render_object(vertices[:], indices[:])
			draw_render_object(ro)
			delete_render_object(&ro)
		case ^mu.Command_Icon:
			vertices: [dynamic]Vertex
			indices: [dynamic]vIndex
			defer {delete(vertices); delete(indices)}
			
			
			src := to_rectanglei(mu.default_atlas[c.id])
			dst := to_rectanglei(c.rect)
			
			// the default size of dst seems to be too high?
			dst.position += (dst.size-src.size)/2
			dst.size = src.size
			
			render_add(font_texture, dst, src, &vertices, &indices)
			
			ro := make_render_object(vertices[:], indices[:])
			sprite := make_sprite(font_texture, material, ro)
			
			// sprite.position = to_vector2(dst.position)
			// sprite_set_size(&sprite, to_vector2(dst.size))
			draw_sprite(sprite)
			delete_render_object(&ro)
			// TODO	
		case ^mu.Command_Clip:
			// instead of Executing any kind of clipping we could just instead use glScissor with the
			// individual window size before rendering anything
			
			// size := get_window_size()
			// rect := c.rect
			// gl.Enable(gl.SCISSOR_TEST)
			// gl.Scissor(rect.x, rect.y, rect.w, rect.h)
			// gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
			// gl.Disable(gl.SCISSOR_TEST)
			
		}
		
	}
}
render_add :: proc(texture: Texture, dst: Rectanglei, src: Rectanglei, vertices: ^[dynamic]Vertex, indices: ^[dynamic]vIndex) {
	// start for our new indices
	// before adding new vertices
	start := cast(vIndex)len(vertices)
	
	V3 :: to_vector3
	V2 :: to_vector2

	s := get_rectangle_positions(src)
	// screen space position
	p := get_rectangle_positions(dst)
	
	
	size := to_vector2(texture.size) 
	
	v := []Vertex {
		{position = V3(p[0]), uv = V2(s[0])/size},
		{position = V3(p[1]), uv = V2(s[1])/size},
		{position = V3(p[2]), uv = V2(s[2])/size},
		{position = V3(p[3]), uv = V2(s[3])/size},
	}
	
	for v in v {
		
		vert := Vertex{position = V3(screen_to_clip(v.position.xy)), uv = Vector2{v.uv.x, 1-v.uv.y}} // flip y 
		append(vertices, vert)
	}
	
	append(indices, start+0, start+2, start+3,   start+0, start+3, start+1)
}

// generate_atlas_texture :: proc() -> Texture {
// 	b := str.builder_make()
// 	for c in 'a'..='z' {
// 		str.write_rune(&b, c)
// 	}
// 	for c in 'A'..='Z' {
// 		str.write_rune(&b, c)
// 	}
	
// 	return make_text_texture(str.to_string(b))
// }

