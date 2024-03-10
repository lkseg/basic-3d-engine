package engine
import gl "vendor:OpenGL"
import str "core:strings"
import "core:mem"
import "core:fmt"
import tt "vendor:stb/truetype"
import "core:unicode/utf8"
import slice "core:slice"
import "core:intrinsics"
import img "vendor:stb/image"

Cull_Face_Mode :: enum {
	Front = gl.FRONT,
	Back  = gl.BACK,
	Front_And_Back = gl.FRONT_AND_BACK,
}

GL_Mode :: enum {
	Cull_Face = 0,
}
GL_Context :: struct {
	cull_face_mode: Cull_Face_Mode,
	
}; gl_context: GL_Context

disable_cull_mode :: proc() {
	gl.Disable(gl.CULL_FACE)
}
enable_cull_mode :: proc() {
	gl.Enable(gl.CULL_FACE)
}
set_cull_mode :: proc(mode: Cull_Face_Mode) {
	gl_context.cull_face_mode = mode
	gl.CullFace(auto_cast mode)
}

Index_Type :: enum u32 {
	u8 = gl.UNSIGNED_BYTE,
	u16 =  gl.UNSIGNED_SHORT,
	u32 =  gl.UNSIGNED_INT,
}
DEFAULT_INDEX_TYPE :: Index_Type.u8 when vIndex==u8 else Index_Type.u16 when vIndex==u16 else Index_Type.u32

get_index_type :: proc($T: typeid) -> Index_Type {
	when T == u32 {
		return Index_Type.u32
	}
	when T == u16 {
		return Index_Type.u16
	}
	when T == u8 {
		return Index_Type.u8
	}
	panic("unknown index type")
}


GL_VERSION_MAJOR :: 3
GL_VERSION_MINOR :: 3

Texture :: struct {
	id: u32,
	data: []Vector4, // must not be set; should be []u8
	size: Vector2i,
}

iShader :: distinct u32

Shader :: struct {
	name: string,
	program: u32,
	id: iShader,
	uniforms: gl.Uniforms,
	// stamp: f64,
}


iMaterial :: u32

Material :: struct {
	shader: iShader,
	textures: [16]u32,
	next: iMaterial,
	id: iMaterial,
	name: string,
}


delete_shader :: proc(using shader: Shader) {
	gl.destroy_uniforms(shader.uniforms)
	delete(name)
	gl.DeleteProgram(shader.program)
}

make_material :: proc(name: string, shader: Shader) -> Material {
	a := get_asset_manager()
	mat: Material
	mat.id = a.material_counter + 1
	mat.shader = shader.id
	mat.name = str.clone(name)
	a.material_counter += 1
	
	asset_manager.material_uid[mat.name] = mat.id
	asset_manager.materials[mat.id] = mat
	return mat
}

set_shader :: proc "contextless" (m: ^Material, shader: Shader) {
	m.shader = shader.id
}
use_shader :: #force_inline proc(shader: iShader) {
	gl.UseProgram(get_shader(shader).program)
}

shader_set_uniform :: proc(shader: Shader, name: cstring, value: $T) {
	#force_inline location_set_uniform(gl.GetUniformLocation(shader.program, name), value)
}
material_set_uniform :: proc(material: iMaterial, name: cstring, value: $T) {
	shader_set_uniform(get_shader(get_material(material).shader), name, value)
}
location_set_uniform :: proc(location: i32, value: $T) {
	loc := location
	value := value
	when intrinsics.type_is_integer(T) {gl.Uniform1i(loc,  i32(value))} else
	when T==i32     {gl.Uniform1i(loc,  value)} else
	when T==f32     {gl.Uniform1f(loc,  value)} else
	when T==Vector2 {gl.Uniform2fv(loc, 1, &value[0])}  else
	when T==Vector3 {gl.Uniform3fv(loc, 1, &value[0])} else
	when T==Vector4 {gl.Uniform4fv(loc, 1, &value[0])} else
	when T==Matrix3 {gl.UniformMatrix3fv(loc, 1, false, &value[0, 0])} else
	when T==Matrix4 {gl.UniformMatrix4fv(loc, 1, false, &value[0, 0])}
	else {
		#panic("unknown uniform type")
	}
	
}
set_uniform :: proc{location_set_uniform, shader_set_uniform, material_set_uniform}

safe_set_uniform :: proc(shader: Shader, name: cstring, value: $T) {
	uni, ok := shader.uniforms[string(name)]
	assert(ok)
	set_uniform(uni.location, value)
}

_LIGHTM: Matrix4

// Uses the material and returns the updated version
use_material :: proc(mat: iMaterial, model: Matrix4) -> Material {
	mat := get_material(mat)
	model := model
	uni: gl.Uniform_Info; ok: bool
	
	uniforms := get_shader(mat.shader).uniforms
	
	camera := get_active_camera()
	use_shader(mat.shader)
	
	uni, ok = uniforms["projection"]
	if  ok {
		gl.UniformMatrix4fv(uni.location, 1, false, &camera.projection[0,0])
	}
	uni, ok = uniforms["model"]
	if ok {
		gl.UniformMatrix4fv(uni.location, 1, false, &model[0,0])
	}
	uni, ok = uniforms["view"]
	if ok {
		gl.UniformMatrix4fv(uni.location, 1, false, &camera.view[0,0])
	}
	uni, ok = uniforms["normal_view"]
	if ok {
		normal_view := inverse_transpose(camera.view*model)
		gl.UniformMatrix4fv(uni.location, 1, false, &normal_view[0,0])
	}
	
	
	uni, ok = uniforms["normal_world"]
	if ok {
		normal_world := inverse_transpose(model)
		gl.UniformMatrix4fv(uni.location, 1, false, &normal_world[0,0])
	}
	
	uni, ok = uniforms["eye"]
	if ok {
		gl.Uniform3fv(uni.location, 1, &camera.position[0])
	}
	
	uni, ok = uniforms["view_2d"]
	if ok {
		w := to_vector2(get_window().size)

		// clipping
		view_2d := Matrix4 {
			2/w.x, 0, 0, 0,
			0    , 2/w.y, 0, 0,
			0, 0, 0, 0,
			0, 0, 0, 0,
		}
		gl.UniformMatrix4fv(uni.location, 1, false, &view_2d[0,0])
	}
	uni, ok = uniforms["light_space"]
	if ok {
		set_uniform(uni.location, _LIGHTM)
	}

	// TODO: Should be Smallarray?
	for i := 0; mat.textures[i]!=0 && i<len(mat.textures); i+=1 {
		buf: [256]byte
		s := fmt.bprintf(buf[:], "texture%v\u0000", i)
		material_set_uniform(mat.id, str.unsafe_string_to_cstring(s), i32(i))
		gl.ActiveTexture(gl.TEXTURE0 + u32(i))
		gl.BindTexture(gl.TEXTURE_2D, mat.textures[i])
	}
	return mat
}


use_material_and_render :: proc(mat: iMaterial, model: Matrix4, ro: Render_Object) {
	next, ok := get_material(mat)
	for ok {
		next = use_material(next.id, model)
		draw_render_object(ro)
		next, ok = get_material(next.next)
	}
}

sprite_use_material_and_render :: proc(sprite: Sprite, model: Matrix4, ro: Render_Object) {
	next, ok := get_material(sprite.material)
	for ok {
		// kind of bad
		set_texture(&next, sprite.texture.id, 0)
		update_material(next)
		
		next = use_material(next.id, model)
		material_set_uniform(next.id, "tint", color_to_float(sprite.tint))
		draw_render_object(ro)
		next, ok = get_material(next.next)
	}
}

// texture == 0 means no texture
set_texture :: proc(mat: ^Material, texture: u32, num: i32) {
	mat.textures[num] = texture
}

// --------------------------------------------------------------------------------------------------



Render_Object :: struct {
	vao, vbo, ebo: u32,
	index_count: i32,

	primitive: u32,
	index_type: Index_Type,
}
make_render_object :: proc(vertices: []$T_Vertex, indices: []$T_Index, primitive := Primitive_Type.Triangle) -> Render_Object {
	primitive := u32(primitive)
	
	Vertex :: T_Vertex
	
	rc: Render_Object
	
	rc.primitive = primitive
	rc.index_type = get_index_type(T_Index)
	
	rc.index_count = i32(len(indices))
	gl.GenVertexArrays(1, &rc.vao);
	gl.BindVertexArray(rc.vao)
	
	gl.GenBuffers(1, &rc.vbo); 
	gl.GenBuffers(1, &rc.ebo); 
	
	
	gl.BindBuffer(gl.ARRAY_BUFFER, rc.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*size_of(type_of(vertices[0])), raw_data(vertices), gl.STATIC_DRAW)
	
	gl.EnableVertexAttribArray(0)
	gl.EnableVertexAttribArray(1)
	gl.EnableVertexAttribArray(2)
	gl.EnableVertexAttribArray(3)
	gl.VertexAttribPointer(0, len(Vector3), gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, position))
	gl.VertexAttribPointer(1, len(Vector2), gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, uv))
	gl.VertexAttribPointer(2, len(Vector3), gl.FLOAT, false, size_of(Vertex), offset_of(Vertex, normal))    
	gl.VertexAttribPointer(3, len(Color), gl.UNSIGNED_BYTE, true, size_of(Vertex), offset_of(Vertex, color))
	
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, rc.ebo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices)*size_of(indices[0]), raw_data(indices), gl.STATIC_DRAW)
	
	return rc
}

set_array_buffer :: proc(rc: Render_Object, vertices: []$T_Vertex) {
	gl.BindBuffer(gl.ARRAY_BUFFER, rc.vbo)
	gl.BufferData(gl.ARRAY_BUFFER, len(vertices)*size_of(T_Vertex), raw_data(vertices), gl.STATIC_DRAW)
}
// make_render_object :: proc{make_render_object_voxel}
delete_render_object :: proc(using rc: ^Render_Object) {
	gl.DeleteBuffers(1, &ebo)
	gl.DeleteBuffers(1, &vbo)
	gl.DeleteVertexArrays(1, &vao)
}

draw_render_object :: proc "contextless" (r: Render_Object) {
	gl.BindVertexArray(r.vao)
	gl.DrawElements(r.primitive, r.index_count, u32(r.index_type), nil)
}


// --------------------------------------------------------------------------------------------------
Frame_Buffer :: struct {
	fbo, color, rbo: u32,
}
Depth_Map :: struct {
	fbo, color: u32,
	size: Vector2i,
}
make_frame_buffer :: proc() -> Frame_Buffer {
	screen := get_window_size()
	
	// look at glViewport for window sizes
	fbo: u32
	gl.GenFramebuffers(1, &fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)

	color: u32
	gl.GenTextures(1, &color)
	gl.BindTexture(gl.TEXTURE_2D, color)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, screen.x, screen.y, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR) // gl.NEAREST ?
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, color, 0)

	rbo: u32
	gl.GenRenderbuffers(1, &rbo)
	gl.BindRenderbuffer(gl.RENDERBUFFER, rbo)
	gl.RenderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, screen.x, screen.y)
	gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo)
	
	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		panic("")
	}
	
	// gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)
	// DeleteFrameBuffer
	return Frame_Buffer{fbo = fbo, color = color, rbo = rbo}
}
make_link_frame_buffer :: proc() -> Frame_Buffer {
	screen := get_window_size()
	
	// look at glViewport for window sizes
	fbo: u32
	gl.GenFramebuffers(1, &fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)

	color: u32
	gl.GenTextures(1, &color)
	gl.BindTexture(gl.TEXTURE_2D, color)
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, screen.x, screen.y, 0, gl.RGB, gl.UNSIGNED_BYTE, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR) // gl.NEAREST ?
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, color, 0)
	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		panic("")
	}
	return Frame_Buffer{fbo = fbo, color = color}
}
make_msaa_frame_buffer :: proc() -> Frame_Buffer {
	screen := get_window_size()
	
	// look at glViewport for window sizes
	fbo: u32
	gl.GenFramebuffers(1, &fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)

	color: u32
	gl.GenTextures(1, &color)
	gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, color)
	gl.TexImage2DMultisample(gl.TEXTURE_2D_MULTISAMPLE, 4, gl.RGB, screen.x, screen.y, gl.TRUE)
	gl.BindTexture(gl.TEXTURE_2D_MULTISAMPLE, 0)
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D_MULTISAMPLE, color, 0)

	rbo: u32
	gl.GenRenderbuffers(1, &rbo)
	gl.BindRenderbuffer(gl.RENDERBUFFER, rbo)
	gl.RenderbufferStorageMultisample(gl.RENDERBUFFER, 4, gl.DEPTH24_STENCIL8, screen.x, screen.y)
	gl.BindRenderbuffer(gl.RENDERBUFFER, 0)
	gl.FramebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo)
	
	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		panic("")
	}
	
	// gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)
	// DeleteFrameBuffer
	return Frame_Buffer{fbo = fbo, color = color, rbo = rbo}
}

make_depth_map :: proc() -> Depth_Map {
	screen := get_window_size()
	
	fbo: u32
	gl.GenFramebuffers(1, &fbo)
	gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)

	// depth map
	depth: u32
	gl.GenTextures(1, &depth)
	gl.BindTexture(gl.TEXTURE_2D, depth)
	size := Vector2i{1024, 1024}
	gl.TexImage2D(gl.TEXTURE_2D, 0, gl.DEPTH_COMPONENT, size.x, size.x, 0, gl.DEPTH_COMPONENT, gl.FLOAT, nil)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	
	gl.FramebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, depth, 0)
	gl.DrawBuffer(gl.NONE)
	gl.ReadBuffer(gl.NONE)
	if gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE {
		panic("")
	}
	
	// gl.BindFramebuffer(gl.FRAMEBUFFER, fbo)
	// DeleteFrameBuffer
	return Depth_Map{fbo = fbo, color = depth, size=size}
}
// --------------------------------------------------------------------------------------------------

load_and_generate_texture :: proc(file_name: string, store_data := false, wrap := gl.CLAMP_TO_EDGE) -> u32 {
	img.set_flip_vertically_on_load(1)
	x,y,n: i32
	dir: string = "./data/textures/"
	path: string = str.concatenate( {dir,file_name} ); defer delete(path)
	
	cpath := str.clone_to_cstring(path); defer delete(cpath)

	// force 4 components per pixel so we can just use gl.RGBA
    // data := img.loadf(cpath, &x, &y, &n, 4)
	// TODO: should look into this prob
	// using loadf is kinda weird
	
	data := img.load(cpath, &x, &y, &n, 4)

	if data==nil {
		fmt.eprintln("could not load image")
		return 0
	}
	
	texture: u32
	gl.GenTextures(1,&texture)
	gl.BindTexture(gl.TEXTURE_2D,texture)
	
    // CLAMP_TO_EDGE removes texel leaking
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(wrap))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(wrap))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, x, y, 0, gl.RGBA, gl.UNSIGNED_BYTE, data)
    gl.GenerateMipmap(gl.TEXTURE_2D)

    
    tex := Texture {id = texture, size = {i32(x), i32(y)}}
    if store_data {
		// The raw image data has x*y*4 entries
		tex.data = make([]Vector4, x*y)
		for i := 0; i < 4*int(x*y) - 3; i += 4 {
			#unroll for j in 0..<4 {
				tex.data[i/4][j] = f32(data[i+j])/255.0
			}
		}
	}
	img.image_free(data)
	
	name, suffix := get_name_and_suffix_temp(file_name)

	_key, _val := delete_key(&asset_manager.textures, name)
	delete(_key)
	asset_manager.textures[str.clone(name)] = tex
	return texture
}
make_texture :: proc(data: []Color, size: Vector2i, wrap := gl.CLAMP_TO_EDGE) -> Texture {
	texture: u32
	gl.GenTextures(1,&texture)
	gl.BindTexture(gl.TEXTURE_2D,texture)
	
    // CLAMP_TO_EDGE removes texel leaking
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(wrap))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(wrap))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
    
    gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGBA, size.x, size.y, 0, gl.RGBA, gl.UNSIGNED_BYTE, raw_data(data))
    gl.GenerateMipmap(gl.TEXTURE_2D)
    return Texture{id = texture, size = size}
}
// --------------------------------------------------------------------------------------------------
get_polygon_mode :: proc() -> u32 {
	// returns two values so i64
	mode: i64
	gl.GetIntegerv(gl.POLYGON_MODE, (^i32)(&mode))
	return u32(mode)
}


// --------------------------------------------------------------------------------------------------
Point_Primitive :: struct {
	size: f32,
}
Line_Primitive :: struct {
	width: f32,
}

Primitive_Type :: enum {
	Point = gl.POINTS,
	Line = gl.LINES,
	Triangle = gl.TRIANGLES,
}
Primitive_Data :: union {
	Point_Primitive,
	Line_Primitive,
}
Primitive :: struct {
	material: iMaterial,
	render_object: Render_Object,
	transform: Matrix4,
	data: Primitive_Data,
	type: Primitive_Type,
	using mesh: Basic_Mesh,
}

primitive_render_list: [dynamic]^Primitive
g_cube_primitive: ^Primitive

new_primitive :: proc(mesh: Basic_Mesh, type: Primitive_Type, material: Material, auto_draw := false) -> ^Primitive {
	_primitive, _ :=  mem.alloc(size_of(Primitive))
	primitive := cast(^Primitive)_primitive

	primitive.mesh = clone_mesh(mesh)
	primitive.material = material.id
	primitive.transform = Matrix4(1)
	primitive.type = type
	
	primitive.render_object = make_render_object(mesh.vertices, mesh.indices, type)
	switch type {
		case .Point:
		primitive.data = Point_Primitive{size = 1}
		case .Line:
		primitive.data = Line_Primitive{width = 1}
		case .Triangle:
	}
	if auto_draw {
		append(&primitive_render_list, primitive)
	}
	return primitive
}
free_primitive :: proc(p: ^Primitive) {
	delete(p.mesh.vertices)
	delete(p.mesh.indices)
	free(p)
}
draw_primitive :: proc(primitive: ^Primitive) {
	use_material(primitive.material, primitive.transform)
	raw_draw_primitive(primitive)
}
raw_draw_primitive :: proc(primitive: ^Primitive) {
	#partial switch data in primitive.data {
		case Point_Primitive:
		gl.PointSize(data.size)
		case Line_Primitive:
		gl.LineWidth(data.width)
	}
	draw_render_object(primitive.render_object)
}
draw_primitives :: proc() {
	
	for primitive in primitive_render_list {
		#force_inline draw_primitive(primitive)
	}
}
