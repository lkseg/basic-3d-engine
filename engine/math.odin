package engine
import la "core:math/linalg"

make_model_matrix :: proc(position: Vector3, rotation := Quaternion(1), scale := Vector3{1,1,1}) -> Matrix4 {
	return la.matrix4_from_trs(position, rotation, scale)
}
to_cell_2d :: #force_inline proc "contextless" (index: i32, stride: i32) -> Vector2i {
	return {index % stride, index/stride}
}
index_2d :: #force_inline proc "contextless" (cell: Vector2i, stride: i32) -> i32 {
	return cell.y*stride + cell.x  
}

screen_to_clip :: proc "contextless" (v: Vector2) -> Vector2 {
	s := v/to_vector2(get_window().size)
	s = 2*s - 1
	s.y *= -1
	return s
}

screen_to_world :: proc "contextless" (v: Vector2) -> Vector3 {
	p := inverse(active_camera.projection) * to_vector4(screen_to_clip(v), 0, 1)
	p.z = 0;
	p.w = 1;
	return (active_camera.transform * p).xyz
}

get_ray_direction_from_screen :: proc(v: Vector2) -> Vector3 {
	clip := screen_to_clip(v)
	view := inverse(active_camera.projection) * to_vector4(clip, -1, 1)
	// direction towards -1 so w = 0
	world: Vector4 = (active_camera.transform * to_vector4(view.xy, -1, 0))
	
	return auto_cast la.normalize(world.xyz)
}


// very basic bad performance
primitive_get_collision :: proc(primitive: Primitive, ray: Ray) -> Collision_Info {
	using primitive.mesh
	min_distance := max(f32)
	info: Collision_Info
	
	for i := 0; i < len(indices); i+=3 {
		i, j, k := indices[i], indices[i+1], indices[i+2]
		
		col := ray_triangle_collision(ray, vertices[i].position, vertices[j].position, vertices[k].position)
		if col.is_hit && vlength(col.position-ray.position) < min_distance {
			min_distance = vlength(col.position-ray.position)
			info = col
		}
	}
	if min_distance == max(f32) do return {}
	return info
}

Ray :: struct {
	position: Vector3,
	direction: Vector3,
}
get_ray_from_mouse :: proc() -> Ray {
	x, y, z := get_basis(active_camera.transform)
	camera := get_active_camera()
	ray: Ray
	ray.position = camera.position
	ray.direction = get_ray_direction_from_screen(get_mouse_position())
	// ray.direction = (screen_to_world(get_mouse_position()) - z*camera.near) - camera.position
	// println(ray.direction)
	//ray.direction = active_camera.target - active_camera.position
	return ray
}
Collision_Info :: struct {
	is_hit: bool,
	position: Vector3,
	distance: f32,
}
ray_sphere_collision :: proc(ray: Ray, center: Vector3, radius: f32) -> Collision_Info {
	// do we want to check whether or not the ray position is inside the sphere?
	// if so just check it before doing the other calculations
	
	// center around sphere
	p := ray.position - center
	d := ray.direction
	
	m2 := d.x*d.x + d.y*d.y + d.z*d.z
	m1 := d.x*p.x + d.y*p.y + d.z*p.z
	m0 := p.x*p.x + p.y*p.y + p.z*p.z
	
	md := m1/m2
	r := md*md - (m0 - radius*radius)/m2
	
	// there is no solution
	if r < 0 {
		return {is_hit = false}
		
	}
	// there is one solution
	if abs(r) <= 0.0001 {
		n := -md
		pos := ray.position + n*ray.direction
		return {is_hit = true, position = pos, distance = vlength(ray.position - pos)}
		
	}
	n0 := -md + sqrt(r)
	n1 := -md - sqrt(r)
	// if n0 is negative so must be n1
	// in this case no hit since the ray is one directional
	if n0 < 0 {
		return {is_hit = false}
	}
	

	n := n0 if n1 < 0 else min(n0, n1)
	
	pos := ray.position + n*ray.direction
	return {is_hit = true, position = pos, distance = vlength(ray.position - pos)}
}

ray_triangle_collision :: proc(ray: Ray, a, b, c: Vector3) -> Collision_Info {
	
	ab := b - a
	ac := c - a
	n := normalize(cross(ab, ac))
	l := to_vector4(n, -dot(n, a))
	lv := dot(l, to_vector4(ray.direction, 0))
	if abs(lv) <= 0.0001 do return {is_hit = false}
	
	t := -dot(l, to_vector4(ray.position, 1))/lv
	p := ray.position + t*ray.direction
	r := p - a
	mat := Matrix2 {
		dot(ab, ab), dot(ab, ac),
		dot(ab, ac), dot(ac, ac),
	}
	w := inverse(mat)*(Vector2{dot(ab, r), dot(ac, r)})
	if w.x < 0 || w.y < 0 || w.x+w.y > 1 do return {}
	
	return {is_hit = true, position = p, distance = vlength(ray.position - p)} 
}

ray_mesh_collision :: proc(ray: Ray, mesh: Basic_Mesh) -> Collision_Info {
	using mesh
	min_distance := max(f32)
	info: Collision_Info
	for i := 0; i < len(indices); i+=3 {
		i, j, k := indices[i], indices[i+1], indices[i+2]
		
		col := ray_triangle_collision(ray, vertices[i].position, vertices[j].position, vertices[k].position)
		
		if col.is_hit && vlength(col.position-ray.position) < min_distance {
			min_distance = vlength(col.position-ray.position)
			info = col
		}
	}
	if min_distance == max(f32) do return {}
	
	return info
}
ray_mesh_collision_scale :: proc(ray: Ray, mesh: Basic_Mesh, scale: Vector3) -> Collision_Info {
	using mesh
	min_distance := max(f32)
	info: Collision_Info
	for i := 0; i < len(indices); i+=3 {
		i, j, k := indices[i], indices[i+1], indices[i+2]
		
		col := ray_triangle_collision(ray, vertices[i].position*scale, vertices[j].position*scale, vertices[k].position*scale)
		
		if col.is_hit && vlength(col.position-ray.position) < min_distance {
			min_distance = vlength(col.position-ray.position)
			info = col
		}
	}
	if min_distance == max(f32) do return {}
	
	return info
}
