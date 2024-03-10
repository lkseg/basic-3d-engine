package game
import "core:fmt"

import queue "core:container/queue"
import pqueue "core:container/priority_queue"
import "core:container"
import str "core:strings"
import "core:builtin"
import "core:slice"
import "core:math" 
import engine "../engine"
import sarr "core:container/small_array"

iPawn_Bucket :: Small_Array(4, iPawn)
Pawn_Bucket :: Small_Array(4, ^Pawn)

Grid3D :: struct {
	using astar: AStar,
	size: Vector3i,
}

Direction :: enum {
	N = 0,
	E,
	S,
	W,
}

is_valid_position :: proc "contextless" (grid: Grid3D, p: AStar_Position) -> bool {
	return p.x>=0 && p.y>=0 && p.z>=0 && p.x<grid.size.x && p.y<grid.size.y && p.z<grid.size.z
}


can_move_to_id :: proc(grid: Grid3D, id: iPoint) -> bool {
	point, ok := grid_get_point_safe(grid, id)
	if !ok || !is_valid_position(grid, point.position) || point.disabled || point.occupied {
		return false
	}
	return true
}
can_move_to_position :: proc(grid: Grid3D, position: AStar_Position) -> bool {
	
	return is_valid_position(grid, position) && can_move_to_id(grid, grid_to_id(grid, position))
}
can_move_to :: proc{can_move_to_id, can_move_to_position}

grid_move :: proc "contextless" (grid: Grid3D, from: AStar_Position, to: AStar_Position) -> bool {
	if !is_valid_position(grid, to) {
		return false
	}
	return true
}


grid_to_id :: proc "contextless" (grid: Grid3D, v: Vector3i) -> iPoint {
	stride_xz := grid.size.x*grid.size.z
	id := v.y*stride_xz + v.z*grid.size.x + v.x
	return auto_cast id
}

grid_get_point_safe :: proc "contextless" (grid: Grid3D, id: iPoint) -> (AStar_Point, bool) #optional_ok {
	if 0<=id && id<len(grid.points) {
		return grid.points[id], true
	}
	return {}, false
}
grid_get_point :: proc "contextless" (grid: Grid3D, v: Vector3i) -> AStar_Point {
	id := #force_inline grid_to_id(grid, v)
	return grid.points[id]
}
grid_get_position :: proc (grid: Grid3D, id: iPoint) -> AStar_Position {
	assert(0<= id && id<len(grid.points))
	return grid.points[id].position
}
grid_get_pawns :: proc(grid: Grid3D, point: iPoint)  -> Pawn_Bucket {
	pawns := grid.points[point].pawns
	bucket: Pawn_Bucket
	sarr.resize(&bucket, pawns.len)
	for i:=0; i<bucket.len; i+=1 {
		bucket.data[i] = get_pawn(pawns.data[i])
	}
	return bucket
}

// returns the pawn that *occupies* at position
pawn_at :: proc(grid: Grid3D, position: AStar_Position) -> ^Pawn {
	if !is_valid_position(grid, position) {
		return nil
	}
	point := grid_get_point(grid, position)
	for i in 0..<point.pawns.len {
		pawn := get_pawn(point.pawns.data[i])
		if .Occupies in pawn.flags {
			return pawn
		}
	}
	return nil
}
make_astar_grid3d :: proc(x: i32, y: i32, z: i32) -> Grid3D {
	grid: Grid3D
	grid.size = {x, y, z}
	grid.points = make(type_of(grid.points), 0, x*y*z)

	y_stride := iPoint(x*z)
	x := f32(x)
	y := f32(y)
	z := f32(z)

	
	for k in 0..<i32(y) do for j in 0..<i32(z) do for i in 0..<i32(x) {
		
		id := #force_inline astar_add_point(&grid, AStar_Position{i, k, j})
		
		i, j, k := f32(i), f32(j), f32(k)
		if 0 < i do connect_points(grid, id, id-1)
		if i < x - 1 do connect_points(grid, id, id+1)
		
		if 0 < j do connect_points(grid, id, id - auto_cast x)
		if j < z -1  do connect_points(grid, id, id+ auto_cast x)

		if 0 < k do connect_points(grid, id, id - y_stride)
		if k < y -1  do connect_points(grid, id, id + y_stride)
	}
	// for i in 0..<f32(x) do for j in 0..<f32(z) do for k in 0..<f32(y) {
	// 	#force_inline astar_add_point(astar, Vector3{i, j, k})
	// }
	return grid
}

grid_add_pawn :: proc(grid: Grid3D, pawn: ^Pawn, ipoint: iPoint) -> bool {
	p := &grid.points[ipoint]
	pawns := &p.pawns
	if sarr.space(pawns^) > 0 {
		sarr.append(pawns, pawn.id)
		if .Occupies in pawn.flags {
			p.occupied = true
		} 
		return true
	}
	return false
}
grid_remove_pawn :: proc(grid: Grid3D, pawn: ^Pawn) -> bool {
	p := &grid.points[pawn.point]
	pawns := &p.pawns
	if idx := is_in_array(sarr.slice(pawns), pawn.id); idx >= 0 {
		sarr.unordered_remove(pawns, idx)

		// check if there is still a pawn inside which occupies the space
		p.occupied = false
		for i:=0; i<pawns.len; i+=1 {
			pawn := get_pawn(pawns.data[i])
			if .Occupies in pawn.flags {
				p.occupied = true
				break
			}
		}
		return true
	}
	return false
}
iAStar :: int
iPoint :: iAStar
Position_Core :: i32
AStar_Position :: Vector3i
AStar_Point :: struct {
    position: AStar_Position,
    neighbours: map[iPoint]iPoint,
    id: iPoint,
	disabled: bool,

	// specific stuff
	occupied: bool,
	pawns: iPawn_Bucket,
}

AStar :: struct {
    points: [dynamic] AStar_Point,
}

astar_exists :: proc(astar: AStar, id: iPoint) -> bool {
	return 0<=id&&id<len(astar.points)
}
astar_get_point :: #force_inline proc "contextless" (astar: AStar, id: iPoint) -> AStar_Point {
	return astar.points[id]
}

astar_add_point :: proc(astar: ^AStar, p: AStar_Position) -> iPoint {
	
	a: AStar_Point
	a.position = p
	a.id = len(astar.points)
	append(&astar.points, a)
	return a.id
}
	
astar_get_position :: #force_inline proc(astar: AStar, id: iPoint) -> AStar_Position {
	return astar.points[id].position
}


astar_get_next_position :: #force_inline proc(astar: AStar, path: []iPoint) -> AStar_Position {
	return astar.points[path[len(path)-1]].position
}
astar_iterate :: #force_inline proc(astar: AStar, path: []iPoint) -> (AStar_Position, []iPoint) {
	pos :=  astar.points[path[len(path)-1]].position
	path := path[:len(path)-1]
	return pos, path
}

// This procedure is idempotent
connect_points :: proc(astar: AStar, a, b: iPoint) {
	astar.points[a].neighbours[b] = b
}
connect_points_bi :: proc(astar: AStar, a, b: iPoint) {
	astar.points[a].neighbours[b] = b
	astar.points[b].neighbours[a] = a
}

is_connected :: proc(a, b: ^AStar_Point) -> bool {
    _, ok := a.neighbours[b.id]
    return ok
}

delete_astar :: proc(using astar: AStar) {
    for p in points {
		delete(p.neighbours)
    }
    delete(points)
}




