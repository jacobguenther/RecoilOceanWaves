#version 460
// File: gen_depth.comp.glsl
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

//__DEFINES__

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 5) restrict readonly buffer DepthData {
	vec4 data[];
};

layout(DEPTH_FORMAT_QUALIFIER, binding=DEPTH_MAP_BINDING) restrict uniform image2DArray depth_map;

// https://gist.github.com/companje/29408948f1e8be54dd5733a74ca49bb9
float map(float value, float min1, float max1, float min2, float max2) {
	return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);

	float water_plane = float(WATER_LEVEL);

	float height = data[id.x * gl_NumWorkGroups.y + id.y].x;
	barrier();

	height = clamp(height, mapHeight.x, water_plane);
	float depth = map(height, mapHeight.x, water_plane, 0.0, 1.0);

	vec4 image_out = vec4(depth, 1.0 - depth, height, 1.0);

	imageStore(depth_map, ivec3(id, 0), image_out);
}