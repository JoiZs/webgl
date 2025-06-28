package main

import "core:fmt"
import "core:math"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

Context :: struct {
	program:    gl.Program,
	buffer:     [3]gl.Buffer,
	accum_time: f32,
}

global_ctx: Context
GL_CTX_NAME :: "webgl-canvas"

@(export)
step :: proc(dt: f32) -> bool {
	ctx := &global_ctx
	ctx.accum_time += dt

	_ = do_draw(ctx)

	return true
}

set_rectangle :: proc(x: f32, y: f32, width: f32, height: f32) {
	x1 := x
	x2 := x1 + width
	y1 := y
	y2 := y + height

	rect_vert := [][5]f32 {
		{x1, y1, 1.0, 0.0, 0.0},
		{x2, y1, 0.0, 1.0, 0.0},
		{x1, y2, 0.0, 0.0, 1.0},
		{x1, y2, 0.0, 0.0, 1.0},
		{x2, y1, 0.0, 1.0, 0.0},
		{x2, y2, 1.0, 0.0, 0.0},
	}

	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(rect_vert) * size_of(rect_vert[0]),
		raw_data(rect_vert),
		gl.STATIC_DRAW,
	)
}

set_cube :: proc(ctx: ^Context) {
	cube := [][12]f32 {
		{-1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0, 1.0},

		// Back face
		{-1.0, -1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0, -1.0},

		// Top face
		{-1.0, 1.0, -1.0, -1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, -1.0},

		// Bottom face
		{-1.0, -1.0, -1.0, 1.0, -1.0, -1.0, 1.0, -1.0, 1.0, -1.0, -1.0, 1.0},

		// Right face
		{1.0, -1.0, -1.0, 1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 1.0, -1.0, 1.0},

		// Left face
		{-1.0, -1.0, -1.0, -1.0, -1.0, 1.0, -1.0, 1.0, 1.0, -1.0, 1.0, -1.0},
	}

	faceColors: [][4]f32 = {
		{1.0, 1.0, 1.0, 1.0}, // Front face: white
		{1.0, 0.0, 0.0, 1.0}, // Back face: red
		{0.0, 1.0, 0.0, 1.0}, // Top face: green
		{0.0, 0.0, 1.0, 1.0}, // Bottom face: blue
		{1.0, 1.0, 0.0, 1.0}, // Right face: yellow
		{1.0, 0.0, 1.0, 1.0}, // Left face: purple
	}

	// Convert the array of colors into a table for all the vertices.

	colors: [dynamic][4]f32
	defer delete(colors)

	for c in faceColors {
		// Repeat each color four times for the four vertices of the face
		append(&colors, c, c, c, c)
	}

	indices: []i32 = {
		0,
		1,
		2,
		0,
		2,
		3, // front
		4,
		5,
		6,
		4,
		6,
		7, // back
		8,
		9,
		10,
		8,
		10,
		11, // top
		12,
		13,
		14,
		12,
		14,
		15, // bottom
		16,
		17,
		18,
		16,
		18,
		19, // right
		20,
		21,
		22,
		20,
		22,
		23, // left
	}

	positionBuffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, positionBuffer)
	gl.BufferData(gl.ARRAY_BUFFER, len(cube) * size_of(cube[0]), raw_data(cube), gl.STATIC_DRAW)
	ctx.buffer[0] = positionBuffer

	colorBuffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, colorBuffer)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(colors) * size_of(colors[0]),
		raw_data(colors),
		gl.STATIC_DRAW,
	)
	ctx.buffer[1] = colorBuffer

	indexBuffer := gl.CreateBuffer()
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, indexBuffer)
	gl.BufferData(
		gl.ELEMENT_ARRAY_BUFFER,
		len(indices) * size_of(indices[0]),
		raw_data(indices),
		gl.STATIC_DRAW,
	)
	ctx.buffer[2] = indexBuffer

}

do_draw :: proc(ctx: ^Context) -> bool {
	gl.SetCurrentContextById(GL_CTX_NAME)

	width, height := gl.DrawingBufferWidth(), gl.DrawingBufferHeight()
	gl.Viewport(0, 0, width, height)

	aspect_ratio := f32(max(width, 1)) / f32(max(height, 1))

	gl.ClearColor(0.8, 0.2, 1.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.UseProgram(ctx.program)

	{
		loc := gl.GetAttribLocation(ctx.program, "a_position")
		gl.BindBuffer(gl.ARRAY_BUFFER, ctx.buffer[0])
		gl.EnableVertexAttribArray(loc)
		gl.VertexAttribPointer(loc, 3, gl.FLOAT, false, 0, 0)
	}

	{
		loc := gl.GetAttribLocation(ctx.program, "a_color")
		gl.BindBuffer(gl.ARRAY_BUFFER, ctx.buffer[1])
		gl.EnableVertexAttribArray(loc)
		gl.VertexAttribPointer(loc, 4, gl.FLOAT, false, 0, 0)
	}

	// {
	// 	// proj := glm.mat4Perspective(glm.radians_f32(60), aspect_ratio, 0.1, 100)
	// 	proj := glm.mat4Ortho3d(-2, 2, -2, 2, -2, 10)
	// 	view := glm.mat4LookAt({0, 0, -8.0}, {0, 0, 0}, {-2, -2, 1})
	// 	model := glm.mat4Rotate({0, math.sin_f32(1), math.cos_f32(0.5)}, ctx.accum_time)

	// 	mvp := proj * view * model

	// 	loc := gl.GetUniformLocation(ctx.program, "u_matrix")
	// 	gl.UniformMatrix4fv(loc, mvp)
	// }

	{
		num_of_matrices := 5
		matrices: []glm.mat4x4 = {
			glm.identity(glm.mat4x4),
			glm.identity(glm.mat4x4),
			glm.identity(glm.mat4x4),
			glm.identity(glm.mat4x4),
			glm.identity(glm.mat4x4),
		}

		for mat, idx in matrices {
			// proj_mat := glm.mat4Ortho3d(-5, 5, -5, 5, -5, 5)
			proj_mat := glm.mat4Perspective(glm.radians_f32(30), aspect_ratio, -8, 4)
			view := glm.mat4LookAt({-8.0, -4.0, 0}, {0, 0, 0}, {0, 0, 1})
			translate_mat := glm.mat4Translate({f32(-1) + f32(idx), 0, 0})
			rotate_mat := glm.mat4Rotate({1, 0, 1}, ctx.accum_time)
			scale_mat := glm.mat4Scale({-0.2, -0.2, -0.2})

			m_mat := proj_mat * view * translate_mat * rotate_mat * scale_mat * mat

			loc := gl.GetUniformLocation(ctx.program, "u_matrix")
			gl.UniformMatrix4fv(loc, m_mat)

			gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.buffer[2])
			gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, nil)
		}

	}

	indices: []u32 = {
		0,
		1,
		2,
		0,
		2,
		3, // front
		4,
		5,
		6,
		4,
		6,
		7, // back
		8,
		9,
		10,
		8,
		10,
		11, // top
		12,
		13,
		14,
		12,
		14,
		15, // bottom
		16,
		17,
		18,
		16,
		18,
		19, // right
		20,
		21,
		22,
		20,
		22,
		23, // left
	}

	// gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ctx.buffer[2])
	// gl.DrawElements(gl.TRIANGLES, 36, gl.UNSIGNED_INT, nil)

	return true
}

main :: proc() {
	_ = gl.CreateCurrentContextById(GL_CTX_NAME, {})
	major, minor: i32
	gl.GetWebGLVersion(&major, &minor)
	fmt.printfln("Version: %d, %d", major, minor)

	ctx := &global_ctx

	ok: bool
	ctx.program, ok = gl.CreateProgramFromStrings({shader_vert}, {shader_frag})
	assert(ok)

	ag_inst_ext := gl.IsExtensionSupported("ANGLE_instanced_arrays")
	assert(ag_inst_ext)

	// set_rectangle(0.0, 0.0, 0.5, 0.5)
	set_cube(ctx)

	event_ptr: u32 = 0
	init_event_raw(event_ptr)

	// trigger_mouse_event()

	fmt.println("Heee")
	// fmt.printfln("Heee %d", mouseEvData.clientX)
}

shader_vert := `
precision mediump float;

attribute vec3 a_position;
attribute vec4 a_color;

uniform mat4 u_matrix;

varying vec4 v_color;

void main(){
    v_color = a_color;
    gl_Position = u_matrix * vec4(a_position, 1);
}
`


shader_frag := `
precision mediump float;

varying vec4 v_color;

void main(){
    gl_FragColor = v_color;
}

`
