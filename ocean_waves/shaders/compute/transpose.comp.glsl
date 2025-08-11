#version 460
/** 
 * A memory-efficient coalesced matrix transpose kernel. 
 * Source: https://developer.nvidia.com/blog/efficient-matrix-transpose-cuda-cc/
 */

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
From: https://github.com/2Retr0/GodotOceanWaves/blob/main/assets/shaders/compute/transpose.glsl
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

layout(local_size_x = TRANSPOSE_TILE_SIZE, local_size_y = TRANSPOSE_TILE_SIZE, local_size_z = 1) in;

struct CascadeParameters {
	// vec2 scales; // x: displacement, y: normal
	float displacement_scale;
	float normal_scale;
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
	CascadeParameters cascade;
};

layout(std430, binding = 5) restrict readonly buffer ButterflyFactorBuffer {
	vec4 butterfly[]; // log2(map_size) x map_size
}; 

layout(std430, binding = 7) restrict buffer FFTBuffer {
	vec2 data[]; // map_size x map_size x num_spectra x 2 * num_cascades
};


shared vec2 tile[TRANSPOSE_TILE_SIZE][TRANSPOSE_TILE_SIZE];

#define DATA_IN(id, layer)  (data[(id.z)*WAVE_RES*WAVE_RES*NUM_SPECTRA*2 + NUM_SPECTRA*WAVE_RES*WAVE_RES + (layer)*WAVE_RES*WAVE_RES + (id.y)*WAVE_RES + (id.x)])
#define DATA_OUT(id, layer) (data[(id.z)*WAVE_RES*WAVE_RES*NUM_SPECTRA*2 +                             0 + (layer)*WAVE_RES*WAVE_RES + (id.y)*WAVE_RES + (id.x)])
void main() {
	const uvec2 id_block = gl_WorkGroupID.xy;
	const uvec2 id_local = gl_LocalInvocationID.xy;
	const uint spectrum = gl_GlobalInvocationID.z;

	uvec3 id = uvec3(gl_GlobalInvocationID.xy, uint(cascade.index));
	barrier();
	tile[id_local.y][id_local.x] = DATA_IN(id, spectrum);
	// barrier();

	id.xy = id_block.yx * TRANSPOSE_TILE_SIZE + id_local.xy;
	barrier();
	DATA_OUT(id, spectrum) = tile[id_local.x][id_local.y];
	// barrier();
}