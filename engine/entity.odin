package engine
import gl "vendor:OpenGL" // TODO should not be here
import la "core:math/linalg"

Transform :: struct {
	position: Vector3,
	scale: Vector3,
	rotation: Quaternion,
}

// Component_Update :: #type proc(component: ^Entity_Component, delta: f32)

// Entity_Component :: struct {
// 	entity: iEntity,
// 	type: Entity_Component_Type,
// 	update: Component_Update,
// 	component: union {
// 		Renderer_Component,
// 		Collision_Component,
// 		Voxel_Component,
// 	},
// }
Light_Type :: enum {
	Directional = 0,
}
Light :: struct {
	type: Light_Type,
	range: f32,
	position: Vector3,
	direction: Vector3,
	enabled: bool,
	space: Matrix4,
}
light_entity: ^Entity
Default_Entity :: struct {}
Internal_Entity :: union #no_nil {
	Default_Entity,
	Light,
}
Entity_Flag :: enum {
	Selected = 0,
}
iEntity :: u32

Entity_Component_Type :: enum u16 {
	Renderer = 0,
	Collision,
	Voxel,
}



Entity :: struct {
	id: iEntity,
	using transform: Transform,
	
	renderer: Maybe(Renderer_Component),
	collision: Maybe(Collision_Component),
	
	
	flags: bit_set[Entity_Flag],
	temp_flags: bit_set[Entity_Flag],

	internal: Internal_Entity,
	// derived object that the game uses
	derived: Maybe(u32),
}
Entity_Manager :: struct {
	// TODO 
	// for now use a map but at some point 
	// it will be necessary to have our own Hash_Map 
	entities: map[iEntity] Entity,
	total_entity_count: iEntity,
}; entity_manager: ^Entity_Manager

init_entity_manager :: proc() {
	entity_manager.entities = make(map[iEntity]Entity, 4096)
}
entity_set_tint :: proc(entity: ^Entity, tint: Color) {
	renderer := &entity.renderer.?
	assert(renderer != nil)
	renderer.tint = color_to_float(tint)
}
entity_set_color :: entity_set_tint

new_voxel_entity :: proc(tint: Color) -> ^Entity {
	entity := new_entity()
	entity.scale *= 0.95
	
	com := make_component(Renderer_Component)
	com.primitive = g_cube_primitive
	
	entity.renderer = com
	entity_set_tint(entity, tint)
	
	col := make_component(Collision_Component)
	col.use_mesh = true
	entity.collision = col
	return entity
}


renderer_update :: proc(entity: ^Entity, delta: f32) {
	v, ok := &entity.renderer.?
	assert(ok)
	
	v.primitive.transform = la.matrix4_from_trs(entity.position, entity.rotation, entity.scale)
	use_material(v.primitive.material, v.primitive.transform)
	
	set_uniform(v.primitive.material, "tint", v.tint)
	raw_draw_primitive(v.primitive)
}
Renderer_Component :: struct {
	primitive: ^Primitive,
	tint: Vector4,
}
delete_renderer_component :: proc(rc: ^Renderer_Component) {
	assert(rc != nil)
	if rc.primitive != nil {
		// free_primitive(rc.primitive)
	} else {
		eprintln("tried to delete empty renderer component")
	}
}
get_mesh :: proc(r: ^Renderer_Component) -> Basic_Mesh {
	assert(r.primitive != nil)
	return r.primitive.mesh
}
Collision_Component :: struct {
	use_mesh: bool,
}
collision_update :: proc(entity: ^Entity, delta: f32) {}

make_entity_component :: proc($T: typeid) -> T {
	// c: Entity_Component
	v: T
	when T == Renderer_Component {
		v.primitive = nil
		v.tint = {1,1,1,1}
	} when T == Collision_Component {
	}
	return v
}
make_component :: make_entity_component

get_entity_manager :: #force_inline proc "contextless" () -> ^Entity_Manager {
	return entity_manager
}


delete_entity_manager :: proc() {
	es := get_entity_manager()
	for key in es.entities {
		delete_entity(&es.entities[key])
		// delete_key(&es.entities, key) memory leak?
	}
	// for key in es.entities {
	// 	delete_key(&es.entities, key)
	// }
	// clear_map(&es.entities)
	delete(es.entities)
}



get_entity :: #force_inline proc "contextless" (id: iEntity) -> ^Entity {
	return &entity_manager.entities[id]
}
new_entity :: proc() -> ^Entity {

	e := Entity{}
	entity_manager.total_entity_count += 1
	e.id = entity_manager.total_entity_count// cast(iEntity) len(entity_manager.entities)+1
	assert(get_entity(e.id) == nil)
	e.rotation = 1
	e.scale = {1, 1, 1}
	entity_manager.entities[e.id] = e
	
	return &entity_manager.entities[e.id]
}

delete_entity :: proc(e: ^Entity) {
	if c := &e.renderer.?; c != nil {
		delete_renderer_component(c)
	}
}
free_entity :: proc(e: ^Entity) {
	
	if c := &e.renderer.?; c != nil {
		delete_renderer_component(c)
	}
	free(e)
}

entity_update :: proc(entity: ^Entity, delta: f32) {
	collision_update(entity, delta)
	renderer_update(entity, delta)
}

update_entities :: proc(delta: f32) {
	for _, entity in &entity_manager.entities {
		mode := get_polygon_mode()
		if .Selected in entity.temp_flags {
			gl.PolygonMode(gl.FRONT_AND_BACK, gl.LINE)
		}
		entity_update(&entity, delta)
		entity.temp_flags = {}
		gl.PolygonMode(gl.FRONT_AND_BACK, mode)
	}
}
// primarily used to fill the depth map
raw_draw_entities :: proc(shader: Shader) {
	manager := get_entity_manager()
	for _, entity in &manager.entities {
		r := &entity.renderer.?
		assert(r != nil)
		r.primitive.transform = la.matrix4_from_trs(entity.position, entity.rotation, entity.scale)
		safe_set_uniform(shader, "model" , r.primitive.transform)
		// println( (_LIGHTM*r.primitive.transform)*Vector4{1, 1, 1, 1})
		raw_draw_primitive(r.primitive)
	}
}
get_entity_under_mouse :: proc() -> (^Entity, Collision_Info) {
	ray := get_ray_from_mouse()
	
	min_distance := max(f32)
	min_entity: ^Entity
	min_info: Collision_Info
	
	for _, entity in &entity_manager.entities {
		c := &entity.collision.?
		if c != nil && c.use_mesh {
			mesh := get_mesh(&entity.renderer.?)
			ray := ray
			ray.position -= entity.position

			// TODO
			info := ray_mesh_collision_scale(ray, mesh, entity.scale)
			if info.is_hit && info.distance < min_distance {
				min_distance = info.distance
				min_entity = &entity
				min_info = info
			}
		}
	}
	if min_entity != nil {
		min_info.position += min_entity.position
	}
	return min_entity, min_info
}

// get_component :: proc(entity: ^Entity, $T: typeid) -> ^T {
// 	for v in &entity.components {
// 		c, ok := &v.component.(T)
// 		if ok do return c
// 	}
// 	return nil
// }
// get_component_by_type :: proc(entity: ^Entity, type: Entity_Component_Type) -> rawptr {
// 	return &entity.compoents[type].?
// }

// get_component :: proc{get_component_by_type, get_component_by_typeid}
