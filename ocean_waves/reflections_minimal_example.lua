-- File: reflections_minimal_example.lua

--[[
Copyright (C) 2025 chmod777

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>. 
]]


function widget:GetInfo()
	return {
		name    = 'Reflections Minimal Example',
		desc    = 'How to use the newly proposed gl.DrawWaterReflections.',
		author  = 'chmod777',
		date    = 'August 2025',
		license = 'GNU GPLv2 or later',
		layer   = 0,
		enabled = false,
		depends = {'gl4'},
	}
end

local fbo_tex, depth_tex, fbo
local view_x, view_y = Spring.GetViewGeometry()
local tex_sx, tex_sy = 512, 512 -- Spring.GetViewGeometry() could be any size really

local vbo, index_vbo, vao

local shader
local vert_source = [[
#version 430

//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec2 pos;
layout (location = 1) in vec2 uv;

out DataVS {
	vec2 uv;
} OUT;

void main() {
	OUT.uv = uv;

	// vec4 position = vec4(pos, 0.0, 1.0);
	vec4 position = cameraViewProj * vec4(pos.x, 0.0, pos.y, 1.0);
	gl_Position = position;
}
]]
local frag_source = [[
#version 430

//__ENGINEUNIFORMBUFFERDEFS__

layout (binding = 0) uniform sampler2D reflect_tex;

in DataVS {
	vec2 uv;
} IN;

out vec4 outColor;

void main() {
	vec2 screen_inverse = 1.0 / viewGeometry.xy;
	vec2 screen_pos = gl_FragCoord.xy;
	vec2 reflect_texcoord = screen_pos * screen_inverse;
	reflect_texcoord = vec2(reflect_texcoord.x, 1.0 - reflect_texcoord.y);

	outColor = vec4(texture(reflect_tex, reflect_texcoord).xyz, 1.0);
}
]]

function widget:Initialize()
	init_quad()
	init_shader()

	fbo_tex = gl.CreateTexture(tex_sx, tex_sy, {
		format = GL.RGBA8,
		target = GL.TEXTURE_2D,
		border = false,
		min_filter = GL.LINEAR, -- could also be repeat
		mag_filter = GL.LINEAR,
		wrap_s = GL.REPEAT,
		wrap_t = GL.REPEAT,
		fbo = true,
	})
	depth_tex = gl.CreateTexture(tex_sx, tex_sy, {
		format = GL.DEPTH_COMPONENT24,
		border = false,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
	})
	fbo = gl.CreateFBO({
		color0 = fbo_tex,
		depth = depth_tex,
		drawbuffers = {GL.COLOR_ATTACHMENT0_EXT},
	})

	Spring.SetDrawWater(false)
end

function widget:DrawWorld()
	gl.DepthMask(true)
	gl.DepthTest(GL.LESS)
	gl.Culling(GL.BACK)

	local previous_fbo = gl.RawBindFBO(fbo)
		gl.Viewport(0, 0, tex_sx, tex_sy)
		local sky         = true
		local ground      = true
		local units       = true
		local features    = true
		local projectiles = true
		gl.DrawWaterReflections(
			sky, ground, units, features, projectiles,
			tex_sx, tex_sy
		)
	gl.RawBindFBO(nil, nil, previous_fbo)
	gl.Viewport(0, 0, view_x, view_y)

	gl.DepthMask(false)
	gl.Culling(false)

	gl.Texture(0, fbo_tex)
	gl.Uniform(0, tex_sx, tex_sy)
	gl.UseShader(shader.shaderObj)
	vao:DrawElements(GL.TRIANGLES, 6)
end

function init_quad()
	local min_x,min_y = 0,0
	local max_x,max_y = Game.mapSizeX,Game.mapSizeZ
	local flip_u,flip_v = false,false
	
	local start_u,end_u = 0,1
	local start_v,end_v = 0,1
	if flip_u then
		start_u,end_u = end_u,start_u
	end
	if flip_v then
		start_v,end_v = end_v,start_v
	end
	
	local vertices = {
		min_x,min_y,  start_u,start_v, --bottom left
		min_x,max_y,  start_u,end_v,   --bottom right
		max_x,max_y,  end_u,end_v,     --top right
		max_x,min_y,  end_u,start_v,   --top left
	}
	local vertex_count = 4
	local layout = {
		{id = 0, name = 'pos', type=GL.FLOAT, size = 2},
		{id = 1, name = 'uv',  type=GL.FLOAT, size = 2},
	}
	
	local indices = {
		2, 1, 0,
		3, 2, 0,
	}

	vbo = gl.GetVBO(GL.ARRAY_BUFFER, false)
	vbo:Define(vertex_count, layout)
	vbo:Upload(vertices)

	index_vbo = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
	index_vbo:Define(#indices)
	index_vbo:Upload(indices)

	vao = gl.GetVAO()
	vao:AttachVertexBuffer(vbo)
	vao:AttachIndexBuffer(index_vbo)
end

function init_shader()
	local engineUniformBufferDefs = gl.LuaShader.GetEngineUniformBufferDefs()
	vert_source = vert_source:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	frag_source = frag_source:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	shader = gl.LuaShader.CheckShaderUpdates({
		vsSrc = vert_source,
		fsSrc = frag_source,
		shaderName = "reflections_minimal_example_shader",
		uniformInt = {},
		uniformFloat = {},
		shaderConfig = {},
		forceupdate = true
	})

	if not shader then
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	if shader then shader:Delete() end

	if vao then vao:Delete() end
	if vbo then vbo:Delete() end
	if index_vbo then index_vbo:Delete() end

	if fbo then gl.DeleteFBO(fbo) end
	if fbo_tex then gl.DeleteTexture(fbo_tex) end
	if depth_tex then gl.DeleteTexture(depth_tex) end

	Spring.SetDrawWater(true)
end
