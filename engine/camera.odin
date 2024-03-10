package engine
import la "core:math/linalg"
import glm "core:math/linalg/glsl"
Camera :: struct {
	position: Vector3,
	target: Vector3,
	// distance: f32, // for an orbital camera this makes things simpler
	
	rotation: Quaternion,
	scale: Vector3,
	angles: [3]f32,
	transform: Matrix4,
	view: Matrix4,
	projection: Matrix4,
	near, far: f32,
	
}; active_camera, engine_camera: Camera; 

camera_arm :: #force_inline proc "contextless"(camera: Camera) -> Vector3 {
	return camera.position - camera.target
}

handle_engine_camera_input :: proc() {
	camera := get_engine_camera()
	_camera := camera^
	x, y, z := get_basis(camera.transform)
	motion: Vector2
	dir: Vector2
	
	if is_pressed_mouse(.Middle) {
		if is_pressed(.Shift) {
			dir = get_mouse_motion() * 0.005
		} else {
			motion = get_mouse_motion() * 0.01
		}
	}
	
	camera.position += (-dir.x*x  + dir.y*y) * 15
	camera.target   += (-dir.x*x + dir.y*y) * 15
	
	
	camera.angles.y += -motion.x
	camera.angles.x = clamp(camera.angles.x-motion.y, -PI/4, PI/4)
	
	
	qy := from_euler_y(camera.angles.y)
	qx := from_euler_x(camera.angles.x)

	
	distance := vlength(camera.position - camera.target)
	d := Vector3{0, 0, distance}
	d = mul(qy*qx, d)
	camera.position = camera.target + d
	{
		camera.rotation =  camera_rotation_from_target(camera^)
	}
	if scroll := get_mouse_scroll(); scroll.y != 0 {
		d := camera.target - camera.position
		// l := vlength(d)
		camera.position +=  d * scroll.y * 0.1
		
	}
	camera_update(camera)
	set_active_camera(camera^)
}
camera_rotation_from_target :: proc(camera: Camera) -> Quaternion {
	z := -normalize(camera.position - camera.target)
	return la.quaternion_from_forward_and_up_f32(z, VECTOR3_UP)
}
camera_update :: proc(camera: ^Camera) {
	camera.rotation = normalize(camera.rotation)
	camera.transform = la.matrix4_from_trs(camera.position, camera.rotation, Vector3{1,1,1})
	camera.view = la.matrix4_inverse(camera.transform)
}

get_engine_camera :: proc() -> ^Camera {
	return &engine_camera
}

get_active_camera :: proc() -> Camera {
	return active_camera
}
set_active_camera :: proc(camera: Camera) {
	active_camera = camera
}
make_camera :: proc() -> Camera {
	camera: Camera
	camera.rotation = 1
	camera.scale = {1, 1, 1}
	camera.transform = identity(Matrix4)
	camera.view = identity(Matrix4)
	window := get_window()
	aspect := f32(window.size.x)/f32(window.size.y)
	camera.projection = glm.mat4Perspective(45, aspect, 0.001, 10000)
	camera.near = 0.001
	camera.far = 10000
	return camera
}