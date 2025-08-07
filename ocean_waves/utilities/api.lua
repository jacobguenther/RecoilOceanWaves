-- File: utilities/api.lua

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

local utilities = VFS.Include('LuaUI/Widgets/ocean_waves/utilities/common.lua')
local deep_copy = utilities.deep_copy

local pow = math.pow

-- helpers --

function as_number(a)
	local n = nil
	if a then
		n = tonumber(a)
	end
	return n
end

function as_color(r, g, b, a)
	local color = nil
	local alpha = nil
	if r and g and b then
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		if type(r) == 'number' and type(g) == 'number' and type(b) == 'number' then
			color = {r = r, g = g, b = b}
			alpha = as_number(a)
		end
	end
	return color, alpha
end

function text_command(api, message)
	-- iterator for each whitespace sperated value
	local match = message:gmatch("%w+")
	if match() == 'oceanwaves' then
		local command = match()

		if command == 'menu' and is_bar then
			ui_toggle_hidden()

		elseif command == 'setwatercolor' then
			local r, g, b, a = match(), match(), match(), match()
			api.set_water_color(r, g, b, a)
		elseif command == 'setwateralpha' then
			local a = match()
			api.set_water_alpha(a)
		elseif command == 'setfoamcolor' then
			local r, g, b, a = match(), match(), match(), match()
			api.set_foam_color(r, g, b, a)
		elseif command == 'setfoamalpha' then
			local a = match()
			api.set_foam_alpha(a)
		elseif command == 'setsubsurfacecolor' then
			local r, g, b = match(), match(), match()
			api.set_subsurface_color(r, g, b)
		elseif command == 'setroughness' then
			local roughness = match()
			api.set_roughness(roughness)

		elseif command == 'setwaveresolution' then
			local resolution = match()
			api.set_wave_resolution(resolution)

		elseif command == 'setcascadetilesize' then
			local cascade_index, value = match(), match()
			api.set_cascade_tile_length(cascade_index, value)
		elseif command == 'setcascadetilelength' then
			local cascade_index, value = match(), match()
			api.set_cascade_tile_length(cascade_index, value)
		elseif command == 'setcascadedisplacementscale' then
			local cascade_index, value = match(), match()
			api.set_cascade_displacement_scale(cascade_index, value)
		elseif command == 'setcascadenormalscale' then
			local cascade_index, value = match(), match()
			api.set_cascade_normal_scale(cascade_index, value)
		elseif command == 'setcascadewindspeed' then
			local cascade_index, value = match(), match()
			api.set_cascade_wind_speed(cascade_index, value)
		elseif command == 'setcascadewinddirection' then
			local cascade_index, value = match(), match()
			api.set_cascade_wind_direction(cascade_index, value)
		elseif command == 'setcascadefetchlength' then
			local cascade_index, value = match(), match()
			api.set_cascade_fetch_length(cascade_index, value)
		elseif command == 'setcascadeswell' then
			local cascade_index, value = match(), match()
			api.set_cascade_swell(cascade_index, value)
		elseif command == 'setcascadespread' then
			local cascade_index, value = match(), match()
			api.set_cascade_spread(cascade_index, value)
		elseif command == 'setcascadedetail' then
			local cascade_index, value = match(), match()
			api.set_cascade_detail(cascade_index, value)
		elseif command == 'setcascadewhitecap' then
			local cascade_index, value = match(), match()
			api.set_cascade_whitecap(cascade_index, value)
		elseif command == 'setcascadefoamamount' then
			local cascade_index, value = match(), match()
			api.set_cascade_foam_amount(cascade_index, value)
		elseif command == 'setdebugenabledisplacement' then
			local value = match()
			api.command(value)
		elseif command == 'setdebugprimitivemode' then
			local value = match()
			api.set_debug_primitive_mode(value)
		elseif command == 'setdebugcoloring' then
			local color, texture_index = match(), match()
			api.set_debug_coloring(color, texture_index)
		end
	end
end

--- Sets up WG['oceanwaves'] functions and Widget:TextCommand
local API = {}
function API:Init(state)
	--- /oceanwaves setwatercolor r g b a
	---@param r number
	---@param g number
	---@param b number
	---@param a number?
	function set_water_color(r, g, b, a)
		local color, alpha = as_color(r, g, b, a)
		if color then
			state.material.water_color = color
			if alpha then
				state.material.alpha = alpha
			end
			state.material.update_material = true
		end
	end

	--- /oceanwaves setwateralpha a
	---@param a number
	function set_water_alpha(a)
		local alpha = as_number(a)
		if alpha then
			state.material.alpha = alpha
			state.material.update_material = true
		end
	end

	--- /oceanwaves setfoamcolor r g b a
	---@param r number
	---@param g number
	---@param b number
	---@param a number?
	function set_foam_color(r, g, b, a)
		local color, alpha = as_color(r, g, b, a)
		if color then
			state.material.foam_color = color
			if alpha then
				state.material.foam_alpha = alpha
			end
			state.material.update_material = true
		end
	end

	--- /oceanwaves setfoamalpha a
	---@param a number
	function set_foam_alpha(a)
		local alpha = as_number(a)
		if alpha then
			state.material.foam_alpha = alpha
			state.material.update_material = true
		end
	end

	--- /oceanwaves setsubsurfacecolor r g b
	---@param r number
	---@param g number
	---@param b number
	function set_subsurface_color(r, g, b)
		local color, _ = as_color(r, g, b)
		if color then
			state.material.subsurface_color = color
			state.material.update_material = true
		end
	end

	--- /oceanwaves setfoamalpha a
	---@param new_roughness number
	function set_roughness(new_roughness)
		local roughness = as_number(new_roughness)
		if roughness then
			state.material.roughness = roughness
			state.material.update_material = true
		end
	end

	function set_gravity(new_gravity)
		local gravity = as_number(new_gravity)
		if gravity then
			state:SetGravity(gravity)
		end
	end
	function set_default_gravity()
		state:SetDefaultGravity()
	end
	function get_gravity()
		return state:GetGravity()
	end
	
	--- /oceanwaves setwaveresolution new_resolution
	---@param new_resolution number
	function set_wave_resolution(new_resolution)
		local wave_resolution = as_number(new_resolution)
		if state.wave_resolution == wave_resolution then
			return
		end
		state.wave_resolution = wave_resolution
		rebuild_pipeline()
	end

	--- /oceanwaves setcascadetilelength cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_tile_length(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].tile_length = value
			state.cascades[cascade_index].should_generate_spectrum = true
			state.upload_cascades_ssbo = true
			state.upload_cascades_ubo = true
		end
	end

	--- /oceanwaves setcascadedisplacement_scale cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_displacement_scale(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].displacement_scale = value
			state.upload_cascades_ssbo = true
			state.upload_cascades_ubo = true
		end
	end

	--- /oceanwaves setcascadenormalscale cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_normal_scale(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].normal_scale = value
			state.upload_cascades_ssbo = true
			state.upload_cascades_ubo = true
		end
	end

	--- /oceanwaves setcascadewindspeed cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_wind_speed(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			local cascade = state.cascades[cascade_index]
			local wind_speed = value
			local wind_speed2 = wind_speed * wind_speed
			local wind_fetch = wind_speed * cascade.fetch_length_m

			cascade.wind_speed = wind_speed
			cascade.wind_speed2 = wind_speed2
			cascade.wind_fetch = wind_fetch
			cascade.alpha = 0.076 * pow(wind_speed2 / cascade.fetch_length_G, 0.22)
			cascade.omega = 22.0 * pow(state.gravity2 / wind_fetch, 0.33333333)

			cascade.should_generate_spectrum = true
			state.upload_cascades_ssbo = true
		end
	end

	--- /oceanwaves setcascadewinddirection cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_wind_direction(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].wind_direction = value
			state.cascades[cascade_index].wind_direction_rad = deg_to_rad(value)
			state.cascades[cascade_index].should_generate_spectrum = true
			state.upload_cascades_ssbo = true
		end
	end

	--- /oceanwaves setcascadefetchlength cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_fetch_length(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			local cascade = state.cascades[cascade_index]
			cascade.fetch_length_km = value
			local fetch_length_m = value*1e3
			local fetch_length_G = fetch_length_m * state.gravity
			local wind_fetch = cascade.wind_speed * fetch_length_m

			cascade.fetch_length_m = fetch_length_m
			cascade.fetch_length_G = fetch_length_G
			cascade.wind_fetch = wind_fetch
			cascade.alpha = 0.076 * pow(cascade.wind_speed2 / fetch_length_G, 0.22)
			cascade.omega = 22.0 * pow(state.gravity2 / wind_fetch, 0.33333333)

			cascade.should_generate_spectrum = true
			state.upload_cascades_ssbo = true
		end
	end

	--- /oceanwaves setcascadeswell cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_swell(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].swell = value
			state.cascades[cascade_index].should_generate_spectrum = true
			state.upload_cascades_ssbo = true
		end
	end

	--- /oceanwaves setcascadespread cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_spread(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].spread = value
			state.cascades[cascade_index].should_generate_spectrum = true
			state.upload_cascades_ssbo = true
		end
	end

	--- /oceanwaves setcascadedetail cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_detail(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].detail = value
			state.cascades[cascade_index].should_generate_spectrum = true
			state.upload_cascades_ssbo = true
		end
	end

	--- /oceanwaves setcascadewhitecap cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_whitecap(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].whitecap = value
			state.upload_cascades_ssbo = true
		end
	end

	--- /oceanwaves setcascadefoamamount cascade_index value
	---@param cascade_index number
	---@param value number
	function set_cascade_foam_amount(cascade_index, value)
		local cascade_index, value = as_number(cascade_index), as_number(value)
		if cascade_index and value then
			state.cascades[cascade_index].foam_amount = value
			state.upload_cascades_ssbo = true
		end
	end

	--- /oceanwaves setdebugenabledisplacement enabled
	---@param enabled string? "on"
	function set_debug_enable_displacement(enable)
		state.debug.disable_displacement = enable == "on"
		state:RebuildPipeline()
	end
	--- /oceanwaves setdebugprimitivemode cascade_index value
	---@param mode string "TRIANGLES" | "LINES" | "POINTS"
	function set_debug_primitive_mode(mode)
		state:SetPrimitiveMode(mode)
	end
	--- /oceanwaves setdebugcoloring coloring texture_index
	---@param coloring string "none" | "lod" | "clipmap" | "depth" | "displacement" | "normal" | "spectrum"
	---@param texture_index number?
	function set_debug_coloring(coloring, texture_index)
		if coloring == "none"
			or coloring == "lod"
			or coloring == "clipmap"
			or coloring == "depth"
			or coloring == "displacement"
			or coloring == "normal"
			or coloring == "spectrum"
		then
			state.debug.coloring = coloring
			if texture_index then
				local index = tonumber(texture_index)
				state.debug.texture = texture_index
			end
			state:RebuildPipeline()
		end
	end

	local api = {
		set_water_color = set_water_color,
		set_water_alpha = set_water_alpha,
		set_foam_color = set_foam_color,
		set_foam_alpha = set_foam_alpha,
		set_subsurface_color = set_subsurface_color,
		set_roughness = set_roughness,
		get_material = function() return deep_copy(state.material) end,
		get_water_color = function() return deep_copy(state.material.water_color) end,
		get_water_alpha = function() return state.material.alpha end,
		get_foam_color = function() return deep_copy(state.material.foam_color) end,
		get_foam_alpha = function() return state.material.foam_alpha end,
		get_subsurface_color = function() return deep_copy(state.material.subsurface_color) end,
		get_roughness = function() return state.material.roughness end,

		set_gravity = set_gravity,
		set_default_gravity = set_default_gravity,
		get_gravity = get_gravity,
		get_default_gravity = function() return G end,

		set_wave_resolution = set_wave_resolution,
		get_wave_resolution = function() return state.wave_resolution end,

		set_cascade_tile_length = set_cascade_tile_length,
		set_cascade_displacement_scale = set_cascade_displacement_scale,
		set_cascade_normal_scale = set_cascade_normal_scale,
		set_cascade_wind_speed = set_cascade_wind_speed,
		set_cascade_wind_direction = set_cascade_wind_direction,
		set_cascade_fetch_length = set_cascade_fetch_length,
		set_cascade_swell = set_cascade_swell,
		set_cascade_spread = set_cascade_spread,
		set_cascade_detail = set_cascade_detail,
		set_cascade_whitecap = set_cascade_whitecap,
		set_cascade_foam_amount = set_cascade_foam_amount,

		get_cascades = function() return deep_copy(state.cascades) end,
		get_cascade_tile_size = function(cascade_index) return state.cascades[cascade_index].tile_length end,
		get_cascade_displacement_scale = function(cascade_index) return state.cascades[cascade_index].displacement_scale end,
		get_cascade_normal_scale = function(cascade_index) return state.cascades[cascade_index].normal_scale end,
		get_cascade_wind_speed = function(cascade_index) return state.cascades[cascade_index].wind_speed end,
		get_cascade_wind_direction = function(cascade_index) return state.cascades[cascade_index].wind_direction end,
		get_cascade_fetch_length = function(cascade_index) return state.cascades[cascade_index].fetch_length_km end,
		get_cascade_swell = function(cascade_index) return state.cascades[cascade_index].swell end,
		get_cascade_spread = function(cascade_index) return state.cascades[cascade_index].spread end,
		get_cascade_detail = function(cascade_index) return state.cascades[cascade_index].detail end,
		get_cascade_whitecap = function(cascade_index) return state.cascades[cascade_index].whitecap end,
		get_cascade_foam_amount = function(cascade_index) return state.cascades[cascade_index].foam_amount end,

		set_debug_enable_displacement = set_debug_enable_displacement,
		set_debug_primitive_mode = set_debug_primitive_mode,
		set_debug_coloring = set_debug_coloring,
		get_debug = function() return deep_copy(state.debug) end,
		get_debug_coloring = function() return state.debug.coloring end,
	}

	WG['oceanwaves'] = api

	function widget:TextCommand(message)
		-- Spring.Echo('test', message)
		text_command(api, message)
	end

	widgetHandler:UpdateCallIn('TextCommand')

	function api:Delete()
		WG['oceanwaves'] = nil
	end
	return api
end
return API