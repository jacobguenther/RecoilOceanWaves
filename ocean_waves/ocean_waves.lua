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

local widget_path = 'LuaUI/Widgets/ocean_waves/'

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
	UI = VFS.Include(widget_path .. "ui/ocean_settings.lua")
end

local API = VFS.Include(widget_path .. 'utilities/api.lua')
local api = nil

local LuaShader
if is_bar then
	LuaShader = gl.LuaShader
elseif is_zero_k then
	luaShaderDir = "LuaUI/Widgets/Include/"
	LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
end

local G = 9.80665
local G2 = G*G
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

-- we will call these speed ups --

local abs = math.abs
local log = math.log
local max = math.max
local deg_to_rad = math.rad
local pow = math.pow

local GetCameraPosition = Spring.GetCameraPosition
local GetCameraDirection = Spring.GetCameraDirection

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

local GL_TEXTURE_FETCH_BARRIER_BIT = GL.TEXTURE_FETCH_BARRIER_BIT
local GL_SHADER_IMAGE_ACCESS_BARRIER_BIT = GL.SHADER_IMAGE_ACCESS_BARRIER_BIT
local GL_TEXTURE_UPDATE_BARRIER_BIT = GL.TEXTURE_UPDATE_BARRIER_BIT
local GL_BUFFER_UPDATE_BARRIER_BIT = GL.BUFFER_UPDATE_BARRIER_BIT
local GL_SHADER_STORAGE_BARRIER_BIT = GL.SHADER_STORAGE_BARRIER_BIT
local GL_ALL_BARRIER_BITS = GL.ALL_BARRIER_BITS

local GL_BYTE = GL.BYTE
local GL_SHORT = GL.SHORT
local GL_INT = GL.INT
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

local Texture = VFS.Include(widget_path .. 'utilities/gl/texture.lua')
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

local ocean_waves_vert_path = widget_path .. 'shaders/ocean_waves.vert.glsl'
local ocean_waves_frag_path = widget_path .. 'shaders/ocean_waves.frag.glsl'
local ocean_waves_shader

local depth_comp_path = widget_path .. 'shaders/compute/gen_depth.comp.glsl'
local butterfly_comp_path = widget_path .. 'shaders/compute/fft_butterfly.comp.glsl'
local spectrum_comp_path = widget_path .. 'shaders/compute/spectrum.comp.glsl'
local spectrum_modulate_comp_path = widget_path .. 'shaders/compute/spectrum_modulate.comp.glsl'
local fft_comp_path = widget_path .. 'shaders/compute/fft.comp.glsl'
local transpose_comp_path = widget_path .. 'shaders/compute/transpose.comp.glsl'
local fft_unpack_comp_path = widget_path .. 'shaders/compute/fft_unpack.comp.glsl'
local cull_tiles_comp_path = widget_path .. 'shaders/compute/cull_tiles.comp.glsl'

local spectrum_comp
local butterfly_comp
local spectrum_modulate_comp
local fft_comp
local transpose_comp
local fft_unpack_comp
local cull_tiles_comp

local shader_defines
-- FIXME time is in the cascades (unused)
local spectrum_modulate_time_loc

local butterfly_factors_ssbo
local cascades_ssbo
local cascades_ubo
local fft_ssbo

local depth_map
local spectrum_texture
local displacement_map
local normal_map

local Clip = VFS.Include(widget_path .. 'utilities/gl/clipmap.lua')
local clipmap

local update_butterfly = true
local update_spectrum = true
local update_culling = true

local camera_pos_x, camera_pos_y, camera_pos_z = GetCameraPosition()
local camera_dir_x, camera_dir_y, camera_dir_z = GetCameraDirection()

local should_create_depth_map = true
local depth_map_divider = 32

-- settings --

local map_size_x = Game.mapSizeX
local map_size_z = Game.mapSizeZ

local mesh_size = 1024
local mesh_grid_count = 1024
local default_wave_resolution = 1024
local texture_filtering = "bilinear" -- "default" | "bilinear" | "bicubic"

local LOD_STEP = 1024
local DISPLACEMENT_FALLOFF_START = 2048
local DISPLACEMENT_FALLOFF_DIST = 4096
local DISPLACEMENT_FALLOFF_END = DISPLACEMENT_FALLOFF_START+DISPLACEMENT_FALLOFF_DIST

local FOAM_FALLOFF_START = 2048
local FOAM_FALLOFF_DIST = 4096
local FOAM_FALLOFF_END = FOAM_FALLOFF_START+FOAM_FALLOFF_DIST

local default_material = {
	water_color =      {r = 0.20, g = 0.30, b = 0.36},
	alpha = 0.35,

	foam_color =       {r = 0.73, g = 0.67, b = 0.62},
	foam_alpha = 0.7,

	subsurface_color = {r = 0.90, g = 1.15, b = 0.85},
	roughness = 0.65,

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
		swell = 0.8,
		spread = 0.3,

		detail = 1.0,
		whitecap = 0.5,
		foam_amount = 4.0,
		-- foam_grow_rate = 1.0,
		-- foam_decay_rate = 1.0,

		should_generate_spectrum = true,

		-- math cache
		wind_direction_rad = nil,
		wind_speed2 = nil,
		fetch_length_m = nil,
		fetch_length_G = nil,
		wind_fetch = nil,
		alpha = nil,
		omega = nil,
	},
	{
		tile_length = 751.0,
		displacement_scale = 1.0,
		normal_scale = 1.0,

		wind_speed = 6.0,
		wind_direction = 40,
		depth = 40.0,
		fetch_length_km = 150.0,
		swell = 0.8,
		spread = 0.3,
		detail = 1.0,

		whitecap = 0.5,
		foam_amount = 4.0,
		-- foam_grow_rate = 1.0,
		-- foam_decay_rate = 1.0,

		should_generate_spectrum = true,

		-- math cache
		wind_direction_rad = nil,
		wind_speed2 = nil,
		fetch_length_m = nil,
		fetch_length_G = nil,
		wind_fetch = nil,
		alpha = nil,
		omega = nil,
	},
	{
		tile_length = 293.0,
		displacement_scale = 1.0,
		normal_scale = 1.0,

		wind_speed = 6.0,
		wind_direction = 40,
		depth = 40.0,
		fetch_length_km = 150.0,
		swell = 0.8,
		spread = 0.3,
		detail = 1.0,

		whitecap = 0.5,
		foam_amount = 4.0,
		-- foam_grow_rate = 1.0,
		-- foam_decay_rate = 1.0,

		should_generate_spectrum = true,

		-- math cache
		wind_direction_rad = nil,
		wind_speed2 = nil,
		fetch_length_m = nil,
		fetch_length_G = nil,
		wind_fetch = nil,
		alpha = nil,
		omega = nil,
	},
}

local default_debug_settings = {
	disable_displacement = false, -- true | false
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

local isPaused = false
local time = 0
local last_dt = 0
local uploaded_dt = 0
local allowed_dt_error = 1.0 / (60.0 * 4)

local current_cascade_index = 0
local cascade_size = 16

-- https://www.oreilly.com/library/view/opengl-programming-guide/9780132748445/app09lev1sec3.html
function as_cacades_std430(cascades)
	local std430 = {}
	for i=1, #cascades do
		local cascade = cascades[i]
		std430[#std430+1] = cascade.displacement_scale
		std430[#std430+1] = cascade.normal_scale
		std430[#std430+1] = cascade.tile_length
		std430[#std430+1] = cascade.alpha
		std430[#std430+1] = cascade.omega
		std430[#std430+1] = cascade.wind_speed
		std430[#std430+1] = cascade.wind_direction_rad
		std430[#std430+1] = cascade.depth
		std430[#std430+1] = cascade.swell
		std430[#std430+1] = cascade.detail
		std430[#std430+1] = cascade.spread
		std430[#std430+1] = 0 -- time
		std430[#std430+1] = i-1+0.5
		-- FIXME

		-- local default_dt = 1.0 / 60.0
		-- local dt
		-- if last_dt != 0.0 then
		-- 	dt = default_dt
		-- else
		-- 	dt = last_dt
		-- end
		-- uploaded_dt = dt

		std430[#std430+1] = cascade.whitecap
		std430[#std430+1] = last_dt * cascade.foam_amount * 7.5
		std430[#std430+1] = last_dt * max(0.5, 10.0 - cascade.foam_amount) * 1.5
	end
	return std430
end

local state = {
	wave_resolution = default_wave_resolution,
	cascades = default_cascades,
	upload_cascades_ssbo = true,
	upload_cascades_ubo = true,

	material = default_material,
	debug = default_debug_settings,
}

function widget:Initialize()
	SetDrawWater(false)

	clipmap = Clip.Clipmap:new(mesh_size, mesh_grid_count, 1)

	init_cascades()

	init_pipeline_values()
	init_textures()
	init_buffers()
	init_shaders()

	api = API:Init(state)
	init_ui()
end

function init_cascades()
	for i=1, #state.cascades do
		local cascade = state.cascades[i]
		cascade.should_generate_spectrum = true
		cascade.wind_direction_rad = deg_to_rad(cascade.wind_direction)
		cascade.wind_speed2 = cascade.wind_speed * cascade.wind_speed
		cascade.fetch_length_m = cascade.fetch_length_km * 1e3
		cascade.fetch_length_G = cascade.fetch_length_m * G
		cascade.wind_fetch = cascade.wind_speed * cascade.fetch_length_m
		cascade.alpha = 0.076 * pow(cascade.wind_speed2 / cascade.fetch_length_G, 0.22)
		cascade.omega = 22.0 * pow(G2 / cascade.wind_fetch, 0.33333333)
	end
end

function init_ui()
	if is_bar then
		ui = UI:new(
			default_cascades,
			default_material,
			default_debug_settings,
			default_wave_resolution
		)
		ui:Init()
	end
end

function init_pipeline_values()
	local wave_resolution = state.wave_resolution
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

	state.material.update_material = true
	for i=1,#state.cascades do
		state.cascades[i].should_generate_spectrum = true
	end
end
function rebuild_pipeline()
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
	local water_level = GetWaterPlaneLevel()
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

	local depth_ssbo = glGetVBO(GL_ARRAY_BUFFER, false)
	depth_ssbo:Define(#depth_data, {
		{id=0, name="depths", type=GL_FLOAT, size=4}
	})
	depth_ssbo:Upload(depth_data)

	local depth_shader_defines = shader_defines..
		"#define WATER_LEVEL ".."0.0".."\n"..
		"#define MAX_DEPTH "..max_depth.."\n"
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

		"#define LOD_STEP ("..LOD_STEP..")\n"..
		"#define MIN_LOD_LEVEL (1)\n"..
		"#define MAX_LOD_LEVEL (10)\n"..

		"#define DISPLACEMENT_FALLOFF_START ("..DISPLACEMENT_FALLOFF_START..")\n"..
		"#define DISPLACEMENT_FALLOFF_DIST ("..DISPLACEMENT_FALLOFF_DIST..")\n"..
		"#define DISPLACEMENT_FALLOFF_END ("..DISPLACEMENT_FALLOFF_END..")\n"..

		"#define FOAM_FALLOFF_START ("..FOAM_FALLOFF_START..")\n"..
		"#define FOAM_FALLOFF_DIST ("..FOAM_FALLOFF_DIST..")\n"..
		"#define FOAM_FALLOFF_END ("..FOAM_FALLOFF_END..")\n"..

		"#define WAVE_RES ("..state.wave_resolution..")\n"..
		"#define NUM_CASCADES ("..#default_cascades..")\n"..
		"#define NUM_SPECTRA (4)\n"..

		"#define TRANSPOSE_TILE_SIZE ("..TRANSPOSE_TILE_SIZE..")\n"..
		"#define SPECTRUM_TILE_SIZE ("..SPECTRUM_TILE_SIZE..")\n"..
		"#define SPECTRUM_MODULTE_TILE_SIZE ("..SPECTRUM_MODULTE_TILE_SIZE..")\n"..
		"#define UNPACK_TILE_SIZE ("..UNPACK_TILE_SIZE..")\n"..

		"#define G ("..G..")\n"..
		"#define PI (3.1415926535897932384626433832795)\n"..
		"#define HALF_PI (1.57079632679)\n"..
		"#define SQRT2 (1.41421356237)\n"..
		"#define EPSILON32 (1e-5)\n"..

		"#define MESH_SIZE ("..mesh_size..")\n"..
		"#define CLIPMAP_TILE_COUNT ("..clipmap:GetTileCount()..")\n"..
		engine_uniform_buffer_defs

	if state.debug.disable_displacement then
		shader_defines = shader_defines.."#define DEBUG_DISABLE_DISPLACEMENT\n"
	end

	if texture_filtering == "default" then
		shader_defines = shader_defines.."#define TEXTURE_FILTERING_DEFAULT\n"
	elseif texture_filtering == "bilinear" then
		shader_defines = shader_defines.."#define TEXTURE_FILTERING_BILINEAR\n"
	elseif texture_filtering == "bicubic" then
		shader_defines = shader_defines.."#define TEXTURE_FILTERING_BICUBIC\n"
	end

	local coloring = state.debug.coloring
	local texture = state.debug.texture

	-- if coloring == "lod" then
	-- end
	if coloring == "clipmap" then
		shader_defines = shader_defines.."#define DEBUG_COLOR_CLIPMAP\n"
	elseif coloring == "displacement" then
		shader_defines = shader_defines.."#define DEBUG_COLOR_TEXTURE_DISPLACEMENT "..texture.."\n"
	elseif coloring == "normal" then
		shader_defines = shader_defines.."#define DEBUG_COLOR_TEXTURE_NORMAL "..texture.."\n"
	elseif coloring == "depth" then
		shader_defines = shader_defines.."#define DEBUG_COLOR_TEXTURE_DEPTH\n"
	end

	local ocean_waves_vert_src = VFS.LoadFile(ocean_waves_vert_path, VFS.RAW)
	local ocean_waves_frag_src = VFS.LoadFile(ocean_waves_frag_path, VFS.RAW)
	ocean_waves_vert_src = ocean_waves_vert_src:gsub("//__DEFINES__", shader_defines)
	ocean_waves_frag_src = ocean_waves_frag_src:gsub("//__DEFINES__", shader_defines)
	ocean_waves_shader = LuaShader({
		vertex = ocean_waves_vert_src,
		fragment = ocean_waves_frag_src,
	}, 'Ocean Waves Shader')
	local ocean_waves_compiled = ocean_waves_shader:Initialize()
	if not ocean_waves_compiled then
		Spring.Echo('Ocean Waves Shader: Compilation Failed')
		widgetHandler:RemoveWidget()
	end
	state.material.update_material = true

	butterfly_comp = compile_compute_shader(butterfly_comp_path, shader_defines)
	spectrum_comp = compile_compute_shader(spectrum_comp_path, shader_defines)
	spectrum_modulate_comp = compile_compute_shader(spectrum_modulate_comp_path, shader_defines)
	fft_comp = compile_compute_shader(fft_comp_path, shader_defines)
	transpose_comp = compile_compute_shader(transpose_comp_path, shader_defines)
	fft_unpack_comp = compile_compute_shader(fft_unpack_comp_path, shader_defines)

	cull_tiles_comp = compile_compute_shader(cull_tiles_comp_path, shader_defines)

	spectrum_modulate_time_loc = glGetUniformLocation(spectrum_modulate_comp, 'time')
end
function compile_compute_shader(path, custom_defines)
	local compute_shader_src = VFS.LoadFile(path, VFS.RAW)
	compute_shader_src = compute_shader_src:gsub("//__DEFINES__", custom_defines)
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
	local wave_resolution = state.wave_resolution
	spectrum_texture = Texture:new('spectrum', { x=wave_resolution, y=wave_resolution, z=#default_cascades}, 0, GL_RGBA16F)
	displacement_map = Texture:new('displacement_map', {x=wave_resolution, y=wave_resolution, z=#default_cascades}, 1, GL_RGBA16F)
	normal_map = Texture:new('normal_map', {x=wave_resolution, y=wave_resolution, z=#default_cascades}, 2, GL_RGBA16F)
	depth_map = Texture:new('depth_map', {x=map_size_x/depth_map_divider, y=map_size_z/depth_map_divider, z=1}, 3, GL_RGBA16F)
end
function init_buffers()
	butterfly_factors_ssbo = glGetVBO(GL_SHADER_STORAGE_BUFFER, false)
	butterfly_factors_ssbo:Define(butterfly_size/4, {
		{id=0, name="butterfly_factors", size=4}
	})

	cascades_ssbo = glGetVBO(GL_SHADER_STORAGE_BUFFER, false)
	cascades_ssbo:Define(#default_cascades, {
		{id=0, name="cascades", --[[ type=LuaVBOImpl::DEFAULT_BUFF_ATTR_TYPE vec4, ]] size=cascade_size/4}
	})
	cascades_ssbo:DumpDefinition()

	fft_ssbo = glGetVBO(GL_SHADER_STORAGE_BUFFER, false)
	fft_ssbo:Define(fft_size/2, {
		{id=0, name="data", size=1}
	})

	cascades_ubo = glGetVBO(GL_UNIFORM_BUFFER, false)
	cascades_ubo:Define(3, {
		{id=0, name="CascadeData", size=3}
	})

	update_butterfly = true
	state.upload_cascades_ssbo = true
	state.upload_cascades_ubo = true
	update_spectrum = true
	update_culling = true
end
function widget:Shutdown()
	if ui and ui.Delete then ui:Delete() end
	if api and api.Delete then api:Delete() end
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

function widget:Update(dt)
	if not isPaused then
		time = time + dt
		local diff = abs(dt - last_dt)
		last_dt = dt
		if abs(uploaded_dt - dt) > diff + allowed_dt_error then
			state.upload_cascades_ssbo = true
		end
	end

	local new_pos_x, new_pos_y, new_pos_z = GetCameraPosition()
	local new_dir_x, new_dir_y, new_dir_z = GetCameraDirection()
	update_culling =
		camera_pos_x ~= new_pos_x or camera_pos_y ~= new_pos_y or camera_pos_z ~= new_pos_z or
		camera_dir_x ~= new_dir_x or camera_dir_y ~= new_dir_y or camera_dir_z ~= new_dir_z
	if update_culling then
		camera_pos_x, camera_pos_y, camera_pos_z = new_pos_x, new_pos_y, new_pos_z
		camera_dir_x, camera_dir_y, camera_dir_z = new_dir_x, new_dir_y, new_dir_z
	end
end

function widget:GamePaused(playerID, isGamePaused)
	if isGamePaused then
		-- widgetHandler:RemoveCallIn("DrawGenesis")
		isPaused = true
	else
		-- widgetHandler:UpdateCallIn("DrawGenesis")
		isPaused = false
	end
end

function widget:DrawGenesis()
	if update_culling then
		clipmap:CullTiles(cull_tiles_comp)
		update_culling = false
	end
	if isPaused then
		return
	end
	if should_create_depth_map then
		create_depth_map()
	end

	butterfly_factors_ssbo:BindBufferRange(5, nil, nil, GL_SHADER_STORAGE_BUFFER)
	fft_ssbo:BindBufferRange(7, nil, nil, GL_SHADER_STORAGE_BUFFER)

	spectrum_texture:bind_image()
	displacement_map:bind_image()
	normal_map:bind_image()

	if update_butterfly then
		glUseShader(butterfly_comp)
		glDispatchCompute(butterfly_dispatch_size, num_fft_stages, 1, nil)
		update_butterfly = false
	end

	if current_cascade_index == 0 then
		current_cascade_index = #default_cascades-1
	else
		current_cascade_index = current_cascade_index - 1
	end
	local current_cascade = state.cascades[current_cascade_index+1]
	if state.upload_cascades_ssbo then
		local cascades_std430 = as_cacades_std430(state.cascades)
		cascades_ssbo:Upload(cascades_std430)
		state.upload_cascades_ssbo = false
	end

	if current_cascade.should_generate_spectrum then
		cascades_ssbo:BindBufferRange(6, nil, nil, GL_SHADER_STORAGE_BUFFER)
		glUseShader(spectrum_comp)
		glDispatchCompute(spectrum_dispatch_size, spectrum_dispatch_size, #default_cascades, nil)
		for i=1, #default_cascades do
			state.cascades[i].should_generate_spectrum = false
		end
	end

	cascades_ssbo:BindBufferRange(6, current_cascade_index, 1, GL_SHADER_STORAGE_BUFFER)

	glUseShader(spectrum_modulate_comp)
	glUniform(spectrum_modulate_time_loc, time)
	glDispatchCompute(spectrum_modulate_dispatch_size, spectrum_modulate_dispatch_size, 1, nil)

	glUseShader(fft_comp)
	glDispatchCompute(1, state.wave_resolution, NUM_SPECTRA, nil)

	glUseShader(transpose_comp)
	glDispatchCompute(transpose_dispatch_size, transpose_dispatch_size, NUM_SPECTRA, nil)

	glUseShader(fft_comp)
	glDispatchCompute(1, state.wave_resolution, NUM_SPECTRA, nil)

	glUseShader(fft_unpack_comp)
	glDispatchCompute(unpack_dispatch_size, unpack_dispatch_size, 1, nil)
end
function widget:DrawFeaturesPostDeferred() draw_water() end
function draw_water()
	glBlending(true);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

	ocean_waves_shader:Activate()
	-- cascades_ssbo:BindBufferRange(6, nil, nil, GL_SHADER_STORAGE_BUFFER)
	displacement_map:use_texture()
	normal_map:use_texture()
	depth_map:use_texture()

	-- glTexture(3, 'modelmaterials_gl4/brdf_0.png') -- brdfLUT
	-- glTexture(4, 'LuaUI/images/noisetextures/noise64_cube_3.dds')
	-- glTexture(5, 'modelmaterials_gl4/envlut_0.png')
	if state.material.update_material then
		local material = state.material
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

	if state.upload_cascades_ubo then
		local max_cascades = 4
		local cascade_uniform = {}
		for i=1, #state.cascades do
			cascade_uniform[#cascade_uniform+1] = state.cascades[i].displacement_scale
		end
		for i=1, (max_cascades)-#state.cascades do
			cascade_uniform[#cascade_uniform+1] = 0
		end

		for i=1, #state.cascades do
			cascade_uniform[#cascade_uniform+1] = state.cascades[i].normal_scale
		end
		for i=1, (max_cascades)-#state.cascades do
			cascade_uniform[#cascade_uniform+1] = 0
		end

		for i=1, #state.cascades do
			cascade_uniform[#cascade_uniform+1] = state.cascades[i].tile_length
		end
		for i=1, (max_cascades)-#state.cascades do
			cascade_uniform[#cascade_uniform+1] = 0
		end

		cascades_ubo:Upload(cascade_uniform)
		state.upload_cascades_ubo = false
	end

	cascades_ubo:BindBufferRange(15, nil, nil, GL_UNIFORM_BUFFER)

	clipmap:Draw()
end

-- Recull clipmap tiles and update lod levels
-- FIXME: camera callins don't exist?
function widget:CameraPositionChanged(posx, posy, posz)
	Spring.Echo("CameraPositionChanged", posx, posy, posz)
	update_culling = true
end
function widget:CameraRotationChanged(rotx, roty, rotz)
	Spring.Echo("CameraRotationChanged", rotx, roty, rotz)
	update_culling = true
end

function widget:ViewResize(vsx, vsy)
	-- Spring.Echo("ViewResize", vsx, vsy)
	update_culling = true
end

-- For unit foam/displacement
-- function widget:UnitEnteredWater(unitID, unitTeam, allyTeam, unitDefID) end
-- function widget:UnitLeftWater(unitID, unitTeam, allyTeam, unitDefID) end
-- function widget:UnitEnteredUnderwater(unitID, unitTeam, allyTeam, unitDefID) end
-- function widget:UnitLeftUnderwater(unitID, unitTeam, allyTeam, unitDefID) end

function delete_buffers()
	update_butterfly = false
	update_spectrum = false
	update_culling = false
	state.upload_cascades_ssbo = false
	state.upload_cascades_ubo = false
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
	state.material.update_material = false
	if ocean_waves_shader ~= nil then ocean_waves_shader:Delete() end
	if butterfly_comp ~= nil then glDeleteShader(butterfly_comp) end
	if spectrum_comp ~= nil then glDeleteShader(spectrum_comp) end
	if spectrum_modulate_comp ~= nil then glDeleteShader(spectrum_modulate_comp) end
	if fft_comp ~= nil then glDeleteShader(fft_comp) end
	if transpose_comp ~= nil then glDeleteShader(transpose_comp) end
	if fft_unpack_comp ~= nil then glDeleteShader(fft_unpack_comp) end
	if cull_tiles_comp ~= nil then glDeleteShader(cull_tiles_comp) end
end

