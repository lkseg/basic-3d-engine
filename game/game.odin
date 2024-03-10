package game
import engine "../engine"
import "core:math"
import "core:reflect"

// Everything marked with @export gets passed to the engine

get_entity :: #force_inline proc(pawn: Pawn) -> ^engine.Entity {
	return engine.get_entity(pawn.entity)
}

Camera :: engine.Camera
Game :: struct {
	camera: Camera,
	engine: engine.Engine_Interface,
}; game: Game

Area :: struct {
	grid: Grid3D,
}; current_area: Area

get_current_area :: #force_inline proc "contextless"() -> ^Area {
	return &current_area
}
iPawn:: u32

Pawn_Type :: enum {
	None = 0,
	Block,
	Fighter,
	Player,
}
Property :: enum {
	Pushable = 0,
	Occupies,    // two *Occupies* Pawns can't be at the same cell
	
}
Properties :: bit_set[Property]
Pawn :: struct {
	id: iPawn,
	offset: Vector3,
	point: iAStar,
	entity: engine.iEntity,
	type: Pawn_Type,
	flags: Properties,
	// derived: ...
}
Pawn_Manager :: struct {
	pawns: map[iPawn] Pawn,
	total_pawn_count: iPawn,
}; pawn_manager: Pawn_Manager


init_pawn_manager :: proc() {
	pawn_manager.pawns = make(map[iPawn]Pawn, 4096)
}
get_derived :: #force_inline proc "contextless" (e: ^engine.Entity) -> ^Pawn {
	// return cast(^Pawn)e.derived
	return get_pawn(e.derived.?)
}
get_pawn_manager :: #force_inline proc "contextless" () -> ^Pawn_Manager {
	return &pawn_manager
}
get_pawn :: #force_inline proc "contextless" (id: iPawn) -> ^Pawn {
	return &get_pawn_manager().pawns[id]
}
get_position :: #force_inline proc(pawn: Pawn) -> AStar_Position {
	return grid_get_position(current_area.grid, pawn.point)
}

pawn_init_point :: proc(pawn: ^Pawn, point: iAStar) {
	area := get_current_area()
	next := &area.grid.points[point]
	assert(!next.disabled)
	if grid_add_pawn(area.grid, pawn, point) {
		pawn.point = point
		return
	}
	panic("could not initialize pawn")
}

// unchecked
pawn_set_point :: proc(pawn: ^Pawn, point: iAStar) {
	area := get_current_area()
	curr := &area.grid.points[pawn.point]
	next := &area.grid.points[point]
	assert(!next.disabled)
	assert(!next.occupied)
	// curr.disabled = false
	// next.disabled = true
	if grid_remove_pawn(area.grid, pawn) {
		if grid_add_pawn(area.grid, pawn, point) {
			pawn.point = point
		}
	}
}

INPUT_DELAY :: 0.5


// TODO pawn_move for editor; since we don't wanna have stuff like push i.e. the general game logic
pawn_move :: proc(pawn: ^Pawn, dir: Vector3i) {
	area := get_current_area()
	grid := &area.grid
	pos := grid_get_position(grid^, pawn.point) + dir

	pushable_prop := Properties{.Occupies, .Pushable}
	if tar := pawn_at(grid^, pos); tar != nil &&  pushable_prop <= tar.flags {
		push_pos := pos+dir
		if can_move_to(grid^, push_pos) {
			pawn_set_point(tar, grid_to_id(grid^,  push_pos))
			pawn_set_point(pawn, grid_to_id(grid^, pos))
		}
	} else {
		ok := can_move_to(grid^, pos)
		if ok {
			pawn_set_point(pawn, grid_to_id(grid^, pos))
		}
	}
}


pawn_update :: proc(pawn: ^Pawn, delta: f32 = 0) {
	grid := &current_area.grid
	
	current := get_position(pawn^)
	@(static) delta_sum := f32(0)
	@(static) delay_timer := f32(0)
	
	
	player_section: if pawn.type == .Player {
		if delta_sum <=  1 do delta_sum += delta
		// if delay_timer<=INPUT_DELAY {
		// 	delay_timer += delta
		// 	break player_section
		// }
		
		dir := engine.get_just_input_direction()
		
		v: Vector3i
		switch {
			case dir.x<0:
			v.z = -1
			case dir.x>0:
			v.z = 1
			case dir.y<0:
			v.x = -1
			case dir.y>0:
			v.x = 1
		}
		
		pawn_move(pawn, v)
	}
	entity := get_entity(pawn^)
	entity.position = to_vector3(grid_get_position(grid^, pawn.point)) + pawn.offset
}

new_pawn :: proc(entity: ^engine.Entity) -> ^Pawn {
	manager := get_pawn_manager()
	pawns := &manager.pawns
	manager.total_pawn_count += 1
	id := manager.total_pawn_count
	pawn := Pawn{}
	pawn.id = id
	assert(get_pawn(pawn.id) == nil)
	pawn.entity = entity.id
	pawns[id] = pawn
	// entity.derived = &pawns[id]
	entity.derived = id
	
	return &pawns[id]
}

@(export)
make_game :: proc(engine_data: engine.Engine_Data, args: ..any) {
	
	engine.set_engine_data(engine_data)
	init_pawn_manager()
	game.camera = engine.make_camera()
	// game.camera.position = {1, 7, 1}
	// game.camera.target = {0.562, 0.583, 0.196}
	// game.camera.position = {0,8,0}
	// game.camera.target = {1,0,1}
	// game.camera.rotation = engine.camera_rotation_from_target(game.camera)
	game.camera.position = {0, 20, 0}
	game.camera.rotation = quaternion_from(-PI/2,0,-PI/2)
	// game.camera.rotation = quaternion_from(PI/2,0,0)
	engine.camera_update(&game.camera)
	
	current_area.grid = make_astar_grid3d(10, 4, 10)
	game.engine = cast_any(args[0], engine.Engine_Interface)
	new_voxel_entity := game.engine.new_voxel_entity

	
	for point in current_area.grid.points {
		cell := point.position
		color: Color
		if cell.y <= 0 {
			color = BROWN
		}
		if cell.y <= 0 && cell.x <= 1 {
			color = BLUE
		}
		if color == {} do continue
		entity := new_voxel_entity(color)
		pawn := new_pawn(entity)
		pawn.flags = {.Occupies}
		pawn_init_point(pawn, point.id)
		pawn_update(pawn)
		
	}
	
	pawn := new_pawn(new_voxel_entity(WHITE))
	
	pawn.offset = {0, -0.25, 0}
	pawn.flags = {.Occupies}
	get_entity(pawn^).scale = {0.5, 0.5, 0.5}
	pawn.type = .Player
	pawn_init_point(pawn, grid_to_id(current_area.grid, {0, 1, 0}))
	pawn_update(pawn)

	
	pawn = new_pawn(new_voxel_entity(WHITE))
	pawn.flags = {.Pushable, .Occupies}
	pawn_init_point(pawn, grid_to_id(current_area.grid, {1, 1, 1}))
	pawn_update(pawn)
}

@(export)
game_update :: proc(engine_data: engine.Engine_Data, delta: f32) {
	engine.set_engine_data(engine_data)
	
	game.engine.set_active_camera(game.camera)
	pawns := &pawn_manager.pawns
	for _, pawn in pawns {
		pawn_update(&pawn, delta)
	}
	engine.camera_update(&game.camera)
}
@(export)
delete_game :: proc() {
	delete_astar(current_area.grid)
	delete(pawn_manager.pawns)
}
