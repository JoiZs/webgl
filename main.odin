package main

import "core:fmt"
import glm "core:math/linalg/glsl"
import gl "vendor:wasm/WebGL"

Context :: struct {
	program:    gl.Program,
	buffer:     gl.Buffer,
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

do_draw :: proc(ctx: ^Context) -> bool {
	gl.SetCurrentContextById(GL_CTX_NAME)

	width, height := gl.DrawingBufferWidth(), gl.DrawingBufferHeight()
	gl.Viewport(0, 0, width, height)

	aspect_ratio := f32(max(width, 1)) / f32(max(height, 1))

	gl.ClearColor(0.5, 0.7, 1.0, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	gl.UseProgram(ctx.program)

	{
		loc := gl.GetAttribLocation(ctx.program, "a_position")
		gl.EnableVertexAttribArray(loc)
		gl.VertexAttribPointer(loc, 2, gl.FLOAT, false, size_of([5]f32), 0)
	}

	{
		loc := gl.GetAttribLocation(ctx.program, "a_color")
		gl.EnableVertexAttribArray(loc)
		gl.VertexAttribPointer(loc, 3, gl.FLOAT, false, size_of([5]f32), size_of([2]f32))
	}

	{
		proj := glm.mat4Perspective(glm.radians_f32(60), aspect_ratio, 0.1, 100)
		view := glm.mat4LookAt({1.2, 1.2, 1.2}, {0, 0, 0}, {0, 0, 1})
		model := glm.mat4Rotate({0, 0, 1}, ctx.accum_time)

		mvp := proj * view * model

		loc := gl.GetUniformLocation(ctx.program, "u_mvp")
		gl.UniformMatrix4fv(loc, mvp)
	}

	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.buffer)
	gl.DrawArrays(gl.TRIANGLES, 0, 6)

	return true
}

main :: proc() {
	_ = gl.CreateCurrentContextById(GL_CTX_NAME, {})
	major, minor: i32
	gl.GetWebGLVersion(&major, &minor)
	fmt.printfln("Version: %d, %d", major, minor)

	ctx := &global_ctx

	gl.ClearColor(0.4, 0.0, 0.8, 1.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)

	ok: bool
	ctx.program, ok = gl.CreateProgramFromStrings({shader_vert}, {shader_frag})
	assert(ok)

	vertices := [][5]f32 {
		{-0.5, +0.5, 1.0, 0.0, 0.0},
		{+0.5, +0.5, 0.0, 1.0, 0.0},
		{+0.5, -0.5, 1.0, 1.0, 0.0},
		{+0.5, -0.5, 1.0, 1.0, 0.0},
		{-0.5, -0.5, 0.0, 0.0, 1.0},
		{-0.5, +0.5, 1.0, 0.0, 0.0},
	}

	ctx.buffer = gl.CreateBuffer()
	gl.BindBuffer(gl.ARRAY_BUFFER, ctx.buffer)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(vertices[0]),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)

	fmt.println("Heee")
}


shader_vert := `
precision highp float;

attribute vec2 a_position;
attribute vec3 a_color;

uniform mat4 u_mvp;

varying vec3 v_color;

void main(){
    v_color = a_color;
    gl_Position = u_mvp * vec4(a_position, 0.0, 1.0);
}
`


shader_frag := `
precision highp float;

varying vec3 v_color;

void main(){
    gl_FragColor = vec4(v_color, 1.0);
}

`
