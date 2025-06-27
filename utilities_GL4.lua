-- File: utilites_GL4.lua

--[[
Copyright (C) 2024 chmod777

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License version 3 as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along
with this program. If not, see <https://www.gnu.org/licenses/>. 
]]

local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture

local glTexture = gl.Texture
local GL_NEAREST = GL.NEAREST
local GL_LINEAR = GL.LINEAR
local GL_CLAMP_TO_EDGE = GL.CLAMP_TO_EDGE
local GL_MIRRORED_REPEAT = GL.MIRRORED_REPEAT
local GL_REPEAT = GL.REPEAT

-- format
local GL_RGBA8 = 0x8058
local GL_RGBA16F = GL.RGBA16F -- 0x881A
local GL_RGBA32F = GL.RGBA32F -- 0x8814

local glCreateFBO = gl.CreateFBO
local glDeleteFBO = gl.DeleteFBO
local glRawBindFBO = gl.RawBindFBO

local GL_COLOR_ATTACHMENT0_EXT = 0x8CE0
local GL_COLOR_ATTACHMENT1_EXT = 0x8CE1
local GL_COLOR_ATTACHMENT2_EXT = 0x8CE2

local GL_DEPTH_COMPONENT   = 0x1902
local GL_DEPTH_COMPONENT16 = 0x81A5
local GL_DEPTH_COMPONENT24 = 0x81A6
local GL_DEPTH_COMPONENT32 = 0x81A7

local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO

local GL_ARRAY_BUFFER = GL.ARRAY_BUFFER
local GL_ELEMENT_ARRAY_BUFFER = GL.ELEMENT_ARRAY_BUFFER

local GL_TRIANGLES = GL.TRIANGLES
local GL_LINES = GL.LINES
local GL_POINTS = GL.POINTS

local Quad = {}
--- num, num, num, num, bool, bool
function Quad:new(minX, minY, maxX, maxY, flipU, flipV)
	if minX == nil then minX = -1 end
	if minY == nil then minY = -1 end
	if maxX == nil then maxX = 1 end
	if maxY == nil then maxY = 1 end
	if minX > maxX then minX,maxX = maxX,minX end
	if minY > maxY then minY,maxY = maxY,minY end
	
	local startU,endU = 0,1
	local startV,endV = 0,1
	if flipU then
		startU,endU = endU,startU
	end
	if flipV then
		startV,endV = endV,startV
	end
	
	local vertices = {
		minX,minY, startU,startV, --bottom left
		minX,maxY, startU,endV,   --bottom right
		maxX,maxY, endU,endV,     --top right
		maxX,minY, endU,startV,   --top left
	}
	local vertexCount = 4
	local vertexVBOLayout = {
		{id = 0, name = 'coords', size = 2},
		{id = 1, name = 'uv', size = 2},
	}
	
	local indices = {
		2, 1, 0,
		3, 2, 0,
	}
	local indexCount = #indices

	local VBO = glGetVBO(GL_ARRAY_BUFFER, false)
	VBO:Define(vertexCount, vertexVBOLayout)
	VBO:Upload(vertices)

	local indexVBO = glGetVBO(GL_ELEMENT_ARRAY_BUFFER, false)
	indexVBO:Define(#indices)
	indexVBO:Upload(indices)

	local VAO = glGetVAO()
	VAO:AttachVertexBuffer(VBO)
	VAO:AttachIndexBuffer(indexVBO)

	local this = {
		vertexVBO = VBO,
		indexVBO = VBO,
		VAO = VAO,
		vertices = vertices,
		vertexCount = vertexCount,
		indices = indices,
		indexCount = indexCount,
	}

	function this:draw()
		this.VAO:DrawElements(GL_TRIANGLES, indexCount, 0, 0, 0, 0)
	end

	function this:Delete()
		if this.indexVBO ~= nil then
			this.indexVBO:Delete()
		end
		if this.vertexVBO ~= nil then
			this.vertexVBO:Delete()
		end
		if this.VAO ~= nil then
			this.VAO:Delete()
		end
	end

	return this
end

local FBO = {}
--- num num bool
function FBO:new(sizeX, sizeY, withDepth)
	if sizeX == nil then sizeX = 256 end
	if sizeY == nil then sizeY = 256 end
	if withDepth == nil then withDepth = false end

	local tex = glCreateTexture(sizeX, sizeY, {
		format = GL_RGBA8,
		border = false,
		target = GL_TEXTURE_2D,
		min_filter = GL_NEAREST,
		mag_filter = GL_NEAREST,
		wrap_s = GL_CLAMP_TO_EDGE,
		wrap_t = GL_CLAMP_TO_EDGE,
		fbo = true,
	})

	local config
	local depth
	if withDepth then
		depth = glCreateTexture(sizeX, sizeY, {
			format = GL_DEPTH_COMPONENT24,
			border = false,
			min_filter = GL_NEAREST,
			mag_filter = GL_NEAREST,
		})
	end
	config = {
		color0 = tex,
		depth = depth,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	}
	fbo = glCreateFBO(config)

	local this = {
		fbo = fbo,
		tex = tex,
		depth = depth
	}

	function this:Delete()
		if glDeleteTexture then
			if this.tex ~= nil then
				glDeleteTexture(this.tex)
			end
			if this.depth ~= nil then
				glDeleteTexture(this.depth)
			end
		end
		if this.fbo ~= nil and glDeleteFBO then
			glDeleteFBO(this.fbo)
		end
	end

	function this:bind()
		this.prevFBO = glRawBindFBO(this.fbo)
	end

	function this:unbind()
		glRawBindFBO(nil, nil, this.prevFBO)
		this.prevFBO = nil
	end

	return this
end

-- function load_obj(path)
-- 	local obj = VFS.LoadFile(path, VFS.RAW)
-- 	local raw_vertices = {}
-- 	local raw_uv = {}

-- 	local vertices = {}
-- 	local indices = {}

-- 	local vertex_layout = {
-- 		{id = 0, name = 'coords', size = 4},
-- 		{id = 1, name = 'uv',     size = 2},
-- 	}
-- 	local vertex_stride = 6

-- 	for line in obj:gmatch("[^\r\n]+") do
-- 		local first = line:sub(1,2)
-- 		local rest = line:sub(3, #line)

-- 		-- if first == "# " then     -- this is a comment
-- 		-- elseif first == "o " then -- object?
-- 		-- elseif first == "s " then -- smooth/surface?
-- 		if first == "v " then
-- 			-- implicit cast 0+str fails on error while tonumber(str) does not
-- 			local func = rest:gmatch("%S+")
-- 			raw_vertices[#raw_vertices+1] = 0+func()
-- 			raw_vertices[#raw_vertices+1] = 0+func()
-- 			raw_vertices[#raw_vertices+1] = 0+func()
-- 		elseif first == "vt" then
-- 			local func = rest:gmatch("%S+")
-- 			raw_uvs[#raw_uvs+1] = 0+func()
-- 			raw_uvs[#raw_uvs+1] = 0+func()
-- 		-- elseif first == "vn" then
-- 		-- 	local func = rest:gmatch("%S+")
-- 		-- 	raw_normals[#raw_normals+1] = 0+func()
-- 		-- 	raw_normals[#raw_normals+1] = 0+func()
-- 		-- 	raw_normals[#raw_normals+1] = 0+func()
-- 		elseif first == "f " then
-- 			for vertex_split in rest:gmatch("%S+") do
-- 				local func = vertex_split:gmatch("[^/]+")
-- 				local vertex_index = tonumber(func())
-- 				local uv_index = tonumber(func())
-- 				local normal_index = tonumber(func())

-- 				indices[#indices+1] = vertex_index-1

-- 				local offset = (vertex_index-1)*vertexStride
-- 				vertices[offset+1] = raw_vertices[(vertex_index-1)*3+1]
-- 				vertices[offset+2] = raw_vertices[(vertex_index-1)*3+2]
-- 				vertices[offset+3] = raw_vertices[(vertex_index-1)*3+3]
-- 				vertices[offset+4] = 1.0

-- 				vertices[offset+5] =       raw_uvs[(uv_index-1)*2+1]
-- 				vertices[offset+6] = 1.0 - raw_uvs[(uv_index-1)*2+2]
-- 			end
-- 		end
-- 	end

-- 	return vertex_layout, vertices, indices
-- end

return Quad, FBO