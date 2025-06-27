-- File: utilities/gl/texture.lua

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

--[[
Description: This provides Texture which is a convinient wrapper around common
gl texture functions.
]]

local glCreateTexture = gl.CreateTexture
local glDeleteTexture = gl.DeleteTexture
local glTexture = gl.Texture
-- local glActiveTexture = gl.ActiveTexture
local glBindImageTexture = gl.BindImageTexture
-- min/mag filter
local GL_NEAREST = GL.NEAREST
local GL_LINEAR = GL.LINEAR
local GL_NEAREST_MIPMAP_NEAREST = GL.NEAREST_MIPMAP_NEAREST
local GL_LINEAR_MIPMAP_NEAREST = GL.LINEAR_MIPMAP_NEAREST
local GL_NEAREST_MIPMAP_LINEAR = GL.NEAREST_MIPMAP_LINEAR
local GL_LINEAR_MIPMAP_LINEAR = GL.LINEAR_MIPMAP_LINEAR
-- wrap
local GL_REPEAT = GL.REPEAT
local GL_MIRRORED_REPEAT = GL.MIRRORED_REPEAT
local GL_CLAMP = GL.CLAMP
local GL_CLAMP_TO_EDGE = GL.CLAMP_TO_EDGE
local GL_CLAMP_TO_BORDER = GL.CLAMP_TO_BORDER
-- target
local GL_TEXTURE_2D = GL.TEXTURE_2D
local GL_TEXTURE_2D_MULTISAMPLE = GL.TEXTURE_2D_MULTISAMPLE
local GL_TEXTURE_2D_ARRAY = 0x8C1A--GL.TEXTURE_2D_ARRAY--FIXME: wait for new engine version
local GL_TEXTURE_3D = GL.TEXTURE_3D
-- format
local GL_RGBA16F = GL.RGBA16F
local GL_RGBA32F = GL.RGBA32F
-- access
local GL_READ_ONLY = GL.READ_ONLY
local GL_WRITE_ONLY = GL.WRITE_ONLY
local GL_READ_WRITE = GL.READ_WRITE

local Texture = {}
function Texture:new(handle, dimensions, default_unit, format)
	local handle = handle
	if type(handle) ~= 'string' then
		return nil
	end

	local dimensions = dimensions
	if type(dimensions) ~= 'table' or
		dimensions['x'] == nil or type(dimensions['x']) ~= 'number' or dimensions['x'] < 1 or
		dimensions['y'] == nil or type(dimensions['y']) ~= 'number' or dimensions['y'] < 1 or
		dimensions['z'] == nil or type(dimensions['z']) ~= 'number' or dimensions['z'] < 1
		then
			return nil
	end

	if default_unit ~= nil and type(default_unit) ~= 'number' then
		return nil
	end

	local default_access = GL_READ_WRITE
	local format = format
	if format ~= GL_RGBA32F and format ~= GL_RGBA16F then
		return nil
	end

	handle = glCreateTexture(
		dimensions.x, dimensions.y, dimensions.z,
		{
			target = GL_TEXTURE_2D_ARRAY,
			format = format,
			min_filter = GL_LINEAR,
			mag_filter = GL_LINEAR,
			wrap_s = GL_REPEAT,
			wrap_t = GL_REPEAT,
			-- wrap_r = GL_CLAMP_TO_EDGE,
			-- compareFunc = number
			-- lodBias = number
			-- aniso = number
			border = false,
			fbo = false,
			fboDepth = false,
		},
		handle
	)
	if handle == nil then
		return nil
	end

	local this = {
		handle = handle,
		dimensions = dimensions,
		format = format,
		default_access = default_access,
		default_unit = default_unit,
	}

	function this:format_as_qualifier()
		if this.format == GL_RGBA16F then
			return "rgba16f"
		elseif this.format == GL_RGBA32F then
			return "rgba32f"
		end
	end

	function this:bind_image(unit_override, access_override)
		local texture_unit = this.default_unit
		if type(unit_override) == "number" then texture_unit = unit_override end

		local access = this.default_access
		if type(access_override) == "number" then access = access_override end

		local level = 0
		-- FIXME: when the latest Engine gets released set layer to nil
		local layer = 0
		glBindImageTexture(texture_unit, this.handle, level, layer, access, this.format)
	end

	function this:use_texture(unit_override)
		local texture_unit = this.default_unit
		if type(unit_override) == "number" then texture_unit = unit_override end

		glTexture(texture_unit, this.handle)
	end

	function this:delete()
		glDeleteTexture(this.handle)
	end

	return this
end

return Texture
