#version 460
// File: ocean_waves.frag.glsl
// Author: chmod777
// License: AGPL v3 only

/*
Copyright (C) 2025 chmod777

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License version 3 as published by the
Free Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along
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

//__Defines__
//__ENGINEUNIFORMBUFFERDEFS__

layout (location = 0) in vec2 coords;
layout (location = 1) in vec4 instance_data;

layout (binding=DISPLACEMENT_MAP_BINDING) uniform sampler2DArray displacement_map;
layout (binding=DEPTH_MAP_BINDING) uniform sampler2D depth_map;

struct CascadeParameters {
	vec2 scales; // x: displacement, y: normal
	float tile_length;
	float alpha;
	float peak_frequency;
	float wind_speed;
	float angle;
	float depth;
	float swell;
	float detail;
	float spread;
	float time;
	float index;
	float whitecap;
	float foam_grow_rate;
	float foam_decay_rate;
	// 16 * sizeof(float)
};

layout(std430, binding=6) restrict readonly buffer Cascade {
	CascadeParameters cascades[NUM_CASCADES];
};

// https://gist.github.com/yiwenl/3f804e80d0930e34a0b33359259b556c
vec2 rotate2d(vec2 v, float a) {
	float s = sin(a);
	float c = cos(a);
	mat2 m = mat2(c, s, -s, c);
	return m * v;
}

out DataVS {
	vec2 uv;
	float wave_height;
	vec3 world_vertex_position;
	flat float tile_id;
	flat float tile_rot;
	flat float tile_scale;
	flat float tile_layer;
} OUT;

void main() {
	float tile_id = instance_data.x;
	float tile_rot = instance_data.y;
	float tile_scale = instance_data.z;
	float tile_layer = instance_data.w;

	vec2 tile_offset = (
			vec2(uint(tile_id) % 4, uint(tile_id) / 4) * vec2(MESH_SIZE, MESH_SIZE)- vec2(MESH_SIZE)*1.5
		)*float(tile_id!=5);

	vec3 camera_position = cameraViewInv[3].xyz;
	ivec2 camera_ipos = ivec2(camera_position.xz);
	vec2 rotated = rotate2d(coords, tile_rot * -(PI/2.0));
	vec2 uv = (rotated + tile_offset) * tile_scale + vec2(camera_ipos.x-camera_ipos.x%64+32, camera_ipos.y-camera_ipos.y%64+32);
	vec3 coord = vec3(uv.x, 0.0, uv.y);
	float dist = distance(coord.xyz, camera_position.xyz);

	vec3 displacement = vec3(0.0);
	for (uint i = 0U; i < NUM_CASCADES; ++i) {
		vec2 uv_scale = vec2(1.0 / cascades[i].tile_length);
		vec3 uv_coords = vec3(uv*uv_scale, float(i));
		float displacement_scale = cascades[i].scales.x;
		displacement += texture(displacement_map, uv_coords).xyz * displacement_scale;
	}
	#ifdef DEBUG_DISABLE_DISPLACEMENT
		displacement = vec3(0.0);
	#endif


	// FIXME: Have this configurable in meters
	// Displacement amonut falls off after 4096 gl units
	// TODO: Dampen displacement when in shallow water
	const float falloff_distance = 4096;
	const float falloff_end = 4096;
	float distance_factor = 1.0 - smoothstep(falloff_distance, falloff_distance+falloff_end, dist);

	mat4 modelMat = mat4(1.0); // translationMat(vec3(0.0, 0.0, 0.0));
	vec3 displaced = coord + vec3(displacement.xyz) * distance_factor;
	vec4 world_vertex_position = modelMat * vec4(displaced, 1.0);
	vec4 vertex_position = cameraProj * cameraView * world_vertex_position;
	gl_Position = vertex_position;

	OUT.uv = uv;
	OUT.wave_height = displacement.y;
	OUT.world_vertex_position = world_vertex_position.xyz;
	OUT.tile_id = tile_id;
	OUT.tile_rot = tile_rot;
	OUT.tile_scale = tile_scale;
	OUT.tile_layer = tile_layer;
}