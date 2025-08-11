
-- File: obj_loader.lua

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

--- Example
--- local ObjectLoader = VFS.Include('LuaUI/Widgets/obj_loader.lua')
--- local obj_loader = ObjectLoader:New()
--- obj_loader:LoadFromFile(model_path)
--- local layout = {
--- 	{id=0, name="position", type=GL_FLOAT, size=4},
--- 	{id=1, name="uv",       type=GL_FLOAT, size=2},
--- 	{id=2, name="normal",   type=GL_FLOAT, size=3},
--- }
--- local settings = {
--- 	flip_u = false,
--- 	flip_v = true,
--- }
--- local vertices, indices = obj_loader:AsBufferData(layout, settings)
local ObjectLoader = {}
function ObjectLoader:New()
	local this = {}

	function this:Reset()
		this = {
			vertex_positions = {},
			vertex_normals = {},
			vertex_uvs = {},
			faces = {},
		}
	end
	this:Reset()

	---@param path string
	function this:LoadFromFile(path)
		local obj = VFS.LoadFile(path, VFS.RAW)
		this:LoadFromString(obj)
	end

	---@param source string
	function this:LoadFromString(souce)
		for line in souce:gmatch("[^\r\n]+") do
			local iter = line:gmatch("%S+")
			local current = iter()
			if current == "#" then
				-- this is a comment
			elseif current == "v" then
				this:ParseVertexPosition(iter)
			elseif current == "vt" then
				this:ParseVertexTextureCoordinate(iter)
			elseif current == "vn" then
				this:ParseVertexNormal(iter)
			elseif current == "f" then
				this:ParseFace(iter)
			end
		end
	end

	-- FIXME: Remove duplicate vertices by using indices better
	---@param layout = {{id, name, size}, ...}
	---@param 	id number
	---@param 	name string "position" | "uv" | "normal"
	---@param 	size number
	---@param settings = {flip_u, flip_v}
	---@param 	flip_u bool
	---@param 	flip_v bool
	function this:AsBufferData(layout, settings)
		local position_size, uv_size, normal_size = 0, 0, 0
		local position_id,normal_id,uv_id
		for _,attribute in ipairs(layout) do
			local id, name, size = attribute.id, attribute.name, attribute.size
			if name == "position" then
				position_size = size
				position_id = id
			elseif name == "uv" then
				uv_size = size
				uv_id = id
			elseif name == "normal" then
				normal_size = size
				normal_id = id
			end
		end

		local position_offset,uv_offset,normal_offset = 0,0,0
		if position_id and uv_id then
			if position_id < uv_id then
				uv_offset = uv_offset + position_size
			else
				position_offset = position_offset + uv_size
			end
		end
		if position_id and normal_id then
			if position_id < normal_id then
				normal_offset = normal_offset + position_size
			else
				position_offset = position_offset + normal_size
			end
		end
		if uv_id and normal_id then
			if uv_id < normal_id then
				normal_offset = normal_offset + uv_size
			else
				uv_offset = uv_offset + normal_size
			end
		end

		local vertex_stride = position_size + uv_size + normal_size

		local vertices = {}
		local indices = {}
		for _,face in ipairs(this.faces) do
			for _,face_vertex in ipairs(face) do
				local position_index = face_vertex.position_index
				local uv_index = face_vertex.uv_index
				local normal_index = face_vertex.normal_index

				indices[#indices+1] = position_index-1

				local offset = (position_index-1)*vertex_stride

				local position = this.vertex_positions[position_index]
				vertices[offset+position_offset+1] = position[1]
				vertices[offset+position_offset+2] = position[2]
				if position_size >= 3 then
					vertices[offset+position_offset+3] = position[3] or 0
				end
				if position_size == 4 then
					vertices[offset+position_offset+4] = position[4] or 1
				end

				local uv = this.vertex_uvs[uv_index]
				local u,v,w = uv[1], uv[2], uv[3] or 0
				if settings.flip_u then u = 1 - u end
				if settings.flip_v then v = 1 - v end
				local uvw = {u,v,w}
				for i=1, uv_size do
					vertices[offset+uv_offset+i] = uvw[i]
				end

				local normal = this.vertex_normals[normal_index]
				for i=1, normal_size do
					vertices[offset+normal_offset+i] = normal[i]
				end
			end
		end

		return vertices, indices
	end

	function this:ParseVertexPosition(iter)
		local x,y,z,w = this:ParseFourNumbers(iter)
		this.vertex_positions[#this.vertex_positions+1] = {x,y,z,w}
	end
	function this:ParseVertexNormal(iter)
		local x,y,z = this:ParseThreeNumbers(iter)
		this.vertex_normals[#this.vertex_normals+1] = {x,y,z}
	end
	function this:ParseVertexTextureCoordinate(iter)
		local u,v,w = this:ParseThreeNumbers(iter)
		this.vertex_uvs[#this.vertex_uvs+1] = {u,v,w}
	end

	-- Assumes that a face only has 3 vertices
	-- just position data
	--     f v1 v2 v3
	-- position and uv
	--     f v1/vt1 v2/vt2 v3/vt3
	-- position, uv, and normal
	--     f v1/vt1/vn1 v2/vt2/vn2 v3/vt3/vn3
	-- position and normal
	--     f v1//vn1 v2//vn2 v3//vn3
	function this:ParseFace(iter)
		this.faces[#this.faces+1] = {
			this:ParseFaceVertex(iter),
			this:ParseFaceVertex(iter),
			this:ParseFaceVertex(iter)
		}
	end
	function this:ParseFaceVertex(iter)
		local source = iter()

		local position_index, uv_index, normal_index
		local from_index = 1

		local slash_1 = source:find("/", 1)
		if slash_1 then
			position_index = source:sub(1, slash_1-1)

			local slash_2 = source:find("/", slash_1+1)
			if slash_2 then
				-- f v1/vt1/vn1
				-- f v1//vn1
				uv_index = source:sub(slash_1+1, slash_2-1)
				normal_index = source:sub(slash_2+1)
			else
				-- f v1/vt1
				uv_index = source:sub(slash_1+1)
			end
		else
			-- f v1
			position_index = source:sub(1)
		end

		if position_index then position_index = tonumber(position_index) end
		if uv_index then uv_index = tonumber(uv_index) end
		if normal_index then normal_index = tonumber(normal_index) end

		local face_vertex = {
			position_index = position_index,
			uv_index = uv_index,
			normal_index = normal_index
		}
		return face_vertex
	end

	function this:ParseFourNumbers(iter)
		local a, b, c = this:ParseThreeNumbers(iter)
		local d = this:ParseNumber(iter)
		return a, b, c, d
	end
	function this:ParseThreeNumbers(iter)
		local a = this:ParseNumber(iter)
		local b = this:ParseNumber(iter)
		local c = this:ParseNumber(iter)
		return a, b, c
	end
	function this:ParseNumber(iter)
		local n = iter()
		if n then
			return tonumber(n)
		end
	end
	return this
end

return ObjectLoader