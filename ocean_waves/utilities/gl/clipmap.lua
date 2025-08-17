-- File: clipmap.lua

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

local pow = math.pow
local min = math.min
local max = math.max
local floor = math.floor
local log = math.log

local glUseShader = gl.UseShader
local glDispatchCompute = gl.DispatchCompute
local glUniform = gl.Uniform

local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO

local GL_ALL_BARRIER_BITS = GL.ALL_BARRIER_BITS

local GL_UNSIGNED_BYTE = GL.UNSIGNED_BYTE
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

local Clipmap = {}
function Clipmap:new(mesh, primitive_mode)
	local vbo = generate_plane_vertices(mesh.size, mesh.grid_count)

	local indices = {}
	generate_clipmap_center_indices(indices, mesh.grid_count)
	local lod_info = {
		max_lod = log(mesh.grid_count) / log(2),
		center = { { base_index=0, index_count=#indices } },
		plane = {}
	}
	for lod=1, lod_info.max_lod do
		local base_index = #indices
		local index_count = gerenate_plane_indices(indices, mesh.grid_count, lod)
		lod_info.plane[#(lod_info.plane)+1] = {
			base_index = base_index,
			index_count = index_count,
		}
	end

	local index_vbo = glGetVBO(GL_ELEMENT_ARRAY_BUFFER, false)
	index_vbo:Define(#indices, GL_UNSIGNED_INT)
	index_vbo:Upload(indices)

	local layers_settings = {
		{ layer=1, scale=0.5, lod=1, base_instance=nil, visible_count=12, distance=0 },
		{ layer=2, scale=1,   lod=1, base_instance=nil, visible_count=12, distance=0 },
		{ layer=3, scale=2,   lod=1, base_instance=nil, visible_count=12, distance=0 },
		{ layer=4, scale=4,   lod=1, base_instance=nil, visible_count=12, distance=0 },
		{ layer=5, scale=8,   lod=1, base_instance=nil, visible_count=12, distance=0 },
		{ layer=6, scale=16,  lod=1, base_instance=nil, visible_count=12, distance=0 }
	}
	local tile_count = 1 + 12*#layers_settings
	local instance_data = {}
	generate_clipmap_center_instance_data(instance_data)
	for l=1, #layers_settings do
		local layer = layers_settings[l]
		local visible = {
			 0,  1,  2,  3,
			 4,          7,
			 8,         11,
			12, 13, 14, 15
		}
		generate_clipmap_tile_instance_data(instance_data, layer, visible)
	end
	local instance_vbo = glGetVBO(GL_ARRAY_BUFFER, false)
	instance_vbo:Define(tile_count, {
		{id=1, name='instance_data', type=GL_FLOAT, size=4} -- uvec4
	})
	instance_vbo:Upload(instance_data)

	local vao = glGetVAO()
	vao:AttachVertexBuffer(vbo)
	vao:AttachIndexBuffer(index_vbo)
	vao:AttachInstanceBuffer(instance_vbo)

	local instance_ssbo = glGetVBO(GL_SHADER_STORAGE_BUFFER, false)
	instance_ssbo:Define(tile_count, {
		{id=0, name='instance_data', size=1} -- vec4
	})
	instance_ssbo:Upload(instance_data)

	local tile_distance_ssbo = glGetVBO(GL_SHADER_STORAGE_BUFFER, true)
	tile_distance_ssbo:Define(#layers_settings+1, {
		{id=0, name="distances", size=1} -- vec4
	})

	local primitive_mode = GL_TRIANGLES

	local this = {
		mesh_info = mesh,

		lod_info = lod_info,
		layers_settings = layers_settings,

		tile_count = tile_count,
		instance_data = instance_data,

		instance_ssbo = instance_ssbo,
		tile_distance_ssbo = tile_distance_ssbo,

		instance_vbo = instance_vbo,
		index_vbo = index_vbo,
		vbo = vbo,
		vao = vao,

		center_visible = false,
		center_distance = 100000000,
		center_lod = 1,

		lod_bins = nil,

		primitive_mode = primitive_mode,
	}
	function this:SetPrimitiveMode(mode)
		if mode == "TRIANGLES" then
			this.primitive_mode = GL_TRIANGLES
		elseif mode == "LINES" then
			this.primitive_mode = GL_LINES
		elseif mode == "POINTS" then
			this.primitive_mode = GL_POINTS
		end
	end
	function this:CullTiles(cull_tiles_comp)
		this.instance_ssbo:BindBufferRange(5, nil, nil, GL_SHADER_STORAGE_BUFFER)
		this.tile_distance_ssbo:BindBufferRange(6, nil, nil, GL_SHADER_STORAGE_BUFFER)
		this.instance_vbo:BindBufferRange(7, nil, nil, GL_SHADER_STORAGE_BUFFER)

		glUseShader(cull_tiles_comp)
			glDispatchCompute(1, 1, 1, nil)

		this.tile_distance_ssbo:BindBufferRange(6)
		local bin_data = tile_distance_ssbo:Download(nil, nil, nil, true)

		local lod_bins = {}

		local debug_print_bins = false
		local cpu_side_binning = true

		local MIN_LOD_LEVEL = 1
		local MAX_LOD_LEVEL = this.lod_info.max_lod
		local LOD_STEP = this.mesh_info.lod_step_distance;
		local DISPLACEMENT_FALLOFF_START = this.mesh_info.displacement_falloff_start
		local DISPLACEMENT_FALLOFF_DIST = this.mesh_info.displacement_falloff_distance
		local DISPLACEMENT_FALLOFF_END = DISPLACEMENT_FALLOFF_START+DISPLACEMENT_FALLOFF_DIST

		local previous_lod = nil
		local current_bin = nil

		-- visible_count = bin_data[1]
		local center_distance      = bin_data[2]
		-- base_instance = bin_data[3]
		this.center_lod = bin_data[4]
		this.center_visible = center_distance > 0
		if this.center_visible then
			previous_lod = this.center_lod
			this.center_lod = 1
		end

		for i=1, #this.layers_settings do
			local data_offset = i*4
			local visible_count = bin_data[data_offset+1]
			local distance      = bin_data[data_offset+2]
			local base_instance = bin_data[data_offset+3]
			local lod           = bin_data[data_offset+4]

			if cpu_side_binning then
				if visible_count > 0 then
					-- Make sure that adjacent layers have similar lod levels
					if previous_lod then
						lod = min(lod, previous_lod)
					end
					-- After the displacement crank it down
					if distance > DISPLACEMENT_FALLOFF_END then
						lod = MAX_LOD_LEVEL
					end
					previous_lod = lod

					if not current_bin then
						current_bin = {}
						current_bin["visible_count"] = visible_count
						current_bin["base_instance"] = base_instance
						current_bin["lod"] = lod
					elseif current_bin.lod == lod then
						current_bin["visible_count"] = current_bin["visible_count"] + visible_count
					else
						lod_bins[#lod_bins+1] = {
							visible_count = current_bin["visible_count"],
							base_instance = current_bin["base_instance"],
							lod = current_bin["lod"]
						}
						current_bin["visible_count"] = visible_count
						current_bin["base_instance"] = base_instance
						current_bin["lod"] = lod
					end
				elseif previous_lod then
					-- This layer isn't visible but there has been a visible layer.
					-- There will be no more visible layers.
					break
				end
			else
				-- copy direnctly from gpu
				if visible_count > 0 then
					bin = {
						lod = lod,
						visible_count = visible_count,
						base_instance = base_instance,
					}
					lod_bins[#lod_bins+1] = bin
				end
			end
		end

		if cpu_side_binning and current_bin then
			lod_bins[#lod_bins+1] = {
				lod = current_bin['lod'],
				base_instance = current_bin['base_instance'],
				visible_count = current_bin['visible_count']
			}
		end

		if debug_print_bins then
			for i=1, #lod_bins do
				local bin = lod_bins[i]
				Spring.Echo(i, bin.visible_count, bin.base_instance, bin.lod)
			end
		end

		this.lod_bins = lod_bins
	end

	function this:Draw()
		this:DrawCenter()
		if not this.lod_bins then
			return
		end
		for i=1, #this.lod_bins do
			local bin = this.lod_bins[i]
			this:DrawBin(bin)
		end
	end
	function this:DrawCenter(lod_level)
		if this.center_visible then
			local lod = this.lod_info.center[1]
			vao:DrawElements(this.primitive_mode, --primitivesMode
				lod.index_count, --drawCount
				lod.base_index, --baseIndex
				1, --instanceCount
				0, --baseVertex
				0  --baseInstance
			)
		end
	end
	function this:DrawBin(bin)
		if bin.visible_count == 0 then return end
		local lod = this.lod_info.plane[bin.lod]
		vao:DrawElements(this.primitive_mode, --primitivesMode
			lod.index_count,   --drawCount (index count)
			lod.base_index,    --baseIndex (first index)
			bin.visible_count, --instanceCount
			0,                 --baseVertex
			bin.base_instance  --baseInstance
		)
	end
	function this:GetTileCount()
		return 1 + 12*#this.layers_settings
	end

	function this:Delete()
		if this.tile_distance_ssbo ~= nil then tile_distance_ssbo:Delete() end
		if this.instance_ssbo ~= nil then this.instance_ssbo:Delete() end
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
function generate_clipmap_tile_instance_data(instance_data, layer, visibility)
	layer.base_instance = #instance_data/4
	local scale = layer.scale
	local layer_index = layer.layer

	local corners = {}
	for i,id in ipairs(visibility) do
		local rotation = 0
		-- listed in clockwise order
		--  0,  1,  2,  3,
		--  4,          7,
		--  8,         11,
		-- 12, 13, 14, 15
		-- 0 = 0
		-- 1 = 90
		-- 2 = 180
		-- 3 = 270
		-- top 2
		if     id==0  then rotation = 2 -- left
		elseif id==1  then rotation = 2 -- center left
		elseif id==2  then rotation = 2 -- center right
		elseif id==3  then rotation = 1 -- right
		-- right 1
		elseif id==7  then rotation = 1 -- top
		elseif id==11 then rotation = 1 -- bottom
		-- bottom 0
		elseif id==15 then rotation = 0 -- right
		elseif id==14 then rotation = 0 -- center right
		elseif id==13 then rotation = 0 -- center left
		elseif id==12 then rotation = 3 -- left
		-- left 3
		elseif id==8  then rotation = 3 -- bottom
		elseif id==4  then rotation = 3 -- top
		end

		-- corners go last
		if id == 0 or id == 3 or id == 12 or id == 15 then
			corners[#corners+1] = id
			corners[#corners+1] = rotation
			corners[#corners+1] = scale
			corners[#corners+1] = layer_index
		else
			instance_data[#instance_data+1] = id
			instance_data[#instance_data+1] = rotation
			instance_data[#instance_data+1] = scale
			instance_data[#instance_data+1] = layer_index
		end
	end
	for i=1,#corners do
		instance_data[#instance_data+1] = corners[i]
	end
end

function generate_plane_vertices(size, grid_count)
	local center_offset = -size / 2
	local step_size = size/grid_count
	local vertices = {}
	local y = center_offset
	for y_i=0, grid_count do
		local x = center_offset
		for x_i=0, grid_count do
			vertices[#vertices+1] = x
			vertices[#vertices+1] = y
			x = x+step_size
		end
		y = y+step_size
	end
	local vertex_count = (grid_count+1)*(grid_count+1)

	local vbo = glGetVBO(GL_ARRAY_BUFFER, false)
	vbo:Define(vertex_count, {
		{id=0, name='coords', type=GL_FLOAT, size=2},
	})
	vbo:Upload(vertices)

	return vbo
end

-- From bottom to top, left to right
function gerenate_plane_indices(indices, grid_count, lod)
	local lod_step = pow(2, lod)
	local index_count = (grid_count/lod_step * grid_count/lod_step) * 6

	local end_vertex = grid_count-lod_step
	local b_step = lod_step*grid_count
	for row=0, end_vertex, lod_step do
		local row_offset = row*(grid_count+1)
		for col=0, end_vertex, lod_step do
			local a = row_offset+col
			local b = a+lod_step
			local c = b+b_step
			local d = c+lod_step
			indices[#indices+1] = a
			indices[#indices+1] = b
			indices[#indices+1] = d
			indices[#indices+1] = a
			indices[#indices+1] = d
			indices[#indices+1] = c
		end
	end
	return index_count
end
function generate_clipmap_center_indices(indices, grid_count)
	local layer_count = grid_count / 2
	for layer=1, layer_count do
		generate_clipmap_center_layer_indices(indices, grid_count, layer)
	end
end
function generate_clipmap_center_layer_indices(indices, grid_count, layer)
	local layer_count = grid_count / 2
	local row_start = layer_count - layer
	local col_start = row_start
	local vertex_end = layer*2

	for y_i=1, vertex_end do
		local x_step = 1
		if y_i~=1 and y_i~=vertex_end then
			x_step = vertex_end-1
		end
		local row_offset = (row_start+y_i-1)*(grid_count+1)
		local col = col_start
		for x_i=1, vertex_end, x_step do
			local a = row_offset + col
			local b = a+1
			local c = b+grid_count
			local d = c+1
			indices[#indices+1] = a
			indices[#indices+1] = b
			indices[#indices+1] = d
			indices[#indices+1] = a
			indices[#indices+1] = d
			indices[#indices+1] = c
			col = col + x_step
		end
	end
end


return {
	Clipmap = Clipmap,
}