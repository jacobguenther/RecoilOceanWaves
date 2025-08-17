-- File: utilities/gl/fbo.lua

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

local GL_RGBAF32 = GL.RGBAF32
local GL_RGB16F = GL.RGB16F
local GL_RGBA8 = GL.RGBA8

local GL_COLOR_ATTACHMENT0_EXT = GL.COLOR_ATTACHMENT0_EXT
local GL_COLOR_ATTACHMENT1_EXT = GL.COLOR_ATTACHMENT1_EXT
local GL_COLOR_ATTACHMENT2_EXT = GL.COLOR_ATTACHMENT2_EXT
local GL_DEPTH_ATTACHMENT_EXT = GL.DEPTH_ATTACHMENT_EXT

local GL_DEPTH_COMPONENT    = 0x1902
local GL_DEPTH_COMPONENT16  = GL.DEPTH_COMPONENT16
local GL_DEPTH_COMPONENT24  = GL.DEPTH_COMPONENT24
local GL_DEPTH_COMPONENT32  = GL.DEPTH_COMPONENT32
local GL_DEPTH_COMPONENT32F = GL.DEPTH_COMPONENT32F

local glCreateFBO = gl.CreateFBO
local glDeleteFBO = gl.DeleteFBO
local glRawBindFBO = gl.RawBindFBO
local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture

local GL_TEXTURE_2D = GL.TEXTURE_2D
local GL_NEAREST = GL.NEAREST
local GL_LINEAR = GL.LINEAR
local GL_CLAMP_TO_EDGE = GL.CLAMP_TO_EDGE

local FBO = {}
---@param sizeX number? (default: 256)
---@param sizeY number? (default: 256)
---@param withDepth bool? (default: false)
function FBO:new(sizeX, sizeY, withDepth)
	if sizeX == nil then sizeX = 256 end
	if sizeY == nil then sizeY = 256 end
	if withDepth == nil then withDepth = false end

	local tex = glCreateTexture(sizeX, sizeY, {
		target = GL_TEXTURE_2D,
		format = GL_RGBA8,
		border = false,
		min_filter = GL_LINEAR,
		mag_filter = GL_LINEAR,
		wrap_s = GL_CLAMP_TO_EDGE,
		wrap_t = GL_CLAMP_TO_EDGE,
		fbo = true,
	})

	local config
	local depth
	if withDepth then
		depth = glCreateTexture(sizeX, sizeY, {
			target = GL_TEXTURE_2D,
			format = GL_DEPTH_COMPONENT32,
			border = false,
			min_filter = GL_NEAREST,
			mag_filter = GL_NEAREST,
			fboDepth = true,
		})
	end
	config = {
		color0 = tex,
		depth = depth,
		drawbuffers = {GL_COLOR_ATTACHMENT0_EXT},
	}
	fbo = glCreateFBO(config)

	local this = {
		sizeX = sizeX,
		sizeY = sizeY,
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
		gl.Viewport(0, 0, this.sizeX, this.sizeY)
		this.prevFBO = glRawBindFBO(this.fbo)
	end

	function this:unbind()
		glRawBindFBO(nil, nil, this.prevFBO)
		this.prevFBO = nil
	end

	return this
end

return FBO
