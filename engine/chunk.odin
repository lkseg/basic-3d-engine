package engine

CHUNK_SIZE :: 30
CHUNK_SIZE_2 :: CHUNK_SIZE * CHUNK_SIZE
CHUNK_SIZE_3 :: CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE
Voxel_Type :: enum u8 {
	None,
	Ground,
	Water,
}
Voxel_Flag :: enum u8 {
	Active,
}
Voxel :: struct #packed {
	__type: Voxel_Type,
	flags: bit_set[Voxel_Flag],
	cell: Vector3i, // this can be [3]uX by using it as an offset
}

Chunk :: struct {
	position: Vector3,
	voxels: []Voxel,
}
delete_chunk :: proc(chunk: Chunk) {
	delete(chunk.voxels)
}
to_chunk_index :: #force_inline proc "contextless" (cell: Vector3i) -> i32 {
	return CHUNK_SIZE_2 * cell.y + CHUNK_SIZE * cell.z + cell.x
}
to_chunk_index_2d :: #force_inline proc "contextless" (cell: Vector3i) -> i32 {
	return CHUNK_SIZE * cell.z + cell.x
}
Chunk_Iterator :: struct {
	chunk: ^Chunk,
	cell: Vector3i,
}
make_chunk_iterator :: proc(chunk: ^Chunk) -> Chunk_Iterator {
	return Chunk_Iterator{chunk = chunk}
}
// iteration order xzy
chunk_iterate :: proc(it: ^Chunk_Iterator) -> (voxel: ^Voxel, cell: Vector3i, ok: bool) {
	ok = true
	defer it.cell.x += 1
	
	if it.cell.x >= CHUNK_SIZE {
		it.cell.x = 0
		it.cell.z += 1
		if it.cell.z >= CHUNK_SIZE {
			it.cell.z = 0
			it.cell.y += 1
			if it.cell.y >= CHUNK_SIZE {
				ok = false
				return
			}
			ix := to_chunk_index(it.cell)
			voxel =  &it.chunk.voxels[ix]
			cell  =  it.cell
			return
		}
		ix := to_chunk_index(it.cell)
		voxel =  &it.chunk.voxels[ix]
		cell  =  it.cell
		return
	}
	
	ix := to_chunk_index(it.cell)
	voxel =  &it.chunk.voxels[ix]
	cell  =  it.cell
	return
}
