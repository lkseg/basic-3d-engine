package engine
import glfw "vendor:glfw"
import mu "vendor:microui"

// The usage of type_of _can_ make the compiler crash
Engine_Interface :: struct {
	new_entity: proc()->^Entity,
	new_voxel_entity: proc(tint: Color) -> ^Entity,
	get_active_camera: proc() -> Camera,
	set_active_camera: proc(Camera),
	get_window_size: proc()->Vector2i,
}
DEFAULT_ENGINE_INTERFACE :: Engine_Interface {
	new_entity,
	new_voxel_entity,
	get_active_camera,
	set_active_camera,
	get_window_size,
}

Ui_Update_Type :: Symbol("ui_update", proc(Engine_Data, Engine_Interface, ..any) -> Ui_Info)
Make_Game_Type :: Symbol("make_game", proc(Engine_Data, ..any))
Game_Update_Type :: Symbol("game_update", proc(Engine_Data, f32))
Delete_Game_Type :: Symbol("delete_game", proc())

Ui_Update_Symbol :: Ui_Update_Type{}
Make_Game_Symbol :: Make_Game_Type{}
Game_Update_Symbol :: Game_Update_Type{}
Delete_Game_Symbol :: Delete_Game_Type{}

Engine_Data :: struct {
	ui_context: ^mu.Context,
	entity_manager: ^Entity_Manager,
	asset_manager: ^Asset_Manager,
	input_manager: ^Input_Manager,
	window: ^Window,
}
get_engine_data :: proc() -> Engine_Data {
	return Engine_Data{get_ui_context(), get_entity_manager(), get_asset_manager(), get_input_manager(), get_window()}
}
set_engine_data :: proc(e: Engine_Data) {
	entity_manager = e.entity_manager
	asset_manager = e.asset_manager
	input_manager = e.input_manager
	app_window = e.window^
}




Any_Symbol :: union {
	Ui_Update_Type,
	Make_Game_Type,
	Game_Update_Type,
	Delete_Game_Type,
}

Window :: struct {
	size: Vector2i,
	handle: glfw.WindowHandle,
}; app_window: Window

get_window :: proc "contextless" () -> ^Window {
	return &app_window
}
get_window_size :: proc() -> Vector2i {
	return app_window.size
}

Editor_State :: enum {
	None=0,
	Default,
	Playing,
}; editor_state: Editor_State

set_editor_state :: proc(state: Editor_State) {
	editor_state = state
}
get_editor_state :: proc() -> Editor_State {
	return editor_state
}
