package engine
import glfw "vendor:glfw"
import sarr "core:container/small_array"
import "core:runtime"
import la "core:math/linalg"
get_time :: glfw.GetTime
RELEASE :: glfw.RELEASE
PRESS   :: glfw.PRESS
REPEAT  :: glfw.REPEAT


Keyboard_Key :: enum i32 {
	Zero = 48,
	One = 49,
	Two = 50,
	Three = 51,
	Four = 52,
	Five = 53,
	Six = 54,
	Seven = 55,
	Eight = 56,
	Nine = 57,
	
	Space = 32,
	
	A = 65,
	B = 66,
	C = 67,
	D = 68,
	E = 69,
	F = 70,
	G = 71,
	H = 72,
	I = 73,
	J = 74,
	K = 75,
	L = 76,
	M = 77,
	N = 78,
	O = 79,
	P = 80,
	Q = 81,
	R = 82,
	S = 83,
	T = 84,
	U = 85,
	V = 86,
	W = 87,
	X = 88,
	Y = 89,
	Z = 90,
	
	Escape = 256,
	Shift = glfw.KEY_LEFT_SHIFT,
	Alt = glfw.KEY_LEFT_ALT,
}
Mouse_Key :: enum i32 {
	Button_1 = 0,
	Button_2 = 1,
	Button_3 = 2,
	Button_4 = 3,
	Button_5 = 4,
	Button_6 = 5,
	Button_7 = 6,
	Button_8 = 7,
	
	Last = Button_8,
	Left = Button_1,
	Right = Button_2,
	Middle = Button_3,
}


Key_Type :: enum {
	Keyboard = 0,
	Mouse,
}

Key :: struct {
	id: union {
		Keyboard_Key,
		Mouse_Key,
	},
	pressed: bool,
	just_pressed: bool,
}
Input_Manager :: struct {
	queue: sarr.Small_Array(50, Key),
	cursor: Cursor,
	keyboard_keys_info: map[Keyboard_Key] Key,
	mouse_keys_info: map[Mouse_Key] Key,
}; input_manager: ^Input_Manager

init_input_manager :: proc() {
	handle := get_window().handle
	glfw.SetKeyCallback(handle, key_callback)
	glfw.SetCursorPosCallback(handle, cursor_position_callback)
	glfw.SetMouseButtonCallback(handle, mouse_button_callback)
	glfw.SetScrollCallback(handle, scroll_callback)
	
	keyboard_keys_info := get_keyboard_keys_info()
	mouse_keys_info := get_mouse_keys_info()
	for k in Keyboard_Key {
		keyboard_keys_info[k] = Key{id = k}
	}
	for k in Mouse_Key {
		mouse_keys_info[k] = Key{id = k}
	}
}
input_manager_clear :: proc() {
	keyboard_keys_info := get_keyboard_keys_info()
	mouse_keys_info := get_mouse_keys_info()
	for _, k in keyboard_keys_info {
		k.just_pressed = false 
	}
	for _, k in mouse_keys_info {
		k.just_pressed = false 
	}
	sarr.clear(&get_input_manager().queue)
}
get_keyboard_keys_info :: #force_inline proc "contextless" () -> ^map[Keyboard_Key] Key {
	return &get_input_manager().keyboard_keys_info
}
get_mouse_keys_info :: #force_inline proc "contextless" () -> ^map[Mouse_Key] Key {
	return &get_input_manager().mouse_keys_info
}
get_input_manager :: #force_inline proc "contextless" () -> ^Input_Manager {
	return input_manager
}




Cursor :: struct {
	position: Vector2,
	previous_position: Vector2,
	motion: Vector2,
	raw_motion: Vector2,
	scroll: Vector2,
	updated: bool, // if it updated last poll
}

get_cursor :: #force_inline proc "contextless" () -> ^Cursor {
	return &get_input_manager().cursor
}
get_mouse_position :: proc() -> Vector2 {
	return get_cursor().position
}
get_mouse_position_ii :: proc() -> (i32, i32) {
	v := get_mouse_position()
	return i32(v.x), i32(v.y)
}

get_mouse_motion :: proc() -> Vector2 {
	return get_cursor().motion
}
get_mouse_scroll :: proc() -> Vector2 {
	return get_cursor().scroll
}


// context = runtime.default_context() for context
cursor_position_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
	cursor := get_cursor()
	cursor.previous_position = cursor.position
	cursor.position = {f32(x), f32(y)}
	// add up until it is being read at the start of a frame
	cursor.raw_motion += cursor.position - cursor.previous_position
	cursor.updated = true
}


fetch_cursor_motion :: proc() {
	cursor := get_cursor()
	cursor.motion = cursor.raw_motion
	cursor.raw_motion = {}
}
// only press or release

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, key, action, mods: c_int) {
	
	
	k, ok := &get_mouse_keys_info()[Mouse_Key(key)]
	if !ok do return
	// order is important
	k.just_pressed = action == PRESS && !k.pressed
	k.pressed = action > RELEASE
	im := get_input_manager()
	sarr.append(&im.queue, k^)
	// k: Key
	// k.id = Mouse_Key(key)
	// k.pressed = action > RELEASE
	// im := get_input_manager()
	// im.mouse[k.id.(Mouse_Key)] = k
}

scroll_callback :: proc "c" (window: glfw.WindowHandle, x, y: f64) {
	get_cursor().scroll = {f32(x), f32(y)}
}
// should not depend on repeat really
// action == release(0); press(1); repeat(2)
key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: c_int) {
	k, ok := &get_keyboard_keys_info()[Keyboard_Key(key)]
	if !ok do return
	k.just_pressed = action == PRESS && !k.pressed
	k.pressed = action > RELEASE
	im := get_input_manager()
	sarr.append(&im.queue, k^)
	// k: Key
	// k.id = Keyboard_Key(key)
	// k.pressed = action > RELEASE
	// im := get_input_manager()
	// im.keyboard[k.id.(Keyboard_Key)] = k
}

is_key_pressed :: proc(key: Keyboard_Key) -> bool {
	k, ok := get_keyboard_keys_info()[key]
	if !ok do return false
	return k.pressed
}
is_pressed_keyboard :: proc(key: Keyboard_Key) -> bool {
	return is_key_pressed(key) 
}
is_pressed_mouse :: proc(key: Mouse_Key) -> bool {
	k, ok := get_mouse_keys_info()[key]
	if !ok do return false
	return k.pressed
}
is_pressed :: is_pressed_keyboard

is_just_pressed :: proc(key: Keyboard_Key) -> bool {
	k, ok := get_keyboard_keys_info()[key]
	if !ok do return false
	return k.just_pressed
}
is_just_pressed_mouse :: proc(key: Mouse_Key) -> bool {
	k, ok := get_mouse_keys_info()[key]
	if !ok do return false
	return k.just_pressed
}

get_input_direction :: proc(w := Keyboard_Key.W, a := Keyboard_Key.A, s := Keyboard_Key.S, d := Keyboard_Key.D) -> Vector2 {
	vel: Vector2
	if is_key_pressed(d) {
		vel.x += 1.0  
	}
	if is_key_pressed(a) {
		vel.x -= 1.0
	}
	if is_key_pressed(w) {
		vel.y += 1.0
	}
	if is_key_pressed(s) {
		vel.y -= 1.0
	}
	if la.length(vel) == 0 do return {}
	return normalize(vel)
}
get_just_input_direction :: proc(w := Keyboard_Key.W, a := Keyboard_Key.A, s := Keyboard_Key.S, d := Keyboard_Key.D) -> Vector2 {
	vel: Vector2
	if is_just_pressed(d) {
		vel.x += 1.0  
	}
	if is_just_pressed(a) {
		vel.x -= 1.0
	}
	if is_just_pressed(w) {
		vel.y += 1.0
	}
	if is_just_pressed(s) {
		vel.y -= 1.0
	}
	if la.length(vel) == 0 do return {}
	return normalize(vel)
}

