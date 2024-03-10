package engine
import "core:os"
import "core:fmt"
import tt "vendor:stb/truetype"
import img "vendor:stb/image"
import "core:c"

c_uint :: c.uint

GLYPHS_COUNT :: 95

Font :: struct {
	// ScaleForPixelHeight
	scale: f32,
	// FontVMetrics *scaled*
	ascent: f32,
	descent: f32,
	line_gap: f32,
	
	// glyphs data see pack_range
	glyphs: [GLYPHS_COUNT]tt.packedchar,
	size: f32,
}
Fonts :: struct {
	fonts: []Font,
	bitmap: []byte, // can be empty
	size: Vector2i,
}
delete_fonts :: proc(f: Fonts) {
	delete(f.fonts)
	delete(f.bitmap)
}
make_fonts :: proc(data: []byte, start_size := f32(68), step := f32(2), count := i32(2), sample_count := [2]c_uint{1,1}) -> Fonts {
	using tt
	fonts := make([]Font, count)
	ranges := make([]pack_range, count)
	defer delete(ranges)
	
	size := start_size
	for i in 0..<count {
		ranges[i] = {size, 32, nil, GLYPHS_COUNT, raw_data(fonts[i].glyphs[:]), 0, 0}
		size -= step
	}
	// the filling order is row > column
	// the bitmap height might be less than the height
	width, height := i32(1024), i32(2048)
	bitmap := make([]byte, width*height)
	defer delete(bitmap)
	
	pack: pack_context;
	
	ROW_PADDING :: 0
	RUNE_PADDING :: 1
    PackBegin(&pack, raw_data(bitmap), width, height, ROW_PADDING, RUNE_PADDING, nil);   
    PackSetOversampling(&pack, sample_count.x, sample_count.y); 
    PackFontRanges(&pack, raw_data(data), 0, raw_data(ranges), count);
    PackEnd(&pack);

	info: fontinfo;
    InitFont(&info, raw_data(data), GetFontOffsetForIndex(raw_data(data),0));
	
    for i in 0..<count {
    	size := ranges[i].font_size;
        scale := ScaleForPixelHeight(&info, ranges[i].font_size);
		
        a, d, l: i32
        GetFontVMetrics(&info, &a, &d, &l);
        fonts[i].scale = scale
		fonts[i].size = size
        fonts[i].ascent, fonts[i].descent  = f32(a)*scale, f32(d)*scale;
        fonts[i].line_gap = f32(l)*scale;
    }

    min_height := i32(0);
    for j in 0..<count {
        for i in 0..<GLYPHS_COUNT {
			g := fonts[j].glyphs[i]
            if (g.y1 > u16(min_height)) {
				min_height = auto_cast g.y1;
			}
	    }
    }
	min_bitmap := make([]byte, width*min_height)
	copy(min_bitmap[:], bitmap[:])
	
	return {fonts = fonts, bitmap = min_bitmap, size ={width, min_height}}
}
