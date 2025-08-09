-- File: ocean_waves_menu.lua

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

function widget:GetInfo()
	return {
		name    = 'Ocean Waves Menu',
		desc    = '',
		author  = 'chmod777',
		date    = 'August 2025',
		license = 'GNU AGPLv3',
		layer   = 0,
		enabled = true,
	}
end


local GetWind = Spring.GetWind
local atan2 = math.atan2
local deg = math.deg

local context = nil
local document = nil
local dm = nil
local dm_name = nil -- widget.whInfo.name

local hidden = false

local squash_first_texture_filtering_update = true
local squash_first_mesh_size_update = true
local squash_first_grid_count_update = true
local squash_first_wave_res_update = true
local squash_first_primitive_mode_update = true

local chobbyInterface = false

function widget:Initialize()
	context = RmlUi.GetContext("shared")

	local data_model = {
		reload_stylesheets = function() document:ReloadStyleSheet() end,

		hidden_toggle = hidden_toggle,

		document_maximized = true,
		minimize_toggle = minimize_toggle,

		material_visible = true,
		mesh_visible = true,
		wind_visible = false,
		gravity_visible = false,
		wave_visible = false,
		debug_visible = false,
		minimize_section_toggle = minimize_section_toggle,

		material = WG['oceanwaves'].get_material(),
		on_material_change = on_material_change,
		on_texture_filtering_mode = on_texture_filtering_mode,

		mesh = WG['oceanwaves'].get_mesh_settings(),
		on_mesh_size_change = on_mesh_size_change,
		on_mesh_grid_count_change = on_mesh_grid_count_change,

		min_wind = Game.windMin,
		max_wind = Game.windMax,
		map_wind_speed_x = 0,
		map_wind_speed_z = 0,
		map_wind_strength = 0,
		map_wind_dir_x = 0,
		map_wind_dir_z = 0,
		map_wind_angle = 0,

		map_gravity = Game.gravity,
		default_gravity = WG["oceanwaves"].get_default_gravity(),
		on_override_gravity = on_override_gravity,
		on_gravity_override_value = on_gravity_override_value,

		wave_resolution = WG["oceanwaves"].get_wave_resolution(),
		on_wave_resolution_change = on_wave_resolution_change,

		selected_cascade = 1,
		cascades = WG['oceanwaves'].get_cascades(),
		on_select_cascade = on_select_cascade,
		on_cascade_change_tile_size = on_cascade_change_tile_size,
		on_cascade_change_displacement_scale = on_cascade_change_displacement_scale,
		on_cascade_change_normal_scale = on_cascade_change_normal_scale,
		on_cascade_change_wind_speed = on_cascade_change_wind_speed,
		on_cascade_change_wind_direction = on_cascade_change_wind_direction,
		on_cascade_change_fetch_length = on_cascade_change_fetch_length,
		on_cascade_change_swell = on_cascade_change_swell,
		on_cascade_change_spread = on_cascade_change_spread,
		on_cascade_change_detail = on_cascade_change_detail,
		on_cascade_change_whitecap = on_cascade_change_whitecap,
		on_cascade_change_foam_amount = on_cascade_change_foam_amount,

		debug = WG["oceanwaves"].get_debug(),
		on_debug_change_displacement = on_debug_change_displacement,
		on_debug_set_primitive_mode = on_debug_set_primitive_mode,
		on_debug_coloring = on_debug_coloring,
		on_debug_update_texture_index = on_debug_update_texture_index,
	}
	dm_name = widget.whInfo.name
	dm = context:OpenDataModel(dm_name, data_model)

	document = context:LoadDocument("LuaUI/Widgets/ocean_waves/ui/ocean_waves_menu.rml", widget)
	document:ReloadStyleSheet()
	document:Show()
end

function widget:Shutdown()
	if document then
		document:Close()
	end
	if context then
		context:RemoveDataModel(dm_name)
	end
end

-- FIXME move this to GameFrame
function widget:Update(n)
	local wind_speed_x, _, wind_speed_z, wind_strength, wind_dir_x, _, wind_dir_z = GetWind()
	local angle = deg(atan2(-wind_dir_x, wind_dir_z))
	if angle < 0 then
		angle = angle + 360
	end
	dm.map_wind_speed_x = wind_speed_x
	dm.map_wind_speed_z = wind_speed_z
	dm.map_wind_strength = wind_strength
	dm.map_wind_dir_x = wind_dir_x
	dm.map_wind_dir_z = wind_dir_z
	dm.map_wind_angle = angle
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
		if chobbyInterface then
			document:Hide()
		else
			document:Show()
		end
	end
end

function validate_number(element)
	if not element.attributes.value then
		return handle_invalid_number(element)
	end
	local value = tonumber(element.attributes.value)
	if not value then
		return handle_invalid_number(element)
	end

	if element.attributes.min then
		local min_value = tonumber(element.attributes.min)
		if min_value and value < min_value then
			return handle_invalid_number(element)
		end
	end

	if element.attributes.max then
		local max_value = tonumber(element.attributes.max)
		if max_value and value > max_value then
			return handle_invalid_number(element)
		end
	end

	element:SetClass("input-error", false)
	return value
end
function handle_invalid_number(element)
	element:SetClass("input-error", true)
	return nil
end

function hidden_toggle(event)
	if not hidden then
		document:Hide()
		if event then
			event.current_element:Blur()
		end
	else
		document:Show()
	end
end
function minimize_toggle()
	dm.document_maximized = not dm.document_maximized
end
function minimize_section_toggle(event, section)
	if section == "material" then
		dm.material_visible = not dm.material_visible
	elseif section == "mesh" then
		dm.mesh_visible = not dm.mesh_visible
	elseif section == "wind" then
		dm.wind_visible = not dm.wind_visible
	elseif section == "wave" then
		dm.wave_visible = not dm.wave_visible
	elseif section == "debug" then
		dm.debug_visible = not dm.debug_visible
	elseif section == "gravity" then
		dm.gravity_visible = not dm.gravity_visible
	end
end

function on_material_change(event, id, part)
	local value = validate_number(event.current_element)
	if not value then
		return
	end
	if part == nil then
		if id == 'alpha' then
			WG['oceanwaves'].set_water_alpha(value)
		elseif id == 'foam_alpha' then
			WG['oceanwaves'].set_foam_alpha(value)
		elseif id == 'roughness' then
			WG['oceanwaves'].set_roughness(value)
		elseif id == 'foam_falloff_start' then
			WG['oceanwaves'].set_foam_falloff_start(value)
		elseif id == 'foam_falloff_distance' then
			WG['oceanwaves'].set_foam_falloff_range(value)
		elseif id == 'displacement_falloff_start' then
			WG['oceanwaves'].set_displacement_falloff_start(value)
		elseif id == 'displacement_falloff_distance' then
			WG['oceanwaves'].set_displacement_falloff_range(value)
		elseif id == 'lod_step_distance' then
			WG['oceanwaves'].set_lod_step_distance(value)
		end
	else
		local color = {}
		if id == 'water_color' then
			color = WG['oceanwaves'].get_water_color()
			color[part] = value
			WG['oceanwaves'].set_water_color(color.r, color.g, color.b)
		elseif id == 'foam_color' then
			color = WG['oceanwaves'].get_foam_color()
			color[part] = value
			WG['oceanwaves'].set_foam_color(color.r, color.g, color.b)
		elseif id == 'subsurface_color' then
			color = WG['oceanwaves'].get_subsurface_color()
			color[part] = value
			WG['oceanwaves'].set_subsurface_color(color.r, color.g, color.b)
		end
	end
end
function on_texture_filtering_mode(event)
	if squash_first_texture_filtering_update then
		squash_first_texture_filtering_update = false
		return
	end

	local value = event.parameters.value
	WG['oceanwaves'].set_texture_filtering(value)
end

function on_mesh_size_change(event)
	if squash_first_mesh_size_update then
		squash_first_mesh_size_update = false
		return
	end

	local value = tonumber(event.parameters.value)
	WG['oceanwaves'].set_mesh_size(value)
end
function on_mesh_grid_count_change(event)
	if squash_first_grid_count_update then
		squash_first_grid_count_update = false
		return
	end
	local value = tonumber(event.parameters.value)
	WG['oceanwaves'].set_mesh_grid_count(value)
end

function on_override_gravity(event, gravity_value_id)
	local override_value_element = document:GetElementById(gravity_value_id)
	local value = validate_number(override_value_element)
	if event.parameters.value == "on" then
		if value then
			WG["oceanwaves"].set_gravity(override)
		end
	else
		WG["oceanwaves"].set_default_gravity()
	end
end
function on_gravity_override_value(event)
	local checked = document:GetElementById("gravity_override"):GetAttribute("checked")
	local override = validate_number(event.current_element)
	if checked ~= nil and override then
		WG["oceanwaves"].set_gravity(override)
	end
end

function on_wave_resolution_change(event)
	if squash_first_wave_res_update then
		squash_first_wave_res_update = false
		return
	end

	local value = tonumber(event.parameters.value)
	WG['oceanwaves'].set_wave_resolution(value)
end

function on_select_cascade(event, i)
	dm.selected_cascade = i
end

function on_cascade_change_tile_size(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_tile_length(cascade_id, value)
	end
end
function on_cascade_change_displacement_scale(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_displacement_scale(cascade_id, value)
	end
end
function on_cascade_change_normal_scale(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_normal_scale(cascade_id, value)
	end
end
function on_cascade_change_wind_speed(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_wind_speed(cascade_id, value)
	end
end
function on_cascade_change_wind_direction(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_wind_direction(cascade_id, value)
	end
end
function on_cascade_change_fetch_length(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_fetch_length(cascade_id, value)
	end
end
function on_cascade_change_swell(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_swell(cascade_id, value)
	end
end
function on_cascade_change_spread(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_spread(cascade_id, value)
	end
end
function on_cascade_change_detail(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_detail(cascade_id, value)
	end
end
function on_cascade_change_whitecap(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_whitecap(cascade_id, value)
	end
end
function on_cascade_change_foam_amount(event, cascade_id)
	local value = validate_number(event.current_element)
	if value then
		WG['oceanwaves'].set_cascade_foam_amount(cascade_id, value)
	end
end

function on_debug_change_displacement(event)
	WG['oceanwaves'].set_debug_enable_displacement(event.parameters.value)
end

function on_debug_set_primitive_mode(event)
	if squash_first_primitive_mode_update then
		squash_first_primitive_mode_update = false
	end
	WG['oceanwaves'].set_debug_primitive_mode(event.parameters.value)
end

function on_debug_coloring(event, texture_index_elm_id)
	local coloring = event.parameters.value;
	local texture_index = nil
	if texture_index_elm_id then
		texture_index = document:GetElementById(texture_index_elm_id):GetAttribute("value")
	end
	WG['oceanwaves'].set_debug_coloring(coloring, texture_index)
end
function on_debug_update_texture_index(event, for_shading)
	local shading = WG['oceanwaves'].get_debug_coloring()
	if shading == for_shading then
		local texture_index = event.parameters.value
		WG['oceanwaves'].set_debug_coloring(shading, texture_index)
	end
end
