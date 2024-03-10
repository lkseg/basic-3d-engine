// +build ignore
package engine
import "core:testing"
import "core:encoding/json"
import "core:runtime"
import "core:intrinsics"

ev :: testing.expect_value
ptrT :: ^testing.T
expect_value :: testing.expect_value
expectv :: expect_value

@test
test_ring_buffer :: proc(t: ptrT) {
	using testing
	// expect, expect_value
	r := make_ring_buffer(int, 3)
	ring_buffer_add(&r, 1)
	ring_buffer_add(&r, 2)
	ring_buffer_add(&r, 3)
	// println(r.buf)
	// println(ring_buffer_get(r, 0))
	// println(ring_buffer_get(r, 1))
	
	ring_buffer_add(&r, 4)
	println(r.buf)
	
	// println(ring_buffer_get(r, 0))
	// println(ring_buffer_get(r, 1)) 
	// println(ring_buffer_get(r, -1))
	delete_ring_buffer(&r) 
}

@test
test_bits :: proc(t: ptrT) {
	
	expect_value(t, bits_mirror4(0b0110), 0b0110)
	expect_value(t, bits_mirror4(0b1000), 0b0001)
	expect_value(t, bits_mirror4(0b1100), 0b0011)
	expect_value(t, bits_mirror4(0b1001), 0b1001)
	expect_value(t, bits_mirror4(0b00001100), 0b0011)


	{
		id := u8(0b01001110)
		base: u8
		for i := u32(1); i <= 64 ;  i = i << 2 {
			i := u8(i)
			base |=  ((id & i)<<1) | ((id & (i<<1))>>1)
		}
		println_b(base)
		expectv(t, base, 0b10001101)
	}
}

@test
test_raw_union :: proc(t: ptrT) {
	A :: struct {
		number: int,
	}
	B :: struct {
		number: int,
	}
	A_Union :: struct #raw_union {
		using _: struct {
			number: int,
		},
		using _: struct {
			a_number: f32,
		},
	}
	val: A_Union
	val.number = max(int)
	
	println(val.a_number)
	val.a_number = 5
	
}


@test
test_map_stuff :: proc(t: ptrT) {
	a: map[int] f32
	a[1] = 4
	// a reference!
	for _, b in &a {
		b = 10
	}
	println(a)


	c := &a
	// this can be dangerous since it isn't really obvious
	for _, b in c {
		b = 15
	}
	println(a)
}

@test
test_any_union_for :: proc(t: ptrT) {
	Entity ::  struct {
		derived: Entity_Type,
	}
	Frog :: struct {
		value: int,
		using entity: ^Entity,
	}
	Dog :: struct {
		some_value: f32,
		using entity: ^Entity,
	}
	Entity_Type :: union #no_nil {
		Frog,
		Dog,
	}
	dog := Dog{}
	dog.entity = &Entity{}
	dog.entity.derived = dog
	println(dog.entity)
	switch e in dog.entity.derived {
		case Dog:
		println("Dog")
		// e.some_value = 3 <-- doesn't compile
		case Frog:
		println("Frog")
		case:
	}
	// dog_ref := &dog.entity.derived // <-- e in dog_ref works too
	switch e in &dog.entity.derived {
		case Dog:
		e.some_value = 3 // <-- doesn't compile
		case Frog:
		case:
	}
	println(dog.entity)
	
	{
		// now for any
		Entity ::  struct {
			derived: any,
		}
		Frog :: struct {
			value: int,
			using entity: Entity,
		}
		Dog :: struct {
			some_value: f32,
			using entity: Entity,
		}
		Entity_Type :: union {
			Frog,
			Dog,
		}
		dog := Dog{}
		dog.entity = Entity{}
		// careful for *any* conventions
		// .data = &dog
		// if dog: ^Dog
		// then .derived = dog^ or else it points at the pointer itself
		dog.entity.derived = dog
		println(dog.entity.derived)
		switch e in dog.entity.derived {
			case Dog:
			println("Dog")
			case Frog:
			println("Frog")
			case:
		}

		switch e in &dog.entity.derived {
			case Dog:
			e.some_value = 3
			case Frog:
			case:
		}
		println(dog.entity.derived)
	}
}


@test
dynamic_ref_aware :: proc(t: ptrT) {
	m := map[int]int{0=1, 1=2}
	ptr := &m[1]
	println(m[1])
	println(ptr^)
	for i in 2..<1000 {
		m[i] = i
	}
	println(m[1])
	// println(ptr^) // <-- probably crash since the underlying dynamic array got reallocated
}





// @test
// test_json :: proc(t: ptrT) {

// 	obj := __Test_Object {
// 		3,
// 		3.1,
// 		{0, 1, 4},
// 		{},
// 		nil,
// 		{3.4},
// 		{},
// 	//	{9, 8, 6},
// }

// println(obj)
// data, ok := json.marshal(obj)
// println(ok)
// _values, parse_ok := json.parse(data)
// println(string(data))
// values := _values.(json.Object)
// println(values)
// deserialized_object := Test_Object{}
// it := make_type_info_struct_iterator(&deserialized_object)
// println("---------------------------------------------------------------")
// for field, i in iterate_type_info_struct(&it) {
// 	field := field
// 	key := it.info.names[i]
// 	value, ok := values[key]
// 	if !ok do continue
// 	printf("%v: ", key)
// 	println(type_of_union(value))
// 	#partial switch v in value {

// 		case json.Float:
// 		switch f in &field {
// 			case i32:
// 			f = i32(v)
// 			case i64:
// 			f = i64(v)
// 				// runtime.type_info_base(type_info_of(field.id)) == runtime.Type_Info_Bit_Set:

// 			}
// 		}
// 	}
// 	println(deserialized_object)
// }



// test_serializer_old :: proc(t: ptrT) {

// 	obj := __Test_Object {
// 		3,
// 		3.1,
// 		{0, 1, 4},
// 		__Some_Struct{8.1},
// 		nil,
// 		{3.4},
// 		{1.4, {2.3}},
// 		__Some_Struct{5.8},
// 		i8(4),
// 		1i+1,
// 	}
// 	ext := __Test_Object_Bigger {
// 		3,
// 		0,//new
// 		0,//new
// 		{0, 1, 4},
// 		__Some_Struct{8.1},
// 		nil,
// 		{3.4},
// 		{1.4, {2.3}},
// 		__Some_Struct{5.8},
// 		i8(4),
// 	}
// 	ext_small := __Test_Object_Smaller {
// 		3,
// 		3.1,
// 		__Some_Struct{8.1},

// 		{3.4},
// 		{1.4, {2.3}},
// 		__Some_Struct{5.8},
// 		i8(4),
// 	}	
// 	s := serialize_struct(obj)
// 	println(s.data)

// 	for h, i in s.infos {
// 		println(i,":",h)
// 	}
// 	data := s.data
// 	stream := Byte_Stream{data, 0}
// 	// println(stream)
// 	println(obj)
// 	d: __Test_Object
// 	big: __Test_Object_Bigger
// 	small: __Test_Object_Smaller
// 	ptr := &d
// 	deserialize_struct(data, ptr, typeid_of(type_of(ptr^)), s.infos)
// 	deserialize_struct(data, &big, typeid_of(type_of(big)), s.infos)
// 	deserialize_struct(data, &small, typeid_of(type_of(small)), s.infos)
// 	println(ptr)
// 	expect_value(t, d, obj)
// 	expect_value(t, ext, big)
// 	expect_value(t, ext_small, small)

// 	arr: [10]int
// 	sarr: [10]__Some_Struct
// 	earr: [__Some_Enum]int
// 	println(type_info_of(type_of(arr)).variant)
// 	println(type_info_of(type_of(sarr)).variant)
// 	println(type_info_of(type_of(earr)).variant)
// }
__Some_Struct :: struct {
	some_struct_value: f32,
}
__Two_Val :: struct {
	float: f64,
	it:    i16,
}

__Some_Other_Struct :: struct {
	a_value: f32,
	a_struct: __Some_Struct,
}

__A_Union :: union {
	__Some_Struct,
	__Some_Other_Struct,
	i32,
}
__B_Union :: union {
	i32,
	__A_Union,
}
__One_Union :: struct {
	some_union: __A_Union,
	again: __A_Union,
	nil_union: __A_Union,
	again_again: __A_Union,
	union_in_union: __B_Union,
}
__Test_Object :: struct {
	id: i32,
	float_val: f32,
	flags: bit_set[0..<9; u128], 
	num_component: Maybe(__Some_Struct),
	nil_component: Maybe(__Some_Struct),

	some_struct: __Some_Struct,
	other_struct: __Some_Other_Struct,
	bigger_union: union{__Some_Struct, __Some_Other_Struct, __A_Union},
	union_with_primitive: union{i32, f32, i8},
	rotation: Quaternion,
	//array: [3]f32,
}
__Test_Object_Bigger :: struct {
	id: i32,
	_float_val: f32,
	new_val: f32,
	flags: bit_set[0..<9; u128], 
	num_component: Maybe(__Some_Struct),
	nil_component: Maybe(__Some_Struct),

	some_struct: __Some_Struct,
	other_struct: __Some_Other_Struct,
	bigger_union: union{__Some_Struct, __Some_Other_Struct, __A_Union},
	union_with_primitive: union{i32, f32, i8},
	//array: [3]f32,
}
__Test_Object_Smaller :: struct {
	id: i32,
	float_val: f32,
	num_component: Maybe(__Some_Struct),

	some_struct: __Some_Struct,
	other_struct: __Some_Other_Struct,
	bigger_union: union{__Some_Struct, __Some_Other_Struct, __A_Union},
	union_with_primitive: union{i32, f32, i8},
	//array: [3]f32,
}
__Some_Enum :: enum{A=6,B,C,D}
__Array_Struct :: struct {
	arr: [10]int,
	val: f32,
	struct_arr: [3]__Two_Val,
	enum_arr: [__Some_Enum]__Two_Val,
}
__Array_Struct_Diff_Sizes :: struct {
	arr: [8]int,
	val: f32,
	struct_arr: [6]__Two_Val,
	enum_arr: [__Some_Enum]__Two_Val,
}
@test
test_serializer :: proc(t: ptrT) {

	obj := __Test_Object {
		3,
		3.1,
		{0, 1, 4},
		__Some_Struct{8.1},
		nil,
		{3.4},
		{1.4, {2.3}},
		__Some_Struct{5.8},
		i8(4),
		1i+1,
	}
	ext := __Test_Object_Bigger {
		3,
		0,//new
		0,//new
		{0, 1, 4},
		__Some_Struct{8.1},
		nil,
		{3.4},
		{1.4, {2.3}},
		__Some_Struct{5.8},
		i8(4),
	}
	ext_small := __Test_Object_Smaller {
		3,
		3.1,
		__Some_Struct{8.1},

		{3.4},
		{1.4, {2.3}},
		__Some_Struct{5.8},
		i8(4),
	}	
	{
		simple := __Some_Other_Struct{1, {4}}
		s := serialize_struct(simple)
		println(s[:])
		simple_to := __Some_Other_Struct{}
		println(simple)
		deserialize_struct(s, &simple_to)
		expect_value(t, simple, simple_to)
	}
	{
		println("-----------------------------------")
		a := __One_Union{__A_Union(__Some_Struct{2.5}), __Some_Other_Struct{2, {4}}, nil, i32(8),
		__B_Union(__A_Union(i32(99)))}
		b := serialize_struct(a)
		c: __One_Union
		deserialize_struct(b, &c)
		println(a)
		println(c)
		// expect_value(t, a, c)
		println("-----------------------------------")
	}
	{
		println("-----------------------------------")
		obj := __Test_Object {
			3,
			3.1,
			{0, 1, 4},
			__Some_Struct{8.1},
			nil,
			{3.4},
			{1.4, {2.3}},
			__Some_Struct{5.8},
			i8(4),
			1i+1,
		}
		b := serialize_struct(obj)
		obj_to: __Test_Object
		deserialize_struct(b, &obj_to)
		println(obj)
		println(obj_to)
		expect_value(t, obj, obj_to)
		println("-----------------------------------")
	} {
		obj: __Array_Struct
		obj.arr = {1,2,3,4,5,6,7,8,9, 10}
		obj.struct_arr = {{1.1, 8}, {1.2, 8}, {1.3, 7}}
		obj.enum_arr = {.A={2.3, 44}, .B={2.4, 55}, .C={2.5, 66},.D={2.6, 77}}
		obj.val = 3.6
		b := serialize_struct(obj)
		obj_to: __Array_Struct
		deserialize_struct(b, &obj_to)
		println(obj)
		println(obj_to)
		expect_value(t, obj, obj_to)
	} {
		obj: __Array_Struct
		obj.arr = {1,2,3,4,5,6,7,8,9, 10}
		obj.struct_arr = {{1.1, 8}, {1.2, 8}, {1.3, 7}}
		obj.enum_arr = {.A={2.3, 44}, .B={2.4, 55}, .C={2.5, 66},.D={2.6, 77}}
		obj.val = 3.6
		b := serialize_struct(obj)
		obj_to: __Array_Struct_Diff_Sizes
		deserialize_struct(b, &obj_to)
		println(obj)
		println(obj_to)
		// expect_value(t, obj, obj_to)
	}
	// arr: #sparse [__Some_Enum]int <- if max - min != size - 1; e.g. {A=0, B, C=3}
	arr: [__Some_Enum]int
	println(len(arr))
}

@test
array_type_stuff :: proc(t: ptrT) {
	Some_Enum :: enum {A,B,C,D}
	static: [10]int // size_of(int) * 8; no len
	enu: [Some_Enum]int
	dyn: [dynamic]int
	slice:= []int{1,2,3}
	println("static:", type_info_of(type_of(static))^)
	println("enu:", type_info_of(type_of(enu))^)
	println("dyn:", type_info_of(type_of(dyn))^)
	println("slice:", type_info_of(type_of(slice))^)
}
@test
union_data_layout :: proc(t: ptrT) {
	uni :: __A_Union
	a: __A_Union

	f: Maybe(i32)
	println(size_of(a))
	println(size_of(uni))
	println(size_of(f))
	println(type_of_union(f))
	println(type_of_union(f)==nil)
	f = 32
	println(type_of_union(f))
	// println(reflect.struct_field_by_name(uni, ).type)
}

@test
string_stuff :: proc(t: ptrT) {
	bytes := []byte{97,98,99}
	println(string(bytes))
	s := ""
	println("sizeof empty string",size_of(s))
	raw := transmute(runtime.Raw_String)s
	println("len empty string",raw.len)
	println("len empty string",len(s))
}




