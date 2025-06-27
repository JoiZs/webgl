package main

import "base:runtime"
import "core:fmt"
import "core:mem"

foreign import "odin_dom"


@(default_calling_convention = "contextless")
foreign odin_dom {
	init_event_raw :: proc(ep: u32) ---
	add_event_listener :: proc(id_ptr: rawptr, // Pointer to element ID string in WASM memory
		id_len: int, // Length of element ID string
		name_ptr: rawptr, // Pointer to event name string in WASM memory
		name_len: int, // Length of event name string
		name_code: u32, // Arbitrary code to identify event type
		data: u32, // Arbitrary data to pass to callback
		callback: rawptr, // Pointer to Odin callback function
		use_capture: bool,) -> bool --- // Whether to use capture phase

}

MouseEventData :: struct #packed {
	name_code:           u32,
	target_type:         u32,
	current_target_type: u32,
	screenX:             i64,
	screenY:             i64,
	clientX:             i64,
	clientY:             i64,
	offsetX:             i64,
	offsetY:             i64,
	pageX:               i64,
	pageY:               i64,
	movementX:           i64,
	movementY:           i64,
	ctrlKey:             bool,
	shiftKey:            bool,
	altKey:              bool,
	metaKey:             bool,
	button:              i16,
	buttons:             u16,
}

@(export)
allocate_event_data :: proc(size: int) -> rawptr {

	rptr, err := mem.alloc(size)
	if err == runtime.Allocator_Error.None {
		return rptr
	}

	return nil
}

mouseEvData: ^MouseEventData

@(export)
event_callback :: proc "c" (event_data_ptr: rawptr, data: u32) {
	event := (^MouseEventData)(event_data_ptr)
	mouseEvData = event
}


write_string_to_memory :: proc(str: string, allocator := context.allocator) -> (rawptr, int) {
	bytes := transmute([]byte)str
	ptr, err := mem.alloc(len(bytes), allocator = allocator)
	if err == .None {
		return nil, 0
	}

	mem.copy(ptr, raw_data(bytes), len(bytes))
	return ptr, len(bytes)
}

trigger_mouse_event :: proc() {
	id := "myCanvas"
	event_name := "mousemove"
	name_code := u32(123) // Arbitrary code
	data := u32(0) // Arbitrary data

	// Write strings to WASM memory
	id_ptr, id_len := write_string_to_memory(id)
	name_ptr, name_len := write_string_to_memory(event_name)

	// Get pointer to callback (must be exported)
	callback := cast(rawptr)event_callback

	// Call JS function
	success := add_event_listener(
		id_ptr,
		id_len,
		name_ptr,
		name_len,
		name_code,
		data,
		callback,
		false,
	)

	mem.free(id_ptr)
	mem.free(name_ptr)
}
