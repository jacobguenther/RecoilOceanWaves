-- File: ui/ocean_settings.lua

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

local atan2 = math.atan2
local rad_to_deg = math.deg

function ui_minimize()
	ui.dm_handle.should_minimize = not ui.dm_handle.should_minimize
end
function ui_toggle_hidden()
	if ui.dm_handle.hidden then
		ui.dm_handle.hidden = false
		ui.document:Hide()
	else
		ui.dm_handle.hidden = true
		ui.document:Show()
	end
end

function ui_minimize_section(event, name)
	if name == "material" then
		ui.dm_handle.material_visible = not ui.dm_handle.material_visible
	elseif name == "wind" then
		ui.dm_handle.wind_visible = not ui.dm_handle.wind_visible
	elseif name == "wave" then
		ui.dm_handle.wave_visible = not ui.dm_handle.wave_visible
	elseif name == "debug" then
		ui.dm_handle.debug_visible = not ui.dm_handle.debug_visible
	elseif name == "gravity" then
		ui.dm_handle.gravity_visible = not ui.dm_handle.gravity_visible
	end
end

function ui_change_wave_resolution(event)
	local value = tonumber(event.parameters.value)
	if value == nil then
		return
	end
	rebuild_pipeline(value)
end

function ui_material_change(event, id, part)
	local value = tonumber(event.parameters.value)
	if value == nil then
		return
	end
	if part == nil then
		ui.dm.material[id] = value
	else
		ui.dm.material[id][part] = value
	end
	ui.dm.material.update_material = true
end
function ui_update_map_wind()
	local wind_speed_x, _, wind_speed_z, wind_strength, wind_dir_x, _, wind_dir_z = Spring.GetWind()
	local angle = 0
	-- local angle = rad_to_deg(atan2(wind_dir_z, wind_dir_x)) + 90
	ui.dm_handle.map_wind_speed_x = wind_speed_x
	ui.dm_handle.map_wind_speed_z = wind_speed_z
	ui.dm_handle.map_wind_strength = wind_strength
	ui.dm_handle.map_wind_dir_x = wind_dir_x
	ui.dm_handle.map_wind_dir_z = wind_dir_z
	ui.dm_handle.map_wind_angle = angle
end

function ui_select_cascade(event, e)
	ui.dm_handle.selected_cascade = e
end
function ui_cascade_change_tile_size(event, cascade_id)
	local tile_length = tonumber(event.parameters.value)
	if type(tile_length) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].tile_length = tile_length
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_displacement_scale(event, cascade_id)
	local displacement_scale = tonumber(event.parameters.value)
	if type(displacement_scale) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].displacement_scale = displacement_scale
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_normal_scale(event, cascade_id)
	local normal_scale = tonumber(event.parameters.value)
	if type(normal_scale) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].normal_scale = normal_scale
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_wind_speed(event, cascade_id)
	local wind_speed = tonumber(event.parameters.value)
	if type(wind_speed) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].wind_speed = wind_speed
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_wind_direction(event, cascade_id)
	local wind_direction = tonumber(event.parameters.value)
	if type(wind_direction) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].wind_direction = wind_direction
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_fetch_length(event, cascade_id)
	local fetch_length_km = tonumber(event.parameters.value)
	if type(fetch_length_km) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].fetch_length_km = fetch_length_km
	ui.dm.cascades[cascade_id].fetch_length_m = fetch_length_km*1e3
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_swell(event, cascade_id)
	local swell = tonumber(event.parameters.value)
	if type(swell) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].swell = swell
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_spread(event, cascade_id)
	local spread = tonumber(event.parameters.value)
	if type(spread) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].spread = spread
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_detail(event, cascade_id)
	local detail = tonumber(event.parameters.value)
	if type(detail) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].detail = detail
	ui.dm.cascades[cascade_id].should_generate_spectrum = true
end
function ui_cascade_change_whitecap(event, cascade_id)
	local whitecap = tonumber(event.parameters.value)
	if type(whitecap) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].whitecap = whitecap
end
function ui_cascade_change_foam_amount(event, cascade_id)
	local foam_amount = tonumber(event.parameters.value)
	if type(foam_amount) ~= "number" then
		return
	end
	ui.dm.cascades[cascade_id].foam_amount = foam_amount
end

function ui_debug_change_displacement(event)
	ui.dm_handle.debug.disable_displacement = event.parameters.value == "on"
	rebuild_pipeline()
end

function ui_debug_set_primitive_mode(event)
	set_primitive_mode(event.parameters.value)
end

function ui_debug_coloring(event, select_id)
	local value = event.parameters.value;
	if value == "none" or value == "lod" or value == "clipmap" or value == "depth" then
		ui.dm_handle.debug.coloring = value
		rebuild_pipeline()
	elseif value == "displacement" or value == "normal" or value == "spectrum" then
		local selection = ui.document:GetElementById(select_id):GetAttribute("value")
		ui.dm_handle.debug.coloring = value
		ui.dm_handle.debug.texture = tonumber(selection)
		rebuild_pipeline()
	end
end
function ui_debug_update_texture_index(event, for_texture)
	if ui.dm_handle.debug.coloring == for_texture then
		ui.dm_handle.debug.texture = tonumber(event.parameters.value)
		rebuild_pipeline()
	end
end

function ui_override_gravity(event, gravity_value_id)
	Spring.Echo("ui_override_gravity", event.parameters.value)
	if event.parameters.value == "on" then
		local value = ui.document:GetElementById(gravity_value_id):GetAttribute("value")
		Spring.Echo("ui_override_gravity", value)
		local override = tonumber(value)
		if override then
			set_gravity(override)
			rebuild_pipeline()
		end
	else
		default_gravity()
		rebuild_pipeline()
	end
end
function set_gravity_override_value(event)
	local checked = ui.document:GetElementById("gravity_override"):GetAttribute("checked")
	if checked ~= nil then
		local override = tonumber(event.parameters.value)
		if type(override) ~= "number" then
			return
		end
		set_gravity(override)
		rebuild_pipeline()
	end
end

local UI = {}
function UI:new(data_model_cascades, material, debug, wave_resolution)
	local context_name = widget.whInfo.name
	widget.rmlContext = RmlUi.CreateContext(context_name)

	local default_gravity, _ = get_gravity()

	local dm = {
		ui_minimize = ui_minimize,
		ui_toggle_hidden = ui_toggle_hidden,
		ui_minimize_section = ui_minimize_section,

		ui_material_change = ui_material_change,

		ui_override_gravity = ui_override_gravity,
		set_gravity_override_value = set_gravity_override_value,

		ui_change_wave_resolution = ui_change_wave_resolution,
		ui_select_cascade = ui_select_cascade,

		ui_cascade_change_tile_size = ui_cascade_change_tile_size,
		ui_cascade_change_displacement_scale = ui_cascade_change_displacement_scale,
		ui_cascade_change_normal_scale = ui_cascade_change_normal_scale,
		ui_cascade_change_wind_speed = ui_cascade_change_wind_speed,
		ui_cascade_change_wind_direction = ui_cascade_change_wind_direction,
		ui_cascade_change_fetch_length = ui_cascade_change_fetch_length,
		ui_cascade_change_swell = ui_cascade_change_swell,
		ui_cascade_change_spread = ui_cascade_change_spread,
		ui_cascade_change_detail = ui_cascade_change_detail,
		ui_cascade_change_whitecap = ui_cascade_change_whitecap,
		ui_cascade_change_foam_amount = ui_cascade_change_foam_amount,

		ui_debug_change_displacement = ui_debug_change_displacement,
		ui_debug_set_primitive_mode = ui_debug_set_primitive_mode,
		ui_debug_coloring = ui_debug_coloring,
		ui_debug_update_texture_index = ui_debug_update_texture_index,

		wave_resolution = wave_resolution,

		min_wind = Game.windMin,
		max_wind = Game.windMax,

		map_wind_speed_x = 0,
		map_wind_speed_z = 0,
		map_wind_strength = 0,

		map_wind_dir_x = 0,
		map_wind_dir_z = 0,
		map_wind_angle = 0,

		map_gravity = Game.gravity,
		default_gravity = default_gravity,

		selected_cascade = 1,
		cascades = data_model_cascades,
		material = material,
		debug = debug,

		should_minimize = 1,
		hidden = 1,
		-- collapsable sections
		-- used in ui_minimize_section
		material_visible = 0,
		wind_visible = 0,
		gravity_visible = 1,
		wave_visible = 0,
		debug_visible = 1,
	}

	local dm_name = "ocean_waves_dm"
	local dm_handle = widget.rmlContext:OpenDataModel(dm_name, dm)
	if not dm_handle then
		Spring.Echo("RmlUi: Failed to open data model ", dm_name)
		return
	end

	local this = {
		context_name = context_name,
		dm_name = dm_name,
		dm_handle = dm_handle,
		document = nil,
		dm = dm,
	}
	function this:Init()
		local document = widget.rmlContext:LoadDocument("LuaUI/Widgets/ui/ocean_settings.rml", widget)
		if not document then
			Spring.Echo("Failed to load document")
			return
		end
		this.document = document
		this.document:ReloadStyleSheet()
		this.document:Show()
	end
	function this:delete()
		widget.rmlContext:RemoveDataModel(this.dm_name)
		if document then
			document:Close()
		end
		if widget.rmlContext then
			RmlUi.RemoveContext(this.context_name)
		end
	end

	return this
end

return UI