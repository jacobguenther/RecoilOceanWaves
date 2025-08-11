#version 460
/** Culls clipmap tiles based on the view frustum and map edges */

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

//__DEFINES__

const uint TILE_COUNT = 73;
const uint LAYER_COUNT = 6;
const uint TILES_PER_LAYER = 12;

// const uint MIN_LOD_LEVEL = 1; // Lua index
// const uint MAX_LOD_LEVEL = 10; // Lua index

layout (local_size_x = TILE_COUNT, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 5) readonly buffer TileData {
	vec4 tiles_in[]; // id, rotation, scale, layer
};
layout(std430, binding = 6) writeonly buffer LodBins {
	vec4 bins[]; // visible_count, distance, base_instance, lod
};
layout(std430, binding = 7) writeonly buffer TileDataOut {
	vec4 tiles_out[]; // id, rotation, scale, layer
};

// #define SHARED_FRUSTUM
#ifdef SHARED_FRUSTUM
	shared vec4 frustum[6];
#endif

shared float distances[TILE_COUNT]; // tile_id, visible, dist, 0.0
shared vec4 layers[LAYER_COUNT+1]; // visible_count, distance, base_instance, base_instance

vec4 NormalizePlane(vec4 plane) {
	return plane / length(plane.xyz);
}

float PointPlaneDistance(vec4 plane, vec3 point) {
	return dot(plane.xyz, point) + plane.w;
}
// bool PointInFrontOfPlane(vec4 plane, vec3 point) {
// 	return PointPlaneDistance(point, plane) > 0.0;
// }

float SpherePlaneDistance(vec4 plane, vec3 center, float radius) {
	return PointPlaneDistance(plane, center) + radius;
}
bool SphereInFrontOfPlane(vec4 plane, vec3 center, float radius) {
	return SpherePlaneDistance(plane, center, radius) > 0.0;
}

float AABBPlaneDistance(vec4 plane, vec3 center, vec3 extents) {
	float center_dist = PointPlaneDistance(plane, center);
	float projected_radius = dot(extents, abs(plane.xyz));
	return center_dist + projected_radius;
}
bool AABBInFrontOfPlane(vec4 plane, vec3 center, vec3 extents) {
	return AABBPlaneDistance(plane, center, extents) > 0.0;
}

// https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdBox(vec3 p, vec3 b) {
	vec3 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

void main() {
	const uint id = gl_LocalInvocationID.x;
	const float tile_id = tiles_in[id].x;
	const float tile_rot = tiles_in[id].y;
	const float tile_scale = tiles_in[id].z;
	const float tile_layer = tiles_in[id].w;

	// From: shaders/ocean_waves.vert.glsl
	const vec2 tile_offset = (
		vec2(
			float(uint(tile_id+0.1) % 4) - 1.5,
			float(uint(tile_id+0.1) / 4) - 1.5
		) * vec2(float(MESH_SIZE) * tile_scale) // * vec2(MESH_SIZE)*tile_scale
	) * float(floor(tile_id+0.1) != 5.0);

	const vec3 camera_pos = cameraViewInv[3].xyz;
	const vec2 tile_pos = tile_offset + camera_pos.xz;
	const vec3 tile_position = vec3(tile_pos.x, 0.0, tile_pos.y);
	const vec3 center = (cameraView * vec4(tile_position, 1.0)).xyz;

	vec3 aabb_extents = vec3(MESH_SIZE * 0.5 * tile_scale + 128.0);
	aabb_extents.y = 10.0;

	const float radius =
		SQRT2 * float(MESH_SIZE) * 0.5
		* tile_scale
		+ 64.0; // from tile/camera/texture alignment

	#ifdef SHARED_FRUSTUM
		if (gl_LocalInvocationID.x == 1) {
	#else
		vec4 frustum[6]; {
	#endif
		const mat4 m = cameraProj;
		const vec4 row1 = vec4(m[0][0], m[1][0], m[2][0], m[3][0]); // row 1
		const vec4 row2 = vec4(m[0][1], m[1][1], m[2][1], m[3][1]); // row 2
		const vec4 row3 = vec4(m[0][2], m[1][2], m[2][2], m[3][2]); // row 3
		const vec4 row4 = vec4(m[0][3], m[1][3], m[2][3], m[3][3]); // row 4
		frustum[0] = NormalizePlane(row4 + row1); // left     w + x
		frustum[1] = NormalizePlane(row4 - row1); // right    w - x
		frustum[4] = NormalizePlane(row4 + row2); // bottom   w + y
		frustum[5] = NormalizePlane(row4 - row2); // top      w - y
		frustum[2] = NormalizePlane(row4 + row3); // near     w + z
		frustum[3] = NormalizePlane(row4 - row3); // far      w - z
	}

	#ifdef SHARED_FRUSTUM
	barrier();
	#endif

	bool visible = true;
	for (int i = 0; i < 6; ++i) {
		// visible = visible && AABBInFrontOfPlane(frustum[i], center, aabb_extents);
		visible = visible && SphereInFrontOfPlane(frustum[i], center, radius);
	}

	vec3 aabb_min = tile_position-aabb_extents;
	vec3 aabb_max = tile_position+aabb_extents;
	vec3 closest_point = clamp(camera_pos, aabb_min, aabb_max);

	float dist =
		distance(camera_pos, closest_point);
		// sdBox(aabb_extents, cameraViewInv[3].xyz-vec3(tile_offset.x, 0.0, tile_offset.y));

	distances[gl_LocalInvocationID.x] = float(visible) * dist;

	barrier();

	if (gl_LocalInvocationID.x == 0) {
		int previous_layer = -1;
		int instance_vbo_end = 0;
		for (int d = 0; d < TILE_COUNT; d++) {
			int current_layer = int(tiles_in[d].w);
			if (previous_layer != current_layer) {
				layers[current_layer].z = float(instance_vbo_end); // base_instance
			}
			previous_layer = current_layer;

			const bool tile_visible = distances[d] > 0.0;
			if (tile_visible) {
				tiles_out[instance_vbo_end] = tiles_in[d];
				instance_vbo_end += 1;
			}
		}
	}

	barrier();

	if (gl_LocalInvocationID.x < LAYER_COUNT+1) {
		uint layer_index = gl_LocalInvocationID.x;

		float layer_visible_count = 0.0;
		float layer_distance = 10000000.0;

		if (layer_index == 0) {
			const float tile_distance = distances[0];
			const bool tile_is_visible = distances[0] > 0;
			layer_visible_count = float(tile_is_visible);
			layer_distance = tile_distance;
		} else {
			for (uint t = 0; t < TILES_PER_LAYER; t++) {
				const uint tile_index = (layer_index-1)*TILES_PER_LAYER+t+1;
				const float tile_distance = distances[tile_index];
				const bool tile_is_visible = tile_distance > 0.0;
				layer_visible_count += float(tile_is_visible);
				// Shortest distance to a visible tile in a layer
				layer_distance = (tile_is_visible) ? min(layer_distance, tile_distance) : layer_distance;
			}
		}
		layer_distance = float(layer_visible_count > 0.0) * layer_distance;

		float layer_lod = floor(layer_distance/float(LOD_STEP));
		layer_lod = clamp(layer_lod, MIN_LOD_LEVEL, MAX_LOD_LEVEL);

		layers[layer_index].x = layer_visible_count;
		layers[layer_index].y = layer_distance;
		// layers[layer_index].z = base_instance
		layers[layer_index].w = layer_lod;
		// layers[layer_index].w = layer_distance;

		barrier();

		bins[layer_index] = layers[layer_index];
	}

	barrier();

	// group layers with the same lod level together
	// if (gl_LocalInvocationID.x == 0) {
	// 	int bin_index = 0;

	// 	bool bin_init = false;
	// 	vec4 current_bin = vec4(0.0);
	// 	float previous_lod = -1.0;

	// 	vec4 center = layers[0];
	// 	if (center.x > 0.0) {
	// 		if (center.y > DISPLACEMENT_FALLOFF_END) {
	// 			center.w = float(MAX_LOD_LEVEL);
	// 		}
	// 		previous_lod = center.w;
	// 		bins[bin_index] = center;
	// 		bin_index = 1;
	// 	}

	// 	for (int l = 1; l < LAYER_COUNT+1; l++) {
	// 		barrier();
	// 		vec4 layer = layers[l];

	// 		if (layer.x > 0.0) {
	// 			bins[bin_index] = layer;
	// 			bin_index += 1;
	// 		}

	// 		if (layer.x > 0.0) {
	// 			float layer_lod = layer.w;
	// 			if (previous_lod != -1) {
	// 				layer_lod = min(layer_lod, previous_lod);
	// 			}
	// 			if (layer.y > DISPLACEMENT_FALLOFF_END) {
	// 				layer_lod = float(MAX_LOD_LEVEL);
	// 			}
	// 			previous_lod = layer_lod;

	// 			if (!bin_init) {
	// 				// create the first bin
	// 				current_bin = vec4(layer);
	// 				bin_init = true;
	// 			} else if (current_bin.w == layer.w) {
	// 				// grow the current bin
	// 				current_bin.x += layer.x;
	// 			} else {
	// 				// push the current bin
	// 				bins[bin_index] = vec4(current_bin);
	// 				bin_index += 1;
	// 				current_bin = vec4(layer);
	// 			}
	// 		}
	// 		else if (previous_lod == -1) {
	// 			// This layer isn't visible but there has been a visible layer.
	// 			// There will be no more visible layers.
	// 			break;
	// 		}
	// 	}

	// 	if (current_bin != -1) {
	// 		bins[bin_index] = current_bin;
	// 	}

	// 	bins[bin_index+1] = vec4(0.0);
	// }
}