package engine
import la "core:math/linalg"
import "core:math"
import "core:thread"
import "core:runtime"
import "core:mem"
import glm "core:math/linalg/glsl"
import slice "core:slice"

vIndex :: u32

Vertex :: struct #packed {
    position: Vector3,
    uv:  Vector2,
	normal: Vector3,
	color: Color,
}

Voxel_Vertex :: Vertex
Voxel_Index  :: vIndex

Mesh :: struct($V: typeid, $I: typeid) {
	vertices: []V,
	indices:  []I,
}
Basic_Mesh :: Mesh(Vertex, vIndex)

clone_mesh :: proc(m: $T/Mesh($V, $I)) -> T {
	return {vertices = slice.clone(m.vertices), indices = slice.clone(m.indices)}
}


make_vertex :: #force_inline proc "contextless" (position: Vector3, uv := Vector2{}) -> Vertex {
	return Vertex{position = position, uv = uv, color = {1, 1, 1, 1}}
}


Face :: struct {
	id: u32,
    neighbours: [dynamic]u32,
	indices: [3]vIndex,
}

// there should be no intersection in indices regarding faces
Faces :: struct {
	faces: [dynamic]Face,
	vertices: []Vertex,
	allocator: mem.Allocator,
}
make_faces :: proc() -> Faces {
	// use the default allocator since it is thread safe
	allocator := runtime.default_allocator()
	return Faces{allocator = allocator}
}
generate_faces :: proc(vert: []Vertex, ind: []vIndex) -> Faces {
	_faces := make_faces()
	using _faces
	context.allocator = _faces.allocator

	_faces.vertices = vert
	faces =  make([dynamic]Face, len(ind)/3, )
	for idx := 0; idx < len(ind) - 2; idx += 3 {
		i, j, k := ind[idx], ind[idx+1], ind[idx+2]
		face: Face
		face.id = u32(idx)
		face.indices = {i, j, k}
		face.neighbours = make(type_of(face.neighbours), 0, 100)
		faces[idx/3] = face
		
	}
	
	// for _, i in faces {
	// 	inner: for j := i+1; j < len(faces); j+=1 {
	// 		for k in faces[i].indices do for l in faces[j].indices {
	// 			if k == l {
	// 				append(&faces[i].neighbours, faces[j].id)
	// 				append(&faces[j].neighbours, faces[i].id)
	// 				continue inner
	// 			}
	// 		}
	// 	}
	// }
	// return _faces
	__proc :: proc(faces: ^[]Face, start, end: int) {
		part := faces[start : end]
		
		for a in &part do for b in faces {
			inner: for i in a.indices do for j in b.indices {
				if i == j {
					append(&a.neighbours, b.id)
					continue inner
				}
			}
		}
	}
	N :: 8
	threads := make([dynamic]^thread.Thread, 0, N)
	defer delete(threads)
	worker_proc :: proc(t: ^thread.Thread) {}

	stride := len(faces)/N 
	for i in 0..< N {
		s := faces[:]
		end := stride * (i+1)
		if i == N-1 do end = len(faces)
		// tracking allocator is not thread safe
		if t := thread.create_and_start_with_poly_data3(&s, stride*i, end, __proc, context); t != nil {
			append(&threads, t)
		}
	}
	
	for len(threads) > 0 {
		for i := 0; i < len(threads); {
			if t := threads[i]; thread.is_done(t) {
				thread.destroy(t)
				ordered_remove(&threads, i)
			} else {
				i += 1
			}
		}
	}
	return _faces
}
make_default_icosphere :: proc(vertices: ^[dynamic]Vertex, indices: ^[dynamic]vIndex) {
	t := f32( (1 + la.sqrt(5.0)) / 2) // golden ratio
	_v := normalize( Vector2{1,t} )
	a := _v.x
	b := _v.y
	
	v := vertices; ic := indices
	
	add_point(v, {-a,  b,  0})
	add_point(v, { a,  b,  0})
	add_point(v, {-a, -b,  0})
	add_point(v, { a, -b,  0})
	
	add_point(v, { 0, -a,  b})
	add_point(v, { 0,  a,  b})
	add_point(v, { 0, -a, -b})
	add_point(v, { 0,  a, -b})
	
	add_point(v, { b,  0, -a})
	add_point(v, { b,  0,  a})
	add_point(v, {-b,  0, -a})
	add_point(v, {-b,  0,  a})

	
	
	add_triangle_indices(ic, 0, 11, 5)
	add_triangle_indices(ic, 0, 5, 1)
	add_triangle_indices(ic, 0, 1, 7)
	add_triangle_indices(ic, 0, 7, 10)
	add_triangle_indices(ic, 0, 10, 11)
	
	add_triangle_indices(ic, 1, 5, 9)
	add_triangle_indices(ic, 5, 11, 4)
	add_triangle_indices(ic, 11, 10, 2)
	add_triangle_indices(ic, 10, 7, 6)
	add_triangle_indices(ic, 7, 1, 8)
	
	add_triangle_indices(ic, 3, 9, 4)
	add_triangle_indices(ic, 3, 4, 2)
	add_triangle_indices(ic, 3, 2, 6)
	add_triangle_indices(ic, 3, 6, 8)
	add_triangle_indices(ic, 3, 8, 9)
	
	add_triangle_indices(ic, 4, 9, 5)
	add_triangle_indices(ic, 2, 4, 11)
	add_triangle_indices(ic, 6, 2, 10)
	add_triangle_indices(ic, 8, 6, 7)
	add_triangle_indices(ic, 9, 8, 1)
}


// The position of the given vertices is not being changed; hence their indices stay valid.
split_triangles :: proc(v: ^[dynamic]Vertex, indices: []vIndex) -> []vIndex {
	cache := make(map[u64]vIndex, 4096)
	
	// This is a 'symmetric' hash function i.e. h(a,b)=h(b,a).
	_hash :: #force_inline proc "contextless" (a, b: vIndex) -> u64 {
		if a < b do return (u64(a) << 32 ) | u64(b)
		return (u64(b) << 32 ) | u64(a)
	}
	new_indices: [dynamic]vIndex
	for idx := 0; idx < len(indices) - 2; idx += 3 {
		i := indices[idx]; j := indices[idx+1]; k := indices[idx+2]
		ij := v[j].position - v[i].position
		ik := v[k].position - v[i].position
		jk := v[k].position - v[j].position
		aij := v[i].position + ij/2
		bik := v[i].position + ik/2
		cjk := v[j].position + jk/2

		
		aij = normalize(aij); bik = normalize(bik); cjk = normalize(cjk)
		a := add_point_cached(v, aij, _hash(i, j), &cache)
		b := add_point_cached(v, bik, _hash(i, k), &cache)
		c := add_point_cached(v, cjk, _hash(j, k), &cache)

		
		add_triangle_indices(&new_indices, i, a, b)
		add_triangle_indices(&new_indices, a, c, b)
		add_triangle_indices(&new_indices, c, k, b)
		add_triangle_indices(&new_indices, a, j, c)
	}
	delete(cache)
	return new_indices[:]
}
add_point_cached :: #force_inline proc(v: ^[dynamic]Vertex, p: Vector3, index: u64, cache: ^map[u64]vIndex) -> vIndex {
	if i, ok := cache[index]; ok {
		return i
	}
	
	append(v, Vertex{position = p, color = {1,1,1,1}, uv = {0,0}})
	cache[index] = vIndex(len(v)-1)
	return vIndex(len(v)-1)
}

apply_computations_sphere :: proc(vert: []Vertex, ind: []vIndex) {
	
	tex := get_texture("swirl")
	noise := tex.data
	assert(noise != nil)
	// we use uvs so -1
	size := to_vector2(tex.size) -1
	
	for _, i in vert {
		x := &vert[i]
		
		uv := sphere_uv(x.position)

		// we don't do wrapping!
		ix := int(math.round(uv.x*size.x))
		iy := int(math.round(uv.y*size.y))
		
		c := iy * int(tex.size.x) + ix
		
		// grayscale hence all values are the same
		// v is our elevation
		v := noise[c].x
		
		v = glm.smoothstep(-0.5, 0.8, v)
		v *= 0.4
		x.position += x.normal * v
		// if v > 0.7 {
		// 	x.position += x.normal * v * 0.5
		// }
		x.uv = uv;
	}
}
RECT_RENDER_OBJECT: Render_Object

default_rect_vertices_centered := []Vertex{
    { position = {-0.5, +0.5, 0}, uv = {0,1}},
    { position = {-0.5, -0.5, 0}, uv = {0,0}},
    { position = {+0.5, -0.5, 0}, uv = {1,0}},
    { position = {+0.5, +0.5, 0}, uv = {1,1}},
}
default_rect_vertices_centered_2 := []Vertex{
    { position = 2*{-0.5, +0.5, 0}, uv = {0,1}},
    { position = 2*{-0.5, -0.5, 0}, uv = {0,0}},
    { position = 2*{+0.5, -0.5, 0}, uv = {1,0}},
    { position = 2*{+0.5, +0.5, 0}, uv = {1,1}},
}
default_rect_indices_centered := []vIndex{
    0, 1, 2,
    0, 2, 3,
}
default_rect_vertices := []Vertex{
    { position = {+0.0, +0.0, 0}, uv = {0,1}},
    { position = {+1.0, +0.0, 0}, uv = {1,1}},
    { position = {+0.0, -1.0, 0}, uv = {0,0}},
    { position = {+1.0, -1.0, 0}, uv = {1,0}},
}
default_rect_indices := []vIndex{
    0, 2, 3,
    0, 3, 1,
}






// not really that useful since uvs and especially normals don't really work
// back to front; top to bot; left to right
min_unit_cube_vertices := []Vertex {
	{ position = {-0.5, +0.5, +0.5}, uv ={1.0/4, 2.0/3}},
	{ position = {+0.5, +0.5, +0.5}, uv ={2.0/4, 2.0/3}},
	{ position = {-0.5, -0.5, +0.5}, uv ={1.0/4, 1.0/3}},
	{ position = {+0.5, -0.5, +0.5}, uv ={2.0/4, 1.0/3}},
	
	{ position = {-0.5, +0.5, -0.5}, uv ={0.0  , 2.0/3}},
	{ position = {+0.5, +0.5, -0.5}, uv ={3.0/4, 2.0/3}},
	{ position = {-0.5, -0.5, -0.5}, uv ={0.0  , 1.0/3}},
	{ position = {+0.5, -0.5, -0.5}, uv ={3.0/4, 1.0/3}},
}

min_cube_indices := []vIndex {
	// back
	0, 2, 3,
	3, 1, 0,
	// right
	1, 3, 7,
	7, 5, 1,
	// front
	5, 7, 6,
	6, 4, 5,
	// left
	4, 6, 2,
	2, 0, 4,
	// top
	4, 0, 1,
	1, 5, 4,
	// bot
	7, 3, 2,
	2, 6, 7,
	
}

CP0 ::	Vector3 {-0.5, +0.5, +0.5}
CP1 ::	Vector3 {+0.5, +0.5, +0.5}
CP2 ::	Vector3 {+0.5, +0.5, -0.5}
CP3 ::	Vector3 {-0.5, +0.5, -0.5}
		
CP4 ::	Vector3 {-0.5, -0.5, +0.5}
CP5 ::	Vector3 {+0.5, -0.5, +0.5}
CP6 ::	Vector3 {+0.5, -0.5, -0.5}
CP7 ::	Vector3 {-0.5, -0.5, -0.5}

CPA := [8]Vector3 {CP0, CP1, CP2, CP3, CP4, CP5, CP6, CP7}

// all points have 3 neighbours
NEIGH := [8][3]u8 {
	{1, 2, 4},
	{0, 3, 5},
	{0, 5, 6},
	{1, 4, 7},

	{0, 3, 6},
	{2, 3, 7},
	{3, 5, 6},
	{2, 4, 7},
}

CV0 ::	Vertex{ position = CP0}
CV1 ::	Vertex{ position = CP1}
CV2 ::	Vertex{ position = CP2}
CV3 ::	Vertex{ position = CP3}
		
CV4 ::	Vertex{ position = CP4}
CV5 ::	Vertex{ position = CP5}
CV6 ::	Vertex{ position = CP6}
CV7 ::	Vertex{ position = CP7}


get_cube_vertices :: proc() -> [24]Vertex {
	U00 :: Vector2{0,0}
	U10 :: Vector2{1,0}
	U01 :: Vector2{0,1}
	U11 :: Vector2{1,1}	
	v := [24]Vertex {
		CV0, CV1, CV2, CV3,
		CV7, CV6, CV5, CV4,
		CV4, CV5, CV1, CV0,
		CV5, CV6, CV2, CV1,
		
		CV6, CV7, CV3, CV2,
		CV7, CV4, CV0, CV3,
	}
	for i := 0; i<24; i+=4 {
		v[i+0].uv, v[i+1].uv, v[i+2].uv, v[i+3].uv = U00, U10, U11, U01
	}
	V :: Vector4
	C :: Color
	for i := 0; i<24; i+=4 {
		c: C = {255,0,0,255} if i < 4 else {0,255,0,255} if i < 8 else {0,0,255,255} if i < 12 else {255,255,0,255}  if i < 16 else {0,255,255,255} if i < 20 else {255,0,255,255}
		v[i+0].color, v[i+1].color, v[i+2].color, v[i+3].color = c, c, c, c
	}
	
	return v
}
get_cube_indices :: proc() -> [36]vIndex {
	a: [36]vIndex
	#unroll for it in 0..<6 {
		i := it*6
		j := u32(it*4)
		a[0+i], a[1+i], a[2+i], a[3+i], a[4+i], a[5+i] = 0+j, 1+j, 3+j, 3+j, 1+j, 2+j
	}
	return a
}
get_cube_mesh :: proc() -> ([24]Vertex, [36]vIndex){
	v, i := get_cube_vertices(), get_cube_indices()
	compute_normals(v[:], i[:])
	return v, i
}
vertices_set_color :: proc(v: []Vertex, color: Color) {
	// color := color_to_float(color)
	for _, i in v {
		v[i].color = color
	}
}

make_cube :: proc() -> Render_Object {
	cv := get_cube_vertices()
	ci := get_cube_indices()
	compute_cube_uvs(cv[:])
	compute_normals(cv[:], ci[:])
	return make_render_object(cv[:], ci[:])
}

make_default_plane :: proc() -> Render_Object {
	V :: make_vertex
	vert := []Vertex {
		V({-0.5, +0.5, 0}, {0, 1}),
		V({+0.5, +0.5, 0}, {1, 1}),
		V({+0.5, -0.5, 0}, {1, 0}),
		V({-0.5, -0.5, 0}, {0, 0}),
	}

	ind := []vIndex {
		1, 0, 2,   2, 0, 3,
	}
	return make_render_object(vert, ind)
}

// makes a plane with m x n points
// faces y
make_plane :: proc(m: i32, n: i32) -> Basic_Mesh {
	m := vIndex(m); n := vIndex(n)
	vertices := make([dynamic]Vertex, n*m)
	indices := make([dynamic]vIndex,  0, n*m)
	step_x := 1.0/f32(n-1)
	step_z := 1.0/f32(m-1)
	V :: make_vertex
	
	start_x := f32(-0.5)
	start_z := f32(-0.5)

	sz := start_z
	UV :: Vector2{0.5, 0.5}
	l := u32(0)
	for i in 0..< n-1 {
		sx := start_x
		fi := f32(i)
		for j in 0..< n {
			fj := f32(j) 
			a := Vector3{sx+fj    *step_x, 0, sz+fi*step_z}
			b := Vector3{sx+fj    *step_x, 0, sz+(fi+1)*step_z}

			
			a_uv := Vector2{a.x + UV.x, -a.z + UV.y}
			b_uv := Vector2{b.x + UV.x, -b.z + UV.y}
			
			vertices[l] = V(a, a_uv)
			vertices[l+n] = V(b, b_uv)
			if j > 0 {
				a := l-1; b := l+0
				c := l+n-1; d := l+n
				append(&indices, a, c, b,    b, c, d)
				v:=vertices
			}
			l += 1
		}
	}
	
	return Basic_Mesh{vertices = vertices[:], indices=indices[:]}
}

// returns the position in the array
add_point :: #force_inline proc(v: ^[dynamic]Vertex, p: Vector3) -> vIndex {
	append(v, Vertex{position = p, color = {1,1,1,1}, uv = {0,0}})
	return vIndex(len(v)-1)
}

add_triangle_indices :: #force_inline proc(v: ^[dynamic]vIndex, x, y, z: vIndex) {
	append(v, x)
	append(v, y)
	append(v, z)
}

// See unit_cube_vertices.
compute_cube_uvs :: proc(v: []Vertex) {
	assert(len(v) % 4 == 0)
	for i := 0; i<len(v); i+=4 {
		a, b, c, d := &v[i], &v[i+1], &v[i+2], &v[i+3]
		a.uv = {0, 1}
		b.uv = {0, 0}
		c.uv = {1, 0}
		d.uv = {1, 1}
	}
}
// Every three indices == one triangle.
compute_normals :: proc(v: []Vertex, indices: []vIndex) {
	assert(len(indices) % 3 == 0)
	for idx := 0; idx <= len(indices) - 3; idx += 3 {
		i:= indices[idx]; j := indices[idx+1]; k := indices[idx+2]
		
		ij := v[j].position - v[i].position
		ik := v[k].position - v[i].position
		n := cross(ij, ik)
		v[i].normal += n
		v[j].normal += n
		v[k].normal += n
	}
	for _, i in v {
		v[i].normal = normalize(v[i].normal)
	}
}
sphere_uv :: proc(v: Vector3) -> Vector2 {
	d := normalize(v)
	uv: Vector2
	uv.x = 0.5 + glm.atan2(d.x, d.z)/(2*PI)
	uv.y = 0.5 + glm.asin(d.y)/PI
	return uv
}

