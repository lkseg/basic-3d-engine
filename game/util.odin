package game

import "core:math"
import la "core:math/linalg"
import hmath "core:math/linalg/hlsl" 
import "core:fmt"
import "core:log"
import "core:mem"
import str "core:strings"
import pqueue "core:container/priority_queue"
import queue "core:container/queue"
import "core:math/rand"
import "core:os"
import "core:reflect"
import c "core:c/libc"
import "core:unicode/utf8"
import ilist "core:container/intrusive/list"
import sarr "core:container/small_array"
import "core:time"
import "core:sync"
import "core:intrinsics"
import "core:runtime"

// builtin quaternion128
Quaternion :: la.Quaternionf32
QUATERNION_NIL :: 1+0i+0j+0k
// [2]f32
Vector2 :: la.Vector2f32
Vector3 :: la.Vector3f32
Vector4 :: la.Vector4f32

Matrix2 :: la.Matrix2x2f32 // matrix[2,2]f32
Matrix3 :: la.Matrix3x3f32 // matrix[3,3]f32
Matrix4 :: la.Matrix4x4f32 // matrix[4,4]f32

Vector2i :: [2]i32
Vector3i :: [3]i32
Vector4i :: [4]i32

Color :: [4]byte

BLACK  :: Color{0, 0, 0, 0}
WHITE :: Color{255, 255, 255, 255}
BROWN :: Color{133, 29, 5, 255}
BLUE  :: Color{0, 0, 255, 255}


is_nil :: reflect.is_nil
type_of_union :: reflect.union_variant_typeid

c_int :: c.int

sin :: math.sin_f32
cos :: math.cos_f32
tan :: math.tan_f32

asin :: math.asin_f32
acos :: math.acos_f32
atan2 :: la.atan2
VECTOR2_UP    :: Vector2{0,-1}
VECTOR2_DOWN  :: Vector2{0,1}
VECTOR2_RIGHT :: Vector2{1,0}
VECTOR2_LEFT  :: Vector2{-1,0}
VECTOR2_ZERO  :: Vector2{0,0}


VECTOR3_UP       :: Vector3{0,1,0}
VECTOR3_DOWN     :: Vector3{0,-1,0}
VECTOR3_RIGHT    :: Vector3{1,0,0}
VECTOR3_LEFT     :: Vector3{-1,0,0}
VECTOR3_ZERO     :: Vector3{0,0,0}
VECTOR3_FORWARD  :: Vector3{0,0,-1}
VECTOR3_FRONT    :: VECTOR3_FORWARD
VECTOR3_BACK     :: Vector3{0,0,1}

AXIS_X :: Vector3{1,0,0}
AXIS_Y :: Vector3{0,1,0}
AXIS_Z :: Vector3{0,0,1}

VECTOR2I_UP    :: Vector2i{0,-1}
VECTOR2I_DOWN  :: Vector2i{0,1}
VECTOR2I_RIGHT :: Vector2i{1,0}
VECTOR2I_LEFT  :: Vector2i{-1,0}
VECTOR2I_ZERO  :: Vector2i{0,0}
VECTOR2I_ONE   :: Vector2i{1,1}

Rectangle :: struct {
	position: Vector2,
	size: Vector2,
}
Rectanglei :: struct {
	position: Vector2i,
	size: Vector2i,
}
PI :: 3.14159265359 
TAU :: PI * 2

TO_DEG :: 180/PI
TO_RAD :: PI/180

round :: la.round
floor :: la.floor
ceil  :: la.ceil
radians :: math.to_radians
degrees :: math.to_degrees
normalize :: la.normalize
sign :: la.sign

cross     :: la.cross
mul :: la.mul
vlength :: la.length
dot :: la.dot

remf :: hmath.fmod_float

modf :: math.modf // returns quotient and remainder/divisor
sqrt :: math.sqrt

println :: fmt.println
eprintln :: fmt.eprintln
printf  :: fmt.printf
tprintf :: fmt.tprintf
Linked_List :: ilist.List
Linked_List_Node :: ilist.Node
Small_Array :: sarr.Small_Array



// x y z order for now
_from_euler_angles :: #force_inline proc(a, b, c: f32) -> Quaternion {
	X :: la.quaternion_from_euler_angle_x
	Y :: la.quaternion_from_euler_angle_y
	Z :: la.quaternion_from_euler_angle_z
	return X(a) * (Y(b) * Z(c))
}
quaternion_from :: proc{la.quaternion_angle_axis_f32, _from_euler_angles}
quat_from :: quaternion_from
from_euler_x :: la.quaternion_from_euler_angle_x_f32
from_euler_y :: la.quaternion_from_euler_angle_y_f32
from_euler_z :: la.quaternion_from_euler_angle_z_f32

// first is the index of the last added element
Ring_Buffer :: struct($T: typeid) {
	buf: []T,
	first: int,
}
make_ring_buffer :: proc($T: typeid, n: i32) -> Ring_Buffer(T) {
	r: Ring_Buffer(T)
	r.buf = make(type_of(r.buf), n)
	r.first = 0
	return r
}
delete_ring_buffer :: proc(r: ^Ring_Buffer($T)) {
	delete(r.buf)
}
ring_buffer_add :: proc(r: ^Ring_Buffer($T), obj: T) {
	r.first = (r.first+1) % len(r.buf)
	r.buf[r.first] = obj
}
ring_buffer_get :: proc(r: Ring_Buffer($T), index: int) -> T {
	assert(r.first>=0)
	i := (r.first - index) %% len(r.buf)
	return r.buf[i]
}


vector2i_to_vector2 :: #force_inline proc "contextless" (v: Vector2i) -> Vector2 {
    return {f32(v.x), f32(v.y)}
}

vector2_to_vector2i :: #force_inline proc "contextless" (v: Vector2) -> Vector2i {
	return {i32(v.x), i32(v.y)}
}

to_vector2 :: proc{vector2i_to_vector2}
to_vector2i :: proc{vector2_to_vector2i}

vector3i_to_vector3 :: #force_inline proc "contextless" (v: Vector3i) -> Vector3 {
    return {f32(v.x), f32(v.y), f32(v.z)}
}

vector3_to_vector3i :: #force_inline proc "contextless" (v: Vector3) -> Vector3i {
	return {i32(v.x), i32(v.y), i32(v.z)}
}
vector2_to_vector3 :: #force_inline proc "contextless" (v: Vector2, z := f32(0)) -> Vector3 {
	return {v.x, v.y, z}
}
vector2i_to_vector3 :: #force_inline proc "contextless" (v: Vector2i, z := f32(0)) -> Vector3 {
	return {f32(v.x), f32(v.y), z}
}



to_vector3 :: proc{vector3_to_vector3i, vector3i_to_vector3, vector2_to_vector3, vector2i_to_vector3}
to_vector3i :: proc{vector3_to_vector3i}

vector2_to_vector4 :: #force_inline proc "contextless" (v: Vector2, z := f32(0), w := f32(0)) -> Vector4 {
	return {v.x, v.y, z, w}
}
vector3_to_vector4 :: #force_inline proc "contextless" (v: Vector3, w := f32(0)) -> Vector4 {
	return {v.x, v.y, v.z, w}
}
to_vector4 :: proc{vector2_to_vector4, vector3_to_vector4}


// 0 -- 1
// |    |
// 2 -- 3
get_rectangle_positions :: proc(r: Rectanglei) -> [4]Vector2i{
	return [4]Vector2i {
		r.position,
		r.position + {r.size.x,  0},
		r.position + {0,           r.size.y},
		r.position + {r.size.x,  r.size.y},
	}
}
rotate :: #force_inline proc(v: Vector2, t: f32) -> Vector2 {
	return {cos(t)*v.x - sin(t)*v.y, sin(t)*v.x + cos(t)*v.y}
}

orthogonal :: #force_inline proc(v: Vector2) -> Vector2 {
	return {-v.y, v.x}
}
node_to_parent :: #force_inline proc "contextless" (node: Linked_List_Node, it: ilist.Iterator($T)) -> ^T {
	return (^T)(uintptr(node) - it.offset)
}
// actual modulo not remainder
// for integer it is %
mod :: proc "contextless" (a, b: f32) -> f32 { 
	rem := remf(a,b)
	return rem if rem>=0 else b+rem
}
to_cstring :: proc{str.clone_to_cstring}
to_temp_cstring :: proc(s: string) -> cstring {
	return str.clone_to_cstring(s, context.temp_allocator)
}

concat :: str.concatenate
tconcat :: #force_inline proc(a: []string) -> string {
	return str.concatenate(a, context.temp_allocator)
}

is_in_array :: proc(a: []$T, v: T) -> int {
	for e, index in a {
		if e == v do return index
	}
	return -1
}

to_u8color :: proc "contextless" (v: Vector4) -> [4]u8 {
	return {u8(v.x)*255, u8(v.y)*255, u8(v.z)*255, u8(v.w)*255} 
}

is_in_queue :: proc(queue: pqueue.Priority_Queue($T), val: T) -> bool {
    using pqueue
    
    for x in queue.queue {
		if val==x {
			return true
		}
    }
    return false
}


squared_length :: #force_inline proc "contextless" (v: Vector3) -> f32 {
	return v.x*v.x + v.y*v.y
}

xy_to_3d :: #force_inline proc "contextless" (v: Vector2) -> Vector3 {
	// -z is forward in 3d
	return Vector3{v.x, 0, -v.y}
}

vec3 :: #force_inline proc "contextless" (v: Vector4) -> Vector3 {
	return {v.x, v.y, v.z}
}
vec4 :: #force_inline proc "contextless" (v: Vector3) -> Vector4 {
	return {v.x, v.y, v.z, 1}
}

get_basis :: proc "contextless" (m: Matrix4) -> (Vector3, Vector3, Vector3) {
	x := Vector3{m[0, 0], m[1, 0], m[2, 0]}
	y := Vector3{m[0, 1], m[1, 1], m[2, 1]}
	z := Vector3{m[0, 2], m[1, 2], m[2, 2]}
	return x, y, z
}
set_scale_vector :: proc(a: ^$A/matrix[$N,N]$T, s: $B/[$Nm]T ) {
    #assert(N-1==Nm)
    #unroll for i in 0..<N-1 {
		a[i,i]=s[i]
    }
}
set_scale_value :: proc(a: ^$A/matrix[$N,N]$T, s: T) {
    #unroll for i in 0..<N-1 {
		a[i,i]=s
    }
}
set_scale :: proc{set_scale_vector, set_scale_value}

set_translation :: proc(a: ^$A/matrix[$N,N]$T, s: $B/[$Nm]T ) {
    #assert(N-1==Nm)
    #unroll for i in 0..<N-1 {
		a[i,N-1]=s[i]
    }
}

identity :: proc($T: typeid/matrix[$N,N]$E) -> T {
    mat: T
    #unroll for i in 0..<N {
		mat[i,i]=E(1)
    }
    return mat
}
print_matrix :: proc(m: $T/matrix[$N,N]$E) {
	println("=======================")
	for j in 0..<N {
		for i in 0..<N-1 {
			printf("%v, ", m[j, i])
		}
		printf("%v", m[j, N-1])
		println()
    }
	println("=======================")
}
is_in_rect :: proc "contextless" (v, r_pos, r_size: $T/[2]$A) -> bool {
	t := r_pos + r_size
	return r_pos.x <= v.x && v.x <= t.x && r_pos.y <= v.y && v.y <= t.y     
}

color_to_float :: proc "contextless" (c: Color) -> Vector4 {
	return Vector4{f32(c[0])/255, f32(c[1])/255, f32(c[2])/255, f32(c[3])/255}
}

scale_int :: #force_inline proc "contextless" (i: $T, f: f32) -> T where intrinsics.type_is_integer(T) {
	return T(f32(i) * f)
}
mul_round :: #force_inline proc(i: $T, f: f32) -> T where intrinsics.type_is_integer(T) {
	return T(la.round(f32(i) * f))
}



make_same_array :: proc (src: $T/[]$E) -> T {
	return make(T, len(src))
}
clone_array :: proc (src: $T/[]$E) -> T {
	dst := make(T, len(src))
	copy(dst, src)
	return dst
}



rotate_left4 :: proc "contextless" (x: u8,  k: uint) -> u8 {
	n :: 4
	s := uint(k) & (n-1)
	return ((x <<s | x >> (n-s))<<4)>>4
}


println_b :: proc(a: any) {
	printf("%#b\n", a)
}

bits_mirror4 :: proc "contextless" (x: u8) -> u8 {
	
	s_2_1 := ((x & 4) >> 1) | ((x & 2) << 1)
	s_3_0 := ((x & 8) >> 3) | ((x & 1) << 3)
	return s_2_1 | s_3_0
}

cast_any :: #force_inline proc "contextless" (val: any, $T: typeid ) -> T {
	return T((cast(^T)val.data)^)
}

get_type_info_struct :: proc($T: typeid) -> (^runtime.Type_Info_Struct, bool) #optional_ok {
	info := runtime.type_info_base(type_info_of(T))
	return &info.variant.(runtime.Type_Info_Struct)
}

Type_Info_Struct_Iterator :: struct {
	info: ^runtime.Type_Info_Struct,
	data: uintptr, // the underlying object
	index: int,
}
make_type_info_struct_iterator :: proc(object: $A/^$T) -> (Type_Info_Struct_Iterator, bool) #optional_ok {
	info, ok := get_type_info_struct(T)
	if !ok {
		return {}, false
	}
	return Type_Info_Struct_Iterator{info = info, data= uintptr(object), index=0}, true
}
_type_info_struct_iterator :: proc(object: $A/^$T) -> (Type_Info_Struct_Iterator, bool) #optional_ok {
	info, ok := get_type_info_struct(T)
	if !ok {
		return {}, false
	}
	return Type_Info_Struct_Iterator{info = info, data= uintptr(object), index=0}, true
}

iterate_type_info_struct :: proc(it: ^Type_Info_Struct_Iterator) -> (any, int, bool) {
	i := it.index
	it.index += 1
	if i >= len(it.info.offsets) {
		return nil, 0, false
	}
	offset := it.info.offsets[i]
	return any{rawptr(it.data+offset), it.info.types[i].id}, i, true
}
iterate :: proc{iterate_type_info_struct}

// snaps v to axis if abs(angle) < epsilon else snaps to the perpendicular axis; epsilon should be positive
vector_snap :: proc(v, axis: $T/[$N]$A, epsilon: f32) -> T {
	when N == 2 {
		
		angle := atan2(cross(v, axis), dot(v, axis))
		// inside epsilon
		if abs(angle) < epsilon {
			return rotate(v, angle)
		}
		if PI - abs(angle) < epsilon {
			return rotate(v, -(PI-angle))
		}
		if angle >= 0 {
			return rotate(v, angle - PI/2)
		}
		return rotate(v, PI/2 + angle)
	} when N == 3 {
		angle := atan2(vlength(cross(v, axis)), dot(v, axis)) // difference to 2d
		// inside epsilon
		if abs(angle) < epsilon {
			return rotate(v, angle)
		}
		if PI - abs(angle) < epsilon {
			return rotate(v, -(PI-angle))
		}
		if angle >= 0 {
			return rotate(v, angle - PI/2)
		}
		return rotate(v, PI/2 + angle)
	}
	return {}
}
