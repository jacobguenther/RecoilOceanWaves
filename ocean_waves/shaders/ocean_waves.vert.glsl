#version 460
// File: ocean_waves.frag.glsl
// Author: chmod777
// License: GPLv2 or later

/*
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
*/

/*
From: https://github.com/2Retr0/GodotOceanWaves/blob/main/assets/shaders/spatial/water.gdshader
MIT License

Copyright (c) 2024 Ethan Truong

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec2 coords;
layout (location = 1) in vec4 instance_data;

layout (binding=DISPLACEMENT_MAP_BINDING) uniform sampler2DArray displacement_map;
layout (binding=DEPTH_MAP_BINDING) uniform sampler2D depth_map;

// struct CascadeParameters {
// 	float displacement_scale;
// 	float normal_scale;
// 	float tile_length;
// 	float alpha;
// 	float peak_frequency;
// 	float wind_speed;
// 	float angle;
// 	float depth;
// 	float swell;
// 	float detail;
// 	float spread;
// 	float time;
// 	float index;
// 	float whitecap;
// 	float foam_grow_rate;
// 	float foam_decay_rate;
// 	// 16 * sizeof(float)
// };
// layout(std430, binding=6) restrict readonly buffer Cascade {
// 	CascadeParameters cascades[NUM_CASCADES];
// };

layout (std140, binding=15) uniform CascadeData {
	vec4 cascade_displacement_scale;
	vec4 cascade_normal_scale;
	vec4 cascade_length;
};

// https://gist.github.com/yiwenl/3f804e80d0930e34a0b33359259b556c
vec2 rotate2d(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, s, -s, c);
	return m * v;
}

out DataVS {
	vec4 uv_wave_height; // w unused
	vec4 world_vertex_position_distance;
	flat vec4 tile;
} OUT;

void main() {
	const float tile_id = instance_data.x;
	const float tile_rot = instance_data.y;
	const float tile_scale = instance_data.z;
	const float tile_layer = instance_data.w;

	const vec2 tile_offset = (
			vec2(
				float(uint(tile_id) % 4) - 1.5,
				float(uint(tile_id) / 4) - 1.5
			) * vec2(MESH_SIZE)
		)*float(tile_id != 5.0);

	const vec3 camera_position = cameraViewInv[3].xyz;
	const ivec2 camera_ipos = ivec2(camera_position.xz);
	const vec2 camera_grid_alignment = vec2(
		camera_ipos.x-camera_ipos.x%CLIP_GRID_ALIGNMENT+HALF_CLIP_GRID_ALIGNMENT,
		camera_ipos.y-camera_ipos.y%CLIP_GRID_ALIGNMENT+HALF_CLIP_GRID_ALIGNMENT
	);
	// const vec2 camera_grid_alignment = vec2(
	// 	camera_ipos -
	// 	camera_ipos%ivec2(CLIP_GRID_ALIGNMENT) +
	// 	ivec2(HALF_CLIP_GRID_ALIGNMENT)
	// );

	const vec2 local_coords = rotate2d(coords, tile_rot * -HALF_PI);

	const vec2 uv = (local_coords + tile_offset) * tile_scale + camera_grid_alignment;
	const vec3 coord = vec3(uv.x, 0.0, uv.y);

	const float dist = distance(coord.xyz, camera_position.xyz);

	vec3 displacement = vec3(0.0);
	for (uint i = 0U; i < NUM_CASCADES; ++i) {
		const float tile_length = cascade_length[i];
		const float displacement_scale = cascade_displacement_scale[i];
	
		const float uv_scale = 1.0 / tile_length;
		const vec3 uv_coords = vec3(uv*uv_scale, float(i));
		displacement += texture(displacement_map, uv_coords).xyz * displacement_scale;
	}
	#ifdef DEBUG_DISABLE_DISPLACEMENT
		displacement = vec3(0.0);
	#endif
	displacement.xz = clamp(displacement.xz, vec2(-10.0), vec2(10.0));
	// displacement = vec3(0.0, displacement.y, 0.0);

	// TODO: Dampen displacement when in shallow water
	const float distance_factor = 1.0 - smoothstep(DISPLACEMENT_FALLOFF_START, DISPLACEMENT_FALLOFF_END, dist);

	const vec3 world_vertex_position = coord + displacement * distance_factor;
	const vec4 vertex_position = cameraViewProj * vec4(world_vertex_position, 1.0);

	gl_Position = vertex_position;
	OUT.uv_wave_height = vec4(uv, displacement.y, 0.0);
	OUT.world_vertex_position_distance = vec4(world_vertex_position, dist);
	OUT.tile = instance_data;
}