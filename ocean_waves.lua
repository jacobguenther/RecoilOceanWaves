-- File: ocean_waves.lua

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
		name    = 'Ocean Waves',
		desc    = '',
		author  = 'chmod777',
		date    = 'June 2025',
		license = 'GNU AGPLv3',
		layer   = 0,
		enabled = true,
	}
end

--[[ Changelog
* June 2025 Created
]]

local game_name = Spring.GetGameName()
local is_bar = game_name:find("^Beyond All Reason") ~= nil
local is_zero_k = game_name:find("^Zero") ~= nil
if not is_bar and not is_zero_k then
	Spring.Echo("Game "..game_name.." is not supported")
	return
end

local UI = nil
ui = nil
if is_bar then
	UI = VFS.Include("LuaUI/Widgets/ui/ocean_settings.lua")
end

local LuaShader
if is_bar then
	LuaShader = gl.LuaShader
elseif is_zero_k then
	luaShaderDir = "LuaUI/Widgets/Include/"
	LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
end

local G
local G2
function default_gravity()
	G = 9.80665 * Game.gravity / 100
	G2 = G*G
end
function set_gravity(new_gravity)
	G = new_gravity
	G2 = G*G
end
function get_gravity()
	return G, G2
end
default_gravity()

local log = math.log
local max = math.max
local deg_to_rad = math.rad
local pow = math.pow

local SetDrawWater = Spring.SetDrawWater
local GetWaterLevel = Spring.GetWaterLevel
local GetWaterPlaneLevel = Spring.GetWaterPlaneLevel
local GetGroundHeight = Spring.GetGroundHeight
local GetGroundOrigHeight = Spring.GetGroundOrigHeight

local GetWaterRendering = gl.GetWaterRendering
local GetMapRendering = gl.GetMapRendering

local glCreateShader = gl.CreateShader
local glDeleteShader = gl.DeleteShader
local glGetShaderLog = gl.GetShaderLog
local glUseShader = gl.UseShader
local glDispatchCompute = gl.DispatchCompute
local glGetUniformLocation = gl.GetUniformLocation
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt

local glGetVBO = gl.GetVBO
local glGetVAO = gl.GetVAO

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

local Texture = VFS.Include('LuaUI/Widgets/utilities/gl/texture.lua')
local glTexture = gl.Texture
-- format
local GL_RGBA16F = GL.RGBA16F
local GL_RGBA32F = GL.RGBA32F
-- access
local GL_READ_ONLY = GL.READ_ONLY
local GL_WRITE_ONLY = GL.WRITE_ONLY
local GL_READ_WRITE = GL.READ_WRITE

-- All things blending
local GL_DST_COLOR             = GL.DST_COLOR
local GL_ONE_MINUS_DST_COLOR   = GL.ONE_MINUS_DST_COLOR
local GL_SRC_ALPHA_SATURATE    = GL.SRC_ALPHA_SATURATE
local GL_FUNC_ADD              = GL.FUNC_ADD
local GL_FUNC_SUBTRACT         = GL.FUNC_SUBTRACT
local GL_FUNC_REVERSE_SUBTRACT = GL.FUNC_REVERSE_SUBTRACT
local GL_MIN                   = GL.MIN
local GL_MAX                   = GL.MAX

local GL_ZERO                  = GL.ZERO
local GL_ONE                   = GL.ONE
local GL_SRC_COLOR             = GL.SRC_COLOR
local GL_ONE_MINUS_SRC_COLOR   = GL.ONE_MINUS_SRC_COLOR
local GL_SRC_ALPHA             = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA   = GL.ONE_MINUS_SRC_ALPHA
local GL_DST_ALPHA             = GL.DST_ALPHA
local GL_ONE_MINUS_DST_ALPHA   = GL.ONE_MINUS_DST_ALPHA

local glBlending = gl.Blending
local glBlendFunc = gl.BlendFunc
local glBlendEquationSeparate = gl.BlendEquationSeparate
local glBlendFuncSeparate = gl.BlendFuncSeparate

local GL_NEVER    = GL.NEVER
local GL_LESS     = GL.LESS
local GL_EQUAL    = GL.EQUAL
local GL_LEQUAL   = GL.LEQUAL
local GL_GREATER  = GL.GREATER
local GL_NOTEQUAL = GL.NOTEQUAL
local GL_GEQUAL   = GL.GEQUAL
local GL_ALWAYS   = GL.ALWAYS

local glAlphaTest = gl.AlphaTest
local glAlphaToCoverage = gl.AlphaToCoverage

local ocean_waves_vert_path = 'LuaUI/Widgets/shaders/ocean_waves.vert.glsl'
local ocean_waves_frag_path = 'LuaUI/Widgets/shaders/ocean_waves.frag.glsl'
local ocean_waves_shader

local depth_comp_path = 'LuaUI/Widgets/shaders/compute/gen_depth.comp.glsl'
local butterfly_comp_path = 'LuaUI/Widgets/shaders/compute/fft_butterfly.comp.glsl'
local spectrum_comp_path = 'LuaUI/Widgets/shaders/compute/spectrum.comp.glsl'
local spectrum_modulate_comp_path = 'LuaUI/Widgets/shaders/compute/spectrum_modulate.comp.glsl'
local fft_comp_path = 'LuaUI/Widgets/shaders/compute/fft.comp.glsl'
local transpose_comp_path = 'LuaUI/Widgets/shaders/compute/transpose.comp.glsl'
local fft_unpack_comp_path = 'LuaUI/Widgets/shaders/compute/fft_unpack.comp.glsl'

local spectrum_comp
local butterfly_comp
local spectrum_modulate_comp
local fft_comp
local transpose_comp
local fft_unpack_comp

local shader_defines
-- FIXME
local spectrum_modulate_time_loc

local butterfly_factors_ssbo
local cascades_ssbo
local fft_ssbo

local depth_map
local spectrum_texture
local displacement_map
local normal_map

local Clip = VFS.Include('LuaUI/Widgets/utilities/gl/clipmap.lua')
local clipmap
local mesh_size = 1024
local mesh_grid_count = 1024

local update_butterfly = true
local update_spectrum = true
local should_create_depth_map = true
local depth_map_divider = 32

-- settings --

local map_size_x = Game.mapSizeX
local map_size_z = Game.mapSizeZ

local default_material = {
	water_color =      {r = 0.10, g = 0.15, b = 0.18},
	alpha = 0.35,

	foam_color =       {r = 0.73, g = 0.67, b = 0.62},
	foam_alpha = 0.7,

	subsurface_color = {r = 0.90, g = 1.15, b = 0.85},
	roughness = 0.65,

	metalness = 0.0,
	update_material = true
}

local default_cascades = {
	{
		tile_length = 997.0,
		displacement_scale = 1.0,
		normal_scale = 1.0,

		wind_speed = 8.0,
		wind_direction = 45,
		depth = 40.0,
		fetch_length_km = 200.0,
		fetch_length_m = nil,
		swell = 0.8,
		spread = 0.3,

		detail = 1.0,
		whitecap = 0.5,
		foam_amount = 4.0,
		foam_grow_rate = 1.0,
		foam_decay_rate = 1.0,

		should_generate_spectrum = true,
	},
	{
		tile_length = 751.0,
		displacement_scale = 1.0,
		normal_scale = 1.0,

		wind_speed = 6.0,
		wind_direction = 40,
		depth = 40.0,
		fetch_length_km = 150.0,
		fetch_length_m = nil,
		swell = 0.8,
		spread = 0.3,
		detail = 1.0,

		whitecap = 0.5,
		foam_amount = 4.0,
		foam_grow_rate = 1.0,
		foam_decay_rate = 1.0,

		should_generate_spectrum = true,
	},
	{
		tile_length = 293.0,
		displacement_scale = 1.0,
		normal_scale = 1.0,

		wind_speed = 6.0,
		wind_direction = 40,
		depth = 40.0,
		fetch_length_km = 150.0,
		fetch_length_m = nil,
		swell = 0.8,
		spread = 0.3,
		detail = 1.0,

		whitecap = 0.5,
		foam_amount = 4.0,
		foam_grow_rate = 1.0,
		foam_decay_rate = 1.0,

		should_generate_spectrum = true,
	},
}

local wave_resolution = 1024

local debug_settings_defaults = {
	disable_displacement = false,
	primitive_mode = "TRIANGLES", -- "TRIANGLES" | "LINES" | "POINTS"
	coloring = "none", -- "none" | "lod" | "clipmap" | "displacement" | "normal" | "spectrum" | "depth"
	texture_layer = 0,
}
-- end settings -- 

local NUM_SPECTRA = 4
local TRANSPOSE_TILE_SIZE = 32
local SPECTRUM_TILE_SIZE = 16
local SPECTRUM_MODULTE_TILE_SIZE = 16
local UNPACK_TILE_SIZE = 16

local num_fft_stages
local fft_size
local butterfly_size
local butterfly_dispatch_size
local spectrum_dispatch_size
local spectrum_modulate_dispatch_size
local transpose_dispatch_size
local unpack_dispatch_size

local time = 0

local current_cascade_index = 0
local cascades_std430

-- https://www.oreilly.com/library/view/opengl-programming-guide/9780132748445/app09lev1sec3.html
function as_cacades_std430(cascades)
	local std430 = {}
	for i=1, #cascades, 1 do
		local cascade = cascades[i]
		-- depends on wind_speed and fetch_length
		if cascade.fetch_length_m == nil then cascade.fetch_length_m = cascade.fetch_length_km * 1e3 end
		local alpha = 0.076 * pow((cascade.wind_speed * cascade.wind_speed) / (cascade.fetch_length_m * G), 0.22)
		local omega = 22.0 * pow(G2 / (cascade.wind_speed*cascade.fetch_length_m), 1.0/3.0)
		-- ivec2,vec2
		-- size and alignment are twice the size of the underlying scalar
		std430[#std430+1] = cascade.displacement_scale
		std430[#std430+1] = cascade.normal_scale
		-- scalar
		-- size and alignment are the underlying machine types
		-- eg., sizeof(GLfloat)
		std430[#std430+1] = cascade.tile_length
		std430[#std430+1] = alpha
		std430[#std430+1] = omega--peak_frequency
		std430[#std430+1] = cascade.wind_speed
		std430[#std430+1] = deg_to_rad(cascade.wind_direction)
		std430[#std430+1] = cascade.depth
		std430[#std430+1] = cascade.swell
		std430[#std430+1] = cascade.detail
		std430[#std430+1] = cascade.spread
		std430[#std430+1] = 0 -- time
		std430[#std430+1] = i-1+0.5
		-- FIXME
		local dt = 1.0 / 60.0
		std430[#std430+1] = cascade.whitecap
		std430[#std430+1] = dt * cascade.foam_amount * 7.5
		std430[#std430+1] = dt * max(0.5, 10.0 - cascade.foam_amount) * 1.5
		-- structure
		-- alignment is the alignment of the biggest structure (ivec2/vec2)
		-- padding
	end
	return std430
end

function widget:Initialize()
	SetDrawWater(false)

	clipmap = Clip.Clipmap:new(mesh_size, mesh_grid_count, 1)

	init_ui()

	init_pipeline_values()
	init_textures()
	init_buffers()
	init_shaders()
end
function init_ui()
	if is_bar then
		ui = UI:new(
			default_cascades,
			default_material,
			debug_settings_defaults,
			wave_resolution
		)
		ui:Init()
	else -- Hacks!
		ui = {
			dm = {
				cascades = default_cascades,
				material = default_material,
				debug = debug_settings_defaults,
			},
			dm_handle = {
				cascades = default_cascades,
				material = default_material,
				debug = debug_settings_defaults,
			},
		}
	end
end
function widget:TextCommand(message)
	local match = message:gmatch("%w+")
	if match() == "oceanwaves" then
		local command = match()
		if command == "ui" and is_bar then
			ui_toggle_hidden()
		end
	end
end
function init_pipeline_values()
	num_fft_stages = log(wave_resolution) / log(2)
	fft_size = wave_resolution*wave_resolution*4*2*#default_cascades
	butterfly_size = wave_resolution*num_fft_stages*#default_cascades

	butterfly_dispatch_size = wave_resolution/2/64
	spectrum_dispatch_size = wave_resolution / SPECTRUM_TILE_SIZE
	spectrum_modulate_dispatch_size = wave_resolution / SPECTRUM_MODULTE_TILE_SIZE
	transpose_dispatch_size = wave_resolution / TRANSPOSE_TILE_SIZE
	unpack_dispatch_size = wave_resolution / UNPACK_TILE_SIZE

	update_butterfly = true
	update_spectrum = true
	should_create_depth_map = true

	ui.dm.material.update_material = true
	for i=1,#ui.dm.cascades do
		ui.dm.cascades[i].should_generate_spectrum = true
	end
end
function rebuild_pipeline(new_wave_resolution)
	if wave_resolution == new_wave_resolution then
		return
	end
	if new_wave_resolution ~= nil then
		wave_resolution = new_wave_resolution
	end

	delete_buffers()
	delete_textures()
	delete_shaders()

	init_pipeline_values()

	init_textures()
	init_buffers()
	init_shaders()
end
function set_primitive_mode(mode)
	if mode == "TRIANGLES" then
		clipmap:SetPrimitiveMode(GL_TRIANGLES)
	elseif mode == "LINES" then
		clipmap:SetPrimitiveMode(GL_LINES)
	elseif mode == "POINTS" then
		clipmap:SetPrimitiveMode(GL_POINTS)
	end
end

function create_depth_map()
	local water_level = Spring.GetWaterLevel(0, 0)
	-- water_level = GetWaterPlaneLevel(0, 0)
	local max_depth = water_level

	local depth_data = {}
	for x=0, map_size_x-1, depth_map_divider do
		for z=0, map_size_z-1, depth_map_divider do
			local height = GetGroundHeight(x, z)
			if height < max_depth then max_depth = height end
			depth_data[#depth_data+1] = height
			depth_data[#depth_data+1] = 0
			depth_data[#depth_data+1] = 0
			depth_data[#depth_data+1] = 0
		end
	end

	local depth_ssbo = glGetVBO(GL_ARRAY_BUFFER, true)
	depth_ssbo:Define(#depth_data, {
		{id=0, name="depths", type=GL_FLOAT, size=4}
	})
	depth_ssbo:Upload(depth_data)

	local engine_uniform_buffer_defs = LuaShader.GetEngineUniformBufferDefs()
	local depth_shader_defines = shader_defines..
		"#define WATER_LEVEL ".."0.0".."\n"..
		"#define MAX_DEPTH "..max_depth.."\n"..
		engine_uniform_buffer_defs
	local depth_comp = compile_compute_shader(depth_comp_path, depth_shader_defines)

	depth_ssbo:BindBufferRange(5, 0, #depth_data, GL_SHADER_STORAGE_BUFFER)
	depth_map:bind_image()

	glUseShader(depth_comp)
	glDispatchCompute(map_size_x/depth_map_divider, map_size_z/depth_map_divider, 1, GL_ALL_BARRIER_BITS)

	glDeleteShader(depth_comp)
	depth_ssbo:Delete()
	should_create_depth_map = false
end
function init_shaders()
	local engine_uniform_buffer_defs = LuaShader.GetEngineUniformBufferDefs()
	shader_defines = "#define SPECTRUM_FORMAT_QUALIFIER "..spectrum_texture:format_as_qualifier().."\n"..
		"#define SPECTRUM_BINDING "..spectrum_texture.default_unit.."\n"..

		"#define DISPLACEMENT_FORMAT_QUALIFIER "..displacement_map:format_as_qualifier().."\n"..
		"#define DISPLACEMENT_MAP_BINDING "..displacement_map.default_unit.."\n"..

		"#define NORMAL_FORMAT_QUALIFIER "..normal_map:format_as_qualifier().."\n"..
		"#define NORMAL_MAP_BINDING "..normal_map.default_unit.."\n"..

		"#define DEPTH_FORMAT_QUALIFIER "..depth_map:format_as_qualifier().."\n"..
		"#define DEPTH_MAP_BINDING "..depth_map.default_unit.."\n"..

		"#define WAVE_RES ("..wave_resolution..")\n"..
		"#define NUM_CASCADES ("..#default_cascades..")\n"..
		"#define NUM_SPECTRA (4)\n"..

		"#define TRANSPOSE_TILE_SIZE ("..TRANSPOSE_TILE_SIZE..")\n"..
		"#define SPECTRUM_TILE_SIZE ("..SPECTRUM_TILE_SIZE..")\n"..
		"#define SPECTRUM_MODULTE_TILE_SIZE ("..SPECTRUM_MODULTE_TILE_SIZE..")\n"..
		"#define UNPACK_TILE_SIZE ("..UNPACK_TILE_SIZE..")\n"..

		"#define G (9.80665)\n"..
		"#define PI (3.1415926535897932384626433832795)\n"..
		"#define EPSILON32 (1e-5)\n"..

		-- "#define DEBUG_COLOR_CLIPMAP\n"..
		-- "#define DEBUG_COLOR_TEXTURE_DEPTH\n"..
		-- "#define DEBUG_COLOR_TEXTURE_NORMAL ".. 3 .."\n"..

		"#define MESH_SIZE "..mesh_size.."\n"

	if ui.dm_handle.debug.disable_displacement then
		shader_defines = shader_defines..
			"#define DEBUG_DISABLE_DISPLACEMENT\n"
	end

	local coloring = ui.dm_handle.debug.coloring
	local texture = ui.dm_handle.debug.texture
	-- if coloring == "lod" then
	-- end
	if coloring == "clipmap" then
		shader_defines = shader_defines..
			"#define DEBUG_COLOR_CLIPMAP\n"
	elseif coloring == "displacement" then
		shader_defines = shader_defines..
			"#define DEBUG_COLOR_TEXTURE_DISPLACEMENT "..texture.."\n"
	elseif coloring == "normal" then
		shader_defines = shader_defines..
			"#define DEBUG_COLOR_TEXTURE_NORMAL "..texture.."\n"
	elseif coloring == "depth" then
		shader_defines = shader_defines..
			"#define DEBUG_COLOR_TEXTURE_DEPTH\n"
	end

	local ocean_waves_vert_src = VFS.LoadFile(ocean_waves_vert_path, VFS.RAW)
	local ocean_waves_frag_src = VFS.LoadFile(ocean_waves_frag_path, VFS.RAW)
	ocean_waves_vert_src = ocean_waves_vert_src:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engine_uniform_buffer_defs)
	ocean_waves_frag_src = ocean_waves_frag_src:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engine_uniform_buffer_defs)
	ocean_waves_vert_src = ocean_waves_vert_src:gsub("//__Defines__", shader_defines)
	ocean_waves_frag_src = ocean_waves_frag_src:gsub("//__Defines__", shader_defines)
	ocean_waves_shader = LuaShader({
		vertex = ocean_waves_vert_src,
		fragment = ocean_waves_frag_src,
	}, 'Ocean Waves Shader')
	local ocean_waves_compiled = ocean_waves_shader:Initialize()
	if not ocean_waves_compiled then
		Spring.Echo('Ocean Waves Shader: Compilation Failed')
		widgetHandler:RemoveWidget()
	end
	ui.dm.material.update_material = true

	butterfly_comp = compile_compute_shader(butterfly_comp_path, shader_defines)
	spectrum_comp = compile_compute_shader(spectrum_comp_path, shader_defines)
	spectrum_modulate_comp = compile_compute_shader(spectrum_modulate_comp_path, shader_defines)
	fft_comp = compile_compute_shader(fft_comp_path, shader_defines)
	transpose_comp = compile_compute_shader(transpose_comp_path, shader_defines)
	fft_unpack_comp = compile_compute_shader(fft_unpack_comp_path, shader_defines)

	spectrum_modulate_time_loc = glGetUniformLocation(spectrum_modulate_comp, 'time')
end
function compile_compute_shader(path, custom_defines)
	local compute_shader_src = VFS.LoadFile(path, VFS.RAW)
	compute_shader_src = compute_shader_src:gsub("//__Defines__", custom_defines)
	local compute_shader = glCreateShader({
		compute = compute_shader_src,
	})
	if (compute_shader == nil) then
		Spring.Echo('Ocean Waves: '..path.." Compilation Failed"..glGetShaderLog())
		widgetHandler:RemoveWidget()
	end
	return compute_shader
end
function init_textures()
	spectrum_texture = Texture:new('spectrum', { x=wave_resolution, y=wave_resolution, z=#default_cascades}, 0, GL_RGBA16F)
	displacement_map = Texture:new('displacement_map', {x=wave_resolution, y=wave_resolution, z=#default_cascades}, 1, GL_RGBA16F)
	normal_map = Texture:new('normal_map', {x=wave_resolution, y=wave_resolution, z=#default_cascades}, 2, GL_RGBA16F)
	depth_map = Texture:new('depth_map', {x=map_size_x/depth_map_divider, y=map_size_z/depth_map_divider, z=1}, 3, GL_RGBA16F)
end
local cascade_size = 16
function init_buffers()
	butterfly_factors_ssbo = glGetVBO(GL_ARRAY_BUFFER, true)
	butterfly_factors_ssbo:Define(butterfly_size, {
		{id=0, name="butterfly_factors", type=GL_FLOAT, size=4}
	})

	cascades_ssbo = glGetVBO(GL_ARRAY_BUFFER, true)
	cascades_ssbo:Define(cascade_size*#default_cascades, {
		{id=0, name="cascades", type=GL_FLOAT, size=1}
	})
	cascades_std430 = as_cacades_std430(default_cascades)
	cascades_ssbo:Upload(cascades_std430)

	fft_ssbo = glGetVBO(GL_ARRAY_BUFFER, true)
	fft_ssbo:Define(fft_size, {
		{id=0, name="data", type=GL_FLOAT, size=2}
	})

	update_butterfly = true
	update_spectrum = true
end
function widget:Shutdown()
	if ui.delete then ui:delete() end
	if clipmap ~= nil then clipmap:Delete() end
	delete_buffers()
	delete_textures()
	delete_shaders()
	SetDrawWater(true)
end
function widget:Reload(event)
	widget:Shutdown()
	widget:Initialize()
end

function widget:GameFrame()
	if is_bar then
		ui_update_map_wind()
	end
end

local chobbyInterface = false
function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
		if is_bar then
			if chobbyInterface then
				ui.document:Hide()
			else
				ui.document:Show()
			end
		end
	end
end

function widget:Update(dt)
	time = time + dt
end

-- TODO only necessary barrier bits
function widget:DrawGenesis()
	if chobbyInterface then return end

	if should_create_depth_map then
		create_depth_map()
	end

	if current_cascade_index == 0 then
		current_cascade_index = #default_cascades-1
	else
		current_cascade_index = current_cascade_index - 1
	end
	local current_cascade = ui.dm.cascades[current_cascade_index+1]
	
	cascades_std430 = as_cacades_std430(ui.dm.cascades)
	cascades_ssbo:Upload(cascades_std430)

	butterfly_factors_ssbo:BindBufferRange(5, 0, butterfly_size, GL_SHADER_STORAGE_BUFFER)
	fft_ssbo:BindBufferRange(7, 0, fft_size, GL_SHADER_STORAGE_BUFFER)

	spectrum_texture:bind_image()
	displacement_map:bind_image()
	normal_map:bind_image()

	if update_butterfly then
		glUseShader(butterfly_comp)
		glDispatchCompute(butterfly_dispatch_size, num_fft_stages, 1, GL_ALL_BARRIER_BITS)
		update_butterfly = false
	end

	if current_cascade.should_generate_spectrum then
		cascades_ssbo:BindBufferRange(6, 0, cascade_size*#default_cascades, GL_SHADER_STORAGE_BUFFER)
		glUseShader(spectrum_comp)
		glDispatchCompute(spectrum_dispatch_size, spectrum_dispatch_size, #default_cascades, GL_ALL_BARRIER_BITS)
		for i=1, #default_cascades do
			ui.dm.cascades[i].should_generate_spectrum = false
		end
	end

	cascades_ssbo:BindBufferRange(6, current_cascade_index*cascade_size, cascade_size, GL_SHADER_STORAGE_BUFFER)

	glUseShader(spectrum_modulate_comp)
	glUniform(spectrum_modulate_time_loc, time)
	glDispatchCompute(
		spectrum_modulate_dispatch_size, spectrum_modulate_dispatch_size, 1,
		GL_ALL_BARRIER_BITS)

	glUseShader(fft_comp)
	glDispatchCompute(1, wave_resolution, NUM_SPECTRA, GL_ALL_BARRIER_BITS)

	glUseShader(transpose_comp)
	glDispatchCompute(
		transpose_dispatch_size, transpose_dispatch_size, NUM_SPECTRA,
		GL_ALL_BARRIER_BITS)

	glUseShader(fft_comp)
	glDispatchCompute(1, wave_resolution, NUM_SPECTRA, GL_ALL_BARRIER_BITS)

	glUseShader(fft_unpack_comp)
	glDispatchCompute(unpack_dispatch_size, unpack_dispatch_size, 1, GL_ALL_BARRIER_BITS)
end
function widget:DrawFeaturesPostDeferred() draw_water() end
function draw_water()
	cascades_ssbo:BindBufferRange(6, 0, cascade_size*#default_cascades, GL_SHADER_STORAGE_BUFFER)

	glBlending(true);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	ocean_waves_shader:Activate()
		displacement_map:use_texture()
		normal_map:use_texture()
		depth_map:use_texture()

		-- glTexture(3, 'modelmaterials_gl4/brdf_0.png') -- brdfLUT
		-- glTexture(4, 'LuaUI/images/noisetextures/noise64_cube_3.dds')
		-- glTexture(5, 'modelmaterials_gl4/envlut_0.png')
		if ui.dm.material.update_material then
			local material = ui.dm.material
			glUniform(7,
				material.water_color.r,
				material.water_color.g,
				material.water_color.b,
				material.alpha
			)
			glUniform(8,
				material.foam_color.r,
				material.foam_color.g,
				material.foam_color.b,
				material.foam_alpha
			)
			glUniform(9,
				material.subsurface_color.r,
				material.subsurface_color.g,
				material.subsurface_color.b,
				material.roughness
			)
			material.update_material = false
		end
		clipmap:Draw()
	ocean_waves_shader:Deactivate()

	glBlending(false)
end

-- Recull clipmap tiles, update lod levels
-- function widget:CameraPositionChanged(position) end
-- function widget:CameraRotationChanged(rotation) end
-- function widget:ViewResize(newX, newY) end

-- For unit foam/displacement
-- function widget:UnitEnteredWater(unitID, unitTeam, allyTeam, unitDefID) end
-- function widget:UnitLeftWater(unitID, unitTeam, allyTeam, unitDefID) end
-- function widget:UnitEnteredUnderwater(unitID, unitTeam, allyTeam, unitDefID) end
-- function widget:UnitLeftUnderwater(unitID, unitTeam, allyTeam, unitDefID) end

function delete_buffers()
	update_butterfly = false
	update_spectrum = false
	if butterfly_factors_ssbo ~= nil then butterfly_factors_ssbo:Delete() end
	if cascades_ssbo ~= nil then cascades_ssbo:Delete() end
	if fft_ssbo ~= nil then fft_ssbo:Delete() end
end
function delete_textures()
	if depth_map ~= nil then depth_map:delete() end
	if spectrum_texture ~= nil then spectrum_texture:delete() end
	if normal_map ~= nil then normal_map:delete() end
	if displacement_map ~= nil then displacement_map:delete() end
end
function delete_shaders()
	update_material = false
	if ocean_waves_shader ~= nil then ocean_waves_shader:Delete() end
	if butterfly_comp ~= nil then glDeleteShader(butterfly_comp) end
	if spectrum_comp ~= nil then glDeleteShader(spectrum_comp) end
	if spectrum_modulate_comp ~= nil then glDeleteShader(spectrum_modulate_comp) end
	if fft_comp ~= nil then glDeleteShader(fft_comp) end
	if transpose_comp ~= nil then glDeleteShader(transpose_comp) end
	if fft_unpack_comp ~= nil then glDeleteShader(fft_unpack_comp) end
end

