package game

import "core:testing"

ev :: testing.expect_value
ptrT :: ^testing.T
expect_value :: testing.expect_value
expectv :: expect_value

@test
test_grid_movement :: proc(t: ptrT) {
	grid := make_astar_grid3d(3, 3, 3)
	defer delete_astar(grid)
	println(grid_to_id(grid, {0, 0, 0}))
	println(grid_to_id(grid, {1, 0, 0}))
	println(grid_to_id(grid, {0, 1, 0}))
	println(grid_to_id(grid, {0, 0, 1}))
	println(grid_to_id(grid, {1, 0, 1}))
}



@test
test_copy :: proc(t: ptrT) {
	a: Small_Array(10, int)
	a.data[0] = 3
	a.data[1] = -1
	b := a
	
	b.data[0] = -8
	println(b.data[0])
	println(a.data[0])
}


@test
rawptr_arg :: proc(t: ptrT) {
	Stuff ::  struct {
		data: rawptr,
	}
	Object :: struct {
		val: int,
	}
	stuff := Stuff{}
	object := Object{5}
	do_thing :: proc(stuff: ^Stuff, object: ^Object) {
		stuff.data = object
	}

	do_thing(&stuff, &object)
	more_stuff: [100]int
	for i in 0..<100 {
		more_stuff[i] += 1
	}
	println(cast(^Object)stuff.data)
	
}
