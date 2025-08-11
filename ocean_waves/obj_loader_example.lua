-- File: obj_loader_example.lua

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
		name    = '.obj Loader Example',
		desc    = 'A wild fish has appeared in the top left hand corner of the map.',
		author  = 'chmod777',
		date    = 'August 2025',
		license = 'GNU GPLv2 or later',
		layer   = 0,
		enabled = false,
		depends = {'gl4'},
	}
end

local widget_path = 'LuaUI/Widgets/ocean_waves/'
local ObjectLoader = VFS.Include(widget_path .. 'utilities/gl/obj_loader.lua')
local model_path = widget_path .. 'models/salmon/salmon.obj'
local texture_path = widget_path .. 'models/salmon/salmon.png'

local LuaShader = gl.LuaShader
local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO
local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest

local GL_ARRAY_BUFFER = GL.ARRAY_BUFFER
local GL_ELEMENT_ARRAY_BUFFER = GL.ELEMENT_ARRAY_BUFFER
local GL_TRIANGLES = GL.TRIANGLES
local GL_FRONT = GL.FRONT
local GL_BACK = GL.BACK
local GL_LESS = GL.LESS

local vao, vbo, index_vbo, index_count
local shader

local vert_source = [[
#version 420

layout (location = 0) in vec4 position;
layout (location = 1) in vec2 uv;
// layout (location = 2) in vec3 normal;

//__ENGINEUNIFORMBUFFERDEFS__

out DataVS {
	vec2 uv;
} OUT;

void main() {
	OUT.uv = uv;

	gl_Position = cameraViewProj * position;
}
]]

local frag_source = [[
#version 420

layout (binding = 1) uniform sampler2D img;

in DataVS {
	vec2 uv;
} IN;

out vec4 outColor;

void main() {
	outColor = texture(img, IN.uv);
}
]]

function widget:Initialize()
	local obj_loader = ObjectLoader:New()
	obj_loader:LoadFromFile(model_path)
	local layout = {
		{id=0, name="position", type=GL_FLOAT, size=4},
		{id=1, name="uv",       type=GL_FLOAT, size=2},
		{id=2, name="normal",   type=GL_FLOAT, size=3},
	}
	local settings = {
		flip_u = false,
		flip_v = true,
	}
	local vertices, indices = obj_loader:AsBufferData(layout, settings)

	vbo = glGetVBO(GL_ARRAY_BUFFER, false)
	vbo:Define(#vertices, layout)
	vbo:Upload(vertices)

	index_vbo = glGetVBO(GL_ELEMENT_ARRAY_BUFFER, false)
	index_vbo:Define(#indices)
	index_vbo:Upload(indices)
	index_count = #indices

	vao = glGetVAO()
	vao:AttachVertexBuffer(vbo)
	vao:AttachIndexBuffer(index_vbo)

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vert_source = vert_source:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	shader = LuaShader.CheckShaderUpdates({
		vsSrc = vert_source,
		fsSrc = frag_source,
		shaderName = "objloaderexample",
		uniformInt = {},
		uniformFloat = {},
		shaderConfig = {},
		forceupdate = true
	})

	if not shader then
		Spring.Echo('Ocean Waves Shader: Compilation Failed')
		widgetHandler:RemoveWidget()
	end
end

function widget:DrawWorld()
	glCulling(GL_BACK)
	glDepthMask(true)
	glDepthTest(GL.LESS)
	glTexture(1, texture_path)
	shader:Activate()
	vao:DrawElements(GL_TRIANGLES, index_count)
end

function widget:Shutdown()
	if vbo then vbo:Delete() end
	if index_vbo then index_vbo:Delete() end
	if vao then vao:Delete() end
	if shader then shader:Delete() end
end