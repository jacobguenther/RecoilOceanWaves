-- File: clipmap.lua

--[[
Copyright (C) 2025 chmod777

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License version 3 as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>. 
]]

local GL_UNSIGNED_SHORT = GL.UNSIGNED_SHORT
local GL_UNSIGNED_INT = GL.UNSIGNED_INT
local GL_FLOAT = GL.FLOAT

local GL_ELEMENT_ARRAY_BUFFER = GL.ELEMENT_ARRAY_BUFFER
local GL_ARRAY_BUFFER = GL.ARRAY_BUFFER
local GL_UNIFORM_BUFFER = GL.UNIFORM_BUFFER
local GL_SHADER_STORAGE_BUFFER = GL.SHADER_STORAGE_BUFFER

local GL_TRIANGLES = GL.TRIANGLES
local GL_POINTS = GL.POINTS
local GL_LINES = GL.LINES

local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO

local Clipmap = {}
function Clipmap:new(size, grid_size, lods)
	local vbo = generate_plane_vertices(size, grid_size)

	local indices = {}
	generate_clipmap_center_indices(indices, grid_size)
	local lod_info = {
		max_lod = 5,
		center = { base=0, count=#indices },
		plane = {}
	}
	for lod=1, lod_info.max_lod do
		local base = #indices
		local count = gerenate_plane_indices(indices, grid_size, lod)
		lod_info.plane[#(lod_info.plane)+1] = {
			base = base,
			count = count,
		}
	end

	local index_vbo = glGetVBO(GL_ELEMENT_ARRAY_BUFFER, false)
	index_vbo:Define(#indices, GL_UNSIGNED_INT)
	index_vbo:Upload(indices)

	local layers_settings = {
		{ scale=0.5, base_lod=1, instance_base=nil },
		{ scale=1,   base_lod=2, instance_base=nil },
		{ scale=2,   base_lod=2, instance_base=nil },
		{ scale=4,   base_lod=3, instance_base=nil },
		{ scale=8,   base_lod=3, instance_base=nil },
		{ scale=16,  base_lod=5, instance_base=nil }
	}
	local instance_data = {}
	generate_clipmap_center_instance_data(instance_data)
	for i=1, #layers_settings do
		local layer_settings = layers_settings[i]
		layer_settings.instance_base = 1+12*(i-1)
		generate_clipmap_tile_instance_data(instance_data, layer_settings.scale, i)
	end
	local instance_vbo = glGetVBO(GL_ARRAY_BUFFER, false)
	instance_vbo:Define(1+12*#layers_settings, {
		{id=1, name='instance_data', type=GL_FLOAT, size=4} -- uvec4
	})
	instance_vbo:Upload(instance_data)

	local vao = glGetVAO()
	vao:AttachVertexBuffer(vbo)
	vao:AttachIndexBuffer(index_vbo)
	vao:AttachInstanceBuffer(instance_vbo)

	local primitive_mode = GL_TRIANGLES

	local this = {
		lod_info = lod_info,
		layers_settings = layers_settings,

		instance_data = instance_data,

		instance_vbo = instance_vbo,
		index_vbo = index_vbo,
		vbo = vbo,
		vao = vao,

		primitive_mode = primitive_mode,
	}
	function this:SetPrimitiveMode(primitive_mode)
		this.primitive_mode = primitive_mode
	end

	function this:Draw()
		this:DrawCenter(1)
		for i=1, #this.layers_settings do
			this:DrawLayer(i, 1)
		end
	end
	function this:DrawCenter(lod_level)
		vao:DrawElements(this.primitive_mode, --primitivesMode
			this.lod_info.center.count, --drawCount
			0, --baseIndex
			1, --instanceCount
			0, --baseVertex
			0  --baseInstance
		)
	end
	function this:DrawLayer(layer, lod_level)
		local layer_settings = this.layers_settings[layer]
		local lod = this.lod_info.plane[layer_settings.base_lod + lod_level - 1]
		vao:DrawElements(this.primitive_mode, --primitivesMode
			lod.count, --drawCount
			lod.base,  --baseIndex
			12,        --instanceCount
			0,         --baseVertex
			layer_settings.instance_base --baseInstance
		)
	end

	function this:Delete()
		if this.instance_vbo ~= nil then this.instance_vbo:Delete() end
		if this.index_vbo ~= nil then this.index_vbo:Delete() end
		if this.vbo ~= nil then this.vbo:Delete() end
		if this.vao ~= nil then this.vao:Delete() end
	end

	return this
end

function generate_clipmap_center_instance_data(instance_data)
	instance_data[#instance_data+1] = 5 -- id
	instance_data[#instance_data+1] = 0 -- rotation
	instance_data[#instance_data+1] = 1 -- scale
	instance_data[#instance_data+1] = 0 -- layer
end
function generate_clipmap_tile_instance_data(instance_data, scale, layer)
	local corners = {}
	for id=0,15 do
		local rotation = 0
		if id<4 then -- top
			rotation = 2
		elseif id==7 or id==11 then -- right
			rotation = 1
		elseif id>11 then -- bottom
			rotation = 0
		elseif id==4 or id==8 then -- left
			rotation = 3
		end

		-- corners go last
		if id == 0 or id == 3 or id == 12 or id == 15 then
			corners[#corners+1] = id
			corners[#corners+1] = rotation
			corners[#corners+1] = scale
			corners[#corners+1] = layer
		elseif id ~= 5 and id ~= 6 and id ~= 9 and id ~= 10 then
			instance_data[#instance_data+1] = id
			instance_data[#instance_data+1] = rotation
			instance_data[#instance_data+1] = scale
			instance_data[#instance_data+1] = layer
		end
	end
	for i=1,#corners do
		instance_data[#instance_data+1] = corners[i]
	end
end

function generate_plane_vertices(size, grid_size)
	local center_offset = size / 2
	local step_size = size/grid_size
	local vertices = {}
	for y_i=0, grid_size do
		local y = step_size*y_i - center_offset
		for x_i=0, grid_size do
			local x = step_size*x_i - center_offset
			vertices[#vertices+1] = x
			vertices[#vertices+1] = y
		end
	end
	local vertex_count = (grid_size+1)*(grid_size+1)

	local vbo = gl.GetVBO(GL_ARRAY_BUFFER, false)
	vbo:Define(vertex_count, {
		{id=0, name='coords', type=GL_FLOAT, size=2},
	})
	vbo:Upload(vertices)

	return vbo
end

function gerenate_plane_indices(indices, grid_size, lod)
	local lod_step = math.pow(2, lod)
	local index_count = (grid_size/lod_step * grid_size/lod_step) * 6
	index_count = 0

	for row=0, grid_size-lod_step, lod_step do
		local row_offset = row*(grid_size+1)
		for col=0, grid_size-lod_step, lod_step do
			local a = row_offset + col
			local b = a+lod_step
			local c = b+lod_step*grid_size
			local d = c+lod_step
			indices[#indices+1] = a
			indices[#indices+1] = b
			indices[#indices+1] = d
			indices[#indices+1] = a
			indices[#indices+1] = d
			indices[#indices+1] = c
			index_count = index_count+6
		end
	end
	return index_count
end
function generate_clipmap_center_indices(indices, grid_size)
	local layer_count = grid_size / 2
	for layer=1, layer_count do
		generate_clipmap_center_layer_indices(indices, grid_size, layer)
	end
end
function generate_clipmap_center_layer_indices(indices, grid_size, layer)
	local layer_count = grid_size / 2
	local row_start = layer_count - layer
	local col_start = row_start
	local vertex_end = layer*2

	local row = row_start
	for y_i=1, vertex_end do
		local row_offset = row*(grid_size+1)
		local col = col_start
		for x_i=1, vertex_end do
			if (y_i==1 or y_i==vertex_end)
				or (x_i==1 or x_i==vertex_end)
			then
				local a = row_offset + col
				local b = a+1
				local c = b+grid_size
				local d = c+1
				indices[#indices+1] = a
				indices[#indices+1] = b
				indices[#indices+1] = d
				indices[#indices+1] = a
				indices[#indices+1] = d
				indices[#indices+1] = c
			end
			col = col + 1
		end
		row = row + 1
	end
end

-- e-------f-------*          *-------*
--  \     / \     / \          \     / \
--   \ 4 /   \   /   \          \   /   \
--    \ /  3  \ /     \          \ /     \
--     c-------d-------*   ...    *-------*
--    / \  2  / \     /          / \     /
--   /   \   /   \   /          /   \   /
--  /  1  \ /     \ /          /     \ /
-- a-------b-------*          *-------*
function generate_mesh(size_x, size_y, subdivisions_y)
	local vertex_layout = {
		{id = 0, name = 'coords', size = 2},
	}
	local vertex_count = 0
	local vertices = {}
	local indices = {}

	local step_y = size_y / subdivisions_y
	local step_x = step_y / (math.sqrt(3) / 2)
	local subdivisions_x = math.floor(size_x / step_x)
	if subdivisions_x%2 ~= 0 then
		subdivisions_x = subdivisions_x + 1
	end
	step_x = size_x / subdivisions_x

	local odd_start_offset = step_x / 2
	local pos_x, pos_y = 0, 0
	for y=0, subdivisions_y, 1 do
		if y%2 == 0 then
			pos_x = 0
		else
			pos_x = odd_start_offset
		end

		for x=0, subdivisions_x, 1 do
			-- coords
			vertices[#vertices+1] = pos_x
			vertices[#vertices+1] = pos_y

			vertex_count = vertex_count+1

			if x==subdivisions_x-1 and y%2 ~= 0 then
				pos_x = pos_x + step_x
			else
				pos_x = pos_x + step_x
			end
		end -- for x

		pos_y = pos_y + step_y
	end -- for y

	for y=0, subdivisions_y-2, 2 do
		local a = (subdivisions_x+1) * y
		local b = a + 1
		local c = a + (subdivisions_x+1)
		local d = c + 1
		local e = c + (subdivisions_x+1)
		local f = e + 1
		for x=0, subdivisions_x*2 - 1, 2 do
			-- CCW
			-- 1
			indices[#indices+1] = a
			indices[#indices+1] = b
			indices[#indices+1] = c
			-- 2
			indices[#indices+1] = b
			indices[#indices+1] = d
			indices[#indices+1] = c
			-- 3
			indices[#indices+1] = c
			indices[#indices+1] = d
			indices[#indices+1] = f
			-- 4
			indices[#indices+1] = c
			indices[#indices+1] = f
			indices[#indices+1] = e
			a,b = b,b+1
			c,d = d,d+1
			e,f = f,f+1
		end -- for x
	end -- for y

	return vertex_layout, vertex_count, vertices, indices
end


return {
	Clipmap = Clipmap,
}