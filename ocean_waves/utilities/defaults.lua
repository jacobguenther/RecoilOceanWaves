-- File: utilities/defaults.lua

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

local defaults = {
	material = {
		water_color =      {r = 0.20, g = 0.30, b = 0.36},
		alpha = 0.35,

		foam_color =       {r = 0.73, g = 0.67, b = 0.62},
		foam_alpha = 0.7,
		foam_falloff_start = 2048,
		foam_falloff_distance = 8192,

		subsurface_color = {r = 0.90, g = 1.15, b = 0.85},
		roughness = 0.65,

		texture_filtering = "bilinear" -- "default" | "bilinear" | "bicubic"
	},
	mesh = {
		size = 1024,
		grid_count = 1024,
		lod_step_distance = 1024,
		displacement_falloff_start = 2048,
		displacement_falloff_distance = 4096,
	},
	wave_resolution = 1024,
	cascades = {
		{
			tile_length = 997.0,
			displacement_scale = 1.0,
			normal_scale = 1.0,

			wind_speed = 8.0,
			wind_direction = 45,
			fetch_length_km = 150.0,
			depth = 40.0,
			swell = 0.8,
			spread = 0.3,
			detail = 1.0,

			whitecap = 0.5,
			foam_amount = 4.0,
		},
		{
			tile_length = 751.0,
			displacement_scale = 1.0,
			normal_scale = 1.0,

			wind_speed = 6.0,
			wind_direction = 40,
			fetch_length_km = 150.0,
			depth = 40.0,
			swell = 0.8,
			spread = 0.3,
			detail = 1.0,

			whitecap = 0.5,
			foam_amount = 4.0,
		},
		{
			tile_length = 293.0,
			displacement_scale = 1.0,
			normal_scale = 1.0,

			wind_speed = 6.0,
			wind_direction = 40,
			fetch_length_km = 150.0,
			depth = 40.0,
			swell = 0.8,
			spread = 0.3,
			detail = 1.0,

			whitecap = 0.5,
			foam_amount = 4.0,
		},
	},
	debug = {
		disable_displacement = false, -- true | false
		primitive_mode = "TRIANGLES", -- "TRIANGLES" | "LINES" | "POINTS"
		coloring = "none", -- "none" | "lod" | "clipmap" | "displacement" | "normal" | "spectrum" | "depth"
		texture_layer = 0,
	}
}

return defaults